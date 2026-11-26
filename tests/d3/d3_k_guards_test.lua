-- Design round 3, group K, guard 2: the layout sweep's hit kind "type" (tests/layout/type.lua): a text that shows in a
-- Wuber frame at a size that is not one of T.SCALE, or in a file that is not one of T.FONTS.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local S = H.state
local root = T.root or H.root

---------------------------------------------------------------------------
-- the layout rule
---------------------------------------------------------------------------

local Type = assert(loadfile(root .. "/tests/layout/type.lua"))()
local E = assert(loadfile(root .. "/tests/layout/engine.lua"))(H)

local OURS = { sizes = { [11] = true, [12] = true, [14] = true, [17] = true, [22] = true, [28] = true, [40] = true },
	files = { ["fonts\\arialn.ttf"] = true } } -- (stands for the theme's files: the fake game has the game's own)

local function screen()
	local w = T.newWorld()
	local c = w:addClient("Lay Out", { spot = "Orgrimmar", class = "MAGE", addons = {}, allowMissing = true, screenW = 1000, screenH = 800 })
	local win = c.env.CreateFrame("Frame", nil, c.env.UIParent)
	win:SetPoint("BOTTOMLEFT", c.env.UIParent, "BOTTOMLEFT", 100, 100)
	win:SetSize(300, 400)
	S[win].lcTag = "Wuber"
	return c, win
end
local function label(win, y, text, path, size)
	local fs = win:CreateFontString(nil, "OVERLAY")
	fs:SetFont(path, size)
	fs:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 10, y)
	fs:SetText(text)
	return fs
end

test("d3 guard: the type rule hits a label made with a raw SetFont at 13, and is quiet for a scale size in a theme file", function()
	local c, win = screen()
	label(win, 300, "Raw thirteen", "Fonts\\ARIALN.TTF", 13)
	label(win, 200, "On the scale", "Fonts\\ARIALN.TTF", 14)
	label(win, 100, "Other file", "Fonts\\FRIZQT__.TTF", 14)
	local _, _, _, fonts = E.check(c)
	eq(#fonts, 3, "three texts show")
	local hits = Type.judge(fonts, OURS)
	eq(#hits, 2, "two hits")
	for _, h in ipairs(hits) do eq(h.kind, "type", "the kind") end
	ok(hits[1].what:find("Raw thirteen", 1, true) and hits[1].detail:find("13", 1, true), "names the text and the size: " .. hits[1].what .. " / " .. hits[1].detail)
	ok(hits[2].what:find("Other file", 1, true) and hits[2].detail:find("FRIZQT", 1, true), "names the text and the file: " .. hits[2].detail)
end)

test("d3 guard: the type rule is quiet for a T.Text label and hits the same label once SetFont gives it 13", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	T.settle(w)
	local Th = r.W.Theme
	local win = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	win:SetPoint("CENTER", r.env.UIParent, "CENTER", 0, 0)
	win:SetSize(300, 200)
	S[win].lcTag = "Wuber"
	local fs = Th.Text(win, "body", "white", "LEFT", "medium")
	fs:SetPoint("TOPLEFT", win, "TOPLEFT", 10, -10)
	fs:SetText("A theme label")
	local function judge()
		local _, _, _, fonts = E.check(r)
		local mine = {}
		for _, f in ipairs(fonts) do if f.text == "A theme label" then mine[#mine + 1] = f end end
		eq(#mine, 1, "the label shows")
		return Type.judge(mine, Type.allowed(r))
	end
	eq(#judge(), 0, "T.Text: no hit")
	fs:SetFont(Th.FONTS.medium, 13)
	local hits = judge()
	eq(#hits, 1, "a raw 13: one hit")
	ok(hits[1].detail:find("13", 1, true), hits[1].detail)
	fs:SetFont("Fonts\\FRIZQT__.TTF", 14)
	ok(#judge() == 1 and judge()[1].detail:find("FRIZQT", 1, true), "the game's own font file is a hit")
end)

test("d3 guard: the type rule reaches the sweep (run.lua keeps its hits under the kind type, which allow.lua can name)", function()
	local run = assert(io.open(root .. "/tests/layout/run.lua", "rb")):read("*a")
	ok(run:find('tests/layout/type.lua', 1, true) and run:find("TYPE.judge", 1, true), "run.lua judges every shot's fonts")
	eq(#Type.judge({ { text = "No font", path = nil, size = nil } }, OURS), 1, "a text with no font set is a hit")
	eq(#Type.judge({ { text = "x", path = "a", size = 13 } }, nil), 0, "no theme (a made-up screen): nothing to judge")
end)
