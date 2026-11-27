-- Design round 4, group F2: an hour when buyers asked while the driver was closed is an OUTLINED square (no fill,
-- a one-pixel violet outline); an hour that earned stays a filled ramp step (earning wins).
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function same(a, b) return math.abs(a - b) < 1e-4 end

local function world(extra)
	local w = T.newWorld()
	local a = w:addClient(T.ANA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(15)
	local DR = a.W.Drive
	a.W.Char().wizard = true
	DR.Heatmap = function(days)
		local g = { max = 3000, days = days }
		for d = 0, 6 do
			g[d] = {}
			for h = 0, 23 do g[d][h] = { copper = 0, rides = 0, open = 0, asks = 0 } end
		end
		g[1][9] = { copper = 5000, rides = 1, open = 60, asks = 0 }
		g[2][10] = { copper = 20000, rides = 2, open = 60, asks = 3 }  -- earned and had askers
		g[6][14] = { copper = 0, rides = 0, open = 0, asks = 4 }       -- asked while closed
		g[3][11] = { copper = 4000, rides = 1, open = 0, asks = 2 }    -- took gold and asked, no open minutes recorded
		return g
	end
	a.W.db.coach = true
	a.W.UI.Toggle(true)
	w:advance(2.5)
	a:clickText("Drive")
	w:advance(1)
	a.W.UI.ShowDrive("earnings")
	w:advance(1)
	local s = a.W.UI.drive.screens.earnings
	s.update()
	a.W.Driver.PaintHeatmap(s.heat, 7, "me")
	return w, a, s
end

local function cellOf(hm, wd, hr)
	for _, b in ipairs(hm.cells) do if b.wday == wd and b.hour == hr then return b end end
end
local function isRamp(Th, c)
	for i = 1, #Th.RAMP do
		local r, g, b = Th.RampRGB(i)
		if c and same(c[1], r) and same(c[2], g) and same(c[3], b) then return i end
	end
end
local function edgeShown(b) return b.edge and b.edge.parts[1]:IsShown() end

local function fillOf(H, b) return H.state[b.fill].color end

test("d4 f2: an asked-while-closed square has no ramp fill and a one-pixel violet outline, the size of its neighbours", function()
	local w, a, s = world()
	local Th, H = a.W.Theme, T.H
	local b, n = cellOf(s.heat, 6, 14), cellOf(s.heat, 6, 13)
	local c = fillOf(H, b)
	ok(c and not isRamp(Th, c), "no ramp fill")
	local pr, pg, pb = Th.RGB("panel")
	ok(c and same(c[1], pr) and same(c[2], pg) and same(c[3], pb), "the empty square's own fill")
	ok(edgeShown(b), "outlined")
	local ac = Th.C.accent
	for i, p in ipairs(b.edge.parts) do
		local pc = H.state[p].color
		ok(pc and same(pc[1], ac[1]) and same(pc[2], ac[2]) and same(pc[3], ac[3]), "outline line " .. i .. " is the violet token")
	end
	eq(b.edge.parts[1]:GetHeight(), 1, "one pixel")
	eq(b.edge.parts[3]:GetWidth(), 1, "one pixel")
	ok(not edgeShown(n), "a quiet neighbour has no outline")
	eq(b:GetWidth(), n:GetWidth(), "same width as its neighbour")
	eq(b:GetHeight(), n:GetHeight(), "same height as its neighbour")
	T.clean(w)
end)

test("d4 f2: an earning square is a filled ramp step with no outline, also when buyers asked (earning wins)", function()
	local w, a, s = world()
	local Th, H = a.W.Theme, T.H
	for _, p in ipairs({ { 1, 9 }, { 2, 10 }, { 3, 11 } }) do
		local b = cellOf(s.heat, p[1], p[2])
		ok(isRamp(Th, fillOf(H, b)), "square " .. p[1] .. "/" .. p[2] .. " is a ramp step")
		ok(not edgeShown(b), "square " .. p[1] .. "/" .. p[2] .. " has no outline")
	end
	T.clean(w)
end)

test("d4 f2: the selection mark shows on an outlined square, and an outline goes when the hour is repainted without askers", function()
	local w, a, s = world()
	local hm, H = s.heat, T.H
	local b = cellOf(hm, 6, 14)
	-- the player scrolls the hour grid until the square is on screen
	ok(a:scrollIntoView(b), "the square can be scrolled into view")
	a:click(b)
	w:advance(0.5)
	ok(hm.sel:IsShown(), "the selection mark is shown")
	ok(hm.sel:GetFrameLevel() > b:GetFrameLevel(), "above the square")
	ok(edgeShown(b), "the outline stays")
	a.W.Drive.Heatmap = function(days)
		local g = { max = 0, days = days }
		for d = 0, 6 do
			g[d] = {}
			for h = 0, 23 do g[d][h] = { copper = 0, rides = 0, open = 0, asks = 0 } end
		end
		g[6][14] = { copper = 0, rides = 0, open = 30, asks = 0 }
		return g
	end
	a.W.Driver.PaintHeatmap(hm, 7, "me")
	ok(not edgeShown(b), "no outline once it is not an asked-while-closed hour")
	T.clean(w)
end)

test("d4 f2: the heatmap tip keeps the original sentence, changing only the colour words", function()
	local w, a, s = world()
	local tip = s.heat.wuberTip and s.heat.wuberTip.text
	local want = "Each square is one hour of one weekday: the stronger the violet, the more you earned per hour open. "
		.. "Outlined squares: buyers asked while you were closed. Tap a square for its numbers."
	eq(tip, want, "the tip's words")
	T.clean(w)
end)
