-- Tests of the layout checker's engine (tests/layout/engine.lua, tools/layout-check.lua; BRIEF21 S11) on small
-- made-up screens: each rule fires on its own bad layout and stays quiet on a good one. Run by the suite
-- (tests/run.lua loads it with its helper table T: test, eq, ok, H, newWorld; lua tests/run.lua "layout engine"),
-- or standalone: lua tools/layout-check.lua --selftest
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local S = H.state
local root = T.root or (H.root)
local E = assert(loadfile(root .. "/tests/layout/engine.lua"))(H)

-- a client with no addon; frames made here are marked as Wuber's (the engine checks only Wuber's)
local function screen()
	local w = T.newWorld()
	local c = w:addClient("Lay Out", { spot = "Orgrimmar", class = "MAGE", addons = {}, allowMissing = true, screenW = 1000, screenH = 800 })
	local env = c.env
	local function frame(parent, x, y, wd, ht, solid)
		local f = env.CreateFrame("Frame", nil, parent or env.UIParent)
		f:SetPoint("BOTTOMLEFT", parent or env.UIParent, "BOTTOMLEFT", x, y)
		f:SetSize(wd, ht)
		S[f].lcTag = "Wuber"
		if solid then
			local t = f:CreateTexture(nil, "BACKGROUND")
			t:SetAllPoints(f)
			t:SetColorTexture(0.1, 0.1, 0.1, 1)
		end
		return f
	end
	local function text(parent, x, y, s, wd)
		local fs = parent:CreateFontString(nil, "OVERLAY")
		fs:SetFont("Fonts\\FRIZQT__.TTF", 12)
		fs:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, y)
		if wd then fs:SetWidth(wd) fs:SetWordWrap(false) end
		fs:SetJustifyH("LEFT")
		fs:SetText(s)
		return fs
	end
	return w, c, frame, text
end

local function kinds(out)
	local k = {}
	for _, h in ipairs(out) do k[h.kind] = (k[h.kind] or 0) + 1 end
	return k
end
local function list(out)
	local s = {}
	for _, h in ipairs(out) do s[#s + 1] = h.kind .. ": " .. h.what .. " " .. h.detail end
	return table.concat(s, "\n  ")
end

test("layout engine: a tidy screen has no problems (texts on their card, a pill inside it, nothing off screen)", function()
	local w, c, frame, text = screen()
	local win = frame(nil, 100, 100, 300, 400, true)
	text(win, 10, 370, "Your trips")
	local card = frame(win, 10, 200, 280, 100, true)
	text(card, 10, 70, "Undercity")
	local pill = frame(card, 200, 10, 70, 24, true)
	text(pill, 8, 6, "Go")
	local out = E.check(c)
	eq(#out, 0, "problems:\n  " .. list(out))
end)

test("layout engine: two texts on each other, a text half under a pill drawn above it, a pill half over a card", function()
	local w, c, frame, text = screen()
	local win = frame(nil, 100, 100, 300, 400, true)
	text(win, 10, 300, "Summon Dan now")
	text(win, 30, 302, "Waiting for Eve")
	local row = frame(win, 10, 100, 280, 40, true)
	text(row, 10, 12, "Dan Rider ready")
	local cue = frame(win, 10, 95, 200, 30, true)
	cue:SetFrameLevel(row:GetFrameLevel() + 5)
	text(cue, 10, 8, "+2 more below")
	local k = kinds(E.check(c))
	ok((k.overlap or 0) >= 1, "texts on texts: overlap")
	ok((k.under or 0) >= 1, "the row's text half under the cue: under")
	ok((k.boxes or 0) >= 1, "the cue half over the row: boxes")
end)

test("layout engine: a text cut short ('...'), one cut on purpose (wuberEllipsis), one sliced by its scroll view, one off the screen", function()
	local w, c, frame, text = screen()
	local win = frame(nil, 100, 100, 300, 400, true)
	local long = text(win, 10, 350, "Advertise your summons in every channel", 40)
	local fine = text(win, 10, 320, "A preview of a long message that goes on", 40)
	rawset(fine, "wuberEllipsis", "a preview")
	local view = frame(win, 10, 100, 280, 100, false)
	view:SetClipsChildren(true)
	local inner = frame(view, 0, -6, 280, 300, false)
	text(inner, 10, 0, "2nd ride with you")
	local edge = frame(nil, 950, 700, 120, 40, true)
	text(edge, 10, 10, "Off the edge")
	local out = E.check(c)
	local k = kinds(out)
	eq(k.cut, 1, "one cut (the marked one is not): " .. list(out))
	ok((k.clipped or 0) >= 1, "the row sliced by its view: clipped")
	ok((k.offscreen or 0) >= 1, "off the screen")
end)

-- (BRIEF22 L1) a "Scroll for more" cue under blank space is an empty view; under a drawn card (the heatmap's
-- squares: no text right above the cue) it is not
test("layout engine: a scroll cue under blank space is emptycue; under a drawn card it is not", function()
	for _, card in ipairs({ false, true }) do
		local w, c, frame, text = screen()
		local win = frame(nil, 100, 100, 300, 400, true)
		text(win, 110, 370, "Earnings")
		if card then frame(win, 10, 40, 280, 200, true) end
		text(win, 110, 10, "Scroll for more")
		local k = kinds(E.check(c))
		eq(k.emptycue or 0, card and 0 or 1, (card and "a card right above the cue" or "only blank space above the cue"))
	end
end)

-- (BRIEF22 L6) the portal art's see-through rim (E.ART_RIM): a title 3 units under its box sits beside it; under a
-- solid card's edge it is under
test("layout engine: a text just under the portal art's see-through rim is not under it; under a solid card it is", function()
	for _, art in ipairs({ true, false }) do
		local w, c, frame, text = screen()
		local win = frame(nil, 100, 100, 400, 400, true)
		local title = frame(win, 20, 200, 300, 40, false)
		title:SetFrameLevel(win:GetFrameLevel() + 1)
		text(title, 10, 2, "The portal is up")
		local pic = frame(win, 20, 212, 300, 260, false) -- its rim: 8 units; over the text by about 4
		pic:SetFrameLevel(win:GetFrameLevel() + 5)
		local t = pic:CreateTexture(nil, "ARTWORK")
		t:SetAllPoints(pic)
		if art then t:SetTexture("Interface\\AddOns\\Wuber\\Media\\fx\\portal_loop") else t:SetColorTexture(0.2, 0.1, 0.3, 1) end
		local k = kinds(E.check(c))
		eq((k.under or 0) > 0, not art, art and "the portal's rim: not under" or "a solid card: under")
	end
end)

test("layout engine: a page hidden whole under another page drawn above it is not on screen (no overlap with it)", function()
	local w, c, frame, text = screen()
	local win = frame(nil, 100, 100, 300, 400, true)
	local page1 = frame(win, 0, 0, 300, 400, true)
	text(page1, 10, 300, "Drive tab")
	local page2 = frame(win, 0, 0, 300, 400, true)
	page2:SetFrameLevel(page1:GetFrameLevel() + 10)
	text(page2, 10, 300, "Messages")
	local out = E.check(c)
	eq(#out, 0, "problems:\n  " .. list(out))
end)

test("layout engine: two of Wuber's windows on each other count once (windows), and a tooltip off the screen is found", function()
	local w, c, frame, text = screen()
	local a = frame(nil, 100, 100, 300, 400, true)
	text(a, 10, 300, "Phone")
	local b = frame(nil, 300, 300, 300, 100, true)
	b:SetFrameLevel(a:GetFrameLevel() + 20)
	text(b, 10, 10, "Big button")
	local tipOwner = frame(nil, 900, 400, 90, 20, true)
	local tt = c.env.GameTooltip
	tt:SetOwner(tipOwner, "ANCHOR_RIGHT")
	tt:AddLine("A tip that opens to the right of a button at the edge")
	tt:Show()
	local out = E.check(c)
	local k = kinds(out)
	eq(k.windows, 1, "one windows problem: " .. list(out))
	eq(k.tooltip, 1, "the tooltip off the screen")
	tt:Hide()
end)

test("layout engine: chrome (design 2) - page content in the place of a header button or of the tab bar is a problem; clear of them it is not", function()
	local w, c, frame, text = screen()
	local win = frame(nil, 100, 100, 360, 600, true)
	local bar = frame(win, 0, 0, 360, 56, true)
	bar:SetFrameLevel(win:GetFrameLevel() + 30)
	text(bar, 40, 8, "Ride")
	local x = frame(win, 312, 556, 32, 32, true)
	x:SetFrameLevel(win:GetFrameLevel() + 60)
	local chrome = { win = win, bar = bar, buttons = { x }, own = { bar, x } }
	-- a good page: a strip the x lies on (it holds the whole button), a title that ends before it, a row above the bar
	local strip = frame(win, 0, 500, 360, 100, true)
	text(strip, 16, 60, "Undercity")
	local row = frame(win, 16, 70, 328, 44, true)
	text(row, 10, 14, "Mia's Rides")
	local out = E.check(c, { chrome = chrome })
	eq(kinds(out).chrome or 0, 0, "a tidy page:\n  " .. list(out))
	-- a naive move: a title that runs under the x, a chip half under it, a row that reaches into the tab bar
	local title = frame(win, 250, 560, 100, 24, false)
	local fs = text(title, 0, 4, "Hover over anything for help")
	local chip = frame(win, 300, 540, 30, 30, true)
	local low = frame(win, 16, 30, 328, 44, true)
	text(low, 10, 14, "Scroll for your trips")
	-- and what no other rule sees: words drawn over the tab bar, wholly inside it
	local over = frame(win, 200, 14, 120, 20, false)
	over:SetFrameLevel(win:GetFrameLevel() + 70)
	text(over, 0, 4, "5 trips")
	out = E.check(c, { chrome = chrome })
	local n, bars, heads = 0, 0, 0
	for _, h in ipairs(out) do
		if h.kind == "chrome" then
			n = n + 1
			if h.detail:find("the tab bar", 1, true) then bars = bars + 1 end
			if h.detail:find("the header button", 1, true) then heads = heads + 1 end
		end
	end
	ok(bars >= 1, "the row in the tab bar: chrome\n  " .. list(out))
	ok(heads >= 1 or (kinds(out).under or 0) + (kinds(out).boxes or 0) >= 1, "the title or the chip under the x is named\n  " .. list(out))
	-- no chrome given and no Wuber: the rule is off
	eq(kinds(E.check(c)).chrome or 0, 0, "off without a window's chrome")
end)

-- (job 211, D) the route walks (tests/layout/routes.lua): the real moves between pages (tabs, cog, Settings back, Options >
-- Open Wuber settings, fold, the ride page's chevron and pill, the driver's console) leave exactly one page shown, the
-- head visible and uncovered, and the normal layout kinds clean. Run as the checker runs them: a child process on this tree.
test("layout routes: the route walks find no problem on this tree", function()
	local lua = (arg and arg[-1]) or "lua5.1"
	local script = root .. "/tools/layout-check.lua"
	local cmd = ('"%s" "%s" --routes-only --wuber "%s/Wuber" 2>&1'):format(lua, script, root):gsub("\\", "/")
	if package.config:sub(1, 1) == "\\" then cmd = '"' .. cmd .. '"' end
	local p = io.popen(cmd, "r")
	local text = p:read("*a") or ""
	p:close()
	local steps, bad = text:match("routes: (%d+) steps, (%d+) route problems")
	ok(steps and tonumber(steps) > 30, "the walks ran: " .. text:sub(-400))
	eq(tonumber(bad), 0, "route problems:\n" .. text:sub(1, 1500))
end)
