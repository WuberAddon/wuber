-- Issue 82: the Skip the bird card must be clickable when the What's new card is up over it.
-- The What's new card sits in the FULLSCREEN_DIALOG strata; the bird card sat a strata below the flight map,
-- so a bird card placed under the news card could not be clicked (the click hit the news card).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local NODES = { { name = "Thunder Bluff, Mulgore", type = "CURRENT" }, { name = "Orgrimmar, Durotar", type = "REACHABLE", cost = 50 } }

test("issue 82 bird: the What's new card is up, you click the Skip the bird card and the booking screen opens", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1920, screenH = 1080,
		saved = { Wuber = { coach = true, newsSeen = "2.3.4" } } })
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	W.drivers["anita lift"] = { name = "Anita Lift", key = "anita lift", dest = "Orgrimmar", price = 5000, state = "open", team = 3, service = "Wuber", heard = r.env.GetTime() }
	local News, Bird = W.Mod("UI.WhatsNew"), W.Mod("UI.Bird")
	w:advance(5)
	local news = News.Card()
	ok(news and H.visible(news), "the What's new card is up")
	w:openTaxiMap(r, NODES)
	w:advance(1)
	local c = Bird.Card()
	ok(c and H.visible(c), "the Skip the bird card shows")
	-- the flight map sits so that the space beside it is where the news card is (the card's usual place is right of the map)
	local nr, map = H.rect(news), r.env.TaxiFrame
	local mr = H.rect(map)
	map:ClearAllPoints()
	map:SetPoint("TOPLEFT", r.env.UIParent, "BOTTOMLEFT", nr.l - mr.w + 40, nr.b + nr.h + 20)
	w:advance(0.5)
	ok(Bird.Place(c, map), "the card is placed again beside the moved map")
	local hit = r:frameAt(H.rect(c).l + H.rect(c).w / 2, H.rect(c).b + H.rect(c).h / 2)
	local f, under = hit, false
	while f do
		if f == c then under = true break end
		f = f:GetParent()
	end
	ok(under, "the click at the middle of the Skip the bird card lands on the card, not on the What's new card")
	r:clickOn(c)
	w:advance(1)
	eq(W.UI.state.confirmKey, "anita lift", "the booking screen opens for the driver")
	ok(r.env.TaxiFrame:IsShown(), "and the flight map stays open")
	T.clean(w)
end)

test("issue 82 bird: no spot is clear of the What's new card, the Skip the bird card rises above it and a click opens the booking screen", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1920, screenH = 1080,
		saved = { Wuber = { coach = true, newsSeen = "2.3.4" } } })
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	W.drivers["anita lift"] = { name = "Anita Lift", key = "anita lift", dest = "Orgrimmar", price = 5000, state = "open", team = 3, service = "Wuber", heard = r.env.GetTime() }
	local News, Bird = W.Mod("UI.WhatsNew"), W.Mod("UI.Bird")
	w:advance(5)
	local news = News.Card()
	ok(news and H.visible(news), "the What's new card is up")
	w:openTaxiMap(r, NODES)
	w:advance(1)
	local c = Bird.Card()
	ok(c and H.visible(c), "the Skip the bird card shows")
	-- the news card's frame covers the whole screen: the spots right of, left of and below the map all hit it
	news:SetSize(1920, 1080)
	news:ClearAllPoints()
	news:SetPoint("BOTTOMLEFT", r.env.UIParent, "BOTTOMLEFT", 0, 0)
	ok(Bird.Place(c, r.env.TaxiFrame), "the card is placed")
	ok(H.STRATA_RANK(c:GetFrameStrata()) > H.STRATA_RANK(news:GetFrameStrata()), "card strata " .. tostring(c:GetFrameStrata()) .. " above the news card's")
	ok(H.STRATA_RANK(c:GetFrameStrata()) > H.STRATA_RANK("FULLSCREEN_DIALOG"), "above FULLSCREEN_DIALOG")
	ok(c:GetFrameLevel() > news:GetFrameLevel(), "card level " .. tostring(c:GetFrameLevel()) .. " above the news card's " .. tostring(news:GetFrameLevel()))
	local cr = H.rect(c)
	local f, under = r:frameAt(cr.l + cr.w / 2, cr.b + cr.h / 2), false
	while f do
		if f == c then under = true break end
		f = f:GetParent()
	end
	ok(under, "the click at the middle of the card lands on the card")
	r:clickOn(c)
	w:advance(1)
	eq(W.UI.state.confirmKey, "anita lift", "the booking screen opens for the driver")
	T.clean(w)
end)
