-- Design round 2, group D: one sheet (T.Sheet) and the card that stands alone (T.SheetCard). Loaded by tests/run.lua
-- with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function setup()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	T.settle(w)
	local TH = d.W.Theme
	local host = d.env.CreateFrame("Frame", nil, d.env.UIParent)
	host:SetSize(300, 500)
	host:SetPoint("CENTER")
	host:Show()
	return w, d, TH, host
end
local function bottom(f) return f:GetBottom() end
local function grabs(f, seen, out)
	seen = seen or {}
	out = out or {}
	if seen[f] then return out end
	seen[f] = true
	for _, r in ipairs({ f:GetRegions() }) do
		if r.GetTextureFilePath then
			local p = r:GetTextureFilePath()
			if type(p) == "string" and p:find("pill", 1, true) and r:IsShown() then out[#out + 1] = r end
		end
	end
	for _, c in ipairs({ f:GetChildren() }) do grabs(c, seen, out) end
	return out
end

test("d2 d: the sheet is full width, flat, top corners 14, no outline and no grab handle", function()
	local w, d, TH, host = setup()
	local sh = TH.Sheet(host, 300, "Title")
	sh:Open() w:advance(1)
	eq(sh.card:GetWidth(), host:GetWidth(), "full width")
	ok(not sh.card.edge, "no outline")
	eq(sh.card.bg.parts.TL:GetWidth(), 14, "top corner 14")
	eq(sh.card.bg.colour, "panel", "the sheet colour")
	eq(#grabs(sh.card), 0, "no grab handle texture")
	eq(sh.title:GetText(), "Title")
	T.clean(w)
end)

test("d2 d: the sheet rises by its own height, drops hidden, and a second call jumps to the end", function()
	local w, d, TH, host = setup()
	local sh = TH.Sheet(host, 300, "Title")
	local base = bottom(host)
	sh:Open()
	ok(bottom(sh.card) <= base - 299, "starts one height lower, clipped: " .. tostring(bottom(sh.card) - base))
	ok(sh.SetClipsChildren, "control: frames can clip")
	w:advance(0.1)
	local mid = bottom(sh.card)
	ok(mid > base - 299 and mid < base - 1, "moving after 0.1 s")
	w:advance(0.5)
	eq(bottom(sh.card), base, "ends in place")
	sh:Close()
	w:advance(0.1)
	ok(sh:IsShown(), "still dropping")
	w:advance(0.4)
	ok(not sh:IsShown(), "the drop ends hidden")
	sh:Open() w:advance(0.05)
	sh:Close()
	eq(bottom(sh.card), base, "Close in the middle of the rise jumps to the end first, then drops")
	sh:Close(true)
	ok(not sh:IsShown(), "Close(true) is instant")
	T.clean(w)
end)

test("d2 d: reduce motion fades in place and nothing travels", function()
	local w, d, TH, host = setup()
	d.W.db.reduceMotion = true
	TH.ReduceMotion = function() return true end
	local sh = TH.Sheet(host, 300, "Title")
	local base = bottom(host)
	sh:Open()
	eq(bottom(sh.card), base, "in place at once")
	w:advance(0.05)
	eq(bottom(sh.card), base, "in place while fading")
	ok(sh:GetAlpha() < 1, "fading")
	w:advance(0.3)
	eq(sh:GetAlpha(), 1, "ends opaque")
	TH.ReduceMotion = nil
	T.clean(w)
end)

test("d2 d: the sheet's main button sits 46 high, 16 from the sides, 12 above the foot; the body ends above it", function()
	local w, d, TH, host = setup()
	local sh = TH.Sheet(host, 300, "Title")
	local clicked
	local b = sh:MainButton("Accept", function() clicked = true end)
	sh:Open() w:advance(1)
	eq(b:GetHeight(), 46)
	eq(b.style or "primary", "primary")
	eq(b:GetBottom() - sh.card:GetBottom(), 12, "12 above the bottom")
	eq(b:GetLeft() - sh.card:GetLeft(), 16, "16 from the left")
	eq(sh.card:GetRight() - b:GetRight(), 16, "16 from the right")
	ok(sh.body:GetBottom() >= b:GetTop(), "the body ends above the button")
	b:GetScript("OnClick")(b)
	ok(clicked, "it clicks")
	local l = sh:Link("No thanks", function() end)
	ok(l and l:GetTop() < b:GetBottom() + 40, "the link sits at the foot")
	T.clean(w)
end)

test("d2 d: T.SheetCard has all four corners 14, no dim, rises 12 with a fade and fades out", function()
	local w, d, TH, host = setup()
	local c = TH.SheetCard(host, 260, 160, "News")
	c:MainButton("Got it", function() end)
	c:Link("Later", function() end)
	eq(c.card.bg.parts.BL:GetWidth(), 14, "bottom corner 14 too")
	eq(c.title:GetText(), "News")
	c:SetTitle("Other")
	eq(c.title:GetText(), "Other")
	c:Open()
	eq(c:GetAlpha(), 0, "starts clear")
	w:advance(0.05)
	ok(c:GetAlpha() > 0 and c:GetAlpha() < 1, "fading in")
	w:advance(0.5)
	eq(c:GetAlpha(), 1)
	c:Close()
	w:advance(0.5)
	ok(not c:IsShown(), "closed hides")
	T.clean(w)
end)

local function riderWith(mine)
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	w:advance(15)
	c.W.Raincheck.Mine = function() return mine(c) end
	return w, c
end
local function offer(c) return { { id = "rcD2", state = "offered", driver = "Anita Lift", cover = 5000, expires = c.env.time() + 6 * 86400 } } end

test("d2 d: the raincheck offer is a sheet in the phone: Raincheck, Accept as the main button, No thanks as a link", function()
	local w, c = riderWith(offer)
	local UI = c.W.UI
	UI.Toggle(true)
	w:advance(3)
	local f = UI.RaincheckOffer()
	w:advance(1)
	ok(f and T.H.visible(f), "the sheet shows")
	eq(f.title:GetText(), "Raincheck", "title in sentence case")
	ok(#c:findText("Anita offers a raincheck", nil, true) > 0, "today's words stay")
	ok(f.card.bg and not f.card.edge, "a flat card, no gold outline")
	eq(f.yes.style or "primary", "primary", "Accept is the main button")
	eq(f.yes.label:GetText(), "Accept")
	eq(f.no.label:GetText(), "No thanks")
	ok(f.no.fill and f.no ~= f.yes, "No thanks is its own control (a link)")
	local fr, wr = T.H.rect(f.card), T.H.rect(UI.state.win)
	ok(math.abs(fr.w - wr.w) < 1 and math.abs(fr.b - (wr.b + UI.TABBAR_H * wr.h / 600)) < 1, "full width, resting on the tab bar")
	T.clean(w)
end)

test("d2 d: Report a bug is a full-height sheet inside the phone with Select all as its main button", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	local W, UI = r.W, r.W.UI
	ok(not UI.IsShown(), "control: the window is closed")
	UI.Bug.Open()
	w:advance(1)
	ok(UI.IsShown(), "opening the report opens the window first")
	ok(UI.Bug.Shown(), "the report shows")
	local f = UI.Bug.frame
	local fr, wr = T.H.rect(f.card), T.H.rect(UI.state.win)
	ok(fr.l >= wr.l - 1 and fr.l + fr.w <= wr.l + wr.w + 1 and fr.b >= wr.b - 1 and fr.b + fr.h <= wr.b + wr.h + 1, "inside the phone, not hanging over its edges")
	ok(fr.h >= (wr.h - (UI.HEAD_H + UI.TABBAR_H) * wr.h / 600) - 2, "full height: from under the header zone to the tab bar")
	eq(f.title:GetText(), "Report a bug")
	eq(f.select.label:GetText(), "Select all", "the main button")
	r:click(f.close)
	ok(not UI.Bug.Shown(), "the x closes it")
	w:advance(1)
	ok(not f:IsShown(), "and it is gone")
	T.clean(w)
end)

-- (design 2, TE) a sheet inside the phone rises from the top edge of the tab bar and leaves the header zone free
local function top(r) return r.b + r.h end

test("d2 d TE: the raincheck offer's sheet rests on the tab bar (card, dim) and the tabs stay in sight", function()
	local w, c = riderWith(offer)
	local UI = c.W.UI
	UI.Toggle(true)
	w:advance(3)
	local f = UI.RaincheckOffer()
	w:advance(1)
	ok(f and T.H.visible(f), "the sheet shows")
	local tb = T.H.rect(UI.state.tabbar)
	local cd, dim = T.H.rect(f.card), T.H.rect(f.dim)
	ok(math.abs(cd.b - top(tb)) < 1, "the card's foot is the tab bar's top edge: " .. cd.b .. " vs " .. top(tb))
	ok(math.abs(dim.b - top(tb)) < 1, "the dim ends at the tab bar too")
	local yes, no = T.H.rect(f.yes), T.H.rect(f.no)
	ok(yes.b >= top(tb) and no.b >= top(tb), "Accept and No thanks are above the tab bar")
	T.clean(w)
end)

test("d2 d TE: a tab click closes the raincheck offer as its x would, nothing breaks", function()
	local w, c = riderWith(offer)
	local UI = c.W.UI
	UI.Toggle(true)
	w:advance(3)
	local f = UI.RaincheckOffer()
	w:advance(1)
	ok(f.open, "control: open")
	local tab
	for _, t in ipairs(UI.state.tabs) do if t.name ~= UI.state.tab then tab = t break end end
	ok(tab, "control: a tab to go to")
	c:click(tab.button)
	w:advance(1)
	eq(UI.state.tab, tab.name, "the tab changed")
	ok(not f.open and not f:IsShown(), "the sheet closed")
	T.clean(w)
end)

test("d2 d TE: Report a bug starts under the header zone, rests on the tab bar, and its x is clear of the window's x", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	local UI = r.W.UI
	UI.Bug.Open()
	w:advance(1)
	local f = UI.Bug.frame
	local win, tb = T.H.rect(UI.state.win), T.H.rect(UI.state.tabbar)
	local cd = T.H.rect(f.card)
	ok(math.abs(cd.b - top(tb)) < 1, "the card's foot is the tab bar's top edge: " .. cd.b .. " vs " .. top(tb))
	local scale = win.h / 600
	ok(top(cd) <= top(win) - UI.HEAD_H * scale + 1, "the top is under the header zone: " .. top(cd) .. " vs " .. top(win))
	local x, wx = T.H.rect(f.close), T.H.rect(UI.state.close)
	local apart = x.l + x.w <= wx.l or wx.l + wx.w <= x.l or top(x) <= wx.b or top(wx) <= x.b
	ok(apart, "the sheet's x does not sit on the window's x")
	ok(f.select and T.H.visible(f.select), "Select all shows")
	local sr = T.H.rect(f.select)
	ok(sr.b >= top(tb), "Select all is above the tab bar")
	T.clean(w)
end)

test("d2 d TE: a tab click closes Report a bug as its x would, nothing breaks", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	local UI = r.W.UI
	UI.Bug.Open()
	w:advance(1)
	ok(UI.Bug.Shown(), "control: open")
	local tab
	for _, t in ipairs(UI.state.tabs) do if t.name ~= UI.state.tab then tab = t break end end
	r:click(tab.button)
	w:advance(1)
	eq(UI.state.tab, tab.name, "the tab changed")
	ok(not UI.Bug.Shown(), "the report closed")
	T.clean(w)
end)

-- (E3b-01) the dim now runs up to the window's top (no undimmed strip cuts page text); what stays true is that nothing
-- of the sheet takes the mouse over a header button
local function catchers(f, x, y, out, seen)
	out, seen = out or {}, seen or {}
	if seen[f] then return out end
	seen[f] = true
	if f.IsShown and f:IsShown() then
		local rc = T.H.rect(f)
		if f.IsMouseEnabled and f:IsMouseEnabled() and rc.l <= x and x <= rc.l + rc.w and rc.b <= y and y <= rc.b + rc.h then
			out[#out + 1] = f
		end
		for _, c in ipairs({ f:GetChildren() }) do catchers(c, x, y, out, seen) end
	end
	return out
end

local function clearOfHeader(f, UI, label)
	local dim = T.H.rect(f.dim)
	local win = T.H.rect(UI.state.win)
	ok(math.abs(top(dim) - top(win)) <= 1, label .. ": the dim runs up to the window's top (" .. top(dim) .. " vs " .. top(win) .. ")")
	for _, entry in ipairs({
		{ name = "close", btn = UI.state.close },
		{ name = "gear", btn = UI.state.gear },
		{ name = "fold", btn = UI.state.phone and UI.state.phone.fold },
	}) do
		if entry.btn and entry.btn:IsShown() then
			local br = T.H.rect(entry.btn)
			local cx, cy = br.l + br.w / 2, br.b + br.h / 2
			eq(#catchers(f, cx, cy), 0, label .. ": nothing of the sheet takes the mouse over the " .. entry.name .. " button")
		end
	end
end

test("d2 d TE: raincheck and Report a bug sheets stop under the header zone so header buttons stay clickable", function()
	local w, c = riderWith(offer)
	local UI = c.W.UI
	UI.Toggle(true)
	w:advance(3)
	local rc = UI.RaincheckOffer()
	w:advance(1)
	ok(rc and T.H.visible(rc), "control: raincheck open")
	clearOfHeader(rc, UI, "raincheck")
	c:click(rc.close)
	w:advance(1)

	UI.Bug.Open()
	w:advance(1)
	ok(UI.Bug.Shown(), "control: Report a bug open")
	clearOfHeader(UI.Bug.frame, UI, "bug")
	T.clean(w)
end)
