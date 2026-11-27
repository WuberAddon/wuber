-- Blind-spot check 4, "no way out" (job 206): the bug hunt's promises for run 1 items 6, 7 and REC-04, run in the suite.
-- The promises live in tests/promises/nowayout.lua (the hunt's registry, so the sweep checks them in thousands of
-- situations too); tools/hunt/nowayout_check.lua also runs the sequence chains of tools/hunt/seq_hunt.lua (about 8 s, not here).
-- Item 8 (a rider taken off the list who asks again is a rider again) is covered by tests/run1_i_redrop.lua.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local Hunt
local function run(id, sit)
	if not Hunt then
		Hunt = dofile(T.dir .. "/hunt/lib.lua")
		Hunt.init({})
	end
	local res = Hunt.runPromise(id, sit, 1, { always = false })
	eq(res.status, "pass", tostring(res.seen or res.detail or res.status))
end

test("bs4 item6: a rider taken off the list but still in the group can be removed", function()
	run("nowayout.driver_can_remove_rider", { role = "warlock", ride = "arrived" })
end)

test("bs4 item7: a rider at the pay step taken out of the group is not left waiting for a trade", function()
	run("nowayout.rider_not_stuck_after_cancelled_trade", { role = "rider", ride = "arrived" })
end)

test("bs4 rec04: leaving the group with the summon box up does not leave the ride at ingroup", function()
	run("nowayout.rider_never_stuck_waiting", { role = "rider", ride = "summoning" })
end)

-- A real remaining gap, not fixed by 201b: the summon ran out while the rider was in the group (CANCEL_SUMMON puts the ride
-- back to "ingroup", right), and the rider then leaves the group 0.5 s or more later: nothing moves the ride on, it says
-- "ingroup" with no group (tools/hunt/seq_hunt.lua chain cancel_then_leave: still so 72 s later; the limit is 10 minutes).
-- The recordings show CANCEL_SUMMON at the very instant of a group exit (20 of 20), so this order is not proven real.
test("bs4 rec04b: summon ran out in the group, the rider leaves later: the ride does not say ingroup", function()
	local Seq = dofile(T.dir .. "/../tools/hunt/seq_hunt.lua")
	local res = Seq.runAll({ seed = 1, chain = "cancel_then_leave" })
	eq(res.chains[1].status, "pass", tostring(res.chains[1].failure))
end)

test("bs4 rec04b (30s): summon ran out in the group, rider leaves 30s later: clears ingroup and allows re-invite", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, "Wuber Rocks")
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
	w:summon(d, "Wuber Rocks")
	w:advance(1)
	eq(T.rideState(r), "portal", "summon box up")
	r.env.CancelSummon()
	r:fire("CANCEL_SUMMON")
	w:advance(30)
	eq(T.rideState(r), "ingroup", "still waiting in group 30s after summon expired")
	r.env.C_PartyInfo.LeaveParty()
	w:advance(0.5)
	eq(T.rideState(r), "accepted", "leaving 30s later clears ingroup back to accepted")
	T.clean(w)
end)
