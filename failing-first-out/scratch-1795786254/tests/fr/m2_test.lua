-- Fix round group m2: HUNT-128, a newer bounty replaces the older at the driver whatever the queue delay.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("fr m2 HUNT-128: a bounty changed within the driver's one-a-minute gap still replaces the first", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local fac = d.W.Faction()
	d.W.Mod("Net.Bounty").heard("addr", "Wuber", "Wuber-Tester", { "Gadgetzan", 6000, fac, 10 })
	w:advance(35)
	d.W.Mod("Net.Bounty").heard("addr", "Wuber", "Wuber-Tester", { "Ratchet", 6000, fac, 10 })
	local places = {}
	for _, row in ipairs(d.W.Bounty.Demand()) do places[row.place] = true end
	ok(places.Ratchet, "the newer place is shown")
	ok(not places.Gadgetzan, "the older place is gone")
	-- the same wish repeated inside the gap is still not counted twice
	w:advance(35)
	d.W.Mod("Net.Bounty").heard("addr", "Wuber", "Wuber-Tester", { "Ratchet", 6000, fac, 10 })
	local n = 0
	for _, row in ipairs(d.W.Bounty.Demand()) do n = n + row.riders end
	eq(n, 1, "one rider")
	T.clean(w)
end)
