local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok


local function cy(env, f)
	local k = f:GetEffectiveScale() / env.UIParent:GetEffectiveScale()
	return (f:GetBottom() + f:GetTop()) / 2 * k
end

local function setup()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	W.db.coach = true
	W.Char().wizard = true
	H.state[d.env.UIParent].w, H.state[d.env.UIParent].h = 1365, 768 -- a 1920x1080 screen
	d.physW, d.physH = 1920, 1080
	d.wide = true
	d:fire("DISPLAY_SIZE_CHANGED")
	W.db.scale = 2.2
	W.Drive.SetScale(2.2)
	if W.UI.ApplyScale then W.UI.ApplyScale() end
	W.Driver.SetOnline(true)
	return w, d, W
end

local function shiftDrag(d, b, dx, dy)
	d.mods.shift = true
	d:drag(b, dx, dy)
	d.mods.shift = nil
end

test("AUD-103: dragging the big button while the phone is open keeps its place when the phone shuts", function()
	local w, d, W = setup()
	local env, DR = d.env, W.Drive
	local b = env.WuberDriveButton
	-- control: the phone shut, full size: a drag keeps its place
	w:advance(2)
	ok(math.abs(b:GetScale() - 2.2) < 0.01, "control: the button is at its chosen size 2.2 (" .. b:GetScale() .. ")")
	shiftDrag(d, b, 0, -150)
	local dropped0 = cy(env, b)
	w:advance(2)
	ok(math.abs(cy(env, b) - dropped0) < 5, ("control: full size, dragged to y %.0f, still there after a moment (y %.0f)"):format(dropped0, cy(env, b)))
	DR.ResetPosition()
	w:advance(1)
	-- the phone open on the Drive tab: the button is shrunk to fit beside it
	W.UI.Toggle(true) w:advance(1) W.UI.SelectTab("Drive") w:advance(0.5)
	W.Driver.ShowScreen("customers") w:advance(2)
	ok(DR.Button.Floating(), "the button floats beside the phone")
	ok(b:GetScale() < 2.1, "control: shrunk beside the phone (scale " .. b:GetScale() .. ")")
	local top = cy(env, b)
	shiftDrag(d, b, 150, -(top - 484) / b:GetScale())
	local dropped = cy(env, b)
	w:advance(2)
	W.UI.Toggle(false)
	w:advance(2)
	local after = cy(env, b)
	ok(math.abs(b:GetScale() - 2.2) < 0.01, "the phone is shut: the chosen size again")
	ok(math.abs(after - dropped) < 8,
		("the player dropped the button at height %.0f with the phone open; once the phone shut it sits at height %.0f (saved offset %s)")
		:format(dropped, after, tostring(DR.db.button.pos and DR.db.button.pos[4])))
	T.clean(w)
end)


test("AUD-104: after a fight with the window closed in it, a closed Wuber's big button does not flash up floating", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	local DR = W.Drive
	W.db.coach = true
	W.Char().wizard = true
	W.UI.Toggle(true) w:advance(2) W.UI.SelectTab("Drive") w:advance(2)
	local b = d.env.WuberDriveButton
	ok(DR.Button.Docked() and b:IsShown(), "control: docked in the Drive tab")
	ok(not DR.IsOpen(), "control: driving is closed, no keep-on-screen")
	w:enterCombat(d) w:advance(0.5)
	W.UI.Toggle(false) w:advance(0.5)
	ok(not d.env.WuberFrame:IsShown(), "the window is closed (in the fight)")
	w:leaveCombat(d)
	w:advance(0.05)
	ok(not (b:IsShown() and DR.Button.Floating()), "0.05 s after the fight the big button pops up floating on screen although driving is closed and nothing wants it")
	w:advance(1)
	ok(not b:IsShown(), "control: a moment later it is gone")
	T.clean(w)
end)
