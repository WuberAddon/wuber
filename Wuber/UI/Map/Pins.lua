-- Module: UI.Map.Pins
-- Purpose: Map pin widgets: tooltip, placing, levels, pulse, aura ring, crown/badge, creator sparkle, Paint.
-- API: (none)
-- Internals: AURA, Aura, CanvasMetrics, NewPin, Paint, Place, SetLevels, StopCreator, StopPulse, Tooltip
-- Uses: UI.Map.Base
-- Later: (none)
-- Events: listens Listen SETTINGS; fires (none)
-- Standalone: no
-- Test: tests/ui/map/pins_test.lua
-- From: Map.lua 382-863 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Map.Pins", { "UI.Map.Base" })
local BaseMod = W.Mod("UI.Map.Base")
local AMBER = BaseMod.AMBER
local Accent = BaseMod.Accent
local BRIGHT = BaseMod.BRIGHT
local BadgeInfo = BaseMod.BadgeInfo
local CREATOR_SCALE = BaseMod.CREATOR_SCALE
local Canvas = BaseMod.Canvas
local Driver = BaseMod.Driver
local ClickOver = BaseMod.ClickOver
local FILL = BaseMod.FILL
local GOLD = BaseMod.GOLD
local IsFav = BaseMod.IsFav
local MEDIA = BaseMod.MEDIA
local NewFrame = BaseMod.NewFrame
local PAUSED = BaseMod.PAUSED
local PIN = BaseMod.PIN
local ScaleTo = BaseMod.ScaleTo
local Seed = BaseMod.Seed
local Text = BaseMod.Text
local call = BaseMod.call
local hex = BaseMod.hex
local plainIcon = BaseMod.plainIcon

---------------------------------------------------------------------------
-- Three-colour aura ring (shared by world map pins and flight map markers)
---------------------------------------------------------------------------

local AURA = {
	violet = { 0.62, 0.42, 1.00 },
	gold = { 1.00, 0.82, 0.20 },
	teal = { 0.20, 0.85, 0.80 },
	outline = { 0.05, 0.04, 0.10, 0.90 },
}
local AURA_COLOURS = { AURA.violet, AURA.gold, AURA.teal }
local AURA_ANGLES = { 0, math.rad(120), math.rad(240) }
local AURA_PERIODS = { -14, 10, -18 }
local TWO_PI = math.pi * 2
local auras = setmetatable({}, { __mode = "k" })

local function FxLevel()
	local Th = W.Theme
	if type(Th) == "table" and type(Th.FxLevel) == "function" then
		local ok, lvl = pcall(Th.FxLevel)
		if ok and type(lvl) == "string" then return lvl end
	end
	local v = W.db and W.db.fx
	if v == "off" or v == "light" then return v end
	return "full"
end

local AuraMT = {}
AuraMT.__index = AuraMT

function AuraMT:Show()
	self.frame:Show()
end

function AuraMT:Hide()
	self:Stop()
	self.frame:Hide()
end

local function ApplyAuraSizes(frame, outline, arcs, inner)
	local px = W.Num(inner) or PIN
	if px <= 0 then px = PIN end
	local r = px / 2 + 9
	local outlineSize = 2 * (r + 3)
	local violetSize = 2 * r / 0.81
	frame:SetSize(outlineSize, outlineSize)
	outline:SetSize(outlineSize, outlineSize)
	for i = 1, 3 do
		local s = violetSize - (i - 1) * 6
		arcs[i]:SetSize(s, s)
	end
	return px
end

local function ResetArcs(arcs)
	for i = 1, 3 do
		local arc = arcs[i]
		if arc.SetRotation then pcall(arc.SetRotation, arc, AURA_ANGLES[i]) end
	end
end

function AuraMT:SetSize(inner)
	self.size = ApplyAuraSizes(self.frame, self.outline, self.arcs, inner)
end

function AuraMT:SetGold(on)
	on = on and true or false
	if self.gold == on then return end
	self.gold = on
	local g = on and ((W.Theme and W.Theme.C and W.Theme.C.gold) or GOLD) or nil
	for i = 1, 3 do
		local c = g or AURA_COLOURS[i]
		self.arcs[i]:SetVertexColor(c[1], c[2], c[3], 1)
	end
end

function AuraMT:Start()
	self.wantTurn = true
	self.frame:Show()
	if FxLevel() == "full" then
		self.turning = true
		self.driver:Show()
	else
		self.turning = false
		self.driver:Hide()
		ResetArcs(self.arcs)
	end
end

function AuraMT:Stop()
	self.wantTurn = false
	self.turning = false
	self.driver:Hide()
end

function AuraMT:Turning()
	return self.turning == true
end

local function Aura(host, inner)
	local frame = NewFrame("Frame", host)
	frame:SetPoint("CENTER", host, "CENTER", 0, 0)
	frame:EnableMouse(false)

	local outline = frame:CreateTexture(nil, "BACKGROUND")
	outline:SetTexture(MEDIA .. "ring")
	outline:SetPoint("CENTER", frame, "CENTER", 0, 0)
	outline:SetVertexColor(AURA.outline[1], AURA.outline[2], AURA.outline[3], AURA.outline[4])

	local arcs = {}
	for i = 1, 3 do
		local t = frame:CreateTexture(nil, "ARTWORK", nil, i)
		t:SetTexture(MEDIA .. "arc")
		t:SetPoint("CENTER", frame, "CENTER", 0, 0)
		local c = AURA_COLOURS[i]
		t:SetVertexColor(c[1], c[2], c[3], 1)
		if t.SetRotation then pcall(t.SetRotation, t, AURA_ANGLES[i]) end
		arcs[i] = t
	end

	local px = ApplyAuraSizes(frame, outline, arcs, inner)

	local driver = NewFrame("Frame", frame)
	driver:EnableMouse(false)
	driver:Hide()
	driver:SetScript("OnUpdate", function()
		local ok = pcall(function()
			local TH = W.Theme
			if TH and TH.ReduceMotion and TH.ReduceMotion() then return end -- (#305) Reduce motion: the aura stands still
			local now = type(GetTime) == "function" and (W.Num(GetTime()) or 0) or 0
			for i = 1, 3 do
				local arc = arcs[i]
				if arc.SetRotation then
					local p = AURA_PERIODS[i]
					local ap = math.abs(p)
					local turn = (now % ap) / ap
					local dir = p < 0 and -1 or 1
					arc:SetRotation(dir * turn * TWO_PI + AURA_ANGLES[i])
				end
			end
		end)
		if not ok then driver:Hide() end
	end)

	local aura = setmetatable({
		frame = frame,
		arcs = arcs,
		outline = outline,
		driver = driver,
		size = px,
		turning = false,
		wantTurn = false,
		gold = false,
	}, AuraMT)

	frame:SetScript("OnHide", function()
		aura:Stop()
	end)
	if host and type(host.HookScript) == "function" then
		pcall(host.HookScript, host, "OnHide", function()
			aura:Stop()
		end)
	end

	auras[aura] = true
	return aura
end

W.Listen("SETTINGS", function(what)
	if what ~= nil and what ~= "fx" then return end
	for a in pairs(auras) do
		if a.wantTurn and a.frame:IsShown() then
			a:Start()
		end
	end
end)

---------------------------------------------------------------------------
-- Pins
---------------------------------------------------------------------------

local function Tooltip(pin)
	-- (design 4) Wuber's own tip card (T.TipShow: a frame under UIParent, never under the game's map). The words
	-- are as they were; a line's colour is a theme token
	local Th = W.Theme
	local d = Driver(pin.key)
	if not (type(Th) == "table" and type(Th.TipShow) == "function" and d) then return end
	local name = Text(d.name, "?")
	local service = Text(d.service, name)
	local lines = {}
	local function add(words, colour) lines[#lines + 1] = { words, colour } end
	if service ~= name then add(name, "muted") end
	if pin.creator then add("Wuber founder", "gold") end
	-- a Pioneer: the shipped list only (Theme.Widgets' T.PioneerLook; a founder: none)
	local look = type(Th.PioneerLook) == "function" and Th.PioneerLook(pin.key) or nil
	local spec = look and type(Th.PIONEER) == "table" and Th.PIONEER[look] or nil
	-- the theme's Pioneer colour, as the badge and the app's map panel (UI.Rider.HomeMap)
	if spec then add(spec.tip, spec.colour) end
	local badge = BadgeInfo(d.badge)
	if badge then add(badge.name .. " badge", "glow") end
	local rank = W.Num(pin.rank ~= nil and pin.rank or d.rank)
	if rank and rank >= 1 and type(W.RankOf) == "function" then
		rank = math.floor(rank)
		local _, title = W.RankOf(rank)
		if title then add(title .. " · " .. rank, "white") end
	end
	if IsFav(pin.key) then add("One of your favourites", "glow") end
	add("To " .. Text(d.dest, "?"), "white")
	add(W.Money(W.Num(d.price) or 0), "gold")
	if d.state == "busy" then
		add("Busy right now", "muted")
	elseif d.state == "paused" then
		add("Paused", "off")
	end
	local team = W.Num(d.team) or 1
	if team >= 3 then
		add("No helpers needed", "muted")
	else
		local n = 3 - math.max(1, math.floor(team))
		add("Bring " .. n .. (n == 1 and " helper" or " helpers"), "muted")
	end
	if W.Num(d.seats) == 0 then add("Group full", "muted") end
	local queue = W.Num(d.queue)
	if queue and queue > 0 then
		add(math.floor(queue) .. (queue == 1 and " rider waiting" or " riders waiting"), "muted")
	end
	if W.myKey and pin.key == W.myKey then
		add("This is you", "muted")
	elseif d.state == "paused" then
		add("Can't take requests now", "muted")
	else
		add("Click to request", "glow")
	end
	Th.TipShow(pin, service, lines, "ANCHOR_RIGHT")
end

-- size and place one pin: constant size on screen (1 / canvas scale), centred on its spot
local function Place(pin, child, w, h, s)
	local scale = (1 / s) * (pin.chosen and 1.25 or 1) * (pin.hover and 1.15 or 1) * (pin.creator and CREATOR_SCALE or 1)
	pin:SetScale(scale)
	pin:ClearAllPoints()
	-- offsets are in the pin's own (scaled) units
	pin:SetPoint("CENTER", child, "TOPLEFT", pin.nx * w / scale, -pin.ny * h / scale)
end

local function CanvasMetrics(child)
	local okw, w = call(child, "GetWidth")
	local okh, h = call(child, "GetHeight")
	local oks, s = call(child, "GetScale")
	w, h, s = okw and W.Num(w), okh and W.Num(h), oks and W.Num(s)
	if not (w and h and w > 0 and h > 0) then return nil end
	if not (s and s > 0) then s = 1 end
	return w, h, s
end

local function PlaceOne(pin)
	local child = Canvas()
	if not child then return end
	local w, h, s = CanvasMetrics(child)
	if w then Place(pin, child, w, h, s) end
end

local function SetLevels(pin, level)
	if pin.level == level then return end
	pin.level = level
	pin:SetFrameLevel(level)
	pin.aura:SetFrameLevel(level)
	if pin.auraRing then pin.auraRing.frame:SetFrameLevel(level + 1) end
	pin.pulse:SetFrameLevel(level + 1)
	pin.body:SetFrameLevel(level + 2)
	pin.deco:SetFrameLevel(level + 3)
	pin.heart:SetFrameLevel(level + 4)
	pin.sparkle:SetFrameLevel(level + 4)
	for _, g in ipairs(pin.glints) do g:SetFrameLevel(level + 5) end
	if pin.crowns then
		for _, c in pairs(pin.crowns) do
			if not plainIcon[c] and c.SetFrameLevel then pcall(c.SetFrameLevel, c, level + 4) end
		end
	end
	for _, b in pairs(pin.badges) do
		if not plainIcon[b] and b.SetFrameLevel then pcall(b.SetFrameLevel, b, level + 4) end
	end
	pin.tag:SetFrameLevel(level + 6)
end

local function StartPulse(pin)
	if pin.pulsing then return end
	pin.pulsing = true
	pin.pulse:Show()
	pin.pulseAnim:Play()
end

local function StopPulse(pin)
	if not pin.pulsing then return end
	pin.pulsing = false
	pin.pulseAnim:Stop()
	pin.pulse:Hide()
end

local function NewPin(parent)
	local pin = NewFrame("Button", parent)
	pin:SetSize(PIN, PIN)
	pin:EnableMouse(true)
	pin:RegisterForClicks("LeftButtonUp")
	pin:SetScript("OnHide", function(self)
		W.Safe("map pin", function()
			if self.auraRing then self.auraRing:Hide() end
		end)
	end)

	-- the three-colour aura ring shown while the driver is open
	local auraRing = Aura(pin, PIN)
	auraRing:Hide()
	pin.auraRing = auraRing

	-- the soft ring that grows and fades while the driver is open
	local pulse = NewFrame("Frame", pin)
	pulse:SetSize(PIN, PIN)
	pulse:SetPoint("CENTER", pin, "CENTER", 0, 0)
	local soft = pulse:CreateTexture(nil, "BACKGROUND")
	soft:SetSize(PIN * 1.4, PIN * 1.4)
	soft:SetPoint("CENTER", pulse, "CENTER", 0, 0)
	soft:SetTexture(MEDIA .. "glow")
	Accent(soft, 0.55)
	local ring = pulse:CreateTexture(nil, "ARTWORK")
	ring:SetAllPoints(pulse)
	ring:SetTexture(MEDIA .. "ring")
	Accent(ring, 1)
	local ag = pulse:CreateAnimationGroup()
	ag:SetLooping("REPEAT")
	local grow = ag:CreateAnimation("Scale")
	ScaleTo(grow, 0.8, 2.1)
	grow:SetDuration(1.8)
	grow:SetSmoothing("OUT")
	local fade = ag:CreateAnimation("Alpha")
	fade:SetFromAlpha(0.7)
	fade:SetToAlpha(0)
	fade:SetDuration(1.8)
	fade:SetSmoothing("OUT")
	pulse:Hide()
	pin.pulse, pin.pulseAnim = pulse, ag

	-- the glow: stronger for cheaper open drivers (W.Prominence); gold and breathing for the creator
	local aura = NewFrame("Frame", pin)
	aura:SetSize(PIN, PIN)
	aura:SetPoint("CENTER", pin, "CENTER", 0, 0)
	local av = aura:CreateTexture(nil, "BACKGROUND")
	av:SetSize(PIN * 2.4, PIN * 2.4)
	av:SetPoint("CENTER", aura, "CENTER", 0, 0)
	av:SetTexture(MEDIA .. "glow")
	Accent(av, 1)
	local ag2 = aura:CreateTexture(nil, "BORDER")
	ag2:SetSize(PIN * 2.9, PIN * 2.9)
	ag2:SetPoint("CENTER", aura, "CENTER", 0, 0)
	ag2:SetTexture(MEDIA .. "glow")
	ag2:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.75)
	ag2:Hide()
	local breathe = aura:CreateAnimationGroup()
	breathe:SetLooping("REPEAT")
	local up = breathe:CreateAnimation("Alpha")
	up:SetFromAlpha(0.7)
	up:SetToAlpha(1)
	up:SetDuration(1.1)
	up:SetSmoothing("IN_OUT")
	up:SetOrder(1)
	local down = breathe:CreateAnimation("Alpha")
	down:SetFromAlpha(1)
	down:SetToAlpha(0.7)
	down:SetDuration(1.1)
	down:SetSmoothing("IN_OUT")
	down:SetOrder(2)
	aura:Hide()
	pin.aura, pin.auraViolet, pin.auraGold, pin.breathe = aura, av, ag2, breathe

	-- the pin itself
	local body = NewFrame("Frame", pin)
	body:SetAllPoints(pin)
	local shadow = body:CreateTexture(nil, "BACKGROUND")
	shadow:SetSize(PIN * 1.7, PIN * 1.7)
	shadow:SetPoint("CENTER", body, "CENTER", 0, -2)
	shadow:SetTexture(MEDIA .. "shadow")
	shadow:SetVertexColor(0, 0, 0, 0.6)
	local halo = body:CreateTexture(nil, "BORDER")
	halo:SetSize(PIN + 12, PIN + 12)
	halo:SetPoint("CENTER", body, "CENTER", 0, 0)
	halo:SetTexture(MEDIA .. "ring")
	halo:SetVertexColor(BRIGHT[1], BRIGHT[2], BRIGHT[3], 1) -- the chosen driver: a violet ring
	halo:Hide()
	local edge = body:CreateTexture(nil, "ARTWORK")
	edge:SetAllPoints(body)
	edge:SetTexture(MEDIA .. "circle")
	edge:SetVertexColor(1, 1, 1, 1)
	local fill = body:CreateTexture(nil, "OVERLAY", nil, 1)
	fill:SetSize(PIN - 4, PIN - 4)
	fill:SetPoint("CENTER", body, "CENTER", 0, 0)
	fill:SetTexture(MEDIA .. "circle")
	fill:SetVertexColor(FILL[1], FILL[2], FILL[3], 1)
	-- the face: the author's portal art, or the white summon glyph if that file isn't there
	local glyph = body:CreateTexture(nil, "OVERLAY", nil, 2)
	glyph:SetPoint("CENTER", body, "CENTER", 0, 0)
	local okp, loaded = pcall(glyph.SetTexture, glyph, MEDIA .. "portal")
	pin.portal = okp and loaded ~= false
	if pin.portal then
		glyph:SetSize(PIN - 6, PIN - 6)
	else
		glyph:SetTexture(MEDIA .. "summon")
		glyph:SetSize(PIN * 0.6, PIN * 0.6)
	end
	pin.body, pin.halo, pin.fill, pin.glyph, pin.edge = body, halo, fill, glyph, edge

	-- decorations: the creator's gold ring, the favourite heart, plain crown/badge icons
	local deco = NewFrame("Frame", pin)
	deco:SetAllPoints(pin)
	local gold = deco:CreateTexture(nil, "ARTWORK")
	gold:SetSize(PIN + 6, PIN + 6)
	gold:SetPoint("CENTER", deco, "CENTER", 0, 0)
	gold:SetTexture(MEDIA .. "ring")
	gold:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
	gold:Hide()
	pin.goldRing = gold
	-- the heart: two circles and a square turned 45 degrees (no heart texture needed)
	local heart = NewFrame("Frame", deco)
	heart:SetSize(10, 10)
	heart:SetPoint("CENTER", pin, "TOPLEFT", 2, -2)
	local HEART = hex("FF5C9A")
	for i, dx in ipairs({ -2.2, 2.2 }) do
		local c = heart:CreateTexture(nil, "OVERLAY")
		c:SetTexture(MEDIA .. "circle")
		c:SetSize(6, 6)
		c:SetPoint("CENTER", heart, "CENTER", dx, 1.4)
		c:SetVertexColor(HEART[1], HEART[2], HEART[3], 1)
	end
	local sq = heart:CreateTexture(nil, "OVERLAY")
	sq:SetSize(5.6, 5.6)
	sq:SetPoint("CENTER", heart, "CENTER", 0, -0.9)
	sq:SetColorTexture(HEART[1], HEART[2], HEART[3], 1)
	if sq.SetRotation then pcall(sq.SetRotation, sq, math.rad(45)) end
	heart:Hide()
	pin.heart = heart
	pin.deco = deco
	pin.badges = {}       -- badge id -> its frame (W.FX.Badge) or plain icon
	-- the creator's sparkle: two glints that twinkle in turn
	local sparkle = NewFrame("Frame", pin)
	sparkle:SetAllPoints(pin)
	local glints = {}
	for i, at in ipairs({ { 0.62, 0.55 }, { -0.6, -0.42 } }) do
		local g = NewFrame("Frame", sparkle)
		g:SetSize(10, 10)
		g:SetPoint("CENTER", sparkle, "CENTER", at[1] * PIN, at[2] * PIN)
		local t = g:CreateTexture(nil, "OVERLAY")
		t:SetAllPoints(g)
		t:SetTexture(MEDIA .. "star")
		t:SetVertexColor(1, 0.93, 0.7, 1)
		local tw = g:CreateAnimationGroup()
		tw:SetLooping("REPEAT")
		-- dark for a while (the two glints take turns), flash on, fade out
		local wait = tw:CreateAnimation("Alpha")
		wait:SetFromAlpha(0)
		wait:SetToAlpha(0)
		wait:SetDuration(i == 1 and 0.3 or 1.4)
		wait:SetOrder(1)
		local on = tw:CreateAnimation("Alpha")
		on:SetFromAlpha(0)
		on:SetToAlpha(1)
		on:SetDuration(0.35)
		on:SetOrder(2)
		local off = tw:CreateAnimation("Alpha")
		off:SetFromAlpha(1)
		off:SetToAlpha(0)
		off:SetDuration(0.55)
		off:SetOrder(3)
		local rest = tw:CreateAnimation("Alpha")
		rest:SetFromAlpha(0)
		rest:SetToAlpha(0)
		rest:SetDuration(i == 1 and 1.4 or 0.3)
		rest:SetOrder(4)
		g.anim = tw
		glints[i] = g
	end
	sparkle:Hide()
	pin.sparkle, pin.glints = sparkle, glints

	-- the price tag under the chosen driver's pin
	local tag = NewFrame("Frame", pin)
	tag:SetSize(44, 16)
	-- (#15) the aura frame reaches 12 px below the pin (ApplyAuraSizes: radius + 9, outline + 3), so the tag starts below it
	tag:SetPoint("TOP", pin, "BOTTOM", 0, -(12 + 3))
	local tl = tag:CreateTexture(nil, "BACKGROUND")
	tl:SetSize(8, 16)
	tl:SetPoint("LEFT", tag, "LEFT", 0, 0)
	tl:SetTexture(MEDIA .. "circle")
	tl:SetTexCoord(0, 0.5, 0, 1)
	tl:SetVertexColor(FILL[1], FILL[2], FILL[3], 1)
	local tr = tag:CreateTexture(nil, "BACKGROUND")
	tr:SetSize(8, 16)
	tr:SetPoint("RIGHT", tag, "RIGHT", 0, 0)
	tr:SetTexture(MEDIA .. "circle")
	tr:SetTexCoord(0.5, 1, 0, 1)
	tr:SetVertexColor(FILL[1], FILL[2], FILL[3], 1)
	local tm = tag:CreateTexture(nil, "BACKGROUND")
	tm:SetPoint("TOPLEFT", tag, "TOPLEFT", 8, 0)
	tm:SetPoint("BOTTOMRIGHT", tag, "BOTTOMRIGHT", -8, 0)
	tm:SetColorTexture(FILL[1], FILL[2], FILL[3], 1)
	local text = tag:CreateFontString(nil, "OVERLAY")
	local T = W.Theme
	if not (type(T) == "table" and type(T.SetFont) == "function" and pcall(T.SetFont, text, "caption", "bold")) then
		local okf, set = pcall(text.SetFont, text, "Fonts\\ARIALN.TTF", 11, "")
		if (not okf or set == false) and GameFontNormal then pcall(text.SetFontObject, text, GameFontNormal) end
	end
	text:SetPoint("CENTER", tag, "CENTER", 0, 0)
	text:SetTextColor(GOLD[1], GOLD[2], GOLD[3], 1)
	tag:Hide()
	pin.tag, pin.tagText = tag, text

	pin:SetScript("OnEnter", function(self)
		W.Safe("map pin", function()
			self.hover = true
			PlaceOne(self)
			Tooltip(self)
		end)
	end)
	pin:SetScript("OnLeave", function(self)
		W.Safe("map pin", function()
			self.hover = false
			PlaceOne(self)
			if W.Theme and W.Theme.TipHide then W.Theme.TipHide(self) end
		end)
	end)
	local function onPinClick(self)
		W.Safe("map pin", function()
			local key = self.key
			local d = Driver(key)
			if not key or not d or d.state == "paused" or (W.myKey and key == W.myKey) then return end
			if W.Theme and W.Theme.TipHide then W.Theme.TipHide(self) end
			W.Sound("click")
			if W.UI and type(W.UI.Show) == "function" then W.UI.Show("confirm", key) end
		end)
	end
	if W.GamepadUI() then -- (PST-01 B) no click script with the Gamepad UI on: the global mouse events
		ClickOver(pin, onPinClick)
	else
		pin:SetScript("OnClick", function(self)
			onPinClick(self)
		end)
	end
	pin:Hide()
	return pin
end

local function Desaturate(t, on)
	if t.SetDesaturated then pcall(t.SetDesaturated, t, on) end
end


local function Plain(pin, file, size, colour)
	local t = pin.deco:CreateTexture(nil, "OVERLAY")
	plainIcon[t] = true
	t:SetTexture(MEDIA .. file)
	t:SetSize(size, size)
	if colour then t:SetVertexColor(colour[1], colour[2], colour[3], 1) end
	return t
end

-- the spinning crown over the creator's pin (W.FX.Crown, else a plain gold star)
local function ShowCrown(pin, d)
	local seed = Seed(d.key or d.name)
	pin.crowns = pin.crowns or {}
	local c = pin.crowns[seed]
	if not c then
		if W.FX and type(W.FX.Crown) == "function" then
			local ok, f = pcall(W.FX.Crown, pin.deco, 22, seed)
			if ok and type(f) == "table" then c = f end
		end
		if not c then c = Plain(pin, "star", 14, GOLD) end
		if pin.level and not plainIcon[c] and c.SetFrameLevel then pcall(c.SetFrameLevel, c, pin.level + 4) end
		pin.crowns[seed] = c
	end
	for k, other in pairs(pin.crowns) do
		if other ~= c then pcall(other.Hide, other) end
	end
	pcall(c.ClearAllPoints, c)
	pcall(c.SetPoint, c, "BOTTOM", pin, "TOP", 0, -4)
	pcall(c.Show, c)
	pin.crown = c
end

local function HideCrown(pin)
	if pin.crowns then
		for _, c in pairs(pin.crowns) do pcall(c.Hide, c) end
	end
	pin.crown = nil
end

-- the driver's badge at the pin's lower right (W.FX.Badge, else W.BADGES' plain icon)
local function ShowBadge(pin, d)
	local info = BadgeInfo(d.badge)
	local want = info and info.id
	for id, b in pairs(pin.badges) do
		if id ~= want then pcall(b.Hide, b) end
	end
	if not want then return end
	local b = pin.badges[want]
	if not b then
		if W.FX and type(W.FX.Badge) == "function" then
			local ok, f = pcall(W.FX.Badge, pin.deco, want, 14)
			if ok and type(f) == "table" then b = f end
		end
		if not b then
			b = pin.deco:CreateTexture(nil, "OVERLAY")
			plainIcon[b] = true
			local tex = info.tex
			if not (type(tex) == "string" or type(tex) == "number") then tex = MEDIA .. "badge" end
			if not pcall(b.SetTexture, b, tex) then b:SetTexture(MEDIA .. "badge") end
			b:SetSize(14, 14)
		end
		if pin.level and not plainIcon[b] and b.SetFrameLevel then pcall(b.SetFrameLevel, b, pin.level + 4) end
		pin.badges[want] = b
	end
	pcall(b.ClearAllPoints, b)
	pcall(b.SetPoint, b, "CENTER", pin, "BOTTOMRIGHT", -2, 3)
	pcall(b.Show, b)
end

local function StartCreator(pin)
	if pin.creatorOn then return end
	pin.creatorOn = true
	pin.goldRing:Show()
	pin.auraGold:Show()
	pin.sparkle:Show()
	for _, g in ipairs(pin.glints) do g.anim:Play() end
	pin.breathe:Play()
end

local function StopCreator(pin)
	if not pin.creatorOn then return end
	pin.creatorOn = false
	pin.goldRing:Hide()
	pin.auraGold:Hide()
	for _, g in ipairs(pin.glints) do g.anim:Stop() end
	pin.sparkle:Hide()
	pin.breathe:Stop()
	HideCrown(pin)
end

local function Paint(pin, d, chosen, glow, creator)
	local state = d.state
	pin.chosen = chosen
	pin.creator = creator
	pin.glow = glow
	local rank = W.Num(d.rank)
	pin.rank = (rank and rank >= 1) and math.floor(rank) or nil
	-- the rim says the state: open bright violet, busy amber, paused grey-violet (the creator: gold)
	local rim = state == "open" and BRIGHT or (state == "busy" and AMBER or PAUSED)
	if creator and state ~= "paused" then rim = GOLD end
	pin.edge:SetVertexColor(rim[1], rim[2], rim[3], 1)
	if state == "open" then
		pin.glyph:SetVertexColor(1, 1, 1, 1)
		if pin.portal then Desaturate(pin.glyph, false) end
		pin.body:SetAlpha(1)
	else
		pin.glyph:SetVertexColor(0.85, 0.85, 0.85, state == "paused" and 0.7 or 0.9)
		if pin.portal then Desaturate(pin.glyph, state == "paused") end
		pin.body:SetAlpha(state == "paused" and 0.65 or 1)
	end
	-- only the creator's pin (and the chosen one) animate for ever; the rest glow still
	if state == "open" and (creator or chosen) then StartPulse(pin) else StopPulse(pin) end
	if pin.auraRing then
		pin.auraRing:SetGold(pin.rank ~= nil and pin.rank >= 1000)
		if state == "open" then
			pin.auraRing:Start()
		else
			pin.auraRing:Hide()
		end
	end
	if glow and glow > 0 then
		pin.aura:SetAlpha(math.min(1, 0.12 + 0.88 * glow))
		pin.auraViolet:SetAlpha(1)
		pin.aura:Show()
	else
		pin.aura:Hide()
	end
	if creator then
		StartCreator(pin)
		ShowCrown(pin, d)
	else
		StopCreator(pin)
	end
	ShowBadge(pin, d)
	if IsFav(d.key) then pin.heart:Show() else pin.heart:Hide() end
	if chosen then
		pin.halo:Show()
		local price = W.Money(W.Num(d.price) or 0)
		pin.tagText:SetText(price)
		pin.tag:SetWidth(math.max(36, #price * 6 + 18))
		pin.tag:Show()
	else
		pin.halo:Hide()
		pin.tag:Hide()
	end
end

-- internals other modules use (bound at load by later modules, or called late)
Mod.AURA = AURA
Mod.Aura = Aura
Mod.CanvasMetrics = CanvasMetrics
Mod.NewPin = NewPin
Mod.Paint = Paint
Mod.Place = Place
Mod.SetLevels = SetLevels
Mod.StopCreator = StopCreator
Mod.StopPulse = StopPulse
Mod.Tooltip = Tooltip -- (BRIEF15, for tests: the pin's tooltip without placing it)
