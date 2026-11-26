-- Design round 3, group R3 (the fix wave): a mini console row (44 high) whose chips fit the row's full width on
-- one line keeps them on that line. The Options button, on the name's line, is 20 high there and sits 1 higher
-- over the 18-high Invite pill (2 to the row's top, 2 clear, 2 to its foot), 2 higher over a 20-high chip. A third line only when
-- the chips do not fit the row's width. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function setup()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	W.Drive.GetAppState = function() return "ok" end
	W.Drive.RideCount = function() return 1 end
	local parent = a.env.CreateFrame("Frame", nil, a.env.UIParent)
	parent:SetSize(400, 300)
	parent:SetPoint("CENTER")
	parent:Show()
	return w, W.Driver, parent
end

local function row(D, parent, wdt, base, c)
	local r = D.Row(parent, wdt)
	r:SetHeight(base)
	r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	D.PaintRow(r, c or { name = "Dan Rider", state = "joined", source = "whisper", at = 1000 }, 1000)
	return r
end

-- The two chips ("2nd ride with you" 121, "Invite to Wuber" 109, 5 between, from 52 to 8 short of the right edge)
-- need a row of 295: from there up the row is 44. A narrower row cannot hold them on one line, so it flows.
test("d3 r3 rows: a mini console row (44) with a ride-count chip and Invite to Wuber is 44 wherever the two fit its width (240 to 340)", function()
	local w, D, parent = setup()
	local under, two = 0, 0
	for wdt = 240, 340, 4 do
		local r = row(D, parent, wdt, 44)
		ok(r.again:IsShown() and r.getapp:IsShown(), "setup: both chips at " .. wdt)
		eq(r.getapp.label:GetText(), "Invite to Wuber", "the chip's words")
		eq(r.again.label:GetText(), "2nd ride with you", "the chip's words")
		local fits = 52 + r.again:GetWidth() + 5 + r.getapp:GetWidth() <= wdt - 8
		if not fits then
			ok(r:GetHeight() > 44, "chips wider than the row flow at " .. wdt)
			ok(r.getapp:GetRight() <= r:GetRight() and r.again:GetRight() <= r:GetRight(), "inside the row at " .. wdt)
			ok(wdt < 296, "the two chips fit from 296 up (" .. wdt .. ")")
			r:Hide()
		else
		two = two + 1
		eq(r:GetHeight(), 44, "two lines at " .. wdt)
		ok(math.abs((r.again:GetTop() + r.again:GetBottom()) - (r.getapp:GetTop() + r.getapp:GetBottom())) < 0.01, "the chips share a line at " .. wdt)
		ok(r:GetTop() - r.more:GetTop() >= 1.99, "Options 2 inside the row's top at " .. wdt)
		ok(r.getapp:GetBottom() - r:GetBottom() >= 1.99, "the Invite pill 2 inside the row's foot at " .. wdt)
		ok(not r.more.label:IsTruncated(), "Options not cut at " .. wdt)
		ok(r.more:GetHeight() >= r.more.label:GetStringHeight(), "the button holds its word at " .. wdt)
		for _, chip in ipairs({ r.again, r.getapp }) do
			ok(chip:GetBottom() - r:GetBottom() >= 0.99, "the chip inside the row's foot at " .. wdt)
			if chip:GetRight() > r.more:GetLeft() and chip:GetTop() > r.more:GetBottom() - 12 then
				under = under + 1
				local clear = r.more:GetBottom() - chip:GetTop()
				ok(clear >= 1.99, "2 clear between Options and the chip under it at " .. wdt .. ": " .. clear)
				eq(r.more:GetHeight(), 20, "the button is 20 high over a chip at " .. wdt)
			end
		end
		r:Hide()
		end
	end
	eq(two, 12, "two lines at every width from 296 to 340")
	ok(under > 0, "setup: at some width a chip lies under the button's column")
	T.clean(w)
end)

test("d3 r3 rows: the Options button is 22 high again where no chip lies under it, and in a console row", function()
	local w, D, parent = setup()
	local r = row(D, parent, 340, 44)
	eq(r.more:GetHeight(), 20, "setup: 20 over the chip")
	local top = r.more:GetTop()
	D.PaintRaidRow(r, { name = "Ivy Moss", asked = 990, state = "queued", tries = 0 }, 1000)
	eq(r.more:GetHeight(), 22, "a raid row (no chips): 22")
	eq(r:GetHeight(), 44, "and 44 high")
	D.PaintRow(r, { name = "Dan Rider", state = "joined", source = "whisper", at = 1000 }, 1000)
	eq(r.more:GetHeight(), 20, "20 again with the chips back")
	eq(r.more:GetTop(), top, "at the same place")
	r:Hide()
	local c = row(D, parent, 340, 52)
	eq(c.more:GetHeight(), 22, "a console row keeps the 22-high button")
	eq(c:GetHeight(), 52, "and its height")
	T.clean(w)
end)

test("d3 r3 rows: chips that do not fit the row's width still take a third line", function()
	local w, D, parent = setup()
	local real = D.Stations
	D.Stations = function() return { "Undercity", "Orgrimmar" } end
	local r = row(D, parent, 300, 44, { name = "Dan Rider", state = "joined", source = "whisper", at = 1000, station = "Undercity" })
	ok(r.station:IsShown(), "setup: three chips")
	ok(52 + r.station:GetWidth() + 5 + r.again:GetWidth() + 5 + r.getapp:GetWidth() > 300 - 8, "setup: wider than the row")
	eq(r:GetHeight(), 66, "the row grew one chip line")
	for _, chip in ipairs({ r.station, r.again, r.getapp }) do
		ok(chip:GetRight() <= r.more:GetLeft() or chip:GetTop() <= r.more:GetBottom() - 1.99, "clear of Options")
		ok(chip:GetRight() <= r:GetRight() and chip:GetBottom() >= r:GetBottom(), "inside the row")
	end
	D.Stations = real
	T.clean(w)
end)

test("d3 r3 rows: over a 20-high chip the low button sits 2 higher: 2 clear, 1 to the row's top", function()
	local w, D, parent = setup()
	local seen = 0
	local real = D.Stations
	D.Stations = function() return { "Undercity", "Orgrimmar" } end
	for wdt = 268, 340, 4 do
		local r = row(D, parent, wdt, 44, { name = "Dan Rider", state = "joined", source = "whisper", at = 1000, station = "Undercity" })
		ok(r.station:IsShown(), "setup: the station chip")
		r.getapp:Hide() -- the station and ride-count chips alone, as for a rider who has Wuber
		D.LayRow(r)
		eq(r:GetHeight(), 44, "two lines at " .. wdt)
		local chip = r.again
		if chip:GetRight() > r.more:GetLeft() and chip:GetTop() > r.more:GetBottom() - 12 then
			seen = seen + 1
			ok(r.more:GetBottom() - chip:GetTop() >= 1.99, "2 clear at " .. wdt)
			ok(r:GetTop() - r.more:GetTop() >= 0.99, "1 to the row's top at " .. wdt)
			ok(chip:GetBottom() - r:GetBottom() >= 0.99, "1 to the row's foot at " .. wdt)
			eq(r.more:GetHeight(), 20, "the low button at " .. wdt)
		elseif chip:GetRight() <= r.more:GetLeft() - 8 then -- clear of the button's column and its gap of 8
			eq(r.more:GetHeight(), 22, "no chip under the button: 22 at " .. wdt)
		end
		r:Hide()
	end
	D.Stations = real
	ok(seen > 0, "setup: at some width the ride-count chip lies under the button's column")
	T.clean(w)
end)
