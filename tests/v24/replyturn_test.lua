-- Wuber 2.4, p7 d: one auto-reply whisper per asker across multiple Wuber drivers. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function setupTwoDrivers(spotA, spotB, verB, autoReplyB)
	local w = T.newWorld()
	-- (the lead) T.driver hands no version on (this build's own is a 2.4.0); a window on another Wuber version is
	-- made directly, the way T.rider does it
	local a = T.driver(w, T.ANITA, { spot = spotA })
	local b = verB and w:addClient(T.BOB, { spot = spotB, class = "WARLOCK", version = verB })
		or T.driver(w, T.BOB, { spot = spotB })
	T.settle(w)
	local aDR, bDR = a.W.Drive, b.W.Drive
	aDR.opts().autoInvite = true
	aDR.opts().watchPublic = true
	bDR.opts().autoInvite = true
	bDR.opts().watchPublic = true
	if autoReplyB ~= nil then
		bDR.opts().autoReply = autoReplyB
	end
	ok(aDR.SetOpen(true), "first driver open")
	ok(bDR.SetOpen(true), "second driver open")
	w:advance(30)
	return w, a, b, aDR, bDR, (a.player and a.player.faction) or "Horde"
end

local function sayInTrade(w, faction, name, text)
	w:advance(8) -- r51 SEC-M2: whisper-backs leave 8 s apart, so each asker comes 8 s after the last
	if not w:player(name) then
		w:addBot(name, { spot = "Ratchet", acceptsInvites = false, faction = faction })
	end
	w:chatFrom(name, text, "CHANNEL", "Trade", faction)
	w:advance(0.5)
end

local ASKERS_12 = {
	"Dan Miller", "Eve Stone", "Fay Wood", "Gil Moss",
	"Hal Reed", "Ida Frost", "Jon Vale", "Kay Pine",
	"Leo Marsh", "Mia Shaw", "Ned Cole", "Pat Gray",
}

local ASKERS_6 = {
	"Quin Bell", "Ray Holt", "Sam Ward",
	"Tim Park", "Una Lane", "Vic Hale",
}

test("v24 replyturn: two drivers in one city, each asker gets one whisper in all", function()
	local w, a, b, aDR, bDR, faction = setupTwoDrivers("Orgrimmar", "Orgrimmar")
	local aKey, bKey = a.W.Key(T.ANITA), a.W.Key(T.BOB)
	ok(a.W.drivers[bKey] and a.W.drivers[bKey].state == "open", "Anita sees Bob open")
	ok(b.W.drivers[aKey] and b.W.drivers[aKey].state == "open", "Bob sees Anita open")

	local fromA, fromB = 0, 0
	for _, name in ipairs(ASKERS_12) do
		sayInTrade(w, faction, name, "WTB summon to Orgrimmar")
		local replies = w:whispersTo(name, "reply")
		eq(#replies, 1, "exactly one reply whisper for " .. name)
		local sender = replies[1] and replies[1].from
		local k = key(name)
		if sender == a.player.name then
			fromA = fromA + 1
			ok(not (bDR.db and bDR.db.replied and bDR.db.replied[k]), "Bob did not record a stamp for " .. name)
		elseif sender == b.player.name then
			fromB = fromB + 1
			ok(not (aDR.db and aDR.db.replied and aDR.db.replied[k]), "Anita did not record a stamp for " .. name)
		else
			ok(false, "reply came from one of the two drivers for " .. name)
		end
	end
	ok(fromA >= 1, "first driver answered at least one asker")
	ok(fromB >= 1, "second driver answered at least one asker")
	eq(fromA + fromB, 12, "all twelve askers answered by the two drivers")
	T.clean(w)
end)

test("v24 replyturn: both drivers agree whose turn it is", function()
	local w, a, b, aDR, bDR = setupTwoDrivers("Orgrimmar", "Orgrimmar")
	local aKey, bKey = a.W.Key(T.ANITA), a.W.Key(T.BOB)
	ok(a.W.drivers[bKey] and a.W.drivers[bKey].state == "open", "Anita sees Bob open")
	ok(b.W.drivers[aKey] and b.W.drivers[aKey].state == "open", "Bob sees Anita open")

	for _, name in ipairs(ASKERS_12) do
		local k = a.W.Key(name)
		local a1, whyA = aDR.ReplyTurn(k, "Orgrimmar")
		local b1, whyB = bDR.ReplyTurn(k, "Orgrimmar")
		ok((a1 == true and b1 == false) or (a1 == false and b1 == true), "exactly one driver has the turn for " .. k)
		if not a1 then
			eq(whyA, "another driver's turn", "Anita gives turn reason")
		end
		if not b1 then
			eq(whyB, "another driver's turn", "Bob gives turn reason")
		end
		local a2 = aDR.ReplyTurn(k, "Orgrimmar")
		local b2 = bDR.ReplyTurn(k, "Orgrimmar")
		eq(a2, a1, "Anita repeats the same decision for " .. k)
		eq(b2, b1, "Bob repeats the same decision for " .. k)
	end
	T.clean(w)
end)

test("v24 replyturn: a driver who is closed, elsewhere or on an older Wuber takes no turn", function()
	-- case 1: second driver closes
	do
		local w, a, b, _, bDR, faction = setupTwoDrivers("Orgrimmar", "Orgrimmar")
		local bKey = a.W.Key(T.BOB)
		ok(a.W.drivers[bKey] and a.W.drivers[bKey].state == "open", "Anita sees Bob open before close")
		bDR.SetOpen(false)
		w:advance(30)
		ok(not a.W.drivers[bKey] or a.W.drivers[bKey].state ~= "open", "Anita sees Bob is no longer open")
		for _, name in ipairs(ASKERS_6) do
			sayInTrade(w, faction, name, "WTB summon to Orgrimmar")
			local replies = w:whispersTo(name, "reply")
			eq(#replies, 1, "closed case: one reply whisper for " .. name)
			eq(replies[1] and replies[1].from, a.player.name, "closed case: Anita sent the whisper to " .. name)
		end
		T.clean(w)
	end

	-- case 2: second driver is open at another city
	do
		local w, a, _, _, _, faction = setupTwoDrivers("Orgrimmar", "Undercity")
		local bKey = a.W.Key(T.BOB)
		ok(a.W.drivers[bKey] and a.W.drivers[bKey].state == "open", "Anita sees Bob open at Undercity")
		for _, name in ipairs(ASKERS_6) do
			sayInTrade(w, faction, name, "WTB summon to Orgrimmar")
			local replies = w:whispersTo(name, "reply")
			eq(#replies, 1, "elsewhere case: one reply whisper for " .. name)
			eq(replies[1] and replies[1].from, a.player.name, "elsewhere case: Anita sent the whisper to " .. name)
		end
		T.clean(w)
	end

	-- case 3: second driver is on an older Wuber (2.3.4 had no auto-reply)
	do
		local w, a, _, aDR, _, faction = setupTwoDrivers("Orgrimmar", "Orgrimmar", "2.3.4", false)
		local bKey = a.W.Key(T.BOB)
		ok(a.W.drivers[bKey] and a.W.drivers[bKey].state == "open", "Anita sees Bob open on 2.3.4")
		eq(a.W.drivers[bKey] and a.W.drivers[bKey].ver, "2.3.4", "Anita sees Bob version 2.3.4")
		for _, name in ipairs(ASKERS_6) do
			ok(aDR.ReplyTurn(a.W.Key(name), "Orgrimmar") == true, "older Wuber case: Anita takes turn for " .. name)
			sayInTrade(w, faction, name, "WTB summon to Orgrimmar")
			local replies = w:whispersTo(name, "reply")
			eq(#replies, 1, "older Wuber case: one reply whisper for " .. name)
			eq(replies[1] and replies[1].from, a.player.name, "older Wuber case: Anita sent the whisper to " .. name)
		end
		T.clean(w)
	end
end)
