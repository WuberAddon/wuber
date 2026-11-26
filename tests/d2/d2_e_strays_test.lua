-- Design round 2, group E: three of the five floating things became sheets built on the sheet core (T.Sheet inside the
-- phone for the login tip; T.SheetCard for What's new and the mid-flight offer, which stand clear of the phone): no
-- outline, no violet fill, flat in the sheet colour, one primary button. Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function rectsCross(a, b)
	return not (a.l + a.w <= b.l or b.l + b.w <= a.l or a.b + a.h <= b.b or b.b + b.h <= a.b)
end

local function primaries(list)
	local n = 0
	for _, b in ipairs(list) do if b.style == "primary" then n = n + 1 end end
	return n
end

-- 1. the login tip
local FAKE = {
	{ id = "fly_or_summon", text = "Fly or summon? Wuber shows what flying costs and how long, before you book.", driver = false, screen = "home" },
	{ id = "world_view", text = "Tap World to see every driver on the whole map.", driver = false, screen = "world" },
}

test("d2 e: the login tip is a sheet inside the phone: grey sentence-case caption, one main button, a second button, a link, and the page dims", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = true } } })
	w:advance(2)
	local W = c.W
	local m = W.Mod("UI.TipTexts")
	m.list = FAKE
	m.Show = function() return true end
	local Fold = W.UI and W.UI.Fold
	if Fold then Fold.Fits = function() return true end end
	W.UI.Toggle(true)
	w:advance(5)
	local Mod = W.Mod("UI.Tips")
	local card = Mod.Card()
	ok(card and H.visible(card), "the tip shows")
	eq(card:GetParent(), c.env.WuberFrame, "inside the phone")
	ok(card.sheet and card.sheet.card, "built on T.Sheet")
	eq(card.kicker:GetText(), "Tip 1 of 2", "the caption in sentence case")
	eq(card.text:GetText(), FAKE[1].text, "the tip's words unchanged")
	ok(not card.sheet.card.edge, "no outline")
	eq(card.sheet.card.bg.colour, "panel", "the sheet colour, no violet fill")
	eq(card.show.style, "primary", "Show me is the main button")
	eq(card.next.style, "dark", "Next tip is the second button")
	eq(card.never.style, "ghost", "Don't show again is a link")
	eq(primaries({ card.show, card.next, card.never }), 1, "one primary button")
	eq(card.show.label:GetText(), "Show me")
	eq(card.next.label:GetText(), "Next tip")
	eq(card.never.label:GetText(), "Don't show again")
	ok(math.abs(card.sheet.dim:GetAlpha() - 0.5) < 0.01, "the page behind dims to 50%")
	local sr, wr = H.rect(card.sheet.card), H.rect(c.env.WuberFrame)
	ok(sr.l >= wr.l - 0.5 and sr.l + sr.w <= wr.l + wr.w + 0.5 and sr.b >= wr.b - 0.5, "the sheet sits inside the phone")
	card.next:Click()
	eq(card.kicker:GetText(), "Tip 2 of 2", "Next tip: the next caption")
	T.clean(w)
end)

-- 2. what's new
test("d2 e: What's new is a card of the sheet look, clear of the phone, with line spacing and Got it as its main button", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = true, newsSeen = "2.3.4", tipsOn = false } } })
	local Mod = c.W.Mod("UI.WhatsNew")
	c.W.UI.Toggle(true)
	w:advance(6)
	local card = Mod.Card()
	ok(card and H.visible(card), "the card shows: " .. tostring(Mod.Why()))
	ok(card.sheet and card.sheet.card, "built on T.SheetCard")
	ok(not card.sheet.card.edge, "no outline")
	eq(card.sheet.card.bg.colour, "panel", "the sheet colour")
	ok(Mod.Expand(), "(the 20 rewrites, W-20) See what's new opens the list")
	eq(card.got.style, "primary", "Got it is the main button")
	eq(primaries({ card.got }), 1)
	eq(card.title:GetText(), "What's new in Wuber 2.4", "the words unchanged")
	ok((card.text.paraLines or 0) >= 3, "wrapped text of several lines")
	ok(card.text.paraH >= card.text.paraLines * c.W.Theme.DrawnSize(12), "the text box holds its lines and their spacing")
	ok(card.text:GetBottom() >= card.got:GetTop() - 0.01, "the words end above the button")
	local wf = c.env.WuberFrame
	ok(H.visible(wf), "the phone is open")
	ok(not rectsCross(H.rect(card), H.rect(wf)), "clear of the phone")
	T.clean(w)
end)

-- 3. the mid-flight offer
local UC_TM = {
	{ name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 },
	{ name = "Tarren Mill, Hillsbrad", type = "REACHABLE", cost = 330, x = 0.47, y = 0.44 },
}

test("d2 e: the mid-flight offer is a sheet card: gold Book with the price, Don't show a link, lines apart, clear of the phone and Wuber's floating pieces", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Undercity", screenW = 1365, screenH = 768 })
	T.settle(w)
	local W = r.W
	W.db.flights = W.db.flights or {}
	W.db.flights["H|undercity|tarren mill"] = { t = 240, tat = r.env.time(), tsrc = "own" }
	W.drivers = W.drivers or {}
	W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Tarren Mill", price = 12345, state = "open", team = 3,
		service = "Mia Runner's Rides", heard = r.env.GetTime() }
	local function piece(name, wd, ht, y)
		local f = r.env.CreateFrame("Frame", name, r.env.UIParent)
		f:SetSize(wd, ht)
		f:SetPoint("TOP", r.env.UIParent, "TOP", 0, y)
		f:Show()
		return f
	end
	local btn = piece("WuberDriveButton", 264, 60, -160)
	local mini = piece("WuberDriveMini", 300, 102, -230)
	W.UI.Toggle(true)
	w:advance(0.2)
	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 240, "Tarren Mill")
	w:advance(3)
	local Mod = W.Mod("UI.InFlight")
	local c = Mod.Card()
	ok(c and H.visible(c), "the offer shows")
	ok(c.sheet and c.sheet.card, "built on T.SheetCard")
	ok(not c.sheet.card.edge, "no outline")
	eq(c.sheet.card.bg.colour, "panel", "the sheet colour, no violet fill")
	eq(c.book.style, "primary", "Book is the gold main button")
	eq(c.never.style, "ghost", "Don't show is a link")
	eq(primaries({ c.book, c.never }), 1, "one primary button")
	eq(c.book.label:GetText(), "Book \194\183 1g 23s 45c", "the price is on the button")
	eq(c.never.label:GetText(), "Don't show")
	ok(c.line1:GetBottom() >= c.line2:GetTop() - 0.01, "the two lines do not touch")
	ok(c.line2:GetBottom() >= c.book:GetTop() - 0.01, "the words end above the button")
	local cr = H.rect(c)
	for name, f in pairs({ WuberFrame = r.env.WuberFrame, WuberDriveButton = btn, WuberDriveMini = mini }) do
		ok(not rectsCross(cr, H.rect(f)), "clear of " .. name)
	end
	w:advance(245)
	T.clean(w)
end)
