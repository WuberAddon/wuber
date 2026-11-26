-- Round 8 (Wuber 2.3.0, SPEC7 8.2), agent E (Net): two-client scenarios over the real wire.
-- D field 18 (PvP), bounty -> driver demand -> serve -> the rider's toast, the passphrase on
-- both sides, a raincheck end to end on F's real book (Drive.Raincheck) and crew, the live
-- portal tracker over G. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local ANITA, TESTCHAR = T.ANITA, T.TESTCHAR

-- a Net-only driver whose beacon carries a PvP level (beacon b.danger / b.dangerSecs, as the
-- engine's beacon will from Drive.Danger)
local function dangerDriver(w, level, secs, extra)
	local d = T.driver(w, ANITA, { netOnly = true })
	local W, env = d.W, d.env
	W.SetLocalDriver(function()
		if W.Char().drive ~= true then return nil end
		local m = env.C_Map.GetBestMapForUnit("player")
		local pos = m and env.C_Map.GetPlayerMapPosition(m, "player")
		local b = { dest = "Ratchet", mapID = m, x = pos and pos.x, y = pos and pos.y, price = 5000,
			service = W.Me(), state = "open", team = 1, seats = 4, danger = level, dangerSecs = secs }
		for k, v in pairs(extra or {}) do b[k] = v end
		return b
	end)
	return d
end

local function lastD(w)
	local all = T.msgs(w, "D", ANITA)
	return all[#all]
end

test("r8 E: D field 18: a hot drop reaches the rider (level, when); none or garbled -> 0; a quiet beacon is unchanged", function()
	local w = T.newWorld()
	local d = dangerDriver(w, 2, 40)
	local r = T.rider(w)
	T.settle(w)
	T.goOnline(d)
	w:advance(3)
	local f = T.fields(lastD(w))
	eq(#f, 20, "fields 1-18 after kind and proto")
	eq(f[19], "", "field 17: no summoner")
	eq(f[20], "2:40", "field 18: level 2, 40 s ago")
	local dr = r.W.drivers["anita lift"]
	ok(dr, "listed")
	eq(dr.danger, 2, "the rider's driver: danger 2")
	ok(dr.dangerAt and math.abs((dr.heard - dr.dangerAt) - 40) < 0.01, "when: 40 s before the beacon")
	eq(dr.dangerSecs, 40, "dangerSecs as sent (C's cards)")
	-- garbled
	w:inject(ANITA, "D~1~Ratchet~1413~627~370~5000~Anita Lift~open~1~4~H~2.3.0~~0~1~~1~~9:x", "CHANNEL")
	eq(r.W.drivers["anita lift"].danger, 0, "garbled: 0")
	w:inject(ANITA, "D~1~Ratchet~1413~627~370~5000~Anita Lift~open~1~4~H~2.3.0~~0~1~~1~~7:30", "CHANNEL")
	eq(r.W.drivers["anita lift"].danger, 2, "a level over 2 is 2")
	w:inject(ANITA, "D~1~Ratchet~1413~627~370~5000~Anita Lift~open~1~4~H~2.2.3~~0~1~~1", "CHANNEL")
	eq(r.W.drivers["anita lift"].danger, 0, "absent (an older driver): 0")
	T.clean(w)
	-- no danger: the beacon is the 2.2 one (16 fields; no 17 without a summoner, no 18)
	local w2 = T.newWorld()
	local d2 = dangerDriver(w2, 0, 0)
	local r2 = T.rider(w2)
	T.settle(w2)
	T.goOnline(d2)
	w2:advance(3)
	eq(#T.fields(lastD(w2)), 18, "a quiet beacon: fields 1-16 only")
	eq(r2.W.drivers["anita lift"].danger, 0, "danger 0")
	T.clean(w2)
end)

test("r8 E: the worst-case D (32-byte dest, 24-letter service, long summoner and realm) stays <= 250 bytes with field 18", function()
	local w = T.newWorld()
	local d = dangerDriver(w, 1, 3600, { dest = string.rep("Q", 40), summoner = "Bartholomewsy Longsurnamexyz",
		service = string.rep("S", 30), queue = 40 })
	d.realm = "CAMWOW EU5 Realm 5 PvE With A Much Longer Name Than Usual"
	local r = T.rider(w)
	T.settle(w)
	d.W.Char().price = 99999999
	T.goOnline(d)
	w:advance(3)
	local e = lastD(w)
	ok(e, "a beacon")
	ok(#e.text <= 250, "D <= 250 bytes: " .. #e.text)
	local f = T.fields(e)
	eq(f[20], "1:3600", "field 18 intact")
	eq(f[19], "Bartholomewsy Longsurnamexyz", "field 17 intact")
	T.clean(w)
end)

test("r8 E: bounty -> driver demand -> the driver opens there -> the rider's bounty ends and the watch toast says so", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Gadgetzan" })
	local r = T.rider(w)
	T.settle(w)
	eq(r.W.Bounty.Pin("Gadgetzan", 7500), true, "Wuber pins a bounty")
	w:advance(2)
	local dem = d.W.Bounty.Demand()
	eq(#dem, 1, "Anita sees the demand")
	eq(dem[1].place, "Gadgetzan", "for Gadgetzan")
	eq(dem[1].riders, 1, "one rider")
	eq(dem[1].low, 7500, "75s")
	local hits, ends = {}, {}
	r.W.Listen("WATCH_HIT", function(drv) hits[#hits + 1] = drv and drv.name end)
	r.W.Listen("BOUNTY", function(kind, b, why, who) if why then ends[#ends + 1] = why .. ":" .. tostring(who) end end)
	w:advance(60)
	T.goOnline(d)
	w:advance(5)
	eq(r.W.Bounty.Mine(), nil, "the bounty is over")
	eq(ends[1], "served:Anita Lift", "served, by Anita")
	ok(#hits >= 1, "the watch toast (WATCH_HIT) fires for the place")
	w:advance(2)
	eq(#d.W.Bounty.Demand(), 0, "the driver's demand clears (copper 0)")
	T.clean(w)
end)

test("r8 E: the passphrase is the same on both sides of a real ride", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { netOnly = true })
	local r = T.rider(w)
	T.settle(w)
	T.goOnline(d)
	local ride = r.W.RequestRide("anita lift")
	w:advance(1)
	local inc = d.W.incoming[1]
	ok(inc and inc.id == ride.id, "the driver has the request")
	local mine = r.W.Passphrase(r.W.ride.id, r.W.myKey or "wuber testcharacter")
	local theirs = d.W.Passphrase(inc.id, inc.buyerKey)
	ok(mine and mine:match("^%u%l+ %u%l+$"), "two words: " .. tostring(mine))
	eq(theirs, mine, "the driver sees the same words")
	T.clean(w)
end)

-- Ana's crew (three Warlock windows, Ana on the network; F's real engine and raincheck book)
-- open at Undercity, and Wuber (the app, 2.3.0) at Orgrimmar
local ANA, BEA, CAL = T.ANA, T.BEA, T.CAL
local SPOT = "Undercity"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function crewScene()
	local w = T.H.NewWorld({})
	local names = { ANA, BEA, CAL }
	local cs = {}
	for i, name in ipairs(names) do
		local crew = {}
		for _, n in ipairs(names) do
			if n ~= name then crew[#crew + 1] = { name = n, role = "lock", app = true } end
		end
		local saved = { chars = { [key(name)] = { crew = crew, captain = (name == ANA) and "" or ANA, wizard = true } } }
		cs[i] = w:addClient(name, { spot = SPOT, class = "WARLOCK", saved = { Wuber = saved } })
	end
	local r = w:addClient(TESTCHAR, { spot = "Orgrimmar", class = "MAGE", money = 1000000 })
	r.W.VERSION = "2.3.0"
	w:group(names)
	w:advance(15)
	cs[1].W.Drive.SetOpen(true)
	w:advance(8)
	return w, cs[1], cs[2], cs[3], r
end

local function iou(c) return (c.W.db.drive and c.W.db.drive.iou) or {} end

test("r8 E: raincheck end to end on the real book: paid by trade, fails, ask, give, accept, rebook free, used on arrival; the crew agrees", function()
	local w, ana, bea, cal, r = crewScene()
	local DR = ana.W.Drive
	local ride = r.W.RequestRide(key(ANA))
	ok(ride, "Wuber books Ana")
	w:advance(9)
	local c = DR.customers[key(TESTCHAR)]
	ok(c and c.wuberRide == ride.id, "Ana's engine took the Wuber ride")
	eq(r.W.ride.state, "ingroup", "Wuber is in the group")
	-- the passphrase: D's row (W.Driver.Passphrase) and Wuber's Found screen say the same words
	local words = r.W.Passphrase(r.W.ride.id, r.W.myKey)
	ok(words, "the rider's words")
	ana.W.Drive.SetOpt("showPass", true) -- (round 9) the words show only with "Show ride passphrase" on
	if ana.W.Driver and ana.W.Driver.Passphrase then eq(ana.W.Driver.Passphrase(c), words, "the driver's row: the same words") end
	eq(ana.W.Driver.Passphrase(c) and true, true, "on: the captain's row has them")
	-- Wuber pays the whole fare by a completed trade before the summon (the harness checks the
	-- zone only as the window opens; the here check never sees Wuber at Undercity)
	local gp, ap = w:player(TESTCHAR), w:player(ANA)
	local zone = gp.zone
	gp.zone = ap.zone
	ok(w:openTrade(ap, gp), "a trade opens")
	gp.zone = zone
	w:tradeMoney(gp, ride.price)
	w:tradeAccept(ap)
	w:tradeAccept(gp)
	w:advance(1)
	ok(r.W.ride.paid, "the rider's record: paid in full")
	-- the summon never comes: Wuber gives up
	ok(r.W.CancelRide(), "the ride ends before arrival (" .. tostring(r.W.ride.state) .. ", stage " .. tostring(r.W.ride.stage) .. ")")
	w:leave(TESTCHAR)
	w:advance(3)
	local okE, why = DR.RaincheckEligible(ride.id)
	ok(okE, "the book: eligible (" .. tostring(why) .. ")")
	eq(r.W.Raincheck.CanAsk(r.W.ride), true, "the rider may ask (the ride table)")
	local alerts = 0
	ana.W.Listen("DRIVE_ALERT", function(_, kind) if kind == "raincheck" then alerts = alerts + 1 end end)
	ok(r.W.Raincheck.Ask(ride.id), "Wuber asks")
	w:advance(2)
	eq(alerts, 1, "Ana's window is alerted once")
	-- Ana's click (the row menu's "Give raincheck"): V give to Wuber, IOU i to the crew
	local okG, id = DR.GiveRaincheck(ride.id)
	ok(okG, "Ana gives one: " .. tostring(id))
	w:advance(2)
	local mine = r.W.Raincheck.Mine()[1]
	ok(mine and mine.id == id, "Wuber's copy has it")
	eq(mine.state, "offered", "offered")
	eq(mine.cover, ride.price, "it covers the fare paid")
	eq(r.W.Raincheck.ForDriver(key(ANA)), nil, "not usable before accepting")
	for _, cw in ipairs({ ana, bea, cal }) do eq(iou(cw)[id] and iou(cw)[id].state, "offered", cw.player.name .. ": offered") end
	ok(r.W.Raincheck.Accept(id), "Wuber accepts")
	w:advance(2)
	for _, cw in ipairs({ ana, bea, cal }) do eq(iou(cw)[id] and iou(cw)[id].state, "active", cw.player.name .. ": active") end
	-- rebook Ana: R field 7 names it, the book takes it (A field 4 = 1): nothing to pay
	r.W.ClearRide()
	w:advance(65)
	eq(r.W.Raincheck.ForDriver(key(ANA), ana.W.Char().service), id, "usable with Ana's crew")
	local ride2, why2 = r.W.RequestRide(key(ANA))
	ok(ride2, "booked again: " .. tostring(why2))
	eq(ride2.voucher, id, "the request names the raincheck")
	w:advance(9)
	local rs = T.msgs(w, "R", TESTCHAR)
	local rf = T.fields(rs[#rs])
	eq(rf[9], id, "R field 7")
	eq(r.W.ride.voucherTaken, true, "taken")
	eq(r.W.ride.raincheck and r.W.ride.raincheck.taken, true, "W.ride.raincheck.taken")
	eq(r.W.ride.price, 0, "covers the whole fare: nothing to pay")
	local c2 = DR.customers[key(TESTCHAR)]
	eq(c2 and c2.voucher, id, "the engine redeemed it")
	eq(iou(ana)[id].state, "active", "still active until arrival")
	-- the summon (here: Wuber arrives at Undercity): used, in every window and in Wuber's copy
	eq(r.W.ride.state, "ingroup", "Wuber is back in the group (stage " .. tostring(r.W.ride.stage) .. ", engine " .. tostring(c2.state) .. ")")
	w:move(TESTCHAR, SPOT)
	w:advance(4)
	local c3 = DR.customers[key(TESTCHAR)]
	local diag = " (engine " .. tostring(c3 and c3.state) .. ", onRide " .. tostring(iou(ana)[id].onRide) .. ", ride " .. tostring(c3 and DR.RideIdOf(c3)) .. ", voucher " .. tostring(c3 and c3.voucher) .. ", rider " .. tostring(r.W.ride.state) .. ")"
	for _, cw in ipairs({ ana, bea, cal }) do eq(iou(cw)[id].state, "used", cw.player.name .. ": used" .. diag) end
	eq(r.W.Raincheck.Mine()[1].state, "used", "Wuber's copy: used")
	eq(r.W.ride.state, "done", "arrived, nothing owed")
	eq(DR.RaincheckRedeem(id, key(TESTCHAR), 5000, DR.customers[key(TESTCHAR)] or {}), false, "a replay after use is refused")
	for _, e in ipairs(w.addonLog) do ok(#e.text <= 250, "every message <= 250 bytes: " .. e.text) end
	T.clean(w)
end)

test("r8 E: the live tracker over G: phases from the driver's window reach the rider in order", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { netOnly = true })
	local r = T.rider(w)
	r.W.VERSION = "2.3.0"
	T.settle(w)
	T.goOnline(d)
	local ride = r.W.RequestRide("anita lift")
	w:advance(1)
	d.W.AcceptRequest(ride.id, 5)
	w:advance(1)
	local seen = {}
	r.W.Listen("RITUAL", function(rit) seen[#seen + 1] = rit.phase .. rit.tapped end)
	for _, p in ipairs({ { "q", 0 }, { "t", 0 }, { "c", 0 }, { "h", 1 }, { "h", 2 }, { "s", 2 } }) do
		d.W.SendRitual(ride.id, TESTCHAR, p[1], p[2], 2, ANITA, 0)
		w:advance(2)
	end
	eq(table.concat(seen, ","), "q0,t0,c0,h1,h2,s2", "every phase, in order")
	T.clean(w)
end)
