-- Design round 2, group F (item 9): one main button in the same place. T.MainButton, then every screen's own.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("d2 f: T.MainButton is a primary pill, 46 high, 16 from each side, 12 above the bottom", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(2)
	local Th, env = c.W.Theme, c.env
	ok(Th.MAIN and Th.MAIN.h == 46 and Th.MAIN.side == 16 and Th.MAIN.foot == 12, "T.MAIN holds 46, 16, 12")
	local page = env.CreateFrame("Frame", nil, env.UIParent)
	page:SetSize(320, 500)
	page:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
	local b = Th.MainButton(page, "Go")
	eq(b.style, "primary", "primary")
	eq(b:GetHeight(), 46, "46 high")
	eq(b:GetLeft() - page:GetLeft(), 16, "16 from the left")
	eq(page:GetRight() - b:GetRight(), 16, "16 from the right")
	eq(b:GetBottom() - page:GetBottom(), 12, "12 above the bottom")
	ok(type(b.SetLabel) == "function" and type(b.SetStyle) == "function", "still a T.Pill")
	local b2 = Th.MainButton(page, "Go", { foot = 40 })
	eq(b2:GetBottom() - page:GetBottom(), 40, "opts.foot")
end)

local H = T.H

-- every shown primary pill under root
local function primaries(root, out, seen)
	out, seen = out or {}, seen or {}
	if type(root) ~= "table" or seen[root] then return out end
	seen[root] = true
	if root.style == "primary" and root.label and H.visible(root) then out[#out + 1] = root end
	for _, c in ipairs({ root:GetChildren() }) do primaries(c, out, seen) end
	return out
end
local function near(a, b) return math.abs(a - b) < 0.6 end
-- the one main button: at most one shown, 46 high, 16 from the sides, 12 above the page's bottom
local function oneMain(what, root, page, want)
	local ps = primaries(root)
	ok(#ps <= 1, what .. ": at most one primary pill is shown (" .. #ps .. ")")
	local b = want or ps[1]
	ok(b, what .. ": the main button is there")
	if not b then return end
	ok(near(b:GetHeight(), 46), what .. ": 46 high (" .. tostring(b:GetHeight()) .. ")")
	ok(near(b:GetLeft() - page:GetLeft(), 16), what .. ": 16 from the left (" .. tostring(b:GetLeft() - page:GetLeft()) .. ")")
	ok(near(page:GetRight() - b:GetRight(), 16), what .. ": 16 from the right (" .. tostring(page:GetRight() - b:GetRight()) .. ")")
	ok(near(b:GetBottom() - page:GetBottom(), 12), what .. ": 12 above the page's bottom (" .. tostring(b:GetBottom() - page:GetBottom()) .. ")")
end

local function riderWorld()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar", screenW = 1365, screenH = 768 })
	T.settle(w)
	T.goOnline(d) w:advance(5)
	r.W.UI.Toggle(true) w:advance(2.5)
	return w, d, r
end
local function withRide(r, w, state, extra)
	local ride = { id = "d2f", driver = "Mia", driverKey = "mia", dest = "Undercity", price = 5000, state = state,
		at = r.env.GetTime(), payee = "Mia", payto = "Mia", service = "Mia's Rides" }
	for k, v in pairs(extra or {}) do ride[k] = v end
	r.W.ride = ride
	r.W.Fire("RIDE")
	w:advance(1)
end

test("d2 f: Request summon is the one main button, in the main button's place", function()
	local w, d, r = riderWorld()
	local UI = r.W.UI
	UI.SelectTab("Ride") UI.Show("confirm", d.W.myKey) w:advance(2)
	local scr = UI.state.screens.confirm
	oneMain("confirm", r.env.WuberFrame, scr.frame, scr.request)
end)

test("d2 f: the ride screen's action is the one main button, in the same place", function()
	local w, d, r = riderWorld()
	local UI = r.W.UI
	withRide(r, w, "invited")
	UI.Show("found") w:advance(2)
	local scr = UI.state.screens.found
	oneMain("ride (invite)", r.env.WuberFrame, scr.frame, scr.action)
	withRide(r, w, "arrived", { arrived = true })
	UI.Show("found") w:advance(2)
	oneMain("ride (pay)", r.env.WuberFrame, scr.frame, scr.action)
end)

test("d2 f: Done and Try another driver are the one main button, in the same place", function()
	local w, d, r = riderWorld()
	local UI = r.W.UI
	withRide(r, w, "done", { paid = 5000, saved = 840, savedHow = "own" })
	UI.Show("done") w:advance(3)
	local scr = UI.state.screens.done
	oneMain("done (paid)", r.env.WuberFrame, scr.frame, scr.done)
	withRide(r, w, "done", { paid = 0, unpaid = true })
	UI.Show("done") w:advance(3)
	oneMain("done (unpaid)", r.env.WuberFrame, scr.frame)
end)

test("d2 f: the trade button under the trade window is the main button's height, the trade window's width", function()
	local w, d, r = riderWorld()
	withRide(r, w, "arrived", { arrived = true })
	r.env.TradeFrame:Show()
	r:fire("TRADE_SHOW") w:advance(1)
	local ps = primaries(r.env.TradeFrame)
	eq(#ps, 1, "one trade button is shown")
	local b = ps[1]
	ok(b, "the button is there")
	if not b then return end
	local tfw = r.env.TradeFrame
	ok(near(b:GetHeight(), 46), "46 high (" .. tostring(b:GetHeight()) .. ")")
	eq(b:GetNumPoints(), 2, "anchored to both sides of the trade window: as wide as it")
	local _, rel = b:GetPoint(1)
	ok(rel == tfw, "anchored to the trade window")
end)

test("d2 f: the messages editor's Save is the one main button, Reset to default a link", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	T.settle(w)
	T.openDrive(d)
	d.W.Driver.ShowScreen("messages") w:advance(1)
	local s = d.W.Driver.ui.subs.messages
	s.edit("greet") w:advance(0.5)
	local e = s.editor
	oneMain("messages", s.frame, s.frame, e.save)
	eq(e.reset.style, "ghost", "Reset to default is a link")
	ok(H.visible(e.reset), "the link is shown")
	T.clean(w)
end)

test("d2 f: the notes sheet's Save is the one main button, Gifted a second button", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	T.settle(w)
	T.openDrive(d)
	d.W.Driver.ShowSheet("note", { name = "Bob Rider" }) w:advance(1)
	local s = d.W.Driver.ui.sheets.note
	ok(s, "the note sheet is built")
	if not s then return end
	oneMain("note sheet", s.frame, s.frame.card, s.save)
	eq(s.gift.style, "dark", "Gifted is a second button")
	T.clean(w)
end)

test("d2 f: the wizard has one main button at the bottom on every step, no Back button, Skip for now is a link", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	T.settle(w)
	T.openDrive(d)
	d.W.Driver.ShowScreen("wizard") w:advance(1)
	local s = d.W.Driver.ui.subs.wizard
	ok(s.backBtn == nil, "no Back button (the chevron at the top goes back)")
	ok(s.back and H.visible(s.back), "the chevron is there")
	d:clickText("My friends help") w:advance(0.5)
	oneMain("wizard step 1", s.frame, s.frame, s.next)
	d:clickOn(s.next) w:advance(1)
	eq(s.step, 2, "step 2")
	oneMain("wizard step 2 (before offers)", s.frame, s.frame, s.send)
	eq(s.skip.style, "ghost", "Skip for now is a link")
	ok(H.visible(s.skip), "the link is shown")
	ok(not H.visible(s.next), "Next waits until the offers are sent")
	s.sent = true s.paint() w:advance(0.3)
	oneMain("wizard step 2 (after offers)", s.frame, s.frame, s.next)
	eq(s.send.style, "ghost", "Send offers again is a link")
	s.back:GetScript("OnClick")(s.back) w:advance(1)
	eq(s.step, 1, "the chevron goes back a step")
	s.step = 3 s.paint() w:advance(0.3)
	oneMain("wizard step 3", s.frame, s.frame, s.next)
	T.clean(w)
end)

test("d2 f: Set up driving on the driver's first page is the main button, in its place", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	T.settle(w)
	d.W.UI.Toggle(true) w:advance(2.5)
	d:clickText("Drive") w:advance(1)
	local b = d:findText("^Set up driving$", true)[1]
	ok(b, "the first page shows Set up driving")
	if not b then return end
	local btn = b:GetParent()
	eq(btn.style, "primary", "it is the main button")
	ok(near(btn:GetHeight(), 46), "46 high")
	local page = btn:GetParent()
	ok(near(btn:GetLeft() - page:GetLeft(), 16) and near(page:GetRight() - btn:GetRight(), 16), "16 from the sides")
	ok(#primaries(page) <= 1, "one primary pill")
end)

-- the main button's words are the bold weight, whatever the screen, and stay so through SetLabel and SetStyle
local function isBold(b, what)
	local path = b.label:GetFont()
	ok(b.label.wuberWeight == "bold" and tostring(path):find("Bold", 1, true), what .. ": bold words (" .. tostring(b.label.wuberWeight) .. ", " .. tostring(path) .. ")")
end

test("d2 f: the main button's words are bold on Confirm, the ride screen and the Messages editor", function()
	local w, d, r = riderWorld()
	local UI = r.W.UI
	UI.SelectTab("Ride") UI.Show("confirm", d.W.myKey) w:advance(2)
	local req = UI.state.screens.confirm.request
	isBold(req, "confirm")
	req:SetLabel("Request summon · 50s")
	isBold(req, "confirm after SetLabel")
	req:SetStyle("primary")
	isBold(req, "confirm after SetStyle")
	withRide(r, w, "invited")
	UI.Show("found") w:advance(2)
	isBold(UI.state.screens.found.action, "ride screen")
	local m = T.newWorld()
	local dr = T.driver(m, T.ANITA, { spot = "Ratchet" })
	T.settle(m)
	T.openDrive(dr)
	dr.W.Driver.ShowScreen("messages") m:advance(1)
	local s = dr.W.Driver.ui.subs.messages
	s.edit("greet") m:advance(0.5)
	isBold(s.editor.save, "messages editor")
	T.clean(m)
end)
