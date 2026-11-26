local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- r50 (job 2609): these bugs are fixed in 2.4.1; their proofs now run as normal tests
local FIXED = { ["H24-01"] = true, ["H24-02"] = true, ["H24-03"] = true, ["H24-04"] = true, ["H24-05"] = true, ["H24-08"] = true, ["H24-15"] = true }
local function proof(id, name, fn)
	if os.getenv("WUBER_H24_PROOF") or FIXED[id] then
		test(id .. ": " .. name, fn)
	else
		test(id .. " (expected fail until fixed): " .. name, function()
			local okp = pcall(fn)
			assert(not okp, id .. " now passes: the bug looks fixed; make this a normal test")
		end)
	end
end

local function trips(n, narrow)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
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

local function covers(a, b)
	if not (a:IsShown() and b:IsShown()) then return false end
	local at, ab, al, ar = a:GetTop(), a:GetBottom(), a:GetLeft(), a:GetRight()
	local bt, bb, bl, br = b:GetTop(), b:GetBottom(), b:GetLeft(), b:GetRight()
	if not (at and ab and al and ar and bt and bb and bl and br) then return false end
	return at > bb + 0.5 and ab < bt - 0.5 and ar > bl + 0.5 and al < br - 0.5
end

-- promise: the scroll cue shows whenever content lies below, and never covers a card (a milestone medal is a card).
-- At scroll 0 on the folded page the first medal row is kept "even if the view is tiny", but the page title moved
-- the grid 32 px down, so on the normal window that row lies under the cue's pill.
proof("H24-01", "the scroll cue never covers a shown milestone medal (folded, normal window, every scroll position)", function()
	for _, n in ipairs({ 1, 3, 11 }) do
		local w, M = trips(n, true)
		local tr = M.view()
		for y = 0, math.floor(tr.scrollMax or 0) + 3, 4 do
			tr.scroll, tr.scrollTarget = y, y
			tr.content:ClearAllPoints()
			tr.content:SetPoint("TOPLEFT", tr.clip, "TOPLEFT", 0, y)
			M.trimCells()
			if ((tr.scrollMax or 0) - y) > 1 then ok(tr.cue:IsShown(), "cue shows with content below, n=" .. n .. " y=" .. y) end
			if tr.cue:IsShown() then
				for _, c in ipairs(tr.cells) do
					if c.m then ok(not covers(tr.cue, c), "cue over medal " .. tostring(c.index) .. " at n=" .. n .. " y=" .. y) end
				end
			end
		end
		T.clean(w)
	end
end)
