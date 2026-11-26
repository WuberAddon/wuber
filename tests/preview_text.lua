-- The screen renderer's text rules (tools/preview/textlayout.lua): text measured with the
-- shipped fonts, wrapped and cut with "..." as the game's FontString does; and the fake game keeps
-- its simple text rule in the tests (preview mode is only for tools/preview/tour.lua).
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local TL = dofile(T.dir .. "/../tools/preview/textlayout.lua")
local POP = "Interface\\AddOns\\Wuber\\Media\\fonts\\Inter-Medium.ttf"

test("preview text: the fake game keeps its simple text rule in the tests (no real font metrics)", function()
	eq(H.textMetrics, nil, "H.textMetrics (only tour.lua turns it on)")
end)

test("preview text: real widths from the shipped fonts (an m is wider than an i, size scales)", function()
	local ratios = TL.RATIOS
	TL.RATIOS = { { 1, 1 } } -- (job 2885) the raw table: the measured game ratios (TL.ratio) are pinned in tests/r55/small_text_width_test.lua
	local m, i = TL.width(POP, 12, "m"), TL.width(POP, 12, "i")
	ok(m > 2 * i, "m " .. m .. " vs i " .. i)
	ok(math.abs(TL.width(POP, 24, "Summoners") - 2 * TL.width(POP, 12, "Summoners")) < 0.01, "twice the size, twice as wide")
	ok(math.abs(TL.width(POP, 12, "|cffff0000Dan|r") - TL.width(POP, 12, "Dan")) < 0.01, "colour codes take no room")
	TL.RATIOS = ratios
end)

test("preview text: wraps on spaces, stops at max lines and at the height with '...', cuts a word too long", function()
	local L = TL.layout(POP, 12, "one two three four five six", { width = TL.width(POP, 12, "one two three") + 1 })
	eq(L.lines[1], "one two three", "first line")
	eq(#L.lines, 2, "lines")
	ok(not L.truncated, "nothing cut")
	L = TL.layout(POP, 12, "one two three four five six", { width = TL.width(POP, 12, "one two") + 1, maxLines = 2 })
	eq(#L.lines, 2, "SetMaxLines(2)")
	ok(L.truncated and L.lines[2]:sub(-3) == "...", "the last line ends in ...: " .. L.lines[2])
	L = TL.layout(POP, 12, "one two three four", { width = TL.width(POP, 12, "one two") + 1, height = 13 })
	eq(#L.lines, 1, "one line fits a 13 high string")
	ok(L.truncated, "the rest is cut")
	L = TL.layout(POP, 12, "Summoners", { width = TL.width(POP, 12, "Summo"), wrap = false })
	ok(L.truncated and L.lines[1]:find("%.%.%.$") and TL.width(POP, 12, L.lines[1]) <= TL.width(POP, 12, "Summo") + 0.01,
		"a one-line string too narrow: cut to fit with ...: " .. L.lines[1])
	L = TL.layout(POP, 12, "Pause", { width = 100, wrap = false })
	ok(not L.truncated and L.lines[1] == "Pause", "a short label stays whole")
end)

test("preview text: snapped to whole pixels, a string is as wide as its rounded glyphs", function()
	local saved = { TL.PX, TL.SNAP, TL.SIZE_SNAP }
	TL.PX, TL.SNAP, TL.SIZE_SNAP = 2, "round", "round"
	local ratios = TL.RATIOS
	TL.RATIOS = { { 1, 1 } } -- (job 2885) the measured ratio (about 1.05) is applied on top of the rounded glyphs; this test is about the rounding
	local w = TL.width(POP, 10, "{price}", 1.15) -- drawn at 23 px
	local px = w * 2 * 1.15
	ok(math.abs(px - math.floor(px + 0.5)) < 0.001, "a whole number of pixels: " .. px)
	TL.PX, TL.SNAP, TL.SIZE_SNAP = saved[1], saved[2], saved[3]
	ok(math.abs(TL.width(POP, 10, "{price}") - TL.width(POP, 10, "{price}", 1.15)) < 0.001, "unsnapped: the scale changes nothing")
	TL.RATIOS = ratios
end)
