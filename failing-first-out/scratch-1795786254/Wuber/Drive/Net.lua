-- Module: Drive.Net
-- Purpose: Engine to network bridge (was Drive_Net.lua).
-- API: W.Drive, DR.net, DR.NetDriver, DR.NetBeacon, DR.NetCheck, DR.NetAfterChange, DR.NetHeldBack,
--   DR.ENGINE, DR.NetAttach, W.PassphraseOn, DR.PassWire, DR.PassHeard
-- Internals: (none) (2.3.0: a 2.3.0 rider's request with a new ride id takes their old row off first,
--   unless a raincheck pays for that row or its summon is under way and the rider didn't cancel it:
--   then the request is answered N busy)
-- Uses: (none)
-- Later: Drive.Danger (DR.DangerLevel: beacon D field 18), Drive.Raincheck (DR.RaincheckRedeem: R field 7,
--   A's last field), Drive.Rank (DR.RankCount: beacon D field 22)
-- Events: listens login, Listen DRIVE_STATE, Listen DRIVE, Listen DRIVE_REMOVED, Listen DRIVE_CREW,
--   Listen DRIVE_RANK, Listen SETTINGS, Listen PROVIDER; fires DRIVE_ALERT
-- Standalone: no
-- Test: tests/drive/net_test.lua
-- From: Drive_Net.lua 1-631 (Wuber 2.2.1)
--
-- Wuber Drive: the network bridge (agent B). Ported from Ritual Rides 1.4.1's Wuber.lua.
--
-- The built-in engine is Wuber's driver on the network through W.SetEngine (Net.lua), with
-- the same table a provider hands WuberAPI.SetDriver: beacon, onRequest, onCancel, onRating.
--
--   beacon      what riders see: one crew window only (DR.NetDriver(): in a group the
--               leader's, ungrouped the captain's), and only while open. Sent again whenever
--               a field riders should see at once changes (open, paused, busy, price, dest,
--               service, team, seats, queue).
--   onRequest   a ride request (Wuber's R): taken only for our destination and a price we
--               show (or showed in the last 150 s; that price is kept for the ride). A gets
--               the price the ride is really charged. The rider's click also whispers
--               "WTB summon to X for N", which the engine reads as a request too: both end in
--               one customer, whichever comes first.
--   stages      each step goes back to the rider once, in order, from the window that took
--               the request: invited, summoning, portal (the engine's "waiting"), arrived,
--               paid, done. A rider put back in the queue keeps the ride for 10 minutes.
--   queue       a Wuber rider in the queue is told their place (1 = next) and the wait, and
--               the same place again every 60 s while they wait (QUEUE_AGAIN).
--   onCancel    off the list in every crew window unless the summon has begun; their
--               whispers are not taken as requests for 30 s.
--   onRating    "Dan Miller rated the ride 5 stars", once.
--
-- Nothing here runs at load time except defining functions: other Drive files are reached
-- from W.OnLogin, events and timers only, and always nil-guarded.

local ADDON, W = ...
local Mod = W.Module("Drive.Net", {})
W.Drive = W.Drive or {}
local DR = W.Drive

local plain, str, num = W.Plain, W.Str, W.Num

-- the engine's customer state -> the stage the rider is shown (each sent once, in order)
local STAGE = { invited = "invited", summoning = "summoning", waiting = "portal", arrived = "arrived", paid = "paid", done = "done" }
local STAGE_RANK = { invited = 1, summoning = 2, portal = 3, arrived = 4, paid = 5, done = 6 }

local HOLD = 60         -- seconds a declined rider's "WTB summon to" whisper is not a request
local CANCEL_HOLD = 30  -- seconds a rider who cancelled is not taken by whisper at all
local PRICE_KEPT = 150  -- seconds a price riders were shown is still honoured
local RIDE_KEPT = 600   -- seconds a Wuber ride still belongs to a rider put back in the queue
local QUEUE_AGAIN = 60  -- seconds after which a rider still in the queue is sent the same place again

local NET = {
	rides = {},      -- [customer key] = { id, buyer, stage (rank sent), price (kept) or nil, at, pos, posAt, label }
	held = {},       -- [key] = when a Wuber request was declined
	cancelled = {},  -- [key] = when the rider cancelled on Wuber
	rated = {},      -- [rideId] = true
	shown = {},      -- [price] = when riders were last shown it
	sig = nil,       -- the beacon's signature last time
	attached = false,
	toldProvider = false,
}
DR.net = NET -- read by the tests and the console

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

local function charDB() return W.Char() end

local function myPrice()
	local p = tonumber(charDB().price) or W.MIN_PRICE
	if p < W.MIN_PRICE then p = W.MIN_PRICE end
	return math.floor(p)
end

-- The destination as Wuber carries it (letters, digits, spaces, ' and -, 32 bytes at most).
local function wuberDest(text)
	if W.CleanDest then return W.CleanDest(text or "") end
	local d = tostring(text or ""):gsub("[^%w%s'%-]", ""):gsub("%s+", " "):gsub("^ ", "")
	return (d:sub(1, 32):gsub(" $", ""))
end

local function destHere()
	local ch = call("char")
	local typed = type(ch) == "table" and ch.dest
	if type(typed) == "string" and typed ~= "" then return typed end
	-- no place typed: where the crew summons to (the Warlock's city), else where we stand
	local served = call("ServedPlaces")
	if type(served) == "table" and type(served[1]) == "string" and served[1] ~= "" then return served[1] end
	local d = call("Dest")
	if type(d) ~= "string" or d == "" then d = (W.DestHere and W.DestHere()) or "" end
	return d
end

local function sameDest(a, b)
	a, b = wuberDest(a), wuberDest(b)
	if a == "" or b == "" then return false end
	if W.Key(a) == W.Key(b) then return true end
	if W.NormPlace then
		local na, nb = W.NormPlace(a), W.NormPlace(b)
		if na and nb and na ~= "" and na == nb then return true end
	end
	return false
end

---------------------------------------------------------------------------
-- Which window is the driver on the network
---------------------------------------------------------------------------

local function isLeader()
	local v = call("IsLeader")
	if v == nil then
		if not W.InGroup() then return true end
		return type(UnitIsGroupLeader) == "function" and plain(UnitIsGroupLeader("player")) == true
	end
	return v == true
end

-- The key of the group's leader, or nil.
local function leaderKey()
	local roster = call("Roster")
	if type(roster) ~= "table" then return nil end
	for _, m in ipairs(roster) do
		if type(m) == "table" and m.unit and type(UnitIsGroupLeader) == "function" then
			local ok, lead = pcall(UnitIsGroupLeader, m.unit)
			if ok and plain(lead) == true then return m.key end
		end
	end
	return nil
end

local function crewRole(key)
	local crew = call("Crew")
	if type(crew) ~= "table" then return nil end
	for _, m in ipairs(crew) do
		if type(m) == "table" and m.key == key then return m.role end
	end
	return nil
end

-- Whether this window is the one riders see. In a group: the leader's (when the leader is a
-- Warlock who drives); a helper leading the group leaves it to the captain's window.
-- Ungrouped: the captain's (a solo driver is his own captain).
function DR.NetDriver()
	local role = call("Role")
	if role ~= nil and role ~= "driver" then return false end
	local captain = call("IsCaptain")
	if captain == nil then captain = true end
	if not W.IsWarlock() then
		-- a runner of another class: riders see and whisper the runner
		return captain == true and call("IsRunner") == true
	end
	if not W.InGroup() then return captain == true end
	-- a Warlock summoner whose runner is no Warlock: the runner's window is on the network
	local cap = not captain and call("CaptainKey")
	if cap and DR.units and DR.units[cap] and DR.peers and DR.peers[cap] and DR.peers[cap].role == "H" then return false end
	if isLeader() then return true end
	local lk = leaderKey()
	-- (a crew Warlock leading keeps the captain silent, unless the crew list says he has no Wuber
	-- (app == false): then no window of his is on the network and the captain's must be)
	if lk and call("IsCrewKey", lk) and crewRole(lk) ~= "helper" then
		local e = call("CrewEntry", lk)
		if not (type(e) == "table" and e.app == false) then return false end
	end
	-- the leader is a helper, has no Wuber or is not one of us: the captain's window drives
	return captain == true
end

-- The crew in the group now, me included (1 to 3): riders bring 3 - team helpers.
local function teamHere()
	local n = 1
	local roster = call("Roster")
	if type(roster) == "table" then
		for _, m in ipairs(roster) do
			if type(m) == "table" and m.key and call("IsCrewKey", m.key) then n = n + 1 end
		end
	end
	return math.min(3, n)
end

local function count(state)
	local n = call("Count", state)
	return tonumber(n) or 0
end

-- What this window tells riders, or nil (closed, locked, or not the window on the network).
function DR.NetBeacon()
	if call("Lock") ~= nil then return nil end
	if not call("Active") then return nil end
	-- selling only: raid summons never beacon
	local selling = call("Selling")
	if selling == nil then selling = call("IsOpen") end
	if not selling then return nil end
	if not DR.NetDriver() then return nil end
	-- a runner who is no Warlock and has nobody to summon is not open to riders
	local chosen = call("Summoners")
	if not W.IsWarlock() and (type(chosen) ~= "table" or #chosen == 0) then return nil end
	local state = "open"
	-- nobody in the group can invite (a helper or a stranger leads): not open to riders
	if call("IsPaused") or call("CanInvite") == false then
		state = "paused"
	elseif call("Busy") then
		state = "busy"
	end
	local maxGroup = tonumber(call("MaxGroup")) or tonumber(opts().maxGroup) or 5
	if maxGroup < 3 then maxGroup = 5 end
	local size = tonumber(call("GroupSize")) or 1
	local c = charDB()
	-- "Summoned by Bea" on the rider's card when the runner is not the one who summons
	local summoner
	if type(chosen) == "table" and chosen[1] and chosen[1] ~= W.myKey then summoner = call("NameOf", chosen[1]) end
	-- the test addon's test mode (DR.SimHooks.peers, review 2.2 #3): off the public network;
	-- only riders who run the test mode too hear this driver ({ [key] = name }, maybe empty)
	local only
	local sim = DR.SimHooks
	if type(sim) == "table" and type(sim.peers) == "function" then
		local okP, set = pcall(sim.peers)
		if okP and type(set) == "table" then only = set end
	end
	-- 2.3.0: the crew's PvP danger (D field 18 "level:seconds"), only when there is some
	local level, secs = call("DangerLevel")
	level = tonumber(level) or 0
	local rank = tonumber(call("RankCount")) or 0
	return {
		dest = wuberDest(destHere()), price = myPrice(), service = c.service,
		state = state, team = teamHere(), seats = math.max(0, maxGroup - size),
		queue = math.min(40, count("queued")), summoner = summoner, only = only,
		danger = level > 0 and level or nil, dangerSecs = level > 0 and math.floor(tonumber(secs) or 0) or nil,
		showPass = W.PassphraseOn() or nil, -- round 9: D field 19
		avgSummon = (call("SummonAvg")), -- FEAT-01: D field 21, the mean summon of 3+ whole rides (nil: not sent)
		rank = rank >= 1 and math.floor(rank) or nil, -- 2.4: D field 22, verified summons (nil when 0)
	}
end

local function providerBeacon()
	local b = DR.NetBeacon()
	if b then NET.shown[b.price] = now() end
	return b
end

local function signature()
	local b = DR.NetBeacon()
	if not b then return "off" end
	local peers = 0
	for _ in pairs(type(b.only) == "table" and b.only or {}) do peers = peers + 1 end
	return table.concat({ tostring(b.dest), tostring(b.price), tostring(b.service), b.state, b.team, b.seats, b.queue,
		tostring(b.summoner), b.only and ("p" .. peers) or "", b.danger or "", b.showPass and "s" or "" }, "~") -- (2.4) not b.rank: a new count waits for the next regular beacon
end

-- A change riders should hear about now (Net keeps beacons 5 s apart by itself).
local function checkBeacon()
	if not NET.attached then return end
	local sig = signature()
	if sig == NET.sig then return end
	NET.sig = sig
	W.SendBeacon()
end
DR.NetCheck = checkBeacon

---------------------------------------------------------------------------
-- (round 9, the author) The ride passphrase is off by default: a driver setting "Show ride passphrase"
-- (DR.Opt("showPass")). Riders see it only when their driver's beacon says so (D field 19); a crew
-- window follows its captain's setting (CFG field 12, heard from the captain only, kept in memory).
---------------------------------------------------------------------------

local passFrom = {} -- [captain key] = true: that captain's CFG said "show the passphrase"

-- true only when this character's setting is on (a crew member: its captain's setting).
function W.PassphraseOn()
	local okC, captain = pcall(function() return DR.IsCaptain() end)
	if not okC or captain ~= false then
		local okO, v = pcall(function() return DR.Opt("showPass") end)
		return okO and v == true
	end
	local cap = call("CaptainKey")
	return cap ~= nil and passFrom[cap] == true
end

-- CFG field 12: "1" while riders see the passphrase, else "" (an old CFG byte for byte).
function DR.PassWire() return W.PassphraseOn() and "1" or "" end

-- A CFG's field 12 from a crew window (Drive.Team): counts only from my captain.
function DR.PassHeard(key, v)
	local cap = call("CaptainKey")
	if not key or key ~= cap or key == W.myKey then return end
	local on = v == "1"
	if (passFrom[key] == true) == on then return end
	passFrom[key] = on or nil
	W.Fire("SETTINGS", "drive.showPass")
end

local function beaconNow()
	NET.sig = signature()
	W.SendBeacon()
end

---------------------------------------------------------------------------
-- The ride's steps, back to the rider
---------------------------------------------------------------------------

local function customerOf(key)
	local list = DR.customers
	return type(list) == "table" and list[key] or nil
end

-- Who the rider pays: the summoner's full name, when it is not this window.
local function payeeOf(c)
	local k = call("Payee", c.name)
	if not k or k == W.myKey then return nil end
	return call("NameOf", k) or nil
end

-- The rest of the crew (full names, not this window): the only others the rider's app lets
-- take the fare (review 2.2 #1).
local function crewNames()
	local list = call("Crew")
	local out = {}
	for _, m in ipairs(type(list) == "table" and list or {}) do
		if type(m) == "table" and not m.me and type(m.name) == "string" and m.key ~= W.myKey then out[#out + 1] = m.name end
	end
	return out
end

local function sendStage(c, r)
	local stage = STAGE[c.state]
	if not stage then return end
	local rank = STAGE_RANK[stage]
	if rank <= (r.stage or 0) then return end -- sent already (or a later one)
	r.stage = rank
	W.SendStage(r.id, stage, r.buyer, payeeOf(c), crewNames())
	if stage == "paid" or stage == "done" then r.over = true end
end

local function orderOf(c) return tonumber(c.order) or tonumber(c.at) or 0 end

-- Riders in the queue ahead of this one.
local function ahead(c)
	local n = 0
	for _, o in pairs(DR.customers or {}) do
		if o ~= c and o.state == "queued" and orderOf(o) < orderOf(c) then n = n + 1 end
	end
	return n
end

-- Every Wuber rider waiting in the queue whose place changed is told it. A rider still in the
-- queue whose last place is older than QUEUE_AGAIN is sent the same place again (the same P, by
-- the same whisper and outbox): a rider who hears no beacon of ours hears that we still keep him
-- (his Wuber gives up after NETK.QUEUE_SILENCE). Only riders in the queue: no queue, no message.
local function checkQueue()
	local t = now()
	for key, r in pairs(NET.rides) do
		local c = customerOf(key)
		if c and c.state == "queued" then
			local n = ahead(c)
			if r.pos ~= n + 1 then
				r.pos, r.posAt = n + 1, t
				W.SendQueue(r.id, n + 1, 60 * n, r.buyer)
			elseif t - (r.posAt or t) >= QUEUE_AGAIN - 0.01 then
				-- W.SendQueue sends a changed place only: the same place goes by W.SendTo, as it does
				r.posAt = t
				W.SendTo(r.buyer, "P", r.id, n + 1, 60 * n)
			end
			r.posAt = r.posAt or t
		elseif r.pos then
			r.pos, r.posAt = nil, nil -- out of the queue (invited): told again next time in it
		end
	end
end

-- A Wuber ride whose customer left the list: before the summon began, the rider is told
-- (N busy) instead of being left waiting; a cancel by the rider needs no answer.
local function rideGone(key, r, reason)
	NET.rides[key] = nil
	if r.over or (r.stage or 0) >= STAGE_RANK.summoning then return end
	if NET.cancelled[key] and now() - NET.cancelled[key] <= CANCEL_HOLD then return end
	W.DeclineRequest(r.id, reason or "busy", r.buyer)
end

local function stateChanged(c, was)
	local key = c and c.key
	local r = key and NET.rides[key]
	if not r then return end
	if c.state == "queued" then
		-- back in the queue (an invite declined, say): under 10 minutes old the ride is still
		-- theirs; an older one is over
		if (r.stage or 0) < STAGE_RANK.paid and now() - (r.at or -1e9) < RIDE_KEPT then
			if r.price then c.price = r.price end
			return
		end
		NET.rides[key] = nil
		c.wuberRide, c.wuberBuyer, c.wuberPrice = nil, nil, nil
		return
	end
	if not STAGE[c.state] and c.state ~= "lead" then
		-- dropped, blocked or otherwise off the list
		if customerOf(key) ~= c then rideGone(key, r) end
		return
	end
	-- joining sets the price to today's: the price the rider was shown stands
	if r.price then c.price = r.price end
	sendStage(c, r)
end

-- After every change: rides whose customer is gone, the queue places, the beacon.
local function afterChange()
	-- a queue restored after a /reload (W.Char().queue) keeps its Wuber rides
	for key, c in pairs(DR.customers or {}) do
		if type(c) == "table" and c.wuberRide and c.wuberBuyer and not NET.rides[key] then
			local stage = STAGE[c.state]
			NET.rides[key] = { id = c.wuberRide, buyer = c.wuberBuyer, stage = stage and STAGE_RANK[stage] or 0,
				price = c.wuberPrice, at = now(), label = c.wuberLabel }
			-- Net's own list of the request too: cancels and ratings still count
			if W.RestoreIncoming then W.RestoreIncoming(c.wuberRide, c.wuberBuyer, c.dest, c.wuberPrice or c.price, stage, c.wuberVer) end
		end
	end
	for key, r in pairs(NET.rides) do
		local c = customerOf(key)
		if not c then
			rideGone(key, r)
		elseif r.price and c.price ~= r.price and (c.state == "joined" or c.state == "queued" or c.state == "invited") then
			c.price = r.price
		end
	end
	checkQueue()
	checkBeacon()
end
DR.NetAfterChange = afterChange

---------------------------------------------------------------------------
-- Requests, cancels, ratings
---------------------------------------------------------------------------

local function wuberLine(msg)
	local v = call("WuberLine", msg)
	if v ~= nil then return v and true or false end
	return type(msg) == "string" and msg:find("^WTB summon to ") ~= nil
end

-- DR.requestFilters: a whisper request not taken. Anything from a rider who cancelled on
-- Wuber in the last 30 s, and Wuber's chat line from one just declined.
local function heldBack(name, source, msg)
	if source ~= "whisper" then return false end
	local k = W.Key(name)
	if not k then return false end
	local t = NET.cancelled[k]
	if t then
		if now() - t <= CANCEL_HOLD then return true end
		NET.cancelled[k] = nil
	end
	local at = NET.held[k]
	if not at then return false end
	if now() - at > HOLD then
		NET.held[k] = nil
		return false
	end
	return wuberLine(msg)
end
DR.NetHeldBack = heldBack

local function logNet(what)
	if type(DR.LogNet) == "function" then W.Safe("drive log", DR.LogNet, what) end
end

local function decline(ride, buyer, reason)
	logNet("wdec")
	local k = W.Key(buyer)
	if k then
		NET.held[k] = now()
		-- the rider's chat line came first and queued them: off the list again
		local c = customerOf(k)
		if c and (c.state == "queued" or c.state == "invited") and not NET.rides[k] and wuberLine(c.msg) and DR.Do then call("Do", "DROP", c.name) end
	end
	W.DeclineRequest(ride.id, reason, buyer)
end

local function isBlocked(key)
	if type(DR.BlockEntry) == "function" then
		local ok, e = pcall(DR.BlockEntry, key)
		if ok then return e ~= nil and e ~= false end
	end
	local d = W.db and W.db.drive
	return type(d) == "table" and type(d.blocklist) == "table" and d.blocklist[key] ~= nil
end

local function onRequest(ride)
	if type(ride) ~= "table" then return end
	local id, buyer = str(ride.id), str(ride.buyer)
	if not id or not buyer then return end
	logNet("wreq")
	local key = W.Key(buyer)
	if not key then return end
	if isBlocked(key) then
		call("BlockedAskToast", buyer)
		decline(ride, buyer, "blocked")
		return
	end
	if not call("IsOpen") or call("IsPaused") or call("Lock") ~= nil then
		decline(ride, buyer, "closed")
		return
	end
	if call("CanInvite") == false then
		decline(ride, buyer, "busy") -- nobody here can invite them now
		return
	end
	-- only for where we summon to, as riders see it (several stations: any open one)
	local here = destHere()
	local dest = str(ride.dest)
	local ours = dest and sameDest(dest, here)
	if dest and not ours and call("MultiStation") then
		for _, st in ipairs(call("Stations") or {}) do
			if st.open and sameDest(dest, st.place) then ours, here = true, st.place end
		end
	end
	if not ours then
		decline(ride, buyer, "closed")
		return
	end
	-- at the price now, or one riders were shown in the last 150 s (kept for this ride)
	local price = tonumber(plain(ride.price))
	local current = myPrice()
	local kept
	if not price or price < current then
		local at = price and NET.shown[price]
		local fresh = at and now() - at <= PRICE_KEPT
		if not fresh and price and W.PriceOk then fresh = W.PriceOk(price, current) end
		if not fresh then
			decline(ride, buyer, "price")
			beaconNow()
			return
		end
		kept = math.max(W.MIN_PRICE, math.floor(price))
	end
	-- (always locked at request time, a later price change never
	-- reaches this rider)
	kept = kept or math.max(W.MIN_PRICE, math.floor(current))
	local cancelledAt = NET.cancelled[key] -- the rider cancelled the ride before this request
	NET.held[key], NET.cancelled[key] = nil, nil
	-- 2.3.0: a new ride id from a rider whose old row (another ride, e.g. a paid one that failed) is
	-- still listed: that ride is over; the new one starts from a fresh row (never "paid" at once)
	-- A row a raincheck pays for (until its rider arrives), or a 2.3.0 rider's summon under way
	-- (summoning, waiting, arrived), keeps its ride unless the rider cancelled it: a second R with a
	-- new id is answered N busy then (the rider's app says try again). After the rider's cancel the
	-- new request replaces the row ("rebook"; a redeemed raincheck stays on its ride, and is used if
	-- the rider still takes that summon).
	local old = DR.customers and DR.customers[key]
	local oldRide = old and call("RideIdOf", old)
	local newVer = W.VerAtLeast and W.VerAtLeast(str(ride.riderVer), "2.3.0")
	if old and not oldRide and (old.state == "paid" or old.state == "done") then
		call("Remove", old, "rebook") -- a finished whisper or manual ride: the new Wuber ride starts fresh
	elseif oldRide and oldRide ~= id then
		local rank = call("Rank", old.state) or 0
		local held = old.voucher or (newVer and rank >= (call("Rank", "summoning") or 5) and rank <= (call("Rank", "arrived") or 7))
		if held and not cancelledAt then
			W.DeclineRequest(id, "busy", buyer)
			return
		end
		-- (a paid or done row of the old ride never carries over to the new ride id, any rider version)
		if newVer or held or old.state == "paid" or old.state == "done" then call("Remove", old, "rebook") end
	end
	local c = call("Request", buyer, "wuber", "WTB summon to " .. wuberDest(here) .. " (Wuber)")
	if type(c) ~= "table" then
		decline(ride, buyer, "blocked") -- one of the crew, or a name that can't be served
		return
	end
	local ckey = c.key or key
	NET.rides[ckey] = { id = id, buyer = buyer, stage = 0, price = kept, at = now(), label = ride.label }
	c.wuberRide, c.wuberBuyer, c.wuberPrice, c.wuberLabel = id, buyer, kept, ride.label
	-- 2.3.0: the rider's version (R field 6) for the live tracker (G)
	local ver = str(ride.riderVer) or str(ride.version)
	c.wuberVer = ver and W.Clean(ver, 12) or nil
	if kept then c.price = kept end
	local before = ahead(c)
	local charged = tonumber(c.price) or kept or current
	-- 2.3.0: a raincheck (R field 7) the book takes lowers the fare due; A's last
	-- field tells the rider it was taken. The book decides; the sender is the event's sender.
	local taken = ride.voucher ~= nil and call("RaincheckRedeem", ride.voucher, key, charged, c) == true
	if taken then
		-- the fare due is kept like a locked price; the crew windows hear it (ST flag v)
		NET.rides[ckey].price, c.wuberPrice = c.price, c.price
		if W.InGroup() then call("SendState", c) end
	elseif W.InGroup() and c.stTold ~= id and W.VerAtLeast and W.VerAtLeast(c.wuberVer, "2.3.0")
		and (tonumber(call("Rank", c.state)) or 0) >= (tonumber(call("Rank", "joined")) or 99) then
		-- (AUD-105) a rider already in the group who books again is joined at once, so the crew windows
		-- never see the join that tells them the ride id: they hear it now, once per ride
		c.stTold = id
		call("SendState", c)
	end
	W.AcceptRequest(id, (c.state ~= "queued" or before == 0) and 5 or 60 * before, buyer, charged, taken or nil)
	sendStage(c, NET.rides[ckey]) -- invited already (the invite goes out at once with room)
	checkQueue()                  -- still waiting: their place in the queue
	checkBeacon()
end

local function onCancel(rideId, buyer)
	rideId, buyer = str(rideId), str(buyer)
	if not rideId or not buyer then return end
	local c, key = call("Find", buyer)
	key = (type(c) == "table" and c.key) or key or W.Key(buyer)
	local r = key and NET.rides[key]
	if not r or r.id ~= rideId then return end
	NET.cancelled[key] = now()
	local rank = tonumber(call("Rank", c and c.state or "")) or 0
	local summoning = tonumber(call("Rank", "summoning")) or 99
	if type(c) == "table" and rank >= summoning then
		W.Print(c.name .. " cancelled on Wuber, but the summon has begun.")
		return
	end
	NET.rides[key] = nil
	if type(c) == "table" then
		call("Do", "DROP", c.name) -- first: the book frees a raincheck tied to this ride while it still has its id
		c.wuberRide, c.wuberBuyer, c.wuberPrice = nil, nil, nil
	end
	W.Print(W.CleanName(buyer) .. " cancelled their Wuber ride.")
end

local function onRating(rideId, buyer, stars)
	rideId, buyer, stars = str(rideId), str(buyer), tonumber(plain(stars))
	if not rideId or not buyer or not stars or NET.rated[rideId] then return end
	if isBlocked(W.Key(buyer) or "") then return end -- (never from a blocked rider)
	stars = math.floor(stars)
	if stars < 1 or stars > 5 then return end
	NET.rated[rideId] = true
	W.Print((W.CleanName(buyer) or buyer) .. " rated the ride " .. stars .. (stars == 1 and " star" or " stars") .. ".")
end

local function guarded(where, fn)
	return function(...)
		local ok, result = pcall(fn, ...)
		if not ok then
			W.Error(where, result)
			return nil
		end
		return result
	end
end

local ENGINE = {
	name = "Wuber",
	builtin = true,
	beacon = guarded("drive beacon", providerBeacon),
	onRequest = guarded("drive request", onRequest),
	onCancel = guarded("drive cancel", onCancel),
	onRating = guarded("drive rating", onRating),
}
DR.ENGINE = ENGINE

---------------------------------------------------------------------------
-- Attaching to Net
---------------------------------------------------------------------------

-- Sets or clears W.engine as the lock and the crew say. Returns whether it is attached.
function DR.NetAttach()
	local lock = call("Lock")
	local want = lock == nil and type(W.provider) ~= "table" and call("Active") == true
	if want and W.engine ~= ENGINE then
		W.SetEngine(ENGINE)
		NET.attached = true
		NET.sig = signature()
		W.SendBeacon()
	elseif not want and W.engine == ENGINE then
		W.SetEngine(nil)
		NET.attached = false
		NET.sig = nil
		W.SendBeacon() -- X: off the network
	end
	return NET.attached
end

local function addFilter()
	DR.requestFilters = DR.requestFilters or {}
	for _, f in ipairs(DR.requestFilters) do
		if f == heldBack then return end
	end
	table.insert(DR.requestFilters, heldBack)
end

W.OnLogin(function()
	addFilter()
	DR.NetAttach()
	W.Every(5, checkQueue) -- the place again for riders still in the queue (QUEUE_AGAIN)
end)

W.Listen("DRIVE_STATE", function(c, was)
	if type(c) == "table" then stateChanged(c, was) end
end)

W.Listen("DRIVE", function()
	if not NET.attached then return end
	afterChange()
end)

-- A customer left the list (A fires why: "timeout", "expired", "declined", "missing",
-- "left", "drop", "blocked", "done"): a Wuber rider not yet summoned is told N busy.
W.Listen("DRIVE_REMOVED", function(c, why)
	local key = type(c) == "table" and c.key
	local r = key and NET.rides[key]
	if not r then return end
	if customerOf(key) == c then return end -- still listed (back in the queue)
	rideGone(key, r, why == "blocked" and "blocked" or "busy")
end)

W.Listen("DRIVE_CREW", function() DR.NetAttach() end)

W.Listen("DRIVE_RANK", function()
	if NET.attached then checkBeacon() end
end)

W.Listen("SETTINGS", function(key)
	if key == "drive" or key == "price" or key == "driver" or key == "summoners" then
		if NET.attached then checkBeacon() else DR.NetAttach() end
	end
end)

-- Another addon took over as driver: the engine closes itself and says so once.
W.Listen("PROVIDER", function(p)
	if p == nil then
		DR.NetAttach()
		return
	end
	if W.engine == ENGINE then
		W.SetEngine(nil)
		NET.attached = false
	end
	if call("IsOpen") and DR.SetOpen then call("SetOpen", false) end
	-- (the old summoning addon is never named: SPEC5 rrmentions; while it holds the lock the
	-- retire card says it all, review #4)
	if not NET.toldProvider and not (DR.Lock and DR.Lock() == "rr") then
		NET.toldProvider = true
		local name = (type(p) == "table" and str(p.name)) or nil
		if not name or name:lower():find("ritual%s*rides") then name = "Another addon" end
		W.Fire("DRIVE_ALERT", name .. " drives for you now: Wuber's own driving is off.", "info")
	end
end)
