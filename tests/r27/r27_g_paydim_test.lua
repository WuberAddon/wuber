local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
test("r27 AUD-09: the pay card is blank (opaque fill over the fare) while a stranger's trade is warned about", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	local MIA, SLY = "Mia Runner", "Sly Fox"
	r.W.ride = { id = "r6", driver = MIA, driverKey = key(MIA), dest = "Undercity", price = 5000, state = "arrived",
		at = r.env.GetTime(), payee = "Bea Jones", payto = "Bea", summoner = "Bea Jones", service = "Mia's Rides" }
	r.W.db.tipPct = 0
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(3)
	local pay = r.W.UI.state.screens.found.pay
	ok(H.visible(pay) and #r:findText("Type in trade window") > 0, "control: before the stranger the pay card shows its fare")
	w:addBot(SLY, { spot = "Orgrimmar" })
	H.state[r.env.TradeFrame].shown = true
	ok(w:openTrade(w:player(SLY), r.player), "the stranger opens trade")
	w:advance(1.5)
	ok(H.visible(pay.dim), "the dim layer shows (the intended dimming)")
	-- the dim card's fill is 70% (control); its border 9-slice (centre included) must not be solid
	local fill = pay.dim.bg.parts.M
	local _, _, _, fa = fill:GetVertexColor()
	ok(math.abs((fa or 1) - 0.7) < 0.01, "control: the dim fill is 70% opaque, got " .. tostring(fa))
	-- no border layer at all is fine: only the 70% fill dims the card
	local ba = 0
	if pay.dim.border then _, _, _, ba = pay.dim.border.parts.M:GetVertexColor() end
	ok((ba or 1) < 0.99, "the dim card's border layer is solid (alpha " .. tostring(ba)
		.. ") across the whole card, so the player sees an empty card instead of a dimmed fare")
	T.clean(w)
end)
