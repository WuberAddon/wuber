-- (job 2525, group E; lesson L4 / change C10) the layout rule "sheet-edge" (tests/layout/engine.lua E.sheetEdge): with a modal sheet up,
-- its dim reaches up to the header's bottom edge, and every page frame in the window is fully under the dim or fully outside it.
-- Made-up screens as engine_test.lua does: a window with a header zone, a tab bar, a page, and a sheet (a frame with .dim and
-- .card, as T.Sheet makes) whose holder sits on the base's offset (a strip below the header, E1-07) or at the header's bottom edge.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local S = H.state
local root = T.root or (H.root)
local E = assert(loadfile(root .. "/tests/layout/engine.lua"))(H)

local function scene(gap)
	local w = T.newWorld()
	local c = w:addClient("Sheet Edge", { spot = "Orgrimmar", class = "MAGE", addons = {}, allowMissing = true, screenW = 1000, screenH = 800 })
	local env = c.env
	local function frame(parent, l, b, wd, ht, solid)
		local f = env.CreateFrame("Frame", nil, parent or env.UIParent)
		f:SetPoint("BOTTOMLEFT", parent or env.UIParent, "BOTTOMLEFT", l, b)
		f:SetSize(wd, ht)
		S[f].lcTag = "Wuber"
		if solid then
			local t = f:CreateTexture(nil, "BACKGROUND")
			t:SetAllPoints(f)
			t:SetColorTexture(0.1, 0.1, 0.1, 1)
		end
		return f
	end
	local function text(parent, x, y, s)
		local fs = parent:CreateFontString(nil, "OVERLAY")
		fs:SetFont("Fonts\\FRIZQT__.TTF", 12)
		fs:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, y)
		fs:SetText(s)
		return fs
	end
	-- the window 360 x 600 at (100, 100): header zone 56 at the top, tab bar 56 at the bottom
	local win = frame(nil, 100, 100, 360, 600, false)
	local top = frame(win, 0, 544, 360, 56, false)
	local bar = frame(win, 0, 0, 360, 56, true)
	bar:SetFrameLevel(win:GetFrameLevel() + 30)
	-- the page: a card wholly inside the sheet's area, a card in the strip (just under the header), a card in the header zone
	local inCard = frame(win, 16, 200, 328, 60, true)
	text(inCard, 10, 20, "Undercity")
	local stripCard = frame(win, 16, gap > 0 and (544 - gap - 20) or 300, 328, 40, true) -- straddles the dim's top edge when there is a gap
	text(stripCard, 10, 10, "Where to?")
	-- the sheet's holder: the base put it `gap` units below the header's bottom edge (0 = at the edge)
	local holder = frame(win, 0, 56, 360, 544 - 56 - gap, false)
	holder:SetFrameStrata("FULLSCREEN_DIALOG")
	holder:SetFrameLevel(400)
	local sh = frame(holder, 0, 0, 360, 544 - 56 - gap, false)
	sh:SetAllPoints(holder)
	local dim = frame(sh, 0, 0, 360, 544 - 56 - gap, true)
	dim:SetAllPoints(sh)
	dim:SetAlpha(0.5)
	local card = frame(sh, 0, 0, 360, 300, true)
	sh.dim, sh.card = dim, card
	local chrome = { win = win, bar = bar, buttons = {}, own = { top, bar }, head = top }
	return c, chrome
end
local function edges(out)
	local list = {}
	for _, h in ipairs(out) do if h.kind == "sheet-edge" then list[#list + 1] = h end end
	return list
end
local function listing(out)
	local s = {}
	for _, h in ipairs(out) do s[#s + 1] = h.kind .. ": " .. h.what .. " " .. h.detail end
	return table.concat(s, "\n  ")
end

-- guard: the rule lives in tests/layout/engine.lua and topmost.lua (test code, not Wuber/); failed before because E.sheetEdge and E.sheets did not exist
test("lessons e: sheet-edge names the strip the base left under the header (a 48 px gap, E1-07) and the page frame its edge cuts", function()
	local c, chrome = scene(48)
	local out = E.check(c, { chrome = chrome })
	local list = edges(out)
	local strip, cutHit = false, false
	for _, h in ipairs(list) do
		if h.detail:find("the dim starts 48 below the header", 1, true) then strip = true end
		if h.detail:find("cut by the edge of the dim", 1, true) then cutHit = true end
	end
	ok(strip, "the 48 px strip is named\n  " .. listing(out))
	ok(cutHit, "the card in the strip, cut by the dim's top edge, is named\n  " .. listing(out))
end)

-- guard: the rule lives in tests/layout/engine.lua and topmost.lua (test code, not Wuber/); failed before because E.sheetEdge and E.sheets did not exist
test("lessons e: sheet-edge is quiet when the dim reaches the header's bottom edge and the page is whole under it", function()
	local c, chrome = scene(0)
	local out = E.check(c, { chrome = chrome })
	eq(#edges(out), 0, "a full-height dim:\n  " .. listing(out))
end)

-- a button on the page, fully under the dim, with the sheet's card (mouse-taking) over its centre: covered on purpose, not a "covered" problem
local function withButton(dimAlpha)
	local c, chrome = scene(0)
	local env = c.env
	local win = chrome.win
	local btn = env.CreateFrame("Button", nil, win)
	btn:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 20, 120)
	btn:SetSize(120, 30)
	btn:EnableMouse(true)
	S[btn].lcTag = "Wuber"
	local sheetFrame
	for _, f in ipairs(c.widgets) do if S[f] and rawget(f, "dim") then sheetFrame = f end end
	sheetFrame.card:EnableMouse(true)
	sheetFrame.card:SetSize(360, 300) -- reaches over the button
	sheetFrame.dim:SetAlpha(dimAlpha)
	E.chromeOf = function() return chrome end
	local Top = dofile(root .. "/tests/layout/topmost.lua")
	return Top.hits(H, E, c)
end
-- guard: the rule lives in tests/layout/engine.lua and topmost.lua (test code, not Wuber/); failed before because E.sheetEdge and E.sheets did not exist
test("lessons e: a button fully under a modal sheet's dim is not 'covered'; with no dim up it is", function()
	local hits = withButton(0.5)
	eq(#hits, 0, "under the dim: " .. #hits .. " covered")
	hits = withButton(0)
	ok(#hits >= 1, "no dim up (alpha 0): the sheet's card covers the button, so it is reported")
end)
