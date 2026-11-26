-- BRIEF24 group A, P1: "Invite public chat buyers" must show its real value after the warning is answered
-- (Yes, Cancel) or goes away another way (hidden, replaced), and after /wuber drive market asks while Settings
-- is open. The knob position (t.pos) and t.on both count: the click's own slide used to leave the knob ticked.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function world()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	d.W.db.coach = true
	d.W.UI.Toggle(true)
	w:advance(3)
	d.W.UI.OpenSettings("driving")
	w:advance(1)
	return w, d, d.W.UI.settings.controls["drive.autoPublic"]
end

local function pop(d) return d.env.StaticPopup_FindVisible(d.W.Drive.PUBLIC_POPUP) ~= nil end

local function shows(t, on, what)
	eq(t.on, on, what .. ": on")
	eq(t.pos, on and 1 or 0, what .. ": knob")
	ok(not t.inactive, what .. ": clickable")
end

test("r24 a: Invite public chat buyers after Cancel shows off, knob at the left", function()
	local w, d, t = world()
	ok(t, "the switch")
	d:click(t)
	w:advance(0.5)
	ok(pop(d), "asks")
	local dlg = d.env.StaticPopupDialogs[d.W.Drive.PUBLIC_POPUP]
	d.env.StaticPopup_Hide(d.W.Drive.PUBLIC_POPUP)
	dlg.OnCancel()
	w:advance(1)
	eq(d.W.Drive.opts().autoPublic, false)
	shows(t, false, "Cancel")
	d:click(t) -- clickable again
	w:advance(0.5)
	ok(pop(d), "asks again")
	T.clean(w)
end)

test("r24 a: Invite public chat buyers after Yes shows on", function()
	local w, d, t = world()
	d:click(t)
	w:advance(0.5)
	local dlg = d.env.StaticPopupDialogs[d.W.Drive.PUBLIC_POPUP]
	d.env.StaticPopup_Hide(d.W.Drive.PUBLIC_POPUP)
	dlg.OnAccept()
	w:advance(1)
	eq(d.W.Drive.opts().autoPublic, true)
	shows(t, true, "Yes")
	T.clean(w)
end)

test("r24 a: Invite public chat buyers when the popup closes without an answer shows the real value", function()
	local w, d, t = world()
	d:click(t)
	w:advance(0.5)
	d.env.StaticPopup_Hide(d.W.Drive.PUBLIC_POPUP) -- Escape or another popup took its place: no OnCancel
	w:advance(1)
	eq(d.W.Drive.opts().autoPublic, false)
	shows(t, false, "hidden")
	T.clean(w)
end)

test("r24 a: /wuber drive market asking while Settings is open: the box follows the real value", function()
	local w, d, t = world()
	d:slash("/wuber drive market on")
	w:advance(0.5)
	ok(pop(d), "the slash command asks")
	shows(t, false, "while it asks")
	local dlg = d.env.StaticPopupDialogs[d.W.Drive.PUBLIC_POPUP]
	d.env.StaticPopup_Hide(d.W.Drive.PUBLIC_POPUP)
	dlg.OnAccept()
	w:advance(1)
	shows(t, true, "Yes through the command")
	d:slash("/wuber drive market off")
	w:advance(1)
	shows(t, false, "off through the command")
	d:slash("/wuber drive market on")
	w:advance(0.5)
	dlg = d.env.StaticPopupDialogs[d.W.Drive.PUBLIC_POPUP]
	d.env.StaticPopup_Hide(d.W.Drive.PUBLIC_POPUP)
	dlg.OnCancel()
	w:advance(1)
	shows(t, false, "Cancel through the command")
	T.clean(w)
end)
