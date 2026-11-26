-- Design round 1, group A: the paint helpers. No glows, one flat card, one corner size, pills that are
-- rounded rectangles over 32 high, and three kinds of button (no violet filled button).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function theme()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(2)
	return w, c.W.Theme, c.env
end
local function frame(env, w, h)
	local f = env.CreateFrame("Frame", nil, env.UIParent)
	if w then f:SetSize(w, h) end
	return f
end
local function regions(f) return select("#", f:GetRegions()) end
local function near(a, b) return math.abs(a - b) < 0.01 end
local function corner(slice) return slice.parts.TL:GetWidth() end

test("d1 a: T.OuterGlow and T.EdgeGlow draw nothing and their objects still take the callers' calls", function()
	local w, Th, env = theme()
	local f = frame(env, 200, 80)
	local before = regions(f)
	local g = Th.OuterGlow(f, "gold", 0.5, 18)
	local e = Th.EdgeGlow(f, "magenta", 0.3)
	eq(regions(f), before, "no texture made on the frame")
	for _, o in ipairs({ g, e }) do
		ok(type(o) == "table" and type(o.parts) == "table" and next(o.parts) == nil, "an object with no parts")
		ok(pcall(function()
			o:SetColor("gold", 0.9)
			o:SetColor("accent")
			o:SetAlpha(0.4)
			o:SetShown(true)
			o:SetShown(false)
			o:Show()
			o:Hide()
		end), "SetColor, SetAlpha, SetShown, Show and Hide are safe")
	end
	eq(regions(f), before, "still none after the calls")
	T.clean(w)
end)

test("d1 a: T.Card is one flat fill with corner 14: no shadow, no border, whatever the caller asks", function()
	local w, Th, env = theme()
	local host = frame(env, 400, 400)
	local plain = Th.Card(host, 300, 120)
	local asked = Th.Card(host, 300, 120, { radius = 22, shadow = true, border = "gold", colour = "panel" })
	for name, card in pairs({ plain = plain, asked = asked }) do
		eq(regions(card), 9, name .. ": only the nine parts of the fill")
		eq(corner(card.bg), 14, name .. ": corner 14")
		for _, t in ipairs({ card:GetRegions() }) do
			ok(not tostring(t:GetTextureFilePath() or ""):find("shadow", 1, true), name .. ": no shadow picture")
		end
	end
	eq(asked.bg.colour, "panel", "opts.colour still colours the card")
	eq(plain.bg.colour, "card", "the card colour by default")
	ok(pcall(function()
		plain.shadow:SetColor("shadow")
		plain.shadow:SetShown(false)
		plain.shadow:SetAlpha(0.2)
		asked.border:SetColor("gold")
		asked.border:SetShown(true)
	end), "card.shadow and card.border are safe to call")
	eq(regions(asked), 9, "and they draw nothing")
	ok(Th.Card(host, 10, 10, { shadow = false }).shadow == nil, "shadow = false: no shadow field, as before")
	T.clean(w)
end)

test("d1 a: T.Rounded gives corner 14 for any radius asked, half the height under 28, also when sized later", function()
	local w, Th, env = theme()
	for _, r in ipairs({ 8, 10, 12, 13, 16, 18, 22, 23 }) do
		eq(corner(Th.Rounded(frame(env, 200, 60), "card", r)), 14, "asked " .. r)
	end
	eq(corner(Th.Rounded(frame(env, 200, 60), "card")), 14, "no radius asked")
	eq(corner(Th.Rounded(frame(env, 200, 28), "card", 12)), 14, "28 high: 14")
	eq(corner(Th.Rounded(frame(env, 200, 20), "card", 12)), 10, "20 high: half the height")
	eq(corner(Th.Rounded(frame(env, 200, 6), "card", 12)), 3, "6 high: 3")
	local late = frame(env)
	local s = Th.Rounded(late, "card", 18)
	late:SetSize(200, 20)
	eq(corner(s), 10, "sized later to 20 high: 10")
	late:SetHeight(64)
	eq(corner(s), 14, "and grown to 64: 14")
	eq(corner(Th.Rounded(frame(env, 200, 60), "line", 23, "BACKGROUND", -1, 1)), 15, "an outline 1 outside keeps the same shape: 15")
	-- the handset keeps its own corners: it uses T.NineSlice itself
	eq(Th.NineSlice(frame(env, 200, 60), "rounded", 43, 0.25).parts.TL:GetWidth(), 43, "T.NineSlice keeps the radius it is given")
	T.clean(w)
end)

local function capsShown(fill)
	for _, t in ipairs(fill.parts) do if not t:IsShown() then return false end end
	return true
end

test("d1 a: a pill over 32 high is a rounded rectangle with corner 14; 32 high or less it stays fully round", function()
	local w, Th, env = theme()
	local host = frame(env, 400, 400)
	local tall = Th.Pill(host, "Request", "primary", 300, 46)
	eq(tall.fill.capsule, false, "46 high: not a capsule")
	ok(not capsShown(tall.fill), "its round caps are hidden")
	ok(tall.fill.rect and tall.fill.rect.parts.M:IsShown(), "a rounded rectangle shows")
	eq(tall.fill.rect.parts.TL:GetWidth(), 14, "with corner 14")
	local small = Th.Pill(host, "Share", "dark", 92, 28)
	eq(small.fill.capsule, true, "28 high: a capsule")
	ok(capsShown(small.fill) and small.fill.rect == nil, "the round caps show, no rectangle")
	eq(small.fill.parts[1]:GetWidth(), 14, "caps half the height")
	eq(Th.Pill(host, "x", "dark", 92, 32).fill.capsule, true, "32 high: still a capsule")
	eq(Th.Pill(host, "x", "dark", 92, 34).fill.capsule, false, "34 high: a rounded rectangle")
	-- sized later
	tall:SetHeight(30)
	eq(tall.fill.capsule, true, "the 46 pill made 30 high turns into a capsule")
	ok(capsShown(tall.fill) and not tall.fill.rect.parts.M:IsShown(), "caps shown, rectangle hidden")
	-- hidden stays hidden through a change of shape
	small.fill:SetShown(false)
	small.fill:SetHeight(40)
	ok(not capsShown(small.fill) and not small.fill.rect.parts.M:IsShown(), "a hidden fill stays hidden")
	small.fill:SetShown(true)
	ok(small.fill.rect.parts.M:IsShown() and not capsShown(small.fill), "and shows as the rectangle")
	T.clean(w)
end)

test("d1 a: a pill has no hover glow; the hover and pressed fills stay", function()
	local w, Th, env = theme()
	local b = Th.Pill(frame(env, 400, 400), "Request", "primary", 300, 46)
	local before = regions(b)
	b:GetScript("OnEnter")(b)
	eq(regions(b), before, "no texture made on hover")
	for _, t in ipairs({ b:GetRegions() }) do
		ok(not (t.GetTextureFilePath and tostring(t:GetTextureFilePath() or ""):find("glow", 1, true)), "no glow picture on the pill")
	end
	ok(type(b.glow) == "table" and not b.glow:IsShown(), "b.glow is there and never shown")
	ok(pcall(function() b.glow:SetVertexColor(1, 1, 1, 1) b.glow:Show() b.glow:Hide() end), "b.glow is safe to call")
	eq(b.fill.colour, "goldLight", "the hover fill")
	b:GetScript("OnMouseDown")(b)
	eq(b.fill.colour, "goldPress", "the pressed fill")
	b:GetScript("OnMouseUp")(b)
	b:GetScript("OnLeave")(b)
	eq(b.fill.colour, "gold", "and back")
	T.clean(w)
end)

test("d1 a: three kinds of button: gold main, raised second, link without a fill; no style paints a violet fill", function()
	local w, Th = theme()
	local S = Th.PILL_STYLES
	local function rgba(c) return Th.RGB(c) end
	-- violet as a fill: blue the strongest, green the weakest, well apart, and not see-through
	local function violetFill(c)
		local r, g, b, a = rgba(c)
		return a >= 0.5 and b > r and r > g and b - g > 0.25
	end
	ok(violetFill("accent") and violetFill("glow") and not violetFill("raised") and not violetFill("gold"), "the rule knows violet")
	for name, st in pairs(S) do
		for _, k in ipairs({ "bg", "hover", "press" }) do
			-- "violet" is no kind of button: it is the look of a chosen option (checked below)
			if name ~= "violet" then ok(not violetFill(st[k]), name .. "." .. k .. " is not a violet fill") end
		end
		ok(st.glow == nil, name .. ": no glow colour")
	end
	eq(S.primary.bg, "gold", "main: gold")
	eq(S.primary.text, "ink", "main: ink words")
	eq(S.dark.bg, "raised", "second: the raised card colour")
	eq(S.dark.text, "white", "second: white words")
	local r0, g0, b0 = rgba(S.dark.bg)
	local r1, g1, b1, a1 = rgba(S.dark.hover)
	ok(r1 > r0 and g1 > g0 and b1 > b0 and r1 - r0 < 0.1 and a1 == 1, "second: hover a little lighter")
	eq(S.ghost.text, "glow", "link: violet words")
	eq(select(4, rgba(S.ghost.bg)), 0, "link: no fill")
	local hv, pr = select(4, rgba(S.ghost.hover)), select(4, rgba(S.ghost.press))
	ok(hv > 0 and hv <= 0.2 and pr > hv and pr <= 0.25, "link: a faint fill on hover and press")
	eq(S.danger.text, "red", "destructive link: red words")
	eq(select(4, rgba(S.danger.bg)), 0, "destructive link: no fill")
	eq(S.off.text, "offText", "off stays")
	-- the old name is the look of a chosen option or an on state: the one violet with ink words, never white
	ok(type(S.violet) == "table", "the name violet is still a style")
	eq(S.violet.bg, "accent", "chosen: the one violet")
	eq(S.violet.text, "ink", "chosen: ink words (white on violet is 2.8 to 1)")
	T.clean(w)
end)

test("d1 a: no screen builds a pill in the old violet style", function()
	local found = {}
	local n = 0
	for _, folder in ipairs({ "UI", "UI/Driver", "UI/Rider", "UI/Settings", "UI/Map", "Drive" }) do
		for _, path in ipairs(T.H.listFiles(T.dir .. "/../Wuber/" .. folder, "lua")) do
			n = n + 1
			local src = T.readFile(path) or ""
			if src:find('T%.Pill%([^\n]-,%s*"violet"') then found[#found + 1] = path end
		end
	end
	ok(n > 40, "the screens were read: " .. n)
	eq(table.concat(found, ", "), "", "files that still ask T.Pill for violet")
end)
