-- Design round 3, group F2: the driver's pages make room for Inter's sizes (body 14, caption 11, floor 11).
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function world()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	return w, a, a.W, a.W.Driver, a.W.Theme
end

test("d3 f2: Earnings' Today / 7 days / 30 days choice sizes its segments by their words, so '30 days' shows whole", function()
	local _, a, _, D, Th = world()
	local s = D.screens.earnings(a.env.UIParent)
	eq(#s.seg.buttons, 3, "three segments")
	local sum = 0
	for _, b in ipairs(s.seg.buttons) do
		local label = b.label:GetText()
		local need = Th.MeasureText(label, "sub", "bold")
		ok(b:GetWidth() >= need + 22, label .. ": " .. b:GetWidth() .. " wide, needs " .. need .. " and its padding")
		sum = sum + b:GetWidth()
	end
	ok(sum <= s.seg:GetWidth(), "and together they fit the choice")
end)

test("d3 f2: a place's name in the price and place sheet's results is never cut at 150", function()
	local _, a, W, D, Th = world()
	local s = D.screens.sheet(a.env.UIParent)
	W.SearchPlaces = function() return { "Feathermoon Stronghold" } end
	s.results("fea")
	local h = s.hits[1]
	ok(h:IsShown(), "the result shows")
	local need = Th.MeasureText("Feathermoon Stronghold", "caption", "bold")
	ok(h:GetWidth() - 10 >= need, "the pill is " .. h:GetWidth() .. " wide for a name that needs " .. need)
end)

test("d3 f2: a Demand row keeps its detail line the row's full width, under the place and beside nothing", function()
	local _, a, _, D, Th = world()
	local card = D.DemandCard(a.env.UIParent, 320)
	local t0 = os.time()
	a.W.Bounty.Demand = function() return { { place = "Gadgetzan", riders = 3, low = 5000, high = 10000, newest = t0 - 120 } } end
	card:Update()
	local row = card.rows[1]
	ok(row, "a row")
	local text = row.sub.wuberText
	ok(row.sub:GetWidth() >= Th.MeasureText(text, "caption", "regular"), text .. " fits " .. row.sub:GetWidth())
	local _, _, _, _, sy = row.sub:GetPoint(1)
	local _, _, _, _, by = row.serve:GetPoint(1)
	ok(by - row.serve:GetHeight() >= sy, "the button ends (" .. by - row.serve:GetHeight() .. ") above where the detail line starts (" .. sy .. ")")
end)

test("d3 f2: the Crew 'my window' words have room for their 72 px", function()
	local _, a, _, D, Th = world()
	local r = a.env.CreateFrame("Frame", nil, a.env.UIParent)
	r.name, r.sub = Th.Text(r, "body", "white", "LEFT", "bold"), Th.Text(r, "caption", "muted", "LEFT", "regular")
	a.W.Drive.BookShareOn = function() return true end
	D.CrewOwnMark(r, { key = "Bob-Realm", name = "Bob", app = true })
	ok(r.ownLabel, "the label is there")
	ok(r.ownLabel:GetWidth() >= Th.MeasureText("my window", "caption", "medium"), "it is " .. r.ownLabel:GetWidth() .. " wide")
end)

test("d3 f2: the Shift complete tiles keep their small label clear of the number, normal and squeezed", function()
	local _, a, _, D = world()
	local s = D.screens.shift(a.env.UIParent)
	local t = s.tiles[3]
	local function gap()
		local _, _, _, _, ly = t.label:GetPoint(1)
		local _, _, _, _, vy = t.value:GetPoint(1)
		return ly - vy -- the number's top is this far under the label's top
	end
	ok(gap() >= 16, "normal: " .. gap() .. " px between the tops")
	D.PaintSplit(s, s.frame)
	s.compact = true
	ok(gap() >= 16, "after layout: " .. gap())
end)
