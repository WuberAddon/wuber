-- Tests of UI.Rider.Trips (BRIEF19 F6): the folded page never slices a milestone row and says when more lies below.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- n trips in the history (the tour's rider has 11)
local function rides(W, n)
	W.db.rides = {}
	for i = 1, n do
		W.db.rides[i] = { dest = "Undercity", driver = "Mia-Kazzak", at = 1763600000 + i * 3600, saved = 600, price = 5000, stars = 5 }
	end
end

test("ui.rider.trips: folded view leaves out a sliced milestone row and shows the scroll cue", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local W = r.W
	W.UI.Toggle(true)
	w:advance(1)
	W.UI.SelectTab("Trips")
	w:advance(1)
	local tr = W.Mod("UI.Rider.Trips").view()
	W.UI.UpdateTrips()
	local clipH = tr.clip:GetHeight()
	ok(tr.scrollMax > 0, "the page is taller than its view")
	ok(tr.cue:IsShown(), "cue shown while more lies below")
	eq(tr.cue.label:GetText(), "Scroll for your trips")
	-- no cell is half inside the view
	for _, c in ipairs(tr.cells) do
		if c.m then
			local top = tr.gridTop + math.floor((c.index - 1) / 4) * 96 - tr.scroll
			if c:IsShown() then ok(top + 96 <= clipH + 0.5 and top >= -0.5, "shown medal " .. c.index .. " is whole") end
			if top + 96 > clipH + 0.5 then ok(not c:IsShown(), "sliced medal " .. c.index .. " is left out") end
		end
	end
	-- at the bottom the cue goes
	tr.scroll, tr.scrollTarget = tr.scrollMax, tr.scrollMax
	W.Mod("UI.Rider.Trips").trimCells()
	ok(not tr.cue:IsShown(), "no cue at the end")
end)

test("ui.rider.trips: F6 the scroll cue never covers a trip row, folded and unfolded", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local W = r.W
	rides(W, 11)
	W.UI.Toggle(true)
	w:advance(1)
	for _, wide in ipairs({ false, true }) do
		local what = wide and "unfolded" or "folded"
		r.wide = wide
		W.db.fold = (not wide) and { v = 1, pages = {}, narrow = true } or nil
		W.UI.Fold.Apply()
		w:advance(1)
		W.UI.SelectTab("Ride")
		w:advance(0.5)
		W.UI.SelectTab("Trips")
		w:advance(1)
		local M = W.Mod("UI.Rider.Trips")
		local tr = M.view()
		W.UI.UpdateTrips()
		local clipH = tr.clip:GetHeight()
		local sawCue = false
		for y = 0, math.floor(tr.scrollMax or 0), 20 do
			tr.scroll, tr.scrollTarget = y, y
			M.trimCells()
			if tr.cue:IsShown() then
				sawCue = true
				-- the cue's strip is the bottom 30 px of the view: no visible row may reach into it
				for i, row in ipairs(tr.rows) do
					if row:IsShown() and row:GetAlpha() > 0 then
						local bottom = tr.listTop + (i - 1) * 54 + 48 - y
						ok(bottom <= clipH - 30 + 0.5, what .. ": row " .. i .. " clear of the cue at scroll " .. y)
					end
				end
			end
		end
		ok(sawCue or (tr.scrollMax or 0) <= 1, what .. ": the cue shows when content continues")
		tr.scroll, tr.scrollTarget = tr.scrollMax or 0, tr.scrollMax or 0
		M.trimCells()
		ok(not tr.cue:IsShown(), what .. ": no cue at the end")
		for i, row in ipairs(tr.rows) do
			if row.live then ok(row:IsShown() and row:GetAlpha() > 0, what .. ": row " .. i .. " drawn at the end") end
		end
	end
end)

-- (BRIEF20 B2, tour 19) the real client reports a clip's height as 0 until it has laid the clip out
-- (the unfolded page, right after the window re-anchored). The rows must still show, the cue only
-- while rows are hidden below, and never over a drawn row (geometry, not fields).
local function drawn(f) return f:IsVisible() and f:GetAlpha() > 0 end
local function check(tr, what)
	local clipTop, clipBottom = tr.clip:GetTop(), tr.clip:GetBottom()
	local cueTop = tr.cue:IsVisible() and tr.cue:GetTop() or nil
	local inView, hiddenBelow = 0, 0
	for i, row in ipairs(tr.rows) do
		if row.live then
			local top, bottom = row:GetTop(), row:GetBottom()
			local fits = top <= clipTop + 0.5 and bottom >= clipBottom - 0.5 and (not cueTop or bottom >= cueTop - 0.5)
			if drawn(row) then
				-- (a row scrolled up past the top edge is clipped there, as the page scrolls)
				ok(bottom >= clipBottom - 0.5, what .. ": drawn row " .. i .. " is not sliced by the bottom edge")
				if cueTop then ok(bottom >= cueTop - 0.5, what .. ": the cue is not over row " .. i) end
				inView = inView + 1
			else
				ok(not fits, what .. ": row " .. i .. " fits in the view, so it is drawn")
				if bottom < clipBottom + 60 then hiddenBelow = hiddenBelow + 1 end
			end
		end
	end
	if tr.cue:IsVisible() then ok(hiddenBelow > 0 or tr.scrollMax > 1, what .. ": the cue only while rows lie below") end
	return inView
end

test("ui.rider.trips: B2 unfolded rows show and the cue never covers one, even before the view is laid out", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local W = r.W
	local M = W.Mod("UI.Rider.Trips")
	for _, n in ipairs({ 11, 2 }) do
		rides(W, n)
		W.UI.Toggle(true)
		w:advance(1)
		for _, wide in ipairs({ false, true }) do
			local what = (wide and "unfolded" or "folded") .. ", " .. n .. " trips"
			r.wide = wide
			W.db.fold = (not wide) and { v = 1, pages = {}, narrow = true } or nil
			W.UI.SelectTab("Ride")
			w:advance(0.5)
			local tr = M.view()
			-- the switch happens while the game has not laid the clip out yet
			tr.clip.GetHeight = function() return 0 end
			W.UI.Fold.Apply()
			W.UI.SelectTab("Trips")
			W.UI.Fold.Apply()
			tr.clip.GetHeight = nil
			w:advance(1)
			eq(W.UI.Fold.IsUnfolded(), wide, what .. ": the fold")
			eq(tr.scroll, 0, what .. ": at the top")
			local inView = check(tr, what)
			if wide then
				ok(inView >= 2, what .. ": trip rows are drawn under Your trips (" .. inView .. ")")
				if n == 2 then ok(not tr.cue:IsShown(), what .. ": no cue when every trip fits") end
				if tr.cue:IsShown() then eq(tr.cue.label:GetText(), "Scroll for more", what .. ": Your trips is in view") end
			end
			-- scrolled through: still no row under the cue, and every row drawn at the end
			local function at(y)
				tr.scroll, tr.scrollTarget = y, y
				tr.content:ClearAllPoints()
				tr.content:SetPoint("TOPLEFT", tr.clip, "TOPLEFT", 0, y)
				M.trimCells()
			end
			for y = 0, math.floor(tr.scrollMax or 0), 37 do
				at(y)
				check(tr, what .. " at " .. y)
			end
			at(tr.scrollMax or 0)
			ok(not tr.cue:IsShown(), what .. ": no cue at the end")
			check(tr, what .. " at the end")
			at(0)
		end
		W.UI.Toggle(false)
		w:advance(1)
	end
end)

-- guard: the neighbouring path: on the base the cue does not cover the Wrapped card in this window; group A (E1-10) owns the case after the Wrapped story
test("ui.rider.trips: E3b-02 cue stays visible while content lies below without overlapping Wrapped card", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W, env = r.W, r.env
	local realDate = env.date
	env.date = function(fmt, t)
		if fmt == "*t" and t == nil then return { year = 2026, month = 11, day = 3, hour = 12, min = 0, sec = 0, wday = 3 } end
		return realDate(fmt, t)
	end
	local oct = os.time({ year = 2026, month = 10, day = 10, hour = 12, min = 0, sec = 0 })
	W.db.rides = {}
	for i = 1, 6 do
		W.db.rides[i] = { at = oct + i * 3600, dest = "Ratchet", driver = "Mia Runner",
			driverKey = "mia runner", price = 5000, saved = 600 }
	end
	W.db.fold = { v = 1, pages = {}, narrow = true }
	W.RebuildTotals()
	W.UI.Toggle(true) w:advance(1)
	W.UI.SelectTab("Trips") w:advance(1)
	local M = W.Mod("UI.Rider.Trips")
	local tr = M.view()
	ok(tr.wrapCard and tr.wrapCard:IsShown(), "Wrapped card is visible on first visit")
	for _, clipH in ipairs({ 453, 500 }) do
		tr.clip.GetHeight = function() return clipH end
		M.fit()
		ok(tr.wrapCard:IsShown(), "Wrapped card stays visible (clipH=" .. clipH .. ")")
		local clipBot = tr.clip:GetBottom()
		for y = 0, math.floor(tr.scrollMax or 0), 20 do
			tr.scroll, tr.scrollTarget = y, y
			tr.content:ClearAllPoints()
			tr.content:SetPoint("TOPLEFT", tr.clip, "TOPLEFT", 0, y)
			M.trimCells()
			local below = (tr.scrollMax or 0) - y
			if below > 1 then
				ok(tr.cue:IsShown(), "scroll cue stays visible while content lies below (clipH=" .. clipH .. ", y=" .. y .. ")")
				local qt, qb = tr.cue:GetTop(), tr.cue:GetBottom()
				local wt, wb = tr.wrapCard:GetTop(), tr.wrapCard:GetBottom()
				if qt and qb and wt and wb then
					local overlapY = qt > wb + 0.5 and qb < wt - 0.5
					ok(not overlapY, "cue never lies across Wrapped card (clipH=" .. clipH .. ", y=" .. y .. ")")
				end
			else
				ok(not tr.cue:IsShown(), "cue hides at bottom (clipH=" .. clipH .. ", y=" .. y .. ")")
			end
		end
		if clipH == 453 then
			tr.scroll, tr.scrollTarget = 0, 0
			tr.content:ClearAllPoints()
			tr.content:SetPoint("TOPLEFT", tr.clip, "TOPLEFT", 0, 0)
			M.trimCells()
			local wb = tr.wrapCard:GetBottom()
			if wb and clipBot then
				ok(wb >= clipBot - 0.5, "Wrapped card stays whole inside clip at scroll 0 (clipH=" .. clipH .. ")")
			end
			ok(tr.wrapCard:IsMouseEnabled(), "Wrapped card stays clickable")
		end
	end
	T.clean(w)
end)
