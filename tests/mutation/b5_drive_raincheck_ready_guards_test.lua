-- Mutation run guards for Wuber/Drive/Raincheck.lua and Wuber/Drive/Ready.lua.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function setupDriver()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	return w, a, a.W.Drive
end

---------------------------------------------------------------------------
-- Wuber/Drive/Raincheck.lua guards
---------------------------------------------------------------------------

-- guards Wuber/Drive/Raincheck.lua:88 (drop statement: call() swallows DR helper error without W.Error)
-- guards Wuber/Drive/Raincheck.lua:188 (drop statement: fact() skips DR.Send fallback when W.SendIOU is nil)
test("mutation b5 drive raincheck: fact falls back to DR.Send when W.SendIOU is nil and reports errors via W.Error", function()
	local w, a, DR = setupDriver()
	local origSendIOU = a.W.SendIOU
	local origSend = DR.Send
	local origErr = a.W.Error
	local errTag
	a.W.SendIOU = nil
	DR.Send = function() error("iou send boom") end
	a.W.Error = function(tag) errTag = tag end
	local exp = a.env.time() + 86400
	DR.RaincheckFact(a.W.myKey, true, "i", "AbCd1234", "dan miller", 5000, exp, "abcdef")
	-- Now trigger fact() via RaincheckHeard("ok", ...) which calls DR.Send("IOU", ...)
	ok(DR.RaincheckHeard("ok", "dan miller", "Dan Miller", "AbCd1234"), "RaincheckHeard ok succeeds")
	a.W.SendIOU = origSendIOU
	DR.Send = origSend
	a.W.Error = origErr
	a.W.lastError = nil
	eq(errTag, "drive Send", "W.Error called when DR.Send throws inside Raincheck")
	T.clean(w)
end)

-- guards Wuber/Drive/Raincheck.lua:136 (swap or->and: takeAgain fails when v.issued is numeric)
-- guards Wuber/Drive/Raincheck.lua:137 (cmp ~=->==: takeAgain skips count when issued today)
-- guards Wuber/Drive/Raincheck.lua:138 (local value -> nil: takeAgain skips incrementing iouDay.n)
-- guards Wuber/Drive/Raincheck.lua:461 (cmp ==->~=: RaincheckFact skips takeAgain when lapsed entry becomes active)
test("mutation b5 drive raincheck: RaincheckFact re-counts lapsed raincheck when active fact arrives today", function()
	local w, a, DR = setupDriver()
	local t = a.env.time()
	local exp = t + 7 * 86400
	local id = "Lapse123"
	a.W.db.drive.iou = {
		[id] = { rider = "dan miller", rideId = "abcdef", cover = 5000, issued = t, expires = exp, state = "void", why = "lapsed" },
	}
	a.W.db.drive.iouDay = { day = a.env.date("%Y%m%d", t), n = 0 }
	DR.RaincheckFact("bea jones", false, "a", id, "dan miller", 5000, exp, "abcdef")
	local v = a.W.db.drive.iou[id]
	eq(v.state, "active", "lapsed entry restored to active")
	eq(a.W.db.drive.iouDay.n, 1, "iouDay.n incremented by takeAgain")
	ok(v.countDay ~= nil, "countDay recorded")
	-- Yesterday's lapsed raincheck becoming active must NOT increment today's iouDay.n
	local oldId = "OldLp123"
	a.W.db.drive.iou[oldId] = { rider = "bea jones", rideId = "ghijkl", cover = 5000, issued = t - 86400, expires = exp, state = "void", why = "lapsed" }
	DR.RaincheckFact("bea jones", false, "a", oldId, "bea jones", 5000, exp, "ghijkl")
	eq(a.W.db.drive.iouDay.n, 1, "yesterday lapsed entry does not increment today iouDay.n")
	T.clean(w)
end)

-- guards Wuber/Drive/Raincheck.lua:256 (drop statement: arrivedEntry does not fire RAINCHECK book arrived)
-- guards Wuber/Drive/Raincheck.lua:609 (drop statement: OwingTick skips arrivedEntry when c.arrivedAt set without unit)
test("mutation b5 drive raincheck: OwingTick voids raincheck and fires RAINCHECK arrived when rider arrived", function()
	local w, a, DR = setupDriver()
	T.goOnline(a, { price = 5000 })
	local t = a.env.time()
	local exp = t + 7 * 86400
	local id = "Arriv123"
	a.W.db.drive.iou = {
		[id] = { rider = "dan miller", rideId = "abcdef", cover = 5000, issued = t, expires = exp, state = "offered" },
	}
	DR.recentPaid[1] = { key = "dan miller", name = "Dan Miller", ride = "abcdef", fare = 5000, traded = 5000 }
	DR.customers["dan miller"] = { key = "dan miller", name = "Dan Miller", wuberRide = "abcdef", arrivedAt = a.W.Now() }
	DR.units["dan miller"] = nil -- left group after arriving
	local arrivedId
	a.W.Listen("RAINCHECK", function(op, what, rid)
		if op == "book" and what == "arrived" then arrivedId = rid end
	end)
	DR.RaincheckTick()
	eq(a.W.db.drive.iou[id].state, "void", "raincheck voided on arrival")
	eq(arrivedId, id, "RAINCHECK book arrived fired")
	T.clean(w)
end)

-- guards Wuber/Drive/Raincheck.lua:617 (drop statement: OwingTick skips arrivedEntry when ArrivedAt(c, unit) is true)
test("mutation b5 drive raincheck: OwingTick voids raincheck when ArrivedAt helper reports unit arrived", function()
	local w, a, DR = setupDriver()
	T.goOnline(a, { price = 5000 })
	local t = a.env.time()
	local exp = t + 7 * 86400
	local id = "Arriv456"
	a.W.db.drive.iou = {
		[id] = { rider = "dan miller", rideId = "abcdef", cover = 5000, issued = t, expires = exp, state = "offered" },
	}
	DR.recentPaid[1] = { key = "dan miller", name = "Dan Miller", ride = "abcdef", fare = 5000, traded = 5000 }
	DR.customers["dan miller"] = { key = "dan miller", name = "Dan Miller", wuberRide = "abcdef" }
	DR.units["dan miller"] = "party1"
	local origArrivedAt = DR.ArrivedAt
	DR.ArrivedAt = function() return true end
	DR.RaincheckTick()
	DR.ArrivedAt = origArrivedAt
	eq(a.W.db.drive.iou[id].state, "void", "raincheck voided when ArrivedAt returns true")
	T.clean(w)
end)

-- guards Wuber/Drive/Raincheck.lua:389 (local value -> nil: RaincheckFor omits raincheck id)
-- guards Wuber/Drive/Raincheck.lua:391 (return -> nil: RaincheckFor returns nil)
test("mutation b5 drive raincheck: RaincheckFor returns eligibility, reason, and existing raincheck id", function()
	local w, a, DR = setupDriver()
	local t = a.env.time()
	local exp = t + 7 * 86400
	local id = "ForId123"
	a.W.db.drive.iou = {
		[id] = { rider = "dan miller", rideId = "abcdef", cover = 5000, issued = t, expires = exp, state = "offered" },
	}
	local okFor, why, gotId = DR.RaincheckFor({ wuberRide = "abcdef" })
	eq(okFor, false, "already has raincheck so not eligible")
	ok(why ~= nil, "reason returned")
	eq(gotId, id, "existing raincheck id returned")
	T.clean(w)
end)

-- guards Wuber/Drive/Raincheck.lua:510 (return false->true: RaincheckHeard returns true for unknown op)
test("mutation b5 drive raincheck: RaincheckHeard returns false for unknown op", function()
	local w, a, DR = setupDriver()
	local t = a.env.time()
	local exp = t + 7 * 86400
	local id = "OpId1234"
	a.W.db.drive.iou = {
		[id] = { rider = "dan miller", rideId = "abcdef", cover = 5000, issued = t, expires = exp, state = "offered" },
	}
	eq(DR.RaincheckHeard("bogus", "dan miller", "Dan Miller", id), false, "unknown op returns false")
	T.clean(w)
end)

-- guards Wuber/Drive/Raincheck.lua:634 (return -> nil: Rainchecks breaks id tie-break when issued times match)
test("mutation b5 drive raincheck: Rainchecks sorts entries with equal issued time by id ascending", function()
	local w, a, DR = setupDriver()
	local t = a.env.time()
	local exp = t + 7 * 86400
	a.W.db.drive.iou = {
		["Id000006"] = { rider = "dan miller", cover = 5000, issued = t, expires = exp, state = "active" },
		["Id000004"] = { rider = "dan miller", cover = 5000, issued = t, expires = exp, state = "active" },
		["Id000002"] = { rider = "dan miller", cover = 5000, issued = t, expires = exp, state = "active" },
		["Id000005"] = { rider = "dan miller", cover = 5000, issued = t, expires = exp, state = "active" },
		["Id000001"] = { rider = "dan miller", cover = 5000, issued = t, expires = exp, state = "active" },
		["Id000003"] = { rider = "dan miller", cover = 5000, issued = t, expires = exp, state = "active" },
	}
	local list = DR.Rainchecks()
	eq(#list, 6, "all 6 rainchecks returned")
	for i = 1, 6 do
		eq(list[i].id, "Id00000" .. i, "sorted by id " .. i)
	end
	T.clean(w)
end)

---------------------------------------------------------------------------
-- Wuber/Drive/Ready.lua guards
---------------------------------------------------------------------------

-- guards Wuber/Drive/Ready.lua:80 (drop statement: Unblacklist leaves blocklist entry)
-- guards Wuber/Drive/Ready.lua:81 (drop statement: Unblacklist leaves refusal entry)
-- guards Wuber/Drive/Ready.lua:82 (drop statement: Unblacklist leaves askedToastAt throttle)
-- guards Wuber/Drive/Ready.lua:134 (swap and->or: BlockedAskToast crashes on nil name)
-- guards Wuber/Drive/Ready.lua:135 (cmp ~=->==: BlockedAskToast fails on non-blocked rider)
test("mutation b5 drive ready: Unblacklist clears blocklist, refusals, and ask-toast throttle; BlockedAskToast handles nil and non-blocked", function()
	local w, a, DR = setupDriver()
	eq(DR.BlockedAskToast(nil), false, "nil name returns false cleanly")
	eq(DR.BlockedAskToast("Not Blocked"), false, "non-blocked rider returns false")
	DR.Blacklist("Dan Miller", DR.NONPAY_REASON .. " (50s)", true)
	DR.refusals["dan miller"] = { name = "Dan Miller", key = "dan miller", reason = "test", at = a.W.Now() }
	ok(DR.BlockedAskToast("Dan Miller"), "first ask toast succeeds")
	eq(DR.BlockedAskToast("Dan Miller"), false, "second ask toast within 60s throttled")
	eq(DR.Unblacklist("Dan Miller", true), 1, "Unblacklist removes 1 entry")
	eq(a.W.db.drive.blocklist["dan miller"], nil, "blocklist cleared")
	eq(DR.refusals["dan miller"], nil, "refusals cleared")
	-- Re-block immediately: askedToastAt was cleared by Unblacklist so toast fires again
	DR.Blacklist("Dan Miller", DR.NONPAY_REASON .. " (50s)", true)
	ok(DR.BlockedAskToast("Dan Miller"), "ask toast fires again after Unblacklist cleared throttle")
	T.clean(w)
end)

-- guards Wuber/Drive/Ready.lua:163 (cmp ==->~=: Readiness skips provider lock message)
test("mutation b5 drive ready: Readiness reports provider lock when DR.Lock returns provider", function()
	local w, a, DR = setupDriver()
	local origLock = DR.Lock
	DR.Lock = function() return "provider" end
	local lines = DR.Readiness()
	DR.Lock = origLock
	local found = false
	for _, l in ipairs(lines) do
		if l.ok == false and l.text:find("Another addon drives for Wuber now", 1, true) then found = true end
	end
	eq(found, true, "provider lock line present in Readiness")
	T.clean(w)
end)

-- guards Wuber/Drive/Ready.lua:181 (swap and->or: Choose summoner fix crashes when W.UI is nil)
test("mutation b5 drive ready: Readiness Choose summoner fix handles nil W.UI cleanly", function()
	local w = T.newWorld()
	local r = T.rider(w, T.BEA, { spot = "Orgrimmar", class = "MAGE" })
	T.settle(w)
	local DR = r.W.Drive
	DR.SetRunner(true)
	local lines = DR.Readiness()
	local fixFn
	for _, l in ipairs(lines) do
		if l.text == "Choose who summons" and l.fix then fixFn = l.fix[2] end
	end
	ok(fixFn ~= nil, "Choose who summons fix found")
	local origUI = r.W.UI
	r.W.UI = nil
	fixFn()
	r.W.UI = origUI
	T.clean(w)
end)

-- guards Wuber/Drive/Ready.lua:258 (swap and->or: Readiness stations line mishandles off/unready flags)
-- guards Wuber/Drive/Ready.lua:260 (drop statement: Readiness omits Stations summary line)
test("mutation b5 drive ready: Readiness lists multi-station summary with open/ready flags", function()
	local w, a, DR = setupDriver()
	local origStations = DR.Stations
	DR.Stations = function()
		return {
			{ place = "Orgrimmar", open = true, ready = true },
			{ place = "Ratchet", open = false, ready = false },
		}
	end
	local lines = DR.Readiness()
	DR.Stations = origStations
	local stText
	for _, l in ipairs(lines) do
		if l.text:find("^Stations: ") then stText = l.text end
	end
	eq(stText, "Stations: Orgrimmar, Ratchet (off) - riders bring a friend.", "multi-station summary formatted")
	T.clean(w)
end)

-- guards Wuber/Drive/Ready.lua:298 (cmp ==->~=: Readiness marks whisperMode off as ok=nil instead of false)
-- guards Wuber/Drive/Ready.lua:299 (return -> nil: Readiness returns nil)
-- guards Wuber/Drive/Ready.lua:304 (cmp ==->~=: Ready returns true when a line has ok=false)
-- guards Wuber/Drive/Ready.lua:306 (return true->false: Ready returns false when all lines pass)
test("mutation b5 drive ready: Ready reflects Readiness ok=false on whisperMode off and true when ready", function()
	local w, a, DR = setupDriver()
	a.W.Char().wizard = true
	DR.opts().whisperMode = "macro"
	DR.opts().needShards = false
	ok(DR.Ready(), "Ready returns true when all lines pass")
	DR.opts().whisperMode = "off"
	eq(DR.Ready(), false, "Ready returns false when whisperMode is off")
	T.clean(w)
end)
