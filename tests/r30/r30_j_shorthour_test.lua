local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- HUNT-03: an hour open only 2 minutes shows no gold-per-hour rate and does not set the brightest square
test("r30 j: heatmap - a short hour (2 min open) shows no rate and is not the brightest square", function()
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
		g[2][20] = { copper = 15000, rides = 2, open = 30, asks = 0, perHour = 30000 }
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
	local short, long
	for _, b in ipairs(hm.cells) do
		if b.wday == 2 and b.hour == 19 then short = b end
		if b.wday == 2 and b.hour == 20 then long = b end
	end
	eq(hm.bestCell, long, "the 30-minute hour is the brightest")
	H.runScript(short, "OnClick", "LeftButton")
	local txt = (hm.info:GetText() or ""):gsub("\n", " · ")
	print("short hour pill: " .. txt)
	ok(not txt:find("g/h", 1, true), "no rate for a 2-minute hour: " .. txt)
	ok(txt:find("open 2 min", 1, true), "still says how long it was open: " .. txt)
	T.clean(w)
end)
