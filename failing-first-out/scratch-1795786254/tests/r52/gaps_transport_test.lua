-- Final home: tests/net/transport_test.lua; add it to the per-module list in tests/run.lua.
-- Pins:
--   the contract (registered, deps = Uses, public names) and the whisper check's numbers (Mod.ASK)
--   the token bucket: a full bucket sends four at once, the rest one a second, in order
--   priorities: a ride whisper goes before the whisper fallback, which goes before a shared flight price
--   caps: 12 fallback messages, 3 shared flight prices, a full outbox of 40 (a ride whisper makes room, a price is refused)
--   coalescing: a newer S for the same ride replaces the queued one (also while held by the whisper check)
--   a trial account (every send refused) goes listen-only after three hard fails, then probes every 5 min
--   SendTo refusals (unknown kind, no name, ourselves); groups, invite, summon and Warlock checks fail safe
-- Why it matters to a player: this is the one outbox. If it broke, ride messages would wait behind beacons or
-- shared prices, the game would throttle or drop them, an invite or "summoned" line would arrive twice or late,
-- and a trial account would spam failing sends instead of booking by whisper.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local TESTCHAR, BOB = T.TESTCHAR, "Bob Helper"
local KEY, GUID = "bob helper", "Player-1-bob helper"

-- guard: coverage, fable-2411 draft adopted in r52
test("net.transport: contract (registered, deps, header, public names); the whisper check's numbers", function()
	local W, w, r, Mod = T.contract("Net.Transport", "tests/net/transport_test.lua", {
		["W.FlushQueue"] = "function",
		["W.QueueLength"] = "function",
		["W.SendChannel"] = "function",
		["W.SendTo"] = "function",
		["W.InGroupWith"] = "function",
		["W.Invite"] = "function",
		["W.LeaveGroup"] = "function",
		["W.AcceptInvite"] = "function",
		["W.AcceptSummon"] = "function",
		["W.IsWarlock"] = "function",
		["Mod.enqueue"] = "function",
		["Mod.hideInvitePopup"] = "function",
		["Mod.money"] = "function",
		["Mod.whisperKind"] = "function",
		["Mod.ASK"] = "table",
		["Mod.ask"] = "table",
	})
	eq(Mod.ASK.WAIT, 1, "a held whisper waits 1 s for the game's answer") -- Transport.lua:39
	eq(Mod.ASK.KEEP, 10, "an answer is fresh for 10 s")
	eq(Mod.ASK.SILENT_MAX, 2, "two silences and asking stops")
	eq(Mod.ASK.TEST_KEEP, 60, "a test whisper may wait 60 s")
	eq(Mod.ask.gaveUp, false, "asking is on at load")
	eq(Mod.ask.listening, false, "the whisper-check events are not wired at load") -- Transport.lua:50
	eq(W.QueueLength(), 0, "nothing queued at load")
	T.clean(w)
end)

-- a rider (Wuber) and a bot (Bob Helper) in Orgrimmar; the send bucket is full (30 s quiet after settling)
local function setup(worldOpts)
	local w = T.newWorld(worldOpts)
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	w:advance(30)
	return w, r, r.W.Mod("Net.Transport")
end

-- the texts of Wuber's addon whispers to Bob that the game took (result 0), oldest first
local function sentTo(w, who)
	local out = {}
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBER" and e.result == 0 and e.chatType == "WHISPER" and e.from == TESTCHAR and e.target and e.target:lower():gsub("%-", " ") == who then
			out[#out + 1] = e.text
		end
	end
	return out
end

-- guard: coverage, fable-2411 draft adopted in r52
test("net.transport: a full bucket sends four whispers at once, the rest one a second, in order", function()
	local w, r = setup()
	eq(r.W.QueueLength(), 0, "setup: nothing waiting")
	local before = #sentTo(w, KEY)
	for i = 1, 6 do ok(r.W.SendTo(BOB, "C", "m" .. i), "queued " .. i) end
	eq(#sentTo(w, KEY) - before, 4, "the burst goes at once") -- NETK.BURST 4 (Net/Base.lua:76)
	eq(r.W.QueueLength(), 2, "two wait")
	w:advance(1.2)
	eq(#sentTo(w, KEY) - before, 5, "one more after a second") -- NETK.RATE 1
	w:advance(1.2)
	eq(#sentTo(w, KEY) - before, 6, "the last a second later")
	eq(r.W.QueueLength(), 0, "nothing waits")
	local got = sentTo(w, KEY)
	for i = 1, 6 do ok(got[before + i] and got[before + i]:find("m" .. i, 1, true), "in order: " .. i) end
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("net.transport: a ride whisper jumps the whisper fallback, which jumps a shared flight price", function()
	local w, r, TM = setup()
	for i = 1, 4 do r.W.SendTo(BOB, "C", "burst" .. i) end -- the bucket is empty now
	local before = #sentTo(w, KEY)
	ok(TM.enqueue("WHISPER", BOB, "F", "C~1~flyprice", nil), "a shared flight price (priority 4)") -- Transport.lua:304
	ok(TM.enqueue("WHISPER", BOB, "K", "C~1~fallback", nil), "a fallback message (priority 2)")
	ok(r.W.SendTo(BOB, "C", "ride"), "a ride whisper (priority 1)")
	eq(r.W.QueueLength(), 3, "all three wait")
	w:advance(10)
	local got = sentTo(w, KEY)
	eq(#got - before, 3, "all three went")
	ok(got[before + 1]:find("ride", 1, true), "the ride whisper first")
	ok(got[before + 2]:find("fallback", 1, true), "then the fallback")
	ok(got[before + 3]:find("flyprice", 1, true), "the shared flight price last")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("net.transport: at most 12 fallback and 3 shared-flight-price messages wait; a ride whisper still gets in", function()
	local w, r, TM = setup()
	r.chatLock = true -- nothing leaves while the chat is locked (Transport.lua:195)
	for i = 1, 12 do eq(TM.enqueue("WHISPER", BOB, "K", "C~1~k" .. i, nil), true, "fallback " .. i) end
	local dropped = r.W.net.dropped
	eq(TM.enqueue("WHISPER", BOB, "K", "C~1~k13", nil), false, "the 13th fallback message is dropped") -- NETK.MAX_LOW 12
	eq(r.W.net.dropped, dropped + 1, "counted as dropped")
	for i = 1, 3 do eq(TM.enqueue("WHISPER", BOB, "F", "C~1~f" .. i, nil), true, "price " .. i) end
	eq(TM.enqueue("WHISPER", BOB, "F", "C~1~f4", nil), false, "the 4th shared flight price is dropped") -- NETK.FLY_QUEUED 3
	eq(r.W.SendTo(BOB, "C", "ride"), true, "a ride whisper is never capped")
	eq(r.W.QueueLength(), 16, "12 + 3 + 1 wait")
	local before = #sentTo(w, KEY)
	r.chatLock = false
	w:advance(60)
	eq(r.W.QueueLength(), 0, "all sent after the lock")
	local got = sentTo(w, KEY)
	eq(#got - before, 16, "16 went")
	ok(got[before + 1]:find("ride", 1, true), "the ride whisper first")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("net.transport: a full outbox (40): a ride whisper pushes out the newest channel message, a shared flight price is refused", function()
	local w, r, TM = setup()
	r.chatLock = true
	eq(r.W.QueueLength(), 0, "setup: empty")
	for i = 1, 40 do TM.enqueue("CHANNEL", nil, "D", "D~1~c" .. i, nil) end
	eq(r.W.QueueLength(), 40, "full") -- NETK.MAX_QUEUE 40 (Net/Base.lua:78)
	local dropped = r.W.net.dropped
	eq(r.W.SendTo(BOB, "C", "ride"), true, "the ride whisper gets in")
	eq(r.W.QueueLength(), 40, "still 40: one channel message made room") -- Transport.lua:354-361
	eq(r.W.net.dropped, dropped + 1, "the channel message counted as dropped")
	eq(TM.enqueue("WHISPER", BOB, "F", "C~1~fly", nil), false, "a shared flight price is worse than everything: refused") -- Transport.lua:354
	eq(r.W.net.dropped, dropped + 2, "counted")
	local mark = #w.addonLog
	r.chatLock = false
	w:advance(1.5)
	local first
	for i = mark + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.from == TESTCHAR and e.prefix == "WUBER" then first = e break end
	end
	ok(first and first.chatType == "WHISPER" and first.text:find("ride", 1, true), "the ride whisper leaves first, ahead of 39 channel messages")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("net.transport: a newer S for the same ride replaces the queued one; another ride's S does not", function()
	local w, r = setup()
	r.chatLock = true
	ok(r.W.SendTo(BOB, "S", 7, "invited"), "S 7 invited")
	ok(r.W.SendTo(BOB, "S", 7, "summoned"), "S 7 summoned")
	eq(r.W.QueueLength(), 1, "one message for ride 7") -- coalesce S:7:key (Transport.lua:547)
	ok(r.W.SendTo(BOB, "S", 8, "invited"), "S 8 invited")
	eq(r.W.QueueLength(), 2, "ride 8 is its own message")
	local before = #sentTo(w, KEY)
	r.chatLock = false
	w:advance(5)
	local got = sentTo(w, KEY)
	eq(#got - before, 2, "two went")
	ok(got[before + 1]:find("summoned", 1, true) and not got[before + 1]:find("invited", 1, true), "ride 7: only the newer")
	ok(got[before + 2]:find("invited", 1, true), "ride 8 as queued")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("net.transport: SendTo refuses an unknown kind, no name and ourselves; SendChannel refuses a whisper kind", function()
	local w, r = setup()
	local before = #w.addonLog
	eq(r.W.SendTo(BOB, "Z", "x"), false, "an unknown kind") -- KINDS (Net/Base.lua:98)
	eq(r.W.SendTo(nil, "C", "x"), false, "no name")
	eq(r.W.SendTo("", "C", "x"), false, "an empty name")
	eq(r.W.SendTo(TESTCHAR, "C", "x"), false, "ourselves")
	eq(r.W.SendChannel("C", "x"), false, "C never goes on the channel") -- CHANNEL_KINDS D X Q
	eq(r.W.QueueLength(), 0, "nothing queued")
	eq(#w.addonLog, before, "nothing sent")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("net.transport: a trial account: three refused sends and none ever sent -> listen-only; then one probe every 5 min", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	r.addonFails = true -- the fake game refuses every addon message with GeneralError (9)
	eq(r.W.net.sent, 0, "setup: nothing sent yet")
	for i = 1, 3 do r.W.SendTo(BOB, "C", "try" .. i) end
	eq(r.W.net.cantSend, true, "listen-only after three hard fails") -- Transport.lua:87
	local dropped = r.W.net.dropped
	eq(r.W.SendTo(BOB, "C", "more"), false, "a send inside the 5 min is dropped") -- Transport.lua:321-323
	eq(r.W.net.dropped, dropped + 1, "counted")
	r.addonFails = false
	w:advance(301) -- NETK.CANT_SEND_PROBE 300
	r.W.SendTo(BOB, "C", "probe")
	w:advance(2)
	eq(r.W.net.cantSend, false, "a probe that goes through ends listen-only") -- Transport.lua:177
	ok(r.W.net.sent > 0, "sent")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("net.transport: a refusal that is not the account's fault (not in a group) never makes it listen-only", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	local TM = r.W.Mod("Net.Transport")
	for i = 1, 4 do TM.enqueue("PARTY", nil, "C", "C~1~p" .. i, nil) end -- NotInGroup (5): Transport.lua:183
	ok((r.W.net.failed or 0) >= 4, "the sends really went to the game and were refused")
	eq(r.W.net.hardFails or 0, 0, "no hard fail counted")
	ok(not r.W.net.cantSend, "not listen-only")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("net.transport: while held by the whisper check, a newer S for the same ride replaces the held one", function()
	local w, r = setup({ whisperCheck = { delay = 0.2 } })
	r.W.Drive.customers[KEY] = { guid = GUID }
	local before = #sentTo(w, KEY)
	ok(r.W.SendTo(BOB, "S", 7, "invited"), "held")
	ok(r.W.SendTo(BOB, "S", 7, "summoned"), "joins the held one")
	eq(r.W.QueueLength(), 1, "one held message") -- Transport.lua:552-557
	eq(r.whisperAsked and #r.whisperAsked or 0, 1, "the game asked once")
	w:advance(0.5)
	local got = sentTo(w, KEY)
	eq(#got - before, 1, "one went after the answer")
	ok(got[before + 1]:find("summoned", 1, true), "the newer text")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("net.transport: groups, invites and Warlock checks fail safe", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	eq(d.W.IsWarlock(), true, "the driver is a Warlock")
	eq(r.W.IsWarlock(), false, "the rider is a Mage")
	eq(r.W.InGroupWith(nil), false, "no name")
	eq(r.W.InGroupWith(T.ANITA), false, "not grouped")
	eq(r.W.Invite(nil), false, "no name: no invite")
	r.env.AcceptGroup = false -- (false, not nil: nil leaves the fake game's AcceptGroup reachable through the env's __index; review R2)
	eq(r.W.AcceptInvite(), false, "no AcceptGroup: false")
	r.env.AcceptGroup = function() error("ADDON_ACTION_BLOCKED") end
	eq(r.W.AcceptInvite(), false, "a refused accept: false") -- Transport.lua:645
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("net.transport: AcceptSummon says why it can't: combat, or no summon call", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	r.env.C_SummonInfo = false -- (false, not nil: see the AcceptGroup note; Transport.lua:657-659 fall through on a non-table / non-function)
	r.env.ConfirmSummon = false
	local okS, why = r.W.AcceptSummon()
	eq(okS, false, "no call")
	eq(why, "Click Accept on the game's summon box.", "the line") -- Transport.lua:660
	w:enterCombat(r)
	okS, why = r.W.AcceptSummon()
	eq(okS, false, "in combat")
	eq(why, "Leave combat first.", "the line") -- Transport.lua:656
	T.clean(w)
end)
