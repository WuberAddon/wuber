local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
-- Skip the bird card: never under the Wuber window (HUNT-02). Mod.Place is called with a
-- map and a window that cover the strip beside the map.
local function box(l, b, w, h, strata, level)
	local f = { l = l, b = b, w = w, h = h, strata = strata, level = level or 1, shown = true }
	function f.GetLeft() return f.l end
	function f.GetRight() return f.l + f.w end
	function f.GetBottom() return f.b end
	function f.GetTop() return f.b + f.h end
	function f.GetEffectiveScale() return 1 end
	function f.IsShown() return f.shown end
	function f.GetFrameStrata() return f.strata end
	function f.GetFrameLevel() return f.level end
	function f.SetFrameStrata(self, s) f.strata = s end
	function f.SetFrameLevel(self, n) f.level = n end
	function f.ClearAllPoints() end
	function f.SetPoint(self, ...) f.pt = { ... } end
	return f
end
test("r30 d: the Skip the bird card is above the Wuber window when no spot is clear of it", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local Bird = r.W.Mod("UI.Bird")
	local sw, sh = 1365, 768
	-- the window covers the whole screen, so every spot hits it
	local win = box(0, 0, sw, sh, "FULLSCREEN_DIALOG", 10)
	local UI = r.W.UI
	UI.state = UI.state or {}
	local oldwin = UI.state.win
	UI.state.win = win
	local map = box(100, 100, 300, 300, "HIGH", 1)
	local card = box(0, 0, 10, 10, "MEDIUM", 1)
	card.text = { GetStringHeight = function() return 20 end, SetText = function() end }
	local prev = Bird.Layout
	Bird.Layout = function() return 200, 100 end
	local placed = Bird.Place(card, map)
	Bird.Layout = prev
	UI.state.win = oldwin
	ok(placed, "placed")
	ok(H.STRATA_RANK(card.strata) > H.STRATA_RANK("FULLSCREEN_DIALOG"), "card strata " .. tostring(card.strata) .. " above the window's (a click in the Toplevel window raises only its level)")
	ok(card.level > win.level, "card level " .. tostring(card.level) .. " above window " .. win.level)
end)
