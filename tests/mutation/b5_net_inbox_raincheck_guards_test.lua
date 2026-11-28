-- Mutation run guards for Wuber/Net/Inbox.lua and Wuber/Net/Raincheck.lua.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function setupClient(name, spot)
	local w = T.newWorld()
	local c = T.rider(w, name or T.BEA, { spot = spot or "Orgrimmar", class = "MAGE" })
	T.settle(w)
	return w, c, c.W
end

---------------------------------------------------------------------------
-- Wuber/Net/Inbox.lua guards
---------------------------------------------------------------------------

-- guards Wuber/Net/Inbox.lua:52 (drop statement: community channel own echo does not update comm.echoAt)
-- guards Wuber/Net/Inbox.lua:69 (drop statement: community channel peer message does not update comm.othersAt)
-- guards Wuber/Net/Inbox.lua:70 (drop statement: community channel peer message does not increment comm.heard)
test("mutation b5 net inbox: community channel updates comm.echoAt on own echo and comm.othersAt/heard on peer", function()
	local w, c, W = setupClient()
	local comm = W.Mod("Net.Community").comm
	local origIsComm = W.IsCommunityChannel
	W.IsCommunityChannel = function() return true end
	comm.echoAt, comm.othersAt, comm.heard = nil, nil, 0
	-- Own echo over community channel
	c:fire("CHAT_MSG_ADDON", W.PREFIX, "Q~1~1", "CHANNEL", W.Me(), nil, nil, 9, "CommChan")
	ok(comm.echoAt ~= nil, "comm.echoAt set on own echo")
	-- Peer message over community channel
	c:fire("CHAT_MSG_ADDON", W.PREFIX, "Q~1~1", "CHANNEL", T.ANITA, nil, nil, 9, "CommChan")
	W.IsCommunityChannel = origIsComm
	ok(comm.othersAt ~= nil, "comm.othersAt set on peer message")
	eq(comm.heard, 1, "comm.heard incremented on peer message")
	T.clean(w)
end)

-- guards Wuber/Net/Inbox.lua:142 (swap or->and: CHAT_MSG_WHISPER WTB summon from self is accepted)
-- guards Wuber/Net/Inbox.lua:144 (local value -> nil: CHAT_MSG_WHISPER ignores recent lastR[key])
-- guards Wuber/Net/Inbox.lua:145 (cmp <->>=: CHAT_MSG_WHISPER drops when lastR is old or accepts when recent)
-- guards Wuber/Net/Inbox.lua:147 (cmp ==->~=: CHAT_MSG_WHISPER duplicates rider already in W.incoming)
test("mutation b5 net inbox: CHAT_MSG_WHISPER WTB skips self, recent lastR, and existing incoming rider", function()
	local w, d, W = setupClient(T.ANITA, "Orgrimmar")
	local origBeacon = W.DriverBeacon
	W.DriverBeacon = function() return { dest = "Ratchet", mapID = 1413, price = 5000, service = "Test", state = "open", team = "1", seats = 1 } end
	local lastR = W.Mod("Net.Requests").lastR
	-- 1. Self whisper and invalid-key sender must be ignored
	d:fire("CHAT_MSG_WHISPER", "WTB summon to Ratchet for 50s", T.ANITA)
	d:fire("CHAT_MSG_WHISPER", "WTB summon to Ratchet for 50s", "---")
	w:advance(3)
	eq(#W.incoming, 0, "self and invalid-key WTB whisper ignored")
	-- 2. Recent lastR[key] (< 30s) must be ignored
	lastR["dan miller"] = W.Now()
	d:fire("CHAT_MSG_WHISPER", "WTB summon to Ratchet for 50s", "Dan Miller")
	w:advance(3)
	eq(#W.incoming, 0, "WTB whisper within 30s of R ignored")
	-- 3. Old lastR[key] (>= 30s) must be accepted
	w:advance(35)
	d:fire("CHAT_MSG_WHISPER", "WTB summon to Ratchet for 50s", "Dan Miller")
	w:advance(3)
	eq(#W.incoming, 1, "WTB whisper after 30s accepted")
	local firstId = W.incoming[1].id
	-- 4. Already in W.incoming must not replace/duplicate even after lastR expires
	w:advance(5)
	d:fire("CHAT_MSG_WHISPER", "WTB summon to Ratchet for 50s", "Dan Miller")
	w:advance(3)
	eq(#W.incoming, 1, "WTB whisper for existing incoming rider not duplicated")
	eq(W.incoming[1].id, firstId, "existing incoming ride id preserved")
	W.DriverBeacon = origBeacon
	T.clean(w)
end)

-- guards Wuber/Net/Inbox.lua:160 (cmp ==->~=: non-PASSWORD_CHANGED notice clears channelPassword or PASSWORD_CHANGED ignored)
test("mutation b5 net inbox: CHAT_MSG_CHANNEL_NOTICE_USER clears channelPassword only on PASSWORD_CHANGED", function()
	local w, c, W = setupClient()
	local BaseMod = W.Mod("Net.Base")
	local calls = {}
	local origCP = BaseMod.channelPassword
	BaseMod.channelPassword = function(v) calls[#calls + 1] = v end
	-- WRONG_PASSWORD or other kind must not clear password
	c:fire("CHAT_MSG_CHANNEL_NOTICE_USER", "OWNER_CHANGED", nil, nil, W.CHANNEL, "Dan Miller", nil, nil, nil, W.CHANNEL)
	eq(#calls, 0, "non-PASSWORD_CHANGED does not call channelPassword")
	c:fire("CHAT_MSG_CHANNEL_NOTICE_USER", "PASSWORD_CHANGED", nil, nil, W.CHANNEL, "Dan Miller", nil, nil, nil, W.CHANNEL)
	BaseMod.channelPassword = origCP
	eq(#calls, 1, "PASSWORD_CHANGED calls channelPassword")
	eq(calls[1], false, "channelPassword called with false")
	T.clean(w)
end)

-- guards Wuber/Net/Inbox.lua:185 (swap and->or: CLUB_ADDED calls CommunityCheck when comm.startAt is nil)
-- guards Wuber/Net/Inbox.lua:186 (drop statement: CLUB_ADDED does not fire COMMUNITY)
test("mutation b5 net inbox: CLUB_ADDED fires COMMUNITY and guards CommunityCheck with comm.startAt", function()
	local w, c, W = setupClient()
	local comm = W.Mod("Net.Community").comm
	local origCheck = W.CommunityCheck
	local checked, fired = 0, 0
	W.CommunityCheck = function() checked = checked + 1 end
	W.Listen("COMMUNITY", function() fired = fired + 1 end)
	comm.startAt = nil
	c:fire("CLUB_ADDED")
	W.CommunityCheck = origCheck
	eq(checked, 0, "CommunityCheck not called when comm.startAt is nil")
	eq(fired, 1, "COMMUNITY fired on CLUB_ADDED")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- Wuber/Net/Raincheck.lua guards
---------------------------------------------------------------------------

-- guards Wuber/Net/Raincheck.lua:108 (swap or->and: expire crashes on non-table or invalid id in db.rainchecks)
-- guards Wuber/Net/Raincheck.lua:119 (cmp <->>=: expire evicts newest instead of oldest when > KEEP)
-- guards Wuber/Net/Raincheck.lua:121 (drop statement: expire fails to delete oldest entry when > KEEP)
test("mutation b5 net raincheck: expire drops invalid entries and evicts oldest past KEEP (20)", function()
	local w, c, W = setupClient()
	local exp = c.env.time() + 7 * 86400
	W.db.rainchecks = {
		["bad"] = { state = "active", expires = exp, at = 100 },
		["BadNonTb"] = "not a table",
	}
	eq(#W.Raincheck.Mine(), 0, "invalid id and non-table entries dropped when <= KEEP")
	eq(W.db.rainchecks["bad"], nil, "invalid id entry dropped")
	eq(W.db.rainchecks["BadNonTb"], nil, "non-table entry dropped")
	for i = 1, 22 do
		local id = string.format("RcId%04d", i)
		W.db.rainchecks[id] = { driverKey = "d" .. i, state = "active", expires = exp, at = 1000 + i }
	end
	local mine = W.Raincheck.Mine()
	eq(#mine, 20, "capped at RK.KEEP (20) entries")
	eq(W.db.rainchecks["RcId0001"], nil, "oldest entry RcId0001 evicted")
	eq(W.db.rainchecks["RcId0002"], nil, "second oldest entry RcId0002 evicted")
	ok(W.db.rainchecks["RcId0022"] ~= nil, "newest entry RcId0022 kept")
	T.clean(w)
end)

-- guards Wuber/Net/Raincheck.lua:175 (cmp >-><=: tracked resets on every heard message)
-- guards Wuber/Net/Raincheck.lua:177 (drop statement: tracked not reset to 1 after clearing > 400)
test("mutation b5 net raincheck: heardN resets after 400 unique V asks without staying capped", function()
	local w, c, W = setupClient()
	local h = W.Mod("Net.Base").netHandler("V")
	ok(type(h) == "function", "V netHandler registered")
	-- Send 3 asks for ride "ridaaa" from Dan Miller (reaches PER_RIDE = 3)
	for _ = 1, 3 do
		h("Dan Miller", "Dan Miller", "dan miller", { "ask", "ridaaa" }, "WHISPER")
	end
	-- A different rideId must NOT reset heardN before 400 unique keys
	h("Dan Miller", "Dan Miller", "dan miller", { "ask", "ridbbb" }, "WHISPER")
	-- A 4th ask for "ridaaa" is still capped (heardN["dan miller|ridaaa"] == 3)
	local fired = 0
	W.Listen("RAINCHECK", function(op, rid) if op == "ask" and rid == "ridaaa" then fired = fired + 1 end end)
	h("Dan Miller", "Dan Miller", "dan miller", { "ask", "ridaaa" }, "WHISPER")
	eq(fired, 0, "4th ask for same ride capped before 400 reset")
	-- Flood 401 unique 6-letter rideIds to trigger > 400 reset of heardN
	for i = 0, 400 do
		local a = string.char(97 + math.floor(i / 26))
		local b = string.char(97 + (i % 26))
		h("Dan Miller", "Dan Miller", "dan miller", { "ask", "flaa" .. a .. b }, "WHISPER")
	end
	-- After reset, "ridaaa" can be heard 3 times again, and a 2nd unique key ("ridccc") must NOT reset it immediately
	h("Dan Miller", "Dan Miller", "dan miller", { "ask", "ridaaa" }, "WHISPER")
	ok(fired >= 1, "ridaaa heard again after > 400 reset")
	h("Dan Miller", "Dan Miller", "dan miller", { "ask", "ridaaa" }, "WHISPER")
	h("Dan Miller", "Dan Miller", "dan miller", { "ask", "ridaaa" }, "WHISPER")
	local beforeCap = fired
	h("Dan Miller", "Dan Miller", "dan miller", { "ask", "ridccc" }, "WHISPER")
	h("Dan Miller", "Dan Miller", "dan miller", { "ask", "ridaaa" }, "WHISPER")
	eq(fired, beforeCap, "ridaaa stays capped after 1 more unique key (tracked reset to 1)")
	T.clean(w)
end)

-- guards Wuber/Net/Raincheck.lua:225 (if cond negated: heardOk fires offer/kept even when raincheck is no longer active)
test("mutation b5 net raincheck: heardOk does nothing when raincheck left active state before HEARD timer", function()
	local w, c, W = setupClient()
	local now = c.env.time()
	local exp = now + 7 * 86400
	local id = "RcWait01"
	W.db.rainchecks = {
		[id] = { driverKey = "anita lift", driver = T.ANITA, addr = T.ANITA, state = "offered", expires = exp, at = now },
	}
	local origSendTo = W.SendTo
	W.SendTo = function() return true end
	ok(W.Raincheck.Accept(id), "Accept succeeds")
	W.SendTo = origSendTo
	-- Mark used before RK.HEARD (3s) elapses
	ok(W.Raincheck.Used(id), "Used marks raincheck used")
	local events = {}
	W.Listen("RAINCHECK", function(op, gotId)
		if gotId == id then events[#events + 1] = op end
	end)
	w:advance(4)
	eq(#events, 0, "heardOk fires neither offer nor kept when state is already used")
	T.clean(w)
end)

-- Skipped: Wuber/Net/Raincheck.lua:267 (drop statement: id = validId(id) is redundant with expire() dropping non-validId keys at line 108)
-- guards Wuber/Net/Raincheck.lua:270 (cmp ==->~=: Decline rejects offered or declines active raincheck)
test("mutation b5 net raincheck: Decline validates id and only declines offered rainchecks", function()
	local w, c, W = setupClient()
	local now = c.env.time()
	local exp = now + 7 * 86400
	W.db.rainchecks = {
		["RcActv01"] = { driverKey = "anita lift", driver = T.ANITA, state = "active", expires = exp, at = now },
		["RcOffr01"] = { driverKey = "bea jones", driver = T.BEA, state = "offered", expires = exp, at = now },
	}
	eq(W.Raincheck.Decline("bad"), false, "invalid id rejected")
	eq(W.Raincheck.Decline("RcActv01"), false, "active raincheck cannot be declined")
	ok(W.db.rainchecks["RcActv01"] ~= nil, "active raincheck still present")
	local origSendTo = W.SendTo
	W.SendTo = function() return true end
	eq(W.Raincheck.Decline("RcOffr01"), true, "offered raincheck declined")
	W.SendTo = origSendTo
	eq(W.db.rainchecks["RcOffr01"], nil, "offered raincheck removed on decline")
	T.clean(w)
end)

-- guards Wuber/Net/Raincheck.lua:286 (cmp ~=->==: Mine sorts by at wrong when timestamps differ)
-- guards Wuber/Net/Raincheck.lua:287 (return -> nil: Mine breaks id tie-break when at timestamps match)
test("mutation b5 net raincheck: Mine sorts newest at first and breaks equal-at ties by id ascending", function()
	local w, c, W = setupClient()
	local exp = c.env.time() + 7 * 86400
	W.db.rainchecks = {
		["Id000006"] = { state = "active", expires = exp, at = 500 },
		["Id000004"] = { state = "active", expires = exp, at = 500 },
		["Id000002"] = { state = "active", expires = exp, at = 500 },
		["Id000005"] = { state = "active", expires = exp, at = 500 },
		["Id000001"] = { state = "active", expires = exp, at = 500 },
		["Id000003"] = { state = "active", expires = exp, at = 500 },
		["IdNewest"] = { state = "active", expires = exp, at = 900 },
	}
	local mine = W.Raincheck.Mine()
	eq(#mine, 7, "all 7 entries returned")
	eq(mine[1].id, "IdNewest", "newest timestamp first")
	for i = 1, 6 do
		eq(mine[i + 1].id, "Id00000" .. i, "equal-at tie sorted by id " .. i)
	end
	T.clean(w)
end)
