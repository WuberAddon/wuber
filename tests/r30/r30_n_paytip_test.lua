local T = ...
local test, ok, eq, H = T.test, T.ok, T.eq, T.H
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
test("r30 N: after a part payment the pay card still shows the tip and the flight line the whole cost", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	local MIA = "Mia Runner"
	r.W.ride = { id = "r6", driver = MIA, driverKey = key(MIA), dest = "Undercity", price = 5000, state = "arrived",
		at = r.env.GetTime(), payee = "Bea Jones", payto = "Bea", summoner = "Bea Jones", service = "Mia's Rides",
		paidSoFar = 2500, flightCost = 3000, flightExact = true }
	r.W.db.tipPct = 10
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(3)
	local UI = r.W.UI
	eq(UI.PayTotal({ price = 5000, raw = r.W.ride }), 3000, "PayTotal is 25s left + 5s tip")
		ok(#r:findText("25s left of 50s %+ 5s tip") > 0, "the small line says what is left of the fare, plus the tip (r46 g)")
	local part = UI.FlightLine({ id = "r6", dest = "Undercity", state = "arrived", price = 5000, raw = r.W.ride })
	local saved = r.W.ride.paidSoFar
	r.W.ride.paidSoFar = nil
	local whole = UI.FlightLine({ id = "r6", dest = "Undercity", state = "arrived", price = 5000, raw = r.W.ride })
	r.W.ride.paidSoFar = saved
	ok(part ~= nil, "a flight line is built")
	eq(part, whole, "the flight line reads the same with a part payment")
	T.clean(w)
end)
