-- Decisions round, group A2 (follow-up to FAB-01): a rider in line who hears NO beacon of his driver (his Wuber is cut
-- off the hidden channel) hears only his queue place P. The driver's Wuber sends that place again when the last P to him
-- is older than 60 s, so he keeps waiting; at most one P per rider per 60 s. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- Anita drives one rider at a time, Wuber is in her group, Bob is queued behind him; then Bob's Wuber is cut off the
-- channel (another copy of it: channel messages no longer reach him, whispers do).
local function queuedDeaf()
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
	ok(bob.W.ride.position, "setup: Bob was told his place in line")
	w:splitChannel(bob, "cut off")
	return w, d, bob, #w.addonLog
end

-- the queue places Anita sent Bob since log entry `from`: the times
local function placesSent(w, from)
	local at = {}
	for i = from + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.from == T.ANITA and e.prefix == "WUBER" and e.chatType == "WHISPER" and key(tostring(e.target)) == key(T.BOB)
			and e.text:match("^P~") then
			at[#at + 1] = e.at
		end
	end
	return at
end

test("dec a2: a rider in line who hears no beacon still waits after 5 minutes; his place came at most once per 60 s", function()
	local w, d, bob, from = queuedDeaf()
	local beaconAt = (bob.W.drivers[key(T.ANITA)] or {}).heard
	for _ = 1, 60 do w:advance(5) end
	local later = (bob.W.drivers[key(T.ANITA)] or {}).heard -- nil: Bob's list dropped her (no beacon for 150 s)
	ok(later == nil or later == beaconAt, "setup: no beacon of Anita reached Bob in those 5 minutes")
	local cb = d.W.Drive.customers[key(T.BOB)]
	eq(cb and cb.state, "queued", "Anita's list still has Bob queued")
	eq(T.rideState(bob), "accepted", "after 5 minutes in line with no beacon heard Bob's own Wuber still waits")
	local at = placesSent(w, from)
	ok(#at >= 4 and #at <= 5, "Anita sent Bob his place again 4 or 5 times in 5 minutes (sent " .. #at .. ")")
	for i = 2, #at do
		ok(at[i] - at[i - 1] >= 59.9, "two places to Bob are at least 60 s apart (" .. (at[i] - at[i - 1]) .. " s)")
	end
	eq(bob.W.ride.position, 1, "Bob's place is the same one")
	T.clean(w)
end)

test("dec a2: a rider in line who hears no beacon gives up about 150 s after the driver's client closes", function()
	local w, d, bob = queuedDeaf()
	for _ = 1, 40 do w:advance(5) end
	eq(T.rideState(bob), "accepted", "setup: Bob still waits after 200 s")
	w:closeClient(d) -- the driver's game is gone: no more queue places
	for _ = 1, 16 do w:advance(5) end
	eq(T.rideState(bob), "accepted", "80 s after the driver closed Bob still waits")
	for _ = 1, 15 do w:advance(5) end
	eq(T.rideState(bob), "failed", "155 s after the driver closed the ride is over")
	T.clean(w)
end)

test("dec a2: a driver with nobody in line sends no queue place, open or closed", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local bob = T.rider(w, T.BOB)
	T.settle(w)
	T.goOnline(d)
	for _ = 1, 30 do w:advance(5) end
	eq(#placesSent(w, 0), 0, "open with an empty queue: no P")
	ok(bob.W.drivers[key(T.ANITA)], "setup: Bob sees Anita")
	T.clean(w)
end)
