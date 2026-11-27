-- Decisions round, group A3 (follow-up to A2): the driver's queue place is sent again every 60 s with the same eta.
-- The rider's countdown must keep running on a repeat of the SAME place, and restart only when the place changes.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function queuedBob()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local testchar = T.rider(w, T.TESTCHAR)
	local bob = T.rider(w, T.BOB)
	T.settle(w)
	T.goOnline(d)
	d.W.Drive.SetOpt("oneAtATime", true)
	w:advance(2)
	T.requestVia(testchar, "anita lift")
	w:advance(8)
	T.requestVia(bob, "anita lift")
	w:advance(6)
	eq(T.rideState(bob), "accepted", "setup: Bob waits in the queue")
	ok(bob.W.ride.position and bob.W.ride.etaAt, "setup: Bob has a place and a countdown")
	return w, d, bob
end

test("dec a3: the same queue place heard again 60 s on does not restart the rider's countdown", function()
	local w, d, bob = queuedBob()
	local r = bob.W.ride
	local eta0, at0, heard0 = r.eta, r.etaAt, r.heardAt
	w:advance(65)
	r = bob.W.ride
	ok(r.heardAt > heard0, "setup: the driver's place came again (heardAt moved on)")
	eq(r.position, 1, "setup: the place is the same")
	eq(r.etaAt, at0, "the countdown's end did not move later")
	eq(r.eta, eta0, "the eta did not change")
	T.clean(w)
end)

test("dec a3: a changed queue place takes the new eta", function()
	local w, d, bob = queuedBob()
	local r = bob.W.ride
	local at0 = r.etaAt
	w:advance(10)
	r.position = 2 -- the rider's copy had another place: the next P differs from it
	w:advance(65)
	r = bob.W.ride
	eq(r.position, 1, "setup: the driver's place was heard")
	ok(r.etaAt ~= at0, "the countdown was taken afresh for the changed place")
	T.clean(w)
end)
