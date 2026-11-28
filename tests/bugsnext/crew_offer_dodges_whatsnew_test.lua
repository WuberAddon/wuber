-- Regression test for #108: crew offer card dodges the What's new card so No thanks stays clickable.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function overlaps(a, b)
	return a.l < b.l + b.w - 1 and b.l < a.l + a.w - 1 and a.b < b.b + b.h - 1 and b.b < a.b + a.h - 1
end

test("bugsnext: crew offer dodges What's new card so No thanks is clickable", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	w:advance(15)
	local W = a.W
	local wn = W.Mod("UI.WhatsNew")
	ok(wn and wn.Show, "UI.WhatsNew.Show exists")
	ok(wn.Show(wn.Version()), "UI.WhatsNew.Show returns true")
	w:advance(0.5)
	local news = a.env.WuberNewsCard
	ok(news and news:IsShown(), "What's new card is shown")

	ok(W.UI.CrewOffer("CaptainOne", "Orgrimmar"), "UI.CrewOffer shows")
	w:advance(0.3)
	local card = W.UI.drive and W.UI.drive.offer
	ok(card and card:IsShown(), "crew offer card is shown")
	ok(not overlaps(H.rect(card), H.rect(news)), "crew offer card does not overlap What's new card")

	a:clickOn(card.no)
	w:advance(0.5)
	eq(card.from, nil, "clicking No thanks clears the crew offer")
	T.clean(w)
end)
