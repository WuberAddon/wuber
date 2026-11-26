local T = ...
-- Verifier V, job 415: the scrolled pages at the middle and the bottom of their range (Trips, Earnings, Settings), and the
-- coach staying up when a ride is accepted. Scrolled the way the page does it (its own scroll target / ScrollTo), rects
-- read again after the frames have run. All of these pass on the base.
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- ---- sweep helpers (scrolled pages) ----
local function isUnder(o, root)
	while o do if o == root then return true end o = o:GetParent() end
	return false
end

-- every drawn word and button under root (not under skip): { obj, r = rect, what = text or name }
local function items(root, skip, out, seen)
	out, seen = out or {}, seen or {}
	if seen[root] then return out end
	seen[root] = true
	if skip and root == skip then return out end
	if root.GetRegions then
		for _, g in ipairs({ root:GetRegions() }) do
			if g.GetText and H.visible(g) then
				local t = g:GetText()
				if type(t) == "string" and t ~= "" then
					local r = H.rect(g)
					if r and r.w > 0 and r.h > 0 then out[#out + 1] = { obj = g, r = r, what = t } end
				end
			end
		end
	end
	if root.GetObjectType and root:GetObjectType() == "Button" and H.visible(root) then
		local r = H.rect(root)
		if r and r.w > 0 and r.h > 0 then out[#out + 1] = { obj = root, r = r, what = "button " .. tostring(root:GetName() or "") } end
	end
	if root.GetChildren then
		for _, c in ipairs({ root:GetChildren() }) do items(c, skip, out, seen) end
	end
	return out
end

local function overlap(a, b)
	return a.l < b.l + b.w - 0.5 and b.l < a.l + a.w - 0.5 and a.b < b.b + b.h - 0.5 and b.b < a.b + a.h - 0.5
end
local function top(r) return r.b + r.h end

local function plain(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

local function inter(a, b)
	local l, r = math.max(a.l, b.l), math.min(a.l + a.w, b.l + b.w)
	local bo, to = math.max(a.b, b.b), math.min(a.b + a.h, b.b + b.h)
	if r <= l or to <= bo then return nil end
	return { l = l, b = bo, w = r - l, h = to - bo }
end

-- what a view shows: the items touching it
local function inView(root, view, skip)
	local out = {}
	for _, it in ipairs(items(root, skip)) do
		if it.r.b + it.r.h > view.b + 0.5 and it.r.b < view.b + view.h - 0.5 then out[#out + 1] = it end
	end
	return out
end

local function tripsWorld(n, folded)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.db.coach = true
	local oct = os.time({ year = 2026, month = 10, day = 10, hour = 12, min = 0, sec = 0 })
	W.db.rides = {}
	for i = 1, n do
		W.db.rides[i] = { at = oct + i * 3600, dest = "Ratchet", driver = "Mia Runner", driverKey = "mia runner", price = 5000, saved = 600 }
	end
	W.db.fold = { v = 1, pages = {}, narrow = folded }
	W.RebuildTotals()
	W.UI.Toggle(true) w:advance(1)
	W.UI.SelectTab("Trips") w:advance(1)
	return w, W, W.Mod("UI.Rider.Trips")
end

-- guard: break-it, Trips.lua:814 (trimCells) the rows the cue would touch no longer cut (r.cut = false): the cue lies over a trip row (run on a copy: fails)
test("h24 v bk: Trips (folded and unfolded, few and many trips): at the middle and the bottom the cue covers no word, and at the end it is gone with the last row whole", function()
	for _, folded in ipairs({ true, false }) do
		for _, n in ipairs({ 1, 3, 11, 40 }) do
			local w, W, M = tripsWorld(n, folded)
			local tr = M.view()
			local smax = math.floor(tr.scrollMax or 0)
			local tag = (folded and "folded " or "unfolded ") .. n .. " trips"
			local ys = { math.floor(smax / 4), math.floor(smax / 2), math.floor(smax * 3 / 4), smax }
			for _, y in ipairs(ys) do
				tr.scrollTarget = y
				for _ = 1, 30 do w:advance(0.1) if tr.scroll == y then break end end
				w:advance(0.2)
				local where = tag .. " at " .. y .. " of " .. smax
				local view = H.rect(tr.clip)
				local cueUp = tr.cue:IsShown()
				eq(cueUp, (smax - y) > 1, where .. ": the cue shows exactly while content lies below")
				local cue = H.rect(tr.cue)
				for _, it in ipairs(inView(tr.content, view)) do
					if cueUp then ok(not overlap(it.r, cue), where .. ": the cue lies over '" .. plain(it.what):sub(1, 24) .. "'") end
				end
				if y == smax then
					local low
					for _, it in ipairs(inView(tr.content, view)) do if not low or it.r.b < low.r.b then low = it end end
					ok(low and low.r.b >= view.b - 0.5, where .. ": the last row is whole inside the view (" .. tostring(low and low.r.b - view.b) .. ")")
				end
			end
			T.clean(w)
		end
	end
end)

-- guard: break-it, Trips.lua:238 the big title anchored -60 instead of -4: it lies over the next row (run on a copy: fails)
test("h24 v bk: Trips (folded and unfolded) the big page title overlaps no word and no button of the page at the top", function()
	for _, folded in ipairs({ true, false }) do
		for _, n in ipairs({ 1, 11 }) do
			local w, W, M = tripsWorld(n, folded)
			local tr = M.view()
			tr.scrollTarget = 0 w:advance(0.3)
			local view = H.rect(tr.clip)
			local t = H.rect(tr.title)
			ok(t.h >= 34, "the title is display size (" .. t.h .. ")")
			for _, it in ipairs(inView(tr.content, view)) do
				if it.obj ~= tr.title then
					ok(not overlap(it.r, t), (folded and "folded " or "unfolded ") .. n .. " trips: the title lies over '" .. plain(it.what):sub(1, 24) .. "'")
				end
			end
			T.clean(w)
		end
	end
end)

local function earn(narrow)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar", screenW = 1365, screenH = 768 })
	T.settle(w)
	local W = a.W
	W.db.coach = true
	W.db.fold = { v = 1, pages = {}, narrow = narrow }
	W.SetAdvanced(true)
	T.openDrive(a)
	W.UI.ShowDrive("console") w:advance(1)
	W.Driver.ShowScreen("earnings") w:advance(2)
	return w, W, W.UI.drive.screens.earnings
end

-- guard: break-it, Earnings.lua:889 the cue strip dropped (strip = 0 while the page is taller than the view): the cue lies over the last card (run on a copy: fails)
test("h24 v bk: Earnings (folded and unfolded, Me and Crew): at top, middle and bottom the cue covers no word, the scroll area starts under the big title, and at the end the cue is gone with the last button whole", function()
	for _, narrow in ipairs({ true, false }) do
		local w, W, s = earn(narrow)
		for _, scope in ipairs({ "me", "crew" }) do
			s.scope = scope s.update() w:advance(1)
			local sc = s.scroll
			local smax = math.floor(sc.max or 0)
			for _, y in ipairs({ 0, math.floor(smax / 2), smax }) do
				sc:ScrollTo(y, true) w:advance(0.6)
				local where = (narrow and "folded " or "unfolded ") .. scope .. " at " .. y .. " of " .. smax
				local view, title = H.rect(sc), H.rect(s.title)
				ok(view.b + view.h <= title.b + 0.5, where .. ": the scroll area starts under the title")
				eq(s.cue:IsShown(), (smax - y) > 1 and (s.strip or 0) > 0, where .. ": the cue shows only while content lies below")
				local cue = H.rect(s.cue)
				for _, it in ipairs(inView(s.content, view)) do
					if s.cue:IsShown() then ok(not overlap(it.r, cue), where .. ": the cue lies over '" .. plain(it.what):sub(1, 24) .. "'") end
				end
				if y == smax then
					local low
					for _, it in ipairs(inView(s.content, view)) do if not low or it.r.b < low.r.b then low = it end end
					ok(low and low.r.b >= view.b - 0.5, where .. ": the last row is whole inside the view")
				end
			end
		end
		T.clean(w)
	end
end)

local function openS(wide, adv)
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	T.settle(w)
	c.W.db.fold = { v = 1, pages = {}, narrow = not wide }
	c.W.SetAdvanced(adv)
	c.W.db.coach = true
	c.W.UI.Toggle(true) w:advance(3)
	c.W.UI.OpenSettings() w:advance(2)
	return w, c, c.W.UI.settings, c.W.Mod("UI.Settings.Panel")
end

-- guard: break-it, Panel.lua:1415 the section clip 60 short (st.clip:SetHeight(h - 60)) or Find.lua:42 listY 144 -> 92: the last row is cut / the list reaches the title box (run on a copy: both fail)
test("h24 v bk: Settings root and every section page (folded and unfolded, Simple and Advanced): scrolled to the end the last row is whole in the view and no row reaches the title, hint or box", function()
	for _, wide in ipairs({ false, true }) do
		for _, adv in ipairs({ false, true }) do
			local w, c, st, P = openS(wide, adv)
			local tag = (wide and "unfolded " or "folded ") .. (adv and "Advanced" or "Simple")
			local home = st.find.home
			if home and H.visible(home) then
				local hr = H.rect(home)
				for _, f in ipairs({ st.title, st.hint, st.find.box }) do
					ok(hr.b + hr.h <= H.rect(f).b + 0.5, tag .. " root: the list starts under the title, hint and box")
				end
				for _, y in ipairs({ 0, math.floor((home.max or 0) / 2), math.floor(home.max or 0) }) do
					home:ScrollTo(y, true) w:advance(0.5)
				end
				local low
				for _, it in ipairs(inView(home.content, hr)) do if not low or it.r.b < low.r.b then low = it end end
				ok(low and low.r.b >= hr.b - 0.5, tag .. " root: at the end the last row is whole in the view")
			end
			for _, sec in ipairs(P.SECTIONS) do
				P.openSection(sec[1]) w:advance(2)
				if st.clip and H.visible(st.clip) then
					local cr, title = H.rect(st.clip), H.rect(st.title)
					local smin, smax = math.floor(st.scrollMin or 0), math.floor(st.scrollMax or 0)
					for _, y in ipairs({ smin, math.floor((smin + smax) / 2), smax }) do
						st.scrollTarget = y
						for _ = 1, 30 do w:advance(0.1) if st.scroll == y then break end end
						w:advance(0.2)
						for _, it in ipairs(inView(st.content, cr)) do
							local part = inter(it.r, cr)
							ok(not (part and overlap(part, title)), tag .. " " .. sec[1] .. " at " .. y .. ": '" .. plain(it.what):sub(1, 24) .. "' reaches the title")
						end
					end
					local low
					for _, it in ipairs(inView(st.content, cr)) do if not low or it.r.b < low.r.b then low = it end end
					ok(low and low.r.b >= cr.b - 0.5, tag .. " " .. sec[1] .. ": at the end the last row is whole in the view (" .. tostring(low and low.r.b - cr.b) .. ")")
				end
			end
			T.clean(w)
		end
	end
end)

-- guard: break-it, Coach.lua:256 stopCoachForNow calling hideCoach(true) instead of hideCoach(false): a ride would end the guide for good (run on a copy: fails)
test("h24 v bk: a ride accepted while the guide is on tips 2 to 5 stops it for now, never for good (W.db.coach stays false)", function()
	for tip = 2, 5 do
		local w = T.newWorld()
		local r = T.rider(w, T.TESTCHAR, { screenW = 1024, screenH = 768 })
		w:advance(15)
		local UI = r.W.UI
		local ui = UI.state
		UI.Toggle(true) w:advance(3)
		local drive = false
		for _, t in ipairs(ui.tabs) do if t.name == "Drive" then drive = true end end
		ok(drive, "control: a Drive tab is present")
		UI.CoachStep(tip) w:advance(1)
		ok(ui.coaching and ui.coach:IsShown() and ui.coachStep == tip, "control: the guide is up on tip " .. tip)
		r.W.ride = { id = "v3", driver = "Bea Jones", driverKey = "bea jones", dest = "Undercity", price = 5000, state = "accepted",
			at = r.env.GetTime(), service = "Bea's Rides" }
		r.W.Fire("RIDE")
		UI.RefreshNow() w:advance(2)
		eq(r.W.db.coach, false, "tip " .. tip .. ": the guide was not ended for good")
		ok(not ui.coaching, "tip " .. tip .. ": it is stopped for now")
		-- and it comes back on Home when the ride is over
		r.W.ride = nil
		r.W.Fire("RIDE")
		UI.RefreshNow() w:advance(1)
		ui.coachTried = false
		T.clean(w)
	end
end)
