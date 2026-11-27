local T = ...
local test = T.test

-- Folded Trips: the Milestones card (tr.tray) must never show with no medal in it, at open or after the
-- view scrolls, and it shows whenever a medal is shown. The Milestones heading is a child of the card and hides
-- with it: intended, an empty card has no job.
local function trips(n, screenH, wide)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = screenH })
	w:advance(15)
	local W = r.W
	W.db.rides = {}
	for i = 1, n do W.db.rides[i] = { at = os.time({ year = 2026, month = 11, day = 17, hour = 12, min = 0, sec = 0 }) - i * 3600, dest = "Ratchet", driver = "Mia Runner", driverKey = "mia runner", price = 5000, saved = 600 } end
	W.db.fold = { v = 1, pages = {}, narrow = not wide }
	W.RebuildTotals()
	W.UI.Toggle(true) w:advance(1)
	W.UI.SelectTab("Trips") w:advance(1)
	return w, W, W.Mod("UI.Rider.Trips")
end

local function cellsShown(tr)
	local k = 0
	for _, c in ipairs(tr.cells) do if c.m and c:IsShown() then k = k + 1 end end
	return k
end

local function sweep(n, screenH, step)
	local w, W, M = trips(n, screenH)
	local tr = M.view()
	local wheel = tr.clip:GetScript("OnMouseWheel")
	local sawCard, sawHidden = false, false
	for s = 1, 40 do
		local card, medals = tr.tray:IsShown() and true or false, cellsShown(tr)
		assert(card == (medals > 0), ("scroll %d: card shown=%s but %d medals shown (must be shown iff a medal shows)"):format(tr.scroll, tostring(card), medals))
		if card then sawCard = true else sawHidden = true end
		wheel(tr.clip, -1)
		w:advance(step)
	end
	w:advance(3)
	assert(sawCard, "control: the card showed with medals at some scroll")
	assert(sawHidden, "control: the card was hidden at some scroll (no medal shown)")
	T.clean(w)
	return sawHidden
end

for _, h in ipairs({ 600, 700, 768, 900 }) do
	test("o2747 #2: Trips folded (screen " .. h .. "): the Milestones card is never shown empty, at open or after scrolling (1 s steps)", function() sweep(12, h, 1) end)
	test("o2747 #2: Trips folded (screen " .. h .. "): same with 12 trips, 5 s steps", function() sweep(12, h, 5) end)
end

-- guard: unfolded Trips with milestones still shows the card with its medals
test("o2747 #2 guard: Trips unfolded (wide) with milestones still shows the Milestones card", function()
	local w, W, M = trips(0, 1080, true)
	local tr = M.view()
	w:advance(3)
	assert(tr.wide, "control: the page is unfolded")
	assert(tr.tray:IsShown(), "the card shows")
	assert(cellsShown(tr) > 0, "its medals show")
	T.clean(w)
end)
