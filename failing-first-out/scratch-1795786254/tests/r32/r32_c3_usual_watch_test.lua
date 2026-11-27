local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function toArrived(w, d, r)
	r.W.db.autoAccept = false
	r.W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(1)
	r.W.UI.Toggle(true)
	w:advance(2.5)
	r:clickText("Accept invite")
	w:advance(1)
	w:summon(d, T.TESTCHAR)
	w:advance(1)
	r:clickText("Accept summon")
	w:advance(3)
end

test("r32 c3: AUD-18 control: a paid ride becomes 'your usual'", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w) T.goOnline(d) w:advance(5)
	toArrived(w, d, r)
	w:openTrade(d, r) w:advance(0.5) w:tradeMoney(r, 5000) w:tradeAccept(d) w:tradeAccept(r) w:advance(1)
	eq(r.W.ride.state, "done", "setup")
	ok(r.W.Usual() ~= nil, "control: Usual after a paid ride")
	T.clean(w)
end)

test("r32 c3: AUD-18 an unpaid ride does not become 'your usual'", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w) T.goOnline(d) w:advance(5)
	toArrived(w, d, r)
	r.W.EndRide() w:advance(1)
	local trip = r.W.db.rides[#r.W.db.rides]
	ok(trip and trip.unpaid, "setup: an unpaid trip is in the history")
	eq(r.W.Stats().rides, 0, "setup: Stats does not count it")
	local u = r.W.Usual()
	ok(u == nil, "no ride was ever paid, Stats says 0 rides, but Home would offer 'Your usual' to " .. tostring(u and u.dest) .. " with " .. tostring(u and u.driver))
	T.clean(w)
end)

test("r32 c3: HUNT-36 two watched places online together: one WATCH_HIT per place, each with its own drivers", function()
	local w = T.newWorld()
	local d1 = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local d2 = T.driver(w, T.BOB, { spot = "Undercity" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	r.W.db.watch[r.W.WatchKey("Ratchet")] = true
	r.W.db.watch[r.W.WatchKey("Undercity")] = true
	local got = {}
	r.W.Listen("WATCH_HIT", function(d, n, list)
		local places = {}
		for _, x in ipairs(list) do places[r.W.WatchKey(x.dest)] = true end
		local np = 0
		for _ in pairs(places) do np = np + 1 end
		got[#got + 1] = { dest = d.dest, n = n, places = np }
	end)
	T.goOnline(d1) T.goOnline(d2)
	w:advance(30)
	local seen = {}
	for _, g in ipairs(got) do
		eq(g.places, 1, "a toast's list holds one place only")
		seen[r.W.WatchKey(g.dest)] = true
	end
	ok(seen.ratchet and seen.undercity, "both places are named (" .. #got .. " toasts)")
	T.clean(w)
end)
