-- Guard tests for Wuber/Drive/Net.lua (Big Batch 2, item H1).
-- Each test guards one line from commit 1d24ac7 that no other test protected.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local TESTCHAR, ANITA, BOB = T.TESTCHAR, T.ANITA, T.BOB

local function hasMsg(w, kind, from, pat1, pat2)
	for _, e in ipairs(T.msgs(w, kind, from)) do
		local s = tostring(e.text)
		if (not pat1 or s:find(pat1, 1, true)) and (not pat2 or s:find(pat2, 1, true)) then return true end
	end
	return false
end

-- guards Wuber/Drive/Net.lua:87 (and to or in opts())
test("mutation b2 drive net: driver still announces open offer via opts().maxGroup when MaxGroup helper is absent", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Ratchet" })
	T.settle(w)
	T.goOnline(d, { price = 100000 })
	d.W.Drive.MaxGroup = nil
	ok(d.W.engine.beacon() ~= nil, "beacon built using opts().maxGroup")
	T.clean(w)
end)

-- guards Wuber/Drive/Net.lua:102 (return nil in wuberDest fallback)
test("mutation b2 drive net: driver declines wrong destination using fallback cleaner when CleanDest is absent", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Ratchet" })
	w:addBot(TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	T.goOnline(d, { price = 100000 })
	local origCleanDest = d.W.CleanDest
	d.W.CleanDest = nil
	d.W.engine.onRequest({ id = "aaaaaa", buyer = TESTCHAR, dest = "Stormwind", price = 100000 })
	d.W.CleanDest = origCleanDest
	w:advance(1)
	ok(hasMsg(w, "N", ANITA, "aaaaaa", "closed"), "wrong destination declined with fallback wuberDest")
	eq(#T.msgs(w, "A", ANITA), 0, "wrong destination not accepted")
	T.clean(w)
end)

-- guards Wuber/Drive/Net.lua:121 (negate if W.NormPlace in sameDest)
test("mutation b2 drive net: driver accepts ride when destination differs only by apostrophe", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Ratchet" })
	w:addBot(TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	T.goOnline(d, { price = 100000 })
	d.W.Char().dest = "Light's Hope Chapel"
	d.W.engine.onRequest({ id = "bbbbbb", buyer = TESTCHAR, dest = "Lights Hope Chapel", price = 100000 })
	w:advance(1)
	eq(#T.msgs(w, "A", ANITA), 1, "destination matched via W.NormPlace")
	T.clean(w)
end)

-- skipped Wuber/Drive/Net.lua:125 (return false -> return nil in sameDest):
--   sameDest is only called in boolean conditions at lines 529 and 532; false and nil behave identically.

-- guards Wuber/Drive/Net.lua:412 (delete NET.rides[key] = nil on expired queue return)
test("mutation b2 drive net: expired ride returned to queue after 10 minutes no longer sends stage updates", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Ratchet" })
	w:addBot(TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	T.goOnline(d, { price = 100000 })
	d.W.Drive.opts().expire = 0
	d.W.engine.onRequest({ id = "cccccc", buyer = TESTCHAR, dest = "Ratchet", price = 100000 })
	w:advance(1)
	eq(#T.msgs(w, "A", ANITA), 1, "ride accepted")
	local c = d.W.Drive.customers["wuber testcharacter"]
	ok(c ~= nil, "customer row exists")
	c.state = "summoning"
	w:advance(650)
	c.state = "queued"
	d.W.Fire("DRIVE_STATE", c, "summoning")
	local beforeS = #T.msgs(w, "S", ANITA)
	c.state = "summoning"
	d.W.Fire("DRIVE_STATE", c, "queued")
	w:advance(0.5)
	eq(#T.msgs(w, "S", ANITA), beforeS, "no stage update sent for expired ride")
	T.clean(w)
end)

-- guards Wuber/Drive/Net.lua:443 (delete c.price = r.price in afterChange)
test("mutation b2 drive net: locked ride price is restored on customer row after drive change", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Ratchet" })
	local r = T.rider(w, TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	T.goOnline(d, { price = 100000 })
	w:advance(2)
	w:inject(ANITA, "D~1~Ratchet~1413~500~500~100000~~open~1~0~~2.3.1", "CHANNEL")
	w:advance(0.2)
	r.W.RequestRide("anita lift")
	w:advance(2)
	local c = d.W.Drive.customers["wuber testcharacter"]
	ok(c ~= nil, "customer row exists")
	c.price = 250000
	d.W.Drive.NetAfterChange()
	eq(c.price, 100000, "locked fare restored by NetAfterChange")
	T.clean(w)
end)

-- guards Wuber/Drive/Net.lua:457 (~= to == in wuberLine)
test("mutation b2 drive net: declined rider's WTB summon whisper is held back when WuberLine hook is absent", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Ratchet" })
	w:addBot(TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	T.goOnline(d, { price = 100000 })
	d.W.Drive.WuberLine = nil
	d.W.engine.onRequest({ id = "dddddd", buyer = TESTCHAR, dest = "Ratchet", price = 10000 })
	w:advance(1)
	ok(hasMsg(w, "N", ANITA, "dddddd"), "underpriced request was declined")
	eq(d.W.Drive.NetHeldBack(TESTCHAR, "whisper", "WTB summon to Ratchet for 1g"), true, "WTB summon whisper is held back")
	T.clean(w)
end)

-- guards Wuber/Drive/Net.lua:458 (and to or in wuberLine)
test("mutation b2 drive net: declined rider's ordinary whisper is not held back", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Ratchet" })
	w:addBot(TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	T.goOnline(d, { price = 100000 })
	d.W.Drive.WuberLine = nil
	d.W.engine.onRequest({ id = "eeeeee", buyer = TESTCHAR, dest = "Ratchet", price = 10000 })
	w:advance(1)
	ok(hasMsg(w, "N", ANITA, "eeeeee"), "underpriced request was declined")
	eq(d.W.Drive.NetHeldBack(TESTCHAR, "whisper", "inv please"), false, "non-Wuber whisper is not held back")
	T.clean(w)
end)

-- guards Wuber/Drive/Net.lua:470 (delete NET.cancelled[k] = nil after CANCEL_HOLD)
test("mutation b2 drive net: after cancel hold expires and a whisper is checked, rebooking during summon is declined busy", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Ratchet" })
	w:addBot(TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	T.goOnline(d, { price = 100000 })
	d.W.engine.onRequest({ id = "ffffff", buyer = TESTCHAR, dest = "Ratchet", price = 100000, riderVer = "2.3.0" })
	w:advance(1)
	local c = d.W.Drive.customers["wuber testcharacter"]
	ok(c ~= nil, "customer row exists")
	c.state = "summoning"
	d.W.engine.onCancel("ffffff", TESTCHAR)
	w:advance(35)
	eq(d.W.Drive.NetHeldBack(TESTCHAR, "whisper", "inv"), false, "cancel hold expired")
	d.W.engine.onRequest({ id = "gggggg", buyer = TESTCHAR, dest = "Ratchet", price = 100000, riderVer = "2.3.0" })
	w:advance(1)
	ok(hasMsg(w, "N", ANITA, "gggggg", "busy"), "rebooking while summon is under way is declined busy")
	T.clean(w)
end)

-- skipped Wuber/Drive/Net.lua:475 (delete NET.held[k] = nil after HOLD):
--   now() only advances, so (now() - at > HOLD) stays true on every later NetHeldBack call, and NET.held is only overwritten or cleared on new requests.

-- guards Wuber/Drive/Net.lua:504 (return nil in isBlocked fallback)
test("mutation b2 drive net: rating from rider on db blocklist is ignored when BlockEntry helper is absent", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Ratchet" })
	T.settle(w)
	T.goOnline(d, { price = 100000 })
	d.W.Drive.BlockEntry = nil
	d.W.db.drive = d.W.db.drive or {}
	d.W.db.drive.blocklist = d.W.db.drive.blocklist or {}
	d.W.db.drive.blocklist["wuber testcharacter"] = true
	d.W.engine.onRating("hhhhhh", TESTCHAR, 5)
	ok(not d:said("rated the ride"), "rating from blocked rider is not printed")
	T.clean(w)
end)

-- guards Wuber/Drive/Net.lua:532 (and to or in MultiStation check)
test("mutation b2 drive net: multi-station driver declines request for a destination with no open station", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Ratchet" })
	w:addBot(TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	T.goOnline(d, { price = 100000 })
	d.W.Drive.MultiStation = function() return true end
	d.W.Drive.Stations = function() return { { place = "Ratchet", open = true } } end
	d.W.engine.onRequest({ id = "iiiiii", buyer = TESTCHAR, dest = "Stormwind", price = 100000 })
	w:advance(1)
	ok(hasMsg(w, "N", ANITA, "iiiiii", "closed"), "unserved destination declined closed")
	eq(#T.msgs(w, "A", ANITA), 0, "unserved destination not accepted")
	T.clean(w)
end)

-- guards Wuber/Drive/Net.lua:606 (delete c.stTold = id)
test("mutation b2 drive net: already-joined 2.3.0 rider in group triggers SendState only once per ride id", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Ratchet" })
	w:addBot(TESTCHAR, { spot = "Orgrimmar" })
	w:addBot(BOB, { spot = "Ratchet" })
	T.settle(w)
	w:group({ ANITA, BOB })
	T.goOnline(d, { price = 100000 })
	w:advance(2)
	local c = d.W.Drive.Request(TESTCHAR, "whisper", "inv")
	ok(c ~= nil, "customer created")
	c.state = "joined"
	local sent = 0
	local origSendState = d.W.Drive.SendState
	d.W.Drive.SendState = function(cust, ...)
		if cust == c then sent = sent + 1 end
		if origSendState then return origSendState(cust, ...) end
	end
	d.W.engine.onRequest({ id = "jjjjjj", buyer = TESTCHAR, dest = "Ratchet", price = 100000, riderVer = "2.3.0" })
	d.W.engine.onRequest({ id = "jjjjjj", buyer = TESTCHAR, dest = "Ratchet", price = 100000, riderVer = "2.3.0" })
	eq(sent, 1, "SendState called only once for the same ride id")
	T.clean(w)
end)

-- guards Wuber/Drive/Net.lua:683 (delete NET.attached = false in NetAttach)
test("mutation b2 drive net: NetAttach returns false after detaching when driver becomes inactive", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Ratchet" })
	T.settle(w)
	T.goOnline(d, { price = 100000 })
	w:advance(2)
	eq(d.W.Drive.NetAttach(), true, "attached while active")
	d.W.Drive.Active = function() return false end
	eq(d.W.Drive.NetAttach(), false, "detaching returns false")
	T.clean(w)
end)

-- skipped Wuber/Drive/Net.lua:693 (== to ~= in addFilter):
--   addFilter runs once at PLAYER_LOGIN when DR.requestFilters is empty, so the loop body never executes in Wuber.
