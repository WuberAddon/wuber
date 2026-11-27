-- Module: Theme.Anim
-- Purpose: T.Animate (A.*): fades, moves, slides, pops, zooms, taps, pulses, spinners, staggers; T.Tween; the motion
--   tokens, Reduce motion, timed glides and pages that slide (A.Push, A.PopPage).
-- API: T.Animate, T.HasText, A.Stop, A.FadeIn, A.FadeOut, A.Move, A.SlideUp, A.SlideIn, A.SlideOut, A.Pop,
--   A.ZoomIn, A.ZoomOut, A.Tap, Pulse:Stop, Pulse:Start, Pulse:SetColor, Pulse:SetShown, A.Pulse, Spin:Start,
--   Spin:Stop, A.Spin, A.Stagger, T.Tween, T.MOTION, T.ReduceMotion, T.Glide, T.GlideStop, A.Push, A.PopPage,
--   A.StopPage
-- Internals: (none)
-- Uses: Theme.Tokens
-- Later: (none)
-- Events: listens (none); fires (none)
-- Standalone: no
-- Test: tests/theme/anim_test.lua
-- From: Theme.lua 505-1037; Theme.lua 1278-1322 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("Theme.Anim", { "Theme.Tokens" })
local TokensMod = W.Mod("Theme.Tokens")
local MISSING, method = TokensMod.MISSING, TokensMod.method

local T = W.Theme
local Try = T.Try

---------------------------------------------------------------------------
-- Animations (AnimationGroups; every helper may be called again at any time)
---------------------------------------------------------------------------

local A = {}
T.Animate = A

-- (#305) Reduce motion: nothing moves, grows, turns or repeats; what is left is a short fade in place
local function still() return T.ReduceMotion and T.ReduceMotion() and true or false end
local living = setmetatable({}, { __mode = "k" }) -- every pulse and spin made (they stop when Reduce motion is switched on)

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
	-- this client draws text that is set while a Scale animation runs at the animated (tiny)
	-- size and keeps it: when any Wuber animation ends, the text under the frame is redrawn
	local play = ag.Play
	if type(play) == "function" then
		ag.Play = function(self, ...)
			local r = play(self, ...)
			local ok, d = pcall(self.GetDuration, self)
			d = ok and tonumber(d) or 0.5
			if W.After then
				W.After(math.min(3, math.max(0.05, d + 0.05)), function()
					if T.RefreshTextUnder then pcall(T.RefreshTextUnder, frame) end
				end)
			end
			return r
		end
	end
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

-- Whether text (a Wuber font string) sits inside the frame. This client draws text that is
-- set while a Scale animation runs at the animated size and keeps it (tiny labels), so frames
-- with text never scale: their scale animations become 1 -> 1 (their alpha and slides stay).
local function hasText(frame)
	if type(frame) ~= "table" then return false end
	local now = GetTime and GetTime() or 0
	if frame.wuberTextAt and now - frame.wuberTextAt < 5 then return frame.wuberHasText end
	local found = false
	for fs in pairs(T.allText) do
		local p, n = fs, 0
		while p and n < 16 do
			if p == frame then found = true break end
			local ok, parent = pcall(p.GetParent, p)
			p = ok and parent or nil
			n = n + 1
		end
		if found then break end
	end
	frame.wuberHasText, frame.wuberTextAt = found, now
	return found
end
T.HasText = hasText

local function scaleAnim(ag, order, duration, from, to, delay, smooth)
	local owner = ag and ag.GetParent and select(2, pcall(ag.GetParent, ag)) or nil
	if hasText(owner) then from, to = 1, 1 end
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
local MOVES = { fadein = true, fadeout = true, move = true, out = true, pop = true, zoomin = true, zoomout = true }
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
	-- (design 2) Reduce motion: the frame fades in where it stands, nothing travels
	if T.ReduceMotion and T.ReduceMotion() then fromX, fromY = 0, 0 end
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
	local still = T.ReduceMotion and T.ReduceMotion() -- (design 2) Reduce motion: it fades out where it stands
	ag.t:SetOffset(still and 0 or (toX or -40), still and 0 or (toY or 0))
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
	if still() then return A.FadeIn(frame, T.MOTION.reduced, delay) end
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

-- Sets a Scale animation's from/to again (the group is reused).
local function rescale(a, from, to)
	local okP, ag = pcall(a.GetParent, a)
	local owner = okP and ag and select(2, pcall(ag.GetParent, ag)) or nil
	if hasText(owner) then from, to = 1, 1 end
	local ok, res = pcall(method, a, "SetScaleFrom", from, from)
	if ok and res ~= MISSING then
		Try(a, "SetScaleTo", to, to)
	else
		Try(a, "SetFromScale", from, from)
		Try(a, "SetToScale", to, to)
	end
end

-- ZoomIn(frame, fromX, fromY, duration = 0.32, from = 0.3): an app opening on a phone. The
-- frame starts small at (fromX, fromY) from its place (the button that opened it; 0, 0 for
-- its own centre), grows past full size as it glides home and fades in, then settles.
A.ZoomIn = guarded("ZoomIn", function(frame, fromX, fromY, duration, from)
	stopMoves(frame)
	if still() then return A.FadeIn(frame, T.MOTION.reduced) end
	local ag, new = group(frame, "zoomin")
	local over = 1.035
	if new then
		ag.t0 = anim(ag, "Translation", 1, 0)
		ag.a0 = anim(ag, "Alpha", 1, 0)
		ag.a0:SetFromAlpha(0)
		ag.a0:SetToAlpha(0)
		ag.s0 = scaleAnim(ag, 1, 0, 1, 0.3)
		ag.t1 = anim(ag, "Translation", 2, 0.24, nil, "OUT")
		ag.s1 = scaleAnim(ag, 2, 0.24, 1, over / 0.3, nil, "OUT")
		ag.a1 = anim(ag, "Alpha", 2, 0.14, nil, "OUT")
		ag.a1:SetFromAlpha(0)
		ag.a1:SetToAlpha(1)
		ag.s2 = scaleAnim(ag, 3, 0.12, 1, 1 / over, nil, "IN_OUT")
	end
	fromX, fromY = fromX or 0, fromY or 0
	from = math.max(0.05, math.min(1, from or 0.3))
	duration = duration or 0.32
	ag.t0:SetOffset(fromX, fromY)
	ag.t1:SetOffset(-fromX, -fromY)
	rescale(ag.s0, 1, from)
	rescale(ag.s1, 1, over / from)
	ag.t1:SetDuration(duration * 0.68)
	ag.s1:SetDuration(duration * 0.68)
	ag.a1:SetDuration(duration * 0.4)
	ag.s2:SetDuration(duration * 0.32)
	frame:SetAlpha(1)
	frame:Show()
	ag:Play()
	return ag
end, showPlain)

-- ZoomOut(frame, toX, toY, duration = 0.2, to = 0.3, onDone): the app going back into its
-- button: shrinks toward (toX, toY), fades and hides.
A.ZoomOut = guarded("ZoomOut", function(frame, toX, toY, duration, to, onDone)
	stopMoves(frame)
	if still() then return A.FadeOut(frame, T.MOTION.reduced, onDone) end
	if not frame:IsShown() then
		if onDone then W.Safe("animate done", onDone, frame) end
		return nil
	end
	local ag, new = group(frame, "zoomout")
	if new then
		ag.t = anim(ag, "Translation", 1, 0.2, nil, "IN")
		ag.s = scaleAnim(ag, 1, 0.2, 1, 0.3, nil, "IN")
		ag.a = anim(ag, "Alpha", 1, 0.2, nil, "IN")
		ag.a:SetFromAlpha(1)
		ag.a:SetToAlpha(0)
		Try(ag, "SetToFinalAlpha", true)
	end
	duration = duration or 0.2
	to = math.max(0.05, math.min(1, to or 0.3))
	ag.t:SetOffset(toX or 0, toY or 0)
	rescale(ag.s, 1, to)
	ag.t:SetDuration(duration)
	ag.s:SetDuration(duration)
	ag.a:SetDuration(duration)
	local token = frame.wuberToken
	ag:SetScript("OnFinished", function()
		if frame.wuberToken ~= token then return end
		frame:Hide()
		frame:SetAlpha(1)
		if onDone then W.Safe("animate done", onDone, frame) end
	end)
	ag:Play()
	return ag
end, function(frame, _, _, _, _, onDone)
	frame:Hide()
	if onDone then pcall(onDone, frame) end
end)

-- Tap(frame): (Design 1) scales nothing and makes no animation: a press is a colour and a click (T.Press in
-- Theme.Widgets). The name stays for callers; it returns nil.
function A.Tap() return nil end

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
	if still() then return end -- (#305) Reduce motion: no rings
	self.running = true
	local token = self.token
	local n = #self.rings
	for i, r in ipairs(self.rings) do
		local delay = (i - 1) * self.period / n
		if delay <= 0 then
			r.ag:Play()
		else
			W.After(delay, function()
				if self.token == token and not still() then r.ag:Play() end -- (#305) the switch may have been turned on meanwhile
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
	living[p] = true
	if opts.start ~= false then p:Start() end
	return p
end

-- Spin(region, period = 1, clockwise = true): turns a texture round and round.
-- Returns a handle with :Stop() and :Start(). (20 Nov, the author: the empty Riders radar spun fast again.)
-- One region has ONE driver, ever: its angle is worked out from the clock (GetTime), not added up
-- frame by frame and not played by an animation group, so Start twice, Spin again, a rebuilt caller or a
-- second handle cannot make it faster: the turn time is always the period. Hidden frames do not tick.
local Spin = {}
Spin.__index = Spin
function Spin:Start()
	if still() then -- (#305) Reduce motion: it stands still, upright
		if self.driver then self.driver:Hide() end
		if self.region then Try(self.region, "SetRotation", 0) end
		return
	end
	if self.driver then self.driver:Show() end
end
function Spin:Stop()
	if self.driver then self.driver:Hide() end
end

function A.Spin(region, period, clockwise)
	if not region then return nil end
	period = period or 1
	if period <= 0 then period = 1 end
	local sign = (clockwise == false) and 1 or -1
	local s = region.wuberSpin
	if s then
		s.period, s.sign = period, sign
		s:Start()
		return s
	end
	s = setmetatable({ period = period, sign = sign, region = region }, Spin)
	living[s] = true
	local parent = Try(region, "GetParent")
	if parent then
		local d = CreateFrame("Frame", nil, parent)
		d:SetScript("OnUpdate", function()
			local ok = pcall(function()
				local turn = (GetTime() % s.period) / s.period
				Try(region, "SetRotation", s.sign * turn * 2 * math.pi)
			end)
			if not ok then d:Hide() end
		end)
		s.driver = d
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
-- Small per-frame tweens (for knobs and bars: no AnimationGroups needed)
---------------------------------------------------------------------------

local tweens, tweener = {}, nil
local function tweenStep(_, elapsed)
	local k = math.min(1, (elapsed or 0) * 14)
	local busy = false
	for obj, tw in pairs(tweens) do
		local v = tw.cur + (tw.target - tw.cur) * k
		if math.abs(v - tw.target) < 0.002 * math.max(1, math.abs(tw.target)) then v = tw.target end
		tw.cur = v
		local ok = pcall(tw.apply, obj, v)
		if not ok or v == tw.target then tweens[obj] = nil else busy = true end
	end
	if not busy and tweener then tweener:Hide() end
end

-- T.Tween(obj, from, to, apply(obj, v)): eases v from -> to over a few frames.
function T.Tween(obj, from, to, apply)
	if from == to then
		pcall(apply, obj, to)
		tweens[obj] = nil
		return
	end
	local tw = tweens[obj]
	if tw then
		tw.target, tw.apply = to, apply
	else
		tweens[obj] = { cur = from, target = to, apply = apply }
	end
	if not tweener then
		tweener = CreateFrame("Frame", nil, UIParent)
		tweener:SetScript("OnUpdate", function(self, e)
			local ok, err = pcall(tweenStep, self, e)
			if not ok then
				tweens = {}
				self:Hide()
				W.Error("tween", err)
			end
		end)
	end
	tweener:Show()
end

---------------------------------------------------------------------------
-- Motion tokens, Reduce motion, timed glides and pages that slide (Design 2)
---------------------------------------------------------------------------

-- The motion tokens (seconds), one table. page: a pushed page; sheetUp, sheetDown: a sheet; dim: the page
-- behind a sheet; fade: small changes of state; reduced: the fade in place of Reduce motion; pill: the pill.
T.MOTION = { page = 0.28, sheetUp = 0.32, sheetDown = 0.24, dim = 0.2, fade = 0.16, reduced = 0.12, pill = 0.45 }

-- T.ReduceMotion() -> true when the player switched "Reduce motion" on (read from W.db at every call).
function T.ReduceMotion()
	local db = W.db
	return type(db) == "table" and db.reduceMotion == true
end

-- (#305) switched on while pulses and spins run: they stop now, not at their next start
if type(W.Listen) == "function" then
	W.Listen("SETTINGS", function(key)
		if key ~= "reduceMotion" or not still() then return end
		for h in pairs(living) do
			if type(h.Stop) == "function" then pcall(h.Stop, h) end
			if h.region then Try(h.region, "SetRotation", 0) end
		end
	end)
end

-- T.Glide(obj, seconds, apply(obj, k), onDone, ease): a per-frame tween with a fixed length. k runs 0 -> 1 over
-- the seconds (ease "OUT", the default, "IN", or "NONE"); apply is called every frame and once with exactly 1,
-- then onDone(obj) once. A new glide on the same obj replaces the old one (which is dropped, not finished).
-- T.GlideStop(obj, finish): drops it; finish = true calls apply(obj, 1) and onDone first.
local glides, glider = {}, nil
local function eased(k, ease)
	if ease == "IN" then return k * k * k end
	if ease == "NONE" then return k end
	local r = 1 - k
	return 1 - r * r * r
end
local function glideEnd(obj, g)
	glides[obj] = nil
	pcall(g.apply, obj, 1)
	if g.onDone then W.Safe("glide done", g.onDone, obj) end
end
local function glideStep(_, elapsed)
	local done
	for obj, g in pairs(glides) do
		g.t = g.t + (elapsed or 0)
		if g.t >= g.d then
			done = done or {}
			done[#done + 1] = obj
		elseif not pcall(g.apply, obj, eased(g.t / g.d, g.ease)) then
			done = done or {}
			done[#done + 1] = obj
		end
	end
	for _, obj in ipairs(done or {}) do
		local g = glides[obj]
		if g then glideEnd(obj, g) end
	end
	if next(glides) == nil and glider then glider:Hide() end
end

function T.Glide(obj, seconds, apply, onDone, ease)
	if obj == nil or type(apply) ~= "function" then return end
	local g = { t = 0, d = tonumber(seconds) or 0, apply = apply, onDone = onDone, ease = ease }
	if g.d <= 0 then
		glideEnd(obj, g)
		return
	end
	glides[obj] = g
	pcall(apply, obj, 0)
	if not glider then
		glider = CreateFrame("Frame", nil, UIParent)
		glider:SetScript("OnUpdate", function(self, e)
			local ok, err = pcall(glideStep, self, e)
			if not ok then
				glides = {}
				self:Hide()
				W.Error("glide", err)
			end
		end)
	end
	glider:Show()
end

function T.GlideStop(obj, finish)
	local g = obj ~= nil and glides[obj]
	if not g then return end
	if finish then glideEnd(obj, g) else glides[obj] = nil end
end

-- Pages (with opts.single only one page is on screen: see below). A.Push(page, old, opts): page comes in from a full width to the right over T.MOTION.page while old
-- moves left by 30% of the width under a black cover that fades to 45%; at the end old is hidden and back in
-- its place and the cover is gone. A.PopPage(page, old, opts) undoes it with the SAME two frames: page (the one
-- on top) leaves to the right and is hidden, old comes back from 30% left as its cover clears.
-- opts: width (default the page's own), clip (the frame that cuts the pages off; SetClipsChildren(true) is called
-- on it once; default the page's parent), secure (true when either page holds a secure button), onDone
-- (function, called once when the pages are in their final state), place (function(frame, dx): puts a frame dx
-- to the right of its place; default: the frame's points are remembered and set again shifted by dx),
-- coverLevel (frame level of the cover; default 20 above the higher of the two pages), single (true or a colour
-- token; for two pages that are siblings whose frames can interleave, so neither can lie wholly over the other:
-- only ONE page is on screen during the move. The page that is hidden at the end is hidden when the move STARTS
-- and never travels; Push: the new page comes in from a full width to the right; PopPage: the page that comes
-- back slides in from 30% to the left of its place. It travels over a flat fill in that colour, true = "black",
-- the window's own, that fills the clip frame: a texture OF the clip frame (BACKGROUND layer), so it lies under
-- every frame in the clip frame by parenting alone; shown when the move starts, hidden when it ends, never
-- faded. No cover. With Reduce motion or in combat there is no fill.) Without single the page on top must be
-- opaque and lie above the other by itself (a panel over a tab). NO frame level of a page is ever changed.
-- The travel is SetPoint per frame (T.Glide), the cover's alpha is set by the same glide: no Translation, no
-- Alpha and no Scale animation. Called while a move runs in the same clip frame or with one of its frames, that
-- move jumps to its end first. T.ReduceMotion(): the page fades in in place over T.MOTION.reduced, nothing
-- travels. In combat with opts.secure (or a protected page): no move and no fade, the pages swap at once and a
-- protected frame is not touched. A.StopPage(clip) ends the move in that clip frame at once (no clip: all).
local PAGE = { back = 0.3, cover = 0.45, moves = {} }

local function pagePoints(frame)
	local pts = {}
	for i = 1, tonumber(Try(frame, "GetNumPoints")) or 0 do
		local p, rel, rp, x, y = frame:GetPoint(i)
		if p then pts[#pts + 1] = { p, rel, rp, x or 0, y or 0 } end
	end
	return pts
end

-- puts a frame dx right of its place (opts.place, or its remembered points shifted)
local function pagePlace(m, frame, dx)
	if not frame then return end
	if m.place then
		W.Safe("page place", m.place, frame, dx)
		return
	end
	local pts = m.points[frame]
	if not pts or #pts == 0 then return end
	frame:ClearAllPoints()
	for _, p in ipairs(pts) do
		if p[2] then frame:SetPoint(p[1], p[2], p[3], p[4] + dx, p[5]) else frame:SetPoint(p[1], p[4] + dx, p[5]) end
	end
end

local function pageCover(clip, level)
	local c = clip.wuberPageCover
	if not c then
		c = CreateFrame("Frame", nil, clip)
		c.tex = c:CreateTexture(nil, "BACKGROUND")
		c.tex:SetColorTexture(0, 0, 0, 1)
		c.tex:SetAllPoints(c)
		c:Hide()
		clip.wuberPageCover = c
	end
	if level then pcall(c.SetFrameLevel, c, level) end
	return c
end

-- the flat fill behind the one page of a single move (opts.single): one texture per clip frame, a region of the
-- clip frame itself, so it is under every child frame without any frame level; used again by every move
local function pageBacking(m, clip, token)
	local b = clip.wuberPageBacking
	if not b then
		b = clip:CreateTexture(nil, "BACKGROUND", nil, 7)
		b:SetAllPoints(clip)
		b:Hide()
		clip.wuberPageBacking = b
	end
	local r, g, bl = T.RGB(type(token) == "string" and token or "black")
	b:SetColorTexture(r or 0, g or 0, bl or 0, 1)
	b:SetAlpha(1)
	b:Show()
	m.backing = b
end

local function protectedFrame(frame)
	if not frame then return false end
	local ok, p = pcall(frame.IsProtected, frame)
	return ok and p and true or false
end

-- the move's last frame: everything in its final place, the leaving frame hidden, onDone once
local function pageFinish(m)
	if m.done then return end
	m.done = true
	if PAGE.moves[m.clip] == m then PAGE.moves[m.clip] = nil end
	T.GlideStop(m, false)
	pcall(function()
		if m.cover then
			m.cover:SetAlpha(0)
			m.cover:Hide()
		end
		if m.backing then m.backing:Hide() end
		if m.leaves then m.leaves:Hide() end
		if m.travels then
			pagePlace(m, m.leaves, 0)
			pagePlace(m, m.stays, 0)
		end
		if m.fades then m.fades:SetAlpha(1) end
	end)
	if m.onDone then W.Safe("page done", m.onDone, m.stays, m.leaves) end
	-- (#36) the pages are in place: the header's drag strip leaves the arrow and switch where they stand now
	if W.UI and W.UI.HeadHit then W.Safe("head hit", W.UI.HeadHit) end
end

local function pageEndFor(clip, a, b)
	local list
	for _, m in pairs(PAGE.moves) do
		if m.clip == clip or (a and (m.stays == a or m.leaves == a)) or (b and (m.stays == b or m.leaves == b)) then
			list = list or {}
			list[#list + 1] = m
		end
	end
	for _, m in ipairs(list or {}) do pageFinish(m) end
end

function A.StopPage(clip)
	if clip then
		local m = PAGE.moves[clip]
		if m then pageFinish(m) end
		return
	end
	pageEndFor(nil)
	local list = {}
	for _, m in pairs(PAGE.moves) do list[#list + 1] = m end
	for _, m in ipairs(list) do pageFinish(m) end
end

-- stays: the frame shown at the end; leaves: the one hidden at the end; push: true when stays comes from the right
local function pageMove(stays, leaves, opts, push)
	opts = opts or {}
	local clip = opts.clip or Try(stays, "GetParent") or stays
	pageEndFor(clip, stays, leaves)
	local m = { clip = clip, stays = stays, leaves = leaves, onDone = opts.onDone, place = opts.place, points = {} }
	if InCombatLockdown and InCombatLockdown() and (opts.secure or protectedFrame(stays) or protectedFrame(leaves)) then
		-- combat and a secure button: swap at once; a protected frame is left exactly as it is
		if not protectedFrame(stays) then stays:Show() end
		if leaves and not protectedFrame(leaves) then leaves:Hide() end
		if m.onDone then W.Safe("page done", m.onDone, stays, leaves) end
		return false
	end
	if not clip.wuberClips then
		Try(clip, "SetClipsChildren", true)
		clip.wuberClips = true
	end
	if T.ReduceMotion() then
		if leaves then leaves:Hide() end
		m.leaves, m.fades = nil, stays
		stays:SetAlpha(0)
		stays:Show()
		PAGE.moves[clip] = m
		T.Glide(m, T.MOTION.reduced, function(_, k) stays:SetAlpha(k) end, pageFinish, "NONE")
		return true
	end
	local width = tonumber(opts.width) or tonumber(Try(stays, "GetWidth")) or 0
	if width <= 0 then width = tonumber(Try(clip, "GetWidth")) or 0 end
	local under = push and leaves or stays -- the page underneath: it is the one that dims
	local top = push and stays or leaves
	if not m.place then
		m.points[stays] = pagePoints(stays)
		if leaves then m.points[leaves] = pagePoints(leaves) end
	end
	m.travels = true
	local single = opts.single and true or false
	if single then
		-- one page on screen: the one that goes is hidden now, the other travels over the flat fill
		if leaves then leaves:Hide() end
		pcall(pageBacking, m, clip, opts.single)
	elseif under and top then
		local lv = tonumber(opts.coverLevel)
		if not lv then
			lv = math.max(tonumber(Try(under, "GetFrameLevel")) or 0, tonumber(Try(top, "GetFrameLevel")) or 0) + 20
		end
		local cover = pageCover(clip, lv)
		-- the cover lies over the part of the lower page that shows: from its left edge to the upper page's left
		cover:ClearAllPoints()
		cover:SetPoint("TOPLEFT", under, "TOPLEFT", 0, 0)
		cover:SetPoint("BOTTOMRIGHT", top, "BOTTOMLEFT", 0, 0)
		cover:SetAlpha(push and 0 or PAGE.cover)
		cover:Show()
		m.cover = cover
	end
	local function step(_, k)
		if single then
			pagePlace(m, stays, (push and width or -PAGE.back * width) * (1 - k))
		elseif push then
			pagePlace(m, stays, width * (1 - k))
			pagePlace(m, leaves, -PAGE.back * width * k)
			if m.cover then m.cover:SetAlpha(PAGE.cover * k) end
		else
			pagePlace(m, leaves, width * k)
			pagePlace(m, stays, -PAGE.back * width * (1 - k))
			if m.cover then m.cover:SetAlpha(PAGE.cover * (1 - k)) end
		end
	end
	PAGE.moves[clip] = m
	step(m, 0)
	stays:Show()
	T.Glide(m, T.MOTION.page, step, pageFinish, "OUT")
	return true
end

-- Push(page, old, opts): page comes in from the right over old (old may be nil). Returns true when it moves or fades.
A.Push = guarded("Push", function(page, old, opts)
	return pageMove(page, old, opts, true)
end, function(page, old, opts)
	pcall(page.Show, page)
	if old then pcall(old.Hide, old) end
	if type(opts) == "table" and opts.onDone then pcall(opts.onDone, page, old) end
end)

-- PopPage(page, old, opts): the way back, with the same two frames as the Push: page leaves to the right, old returns.
A.PopPage = guarded("PopPage", function(page, old, opts)
	if not old then
		pageEndFor(type(opts) == "table" and opts.clip or nil, page)
		page:Hide()
		if type(opts) == "table" and opts.onDone then W.Safe("page done", opts.onDone, nil, page) end
		return false
	end
	return pageMove(old, page, opts, false)
end, function(page, old, opts)
	pcall(page.Hide, page)
	if old then pcall(old.Show, old) end
	if type(opts) == "table" and opts.onDone then pcall(opts.onDone, old, page) end
end)
