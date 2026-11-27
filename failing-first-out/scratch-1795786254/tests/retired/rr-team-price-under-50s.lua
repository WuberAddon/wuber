-- RETIRED 24 Nov 2026 (job 2743). Why: it checked the old addon's own /rr price message; Wuber not listing a provider under 50s is now in tests/oldaddon
-- Was in tests/run.lua. Not loaded by the suite; kept for the record. It needed the old addon's own code (Ritual Rides 1.4.1), which is not in this repository.

test("Ritual Rides: a team price under 50s stops beaconing and says why", function()
	rrNeeded()
	local w = newWorld()
	local cs = rrTeam(w)
	local r = rider(w)
	settle(w, 20)
	ok(r.W.drivers["ana smith"], "listed at the normal price")
	cs[1]:slash("/rr price 10s")
	w:advance(10)
	eq(r.W.drivers["ana smith"], nil, "the team is not listed under 50s")
	local told = false
	for _, c in ipairs(cs) do if c:said("Wuber needs a fare of at least 50s") then told = true end end
	ok(told, "RR says Wuber needs a fare of at least 50s")
	for _, e in ipairs(msgs(w, "D", ANA)) do
		if e.at > w.time - 9 then ok(tonumber(fields(e)[7]) >= 5000, "no beacon under 50s: " .. e.text) end
	end
	clean(w)
end)
