-- Decision #109 (the reply gap): the guard tests that pin option A, "nobody answers inside the gap". Two open Wuber drivers
-- stand in Orgrimmar. A buyer who asks within DR.REPLY_GAP (8 s) of the driver's last whisper back, when it is that driver's
-- turn, gets no whisper from either driver and stays a lead. See Wuber/Drive/AutoReply.lua (header, underCap, ReplyTurn).
-- Loaded by tests/run.lua (tests/dec/*_test.lua) with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local PLACE = "Orgrimmar"
local LINE = "WTB summon to " .. PLACE

-- two open drivers at the same place, each beaconing to the other
local function twoDrivers()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = PLACE })
	local b = T.driver(w, T.BOB, { spot = PLACE })
	T.settle(w)
	for _, d in ipairs({ a, b }) do
		local DR = d.W.Drive
		DR.opts().autoInvite = true
		DR.opts().watchPublic = true
		ok(DR.SetOpen(true), "driver open in " .. PLACE)
	end
	w:advance(35)
	ok(a.W.drivers[a.W.Key(T.BOB)] and b.W.drivers[b.W.Key(T.ANITA)], "each driver sees the other as open")
	return w, a, b, a.player.faction
end

-- buyers whose turn is a's: asker names are tried in order, so the same names serve every run
local function buyersForA(a, n)
	local out = {}
	for i = 1, 60 do
		local name = "Buyer" .. string.char(96 + (i - 1) % 26 + 1) .. string.char(96 + math.floor((i - 1) / 26) + 1) .. " Test"
		if a.W.Drive.ReplyTurn(a.W.Key(name), PLACE) then out[#out + 1] = name end
		if #out == n then return out end
	end
	error("not enough buyers whose turn is the first driver")
end

local function say(w, faction, name)
	if not w:player(name) then w:addBot(name, { spot = "Ratchet", acceptsInvites = false, faction = faction }) end
	w:chatFrom(name, LINE, "CHANNEL", "Trade", faction)
end

local function whispers(w, name) return #w:whispersTo(name, "reply") end

-- guard: decision #109, pins today's reply-gap behaviour
test("#109 guard: a buyer asking inside the 8 s gap gets no whisper from either driver and stays a lead", function()
	local w, a, b, faction = twoDrivers()
	eq(a.W.Drive.REPLY_GAP, 8, "the gap is 8 seconds")
	local first, second = unpack(buyersForA(a, 2))
	say(w, faction, first)
	w:advance(5)
	eq(whispers(w, first), 1, "the first buyer is answered by the driver whose turn it is")
	say(w, faction, second)
	w:advance(2)
	eq(whispers(w, second), 0, "the second buyer, 5 s later, got a whisper from a driver")
	for _, d in ipairs({ a, b }) do
		local c = d.W.Drive.customers[d.W.Key(second)]
		ok(c and c.state == "lead", d.player.name .. ": the unanswered buyer is not a lead in the console")
	end
	T.clean(w)
end)

-- guard: decision #109, pins today's reply-gap behaviour
test("#109 guard: inside the gap the decline reasons are the documented ones", function()
	local w, a, b, faction = twoDrivers()
	local first, second, third = unpack(buyersForA(a, 3))
	say(w, faction, first)
	w:advance(5)
	eq(whispers(w, first), 1, "the first buyer is answered")
	say(w, faction, second)
	w:advance(1)
	-- the driver whose turn it is stands inside its gap; the other driver is not the one in turn
	local okA, whyA = a.W.Drive.TryReply(third, LINE, "invite")
	eq(okA, false, "the driver in turn answered inside the gap")
	eq(whyA, "too soon after the last whisper back", "the turn-holder's reason")
	local okB, whyB = b.W.Drive.TryReply(third, LINE, "invite")
	eq(okB, false, "the other driver answered in the turn-holder's place")
	eq(whyB, "another driver's turn", "the other driver's reason")
	eq(whispers(w, third), 0, "no whisper went to a buyer who never asked")
	T.clean(w)
end)

-- guard: decision #109, pins today's reply-gap behaviour
test("#109 guard: a buyer asking 9 s after the last gets exactly one whisper between the two drivers", function()
	local w, a, b, faction = twoDrivers()
	local first, second = unpack(buyersForA(a, 2))
	say(w, faction, first)
	w:advance(9)
	say(w, faction, second)
	w:advance(2)
	eq(whispers(w, first), 1, "the first buyer's whispers")
	eq(whispers(w, second), 1, "the second buyer, 9 s later, got " .. whispers(w, second) .. " whispers instead of one")
	T.clean(w)
end)

-- guard: decision #109, pins today's reply-gap behaviour
test("#109 guard: for spacings of 0 to 12 s no buyer is ever whispered twice, and none is answered inside the gap", function()
	for spacing = 0, 12 do
		local w, a, b, faction = twoDrivers()
		local first, second = unpack(buyersForA(a, 2))
		say(w, faction, first)
		w:advance(spacing)
		say(w, faction, second)
		w:advance(3)
		for _, name in ipairs({ first, second }) do
			ok(whispers(w, name) <= 1, "spacing " .. spacing .. " s: " .. name .. " got " .. whispers(w, name) .. " whispers")
		end
		if spacing < 8 then eq(whispers(w, second), 0, "spacing " .. spacing .. " s: answered inside the gap") end
		if spacing > 8 then eq(whispers(w, second), 1, "spacing " .. spacing .. " s: not answered after the gap") end
		T.clean(w)
	end
end)
