-- Tests of the Theme Switcher table, tokens, and WCAG contrast across every theme.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function lum(c)
	local function ch(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
	return 0.2126 * ch(c[1]) + 0.7152 * ch(c[2]) + 0.0722 * ch(c[3])
end

local function contrast(a, b)
	local x, y = lum(a), lum(b)
	if x < y then x, y = y, x end
	return (x + 0.05) / (y + 0.05)
end

local REQUIRED_TOKENS = {
	"black", "nightTop", "panel", "card", "hover", "line", "raised", "well",
	"white", "ink", "muted", "accent", "glow", "magenta", "teal",
	"gold", "goldLight", "goldPress", "goldDeep", "amber", "off", "offText", "red", "shadow",
}

test("themeswitcher: theme table has classic default and all required tokens", function()
	local w = T.newWorld()
	local c = T.rider(w, T.ANA)
	T.settle(w)
	local Th = c.W.Theme

	eq(Th.DEFAULT_THEME, "classic", "default theme is classic")
	eq(Th.ThemeId(), "classic", "active theme defaults to classic")
	ok(type(Th.THEME_ORDER) == "table" and #Th.THEME_ORDER >= 4, "at least 4 themes in THEME_ORDER")
	eq(Th.THEME_ORDER[1], "classic", "classic is first in THEME_ORDER")

	for _, id in ipairs(Th.THEME_ORDER) do
		local th = Th.THEMES[id]
		ok(type(th) == "table", id .. ": theme entry exists")
		eq(th.id, id, id .. ": id matches key")
		ok(type(th.name) == "string" and th.name ~= "", id .. ": has display name")
		ok(type(th.desc) == "string" and th.desc ~= "", id .. ": has description")
		ok(type(th.c) == "table", id .. ": has colour table")
		for _, tok in ipairs(REQUIRED_TOKENS) do
			local col = th.c[tok]
			ok(type(col) == "table" and type(col[1]) == "number" and type(col[2]) == "number" and type(col[3]) == "number",
				id .. ": missing or invalid token " .. tok)
		end
	end

	-- Classic matches the original palette values identically
	local classic = Th.THEMES.classic.c
	local orig = {
		black = Th.Hex("0B0B16"), nightTop = Th.Hex("141228"), panel = Th.Hex("181630"),
		card = Th.Hex("211E3B"), white = Th.Hex("F2EEFF"), muted = Th.Hex("ABA5C9"),
		accent = Th.Hex("A974F5"), gold = Th.Hex("F9C53E"), red = Th.Hex("FF5C7A"),
	}
	for k, want in pairs(orig) do
		local got = classic[k]
		ok(math.abs(got[1] - want[1]) < 0.001 and math.abs(got[2] - want[2]) < 0.001 and math.abs(got[3] - want[3]) < 0.001,
			"classic token " .. k .. " matches original palette")
	end

	T.clean(w)
end)

test("themeswitcher: every theme passes WCAG AA contrast (4.5:1+) on all text/surface pairs", function()
	local w = T.newWorld()
	local c = T.rider(w, T.ANA)
	T.settle(w)
	local Th = c.W.Theme

	local pairsToCheck = {
		{ "white", "black", 4.5 }, { "white", "nightTop", 4.5 }, { "white", "panel", 4.5 },
		{ "white", "card", 4.5 }, { "white", "hover", 4.5 }, { "white", "raised", 4.5 }, { "white", "well", 4.5 },
		{ "muted", "black", 4.5 }, { "muted", "panel", 4.5 }, { "muted", "card", 4.5 },
		{ "off", "card", 4.5 }, { "offText", "card", 4.5 },
		{ "ink", "gold", 4.5 }, { "ink", "accent", 4.5 },
		{ "accent", "black", 4.5 }, { "accent", "panel", 4.5 }, { "accent", "card", 4.5 },
		{ "gold", "black", 4.5 }, { "gold", "panel", 4.5 }, { "gold", "card", 4.5 },
		{ "red", "black", 4.5 }, { "red", "panel", 4.5 }, { "red", "card", 4.5 },
	}

	for _, id in ipairs(Th.THEME_ORDER) do
		local col = Th.THEMES[id].c
		for _, pair in ipairs(pairsToCheck) do
			local fg, bg, minRatio = pair[1], pair[2], pair[3]
			local ratio = contrast(col[fg], col[bg])
			ok(ratio >= minRatio, ("%s: %s on %s contrast %.2f < %.1f"):format(id, fg, bg, ratio, minRatio))
		end
	end

	T.clean(w)
end)
