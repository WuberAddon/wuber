-- Mentions of "wuber" in public chat (any form, no "[Wuber]" tag): the sender gets ONE hidden addon-whisper Q, within
-- NETK.MENTION_*; a mention is never an advert. Loaded by tests/run.lua with its helper table T (folder found by itself).
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local newWorld, driver, rider, settle, goOnline, clean, msgs = T.newWorld, T.driver, T.rider, T.settle, T.goOnline, T.clean, T.msgs
local TESTCHAR, BOB = T.TESTCHAR, T.BOB
local EVE = "Eve Vile"

local function qs(w, to)
	local n = 0
	for _, e in ipairs(msgs(w, "Q", TESTCHAR, "WHISPER")) do
		if H.key(e.target) == H.key(to) then n = n + 1 end
	end
	return n
end

local function totalQ(w) return #msgs(w, "Q", TESTCHAR, "WHISPER") end

local function fired(c, name)
	local n = 0
	for _, e in ipairs(c.fired or {}) do if e.name == name then n = n + 1 end end
	return n
end

-- a rider past its first minute, Eve's Q count at zero
local function calm(opts)
	local w = newWorld(opts)
	local r = rider(w)
	settle(w, 90)
	return w, r
end

local function sayAll(w, who, line) for _, n in ipairs(who) do w:chatFrom(n, line, "CHANNEL", "Trade") end end

test("mention: every form of the word asks its sender once; the tag still takes the advert path; near misses do nothing", function()
	local w, r = calm()
	local lines = { { "Ann One", "Wuber" }, { "Ben Two", "WUBER" }, { "Cat Three", "does anyone use wuber's list?" }, { "Dan Four", "Wubers are cool" },
		{ "Eli Five", "wuberaddon is nice" }, { "Fay Six", "wuber-" } }
	for _, l in ipairs(lines) do
		w:chatFrom(l[1], l[2], "CHANNEL", "Trade")
		w:advance(16)
		eq(qs(w, l[1]), 1, l[2] .. ": one Q to " .. l[1])
	end
	local before = totalQ(w)
	w:chatFrom("Gus Seven", "wubba lubba", "CHANNEL", "Trade")
	w:chatFrom("Hal Eight", "an uber warlock", "CHANNEL", "Trade")
	w:advance(30)
	eq(totalQ(w), before, "wubba and uber: no Q")
	-- the tag: advert path (an unconfirmed name, counted, ADVERT fired)
	w:chatFrom("Ivy Nine", "[Wuber] Summons to Ratchet", "CHANNEL", "Trade")
	w:advance(1)
	ok(r.W.fallback.advertHeard["ivy nine"], "a tagged line is an advert")
	eq(r.W.net.advertsHeard, 1, "counted as an advert")
	clean(w)
end)

test("mention: never an advert (no unconfirmed name, no advertHeard, no count, no ADVERT event, no confirm round)", function()
	local w, r = calm()
	w:chatFrom(EVE, "wuber anyone?", "CHANNEL", "Trade")
	w:advance(1)
	eq(r.W.fallback.advertHeard["eve vile"], nil, "not advertHeard")
	eq(r.W.fallback.unconfirmed["eve vile"], nil, "not unconfirmed")
	eq(r.W.net.advertsHeard, 0, "not counted")
	eq(fired(r, "ADVERT"), 0, "no ADVERT event")
	eq(r.W.Mod("Net.Discovery").round.confirmAt, nil, "no confirm round planned")
	w:advance(30)
	eq(qs(w, EVE), 1, "but one Q")
	eq(r.W.fallback.advertHeard["eve vile"], nil, "still not advertHeard")
	clean(w)
end)

test("mention: one Q per name per hour; an hour later one more", function()
	local w, r = calm()
	w:chatFrom(EVE, "wuberaddon?", "CHANNEL", "Trade")
	w:advance(20)
	eq(qs(w, EVE), 1, "first mention")
	w:chatFrom(EVE, "wuber again", "SAY")
	w:chatFrom(EVE, "wuber again", "YELL")
	w:advance(3000)
	eq(qs(w, EVE), 1, "within the hour: none")
	w:advance(700)
	w:chatFrom(EVE, "wuber's", "CHANNEL", "Trade")
	w:advance(20)
	eq(qs(w, EVE), 2, "after an hour: one more")
	clean(w)
end)

test("mention: 12 Qs an hour in all, and 10 s apart", function()
	local w, r = calm()
	for i = 1, 14 do
		w:chatFrom("Bot" .. string.char(64 + i) .. " Test", "wuber", "CHANNEL", "Trade")
		w:advance(16)
	end
	eq(totalQ(w), 12, "the 13th and 14th name got none")
	-- 10 s step: three at once leave at least 10 s apart
	local w2, r2 = calm()
	for _, n in ipairs({ "Ann One", "Ben Two", "Cat Three" }) do w2:chatFrom(n, "wuber", "CHANNEL", "Trade") end
	local seen, when = {}, {}
	for s = 1, 60 do
		w2:advance(1)
		for _, n in ipairs({ "Ann One", "Ben Two", "Cat Three" }) do
			if not seen[n] and qs(w2, n) > 0 then seen[n] = true when[#when + 1] = s end
		end
	end
	eq(#when, 3, "all three asked in the end")
	table.sort(when)
	ok(when[2] - when[1] >= 9, "second Q 10 s after the first: " .. table.concat(when, ","))
	ok(when[3] - when[2] >= 9, "third Q 10 s after the second: " .. table.concat(when, ","))
	ok(when[1] >= 3, "not at once: " .. tostring(when[1]))
	clean(w)
	clean(w2)
end)

test("mention: at most 5 wait; the rest are dropped", function()
	local w, r = calm()
	for i = 1, 8 do w:chatFrom("Nobody" .. string.char(64 + i) .. " Test", "wuber", "CHANNEL", "Trade") end
	w:advance(200)
	eq(totalQ(w), 5, "five Qs, three mentions dropped")
	clean(w)
end)

test("mention: nothing in combat, in a raid or in an instance, and nothing is kept for later", function()
	local w, r = calm()
	r.player.combat = true
	w:chatFrom("Ann One", "wuber", "CHANNEL", "Trade")
	r.player.combat = false
	r.player.group = { leader = TESTCHAR, members = { TESTCHAR }, raid = true }
	w:chatFrom("Ben Two", "wuber", "CHANNEL", "Trade")
	r.player.group = nil
	r.player.instance = true
	w:chatFrom("Cat Three", "wuber", "CHANNEL", "Trade")
	r.player.instance = nil
	w:advance(60)
	eq(totalQ(w), 0, "nothing sent, nothing queued for later")
	-- and the same checks again when the send is due
	w:chatFrom("Dan Four", "wuber", "CHANNEL", "Trade")
	r.player.combat = true
	w:advance(30)
	r.player.combat = false
	eq(qs(w, "Dan Four"), 0, "combat at send time: dropped")
	w:chatFrom("Eli Five", "wuber", "CHANNEL", "Trade")
	r.player.instance = true
	w:advance(30)
	r.player.instance = nil
	eq(qs(w, "Eli Five"), 0, "instance at send time: dropped")
	w:advance(60)
	eq(totalQ(w), 0, "still nothing after")
	clean(w)
end)

test("mention: none in the first minute after login; a name from then is asked later", function()
	local w = newWorld()
	local r = rider(w)
	w:advance(5)
	w:chatFrom(EVE, "wuber", "CHANNEL", "Trade")
	w:advance(30)
	eq(qs(w, EVE), 0, "30 s after login: none")
	w:advance(60)
	w:chatFrom(EVE, "wuber", "CHANNEL", "Trade")
	w:advance(20)
	eq(qs(w, EVE), 1, "after the first minute: one")
	clean(w)
end)

-- guard: on the old code "wuber's" is a bare word that already asked its sender only; this pins hidden/ourselves/text-name rules for the new path
test("mention: hidden, listed, ourselves, our own channel and a text name get no Q; the sender only is asked", function()
	local w, r = calm()
	r.W.db.hidden = { ["eve vile"] = true }
	w:chatFrom(EVE, "wuber", "CHANNEL", "Trade")
	r.W.HeardChatLine("wuber", TESTCHAR, "Trade", "Trade")
	w:advance(30)
	eq(qs(w, EVE), 0, "a hidden name gets none")
	eq(qs(w, TESTCHAR), 0, "not ourselves")
	r.W.db.hidden = {}
	w:chatFrom(EVE, "ask Bob Stone about wuber's addon", "CHANNEL", "Trade")
	w:advance(30)
	eq(qs(w, EVE), 1, "the sender is asked")
	eq(qs(w, BOB), 0, "a name in the text never is")
	clean(w)
end)

test("mention: a real driver who answers is listed by WHISPER", function()
	local w = newWorld()
	local d = driver(w, BOB)
	local r = rider(w)
	w:splitChannel(d, "other")
	settle(w, 20)
	goOnline(d)
	w:advance(5)
	eq(r.W.drivers["bob stone"], nil, "not heard on the channel")
	w:advance(60)
	w:chatFrom(BOB, "does wuberaddon work here?", "CHANNEL", "Trade")
	w:advance(20)
	ok(qs(w, BOB) >= 1, "Bob was asked")
	local x = r.W.drivers["bob stone"]
	ok(x, "listed after his own D")
	eq(x and x.via, "WHISPER", "by whisper")
	clean(w)
end)

test("mention: a driver on another layer, heard in a channel, is found by the Q (addon whispers cross layers)", function()
	local w = newWorld()
	local d = driver(w, BOB)
	local r = rider(w)
	d.layer = 2
	w:splitChannel(d, "other")
	settle(w, 20)
	goOnline(d)
	w:advance(65)
	local seenSay = 0
	for _, e in ipairs(r.fired or {}) do if e.name == "CHAT_MSG_SAY" then seenSay = seenSay + 1 end end
	w:publicLine(BOB, "Horde", "wuberaddon here", "SAY", nil, "user", d)
	w:advance(2)
	eq(r.W.drivers["bob stone"], nil, "/say stays within layer 2")
	eq(qs(w, BOB), 0, "so no Q from a /say he made on his layer")
	w:chatFrom(BOB, "any wuberaddon drivers on this layer?", "CHANNEL", "Trade")
	w:advance(20)
	ok(qs(w, BOB) >= 1, "the channel line asked him")
	local x = r.W.drivers["bob stone"]
	ok(x, "found across layers")
	eq(x and x.via, "WHISPER", "by whisper")
	clean(w)
end)
