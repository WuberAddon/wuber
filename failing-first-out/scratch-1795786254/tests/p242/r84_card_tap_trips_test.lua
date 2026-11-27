-- Tests for issue 84: tapping the milestone celebration card opens Wuber on Trips, even with the
-- What's new card and a first-open tip on screen at the same time.
local T = ...
local test, ok, eq, H = T.test, T.ok, T.eq, T.H

test("#84 moments: tapping the celebration card opens Wuber on Trips with the What's new card up", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, {})
	w:advance(5)
	local W = c.W
	local News = W.Mod("UI.WhatsNew")
	ok(News.Show("2.4.2"), "the What's new card shows")
	w:advance(1)
	W.UI.Celebrate("firstride", { "firstride" })
	w:advance(1)
	local pop = W.UI.state.pop
	ok(pop and H.visible(pop), "the celebration card shows")
	local hit = c:clickOn(pop)
	-- the tap must reach the celebration card, not the What's new card drawn under it
	eq(hit, pop, "the tap lands on the celebration card (it got " .. tostring(hit and hit:GetName()) .. "; on screen: " .. table.concat(c:visibleTexts(), " | ") .. ")")
	w:advance(1.5)
	ok(W.UI.IsShown(), "Wuber opens")
	eq(W.UI.state.tab, "Trips", "Wuber opens on the Trips tab")
	T.clean(w)
end)

-- a first open caused by the tap must stay on Trips: the first-open login tip used to move the phone to Home
test("#84 moments: tapping the celebration card on a first open stays on Trips (the login tip does not move it to Home)", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = true } } })
	w:advance(10)
	local W = c.W
	W.UI.Celebrate("firstride", { "firstride" })
	w:advance(1)
	local pop = W.UI.state.pop
	ok(pop and H.visible(pop), "the celebration card shows")
	ok(not W.UI.IsShown(), "Wuber is shut before the tap")
	c:clickOn(pop)
	w:advance(1.5)
	eq(W.UI.state.tab, "Trips", "Wuber opens on the Trips tab")
	w:advance(8)
	eq(W.UI.state.tab, "Trips", "and stays on Trips after the login tip's wait")
	T.clean(w)
end)
