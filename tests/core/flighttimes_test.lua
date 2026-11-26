-- Tests of Core.FlightTimes (SPEC7 4; owner B). Loaded by tests/run.lua with its helper table T.
-- The player's own flights (fake taxi: TakeTaxiNode, UnitOnTaxi, PLAYER_CONTROL_*), the estimate
-- from the game's splines and its calibration, W.FlightRoute, the flight map's calibration
-- (TaxiNodePosition), and that Enhanced Flight Map is gone.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local UC_TM = { { name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 },
	{ name = "Tarren Mill, Hillsbrad", type = "REACHABLE", cost = 330, x = 0.47, y = 0.44 },
	{ name = "Hammerfall, Arathi", type = "REACHABLE", cost = 530 },
	{ name = "Kalimdor's Nowhere, Somewhere", type = "REACHABLE", cost = 100 } }

local function fired(r, name)
	local out = {}
	r.W.Listen(name, function(...) out[#out + 1] = { ... } end)
	return out
end

-- one flight from the Undercity map: slot, seconds in the air, where the player lands
local function flight(w, r, slot, secs, land, opts)
	w:openTaxiMap(r, UC_TM)
	w:fly(r, slot, secs, land, opts)
	w:advance((opts and opts.takeoff or 1) + secs + 1)
end

local function stored(r, a, b)
	local e = r.W.db.flights and r.W.db.flights["H|" .. a .. "|" .. b]
	return e and e.t, e and e.tsrc
end

test("core.flighttimes: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("Core.FlightTimes", "tests/core/flighttimes_test.lua", {
		["W.FlightRoute"] = "function",
		["W.FlightTime"] = "function",
		["Mod.Estimate"] = "function",
		["Mod.MapOpened"] = "function",
		["Mod.MapClosed"] = "function",
		["Mod.Calibration"] = "function",
		["Mod.MapCal"] = "function",
		["Mod.FitAffine"] = "function",
	})
	ok(Mod, "W.Mod(\"Core.FlightTimes\")")
	T.clean(w)
end)

test("core.flighttimes: a 95 s flight Undercity > Tarren Mill is stored as 95 own, fires FLIGHT_TIME and FLIGHTS", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Undercity" })
	T.settle(w)
	local W = r.W
	local ft, fl = fired(r, "FLIGHT_TIME"), fired(r, "FLIGHTS")
	local ver = W.FLY.ver
	local before = select(2, W.FlightTime("Undercity", "Tarren Mill"))
	eq(before, "est", "an estimate before any flight")
	flight(w, r, 2, 95, "Tarren Mill")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	local t, src = stored(r, "undercity", "tarren mill")
	eq(t, 95, "95 s stored")
	eq(src, "own")
	eq(#ft, 1, "FLIGHT_TIME once")
	eq(ft[1][1], "undercity") eq(ft[1][2], "tarren mill") eq(ft[1][3], 95)
	ok(#fl >= 1, "FLIGHTS")
	ok(W.FLY.ver > ver, "the share list's version moved")
	eq(W.FlightTime("Undercity", "Tarren Mill"), 95)
	eq(select(2, W.FlightTime("Undercity", "Tarren Mill")), "own")
	-- the pool shares own times, never estimates
	local list = W.FlightShareList()
	local seen = {}
	for _, e in ipairs(list) do if e.t then seen[e.from .. ">" .. e.to] = e.t end end
	eq(seen["undercity>tarren mill"], 95, "own shared")
	eq(seen["tarren mill>undercity"], nil, "the estimate never")
	T.clean(w)
end)

test("core.flighttimes: rejected: 3 s, 4,000 s, a loading screen, a logout, the wrong landing place, an unknown end", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Undercity" })
	T.settle(w)
	local W = r.W
	local ft = fired(r, "FLIGHT_TIME")
	flight(w, r, 2, 3, "Tarren Mill")
	eq(stored(r, "undercity", "tarren mill"), nil, "3 s")
	flight(w, r, 2, 4000, "Tarren Mill")
	eq(stored(r, "undercity", "tarren mill"), nil, "4,000 s")
	flight(w, r, 2, 120, "Tarren Mill", { loadingScreen = 30 })
	eq(stored(r, "undercity", "tarren mill"), nil, "a loading screen mid-flight")
	flight(w, r, 2, 120, "Tarren Mill", { logout = 30 })
	eq(stored(r, "undercity", "tarren mill"), nil, "a logout mid-flight")
	flight(w, r, 2, 120, "Orgrimmar")
	eq(stored(r, "undercity", "tarren mill"), nil, "landed somewhere else")
	flight(w, r, 4, 120, "Tarren Mill")
	eq(#ft, 0, "nothing stored, nothing fired")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	-- never took off (the click, then nothing within 5 s): nothing, and the ticker stops
	w:openTaxiMap(r, UC_TM)
	r.env.TakeTaxiNode = r.env.TakeTaxiNode -- (the hooked one)
	r.W.Mod("Core.FlightTimes").clicked(2)
	w:advance(10)
	r:fire("PLAYER_CONTROL_GAINED")
	eq(#ft, 0, "no take-off: nothing")
	-- a second click before landing: neither counts
	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 100, "Tarren Mill")
	w:advance(30)
	r.W.Mod("Core.FlightTimes").clicked(2)
	w:advance(80)
	eq(#ft, 0, "another TakeTaxiNode in the air: nothing")
	T.clean(w)
end)

test("core.flighttimes: the 10 % rule: a close time keeps the smaller, a different one replaces", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Undercity" })
	T.settle(w)
	flight(w, r, 2, 100, "Tarren Mill")
	eq(stored(r, "undercity", "tarren mill"), 100)
	flight(w, r, 2, 108, "Tarren Mill")
	eq(stored(r, "undercity", "tarren mill"), 100, "within 10 %: the smaller stays")
	flight(w, r, 2, 95, "Tarren Mill")
	eq(stored(r, "undercity", "tarren mill"), 95, "within 10 % and smaller")
	flight(w, r, 2, 140, "Tarren Mill")
	eq(stored(r, "undercity", "tarren mill"), 140, "more than 10 % off: the new one")
	-- a shared time is replaced by an own one, even within 10 %
	r.W.db.flights["H|undercity|tarren mill"] = { t = 100, tat = r.env.time(), tsrc = "shared", tn = 2 }
	flight(w, r, 2, 105, "Tarren Mill")
	local t, src = stored(r, "undercity", "tarren mill")
	eq(t, 105) eq(src, "own")
	T.clean(w)
end)

test("core.flighttimes: the estimate sums the route's legs; 3 own flights calibrate it (median); TravelSaved uses it then", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Undercity" })
	T.settle(w)
	local W, Mod = r.W, r.W.Mod("Core.FlightTimes")
	-- Undercity (11) > Tarren Mill (13): one leg
	local L = W.TAXI.lens
	local yards, delay
	for i = 1, #L - 3, 4 do if L[i] == 11 and L[i + 1] == 13 then yards, delay = L[i + 2], L[i + 3] end end
	ok(yards and yards > 1000, "a length for 11 > 13")
	local raw = yards / W.FLY.SPEED + delay
	eq(W.FlightTime("Undercity", "Tarren Mill"), math.floor(raw + W.FLY.TAKEOFF + 0.5), "est = yards / 32 + stops + 3 s")
	local route = W.FlightRoute("Undercity", "Tarren Mill")
	eq(route and table.concat(route, ","), "11,13", "the route's node ids")
	eq(W.FlightRoute("Undercity", "Undercity"), nil, "no route to itself")
	ok(W.FlightRoute("Orgrimmar", "Tarren Mill"), "across the sea (the zeppelin)")
	local cross = W.FlightTime("Orgrimmar", "Tarren Mill")
	ok(cross and cross > W.FLY.CROSS, "a crossing adds its time: " .. tostring(cross))
	local before = W.FlightTime("Tarren Mill", "Undercity")
	local tsBefore, howBefore = W.TravelSaved("Hammerfall")
	ok(howBefore ~= "est", "uncalibrated: TravelSaved keeps the straight-line model")
	-- three flights at 1.5 x the estimate's flying time
	local secs = math.floor(raw * 1.5 + W.FLY.TAKEOFF + 0.5)
	for _ = 1, 2 do flight(w, r, 2, secs, "Tarren Mill") end
	eq(Mod.Calibration(), 1, "2 ratios: not yet")
	flight(w, r, 2, secs, "Tarren Mill")
	local ratio, n = Mod.Calibration()
	eq(n, 3)
	ok(math.abs(ratio - 1.5) < 0.02, "the median ratio: " .. ratio)
	eq(#W.db.flyCal.samples, 3)
	local after = W.FlightTime("Tarren Mill", "Undercity")
	eq(select(2, W.FlightTime("Tarren Mill", "Undercity")), "est")
	ok(after > before * 1.4 and after < before * 1.6, ("calibrated: %d -> %d"):format(before, after))
	local ts, how = W.TravelSaved("Hammerfall")
	eq(how, "est", "calibrated: TravelSaved uses the estimate")
	ok(ts and ts ~= tsBefore, "a different number")
	-- a broken measurement (10 x) is not a ratio; the last 9 are kept
	flight(w, r, 2, math.floor(raw * 10), "Tarren Mill")
	eq(#W.db.flyCal.samples, 3, "10 x: no ratio")
	for _ = 1, 8 do flight(w, r, 2, secs, "Tarren Mill") end
	eq(#W.db.flyCal.samples, 9, "the last 9")
	T.clean(w)
end)

test("core.flighttimes: 2.2's Enhanced Flight Map times become own once (flightsV 3); the addon never reads EnhancedFlightMapDB", function()
	local w = T.newWorld()
	local at = H.EPOCH + 900
	local r = T.rider(w, nil, { spot = "Undercity", prepare = function(env)
		env.EnhancedFlightMapDB = { flightTimes = { n11 = 1 } }
	end, saved = { Wuber = { flights = {
		["H|undercity|tarren mill"] = { t = 140, tat = at, tsrc = "efm" },
		["H|orgrimmar|crossroads"] = { t = 90, tat = at, tsrc = "shared", tn = 2 },
	} } } })
	T.settle(w)
	local W = r.W
	eq(W.db.flightsV, 3)
	eq(select(2, stored(r, "undercity", "tarren mill")), "own")
	eq(stored(r, "undercity", "tarren mill"), 140, "the seconds kept")
	eq(select(2, stored(r, "orgrimmar", "crossroads")), "shared", "shared stays shared")
	eq(W.ReadEFM, nil, "no reader")
	-- every file of the addon: no EnhancedFlightMapDB; the TOC names no EnhancedFlightMap
	local toc = T.readFile(T.dir .. "/../Wuber/Wuber.toc")
	ok(toc and not toc:find("EnhancedFlightMap", 1, true), "TOC")
	local files = 0
	for line in toc:gmatch("[^\r\n]+") do
		if line:match("%.lua%s*$") and not line:match("^#") then
			local src = T.readFile(T.dir .. "/../Wuber/" .. line:gsub("\\", "/"):gsub("%s+$", ""))
			if src then
				files = files + 1
				ok(not src:find("EnhancedFlightMapDB", 1, true), line .. " reads EnhancedFlightMapDB")
			end
		end
	end
	ok(files > 80, "read the addon's files: " .. files)
	T.clean(w)
end)

test("core.flighttimes: a player who never flies gets no new listeners; the map calibration learns from TaxiNodePosition", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Undercity" })
	T.settle(w)
	local W, Mod = r.W, r.W.Mod("Core.FlightTimes")
	local function handlers(ev)
		local i = 1
		while true do
			local name, v = debug.getupvalue(W.On, i)
			if not name then return 0 end
			if name == "handlers" then return v[ev] and #v[ev] or 0 end
			i = i + 1
		end
	end
	eq(handlers("PLAYER_CONTROL_GAINED"), 0, "nothing at login")
	-- an old-style map (no x, y): nothing learned, nothing saved
	w:openTaxi(r, { { name = "Undercity, Tirisfal", type = "CURRENT" }, { name = "Tarren Mill, Hillsbrad", type = "REACHABLE" } })
	eq(W.db.mapCal, nil, "no positions: no mapCal")
	eq(handlers("PLAYER_CONTROL_GAINED"), 0, "an open map registers nothing")
	-- four nodes of the Eastern Kingdoms with positions from a known affine
	local A = { -1.0e-5, -6e-5, 0.5, -4e-5, 1e-5, 0.4 }
	local function uv(id)
		local n = W.TAXI.nodes[id]
		return A[1] * n[3] + A[2] * n[4] + A[3], A[4] * n[3] + A[5] * n[4] + A[6]
	end
	local nodes = {}
	for i, id in ipairs({ 11, 13, 17, 21 }) do
		local u, v = uv(id)
		nodes[i] = { name = W.TAXI.nodes[id][1] .. ", Somewhere", type = i == 1 and "CURRENT" or "REACHABLE", x = u, y = v }
	end
	w:openTaxiMap(r, nodes)
	local cal = Mod.MapCal(0)
	ok(cal, "a calibration for continent 0")
	eq(cal.n, 4)
	for i, key in ipairs({ "a", "b", "c", "d", "e", "f" }) do
		ok(math.abs(cal[key] - A[i]) <= math.abs(A[i]) * 0.005, key .. ": " .. cal[key] .. " vs " .. A[i])
	end
	eq(Mod.MapCal(1), nil, "nothing for Kalimdor")
	eq(Mod.FitAffine({ { 0, 0, 0, 0 }, { 1, 1, 1, 1 }, { 2, 2, 2, 2 } }), nil, "points in a line: no fit")
	eq(handlers("PLAYER_CONTROL_GAINED"), 0, "still nothing until a flight is taken")
	T.clean(w)
end)

test("core.flighttimes: round 9 C11 - a bottom-up TaxiNodePosition v is read from the data and flipped; top-down stays", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Undercity" })
	T.settle(w)
	local W, Mod = r.W, r.W.Mod("Core.FlightTimes")
	-- the same true (top-down) affine as above, but the map reports v from the bottom (1 - v)
	local A = { -1.0e-5, -6e-5, 0.5, -4e-5, 1e-5, 0.4 }
	local nodes = {}
	for i, id in ipairs({ 11, 13, 17, 21 }) do
		local n = W.TAXI.nodes[id]
		local u, v = A[1] * n[3] + A[2] * n[4] + A[3], A[4] * n[3] + A[5] * n[4] + A[6]
		nodes[i] = { name = n[1] .. ", Somewhere", type = i == 1 and "CURRENT" or "REACHABLE", x = u, y = 1 - v }
	end
	w:openTaxiMap(r, nodes)
	local cal = Mod.MapCal(0)
	ok(cal and cal.flipped == true, "the bottom-up fit is noticed")
	for i, key in ipairs({ "a", "b", "c", "d", "e", "f" }) do
		ok(math.abs(cal[key] - A[i]) <= math.abs(A[i]) * 0.005, key .. ": " .. cal[key] .. " vs " .. A[i])
	end
	local saved = W.db.mapCal[0]
	ok(saved.d > 0, "the saved fit keeps what the game said (no rewrite, no new version)")
	-- a top-down map is left alone
	saved.d, saved.e, saved.f = A[4], A[5], A[6]
	local c2 = Mod.MapCal(0)
	ok(c2 == saved and not c2.flipped, "top-down: the saved fit as it is")
	T.clean(w)
end)

test("core.flighttimes: round 9 C11 review - points spread only east-west can't tell north: the calibration stays unknown", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Undercity" })
	T.settle(w)
	local W, Mod = r.W, r.W.Mod("Core.FlightTimes")
	-- a bottom-up map (as the classic flight map draws it)
	local A = { -1.0e-5, -6e-5, 0.5, -4e-5, 1e-5, 0.4 }
	-- Eastern Kingdoms nodes in one east-west band (world x within 600 yards), spread out east to west
	local band, x0 = {}, nil
	local ids = {}
	for id, n in pairs(W.TAXI.nodes) do if n[2] == 0 then ids[#ids + 1] = id end end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local n = W.TAXI.nodes[id]
		x0 = x0 or n[3]
		local far = true
		for _, b in ipairs(band) do if math.abs(W.TAXI.nodes[b][4] - n[4]) < 800 then far = false end end
		if math.abs(n[3] - x0) <= 600 and far then band[#band + 1] = id end
	end
	ok(#band >= 3, "found an east-west band: " .. #band)
	local fake, lo, hi = {}, nil, nil
	for _, id in ipairs(band) do
		local n = W.TAXI.nodes[id]
		lo, hi = math.min(lo or n[3], n[3]), math.max(hi or n[3], n[3])
		local u, v = A[1] * n[3] + A[2] * n[4] + A[3], A[4] * n[3] + A[5] * n[4] + A[6]
		fake[id] = { u, 1 - v }
	end
	ok(hi - lo < Mod.FT.MAPCAL_NS, "too little north-south spread: " .. (hi - lo))
	-- a fit with |d| >= |e| (it would pass the old check) but no north-south spread behind it
	W.db.mapCal = { [0] = { a = A[1], b = A[2], c = A[3], d = 4e-5, e = 1e-5, f = 0.6, n = #band, at = 1, pts = fake } }
	eq(Mod.MapCal(0), nil, "east-west only: unknown, never a guessed direction")
	-- |d| below |e|: the direction can't be told either, whatever the spread
	W.db.mapCal = { [0] = { a = A[1], b = A[2], c = A[3], d = 1e-6, e = 5e-5, f = 0.6, n = 3, at = 1,
		pts = { [11] = { 0.1, 0.1 }, [13] = { 0.2, 0.2 }, [17] = { 0.3, 0.3 }, [21] = { 0.4, 0.4 } } } }
	eq(Mod.MapCal(0), nil, "x not the main term of v: unknown")
	T.clean(w)
end)
