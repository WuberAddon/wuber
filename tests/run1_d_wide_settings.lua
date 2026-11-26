-- In-game run 1, item 12.2 (screenshot 165909): wide window, Settings opened over the Ride home. Characterises what the
-- fake game can see: the Settings page (title, back chevron, section list, rows) is inside the window and above the Ride
-- page in draw order, in both routes (Wide on for Ride first, and Settings opened folded). Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function inside(f, win)
	return f:GetLeft() >= win:GetLeft() - 0.5 and f:GetRight() <= win:GetRight() + 0.5
		and f:GetTop() <= win:GetTop() + 0.5 and f:GetBottom() >= win:GetBottom() - 0.5
end

local function topLevel(f)
	local m = f:GetFrameLevel() or 0
	for _, c in ipairs({ f:GetChildren() }) do m = math.max(m, topLevel(c)) end
	return m
end

local function openWide()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar", screenW = 1920, screenH = 1080, wide = true })
	r.wide = true
	T.settle(w)
	T.goOnline(d)
	w:advance(5)
	r.W.db.coach = true
	r.W.UI.Toggle(true)
	w:advance(3)
	return w, r
end

local function check(w, r)
	local UI = r.W.UI
	local ui = UI.state
	local st = r.W.Mod("UI.Settings.Rows").st
	ok(UI.Fold.IsUnfolded() and ui.win:GetWidth() > 700, "the window is wide: " .. ui.win:GetWidth())
	ok(st.panel:IsVisible(), "the Settings page is visible")
	ok(st.title:IsVisible() and inside(st.title, ui.win), "the title is visible and inside the window")
	ok(st.back:IsVisible() and inside(st.back, ui.win), "the back chevron is visible and inside the window")
	ok(st.nav and st.nav:IsVisible(), "the section list is visible")
	ok(st.clip:IsVisible() and inside(st.clip, ui.win), "the section's rows are inside the window")
	ok(st.panel:GetFrameLevel() > topLevel(UI.GetTab("Ride")), "the Settings page is drawn above everything of the Ride tab")
	ok(UI.Fold.Pane():IsShown(), "the side pane is up")
	ok(st.title:GetLeft() < UI.Fold.Pane():GetLeft(), "the title is in the left pane")
end

test("run1 d: wide window, Ride home unfolded, open Settings: title, back, list and rows are on screen above the Ride page", function()
	local w, r = openWide()
	local UI = r.W.UI
	if not UI.Fold.IsUnfolded() then UI.Fold.Toggle() w:advance(1) end
	UI.OpenSettings()
	w:advance(1)
	check(w, r)
	T.clean(w)
end)

test("run1 d: wide window, Settings opened from the folded phone: the same whole Settings page", function()
	local w, r = openWide()
	local UI = r.W.UI
	if UI.Fold.IsUnfolded() then UI.Fold.Toggle() w:advance(1) end
	ok(not UI.Fold.IsUnfolded(), "folded to start")
	UI.OpenSettings()
	w:advance(1)
	check(w, r)
	UI.CloseSettings()
	w:advance(1)
	ok(not r.W.Mod("UI.Settings.Rows").st.panel:IsShown(), "back closes it")
	T.clean(w)
end)
