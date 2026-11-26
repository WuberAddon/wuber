local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- HUNT-22: a ride ended without paying is not listed in Trips (the Done screen says so): the list and
-- its trip count leave it out. The saved row stays in the saved data.

test("r32 c2: Trips leaves an unpaid ride out of its list and its trip count", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local W = r.W
	local now = 1700000000
	W.db.rides = {
		{ at = now - 300, driver = "Anita Lift", dest = "Orgrimmar", price = 50000 },
		{ at = now - 200, driver = "Anita Lift", dest = "Undercity", price = 50000, unpaid = true },
		{ at = now - 100, driver = "Anita Lift", dest = "Thunder Bluff", price = 50000 },
	}
	W.UI.Toggle(true)
	w:advance(1)
	W.UI.SelectTab("Trips")
	w:advance(1)
	W.UI.UpdateTrips()
	local tr = W.UI.trips
	local live, seen = 0, ""
	for _, row in ipairs(tr.rows) do
		if row.live then live = live + 1 seen = seen .. (row.dest:GetText() or "") .. ";" end
	end
	eq(live, 2, "two paid trips listed: " .. seen)
	ok(not seen:find("Undercity", 1, true), "the unpaid ride is not listed: " .. seen)
	eq(tr.hCount:GetText(), "2 trips", "the count leaves it out")
	eq(#W.db.rides, 3, "the saved row is left alone")
end)
