-- Guard tests for Wuber/Net/Requests.lua and Wuber/Net/Rides.lua (Big Batch 2, H2).
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local TESTCHAR, ANITA, BOB = T.TESTCHAR, T.ANITA, "Bob Helper"

-- guards Wuber/Net/Requests.lua:67 (negate the if)
test("mutation b2 requests: RestoreFinished restores recent finished rides so late ratings count", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	w:addBot(BOB, { spot = "Ratchet" })
	T.settle(w)
	local ratings = 0
	d.W.Listen("RATING", function() ratings = ratings + 1 end)
	d.W.db.netFinished = { { id = "AbCdEf", key = "bob helper", at = d.env.time() - 10 } }
	d.W.RestoreFinished()
	w:inject(BOB, d.W.Encode("T", "AbCdEf", 5), "WHISPER", d)
	w:advance(1)
	eq(ratings, 1, "restored finished ride accepts the rider's late rating")
	T.clean(w)
end)

-- Skipped Wuber/Net/Requests.lua:82 (return true instead of false): removeIncoming's only caller
-- that checks its return value (DeclineRequest) just found r in W.incoming, so the not-found
-- return false is unreachable from outside.

-- guards Wuber/Net/Requests.lua:105 (delete the line)
test("mutation b2 requests: RestoreIncoming rejects an invalid ride id", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	eq(d.W.RestoreIncoming("bad-id!", BOB, "Orgrimmar", 5000, "accepted"), false, "invalid ride id is refused")
	eq(#d.W.incoming, 0, "nothing added to incoming")
	T.clean(w)
end)

-- guards Wuber/Net/Requests.lua:108 (or to and)
test("mutation b2 requests: RestoreIncoming refuses missing id or duplicate incoming request", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	eq(d.W.RestoreIncoming(nil, BOB, "Orgrimmar", 5000, "accepted"), false, "missing id is refused even with a valid buyer")
	eq(d.W.RestoreIncoming("AbCdEf", BOB, "Orgrimmar", 5000, "accepted"), true, "valid request is restored")
	eq(d.W.RestoreIncoming("AbCdEf", BOB, "Orgrimmar", 5000, "accepted"), false, "duplicate id and buyer is refused")
	eq(#d.W.incoming, 1, "only one copy in incoming")
	T.clean(w)
end)

-- guards Wuber/Net/Requests.lua:109 (delete the line)
test("mutation b2 requests: RestoreIncoming cleans the rider version suffix", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	eq(d.W.RestoreIncoming("AbCdEf", BOB, "Orgrimmar", 5000, "accepted", "2.3.3-rc1"), true, "restored")
	eq(d.W.incoming[1].riderVer, "2.3.3", "prerelease suffix is stripped from riderVer")
	T.clean(w)
end)

-- guards Wuber/Net/Requests.lua:111 (or to and)
-- guards Wuber/Net/Requests.lua:113 (return true instead of false)
test("mutation b2 requests: RestoreIncoming remembers paid or done rides for ratings and returns false", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	w:addBot(BOB, { spot = "Ratchet" })
	T.settle(w)
	local ratings = 0
	d.W.Listen("RATING", function() ratings = ratings + 1 end)
	eq(d.W.RestoreIncoming("AbCdEf", BOB, "Orgrimmar", 5000, "paid"), false, "paid ride is not put back in incoming")
	eq(#d.W.incoming, 0, "incoming stays empty")
	w:inject(BOB, d.W.Encode("T", "AbCdEf", 5), "WHISPER", d)
	w:advance(1)
	eq(ratings, 1, "remembered paid ride still accepts the rider's rating")
	T.clean(w)
end)

-- guards Wuber/Net/Requests.lua:121 (return nil)
test("mutation b2 requests: RestoreIncoming returns true when a ride is restored", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	eq(d.W.RestoreIncoming("AbCdEf", BOB, "Orgrimmar", 5000, "accepted"), true, "returns true, not nil")
	T.clean(w)
end)

-- guards Wuber/Net/Requests.lua:135 (delete the line)
test("mutation b2 requests: closed driver throttles repeated closed replies to the same rider", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	w:addBot(BOB, { spot = "Ratchet" })
	T.settle(w)
	local mark = #w.addonLog
	w:inject(BOB, d.W.Encode("R", "AbCdEf", "Orgrimmar", 5000), "WHISPER", d)
	w:advance(1)
	w:inject(BOB, d.W.Encode("R", "GhIjKl", "Orgrimmar", 5000), "WHISPER", d)
	w:advance(1)
	local closed = 0
	for i = mark + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.prefix == "WUBER" and e.from == ANITA and e.chatType == "WHISPER" and tostring(e.text):match("^N~.*~closed$") then
			closed = closed + 1
		end
	end
	eq(closed, 1, "only one N closed reply within 10 seconds")
	T.clean(w)
end)

-- guards Wuber/Net/Requests.lua:259 (delete the line)
test("mutation b2 requests: AcceptRequest falls back to driver beacon price when no price is given", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { spot = "Orgrimmar" })
	w:addBot(BOB, { spot = "Ratchet" })
	T.settle(w)
	local mark = #w.addonLog
	eq(d.W.AcceptRequest("AbCdEf", 10, BOB), true, "accepted without an explicit price or incoming entry")
	w:advance(1)
	local sentA
	for i = mark + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.prefix == "WUBER" and e.from == ANITA and e.chatType == "WHISPER" and tostring(e.text):match("^A~") then
			sentA = e.text
		end
	end
	ok(sentA ~= nil, "A whisper was sent")
	local _, _, f = d.W.Decode(sentA)
	eq(tonumber(f[2]), 0, "fallback price is encoded as 0, not omitted")
	T.clean(w)
end)

-- guards Wuber/Net/Rides.lua:331 (and to or)
test("mutation b2 rides: CancelMacro returns nil when driver name has no valid macro target", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	r.W.ride = { id = "AbCdEf", state = "accepted", driver = "" }
	eq(r.W.CancelMacro(), nil, "empty driver name yields nil instead of concatenating nil")
	T.clean(w)
end)

-- guards Wuber/Net/Rides.lua:332 (return nil)
test("mutation b2 rides: CancelMacro builds the cancel whisper macro for an active ride", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	r.W.ride = { id = "AbCdEf", state = "accepted", driver = ANITA }
	eq(r.W.CancelMacro(), "/w Anita-Lift Sorry, I have to cancel - thanks anyway", "returns the /w macro")
	T.clean(w)
end)

-- guards Wuber/Net/Rides.lua:634 (or to and)
test("mutation b2 rides: delayed summoner lookup stops if the summon is cancelled", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local name = ""
	r.env.C_SummonInfo = r.env.C_SummonInfo or {}
	r.env.C_SummonInfo.GetSummonConfirmSummoner = function() return name end
	local ride = { id = "AbCdEf", state = "summoning", driverKey = "anita lift", driver = ANITA, at = r.W.Now() }
	r.W.ride = ride
	r:fire("CONFIRM_SUMMON")
	eq(ride.summonNoName, true, "initially unknown summoner")
	r:fire("CANCEL_SUMMON")
	name = BOB
	w:advance(2)
	eq(ride.summonedBy, nil, "cancelled summon does not record a late summoner")
	T.clean(w)
end)

-- guards Wuber/Net/Rides.lua:638 (delete the line)
test("mutation b2 rides: delayed summoner lookup clears summonNoName once the name arrives", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local name = ""
	r.env.C_SummonInfo = r.env.C_SummonInfo or {}
	r.env.C_SummonInfo.GetSummonConfirmSummoner = function() return name end
	local ride = { id = "AbCdEf", state = "summoning", driverKey = "anita lift", driver = ANITA, at = r.W.Now() }
	r.W.ride = ride
	r:fire("CONFIRM_SUMMON")
	eq(ride.summonNoName, true, "initially unknown summoner")
	name = BOB
	w:advance(2)
	eq(ride.summonedBy, "bob helper", "late summoner recorded")
	eq(ride.summonNoName, nil, "summonNoName cleared once summoner is known")
	T.clean(w)
end)

-- guards Wuber/Net/Rides.lua:761 (or to and)
test("mutation b2 rides: PayFare records moneyBefore so TRADE_CLOSED can count the payment", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR, { money = 10000 })
	T.settle(w)
	r.W.ride = { id = "AbCdEf", state = "arrived", driverKey = "anita lift", driver = ANITA, price = 5000, at = r.W.Now() }
	r.W.tradeOpen = true
	r.env.UnitName = function(unit) if unit == "npc" then return ANITA end return TESTCHAR end
	local okp = r.W.PayFare()
	eq(okp, true, "PayFare succeeds")
	ok(r.W.ride.moneyBefore ~= nil, "moneyBefore is recorded on first PayFare")
	T.clean(w)
end)

-- guards Wuber/Net/Rides.lua:875 (or to and)
test("mutation b2 rides: trade failure clears moneyBefore when the trade window is already closed", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR, { money = 10000 })
	T.settle(w)
	r.W.ride = { id = "AbCdEf", state = "arrived", driverKey = "anita lift", driver = ANITA, price = 5000, at = r.W.Now(), moneyBefore = 10000 }
	r.W.tradeOpen = false
	r.env.ERR_TRADE_CANCELLED = "Trade cancelled."
	r:fire("UI_ERROR_MESSAGE", 0, "Trade cancelled.")
	eq(r.W.ride.moneyBefore, nil, "moneyBefore cleared even when tradeClosedAt was not set")
	T.clean(w)
end)
