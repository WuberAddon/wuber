-- Round 37 b2: the Skip the bird card waits the driver's own average summon (UI.SummonWait), the same number the Fly or summon card uses for that driver.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function setup(avg)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	W.drivers["anita lift"] = { name = "Anita Lift", key = "anita lift", dest = "Orgrimmar", price = 5000, state = "open", team = 3, service = "Wuber", heard = r.env.GetTime(), avgSummon = avg }
	W.ride = { id = "gJBrSi", state = "done", driver = "anita lift", driverKey = "anita lift", dest = "Orgrimmar", price = 5000 }
	return w, r, W
end

test("r37 b2: UI.SummonWait gives the average in 10..900 floored, else the default", function()
	local w, r, W = setup(nil)
	local UI = W.UI
	ok(type(UI.SummonWait) == "function", "UI.SummonWait is there")
	local def = W.SUMMON_SECS or 30
	eq(UI.SummonWait({}), def, "nil")
	eq(UI.SummonWait({ avgSummon = 9 }), def, "9")
	eq(UI.SummonWait({ avgSummon = 10 }), 10, "10")
	eq(UI.SummonWait({ avgSummon = 45.7 }), 45, "45.7")
	eq(UI.SummonWait({ avgSummon = 900 }), 900, "900")
	eq(UI.SummonWait({ avgSummon = 901 }), def, "901")
	eq(UI.SummonWait({ avgSummon = "abc" }), def, "a string")
	eq(UI.SummonWait(), def, "no table")
	T.clean(w)
end)

test("r37 b2: a driver averaging 300 s with a 200 s flight is not picked; the why-text says shorter than a summon's wait", function()
	local w, r, W = setup(300)
	local Mod = W.Mod("UI.Bird")
	local real = W.FlightTime
	W.FlightTime = function() return 200, "est" end
	eq(Mod.Pick(), nil, "not picked")
	w:openTaxiMap(r, { { name = "Thunder Bluff, Mulgore", type = "CURRENT" }, { name = "Orgrimmar, Durotar", type = "REACHABLE", cost = 50 } })
	w:advance(0.5)
	W.FlightTime = function() return 250, "est" end
	ok(Mod.Why() and Mod.Why():find("shorter than a summon's wait", 1, true), "why: " .. tostring(Mod.Why()))
	W.FlightTime = real
	T.clean(w)
end)

test("r37 b2: a driver averaging 45 s with a 150 s flight is picked, back 105; no average is flight less 30", function()
	local w, r, W = setup(45)
	local Mod = W.Mod("UI.Bird")
	local real = W.FlightTime
	W.FlightTime = function() return 150, "est" end
	local d, info = Mod.Pick()
	ok(d, "picked")
	eq(info.back, 105, "back")
	W.drivers["anita lift"].avgSummon = nil
	local _, info2 = Mod.Pick()
	eq(info2.back, 150 - (W.SUMMON_SECS or 30), "no average: as before")
	W.FlightTime = real
	T.clean(w)
end)

test("r37 b2: for one driver the card's back and the booking card's time saved are the same number", function()
	local w, r, W = setup(45)
	local f1, f2 = W.FlightTime, W.TravelSaved
	W.FlightTime = function() return 150, "est" end
	W.TravelSaved = function() return 150, "est" end
	local _, info = W.Mod("UI.Bird").Pick()
	ok(info, "picked")
	local di = W.Mod("UI.Rider.Booking").DialInfo(W.UI.Drivers()[1], 5000)
	eq(di.timeSaved, info.back, "same number")
	eq(info.back, 105, "150 less 45")
	W.FlightTime, W.TravelSaved = f1, f2
	T.clean(w)
end)
