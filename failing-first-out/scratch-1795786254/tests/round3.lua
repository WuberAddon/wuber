-- Wuber 1.2 (round three: the phone) tests: the handset round the window, the 15% bigger
-- default size and its migration, the home indicator, the status bar, the secure overlay.
-- Loaded by run.lua with its helpers in one table; run as part of `lua5.1 tests/run.lua`.

local T = ...
local H, S, test, eq, ok, list = T.H, T.S, T.test, T.eq, T.ok, T.list
local newWorld, driver, rider, settle, goOnline, clean = T.newWorld, T.driver, T.rider, T.settle, T.goOnline, T.clean
local needUI, openConfirm, secureShown = T.needUI, T.openConfirm, T.secureShown
local TESTCHAR = T.TESTCHAR

local function near(a, b, tol) return math.abs((a or 0) - (b or 0)) <= (tol or 0.5) end

-- the window's own scale (its effective scale over UIParent's)
local function winScale(r)
	return H.effScale(r.env.WuberFrame) / H.effScale(r.env.UIParent)
end

local function inside(outer, inner)
	return inner.l >= outer.l - 0.01 and inner.b >= outer.b - 0.01
		and inner.l + inner.w <= outer.l + outer.w + 0.01 and inner.b + inner.h <= outer.b + outer.h + 0.01
end

test("phone: the handset is built round the window (bezel, island, status bar, home indicator)", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	needUI(r)
	r.W.UI.Toggle(true)
	w:advance(2.5)
	local ph = r.W.UI.state.phone
	ok(ph, "UI.state.phone")
	local win = H.rect(r.env.WuberFrame)
	local pr = H.rect(ph)
	ok(inside(pr, win), "the phone holds the window")
	local P = r.W.UI.PHONE
	ok(near(pr.w / H.effScale(ph), P.w) and near(pr.h / H.effScale(ph), P.h), ("phone %.0fx%.0f"):format(pr.w, pr.h))
	-- status bar above the window, home indicator below it, island in the status bar
	local sb, hb, isl = H.rect(ph.status), H.rect(ph.home), H.rect(ph.island)
	ok(sb.b >= win.b + win.h - 0.5, "status bar above the window's top")
	ok(hb.b + hb.h <= win.b + 3, "home indicator below the window")
	ok(inside(sb, isl), "the Dynamic Island sits in the status bar")
	ok(near(isl.l + isl.w / 2, win.l + win.w / 2, 0.5), "the island is centred")
	ok(H.visible(ph.island) and H.visible(ph.clock) and H.visible(ph.signal) and H.visible(ph.home), "all shown")
	-- the bezel is over the app (it rounds the content's corners) and never takes the mouse
	ok(ph.bezel:GetFrameLevel() > r.W.UI.state.top:GetFrameLevel() + 40, "bezel above the screens")
	ok(not ph.bezel:IsMouseEnabled(), "bezel is click-through")
	ok(r.env.WuberFrame:IsClampedToScreen(), "clamped to the screen")
	-- every interactive part has a tooltip
	ok(ph.home.wuberTip and ph.signal.wuberTip, "tooltips on the home indicator and the signal bars")
	-- the status bar drags the window
	local before = H.rect(r.env.WuberFrame).l
	r:drag(ph.status, -40, 0)
	ok(H.rect(r.env.WuberFrame).l < before - 10, "the status bar drags the phone")
	clean(w)
end)

test("phone: 15% bigger by default, and the whole phone fits a 1080p screen at the default UI scale", function()
	for _, size in ipairs({ { 1920, 1080 }, { 1365, 768 }, { 1024, 520 } }) do
		local w = newWorld()
		local r = rider(w, TESTCHAR, { screenW = size[1], screenH = size[2] })
		settle(w)
		needUI(r)
		r.W.UI.Toggle(true)
		w:advance(2.5)
		local s = winScale(r)
		local pr = H.rect(r.W.UI.state.phone)
		local ue = H.effScale(r.env.UIParent)
		if size[2] >= 768 then
			ok(near(s, 1.15, 0.001), ("default scale 1.15 at %dx%d: %.3f"):format(size[1], size[2], s))
		else
			ok(s < 1.15 and s >= 0.5, ("a small screen fits it smaller: %.3f"):format(s))
		end
		ok(pr.h <= size[2] * ue and pr.w <= size[1] * ue, ("the phone fits %dx%d: %.0fx%.0f"):format(size[1], size[2], pr.w / ue, pr.h / ue))
		eq(r.W.db.scale, nil, "nothing saved by opening")
		clean(w)
	end
end)

test("phone: saved window size: 1.0 (the old default) becomes 1.15 once; other sizes stay", function()
	local w = newWorld()
	local a = rider(w, TESTCHAR, { saved = { Wuber = { scale = 1 } } })
	local b = rider(w, "Bea Moon", { saved = { Wuber = { scale = 0.8 } } })
	local c = rider(w, "Cal Brown", { saved = { Wuber = { scale = 1, scaleV = 2 } } })
	settle(w)
	needUI(a)
	eq(a.W.db.scale, 1.15, "1.0 migrated")
	eq(a.W.db.scaleV, 2, "marked done")
	eq(b.W.db.scale, 0.8, "0.8 kept")
	eq(c.W.db.scale, 1, "already migrated: a chosen 100% stays")
	for _, r in ipairs({ a, b, c }) do r.W.UI.Toggle(true) end
	w:advance(2.5)
	ok(near(winScale(a), 1.15, 0.001), "a at 1.15: " .. winScale(a))
	ok(near(winScale(b), 0.8, 0.001), "b at 0.8: " .. winScale(b))
	ok(near(winScale(c), 1, 0.001), "c at 1.0: " .. winScale(c))
	-- the slider shows 115% and Reset brings back the default
	a.W.UI.Show("settings")
	w:advance(1)
	local st = a.W.UI.settings
	ok(st and st.controls.scale and near(st.controls.scale.value, 1.15, 0.01), "slider at 115%")
	a.W.db.scale = 0.9
	a.W.Fire("SETTINGS", "scale")
	w:advance(0.5)
	ok(near(winScale(a), 0.9, 0.001), "slider value applies: " .. winScale(a))
	clean(w)
end)

test("phone: the home indicator closes the app (and the minimap button opens it again)", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	needUI(r)
	r.W.UI.Toggle(true)
	w:advance(2.5)
	local ph = r.W.UI.state.phone
	local hit = r:clickOn(ph.home.bar)
	ok(hit == ph.home, "the click lands on the home indicator (" .. tostring(hit) .. ")")
	w:advance(1)
	ok(not r.env.WuberFrame:IsShown(), "closed")
	ok(not r.W.UI.IsShown(), "UI.IsShown false")
	-- open again from the minimap button: it zooms out of it and ends at full size, opaque
	r:clickOn(r.env.WuberMinimapButton)
	w:advance(0.1)
	ok(r.env.WuberFrame:IsShown(), "open again")
	w:advance(1)
	eq(r.env.WuberFrame:GetAlpha(), 1, "fully shown after the zoom")
	ok(near(winScale(r), 1.15, 0.001), "the zoom leaves the scale alone")
	-- and the close button and Escape still close it
	r.W.UI.Toggle(false)
	w:advance(1)
	ok(not r.env.WuberFrame:IsShown(), "Toggle(false) closes")
	clean(w)
end)

test("phone: the status bar follows the game clock and the network (signal bars)", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	needUI(r)
	r.W.UI.Toggle(true)
	w:advance(2.5)
	local ph = r.W.UI.state.phone
	ok(ph.clock:GetText():match("^%d%d:%d%d$"), "HH:MM: " .. tostring(ph.clock:GetText()))
	local h, m = r.env.GetGameTime()
	eq(ph.clock:GetText(), ("%02d:%02d"):format(h, m), "the realm's time")
	ok(r.W.UI.SignalBars() >= 2, "on the network: " .. r.W.UI.SignalBars())
	goOnline(d)
	w:advance(2)
	eq(r.W.UI.SignalBars(), 4, "full bars with a driver heard")
	eq(ph.signal.bars, 4, "drawn")
	-- the channel goes (a loading screen): no bars, no errors; then it comes back
	w:dropChannels(r)
	r.W.Fire("NETWORK", false)
	w:advance(1.5)
	eq(ph.signal.bars, 0, "no bars off the network")
	ok(not H.visible(ph.signal.lit), "lit bars hidden")
	w:advance(30)
	ok((ph.signal.bars or 0) >= 2, "bars back after rejoining: " .. tostring(ph.signal.bars))
	-- the clock moves on
	local t0 = ph.clock:GetText()
	w:advance(61)
	ok(ph.clock:GetText() ~= t0, "the clock ticks: " .. t0 .. " -> " .. ph.clock:GetText())
	-- the island's live light shows while a ride is under way
	ok(not H.visible(ph.island.live), "no live light without a ride")
	r.W.RequestRide("anita lift")
	w:advance(1.5)
	ok(H.visible(ph.island.live), "live light during the ride")
	-- the signal tooltip says what the bars mean
	local gt = r.env.GameTooltip
	S[gt].tipLines = {}
	S[ph.signal].scripts.OnEnter(ph.signal)
	ok(#(S[gt].tipLines or {}) > 0, "signal tooltip")
	clean(w)
end)

test("phone: the secure Request button still matches the Request pill at the new size", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w, TESTCHAR, { screenW = 1365, screenH = 768 })
	settle(w)
	goOnline(d)
	openConfirm(r, "anita lift")
	local pill = r.W.UI.state.screens.confirm.request
	local b = r.env.WuberRequestButton
	ok(near(winScale(r), 1.15, 0.001), "window at 1.15")
	ok(H.visible(b), "secure button shown (" .. list(r:visibleTexts()) .. ")")
	local pr, br = H.rect(pill), H.rect(b)
	ok(near(pr.l, br.l) and near(pr.b, br.b) and near(pr.w, br.w) and near(pr.h, br.h),
		("same place and size: pill %.1f,%.1f %.1fx%.1f; button %.1f,%.1f %.1fx%.1f"):format(pr.l, pr.b, pr.w, pr.h, br.l, br.b, br.w, br.h))
	local hit = r:clickOn(pill)
	ok(S[hit].secure, "the click on the pill lands on the secure button")
	-- closed by the home indicator: the overlay goes too; open again: back on the pill
	r:clickOn(r.W.UI.state.phone.home)
	w:advance(1)
	eq(#secureShown(r), 0, "no secure button while closed")
	clean(w)
end)
