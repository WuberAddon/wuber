-- Design round 1, group J: words in place of mystery icons on the driver's side. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function setup()
	local w = T.newWorld()
	local d = T.driver(w, "Anita Lift")
	local r = T.rider(w)
	T.settle(w)
	T.goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(1)
	return w, d, r
end

local function labelOf(btn)
	for _, reg in ipairs({ btn:GetRegions() }) do
		if reg.GetText and reg:GetText() and reg:GetText() ~= "" then return reg:GetText() end
	end
end

local function hasTexture(f, match)
	for _, reg in ipairs({ f:GetRegions() }) do
		local p = reg.GetTextureFilePath and reg:GetTextureFilePath()
		if type(p) == "string" and p:lower():find(match, 1, true) and reg:IsShown() then return true end
	end
	return false
end

test("d1 j: a queue row's menu button says Options and carries no dots", function()
	local w, d = setup()
	local m = d.env.WuberDriveMini
	local row = m.rows[1]
	ok(row and H.visible(row), "control: the first row shows a rider")
	eq(labelOf(row.more), "Options", "the button's word")
	local circles = 0
	for _, reg in ipairs({ row.more:GetRegions() }) do
		local p = reg.GetTextureFilePath and reg:GetTextureFilePath()
		if type(p) == "string" and p:lower():find("circle", 1, true) then circles = circles + 1 end
	end
	eq(circles, 0, "no dot circles on the button")
	T.clean(w)
end)

test("d1 j: the Options button opens the same menu as the dots did", function()
	local w, d = setup()
	local m = d.env.WuberDriveMini
	local row = m.rows[1]
	d:clickOn(row.more) w:advance(1)
	local ui = d.W.Driver.ui
	local s = ui and ui.sheets and ui.sheets.menu
	ok(s and H.visible(s.frame), "the Options button opens the row menu")
	T.clean(w)
end)

test("d1 j: the row tooltip names the Options button", function()
	local w, d = setup()
	local c = d.W.Drive.Sorted()[1]
	local tip = d.W.Driver.RowTip(c)
	ok(tip:find("the Options button", 1, true), "tooltip names the Options button")
	ok(not tip:find("the ... button", 1, true), "no 'the ... button'")
	T.clean(w)
end)

test("d1 j: the shard count reads in words, 12 shards and 1 shard, with no battery picture", function()
	local w, d = setup()
	local D = d.W.Driver
	local g = D.ui.console.status.fuel
	for _, case in ipairs({ { 12, "12 shards" }, { 1, "1 shard" } }) do
		local real = D.FuelInfo
		D.FuelInfo = function() return case[1], "accent", "tip", 0.5 end
		D.PaintFuel(g)
		D.FuelInfo = real
		eq(g.num.wuberText, case[2], "the words for " .. case[1])
		ok(not hasTexture(g, "battery"), "no battery texture")
	end
	T.clean(w)
end)
