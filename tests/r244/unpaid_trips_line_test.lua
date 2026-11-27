-- 3045 answer 6: a rider removed from the group while the summon box is up. Is that ride saved in Trips as unpaid?
-- This test only observes (what is saved and what Trips lists) and prints it in its messages.
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


local function tripsRows(r)
	local m = r.W.Mod("UI.Rider.Trips")
	local live, unpaid = 0, 0
	for _, row in ipairs((m and m.view and m.view().rows) or {}) do
		if row.live and row.trip then
			live = live + 1
			if row.trip.unpaid then unpaid = unpaid + 1 end
		end
	end
	return live, unpaid
end

-- guard: the removed-from-the-group ride is stored but hidden: Trips never lists it and its count never includes it,
-- so the Done page's "An unpaid ride isn't saved in Trips" is true and stays as it is (answer 6, no change needed)
test("unpaid trips 3045: removed from the group at the summon box: stored as unpaid, not listed or counted in Trips", function()
	local w, d, r = boxUp()
	r.W.db.rides[#r.W.db.rides + 1] = { dest = "Orgrimmar", driver = "anita lift", price = 5000, at = r.W.Now and r.W.Now() or 1 } -- a paid trip, to prove the view lists
	local before = #r.W.db.rides
	w:uninvite(d, RIDER)
	w:advance(1)
	eq(T.rideState(r), "done", "the ride has ended")
	local last = r.W.db.rides[#r.W.db.rides]
	eq(#r.W.db.rides, before + 1, "the ended ride is stored")
	ok(last and last.unpaid == true, "stored as unpaid")
	r.W.UI.Toggle(true)
	w:advance(1)
	pcall(function() r:clickText("Done") end)
	w:advance(1)
	pcall(function() r:clickText("Trips") end)
	w:advance(2)
	local live, unpaid = tripsRows(r)
	eq(live, 1, "Trips lists only the paid trip, not the removed ride")
	eq(unpaid, 0, "no unpaid trip is listed")
	T.clean(w)
end)
