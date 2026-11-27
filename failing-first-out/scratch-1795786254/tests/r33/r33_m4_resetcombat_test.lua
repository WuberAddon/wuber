local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- HUNT-59: Reset on Window position in a fight does not say "back" until the window really moved.

local function pt(win) local p, _, rp, x, y = win:GetPoint(1) return tostring(p) .. "/" .. tostring(rp) .. "/" .. tostring(x) .. "/" .. tostring(y) end

test("r33 m4: HUNT-59: Reset in combat waits, then moves the window and says back after the fight", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	w:advance(3)
	local W = d.W
	W.UI.Toggle(true)
	W.UI.OpenSettings("window")
	local win = W.UI.state.win
	win:ClearAllPoints()
	win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 5, -5)
	W.db.pos = { "TOPLEFT", "TOPLEFT", 5, -5 }
	local before = pt(win)
	local said = {}
	local real = W.UI.Toast
	W.UI.Toast = function(t) said[#said + 1] = tostring(t) end
	local b = W.UI.settings.controls.resetPos
	ok(b, "the Reset button exists")
	w:enterCombat(d)
	b:Click()
	eq(pt(win), before, "in the fight the window stays")
	for _, t in ipairs(said) do ok(not t:find("back in its usual place", 1, true), "no 'back' claim while it has not moved: " .. t) end
	w:leaveCombat(d)
	w:advance(1)
	ok(pt(win) ~= before, "after the fight the window moved")
	local back
	-- (decisions N) a reset that changed something now says "1 setting reset." with Undo, in place of "Window back in its usual place"
	for _, t in ipairs(said) do if t:find("1 setting reset.", 1, true) then back = true end end
	ok(back, "it says the reset is done once the window is back")
	W.UI.Toast = real
	T.clean(w)
end)
