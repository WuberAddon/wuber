-- Mutation run guards for Wuber/Core/Flights.lua and Wuber/Core/FlightTimes.lua.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function setupClient()
	local w = T.newWorld()
	local c = T.rider(w, T.ANITA, { spot = "Orgrimmar", class = "WARLOCK" })
	T.settle(w)
	return w, c, c.W
end

---------------------------------------------------------------------------
-- Wuber/Core/Flights.lua guards
---------------------------------------------------------------------------

-- guards Wuber/Core/Flights.lua:165 (drop statement: FlightPrune does not decrement count while pruning)
-- guards Wuber/Core/Flights.lua:168 (return -> nil: FlightPrune returns nil instead of count)
test("mutation b5 core flights: FlightPrune evicts oldest shared entries down to FLY.MAX and returns count", function()
	local w, c, W = setupClient()
	local FLY = W.FLY
	local store = {}
	W.db.flights = store
	for i = 1, FLY.MAX + 3 do
		store["H|Org|Place" .. i] = { c = 500, at = 100 + i, src = "shared" }
	end
	local n = W.FlightPrune()
	eq(n, FLY.MAX, "FlightPrune returns FLY.MAX after pruning")
	eq(store["H|Org|Place1"], nil, "oldest shared entry pruned")
	eq(store["H|Org|Place2"], nil, "second oldest shared entry pruned")
	eq(store["H|Org|Place3"], nil, "third oldest shared entry pruned")
	ok(store["H|Org|Place4"] ~= nil, "remaining entry kept")
	T.clean(w)
end)

-- guards Wuber/Core/Flights.lua:205 (local value -> nil: FlightMerge returns nil instead of false on unchanged merge)
-- guards Wuber/Core/Flights.lua:208 (drop statement: FlightMerge returns false when new peer vouches for same value)
-- guards Wuber/Core/Flights.lua:211 (drop statement: FlightMerge does not update e.at when newer timestamp arrives)
-- guards Wuber/Core/Flights.lua:212 (drop statement: FlightMerge returns false when timestamp updated)
-- guards Wuber/Core/Flights.lua:214 (return -> nil: FlightMerge returns nil instead of boolean on same-value merge)
-- guards Wuber/Core/Flights.lua:220 (return -> nil: FlightMerge returns nil instead of false when conflicting value loses)
test("mutation b5 core flights: FlightMerge handles same-value vouch/timestamp updates and conflicting value rejection", function()
	local w, c, W = setupClient()
	W.db.flights = {}
	local t0 = c.env.time() - 100
	-- Initial merge
	eq(W.FlightMerge("H", "Orgrimmar", "Crossroads", 500, nil, t0, "Bea"), true, "initial merge returns true")
	-- Same value, same peer, same timestamp -> unchanged (must return false, not nil)
	eq(W.FlightMerge("H", "Orgrimmar", "Crossroads", 500, nil, t0, "Bea"), false, "identical repeat returns false")
	-- Same value, new peer -> vouched, returns true
	eq(W.FlightMerge("H", "Orgrimmar", "Crossroads", 500, nil, t0, "Cal"), true, "new peer vouch returns true")
	-- Same value, same peer, newer timestamp -> updates e.at and returns true
	eq(W.FlightMerge("H", "Orgrimmar", "Crossroads", 500, nil, t0 + 10, "Bea"), true, "newer timestamp returns true")
	local key = "H|" .. W.NormPlace("Orgrimmar") .. "|" .. W.NormPlace("Crossroads")
	eq(W.db.flights[key].at, t0 + 10, "timestamp updated to newer value")
	-- Different value, not >60s newer and fewer peers -> rejected, must return false
	eq(W.FlightMerge("H", "Orgrimmar", "Crossroads", 900, nil, t0 + 20, "Dan"), false, "conflicting value within 60s returns false")
	T.clean(w)
end)

-- guards Wuber/Core/Flights.lua:259 (if cond negated: FlightShareList includes wrong-faction or non-table entries)
test("mutation b5 core flights: FlightShareList skips opposite-faction and non-table entries", function()
	local w, c, W = setupClient()
	local org = W.NormPlace("Orgrimmar")
	local xr = W.NormPlace("Crossroads")
	local sw = W.NormPlace("Stormwind")
	W.db.flights = {
		["H|" .. org .. "|" .. xr] = { c = 500, at = 100, src = "own" },
		["A|" .. org .. "|" .. xr] = { c = 500, at = 100, src = "own" },
		["A|" .. sw .. "|" .. xr] = { c = 500, at = 100, src = "own" },
		["H|" .. org .. "|junk"] = "not a table",
	}
	W.FLY.ver = W.FLY.ver + 1
	local list = W.FlightShareList()
	eq(#list, 1, "only matching-faction valid entry shared")
	eq(list[1].k, "H|" .. org .. "|" .. xr, "shared key matches Horde route")
	T.clean(w)
end)

-- Skipped: Wuber/Core/Flights.lua:395 (return -> nil: linked() is only used in boolean check at line 403, so false vs nil is unobservable)

-- guards Wuber/Core/Flights.lua:606 (drop statement: Migrate does not bump FLY.ver so FlightShareList cache stays stale)
test("mutation b5 core flights: Migrate bumps FLY.ver so FlightShareList refreshes", function()
	local w, c, W = setupClient()
	local org = W.NormPlace("Orgrimmar")
	local xr = W.NormPlace("Crossroads")
	W.db.flightsV = 2
	W.db.flights = {
		["H|" .. org .. "|" .. xr] = { t = 90, tat = 100, tsrc = "efm", tn = 2 },
	}
	W.FLY.ver = W.FLY.ver + 1
	-- Warm FlightShareList cache before Migrate
	local before = W.FlightShareList()
	eq(#before, 1, "cache populated before Migrate")
	local n = W.FLY.Migrate()
	eq(n, 1, "Migrate converted 1 efm entry")
	local after = W.FlightShareList()
	ok(before ~= after, "FlightShareList cache invalidated after Migrate")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- Wuber/Core/FlightTimes.lua guards
---------------------------------------------------------------------------

-- Skipped: Wuber/Core/FlightTimes.lua:103 (return -> nil: isBoat() is only used in elseif check at line 119, so false vs nil is unobservable)

-- guards Wuber/Core/FlightTimes.lua:133 (drop statement: median does not sort samples before picking middle)
-- guards Wuber/Core/FlightTimes.lua:137 (return -> nil: median returns nil for even-length sample list)
test("mutation b5 core flights: FlightTimes calibration computes sorted median for even sample counts", function()
	local w, c, W = setupClient()
	local FT = W.Mod("Core.FlightTimes")
	local tp, fp, mine = W.FLY.Pair("Orgrimmar", "Thunder Bluff")
	ok(tp and fp, "Pair found for Orgrimmar -> Thunder Bluff")
	local fly, other = FT.rawEstimate(fp, tp, mine)
	ok(fly and fly > 0, "rawEstimate available for Orgrimmar -> Thunder Bluff")
	-- 4 unsorted ratios: 1.3, 0.9, 1.1, 1.5 (sorted: 0.9, 1.1, 1.3, 1.5 -> median = 1.2)
	-- Seed 3 samples, then land a 4th flight at ratio 1.5
	W.db.flyCal = { n = 3, samples = { 1.3, 0.9, 1.1 }, ratio = 1.1 }
	c.env.UnitOnTaxi = function() return false end
	local secs = other + fly * 1.5
	local t0 = c.env.GetServerTime()
	c.W.Char().flightStart = {
		from = W.NormPlace("Orgrimmar"),
		to = W.NormPlace("Thunder Bluff"),
		fromName = "Orgrimmar",
		dest = "Thunder Bluff",
		side = "H",
		at = t0 - math.floor(secs + 0.5),
		exp = 400,
	}
	-- Resume while on taxi, then land at Thunder Bluff
	local origDestHere = W.DestHere
	W.DestHere = function() return nil, { name = "Thunder Bluff" } end
	c.env.UnitOnTaxi = function() return true end
	FT.resume()
	c.env.UnitOnTaxi = function() return false end
	c:fire("PLAYER_CONTROL_GAINED")
	W.DestHere = origDestHere
	local ratio, n = FT.Calibration()
	eq(n, 4, "4 calibration samples")
	ok(math.abs(ratio - 1.2) < 0.01, "sorted even-count median ratio is ~1.2, got " .. tostring(ratio))
	T.clean(w)
end)

-- guards Wuber/Core/FlightTimes.lua:254 (drop statement: takenOff does not drop pending flight after START_WAIT)
test("mutation b5 core flights: FlightTimes drops pending flight if never on taxi past START_WAIT", function()
	local w, c, W = setupClient()
	local FT = W.Mod("Core.FlightTimes")
	local origNodes, origName, origType = c.env.NumTaxiNodes, c.env.TaxiNodeName, c.env.TaxiNodeGetType
	c.env.UnitOnTaxi = function() return false end
	c.env.TaxiNodeName = function(slot) return slot == 1 and "Orgrimmar" or "Thunder Bluff" end
	c.env.TaxiNodeGetType = function(slot) return slot == 1 and "CURRENT" or "REACHABLE" end
	c.env.NumTaxiNodes = function() return 2 end
	FT.MapOpened()
	FT.clicked(2)
	w:advance(7) -- past FT.START_WAIT (5s)
	-- Now even if player gets on a taxi later, the stale pending flight must have been dropped
	c.env.UnitOnTaxi = function() return true end
	c:fire("PLAYER_CONTROL_LOST")
	eq(W.FlightLeft(), nil, "stale pending flight dropped after START_WAIT")
	c.env.NumTaxiNodes, c.env.TaxiNodeName, c.env.TaxiNodeGetType = origNodes, origName, origType
	T.clean(w)
end)

-- guards Wuber/Core/FlightTimes.lua:309 (swap and->or: RIDE listener crashes or misreads W.ride when event arg is nil)
-- guards Wuber/Core/FlightTimes.lua:310 (cmp ==->~=: RIDE portal/arrived does not drop pending flight)
test("mutation b5 core flights: FlightTimes drops pending flight on RIDE portal or arrived", function()
	local w, c, W = setupClient()
	local FT = W.Mod("Core.FlightTimes")
	local origNodes, origName, origType = c.env.NumTaxiNodes, c.env.TaxiNodeName, c.env.TaxiNodeGetType
	c.env.TaxiNodeName = function(slot) return slot == 1 and "Orgrimmar" or "Thunder Bluff" end
	c.env.TaxiNodeGetType = function(slot) return slot == 1 and "CURRENT" or "REACHABLE" end
	c.env.NumTaxiNodes = function() return 2 end
	c.env.UnitOnTaxi = function() return true end
	FT.MapOpened()
	-- 1. Direct RIDE event with state = "portal"
	FT.clicked(2)
	c:fire("PLAYER_CONTROL_LOST")
	ok(W.FlightLeft() ~= nil, "flight active before RIDE portal")
	W.Fire("RIDE", { state = "portal" })
	eq(W.FlightLeft(), nil, "pending flight dropped on RIDE portal")
	-- 2. RIDE event with nil arg falling back to W.ride (state = "arrived")
	FT.clicked(2)
	c:fire("PLAYER_CONTROL_LOST")
	ok(W.FlightLeft() ~= nil, "flight active before RIDE nil/arrived")
	W.ride = { state = "arrived" }
	W.Fire("RIDE")
	W.ride = nil
	eq(W.FlightLeft(), nil, "pending flight dropped when W.ride is arrived")
	c.env.NumTaxiNodes, c.env.TaxiNodeName, c.env.TaxiNodeGetType = origNodes, origName, origType
	T.clean(w)
end)

-- guards Wuber/Core/FlightTimes.lua:348 (drop statement: resume does not wire PLAYER_CONTROL_GAINED)
-- guards Wuber/Core/FlightTimes.lua:352 (drop statement: resume does not start tick timer)
test("mutation b5 core flights: FlightTimes resume wires events and starts landing ticker", function()
	local w, c, W = setupClient()
	local FT = W.Mod("Core.FlightTimes")
	local t0 = c.env.GetServerTime()
	c.W.Char().flightStart = {
		from = W.NormPlace("Orgrimmar"),
		to = W.NormPlace("Thunder Bluff"),
		fromName = "Orgrimmar",
		dest = "Thunder Bluff",
		side = "H",
		at = t0 - 10,
		exp = 400,
	}
	c.env.UnitOnTaxi = function() return true end
	FT.resume()
	ok(W.FlightLeft() ~= nil, "resume restores active flight")
	-- Ticker (line 352) should detect landing when UnitOnTaxi becomes false
	local landedEvent = false
	W.Listen("FLIGHT_TIME", function() landedEvent = true end)
	local origDestHere = W.DestHere
	W.DestHere = function() return nil, { name = "Thunder Bluff" } end
	c.env.UnitOnTaxi = function() return false end
	w:advance(1.5) -- past FT.TICK (0.5s)
	W.DestHere = origDestHere
	eq(W.FlightLeft(), nil, "ticker clears flight on landing after resume")
	eq(landedEvent, true, "ticker fired FLIGHT_TIME on landing without PLAYER_CONTROL_GAINED")
	-- Also verify wire() (line 348) wired RIDE listener after resume
	c.W.Char().flightStart = {
		from = W.NormPlace("Orgrimmar"),
		to = W.NormPlace("Thunder Bluff"),
		fromName = "Orgrimmar",
		dest = "Thunder Bluff",
		side = "H",
		at = t0 - 10,
		exp = 400,
	}
	c.env.UnitOnTaxi = function() return true end
	FT.resume()
	W.Fire("RIDE", { state = "portal" })
	eq(W.FlightLeft(), nil, "wire() wired RIDE listener on resume")
	T.clean(w)
end)

-- guards Wuber/Core/FlightTimes.lua:395 (swap and->or: MapCal accepts missing c.a when remaining coefficients are present)
test("mutation b5 core flights: MapCal returns nil when any affine coefficient is missing", function()
	local w, c, W = setupClient()
	local FT = W.Mod("Core.FlightTimes")
	local pts = {}
	local cont
	for id, n in pairs(W.TAXI.nodes) do
		if type(n) == "table" and n[2] == 1 then
			cont = 1
			pts[id] = true
			if #pts >= 0 then end
		end
	end
	W.db.mapCal = {
		[cont] = { a = nil, b = 0, c = 0, d = -1, e = 0, f = 0, pts = pts },
	}
	eq(FT.MapCal(cont), nil, "MapCal returns nil when coefficient a is missing")
	T.clean(w)
end)
