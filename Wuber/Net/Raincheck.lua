-- Module: Net.Raincheck
-- Purpose: the lag-drop raincheck's wire (kind V, R field 7, A's last field, the IOU fact sender)
--   and the rider's own copy of rainchecks (display only: the driver's book decides).
-- API: W.Raincheck, W.Raincheck.Ask, W.Raincheck.CanAsk, W.Raincheck.Accept, W.Raincheck.Decline,
--   W.Raincheck.Mine, W.Raincheck.ForDriver, W.Raincheck.Use, W.Raincheck.Want, W.Raincheck.Using, W.Raincheck.Used,
--   W.Raincheck.Give, W.Raincheck.Void, W.SendIOU
-- Internals: RK, OPS, IOU_OPS, known, sent, heardN, tracked, use, unwanted, waiting, bump, heardGive, store, unixTime, validId,
--   expire, count, remember, heardOk; hook slot heard (kind V, called by Net.Base's W.NetKind handler)
-- Uses: Net.Base, Net.Transport, Net.Rides
-- Later: Drive.Team (DR.Send for the IOU fact)
-- Events: listens RIDE (remembers the last paid, failed ride: W.db.rcFailed); fires RAINCHECK
-- Standalone: no
-- Test: tests/net/raincheck_test.lua
-- From: new in Wuber 2.3.0
--
-- A raincheck is one free summon later from the same crew, given instead of a refund when a ride
-- paid by trade failed before the rider arrived. Wuber never refunds or moves gold. The driver's
-- book (Drive.Raincheck) is the authority: nothing a rider holds or sends can make one or use
-- one without it. This module only carries the words and keeps the rider's copy to show.
--
-- Kind V (addon whisper, only between a ride's driver and its rider; at most 3 each way per ride):
--   V~1~ask~<rideId>                                                rider -> driver (once per ride)
--   V~1~give~<rideId>~<id 8>~<expires unix>~<cover copper>~<service <=32>   driver -> rider (<= 80 B)
--   V~1~ok~<id>   V~1~no~<id>                                        rider -> driver
--   V~1~void~<id>~<reason <=12>                                     driver -> rider
-- The driver's side hears ask / ok / no as W.Fire("RAINCHECK", "ask", rideId, senderKey, addr),
-- ("accept" | "decline", id, senderKey, addr): the sender is always the event's sender.
-- R field 7 (Net.Rides) names the raincheck when the rider books its crew; A's last field "1"
-- says the book took it ("0" not; an old driver sends nothing: not taken).
-- WUBERT fact (Drive.Team's outbox): IOU~1~<op i|a|u|v>~<id>~<riderKey <=40>~<cover>~<expires>~<rideId>
--
-- Last failed paid ride (2.4.2): W.db.rcFailed = { rideId, driverKey, driver, addr, service, at } (per character, saved), set when
-- a ride paid by trade ends without arriving. A give is also believed from that ride's driver (the event's sender) for
-- RK.OFFER s after, even once W.ride is cleared (Try another driver, Done); any other sender is ignored.
-- Rider copy: W.db.rainchecks[id] = { driverKey, driver, service, cover, expires, state =
-- "offered" | "active" | "used" | "void", rideId, addr, at } (created only when one is offered).
-- Events: RAINCHECK("offer" | "active" | "used" | "void" | "declined" | "kept", id) on the rider's side,
-- ("taken" | "refused", id) from Net.Rides when the A came.
-- The driver says nothing back to V ok, so the rider's Accept waits RK.HEARD s (longer while our
-- outbox still holds it, up to RK.HEARD_TRIES waits) for the game's "No player named" about the
-- driver (Net.Rides notes it in fb.offlineUntil): none, "kept" (UI.Moments says "Raincheck kept");
-- one, the ok was lost: the copy is "offered" again and "offer" fires again (the card comes back).

local _, W = ...
local Mod = W.Module("Net.Raincheck", { "Net.Base", "Net.Transport", "Net.Rides" })
local BaseMod = W.Mod("Net.Base")
local RidesMod = W.Mod("Net.Rides")
local ENDED, NETK, address, clock, netInt, rideId = BaseMod.ENDED, BaseMod.NETK, BaseMod.address, BaseMod.clock, BaseMod.netInt, BaseMod.rideId
local fb = BaseMod.fb
local rideTimes = RidesMod.rideTimes
local str = W.Str

local RK = {
	ASK_WINDOW = 1800,  -- a ride that ended this long after it was paid gets none
	HOLD_MAX = 3,       -- active rainchecks a rider holds in all
	LIFE = 7 * 86400,   -- a raincheck lasts a week
	PER_RIDE = 3,       -- V messages per ride (or raincheck id) each way
	KEEP = 20,          -- entries kept in the rider's copy
	IOU_MAX = 90,       -- bytes of an IOU fact
	OFFER = 1800,       -- an offer not accepted lapses after 30 minutes (as in the driver's book)
	HEARD = 3,          -- seconds after V ok with no "No player named" for the driver: kept
	HEARD_TRIES = 4,    -- waits of HEARD at most (one more each while the outbox still holds messages)
}
Mod.RK = RK -- read by tests/polestar/p19_polite_limits_test.lua
local OPS = { ask = true, give = true, ok = true, no = true, void = true }
local IOU_OPS = { i = true, a = true, u = true, v = true }

local Raincheck = {}
W.Raincheck = Raincheck

local known = {}  -- rideId -> { driverKey, driver, addr, service, asked } (this session)
local sent = {}   -- rideId or id -> V we sent about it
local heardN = {} -- senderKey .. "|" .. rideId or id -> V heard about it
local use = true  -- Confirm's "Use raincheck" (on by default; Raincheck.Use)
local unwanted = {} -- driverKey -> true: switched off for that driver (Raincheck.Want; this session)
local waiting = {} -- id -> { off = fb.offlineUntil[driverKey] when we accepted }: V ok not yet known to have gone (this session)

-- The rider's copy (nil while none was ever offered, unless create).
local function store(create)
	local db = W.db
	if type(db) ~= "table" then return nil end
	if type(db.rainchecks) ~= "table" then
		if not create then return nil end
		db.rainchecks = {}
	end
	return db.rainchecks
end

-- A unix time on the wire (10 digits: W.Int stops at 9) as a number, else nil.
local function unixTime(v)
	if type(v) == "number" then v = string.format("%d", math.floor(v)) end
	v = str(v)
	if not v or not v:match("^%d+$") or #v > 10 then return nil end
	return tonumber(v)
end

local function validId(v)
	v = str(v)
	return v and v:match("^%w%w%w%w%w%w%w%w$") or nil
end

-- Offered or active ones past their time, and offers not accepted within 30 min, become void; the oldest past KEEP go.
local function expire()
	local list = store(false)
	if not list then return nil end
	local t, n = clock(), 0
	for id, e in pairs(list) do
		if type(e) ~= "table" or not validId(id) then
			list[id] = nil
		else
			if (e.state == "offered" or e.state == "active") and (tonumber(e.expires) or 0) <= t then e.state = "void" end
			if e.state == "offered" and t - (tonumber(e.at) or 0) >= RK.OFFER then e.state = "void" end -- (the book lapses it too)
			n = n + 1
		end
	end
	while n > RK.KEEP do
		local old, oldAt
		for id, e in pairs(list) do
			if not oldAt or (tonumber(e.at) or 0) < oldAt then old, oldAt = id, tonumber(e.at) or 0 end
		end
		list[old] = nil
		n = n - 1
	end
	return list
end

-- How many entries are in a state (except one id), and whether one of them is this driver's.
local function count(state, except, driverKey)
	local n, theirs = 0, false
	for id, e in pairs(store(false) or {}) do
		if id ~= except and e.state == state then
			n = n + 1
			if driverKey and e.driverKey == driverKey then theirs = true end
		end
	end
	return n, theirs
end

-- The ride (W.ride) this raincheck talk is about, remembered with its driver.
local function remember(id)
	local k = known[id]
	if k then return k end
	local r = W.ride
	if not (r and r.id == id and r.driverKey) then return nil end
	k = { driverKey = r.driverKey, driver = r.driver, addr = r.addr or r.driver, service = r.service }
	known[id] = k
	return k
end

-- The last paid, failed ride (W.db.rcFailed) when it is this ride and this driver, and not older than RK.OFFER.
local function failedRide(rid, key)
	local db = W.db
	local f = type(db) == "table" and db.rcFailed
	if type(f) ~= "table" or f.rideId ~= rid or not key or f.driverKey ~= key then return nil end
	if clock() - (tonumber(f.at) or 0) > RK.OFFER then return nil end
	return f
end

-- A paid ride that ended without arriving: remember its driver and id (survives W.ClearRide and a /reload).
W.Listen("RIDE", function(r)
	local db = W.db
	if type(db) ~= "table" or type(r) ~= "table" then return end
	if not (r.paid and ENDED[r.state] and r.state ~= "done" and not r.arrivedAt and r.driverKey) then return end
	local rid = rideId(r.id)
	if not rid then return end
	if db.rcFailed and db.rcFailed.rideId == rid then return end
	db.rcFailed = { rideId = rid, driverKey = r.driverKey, driver = r.driver, addr = r.addr or r.driver,
		service = r.service, at = clock() }
end)

local tracked = 0 -- entries in heardN (a flood of made-up ids starts it afresh past 400)
local function bump(t, k, max)
	if t == heardN and not t[k] then
		tracked = tracked + 1
		if tracked > 400 then
			for x in pairs(heardN) do heardN[x] = nil end
			tracked = 1
		end
	end
	local n = (t[k] or 0) + 1
	if n > max then return false end
	t[k] = n
	return true
end

---------------------------------------------------------------------------
-- Rider side
---------------------------------------------------------------------------

-- Whether the rider may ask for a raincheck for this ride (its id, or the ride table): true, or false and why ("ride" not
-- our last ride, "asked" already, "unpaid" not paid in full by trade, "arrived", "open" not
-- ended, "late" ended over 30 min after paying). The driver's book checks again and decides.
function Raincheck.CanAsk(id)
	if type(id) == "table" then id = id.id end
	id = rideId(id)
	local r = W.ride
	if not (id and r and r.id == id and r.driverKey) then return false, "ride" end
	if known[id] and known[id].asked then return false, "asked" end
	local times = rideTimes[id] or { paidAt = tonumber(r.paidAt), endedAt = tonumber(r.endedAt) } -- (after a /reload)
	if not (r.paid and times.paidAt) then return false, "unpaid" end
	if r.arrivedAt or r.state == "done" or (W.RIDE_RANK[r.state] or 0) >= W.RIDE_RANK.arrived then return false, "arrived" end
	if not ENDED[r.state] then return false, "open" end
	if not times.endedAt or times.endedAt - times.paidAt > RK.ASK_WINDOW then return false, "late" end
	return true
end

-- The rider asks the driver for a raincheck on a failed paid ride (once per ride). Returns
-- whether it was sent.
function Raincheck.Ask(id)
	if not Raincheck.CanAsk(id) then return false end
	id = rideId(id)
	local k = remember(id)
	if not k or not bump(sent, id, RK.PER_RIDE) then return false end
	if not W.SendTo(k.addr, "V", "ask", id) then return false end -- (a send that failed leaves the one ask unspent)
	k.asked = true
	return true
end

-- RK.HEARD s after V ok (see the header): the game said the driver isn't on (a new
-- fb.offlineUntil from Net.Rides): the ok was lost, the offer is back; else "kept".
local function heardOk(id, tries)
	local wait = waiting[id]
	local list = store(false)
	local e = wait and list and list[id]
	if not e or e.state ~= "active" then
		waiting[id] = nil
		return
	end
	local queued = type(W.QueueLength) == "function" and (W.Num(W.QueueLength()) or 0) > 0
	if queued and tries < RK.HEARD_TRIES then
		W.After(RK.HEARD, function() heardOk(id, tries + 1) end)
		return
	end
	waiting[id] = nil
	local off = e.driverKey and fb.offlineUntil[e.driverKey]
	if off and off ~= wait.off then
		e.state = "offered"
		W.Fire("RAINCHECK", "offer", id)
	else
		W.Fire("RAINCHECK", "kept", id)
	end
end

-- The rider accepts an offered raincheck: it is active only once the driver's window has the
-- answer (the book). Refused past 3 active ones, or with one already from this driver.
function Raincheck.Accept(id)
	id = validId(id)
	local list = expire()
	local e = id and list and list[id]
	if not (e and e.state == "offered") then return false end
	local n, theirs = count("active", id, e.driverKey)
	if n >= RK.HOLD_MAX or theirs then return false end
	local key = e.driverKey
	-- the stamp is taken BEFORE the send: a send that reaches a driver cached offline learns the
	-- game's not-found line inside W.SendTo, and a snapshot after it would hide that change
	local off = key and fb.offlineUntil[key]
	if not bump(sent, id, RK.PER_RIDE) or not W.SendTo(e.addr or e.driver, "V", "ok", id) then return false end
	e.state = "active"
	waiting[id] = { off = off }
	W.After(RK.HEARD, function() heardOk(id, 1) end)
	W.Fire("RAINCHECK", "active", id)
	return true
end

-- The rider says no thanks: the offer goes.
function Raincheck.Decline(id)
	id = validId(id)
	local list = expire()
	local e = id and list and list[id]
	if not (e and e.state == "offered") then return false end
	if bump(sent, id, RK.PER_RIDE) then W.SendTo(e.addr or e.driver, "V", "no", id) end
	list[id] = nil
	W.Fire("RAINCHECK", "declined", id)
	return true
end

-- The rider's rainchecks, newest first: { id, driverKey, driver, service, cover, expires,
-- state, rideId }.
function Raincheck.Mine()
	local out = {}
	for id, e in pairs(expire() or {}) do
		out[#out + 1] = { id = id, driverKey = e.driverKey, driver = e.driver, service = e.service, cover = e.cover,
			expires = e.expires, state = e.state, rideId = e.rideId, at = e.at }
	end
	table.sort(out, function(a, b)
		if (a.at or 0) ~= (b.at or 0) then return (a.at or 0) > (b.at or 0) end
		return a.id < b.id
	end)
	return out
end

-- An active raincheck for this driver (a W.drivers entry, or a key, with or without the
-- service as a second argument): id, cover (copper); nil when none. Matches the driver's key
-- or, for the same crew under another driver, its service.
function Raincheck.ForDriver(driver, svc)
	local list = expire()
	if not list then return nil end
	local key, service
	if type(driver) == "table" then
		key, service = W.Key(str(driver.key) or str(driver.name)), str(driver.service)
	else
		key = W.Key(str(driver))
	end
	service = str(svc) or service
	service = service and service:lower()
	local best
	for id, e in pairs(list) do
		if e.state == "active" and (e.driverKey == key or (service and type(e.service) == "string" and e.service:lower() == service)) then
			if not best or (e.expires or 0) < (list[best].expires or 0) then best = id end
		end
	end
	if not best then return nil end
	return best, tonumber(list[best].cover) or 0
end

-- Confirm's "Use raincheck" toggle (on by default): W.RequestRide names the raincheck in R
-- only while on. Use(on) for every driver, Want(driverKey, on) for one; Using(driverKey).
function Raincheck.Use(on) use = on ~= false end
function Raincheck.Want(driverKey, on)
	local key = W.Key(str(driverKey))
	if key then unwanted[key] = (on == false) or nil end
end
function Raincheck.Using(driverKey)
	local key = driverKey and W.Key(str(driverKey))
	return use and not (key and unwanted[key])
end

-- The ride that named this raincheck arrived (Net.Rides): the rider's copy shows it used.
function Raincheck.Used(id)
	local list = store(false)
	local e = validId(id) and list and list[id]
	if not e or e.state == "used" then return false end
	e.state = "used"
	W.Fire("RAINCHECK", "used", id)
	return true
end

---------------------------------------------------------------------------
-- Driver side (the wire for Drive.Raincheck's book)
---------------------------------------------------------------------------

-- The driver offers a raincheck to the rider of a failed ride. Returns whether V give went.
function Raincheck.Give(rid, buyer, id, expires, cover, service)
	rid, id, buyer = rideId(rid), validId(id), address(buyer)
	expires, cover = unixTime(expires), W.Int(cover)
	if not (rid and id and buyer and expires and cover) then return false end
	if not bump(sent, rid, RK.PER_RIDE) then return false end
	service = W.CleanDest(service or "")
	-- (the time goes as text: W.Encode keeps numbers to 9 digits)
	return W.SendTo(buyer, "V", "give", rid, id, string.format("%d", expires), cover, service) and true or false
end

-- The driver voids a raincheck (expired, or never accepted). reason: <= 12 letters.
function Raincheck.Void(id, buyer, reason)
	id, buyer = validId(id), address(buyer)
	if not (id and buyer) or not bump(sent, id, RK.PER_RIDE) then return false end
	reason = (W.Clean(str(reason) or "", 12):gsub("[^%w ]", ""))
	return W.SendTo(buyer, "V", "void", id, reason) and true or false
end

-- The driver side's IOU fact to the crew (WUBERT, Drive.Team's outbox): op i (issued, offered),
-- a (active), u (used), v (void). Returns whether it was queued.
function W.SendIOU(op, id, riderKey, cover, expires, rid)
	op, id = str(op), validId(id)
	riderKey = W.Key(str(riderKey))
	cover, expires = W.Int(cover) or 0, string.format("%d", unixTime(expires) or 0)
	local DR = W.Drive
	if not (op and IOU_OPS[op] and id and riderKey) or type(DR) ~= "table" or type(DR.Send) ~= "function" then return false end
	rid = rideId(rid) or ""
	riderKey = W.Clean(riderKey, 40)
	local text = table.concat({ "IOU", "1", op, id, riderKey, cover, expires, rid }, "~")
	if #text > RK.IOU_MAX then return false end
	local ok, res = pcall(DR.Send, "IOU", op, id, riderKey, cover, expires, rid)
	return ok and res ~= false
end

---------------------------------------------------------------------------
-- Hearing V (Net.Inbox: by whisper only)
---------------------------------------------------------------------------

-- the rider hears "give": only from the driver of the ride it names, for a ride paid in full
-- and never arrived; one per ride
local function heardGive(addr, name, key, f)
	local rid, id = rideId(f[2]), validId(f[3])
	local k = rid and remember(rid)
	local rec = rid and failedRide(rid, key)
	if not k and rec then
		k = { driverKey = rec.driverKey, driver = rec.driver, addr = rec.addr or rec.driver, service = rec.service }
	end
	if not (k and id and k.driverKey == key) then return end
	local times, r = rideTimes[rid], W.ride
	-- paid in full by trade: this session's times, or the ride itself (kept over a /reload), or the saved failed-ride note
	if not (rec or (times and times.paidAt) or (r and r.id == rid and r.paid and r.driverKey == key)) then return end
	if r and r.id == rid and (r.arrivedAt or (W.RIDE_RANK[r.state] or 0) >= W.RIDE_RANK.arrived) then return end
	local t = clock()
	local expires = unixTime(f[4])
	if not expires or expires <= t or expires > t + RK.LIFE + 3600 then return end
	local cover = netInt(f[5], 0, NETK.MAX_PRICE, 0)
	if cover <= 0 then return end
	local list = expire() or store(true)
	for _, e in pairs(list) do
		if e.rideId == rid then return end -- one per ride
	end
	local service = W.CleanService(f[6] or "", name)
	list[id] = { driverKey = key, driver = name, addr = addr, service = service, cover = cover, expires = expires,
		state = "offered", rideId = rid, at = t }
	W.Fire("RAINCHECK", "offer", id)
end

-- V: ask / give / ok / no / void
function Mod.heard(addr, name, key, f, chan)
	if chan ~= "WHISPER" then return end
	local op = f[1]
	if not (op and OPS[op]) then return end
	local about = (op == "ask" or op == "give") and rideId(f[2]) or validId(f[2])
	if not about or not bump(heardN, key .. "|" .. about, RK.PER_RIDE) then return end
	if op == "give" then
		heardGive(addr, name, key, f)
	elseif op == "void" then
		local list = store(false)
		local e = list and list[about]
		-- (round 9) "used": the driver's book used it on arrival (even when the rider's copy got
		-- there first by another ride, or lapsed it): used, never void
		local used = f[3] == "used"
		if e and e.driverKey == key and e.state ~= "used" and (used or e.state ~= "void") then
			e.state = used and "used" or "void"
			W.Fire("RAINCHECK", e.state, about)
		end
	elseif op == "ask" then
		W.Fire("RAINCHECK", "ask", about, key, addr)
	else
		W.Fire("RAINCHECK", op == "ok" and "accept" or "decline", about, key, addr)
	end
end
