-- Round 8 (Wuber 2.3.0), agent F (engine): two-client scenarios over the real wire.
-- A rider with the app and a 3-window crew: the live portal tracker (G from the engine's facts),
-- the passphrase in a crew window (ST field 9), the PvP warning from a crew window's fight (HI
-- field 11 -> beacon D field 18 -> the rider's driver list), a raincheck end to end on Drive.Raincheck's
-- book (trade, ask, give, accept, free rebook, used on arrival) and its abuse cases over the wire.
-- Loaded by tests/run.lua.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local ANA, BEA, CAL, TESTCHAR = "Ana Smith", "Bea Jones", "Cal Brown", "Wuber TestCharacter"
local SPOT = "Undercity"

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function crewSaved(me, names, captain)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end
	end
	return { chars = { [key(me)] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true } } }
end

-- the crew (open) and a rider whose app is 2.3.0 (riderVersion) at Orgrimmar
local function crewAndRider(riderVersion)
	local w = H.NewWorld({})
	local names = { ANA, BEA, CAL }
	local cs = {}
	for i, name in ipairs(names) do
		cs[i] = w:addClient(name, { spot = SPOT, class = "WARLOCK", saved = { Wuber = crewSaved(name, names, ANA) } })
	end
	local r = w:addClient(TESTCHAR, { spot = "Orgrimmar", class = "MAGE", money = 1000000 })
	if riderVersion then r.W.VERSION = riderVersion end
	w:group(names)
	w:advance(15)
	cs[1].W.Drive.SetOpen(true)
	w:advance(8)
	return w, cs[1], cs[2], cs[3], r
end

local function gs(w)
	local out = {}
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBER" and e.from == ANA and e.text:match("^G~") then out[#out + 1] = e.text end
	end
	return out
end

test("r8 F: the live portal tracker: the crew's facts reach a 2.3.0 rider as G, in order; an older rider gets none", function()
	local w, ana, bea, cal, r = crewAndRider("2.3.0")
	ok(r.W.RequestRide(key(ANA)), "requested")
	w:advance(9)
	local c = ana.W.Drive.customers[key(TESTCHAR)]
	ok(c and c.wuberRide and c.state == "joined", "Wuber joined Ana's group")
	eq(c.wuberVer, "2.3.0", "R field 6 reached the engine")
	local id = c.wuberRide
	local seen = {}
	r.W.Listen("RITUAL", function(rit) seen[#seen + 1] = rit and rit.phase end)
	ana.W.Drive.Do("GR", TESTCHAR)
	w:advance(2)
	ana.W.Drive.Do("CAST", TESTCHAR)
	w:advance(2)
	bea.W.Drive.Do("HELP", TESTCHAR)
	w:advance(2)
	cal.W.Drive.Do("HELP", TESTCHAR)
	w:advance(2)
	ana.W.Drive.Do("END", TESTCHAR, 1)
	w:advance(2)
	local list = gs(w)
	ok(#list >= 5, "G sent: " .. table.concat(list, " | "))
	for _, g in ipairs(list) do
		ok(#g <= 45, "G <= 45 bytes: " .. g)
		ok(g:find("~" .. id .. "~", 1, true), "the ride id")
	end
	local rit = r.W.ride and r.W.ride.ritual
	ok(rit, "the rider has W.ride.ritual")
	eq(rit.phase, "s", "summon sent")
	eq(rit.tapped, 2) eq(rit.need, 2)
	eq(table.concat(seen, " "):match("c h h s$") ~= nil, true, "the rider saw c h h s: " .. table.concat(seen, " "))
	T.clean(w)

	-- an older rider (2.2.3: the test clients are 2.3.0 now, so say so): no G at all
	w, ana, bea, cal, r = crewAndRider("2.2.3")
	ok(r.W.RequestRide(key(ANA)), "requested")
	w:advance(9)
	ana.W.Drive.Do("CAST", TESTCHAR)
	w:advance(2)
	ana.W.Drive.Do("END", TESTCHAR, 1)
	w:advance(2)
	eq(#gs(w), 0, "no G for a rider without a 2.3.0 R")
	T.clean(w)
end)

test("r8 F: the live portal tracker lives on after the driver's /reload (c.wuberVer back in Net's ride versions)", function()
	local w, ana, bea, cal, r = crewAndRider("2.3.0")
	ok(r.W.RequestRide(key(ANA)), "requested")
	w:advance(9)
	local c = ana.W.Drive.customers[key(TESTCHAR)]
	ok(c and c.wuberRide and c.state == "joined", "Wuber joined Ana's group")
	local id = c.wuberRide
	local ana2 = w:reload(ana)
	w:advance(5)
	local c2 = ana2.W.Drive.customers[key(TESTCHAR)]
	ok(c2 and c2.wuberRide == id, "the ride is back after the /reload")
	eq(c2.wuberVer, "2.3.0", "with the rider's version")
	local before = #gs(w)
	local seen = {}
	r.W.Listen("RITUAL", function(rit) seen[#seen + 1] = rit and rit.phase end)
	ana2.W.Drive.Do("GR", TESTCHAR)
	w:advance(2)
	ana2.W.Drive.Do("CAST", TESTCHAR)
	w:advance(2)
	local list = gs(w)
	ok(#list > before, "G sent after the /reload: " .. table.concat(list, " | "))
	for i = before + 1, #list do ok(list[i]:find("~" .. id .. "~", 1, true), "the ride id: " .. list[i]) end
	ok(#seen > 0, "the rider heard it")
	eq(seen[#seen], "c", "casting")
	-- an old rider's restored ride still gets none
	eq(ana2.W.SendRitual(id, "Bob Stone", "c", 0, 2, ANA, 0), false, "never to another rider under that ride id")
	T.clean(w)
end)

test("r8 F: the passphrase: a crew window learns the ride id from ST and shows the rider's words", function()
	local w, ana, bea, cal, r = crewAndRider("2.3.0")
	ok(r.W.RequestRide(key(ANA)), "requested")
	w:advance(9)
	local c = ana.W.Drive.customers[key(TESTCHAR)]
	local cb = bea.W.Drive.customers[key(TESTCHAR)]
	ok(cb, "Bea lists Wuber")
	eq(bea.W.Drive.RideIdOf(cb), c.wuberRide, "Bea knows the ride id (ST field 9)")
	eq(cb.wuberRide, nil, "Bea doesn't take the ride over")
	local words = bea.W.Passphrase(bea.W.Drive.RideIdOf(cb), key(TESTCHAR))
	ok(words and words:find(" "), "two words: " .. tostring(words))
	eq(words, r.W.Passphrase(r.W.ride.id, key(TESTCHAR)), "the rider's words are the same")
	T.clean(w)
end)

test("r8 F: PvP: Cal fights an enemy player, the crew's beacon carries it, the rider's list warns", function()
	local w, ana, bea, cal, r = crewAndRider("2.3.0")
	w:addBot("Ally Foe", { faction = "Alliance", spot = SPOT })
	w:advance(1)
	eq((r.W.drivers[key(ANA)] or {}).danger or 0, 0, "calm at first")
	w:pvpFight(cal, "Ally Foe")
	w:advance(8)
	local d = r.W.drivers[key(ANA)]
	ok(d, "Ana listed")
	eq(d.danger, 2, "the rider sees a hot drop")
	local last
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBER" and e.from == ANA and e.text:match("^D~") then last = e.text end
	end
	ok(last and last:find("~2:%d+$") and #last <= 250, "D ends with field 18: " .. tostring(last))
	T.clean(w)
end)

-- Raincheck over the real wire. The crew stands at Ratchet; Wuber stands just over the
-- Durotar border: within reach of a trade with Ana (the harness's trade range and UnitIsVisible are
-- the zone) but on another map, so the driver's here check (DR.Here: visible AND the same map) never
-- counts him arrived, and his own (W.DestHere) doesn't either. Nothing in tests/lib changes for it.
local BORDER = { mapID = 1411, x = 0.04, y = 0.45, zone = "The Barrens", sub = "" }

local function rainCrew(others)
	local w = H.NewWorld({})
	local names = { ANA, BEA, CAL }
	local cs = {}
	for i, name in ipairs(names) do
		cs[i] = w:addClient(name, { spot = "Ratchet", class = "WARLOCK", saved = { Wuber = crewSaved(name, names, ANA) } })
	end
	local r = w:addClient(TESTCHAR, { spot = BORDER, class = "MAGE", money = 1000000 })
	r.W.VERSION = "2.3.0"
	local more = {}
	for i, n in ipairs(others or {}) do
		more[i] = w:addClient(n, { spot = "Orgrimmar", class = "MAGE", money = 1000000 })
		more[i].W.VERSION = "2.3.0"
	end
	w:group(names)
	w:advance(15)
	cs[1].W.Drive.SetOpen(true)
	w:advance(8)
	return w, cs[1], cs[2], cs[3], r, more
end

local function books(list, id)
	local out = {}
	for _, c in ipairs(list) do
		local b = c.W.db.drive.iou
		out[#out + 1] = (b and b[id] and b[id].state) or "-"
	end
	return table.concat(out, " ")
end

-- the last A Ana whispered to `who`, split
local function lastA(w, who)
	local text
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBER" and e.from == ANA and (e.to == nil or e.to == who) and e.text:match("^A~") then text = e.text end
	end
	local f = {}
	for x in ((text or "") .. "~"):gmatch("([^~]*)~") do f[#f + 1] = x end
	return f, text
end

-- Wuber's ride to Ana's crew: paid by trade, Ana closes before casting, Wuber cancels, asks, Ana gives,
-- Wuber accepts. Returns the ride, the raincheck id and the fare.
local function activeRaincheck(w, ana, bea, cal, r)
	local DR = ana.W.Drive
	local ride = r.W.RequestRide(key(ANA))
	ok(ride, "requested")
	w:advance(9)
	local c = DR.customers[key(TESTCHAR)]
	ok(c and c.wuberRide == ride.id, "Ana took the Wuber ride")
	ok(c and c.state == "joined", "Wuber joined; not here: " .. tostring(c and c.state))
	local fare = c.price
	ok(fare and fare > 0, "a fare: " .. tostring(fare))
	-- Wuber pays by trade (he types the money; Wuber never does)
	ok(w:openTrade(w:player(TESTCHAR), w:player(ANA)), "a trade over the border")
	w:tradeMoney(w:player(TESTCHAR), fare)
	w:tradeAccept(w:player(ANA))
	w:tradeAccept(w:player(TESTCHAR))
	w:advance(2)
	ok(r.W.ride.paid, "Wuber's record: paid")
	local e = DR.recentPaid[#DR.recentPaid]
	ok(e and e.ride == ride.id and e.traded >= fare and e.paidAt, "Ana's book: paid in full by trade")
	eq(c.arrivedAt, nil, "never arrived")
	-- Ana closes before casting; the summon never comes, Wuber gives up
	DR.SetOpen(false)
	w:advance(3)
	if r.W.RideActive() then ok(r.W.CancelRide(), "Wuber cancels") end
	w:advance(3)
	ok(not r.W.RideActive(), "the ride is over for Wuber: " .. tostring(r.W.ride and r.W.ride.state))
	eq(DR.RaincheckEligible(ride.id), true, "eligible: " .. tostring((select(2, DR.RaincheckEligible(ride.id)))))
	ok(r.W.Raincheck.CanAsk(ride.id), "Wuber may ask: " .. tostring((select(2, r.W.Raincheck.CanAsk(ride.id)))))
	ok(r.W.Raincheck.Ask(ride.id), "Wuber asks (V ask)")
	w:advance(2)
	local alert
	for _, f in ipairs(ana.fired) do if f.name == "DRIVE_ALERT" and f.args[2] == "raincheck" then alert = f.args[3] end end
	ok(alert and alert.rideId == ride.id and alert.name == TESTCHAR, "Ana is alerted, with the ride")
	eq(r.W.Raincheck.Ask(ride.id), false, "one ask per ride")
	eq(#r.W.Raincheck.Mine(), 0, "nothing offered until Ana clicks")
	eq(ana.W.db.drive.iou, nil, "and nothing in the book")
	-- Ana clicks Give (V give, IOU i)
	local okG, id = DR.GiveRaincheck(ride.id)
	ok(okG, "given: " .. tostring(id))
	w:advance(2)
	local mine = r.W.Raincheck.Mine()[1]
	ok(mine and mine.id == id and mine.state == "offered", "Wuber has the offer")
	eq(mine and mine.cover, fare, "it covers what he paid")
	eq(books({ ana, bea, cal }, id), "offered offered offered", "offered in every window")
	ok(r.W.Raincheck.Accept(id), "Wuber accepts (V ok)")
	w:advance(2)
	eq(books({ ana, bea, cal }, id), "active active active", "active only now, in every window")
	return ride, id, fare
end

-- Wuber leaves Ana's group and clears the old ride; Ana opens again
local function reopen(w, ana, r)
	w:leave(TESTCHAR)
	r.W.ClearRide()
	ana.W.Drive.SetOpen(true)
	w:advance(65)
end

test("r8 F: raincheck over the real wire: paid by trade, closed before the cast, ask, give, accept; the rebook is free (A field 4), used on arrival", function()
	local w, ana, bea, cal, r = rainCrew()
	local DR = ana.W.Drive
	local _, id, fare = activeRaincheck(w, ana, bea, cal, r)
	reopen(w, ana, r)
	local ride2, why = r.W.RequestRide(key(ANA))
	ok(ride2, "booked again: " .. tostring(why))
	eq(ride2 and ride2.voucher, id, "R field 7 names the raincheck")
	w:advance(1)
	local f, text = lastA(w, TESTCHAR)
	eq(f[#f], "1", "A's last field: taken (" .. tostring(text) .. ")")
	eq(r.W.ride.voucherTaken, true, "Wuber: taken")
	eq(r.W.ride.price, 0, "nothing to pay")
	w:advance(8)
	local c = DR.customers[key(TESTCHAR)]
	ok(c and c.voucher == id and c.price == 0, "Ana bills nothing")
	eq(bea.W.Drive.customers[key(TESTCHAR)] and bea.W.Drive.customers[key(TESTCHAR)].price, 0, "Bea bills nothing (ST flag v)")
	eq(books({ ana, bea, cal }, id), "active active active", "not used on request")
	-- the summon: Wuber accepts and arrives at Ratchet
	w:summon(ana, TESTCHAR)
	w:advance(1)
	w.hardware = r r.W.AcceptSummon() w.hardware = nil
	w:advance(6)
	eq(books({ ana, bea, cal }, id), "used used used", "used on arrival, in every window")
	eq(r.W.Raincheck.Mine()[1].state, "used", "Wuber's copy: used")
	eq(r.W.ride.state, "done", "arrived, nothing owed")
	local given, used = DR.RaincheckCounts(0)
	eq(given, 1) eq(used, 1)
	ok(fare > 0)
	T.clean(w)
end)

test("r8 F: raincheck abuse over the real wire: another rider naming Wuber's id, a replay after use: the normal fare", function()
	local DAN = "Dan Miller"
	local w, ana, bea, cal, r, more = rainCrew({ DAN })
	local dan = more[1]
	local DR = ana.W.Drive
	local _, id, fare = activeRaincheck(w, ana, bea, cal, r)
	reopen(w, ana, r)
	-- Dan's (modified) client names Wuber's raincheck in R field 7: the book checks the event's sender
	dan.W.Raincheck.ForDriver = function() return id, fare end
	local dride = dan.W.RequestRide(key(ANA))
	ok(dride and dride.voucher == id, "Dan's R names Wuber's id")
	w:advance(1)
	local f = lastA(w, DAN)
	ok(f[#f] ~= "1", "A: not taken")
	eq(dan.W.ride.voucherTaken, nil, "Dan: not taken")
	eq(dan.W.ride.price, fare, "Dan pays the normal fare")
	eq(books({ ana, bea, cal }, id), "active active active", "Wuber's raincheck untouched")
	w:advance(8)
	eq(DR.customers[key(DAN)] and DR.customers[key(DAN)].voucher, nil, "no voucher on Dan's row")
	dan.W.CancelRide()
	w:advance(3)
	-- Wuber uses it (free ride, arrives)
	local ride2 = r.W.RequestRide(key(ANA))
	ok(ride2 and ride2.voucher == id, "Wuber books with it")
	w:advance(9)
	w:summon(ana, TESTCHAR)
	w:advance(1)
	w.hardware = r r.W.AcceptSummon() w.hardware = nil
	w:advance(6)
	eq(books({ ana, bea, cal }, id), "used used used", "used")
	-- a replay: Wuber's (modified) client names the used id again
	w:leave(TESTCHAR)
	r.W.ClearRide()
	w:move(TESTCHAR, BORDER)
	w:advance(65)
	r.W.Raincheck.ForDriver = function() return id, fare end
	local ride3 = r.W.RequestRide(key(ANA))
	ok(ride3 and ride3.voucher == id, "the replayed id goes out")
	w:advance(1)
	local f3 = lastA(w, TESTCHAR)
	ok(f3[#f3] ~= "1", "A: not taken")
	eq(r.W.ride.voucherRefused, true, "Wuber: raincheck not taken, normal fare")
	eq(r.W.ride.price, fare, "the normal fare")
	eq(books({ ana, bea, cal }, id), "used used used", "still used")
	T.clean(w)
end)
