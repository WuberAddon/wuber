local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }

local function texts(f, out, seen)
	out, seen = out or {}, seen or {}
	if seen[f] then return out end
	seen[f] = true
	for _, r in ipairs({ f:GetRegions() }) do
		if r.GetText and r:GetText() == "Settings" and H.visible(r) then out[#out + 1] = r end
	end
	for _, c in ipairs({ f:GetChildren() }) do texts(c, out, seen) end
	return out
end

-- Promise (H24-02): the Report a bug sheet's top edge never cuts a page word, the big Settings title included, at either screen
for _, size in ipairs({ { 1024, 768 }, { 800, 600 } }) do
	test(("r50 c H24-02: the Report a bug sheet does not cut the big Settings title (%dx%d)"):format(size[1], size[2]), function()
		local w = T.newWorld()
		local r = T.rider(w, T.TESTCHAR, { screenW = size[1], screenH = size[2] })
		T.settle(w)
		local UI = r.W.UI
		UI.Toggle(true) w:advance(3)
		UI.OpenSettings() w:advance(3)
		local big = texts(UI.state.win)
		ok(#big > 0, "control: the big Settings title is drawn")
		ok(UI.Bug.Open(), "the report opens") w:advance(2)
		local card = H.rect(UI.Bug.frame.card)
		local cardTop = card.b + card.h
		for _, t in ipairs(big) do
			local tr = H.rect(t)
			ok(not (tr.b + tr.h > cardTop + 0.5 and tr.b < cardTop - 0.5), "the title is cut by the sheet's top edge")
		end
		T.clean(w)
	end)
end

-- guard: the sheet still stands over the page's rows below the header zone and ends at the tab bar
test("r50 c H24-02 guard: with no big title the sheet card starts at the header zone's foot", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1024, screenH = 768 })
	T.settle(w)
	local UI = r.W.UI
	UI.Toggle(true) w:advance(3)
	ok(UI.Bug.Open(), "the report opens") w:advance(2)
	local win, card = H.rect(UI.state.win), H.rect(UI.Bug.frame.card)
	local k = win.h / UI.state.win:GetHeight()
	local top = (win.b + win.h - (card.b + card.h)) / k
	ok(math.abs(top - 56) <= 0.6, "card top below the window top: " .. top)
	T.clean(w)
end)

-- Promise (R49-7): the report's dim never lies over the lifted big Drive button (strata FULLSCREEN_DIALOG, level above
-- the window's); the dim has no job over a button the player must reach
test("r50 c R49-7: the Report a bug dim stands under the lifted big Drive button", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 800, screenH = 600 })
	T.settle(w)
	local UI = r.W.UI
	UI.Toggle(true) w:advance(3)
	ok(UI.Bug.Open(), "the report opens") w:advance(2)
	local f = UI.Bug.frame
	for _, fr in ipairs({ f.holder, f, f.card }) do
		ok(STRATA[fr:GetFrameStrata()] < STRATA.FULLSCREEN_DIALOG, "strata of the sheet is under the Drive button's: " .. fr:GetFrameStrata())
	end
	T.clean(w)
end)

-- guard: the sheet stays over the window's own pages and tab bar
test("r50 c R49-7 guard: the Report a bug holder is still above the window", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local UI = r.W.UI
	UI.Toggle(true) w:advance(3)
	ok(UI.Bug.Open(), "the report opens") w:advance(2)
	ok(STRATA[UI.Bug.frame.holder:GetFrameStrata()] > STRATA[UI.state.win:GetFrameStrata()], "above the window's strata")
	T.clean(w)
end)

-- Promise (H24-11): a name Wuber knows only from the rank count is left out of the report
test("r50 c H24-11: a rider known only from the rank count is hidden in the report", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local W = r.W
	local c = W.Char()
	c.rank = { n = 1, seen = { Zandrilla = 99999 } }
	local text = W.UI.Bug.Report("Zandrilla whispered me")
	ok(not text:find("Zandrilla", 1, true), "the rank-only name is in the report")
	T.clean(w)
end)

-- guard: a name of a favourite is still hidden, and ordinary words stay
test("r50 c H24-11 guard: a favourite's name is still hidden and the note's other words stay", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local W = r.W
	W.db.favs = W.db.favs or {}
	W.db.favs["Quinnary-Argent"] = true
	local text = W.UI.Bug.Report("Quinnary-Argent failed my request")
	ok(not text:find("Quinnary", 1, true), "the favourite's name is in the report")
	ok(text:find("failed my request", 1, true), "the note's words stay")
	T.clean(w)
end)
