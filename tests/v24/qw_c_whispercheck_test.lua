-- Wuber 2.4 quick win C: before a hidden (addon) whisper to a player whose GUID is known, Net.Transport asks the game
-- C_ChatInfo.RequestCanLocalWhisperTarget(guid) and waits (at most ASK.WAIT seconds) for CAN_LOCAL_WHISPER_TARGET_RESPONSE.
-- The fake game has that call by default (the real game has it: PF-062, answers 0 in about 0.2 s); a world made with
-- whisperCheck = { delay = 0.2, silent = ?, wrong = ? } shapes the answer, whisperCheck = false is a game without the call
-- (tests/harness.lua, NewWorld).
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local TESTCHAR, BOB = T.TESTCHAR, "Bob Helper"
local KEY, GUID = "bob helper", "Player-1-bob helper"

-- a rider (Wuber) and a bot (Bob Helper) Wuber knows the GUID of (a Drive customer record); wc: the world's whisperCheck switch
local function setup(wc, opts)
	opts = opts or {}
	local w = T.newWorld({ whisperCheck = wc })
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	w:advance(2)
	if opts.guid ~= false then r.W.Drive.customers[KEY] = { guid = GUID } end
	if opts.offline then w:player(BOB).online = false end
	return w, r, r.W.Mod("Net.Transport")
end

local function sentTo(w, who)
	local out = {}
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBER" and e.result == 0 and e.chatType == "WHISPER" and e.from == TESTCHAR and e.target and e.target:lower():gsub("%-", " ") == who then
			out[#out + 1] = e.text
		end
	end
	return out
end

local function shownNotFound(r)
	local n = 0
	for _, l in ipairs(r.chatShown) do
		if tostring(l.text):find("No player named", 1, true) then n = n + 1 end
	end
	return n
end

local function asked(r) return r.whisperAsked and #r.whisperAsked or 0 end

test("v24 qw c whispercheck: a game without the call (whisperCheck = false): the whisper goes at once as before", function()
	local w, r = setup(false)
	eq(r.env.C_ChatInfo.RequestCanLocalWhisperTarget, nil, "no call in a game without it")
	ok(r.W.SendTo(BOB, "C", "one"), "SendTo says yes")
	eq(#sentTo(w, KEY), 1, "sent at once")
	eq(r.W.QueueLength(), 0, "nothing waits")
	T.clean(w)
end)

test("v24 qw c whispercheck: can whisper: held until the answer, in order, counted in the queue; a second one inside ten seconds does not ask again", function()
	local w, r, TM = setup({ delay = 0.2 })
	ok(r.W.SendTo(BOB, "C", "first"), "first")
	ok(r.W.SendTo(BOB, "C", "second"), "second")
	eq(asked(r), 1, "asked once for both")
	eq(r.whisperAsked[1], GUID, "with the GUID")
	eq(#sentTo(w, KEY), 0, "nothing sent while held")
	eq(r.W.QueueLength(), 2, "W.QueueLength counts the held ones")
	w:advance(0.5)
	local got = sentTo(w, KEY)
	eq(#got, 2, "both sent after the answer")
	ok(got[1] and got[1]:find("first", 1, true) and got[2] and got[2]:find("second", 1, true), "in order")
	eq(r.W.QueueLength(), 0, "nothing waits now")
	ok(r.W.SendTo(BOB, "C", "third"), "third")
	eq(asked(r), 1, "a fresh answer: not asked again")
	eq(#sentTo(w, KEY), 3, "and it goes at once")
	w:advance(11)
	ok(r.W.SendTo(BOB, "C", "fourth"), "fourth")
	eq(asked(r), 2, "after ten seconds the game is asked again")
	w:advance(0.5)
	eq(#sentTo(w, KEY), 4, "sent")
	eq(TM.ask.silent, 0, "no silences")
	T.clean(w)
end)

test("v24 qw c whispercheck: offline the first time: sent as before, the game's line comes back hidden, and offline answers are proven", function()
	local w, r, TM = setup({ delay = 0.2 }, { offline = true })
	local failed0 = w.failedAddonWhispers or 0
	r.W.SendTo(BOB, "C", "hello")
	w:advance(0.5)
	eq(#sentTo(w, KEY), 1, "still sent (not yet proven)")
	w:advance(2)
	eq((w.failedAddonWhispers or 0) - failed0, 1, "the game answered it with its not-found line")
	eq(shownNotFound(r), 0, "the chat frame never shows it")
	eq(TM.ask.proven, true, "offline answers are proven")
	eq(TM.ask.gaveUp, false, "asking goes on")
	w:advance(12)
	eq(TM.ask.gaveUp, false, "and the later timer did not give up")
	T.clean(w)
end)

test("v24 qw c whispercheck: offline after proof: nothing is sent, no line reaches the chat, Wuber reacts as it does to the game's line", function()
	local w, r, TM = setup({ delay = 0.2 }, { offline = true })
	r.W.SendTo(BOB, "C", "hello")
	w:advance(3)
	eq(TM.ask.proven, true, "proven")
	local W = r.W
	W.fallback.offlineUntil[KEY] = nil
	W.drivers[KEY] = { key = KEY, name = BOB, addr = BOB, state = "open", dest = "Orgrimmar" }
	local before, failed = #sentTo(w, KEY), w.failedAddonWhispers
	w:advance(11)
	ok(W.SendTo(BOB, "C", "again"), "SendTo still says yes")
	eq(asked(r), 2, "the game was asked again")
	w:advance(1)
	eq(#sentTo(w, KEY), before, "nothing went to the fake world")
	eq(w.failedAddonWhispers, failed, "so the game printed nothing")
	eq(shownNotFound(r), 0, "no line in the chat frame")
	eq(W.net.notSent, 1, "counted")
	ok(W.fallback.offlineUntil[KEY], "the whisper fallback backs off from them, as it does for the game's line")
	eq(W.drivers[KEY], nil, "the driver is dropped, as the game's line does")
	eq(W.QueueLength(), 0, "nothing waits")
	-- a message inside the fresh ten seconds is dropped the same way, without asking
	W.fallback.offlineUntil[KEY] = nil
	W.SendTo(BOB, "C", "and again")
	eq(asked(r), 2, "no new ask")
	eq(W.net.notSent, 2, "dropped")
	ok(W.fallback.offlineUntil[KEY], "same reaction")
	T.clean(w)
end)

test("v24 qw c whispercheck: a call that never answers: sent after the wait; after two silences no more asking and no more waiting", function()
	local w, r, TM = setup({ silent = true })
	r.W.SendTo(BOB, "C", "one")
	w:advance(0.9)
	eq(#sentTo(w, KEY), 0, "still held")
	w:advance(0.3)
	eq(#sentTo(w, KEY), 1, "sent after the wait")
	eq(TM.ask.silent, 1, "one silence")
	r.W.SendTo(BOB, "C", "two")
	w:advance(1.2)
	eq(#sentTo(w, KEY), 2, "sent")
	eq(TM.ask.gaveUp, true, "asking is given up")
	eq(r.W.net.askSilent, 2, "counted")
	r.W.SendTo(BOB, "C", "three")
	eq(#sentTo(w, KEY), 3, "now it goes at once")
	eq(asked(r), 2, "not asked")
	T.clean(w)
end)

test("v24 qw c whispercheck: a wrong answer (offline for an online player): delivered, no line comes, asking is given up", function()
	local w, r, TM = setup({ delay = 0.2, wrong = true })
	r.W.SendTo(BOB, "C", "hello")
	w:advance(0.5)
	eq(#sentTo(w, KEY), 1, "delivered all the same")
	w:advance(11)
	eq(TM.ask.proven, false, "not proven")
	eq(TM.ask.gaveUp, true, "given up")
	r.W.SendTo(BOB, "C", "later")
	eq(#sentTo(w, KEY), 2, "later whispers go at once")
	eq(asked(r), 1, "without asking")
	T.clean(w)
end)

test("v24 qw c whispercheck: no GUID known: today's path, the game is not asked", function()
	local w, r = setup({ delay = 0.2 }, { guid = false })
	r.W.SendTo(BOB, "C", "hello")
	eq(#sentTo(w, KEY), 1, "sent at once")
	eq(asked(r), 0, "not asked")
	T.clean(w)
end)

test("v24 qw c whispercheck: the GUID of a party member is used when there is no customer record", function()
	local w, r = setup({ delay = 0.2 }, { guid = false })
	w:group({ TESTCHAR, BOB })
	w:advance(1)
	r.W.SendTo(BOB, "C", "hello")
	eq(asked(r), 1, "asked")
	eq(r.whisperAsked[1], GUID, "with the unit's GUID")
	w:advance(0.5)
	eq(#sentTo(w, KEY), 1, "sent after the answer")
	T.clean(w)
end)

test("v24 qw c whispercheck: a message with the same coalesce key replaces the held one", function()
	local w, r = setup({ delay = 0.2 })
	r.W.SendTo(BOB, "S", "ride1", "old")
	r.W.SendTo(BOB, "S", "ride1", "new")
	eq(r.W.QueueLength(), 1, "one held")
	w:advance(0.5)
	local got = sentTo(w, KEY)
	eq(#got, 1, "one sent")
	ok(got[1] and got[1]:find("new", 1, true) and not got[1]:find("old", 1, true), "the newer text: " .. tostring(got[1]))
	T.clean(w)
end)

test("v24 qw c whispercheck: chat locked: not asked", function()
	local w, r = setup({ delay = 0.2 })
	r.chatLock = true
	r.W.SendTo(BOB, "C", "hello")
	eq(asked(r), 0, "not asked")
	eq(r.W.QueueLength(), 1, "queued as today (held back by the lock)")
	r.chatLock = false
	w:advance(2)
	eq(#sentTo(w, KEY), 1, "sent when the lock ends")
	T.clean(w)
end)
