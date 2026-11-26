local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- Round 33, group E5. AUD-118 (Google C03b-3): a trip on one continent was priced through free boats across
-- the sea (Auberdine > Menethil > Theramore: 0c, "no price") instead of the flight master's fare.
-- AUD-119 (Google C03b-1): the nearest flight point to Gnomeregan was Tidegear Coast (node 3205), which has
-- no flights, so the rider saw no flight price or route.

test("r33 e5: a trip on one continent is priced by flight, not by free boats over the sea (AUD-118)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Ironforge", faction = "Alliance" })
	T.settle(w)
	local W = r.W
	eq(W.FLY.Cheapest({ 80 }, { 32 }, "A"), 630, "control: Ratchet > Theramore 6s30c")
	local c = W.FlightCost("Auberdine", "Theramore")
	eq(c, 630, "Auberdine > Theramore is the direct 6s30c flight")
	local route = W.FlightRoute("Auberdine", "Theramore")
	ok(route and route[1] == 26 and route[#route] == 32, "route Auberdine to Theramore")
	for _, id in ipairs(route or {}) do ok(id ~= 7, "the route does not go by Menethil Harbor") end
	local via
	c, _, _, via = W.FlightCost("Stormwind", "Booty Bay")
	eq(c, W.FLY.Cheapest({ 2 }, { 19 }, "A"), "Stormwind > Booty Bay")
	ok(via ~= "boat", "Stormwind > Booty Bay is not labelled boat (" .. tostring(via) .. ", " .. tostring(c) .. ")")
	c, _, _, via = W.FlightCost("Ironforge", "Booty Bay")
	ok(via ~= "boat", "Ironforge > Booty Bay is not labelled boat (" .. tostring(via) .. ", " .. tostring(c) .. ")")
	-- a real crossing still takes the boat
	c, _, _, via = W.FlightCost("Ironforge", "Theramore")
	eq(via, "boat", "Ironforge > Theramore still goes by the Menethil boat")
	ok(c and c > 0, "and has a price")
	T.clean(w)
end)

test("r33 e5: the nearest flight point is one with flights, not Tidegear Coast (AUD-119)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Ironforge", faction = "Alliance" })
	T.settle(w)
	local W = r.W
	-- the game's world position of Gnomeregan's entrance (continent 0), in the same system as W.TAXI.nodes
	local realPos = r.env.C_Map.GetWorldPosFromMapPos
	r.env.C_Map.GetWorldPosFromMapPos = function(id, pos)
		if id == 1426 and math.abs(pos.x - 0.24) < 1e-6 then return 0, r.env.CreateVector2D(-5163.5, 925.4) end
		return realPos(id, pos)
	end
	local g = W.FindPlace("Gnomeregan")
	g.world = nil
	eq(select(2, W.PlaceWorld(g)), -5163.5, "harness: Gnomeregan is where the game puts it")
	local route = W.FlightRoute("Gnomeregan", "Stormwind")
	ok(route, "a route from Gnomeregan to Stormwind")
	ok(route and route[1] ~= 3205, "the route does not start at Tidegear Coast")
	local cost = W.FlightCost("Gnomeregan", "Stormwind")
	ok(cost and cost > 0, "a flight price from Gnomeregan to Stormwind, got " .. tostring(cost))
	T.clean(w)
end)
