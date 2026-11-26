-- Tests of Net.Raincheck. Loaded by tests/run.lua with its helper table T.
-- Round 8 step 0: the stub's contract (registered, deps = header Uses, public names) and that it
-- is idle (does nothing, sends nothing, saves nothing). The owner adds the behaviour tests.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("net.raincheck: contract (registered, deps, header, public names); idle with no ride", function()
	local W, w, r, Mod = T.contract("Net.Raincheck", "tests/net/raincheck_test.lua", {
		["W.Raincheck"] = "table",
		["W.Raincheck.Accept"] = "function",
		["W.Raincheck.Ask"] = "function",
		["W.Raincheck.Decline"] = "function",
		["W.Raincheck.ForDriver"] = "function",
		["W.Raincheck.Mine"] = "function",
		["W.SendIOU"] = "function",
		["W.Raincheck.CanAsk"] = "function",
		["W.Raincheck.Use"] = "function",
		["W.Raincheck.Using"] = "function",
		["W.Raincheck.Want"] = "function",
		["W.Raincheck.Used"] = "function",
		["W.Raincheck.Give"] = "function",
		["W.Raincheck.Void"] = "function",
		["Mod.heard"] = "function",
	})
	ok(Mod, "W.Mod(\"Net.Raincheck\")")
	local sent = #w.addonLog
	eq(W.Raincheck.Ask("r1"), false, "ask: nothing sent")
	eq(W.Raincheck.Accept("abcd1234"), false, "accept")
	eq(W.Raincheck.Decline("abcd1234"), false, "decline")
	eq(#W.Raincheck.Mine(), 0, "none held")
	eq(W.Raincheck.ForDriver("anita lift"), nil, "none for a driver")
	eq(W.SendIOU("i", "abcd1234"), false, "no rider key: no IOU fact")
	eq(#w.addonLog, sent, "no addon message")
	eq(W.db.rainchecks, nil, "nothing saved")
	T.clean(w)
end)

local ANITA, TESTCHAR, BOB = T.ANITA, T.TESTCHAR, T.BOB

local function vs(w, from)
	local out = {}
	for _, e in ipairs(T.msgs(w, "V", from)) do out[#out + 1] = e.text end
	return out
end

-- Anita (Net only) takes Wuber's ride; with paid, Wuber pays the whole fare by a completed trade
-- while in her group; with failed, the ride then ends before he arrives (Wuber cancels)
local function paidRide(opts)
	opts = opts or {}
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { netOnly = true })
	local r = T.rider(w, TESTCHAR, { money = 100000 })
	r.W.VERSION = "2.3.0"
	T.settle(w)
	T.goOnline(d)
	local ride = r.W.RequestRide("anita lift")
	w:advance(1)
	ok(d.W.AcceptRequest(ride.id, 5), "accepted")
	w:group({ ANITA, TESTCHAR })
	w:advance(1)
	eq(r.W.ride.state, "ingroup", "in the group")
	w:move(ANITA, "Orgrimmar") -- (a trade needs them side by side)
	w:advance(1)
	if opts.paid ~= false then
		ok(w:openTrade(w:player(ANITA), w:player(TESTCHAR)), "a trade opens")
		w:tradeMoney(w:player(TESTCHAR), opts.pay or ride.price)
		w:tradeAccept(w:player(ANITA))
		w:tradeAccept(w:player(TESTCHAR))
		w:advance(1)
	end
	if opts.failed ~= false then
		w:advance(5)
		ok(r.W.CancelRide(), "the ride ends before arrival")
		w:advance(1)
	end
	return w, d, r, ride
end

-- a stand-in for Drive.Raincheck's book: gives on ask, notes answers (the real book is F's)
local function fakeBook(d, cover)
	local book = { asks = {}, answers = {} }
	d.W.Listen("RAINCHECK", function(op, a, key, addr)
		if op == "ask" then
			book.asks[#book.asks + 1] = a .. ":" .. key
			d.W.Raincheck.Give(a, addr, "Rc000001", d.env.time() + 7 * 86400, cover or 5000, "Anita Lift")
		elseif op == "accept" or op == "decline" then
			book.answers[#book.answers + 1] = op .. ":" .. a .. ":" .. key
		end
	end)
	return book
end

test("net.raincheck: ask, give, accept: the words, the rider's copy, the driver hears the sender", function()
	local w, d, r, ride = paidRide()
	local book = fakeBook(d)
	eq(r.W.Raincheck.CanAsk(ride.id), true, "a paid ride that failed before arrival")
	eq(r.W.Raincheck.CanAsk(r.W.ride), true, "the ride table will do (C's Done)")
	eq(r.W.Raincheck.Ask(ride.id), true, "asked")
	w:advance(1)
	eq(vs(w, TESTCHAR)[1], "V~1~ask~" .. ride.id, "V ask")
	eq(book.asks[1], ride.id .. ":wuber testcharacter", "the driver hears it from the event's sender")
	eq(#vs(w, ANITA), 1, "V give")
	ok(#vs(w, ANITA)[1] <= 80, "give <= 80 bytes")
	local mine = r.W.Raincheck.Mine()
	eq(#mine, 1, "offered")
	eq(mine[1].state, "offered", "offered, not active")
	eq(mine[1].cover, 5000, "covers 50s")
	eq(mine[1].driverKey, "anita lift", "Anita's")
	eq(r.W.Raincheck.ForDriver("anita lift"), nil, "not usable before accepting")
	eq(r.W.Raincheck.Ask(ride.id), false, "a second ask: refused")
	local okA, why = r.W.Raincheck.CanAsk(ride.id)
	eq(why, "asked", "why")
	eq(r.W.Raincheck.Accept("Rc000001"), true, "accepted")
	w:advance(1)
	eq(vs(w, TESTCHAR)[2], "V~1~ok~Rc000001", "V ok")
	eq(book.answers[1], "accept:Rc000001:wuber testcharacter", "the driver hears accept from Wuber")
	eq(r.W.Raincheck.Mine()[1].state, "active", "active (the book decides)")
	local id, cover = r.W.Raincheck.ForDriver(d.W.drivers and r.W.drivers["anita lift"] or "anita lift")
	eq(id, "Rc000001", "usable with Anita")
	eq(cover, 5000, "cover")
	eq(r.W.Raincheck.ForDriver("anita lift", "Anita Lift"), "Rc000001", "key and service (C's Confirm)")
	eq(r.W.Raincheck.ForDriver("someone else", "anita lift"), "Rc000001", "the same crew under another driver")
	eq(r.W.Raincheck.ForDriver("someone else", "Other Crew"), nil, "another crew: none")
	eq(r.W.Raincheck.Accept("Rc000001"), false, "twice: no")
	for _, t in ipairs(vs(w, TESTCHAR)) do ok(#t <= 20, "rider V small: " .. t) end
	T.clean(w)
end)

test("net.raincheck: not eligible: unpaid, part paid, still open, arrived, over 30 min after paying", function()
	local w, d, r, ride = paidRide({ paid = false })
	local okA, why = r.W.Raincheck.CanAsk(ride.id)
	eq(okA, false, "unpaid") eq(why, "unpaid", "why")
	eq(r.W.Raincheck.Ask(ride.id), false, "no V")
	eq(#vs(w, TESTCHAR), 0, "nothing sent")
	T.clean(w)
	local w2, d2, r2, ride2 = paidRide({ pay = 2500 })
	okA, why = r2.W.Raincheck.CanAsk(ride2.id)
	eq(why, "unpaid", "part paid is not paid")
	T.clean(w2)
	local w3, d3, r3, ride3 = paidRide({ failed = false })
	okA, why = r3.W.Raincheck.CanAsk(ride3.id)
	eq(why, "open", "the ride is still going")
	T.clean(w3)
	local w4, d4, r4, ride4 = paidRide()
	local times = r4.W.Mod("Net.Rides").rideTimes[ride4.id]
	ok(times and times.paidAt and times.endedAt, "paid and ended times kept")
	times.paidAt = times.endedAt - 1801 -- (a clock held in combat or an instance)
	okA, why = r4.W.Raincheck.CanAsk(ride4.id)
	eq(why, "late", "ended over 30 min after paying")
	T.clean(w4)
	local w5, d5, r5, ride5 = paidRide({ failed = false })
	r5.W.ride.arrivedAt = r5.env.time()
	r5.W.ride.state = "cancelled"
	okA, why = r5.W.Raincheck.CanAsk(ride5.id)
	eq(why, "arrived", "an arrived rider never qualifies")
	eq(r5.W.Raincheck.CanAsk("ZZZZZZ"), false, "not our ride")
	T.clean(w5)
end)

test("net.raincheck: give is believed only from the ride's driver, for a paid ride, once per ride; void; decline", function()
	local w, d, r, ride = paidRide()
	local t = r.env.time()
	local function give(from, rid, id, exp, cover)
		w:inject(from, "V~1~give~" .. rid .. "~" .. id .. "~" .. exp .. "~" .. cover .. "~Anita Lift", "WHISPER", r)
	end
	give(BOB, ride.id, "Bob00001", t + 86400, 5000)
	eq(#r.W.Raincheck.Mine(), 0, "from a stranger: ignored")
	give(ANITA, "ZZZZZZ", "Ani00001", t + 86400, 5000)
	eq(#r.W.Raincheck.Mine(), 0, "for a ride that isn't ours: ignored")
	give(ANITA, ride.id, "Ani00002", t - 5, 5000)
	eq(#r.W.Raincheck.Mine(), 0, "already expired: ignored")
	give(ANITA, ride.id, "Ani00003", t + 30 * 86400, 5000)
	eq(#r.W.Raincheck.Mine(), 0, "longer than a week: ignored")
	give(ANITA, ride.id, "Ani00004", t + 86400, 0)
	eq(#r.W.Raincheck.Mine(), 0, "covers nothing: ignored")
	w:inject(ANITA, "V~1~give~" .. ride.id .. "~Ani00005~" .. (t + 86400) .. "~5000~Anita Lift", "CHANNEL")
	eq(#r.W.Raincheck.Mine(), 0, "over the channel: ignored")
	give(ANITA, ride.id, "Ani00006", t + 86400, 5000)
	eq(#r.W.Raincheck.Mine(), 0, "the 4th V from Anita about this ride: ignored (3 each way)")
	T.clean(w)
	local w2, d2, r2, ride2 = paidRide()
	local t2 = r2.env.time()
	w2:inject(ANITA, "V~1~give~" .. ride2.id .. "~Ani00001~" .. (t2 + 86400) .. "~5000~Anita Lift", "WHISPER", r2)
	eq(#r2.W.Raincheck.Mine(), 1, "the driver's give")
	w2:inject(ANITA, "V~1~give~" .. ride2.id .. "~Ani00009~" .. (t2 + 86400) .. "~9000~Anita Lift", "WHISPER", r2)
	eq(#r2.W.Raincheck.Mine(), 1, "one per ride")
	w2:inject(BOB, "V~1~void~Ani00001~nope", "WHISPER", r2)
	eq(r2.W.Raincheck.Mine()[1].state, "offered", "a stranger can't void it")
	eq(r2.W.Raincheck.Decline("Ani00001"), true, "no thanks")
	w2:advance(1)
	eq(vs(w2, TESTCHAR)[1], "V~1~no~Ani00001", "V no")
	eq(#r2.W.Raincheck.Mine(), 0, "gone")
	T.clean(w2)
	local w3, d3, r3, ride3 = paidRide()
	local t3 = r3.env.time()
	w3:inject(ANITA, "V~1~give~" .. ride3.id .. "~Ani00001~" .. (t3 + 86400) .. "~5000~Anita Lift", "WHISPER", r3)
	r3.W.Raincheck.Accept("Ani00001")
	w3:inject(ANITA, "V~1~void~Ani00001~expired", "WHISPER", r3)
	eq(r3.W.Raincheck.Mine()[1].state, "void", "the driver voids it")
	eq(r3.W.Raincheck.ForDriver("anita lift"), nil, "void: not usable")
	T.clean(w3)
end)

test("net.raincheck: limits: 3 active in all, 1 per crew; a week, then void", function()
	local w, d, r, ride = paidRide()
	local W, t = r.W, r.env.time()
	W.db.rainchecks = {
		Aaaaaaa1 = { driverKey = "x one", driver = "X One", service = "X", cover = 5000, expires = t + 86400, state = "active", rideId = "AAAAAA", at = t - 3 },
		Aaaaaaa2 = { driverKey = "x two", driver = "X Two", service = "Y", cover = 5000, expires = t + 86400, state = "active", rideId = "BBBBBB", at = t - 2 },
		Aaaaaaa3 = { driverKey = "x three", driver = "X Three", service = "Z", cover = 5000, expires = t + 86400, state = "active", rideId = "CCCCCC", at = t - 1 },
	}
	w:inject(ANITA, "V~1~give~" .. ride.id .. "~Ani00001~" .. (t + 86400) .. "~5000~Anita Lift", "WHISPER", r)
	eq(#W.Raincheck.Mine(), 4, "offered")
	eq(W.Raincheck.Accept("Ani00001"), false, "a 4th active: refused")
	W.db.rainchecks.Aaaaaaa3.expires = t - 1
	eq(W.Raincheck.ForDriver("x three"), nil, "past its week: void")
	eq(W.db.rainchecks.Aaaaaaa3.state, "void", "void")
	W.db.rainchecks.Aaaaaaa2.driverKey = "anita lift"
	eq(W.Raincheck.Accept("Ani00001"), false, "one active per crew already")
	W.db.rainchecks.Aaaaaaa2.driverKey = "x two"
	eq(W.Raincheck.Accept("Ani00001"), true, "now")
	eq(W.Raincheck.ForDriver({ key = "someone else", service = "y" }), "Aaaaaaa2", "the same crew under another driver (service)")
	T.clean(w)
end)

-- Wuber holds an active raincheck (cover) from Anita and books her again
local function rebook(cover, opts)
	opts = opts or {}
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { netOnly = true })
	local r = T.rider(w, TESTCHAR, { money = 100000 })
	r.W.VERSION = "2.3.0"
	T.settle(w)
	T.goOnline(d, { price = 7500 })
	w:advance(5)
	local t = r.env.time()
	r.W.db.rainchecks = { Ani00001 = { driverKey = "anita lift", driver = ANITA, service = "Anita Lift", cover = cover,
		expires = t + 86400, state = "active", rideId = "QQQQQQ", at = t } }
	if opts.off then r.W.Raincheck.Use(false) end
	if opts.notFor then r.W.Raincheck.Want(opts.notFor, false) end
	if opts.how then
		r.W.TravelSaved = function() return 600, "same continent", opts.how ~= "est" end
		r.W.FlightTime = function() return 480, opts.how end
	end
	local ride = r.W.RequestRide("anita lift")
	w:advance(1)
	return w, d, r, ride
end

test("net.raincheck: redeem: R field 7; the book takes it (A field 4 = 1): the fare less the cover is due; used on arrival", function()
	local w, d, r, ride = rebook(5000)
	local f = T.fields(T.msgs(w, "R", TESTCHAR)[1])
	eq(f[8], "2.3.0", "field 6") eq(f[9], "Ani00001", "field 7 = the raincheck")
	eq(d.W.incoming[1].voucher, "Ani00001", "the driver's request carries it (for the book)")
	local events = {}
	r.W.Listen("RAINCHECK", function(op, id) events[#events + 1] = op .. ":" .. tostring(id) end)
	ok(d.W.AcceptRequest(ride.id, 5, nil, 7500, true), "the book took it")
	w:advance(1)
	local a = T.fields(T.msgs(w, "A", ANITA)[1])
	eq(a[6], "1", "A's last field: taken")
	eq(r.W.ride.voucherTaken, true, "taken")
	eq(r.W.ride.fare, 7500, "the fare")
	eq(r.W.ride.price, 2500, "the cover comes off: 25s to pay")
	eq(r.W.ride.raincheck.id, "Ani00001", "W.ride.raincheck (UI.RaincheckCover): the id")
	eq(r.W.ride.raincheck.cover, 5000, "the cover")
	eq(r.W.ride.raincheck.taken, true, "taken")
	eq(r.W.db.ride.raincheck.taken, true, "kept over a /reload")
	eq(events[1], "taken:Ani00001", "RAINCHECK taken")
	-- the same A again (a resend) changes nothing
	w:inject(ANITA, "A~1~" .. ride.id .. "~7500~5~1", "WHISPER", r)
	eq(r.W.ride.price, 2500, "still 25s")
	T.clean(w)
	-- covers it all: nothing to pay; arriving makes the copy used
	local w2, d2, r2, ride2 = rebook(5000, { how = "own" })
	eq(r2.W.ride.savedHow, "own", "a measured flight: savedHow own")
	d2.W.AcceptRequest(ride2.id, 5, nil, 5000, true)
	w2:advance(1)
	eq(r2.W.ride.price, 0, "nothing to pay")
	w2:group({ ANITA, TESTCHAR })
	w2:advance(1)
	w2:summon(d2, TESTCHAR)
	w2:advance(1)
	eq(r2.W.ride.state, "portal", "the summon is up")
	w2.hardware = r2 r2.W.AcceptSummon() w2.hardware = nil -- (the rider's click)
	w2:advance(6)
	eq(r2.W.db.rainchecks.Ani00001.state, "used", "the rider's copy: used on arrival")
	eq(r2.W.ride.state, "done", "a free ride is done on arrival")
	local trips = r2.W.db.trips or {}
	local trip = r2.W.ride.trip or trips[#trips]
	eq(trip and trip.savedHow, "own", "the trip record keeps savedHow (Wrapped, the share line: no \"about\")")
	T.clean(w2)
end)

test("net.raincheck: not taken: A field 4 = 0, an old driver's A, or the toggle off -> the normal fare", function()
	local w, d, r, ride = rebook(5000)
	local events = {}
	r.W.Listen("RAINCHECK", function(op) events[#events + 1] = op end)
	d.W.AcceptRequest(ride.id, 5, nil, 7500, false)
	w:advance(1)
	eq(T.fields(T.msgs(w, "A", ANITA)[1])[6], "0", "A field 4: not taken")
	eq(r.W.ride.price, 7500, "normal fare")
	eq(r.W.ride.voucherRefused, true, "Confirm/Pay say so")
	eq(r.W.ride.raincheck.taken, false, "W.ride.raincheck.taken = false")
	eq(events[1], "refused", "RAINCHECK refused")
	T.clean(w)
	-- an old driver: A has no field 4
	local w2, d2, r2, ride2 = rebook(5000)
	w2:inject(ANITA, "A~1~" .. ride2.id .. "~7500~5", "WHISPER", r2)
	eq(r2.W.ride.price, 7500, "an old driver: normal fare")
	eq(r2.W.ride.voucherRefused, true, "not taken")
	T.clean(w2)
	-- the toggle off: R carries no raincheck
	local w3, d3, r3, ride3 = rebook(5000, { off = true })
	local f = T.fields(T.msgs(w3, "R", TESTCHAR)[1])
	eq(f[9], nil, "no field 7")
	eq(r3.W.ride.voucher, nil, "no raincheck on the ride")
	eq(d3.W.incoming[1].voucher, nil, "none at the driver")
	r3.W.Raincheck.Use(true)
	T.clean(w3)
	-- switched off for this driver only (C's Confirm: W.Raincheck.Want(driverKey, false))
	local w4, d4, r4 = rebook(5000, { notFor = "anita lift", how = "est" })
	eq(T.fields(T.msgs(w4, "R", TESTCHAR)[1])[9], nil, "Want(anita, false): no field 7")
	eq(r4.W.Raincheck.Using("anita lift"), false, "not for Anita")
	eq(r4.W.Raincheck.Using("bob stone"), true, "still for others")
	eq(r4.W.ride.raincheck, nil, "no W.ride.raincheck")
	eq(r4.W.ride.savedHow, "same continent", "an estimate keeps its kind (\"about\")")
	r4.W.Raincheck.Want("anita lift", true)
	eq(r4.W.Raincheck.Using("anita lift"), true, "back on")
	T.clean(w4)
end)

test("net.raincheck: abuse: forged ids, replays and floods reach only the book, under the real sender", function()
	local w, d, r, ride = paidRide()
	local book = fakeBook(d)
	-- Bob says ok to an id he was never given: the book hears Bob, not Wuber
	w:inject(BOB, "V~1~ok~Rc000001", "WHISPER", d)
	eq(book.answers[1], "accept:Rc000001:bob stone", "the sender is the event's sender")
	-- a flood about one id: 3 heard, the rest dropped
	for _ = 1, 6 do w:inject(BOB, "V~1~ok~Rc000002", "WHISPER", d) end
	eq(#book.answers, 4, "at most 3 per sender and id")
	-- garbage
	w:inject(BOB, "V~1~ok~short", "WHISPER", d)
	w:inject(BOB, "V~1~steal~Rc000003", "WHISPER", d)
	w:inject(BOB, "V~1~ask~notAnId", "WHISPER", d)
	eq(#book.answers, 4, "bad ids and ops ignored")
	eq(#book.asks, 0, "a bad ride id is no ask")
	-- the rider can't accept what was never offered, nor make one up
	eq(r.W.Raincheck.Accept("Rc000009"), false, "no such offer")
	r.W.db.rainchecks = { Fake0001 = { driverKey = "anita lift", cover = 999999, expires = r.env.time() + 86400, state = "active", at = 1 } }
	local id = r.W.Raincheck.ForDriver("anita lift")
	eq(id, "Fake0001", "a made-up copy is still sent as an id...")
	-- ...but the redeem is the driver's book's decision (A field 4); a netOnly driver without a book never takes it
	T.clean(w)
end)

test("net.raincheck: W.SendIOU: the crew fact through Drive.Team's outbox, <= 90 bytes; bad facts refused", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA)
	local DR = d.W.Drive
	local got = {}
	local orig = DR.Send
	DR.Send = function(kind, ...) got[#got + 1] = table.concat({ kind, ... }, "~") return true end
	eq(d.W.SendIOU("i", "Rc000001", "Wuber TestCharacter", 5000, 1800000000, "AbCdEf"), true, "issued (a 10-digit time)")
	eq(got[1], "IOU~i~Rc000001~wuber testcharacter~5000~1800000000~AbCdEf", "fields")
	eq(d.W.SendIOU("u", "Rc000001", string.rep("Bartholomew ", 6), 99999999, 1800000000, "AbCdEf"), true, "a long key is cut")
	ok(#("IOU~1~" .. got[2]:sub(5)) <= 90, "<= 90 bytes: " .. got[2])
	eq(d.W.SendIOU("x", "Rc000001", "Wuber TestCharacter", 5000, 1, "AbCdEf"), false, "unknown op")
	eq(d.W.SendIOU("a", "bad", "Wuber TestCharacter", 5000, 1, "AbCdEf"), false, "bad id")
	eq(d.W.SendIOU("a", "Rc000001", nil, 5000, 1, "AbCdEf"), false, "no rider")
	eq(#got, 2, "only the good ones")
	DR.Send = orig
	T.clean(w)
end)

test("net.raincheck: worst-case sizes: R with fields 6 and 7, A with field 4, V give and void stay small (<= 250)", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { netOnly = true })
	local r = T.rider(w, TESTCHAR, { money = 100000 })
	r.W.VERSION = "2.3.0"
	local W, env = d.W, d.env
	W.SetLocalDriver(function()
		if W.Char().drive ~= true then return nil end
		local m = env.C_Map.GetBestMapForUnit("player")
		local pos = m and env.C_Map.GetPlayerMapPosition(m, "player")
		return { dest = string.rep("Q", 40), mapID = m, x = pos and pos.x, y = pos and pos.y, price = 99999999,
			service = string.rep("S", 40), state = "open", team = 1, seats = 4 }
	end)
	T.settle(w)
	T.goOnline(d)
	w:advance(5)
	local t = r.env.time()
	r.W.db.rainchecks = { Ani00001 = { driverKey = "anita lift", driver = ANITA, service = string.rep("S", 40), cover = 99999999,
		expires = t + 86400, state = "active", rideId = "QQQQQQ", at = t } }
	local ride = r.W.RequestRide("anita lift")
	ok(ride, "booked")
	w:advance(1)
	local R = T.msgs(w, "R", TESTCHAR)[1]
	ok(R and #R.text <= 250, "R <= 250 bytes: " .. tostring(R and #R.text))
	eq(T.fields(R)[9], "Ani00001", "with field 7")
	d.W.AcceptRequest(ride.id, 3600, nil, 99999999, true)
	w:advance(1)
	local A = T.msgs(w, "A", ANITA)[1]
	ok(A and #A.text <= 250, "A <= 250 bytes")
	eq(T.fields(A)[6], "1", "with field 4")
	ok(d.W.Raincheck.Give(ride.id, TESTCHAR, "Rc000001", t + 7 * 86400, 99999999, string.rep("S", 40)), "give")
	ok(d.W.Raincheck.Void("Rc000001", TESTCHAR, string.rep("x", 40)), "void")
	w:advance(1)
	local v = vs(w, ANITA)
	eq(#v, 2, "give and void")
	ok(#v[1] <= 80, "V give <= 80 bytes: " .. #v[1])
	ok(#v[2] <= 30, "V void <= 30 bytes: " .. #v[2])
	T.clean(w)
end)

test("net.raincheck: a /reload (or lag-drop) keeps the raincheck path: paid and ended times are saved with the ride", function()
	-- reload after paying, then the ride fails: may ask; the driver's offer comes through
	local w, d, r, ride = paidRide({ failed = false })
	ok(r.W.ride.paidAt and r.W.db.ride.paidAt, "paidAt on the ride, saved")
	local r2 = w:reload(r)
	r2.W.VERSION = "2.3.0"
	w:advance(3)
	ok(r2.W.ride and r2.W.ride.paid, "the paid ride came back")
	ok(r2.W.CancelRide(), "then it fails")
	w:advance(1)
	ok(r2.W.db.ride.endedAt, "endedAt saved")
	eq(r2.W.Raincheck.CanAsk(r2.W.ride), true, "may still ask after the reload")
	eq(r2.W.Raincheck.Ask(ride.id), true, "asks")
	local t = r2.env.time()
	w:inject(ANITA, "V~1~give~" .. ride.id .. "~Ani00001~" .. (t + 86400) .. "~5000~Anita Lift", "WHISPER", r2)
	eq(#r2.W.Raincheck.Mine(), 1, "the offer comes through")
	T.clean(w)
	-- reload after it failed (the Sorry screen): the ended paid ride comes back for 30 minutes
	local w3, d3, r3, ride3 = paidRide()
	local r4 = w3:reload(r3)
	r4.W.VERSION = "2.3.0"
	w3:advance(3)
	ok(r4.W.ride and r4.W.ride.id == ride3.id, "the failed paid ride came back")
	eq(r4.W.RideActive(), false, "ended")
	eq(r4.W.Raincheck.CanAsk(ride3.id), true, "may ask")
	local t3 = r4.env.time()
	w3:inject(ANITA, "V~1~give~" .. ride3.id .. "~Ani00002~" .. (t3 + 86400) .. "~5000~Anita Lift", "WHISPER", r4)
	eq(#r4.W.Raincheck.Mine(), 1, "the offer comes through")
	w3:inject(BOB, "V~1~give~" .. ride3.id .. "~Bob00002~" .. (t3 + 86400) .. "~5000~Bob", "WHISPER", r4)
	eq(#r4.W.Raincheck.Mine(), 1, "never from someone else")
	T.clean(w3)
end)

test("net.raincheck: an offer not accepted within 30 minutes lapses in the rider's copy too; a failed paid ride is restored for 30 min of paying", function()
	local w, d, r, ride = paidRide()
	local t = r.env.time()
	w:inject(ANITA, "V~1~give~" .. ride.id .. "~Ani00001~" .. (t + 86400) .. "~5000~Anita Lift", "WHISPER", r)
	eq(r.W.Raincheck.Mine()[1].state, "offered", "offered")
	r.W.db.rainchecks.Ani00001.at = t - 1801 -- (offline when it lapsed)
	eq(r.W.Raincheck.Accept("Ani00001"), false, "a lapsed offer can't be accepted")
	eq(r.W.Raincheck.Mine()[1].state, "void", "void, as in the book")
	eq(r.W.Raincheck.ForDriver("anita lift"), nil, "nothing to use")
	T.clean(w)
	-- a lag-drop of 15 minutes after the failure: the ride is still there to ask about
	local w2, d2, r2, ride2 = paidRide()
	local saved = w2:logout(r2)
	w2:advance(900)
	local r3 = w2:addClient(TESTCHAR, { spot = "Orgrimmar", class = "MAGE", money = 100000, saved = saved })
	r3.W.VERSION = "2.3.0"
	w2:advance(3)
	eq(r3.W.ride and r3.W.ride.id, ride2.id, "restored after 15 min")
	eq(r3.W.Raincheck.CanAsk(ride2.id), true, "may ask")
	T.clean(w2)
	-- past 30 minutes of paying: gone
	local w4, d4, r4, ride4 = paidRide()
	local saved4 = w4:logout(r4)
	w4:advance(1900)
	local r5 = w4:addClient(TESTCHAR, { spot = "Orgrimmar", class = "MAGE", money = 100000, saved = saved4 })
	w4:advance(3)
	eq(r5.W.ride, nil, "not restored after 30 min")
	T.clean(w4)
end)

-- (round 9, C12) the driver's "void ... used" (the book used it on arrival) marks the rider's copy
-- used, never void, even when it reaches the rider before their own arrival does
test("net.raincheck: V void with reason used marks the rider's copy used, not void (round 9 C12)", function()
	local w, d, r, ride = paidRide()
	local t = r.env.time()
	local seen
	r.W.Listen("RAINCHECK", function(what, id) seen = what end)
	w:inject(ANITA, "V~1~give~" .. ride.id .. "~Ani00001~" .. (t + 86400) .. "~5000~Anita Lift", "WHISPER", r)
	eq(r.W.Raincheck.Accept("Ani00001"), true, "accepted")
	w:advance(1)
	eq(r.W.Raincheck.Mine()[1].state, "active", "active")
	w:inject(ANITA, "V~1~void~Ani00001~used", "WHISPER", r)
	eq(r.W.Raincheck.Mine()[1].state, "used", "used, not void")
	eq(seen, "used", "RAINCHECK used fired")
	T.clean(w)
end)
