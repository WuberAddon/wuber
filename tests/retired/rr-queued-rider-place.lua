-- RETIRED 24 Nov 2026 (job 2743). Why: it used the old addon's /rr max; WuberAPI.Queue (P to the rider) through a coexisting addon is now in tests/oldaddon
-- Was in tests/round2.lua. Not loaded by the suite; kept for the record. It needed the old addon's own code (Ritual Rides 1.4.1), which is not in this repository.

test("Ritual Rides: a queued Wuber rider is told their place (P through WuberAPI.Queue)", function()
	T.rrNeeded()
	local w = newWorld()
	local cs = T.rrTeam(w)
	local r1 = rider(w)
	local r2 = rider(w, BOB, { spot = "Undercity" })
	settle(w, 20)
	ok(r1.W.drivers["ana smith"] and r2.W.drivers["ana smith"], "both see the team")
	cs[1]:slash("/rr max 4") -- the three Warlocks and one rider: the second waits in the queue
	w:advance(1)
	r1.W.RequestRide("ana smith")
	w:advance(3)
	r2.W.RequestRide("ana smith")
	w:advance(8)
	local P = msgs(w, "P", ANA, "WHISPER")
	ok(#P >= 1, "a P from the team (" .. #P .. ")")
	local toBob
	for _, e in ipairs(P) do if e.target:gsub("%-", " ") == BOB then toBob = e end end
	ok(toBob, "Bob (second) is told his place")
	eq(position(r2), 1, "Bob holds place 1 (next)")
	if HAVE_UI then
		r2.W.UI.Show("home")
		w:advance(2.5)
		ok(#r2:findText("You're next") + #r2:findText("in line") > 0, "the place shown (" .. texts(r2) .. ")")
	end
	clean(w)
end)
