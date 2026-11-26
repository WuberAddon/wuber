local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function doneRide(w, d, r)
	r.W.db.autoAccept = false
	r.W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(1)
	r.W.UI.Toggle(true)
	w:advance(2.5)
	r:clickText("Accept invite")
	w:advance(1)
	w:summon(d, T.TESTCHAR)
	w:advance(1)
	r:clickText("Accept summon")
	w:advance(3)
	w:openTrade(d, r)
	w:advance(0.5)
	w:tradeMoney(r, 5000)
	w:tradeAccept(d)
	w:tradeAccept(r)
	w:advance(1)
end

test("r32 p3: C08b-6: control: a finished ride that was never rated comes back after /reload (so it can be rated)", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w) T.goOnline(d) w:advance(5)
	doneRide(w, d, r)
	eq(r.W.ride.state, "done", "setup")
	local r2 = w:reload(r)
	w:advance(3)
	ok(r2.W.ride and r2.W.ride.state == "done", "control: unrated done ride restored")
	T.clean(w)
end)

test("r32 p3: C08b-6: an already rated finished ride is brought back by /reload as the Done screen again", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w) T.goOnline(d) w:advance(5)
	doneRide(w, d, r)
	eq(r.W.ride.state, "done", "setup")
	ok(r.W.Rate(5), "rated")
	local r2 = w:reload(r)
	w:advance(3)
	ok(r2.W.ride == nil, "the rider already rated and reloaded, but the finished ride (state " .. tostring(r2.W.ride and r2.W.ride.state) ..
		", rated " .. tostring(r2.W.ride and r2.W.ride.rated) .. ") is restored instead of being cleared")
	T.clean(w)
end)

-- The rider is in combat the whole time; the driver's invite only reaches the game after 'wait' seconds
-- (S is dropped, so it is the game's own PARTY_INVITE_REQUEST that moves the ride to 'invited').
-- The rider leaves combat at t = 'leave' and never accepts the invite. Returns the seconds left on the
-- 'invited' limit 2 s after leaving combat.
local function failAfterLeaving(wait, leave)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	r.W.db.autoAccept = false
	T.goOnline(d)
	w:advance(5)
	w.drop = { S = 100 }
	local orig = r.fire
	r.fire = function(self, ev, ...)
		if ev == "PARTY_INVITE_REQUEST" then
			local args = { ... }
			w:after(wait, function() orig(self, ev, unpack(args)) end, r, "late invite")
			return
		end
		return orig(self, ev, ...)
	end
	r.W.RequestRide("anita lift")
	w:advance(0.2)
	w:enterCombat(r)
	T.take(d)
	local t = 0
	while t < leave do w:advance(1) t = t + 1 end
	eq(r.W.ride.state, "invited", "setup: invited while still in combat")
	w:leaveCombat(r)
	w:advance(2)
	local rr = r.W.ride
	return (rr.changed + 60) - r.env.GetTime(), w -- seconds from now until the 60 s 'invited' limit fires (about 58 when the clock is right)
end

test("r32 p3: C08b-7: control: invite arrives at once, rider leaves combat 10 s later: the 60 s invited limit runs from leaving combat", function()
	local after, w = failAfterLeaving(1, 10)
	ok(after >= 50 and after <= 62, "control: the invited limit fires in " .. math.floor(after) .. " s")
	T.clean(w)
end)

test("r32 p3: C08b-7: 'accepted' held in combat 40 s, then invited: the 60 s invited clock also counts the time held before", function()
	local after, w = failAfterLeaving(40, 50)
	-- invited at ~40, still in combat until 50: only 0 s of the 'invited' clock has run when combat ends
	ok(after <= 62, "the rider left combat and has not answered the invite: it should fail in about 58 s, but the limit is " .. math.floor(after) .. " s away (the 40 s spent held in 'accepted' were added to the 'invited' state's clock)")
	T.clean(w)
end)
