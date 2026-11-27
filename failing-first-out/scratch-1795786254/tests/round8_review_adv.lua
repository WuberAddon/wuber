-- Independent review (round 8): adversarial raincheck scenarios over the real wire and F's real book.
-- Scratch file in a throwaway worktree; never committed. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local ANA, BEA, CAL, TESTCHAR, BOB = T.ANA, T.BEA, T.CAL, T.TESTCHAR, T.BOB
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

local function payByTrade(w, amount)
	local gp, ap = w:player(TESTCHAR), w:player(ANA)
	local zone = gp.zone
	gp.zone = ap.zone
	ok(w:openTrade(ap, gp), "a trade opens")
	gp.zone = zone
	w:tradeMoney(gp, amount)
	w:tradeAccept(ap)
	w:tradeAccept(gp)
	w:advance(1)
end

local function book(opts)
	opts = opts or {}
	local w, ana, bea, cal, r = crewScene()
	local s = { w = w, ana = ana, bea = bea, cal = cal, r = r, DR = ana.W.Drive }
	s.ride = r.W.RequestRide(key(ANA))
	ok(s.ride, "Wuber books Ana")
	w:advance(9)
	s.c = s.DR.customers[key(TESTCHAR)]
	ok(s.c and s.c.wuberRide == s.ride.id, "Ana's engine took the ride")
	if opts.pay ~= false then
		payByTrade(w, s.ride.price)
		ok(r.W.ride.paid, "the rider's record: paid")
	end
	return s
end

local function fail(s)
	local cr = s.r.W.CancelRide()
	if not cr then print("   (CancelRide false; state " .. tostring(s.r.W.ride and s.r.W.ride.state) .. ")") end
	s.w:leave(TESTCHAR)
	s.w:advance(3)
end

local function failedPaid()
	local s = book()
	fail(s)
	return s
end

local function giveAccept(s)
	ok(s.r.W.Raincheck.Ask(s.ride.id), "Wuber asks")
	s.w:advance(2)
	local okG, id = s.DR.GiveRaincheck(s.ride.id)
	ok(okG, "Ana gives: " .. tostring(id))
	s.w:advance(2)
	ok(s.r.W.Raincheck.Accept(id), "Wuber accepts")
	s.w:advance(2)
	eq(iou(s.ana)[id] and iou(s.ana)[id].state, "active", "active in Ana's book")
	return id
end

-- the last A sent for a ride id (fields)
local function lastA(w, rid)
	local found
	for _, e in ipairs(w.addonLog) do
		if e.text:sub(1, 4 + #rid) == "A~1~" .. rid then found = e end
	end
	return found and T.fields(found)
end

local function rebook(s)
	s.r.W.ClearRide()
	s.w:advance(65)
	local ride2, why = s.r.W.RequestRide(key(ANA))
	ok(ride2, "booked again: " .. tostring(why))
	s.w:advance(9)
	return ride2
end

test("r8 review adv 01: forged sender: Bob's V ask / ok / give about Wuber's ride change nothing and don't use up Wuber's ask", function()
	local s = failedPaid()
	local alerts = 0
	s.ana.W.Listen("DRIVE_ALERT", function(_, kind) if kind == "raincheck" then alerts = alerts + 1 end end)
	s.w:inject(BOB, "V~1~ask~" .. s.ride.id, "WHISPER", s.ana)
	s.w:advance(1)
	eq(alerts, 0, "Bob's ask: no alert")
	ok(s.r.W.Raincheck.Ask(s.ride.id), "Wuber asks")
	s.w:advance(2)
	eq(alerts, 1, "Wuber's own ask still alerts")
	local okG, id = s.DR.GiveRaincheck(s.ride.id)
	ok(okG, "given")
	s.w:advance(2)
	s.w:inject(BOB, "V~1~ok~" .. id, "WHISPER", s.ana)
	s.w:advance(1)
	eq(iou(s.ana)[id].state, "offered", "Bob's ok: still offered")
	s.w:inject(BOB, "V~1~give~" .. s.ride.id .. "~Fake0001~" .. string.format("%d", s.r.env.time() + 86400) .. "~99999~Bob", "WHISPER", s.r)
	s.w:advance(1)
	eq(s.r.W.db.rainchecks.Fake0001, nil, "a give from Bob (not Wuber's driver) is ignored")
	T.clean(s.w)
end)

test("r8 review adv 02: other rider's id: Bob's R naming Wuber's active raincheck pays the normal fare (A field 4 = 0)", function()
	local s = failedPaid()
	local id = giveAccept(s)
	local d = s.r.W.drivers[key(ANA)]
	ok(d, "Ana's beacon")
	s.w:inject(BOB, table.concat({ "R", "1", "Bobxyz", d.dest, tostring(d.price), "0", "0", "2.3.0", id }, "~"), "WHISPER", s.ana)
	s.w:advance(3)
	local a = lastA(s.w, "Bobxyz")
	ok(a, "Ana answered Bob")
	eq(a and a[6], "0", "not taken for Bob")
	local cb = s.DR.customers[key(BOB)]
	eq(cb and cb.voucher, nil, "no voucher on Bob's row")
	eq(iou(s.ana)[id].state, "active", "Wuber's raincheck untouched")
	eq(iou(s.ana)[id].onRide, nil, "not attached to Bob's ride")
	T.clean(s.w)
end)

test("r8 review adv 03: replay after use: Wuber's own copy forged back to active; the book says used: normal fare", function()
	local s = failedPaid()
	local id = giveAccept(s)
	local ride2 = rebook(s)
	eq(ride2.voucher, id, "R names it")
	eq(s.r.W.ride.voucherTaken, true, "taken")
	s.w:move(TESTCHAR, SPOT)
	s.w:advance(4)
	eq(iou(s.ana)[id].state, "used", "used on arrival")
	-- Wuber goes home, forges his copy back to active and books again
	s.w:leave(TESTCHAR)
	s.w:move(TESTCHAR, "Orgrimmar")
	s.w:advance(3)
	s.r.W.db.rainchecks[id].state = "active"
	local ride3 = rebook(s)
	eq(ride3.voucher, id, "the forged copy is named in R")
	eq(s.r.W.ride.voucherTaken, nil, "not taken")
	eq(s.r.W.ride.voucherRefused, true, "the rider is told: normal fare")
	ok((s.r.W.ride.price or 0) > 0, "a fare is due")
	local c = s.DR.customers[key(TESTCHAR)]
	eq(c and c.voucher, nil, "no voucher on the row")
	T.clean(s.w)
end)

test("r8 review adv 04: expired in the book (the rider's copy still says active): voided by the tick, normal fare", function()
	local s = failedPaid()
	local id = giveAccept(s)
	iou(s.ana)[id].expires = s.ana.env.time() - 1
	s.w:advance(2)
	eq(iou(s.ana)[id].state, "void", "the tick voids it")
	local ride2 = rebook(s)
	eq(ride2.voucher, id, "the rider still names it")
	eq(s.r.W.ride.voucherRefused, true, "refused")
	T.clean(s.w)
end)

test("r8 review adv 05: caps: three IOU i facts from a crew mate fill today's cap in Ana's window: Wuber's ride gets none", function()
	local s = failedPaid()
	-- (F: a real i fact carries its issue time + 7 days; only one issued today counts toward today's cap)
	local t = s.bea.env.time() + 7 * 86400
	for i = 1, 3 do s.bea.W.Drive.Do("IOU", "i", "Capx000" .. i, "rider " .. i, 100, t, "") end
	s.w:advance(2)
	eq(s.ana.W.db.drive.iouDay and s.ana.W.db.drive.iouDay.n, 3, "Ana's day count heard the crew's three")
	local okE, why = s.DR.RaincheckEligible(s.ride.id)
	eq(okE, false, "not eligible")
	eq(why, "cap", "cap")
	eq(s.DR.GiveRaincheck(s.ride.id), false, "Give refused")
	T.clean(s.w)
end)

test("r8 review adv 06: double redeem: a second R with a new ride id and the same raincheck while the first is open; then a third after use", function()
	local s = failedPaid()
	local id = giveAccept(s)
	local ride2 = rebook(s)
	eq(s.r.W.ride.voucherTaken, true, "first redeem taken")
	local d = s.r.W.drivers[key(ANA)]
	s.w:inject(TESTCHAR, table.concat({ "R", "1", "Glnzzz", d.dest, tostring(d.price), "0", "0", "2.3.0", id }, "~"), "WHISPER", s.ana)
	s.w:advance(3)
	local n = 0
	for _, c in pairs(s.DR.customers) do if c.voucher == id then n = n + 1 end end
	ok(n <= 1, "at most one row holds the raincheck (" .. n .. ")")
	local nc = s.DR.customers[key(TESTCHAR)]
	print("   after 2nd R: row ride " .. tostring(nc and s.DR.RideIdOf(nc)) .. " state " .. tostring(nc and nc.state) .. " voucher " .. tostring(nc and nc.voucher) .. " onRide " .. tostring(iou(s.ana)[id].onRide) .. " price " .. tostring(nc and nc.price) .. " rider ride " .. tostring(s.r.W.ride.id) .. " " .. tostring(s.r.W.ride.state))
	s.w:move(TESTCHAR, SPOT)
	s.w:advance(4)
	nc = s.DR.customers[key(TESTCHAR)]
	print("   after move: row ride " .. tostring(nc and s.DR.RideIdOf(nc)) .. " state " .. tostring(nc and nc.state) .. " voucher " .. tostring(nc and nc.voucher) .. " onRide " .. tostring(iou(s.ana)[id].onRide) .. " rider " .. tostring(s.r.W.ride.state))
	s.w:advance(30)
	nc = s.DR.customers[key(TESTCHAR)]
	print("   +30s: row state " .. tostring(nc and nc.state) .. " book " .. tostring(iou(s.ana)[id].state))
	eq(iou(s.ana)[id].state, "used", "used on arrival")
	s.w:inject(TESTCHAR, table.concat({ "R", "1", "Glnyyy", d.dest, tostring(d.price), "0", "0", "2.3.0", id }, "~"), "WHISPER", s.ana)
	s.w:advance(3)
	local a = lastA(s.w, "Glnyyy")
	if a then eq(a[6], "0", "a third R after use: not taken") end
	eq(iou(s.ana)[id].state, "used", "still used")
	T.clean(s.w, { violations = true })
end)

test("r8 review adv 07: give without payment: unpaid, a rider's forged PAID fact, Mark as paid by hand", function()
	local s = book({ pay = false })
	-- Wuber (in the group, not crew) forges the crew's PAID fact over WUBERT
	s.w:inject(TESTCHAR, "PAID~1~" .. TESTCHAR .. "~" .. tostring(s.ride.price) .. "~t", "PARTY", s.ana, "WUBERT")
	s.w:advance(1)
	fail(s)
	local okE, why = s.DR.RaincheckEligible(s.ride.id)
	eq(okE, false, "not eligible")
	eq(why, "unpaid", "unpaid (the forged fact was not believed)")
	eq(s.DR.GiveRaincheck(s.ride.id), false, "Give refused")
	-- by hand
	local s2 = book({ pay = false })
	s2.DR.Do("PAID", TESTCHAR, s2.ride.price, "m")
	s2.w:advance(1)
	fail(s2)
	local ok2, why2 = s2.DR.RaincheckEligible(s2.ride.id)
	eq(ok2, false, "by hand: not eligible")
	eq(why2, "hand", "hand")
	T.clean(s.w)
	T.clean(s2.w)
end)

test("r8 review adv 08: accept after void: declined (void) then a V ok; and an expired offer accepted", function()
	local s = failedPaid()
	ok(s.r.W.Raincheck.Ask(s.ride.id), "asks")
	s.w:advance(2)
	local _, id = s.DR.GiveRaincheck(s.ride.id)
	s.w:advance(2)
	ok(s.r.W.Raincheck.Decline(id), "Wuber declines")
	s.w:advance(2)
	eq(iou(s.ana)[id].state, "void", "void")
	s.w:inject(TESTCHAR, "V~1~ok~" .. id, "WHISPER", s.ana)
	s.w:advance(1)
	eq(iou(s.ana)[id].state, "void", "a late ok: still void")
	eq(s.DR.RaincheckRedeem(id, key(TESTCHAR), 5000, { key = key(TESTCHAR), name = TESTCHAR }), false, "no redeem")
	T.clean(s.w)
end)

test("r8 review adv 09: ask after arrival: paid, arrived, then left: the book refuses, no alert", function()
	local s = book()
	s.w:move(TESTCHAR, SPOT)
	s.w:advance(4)
	s.w:leave(TESTCHAR)
	s.w:advance(3)
	local alerts = 0
	s.ana.W.Listen("DRIVE_ALERT", function(_, kind) if kind == "raincheck" then alerts = alerts + 1 end end)
	s.w:inject(TESTCHAR, "V~1~ask~" .. s.ride.id, "WHISPER", s.ana)
	s.w:advance(1)
	eq(alerts, 0, "no alert")
	local okE, why = s.DR.RaincheckEligible(s.ride.id)
	eq(okE, false, "not eligible (" .. tostring(why) .. ")")
	eq(s.DR.GiveRaincheck(s.ride.id), false, "Give refused")
	T.clean(s.w)
end)

test("r8 review adv 10 (design gap?): summon went out (END ok), the rider left the group, then stood at the spot: eligible?", function()
	local s = book()
	s.DR.Do("CAST", TESTCHAR)
	s.w:advance(1)
	s.DR.Do("END", TESTCHAR, 1)
	s.w:advance(1)
	s.w:leave(TESTCHAR)
	s.w:move(TESTCHAR, SPOT)
	s.w:advance(3)
	local okE, why = s.DR.RaincheckEligible(s.ride.id)
	eq(okE, false, "a ride whose summon went out and whose rider then left should not read as failed (" .. tostring(why) .. ")")
	T.clean(s.w)
end)

test("r8 review adv 11 (crew trust): a crew mate's IOU a fact for an id never issued mints an active raincheck", function()
	local s = failedPaid()
	local t = s.cal.env.time() + 6 * 86400
	s.cal.W.Drive.Do("IOU", "a", "Mint0001", key(TESTCHAR), 99999999, t, "")
	s.w:advance(2)
	local v = iou(s.ana).Mint0001
	eq(v, nil, "an active raincheck nobody issued should not appear in Ana's book (state " .. tostring(v and v.state) .. ", cover " .. tostring(v and v.cover) .. ")")
	T.clean(s.w)
end)

test("r8 review adv 12: crew window disagreement: Bea away while Wuber accepts and while it is used; she rejoins", function()
	local s = failedPaid()
	ok(s.r.W.Raincheck.Ask(s.ride.id), "asks")
	s.w:advance(2)
	local _, id = s.DR.GiveRaincheck(s.ride.id)
	s.w:advance(2)
	eq(iou(s.bea)[id] and iou(s.bea)[id].state, "offered", "Bea: offered")
	s.w:leave(BEA)
	s.w:advance(3)
	ok(s.r.W.Raincheck.Accept(id), "accepts")
	s.w:advance(2)
	eq(iou(s.ana)[id].state, "active", "Ana: active")
	s.w:group({ ANA, BEA, CAL })
	s.w:advance(15)
	eq(iou(s.bea)[id] and iou(s.bea)[id].state, "active", "Bea after rejoining: active (join sync)")
	-- used while Bea is away again
	s.w:leave(BEA)
	s.w:advance(3)
	rebook(s)
	eq(s.r.W.ride.voucherTaken, true, "taken")
	s.w:move(TESTCHAR, SPOT)
	s.w:advance(4)
	eq(iou(s.ana)[id].state, "used", "Ana: used")
	s.w:group({ ANA, BEA, CAL, TESTCHAR })
	s.w:advance(15)
	eq(iou(s.bea)[id] and iou(s.bea)[id].state, "used", "Bea after rejoining: should know it was used")
	eq(s.bea.W.Drive.RaincheckRedeem(id, key(TESTCHAR), 5000, { key = key(TESTCHAR), name = TESTCHAR }), false, "Bea's book must not redeem it again")
	T.clean(s.w, { violations = true })
end)

test("r8 review adv 13 (lag-drop): the rider reloads after paying; the ride then fails: may Wuber still ask and receive the offer?", function()
	local s = book()
	local r2 = s.w:reload(s.r)
	r2.W.VERSION = "2.3.0"
	s.w:advance(3)
	ok(r2.W.ride and r2.W.ride.paid, "the paid ride came back after the reload")
	s.r = r2
	fail(s)
	local can, why = r2.W.Raincheck.CanAsk(r2.W.ride)
	print("   after reload: CanAsk " .. tostring(can) .. " " .. tostring(why) .. ", ride state " .. tostring(r2.W.ride.state))
	local okE, whyE = s.DR.RaincheckEligible(s.ride.id)
	ok(okE, "the book: eligible (" .. tostring(whyE) .. ")")
	local okG, id = s.DR.GiveRaincheck(s.ride.id)
	ok(okG, "Ana gives from the row")
	s.w:advance(2)
	local mine = r2.W.Raincheck.Mine()[1]
	print("   offer received: " .. tostring(mine and mine.id) .. " (given " .. tostring(id) .. "); book state " .. tostring(iou(s.ana)[id] and iou(s.ana)[id].state) .. "; eligible for another ride: held? " .. tostring(({ s.DR.RaincheckEligible("Zzzzzz") })[2]))
	eq(can, true, "after a reload the rider may still ask (" .. tostring(why) .. ")")
	eq(mine and mine.id, id, "the reloaded rider receives the offer")
	T.clean(s.w)
end)

test("r8 review adv 14: the rider asks the instant the ride ends (the driver may still list them): the ask is not lost", function()
	local s = book()
	local alerts = 0
	s.ana.W.Listen("DRIVE_ALERT", function(_, kind) if kind == "raincheck" then alerts = alerts + 1 end end)
	ok(s.r.W.CancelRide(), "Wuber cancels (stays in the group)")
	ok(s.r.W.Raincheck.Ask(s.ride.id), "and asks at once")
	s.w:advance(3)
	s.w:leave(TESTCHAR)
	s.w:advance(3)
	local okE, why = s.DR.RaincheckEligible(s.ride.id)
	ok(true, "eligible now: " .. tostring(okE) .. " " .. tostring(why))
	eq(alerts, 1, "the driver was alerted (eligible " .. tostring(okE) .. " " .. tostring(why) .. ")")
	T.clean(s.w)
end)

test("r8 review adv 15: a raincheck-paid ride that fails again earns no second raincheck", function()
	local s = failedPaid()
	local id = giveAccept(s)
	rebook(s)
	eq(s.r.W.ride.voucherTaken, true, "taken")
	ok(s.r.W.CancelRide(), "fails again")
	s.w:leave(TESTCHAR)
	s.w:advance(3)
	local ride2 = s.r.W.ride.id
	eq(iou(s.ana)[id].state, "active", "the raincheck stays active (failed before arrival)")
	eq(s.DR.RaincheckEligible(ride2), false, "no raincheck on the free ride")
	T.clean(s.w)
end)

test("r8 review adv 14b: the rider cancels, stays in the group 5 s (Sorry screen), then asks", function()
	local s = book()
	local alerts = 0
	s.ana.W.Listen("DRIVE_ALERT", function(_, kind) if kind == "raincheck" then alerts = alerts + 1 end end)
	ok(s.r.W.CancelRide(), "Wuber cancels")
	s.w:advance(5)
	local c = s.DR.customers[key(TESTCHAR)]
	print("   row after cancel: " .. tostring(c and c.state) .. " eligible " .. tostring(s.DR.RaincheckEligible(s.ride.id)) .. " " .. tostring(({ s.DR.RaincheckEligible(s.ride.id) })[2]) .. " canAsk " .. tostring(s.r.W.Raincheck.CanAsk(s.ride.id)) .. " inGroup " .. tostring(s.r.W.InGroup()))
	ok(s.r.W.Raincheck.Ask(s.ride.id), "asks")
	s.w:advance(3)
	s.w:leave(TESTCHAR)
	s.w:advance(3)
	local okE, why = s.DR.RaincheckEligible(s.ride.id)
	eq(alerts, 1, "the driver was alerted (eligible now " .. tostring(okE) .. " " .. tostring(why) .. ")")
	T.clean(s.w)
end)

test("r8 review adv 06b: redeemed ride: the summon box is up, the rider presses Cancel, then accepts the game's summon: is the raincheck used?", function()
	local s = failedPaid()
	local id = giveAccept(s)
	rebook(s)
	eq(s.r.W.ride.voucherTaken, true, "taken")
	s.DR.Do("CAST", TESTCHAR)
	s.w:advance(1)
	s.DR.Do("END", TESTCHAR, 1)
	s.w:advance(1)
	ok(s.r.W.CancelRide(), "Wuber cancels while the summon box is up")
	s.w:advance(5)
	local c = s.DR.customers[key(TESTCHAR)]
	print("   row after cancel: " .. tostring(c and c.state) .. ", onRide " .. tostring(iou(s.ana)[id].onRide))
	s.w:move(TESTCHAR, SPOT) -- accepts the summon the game still shows
	s.w:advance(10)
	eq(iou(s.ana)[id].state, "used", "a rider summoned on a redeemed ride has used it")
	T.clean(s.w, { violations = true })
end)

test("r8 review adv 06c: redeemed ride, summon box up; the rider's client sends one R with a new ride id (a /run line), then accepts the summon", function()
	local s = failedPaid()
	local id = giveAccept(s)
	rebook(s)
	eq(s.r.W.ride.voucherTaken, true, "taken")
	s.DR.Do("CAST", TESTCHAR)
	s.w:advance(1)
	s.DR.Do("END", TESTCHAR, 1)
	s.w:advance(1)
	local d = s.r.W.drivers[key(ANA)]
	s.w:inject(TESTCHAR, table.concat({ "R", "1", "Glnzzz", d.dest, tostring(d.price), "0", "0", "2.3.0", "" }, "~"), "WHISPER", s.ana)
	s.w:advance(2)
	local c = s.DR.customers[key(TESTCHAR)]
	print("   row after the forged R: " .. tostring(c and c.state) .. " ride " .. tostring(c and s.DR.RideIdOf(c)) .. ", onRide " .. tostring(iou(s.ana)[id].onRide))
	s.w:move(TESTCHAR, SPOT)
	s.w:advance(10)
	eq(iou(s.ana)[id].state, "used", "a rider summoned on a redeemed ride has used it")
	T.clean(s.w, { violations = true })
end)


-- ===== re-review of the fixes (8cfb301, 610ac62, 0c35665) =====

local function answered(s, rid)
	local a = lastA(s.w, rid)
	return a ~= nil, a
end

test("r8 rereview R1: a legit rebook with the raincheck after the redeemed ride's summon box was cancelled (row still waiting)", function()
	local s = failedPaid()
	local id = giveAccept(s)
	rebook(s)
	eq(s.r.W.ride.voucherTaken, true, "first redeem")
	s.DR.Do("CAST", TESTCHAR) s.w:advance(1)
	s.DR.Do("END", TESTCHAR, 1) s.w:advance(1)
	ok(s.r.W.CancelRide(), "Wuber cancels while the box is up (he declines the summon)")
	s.w:advance(5)
	local c = s.DR.customers[key(TESTCHAR)]
	print("   row: " .. tostring(c and c.state) .. ", voucher " .. tostring(c and c.voucher))
	local ride3 = rebook(s)
	local got = answered(s, ride3.id)
	print("   rebook 70 s later: answered " .. tostring(got) .. ", rider state " .. tostring(s.r.W.ride.state) .. ", taken " .. tostring(s.r.W.ride.voucherTaken))
	s.w:advance(60)
	got = answered(s, ride3.id)
	print("   +60 s: answered " .. tostring(got) .. ", rider state " .. tostring(s.r.W.ride.state) .. ", book " .. tostring(iou(s.ana)[id].state))
	ok(got, "the driver answers the rebook (A) within about 2 minutes")
	T.clean(s.w, { violations = true })
end)

test("r8 rereview R2: no raincheck: a 2.3.0 rider cancels while the summon box is up, then books again", function()
	local s = book({ pay = false })
	s.DR.Do("CAST", TESTCHAR) s.w:advance(1)
	s.DR.Do("END", TESTCHAR, 1) s.w:advance(1)
	ok(s.r.W.CancelRide(), "cancels")
	s.w:advance(5)
	local ride2 = rebook(s)
	local got = answered(s, ride2.id)
	print("   answered " .. tostring(got) .. ", rider state " .. tostring(s.r.W.ride.state))
	ok(got, "the new request is answered")
	T.clean(s.w, { violations = true })
end)

test("r8 rereview R3: lag-drop with the summon box up: END ok, the box times out (rider gone), the ride fails: still eligible?", function()
	local s = book()
	s.DR.Do("CAST", TESTCHAR) s.w:advance(1)
	s.DR.Do("END", TESTCHAR, 1) s.w:advance(1)
	s.w:advance(140) -- the summon box lapses (WAIT_TTL 130 s): the row is back to joined
	local c = s.DR.customers[key(TESTCHAR)]
	print("   row after the box lapsed: " .. tostring(c and c.state))
	fail(s)
	local okE, why = s.DR.RaincheckEligible(s.ride.id)
	eq(okE, true, "a summon that was never accepted is a failed ride (" .. tostring(why) .. ")")
	T.clean(s.w, { violations = true })
end)

-- (F, the lead's decision of 22:37: the crew stays trusted like PAID, so a crew mate's i + a is
-- believed; its facts can't go past the day's cap, and a cover is clamped to the highest fare seen)
test("r8 rereview R4: crew mint with i then a: believed, but within the day's cap and a sane cover", function()
	local s = failedPaid()
	local t = s.cal.env.time() + 7 * 86400 -- issued today
	for i = 1, 5 do
		s.cal.W.Drive.Do("IOU", "i", "Mint000" .. i, key(TESTCHAR), 99999999, t, "")
		s.cal.W.Drive.Do("IOU", "a", "Mint000" .. i, key(TESTCHAR), 99999999, t, "")
	end
	s.w:advance(3)
	local n, most = 0, 0
	for id, v in pairs(iou(s.ana)) do
		if id:match("^Mint") and v.state == "active" then n, most = n + 1, math.max(most, v.cover) end
	end
	print("   minted active in Ana's book: " .. n .. ", day count " .. tostring(s.ana.W.db.drive.iouDay and s.ana.W.db.drive.iouDay.n) .. ", top cover " .. most)
	eq(n, s.DR.RAINCHECK.DAY_CAP, "the 4th and 5th of the day are refused")
	ok(most <= s.ride.price, "cover at most the highest fare seen (" .. most .. ")")
	T.clean(s.w)
end)

test("r8 rereview R5: the join sync fills a fresh window's day cap with old rainchecks", function()
	local s = failedPaid()
	local id = giveAccept(s)
	-- two more active ones from earlier days in Ana's book
	local b = iou(s.ana)
	local t = s.ana.env.time()
	for i = 1, 2 do
		b["Oldx000" .. i] = { rider = "rider " .. i, rideId = "Oldrid", cover = 500, issued = t - 3 * 86400, expires = t + 4 * 86400, state = "active", by = key(ANA), crew = key(ANA), at = t - 3 * 86400 }
	end
	-- Bea loses her book (a new PC) and rejoins
	s.w:leave(BEA) s.w:advance(3)
	s.bea.W.db.drive.iou, s.bea.W.db.drive.iouDay = nil, nil
	s.w:group({ ANA, BEA, CAL }) s.w:advance(20)
	local bb = iou(s.bea)
	print("   Bea: " .. tostring(bb[id] and bb[id].state) .. ", old ones " .. tostring(bb.Oldx0001 and bb.Oldx0001.state) .. ", day count " .. tostring(s.bea.W.db.drive.iouDay and s.bea.W.db.drive.iouDay.n))
	ok((s.bea.W.db.drive.iouDay and s.bea.W.db.drive.iouDay.n or 0) <= 1, "only today's raincheck counts toward Bea's cap today")
	T.clean(s.w, { violations = true })
end)

test("r8 rereview R6: an offer the rider never saw lapses in the book; the rider's copy (offline at the lapse) still offers Accept", function()
	local s = failedPaid()
	ok(s.r.W.Raincheck.Ask(s.ride.id), "asks")
	s.w:advance(2)
	local _, id = s.DR.GiveRaincheck(s.ride.id)
	s.w:advance(2)
	eq(s.r.W.Raincheck.Mine()[1].state, "offered", "Wuber's copy: offered")
	local saved = s.w:logout(s.r)
	s.w:advance(1900)
	eq(iou(s.ana)[id].state, "void", "the book: lapsed")
	local r2 = s.w:addClient(TESTCHAR, { spot = "Orgrimmar", class = "MAGE", money = 1000000, saved = saved })
	r2.W.VERSION = "2.3.0"
	s.w:advance(5)
	local mine = r2.W.Raincheck.Mine()[1]
	print("   Wuber's copy after the lapse: " .. tostring(mine and mine.state) .. "; Accept -> " .. tostring(r2.W.Raincheck.Accept(id)) .. "; ForDriver -> " .. tostring(r2.W.Raincheck.ForDriver(key(ANA))))
	eq(r2.W.Raincheck.ForDriver(key(ANA)), nil, "a lapsed offer is not shown as usable")
	T.clean(s.w)
end)

test("r8 rereview R7: a failed paid ride restored after a /reload: no second trip, no new toast, a new booking works", function()
	local s = failedPaid()
	local trips = #(s.r.W.db.rides and s.r.W.db.rides.trips or {})
	local r2 = s.w:reload(s.r)
	r2.W.VERSION = "2.3.0"
	s.w:advance(3)
	print("   restored: " .. tostring(r2.W.ride and r2.W.ride.state) .. ", trips " .. trips .. " -> " .. #(r2.W.db.rides and r2.W.db.rides.trips or {}))
	eq(#(r2.W.db.rides and r2.W.db.rides.trips or {}), trips, "no trip added by the restore")
	eq(r2.W.Raincheck.CanAsk(r2.W.ride), true, "may ask")
	s.r = r2
	s.w:advance(65)
	local ride2, why = r2.W.RequestRide(key(ANA))
	ok(ride2, "a new booking after the restore: " .. tostring(why))
	T.clean(s.w)
end)


test("r8 rereview R8: a lag-drop longer than 10 min: the failed paid ride after a relog 15 min later", function()
	local s = failedPaid()
	local saved = s.w:logout(s.r)
	s.w:advance(900)
	local r2 = s.w:addClient(TESTCHAR, { spot = "Orgrimmar", class = "MAGE", money = 1000000, saved = saved })
	r2.W.VERSION = "2.3.0"
	s.w:advance(3)
	print("   restored after 15 min: " .. tostring(r2.W.ride and r2.W.ride.state) .. "; driver eligible " .. tostring(s.DR.RaincheckEligible(s.ride.id)))
	eq(r2.W.ride and r2.W.ride.id, s.ride.id, "the failed paid ride is still there to ask about (the 30-minute window)")
	T.clean(s.w)
end)
