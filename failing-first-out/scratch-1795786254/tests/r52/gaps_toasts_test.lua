-- Tests of UI.Toasts (Wuber/UI/Toasts.lua). Loaded by tests/run.lua with its helper table T.
-- Final home: tests/ui/toasts_test.lua; add it to the per-module list in tests/run.lua.
-- Pins: UI.Toast (nil or malformed text shows nothing, a repeat inside 2 s is not shown twice, one toast at a time,
-- Pins:   each kind stays its own number of seconds, the sticky portal toast is not pushed off by a lesser one);
-- Pins: the toast's look per kind (the '!' mark for warn and error, a glyph for the rest, an unknown kind looks like info);
-- Pins: a click runs the toast's action once and the toast is already gone when it runs; no action opens Wuber;
-- Pins: UI.UndoToast / UI.UndoPending (the Undo button and a click on the toast run it once; no function, no Undo);
-- Pins: UI.ChatBox, UI.ClearOfChat, UI.HudBoxes, UI.ClearOfHud (what counts as in the way, and where a box goes instead).
-- Why it matters to a player: toasts are how Wuber says "your driver accepted", "click the portal" and "3 settings reset".
-- If they broke, the rider would miss the portal call, see the same line twice or one over the chat box, or lose an Undo.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function world()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	T.settle(w)
	return w, r, r.W.UI
end

local function has(r, text)
	for _, t in ipairs(r:visibleTexts()) do if t == text then return true end end
	return false
end

local function overlaps(a, b) -- { l, r, b, t } boxes
	return a[1] < b[2] and a[2] > b[1] and a[3] < b[4] and a[4] > b[3]
end

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.toasts: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("UI.Toasts", "tests/ui/toasts_test.lua", {
		["UI.Toast"] = "function", ["UI.ToastPlace"] = "function", ["UI.ToastShowing"] = "function", ["UI.UndoToast"] = "function",
		["UI.UndoPending"] = "function", ["UI.ChatBox"] = "function", ["UI.ClearOfChat"] = "function", ["UI.HudBoxes"] = "function",
		["UI.ClearOfHud"] = "function",
	})
	ok(Mod, "W.Mod(\"UI.Toasts\")")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.toasts: no text, or text that is not a string, shows nothing", function()
	local w, r, UI = world()
	eq(UI.Toast(nil, "info"), nil, "nil text") -- Toasts.lua:417
	eq(UI.Toast({}, "info"), nil, "a table")
	eq(UI.Toast(false, "info"), nil, "false")
	ok(not UI.ToastShowing(), "no toast is up")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.toasts: the same line twice inside 2 s is one toast; after 2 s it shows again", function()
	local w, r, UI = world()
	local t1 = UI.Toast("Mia accepted - 50s to Undercity", "found")
	ok(t1, "shown")
	w:advance(1)
	local t2 = UI.Toast("Mia accepted - 50s to Undercity", "found")
	eq(t2, t1, "the same toast comes back, no second one") -- Toasts.lua:421-423
	w:advance(1.5) -- 2.5 s since it came up, still on screen (4 s)
	ok(UI.ToastShowing(), "control: still up")
	local t3 = UI.Toast("Mia accepted - 50s to Undercity", "found")
	ok(t3 and t3.at > t1.at, "a new showing after 2 s")
	w:advance(0.5)
	local n = 0
	for _, t in ipairs(r:visibleTexts()) do if t == "Mia accepted - 50s to Undercity" then n = n + 1 end end
	eq(n, 1, "one line on screen")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.toasts: a new toast replaces the one showing (one at a time)", function()
	local w, r, UI = world()
	UI.Toast("First line", "info")
	w:advance(0.5)
	UI.Toast("Second line", "found")
	w:advance(0.5)
	ok(has(r, "Second line"), "the new one shows")
	ok(not has(r, "First line"), "the old one is gone") -- Toasts.lua:429
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.toasts: each kind stays its own time: info 4 s, fav 6 s, portal 8 s", function()
	local w, r, UI = world()
	for _, c in ipairs({ { "info", 4 }, { "fav", 6 }, { "portal", 8 } }) do
		UI.Toast("A " .. c[1] .. " toast", c[1])
		w:advance(c[2] - 0.5)
		ok(UI.ToastShowing(), c[1] .. " still up just before " .. c[2] .. " s") -- Toasts.lua:217-243
		w:advance(1)
		ok(not UI.ToastShowing(), c[1] .. " gone after " .. c[2] .. " s")
		w:advance(3) -- clear of the 2 s repeat rule between kinds
	end
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.toasts: the portal toast is not pushed off by a lesser toast, but another portal toast replaces it", function()
	local w, r, UI = world()
	UI.Toast("Click the portal now", "portal")
	w:advance(2)
	eq(UI.Toast("Something minor", "info"), nil, "the lesser one is dropped") -- Toasts.lua:425-428
	eq(UI.Toast("Careful", "warn"), nil, "a warning too")
	w:advance(0.5)
	ok(has(r, "Click the portal now"), "the portal call stays")
	ok(not has(r, "Something minor"), "the lesser one never shows")
	local t = UI.Toast("Click the portal again", "portal")
	ok(t, "a second portal toast is allowed")
	w:advance(0.5)
	ok(has(r, "Click the portal again") and not has(r, "Click the portal now"), "it replaces the first")
	w:advance(8.5) -- the sticky time is over
	ok(UI.Toast("Now it shows", "info"), "after its 8 s a lesser toast shows again")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.toasts: warn and error carry a '!' mark, the others a glyph, an unknown kind looks like info", function()
	local w, r, UI = world()
	local t = UI.Toast("Careful there", "warn")
	eq(t.mark:GetText(), "!") -- Toasts.lua:225, 450
	ok(t.mark:IsShown() and not t.glyph:IsShown(), "mark, no glyph")
	w:advance(2.5)
	t = UI.Toast("Mia accepted", "found")
	ok(t.glyph:IsShown() and not t.mark:IsShown(), "found: a glyph")
	w:advance(2.5)
	t = UI.Toast("What kind is this", "bogus")
	ok(t, "an unknown kind still shows")
	ok(t.glyph:IsShown() and not t.mark:IsShown(), "looks like info: a glyph")
	eq(t.kind, "bogus", "the kind is kept as given")
	w:advance(2.5)
	t = UI.Toast("No kind at all")
	eq(t.kind, "info", "no kind is info") -- Toasts.lua:433
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.toasts: a click runs the toast's action once, with the toast already gone, and a follow-up toast stays", function()
	local w, r, UI = world()
	local calls, wasUp = 0, nil
	local t = UI.Toast("Open the driver", "found", function()
		calls = calls + 1
		wasUp = UI.ToastShowing()
		UI.Toast("Opened", "info")
	end)
	t:GetScript("OnClick")(t)
	eq(calls, 1, "the action ran once")
	eq(wasUp, false, "the clicked toast was already off the queue") -- Toasts.lua:365-366
	ok(UI.ToastShowing(), "the follow-up toast is up")
	w:advance(0.5)
	ok(has(r, "Opened"), "and visible")
	ok(not has(r, "Open the driver"), "the clicked one is gone")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.toasts: a click on a toast with no action opens Wuber", function()
	local w, r, UI = world()
	if UI.IsShown() then UI.Toggle(false) w:advance(1.5) end
	ok(not UI.IsShown(), "control: Wuber is closed")
	local t = UI.Toast("Just a note", "info")
	t:GetScript("OnClick")(t)
	w:advance(1)
	ok(UI.IsShown(), "the window opened") -- Toasts.lua:366
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.toasts: UndoToast's Undo button runs the undo once and takes the toast away", function()
	local w, r, UI = world()
	local n = 0
	local t = UI.UndoToast("3 settings reset.", function() n = n + 1 end)
	ok(t and t.undo and t.undo:IsShown(), "the toast has an Undo button") -- Toasts.lua:485-498
	ok(UI.UndoPending(), "an Undo is pending")
	w:advance(0.5)
	ok(has(r, "3 settings reset."), "the line shows")
	t.undo:GetScript("OnClick")(t.undo)
	eq(n, 1, "undone")
	ok(not UI.UndoPending(), "nothing left to undo")
	t.undo:GetScript("OnClick")(t.undo)
	eq(n, 1, "a second click does nothing")
	w:advance(0.5)
	ok(not UI.ToastShowing(), "the toast is gone")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.toasts: a click on the Undo toast itself undoes too; with no function there is no Undo", function()
	local w, r, UI = world()
	local n = 0
	local t = UI.UndoToast("1 setting reset.", function() n = n + 1 end)
	t:GetScript("OnClick")(t)
	eq(n, 1, "the toast's own click runs the undo") -- Toasts.lua:472-498
	ok(not UI.UndoPending())
	w:advance(3)
	t = UI.UndoToast("Nothing to undo", nil)
	ok(t, "still a toast")
	ok(not UI.UndoPending(), "but no Undo is pending")
	w:advance(0.5)
	ok(has(r, "Nothing to undo"), "its line shows")
	T.clean(w)
end)

local function placeChat(r, l, b, wd, h)
	local f = r.env.DEFAULT_CHAT_FRAME
	f:ClearAllPoints()
	f:SetPoint("BOTTOMLEFT", r.env.UIParent, "BOTTOMLEFT", l, b)
	f:SetSize(wd, h)
	f:Show()
	return f
end

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.toasts: ChatBox is the chat frame with its tab row; none when the chat is hidden", function()
	local w, r, UI = world()
	local f = placeChat(r, 32, 95, 430, 120)
	w:advance(0.5)
	local c, rc = UI.ChatBox(), H.rect(f)
	ok(c, "the box")
	ok(math.abs(c[1] - (rc.l - 4)) < 0.6 and math.abs(c[2] - (rc.l + rc.w + 4)) < 0.6, "4 each side") -- Toasts.lua:37, 67-80
	ok(math.abs(c[3] - (rc.b - 4)) < 0.6 and math.abs(c[4] - (rc.b + rc.h + 26)) < 0.6, "4 below, 26 above for the tabs")
	f:Hide()
	eq(UI.ChatBox(), nil, "a hidden chat is nothing to keep clear of")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.toasts: ClearOfChat moves a box off the chat frame, leaves a clear one and a nil one alone", function()
	local w, r, UI = world()
	local sw, sh = r.env.UIParent:GetWidth(), r.env.UIParent:GetHeight()
	placeChat(r, 32, 95, 430, 120)
	w:advance(0.5)
	local c = UI.ChatBox()
	local l, b, moved = UI.ClearOfChat(40, 100, 100, 50)
	eq(moved, true, "over the chat: it moves") -- Toasts.lua:90-110
	ok(not overlaps(c, { l, l + 100, b, b + 50 }), "the new place is clear of the chat")
	ok(l >= 0 and b >= 0 and l + 100 <= sw + 0.5 and b + 50 <= sh + 0.5, "and on the screen")
	local l2, b2, moved2 = UI.ClearOfChat(sw - 150, sh - 100, 100, 50)
	eq(l2, sw - 150)
	eq(b2, sh - 100)
	eq(moved2, false, "a clear box stays")
	local a, bb, m3 = UI.ClearOfChat(nil, nil, 10, 10)
	eq(a, nil)
	eq(bb, nil)
	eq(m3, false, "no place given: nothing to move")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.toasts: HudBoxes counts a shown bar, not a hidden one, not one that covers most of the screen", function()
	local w, r, UI = world()
	local env = r.env
	local sw, sh = env.UIParent:GetWidth(), env.UIParent:GetHeight()
	local before = #UI.HudBoxes()
	local bar = env.CreateFrame("Frame", "DaylightUIBar8", env.UIParent)
	bar:SetSize(500, 60)
	bar:SetPoint("BOTTOM", env.UIParent, "BOTTOM", 0, 0)
	bar:Show()
	ok(env.DaylightUIBar8, "control: the named frame is a global")
	eq(#UI.HudBoxes(), before + 1, "a shown bar counts") -- Toasts.lua:136-148
	bar:Hide()
	eq(#UI.HudBoxes(), before, "a hidden one does not")
	bar:Show()
	bar:SetSize(sw * 0.9, sh * 0.9)
	eq(#UI.HudBoxes(), before, "a holder over most of the screen is not a bar (0.4 of the screen)")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.toasts: ClearOfHud leaves a clear spot, moves off an action bar, and never lands on an avoid box", function()
	local w, r, UI = world()
	local env = r.env
	local sw, sh = env.UIParent:GetWidth(), env.UIParent:GetHeight()
	local l, b, moved, clear = UI.ClearOfHud(sw - 150, sh - 100, 100, 50)
	ok(l == sw - 150 and b == sh - 100 and moved == false and clear == true, "a clear spot stays") -- Toasts.lua:184-190
	local bar = env.CreateFrame("Frame", "DaylightUIBar8", env.UIParent)
	bar:SetSize(500, 60)
	bar:SetPoint("BOTTOM", env.UIParent, "BOTTOM", 0, 0)
	bar:Show()
	local bl = (sw - 500) / 2
	local barBox = { bl, bl + 500, 0, 60 }
	local nl, nb, m2, c2 = UI.ClearOfHud(sw / 2 - 50, 10, 100, 50)
	eq(m2, true, "over the bar: it moves")
	eq(c2, true, "and finds a clear place")
	ok(not overlaps(barBox, { nl, nl + 100, nb, nb + 50 }), "clear of the bar")
	-- an avoid box (the open phone) is never covered
	local avoid = { { sw - 200, sw, sh - 120, sh } }
	local al, ab, am = UI.ClearOfHud(sw - 150, sh - 100, 100, 50, avoid)
	eq(am, true, "a box over the phone moves")
	ok(not overlaps(avoid[1], { al, al + 100, ab, ab + 50 }), "and is clear of it")
	local a, bb, m3, c3 = UI.ClearOfHud(nil, nil, 10, 10)
	ok(a == nil and bb == nil and m3 == false and c3 == true, "no place given: nothing to do")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.toasts: with the window closed and nothing in the way the next toast goes to the top centre", function()
	local w, r, UI = world()
	if UI.IsShown() then UI.Toggle(false) end
	w:advance(1.5)
	local x, top = UI.ToastPlace()
	eq(x, 0, "x") -- Toasts.lua:250-253, as r34_j_toastplace_test
	eq(top, -18, "top")
	T.clean(w)
end)
