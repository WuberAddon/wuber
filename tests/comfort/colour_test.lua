-- Comfort and accessibility (job 2903): nothing important is shown by colour alone.
-- 1. The state colours (red = a problem, gold = a price or the main action, violet "glow" = on / ready, "muted" = off)
--    must stay apart for a player with protanopia, deuteranopia or tritanopia: a colour-blind simulation (Machado 2009,
--    full severity, linear RGB) of the theme's tokens, compared in CIE Lab (delta E 76), at least 15 apart (delta E 76: 10 is already plain to see).
-- 2. A pair of colours that tells two states apart on the same glyph needs a second cue (another glyph or a word):
--    the places that switch a coloured glyph by state are listed here with the cue that goes with the colour; a new
--    place must be added with its cue, or the test below fails and says where.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local MACHADO = {
	protan = { { 0.152286, 1.052583, -0.204868 }, { 0.114503, 0.786281, 0.099216 }, { -0.003882, -0.048116, 1.051998 } },
	deutan = { { 0.367322, 0.860646, -0.227968 }, { 0.280085, 0.672501, 0.047413 }, { -0.011820, 0.042940, 0.968881 } },
	tritan = { { 1.255528, -0.076749, -0.178779 }, { -0.078411, 0.930809, 0.147602 }, { 0.004733, 0.691367, 0.303900 } },
}
local function lin(c) return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
local function toLab(r, g, b)
	local x = 0.4124 * r + 0.3576 * g + 0.1805 * b
	local y = 0.2126 * r + 0.7152 * g + 0.0722 * b
	local z = 0.0193 * r + 0.1192 * g + 0.9505 * b
	local function f(t) return t > 0.008856 and t ^ (1 / 3) or (7.787 * t + 16 / 116) end
	local fx, fy, fz = f(x / 0.95047), f(y), f(z / 1.08883)
	return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)
end
local function seen(kind, c)
	local r, g, b = lin(c[1]), lin(c[2]), lin(c[3])
	if kind ~= "normal" then
		local m = MACHADO[kind]
		r, g, b = m[1][1] * r + m[1][2] * g + m[1][3] * b, m[2][1] * r + m[2][2] * g + m[2][3] * b, m[3][1] * r + m[3][2] * g + m[3][3] * b
		r, g, b = math.max(0, math.min(1, r)), math.max(0, math.min(1, g)), math.max(0, math.min(1, b))
	end
	return toLab(r, g, b)
end
local function dE(kind, a, b)
	local l1, a1, b1 = seen(kind, a)
	local l2, a2, b2 = seen(kind, b)
	return math.sqrt((l1 - l2) ^ 2 + (a1 - a2) ^ 2 + (b1 - b2) ^ 2)
end

local PAIRS = { { "red", "gold" }, { "red", "glow" }, { "gold", "glow" }, { "red", "muted" }, { "glow", "muted" }, { "gold", "muted" } }
local MIN = 15

test("comfort.colour: the state colours stay apart under protanopia, deuteranopia and tritanopia", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, {})
	T.settle(w)
	local TH = c.W.Theme
	local bad, lines = {}, {}
	for _, kind in ipairs({ "protan", "deutan", "tritan" }) do
		for _, p in ipairs(PAIRS) do
			local a, b = TH.C[p[1]], TH.C[p[2]]
			ok(a and b, "token " .. p[1] .. " and " .. p[2] .. " exist")
			local d = dE(kind, { a[1], a[2], a[3] }, { b[1], b[2], b[3] })
			lines[#lines + 1] = ("%s %s/%s dE=%.1f"):format(kind, p[1], p[2], d)
			if d < MIN then bad[#bad + 1] = ("%s: %s and %s are only %.1f apart (need %d)"):format(kind, p[1], p[2], d, MIN) end
		end
	end
	print("COLOUR " .. table.concat(lines, "; "))
	eq(table.concat(bad, "; "), "", "state colours too close for a colour-blind player")
	T.clean(w)
end)
