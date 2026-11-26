-- Tests from the mutation run (job 2765), network sends, bounty, trade check (Net/*).
-- Each guards one line that no other test noticed when it was broken.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local TESTCHAR, BOB = T.TESTCHAR, "Bob Helper"

-- guards Wuber/Net/Transport.lua:86 (mutation run 2765, mutant 10296: cmp <->>=)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation net: one or two refused sends do not make the account listen-only; the third does", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	r.addonFails = true -- the fake game refuses every addon message
	r.W.SendTo(BOB, "C", "try1")
	ok(not r.W.net.cantSend, "after one refusal Wuber still sends")
	r.W.SendTo(BOB, "C", "try2")
	ok(not r.W.net.cantSend, "after two refusals Wuber still sends")
	r.W.SendTo(BOB, "C", "try3")
	eq(r.W.net.cantSend, true, "three refusals and none ever sent: listen-only")
	T.clean(w)
end)

-- guards Wuber/Net/Bounty.lua:123 (mutation run 2765, mutant 22749: cmp ==->~=)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation net: a bounty whose copies were all refused is offered again at the next tick, not held back as sent", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	w:advance(30)
	local fb = r.W.Mod("Net.Base").fb
	fb.qAt["bob helper"], fb.qAddr["bob helper"] = r.env.GetTime(), BOB
	r.W.Faction = function() return "H" end
	r.W.SendChannel = function() return false end
	local realSendTo = r.W.SendTo
	r.W.SendTo = function() return false end
	ok(r.W.Bounty.Pin("Orgrimmar", 5000), "pinned")
	eq(r.W.Bounty.Mine().sends, 0, "every copy was refused: nothing counts as sent, it stays due")
	r.W.SendTo = realSendTo
	local mark = #w.addonLog
	w:advance(70)
	local went = 0
	for i = mark + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.prefix == "WUBER" and e.from == TESTCHAR and e.chatType == "WHISPER" and tostring(e.text):match("^W~") then went = went + 1 end
	end
	ok(went >= 1, "the bounty reached the driver at the next tick, not five minutes later")
	eq(r.W.Bounty.Mine().sends, 1, "and now it counts as sent")
	T.clean(w)
end)

-- guards Wuber/Net/Rides.lua:754 (mutation run 2765, mutant 22769: return -> nil)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation net: paying with a trade whose partner is unknown and no driver in the group is refused with the reason", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	r.W.ride = { id = "abcdef", state = "arrived", driverKey = "mia runner", driver = "Mia Runner", price = 5000, at = r.env.GetTime() }
	r.W.tradeOpen = true
	local okp, line = r.W.PayFare()
	eq(okp, false, "refused")
	eq(line, "That trade isn't with your driver.", "and says why")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:578 (mutation run 2765, mutant 24733: return -> nil)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation net: when the game cannot answer the whisper check, the message is still queued and SendTo says so", function()
	local w = T.newWorld({ whisperCheck = { delay = 0.2 } })
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	T.settle(w)
	w:advance(30)
	r.W.Drive.customers["bob helper"] = { guid = "Player-1-bob helper" }
	r.env.C_ChatInfo.RequestCanLocalWhisperTarget = function() error("the game refused the check") end
	eq(r.W.SendTo(BOB, "C", "hello"), true, "queued without the check")
	w:advance(5)
	local got = 0
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBER" and e.chatType == "WHISPER" and e.from == TESTCHAR and tostring(e.text):find("hello", 1, true) then got = got + 1 end
	end
	eq(got, 1, "the message went out")
	T.clean(w)
end)

-- guards Wuber/Net/Community.lua:291 (mutation run 2765, mutant 11660: if cond negated)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation net: accepting a community invitation with no club id is refused and never calls the game", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local calls = 0
	r.env.C_Club = r.env.C_Club or {}
	r.env.C_Club.AcceptInvitation = function() calls = calls + 1 return true end
	eq(r.W.CommunityAccept(nil), false, "no club id: refused")
	eq(calls, 0, "the game was never asked")
	eq(r.W.community.acceptFailed, true, "the failure is noted")
	eq(r.W.CommunityAccept("club-1"), true, "control: with an id the game is asked")
	eq(calls, 1, "once")
	T.clean(w)
end)

-- guards Wuber/Net/Transport.lua:627 (mutation run 2765, mutant 16760: cmp ~=->==)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation net: leaving the group uses the game's own LeaveParty call, and the older global when that is missing", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local modern, old = 0, 0
	r.env.C_PartyInfo = r.env.C_PartyInfo or {}
	r.env.C_PartyInfo.LeaveParty = function() modern = modern + 1 end
	r.env.LeaveParty = function() old = old + 1 end
	eq(r.W.LeaveGroup(), true, "went through")
	eq(modern, 1, "the modern call was used")
	eq(old, 0, "not the old one")
	r.env.C_PartyInfo.LeaveParty = nil
	eq(r.W.LeaveGroup(), true, "went through on the old call")
	eq(old, 1, "the older global is the fallback")
	T.clean(w)
end)
