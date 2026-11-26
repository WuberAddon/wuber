-- Final home: tests/fx/moments_test.lua; add it to the per-module list in tests/run.lua.
-- Pins:
--   the ride's portal and arrival moments play once per ride, the arrival waits out a loading screen
--   a ride restored after /reload never replays its moments (Mod.markRestored)
--   a payment bursts once: DRIVE_PAID and the SendStage "paid" never both burst for one rider within 5 s
--   only a traded payment taken by this window bursts; a tip is the bigger shower; 5 stars rain coins
--   no gold portal on the own cast for anyone who is not a founder
-- Why it matters to a player: a moment that replays after every /reload, or two coin bursts for one
--   payment, makes the celebration feel broken; a burst for a payment marked by hand or taken by another
--   window would celebrate money this player never received.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local TESTCHAR = T.TESTCHAR

-- every FX.Fullscreen moment asked for, by name (the real one still plays)
local function spy(W)
	local FX, calls = W.FX, {}
	local orig = FX.Fullscreen
	FX.Fullscreen = function(name, opts)
		calls[#calls + 1] = name
		return orig(name, opts)
	end
	return calls, function() FX.Fullscreen = orig end
end

local function has(calls, name)
	local n = 0
	for _, c in ipairs(calls) do if c == name then n = n + 1 end end
	return n
end

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.moments: contract (registered, deps, header, public names)", function()
	local W, w = T.contract("FX.Moments", "tests/fx/moments_test.lua", {
		["W.FX.OnRide"] = "function", ["W.FX.OnPaid"] = "function", ["W.FX.OnDrivePaid"] = "function",
		["W.FX.OnRating"] = "function", ["W.FX.OnDriveRitual"] = "function", ["Mod.markRestored"] = "function",
	})
	eq(W.FX.sendStageHooked, true, "W.SendStage is wrapped (once)") -- Moments.lua:181-195
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.moments: the portal and the arrival play once per ride; a 5-star rating rains coins", function()
	local W, w = T.contract("FX.Moments", "tests/fx/moments_test.lua", {})
	local FX = W.FX
	local calls, restore = spy(W)
	FX.OnRide({ id = "r9", state = "portal" })
	eq(has(calls, "portal_open"), 1, "the portal opens")
	FX.OnRide({ id = "r9", state = "portal" })
	eq(has(calls, "portal_open"), 1, "once per ride") -- Moments.lua:63-66
	FX.OnRide({ id = "r9", state = "arrived" })
	eq(has(calls, "arrival"), 0, "a moment later, not at once") -- Moments.lua:47-50
	w:advance(0.2)
	eq(has(calls, "arrival"), 1, "the arrival")
	FX.OnRide({ id = "r9", state = "paying" })
	FX.OnRide({ id = "r9", state = "done" })
	w:advance(0.5)
	eq(has(calls, "arrival"), 1, "paying and done do not play it again")
	FX.OnRide(nil) FX.OnRide({ id = "r10" }) FX.OnRide("junk")
	FX.OnRating("r9", TESTCHAR, 4)
	eq(has(calls, "coins"), 0, "4 stars: no shower")
	FX.OnRating("r9", TESTCHAR, 5)
	eq(has(calls, "coins"), 1, "5 stars: coins") -- Moments.lua:158-160
	restore()
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.moments: an arrival during a loading screen waits until the world is back", function()
	local W, w, r = T.contract("FX.Moments", "tests/fx/moments_test.lua", {})
	local calls, restore = spy(W)
	r:fire("PLAYER_LEAVING_WORLD")
	W.FX.OnRide({ id = "r11", state = "arrived" })
	w:advance(1)
	eq(has(calls, "arrival"), 0, "not behind the loading screen") -- Moments.lua:45, 48
	r:fire("PLAYER_ENTERING_WORLD")
	w:advance(0.5)
	eq(has(calls, "arrival"), 1, "played once the world is back") -- Moments.lua:171-177
	restore()
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.moments: a ride restored after /reload does not replay its portal or arrival", function()
	local W, w = T.contract("FX.Moments", "tests/fx/moments_test.lua", {})
	local calls, restore = spy(W)
	W.db.ride = { id = "r12", state = "arrived" }
	W.Mod("FX.Moments").markRestored()
	W.FX.OnRide({ id = "r12", state = "arrived" })
	W.FX.OnRide({ id = "r12", state = "portal" })
	w:advance(0.5)
	eq(has(calls, "arrival"), 0, "no arrival replay") -- Moments.lua:202-208
	eq(has(calls, "portal_open"), 0, "no portal replay")
	-- a ride only asked for still plays its portal later
	W.db.ride = { id = "r13", state = "asked" }
	W.Mod("FX.Moments").markRestored()
	W.FX.OnRide({ id = "r13", state = "portal" })
	eq(has(calls, "portal_open"), 1, "the portal still opens for it")
	W.FX.OnRide(nil)
	W.db.ride = nil
	restore()
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.moments: a traded payment bursts once; a tip is the bigger shower; hand-marked or another window's: nothing", function()
	local W, w = T.contract("FX.Moments", "tests/fx/moments_test.lua", {})
	local FX = W.FX
	eq(FX.OnDrivePaid("Dan Miller", 5000, 0, nil, false, "t"), nil, "another window took it") -- Moments.lua:142
	eq(FX.OnDrivePaid("Dan Miller", 5000, 0, nil, true, "m"), nil, "marked paid by hand")
	eq(FX.OnDrivePaid("Dan Miller", 0, 0, nil, true, "t"), nil, "nothing paid")
	eq(FX.OnDrivePaid("Dan Miller", "junk", 0, nil, true, "t"), nil)
	eq(FX.OnDrivePaid("Dan Miller", 5000, 0, nil, true, "t"), "paid")
	eq(FX.OnDrivePaid("Dan Miller", 5000, 0, nil, true, "t"), nil, "the same rider within 5 s: one burst")
	eq(FX.OnDrivePaid("Eve Stone", 5000, 0, nil, true, "t"), "paid", "another rider's payment still bursts")
	w:advance(6)
	eq(FX.OnDrivePaid("Dan Miller", 5000, 500, nil, true, "t"), "coins", "with a tip: the shower") -- Moments.lua:149
	eq(FX.lastDrivePaid, "coins")
	-- a bare first name and the full name are one rider
	w:advance(6)
	eq(FX.OnDrivePaid("Ed-Realm", 5000, 0, nil, true, "t"), "paid")
	eq(FX.OnDrivePaid("Ed", 5000, 0, nil, true, "t"), nil, "Ed and Ed-Realm: one payment") -- Moments.lua:115-121
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.moments: the stage burst: once per ride, never right after DRIVE_PAID burst for the same rider", function()
	local W, w = T.contract("FX.Moments", "tests/fx/moments_test.lua", {})
	local FX = W.FX
	local calls, restore = spy(W)
	eq(FX.OnDrivePaid("Dan Miller", 5000, 0, nil, true, "t"), "paid")
	local t0 = FX.paidAt
	eq(has(calls, "paid"), 1)
	w:advance(1)
	FX.OnPaid("ride1", "Dan")
	eq(has(calls, "paid"), 1, "the stage for the same payment: no second burst") -- Moments.lua:129
	eq(FX.paidAt, t0)
	w:advance(6)
	FX.OnPaid("ride1", "Dan")
	eq(has(calls, "paid"), 1, "that ride's stage never bursts later either") -- Moments.lua:125-126
	FX.OnPaid("ride2", "Dan")
	eq(has(calls, "paid"), 2, "a new ride does")
	restore()
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("fx.moments: the gold portal on my own cast is for founders only", function()
	local W, w = T.contract("FX.Moments", "tests/fx/moments_test.lua", {})
	local FX = W.FX
	local calls, restore = spy(W)
	eq(FX.OnDriveRitual("Dan Miller", "s", { ride = "r1" }), nil, "only the cast phase")
	eq(FX.OnDriveRitual("Dan Miller", "c", { ride = "r1" }), nil, "not a founder: nothing") -- Moments.lua:94-95
	eq(has(calls, "portal_open"), 0)
	restore()
	T.clean(w)
end)
