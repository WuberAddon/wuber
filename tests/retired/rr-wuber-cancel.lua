-- RETIRED 24 Nov 2026 (job 2743). Why: it read the old addon's own customer list; a Wuber cancel reaching a provider's onCancel is now in tests/oldaddon
-- Was in tests/run.lua. Not loaded by the suite; kept for the record. It needed the old addon's own code (Ritual Rides 1.4.1), which is not in this repository.

test("Ritual Rides: a Wuber cancel takes the rider off RR's list", function()
	rrNeeded()
	local w = newWorld()
	local cs = rrTeam(w)
	local r = rider(w)
	settle(w, 20)
	r.W.RequestRide("ana smith")
	w:advance(3)
	eq(count(cs[1].RR.customers), 1, "on the list")
	r.W.CancelRide()
	w:advance(3)
	eq(count(cs[1].RR.customers), 0, "off the list")
	clean(w)
end)
