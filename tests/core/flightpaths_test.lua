-- Tests of Core.FlightPaths (SPEC7 3.3, 3.4, 4.3; owner B). Loaded by tests/run.lua with its helper table T.
-- The generated data (tools/build-flights.js; its own checks are in tests/build-flights.test.js).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("core.flightpaths: contract (registered, deps, header, public names); data only", function()
	local W, w, r, Mod = T.contract("Core.FlightPaths", "tests/core/flightpaths_test.lua", {
		["W.TAXI_BOUNDS"] = "table",
		["W.TAXI_PATHS"] = "table",
	})
	ok(Mod, "W.Mod(\"Core.FlightPaths\")")
	T.clean(w)
end)

test("core.flightpaths: one shape per pair of the flight table's legs, even x/y counts, inside the continent's bounds", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W = r.W
	local L, nodes = W.TAXI.legs, W.TAXI.nodes
	local pairs_, n = {}, 0
	for i = 1, #L - 2, 3 do
		local a, b = math.min(L[i], L[i + 1]), math.max(L[i], L[i + 1])
		if not pairs_[a .. ":" .. b] then
			pairs_[a .. ":" .. b] = true
			n = n + 1
		end
	end
	local shapes, points = 0, 0
	for k, p in pairs(W.TAXI_PATHS) do
		shapes = shapes + 1
		ok(pairs_[k], "a pair of the table: " .. k)
		eq(#p % 2, 0, k .. " even")
		ok(#p >= 4, k .. " two points at least")
		local a = tonumber(k:match("^(%d+):"))
		local b = W.TAXI_BOUNDS[nodes[a][2]]
		for i = 1, #p - 1, 2 do
			ok(p[i] >= b[1] and p[i + 1] >= b[2] and p[i] <= b[3] and p[i + 1] <= b[4], k .. " inside its bounds")
			ok(p[i] % 1 == 0 and p[i + 1] % 1 == 0, "whole yards")
		end
		-- starts near node a (the spline leaves from the flight master)
		local dx, dy = p[1] - nodes[a][3], p[2] - nodes[a][4]
		ok(math.sqrt(dx * dx + dy * dy) < 120, k .. " starts at its first node")
		points = points + #p / 2
	end
	eq(shapes, n, "every pair has a shape")
	ok(points <= 3000, "points " .. points)
	ok(W.TAXI_BOUNDS[0] and W.TAXI_BOUNDS[1], "both continents")
	-- and the legs' lengths (Core.Flights' block): one per leg
	eq(#W.TAXI.lens, #L / 3 * 4, "a length per leg")
	T.clean(w)
end)
