-- Tests of Theme.Tokens (round 9, S12: secondary text a notch larger and brighter, in the tokens;
-- disabled button text readable). Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- WCAG contrast of two { r, g, b } colours (0..1)
local function lum(c)
	local function ch(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
	return 0.2126 * ch(c[1]) + 0.7152 * ch(c[2]) + 0.0722 * ch(c[3])
end
local function contrast(a, b)
	local x, y = lum(a), lum(b)
	if x < y then x, y = y, x end
	return (x + 0.05) / (y + 0.05)
end

test("Theme.Tokens: nothing is drawn under 11, sizes on the scale stay as asked, T.READABLE adds nothing (design 3)", function()
	local W, w = T.contract("Theme.Tokens", "tests/theme/tokens_test.lua", {
		["W.Theme"] = "table", ["T.SIZE"] = "table", ["T.C"] = "table", ["T.RGB"] = "function", ["T.Text"] = "function",
		["T.SetFont"] = "function", ["T.MeasureText"] = "function", ["T.Fit"] = "function", ["T.READABLE"] = "table",
		["T.DrawnSize"] = "function", ["T.Card"] = "function",
	})
	local Th = W.Theme
	eq(Th.DrawnSize(9), 11, "9 px is drawn at the floor, 11")
	eq(Th.DrawnSize(10), 11, "10 px is drawn at the floor, 11")
	eq(Th.DrawnSize(11), 11, "11 px as asked")
	eq(Th.DrawnSize("caption"), 11, "caption is 11")
	eq(Th.DrawnSize("small"), 12, "small is sub, 12")
	eq(Th.DrawnSize("sub"), 12, "sub is 12")
	eq(Th.DrawnSize("body"), 14, "body is 14")
	eq(Th.DrawnSize(17), 17, "headings as asked")
	eq(Th.DrawnSize("hero"), 40, "hero is 40")
	ok(type(Th.READABLE) == "table", "T.READABLE is still there")
	eq(Th.READABLE.under, 11, "T.READABLE.under is the floor")
	local env = w.clients[1].env
	local f = env.CreateFrame("Frame", nil, env.UIParent)
	local fs = Th.Text(f, 10, "muted", "LEFT", "regular")
	local _, px = fs:GetFont()
	eq(px, 11, "a 10 px muted label is drawn at 11 (the floor)")
	-- fitting never goes under the floor
	local long = Th.Text(f, "caption", "muted", "LEFT", "regular")
	long:SetWidth(60)
	long:SetText("Gold per open hour, by hour of day, hollow bars are still counting")
	local _, lp = long:GetFont()
	ok(lp >= 11, "a long label never fits by drawing under 11 (got " .. tostring(lp) .. ")")
	-- measuring matches drawing: a 10 px string measures as 11 px text
	ok(math.abs(Th.MeasureText("Hello there", 10) - Th.MeasureText("Hello there", 11)) < 0.01, "measured at the drawn size")
	T.clean(w)
end)

test("Theme.Tokens: secondary text is brighter and a disabled button's label is readable on its card (S12)", function()
	local W, w = T.contract("Theme.Tokens", "tests/theme/tokens_test.lua", {})
	local Th = W.Theme
	local card = Th.C.card
	ok(contrast(Th.C.muted, card) >= 6.5, ("muted on a card: contrast %.2f (want 6.5 or more)"):format(contrast(Th.C.muted, card)))
	ok(lum(Th.C.muted) > lum(Th.Hex("9A93B8")), "muted is brighter than 2.3.0's 9A93B8")
	-- a disabled pill (Pause while closed): its label colour against its fill
	local env = w.clients[1].env
	local b = Th.Pill(env.UIParent, "Pause", "dark", 120, 40)
	b:SetActive(false)
	local r, g, bl = b.label:GetTextColor()
	local c = contrast({ r, g, bl }, card)
	ok(c >= 4.5, ("disabled label on its card: contrast %.2f (want 4.5 or more)"):format(c))
	ok(c < contrast(Th.C.white, card) * 0.6, "still clearly quieter than an active label")
	T.clean(w)
end)
