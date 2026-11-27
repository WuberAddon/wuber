-- Fix round 2.4, group k: the booking card (Booking.lua) and the finding screen's pill (Confirm.lua)
local T = ...
local test, ok, eq = T.test, T.ok, T.eq

test("fr.k: HUNT-139 the dial's grey line wraps (never cut) and the dial grows for it", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local Mod = r.W.Mod("UI.Rider.Booking")
	local dial = Mod.Dial(r.env.UIParent, 324, 88)
	dial:SetPoint("TOPLEFT", r.env.UIParent, "TOPLEFT", 10, -10)
	local info = { timeSaved = 180, fare = 9000, flightCost = 4050, flySecs = 600, wait = 120, rate = 1,
		line = "Summon is 3 min faster \194\183 worth about 12g 34s 56c of your time, which is a lot of money to you indeed" }
	dial:Set(info)
	ok(dial.line.wuberWrapped, "the long line wrapped")
	ok(dial.line:IsTruncated() ~= true, "and is not cut")
	ok((dial.extra or 0) > 0, "the dial grew for it: " .. tostring(dial.extra))
	dial:Set({ timeSaved = 180, fare = 9000, flightCost = 4050, flySecs = 600, wait = 120, rate = 1, line = "Short line" })
	ok(not dial.line.wuberWrapped, "a short line stays one line")
	eq(dial.extra or 0, 0, "no extra height for it")
	T.clean(w)
end)

test("fr.k: HUNT-143 the finding screen's second Leave group pill has a tooltip", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local Confirm = r.W.Mod("UI.Rider.Confirm")
	local Booking = r.W.Mod("UI.Rider.Booking")
	ok(Confirm and Booking, "modules")
	local src = T.readFile(T.dir .. "/../Wuber/UI/Rider/Confirm.lua")
	local n = 0
	for _ in src:gmatch('T%.Tip%(s%.leave, "Leave group"') do n = n + 1 end
	ok(n >= 2, "both Leave group pills have T.Tip: " .. n)
	T.clean(w)
end)
