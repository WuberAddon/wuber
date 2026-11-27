-- A lead's row (someone who only whispered) shows the rides so far ("1 ride with you"), not "2nd ride with you".
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function row(rides, state)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	W.Drive.GetAppState = function() return "ok" end
	W.Drive.RideCount = function() return rides end
	local D = W.Driver
	local parent = a.env.CreateFrame("Frame", nil, a.env.UIParent)
	parent:SetSize(400, 300)
	parent:SetPoint("CENTER")
	parent:Show()
	local r = D.Row(parent, 340)
	r:SetHeight(52)
	r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	D.PaintRow(r, { name = "Dan Rider", state = state, source = "whisper", at = 1000, msg = "good job mate!" }, 1000)
	return w, r
end

test("playtest Q4: a lead who paid once reads '1 ride with you'", function()
	local w, r = row(1, "lead")
	ok(r.again:IsShown(), "the chip shows")
	eq(r.again.label:GetText(), "1 ride with you", "rides so far")
	T.clean(w)
end)

test("playtest Q4: a lead who paid three times reads '3 rides with you'", function()
	local w, r = row(3, "lead")
	eq(r.again.label:GetText(), "3 rides with you", "rides so far, plural")
	T.clean(w)
end)

-- guard: a row for a ride that is under way still counts this ride ("2nd")
test("playtest Q4: a joined rider with one earlier ride still reads '2nd ride with you'", function()
	local w, r = row(1, "joined")
	eq(r.again.label:GetText(), "2nd ride with you", "the nth ride")
	T.clean(w)
end)

-- guard: a lead with no paid ride has no chip, and the whisperer stays listed (the row is drawn)
test("playtest Q4: a lead with no earlier ride has no chip and the row is still shown", function()
	local w, r = row(0, "lead")
	ok(not r.again:IsShown(), "no chip")
	ok(r:IsShown() or r.name:GetText() ~= nil, "the row is there")
	T.clean(w)
end)
