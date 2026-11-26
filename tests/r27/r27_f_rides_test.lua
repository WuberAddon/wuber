-- r27 group F: rider ride state (Wuber/Net/Rides.lua).
-- AUD-08: the driver's S "invited" whisper beats the game's invite box: auto-accept still runs.
-- AUD-11: a rider already in the driver's group who is dropped sees the declined screen.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- AUD-08 (audit C08b-1)

-- delay the game's PARTY_INVITE_REQUEST at the rider by 'delay' seconds (the driver's S "invited" whisper wins the race)
local function ride(delay)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	r.W.db.autoAccept = true
	T.goOnline(d)
	w:advance(5)
	if delay then
		local orig = r.fire
		r.fire = function(self, ev, ...)
			if ev == "PARTY_INVITE_REQUEST" then
				local args = { ... }
				w:after(delay, function() orig(self, ev, unpack(args)) end, r, "late invite")
				return
			end
			return orig(self, ev, ...)
		end
	end
	r.W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(6)
	return w, r, d
end

test("r27 AUD-08: control: invite request first, then S: auto-accept joins the group", function()
	local w, r = ride(nil)
	ok(r.W.ride.autoAccepted == true, "control: the rider should have been auto-accepted, ride state " .. tostring(r.W.ride.state))
	T.clean(w)
end)

test("r27 AUD-08: driver's S 'invited' whisper arrives before the game's invite popup: auto-accept silently does nothing", function()
	local w, r = ride(0.6)
	ok(r.W.ride.state == "invited" or r.W.ride.state == "ingroup", "setup: state " .. tostring(r.W.ride.state))
	ok(r.W.ride.autoAccepted == true and r.W.InGroup(),
		"auto-accept is on, the driver invited the rider, but the rider was never put in the group (state " .. tostring(r.W.ride.state) ..
		", inviter " .. tostring(r.W.ride.inviter) .. "): the invite popup sits there until the rider clicks it")
	T.clean(w)
end)

-- AUD-11 (audit C08b-2)

local function joined()
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
	return w, r, d
end

test("r27 AUD-11: control: dropped while only invited: the rider is told at once", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	r.W.db.autoAccept = false
	T.goOnline(d)
	w:advance(5)
	r.W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(3)
	eq(r.W.ride.state, "invited", "setup")
	d.W.Drive.Do("DROP", "Wuber TestCharacter")
	w:advance(3)
	eq(r.W.ride.state, "declined", "control: an invited rider whose driver drops them sees the ride declined")
	T.clean(w)
end)

test("r27 AUD-11: rider already in the group is dropped by the driver: Wuber keeps saying 'Waiting for the portal'", function()
	local w, r, d = joined()
	eq(r.W.ride.state, "ingroup", "setup: rider joined the group")
	d.W.Drive.Do("DROP", "Wuber TestCharacter")
	w:advance(3)
	ok(#w:messages("N", T.ANITA, "WHISPER") >= 1, "setup: the driver did send N (decline) to the rider")
	ok(r.W.ride.state == "declined", "the driver dropped the rider and sent N, but the rider's ride still says '" .. tostring(r.W.ride.state) .. "' (waits up to 10 min) instead of declined")
	T.clean(w)
end)

test("r27 AUD-11: a late decline once the summon is cast is not believed, nor one from anyone but the driver", function()
	local w, r, d = joined()
	local b = T.rider(w, T.BEA, { spot = "Orgrimmar" })
	T.settle(w)
	eq(r.W.ride.state, "ingroup", "setup: rider joined the group")
	local id = r.W.ride.id
	b.W.SendTo("Wuber TestCharacter", "N", id, "busy")
	w:advance(3)
	eq(r.W.ride.state, "ingroup", "an N from someone who is not this ride's driver is ignored")
	r.W.ride.state = "portal"
	d.W.SendTo("Wuber TestCharacter", "N", id, "busy")
	w:advance(3)
	eq(r.W.ride.state, "portal", "the portal is up: a late N from the driver does not end the ride")
	T.clean(w)
end)

test("r27 AUD-08: a stranger's invite after the driver's S 'invited' is not auto-accepted", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	r.W.db.autoAccept = true
	T.goOnline(d)
	w:advance(5)
	-- the driver's invite never reaches the rider: only the S whisper does
	local orig = r.fire
	r.fire = function(self, ev, ...)
		if ev == "PARTY_INVITE_REQUEST" then return end
		return orig(self, ev, ...)
	end
	r.W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(6)
	eq(r.W.ride.state, "invited", "setup: the S 'invited' whisper moved the ride on")
	r.fire = orig
	local accepted = 0
	local was = r.W.Try
	r.W.Try = function(what, fn, ...)
		if what == "accept" then accepted = accepted + 1 end
		return was(what, fn, ...)
	end
	r:fire("PARTY_INVITE_REQUEST", "Bob Stranger")
	eq(accepted, 0, "a stranger's invite is never accepted for the rider")
	ok(r.W.ride.autoAccepted ~= true, "not marked auto-accepted")
	r.W.Try = was
	T.clean(w)
end)
