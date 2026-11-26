-- Module: Drive.Raincheck
-- Purpose: the raincheck book (the authority): eligibility of a failed paid ride, giving one, the
--   daily cap and expiry, redeeming in the request path, used on arrival, the crew's IOU facts.
-- API: DR.recentPaid, DR.RAINCHECK, DR.RaincheckEligible, DR.GiveRaincheck, DR.Rainchecks,
--   DR.RaincheckHeard, DR.RaincheckFact, DR.RaincheckRedeem, DR.RaincheckSync, DR.RaincheckTick,
--   DR.RaincheckCounts, DR.RaincheckGiven, DR.RaincheckFor, DR.RideIdOf, DR.RecentPaidSave, DR.RecentPaidLoad
-- Internals: (none)
-- Uses: (none)
-- Later: (none)
-- Events: listens Listen DRIVE_PAID, Listen DRIVE_STATE, Listen DRIVE_REMOVED, Listen DRIVE_RITUAL, Listen RAINCHECK (ask,
--   accept, decline from Net.Raincheck); fires RAINCHECK ("book", what, id), DRIVE_ALERT (kind "raincheck",
--   data { rideId, name }, through DR.Alert)
-- Standalone: no
-- Test: tests/drive/raincheck_test.lua
-- From: new in Wuber 2.3.0
--
-- A raincheck is one free summon later from the same crew, given instead of a refund when a ride
-- PAID BY TRADE failed before the rider arrived. Wuber never refunds and never moves gold.
--
-- Eligible (DR.RaincheckEligible(rideId) -> true | false, why), all of:
--   the ride is a Wuber ride whose fare was paid in full by completed trades (Drive.Trade's PAID,
--   never "Mark as paid": "hand"; less than the locked fare: "part"; nothing: "unpaid");
--   the rider never arrived ("arrived": the queue's here check, also for a rider who paid first, or
--   already here when the payment landed, even one who left the group at once; an
--   arrival on that ride after a raincheck was given voids it, and a rider who paid before joining
--   the group is not "left" until they had joined); the summon never went out ("summoned": END ok
--   for that ride and the rider left the group with the summon box up; cleared when the box lapses,
--   the row back to joined, or a later summon on that ride fails);
--   the ride ended ("open" until then: removed from the list, or the driver closed) within 30
--   minutes of the payment ("late"); no raincheck for that ride yet ("given"); the rider holds no
--   live one from this crew ("held"); the crew gave fewer than 3 today ("cap").
-- Both sides agree: the rider asks (V ask; an ask heard while the ride is still "open" waits and
-- alerts once it is eligible; only an eligible ask uses the ride's one ask), the driver clicks Give
-- (V give), the rider accepts (V ok): only then is it active. An offer not accepted within 30
-- minutes lapses (void, "lapsed"), so it never holds the rider's place or the cap for 7 days. Redeemed in the request path (Drive.Net's onRequest: R field 7) only
-- when the book says: that id, active, not expired, the event's sender is its rider, this crew; the
-- fare due drops by its cover. Used on arrival (the driver's here check), never on request: a ride
-- that fails again before arrival leaves it active. A redeemed one is also used when its rider
-- arrives on any row within 30 minutes of the redeem (a second request with a new ride id, the
-- "rebook" that replaced the row, keeps it on the redeemed ride). Expires after 7 days.
--
-- The book (round 9: taken = the rider took it, set on active/used and kept when it goes void):
-- W.db.drive.iou[id] = { rider, name, rideId, cover, issued, expires, state = "offered" |
-- "active" | "used" | "void", by, crew, service, why, onRide }, kept the same in every crew window
-- by the IOU fact (op i issued, a active, u used, v void; merge: void/used beat active beat offered;
-- an id never heard of is taken only from an i fact; one issued today (its expiry minus 7 days)
-- counts toward the day's cap and a crew window's past the cap is refused; a crew fact's cover is
-- at most the highest fare this window has seen (its price, a paid ride's fare, a cover in the book)).
-- W.db.drive.iouDay = { day, n }. Both are made the first time a raincheck is given or heard.
-- DR.recentPaid: the last 20 rides paid by trade (session; saved with the queue snapshot).
--
-- Wire (Net.Raincheck, nil-safe): W.Raincheck.Give(rideId, addr, id, expires, cover, service) and
-- W.Raincheck.Void(id, addr, reason) whisper V to the rider; W.SendIOU(op, id, riderKey, cover,
-- expires, rideId) tells the crew (after the fact is applied here); a window that joins hears the
-- book on Team's low-priority bulk lane (DR.SendBulk: active ones as i + a, recent used and void
-- ones as u / v, which beat a stale active there). The rider's V ask / ok / no come
-- as RAINCHECK("ask" | "accept" | "decline", ...) into DR.RaincheckHeard(op, senderKey, addr, field).

local _, W = ...
local Mod = W.Module("Drive.Raincheck", {})
W.Drive = W.Drive or {}
local DR = W.Drive

local RAINCHECK = {
	WINDOW = 1800,        -- the ride ended within 30 minutes of payment
	DAYS = 7,             -- a raincheck lasts 7 days
	DAY_CAP = 3,          -- a crew gives at most 3 a day
	RECENT = 20,          -- rides paid by trade kept
	SYNC = 20,            -- entries told to a window that joins (used / void first)
	OFFER = 1800,         -- an offer not accepted lapses after 30 minutes
	PER_RIDE = 3,         -- V messages to the rider per ride
	KEEP = 30 * 86400,    -- used and void entries stay in the book for 30 days
	BOOK_MAX = 100,
	STATE_RANK = { offered = 1, active = 2, used = 3, void = 3 },
	OPS = { i = "offered", a = "active", u = "used", v = "void" },
}
DR.RAINCHECK = RAINCHECK

DR.recentPaid = DR.recentPaid or {}

local function stamp() return (type(time) == "function" and time()) or 0 end

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

local function driveDB()
	local d = W.db and W.db.drive
	return type(d) == "table" and d or nil
end

-- the book, made when first needed (make = true) so saved data is unchanged until then
local function book(make)
	local d = driveDB()
	if not d then return nil end
	if type(d.iou) ~= "table" then
		if not make then return nil end
		d.iou = {}
	end
	return d.iou
end

local function dayKey(t) return (type(date) == "function" and date("%Y%m%d", t)) or "0" end

local function today(make)
	local d = driveDB()
	if not d then return nil end
	local k = dayKey(stamp())
	if type(d.iouDay) ~= "table" or d.iouDay.day ~= k then
		if not make then return { day = k, n = 0 } end
		d.iouDay = { day = k, n = 0 }
	end
	return d.iouDay
end

-- An offer counts toward the day's three while it is open and once accepted; one declined or lapsed
-- gives its place back (v.countDay = the day it was counted on, cleared when it is given back).
local function giveBack(v)
	local d = v.countDay
	if not d then return end
	v.countDay = nil
	local day = today(false)
	local real = driveDB() and driveDB().iouDay
	if real and day and real.day == d and real.n > 0 then real.n = real.n - 1 end
end

local function takeAgain(v)
	if v.countDay then return end
	local k = dayKey(tonumber(v.issued) or stamp())
	if k ~= dayKey(stamp()) then return end
	local day = today(true)
	if day then day.n = day.n + 1; v.countDay = k end
end

local function cleanId(v)
	v = W.Str(v)
	if v and #v == 8 and v:match("^%w+$") then return v end
	return nil
end

local function cleanRide(v)
	v = W.Str(v)
	if v and #v == 6 and v:match("^%a+$") then return v end
	return nil
end

local function newId()
	local chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789"
	local b = book(true)
	for _ = 1, 20 do
		local out = {}
		for i = 1, 8 do
			local k = math.random(1, #chars)
			out[i] = chars:sub(k, k)
		end
		local id = table.concat(out)
		if not b[id] then return id end
	end
	return nil
end

-- the Wuber ride id of a customer (the window that took the request, or a crew window from ST)
function DR.RideIdOf(c)
	if type(c) ~= "table" then return nil end
	return c.wuberRide or c.rideId
end

-- RAINCHECK is shared with Net.Raincheck (its ops: ask, accept, decline on the driver's side;
-- offer, active, ... on the rider's): the book's own changes go as RAINCHECK("book", what, id)
local function changed(what, id)
	W.Fire("RAINCHECK", "book", what, id)
	call("Changed")
end

-- An IOU fact: applied here first, then told to the crew (Net.Raincheck's W.SendIOU, else Team)
local function fact(op, id, riderKey, cover, expires, rideId)
	DR.RaincheckFact(W.myKey, true, op, id, riderKey, cover, expires, rideId)
	if type(W.SendIOU) == "function" then
		W.Safe("raincheck iou", W.SendIOU, op, id, riderKey, cover, expires, rideId or "")
	else
		call("Send", "IOU", op, id, riderKey, cover, string.format("%d", tonumber(expires) or 0), rideId or "")
	end
end

-- V to the rider (Net.Raincheck): give / void
local function tellGive(addr, ride, id, expires, cover, service)
	local RC = W.Raincheck
	if type(RC) == "table" and type(RC.Give) == "function" then W.Safe("raincheck give", RC.Give, ride, addr, id, expires, cover, service) end
end

local function tellVoid(addr, id, reason)
	local RC = W.Raincheck
	if type(RC) == "table" and type(RC.Void) == "function" then W.Safe("raincheck void", RC.Void, id, addr, reason) end
end

-- a raincheck that can still be used (offered or active, not expired)
local function live(v, t)
	t = t or stamp()
	if v and v.state == "offered" and t - (tonumber(v.issued) or 0) >= RAINCHECK.OFFER then return false end
	return v and (v.state == "offered" or v.state == "active") and (tonumber(v.expires) or 0) > t
end

-- the raincheck given for a ride (one per ride id)
local function forRide(rideId)
	for id, v in pairs(book(false) or {}) do
		if v.rideId == rideId then return id, v end
	end
	return nil
end

---------------------------------------------------------------------------
-- Rides paid by trade
---------------------------------------------------------------------------

local function recentFor(rideId, key)
	for i = #DR.recentPaid, 1, -1 do
		local e = DR.recentPaid[i]
		if (rideId and e.ride == rideId) or (not rideId and key and e.key == key and not e.ride) then return e end
	end
	return nil
end

-- the customer's entry (made on the first payment); its ride id filled in once known
local function entryOf(c, make)
	local ride = DR.RideIdOf(c)
	local e = recentFor(ride, c.key) or (ride and recentFor(nil, c.key))
	if e then
		e.ride = e.ride or ride
		return e
	end
	if not make or not ride then return nil end
	e = { ride = ride, key = c.key, name = c.name, buyer = c.wuberBuyer or c.name, fare = 0, traded = 0, hand = false,
		summoned = c.state == "waiting" or nil }
	DR.recentPaid[#DR.recentPaid + 1] = e
	while #DR.recentPaid > RAINCHECK.RECENT do table.remove(DR.recentPaid, 1) end
	return e
end

-- The rider of a paid ride arrived: that ride never qualifies, and a raincheck already given for
-- it (the driver closed for a moment, then summoned them after all) goes void.
local function arrivedEntry(e)
	if not e or e.arrived then return end
	e.arrived = true
	local id, v = forRide(e.ride)
	if id and live(v) and not v.onRide then
		fact("v", id, v.rider, v.cover, v.expires, v.rideId)
		v.why = "arrived"
		tellVoid(v.addr or e.addr or e.buyer or e.name, id, "arrived")
		changed("arrived", id)
	end
end

-- DRIVE_PAID: name, copper, tip, cashierKey, mine, how ("t" traded | "m" by hand), price
W.Listen("DRIVE_PAID", function(name, copper, tip, cashierKey, mine, how, price)
	local c = call("Find", name)
	if type(c) ~= "table" then return end
	local e = entryOf(c, true)
	if not e then return end
	-- the rider is here already (arrived, then paid: the usual ride): that ride never qualifies,
	-- even when they leave the group before the next tick (auto-leave)
	if c.state == "arrived" or c.arrivedAt then arrivedEntry(e) end
	local fare = tonumber(c.fullFare or price or c.price) or 0
	if fare > e.fare then e.fare = fare end
	if how == "t" then
		e.traded = e.traded + math.max(0, math.floor(tonumber(copper) or 0))
		if e.traded >= e.fare and e.fare > 0 and not e.paidAt then e.paidAt = stamp() end
	else
		e.hand = true
	end
	if c.voucher then e.voucher = true end -- a ride a raincheck paid for
end)

local function arrived(c)
	arrivedEntry(entryOf(c, false))
end

-- the rider's raincheck redeemed in the last 30 minutes (still active: its ride not arrived yet)
local function redeemedBy(key, t)
	for id, v in pairs(book(false) or {}) do
		if v.rider == key and v.state == "active" and v.onRide and t - (tonumber(v.redeemAt) or 0) <= RAINCHECK.WINDOW then return id end
	end
	return nil
end

-- A redeemed raincheck is used when its rider arrives (the driver's here check), on its row or on
-- any row of that rider (a request with a new ride id replaced the redeemed one).
local function useVoucher(c, id)
	local b = book(false)
	local v = id and b and b[id]
	if not v or v.state ~= "active" or not v.onRide or v.rider ~= c.key then return end
	local onRow = c.voucher == id
	if onRow then c.voucher = nil end
	fact("u", id, v.rider, v.cover, v.expires, v.rideId)
	tellVoid(c.wuberBuyer or c.name, id, "used")
	-- nothing left to pay: the ride counts as paid (no gold moved, so never as a trade)
	if onRow and (tonumber(c.price) or 0) <= 0 and (DR.Rank and DR.Rank(c.state) < DR.Rank("paid")) then
		call("Do", "PAID", c.name, 0, "m")
	end
end

W.Listen("DRIVE_STATE", function(c)
	if type(c) ~= "table" then return end
	if c.state == "joined" then
		-- the summon box lapsed (or the summon was taken back): that summon never landed
		local e = recentFor(DR.RideIdOf(c))
		if e then e.summoned = nil end
		return
	end
	if c.state ~= "arrived" then return end
	arrived(c)
	local id = c.voucher or redeemedBy(c.key, stamp())
	if id then useVoucher(c, id) end
end)

-- the summon went out (END ok) for a ride: no raincheck for it while the box is up (a rider who
-- leaves the group then took the summon or walked away from it). The box lapsing or a later
-- failed summon puts the row back to joined, which clears it (DRIVE_STATE above).
W.Listen("DRIVE_RITUAL", function(_, phase, data)
	if phase ~= "s" or type(data) ~= "table" then return end
	local e = recentFor(cleanRide(data.ride))
	if e then e.summoned = true end
end)

-- off the list: the ride ended (a redeemed raincheck stays active for the next try; a "rebook",
-- a new ride id that replaced the row, keeps it on the redeemed ride, used if the rider arrives)
W.Listen("DRIVE_REMOVED", function(c, why)
	if type(c) ~= "table" then return end
	local e = entryOf(c, false)
	if e and not e.endedAt then e.endedAt, e.why = stamp(), why end
	if c.voucher then
		local b = book(false)
		local v = b and b[c.voucher]
		if v and v.onRide == DR.RideIdOf(c) and why ~= "rebook" then v.onRide = nil end
		c.voucher = nil
	end
end)

---------------------------------------------------------------------------
-- The book
---------------------------------------------------------------------------

local function holds(riderKey, t)
	for _, v in pairs(book(false) or {}) do
		if v.rider == riderKey and live(v, t) then return true end
	end
	return false
end

-- the rider's ask, once eligible: the driver is alerted (the ride's one ask is used)
local askNow

-- may this ride get a raincheck (paid by trade, never arrived, ended within 30 minutes)?
function DR.RaincheckEligible(rideId)
	rideId = cleanRide(rideId)
	if not rideId then return false, "unknown" end
	local e = recentFor(rideId)
	if not e then return false, "unpaid" end
	if e.voucher then return false, "free" end
	if (e.traded or 0) <= 0 then return false, e.hand and "hand" or "unpaid" end
	if e.traded < (e.fare or 0) or not e.paidAt then return false, "part" end
	if e.arrived then return false, "arrived" end
	if e.summoned then return false, "summoned" end
	if not e.endedAt then return false, "open" end
	if e.endedAt - e.paidAt > RAINCHECK.WINDOW then return false, "late" end
	if forRide(rideId) then return false, "given" end
	local t = stamp()
	if holds(e.key, t) then return false, "held" end
	if (today(false) or { n = 0 }).n >= RAINCHECK.DAY_CAP then return false, "cap" end
	return true
end

askNow = function(e)
	e.asked, e.askWait = true, nil
	DR.Alert(W.Short(e.name) .. " asks for a raincheck: their paid ride failed. Give one from their row.", "raincheck",
		{ rideId = e.ride, name = e.name })
end

-- The raincheck that this row's ride could get or has: eligible, why, id (when given).
function DR.RaincheckFor(c)
	local ride = DR.RideIdOf(c)
	if not ride then return false, "unknown" end
	local id = forRide(ride)
	local ok, why = DR.RaincheckEligible(ride)
	return ok, why, id
end

local function serviceName()
	local ch = W.Char()
	local s = type(ch.service) == "string" and ch.service or ""
	if s == "" then s = W.myName or W.Me() or "" end
	return W.Clean(s, 32)
end

-- the driver offers a raincheck for a failed ride (a click). Returns true, id or false, why.
function DR.GiveRaincheck(rideId)
	local ok, why = DR.RaincheckEligible(rideId)
	if not ok then return false, why end
	local e = recentFor(cleanRide(rideId))
	local id = newId()
	if not id then return false, "id" end
	local t = stamp()
	local expires = t + RAINCHECK.DAYS * 86400
	local cover = math.min(e.fare, e.traded)
	fact("i", id, e.key, cover, expires, e.ride)
	local v = (book(false) or {})[id]
	if not v then return false, "book" end
	v.name, v.by, v.service, v.addr = e.name, W.myKey, serviceName(), e.addr or e.buyer or e.name
	tellGive(v.addr, e.ride, id, expires, cover, v.service)
	changed("give", id)
	return true, id
end

-- the most a raincheck can cover here: the highest fare this window has seen
local function highestFare(b)
	local ch = W.Char()
	local most = tonumber(type(ch) == "table" and ch.price) or 0
	for _, e in ipairs(DR.recentPaid) do most = math.max(most, tonumber(e.fare) or 0) end
	for _, v in pairs(b) do most = math.max(most, tonumber(v.cover) or 0) end
	return math.max(most, W.MIN_PRICE or 0)
end

-- An IOU fact (a crew window's, or mine through DR.Do): the book, merged.
function DR.RaincheckFact(from, mine, op, id, riderKey, cover, expires, rideId)
	local state = RAINCHECK.OPS[op or ""]
	id = cleanId(id)
	riderKey = W.Str(riderKey) and W.Clean(W.Str(riderKey), 40) or nil
	if not state or not id or not riderKey or riderKey == "" then return end
	local t = stamp()
	expires = math.floor(tonumber(expires) or 0)
	if expires <= 0 or expires > t + (RAINCHECK.DAYS + 1) * 86400 then return end
	local b = book(true)
	local v = b[id]
	if not v then
		-- never heard of it: only an i fact makes an entry; one issued today counts toward the day's
		-- cap (a crew window's past the cap is refused); an older one (the join sync) doesn't
		if op ~= "i" then return end
		local counts = dayKey(expires - RAINCHECK.DAYS * 86400) == dayKey(t)
		if counts and not mine and (today(false) or { n = 0 }).n >= RAINCHECK.DAY_CAP then return end
		cover = math.max(0, math.min(99999999, math.floor(tonumber(cover) or 0)))
		if not mine then cover = math.min(cover, highestFare(b)) end
		v = { rider = riderKey, rideId = cleanRide(rideId), cover = cover,
			issued = t, expires = expires, state = state, by = from, crew = call("CaptainKey") }
		b[id] = v
		if counts then
			local day = today(true)
			day.n = day.n + 1
			v.countDay = dayKey(t)
		end
	elseif v.rider ~= riderKey then
		return -- the same id for another rider: a forgery, never merged
	elseif v.state == "void" and v.why == "lapsed" and (state == "active" or state == "used") then
		-- a local lapse (this window missed the acceptance) never beats the rider's real answer
		v.state, v.why = state, nil
		if v.state == "active" then takeAgain(v) end
	elseif RAINCHECK.STATE_RANK[state] > RAINCHECK.STATE_RANK[v.state] then
		if state == "void" and v.state == "offered" then giveBack(v) end
		v.state = state
	else
		return
	end
	v.at = t
	-- an older one (the join sync) is dated when it was given, not when this window heard of it, so it
	-- never counts as given today (kept at "now" while only offered: the offer window runs from issued)
	if (state == "active" or state == "used") and dayKey(expires - RAINCHECK.DAYS * 86400) ~= dayKey(t) then
		v.issued = math.min(v.issued or t, expires - RAINCHECK.DAYS * 86400)
	end
	if state == "used" then v.usedAt = t end
	-- (round 9) the rider took it (Earnings' "given"): kept when it later goes void
	if state == "active" or state == "used" then v.taken = true end
	if not mine then changed("fact", id) end
end

-- The rider's V (Net.Raincheck): ask (rideId), ok / no (id). Only the event's sender counts;
-- `addr` is where the rider's answer came from (the V give / void go back there).
function DR.RaincheckHeard(op, fromKey, addr, a)
	if not fromKey then return false end
	if op == "ask" then
		local e = recentFor(cleanRide(a))
		if not e or e.key ~= fromKey or e.asked then return false end
		e.addr = W.Str(addr) or e.addr
		local ok, why = DR.RaincheckEligible(e.ride)
		if ok then
			askNow(e)
		elseif why == "open" then
			e.askWait = true -- the ride ends a moment later (the rider's cancel crossed the ask): alert then
		end
		changed("ask", e.ride)
		return ok
	end
	local id = cleanId(a)
	local v = id and (book(false) or {})[id]
	if not v or v.rider ~= fromKey or v.state ~= "offered" or not live(v) then return false end
	if op == "ok" then
		fact("a", id, v.rider, v.cover, v.expires, v.rideId)
		changed("ok", id)
		return true
	elseif op == "no" then
		fact("v", id, v.rider, v.cover, v.expires, v.rideId)
		v.why = "no"
		changed("no", id)
		return true
	end
	return false
end

-- Net.Raincheck hands the rider's V over as RAINCHECK("ask", rideId, senderKey, addr) and
-- ("accept" | "decline", id, senderKey, addr)
local HEARD = { ask = "ask", accept = "ok", decline = "no" }
W.Listen("RAINCHECK", function(op, a, senderKey, addr)
	local mine = HEARD[op or ""]
	if not mine or type(senderKey) ~= "string" then return end
	DR.RaincheckHeard(mine, senderKey, addr, a)
end)

-- R field 7 (Drive.Net's onRequest): may voucher `id` lower this ride's fare? The book decides;
-- `senderKey` is the request's event sender. Sets c.voucher, c.cover, c.fullFare and the fare due.
function DR.RaincheckRedeem(id, senderKey, fare, c)
	id = cleanId(id)
	local v = id and (book(false) or {})[id]
	if not v or type(c) ~= "table" or v.state ~= "active" or not live(v) then return false end
	if not senderKey or v.rider ~= senderKey then return false end
	if v.crew and v.crew ~= call("CaptainKey") then return false end
	fare = math.max(0, math.floor(tonumber(fare) or 0))
	v.onRide, v.redeemAt = DR.RideIdOf(c), stamp()
	c.voucher, c.cover, c.fullFare = id, v.cover, fare
	c.price = math.max(0, fare - (v.cover or 0))
	changed("redeem", id)
	return true
end

-- A window that joins hears the book on the bulk lane (at most 20 entries): recent used and void
-- ones first (they beat a stale active there), then the active ones as i + a (i makes the entry
-- in a window that never heard of it, and counts toward its day's cap there).
local function syncOne(op, id, v)
	call("SendBulk", "IOU", op, id, v.rider, v.cover or 0, string.format("%d", tonumber(v.expires) or 0), v.rideId or "")
end

function DR.RaincheckSync()
	local n, t = 0, stamp()
	local b = book(false) or {}
	for id, v in pairs(b) do
		if n >= RAINCHECK.SYNC then return end
		if (v.state == "used" or (v.state == "void" and v.why ~= "lapsed")) and t - (tonumber(v.at or v.issued) or 0) <= (RAINCHECK.DAYS + 1) * 86400 then
			n = n + 1
			-- a used one issued today goes as i then u: the i makes the entry in a window that never
			-- heard of it (and counts toward its day's cap, at most 3); a lone u is ignored there
			if v.state == "used" and dayKey((tonumber(v.expires) or 0) - RAINCHECK.DAYS * 86400) == dayKey(t) then syncOne("i", id, v) end
			syncOne(v.state == "used" and "u" or "v", id, v)
		end
	end
	for id, v in pairs(b) do
		if n >= RAINCHECK.SYNC then return end
		if v.state == "active" and live(v, t) then
			n = n + 1
			syncOne("i", id, v)
			syncOne("a", id, v)
		end
	end
end

-- Once a second (DR.Tick): expiry, a prepaid rider's arrival, rides ended by closing, pruning.
function DR.RaincheckTick()
	local t = stamp()
	local b = book(false)
	if b then
		local n = 0
		for id, v in pairs(b) do
			n = n + 1
			if v.state == "active" and (tonumber(v.expires) or 0) <= t then
				v.state, v.why, v.at = "void", "expired", t
				changed("expired", id)
			elseif v.state == "offered" and (not live(v, t) or (tonumber(v.expires) or 0) <= t) then
				-- never accepted: the offer lapses, even one past its expiry (round 9: never "expired",
				-- which counts as given); the giver's window tells the rider
				v.state, v.why, v.at = "void", "lapsed", t
				giveBack(v)
				if v.by == W.myKey and v.addr then tellVoid(v.addr, id, "lapsed") end
				changed("lapsed", id)
			elseif (v.state == "used" or v.state == "void") and t - (v.at or v.issued or 0) > RAINCHECK.KEEP then
				b[id] = nil
			end
		end
		if n > RAINCHECK.BOOK_MAX then
			local oldest, at
			for id, v in pairs(b) do
				if (v.state == "used" or v.state == "void") and (not at or (v.issued or 0) < at) then oldest, at = id, v.issued or 0 end
			end
			if oldest then b[oldest] = nil end
		end
	end
	if #DR.recentPaid == 0 then return end
	local open = call("Selling") == true
	for _, e in ipairs(DR.recentPaid) do
		local c = DR.customers and DR.customers[e.key]
		local unit = DR.units and DR.units[e.key]
		if e.endedAt and not e.arrived then
			-- ended (closed), then summoned after all on the same ride: arrived (a prepaid rider's
			-- row is "paid", so the queue's here check doesn't run for it)
			if c and unit and DR.RideIdOf(c) == e.ride and (c.arrivedAt or call("ArrivedAt", c, unit)) then arrivedEntry(e) end
		elseif not e.arrived then
			if c and c.arrivedAt and DR.RideIdOf(c) == e.ride then
				arrivedEntry(e) -- the queue saw them here on this ride, even if they left the group since
			elseif not c then
				e.endedAt, e.why = t, "gone"
			elseif not unit and c.joinedAt then
				e.endedAt, e.why = t, "left" -- the rider left the group (one who paid before joining: not yet)
			elseif not open then
				e.endedAt, e.why = t, "closed"
			elseif unit and DR.RideIdOf(c) == e.ride and (c.arrivedAt or call("ArrivedAt", c, unit)) then
				arrivedEntry(e)
			end
		end
		if e.askWait and not e.asked and e.endedAt and DR.RaincheckEligible(e.ride) then askNow(e) end
	end
end

-- the book: every raincheck this crew gave, newest first (copies, with their id)
function DR.Rainchecks()
	local out = {}
	for id, v in pairs(book(false) or {}) do
		local copy = { id = id }
		for k, x in pairs(v) do copy[k] = x end
		out[#out + 1] = copy
	end
	table.sort(out, function(a, b)
		if (a.issued or 0) ~= (b.issued or 0) then return (a.issued or 0) > (b.issued or 0) end
		return a.id < b.id
	end)
	return out
end

-- given: the rider took it (active or used, or void after they took it); an offer waiting, declined
-- or lapsed is not. (A book saved before round 9 has no "taken": its expired ones count.)
local function wasGiven(v)
	if type(v) ~= "table" then return false end
	if v.state == "active" or v.state == "used" or v.taken then return true end
	return v.state == "void" and v.why == "expired"
end
-- DR.RaincheckGiven(entry) -> true when that book entry (or a DR.Rainchecks copy) counts as given
DR.RaincheckGiven = wasGiven

-- Earnings' line "Rainchecks: given 2 · used 1" since a time (default: today's start)
function DR.RaincheckCounts(since)
	since = tonumber(since) or 0
	local given, used = 0, 0
	for _, v in pairs(book(false) or {}) do
		if (v.issued or 0) >= since and wasGiven(v) then given = given + 1 end
		if v.state == "used" and (v.usedAt or 0) >= since then used = used + 1 end
	end
	return given, used
end

-- DR.recentPaid with the queue snapshot (Drive.Core): plain copies, back after a /reload
function DR.RecentPaidSave()
	if #DR.recentPaid == 0 then return nil end
	local out = {}
	for i, e in ipairs(DR.recentPaid) do
		local s = {}
		for k, v in pairs(e) do
			if type(v) == "string" or type(v) == "number" or type(v) == "boolean" then s[k] = v end
		end
		out[i] = s
	end
	return out
end

function DR.RecentPaidLoad(list)
	if type(list) ~= "table" then return end
	local t = stamp()
	for _, s in ipairs(list) do
		if type(s) == "table" and cleanRide(s.ride) and W.Str(s.key) and t - (tonumber(s.paidAt) or 0) < 86400
			and not recentFor(s.ride) and #DR.recentPaid < RAINCHECK.RECENT then
			DR.recentPaid[#DR.recentPaid + 1] = s
		end
	end
end
