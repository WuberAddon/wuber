-- Tests of UI.Rider.Wrapped. Loaded by tests/run.lua with its helper table T.
-- The card once, only days 1-10, only with 3+ rides; then the chip; the story's slides (tap,
-- 6 s, paused on hover, translation and alpha only); the share text (<= 240, passes SpamReason).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function at(y, m, d, h) return os.time({ year = y, month = m, day = d, hour = h or 12, min = 0, sec = 0 }) end

-- a rider whose clock says `day` November 2026, with `n` paid October rides
local function setup(day, n)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	local env = r.env
	local realDate = env.date
	env.date = function(fmt, t)
		if fmt == "*t" and t == nil then return { year = 2026, month = 11, day = day, hour = 12, min = 0, sec = 0, wday = 3 } end
		return realDate(fmt, t)
	end
	W.db.rides = {}
	for i = 1, n do
		W.db.rides[i] = { at = at(2026, 10, i), dest = i % 2 == 0 and "Ratchet" or "Undercity", driver = "Mia Runner",
			driverKey = "mia runner", price = 5000, saved = 600 }
	end
	W.RebuildTotals()
	return w, r, W
end

local function openTrips(w, r)
	r.W.UI.Toggle(true)
	w:advance(1)
	r.W.UI.SelectTab("Trips")
	w:advance(1)
end

test("ui.rider.wrapped: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("UI.Rider.Wrapped", "tests/ui/rider/wrapped_test.lua", {
		["Mod.Due"] = "function", ["Mod.Months"] = "function", ["Mod.Card"] = "function", ["Mod.Chip"] = "function",
		["Mod.Open"] = "function", ["Mod.Close"] = "function", ["Mod.Next"] = "function", ["Mod.Prev"] = "function",
		["Mod.Slides"] = "function", ["Mod.ShareText"] = "function", ["Mod.Story"] = "function",
	})
	ok(Mod, "W.Mod(\"UI.Rider.Wrapped\")")
	eq(Mod.Story(), nil, "no story built at load")
	T.clean(w)
end)

test("ui.rider.wrapped: the card once, only days 1-10, only 3+ rides; then the chip", function()
	local w, r, W = setup(3, 4)
	local Mod = W.Mod("UI.Rider.Wrapped")
	openTrips(w, r)
	local tr = W.UI.trips
	ok(tr.wrapCard and H.visible(tr.wrapCard), "the card on the first visit")
	eq(tr.wrapCard.title.wuberText, "Your October in Azeroth is ready", "its words")
	eq(W.db.wrapped.seen, "2026-10", "seen")
	-- the next visit: the chip instead
	W.UI.SelectTab("Ride")
	w:advance(1)
	W.UI.SelectTab("Trips")
	w:advance(1)
	ok(not H.visible(tr.wrapCard), "never twice")
	ok(H.visible(tr.wrapChip), "the Wrapped chip")
	T.clean(w)
	-- day 12: no card
	w, r, W = setup(12, 4)
	eq(W.Mod("UI.Rider.Wrapped").Due(), nil, "after the 10th: no card")
	T.clean(w)
	-- 2 rides: no card
	w, r, W = setup(2, 2)
	eq(W.Mod("UI.Rider.Wrapped").Due(), nil, "under 3 rides: no card")
	T.clean(w)
end)

test("ui.rider.wrapped: round 9 C9 - reaching the summary docks the secure share button at once", function()
	local w, r, W = setup(3, 5)
	local Mod = W.Mod("UI.Rider.Wrapped")
	openTrips(w, r)
	W.InGroup = function() return true end
	ok(Mod.Open(2026, 10), "opens")
	local st = Mod.Story()
	local b = r.env.WuberShareButton
	for _ = 1, #st.slides - 1 do Mod.Next() end
	ok(st.slides[st.index].summary, "on the summary")
	ok(H.visible(st.share), "the Share pill")
	ok(b:IsShown(), "the secure button is there before the window's next tick")
	eq(("%.1f,%.1f"):format(b:GetCenter()), ("%.1f,%.1f"):format(st.share:GetCenter()), "over the pill")
	Mod.Close()
	T.clean(w)
end)

test("ui.rider.wrapped: the story (slides, tap, 6 s, paused on hover, no scale) and the share text", function()
	local w, r, W = setup(3, 5)
	local Mod = W.Mod("UI.Rider.Wrapped")
	openTrips(w, r)
	ok(Mod.Open(2026, 10), "opens")
	local st = Mod.Story()
	ok(H.visible(st), "the story shows")
	eq(#st.slides, 5, "five slides (no driving that month)")
	eq(st.index, 1, "the first slide")
	eq(st.slide.big.wuberText, "5 summons", "rides")
	w:advance(6.5)
	eq(st.index, 2, "6 s: the next slide")
	eq(st.slide.big.wuberText, "about 50 min", "time saved, an estimate")
	-- hover pauses
	st.right:GetScript("OnEnter")(st.right)
	w:advance(10)
	eq(st.index, 2, "paused while hovered")
	st.right:GetScript("OnLeave")(st.right)
	st.right:Click()
	w:advance(0.1)
	eq(st.index, 3, "tap right: next")
	st.left:Click()
	w:advance(0.1)
	eq(st.index, 2, "tap left: back")
	for _, f in ipairs({ st, st.slide }) do
		local sc = H.state[f].scale
		ok(sc == nil or sc == 1, "no scale")
	end
	-- the share line
	local line = Mod.ShareText(W.Mod("Core.Wrapped").Month(2026, 10))
	eq(line, "My October on Wuber: 5 summons, about 50 min saved, favourite driver Mia.", "share text")
	ok(#line <= 240, "<= 240")
	eq(W.SpamReason(line), nil, "passes SpamReason")
	-- (round 9, C1) hours: "3 h 20 min" has short words on purpose; the line is still shared
	local long = Mod.ShareText({ name = "October", rides = 5, saved = 12000, topDriver = "Mia" })
	eq(long, "My October on Wuber: 5 summons, 3 h 20 min saved, favourite driver Mia.", "hours: still a share line")
	eq(Mod.ShareText({ name = "October", rides = 5, saved = 480, topDriver = "Cheap Gold" }), nil, "a spam word in a name: no line")
	-- a driving month adds the driver's slide
	W.db.drive = W.db.drive or {}
	W.db.drive.log = { rides = { at(2026, 10, 5, 20) .. ",5000,Dan,Undercity,t,5000" } }
	eq(#Mod.Slides(W.Mod("Core.Wrapped").Month(2026, 10)), 6, "the driver's slide")
	Mod.Close()
	ok(not H.visible(st), "closed")
	T.clean(w)
end)

-- (round 13, I1) a reviewer's shots 20-23: the story was see-through ('1h 50m', 'Bronze Rider' and the
-- milestones ghosted through it) and, unfolded, had a second x in the middle of the window. While
-- the story shows nothing of the Trips page shows under it (folded: the tab; unfolded: the side
-- pane under the month list too), its backgrounds are solid, and there is one x of its own, at the
-- window's right edge; closing it brings Trips back.
test("ui.rider.wrapped r13 I1: nothing of Trips shows under the story; one x, at the right", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	w:advance(15)
	local W = r.W
	local env = r.env
	local realDate = env.date
	env.date = function(fmt, t)
		if fmt == "*t" and t == nil then return { year = 2026, month = 11, day = 20, hour = 12, min = 0, sec = 0, wday = 3 } end
		return realDate(fmt, t)
	end
	W.db.rides = {}
	for i = 1, 12 do
		W.db.rides[i] = { at = at(2026, 10, i), dest = i % 2 == 0 and "Ratchet" or "Undercity", driver = "Mia Runner",
			driverKey = "mia runner", price = 5000, saved = 600 }
	end
	W.RebuildTotals()
	local UI = W.UI
	local Mod = W.Mod("UI.Rider.Wrapped")
	local S = H.state
	UI.Toggle(true)
	w:advance(1)
	local function under(obj, root)
		local p = obj
		while p do
			if p == root then return true end
			p = S[p] and S[p].parent
		end
		return false
	end
	local function shown(obj)
		local ok2, a = pcall(function() return obj:GetEffectiveAlpha() end)
		return H.visible(obj) and (not ok2 or (tonumber(a) or 1) > 0.05)
	end
	for _, wide in ipairs({ false, true }) do
		local what = wide and "unfolded" or "folded"
		r.wide = wide
		W.db.fold = (not wide) and { v = 1, pages = {}, narrow = true } or nil
		UI.Fold.Apply()
		w:advance(1)
		UI.SelectTab("Ride")
		w:advance(0.5)
		UI.SelectTab("Trips")
		w:advance(1)
		ok(shown(UI.trips.hero), what .. ": Trips shows")
		ok(Mod.Open(2026, 10), what .. ": the story opens")
		w:advance(1)
		local st = Mod.Story()
		local covers = { st }
		if wide then
			ok(Mod.Summary() and shown(Mod.Summary()), what .. ": the month list shows in the side pane")
			covers[2] = Mod.Summary()
		end
		-- (design 2, C) the header's buttons lie over every page: the fold button's word is not Trips text
		covers[#covers + 1] = UI.state.top
		for _, cv in ipairs(covers) do
			if cv.bg then
				local _, _, _, a = cv.bg:GetVertexColor()
				local col = S[cv.bg].color
				a = col and col[4] or a
				eq(a, 1, what .. ": a solid background")
			end
		end
		local bad = {}
		for _, obj in ipairs(r.widgets) do
			local s = S[obj]
			if s and s.otype == "FontString" and s.text and tostring(s.text):match("%S") and shown(obj) then
				local mine = false
				for _, cv in ipairs(covers) do if under(obj, cv) then mine = true end end
				if not mine then
					local fr = H.rect(obj)
					for _, cv in ipairs(covers) do
						local cr = H.rect(cv)
						if fr and cr and fr.l < cr.l + cr.w - 2 and fr.l + fr.w > cr.l + 2 and fr.b < cr.b + cr.h - 2 and fr.b + fr.h > cr.b + 2 then
							bad[#bad + 1] = tostring(s.text)
							break
						end
					end
				end
			end
		end
		eq(#bad, 0, what .. ": Trips text under the story: " .. table.concat(bad, " | "))
		-- one x of the story's own, at the window's right edge
		local xs = {}
		for _, b in ipairs({ st.close, Mod.Summary() and Mod.Summary().close }) do
			if b and shown(b) then xs[#xs + 1] = b end
		end
		eq(#xs, 1, what .. ": one x for the story")
		if xs[1] then
			local br, wr = H.rect(xs[1]), H.rect(UI.state.win)
			ok(br.l + br.w >= wr.l + wr.w - 30, what .. ": the x at the window's right edge (" .. (br.l + br.w) .. " vs " .. (wr.l + wr.w) .. ")")
		end
		Mod.Close()
		w:advance(1)
		ok(not Mod.Shown(), what .. ": closed")
		ok(shown(UI.trips.hero), what .. ": Trips is back")
	end
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)
