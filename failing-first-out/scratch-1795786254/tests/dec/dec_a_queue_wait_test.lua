-- Decisions round, group A (FAB-01): a rider in line WAITS while the driver keeps him. His own Wuber gives up only
-- after NETK.QUEUE_SILENCE (150 s) with nothing heard from that driver (the queue place P, any ride message, a beacon).
-- A rider who was told no place keeps the old limits. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- Anita drives one rider at a time, Wuber is in her group, Bob is queued behind him.
local function queued()
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
	eq(T.rideState(bob), "accepted", "setup: Bob's request was accepted (he waits in the queue)")
	local cb = d.W.Drive.customers[key(T.BOB)]
	eq(cb and cb.state, "queued", "setup: Anita's list has Bob queued")
	ok(bob.W.ride.position, "setup: Bob was told his place in line")
	return w, d, bob
end

test("dec a: a rider in line still waits after 5 minutes with a live driver, and the driver's list keeps him", function()
	local w, d, bob = queued()
	for _ = 1, 60 do w:advance(5) end
	local cb = d.W.Drive.customers[key(T.BOB)]
	eq(T.rideState(bob), "accepted", "after 5 minutes in line Bob's own Wuber still waits (the driver's list: "
		.. tostring(cb and cb.state or "Bob gone") .. ")")
	eq(cb and cb.state, "queued", "Anita's list still has Bob queued")
	eq(bob.W.Mod("Net.Base").NETK.QUEUE_SILENCE, 150, "the silence limit is one named number")
	T.clean(w)
end)

test("dec a: a rider in line gives up about 150 s after the driver goes silent", function()
	local w, d, bob = queued()
	for _ = 1, 40 do w:advance(5) end
	eq(T.rideState(bob), "accepted", "setup: Bob still waits after 200 s")
	w:closeClient(d) -- the driver's game is gone: nothing more is heard from her
	for _ = 1, 12 do w:advance(5) end
	eq(T.rideState(bob), "accepted", "60 s of silence is not enough to give up")
	for _ = 1, 19 do w:advance(5) end
	eq(T.rideState(bob), "failed", "155 s after the driver went silent the ride is over")
	T.clean(w)
end)

test("dec a: a rider who was told no place in line keeps the old 120 s limit", function()
	local w, d, bob = queued()
	local r = bob.W.ride
	r.position = nil
	d.roundOne = true -- (group A2) her client sends no queue place from here on, as an old driver's: the place is not sent again
	local left = 120 - (bob.env.GetTime() - r.changed)
	w:advance(left - 5)
	eq(T.rideState(bob), "accepted", "5 s before the limit the ride is still on")
	w:advance(10)
	eq(T.rideState(bob), "failed", "accepted for 120 s with no place heard: the ride fails as before")
	T.clean(w)
end)
