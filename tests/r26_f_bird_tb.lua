local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function setup(state, birdTip)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	W.drivers["anita lift"] = { name = "Anita Lift", key = "anita lift", dest = "Orgrimmar", price = 5000, state = "open", team = 3, service = "Wuber", heard = r.env.GetTime() }
	if birdTip ~= nil then W.db.birdTip = birdTip end
	if state then W.ride = { id = "gJBrSi", state = state, driver = "anita lift", driverKey = "anita lift", dest = "Orgrimmar", price = 5000 } end
	return w, r, W
end

local function open(w, r)
	w:openTaxiMap(r, { { name = "Thunder Bluff, Mulgore", type = "CURRENT" }, { name = "Orgrimmar, Durotar", type = "REACHABLE", cost = 50 } })
	w:advance(0.5)
end

for _, st in ipairs({ "done", "paying", "arrived" }) do
	test("r26f bird: Thunder Bluff to Orgrimmar, ride " .. st .. ", real estimate", function()
		local w, r, W = setup(st)
		local Mod = W.Mod("UI.Bird")
		open(w, r)
		local d, info = Mod.Pick()
		ok(d and d.key == "anita lift", "picks the driver")
		ok(info and info.secs > 120 and info.secs < 240, "estimate is the short one: " .. tostring(info and info.secs))
		ok(Mod.Card() and H.visible(Mod.Card()), "card visible")
		T.clean(w)
	end)
end

test("r26f bird: card back time is the flight minus the wait", function()
	local w, r, W = setup("done")
	local Mod = W.Mod("UI.Bird")
	open(w, r)
	local d, info = Mod.Pick()
	eq(info.back, info.secs - W.SUMMON_SECS, "back")
	ok(Mod.Message(d, info):find("back.", 1, true), "wording keeps back")
	T.clean(w)
end)

test("r26f bird: negatives (short flight, tip off, ride still waiting)", function()
	local w, r, W = setup("done")
	local Mod = W.Mod("UI.Bird")
	local real = W.FlightTime
	W.FlightTime = function() return 25, "est" end
	ok(Mod.Pick() == nil, "a 25 s flight gives no pick")
	open(w, r)
	ok(not (Mod.Card() and H.visible(Mod.Card())), "no card for 25 s")
	W.FlightTime = real
	T.clean(w)
	local w2, r2, W2 = setup("done", false)
	local M2 = W2.Mod("UI.Bird")
	open(w2, r2)
	ok(not (M2.Card() and H.visible(M2.Card())), "tip off: no card")
	T.clean(w2)
	local w3, r3, W3 = setup("summoning")
	local M3 = W3.Mod("UI.Bird")
	open(w3, r3)
	ok(not (M3.Card() and H.visible(M3.Card())), "ride before the summon lands: no card")
	T.clean(w3)
end)
