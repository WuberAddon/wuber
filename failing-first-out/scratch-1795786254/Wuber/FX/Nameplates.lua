-- Module: FX.Nameplates
-- Purpose: crowns and badges over heads, and the mouse-over tooltip line (was Nameplates.lua).
-- API: W.Plates
-- Internals: hook slot emblem (set by FX.Emblem: the Pioneers' emblems follow the same plates)
-- Uses: Theme.Widgets
--   (T.PioneerLook, T.PioneerBadge, T.PIONEER are read at run time)
-- Later: (none)
-- Events: listens On NAME_PLATE_UNIT_ADDED, On NAME_PLATE_UNIT_REMOVED, On PLAYER_ENTERING_WORLD, Listen
--   SETTINGS, Listen DRIVERS, login; fires (none)
-- Standalone: no
-- Test: tests/fx/nameplates_test.lua
-- From: Nameplates.lua 1-481 (Wuber 2.2.1)
--
-- Wuber: crowns and badges over heads. The founder's characters (W.CREATOR) get the spinning
-- crown above their nameplate; known Wuber drivers with a fresh beacon get their badge. Your
-- own crown (when you are the founder) sits over your character in the middle of the screen.
-- Plus a tooltip line on mouse-over: "Wuber founder" or "Wuber driver · 50s to Undercity".
-- A Pioneer (the shipped W.PIONEERS lists only, never a network claim) gets the Pioneer
-- variant instead of the plain driver badge, and the Pioneer line; the founder's crown wins.
--
-- Moo's proven rules for anything drawn on a nameplate: GetNamePlateForUnit under pcall,
-- skip secret and forbidden (instance) plates, ONE anchor point to the plate and an explicit
-- size, never read the plate's size, scale or position, parent to the plate under pcall
-- (UIParent if refused), drop any old frame when a token is re-added, release on
-- NAME_PLATE_UNIT_REMOVED, a 2 s sweep for names that arrive late and badges that expire,
-- at most 10 frames, pooled. Game settings (CVars) change only from the Settings button.
--
--   W.Plates.Refresh(), W.Plates.TurnOnFriendlyPlates(), W.Plates.FriendlyPlatesOn(),
--   W.Plates.Count()

local _, W = ...
local Mod = W.Module("FX.Nameplates", { "Theme.Widgets" })

local P = {}
W.Plates = P

local MAX_FRAMES = 10
local CROWN_SIZE = 46        -- px: the crown frame (the crown fills about 80% of it)
local BADGE_SIZE = 26
local CROWN_GAP = 2          -- px between the plate's top and the crown frame's bottom
local BADGE_GAP = 2
local PIONEER_SIZE = 22      -- the Pioneer variant's disc
local MOO_LIFT = 40          -- Moo draws a cow over guildies: sit clear above it
local FRIENDLY_CVARS = { "nameplateShowFriends", "nameplateShowFriendlyPlayers" }
local SELF_REF_ZOOM = 12     -- camera distance (yards) at which your own crown is its base size

local byUnit = {}            -- [unit token] = holder
local free = { crown = {}, badge = {}, pioneer = {} }
local count = 0

-- FX.Emblem's hook slot (it loads later and fills it): plate events and the 2 s sweep reach it.
Mod.emblem = nil
local function emblem(what, unit)
	local e = Mod.emblem
	if type(e) == "table" and type(e[what]) == "function" then W.Safe("emblem", e[what], unit) end
end

local function call(obj, m, ...)
	if obj == nil then return nil end
	local f = obj[m]
	if type(f) ~= "function" then return nil end
	local ok, a, b, c = pcall(f, obj, ...)
	if ok then return a, b, c end
	return nil
end

local function api(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return W.Plain(a), W.Plain(b) end
	return nil
end

local function wanted()
	return not (W.db and W.db.plates == false)
end

local mooLoaded
local function mooHere()
	if mooLoaded ~= nil then return mooLoaded end
	mooLoaded = false
	local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
	for _, name in ipairs({ "Moo", "MooForever" }) do
		if api(isLoaded, name) then mooLoaded = true end
	end
	return mooLoaded
end
P.MooLoaded = function() mooLoaded = nil return mooHere() end

---------------------------------------------------------------------------
-- Who gets what
---------------------------------------------------------------------------

-- The key of a nameplate's player, or nil (not a player, secret, unknown).
local function playerKey(unit)
	if api(UnitIsPlayer, unit) ~= true then return nil end
	local name = W.UnitName(unit)
	if not name then return nil end
	return W.Key(name), name
end

local function driverFor(key)
	local d = key and type(W.drivers) == "table" and W.drivers[key]
	if type(d) ~= "table" then return nil end
	if W.db and type(W.db.hidden) == "table" and W.db.hidden[key] then return nil end
	return d
end

-- "rider" / "driver" for a Pioneer (Theme.Widgets: the shipped list; a founder: nil), else nil
local function pioneerOf(key)
	local T = W.Theme
	if not key or type(T) ~= "table" or type(T.PioneerLook) ~= "function" then return nil end
	return T.PioneerLook(key)
end

-- "crown", "pioneer" (with "rider" / "driver"), "badge" (with the badge id) or nil
local function lookFor(key)
	if not key then return nil end
	if W.IsCreator(key) then return "crown" end
	local pioneer = pioneerOf(key)
	if pioneer then return "pioneer", pioneer end
	local d = driverFor(key)
	local badge = d and W.Str(d.badge)
	if badge and W.FX and W.FX.Has("badge_" .. badge) then return "badge", badge end
	return nil
end
P.LookFor = lookFor

---------------------------------------------------------------------------
-- Plates
---------------------------------------------------------------------------

local function getPlate(unit)
	if not (C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function") then return nil end
	local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
	if not ok or W.Plain(plate) == nil or type(plate) ~= "table" then return nil end
	if plate.IsForbidden then
		local okF, forbidden = pcall(plate.IsForbidden, plate)
		if not okF or W.Plain(forbidden) ~= false then return nil end -- (a secret is never compared)
	end
	return plate
end
P.GetPlate = getPlate

local function newHolder(kind, badge)
	local fx = W.FX
	if not fx then return nil end
	local h
	if kind == "crown" then
		h = fx.Crown(UIParent, CROWN_SIZE, 0)
	elseif kind == "pioneer" then
		local T = W.Theme
		h = T and type(T.PioneerBadge) == "function" and T.PioneerBadge(UIParent, badge, PIONEER_SIZE, false) or nil
	else
		h = fx.Badge(UIParent, badge, BADGE_SIZE)
	end
	if not h then return nil end
	h.plateKind = kind
	call(h, "SetFrameStrata", "BACKGROUND") -- behind the Drive button's and console's text, like your own crown
	call(h, "EnableMouse", false)
	h:Hide()
	return h
end

local function release(h)
	if not h then return end
	h:Hide()
	h:ClearAllPoints()
	pcall(h.SetParent, h, UIParent)
	h.unit, h.plate, h.key = nil, nil, nil
	local list = free[h.plateKind or "badge"]
	list[#list + 1] = h
end

local function drop(unit)
	local h = byUnit[unit]
	if h then
		byUnit[unit] = nil
		count = count - 1
		release(h)
	end
end

local function place(h, plate)
	h:ClearAllPoints()
	if not pcall(h.SetParent, h, plate) then pcall(h.SetParent, h, UIParent) end
	call(h, "SetScale", 1)
	if h.plateKind == "crown" then
		h:SetSize(CROWN_SIZE, CROWN_SIZE)
		h:SetPoint("BOTTOM", plate, "TOP", 0, CROWN_GAP + (mooHere() and MOO_LIFT or 0))
	else
		local size = h.plateKind == "pioneer" and PIONEER_SIZE or BADGE_SIZE
		h:SetSize(size, size)
		h:SetPoint("BOTTOM", plate, "TOP", 0, BADGE_GAP)
	end
end

local function attach(unit, plate, kind, badge, key)
	local h = table.remove(free[kind])
	if h and kind == "badge" and h.SetBadge then
		if not h:SetBadge(badge) then
			free[kind][#free[kind] + 1] = h
			h = nil
		end
	end
	if h and kind == "pioneer" and h.SetKind then h:SetKind(badge) end
	if not h then h = newHolder(kind, badge) end
	if not h then return nil end
	local ok = pcall(place, h, plate)
	if not ok then
		release(h)
		return nil
	end
	if kind == "crown" and h.SetSeed then h:SetSeed(key) end
	h.unit, h.plate, h.key, h.badgeId = unit, plate, key, badge
	h:Show()
	if h.Refresh then h:Refresh() end
	return h
end

local function tryUnit(unit)
	if byUnit[unit] or not wanted() then return end
	if count >= MAX_FRAMES then return end
	if api(UnitIsUnit, unit, "player") == true then return end -- yours is drawn mid-screen
	local key = playerKey(unit)
	local kind, badge = lookFor(key)
	if not kind then return end
	local plate = getPlate(unit)
	if not plate then return end
	local h = attach(unit, plate, kind, badge, key)
	if h then
		byUnit[unit] = h
		count = count + 1
	end
end

function P.OnPlateAdded(unit)
	unit = W.Str(unit)
	if not unit then return end
	drop(unit) -- tokens are recycled: never keep an old frame on a re-added token
	tryUnit(unit)
	emblem("Added", unit)
end

function P.OnPlateRemoved(unit)
	unit = W.Str(unit)
	if not unit then return end
	drop(unit)
	emblem("Removed", unit)
end

function P.ReleaseAll()
	for unit in pairs(byUnit) do drop(unit) end
end

-- Every 2 s: pick up players whose names arrived after their plate, and drop frames whose
-- player changed, stopped driving, changed badge or moved to another plate.
function P.Sweep()
	emblem("Sweep") -- its own setting: not tied to the crowns and badges
	if not wanted() then
		P.ReleaseAll()
		return
	end
	for unit, h in pairs(byUnit) do
		local keep = api(UnitExists, unit) == true
		if keep then
			local key = playerKey(unit)
			local kind, badge = lookFor(key)
			keep = key == h.key and kind == h.plateKind and (kind == "crown" or badge == h.badgeId) and getPlate(unit) == h.plate
		end
		if not keep then drop(unit) end
	end
	for i = 1, 40 do
		local unit = "nameplate" .. i
		if not byUnit[unit] and api(UnitExists, unit) == true then tryUnit(unit) end
	end
end

function P.Count() return count end

---------------------------------------------------------------------------
-- Your own crown: your character stays in the middle of the screen while the camera follows
-- you, so the crown is pinned just above the middle and scaled with the camera's zoom.
---------------------------------------------------------------------------

local selfCrown
local selfTicker

local function cameraZoom()
	local z = W.Num(api(GetCameraZoom))
	if z and z >= 0 then return z end
	return nil
end

local function placeSelf()
	local h = selfCrown
	if not h then return end
	local zoom = cameraZoom()
	if zoom and zoom < 0.8 then
		h:SetAlpha(0) -- first person: nothing to crown
		return
	end
	h:SetAlpha(1)
	local k = zoom and math.max(0.35, math.min(2.5, SELF_REF_ZOOM / zoom)) or 1
	local up = 34
	if api(IsMounted) == true then up = up + 22 end
	if mooHere() then up = up + MOO_LIFT * 0.5 end
	if h.lastK ~= k or h.lastUp ~= up then
		h.lastK, h.lastUp = k, up
		call(h, "SetScale", k)
		h:ClearAllPoints()
		-- offsets are in the crown's own (scaled) units: up px of screen at zoom k is up * k / k
		h:SetPoint("BOTTOM", UIParent, "CENTER", 0, up)
	end
end

local function selfWanted()
	return wanted() and W.IsCreator(W.myKey or W.Me())
end

function P.EnsureSelf()
	if not selfWanted() then
		if selfCrown then selfCrown:Hide() end
		if selfTicker then
			selfTicker:Cancel()
			selfTicker = nil
		end
		return
	end
	if not selfCrown then
		selfCrown = W.FX and W.FX.Crown(UIParent, CROWN_SIZE, W.myKey or "me")
		if not selfCrown then return end
		call(selfCrown, "SetFrameStrata", "BACKGROUND")
		call(selfCrown, "EnableMouse", false)
		selfCrown.isSelf = true
		-- (decisions H) a tooltip that says what the floating crown is. It answers the mouse moving over it only,
		-- and only where the client can turn clicks off for a frame: a click always goes through to the game world.
		if type(selfCrown.SetMouseMotionEnabled) == "function" and type(selfCrown.SetMouseClickEnabled) == "function" then
			call(selfCrown, "SetMouseMotionEnabled", true)
			call(selfCrown, "SetMouseClickEnabled", false)
		end
		if W.Theme and W.Theme.Tip then
			W.Theme.Tip(selfCrown, "Wuber founder", "Your founder's crown. It shows on your card, pin and over your head by itself; it can't be picked or given to anyone else.")
		end
	end
	placeSelf()
	selfCrown:Show()
	if selfCrown.Refresh then selfCrown:Refresh() end
	if not selfTicker then selfTicker = W.Every(0.2, placeSelf) end
end
P.SelfCrown = function() return selfCrown end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

function P.Refresh()
	if not wanted() then
		P.ReleaseAll()
	else
		-- re-place every frame (Moo may have loaded) and pick up new ones
		for unit, h in pairs(byUnit) do
			if not pcall(place, h, h.plate) then drop(unit) end
		end
		P.Sweep()
	end
	P.EnsureSelf()
end

local function readCVar(name)
	local v
	if C_CVar and type(C_CVar.GetCVar) == "function" then
		v = api(C_CVar.GetCVar, name)
	elseif type(GetCVar) == "function" then
		v = api(GetCVar, name)
	end
	if v == nil then return nil end
	return tostring(v)
end

local function writeCVar(name, value)
	local ok = false
	if C_CVar and type(C_CVar.SetCVar) == "function" then
		ok = pcall(C_CVar.SetCVar, name, tostring(value))
	elseif type(SetCVar) == "function" then
		ok = pcall(SetCVar, name, tostring(value))
	end
	return ok
end

-- true / false, or nil when the client does not say.
function P.FriendlyPlatesOn()
	local known = false
	for _, name in ipairs(FRIENDLY_CVARS) do
		local v = readCVar(name)
		if v ~= nil then
			known = true
			if v == "1" then return true end
		end
	end
	if known then return false end
	return nil
end

local function tell(text, kind)
	if W.UI and type(W.UI.Toast) == "function" then
		local ok = pcall(W.UI.Toast, text, kind)
		if ok then return end
	end
	W.Print(text)
end

-- Only ever from the Settings button (a click), out of combat.
function P.TurnOnFriendlyPlates()
	if W.InCombat() then
		tell("Can't change nameplates in combat. Try again after the fight.", "error")
		return false
	end
	local done = false
	for _, name in ipairs(FRIENDLY_CVARS) do
		if readCVar(name) ~= nil then done = writeCVar(name, "1") or done end
	end
	if done then
		tell("Friendly nameplates are on: crowns and badges show over heads. Shift+V turns them off.")
		W.After(0.5, P.Sweep)
	else
		tell("Couldn't switch them on from here. Press Shift+V, or turn on friendly nameplates in the game's settings.", "error")
	end
	return done
end

---------------------------------------------------------------------------
-- Tooltip line: "Wuber founder" / "Wuber driver · 50s to Undercity"
---------------------------------------------------------------------------

local CROWN_ICON = "|TInterface\\AddOns\\Wuber\\Media\\fx\\crown:16:16:0:0:512:256:2:62:2:62|t"

local function badgeIcon(id)
	local first = W.FX and W.FX.BadgeFirst and W.FX.BadgeFirst(id)
	if not first then return "" end
	local col, row = first % 8, math.floor(first / 8)
	return ("|TInterface\\AddOns\\Wuber\\Media\\fx\\badges:14:14:0:0:512:512:%d:%d:%d:%d|t "):format(
		col * 64 + 2, col * 64 + 62, row * 64 + 2, row * 64 + 62)
end

local PIN_ICON = "|TInterface\\AddOns\\Wuber\\Media\\pin:14:14|t"

local function lineFor(key)
	if W.IsCreator(key) then
		return CROWN_ICON .. " Wuber founder", 0.976, 0.773, 0.243
	end
	-- a Pioneer's line (under the driver's, when he drives)
	local pioneer = pioneerOf(key)
	local pio = pioneer and W.Theme.PIONEER[pioneer]
	local d = driverFor(key)
	if not d then
		if not pio then return nil end
		local r, g, b = W.Theme.RGB(pio.colour)
		return PIN_ICON .. " " .. pio.tip, r, g, b
	end
	local text = "Wuber driver"
	local price = W.Num(d.price)
	local dest = W.Str(d.dest)
	if price and dest then
		text = text .. " · " .. W.Money(price) .. " to " .. dest
	elseif dest then
		text = text .. " · to " .. dest
	end
	if pio then text = text .. "\n" .. W.Theme.Code(pio.colour) .. pio.tip .. "|r" end
	return badgeIcon(W.Str(d.badge)) .. text, 0.804, 0.490, 0.961
end
P.TooltipLine = lineFor

local lastAdded -- the text added to the tooltip last time (a tooltip can be rebuilt twice)

local function onTooltip(tooltip)
	if tooltip ~= GameTooltip or W.InCombat() then return end
	if api(UnitIsPlayer, "mouseover") ~= true then return end
	local name = W.UnitName("mouseover")
	local key = name and W.Key(name)
	if not key then return end
	local text, r, g, b = lineFor(key)
	if not text then return end
	-- already there (the same tooltip passed through twice)?
	local n = W.Num(call(tooltip, "NumLines")) or 0
	if n > 0 and lastAdded == text then
		local fs = _G and _G["GameTooltipTextLeft" .. n]
		local have = fs and W.Str(call(fs, "GetText"))
		if have == text then return end
	end
	pcall(tooltip.AddLine, tooltip, text, r, g, b)
	lastAdded = text
end

local hooked = false
local function hookTooltip()
	if hooked then return end
	local fn = function(tooltip)
		local ok, err = pcall(onTooltip, tooltip)
		if not ok then W.Error("tooltip", err) end
	end
	local tdp = TooltipDataProcessor
	local unitType = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit
	if type(tdp) == "table" and type(tdp.AddTooltipPostCall) == "function" and unitType ~= nil then
		if pcall(tdp.AddTooltipPostCall, unitType, fn) then hooked = true end
		return -- one path only
	end
	if GameTooltip and type(GameTooltip.HookScript) == "function" then
		if pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", fn) then hooked = true end
	end
end
P.HookTooltip = hookTooltip

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

W.On("NAME_PLATE_UNIT_ADDED", function(unit) P.OnPlateAdded(unit) end)
W.On("NAME_PLATE_UNIT_REMOVED", function(unit) P.OnPlateRemoved(unit) end)
W.On("PLAYER_ENTERING_WORLD", function()
	-- a new zone rebuilds the plates
	P.ReleaseAll()
	emblem("ReleaseAll")
	W.After(1, function()
		P.Sweep()
		P.EnsureSelf()
	end)
end)

W.Listen("SETTINGS", function(key)
	if key == nil or key == "plates" then P.Refresh() end
end)
W.Listen("DRIVERS", function()
	-- a beacon brought a badge or took one away: the sweep sorts it out (cheap)
	if wanted() then P.Sweep() end
end)

W.OnLogin(function()
	hookTooltip()
	W.Every(2, P.Sweep)
	P.EnsureSelf()
end)
