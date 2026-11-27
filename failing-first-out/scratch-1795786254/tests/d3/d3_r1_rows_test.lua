-- Design round 3, group R1 (the fix wave): with a row's Options button on the name's line, a chip that would lie
-- under the button's column keeps clear of it. A console row (52 high) lifts the button and lowers the chips so
-- 2 lie between them and the row stays two lines; a mini console row (44 high) stays two lines too (group R3:
-- its button is 20 high and 2 higher, 2 clear above the chip). Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function row(base)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	W.Drive.GetAppState = function() return "ok" end
	W.Drive.RideCount = function() return 1 end
	local D = W.Driver
	local parent = a.env.CreateFrame("Frame", nil, a.env.UIParent)
	parent:SetSize(400, 300)
	parent:SetPoint("CENTER")
	parent:Show()
	local r = D.Row(parent, 340) -- the usual console width: "2nd ride with you" and "Invite to Wuber" fill one line
	r:SetHeight(base)
	r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	D.PaintRow(r, { name = "Dan Rider", state = "joined", source = "whisper", at = 1000 }, 1000)
	return w, r
end

test("d3 r1 rows: a console row (52) with a chip under the Options column stays two lines, the button 2 clear above the chips", function()
	local w, r = row(52)
	ok(r.more:GetBottom() > r.name:GetBottom() - 12, "setup: Options is on the name's line")
	local under = 0
	for _, chip in ipairs({ r.again, r.getapp }) do
		ok(chip:IsShown(), "setup: two chips")
		if chip:GetRight() > r.more:GetLeft() then
			under = under + 1
			ok(r.more:GetBottom() - chip:GetTop() >= 1.99, "2 clear between Options and the chip under it: " .. (r.more:GetBottom() - chip:GetTop()))
		end
		ok(chip:GetBottom() - r:GetBottom() >= 3.99, "the chip keeps 4 to the row's foot")
	end
	ok(under > 0, "setup: a chip lies under the button's column")
	ok(r:GetTop() - r.more:GetTop() >= 3.99, "Options keeps 4 to the row's top")
	eq(r:GetHeight(), 52, "the row keeps its height")
	T.clean(w)
end)

test("d3 r1 rows: a mini console row (44) keeps that chip on its line, 2 clear under the button", function()
	local w, r = row(44)
	for _, chip in ipairs({ r.again, r.getapp }) do
		ok(chip:GetRight() <= r.more:GetLeft() or chip:GetTop() <= r.more:GetBottom() - 1.99,
			"the chip is beside the button's column or 2 under the button")
	end
	eq(r:GetHeight(), 44, "two lines, 2 clear (R3: was a third line, 66)")
	T.clean(w)
end)
