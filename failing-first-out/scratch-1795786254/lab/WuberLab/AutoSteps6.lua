-- Wuber Lab (developer only, never ship): AutoSteps6.lua, the Auto check screen "a_ruler" (the text ruler, job 2630 item 03; job 2609b).
-- Measures real text widths, line counts and cuts for Wuber's own strings in each font. Read-only, nothing sent. Needs a full game restart (new file).
-- Details of what it does are in the notes below (kept from the draft).
local _, L = ...
local K = L.PhotoKit
local str, num = L.str, L.num
local fn = K.fn
local SCREENS = L.AUTO_SCREENS
local function screen(s)
	s.auto = true
	SCREENS[#SCREENS + 1] = s
	return s
end
local function tourScreen(id)
	for _, s in ipairs(L.PHOTO_SCREENS or {}) do if s.id == id then return s end end
	return nil
end
local function runOf(id)
	return function(W, view)
		local s = tourScreen(id)
		if not s then return "the tour has no screen " .. id end
		return s.run(W, view)
	end
end
local function data()
	local t = K.tour()
	if not t then return {} end
	t.autoData = t.autoData or {}
	return t.autoData
end
local function clock() return L.Now() end
local function result(name, status, detail, step)
	return { name = name, status = status, detail = detail, steps = step and { step } or nil }
end
local function one(...) return { result(...) } end

local RULER = {
	WIDTHS = { 80, 160, 320 },
	PROBE = "uruuru uruuru", PSIZE = 22, NEAR = 0.04,
	WAIT_MAX = 40,   -- seconds to wait for Inter, then measure anyway and say loaded = false
	EVERY = 0.25,    -- seconds between two readings of a probe
	STABLE = 0.5,    -- two equal readings this far apart: a game font is there
	BUDGET = 30,     -- measurements (one string in one font, all its modes) per poll
}
local MODES = { { name = "wrap", wrap = true, max = 0 }, { name = "max1", wrap = true, max = 1 }, { name = "nowrap", wrap = false, max = 0 } }

-- the strings: id, text, core (every font), nsw (long single word: also the two NonSpaceWrap settings), src (where it is from)
local STRINGS = {
	{ "s01", "Nobody summons to Feathermoon Stronghold right now", true, false, "UI/Rider/Home.lua:1145, cut in game (picture 231616)" },
	{ "s02", "every 15 min", true, false, "Theme/Widgets.lua:886, IsTruncated on 16 Driving screens" },
	{ "s03", "Accepted", true, false, "UI/Phone.lua:391, Ride.lua:65 (rings 3 units off)" },
	{ "s04", "Invite", true, false, "UI/Rider/Ride.lua:65" },
	{ "s05", "Arrived", true, false, "UI/Rider/Ride.lua:65" },
	{ "s06", "Pay", true, false, "UI/Rider/Ride.lua:65" },
	{ "s07", "Feathermoon Stronghold", true, false, "Core/Places.lua:68, drawn smaller in game" },
	{ "s08", "uruuru uruuru", true, false, "Theme/Tokens.lua:248, the WatchFont probe" },
	{ "s09", "iiiiiiiiii", true, false, "narrowest letter x10" },
	{ "s10", "WWWWWWWWWW", true, false, "widest letter x10" },
	{ "s11", "0123456789", true, false, "the ten digits" },
	{ "s12", "Orgrimmar", true, false, "cut at 'Orgrim' in game" },
	{ "s13", "Portal", false, false, "UI/Rider/Ride.lua:65" },
	{ "s14", "Finding a driver", false, false, "UI/Phone.lua:391" },
	{ "s15", "Invited", false, false, "UI/Phone.lua:391" },
	{ "s16", "Summoning", false, false, "UI/Phone.lua:392" },
	{ "s17", "Portal open", false, false, "UI/Phone.lua:392" },
	{ "s18", "Share after combat", false, false, "UI/Share.lua pill (HUNT-129)" },
	{ "s19", "Tell the guild", false, false, "pill label" },
	{ "s20", "Ask or search: how do I mute sounds?", false, false, "AutoSteps3.lua SEARCH_TEXTS (the longest of three)" },
	{ "s21", "Valley of Strength", false, false, "a sub-zone name" },
	{ "s22", "Thunder Bluff", false, false, "a zone name with a space" },
	{ "s23", "17:00\226\128\14720:00", false, false, "an en dash; cut at '20:' in a shot" },
	{ "s24", "Nobody summons yet: tap Warlocks to pick who summons", false, false, "UI/Driver/Raid.lua:138" },
	{ "s25", "Opening also posts one advert line in public chat. At most once every 15 minutes. Never in combat, never without your click. Change the words in Messages.", false, false, "UI/Settings/Panel.lua:325 (154 characters)" },
	{ "s26", "Riders pinned a bounty for this place: nobody summons there right now. A bounty is a wish, not a payment: they still pay your fare. Ok.", false, false, "UI/Driver/Demand.lua:144 plus ' Ok.' = exactly 135 characters (the AUD-109 alert)" },
	{ "s27", "Flying is 49c cheaper, about 3 minutes faster", false, false, "the shape of the Confirm line cut as 'Flying is 49c 50c cheaper, about 3...'" },
	{ "s28", "Copy this (Select all, Ctrl+C) and paste it in the comments on Wuber's CurseForge page. Nothing is sent; players' names are left out.", false, false, "UI/Bug.lua:34 (133 characters)" },
	{ "s29", "abcdefghijklmnopqrstuvwxyzabcdefghijklmn", false, true, "a 40-letter word, no spaces" },
	{ "s30", "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW", false, true, "40 wide letters, no spaces" },
	{ "s31", "iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii", false, true, "40 narrow letters, no spaces" },
	{ "s32", "well-known-long-hyphenated-words-in-a-row", false, true, "hyphens, no spaces (does the game break at a hyphen?)" },
	{ "s33", "Thunder/Orgrimmar/Undercity/Stormwind/Ironforge", false, true, "slashes, no spaces" },
	{ "s34", "1111111111", false, false, "digits: narrow one" },
	{ "s35", "8888888888", false, false, "digits: wide eight (Inter's digits are equal width, the game fonts' may not be)" },
	{ "s36", "1,234,567g 89s 12c", false, false, "money" },
	{ "s37", "12:34:56", false, false, "a clock" },
	{ "s38", "100%", false, false, "a percent sign" },
	{ "s39", "49c", false, false, "the smallest price" },
	{ "s40", "3 min 20 s", false, false, "a duration" },
	{ "s41", ".,;:!?'\"-_()[]{}", false, false, "punctuation" },
	{ "s42", "...", false, false, "the cut marker itself" },
	{ "s43", "@#$%&*+=<>~^/\\", false, false, "symbols" },
	{ "s44", "Caf\195\169 M\195\188nster \195\133ngstr\195\182m", false, false, "accented letters (UTF-8: Cafe, Muenster, Angstroem)" },
	{ "s45", "\195\156ber Stra\195\159e \195\177and\195\186", false, false, "umlaut, sharp s, enye" },
	{ "s46", "\195\160\195\169\195\174\195\181\195\188\195\167\195\177 \195\128\195\137\195\142\195\149\195\156\195\135\195\145", false, false, "lower and upper accented letters (Theme.ACCENT_W assumes 561 for each)" },
	{ "s47", "a  b", false, false, "two spaces" },
	{ "s48", " leading and trailing ", false, false, "spaces at the ends" },
	{ "s49", "a b c d e f g h i j k l m n o p", false, false, "many one-letter words" },
	{ "s50", "|cff33e0ccWuber|r Pioneer", false, false, "colour codes (not drawn, so not measured)" },
	{ "s51", "|TInterface\\Icons\\INV_Misc_QuestionMark:12|t Icon", false, false, "a texture escape (the fake counts it as 'WW')" },
	{ "s52", "first line|nsecond line", false, false, "the |n escape" },
	{ "s53", "first line\nsecond line", false, false, "a real newline" },
	{ "s54", "The quick brown fox jumps over the lazy dog", false, false, "a pangram" },
	{ "s55", "Pack my box with five dozen liquor jugs", false, false, "another" },
	{ "s56", "Opening also posts one advert line in public chat. At most once every 15 minutes. Copy this (Select all, Ctrl+C) and paste it in the comments on Wuber's CurseForge page. Nothing is sent; players' names are left out.", false, false, "a 215-character paragraph" },
	{ "s57", "", false, false, "empty" },
	{ "s58", " ", false, false, "one space" },
	{ "s59", "WuberNet Wuber Rocks", false, false, "mixed case" },
	{ "s60", "Name-Realm Name-Realm Name-Realm", false, false, "the shape of a full character name, three times" },
	{ "s61", "AVAVAVAVAV", false, false, "kerning pairs: is a pair narrower than the two letters' advances?" },
	{ "s62", "LTLTLTLTLT", false, false, "more kerning pairs" },
}

-- one guarded game call: a number (3 decimals), a boolean, a short string, or a tag saying why there is no answer
local function pack(...) return { n = select("#", ...), ... } end
local function norm(v)
	if L.IsSecret and L.IsSecret(v) then return "secret" end
	if type(v) == "number" then
		if v ~= v then return "nan" end
		return math.floor(v * 1000 + 0.5) / 1000
	end
	if type(v) == "boolean" then return v end
	if type(v) == "string" then return v:sub(1, 60) end
	return type(v)
end
local function ask(obj, name, ...)
	if type(obj) ~= "table" then return "no object" end
	local f = obj[name]
	if type(f) ~= "function" then return "no such call" end
	local r = pack(pcall(f, obj, ...))
	if not r[1] then return "error: " .. tostring(r[2]):sub(1, 60) end
	if r.n == 1 then return "nothing" end
	return norm(r[2])
end
local function call(obj, name, ...) pcall(function(...) return obj[name](obj, ...) end, ...) end

local function fontList(W)
	local T = type(W.Theme) == "table" and W.Theme or {}
	local files = type(T.FONTS) == "table" and T.FONTS or {}
	local scale = type(T.SCALE) == "table" and T.SCALE or { 11, 12, 14, 17, 22, 28, 40 }
	local media = "Interface\\AddOns\\Wuber\\Media\\fonts\\"
	local inter = { regular = files.regular or media .. "Inter-Regular.ttf", medium = files.medium or media .. "Inter-Medium.ttf", bold = files.bold or media .. "Inter-Bold.ttf" }
	local list = {}
	local function add(key, file, size, full, obj) list[#list + 1] = { key = key, file = file, size = size, full = full, obj = obj } end
	for _, weight in ipairs({ "regular", "medium", "bold" }) do
		for _, px in ipairs(scale) do
			add(("inter-%s-%d"):format(weight, px), inter[weight], px,
				(weight == "regular" and px == 12) or (weight == "medium" and px == 14) or (weight == "bold" and px == 22))
		end
	end
	local arial = type(T.FONT) == "string" and T.FONT or "Fonts\\ARIALN.TTF"
	for _, px in ipairs(scale) do
		local size = math.floor(px * 1.12 + 0.5) -- what Theme.SetFont gives Arial Narrow (Tokens.lua:326)
		add("arialn-" .. size, arial, size, px == 12)
	end
	for _, name in ipairs({ "GameFontNormal", "GameFontNormalSmall", "GameFontNormalLarge", "GameFontNormalHuge" }) do
		add("obj-" .. name, nil, nil, name == "GameFontNormal", name)
	end
	return list, inter, arial
end

local function rulerInit(W)
	local d = { phase = "wait", t0 = clock(), fs = {}, rows = {}, jobs = {}, tags = {}, probes = {} }
	local okH, host = pcall(CreateFrame, "Frame", nil, UIParent)
	if not okH or type(host) ~= "table" then d.phase, d.err = "done", "no frame could be made" return d end
	pcall(host.Hide, host)
	d.host = host
	local fonts, inter, arial = fontList(W)
	d.fonts = fonts
	-- the probes: each distinct font file once, at the probe size
	local T = type(W.Theme) == "table" and W.Theme or {}
	local function expected(weight)
		if type(T.MeasureText) ~= "function" then return weight == "regular" and 143.3 or nil end
		local okM, v = pcall(T.MeasureText, RULER.PROBE, RULER.PSIZE, weight)
		return okM and num(v) and (v / 1.03) or (weight == "regular" and 143.3 or nil)
	end
	local list = {
		{ key = "inter-regular", file = inter.regular, want = expected("regular") },
		{ key = "inter-medium", file = inter.medium, want = expected("medium") },
		{ key = "inter-bold", file = inter.bold, want = expected("bold") },
		{ key = "arialn", file = arial },
		{ key = "frizqt", file = "Fonts\\FRIZQT__.TTF" },
	}
	for _, p in ipairs(list) do
		local okF, f = pcall(host.CreateFontString, host, nil, "OVERLAY")
		p.fs, p.hist = okF and type(f) == "table" and f or nil, {}
		if p.fs then p.sf = ask(p.fs, "SetFont", p.file, RULER.PSIZE, "") end
		d.probes[#d.probes + 1] = p
	end
	for _, cfg in ipairs(fonts) do
		for _, s in ipairs(STRINGS) do
			if cfg.full or s[3] then d.jobs[#d.jobs + 1] = { cfg = cfg, s = s } end
		end
	end
	d.next, d.glyphAt = 1, 1
	d.glyphs = {}
	return d
end

-- a probe reading: SetText("") then the words, as WatchFont does (Tokens.lua:260-263)
local function probeRead(p, t)
	if not p.fs then return nil end
	local last = p.hist[#p.hist]
	if last and t - last.t < RULER.EVERY then return last.w end
	call(p.fs, "SetText", "")
	call(p.fs, "SetText", RULER.PROBE)
	local w = ask(p.fs, "GetStringWidth")
	w = type(w) == "number" and w or nil
	p.hist[#p.hist + 1] = { t = t, w = w }
	return w
end
local function probeLoaded(p)
	local n = #p.hist
	if n == 0 then return false end
	local w = p.hist[n].w
	if not w or w <= 0 then return false end
	if p.want then return math.abs(w - p.want) <= p.want * RULER.NEAR end
	-- a game font: the same width in two readings at least STABLE apart
	for i = n - 1, 1, -1 do
		local h = p.hist[i]
		if p.hist[n].t - h.t >= RULER.STABLE then return h.w ~= nil and math.abs(h.w - w) < 0.01 end
	end
	return false
end

local function fsFor(d, cfg, variant)
	local key = cfg.key .. (variant or "")
	if d.fs[key] then return d.fs[key] end
	local okF, f = pcall(d.host.CreateFontString, d.host, nil, "OVERLAY")
	if not okF or type(f) ~= "table" then return nil end
	if cfg.obj then
		local o = rawget(_G, cfg.obj)
		if type(o) ~= "table" then cfg.missing = true return nil end
		call(f, "SetFontObject", o)
		if not cfg.gf then
			local okG, file, size, flags = pcall(f.GetFont, f)
			cfg.gf = okG and { norm(file), norm(size), norm(flags) } or nil
		end
	else
		local ret = ask(f, "SetFont", cfg.file, cfg.size, "")
		if cfg.sf == nil then cfg.sf = ret end -- what SetFont returns for this file (true / false / nothing)
		if not cfg.gf then
			local okG, file, size, flags = pcall(f.GetFont, f)
			cfg.gf = okG and { norm(file), norm(size), norm(flags) } or nil
		end
	end
	if variant == "nsw0" then call(f, "SetNonSpaceWrap", false) elseif variant == "nsw1" then call(f, "SetNonSpaceWrap", true) end
	d.fs[key] = f
	return f
end

local function setMode(f, width, wrap, max)
	call(f, "SetWidth", width)
	call(f, "SetWordWrap", wrap)
	call(f, "SetMaxLines", max)
end
local function setText(f, text)
	call(f, "SetText", "")
	call(f, "SetText", text)
end
local function tag(d, v)
	if type(v) == "string" then d.tags[v] = (d.tags[v] or 0) + 1 end
	return v
end

local function measure(d, job)
	local cfg, s = job.cfg, job.s
	local f = fsFor(d, cfg)
	if not f then return nil end
	local row = { f = cfg.key, s = s[1] }
	setMode(f, 0, true, 0)
	setText(f, s[2])
	row.w = tag(d, ask(f, "GetStringWidth"))
	row.uw = tag(d, ask(f, "GetUnboundedStringWidth"))
	row.h = tag(d, ask(f, "GetStringHeight"))
	row.lh = tag(d, ask(f, "GetLineHeight"))
	row.n = tag(d, ask(f, "GetNumLines"))
	if cfg.full then
		row.m = {}
		for _, mode in ipairs(MODES) do
			for _, width in ipairs(RULER.WIDTHS) do
				setMode(f, width, mode.wrap, mode.max)
				setText(f, s[2])
				row.m[mode.name .. "@" .. width] = { tag(d, ask(f, "GetNumLines")), tag(d, ask(f, "GetStringHeight")), tag(d, ask(f, "GetWrappedWidth")),
					tag(d, ask(f, "GetStringWidth")), tag(d, ask(f, "IsTruncated")) }
			end
		end
		setMode(f, 0, true, 0)
		if s[4] then
			for _, variant in ipairs({ "nsw0", "nsw1" }) do
				local g = fsFor(d, cfg, variant)
				if g then
					for _, width in ipairs(RULER.WIDTHS) do
						setMode(g, width, true, 0)
						setText(g, s[2])
						row.m[variant .. "wrap@" .. width] = { tag(d, ask(g, "GetNumLines")), tag(d, ask(g, "GetStringHeight")), tag(d, ask(g, "GetWrappedWidth")),
							tag(d, ask(g, "GetStringWidth")), tag(d, ask(g, "IsTruncated")) }
					end
				end
			end
		end
	end
	return row
end

-- the glyph table: one advance per character at size 100 (so whole-pixel rounding is under 1 percent), per font FILE, for
-- ASCII 32..126 and the Latin-1 letters U+00C0..00FF (sent as UTF-8). A space is read as width("." .. " " .. ".") - width("..").
-- This is what lets the fake game build a per-font advance table for the two game fonts, whose files are not on this PC.
local GLYPH_SIZE = 100
local function glyphChars()
	local list = {}
	for cp = 32, 126 do list[#list + 1] = { cp, string.char(cp) } end
	for cp = 192, 255 do list[#list + 1] = { cp, string.char(195, cp - 192 + 128) } end
	return list
end
local GLYPHS = glyphChars()
local function glyphStep(d)
	for _ = 1, 80 do
		local p = d.probes[d.glyphP or 1]
		if not p then return true end
		local g = GLYPHS[d.glyphAt]
		if not g then
			d.glyphP, d.glyphAt = (d.glyphP or 1) + 1, 1
		else
			if not p.gfs then
				local okF, f = pcall(d.host.CreateFontString, d.host, nil, "OVERLAY")
				if okF and type(f) == "table" then
					p.gfs = f
					call(f, "SetFont", p.file, GLYPH_SIZE, "")
					call(f, "SetWidth", 0)
					call(f, "SetWordWrap", false)
				end
			end
			d.glyphs[p.key] = d.glyphs[p.key] or {}
			if p.gfs then
				local text = g[1] == 32 and ". ." or g[2]
				setText(p.gfs, text)
				local w = ask(p.gfs, "GetUnboundedStringWidth")
				if g[1] == 32 then
					setText(p.gfs, "..")
					local base = ask(p.gfs, "GetUnboundedStringWidth")
					w = (type(w) == "number" and type(base) == "number") and (math.floor((w - base) * 1000 + 0.5) / 1000) or w
				end
				d.glyphs[p.key][g[1]] = tag(d, w)
			end
			d.glyphAt = d.glyphAt + 1
		end
	end
	return false
end

local function rulerSave(d, W)
	local meta = { when = L.Epoch and math.floor(L.Epoch()) or 0, loadedWithin = d.loadedAt, widths = RULER.WIDTHS, jobs = #d.jobs, rows = #d.rows }
	local okB, version, build, date, toc = pcall(GetBuildInfo)
	if okB then meta.version, meta.build, meta.date, meta.toc = norm(version), norm(build), norm(date), norm(toc) end
	local okL, loc = pcall(GetLocale)
	meta.locale = okL and norm(loc) or nil
	if type(UIParent) == "table" then
		meta.uiEffScale = ask(UIParent, "GetEffectiveScale")
		meta.uiW, meta.uiH = ask(UIParent, "GetWidth"), ask(UIParent, "GetHeight")
	end
	local okP, pw, ph = pcall(GetPhysicalScreenSize)
	if okP then meta.physW, meta.physH = norm(pw), norm(ph) end
	local okC1, ui = pcall(GetCVar, "uiScale")
	local okC2, use = pcall(GetCVar, "useUiScale")
	meta.cvarUiScale, meta.cvarUseUiScale = okC1 and norm(ui) or nil, okC2 and norm(use) or nil
	local fonts, strings = {}, {}
	for _, cfg in ipairs(d.fonts) do
		fonts[cfg.key] = { file = cfg.gf and cfg.gf[1] or cfg.file, size = cfg.gf and cfg.gf[2] or cfg.size, flags = cfg.gf and cfg.gf[3] or "",
			setFont = cfg.sf, obj = cfg.obj, full = cfg.full, missing = cfg.missing }
	end
	for _, s in ipairs(STRINGS) do strings[s[1]] = { text = s[2], core = s[3], nsw = s[4], src = s[5] } end
	local probes = {}
	for _, p in ipairs(d.probes) do
		local first, last = p.hist[1], p.hist[#p.hist]
		probes[p.key] = { first = first and first.w, last = last and last.w, want = p.want, readings = #p.hist, loaded = d.loadedFinal[p.key] == true, setFont = p.sf }
	end
	local a = { meta = meta, fonts = fonts, strings = strings, probes = probes, rows = d.rows, glyphs = d.glyphs, glyphSize = GLYPH_SIZE, missing = d.tags }
	local line = ("%d rows, %d fonts, %d strings; Inter %s after %.1f s"):format(#d.rows, #d.fonts, #STRINGS, d.interLoaded and "loaded" or "NOT loaded", d.loadedAt or -1)
	local G = L.GameFacts
	if type(G) == "table" and type(G.Put) == "function" then pcall(G.Put, "RULER", line, a, true) end
	return line
end

-- ready(): polled about every 0.1 s by the tour; true when everything is measured and saved
local function rulerStep(W)
	local d = data().ruler
	if not d then
		d = rulerInit(W)
		data().ruler = d
	end
	if d.phase == "done" then return true end
	local t = clock()
	if d.phase == "wait" then
		local all, inter = true, true
		for _, p in ipairs(d.probes) do
			probeRead(p, t)
			if not probeLoaded(p) then
				all = false
				if p.key:sub(1, 5) == "inter" then inter = false end
			end
		end
		if not all and t - d.t0 < RULER.WAIT_MAX then return false end
		d.loadedAt, d.interLoaded, d.phase = t - d.t0, inter, "run"
		local words = {}
		for _, p in ipairs(d.probes) do
			local first = p.hist[1]
			words[#words + 1] = ("%s first %s now %s want %s"):format(p.key, tostring(first and first.w), tostring(p.hist[#p.hist].w), tostring(p.want))
		end
		L.Log("auto", ("ruler: fonts %s after %.1f s (%s)"):format(all and "loaded" or "NOT all loaded", t - d.t0, table.concat(words, "; ")))
		return false
	end
	if d.phase == "run" then
		for _ = 1, RULER.BUDGET do
			local job = d.jobs[d.next]
			if not job then d.phase = "glyphs" break end
			d.next = d.next + 1
			local okM, row = pcall(measure, d, job)
			if okM and row then d.rows[#d.rows + 1] = row end
		end
		return false
	end
	if d.phase == "glyphs" then
		if glyphStep(d) then d.phase = "after" end
		return false
	end
	-- "after": read every probe once more (a font that moved during the run is not loaded), save, done
	d.loadedFinal = {}
	for _, p in ipairs(d.probes) do
		local before = p.hist[#p.hist].w
		local now = clock()
		-- a fresh reading regardless of EVERY
		call(p.fs, "SetText", "")
		call(p.fs, "SetText", RULER.PROBE)
		local w = ask(p.fs, "GetStringWidth")
		p.hist[#p.hist + 1] = { t = now, w = type(w) == "number" and w or nil }
		d.loadedFinal[p.key] = (probeLoaded(p) and type(w) == "number" and before ~= nil and math.abs(w - before) < 0.01) == true
	end
	d.summary = rulerSave(d, W)
	L.Log("auto", "ruler: saved " .. d.summary)
	d.phase = "done"
	return true
end

screen({ id = "a_ruler", side = "rider", maxWait = 60, wait = 0.3,
	title = "Text ruler: the game measures, wraps and cuts 60 strings in Wuber's fonts (for the fake game's text rules; nothing to do)",
	run = runOf("home"),
	ready = function(W) return rulerStep(W) end,
	verify = function(W)
		local d = data().ruler
		if not d then return "skip", "the ruler did not start" end
		if d.err then return one("ruler", "skip", d.err) end
		local out = {}
		if d.phase ~= "done" then
			-- maxWait ran out: save what there is, say so
			d.loadedFinal = d.loadedFinal or {}
			if d.rows and #d.rows > 0 and d.fonts then d.summary = rulerSave(d, W) end
			return one("ruler rows", "look", ("fail: the ruler did not finish (phase %s, %d of %d measurements); partial rows saved"):format(tostring(d.phase), #d.rows, #d.jobs))
		end
		local bad = {}
		for _, p in ipairs(d.probes) do
			if not d.loadedFinal[p.key] then bad[#bad + 1] = p.key end
		end
		if #bad == 0 then
			out[#out + 1] = result("ruler fonts loaded", "pass", ("all five font files measured stable after %.1f s"):format(d.loadedAt or 0))
		else
			out[#out + 1] = result("ruler fonts loaded", "look", "fail: not stable or not loaded: " .. table.concat(bad, ", ") .. " (their rows are marked loaded = false)")
		end
		local miss = {}
		for k, n in pairs(d.tags) do miss[#miss + 1] = ("%s x%d"):format(k, n) end
		table.sort(miss)
		if #miss == 0 then
			out[#out + 1] = result("ruler calls", "pass", "every method answered a value")
		else
			out[#out + 1] = result("ruler calls", "look", "some methods gave no value (that is an answer, saved): " .. table.concat(miss, "; "))
		end
		-- a sanity check of the capture itself: in any proportional font ten W are wider than ten i (s10 > s09)
		local byKey = {}
		for _, r in ipairs(d.rows) do byKey[r.f .. "/" .. r.s] = r end
		local wrong = {}
		for _, cfg in ipairs(d.fonts) do
			local i, w = byKey[cfg.key .. "/s09"], byKey[cfg.key .. "/s10"]
			if i and w and type(i.uw) == "number" and type(w.uw) == "number" and not (w.uw > i.uw) then wrong[#wrong + 1] = cfg.key end
		end
		if #wrong == 0 then
			out[#out + 1] = result("ruler sanity", "pass", d.summary or "saved")
		else
			out[#out + 1] = result("ruler sanity", "look", "fail: ten W were not wider than ten i in " .. table.concat(wrong, ", ") .. ": the capture is not usable")
		end
		return out
	end })
