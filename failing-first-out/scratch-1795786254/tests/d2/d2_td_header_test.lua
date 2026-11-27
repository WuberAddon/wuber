-- Design round 2, group TD: the top of the pages after the tab bar moved. Confirm is a pushed page (no cog); Done's
-- headline and the stranger warning keep clear of the header's buttons with every word; the coach marks keep off
-- the tab bar and the buttons; nothing of the tab underneath draws over Settings.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function riderWorld(opts)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, opts or { spot = "Orgrimmar", screenW = 1024, screenH = 768 })
	T.settle(w)
	T.goOnline(d) w:advance(5)
	r.W.db.coach = true
	r.W.UI.Toggle(true) w:advance(2.5)
	return w, d, r
end

local function withRide(r, w, state, extra)
	local ride = { id = "d2td", driver = "Mia", driverKey = "mia", dest = "Undercity", price = 5000, state = state,
		at = r.env.GetTime(), payee = "Mia", payto = "Mia", service = "Mia's Rides" }
	for k, v in pairs(extra or {}) do ride[k] = v end
	r.W.ride = ride
	r.W.Fire("RIDE")
	w:advance(1)
end

-- a and b share no point (two rects of H.rect)
local function apart(x, y)
	return x.l + x.w <= y.l + 0.5 or y.l + y.w <= x.l + 0.5 or x.b + x.h <= y.b + 0.5 or y.b + y.h <= x.b + 0.5
end

-- the header's buttons that show now
local function headButtons(ui)
	local out = {}
	for name, b in pairs({ x = ui.close, cog = ui.gear, fold = ui.phone and ui.phone.fold }) do
		if b and H.visible(b) then out[name] = b end
	end
	return out
end

local function clearOfButtons(ui, thing, what)
	for name, b in pairs(headButtons(ui)) do
		ok(apart(H.rect(thing), H.rect(b)), what .. " keeps clear of the " .. name)
	end
end

test("d2 td: Confirm is a pushed page: its back chevron and the x show, the cog does not; back on the list the cog returns", function()
	local w, d, r = riderWorld()
	local UI, ui = r.W.UI, r.W.UI.state
	ok(H.visible(ui.gear), "the list of drivers shows the cog")
	UI.SelectTab("Ride") UI.Show("confirm", d.W.myKey) w:advance(2)
	local scr = ui.screens.confirm
	ok(H.visible(scr.frame) and H.visible(scr.back), "Confirm shows its back chevron")
	ok(not H.visible(ui.gear), "no cog beside a back chevron")
	ok(H.visible(ui.close), "the x stays")
	clearOfButtons(ui, scr.back, "the chevron")
	UI.Show("home") w:advance(2)
	ok(H.visible(ui.gear), "the cog is back on the list")
	T.clean(w)
end)

test("d2 td: Done's long headline keeps every word and ends before the header's buttons; a short one is centred as before", function()
	local w, d, r = riderWorld()
	local UI, ui = r.W.UI, r.W.UI.state
	-- the way a ride ends: from the pay screen (a pushed page: the cog is hidden there and comes back on Done)
	withRide(r, w, "arrived", { arrived = true })
	UI.Show("found") w:advance(3)
	ok(not H.visible(ui.gear), "no cog on the pay screen")
	withRide(r, w, "done", { paid = 6000, saved = 840, savedHow = "own" })
	UI.Show("done") w:advance(3)
	local scr = ui.screens.done
	ok(H.visible(ui.gear), "the cog is back on Done")
	eq(scr.title:GetText(), "Undercity · Paid 60s to Mia", "the headline's words")
	ok(H.visible(scr.title), "it shows")
	ok(not scr.title:IsTruncated(), "no word is cut")
	ok(next(headButtons(ui)) ~= nil, "the header's buttons show")
	clearOfButtons(ui, scr.title, "the headline")
	clearOfButtons(ui, scr.badge, "the tick")
	local wr, tr, br = H.rect(r.env.WuberFrame), H.rect(scr.title), H.rect(scr.badge)
	ok(br.l >= wr.l + 15.5, "the tick is inside the side margin: " .. (br.l - wr.l))
	ok(tr.b >= H.rect(scr.avatar).b + H.rect(scr.avatar).h - 0.5, "the headline ends above the driver's portal")
	-- a much longer one: still whole, still clear
	withRide(r, w, "done", { dest = "Stranglethorn Vale", paid = 1236000, payto = "Wintergreen", saved = 840, savedHow = "own" })
	UI.Show("done") w:advance(3)
	ok(#scr.title:GetText() > 40, "a long headline: " .. scr.title:GetText())
	ok(not scr.title:IsTruncated(), "no word of the long one is cut")
	clearOfButtons(ui, scr.title, "the long headline")
	ok(H.rect(scr.title).b >= H.rect(scr.avatar).b + H.rect(scr.avatar).h - 0.5, "the long headline ends above the driver's portal")
	-- an unpaid end ("Ride ended"): short, centred over the portal as before
	withRide(r, w, "done", { paid = 0, unpaid = true })
	UI.Show("done") w:advance(3)
	eq(scr.title:GetText(), "Ride ended", "the short headline")
	local b2, t2 = H.rect(scr.badge), H.rect(scr.title)
	local need = r.W.Theme.MeasureText("Ride ended", 18, "bold")
	local sc = wr.w / r.env.WuberFrame:GetWidth() -- H.rect is in screen units; the window has its own scale
	local mid = (b2.l + t2.l + need * sc) / 2
	ok(math.abs(mid - (wr.l + 180 * sc)) < 1.5, "the short line is centred: " .. (mid - wr.l) / sc)
	T.clean(w)
end)

test("d2 td: the stranger warning on the pay look ends before the x, with its words whole", function()
	local w, d, r = riderWorld()
	local UI, ui = r.W.UI, r.W.UI.state
	local realName = r.W.UnitName
	for _, who in ipairs({ "Sly Fox", "Wintergreenx Fox" }) do
		r.W.tradeOpen = true
		UI.TradePartnerOK = function() return false, who:lower() end
		r.W.UnitName = function(unit, ...)
			if unit == "npc" then return who end
			return realName(unit, ...)
		end
		withRide(r, w, "arrived", { arrived = true })
		UI.Show("found") w:advance(3)
		local scr = ui.screens.found
		eq(scr.mode, "pay", "the pay look")
		local al = scr.alert
		ok(H.visible(al), "the warning card shows for " .. who)
		ok(al.head:GetText():find("isn't your driver", 1, true), "its head: " .. tostring(al.head:GetText()))
		ok(not al.head:IsTruncated(), "the head is whole: " .. al.head:GetText())
		ok(not al.body:IsTruncated(), "the body is whole: " .. al.body:GetText())
		ok(H.visible(ui.close), "the x shows")
		clearOfButtons(ui, al, "the warning card (" .. who .. ")")
		local ar = H.rect(al)
		for _, fs in ipairs({ al.head, al.body }) do
			local fr = H.rect(fs)
			ok(fr.l >= ar.l - 0.5 and fr.l + fr.w <= ar.l + ar.w + 0.5 and fr.b >= ar.b - 0.5, "the words are inside the card (" .. who .. ")")
		end
		ok(ar.b >= H.rect(scr.pay).b + H.rect(scr.pay).h - 0.5, "the card ends above the pay card (" .. who .. ")")
	end
	T.clean(w)
end)

test("d2 td: every coach mark points at a thing that shows, and its bubble is inside the window, off the tab bar and off the header's buttons", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1024, screenH = 768 })
	w:advance(15)
	r.W.UI.Toggle(true)
	w:advance(3)
	local UI, ui = r.W.UI, r.W.UI.state
	local card = ui.coach
	ok(card and H.visible(card), "the first tip shows")
	local wantTarget = { [4] = function() for _, tab in ipairs(ui.tabs) do if tab.name == "Drive" then return tab.button end end end,
		[5] = function() return ui.gear end }
	for i = 1, #UI.COACH do
		UI.CoachStep(i) w:advance(1)
		eq(ui.coachStep, i, "tip " .. i .. " shows")
		local tag = " (tip " .. i .. ")"
		local cr, wr, bar = H.rect(card), H.rect(r.env.WuberFrame), H.rect(ui.tabbar)
		ok(cr.l >= wr.l - 0.5 and cr.l + cr.w <= wr.l + wr.w + 0.5, "inside the window, sideways" .. tag)
		ok(cr.b + cr.h <= wr.b + wr.h + 0.5, "inside the window, at the top" .. tag)
		ok(cr.b >= bar.b + bar.h + 7.5, "8 above the tab bar: " .. (cr.b - bar.b - bar.h) .. tag)
		clearOfButtons(ui, card, "the bubble" .. tag)
		local target = UI.COACH[i].target()
		ok(target and H.visible(target), "its target shows" .. tag)
		if wantTarget[i] then
			eq(target, wantTarget[i](), "it points at the real control" .. tag)
			ok(apart(cr, H.rect(target)), "the bubble does not cover what it points at" .. tag)
			local rr, tr = H.rect(card.ring), H.rect(target)
			ok(rr.l < tr.l and rr.l > tr.l - 6 and rr.b < tr.b and rr.b > tr.b - 6 and rr.w > tr.w and rr.h > tr.h, "the ring is round the target" .. tag)
		end
	end
	local drive, cog = H.rect(wantTarget[4]()), H.rect(ui.gear)
	local wr, bar = H.rect(r.env.WuberFrame), H.rect(ui.tabbar)
	ok(drive.b >= bar.b - 0.5 and drive.b + drive.h <= bar.b + bar.h + 0.5, "the Drive tab is in the bar at the bottom")
	ok(cog.b > wr.b + wr.h / 2 and cog.l > wr.l + wr.w / 2, "the cog is at the top right")
	T.clean(w)
end)

-- every soft edge or scroll bar (T.EdgeFade's holder) that shows, is not part of the panel, and is on or above the
-- panel's level inside the panel's box: it would draw as a band across the page
local function under(f, root)
	while f do
		if f == root then return true end
		f = f:GetParent()
	end
	return false
end
local function bands(c, panel)
	local bad = {}
	local pl = tonumber(panel:GetFrameLevel()) or 0
	for _, f in ipairs(c.frames or {}) do
		local fd = f.edgeFade
		if fd and fd.holder and H.visible(fd.holder) and not under(f, panel) and (tonumber(fd.holder:GetFrameLevel()) or 0) >= pl
			and not apart(H.rect(fd.holder), H.rect(panel)) then
			local hr, pr = H.rect(fd.holder), H.rect(panel)
			bad[#bad + 1] = ("holder level %d over panel %d, its bottom %d above the panel's"):format(fd.holder:GetFrameLevel(), pl, hr.b - pr.b)
		end
	end
	return bad
end

-- (the lead turned this into a test once Screens.lua got its small lift) The band across every Settings picture is the soft bottom edge and the
-- scroll bar of the driver's pushed screen underneath (Wuber/UI/Driver/Screens.lua:163, T.Scroll(f) with the default
-- lift of 40: its holder is 23 to 28 levels ABOVE the Settings panel). Nothing in Settings/* draws it, and Driver/*
-- is not this group's. When that scroll has a lift that keeps its holder under the Settings panel (the window's
-- level + 40), turn T.pending into test: it fails on today's code ("holder level 64 over panel 41").
test("d2 td: no soft edge or scroll bar of the page underneath draws across Settings (a driver, Messages underneath)", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet", screenW = 1024, screenH = 768 })
	T.settle(w)
	T.goOnline(d) w:advance(5)
	d.W.db.coach = true
	local UI, ui = d.W.UI, d.W.UI.state
	UI.Toggle(true) w:advance(2)
	UI.SelectTab("Drive") w:advance(3)
	-- a pushed driver's screen with a scrolled list (Messages) is the page underneath
	d.W.Driver.ShowScreen("messages") w:advance(3)
	local st = d.W.Mod("UI.Settings.Rows").st
	for _, view in ipairs({ "home", "driving", "sound" }) do
		if view == "home" then UI.OpenSettings() else UI.OpenSettings(view) end
		w:advance(3)
		ok(st.panel and H.visible(st.panel), "Settings is up (" .. view .. ")")
		local bad = bands(d, st.panel)
		eq(#bad, 0, "across Settings (" .. view .. "): " .. table.concat(bad, "; "))
		-- the only soft edges are the scrolled list's own: its bottom one at the panel's foot, just above the tab bar
		local pr, bar = H.rect(st.panel), H.rect(ui.tabbar)
		ok(math.abs(pr.b - (bar.b + bar.h)) < 0.6, "the panel ends on the tab bar")
		for _, f in ipairs(d.frames or {}) do
			local fd = f.edgeFade
			if fd and H.visible(fd.holder) and under(f, st.panel) and fd.bottom:IsShown() then
				local fr = H.rect(fd.bottom)
				ok(fr.b - pr.b <= 8, "a soft bottom edge only at the list's real end (" .. view .. "): " .. (fr.b - pr.b) .. " above the panel's foot")
			end
		end
		UI.CloseSettings(true) w:advance(2)
	end
	T.clean(w)
end)
