-- Tests for E3b-05 (REV-d3-2 / D3-10): root page titles ("Settings", "Trips", "Earnings")
-- are drawn large ("display", 28) on the page itself, not small ("heading", 17) in the header bar,
-- with no overlap or clipping at both folded and wide sizes.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function R(f) return H.rect(f) end

local function fontSize(fs)
	local _, sz = fs:GetFont()
	return sz and math.floor(sz + 0.5) or 0
end

local function apart(a, b)
	local ra, rb = R(a), R(b)
	if not (ra and rb) then return false end
	return (ra.l + ra.w <= rb.l + 0.5) or (rb.l + rb.w <= ra.l + 0.5)
		or (ra.b + ra.h <= rb.b + 0.5) or (rb.b + rb.h <= ra.b + 0.5)
end

local function belowHeader(fs, win)
	local r, wr = R(fs), R(win)
	if not (r and wr) then return false, "missing rect" end
	local winTop = wr.b + wr.h
	local fsTop = r.b + r.h
	return fsTop <= winTop - 44 + 0.5, ("top %.1f vs header bottom %.1f"):format(fsTop, winTop - 44)
end

local function insideWin(fs, win)
	local r, wr = R(fs), R(win)
	if not (r and wr) then return false end
	return r.l >= wr.l - 0.5 and r.l + r.w <= wr.l + wr.w + 0.5
		and r.b >= wr.b - 0.5 and r.b + r.h <= wr.b + wr.h + 0.5
end

test("d3 e3b05: root page titles Settings, Trips and Earnings are display size on the page (not header), folded and wide", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	local d = T.driver(w, T.ANITA, { spot = "Undercity", screenW = 1920, screenH = 1080 })
	T.settle(w)

	for _, wide in ipairs({ false, true }) do
		local tag = wide and "wide" or "folded"
		r.wide = wide
		r.W.db.coach = true
		r.W.db.fold = (not wide) and { v = 1, pages = {}, narrow = true } or nil
		r.W.UI.Toggle(true)
		w:advance(1)
		r.W.UI.Fold.Apply()
		w:advance(1)

		local rUI = r.W.UI
		local rWin = rUI.state.win
		local disp = r.W.Theme.SIZE.display
		local head = r.W.Theme.SIZE.heading

		-- 1. Settings
		rUI.OpenSettings()
		w:advance(1)
		local st = rUI.settings
		ok(st.title and H.visible(st.title), tag .. " Settings: title visible")
		eq(st.title:GetText(), "Settings", tag .. " Settings: title text")
		eq(fontSize(st.title), disp, tag .. " Settings: display size (" .. disp .. ")")
		local okHead, msgHead = belowHeader(st.title, rWin)
		ok(okHead, tag .. " Settings: title below header (" .. tostring(msgHead) .. ")")
		ok(insideWin(st.title, rWin), tag .. " Settings: title inside window")
		ok(apart(st.title, st.back), tag .. " Settings: title clear of back button")
		ok(apart(st.title, rUI.state.close), tag .. " Settings: title clear of close button")
		ok(st.hint and H.visible(st.hint), tag .. " Settings: hint visible")
		ok(apart(st.title, st.hint), tag .. " Settings: title clear of hint")
		ok(apart(st.hint, st.find.box), tag .. " Settings: hint clear of search box")
		ok(apart(st.title, st.find.box), tag .. " Settings: title clear of search box")
		if wide then
			ok(st.title:GetLeft() < rUI.Fold.Pane():GetLeft(), tag .. " Settings: title in left pane")
			for _, nb in ipairs(st.nav.rows) do
				if nb:IsShown() then
					ok(apart(st.find.box, nb), tag .. " Settings: search box clear of nav row " .. tostring(nb.key))
				end
			end
		else
			ok(apart(st.find.box, st.find.home), tag .. " Settings: search box clear of home list")
		end
		rUI.CloseSettings(true)
		w:advance(1)

		-- 2. Trips
		rUI.SelectTab("Trips")
		w:advance(1)
		local tr = r.W.Mod("UI.Rider.Trips").view()
		ok(tr.title and H.visible(tr.title), tag .. " Trips: title visible")
		eq(tr.title:GetText(), "Trips", tag .. " Trips: title text")
		eq(fontSize(tr.title), disp, tag .. " Trips: display size (" .. disp .. ")")
		local okTrips, msgTrips = belowHeader(tr.title, rWin)
		ok(okTrips, tag .. " Trips: title below header (" .. tostring(msgTrips) .. ")")
		ok(insideWin(tr.title, rWin), tag .. " Trips: title inside window")
		ok(apart(tr.title, tr.hero), tag .. " Trips: title clear of Time saved hero")
		if tr.wrapChip and tr.wrapChip:IsShown() then
			ok(apart(tr.title, tr.wrapChip), tag .. " Trips: title clear of Wrapped chip")
		end
		rUI.SelectTab("Ride")
		w:advance(1)

		-- 3. Earnings
		d.wide = wide
		d.W.db.coach = true
		d.W.db.fold = (not wide) and { v = 1, pages = {}, narrow = true } or nil
		T.openDrive(d)
		d.W.UI.ShowDrive("earnings")
		w:advance(1)
		local dUI = d.W.UI
		local dWin = dUI.state.win
		local e = dUI.drive.screens.earnings
		local dDisp = d.W.Theme.SIZE.display
		ok(e.title and H.visible(e.title), tag .. " Earnings: title visible")
		eq(e.title:GetText(), "Earnings", tag .. " Earnings: title text")
		eq(fontSize(e.title), dDisp, tag .. " Earnings: display size (" .. dDisp .. ")")
		local okEarn, msgEarn = belowHeader(e.title, dWin)
		ok(okEarn, tag .. " Earnings: title below header (" .. tostring(msgEarn) .. ")")
		ok(insideWin(e.title, dWin), tag .. " Earnings: title inside window")
		ok(apart(e.title, e.back), tag .. " Earnings: title clear of back button")
		ok(apart(e.title, e.dash), tag .. " Earnings: title clear of dashboard card")
		dUI.Toggle(false)
		w:advance(1)
		rUI.Toggle(false)
		w:advance(1)
	end
	T.clean(w)
end)
