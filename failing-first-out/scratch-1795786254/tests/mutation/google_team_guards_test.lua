-- Tests from the mutation run for Wuber/Drive/Team.lua.
-- Each guards one line that no other test noticed when it was broken.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local TESTCHAR, BOB, CAP = T.TESTCHAR, "Bob Helper", "Captain Lock"

-- guards Wuber/Drive/Team.lua:88 (return true -> return false)
test("mutation team: a send error drops the failing message instead of blocking the outbox", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	local p = T.rider(w, BOB)
	T.settle(w)
	w:group({ TESTCHAR, BOB })
	w:advance(1)
	local DR = d.W.Drive
	DR.on = true
	local realSend = d.env.C_ChatInfo.SendAddonMessage
	local n = 0
	d.env.C_ChatInfo.SendAddonMessage = function(...)
		n = n + 1
		if n == 1 then error("boom") end
		return realSend(...)
	end
	local sentBefore = DR.comm.sent
	DR.Send("ST", "p1", "waiting")
	DR.Send("ST", "p2", "waiting")
	DR.FlushComm()
	eq(DR.comm.failed, 1, "one send failed")
	eq(DR.comm.sent, sentBefore + 1, "the second message still went out")
	local q1, q2 = DR.CommBacklog()
	eq(q1, 0, "outbox is empty")
	eq(q2, 0, "bulk is empty")
	d.env.C_ChatInfo.SendAddonMessage = realSend
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:115 (cmp < -> >=)
test("mutation team: chat lock holds the token budget so queued messages flush together when the lock clears", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	local p = T.rider(w, BOB)
	T.settle(w)
	w:group({ TESTCHAR, BOB })
	w:advance(1)
	local DR = d.W.Drive
	DR.on = true
	local realSend = d.env.C_ChatInfo.SendAddonMessage
	local locked = true
	d.env.C_ChatInfo.SendAddonMessage = function(...)
		if locked then return 11 end
		return realSend(...)
	end
	for i = 1, 5 do DR.Send("ST", "p" .. i, "waiting") end
	DR.FlushComm()
	local q1 = DR.CommBacklog()
	eq(q1, 5, "all 5 stay queued while chat-locked")
	locked = false
	d.env.C_ChatInfo.SendAddonMessage = realSend
	w:advance(2.1)
	DR.FlushComm()
	q1 = DR.CommBacklog()
	eq(q1, 0, "preserved budget flushes all 5 at once when holdUntil expires")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:116 (delete tokens = 0)
test("mutation team: throttle clears the token budget until the next second", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	local p = T.rider(w, BOB)
	T.settle(w)
	w:group({ TESTCHAR, BOB })
	w:advance(1)
	local DR = d.W.Drive
	DR.on = true
	local realSend = d.env.C_ChatInfo.SendAddonMessage
	local throttled = true
	d.env.C_ChatInfo.SendAddonMessage = function(...)
		if throttled then return 3 end
		return realSend(...)
	end
	DR.Send("PAU", 1)
	DR.FlushComm()
	eq(DR.CommBacklog(), 1, "throttled message stays queued")
	throttled = false
	d.env.C_ChatInfo.SendAddonMessage = realSend
	DR.FlushComm()
	eq(DR.CommBacklog(), 1, "token budget is zeroed for the rest of this second")
	w:advance(1.1)
	DR.FlushComm()
	eq(DR.CommBacklog(), 0, "flushes once tokens refill")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:382 (return DR.IsLeader() -> return nil)
test("mutation team: group leader answers sync when the captain is not in the group", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	local p = T.rider(w, BOB)
	T.settle(w)
	w:group({ TESTCHAR, BOB })
	w:advance(1)
	local DR = d.W.Drive
	DR.char().captain = CAP
	eq(DR.IsCaptain(), false, "not the captain")
	eq(DR.IsLeader(), true, "is the group leader")
	eq(DR.SyncAnswerer(), true, "leader answers sync when captain is absent")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:457 (delete DR.customers[key] = nil)
test("mutation team: heardHello clears any stale customer entry for a crew member", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	local b = T.driver(w, BOB)
	T.settle(w)
	w:group({ TESTCHAR, BOB })
	w:advance(1)
	local DR = d.W.Drive
	DR.on = true
	b.W.Drive.on = true
	local bKey = d.W.Key(BOB)
	DR.char().crew = { { name = BOB, role = "lock" } }
	DR.customers[bKey] = { name = BOB, state = "waiting" }
	b.W.Drive.Hello(true)
	w:advance(0.5)
	eq(DR.customers[bKey], nil, "crew member is removed from customers on hello")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:487 (cmp ~= -> ==)
test("mutation team: isContact checks W.Contacts when it is a function", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.settle(w)
	local DR = d.W.Drive
	local bKey = d.W.Key(BOB)
	d.W.Contacts = function() return { { key = bKey } } end
	DR.offers[bKey] = { name = BOB, at = d.env.GetTime() - 25, state = "waiting" }
	DR.OfferTick()
	eq(DR.offers[bKey].state, "waiting", "contact stays waiting instead of flipping to noapp")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:489 (cmp ~= -> ==)
test("mutation team: isContact accepts a table returned by W.Contacts", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.settle(w)
	local DR = d.W.Drive
	local bKey = d.W.Key(BOB)
	d.W.Contacts = function() return { { key = bKey } } end
	DR.offers[bKey] = { name = BOB, at = d.env.GetTime() - 25, state = "waiting" }
	DR.OfferTick()
	eq(DR.offers[bKey].state, "waiting", "valid contacts table keeps offer waiting")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:491 (cmp == -> ~=)
test("mutation team: non-matching contacts do not keep an unanswered offer waiting", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.settle(w)
	local DR = d.W.Drive
	local bKey = d.W.Key(BOB)
	d.W.Contacts = function() return { { key = "someone else" } } end
	DR.offers[bKey] = { name = BOB, at = d.env.GetTime() - 25, state = "waiting" }
	DR.OfferTick()
	eq(DR.offers[bKey].state, "noapp", "non-matching contact flips to noapp after 20s")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:542 (delete DR.offers[k] = nil)
test("mutation team: OfferCrew raid pick for an existing crew member clears any pending offer", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.settle(w)
	local DR = d.W.Drive
	local bKey = d.W.Key(BOB)
	DR.char().crew = { { name = BOB, role = "lock" } }
	DR.offers[bKey] = { name = BOB, at = d.env.GetTime(), state = "waiting" }
	DR.AddSummoner = DR.AddSummoner or function() return true end
	local okOffer, why = DR.OfferCrew(BOB, "raid")
	eq(okOffer, true, "raid pick succeeded")
	eq(why, "crew", "recognized as existing crew")
	eq(DR.offers[bKey], nil, "stale offer entry is cleared")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:623 (or -> and)
test("mutation team: accepting a new captain offer clears the old captain from peers", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.settle(w)
	local DR = d.W.Drive
	local oldKey = d.W.Key(CAP)
	DR.char().captain = CAP
	DR.peers[oldKey] = { name = CAP, at = d.env.GetTime() }
	DR.pendingOffers[d.W.Key(BOB)] = { name = BOB, at = d.env.GetTime() }
	eq(DR.AnswerOffer(BOB, true), true, "accepted new captain")
	eq(DR.peers[oldKey], nil, "old captain cleared from peers")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:628 (and -> or)
test("mutation team: accepting a captain offer does not whisper TL to a plain helper without Wuber", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	w:addBot("Plain Helper", { spot = "Orgrimmar" })
	T.settle(w)
	local DR = d.W.Drive
	DR.char().crew = { { name = "Plain Helper", role = "helper", app = false } }
	DR.pendingOffers[d.W.Key(BOB)] = { name = BOB, at = d.env.GetTime() }
	local mark = #w.addonLog
	eq(DR.AnswerOffer(BOB, true), true, "accepted new captain")
	w:advance(0.5)
	local sentTL = false
	for i = mark + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.from == TESTCHAR and e.target == "Plain Helper" and tostring(e.text):find("TL", 1, true) then
			sentTL = true
		end
	end
	eq(sentTL, false, "plain helper with app=false is not whispered TL")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:632 (cmp ~= -> ==)
test("mutation team: accepting a captain offer clears old crew members from peers", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.settle(w)
	local DR = d.W.Drive
	local oldMem = "Old Member"
	local oldKey = d.W.Key(oldMem)
	DR.char().crew = { { name = oldMem, role = "lock" } }
	DR.peers[oldKey] = { name = oldMem, at = d.env.GetTime() }
	DR.pendingOffers[d.W.Key(BOB)] = { name = BOB, at = d.env.GetTime() }
	eq(DR.AnswerOffer(BOB, true), true, "accepted new captain")
	eq(DR.peers[oldKey], nil, "old crew member cleared from peers")
	T.clean(w)
end)

-- guards Wuber/Drive/Team.lua:665 (return DR.DropCrewMember(k) -> return nil)
test("mutation team: non-captain RemoveCrew returns DropCrewMember result", function()
	local w = T.newWorld()
	local d = T.driver(w, TESTCHAR)
	T.settle(w)
	local DR = d.W.Drive
	DR.char().captain = CAP
	DR.char().crew = { { name = BOB, role = "lock" } }
	eq(DR.IsCaptain(), false, "not captain")
	eq(DR.RemoveCrew(BOB), true, "removing existing member returns true")
	eq(DR.RemoveCrew(BOB), false, "removing absent member returns false")
	T.clean(w)
end)
