-- Round 37 b: FEAT-01, the average summon time (data and wire only; no words yet). A ready driver's
-- completed rides keep { total = request -> arrival, cast = cast start -> arrival } (the last 20);
-- DR.SummonAvg() is their mean once there are 3; the beacon D carries it as field 21; riders read
-- it into d.avgSummon and the Fly or summon card uses it as the wait.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local ANITA, TESTCHAR, BOB = T.ANITA, T.TESTCHAR, T.BOB

local function samples(d)
	local db = d.W.db and d.W.db.drive
	return (type(db) == "table" and type(db.summons) == "table") and db.summons or {}
end

-- put n saved samples of { total, cast } in the driver's data
local function seed(d, list)
	d.W.db.drive = d.W.db.drive or {}
	local s = {}
	for i, v in ipairs(list) do s[i] = { total = v[1], cast = v[2] } end
	d.W.db.drive.summons = s
end

local function online(opts)
	local w = T.newWorld()
	local d = T.driver(w, ANITA, opts)
	for _, n in ipairs({ "Dan Miller", "Eve Stone", "Fay Bell" }) do w:addBot(n, { spot = "Orgrimmar", class = "MAGE" }) end
	T.settle(w) T.goOnline(d) w:advance(5)
	return w, d
end

local function clock(d) return d.env.GetTime() end

-- A ride the engine's own way, with the markers it sets (DR.Create / DR.SetState, c.castAt, c.arrivedAt):
-- asked, wait a, cast, b to the summon, c more to arrival; paid by trade unless o.byHand.
local function fakeRide(w, d, name, a, b, c, o)
	o = o or {}
	local W, DR = d.W, d.W.Drive
	local r
	if o.leadFor then
		r = DR.Create(name, "lead", "whisper")
		w:advance(o.leadFor)
		DR.ResetRide(r)
		DR.SetState(r, "queued")
	else
		r = DR.Create(name, "queued", "whisper")
	end
	w:advance(a)
	DR.SetState(r, "invited")
	DR.SetState(r, "joined")
	r.castAt, r.tries = clock(d), 1
	DR.SetState(r, "summoning")
	w:advance(b)
	r.endAt = clock(d)
	DR.SetState(r, "waiting")
	w:advance(c)
	if o.walked then r.walked, r.tries = true, 0 end
	if o.crewArrival then
		DR.SetState(r, "arrived") -- a crew window's ST: arrived, no arrival this window saw
		r.arrivedAt = r.arrivedAt or clock(d)
	else
		r.arrivedAt = clock(d)
		DR.SetState(r, "arrived")
	end
	w:advance(1)
	if o.before then o.before(r) end
	W.Fire("DRIVE_PAID", r.name, r.price or 5000, 0, W.myKey, true, o.byHand and "m" or "t", r.price or 5000)
	DR.SetState(r, "paid")
	w:advance(1)
	return r
end

test("r37 b: a fixed list of rides gives their mean in whole seconds, cast too", function()
	local w, d = online()
	local DR = d.W.Drive
	ok(type(DR.SummonAvg) == "function", "DR.SummonAvg is there")
	seed(d, { { 40, 10 }, { 50, 20 }, { 61, 31 } })
	local total, cast, n = DR.SummonAvg()
	eq(total, 50, "(40 + 50 + 61) / 3 = 50.3: 50")
	eq(cast, 20, "(10 + 20 + 31) / 3 = 20.3: 20")
	eq(n, 3, "three rides")
	seed(d, { { 37, 12 }, { 80, 40 }, { 44, 15 }, { 52, 21 } })
	total, cast, n = DR.SummonAvg()
	eq(total, 53, "(37 + 80 + 44 + 52) / 4 = 53.25: 53")
	eq(cast, 22, "(12 + 40 + 15 + 21) / 4 = 22")
	eq(n, 4)
	T.clean(w)
end)

test("r37 b: fewer than 3 rides: no average, and no field 21 on the beacon (today's bytes)", function()
	local w, d = online()
	local DR = d.W.Drive
	seed(d, {})
	d.W.SendBeacon(true) w:advance(1)
	local list = T.msgs(w, "D", ANITA)
	ok(#list > 0, "control: the driver beacons")
	local none = list[#list].text
	seed(d, { { 40, 10 }, { 50, 20 } })
	w:advance(10)
	local total, cast, n = DR.SummonAvg()
	eq(total, nil, "two rides: no average")
	eq(cast, nil)
	eq(n, 2)
	d.W.SendBeacon(true) w:advance(1)
	list = T.msgs(w, "D", ANITA)
	eq(list[#list].text, none, "two rides: exactly the bytes of a driver with none")
	eq(#T.fields(list[#list]), 18, "kind, protocol and 16 fields")
	seed(d, { { 40, 10 }, { 50, 20 }, { 61, 31 } })
	w:advance(10)
	d.W.SendBeacon(true) w:advance(1)
	list = T.msgs(w, "D", ANITA)
	local three = list[#list].text
	eq(three, none .. "~~~~~50", "three rides: fields 17-20 empty and field 21 the average")
	eq(T.fields(list[#list])[23], "50", "field 21 (after kind and protocol)")
	T.clean(w)
end)

test("r37 b: only the last 20 rides count, and a new ride pushes the oldest out", function()
	local w, d = online()
	local DR = d.W.Drive
	local list = {}
	for i = 1, 5 do list[#list + 1] = { 900, 800 } end
	for i = 1, 20 do list[#list + 1] = { 30, 10 } end
	seed(d, list)
	local total, cast, n = DR.SummonAvg()
	eq(total, 30, "the five slow old rides are not among the last 20")
	eq(cast, 10)
	eq(n, 20)
	-- 20 kept: a real ride (25 s: 5 to the cast, 20 cast to arrival) drops the oldest
	list = {}
	list[1] = { 900, 800 }
	for i = 2, 20 do list[i] = { 30, 10 } end
	seed(d, list)
	fakeRide(w, d, "Dan Miller", 5, 15, 5)
	local s = samples(d)
	eq(#s, 20, "still 20 kept")
	eq(s[20] and s[20].total, 25, "newest last: request to arrival")
	eq(s[20] and s[20].cast, 20, "cast start to arrival")
	eq(s[1] and s[1].total, 30, "the oldest (900) went")
	T.clean(w)
end)

test("r37 b: a ready driver's ride gives one sample; a lead counts from the moment they asked", function()
	local w, d = online()
	seed(d, {})
	fakeRide(w, d, "Dan Miller", 4, 20, 6)
	local s = samples(d)
	eq(#s, 1, "one sample")
	eq(s[1] and s[1].total, 30, "4 + 20 + 6")
	eq(s[1] and s[1].cast, 26)
	fakeRide(w, d, "Eve Stone", 3, 10, 2, { leadFor = 40 })
	s = samples(d)
	eq(#s, 2, "the lead's ride counts")
	eq(s[2] and s[2].total, 15, "from their request, not from when they were listed (40 s before)")
	T.clean(w)
end)

test("r37 b: left out: walked, paid by hand, a crew window's arrival, raid mode, queued behind another", function()
	local w, d = online()
	local DR = d.W.Drive
	seed(d, {})
	fakeRide(w, d, "Dan Miller", 2, 10, 2, { walked = true })
	eq(#samples(d), 0, "a rider who walked")
	fakeRide(w, d, "Eve Stone", 2, 10, 2, { byHand = true })
	eq(#samples(d), 0, "a payment marked by hand")
	fakeRide(w, d, "Fay Bell", 2, 10, 2, { crewArrival = true })
	eq(#samples(d), 0, "an arrival this window never saw")
	-- raid mode: not selling
	local sell = DR.Selling
	DR.Selling = function() return false end
	DR.Remove(DR.customers["dan miller"], "done")
	fakeRide(w, d, "Dan Miller", 2, 10, 2)
	DR.Selling = sell
	eq(#samples(d), 0, "a raid-mode summon")
	-- queued behind another: Eve is being summoned when Dan asks
	DR.Remove(DR.customers["dan miller"], "done")
	DR.Remove(DR.customers["eve stone"], "done")
	local eve = DR.Create("Eve Stone", "queued", "whisper")
	DR.SetState(eve, "invited")
	DR.SetState(eve, "joined")
	fakeRide(w, d, "Dan Miller", 2, 10, 2)
	eq(#samples(d), 0, "a ride that waited behind another rider")
	-- control: the same ride with nobody ahead counts
	DR.Remove(eve, "done")
	DR.Remove(DR.customers["dan miller"], "done")
	fakeRide(w, d, "Dan Miller", 2, 10, 2)
	eq(#samples(d), 1, "control: nobody ahead, it counts")
	T.clean(w)
end)

test("r37 b: a ride restored after a /reload gives no sample", function()
	local w, d = online()
	local DR = d.W.Drive
	seed(d, {})
	local r = DR.Create("Dan Miller", "queued", "whisper")
	w:advance(2)
	DR.SetState(r, "invited")
	DR.SetState(r, "joined")
	r.castAt, r.tries = clock(d), 1
	DR.SetState(r, "summoning")
	w:advance(5)
	-- after the /reload the row is back (as DR.RestoreQueue makes it): created again, its saved times copied
	DR.Remove(r, "done")
	local again = DR.Create("Dan Miller", "joined", "group")
	again.castAt, again.tries = r.castAt, 1
	DR.SetState(again, "summoning")
	w:advance(5)
	again.arrivedAt = clock(d)
	DR.SetState(again, "arrived")
	d.W.Fire("DRIVE_PAID", again.name, 5000, 0, d.W.myKey, true, "t", 5000)
	DR.SetState(again, "paid")
	eq(#samples(d), 0, "no request time this session saw: left out")
	T.clean(w)
end)

-- a D from name with these fields 17.. (nil: the 20-field beacon of 2.3.2)
local function beacon(w, name, f21, fields)
	local f = { "D", "1", "Ratchet", "1413", "500", "500", "5000", "", "open", "1", "0", "", "2.3.4-dev", "", "0", "1", "", "1", "", "", "", "" }
	if f21 ~= nil then f[#f + 1] = f21 end
	if fields then f = fields end
	w:inject(name, table.concat(f, "~"), "CHANNEL")
	w:advance(0.5)
end

test("r37 b: a rider reads field 21; older beacons and bad values give nil; a later beacon without it clears it", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local key = "dee nobody"
	beacon(w, "Dee Nobody", "45")
	ok(r.W.drivers[key], "control: heard")
	eq(r.W.drivers[key].avgSummon, 45, "45 s heard")
	eq(r.W.UI.Driver(key).avgSummon, 45, "and in the driver view")
	beacon(w, "Dee Nobody", nil)
	eq(r.W.drivers[key].avgSummon, nil, "a later beacon without field 21 clears it")
	for _, bad in ipairs({ "0", "5", "9", "901", "abc", "35x", "", " 35", "3.5e1", "-40" }) do
		beacon(w, "Dee Nobody", "45")
		beacon(w, "Dee Nobody", bad)
		eq(r.W.drivers[key].avgSummon, nil, "'" .. bad .. "' is not sent")
	end
	beacon(w, "Dee Nobody", "10")
	eq(r.W.drivers[key].avgSummon, 10, "10 s is in range")
	beacon(w, "Dee Nobody", "900")
	eq(r.W.drivers[key].avgSummon, 900, "900 s is in range")
	-- a 2.3.2 driver's 20 fields
	beacon(w, "Dee Nobody", nil, { "D", "1", "Ratchet", "1413", "500", "500", "5000", "", "open", "1", "0", "", "2.3.2", "", "0", "1", "", "1", "", "", "", "0" })
	eq(r.W.drivers[key].avgSummon, nil, "an older beacon (20 fields): none")
	T.clean(w)
end)

test("r37 b: the Fly or summon numbers use the driver's heard average, else W.SUMMON_SECS", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local W = r.W
	local Booking = W.Mod("UI.Rider.Booking")
	local real = W.TravelSaved
	W.TravelSaved = function() return 600, "same continent", true end
	local info = Booking.DialInfo({ dest = "Ratchet", price = 5000, queue = 0 }, 5000)
	eq(info.wait, W.SUMMON_SECS, "no average: the shared default")
	eq(info.timeSaved, 600 - W.SUMMON_SECS)
	info = Booking.DialInfo({ dest = "Ratchet", price = 5000, queue = 0, avgSummon = 75 }, 5000)
	eq(info.wait, 75, "the driver's average")
	eq(info.waitKnown, true)
	eq(info.timeSaved, 525, "600 - 75")
	info = Booking.DialInfo({ dest = "Ratchet", price = 5000, queue = 0, avgSummon = 75 }, 5000, { wait = 200 })
	eq(info.wait, 200, "a wait the caller knows (a busy driver's) wins")
	info = Booking.DialInfo({ dest = "Ratchet", price = 5000, queue = 0, avgSummon = 3 }, 5000)
	eq(info.wait, W.SUMMON_SECS, "an average outside 10..900 is no average")
	-- through the network: a beacon with 75 makes the driver view carry it
	beacon(w, "Dee Nobody", "75")
	local v = W.UI.Driver("dee nobody")
	info = Booking.DialInfo(v, 5000)
	eq(info and info.wait, 75, "the heard driver's view")
	W.TravelSaved = real
	T.clean(w)
end)

test("r37 b: the longest D with the average still fits in 250 bytes, no field cut", function()
	local w, d = online()
	local W, DR = d.W, d.W.Drive
	seed(d, { { 900, 900 }, { 900, 900 }, { 900, 900 } })
	local badge = ""
	for id in pairs(W.BADGE_BY_ID or {}) do if #id > #badge then badge = id end end
	local realm = string.rep("R", 40)
	d.env.GetRealmName = function() return realm end
	local ver, flag = W.VERSION, W.EmblemFlag
	W.VERSION = "2.3.10-beta12"
	W.EmblemFlag = function() return "0" end
	local dest, service, summoner = string.rep("D", 32), "Quick Summons Every Hour", "Abcdefghijkl Mnopqrstuvwx"
	local real = DR.NetBeacon
	DR.NetBeacon = function()
		local b = real()
		if not b then return nil end
		b.dest, b.service, b.price, b.state, b.team, b.seats, b.queue = dest, service, 99999999, "paused", 3, 40, 40
		b.summoner, b.danger, b.dangerSecs, b.showPass, b.badge = summoner, 2, 3600, true, badge
		b.mapID, b.x, b.y = 99999, 1, 1
		return b
	end
	W.SendBeacon(true) w:advance(1)
	local list = T.msgs(w, "D", ANITA)
	local text = list[#list].text
	local f = T.fields(list[#list])
	DR.NetBeacon, W.VERSION, W.EmblemFlag = real, ver, flag
	ok(#text <= 250, "the longest D is " .. #text .. " bytes")
	eq(f[3], dest, "the dest whole")
	eq(f[8], service, "the service whole")
	eq(f[17], string.rep("R", 32), "the realm whole (32)")
	eq(f[19], summoner, "the summoner whole")
	eq(f[20], "2:3600", "danger")
	eq(f[21], "1", "passphrase flag")
	eq(f[22], "0", "emblem flag")
	eq(f[23], "900", "field 21: the average")
	eq(#f, 23, "nothing after it")
	T.clean(w)
end)

-- a whole ride, rider and driver (tests/r32/r32_p3_rides_test.lua's)
local function doneRide(w, d, r, name)
	r.W.db.autoAccept = false
	r.W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(1)
	r.W.UI.Toggle(true)
	w:advance(2.5)
	r:clickText("Accept invite")
	w:advance(1)
	d.W.Drive.Do("CAST", name) -- the cast start the engine's cast watch reports (the fake w:summon has none)
	w:advance(1)
	w:summon(d, name)
	w:advance(1)
	r:clickText("Accept summon")
	w:advance(3)
	w:openTrade(d, r)
	w:advance(0.5)
	w:tradeMoney(r, 5000)
	w:tradeAccept(d)
	w:tradeAccept(r)
	w:advance(1)
	r.W.UI.Toggle(false)
	w:advance(1)
end

test("r37 b: two whole rides make the average; the rider hears it and the card uses it", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Ratchet" })
	local g = T.rider(w, TESTCHAR, { spot = "Orgrimmar" })
	local b = T.rider(w, BOB, { spot = "Orgrimmar" })
	T.settle(w) T.goOnline(d) w:advance(5)
	seed(d, { { 40, 20 } })
	doneRide(w, d, g, TESTCHAR)
	eq(g.W.ride and g.W.ride.state, "done", "control: Wuber's ride is done")
	local s = samples(d)
	eq(#s, 2, "Wuber's ride gave a sample")
	local first = s[2]
	ok(first and first.total >= first.cast and first.cast > 0 and first.total < 60,
		"request to arrival " .. tostring(first and first.total) .. " s, cast to arrival " .. tostring(first and first.cast) .. " s")
	eq(d.W.Drive.SummonAvg(), nil, "two rides: no average yet")
	w:advance(30)
	doneRide(w, d, b, BOB)
	eq(b.W.ride and b.W.ride.state, "done", "control: Bob's ride is done")
	eq(#samples(d), 3, "Bob's ride too")
	local avg = d.W.Drive.SummonAvg()
	ok(avg, "three rides: an average")
	w:advance(70) -- the next beacons
	local heard = g.W.drivers["anita lift"]
	eq(heard and heard.avgSummon, avg, "Wuber hears the average")
	local Booking = g.W.Mod("UI.Rider.Booking")
	local real = g.W.TravelSaved
	g.W.TravelSaved = function() return 600, "same continent", true end
	local view = g.W.UI.Driver("anita lift")
	view.queue = 0
	local info = Booking.DialInfo(view, 5000)
	eq(info and info.wait, avg, "the card's wait is Anita's average")
	g.W.TravelSaved = real
	T.clean(w)
end)

test("r37 b: a whole ride marked paid by hand gives no sample", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Ratchet" })
	local g = T.rider(w, TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w) T.goOnline(d) w:advance(5)
	seed(d, {})
	g.W.db.autoAccept = false
	g.W.RequestRide("anita lift")
	w:advance(2)
	g.W.UI.Toggle(true) w:advance(2.5)
	g:clickText("Accept invite") w:advance(1)
	d.W.Drive.Do("CAST", TESTCHAR) w:advance(1)
	w:summon(d, TESTCHAR) w:advance(1)
	g:clickText("Accept summon") w:advance(3)
	local c = d.W.Drive.Find(TESTCHAR)
	eq(c and c.state, "arrived", "control: summoned and here")
	ok(c and (c.tries or 0) > 0 and not c.walked, "control: summoned, not walked")
	d.W.Drive.MarkPaid(c) w:advance(2)
	eq(c.state == "paid" or c.state == "done", true, "control: marked paid")
	eq(#samples(d), 0, "by hand: no sample")
	T.clean(w)
end)
