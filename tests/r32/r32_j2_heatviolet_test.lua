local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- HUNT-16: violet means buyers asked while you were closed; an hour you were open is never violet.
local function paint(cellData)
	local w = T.newWorld()
	local a = w:addClient(T.ANA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(15)
	local DR = a.W.Drive
	a.W.Char().wizard = true
	DR.Heatmap = function(days)
		local g = { max = 0, days = days }
		for d = 0, 6 do
			g[d] = {}
			for h = 0, 23 do g[d][h] = { copper = 0, rides = 0, open = 0, asks = 0 } end
		end
		g[2][19] = cellData
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
	local seen = {}
	for _, b in ipairs(hm.cells) do
		if b.wday == 2 and b.hour == 19 then
			local orig = b.fill.SetColorTexture
			b.fill.SetColorTexture = function(self, r, g, bl, al)
				seen.c = { r, g, bl, al }
				orig(self, r, g, bl, al)
			end
		end
	end
	a.W.Driver.PaintHeatmap(hm, 7, "me")
	local C = a.W.Theme
	return w, seen.c, { C.RGB("accent") }, { C.RGB("raised") }, { C.RampRGB(1) }
end

local function same(c, ref) return c and math.abs(c[1] - ref[1]) < 1e-6 and math.abs(c[2] - ref[2]) < 1e-6 and math.abs(c[3] - ref[3]) < 1e-6 end

test("r32 j2: heatmap - an hour open with a buyer asking and no gold is not violet", function()
	local w, c, accent, raised = paint({ copper = 0, rides = 0, open = 60, asks = 1 })
	ok(c, "painted")
	ok(not same(c, accent), "open hour is not the violet 'asked while closed' colour")
	ok(same(c, raised), "open hour with no gold is the plain open colour")
	T.clean(w)
end)

test("r32 j2: heatmap - an hour closed with a buyer asking is an outlined square with the empty fill (design round 4, F2)", function()
	local w, c, accent, raised, faint = paint({ copper = 0, rides = 0, open = 0, asks = 2 })
	local ok0 = c and not same(c, faint) and not same(c, accent)
	ok(ok0, "neither a ramp step nor filled violet")
	eq(c[4], 1, "opaque")
	T.clean(w)
end)
