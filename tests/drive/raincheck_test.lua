-- Tests of Drive.Raincheck. Loaded by tests/run.lua with its helper table T.
-- The rider's side (kind V, R field 7, A's last field) is Net.Raincheck's (owner E): here the
-- engine is driven the way that wire hands it over (ride.voucher into onRequest, V into
-- DR.RaincheckHeard) and W.SendIOU / W.AcceptRequest are spies.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local ANA, BEA, CAL, TESTCHAR = "Ana Smith", "Bea Jones", "Cal Brown", "Wuber TestCharacter"
local SPOT = "Undercity"
local FARE = 5000

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function crewSaved(me, names, captain)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end
	end
	return { chars = { [key(me)] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true } } }
end

-- Three Warlocks of one crew (Ana leads, the window on the network), open; Wuber (the app) asks
-- for a ride and joins. ride.voucher of the next request = scene.voucher (R field 7).
local function scene()
	local w = H.NewWorld({})
	local names = { ANA, BEA, CAL }
	local cs = {}
	for i, name in ipairs(names) do
		cs[i] = w:addClient(name, { spot = SPOT, class = "WARLOCK", saved = { Wuber = crewSaved(name, names, ANA) } })
	end
	local r = w:addClient(TESTCHAR, { spot = "Orgrimmar", class = "MAGE", money = 1000000 })
	w:group(names)
	w:advance(15)
	local s = { w = w, ana = cs[1], bea = cs[2], cal = cs[3], r = r, ivs = {}, accepts = {} }
	local DR = s.ana.W.Drive
	s.DR = DR
	-- V to the rider (Net.Raincheck's Give / Void): recorded, then sent as usual
	for _, c in ipairs(cs) do
		local list = {}
		s.ivs[c] = list
		local RC = c.W.Raincheck
		local give, void = RC.Give, RC.Void
		RC.Give = function(...) list[#list + 1] = { "give", ... } return give(...) end
		RC.Void = function(...) list[#list + 1] = { "void", ... } return void(...) end
	end
	local accept = s.ana.W.AcceptRequest
	s.ana.W.AcceptRequest = function(...)
		s.accepts[#s.accepts + 1] = { ... }
		return accept(...)
	end
	local engine = DR.ENGINE
	local onRequest = engine.onRequest
	engine.onRequest = function(x)
		x.riderVer, x.voucher = "2.3.0", s.voucher
		return onRequest(x)
	end
	DR.SetOpen(true)
	w:advance(8)
	return s
end

local function book(c) return c.W.db.drive.iou or {} end

-- Wuber books Ana (and joins the group)
local function book_ride(s)
	ok(s.r.W.RequestRide(key(ANA)), "requested")
	s.w:advance(9)
	local c = s.DR.customers[key(TESTCHAR)]
	ok(c and c.wuberRide, "Ana took the Wuber ride")
	return c
end

-- the fare paid by trade (Drive.Trade's fact: "PAID name copper"), a cast that fails, then the
-- ride ends (the driver closes)
local function paidThenFailed(s, copper, how)
	local c = book_ride(s)
	s.DR.Do("PAID", TESTCHAR, copper or FARE, how)
	s.w:advance(1)
	s.DR.Do("CAST", TESTCHAR)
	s.w:advance(1)
	s.DR.Do("END", TESTCHAR, 0)
	s.w:advance(1)
	return c, c.wuberRide
end

local function closeShop(s)
	s.DR.SetOpen(false)
	s.w:advance(2)
end

local function give(s, ride)
	local okG, id = s.DR.GiveRaincheck(ride)
	ok(okG, "given: " .. tostring(id))
	s.w:advance(1)
	return id
end

test("drive.raincheck: contract (registered, deps, header, public names); idle: nothing saved", function()
	local W, w, r, Mod = T.contract("Drive.Raincheck", "tests/drive/raincheck_test.lua", {
		["DR.RaincheckEligible"] = "function", ["DR.GiveRaincheck"] = "function", ["DR.Rainchecks"] = "function",
		["DR.RaincheckHeard"] = "function", ["DR.RaincheckFact"] = "function", ["DR.RaincheckRedeem"] = "function",
		["DR.RaincheckSync"] = "function", ["DR.RaincheckTick"] = "function", ["DR.RaincheckCounts"] = "function",
		["DR.RideIdOf"] = "function", ["DR.recentPaid"] = "table",
	})
	ok(Mod, "W.Mod(\"Drive.Raincheck\")")
	eq(W.Drive.RaincheckEligible("abcdef"), false, "no ride is eligible")
	eq(#W.Drive.Rainchecks(), 0, "the book is empty")
	eq(W.db.drive.iou, nil, "no book saved until one is given")
	eq(W.db.drive.iouDay, nil)
	T.clean(w)
end)

test("drive.raincheck: happy path: paid by trade, cast fails, ask, give, accept, rebook free, arrive -> used; crew agrees", function()
	local s = scene()
	local w, DR = s.w, s.DR
	local c, ride = paidThenFailed(s)
	eq(DR.RaincheckEligible(ride), false, "still listed and open")
	eq(select(2, DR.RaincheckEligible(ride)), "open")
	closeShop(s)
	eq(DR.RaincheckEligible(ride), true, "ended within 30 minutes of a full payment by trade")
	-- the rider asks (V ask): the driver is alerted once
	local alerts = 0
	for _, f in ipairs(s.ana.fired) do if f.name == "DRIVE_ALERT" and f.args[2] == "raincheck" then alerts = alerts + 1 end end
	-- (Net.Raincheck hands V ask over as RAINCHECK("ask", rideId, senderKey, addr))
	s.ana.W.Fire("RAINCHECK", "ask", ride, key(TESTCHAR), TESTCHAR)
	local after = 0
	for _, f in ipairs(s.ana.fired) do if f.name == "DRIVE_ALERT" and f.args[2] == "raincheck" then after = after + 1 end end
	eq(after, alerts + 1, "one raincheck alert")
	local data
	for _, f in ipairs(s.ana.fired) do if f.name == "DRIVE_ALERT" and f.args[2] == "raincheck" then data = f.args[3] end end
	ok(type(data) == "table", "the alert says which ride (3rd argument)")
	eq(data and data.rideId, ride, "data.rideId") eq(data and data.name, TESTCHAR, "data.name")
	eq(DR.RaincheckHeard("ask", key(TESTCHAR), TESTCHAR, ride), false, "a second ask for the same ride is refused")
	eq(DR.RaincheckHeard("ask", "dan miller", "Dan Miller", ride), false, "somebody else can't ask for Wuber's ride")
	-- the driver gives it: V give to the rider, IOU i to the crew
	local id = give(s, ride)
	eq(#id, 8, "an 8-character id")
	local g = s.ivs[s.ana][1]
	eq(g[1], "give") eq(g[2], ride) eq(g[3], TESTCHAR) eq(g[4], id) eq(g[6], FARE, "covers the fare paid")
	ok(g[5] > s.ana.env.time() + 6 * 86400, "expires in 7 days")
	local iou
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBERT" and e.from == ANA and e.text:match("^IOU~1~i~") then iou = e.text end
	end
	ok(iou and #iou <= 90 and iou:find(id, 1, true), "IOU i to the crew: " .. tostring(iou))
	for _, cw in ipairs({ s.ana, s.bea, s.cal }) do eq(book(cw)[id] and book(cw)[id].state, "offered", cw.player.name .. ": offered") end
	eq(select(2, DR.GiveRaincheck(ride)), "given", "one per ride id")
	-- not active before the rider accepts: a request with it pays the normal fare
	DR.SetOpen(true)
	w:advance(3)
	eq(DR.RaincheckRedeem(id, key(TESTCHAR), FARE, c), false, "offered is not active")
	-- the rider accepts (V ok): active everywhere
	eq(DR.RaincheckHeard("ok", "dan miller", "Dan Miller", id), false, "only its rider can accept")
	s.ana.W.Fire("RAINCHECK", "accept", id, key(TESTCHAR), TESTCHAR)
	w:advance(1)
	for _, cw in ipairs({ s.ana, s.bea, s.cal }) do eq(book(cw)[id].state, "active", cw.player.name .. ": active") end
	-- rebook with it (R field 7): taken, nothing to pay
	s.r.W.ride = nil
	DR.Remove(DR.customers[key(TESTCHAR)], "drop")
	w:advance(1)
	s.voucher = id
	local c2 = book_ride(s)
	local a = s.accepts[#s.accepts]
	eq(a[5], true, "A's last field: taken")
	eq(a[4], FARE, "A names the full fare (the rider subtracts the cover)")
	eq(c2.voucher, id) eq(c2.price, 0, "nothing due")
	eq(book(s.ana)[id].state, "active", "still active until arrival")
	eq(s.bea.W.Drive.customers[key(TESTCHAR)].price, 0, "the crew windows bill nothing (ST flag v)")
	-- it fails again before arrival (the ride is dropped): still active, and it works next time
	DR.Do("CAST", TESTCHAR)
	w:advance(1)
	DR.Do("END", TESTCHAR, 0)
	w:advance(1)
	DR.Remove(DR.customers[key(TESTCHAR)], "drop")
	w:advance(1)
	eq(book(s.ana)[id].state, "active", "a failed ride before arrival leaves it active")
	eq(book(s.ana)[id].onRide, nil)
	s.r.W.ride = nil
	c2 = book_ride(s)
	eq(s.accepts[#s.accepts][5], true, "taken again")
	eq(c2.price, 0)
	-- arrival: used, everywhere; the ride counts as paid without a trade
	w:move(TESTCHAR, SPOT)
	w:advance(3)
	for _, cw in ipairs({ s.ana, s.bea, s.cal }) do eq(book(cw)[id].state, "used", cw.player.name .. ": used") end
	local v = s.ivs[s.ana][#s.ivs[s.ana]]
	eq(v[1], "void") eq(v[2], id) eq(v[4], "used")
	eq(DR.customers[key(TESTCHAR)].state, "paid", "nothing to pay: paid")
	-- replay after used: normal fare
	eq(DR.RaincheckRedeem(id, key(TESTCHAR), FARE, DR.customers[key(TESTCHAR)]), false, "a used raincheck is refused")
	local given, used = DR.RaincheckCounts(0)
	eq(given, 1) eq(used, 1)
	T.clean(s.w)
end)

test("drive.raincheck: booking again while the failed ride's row is still listed: a fresh row, free, used on arrival", function()
	local s = scene()
	local w, DR = s.w, s.DR
	local c, ride = paidThenFailed(s)
	closeShop(s)
	local id = give(s, ride)
	DR.RaincheckHeard("ok", key(TESTCHAR), TESTCHAR, id)
	w:advance(1)
	DR.SetOpen(true)
	w:advance(2)
	ok(DR.customers[key(TESTCHAR)] == c, "the old row is still listed")
	s.r.W.ride = nil
	s.voucher = id
	local c2 = book_ride(s)
	ok(c2 ~= c, "a fresh row for the new ride")
	ok(c2.wuberRide ~= ride, "the new ride id")
	eq(c2.voucher, id) eq(c2.price, 0, "nothing due")
	ok(c2.state ~= "paid" and c2.state ~= "done", "not paid at once: " .. tostring(c2.state))
	local cb = s.bea.W.Drive.customers[key(TESTCHAR)]
	eq(cb and s.bea.W.Drive.RideIdOf(cb), c2.wuberRide, "Bea's row follows the new ride")
	eq(cb and cb.price, 0, "and bills nothing")
	w:move(TESTCHAR, SPOT)
	w:advance(3)
	for _, cw in ipairs({ s.ana, s.bea, s.cal }) do eq(book(cw)[id].state, "used", cw.player.name .. ": used on arrival") end
	T.clean(s.w)
end)

test("drive.raincheck: a redeemed one is used when its rider arrives on any row within 30 minutes of the redeem", function()
	local s = scene()
	local w, DR = s.w, s.DR
	local _, ride = paidThenFailed(s)
	closeShop(s)
	local id = give(s, ride)
	DR.RaincheckHeard("ok", key(TESTCHAR), TESTCHAR, id)
	w:advance(1)
	DR.SetOpen(true)
	w:advance(2)
	s.r.W.ride = nil
	s.voucher = id
	local c2 = book_ride(s)
	eq(c2.voucher, id, "redeemed on the new row")
	eq(book(s.ana)[id].onRide, c2.wuberRide)
	-- rows that don't carry it (e.g. one that replaced the redeemed row) arriving
	local other = { key = "dan miller", name = "Dan Miller", state = "arrived" }
	s.ana.W.Fire("DRIVE_STATE", other)
	eq(book(s.ana)[id].state, "active", "another rider's arrival: nothing")
	local row = { key = key(TESTCHAR), name = TESTCHAR, state = "arrived", wuberRide = "Zzzzzz" }
	local at = book(s.ana)[id].redeemAt
	book(s.ana)[id].redeemAt = at - DR.RAINCHECK.WINDOW - 1
	s.ana.W.Fire("DRIVE_STATE", row)
	eq(book(s.ana)[id].state, "active", "redeemed over 30 minutes ago: not this arrival")
	book(s.ana)[id].redeemAt = at
	s.ana.W.Fire("DRIVE_STATE", row)
	eq(book(s.ana)[id].state, "used", "its rider arrived on another row: used")
	eq(c2.voucher, id, "(the redeemed row is left as it is)")
	T.clean(s.w)
end)

test("drive.raincheck: a request with a new ride id never replaces a row whose summon is under way", function()
	local s = scene()
	local w, DR = s.w, s.DR
	local c = book_ride(s)
	local ride = c.wuberRide
	DR.Do("CAST", TESTCHAR)
	w:advance(1)
	DR.Do("END", TESTCHAR, 1)
	w:advance(1)
	eq(c.state, "waiting", "the summon went out")
	local d = s.r.W.drivers[key(ANA)]
	w:inject(TESTCHAR, table.concat({ "R", "1", "Glnzzz", d.dest, tostring(d.price), "0", "0", "2.3.0", "" }, "~"), "WHISPER", s.ana)
	w:advance(2)
	ok(DR.customers[key(TESTCHAR)] == c, "the same row")
	eq(DR.RideIdOf(c), ride, "its ride kept")
	local busy = false
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBER" and e.from == ANA and e.text == "N~1~Glnzzz~busy" then busy = true end
	end
	ok(busy, "the new request is answered N busy (the rider's app says try again)")
	-- paid by trade while the summon box is up, then the rider leaves the group: the summon went out
	DR.Do("PAID", TESTCHAR, FARE)
	w:advance(1)
	w:leave(TESTCHAR)
	w:advance(3)
	local okE, why = DR.RaincheckEligible(ride)
	eq(okE, false) eq(why, "summoned", "paid after the summon went out, then left: no raincheck")
	T.clean(s.w)
end)

test("drive.raincheck: not eligible: paid by hand, part payment, unpaid, arrived, over 30 minutes", function()
	local s = scene()
	local DR = s.DR
	-- by hand ("Mark as paid")
	local _, ride = paidThenFailed(s, 0, "m")
	closeShop(s)
	local okE, why = DR.RaincheckEligible(ride)
	eq(okE, false) eq(why, "hand", "Mark as paid never qualifies")
	eq(DR.GiveRaincheck(ride), false, "and can't be given")
	T.clean(s.w)

	s = scene()
	DR = s.DR
	_, ride = paidThenFailed(s, 3000)
	closeShop(s)
	okE, why = DR.RaincheckEligible(ride)
	eq(okE, false) eq(why, "part", "a part payment never qualifies")
	T.clean(s.w)

	s = scene()
	DR = s.DR
	local c = book_ride(s)
	ride = c.wuberRide
	closeShop(s)
	okE, why = DR.RaincheckEligible(ride)
	eq(okE, false) eq(why, "unpaid", "unpaid")
	T.clean(s.w)

	s = scene()
	DR = s.DR
	c = book_ride(s)
	ride = c.wuberRide
	c.tries = 1 -- (d4 g) summoned once: a rider who walks up with no summon now leaves the list
	s.w:move(TESTCHAR, SPOT) -- the rider walks in: arrived (the here check)
	s.w:advance(3)
	eq(c.state, "arrived")
	DR.Do("PAID", TESTCHAR, FARE)
	s.w:advance(1)
	closeShop(s)
	okE, why = DR.RaincheckEligible(ride)
	eq(okE, false) eq(why, "arrived", "an arrived rider never qualifies")
	T.clean(s.w)

	s = scene()
	DR = s.DR
	c, ride = paidThenFailed(s)
	DR.recentPaid[#DR.recentPaid].paidAt = DR.recentPaid[#DR.recentPaid].paidAt - 31 * 60
	closeShop(s)
	okE, why = DR.RaincheckEligible(ride)
	eq(okE, false) eq(why, "late", "ended more than 30 minutes after payment")
	eq(DR.RaincheckEligible("nosuch"), false, "a ride id we never had")
	T.clean(s.w)
end)

test("drive.raincheck: limits: one live per rider per crew; 3 a day; expiry voids; a declined one is void", function()
	local s = scene()
	local w, DR = s.w, s.DR
	local _, ride = paidThenFailed(s)
	closeShop(s)
	-- three given today already (crew facts)
	local t = s.ana.env.time()
	-- (a real i fact carries its issue time + 7 days: issued today, so counted)
	for i = 1, 3 do s.bea.W.Drive.Do("IOU", "i", "Cap0000" .. i, "rider " .. i, 5000, t + 7 * 86400, "") end
	w:advance(1)
	eq(s.ana.W.db.drive.iouDay.n, 3, "the day's count learned from the crew")
	local okE, why = DR.RaincheckEligible(ride)
	eq(okE, false) eq(why, "cap", "the 4th of the day is refused")
	-- (every crew window counted the three; a window past the cap refuses another i fact)
	for _, cw in ipairs({ s.ana, s.bea, s.cal }) do cw.W.db.drive.iouDay.n = 0 end
	-- Wuber holds a live one already
	-- (an id never heard of is taken only from an i fact: issued, then accepted)
	s.bea.W.Drive.Do("IOU", "i", "Held0001", key(TESTCHAR), 5000, t + 86400, "")
	s.bea.W.Drive.Do("IOU", "a", "Held0001", key(TESTCHAR), 5000, t + 86400, "")
	w:advance(1)
	okE, why = DR.RaincheckEligible(ride)
	eq(okE, false) eq(why, "held", "one live raincheck per rider per crew")
	-- that one expires: void, and Wuber may get one again
	book(s.ana).Held0001.expires = t - 1
	DR.RaincheckTick()
	eq(book(s.ana).Held0001.state, "void", "expired: void")
	eq(book(s.ana).Held0001.why, "expired")
	eq(DR.RaincheckEligible(ride), true)
	local id = give(s, ride)
	eq(DR.RaincheckHeard("no", key(TESTCHAR), TESTCHAR, id), true, "No thanks")
	w:advance(1)
	for _, cw in ipairs({ s.ana, s.bea, s.cal }) do eq(book(cw)[id].state, "void", cw.player.name .. ": declined is void") end
	eq(DR.RaincheckHeard("ok", key(TESTCHAR), TESTCHAR, id), false, "a void one can't be accepted later")
	T.clean(s.w)
end)

test("drive.raincheck: an arrival on that ride voids a raincheck given for it; a rider who paid before joining hasn't left", function()
	local s = scene()
	local w, DR = s.w, s.DR
	local c, ride = paidThenFailed(s)
	closeShop(s)
	local id = give(s, ride)
	eq(DR.RaincheckHeard("ok", key(TESTCHAR), TESTCHAR, id), true, "accepted")
	w:advance(1)
	eq(book(s.ana)[id].state, "active")
	-- Ana opens again and summons Wuber after all, on the same ride: he arrives
	DR.SetOpen(true)
	w:advance(2)
	w:move(TESTCHAR, SPOT)
	w:advance(3)
	ok(DR.recentPaid[#DR.recentPaid].arrived, "the here check saw him")
	for _, cw in ipairs({ s.ana, s.bea, s.cal }) do eq(book(cw)[id].state, "void", cw.player.name .. ": void") end
	eq(book(s.ana)[id].why, "arrived")
	local v = s.ivs[s.ana][#s.ivs[s.ana]]
	eq(v[1], "void") eq(v[2], id) eq(v[4], "arrived", "the rider is told")
	eq(DR.RaincheckRedeem(id, key(TESTCHAR), FARE, { key = key(TESTCHAR), name = TESTCHAR }), false, "normal fare")
	eq(select(2, DR.RaincheckEligible(ride)), "arrived")
	T.clean(s.w)

	-- an offered one goes the same way (and can't be accepted afterwards)
	s = scene()
	w, DR = s.w, s.DR
	c, ride = paidThenFailed(s)
	closeShop(s)
	id = give(s, ride)
	DR.SetOpen(true)
	w:advance(2)
	w:move(TESTCHAR, SPOT)
	w:advance(3)
	eq(book(s.ana)[id].state, "void", "offered, then he arrived: void")
	eq(DR.RaincheckHeard("ok", key(TESTCHAR), TESTCHAR, id), false, "too late to accept")
	T.clean(s.w)

	-- paid by trade before joining the group (no unit yet): the ride goes on, it hasn't ended
	s = scene()
	DR = s.DR
	c = book_ride(s)
	DR.Do("PAID", TESTCHAR, FARE)
	s.w:advance(1)
	local unit = DR.units[key(TESTCHAR)]
	DR.units[key(TESTCHAR)], c.joinedAt = nil, nil
	DR.RaincheckTick()
	eq(select(2, DR.RaincheckEligible(c.wuberRide)), "open", "not in the group yet: still open")
	c.joinedAt = 1
	DR.RaincheckTick()
	eq(DR.RaincheckEligible(c.wuberRide), true, "once he had joined, leaving the group ends it")
	DR.units[key(TESTCHAR)] = unit
	T.clean(s.w)
end)

test("drive.raincheck: can't be gamed: forged, someone else's, replayed, expired or not-accepted ids pay the normal fare", function()
	local s = scene()
	local w, DR = s.w, s.DR
	local _, ride = paidThenFailed(s)
	closeShop(s)
	DR.RaincheckHeard("ask", key(TESTCHAR), TESTCHAR, ride)
	local id = give(s, ride)
	DR.RaincheckHeard("ok", key(TESTCHAR), TESTCHAR, id)
	w:advance(1)
	local fake = { key = "dan miller", name = "Dan Miller", price = FARE }
	eq(DR.RaincheckRedeem("Zz9Zz9Zz", key(TESTCHAR), FARE, fake), false, "a made-up id")
	eq(DR.RaincheckRedeem(id, "dan miller", FARE, fake), false, "Wuber's id from Dan (the event's sender decides)")
	eq(fake.price, FARE, "Dan's fare untouched")
	eq(DR.RaincheckRedeem("bad id!", key(TESTCHAR), FARE, fake), false, "junk")
	-- a forged IOU fact can't move another rider's raincheck, nor be "used" unseen
	s.bea.W.Drive.Do("IOU", "a", id, "dan miller", 99999, s.ana.env.time() + 86400, "")
	s.bea.W.Drive.Do("IOU", "u", "Never000", key(TESTCHAR), 5000, s.ana.env.time() + 86400, "")
	w:advance(1)
	eq(book(s.ana)[id].rider, key(TESTCHAR), "same id, other rider: ignored")
	eq(book(s.ana)[id].cover, FARE)
	eq(book(s.ana).Never000, nil, "used of an id never heard of: nothing")
	-- a stranger in the group (no crew) can't send IOU at all
	w:addBot("Zed Stranger", { spot = SPOT })
	w:group({ ANA, BEA, CAL, TESTCHAR, "Zed Stranger" })
	w:advance(2)
	local zt = string.format("%d", s.ana.env.time() + 86400)
	w:inject("Zed Stranger", "IOU~1~a~Zed00001~zed stranger~5000~" .. zt .. "~", "PARTY", s.ana, "WUBERT")
	w:inject("Zed Stranger", "IOU~1~v~" .. id .. "~" .. key(TESTCHAR) .. "~5000~" .. zt .. "~", "PARTY", s.ana, "WUBERT")
	w:inject(BEA, "IOU~1~i~Bea00001~zed stranger~5000~" .. zt .. "~", "PARTY", s.ana, "WUBERT")
	eq(book(s.ana).Bea00001 ~= nil, true, "(the same fact from the crew is taken)")
	eq(book(s.ana).Zed00001, nil, "a stranger's IOU: ignored")
	eq(book(s.ana)[id].state, "active", "a stranger can't void Wuber's")
	-- the rider's own copy grants nothing: only the book's state counts
	book(s.ana)[id].state = "offered"
	eq(DR.RaincheckRedeem(id, key(TESTCHAR), FARE, { key = key(TESTCHAR), name = TESTCHAR }), false, "not accepted: normal fare")
	book(s.ana)[id].state = "active"
	-- another crew's raincheck (the book says who gave it)
	book(s.ana)[id].crew = "someone else"
	eq(DR.RaincheckRedeem(id, key(TESTCHAR), FARE, { key = key(TESTCHAR), name = TESTCHAR }), false, "another crew's")
	book(s.ana)[id].crew = key(ANA)
	-- expired
	local exp = book(s.ana)[id].expires
	book(s.ana)[id].expires = s.ana.env.time() - 1
	eq(DR.RaincheckRedeem(id, key(TESTCHAR), FARE, { key = key(TESTCHAR), name = TESTCHAR }), false, "expired")
	book(s.ana)[id].expires = exp
	-- cover under the new fare: the rider pays the difference
	local x = { key = key(TESTCHAR), name = TESTCHAR }
	eq(DR.RaincheckRedeem(id, key(TESTCHAR), 8000, x), true)
	eq(x.price, 3000, "8000 - 5000")
	T.clean(s.w)
end)

test("drive.raincheck: can't be gamed: an expired offer can't be accepted; a replayed IOU can't revive a used one; a far expiry is refused", function()
	local s = scene()
	local w, DR = s.w, s.DR
	local _, ride = paidThenFailed(s, FARE + 1000) -- the fare and a 10s tip
	closeShop(s)
	local id = give(s, ride)
	eq(book(s.ana)[id].cover, FARE, "it covers the fare, never the tip")
	local exp = book(s.ana)[id].expires
	book(s.ana)[id].expires = s.ana.env.time() - 1 -- (before the once-a-second tick voids it)
	eq(DR.RaincheckHeard("ok", key(TESTCHAR), TESTCHAR, id), false, "an expired offer: refused")
	eq(book(s.ana)[id].state, "offered")
	book(s.ana)[id].expires = exp
	eq(DR.RaincheckHeard("ok", key(TESTCHAR), TESTCHAR, id), true)
	w:advance(1)
	-- used, then a crew window replays the old "active"
	DR.RaincheckFact(key(ANA), true, "u", id, key(TESTCHAR), FARE, exp, ride)
	s.bea.W.Drive.Do("IOU", "a", id, key(TESTCHAR), FARE, exp, ride)
	w:advance(1)
	eq(book(s.ana)[id].state, "used", "used stays used")
	eq(DR.RaincheckRedeem(id, key(TESTCHAR), FARE, { key = key(TESTCHAR), name = TESTCHAR }), false, "and pays nothing off")
	-- an IOU fact that lasts a year
	local t = s.ana.env.time()
	s.bea.W.Drive.Do("IOU", "i", "Year0001", "rider x", 5000, t + 365 * 86400, "")
	w:advance(1)
	eq(book(s.ana).Year0001, nil, "an expiry past 8 days is refused")
	s.bea.W.Drive.Do("IOU", "i", "Week0001", "rider x", 5000, t + 6 * 86400, "")
	s.bea.W.Drive.Do("IOU", "a", "Week0001", "rider x", 5000, t + 6 * 86400, "")
	w:advance(1)
	eq(book(s.ana).Week0001 and book(s.ana).Week0001.state, "active", "(a normal one is taken)")
	-- an a (or u, v) fact for an id never issued mints nothing (review: it would skip the cap)
	s.bea.W.Drive.Do("IOU", "a", "Mint0001", "rider x", 99999999, t + 6 * 86400, "")
	w:advance(1)
	eq(book(s.ana).Mint0001, nil, "an a fact for an id never issued: nothing")
	-- a raincheck paid for this ride: the ride itself can't earn another one
	T.clean(s.w)
end)

test("drive.raincheck: can't be gamed: nobody else asks for Wuber's ride; accept twice; a crew fact naming another rider; a ride a raincheck paid for", function()
	local s = scene()
	local w, DR = s.w, s.DR
	local _, ride = paidThenFailed(s)
	closeShop(s)
	local function alerts()
		local n = 0
		for _, f in ipairs(s.ana.fired) do if f.name == "DRIVE_ALERT" and f.args[2] == "raincheck" then n = n + 1 end end
		return n
	end
	local before = alerts()
	eq(DR.RaincheckHeard("ask", "dan miller", "Dan Miller", ride), false, "Dan can't ask for Wuber's ride")
	eq(alerts(), before, "no alert for Dan's ask")
	eq(DR.RaincheckHeard("ask", key(TESTCHAR), TESTCHAR, ride), true, "Wuber still can")
	eq(alerts(), before + 1)
	local id = give(s, ride)
	eq(DR.RaincheckHeard("ok", key(TESTCHAR), TESTCHAR, id), true)
	w:advance(1)
	eq(DR.RaincheckHeard("ok", key(TESTCHAR), TESTCHAR, id), false, "accepting twice does nothing")
	-- a crew fact that names another rider can't void Wuber's
	s.bea.W.Drive.Do("IOU", "v", id, "dan miller", FARE, book(s.ana)[id].expires, "")
	w:advance(1)
	eq(book(s.ana)[id].state, "active", "Wuber's stays active")
	-- the ride Wuber's raincheck pays for: he pays the fare by trade anyway and it fails too: no second raincheck
	DR.SetOpen(true)
	DR.Remove(DR.customers[key(TESTCHAR)], "drop")
	s.r.W.ride = nil
	w:advance(1)
	s.voucher = id
	local c2, ride2 = paidThenFailed(s)
	eq(c2.voucher, id, "redeemed")
	closeShop(s)
	local okE, why = DR.RaincheckEligible(ride2)
	eq(okE, false) eq(why, "free", "a ride a raincheck paid for earns none")
	T.clean(s.w)
end)

test("drive.raincheck: an ask before the ride ends waits for it; an offer not accepted lapses in 30 minutes (no 7-day hold)", function()
	local s = scene()
	local w, DR = s.w, s.DR
	local _, ride = paidThenFailed(s)
	local alerts = 0
	s.ana.W.Listen("DRIVE_ALERT", function(_, kind) if kind == "raincheck" then alerts = alerts + 1 end end)
	-- the rider's ask crosses the end of the ride: not lost, the driver is alerted once it is eligible
	eq(select(2, DR.RaincheckEligible(ride)), "open", "the ride is still open")
	eq(DR.RaincheckHeard("ask", key(TESTCHAR), TESTCHAR, ride), false, "asked while open: waits")
	eq(alerts, 0, "no alert yet")
	closeShop(s)
	w:advance(2)
	eq(alerts, 1, "alerted once the ride ended")
	eq(DR.RaincheckHeard("ask", key(TESTCHAR), TESTCHAR, ride), false, "the ride's one ask is used now")
	eq(alerts, 1, "no second alert")
	-- offered, never accepted: void after 30 minutes, the rider told
	local id = give(s, ride)
	eq(book(s.ana)[id].state, "offered", "offered")
	book(s.ana)[id].issued = book(s.ana)[id].issued - DR.RAINCHECK.OFFER + 5
	DR.RaincheckTick()
	eq(book(s.ana)[id].state, "offered", "not yet")
	book(s.ana)[id].issued = book(s.ana)[id].issued - 5
	DR.RaincheckTick()
	eq(book(s.ana)[id].state, "void", "lapsed: void")
	eq(book(s.ana)[id].why, "lapsed")
	w:advance(1)
	local told = false
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBER" and e.from == ANA and e.text:find("~void~" .. id .. "~lapsed", 1, true) then told = true end
	end
	ok(told, "the rider was told (V void lapsed)")
	eq(DR.RaincheckHeard("ok", key(TESTCHAR), TESTCHAR, id), false, "a lapsed offer can't be accepted")
	eq(book(s.ana)[id].state, "void", "still void")
	T.clean(s.w)
end)

test("drive.raincheck: a window that joins hears the live book (at most 20); a restored queue keeps the paid rides", function()
	local s = scene()
	local w, DR = s.w, s.DR
	local t = s.ana.env.time()
	for i = 1, 25 do
		DR.RaincheckFact(key(ANA), true, "i", ("Sync%04d"):format(i), "rider " .. i, 5000, t + 86400, "")
		DR.RaincheckFact(key(ANA), true, "a", ("Sync%04d"):format(i), "rider " .. i, 5000, t + 86400, "")
	end
	-- used ones go first (they beat a stale active in that window); one used 9 days ago stays out
	for _, id in ipairs({ "Used0001", "Old00001" }) do
		DR.RaincheckFact(key(ANA), true, "i", id, "rider x", 5000, t + 86400, "")
		DR.RaincheckFact(key(ANA), true, "u", id, "rider x", 5000, t + 86400, "")
	end
	book(s.ana).Old00001.at = t - 9 * 86400
	local before = #w.addonLog
	DR.RaincheckSync()
	local _, nBulk = DR.CommBacklog()
	ok(nBulk > 0, "on the low-priority bulk lane: " .. tostring(nBulk))
	w:advance(45) -- the bulk lane: one a second, i + a for each
	local n, used, old = 0, 0, 0
	for i = before + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.prefix == "WUBERT" and e.from == ANA and e.text:match("^IOU~1~a~Sync") then
			n = n + 1
			ok(#e.text <= 90, "IOU <= 90 bytes")
		end
		if e.prefix == "WUBERT" and e.from == ANA and e.text:match("^IOU~1~u~Used0001") then used = used + 1 end
		if e.prefix == "WUBERT" and e.from == ANA and e.text:match("^IOU~1~u~Old00001") then old = old + 1 end
	end
	eq(used, 1, "the recent used one")
	eq(old, 0, "not one used 9 days ago")
	eq(n, 19, "19 active entries (20 in all)")
	eq(book(s.bea).Sync0001 ~= nil or book(s.bea).Sync0025 ~= nil, true, "Bea's book has them")
	-- the queue snapshot carries DR.recentPaid
	local _, ride = paidThenFailed(s)
	DR.Snapshot()
	local q = s.ana.W.Char().queue
	ok(q and q.paid and q.paid[#q.paid].ride == ride, "saved with the queue snapshot")
	for i = #DR.recentPaid, 1, -1 do DR.recentPaid[i] = nil end
	DR.RestoreQueue()
	ok(DR.recentPaid[1] and DR.recentPaid[1].ride == ride, "back after a /reload")
	T.clean(s.w)
end)

-- (round 9, C6) a /reload after the rider redeemed: the queue snapshot keeps the raincheck on the
-- row (voucher, cover, full fare), so arrival still marks the ride paid (nothing to pay)
test("drive.raincheck: a /reload mid-ride keeps the redeemed raincheck on the row; arrival still pays (round 9 C6)", function()
	local s = scene()
	local w, DR = s.w, s.DR
	local _, ride = paidThenFailed(s)
	closeShop(s)
	local id = give(s, ride)
	DR.RaincheckHeard("ok", key(TESTCHAR), TESTCHAR, id)
	w:advance(1)
	DR.SetOpen(true)
	w:advance(2)
	s.r.W.ride = nil
	s.voucher = id
	local c2 = book_ride(s)
	eq(c2.voucher, id, "redeemed") eq(c2.price, 0, "nothing due")
	local full = c2.fullFare
	ok(full and full > 0, "the full fare is on the row: " .. tostring(full))
	DR.Snapshot()
	local q = s.ana.W.Char().queue
	local saved
	for _, e in ipairs(q and q.list or {}) do if e.key == key(TESTCHAR) then saved = e end end
	ok(saved, "Wuber's row is in the snapshot")
	eq(saved and saved.voucher, id, "the snapshot keeps the voucher")
	eq(saved and saved.fullFare, full, "and the full fare")
	-- the /reload: the row loses what only lived in memory; the snapshot gives it back
	c2.voucher, c2.cover, c2.fullFare = nil, nil, nil
	DR.RestoreQueue()
	eq(c2.voucher, id, "back after a /reload")
	eq(c2.fullFare, full, "the full fare too")
	w:move(TESTCHAR, SPOT)
	w:advance(3)
	eq(book(s.ana)[id].state, "used", "used on arrival")
	ok(DR.Rank(c2.state) >= DR.Rank("paid"), "nothing to pay: paid, not stuck at arrived (" .. tostring(c2.state) .. ")")
	T.clean(s.w)
end)

-- (round 9, C12) Earnings' "given" counts only rainchecks the rider took: a declined or lapsed offer
-- is not given, in the giver's window or a crew window (whose book never hears why it went void)
test("drive.raincheck: an offer still waiting when its expiry passes lapses (not 'expired'): not given; Earnings asks DR (round 9 review)", function()
	local s = scene()
	local w, DR = s.w, s.DR
	local _, ride = paidThenFailed(s)
	closeShop(s)
	local id = give(s, ride)
	w:advance(2)
	for _, cw in ipairs({ s.ana, s.bea }) do
		local v = book(cw)[id]
		eq(v.state, "offered", cw.player.name .. ": offered, no answer yet")
		v.expires = cw.env.time() - 1 -- its expiry passes while the offer still waits
	end
	w:advance(2)
	for _, cw in ipairs({ s.ana, s.bea }) do
		local v = book(cw)[id]
		eq(v.state, "void", cw.player.name .. ": void")
		eq(v.why, "lapsed", cw.player.name .. ": an offer never taken lapses")
		eq((cw.W.Drive.RaincheckCounts(0)), 0, cw.player.name .. ": not given")
		eq((cw.W.Driver.RaincheckCounts()), 0, cw.player.name .. ": Earnings agrees")
	end
	-- Earnings has no rule of its own: it asks DR.RaincheckGiven
	local a = s.ana
	local was = a.W.Drive.RaincheckGiven
	ok(type(was) == "function", "DR.RaincheckGiven")
	a.W.Drive.RaincheckGiven = function() return true end
	eq((a.W.Driver.RaincheckCounts()), 1, "Earnings counts what DR.RaincheckGiven says")
	a.W.Drive.RaincheckGiven = was
	T.clean(s.w)
end)

test("drive.raincheck: given counts only taken ones: declined or lapsed offers are not given, in any window (round 9 C12)", function()
	local s = scene()
	local w, DR = s.w, s.DR
	local _, ride = paidThenFailed(s)
	closeShop(s)
	local id = give(s, ride)
	DR.RaincheckHeard("no", key(TESTCHAR), TESTCHAR, id)
	w:advance(2)
	for _, cw in ipairs({ s.ana, s.bea, s.cal }) do
		eq(book(cw)[id].state, "void", cw.player.name .. ": declined is void")
		eq((cw.W.Drive.RaincheckCounts(0)), 0, cw.player.name .. ": a declined one is not given")
		eq((cw.W.Driver.RaincheckCounts()), 0, cw.player.name .. ": Earnings agrees")
	end
	T.clean(s.w)
	-- an offer nobody answers lapses after 30 minutes: not given either
	s = scene()
	w, DR = s.w, s.DR
	_, ride = paidThenFailed(s)
	closeShop(s)
	id = give(s, ride)
	w:advance(31 * 60)
	for _, cw in ipairs({ s.ana, s.bea }) do
		eq(book(cw)[id].state, "void", cw.player.name .. ": lapsed")
		eq((cw.W.Drive.RaincheckCounts(0)), 0, cw.player.name .. ": a lapsed one is not given")
		eq((cw.W.Driver.RaincheckCounts()), 0, cw.player.name .. ": Earnings agrees")
	end
	T.clean(s.w)
	-- taken, then it runs out unused: still given
	s = scene()
	w, DR = s.w, s.DR
	_, ride = paidThenFailed(s)
	closeShop(s)
	id = give(s, ride)
	DR.RaincheckHeard("ok", key(TESTCHAR), TESTCHAR, id)
	w:advance(2)
	for _, cw in ipairs({ s.ana, s.bea }) do
		local v = book(cw)[id]
		eq(v.state, "active", cw.player.name .. ": active")
		v.expires = cw.env.time() - 1
	end
	w:advance(2)
	for _, cw in ipairs({ s.ana, s.bea }) do
		eq(book(cw)[id].state, "void", cw.player.name .. ": expired")
		eq((cw.W.Drive.RaincheckCounts(0)), 1, cw.player.name .. ": taken, then expired: given")
		eq((cw.W.Driver.RaincheckCounts()), 1, cw.player.name .. ": Earnings agrees")
	end
	T.clean(s.w)
end)


-- a rider who arrives first, pays by trade and leaves the group before the next
-- 1-second tick (auto-leave does) arrived: the ride never qualifies, in any crew window.
test("drive.raincheck: arrived, paid, then left at once (auto-leave): never eligible (BRIEF17 C3)", function()
	local s = scene()
	local DR = s.DR
	local c = book_ride(s)
	local ride = c.wuberRide
	c.tries = 1 -- (d4 g) summoned once: a rider who walks up with no summon now leaves the list
	s.w:move(TESTCHAR, SPOT)
	s.w:advance(3)
	eq(c.state, "arrived")
	DR.Do("PAID", TESTCHAR, FARE)
	s.w:leave(TESTCHAR) -- before the next tick
	s.w:advance(3)
	closeShop(s)
	for _, cw in ipairs({ s.ana, s.bea }) do
		local okE, why = cw.W.Drive.RaincheckEligible(ride)
		eq(okE, false, cw.player.name .. ": not eligible")
		if cw == s.ana then eq(why, "arrived", "the rider arrived") end
	end
	eq(DR.GiveRaincheck(ride), false, "and can't be given")
	T.clean(s.w)
end)

-- a repeat rider (a done row asked again) starts a fresh ride: nothing of the last
-- ride's 2.1-2.3 state is left on the row, and the second paid ride counts in the lifetime stats.
test("drive.queue: a repeat rider's row starts clean; the second paid ride counts too (BRIEF17 C6)", function()
	local s = scene()
	local DR = s.DR
	s.r.W.db.autoLeave = false -- Wuber stays in the group after the ride
	local c = book_ride(s)
	c.tries = 1 -- (d4 g) summoned once: a rider who walks up with no summon now leaves the list
	s.w:move(TESTCHAR, SPOT)
	s.w:advance(3)
	eq(c.state, "arrived")
	local st = s.ana.W.db.drive.stats
	local before = st and st.rides or 0
	DR.Do("PAID", TESTCHAR, FARE)
	s.w:advance(1)
	eq(c.state, "paid")
	st = s.ana.W.db.drive.stats
	eq(st.rides, before + 1, "ride 1 counted")
	DR.Do("THX", TESTCHAR)
	s.w:advance(1)
	eq(c.state, "done")
	-- what ride 1 left on the row (a raincheck ride, several stations, the tracker, ...)
	local stale = { voucher = "ABCDEFGH", cover = 9000, fullFare = 10000, prepaid = true, rideId = "QWERTY",
		wuberVer = "2.3.0", wuberLabel = "Ride 1", askWhere = true, whereTold = true,
		elsewhere = true, elsewhereTold = true, payeeBlind = true, priceTold = true, dest = "Ironforge",
		doneAt = 1, helps = { x = true }, called = true }
	for k, v in pairs(stale) do c[k] = v end
	local again = DR.Request(TESTCHAR, "whisper", "summon please")
	ok(again == c, "the same row, asked again")
	for k in pairs(stale) do
		if k ~= "payeeBlind" then eq(c[k], nil, "cleared: " .. k) end
	end
	eq(c.wuberRide, nil, "no Wuber ride on a whispered ride")
	eq(c.wuberBuyer, nil, "no Wuber buyer")
	eq(c.wuberPrice, nil, "no Wuber price")
	ok(c.payeeBlind ~= true or DR.PayeeBlind(c), "payeeBlind worked out again for this ride")
	s.w:advance(3)
	eq(c.state, "arrived", "still standing here: arrived")
	DR.Do("PAID", TESTCHAR, c.price)
	s.w:advance(1)
	eq(c.state, "paid")
	eq(s.ana.W.db.drive.stats.rides, before + 2, "ride 2 counted in the lifetime stats too")
	T.clean(s.w)
end)
