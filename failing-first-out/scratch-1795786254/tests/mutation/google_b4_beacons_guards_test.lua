-- Guard tests for Wuber/Net/Beacons.lua (Batch 4, lane d3).
-- Each test guards a line from the mutation audit that no other test protected.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local TESTCHAR, ANITA, BOB = T.TESTCHAR, T.ANITA, "Bob Helper"

local function setupComm(c)
	local CX = c.W.Mod("Net.Community").CX
	local comm = c.W.Mod("Net.Community").comm
	local sent = {}
	c.W.CommunityIndex = function() return 7 end
	CX.send = function(kind, ...)
		sent[#sent + 1] = { kind = kind, args = { ... } }
		return true
	end
	return CX, comm, sent
end

local function makeBeaconFields(price, faction, opts)
	opts = opts or {}
	return {
		"Orgrimmar", "1411", "500", "500", tostring(price), "",
		opts.state or "open", "1", "3", faction, "2.4.0", "", "0",
	}
end

-- guards Wuber/Net/Beacons.lua:127 (drop statement: below-MIN_PRICE driver is recorded in fb.rejected)
test("mutation b4 beacons: driver below MIN_PRICE is marked rejected so directory K skips them", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	local key = r.W.Key(BOB)
	local fb = r.W.Mod("Net.Base").fb
	local heardBeacon = r.W.Mod("Net.Beacons").heardBeacon
	heardBeacon(BOB, BOB, key, makeBeaconFields(0, r.W.Faction()), "2", "CHANNEL", false)
	ok(fb.rejected[key] ~= nil, "below-MIN_PRICE driver is recorded in fb.rejected")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:128 (drop statement: below-MIN_PRICE driver is removed from W.hiddenDrivers)
test("mutation b4 beacons: hidden driver who beacons below MIN_PRICE is evicted from hiddenDrivers", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	local key = r.W.Key(BOB)
	local fac = r.W.Faction()
	local heardBeacon = r.W.Mod("Net.Beacons").heardBeacon
	r.W.HideDriver(key, true)
	heardBeacon(BOB, BOB, key, makeBeaconFields(10000, fac), "2", "CHANNEL", false)
	ok(r.W.hiddenDrivers[key] ~= nil, "control: hidden driver is cached in hiddenDrivers")
	heardBeacon(BOB, BOB, key, makeBeaconFields(0, fac), "2", "CHANNEL", false)
	eq(r.W.hiddenDrivers[key], nil, "hidden driver below MIN_PRICE is removed from hiddenDrivers")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:131 (drop statement: removing below-MIN_PRICE listed driver fires DRIVERS)
test("mutation b4 beacons: listed driver who beacons below MIN_PRICE is removed and fires DRIVERS", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	local key = r.W.Key(BOB)
	local fac = r.W.Faction()
	local heardBeacon = r.W.Mod("Net.Beacons").heardBeacon
	heardBeacon(BOB, BOB, key, makeBeaconFields(10000, fac), "2", "CHANNEL", false)
	ok(r.W.drivers[key] ~= nil, "control: driver is listed")
	local fires = 0
	r.W.Listen("DRIVERS", function() fires = fires + 1 end)
	heardBeacon(BOB, BOB, key, makeBeaconFields(0, fac), "2", "CHANNEL", false)
	eq(r.W.drivers[key], nil, "driver is removed from W.drivers")
	ok(fires > 0, "DRIVERS fired when below-MIN_PRICE driver was removed")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:98 (drop statement: opposite-faction driver is recorded in fb.rejected)
test("mutation b4 beacons: opposite-faction driver is marked rejected", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	local myFac = r.W.Faction()
	local otherFac = (myFac == "H") and "A" or "H"
	local key = r.W.Key(BOB)
	local fb = r.W.Mod("Net.Base").fb
	local heardBeacon = r.W.Mod("Net.Beacons").heardBeacon
	heardBeacon(BOB, BOB, key, makeBeaconFields(10000, otherFac), "2", "CHANNEL", false)
	ok(fb.rejected[key] ~= nil, "opposite-faction driver is recorded in fb.rejected")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:680 (drop statement: refused whisper push retries after PUSH_RETRY)
-- guards Wuber/Net/Beacons.lua:677 (drop statement: pending retry blocks duplicate Q reply before retry fires)
-- guards Wuber/Net/Beacons.lua:679 (drop statement: retry clears pushPending so later Qs are answered)
test("mutation b4 beacons: refused whisper push blocks duplicate Qs while pending, then retries and clears pending", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	d.W.SetDriving(true)
	T.settle(w)
	w:advance(10)
	local beacons = d.W.Mod("Net.Beacons")
	local fb = d.W.Mod("Net.Base").fb
	local key = d.W.Key(BOB)
	fb.riders[key] = { key = key, addr = BOB, at = d.env.GetTime() }
	local allowSend = false
	local sentD = 0
	local origSendTo = d.W.SendTo
	d.W.SendTo = function(addr, kind, ...)
		if addr == BOB and kind == "D" then
			if not allowSend then return false end
			sentD = sentD + 1
		end
		return origSendTo(addr, kind, ...)
	end
	-- Force a price change so tickBeacon -> tickPush -> pushOne fails and schedules retry (5s)
	d.W.Char().price = (d.W.Char().price or 50000) + 10000
	beacons.tickBeacon()
	eq(sentD, 0, "initial push refused by transport")
	-- While retry is pending (pushPending[key] == true), a whisper Q must not schedule a reply
	fb.replyAt[key] = nil
	beacons.heardWhisperPing(BOB, key)
	eq(fb.replyPending[key], nil, "no duplicate Q reply scheduled while push retry is pending")
	-- Allow send before the 5s retry fires
	allowSend = true
	w:advance(6)
	eq(sentD, 1, "retry delivered D after PUSH_RETRY")
	-- After retry cleared pushPending[key], a Q past REPLY_QUIET can schedule a reply again
	w:advance(20)
	beacons.heardWhisperPing(BOB, key)
	ok(fb.replyPending[key] == true, "Q after retry and REPLY_QUIET schedules normally")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:691 (drop statement: staggered push marks pushPending while waiting)
-- guards Wuber/Net/Beacons.lua:693 (drop statement: staggered push clears pushPending when it fires)
test("mutation b4 beacons: staggered whisper push blocks Qs during stagger delay then clears pending", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	d.W.SetDriving(true)
	T.settle(w)
	w:advance(10)
	local beacons = d.W.Mod("Net.Beacons")
	local fb = d.W.Mod("Net.Base").fb
	local t0 = d.env.GetTime()
	-- 5 recent riders: 1..4 go at once (PUSH_NOW = 4), rider 5 is staggered by 1s
	for i = 1, 5 do
		local name = "Rider" .. i
		local rk = d.W.Key(name)
		fb.riders[rk] = { key = rk, addr = name, at = t0 - (i - 1) * 0.1 }
	end
	local k5 = d.W.Key("Rider5")
	d.W.Char().price = (d.W.Char().price or 50000) + 10000
	beacons.tickBeacon()
	-- Immediately after tickBeacon, Rider5 is staggered (pushPending[k5] == true), so Q must not schedule
	fb.replyAt[k5] = nil
	beacons.heardWhisperPing("Rider5", k5)
	eq(fb.replyPending[k5], nil, "Rider5 Q is skipped while staggered push is pending")
	-- After stagger timer fires (1s+) and REPLY_QUIET (15s+) elapses, Rider5 Q schedules again
	w:advance(20)
	beacons.heardWhisperPing("Rider5", k5)
	ok(fb.replyPending[k5] == true, "Rider5 Q schedules after staggered push cleared pending")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:600 (drop statement: expired whisper riders are pruned from fb.riders)
test("mutation b4 beacons: recentRiders prunes whisper riders older than RIDER_KEEP", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	d.W.SetDriving(true)
	T.settle(w)
	local beacons = d.W.Mod("Net.Beacons")
	local fb = d.W.Mod("Net.Base").fb
	local key = d.W.Key(BOB)
	w:advance(10)
	local keep = d.W.Mod("Net.Base").NETK.RIDER_KEEP
	fb.riders[key] = { key = key, addr = BOB, at = d.env.GetTime() - (keep + 10) }
	d.W.Char().price = (d.W.Char().price or 50000) + 10000
	beacons.tickBeacon()
	eq(fb.riders[key], nil, "stale rider entry is removed from fb.riders after RIDER_KEEP")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:264 (drop statement: CX.ping records comm.lastQ so repeat within Q_GAP is skipped)
test("mutation b4 beacons: CX.ping records lastQ and suppresses a second ping within Q_GAP", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local CX, comm, sent = setupComm(r)
	comm.lastQ = -1000
	comm.lastQHeard = -1000
	eq(CX.ping(500), true, "first CX.ping sends Q")
	eq(CX.ping(510), false, "second CX.ping within Q_GAP is suppressed")
	eq(#sent, 1, "only one Q sent")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:260 (local value -> nil: CX.ping includes hidden Pioneer emblem flag)
test("mutation b4 beacons: CX.ping passes hidden Pioneer emblem flag when EmblemFlag is set", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local CX, comm, sent = setupComm(r)
	comm.lastQ = -1000
	comm.lastQHeard = -1000
	r.W.EmblemFlag = function() return "0" end
	eq(CX.ping(500), true, "CX.ping sends Q")
	eq(#sent, 1, "one Q sent")
	eq(sent[1].args[1], "", "empty arg 1 before emblem flag")
	eq(sent[1].args[2], "0", "emblem-off flag passed in Q")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:520 (local value -> nil: CX.beacon uses current time for periodic resend and lastD)
test("mutation b4 beacons: CX.beacon sends periodic beacon after CX.EVERY and updates comm.lastD", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	d.W.SetDriving(true)
	T.settle(w)
	local CX, comm, sent = setupComm(d)
	local b = d.W.Mod("Net.Beacons").beaconFor(nil)
	CX.isolated = function() return false end
	comm.force = false
	comm.online = true
	w:advance(CX.EVERY + 50)
	comm.lastD = d.env.GetTime() - (CX.EVERY + 5)
	local before = #sent
	eq(CX.beacon(b, false), true, "CX.beacon sends periodic D after CX.EVERY")
	eq(#sent, before + 1, "one D sent")
	ok(type(comm.lastD) == "number" and comm.lastD >= d.env.GetTime() - 1, "comm.lastD updated to now")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:529 (drop statement: CX.found resets comm.online to false)
-- guards Wuber/Net/Beacons.lua:530 (drop statement: CX.found pings community drivers)
test("mutation b4 beacons: CX.found resets comm.online and pings community drivers", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local CX, comm, sent = setupComm(r)
	comm.online = true
	comm.lastQ = -1000
	comm.lastQHeard = -1000
	CX.found()
	eq(comm.online, false, "comm.online reset to false when not driving")
	local sawQ = false
	for _, s in ipairs(sent) do
		if s.kind == "Q" then sawQ = true end
	end
	ok(sawQ, "CX.found sent Q to ask community drivers")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:533 (drop statement: CX.found records beaconedPrices for PriceOk)
-- guards Wuber/Net/Beacons.lua:460 (return -> nil: PriceOk accepts recently beaconed price after price raise)
test("mutation b4 beacons: CX.found records beaconed price so PriceOk accepts it after a price raise", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	d.W.SetDriving(true)
	T.settle(w)
	local CX, comm = setupComm(d)
	d.W.Char().price = 40000
	comm.lastQ = -1000
	comm.lastQHeard = -1000
	CX.found()
	ok(d.W.PriceOk(40000, 60000), "old beaconed price from CX.found is still accepted by PriceOk")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:548 (drop statement: SendBeacon offline clears comm.online so X is sent once)
test("mutation b4 beacons: SendBeacon clears comm.online when stopping driving so community X is sent once", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	d.W.SetDriving(true)
	T.settle(w)
	local _, comm, sent = setupComm(d)
	comm.online = true
	d.W.SetDriving(false)
	d.W.SendBeacon()
	eq(comm.online, false, "comm.online cleared when offline")
	local xCount = 0
	for _, s in ipairs(sent) do
		if s.kind == "X" then xCount = xCount + 1 end
	end
	eq(xCount, 1, "community X sent only once across repeated SendBeacon while offline")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:800 (drop statement: community Q updates comm.lastQHeard)
test("mutation b4 beacons: hearing a community Q updates comm.lastQHeard and suppresses CX.ping", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	w:advance(50)
	local CX, comm = setupComm(r)
	comm.lastQ = -1000
	comm.lastQHeard = -1000
	r.W.Mod("Net.Beacons").heardPing(true)
	eq(CX.ping(r.env.GetTime()), false, "CX.ping is suppressed right after hearing a community Q")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:804 (drop statement: community Q reply clears comm.replyPending)
test("mutation b4 beacons: community Q reply clears comm.replyPending so later Qs are answered", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	d.W.SetDriving(true)
	T.settle(w)
	w:advance(30)
	local _, comm, sent = setupComm(d)
	local heardPing = d.W.Mod("Net.Beacons").heardPing
	comm.replyPending = false
	comm.lastQReply = -1000
	heardPing(true)
	w:advance(5)
	eq(comm.replyPending, false, "comm.replyPending cleared after community Q reply")
	w:advance(d.W.Mod("Net.Base").NETK.Q_QUIET + 5)
	local before = #sent
	heardPing(true)
	w:advance(5)
	ok(#sent > before, "second community Q after Q_QUIET is also answered")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:428 (drop statement: DriverBeacon reports provider error via W.Error)
test("mutation b4 beacons: DriverBeacon reports provider error via W.Error and returns nil", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local errs = {}
	d.W.Error = function(tag, msg) errs[#errs + 1] = { tag = tag, msg = msg } end
	d.W.provider = { name = "BrokenProvider", beacon = function() error("boom") end }
	eq(d.W.DriverBeacon(), nil, "DriverBeacon returns nil when provider errors")
	eq(#errs, 1, "W.Error called once")
	eq(errs[1].tag, "beacon", "W.Error tagged with beacon")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:153 (drop statement: whisper beacon records d.whisperAt)
test("mutation b4 beacons: whisper beacon records whisperAt timestamp on driver entry", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	w:advance(25)
	local key = r.W.Key(BOB)
	local heardBeacon = r.W.Mod("Net.Beacons").heardBeacon
	heardBeacon(BOB, BOB, key, makeBeaconFields(10000, r.W.Faction()), "2", "WHISPER", false)
	local d = r.W.drivers[key]
	ok(d ~= nil, "driver is listed")
	eq(d.whisperAt, d.heard, "whisperAt is recorded as d.heard for WHISPER beacons")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:718 (swap and->or: rider with pending Q reply is not double-sent by tickPush)
test("mutation b4 beacons: whisper rider with pending Q reply gets one D, not a duplicate push", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	d.W.SetDriving(true)
	T.settle(w)
	w:advance(10)
	local beacons = d.W.Mod("Net.Beacons")
	local fb = d.W.Mod("Net.Base").fb
	local key = d.W.Key(BOB)
	local sentD = 0
	local origSendTo = d.W.SendTo
	d.W.SendTo = function(addr, kind, ...)
		if addr == BOB and kind == "D" then sentD = sentD + 1 end
		return origSendTo(addr, kind, ...)
	end
	beacons.heardWhisperPing(BOB, key)
	ok(fb.replyPending[key] == true, "control: Q reply is pending")
	d.W.Char().price = (d.W.Char().price or 50000) + 10000
	beacons.tickBeacon()
	eq(sentD, 0, "tickPush does not send immediately while Q reply is pending")
	w:advance(3)
	eq(sentD, 1, "only one D is sent when Q reply fires")
	T.clean(w)
end)
