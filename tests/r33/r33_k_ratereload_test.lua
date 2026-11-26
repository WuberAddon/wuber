local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function doneRide(w, d, r)
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
	w:openTrade(d, r)
	w:advance(0.5)
	w:tradeMoney(r, 5000)
	w:tradeAccept(d)
	w:tradeAccept(r)
	w:advance(1)
end

local function lastTrip(c) local t = c.W.db.rides return t and t[#t] end

test("r33 AUD-23: ride finished, /reload before rating: the stars given afterwards are not kept in Trips", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w) T.goOnline(d) w:advance(5)
	doneRide(w, d, r)
	eq(r.W.ride.state, "done", "setup")
	local r2 = w:reload(r)
	w:advance(3)
	ok(r2.W.ride and r2.W.ride.state == "done" and not r2.W.ride.rated, "setup: the unrated Done screen came back")
	ok(r2.W.Rate(5), "the rider's rating is accepted and sent")
	ok(lastTrip(r2) and lastTrip(r2).stars == 5,
		"the rider gave 5 stars after /reload, the Done screen confirms it, but the trip in Trips has stars = " .. tostring(lastTrip(r2) and lastTrip(r2).stars))
	T.clean(w)
end)