-- RETIRED 24 Nov 2026 (job 2743). Why: it tests the Lab addon logging the old addon's own customers and button; the Lab is a separate in-game tool and the old addon is gone
-- Was in tests/lab.lua. Not loaded by the suite; kept for the record. It needed the old addon's own code (Ritual Rides 1.4.1), which is not in this repository.

test("lab: a full Ritual Rides ride is logged on every window and the checklists tick themselves", function()
	if not HAVE_RR then error("Ritual Rides not found") end
	local w = newWorld()
	local cs = labTeam(w)
	local r = labRider(w)
	settle(w)
	w:advance(8)
	local key = "anita lift"
	ok(r.W.drivers[key], "the rider sees the team")
	local price = r.W.drivers[key].price
	requestVia(r, key)
	w:advance(3)
	eq(#w:messages("A", ANITA, "WHISPER"), 1, "accepted")
	w:advance(8)
	eq(rideState(r), "ingroup", "invite taken by itself")
	cs[1]:click(cs[1].env.RitualRidesButton)
	w:advance(3)
	ok(w:clickPortal(cs[2]), "Farra clicks the portal")
	ok(w:clickPortal(cs[3]), "Hayley clicks the portal")
	w:advance(1)
	eq(rideState(r), "portal")
	r:clickText("Accept summon")
	w:advance(5)
	ok(r.W.RIDE_RANK[rideState(r)] >= r.W.RIDE_RANK.arrived, "arrived")
	if not w:player(ROCKS).trade then
		for _, c in ipairs(cs) do if not w:player(ROCKS).trade then w:openTrade(c, r) end end
	end
	w:advance(1)
	w:tradeMoney(r, price)
	local tr = w:player(ROCKS).trade
	local cashier = tr.a == w:player(ROCKS) and tr.b or tr.a
	w:tradeAccept(r)
	w:tradeAccept(cashier)
	w:advance(5)
	eq(rideState(r), "done")
	ok(r.W.Rate(5), "rated")
	w:advance(6)

	-- the rider's timeline: each stage once, in order, with durations
	local states = {}
	for _, l in ipairs(find(r, "ride")) do
		local id, st = l:match("^([^;]+);([^;]+);")
		if id and id ~= "-" then states[#states + 1] = st end
	end
	-- (Ritual Rides invites at once: the invite can come before the A, so "accepted" may be skipped)
	local want = { "requesting", "invited", "ingroup", "portal", "arrived", "done" }
	local at = 1
	for _, s in ipairs(states) do if s == want[at] then at = at + 1 end end
	eq(at, #want + 1, "ride stages in order (" .. table.concat(states, ",") .. ")")
	ok(#find(r, "ride", "dt=") >= 6, "durations")
	ok(#find(r, "msg>", "R W>") >= 1, "R out logged")
	ok(#find(r, "msg<", "A W<") >= 1, "A in logged")
	ok(#find(r, "whsp", "> Anita Lift: WTB summon") == 1, "visible whisper logged")
	ok(#find(r, "ridef", "autoAccepted=true") == 1, "auto accept logged")
	ok(#find(r, "ridef", "acceptedAt=") == 1, "the driver's A logged even after the invite")
	ok(#find(r, "ev", "PARTY_INVITE_REQUEST inviter='Anita Lift'") == 1, "raw inviter: " .. list(find(r, "ev", "PARTY_INVITE"), " / "))
	ok(#find(r, "try", "cap=accept ok=true") == 1, "W.Try accept logged")
	ok(#find(r, "ev", "CONFIRM_SUMMON") == 1, "summon box logged")
	ok(#find(r, "ev", "PLAYER_MONEY -") >= 1, "money down logged")
	-- the rider's checklist
	for _, id in ipairs({ "r_booked", "r_whisper", "r_accepted", "r_invite", "r_summon", "r_arrived", "r_pay", "r_left", "r_rated", "r_milestone", "r_open" }) do
		eq(checked(r, id), "auto", "rider step " .. id)
	end
	ok(labOf(r).Result("r_accepted").took ~= nil, "time taken since the step before")
	eq(checked(r, "r_cancel"), nil, "not ticked by mistake")
	-- the driver's window
	local d = cs[1]
	ok(#find(d, "prov", "onRequest") == 1, "provider request logged")
	ok(#find(d, "api", "Accept id=") == 1, "WuberAPI.Accept logged")
	ok(#find(d, "drv", ";stage:portal;") == 1, "driver stage logged")
	ok(#find(d, "rr", "customer Wuber Rocks") >= 3, "RR customer states")
	for _, id in ipairs({ "d_provider", "d_online", "d_request", "d_accept", "d_invited", "d_summoning", "d_portal", "d_arrived", "d_paid", "d_rating" }) do
		eq(checked(d, id), "auto", "driver step " .. id)
	end
	-- the team windows
	for i = 2, 3 do
		eq(labOf(cs[i]).Role(), "team")
		eq(checked(cs[i], "t_provider"), "auto", "team provider")
		eq(#find(cs[i], "drv", ";stage:"), 0, "no stages from a team window")
	end
	local cashierClient = cashier.client
	if cashierClient and labOf(cashierClient).Role() == "team" then eq(checked(cashierClient, "t_cashier"), "auto", "cashier") end
	-- the plan ticks itself on whichever window saw it, and the four windows share it
	w:advance(60)
	local function planR(c, id) local rec = labOf(c).PlanRec(id) return rec and rec.r end
	for _, id in ipairs({ "s2_1", "s3_r3", "s3_r4", "s3_r5", "s3_r6", "s3_c2", "s3_c3", "s3_c4", "s3_c5", "s3_c6", "s3_r8", "s3_c1", "s3_c7", "s3_d1", "s0_1", "s1_1", "s5_6" }) do
		for _, c in ipairs({ r, cs[1], cs[2], cs[3] }) do
			eq(planR(c, id), "auto", "plan step " .. id .. " on " .. c.player.name)
		end
	end
	eq(labOf(cs[1]).PlanRec("s3_c1").who, ANITA, "the whisper reaching Anita was ticked on Anita")
	eq(labOf(r).PlanRec("s3_c7").who, ANITA, "Ritual Rides' log, from Anita, on Wuber Rocks")
	eq(planR(r, "s3_r7"), nil, "Pay button not used here (the test traded by hand)")
	eq(planR(r, "s0_2"), nil, "Wuber Rocks has no Ritual Rides here: not ticked")
	eq(planR(cs[2], "s0_2@wuber rocks"), "no", "Wuber Rocks' probe result shared")
	eq(planR(cs[2], "s0_2@anita lift"), "ok", "Anita's probe result shared")
	ok(#find(cs[2], "plan", "s3_c2;auto;by=auto_accept;who=Wuber Rocks;src=sync") == 1, "sync logged")
	local wlab = 0
	for _, e in ipairs(w.addonLog) do if e.prefix == "WLAB" then wlab = wlab + 1 end end
	ok(wlab < 120, "plan sync stays light: " .. wlab .. " messages")
	if os.getenv("LAB_DUMP") then print("plan sync messages: " .. wlab) end
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WLAB" then
			ok(e.chatType == "WHISPER" or e.chatType == "PARTY" or e.chatType == "RAID", "plan sync only by whisper or group: " .. tostring(e.chatType))
			if e.chatType == "WHISPER" then ok(({ [ANITA] = 1, [FARRA] = 1, [HAYLEY] = 1, [ROCKS] = 1 })[e.target], "plan whisper to " .. tostring(e.target)) end
		end
	end
	labOf(r).PlanMark("s5_1", "fail")
	labOf(r).PlanNote("s5_1", "crown too small")
	w:advance(20)
	labOf(r).MarkStep("r_crown", "fail")
	labOf(r).SetNote("r_crown", "crown sits inside the cow")
	labOf(r).Mark("ride one done")
	r:fire("ADDON_ACTION_BLOCKED", "Wuber", "AcceptTrade()")
	dumpSaved(r, "ROCKS1")
	dumpSaved(cs[1], "GLNWLS2K")
	dumpSaved(cs[2], "WOW1")
	dumpSaved(cs[3], "WOW2")
	for _, c in ipairs({ r, cs[1], cs[2], cs[3] }) do
		ok(#find(c, "laberr") == 0, c.player.name .. " lab faults: " .. list(find(c, "laberr"), "\n"))
		ok(#find(c, "err") == 0, c.player.name .. " Lua errors: " .. list(find(c, "err"), "\n"))
	end
	clean(w)
end)
