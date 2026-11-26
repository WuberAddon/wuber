-- Text as the game lays it out (tools only; never shipped): measures a FontString's text with the
-- shipped fonts' real glyph advances (tools/preview/fontmetrics.lua, unhinted, as the game's vector
-- text draws them), wraps it on spaces at the string's width, stops at its height or SetMaxLines,
-- and truncates the last line it keeps with "..." as the game's FontString does.
--   local TL = dofile("tools/preview/textlayout.lua")
--   TL.width(fontPath, size, text)                      -> width in the string's own units
--   TL.layout(fontPath, size, text, { width, height, wrap, maxLines, spacing })
--       -> { lines = {..}, widths = {..}, truncated = bool, lineH = n, height = n }
-- Used by the fake game in preview mode (tests/harness.lua H.textMetrics) and by dump.lua.
local here = (debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/"):match("^(.*)/[^/]*$")) or "."
local FONTS = dofile(here .. "/fontmetrics.lua")
local TL = {}

TL.EM = 1.0      -- the font's em per 1.0 of SetFont size (calibrated against the 19 Nov shots)
TL.LINE = 1.0    -- the line step per 1.0 of size (plus SetSpacing, which goes BETWEEN lines: n lines are n x size + (n - 1) x spacing tall)
TL.ELLIPSIS = "..."
TL.DEFAULT_FONT = "frizqt__.ttf" -- GameFontNormal and friends
TL.STRETCH = 1   -- every glyph advance times this (tools/layout-check.lua --stretch N: 1.3 = all text 30% wider; 1 changes nothing)
TL.LOADING = 0.05 -- seconds a font and size, first asked for, measure as Arial Narrow (the game loading it)

local function fontOf(path)
	local name = type(path) == "string" and path:gsub("\\", "/"):match("([^/]+)$") or TL.DEFAULT_FONT
	name = name:lower()
	if not name:find("%.") then name = name .. ".ttf" end
	return FONTS[name] or FONTS[TL.DEFAULT_FONT] or FONTS["inter-regular.ttf"], name
end
TL.fontOf = fontOf

-- the text the game draws: colour codes gone, |T..|t (inline textures) kept as one marker each
local function plain(text)
	text = tostring(text or "")
	text = text:gsub("||", "\1")
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|n", "\n")
	text = text:gsub("|H.-|h(.-)|h", "%1")
	return text
end
TL.plain = plain

-- the width of one inline texture: |Tpath:h:w:...|t (0 = the line's height; w defaults to h)
local function inlineWidth(spec, size)
	local _, h, w = spec:match("^([^:]*):?([%-%d%.]*):?([%-%d%.]*)")
	h, w = tonumber(h), tonumber(w)
	if not h or h == 0 then h = size end
	if not w or w == 0 then w = h end
	return w
end

-- Pixel snapping (as the game draws text): TL.PX = screen pixels per unit (tour.lua sets it) and
-- the string's effective scale give the pixel size; each glyph's advance is then rounded to whole
-- pixels (TL.SNAP: "round", "ceil", or nil = the font's own unrounded advances).
TL.PX = nil
TL.SNAP = nil
TL.SIZE_SNAP = nil -- "round": the pixel size itself is a whole number
TL.TRACK = 0 -- pixels added after each glyph (the game's text runs a little wider than the font's advances)
-- (#238, job 2885) the game draws text wider than the font's raw advances. The 2.4.3 run 3 Lab font check (a_font, the
-- game's GetStringWidth against the raw Inter table) measured: regular 11 = 1.045 to 1.064 on the maintainer's game (1.069 to
-- 1.077 on a second window; 1.06 is the middle of the eight), medium 14 = 1.040, regular 22 = 1.042; the other strings at 14 and 22 were inside the Lab's 4%
-- tolerance and were not listed, and 4 digits at 14 measured 37.0 to 37.5 against 36.3 raw (1.02 to 1.03).
-- So: the measured ratio at 11, 14 and 22; between two measured sizes the ratio is interpolated; below 11 and above 22 it is the
-- nearest measured one. Sizes the Lab did not measure are SCALED with the measured ratio this way, they are not measured.
-- Every glyph advance is multiplied by TL.ratio(size) (tests/r55/small_text_width_test.lua pins the measured rows).
TL.RATIOS = { { 11, 1.060 }, { 14, 1.040 }, { 22, 1.042 } }
-- TL.FLAT = true: the first draft's flat rule (#245: every glyph 6% wider at 12 px and under, nothing above), kept only so a proof can show what a
-- flat factor over-flags (tests/r55/probe_labels_test.lua, layout-check --text-rule flat). Off in every normal run.
TL.FLAT = nil
TL.RAW = nil -- true: the font's own advances, no ratio (tools/rec/probe-labels.lua records them next to what the game measured)
function TL.ratio(size)
	if TL.RAW then return 1 end
	if TL.FLAT then return size <= 12 and 1.06 or 1 end
	local R = TL.RATIOS
	if size <= R[1][1] then return R[1][2] end
	for i = 2, #R do
		if size <= R[i][1] then
			local s0, r0, s1, r1 = R[i - 1][1], R[i - 1][2], R[i][1], R[i][2]
			return r0 + (r1 - r0) * (size - s0) / (s1 - s0)
		end
	end
	return R[#R][2]
end
local snapScale = nil -- set per call (the string's effective scale)
local function adv(m, cp, size)
	local small = TL.ratio(size)
	local a = (m.adv[cp] or m.fallback) * size * TL.EM * TL.STRETCH * small
	if TL.PX and TL.SNAP and snapScale then
		local k = TL.PX * snapScale
		local P = size * TL.EM * k
		if TL.SIZE_SNAP == "round" then P = math.floor(P + 0.5) end
		local px = (m.adv[cp] or m.fallback) * P
		if TL.SNAP == "ceil" then px = math.ceil(px - 1e-6) elseif TL.SNAP == "floor" then px = math.floor(px + 1e-6) else px = math.floor(px + 0.5) end
		a = (px + TL.TRACK) / k * TL.STRETCH * small
	end
	return a
end

-- width of a run of text (no newlines), in units of the string
local function runWidth(m, size, s)
	local wsum = 0
	local i, n = 1, #s
	while i <= n do
		local a, b, spec = s:find("^|T(.-)|t", i)
		if a then
			wsum = wsum + inlineWidth(spec, size)
			i = b + 1
		else
			local c = s:byte(i)
			local cp, len
			if c < 0x80 then cp, len = c, 1
			elseif c >= 0xF0 then cp, len = ((c % 8) * 262144) + ((s:byte(i + 1) or 128) % 64) * 4096 + ((s:byte(i + 2) or 128) % 64) * 64 + ((s:byte(i + 3) or 128) % 64), 4
			elseif c >= 0xE0 then cp, len = ((c % 16) * 4096) + ((s:byte(i + 1) or 128) % 64) * 64 + ((s:byte(i + 2) or 128) % 64), 3
			elseif c >= 0xC0 then cp, len = ((c % 32) * 64) + ((s:byte(i + 1) or 128) % 64), 2
			else cp, len = c, 1 end
			if cp == 1 then cp = 124 end
			wsum = wsum + adv(m, cp, size)
			i = i + len
		end
	end
	return wsum
end

function TL.width(path, size, text, scale)
	snapScale = scale
	local m = fontOf(path)
	size = tonumber(size) or 12
	local best = 0
	for line in (plain(text) .. "\n"):gmatch("(.-)\n") do
		local wd = runWidth(m, size, line)
		if wd > best then best = wd end
	end
	return best
end

-- the longest start of s (whole characters) that fits maxW once "..." is added
local function cut(m, size, s, maxW)
	local ell = runWidth(m, size, TL.ELLIPSIS)
	local chars = {}
	for ch in s:gmatch("|T.-|t") do end
	local i, n = 1, #s
	while i <= n do
		local a, b = s:find("^|T.-|t", i)
		if a then chars[#chars + 1] = s:sub(a, b) i = b + 1
		else
			local c = s:byte(i)
			local len = c >= 0xF0 and 4 or c >= 0xE0 and 3 or c >= 0xC0 and 2 or 1
			chars[#chars + 1] = s:sub(i, i + len - 1)
			i = i + len
		end
	end
	local out, wsum = {}, 0
	for _, ch in ipairs(chars) do
		local cw = runWidth(m, size, ch)
		if wsum + cw + ell > maxW + 0.01 then break end
		out[#out + 1] = ch
		wsum = wsum + cw
	end
	local s2 = table.concat(out):gsub("%s+$", "")
	return s2 .. TL.ELLIPSIS
end

-- opts: width (nil = unbounded), height (nil = grows), wrap (default true), maxLines (0/nil = no
-- limit), spacing
function TL.layout(path, size, text, opts)
	opts = opts or {}
	snapScale = opts.scale
	local m = fontOf(path)
	size = tonumber(size) or 12
	local spacing = tonumber(opts.spacing) or 0
	local lineH = size * TL.LINE + spacing -- the step from one line to the next
	local W = opts.width
	local wrap = opts.wrap ~= false
	local lines, truncated = {}, false
	for para in (plain(text) .. "\n"):gmatch("(.-)\n") do
		if not W then
			lines[#lines + 1] = para
		elseif not wrap then
			if runWidth(m, size, para) > W + 0.01 then
				lines[#lines + 1] = cut(m, size, para, W)
				truncated = true
			else
				lines[#lines + 1] = para
			end
		else
			local cur = nil
			for word in para:gmatch("%S+") do
				local try = cur and (cur .. " " .. word) or word
				if runWidth(m, size, try) <= W + 0.01 then
					cur = try
				else
					if cur then lines[#lines + 1] = cur end
					if runWidth(m, size, word) > W + 0.01 then
						-- one word wider than the string: the game cuts it ("...")
						lines[#lines + 1] = cut(m, size, word, W)
						truncated = true
						cur = nil
					else
						cur = word
					end
				end
			end
			lines[#lines + 1] = cur or ""
		end
	end
	-- the lines the string has room for
	local keep = #lines
	local ml = tonumber(opts.maxLines) or 0
	if ml > 0 and keep > ml then keep = ml end
	if opts.height and opts.height > 0 then
		local fit = math.max(1, math.floor((opts.height + spacing + 0.5) / lineH + 0.001))
		if keep > fit then keep = fit end
	end
	if keep < #lines then
		local rest = {}
		for i = keep, #lines do rest[#rest + 1] = lines[i] end
		local last = table.concat(rest, " ")
		lines[keep] = W and cut(m, size, last, math.max(0, W - 0.01)) or (lines[keep] .. TL.ELLIPSIS)
		-- (cut keeps what fits with "..."; when the whole last line fits, the dots still show)
		for i = #lines, keep + 1, -1 do lines[i] = nil end
		truncated = true
	end
	local widths, maxW = {}, 0
	for i, ln in ipairs(lines) do
		widths[i] = runWidth(m, size, ln)
		if widths[i] > maxW then maxW = widths[i] end
	end
	return { lines = lines, widths = widths, truncated = truncated, lineH = lineH, height = math.max(0, #lines * lineH - spacing), width = maxW }
end

return TL
