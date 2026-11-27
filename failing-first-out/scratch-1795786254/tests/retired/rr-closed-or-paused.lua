-- RETIRED 24 Nov 2026 (job 2743). Why: it used the old addon's /rr off; Wuber answering a provider's N closed is now in tests/oldaddon
-- Was in tests/run.lua. Not loaded by the suite; kept for the record. It needed the old addon's own code (Ritual Rides 1.4.1), which is not in this repository.

test("Ritual Rides: closed or paused -> N closed", function()
	rrNeeded()
	local w = newWorld()
	local cs = rrTeam(w)
	local r = rider(w)
	settle(w, 20)
	ok(r.W.drivers["ana smith"], "seen")
	cs[1]:slash("/rr off")
	r.W.RequestRide("ana smith")
	w:advance(3)
	local N = msgs(w, "N", ANA)
	if #N == 0 then
		-- the rider dropped the closed team already (X)
		ok(r.W.ride == nil or rideState(r) ~= "accepted", "not accepted while closed")
	else
		eq(fields(N[1])[4], "closed", "reason")
	end
	clean(w)
end)
