-- Wuber 2.4 fix round 3, group A: sends held during the game's chat lock (LRN-02, PST-04) and the quiet
-- time after a loading screen (LRN-03). Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function setup()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	w:advance(30) -- the login quiet time is over
	return w, r
end

local function whisperTo(w, r, n)
	for i = 1, n do r.W.SendTo("Tina Trial", "S", i, "invited") end
end

test("v24 f3a chat lock: a locked chat holds the outbox, never a hard fail, and it sends when the lock ends", function()
	local w, r = setup()
	local c = r
	c.chatLock = true
	local sentBefore = r.W.net.sent
	for i = 1, 5 do r.W.SendTo("Tina Trial", "S", i, "invited") end
	w:advance(20)
	eq(r.W.net.sent, sentBefore, "nothing went out while locked")
	ok((r.W.net.hardFails or 0) == 0, "no hard fail counted (" .. tostring(r.W.net.hardFails) .. ")")
	ok(not r.W.net.cantSend, "never listen-only")
	ok(r.W.QueueLength() >= 5, "the messages are kept (" .. r.W.QueueLength() .. ")")
	c.chatLock = false
	w:advance(10)
	eq(r.W.QueueLength(), 0, "the outbox emptied after the lock")
	ok(r.W.net.sent > sentBefore, "they were sent")
end)

test("v24 f3a chat lock: a boss fight (ENCOUNTER_START to ENCOUNTER_END) holds sends, with no lockdown call at all", function()
	local w, r = setup()
	local c = r
	r.env.C_ChatInfo.InChatMessagingLockdown = nil -- this client may not have the call
	c:fire("ENCOUNTER_START", 1, "Boss", 1, 5)
	local before = #w.addonLog
	whisperTo(w, r, 3)
	w:advance(5)
	eq(#w.addonLog, before, "no send during the fight")
	ok(r.W.QueueLength() >= 1, "kept")
	c:fire("ENCOUNTER_END", 1, "Boss", 1, 5, 1)
	w:advance(5)
	eq(r.W.QueueLength(), 0, "sent after the fight")
end)

test("v24 f3a chat lock: result 11 is later, not a hard fail", function()
	local w, r = setup()
	local c = r
	c.chatLock = true
	r.env.C_ChatInfo.InChatMessagingLockdown = function() return false end -- the call is not told (late or wrong)
	for i = 1, 5 do r.W.SendTo("Tina Trial", "S", i, "invited") end
	w:advance(10)
	ok(not r.W.net.cantSend, "not listen-only")
	ok((r.W.net.hardFails or 0) == 0, "no hard fail")
	ok(r.W.QueueLength() >= 1, "kept")
	c.chatLock = false
	w:advance(15)
	eq(r.W.QueueLength(), 0, "sent later")
end)

test("v24 f3a chat lock: where the game has its own lock call, that call decides: a boss fight it does not lock holds nothing", function()
	local w, r = setup()
	r.env.C_ChatInfo.InChatMessagingLockdown = function() return false end
	r:fire("ENCOUNTER_START", 1, "Boss", 1, 5)
	local before = #w.addonLog
	whisperTo(w, r, 3)
	w:advance(5)
	eq(#w.addonLog - before, 3, "the three messages went during the fight")
	eq(r.W.QueueLength(), 0, "nothing held")
end)

test("v24 f3a chat lock: a boss fight whose end is never told stops holding after 15 minutes (no lock call)", function()
	local w, r = setup()
	r.env.C_ChatInfo.InChatMessagingLockdown = nil
	r:fire("ENCOUNTER_START", 1, "Boss", 1, 5)
	whisperTo(w, r, 2)
	w:advance(600)
	ok(r.W.QueueLength() >= 1, "still held at 10 minutes")
	w:advance(330)
	eq(r.W.QueueLength(), 0, "sent once 15 minutes have passed")
end)

test("v24 f3a loading screen: two messages go at once, the rest one a second, never the usual burst of four, order kept", function()
	local w, r = setup()
	r:fire("PLAYER_ENTERING_WORLD", false, false)
	local before = #w.addonLog
	for i = 1, 8 do r.W.SendTo("Tina Trial", "S", i, "invited") end
	w:advance(0.2)
	eq(#w.addonLog - before, 2, "two went at once (a rider's 'arrived' is never late)")
	w:advance(2)
	local mid = #w.addonLog - before
	ok(mid >= 3 and mid <= 5, "then about one a second (" .. mid .. " after 2.2 s)")
	w:advance(30)
	eq(r.W.QueueLength(), 0, "all of them went in the end")
	local ids, want = {}, {}
	for i = 1, 8 do want[i] = r.W.Encode("S", i, "invited") end
	for i = before + 1, #w.addonLog do ids[#ids + 1] = w.addonLog[i].text end
	eq(table.concat(ids, "|"), table.concat(want, "|"), "in order")
end)

test("v24 f3a loading screen: without one, four of the same eight go at once (control)", function()
	local w, r = setup()
	local before = #w.addonLog
	for i = 1, 8 do r.W.SendTo("Tina Trial", "S", i, "invited") end
	w:advance(0.2)
	eq(#w.addonLog - before, 4, "the usual burst: four at once with a full budget (NETK.BURST)")
end)

test("v24 f3a loading screen: a touchy game (refuses sends for 5 s) loses nothing and is never taken for an account that cannot send", function()
	local w, r = setup()
	local c = r
	w.touchyLoad = true
	c:fire("PLAYER_ENTERING_WORLD", false, false)
	whisperTo(w, r, 6)
	w:advance(40)
	eq(r.W.QueueLength(), 0, "everything went after")
	ok((r.W.net.hardFails or 0) == 0, "no hard fail counted (" .. tostring(r.W.net.hardFails) .. ")")
	ok(not r.W.net.cantSend, "never listen-only")
	ok((c.touchyRefused or 0) <= 8, "only a few tries met the touchy seconds (" .. tostring(c.touchyRefused) .. ")")
end)
