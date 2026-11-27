-- The small console under Wuber's floating big button (Pause | shards | Close/Open, the "Driving" words) must stay stuck to the
-- button while the player drags it. It used to be placed by a 0.25 s ticker from the button's coordinates, so it moved AFTER
-- the button. Promise: in the very frame the button has moved (shift-drag), the console is under it again.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function setup()
	local w = T.newWorld()
	local a = w:addClient(T.ANA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(15)
	local DR, D = a.W.Drive, a.W.Driver
	DR.Button = DR.Button or {}
	DR.Button.Floating = function() return true end
	DR.Button.docked = nil
	DR.button = DR.button or a.env.WuberDriveButton
	H.state[DR.button].shown = true
	DR.IsOpen = function() return true end
	D.UpdateMini()
	w:advance(1)
	return w, a, DR, D
end

local function gap(a, b)
	local m = a.W.UI.drive.mini
	return math.abs((m:GetLeft() * m:GetEffectiveScale()) - (b:GetLeft() * b:GetEffectiveScale())),
		math.abs((m:GetTop() * m:GetEffectiveScale()) - ((b:GetBottom() - 4) * b:GetEffectiveScale()))
end

test("r54 mini: the console under the floating button moves in the same frame as the button while it is dragged", function()
	local w, a, DR, D = setup()
	local b = DR.button
	local m = a.W.UI.drive.mini
	ok(m and m:IsShown(), "control: the console shows under the floating button")
	local dx, dy = gap(a, b)
	ok(dx < 1 and dy < 1, "control: stuck to the button before the drag (" .. dx .. "," .. dy .. ")")
	a.mods = a.mods or {}
	a.mods.shift = true
	w.hardware = a
	b:GetScript("OnDragStart")(b, "LeftButton")
	w.hardware = nil
	for i = 1, 5 do
		-- the game moves the button under the mouse each frame
		local l, bt = b:GetLeft(), b:GetBottom()
		b:ClearAllPoints()
		b:SetPoint("BOTTOMLEFT", a.env.UIParent, "BOTTOMLEFT", l + 37, bt + 23)
		w:advance(w.frameStep) -- one game frame
		local ex, ey = gap(a, b)
		ok(ex < 1 and ey < 1, "frame " .. i .. ": the console is under the button the same frame (off by " .. ex .. "," .. ey .. ")")
	end
	a.mods.shift = false
	T.clean(w)
end)
