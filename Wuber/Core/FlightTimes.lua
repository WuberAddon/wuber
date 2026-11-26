-- Module: Core.FlightTimes
-- Purpose: real flight times with no other addon: records the player's own flights (TakeTaxiNode
--   hook, take-off and landing), the estimate from the game's own flight splines and its calibration,
--   the cheapest route's node ids for the map, and the flight map's calibration (TaxiNodePosition).
-- API: W.FlightRoute, W.OnTaxi, W.FlightLeft, Mod.resume, Mod.Estimate, Mod.MapOpened, Mod.MapClosed,
--   Mod.Calibration, Mod.MapCal, Mod.FitAffine
-- Internals: (none)
-- Uses: Core.Places, Core.Flights
-- Later: (none)
-- Events: listens (none at load; from the first flight taken: On PLAYER_CONTROL_LOST, On
--   PLAYER_CONTROL_GAINED, On PLAYER_ENTERING_WORLD, On PLAYER_LOGOUT, On CONFIRM_SUMMON, Listen
--   RIDE); fires FLIGHT_TIME, FLIGHTS
-- Standalone: no
-- Test: tests/core/flighttimes_test.lua
-- From: new in Wuber 2.3.0 (SPEC7 section 4; owner B)
--
-- Nothing runs at load (one W.OnLogin function: Mod.resume, below). Core.Flights' own flight-map listeners call Mod.MapOpened (TAXIMAP_OPENED)
-- and Mod.MapClosed (TAXIMAP_CLOSED); the first MapOpened hooks TakeTaxiNode (hooksecurefunc: a
-- hook, never a replacement, so nothing is tainted), and the first click registers the four
-- flight listeners. A player who never flies gets nothing new.
--
-- Recording (SPEC7 4.2): a click on the flight map (TakeTaxiNode(slot)) remembers from (the
-- CURRENT node) and to (that slot), both as Core.Flights' store keys (towns this side flies to).
-- Take-off: UnitOnTaxi("player") within 5 s of the click (PLAYER_CONTROL_LOST, and a 0.5 s ticker).
-- Landing: PLAYER_CONTROL_GAINED off the taxi, or (LRN-01) the same ticker seeing UnitOnTaxi turn
-- false: the landing event can come while the flag is still set, and it does not come again. The
-- ticker runs only while a flight is timed: it stops at landing, on a drop, or FLY.MAX_SECS +
-- FT.LAND_MARGIN after take-off (the flight is then dropped) -> seconds. Nothing
-- is stored when: the time is outside 5 s..1 h; a loading screen (PLAYER_ENTERING_WORLD) or a
-- logout came mid-flight; the player didn't land at `to` (the place they stand at, or the flight
-- point next to them); an end isn't a known town; another click came before landing. Stored as
-- W.db.flights[side|from|to].t, tsrc "own" (FLY.SetOwnTime: within 10 % the smaller stays); fires
-- FLIGHT_TIME(from, to, secs) and FLIGHTS; the pool (Net.Flights, kind F) shares it from there.
--
-- Estimate (SPEC7 4.3): the cheapest route's legs (Core.Flights' Dijkstra over W.TAXI), each
-- yards / FLY.SPEED + its stop seconds (W.TAXI.lens), a boat or zeppelin FLY.CROSS, plus
-- FLY.TAKEOFF per flight. Calibration: each own flight with an estimate gives a ratio (measured
-- over estimated flying time); from 3 ratios the median (of the last 9) multiplies every
-- spline time: W.db.flyCal = { ratio, n, samples }. These are labelled "est" ("about" on
-- screen) and never stored or shared.
--
-- Map calibration (SPEC7 3.3 step 2): at a flight master, TaxiNodePosition(i) (map u, v on the
-- continent map) of nodes whose world position W.TAXI knows; 3 or more distinct nodes -> a
-- least-squares affine u = a*wx + b*wy + c, v = d*wx + e*wy + f in W.db.mapCal[continent] =
-- { a, b, c, d, e, f, n, at, pts } (pts: the samples by node id, so it improves with each visit).
-- Written only when a usable sample was read (positions of 0, 0 are the game's "unknown").
-- (round 9, C11) Which way v runs is read from the data, not assumed: north is +world x and the
-- top of every continent map, so a top-down v falls as x grows (d < 0). A fit with d > 0 (and x
-- the main term) came from a bottom-up v (the classic flight map's BOTTOMLEFT origin); MapCal
-- hands it back flipped (v' = 1 - v). The saved points are never changed, so no new version.
-- Without FT.MAPCAL_NS yards of north-south spread among the points (or with |d| < |e|) the
-- direction can't be told: MapCal gives nil and the world map keeps its node-box fallback.

local _, W = ...
local Mod = W.Module("Core.FlightTimes", { "Core.Places", "Core.Flights" })
local PlacesMod = W.Mod("Core.Places")
local call, exact = PlacesMod.call, PlacesMod.exact

local str, num = W.Str, W.Num

local FT = {
	START_WAIT = 5,   -- seconds from the click to take-off
	TICK = 0.5,       -- the take-off and landing check while a flight is timed
	LAND_MARGIN = 60, -- (LRN-01) seconds past FLY.MAX_SECS before an unfinished flight is given up
	CAL_MIN = 3,      -- ratios before the median is used
	CAL_KEEP = 9,     -- ratios kept
	RATIO_LO = 0.33, RATIO_HI = 3, -- a ratio outside this is a broken measurement
	LAND_YARDS = 300, -- "landed at to": the flight point this near
	MAPCAL_PTS = 80,  -- samples kept per continent
	MAPCAL_NS = 2000, -- (round 9, C11) yards of north-south spread before the fit's direction is trusted
}
Mod.FT = FT

local function side()
	local s = W.Faction and W.Faction() or nil
	if s == "H" or s == "A" then return s end
	return nil
end

local function now() return num(call(GetTime)) or 0 end

---------------------------------------------------------------------------
-- The estimate
---------------------------------------------------------------------------

local lensFor, lensIdx -- W.TAXI.lens -> { ["a>b"] = { yards, delay } }
local function lensIndex()
	local T = W.TAXI
	local L = type(T) == "table" and type(T.lens) == "table" and T.lens or nil
	if lensFor == L and lensIdx then return lensIdx end
	lensFor, lensIdx = L, {}
	if L then
		for i = 1, #L - 3, 4 do lensIdx[L[i] .. ">" .. L[i + 1]] = { L[i + 2], L[i + 3] } end
	end
	return lensIdx
end

local function isBoat(a, b)
	local B = type(W.TAXI) == "table" and type(W.TAXI.boats) == "table" and W.TAXI.boats or {}
	for i = 1, #B - 2, 3 do
		if (B[i] == a and B[i + 1] == b) or (B[i] == b and B[i + 1] == a) then return true end
	end
	return false
end

-- The route's flying seconds at FLY.SPEED (uncalibrated) and its other seconds (take-offs,
-- crossings); nil when the table can't route it or a leg has no length.
local function rawEstimate(from, to, mine)
	local FLY, s = W.FLY, side()
	if type(FLY) ~= "table" or type(FLY.Route) ~= "function" or not s then return nil end
	local path = FLY.Route(from, to, mine, s)
	if type(path) ~= "table" or #path < 2 then return nil end
	local lens = lensIndex()
	local fly, other = 0, FLY.TAKEOFF
	for i = 1, #path - 1 do
		local l = lens[path[i] .. ">" .. path[i + 1]]
		if l then
			fly = fly + l[1] / FLY.SPEED + l[2]
		elseif isBoat(path[i], path[i + 1]) then
			other = other + FLY.CROSS + FLY.TAKEOFF
		else
			return nil
		end
	end
	if fly <= 0 and other <= FLY.TAKEOFF then return nil end
	return fly, other
end
Mod.rawEstimate = rawEstimate

local function median(list)
	local t = {}
	for i, v in ipairs(list) do t[i] = v end
	table.sort(t)
	local n = #t
	if n == 0 then return nil end
	if n % 2 == 1 then return t[(n + 1) / 2] end
	return (t[n / 2] + t[n / 2 + 1]) / 2
end

-- The calibration in use: ratio (1 until 3 own flights had an estimate), samples taken.
function Mod.Calibration()
	local c = type(W.db) == "table" and W.db.flyCal or nil
	if type(c) ~= "table" then return 1, 0 end
	local n, r = num(c.n) or 0, num(c.ratio)
	if n >= FT.CAL_MIN and r and r >= FT.RATIO_LO and r <= FT.RATIO_HI then return r, n end
	return 1, n
end

-- Seconds an estimate says (from, to: places; mine: from is where the player stands), or nil.
function Mod.Estimate(from, to, mine)
	local fly, other = rawEstimate(from, to, mine)
	if not fly then return nil end
	local secs = fly * Mod.Calibration() + other
	if secs < W.FLY.MIN_SECS then return nil end
	return math.floor(math.min(secs, W.FLY.MAX_SECS) + 0.5)
end

-- One own flight's ratio into the calibration (from, to: store keys); skipped when the estimate
-- route has a boat or zeppelin leg, since the taxi ride flew other legs.
local function calibrate(a, b, secs)
	local d0 = W.db
	if type(d0) ~= "table" then return end
	local fly, other = rawEstimate(exact(a), exact(b), false)
	if not fly or fly <= 0 then return end
	if other > W.FLY.TAKEOFF then return end   -- a boat or zeppelin leg: the taxi ride is not that route
	local ratio = (secs - other) / fly
	if ratio < FT.RATIO_LO or ratio > FT.RATIO_HI then return end
	local c = type(d0.flyCal) == "table" and d0.flyCal or {}
	d0.flyCal = c
	local samples = type(c.samples) == "table" and c.samples or {}
	c.samples = samples
	samples[#samples + 1] = math.floor(ratio * 10000 + 0.5) / 10000
	while #samples > FT.CAL_KEEP do table.remove(samples, 1) end
	c.n = (num(c.n) or 0) + 1
	if c.n >= FT.CAL_MIN then c.ratio = median(samples) end
end

-- The cheapest route's flight-master node ids (W.TAXI.nodes) from one place to another
-- (from nil: where the player stands), for the gold route on the map; nil when none.
function W.FlightRoute(from, to)
	local FLY = W.FLY
	if type(FLY) ~= "table" or type(FLY.Pair) ~= "function" then return nil end
	local tp, fp, mine = FLY.Pair(from, to)
	if not tp then return nil end
	local path = FLY.Route(fp, tp, mine, side())
	if type(path) ~= "table" or #path < 2 then return nil end
	local out = {}
	for i, id in ipairs(path) do out[i] = id end
	return out
end

---------------------------------------------------------------------------
-- Recording the player's own flights
---------------------------------------------------------------------------

local pend          -- the flight under way: { from, to, clickAt, startAt, ticker }
local names = {}    -- the open flight map: [slot] = node name; names.current
local hooked, wired = false, false

local function stopTicker(p)
	if p and p.ticker then
		pcall(p.ticker.Cancel, p.ticker)
		p.ticker = nil
	end
end

-- (Polestar idea 4) the flight in the air is also saved with the SERVER's clock, so a /reload keeps it:
-- W.Char().flightStart = { from, to, fromName, dest, side, at (GetServerTime), exp (expected seconds) }.
local function saveStart(p)
	local ok, c = pcall(W.Char)
	if not ok or type(c) ~= "table" then return end
	local at = num(call(GetServerTime))
	if not at then return end
	local exp
	if p.dest and type(W.FlightTime) == "function" then exp = num(call(W.FlightTime, p.fromName, p.dest)) end
	if not exp or exp <= 0 then exp = W.FLY.MAX_SECS end
	c.flightStart = { from = p.from, to = p.to, fromName = p.fromName, dest = p.dest, side = p.side, at = at, exp = exp }
end

local function forgetStart()
	local ok, c = pcall(W.Char)
	if ok and type(c) == "table" then c.flightStart = nil end
end

-- keep: the saved start stays (a /reload or logout mid-flight; the next login decides)
local function drop(keep)
	stopTicker(pend)
	pend = nil
	if not keep then forgetStart() end
end

local function onTaxi() return call(UnitOnTaxi, "player") == true end

function W.OnTaxi() return onTaxi() end

-- Seconds left of the flight being timed (never negative), or nil when unknown; second value is
-- the destination flight point's name when known. Read-only.
function W.FlightLeft()
	local p = pend
	if not p or not p.startAt or not onTaxi() then return nil end
	local dest = p.dest
	if not dest then return nil end
	local total = type(W.FlightTime) == "function" and num(call(W.FlightTime, p.fromName, dest)) or nil
	if not total or total <= 0 then return nil, dest end
	return math.max(0, total - math.max(0, now() - p.startAt)), dest
end

local function takenOff()
	if not pend or pend.startAt then return end
	if onTaxi() then
		pend.startAt = now()
		saveStart(pend)
	elseif now() - pend.clickAt > FT.START_WAIT then
		drop()
	end
end

-- Whether the player stands at place key `to`: the place here, or the flight point next to them.
local function landedAt(to)
	local _, p = W.DestHere()
	if p and W.NormPlace(p.name) == to then return true end
	local cont, wx, wy = W.WorldPos(W.MyPosition())
	if not cont then return false end
	local FLY = W.FLY
	local d = FLY.TaxiData()
	for _, id in ipairs(d.at[to] or {}) do
		local n = d.nodes[id]
		if n and n[2] == cont then
			local dx, dy = n[3] - wx, n[4] - wy
			if math.sqrt(dx * dx + dy * dy) <= FT.LAND_YARDS then return true end
		end
	end
	return false
end

local function landed()
	local p = pend
	if not p or not p.startAt or onTaxi() then return end
	drop()
	local secs = now() - p.startAt
	local FLY, s = W.FLY, side()
	if secs < FLY.MIN_SECS or secs > FLY.MAX_SECS or s ~= p.side or not landedAt(p.to) then return end
	local t = FLY.SetOwnTime(s, p.from, p.to, secs)
	if not t then return end
	calibrate(p.from, p.to, math.floor(secs + 0.5))
	W.Fire("FLIGHT_TIME", p.from, p.to, t)
	W.Fire("FLIGHTS")
end

-- (LRN-01) the ticker after take-off: the landing seen by the flag, and the time limit
local function tick()
	local p = pend
	if not p then return end
	if not p.startAt then return takenOff() end
	if not onTaxi() then return landed() end
	if now() - p.startAt > W.FLY.MAX_SECS + FT.LAND_MARGIN then drop() end
end

local function wire()
	if wired then return end
	wired = true
	W.On("PLAYER_CONTROL_LOST", takenOff)
	W.On("PLAYER_CONTROL_GAINED", landed)
	W.On("PLAYER_ENTERING_WORLD", function(_, isReload) if pend and not isReload then drop() end end)
	W.On("PLAYER_LOGOUT", function() if pend then drop(true) end end)
	W.On("CONFIRM_SUMMON", function() if pend then drop() end end)
	W.Listen("RIDE", function(r)
		if not pend then return end
		r = type(r) == "table" and r or W.ride
		if type(r) == "table" and (r.state == "portal" or r.state == "arrived") then drop() end
	end)
end

-- The click (after the game's TakeTaxiNode ran).
local function clicked(slot)
	slot = num(slot)
	if pend and pend.startAt then -- a second flight before landing: neither counts
		drop()
		return
	end
	drop()
	local s, FLY = side(), W.FLY
	if not slot or not s then return end
	local fromName = names.current
	local toName = names[slot] or str(call(TaxiNodeName, slot))
	local fromPlace, toPlace = FLY.NodePlace(fromName), FLY.NodePlace(toName)
	local a, b = FLY.places(s, fromPlace, toPlace)
	if not a then return end
	wire()
	pend = { from = a, to = b, fromName = str(fromPlace), dest = str(toPlace), side = s, clickAt = now() }
	pend.ticker = W.Every(FT.TICK, tick)
end
Mod.clicked = clicked

-- (Polestar idea 4) after a /reload in the air: still on a taxi and the saved start younger than its
-- expected seconds plus FT.LAND_MARGIN -> the flight is timed again from the server's clock; else the
-- saved start is dropped and no flight time is recorded.
local function resume()
	local ok, c = pcall(W.Char)
	local s = ok and type(c) == "table" and c.flightStart or nil
	if type(s) ~= "table" then return end
	c.flightStart = nil
	local at, exp, srv = num(s.at), num(s.exp), num(call(GetServerTime))
	if not at or not exp or not srv or type(s.from) ~= "string" or type(s.to) ~= "string"
		or (s.side ~= "H" and s.side ~= "A") or not onTaxi() then return end
	local age = srv - at
	if age < 0 or age > exp + FT.LAND_MARGIN then return end
	wire()
	pend = { from = s.from, to = s.to, fromName = str(s.fromName), dest = str(s.dest), side = s.side,
		clickAt = now() - age, startAt = now() - age }
	c.flightStart = s
	pend.ticker = W.Every(FT.TICK, tick)
end
Mod.resume = resume
W.OnLogin(resume)

local function hook()
	if hooked or type(hooksecurefunc) ~= "function" or type(TakeTaxiNode) ~= "function" then return end
	local ok = pcall(hooksecurefunc, "TakeTaxiNode", function(slot) W.Safe("flight taken", clicked, slot) end)
	hooked = ok
end

---------------------------------------------------------------------------
-- The flight map's calibration (TaxiNodePosition)
---------------------------------------------------------------------------

-- Least squares: samples { { wx, wy, u, v }, ... } (3 or more, not all in a line) ->
-- a, b, c, d, e, f with u = a*wx + b*wy + c, v = d*wx + e*wy + f; nil when degenerate.
function Mod.FitAffine(samples)
	if type(samples) ~= "table" or #samples < 3 then return nil end
	-- centred for a well-conditioned 2 x 2 solve
	local n, mx, my, mu, mv = #samples, 0, 0, 0, 0
	for _, p in ipairs(samples) do mx, my, mu, mv = mx + p[1], my + p[2], mu + p[3], mv + p[4] end
	mx, my, mu, mv = mx / n, my / n, mu / n, mv / n
	local sxx, sxy, syy, sxu, syu, sxv, syv = 0, 0, 0, 0, 0, 0, 0
	for _, p in ipairs(samples) do
		local x, y, u, v = p[1] - mx, p[2] - my, p[3] - mu, p[4] - mv
		sxx, sxy, syy = sxx + x * x, sxy + x * y, syy + y * y
		sxu, syu, sxv, syv = sxu + x * u, syu + y * u, sxv + x * v, syv + y * v
	end
	local det = sxx * syy - sxy * sxy
	if math.abs(det) < 1e-9 * math.max(1, sxx * syy) then return nil end
	local a = (sxu * syy - syu * sxy) / det
	local b = (syu * sxx - sxu * sxy) / det
	local d = (sxv * syy - syv * sxy) / det
	local e = (syv * sxx - sxv * sxy) / det
	return a, b, mu - a * mx - b * my, d, e, mv - d * mx - e * my
end

-- The calibration for a continent: { a, b, c, d, e, f, n, at } or nil, v always top-down
-- (flipped = true when the saved fit's v ran bottom-up; see the header).
function Mod.MapCal(cont)
	local all = type(W.db) == "table" and W.db.mapCal or nil
	local c = type(all) == "table" and all[cont] or nil
	if type(c) ~= "table" or not (num(c.a) and num(c.b) and num(c.c) and num(c.d) and num(c.e) and num(c.f)) then return nil end
	-- (round 9, C11 review) the direction is read from north-south spread: points mostly east-west
	-- can't tell it (|d| below |e|, or too little spread), so the fit stays unknown and the map
	-- uses its node box instead
	local lo, hi
	for id in pairs(type(c.pts) == "table" and c.pts or {}) do
		local n = type(W.TAXI) == "table" and W.TAXI.nodes and W.TAXI.nodes[id]
		local x = n and n[2] == cont and num(n[3])
		if x then lo, hi = math.min(lo or x, x), math.max(hi or x, x) end
	end
	if not lo or hi - lo < FT.MAPCAL_NS or math.abs(c.d) < math.abs(c.e) then return nil end
	if c.d > 0 then
		return { a = c.a, b = c.b, c = c.c, d = -c.d, e = -c.e, f = 1 - c.f, n = c.n, at = c.at, flipped = true }
	end
	return c
end

-- The W.TAXI node a flight-map name means, for side s.
local function taxiNode(name, s)
	local key = W.NormPlace(W.FLY.NodePlace(name) or "")
	if key == "" then return nil end
	local T = W.TAXI
	local best
	for id, n in pairs(type(T) == "table" and T.nodes or {}) do
		if W.NormPlace(n[1]) == key and W.FLY.Usable(n, s) and (not best or id < best) then best = id end
	end
	return best
end

local function learnMapCal(count, s)
	local d0 = W.db
	if type(d0) ~= "table" or type(TaxiNodePosition) ~= "function" or not s then return 0 end
	local got = 0
	for i = 1, math.min(count, 200) do
		local u, v = call(TaxiNodePosition, i)
		u, v = num(u), num(v)
		if u and v and u > 0 and v > 0 and u < 1 and v < 1 then
			local id = taxiNode(names[i], s)
			local n = id and W.TAXI.nodes[id]
			if n then
				local all = type(d0.mapCal) == "table" and d0.mapCal or {}
				d0.mapCal = all
				local c = type(all[n[2]]) == "table" and all[n[2]] or {}
				all[n[2]] = c
				c.pts = type(c.pts) == "table" and c.pts or {}
				local have = 0
				for _ in pairs(c.pts) do have = have + 1 end
				if c.pts[id] or have < FT.MAPCAL_PTS then
					c.pts[id] = { math.floor(u * 1e5 + 0.5) / 1e5, math.floor(v * 1e5 + 0.5) / 1e5 }
					got = got + 1
				end
			end
		end
	end
	if got == 0 then return 0 end
	for cont, c in pairs(d0.mapCal) do
		if type(c) == "table" and type(c.pts) == "table" then
			local samples = {}
			for id, uv in pairs(c.pts) do
				local n = W.TAXI.nodes[id]
				if n and n[2] == cont and type(uv) == "table" then samples[#samples + 1] = { n[3], n[4], uv[1], uv[2] } end
			end
			table.sort(samples, function(p, q) return p[1] < q[1] or (p[1] == q[1] and p[2] < q[2]) end)
			local a, b, cc, d, e, f = Mod.FitAffine(samples)
			if a then
				c.a, c.b, c.c, c.d, c.e, c.f, c.n, c.at = a, b, cc, d, e, f, #samples, num(call(time)) or 0
			end
		end
	end
	return got
end

---------------------------------------------------------------------------
-- The flight map (Core.Flights' listeners call these)
---------------------------------------------------------------------------

function Mod.MapOpened()
	names = {}
	local count = num(call(NumTaxiNodes)) or 0
	for i = 1, math.min(count, 200) do
		local nm = str(call(TaxiNodeName, i))
		names[i] = nm
		if nm and str(call(TaxiNodeGetType, i)) == "CURRENT" then names.current = nm end
	end
	hook()
	learnMapCal(count, side())
end

-- (the click closes the map: the take-off check is already running from the click)
function Mod.MapClosed()
	if pend and not pend.startAt then takenOff() end
end
