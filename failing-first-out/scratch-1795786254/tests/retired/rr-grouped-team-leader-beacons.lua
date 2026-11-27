-- RETIRED 24 Nov 2026 (job 2743). Why: it ran the old addon's own /rr team and /rr on commands; the Wuber side (only the leader's window beacons) is now tests/oldaddon/provider_standin_test.lua
-- Was in tests/run.lua. Not loaded by the suite; kept for the record. It needed the old addon's own code (Ritual Rides 1.4.1), which is not in this repository.

test("Ritual Rides: grouped team, only the leader beacons, after /rr team and /rr on", function()
	rrNeeded()
	local w = newWorld()
	local cs = rrTeam(w, { open = false })
	local r = rider(w)
	settle(w)
	for _, c in ipairs(cs) do
		eq(c.W.Provider(), "Ritual Rides", c.player.name .. " provider set")
		eq(c.W.Driver and c.W.Driver.SetOnline(true), false, "Wuber's own driver mode stays off with a provider")
	end
	eq(#msgs(w, "D"), 0, "no beacon before /rr on")
	cs[1]:slash("/rr on")
	w:advance(10)
	local senders = {}
	for _, e in ipairs(msgs(w, "D")) do senders[e.from] = true end
	eq(count(senders), 1, "one window beacons")
	ok(senders[ANA], "the leader beacons")
	local dd = r.W.drivers["ana smith"]
	ok(dd, "the rider sees the team")
	eq(dd.team, 3, "team of three")
	eq(dd.dest, "Ratchet")
	clean(w)
end)
