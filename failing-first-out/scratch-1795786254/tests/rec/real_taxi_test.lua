-- Conformance (the flight recorder, lane B2): the flight master's map in the fake game against the real
-- client (facts taxi.numnodes, taxi.reachable, taxi.positions, taxi.frame, taxi.nodeids; the recorded data
-- and where each piece comes from: tests/fixtures/rec/lab-taxi.lua).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local FACTS = dofile(T.dir .. "/fixtures/rec/lab-real-facts.lua")
local function fact(id)
	for _, f in ipairs(FACTS) do if f.id == id then return f end end
end
local DATA = dofile(T.dir .. "/fixtures/rec/lab-taxi.lua")

local function reachable(env)
	local n, reach = env.NumTaxiNodes(), 0
	for i = 1, n do if env.TaxiNodeGetType(i) == "REACHABLE" then reach = reach + 1 end end
	return reach, n
end

-- the probe line "flight map: N of M nodes reachable", asked of the fake as the test addon asked it
test("rec: real: NumTaxiNodes counts every node of the continent; REACHABLE only the known ones (taxi.numnodes, taxi.reachable)", function()
	for _, s in ipairs(DATA.seen) do
		local w = T.newWorld()
		local spot = s.here == "Undercity" and "Undercity" or s.here
		local r = T.rider(w, "Wuber Rocks", { spot = spot })
		w:advance(1)
		local cont = s.here == "Undercity" and "Eastern Kingdoms" or "Kalimdor"
		w:openTaxiMap(r, H.realTaxi(cont, s.here, { known = s.known }))
		local reach, n = reachable(r.env)
		eq(reach, s.reach, s.who .. " " .. s.at .. ": reachable")
		if cont == "Kalimdor" then
			eq(n, s.nodes, s.who .. " " .. s.at .. ": nodes")
		else
			-- (the 14th Eastern Kingdoms node is not in the recording: the fake has 13)
			eq(n, s.nodes - 1, "Eastern Kingdoms: the 13 recorded nodes")
		end
		T.clean(w)
	end
end)

-- costs read with TaxiNodeCost on the real client: Thunder Bluff -> Orgrimmar 50; Orgrimmar -> Ratchet
-- and -> Camp Taurajo 0 (a real answer, not a missing one), -> Crossroads 99
test("rec: real: TaxiNodeCost as recorded, 0 included (taxi.reachable)", function()
	local w = T.newWorld()
	local r = T.rider(w, "Wuber Rocks")
	w:advance(1)
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Orgrimmar", { known = { "Crossroads", "Ratchet", "Camp Taurajo" } }))
	local got = {}
	for i = 1, r.env.NumTaxiNodes() do
		if r.env.TaxiNodeGetType(i) == "REACHABLE" then got[#got + 1] = r.env.TaxiNodeName(i) .. "=" .. r.env.TaxiNodeCost(i) end
	end
	eq(table.concat(got, " "), "Crossroads, The Barrens=99 Camp Taurajo, The Barrens=0 Ratchet, The Barrens=0")
	T.clean(w)
end)

test("rec: real: TaxiNodePosition gives the recorded positions (taxi.positions)", function()
	local pos = fact("taxi.positions").value
	local w = T.newWorld()
	local r = T.rider(w, "Wuber Rocks", { spot = "Thunder Bluff" })
	w:advance(1)
	local nodes = H.realTaxi("Kalimdor", "Thunder Bluff")
	w:openTaxiMap(r, nodes)
	local n = 0
	for i, node in ipairs(nodes) do
		local x, y = r.env.TaxiNodePosition(i)
		local want = pos[node.nodeID]
		if want then
			n = n + 1
			eq(x .. "," .. y, want[1] .. "," .. want[2], node.name)
		else
			eq(x .. "," .. y, "0,0", node.name .. ": no recorded position")
		end
	end
	eq(n, 21, "21 recorded positions")
	T.clean(w)
end)

-- taxi.frame: "bird: the flight map is TaxiFrame" (Anita Lift, 20 Nov); size and place from SHOT-FACTS.md
test("rec: real: the flight map is TaxiFrame, about 603 x 638 at 16, -118 (taxi.frame)", function()
	local w = T.newWorld()
	local r = T.rider(w, "Wuber Rocks", { spot = "Thunder Bluff" })
	w:advance(1)
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff"))
	local f = r.env.TaxiFrame
	ok(f and f:IsShown(), "TaxiFrame shows")
	eq(rawget(r.env, "FlightMapFrame"), nil, "no FlightMapFrame")
	eq(f:GetWidth() .. "x" .. f:GetHeight(), DATA.frame.w .. "x" .. DATA.frame.h, "the measured size")
	local p, rel, rp, x, y = f:GetPoint(1)
	eq(p .. " " .. rp .. " " .. x .. "," .. y, "TOPLEFT TOPLEFT " .. DATA.frame.x .. "," .. DATA.frame.y, "the measured place")
	T.clean(w)
	local w2 = T.newWorld()
	local r2 = T.rider(w2, "Wuber Rocks")
	w2:advance(1)
	w2:openTaxiMap(r2, H.realTaxi("Kalimdor", "Orgrimmar"), { frameSize = "old" })
	eq(r2.env.TaxiFrame:GetWidth() .. "x" .. r2.env.TaxiFrame:GetHeight(), "384x512", "the old size on request")
	T.clean(w2)
end)

-- The author's case of 21 Nov (00:08:28 to 00:10:51, eleven opens): Wuber Rocks at Thunder Bluff after a
-- ride to Orgrimmar, Orgrimmar the only place known ("1 of 22 nodes reachable"), Anita Lift open in
-- Orgrimmar: no Skip the bird card showed then (the 2.3.3-dev build). With today's code and the real map:
local function authorsCase(screenW, screenH)
	local w = T.newWorld()
	local r = T.rider(w, "Wuber Rocks", { spot = "Thunder Bluff", screenW = screenW, screenH = screenH })
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	W.drivers["anita lift"] = { name = "Anita Lift", key = "anita lift", dest = "Orgrimmar", price = 5000, state = "open", team = 3,
		service = "Wuber", heard = r.env.GetTime() }
	W.ride = { id = "gJBrSi", state = "done", driver = "anita lift", driverKey = "anita lift", dest = "Orgrimmar", price = 5000 }
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } }))
	w:advance(0.5)
	return w, r, W
end

test("rec: real: the author's case of 21 Nov: Thunder Bluff, 1 of 22 reachable, the bird card shows (taxi.*)", function()
	local w, r, W = authorsCase(1365, 768)
	eq(select(1, reachable(r.env)), 1, "1 of 22 reachable")
	local Bd = W.Mod("UI.Bird")
	local d = Bd.Pick()
	ok(d and d.key == "anita lift", "the driver is picked")
	local c = Bd.Card()
	ok(c and H.visible(c), "the card shows")
	T.clean(w)
end)

test("rec: real: Core/Flights.lua learns the right things from the 22 real nodes (taxi.nodeids, taxi.positions)", function()
	local w, r, W = authorsCase(1365, 768)
	local e = W.db.flights["H|thunder bluff|orgrimmar"]
	eq(e and e.c, 50, "the cost, as the real WuberDB.flights has it")
	local n = 0
	for k in pairs(W.db.flights) do if k:find("^H|thunder bluff|") then n = n + 1 end end
	eq(n, 1, "only the one known route")
	local want = fact("taxi.nodeids").value
	local nodes = W.db.flightNodes and W.db.flightNodes.H or {}
	for id, name in pairs(nodes) do eq(name, want[id], "node " .. id .. " as the real flightNodes.H") end
	ok(nodes[22] == "thunder bluff" and nodes[23] == "orgrimmar" and nodes[80] == "ratchet", "the main nodes learned")
	local cal = W.db.mapCal and W.db.mapCal[1]
	ok(cal, "a Kalimdor calibration")
	local pts = 0
	for _ in pairs(cal and cal.pts or {}) do pts = pts + 1 end
	eq(pts, 21, "21 positions, as the real mapCal[1].pts")
	-- the real fit (WuberDB.mapCal[1], 21 Nov 00:12): c = 0.45069867942054, f = 0.5123252224478,
	-- b = d = -4.108e-05
	ok(math.abs(cal.c - 0.45069867942054) < 1e-6 and math.abs(cal.f - 0.5123252224478) < 1e-6, "the same fit: " .. cal.c .. ", " .. cal.f)
	ok(math.abs(cal.b + 4.1084571100005e-05) < 1e-9 and math.abs(cal.d + 4.1084591833974e-05) < 1e-9, "the same scale")
	T.clean(w)
end)

-- the bird card's place beside the real-size TaxiFrame: on the screen, not over the map, at the r26 test
-- screen (1365 x 768) and at the UI size SHOT-FACTS.md infers for the author's screen (about 1350 x 1060)
test("rec: real: the bird card stands beside the real-size TaxiFrame, on the screen (taxi.frame)", function()
	for _, s in ipairs({ { 1365, 768 }, { 1350, 1060 }, { 1920, 1080 } }) do
		local w, r, W = authorsCase(s[1], s[2])
		local c = W.Mod("UI.Bird").Card()
		ok(c and H.visible(c), s[1] .. "x" .. s[2] .. ": the card shows")
		local cr, mr, ur = H.rect(c), H.rect(r.env.TaxiFrame), H.rect(r.env.UIParent)
		local what = s[1] .. "x" .. s[2]
		ok(cr.l >= ur.l - 0.5 and cr.l + cr.w <= ur.l + ur.w + 0.5 and cr.b >= ur.b - 0.5 and cr.b + cr.h <= ur.b + ur.h + 0.5,
			what .. ": on the screen")
		ok(cr.l + cr.w <= mr.l + 0.5 or mr.l + mr.w <= cr.l + 0.5 or cr.b + cr.h <= mr.b + 0.5 or mr.b + mr.h <= cr.b + 0.5,
			what .. ": not over the map")
		T.clean(w)
	end
end)
