local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("after a /reload mid-ride the driver's live cast (G) is still shown on the ride", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	r.W.db.autoAccept = true
	T.goOnline(d)
	w:advance(5)
	r.W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(6)
	eq(r.W.ride.state, "ingroup", "setup: in the driver's group")
	local id = r.W.ride.id
	-- control: before the reload the tracker is believed
	w:inject(T.ANITA, "G~1~" .. id .. "~c~0~2~Anita Lift~0", "WHISPER", r)
	w:advance(0.5)
	ok(r.W.ride.ritual and r.W.ride.ritual.phase == "c", "control: before the reload a G (cast) is shown on the ride")
	-- the player reloads the UI mid-ride
	local r2 = w:reload(r)
	w:advance(3)
	ok(r2.W.ride and r2.W.ride.id == id, "setup: the ride came back after /reload (state " .. tostring(r2.W.ride and r2.W.ride.state) .. ")")
	w:inject(T.ANITA, "G~1~" .. id .. "~c~0~2~Anita Lift~0", "WHISPER", r2)
	w:advance(0.5)
	ok(r2.W.ride.ritual and r2.W.ride.ritual.phase == "c",
		"after /reload the driver's live cast/summon progress is ignored for the rest of the ride (ride.acceptedAt = " .. tostring(r2.W.ride.acceptedAt) .. ")")
	T.clean(w)
end)
