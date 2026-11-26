local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("r34 m: HUNT-71 a watched-place alert due in combat waits for combat to end, not lost", function()
	local w = T.newWorld()
	local d1 = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local d2 = T.driver(w, T.BOB, { spot = "Undercity" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	r.W.db.watch[r.W.WatchKey("Ratchet")] = true
	r.W.db.watch[r.W.WatchKey("Undercity")] = true
	local got, inCombatAtFire = {}, {}
	r.W.Listen("WATCH_HIT", function(d)
		got[#got + 1] = r.W.WatchKey(d.dest)
		inCombatAtFire[#inCombatAtFire + 1] = r.W.InCombat()
	end)
	T.goOnline(d1) T.goOnline(d2)
	local n = 0
	while #got < 1 and n < 40 do w:advance(0.5) n = n + 1 end
	eq(#got, 1, "setup: the first place's alert fired")
	w:enterCombat(r)
	w:advance(10) -- the second alert's 6 s hold ends in combat
	eq(#got, 1, "no second alert is fired while in combat")
	w:leaveCombat(r)
	w:advance(1)
	eq(#got, 2, "the second alert comes after combat")
	ok(inCombatAtFire[2] == false, "fired out of combat")
	T.clean(w)
end)
