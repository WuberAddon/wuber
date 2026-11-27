-- #204 (T243-2) "Paused during combat" stayed drawn over other pages: the big button is docked over the Drive tab's
-- slot, every dock/move/hide path returns early in combat, so the button kept its look (alpha 1, its title) at its old
-- spot over Ride, Settings and pushed pages. Promise: in combat, the slot gone means alpha 0 and no words (allowed
-- calls only); the slot back where it was brings the paused look back; after the fight it docks again.
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

local function text(fs) return fs and fs.GetText and fs:GetText() or "" end

test("#204 paused label: combat on Drive, then Ride, then Settings: the button's look is gone; back on Drive it returns", function()
	local w, d, W, b = setup()
	ok(W.Drive.Button.Docked(), "control: docked on Drive")
	w:enterCombat(d) w:advance(0.5)
	eq(text(b.title), "Paused during combat", "control: paused title on the Drive slot")
	eq(b:GetAlpha(), 1, "control: shown on the slot")
	W.UI.SelectTab("Ride") w:advance(1.5)
	eq(b:GetAlpha(), 0, "Ride: alpha 0")
	eq(text(b.title), "", "Ride: no title")
	eq(text(b.sub), "", "Ride: no sub")
	W.UI.SelectTab("Drive") w:advance(1.5)
	eq(b:GetAlpha(), 1, "Drive again: alpha 1")
	eq(text(b.title), "Paused during combat", "Drive again: the paused title is back")
	W.UI.SelectTab("Ride") w:advance(1.5)
	W.UI.OpenSettings() w:advance(1.5)
	eq(W.UI.SettingsShown(), true, "Settings shows")
	eq(b:GetAlpha(), 0, "Settings: alpha 0")
	eq(text(b.title), "", "Settings: no title")
	eq(text(b.sub), "", "Settings: no sub")
	eq(#w.violations, 0, "no protected call in combat: " .. table.concat(w.violations, "; "))
	-- the hero card of the Drive page is not left drawn over Settings
	local con = W.Mod("UI.Driver") and W.Mod("UI.Driver").ui and W.Mod("UI.Driver").ui.console
	if con then eq(con:IsVisible(), false, "the Drive page is not drawn over Settings") end
	-- a real click at the old spot of the button reaches the button (EnableMouse cannot change in combat); it does nothing
	local before = b:GetAttribute("macrotext")
	d:clickOn(b) w:advance(0.5)
	eq(b:GetAttribute("macrotext"), before, "a click there does nothing more (the paused plan is empty)")
	eq(#w.violations, 0, "still no protected call: " .. table.concat(w.violations, "; "))
	w:leaveCombat(d) w:advance(1.5)
	eq(b:GetAlpha(), 1, "after the fight: alpha 1")
	W.UI.CloseSettings() w:advance(0.5)
	W.UI.SelectTab("Drive") w:advance(1.5)
	ok(W.Drive.Button.Docked(), "after the fight: docked on the Drive slot again")
	T.clean(w)
end)

test("#204 paused label: combat on Drive, the window closed: the look is gone", function()
	local w, d, W, b = setup()
	w:enterCombat(d) w:advance(0.5)
	W.UI.Toggle(false) w:advance(1.5)
	eq(b:GetAlpha(), 0, "window closed: alpha 0")
	eq(text(b.title), "", "window closed: no title")
	eq(#w.violations, 0, "no protected call in combat: " .. table.concat(w.violations, "; "))
	w:leaveCombat(d) w:advance(1.5)
	eq(b:GetAlpha(), 1, "after the fight: alpha 1")
	T.clean(w)
end)
