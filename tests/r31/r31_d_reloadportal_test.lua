local T = ...
-- Round 31 group D (HUNT-06): a /reload while the summon is up does not play the full-screen portal
-- again; a ride that was only asked for before the reload still plays it when the portal opens later.
local test, eq, ok = T.test, T.eq, T.ok

local function setup()
	local w = T.newWorld()
	local d = T.driver(w, "Anita Lift")
	local r = T.rider(w)
	T.settle(w)
	T.goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(2)
	if not w:player(T.TESTCHAR).group then
		w.hardware = r
		r.W.AcceptInvite()
		w.hardware = nil
		w:advance(1)
	end
	return w, d, r
end

test("reload at the portal: the full-screen portal does not play again", function()
	local w, d, r = setup()
	w:summon(d, T.TESTCHAR)
	w:advance(1)
	eq(r.W.ride and r.W.ride.state, "portal", "the summon is up")
	w:advance(5)
	local r2 = w:reload(r)
	w:advance(0.2)
	eq(r2.W.ride and r2.W.ride.state, "portal", "ride restored at the portal")
	eq(r2.W.FX.Stats().playing, 0, "no effect playing after the reload")
end)

test("reload when only accepted: the portal still plays when it opens later", function()
	local w, d, r = setup()
	local r2 = w:reload(r)
	w:advance(0.2)
	ok(r2.W.ride and r2.W.ride.state ~= "portal", "ride restored before the portal")
	w:summon(d, T.TESTCHAR)
	w:advance(1)
	eq(r2.W.ride and r2.W.ride.state, "portal", "the summon is up")
	ok(r2.W.FX.Stats().playing > 0, "the portal plays")
end)
