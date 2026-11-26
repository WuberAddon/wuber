-- Guard tests for Wuber/Net/Transport.lua unprotected lines.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local TESTCHAR, BOB, CAL = T.TESTCHAR, "Bob Helper", "Cal Stone"

-- guards Wuber/Net/Transport.lua:638 (drop statement name = address(name): control-only name is passed to InviteUnit instead of returning false)
test("mutation b4 transport: W.Invite rejects blank or control-only names without calling InviteUnit", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local calls = 0
	local got
	r.env.C_PartyInfo = r.env.C_PartyInfo or {}
	r.env.C_PartyInfo.InviteUnit = function(n) calls = calls + 1; got = n end
	eq(r.W.Invite(""), false, "empty name rejected")
	eq(r.W.Invite("\n"), false, "control-only name rejected")
	eq(calls, 0, "InviteUnit not called for invalid name")
	eq(r.W.Invite("Bob\nHelper"), true, "cleaned name accepted")
	eq(got, "Bob Helper", "control characters cleaned before InviteUnit")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:499 (drop statement ask.pendingTest[key] = nil: stale pendingTest flag triggers another test timer on a later online whisper and sets gaveUp)
test("mutation b4 transport: noteTest clears pendingTest so a later online whisper does not arm a false gaveUp timer", function()
	local w = T.newWorld({ whisperCheck = { delay = 0.2 } })
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	w:addBot(CAL, { spot = "Orgrimmar" })
	T.settle(w)
	w:advance(2)
	r.W.Drive.customers["bob helper"] = { guid = "Player-1-bob helper" }
	r.W.Drive.customers["cal stone"] = { guid = "Player-1-cal stone" }
	w:player(BOB).online = false
	r.W.SendTo(BOB, "C", "first")
	w:advance(1)
	w:player(BOB).online = true
	w:advance(11) -- past ASK.KEEP (10s) so fresh cache expires
	r.W.SendTo(BOB, "C", "second-online")
	w:advance(12) -- past NOT_FOUND_WINDOW (10s) + 0.5s
	local asksBefore = r.whisperAsked and #r.whisperAsked or 0
	r.W.SendTo(CAL, "C", "check")
	w:advance(0.5)
	local asksAfter = r.whisperAsked and #r.whisperAsked or 0
	eq(asksAfter, asksBefore + 1, "whisper check still active after later online whisper")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:468 (cmp ==->~= on ERR_CHAT_PLAYER_NOT_FOUND_S: custom format string ignored when proving offline whisper)
test("mutation b4 transport: suppressed offline whisper formats ERR_CHAT_PLAYER_NOT_FOUND_S for system handlers", function()
	local w = T.newWorld({ whisperCheck = { delay = 0.2 } })
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	w:advance(2)
	r.W.Drive.customers["bob helper"] = { guid = "Player-1-bob helper" }
	w:player(BOB).online = false
	r.W.SendTo(BOB, "C", "probe")
	w:advance(1) -- proves offline via game's not-found line
	r.env.ERR_CHAT_PLAYER_NOT_FOUND_S = "Offline target: %s"
	local seen
	r.W.On("CHAT_MSG_SYSTEM", function(msg) seen = msg end)
	r.W.SendTo(BOB, "C", "suppressed")
	w:advance(0.5)
	eq(seen, "Offline target: Bob Helper", "custom ERR_CHAT_PLAYER_NOT_FOUND_S passed to system handlers")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:472 (swap and->or in tellNotFound: malformed format error string is fired to CHAT_MSG_SYSTEM handlers)
test("mutation b4 transport: tellNotFound does not fire CHAT_MSG_SYSTEM when ERR_CHAT_PLAYER_NOT_FOUND_S fails formatting", function()
	local w = T.newWorld({ whisperCheck = { delay = 0.2 } })
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	w:advance(2)
	r.W.Drive.customers["bob helper"] = { guid = "Player-1-bob helper" }
	w:player(BOB).online = false
	r.W.SendTo(BOB, "C", "probe")
	w:advance(1)
	r.env.ERR_CHAT_PLAYER_NOT_FOUND_S = "%d"
	local seen = 0
	r.W.On("CHAT_MSG_SYSTEM", function() seen = seen + 1 end)
	r.W.SendTo(BOB, "C", "suppressed")
	w:advance(0.5)
	eq(seen, 0, "failed string.format does not dispatch CHAT_MSG_SYSTEM")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:156 (drop statement holdUntil = now() + 2: CHAT_LOCKED whisper retries immediately instead of holding 2s)
test("mutation b4 transport: chat-locked normal send holds the queue for 2 seconds", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	w:advance(5)
	local realSend = r.env.C_ChatInfo.SendAddonMessage
	local calls = 0
	r.env.C_ChatInfo.SendAddonMessage = function(prefix, text, chatType, target)
		if chatType == "WHISPER" then
			calls = calls + 1
			if calls == 1 then return 11 end
		end
		return realSend(prefix, text, chatType, target)
	end
	local before = r.W.net.sent
	ok(r.W.SendTo(BOB, "C", "locked"), "whisper queued")
	eq(r.W.net.sent, before, "held on CHAT_LOCKED")
	w:advance(1)
	eq(r.W.net.sent, before, "still held at 1s before 2s hold expires")
	w:advance(1.5)
	eq(r.W.net.sent, before + 1, "sent after 2s lock hold expires")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:279 (drop statement holdUntil = 0 on ENCOUNTER_END: queue stays held after encounter ends)
test("mutation b4 transport: ENCOUNTER_END clears holdUntil so FlushQueue sends immediately", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	w:advance(5)
	local realSend = r.env.C_ChatInfo.SendAddonMessage
	local locked = true
	r.env.C_ChatInfo.SendAddonMessage = function(prefix, text, chatType, target)
		if locked and chatType == "WHISPER" then return 11 end
		return realSend(prefix, text, chatType, target)
	end
	local before = r.W.net.sent
	ok(r.W.SendTo(BOB, "C", "fight"), "whisper queued")
	eq(r.W.net.sent, before, "held while locked")
	locked = false
	r:fire("ENCOUNTER_END", 1, "Boss", 1, 5, 1)
	eq(r.W.net.sent, before + 1, "ENCOUNTER_END clears holdUntil and sends")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:280 (drop statement W.FlushQueue() on ENCOUNTER_END: held messages wait for timer instead of flushing at encounter end)
test("mutation b4 transport: ENCOUNTER_END flushes held messages without waiting for timer", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	w:advance(5)
	r.env.C_ChatInfo.InChatMessagingLockdown = nil
	r:fire("ENCOUNTER_START", 1, "Boss", 1, 5)
	local before = r.W.net.sent
	ok(r.W.SendTo(BOB, "C", "queued-in-fight"), "whisper queued during encounter")
	eq(r.W.net.sent, before, "held during encounter")
	r:fire("ENCOUNTER_END", 1, "Boss", 1, 5, 1)
	eq(r.W.net.sent, before + 1, "flushed immediately on ENCOUNTER_END")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:162 (drop statement W.net.failed = W.net.failed + 1: 10th throttle drops item without counting failure)
-- guards Wuber/Net/Transport.lua:163 (return -> nil on 10th throttle: item stays stuck in queue instead of being removed)
test("mutation b4 transport: normal send throttled 10 times counts failed and leaves queue", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	w:advance(5)
	r.env.C_ChatInfo.SendAddonMessage = function() return 3 end
	local beforeFailed = r.W.net.failed
	ok(r.W.SendTo(BOB, "C", "throttled"), "whisper queued")
	w:advance(20)
	eq(r.W.net.failed, beforeFailed + 1, "10th throttle increments W.net.failed")
	eq(r.W.QueueLength(), 0, "dropped throttled item is removed from queue")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:145 (drop statement W.net.failed = W.net.failed + 1 on SendAddonMessage error)
-- guards Wuber/Net/Transport.lua:147 (return -> nil on SendAddonMessage error: item stays stuck in queue)
test("mutation b4 transport: erroring SendAddonMessage counts failed and removes item from queue", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	w:advance(5)
	r.env.C_ChatInfo.SendAddonMessage = function() error("boom") end
	local beforeFailed = r.W.net.failed
	ok(r.W.SendTo(BOB, "C", "err"), "whisper queued")
	eq(r.W.net.failed, beforeFailed + 1, "error increments W.net.failed")
	eq(r.W.QueueLength(), 0, "errored item removed from queue")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:146 (drop statement noteHardFail(): 3 SendAddonMessage errors never set W.net.cantSend)
-- guards Wuber/Net/Transport.lua:89 (drop statement W.Fire("NETWORK", W.OnNetwork()) in noteHardFail: listeners not notified on cantSend)
test("mutation b4 transport: 3 SendAddonMessage errors set cantSend and fire NETWORK", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	w:advance(5)
	r.W.net.sent = 0
	r.W.net.hardFails = 0
	r.env.C_ChatInfo.SendAddonMessage = function() error("boom") end
	local fired = 0
	r.W.Listen("NETWORK", function() fired = fired + 1 end)
	r.W.SendTo(BOB, "C", "e1")
	r.W.SendTo(BOB, "C", "e2")
	r.W.SendTo(BOB, "C", "e3")
	eq(r.W.net.cantSend, true, "cantSend set after 3 errors")
	eq(fired, 1, "NETWORK event fired on cantSend")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:333 (drop statement W.net.probeAt = now() + NETK.CANT_SEND_PROBE: second message after probe also probes instead of dropping)
test("mutation b4 transport: cantSend probe advances probeAt so an immediate second message is dropped", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	w:advance(5)
	r.W.net.cantSend = true
	r.W.net.probeAt = r.env.GetTime() - 1
	local beforeDropped = r.W.net.dropped
	r.env.C_ChatInfo.SendAddonMessage = function() return 7 end
	eq(r.W.SendTo(BOB, "C", "probe"), true, "first probe allowed")
	eq(r.W.SendTo(BOB, "C", "second"), false, "immediate second message dropped")
	eq(r.W.net.dropped, beforeDropped + 1, "second message counted as dropped")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:178 (drop statement W.Fire("NETWORK", W.OnNetwork()) on cantSend recovery)
test("mutation b4 transport: successful send while cantSend clears cantSend and fires NETWORK", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	w:advance(5)
	r.W.net.cantSend = true
	r.W.net.probeAt = r.env.GetTime() - 1
	local fired = 0
	r.W.Listen("NETWORK", function() fired = fired + 1 end)
	eq(r.W.SendTo(BOB, "C", "recover"), true, "probe sent")
	eq(r.W.net.cantSend, false, "cantSend cleared on success")
	eq(fired, 1, "NETWORK event fired on recovery")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:139 (drop statement W.net.dropped = W.net.dropped + 1 when ChannelIndex is nil at transmit)
-- guards Wuber/Net/Transport.lua:140 (return true->false when ChannelIndex is nil at transmit)
test("mutation b4 transport: queued channel message drops and leaves queue if ChannelIndex disappears", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	w:advance(5)
	r.env.C_ChatInfo.InChatMessagingLockdown = nil
	r:fire("ENCOUNTER_START", 1, "Boss", 1, 5)
	ok(r.W.SendChannel("Q", "Orgrimmar", 10), "channel Q queued during encounter")
	local beforeDropped = r.W.net.dropped
	r.W.ChannelIndex = function() return nil end
	r:fire("ENCOUNTER_END", 1, "Boss", 1, 5, 1)
	eq(r.W.net.dropped, beforeDropped + 1, "dropped when ChannelIndex became nil")
	eq(r.W.QueueLength(), 0, "dropped channel item removed from queue")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:317 (swap and->or in urgent coalesce: non-urgent prio-4 F coalesce hits FLY_QUEUED cap and drops instead of updating in place)
test("mutation b4 transport: non-urgent prio-4 coalesce updates in place even when FLY_QUEUED is full", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	w:advance(5)
	r.env.C_ChatInfo.InChatMessagingLockdown = nil
	r:fire("ENCOUNTER_START", 1, "Boss", 1, 5)
	local enqueue = r.W.Mod("Net.Transport").enqueue
	ok(enqueue("WHISPER", BOB, "F", "f1", "fly:1"), "F1 queued")
	ok(enqueue("WHISPER", BOB, "F", "f2", "fly:2"), "F2 queued")
	ok(enqueue("WHISPER", BOB, "F", "f3", "fly:3"), "F3 queued")
	local beforeDropped = r.W.net.dropped
	ok(enqueue("WHISPER", BOB, "F", "f1-updated", "fly:1"), "coalescing F1 succeeds at FLY_QUEUED cap")
	eq(r.W.net.dropped, beforeDropped, "coalescing F1 did not drop")
	eq(r.W.QueueLength(), 3, "queue still has 3 F items")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:318 (drop statement stale = item: urgent beacon leaves old non-urgent beacon in queue)
-- guards Wuber/Net/Transport.lua:373 (cmp ==->~= in stale removal: urgent beacon removes wrong item or leaves stale beacon)
test("mutation b4 transport: urgent beacon replaces waiting non-urgent beacon without dropping other queued items", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	w:advance(5)
	r.env.C_ChatInfo.InChatMessagingLockdown = nil
	r:fire("ENCOUNTER_START", 1, "Boss", 1, 5)
	ok(r.W.SendTo(BOB, "C", "keep-me"), "prio-1 whisper queued")
	ok(r.W.SendChannel("D", "Orgrimmar", 1454, 1, 0, 0, 0, "open"), "initial beacon queued")
	ok(r.W.SendChannel("D", "Orgrimmar", 1454, 1, 0, 0, 0, "busy"), "urgent beacon queued")
	eq(r.W.QueueLength(), 2, "stale beacon removed, whisper kept")
	local sentChan, sentWhisp = 0, 0
	local realSend = r.env.C_ChatInfo.SendAddonMessage
	r.env.C_ChatInfo.SendAddonMessage = function(prefix, text, chatType, target)
		if chatType == "CHANNEL" then sentChan = sentChan + 1 end
		if chatType == "WHISPER" then sentWhisp = sentWhisp + 1 end
		return realSend(prefix, text, chatType, target)
	end
	r:fire("ENCOUNTER_END", 1, "Boss", 1, 5, 1)
	w:advance(5)
	eq(sentChan, 1, "only the newer urgent beacon was sent")
	eq(sentWhisp, 1, "whisper was not removed by stale cleanup")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:340 (drop statement W.net.dropped = W.net.dropped + 1 when FLY_QUEUED cap reached)
test("mutation b4 transport: queueing a 4th F message drops it and increments W.net.dropped", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	w:advance(5)
	r.env.C_ChatInfo.InChatMessagingLockdown = nil
	r:fire("ENCOUNTER_START", 1, "Boss", 1, 5)
	local enqueue = r.W.Mod("Net.Transport").enqueue
	ok(enqueue("WHISPER", BOB, "F", "f1", "fly:1"), "F1 queued")
	ok(enqueue("WHISPER", BOB, "F", "f2", "fly:2"), "F2 queued")
	ok(enqueue("WHISPER", BOB, "F", "f3", "fly:3"), "F3 queued")
	local beforeDropped = r.W.net.dropped
	eq(enqueue("WHISPER", BOB, "F", "f4", "fly:4"), false, "4th F message rejected")
	eq(r.W.net.dropped, beforeDropped + 1, "4th F message increments W.net.dropped")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:106 (drop statement target = W.CommunityIndex(): sends to CX.TARGET sentinel instead of channel index)
test("mutation b4 transport: community send passes CommunityIndex to SendAddonMessage", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	r.W.CommunityIndex = function() return 7 end
	local gotTarget
	r.env.C_ChatInfo.SendAddonMessage = function(prefix, text, chatType, target)
		gotTarget = target
		return 0
	end
	ok(r.W.Mod("Net.Community").CX.send("Q", "Orgrimmar", 10), "community Q queued")
	eq(gotTarget, 7, "SendAddonMessage received numeric CommunityIndex 7")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:108 (drop statement comm.dropped = comm.dropped + 1 when CommunityIndex becomes nil)
-- guards Wuber/Net/Transport.lua:109 (return true->false when CommunityIndex becomes nil)
test("mutation b4 transport: queued community message drops and leaves queue if CommunityIndex disappears", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	w:advance(5)
	r.W.CommunityIndex = function() return 5 end
	r.env.C_ChatInfo.InChatMessagingLockdown = nil
	r:fire("ENCOUNTER_START", 1, "Boss", 1, 5)
	ok(r.W.Mod("Net.Community").CX.send("Q", "Orgrimmar", 10), "community Q queued")
	r.W.CommunityIndex = function() return nil end
	r:fire("ENCOUNTER_END", 1, "Boss", 1, 5, 1)
	eq(r.W.community.dropped, 1, "community dropped incremented when index disappeared")
	eq(r.W.QueueLength(), 0, "dropped community item removed from queue")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:123 (drop statement comm.dropped = comm.dropped + 1 on 10th community throttle)
test("mutation b4 transport: community send throttled 10 times increments comm.dropped", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	w:advance(5)
	r.W.CommunityIndex = function() return 5 end
	r.env.C_ChatInfo.SendAddonMessage = function() return 3 end
	ok(r.W.Mod("Net.Community").CX.send("Q", "Orgrimmar", 10), "community Q queued")
	w:advance(20)
	eq(r.W.community.dropped, 1, "10th community throttle increments comm.dropped")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:127 (drop statement comm.fails = 0 on community send success)
test("mutation b4 transport: successful community send resets comm.fails to 0", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	w:advance(5)
	r.W.CommunityIndex = function() return 5 end
	r.env.C_ChatInfo.SendAddonMessage = function() return 7 end
	ok(r.W.Mod("Net.Community").CX.send("Q", "Orgrimmar", 10), "first community Q queued")
	eq(r.W.community.fails, 1, "first failure recorded")
	r.env.C_ChatInfo.SendAddonMessage = function() return 0 end
	ok(r.W.Mod("Net.Community").CX.send("Q", "Orgrimmar", 10), "second community Q queued")
	eq(r.W.community.fails, 0, "success resets comm.fails to 0")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:416 (local value -> nil on coalesce in CX.send: duplicate community Qs are not coalesced)
test("mutation b4 transport: CX.send coalesces duplicate queued community Q messages", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	w:advance(5)
	r.W.CommunityIndex = function() return 5 end
	r.env.C_ChatInfo.InChatMessagingLockdown = nil
	r:fire("ENCOUNTER_START", 1, "Boss", 1, 5)
	local CX = r.W.Mod("Net.Community").CX
	ok(CX.send("Q", "Orgrimmar", 10), "first community Q queued")
	ok(CX.send("Q", "Stormwind", 10), "second community Q coalesced")
	eq(r.W.QueueLength(), 1, "only 1 community Q queued")
	T.clean(w)
end)
