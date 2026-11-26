-- Module: Theme.Forms
-- Purpose: driver-screen building blocks: T.Line, T.Field, T.EdgeFade, T.Scroll, T.Sheet, T.ListButton, T.Para,
--   T.Tag, T.AlertCard, and the list row (design 2): T.RowGroup, group:Row, T.RowHeading. T.EdgeFade is the one look for every clipped list (soft top/bottom edges and a thin
--   scroll bar shown while the list can scroll).
-- API: T.Line, T.Outline, Outline:SetColor, Outline:SetAlpha, Outline:SetShown, T.Field, T.EdgeFade, T.Scroll, T.Sheet, T.SheetCard, T.ListButton, T.ParaLines, T.Para, T.Tag, T.AlertCard,
--   T.CutOneLine, T.WholeOnHover, T.RowGroup, Group:Row, Group:Layout, Group:LayoutNow, T.RowHeading, T.ROW, Row:SetTitle, Row:SetSub, Row:SetValue, Row:SetShown, Row:Wash, Row:Unwash
--   T.WholeOnHover(fs, owner): hovering the owner (default: the nearest mouse-taking ancestor up to 3 up, else a hover-only frame over the label) shows the whole text of a one-line label that is cut at that moment, as the first words of the tip card, before the owner's own T.Tip words; T.Fit sets it on every label it finds cut.
-- Internals: wholeOwner, WHOLE_MAX_H, fadeTex, paintFade, measure, BAR, barTex, amounts, paintBar, ROW, rowRoom, rowLayout, rowTip, routed, dress, reduced, MOT, easeOut, easeIn, run, finish
-- Uses: (none)
-- Later: UI.Window (UI.HeadAbove, run time: a sheet with opts.head lifts the header's buttons over its dim while it is up)
-- Events: listens (none); fires (none)
-- Standalone: no
-- Test: tests/theme/forms_test.lua
-- From: Theme.lua 1616-2004 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("Theme.Forms", {})

local T = W.Theme
local Try = T.Try
local A = T.Animate

---------------------------------------------------------------------------
-- Round four (the driver's screens): fields, scroll areas, bottom sheets, thin lines
---------------------------------------------------------------------------

-- T.Line(parent, colour, alpha, layer): a 1 px texture (place it with SetPoint).
function T.Line(parent, colour, alpha, layer)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	local r, g, b, a = T.RGB(colour or "line", alpha)
	if not pcall(t.SetColorTexture, t, r, g, b, a) then
		t:SetTexture(T.MEDIA .. "circle")
		t:SetVertexColor(r, g, b, a)
	end
	return t
end

-- T.Outline(frame, colour, thick): a flat thin outline round a frame (four lines, no glow): the ring round the
-- thing a tip is about. o:SetColor(c, a), o:SetAlpha(a), o:SetShown(on).
local Outline = {}
Outline.__index = Outline
function Outline:SetColor(c, alpha)
	local r, g, b, a = T.RGB(c, alpha)
	for _, t in ipairs(self.parts) do
		if not pcall(t.SetColorTexture, t, r, g, b, a) then t:SetVertexColor(r, g, b, a) end
	end
	self.colour = c
end
function Outline:SetAlpha(a)
	for _, t in ipairs(self.parts) do t:SetAlpha(a) end
end
function Outline:SetShown(shown)
	for _, t in ipairs(self.parts) do
		if shown then t:Show() else t:Hide() end
	end
end
function T.Outline(frame, colour, thick)
	thick = thick or 2
	local o = setmetatable({ parts = {} }, Outline)
	for i = 1, 4 do o.parts[i] = T.Line(frame, colour or "accent", nil, "OVERLAY") end
	local top, bottom, left, right = o.parts[1], o.parts[2], o.parts[3], o.parts[4]
	top:SetPoint("TOPLEFT", frame, "TOPLEFT")
	top:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
	top:SetHeight(thick)
	bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
	bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
	bottom:SetHeight(thick)
	left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -thick)
	left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, thick)
	left:SetWidth(thick)
	right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -thick)
	right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, thick)
	right:SetWidth(thick)
	o.colour = colour or "accent"
	return o
end

-- T.Field(parent, w, h, opts): an edit box on a dark pill.
-- opts: { justify = "LEFT", max = 32, size = "body", placeholder = text, get = fn() -> text,
--         onCommit = fn(text) (Enter or focus lost, when the text changed; with get the field shows
--           get() again after, without get it keeps what was typed),
--         onChange = fn(text) (every key), onEnter = fn(text) (Enter pressed), onEscape = fn() (after Escape lets go of the keyboard),
--         multi = true (several lines, h is the box), colour = the well's colour }
-- f.edit, f.hint, f:Sync() (shows get() unless typing), f:Text(), f:SetText(t), f.focused.
-- A box with no get is the caller's own (notes, the Messages editor, price, searches):
-- losing focus, Escape and Sync never touch its text, only the placeholder; the caller reads f:Text().
function T.Field(parent, w, h, opts)
	opts = opts or {}
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w, h)
	-- an inset well: darker than any card it sits on, with a thin edge (violet while typing)
	local well = opts.colour or { 0.035, 0.035, 0.075, 1 }
	-- the edge on the field, the well on a child just inside it (so the edge shows round it)
	local inner = CreateFrame("Frame", nil, f)
	inner:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	inner:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
	if opts.multi then
		f.edge = T.Rounded(f, "line", 13, "BACKGROUND", 0)
		f.bg = T.Rounded(inner, well, 12, "BACKGROUND", 0)
	else
		f.edge = T.PillFill(f, "line", h, "BACKGROUND", 0)
		f.bg = T.PillFill(inner, well, h - 2, "BACKGROUND", 0)
	end
	f.inner, f.well = inner, well
	local inset = opts.multi and 10 or math.floor(h / 2)
	local eb = CreateFrame("EditBox", nil, inner)
	eb:SetPoint("TOPLEFT", f, "TOPLEFT", inset, opts.multi and -8 or 0)
	eb:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, opts.multi and 8 or 0)
	eb:SetAutoFocus(false)
	Try(eb, "SetMultiLine", opts.multi and true or false)
	T.OwnFont(eb)
	T.SetFont(eb, opts.size or "body", "medium")
	eb:SetTextColor(T.RGB("white"))
	Try(eb, "SetJustifyH", opts.justify or "LEFT")
	if opts.multi then Try(eb, "SetJustifyV", "TOP") end
	Try(eb, "SetMaxLetters", opts.max or 32)
	f.edit = eb
	f.hint = T.Text(inner, opts.size or "body", "off", opts.justify or "LEFT", "regular")
	f.hint:SetPoint("TOPLEFT", eb, "TOPLEFT", 0, 0)
	f.hint:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT", 0, 0)
	if opts.multi then Try(f.hint, "SetJustifyV", "TOP") end
	f.hint:SetText(opts.placeholder or "")
	local function current()
		if opts.get then
			local ok, t = pcall(opts.get)
			if ok and t ~= nil then return tostring(t) end
		end
		return ""
	end
	function f.Text(self) return Try(eb, "GetText") or "" end
	function f.SetText(self, t)
		eb:SetText(t or "")
		if t and t ~= "" then self.hint:Hide() elseif not self.focused then self.hint:Show() end
	end
	function f.Sync(self)
		if self.focused then return end
		local t
		if opts.get then
			t = current()
			eb:SetText(t)
		else
			t = self:Text() -- nothing to show instead: keep what is in the box
		end
		if t == "" and (opts.placeholder or "") ~= "" then self.hint:Show() else self.hint:Hide() end
	end
	local function done(keep)
		if not f.focused then return end
		f.focused = nil
		if keep and opts.onCommit then
			local text = f:Text()
			-- with get: changed from the saved value; without: changed since focus was gained
			local was = opts.get and current() or (f.before or "")
			if text ~= was then
				local ok, err = pcall(opts.onCommit, text)
				if not ok then W.Error("field", err) end
			end
		end
		f:Sync()
	end
	eb:SetScript("OnEditFocusGained", function(self)
		f.focused = true
		f.before = f:Text()
		f.hint:Hide()
		f.edge:SetColor("accent")
		if not opts.multi then pcall(self.HighlightText, self) end
	end)
	eb:SetScript("OnEditFocusLost", function()
		f.edge:SetColor("line")
		local ok, err = pcall(done, true)
		if not ok then W.Error("field", err) end
	end)
	eb:SetScript("OnEnterPressed", function(self)
		if opts.multi and not opts.enterCommits then return end
		-- onEnter first: losing focus re-syncs a box with get to the saved value, so the
		-- typed text has to be used before ClearFocus
		if opts.onEnter then
			local ok, err = pcall(opts.onEnter, f:Text())
			if not ok then W.Error("field", err) end
		end
		pcall(self.ClearFocus, self)
	end)
	eb:SetScript("OnEscapePressed", function(self)
		f.focused = nil
		pcall(self.ClearFocus, self)
		f:Sync()
		if opts.onEscape then
			local ok, err = pcall(opts.onEscape)
			if not ok then W.Error("field", err) end
		end
	end)
	eb:SetScript("OnTextChanged", function(self, user)
		if not user then return end
		if opts.onChange then
			local ok, err = pcall(opts.onChange, f:Text())
			if not ok then W.Error("field", err) end
		end
	end)
	-- a click anywhere on the pill types in it
	f:EnableMouse(true)
	f:SetScript("OnMouseDown", function() pcall(eb.SetFocus, eb) end)
	-- the pill round the box shows the box's own tooltip
	local function fromEdit(key)
		return function()
			local t = eb.wuberTip
			local v = t and t[key]
			if type(v) == "function" then
				local ok, r = pcall(v, eb)
				return ok and r or nil
			end
			return v
		end
	end
	T.Tip(f, fromEdit("title"), fromEdit("text"))
	f:Sync()
	return f
end

-- T.EdgeFade(view, opts) (S6, round 9): the one shared look for every list that clips. view
-- clips its children (EdgeFade turns that on) and gets a soft fade at its bottom edge while there
-- is more below, and at its top edge once scrolled. opts: colour = what is behind the list (a
-- palette name or { r, g, b }; default "black", the window), size = the fade's height (24),
-- content = the frame that holds the rows (default view.content), source = fn() -> offset, max
-- (instead of measuring content against view), lift = how many frame levels above view the fades
-- sit (default 40; a list that other screens open over takes less, so its fades stay under them),
-- bar = false (no scroll bar; by default a thin one shows on the right while the list can scroll).
-- Fades sit above the rows, never take the mouse and never scale. Returns fd (also view.edgeFade): fd:Update() (it also runs itself 5 times a second
-- while shown), fd.top, fd.bottom (the two textures), fd:Shown("top" or "bottom"), fd:SetColour(c),
-- fd.track, fd.thumb (the scroll bar's textures), fd:BarShown(), fd:Bar() (places the thumb).
local function fadeTex(holder, top)
	local t = holder:CreateTexture(nil, "OVERLAY", nil, 7)
	Try(t, "SetColorTexture", 1, 1, 1, 1)
	t:SetPoint(top and "TOPLEFT" or "BOTTOMLEFT", holder, top and "TOPLEFT" or "BOTTOMLEFT", 0, 0)
	t:SetPoint(top and "TOPRIGHT" or "BOTTOMRIGHT", holder, top and "TOPRIGHT" or "BOTTOMRIGHT", 0, 0)
	t:Hide()
	return t
end

-- paints a fade: solid colour at the edge, clear towards the rows (SetGradient with CreateColor, or
-- SetGradientAlpha on older clients, or a flat half-alpha band where neither exists)
local function paintFade(t, top, colour)
	local r, g, b = T.RGB(colour)
	local lo, hi = top and 0 or 1, top and 1 or 0 -- VERTICAL: min is the bottom, max the top
	local ok = false
	if type(CreateColor) == "function" and t.SetGradient then
		Try(t, "SetVertexColor", 1, 1, 1, 1)
		ok = pcall(t.SetGradient, t, "VERTICAL", CreateColor(r, g, b, lo), CreateColor(r, g, b, hi))
	end
	if not ok and t.SetGradientAlpha then ok = pcall(t.SetGradientAlpha, t, "VERTICAL", r, g, b, lo, r, g, b, hi) end
	if not ok then Try(t, "SetVertexColor", r, g, b, 0.55) end
end

-- how far content is scrolled past view's top, and how far it reaches past view's bottom
local function measure(view, content)
	if not content then return 0, 0 end
	local vt, vb = tonumber(Try(view, "GetTop")), tonumber(Try(view, "GetBottom"))
	local ct, cb = tonumber(Try(content, "GetTop")), tonumber(Try(content, "GetBottom"))
	if not (vt and vb and ct and cb) then return 0, 0 end
	return ct - vt, vb - cb
end

-- the thin scroll bar every clipped list gets with its fades: a faint track on the right
-- edge and a thumb as long as the part in view, placed by how far the list is scrolled. Shown only
-- while the list can scroll; it never takes the mouse (the wheel scrolls) and only moves, never fades.
local BAR = { w = 3, inset = 4, right = 3, minThumb = 18 }
local function barTex(holder, colour, alpha)
	local t = T.Line(holder, colour, alpha, "OVERLAY")
	Try(t, "SetDrawLayer", "OVERLAY", 7)
	t:SetWidth(BAR.w)
	t:Hide()
	return t
end

-- how far the list is scrolled (above), how much more is below, and the view's height
local function amounts(fd)
	local above, below
	if fd.source then
		local off, max = fd.source()
		off, max = tonumber(off) or 0, tonumber(max) or 0
		above, below = off, max - off
	else
		above, below = measure(fd.view, fd.content or fd.view.content)
	end
	return math.max(0, above), math.max(0, below), tonumber(Try(fd.view, "GetHeight")) or 0
end

local function paintBar(fd, above, below, h)
	if not fd.thumb then return end
	local range = above + below
	local track = h - BAR.inset * 2
	local show = range > 1 and track > BAR.minThumb
	if fd.barShown ~= show then
		fd.barShown = show
		fd.track:SetShown(show)
		fd.thumb:SetShown(show)
	end
	if not show then fd.barAt = nil return end
	local th = math.max(BAR.minThumb, math.floor(track * h / (h + range) + 0.5))
	local y = math.floor(BAR.inset + (track - th) * math.min(1, above / range) + 0.5)
	local at = th * 10000 + y
	if at == fd.barAt then return end
	fd.barAt = at
	fd.thumb:SetHeight(th)
	fd.thumb:ClearAllPoints()
	fd.thumb:SetPoint("TOPRIGHT", fd.holder, "TOPRIGHT", -BAR.right, -y)
end

function T.EdgeFade(view, opts)
	opts = opts or {}
	Try(view, "SetClipsChildren", true)
	local holder = CreateFrame("Frame", nil, view)
	holder:SetAllPoints(view)
	local fd = { view = view, holder = holder, colour = opts.colour or "black", size = opts.size or 24,
		content = opts.content, source = opts.source, lift = tonumber(opts.lift) or 40, wait = 0 }
	fd.top, fd.bottom = fadeTex(holder, true), fadeTex(holder, false)
	if opts.bar ~= false then
		fd.track = barTex(holder, "white", 0.08)
		fd.track:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -BAR.right, -BAR.inset)
		fd.track:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -BAR.right, BAR.inset)
		fd.thumb = barTex(holder, "muted", 0.7)
	end
	function fd.SetColour(self, c)
		self.colour = c or "black"
		paintFade(self.top, true, self.colour)
		paintFade(self.bottom, false, self.colour)
	end
	function fd.Bar(self)
		paintBar(self, amounts(self))
	end
	function fd.BarShown(self)
		return self.thumb and self.thumb:IsShown() and true or false
	end
	function fd.Shown(self, edge)
		local t = edge == "top" and self.top or self.bottom
		return t:IsShown() and true or false
	end
	-- the bar between two 0.2 s updates (it follows a smooth scroll every frame): it asks only the list's own
	-- offset (the source), and paints only when the offset or the range moved; the view's height is the one the
	-- last update read. A list with no source (T.Scroll) paints its bar itself each time it moves (place).
	function fd.Follow(self)
		if not (self.source and self.viewH) then return end
		local off, max = self.source()
		off, max = tonumber(off) or 0, tonumber(max) or 0
		if off == self.fOff and max == self.fMax then return end
		self.fOff, self.fMax = off, max
		paintBar(self, math.max(0, off), math.max(0, max - off), self.viewH)
	end
	function fd.Update(self)
		local lvl = tonumber(Try(view, "GetFrameLevel")) or 1
		if (tonumber(Try(holder, "GetFrameLevel")) or 0) ~= lvl + self.lift then Try(holder, "SetFrameLevel", lvl + self.lift) end
		local above, below, h = amounts(self)
		self.viewH = h
		if self.source then self.fOff, self.fMax = above, above + below end
		paintBar(self, above, below, h)
		local size = math.max(4, math.min(self.size, math.floor(h / 4)))
		self.top:SetHeight(size)
		self.bottom:SetHeight(size)
		self.top:SetShown(above > 1)
		self.bottom:SetShown(below > 1)
	end
	fd:SetColour(fd.colour)
	holder:SetScript("OnUpdate", function(_, elapsed)
		fd.wait = fd.wait - (tonumber(elapsed) or 0)
		if fd.wait > 0 then
			-- the bar follows the smooth scroll every frame (the fades 5 times a second)
			if fd.thumb then pcall(fd.Follow, fd) end
			return
		end
		fd.wait = 0.2
		pcall(fd.Update, fd)
	end)
	view.edgeFade = fd
	return fd
end

-- T.Scroll(parent, opts): a clipped area that scrolls its content with the mouse wheel (smoothly),
-- with T.EdgeFade's soft edges (opts: EdgeFade's colour, size and lift).
-- s.content (put things on it), s:SetContentHeight(h), s:ScrollTo(y, instant), s.offset, s.edgeFade.
function T.Scroll(parent, opts)
	local s = CreateFrame("Frame", nil, parent)
	Try(s, "SetClipsChildren", true)
	s:EnableMouseWheel(true)
	local c = CreateFrame("Frame", nil, s)
	c:SetPoint("TOPLEFT", s, "TOPLEFT", 0, 0)
	c:SetPoint("RIGHT", s, "RIGHT", 0, 0)
	c:SetHeight(10)
	s.content = c
	s.offset, s.target, s.max = 0, 0, 0
	local fd = T.EdgeFade(s, { colour = opts and opts.colour, size = opts and opts.size, lift = opts and opts.lift, content = c })
	local function place(y)
		s.offset = y
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", s, "TOPLEFT", 0, y)
		c:SetPoint("RIGHT", s, "RIGHT", 0, 0)
		pcall(fd.Update, fd)
	end
	function s.SetContentHeight(self, h)
		h = math.max(1, tonumber(h) or 1)
		c:SetHeight(h)
		local view = tonumber(Try(self, "GetHeight")) or h
		self.max = math.max(0, h - view)
		if self.target > self.max then self:ScrollTo(self.max, true) end
		pcall(fd.Update, fd)
	end
	function s.ScrollTo(self, y, instant)
		y = math.max(0, math.min(self.max or 0, tonumber(y) or 0))
		self.target = y
		if instant then place(y) end
	end
	s:SetScript("OnMouseWheel", function(self, delta)
		self:ScrollTo(self.target - (tonumber(delta) or 0) * 60)
	end)
	s:SetScript("OnUpdate", function(self, elapsed)
		if self.offset == self.target then return end
		local k = math.min(1, (tonumber(elapsed) or 0) * 14)
		local y = self.offset + (self.target - self.offset) * k
		if math.abs(y - self.target) < 0.5 then y = self.target end
		local ok = pcall(place, y)
		if not ok then self.offset = self.target end
	end)
	return s
end

-- (Design 2) One look for the sheet and the card that stands alone: flat in the sheet colour ("panel"), no outline,
-- no grab handle, corner 14, a title (17 bold) at the left and the x at the right, a body, and at the foot ONE main
-- button (sheet:MainButton, 46 high, 16 from each side, 12 above the bottom) with an optional link under it.
-- dress: put the title, x, body and the two foot buttons on a card frame; close() is what the x does.
local function dress(card, close)
	-- the words sit on their own frame over the card, so the fill (a frame of its own) never covers them
	local top = CreateFrame("Frame", nil, card)
	top:SetAllPoints(card)
	card.top = top
	card.title = T.Text(top, "heading", "white", "LEFT", "bold")
	card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -18)
	card.title:SetPoint("RIGHT", card, "RIGHT", -56, 0)
	card.sub = T.Text(top, "caption", "muted", "LEFT", "regular")
	card.sub:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -3)
	card.sub:SetPoint("RIGHT", card, "RIGHT", -16, 0)
	card.close = T.RoundButton(top, "close", 28, "card")
	card.close:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -12)
	card.close:SetScript("OnClick", function() pcall(close) end)
	T.Tip(card.close, "Close", "Close this without changing anything else.")
	card.body = CreateFrame("Frame", nil, card)
	card.topPad = 56
	local function lay()
		local foot = 0
		if card.mainBtn then foot = 70 end
		if card.linkBtn then foot = foot + 30 end
		if card.mainBtn then
			card.mainBtn:ClearAllPoints()
			card.mainBtn:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 16, 12 + (card.linkBtn and 30 or 0))
			card.mainBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -16, 12 + (card.linkBtn and 30 or 0))
		end
		if card.linkBtn then
			card.linkBtn:ClearAllPoints()
			card.linkBtn:SetPoint("BOTTOM", card, "BOTTOM", 0, 10)
		end
		card.body:ClearAllPoints()
		card.body:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -card.topPad)
		card.body:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 0, foot)
	end
	card.layFoot = lay
	function card.SetTitle(self, t, sub)
		self.title:SetText(t or "")
		self.sub:SetText(sub or "")
		self.topPad = (sub and sub ~= "") and 66 or 56
		lay()
	end
	-- the one gold main button at the foot; the body ends above it
	function card.MainButton(self, label, onClick, tip)
		if not self.mainBtn then
			self.mainBtn = T.MainButton(self, label) -- the same button as a screen's main button (bold words); lay() places it
			self.mainBtn:SetHeight(46)
		end
		local b = self.mainBtn
		b:SetLabel(label)
		b:SetScript("OnClick", onClick)
		T.Tip(b, label, tip or label)
		lay()
		return b
	end
	-- a link (no fill, violet words) under the main button
	function card.Link(self, label, onClick, tip)
		if not self.linkBtn then
			self.linkBtn = T.Pill(self, label, "ghost", 160, 26)
		end
		local b = self.linkBtn
		b:SetLabel(label)
		b:SetScript("OnClick", onClick)
		T.Tip(b, label, tip or label)
		lay()
		return b
	end
	card.body:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -56)
	card.body:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 0, 0)
end

local function reduced() return T.ReduceMotion and T.ReduceMotion() and true or false end
-- the motion tokens (Theme/Anim.lua: T.MOTION), read when a sheet moves
local function MOT() return T.MOTION or { sheetUp = 0.32, sheetDown = 0.24, fade = 0.16, reduced = 0.12 } end
local function easeOut(u) return 1 - (1 - u) * (1 - u) * (1 - u) end
local function easeIn(u) return u * u * u end

-- run frame's own OnUpdate for dur seconds: step(u) with u 0..1 (eased by the caller), then done()
local function run(f, dur, step, done)
	f.run = { t = 0, dur = dur, step = step, done = done }
	f:SetScript("OnUpdate", function(self, e)
		local r = self.run
		if not r then return end
		r.t = r.t + (tonumber(e) or 0)
		local u = math.min(1, r.t / r.dur)
		step(u)
		if u >= 1 then
			self.run = nil
			self:SetScript("OnUpdate", nil)
			if r.done then r.done() end
		end
	end)
end
-- jump a running move to its end
local function finish(f)
	local r = f.run
	if not r then return end
	f.run = nil
	f:SetScript("OnUpdate", nil)
	r.step(1)
	if r.done then r.done() end
end

-- T.Sheet(host, height, title, opts): a bottom sheet over host (a dim behind that closes it when clicked and a
-- card the full width of host, top corners 14, that rises by its own height in 0.32 s and drops in 0.24 s).
-- sheet.body (put rows on it, under the title), sheet:Open(), sheet:Close(instant), sheet:SetTitle(t, sub),
-- sheet:SetSheetHeight(h), sheet.onClose, sheet:MainButton(label, onClick[, tip]), sheet:Link(label, onClick[, tip]).
-- opts.head = n: the dim reaches over the top n of host too, but only below them does it take the mouse (a click
-- there closes the sheet), and (r49, E1-07) the window's header buttons (fold, cog, x) are lifted over the dim while the
-- sheet is up (UI.HeadAbove), so they are drawn whole and stay usable; sheet:HeadDown() puts them back (a caller that
-- replaces the sheet's OnHide script calls it there).
-- opts.secure = true: the sheet holds a secure frame, so in combat it opens and closes at once. It moves by SetPoint
-- inside its own clipping frame (no Translation); Reduce motion: a 0.12 s fade in place.
local sheetCount = 0
local escHeld = {} -- sheet name -> { { index, window name } } swapped in UISpecialFrames (put back when it closes)
-- swapped IN PLACE (no insert or remove): Escape walks the list while a sheet hides, so the list must keep its length
local function escTake(sh)
	local name = sh.GetName and sh:GetName()
	local list = _G.UISpecialFrames
	if not name or type(list) ~= "table" or escHeld[name] then return end
	local taken = {}
	for i = 1, #list do
		local n = list[i]
		local f = type(n) == "string" and _G[n] or nil
		local up = f and Try(sh, "GetParent")
		while up and up ~= f do up = Try(up, "GetParent") end
		if f and up == f then taken[#taken + 1] = { i, n } list[i] = name end
	end
	if #taken > 0 then escHeld[name] = taken end
end
local function escGive(sh)
	local name = sh.GetName and sh:GetName()
	local list = _G.UISpecialFrames
	local taken = name and escHeld[name]
	if not taken or type(list) ~= "table" then return end
	escHeld[name] = nil
	for _, t in ipairs(taken) do
		-- only our own sheet name is ever replaced; another addon may have shifted the slot, so look for it
		local at = list[t[1]] == name and t[1] or nil
		if not at then for i = 1, #list do if list[i] == name then at = i break end end end
		if at then list[at] = t[2] end
	end
end
function T.Sheet(host, height, title, opts)
	local secure = type(opts) == "table" and opts.secure
	local head = type(opts) == "table" and tonumber(opts.head) or nil
	sheetCount = sheetCount + 1
	-- (job 2767; #303: with opts.head too) a sheet inside a window is named so Escape can close it ALONE: while it is open it takes
	-- its window's place in UISpecialFrames (see escTake), so the first Escape closes the sheet and the next the window
	local sh = CreateFrame("Frame", "WuberSheet" .. sheetCount, host)
	sh:SetAllPoints(host)
	sh:SetFrameLevel((tonumber(Try(host, "GetFrameLevel")) or 1) + 50)
	Try(sh, "SetClipsChildren", true)
	sh:EnableMouse(true)
	-- the dim is a FRAME, and its frame alpha is what changes: in the game a texture's own SetAlpha is ignored while an
	-- Alpha animation runs over it (a page fading in as the sheet opens), so a texture dim could stay clear or stay dark
	sh.dim = CreateFrame("Frame", nil, sh)
	sh.dim:SetAllPoints(sh)
	sh.dim:SetFrameLevel(sh:GetFrameLevel())
	sh.dim.fill = T.Line(sh.dim, "black", 1, "BACKGROUND") -- shown at 50% (put)
	sh.dim.fill:SetAllPoints(sh.dim)
	sh:SetScript("OnMouseDown", function(self) pcall(self.Close, self) end)
	sh.wuberNoTip = true -- a click blocker (the dim): no tooltip on empty space
	if head then
		-- the dim's top strip takes no mouse (the header's buttons are under it); the rest still blocks and closes
		sh:EnableMouse(false)
		sh.catch = CreateFrame("Frame", nil, sh)
		sh.catch:SetPoint("TOPLEFT", sh, "TOPLEFT", 0, -head)
		sh.catch:SetPoint("BOTTOMRIGHT", sh, "BOTTOMRIGHT", 0, 0)
		sh.catch:SetFrameLevel(sh:GetFrameLevel())
		sh.catch:EnableMouse(true)
		sh.catch.wuberNoTip = true
		sh.catch:SetScript("OnMouseDown", function() pcall(sh.Close, sh) end)
	end
	local card = CreateFrame("Frame", nil, sh)
	card:SetPoint("BOTTOMLEFT", sh, "BOTTOMLEFT", 0, 0)
	card:SetPoint("BOTTOMRIGHT", sh, "BOTTOMRIGHT", 0, 0)
	card:SetHeight(height or 300)
	card:EnableMouse(true)
	card.wuberNoTip = true
	-- the fill reaches 14 below the card so only the top corners show (the clip of sh cuts it)
	local fill = CreateFrame("Frame", nil, card)
	fill:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
	fill:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 0, -T.CORNER.radius)
	card.fill = fill
	card.bg = T.Rounded(fill, "panel", 14, "BACKGROUND", 0)
	sh.card = card
	dress(card, function() sh:Close() end)
	sh.title, sh.sub, sh.close, sh.body = card.title, card.sub, card.close, card.body
	sh.sheetH = height or 300
	-- the header's buttons stand over the dim while the sheet is up (opts.head): lifted at Open, put back when it is hidden
	local function lift(on)
		if not head then return end
		local U = W.UI
		if type(U) == "table" and type(U.HeadAbove) == "function" then pcall(U.HeadAbove, on, sh) end
	end
	sh:HookScript("OnHide", function(self)
		lift(false)
		escGive(self)
		-- hidden by Escape (not by Close): it was open, so say it closed
		if self.open and not self:IsShown() then
			self.open = false
			if self.run then finish(self) end
			if self.onClose then pcall(self.onClose, self) end
		end
	end)
	-- (a caller that sets its own OnHide script, which replaces the hook, calls this from it)
	function sh.HeadDown() lift(false) escGive(sh) end
	local function put(p, fadeOnly)
		local y = fadeOnly and 0 or -(1 - p) * sh.sheetH
		card:SetPoint("BOTTOMLEFT", sh, "BOTTOMLEFT", 0, y)
		card:SetPoint("BOTTOMRIGHT", sh, "BOTTOMRIGHT", 0, y)
		sh.dim:SetAlpha(0.5 * p)
		sh:SetAlpha(fadeOnly and p or 1)
	end
	function sh.SetTitle(self, t, sub) card:SetTitle(t, sub) end
	function sh.MainButton(self, ...) return card:MainButton(...) end
	function sh.Link(self, ...) return card:Link(...) end
	function sh.SetSheetHeight(self, h) self.sheetH = h card:SetHeight(h) end
	local function instant() return secure and InCombatLockdown and InCombatLockdown() end
	function sh.Open(self)
		finish(self)
		self.open = true
		self:Show()
		lift(true)
		escTake(self)
		if instant() then put(1) return end
		local fade = reduced()
		put(0, fade)
		run(self, fade and MOT().reduced or MOT().sheetUp, function(u) put(fade and u or easeOut(u), fade) end)
	end
	function sh.Close(self, instant_)
		if self.run then finish(self) end
		if not self.open then return end
		self.open = false
		escGive(self) -- Escape during the drop goes to the window, not to the sheet that is leaving
		if instant_ or instant() then
			self:Hide()
			lift(false)
		else
			local fade = reduced()
			run(self, fade and MOT().reduced or MOT().sheetDown, function(u) put(1 - (fade and u or easeIn(u)), fade) end, function() self:Hide() lift(false) end)
		end
		if self.onClose then pcall(self.onClose, self) end
	end
	sh:SetTitle(title)
	sh:Hide()
	return sh
end

-- T.SheetCard(parent, width, height, title): the sheet's look for a card that stands alone outside the phone
-- (all four corners 14, no dim): .body, :SetTitle, :MainButton, :Link, .title, .sub, .close. :Open() rises 12 with a
-- fade (0.16 s), :Close() fades out and hides; the caller places the returned frame.
function T.SheetCard(parent, width, height, title)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width or 300, height or 200)
	local card = CreateFrame("Frame", nil, f)
	card:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	card:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	card:EnableMouse(true)
	card.wuberNoTip = true
	card.bg = T.Rounded(card, "panel", 14, "BACKGROUND", 0)
	f.card = card
	dress(card, function() f:Close() end)
	f.title, f.sub, f.close, f.body = card.title, card.sub, card.close, card.body
	function f.SetTitle(self, t, sub) card:SetTitle(t, sub) end
	function f.MainButton(self, ...) return card:MainButton(...) end
	function f.Link(self, ...) return card:Link(...) end
	local function put(p, still)
		local y = still and 0 or -12 * (1 - p)
		card:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y)
		card:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, y)
		f:SetAlpha(p)
	end
	function f.Open(self)
		finish(self)
		self.open = true
		self:Show()
		local still = reduced()
		put(0, still)
		run(self, still and MOT().reduced or MOT().fade, function(u) put(u, still) end)
	end
	function f.Close(self, instant_)
		finish(self)
		if not self.open then return end
		self.open = false
		if instant_ then self:Hide() return end
		local still = reduced()
		run(self, still and MOT().reduced or MOT().fade, function(u) put(1 - u, still) end, function() self:Hide() f:SetAlpha(1) end)
		if self.onClose then pcall(self.onClose, self) end
	end
	f:SetTitle(title)
	f:Hide()
	return f
end

-- T.ListButton(parent, w, h, label, sub, glyph, colour): a big labelled row (menus, sheets).
function T.ListButton(parent, w, h, label, sub, glyph, colour)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	b:RegisterForClicks("LeftButtonUp")
	b.bg = T.Rounded(b, "card", 12, "BACKGROUND", 0)
	local x = 14
	if glyph then
		b.disc = T.Circle(b, 30, "panel", "ARTWORK")
		b.disc:SetPoint("LEFT", b, "LEFT", 10, 0)
		b.icon = T.Icon(b, glyph, 15, colour or "glow", "OVERLAY")
		b.icon:SetPoint("CENTER", b.disc, "CENTER")
		x = 50
	end
	b.label = T.Text(b, "body", colour == "red" and "red" or "white", "LEFT", "bold")
	b.sub = T.Text(b, "caption", "muted", "LEFT", "regular")
	if sub and sub ~= "" then
		b.label:SetPoint("TOPLEFT", b, "TOPLEFT", x, -(h / 2 - 15))
		b.sub:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -2)
	else
		b.label:SetPoint("LEFT", b, "LEFT", x, 0)
	end
	b.label:SetPoint("RIGHT", b, "RIGHT", -14, 0)
	b.sub:SetPoint("RIGHT", b, "RIGHT", -14, 0)
	b.label:SetText(label or "")
	b.sub:SetText(sub or "")
	b:SetScript("OnEnter", function(self) self.bg:SetColor("hover") end)
	b:SetScript("OnLeave", function(self) self.bg:SetColor("card") end)
	T.Press(b, { fill = b.bg })
	return b
end

-- T.Para(parent, size, colour, width, weight): size is a T.SIZE name; a wrapping paragraph whose height follows its text
-- (fs:SetPara(text) measures the lines, so nothing is cut off and nothing floats in a gap).
local function paraLines(text, px, weight, room)
	local total = 0
	for line in (tostring(text or "") .. "\n"):gmatch("([^\n]*)\n") do
		local n, cur = 1, ""
		for word in line:gmatch("%S+") do
			local try = cur == "" and word or (cur .. " " .. word)
			-- (#265 #269 #270) 7% over the font table (was 4): the game draws small text about 6% wider than the font table (2.4.3 run 3);
			-- a spare line costs a little height, a cut line loses words
			if cur ~= "" and T.MeasureText(try, px, weight) * 1.07 > room then n, cur = n + 1, word else cur = try end
		end
		total = total + n
	end
	return math.max(1, total)
end
T.ParaLines = paraLines

function T.Para(parent, px, colour, width, weight)
	local fs = T.Text(parent, px, colour or "muted", "LEFT", weight or "regular")
	fs:SetWidth(width)
	Try(fs, "SetWordWrap", true)
	Try(fs, "SetNonSpaceWrap", false)
	Try(fs, "SetJustifyV", "TOP")
	fs.paraW = width
	function fs.SetPara(self, text)
		local lines = paraLines(text, px, weight or "regular", self.paraW)
		Try(self, "SetMaxLines", lines + 1)
		-- one line: as it always was; each further line adds the label's own step (its drawn size and line spacing)
		local step = T.DrawnSize(px) + (tonumber(Try(self, "GetSpacing")) or T.Spacing(px))
		local hgt = math.ceil((T.SIZE[px] or tonumber(px) or T.SIZE.body) * 1.32 + 1) + 2 + (lines - 1) * step
		self:SetHeight(hgt)
		self:SetText(text)
		self.paraLines, self.paraH = lines, hgt
		return hgt
	end
	return fs
end

---------------------------------------------------------------------------
-- Design round 2: the list row. Every list of Wuber is rows inside ONE card (T.RowGroup).
---------------------------------------------------------------------------

-- T.RowGroup(parent, width[, opts]) -> group: one card (the card colour, corner 14) that holds rows.
--   opts: { colour = the card's colour ("card") }. group.rows (in the order made), group.width, group.bg.
-- group:Row(opts) -> row. opts:
--   title, sub      the words: the title white, the second line grey. Both WRAP: they are never cut, never "...".
--   icon            a glyph name (Media), drawn violet in a round violet-soft disc (row.disc, row.icon); or
--   avatar          a frame the caller made (it is parented to the row and placed where the disc would be).
--   right           "chevron" (row.chevron, grey) | "switch" (row.switch, T.Toggle as it is; opts.on its start,
--                   opts.onChange(on, switch)) | "value" (row.value, grey; opts.chevron = true adds a chevron
--                   after it) | "price" (row.value, gold, bold) | "button" (row.button, ONE small second-kind
--                   button with opts.value as its words; opts.buttonW its width, else fitted) | nil.
--   value           the words of a value, price or button.
--   below           a frame the caller made (a slider, a set of segments, a field): it goes under the words,
--                   from the title's left to the row's right pad, and the row grows by its height.
--   onClick(row)    the row is pressed like every control (T.Press: the pressed fill and the one click
--                   sound on mouse down) and lights under the mouse. With right = "button" the button gets it.
--   tip             { title, body } (title defaults to the row's title): on the row and on its control.
-- (row.title:SetText, row.sub:SetText and row.value:SetText are SetTitle, SetSub and SetValue.)
-- row.title, row.sub, row.switch / row.value / row.button / row.chevron, row.textX (where the title starts),
-- row:SetTitle(t), row:SetSub(t), row:SetValue(t), row:SetShown(on) (they lay the group out again),
-- row:Wash() (a soft violet wash over the row that fades away: a search match), row:Unwash() (off at once), row.divider.
-- group:Layout() -> the card's height. A row is 44 high with one line, 56 with two, taller when its words wrap
-- or it has something below. Between shown rows a one-pixel divider in "line" that starts where the title
-- starts; none after the last shown row. A hidden row takes no room. group.onLayout(group, h) is called after.
-- T.RowHeading(parent, text[, group]) -> a quiet sentence-case heading (grey, sub size); with group it sits
-- 8 above the card, in line with the card's first words. heading.gap = 8.
local ROW = { one = 44, two = 56, pad = 12, disc = 32, gap = 12, textPad = 7, between = 2, title = "body", sub = "caption",
	wash = 0.18, washHold = 0.6, washFade = 0.9, button = 30, headGap = 8, belowUp = 6, clear = { 0.129, 0.118, 0.231, 0 } }
T.ROW = ROW

local Row = {}
local Group = {}

local function rowRoom(row)
	local right = row.rightW > 0 and (row.rightW + ROW.gap) or 0
	return math.max(40, row.group.width - row.textX - right - ROW.pad)
end

-- T.PlaceOnce(frame, point, rel, relPoint, x, y): the same as frame:ClearAllPoints() then frame:SetPoint(...), but a
-- frame that already stands exactly there (one point, the same anchor and offsets) is left alone: a redraw that
-- changes nothing then makes no layout work in the game.
function T.PlaceOnce(frame, point, rel, relPoint, x, y)
	x, y = x or 0, y or 0
	if tonumber(Try(frame, "GetNumPoints")) == 1 then
		local ok, p, r, rp, px, py = pcall(frame.GetPoint, frame, 1)
		px, py = tonumber(px), tonumber(py)
		if ok and p == point and r == rel and (rp or p) == (relPoint or point) and px and py
			and math.abs(px - x) < 0.001 and math.abs(py - y) < 0.001 then
			return false
		end
	end
	frame:ClearAllPoints()
	frame:SetPoint(point, rel, relPoint or point, x, y)
	return true
end

-- one row's height, its words placed for it. Unchanged words, room and sizes give the same height, so the answer
-- from last time stands (nothing is measured, set or placed again).
local function anchored(f) return f == nil or (tonumber(Try(f, "GetNumPoints")) or 0) > 0 end
local function rowLayout(row)
	local belowH = row.below and (tonumber(Try(row.below, "GetHeight")) or 0) or -1
	local sig = table.concat({ row.titleText, row.subText, rowRoom(row), row.textX, belowH, tostring(row.below), row.lead and 1 or 0,
		row.rightFrame and 1 or 0, T.DrawnSize(ROW.title), T.DrawnSize(ROW.sub), T.Spacing(ROW.title), T.Spacing(ROW.sub),
		T.textEpoch or 0 }, "\1") -- (a text refresh, e.g. the font arriving, lays every row out again: its words are set again)
	-- (review) and only while every part it places still stands where it put it: other code (a card's chips) may have cleared one
	if row.laySig == sig and row.layH and math.abs((tonumber(Try(row, "GetHeight")) or -1) - row.layH) < 0.001
		and anchored(row.title) and (row.subText == "" or anchored(row.sub)) and anchored(row.below) and anchored(row.lead)
		and anchored(row.rightFrame) then
		return row.layH
	end
	row.laySig = nil
	row.laying = true
	local room = rowRoom(row)
	local hasSub = row.subText ~= ""
	row.title.paraW = room
	row.title:SetWidth(room)
	local th = row.title:SetPara(row.titleText)
	-- one line sits at the middle of its box (a wrapped one starts at the top)
	Try(row.title, "SetJustifyV", row.title.paraLines == 1 and "MIDDLE" or "TOP")
	local sh = 0
	if hasSub then
		row.sub.paraW = room
		row.sub:SetWidth(room)
		sh = row.sub:SetPara(row.subText) + ROW.between
		row.sub:Show()
	else
		row.sub:Hide()
	end
	local words = th + sh
	local top = math.max(hasSub and ROW.two or ROW.one, words + ROW.textPad * 2)
	local y = math.floor((top - words) / 2)
	T.PlaceOnce(row.title, "TOPLEFT", row, "TOPLEFT", row.textX, -y)
	if hasSub then T.PlaceOnce(row.sub, "TOPLEFT", row.title, "BOTTOMLEFT", 0, -ROW.between) end
	local h = top
	if row.below then
		local bh = tonumber(Try(row.below, "GetHeight")) or 0
		T.PlaceOnce(row.below, "TOPLEFT", row, "TOPLEFT", row.textX, -(top - ROW.belowUp))
		h = top - ROW.belowUp + bh + ROW.pad
	end
	-- the disc and the control at the right sit at the middle of the words' part
	if row.lead then
		T.PlaceOnce(row.lead, "CENTER", row, "TOPLEFT", ROW.pad + ROW.disc / 2, -top / 2)
	end
	if row.rightFrame then
		T.PlaceOnce(row.rightFrame, "RIGHT", row, "TOPRIGHT", -ROW.pad, -top / 2)
	end
	row.wordsH = top
	row:SetHeight(h)
	row.laying = nil
	row.laySig, row.layH = sig, h
	return h
end

function Row:SetTitle(t)
	t = tostring(t or "")
	if t == self.titleText then return end
	self.titleText = t
	self.group:Layout()
end
function Row:SetSub(t)
	t = tostring(t or "")
	if t == self.subText then return end
	self.subText = t
	self.group:Layout()
end
-- the words of the value, price or button at the right; the row's words get the room that is left
function Row:SetValue(t)
	t = tostring(t or "")
	if t == self.valueText then return end
	self.valueText = t
	if self.button then
		if self.button.label then self.button.label:SetText(t) end
	elseif self.value then
		self.valueRaw(self.value, t)
		local w = math.ceil(T.MeasureText(t, ROW.title, self.kind == "price" and "bold" or "medium")) + 2
		self.value:SetWidth(w)
		self.rightW = w + (self.chevron and 18 or 0)
		self.rightFrame:SetWidth(math.max(1, self.rightW))
	end
	self.group:Layout()
end
function Row:SetShown(on)
	on = on and true or false
	if on then self:Show() else self:Hide() end
	if self.off == not on then return end
	self.off = not on
	self.group:Layout()
end
-- a search match: a soft violet wash that holds a moment and fades away (never a solid violet card)
function Row:Wash()
	local wash = self.wash
	if not wash then
		wash = CreateFrame("Frame", nil, self)
		wash:SetAllPoints(self)
		wash.fill = T.Rounded(wash, { T.C.accent[1], T.C.accent[2], T.C.accent[3], ROW.wash }, T.CORNER.radius, "BACKGROUND", 2)
		wash:SetScript("OnUpdate", function(w, elapsed)
			w.left = (w.left or 0) - (tonumber(elapsed) or 0)
			if w.left <= 0 then
				w.fill:SetShown(false)
				w:Hide()
				return
			end
			w.fill:SetAlpha(math.min(1, w.left / ROW.washFade))
		end)
		self.wash = wash
	end
	wash.left = ROW.washHold + ROW.washFade
	wash.fill:SetShown(true)
	wash.fill:SetAlpha(1)
	wash:Show()
end
-- the wash off at once (the search was cleared)
function Row:Unwash()
	if self.wash then
		self.wash.fill:SetShown(false)
		self.wash:Hide()
	end
end

-- row.title:SetText, row.sub:SetText and row.value:SetText are SetTitle, SetSub and SetValue: a caller that
-- holds the label and sets its words still gets a row that fits them
local function routed(row, fs, setter)
	local raw = fs.SetText
	fs.SetText = function(self, t)
		if row.laying then return raw(self, t) end
		return setter(row, t)
	end
	return raw
end

local function rowTip(frame, row, tip)
	T.Tip(frame, function() return (type(tip) == "table" and tip.title) or row.titleText end,
		type(tip) == "table" and tip.body or nil)
end

function Group:Row(opts)
	opts = opts or {}
	local group = self
	local row = CreateFrame(opts.onClick and opts.right ~= "button" and "Button" or "Frame", nil, group)
	for k, v in pairs(Row) do row[k] = v end
	row.group, row.kind, row.opts = group, opts.right, opts
	row.titleText, row.subText, row.valueText = tostring(opts.title or ""), tostring(opts.sub or ""), tostring(opts.value or "")
	row:SetWidth(group.width)
	row.textX = ROW.pad + 4
	if opts.icon then
		row.lead = CreateFrame("Frame", nil, row)
		row.lead:SetSize(ROW.disc, ROW.disc)
		row.disc = T.Circle(row.lead, ROW.disc, { T.C.accent[1], T.C.accent[2], T.C.accent[3], 0.18 }, "ARTWORK")
		row.disc:SetPoint("CENTER", row.lead, "CENTER")
		row.icon = T.Icon(row.lead, opts.icon, 16, "accent", "OVERLAY")
		row.icon:SetPoint("CENTER", row.lead, "CENTER")
		row.textX = ROW.pad + ROW.disc + ROW.gap
	elseif opts.avatar then
		row.lead = opts.avatar
		Try(row.lead, "SetParent", row)
		row.avatar = opts.avatar
		row.textX = ROW.pad + ROW.disc + ROW.gap
	end
	row.title = T.Para(row, ROW.title, "white", 100, "bold")
	row.sub = T.Para(row, ROW.sub, "muted", 100, "regular")
	routed(row, row.title, Row.SetTitle)
	routed(row, row.sub, Row.SetSub)
	-- the control at the right
	row.rightW = 0
	local kind = opts.right
	if kind == "switch" then
		row.switch = T.Toggle(row, opts.on, function(on, t)
			if opts.onChange then opts.onChange(on, t) end
		end)
		row.switch.row = row
		row.rightFrame, row.rightW = row.switch, 44
	elseif kind == "button" then
		local words = row.valueText
		local bw = tonumber(opts.buttonW) or math.max(56, math.ceil(T.MeasureText(words, "body", "bold")) + 28)
		row.button = T.Pill(row, words, "dark", bw, ROW.button)
		row.button.row = row
		if opts.onClick then
			row.button:SetScript("OnClick", function(b)
				if b.inactive then return end
				local ok, err = pcall(opts.onClick, row, b)
				if not ok then W.Error("row", err) end
			end)
		end
		row.rightFrame, row.rightW = row.button, bw
	elseif kind == "chevron" or kind == "value" or kind == "price" then
		local holder = CreateFrame("Frame", nil, row)
		holder:SetSize(12, 20)
		local chev = kind == "chevron" or (kind == "value" and opts.chevron)
		if chev then
			row.chevron = T.Icon(holder, "chevron", 12, "offText", "OVERLAY")
			row.chevron:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
		end
		if kind ~= "chevron" then
			row.value = T.Text(holder, ROW.title, kind == "price" and "gold" or "muted", "RIGHT", kind == "price" and "bold" or "medium")
			row.value:SetPoint("RIGHT", holder, "RIGHT", chev and -18 or 0, 0)
			local w = math.ceil(T.MeasureText(row.valueText, ROW.title, kind == "price" and "bold" or "medium")) + 2
			row.value:SetWidth(w)
			row.value:SetText(row.valueText)
			row.valueRaw = routed(row, row.value, Row.SetValue)
			row.rightW = w + (chev and 18 or 0)
		else
			row.rightW = 12
		end
		holder:SetWidth(math.max(1, row.rightW))
		row.rightFrame = holder
	end
	if opts.below then
		row.below = opts.below
		Try(row.below, "SetParent", row)
	end
	-- the line under the row: from where the title starts to the card's edge
	row.divider = T.Line(row, "line", nil, "ARTWORK")
	row.divider:SetHeight(1)
	row.divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", row.textX, 0)
	row.divider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	Try(row, "EnableMouse", true)
	if opts.onClick and kind ~= "button" then
		row:RegisterForClicks("LeftButtonUp")
		row.fill = T.Rounded(row, ROW.clear, T.CORNER.radius, "BACKGROUND", 1)
		row:SetScript("OnEnter", function(r) r.fill:SetColor("hover") end)
		row:SetScript("OnLeave", function(r) r.fill:SetColor(ROW.clear) end)
		row:SetScript("OnClick", function(r)
			local ok, err = pcall(opts.onClick, r)
			if not ok then W.Error("row", err) end
		end)
		T.Press(row, { fill = row.fill, pressed = "line", hover = "hover", rest = ROW.clear })
	end
	if opts.tip ~= false then
		rowTip(row, row, opts.tip)
		if row.switch then rowTip(row.switch, row, opts.tip) end
		if row.button then rowTip(row.button, row, opts.tip) end
	end
	group.rows[#group.rows + 1] = row
	return row
end

function Group:Layout()
	-- (speed, job 2749) during a text refresh the card is laid out once, at its end (T.HoldLayout, Theme.Tokens)
	if T.HoldLayout and T.HoldLayout(self) then return self.height or 0 end
	return self:LayoutNow()
end

-- (#317) the card laid out now, even inside a text refresh: for a page that needs the card's real height to place what is under it
function Group:LayoutNow()
	local y, last = 0, nil
	for _, row in ipairs(self.rows) do
		if not row.off then
			local h = rowLayout(row)
			T.PlaceOnce(row, "TOPLEFT", self, "TOPLEFT", 0, -y)
			row.divider:Show()
			y = y + h
			last = row
		end
	end
	if last then last.divider:Hide() end
	self.height = y
	self:SetHeight(math.max(1, y))
	if type(self.onLayout) == "function" then pcall(self.onLayout, self, y) end
	return y
end

function T.RowGroup(parent, width, opts)
	opts = opts or {}
	local group = CreateFrame("Frame", nil, parent)
	group:SetSize(width, 1)
	for k, v in pairs(Group) do group[k] = v end
	group.width, group.rows, group.height = width, {}, 0
	group.bg = T.Rounded(group, opts.colour or "card", T.CORNER.radius, "BACKGROUND", 0)
	return group
end

function T.RowHeading(parent, text, group)
	local h = T.Text(parent, ROW.sub, "muted", "LEFT", "regular")
	h.gap = ROW.headGap
	h:SetText(text or "")
	if group then h:SetPoint("BOTTOMLEFT", group, "TOPLEFT", ROW.pad + 4, ROW.headGap) end
	return h
end

---------------------------------------------------------------------------
-- Round seven (the author's picked mockups): solid tags and the safety card
---------------------------------------------------------------------------

-- Words or a glyph on a violet fill are ink, never white (white on violet is 2.8 to 1). onViolet(fill): is this fill
-- the theme's violet, drawn solid? litText(fill, text): the text colour to use on that fill. (The same two as in
-- Theme.Widgets: Forms has no dependency on it.)
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

-- T.Tag(parent, text, opts): a solid pill sized to its words, with an optional icon or dot
-- (the map's zone pill, the destination chips, "TIME SAVED", the stat pills).
-- opts: fill (colour, "card"), text (colour, "white"), size (a T.SIZE name, "sub"), weight ("medium"),
--   h (28), icon (a Media name), iconColour, iconSize, dot (a colour), pad (14), min (width)
-- tag:SetTag(text, fill, textColour) changes the words (and colours) and refits the width.
-- tag:SetChosen(on): the chosen one of a set (a filter chip): violet with ink words; at rest card with muted words.
-- (design 1) Words and the icon on a violet fill are always ink, whatever colour the caller asks for.
function T.Tag(parent, text, opts)
	opts = opts or {}
	local h = opts.h or 28
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(60, h)
	local fill0 = opts.fill or "card"
	f.fill = T.PillFill(f, fill0, h, "BACKGROUND", 1)
	local pad = opts.pad or 14
	local lead = pad
	if opts.icon then
		local is = opts.iconSize or math.floor(h * 0.5)
		f.icon = T.Icon(f, opts.icon, is, litText(fill0, opts.iconColour or opts.text or "white"), "ARTWORK")
		f.icon:SetPoint("LEFT", f, "LEFT", pad - 2, 0)
		lead = pad - 2 + is + 6
	elseif opts.dot then
		f.dot = T.Circle(f, 7, opts.dot, "ARTWORK")
		f.dot:SetPoint("LEFT", f, "LEFT", pad - 2, 0)
		lead = pad - 2 + 7 + 6
	end
	f.label = T.Text(f, opts.size or "sub", litText(fill0, opts.text or "white"), "LEFT", opts.weight or "medium")
	f.label:SetPoint("LEFT", f, "LEFT", lead, 0)
	f.lead, f.pad, f.minW = lead, pad, opts.min or 0
	f.fillColour, f.textColour, f.iconColour = fill0, opts.text or "white", opts.iconColour or opts.text or "white"
	function f.SetTag(self, t, fill, tc)
		t = t or ""
		if fill then self.fillColour = fill self.fill:SetColor(fill) end
		if tc then self.textColour = tc end
		if fill or tc then
			self.label:SetTextColor(T.RGB(litText(self.fillColour, self.textColour)))
			if self.icon then self.icon:SetVertexColor(T.RGB(litText(self.fillColour, self.iconColour))) end
		end
		if self.label.wuberText ~= t then self.label:SetText(t) end -- (the same words are not set again)
		local tw = T.TextWidth(self.label, t)
		if not tw or tw <= 0 then tw = #t * 6 end
		self:SetWidth(math.max(self.minW, math.floor(self.lead + tw + self.pad + 0.5)))
	end
	function f.SetChosen(self, on)
		self:SetTag(self.label:GetText(), on and "accent" or "card", on and "ink" or "muted")
	end
	f:SetTag(text)
	return f
end

-- T.AlertCard(parent, w, h): the safety card (a wrong summoner zone, a stranger's trade, PvP on the way): a dark
-- fill, a 2 px red edge, a warning sign, a bold red line and a white one. Red is the one warning colour.
-- card:SetAlert(head, body) fills it; card:SetCompact(true) is the 50 high form (no ring, smaller words).
function T.AlertCard(parent, w, h)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w, h)
	f.edge = T.Rounded(f, "red", 18, "BACKGROUND", -6, 2)
	f.bg = T.Rounded(f, "hover", 16, "BACKGROUND", -4)
	f.ring = T.Tex(f, "ring", "ARTWORK")
	f.ring:SetSize(34, 34)
	f.ring:SetPoint("LEFT", f, "LEFT", 16, 0)
	f.ring:SetVertexColor(T.RGB("red"))
	f.mark = T.Text(f, "heading", "red", "CENTER", "bold")
	f.mark:SetPoint("CENTER", f.ring, "CENTER", 0, 1)
	f.mark:SetText("!")
	f.head = T.Text(f, "body", "red", "LEFT", "bold")
	f.head:SetPoint("TOPLEFT", f, "TOPLEFT", 62, -14)
	f.head:SetWidth(w - 76)
	f.body = T.Text(f, "caption", "white", "LEFT", "regular")
	f.body:SetPoint("TOPLEFT", f.head, "BOTTOMLEFT", 0, -4)
	f.body:SetWidth(w - 76)
	Try(f.body, "SetWordWrap", true)
	Try(f.body, "SetMaxLines", 2)
	function f.SetAlert(self, head, body)
		self.head:SetText(head or "")
		self.body:SetText(body or "")
	end
	-- (r19, F3) the same words and colours in less room: no warning ring, a smaller head and
	-- body, 50 high (folded Confirm, when the sheet is full). SetCompact(false) puts it back.
	function f.SetCompact(self, on)
		on = on and true or false
		if self.compact == on then return end
		self.compact = on
		self:SetHeight(on and 50 or h)
		for _, k in ipairs({ "ring", "mark" }) do
			if on then self[k]:Hide() else self[k]:Show() end
		end
		self.head:ClearAllPoints()
		self.head:SetPoint("TOPLEFT", self, "TOPLEFT", on and 16 or 62, on and -6 or -14)
		self.head:SetWidth(on and (w - 32) or (w - 76))
		T.SetFont(self.head, on and "sub" or "body", "bold")
		self.body:ClearAllPoints()
		self.body:SetPoint("TOPLEFT", self.head, "BOTTOMLEFT", 0, on and -2 or -4)
		self.body:SetWidth(on and (w - 32) or (w - 76))
		T.SetFont(self.body, "caption", "regular")
	end
	return f
end

---------------------------------------------------------------------------
-- Design round 4 (quick win 7): a one-line label that is cut shows its whole text on hover
---------------------------------------------------------------------------

-- T.CutOneLine(fs): is this label a one-line T.Text label that is cut right now? The game's own answer
-- (IsTruncated) when it gives one, the measured width otherwise. A label allowed more lines is never "cut" here.
function T.CutOneLine(fs)
	if type(fs) ~= "table" or type(fs.GetText) ~= "function" then return false end
	if fs.wuberWrapOn or fs.wuberWrapped or (tonumber(fs.wuberLines) or 0) >= 2 or (tonumber(fs.wuberMaxLines) or 0) >= 2 then return false end
	local text = Try(fs, "GetText")
	if type(text) ~= "string" or text == "" then return false end
	local game = Try(fs, "IsTruncated")
	if type(game) == "boolean" then return game end
	local room = tonumber(Try(fs, "GetWidth")) or 0
	return room > 0 and T.TextWidth(fs) > room + 1
end

-- T.WholeOnHover(fs, owner): hovering owner shows fs's whole text when fs is a one-line label that is cut at that
-- moment (nothing extra when it fits), on the tip card: the registered labels go in owner.wuberWholes, which T.Tip's own
-- hover reads (Theme.Widgets showTip): the whole words come first, the owner's own tip words after them. owner: a frame;
-- default the nearest ancestor of the label (the parent, at most 3 up) that takes the mouse and is no bigger than a row
-- (WHOLE_MAX_H: never the whole window), so the hover rides on a control that is already hovered and its highlight is
-- never stolen; only when there is none, a thin frame over the label that takes hovers only (never clicks: it is made
-- only where the client can say so). Secure (protected) frames are left alone. Safe to call again.
local WHOLE_MAX_H = 90

local function wholeOwner(fs, parent)
	local up = parent
	for _ = 1, 3 do
		if not up then break end
		if Try(up, "IsMouseEnabled") == true and (tonumber(Try(up, "GetHeight")) or 0) <= WHOLE_MAX_H then return up end
		up = Try(up, "GetParent")
	end
	if type(parent.SetMouseClickEnabled) == "function" or type(parent.SetPropagateMouseClicks) == "function" then
		local owner = CreateFrame("Frame", nil, parent)
		owner:SetAllPoints(fs)
		Try(owner, "EnableMouse", true)
		Try(owner, "SetMouseClickEnabled", false)
		Try(owner, "SetPropagateMouseClicks", true)
		owner.wuberWholeMouse = true
		return owner
	end
end

function T.WholeOnHover(fs, owner)
	if type(fs) ~= "table" or fs.wuberWhole or type(fs.GetParent) ~= "function" then return fs end
	local parent = Try(fs, "GetParent")
	if not owner then
		if not parent then return fs end
		owner = wholeOwner(fs, parent)
		if not owner then return fs end
	end
	if Try(owner, "IsProtected") == true or Try(parent, "IsProtected") == true or type(owner.HookScript) ~= "function" then return fs end
	fs.wuberWhole = owner
	if not owner.wuberWholes then owner.wuberWholes = {} end
	T.TipHook(owner)
	owner.wuberWholes[#owner.wuberWholes + 1] = fs
	return fs
end
