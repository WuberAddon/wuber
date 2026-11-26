-- #317 run 5 (2.4.3): on Ride home, a searched place nobody summons to, your bounty pinned, the window FOLDED: the
-- "Your bounty" card covered "Nobody summons to <place> right now" and the price picks (the real game, Auto check,
-- UI scale 0.71, folded window 360 x 600 at scale 1.15). Run 4's fix measured the card; this was not a measuring fault.
-- Why folded and not unfolded: with the Group Finder setting on, its card stands on top of an empty list, under your
-- bounty. The folded list is 238 high (unfolded 392), too short for the bounty stack under both cards, so Home moved the
-- Group Finder card under the stack (belowGF) and started the stack at the list's top (offset 0): right under your
-- bounty's card. The fix places the stack by anchors (its top to the bottom of the card above it), so the game lays it
-- out and no measured height or late layout can put it under the card.
-- Each case plays the Lab's order (home_empty folded and unfolded, then home_bounty), with the real client's late
-- layouts: the cards' layout held to the end of a text refresh, the card's measured height wrong (deferred), the window
-- hidden while the page is drawn and shown after, and the list 0 wide and 0 high at the first layout.
local T = ...
local test, ok, H = T.test, T.ok, T.H
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

local function run(o)
	local unitH = 768 / o.scale
	TL.PX = 1080 / unitH
	TL.SNAP, TL.SIZE_SNAP = "round", "round"
	H.textMetrics = TL
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920 / 1080 * unitH, screenH = unitH, physW = 1920, physH = 1080, saved = { Wuber = { coach = true } } })
	w:advance(15)
	local W, UI = c.W, c.W.UI
	if o.gf then W.db.groupFinder = true end
	UI.Toggle(true)
	w:advance(3)
	local function fold(narrow) W.db.fold = { v = 1, pages = {}, narrow = narrow } UI.Fold.Apply() end
	-- the Lab's order: home_empty folded, then unfolded
	fold(true) w:advance(2)
	UI.Show("home") UI.RefreshNow() w:advance(2)
	fold(false) w:advance(2) UI.RefreshNow() w:advance(2)
	-- home_bounty: your bounty for Gadgetzan (as the Lab's photo shot stubs it), the window folded again
	local mine = { place = "Gadgetzan", copper = 5000, at = os.time() - 120, left = 1680 }
	W.Bounty.Mine = function() return mine end
	local s = UI.state.screens.home
	if o.hidden then UI.Toggle(false) end
	fold(o.folded)
	UI.SetSearch("Gadgetzan")
	UI.Show("home")
	local bc = s.bountyChip
	local undo = {}
	if o.zero then
		-- the list 0 wide and 0 high at the first layout (its anchors not resolved yet)
		for _, k in ipairs({ "GetWidth", "GetHeight" }) do
			undo[#undo + 1] = { s.clip, k, rawget(s.clip, k) }
			s.clip[k] = function() return 0 end
		end
	end
	if o.deferred then
		-- the card's height as the page measures it is never its real height (a font or a wrap the measure misses): it
		-- stays wrong for every redraw of this case
		local real = bc.LayoutNow
		bc.LayoutNow = function(self)
			local y = real(self)
			self.height = 0
			return 0
		end
	end
	if o.held then
		W.Theme.LayoutsHeld(UI.RefreshNow)
	else
		UI.RefreshNow()
	end
	for i = #undo, 1, -1 do undo[i][1][undo[i][2]] = undo[i][3] end
	if o.hidden then UI.Toggle(true) end
	local function clear(when)
		ok(H.visible(bc), when .. ": Your bounty card shows")
		local cr = rect(bc)
		ok(cr.h > 0, when .. ": control: the card has a height")
		local e = s.empty
		local parts = { { "the title", e.title }, { "the sub", e.sub } }
		for i, p in ipairs(e.bounty.picks) do parts[#parts + 1] = { "pick " .. i, p } end
		local covers = { { "Your bounty card", bc } }
		if s.gfRows and H.visible(s.gfRows) then covers[#covers + 1] = { "the Group Finder card", s.gfRows } end
		for _, cv in ipairs(covers) do
			local r = rect(cv[2])
			for _, p in ipairs(parts) do
				if H.visible(p[2]) then
					ok(not inter(r, rect(p[2])), when .. ": " .. cv[1] .. " overlaps " .. p[1])
				end
			end
		end
		-- the stack's title starts under the card, never above its bottom
		ok(rect(e.title).t <= cr.b, when .. ": the title starts under Your bounty card")
	end
	w:advance(2)
	clear("settled")
	UI.Refresh(true)
	w:advance(1)
	clear("after a redraw")
	ok(s.empty.title:GetText() == "Nobody summons to Gadgetzan right now", "the title keeps its words")
	H.textMetrics = nil
	T.clean(w)
end

local LATE = {
	{ "", {} },
	{ " (layout held to the end of a text refresh)", { held = true } },
	{ " (the card's measured height wrong)", { deferred = true } },
	{ " (window hidden while drawn, shown after)", { hidden = true } },
	{ " (the list 0 wide and high at the first layout)", { zero = true } },
}
for _, scale in ipairs({ 0.71, 1.0 }) do
	for _, l in ipairs(LATE) do
		local o = { gf = true, folded = true, scale = scale }
		for k, v in pairs(l[2]) do o[k] = v end
		test("bounty anchors (#317 run 5): Group Finder on, folded, UI scale " .. scale .. l[1] .. ": the card clears the title and the picks", function()
			run(o)
		end)
	end
end
-- Group Finder off, the card's measured height wrong: the stack stood where the measure said (failed on the base)
test("bounty anchors (#317 run 5): Group Finder off, folded, UI scale 0.71 (the card's measured height wrong): the card clears the title and the picks", function()
	run({ gf = false, folded = true, scale = 0.71, deferred = true })
end)
-- guards: unfolded with the Group Finder on, and folded with it off, already stood clear on the base (run 5 passed them)
for _, v in ipairs({ { gf = true, folded = false }, { gf = false, folded = true } }) do
	local name = (v.gf and "Group Finder on, unfolded" or "Group Finder off, folded")
	test("bounty anchors (#317 run 5) guard: " .. name .. " UI scale 0.71: the card clears the title and the picks", function()
		run({ gf = v.gf, folded = v.folded, scale = 0.71 })
	end)
	test("bounty anchors (#317 run 5) guard: " .. name .. " UI scale 0.71 (layout held): the card clears the title and the picks", function()
		run({ gf = v.gf, folded = v.folded, scale = 0.71, held = true })
	end)
end
