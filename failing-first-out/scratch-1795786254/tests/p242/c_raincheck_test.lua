-- Tests of group C (prep-242): Net.Raincheck keeps the last paid, failed ride (AU24-07).
local T = ...
local test = T.test

-- Anita takes Wuber's ride, Wuber pays the whole fare by a completed trade, then cancels before arriving
local function paidFailedRide()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { netOnly = true })
	local r = T.rider(w, T.TESTCHAR, { money = 100000 })
	r.W.VERSION = "2.3.0"
	T.settle(w)
	T.goOnline(d)
	local ride = r.W.RequestRide("anita lift")
	w:advance(1)
	assert(d.W.AcceptRequest(ride.id, 5), "accepted")
	w:group({ T.ANITA, T.TESTCHAR })
	w:advance(1)
	w:move(T.ANITA, "Orgrimmar")
	w:advance(1)
	assert(w:openTrade(w:player(T.ANITA), w:player(T.TESTCHAR)), "a trade opens")
	w:tradeMoney(w:player(T.TESTCHAR), ride.price)
	w:tradeAccept(w:player(T.ANITA))
	w:tradeAccept(w:player(T.TESTCHAR))
	w:advance(6)
	assert(r.W.CancelRide(), "the ride ends before arrival")
	w:advance(1)
	return w, d, r, ride
end

local function give(d, ride, id, from)
	d.W.Raincheck.Give(ride.id, T.TESTCHAR, id, d.env.time() + 7 * 86400, 5000, "Anita Lift")
end

-- The promise: the rider's paid, failed ride's driver can still give after the failed-ride screen is gone.
test("p242.c: a give from the failed ride's driver reaches the rider after W.ClearRide", function()
	local w, d, r, ride = paidFailedRide()
	r.W.ClearRide()
	give(d, ride, "Rc000002")
	w:advance(1)
	assert(#r.W.Raincheck.Mine() == 1, "no offer after the screen was left: " .. #r.W.Raincheck.Mine())
	T.clean(w)
end)

test("p242.c: the note survives a /reload of the rider", function()
	local w, d, r, ride = paidFailedRide()
	r.W.ClearRide()
	local r2 = w:reload(r)
	w:advance(5)
	give(d, ride, "Rc000003")
	w:advance(1)
	assert(#r2.W.Raincheck.Mine() == 1, "no offer after a reload: " .. #r2.W.Raincheck.Mine())
	T.clean(w)
end)

-- guard: unchanged path, a give while the failed ride is still held
test("p242.c: guard: a give while the ride is still held works as before", function()
	local w, d, r, ride = paidFailedRide()
	give(d, ride, "Rc000001")
	w:advance(1)
	assert(#r.W.Raincheck.Mine() == 1, "control broken")
	T.clean(w)
end)

-- guard: a give from anyone but that ride's driver is still ignored
test("p242.c: guard: a give from another player is ignored once the screen is gone", function()
	local w, d, r, ride = paidFailedRide()
	r.W.ClearRide()
	local o = T.driver(w, T.BOB, { netOnly = true })
	T.settle(w)
	o.W.Raincheck.Give(ride.id, T.TESTCHAR, "Rc000004", o.env.time() + 7 * 86400, 5000, "Anita Lift")
	w:advance(1)
	assert(#r.W.Raincheck.Mine() == 0, "another sender was believed")
	T.clean(w)
end)

-- guard: a give after 30 minutes is ignored
test("p242.c: guard: a give over 30 minutes after the failure is ignored", function()
	local w, d, r, ride = paidFailedRide()
	r.W.ClearRide()
	w:advance(1900)
	give(d, ride, "Rc000005")
	w:advance(1)
	assert(#r.W.Raincheck.Mine() == 0, "a late give was believed")
	T.clean(w)
end)
