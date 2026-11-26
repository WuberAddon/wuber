-- Design round 4, group F: charts in the palette. One violet ramp (T.RAMP) for every bar and square, a two-word key
-- ("less", "more"), the hints as caption text, the big number still gold.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function same(a, b) return math.abs(a - b) < 1e-4 end
local function isRamp(Th, r, g, b)
	for i = 1, #Th.RAMP do
		local rr, gg, bb = Th.RampRGB(i)
		if same(r, rr) and same(g, gg) and same(b, bb) then return i end
	end
end

local function earnings(opts)
	opts = opts or {}
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
		g[2][10] = { copper = 20000, rides = 2, open = 60, asks = 0 }
		g[3][11] = { copper = 40000, rides = 3, open = 60, asks = 0 }
		g[4][12] = { copper = 60000, rides = 3, open = 60, asks = 0 }
		g[5][13] = { copper = 100000, rides = 5, open = 60, asks = 0 }
		g[6][14] = { copper = 0, rides = 0, open = 0, asks = 4 }
		g[0][15] = { copper = 3000, rides = 1, open = 10, asks = 0 }
		return g
	end
	DR.Hours = function()
		local hrs = {}
		for h = 0, 23 do hrs[h] = { open = 60, copper = h * 5000, rides = 1, asks = 0 } end
		hrs[3] = { open = 0, copper = 0, rides = 0, asks = 0 }
		return hrs
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

-- every colour a texture was given, by wrapping its setters
local function watch(tex, log)
	for _, m in ipairs({ "SetColorTexture", "SetVertexColor" }) do
		local orig = tex[m]
		tex[m] = function(self, r, g, b, al) log[#log + 1] = { r, g, b, al, m } return orig(self, r, g, b, al) end
	end
end

test("d4 f: T.RAMP is four steps of violet over the card, faint to strong, and RampRGB gives opaque colours", function()
	local w, a = earnings()
	local Th = a.W.Theme
	eq(#Th.RAMP, 4, "four steps")
	for i = 2, #Th.RAMP do ok(Th.RAMP[i] > Th.RAMP[i - 1], "step " .. i .. " is stronger") end
	local r1, g1, b1 = Th.RampRGB(1)
	local r4, g4, b4 = Th.RampRGB(4)
	ok(same(r4, Th.C.accent[1]) and same(g4, Th.C.accent[2]) and same(b4, Th.C.accent[3]), "the strongest step is the violet token")
	ok(r1 < r4 and g1 < g4, "the faintest is nearer the card")
	T.clean(w)
end)

test("d4 f: the bars and the heatmap squares are drawn only in ramp steps, stronger for more, never gold", function()
	local w, a, s = earnings()
	local Th = a.W.Theme
	local gold = Th.C.gold
	-- bars: every visible fill is a ramp step; the busiest hours are stronger than the quiet ones
	a.W.Driver.RefreshNow()
	w:advance(1)
	s.update()
	local steps, seen = {}, 0
	for h = 0, 23 do
		local b = s.dash.bars[h]
		if b.fill:IsShown() and not (s.hours[h].open <= 0) then
			local r, g, bl = b.fill:GetVertexColor()
			local st = isRamp(Th, r, g, bl)
			ok(st, "bar " .. h .. " is a ramp step, got " .. string.format("%.2f %.2f %.2f", r, g, bl))
			ok(not (same(r, gold[1]) and same(g, gold[2])), "bar " .. h .. " is not gold")
			steps[h] = st or 0
			seen = seen + 1
		end
		ok(not b.dim:IsShown(), "no second 'under target' colour on bar " .. h)
		ok(not b.shine:IsShown(), "no gold shine on bar " .. h)
	end
	ok(seen >= 20, "the bars are drawn (" .. seen .. ")")
	ok(steps[23] > steps[2], "a stronger bar for more gold an hour: " .. steps[23] .. " vs " .. steps[2])
	-- squares
	local by = {}
	for _, b in ipairs(s.heat.cells) do
		by[b.wday * 100 + b.hour] = b
	end
	local function stepOf(wd, hr)
		local b = by[wd * 100 + hr]
		local log = {}
		watch(b.fill, log)
		a.W.Driver.PaintHeatmap(s.heat, 7, "me")
		local c = log[#log]
		ok(c, "square painted")
		return c and isRamp(Th, c[1], c[2], c[3]), c
	end
	local s1 = stepOf(1, 9)
	local s5 = stepOf(5, 13)
	ok(s1, "a quiet earning hour is a ramp step")
	ok(s5, "the best hour is a ramp step")
	eq(s5, #Th.RAMP, "the best hour is the strongest step")
	ok(s1 < s5, "a quieter hour is fainter")
	local sa, ca = stepOf(6, 14)
	ok(not sa, "an asked-while-closed hour is not a ramp step: it is outlined (design round 4, F2)")
	eq(ca and ca[4], 1, "opaque")
	local ss = stepOf(0, 15)
	eq(ss, 1, "an hour open under 30 minutes that took gold is the faintest step")
	-- no square is gold
	local log = {}
	for _, b in ipairs(s.heat.cells) do watch(b.fill, log) end
	a.W.Driver.PaintHeatmap(s.heat, 7, "me")
	for _, c in ipairs(log) do
		ok(not (same(c[1], gold[1]) and same(c[2], gold[2]) and same(c[3], gold[3])), "no gold square")
		ok(not (c[1] > 0.75 and c[2] > 0.6 and c[3] < 0.4), "nothing gold-like in a square")
	end
	T.clean(w)
end)

test("d4 f: the key says 'less' and 'more' at caption size, clear of the squares and of the legend, whole", function()
	local w, a, s = earnings()
	local Th = a.W.Theme
	for _, where in ipairs({ { "the heatmap", s.heat }, { "the bar chart", s.dash } }) do
		local name, card = where[1], where[2]
		local k = card.key
		ok(k, name .. " has a key")
		ok(k:IsShown(), name .. "'s key is shown with data")
		eq(k.less:GetText(), "less", name)
		eq(k.more:GetText(), "more", name)
		for _, t in ipairs({ k.less, k.more }) do
			eq(select(2, t:GetFont()), Th.SIZE.caption, name .. ": caption size")
			ok(not t:IsTruncated(), name .. ": not cut")
			ok(H.truncation(t) == nil, name .. ": drawn whole")
		end
		eq(#k.steps, #Th.RAMP, name .. ": a swatch per step")
		for i, sw in ipairs(k.steps) do
			local c = H.state[sw].color
			ok(c and isRamp(Th, c[1], c[2], c[3]) == i, name .. ": swatch " .. i .. " is step " .. i)
		end
		ok(k:GetRight() <= card:GetRight() + 0.5 and k:GetLeft() >= card:GetLeft() - 0.5, name .. ": inside its card")
		ok(k:GetBottom() >= card:GetBottom() - 0.5 and k:GetTop() <= card:GetTop() + 0.5, name .. ": inside its card, vertically")
	end
	-- clear of the squares: the key sits under the last row
	local lastRow = s.heat.cells[#s.heat.cells]
	ok(s.heat.key:GetTop() <= lastRow:GetBottom() - 2, "the key is under the squares")
	ok(s.heat.key:GetTop() <= s.heat.hours[1]:GetBottom() + 0.5, "and under their hour labels")
	-- clear of the legend words
	local lg = s.dash.legend
	ok(lg:GetRight() <= s.dash.key:GetLeft() + 0.5 or lg:GetBottom() >= s.dash.key:GetTop() or lg:GetTop() <= s.dash.key:GetBottom(), "the legend and the key do not overlap")
	T.clean(w)
end)

test("d4 f: the hint 'Tap a square for its numbers.' is plain caption text (no pill) until a square is tapped; the two tips are text too", function()
	local w, a, s = earnings()
	local hm = s.heat
	a.W.Driver.PaintHeatmap(hm, 7, "me")
	eq(hm.info:GetText(), "Tap a square for its numbers.", "the same words")
	ok(hm.pill:IsShown(), "the words are shown")
	ok(hm.pill.fill.hidden, "with no pill under them")
	local r, g, b = hm.info:GetTextColor()
	local m = a.W.Theme.C.muted
	ok(same(r, m[1]) and same(g, m[2]) and same(b, m[3]), "in the muted colour")
	-- a tapped square keeps its numbers pill
	local cell
	for _, c in ipairs(hm.cells) do if c.wday == 5 and c.hour == 13 then cell = c end end
	a:click(cell)
	w:advance(0.5)
	ok(not hm.pill.fill.hidden, "a tapped square's numbers keep their pill")
	-- the two tips under the heatmap: no pill, caption size
	for _, c in ipairs({ s.top, s.try }) do
		ok(not c.fill, "no pill fill on a tip")
		eq(select(2, c.text:GetFont()), a.W.Theme.SIZE.caption, "caption size")
	end
	T.clean(w)
end)

test("d4 f: the big number is still gold", function()
	local w, a = earnings()
	local s = a.W.Driver.screens.earnings(a.env.UIParent) -- as built, before any data
	local r, g, b = s.per:GetTextColor()
	local gold = a.W.Theme.C.gold
	ok(same(r, gold[1]) and same(g, gold[2]) and same(b, gold[3]), "gold per open hour is gold")
	T.clean(w)
end)
