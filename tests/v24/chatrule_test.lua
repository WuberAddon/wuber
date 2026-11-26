-- Wuber 2.4, the chat rule: addon code sends no chat line by itself, except the one auto-reply whisper from
-- Wuber/Drive/AutoReply.lua inside its limits (CLAUDE.md "Secure and hardware-click rules"; the author, 21 Nov 2026).
-- These tests hold the two guards to that rule: the fake game (H.replyRule) and tools/check.lua (check 8).
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local SITE = "/x/Wuber/Drive/AutoReply.lua"

test("v24 chatrule: addon code outside the auto-reply call site still cannot whisper", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA)
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	T.settle(w)
	-- called from a test file: no addon file on the stack
	a.env.C_ChatInfo.SendChatMessage("hello", "WHISPER", nil, "Dan-Miller")
	eq(#w:whispersTo("Dan Miller"), 0, "nothing was whispered")
	eq(#w.violations, 1, "a violation is recorded")
	ok(tostring(w.violations[1]):find("not sent from the auto-reply call site", 1, true), tostring(w.violations[1]))
	-- called under Wuber's own code (W.Safe lives in Core/Runtime.lua): still not the call site
	a.W.Safe("chatrule", function() a.env.SendChatMessage("hello", "WHISPER", nil, "Dan-Miller") end)
	eq(#w:whispersTo("Dan Miller"), 0, "nothing was whispered from another Wuber file")
	eq(#w.violations, 2, "a second violation")
	-- any other kind of chat line is refused whatever the file
	a.env.SendChatMessage("WTS summons", "CHANNEL", nil, 2)
	eq(#w.violations, 3, "a channel line is a violation")
	eq(#w.blocked, 3, "all three were blocked")
	w.violations = {}
	T.clean(w)
end)

test("v24 chatrule: the fake game holds the auto-reply whisper to its limits", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA)
	local b = T.rider(w, T.BOB)
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	T.settle(w)
	local rule = H.replyRule
	eq(rule(w, a, "WHISPER", "Dan-Miller", SITE), nil, "allowed: a whisper from the call site to a full name")
	eq(rule(w, a, "WHISPER", "Dan Miller", "\\x\\Wuber\\Drive\\AutoReply.lua"), nil, "allowed: Windows separators, a space in the name")
	ok(rule(w, a, "SAY", "Dan-Miller", SITE), "never a say line")
	ok(rule(w, a, "CHANNEL", "2", SITE), "never a channel line")
	ok(rule(w, a, "WHISPER", "Dan-Miller", "/x/Wuber/Drive/Queue.lua"), "never from another file")
	ok(rule(w, a, "WHISPER", "Dan-Miller", "/x/Other/Drive/AutoReply.lua"), "never from another addon's file of that name")
	eq(rule(w, a, "WHISPER", "Dan", SITE), "not a full two-part name", "a short name")
	eq(rule(w, a, "WHISPER", T.ANITA, SITE), "a whisper to yourself", "never to yourself")
	-- in combat
	w:enterCombat(a)
	eq(rule(w, a, "WHISPER", "Dan-Miller", SITE), "in combat", "never in combat")
	w:leaveCombat(a)
	-- in an instance (the fake game's IsInInstance answers from the player)
	a.player.instance = true
	eq(rule(w, a, "WHISPER", "Dan-Miller", SITE), "in an instance", "never in an instance")
	eq(a.env.IsInInstance(), true, "IsInInstance says so")
	a.player.instance = nil
	eq(a.env.IsInInstance(), false, "and not outside one")
	-- once per player per hour
	w.replies = { [T.ANITA] = { [H.key("Dan Miller")] = w.time } }
	eq(rule(w, a, "WHISPER", "Dan-Miller", SITE), "a second whisper to the same player within the hour", "once an hour")
	w:advance(3601)
	eq(rule(w, a, "WHISPER", "Dan-Miller", SITE), nil, "allowed again after the hour")
	-- someone in the group
	w:group({ T.ANITA, T.BOB })
	T.settle(w, 1)
	eq(rule(w, a, "WHISPER", (T.BOB:gsub(" ", "-")), SITE), "a whisper to someone in the group", "never to the group")
	-- a raid
	a.player.group.raid = true
	eq(rule(w, a, "WHISPER", "Dan-Miller", SITE), "in a raid", "never in a raid")
	ok(b ~= nil, "the rider's window was there")
	T.clean(w)
end)

test("v24 chatrule: check.lua fails on SendChatMessage anywhere but the one call site", function()
	local scan = T.CHECK.scanChat
	local call = "local _, W = ...\nlocal function send(t, n) C_ChatInfo.SendChatMessage(t, 'WHISPER', nil, n) end\n"
	eq(scan("Drive/AutoReply.lua", call), nil, "the call site may name it once")
	eq(scan("Drive\\AutoReply.lua", call), nil, "Windows separators too")
	eq(scan("Drive/Queue.lua", call), 2, "any other file fails, at the line")
	eq(scan("UI/AutoReply.lua", call), 2, "a file of the same name elsewhere fails")
	eq(scan("Drive/AutoReply.lua", call .. "SendChatMessage('x', 'SAY')\n"), 3, "a second line in the call site fails")
	eq(scan("Drive/Queue.lua", "-- SendChatMessage is never called here\nlocal x = 1\n"), nil, "a comment is no call")
	eq(T.CHECK.CHAT_ALLOW["Drive/AutoReply.lua"], 1, "one line in the call site")
	local n = 0
	for _ in pairs(T.CHECK.CHAT_ALLOW) do n = n + 1 end
	-- (the decisions round, the author's yes of 21 Nov 2026 22:28) a second call site: Drive/AutoLines.lua
	eq(n, 3, "three files on the list: the two call sites, and Core/Runtime.lua's table of names")
	-- the whole addon as it is passes check 8 (the suite's "tools/check.lua passes" test runs every check)
	local res = T.CHECK.check({ root = H.root, files = { "Core/Runtime.lua" }, globals = nil })
	for _, f in ipairs(res.fails) do ok(not f:find("SendChatMessage", 1, true), f) end
	ok(true, "Core/Runtime.lua's string is allowed")
end)
