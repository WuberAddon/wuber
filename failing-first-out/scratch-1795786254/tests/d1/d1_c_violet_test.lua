-- Wuber design round 1, group C: the colours of the theme's controls. One violet (accent = glow = magenta), flat
-- card colours, words on a violet fill are ink, sliders / bars / chosen segments are violet (not gold), one warning
-- colour (red). Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function hexOf(c)
	return ("%02X%02X%02X"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end
local function same(r, g, b, c) return math.abs(r - c[1]) < 0.01 and math.abs(g - c[2]) < 0.01 and math.abs(b - c[3]) < 0.01 end
local function fillIs(fill, c)
	local r, g, b = fill.parts[1]:GetVertexColor()
	return same(r, g, b, c)
end
local function textIs(fs, c)
	local r, g, b = fs:GetTextColor()
	return same(r, g, b, c)
end

local function theme()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local env = a.env
	local holder = env.CreateFrame("Frame", nil, env.UIParent)
	holder:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
	holder:SetSize(320, 200)
	return a.W.Theme, holder, w
end

test("d1 c: the three violet names are one colour, the cards are the new flat ones, the rest keeps its value", function()
	local Th = theme()
	local C = Th.C
	for _, k in ipairs({ "accent", "glow", "magenta", "open", "green" }) do eq(hexOf(C[k]), "A974F5", k .. " is the one violet") end
	eq(hexOf(C.card), "211E3B", "card")
	eq(hexOf(C.hover), "2A2748", "hover is card2")
	eq(hexOf(C.raised), "2A2748", "raised is card2")
	eq(hexOf(C.panel), "181630", "panel")
	-- off: lifted to 8B83AC on purpose by job 129 (B11)
	local keep = { black = "0B0B16", nightTop = "141228", white = "F2EEFF", muted = "ABA5C9", offText = "8F89AD", off = "8B83AC",
		line = "333154", gold = "F9C53E", goldLight = "FFD866", goldPress = "E0AE2E", ink = "1D1B31", red = "FF5C7A",
		amber = "F9A23E", goldDeep = "B1873F", teal = "33E0CC" }
	for k, v in pairs(keep) do eq(hexOf(C[k]), v, k .. " keeps its value") end
end)

test("d1 c: a chosen segment is violet with ink words (also when a caller asks for white words on violet)", function()
	local Th, holder = theme()
	local C = Th.C
	local s = Th.Segmented(holder, { { value = 1, label = "Week" }, { value = 2, label = "Month" } }, 1, nil, 200, 30)
	local on, rest = s.buttons[1], s.buttons[2]
	ok(fillIs(on.chosen, C.accent), "the chosen part is violet")
	ok(not fillIs(on.chosen, C.gold), "the chosen part is not gold")
	ok(textIs(on.label, C.ink), "the chosen part's words are ink")
	ok(textIs(rest.label, C.muted), "the other part's words are muted")
	s:SetValue(2)
	ok(textIs(rest.label, C.ink) and fillIs(rest.chosen, C.accent), "the newly chosen part is violet with ink words")
	ok(textIs(on.label, C.muted), "the part no longer chosen is muted")
	s.onStyle, s.onText = "violet", "white"
	s:SetValue(1)
	ok(fillIs(on.chosen, C.accent), "style violet: a violet fill")
	ok(textIs(on.label, C.ink), "style violet with white words asked: the words are ink all the same")
end)

test("d1 c: a chosen chip or tag is violet with ink words; at rest it is a card colour with white or muted words", function()
	local Th, holder = theme()
	local C = Th.C
	local tag = Th.Tag(holder, "All", { h = 30 })
	ok(fillIs(tag.fill, C.card) and textIs(tag.label, C.white), "a tag at rest: card, white words")
	tag:SetTag("All", "accent", "white") -- what the Ride home filter chips pass today
	ok(fillIs(tag.fill, C.accent), "chosen: violet")
	ok(textIs(tag.label, C.ink), "chosen: ink words, although white was asked")
	tag:SetTag("All", "card", "muted")
	ok(fillIs(tag.fill, C.card) and textIs(tag.label, C.muted), "back at rest: card, muted words")
	ok(type(tag.SetChosen) == "function", "tag:SetChosen exists")
	tag:SetChosen(true)
	ok(fillIs(tag.fill, C.accent) and textIs(tag.label, C.ink), "SetChosen(true): violet, ink")
	tag:SetChosen(false)
	ok(fillIs(tag.fill, C.card) and textIs(tag.label, C.muted), "SetChosen(false): card, muted")
	local lit = Th.Tag(holder, "Lit", { fill = "glow", text = "white", icon = "clock" })
	ok(textIs(lit.label, C.ink), "a tag made violet: ink words")
	local r, g, b = lit.icon:GetVertexColor()
	ok(same(r, g, b, C.ink), "a tag made violet: an ink glyph")

	local chip = Th.Chip(holder, "Open", "glow")
	ok(fillIs(chip.fill, C.raised), "a chip at rest is flat card2, not a wash of its own colour")
	ok(textIs(chip.label, C.glow), "a status chip keeps its word colour")
	local plain = Th.Chip(holder, "Booty Bay")
	ok(textIs(plain.label, C.white), "a plain chip has white words")
	ok(type(chip.SetChosen) == "function", "chip:SetChosen exists")
	plain:SetChosen(true)
	ok(fillIs(plain.fill, C.accent) and textIs(plain.label, C.ink), "a chosen chip: violet, ink words")
	plain:SetChosen(false)
	ok(fillIs(plain.fill, C.raised) and textIs(plain.label, C.white), "a chip no longer chosen: card2, white words")
end)

test("d1 c: sliders and bars fill violet, the switch is violet when on and card2 when off", function()
	local Th, holder = theme()
	local C = Th.C
	local s = Th.Slider(holder, 260, { min = 0, max = 100, step = 1, value = 30 })
	ok(fillIs(s.fillTex, C.accent), "the slider's fill is violet")
	ok(not fillIs(s.fillTex, C.gold), "the slider's fill is not gold")
	ok(not textIs(s.label, C.gold), "the slider's value is not gold")
	ok(s.halo.nothing == true, "the slider's knob has no halo (design 1: glows off)")
	local bar = Th.Bar(holder, 200, 8)
	ok(fillIs(bar.fillTex, C.accent), "a bar with no colour given is violet")
	local t = Th.Toggle(holder, true)
	ok(fillIs(t.track, C.accent), "a switch that is on is violet")
	t:SetOn(false)
	ok(fillIs(t.track, C.raised), "a switch that is off is card2")
end)

test("d1 c: a badge is grey unless the caller names a colour (gold stays for who asks); the alert card warns in red", function()
	local Th, holder = theme()
	local C = Th.C
	local b = Th.Badge(holder, "No helpers needed")
	ok(textIs(b.label, C.muted), "no colour given: muted words")
	ok(not textIs(b.label, C.gold), "no colour given: not gold")
	local f = Th.Badge(holder, "Founder", "gold")
	ok(textIs(f.label, C.gold), "gold asked (the Founder badge): gold")
	local r, g, bl = f.edge[1]:GetVertexColor()
	ok(same(r, g, bl, C.gold), "gold asked: a gold outline")
	local card = Th.AlertCard(holder, 300, 64)
	ok(textIs(card.head, C.red), "the alert card's head is red")
	ok(textIs(card.mark, C.red), "the alert card's mark is red")
	local rr, rg, rb = card.ring:GetVertexColor()
	ok(same(rr, rg, rb, C.red), "the alert card's ring is red")
	eq(card.edge.colour, "red", "the alert card's edge is red")
end)

-- the body of one function of a theme file: from its "function T.Name(" line to the next line that starts a function
local function bodyOf(src, name)
	local from = src:find("\nfunction T%." .. name .. "%(") or src:find("\nlocal function " .. name .. "%(")
	if not from then return nil end
	local to = src:find("\nfunction ", from + 1, true)
	local to2 = src:find("\nlocal function ", from + 1, true)
	if to2 and (not to or to2 < to) then to = to2 end
	return src:sub(from, (to or #src + 1) - 1)
end

test("d1 c: no control of the theme uses goldDeep, magenta, amber or teal; gold only where a caller asks", function()
	local owned = {
		["Wuber/Theme/Widgets.lua"] = { "Chip", "Badge", "Toggle", "Slider", "segPaint", "Segmented", "Bar" },
		["Wuber/Theme/Forms.lua"] = { "Tag", "AlertCard", "ListButton", "Field", "Sheet" },
	}
	for path, names in pairs(owned) do
		local src = "\n" .. T.readFile(T.dir .. "/../" .. path):gsub("\r", "")
		for _, name in ipairs(names) do
			local body = bodyOf(src, name)
			ok(body, name .. " found in " .. path)
			for _, word in ipairs({ "goldDeep", "magenta", "amber", "teal", "gold" }) do
				ok(not (body or ""):find('"' .. word .. '"', 1, true), ("%s: T.%s does not use \"%s\""):format(path, name, word))
			end
		end
	end
	-- T.C itself: each of the names that left the phone is defined exactly once and never read in Tokens.lua
	local tok = T.readFile(T.dir .. "/../Wuber/Theme/Tokens.lua")
	for _, word in ipairs({ "goldDeep", "amber" }) do
		local n = 0
		for _ in tok:gmatch('"' .. word .. '"') do n = n + 1 end
		eq(n, 0, "Theme/Tokens.lua never names \"" .. word .. "\" as a colour to draw")
	end
end)
