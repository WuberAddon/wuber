-- Guard tests for Wuber/Net/Rides.lua.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local TESTCHAR, ANITA, BOB = T.TESTCHAR, T.ANITA, "Bob Helper"

-- guards Wuber/Net/Rides.lua:150 (drop statement: fb.riders[key] = nil)
test("mutation b5 rides: offline system error drops rider from beacon whisper list", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar", price = 5000 })
	w:addBot(BOB, { spot = "Ratchet" })
	T.settle(w)
	d.W.fallback.riders["bob helper"] = { key = "bob helper", addr = BOB, at = d.W.Now() }
	d.W.SendTo(BOB, "P", "test")
	w:advance(1)
	-- Driver whispered to Bob, so whisperedRecently("bob helper") is true.
	d:fire("CHAT_MSG_SYSTEM", "No player named 'Bob Helper' is currently playing.")
	eq(d.W.Drive.HasWuber(BOB), nil, "offline rider is dropped from fb.riders")
	T.clean(w)
end)

-- guards Wuber/Net/Rides.lua:307 (drop statement: W.ride = nil)
-- guards Wuber/Net/Rides.lua:308 (drop statement: persist(nil))
test("mutation b5 rides: ClearRide clears W.ride and saved W.db.ride", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	r.W.ride = { id = "AbCdEf", state = "done", driver = ANITA, driverKey = "anita lift" }
	r.W.db.ride = { id = "AbCdEf", state = "done" }
	r.W.ClearRide()
	eq(r.W.ride, nil, "W.ride is cleared")
	eq(r.W.db.ride, nil, "W.db.ride is cleared")
	T.clean(w)
end)

-- guards Wuber/Net/Rides.lua:322 (swap and->or: local dest = (d.destOk and d.destWire) or d.dest)
-- guards Wuber/Net/Rides.lua:323 (return -> nil: return "WTB summon to " ..)
test("mutation b5 rides: RequestWhisper uses display dest when destWire is unwhitelisted", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	r.W.drivers["anita lift"] = {
		name = ANITA,
		dest = "Orgrimmar",
		destWire = "BadCustomWire",
		destOk = false,
		price = 5000,
	}
	local text, to = r.W.RequestWhisper("anita lift")
	eq(text, "WTB summon to Orgrimmar for 50s", "falls back to d.dest when destOk is false")
	eq(to, "Anita-Lift", "returns macro target name")
	T.clean(w)
end)

-- guards Wuber/Net/Rides.lua:329 (swap and->or: if not (text and to) then return nil end)
-- guards Wuber/Net/Rides.lua:330 (return -> nil: return "/w " .. to .. " " .. text)
test("mutation b5 rides: RequestMacro returns /w macro for valid driver and nil when name is missing", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	r.W.drivers["anita lift"] = { name = ANITA, dest = "Orgrimmar", price = 5000 }
	eq(r.W.RequestMacro("anita lift"), "/w Anita-Lift WTB summon to Orgrimmar for 50s", "builds /w macro")
	r.W.drivers["nameless"] = { name = "", dest = "Orgrimmar", price = 5000 }
	eq(r.W.RequestMacro("nameless"), nil, "returns nil when driver name produces no macro target")
	T.clean(w)
end)

-- guards Wuber/Net/Rides.lua:395 (cmp ==->~=: local heard = type(d) == "table" and tonumber(d.heard))
-- guards Wuber/Net/Rides.lua:396 (cmp >-><=: if heard and heard > at then at = heard end)
-- guards Wuber/Net/Rides.lua:397 (return -> nil: return at)
-- guards Wuber/Net/Rides.lua:553 (cmp ==->~=: if r.state == "accepted" and r.position then)
test("mutation b5 rides: queued accepted ride uses driver beacon heard time to stay alive", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local t0 = r.W.Now()
	r.W.drivers["anita lift"] = { name = ANITA, dest = "Orgrimmar", price = 5000, heard = t0 + 80 }
	r.W.ride = {
		id = "AbCdEf",
		state = "accepted",
		position = 2,
		driver = ANITA,
		driverKey = "anita lift",
		addr = ANITA,
		at = t0,
		changed = t0,
	}
	-- Advance past QUEUE_SILENCE (150s) from t0, but within 150s of driver's heard (t0 + 80).
	w:advance(160)
	eq(r.W.ride.state, "accepted", "queued ride stays alive while driver beacon was heard recently")
	-- Advance past 150s from driver's heard (t0 + 80 + 150 = t0 + 230).
	w:advance(80)
	eq(r.W.ride.state, "failed", "queued ride times out to failed after silence from driver")
	T.clean(w)
end)

-- guards Wuber/Net/Rides.lua:396 (cmp >-><=: older driver heard does not shorten queue timeout)
test("mutation b5 rides: older driver beacon heard time does not override newer ride change", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local t0 = r.W.Now()
	r.W.drivers["anita lift"] = { name = ANITA, dest = "Orgrimmar", price = 5000, heard = t0 - 80 }
	r.W.ride = {
		id = "AbCdEf",
		state = "accepted",
		position = 1,
		driver = ANITA,
		driverKey = "anita lift",
		addr = ANITA,
		at = t0,
		changed = t0,
	}
	w:advance(30)
	eq(r.W.ride.state, "accepted", "older driver.heard does not cause premature timeout")
	T.clean(w)
end)

-- guards Wuber/Net/Rides.lua:517 (drop statement: r.arrivedZone = zone)
-- guards Wuber/Net/Rides.lua:519 (return -> nil: return W.EndRide("auto"))
test("mutation b5 rides: leaving the arrival zone ends an arrived ride automatically", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local t0 = r.W.Now()
	r.W.ride = {
		id = "AbCdEf",
		state = "arrived",
		driver = ANITA,
		driverKey = "anita lift",
		addr = ANITA,
		dest = "Orgrimmar",
		price = 0,
		at = t0,
		changed = t0,
	}
	r.W.CheckRide()
	eq(r.W.ride.arrivedZone, "Orgrimmar", "records arrival zone while standing at dest")
	w:move(TESTCHAR, "Ratchet")
	r.W.CheckRide()
	eq(r.W.ride.state, "done", "leaving arrival zone ends the ride")
	eq(r.W.ride.endedBy, "auto", "ride endedBy is auto")
	T.clean(w)
end)

-- guards Wuber/Net/Rides.lua:530 (swap and->or: if r.state == "requesting" and not r.resent)
test("mutation b5 rides: CheckRide does not resend R once ride is accepted", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local t0 = r.W.Now()
	r.W.ride = {
		id = "AbCdEf",
		state = "accepted",
		driver = ANITA,
		driverKey = "anita lift",
		addr = ANITA,
		dest = "Orgrimmar",
		price = 5000,
		at = t0 - 20,
		changed = t0 - 20,
	}
	local mark = #w.addonLog
	r.W.CheckRide()
	w:advance(1)
	local sentR = 0
	for i = mark + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.prefix == "WUBER" and e.from == TESTCHAR and e.chatType == "WHISPER"
			and tostring(e.text):match("^R~") then
			sentR = sentR + 1
		end
	end
	eq(sentR, 0, "accepted ride never resends R")
	T.clean(w)
end)

-- guards Wuber/Net/Rides.lua:674 (swap and->or: if W.ride == r and r.state == "ingroup" and not W.InGroup())
test("mutation b5 rides: CANCEL_SUMMON keeps ingroup state when rider stays in group", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	local r = T.rider(w, TESTCHAR, { spot = "Ratchet" })
	T.settle(w)
	w:group({ ANITA, TESTCHAR })
	local t0 = r.W.Now()
	r.W.ride = {
		id = "AbCdEf",
		state = "portal",
		driver = ANITA,
		driverKey = "anita lift",
		addr = ANITA,
		dest = "Orgrimmar",
		price = 5000,
		at = t0,
		changed = t0,
	}
	r:fire("CANCEL_SUMMON")
	eq(r.W.ride.state, "ingroup", "immediately returns to ingroup while still grouped")
	local firedAfter = 0
	r.W.Listen("RIDE", function() firedAfter = firedAfter + 1 end)
	w:advance(0.4)
	eq(r.W.ride.state, "ingroup", "stays ingroup after delayed check when still in group")
	eq(firedAfter, 0, "does not fire RIDE again when still in group")
	T.clean(w)
end)

-- guards Wuber/Net/Rides.lua:721 (drop statement: r.autoLeft = true)
-- guards Wuber/Net/Rides.lua:722 (cmp ==->~=: if r == W.ride then fireRide(r) end)
test("mutation b5 rides: AutoLeave sets autoLeft and fires RIDE when leaving the driver group", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	local r = T.rider(w, TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	w:group({ ANITA, TESTCHAR })
	local t0 = r.W.Now()
	local ride = {
		id = "AbCdEf",
		state = "done",
		driver = ANITA,
		driverKey = "anita lift",
		addr = ANITA,
		dest = "Orgrimmar",
		price = 5000,
		at = t0,
		changed = t0,
	}
	r.W.ride = ride
	local fired = 0
	r.W.Listen("RIDE", function() fired = fired + 1 end)
	eq(r.W.AutoLeave(ride), true, "AutoLeave queues leave")
	w:advance(4)
	eq(ride.autoLeft, true, "autoLeft is marked true after leaving")
	ok(fired >= 1, "RIDE event fires when W.ride is auto-left")
	T.clean(w)
end)
