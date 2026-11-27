-- Group E (prep-242): the trade strip after a late arrival (AU24-08) and the mid-flight offer only for a faster summon (AU24-14).
local T = ...
local test = T.test
local ok, H = T.ok, T.H
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- the strip must show whenever a trade is open and the ride has arrived, however late the arrival is noticed
local function stripAfterLateArrival(step)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	local MIA = "Mia Runner"
	r.W.ride = { id = "r6", driver = MIA, driverKey = key(MIA), dest = "Undercity", price = 5000, state = "summoning",
		at = r.env.GetTime(), payee = MIA, payto = "Mia", summoner = MIA, service = "Mia's Rides" }
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(3)
	w:addBot(MIA, { spot = "Orgrimmar" })
	H.state[r.env.TradeFrame].shown = true
	ok(w:openTrade(w:player(MIA), r.player), "the driver opens trade")
	for _ = 1, math.floor(1.5 / step + 0.5) do w:advance(step) end
	r.W.ride.state = "arrived"
	r.W.Fire("RIDE")
	w:advance(3)
	local n = #r:findText("Wuber: ")
	T.clean(w)
	return n
end
test("AU24-08 fix: the strip shows when the arrival is noticed after the trade opened (1 s steps)", function()
	ok(stripAfterLateArrival(1) > 0, "strip shown")
end)
-- guard: at 5 s steps the 0.15 s look runs after the arrival, so the base already shows the strip
test("AU24-08 fix: the strip shows when the arrival is noticed after the trade opened (5 s steps)", function()
	ok(stripAfterLateArrival(5) > 0, "strip shown")
end)

-- guard: a RIDE event with no trade open shows no strip (the strip has no job without a trade)
test("AU24-08 guard: no trade open, no strip after a RIDE event", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	local MIA = "Mia Runner"
	r.W.ride = { id = "r7", driver = MIA, driverKey = key(MIA), dest = "Undercity", price = 5000, state = "arrived",
		at = r.env.GetTime(), payee = MIA, payto = "Mia", summoner = MIA, service = "Mia's Rides" }
	r.W.Fire("RIDE")
	w:advance(3)
	ok(#r:findText("Wuber: ") == 0, "no strip without a trade")
	T.clean(w)
end)

local UC_TM = {
	{ name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 },
	{ name = "Tarren Mill, Hillsbrad", type = "REACHABLE", cost = 330, x = 0.47, y = 0.44 },
}
-- avgs: list of summon seconds, one open driver each; returns the key the card names (or nil)
local function offer(avgs, flight)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Undercity", screenW = 1365, screenH = 768 })
	T.settle(w)
	r.W.db.flights = r.W.db.flights or {}
	r.W.db.flights["H|undercity|tarren mill"] = { t = flight, tat = r.env.time(), tsrc = "own" }
	r.W.drivers = r.W.drivers or {}
	for i, avg in ipairs(avgs) do
		local nm = "Driver" .. string.char(64 + i)
		r.W.drivers[key(nm)] = { name = nm, key = key(nm), dest = "Tarren Mill", price = 5000 + i, state = "open",
			team = 3, service = nm .. "'s Rides", heard = r.env.GetTime(), avgSummon = avg }
	end
	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, flight, "Tarren Mill")
	w:advance(8)
	local Mod = r.W.Mod("UI.InFlight")
	local c = Mod.Card()
	local shown = c and H.visible(c) and c.key or nil
	T.clean(w)
	return shown
end
test("AU24-14 fix: a driver whose summon is slower than the flight left gets no card", function()
	ok(offer({ 600 }, 200) == nil, "no card for a 600 s summon")
end)
test("AU24-14 fix: a slow driver is skipped and the fast one is offered", function()
	ok(offer({ 600, 30 }, 200) == "drivera" or offer({ 600, 30 }, 200) == "driverb", "a card shows")
	ok(offer({ 600, 30 }, 200) == "driverb", "the fast driver, not the slow one")
end)
-- guard: the fast driver alone is offered as before
test("AU24-14 guard: a 30 s summon is still offered mid-flight", function()
	ok(offer({ 30 }, 200) == "drivera", "card for the fast driver")
end)
