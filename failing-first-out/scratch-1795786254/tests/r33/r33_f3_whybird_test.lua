local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local NODES = { { name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 },
	{ name = "Tarren Mill, Hillsbrad", type = "REACHABLE", cost = 580, x = 0.47, y = 0.44 } }

test("r33 f3 (REV-r28-5): Why in the 0.1 s after the flight map opens must not say no room", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Tarren Mill", price = 5000, state = "open", team = 3, service = "Mia's Rides", heard = r.env.GetTime() }
	W.FlightCost = function() return 2300, 1 end
	W.FlightTime = function() return 540, "est" end
	local Mod = W.Mod("UI.Bird")
	w:openTaxiMap(r, NODES)
	local line = Mod.Why()
	local up = Mod.Card() and H.visible(Mod.Card())
	ok(not (line and line:find("no room", 1, true)), "player sees: " .. tostring(line) .. " (card up yet: " .. tostring(up) .. ")")
	w:advance(0.5)
	ok(Mod.Card() and H.visible(Mod.Card()), "control: card shows after 0.5 s")
	T.clean(w)
end)
