-- Module: Drive.Cast
-- Purpose: Big-button helpers and state, stations, raid assignment, the ritual watcher (spellcast
--   events, DR.CastWatch).
-- API: W.Drive, DR.Button, DR.RITUAL_ID, DR.MACRO_MAX, B.state, DR.ButtonStation, DR.calls,
--   DR.RaidAssign, DR.cast, DR.RitualBusy, DR.NextSummon, DR.CastFinish, DR.watching, DR.CastWatch,
--   DR.SummonLook, DR.SummonSeen (2.4: the game's own word on a group member's summon,
--   C_IncomingSummon; looked at once a second from DR.CastWatch, never from painting),
--   DR.SummonPending, DR.SummonHeld (2.4, the double-summon guard: DR.NextSummon never gives a rider
--   the game says has a summon waiting; the button's PreClick looks once more first)
-- Internals: CALL_AGAIN, COLORS, HEIGHT, SAY, VERB, WIDTH, btnDB, call, calls, due, isLeader, mode,
--   money, myStation, now, opts, raidTold, ritualName, settled, short, sorted, state, str1, units,
--   watching, heldHelpers, holdStart, holdStop (2.3.0: a group member without Wuber who holds my
--   portal 2 s or more is named in HELP field 2, once per summon), SUMMON, seen, summonRead,
--   summonLook (2.4), shardCount, shardProof (2.4: a Soul Shard still there a second into my channel
--   and gone when it ends proves the summon went out, where no helper was heard)
-- Uses: (none)
-- Later: (none)
-- Events: listens On UNIT_SPELLCAST_SENT, On UNIT_SPELLCAST_START, On UNIT_SPELLCAST_CHANNEL_START, On
--   UNIT_SPELLCAST_SUCCEEDED, On UNIT_SPELLCAST_CHANNEL_STOP, On UNIT_SPELLCAST_FAILED, On
--   UNIT_SPELLCAST_INTERRUPTED; fires DRIVE_RITUAL (2.3.0: phase "t" when this window targets a rider
--   for the summon); skinButton and skin (old line 49) moved to Drive.Button
-- Standalone: no
-- Test: tests/drive/cast_test.lua
-- From: Drive_Button.lua 1-525 (Wuber 2.2.1)
--
-- Wuber Drive: the big button (agent B). Ported from Ritual Rides 1.4.1's Button.lua.
--
-- WuberDriveButton is the only secure driver button: a real click (or the key bound to it)
-- runs what it holds, and what it holds is always the next thing due in this window:
--
--   * accept a rider's trade once the amount is right (it presses the game's own Trade
--     button: type "click"), or
--   * a macro: the whispers this window owes ("/w ..."), riders who are done leaving the
--     group ("/uninvite ..."), and the next summon ("/target [@raid4]", "/cast Ritual of
--     Summoning"). A helper who is not a Warlock never gets a cast step.
--
-- A macro holds 255 characters; what does not fit waits for the next click. The game
-- forbids changing a secure button in combat, so a fight empties it first ("Paused during
-- combat") and it catches up afterwards. One click, one action: nothing clicks for you.
--
-- The button is parented to UIParent and never anchored to WuberFrame: docked into the
-- Drive tab's slot by absolute coordinates (UI.SyncSecure's way), floating elsewhere at its
-- saved place. Docking and undocking happen only out of combat.

local ADDON, W = ...
local Mod = W.Module("Drive.Cast", {})
W.Drive = W.Drive or {}
local DR = W.Drive

local plain, num, str = W.Plain, W.Num, W.Str

DR.Button = DR.Button or {}
local B = DR.Button

DR.RITUAL_ID = 698
DR.MACRO_MAX = DR.MACRO_MAX or 255

local WIDTH, HEIGHT = 340, 100 -- floating (scaled by DR.Scale()); docked it takes its slot's size

-- the accent line (bottom and right edge): go = gold, wait = amber, alert = red, off/idle = grey
local COLORS = {
	off = { 0.42, 0.40, 0.52 },
	idle = { 0.42, 0.40, 0.52 },
	go = { 0.98, 0.77, 0.24 },
	wait = { 0.98, 0.64, 0.24 },
	alert = { 1.00, 0.36, 0.48 },
}

local VERB = { thanks = "Thank", tip = "Thank", price = "Answer", offer = "Price for", refuse = "Refuse", pay = "Remind",
	short = "Remind", busy = "Answer", greet = "Greet", getapp = "Wuber tip for", moved = "Say sorry to", where = "Ask",
	mailpay = "Tell" }
local SAY = { thanks = "thanks", tip = "thanks for the tip", price = "the price", offer = "the price", refuse = "why not",
	pay = "a reminder to pay", short = "the rest is due", busy = "they're in a group", greet = "the greeting",
	getapp = "how to get Wuber", moved = "that you've moved",
	where = "a question about where to go", mailpay = "how to pay by mail" }

local state = { docked = nil, sig = nil, due = false, flashing = false }
B.state = state

local function now() return W.Now() end

local function call(name, ...)
	local fn = DR[name]
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if not ok then
		W.Error("drive " .. name, a)
		return nil
	end
	return a, b
end

local function opts()
	local o = call("opts")
	return type(o) == "table" and o or {}
end

-- W.db.drive.button (A's DR.InitDB makes it; a stand-in until then).
local spare = { scale = 1, sizeSet = false, locked = false, shown = true, keepClosed = false }
local function btnDB()
	local d = W.db and W.db.drive
	if type(d) ~= "table" then return spare end
	if type(d.button) ~= "table" then d.button = { scale = 1, sizeSet = false, locked = false, shown = true, keepClosed = false } end
	return d.button
end

local function short(name) return W.Short(name) end
local function money(c) return W.Money(c) end
local function sorted()
	local l = call("Sorted")
	return type(l) == "table" and l or {}
end
local function due(c) return tonumber(call("Due", c)) or 0 end
local function units() return type(DR.units) == "table" and DR.units or {} end
local function isLeader()
	local v = call("IsLeader")
	if v == nil then return true end
	return v == true
end

local function str1(v) return type(v) == "string" and v ~= "" and v or nil end
local function mode() return call("Mode") == "raid" and "raid" or "sell" end

---------------------------------------------------------------------------
-- Stations (2.1): with summoners in two or more places, each plans only its own riders
---------------------------------------------------------------------------

local function placeName(v)
	if type(v) == "table" then v = v.place end
	return str1(v) and v:lower() or nil
end

-- The place this window stands at when the crew has 2+ stations, else nil (no filter).
local function myStation()
	local multi = call("MultiStation")
	if multi == false then return nil end
	if multi == nil then
		local list = call("Stations")
		if type(list) ~= "table" or #list < 2 then return nil end
	end
	return placeName(call("MyStation"))
end
DR.ButtonStation = myStation

local function stationOf(c)
	if type(c) ~= "table" then return nil end
	return placeName(call("StationOf", c.name)) or placeName(c.station)
end

local function atStation(c, station)
	if not station then return true end
	local s = stationOf(c)
	return s == nil or s == station
end

---------------------------------------------------------------------------
-- Raid summons (2.1): the queue of raiders, and who takes whom
---------------------------------------------------------------------------

local CALL_AGAIN = 30 -- a summoner without Wuber is asked again after this long
local calls = {}      -- [summoner key] = { name, at }: the runner asked them in party/raid chat
DR.calls = calls
local raidTold = {}   -- [raider key] = when the raidsum whisper went

local function raidRows()
	local r = call("RaidQueue")
	return type(r) == "table" and r or {}
end

local function rowUnit(row) return type(row) == "table" and row.name and units()[W.Key(row.name) or ""] or nil end
local function settled(s) return s == "waiting" or s == "arrived" or s == "done" or s == "dropped" end

-- Not claimed by any summoner, and not summoned yet.
local function rowFree(row)
	return not str1(row.claimedBy) and not settled(row.state) and row.state ~= "summoning"
end

-- The raid's summoners in cast order that can cast now: { key, free }. A summoner holding a
-- claim (or casting) is not free.
local function raidSummoners(rows)
	local keys = call("Summoners")
	keys = type(keys) == "table" and keys or {}
	if #keys == 0 and W.IsWarlock() then keys = { W.myKey } end
	local info = {}
	local rw = call("RaidWarlocks")
	for _, r in ipairs(type(rw) == "table" and rw or {}) do
		if type(r) == "table" and r.key then info[r.key] = r end
	end
	local out = {}
	for _, k in ipairs(keys) do
		local shards
		if k == W.myKey then
			shards = call("Shards")
		else
			local r, p = info[k], DR.peers and DR.peers[k]
			shards = (r and r.shards) or (p and p.shards)
		end
		local busy = k == W.myKey and DR.cast ~= nil
		for _, row in ipairs(rows) do
			if row.claimedBy == k and not settled(row.state) then busy = true end
		end
		local dry = opts().needShards ~= false and tonumber(shards) == 0
		if (k == W.myKey or (units()[k] and call("Online", units()[k]) ~= false)) and not dry then out[#out + 1] = { key = k, free = not busy } end
	end
	return out
end

-- Who takes whom: the free summoners in order each take the next free raider, so two
-- summoners never plan the same one (every window works this out from the same queue).
-- Returns { {key, row} } in summoner order, and the rows.
function DR.RaidAssign()
	local rows = raidRows()
	local free = {}
	for _, row in ipairs(rows) do
		local unit = rowUnit(row)
		if type(row) == "table" and rowFree(row) and not row.here and unit and call("Online", unit) ~= false then free[#free + 1] = row end
	end
	local out, i = {}, 0
	for _, s in ipairs(raidSummoners(rows)) do
		if s.free then
			i = i + 1
			if free[i] then out[#out + 1] = { key = s.key, row = free[i], index = i } end
		end
	end
	return out, rows
end

---------------------------------------------------------------------------
-- 2.4: the game's own word on a group member's summon (a rider with Wuber or without)
---------------------------------------------------------------------------
-- C_IncomingSummon.IncomingSummonStatus(unit) answers for any group member: a summon is waiting (1), was
-- accepted (2) or was declined (3). Nothing of it is proven in this client yet, so every doubt ends in
-- "nothing is known", which leaves each row and the button exactly as they are without it:
--   * the call may be missing, or raise: nothing is known;
--   * its answer may be secret (in an instance): nothing is known, and the answer found once it is readable
--     again has no known age;
--   * "accepted" and "declined" stay for a couple of minutes after the summon is over, so those two count
--     only when this window saw the answer change to them, after the latest cast on that rider (the crew's
--     c.castAt, or this window's own: seen[key].cast). An answer already there at the first look is of
--     unknown age and never counts, "waiting" included. A "waiting" this window saw appear needs no cast of
--     ours, but a summon box that the game says has been up longer than SUMMON.HOLD_MAX is not believed (a box
--     lasts 2 to 3 minutes).
-- Looked at once a second (DR.CastWatch, the drive tick: no ticker and no event of its own), only for riders
-- in the group who are not here yet. Painting only reads what the last look found.
local SUMMON = { HOLD_MAX = 200, STALE = 3 }
local seen = {} -- [rider key] = { st = "none"|"waiting"|"accepted"|"declined" or nil, at, first, look, cast }

local function summonCode(name, fallback)
	local e = rawget(_G, "Enum")
	local s = type(e) == "table" and rawget(e, "SummonStatus") or nil
	return (type(s) == "table" and num(s[name])) or fallback
end

-- What the game says about this unit's summon now, in Wuber's words; nil when nothing is known.
local function summonRead(unit)
	local api = rawget(_G, "C_IncomingSummon")
	local fn = type(api) == "table" and api.IncomingSummonStatus
	if type(fn) ~= "function" or not unit then return nil end
	local ok, v = pcall(fn, unit)
	v = ok and num(v) or nil
	if not v then return nil end
	if v == summonCode("Pending", 1) then return "waiting" end
	if v == summonCode("Accepted", 2) then return "accepted" end
	if v == summonCode("Declined", 3) then return "declined" end
	return "none"
end

-- (#83) A /reload empties `seen`. A "waiting" this window saw appear is kept in the saved data (W.db.drive.summonWait,
-- [rider key] = { at, look }) and believed again at the first look after a /reload, if that look comes soon
-- after the last one of the window before. The game clock runs on over a /reload and starts again at a relog,
-- so an old record (or one from the future) is never believed.
local RELOAD_GAP = 30
local function waitStore(create)
	local d = W.db and W.db.drive
	if type(d) ~= "table" then return nil end
	if type(d.summonWait) ~= "table" then
		if not create then return nil end
		d.summonWait = {}
	end
	return d.summonWait
end

-- Is this saved record still good at game time t? (its last look was lately, and the summon is not over 200 s old)
local function waitFresh(r, t)
	return type(r) == "table" and num(r.at) and num(r.look) and r.look <= t and t - r.look <= RELOAD_GAP
		and r.at <= t and t - r.at <= SUMMON.HOLD_MAX
end

local function summonLook(key, unit, t)
	local st = summonRead(unit)
	local e = seen[key]
	if not e then
		e = {}
		seen[key] = e
	end
	e.look = t
	local store = waitStore(false)
	local kept = store and store[key]
	if st == nil then
		e.st, e.at, e.first = nil, nil, nil
	elseif e.st == nil and st == "waiting" and waitFresh(kept, t) then
		e.st, e.at, e.first = st, kept.at, nil -- seen to appear before the /reload
	elseif e.st == nil then
		e.st, e.at, e.first = st, t, true -- there at the first look: how old it is, nobody knows
	elseif e.st ~= st then
		e.st, e.at, e.first = st, t, nil -- this window saw it change
	end
	if e.st == "waiting" and not e.first then
		store = waitStore(true)
		if store then
			for k, r in pairs(store) do
				if k ~= key and not waitFresh(r, t) then store[k] = nil end -- old records go, so the table cannot grow for ever
			end
			store[key] = { at = e.at, look = t }
		end
	elseif kept then
		store[key] = nil
	end
end

-- One look at every rider in the group who is not here yet (the queue's joined, summoning and waiting riders;
-- in raid mode the raid queue's rows). Riders who left that set are forgotten.
function DR.SummonLook(t)
	local api = rawget(_G, "C_IncomingSummon")
	if type(api) ~= "table" or type(api.IncomingSummonStatus) ~= "function" then
		for key in pairs(seen) do seen[key] = nil end -- no such call on this client: nothing is known, ever
		return
	end
	t = t or now()
	local u, live = units(), {}
	if mode() == "raid" then
		for _, r in ipairs(raidRows()) do
			local key = type(r) == "table" and not r.here and r.state ~= "arrived" and r.state ~= "done" and r.state ~= "dropped"
				and r.name and W.Key(r.name)
			if key and u[key] then
				live[key] = true
				summonLook(key, u[key], t)
			end
		end
	else
		for key, c in pairs(DR.customers or {}) do
			local s = type(c) == "table" and c.state
			if u[key] and (s == "joined" or s == "summoning" or s == "waiting") then
				live[key] = true
				summonLook(key, u[key], t)
			end
		end
	end
	for key in pairs(seen) do
		if not live[key] then seen[key] = nil end
	end
end

local function riderKey(c)
	if type(c) == "table" then return str1(c.key) or (str1(c.name) and W.Key(c.name)) or nil end
	return str1(c) and W.Key(c) or nil
end

-- For a rider's row (a queue customer or a raid row): "waiting", "accepted" or "declined" and since when,
-- or nil: the row says what it says without this.
-- A rider WITH Wuber always gets nil. For that rider Wuber's own path (the ritual watcher, the stages their
-- own Wuber shows them, their arrival) is the truth, and the game's sticky answer could contradict it for
-- minutes: one rider never gets two answers, and the one both screens share wins.
function DR.SummonSeen(c)
	local key = riderKey(c)
	local e = key and seen[key]
	if not e or e.st == nil or e.st == "none" then return nil end
	local t = now()
	if t - (e.look or -1e9) > SUMMON.STALE then return nil end -- nobody looked lately (the tick stood still)
	if e.st == "waiting" then
		if e.first or t - e.at > SUMMON.HOLD_MAX then return nil end -- (first: see DR.SummonPending)
	else
		local cast = math.max(type(c) == "table" and num(c.castAt) or -1e9, e.cast or -1e9)
		if e.first or cast == -1e9 or e.at < cast then return nil end -- older than the latest cast, or no cast of ours
	end
	if call("HasWuber", c) then return nil end
	return e.st, e.at
end

-- The double-summon guard: true while the game says this rider (a customer, a raid row or a name; with Wuber
-- or without) has a summon waiting now: another Warlock's, or an earlier one of ours. A second summon would
-- only waste a Soul Shard. False when nothing is known (no such call, a secret answer, no look in the last
-- seconds) or when the game has said "waiting" for longer than a summon box lasts (SUMMON.HOLD_MAX): then the
-- cast goes as it always did.
function DR.SummonPending(c)
	local key = riderKey(c)
	local e = key and seen[key]
	if not e or e.st ~= "waiting" then return false end
	-- A "waiting" that was already there at the first look is not believed either: until this call is proven in the
	-- game, only a summon this window saw APPEAR holds a cast back. (A summon comes from somebody in the rider's own
	-- group, so a real one appears while the rider is in ours and is seen to; an answer that is simply always
	-- "waiting" on some client must never lock a paying rider out.)
	if e.first then return false end
	local t = now()
	return t - (e.look or -1e9) <= SUMMON.STALE and t - e.at <= SUMMON.HOLD_MAX
end

---------------------------------------------------------------------------
-- The ritual: who is being summoned right now
---------------------------------------------------------------------------

DR.cast = nil -- my own ritual: { name, at, guid, channel, stopped }

-- The customer a ritual is running for and the one casting it, or nil. With `station`, only
-- a ritual for a rider of that station (another station's portal is not ours to click).
function DR.RitualBusy(station)
	if DR.cast then return DR.cast.name or "?", W.myKey end
	if mode() ~= "raid" then -- (sell customers are not served in raid mode: a stale row must not lock the button)
		for _, c in pairs(DR.customers or {}) do
			if type(c) == "table" and c.state == "summoning" and atStation(c, station) then return c.name, c.caster end
		end
	end
	if mode() == "raid" then
		for _, r in ipairs(raidRows()) do
			if type(r) == "table" and r.state == "summoning" and str1(r.claimedBy) then return r.name, r.claimedBy end
		end
	end
	return nil
end

-- A rider who could be summoned now: in the group, online, not here, of my station.
-- (run 1 item 8) The second value says which check failed, for DR.NextSummon's debug note.
local function summonable(c, unit, station)
	if c.state ~= "joined" then return false, "state " .. tostring(c.state) end
	if not unit then return false, "not found in the group" end
	if call("Online", unit) == false then return false, "offline" end
	if call("Here", unit) then return false, "already here" end
	if not atStation(c, station) then return false, "another station" end
	-- (BRIEF18 c) never a rider for a place we left (DR.PlaceStale: not summoned, not paying)
	if call("PlaceStale", c) == true then return false, "place changed" end
	return true
end

-- The customer to summon next: in the group, online, not here, of my station. A row
-- clicked first wins. (2.4) Never a rider the game says has a summon waiting already
-- (DR.SummonPending): the plan then holds no cast for them, so the click wastes no Soul Shard.
function DR.NextSummon(station)
	local best
	local u = units()
	-- (run 1 item 8) why each listed rider is not summonable now: DR.whyNoSummon[key] = reason, and one
	-- line in DR.whyNoSummonText ("Dan: already here; ..."), for /w debug; never said in chat
	local why, text = {}, {}
	DR.whyNoSummon, DR.whyNoSummonText = why, nil
	for _, c in ipairs(sorted()) do
		local can, reason = summonable(c, u[c.key], station)
		if can and call("SummonPending", c) == true then can, reason = false, "summon pending" end
		if can then
			if c.priority then return c end
			best = best or c
		else
			local wk = riderKey(c) -- a listed rider can lack .key (only a name): never index by nil
			if wk then why[wk] = reason end
			text[#text + 1] = tostring(c.name) .. ": " .. tostring(reason)
		end
	end
	DR.whyNoSummonText = #text > 0 and table.concat(text, "; ") or (best and nil or "nobody listed")
	return best
end

-- (2.4) The first rider DR.NextSummon passes over only because they have a summon waiting already, or nil:
-- what the button says when there is nobody else to summon.
function DR.SummonHeld(station)
	local u = units()
	for _, c in ipairs(sorted()) do
		if summonable(c, u[c.key], station) and call("SummonPending", c) == true then return c end
	end
	return nil
end

local function ritualName()
	local n = call("Ritual")
	if type(n) == "string" and n ~= "" then return n end
	return "Ritual of Summoning"
end

local function isRitual(spellID)
	spellID = num(spellID)
	if spellID then
		if spellID == DR.RITUAL_ID then return true end
		local getName = C_Spell and C_Spell.GetSpellName
		if type(getName) == "function" then
			local ok, name = pcall(getName, spellID)
			if ok and str(name) and name == ritualName() then return true end
		end
		return false
	end
	-- the client hides the spell: a cast right after our click is ours, and so is what follows while that
	-- cast of ours is open and has no channel yet (AUD-90: the real cast takes about 5 s before the channel)
	local intent = DR.castIntent
	if intent ~= nil and now() - intent.at < 3 then return true end
	local cast = DR.cast
	return cast ~= nil and not cast.channel and now() - (num(cast.at) or 0) < 12
end

local function findName(name)
	local c = call("Find", name)
	return type(c) == "table" and c or nil
end

local function castTarget()
	local intent = DR.castIntent
	if intent and now() - intent.at < 6 then return intent.name end
	local raid = mode() == "raid"
	local sent = DR.castSent
	if sent and now() - sent.at < 6 then
		local c = findName(sent.name)
		if c then return c.name end
		if raid then return sent.name end
	end
	local target = W.UnitName("target")
	local c = target and findName(target)
	if not c and raid then return target end
	return c and c.name or nil
end

-- 2.4: the Soul Shard as a second proof. The shard is said to go only when the summon completes, not when the
-- cast starts (other addons' code relies on it; not proven in this client). So the count is taken when the cast
-- is first seen (cast.shards) and again a second or more into the channel (cast.shardsMid, DR.CastWatch). Only
-- when both are known, the shard was still there mid-channel, and it is gone a second after the channel ended,
-- did the summon go out. A client that takes the shard with the cast shows it gone mid-channel already: then
-- nothing is proven, ever. An unknown or secret count, or a channel that ended before the second look, proves
-- nothing either. No shard gone is never read as "failed": when the count updates is not proven.
local function shardCount(name) return num(call("Shards", name)) end

local function shardProof(cast)
	local a, b = cast.shards, cast.shardsMid
	if not (a and b) or b < a then return false end
	local n = shardCount(cast.name)
	return n ~= nil and n < b
end

local function begin(guid, channel)
	local t = now()
	local cast = DR.cast
	if cast then
		if channel and not cast.channel then cast.channel = t end
		return
	end
	local name = castTarget()
	DR.cast = { name = name, at = t, guid = plain(guid), channel = channel and t or nil, shards = shardCount(name) }
	-- 2.4: my own latest cast on this rider: an "accepted" or "declined" the game said before now is stale
	local rk = name and W.Key(name)
	if rk then
		seen[rk] = seen[rk] or {}
		seen[rk].cast = t
	end
	if name then call("Do", "CAST", name) end
	-- a raid claim holds once the channel runs (A releases a claim with no channel after 40 s)
	if name and mode() == "raid" then call("Do", "CH", name) end
	call("Changed")
end

-- 2.3.0 (SPEC7 5.5): a group member without Wuber who holds my portal 2 s or more is a helper;
-- this window (the caster's) names them in HELP's field 2, once per summon
local function heldHelpers(cast, t)
	for key, h in pairs(cast.holds or {}) do
		if not h.told and (h.stop or t) - h.at >= 2 then
			h.told = true
			call("Do", "HELP", cast.name, h.name)
		end
	end
end

local function holdStart(unit, spellID)
	local cast = DR.cast
	if not (cast and cast.name and cast.channel) or mode() == "raid" then return false end
	-- only the ritual is a portal click: another channel (Mind Flay...) is not (a hidden spell id still counts)
	if num(spellID) and not isRitual(spellID) then return false end
	local u = plain(unit)
	if type(u) ~= "string" or not (u:match("^party%d+$") or u:match("^raid%d+$")) then return false end
	local name = W.UnitName(u)
	local key = name and W.Key(name)
	if not key or key == W.myKey or (DR.apps and DR.apps[key]) or call("TrustKey", key) or call("IsPlainSummoner", key) then
		return false
	end
	local m = call("CrewEntry", key)
	if m and m.role == "lock" then return false end
	cast.holds = cast.holds or {}
	local old = cast.holds[key]
	-- a hold that already ended short and was never told starts afresh on the next click
	if not old or (old.stop and not old.told) then cast.holds[key] = { name = name, at = now() } end
	return true
end

local function holdStop(unit)
	local cast = DR.cast
	local name = cast and cast.holds and W.UnitName(plain(unit))
	local h = name and cast.holds[W.Key(name) or "?"]
	if h and not h.stop then
		h.stop = now()
		heldHelpers(cast, h.stop)
	end
end

local function finish(ok)
	local cast = DR.cast
	if not cast then return end
	if ok and cast.holds then heldHelpers(cast, now()) end
	DR.cast, DR.castIntent, DR.castIdle = nil, nil, nil
	if cast.name then call("Do", "END", cast.name, ok and 1 or 0) end
	if ok and cast.name and mode() == "raid" then call("LogRaid", cast.name) end
	call("Changed")
end
DR.CastFinish = finish

local function mine(unit) return plain(unit) == "player" end

-- The customer of a crew member's ritual this window is to help with, or nil.
local function helping()
	if DR.cast then return nil end
	-- this window just clicked its own summon (a raid has several casting at once)
	local intent = DR.castIntent
	if intent and now() - intent.at < 6 then return nil end
	-- two stations can channel at once: a click here helps the ritual of this station
	local name, caster = DR.RitualBusy(myStation())
	if name and caster and caster ~= W.myKey then return name end
	return nil
end

-- How many helpers have clicked the portal of the ritual for this customer.
local function helpers(name)
	local c = name and findName(name)
	local n = 0
	for _ in pairs(type(c) == "table" and type(c.helps) == "table" and c.helps or {}) do n = n + 1 end
	return n
end

local function helpSeen()
	local o = opts()
	return o.helpSeen ~= nil and o.helpSeen ~= "" and o.helpSeen == W.Build()
end

W.On("UNIT_SPELLCAST_SENT", function(unit, target, _, spellID)
	if not mine(unit) or helping() or not isRitual(spellID) then return end
	target = str(target)
	if target then
		DR.castSent = { name = target, at = now() }
		-- 2.3.0 (SPEC7 5.10): this window targets a rider for the summon
		local c = findName(target)
		if c and mode() ~= "raid" then
			W.Fire("DRIVE_RITUAL", c.name, "t", { mine = true, key = c.key, rider = c.name, caster = W.myKey,
				ride = c.wuberRide or c.rideId })
		end
	end
end)

W.On("UNIT_SPELLCAST_START", function(unit, guid, spellID)
	if mine(unit) and not helping() and isRitual(spellID) then begin(guid, false) end
end)

-- A channel of this character's own spell (Drain Soul, Arcane Missiles...): not a portal click.
-- Only when the client shows the spell id; the ritual itself always counts as a click.
local function ownChannel(spellID)
	local id = num(spellID)
	if not id or id == DR.RITUAL_ID then return false end
	local known = rawget(_G, "IsPlayerSpell") or rawget(_G, "IsSpellKnown")
	if type(known) ~= "function" then return false end
	local ok, yes = pcall(known, id)
	return ok and plain(yes) == true and not isRitual(id)
end

---------------------------------------------------------------------------
-- A summoner without Wuber (2.1): the runner's window watches their party/raid unit
---------------------------------------------------------------------------

local watching = {} -- [summoner key] = { name, channel, stopped }: their ritual, seen from here
DR.watching = watching

-- The key and unit of a crew summoner without Wuber, when this window is the runner.
local function plainCaster(unit)
	local u = plain(unit)
	if type(u) ~= "string" or not (u:match("^party%d+$") or u:match("^raid%d+$")) then return nil end
	local name = W.UnitName(u)
	local key = name and W.Key(name)
	if not key or key == W.myKey or not (DR.IsPlainSummoner and DR.IsPlainSummoner(key)) then return nil end
	if not (DR.RunnerWindow and DR.RunnerWindow()) then return nil end
	return key, u
end

-- Whom they summon: the rider the runner asked them for, else their target.
local function plainTarget(key, unit)
	local cl = calls[key]
	if cl and now() - cl.at < 90 then return cl.name end
	local tn = W.UnitName(unit .. "target")
	if not tn then return nil end
	local c = findName(tn)
	if c then return c.name end
	return mode() == "raid" and tn or nil
end

local function plainStart(unit, spellID)
	local key, u = plainCaster(unit)
	if not key or watching[key] then return end
	if num(spellID) then
		if not isRitual(spellID) then return end
	elseif not (calls[key] and now() - calls[key].at < 90) then
		return -- the spell is hidden: only right after we asked them
	end
	local name = plainTarget(key, u)
	if not name then return end
	watching[key] = { name = name, channel = now() }
	calls[key] = nil
	if mode() == "raid" then
		-- the call click was the claim; this says their channel started (A's CH)
		local claimed
		for _, r in ipairs(raidRows()) do
			if type(r) == "table" and r.claimedBy == key and W.Key(r.name) == W.Key(name) then claimed = true end
		end
		if not claimed then call("Do", "CAST", name, key) end
		call("Do", "CH", name, key)
	else
		call("Do", "CAST", name, key)
	end
	call("Changed")
end

-- Their channel ended: held 2 s or more (or a helper said they clicked) = the summon went.
local function plainStop(unit)
	local key = plainCaster(unit)
	local wt = key and watching[key]
	if not wt or wt.stopped then return end
	wt.stopped = true
	local held = now() - wt.channel
	W.After(1, function()
		if watching[key] ~= wt then return end
		watching[key] = nil
		call("Do", "END", wt.name, (helpers(wt.name) >= 1 or held >= 2) and 1 or 0, key)
		call("Changed")
	end)
end

W.On("UNIT_SPELLCAST_CHANNEL_START", function(unit, guid, spellID)
	if not mine(unit) then
		if holdStart(unit, spellID) then return end
		plainStart(unit, spellID)
		return
	end
	local name = helping()
	if name then
		-- clicking a crew member's portal makes this character channel too (any class): the
		-- caster is told
		if ownChannel(spellID) then return end
		call("Do", "HELP", name)
		return
	end
	if isRitual(spellID) then begin(guid, true) end
end)

W.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, guid, spellID)
	if not (mine(unit) and not helping() and isRitual(spellID)) then return end
	begin(guid, false)
	local cast = DR.cast
	-- a ritual that is one cast and no channel is over now
	W.After(1.5, function()
		if DR.cast == cast and cast and not cast.channel then finish(true) end
	end)
end)

W.On("UNIT_SPELLCAST_CHANNEL_STOP", function(unit)
	if not mine(unit) then
		holdStop(unit)
		plainStop(unit)
		return
	end
	local cast = DR.cast
	if not (cast and cast.channel) or cast.stopped then return end
	if cast.holds then heldHelpers(cast, now()) end
	-- The channel is over. Did the summon go out, or was the ritual dropped? A helper who
	-- clicked the portal has said so (HELP): that settles it.
	if helpers(cast.name) >= 1 then
		finish(true)
		return
	end
	local held = now() - cast.channel
	cast.stopped = true
	W.After(1, function()
		if DR.cast ~= cast then return end
		if helpers(cast.name) >= 1 then
			finish(true)
		elseif shardProof(cast) then
			-- 2.4: no helper was heard (two without Wuber who clicked within a moment of each other are never
			-- heard: a hold counts from 2 s), but the Soul Shard went while the channel ran: the summon went out
			finish(true)
		elseif helpSeen() and mode() ~= "raid" then -- raid HELPs never reach helpers(): fall back to held time
			-- this client does tell when a helper clicks, and none did: nothing was summoned
			finish(false)
		else
			-- never told: held for a while means the helpers clicked, dropped at once cancelled
			finish(held >= 2)
		end
	end)
end)

local function failed(unit, guid, spellID)
	if not mine(unit) then return end
	local cast = DR.cast
	if not cast or cast.channel then return end
	guid = plain(guid)
	if cast.guid and guid and cast.guid ~= guid then return end -- another press during the cast
	if not isRitual(spellID) then return end
	finish(false)
end

W.On("UNIT_SPELLCAST_FAILED", failed)
W.On("UNIT_SPELLCAST_INTERRUPTED", failed)

local function busyWith(fn)
	if type(fn) ~= "function" then return false end
	local ok, name = pcall(fn, "player")
	if not ok then return true end
	if type(issecretvalue) == "function" then
		local okS, hidden = pcall(issecretvalue, name)
		if not okS or hidden == true then return true end -- a hidden answer still counts as busy
	end
	return name ~= nil
end

-- Once a second: a ritual whose end the events did not tell.
function DR.CastWatch(t)
	t = t or now()
	call("SummonLook", t) -- 2.4: the game's word on each waiting rider's summon, once a second
	for key, wt in pairs(watching) do
		-- a friend's ritual whose end we never saw (out of range): over after 330 s
		if t - wt.channel > 330 then
			watching[key] = nil
			call("Do", "END", wt.name, 0, key)
		end
	end
	local cast = DR.cast
	-- 2.4: the Soul Shard count a second or more into my channel (shardProof): still there, or gone with the cast
	if cast and cast.channel and not cast.stopped and cast.shardsMid == nil and t - cast.channel >= 1 then
		cast.shardsMid = shardCount(cast.name) or false
	end
	if not cast or t - cast.at < 3 then return end
	if t - cast.at > 330 then
		finish(false)
		return
	end
	if cast.stopped then return end -- its verdict is on the way
	if busyWith(UnitCastingInfo) or busyWith(UnitChannelInfo) then
		DR.castIdle = nil
		return
	end
	DR.castIdle = (DR.castIdle or 0) + 1
	if DR.castIdle >= 2 then finish(cast.channel ~= nil and t - cast.channel >= 2) end
end

-- for other modules (REFACTOR-MAP section 2): set at the end, when every local holds its final value
Mod.CALL_AGAIN = CALL_AGAIN
Mod.COLORS = COLORS
Mod.HEIGHT = HEIGHT
Mod.SAY = SAY
Mod.VERB = VERB
Mod.WIDTH = WIDTH
Mod.btnDB = btnDB
Mod.call = call
Mod.calls = calls
Mod.due = due
Mod.isLeader = isLeader
Mod.mode = mode
Mod.money = money
Mod.myStation = myStation
Mod.now = now
Mod.opts = opts
Mod.raidTold = raidTold
Mod.ritualName = ritualName
Mod.settled = settled
Mod.short = short
Mod.sorted = sorted
Mod.state = state
Mod.str1 = str1
Mod.units = units
Mod.watching = watching
