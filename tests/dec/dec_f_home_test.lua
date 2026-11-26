-- Decisions round, group F: Rider Home. The bounty card's Take down tip, the "Your usual" note and the empty screen's
-- button words. Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function setup5(pinned)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768, saved = { Wuber = { coach = false } } })
	w:advance(15)
	local mine = pinned and { place = "Gadgetzan", copper = 6000, at = r.env.time() } or nil
	r.W.Bounty = { Mine = function() return mine end, Cancel = function() mine = nil return true end, Demand = function() return {} end,
		Pin = function(place, copper) mine = { place = place, copper = copper, at = r.env.time() } return true end }
	r.W.UI.Toggle(true)
	w:advance(3)
	r.W.UI.Show("home")
	w:advance(1.5)
	r.W.UI.SetSearch("Gadgetzan")
	w:advance(1)
	local bb = r.W.UI.state.screens.home.empty.bounty
	ok(H.visible(bb), "the bounty picks show")
	local en = bb.pin:GetScript("OnEnter")
	en(bb.pin)
	local env = r.env
	local lines = { env.GameTooltipTextLeft1:GetText(), env.GameTooltipTextLeft2:GetText() }
	return w, r, bb, lines
end

test("dec f: audit C27r-5: control, with nothing pinned the button reads Pin and its tip says Pin a bounty", function()
	local w, r, bb, lines = setup5(false)
	ok(bb.pin.label.wuberText ~= "Take down", "label " .. tostring(bb.pin.label.wuberText))
	eq(lines[1], "Pin a bounty", "tip title")
end)

test("dec f: audit C27r-5: with a bounty up the pin button is gone and the Take down link's tip says so (already as asked since design 2)", function()
	local w, r, bb = setup5(true)
	ok(not H.visible(bb.pin), "the Pin button hides while the bounty is up")
	local chip = r.W.UI.state.screens.home.bountyChip
	ok(chip and H.visible(chip.close), "the Take down link shows")
	eq(chip.close.label.wuberText, "Take down", "control: the link is Take down")
	chip.close:GetScript("OnEnter")(chip.close)
	eq(r.env.GameTooltipTextLeft1:GetText(), "Take the bounty down", "tip title")
	eq(r.env.GameTooltipTextLeft2:GetText(), "Drivers stop seeing it.", "tip text")
	T.clean(w)
end)

local function home4(bobOpen)
	local w = T.newWorld()
	local bob = T.driver(w, T.BOB, { spot = "Undercity" })
	if bobOpen then T.goOnline(bob) end
	w:advance(5)
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar", screenW = 1365, screenH = 768, saved = { Wuber = { coach = false } } })
	w:advance(15)
	local W = r.W
	-- the usual driver is Anita, who is not online
	W.db.rides = {}
	for i = 1, 3 do
		W.db.rides[i] = { dest = "Undercity", driver = T.ANITA, driverKey = W.Key(T.ANITA), price = 5000, at = r.env.time() - i * 3600, saved = 600 }
	end
	if W.RebuildTotals then W.RebuildTotals() end
	W.UI.Toggle(true)
	w:advance(3)
	W.UI.Show("home")
	w:advance(3)
	W.UI.Refresh(true)
	w:advance(3)
	return w, r, W, W.UI.state.screens.home
end

test("dec f: audit C27r-4: control, nobody is open at all: the line 'nobody's there right now' is true", function()
	local w, r, W, s = home4(false)
	ok(#r:findText("Your usual") == 0 and #r:findText("nobody's there right now") == 0, "control: no usual note while nobody is listed (word rule): " .. T.list(r:visibleTexts()):sub(1, 200))
	ok(#r:findText("No drivers online") > 0, "the empty screen says so")
end)

test("dec f: audit C27r-4: another driver is open at the usual place: Home does not say nobody is there", function()
	local w, r, W, s = home4(true)
	ok(#r:findText("Undercity") > 0 and not H.visible(s.usual), "control: Bob's card is listed and Anita's usual card is not up: " .. T.list(r:visibleTexts()):sub(1, 250))
	ok(#r:findText("Bob") > 0, "control: Bob is listed")
	ok(#r:findText("nobody's there right now") == 0,
		"Home prints \"Your usual: Undercity - nobody's there right now\" above Bob's open card for Undercity: " .. T.list(r:visibleTexts()):sub(1, 300))
	T.clean(w)
end)
test("dec f: the empty screen's button reads 'Tell me when one opens', as on the Ride screen", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768, saved = { Wuber = { coach = false } } })
	w:advance(15)
	r.W.UI.Toggle(true)
	w:advance(3)
	r.W.UI.Show("home")
	w:advance(3)
	r.W.UI.Refresh(true)
	w:advance(2)
	local e = r.W.UI.state.screens.home.empty
	ok(H.visible(e), "the empty screen is up: " .. T.list(r:visibleTexts()):sub(1, 200))
	eq(e.watch.label:GetText(), "Tell me", "button label (word rule: short; the tooltip has the long words)")
	ok(#r:findText("comes online") == 0, "no old words: " .. T.list(r:visibleTexts()):sub(1, 300))
	T.clean(w)
end)
