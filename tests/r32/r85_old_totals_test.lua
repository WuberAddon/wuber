local T = ...
local test, eq = T.test, T.eq

-- #85: saved data from older versions counted unpaid rides in the lifetime totals, so Trips listed
-- fewer trips than the ride count said. On load, totals made before unpaid rides were left out are
-- made again from the saved trips (all of them are kept while there are fewer than 100).

test("r85: old saved totals that counted an unpaid ride are made again, so the ride count matches Trips", function()
	local w = T.newWorld()
	local now = 1700000000
	local saved = { Wuber = {
		progressReady = true,
		rides = {
			{ at = now - 300, driver = "Anita Lift", dest = "Orgrimmar", price = 50000 },
			{ at = now - 200, driver = "Anita Lift", dest = "Undercity", price = 50000, unpaid = true },
			{ at = now - 100, driver = "Anita Lift", dest = "Thunder Bluff", price = 50000 },
		},
		totals = { rides = 3, spent = 150000, saved = 0, savedValue = 0, places = {}, placeCount = 3, drivers = {} },
	} }
	local r = T.rider(w, T.TESTCHAR, { saved = saved })
	T.settle(w)
	local W = r.W
	eq(W.Stats().rides, 2, "the ride count is the paid trips")
	eq(W.db.totals.rides, 2, "the saved totals are made again")
	eq(W.db.totalsOld and W.db.totalsOld.rides, 3, "the old totals are kept unchanged")
	-- a second load: no new rebuild (the marker), and the backup is not overwritten
	W.db.totals.rides = 7 -- (a sign that a rebuild would be seen)
	local r2 = w:reload(r)
	T.settle(w)
	eq(r2.W.db.totals.rides, 7, "a second load does not rebuild again")
	eq(r2.W.db.totalsOld.rides, 3, "a second load leaves the backup alone")
	T.clean(w)
end)

test("r85: saved data with 100 or more trips and no marker is not rebuilt", function()
	local w = T.newWorld()
	local rows = {}
	for i = 1, 100 do rows[i] = { at = 1700000000 + i, driver = "Anita Lift", dest = "Orgrimmar", price = 50000 } end
	local saved = { Wuber = { progressReady = true, rides = rows,
		totals = { rides = 150, spent = 0, saved = 0, savedValue = 0, places = {}, placeCount = 1, drivers = {} } } }
	local r = T.rider(w, T.TESTCHAR, { saved = saved })
	T.settle(w)
	eq(r.W.Stats().rides, 150, "the lifetime count stays (older trips are no longer saved)")
	eq(r.W.db.totalsOld, nil, "nothing was backed up")
	T.clean(w)
end)
