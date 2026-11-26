-- While the Wuber window is moved, the driver's big docked card ("Open - waiting for riders") must stay on its slot.
-- It is a secure button anchored to UIParent, so it is re-placed by a 0.25 s ticker (Wuber/Drive/Button.lua, W.Every(0.25)),
-- and during a drag it is left behind the window.
local T = ...
local test, ok = T.test, T.ok

test("playtest F1: the docked big card follows the window within one frame while it is dragged", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	W.Char().wizard = true
	W.UI.Toggle(true) w:advance(2) W.UI.SelectTab("Drive") w:advance(2)
	local DR = W.Drive
	local b = d.env.WuberDriveButton
	ok(DR.Button.Docked() and b:IsShown(), "control: docked in the Drive tab")
	local slot = W.Driver.Slot()
	ok(slot, "control: found the console slot")
	local function gap()
		local se, be = slot:GetEffectiveScale(), b:GetEffectiveScale()
		return (slot:GetLeft() * se) - (b:GetLeft() * be), (slot:GetBottom() * se) - (b:GetBottom() * be)
	end
	local sl0 = slot:GetLeft()
	local gx0, gy0 = gap()
	ok(math.abs(gx0) < 1 and math.abs(gy0) < 1, "control: the card starts on its slot")
	local top = W.UI.state.top
	top:GetScript("OnDragStart")(top)
	local win = d.env.WuberFrame
	local p, rel, rp, x, y = win:GetPoint(1)
	win:ClearAllPoints()
	win:SetPoint(p, rel, rp, x + 120, y - 80)
	-- (no time passes: the real game draws the next frame before any 0.25 s ticker)
	ok(slot:GetLeft() ~= sl0, "control: the window really moved the slot (" .. tostring(sl0) .. " -> " .. tostring(slot:GetLeft()) .. ")")
	local gx, gy = gap()
	ok(math.abs(gx) < 1 and math.abs(gy) < 1,
		"the docked card lags behind the moving window by " .. math.floor(gx + 0.5) .. ", " .. math.floor(gy + 0.5) .. " px")
	top:GetScript("OnDragStop")(top)
	T.clean(w)
end)
