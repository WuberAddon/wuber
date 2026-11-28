-- Module: Theme.Widgets
-- Purpose: pills, chips, badges, round buttons, tooltips (T.Tip, on the WuberTip card), toggles, sliders, segmented controls, bars,
--   glows, crowns, tier colours.
-- API: T.PILL_STYLES, T.Press, T.PressDown, T.PressUp, T.Pill, T.MainButton, T.MAIN, T.Chip, T.Badge, T.RoundButton, T.TipShow, T.TipHide, T.TipOwner, T.TipHook, T.Tip, T.RefreshTip, T.SolidTip, T.Toggle, T.Slider,
--   T.Segmented, T.Bar, T.OuterGlow, T.EdgeGlow, T.StateGlow, T.FxLevel, T.FxFrame, T.Crown, T.DriverBadge, T.BadgeTexture, T.TIER,
--   T.PIONEER, T.PioneerLook, T.PioneerBadge, T.ShowPioneer, T.TIP_W, T.NoGlow
-- Internals: pillText, Mod.TIP (the tip card's numbers)
-- Uses: Theme.Tokens
-- Later: (none)
-- Events: listens (none); fires (none)
-- Standalone: no
-- Test: tests/theme/widgets_test.lua
-- From: Theme.lua 1038-1277; Theme.lua 1323-1615 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("Theme.Widgets", { "Theme.Tokens" })
local TokensMod = W.Mod("Theme.Tokens")
local hex = TokensMod.hex

local T = W.Theme
local Try = T.Try

---------------------------------------------------------------------------
-- Pill buttons
---------------------------------------------------------------------------
-- T.Pill(parent, text, style, w, h): (Design 1) three kinds of button: "primary" the one main button of a
-- screen (gold, ink words), "dark" the second button (the raised card colour, white words), "ghost" a link
-- (no fill, violet words; "danger" the same with red words). "violet" is no kind of button: it is the look of a
-- chosen option or a state that is on (violet fill, ink words); no action asks for it. Over T.CORNER.round (32) high a pill is a rounded
-- rectangle, else fully round (T.PillFill); no glow on hover (b.glow draws nothing). The button's own OnEnter/OnLeave/OnMouseDown/OnMouseUp draw
-- the hover and press looks: add your own with HookScript, and set OnClick as usual.
-- b:SetLabel(text), b:SetStyle(style), b:SetActive(bool) (an inactive pill looks quiet and
-- does not click), b.label, b.fill.

-- a token's colour a little lighter (by) or see-through (alpha), as a colour table
local function shade(name, by, alpha)
	local c = T.C[name]
	return { math.max(0, math.min(1, c[1] + by)), math.max(0, math.min(1, c[2] + by)), math.max(0, math.min(1, c[3] + by)), alpha or c[4] or 1 }
end

local function nothing() end

---------------------------------------------------------------------------
-- T.Press: every press answers at once (Design 1, item 6)
---------------------------------------------------------------------------
-- T.Press(frame, opts): the one press look and the one soft click of every control. Mouse down: the pressed fill
-- AT ONCE and one W.Sound("click"); mouse up, leaving or hiding: back to the resting (or hover) fill, eased over about
-- 0.16 s (T.Tween). Nothing is scaled. An inactive or disabled control (frame.inactive, frame.disabled, a disabled
-- Button, opts.inactive(frame)) is silent and unchanged. opts:
--   fill     what to paint: a slice or pill fill (SetColor) or a texture (SetVertexColor), or function(frame) giving
--            it; none: only the sound
--   rest     where it goes back to (a token, a colour table, or function(frame)); left out: the colour it had when
--            the mouse went down, which is what a screen wants (its own hover and state colours stay its own)
--   hover    with rest: the colour to go back to while the mouse is still over it
--   pressed  the pressed colour; by default card colours go to "raised", "raised"/"hover" to "line", gold to
--            "goldPress", violet and other bright fills a little darker, other dark fills a step lighter
--   paint    function(frame, pressed) for a control that paints itself (frame.wuberPressed is set meanwhile)
--   quiet    true: no sound
-- It hooks OnMouseDown, OnMouseUp, OnEnter, OnLeave and OnHide (HookScript: existing scripts stay), so call it AFTER
-- any SetScript of those on the frame, once, where the control is built; calling it again only changes opts.
-- Never call it on a secure button. A T.Pill has it built in.
local PRESSED = { card = "raised", panel = "raised", black = "raised", raised = "line", hover = "line",
	gold = "goldPress", goldLight = "goldPress" }
local function nearColour(c, name)
	local t = T.C[name]
	return math.abs(c[1] - t[1]) < 0.012 and math.abs(c[2] - t[2]) < 0.012 and math.abs(c[3] - t[3]) < 0.012
end
-- the pressed look of a resting colour (a token or a colour table)
local function pressedOf(rest)
	if type(rest) == "string" then
		if PRESSED[rest] then return PRESSED[rest] end
		if rest == "accent" or rest == "glow" or rest == "magenta" then return shade("accent", -0.08) end
		if rest == "line" then return shade("line", 0.06) end
		if not T.C[rest] then return "raised" end
		rest = T.C[rest]
	end
	if type(rest) ~= "table" then return "raised" end
	local r, g, b, a = rest[1] or 1, rest[2] or 1, rest[3] or 1, rest[4] or 1
	local c = { r, g, b, a }
	if a < 0.05 then return "raised" end -- nothing drawn at rest: the card2 fill
	if a < 0.9 then return { r, g, b, math.min(1, a + 0.14) } end -- a see-through fill: more of it
	if nearColour(c, "raised") then return "line" end
	if nearColour(c, "card") or nearColour(c, "panel") then return "raised" end
	if nearColour(c, "gold") or nearColour(c, "goldLight") then return "goldPress" end
	-- a dark fill a step lighter, a bright one (violet, white) a little darker
	local by = (0.3 * r + 0.59 * g + 0.11 * b) < 0.4 and 0.06 or -0.08
	return { math.max(0, math.min(1, r + by)), math.max(0, math.min(1, g + by)), math.max(0, math.min(1, b + by)), a }
end
local function pressValue(v, frame)
	if type(v) == "function" then
		local ok, res = pcall(v, frame)
		return ok and res or nil
	end
	return v
end
-- the colour a fill is drawn in now, as a table
local pressShown
function pressShown(fill)
	local tex = fill
	if type(fill.parts) == "table" then
		local _, part = next(fill.parts)
		tex = part
		if not tex and type(fill.rect) == "table" then return pressShown(fill.rect) end
	end
	if type(tex) ~= "table" or type(tex.GetVertexColor) ~= "function" then return nil end
	local r, g, b, a = tex:GetVertexColor()
	if type(r) ~= "number" then return nil end
	return { r, g or r, b or r, a or 1 }
end
-- paints the fill and remembers what was painted, so a release can tell when the screen painted it meanwhile
local function pressFill(fill, c)
	if type(fill.SetColor) == "function" then
		fill:SetColor(c)
	else
		fill:SetVertexColor(T.RGB(c))
	end
	fill.wuberPressColour = pressShown(fill)
end
local function pressOurs(fill)
	local c, now = fill.wuberPressColour, pressShown(fill)
	if not (c and now) then return false end
	for i = 1, 4 do
		if math.abs(c[i] - now[i]) > 0.004 then return false end
	end
	return true
end
local function pressPaint(frame, pressed)
	local o = frame.wuberPress
	if type(o) ~= "table" then return end
	if type(o.paint) == "function" then
		pcall(o.paint, frame, pressed)
		return
	end
	local fill = pressValue(o.fill, frame)
	if type(fill) ~= "table" then return end
	if pressed then
		-- where it goes back to: opts.rest / opts.hover, else the colour it had when the mouse went down (a release
		-- that was still easing back: the colour that one was going to)
		local back = fill.wuberPressBack
		T.Tween(fill, 1, 1, nothing)
		fill.wuberPressBack = nil
		frame.wuberPressFill = fill
		frame.wuberPressFrom = (back and pressOurs(fill) and back) or pressShown(fill) or "card"
		pressFill(fill, pressValue(o.pressed, frame) or pressedOf(pressValue(o.rest, frame) or frame.wuberPressFrom))
		return
	end
	fill = frame.wuberPressFill or fill
	if not pressOurs(fill) then return end -- the screen repainted it while it was down: its colour stands
	local from, kept = fill.wuberPressColour, frame.wuberPressFrom
	local function back()
		return (frame.wuberOver and pressValue(o.hover, frame)) or pressValue(o.rest, frame) or kept or "card"
	end
	fill.wuberPressBack = back()
	T.Tween(fill, 0, 1, function(f, v)
		-- the screen painted the fill itself meanwhile (a new state, the mouse left): its colour stands
		if not pressOurs(f) then
			f.wuberPressBack = nil
			error("repainted", 0)
		end
		local to = back()
		if v >= 1 then
			f.wuberPressBack = nil
			pressFill(f, to)
			return
		end
		local tr, tg, tb, ta = T.RGB(to)
		pressFill(f, { from[1] + (tr - from[1]) * v, from[2] + (tg - from[2]) * v, from[3] + (tb - from[3]) * v, from[4] + (ta - from[4]) * v })
	end)
end
local function pressOff(frame)
	if frame.inactive or frame.disabled then return true end
	local o = frame.wuberPress
	if type(o) == "table" and type(o.inactive) == "function" then
		local ok, off = pcall(o.inactive, frame)
		if ok and off then return true end
	end
	if type(frame.IsEnabled) == "function" then
		local ok, on = pcall(frame.IsEnabled, frame)
		if ok and on == false then return true end
	end
	return false
end
-- (a press that is already down does nothing more: a frame that passes its mouse down on may call both the
-- script and T.PressDown, and the player still hears one click)
local function pressDown(frame)
	local o = frame.wuberPress
	if type(o) ~= "table" or frame.wuberPressed or pressOff(frame) then return end
	frame.wuberPressed = true
	pressPaint(frame, true)
	if not o.quiet then W.Sound("click") end
end
local function pressUp(frame)
	if not frame.wuberPressed then return end
	frame.wuberPressed = nil
	pressPaint(frame, false)
end
-- T.PressDown(frame), T.PressUp(frame): the press of a control that has T.Press, for a frame lying over it that
-- passes its own mouse down and up on (a badge on a card). Safe on anything; never twice for one press.
function T.PressDown(frame)
	if type(frame) == "table" then pcall(pressDown, frame) end
end
function T.PressUp(frame)
	if type(frame) == "table" then pcall(pressUp, frame) end
end
function T.Press(frame, opts)
	if type(frame) ~= "table" or type(frame.HookScript) ~= "function" then return frame end
	if frame.wuberPressOwn then return frame end -- a T.Pill: its own scripts press and click already
	local had = frame.wuberPress
	if had and type(opts) ~= "table" then return frame end -- called again with nothing new: keep its fill
	frame.wuberPress = type(opts) == "table" and opts or {}
	if had then return frame end
	Try(frame, "HookScript", "OnMouseDown", function(self) pcall(pressDown, self) end)
	Try(frame, "HookScript", "OnMouseUp", function(self) pcall(pressUp, self) end)
	Try(frame, "HookScript", "OnEnter", function(self) self.wuberOver = true end)
	Try(frame, "HookScript", "OnLeave", function(self)
		self.wuberOver = nil
		pcall(pressUp, self)
	end)
	Try(frame, "HookScript", "OnHide", function(self)
		self.wuberOver = nil
		pcall(pressUp, self)
	end)
	return frame
end
local STYLES = {
	primary = { bg = "gold", hover = "goldLight", press = "goldPress", text = "ink" },
	dark = { bg = "raised", hover = shade("raised", 0.05), press = "line", text = "white" },
	ghost = { bg = shade("glow", 0, 0), hover = shade("glow", 0, 0.10), press = shade("glow", 0, 0.18), text = "glow" },
	danger = { bg = shade("red", 0, 0), hover = shade("red", 0, 0.10), press = shade("red", 0, 0.18), text = "red" },
	off = { bg = "card", hover = "card", press = "card", text = "offText" }, -- S12: readable when disabled
}
-- "violet": what is chosen or on (never an action): the one violet with ink words (white on violet is 2.8 to 1)
STYLES.violet = { bg = "accent", hover = shade("accent", 0.04), press = shade("accent", -0.08), text = "ink" }
T.PILL_STYLES = STYLES

-- (Design 1) what a glow that is no longer drawn leaves behind: an object with a slice's and a texture's
-- methods (SetColor, SetAlpha, SetShown, Show, Hide, SetVertexColor, ...) that makes no texture; any
-- other method a caller uses is there too and does nothing.
local NoGlow = { __index = function() return nothing end }
local function noGlow() return setmetatable({ parts = {}, nothing = true }, NoGlow) end
-- T.NoGlow(): the bare no-op glow the UI files hand-place (takes every call, does nothing, holds no fields)
local NoOpGlow = { __index = function() return function() end end }
T.NoGlow = function() return setmetatable({}, NoOpGlow) end

local function pillPaint(b)
	local st = STYLES[b.inactive and "off" or b.style] or STYLES.dark
	local fill = st.bg
	if not b.inactive then
		if b.pressed then fill = st.press elseif b.hover then fill = st.hover end
	end
	-- a pill lit by its own pill (b.lit: tabs, Earnings periods; b.chosen: segments) keeps its
	-- fill hidden: it is not repainted (it would only be covered by the lit pill)
	if not (type(b.lit) == "table" or type(b.chosen) == "table") then b.fill:SetColor(fill) end
	-- a colour the screen gave the label itself (b.ownColour) outlives hover and press; an inactive pill uses its own
	if b.ownColour and not b.inactive then
		b.painting = true
		b.label:SetTextColor(unpack(b.ownColour))
		b.painting = nil
	else
		b.painting = true
		b.label:SetTextColor(T.RGB(st.text))
		b.painting = nil
	end
	if b.icon then b.icon:SetVertexColor(T.RGB(st.text)) end
end

-- (design round 3) a pill's label takes its size name and weight from the pill's height: 48 and up heading and
-- bold, 36 and up body, smaller sub (medium). T.Pill and T.Segmented (sizing its segments by label) both ask here.
local function pillText(h)
	if h >= 48 then return "heading", "bold" end
	if h >= 36 then return "body", "medium" end
	return "sub", "medium"
end

function T.Pill(parent, text, style, w, h, name, template)
	w, h = w or 140, h or 44
	local b = CreateFrame("Button", name, parent, template)
	b:SetSize(w, h)
	b.style = STYLES[style] and style or "dark"
	b.fill = T.PillFill(b, STYLES[b.style].bg, h, "BACKGROUND", 0) -- its first alpha is its style's
	b.glow = noGlow() -- (Design 1) no glow on hover; the name stays for callers
	-- the fill follows the pill's height (capsule up to 32 high, a rounded rectangle above)
	Try(b, "HookScript", "OnSizeChanged", function(self, _, hh)
		if type(self.fill) == "table" and type(self.fill.SetHeight) == "function" and tonumber(hh) then self.fill:SetHeight(hh) end
	end)
	local labelSize, labelWeight = pillText(h)
	b.label = T.Text(b, labelSize, "white", "CENTER", labelWeight)
	b.label:SetPoint("LEFT", b, "LEFT", h / 2, 0)
	b.label:SetPoint("RIGHT", b, "RIGHT", -h / 2, 0)
	-- a long label wraps onto two lines in a tall pill, else it shrinks a little (T.Fit)
	b.label.wuberRoom = w - h
	if h >= 34 then b.label.wuberLines = 2 end
	b.label:SetText(text or "")
	-- remember a label colour a screen sets directly, so the next hover or press repaints with it
	local rawSetColour = b.label.SetTextColor
	function b.label.SetTextColor(fs, r, g, bl, a)
		if not b.painting then b.ownColour = { r, g, bl, a } end
		return rawSetColour(fs, r, g, bl, a)
	end

	function b.SetLabel(self, t)
		self.label.wuberRoom = (tonumber((self:GetWidth())) or w) - (tonumber((self:GetHeight())) or h)
		self.label:SetText(t or "")
		T.Fit(self.label)
	end
	function b.SetStyle(self, s)
		self.style = STYLES[s] and s or self.style
		self.ownColour = nil
		pillPaint(self)
	end
	function b.SetActive(self, on)
		self.inactive = not on
		self.ownColour = nil
		pillPaint(self)
	end
	function b.Repaint(self) pillPaint(self) end

	b:SetScript("OnEnter", function(self)
		self.hover = true
		pcall(pillPaint, self)
	end)
	b:SetScript("OnLeave", function(self)
		self.hover, self.pressed, self.wuberPressed = nil, nil, nil
		pcall(pillPaint, self)
	end)
	-- (Design 1) the press of T.Press, in the pill's own scripts (a secure overlay forwards them, UI.Secure): the
	-- pressed fill at once and the one click; an inactive pill is silent and unchanged
	b.wuberPressOwn = true
	b.wuberPress = { paint = function(self, pressed)
		self.pressed = pressed or nil
		pillPaint(self)
	end }
	b:SetScript("OnMouseDown", function(self) pcall(pressDown, self) end)
	b:SetScript("OnMouseUp", function(self)
		self.pressed, self.wuberPressed = nil, nil
		pcall(pillPaint, self)
	end)
	pillPaint(b)
	if type(T.OnTheme) == "function" then T.OnTheme(b, pillPaint) end
	return b
end

-- (Design 2, item 9) T.MainButton(parent, label[, opts]): the one main button of a screen, always in the same place: a
-- T.Pill in style "primary", T.MAIN.h (46) high, T.MAIN.side (16) from each side of parent and T.MAIN.foot (12) above
-- its bottom (opts.foot overrides the 12 when something must sit under it, such as a link; opts.name, opts.template are
-- passed on). Its label is always the bold weight. It returns the T.Pill itself, so SetLabel, SetStyle, SetActive and the rest keep working. The place is set
-- here, once, when the screen is built: a secure overlay laid over it never has to follow it.
T.MAIN = { h = 46, side = 16, foot = 12 }
function T.MainButton(parent, label, opts)
	opts = opts or {}
	local M = T.MAIN
	local pw = tonumber((parent and parent.GetWidth and parent:GetWidth())) or 0
	local b = T.Pill(parent, label, "primary", pw > 2 * M.side + 40 and (pw - 2 * M.side) or 300, M.h, opts.name, opts.template)
	b:ClearAllPoints()
	b:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", M.side, opts.foot or M.foot)
	b:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -M.side, opts.foot or M.foot)
	b:SetHeight(M.h)
	-- the words of the main button are bold on every screen, and stay bold through SetLabel and SetStyle
	local function bold()
		if b.label.wuberWeight ~= "bold" then T.SetFont(b.label, "body", "bold") end
	end
	bold()
	local setLabel, setStyle = b.SetLabel, b.SetStyle
	function b.SetLabel(self, t)
		bold()
		return setLabel(self, t)
	end
	function b.SetStyle(self, s)
		local r = setStyle(self, s)
		bold()
		return r
	end
	return b
end

---------------------------------------------------------------------------
-- Chips: a small coloured label with a dot ("Open", "Busy")
---------------------------------------------------------------------------

-- (design 1) At rest the chip is flat card2 with its words (and dot) in the colour given, white by default;
-- f:SetChosen(on) makes it the chosen one of a set: a violet fill with ink words.
function T.Chip(parent, text, colour)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(60, 20)
	f.fill = T.PillFill(f, "raised", 20, "BACKGROUND", 1) -- made at the alpha it keeps
	f.dot = T.Circle(f, 6, colour or "white", "ARTWORK")
	f.dot:SetPoint("LEFT", f, "LEFT", 8, 0)
	f.label = T.Text(f, "caption", colour or "white", "LEFT", "medium")
	f.label:SetPoint("LEFT", f.dot, "RIGHT", 5, 0)
	function f.SetChip(self, t, c)
		c = c or self.colour or "white"
		self.colour = c
		self.label:SetText(t or "")
		local shown = self.chosen and "ink" or c
		self.label:SetTextColor(T.RGB(shown))
		self.dot:SetVertexColor(T.RGB(shown))
		self.fill:SetColor(self.chosen and "accent" or "raised")
		local width = T.TextWidth(self.label, t or "")
		if width <= 0 then width = #(t or "") * 6 end
		self:SetWidth(math.floor(width + 27))
	end
	function f.SetChosen(self, on)
		self.chosen = on and true or nil
		self:SetChip(self.label:GetText(), self.colour)
	end
	f:SetChip(text, colour or "white")
	return f
end

-- A badge with an outline (no dot): T.Badge(parent, "No helpers needed", colour). Grey ("muted") unless the caller
-- names a colour: gold is for a price, the main button and the Founder badge, so only a caller can ask for it.
function T.Badge(parent, text, colour)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(60, 18)
	f.fill = T.PillFill(f, colour or "muted", 18, "BACKGROUND", 0)
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
	f.label = T.Text(f, "caption", colour or "muted", "CENTER", "bold")
	f.label:SetPoint("CENTER", f, "CENTER", 0, 0)
	function f.SetBadge(self, t, c)
		c = c or self.colour or "muted"
		self.colour = c
		self.label:SetText(t or "")
		self.label:SetTextColor(T.RGB(c))
		local r, g, b = T.RGB(c)
		for _, p in ipairs(self.edge) do p:SetVertexColor(r, g, b, 0.9) end
		self.fill:SetColor({ r, g, b, 0.1 })
		local width = T.TextWidth(self.label, t or "")
		if width <= 0 then width = #(t or "") * 6 end
		self:SetWidth(math.floor(width + 18))
	end
	f:SetBadge(text, colour or "muted")
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
	-- (the real client's GetTexture() gives a file id, never the name: pages find a back arrow by this flag)
	if glyph == "back" then b.wuberBackArrow = true end
	b:SetScript("OnEnter", function(self) self.bg:SetVertexColor(T.RGB("hover")) end)
	b:SetScript("OnLeave", function(self) self.bg:SetVertexColor(T.RGB(colour or "card")) end)
	T.Press(b, { fill = b.bg })
	return b
end

---------------------------------------------------------------------------
-- Tooltips: Wuber's own tip card (WuberTip): T.TipShow, T.TipHide, T.TipOwner, T.Tip(frame, title, text)
---------------------------------------------------------------------------
-- (design 4, item 17) Every Wuber tip is drawn on ONE frame of Wuber's own, "WuberTip", made when the first tip
-- shows: a small card2 card with the app's one corner, never see-through, on the TOOLTIP strata, parented to
-- UIParent (never to a frame of the game's map). The title is "body" medium white; each line under it is "sub"
-- regular in the muted grey unless it names another colour token. Text wraps at TIP.wrap (wider only for one long
-- word) with TIP.pad around it. The card holds text, so it is never scaled: it fades in (TIP.fade; Reduce motion:
-- there at once) and hides at once. It never takes the mouse. The game's own tooltip is not used and not changed.
--
-- It stands BESIDE its owner, never on it: the side the caller prefers first (anchor), then right, left, above,
-- below, TIP.clear away; the first side where it lies wholly on the screen wins. If none does it takes the side
-- with the most room and is moved back onto the screen.
--
-- T.TipShow(owner, title, lines, anchor) -> the card, or nil (no title). lines: nil, one string, or a list whose
--   entries are a string or { text, "token" }. anchor: one of the game's ANCHOR_ names, read as a preference
--   (ANCHOR_RIGHT right, ANCHOR_LEFT left, ANCHOR_TOP... above, ANCHOR_BOTTOM... below; none: right).
-- T.TipHide(owner): hides the card if it is owner's (owner nil: whoever's it is).
-- T.TipOwner() -> the frame whose tip shows now, or nil.
-- A frame may also carry frame.wuberWholes (set by T.WholeOnHover, Theme.Forms): see showTip. T.TipHook(frame) hooks it.
-- The card: card.owner, card.side ("right", "left", "above", "below"), card.title, card.lines (font strings).
--
-- T.Tip(frame, title, text, anchor): a short title and one plain sentence on what the thing does. title and text
-- may be functions (called on each mouse-over, returning the text). Hooks OnEnter/OnLeave, so call
-- it AFTER any SetScript("OnEnter"/"OnLeave") on the frame. Calling it again only changes the
-- words. Returns the frame.

local function tipValue(v, frame)
	if type(v) == "function" then
		local ok, res = pcall(v, frame)
		if ok then return res end
		return nil
	end
	return v
end

-- wrap: the widest a tip's text gets; pad: around the text; clear: between the card and its owner; fade: seconds;
-- settle: how long a shown card measures itself again (the game has a new string's font a moment late)
local TIP = { wrap = 240, pad = 12, clear = 8, fade = 0.14, settle = 0.6 }
Mod.TIP = TIP
-- about the widest a tip gets (the card's width with a full line)
T.TIP_W = TIP.wrap + 2 * TIP.pad
local TIP_PREFER = {
	ANCHOR_RIGHT = "right", ANCHOR_LEFT = "left", ANCHOR_TOP = "above", ANCHOR_TOPLEFT = "above",
	ANCHOR_TOPRIGHT = "above", ANCHOR_BOTTOM = "below", ANCHOR_BOTTOMLEFT = "below", ANCHOR_BOTTOMRIGHT = "below",
}
local TIP_ORDER = { "right", "left", "above", "below" }

local function uiNum(v)
	v = W.Plain and W.Plain(v) or v
	return type(v) == "number" and v or nil
end

-- frame's box in UIParent units ({ l, r, t, b }), and the screen's width and height
local function tipBox(f)
	local ui = UIParent
	if not ui then return nil end
	local l, r = uiNum(Try(f, "GetLeft")), uiNum(Try(f, "GetRight"))
	local t, b = uiNum(Try(f, "GetTop")), uiNum(Try(f, "GetBottom"))
	local fe, ue = uiNum(Try(f, "GetEffectiveScale")), uiNum(Try(ui, "GetEffectiveScale"))
	local sw, sh = uiNum(Try(ui, "GetWidth")), uiNum(Try(ui, "GetHeight"))
	if not (l and r and t and b and fe and ue and sw and sh) or ue <= 0 then return nil end
	local k = fe / ue
	return { l = l * k, r = r * k, t = t * k, b = b * k }, sw, sh
end

local function within(v, lo, hi)
	if hi < lo then return lo end
	return math.max(lo, math.min(hi, v))
end

-- the card (w x h) on that side of the box o: its left and bottom, and whether it lies wholly on the screen there.
-- Beside the owner its top is level with the owner's; above or below it starts at the owner's left (ANCHOR_TOP and
-- ANCHOR_BOTTOM: centred; ANCHOR_TOPRIGHT: ends at its right). Along the owner's edge it is kept on the screen,
-- which never moves it onto the owner.
local function tipAt(side, o, w, h, sw, sh, anchor)
	local l, b
	if side == "right" or side == "left" then
		l = side == "right" and o.r + TIP.clear or o.l - TIP.clear - w
		b = within(o.t - h, 0, sh - h)
		return l, b, l >= 0 and l + w <= sw
	end
	b = side == "above" and o.t + TIP.clear or o.b - TIP.clear - h
	if anchor == "ANCHOR_TOP" or anchor == "ANCHOR_BOTTOM" then
		l = (o.l + o.r) / 2 - w / 2
	elseif anchor == "ANCHOR_TOPRIGHT" then
		l = o.r - w
	else
		l = o.l
	end
	return within(l, 0, sw - w), b, b >= 0 and b + h <= sh
end

local function placeTip(card)
	local w, h = card.w or 0, card.h or 0
	local o, sw, sh = tipBox(card.owner)
	card:ClearAllPoints()
	card.side = nil
	card.at = o -- where the owner was when the card was placed (tipTick follows it)
	if not o then
		card:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		return
	end
	local first = TIP_PREFER[card.anchor or ""] or TIP_ORDER[1]
	local l, b, fits = tipAt(first, o, w, h, sw, sh, card.anchor)
	local side = fits and first or nil
	for i = 1, #TIP_ORDER do
		if side then break end
		l, b, fits = tipAt(TIP_ORDER[i], o, w, h, sw, sh, card.anchor)
		if fits then side = TIP_ORDER[i] end
	end
	if not side then
		-- no side holds it whole: the side with the most room to spare, moved back onto the screen
		local spare = { right = sw - o.r - w, left = o.l - w, above = sh - o.t - h, below = o.b - h }
		side = first
		for i = 1, #TIP_ORDER do
			if spare[TIP_ORDER[i]] > spare[side] then side = TIP_ORDER[i] end
		end
		l, b = tipAt(side, o, w, h, sw, sh, card.anchor)
		l, b = within(l, 0, sw - w), within(b, 0, sh - h)
	end
	card.side = side
	card:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", math.floor(l + 0.5), math.floor(b + 0.5))
end

-- the widest line of the words, and their widest single word: by Inter's own measure, and for the two winners by
-- the game's answer too (a probe label of the same font, never shown), so a word the game draws wider is not cut
local function tipWidths(card, words, size, weight)
	local line, word, lineText, wordText = 0, 0, "", ""
	for part in (words .. "\n"):gmatch("(.-)\n") do
		local w = T.MeasureText(part, size, weight)
		if w > line then line, lineText = w, part end
		for one in part:gmatch("%S+") do
			w = T.MeasureText(one, size, weight)
			if w > word then word, wordText = w, one end
		end
	end
	local probe = card.probe[size]
	if probe then
		probe:SetText(wordText)
		-- half a unit a letter on top: the game puts every letter on a whole pixel, which a long word adds up
		word = math.max(word, uiNum(Try(probe, "GetStringWidth")) or 0) + 0.5 * #wordText
		if line <= TIP.wrap then
			probe:SetText(lineText)
			line = math.max(line, uiNum(Try(probe, "GetStringWidth")) or 0)
		end
		probe:SetText("")
	end
	return line, word
end

-- the card as large as its words need: every text TIP.wrap wide at most (one long word: as wide as the word)
local function sizeTip(card)
	local shown = card.shown
	local line, word = 0, 0
	for i = 1, #shown do
		local fs = shown[i]
		local l, wd = tipWidths(card, fs.words, fs.size, fs.weight)
		line, word = math.max(line, l), math.max(word, wd)
	end
	local textW = math.ceil(math.max(math.min(line, TIP.wrap), word)) + 1
	local gap = T.Spacing("sub")
	local y = TIP.pad
	for i = 1, #shown do
		local fs = shown[i]
		fs:SetWidth(textW)
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", card, "TOPLEFT", TIP.pad, -y)
		local h = math.max(uiNum(Try(fs, "GetStringHeight")) or 0, T.DrawnSize(fs.size))
		y = y + math.ceil(h) + (i < #shown and gap or 0)
	end
	card.w, card.h = textW + 2 * TIP.pad, y + TIP.pad
	card:SetSize(card.w, card.h)
end

local function hideCard(card)
	if type(T.GlideStop) == "function" then T.GlideStop(card) end
	local owner = card.owner
	card.owner = nil
	card:Hide()
	if type(owner) == "table" and owner.wuberTipShown then owner.wuberTipShown = nil end
end

-- every frame while it shows: gone when the owner it was shown for is no longer visible; measured again while
-- the font may still be loading; placed again when the owner has moved
local function tipTick(card, elapsed)
	local owner = card.owner
	if not owner or (card.ownerSeen and Try(owner, "IsVisible") == false) then
		hideCard(card)
		return
	end
	card.age = (card.age or 0) + (tonumber(elapsed) or 0)
	local w, h = card.w, card.h
	if card.age <= TIP.settle then sizeTip(card) end
	-- the owner moved or changed size under it (a page slid in, a list scrolled): beside it again
	local o, was = tipBox(owner), card.at
	local moved = o and (not was or math.abs(o.l - was.l) + math.abs(o.r - was.r) + math.abs(o.t - was.t) + math.abs(o.b - was.b) > 0.5)
	if moved or card.w ~= w or card.h ~= h then placeTip(card) end
end

local function tipText(card, size, weight)
	local fs = card:CreateFontString(nil, "OVERLAY")
	if size == "body" then T.SetFont(fs, "body", weight) else T.SetFont(fs, "sub", weight) end
	fs.size, fs.weight = size, weight
	fs:SetJustifyH("LEFT")
	Try(fs, "SetJustifyV", "TOP")
	Try(fs, "SetWordWrap", true)
	return fs
end

local tipCard
local function tipFrame()
	if tipCard then return tipCard end
	if not UIParent then return nil end
	local card = CreateFrame("Frame", "WuberTip", UIParent)
	card:Hide()
	card:SetSize(TIP.wrap, 40)
	card:SetFrameStrata("TOOLTIP")
	Try(card, "SetClampedToScreen", true)
	Try(card, "EnableMouse", false)
	-- (design 4, P1) a one-pixel edge in the line token round the fill: the same rounded picture one pixel larger, under it
	card.edge = T.Rounded(card, "line", T.CORNER.radius, "BACKGROUND", -1, 1)
	card.fill = T.Rounded(card, "raised", T.CORNER.radius)
	card.title = tipText(card, "body", "medium")
	card.lines, card.shown = {}, {}
	card.probe = { body = tipText(card, "body", "medium"), sub = tipText(card, "sub", "regular") }
	for _, probe in pairs(card.probe) do
		Try(probe, "SetWordWrap", false)
		probe:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
		probe:Hide()
	end
	card:SetScript("OnUpdate", function(self, elapsed) pcall(tipTick, self, elapsed) end)
	tipCard = card
	return card
end

local function tipFade(card, k) card:SetAlpha(k) end

function T.TipShow(owner, title, lines, anchor)
	if not owner or type(title) ~= "string" or title == "" then return nil end
	local card = tipFrame()
	if not card then return nil end
	local again = card:IsShown() and card.owner == owner
	if card.owner and card.owner ~= owner and card.owner.wuberTipShown then card.owner.wuberTipShown = nil end
	card.owner, card.anchor = owner, anchor
	card.ownerSeen = Try(owner, "IsVisible") == true -- gone later when the owner stops being visible (tipTick)
	local shown = {}
	card.title.words = title
	card.title:SetText(title)
	card.title:SetTextColor(T.RGB("white"))
	shown[1] = card.title
	if type(lines) == "string" then lines = { lines } end
	local n = 0
	for _, line in ipairs(type(lines) == "table" and lines or {}) do
		local words, colour = line, nil
		if type(line) == "table" then words, colour = line[1], line[2] end
		if type(words) == "string" and words ~= "" then
			n = n + 1
			local fs = card.lines[n]
			if not fs then
				fs = tipText(card, "sub", "regular")
				card.lines[n] = fs
			end
			fs.words = words
			fs:SetText(words)
			fs:SetTextColor(T.RGB(type(colour) == "string" and T.C[colour] and colour or "muted"))
			fs:Show()
			shown[#shown + 1] = fs
		end
	end
	for i = n + 1, #card.lines do card.lines[i]:Hide() end
	card.shown = shown
	sizeTip(card)
	placeTip(card)
	card.age = 0
	card:Show()
	if not again then
		if type(T.Glide) == "function" and not (type(T.ReduceMotion) == "function" and T.ReduceMotion()) then
			T.Glide(card, TIP.fade, tipFade)
		else
			if type(T.GlideStop) == "function" then T.GlideStop(card) end
			card:SetAlpha(1)
		end
	end
	return card
end

function T.TipHide(owner)
	local card = tipCard
	if card and (owner == nil or card.owner == owner) then hideCard(card) end
end

function T.TipOwner()
	local card = tipCard
	if card and card:IsShown() then return card.owner end
	return nil
end

-- (round 13) Once made the game's tooltip solid for the tips Wuber built on it. Every tip is the card now, which
-- is always solid, and the game's tooltip is left as the game draws it: this does nothing. The name stays.
function T.SolidTip() end

-- (design 4, quick win 7) frame.wuberWholes: the one-line labels (font strings) T.WholeOnHover registered on this frame.
-- The ones that are cut at this moment come FIRST in the card, whole (the first is the title, the others lines in
-- white), then the owner's own title (unless it is the same words) and its text. A frame with no T.Tip of its own
-- shows just the whole words, and nothing when none is cut.
local function showTip(frame)
	local tip = frame.wuberTip
	local title, text, anchor
	if tip then title, text, anchor = tipValue(tip.title, frame), tipValue(tip.text, frame), tip.anchor end
	if type(title) ~= "string" or title == "" then title = nil end
	local lines = {}
	if type(frame.wuberWholes) == "table" and type(T.CutOneLine) == "function" then
		local wholes = {}
		for _, fs in ipairs(frame.wuberWholes) do
			if Try(fs, "IsShown") ~= false and (tonumber(Try(fs, "GetAlpha")) or 1) > 0.01 and T.CutOneLine(fs) then
				wholes[#wholes + 1] = Try(fs, "GetText")
			end
		end
		if #wholes > 0 then
			for i = 2, #wholes do lines[#lines + 1] = { wholes[i], "white" } end
			if title and title ~= wholes[1] then lines[#lines + 1] = { title, "white" } end
			title = wholes[1]
		end
	end
	if not title then return end
	if type(text) == "string" and text ~= "" then lines[#lines + 1] = text end
	if T.TipShow(frame, title, lines, anchor) then frame.wuberTipShown = true end
end

local function hideTip(frame)
	if frame.wuberTipShown then
		frame.wuberTipShown = nil
		T.TipHide(frame)
	end
end

-- T.TipHook(frame): the tip's three hooks on frame, once, with no words of its own (T.Tip calls it; T.WholeOnHover
-- uses it so a frame with only whole labels shows the card too).
function T.TipHook(frame)
	if not frame or frame.wuberTipHooked or type(frame.HookScript) ~= "function" then return end
	frame.wuberTipHooked = true
	pcall(frame.HookScript, frame, "OnEnter", function(self) pcall(showTip, self) end)
	pcall(frame.HookScript, frame, "OnLeave", function(self) pcall(hideTip, self) end)
	pcall(frame.HookScript, frame, "OnHide", function(self) pcall(hideTip, self) end)
end

function T.Tip(frame, title, text, anchor)
	if not frame then return nil end
	frame.wuberTip = { title = title, text = text, anchor = anchor }
	T.TipHook(frame)
	return frame
end

-- The tip again, now (its words changed while the mouse is over it).
function T.RefreshTip(frame)
	if frame and frame.wuberTipShown then pcall(showTip, frame) end
end

---------------------------------------------------------------------------
-- Controls: Toggle, Slider, Segmented, Bar
---------------------------------------------------------------------------

-- Words or a glyph on a violet fill are ink, never white (white on violet is 2.8 to 1). onViolet(fill): is this fill
-- the theme's violet, drawn solid? litText(fill, text): the text colour to use on that fill.
local function onViolet(fill)
	if type(fill) == "string" then fill = T.C[fill] end
	local v = T.C.accent
	if type(fill) ~= "table" or (fill[4] or 1) < 0.9 then return false end
	return math.abs(fill[1] - v[1]) < 0.01 and math.abs(fill[2] - v[2]) < 0.01 and math.abs(fill[3] - v[3]) < 0.01
end
local function litText(fill, text)
	if onViolet(fill) then return "ink" end
	return text
end

-- T.Toggle(parent, on, onChange(on)): a 44 x 24 switch, violet when on, card2 when off. t:SetOn(on, quiet), t.on.
function T.Toggle(parent, on, onChange)
	local t = CreateFrame("Button", nil, parent)
	t:SetSize(44, 24)
	t.track = T.PillFill(t, "raised", 24, "ARTWORK", 0)
	t.knob = T.Circle(t, 18, "white", "OVERLAY")
	t.on = on and true or false
	t.pos = t.on and 1 or 0
	local function place(self, v)
		self.pos = v
		self.knob:ClearAllPoints()
		self.knob:SetPoint("CENTER", self, "LEFT", 12 + 20 * v, 0)
	end
	local function paint(self)
		-- pressed (T.Press): the violet a little darker, the off track a step lighter
		if self.wuberPressed then
			self.track:SetColor(self.on and shade("accent", -0.08) or shade("line", 0.06))
		else
			self.track:SetColor(self.on and "accent" or (self.hover and "line" or "raised"))
		end
		self.knob:SetVertexColor(T.RGB(self.on and "white" or "muted"))
	end
	function t.SetOn(self, v, animate)
		self.on = v and true or false
		paint(self)
		local target = self.on and 1 or 0
		-- Not animated: still end any slide that is running, or it carries the knob to the old side.
		if animate then T.Tween(self, self.pos, target, place) else T.Tween(self, target, target, place) end
	end
	t:RegisterForClicks("LeftButtonUp")
	t:SetScript("OnClick", function(self)
		local ok, err = pcall(function()
			self:SetOn(not self.on, true)
			if onChange then onChange(self.on, self) end
		end)
		if not ok then W.Error("toggle", err) end
	end)
	t:SetScript("OnEnter", function(self) self.hover = true pcall(paint, self) end)
	t:SetScript("OnLeave", function(self) self.hover = nil pcall(paint, self) end)
	T.Press(t, { paint = function(self) paint(self) end }) -- the click is the press's, on mouse down
	t:SetOn(t.on)
	if type(T.OnTheme) == "function" then T.OnTheme(t, paint) end
	return t
end

-- T.Slider(parent, width, opts): opts { min, max, step, value, onChange(v), format(v) -> text,
-- live (default true: a drag commits 0.3 s after it rests; false: only when let go),
-- labelW (the value's room on the right, default 60; a long value such as "every 15 min" gives it more) }.
-- A real Slider (the game drags its thumb), drawn as a track, a violet fill, a knob and the
-- value on the right. The mouse wheel steps it only once it was clicked, until the mouse leaves
-- (before that the wheel scrolls the page). s:Set(v) changes it without onChange.
function T.Slider(parent, width, opts)
	opts = opts or {}
	local lo, hi, step = opts.min or 0, opts.max or 1, opts.step or 0
	local labelW = tonumber(opts.labelW) or 60
	local trackW = width - labelW - 4
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(width, 24)
	local s = CreateFrame("Slider", nil, holder)
	s:SetSize(trackW, 24)
	s:SetPoint("LEFT", holder, "LEFT", 0, 0)
	Try(s, "SetOrientation", "HORIZONTAL")
	s:SetMinMaxValues(lo, hi)
	if step > 0 then
		Try(s, "SetValueStep", step)
		Try(s, "SetObeyStepOnDrag", true)
	end
	s.holder = holder
	s.track = CreateFrame("Frame", nil, s)
	s.track:SetSize(trackW, 6)
	s.track:SetPoint("LEFT", s, "LEFT", 0, 0)
	T.PillFill(s.track, "line", 6, "ARTWORK", 0)
	s.fill = CreateFrame("Frame", nil, s.track)
	s.fill:SetPoint("LEFT", s.track, "LEFT", 0, 0)
	s.fill:SetSize(6, 6)
	s.fillTex = T.PillFill(s.fill, "accent", 6, "ARTWORK", 1)
	-- S8 (round 9): the knob on a frame of its own above the track and its fill (child frames
	-- draw over their parent's textures, so the fill used to cut across a knob drawn on s)
	s.top = CreateFrame("Frame", nil, s)
	s.top:SetAllPoints(s)
	s.top:SetFrameLevel((tonumber(Try(s.fill, "GetFrameLevel")) or 0) + 1)
	s.halo = noGlow() -- (design 1) no halo round the knob
	s.knob = T.Circle(s.top, 18, "white", "OVERLAY")
	-- the game's own thumb (what you drag): the same white knob
	local thumb = s:CreateTexture(nil, "OVERLAY", nil, 1)
	thumb:SetTexture(T.MEDIA .. "circle")
	thumb:SetSize(18, 18)
	Try(s, "SetThumbTexture", thumb)
	s.thumb = thumb
	s.label = T.Text(holder, "sub", "white", "RIGHT", "bold")
	s.label:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
	s.label:SetWidth(labelW)
	local function snap(v)
		v = tonumber(v) or lo
		if step and step > 0 then v = lo + math.floor((v - lo) / step + 0.5) * step end
		if v < lo then v = lo elseif v > hi then v = hi end
		return v
	end
	local function paint(self, v)
		self.value = v
		local f = (hi > lo) and (v - lo) / (hi - lo) or 0
		local x = 9 + f * (trackW - 18)
		self.knob:ClearAllPoints()
		self.knob:SetPoint("CENTER", self.track, "LEFT", x, 0)
		self.halo:ClearAllPoints()
		self.halo:SetPoint("CENTER", self.knob, "CENTER")
		self.fill:SetWidth(math.max(6, x))
		self.label:SetText(opts.format and opts.format(v) or tostring(v))
	end
	local function commit(self)
		self.pending = nil
		if self.committed == self.value then return end
		self.committed = self.value
		if opts.onChange then
			local ok, err = pcall(opts.onChange, self.value, self)
			if not ok then W.Error("slider", err) end
		end
	end
	-- Set(v): show v without telling anyone
	function s.Set(self, v)
		v = snap(v)
		self.quiet = true
		pcall(self.SetValue, self, v)
		self.quiet = nil
		self.committed = v
		paint(self, v)
	end
	s:SetScript("OnValueChanged", function(self, v, userInput)
		local ok, err = pcall(function()
			v = snap(v)
			paint(self, v)
			if self.quiet then return end
			local token = {}
			self.pending = token
			if userInput and opts.live == false then return end -- on let go
			W.After(userInput and 0.3 or 0.05, function()
				if self.pending == token then commit(self) end
			end)
		end)
		if not ok then W.Error("slider", err) end
	end)
	-- the wheel steps a slider only after it was clicked (or dragged), until the mouse
	-- leaves it. Until then the slider takes no wheel, so the game sends the wheel to the page under
	-- it and the page scrolls: a wheel that passes over a slider never changes it.
	local function wheelOn(self, on)
		self.wheelOn = on and true or nil
		Try(self, "EnableMouseWheel", on and true or false)
	end
	wheelOn(s, false)
	s:SetScript("OnMouseWheel", function(self, delta)
		if not self.wheelOn then return end
		local d = (step and step > 0) and step or (hi - lo) / 20
		pcall(self.SetValue, self, snap((self.value or lo) + (tonumber(delta) or 0) * d))
	end)
	s:SetScript("OnMouseDown", function(self) wheelOn(self, true) end)
	s:SetScript("OnMouseUp", function(self)
		if self.pending then commit(self) end
	end)
	s:SetScript("OnEnter", function(self) self.halo:SetVertexColor(T.RGB("accent", 0.5)) end)
	s:SetScript("OnLeave", function(self) self.halo:SetVertexColor(T.RGB("accent", 0.25)) end)
	s:Set(opts.value or lo)
	Try(s, "HookScript", "OnLeave", function(self) wheelOn(self, false) end)
	return s
end

-- T.Segmented(parent, choices, value, onChange(value), width, height): a pill split into
-- choices ({ { value =, label =, tip = } }); the chosen one is violet with ink words. s:SetValue(v), s:Paint().
-- the chosen part is lit by its own opaque pill (b.chosen), shown or hidden; the parts'
-- own fills stay hidden. In the game a fill kept its alpha when the choice changed while it was not
-- drawn (a clear part stayed clear, a lit one turned solid white). Looks: s.onStyle (a T.PILL_STYLES
-- name; "chosen" by default, which is no pill style but the look below) and s.litFor(b) (a colour for the lit pill)
-- and s.onText (its words' colour); the other parts have muted words, white under the mouse. (design 1) Whatever
-- the caller asks, words on a violet lit pill are ink.
local SEG_CHOSEN = { bg = "accent", hover = "accent", press = "accent", text = "ink" }
local function segPaint(s)
	local st = STYLES[s.onStyle] or SEG_CHOSEN
	for _, b in ipairs(s.buttons) do
		local on = b.value == s.value
		b.fill:SetShown(false)
		b.chosen:SetShown(on)
		local lit
		if on then
			lit = s.litFor and s.litFor(b)
			if not lit then lit = b.pressed and st.press or (b.hover and st.hover or st.bg) end
			-- a violet look (the old "violet" pill style has its own hover and press shades): the one violet
			if st.bg == "accent" then lit = "accent" end
			b.chosen:SetColor(lit)
		end
		b.label:SetTextColor(T.RGB(on and litText(lit, s.onText or st.text) or (b.hover and "white" or "muted")))
	end
end

-- T.Segmented(parent, choices, value, onChange, width, height, opts): opts.byLabel = true sizes the segments by
-- their labels (each one's text plus its pill padding, the spare width shared evenly) instead of equal widths,
-- so a long label is not cut beside short ones; opts.pad overrides the horizontal padding per side (default ph/2).
function T.Segmented(parent, choices, value, onChange, width, height, opts)
	height = height or 30
	local s = CreateFrame("Frame", nil, parent)
	s:SetSize(width, height)
	s.bg = T.PillFill(s, "line", height, "BACKGROUND", 0)
	if type(T.OnTheme) == "function" then T.OnTheme(s, segPaint) end
	s.buttons = {}
	local n = #choices
	local bw = (width - 4) / math.max(1, n)
	local ph = height - 4 -- the pill's own label size (T.Pill) and its padding of half its height each side
	local sidePad = (type(opts) == "table" and tonumber(opts.pad)) or (ph / 2)
	local widths = {}
	if type(opts) == "table" and opts.byLabel then
		local need, sum = {}, 0
		for i, ch in ipairs(choices) do
			need[i] = (tonumber(T.MeasureText(ch.label, pillText(ph))) or 0) * 1.05 + sidePad * 2 + 2
			sum = sum + need[i]
		end
		local spare = (width - 4 - sum) / math.max(1, n)
		for i = 1, n do widths[i] = spare >= 0 and need[i] + spare or need[i] * (width - 4) / sum end
	end
	local x = 2
	for i, ch in ipairs(choices) do
		local bw_i = widths[i] or bw
		local b = T.Pill(s, ch.label, "ghost", bw_i, ph)
		if sidePad ~= ph / 2 then
			b.label:ClearAllPoints()
			b.label:SetPoint("LEFT", b, "LEFT", sidePad, 0)
			b.label:SetPoint("RIGHT", b, "RIGHT", -sidePad, 0)
			b.label.wuberRoom = bw_i - sidePad * 2
			b.label:SetText(ch.label or "")
		end
		b:SetPoint("LEFT", s, "LEFT", x, 0)
		x = x + bw_i
		b.value = ch.value
		b:HookScript("OnClick", function(self)
			if s.value == self.value then return end
			s:SetValue(self.value)
			if onChange then
				local ok, err = pcall(onChange, self.value, s)
				if not ok then W.Error("choice", err) end
			end
		end)
		if ch.tip then T.Tip(b, ch.label, ch.tip) end
		b.fill:SetShown(false)
		b.chosen = T.PillFill(b, "accent", height - 4, "BACKGROUND", 0)
		b.chosen:SetShown(false)
		for _, ev in ipairs({ "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp" }) do
			b:HookScript(ev, function() pcall(segPaint, s) end)
		end
		s.buttons[i] = b
	end
	s.onStyle = "chosen"
	function s.Paint(self) segPaint(self) end
	function s.SetValue(self, v)
		self.value = v
		for _, b in ipairs(self.buttons) do
			b:SetStyle(b.value == v and self.onStyle or "ghost")
		end
		segPaint(self)
	end
	s:SetValue(value)
	return s
end

-- T.Bar(parent, width, height, colour): a progress bar, violet unless a colour is given; b:SetValue(0..1, animate).
function T.Bar(parent, width, height, colour)
	height = height or 8
	local b = CreateFrame("Frame", nil, parent)
	b:SetSize(width, height)
	T.PillFill(b, "line", height, "BACKGROUND", 0)
	b.fill = CreateFrame("Frame", nil, b)
	b.fill:SetPoint("LEFT", b, "LEFT", 0, 0)
	b.fill:SetSize(height, height)
	b.fillTex = T.PillFill(b.fill, colour or "accent", height, "ARTWORK", 0)
	b.shine = noGlow() -- (design 1) a flat fill: no shine across the bar
	b.cur = 0
	local function apply(self, v)
		self.cur = v
		self.fill:SetWidth(math.max(height, width * v))
		if v <= 0 then self.fill:Hide() else self.fill:Show() end
	end
	function b.SetValue(self, v, animate)
		v = tonumber(v) or 0
		if v < 0 then v = 0 elseif v > 1 then v = 1 end
		if animate then T.Tween(self, self.cur, v, apply) else apply(self, v) end
	end
	function b.SetColor(self, c) self.fillTex:SetColor(c) end
	b:SetValue(0)
	return b
end

---------------------------------------------------------------------------
-- Glow and effects helpers (prominence)
---------------------------------------------------------------------------

-- (Design 1) No coloured glow: both helpers draw nothing. They still return an object with the methods
-- their callers use (g:SetColor(c, a), g:SetAlpha(a), g:SetShown(on)), which makes no texture.
function T.OuterGlow(frame, colour, alpha, reach)
	return noGlow()
end

function T.EdgeGlow(frame, colour, alpha)
	return noGlow()
end

-- (Design 1) The one glow that is still drawn: the driver's big button tells its state by the colour of its
-- outer glow, and that button keeps today's look until its own redesign. Nothing else may call this.
-- g:SetColor(c, a), g:SetAlpha(a), g:SetShown(on).
function T.StateGlow(frame, colour, alpha, reach)
	reach = reach or 14
	local g = T.NineSlice(frame, "shadow", 26, 31 / 64, "BACKGROUND", -7, reach)
	for _, t in pairs(g.parts) do Try(t, "SetBlendMode", "ADD") end
	g:SetColor(colour or "accent", alpha or 0.5)
	return g
end

-- The effects setting: "full", "light" or "off".
function T.FxLevel()
	if T.ReduceMotion and T.ReduceMotion() then return "off" end -- (#305) Reduce motion: no moving effects
	local v = W.db and W.db.fx
	if v == "off" or v == "light" then return v end
	return "full"
end

-- A frame from W.FX (fn = "Crown", "Badge" or "Flipbook"), else nil. Never raises.
function T.FxFrame(fn, ...)
	local fx = W.FX
	if type(fx) ~= "table" or type(fx[fn]) ~= "function" then return nil end
	local ok, f = pcall(fx[fn], ...)
	if not ok then
		W.Error("FX." .. fn, f)
		return nil
	end
	if type(f) == "table" and type(f.SetPoint) ~= "function" and type(f.frame) == "table" then f = f.frame end
	if type(f) ~= "table" or type(f.SetPoint) ~= "function" then return nil end
	return f
end

-- The creator's crown at size on parent: W.FX.Crown, else the plain crown glyph in gold.
-- Returns a frame (pos it with SetPoint).
function T.Crown(parent, size, seed)
	local f = T.FxFrame("Crown", parent, size, seed)
	if f then return f end
	f = CreateFrame("Frame", nil, parent)
	f:SetSize(size, size)
	f.icon = T.Icon(f, "crown", size, "gold", "ARTWORK")
	f.icon:SetPoint("CENTER", f, "CENTER")
	f.plain = true
	return f
end

-- The still, face-on icon of a badge id: Media\badge_<id> (64 x 64, full colour, one small file that
-- loads at once), or nil for an id that is not in W.BADGES. on a driver card the
-- spinning sheet could be caught edge-on or still loading and read as a plain white blob.
function T.BadgeTexture(id)
	if type(id) ~= "string" or id == "" then return nil end
	local list = type(W.BADGES) == "table" and W.BADGES or {}
	for _, b in ipairs(list) do
		if type(b) == "table" and b.id == id then return T.MEDIA .. (W.Str(b.texture) or ("badge_" .. id)) end -- Media/badge_<id>.tga (tests/fx/badge_test.lua checks every file)
	end
	return nil
end

-- A driver badge (W.BADGES id) at size on parent. still: the face-on icon (T.BadgeTexture) and no
-- effect sheet (driver cards); else W.FX.Badge (spins), else the same icon, else a plain star token.
function T.DriverBadge(parent, id, size, still)
	if type(id) ~= "string" or id == "" then return nil end
	local path = T.BadgeTexture(id)
	local f = not (still and path) and T.FxFrame("Badge", parent, id, size) or nil
	if f then return f end
	if path then
		f = CreateFrame("Frame", nil, parent)
		f:SetSize(size, size)
		f.icon = f:CreateTexture(nil, "ARTWORK")
		f.icon:SetAllPoints(f)
		f.icon:SetTexture(path)
		f.plain = true
		return f
	end
	f = CreateFrame("Frame", nil, parent)
	f:SetSize(size, size)
	f.disc = T.Circle(f, size, "panel", "ARTWORK")
	f.disc:SetPoint("CENTER", f, "CENTER")
	f.icon = T.Icon(f, "star", math.floor(size * 0.62), "glow", "OVERLAY")
	f.icon:SetPoint("CENTER", f, "CENTER")
	f.plain = true
	return f
end

---------------------------------------------------------------------------
-- Pioneers: Wuber's first riders and drivers, from the shipped lists only (W.PioneerKind).
-- Cosmetic: a small pin disc by the name and one tooltip line. The founder look wins: a founder
-- gets no Pioneer badge. With the shipped (empty) lists nothing is ever made.
---------------------------------------------------------------------------

T.PIONEER = {
	rider = { tip = "Pioneer: one of Wuber's first riders", word = "Pioneer", colour = "glow" },
	driver = { tip = "Pioneer Driver: one of Wuber's first drivers", word = "Pioneer Driver", colour = "teal" },
}

-- "rider", "driver" or nil for a name or key: the Pioneer look to show (a founder: nil).
function T.PioneerLook(nameOrKey)
	if nameOrKey == nil or type(W.PioneerKind) ~= "function" then return nil end
	local ok, kind = pcall(W.PioneerKind, nameOrKey)
	if not ok or (kind ~= "rider" and kind ~= "driver") then return nil end
	local okc, founder = pcall(W.IsCreator, nameOrKey)
	if okc and founder == true then return nil end
	return kind
end

-- A Pioneer badge (kind "rider" / "driver") at size: a dark disc, a ring and the Wuber pin in the
-- kind's colour, with its tooltip. mouse: takes the mouse (its own tooltip; off on rows and pins,
-- whose tooltip has the line). b:SetKind(kind) repaints it.
function T.PioneerBadge(parent, kind, size, mouse)
	size = size or 16
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(size, size)
	f.disc = T.Circle(f, size, "panel", "ARTWORK")
	f.disc:SetPoint("CENTER", f, "CENTER")
	f.ring = T.Tex(f, "ring", "ARTWORK", 1)
	f.ring:SetSize(size, size)
	f.ring:SetPoint("CENTER", f, "CENTER")
	f.icon = T.Icon(f, "pin", math.floor(size * 0.62), "white", "OVERLAY")
	f.icon:SetPoint("CENTER", f, "CENTER")
	function f.SetKind(self, k)
		local look = T.PIONEER[k] or T.PIONEER.rider
		self.kind = T.PIONEER[k] and k or "rider"
		self.ring:SetVertexColor(T.RGB(look.colour))
		self.icon:SetVertexColor(T.RGB(look.colour))
		self.tipText = look.tip
	end
	f:SetKind(kind)
	f:EnableMouse(mouse == true)
	T.Tip(f, function(self) return self.tipText end)
	return f
end

-- Shows the Pioneer badge owner[field] for kind (made on first use, repainted when the kind
-- changes), or hides it (kind nil). Returns the badge when shown. The caller places it.
function T.ShowPioneer(owner, field, kind, size, parent, mouse)
	local b = owner[field]
	if not T.PIONEER[kind or ""] then
		if b then b:Hide() end
		return nil
	end
	if not b then
		b = T.PioneerBadge(parent or owner, kind, size, mouse)
		owner[field] = b
	elseif b.kind ~= kind then
		b:SetKind(kind)
	end
	b:Show()
	return b
end

-- Rider levels: 1 Bronze, 2 Silver, 3 Gold.
T.TIER = {
	[0] = { name = "New rider", colour = "muted" },
	{ name = "Bronze", colour = hex("D08A55"), from = 3 },
	{ name = "Silver", colour = hex("C9CEDF"), from = 10 },
	{ name = "Gold", colour = "gold", from = 25 },
}
