local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local ANITA, TESTCHAR = T.ANITA, T.TESTCHAR

-- Anita (Net only) takes Wuber's ride; with paid, Wuber pays the whole fare by a completed trade
-- while in her group; with failed, the ride then ends before he arrives (Wuber cancels)
local function paidRide(opts)
	opts = opts or {}
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { netOnly = true })
	local r = T.rider(w, TESTCHAR, { money = 100000 })
	r.W.VERSION = "2.3.0"
	T.settle(w)
	T.goOnline(d)
	local ride = r.W.RequestRide("anita lift")
	w:advance(1)
	ok(d.W.AcceptRequest(ride.id, 5), "accepted")
	w:group({ ANITA, TESTCHAR })
	w:advance(1)
	eq(r.W.ride.state, "ingroup", "in the group")
	w:move(ANITA, "Orgrimmar") -- (a trade needs them side by side)
	w:advance(1)
	if opts.paid ~= false then
		ok(w:openTrade(w:player(ANITA), w:player(TESTCHAR)), "a trade opens")
		w:tradeMoney(w:player(TESTCHAR), opts.pay or ride.price)
		w:tradeAccept(w:player(ANITA))
		w:tradeAccept(w:player(TESTCHAR))
		w:advance(1)
	end
	if opts.failed ~= false then
		w:advance(5)
		ok(r.W.CancelRide(), "the ride ends before arrival")
		w:advance(1)
	end
	return w, d, r, ride
end

test("r33 e2 AUD-41: a raincheck ask that never went out must not use up the rider's one ask", function()
	local w, d, r, ride = paidRide()
	eq(r.W.Raincheck.CanAsk(ride.id), true, "control: a paid ride that failed may ask")
	-- this account can't send right now (Transport drops everything but a probe every 5 min)
	r.W.net.cantSend = true
	r.W.net.probeAt = 1e12
	local sent = r.W.Raincheck.Ask(ride.id)
	eq(sent, false, "control: the ask did not go out (the Done screen says Couldn't ask right now)")
	w:advance(1)
	eq(#T.msgs(w, "V", TESTCHAR), 0, "control: no V message was sent")
	-- sending works again
	r.W.net.cantSend = false
	r.W.net.probeAt = 0
	local can, why = r.W.Raincheck.CanAsk(ride.id)
	ok(can == true, "no ask ever reached the driver, yet the rider is now told '" .. tostring(why) .. "' and the Ask for a raincheck button is gone for this ride")
	if r.W.UI and r.W.UI.RaincheckAskable then
		ok(r.W.UI.RaincheckAskable({ id = ride.id, raw = r.W.ride }) == true, "the Ask for a raincheck button stays hidden")
	end
	T.clean(w)
end)
