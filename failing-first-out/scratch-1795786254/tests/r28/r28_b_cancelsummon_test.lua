-- r28 group B: REC-04, CANCEL_SUMMON while out of the group (Wuber/Net/Rides.lua).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local RIDER = "Wuber Rocks"

-- A ride up to the summon box: the driver (Anita Lift) at Ratchet, the rider in Orgrimmar.
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
	eq(T.rideState(r), "ingroup", "in the group")
	w:summon(d, RIDER)
	w:advance(1)
	eq(T.rideState(r), "portal", "the summon is up")
	return w, d, r
end

-- the driver's own "declined" whisper would end the ride by itself; here it never arrives (lost, or the driver is gone)
local function quiet(d) d.W.SendTo = function() return true end end

test("r28 REC-04: out of the group with the summon box up, the ride does not say ingroup", function()
	local w, d, r = boxUp()
	quiet(d)
	r.env.C_PartyInfo.LeaveParty()
	w:advance(0.15)
	ok(T.rideState(r) ~= "ingroup", "not ingroup out of the group: " .. tostring(T.rideState(r)))
	T.clean(w)
end)

test("r28 REC-04: removed from the group with the summon box up, the ride does not say ingroup", function()
	local w, d, r = boxUp()
	quiet(d)
	w:uninvite(d, RIDER)
	w:advance(0.15)
	ok(T.rideState(r) ~= "ingroup", "not ingroup out of the group: " .. tostring(T.rideState(r)))
	T.clean(w)
end)

test("r28 REC-04: declining the summon box while still in the group goes back to waiting in the group", function()
	local w, d, r = boxUp()
	r.env.CancelSummon()
	r:fire("CANCEL_SUMMON")
	w:advance(1)
	eq(T.rideState(r), "ingroup", "back to waiting in the group")
	T.clean(w)
end)
