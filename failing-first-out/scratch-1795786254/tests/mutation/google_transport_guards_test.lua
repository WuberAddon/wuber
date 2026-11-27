-- Guard tests for Wuber/Net/Transport.lua lines unprotected in commit 1d24ac7.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local TESTCHAR, BOB, CAL = T.TESTCHAR, "Bob Helper", "Cal Stone"

-- guards Wuber/Net/Transport.lua:100 (deleted W.net.failed = W.net.failed + 1)
test("mutation transport: missing SendAddonMessage increments W.net.failed", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	r.env.C_ChatInfo.SendAddonMessage = nil
	local before = r.W.net.failed
	r.W.SendTo(BOB, "C", "hello")
	w:advance(1)
	eq(r.W.net.failed, before + 1, "missing SendAddonMessage counts as failed")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:114 (and to or in if res[1] and n >= 2)
test("mutation transport: community send with no return value records ok (nil), not ok (true)", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	r.W.CommunityIndex = function() return 5 end
	r.env.C_ChatInfo.SendAddonMessage = function() end
	ok(r.W.Mod("Net.Community").CX.send("Q", "Orgrimmar", 10), "community Q queued")
	w:advance(1)
	eq(r.W.community.firstResult, "ok (nil)", "no return value records nil result")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:115 (negated if not res[1] in community transmit)
test("mutation transport: erroring community send counts as failure, not sent", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	r.W.CommunityIndex = function() return 5 end
	r.env.C_ChatInfo.SendAddonMessage = function() error("send error") end
	ok(r.W.Mod("Net.Community").CX.send("Q", "Orgrimmar", 10), "community Q queued")
	w:advance(1)
	eq(r.W.community.fails, 1, "error counted as community failure")
	eq(r.W.community.sent, 0, "error not counted as sent")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:118 (deleted holdUntil = now() + 2 on CHAT_LOCKED)
test("mutation transport: chat-locked community send holds the queue for 2 seconds", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	w:advance(10)
	r.W.CommunityIndex = function() return 5 end
	local calls = 0
	r.env.C_ChatInfo.SendAddonMessage = function()
		calls = calls + 1
		if calls == 1 then return 11 end
		return 0
	end
	ok(r.W.Mod("Net.Community").CX.send("Q", "Orgrimmar", 10), "community Q queued")
	eq(r.W.community.sent, 0, "locked on first attempt")
	w:advance(1)
	eq(r.W.community.sent, 0, "still held at 1s before 2s hold expires")
	w:advance(1.5)
	eq(r.W.community.sent, 1, "sent after the 2s lock hold expires")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:121 (or to and in item.tries = (item.tries or 0) + 1)
test("mutation transport: throttled community send increments tries without error", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	w:advance(10)
	r.W.CommunityIndex = function() return 5 end
	local calls = 0
	r.env.C_ChatInfo.SendAddonMessage = function()
		calls = calls + 1
		if calls == 1 then return 3 end
		return 0
	end
	ok(r.W.Mod("Net.Community").CX.send("Q", "Orgrimmar", 10), "community Q queued")
	w:advance(2)
	eq(r.W.community.sent, 1, "throttled send retried and succeeded")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:122 (< to >= in if item.tries < 10)
test("mutation transport: throttled community send retries instead of dropping on first try", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	w:advance(10)
	r.W.CommunityIndex = function() return 5 end
	local calls = 0
	r.env.C_ChatInfo.SendAddonMessage = function()
		calls = calls + 1
		if calls == 1 then return 3 end
		return 0
	end
	ok(r.W.Mod("Net.Community").CX.send("Q", "Orgrimmar", 10), "community Q queued")
	w:advance(2)
	eq(r.W.community.dropped, 0, "first throttle does not drop the item")
	eq(r.W.community.sent, 1, "retried item is sent")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:129 (negated if comm.firstResult == nil)
test("mutation transport: first successful community send records comm.firstResult", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	w:advance(10)
	r.W.CommunityIndex = function() return 5 end
	r.env.C_ChatInfo.SendAddonMessage = function() return 0 end
	ok(r.W.Mod("Net.Community").CX.send("Q", "Orgrimmar", 10), "community Q queued")
	w:advance(1)
	eq(r.W.community.firstResult, "ok (0)", "firstResult recorded on first success")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:492 (and to or in deliver pendingTest clear)
test("mutation transport: queued test whisper proves offline answers so later whispers are suppressed", function()
	local w = T.newWorld({ whisperCheck = { delay = 0.2 } })
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	w:advance(2)
	r.W.Drive.customers["bob helper"] = { guid = "Player-1-bob helper" }
	w:player(BOB).online = false
	local realSend = r.env.C_ChatInfo.SendAddonMessage
	local throttledOnce = false
	r.env.C_ChatInfo.SendAddonMessage = function(prefix, text, chatType, target)
		if not throttledOnce and chatType == "WHISPER" then
			throttledOnce = true
			return 3
		end
		return realSend(prefix, text, chatType, target)
	end
	ok(r.W.SendTo(BOB, "C", "first"), "first whisper queued")
	w:advance(2)
	eq(r.W.net.notSent or 0, 0, "first test whisper still went out")
	ok(r.W.SendTo(BOB, "C", "second"), "second whisper handled")
	w:advance(1)
	eq(r.W.net.notSent, 1, "second whisper suppressed after offline was proven")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:500 (or to and in ask.noteTest expiry check)
test("mutation transport: expired test whisper does not trigger ask.gaveUp when delayed past TEST_KEEP", function()
	local w = T.newWorld({ whisperCheck = { delay = 0.2 } })
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	w:addBot(CAL, { spot = "Orgrimmar" })
	T.settle(w)
	w:advance(2)
	r.W.Drive.customers["bob helper"] = { guid = "Player-1-bob helper" }
	r.W.Drive.customers["cal stone"] = { guid = "Player-1-cal stone" }
	w:player(BOB).online = false
	local unlockAt = r.env.GetTime() + 65
	local realSend = r.env.C_ChatInfo.SendAddonMessage
	r.env.C_ChatInfo.SendAddonMessage = function(prefix, text, chatType, target)
		if r.env.GetTime() < unlockAt then return 11 end
		return realSend(prefix, text, chatType, target)
	end
	ok(r.W.SendTo(BOB, "C", "delayed"), "whisper queued")
	w:advance(0.5) -- whisper check answers offline; whisper queued and hits CHAT_LOCKED (11)
	w:player(BOB).online = true -- comes online before whisper actually leaves, so no not-found line
	w:advance(85) -- past TEST_KEEP (60s) and NOT_FOUND_WINDOW (10s)
	local asksBefore = r.whisperAsked and #r.whisperAsked or 0
	ok(r.W.SendTo(CAL, "C", "check"), "second player whisper queued")
	w:advance(0.5)
	local asksAfter = r.whisperAsked and #r.whisperAsked or 0
	eq(asksAfter, asksBefore + 1, "whisper check still active (not gaveUp) after expired test whisper")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:529 (> to <= in onAnswer fresh cache eviction)
test("mutation transport: fresh whisper check for one player is not evicted by another player's answer", function()
	local w = T.newWorld({ whisperCheck = { delay = 0.2 } })
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	w:addBot(CAL, { spot = "Orgrimmar" })
	T.settle(w)
	w:advance(2)
	r.W.Drive.customers["bob helper"] = { guid = "Player-1-bob helper" }
	r.W.Drive.customers["cal stone"] = { guid = "Player-1-cal stone" }
	r.W.SendTo(BOB, "C", "one")
	w:advance(1)
	local asks1 = r.whisperAsked and #r.whisperAsked or 0
	eq(asks1, 1, "asked for Bob")
	w:advance(2)
	r.W.SendTo(CAL, "C", "two")
	w:advance(1)
	local asks2 = r.whisperAsked and #r.whisperAsked or 0
	eq(asks2, 2, "asked for Cal")
	w:advance(1)
	r.W.SendTo(BOB, "C", "three")
	w:advance(1)
	local asks3 = r.whisperAsked and #r.whisperAsked or 0
	eq(asks3, 2, "Bob's fresh answer was kept, not evicted")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:599 (== to ~= in RequestCanLocalWhisperTarget error release)
test("mutation transport: failed RequestCanLocalWhisperTarget releases held item and sends once", function()
	local w = T.newWorld({ whisperCheck = { delay = 0.2 } })
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	w:advance(2)
	r.W.Drive.customers["bob helper"] = { guid = "Player-1-bob helper" }
	r.env.C_ChatInfo.RequestCanLocalWhisperTarget = function() error("check refused") end
	local mark = #w.addonLog
	eq(r.W.SendTo(BOB, "C", "hello"), true, "queued directly on error")
	w:advance(2)
	eq(r.W.QueueLength(), 0, "held count released")
	local sent = 0
	for i = mark + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.prefix == "WUBER" and e.chatType == "WHISPER" and e.from == TESTCHAR then sent = sent + 1 end
	end
	eq(sent, 1, "sent once, not duplicated by WAIT timer")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:641 (~= to == in W.Invite fallback check)
test("mutation transport: W.Invite prefers C_PartyInfo.InviteUnit and falls back to InviteUnit", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local modern, old = 0, 0
	r.env.C_PartyInfo = r.env.C_PartyInfo or {}
	r.env.C_PartyInfo.InviteUnit = function() modern = modern + 1 end
	r.env.InviteUnit = function() old = old + 1 end
	eq(r.W.Invite(BOB), true, "modern invite succeeded")
	eq(modern, 1, "C_PartyInfo.InviteUnit called")
	eq(old, 0, "global InviteUnit not called")
	r.env.C_PartyInfo.InviteUnit = nil
	eq(r.W.Invite(BOB), true, "fallback invite succeeded")
	eq(old, 1, "global InviteUnit called when C_PartyInfo.InviteUnit missing")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:642 (~= to == in W.Invite function guard)
test("mutation transport: W.Invite calls InviteUnit when present and returns false when missing", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local calls = 0
	r.env.C_PartyInfo = r.env.C_PartyInfo or {}
	r.env.C_PartyInfo.InviteUnit = function() calls = calls + 1 end
	eq(r.W.Invite(BOB), true, "invite succeeds when function exists")
	eq(calls, 1, "InviteUnit was called")
	r.env.C_PartyInfo.InviteUnit = false
	r.env.InviteUnit = false
	eq(r.W.Invite(BOB), false, "invite returns false when no InviteUnit exists")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:643 (return nil instead of pcall result in W.Invite)
test("mutation transport: W.Invite returns true on successful invite, not nil", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	r.env.C_PartyInfo = r.env.C_PartyInfo or {}
	r.env.C_PartyInfo.InviteUnit = function() end
	eq(r.W.Invite(BOB), true, "W.Invite returns true")
	T.clean(w)
end)
