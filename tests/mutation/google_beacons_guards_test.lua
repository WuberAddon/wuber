-- Guard tests for Wuber/Net/Beacons.lua lines from the mutation run.
-- Each test guards one line that no other test noticed when it was broken.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local TESTCHAR, ANITA, BOB = T.TESTCHAR, T.ANITA, "Bob Helper"

local function countDRIVERS(c)
	local n = 0
	c.W.Listen("DRIVERS", function() n = n + 1 end)
	return function() return n end
end

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

-- guards Wuber/Net/Beacons.lua:48 (1d24ac7:48, > to <=)
test("mutation beacons: hidden drivers stay cached before DRIVER_TTL and expire after it", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	d.W.SetDriving(true)
	T.settle(w)
	w:advance(5)
	local key = r.W.Key(ANITA)
	r.W.HideDriver(key, true)
	w:advance(10)
	r.W.ExpireDrivers()
	ok(r.W.hiddenDrivers[key] ~= nil, "hidden driver is still cached before DRIVER_TTL")
	r.W.HideDriver(key, false)
	local found = false
	for _, drv in ipairs(r.W.DriversSorted()) do
		if drv.key == key then found = true end
	end
	ok(found, "unhiding before DRIVER_TTL restores the driver immediately")
	r.W.HideDriver(key, true)
	-- Silence the driver so no fresh beacons arrive, then advance past DRIVER_TTL (150s)
	d.W.SetDriving(false)
	w:advance(160)
	r.W.ExpireDrivers()
	eq(r.W.hiddenDrivers[key], nil, "hidden driver expires after DRIVER_TTL")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:99 (1d24ac7:91, negate the if)
test("mutation beacons: a listed driver who beacons with the opposite faction is removed and fires DRIVERS", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	local myFac = r.W.Faction()
	local otherFac = (myFac == "H") and "A" or "H"
	local key = r.W.Key(BOB)
	local heardBeacon = r.W.Mod("Net.Beacons").heardBeacon
	heardBeacon(BOB, BOB, key, { "Orgrimmar", "1411", "500", "500", "10000", "", "open", "1", "3", myFac, "2.4.0", "", "0" }, "2", "CHANNEL", false)
	ok(r.W.drivers[key] ~= nil, "driver is listed for matching faction")
	local fires = countDRIVERS(r)
	local before = fires()
	heardBeacon(BOB, BOB, key, { "Orgrimmar", "1411", "500", "500", "10000", "", "open", "1", "3", otherFac, "2.4.0", "", "0" }, "2", "CHANNEL", false)
	eq(r.W.drivers[key], nil, "driver is removed when faction mismatches")
	ok(fires() > before, "DRIVERS fired on removal")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:200 (1d24ac7:192, negate the if)
test("mutation beacons: a listed driver who becomes hidden is removed and fires DRIVERS on next beacon", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	local myFac = r.W.Faction()
	local key = r.W.Key(BOB)
	local heardBeacon = r.W.Mod("Net.Beacons").heardBeacon
	heardBeacon(BOB, BOB, key, { "Orgrimmar", "1411", "500", "500", "10000", "", "open", "1", "3", myFac, "2.4.0", "", "0" }, "2", "CHANNEL", false)
	ok(r.W.drivers[key] ~= nil, "driver is initially listed")
	r.W.db.hidden = r.W.db.hidden or {}
	r.W.db.hidden[key] = true
	local fires = countDRIVERS(r)
	local before = fires()
	heardBeacon(BOB, BOB, key, { "Orgrimmar", "1411", "500", "500", "10000", "", "open", "1", "3", myFac, "2.4.0", "", "0" }, "2", "CHANNEL", false)
	eq(r.W.drivers[key], nil, "hidden driver is removed from W.drivers")
	ok(r.W.hiddenDrivers[key] ~= nil, "and kept in W.hiddenDrivers")
	ok(fires() > before, "DRIVERS fired when listed driver became hidden")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:259 (1d24ac7:249, < to >=)
test("mutation beacons: CX.ping skips within Q_GAP or PING_GAP and sends after both gaps", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local CX, comm, sent = setupComm(r)
	comm.lastQ = 100
	comm.lastQHeard = 0
	eq(CX.ping(110), false, "skipped within CX.Q_GAP")
	eq(#sent, 0, "nothing sent within CX.Q_GAP")
	comm.lastQ = 0
	comm.lastQHeard = 195
	eq(CX.ping(205), false, "skipped within NETK.PING_GAP")
	eq(#sent, 0, "nothing sent within NETK.PING_GAP")
	eq(CX.ping(230), true, "sent after both gaps elapsed")
	eq(#sent, 1, "one Q sent")
	eq(sent[1].kind, "Q", "kind is Q")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:265 (1d24ac7:255, return false)
test("mutation beacons: CX.ping returns true when it sends a community Q", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local CX, comm, sent = setupComm(r)
	comm.lastQ = -1000
	comm.lastQHeard = -1000
	eq(CX.ping(500), true, "CX.ping returns true on send")
	eq(#sent, 1, "one Q sent")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:513 (1d24ac7:503, or to and)
test("mutation beacons: CX.isolated returns false within 60s of joining WuberNet", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local CX = r.W.Mod("Net.Community").CX
	local fb = r.W.Mod("Net.Base").fb
	r.W.OnNetwork = function() return true end
	fb.joinedAt = r.env.GetTime() - 10
	fb.chanOthersAt = nil
	eq(CX.isolated(), false, "not isolated within 60s of joining")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:514 (1d24ac7:504, or to and)
test("mutation beacons: CX.isolated returns true when joined >= 60s and no others heard for >= 180s", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	w:advance(300)
	local CX = r.W.Mod("Net.Community").CX
	local fb = r.W.Mod("Net.Base").fb
	r.W.OnNetwork = function() return true end
	fb.joinedAt = r.env.GetTime() - 250
	fb.chanOthersAt = r.env.GetTime() - 200
	eq(CX.isolated(), true, "isolated when others were last heard >= 180s ago")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:521 (1d24ac7:511, or to and)
test("mutation beacons: CX.beacon sends when any of changed, force, offline, or isolated is true", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	d.W.SetDriving(true)
	T.settle(w)
	local CX, comm, sent = setupComm(d)
	local b = d.W.Mod("Net.Beacons").beaconFor(nil)
	ok(b ~= nil, "driver has a beacon")
	CX.isolated = function() return false end
	comm.force = false
	comm.online = true
	comm.lastD = d.env.GetTime() - 5
	eq(CX.beacon(b, true), true, "sends on changed=true alone")
	comm.force = true
	comm.online = true
	comm.lastD = d.env.GetTime() - 5
	eq(CX.beacon(b, false), true, "sends on comm.force alone")
	comm.force = false
	comm.online = false
	comm.lastD = d.env.GetTime() - 5
	eq(CX.beacon(b, false), true, "sends on not comm.online alone")
	CX.isolated = function() return true end
	comm.force = false
	comm.online = true
	comm.lastD = d.env.GetTime() - 5
	eq(CX.beacon(b, false), true, "sends on CX.isolated() alone")
	eq(#sent, 4, "all four triggers sent D")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:524 (1d24ac7:514, return nil)
test("mutation beacons: CX.beacon returns true when it sends D", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	d.W.SetDriving(true)
	T.settle(w)
	local CX, _, sent = setupComm(d)
	local b = d.W.Mod("Net.Beacons").beaconFor(nil)
	eq(CX.beacon(b, true), true, "CX.beacon returns true")
	eq(#sent, 1, "one D sent")
	eq(sent[1].kind, "D", "kind is D")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:532 (1d24ac7:522, negate the if)
test("mutation beacons: CX.found sends a beacon when driving", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	d.W.SetDriving(true)
	T.settle(w)
	local CX, comm, sent = setupComm(d)
	comm.lastQ = -1000
	comm.lastQHeard = -1000
	CX.found()
	local sawD = false
	for _, s in ipairs(sent) do
		if s.kind == "D" then sawD = true end
	end
	ok(sawD, "CX.found sent D when driving")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:801 (1d24ac7:791, or to and)
test("mutation beacons: community Q is ignored when replyPending is true or not driving", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	d.W.SetDriving(true)
	T.settle(w)
	w:advance(30)
	local CX, comm, sent = setupComm(d)
	local heardPing = d.W.Mod("Net.Beacons").heardPing
	-- Case 1: driving, replyPending already true, lastQReply old -> must not schedule another reply
	comm.replyPending = true
	comm.lastQReply = -1000
	heardPing(true)
	w:advance(5)
	eq(#sent, 0, "no reply sent when replyPending was true")
	-- Case 2: not driving, replyPending false, lastQReply old -> must not set replyPending
	d.W.SetDriving(false)
	comm.replyPending = false
	comm.lastQReply = -1000
	heardPing(true)
	eq(comm.replyPending, false, "replyPending stays false when not driving")
	T.clean(w)
end)

-- guards Wuber/Net/Beacons.lua:806 (1d24ac7:796, and to or)
test("mutation beacons: community Q triggers a community D reply after the jitter delay", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	d.W.SetDriving(true)
	T.settle(w)
	w:advance(30)
	local _, comm, sent = setupComm(d)
	comm.replyPending = false
	comm.lastQReply = -1000
	d.W.Mod("Net.Beacons").heardPing(true)
	w:advance(5)
	local sawD = false
	for _, s in ipairs(sent) do
		if s.kind == "D" then sawD = true end
	end
	ok(sawD, "community D reply sent after heardPing(true)")
	T.clean(w)
end)
