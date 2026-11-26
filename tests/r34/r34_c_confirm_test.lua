local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
test("r34 c: the rider-level chip on the waiting screen takes the mouse so its tooltip shows", function()
	local w = T.newWorld()
	local d = T.driver(w, "Anita Lift")
	local r = T.rider(w)
	T.settle(w)
	T.goOnline(d)
	r.W.Tier = function() return 2 end -- a Silver rider
	r.W.RequestRide("anita lift")
	w:advance(0.5)
	r.W.ride.state = "requesting"
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.RefreshNow()
	local chip = r.W.UI.state.screens.finding.tier
	ok(chip and H.visible(chip), "control: the Silver rider chip shows on the waiting screen. Visible: " .. T.list(r:visibleTexts()):sub(1, 300))
	ok(chip.wuberTip and chip.wuberTip.title == "Your rider level", "control: the chip carries the 'Your rider level' tooltip")
	ok(chip:IsMouseEnabled(), "the chip has a 'Your rider level' tooltip but its frame takes no mouse (no EnableMouse), so in the game hovering it never shows the tip")
	T.clean(w)
end)
local MIA = "mia runner"
local function open(w, grouped)
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	w:advance(15)
	local W = r.W
	W.db.coach = true
	-- (design round 4) the fake world has real yards now, so the flight is shorter and the summon no longer wins by a lot:
	-- a low value of time makes flying the cheaper pick, whose verdict ("Flying is ... cheaper, ... slower") is the long one that wraps
	W.db.timeValue = 20000
	W.drivers = W.drivers or {}
	W.drivers[MIA] = { name = "Mia Runner", key = MIA, dest = "Ratchet", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = r.env.GetTime(), summoner = "Mia Runner" }
	if grouped then
		w:addBot("Bob Lee", { spot = "Orgrimmar" })
		w:invite(r, "Bob Lee") w:advance(3)
		W.Fire("DRIVERS")
	end
	W.UI.Show("confirm", MIA)
	w:advance(3)
	return r, W
end
test("r34 c: folded booking card, wrapped verdict and a group warning keeps the how-you-pay row", function()
	local w = T.newWorld()
	local r, W = open(w, false)
	ok(#r:findText("Trade 50s after you arrive") > 0, "control: without a group the card says 'Trade 50s after you arrive'")
	ok(W.UI.state.screens.confirm.dial.extra > 0, "control: the dial's verdict wraps onto a second line (extra " .. tostring(W.UI.state.screens.confirm.dial.extra) .. ")")
	local w2 = T.newWorld()
	local r2, W2 = open(w2, true)
	ok(#r2:findText("You're in a group") > 0, "control: the group warning shows")
	ok(#r2:findText("Trade 50s after you arrive") > 0, "the About card squeezed in (the squeeze counted the wrapped line as saved space twice) so the 'Trade 50s after you arrive' how-you-pay row is hidden. Visible: " .. T.list(r2:visibleTexts()):sub(1, 700))
	T.clean(w2)
end)