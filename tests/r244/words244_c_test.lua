-- words244 C (line 11): the rider is removed from the group while the summon box is up: the ended page, "Ride ended", with the line
-- "Removed from the group". Leaving by oneself and a normal end are unchanged.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local RIDER = "Wuber Rocks"

local function boxUp()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, RIDER)
	T.settle(w)
	r.W.db.autoAccept = false
	T.goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(1)
	w:advance(3)
	r.W.UI.Toggle(true)
	w:advance(2.5)
	r:clickText("Accept invite")
	w:advance(1)
	w:summon(d, RIDER)
	w:advance(1)
	eq(T.rideState(r), "portal", "the summon is up")
	d.W.SendTo = function() return true end -- (the driver's own whisper would end the ride by itself)
	return w, d, r
end

local function seen(r, text)
	for _, t in ipairs(r:visibleTexts()) do
		if tostring(t):find(text, 1, true) then return true end
	end
	return false
end

test("words244 C: removed from the group with the summon box up shows Ride ended and Removed from the group", function()
	local w, d, r = boxUp()
	w:uninvite(d, RIDER)
	w:advance(1)
	eq(T.rideState(r), "done", "the ride has ended")
	ok(seen(r, "Ride ended"), "title Ride ended: " .. table.concat(r:visibleTexts(), " | "))
	ok(seen(r, "Removed from the group"), "the line: " .. table.concat(r:visibleTexts(), " | "))
	T.clean(w)
end)

test("words244 C: guard, leaving the group by oneself with the box up is not the removed page", function()
	local w, d, r = boxUp()
	r.env.C_PartyInfo.LeaveParty()
	w:advance(1)
	ok(T.rideState(r) ~= "done", "not ended: " .. tostring(T.rideState(r)))
	ok(not seen(r, "Removed from the group"), "no removed line")
	T.clean(w)
end)

test("words244 C: guard, a normal unpaid end shows Ride ended without the removed line", function()
	local w, d, r = boxUp()
	r.W.ride.state = "arrived"
	ok(r.W.EndRide("rider"), "ended")
	w:advance(1)
	ok(seen(r, "Ride ended"), "title: " .. table.concat(r:visibleTexts(), " | "))
	ok(not seen(r, "Removed from the group"), "no removed line")
	T.clean(w)
end)
