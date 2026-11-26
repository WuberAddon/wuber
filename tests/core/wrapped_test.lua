-- Tests of Core.Wrapped. Loaded by tests/run.lua with its helper table T.
-- The month maths: local month boundaries, the est flag, the longest hop by world distance, new
-- places against earlier months, the streak, the driver's month; stores nothing.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function at(y, m, d, h) return os.time({ year = y, month = m, day = d, hour = h or 12, min = 0, sec = 0 }) end

test("core.wrapped: contract (registered, deps, header, public names); idle without trips", function()
	local W, w, r, Mod = T.contract("Core.Wrapped", "tests/core/wrapped_test.lua", {
		["Mod.Month"] = "function", ["Mod.Range"] = "function", ["Mod.Key"] = "function", ["Mod.MonthName"] = "function",
	})
	ok(Mod, "W.Mod(\"Core.Wrapped\")")
	local m = Mod.Month(2026, 10)
	eq(m and m.rides, 0, "no rides in October")
	eq(Mod.Month(2026, 13), nil, "no month 13")
	eq(Mod.Key(2026, 3), "2026-03", "the key")
	eq(W.db.wrapped, nil, "nothing saved")
	T.clean(w)
end)

test("core.wrapped: month maths (boundaries, est, longest hop, new places, streak, tier, driver)", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W = r.W
	local Mod = W.Mod("Core.Wrapped")
	W.db.rides = {
		{ at = at(2026, 9, 20), dest = "Undercity", driver = "Mia Runner", driverKey = "mia runner", price = 5000 },
		{ at = at(2026, 9, 30, 23), dest = "Ratchet", driver = "Mia Runner", driverKey = "mia runner", price = 5000 },
		-- October: the 1st 00:30 is October in local time
		{ at = at(2026, 10, 1, 0) + 1800, dest = "Undercity", driver = "Mia Runner", driverKey = "mia runner", price = 5000,
			saved = 600, savedHow = "own", flightCost = 2300, flightExact = 1, fromZone = "Orgrimmar" },
		{ at = at(2026, 10, 2), dest = "Gadgetzan", driver = "Bea Jones", driverKey = "bea jones", price = 6000, saved = 300,
			fromZone = "Orgrimmar" },
		{ at = at(2026, 10, 3), dest = "Undercity", driver = "Mia Runner", driverKey = "mia runner", price = 5000, saved = 900, savedHow = "own" },
		{ at = at(2026, 10, 9), dest = "Ratchet", driver = "Mia Runner", driverKey = "mia runner", price = 5000, unpaid = true },
		{ at = at(2026, 10, 31, 23) + 3000, dest = "Ratchet", driver = "Mia Runner", driverKey = "mia runner", price = 4000 },
		{ at = at(2026, 11, 1, 0) + 60, dest = "Moonglade", driver = "Bea Jones", driverKey = "bea jones", price = 9000 },
	}
	-- world positions: Orgrimmar - Gadgetzan is the longer hop
	local world = { orgrimmar = { 1, 0, 0 }, undercity = { 0, 0, 0 }, gadgetzan = { 1, 3000, 4000 } }
	W.ExactPlace = function(n) local k = tostring(n):lower() return world[k] and { name = n, k = k } or { name = n } end
	W.PlaceWorld = function(p) local c = p.k and world[p.k] if c then return c[1], c[2], c[3] end return nil end
	local m = Mod.Month(2026, 10)
	eq(m.rides, 4, "four paid rides in October (unpaid and the neighbours left out)")
	eq(m.places, 3, "Undercity, Gadgetzan, Ratchet")
	eq(m.topPlace, "Undercity", "top place")
	eq(m.topDriver, "Mia", "favourite driver (short)")
	eq(m.saved, 1800, "time saved")
	eq(m.about, true, "one estimate makes it 'about'")
	eq(m.flightSaved, 2300, "exact flight prices only")
	eq(m.spent, 20000, "spent")
	eq(m.longestHop and m.longestHop.to, "Gadgetzan", "longest hop by world distance")
	eq(m.longestHop and m.longestHop.yards, 5000, "its yards")
	eq(table.concat(m.newPlaces, ","), "Gadgetzan", "new places: Undercity and Ratchet were seen in September")
	eq(m.streak, 3, "1st, 2nd and 3rd in a row")
	eq(m.name, "October", "the month's name")
	eq(m.capped, false, "not capped")
	-- all own: no "about"
	W.db.rides[4].savedHow = "own"
	eq(Mod.Month(2026, 10).about, false, "all measured")
	-- September and November
	eq(Mod.Month(2026, 9).rides, 2, "September")
	eq(Mod.Month(2026, 11).rides, 1, "November 1st 00:01")
	-- the driver's month from the log
	W.db.drive = W.db.drive or {}
	W.db.drive.log = { rides = { at(2026, 10, 5, 20) .. ",5000,Dan,Undercity,t,5000", at(2026, 10, 6, 20) .. ",6000,Eve,Undercity,t,5000",
		at(2026, 10, 6, 9) .. ",5000,Fay,Undercity,t,5000", at(2026, 9, 6, 9) .. ",5000,Old,Undercity,t,5000" },
		cut = { { at = at(2026, 10, 6, 21), clicks = { farra = 4, hayley = 2 } } } }
	local d = Mod.Month(2026, 10).driver
	eq(d and d.rides, 3, "driver rides")
	eq(d and d.gold, 16000, "driver gold")
	eq(d and d.bestHour, 20, "best hour")
	eq(d and d.helpers, 2, "helpers thanked")
	eq(W.db.wrapped, nil, "nothing saved")
	T.clean(w)
end)
