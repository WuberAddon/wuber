-- Design round 3, group A: Wuber's text is drawn in Inter (three Latin-only files with equal-width digits, made by
-- tools/fonts/make_inter.py). The shipped files are read here (a small cmap and hmtx reader): what they hold, that the
-- width table in Theme/Tokens.lua is the files' own, and that the late-font probe still tells Inter from Arial Narrow.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local ROOT = T.dir .. "/../"
local FONT_DIR = ROOT .. "Wuber/Media/fonts/"
local WEIGHTS = { regular = "Inter-Regular.ttf", medium = "Inter-Medium.ttf", bold = "Inter-Bold.ttf" }

local function rider()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	T.settle(w)
	return w, r, r.W.Theme
end

local function slurp(path)
	local h = io.open(path, "rb")
	if not h then return nil end
	local s = h:read("*a")
	h:close()
	return s
end

-- a TrueType file's character map (code point -> glyph) and advance widths (in thousandths of the size)
local function readFont(path)
	local s = slurp(path)
	if not s then return nil end
	local function u16(o) local a, b = s:byte(o + 1, o + 2) return a * 256 + b end
	local function u32(o) return u16(o) * 65536 + u16(o + 2) end
	local function s16(o) local v = u16(o) return v >= 32768 and v - 65536 or v end
	local tables = {}
	for i = 0, u16(4) - 1 do
		local o = 12 + i * 16
		tables[s:sub(o + 1, o + 4)] = u32(o + 8)
	end
	local upm = u16(tables.head + 18)
	local nMetrics = u16(tables.hhea + 34)
	local function advance(gid)
		if gid >= nMetrics then gid = nMetrics - 1 end
		return u16(tables.hmtx + gid * 4)
	end
	local map = {}
	local cmap = tables.cmap
	for i = 0, u16(cmap + 2) - 1 do
		local rec = cmap + 4 + i * 8
		local platform, sub = u16(rec), cmap + u32(rec + 4)
		local format = u16(sub)
		if (platform == 0 or platform == 3) and format == 4 then
			local seg = u16(sub + 6) / 2
			local ends, starts = sub + 14, sub + 16 + seg * 2
			local deltas, ranges = starts + seg * 2, starts + seg * 4
			for k = 0, seg - 1 do
				local lo, hi, delta, ro = u16(starts + k * 2), u16(ends + k * 2), s16(deltas + k * 2), u16(ranges + k * 2)
				for cp = lo, hi do
					if cp ~= 0xFFFF then
						local gid
						if ro == 0 then
							gid = (cp + delta) % 65536
						else
							gid = u16(ranges + k * 2 + ro + (cp - lo) * 2)
							if gid ~= 0 then gid = (gid + delta) % 65536 end
						end
						if gid ~= 0 then map[cp] = gid end
					end
				end
			end
		elseif (platform == 0 or platform == 3) and format == 12 then
			for k = 0, u32(sub + 12) - 1 do
				local g = sub + 16 + k * 12
				local lo, hi, first = u32(g), u32(g + 4), u32(g + 8)
				for cp = lo, hi do map[cp] = first + (cp - lo) end
			end
		end
	end
	local font = { map = map, upm = upm, count = 0 }
	for _ in pairs(map) do font.count = font.count + 1 end
	-- the advance of a character in thousandths of the font size, to the nearest whole one (nil: not in the file)
	function font.width(cp)
		local gid = map[cp]
		return gid and math.floor(advance(gid) / upm * 1000 + 0.5) or nil
	end
	function font.exact(cp)
		local gid = map[cp]
		return gid and advance(gid) / upm or nil
	end
	return font
end

local fonts
local function shipped()
	if not fonts then
		fonts = {}
		for weight, name in pairs(WEIGHTS) do fonts[weight] = readFont(FONT_DIR .. name) end
	end
	return fonts
end

local function utf8codes(text, each)
	for ch in text:gmatch("[\194-\244][\128-\191]+") do
		local b1, b2, b3, b4 = ch:byte(1, 4)
		local cp
		if b1 < 0xE0 then cp = (b1 - 0xC0) * 64 + (b2 - 0x80)
		elseif b1 < 0xF0 then cp = (b1 - 0xE0) * 4096 + (b2 - 0x80) * 64 + ((b3 or 0x80) - 0x80)
		else cp = (b1 - 0xF0) * 262144 + (b2 - 0x80) * 4096 + ((b3 or 0x80) - 0x80) * 64 + ((b4 or 0x80) - 0x80) end
		each(cp)
	end
end

test("d3 a: T.FONTS names three Inter files; they are the only fonts shipped, and the licence is Inter's", function()
	local w, _, Th = rider()
	for weight, name in pairs(WEIGHTS) do
		eq(Th.FONTS[weight], "Interface\\AddOns\\Wuber\\Media\\fonts\\" .. name, weight)
		ok(slurp(FONT_DIR .. name), name .. " is in Wuber/Media/fonts")
	end
	local n = 0
	for _ in pairs(Th.FONTS) do n = n + 1 end
	eq(n, 3, "three weights, nothing else")
	for _, old in ipairs({ "Poppins-Regular.ttf", "Poppins-Medium.ttf", "Poppins-Bold.ttf" }) do
		eq(slurp(FONT_DIR .. old), nil, old .. " has left")
	end
	-- the folder's listing, where the shell gives one
	local windows = package.config:sub(1, 1) == "\\"
	local cmd = windows and ('dir /b "' .. FONT_DIR:gsub("/", "\\") .. '" 2>nul') or ('ls "' .. FONT_DIR .. '" 2>/dev/null')
	local okp, pipe = pcall(io.popen, cmd)
	if okp and pipe then
		local seen = 0
		for line in pipe:lines() do
			local name = line:gsub("%s+$", "")
			if name:lower():match("%.[ot]tf$") then
				seen = seen + 1
				ok(name == WEIGHTS.regular or name == WEIGHTS.medium or name == WEIGHTS.bold, "a font file T.FONTS does not name: " .. name)
			end
		end
		pipe:close()
		ok(seen == 0 or seen == 3, "three font files in the folder, got " .. seen)
	end
	local licence = slurp(FONT_DIR .. "OFL.txt") or ""
	ok(licence:find("The Inter Project Authors", 1, true), "OFL.txt names Inter's authors")
	ok(licence:find("SIL Open Font License", 1, true), "OFL.txt is the SIL Open Font License")
	ok(not licence:find("Reserved Font Name%s+[\"']"), "no Reserved Font Name is declared")
	ok(not licence:lower():find("poppins", 1, true), "OFL.txt no longer names the old font")
	T.clean(w)
end)

-- the author's rule: Latin only. Blocks no shipped file may hold a character of.
local BANNED = {
	{ 0x0370, 0x03FF, "Greek" }, { 0x1F00, 0x1FFF, "Greek Extended" },
	{ 0x0400, 0x052F, "Cyrillic" }, { 0x1C80, 0x1C8F, "Cyrillic Extended-C" }, { 0x2DE0, 0x2DFF, "Cyrillic Extended-A" },
	{ 0xA640, 0xA69F, "Cyrillic Extended-B" },
	{ 0x1100, 0x11FF, "Hangul Jamo" }, { 0x3130, 0x318F, "Hangul Compatibility Jamo" }, { 0xAC00, 0xD7AF, "Hangul" },
	{ 0x2E80, 0x312F, "CJK radicals, symbols, kana, bopomofo" }, { 0x3190, 0x9FFF, "CJK" }, { 0xF900, 0xFAFF, "CJK Compatibility" },
	{ 0xFF00, 0xFFEF, "full-width forms" }, { 0x20000, 0x3FFFF, "CJK extensions" },
	{ 0x1EA0, 0x1EFF, "Vietnamese (Latin Extended Additional)" },
}

test("d3 a: each shipped file is Latin only, holds every ASCII and Latin-1 character, and its ten digits are one width", function()
	for weight, name in pairs(WEIGHTS) do
		local f = shipped()[weight]
		ok(f, name .. " can be read")
		if f then
			for cp in pairs(f.map) do
				for _, b in ipairs(BANNED) do
					ok(not (cp >= b[1] and cp <= b[2]), ("%s holds U+%04X (%s)"):format(name, cp, b[3]))
				end
			end
			ok(f.count < 500, name .. " holds a few hundred characters, got " .. f.count)
			for cp = 32, 126 do ok(f.map[cp], ("%s lacks U+%04X"):format(name, cp)) end
			for cp = 0xA1, 0xFF do
				if cp ~= 0xAD then ok(f.map[cp], ("%s lacks U+%04X"):format(name, cp)) end -- Inter draws no soft hyphen
			end
			for cp = 0x100, 0x17F do
				if cp ~= 0x149 then ok(f.map[cp], ("%s lacks U+%04X"):format(name, cp)) end -- nor the old n-apostrophe
			end
			for _, cp in ipairs({ 0xA0, 0x218, 0x219, 0x21A, 0x21B, 0x1E9E, 0x2013, 0x2014, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022,
				0x2026, 0x2032, 0x2033, 0x2039, 0x203A, 0x2009, 0x202F, 0x20AC, 0x2122, 0x2190, 0x2191, 0x2192, 0x2193, 0x2212 }) do
				ok(f.map[cp], ("%s lacks U+%04X"):format(name, cp))
			end
			local digit = f.exact(48)
			for cp = 49, 57 do eq(f.exact(cp), digit, name .. ": the digit " .. string.char(cp) .. " is as wide as 0") end
			ok(f.exact(49) > f.exact(108) * 2, name .. ": 1 has the tabular width, far wider than l")
		end
	end
end)

test("d3 a: every character that isn't plain ASCII in Wuber's code is in all three files", function()
	local toc = slurp(ROOT .. "Wuber/Wuber.toc")
	ok(toc, "the TOC")
	local files, found = 0, {}
	for line in (toc or ""):gmatch("[^\r\n]+") do
		local rel = line:match("^%s*([%w_\\/%.%-]+%.lua)%s*$")
		local src = rel and slurp(ROOT .. "Wuber/" .. rel:gsub("\\", "/"))
		if src then
			files = files + 1
			for code in src:gmatch("[^\r\n]+") do
				if not code:match("^%s*%-%-") then -- a comment line is never drawn
					utf8codes(code, function(cp) found[cp] = rel end)
					-- and the same characters written as decimal bytes ("\226\128\166")
					for run in code:gmatch("\\%d%d%d[\\%d]*") do
						local bytes = {}
						for d in run:gmatch("\\(%d%d?%d?)") do
							if tonumber(d) < 256 then bytes[#bytes + 1] = string.char(tonumber(d)) end
						end
						utf8codes(table.concat(bytes), function(cp) found[cp] = rel end)
					end
				end
			end
		end
	end
	ok(files > 80, "read the addon's files, got " .. files)
	ok(found[0xB7], "control: the middle dot is found")
	for cp, rel in pairs(found) do
		for weight, name in pairs(WEIGHTS) do
			local f = shipped()[weight]
			ok(f and f.map[cp], ("U+%04X (in %s) is not in %s"):format(cp, rel, name))
		end
	end
end)

test("d3 a: the width table in Theme/Tokens.lua is the files' own advance widths, 32 to 126, all three weights", function()
	local w, r = rider()
	local Mod = r.W.Mod("Theme.Tokens")
	local tbl = Mod.FONT_W
	ok(type(tbl) == "table", "Mod.FONT_W, the width table")
	local means = 0
	for weight, name in pairs(WEIGHTS) do
		local f = shipped()[weight]
		local row = type(tbl) == "table" and tbl[weight] or {}
		eq(#row, 95, weight .. ": 95 widths")
		if f then
			for cp = 32, 126 do
				eq(row[cp - 31], f.width(cp), ("%s: the width of %q"):format(name, string.char(cp)))
			end
			for cp = 49, 57 do eq(row[cp - 31], row[48 - 31], weight .. ": digits one width in the table") end
			local sum, n = 0, 0
			for cp = 0xDF, 0xFF do
				if cp ~= 0xF7 then sum = sum + f.exact(cp) n = n + 1 end
			end
			means = means + sum / n
		end
	end
	-- one character that isn't plain ASCII: Inter's average small accented letter (U+00DF..00FF, mean of the weights)
	eq(Mod.ACCENT_W, math.floor(means / 3 * 1000 + 0.5), "Mod.ACCENT_W")
	-- and T.MeasureText uses them: a price is as wide as another of the same length
	local Th = r.W.Theme
	eq(Th.MeasureText("111g 11s", "body"), Th.MeasureText("908g 47s", "body"), "prices of the same length are one width")
	ok(math.abs(Th.MeasureText("\195\169", 22, "medium") - Mod.ACCENT_W * 22 / 1000 * 1.03) < 1e-6, "an accented letter measures ACCENT_W")
	T.clean(w)
end)

test("d3 a: the late-font probe knows Inter from Arial Narrow: at once when the game measures Inter, waiting when narrower", function()
	local w, r, Th = rider()
	local wt = Th.FONT_WAIT
	local on = false
	for _, px in ipairs(Th.SCALE) do on = on or px == wt.size end
	ok(on, "the probe's size is one of the seven, got " .. tostring(wt.size))
	-- what Wuber expects for the probe is Inter Regular's real width...
	local want = Th.MeasureText(wt.probe, wt.size, "regular") / 1.03
	local f = shipped().regular
	local real = 0
	for i = 1, #wt.probe do real = real + (f and f.exact(wt.probe:byte(i)) or 0) end
	real = real * wt.size
	ok(math.abs(want - real) <= real * 0.005, ("the probe in Inter Regular: expected %.2f, the file says %.2f"):format(want, real))
	-- ...and Arial Narrow's is far outside the 'near' band (Arial's widths x 0.82, the tools' stand-in)
	local metrics = dofile(ROOT .. "tools/preview/fontmetrics.lua")
	local narrow = 0
	for i = 1, #wt.probe do narrow = narrow + metrics["arialn.ttf"].adv[wt.probe:byte(i)] end
	narrow = narrow * wt.size
	ok(math.abs(real - narrow) > real * wt.near * 4, ("Arial Narrow's %.2f is far from Inter's %.2f"):format(narrow, real))
	-- the game has the font: true at once, nothing waits, nothing fires
	local fired = 0
	r.W.Listen("FONT_READY", function() fired = fired + 1 end)
	eq(Th.WatchFont(), true, "measured as Inter: the font is there")
	w:advance(40)
	eq(fired, 0, "no FONT_READY when it was there from the start")
	-- the game still loads it (the probe measures narrower): waits, then says so once
	w.fontReadyAt = w.time + 10
	eq(Th.WatchFont(), false, "measured narrower: the font is still loading")
	w:advance(5)
	eq(fired, 0, "still waiting")
	w:advance(10)
	eq(fired, 1, "FONT_READY once the probe measures as Inter")
	T.clean(w)
end)
