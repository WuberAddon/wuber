-- Tests of UI.Moments (round 13, A). Loaded by tests/run.lua with its helper table T.
--   I3: a raincheck offered while the app is open sits inside the phone (folded and unfolded), never
--   over its edge, the tabs or the top buttons; with the app closed it stays at the top of the screen.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function inside(a, b, slop)
	slop = slop or 0.5
	return a.l >= b.l - slop and a.l + a.w <= b.l + b.w + slop and a.b >= b.b - slop and a.b + a.h <= b.b + b.h + slop
end

test("ui.moments r13 I3: the raincheck card sits inside the phone, folded and unfolded", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	w:advance(15)
	local W = c.W
	local UI = W.UI
	local R = W.Raincheck
	local n = 0
	R.Mine = function()
		return { { id = "rc" .. n, state = "offered", driver = "Anita Lift", cover = 5000, expires = os.time({ year = 2026, month = 11, day = 19, hour = 12, min = 0, sec = 0 }) + 6 * 86400 } }
	end
	UI.Toggle(true)
	w:advance(3)
	local win = UI.state.win
	-- the window over to the left, away from the top of the screen (as a player may drag it)
	win:ClearAllPoints()
	win:SetPoint("TOPLEFT", c.env.UIParent, "TOPLEFT", 100, -200)
	for _, wide in ipairs({ false, true }) do
		c.wide = wide
		W.db.fold = (not wide) and { v = 1, pages = {}, narrow = true } or nil
		UI.Fold.Apply()
		w:advance(1)
		n = n + 1
		local f = UI.RaincheckOffer()
		w:advance(1)
		local what = wide and "unfolded" or "folded"
		ok(f and H.visible(f), what .. ": the card shows")
		-- (Design 2) the offer is a sheet over the phone: its card is the full width at the foot
		local fr, wr = H.rect(f.card or f), H.rect(win)
		ok(inside(fr, wr), what .. (": the card is inside the window (card %d..%d x %d..%d, window %d..%d x %d..%d)"):format(
			fr.l, fr.l + fr.w, fr.b, fr.b + fr.h, wr.l, wr.l + wr.w, wr.b, wr.b + wr.h))
		-- below the top bar (tabs, fold, settings, close)
		ok(fr.b + fr.h <= wr.b + wr.h - 50, what .. ": clear of the top bar")
		local tb = H.rect(UI.state.tabbar)
		ok(math.abs(fr.w - wr.w) < 1 and math.abs(fr.b - (tb.b + tb.h)) < 1, what .. ": the full width, resting on the tab bar")
		ok(H.STRATA_RANK(f:GetFrameStrata()) >= H.STRATA_RANK(win:GetFrameStrata()), what .. ": drawn over the window")
		f:Hide()
	end
	-- the app closed: the card at the top of the screen, on the screen
	UI.Toggle(false)
	w:advance(1)
	n = n + 1
	local f = UI.RaincheckOffer()
	w:advance(1)
	ok(f and H.visible(f), "closed app: the card shows")
	local fr = H.rect(f)
	local sw, sh = c.env.UIParent:GetWidth(), c.env.UIParent:GetHeight()
	ok(fr.l >= 0 and fr.l + fr.w <= sw and fr.b >= 0 and fr.b + fr.h <= sh, "closed app: on the screen")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

-- (round 13 review) the window has its own scale (the Window size slider: 0.4 to 2): the card is scaled
-- with it while the app is open, so it stays inside the phone and under its top bar at any size.
test("ui.moments r13 I3: the raincheck card fits the phone at window scales 0.7 and 1.6", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1200 })
	w:advance(15)
	local W = c.W
	local UI = W.UI
	local n = 0
	W.Raincheck.Mine = function()
		return { { id = "rs" .. n, state = "offered", driver = "Anita Lift", cover = 5000, expires = os.time({ year = 2026, month = 11, day = 19, hour = 12, min = 0, sec = 0 }) + 6 * 86400 } }
	end
	UI.Toggle(true)
	w:advance(3)
	local win = UI.state.win
	for _, scale in ipairs({ 0.7, 1.6 }) do
		W.db.scale = scale
		UI.ApplyScale()
		w:advance(1)
		win:ClearAllPoints()
		win:SetPoint("TOPLEFT", c.env.UIParent, "TOPLEFT", 40, -20)
		local eff = win:GetEffectiveScale() / c.env.UIParent:GetEffectiveScale()
		ok(math.abs(eff - scale) < 0.01, "the window is at " .. scale .. " (" .. eff .. ")")
		for _, wide in ipairs({ false, true }) do
			c.wide = wide
			W.db.fold = (not wide) and { v = 1, pages = {}, narrow = true } or nil
			UI.Fold.Apply()
			w:advance(1)
			n = n + 1
			local f = UI.RaincheckOffer()
			w:advance(1)
			local what = ("scale %s, %s"):format(scale, wide and "unfolded" or "folded")
			ok(f and H.visible(f), what .. ": the card shows")
			local fr, wr = H.rect(f.card or f), H.rect(win)
			ok(inside(fr, wr), what .. (": inside the window (card %d..%d x %d..%d, window %d..%d x %d..%d)"):format(
				fr.l, fr.l + fr.w, fr.b, fr.b + fr.h, wr.l, wr.l + wr.w, wr.b, wr.b + wr.h))
			ok(fr.b + fr.h <= wr.b + wr.h - 56 * scale, what .. (": under the top bar (card top %d, window top %d)"):format(fr.b + fr.h, wr.b + wr.h))
			ok(math.abs(fr.w - wr.w) < 1, what .. ": the sheet is the window's width (" .. fr.w .. ")")
			f:Hide()
		end
	end
	-- the app closed: the card at its own size again, at the top of the screen
	UI.Toggle(false)
	w:advance(1)
	n = n + 1
	local f = UI.RaincheckOffer()
	w:advance(1)
	ok(f and H.visible(f), "closed app: the card shows")
	local fr = H.rect(f)
	ok(math.abs(fr.w - 310) < 1, "closed app: its own size (" .. fr.w .. ")")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

-- (round 20, B7) shot 17: the white location pill on the home map pokes out behind the raincheck sheet: hidden while it shows
test("ui.moments r20 B7: the map location pill is hidden while the raincheck sheet shows, back after", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	w:advance(15)
	local W = c.W
	local UI = W.UI
	W.Raincheck.Mine = function()
		-- (speed round) the game's clock, not the real one: "until <date>" on the sheet must not change with the day the suite runs
		return { { id = "rcB7", state = "offered", driver = "Anita Lift", cover = 5000, expires = c.env.time() + 6 * 86400 } }
	end
	UI.Toggle(true)
	w:advance(3)
	local zone = UI.state.screens.home.map.zone
	ok(H.visible(zone), "before the offer the pill shows")
	local f = UI.RaincheckOffer()
	w:advance(1)
	ok(f and H.visible(f), "the sheet shows")
	ok(not H.visible(zone), "the pill is hidden behind the sheet")
	f:Hide()
	w:advance(1)
	ok(H.visible(zone), "the sheet gone: the pill is back")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)
