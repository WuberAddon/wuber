-- #238: the fake game measured size-11 text about 5% narrower than the real game, so the layout check missed text the game cuts.
-- The 2.4.3 run 3 Lab font check measured the game's string widths at regular 11 (two accounts):
--   "abcdefghijklmnopqrstuvwxyz" 162.0 / 163.9, "The quick brown fox jumps over the lazy dog" 250.0 / 253.0,
--   "0123456789" 74.5 / 75.4, "123g 45s" 54.0 / 54.6 (raw Inter table: 153.4, 235.0, 71.3, 51.3).
-- Promise: with the shipped fonts' metrics on (as the layout check has them), a FontString at size 11 answers within 2% of
-- the measured game width; sizes 14 and 22 are drawn at their measured ratio (1.040, 1.042); others are scaled (job 2885).
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local TL = dofile("tools/preview/textlayout.lua")
local function withMetrics(fn)
	local old = H.textMetrics
	H.textMetrics = TL
	local good, err = pcall(fn)
	H.textMetrics = old
	if not good then error(err, 0) end
end

local ROWS = {
	{ "abcdefghijklmnopqrstuvwxyz", 162.0, 163.9 },
	{ "The quick brown fox jumps over the lazy dog", 250.0, 253.0 },
	{ "0123456789", 74.5, 75.4 },
	{ "123g 45s", 54.0, 54.6 },
}

local function rider()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	T.settle(w)
	return w, r, r.W.Theme
end

local function drawn(w, r, Th, size, text)
	local fs = r.env.UIParent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(Th.FONTS.regular, size, "")
	fs:SetWordWrap(false)
	fs:SetText(text)
	w:advance(1) -- past the moment the game answers with Arial Narrow's widths while it loads the font (TL.LOADING)
	return fs:GetStringWidth()
end

test("#238: a regular size 11 string is within 2% of the width the game measured", function()
	local w, r, Th = rider()
	withMetrics(function()
		for _, row in ipairs(ROWS) do
			local got = drawn(w, r, Th, 11, row[1])
			for k = 2, 3 do
				ok(math.abs(got - row[k]) <= row[k] * 0.02, ('"%s" at 11: fake %.1f, game %.1f'):format(row[1]:sub(1, 12), got, row[k]))
			end
		end
	end)
end)

-- (job 2885) the measured ratios at 14 and 22 (medium 14 +4.0%, regular 22 +4.2% on the long sentence), and the scaled sizes
test("#238: sizes 14 and 22 are drawn at the measured ratio over the raw table", function()
	local w, r, Th = rider()
	withMetrics(function()
		for size, ratio in pairs({ [14] = 1.040, [22] = 1.042 }) do
			for _, row in ipairs(ROWS) do
				local raw = Th.MeasureText(row[1], size, "regular") / 1.03
				local got = drawn(w, r, Th, size, row[1])
				ok(math.abs(got - raw * ratio) <= raw * 0.01, ('"%s" at %d: fake %.1f, wanted %.1f'):format(row[1]:sub(1, 12), size, got, raw * ratio))
			end
		end
	end)
end)

test("#238: sizes the Lab did not measure scale with the measured ratio", function()
	eq(TL.ratio(9), 1.06); eq(TL.ratio(11), 1.06); eq(TL.ratio(14), 1.040); eq(TL.ratio(22), 1.042); eq(TL.ratio(40), 1.042)
	ok(TL.ratio(12) < 1.06 and TL.ratio(12) > 1.040, "size 12 lies between the 11 and 14 ratios")
	ok(TL.ratio(18) > 1.040 and TL.ratio(18) < 1.042 + 1e-9, "size 18 lies between the 14 and 22 ratios")
end)
