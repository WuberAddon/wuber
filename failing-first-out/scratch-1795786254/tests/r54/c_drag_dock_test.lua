-- r54 C: dragging the Wuber window never shows or hides another Wuber frame.
-- Promise: while the window is dragged (ui.top OnDragStart .. OnDragStop), the driver's big button keeps the state
-- it had (docked in the Drive tab stays docked; its floating mini console does not open) however long the drag lasts.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function setup()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	W.Char().wizard = true
	W.UI.Toggle(true) w:advance(2) W.UI.SelectTab("Drive") w:advance(2)
	return w, d, W
end

local function dragCase(step)
	return function()
		local w, d, W = setup()
		local DR = W.Drive
		local b = d.env.WuberDriveButton
		ok(DR.Button.Docked() and b:IsShown(), "control: docked in the Drive tab")
		local top = W.UI.state.top
		top:GetScript("OnDragStart")(top)
		for _ = 1, 6 do
			w:advance(step)
			ok(DR.Button.Docked(), "still docked during the drag")
			ok(b:IsShown(), "the button is still shown during the drag")
		end
		top:GetScript("OnDragStop")(top)
		w:advance(step)
		ok(DR.Button.Docked() and b:IsShown(), "docked after the drop")
		T.clean(w)
	end
end
test("r54 C: the big button stays docked in the Drive tab while the window is dragged (1 s steps)", dragCase(1))
test("r54 C: the big button stays docked in the Drive tab while the window is dragged (5 s steps)", dragCase(5))

-- guard: closing the window still releases the docked button (the rule is not tied to the drag)
test("r54 C: closing the window still lets the big button leave its slot", function()
	local w, d, W = setup()
	local DR = W.Drive
	ok(DR.Button.Docked(), "control: docked")
	W.UI.Toggle(false) w:advance(2)
	ok(not DR.Button.Docked(), "closing the window ends the docking")
	T.clean(w)
end)

-- guard: leaving the Drive tab (no drag) still undocks it
test("r54 C: another tab still lets the big button leave its slot", function()
	local w, d, W = setup()
	local DR = W.Drive
	W.UI.SelectTab("Trips") w:advance(2)
	ok(not DR.Button.Docked(), "off the Drive tab it is not docked")
	T.clean(w)
end)
