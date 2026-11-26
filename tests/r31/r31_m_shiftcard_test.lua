local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

test("audit C44b-6: a shift where only the crew took gold shows BEST HOUR as '-' on the Shift Complete card", function()
	local w = T.newWorld()
	local ana = w:addClient("Ana Smith", { spot = "Undercity", class = "WARLOCK" })
	local DR = ana.W.Drive
	w:advance(10)
	ok(DR.SetOpen(true), "open")
	w:advance(600)
	-- control: the driver's own payment gives a best hour
	DR.LogRide(6000, "Dan Miller", "t", 6000)
	w:advance(600)
	local c = DR.ShiftSummary()
	ok(c.bestHour ~= nil, "control: own ride should give a best hour")
	-- the bug: a crewmate took 2g in the shift, this window took nothing more
	local w2 = T.newWorld()
	local bob = w2:addClient("Bob Smith", { spot = "Undercity", class = "WARLOCK" })
	local D2 = bob.W.Drive
	w2:advance(10)
	ok(D2.SetOpen(true), "open 2")
	w2:advance(600)
	D2.LogTeamRide(20000, "Fay Moon", "bea jones", "bea jones")
	w2:advance(600)
	D2.SetOpen(false)
	local s = D2.ShiftSummary()
	eq(s.crewCopper, 20000, "the card reports the crew's 2g")
	ok(s.bestHour ~= nil and s.bestCopper >= 20000,
		"Shift Complete shows the crew took 2g but BEST HOUR reads '-' (bestHour=" .. tostring(s.bestHour) .. ", bestCopper=" .. tostring(s.bestCopper) .. ")")
	T.clean(w) T.clean(w2)
end)

test("r31 M: the Shift complete card's open time leaves out the time paused", function()
	local w = T.newWorld()
	local ana = w:addClient("Ana Smith", { spot = "Undercity", class = "WARLOCK" })
	local DR = ana.W.Drive
	w:advance(10)
	ok(DR.SetOpen(true), "open")
	w:advance(600)
	DR.SetPaused(true)
	w:advance(3000)
	DR.SetPaused(false)
	w:advance(600)
	DR.SetOpen(false)
	local s = DR.ShiftSummary()
	ok(s.open >= 1200 and s.open <= 1260, "open should be about 20 minutes, not 70: " .. tostring(s.open))
	T.clean(w)
end)
