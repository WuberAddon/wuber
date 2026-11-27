-- Wuber 2.4 fix3 group M, idea 12: the palette's contrast (WCAG 2.x ratio). Every text colour token on every
-- background token it is really drawn on (the table below; found from Theme/Tokens.lua, Theme/Widgets.lua variants
-- and how the cards call T.Text). Main text must reach 7:1, grey / secondary text 4.5:1, coloured status text
-- (gold, violet, amber, red, teal words) 4.5:1 (the brief names two tiers; this third one is the usual AA bar).
-- Today's failures are listed in KNOWN with their measured ratio: a palette change that makes one better or worse,
-- or a new pair that fails, fails here. Colours are the author's taste call: this test never changes one.
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

local NEED = { main = 7, grey = 4.5, colour = 4.5 }
-- { text token, background token, tier, where it is drawn }
local PAIRS = {
	{ "white", "black", "main", "body text on the window" },
	{ "white", "panel", "main", "body text on sheets and panels" },
	{ "white", "card", "main", "card titles and values (most screens)" },
	{ "white", "hover", "main", "a card row under the mouse" },
	{ "white", "raised", "main", "raised chips and toggles" },
	{ "ink", "accent", "colour", "design 1: words and glyphs on a violet fill (a chosen chip, tag or segment)" },
	{ "ink", "glow", "colour", "design 1: the same violet under its second name" },
	{ "ink", "magenta", "colour", "design 1: the same violet under its third name" },
	{ "ink", "gold", "main", "the gold main button's label (Widgets variant primary)" },
	{ "ink", "goldLight", "main", "the gold button under the mouse" },
	{ "ink", "goldPress", "main", "the gold button pressed" },
	{ "muted", "black", "grey", "secondary text on the window" },
	{ "muted", "panel", "grey", "secondary text on sheets" },
	{ "muted", "card", "grey", "secondary text on cards (subtitles, hints)" },
	{ "muted", "hover", "grey", "secondary text on a card under the mouse" },
	{ "muted", "raised", "grey", "secondary text on raised chips (Ride tabs)" },
	{ "offText", "card", "grey", "a disabled button's label (Widgets variant off); design 1: on the new card 211E3B" },
	{ "off", "card", "grey", "paused / closed status words (Driver Draw status table)" },
	{ "off", "black", "grey", "paused / closed status words on the window" },
	{ "gold", "card", "colour", "prices, shard counts, stars" },
	{ "gold", "black", "colour", "prices on the window" },
	{ "accent", "card", "colour", "design 1: violet words and icons on a card (links, what is chosen)" },
	{ "accent", "black", "colour", "design 1: violet words on the window" },
	{ "accent", "panel", "colour", "design 1: violet words on a sheet" },
	{ "glow", "card", "colour", "Open, highlights" },
	{ "glow", "black", "colour", "Open on the window" },
	{ "amber", "card", "colour", "busy, warnings (Forms, Crew, Build)" },
	{ "amber", "black", "colour", "warnings on the window" },
	{ "red", "card", "colour", "errors, danger button label" },
	{ "red", "black", "colour", "errors on the window" },
	{ "teal", "card", "colour", "Pioneer Driver word (Widgets driver badge)" },
	{ "teal", "black", "colour", "Pioneer Driver word on the window" },
}
-- today's pairs under their bar: "text|background" = the ratio measured on 21 Nov 2026 (2 decimals)
local KNOWN = {
}

local function r2(x) return math.floor(x * 100 + 0.5) / 100 end

test("v24 f3m contrast: the palette's text/background pairs reach 7:1 / 4.5:1 except the listed ones", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local C = a.W.Theme.C
	local failing, listed = {}, 0
	for _, p in ipairs(PAIRS) do
		local fg, bg, tier = C[p[1]], C[p[2]], p[3]
		ok(fg and bg, "token exists: " .. p[1] .. " / " .. p[2])
		local r = r2(contrast(fg, bg))
		local key = p[1] .. "|" .. p[2]
		if r < NEED[tier] then
			failing[#failing + 1] = ("%s on %s %.2f (%s needs %s; %s)"):format(p[1], p[2], r, tier, NEED[tier], p[4])
			ok(KNOWN[key] ~= nil, ("NEW failing pair %s on %s: %.2f, %s needs %s (%s)"):format(p[1], p[2], r, tier, NEED[tier], p[4]))
			ok(KNOWN[key] == r, ("%s on %s changed: known %s, now %.2f (update KNOWN only if the author meant it)"):format(p[1], p[2], tostring(KNOWN[key]), r))
		else
			ok(KNOWN[key] == nil, ("%s on %s now passes at %.2f: remove it from KNOWN"):format(p[1], p[2], r))
		end
	end
	for _ in pairs(KNOWN) do listed = listed + 1 end
	eq(#failing, listed, "every KNOWN pair still fails: " .. table.concat(failing, " / "))
	if os.getenv("WUBER_CONTRAST_LIST") then for _, l in ipairs(failing) do print(l) end end
end)
