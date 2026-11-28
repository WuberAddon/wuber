-- Module: Theme.Tokens
-- Purpose: media paths, fonts, sizes, palette (T.C, T.Hex, T.RGB), T.Try, text and fonts (T.SetFont, T.Text,
--   T.Fit, T.MeasureText), textures, nine-slices, pill fills, T.Card.
-- API: W.Theme, T.MEDIA, T.FONTS, T.FONT, T.SIZE, T.WEIGHT, T.SCALE, T.Snap, T.READABLE, T.DrawnSize, T.Hex, T.C, T.C.open, T.C.green, T.RGB, T.RAMP, T.RampRGB, T.Code, T.THEMES, T.THEME_ORDER, T.DEFAULT_THEME, T.ThemeId, T.ThemeInfo, T.ApplyTheme, T.SetTheme, T.OnTheme, T.RegisterBackdrop,
--   T.Try, T.allText, T.RefreshTextUnder, T.RefreshOne, T.RefreshText, T.RefreshShown, T.layoutHold, T.HoldLayout,
--   T.LayoutsHeld (speed: the refreshes lay each list card out once), T.textEpoch, T.FONT_WAIT, T.WatchFont,
--   T.SetFont, T.LEADING, T.Spacing, T.WorldText, T.OwnFont, T.MeasureText, T.TextWidth,
--   T.Fit, T.Lines, T.Text, T.Tex, T.Icon, T.Circle, Slice:SetColor, Slice:SetShown, Slice:SetAlpha,
--   T.NineSlice, T.Rounded, Pill3:SetColor, Pill3:SetHeight, Pill3:SetShown, T.PillFill, T.Card, T.CORNER
-- Internals: hex, MISSING, method, drawn, Mod.FONT_W (the width table), Mod.ACCENT_W
-- Uses: (none)
-- Later: (none)
-- Events: listens login; fires FONT_READY
-- Standalone: no
-- Test: tests/theme/tokens_test.lua
-- From: Theme.lua 1-504 (Wuber 2.2.1)
--
-- Wuber: the look. Colours, fonts, the generated textures in Media/, and small builders
-- (cards, pill buttons, chips, icons) plus animation helpers, shared by UI.lua, Map.lua and
-- Driver.lua so every screen looks the same. Nothing here talks to the network.

local _, W = ...
local Mod = W.Module("Theme.Tokens", {})

local T = {}
W.Theme = T

T.MEDIA = "Interface\\AddOns\\Wuber\\Media\\"
-- Inter (SIL Open Font License, Media/fonts/OFL.txt): three Latin-only files with equal-width digits, made by
-- tools/fonts/make_inter.py from Inter's release. Arial Narrow if it can't be loaded.
T.FONTS = {
	regular = T.MEDIA .. "fonts\\Inter-Regular.ttf",
	medium = T.MEDIA .. "fonts\\Inter-Medium.ttf",
	bold = T.MEDIA .. "fonts\\Inter-Bold.ttf",
}
T.FONT = "Fonts\\ARIALN.TTF"
-- (design round 3) Seven text sizes and no others. A call site names one ("body"), never a number.
-- small and price are older names for sub and title, kept for callers.
T.SIZE = { hero = 40, display = 28, title = 22, heading = 17, body = 14, sub = 12, caption = 11, small = 12, price = 22 }
-- the weight each size gets unless asked otherwise
T.WEIGHT = {
	hero = "bold", display = "bold", title = "bold", heading = "bold", price = "bold",
	body = "medium", caption = "medium", sub = "regular", small = "regular",
}
-- The scale, smallest first. A number that still reaches the theme (a computed size, a label T.Fit shrinks,
-- an older caller) is drawn and measured at the scale size T.Snap gives it: up to 11 is 11 (the floor),
-- 12 is 12, 13 to 15 is 14, 16 to 19 is 17, 20 to 23 is 22, 24 to 34 is 28, anything larger is 40.
T.SCALE = { 11, 12, 14, 17, 22, 28, 40 }
local SNAP_UPTO = { 11, 12, 15, 19, 23, 34 }
function T.Snap(px)
	px = tonumber(px)
	if not px then return T.SIZE.body end
	for i = 1, #SNAP_UPTO do
		if px <= SNAP_UPTO[i] then return T.SCALE[i] end
	end
	return T.SCALE[#T.SCALE]
end

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
	panel = hex("181630"),       -- sheets and panels
	card = hex("211E3B"),        -- cards, rows, fields, chips at rest
	hover = hex("2A2748"),       -- card2: a card under the mouse or pressed (the same colour as raised)
	line = hex("333154"),        -- lines and dividers
	raised = hex("2A2748"),      -- card2: a switch that is off, step dots, the second button
	white = hex("F2EEFF"),       -- main text
	ink = hex("1D1B31"),         -- text on gold and on violet (never white on violet: 2.8 to 1)
	muted = hex("ABA5C9"),       -- secondary text: lavender grey (S12: a touch brighter than 9A93B8)
	accent = hex("A974F5"),      -- violet, ONE colour under three names: what is chosen, progress, links
	glow = hex("A974F5"),        -- the same violet ("Open", highlights)
	magenta = hex("A974F5"),     -- the same violet (once the hot edge of glows)
	teal = hex("33E0CC"),        -- the Pioneer Driver badge only
	gold = hex("F9C53E"),        -- prices and the one main button of a screen (and the Founder badge)
	goldLight = hex("FFD866"),
	goldPress = hex("E0AE2E"),
	goldDeep = hex("B1873F"),    -- no longer drawn by the theme (the name stays for old callers)
	amber = hex("F9A23E"),       -- the driver's big button only; a warning is red
	off = hex("8B83AC"),         -- paused, off (4.5:1 on a card)
	offText = hex("8F89AD"),     -- S12: a disabled button's label (readable on a card, still quiet)
	red = hex("FF5C7A"),         -- errors and warnings (the one warning colour)
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

-- (design round 4, F) the chart ramp: ONE violet from faint to strong for every bar and square (an amount is
-- not a price, so no gold). Each step is the violet token at that strength over the card colour, opaque, so a
-- chart square is the same colour on any card. T.RampRGB(i) = r, g, b of step i (1 faintest .. #T.RAMP strongest).
T.RAMP = { 0.18, 0.40, 0.65, 1.0 }
function T.RampRGB(i)
	local a = T.RAMP[math.max(1, math.min(#T.RAMP, math.floor(tonumber(i) or 1)))]
	local c, v = T.C.card, T.C.accent
	return c[1] + (v[1] - c[1]) * a, c[2] + (v[2] - c[2]) * a, c[3] + (v[3] - c[3]) * a
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
	return T.Snap(tonumber(size) or T.SIZE.body)
end

-- S12 (round 9): the smallest text drawn a notch larger, in this one place. Every size the code
-- asks for (and remembers, and fits with) stays the size it asked for; only the drawn and
-- measured size of text under T.READABLE.under px grows by T.READABLE.by (so 9 draws at 10, 10
-- at 11; 11 and up as asked). T.DrawnSize(size) answers it.
-- (design round 3) Every size is on the scale now and the scale starts at 11, so nothing is under 11 and the
-- notch adds nothing; the name and T.DrawnSize stay for callers.
T.READABLE = { under = 11, by = 1 }
local function drawn(px)
	local r = T.READABLE
	if type(r) == "table" and tonumber(r.under) and px < r.under then return px + (tonumber(r.by) or 0) end
	return px
end
function T.DrawnSize(size) return drawn(fontSize(size)) end

-- (design round 1) Line spacing: the gap between the lines of a wrapped label is T.LEADING x its drawn size,
-- in whole units (13 gets 4, 11 gets 3). T.SetFont sets it on every label. A label of n lines is
-- n x T.DrawnSize(size) + (n - 1) x T.Spacing(size) tall; one line is as tall as it was.
T.LEADING = 0.3
function T.Spacing(size) return math.floor(drawn(fontSize(size)) * T.LEADING + 0.5) end

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

-- Every Wuber font string (weak), for T.RefreshText.
T.allText = setmetatable({}, { __mode = "k" })

-- RefreshTextUnder(frame): RefreshText for the strings inside one frame only.
-- (speed, job 2749) Re-setting many labels at once (the refreshes below) holds the list cards' layout (Theme.Forms,
-- Group:Layout asks T.HoldLayout) until the end: each card is laid out once with its final words, not once per label
-- it holds (40 rows on Home were 2 x 40 full card layouts per refresh). What is drawn at the end is the same.
T.layoutHold = 0
local held = { list = {}, set = {} }
function T.HoldLayout(group)
	if T.layoutHold <= 0 or group == nil then return false end
	if not held.set[group] then
		held.set[group] = true
		held.list[#held.list + 1] = group
	end
	return true
end
T.textEpoch = 0 -- (speed) counts the text refreshes: a list row laid out before one is laid out again (Forms rowLayout)
local function layoutsHeld(fn, ...)
	if T.layoutHold <= 0 then T.textEpoch = T.textEpoch + 1 end
	T.layoutHold = T.layoutHold + 1
	local ok, err = pcall(fn, ...)
	T.layoutHold = T.layoutHold - 1
	if T.layoutHold <= 0 then
		T.layoutHold = 0
		local list = held.list
		held.list, held.set = {}, {}
		for _, g in ipairs(list) do
			if type(g.Layout) == "function" then pcall(g.Layout, g) end
		end
	end
	if not ok then error(err, 0) end
end
T.LayoutsHeld = layoutsHeld

local function refreshUnder(frame)
	for fs in pairs(T.allText) do
		local p, n = fs, 0
		while p and n < 16 do
			if p == frame then
				T.RefreshOne(fs)
				break
			end
			local ok, parent = pcall(p.GetParent, p)
			p = ok and parent or nil
			n = n + 1
		end
	end
end
function T.RefreshTextUnder(frame)
	if not frame then return end
	layoutsHeld(refreshUnder, frame)
end

-- Text set before the game had loaded the addon font (built while hidden, at login) can be drawn at a
-- tiny size and stays that way until it is set again. RefreshText re-applies each string's
-- font and text: run when the window first shows, and shortly after.
function T.RefreshOne(fs)
		local px, weight = fs.wuberPx, fs.wuberWeight
		if px then
			local wasFitting = fs.wuberFitting
			fs.wuberFitting = true
			pcall(T.SetFont, fs, px, weight)
			fs.wuberFitting = wasFitting
			local ok, text = pcall(fs.GetText, fs)
			if ok and type(text) == "string" and text ~= "" then
				local set = fs.SetText
				pcall(set, fs, "")
				fs.wuberText = nil
				pcall(set, fs, text)
			end
		end
end

local function refreshAll()
	for fs in pairs(T.allText) do T.RefreshOne(fs) end
end
function T.RefreshText() layoutsHeld(refreshAll) end

-- RefreshShown(): RefreshText for the strings on screen now only (cheap).
local function refreshShown()
	for fs in pairs(T.allText) do
		local ok, shown = pcall(fs.IsVisible, fs)
		if ok and shown then T.RefreshOne(fs) end
	end
end
function T.RefreshShown() layoutsHeld(refreshShown) end

-- (BRIEF18, the author's clue) The game loads the addon font (Inter) a moment after login. Text set before then keeps a
-- layout made with another font's widths until it is set again ("tap Res..." on the floating
-- button, which shows from login; it came right only when the window's first open re-set it). A
-- probe string in Inter says when the game measures Inter as Inter: then every Wuber string
-- is set again (T.RefreshText), once, the shown ones once more a moment later, and FONT_READY
-- fires. Loaded already at login (a /reload): nothing to do. Never told within upto seconds: the
-- shown strings are set again once. FONT_WAIT.near: how close to Inter's own widths counts.
-- The probe's words: in Inter Regular they are 0.501 of the size a letter (143.3 wide at 22), in Arial Narrow
-- 0.382 (109.3 at 22: 24% narrower, six times FONT_WAIT.near), so the two are never mistaken; size is one of the seven.
T.FONT_WAIT = { every = 0.5, upto = 30, again = 1, near = 0.04, probe = "uruuru uruuru", size = 22 }
local fontProbe
local function probeWidth()
	local wt = T.FONT_WAIT
	if not fontProbe then
		local ok, f = pcall(CreateFrame, "Frame", nil, UIParent)
		if not ok or type(f) ~= "table" then return nil end
		f:Hide()
		fontProbe = f:CreateFontString(nil, "OVERLAY")
	end
	pcall(method, fontProbe, "SetFont", T.FONTS.regular, wt.size, "")
	pcall(method, fontProbe, "SetText", "")
	pcall(method, fontProbe, "SetText", wt.probe)
	local got = tonumber(Try(fontProbe, "GetStringWidth"))
	if not got or got <= 0 then return nil end
	return got
end
local function near(a, b) return a and b and math.abs(a - b) <= b * T.FONT_WAIT.near end
-- WatchFont(): from login (W.OnLogin); true when the font was there at once.
function T.WatchFont()
	local wt = T.FONT_WAIT
	local want = T.MeasureText(wt.probe, wt.size, "regular") / 1.03
	local first = probeWidth()
	if not first or near(first, want) then return true end
	local waited = 0
	local function tick()
		waited = waited + wt.every
		local got = probeWidth()
		if near(got, want) or (got and not near(got, first)) then
			T.RefreshText()
			W.After(wt.again, T.RefreshShown)
			if W.Fire then W.Fire("FONT_READY") end
		elseif waited >= wt.upto then
			T.RefreshShown()
		else
			W.After(wt.every, tick)
		end
	end
	W.After(wt.every, tick)
	return false
end
W.OnLogin(function() T.WatchFont() end)

-- Arial Narrow first (always there), then Inter on top. This client's SetFont returns false
-- for addon fonts even when they load (other addons' .ttf fonts show fine in game), so its
-- answer isn't trusted: if Inter really fails, the string keeps Arial Narrow.
-- T.poppins = false (e.g. /run Wuber.Theme.poppins=false) turns the addon font off
-- (the switch keeps its older name: it was made for the font Wuber used before Inter).
-- An EditBox made with no template shares one font object with the chat box, so a font call on it can
-- change what the player types in chat. T.OwnFont gives the box a font object of its own (named Wuber...,
-- copied from the box's current font) before its first T.SetFont. Nothing happens where the client lacks
-- CreateFont. Safe to call twice.
local ownFontCount = 0
function T.OwnFont(eb)
	if type(eb) ~= "table" or eb.wuberOwnFont or type(CreateFont) ~= "function" then return false end
	ownFontCount = ownFontCount + 1
	local okMake, obj = pcall(CreateFont, "WuberEditFont" .. ownFontCount)
	if not okMake or type(obj) ~= "table" then return false end
	local okGet, path, size, flags = pcall(method, eb, "GetFont")
	if okGet and path ~= MISSING and path then pcall(method, obj, "SetFont", path, size, flags or "") end
	local okSet, res = pcall(method, eb, "SetFontObject", obj)
	if not okSet or res == MISSING then return false end
	eb.wuberOwnFont = obj
	return true
end

function T.SetFont(fs, size, weight)
	local px = fontSize(size)
	if type(size) == "string" and not weight then weight = T.WEIGHT[size] end
	-- remembered for fitting: the size asked for (base) and the size drawn now
	if type(fs) == "table" then
		fs.wuberPx, fs.wuberWeight = px, weight or "medium"
		if not fs.wuberFitting then fs.wuberBase = px end
		T.allText[fs] = true
	end
	-- Arial Narrow runs small next to Inter: a touch larger keeps the layout
	local draw = (type(fs) == "table" and fs.wuberFlat) and px or drawn(px)
	local base = setFile(fs, T.FONT, math.floor(draw * 1.12 + 0.5))
	if not base then
		local font = GameFontNormal or GameFontHighlight
		if font then Try(fs, "SetFontObject", font) end
	end
	if T.poppins ~= false then
		pcall(method, fs, "SetFont", T.FONTS[weight or "medium"] or T.FONTS.medium, draw, "")
	end
	-- (design round 1) wrapped lines get air: set with the font, so a refit at another size keeps it in step
	Try(fs, "SetSpacing", math.floor(draw * T.LEADING + 0.5))
	-- no shadow on text inside the phone; text over the game world (T.WorldText) keeps one
	if type(fs) == "table" and fs.wuberWorld then
		Try(fs, "SetShadowOffset", 1, -1)
		Try(fs, "SetShadowColor", 0, 0, 0, 0.45)
	else
		Try(fs, "SetShadowOffset", 0, 0)
		Try(fs, "SetShadowColor", 0, 0, 0, 0)
	end
end

-- WorldText(fs): for text drawn straight over the game world, with no Wuber fill behind it (the floating
-- button's words, the alert banner): a soft black shadow, kept through every later T.SetFont. Returns fs.
function T.WorldText(fs)
	if type(fs) ~= "table" then return fs end
	fs.wuberWorld = true
	Try(fs, "SetShadowOffset", 1, -1)
	Try(fs, "SetShadowColor", 0, 0, 0, 0.45)
	return fs
end

-- Inter's advance widths (characters 32..126, in thousandths of the font size, the ten digits one width), from the
-- shipped font files by tools/preview/fontmetrics.py --tokens (never typed by hand; tests/d3/d3_a_font_test.lua reads
-- the files and compares): text is measured before the game has the font loaded (GetStringWidth answers
-- with Arial Narrow's narrower widths until then, which cut the text short with "...").
local INTER_W = {
	regular = { 281, 288, 466, 633, 642, 982, 644, 300, 365, 365, 501, 662, 288, 460, 288, 360, 648, 648, 648, 648, 648, 648, 648, 648, 648, 648, 288, 302, 662, 662, 662, 511, 966, 690, 654, 730, 722, 601, 590, 746, 743, 269, 571, 672, 565, 903, 753, 765, 639, 765, 644, 642, 646, 744, 690, 985, 682, 679, 629, 365, 360, 365, 471, 456, 323, 562, 612, 571, 612, 583, 370, 613, 591, 242, 242, 549, 242, 876, 591, 600, 612, 612, 376, 528, 327, 591, 562, 818, 546, 562, 552, 426, 333, 426, 662 },
	medium = { 267, 304, 495, 639, 646, 993, 653, 313, 369, 369, 521, 667, 303, 462, 303, 370, 648, 648, 648, 648, 648, 648, 648, 648, 648, 648, 303, 315, 667, 667, 667, 527, 982, 709, 657, 733, 722, 603, 589, 748, 745, 272, 575, 688, 565, 913, 756, 767, 642, 769, 648, 646, 653, 740, 709, 1003, 701, 696, 641, 369, 370, 369, 477, 463, 337, 568, 618, 577, 618, 587, 379, 620, 602, 252, 252, 559, 252, 888, 602, 604, 618, 618, 387, 539, 340, 602, 575, 829, 557, 575, 559, 440, 346, 440, 667 },
	bold = { 237, 338, 552, 649, 655, 1016, 672, 339, 377, 377, 559, 679, 334, 468, 334, 388, 646, 646, 646, 646, 646, 646, 646, 646, 646, 646, 334, 343, 679, 679, 679, 560, 1016, 747, 662, 740, 722, 607, 587, 750, 747, 281, 584, 719, 565, 932, 762, 771, 648, 777, 657, 655, 667, 732, 747, 1038, 738, 731, 664, 377, 388, 377, 487, 476, 365, 581, 630, 588, 630, 596, 398, 632, 623, 271, 271, 580, 271, 913, 623, 613, 630, 630, 407, 560, 366, 623, 600, 850, 580, 602, 573, 469, 372, 469, 679 },
}
-- one character that isn't plain ASCII: Inter's average small accented letter (U+00DF..00FF, mean of the three weights)
local ACCENT_W = 561
Mod.FONT_W, Mod.ACCENT_W = INTER_W, ACCENT_W

-- MeasureText(text, size, weight): how wide the text is in Inter (UI units), a little generous.
local function measureAt(text, px, weight)
	text = tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "WW")
	local tbl = INTER_W[weight or "medium"] or INTER_W.medium
	local sum = 0
	for i = 1, #text do
		local b = text:byte(i)
		if b >= 32 and b <= 126 then
			sum = sum + tbl[b - 31]
		elseif b >= 0xC0 then
			sum = sum + ACCENT_W -- one character that isn't plain ASCII (its other bytes add nothing)
		end
	end
	return sum * px / 1000 * 1.03
end
function T.MeasureText(text, size, weight)
	if type(size) == "string" and not weight then weight = T.WEIGHT[size] end
	return measureAt(text, drawn(fontSize(size)), weight)
end

-- TextWidth(fs, text): the room a font string's text needs (the wider of the game's answer
-- and Inter's own measure, so a label sized by it is never cut short).
function T.TextWidth(fs, text)
	local got = tonumber(Try(fs, "GetStringWidth")) or 0
	if T.poppins == false or not (type(fs) == "table" and fs.wuberPx) then return got end
	text = text or fs.wuberText or Try(fs, "GetText") or ""
	return math.max(got, T.MeasureText(text, fs.wuberPx, fs.wuberWeight))
end

-- the width a label has: its anchors' (two or more points), else the width it was given; a label
-- with fs.wuberSpare = k (round 13, I18) is fitted into room / k (the game draws some words a touch
-- wider than measured: 'Orgrimmar' was cut at 'Orgrim...')
local roomAt
local function roomOf(fs)
	local r = roomAt(fs)
	local k = tonumber(fs.wuberSpare)
	if r and k and k > 0 then return r / k end
	return r
end
roomAt = function(fs)
	local n = tonumber(Try(fs, "GetNumPoints")) or 0
	if n >= 2 then
		local hasL, hasR = false, false
		for i = 1, n do
			local p = Try(fs, "GetPoint", i)
			if type(p) == "string" then
				if p:find("LEFT", 1, true) then hasL = true end
				if p:find("RIGHT", 1, true) then hasR = true end
			end
		end
		if hasL and hasR then
			-- laid out (both edges known): the room between them
			local l, r = tonumber(Try(fs, "GetLeft")), tonumber(Try(fs, "GetRight"))
			if l and r and r > l then return r - l end
		end
	end
	local r = fs.wuberRoom
	if r and r > 0 then return r end
	return nil
end

-- how many lines the words take in room, drawn at exactly px (S12: the notch never adds a line)
local function lineCount(text, px, weight, room)
	local n, cur = 1, ""
	for word in text:gmatch("%S+") do
		local try = cur == "" and word or (cur .. " " .. word)
		-- (measured as drawn, without MeasureText's 3% of room to spare: a near-full line stays one line)
		if cur ~= "" and measureAt(try, px, weight) / 1.03 > room then n, cur = n + 1, word else cur = try end
	end
	return n
end

-- whether the words fit on `lines` lines of `room`
local function wraps(text, px, weight, room, lines)
	local n, cur = 1, ""
	for word in text:gmatch("%S+") do
		if T.MeasureText(word, px, weight) > room then return false end
		local try = cur == "" and word or (cur .. " " .. word)
		if T.MeasureText(try, px, weight) <= room then
			cur = try
		else
			n, cur = n + 1, word
			if n > lines then return false end
		end
	end
	return true
end

-- (20 Nov hotfix) the game's own answer wins: our widths are estimates, and when the game still cuts the
-- text ("Advertis...", "tap Res..."), wrap a two-line label and shrink until the game says it fits
local function realFit(fs)
	if fs.wuberFitting or not fs.wuberBase or Try(fs, "IsTruncated") ~= true then return end
	local weight = fs.wuberWeight
	fs.wuberFitting = true
	if (fs.wuberLines or 1) >= 2 then
		Try(fs, "SetWordWrap", true)
		fs.wuberWrapped = true
	end
	local low = fs.wuberMin or math.max(drawn(8) >= 9 and 8 or 9, math.floor(fs.wuberBase * 0.8))
	local px = tonumber(fs.wuberPx) or fs.wuberBase
	while px > low and Try(fs, "IsTruncated") == true do
		px = px - 1
		pcall(T.SetFont, fs, px, weight)
	end
	fs.wuberFitting = false
end

-- Fit(fs): a one-line label whose text is wider than its room gets a smaller size (down to
-- 80%, never below 9) instead of "..."; a label allowed two lines (T.Lines(fs, 2)) wraps
-- first. Runs by itself on SetText and SetWidth of every T.Text label.
-- (design round 3) The smaller size is the next one down the scale (a body label goes 14, 12, 11; a
-- caption has nowhere to go: its frame must hold it), because T.SetFont and T.MeasureText snap alike.
function T.Fit(fs)
	if type(fs) ~= "table" or fs.wuberFitting or not fs.wuberBase or T.poppins == false then return end
	-- a label its maker lets wrap already has room (more lines); leave its size alone
	if fs.wuberWrapOn and not fs.wuberLines then
		-- S12: drawn a notch up only when that adds no line (a wrapped label's layout keeps)
		local base, flat = fs.wuberBase, nil
		local room = drawn(base) ~= base and roomOf(fs)
		if room and lineCount(fs.wuberText or "", drawn(base), fs.wuberWeight, room) > lineCount(fs.wuberText or "", base, fs.wuberWeight, room) then
			flat = true
		end
		if fs.wuberPx ~= base or fs.wuberFlat ~= flat then
			fs.wuberFlat = flat
			fs.wuberFitting = true
			pcall(T.SetFont, fs, fs.wuberBase, fs.wuberWeight)
			fs.wuberFitting = false
		end
		return
	end
	local text = fs.wuberText or ""
	local base, weight = fs.wuberBase, fs.wuberWeight
	local room = roomOf(fs)
	local px, wrap = base, false
	-- (2.4 fix round 3, stage A) a label allowed more lines (T.Lines, or SetMaxLines of 2 or more) wraps first,
	-- at full size; it shrinks only when its lines still do not hold the text, and then only as far as they do
	local lines = fs.wuberLines or ((tonumber(fs.wuberMaxLines) or 0) >= 2 and fs.wuberMaxLines) or 1
	if room and text ~= "" and T.MeasureText(text, base, weight) > room then
		if lines >= 2 and wraps(text, base, weight, room, lines) then
			wrap = true
		else
			-- never drawn below 9 (S12 draws small sizes a notch up, so the floor is asked for in drawn px)
			local low = fs.wuberMin or math.max(drawn(8) >= 9 and 8 or 9, math.floor(base * 0.8))
			if lines >= 2 then
				while px > low and not wraps(text, px, weight, room, lines) do px = px - 1 end
				wrap = T.MeasureText(text, px, weight) > room
			else
				while px > low and T.MeasureText(text, px, weight) > room do px = px - 1 end
			end
		end
	end
	local wasFlat = fs.wuberFlat
	fs.wuberFlat = nil
	fs.wuberFitting = true
	if px ~= fs.wuberPx or wasFlat then pcall(T.SetFont, fs, px, weight) end
	-- (20 Nov hotfix) a label allowed two lines keeps word wrap on even when our estimate says one line
	-- fits: the game draws some strings wider than the estimate, and with wrap off it cut them ("tap Res...")
	if fs.wuberLines or lines >= 2 then Try(fs, "SetWordWrap", wrap or lines >= 2) end
	fs.wuberFitting = false
	fs.wuberWrapped = wrap
	realFit(fs)
	-- (design round 4) still one line and cut: hovering it will show the whole text (T.WholeOnHover, Theme.Forms)
	-- (the game's answer can come before the label is laid out, and a hook set now would not survive the widget's own
	-- SetScript): so a label our measure finds too wide is looked at again a moment later, once it is laid out
	if not fs.wuberWhole and not fs.wuberWholeAsk and not wrap and lines < 2 and T.WholeOnHover
		and room and text ~= "" and T.MeasureText(text, px, weight) > room then
		fs.wuberWholeAsk = true
		W.After(0, function()
			fs.wuberWholeAsk = nil
			if not fs.wuberWhole and T.CutOneLine(fs) then T.WholeOnHover(fs) end
		end)
	end
end

-- Lines(fs, n): the label may wrap onto n lines (2) when its text is too long for one.
function T.Lines(fs, n)
	fs.wuberLines = n
	T.Fit(fs)
	return fs
end

-- A font string: size is a name from T.SIZE ("heading", "body", "caption", ...); a number is snapped to the scale;
-- weight "regular", "medium" or "bold" (default from T.WEIGHT, else medium).
-- Text too wide for its width shrinks a little (T.Fit) rather than being cut short.
function T.Text(parent, size, colour, justify, weight, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	T.SetFont(fs, size, weight)
	fs:SetTextColor(T.RGB(colour or "white"))
	fs:SetJustifyH(justify or "LEFT")
	Try(fs, "SetJustifyV", "MIDDLE")
	Try(fs, "SetWordWrap", false)
	local setText, setWidth, setWrap, setMax = fs.SetText, fs.SetWidth, fs.SetWordWrap, fs.SetMaxLines
	if type(setMax) == "function" then
		-- (2.4 fix round 3) T.Fit knows the lines a label may take
		fs.SetMaxLines = function(self, n, ...)
			self.wuberMaxLines = tonumber(n)
			return setMax(self, n, ...)
		end
	end
	if type(setWrap) == "function" then
		fs.SetWordWrap = function(self, on)
			setWrap(self, on)
			if not self.wuberFitting then
				self.wuberWrapOn = on and true or false
				T.Fit(self)
			end
		end
	end
	if type(setText) == "function" and type(setWidth) == "function" then
		fs.SetText = function(self, text)
			setText(self, text)
			local t = text ~= nil and tostring(text) or ""
			if t ~= self.wuberText then
				self.wuberText = t
				T.Fit(self)
			end
		end
		fs.SetWidth = function(self, w)
			setWidth(self, w)
			self.wuberRoom = tonumber(w)
			T.Fit(self)
		end
	end
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
	self.colour, self.alpha = c, alpha
end
function Slice:SetShown(shown)
	for _, t in pairs(self.parts) do
		if shown then t:Show() else t:Hide() end
	end
end
function Slice:SetAlpha(a)
	for _, t in pairs(self.parts) do t:SetAlpha(a) end
end

-- anchor: lay the slices round another region (they still belong to frame, so they draw at
-- frame's level: the phone's shadow sits under the window and round the whole handset).
function T.NineSlice(frame, name, px, c, layer, sub, out, anchor)
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
	local to = anchor or frame
	p.TL:SetSize(px, px)
	p.TL:SetPoint("TOPLEFT", to, "TOPLEFT", -out, out)
	p.TR:SetSize(px, px)
	p.TR:SetPoint("TOPRIGHT", to, "TOPRIGHT", out, out)
	p.BL:SetSize(px, px)
	p.BL:SetPoint("BOTTOMLEFT", to, "BOTTOMLEFT", -out, -out)
	p.BR:SetSize(px, px)
	p.BR:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", out, -out)
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

-- A rounded fill on frame. (Design 1) One corner size for the whole app: T.CORNER.radius (14), whatever
-- radius the caller asks for; a frame under T.CORNER.small (28) high gets half its height. The corners
-- follow the frame when it is sized later (OnSizeChanged, OnShow). out: how far the fill reaches outside
-- the frame (an outline): its corners are that much larger. A shape that must keep a radius of its own
-- (the handset, the driver's big button) uses T.NineSlice itself.
T.CORNER = { radius = 14, small = 28, round = 32, window = 7 } -- window: the corner of the window art (Media/winbg.tga), for what must lie inside it (a sheet's dim)
local function cornerFor(h, out)
	local k = T.CORNER
	h = tonumber(h)
	if h and h > 0 and h < k.small then return h / 2 + out end
	return k.radius + out
end
function T.Rounded(frame, colour, radius, layer, sub, out)
	local reach = tonumber(out) or 0
	local s = T.NineSlice(frame, "rounded", cornerFor(Try(frame, "GetHeight"), reach), 0.25, layer or "BACKGROUND", sub or 0, out)
	s:SetColor(colour or "card")
	local function fit(self, _, h)
		local px = cornerFor(h or Try(self, "GetHeight"), reach)
		if px == s.px then return end
		s.px = px
		local p = s.parts
		p.TL:SetSize(px, px)
		p.TR:SetSize(px, px)
		p.BL:SetSize(px, px)
		p.BR:SetSize(px, px)
	end
	fit(frame)
	Try(frame, "HookScript", "OnSizeChanged", fit)
	Try(frame, "HookScript", "OnShow", function(self) fit(self) end)
	return s
end

-- A pill fill (fully round ends) on frame; the caps are half the frame's height.
-- (Design 1) Fully round only up to T.CORNER.round (32) high: a taller one is a rounded rectangle with
-- the app's one corner (its own nine-slice, s.rect, made when first needed; s.capsule says which shape
-- shows). SetHeight chooses, so a fill sized later changes shape with it.
local Pill3 = {}
Pill3.__index = Pill3
local function pillShow(self)
	local on = not self.hidden
	for _, t in ipairs(self.parts) do
		if on and self.capsule then t:Show() else t:Hide() end
	end
	if self.rect then self.rect:SetShown(on and not self.capsule) end
end
function Pill3:SetColor(c, alpha)
	local r, g, b, a = T.RGB(c, alpha)
	for _, t in ipairs(self.parts) do t:SetVertexColor(r, g, b, a) end
	if self.rect then self.rect:SetColor(c, alpha) end
	self.colour, self.alpha = c, alpha
end
function Pill3:SetHeight(h)
	h = tonumber(h) or 0
	self.parts[1]:SetWidth(h / 2)
	self.parts[3]:SetWidth(h / 2)
	local capsule = h <= T.CORNER.round
	if not capsule and not self.rect then
		self.rect = T.NineSlice(self.frame, "rounded", T.CORNER.radius, 0.25, self.layer, self.sub)
		self.rect:SetColor(self.colour or "card", self.alpha)
	end
	if capsule ~= self.capsule then
		self.capsule = capsule
		pillShow(self)
	end
end
function Pill3:SetShown(shown)
	self.hidden = not shown
	pillShow(self)
end

function T.PillFill(frame, colour, h, layer, sub)
	local s = setmetatable({ parts = {}, frame = frame, layer = layer or "BACKGROUND", sub = sub or 0 }, Pill3)
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
	s:SetColor(colour or "card")
	s:SetHeight(h or 32)
	return s
end

---------------------------------------------------------------------------
-- Card: one flat rounded panel
---------------------------------------------------------------------------
-- (Design 1) One card: a flat fill with the app's one corner (T.Rounded). No shadow, no border, no gradient,
-- whatever opts ask for. opts: { colour = "card" }; opts.radius, opts.shadow and opts.border are ignored.
-- card.bg is the fill's slice (card.bg:SetColor("line")). card.shadow (unless opts.shadow == false) and
-- card.border (when opts.border is given) are still there for callers, as slices that draw nothing.

function T.Card(parent, w, h, opts)
	opts = opts or {}
	local f = CreateFrame("Frame", nil, parent)
	if w and h then f:SetSize(w, h) end
	if opts.shadow ~= false then f.shadow = setmetatable({ parts = {} }, Slice) end
	if opts.border then f.border = setmetatable({ parts = {} }, Slice) end
	f.bg = T.Rounded(f, opts.colour or "card", T.CORNER.radius, "BACKGROUND", -4)
	return f
end

-- exports (REFACTOR-MAP section 2)
Mod.hex, Mod.MISSING, Mod.method = hex, MISSING, method

---------------------------------------------------------------------------
-- Themes and live recolouring (appended here so earlier line numbers stay fixed)
---------------------------------------------------------------------------

T.C.well = hex("090913")
T.DEFAULT_THEME = "classic"
T.THEME_ORDER = { "classic", "daylight", "night", "fel" }
T.THEMES = {
	classic = {
		id = "classic", name = "Classic", desc = "Night-sky violet and gold.",
		c = {
			black = hex("0B0B16"), nightTop = hex("141228"), panel = hex("181630"), card = hex("211E3B"),
			hover = hex("2A2748"), line = hex("333154"), raised = hex("2A2748"), well = hex("090913"),
			white = hex("F2EEFF"), ink = hex("1D1B31"), muted = hex("ABA5C9"),
			accent = hex("A974F5"), glow = hex("A974F5"), magenta = hex("A974F5"),
			teal = hex("33E0CC"), gold = hex("F9C53E"), goldLight = hex("FFD866"),
			goldPress = hex("E0AE2E"), goldDeep = hex("B1873F"), amber = hex("F9A23E"),
			off = hex("8B83AC"), offText = hex("8F89AD"), red = hex("FF5C7A"),
			shadow = hex("000000", 0.6),
		},
	},
	daylight = {
		id = "daylight", name = "Daylight", desc = "Bright paper cards with dark ink.",
		c = {
			black = hex("EEF0F6"), nightTop = hex("F7F8FC"), panel = hex("E4E7F0"), card = hex("FFFFFF"),
			hover = hex("E9ECF5"), line = hex("C5CADB"), raised = hex("DDE1EE"), well = hex("F2F4FA"),
			white = hex("181A24"), ink = hex("FFFFFF"), muted = hex("4E5368"),
			accent = hex("6D3FD6"), glow = hex("6D3FD6"), magenta = hex("6D3FD6"),
			teal = hex("0B7A70"), gold = hex("8E5C00"), goldLight = hex("A66C00"),
			goldPress = hex("734900"), goldDeep = hex("704800"), amber = hex("A65900"),
			off = hex("585D72"), offText = hex("5E6378"), red = hex("C41E3A"),
			shadow = hex("000000", 0.25),
		},
	},
	night = {
		id = "night", name = "Night", desc = "Deep charcoal with cool ice-blue highlights.",
		c = {
			black = hex("07080C"), nightTop = hex("0E1118"), panel = hex("11141D"), card = hex("181C28"),
			hover = hex("222838"), line = hex("2C3347"), raised = hex("222838"), well = hex("0A0C12"),
			white = hex("EEF2FA"), ink = hex("0D1018"), muted = hex("9FAAC2"),
			accent = hex("66B2FF"), glow = hex("66B2FF"), magenta = hex("66B2FF"),
			teal = hex("33E0CC"), gold = hex("F5C242"), goldLight = hex("FFD66B"),
			goldPress = hex("D9A626"), goldDeep = hex("A8802C"), amber = hex("F59E3D"),
			off = hex("8591AA"), offText = hex("8C97B0"), red = hex("FF637D"),
			shadow = hex("000000", 0.7),
		},
	},
	fel = {
		id = "fel", name = "Fel", desc = "Dark obsidian with Warlock fel-green highlights.",
		c = {
			black = hex("08110E"), nightTop = hex("0F1D17"), panel = hex("11201A"), card = hex("182B23"),
			hover = hex("21392F"), line = hex("2D4A3E"), raised = hex("21392F"), well = hex("09130F"),
			white = hex("EBF7F1"), ink = hex("0B1712"), muted = hex("9BC2B1"),
			accent = hex("3CE08E"), glow = hex("3CE08E"), magenta = hex("3CE08E"),
			teal = hex("45E6D8"), gold = hex("F9C53E"), goldLight = hex("FFD866"),
			goldPress = hex("E0AE2E"), goldDeep = hex("B1873F"), amber = hex("F9A23E"),
			off = hex("82A898"), offText = hex("89B0A0"), red = hex("FF6B7E"),
			shadow = hex("000000", 0.65),
		},
	},
}
T.activeTheme = T.DEFAULT_THEME

local rgbLast = { token = nil, alpha = nil, r = nil, g = nil, b = nil, a = nil }
local function rgbMatches(r, g, b, a)
	if not rgbLast.token then return false end
	if math.abs((r or 0) - rgbLast.r) > 0.001 or math.abs((g or 0) - rgbLast.g) > 0.001 or math.abs((b or 0) - rgbLast.b) > 0.001 then
		return false
	end
	if a ~= nil and math.abs(a - rgbLast.a) > 0.001 then return false end
	return true
end

local origRGB = T.RGB
function T.RGB(c, alpha)
	local tok = type(c) == "string" and T.C[c] and c or nil
	local r, g, b, a = origRGB(c, alpha)
	if tok then
		rgbLast.token, rgbLast.alpha, rgbLast.r, rgbLast.g, rgbLast.b, rgbLast.a = tok, alpha, r, g, b, a
	else
		rgbLast.token = nil
	end
	return r, g, b, a
end

local allIcons = setmetatable({}, { __mode = "k" })
local allSlices = setmetatable({}, { __mode = "k" })
local allPills = setmetatable({}, { __mode = "k" })
local allRepaint = setmetatable({}, { __mode = "k" })
local allBackdrops = setmetatable({}, { __mode = "k" })

local origText = T.Text
function T.Text(parent, size, colour, justify, weight, layer)
	local fs = origText(parent, size, colour, justify, weight, layer)
	local col = colour or "white"
	if type(col) == "string" and T.C[col] then fs.wuberColor = col end
	local rawSetColor = fs.SetTextColor
	if type(rawSetColor) == "function" then
		fs.wuberRawSetColor = rawSetColor
		fs.SetTextColor = function(self, r, g, b, a)
			if rgbMatches(r, g, b, a) then
				self.wuberColor, self.wuberAlpha = rgbLast.token, rgbLast.alpha
			else
				self.wuberColor, self.wuberAlpha = nil, nil
			end
			return rawSetColor(self, r, g, b, a)
		end
	end
	return fs
end

local function trackVertex(t, col)
	if type(t) ~= "table" then return end
	if type(col) == "string" and T.C[col] then t.wuberColor = col end
	local rawSet = t.SetVertexColor
	if type(rawSet) == "function" then
		t.wuberRawSetVertex = rawSet
		t.SetVertexColor = function(self, r, g, b, a)
			if rgbMatches(r, g, b, a) then
				self.wuberColor, self.wuberAlpha = rgbLast.token, rgbLast.alpha
			else
				self.wuberColor, self.wuberAlpha = nil, nil
			end
			return rawSet(self, r, g, b, a)
		end
	end
	allIcons[t] = true
end

local origIcon = T.Icon
function T.Icon(parent, name, size, colour, layer)
	local t = origIcon(parent, name, size, colour, layer)
	trackVertex(t, colour or "white")
	return t
end

local origCircle = T.Circle
function T.Circle(parent, size, colour, layer, sub)
	local t = origCircle(parent, size, colour, layer, sub)
	trackVertex(t, colour or "white")
	return t
end

local origNineSlice = T.NineSlice
function T.NineSlice(frame, name, px, c, layer, sub, out, anchor)
	local s = origNineSlice(frame, name, px, c, layer, sub, out, anchor)
	allSlices[s] = true
	return s
end

local origPillFill = T.PillFill
function T.PillFill(frame, colour, h, layer, sub)
	local s = origPillFill(frame, colour, h, layer, sub)
	allPills[s] = true
	return s
end

local function paintBackdrop(bd)
	local classic = T.activeTheme == T.DEFAULT_THEME
	if type(bd.showArt) == "function" then
		pcall(bd.showArt, classic)
	elseif type(bd.art) == "table" then
		for _, t in ipairs(bd.art) do
			if t and t.SetShown then pcall(t.SetShown, t, classic) end
		end
	end
	if classic then
		if bd.fill then pcall(bd.fill.Hide, bd.fill) end
		return
	end
	local f = bd.fill
	if not f then
		f = bd.frame:CreateTexture(nil, bd.layer or "BACKGROUND", nil, bd.sub or -4)
		f:SetPoint("TOPLEFT", bd.frame, "TOPLEFT", 0, bd.top or 0)
		f:SetPoint("BOTTOMRIGHT", bd.frame, "BOTTOMRIGHT", 0, bd.bottom or 0)
		bd.fill = f
	end
	local br, bg, bb = T.RGB("black")
	local tr, tg, tb = T.RGB("nightTop")
	Try(f, "SetColorTexture", 1, 1, 1, 1)
	local ok = false
	if type(CreateColor) == "function" and f.SetGradient then
		Try(f, "SetVertexColor", 1, 1, 1, 1)
		ok = pcall(f.SetGradient, f, "VERTICAL", CreateColor(br, bg, bb, 1), CreateColor(tr, tg, tb, 1))
	end
	if not ok and f.SetGradientAlpha then
		ok = pcall(f.SetGradientAlpha, f, "VERTICAL", br, bg, bb, 1, tr, tg, tb, 1)
	end
	if not ok then
		if not pcall(f.SetColorTexture, f, br, bg, bb, 1) then
			Try(f, "SetVertexColor", br, bg, bb, 1)
		end
	end
	f:Show()
end

function T.OnTheme(obj, fn)
	if obj ~= nil and type(fn) == "function" then allRepaint[obj] = fn end
end

function T.RegisterBackdrop(frame, opts)
	if not frame then return nil end
	opts = opts or {}
	local bd = {
		frame = frame, art = opts.art, showArt = opts.showArt,
		top = opts.top or 0, bottom = opts.bottom or 0,
		layer = opts.layer or "BACKGROUND", sub = opts.sub or -4,
	}
	allBackdrops[frame] = bd
	if T.activeTheme ~= T.DEFAULT_THEME then paintBackdrop(bd) end
	return bd
end

function T.ThemeId(id)
	if id == nil then
		local db = W.db
		id = type(db) == "table" and db.theme or nil
	end
	if type(id) == "string" and T.THEMES[id] then return id end
	return T.DEFAULT_THEME
end

function T.ThemeInfo(id)
	return T.THEMES[T.ThemeId(id)]
end

function T.ApplyTheme(id, force)
	id = T.ThemeId(id)
	if id == T.activeTheme and not force then return id end
	local th = T.THEMES[id]
	T.activeTheme = id
	for k, col in pairs(th.c) do
		local dst = T.C[k]
		if type(dst) == "table" then
			dst[1], dst[2], dst[3], dst[4] = col[1], col[2], col[3], col[4]
		else
			T.C[k] = { col[1], col[2], col[3], col[4] }
		end
	end
	T.C.open = T.C.glow
	T.C.green = T.C.glow
	for s in pairs(allSlices) do
		if type(s.colour) == "string" and T.C[s.colour] then pcall(s.SetColor, s, s.colour, s.alpha) end
	end
	for p in pairs(allPills) do
		if type(p.colour) == "string" and T.C[p.colour] then pcall(p.SetColor, p, p.colour, p.alpha) end
	end
	for t in pairs(allIcons) do
		if type(t.wuberColor) == "string" and T.C[t.wuberColor] then
			local fn = t.wuberRawSetVertex or t.SetVertexColor
			if type(fn) == "function" then pcall(fn, t, T.RGB(t.wuberColor, t.wuberAlpha)) end
		end
	end
	for fs in pairs(T.allText) do
		if type(fs.wuberColor) == "string" and T.C[fs.wuberColor] then
			local fn = fs.wuberRawSetColor or fs.SetTextColor
			if type(fn) == "function" then pcall(fn, fs, T.RGB(fs.wuberColor, fs.wuberAlpha)) end
		end
	end
	for _, bd in pairs(allBackdrops) do paintBackdrop(bd) end
	for obj, fn in pairs(allRepaint) do pcall(fn, obj) end
	return id
end

function T.SetTheme(id)
	id = T.ThemeId(id)
	local db = W.db
	if type(db) == "table" then db.theme = id end
	T.ApplyTheme(id, true)
	if W.Fire then
		W.Fire("THEME", id)
		W.Fire("SETTINGS", "theme")
	end
	return id
end

W.OnLogin(function() T.ApplyTheme(T.ThemeId()) end)
