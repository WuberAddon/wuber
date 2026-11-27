local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local SIZES = { { 1365, 768 }, { 1024, 600 }, { 1920, 1080 } }

local function trips(n, narrow, size)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = size[1], screenH = size[2] })
	w:advance(15)
	local W = r.W
	local oct = os.time({ year = 2026, month = 10, day = 10, hour = 12, min = 0, sec = 0 })
	W.db.rides = {}
	for i = 1, n do
		W.db.rides[i] = { at = oct + i * 3600, dest = "Ratchet", driver = "Mia Runner", driverKey = "mia runner", price = 5000, saved = 600 }
	end
	W.db.fold = { v = 1, pages = {}, narrow = narrow }
	W.RebuildTotals()
	W.UI.Toggle(true) w:advance(1)
	W.UI.SelectTab("Trips") w:advance(1)
	return w, W.Mod("UI.Rider.Trips")
end

local function goto_(tr, M, y)
	tr.scroll, tr.scrollTarget = y, y
	tr.content:ClearAllPoints()
	tr.content:SetPoint("TOPLEFT", tr.clip, "TOPLEFT", 0, y)
	M.trimCells()
end

local function anyCell(tr)
	for _, c in ipairs(tr.cells) do if c.m and c:IsShown() then return true end end
	return false
end

-- Promise: on folded Trips no Milestones title (or its empty card) shows with no medal under it, 0 to 12 rides,
-- every scroll position, three window sizes. A title with no medals has no job.
test("b2955 trips milestones: folded Trips never shows the Milestones title or card with no medal shown, 0 to 12 rides", function()
	for _, size in ipairs(SIZES) do
		for n = 0, 12 do
			local w, M = trips(n, true, size)
			local tr = M.view()
			for y = 0, math.floor(tr.scrollMax or 0) + 3, 4 do
				goto_(tr, M, y)
				if tr.mHead:IsShown() or tr.tray:IsShown() then
					ok(anyCell(tr), "title or card with no medal n=" .. n .. " y=" .. y .. " size=" .. size[1])
				end
			end
			T.clean(w)
		end
	end
end)

-- guard: passes on the base too; the unfolded side pane keeps its title and tray whatever the scroll
test("b2955 trips milestones: unfolded Trips keeps the Milestones title and card", function()
	local w, M = trips(11, false, SIZES[1])
	local tr = M.view()
	ok(tr.mHead:IsShown(), "title shows")
	ok(tr.tray:IsShown(), "card shows")
	ok(anyCell(tr), "medals show")
	T.clean(w)
end)

-- guard: passes on the base too; scrolled until the first row fits above the cue, title, card and medals show
test("b2955 trips milestones: scrolled until the medals fit, title and card are back", function()
	local w, M = trips(11, true, SIZES[1])
	local tr = M.view()
	goto_(tr, M, 100)
	ok(anyCell(tr), "medals show")
	ok(tr.mHead:IsShown(), "title shows with them")
	ok(tr.tray:IsShown(), "card shows with them")
	T.clean(w)
end)