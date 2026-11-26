-- Round 26 B: Help's "Show a tip" row calls UI.Tips.ShowAgain (else ShowNow); it has a tooltip.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function open()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	return w, r, r.W
end

test("r26 B: Help has a Show a tip row that calls UI.Tips.ShowAgain once", function()
	local w, r, W = open()
	local n, s = 0, 0
	local m = W.Mod("UI.Tips")
	m.ShowAgain = function() n = n + 1 end
	m.ShowNow = function() s = s + 1 end
	W.UI.OpenHelp("settings")
	w:advance(1)
	local btn = W.UI.settings.help.tip
	ok(btn, "the row's button exists")
	ok(btn:GetScript("OnEnter"), "the button has a tooltip (T.Tip hooks OnEnter)")
	W.UI.settings.help.tip:GetScript("OnClick")(btn)
	eq(n, 1, "ShowAgain called once"); eq(s, 0, "ShowNow not used")
end)

test("r26 B: without ShowAgain the row falls back to ShowNow, and to nothing without UI.Tips", function()
	local w, r, W = open()
	local s = 0
	local m = W.Mod("UI.Tips")
	m.ShowAgain = nil
	m.ShowNow = function() s = s + 1 end
	W.UI.OpenHelp("settings")
	w:advance(1)
	local btn = W.UI.settings.help.tip
	btn:GetScript("OnClick")(btn)
	eq(s, 1)
	m.ShowNow = nil
	btn:GetScript("OnClick")(btn)
	eq(s, 1)
end)
