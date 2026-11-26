-- #317 (run 4 of 2.4.3): on Ride home, a searched place nobody summons to, a bounty pinned: the "Your bounty" card
-- (with Take down) must stand clear of the "Nobody summons to <place> right now" line and the price picks, folded and
-- unfolded, at the maintainer's UI scale (0.71) and at 1.0, with the shipped fonts' real widths.
-- The card's own height is only known once its rows are laid out. The page measured it before that (a card laid out at the end of
-- a text refresh, T.LayoutsHeld, is 0 high until then) and put the empty state right under the card's top: the card covered the
-- title and the picks, and stayed there because nothing drew the page again.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local TL = dofile(H.root .. "/tools/preview/textlayout.lua")

local function rect(f)
	local l, b, wd, ht = f:GetRect()
	return { l = l or 0, b = b or 0, w = wd or 0, h = ht or 0, t = (b or 0) + (ht or 0) }
end
local function inter(a, b)
	local w = math.min(a.l + a.w, b.l + b.w) - math.max(a.l, b.l)
	local h = math.min(a.t, b.t) - math.max(a.b, b.b)
	return w > 0.5 and h > 0.5
end

local function run(folded, scale, held)
	-- the shipped fonts' real widths, at the game window (1920x1080) and this UI scale, as the layout checker has them
	local unitH = 768 / scale
	TL.PX = 1080 / unitH
	TL.SNAP, TL.SIZE_SNAP = "round", "round"
	H.textMetrics = TL
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920 / 1080 * unitH, screenH = unitH, physW = 1920, physH = 1080, saved = { Wuber = { coach = true } } })
	w:advance(15)
	local W, UI = c.W, c.W.UI
	UI.Toggle(true)
	w:advance(3)
	W.db.fold = { v = 1, pages = {}, narrow = folded }
	UI.Fold.Apply()
	w:advance(2)
	UI.Show("home")
	w:advance(2)
	UI.SetSearch("Gadgetzan")
	w:advance(1)
	UI.Refresh(true)
	w:advance(1)
	local s = UI.state.screens.home
	local bb = s.empty.bounty
	ok(H.visible(bb), "the bounty card to pin shows")
	local pin = bb.pin
	pin:GetScript("OnClick")(pin) -- direct-click: the test is about where the card lands after the pin; Pin's own click is covered by the buttons suite
	ok(UI.BountyMine(), "the bounty is pinned")
	if held then
		-- the page is drawn while the cards' layout is held to the end of a text refresh
		W.Theme.LayoutsHeld(UI.RefreshNow)
	else
		UI.RefreshNow()
	end
	local chip = s.bountyChip
	local function clear(when)
		ok(H.visible(chip), when .. ": Your bounty card shows")
		local cr = rect(chip)
		ok(cr.h > 0, when .. ": control: the card has a height")
		local parts = { { "title", s.empty.title }, { "sub", s.empty.sub } }
		for i, p in ipairs(bb.picks) do parts[#parts + 1] = { "pick " .. i, p } end
		for _, p in ipairs(parts) do
			if H.visible(p[2]) then
				ok(not inter(cr, rect(p[2])), when .. ": Your bounty card overlaps " .. p[1])
			end
		end
	end
	clear("as soon as the page is drawn")
	w:advance(2)
	clear("settled")
	eq(s.empty.title:GetText(), "Nobody summons to Gadgetzan right now", "the title keeps its words")
	H.textMetrics = nil
	T.clean(w)
end

for _, folded in ipairs({ true, false }) do
	for _, scale in ipairs({ 0.71, 1.0 }) do
		local name = (folded and "folded" or "unfolded") .. " UI scale " .. scale
		test("pinned bounty card (#317) " .. name .. ": the card clears the title and the picks when its layout is held", function()
			run(folded, scale, true)
		end)
		-- guard: the card laid out in step with the page (the ordinary path): it already stood clear
		test("pinned bounty card (#317) guard: " .. name .. ": the card clears the title and the picks", function()
			run(folded, scale, false)
		end)
	end
end
