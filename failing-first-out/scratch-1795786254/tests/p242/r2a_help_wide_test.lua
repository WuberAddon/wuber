-- p242 r2 group A (H24-07, the author said yes for 2.4.2): Help unfolded used the folded 360-wide page on the left and
-- left the right of the unfolded pane empty. Promise swept: unfolded, the Help page's title, cards, text, address box and
-- end rows use the whole unfolded pane (the same 16 margins as folded), the text wraps again to the new width (nothing
-- cut: each paragraph's height fits its lines), the scroll reaches the "Report a bug" row and the footer, folded Help is
-- unchanged, and folding or unfolding with Help open lays it out both ways. Words are never shortened.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function setup(wide)
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar", screenW = 1920, screenH = 1080, wide = true })
	c.wide = true -- (the harness keeps tests folded unless they ask for room)
	T.settle(w)
	w:advance(5)
	c.W.db.coach = true
	local UI = c.W.UI
	UI.Toggle(true)
	w:advance(3)
	UI.OpenSettings()
	w:advance(2)
	if (UI.Fold.IsUnfolded() and true or false) ~= wide then UI.Fold.Toggle() w:advance(2) end
	return w, c, UI
end

local function fit(UI, label, paneW)
	local st = UI.settings.help
	local want = paneW - 32
	ok(st.panel:IsShown(), label .. ": Help shows")
	eq(st.content:GetWidth(), paneW, label .. ": the page is the pane wide")
	for i, card in ipairs(st.cards) do
		eq(card:GetWidth(), want, label .. ": card " .. i .. " is the pane less the margins")
	end
	eq(st.bugRow:GetWidth(), want, label .. ": the Report a bug row is the pane less the margins")
	-- every paragraph runs to the new margin and its height holds its lines
	local widest = 0
	for _, e in ipairs(st.texts) do
		ok(e.fs:GetWidth() >= (e.room or 0) - 0.5, label .. ": room kept")
		if e.room > widest then widest = e.room end
		ok(e.h >= e.lines * e.px, label .. ": height holds the lines: " .. e.text:sub(1, 24))
	end
	ok(widest >= want - 140, label .. ": text uses the width (widest room " .. widest .. ")")
	-- the scroll reaches the end: the page height less the view is the scroll range, and the Report a bug row ends inside it
	local clipH = st.clip:GetHeight()
	eq(st.scrollMax, math.max(0, st.height - clipH), label .. ": the scroll range follows the page")
	local _, _, _, _, oy = st.bugRow:GetPoint(1)
	ok(-oy + st.bugRow:GetHeight() <= st.height, label .. ": the Report a bug row is inside the page")
	ok(st.bug:IsVisible(), label .. ": Report a bug shows")
end

test("p242 r2a: H24-07: unfolded Help uses the whole unfolded pane, wraps again, scrolls to the end", function()
	local w, c, UI = setup(true)
	UI.OpenHelp("settings")
	w:advance(2)
	fit(UI, "unfolded", 720)
	T.clean(w)
end)

-- guard: folded Help is the 360 page as before (passes on the base)
test("p242 r2a: folded Help is unchanged (360 wide, 16 margins)", function()
	local w, c, UI = setup(false)
	UI.OpenHelp("settings")
	w:advance(2)
	fit(UI, "folded", 360)
	T.clean(w)
end)

test("p242 r2a: fold and unfold with Help open lays it out both ways", function()
	local w, c, UI = setup(false)
	UI.OpenHelp("settings")
	w:advance(2)
	ok(not UI.Fold.IsUnfolded(), "starts folded")
	local hs = UI.settings.help
	local foldedH = hs.height
	for round = 1, 2 do
		UI.Fold.Toggle()
		w:advance(3)
		fit(UI, "unfolded " .. round, 720)
		ok(hs.height < foldedH, "wider text is shorter (" .. hs.height .. " < " .. foldedH .. ")")
		UI.Fold.Toggle()
		w:advance(3)
		fit(UI, "folded again " .. round, 360)
		eq(hs.height, foldedH, "folded again: the same height as the first time")
	end
	T.clean(w)
end)

-- guard: the footer shows in both widths (passes on the base)
test("p242 r2a: the footer shows in both widths", function()
	for _, wide in ipairs({ false, true }) do
		local w, c, UI = setup(wide)
		UI.OpenHelp("settings")
		w:advance(2)
		ok(#c:findText("never sends anything in chat without your click", false, true) > 0, "footer shown, wide=" .. tostring(wide))
		T.clean(w)
	end
end)
