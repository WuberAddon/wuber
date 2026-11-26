local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function trips(n, narrow, wrap)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W, env = r.W, r.env
	if wrap then
		local realDate = env.date
		env.date = function(fmt, t)
			if fmt == "*t" and t == nil then return { year = 2026, month = 11, day = 3, hour = 12, min = 0, sec = 0, wday = 3 } end
			return realDate(fmt, t)
		end
	end
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

local function goto_(tr, M, y)
	tr.scroll, tr.scrollTarget = y, y
	tr.content:ClearAllPoints()
	tr.content:SetPoint("TOPLEFT", tr.clip, "TOPLEFT", 0, y)
	M.trimCells()
end

-- Real = a player can see it: a medal cell that is shown. Promise: with the cue up, no shown medal lies under it,
-- 1 to 11 rides, both window widths, every scroll position. The first row, kept "even if the view is tiny",
-- is the one that was covered at the top of the folded page.
test("r50 b H24-01: the scroll cue never covers a shown medal, 1 to 11 rides, folded and unfolded, every scroll position", function()
	for _, narrow in ipairs({ true, false }) do
		for _, n in ipairs({ 1, 2, 3, 5, 7, 10, 11 }) do
			local w, M = trips(n, narrow)
			local tr = M.view()
			for y = 0, math.floor(tr.scrollMax or 0) + 3, 4 do
				goto_(tr, M, y)
				if ((tr.scrollMax or 0) - y) > 1 then ok(tr.cue:IsShown(), "cue shows with content below n=" .. n .. " y=" .. y) end
				for _, c in ipairs(tr.cells) do
					if c.m then ok(not covers(tr.cue, c), "cue over medal " .. tostring(c.index) .. " n=" .. n .. " narrow=" .. tostring(narrow) .. " y=" .. y) end
				end
			end
			T.clean(w)
		end
	end
end)

-- guard: passes on the base too; the medals still show: scrolled until the first row lies whole above the cue's band it is drawn again
test("r50 b H24-01: a first row that fits above the cue is shown (scrolled a little)", function()
	local w, M = trips(11, true)
	local tr = M.view()
	goto_(tr, M, 100)
	local n = 0
	for _, c in ipairs(tr.cells) do if c.m and c:IsShown() and c.index <= 4 then n = n + 1 end end
	eq(n, 4, "the four medals of the first row show at scroll 100")
	T.clean(w)
end)

-- guard: passes on the base too; unfolded window keeps all its medals (no clip, no cue over them)
test("r50 b H24-01: the unfolded page shows every medal", function()
	local w, M = trips(11, false)
	local tr = M.view()
	local n = 0
	for _, c in ipairs(tr.cells) do if c.m and c:IsShown() then n = n + 1 end end
	eq(n, 14, "all medals show")
	T.clean(w)
end)

-- H24 bk guard, kept here: R49-1's first-row clip stayed on after the Wrapped card left the band. The clip is cut
-- only for the Wrapped card now (the first row is hidden whole instead), so it runs to the foot again.
test("r50 b: with the Wrapped card in the cue's band the page is cut 30 above the foot, and runs to the foot again after", function()
	local w, M = trips(6, true, true)
	local tr = M.view()
	tr.scroll, tr.scrollTarget = 0, 0
	tr.wrapTop = 420
	M.trimCells()
	ok(tr.cue:IsShown(), "the cue shows while content lies below")
	local foot = tr.body:GetBottom()
	ok(math.abs(tr.clip:GetBottom() - (foot + 30)) < 0.5, "page cut above the cue's band")
	tr.wrapTop = 100
	M.trimCells()
	ok(math.abs(tr.clip:GetBottom() - foot) < 0.5, "card out of the band: the page runs to the foot again")
	T.clean(w)
end)
