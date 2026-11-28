-- Module: UI.Secure
-- Purpose: The secure Request/Cancel macro buttons, the advert/go overlays and the share overlay
--   (WuberShareButton): macros, overlay placement, UI.SyncSecure, combat lock handling.
-- API: UI.SyncSecure
-- Internals: BLOCK_TEXT, buildSecure, combatRequest, doCancel, hideOverlays, requestBlock, requestMacro, settleLater
--   (an overlay whose pill moved looks again every 0.1 s for half a second, so it follows a rising sheet)
-- Uses: UI.Kit
-- Later: UI.Share (Target, Macro, Shared: the share pill under WuberShareButton)
-- Events: listens (none); fires (none)
-- Standalone: no
-- Test: tests/ui/secure_test.lua
-- From: UI.lua 613-907 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Secure", { "UI.Kit" })
local KitMod = W.Mod("UI.Kit")
local N = KitMod.N
local S = KitMod.S
local call = KitMod.call
local cancellable = KitMod.cancellable
local inCombat = KitMod.inCombat
local inGroup = KitMod.inGroup
local inGroupWith = KitMod.inGroupWith
local macroSafe = KitMod.macroSafe
local money = KitMod.money
local myKey = KitMod.myKey
local now = KitMod.now
local onNetwork = KitMod.onNetwork
local rideActive = KitMod.rideActive
local rideView = KitMod.rideView
local ui = KitMod.ui
local UI = W.UI

---------------------------------------------------------------------------
-- Secure buttons (Request and Cancel whispers)
---------------------------------------------------------------------------

local secure = {}

-- The request: driver key and the macro, if this click may go ahead.
local function requestBlock(key)
	local d = UI.Driver(key)
	if not d then return "gone" end
	if d.key == myKey() then return "self" end
	if d.state == "paused" then return "paused" end
	if rideActive() then return "active" end
	if type(W.AlreadyAt) == "function" and call(W.AlreadyAt, d.dest) then return "here", d end
	if inGroup() and not inGroupWith(d.key) then return "group" end
	if not onNetwork() and not (W.drivers and W.drivers[d.key]) then return "offline" end
	return nil, d
end

local BLOCK_TEXT = {
	gone = "That driver has gone offline",
	self = "That's you!",
	paused = "That driver has paused for now",
	active = "You already have a ride under way",
	group = "Leave your group first",
	offline = "The network is unavailable",
	here = "You're already there",
}

-- "/w Name-Surname text" checked: one line, a plain name, at most 255 bytes.
local function checkMacro(macro)
	macro = S(macro)
	if not macro or macro:find("[\r\n|]") then return nil end
	local target, line = macro:match("^/w (%S+) (.+)$")
	if not target or target:find("/", 1, true) then return nil end
	line = macroSafe(line, 200)
	if not line then return nil end
	return "/w " .. target .. " " .. line, line
end

local function requestMacro(key, d)
	local macro
	if type(W.RequestMacro) == "function" then
		macro = call(W.RequestMacro, key)
	elseif type(W.RequestWhisper) == "function" then
		local line, target = call(W.RequestWhisper, key)
		if line and target then macro = "/w " .. tostring(target) .. " " .. tostring(line) end
	elseif d then
		local target = W.Tell and call(W.Tell, d.name) or (d.name:gsub("%s+", "-"))
		macro = "/w " .. tostring(target) .. " WTB summon to " .. d.dest .. " for " .. money(d.price)
	end
	return checkMacro(macro)
end

local CANCEL_LINE = "Sorry, I have to cancel - thanks anyway"

local function cancelMacro(rv)
	local macro
	if type(W.CancelMacro) == "function" then macro = call(W.CancelMacro) end
	local ok, line = checkMacro(macro)
	if not ok and rv and rv.driver then
		local target = W.Tell and call(W.Tell, rv.driver) or rv.driver:gsub("%s+", "-")
		ok, line = checkMacro("/w " .. tostring(target) .. " " .. CANCEL_LINE)
	end
	if not ok then return nil end
	-- the line must never read as a new request
	if line:lower():find("summon", 1, true) then
		ok = checkMacro((ok:match("^(/w %S+ )") or "") .. CANCEL_LINE)
	end
	return ok
end

-- Cancels the ride (C to the driver); the secure overlay has already whispered if it could.
local function doCancel(whispered)
	local rv = rideView()
	if not cancellable(rv) then
		UI.Toast("Too late to cancel now", "warn")
		return
	end
	local ok = call(W.CancelRide)
	if ok == false then
		UI.Toast("Too late to cancel now", "warn")
		return
	end
	ui.dismissed[rv.id] = true
	call(W.ClearRide)
	ui.manual = "home"
	if whispered or not inCombat() then
		UI.Toast("Ride cancelled", "info")
	else
		UI.Toast("Ride cancelled. No whisper in combat.", "info")
	end
	UI.Refresh(true)
end

-- What each overlay sits on, and whether it may be used now. The Drive tab's two (GO when
-- it would also post the advert, and the Advertise pill) come from Driver.lua.
local function overlayTarget(which)
	local win = ui.win
	if which == "share" then
		-- the visible share pill of the current page or standalone card (UI.Share: flex, wrapped, cut, rank)
		if win and win:IsShown() and (ui.moving or ui.splashing or ui.settingsOpen or ui.closing or now() < ui.animUntil) then
			return nil
		end
		local Sh = UI.Share
		return Sh and call(Sh.Target) or nil
	end
	if not (win and win:IsShown()) or ui.moving or ui.splashing or ui.settingsOpen or ui.closing then return nil end
	if now() < ui.animUntil then return nil end
	if which == "go" or which == "advert" then
		if ui.tab ~= "Drive" then return nil end
		local Dr = W.Driver
		if type(Dr) ~= "table" or type(Dr.AdvertTarget) ~= "function" then return nil end
		return call(Dr.AdvertTarget, which)
	end
	if ui.tab ~= "Ride" then return nil end
	local scr = ui.screens and ui.screens[ui.screen]
	if not scr then return nil end
	if which == "request" then
		if ui.screen ~= "confirm" or not ui.confirmKey then return nil end
		if requestBlock(ui.confirmKey) then return nil end
		return scr.request
	else
		local rv = rideView()
		if not cancellable(rv) then return nil end
		return scr.cancel
	end
end

-- (prep-242 r3 H) a pill that moves on its own (the shift card's sheet rises for 0.32 s, UI.Driver.Sheets) leaves no
-- call behind it: the overlay docked at the first place it saw (off the screen's foot) and stayed there until the
-- next 1 s refresh. So for half a second after its place last changed the overlay looks again every 0.1 s
-- (a sheet may start to move a frame after it opens), until the pill holds still.
local SETTLE = 0.5
local settling = false
local function settleLater()
	if settling or type(W.After) ~= "function" then return end
	settling = true
	W.After(0.1, function()
		settling = false
		if UI.SyncSecure then UI.SyncSecure() end
	end)
end

local function placeOverlay(b, pill)
	if inCombat() then return end
	if not (pill and pill:IsVisible()) or pill.dockHold then -- (#16) dockHold: the pill is under the window while its sheet rises
		if b:IsShown() then b:Hide() end
		b.sig = nil
		return
	end
	local l, bt = N(pill:GetLeft()), N(pill:GetBottom())
	local w, h = N(pill:GetWidth()), N(pill:GetHeight())
	local pe, ue = N(pill:GetEffectiveScale()), N(UIParent:GetEffectiveScale())
	if not (l and bt and w and h and pe and ue) or w <= 0 or h <= 0 or ue <= 0 then
		if b:IsShown() then b:Hide() end
		return
	end
	local s = pe / ue
	local sig = ("%.1f:%.1f:%.1f:%.1f:%.4f"):format(l, bt, w, h, s)
	local base = math.max(N(ui.win and ui.win:GetFrameLevel()) or 0, N(pill.GetFrameLevel and pill:GetFrameLevel()) or 0)
	local level = math.min(10000, base + 100) -- (levels stop at 10000)
	-- over the open world map too (the game raises a map that opens after the overlay was placed)
	local strata, mapLevel = "FULLSCREEN_DIALOG", level
	strata, mapLevel = KitMod.OverMap(strata, level)
	if b.level ~= mapLevel or b.strata ~= strata then
		if b.strata ~= strata then b:SetFrameStrata(strata) end
		b:SetFrameLevel(mapLevel)
		b.level, b.strata = mapLevel, strata
	end
	if b.sig ~= sig then
		b:SetScale(s)
		b:ClearAllPoints()
		b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, bt)
		b:SetSize(w, h)
		b.sig = sig
		b.movedAt = now()
	end
	if b.movedAt and now() - b.movedAt < SETTLE then settleLater() end
	b.pill = pill
	if not b:IsShown() then b:Show() end
end

-- A click on the Request overlay in a fight. The overlay is put away as a fight begins (UI.Window),
-- but if the lockdown came first it stays over the pill with an empty macro (nothing protected runs).
-- Book as the pill does in a fight (UI.Rider.Confirm): the request goes, the whisper doesn't. Only
-- while the open card's own Request pill is under it, for a driver who can still be asked;
-- W.RequestRide sends nothing again for a ride already asked for, so one click is one request.
local function combatRequest(b)
	local key, win = ui.confirmKey, ui.win
	local scr = ui.screens and ui.screens.confirm
	local pill = scr and scr.request
	if not (key and pill and b.pill == pill and ui.tab == "Ride" and ui.screen == "confirm" and win and win:IsShown()
		and pill:IsVisible() and not pill.inactive and not (ui.closing or ui.settingsOpen or ui.moving)) then
		UI.Toast("Can't request in combat", "warn")
		return
	end
	local ride
	local why = requestBlock(key)
	if not why then ride, why = call(W.RequestRide, key) end
	if not ride then
		UI.Toast(BLOCK_TEXT[why or ""] or "Couldn't send the request", "warn")
		return
	end
	UI.Toast("Request sent. No whisper in combat.", "info")
	ui.manual = "home"
	UI.Refresh(true)
end

-- Lays the secure buttons over their pills (out of combat only).
function UI.SyncSecure()
	if inCombat() then return end
	if secure.request then placeOverlay(secure.request, overlayTarget("request")) end
	if secure.cancel then placeOverlay(secure.cancel, overlayTarget("cancel")) end
	if secure.go then placeOverlay(secure.go, overlayTarget("go")) end
	if secure.advert then placeOverlay(secure.advert, overlayTarget("advert")) end
	if secure.share then placeOverlay(secure.share, overlayTarget("share")) end
	-- the big driver button docks over its slot on the Drive tab, else floats (Driver.lua)
	local Dr = W.Driver
	if type(Dr) == "table" and type(Dr.SyncDock) == "function" then call(Dr.SyncDock) end
end

local function hideOverlays()
	if inCombat() then return end
	for _, b in pairs(secure) do
		b:SetAttribute("macrotext", "")
		b:Hide()
		b.sig = nil
	end
end

local function forward(b, script, pill)
	pill = pill or b.pill
	if not pill then return end
	local fn = pill:GetScript(script)
	if fn then pcall(fn, pill) end
end

local function makeSecure(name, pre, post)
	local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
	b:SetSize(10, 10)
	b:SetFrameStrata("FULLSCREEN_DIALOG")
	b:SetFrameLevel(120)
	b:RegisterForClicks("LeftButtonUp")
	b:SetAttribute("useOnKeyDown", false)
	b:SetAttribute("type", "macro")
	b:SetAttribute("macrotext", "")
	b:Hide()
	b:SetScript("PreClick", function(self, button, down)
		if not down then W.Crumb("click " .. tostring(name)) end
		local ok, err = pcall(pre, self, button, down)
		if not ok then
			self.armed = nil
			W.Error("secure button", err)
		end
	end)
	b:SetScript("PostClick", function(self, button, down)
		if down then return end
		local armed = self.armed
		self.armed = nil
		if not inCombat() then self:SetAttribute("macrotext", "") end
		local ok, err = pcall(post, self, armed)
		if not ok then W.Error("secure button", err) end
	end)
	-- the pill underneath shows hover and press
	b:SetScript("OnEnter", function(self) forward(self, "OnEnter") end)
	b:SetScript("OnLeave", function(self) forward(self, "OnLeave") end)
	b:SetScript("OnMouseDown", function(self) forward(self, "OnMouseDown") end)
	b:SetScript("OnMouseUp", function(self) forward(self, "OnMouseUp") end)
	return b
end

local function buildSecure()
	if secure.request then return end
	if inCombat() then
		if W.AfterCombat then W.AfterCombat(buildSecure) end
		return
	end
	secure.request = makeSecure("WuberRequestButton", function(self, _, down)
		self.armed = nil
		if down or inCombat() then return end
		self:SetAttribute("macrotext", "")
		local key = ui.confirmKey
		local why, d = requestBlock(key)
		if why then return end
		local macro = requestMacro(d.key, d)
		if not macro then return end
		self:SetAttribute("type", "macro")
		self:SetAttribute("macrotext", macro)
		self.armed = d.key
	end, function(self, armed)
		if armed then
			local ride, why = call(W.RequestRide, armed)
			if not ride and why then UI.Toast(BLOCK_TEXT[why] or "Couldn't send the request", "warn") end
			ui.manual = "home"
			UI.Refresh(true)
		elseif inCombat() then
			combatRequest(self)
		else
			local why = requestBlock(ui.confirmKey)
			UI.Toast(BLOCK_TEXT[why or ""] or "Couldn't send the request", "warn")
		end
	end)
	secure.cancel = makeSecure("WuberCancelButton", function(self, _, down)
		self.armed = nil
		if down or inCombat() then return end
		self:SetAttribute("macrotext", "")
		local rv = rideView()
		if not cancellable(rv) then return end
		local macro = cancelMacro(rv)
		if not macro then
			self.armed = "quiet"
			return
		end
		self:SetAttribute("type", "macro")
		self:SetAttribute("macrotext", macro)
		self.armed = "whisper"
	end, function(_, armed)
		doCancel(armed == "whisper")
	end)
	-- the Drive tab: GO ONLINE that also posts the advert, and the Advertise pill. The line is
	-- only set here, in the click itself, when Driver.lua's plan allows it (out of combat,
	-- not within 15 min of the last, a public channel joined).
	local function advertButton(name, which)
		return makeSecure(name, function(self, _, down)
			self.armed = nil
			if down or inCombat() then return end
			self:SetAttribute("macrotext", "")
			local Dr = W.Driver
			if type(Dr) ~= "table" or type(Dr.AdvertPlan) ~= "function" then return end
			if overlayTarget(which) == nil then return end
			local plan = call(Dr.AdvertPlan, which)
			local macro = type(plan) == "table" and S(plan.macro)
			if not macro or macro:find("[\r\n|]") or #macro > 255 or not macro:match("^/%d+ %S") then
				self.armed = false
				return
			end
			self:SetAttribute("type", "macro")
			self:SetAttribute("macrotext", macro)
			self.armed = plan
		end, function(_, armed)
			local Dr = W.Driver
			if type(Dr) == "table" and type(Dr.AdvertClicked) == "function" then
				call(Dr.AdvertClicked, which, type(armed) == "table" and armed or nil)
			end
			UI.Refresh(true)
		end)
	end
	secure.go = advertButton("WuberGoButton", "go")
	secure.advert = advertButton("WuberAdvertButton", "advert")
	-- the share pills: "/p <line>", "/ra <line>", or "/g <line>" (guild pills),
	-- set only in the click itself by UI.Share from the pill under it, emptied after; never in combat
	secure.share = makeSecure("WuberShareButton", function(self, _, down)
		self.armed = nil
		if down or inCombat() then return end
		self:SetAttribute("macrotext", "")
		local pill = overlayTarget("share")
		local Sh = UI.Share
		if not (pill and Sh) then return end
		local macro, line = call(Sh.Macro, pill)
		macro = S(macro)
		if not macro or macro:find("[\r\n|]") or #macro > 255 or not (macro:match("^/r?[ap] %S") or macro:match("^/g %S")) then return end
		self:SetAttribute("type", "macro")
		self:SetAttribute("macrotext", macro)
		self.armed = { pill = pill, line = line }
	end, function(_, armed)
		local Sh = UI.Share
		if type(armed) == "table" then
			if Sh then call(Sh.Shared, armed.pill, armed.line) end
		elseif inCombat() then
			UI.Toast("Share after combat", "warn")
		end
		UI.Refresh(true)
	end)
	UI.secure = secure
end

-- internals other modules use (bound at load by later modules, or called late)
Mod.BLOCK_TEXT = BLOCK_TEXT
Mod.buildSecure = buildSecure
Mod.doCancel = doCancel
Mod.hideOverlays = hideOverlays
Mod.requestBlock = requestBlock
Mod.requestMacro = requestMacro
