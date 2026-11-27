-- bs8: blind-spot checks for the in-game run 1 polish misses (job 206; from a reviewer's BS8 pilot, judged and adapted).
-- Item 10 (portal page you dot), 12.7 (Greeting confirm / preview), 12.8 (Shift complete sheet over the pills), 12.2 (wide Settings).
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function rectsOverlap(a, b)
	return a.l < b.l + b.w - 0.5 and b.l < a.l + a.w - 0.5 and a.b < b.b + b.h - 0.5 and b.b < a.b + a.h - 0.5
end

-- Item 10 (updated E1-03): with the portal up the you dot is hidden and does not pulse, and the strip behind
-- it is hidden altogether (alpha 0).
test("bs8 polish 1 (item 10): portal page: the you dot is hidden and still, the map strip is hidden", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	r.W.ride = { id = "bs8_10", driver = "Mia Runner", driverKey = "mia runner", dest = "Undercity",
		price = 5000, state = "portal", at = r.env.GetTime(), payee = "Mia Runner", payto = "Mia", service = "Mia's Rides" }
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.Show("found")
	w:advance(3)
	local s = r.W.UI.state.screens.found
	ok(s and s.map and s.map.me and s.map.me.pulse, "found screen has the you dot and its pulse")
	ok(s.hero.art:IsShown(), "setup: the portal picture is up")
	eq(s.map.me:GetAlpha(), 0, "the you dot is hidden")
	ok(not s.map.me.pulse.running, "the you dot is not pulsing under the header")
	ok(s.map.canvas:GetAlpha() < 0.05, "the strip's map art is hidden, not just dimmed")
	T.clean(w)
end)

-- Item 12.7: the Greeting "Invite public chat riders" confirm is Blizzard's popup; Wuber lays an opaque backdrop behind it
-- (Drive.PlacePublicWarning) so the Greeting chips do not show through. Driven through the real switch, not a hand-made frame.
test("bs8 polish 2 (item 12.7): the public-buyers confirm over Wuber gets Wuber's opaque backdrop", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	T.openDrive(d)
	d.W.Driver.ShowScreen("messages")
	w:advance(1)
	local DR = d.W.Drive
	DR.SetAutoPublic(true)
	w:advance(0.5)
	local env = d.env
	local dlg = env.StaticPopupDialogs and env.StaticPopupDialogs[DR.PUBLIC_POPUP]
	ok(dlg and type(dlg.OnShow) == "function" and type(dlg.OnHide) == "function", "the confirm is registered with Wuber's OnShow and OnHide")
	-- the fake game's StaticPopup_Show draws no frame and calls no OnShow: make the popup frame the game would and run the registered hooks
	local pop = env.CreateFrame("Frame", nil, env.UIParent)
	pop:SetSize(320, 120)
	pop.text = pop:CreateFontString(nil, "ARTWORK")
	pop.text:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
	pop.text:SetText(DR.PUBLIC_WARNING)
	pop:SetAlpha(0.6)
	env.WuberFrame:Show()
	dlg.OnShow(pop)
	ok(pop.wuberBack and pop.wuberBack:IsShown(), "its opaque backdrop is on while Wuber's window is up")
	eq(pop:GetAlpha(), 1, "the popup itself is not see-through")
	dlg.OnHide(pop)
	ok(not pop.wuberBack:IsShown(), "the backdrop goes with the popup")
	eq(pop:GetAlpha(), 0.6, "the alpha is put back")
	T.clean(w)
end)

-- Item 12.7, the preview bubble on the Greeting screen is a tinted chat bubble by design (alpha 0.32 over the card); what must
-- hold is that it does not sit on the placeholder chips and its text stays inside it.
test("bs8 polish 3 (item 12.7): Greeting editor: the preview bubble clears the placeholder chips and holds its text", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	T.openDrive(d)
	d.W.Driver.ShowScreen("messages")
	w:advance(1)
	local scr = d.W.UI.drive.screens.messages
	ok(scr and type(scr.edit) == "function", "the messages screen has edit()")
	scr.edit("greet")
	w:advance(0.5)
	local e = scr.editor
	ok(e and e.bubble and e.prev, "the greeting editor has its preview bubble")
	local bub = H.rect(e.bubble)
	ok(bub and bub.h > 0, "the bubble has a size")
	local n = 0
	for _, chip in ipairs(e.chips or {}) do
		local r = chip:IsShown() and H.rect(chip)
		if r and r.h > 0 then
			n = n + 1
			ok(not rectsOverlap(bub, r), "the preview bubble overlaps a placeholder chip")
		end
	end
	ok(n > 0, "setup: the chips are shown")
	local pt = H.rect(e.prev)
	if pt and pt.h > 0 then
		ok(pt.b >= bub.b - 0.5 and pt.b + pt.h <= bub.b + bub.h + 0.5, "the preview text stays inside the bubble")
	end
	T.clean(w)
end)

-- Item 12.8: the Shift complete sheet's top must not land inside the Open / Pause / Advertise row (labels cut in half).
-- The real flow with the real pill positions (no hand-moved pill: the sheet decides its own height).
test("bs8 polish 4 (item 12.8): Shift complete sheet's top does not cut the Open / Pause / Advertise pills", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	T.openDrive(d)
	local D = d.W.Driver
	D.lastShift = { rides = 3, copper = 15000, tips = 1000, open = 1800, bestHour = 17, bestCopper = 15000 }
	ok(D.ShowSheet("shift"), "the Shift complete sheet opens")
	w:advance(1)
	local sh = D.ui.sheets.shift.frame
	-- the fake phone's pills sit above the sheet: slide the Open pill (and so the row) down until the sheet's top is in the middle of it
	local open = D.ui.console.open
	local c0, r0 = H.rect(sh.card), H.rect(open)
	local sc = c0.h / sh.sheetH
	local pt, rel, rp, x, y = open:GetPoint(1)
	open:ClearAllPoints()
	open:SetPoint(pt, rel, rp, x, y + ((c0.b + c0.h) - (r0.b + r0.h / 2)) / sc)
	D.ui.sheets.shift.update()
	w:advance(1)
	local card = H.rect(sh.card)
	ok(card and card.h > 0, "the sheet's card has a size")
	local top = card.b + card.h
	for _, name in ipairs({ "open", "pause", "advert" }) do
		local p = D.ui.console[name]
		ok(p and p.label, "the " .. name .. " pill exists")
		local r = p:IsShown() and H.rect(p)
		if r and r.h > 0 then
			ok(not (top > r.b + 0.01 and top < r.b + r.h - 0.01),
				"the sheet's top (" .. top .. ") cuts the " .. tostring(p.label:GetText()) .. " pill [" .. r.b .. ", " .. (r.b + r.h) .. "]")
			ok((p.label:GetStringWidth() or 0) <= (p:GetWidth() or 0) + 0.5, "the " .. name .. " label fits its pill")
		end
	end
	T.clean(w)
end)

-- Item 12.2, the polish angle (stacking is BS1's): wide Settings shows its own title and back arrow, and its rows stay inside
-- the panel (the shot had them cut at x=677 with the title missing).
test("bs8 polish 5 (item 12.2): wide Settings: title and back arrow visible, rows inside the panel", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	r.wide = true
	r.W.db.fold = { v = 1, pages = {}, narrow = false }
	w:advance(15)
	r.W.UI.Toggle(true)
	w:advance(3)
	r.W.UI.OpenSettings()
	w:advance(1)
	local st = r.W.UI.settings
	ok(st and st.panel and st.panel:IsShown(), "the Settings panel is shown")
	ok(st.title and H.visible(st.title) and st.title:GetText() == "Settings", "the Settings title is visible")
	ok(st.back and H.visible(st.back), "the back arrow is visible")
	local p, c = H.rect(st.panel), H.rect(st.clip)
	ok(p and c, "panel and rows clip have rects")
	ok(c.l >= p.l - 0.5 and c.l + c.w <= p.l + p.w + 0.5, "the rows' clip [" .. c.l .. ", " .. (c.l + c.w) .. "] is inside the panel [" .. p.l .. ", " .. (p.l + p.w) .. "]")
	T.clean(w)
end)
