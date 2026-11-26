-- Module: Net.Transport
-- Purpose: The one outgoing queue: token bucket, priorities, transmit, W.SendChannel / W.SendTo
--   / W.FlushQueue; groups, invites and summons (W.Invite, W.AcceptInvite,
--   W.AcceptSummon...).
-- API: W.FlushQueue, W.QueueLength, W.SendChannel, CX.send, W.SendTo, W.InGroupWith, W.Invite,
--   W.LeaveGroup, W.AcceptInvite, W.AcceptSummon, W.IsWarlock,
--   NETK.{CANT_SEND_PROBE,MAX_LOW,FLY_QUEUED}
-- Internals: COALESCE, enqueue, hideInvitePopup, money, whisperKind, ASK / ask (the "can this player be whispered?"
--   check before a hidden whisper; Mod.ASK holds its numbers, Mod.ask its state; counters W.net.notSent, W.net.askSilent)
-- Uses: Net.Base, Net.Community
-- Later: Drive.Queue (W.Drive.customers[key].guid, read at run time: the GUID of a whisper target)
-- Events: listens ENCOUNTER_START, ENCOUNTER_END, PLAYER_ENTERING_WORLD; from the first whisper check only (never at
--   load): CAN_LOCAL_WHISPER_TARGET_RESPONSE, CHAT_MSG_SYSTEM; fires NETWORK
-- Standalone: no
-- Test: tests/net/transport_test.lua
-- From: Net.lua 819-1173 (Wuber 2.2.1)
--
---------------------------------------------------------------------------
-- Sending: one queue, rate-limited
---------------------------------------------------------------------------

local _, W = ...
local Mod = W.Module("Net.Transport", { "Net.Base", "Net.Community" })
local BaseMod = W.Mod("Net.Base")
local CommunityMod = W.Mod("Net.Community")
local CHANNEL_KINDS, KINDS, NETK, WHISPER_TOO, address = BaseMod.CHANNEL_KINDS, BaseMod.KINDS, BaseMod.NETK, BaseMod.WHISPER_TOO, BaseMod.address
local call, fb, myKey, now = BaseMod.call, BaseMod.fb, BaseMod.myKey, BaseMod.now
local CX, comm = CommunityMod.CX, CommunityMod.comm
local plain, str, num = W.Plain, W.Str, W.Num

local queue = {}
local tokens, lastRefill = NETK.BURST, nil
local flushPending = false
local flushWake = 0 -- when the pending flush timer fires

-- The whisper check (see "Asking the game" above W.SendTo). ASK: WAIT seconds a held whisper waits for the game's answer;
-- KEEP seconds an answer counts as fresh; SILENT_MAX unanswered waits in a session before asking is given up for good;
-- TEST_KEEP seconds a marked test whisper may wait in the queue before it stops being the test.
local ASK = { WAIT = 1, KEEP = 10, SILENT_MAX = 2, TEST_KEEP = 60, EVENT = "CAN_LOCAL_WHISPER_TARGET_RESPONSE" }
local ask = {
	held = {},        -- key -> { guid, target, items = { { target, kind, text, coalesce } } } waiting for the answer
	heldN = 0,        -- messages held (W.QueueLength counts them)
	fresh = {},       -- guid -> { offline, at } the game's last answers
	pendingTest = {}, -- key -> the time until which our next whisper to them is the test of an "offline" answer
	tests = {},       -- key -> { at } a test whisper went out; waiting for the game's "No player named" line
	silent = 0,       -- waits that ended with no answer
	answered = false, -- the game has answered at least once
	proven = false,   -- an "offline" answer was followed by the game's not-found line: offline answers are believed
	gaveUp = false,   -- asking is off for the rest of the session
	listening = false, -- the two events are wired (at the first ask)
}

-- The game's chat lock (a raid or boss fight) refuses every addon message with the number 11.
-- That is "later", never the account's fault: the outbox is held (nothing counted) and sent when
-- the lock ends. inFight follows ENCOUNTER_START/END; holdUntil is set by an answer of 11;
-- InChatMessagingLockdown is asked too, where this client has it.
local CHAT_LOCKED = 11
local inFight, fightAt, FIGHT_MAX = false, 0, 900
local holdUntil = 0
-- Just after a loading screen the game may be touchy about a burst of addon messages. So the budget is cut to
-- LOAD_BURST there: two messages may go at once (a summoned rider's "arrived" is never late), the rest follow at
-- the usual one a second, where NETK.BURST (four) could go at once before. A message the game refuses then is kept and tried again (the
-- throttle answers below), so nothing is lost either way. A quiet time (QUIET seconds of nothing) and a slow
-- phase (SLOW seconds at SLOW_FACTOR of the speed) are possible too; both are off (0) until the game is seen to
-- need them: a quiet time delays the ride's own messages at its most delicate moment, and a message waiting in it
-- is lost when the player reloads just then.
local QUIET, SLOW, SLOW_FACTOR, LOAD_BURST = 0, 0, 0.1, 2
local quietUntil, slowUntil = 0, 0

local THROTTLED = { [3] = true, [8] = true } -- AddonMessageThrottle, ChannelThrottle
do
	local E = type(Enum) == "table" and Enum.SendAddonMessageResult
	if type(E) == "table" then
		if num(E.AddonMessageThrottle) then THROTTLED[E.AddonMessageThrottle] = true end
		if num(E.ChannelThrottle) then THROTTLED[E.ChannelThrottle] = true end
	end
end

-- Trial and veteran accounts on Forever can't send addon messages at all: three failed
-- sends in a row and none ever sent -> W.net.cantSend. Wuber then only listens (drivers are
-- still seen over the channel) and books by the chat whisper alone; one message is still
-- tried every 5 min in case it was something else. Said once in chat.
NETK.CANT_SEND_PROBE = 300
local function noteHardFail()
	W.net.hardFails = (W.net.hardFails or 0) + 1
	if W.net.cantSend or W.net.hardFails < 3 or W.net.sent > 0 then return end
	W.net.cantSend = true
	W.net.probeAt = now() + NETK.CANT_SEND_PROBE
	W.Fire("NETWORK", W.OnNetwork())
	if not W.net.cantSendSaid then
		W.net.cantSendSaid = true
		W.Print("This account can't send addon messages (trial accounts can't). You can still see drivers and book: your request goes as a whisper.")
	end
end

-- true: done with (sent, or can never be sent); false: the game said "too fast", later
local function transmit(item)
	local CI = C_ChatInfo
	if type(CI) ~= "table" or type(CI.SendAddonMessage) ~= "function" then
		W.net.failed = W.net.failed + 1
		return true
	end
	local target = item.target
	if item.target == CX.TARGET then
		-- a copy for the community channel: its own failures, never the account's
		target = W.CommunityIndex()
		if not target then
			comm.dropped = comm.dropped + 1
			return true
		end
		local res = { pcall(CI.SendAddonMessage, W.PREFIX, item.text, "CHANNEL", target) }
		local n = table.maxn(res)
		local r = nil -- (false is a result here, so no "and/or")
		if res[1] and n >= 2 then r = plain(res[n]) end
		if not res[1] then
			CX.fail("error")
		elseif r == CHAT_LOCKED then
			holdUntil = now() + 2 -- locked: later, not a failure
			return false
		elseif r == 3 or (r ~= 8 and type(r) == "number" and THROTTLED[r]) then
			item.tries = (item.tries or 0) + 1 -- the prefix's own throttle: later
			if item.tries < 10 then return false end
			comm.dropped = comm.dropped + 1
		elseif r == false or r == 7 or r == 8 or r == 9 or (type(r) == "number" and r ~= 0) then
			CX.fail(r)
		else
			comm.fails = 0
			comm.sent = comm.sent + 1
			if comm.firstResult == nil then
				comm.firstResult = "ok (" .. tostring(r) .. ")"
				CX.note("first send: " .. comm.firstResult .. " on channel " .. target)
			end
		end
		return true
	end
	if item.chan == "CHANNEL" then
		target = W.ChannelIndex() -- read again: the index can change
		if not target then
			W.net.dropped = W.net.dropped + 1
			return true
		end
	end
	local out = { pcall(CI.SendAddonMessage, W.PREFIX, item.text, item.chan, target) }
	if not out[1] then
		W.net.failed = W.net.failed + 1
		noteHardFail()
		return true
	end
	-- the result is the last value returned (its place moved between client versions;
	-- older clients return a boolean, newer a number: 0 is success)
	local n = table.maxn(out)
	local res = n >= 2 and plain(out[n]) or nil
	-- (a plain false counts as sent: this client's answers can't be trusted, see Theme's
	-- SetFont, and a false alarm here would switch the account to listen-only)
	if res == CHAT_LOCKED then
		holdUntil = now() + 2 -- locked: keep it, count nothing, try again when the lock ends
		return false
	end
	if type(res) == "number" and THROTTLED[res] then
		item.tries = (item.tries or 0) + 1
		if item.tries < 10 then return false end
		W.net.failed = W.net.failed + 1
		return true
	end
	if item.chan == "WHISPER" then
		-- even a refused whisper may still bring "No player named" back
		local key = W.Key(target)
		if key then
			fb.whispered[key] = now()
			if ask.pendingTest[key] and ask.noteTest then ask.noteTest(key) end
		end
	end
	if res == nil or res == true or res == 0 then
		W.net.sent = W.net.sent + 1
		W.net.hardFails = 0
		if W.net.cantSend then
			W.net.cantSend = false
			W.Fire("NETWORK", W.OnNetwork())
		end
	else
		W.net.failed = W.net.failed + 1
		-- not in the channel any more, or not in a group: not the account's fault
		if not (res == 7 or res == 5) then noteHardFail() end
	end
	return true
end

-- Whether the game's chat is locked just now. An answer of 11 always holds for a moment. Where the game has its own
-- call for the lock, that call decides (a boss fight on a client that does not lock chat then holds nothing); where it
-- has none, a boss fight (ENCOUNTER_START to ENCOUNTER_END) counts as locked, for FIGHT_MAX seconds at most in case
-- the end is never told.
local function locked()
	if now() < holdUntil then return true end
	local CI = C_ChatInfo
	if type(CI) == "table" and type(CI.InChatMessagingLockdown) == "function" then
		local ok, res = pcall(CI.InChatMessagingLockdown)
		if ok then return plain(res) == true end
	end
	return inFight and now() - fightAt < FIGHT_MAX
end

-- the seconds of [a, b] that run from lo up to hi
local function overlap(a, b, lo, hi)
	local s, e = math.max(a, lo), math.min(b, hi)
	return e > s and (e - s) or 0
end

local function refill()
	local t = now()
	if not lastRefill then lastRefill = t end
	if t > lastRefill then
		local a = lastRefill
		local quiet = overlap(a, t, -math.huge, quietUntil)
		local slow = overlap(a, t, quietUntil, slowUntil)
		local gain = (t - a - quiet - slow) * NETK.RATE + slow * NETK.RATE * SLOW_FACTOR
		tokens = math.min(NETK.BURST, tokens + gain)
	end
	lastRefill = t
end

local function armFlush(wait)
	-- a timer already waiting stays unless this one is due earlier: then an earlier one is armed as well
	if not flushPending or now() + wait < flushWake - 0.05 then
		flushPending = true
		flushWake = now() + wait
		local mine = flushWake
		W.After(wait, function()
			if flushWake == mine then flushPending = false end
			W.FlushQueue()
		end)
	end
end

-- Sends what the rate allows now; the rest waits for a timer. A shared-flight-price item (the
-- lowest priority, 4) goes only when the whole burst allowance is back: whatever comes next
-- (a ride message) still goes at once.
local function needed()
	if queue[1] and queue[1].prio == 4 then return NETK.BURST end
	return 1
end

function W.FlushQueue()
	refill()
	if #queue > 0 then
		if locked() then
			armFlush(math.max(1, holdUntil - now())) -- held: asked again every second or so
			return
		end
		if now() < quietUntil then
			armFlush(quietUntil - now() + 0.05) -- the quiet time after a loading screen
			return
		end
	end
	while #queue > 0 and tokens >= needed() do
		if not transmit(queue[1]) then
			if now() < holdUntil then break end -- (locked: the budget stays)
			tokens = 0
			break
		end
		local item = table.remove(queue, 1)
		tokens = tokens - 1
		if item.done then W.Safe("sent", item.done) end -- (shared flight prices count what went)
	end
	if #queue > 0 then
		local rate = NETK.RATE
		if now() < slowUntil then rate = rate * SLOW_FACTOR end
		local wait = math.max(0.1, (needed() - tokens) / rate)
		if now() < slowUntil then wait = math.min(wait, slowUntil - now() + 0.05) end
		if now() < holdUntil then wait = math.max(wait, holdUntil - now()) end
		-- a timer already waiting stays unless the head now needs less wait (a ride message
		-- queued behind a shared flight price): then an earlier one is armed as well
		armFlush(wait)
	end
end

W.On("ENCOUNTER_START", function() inFight, fightAt = true, now() end)
W.On("ENCOUNTER_END", function()
	inFight = false
	holdUntil = 0
	W.FlushQueue()
end)
-- a loading screen: no fight goes on across it; the budget is cut to LOAD_BURST (and a quiet time starts, if one is set)
-- (A login or a /reload is left alone: Wuber has nothing to send then yet, and it starts its own
-- first beacon and whisper round on timers; it is the zoning and summon loading screens that count.)
W.On("PLAYER_ENTERING_WORLD", function(isLogin, isReload)
	inFight = false
	if isLogin == true or isReload == true then return end
	local t = now()
	refill()
	tokens = math.min(tokens, QUIET > 0 and 0 or LOAD_BURST)
	quietUntil, slowUntil = t + QUIET, t + QUIET + SLOW
	if #queue > 0 then W.FlushQueue() end
end)

-- How many messages are waiting to go out.
function W.QueueLength() return #queue + ask.heldN end

NETK.MAX_LOW = 12 -- whisper-fallback messages (D, X, Q, K by whisper) waiting at most

-- Order in the queue: ride whispers (1), then the whisper fallback's (2), then the channel (3),
-- then shared flight prices (4).
NETK.FLY_QUEUED = 3 -- shared-flight-price messages waiting at most
-- (#19) A beacon that tells a new state (open, busy, paused) goes with the fallback's: at one message a second the
-- whispered Q and K to other drivers kept it waiting 10 s and more. Same budget, same queue; an unchanged state stays at 3.
local function priority(chan, kind, urgent)
	if kind == "F" then return 4 end
	if chan == "CHANNEL" then return (urgent and kind == "D") and 2 or 3 end
	if WHISPER_TOO[kind] or kind == "K" then return 2 end
	return 1
end

local function enqueue(chan, target, kind, text, coalesce, done, urgent)
	local stale -- a waiting beacon that an urgent newer one replaces: it goes only once the new one is really queued
	if coalesce then
		for i, item in ipairs(queue) do
			if item.coalesce == coalesce and item.chan == chan then
				if urgent and (item.prio or 3) > 2 then
					stale = item
				else
					item.text, item.kind, item.target, item.tries = text, kind, target, 0
					return true
				end
				break
			end
		end
	end
	if W.net.cantSend then
		-- this account can't send: drop it, but let one through every 5 min (a probe)
		if now() < (W.net.probeAt or 0) then
			W.net.dropped = W.net.dropped + 1
			return false
		end
		W.net.probeAt = now() + NETK.CANT_SEND_PROBE
	end
	local prio = priority(chan, kind, urgent)
	if prio == 4 then
		local low = 0
		for _, item in ipairs(queue) do if item.prio == 4 then low = low + 1 end end
		if low >= NETK.FLY_QUEUED then
			W.net.dropped = W.net.dropped + 1
			return false
		end
	end
	if prio == 2 and not urgent then
		-- the fallback never crowds the queue: past 12 waiting, a new one is dropped
		local low = 0
		for _, item in ipairs(queue) do if item.prio == 2 then low = low + 1 end end
		if low >= NETK.MAX_LOW then
			W.net.dropped = W.net.dropped + 1
			return false
		end
	end
	-- full (SPEC5 outbox, review #5): the lowest-priority item waiting goes (the newest of the
	-- lowest kind), never the head; a new item worse than everything waiting is dropped
	-- itself. Ride messages may run 20 over the cap before one of them goes.
	if #queue >= NETK.MAX_QUEUE then
		local worst
		for i = #queue, 1, -1 do
			if not worst or (queue[i].prio or 3) > (queue[worst].prio or 3) then worst = i end
		end
		local wp = worst and (queue[worst].prio or 3) or 1
		if prio > wp then
			W.net.dropped = W.net.dropped + 1
			return false
		end
		if wp > 1 or prio > 1 or #queue >= NETK.MAX_QUEUE + 20 then
			table.remove(queue, worst)
			W.net.dropped = W.net.dropped + 1
		end
	end
	if stale then
		for i, other in ipairs(queue) do
			if other == stale then table.remove(queue, i) break end
		end
	end
	local item = { chan = chan, target = target, kind = kind, text = text, coalesce = coalesce, prio = prio, done = done }
	local at = #queue + 1
	-- ahead of every message of a lower priority still waiting
	for i, other in ipairs(queue) do
		if (other.prio or 3) > prio or (urgent and (other.prio or 3) == prio and other.kind ~= "D") then
			at = i
			break
		end
	end
	table.insert(queue, at, item)
	W.FlushQueue()
	return true
end

-- What a queued channel message of a kind is replaced by: a newer one of the same group
-- (a beacon by a beacon, a Q is not doubled, a bounty by the rider's newer bounty).
local COALESCE = { Q = "ping", W = "bounty" }
local lastBeaconState -- the state of the last channel beacon handed to the queue (#19)

-- Sends a message to everyone on the channel: W.SendChannel("D", dest, mapID, ...).
-- A queued D or X is replaced by the newer one, a queued Q is not doubled. Returns false
-- when not on the network.
function W.SendChannel(kind, ...)
	if not CHANNEL_KINDS[kind] or not W.OnNetwork() then return false end
	local coalesce = COALESCE[kind] or "beacon"
	local urgent = false
	if kind == "D" then
		local state = select(7, ...) -- the beacon's state field
		urgent = lastBeaconState ~= nil and state ~= lastBeaconState
		local queued = enqueue("CHANNEL", nil, kind, W.Encode(kind, ...), coalesce, nil, urgent)
		if queued then lastBeaconState = state end -- (a dropped beacon never told its state)
		return queued
	end
	return enqueue("CHANNEL", nil, kind, W.Encode(kind, ...), coalesce)
end

-- The same, as a copy on the community channel (see "The Wuber community"); false when it
-- isn't usable. A queued copy is replaced by a newer one, as on WuberNet.
function CX.send(kind, ...)
	if not CHANNEL_KINDS[kind] or not W.CommunityIndex() then return false end
	local coalesce = "c:" .. (COALESCE[kind] or "beacon")
	return enqueue("CHANNEL", CX.TARGET, kind, W.Encode(kind, ...), coalesce)
end

---------------------------------------------------------------------------
-- Asking the game before a hidden whisper
---------------------------------------------------------------------------
-- An addon whisper to someone who is offline makes the game print "No player named ..." (Net.Base hides that line, and
-- that stays as the fall-back). Where we know the player's GUID, W.SendTo first asks the game
-- C_ChatInfo.RequestCanLocalWhisperTarget(guid); the answer is the event CAN_LOCAL_WHISPER_TARGET_RESPONSE (guid, status):
-- 0 can, 1 can (guild), 2 offline, 3 wrong faction. Wuber has not yet seen this call in the real game, so nothing is trusted:
--  * The GUID is the Drive customer record's, else the party or raid unit with the same name key. No GUID, no such call,
--    a locked chat, a trial account or asking given up: W.SendTo does what it always did.
--  * Messages for a player we are asking about are held (in order; the same coalesce key replaces the held one) until
--    the answer, or ASK.WAIT seconds, then go as always. An answer stays fresh for ASK.KEEP seconds.
--  * "Can" (any status but offline): the message goes as always. "Offline": the first time it still goes as always, and
--    that whisper is a test: if the game's "No player named" line for that player comes back within
--    NETK.NOT_FOUND_WINDOW seconds, offline answers are PROVEN. If it does not, the answer was wrong and asking is given up.
--    Once proven, an "offline" answer means the message is not sent at all (W.net.notSent); Wuber's own CHAT_MSG_SYSTEM
--    handlers are told the game's not-found line (never the chat frame), so they react as they do today and no line prints.
--  * ASK.SILENT_MAX waits with never an answer: asking is given up. A late answer is only remembered. Giving up beats proven.
local function guidFor(key)
	local D = W.Drive
	local rec = type(D) == "table" and type(D.customers) == "table" and D.customers[key] or nil
	local g = type(rec) == "table" and plain(rec.guid) or nil
	if type(g) == "string" and g ~= "" then return g end
	local unitGuid = rawget(_G, "UnitGUID")
	if type(unitGuid) ~= "function" then return nil end
	for i = 1, 44 do
		local unit = i <= 4 and ("party" .. i) or ("raid" .. (i - 4))
		if W.Key(W.UnitName(unit)) == key then
			local okG, id = pcall(unitGuid, unit)
			id = okG and plain(id) or nil
			if type(id) == "string" and id ~= "" then return id end
		end
	end
	return nil
end

local function canAsk()
	if ask.gaveUp or W.net.cantSend then return false end
	local CI = C_ChatInfo
	return type(CI) == "table" and type(CI.RequestCanLocalWhisperTarget) == "function"
end

local function offlineStatus()
	local E = type(Enum) == "table" and Enum.ChatWhisperTargetStatus
	return (type(E) == "table" and num(E.Offline)) or 2
end

-- Tells Wuber's own handlers what the game would print for a whisper to someone offline (they never reach the chat frame).
local function tellNotFound(target)
	local fmt = (type(ERR_CHAT_PLAYER_NOT_FOUND_S) == "string" and ERR_CHAT_PLAYER_NOT_FOUND_S)
		or "No player named '%s' is currently playing."
	local okF, line = pcall(string.format, fmt, target)
	local onEvent = W.frame and W.frame.GetScript and select(2, pcall(W.frame.GetScript, W.frame, "OnEvent"))
	if okF and type(onEvent) == "function" then pcall(onEvent, W.frame, "CHAT_MSG_SYSTEM", line) end
end

local function release(key, h)
	ask.held[key] = nil
	ask.heldN = ask.heldN - #h.items
end

-- The held messages leave: sent as always, or (an offline answer already proven) not at all.
local function deliver(key, target, items, offline)
	if offline and not ask.gaveUp then
		if ask.proven then
			fb.whispered[key] = now()
			W.net.notSent = (W.net.notSent or 0) + #items
			tellNotFound(target)
			return
		end
		ask.pendingTest[key] = now() + ASK.TEST_KEEP
	end
	for i, it in ipairs(items) do
		if not enqueue("WHISPER", it.target, it.kind, it.text, it.coalesce) and i == 1 then ask.pendingTest[key] = nil end
	end
end

-- Our first whisper to a player the game called offline has gone out: the game's line must follow soon.
function ask.noteTest(key)
	local until_ = ask.pendingTest[key]
	ask.pendingTest[key] = nil
	if not until_ or now() > until_ then return end
	local t = { at = now() }
	ask.tests[key] = t
	W.After(NETK.NOT_FOUND_WINDOW + 0.5, function()
		if ask.tests[key] == t then
			ask.tests[key] = nil
			ask.gaveUp = true -- the line never came: the game's answer was wrong
		end
	end)
end

-- The game's "No player named" line after a test whisper: offline answers are proven.
local function onSystem(text)
	local key = W.Key(W.NotFoundName(text))
	local t = key and ask.tests[key]
	if t and now() - t.at <= NETK.NOT_FOUND_WINDOW then
		ask.tests[key] = nil
		ask.proven = true
	end
end

-- The game's answer: remembered, and everything held for that player leaves.
local function onAnswer(guid, status)
	guid, status = plain(guid), num(status)
	if type(guid) ~= "string" or not status then return end
	ask.answered = true
	local offline = status == offlineStatus()
	local t = now()
	for g, f in pairs(ask.fresh) do
		if t - f.at > ASK.KEEP then ask.fresh[g] = nil end
	end
	ask.fresh[guid] = { offline = offline, at = t }
	-- (the keys first: a handler told "not found" may send again, and a table must not gain keys while it is walked)
	local keys = {}
	for key, h in pairs(ask.held) do
		if h.guid == guid then keys[#keys + 1] = key end
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local h = ask.held[key]
		if h and h.guid == guid then
			release(key, h)
			deliver(key, h.target, h.items, offline)
		end
	end
end

-- The two events are wired at the first ask, never at load: a client without the call (and the fake game, until the call
-- is seen in the real game) registers nothing new and runs exactly as before.
-- (The answer's event is named in ASK.EVENT, not written into the W.On call: the flight recorder's event list and the fake
-- game's are made from the literal names, and both learn this event only once it has been seen in the real game.)
local function listen()
	if ask.listening then return end
	ask.listening = true
	W.On("CHAT_MSG_SYSTEM", onSystem)
	W.On(ASK.EVENT, onAnswer)
end

-- Sends a message by addon whisper to one player: W.SendTo("Anita Lift", "R", id, ...).
-- A queued S (or P, or G) for the same ride and player is replaced by the newer one. Returns
-- false for a bad name, or ourselves.
-- The whisper fallback's kinds go this way too (D, X, Q, K): a queued D or X to the same
-- player is replaced by the newer one, a queued Q or K is not doubled (nor a W, 2.3.0: the
-- newer bounty replaces it).
function W.SendTo(name, kind, ...)
	local target = address(name)
	local key = W.Key(target)
	if not KINDS[kind] or (CHANNEL_KINDS[kind] and not WHISPER_TOO[kind]) or not key or key == myKey() then return false end
	local coalesce = nil
	if kind == "S" or kind == "P" or kind == "G" then coalesce = kind .. ":" .. tostring((...)) .. ":" .. key end
	if kind == "D" or kind == "X" then coalesce = "wD:" .. key end
	if kind == "Q" or kind == "K" or kind == "W" then coalesce = "w" .. kind .. ":" .. key end
	local text = W.Encode(kind, ...)
	-- messages already held for this player: the new one joins them (the same coalesce key replaces the held one)
	local h = ask.held[key]
	if h then
		for _, it in ipairs(h.items) do
			if coalesce and it.coalesce == coalesce then
				it.text, it.kind, it.target = text, kind, target
				return true
			end
		end
		h.items[#h.items + 1] = { target = target, kind = kind, text = text, coalesce = coalesce }
		ask.heldN = ask.heldN + 1
		return true
	end
	local guid = canAsk() and not locked() and guidFor(key) or nil
	if not guid then return enqueue("WHISPER", target, kind, text, coalesce) end
	local f = ask.fresh[guid]
	if f and now() - f.at <= ASK.KEEP then
		if not f.offline then return enqueue("WHISPER", target, kind, text, coalesce) end
		deliver(key, target, { { target = target, kind = kind, text = text, coalesce = coalesce } }, true)
		return true
	end
	h = { guid = guid, target = target, items = { { target = target, kind = kind, text = text, coalesce = coalesce } } }
	ask.held[key] = h
	ask.heldN = ask.heldN + 1
	listen()
	if not pcall(C_ChatInfo.RequestCanLocalWhisperTarget, guid) then
		if ask.held[key] == h then release(key, h) end
		return enqueue("WHISPER", target, kind, text, coalesce)
	end
	W.After(ASK.WAIT, function()
		if ask.held[key] ~= h then return end
		release(key, h)
		ask.silent = ask.silent + 1
		W.net.askSilent = (W.net.askSilent or 0) + 1
		if ask.silent >= ASK.SILENT_MAX and not ask.answered then ask.gaveUp = true end
		deliver(key, h.target, h.items, false)
	end)
	return true
end

-- A channel kind (D, X or Q) by addon whisper to one player, for the whisper fallback.
local function whisperKind(name, kind, ...)
	if not WHISPER_TOO[kind] then return false end
	return W.SendTo(name, kind, ...)
end

---------------------------------------------------------------------------
-- Groups, invites, summons (each call guarded)
---------------------------------------------------------------------------

-- Whether the player with this name or key is in our party or raid.
function W.InGroupWith(key)
	key = key and W.Key(key)
	if not key then return false end
	for i = 1, 4 do
		if W.Key(W.UnitName("party" .. i)) == key then return true end
	end
	for i = 1, 40 do
		if W.Key(W.UnitName("raid" .. i)) == key then return true end
	end
	return false
end

-- Invites a player to our group (no click needed). Returns whether the call went through.
function W.Invite(name)
	name = address(name)
	if not name then return false end
	local fn = type(C_PartyInfo) == "table" and C_PartyInfo.InviteUnit or nil
	if type(fn) ~= "function" then fn = InviteUnit end
	if type(fn) ~= "function" then return false end
	return (pcall(fn, name))
end

-- Leaves the group (for "Leave your group first"). Returns whether the call went through.
function W.LeaveGroup()
	local fn = type(C_PartyInfo) == "table" and C_PartyInfo.LeaveParty or nil
	if type(fn) ~= "function" then fn = LeaveParty end
	if type(fn) ~= "function" then return false end
	return (pcall(fn))
end

-- Marks the visible party invite box as accepted and hides it. Hiding it without the mark
-- would decline the invite, so it is only hidden when found.
local function hideInvitePopup()
	if type(StaticPopup_FindVisible) ~= "function" then return end
	local dialog = plain(call(StaticPopup_FindVisible, "PARTY_INVITE"))
	if type(dialog) ~= "table" then return end
	pcall(function() dialog.inviteAccepted = 1 end)
	if type(StaticPopup_Hide) == "function" then pcall(StaticPopup_Hide, "PARTY_INVITE") end
end

-- Accepts the party invite (only from a button click). Returns whether AcceptGroup ran.
function W.AcceptInvite()
	if type(AcceptGroup) ~= "function" then return false end
	local ok = pcall(AcceptGroup)
	if ok then -- a refused accept leaves the game's box up: it is the rider's only way left
		hideInvitePopup()
		W.After(0.2, hideInvitePopup)
	end
	return ok
end

-- Accepts the summon (only from a button click). Returns true, or false and a short line
-- for the player.
function W.AcceptSummon()
	if W.InCombat() then return false, "Leave combat first." end
	local fn = type(C_SummonInfo) == "table" and C_SummonInfo.ConfirmSummon or nil
	if type(fn) ~= "function" then fn = ConfirmSummon end
	if type(fn) ~= "function" or not pcall(fn) then
		return false, "Click Accept on the game's summon box."
	end
	local r = W.ride
	if r then
		r.summonAccepted = true
		r.summonNoName = nil
		W.After(2, function() if W.CheckArrival then W.CheckArrival() end end)
		W.After(5, function() if W.CheckArrival then W.CheckArrival() end end)
	end
	return true
end

-- Whether the player is a Warlock.
function W.IsWarlock()
	if type(UnitClass) ~= "function" then return false end
	local ok, _, class = pcall(UnitClass, "player")
	return ok and str(class) == "WARLOCK"
end

local function money()
	return num(call(GetMoney))
end

-- for the Net modules that load after this one (REFACTOR-MAP section 2)
Mod.enqueue, Mod.hideInvitePopup, Mod.money, Mod.whisperKind = enqueue, hideInvitePopup, money, whisperKind
Mod.ASK, Mod.ask = ASK, ask -- (the tests read the whisper check's numbers and state)
