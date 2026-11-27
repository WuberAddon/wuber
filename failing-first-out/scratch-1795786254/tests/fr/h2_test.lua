local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local clean = T.clean
local ANITA = T.ANITA

-- HUNT-125: a rider who booked from the driver's advert alone (the driver never saw his Q and he
-- never heard a beacon) still learns that the driver shows the ride passphrase.
local function scene(flagFirst)
	local w = T.newWorld({ realm = H.FOUNDER_REALM }) -- the driver is heard on a world that names a realm
	local d = T.driver(w, ANITA)
	local r = T.rider(w)
	w:splitChannel(r, "B") -- another copy of the channel: only whispers reach him
	T.settle(w)
	T.goOnline(d) w:advance(5)
	if flagFirst then d.W.Drive.SetOpt("showPass", true) w:advance(1) end
	ok(r.W.RequestRide("anita lift"), "the rider books")
	-- as if only the advert had found him: the driver has no Q row for him, the rider no beacon flag
	local fb = d.W.Mod("Net.Base").fb
	for k in pairs(fb.riders) do fb.riders[k] = nil end
	r.W.ride.showPass = nil
	r.W.drivers["anita lift"] = nil
	return w, d, r
end

for _, first in ipairs({ true, false }) do
	test("fr h2: a rider with no beacon is told the passphrase flag (flag on " .. (first and "before" or "after") .. " the booking)", function()
		local w, d, r = scene(first)
		if not first then d.W.Drive.SetOpt("showPass", true) end
		local fb = d.W.Mod("Net.Base").fb
		for _ = 1, 70 do for k in pairs(fb.riders) do fb.riders[k] = nil end w:advance(1) end -- he never asks
		eq(r.W.ride and r.W.ride.showPass, true, "the ride knows the driver shows the passphrase")
		clean(w)
	end)
end
