-- Tests of UI.Kit (Wuber/UI/Kit.lua). Loaded by tests/run.lua with its helper table T.
-- Final home: tests/ui/kit_test.lua; add it to the per-module list in tests/run.lua.
-- Pins:
--   the contract (W.UI, the window numbers, the helpers every rider screen uses)
--   UI.Duration's words at the minute and hour edges; UI.Ordinal's 11th/12th/13th; UI.SummonWait's 10..900 window
--   UI.Driver cleans a heard driver (unknown state = paused, team 1..3, queue 0..40, no negative price, map x/y in 0..1,
--   out-of-range average and rank dropped) and finds a driver by name as well as by key
--   UI.Ride: no ride is nil; the summoner equal to the driver is dropped; a summon up while summoning is portalUp
--   UI.HabitLine: streak, favourite (only this ride's driver when asked), spend; nil when nothing is worth saying
-- Why it matters to a player: every rider screen reads drivers and the ride through these views. If they broke, a
-- driver could show a negative fare or a nonsense queue, a pin could sit off the map, "1 h" could read "60 min",
-- and Done could praise the wrong favourite driver.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.kit: contract (registered, deps, header, public names) and the window numbers", function()
	local W, w, r, Mod = T.contract("UI.Kit", "tests/ui/kit_test.lua", {
		["W.UI"] = "table",
		["UI.DEFAULT_SCALE"] = "number", ["UI.PHONE"] = "table", ["UI.LIST_PAD"] = "number", ["UI.state"] = "table",
		["UI.Duration"] = "function", ["UI.SummonWait"] = "function", ["UI.Ordinal"] = "function", ["UI.FillSaved"] = "function",
		["UI.Prominence"] = "function", ["UI.Drivers"] = "function", ["UI.Driver"] = "function", ["UI.Ride"] = "function",
		["UI.HabitLine"] = "function", ["UI.FitOrWrap"] = "function", ["UI.MayOpen"] = "function",
	})
	eq(W.UI.DEFAULT_SCALE, 1.15, "the default scale") -- Kit.lua:54
	eq(W.UI.LIST_PAD, 14, "the list's inset")
	eq(W.UI.PHONE.w, 360 + 8 * 2, "the phone's width: the window and two bezels")
	eq(W.UI.PHONE.h, 600 + 26 + 15 + 8 * 2, "the phone's height: window, status bar, home bar, bezels")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.kit: UI.Duration at the minute and hour edges", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local D = r.W.UI.Duration
	eq(D(nil), "under a minute", "nothing") -- Kit.lua:129-139
	eq(D(59), "under a minute", "59 s")
	eq(D(60), "1 min", "60 s")
	eq(D(14 * 60), "14 min", "14 min")
	eq(D(59 * 60 + 30), "1 h", "59.5 min rounds to the hour: never 60 min")
	eq(D(80 * 60), "1 h 20 min", "80 min")
	eq(D(3 * 3600), "3 h", "3 h")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.kit: UI.Ordinal (11th, 12th, 13th, 111th) and UI.SummonWait's window", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local O, UI = r.W.UI.Ordinal, r.W.UI
	local want = { [0] = "0th", [1] = "1st", [2] = "2nd", [3] = "3rd", [4] = "4th", [11] = "11th", [12] = "12th",
		[13] = "13th", [21] = "21st", [22] = "22nd", [23] = "23rd", [111] = "111th", [112] = "112th", [101] = "101st" }
	for n, s in pairs(want) do eq(O(n), s, "ordinal " .. n) end -- Kit.lua:150-158
	local def = r.W.SUMMON_SECS or 30
	eq(UI.SummonWait(nil), def, "no driver: the shared wait")
	eq(UI.SummonWait({ avgSummon = 45.7 }), 45, "their own average, floored") -- Kit.lua:143-147
	eq(UI.SummonWait({ avgSummon = 9 }), def, "under 10 s: not believed")
	eq(UI.SummonWait({ avgSummon = 900 }), 900, "900 s: the edge")
	eq(UI.SummonWait({ avgSummon = 901 }), def, "over 900 s: not believed")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.kit: UI.Driver cleans what was heard and finds a driver by name too", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W = r.W
	W.drivers["xena yarrow"] = { name = "Xena Yarrow", key = "xena yarrow", state = "dancing", team = 7, queue = 99, price = -5,
		avgSummon = 5, rank = 0, x = 500, y = 250 }
	local v = W.UI.Driver("xena yarrow")
	ok(v, "a view")
	eq(v.state, "paused", "an unknown state reads as paused") -- driverView, Kit.lua:200
	eq(v.team, 3, "team clamped to 1..3")
	eq(v.queue, 40, "queue clamped to 0..40")
	eq(v.price, 0, "never a negative fare")
	eq(v.avgSummon, nil, "an average under 10 s is dropped")
	eq(v.rank, nil, "a rank of 0 is dropped")
	eq(v.x, 0.5, "x in thousandths -> 0..1") eq(v.y, 0.25, "y")
	eq(v.dest, "Unknown", "no place heard")
	eq(v.service, "Xena Yarrow", "no service name: the driver's name")
	eq(v.short, "Xena", "short name")
	ok(W.UI.Driver("Xena Yarrow"), "found by name as well as by key") -- Kit.lua:291
	eq(W.UI.Driver(nil), nil, "no key")
	W.drivers["no name"] = { state = "open" }
	eq(W.UI.Driver("no name"), nil, "a record without a name gives no view")
	W.drivers["xena yarrow"], W.drivers["no name"] = nil, nil
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.kit: UI.Ride: no ride is nil; the driver as summoner is dropped; a summon up while summoning is portalUp", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W = r.W
	eq(W.UI.Ride(), nil, "no ride")
	local saved = W.ride
	W.ride = { id = "r1", driver = "Anita Lift", driverKey = "anita lift", state = "summoning", summonUp = true,
		summoner = "Anita Lift", dest = "Ratchet", price = 5000 }
	local v = W.UI.Ride()
	eq(v.rank, 5, "summoning is rank 5") -- RIDE_RANK, Kit.lua:295
	eq(v.portalUp, true, "the summon is up")
	eq(v.summoner, nil, "the driver herself is not named as summoner")
	eq(v.short, "Anita", "short name")
	W.ride.state, W.ride.summoner = "requesting", "Bob Stone"
	v = W.UI.Ride()
	eq(v.portalUp, false, "not while requesting")
	eq(v.summoner, "Bob", "another Warlock casts: named, short")
	W.ride = saved
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.kit: UI.HabitLine: streak, favourite (only this ride's driver when asked), spend; nil when nothing to say", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local UI = r.W.UI
	local stats = { streakDays = 4, favouriteDriver = "Anita Lift", favouriteCount = 5, spent = 32000, rides = 3 }
	eq(UI.HabitLine(nil, stats), "4-day ride streak · 5 rides with Anita · " .. r.W.Money(32000) .. " in all", "all three") -- Kit.lua:455
	eq(UI.HabitLine("anita lift", stats), "4-day ride streak · 5 rides with Anita · " .. r.W.Money(32000) .. " in all", "this ride's driver")
	eq(UI.HabitLine("bob stone", stats), "4-day ride streak · " .. r.W.Money(32000) .. " in all", "another driver's ride: no favourite")
	eq(UI.HabitLine(nil, { streakDays = 1, favouriteCount = 1, favouriteDriver = "Anita Lift", spent = 5000, rides = 1 }), nil,
		"a one-day streak, one ride with her, one ride paid: nothing worth saying")
	eq(UI.HabitLine(nil, {}), nil, "no stats")
	T.clean(w)
end)
