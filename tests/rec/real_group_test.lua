-- Conformance (the flight recorder, lane B2): leaving a group in the fake game against the real client.
-- Evidence: the test addon's lines (kinds "ev" and "sys") on the real client, 17-21 Nov 2026
-- (tests/fixtures/rec/lab-real-facts.lua, id group.leave.cancel_summon).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local L = dofile(T.dir .. "/rec/real_lib.lua")

local RIDER = "Wuber Rocks"
local EXIT = L.set({ "GROUP_LEFT", "CHANNEL_UI_UPDATE", "GROUP_ROSTER_UPDATE", "CANCEL_SUMMON" })

-- A ride from request to "arrived": the driver (Anita Lift) at Ratchet, the rider in Orgrimmar.
local function arrived(opts)
	local w = T.newWorld(opts)
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, RIDER)
	T.settle(w)
	r.W.db.autoAccept = false
	T.goOnline(d)
	d.W.Drive.SetOpt("autoTrade", false) -- (d4 x4) the summon now counts as ours, so the driver would open the trade 3 s after landing: this test is about the group exit
	r.W.RequestRide("anita lift")
	w:advance(1)
	w:advance(3) -- (Wuber's engine takes the rider and invites by itself)
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

local function accept(w, r)
	r:clickText("Accept summon")
	w:advance(6)
	eq(T.rideState(r), "arrived", "landed")
end

-- group.leave.cancel_summon: all 20 group exits of the recording (13 "You have been removed from the
-- group.", 5 "You leave the group.", 2 "Your group has been disbanded.") have CANCEL_SUMMON in the same
-- millisecond as the line, also when the summon was accepted long before (21 s to 24 h) or there was
-- none (2 of 20). The roster update (members=0) came 37-157 ms BEFORE the line in 18 of 20 exits (in
-- the same instant or 50 ms after in the other 2), e.g. verbatim:
--   20 Nov 13:05:07.179 Wuber Rocks GROUP_ROSTER_UPDATE members=0
--   20 Nov 13:05:07.329 Wuber Rocks sys You have been removed from the group.   + CANCEL_SUMMON
--   21 Nov 00:07:54.545 Wuber Rocks sys You have been removed from the group.   + CANCEL_SUMMON (64 s after the summon box)
--   21 Nov 00:07:54.595 Wuber Rocks GROUP_ROSTER_UPDATE members=0
-- (The fact's summary says the roster update follows; the lines say it mostly comes first: the fake
-- follows the 18 of 20.)
local function exitShape(rec, line)
	local names = rec.names()
	-- (REC 22 Nov, WuberRec 1.1.0) GROUP_LEFT carries (1, "<->") and CHANNEL_UI_UPDATE fires between it and the roster update
	eq(names, 'GROUP_LEFT(1,<->) CHANNEL_UI_UPDATE GROUP_ROSTER_UPDATE CANCEL_SUMMON', line)
	local gru, cancel = rec.find("GROUP_ROSTER_UPDATE"), rec.find("CANCEL_SUMMON")
	local dt = cancel[2] - gru[2]
	ok(dt >= 0.03 and dt <= 0.16, line .. ": CANCEL_SUMMON 0.03-0.16 s after the roster update: " .. dt)
end

test("rec: real: removed from the group after an accepted summon: CANCEL_SUMMON (group.leave.cancel_summon)", function()
	local w, d, r = arrived()
	accept(w, r)
	local rec = L.record(w, r, EXIT)
	w:uninvite(d, RIDER)
	w:advance(1)
	exitShape(rec, "removed")
	eq(T.rideState(r), "arrived", "Wuber leaves an arrived ride alone on CANCEL_SUMMON")
	T.clean(w)
end)

test("rec: real: leaving the group (LeaveParty): CANCEL_SUMMON (group.leave.cancel_summon)", function()
	local w, d, r = arrived()
	accept(w, r)
	local rec = L.record(w, r, EXIT)
	r.env.C_PartyInfo.LeaveParty()
	w:advance(1)
	exitShape(rec, "left")
	T.clean(w)
end)

test("rec: real: the group disbands: the last one gets CANCEL_SUMMON too (group.leave.cancel_summon)", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local r = T.rider(w, RIDER)
	T.settle(w)
	w:group({ T.ANITA, RIDER })
	w:advance(1)
	local rd = L.record(w, d, EXIT)
	r.env.C_PartyInfo.LeaveParty()
	w:advance(1)
	exitShape(rd, "disbanded")
	T.clean(w)
end)

-- REC bug (BUGS-NEXT): Net/Rides.lua's CANCEL_SUMMON handler puts a "portal" ride back to "ingroup"
-- without asking whether the rider is still in a group. On the real client CANCEL_SUMMON comes with every
-- group exit, so a rider who leaves (or is removed) while the summon box is up reads "in the group" for
-- up to 10 minutes (STATE_LIMIT.ingroup) with no group at all; the old fake left it at "portal" (120 s).
test("rec: real: out of the group with the summon box up, the ride does not say ingroup (group.leave.cancel_summon)", function()
	local w, d, r = arrived()
	r.env.C_PartyInfo.LeaveParty()
	w:advance(1)
	ok(T.rideState(r) ~= "ingroup", "not ingroup out of the group: " .. tostring(T.rideState(r)))
	T.clean(w)
end)

test("rec: real: removed while the summon box is up: the box goes, CANCEL_SUMMON (group.leave.cancel_summon)", function()
	local w, d, r = arrived()
	local rec = L.record(w, r, EXIT)
	w:uninvite(d, RIDER)
	w:advance(1)
	exitShape(rec, "removed with the box up")
	eq(r.popups.CONFIRM_SUMMON, nil, "the summon box is gone")
	eq(r.player.pendingSummon, nil, "no summon to accept")
	T.clean(w)
end)
