local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- the flight-master legs only (W.TAXI.lens: from, to, yards, stop seconds): what a taxi ride really flies
local function flightSecs(W, from, to)
	local L, adj = W.TAXI.lens, {}
	for i = 1, #L - 3, 4 do
		adj[L[i]] = adj[L[i]] or {}
		table.insert(adj[L[i]], { L[i + 1], L[i + 2] / W.FLY.SPEED + L[i + 3] })
	end
	local dist, done = { [from] = 0 }, {}
	while true do
		local u, du
		for id, d in pairs(dist) do if not done[id] and (not du or d < du) then u, du = id, d end end
		if not u then return nil end
		if u == to then return du end
		done[u] = true
		for _, e in ipairs(adj[u] or {}) do
			if not done[e[1]] and (not dist[e[1]] or du + e[2] < dist[e[1]]) then dist[e[1]] = du + e[2] end
		end
	end
end

local function ride(w, r, fromName, toName, secs, land)
	local map = { { name = fromName, type = "CURRENT", cost = 0 }, { name = toName, type = "REACHABLE", cost = 100 } }
	w:openTaxiMap(r, map)
	w:fly(r, 2, secs, land)
	w:advance(secs + 3)
end

test("r34 h: a taxi ride the estimate routes through a zeppelin makes no calibration sample", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Undercity" })
	T.settle(w)
	local W = r.W
	local FT = W.Mod("Core.FlightTimes")
	-- control: Undercity > Tarren Mill is a plain flight; flown at the model's speed the ratio is 1
	local tm = flightSecs(W, 11, 13)
	ok(tm, "a flight-only route 11 > 13")
	ride(w, r, "Undercity, Tirisfal", "Tarren Mill, Hillsbrad", math.floor(tm + W.FLY.TAKEOFF + 0.5), "Tarren Mill")
	local s = W.db.flyCal and W.db.flyCal.samples
	ok(s and #s == 1, "control: the first flight made a sample")
	ok(s and math.abs(s[1] - 1) < 0.05, "control: ratio about 1, got " .. tostring(s and s[1]))
	-- the bug: Undercity > Stonard. The game flies legs only; the estimate takes the 0-copper Undercity > Grom'gol zeppelin.
	local path = W.FlightRoute("Undercity", "Stonard")
	local route = table.concat(path or {}, ",")
	local real = flightSecs(W, 11, 56)
	ok(real, "a flight-only route 11 > 56")
	w:placePlayer(r.player, "Undercity") w:advance(1)
	w:advance(60)
	local sp = W.FindPlace("Stonard")
	ride(w, r, "Undercity, Tirisfal", "Stonard, Swamp of Sorrows", math.floor(real + W.FLY.TAKEOFF + 0.5), { mapID = sp.mapID, x = sp.x, y = sp.y, zone = "Swamp of Sorrows", sub = "Stonard" })
	s = W.db.flyCal and W.db.flyCal.samples or {}
	ok(#s == 1, "the zeppelin-routed flight made no sample (route " .. route .. "), got " .. #s .. " samples")
	ok(not s[2] or math.abs(s[2] - 1) < 0.05, "no skewed sample")
	T.clean(w)
end)
