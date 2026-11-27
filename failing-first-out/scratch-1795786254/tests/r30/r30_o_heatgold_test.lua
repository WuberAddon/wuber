local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- HUNT-03 follow-up: an hour open under 30 minutes that took gold stays at the faintest tone, never "raised"
-- (design round 4, F: the tones are the violet ramp's steps now; the faintest is T.RampRGB(1), not dim gold)
local function setup(longHour)
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
		g[2][19] = { copper = 10000, rides = 2, open = 2, asks = 0 }
		if longHour then g[2][20] = { copper = 15000, rides = 2, open = 30, asks = 0, perHour = 30000 } end
		return g
	end
	a.W.db.coach = true
	a.W.UI.Toggle(true)
	w:advance(2.5)
	a:clickText("Drive")
	w:advance(1)
	a.W.UI.ShowDrive("earnings")
	w:advance(1)
	local hm = a.W.UI.drive.screens.earnings.heat
	local short
	local seen = {}
	for _, b in ipairs(hm.cells) do
		if b.wday == 2 and b.hour == 19 then
			short = b
			local orig = b.fill.SetColorTexture
			b.fill.SetColorTexture = function(self, r, g, bl, al)
				seen.c = { r, g, bl, al }
				orig(self, r, g, bl, al)
			end
		end
	end
	a.W.Driver.PaintHeatmap(hm, 7, "me")
	return w, a, hm, short, seen
end

test("r30 o: heatmap - a short hour that took gold stays at the faintest step beside a 30-minute hour", function()
	local w, a, hm, short, seen = setup(true)
	local T2 = a.W.Theme
	ok(seen.c, "the short square was painted")
	local want = { T2.RampRGB(1) }
	for i = 1, 3 do ok(math.abs(seen.c[i] - want[i]) < 1e-6, "faintest step, channel " .. i .. ": " .. tostring(seen.c[i])) end
	ok(hm.bestCell and hm.bestCell ~= short, "the 30-minute hour is still the brightest")
	T.clean(w)
end)

test("r30 o: heatmap - only short hours that took gold are the faintest step and none is the brightest", function()
	local w, a, hm, short, seen = setup(false)
	local lo = { a.W.Theme.RampRGB(1) }
	ok(seen.c and math.abs(seen.c[1] - lo[1]) < 1e-6, "the faintest step, not the raised colour")
	eq(hm.bestCell, nil, "no brightest square")
	T.clean(w)
end)
