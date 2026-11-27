local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
test("r33 f6 AUD-120: picking a tip while the trade window is open updates the trade strip", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	local MIA = "Mia Runner"
	r.W.ride = { id = "r6", driver = MIA, driverKey = key(MIA), dest = "Undercity", price = 5000, state = "arrived",
		at = r.env.GetTime(), payee = MIA, payto = "Mia", summoner = MIA, service = "Mia's Rides" }
	r.W.db.tipPct = 0
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(3)
	w:addBot(MIA, { spot = "Orgrimmar" })
	H.state[r.env.TradeFrame].shown = true
	ok(w:openTrade(w:player(MIA), r.player), "the driver opens trade")
	w:advance(1.5)
	local before = r:findText("Wuber: ")
	ok(#before > 0, "control: the strip under the trade window shows. Visible: " .. T.list(r:visibleTexts()):sub(1, 300))
	local t0 = before[1]:GetText()
	ok(t0:find("50", 1, true), "control: strip asks for the fare 50s, reads: " .. t0)
	ok(r.W.UI.SetTipPct(20), "the player picks a 20% tip")
	w:advance(1.5)
	local after = r:findText("Wuber: ")
	local t1 = after[1] and after[1]:GetText() or "(none)"
	ok(t1 ~= t0 and t1:find("60", 1, true), "the strip under the open trade follows the tip to 60s, reads: " .. t1)
	T.clean(w)
end)