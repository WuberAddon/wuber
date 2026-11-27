-- Wuber 2.4 fix3 group M, idea 3: the layout checker's text stretch (--stretch N): the fake game's text measure
-- (tools/preview/textlayout.lua, TL.STRETCH) makes every glyph advance N percent wider; 1 (the default) changes nothing.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function near(a, b) return math.abs(a - b) < 1e-9 end

test("v24 f3m stretch: TL.STRETCH widens every measured text, default 1 changes nothing", function()
	local TL = dofile("tools/preview/textlayout.lua")
	local path, text = "Interface\\AddOns\\Wuber\\Media\\fonts\\Inter-Regular.ttf", "Whisper me invite for Orgrimmar"
	local w0 = TL.width(path, 13, text)
	ok(w0 > 50, "measured")
	eq(TL.STRETCH, 1, "default stretch is 1")
	TL.STRETCH = 1.3
	ok(near(TL.width(path, 13, text), w0 * 1.3), "30% wider: " .. tostring(TL.width(path, 13, text)) .. " vs " .. w0 * 1.3)
	-- a string that just fitted is cut once stretched
	local L0 = TL.layout(path, 13, text, { width = w0 + 1, wrap = false })
	ok(L0.truncated, "cut at 30% wider")
	TL.STRETCH = 1
	ok(not TL.layout(path, 13, text, { width = w0 + 1, wrap = false }).truncated, "not cut at 1")
	eq(TL.width(path, 13, text), w0, "back to the same width")
end)
