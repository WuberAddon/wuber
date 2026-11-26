-- r49 group A (E1-10, E3b-02): the Trips scroll cue and the Wrapped card, after the Wrapped story and without it.
-- Promise: the cue shows whenever trips lie below the view and never lies across the Wrapped card, a row, a heading
-- or a milestone card (what the player SEES: a frame is cut at the clip's edge), at every scroll step, folded and
-- narrow, whatever sits above the card (0 to 3 habit chips, short or long). With no chips the first row of medals
-- (kept on at the top, round 7) reached the cue's strip: the clip now ends above the cue there too. The other
-- cases held on the base at the view's real height (the cue sits under the clip's edge or clear of the card).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- the part of a frame the player sees: its rectangle cut at the clip's edges (the cue itself is not clipped)
local function seen(f, clip)
	local t, b = f:GetTop(), f:GetBottom()
	if not (t and b) then return nil end
	local ct, cb = clip:GetTop(), clip:GetBottom()
	if ct and cb then t, b = math.min(t, ct), math.max(b, cb) end
	if t - b < 0.5 then return nil end
	return t, b
end
-- true when both are shown and the seen parts cross
local function crosses(a, b, clip)
	if not (a and b and a:IsShown() and b:IsShown()) then return false end
	local at, ab = a:GetTop(), a:GetBottom()
	local bt, bb = seen(b, clip)
	if not (at and ab and bt) then return false end
	return at > bb + 0.5 and ab < bt - 0.5
end

local LONG = "A very long chip sentence that needs the full width of the page to read"

-- a narrow (folded) rider on the first visit of November with last month's trips; nchips habit chips
local function setup(nchips, long, afterStory)
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
	for i = 1, 14 do
		W.db.rides[i] = { at = oct + i * 3600, dest = "Ratchet", driver = "Mia Runner",
			driverKey = "mia runner", price = 5000, saved = 600 }
	end
	W.db.fold = { v = 1, pages = {}, narrow = true }
	W.RebuildTotals()
	local words = {}
	for i = 1, nchips do words[i] = long and LONG or "Short chip" end
	W.UI.TripsChips = function() return words end
	W.UI.Toggle(true) w:advance(1)
	W.UI.SelectTab("Trips") w:advance(1)
	local M = W.Mod("UI.Rider.Trips")
	local tr = M.view()
	ok(tr.wrapCard and tr.wrapTop, "the Wrapped card is offered on the first visit (placed, though the cue may leave it out at the top)")
	if afterStory then
		local WR = W.Mod("UI.Rider.Wrapped")
		WR.Open(tr.wrapCard.year, tr.wrapCard.month)
		w:advance(8)
		WR.Close()
		w:advance(1)
	end
	return w, W, M, tr
end

-- every scroll step to the end, at the view's real height (nothing faked: the cue and the clip are laid
-- out by the same frames). Returns how many steps showed the card whole and how many left it out.
local function sweep(M, tr, what)
	local cardOn, cardOff, saw = 0, 0, 0
	for y = 0, math.floor(tr.scrollMax or 0) do
		tr.scroll, tr.scrollTarget = y, y
		tr.content:ClearAllPoints()
		tr.content:SetPoint("TOPLEFT", tr.clip, "TOPLEFT", 0, y)
		M.trimCells()
		M.trimCells() -- a second pass changes nothing
		local tag = what .. " (y=" .. y .. ")"
		if (tr.scrollMax or 0) - y > 1 then
			saw = saw + 1
			ok(tr.cue:IsShown(), "the cue shows while trips lie below: " .. tag)
			ok(not crosses(tr.cue, tr.wrapCard, tr.clip), "the cue is not across the Wrapped card: " .. tag)
			if tr.wrapCard:IsShown() then cardOn = cardOn + 1 else cardOff = cardOff + 1 end
			for i, r in ipairs(tr.rows) do ok(not crosses(tr.cue, r, tr.clip), "the cue is not across row " .. i .. ": " .. tag) end
			-- (milestone cards: the first row stays on at the top of the page by an earlier decision, round 7 "medals kept")
			for _, c in ipairs(tr.cells) do ok(not crosses(tr.cue, c, tr.clip), "the cue is not across a milestone card: " .. tag) end
		else
			ok(not tr.cue:IsShown(), "no cue at the end: " .. tag)
		end
	end
	ok(saw > 0, what .. ": the sweep saw the cue")
	return cardOn, cardOff
end

for _, v in ipairs({ { 2, true }, { 3, false }, { 3, true } }) do
	local n, long = v[1], v[2]
	local name = n .. " chips" .. (long and " (long)" or "")
	-- guard: promise already held on the base at the real view height (the cue sits under the clip edge or clear of the card)
	test("r49 a: the Trips cue lies across no card, row or heading at any scroll step, " .. name .. ", after the story", function()
		local w, W, M, tr = setup(n, long, true)
		local on, off = sweep(M, tr, name .. " after the story")
		-- the card shows once scrolled to where it fits
		ok(on > 0, name .. ": the card shows whole once it fits")
		T.clean(w)
	end)
end

-- guard: a Wrapped card that already fits above the cue (1 or 2 short chips) stays on at every step where it fits,
-- folded and narrow, on the first visit and after the story (held on the base, E3b-02)
for _, n in ipairs({ 1, 2 }) do
	for _, afterStory in ipairs({ false, true }) do
		-- guard: held on the base (the card fits, so the new cut never touches it)
		test("r49 a: the Trips cue and a Wrapped card that fits, " .. n .. " short chips" .. (afterStory and ", after the story" or ", first visit"), function()
			local w, W, M, tr = setup(n, false, afterStory)
			local on = sweep(M, tr, n .. " chips")
			ok(on > 0, "the card shows whole while it fits")
			tr.scroll, tr.scrollTarget = 0, 0
			tr.content:ClearAllPoints()
			tr.content:SetPoint("TOPLEFT", tr.clip, "TOPLEFT", 0, 0)
			M.trimCells()
			ok(tr.wrapCard:IsShown(), "the card shows at the top of the page")
			ok(tr.wrapCard:IsMouseEnabled(), "the card stays clickable")
			T.clean(w)
		end)
	end
end

-- no habit chips: the first row of medals starts under the cue's strip at the top of the page (failed on the base)
test("r49 a: the Trips cue lies across no medal with no habit chips, after the story", function()
	local w, W, M, tr = setup(0, false, true)
	local on, off = sweep(M, tr, "0 chips")
	ok(on > 0, "the Wrapped card shows whole while it fits")
	tr.scroll, tr.scrollTarget = 0, 0
	tr.content:ClearAllPoints()
	tr.content:SetPoint("TOPLEFT", tr.clip, "TOPLEFT", 0, 0)
	M.trimCells()
	ok(tr.wrapCard:IsShown(), "the card shows at the top of the page")
	T.clean(w)
end)
