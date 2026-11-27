local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function openDriving(w, d)
	d.W.db.coach = true
	d.W.UI.Toggle(true)
	w:advance(3)
	d.W.UI.OpenSettings("driving")
	w:advance(1)
	return d.W.UI.settings
end

local function captureKey(d, st, keyName, modFnName)
	local set = st.controls["drive.key"]
	ok(set, "drive.key Set button")
	local cap
	for _, ch in ipairs({ set:GetParent():GetChildren() }) do
		if ch.GetScript and ch:GetScript("OnKeyDown") then cap = ch break end
	end
	ok(cap, "key capture frame")
	local orig = d.env[modFnName]
	d.env[modFnName] = function() return false end
	set:GetScript("OnClick")(set)
	cap:GetScript("OnKeyDown")(cap, keyName)
	local withoutMod = d.W.db.drive.button.key
	d.env[modFnName] = function() return true end
	set:GetScript("OnClick")(set)
	cap:GetScript("OnKeyDown")(cap, keyName)
	local withMod = d.W.db.drive.button.key
	d.env[modFnName] = orig
	return withoutMod, withMod
end

-- guards Wuber/UI/Settings/Rows.lua:691 (Alt modifier check inverted during keybind capture)
test("mutation b3 settings rows: key capture applies ALT- only when Alt is held", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local st = openDriving(w, d)
	local plain, modded = captureKey(d, st, "F5", "IsAltKeyDown")
	eq(plain, "F5", "plain key without Alt")
	eq(modded, "ALT-F5", "ALT- prefix when Alt is held")
	T.clean(w)
end)

-- guards Wuber/UI/Settings/Rows.lua:692 (Ctrl modifier check inverted during keybind capture)
test("mutation b3 settings rows: key capture applies CTRL- only when Ctrl is held", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local st = openDriving(w, d)
	local plain, modded = captureKey(d, st, "F6", "IsControlKeyDown")
	eq(plain, "F6", "plain key without Ctrl")
	eq(modded, "CTRL-F6", "CTRL- prefix when Ctrl is held")
	T.clean(w)
end)

-- guards Wuber/UI/Settings/Rows.lua:693 (Shift modifier check inverted during keybind capture)
test("mutation b3 settings rows: key capture applies SHIFT- only when Shift is held", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local st = openDriving(w, d)
	local plain, modded = captureKey(d, st, "F7", "IsShiftKeyDown")
	eq(plain, "F7", "plain key without Shift")
	eq(modded, "SHIFT-F7", "SHIFT- prefix when Shift is held")
	T.clean(w)
end)

-- guards Wuber/UI/Settings/Rows.lua:938 (Reset place Undo skips placing the big button back)
test("mutation b3 settings rows: Reset place Undo places the big button back", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local st = openDriving(w, d)
	local btn = st.controls["drive.resetPos"]
	ok(btn, "drive.resetPos button")
	d.W.db.drive.button.pos = { "CENTER", 120, -40 }
	local placed = 0
	local origPlace = d.W.Drive.Button.Place
	d.W.Drive.Button.Place = function(...)
		placed = placed + 1
		return origPlace(...)
	end
	btn:GetScript("OnClick")(btn)
	w:advance(0.2)
	placed = 0
	ok(d:clickText("Undo"), "clicked Undo on toast")
	d.W.Drive.Button.Place = origPlace
	eq(placed, 2, "Undo calls Button.Place")
	T.clean(w)
end)

-- guards Wuber/UI/Settings/Rows.lua:1097 (Wide pages Reset Undo skips applying Fold layout)
test("mutation b3 settings rows: Wide pages Reset Undo re-applies Fold layout", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	d.W.db.coach = true
	d.W.UI.Toggle(true)
	w:advance(3)
	d.W.UI.OpenSettings("window")
	w:advance(1)
	local st = d.W.UI.settings
	local btn = st.controls.foldReset
	ok(btn, "foldReset button")
	d.W.db.fold = { v = 1, pages = { driving = false }, narrow = true }
	local applied = 0
	local origApply = d.W.UI.Fold.Apply
	d.W.UI.Fold.Apply = function(...)
		applied = applied + 1
		return origApply(...)
	end
	btn:GetScript("OnClick")(btn)
	w:advance(0.2)
	applied = 0
	ok(d:clickText("Undo"), "clicked Undo on toast")
	d.W.UI.Fold.Apply = origApply
	eq(applied, 2, "Undo calls Fold.Apply")
	T.clean(w)
end)

-- guards Wuber/UI/Settings/Rows.lua:787 (switching Group size back to Auto leaves old maxGroup saved)
test("mutation b3 settings rows: Group size slider back to Auto resets saved maxGroup to 0", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local st = openDriving(w, d)
	local sl = st.controls["drive.maxGroup"]
	ok(sl, "drive.maxGroup slider")
	sl.onChange(10)
	eq(d.W.Drive.opts().maxGroup, 10, "maxGroup set to 10")
	sl.onChange(2)
	eq(d.W.Drive.opts().maxGroup, 0, "Auto resets saved maxGroup to 0")
	eq(d.W.Drive.opts().oneAtATime, false, "Auto clears oneAtATime")
	T.clean(w)
end)

-- guards Wuber/UI/Settings/Rows.lua:857 (crew window Remove riders toggle shows opposite of captain setting)
test("mutation b3 settings rows: crew window Remove riders toggle keeps captain state on click", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local DR = d.W.Drive
	DR.IsCaptain = function() return false end
	local st = openDriving(w, d)
	local t = st.controls["drive.kickAfter"]
	ok(t, "drive.kickAfter toggle")
	DR.opts().kickAfter = true
	d.W.UI.UpdateSettings()
	w:advance(0.5)
	t:Click()
	w:advance(0.5)
	eq(t.on, true, "crew toggle remains on matching captain")
	eq(DR.opts().kickAfter, true, "saved kickAfter unchanged")
	T.clean(w)
end)

-- guards Wuber/UI/Settings/Rows.lua:874 (Block and tell them fails to enable autoBlock)
test("mutation b3 settings rows: leavers Block and tell them enables autoBlock and tellBlocked", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local st = openDriving(w, d)
	local seg = st.controls["drive.leavers"]
	ok(seg, "drive.leavers segmented control")
	seg.buttons[3]:Click()
	d.W.Drive.opts().autoBlock = false
	d.W.Drive.opts().tellBlocked = false
	seg.buttons[1]:Click()
	eq(d.W.Drive.opts().autoBlock, true, "autoBlock enabled")
	eq(d.W.Drive.opts().tellBlocked, true, "tellBlocked enabled")
	T.clean(w)
end)

-- guards Wuber/UI/Settings/Rows.lua:877 (Block quietly fails to enable autoBlock)
test("mutation b3 settings rows: leavers Block quietly enables autoBlock and disables tellBlocked", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local st = openDriving(w, d)
	local seg = st.controls["drive.leavers"]
	ok(seg, "drive.leavers segmented control")
	seg.buttons[3]:Click()
	d.W.Drive.opts().autoBlock = false
	d.W.Drive.opts().tellBlocked = true
	seg.buttons[2]:Click()
	eq(d.W.Drive.opts().autoBlock, true, "autoBlock enabled")
	eq(d.W.Drive.opts().tellBlocked, false, "tellBlocked disabled")
	T.clean(w)
end)

-- guards Wuber/UI/Settings/Rows.lua:978 (Alert character field skips calling DR().BellSet)
test("mutation b3 settings rows: Alert character field saves name via BellSet", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local st = openDriving(w, d)
	local field = st.controls["drive.bell"]
	ok(field, "drive.bell field")
	field.edit:GetScript("OnEditFocusGained")(field.edit)
	field.edit:SetText("Testchar")
	field.edit:GetScript("OnEditFocusLost")(field.edit)
	w:advance(0.2)
	eq(d.W.db.drive.bell and d.W.db.drive.bell.name, "Testchar", "bell name saved")
	T.clean(w)
end)
