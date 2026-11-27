-- Module: UI.Minimap
-- Purpose: The minimap button (UI.FlashMinimap, UI.RefreshMinimap, UI.MayPause).
-- API: UI.MayPause, UI.FlashMinimap, UI.RefreshMinimap
-- Internals: buildMinimap, placeMinimap, refreshMinimap
-- Uses: UI.Kit
-- Later: (none)
-- Events: listens (none); fires (none)
-- Standalone: no
-- Test: tests/ui/minimap_test.lua
-- From: UI.lua 4962-5095 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Minimap", { "UI.Kit" })
local KitMod = W.Mod("UI.Kit")
local N = KitMod.N
local call = KitMod.call
local rideActive = KitMod.rideActive
local rideView = KitMod.rideView
local safeScript = KitMod.safeScript
local setShown = KitMod.setShown
local ui = KitMod.ui
local T = W.Theme
local A = T.Animate
local UI = W.UI

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------

local function placeMinimap(b)
	local angle = math.rad(N(W.db and W.db.minimapAngle) or 215)
	local r = ((N(Minimap:GetWidth()) or 140) / 2) + 10
	b:ClearAllPoints()
	b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

-- Whether this character may pause the crew (not a helper: review #17)
function UI.MayPause()
	local D = W.Driver
	if type(D) == "table" and type(D.CanPause) == "function" then return call(D.CanPause) ~= false end
	local DR = W.Drive
	return not (type(DR) == "table" and type(DR.Role) == "function" and call(DR.Role) == "helper")
end

local function buildMinimap()
	if ui.minimap or type(Minimap) ~= "table" then return end
	local b = CreateFrame("Button", "WuberMinimapButton", Minimap)
	ui.minimap = b
	b:SetSize(32, 32)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(8)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	ui.minimapButton = b
	b.shadow = T.Circle(b, 36, { 0, 0, 0, 0.5 }, "BACKGROUND")
	b.shadow:SetPoint("CENTER", b, "CENTER", 0, -1)
	b.face = T.Tex(b, "minimap", "ARTWORK")
	b.face:SetSize(30, 30)
	b.face:SetPoint("CENTER", b, "CENTER")
	b.hover = T.Tex(b, "ring", "OVERLAY")
	b.hover:SetSize(32, 32)
	b.hover:SetPoint("CENTER", b, "CENTER")
	b.hover:SetVertexColor(T.RGB("glow"))
	b.hover:Hide()
	b.badge = T.Circle(b, 9, "glow", "OVERLAY")
	b.badge:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
	b.badge:Hide()
	b.pulse = A.Pulse(b, { size = 64, colour = "magenta", alpha = 0.8, period = 1.2, rings = 2, start = false })

	safeScript(b, "OnClick", function(self, which)
		if which == "RightButton" then
			local DR = W.Drive
			-- (helpers don't pause: only the crew's Warlocks do, review #17)
			if call(IsShiftKeyDown) == true and type(DR) == "table" and type(DR.SetPaused) == "function"
				and type(DR.IsOpen) == "function" and call(DR.IsOpen) == true and UI.MayPause() then
				local paused = call(DR.IsPaused) == true
				call(DR.SetPaused, not paused)
				UI.Toast(paused and "Resumed: inviting riders again" or "Paused: no new invites", "info")
				return
			end
			if not UI.Show("drive") then UI.Toast("Driving isn't available here", "info") end
		else
			UI.Toggle(nil, self)
		end
	end)
	safeScript(b, "OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local ok = pcall(function()
				local mx, my = Minimap:GetCenter()
				local x, y = GetCursorPosition()
				local scale = Minimap:GetEffectiveScale()
				mx, my, x, y, scale = N(mx), N(my), N(x), N(y), N(scale)
				if not (mx and my and x and y and scale and scale > 0) then return end
				if W.db then W.db.minimapAngle = math.floor(math.deg(math.atan2(y / scale - my, x / scale - mx)) + 0.5) end
				placeMinimap(self)
			end)
			if not ok then self:SetScript("OnUpdate", nil) end
		end)
	end)
	safeScript(b, "OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	safeScript(b, "OnEnter", function(self)
		self.hover:Show()
		-- (design 4) Wuber's own tip card, beside the button (T.TipShow); the words are as they were
		local lines = {}
		local list = UI.Drivers()
		local open = 0
		for _, d in ipairs(list) do if d.state == "open" then open = open + 1 end end
		lines[#lines + 1] = { open == 1 and "1 driver open now" or (open .. " drivers open now"), "white" }
		local rv = rideView()
		if rideActive(rv) then lines[#lines + 1] = { "Your ride: " .. rv.short .. " to " .. rv.dest, "glow" } end
		local drive = UI.DriveSummary and UI.DriveSummary()
		if drive then lines[#lines + 1] = { drive, "white" } end
		if call(W.Advanced) == false then
			lines[#lines + 1] = "Left-click: open or close. Drag: move."
		else
			lines[#lines + 1] = "Left-click: open or close. Right-click: your driver console." .. (UI.MayPause() and type(W.Drive) == "table" and type(W.Drive.IsOpen) == "function" and call(W.Drive.IsOpen) == true and " Shift-right-click: pause or resume driving." or "") .. " Drag: move."
		end
		T.TipShow(self, "Wuber", lines, "ANCHOR_LEFT")
	end)
	safeScript(b, "OnLeave", function(self)
		self.hover:Hide()
		T.TipHide(self)
	end)
	placeMinimap(b)
	if W.db and W.db.minimapHidden then b:Hide() end
end

-- Pulses the minimap button: magenta while the summon is up and the window is closed, gold
-- (colour "gold") while the big driver button has a click for you.
function UI.FlashMinimap(on, colour)
	local b = ui.minimap
	if not b then return end
	if on then
		colour = colour or "magenta"
		if b.pulseColour ~= colour then
			b.pulseColour = colour
			b.pulse:SetColor(colour)
		end
		if not b.pulse.running then b.pulse:Start() end
	elseif b.pulse.running then
		b.pulse:Stop()
	end
end

local function refreshMinimap()
	local b = ui.minimap
	if not b then return end
	local open = false
	for _, d in ipairs(UI.Drivers()) do
		if d.state == "open" then open = true break end
	end
	setShown(b.badge, open)
	local rv = rideView()
	if rv and rv.portalUp then
		-- (HUNT-46) the summon's magenta pulse comes back whenever the window is shut
		UI.FlashMinimap(not (ui.win and ui.win:IsShown()))
		return
	end
	-- the driver: gold while the big button has a click for you (and the console isn't showing)
	local want = UI.DriveWantsClick and UI.DriveWantsClick() == true
	local looking = ui.win and ui.win:IsShown() and ui.tab == "Drive"
	UI.FlashMinimap(want and not looking, "gold")
end

UI.RefreshMinimap = function() W.Safe("minimap", refreshMinimap) end

-- internals other modules use (bound at load by later modules, or called late)
Mod.buildMinimap = buildMinimap
Mod.placeMinimap = placeMinimap
Mod.refreshMinimap = refreshMinimap
