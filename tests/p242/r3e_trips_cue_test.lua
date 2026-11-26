local T = ...
local test = T.test

local function trips(n)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.db.rides = {}
	for i = 1, n do W.db.rides[i] = { at = os.time({ year = 2026, month = 11, day = 17, hour = 12, min = 0, sec = 0 }) - i * 3600, dest = "Ratchet", driver = "Mia Runner", driverKey = "mia runner", price = 5000, saved = 600 } end
	W.db.fold = { v = 1, pages = {}, narrow = true }
	W.RebuildTotals()
	W.UI.Toggle(true) w:advance(1)
	W.UI.SelectTab("Trips") w:advance(1)
	return w, W, W.Mod("UI.Rider.Trips")
end

-- the promise: while the Scroll cue shows, it sits right under the last whole thing drawn (no blank band
-- above it), and scrolled to the end every medal row is on and the cue is gone
local function sweep(n, step)
	local w, W, M = trips(n)
	local tr = M.view()
	local wheel = tr.clip:GetScript("OnMouseWheel")
	local sawCue = false
	for s = 1, 30 do
		local y = tr.scroll
		local clipH = tr.clipH + (tr.cueClipped and 30 or 0)
		if tr.cue:IsShown() then
			sawCue = true
			local lowest = 0
			for _, c in ipairs(tr.cells) do
				if c:IsShown() and c.m then lowest = math.max(lowest, tr.gridTop + math.floor((c.index - 1) / 4) * 96 + 96 - y) end
			end
			for i, r in ipairs(tr.rows) do
				if r:IsShown() then lowest = math.max(lowest, tr.listTop + (i - 1) * 54 + 48 - y) end
			end
			if tr.hHead:IsShown() and tr.histTop + 26 - y <= clipH - 30 then lowest = math.max(lowest, tr.histTop + 26 - y) end
			-- (merge 2.4.2) r50 H24-01 hides even the first medal row whole when the cue's band touches it: the
			-- Medals heading above the grid is then the last thing shown
			if tr.mHead:IsShown() and tr.gridTop - 6 - y >= 0 and tr.gridTop - 6 - y <= clipH - 30 then lowest = math.max(lowest, tr.gridTop - 6 - y) end
			local cueTop = clipH - 8 - 22 - (tr.cueLift or 0)
			assert(cueTop - lowest <= 14, ("scroll %d: the cue's top is %d under the last shown medal row (blank band)"):format(y, cueTop - lowest))
			assert(tr.cueClipped or cueTop >= lowest - 0.5, "the cue lies over a medal row at scroll " .. y)
		end
		wheel(tr.clip, -1)
		w:advance(step)
	end
	w:advance(3)
	assert(sawCue, "control: the cue showed on the way")
	assert(tr.scroll >= tr.scrollMax - 0.5, "scrolled to the end")
	assert(not tr.cue:IsShown(), "no cue at the end")
	for _, c in ipairs(tr.cells) do if c.m and n == 0 then assert(c:IsShown(), "medal " .. c.index .. " can scroll into view") end end
	T.clean(w)
end

test("r3e: Trips narrow, no trips: the Scroll cue never lies over a blank band; the last medal row scrolls into view (1 s steps)", function() sweep(0, 1) end)
test("r3e: Trips narrow, no trips: same at 5 s steps", function() sweep(0, 5) end)
-- guard: with trips the page is longer; the same promise held before (rows under the cue are hidden whole)
test("r3e guard: Trips narrow with 12 trips: the cue sits clear of the medal rows and the end is reachable", function() sweep(12, 1) end)
