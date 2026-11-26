local T = ...
local test, eq, ok = T.test, T.eq, T.ok
test("r46 E AUD-133: a summon priced the same as the flight says 'the summon costs the same'", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	r.W.FlightCost = function() return 2300, 1 end
	r.W.TravelSaved = function() return nil end
	local UI = r.W.UI
	local c = UI.FlightLine("Undercity", false, 1000)
	ok(c and c:find("saves you", 1, true), "control: " .. tostring(c))
	local line = UI.FlightLine("Undercity", false, 2300)
	eq(line, "Flying here costs 23s · the summon costs the same")
	local past = UI.FlightLine("Undercity", true, 2300)
	eq(past, "Flying here would cost 23s · the summon cost the same")
	T.clean(w)
end)
