-- Wuber 2.4 fix round 3, group C: LRN-05, the summoner's name may arrive late after CONFIRM_SUMMON.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local ANITA, TESTCHAR = T.ANITA, T.TESTCHAR

local function ride(late, word)
	local w = T.newWorld()
	local d = T.driver(w, ANITA)
	local r = T.rider(w)
	T.settle(w)
	T.goOnline(d)
	T.requestVia(r, "anita lift")
	w:advance(8)
	w:summon(d, TESTCHAR, { nameLate = late, lateWord = word })
	return w, d, r
end

test("v24 f3c: the summoner's name at once: summonedBy is set (control)", function()
	local w, d, r = ride(nil)
	w:advance(1)
	eq(r.W.ride.state, "portal", "the summon is up")
	eq(r.W.ride.summonedBy, "anita lift", "named at once")
	T.clean(w)
end)

test("v24 f3c: a name 3 s late is asked for again and gives the same state, one RIDE event per change", function()
	local w, d, r = ride(3)
	w:advance(1)
	eq(r.W.ride.state, "portal", "the summon is up")
	ok(not r.W.ride.summonedBy, "not named yet")
	w:advance(4)
	eq(r.W.ride.summonedBy, "anita lift", "the late name was taken")
	eq(r.W.ride.state, "portal", "still at the portal")
	T.clean(w)
end)

test("v24 f3c: a name later than 5 s is given up on; the box closing stops the asking", function()
	local w, d, r = ride(9)
	w:advance(7)
	ok(not r.W.ride.summonedBy, "gave up after about 5 s")
	T.clean(w)
	local w2, d2, r2 = ride(3)
	w2:advance(1)
	r2.env.C_SummonInfo.CancelSummon()
	r2.fire("CANCEL_SUMMON")
	w2:advance(6)
	ok(not r2.W.ride.summonedBy, "cancelled: no late name written")
	T.clean(w2)
end)

test("v24 f3c: the game's word 'Unknown' is not a summoner's name; the real name is taken when it comes", function()
	local w, d, r = ride(3, "Unknown")
	w:advance(1)
	eq(r.W.ride.state, "portal", "the summon is up")
	ok(not r.W.ride.summonedBy, "'Unknown' was not written as the summoner (" .. tostring(r.W.ride.summonedBy) .. ")")
	w:advance(4)
	eq(r.W.ride.summonedBy, "anita lift", "the real name was taken")
	T.clean(w)
end)
