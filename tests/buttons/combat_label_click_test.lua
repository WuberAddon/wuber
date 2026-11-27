-- T243-2 (#99) In combat the big button's "Paused during combat" label stayed over Settings and Ride, was left behind when the
-- window moved, and its area ate clicks. Promise: in a fight, a click on a Wuber control reaches that control even where the
-- paused button was left behind (the topmost frame there is not the secure button), and a label that is drawn lies on the
-- button (anchored to it) and on the Drive slot it belongs to. The fix may not show, hide, move or change a secure frame in combat.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function setup()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	W.db.coach = true
	W.Char().wizard = true
	W.Driver.SetOnline(true)
	w:advance(2)
	W.UI.Toggle(true) w:advance(1)
	W.UI.SelectTab("Drive") w:advance(1.2)
	return w, d, W, d.env.WuberDriveButton
end

local function centre(f) return f:GetLeft() + f:GetWidth() / 2, f:GetBottom() + f:GetHeight() / 2 end

test("T243-2 combat: the window moves over the paused button, a click on Settings reaches Settings", function()
	local w, d, W, b = setup()
	local ui = W.UI.state
	ok(W.Drive.Button.Docked(), "control: docked on Drive")
	w:enterCombat(d) w:advance(0.5)
	eq(b:GetAlpha(), 1, "control: the paused look is on the slot")
	-- the player drags the window so the Settings cog lands where the paused button was left
	local bx, by = centre(b)
	local gx, gy = centre(ui.gear)
	-- (the window is a plain Wuber frame: it moves in a fight, the secure button does not)
	local win = d.env.WuberFrame
	local p, rel, rp, px, py = win:GetPoint(1)
	win:ClearAllPoints()
	win:SetPoint(p, rel, rp, px + (bx - gx), py + (by - gy)) w:advance(1.5)
	local nx, ny = centre(ui.gear)
	ok(math.abs(nx - bx) < 3 and math.abs(ny - by) < 3, "control: the cog is now under the old place of the button")
	local hit = d:clickOn(ui.gear) w:advance(0.5)
	ok(hit ~= b, "the click on the cog is not taken by the paused button")
	eq(W.UI.SettingsShown(), true, "Settings opened")
	eq(#w.violations, 0, "no protected call in combat: " .. table.concat(w.violations, "; "))
	local br = H.rect(b)
	for _, t in ipairs(H.drawnTexts(d, { match = "Paused during combat" })) do
		local r = t.rect
		ok(r.l >= br.l - 1 and r.l + r.w <= br.l + br.w + 1 and r.b >= br.b - 1 and r.b + r.h <= br.b + br.h + 1, "a drawn label lies on the button")
	end
	w:leaveCombat(d) w:advance(1.5)
	T.clean(w)
end)

test("T243-2 combat: Settings opened in the fight, a click on a Settings control under the paused button reaches it", function()
	local w, d, W, b = setup()
	w:enterCombat(d) w:advance(0.5)
	W.UI.OpenSettings() w:advance(1.5)
	eq(W.UI.SettingsShown(), true, "Settings shows")
	local bx, by = centre(b)
	local f = d:frameAt(bx, by)
	ok(f ~= b, "the topmost frame at the paused button's centre is a Wuber control or page, not the secure button")
	eq(#w.violations, 0, "no protected call in combat: " .. table.concat(w.violations, "; "))
	w:leaveCombat(d) w:advance(1.5)
	T.clean(w)
end)

-- guard: a fight that begins during a window drag: the button's anchor to its slot is undone while that is still allowed, so the
-- window stays free to move and lift itself in the fight
test("T243-2 combat begins during a window drag: the button is back on the screen, not anchored to the window", function()
	local w, d, W, b = setup()
	W.Fire("WINDOW_DRAG", true) w:advance(0.2)
	local _, rel = b:GetPoint(1)
	ok(rel ~= d.env.UIParent, "control: anchored to the slot for the drag")
	w:enterCombat(d) w:advance(0.5)
	local _, rel2 = b:GetPoint(1)
	eq(rel2, d.env.UIParent, "anchored to the screen in the fight")
	eq(#w.violations, 0, "no protected call in combat: " .. table.concat(w.violations, "; "))
	w:leaveCombat(d) w:advance(1.5)
	T.clean(w)
end)
