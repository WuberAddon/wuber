-- RETIRED 24 Nov 2026 (job 2743). Why: it tested the old addon's own RR.Classify whisper reader, not Wuber
-- Was in tests/run.lua. Not loaded by the suite; kept for the record. It needed the old addon's own code (Ritual Rides 1.4.1), which is not in this repository.

test("RR.Classify reads every W.PLACES request whisper as a request", function()
	rrNeeded()
	local w = newWorld()
	local cs = rrTeam(w)
	local W, RR = cs[1].W, cs[1].RR
	local bad = {}
	for _, place in ipairs(W.PLACES) do
		local name = place.name or place[1]
		local line = "WTB summon to " .. tostring(name) .. " for 50s"
		if RR.Classify(line) ~= "request" then bad[#bad + 1] = line end
	end
	ok(#W.PLACES > 20, "places listed")
	eq(#bad, 0, "not read as requests: " .. list(bad))
	clean(w)
end)
