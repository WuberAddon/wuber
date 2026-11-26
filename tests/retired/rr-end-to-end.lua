-- RETIRED 24 Nov 2026 (job 2743). Why: it drove a whole ride through the old addon's own button, invites and trade code; WuberAPI accept/cancel/rate through a coexisting addon is now in tests/oldaddon
-- Was in tests/run.lua. Not loaded by the suite; kept for the record. It needed the old addon's own code (Ritual Rides 1.4.1), which is not in this repository.

test("Ritual Rides end to end (RR 1.4.1 drives, Wuber's engine locked): request, accept, invite, summon, pay, rate", function()
	rrNeeded()
	local w = newWorld()
	local cs = rrTeam(w)
	local r = rider(w)
	settle(w)
	r.W.db.autoAccept = false -- this test clicks Wuber's Accept invite button
	w:advance(8) -- the rider's Q on joining is answered within a few seconds
	ok(r.W.drivers["ana smith"], "the rider sees the team")
	local price = r.W.drivers["ana smith"].price
	requestVia(r, "ana smith")
	w:advance(3)
	-- one customer in Ritual Rides, though both the whisper and R arrived
	local n = 0
	for _ in pairs(cs[1].RR.customers) do n = n + 1 end
	eq(n, 1, "one RR customer")
	eq(#msgs(w, "A", ANA, "WHISPER"), 1, "RR accepted through WuberAPI")
	w:advance(6)
	ok(r.popups.PARTY_INVITE, "RR invited the rider")
	r:clickText("Accept invite")
	w:advance(3)
	eq(rideState(r), "ingroup")
	-- the summon: Ana presses the RR button, Bea and Cal click the portal
	cs[1]:click(cs[1].env.RitualRidesButton)
	w:advance(3)
	ok(w:clickPortal(cs[2]), "Bea clicks the portal")
	ok(w:clickPortal(cs[3]), "Cal clicks the portal")
	w:advance(1)
	eq(rideState(r), "portal", "summon up")
	r:clickText("Accept summon")
	w:advance(5)
	eq(w:player(TESTCHAR).zone, "The Barrens")
	ok(r.W.RIDE_RANK[rideState(r)] >= r.W.RIDE_RANK.arrived, "arrived: " .. tostring(rideState(r)))
	-- RR's trade: whoever opens it, the rider pays
	if not w:player(TESTCHAR).trade then
		for _, c in ipairs(cs) do if not w:player(TESTCHAR).trade then w:openTrade(c, r) end end
	end
	w:advance(1)
	w:tradeMoney(r, price)
	local cashier = w:player(TESTCHAR).trade.a == w:player(TESTCHAR) and w:player(TESTCHAR).trade.b or w:player(TESTCHAR).trade.a
	w:tradeAccept(r)
	w:tradeAccept(cashier)
	w:advance(5)
	eq(rideState(r), "done")
	ok(r.W.Rate(5), "rated")
	w:advance(3)
	eq(#msgs(w, "T", TESTCHAR), 1, "T sent")
	local said = false
	for _, c in ipairs(cs) do if c:said("rated the ride") then said = true end end
	ok(said, "RR says the rating")
	-- stage words
	for _, e in ipairs(msgs(w, "S")) do
		local st = fields(e)[4]
		ok(({ invited = 1, summoning = 1, portal = 1, arrived = 1, paid = 1, done = 1 })[st], "stage word " .. tostring(st))
	end
	-- SPEC3 3.3: the whole ride ran on RR 1.4.1, Wuber's engine stayed locked off
	for _, c in ipairs(cs) do assertLocked(c) end
	clean(w)
end)
