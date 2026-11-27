-- Round 33 group b, LRN-01: the landing event (PLAYER_CONTROL_GAINED) can come while UnitOnTaxi is
-- still true, and it does not come again. Wuber must still learn the flight time, and the next flight
-- must not be thrown away. The fake game plays that order only when asked (w:fly opts.flagLag).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local UC_MAP = { { name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 },
	{ name = "Tarren Mill, Hillsbrad", type = "REACHABLE", cost = 330, x = 0.47, y = 0.44 } }
local TM_MAP = { { name = "Tarren Mill, Hillsbrad", type = "CURRENT", cost = 0, x = 0.47, y = 0.44 },
	{ name = "Undercity, Tirisfal", type = "REACHABLE", cost = 330, x = 0.42, y = 0.31 } }

local function stored(r, a, b)
	local e = r.W.db.flights and r.W.db.flights["H|" .. a .. "|" .. b]
	return e and e.t, e and e.tsrc
end

test("r33 b LRN-01: the landing event comes while the taxi flag is still set: the 95 s flight is still learned as the player's own", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Undercity" })
	T.settle(w)
	w:openTaxiMap(r, UC_MAP)
	w:fly(r, 2, 95, "Tarren Mill", { flagLag = 0.5 })
	w:advance(1 + 95 + 0.2)
	eq(r.env.UnitOnTaxi("player"), true, "harness check: the flag is still set just after the landing event")
	w:advance(10)
	eq(r.env.UnitOnTaxi("player"), false, "harness check: landed")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	local t, src = stored(r, "undercity", "tarren mill")
	ok(t ~= nil and math.abs(t - 95) <= 1, "about 95 s stored, got " .. tostring(t))
	eq(src, "own", "as the player's own time")
	T.clean(w)
end)

test("r33 b LRN-01: after such a landing the next, normal flight is stored too", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Undercity" })
	T.settle(w)
	w:openTaxiMap(r, UC_MAP)
	w:fly(r, 2, 95, "Tarren Mill", { flagLag = 0.5 })
	w:advance(1 + 95 + 10)
	w:openTaxiMap(r, TM_MAP)
	w:fly(r, 2, 90, "Undercity")
	w:advance(1 + 90 + 1)
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	local t, src = stored(r, "tarren mill", "undercity")
	eq(t, 90, "the flight back: 90 s stored")
	eq(src, "own", "as the player's own time")
	T.clean(w)
end)

test("r33 b LRN-01: the flag never drops: Wuber gives up after the longest flight plus a margin and stores nothing", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Undercity" })
	T.settle(w)
	local FT = r.W.Mod("Core.FlightTimes").FT
	ok(type(FT.LAND_MARGIN) == "number" and FT.LAND_MARGIN > 0, "a landing margin is set")
	w:openTaxiMap(r, UC_MAP)
	w:fly(r, 2, 95, "Tarren Mill", { flagLag = 100000 })
	w:advance(1 + r.W.FLY.MAX_SECS + FT.LAND_MARGIN + 5)
	eq(r.env.UnitOnTaxi("player"), true, "harness check: the flag is still set")
	eq(stored(r, "undercity", "tarren mill"), nil, "nothing stored while the game says the player is in the air")
	-- the stale flight is gone: the next one counts
	r.player.onTaxi = false
	w:openTaxiMap(r, UC_MAP)
	w:fly(r, 2, 95, "Tarren Mill")
	w:advance(1 + 95 + 1)
	eq(stored(r, "undercity", "tarren mill"), 95, "the next flight is stored")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)
