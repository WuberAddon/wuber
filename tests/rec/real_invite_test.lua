-- Flight recorder, lane B1: the fake game's group invite checked against the real client (WoW Forever,
-- 17-21 Nov 2026; facts in tests/fixtures/rec/lab-real-facts.lua).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function listen(name, fn)
	local got, orig = {}, H.Client.fire
	H.Client.fire = function(self, ev, ...)
		if self.player and self.player.name == name and ev ~= "CHAT_MSG_ADDON" then
			got[#got + 1] = { ev = ev, at = self.world.time, args = { n = select("#", ...), ... } }
		end
		return orig(self, ev, ...)
	end
	local okf, err = pcall(fn, got)
	H.Client.fire = orig
	if not okf then error(err, 0) end
	return got
end

-- invite.args (41 of 41): "Wuber Rocks 21 Nov 00:06:32 PARTY_INVITE_REQUEST inviter='Anita Lift' type=string
-- extra=8": a plain string, then 8 more arguments (the retail documentation lists 7: isTank, isHealer, isDamage,
-- isNativeRealm, allowMultipleRoles, inviterGUID, questSessionActive; this client sends one more).
-- chat.system.lines (41 of 41): in the same frame, just after it, the invitee's
-- "|Hplayer:Anita Lift|h[Anita Lift]|h has invited you to join a group."
test("rec: real: PARTY_INVITE_REQUEST has the inviter and 8 more arguments, then the invitee's system line (invite.args)", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.rider(w, T.TESTCHAR)
	T.settle(w)
	local got = listen(T.TESTCHAR, function()
		w:invite(d, T.TESTCHAR)
		w:advance(1)
	end)
	local req, line
	for i, e in ipairs(got) do
		if e.ev == "PARTY_INVITE_REQUEST" and not req then req = i end
		if e.ev == "CHAT_MSG_SYSTEM" and tostring(e.args[1]):find("has invited you", 1, true) then line = i end
	end
	ok(req, "PARTY_INVITE_REQUEST fired")
	local a = got[req].args
	eq(a.n, 9, "the inviter and 8 more")
	eq(type(a[1]), "string", "the inviter is a plain string")
	eq(a[1], T.ANITA, "the inviter's name")
	ok(line, "the invitee's system line")
	eq(got[line].args[1], "|Hplayer:Anita Lift|h[Anita Lift]|h has invited you to join a group.", "the real wording")
	eq(got[line].at, got[req].at, "in the same frame")
	ok(line > req, "after the event")
	T.clean(w)
end)

-- chat.system.lines: the inviter's own line was already right ("You have invited Farra Way to join your group.",
-- 15 in the lines): kept.
test("rec: real: the inviter's system line is 'You have invited X to join your group.' (chat.system.lines)", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.rider(w, T.TESTCHAR)
	T.settle(w)
	local got = listen(T.ANITA, function()
		w:invite(d, T.TESTCHAR)
		w:advance(1)
	end)
	local seen = false
	for _, e in ipairs(got) do
		if e.ev == "CHAT_MSG_SYSTEM" and e.args[1] == "You have invited " .. T.TESTCHAR .. " to join your group." then seen = true end
	end
	ok(seen, "the inviter's line")
	T.clean(w)
end)
