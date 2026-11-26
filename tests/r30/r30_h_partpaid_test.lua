local T = ...
local test, ok, eq, H = T.test, T.ok, T.eq, T.H
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
test("r30 H: after part of the fare is paid, the pay card and the trade strip name what is left", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	local MIA = "Mia Runner"
	r.W.ride = { id = "r6", driver = MIA, driverKey = key(MIA), dest = "Undercity", price = 5000, state = "arrived",
		at = r.env.GetTime(), payee = "Bea Jones", payto = "Bea", summoner = "Bea Jones", service = "Mia's Rides", paidSoFar = 2500 }
	r.W.db.tipPct = 0
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(3)
	eq(r.W.UI.PayTotal({ price = 5000, raw = r.W.ride }), 2500, "PayTotal is the 25s left")
	ok(#r:findText("25s") > 0, "the pay card names 25s")
	ok(#r:findText("Type 50s") == 0, "the pay card no longer says the whole 50s")
	H.state[r.env.TradeFrame].shown = true
	r.W.Fire("TRADE_SHOW")
	w:advance(1.5)
	T.clean(w)
end)
