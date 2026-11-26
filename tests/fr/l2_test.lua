-- Fix round 2.4, group l2: HUNT-122 (one tap on a chat lead invites with whisper invites off) and
-- HUNT-123 (an auto-invite is counted only when Wuber really invited). Loaded by tests/run.lua with T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local function invitesTo(w, name)
	local n = 0
	for _, i in ipairs(w.invites or {}) do if i.to:lower() == name:lower() then n = n + 1 end end
	return n
end

test("fr l2 HUNT-122: whisper invites off: one tap on a lead invites them", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	w:addBot(T.BOB, { spot = "Orgrimmar", class = "MAGE" })
	T.settle(w)
	T.goOnline(d, { price = 5000 })
	local DR = d.W.Drive
	DR.opts().autoInvite = false
	local c = DR.Lead(T.BOB, "anyone doing summons?", "whisper")
	ok(c and c.state == "lead", "a lead")
	w.hardware = d
	d.W.Driver.RowClick(c, "LeftButton")
	w.hardware = nil
	w:advance(1)
	eq(invitesTo(w, T.BOB), 1, "one tap, one invite")
	T.clean(w)
end)

test("fr l2 HUNT-123: whisper invites off: a clear whisper counts no auto-invite", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	w:addBot(T.TESTCHAR, { spot = "Orgrimmar", class = "MAGE", acceptsInvites = false })
	T.settle(w)
	T.goOnline(d, { price = 5000 })
	local DR = d.W.Drive
	DR.opts().autoInvite = false
	w:botWhisper(T.TESTCHAR, d, "summon pls")
	w:advance(5)
	eq(invitesTo(w, T.TESTCHAR), 0, "nobody invited")
	eq((DR.AutoRecord()), 0, "no auto-invite counted")
	T.clean(w)
end)
