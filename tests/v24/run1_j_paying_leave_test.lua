-- Run 1 group j, item 7: a rider in "paying" who is removed from the driver's group ends the ride within about 5 s
-- (the same "done (no payment seen)" ending as the 60 s timer), without marking anything paid.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local RIDER = "Wuber Rocks"

local function paying()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, RIDER)
	T.settle(w)
	r.W.db.autoAccept = false
	T.goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(4)
	r.W.UI.Toggle(true)
	w:advance(2.5)
	r:clickText("Accept invite")
	w:advance(1)
	w:summon(d, RIDER)
	w:advance(1)
	r:clickText("Accept summon")
	w:advance(6)
	return w, d, r
end

test("run1 j7: a paying rider removed from the group ends the ride within 6 s, unpaid", function()
	local w, d, r = paying()
	local st = T.rideState(r)
	ok(st == "paying" or st == "arrived", "at the pay step: " .. tostring(st))
	r.W.ride.state = "paying" -- the driver's trade request is up
	w:uninvite(d, RIDER)
	w:advance(6)
	eq(T.rideState(r), "done", "ended")
	ok(not r.W.ride or not r.W.ride.paid, "nothing marked paid")
	T.clean(w)
end)

test("run1 j7: still in the group, a paying ride waits", function()
	local w, d, r = paying()
	r.W.ride.state = "paying"
	w:advance(30)
	eq(T.rideState(r), "paying", "still paying")
	T.clean(w)
end)
