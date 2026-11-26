-- Round 28 lead, REC-04: the recorded client fires CANCEL_SUMMON at the instant of the group exit and its roster
-- update about 50 ms later. Whether the group still counts at that instant is not recorded, so both orders are held.
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
	w:advance(4)
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

test("r28 REC-04: the group still counts at the instant of CANCEL_SUMMON: a moment later the ride no longer says ingroup", function()
	local w, d, r = boxUp()
	d.W.SendTo = function() return true end -- the driver's own "declined" whisper never arrives
	local real = r.W.InGroup
	r.W.InGroup = function() return true end -- the roster has not caught up yet
	r.env.C_PartyInfo.LeaveParty()
	w:advance(0.15)
	eq(T.rideState(r), "ingroup", "control: at that instant the ride goes back to waiting in the group")
	r.W.InGroup = real
	w:advance(0.5)
	ok(T.rideState(r) ~= "ingroup", "out of the group a moment later: " .. tostring(T.rideState(r)))
	T.clean(w)
end)

test("r28 REC-04: the summon box declined in the group: the later look changes nothing", function()
	local w, d, r = boxUp()
	r.env.CancelSummon()
	r:fire("CANCEL_SUMMON")
	w:advance(2)
	eq(T.rideState(r), "ingroup", "still waiting in the group")
	T.clean(w)
end)
