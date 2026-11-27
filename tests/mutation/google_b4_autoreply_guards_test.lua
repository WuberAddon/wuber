-- Guard tests for Wuber/Drive/AutoReply.lua (Batch 4, lane d1).
-- Each test guards a line from the mutation audit that no other test protected.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function openOrgDriver()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = a.W.Drive
	DR.opts().autoInvite = true
	DR.opts().watchPublic = true
	ok(DR.SetOpen(true), "driver open in Orgrimmar")
	w:advance(3)
	return w, a, DR
end

local function with(tbl, over, fn)
	local saved = {}
	for k, v in pairs(over) do
		saved[k] = tbl[k]
		if v == false then tbl[k] = nil else tbl[k] = v end
	end
	local good, err = pcall(fn)
	for k in pairs(over) do tbl[k] = saved[k] end
	if not good then error(err, 0) end
end

-- guards Wuber/Drive/AutoReply.lua:301 (swap and->or: CanReply crashes when MaxGroup is missing while GroupSize is present)
test("mutation b4 autoreply: CanReply skips group-cap check cleanly when MaxGroup is absent", function()
	local w, a, DR = openOrgDriver()
	with(DR, { MaxGroup = false }, function()
		local can, reason = DR.CanReply("Dan Miller")
		eq(can, true, "CanReply succeeds without MaxGroup")
		eq(reason, nil, "no refusal reason")
	end)
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:117 (swap or->and: ReplyHeard(nil) crashes on #key instead of returning false)
test("mutation b4 autoreply: ReplyHeard returns false cleanly when given nil or empty key", function()
	local w, a, DR = openOrgDriver()
	eq(DR.ReplyHeard(nil), false, "nil key returns false")
	eq(DR.ReplyHeard(""), false, "empty key returns false")
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:473 (local value -> nil: failed send wipes a pre-existing reply stamp instead of restoring it)
test("mutation b4 autoreply: a failed TryReply send restores any pre-existing reply stamp", function()
	local w, a, DR = openOrgDriver()
	local k = a.W.Key("Dan Miller")
	local prior = a.env.time() - 60
	DR.db.replied = { [k] = prior }
	local realSend = a.env.C_ChatInfo.SendChatMessage
	a.env.C_ChatInfo.SendChatMessage = function() error("the game said no") end
	with(DR, { CanReply = function() return true end }, function()
		local sent, reason = DR.TryReply("Dan Miller", "WTB summon to Orgrimmar", "invite")
		eq(sent, false, "send failed")
		eq(reason, "could not send", "expected failure reason")
	end)
	a.env.C_ChatInfo.SendChatMessage = realSend
	eq(DR.db.replied[k], prior, "pre-existing reply stamp is preserved after send failure")
	T.clean(w)
end)

-- guards Wuber/Drive/AutoReply.lua:483 (drop statement: failed send leaves new sessionReplied timestamp instead of restoring beforeSess)
test("mutation b4 autoreply: a failed retry restores the prior session reply record for wall-clock jump checks", function()
	local w, a, DR = openOrgDriver()
	eq(DR.TryReply("Dan Miller", "WTB summon to Orgrimmar", "invite"), true, "initial whisper succeeds")
	w:advance(10)
	local realSend = a.env.C_ChatInfo.SendChatMessage
	a.env.C_ChatInfo.SendChatMessage = function() error("the game said no") end
	with(DR, { CanReply = function() return true end }, function()
		local sent, reason = DR.TryReply("Dan Miller", "WTB summon to Orgrimmar", "invite")
		eq(sent, false, "retry send failed")
		eq(reason, "could not send", "expected failure reason")
	end)
	a.env.C_ChatInfo.SendChatMessage = realSend
	-- Jump wall clock past REPLY_EVERY; sessionReplied must still match the original stamp so CanReply blocks it.
	local realTime = a.env.time
	a.env.time = function(t) if t then return realTime(t) end return realTime() + 5000 end
	local can, reason = DR.CanReply("Dan Miller")
	a.env.time = realTime
	eq(can, false, "still blocked within session hour after wall-clock jump")
	eq(reason, "already whispered within the hour", "expected cooldown reason")
	T.clean(w)
end)
