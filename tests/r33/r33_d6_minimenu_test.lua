local T = ...
-- Round 33 group d6 (AUD-121, a reviewer C52b-1): with the window shut, the '...' on a floating mini
-- console row opened its menu on the hidden Drive page. It now opens the window on the Drive tab
-- first (UI.ShowDrive, the path the other open paths use), so the menu is seen at once.
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function setup()
	local w = T.newWorld()
	local d = T.driver(w, "Anita Lift")
	local r = T.rider(w)
	T.settle(w)
	T.goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(1)
	return w, d, r
end

local function menuShown(d)
	local ui = d.W.Driver.ui
	local s = ui and ui.sheets and ui.sheets.menu
	return s ~= nil and H.visible(s.frame)
end

test("r33 d6: the dots on a mini console row open the window on Drive with the menu (Drive never opened)", function()
	local w, d = setup()
	local m = d.env.WuberDriveMini
	ok(m and m:IsVisible(), "control: the floating console shows")
	local row = m.rows[1]
	ok(row and H.visible(row), "control: its first row shows a rider")
	d:clickOn(row.more) w:advance(1)
	ok(d.W.UI.IsShown(), "the window opened")
	eq(d.W.UI.state and d.W.UI.state.tab, "Drive", "on the Drive tab")
	ok(menuShown(d), "the row menu shows")
	T.clean(w)
end)

test("r33 d6: after Drive was opened once and the window shut, the dots show the menu at once", function()
	local w, d = setup()
	d.W.UI.Toggle(true) w:advance(2.5)
	d:clickText("Drive") w:advance(1.5)
	d.W.UI.Toggle(false) w:advance(2)
	local m = d.env.WuberDriveMini
	ok(m and m:IsVisible(), "control: mini console shows once the window is shut")
	d:clickOn(m.rows[1].more) w:advance(1)
	ok(d.W.UI.IsShown(), "the window opened")
	ok(menuShown(d), "the row menu shows")
	eq(d.W.Driver.SheetOpen(), true, "the menu counts as open")
	T.clean(w)
end)

test("r33 d6: with Drive on screen the dots open the menu and the window stays as it was", function()
	local w, d = setup()
	d.W.UI.Toggle(true) w:advance(2.5)
	d:clickText("Drive") w:advance(1.5)
	local opened = 0
	local real = d.W.UI.ShowDrive
	d.W.UI.ShowDrive = function(...) opened = opened + 1 return real(...) end
	ok(d.W.Driver.OpenMenu(d.W.Drive.Sorted()[1]), "OpenMenu says it opened")
	w:advance(1)
	ok(menuShown(d), "the row menu shows")
	eq(opened, 0, "no second open of the Drive tab")
	d.W.UI.ShowDrive = real
	T.clean(w)
end)
