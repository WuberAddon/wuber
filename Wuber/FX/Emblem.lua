-- Module: FX.Emblem
-- Purpose: the Pioneers' floating emblem: Wuber's own small swirling portal
--   over a listed Pioneer's nameplate, seen by other Wuber users in the open world; Pioneer Drivers in
--   teal; the founders' crown wins; a local-only preview over your own head.
-- API: W.Emblem, W.EmblemHeard, W.EmblemFlag
-- Internals: (none)
-- Uses: FX.Effects, FX.Nameplates, Theme.Widgets
-- Later: UI.UpdateSettings (the chat command moves an open Settings switch)
-- Events: listens (none: FX.Nameplates calls it through its hook slot); fires (none); sets
--   FX.Nameplates.emblem
-- Standalone: no
-- Test: tests/fx/emblem_test.lua
-- From: new in 2.3.2
--
-- Who gets one: ONLY a name on the shipped list (W.PioneerKind, Core.Base). No network field, saved
-- value or other player's claim can ever give an emblem. With the shipped lists empty nothing is
-- made: no frame, no model, no ticker, nothing sent. The founders (W.IsCreator) keep their crown and
-- never get an emblem. A Pioneer can hide their own: WuberDB.myEmblem = false hides it over their own
-- head and adds a hide-only flag ("0") to the messages they already send (driver beacon field 20,
-- the Q ping's field 2). The flag can only ever hide an emblem the list already gives.
--
-- Where: on the nameplate (Moo's rules, as FX.Nameplates: one anchor, explicit size, never read the
-- plate's size or position, parent under pcall), only with friendly nameplates on and never inside an
-- instance (the game forbids friendly plates there); only the /wuber emblem preview, which nobody else
-- sees, also shows there and with emblems off (a forbidden plate is still skipped). One holder per visible Pioneer, pooled, at
-- most 6. No text anywhere in a holder (the portal sprite, a ring texture and a glow); no Scale animation.
--
-- The art: Wuber's own summoning portal, rendered in Blender like the founder's
-- crown (tools/emblem/: portal_blend.py, make_emblem.py): an open swirling vortex with a bright core,
-- a gold rune ring turning the other way, gold sparks and a soft glow, 32 frames of 128 px in a
-- 1024x512 atlas per colour (ATLAS: Media/fx/emblem.tga violet for riders, emblem_teal.tga for
-- Pioneer Drivers), the crown's grid. The 32 frames are one seamless loop (the six-fold ring's
-- 60-degree turn, the swirl's 120); the holder steps them with SetTexCoord at the look's spin (radians a second), held still
-- when effects are off (FX.Mode, as the crown). Only if the atlas won't load is Wuber's flat ring.tga
-- turned instead. The look (LOOKS 1-3: size, height, speed; default 2, the Orb, the author's pick) is
-- picked with "/wuber emblem 1|2|3"; "/wuber emblem preview" shows the emblem over your own head
-- (and your target's nameplate) for two minutes, on this screen only.
--
--   W.Emblem.Kind(key), .Added(unit), .Removed(unit), .Sweep(), .ReleaseAll(), .Count(), .Look(),
--   .SetLook(n), .Preview(on, kind), .Previewing(), .Status(), .Command(text), .Active(), .Mine(),
--   .SelfHolder(), .LOOKS, .ATLAS, .FrameCoords(i), .Colour(kind)
--   W.EmblemHeard(nameOrKey, flag)   a heard message's hide flag ("0": hidden; anything else: shown)
--   W.EmblemFlag()                   "0" when I am a Pioneer who hid my emblem, else nil

local _, W = ...
local Mod = W.Module("FX.Emblem", { "FX.Effects", "FX.Nameplates", "Theme.Widgets" })
local NameplatesMod = W.Mod("FX.Nameplates")
local EffectsMod = W.Mod("FX.Effects")

local E = {}
W.Emblem = E

local MEDIA = "Interface\\AddOns\\Wuber\\Media\\"
local MAX_FRAMES = 6
local GAP = 2               -- px between the plate's top and the emblem
local BADGE_LIFT = 28       -- over a driver's badge (26 px + its gap)
local MOO_LIFT = 40         -- the crown's own lift over Moo's cow (FX.Nameplates MOO_LIFT)
local CROWN_LIFT = 50       -- over a founder's crown (46 px + its gap; only in the preview)
local PREVIEW_SECS = 120
local HEARD_TTL = 6 * 3600  -- s: a heard "emblem off" is forgotten after this
local TICK = 1 / 30         -- s: the spin's frame step

-- The colours: the Pioneer badge's own theme tokens (T.PIONEER[kind].colour: riders "glow" violet,
-- drivers "teal"), so badge and emblem are always one colour. Gold stays the founders'.
-- { r, g, b } for kind ("rider"/"driver"; anything else: the riders').
function E.Colour(kind)
	local T = W.Theme
	local look = T.PIONEER[kind] or T.PIONEER.rider
	local r, g, b = T.RGB(look.colour)
	return { r, g, b }
end

-- The three looks (size and lift in px, spin in radians a second). the author picked 2, the Orb:
-- it is the default; the others stay for "/wuber emblem 1|3".
E.LOOKS = {
	{ name = "Ring", desc = "a small portal just above the name, quicker", size = 44, lift = 4, spin = 0.9, alpha = 1, glow = 1.5 },
	{ name = "Orb", desc = "Wuber's portal, bigger and higher up", size = 64, lift = 18, spin = 0.6, alpha = 1, glow = 1.7 },
	{ name = "Spark", desc = "a small faint portal, slow", size = 32, lift = 2, spin = 0.4, alpha = 0.75, glow = 1.3 },
}
local DEFAULT_LOOK = 2

-- The art: the crown's grid (Media/fx, made by tools/emblem/make_emblem.py). One file per colour;
-- frames run row by row; the 32 frames are one loop: a 60-degree turn of the portal's six-fold ring (turn).
E.ATLAS = {
	rider = MEDIA .. "fx\\emblem", driver = MEDIA .. "fx\\emblem_teal",
	w = 1024, h = 512, cell = 128, cols = 8, frames = 32, turn = math.pi / 3,
}
local A = E.ATLAS
local HALO_ALPHA = 0.5  -- the art carries its own bloom: the glow behind is a soft lift only

-- Left, right, top, bottom of frame i (0-based, wraps) in the atlas (FX.Effects' frameCoords).
function E.FrameCoords(i)
	i = math.floor(i) % A.frames
	local col = i % A.cols
	local row = math.floor(i / A.cols)
	local l, t = col * A.cell / A.w, row * A.cell / A.h
	return l, l + A.cell / A.w, t, t + A.cell / A.h
end

local byUnit = {}     -- [unit token] = holder on a plate
local free = {}       -- pooled holders
local count = 0
local heardOff = {}   -- [key] = time a hide flag was heard
local selfH           -- the emblem over my own head (mine, or the preview)
local selfTicker
local spinner         -- the one frame whose OnUpdate turns every shown emblem
local preview = { on = false, kind = "rider", till = 0 }

local function call(obj, m, ...)
	if obj == nil then return nil end
	local f = obj[m]
	if type(f) ~= "function" then return nil end
	local ok, a, b = pcall(f, obj, ...)
	if ok then return a, b end
	return nil
end

local function api(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return W.Plain(a) end
	return nil
end

local function now() return W.Now() end
local function say(text) W.Print(text) end

---------------------------------------------------------------------------
-- Who gets one
---------------------------------------------------------------------------

-- Any name on the shipped lists at all (cheap: nothing is done while they are empty).
local function listsEmpty()
	local P = W.PIONEERS
	if type(P) ~= "table" then return true end
	for _, part in ipairs({ P.riders, P.drivers }) do
		if type(part) == "table" then
			for _, names in pairs(part) do
				if type(names) == "table" and #names > 0 then return false end
			end
		end
	end
	return true
end

local function wanted() return not (W.db and W.db.emblems == false) end

local function look()
	local n = W.Num(W.db and W.db.emblemLook)
	return (n and E.LOOKS[n]) and n or DEFAULT_LOOK
end
E.Look = look

local function hiddenByFlag(key)
	local at = heardOff[key]
	if not at then return false end
	if now() - at > HEARD_TTL then
		heardOff[key] = nil
		return false
	end
	return true
end

-- "rider", "driver" or nil: the emblem a player's key gets on this client.
function E.Kind(key)
	if not key or listsEmpty() then return nil end
	if W.IsCreator(key) then return nil end -- the founders' crown wins
	local kind = W.PioneerKind(key)
	if not kind or hiddenByFlag(key) then return nil end
	return kind
end

-- A heard message's hide flag. Only ever hides: a name not on the list stays without an emblem.
function W.EmblemHeard(nameOrKey, flag)
	if listsEmpty() then return end
	local key = W.Key(nameOrKey)
	if not key or not W.PioneerKind(key) then return end
	if flag == "0" then
		heardOff[key] = now()
	else
		heardOff[key] = nil
	end
end

local function myKey() return W.myKey or W.Key(W.Me()) end

local function iAmPioneer()
	if listsEmpty() then return nil end
	local k = myKey()
	if not k or W.IsCreator(k) then return nil end
	return W.PioneerKind(k)
end

-- Whether the shipped lists name anyone (Settings shows the emblem rows only then); my own kind.
E.Active = function() return not listsEmpty() end
E.Mine = function() return iAmPioneer() end

-- "0" when I am a Pioneer who hid my emblem (then my beacon and pings carry it), else nil.
function W.EmblemFlag()
	if not (W.db and W.db.myEmblem == false) then return nil end
	if not iAmPioneer() then return nil end
	return "0"
end

---------------------------------------------------------------------------
-- The holder: a frame with a glow, the orb sprite and (only if the atlas won't load) a flat ring
---------------------------------------------------------------------------

-- Frames a second: the atlas's turn at the holder's spin (radians a second).
local function fps(h) return A.frames * (h.speed or 0.6) / A.turn end

-- Effects off: the orb holds still (as the founder's crown).
local function still()
	local FX = EffectsMod and W.FX
	return FX and type(FX.Mode) == "function" and FX.Mode() == "off" or false
end

local function showFrame(h)
	local i = math.floor(h.pos or 0) % A.frames
	if h.shown == i then return end
	h.shown = i
	h.orb:SetTexCoord(E.FrameCoords(i))
end

local function spin(dt)
	local any = false
	local hold = still()
	local function turn(h)
		if not (h and h:IsShown()) then return end
		any = true
		if hold then return end
		if h.flat then
			h.angle = ((h.angle or 0) + dt * (h.speed or 0.6)) % (2 * math.pi)
			call(h.ring, "SetRotation", h.angle)
		else
			h.pos = ((h.pos or 0) + dt * fps(h)) % A.frames
			showFrame(h)
		end
	end
	for _, h in pairs(byUnit) do turn(h) end
	turn(selfH)
	if not any and spinner then spinner:Hide() end
end

local function ensureSpinner()
	if spinner then
		spinner:Show()
		return
	end
	spinner = CreateFrame("Frame", nil, UIParent)
	local acc = 0
	spinner:SetScript("OnUpdate", function(_, dt)
		acc = acc + (W.Num(dt) or 0)
		if acc < TICK then return end
		local step = acc
		acc = 0
		local ok, err = pcall(spin, step)
		if not ok then
			spinner:Hide()
			W.Error("emblem", err)
		end
	end)
end

-- The orb's atlas for a kind. If the client refuses the file, the flat ring is drawn instead.
local function setArt(h, kind)
	local path = kind == "driver" and A.driver or A.rider
	if h.art == path then return end
	h.art = path
	local ok, res = pcall(h.orb.SetTexture, h.orb, path)
	h.flat = not ok or res == false
	if h.flat then
		h.orb:Hide()
		h.ring:Show()
	else
		h.ring:Hide()
		h.orb:Show()
	end
end

local function newHolder()
	local h = CreateFrame("Frame", nil, UIParent)
	call(h, "EnableMouse", false)
	call(h, "SetFrameStrata", "BACKGROUND") -- behind the Drive button's and console's text (a plate badge too)
	h.halo = h:CreateTexture(nil, "BACKGROUND")
	h.halo:SetTexture(MEDIA .. "glow")
	call(h.halo, "SetBlendMode", "ADD")
	h.halo:SetPoint("CENTER", h, "CENTER", 0, 0)
	h.orb = h:CreateTexture(nil, "ARTWORK")
	call(h.orb, "SetBlendMode", "BLEND")
	h.orb:SetAllPoints(h)
	h.ring = h:CreateTexture(nil, "ARTWORK")
	h.ring:SetTexture(MEDIA .. "ring")
	call(h.ring, "SetBlendMode", "ADD")
	h.ring:SetAllPoints(h)
	h.ring:Hide()
	h:Hide()
	return h
end

-- Size, colour, speed and art for a kind ("rider"/"driver") in the current look. The orb carries its
-- own colours; the glow behind it and the fallback ring take the kind's theme colour. Each emblem
-- starts on its own frame (from the key), so emblems side by side don't turn in step.
local function dress(h, kind, key)
	local L = E.LOOKS[look()]
	h.kind, h.look = kind, look()
	h.speed = L.spin
	h:SetSize(L.size, L.size)
	h.halo:SetSize(L.size * L.glow, L.size * L.glow)
	h:SetAlpha(L.alpha)
	local c = E.Colour(kind)
	h.halo:SetVertexColor(c[1], c[2], c[3], HALO_ALPHA)
	h.ring:SetVertexColor(c[1], c[2], c[3], 1)
	setArt(h, kind)
	local FX = EffectsMod and W.FX
	h.pos = (key and FX and type(FX.Hash) == "function") and (FX.Hash(key) % A.frames) or 0
	h.shown = nil
	if not h.flat then showFrame(h) end
end

local function release(h)
	if not h then return end
	h:Hide()
	h:ClearAllPoints()
	pcall(h.SetParent, h, UIParent)
	h.unit, h.plate, h.key = nil, nil, nil
	free[#free + 1] = h
end

local function drop(unit)
	local h = byUnit[unit]
	if h then
		byUnit[unit] = nil
		count = count - 1
		release(h)
	end
end

---------------------------------------------------------------------------
-- On nameplates
---------------------------------------------------------------------------

local function plates() return W.Plates end

local function place(h, plate, key)
	h:ClearAllPoints()
	if not pcall(h.SetParent, h, plate) then pcall(h.SetParent, h, UIParent) end
	call(h, "SetScale", 1)
	local P = plates()
	local under = P and P.LookFor and P.LookFor(key) -- a badge (or, in the preview, a crown) sits on the plate: go above it
	if W.db and W.db.plates == false then under = nil end -- crowns and badges off: nothing is drawn there, so nothing to clear
	local lift = (under == "crown" and CROWN_LIFT) or (under and BADGE_LIFT) or 0
	if under == "crown" and P.MooLoaded and P.MooLoaded() then lift = lift + MOO_LIFT end -- the crown itself sits above Moo's cow
	h:SetPoint("BOTTOM", plate, "TOP", 0, GAP + E.LOOKS[look()].lift + lift)
end

local function blocked() return not wanted() or W.InInstance() end

-- The preview over my target is only on my screen, so it shows in an instance and with emblems off too.
local function previewTarget(unit) return preview.on and api(UnitIsUnit, unit, "target") == true end

-- The kind a unit's emblem has: the list's, or the preview's over my target.
local function kindForUnit(unit)
	if api(UnitIsPlayer, unit) ~= true then return nil end
	local name = W.UnitName(unit)
	local key = name and W.Key(name)
	if not key then return nil end
	-- the preview over my target: anyone, even a founder (it is only on my screen; it sits above the crown)
	if preview.on and api(UnitIsUnit, unit, "target") == true then return preview.kind, key end
	return E.Kind(key), key
end

local function tryUnit(unit)
	if byUnit[unit] or count >= MAX_FRAMES or (blocked() and not previewTarget(unit)) then return end
	if api(UnitIsUnit, unit, "player") == true then return end -- mine is drawn mid-screen
	local kind, key = kindForUnit(unit)
	if not kind then return end
	local P = plates()
	local plate = P and P.GetPlate and P.GetPlate(unit)
	if not plate then return end
	local h = table.remove(free) or newHolder()
	if not pcall(place, h, plate, key) then
		release(h)
		return
	end
	h.unit, h.plate, h.key = unit, plate, key
	dress(h, kind, key)
	h:Show()
	byUnit[unit] = h
	count = count + 1
	ensureSpinner()
end

function E.Added(unit)
	unit = W.Str(unit)
	if not unit then return end
	drop(unit)
	if listsEmpty() and not preview.on then return end
	tryUnit(unit)
end

function E.Removed(unit)
	unit = W.Str(unit)
	if unit then drop(unit) end
end

function E.ReleaseAll()
	for unit in pairs(byUnit) do drop(unit) end
end

function E.Count() return count end

---------------------------------------------------------------------------
-- Over my own head (a Pioneer's own, or the preview): mid-screen, sized by the camera's zoom
---------------------------------------------------------------------------

local function placeSelf()
	local h = selfH
	if not (h and h:IsShown()) then return end
	if preview.on and now() >= preview.till then
		E.Preview(false)
		return
	end
	local zoom = W.Num(api(GetCameraZoom))
	if zoom and zoom < 0.8 then
		h:SetAlpha(0) -- first person
		return
	end
	h:SetAlpha(E.LOOKS[look()].alpha)
	local k = zoom and zoom > 0 and math.max(0.35, math.min(2.5, 12 / zoom)) or 1
	local up = 40 + E.LOOKS[look()].lift
	if api(IsMounted) == true then up = up + 22 end
	local P = plates()
	local crown = preview.on and P and P.SelfCrown and P.SelfCrown()
	if crown and crown:IsShown() then -- a founder's own crown is over the head: the preview sits above it (crown is 46 high)
		local _, _, _, _, cy = crown:GetPoint(1)
		cy = W.Num(cy)
		if cy then up = math.max(up, cy + 46 + E.LOOKS[look()].lift) end
	end
	if h.lastK ~= k or h.lastUp ~= up then
		h.lastK, h.lastUp = k, up
		call(h, "SetScale", k)
		h:ClearAllPoints()
		h:SetPoint("BOTTOM", UIParent, "CENTER", 0, up)
	end
end

local function selfKind()
	if preview.on then return preview.kind end
	if blocked() or (W.db and W.db.myEmblem == false) then return nil end
	return iAmPioneer()
end

local function ensureSelf()
	local kind = selfKind()
	if kind and W.InInstance() and not preview.on then kind = nil end
	if not kind then
		if selfH then selfH:Hide() end
		if selfTicker then
			selfTicker:Cancel()
			selfTicker = nil
		end
		return
	end
	if not selfH then
		selfH = newHolder()
		call(selfH, "SetFrameStrata", "BACKGROUND")
	end
	if selfH.kind ~= kind or selfH.look ~= look() or not selfH:IsShown() then dress(selfH, kind, myKey()) end
	selfH.lastK = nil
	selfH:Show()
	placeSelf()
	ensureSpinner()
	if not selfTicker then selfTicker = W.Every(0.2, placeSelf) end
end
E.SelfHolder = function() return selfH end

---------------------------------------------------------------------------
-- The sweep (every 2 s, from FX.Nameplates' ticker), settings and the preview
---------------------------------------------------------------------------

function E.Sweep()
	if (listsEmpty() and not preview.on) or (blocked() and not preview.on) then
		E.ReleaseAll()
		if selfH or preview.on then ensureSelf() end
		return
	end
	for unit, h in pairs(byUnit) do
		local keep = api(UnitExists, unit) == true
		if keep then
			local kind, key = kindForUnit(unit)
			local P = plates()
			keep = (not blocked() or previewTarget(unit)) and key == h.key and kind == h.kind and h.look == look() and P and P.GetPlate and P.GetPlate(unit) == h.plate
		end
		if not keep then drop(unit) end
	end
	for i = 1, 40 do
		local unit = "nameplate" .. i
		if not byUnit[unit] and count < MAX_FRAMES and api(UnitExists, unit) == true then tryUnit(unit) end
	end
	ensureSelf()
end

function E.SetLook(n)
	n = W.Num(n)
	if not (n and E.LOOKS[n]) then return false end
	W.db.emblemLook = n ~= DEFAULT_LOOK and n or nil -- the default (2, the Orb): nothing saved
	E.ReleaseAll()
	if selfH then selfH.look = nil end
	E.Sweep()
	return true
end

-- The local preview over my own head (and my target's nameplate): nothing is sent, nothing saved.
function E.Preview(on, kind)
	preview.on = on and true or false
	preview.kind = (kind == "driver") and "driver" or "rider"
	preview.till = now() + PREVIEW_SECS
	if selfH then selfH.kind = nil end
	E.ReleaseAll()
	E.Sweep()
	ensureSelf()
	return preview.on
end
E.Previewing = function() return preview.on, preview.kind end

-- What is showing and which art (for /wuber emblem and in-game checks; the field keeps its name "model").
function E.Status()
	local shown = selfH and selfH:IsShown() and selfH or nil
	if not shown then for _, h in pairs(byUnit) do shown = h break end end
	local model = "custom portal"
	if shown and shown.flat then model = "flat ring (the portal art didn't load)" end
	return { look = look(), lookName = E.LOOKS[look()].name, on = wanted(), count = count, preview = preview.on,
		previewKind = preview.kind, selfShown = selfH ~= nil and selfH:IsShown() and true or false,
		flat = shown and shown.flat or false, model = model, pioneer = iAmPioneer(), mineHidden = W.db and W.db.myEmblem == false }
end

local function lookLine(n)
	local L = E.LOOKS[n]
	return n .. " " .. L.name .. ": " .. L.desc
end

-- an open Settings page shows the new switch at once (UI loads later: called at run time, guarded)
local function syncSettings()
	local UI = W.UI
	if type(UI) == "table" and type(UI.UpdateSettings) == "function" then W.Safe("emblem settings", UI.UpdateSettings) end
end

-- "/wuber emblem [1|2|3|preview [driver]|stop|on|off|mine on|off]"
function E.Command(text)
	local a, b = (W.Str(text) or ""):lower():match("^(%S*)%s*(%S*)")
	local n = tonumber(a)
	if n and E.LOOKS[n] then
		E.SetLook(n)
		say("Pioneer emblem look " .. lookLine(look()) .. ".")
	elseif a == "preview" or a == "show" then
		local on = b == "driver" or b == "rider" or not preview.on
		E.Preview(on, b)
		if on then
			say("Preview on: " .. E.Status().model .. " (" .. preview.kind .. " colour, look " .. lookLine(look()) .. "). Only you see it; it ends in two minutes. /wuber emblem stop ends it now.")
		else
			say("Preview off.")
		end
	elseif a == "stop" then
		E.Preview(false)
		say("Preview off.")
	elseif a == "on" or a == "off" then
		if a == "off" then W.db.emblems = false else W.db.emblems = nil end
		E.Sweep()
		syncSettings()
		say(a == "on" and "Pioneer emblems over heads: on." or "Pioneer emblems over heads: off.")
	elseif a == "mine" then
		if not iAmPioneer() then
			say("You aren't on the Pioneer list, so you have no emblem to hide.")
		elseif b == "on" or b == "off" then
			if b == "off" then W.db.myEmblem = false else W.db.myEmblem = nil end
			E.Sweep()
			syncSettings()
			if W.SendBeacon then W.Safe("emblem beacon", W.SendBeacon) end -- others learn it now, not with the next beacon
			say(b == "on" and "Your Pioneer emblem shows again." or "Your Pioneer emblem is hidden, for you and for others with Wuber.")
		else
			say("Your Pioneer emblem: " .. (W.db.myEmblem == false and "hidden" or "showing") .. ". /wuber emblem mine on|off")
		end
	else
		local s = E.Status()
		say("Pioneer emblems: " .. (s.on and "on" or "off") .. ", look " .. lookLine(s.look) .. ". Art: " .. s.model .. ".")
		say("/wuber emblem 1|2|3 picks the look; /wuber emblem preview [driver] shows it over your head; on|off; mine on|off.")
	end
end

-- FX.Nameplates' hook slot: it calls these from its plate events and its 2 s sweep.
NameplatesMod.emblem = E
