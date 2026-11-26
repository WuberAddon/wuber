local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- a rider drains the send burst (4), queues a shared-flight-price F (waits for a full burst),
-- then 0.5 s later queues a ride message. Returns the seconds the ride message waited.
local function run(withF)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	w:addBot("Pingbot", { spot = "Orgrimmar" })
	T.settle(w)
	w:advance(30) -- bucket full
	local TM = r.W.Mod("Net.Transport")
	for i = 1, 4 do r.W.SendTo("Pingbot", "C", "burst" .. i) end
	if withF then TM.enqueue("WHISPER", "Pingbot", "F", "F~1~x~y", nil, nil) end
	w:advance(0.5)
	local t0 = r.env.GetTime()
	local tsent
	r.W.SendTo("Pingbot", "C", "ride")
	for step = 1, 80 do
		w:advance(0.1)
		for _, e in ipairs(w:messages("C", r.player.name)) do
			if e.text:find("ride", 1, true) then tsent = tsent or r.env.GetTime() end
		end
		if tsent then break end
	end
	return w, tsent and (tsent - t0) or nil, r
end

test("r33 m AUD-32: control: a ride message sent half a second after the burst goes out in about a second", function()
	local w, waited = run(false)
	ok(waited and waited <= 1.5, "control: waited " .. tostring(waited))
	T.clean(w)
end)

test("r33 m AUD-32: a ride message waits about 4 s behind a queued shared-flight-price message", function()
	local w, waited, r = run(true)
	ok(waited and waited <= 1.5, "the ride message (R/A/S/C) should go in about a second as the token refills, but waited " .. tostring(waited) .. " s behind the shared flight price")
	T.clean(w)
end)

local function setup(failAccept)
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
	w:advance(2)
	r.W.UI.Toggle(true) w:advance(2.5)
	if failAccept then r.env.AcceptGroup = function() error("ADDON_ACTION_BLOCKED") end end
	return w, r, d
end

test("r33 m AUD-33: control: Accept invite joins the group and the box goes", function()
	local w, r = setup(false)
	ok(r.popups.PARTY_INVITE ~= nil, "setup: the game's invite box should be showing, ride " .. tostring(r.W.ride.state))
	local hit = r:clickText("Accept invite")
	w:advance(1)
	ok(r.W.InGroup(), "control: should be in the group, clicked=" .. tostring(hit))
	T.clean(w)
end)

test("r33 m AUD-33: AcceptGroup fails: Wuber hides the game's invite box anyway, so the rider cannot accept", function()
	local w, r = setup(true)
	ok(r.popups.PARTY_INVITE ~= nil, "setup: the game's invite box should be showing, ride " .. tostring(r.W.ride.state))
	r:clickText("Accept invite")
	w:advance(1)
	ok(not r.W.InGroup(), "setup: AcceptGroup failed so not in group")
	ok(r.popups.PARTY_INVITE ~= nil, "AcceptGroup failed and Wuber said 'Click Accept on the invite window', but the game's invite window is gone (hidden by Wuber): no way left to accept")
end)