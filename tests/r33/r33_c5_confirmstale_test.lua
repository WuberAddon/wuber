local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local MIA = "mia runner"
local A, B = "mia runner", "bea jones"
test("r33 c5 AUD-115: opening a second driver to the same place lays the Here map over the World map", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	r.wide = true
	w:advance(15)
	local W = r.W
	W.db.coach = true
	W.drivers = W.drivers or {}
	W.drivers[A] = { name = "Mia Runner", key = A, dest = "Ratchet", price = 5000, state = "open", team = 3, service = "Mia's Rides", heard = r.env.GetTime() }
	W.drivers[B] = { name = "Bea Jones", key = B, dest = "Ratchet", price = 6000, state = "open", team = 3, service = "Bea's Rides", heard = r.env.GetTime() }
	W.UI.Show("confirm", A)
	w:advance(3)
	local s = W.UI.state.screens.confirm
	ok(s.wide, "control: the booking card is unfolded (map in the side pane)")
	local WM = W.Mod("UI.Rider.WorldMap")
	eq(WM.Wanted(), "world", "control: the World view is the wanted mode")
	ok(not H.visible(s.map), "control: with World chosen the Here map is hidden after the first open")
	-- a pin / toast for another driver to the same place
	W.UI.Show("confirm", B)
	w:advance(3)
	ok(not H.visible(s.map), "with World chosen the Here map stays hidden after the second driver opens")
	T.clean(w)
end)
test("r33 c5 AUD-134: Confirm for a driver who went offline still shows the earlier driver's card", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	W.drivers[MIA] = { name = "Mia Runner", key = MIA, dest = "Ratchet", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = r.env.GetTime() }
	W.UI.Show("confirm", MIA)
	w:advance(3)
	ok(#r:findText("Mia's Rides") > 0, "control: Mia's booking card shows. Visible: " .. T.list(r:visibleTexts()):sub(1, 300))
	local priceBefore = #r:findText("50s") > 0
	-- the player leaves the card, Mia goes offline, then a stale toast for Mia is clicked
	W.UI.Show("home") w:advance(1)
	W.drivers[MIA] = nil
	W.UI.Show("confirm", MIA)
	w:advance(3)
	ok(#r:findText("This driver went offline") > 0, "control: the card says the driver went offline. Visible: " .. T.list(r:visibleTexts()):sub(1, 300))
	local s = W.UI.state.screens.confirm
	ok(priceBefore, "control: price 50s was on the card before")
	local stale = {}
	if #r:findText("50s") > 0 then stale[#stale + 1] = "price 50s" end
	if #r:findText("Ratchet") > 0 then stale[#stale + 1] = "route Ratchet" end
	ok(#stale == 0, "the card says 'This driver went offline' but still shows Mia's old details: " .. table.concat(stale, ", ")
		.. ". Visible: " .. T.list(r:visibleTexts()):sub(1, 400))
	T.clean(w)
end)
test("r33 c5 AUD-134 follow-up: the card for an online driver after a gone one shows its row, dial or pill, route and pay", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	W.UI.Show("confirm", MIA)
	w:advance(3)
	local s = W.UI.state.screens.confirm
	ok(#r:findText("This driver went offline") > 0, "control: the gone card shows")
	W.drivers["bea jones"] = { name = "Bea Jones", key = "bea jones", dest = "Ratchet", price = 6000, state = "open", team = 3,
		service = "Bea's Rides", heard = r.env.GetTime() }
	W.UI.Show("home") w:advance(1)
	W.UI.Show("confirm", "bea jones")
	w:advance(3)
	local card = s.card
	ok(card.row:IsShown(), "the driver row is shown")
	ok(s.dial:IsShown() or s.saved:IsShown(), "the dial or the savings pill is shown")
	ok(s.route:IsShown(), "the route is shown")
	ok(s.pay and s.pay:IsShown() or s.rc:IsShown(), "the pay row (or raincheck row) is shown")
	ok(#r:findText("60s") > 0, "the price is shown. Visible: " .. T.list(r:visibleTexts()):sub(1, 300))
	T.clean(w)
end)
