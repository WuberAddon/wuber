-- Tests of Net.Bounty (SPEC7 5.3; owner E). Loaded by tests/run.lua with its helper table T.
-- Round 8 step 0: the stub's contract (registered, deps = header Uses, public names) and that it
-- is idle (does nothing, sends nothing, saves nothing). The owner adds the behaviour tests.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("net.bounty: contract (registered, deps, header, public names); idle with nothing pinned", function()
	local W, w, r, Mod = T.contract("Net.Bounty", "tests/net/bounty_test.lua", {
		["W.Bounty"] = "table",
		["W.Bounty.Cancel"] = "function",
		["W.Bounty.Demand"] = "function",
		["W.Bounty.Mine"] = "function",
		["W.Bounty.Pin"] = "function",
		["W.Bounty.Place"] = "function",
		["W.bounties"] = "table",
		["Mod.heard"] = "function",
		["Mod.tick"] = "function",
	})
	ok(Mod, "W.Mod(\"Net.Bounty\")")
	local sent = #w.addonLog
	eq(W.Bounty.Pin("The Barrens", 5000), false, "a whole zone: no bounty")
	eq(W.Bounty.Pin("Nowhere Town", 5000), false, "an unknown place: no bounty")
	eq(W.Bounty.Mine(), nil, "no bounty")
	eq(W.Bounty.Cancel(), false, "nothing to cancel")
	eq(#W.Bounty.Demand(), 0, "no demand")
	eq(#w.addonLog, sent, "no addon message")
	eq(W.db.bounty, nil, "nothing saved")
	T.clean(w)
end)

local ANITA, TESTCHAR, BOB, ANA, BEA, CAL = T.ANITA, T.TESTCHAR, T.BOB, T.ANA, T.BEA, T.CAL

-- the W messages a player sent (each send once: over the channel, the community copy aside)
local function ws(w, from, chan)
	local out = {}
	for _, e in ipairs(T.msgs(w, "W", from, chan or "CHANNEL")) do
		if e.target == nil or type(e.target) == "number" then out[#out + 1] = e end
	end
	return out
end

local function wFields(e) return T.fields(e) end

test("net.bounty: W's size: a 32-byte place, the top fare and 30 minutes fit in 50 bytes", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local text = r.W.Encode("W", string.rep("x", 32), 99999999, "H", 30)
	ok(#text <= 50, "W <= 50 bytes: " .. #text)
	eq(text, "W~1~" .. string.rep("x", 32) .. "~99999999~H~30", "fields")
	T.clean(w)
end)

test("net.bounty: pin sends one W, again every 5 min, never a 7th; ends by itself after 30 min (copper 0)", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	local fired = {}
	r.W.Listen("BOUNTY", function(kind, b, why) fired[#fired + 1] = kind .. ":" .. tostring(b and b.place) .. ":" .. tostring(why) end)
	eq(r.W.Bounty.Pin("gadget", 6000), true, "pinned (a place's other name)")
	w:advance(1)
	local mine = r.W.Bounty.Mine()
	eq(mine.place, "Gadgetzan", "the place's own name")
	eq(mine.copper, 6000, "60s")
	eq(r.W.db.bounty.place, "Gadgetzan", "saved (survives /reload)")
	ok(r.W.IsWatched("Gadgetzan"), "the place is watched too")
	eq(fired[1], "mine:Gadgetzan:nil", "BOUNTY mine")
	local sent = ws(w, TESTCHAR)
	eq(#sent, 1, "one W")
	local f = wFields(sent[1])
	eq(f[3], "Gadgetzan", "place") eq(f[4], "6000", "copper") eq(f[5], "H", "faction") eq(f[6], "30", "minutes left")
	w:advance(200)
	eq(#ws(w, TESTCHAR), 1, "nothing before 5 min")
	w:advance(101)
	eq(#ws(w, TESTCHAR), 2, "the second at 5 min")
	eq(wFields(ws(w, TESTCHAR)[2])[6], "25", "25 minutes left")
	for _ = 1, 5 do w:advance(300) end
	eq(#ws(w, TESTCHAR), 7, "6 sends, then the cancel (copper 0) at 30 min")
	eq(wFields(ws(w, TESTCHAR)[6])[4], "6000", "the 6th is the bounty")
	eq(wFields(ws(w, TESTCHAR)[7])[4], "0", "the 7th is the end: copper 0")
	eq(r.W.Bounty.Mine(), nil, "over")
	eq(r.W.db.bounty, nil, "not saved any more")
	eq(fired[#fired], "mine:nil:expired", "BOUNTY: expired")
	w:advance(600)
	eq(#ws(w, TESTCHAR), 7, "nothing more")
	T.clean(w)
end)

test("net.bounty: refused for zones, unknown places, places a driver serves, during a ride; one at a time", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA)
	local r = T.rider(w)
	T.settle(w)
	T.goOnline(d)
	w:advance(3)
	local okP, why = r.W.Bounty.Pin("Tanaris", 5000)
	eq(okP, false, "a whole zone") eq(why, "place", "why")
	okP, why = r.W.Bounty.Pin("Ratchet", 5000)
	eq(okP, false, "Anita serves Ratchet") eq(why, "served", "why")
	okP, why = r.W.Bounty.Pin("Moonbase", 5000)
	eq(why, "place", "unknown")
	eq(r.W.Bounty.Pin("Gadgetzan", 1), true, "pinned")
	eq(r.W.Bounty.Mine().copper, r.W.MIN_PRICE, "clamped up to the lowest fare")
	eq(r.W.Bounty.Pin("Everlook", 7500), true, "a newer one")
	eq(r.W.Bounty.Mine().place, "Everlook", "replaces the older")
	w:advance(1)
	eq(#ws(w, TESTCHAR), 1, "one send in the first minute")
	w:advance(60)
	eq(#ws(w, TESTCHAR), 2, "the newer one after the minute")
	eq(wFields(ws(w, TESTCHAR)[2])[3], "Everlook", "Everlook")
	T.clean(w)
end)

test("net.bounty: booking a ride ends it (copper 0); a driver who starts serving the place ends it", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Gadgetzan" })
	local r = T.rider(w)
	T.settle(w)
	eq(r.W.Bounty.Pin("Gadgetzan", 7500), true, "pinned")
	w:advance(61)
	local fired = {}
	r.W.Listen("BOUNTY", function(kind, b, why, who) fired[#fired + 1] = tostring(why) .. ":" .. tostring(who) end)
	T.goOnline(d)
	w:advance(5)
	eq(r.W.Bounty.Mine(), nil, "a driver serves Gadgetzan now: over")
	eq(fired[1], "served:Anita Lift", "BOUNTY says who")
	local last = ws(w, TESTCHAR)
	eq(wFields(last[#last])[4], "0", "drivers hear the end")
	T.clean(w)
	-- booking
	local w2 = T.newWorld()
	local d2 = T.driver(w2, ANITA)
	local r2 = T.rider(w2)
	T.settle(w2)
	eq(r2.W.Bounty.Pin("Gadgetzan", 7500), true, "pinned")
	w2:advance(61)
	T.goOnline(d2)
	w2:advance(3)
	ok(r2.W.RequestRide("anita lift"), "a ride to Ratchet")
	w2:advance(1)
	eq(r2.W.Bounty.Mine(), nil, "booking ended it")
	local sent = ws(w2, TESTCHAR)
	eq(#sent, 2, "pin and end")
	eq(wFields(sent[2])[4], "0", "copper 0")
	T.clean(w2)
end)

test("net.bounty: driver demand: 3 riders aggregated, one per sender a minute, faction, place, crew and setting checks", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA)
	local r = T.rider(w)
	T.settle(w)
	local DW = d.W
	local n = 0
	DW.Listen("BOUNTY", function(kind) if kind == "demand" then n = n + 1 end end)
	w:inject(TESTCHAR, "W~1~Gadgetzan~5000~H~30", "CHANNEL")
	w:inject(ANA, "W~1~gz~10000~H~20", "CHANNEL")
	w:inject(BEA, "W~1~Gadgetzan~7500~H~30", "WHISPER", d)
	w:inject(TESTCHAR, "W~1~Gadgetzan~9000~H~30", "CHANNEL") -- a 4th from Wuber within 60 s
	w:inject(CAL, "W~1~Gadgetzan~9000~A~30", "CHANNEL")    -- Alliance
	w:inject(BOB, "W~1~Tanaris~9000~H~30", "CHANNEL")      -- a zone
	w:inject(BOB, "W~1~Free gold here~9000~H~30", "CHANNEL") -- free text
	w:inject(BOB, "W~1~Everlook~abc~H~30", "CHANNEL")      -- a bad number
	w:inject(BOB, "W~1~Everlook~9000~X~30", "CHANNEL")     -- no faction
	local dem = DW.Bounty.Demand()
	eq(#dem, 1, "one place")
	eq(dem[1].place, "Gadgetzan", "Gadgetzan")
	eq(dem[1].riders, 3, "three riders")
	eq(dem[1].low, 7500, "the median")
	eq(dem[1].high, 10000, "the highest")
	eq(DW.bounties.Gadgetzan["wuber testcharacter"].copper, 5000, "Wuber's 4th within 60 s ignored")
	eq(n, 3, "BOUNTY demand per counted one")
	-- the same sender's newer one replaces the older, after a minute; cancels count at once
	w:advance(61)
	w:inject(TESTCHAR, "W~1~Everlook~6000~H~30", "CHANNEL")
	dem = DW.Bounty.Demand()
	eq(#dem, 2, "two places")
	eq(dem[1].place, "Gadgetzan", "the most wanted first") eq(dem[1].riders, 2, "Wuber moved")
	eq(dem[2].place, "Everlook", "Everlook") eq(dem[2].riders, 1, "Wuber")
	w:inject(TESTCHAR, "W~1~Everlook~0~H~1", "CHANNEL")
	eq(#DW.Bounty.Demand(), 1, "a cancel counts at once")
	-- the minutes run out
	w:advance(20 * 60)
	dem = DW.Bounty.Demand()
	eq(dem[1].riders, 1, "Ana's 20 minutes are over")
	w:advance(10 * 60)
	eq(#DW.Bounty.Demand(), 0, "all over")
	T.clean(w)
end)

test("net.bounty: driver demand ignores outliers in the range, the crew, blocked riders, and nothing with the setting off", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA)
	local r = T.rider(w)
	T.settle(w)
	local DW = d.W
	w:inject(TESTCHAR, "W~1~Everlook~5000~H~30", "CHANNEL")
	w:inject(ANA, "W~1~Everlook~6000~H~30", "CHANNEL")
	w:inject(BEA, "W~1~Everlook~900000~H~30", "CHANNEL")
	local dem = DW.Bounty.Demand()
	eq(dem[1].riders, 3, "three riders")
	eq(dem[1].low, 6000, "median")
	eq(dem[1].high, 6000, "90g is over 3 x the median: left out")
	-- blocked
	DW.db.drive = DW.db.drive or {}
	DW.db.drive.blocklist = DW.db.drive.blocklist or {}
	DW.db.drive.blocklist["cal brown"] = { reason = "test" }
	w:inject(CAL, "W~1~Everlook~5000~H~30", "CHANNEL")
	eq(DW.Bounty.Demand()[1].riders, 3, "a blocked rider is not counted")
	-- the driver's own crew (here: the captain)
	DW.Char().captain = "Ana Smith"
	w:advance(61)
	w:inject(ANA, "W~1~Gadgetzan~5000~H~30", "CHANNEL")
	eq(#DW.Bounty.Demand(), 1, "my own crew is not counted")
	DW.Char().captain = ""
	-- the setting
	DW.db.drive.opts = DW.db.drive.opts or {}
	DW.db.drive.opts.watchBounty = false
	w:inject(BOB, "W~1~Gadgetzan~5000~H~30", "CHANNEL")
	eq(#DW.Bounty.Demand(), 1, "Show what riders want off: nothing new heard")
	T.clean(w)
end)

test("net.bounty: an old client doesn't know W (Decode nil, ignored)", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA)
	T.settle(w)
	local BaseMod = d.W.Mod("Net.Base")
	ok(d.W.Decode("W~1~Gadgetzan~5000~H~30"), "this version knows W")
	BaseMod.KINDS.W = nil -- as a 2.2 client
	eq(d.W.Decode("W~1~Gadgetzan~5000~H~30"), nil, "an old client: Decode nil")
	w:inject(T.TESTCHAR, "W~1~Gadgetzan~5000~H~30", "CHANNEL")
	eq(#d.W.Bounty.Demand(), 0, "ignored")
	BaseMod.KINDS.W = true
	T.clean(w)
end)
