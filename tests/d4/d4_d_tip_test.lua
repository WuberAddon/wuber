-- Design round 4, group D (audit item 17): Wuber's own tooltip, the frame WuberTip (Theme.Widgets: T.TipShow, T.TipHide,
-- T.TipOwner; T.Tip draws on it). The game's tooltip is not used for Wuber's tips and is not changed.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local S = H.state

local LONG = "A long sentence about what this control does, with enough words in it that no tip could hold it on one line of its card."

local function rects(c, owner)
	local card = c.env.WuberTip
	return H.rect(card), H.rect(owner), H.rect(c.env.UIParent)
end
-- how much two harness rects ({ l, b, w, h }) share
local function shared(a, b)
	local w = math.min(a.l + a.w, b.l + b.w) - math.max(a.l, b.l)
	local h = math.min(a.b + a.h, b.b + b.h) - math.max(a.b, b.b)
	return w, h
end
local function clearOf(a, b)
	local w, h = shared(a, b)
	return not (w > 0.5 and h > 0.5)
end
local function onScreen(r, up)
	return r.l >= -0.5 and r.b >= -0.5 and r.l + r.w <= up.w + 0.5 and r.b + r.h <= up.h + 0.5
end
local function owner(c, point, x, y, w, h)
	local f = c.env.CreateFrame("Button", nil, c.env.UIParent)
	f:SetPoint(point, c.env.UIParent, point, x or 0, y or 0)
	f:SetSize(w or 120, h or 30)
	return f
end
-- the game's tooltip with every call that would draw a tip on it counted
local function watchGame(c)
	local gt = c.env.GameTooltip
	local used = {}
	for _, m in ipairs({ "SetOwner", "AddLine", "AddDoubleLine", "SetText", "Show", "SetFrameStrata", "SetAlpha", "ClearAllPoints", "SetPoint" }) do
		local real = gt[m]
		gt[m] = function(...)
			used[#used + 1] = m
			return real(...)
		end
	end
	return used
end

test("d4 d: T.Tip draws on Wuber's own card WuberTip: card2, opaque, on the tooltip layer, no mouse, title and line in the theme's sizes and colours", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(5)
	local env, Th = c.env, c.W.Theme
	local used = watchGame(c)
	local f = owner(c, "CENTER")
	Th.Tip(f, "A title", "One plain sentence.")
	S[f].scripts.OnEnter(f)
	local card = env.WuberTip
	ok(card, "the frame WuberTip exists")
	if card then
		ok(H.visible(card), "it shows")
		eq(card:GetParent(), env.UIParent, "parented to UIParent")
		eq(card:GetFrameStrata(), "TOOLTIP", "on the tooltip layer")
		ok(not card:IsMouseEnabled(), "it never takes the mouse")
		eq(Th.TipOwner(), f, "T.TipOwner names the control")
		eq(card.title:GetText(), "A title", "the title")
		eq(card.lines[1]:GetText(), "One plain sentence.", "the line")
		local r, g, b = card.title:GetTextColor()
		local wr, wg, wb = Th.RGB("white")
		ok(math.abs(r - wr) + math.abs(g - wg) + math.abs(b - wb) < 0.01, "the title is white")
		r, g, b = card.lines[1]:GetTextColor()
		local mr, mg, mb = Th.RGB("muted")
		ok(math.abs(r - mr) + math.abs(g - mg) + math.abs(b - mb) < 0.01, "the line is the muted grey")
		eq(card.title.wuberPx, Th.SIZE.body, "the title is body size")
		eq(card.title.wuberWeight, "medium", "the title is medium")
		eq(card.lines[1].wuberPx, Th.SIZE.sub, "the line is sub size")
		eq(card.lines[1].wuberWeight, "regular", "the line is regular")
		-- the fill: the card2 token, solid
		local fr, fg, fb, fa = Th.RGB("raised")
		eq(fa, 1, "card2 is a solid colour")
		ok(card.fill and card.fill.parts, "a rounded fill")
		local part = card.fill and card.fill.parts and (card.fill.parts.C or card.fill.parts.TL)
		if part then
			local pr, pg, pb, pa = part:GetVertexColor()
			ok(math.abs(pr - fr) + math.abs(pg - fg) + math.abs(pb - fb) < 0.01, "the fill is card2")
			eq(pa, 1, "the fill is opaque")
		end
		w:advance(1)
		eq(card:GetAlpha(), 1, "once faded in it is not see-through")
		eq(card:GetScale(), 1, "never scaled")
		S[f].scripts.OnLeave(f)
		ok(not H.visible(card), "hidden at once when the mouse leaves")
		eq(Th.TipOwner(), nil, "no owner then")
	end
	eq(#used, 0, "the game's tooltip is not used (" .. table.concat(used, ", ") .. ")")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("d4 d: the tip card fades in over 0.12 to 0.16 s; with Reduce motion it is there at once", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(5)
	local env, Th = c.env, c.W.Theme
	local f = owner(c, "CENTER")
	Th.Tip(f, "A title", "One plain sentence.")
	S[f].scripts.OnEnter(f)
	local card = env.WuberTip
	ok(card and card:GetAlpha() < 1, "it starts see-through (a fade)")
	w:advance(0.05)
	ok(card:GetAlpha() > 0 and card:GetAlpha() < 1, "part of the way after 0.05 s")
	w:advance(0.12)
	eq(card:GetAlpha(), 1, "whole by 0.17 s")
	S[f].scripts.OnLeave(f)
	c.W.db.reduceMotion = true
	S[f].scripts.OnEnter(f)
	eq(card:GetAlpha(), 1, "Reduce motion: whole at once")
	S[f].scripts.OnLeave(f)
	c.W.db.reduceMotion = nil
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("d4 d: the tip stands beside its owner, never on it, wholly on the screen: four edges, four corners and the middle", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(5)
	local env, Th = c.env, c.W.Theme
	local spots = {
		{ "the middle", "CENTER", 0, 0, "right" }, { "the right edge", "RIGHT", -4, 0, "left" }, { "the left edge", "LEFT", 4, 0, "right" },
		{ "the top edge", "TOP", 0, -4, "right" }, { "the bottom edge", "BOTTOM", 0, 4, "right" },
		{ "the top right corner", "TOPRIGHT", -4, -4, "left" }, { "the bottom left corner", "BOTTOMLEFT", 4, 4, "right" },
		{ "the top left corner", "TOPLEFT", 4, -4, "right" }, { "the bottom right corner", "BOTTOMRIGHT", -4, -4 + 8, "left" },
	}
	for _, words in ipairs({ "Words.", LONG }) do
		for _, s in ipairs(spots) do
			local f = owner(c, s[2], s[3], s[4])
			Th.Tip(f, "A title", words)
			S[f].scripts.OnEnter(f)
			local card = env.WuberTip
			local cr, orr, up = rects(c, f)
			ok(onScreen(cr, up), ("%s: wholly on the screen (%.0f, %.0f, %.0f x %.0f)"):format(s[1], cr.l, cr.b, cr.w, cr.h))
			ok(clearOf(cr, orr), s[1] .. ": not on its owner")
			eq(card.side, s[5], s[1] .. ": the side it took")
			if card.side == "right" then ok(math.abs(cr.l - (orr.l + orr.w) - 8) <= 1, s[1] .. ": 8 clear of the owner") end
			if card.side == "left" then ok(math.abs(orr.l - (cr.l + cr.w) - 8) <= 1, s[1] .. ": 8 clear of the owner") end
			S[f].scripts.OnLeave(f)
		end
	end
	-- an owner as wide as the screen: no room beside it, so above (or below at the top)
	local bar = owner(c, "CENTER", 0, 0, S[env.UIParent].w - 10, 30)
	Th.Tip(bar, "A title", LONG)
	S[bar].scripts.OnEnter(bar)
	local cr, orr, up = rects(c, bar)
	eq(env.WuberTip.side, "above", "a full-width owner: above it")
	ok(onScreen(cr, up) and clearOf(cr, orr), "a full-width owner: on the screen and not on it")
	S[bar].scripts.OnLeave(bar)
	local topBar = owner(c, "TOP", 0, -2, S[env.UIParent].w - 10, 30)
	Th.Tip(topBar, "A title", LONG)
	S[topBar].scripts.OnEnter(topBar)
	cr, orr, up = rects(c, topBar)
	eq(env.WuberTip.side, "below", "a full-width owner at the top: below it")
	ok(onScreen(cr, up) and clearOf(cr, orr), "a full-width owner at the top: on the screen and not on it")
	S[topBar].scripts.OnLeave(topBar)
	-- an owner that fills the screen: nowhere is clear, the card is still on the screen
	local all = owner(c, "CENTER", 0, 0, S[env.UIParent].w, S[env.UIParent].h)
	Th.Tip(all, "A title", LONG)
	S[all].scripts.OnEnter(all)
	cr, orr, up = rects(c, all)
	ok(onScreen(cr, up), "an owner that fills the screen: the card stays on the screen")
	S[all].scripts.OnLeave(all)
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("d4 d: T.Tip's anchor is a preference: the side asked for when it fits, the next one when it does not", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(5)
	local env, Th = c.env, c.W.Theme
	local function side(point, x, y, anchor)
		local f = owner(c, point, x, y)
		Th.Tip(f, "A title", "Words.", anchor)
		S[f].scripts.OnEnter(f)
		local s = env.WuberTip.side
		local cr, orr, up = rects(c, f)
		ok(onScreen(cr, up) and clearOf(cr, orr), tostring(anchor) .. " at " .. point .. ": on the screen, not on its owner")
		S[f].scripts.OnLeave(f)
		return s
	end
	eq(side("CENTER", 0, 0, nil), "right", "no anchor: right")
	eq(side("CENTER", 0, 0, "ANCHOR_RIGHT"), "right", "ANCHOR_RIGHT: right")
	eq(side("CENTER", 0, 0, "ANCHOR_LEFT"), "left", "ANCHOR_LEFT: left")
	eq(side("CENTER", 0, 0, "ANCHOR_TOP"), "above", "ANCHOR_TOP: above")
	eq(side("CENTER", 0, 0, "ANCHOR_TOPLEFT"), "above", "ANCHOR_TOPLEFT: above")
	eq(side("CENTER", 0, 0, "ANCHOR_BOTTOMRIGHT"), "below", "ANCHOR_BOTTOMRIGHT: below")
	eq(side("LEFT", 4, 0, "ANCHOR_LEFT"), "right", "ANCHOR_LEFT at the left edge: right")
	eq(side("TOP", 0, -4, "ANCHOR_TOP"), "right", "ANCHOR_TOP at the top edge: the next side that fits")
	eq(side("BOTTOM", 0, 4, "ANCHOR_BOTTOM"), "right", "ANCHOR_BOTTOM at the bottom edge: the next side that fits")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("d4 d: a long tip wraps at 240, a long single word widens the card, and no text is cut or outside the card", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(5)
	local env, Th = c.env, c.W.Theme
	local f = owner(c, "CENTER")
	local function inCard(card, what)
		local cr = H.rect(card)
		local texts = { card.title }
		for _, fs in ipairs(card.lines) do if fs:IsShown() then texts[#texts + 1] = fs end end
		local sum = 0
		for i, fs in ipairs(texts) do
			local r = H.rect(fs)
			ok(r.l >= cr.l + 12 - 0.5 and r.l + r.w <= cr.l + cr.w - 12 + 0.5, what .. ": text " .. i .. " is 12 inside the card's sides")
			ok(r.b >= cr.b + 12 - 0.5 and r.b + r.h <= cr.b + cr.h - 12 + 0.5 or fs:GetStringHeight() <= r.h + 0.5, what .. ": text " .. i .. " is inside the card")
			ok(fs:CanWordWrap(), what .. ": text " .. i .. " may wrap")
			eq(fs:GetMaxLines() or 0, 0, what .. ": text " .. i .. " has no limit on its lines")
			ok(not fs:IsTruncated(), what .. ": text " .. i .. " is not cut")
			sum = sum + fs:GetStringHeight()
		end
		ok(cr.h >= sum + 24 - 0.5, ("%s: the card is as tall as its texts and 12 above and below (%.0f for %.0f)"):format(what, cr.h, sum))
		return cr, texts
	end
	Th.Tip(f, "A title", "Short.")
	S[f].scripts.OnEnter(f)
	local card = env.WuberTip
	local cr = inCard(card, "short")
	ok(cr.w < 240, ("a short tip is as narrow as its words (%.0f)"):format(cr.w))
	S[f].scripts.OnLeave(f)
	Th.Tip(f, "A title", LONG)
	S[f].scripts.OnEnter(f)
	cr = inCard(card, "long")
	ok(cr.w <= 240 + 24 + 1.5 and cr.w >= 240, ("a long tip's text is 240 wide, the card 264 (%.0f)"):format(cr.w))
	ok(math.abs(card.lines[1]:GetWidth() - 240) <= 1.5, "the line wraps at 240")
	S[f].scripts.OnLeave(f)
	local word = ("Pneumonoultramicroscopic"):rep(3)
	Th.Tip(f, "A title", word .. " and more words")
	S[f].scripts.OnEnter(f)
	cr = inCard(card, "long word")
	ok(cr.w > 264, ("one long word: the card is wider than 264 (%.0f)"):format(cr.w))
	ok(card.lines[1]:GetWidth() >= Th.MeasureText(word, "sub", "regular") - 0.5, "as wide as the word")
	S[f].scripts.OnLeave(f)
	-- lines: a list, each a string or { text, token }; an empty one is left out; an unknown token is the muted grey
	Th.TipShow(f, "Several", { "one", { "two", "gold" }, "", { "three", "no such token" }, { "four", "glow" } })
	inCard(card, "several")
	local got = {}
	for _, fs in ipairs(card.lines) do if fs:IsShown() then got[#got + 1] = fs:GetText() end end
	eq(table.concat(got, "|"), "one|two|three|four", "its lines in order")
	local r, g, b = card.lines[2]:GetTextColor()
	local gr, gg, gb = Th.RGB("gold")
	ok(math.abs(r - gr) + math.abs(g - gg) + math.abs(b - gb) < 0.01, "a line in a token's colour")
	r, g, b = card.lines[3]:GetTextColor()
	local mr, mg, mb = Th.RGB("muted")
	ok(math.abs(r - mr) + math.abs(g - mg) + math.abs(b - mb) < 0.01, "an unknown token: the muted grey")
	-- the lines stand under each other with the theme's line spacing between them
	local a1, a2 = H.rect(card.lines[1]), H.rect(card.lines[2])
	ok(math.abs((a1.b - (a2.b + a2.h)) - Th.Spacing("sub")) <= 1, "T.Spacing between two lines")
	Th.TipShow(f, "Fewer", "one")
	ok(not card.lines[2]:IsShown(), "a shorter tip hides the lines it does not use")
	Th.TipHide(owner(c, "LEFT"))
	ok(H.visible(card), "T.TipHide of another frame leaves it")
	Th.TipHide(f)
	ok(not H.visible(card), "T.TipHide of its owner hides it")
	eq(Th.TipShow(f, "", "words"), nil, "no title: no tip")
	ok(not H.visible(card), "and nothing shows")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("d4 d: the tip goes when its owner hides, and T.RefreshTip changes the words in place", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(5)
	local env, Th = c.env, c.W.Theme
	local f = owner(c, "CENTER")
	local words = "First."
	Th.Tip(f, "A title", function() return words end)
	S[f].scripts.OnEnter(f)
	local card = env.WuberTip
	w:advance(1)
	words = "Second."
	Th.RefreshTip(f)
	eq(card.lines[1]:GetText(), "Second.", "the new words")
	eq(card:GetAlpha(), 1, "no new fade for the same owner")
	-- the owner moves under the tip (a page that slides in, a list that scrolls): the tip is beside it again
	local before = H.rect(card)
	f:ClearAllPoints()
	f:SetPoint("CENTER", env.UIParent, "CENTER", 200, 120)
	w:advance(0.05)
	local cr, orr, up = rects(c, f)
	ok(math.abs(cr.l - before.l - 200) <= 1 and math.abs(cr.b - before.b - 120) <= 1, "it follows its owner")
	ok(onScreen(cr, up) and clearOf(cr, orr), "still beside it and on the screen")
	f:Hide()
	ok(not H.visible(card), "gone with its owner (OnHide)")
	-- an owner whose parent hides, with no script of its own run on the card's side
	local holder = env.CreateFrame("Frame", nil, env.UIParent)
	holder:SetAllPoints(env.UIParent)
	local g = env.CreateFrame("Button", nil, holder)
	g:SetPoint("CENTER", holder, "CENTER", 0, 0)
	g:SetSize(80, 30)
	Th.TipShow(g, "By hand", "A tip shown through T.TipShow.")
	ok(H.visible(card), "shown by hand")
	holder:Hide()
	w:advance(0.1)
	ok(not H.visible(card), "gone once its owner is no longer visible")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

-- every control of the window that has a tip, hovered in turn
local function sweep(c, what)
	local env = c.env
	local n, bad = 0, {}
	local up = H.rect(env.UIParent)
	for _, f in ipairs(c.widgets) do
		local s = S[f]
		if s and s.kind == "frame" and f.wuberTip and H.visible(f) and s.scripts and s.scripts.OnEnter and s.scripts.OnLeave then
			local orr = H.rect(f)
			if orr and orr.w > 0 and orr.h > 0 and orr.w < up.w / 2 and orr.h < up.h / 2 then
				s.scripts.OnEnter(f)
				local card = env.WuberTip
				if card and H.visible(card) and card.owner == f then
					n = n + 1
					local cr = H.rect(card)
					if not onScreen(cr, up) then bad[#bad + 1] = tostring(card.title:GetText()) .. ": off the screen" end
					if not clearOf(cr, orr) then bad[#bad + 1] = tostring(card.title:GetText()) .. ": on its owner" end
				end
				s.scripts.OnLeave(f)
			end
		end
	end
	ok(n >= 5, what .. ": tips were shown (" .. n .. ")")
	eq(#bad, 0, what .. ": every tip is on the screen and beside its control (" .. table.concat(bad, "; ") .. ")")
end

test("d4 d: every tip of the window stands beside its control and on the screen, folded and unfolded, in the middle and at the screen's edges", function()
	for _, wide in ipairs({ false, true }) do
		local w = T.newWorld()
		local c = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
		c.wide = wide
		T.settle(w)
		c.W.db.coach = true
		c.W.UI.Toggle(true)
		w:advance(3)
		local win = c.env.WuberFrame
		ok(win and H.visible(win), "the window is open")
		local name = wide and "unfolded" or "folded"
		sweep(c, name .. ", where it opens")
		for _, at in ipairs({ { "TOPLEFT", 0, 0 }, { "TOPRIGHT", 0, 0 }, { "BOTTOMLEFT", 0, 0 }, { "BOTTOMRIGHT", 0, 0 } }) do
			win:ClearAllPoints()
			win:SetPoint(at[1], c.env.UIParent, at[1], at[2], at[3])
			sweep(c, name .. ", window at " .. at[1])
		end
		eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
		T.clean(w)
	end
end)

test("d4 d: the tips built by hand (minimap button, big button) are the same card, with their words and lines, and never the game's tooltip", function()
	local w = T.newWorld()
	local c = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	w:advance(5)
	local env, Th = c.env, c.W.Theme
	local used = watchGame(c)
	local mini, big = env.WuberMinimapButton, env.WuberDriveButton
	ok(mini and big, "both buttons exist")
	S[mini].scripts.OnEnter(mini)
	local card = env.WuberTip
	ok(card and H.visible(card), "the minimap button's tip is the card")
	eq(card.title:GetText(), "Wuber", "its title")
	ok(tostring(card.lines[1]:GetText()):find("open now", 1, true), "its first line: drivers open now")
	local last
	for _, fs in ipairs(card.lines) do if fs:IsShown() then last = fs:GetText() end end
	ok(tostring(last):find("Left-click: open or close.", 1, true), "its last line: what the clicks do")
	local cr, orr, up = rects(c, mini)
	ok(onScreen(cr, up) and clearOf(cr, orr), "beside the minimap button, on the screen")
	S[mini].scripts.OnLeave(mini)
	ok(not H.visible(card), "hidden on leave")
	local shownBefore, pointsBefore = big:IsShown(), big:GetNumPoints()
	S[big].scripts.OnEnter(big)
	ok(H.visible(card), "the big button's tip is the card")
	eq(Th.TipOwner(), big, "its owner is the big button")
	ok(#tostring(card.title:GetText()) > 0, "it has a title")
	ok(card.lines[1]:IsShown() and card.lines[2]:IsShown(), "and at least two lines")
	ok(tostring(card.lines[2]:GetText()):find("Shift-drag moves it when it floats.", 1, true), "the key line's words are as they were")
	ok(card:GetParent() == env.UIParent and not card:IsProtected(), "the card is not a secure frame and not the button's child")
	S[big].scripts.OnLeave(big)
	ok(not H.visible(card), "hidden on leave")
	eq(big:IsShown(), shownBefore, "the big button itself is not shown or hidden by its tip")
	eq(big:GetNumPoints(), pointsBefore, "nor moved")
	eq(#used, 0, "the game's tooltip is not used (" .. table.concat(used, ", ") .. ")")
	eq(#w.violations, 0, "violations (" .. table.concat(w.violations, "; ") .. ")")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("d4 d: the fake game answers 'what does this tip say' from the card (the game tooltip's state mirrors it), and a real game tooltip takes it back", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(5)
	local env, Th = c.env, c.W.Theme
	local gt = env.GameTooltip
	local f = owner(c, "CENTER")
	Th.TipShow(f, "A title", { "One.", { "Two.", "gold" } }, "ANCHOR_LEFT")
	eq(table.concat(S[gt].tipLines, "|"), "A title|One.|Two.", "the lines the card shows")
	eq(S[gt].owner, f, "its owner")
	eq(S[gt].shown, true, "shown")
	eq(S[gt].wuberMirror, env.WuberTip, "marked as a copy of the card")
	local gr = Th.RGB("gold")
	ok(math.abs(S[gt].tipMeta[3][1] - gr) < 0.01, "a line's colour")
	eq(env.GameTooltipTextLeft1:GetText(), "A title", "the game's line strings say the same")
	Th.TipHide(f)
	eq(S[gt].shown, false, "hidden with the card")
	eq(S[gt].wuberMirror, nil, "no copy any more")
	gt:SetOwner(env.UIParent, "ANCHOR_CURSOR")
	gt:AddLine("The game's own")
	gt:Show()
	eq(S[gt].wuberMirror, nil, "the game's own tooltip is no copy")
	eq(table.concat(S[gt].tipLines, "|"), "The game's own", "and says what the game put on it")
	gt:Hide()
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("d4 d: check.lua rule 11 fails on GameTooltip in a Wuber file, except the unit-tooltip hook in FX/Nameplates.lua", function()
	local scan = T.CHECK.scanGameTip
	ok(type(scan) == "function", "check.lua has the rule")
	if type(scan) ~= "function" then return end
	local old = "local function tip(self)\n\tGameTooltip:SetOwner(self, \"ANCHOR_LEFT\")\n\tGameTooltip:AddLine(\"Wuber\")\n\tGameTooltip:Show()\nend\n"
	local line, n, max = scan("UI/Minimap.lua", old)
	eq(line, 2, "a tip drawn on the game's tooltip: the first line that names it")
	eq(n, 3, "named three times")
	eq(max, 0, "none allowed there")
	eq(scan("UI/Minimap.lua", "-- GameTooltip in a comment\nlocal x = \"GameTooltipTextLeft\"\n"), nil, "a comment and another name do not count")
	eq(scan("Theme/Widgets.lua", "local gt = GameTooltip\n") ~= nil, true, "the theme may not name it either")
	local n2 = 0
	for _ in pairs(T.CHECK.TIP_ALLOW) do n2 = n2 + 1 end
	eq(n2, 1, "one file on the allow-list")
	ok(T.CHECK.TIP_ALLOW["FX/Nameplates.lua"], "FX/Nameplates.lua: the game's unit tooltip")
	-- today's files pass, and Nameplates uses no more than its allowance
	local root = T.root or H.root
	for _, file in ipairs({ "Theme/Widgets.lua", "UI/Minimap.lua", "UI/Map/Map.lua", "UI/Map/Pins.lua", "UI/Rider/HomeMap.lua", "Drive/Button.lua", "FX/Nameplates.lua" }) do
		local fh = io.open(root .. "/Wuber/" .. file, "rb")
		ok(fh, file .. " can be read")
		if fh then
			local src = fh:read("*a")
			fh:close()
			eq(scan(file, src), nil, file .. " passes")
		end
	end
end)

test("d4 d: the layout rule for the tip card: on its owner or off the screen is a 'tooltip' problem, beside it is none", function()
	local root = T.root or H.root
	local E = assert(loadfile(root .. "/tests/layout/engine.lua"))(H)
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(5)
	local env, Th = c.env, c.W.Theme
	local f = owner(c, "CENTER")
	Th.TipShow(f, "A title", "Words.")
	eq(#E.tipCard(c), 0, "beside its owner: fine")
	local card = env.WuberTip
	card:ClearAllPoints()
	card:SetPoint("CENTER", f, "CENTER", 0, 0)
	local got = E.tipCard(c)
	eq(#got, 1, "on its owner: one problem")
	ok(got[1] and got[1].detail:find("covers what it explains", 1, true), "it says so")
	card:ClearAllPoints()
	card:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", -30, 300)
	got = E.tipCard(c)
	eq(#got, 1, "off the screen: one problem")
	ok(got[1] and got[1].detail:find("off the screen", 1, true), "it says so")
	Th.TipHide(f)
	eq(#E.tipCard(c), 0, "no tip: nothing")
	T.clean(w)
end)
