local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local clean = T.clean
local ANITA = T.ANITA

-- HUNT-112: a driver the rider booked through another copy of the channel (another internal
-- realm: only whispers reach them) turns Show ride passphrase on while the rider waits in
-- their group. The rider's ride screen must show the two words, as on the same copy.
local function scene(copy)
	local w = T.newWorld({ realm = H.FOUNDER_REALM }) -- the driver is heard on a world that names a realm
	local d = T.driver(w, ANITA)
	local r = T.rider(w)
	if copy then w:splitChannel(r, copy) end
	T.settle(w)
	T.goOnline(d) w:advance(5)
	ok(r.W.drivers["anita lift"], "control: the rider hears the driver")
	ok(r.W.RequestRide("anita lift"), "control: the rider books")
	w:advance(20)
	return w, d, r
end

local function passLine(r)
	for _, s in ipairs(r:visibleTexts()) do
		if tostring(s):find("Passphrase:", 1, true) then return s end
	end
end

for _, copy in ipairs({ false, "B" }) do
	local where = copy and "another copy of the channel" or "the same channel (control)"
	test("r34 l: the driver turns Show ride passphrase on while the rider waits in the group, on " .. where, function()
		local w, d, r = scene(copy)
		local ride = r.W.ride
		ok(ride and r.W.InGroupWith("anita lift"), "control: the rider is in the driver's group (ride state "
			.. tostring(ride and ride.state) .. ")")
		eq(ride.showPass, nil, "control: no passphrase yet")
		eq(passLine(r), nil, "control: no passphrase line yet")
		d.W.Drive.SetOpt("showPass", true)
		w:advance(70)
		r:slash("/wuber") w:advance(3)
		eq(r.W.ride and r.W.ride.showPass, true, "the rider's ride knows the driver shows the passphrase")
		local line = passLine(r)
		ok(line, "the ride screen shows the passphrase. Visible: " .. T.list(r:visibleTexts()):sub(1, 400))
		local theirs = d.W.Passphrase(r.W.ride.id, r.W.myKey)
		ok(theirs and tostring(line):find(theirs, 1, true), "the same words as the driver's (" .. tostring(theirs) .. "): " .. tostring(line))
		-- and off again: the line goes
		d.W.Drive.SetOpt("showPass", false)
		w:advance(20)
		eq(r.W.ride and r.W.ride.showPass, nil, "the driver turned it off: the ride says so")
		ok(not passLine(r), "the passphrase line has gone")
		clean(w)
	end)
end
