-- Wuber: the look. Colours, fonts, the generated textures in Media/, and small builders
-- (cards, pill buttons, chips, icons) plus animation helpers, shared by UI.lua, Map.lua and
-- Driver.lua so every screen looks the same. Nothing here talks to the network.

local _, W = ...

local T = {}
W.Theme = T

T.MEDIA = "Interface\\AddOns\\Wuber\\Media\\"
-- Poppins (SIL Open Font License, Media/fonts/OFL.txt); Arial Narrow if it can't be loaded.
T.FONTS = {
	regular = T.MEDIA .. "fonts\\Poppins-Regular.ttf",
	medium = T.MEDIA .. "fonts\\Poppins-Medium.ttf",
	bold = T.MEDIA .. "fonts\\Poppins-Bold.ttf",
}
T.FONT = "Fonts\\ARIALN.TTF"
T.SIZE = { title = 24, heading = 17, body = 13, small = 11, price = 20 }
-- the weight each size gets unless asked otherwise
T.WEIGHT = { title = "bold", heading = "bold", price = "bold", body = "medium", small = "regular" }

---------------------------------------------------------------------------
-- Colours: { r, g, b, a }
---------------------------------------------------------------------------

local function hex(h, a)
	return {
		tonumber(h:sub(1, 2), 16) / 255,
		tonumber(h:sub(3, 4), 16) / 255,
		tonumber(h:sub(5, 6), 16) / 255,
		a or 1,
	}
end
T.Hex = hex

-- the author's logo: night-sky violet and gold. Names are roles, so every screen stays in step.
T.C = {
	black = hex("0B0B16"),       -- the window: deep night
	nightTop = hex("141228"),    -- the top of the window's gradient
	panel = hex("161628"),       -- sheets and panels
	card = hex("1D1B31"),
	hover = hex("26233F"),       -- a card under the mouse
	line = hex("333154"),        -- lines and dividers
	raised = hex("3D3A60"),
	white = hex("F2EEFF"),       -- main text
	ink = hex("1D1B31"),         -- text on gold
	muted = hex("9A93B8"),       -- secondary text: lavender grey
	accent = hex("883FDA"),      -- portal violet
	glow = hex("CD7DF5"),        -- bright violet: "Open", highlights
	magenta = hex("E467FC"),     -- hot edge of glows and pulses
	gold = hex("F9C53E"),        -- prices, the main button, stars
	goldLight = hex("FFD866"),
	goldPress = hex("E0AE2E"),
	goldDeep = hex("B1873F"),    -- borders and badges
	amber = hex("F9A23E"),       -- busy
	off = hex("6B6585"),         -- paused, off
	red = hex("FF5C7A"),         -- errors
	shadow = hex("000000", 0.6),
}
T.C.open = T.C.glow
T.C.green = T.C.glow -- "open" was green once: it is violet now

-- A colour by name or table -> r, g, b, a. Unknown: white.
function T.RGB(c, alpha)
	if type(c) == "string" then c = T.C[c] end
	if type(c) ~= "table" then c = T.C.white end
	return c[1] or 1, c[2] or 1, c[3] or 1, alpha or c[4] or 1
end

-- "|cffRRGGBB" for inline colour codes
function T.Code(c)
	local r, g, b = T.RGB(c)
	return ("|cff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

---------------------------------------------------------------------------
-- Calling a method the client may not have (never raises)
---------------------------------------------------------------------------

local function invoke(obj, method, ...)
	local f = obj[method]
	if type(f) ~= "function" then return nil end
	return f(obj, ...)
end

function T.Try(obj, method, ...)
	if obj == nil then return nil end
	local ok, a, b, c, d = pcall(invoke, obj, method, ...)
	if ok then return a, b, c, d end
	return nil
end
local Try = T.Try

---------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------

local function fontSize(size)
	if type(size) == "string" then size = T.SIZE[size] end
	return tonumber(size) or T.SIZE.body
end

local MISSING = {}
local function method(obj, name, ...)
	local f = obj[name]
	if type(f) ~= "function" then return MISSING end
	return f(obj, ...)
end

-- Whether fs now has the font (GetFont says so where the client has it).
local function setFile(fs, path, px)
	local ok, res = pcall(method, fs, "SetFont", path, px, "")
	if not ok or res == MISSING or res == false then return false end
	local okGet, file = pcall(method, fs, "GetFont")
	if okGet and file ~= MISSING then return file ~= nil end
	return true
end

-- T.poppins: nil until the first try, then true/false (false: Arial Narrow from then on).
function T.SetFont(fs, size, weight)
	local px = fontSize(size)
	if type(size) == "string" and not weight then weight = T.WEIGHT[size] end
	local done = false
	if T.poppins ~= false then
		done = setFile(fs, T.FONTS[weight or "medium"] or T.FONTS.medium, px)
		if T.poppins == nil then T.poppins = done end
	end
	-- Arial Narrow runs small next to Poppins: a touch larger keeps the layout
	if not done then done = setFile(fs, T.FONT, math.floor(px * 1.12 + 0.5)) end
	if not done then
		local font = GameFontNormal or GameFontHighlight
		if font then Try(fs, "SetFontObject", font) end
	end
	Try(fs, "SetShadowOffset", 1, -1)
	Try(fs, "SetShadowColor", 0, 0, 0, 0.45)
end

-- A font string: size is a name from T.SIZE ("title", "body", ...) or a number;
-- weight "regular", "medium" or "bold" (default from T.WEIGHT, else medium).
function T.Text(parent, size, colour, justify, weight, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	T.SetFont(fs, size, weight)
	fs:SetTextColor(T.RGB(colour or "white"))
	fs:SetJustifyH(justify or "LEFT")
	Try(fs, "SetJustifyV", "MIDDLE")
	Try(fs, "SetWordWrap", false)
	return fs
end

---------------------------------------------------------------------------
-- Textures
---------------------------------------------------------------------------

function T.Tex(parent, name, layer, sub)
	local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
	t:SetTexture(T.MEDIA .. name)
	return t
end

-- A white glyph from Media (summon, ride, check, star, close, back, search, ...), tinted.
function T.Icon(parent, name, size, colour, layer)
	local t = T.Tex(parent, name, layer or "OVERLAY")
	t:SetSize(size or 16, size or 16)
	t:SetVertexColor(T.RGB(colour or "white"))
	return t
end

function T.Circle(parent, size, colour, layer, sub)
	local t = T.Tex(parent, "circle", layer or "ARTWORK", sub)
	t:SetSize(size or 16, size or 16)
	t:SetVertexColor(T.RGB(colour or "white"))
	return t
end

-- Nine textures from one square source, so a rounded shape stretches to any size.
-- c: the corner part of the texture (0..0.5); px: the corner's size on screen;
-- out: how far the shape reaches outside the frame (shadows).
local NINE = {
	TL = { 0, "c", 0, "c" }, T = { "c", "1-c", 0, "c" }, TR = { "1-c", 1, 0, "c" },
	L = { 0, "c", "c", "1-c" }, M = { "c", "1-c", "c", "1-c" }, R = { "1-c", 1, "c", "1-c" },
	BL = { 0, "c", "1-c", 1 }, B = { "c", "1-c", "1-c", 1 }, BR = { "1-c", 1, "1-c", 1 },
}

local Slice = {}
Slice.__index = Slice
function Slice:SetColor(c, alpha)
	local r, g, b, a = T.RGB(c, alpha)
	for _, t in pairs(self.parts) do t:SetVertexColor(r, g, b, a) end
	self.colour = c
end
function Slice:SetShown(shown)
	for _, t in pairs(self.parts) do
		if shown then t:Show() else t:Hide() end
	end
end
function Slice:SetAlpha(a)
	for _, t in pairs(self.parts) do t:SetAlpha(a) end
end

function T.NineSlice(frame, name, px, c, layer, sub, out)
	out = out or 0
	local s = setmetatable({ parts = {} }, Slice)
	local function v(x)
		if x == "c" then return c elseif x == "1-c" then return 1 - c end
		return x
	end
	for k, tc in pairs(NINE) do
		local t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
		t:SetTexture(T.MEDIA .. name)
		t:SetTexCoord(v(tc[1]), v(tc[2]), v(tc[3]), v(tc[4]))
		s.parts[k] = t
	end
	local p = s.parts
	p.TL:SetSize(px, px)
	p.TL:SetPoint("TOPLEFT", frame, "TOPLEFT", -out, out)
	p.TR:SetSize(px, px)
	p.TR:SetPoint("TOPRIGHT", frame, "TOPRIGHT", out, out)
	p.BL:SetSize(px, px)
	p.BL:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -out, -out)
	p.BR:SetSize(px, px)
	p.BR:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", out, -out)
	p.T:SetPoint("TOPLEFT", p.TL, "TOPRIGHT")
	p.T:SetPoint("BOTTOMRIGHT", p.TR, "BOTTOMLEFT")
	p.B:SetPoint("TOPLEFT", p.BL, "TOPRIGHT")
	p.B:SetPoint("BOTTOMRIGHT", p.BR, "BOTTOMLEFT")
	p.L:SetPoint("TOPLEFT", p.TL, "BOTTOMLEFT")
	p.L:SetPoint("BOTTOMRIGHT", p.BL, "TOPRIGHT")
	p.R:SetPoint("TOPLEFT", p.TR, "BOTTOMLEFT")
	p.R:SetPoint("BOTTOMRIGHT", p.BR, "TOPRIGHT")
	p.M:SetPoint("TOPLEFT", p.TL, "BOTTOMRIGHT")
	p.M:SetPoint("BOTTOMRIGHT", p.BR, "TOPLEFT")
	return s
end

-- A rounded fill on frame (radius on screen, default 12).
function T.Rounded(frame, colour, radius, layer, sub, out)
	local s = T.NineSlice(frame, "rounded", radius or 12, 0.25, layer or "BACKGROUND", sub or 0, out)
	s:SetColor(colour or "card")
	return s
end

-- A pill fill (fully round ends) on frame; the caps are half the frame's height.
local Pill3 = {}
Pill3.__index = Pill3
function Pill3:SetColor(c, alpha)
	local r, g, b, a = T.RGB(c, alpha)
	for _, t in ipairs(self.parts) do t:SetVertexColor(r, g, b, a) end
	self.colour = c
end
function Pill3:SetHeight(h)
	self.parts[1]:SetWidth(h / 2)
	self.parts[3]:SetWidth(h / 2)
end
function Pill3:SetShown(shown)
	for _, t in ipairs(self.parts) do
		if shown then t:Show() else t:Hide() end
	end
end

function T.PillFill(frame, colour, h, layer, sub)
	local s = setmetatable({ parts = {} }, Pill3)
	local coords = { { 0, 0.25 }, { 0.25, 0.75 }, { 0.75, 1 } }
	for i = 1, 3 do
		local t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
		t:SetTexture(T.MEDIA .. "pill")
		t:SetTexCoord(coords[i][1], coords[i][2], 0, 1)
		s.parts[i] = t
	end
	local l, m, r = s.parts[1], s.parts[2], s.parts[3]
	l:SetPoint("TOPLEFT", frame, "TOPLEFT")
	l:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
	r:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
	r:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
	m:SetPoint("TOPLEFT", l, "TOPRIGHT")
	m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
	s:SetHeight(h or 32)
	s:SetColor(colour or "card")
	return s
end

---------------------------------------------------------------------------
-- Card: a rounded panel with a soft shadow
---------------------------------------------------------------------------
-- opts: { colour = "card", radius = 14, shadow = true, border = colour or nil }
-- card.bg / card.shadow / card.border are slices: card.bg:SetColor("line") etc.

function T.Card(parent, w, h, opts)
	opts = opts or {}
	local f = CreateFrame("Frame", nil, parent)
	if w and h then f:SetSize(w, h) end
	local radius = opts.radius or 14
	if opts.shadow ~= false then
		f.shadow = T.NineSlice(f, "shadow", 24, 31 / 64, "BACKGROUND", -8, 12)
		f.shadow:SetColor("shadow")
		-- dropped a little below the card
		for _, t in pairs(f.shadow.parts) do
			local p, rel, rp, x, y = t:GetPoint(1)
			if p and rel == f then t:SetPoint(p, rel, rp, x, (y or 0) - 3) end
		end
	end
	if opts.border then
		f.border = T.Rounded(f, opts.border, radius + 1, "BACKGROUND", -6, 1)
	end
	f.bg = T.Rounded(f, opts.colour or "card", radius, "BACKGROUND", -4)
	return f
end

---------------------------------------------------------------------------
-- Animations (AnimationGroups; every helper may be called again at any time)
---------------------------------------------------------------------------

local A = {}
T.Animate = A

local function groups(frame)
	local g = frame.wuberAnims
	if not g then
		g = {}
		frame.wuberAnims = g
	end
	return g
end

-- One group per frame and kind, made once and reused.
local function group(frame, kind)
	local g = groups(frame)
	local ag = g[kind]
	if ag then
		Try(ag, "Stop")
		return ag, false
	end
	ag = frame:CreateAnimationGroup()
	g[kind] = ag
	return ag, true
end

local function anim(ag, kind, order, duration, delay, smooth)
	local a = ag:CreateAnimation(kind)
	a:SetOrder(order or 1)
	a:SetDuration(duration or 0)
	if delay and delay > 0 then a:SetStartDelay(delay) end
	if smooth then a:SetSmoothing(smooth) end
	return a
end

local function scaleAnim(ag, order, duration, from, to, delay, smooth)
	local a = anim(ag, "Scale", order, duration, delay, smooth)
	-- SetScaleFrom/To on this client; SetFromScale/ToScale on some others
	local ok, res = pcall(method, a, "SetScaleFrom", from, from)
	if ok and res ~= MISSING then
		Try(a, "SetScaleTo", to, to)
	else
		Try(a, "SetFromScale", from, from)
		Try(a, "SetToScale", to, to)
	end
	Try(a, "SetOrigin", "CENTER", 0, 0)
	return a
end

-- Stops every Wuber animation on the frame (leaves it where it is).
function A.Stop(frame, except)
	if not frame or not frame.wuberAnims then return end
	frame.wuberToken = (frame.wuberToken or 0) + 1
	for kind, ag in pairs(frame.wuberAnims) do
		if kind ~= except then Try(ag, "Stop") end
	end
end

-- Moving animations replace each other; looping ones (Pulse, Spin) are left alone.
local MOVES = { fadein = true, fadeout = true, move = true, out = true, pop = true }
local function stopMoves(frame)
	if not frame.wuberAnims then return end
	frame.wuberToken = (frame.wuberToken or 0) + 1
	for kind, ag in pairs(frame.wuberAnims) do
		if MOVES[kind] then Try(ag, "Stop") end
	end
end

local function guarded(name, fn, fallback)
	return function(frame, ...)
		if not frame then return nil end
		local ok, res = pcall(fn, frame, ...)
		if ok then return res end
		W.Error("animate " .. name, res)
		if fallback then pcall(fallback, frame, ...) end
		return nil
	end
end

local function showPlain(frame)
	frame:SetAlpha(1)
	frame:Show()
end

-- FadeIn(frame, duration = 0.2, delay = 0)
A.FadeIn = guarded("FadeIn", function(frame, duration, delay)
	stopMoves(frame)
	local ag, new = group(frame, "fadein")
	if new then
		ag.a = anim(ag, "Alpha", 1, 0)
		ag.a:SetFromAlpha(0)
		ag.a:SetToAlpha(0)
		ag.b = anim(ag, "Alpha", 2, 0.2, nil, "OUT")
		ag.b:SetFromAlpha(0)
		ag.b:SetToAlpha(1)
	end
	ag.b:SetDuration(duration or 0.2)
	ag.b:SetStartDelay(delay or 0)
	frame:SetAlpha(1)
	frame:Show()
	ag:Play()
	return ag
end, showPlain)

-- FadeOut(frame, duration = 0.18, onDone, keepShown): hides the frame at the end.
A.FadeOut = guarded("FadeOut", function(frame, duration, onDone, keepShown)
	stopMoves(frame)
	if not frame:IsShown() then
		if onDone then W.Safe("animate done", onDone, frame) end
		return nil
	end
	local ag, new = group(frame, "fadeout")
	if new then
		ag.a = anim(ag, "Alpha", 1, 0.18, nil, "IN")
		ag.a:SetFromAlpha(1)
		ag.a:SetToAlpha(0)
		Try(ag, "SetToFinalAlpha", true)
	end
	ag.a:SetDuration(duration or 0.18)
	local token = frame.wuberToken
	ag:SetScript("OnFinished", function()
		if frame.wuberToken ~= token then return end
		if keepShown then frame:SetAlpha(0) else
			frame:Hide()
			frame:SetAlpha(1)
		end
		if onDone then W.Safe("animate done", onDone, frame) end
	end)
	ag:Play()
	return ag
end, function(frame, _, onDone, keepShown)
	if keepShown then frame:SetAlpha(0) else frame:Hide() end
	if onDone then pcall(onDone, frame) end
end)

-- Move(frame, fromX, fromY, duration = 0.25, delay = 0): shows the frame and glides it
-- from (fromX, fromY) away into its place, fading in.
A.Move = guarded("Move", function(frame, fromX, fromY, duration, delay)
	stopMoves(frame)
	local ag, new = group(frame, "move")
	if new then
		ag.t0 = anim(ag, "Translation", 1, 0)
		ag.a0 = anim(ag, "Alpha", 1, 0)
		ag.a0:SetFromAlpha(0)
		ag.a0:SetToAlpha(0)
		ag.t1 = anim(ag, "Translation", 2, 0.25, nil, "OUT")
		ag.a1 = anim(ag, "Alpha", 2, 0.2, nil, "OUT")
		ag.a1:SetFromAlpha(0)
		ag.a1:SetToAlpha(1)
	end
	fromX, fromY = fromX or 0, fromY or 0
	duration = duration or 0.25
	ag.t0:SetOffset(fromX, fromY)
	ag.t1:SetOffset(-fromX, -fromY)
	ag.t1:SetDuration(duration)
	ag.a1:SetDuration(duration * 0.8)
	ag.t1:SetStartDelay(delay or 0)
	ag.a1:SetStartDelay(delay or 0)
	frame:SetAlpha(1)
	frame:Show()
	ag:Play()
	return ag
end, showPlain)

-- SlideUp(frame, distance = 24, duration = 0.28, delay = 0)
function A.SlideUp(frame, distance, duration, delay)
	return A.Move(frame, 0, -(distance or 24), duration or 0.28, delay)
end

-- SlideIn(frame, fromX = 40, duration = 0.25, delay = 0): from the right when fromX > 0
function A.SlideIn(frame, fromX, duration, delay)
	return A.Move(frame, fromX or 40, 0, duration or 0.25, delay)
end

-- SlideOut(frame, toX = -40, duration = 0.2, onDone): glides away, fades, hides.
A.SlideOut = guarded("SlideOut", function(frame, toX, duration, onDone, toY)
	stopMoves(frame)
	if not frame:IsShown() then
		if onDone then W.Safe("animate done", onDone, frame) end
		return nil
	end
	local ag, new = group(frame, "out")
	if new then
		ag.t = anim(ag, "Translation", 1, 0.2, nil, "IN")
		ag.a = anim(ag, "Alpha", 1, 0.2, nil, "IN")
		ag.a:SetFromAlpha(1)
		ag.a:SetToAlpha(0)
		Try(ag, "SetToFinalAlpha", true)
	end
	ag.t:SetOffset(toX or -40, toY or 0)
	ag.t:SetDuration(duration or 0.2)
	ag.a:SetDuration(duration or 0.2)
	local token = frame.wuberToken
	ag:SetScript("OnFinished", function()
		if frame.wuberToken ~= token then return end
		frame:Hide()
		frame:SetAlpha(1)
		if onDone then W.Safe("animate done", onDone, frame) end
	end)
	ag:Play()
	return ag
end, function(frame, _, _, onDone)
	frame:Hide()
	if onDone then pcall(onDone, frame) end
end)

-- Pop(frame, duration = 0.32, delay = 0): grows from 0.85 past full size and settles.
A.Pop = guarded("Pop", function(frame, duration, delay)
	stopMoves(frame)
	local ag, new = group(frame, "pop")
	local over = 1.06
	if new then
		ag.a0 = anim(ag, "Alpha", 1, 0)
		ag.a0:SetFromAlpha(0)
		ag.a0:SetToAlpha(0)
		ag.s0 = scaleAnim(ag, 1, 0, 1, 0.85)
		ag.s1 = scaleAnim(ag, 2, 0.2, 1, over / 0.85, nil, "OUT")
		ag.a1 = anim(ag, "Alpha", 2, 0.14, nil, "OUT")
		ag.a1:SetFromAlpha(0)
		ag.a1:SetToAlpha(1)
		ag.s2 = scaleAnim(ag, 3, 0.12, 1, 1 / over, nil, "IN_OUT")
	end
	duration = duration or 0.32
	ag.s1:SetDuration(duration * 0.62)
	ag.a1:SetDuration(duration * 0.45)
	ag.s2:SetDuration(duration * 0.38)
	ag.s1:SetStartDelay(delay or 0)
	ag.a1:SetStartDelay(delay or 0)
	frame:SetAlpha(1)
	frame:Show()
	ag:Play()
	return ag
end, showPlain)

-- Tap(frame): the quick press-in a button gives (scale to 0.97 and back).
A.Tap = guarded("Tap", function(frame)
	local ag, new = group(frame, "tap")
	if new then
		scaleAnim(ag, 1, 0.07, 1, 0.97, nil, "OUT")
		scaleAnim(ag, 2, 0.14, 1, 1 / 0.97, nil, "OUT")
	end
	ag:Play()
	return ag
end)

-- Pulse(host, opts): rings that grow out of the host's centre and fade, over and over.
-- opts: { size = 64, colour = "white", alpha = 0.55, period = 1.8, rings = 2, from = 0.3,
--         texture = "pulse", level = nil }
-- Returns a handle: handle:Start(), handle:Stop(), handle:SetColor(c), handle.frame.
local Pulse = {}
Pulse.__index = Pulse

function Pulse:Stop()
	self.token = self.token + 1
	for _, r in ipairs(self.rings) do
		Try(r.ag, "Stop")
		r:SetAlpha(0)
	end
	self.running = false
end

function Pulse:Start()
	self:Stop()
	self.running = true
	local token = self.token
	local n = #self.rings
	for i, r in ipairs(self.rings) do
		local delay = (i - 1) * self.period / n
		if delay <= 0 then
			r.ag:Play()
		else
			W.After(delay, function()
				if self.token == token then r.ag:Play() end
			end)
		end
	end
end

function Pulse:SetColor(c, alpha)
	local r, g, b = T.RGB(c)
	for _, ring in ipairs(self.rings) do ring.tex:SetVertexColor(r, g, b, 1) end
	if alpha then
		self.alpha = alpha
		for _, ring in ipairs(self.rings) do ring.fade:SetFromAlpha(alpha) end
	end
end

function Pulse:SetShown(shown)
	if shown then self.frame:Show() else self.frame:Hide() end
end

function A.Pulse(host, opts)
	opts = opts or {}
	local size = opts.size or 64
	local holder = CreateFrame("Frame", nil, host)
	holder:SetSize(size, size)
	holder:SetPoint("CENTER", host, "CENTER")
	if opts.level then holder:SetFrameLevel(opts.level) end
	local p = setmetatable({ frame = holder, rings = {}, token = 0, period = opts.period or 1.8, alpha = opts.alpha or 0.55 }, Pulse)
	for i = 1, (opts.rings or 2) do
		local ring = CreateFrame("Frame", nil, holder)
		ring:SetSize(size, size)
		ring:SetPoint("CENTER", holder, "CENTER")
		ring:SetAlpha(0)
		ring.tex = ring:CreateTexture(nil, "ARTWORK")
		ring.tex:SetTexture(T.MEDIA .. (opts.texture or "pulse"))
		ring.tex:SetAllPoints(ring)
		local ag = ring:CreateAnimationGroup()
		ag:SetLooping("REPEAT")
		scaleAnim(ag, 1, p.period, opts.from or 0.3, 1, nil, "OUT")
		ring.fade = anim(ag, "Alpha", 1, p.period, nil, "IN")
		ring.fade:SetFromAlpha(p.alpha)
		ring.fade:SetToAlpha(0)
		ring.ag = ag
		p.rings[i] = ring
	end
	p:SetColor(opts.colour or "white")
	if opts.start ~= false then p:Start() end
	return p
end

-- Spin(region, period = 1, clockwise = true): turns a texture round and round.
-- Returns a handle with :Stop() and :Start().
local Spin = {}
Spin.__index = Spin
function Spin:Start()
	if self.ag then self.ag:Play() elseif self.driver then self.driver:Show() end
end
function Spin:Stop()
	if self.ag then Try(self.ag, "Stop") end
	if self.driver then self.driver:Hide() end
end

function A.Spin(region, period, clockwise)
	if not region then return nil end
	period = period or 1
	local degrees = (clockwise == false) and 360 or -360
	if region.wuberSpin then
		local s = region.wuberSpin
		if s.ag and s.rot then
			Try(s.ag, "Stop")
			s.rot:SetDuration(period)
			s.rot:SetDegrees(degrees)
		end
		s.period, s.degrees = period, degrees
		s:Start()
		return s
	end
	local s = setmetatable({ period = period, degrees = degrees }, Spin)
	local ag = Try(region, "CreateAnimationGroup")
	if ag then
		local ok = pcall(function()
			ag:SetLooping("REPEAT")
			s.rot = ag:CreateAnimation("Rotation")
			s.rot:SetDegrees(degrees)
			s.rot:SetDuration(period)
			Try(s.rot, "SetOrigin", "CENTER", 0, 0)
		end)
		if ok then s.ag = ag end
	end
	if not s.ag then
		-- no animation groups on textures here: turn it by hand while it is shown
		local parent = Try(region, "GetParent")
		if parent then
			local d = CreateFrame("Frame", nil, parent)
			local angle = 0
			d:SetScript("OnUpdate", function(_, elapsed)
				local ok = pcall(function()
					angle = (angle + (elapsed or 0) * math.rad(s.degrees) / s.period) % (2 * math.pi)
					Try(region, "SetRotation", angle)
				end)
				if not ok then d:Hide() end
			end)
			s.driver = d
		end
	end
	region.wuberSpin = s
	s:Start()
	return s
end

-- Stagger(list, delay = 0.045, how = "SlideUp" | "SlideIn" | "FadeIn" | "Pop" | fn(frame, delay))
function A.Stagger(list, delay, how)
	delay = delay or 0.045
	for i, f in ipairs(list or {}) do
		local d = (i - 1) * delay
		if type(how) == "function" then
			W.Safe("stagger", how, f, d)
		elseif how == "SlideIn" then
			A.SlideIn(f, 40, 0.28, d)
		elseif how == "FadeIn" then
			A.FadeIn(f, 0.2, d)
		elseif how == "Pop" then
			A.Pop(f, 0.32, d)
		else
			A.SlideUp(f, 18, 0.3, d)
		end
	end
end

---------------------------------------------------------------------------
-- Pill buttons
---------------------------------------------------------------------------
-- T.Pill(parent, text, style, w, h): style "primary" (white, black text), "dark" (grey),
-- "ghost" (clear, white text). The button's own OnEnter/OnLeave/OnMouseDown/OnMouseUp draw
-- the hover and press looks: add your own with HookScript, and set OnClick as usual.
-- b:SetLabel(text), b:SetStyle(style), b:SetActive(bool) (an inactive pill looks quiet and
-- does not click), b.label, b.fill.

local STYLES = {
	primary = { bg = "gold", hover = "goldLight", press = "goldPress", text = "ink", glow = "gold" },
	dark = { bg = "card", hover = "hover", press = "line", text = "white" },
	ghost = { bg = { 1, 1, 1, 0 }, hover = { 1, 1, 1, 0.06 }, press = { 1, 1, 1, 0.12 }, text = "white" },
	violet = { bg = "accent", hover = { 0.6, 0.32, 0.9, 1 }, press = { 0.45, 0.2, 0.75, 1 }, text = "white", glow = "magenta" },
	danger = { bg = { 1, 0.36, 0.48, 0.16 }, hover = { 1, 0.36, 0.48, 0.24 }, press = { 1, 0.36, 0.48, 0.32 }, text = "red" },
	off = { bg = "card", hover = "card", press = "card", text = "off" },
}
T.PILL_STYLES = STYLES

local function pillPaint(b)
	local st = STYLES[b.inactive and "off" or b.style] or STYLES.dark
	local fill = st.bg
	if not b.inactive then
		if b.pressed then fill = st.press elseif b.hover then fill = st.hover end
	end
	b.fill:SetColor(fill)
	if b.glow then
		if st.glow and b.hover and not b.inactive then
			b.glow:SetVertexColor(T.RGB(st.glow, 0.35))
			b.glow:Show()
		else
			b.glow:Hide()
		end
	end
	b.label:SetTextColor(T.RGB(st.text))
	if b.icon then b.icon:SetVertexColor(T.RGB(st.text)) end
end

function T.Pill(parent, text, style, w, h, name, template)
	w, h = w or 140, h or 44
	local b = CreateFrame("Button", name, parent, template)
	b:SetSize(w, h)
	b.style = STYLES[style] and style or "dark"
	b.fill = T.PillFill(b, "card", h, "BACKGROUND", 0)
	-- a soft glow round the pill on hover (gold for the main button)
	b.glow = b:CreateTexture(nil, "BACKGROUND", nil, -2)
	b.glow:SetTexture(T.MEDIA .. "glow")
	b.glow:SetPoint("TOPLEFT", b, "TOPLEFT", -18, 14)
	b.glow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 18, -14)
	b.glow:Hide()
	b.label = T.Text(b, h >= 48 and 16 or (h >= 36 and "body" or "small"), "white", "CENTER", h >= 48 and "bold" or "medium")
	b.label:SetPoint("LEFT", b, "LEFT", h / 2, 0)
	b.label:SetPoint("RIGHT", b, "RIGHT", -h / 2, 0)
	b.label:SetText(text or "")

	function b.SetLabel(self, t) self.label:SetText(t or "") end
	function b.SetStyle(self, s)
		self.style = STYLES[s] and s or self.style
		pillPaint(self)
	end
	function b.SetActive(self, on)
		self.inactive = not on
		pillPaint(self)
	end
	function b.Repaint(self) pillPaint(self) end

	b:SetScript("OnEnter", function(self)
		self.hover = true
		pcall(pillPaint, self)
	end)
	b:SetScript("OnLeave", function(self)
		self.hover, self.pressed = nil, nil
		pcall(pillPaint, self)
	end)
	b:SetScript("OnMouseDown", function(self)
		if self.inactive then return end
		self.pressed = true
		pcall(pillPaint, self)
		A.Tap(self)
	end)
	b:SetScript("OnMouseUp", function(self)
		self.pressed = nil
		pcall(pillPaint, self)
	end)
	pillPaint(b)
	return b
end

---------------------------------------------------------------------------
-- Chips: a small coloured label with a dot ("Open", "Busy")
---------------------------------------------------------------------------

function T.Chip(parent, text, colour)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(60, 20)
	f.fill = T.PillFill(f, colour or "white", 20, "BACKGROUND", 1)
	f.dot = T.Circle(f, 6, colour or "white", "ARTWORK")
	f.dot:SetPoint("LEFT", f, "LEFT", 8, 0)
	f.label = T.Text(f, 10, colour or "white", "LEFT", "medium")
	f.label:SetPoint("LEFT", f.dot, "RIGHT", 5, 0)
	function f.SetChip(self, t, c)
		c = c or self.colour or "white"
		self.colour = c
		self.label:SetText(t or "")
		self.label:SetTextColor(T.RGB(c))
		self.dot:SetVertexColor(T.RGB(c))
		local r, g, b = T.RGB(c)
		self.fill:SetColor({ r, g, b, 0.16 })
		local width = tonumber(Try(self.label, "GetStringWidth")) or 0
		if width <= 0 then width = #(t or "") * 6 end
		self:SetWidth(math.floor(width + 27))
	end
	f:SetChip(text, colour or "white")
	return f
end

-- A badge with an outline (no dot): T.Badge(parent, "No helpers needed", "gold").
function T.Badge(parent, text, colour)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(60, 18)
	f.fill = T.PillFill(f, colour or "gold", 18, "BACKGROUND", 0)
	local parts = {}
	local coords = { { 0, 0.25 }, { 0.25, 0.75 }, { 0.75, 1 } }
	for i = 1, 3 do
		local t = f:CreateTexture(nil, "BORDER")
		t:SetTexture(T.MEDIA .. "pill_outline")
		t:SetTexCoord(coords[i][1], coords[i][2], 0, 1)
		parts[i] = t
	end
	parts[1]:SetPoint("TOPLEFT", f, "TOPLEFT")
	parts[1]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT")
	parts[1]:SetWidth(9)
	parts[3]:SetPoint("TOPRIGHT", f, "TOPRIGHT")
	parts[3]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT")
	parts[3]:SetWidth(9)
	parts[2]:SetPoint("TOPLEFT", parts[1], "TOPRIGHT")
	parts[2]:SetPoint("BOTTOMRIGHT", parts[3], "BOTTOMLEFT")
	f.edge = parts
	f.label = T.Text(f, 10, colour or "gold", "CENTER", "bold")
	f.label:SetPoint("CENTER", f, "CENTER", 0, 0)
	function f.SetBadge(self, t, c)
		c = c or self.colour or "gold"
		self.colour = c
		self.label:SetText(t or "")
		self.label:SetTextColor(T.RGB(c))
		local r, g, b = T.RGB(c)
		for _, p in ipairs(self.edge) do p:SetVertexColor(r, g, b, 0.9) end
		self.fill:SetColor({ r, g, b, 0.1 })
		local width = tonumber(Try(self.label, "GetStringWidth")) or 0
		if width <= 0 then width = #(t or "") * 6 end
		self:SetWidth(math.floor(width + 18))
	end
	f:SetBadge(text, colour or "gold")
	return f
end

---------------------------------------------------------------------------
-- A round icon button (close, back)
---------------------------------------------------------------------------

function T.RoundButton(parent, glyph, size, colour)
	size = size or 32
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	b.bg = T.Circle(b, size, colour or "card", "BACKGROUND")
	b.bg:SetPoint("CENTER", b, "CENTER")
	b.glyph = T.Icon(b, glyph, math.floor(size * 0.6), "white", "ARTWORK")
	b.glyph:SetPoint("CENTER", b, "CENTER")
	b:SetScript("OnEnter", function(self) self.bg:SetVertexColor(T.RGB("hover")) end)
	b:SetScript("OnLeave", function(self) self.bg:SetVertexColor(T.RGB(colour or "card")) end)
	b:SetScript("OnMouseDown", function(self) A.Tap(self) end)
	return b
end
