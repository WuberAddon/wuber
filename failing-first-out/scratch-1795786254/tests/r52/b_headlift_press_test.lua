local T = ...
local test = T.test
-- 2.4.2 audit #2: the sheet closes after the window's strata moved; the buttons follow the window
test("r52 B2: header buttons take the window's current strata when the last sheet closes", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	w:advance(15)
	local UI = c.W.UI
	UI.Toggle(true) w:advance(3)
	local K = c.W.Mod("UI.Kit")
	local btn = K.ui.close
	local win = K.ui.win
	UI.HeadAbove(true, "sheetA")
	assert(btn:GetFrameStrata() == "FULLSCREEN_DIALOG", "lifted")
	win:SetFrameStrata("FULLSCREEN_DIALOG")
	K.ui.strata = "FULLSCREEN_DIALOG"
	UI.HeadAbove(false, "sheetA")
	assert(btn:GetFrameStrata() == win:GetFrameStrata(), "close X strata " .. btn:GetFrameStrata() .. " window " .. win:GetFrameStrata())
	T.clean(w)
end)
-- guard: window strata unchanged, buttons return to it
test("r52 B2 guard: strata unchanged, buttons return to the window's", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	w:advance(15)
	local UI = c.W.UI
	UI.Toggle(true) w:advance(3)
	local K = c.W.Mod("UI.Kit")
	local btn, win = K.ui.close, K.ui.win
	local was = btn:GetFrameStrata()
	UI.HeadAbove(true, "s") UI.HeadAbove(false, "s")
	assert(btn:GetFrameStrata() == was and was == win:GetFrameStrata(), "back to " .. was .. ", is " .. btn:GetFrameStrata())
	T.clean(w)
end)
-- promise #4: every close X keeps its pressed fill (the cards called T.Press(x) with no opts and wiped it)
test("r52 B4: the What's New card's close X shows its pressed fill", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	w:advance(15)
	local x = c.W.Mod("UI.WhatsNew").Card().close
	assert(x, "control: it has a close X")
	assert(x.wuberPress and x.wuberPress.fill, "the close X lost its pressed fill")
	T.clean(w)
end)
-- guard: the T.Press contract itself (the in-flight card's X is the same sheet round button, pressed again with no options)
test("r52 B4: a round button pressed again with no options keeps its fill; explicit options still replace", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	w:advance(15)
	local Th = c.W.Theme
	local b = Th.RoundButton(c.env.UIParent, "close", 28, "card")
	local fill = b.wuberPress and b.wuberPress.fill
	assert(fill, "control: a round button has a fill")
	Th.Press(b)
	assert(b.wuberPress.fill == fill, "T.Press(b) with no options wiped the fill")
	Th.Press(b, { fill = fill, pressed = "line" })
	assert(b.wuberPress.pressed == "line", "guard: explicit options still replace")
	T.clean(w)
end)
