-- Design round 3, group R2: typing in the place search never drops a match because its name is long. The pills wrap
-- onto a second row (the sheet grows by it); every name is shown whole, in the same order as W.SearchPlaces gives.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function open()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	T.openDrive(a)
	a.W.Driver.ShowSheet("sheet") w:advance(2)
	local s = a.W.UI.drive.screens.sheet
	s.mode = "choose" s.layout() w:advance(1)
	return w, a, s
end

test("d3 r2: typing 'ea' shows every match whole, in order, wrapping onto a second row inside the card", function()
	local w, a, s = open()
	local want = {}
	for i, p in ipairs(a.W.SearchPlaces("ea", 3)) do want[i] = type(p) == "table" and p.name or p end
	ok(#want >= 2, "control: the search finds several places")
	local h0 = s.frame.card:GetHeight()
	a:type(s.search.edit, "ea", false)
	local got, tops, card = {}, {}, H.rect(s.frame.card)
	local Th = a.W.Theme
	for _, h in ipairs(s.hits) do
		if h:IsShown() then
			got[#got + 1] = h.place
			local r = H.rect(h)
			ok(r.l + r.w <= card.l + card.w, h.place .. " hangs over the card's edge")
			ok(h:GetWidth() >= math.floor(Th.MeasureText(h.place, h.label.wuberBase, h.label.wuberWeight) + 28), h.place .. " is narrower than its text")
			tops[math.floor(h:GetBottom())] = true
		end
	end
	eq(table.concat(got, "|"), table.concat(want, "|"), "the pills are the matches, in the same order")
	local rows = 0 for _ in pairs(tops) do rows = rows + 1 end
	ok(rows >= 2, "control: the long names need a second row (" .. rows .. ")")
	ok(s.frame.card:GetHeight() > h0, "the sheet grew by the second row")
	-- the field under the pills stays clear of them
	a:type(s.search.edit, "", false)
	eq(s.hitRows, 0, "no matches: the extra row is given back")
	T.clean(w)
end)
