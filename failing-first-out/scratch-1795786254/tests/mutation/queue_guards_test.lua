-- Guard tests from the second mutation run: the driver queue, leads, invites and lead hand-over (Drive/Queue.lua).
-- Each test guards lines that no other test noticed when they were broken. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local DAN = "Dan Miller"

local function alertsOf(a, part)
	local out = {}
	for _, f in ipairs(a.fired) do
		if f.name == "DRIVE_ALERT" and tostring(f.args[1]):find(part, 1, true) then out[#out + 1] = f.args[1] end
	end
	return out
end

local function firedCount(a, name)
	local n = 0
	for _, f in ipairs(a.fired) do if f.name == name then n = n + 1 end end
	return n
end

local function invitesTo(w, name)
	local n = 0
	for _, i in ipairs(w.invites) do if i.to == name then n = n + 1 end end
	return n
end

local function openDriver(w)
	return T.driver(w, T.ANITA, { spot = "Undercity" })
end

-- guards Wuber/Drive/Queue.lua:366 and :367 (mutation run, mutants 26260 and 31092: drop statement, return -> nil)
test("mutation queue: a second sign of life from a listed lead replaces their words, refreshes the window and returns the same lead", function()
	local w = T.newWorld()
	local a = openDriver(w)
	T.settle(w)
	local DR = a.W.Drive
	local first = DR.Lead(DAN, "anyone summoning?", "whisper")
	ok(first, "control: the lead is listed")
	w:advance(3)
	local before = firedCount(a, "DRIVE")
	local again = DR.Lead(DAN, "hello? summon?", "whisper")
	ok(again == first, "the same entry comes back, no second row")
	eq(first.msg, "hello? summon?", "the newest words are kept")
	w:advance(0.2)
	ok(firedCount(a, "DRIVE") > before, "the window is told to redraw")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:399-404 (mutation run, mutants 4206, 28319, 27623, 12722, 23773)
test("mutation queue: a rider held back by the driver is only ever listed as a lead, never queued for an invite", function()
	local w = T.newWorld()
	local a = openDriver(w)
	T.settle(w)
	ok(a.W.Drive.SetOpen(true), "driver opens")
	w:advance(2)
	local DR = a.W.Drive
	ok(DR.SetServeHold(DAN, true), "control: the hold is set")
	eq(DR.Request(DAN, "whisper", "summon pls"), nil, "nobody is queued")
	local c = DR.customers[a.W.Key(DAN)]
	ok(c, "they are listed")
	eq(c and c.state, "lead", "as a lead")
	-- a finished ride asks again: their old price and state are wiped, the words they sent now are kept
	c.state, c.price, c.paid, c.msg = "done", 99999, 5, "old words"
	eq(DR.Request(DAN, "whisper", nil), nil, "still nobody is queued")
	eq(c.state, "lead", "back to a lead")
	eq(c.price, DR.char().price, "the old ride's price is gone")
	eq(c.paid, 0, "the old ride's payment is gone")
	eq(c.msg, "old words", "no new words: the old ones stay")
	w:advance(10)
	eq(invitesTo(w, DAN), 0, "never invited")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:484 and :486 (mutation run, mutants 21945, 14079: drop statement)
test("mutation queue: putting a rider first marks only that rider and redraws the window", function()
	local w = T.newWorld()
	local a = openDriver(w)
	T.settle(w)
	local DR = a.W.Drive
	local one = DR.Lead("Ann Aa", "summon?", "say")
	local two = DR.Lead("Bea Bb", "summon?", "say")
	one.priority = true
	w:advance(3)
	local before = firedCount(a, "DRIVE")
	DR.SetPriority(two)
	ok(two.priority, "the chosen rider is first")
	ok(not one.priority, "the one before no longer is")
	w:advance(0.2)
	ok(firedCount(a, "DRIVE") > before, "the window is told to redraw")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:406 (mutation run, mutant 11677: drop statement)
test("mutation queue: new words from a held-back rider already listed redraw the driver's window", function()
	local w = T.newWorld()
	local a = openDriver(w)
	T.settle(w)
	local DR = a.W.Drive
	ok(DR.SetServeHold(DAN, true), "control: the hold is set")
	DR.Request(DAN, "whisper", "first words")
	w:advance(3)
	local before = firedCount(a, "DRIVE")
	DR.Request(DAN, "whisper", "second words")
	w:advance(0.2)
	ok(firedCount(a, "DRIVE") > before, "the window is told to redraw")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:728-729, :744 and :745 (mutation run, mutants 19123, 1059, 20539, 22588)
test("mutation queue: when a party must become a raid the driver is told once, in the game's own words for the question", function()
	local w = T.newWorld()
	local a = openDriver(w)
	local names = { "Bea Four", "Cy Five", "Di Six", "Ed Seven", "Flo Eight", "Gus Nine" }
	for _, n in ipairs(names) do w:addBot(n, { spot = "Ratchet", acceptsInvites = true }) end
	T.settle(w)
	a.env.CONVERT_TO_RAID = "Make this a raid group?"
	ok(a.W.Drive.SetOpen(true), "driver opens")
	a.W.Drive.opts().oneAtATime = false
	a.W.Drive.opts().maxGroup = 10
	w:advance(3)
	for _, n in ipairs(names) do w:botWhisper(n, a, "summon pls") end
	w:advance(20)
	ok(a.popups.CONVERT_TO_RAID, "control: the game asks to make the party a raid")
	eq(#alertsOf(a, "The game asks \"Make this a raid group?\" - say yes so"), 1, "told once, with the game's wording")
	eq(#alertsOf(a, "The game asks"), 1, "and not again for the next rider")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:729 and :744 (mutation run, mutants 1059, 20539)
test("mutation queue: a game that gives the raid question no wording still gets the driver's hint, and only once per session", function()
	local w = T.newWorld()
	local a = openDriver(w)
	w:addBot("Bea Four", { spot = "Undercity" })
	w:addBot("Cy Five", { spot = "Undercity" })
	w:addBot("Di Six", { spot = "Undercity" })
	w:addBot("Ed Seven", { spot = "Undercity" })
	w:addBot(DAN, { spot = "Ratchet", acceptsInvites = false })
	T.settle(w)
	w:group({ T.ANITA, "Bea Four", "Cy Five", "Di Six", "Ed Seven" })
	w:advance(2)
	a.env.CONVERT_TO_RAID = ""
	ok(a.W.Drive.SetOpen(true), "driver opens")
	a.W.Drive.opts().oneAtATime = false
	a.W.Drive.opts().maxGroup = 10
	w:advance(3)
	w:botWhisper(DAN, a, "summon pls")
	w:advance(5)
	local c = a.W.Drive.customers[a.W.Key(DAN)]
	eq(c and c.state, "invited", "control: Dan is invited into a full party")
	eq(#alertsOf(a, "The game asks \"Convert to raid\" - say yes so"), 1, "the hint names the question")
	-- the invite goes unanswered and he is queued again: invited again, not told again
	c.state = "queued"
	w:advance(5)
	eq(c.state, "invited", "control: invited a second time")
	eq(#alertsOf(a, "The game asks"), 1, "the hint is not repeated")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:690, :694, :704, :714 (mutation run, mutants 1688, 21583, 15821, 6529)
test("mutation queue: a helper who leads the group hands the lead to the captain first and goes through", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANA, { spot = "Orgrimmar" })
	local c = T.driver(w, T.CAL, { spot = "Orgrimmar" })
	local b = T.rider(w, T.BEA, { spot = "Orgrimmar", class = "PRIEST" })
	T.settle(w)
	b.W.Drive.char().crew = { T.ANA, T.CAL }
	b.W.Drive.char().captain = T.CAL
	w:group({ T.BEA, T.ANA, T.CAL })
	w:advance(2)
	a.W.Drive.char().captain = T.CAL
	c.W.Drive.char().crew = { { name = T.ANA, role = "lock", app = true }, { name = T.BEA, role = "helper", app = true } }
	ok(c.W.Drive.SetOpen(true), "the captain's window is open")
	ok(a.W.Drive.SetOpen(true), "so is the other Warlock's")
	w:advance(4)
	ok(b.W.Drive.IsOpen(), "the helper's window follows")
	local promotedTo
	b.env.C_PartyInfo.PromoteToLeader = function(n) promotedTo = n end
	b.W.Drive.char().crew = { { name = T.ANA, role = "lock", app = true }, { name = T.CAL, role = "lock", app = true } }
	b.W.Drive.peers[b.W.Key(T.ANA)] = { name = T.ANA, role = "L", at = 0 } -- the other Warlock, heard
	local unit, name = b.W.Drive.LeadTarget()
	ok(unit, "control: there is somebody to hand the lead to")
	eq(name, T.CAL, "the captain, though another Warlock's name sorts first")
	eq(b.W.Drive.HandLead(), name, "the hand-over reports who got the lead")
	ok(promotedTo and promotedTo:find("Cal", 1, true), "and the game was asked to promote the captain")
	T.clean(w)
end)


-- guards Wuber/Drive/Queue.lua:693 and :699 (mutation run, mutants 31026, 16962)
test("mutation queue: with no captain in the group a helper hands the lead to a Warlock, never to a fellow helper", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANA, { spot = "Orgrimmar" })
	local b = T.rider(w, T.BEA, { spot = "Orgrimmar", class = "PRIEST" })
	w:addBot("Abe Aa", { spot = "Orgrimmar", class = "PRIEST" })
	T.settle(w)
	b.W.Drive.char().captain = T.CAL
	w:group({ T.BEA, T.ANA, "Abe Aa" })
	w:advance(2)
	ok(a.W.Drive.SetOpen(true), "the Warlock is open")
	w:advance(4)
	b.W.Drive.char().crew = { { name = T.ANA, role = "lock", app = true }, { name = "Abe Aa", role = "helper", app = true } }
	b.W.Drive.peers[b.W.Key(T.ANA)] = { name = T.ANA, role = "L", at = 0 }
	b.W.Drive.peers[b.W.Key("Abe Aa")] = { name = "Abe Aa", role = "H", at = 0 }
	b.W.Drive.Selling = function() return true end -- the captain's window is not here to say so
	local unit, name = b.W.Drive.LeadTarget()
	ok(unit, "control: there is somebody to hand the lead to")
	eq(name, T.ANA, "the Warlock, though the helper's name sorts first")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1071, :1083 and :1084 (mutation run, mutants 19421, 30527, 11163)
test("mutation queue: a group invite is accepted for you only from your own crew, and the game's pop-up is closed at once and again after a moment", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = a.W.Drive
	DR.char().crew = { { name = T.CAL, role = "lock", app = true } }
	ok(DR.SetOpen(true), "the driver is open")
	w:advance(2)
	DR.opts().autoAccept = true
	local accepted, hidden = 0, 0
	a.env.AcceptGroup = function() accepted = accepted + 1 end
	local dialog = {}
	a.env.StaticPopup_FindVisible = function(which) if which == "PARTY_INVITE" then return dialog end end
	a.env.StaticPopup_Hide = function(which) if which == "PARTY_INVITE" then hidden = hidden + 1 end end
	a:fire("PARTY_INVITE_REQUEST", T.BOB)
	w:advance(1)
	eq(accepted, 0, "a stranger's invite is left for you to decide")
	eq(hidden, 0, "and its pop-up stays")
	a:fire("PARTY_INVITE_REQUEST", T.CAL)
	eq(accepted, 1, "a crew member's invite is accepted")
	eq(hidden, 1, "the pop-up is closed at once")
	w:advance(1)
	eq(hidden, 2, "and closed again if the game raised it late")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1342-1349 (mutation run, mutants 26376, 3952, 19806, 19613)
test("mutation queue: a crew window's rider arrives at the leader on the station that window chose, and a later change of station follows", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANA, { spot = "Orgrimmar" })
	local b = T.rider(w, T.BEA, { spot = "Orgrimmar", class = "PRIEST" })
	w:addBot(T.BOB, { spot = "Ratchet", acceptsInvites = false })
	T.settle(w)
	w:group({ T.ANA, T.BEA })
	w:advance(2)
	ok(a.W.Drive.OfferCrew(T.BEA), "setup: the crew offer")
	w:advance(3)
	b.W.Drive.AnswerOffer(T.ANA, true)
	w:advance(3)
	ok(b.W.Drive.char().captain ~= "", "setup: Bea is in Ana's crew")
	ok(a.W.Drive.SetOpen(true), "driver opens")
	a.W.Drive.opts().autoInvite = false
	w:advance(3)
	b.W.Drive.Send("ASK", T.BOB, "", "Ironforge", nil)
	w:advance(3)
	local c = a.W.Drive.customers[a.W.Key(T.BOB)]
	ok(c, "control: Bob is listed at the leader")
	eq(c and c.station, "Ironforge", "on the station the crew window chose")
	eq(a.W.Drive.relayStation, nil, "and the leader does not keep that station for the next rider")
	b.W.Drive.Send("ASK", T.BOB, "", "Darnassus", nil)
	w:advance(3)
	eq(c.station, "Darnassus", "a later answer from the crew window moves him to the new station")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1665 (mutation run, mutant 1866: drop statement)
test("mutation queue: a lead nobody answered is dropped from the list after its time is up", function()
	local w = T.newWorld()
	local a = openDriver(w)
	T.settle(w)
	local DR = a.W.Drive
	ok(DR.SetOpen(true), "driver opens")
	ok(DR.Lead(DAN, "summon?", "say"), "control: Dan is listed as a lead")
	w:advance(DR.LEAD_TTL - 10)
	ok(DR.customers[a.W.Key(DAN)], "still listed a little before the time is up")
	w:advance(30)
	eq(DR.customers[a.W.Key(DAN)], nil, "gone once it is up")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1673 (mutation run, mutant 5643: cmp == -> ~=)
test("mutation queue: the 'invite by hand' hint comes on the third unanswered invite only, not on the others", function()
	local w = T.newWorld()
	local a = openDriver(w)
	local names = { "Bo One", "Bo Two", "Bo Three", "Bo Four" }
	for _, n in ipairs(names) do w:addBot(n, { spot = "Ratchet", acceptsInvites = false }) end
	T.settle(w)
	ok(a.W.Drive.SetOpen(true), "driver opens")
	w:advance(3)
	for _, n in ipairs(names) do w:botWhisper(n, a, "summon pls") end
	w:advance(a.W.Drive.opts().inviteTimeout + 60)
	ok(a.W.Drive.inviteMisses >= 4, "control: four invites went unanswered")
	eq(#alertsOf(a, "Three invites in a row went unanswered"), 1, "the hint was shown once, not on every miss")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:889 (mutation run, mutant 30021: drop statement)
test("mutation queue: a rider whose ride is done is taken off the list when they leave the group", function()
	local w = T.newWorld()
	local a = openDriver(w)
	w:addBot(DAN, { spot = "Ratchet", acceptsInvites = true })
	T.settle(w)
	ok(a.W.Drive.SetOpen(true), "driver opens")
	w:advance(2)
	w:botWhisper(DAN, a, "summon pls")
	w:advance(6)
	local DR = a.W.Drive
	local c = DR.customers[a.W.Key(DAN)]
	eq(c and c.state, "joined", "control: Dan is a waiting rider")
	c.state = "done"
	w:leave(DAN)
	eq(DR.customers[a.W.Key(DAN)], nil, "Dan is off the list at once")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1583 (mutation run, mutant 11478: drop statement)
test("mutation queue: when a driver who typed a place leaves it, the settings screen is told the place is cleared", function()
	local w = T.newWorld()
	local a = openDriver(w)
	T.settle(w)
	local DR = a.W.Drive
	ok(DR.SetOpen(true), "driver opens")
	DR.SetDest("Undercity")
	w:advance(3)
	eq(DR.char().dest, "Undercity", "control: the typed place is kept while standing there")
	local before = 0
	for _, f in ipairs(a.fired) do if f.name == "SETTINGS" and f.args[1] == "dest" then before = before + 1 end end
	w:move(T.ANITA, "Orgrimmar")
	w:advance(6)
	eq(DR.char().dest, "", "the typed place is cleared")
	local after = 0
	for _, f in ipairs(a.fired) do if f.name == "SETTINGS" and f.args[1] == "dest" then after = after + 1 end end
	ok(after > before, "the settings screen was told")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:417, :418 and :426 (mutation run, mutants 5286, 20545, 22223)
test("mutation queue: a rider who names only another place is listed as a lead, and keeps that place when they say 'summon pls' later", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = a.W.Drive
	w:advance(3)
	eq(DR.Request(DAN, "whisper", "do you do UC summ?"), nil, "nobody is queued")
	local c = DR.customers[a.W.Key(DAN)]
	eq(c and c.state, "lead", "listed as a lead")
	ok(c and c.askedFor, "with the place they asked for")
	eq(c and c.heardBy, a.W.Key(T.ANITA), "and this window as the one who heard them")
	-- the next words name no place: still that place, the words are kept
	w:advance(3)
	eq(DR.Request(DAN, "whisper", "summon pls"), nil, "still nobody is queued")
	eq(c.state, "lead", "still a lead")
	eq(c.msg, "summon pls", "their latest words are shown")
	-- a finished rider (not heard by anybody yet) who now asks for another place is heard by this window
	local eve = DR.Lead("Eve Ee", "summon?", "say")
	eve.state, eve.heardBy = "done", nil
	eq(DR.Request("Eve Ee", "whisper", "do you do UC summ?"), nil, "Eve is not queued either")
	eq(eve.heardBy, a.W.Key(T.ANITA), "this window is the one who heard her")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1609 and :1610 (mutation run, mutants 29669, 3294)
test("mutation queue: a queued rider who turns out to want a place the driver does not serve goes back to a lead, and the window is told", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = a.W.Drive
	ok(DR.SetOpen(true), "driver opens")
	DR.opts().autoInvite = false
	w:advance(3)
	local c = DR.Request(DAN, "whisper", "summon pls")
	eq(c and c.state, "queued", "control: Dan is queued")
	c.askFor = "Ironforge"
	c.heardBy = nil
	local function toldCount()
		local n = 0
		for _, f in ipairs(a.fired) do if f.name == "DRIVE_STATE" and f.args[1] == c and f.args[2] == "queued" then n = n + 1 end end
		return n
	end
	local told = toldCount()
	DR.PlaceSweep()
	eq(c.state, "lead", "back to a lead")
	eq(c.askedFor, "Ironforge", "with the place he asked for")
	eq(c.askFor, nil, "no longer a pending ask")
	eq(c.heardBy, a.W.Key(T.ANITA), "this window heard him")
	eq(toldCount(), told + 1, "the window is told he left the queue")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:877 and :879 (mutation run, mutants 18838, 5081)
test("mutation queue: a window that is neither the leader nor in a trusted leader's group still decides on a rider who walks out owing, if it is the captain", function()
	local w = T.newWorld()
	local b = T.driver(w, T.BEA, { spot = "Orgrimmar" })
	local c = T.driver(w, T.CAL, { spot = "Orgrimmar" })
	w:addBot("Abe Aa", { spot = "Orgrimmar", class = "PRIEST" })
	T.settle(w)
	local DR = b.W.Drive
	DR.char().crew = { { name = T.CAL, role = "lock", app = true } }
	w:group({ "Abe Aa", T.BEA, T.CAL })
	w:advance(3)
	ok(not DR.IsLeader(), "control: this window does not lead the group")
	ok(DR.IsCaptain(), "control: it is the captain")
	ok(DR.units[b.W.Key(T.CAL)], "control: the other Warlock is in the group")
	DR.peers[b.W.Key(T.CAL)] = { name = T.CAL, role = "L", at = 0 }
	eq(DR.DecidesNonPayer({}), true, "the captain decides when no trusted window leads the group")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1389-1390 (mutation run, mutants 28370, 4927)
test("mutation queue: when a crew window serves a rider who rode before and is in the group again, the leader starts a fresh ride for them", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANA, { spot = "Orgrimmar" })
	local b = T.rider(w, T.BEA, { spot = "Orgrimmar", class = "PRIEST" })
	w:addBot(T.BOB, { spot = "Ratchet", acceptsInvites = true })
	T.settle(w)
	w:group({ T.ANA, T.BEA })
	w:advance(2)
	ok(a.W.Drive.OfferCrew(T.BEA), "setup: the crew offer")
	w:advance(3)
	b.W.Drive.AnswerOffer(T.ANA, true)
	w:advance(3)
	ok(a.W.Drive.SetOpen(true), "driver opens")
	w:advance(3)
	w:botWhisper(T.BOB, a, "summon pls")
	w:advance(8)
	local DR = a.W.Drive
	local c = DR.customers[a.W.Key(T.BOB)]
	ok(c and DR.units[a.W.Key(T.BOB)], "control: Bob is in the group")
	c.state, c.price, c.paid, c.joinedAt = "done", 99999, 7, nil
	b.W.Drive.Send("ADD", T.BOB, nil)
	w:advance(1)
	eq(c.state, "joined", "back to waiting for a ride")
	eq(c.price, DR.char().price, "the old fare is gone")
	ok(c.joinedAt, "and the waiting time starts again")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:91 (mutation run, mutant 2593: drop statement)
test("mutation queue: a first name alone finds the one rider it belongs to, and nobody when two riders share it", function()
	local w = T.newWorld()
	local a = openDriver(w)
	T.settle(w)
	local DR = a.W.Drive
	ok(DR.Lead(DAN, "summon?", "say"), "control: Dan Miller is listed")
	eq(DR.ResolveKey("Dan"), a.W.Key(DAN), "'Dan' is Dan Miller")
	ok(DR.Lead("Dan Stone", "summon?", "say"), "control: a second Dan is listed")
	eq(DR.ResolveKey("Dan"), a.W.Key("Dan"), "two Dans: the name is left as it was heard")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:565 (mutation run, mutant 22219: drop statement)
test("mutation queue: words from a rider whose ride is done are kept on their row without making them a lead again", function()
	local w = T.newWorld()
	local a = openDriver(w)
	w:addBot(DAN, { spot = "Ratchet", acceptsInvites = true })
	T.settle(w)
	ok(a.W.Drive.SetOpen(true), "driver opens")
	w:advance(2)
	w:botWhisper(DAN, a, "summon pls")
	w:advance(6)
	local DR = a.W.Drive
	local c = DR.customers[a.W.Key(DAN)]
	eq(c and c.state, "joined", "control: Dan is a waiting rider")
	c.state = "done"
	w:botWhisper(DAN, a, "thanks a lot, see you")
	w:advance(1)
	eq(c.state, "done", "he stays done")
	eq(c.msg, "thanks a lot, see you", "his words are on the row")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1365 (mutation run, mutant 11601: drop statement)
test("mutation queue: when the leader lists a rider a crew window had only as a lead, that window starts the ride fresh", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANA, { spot = "Orgrimmar" })
	local b = T.rider(w, T.BEA, { spot = "Orgrimmar", class = "PRIEST" })
	w:addBot(T.BOB, { spot = "Ratchet", acceptsInvites = false })
	T.settle(w)
	w:group({ T.ANA, T.BEA })
	w:advance(2)
	ok(a.W.Drive.OfferCrew(T.BEA), "setup: the crew offer")
	w:advance(3)
	b.W.Drive.AnswerOffer(T.ANA, true)
	w:advance(3)
	ok(a.W.Drive.SetOpen(true), "driver opens")
	a.W.Drive.opts().autoInvite = false
	w:advance(4)
	ok(b.W.Drive.IsOpen(), "control: Bea's window follows")
	local lead = b.W.Drive.Lead(T.BOB, "summon?", "whisper")
	ok(lead, "control: Bea's window has Bob as a lead")
	lead.price = 99999
	a.W.Drive.Send("ASK", T.BOB, "queued", nil, nil)
	w:advance(3)
	local c = b.W.Drive.customers[b.W.Key(T.BOB)]
	eq(c and c.state, "queued", "Bob is queued in Bea's window too")
	eq(c.price, b.W.Drive.char().price, "at her own price, not the old one")
	T.clean(w)
end)


local function crewOfTwo()
	local w = T.newWorld()
	local a = openDriver(w)
	T.settle(w)
	ok(a.W.Drive.SetOpen(true), "driver opens")
	w:advance(2)
	w:addBot("Ed Rider", { spot = "Undercity" })
	w:addBot("Bo Rider", { spot = "Undercity" })
	a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Ed Rider")
	a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Bo Rider")
	w:advance(8)
	local DR = a.W.Drive
	local boUnit
	for i = 1, 4 do if a.W.UnitName("party" .. i) == "Bo Rider" then boUnit = "party" .. i end end
	ok(DR.customers["ed rider"] and DR.customers["bo rider"], "setup: both riders are listed")
	ok(boUnit, "setup: Bo has a party unit")
	local real = a.env.UnitName
	local function hideBo() a.env.UnitName = function(u) local n, r = real(u) if n == "Bo" then return "Unknown", nil end return n, r end end
	local function showBo() a.env.UnitName = real end
	return w, a, DR, hideBo, showBo
end

-- guards Wuber/Drive/Queue.lua:946 and :948 (mutation run, mutants 18858, 21130: drop statement)
test("mutation queue: a name that stays unreadable for good stops holding the list, and a rider who left is dropped", function()
	local w, a, DR, hideBo = crewOfTwo()
	hideBo()
	w:leave("Ed Rider")
	w:advance(8)
	ok(DR.customers["ed rider"], "control: while the roster is short nobody is dropped")
	w:advance(14)
	ok(not DR.customers["ed rider"], "after the wait, the rider who left is dropped")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:951 (mutation run, mutant 31529: drop statement)
test("mutation queue: many roster events while the roster is short ask for one look, not one each", function()
	local function looksAfter(events)
		local w, a, DR, hideBo = crewOfTwo()
		hideBo()
		local real = DR.SyncRoster
		DR.SyncRoster = function(...) return real(...) end
		for _ = 1, events do real() end
		local syncs = 0
		DR.SyncRoster = function(...) syncs = syncs + 1 return real(...) end
		w:advance(3.5)
		DR.SyncRoster = real
		T.clean(w)
		return syncs
	end
	local one = looksAfter(1)
	ok(one >= 1, "control: the pause ends in a look")
	eq(looksAfter(5), one, "five events ask for no more looks than one")
end)

local ANA, BEA, CAL = "Ana Smith", "Bea Jones", "Cal Brown"
local function crewSavedFor(me, names, captain)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end
	end
	return { chars = { [(me:lower())] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true } } }
end
-- a crew of three Warlocks: the driver stands in Orgrimmar, the other two in Undercity (two stations)
local function twoStations()
	local w = T.H.NewWorld({})
	local names = { ANA, BEA, CAL }
	local cs = {}
	for i, n in ipairs(names) do
		cs[i] = w:addClient(n, { spot = (i == 1) and "Orgrimmar" or "Undercity", class = "WARLOCK", saved = { Wuber = crewSavedFor(n, names, ANA) } })
	end
	w:group(names)
	w:advance(2)
	cs[1].W.Drive.SetOpen(true)
	w:advance(5)
	return w, cs[1]
end

-- guards Wuber/Drive/Queue.lua:463 (mutation run, mutant 28419: swap or->and; :464 is the same value, equivalent)
test("mutation queue: a lead the driver adds who named a place no station serves goes to the first open station", function()
	local w, ana = twoStations()
	local DR = ana.W.Drive
	w:addBot("Eve Long", { spot = "Thunder Bluff" })
	local e = DR.Request("Eve Long", "manual", "summon to thunder bluff")
	ok(e, "the driver's own choice is queued")
	eq(e.station, "Orgrimmar", "on the first open station")
	eq(e.forPlace, "Orgrimmar", "and the request remembers it")
	T.clean(w)
end)

local function askedWhere(w, ana)
	local DR = ana.W.Drive
	w:addBot("Dan Miller", { spot = "Thunder Bluff" })
	w:botWhisper("Dan Miller", ana, "summon pls")
	w:advance(0.3)
	local c = DR.customers["dan miller"]
	ok(c and c.askWhere and c.station == "Orgrimmar", "setup: asked 'Where to?', first station for now")
	return DR, c
end

local function recordAsks(DR)
	local asks = {}
	local send = DR.Send
	DR.Send = function(kind, name, a, station, ...)
		if kind == "ASK" then asks[#asks + 1] = station end
		return send(kind, name, a, station, ...)
	end
	return asks
end

-- guards Wuber/Drive/Queue.lua:517 (mutation run, mutant 26304: local value -> nil)
test("mutation queue: an answer to 'Where to?' that names the station already set tells the crew nothing new", function()
	local w, ana = twoStations()
	local DR, c = askedWhere(w, ana)
	local asks = recordAsks(DR)
	w:botWhisper("Dan Miller", ana, "orgrimmar")
	w:advance(0.1)
	eq(c.station, "Orgrimmar", "control: the station is the same")
	eq(#asks, 0, "no new ASK to the crew")
	T.clean(w)
end)

test("mutation queue: an answer to 'Where to?' naming another station moves the rider and tells the crew", function()
	local w, ana = twoStations()
	local DR, c = askedWhere(w, ana)
	local asks = recordAsks(DR)
	w:botWhisper("Dan Miller", ana, "undercity")
	w:advance(0.1)
	eq(c.station, "Undercity", "the rider goes to Undercity")
	eq(c.forPlace, "Undercity", "and the request remembers that place")
	eq(asks[1], "Undercity", "the crew is told")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:521 (mutation run, mutant 23028: swap and->or)
test("mutation queue: with only one station left open an answer moves the rider but not the place the request remembers", function()
	local w, ana = twoStations()
	local DR, c = askedWhere(w, ana)
	DR.SetStation("Orgrimmar", false)
	w:advance(0.1)
	ok(not DR.MultiStation(), "setup: one station is open")
	w:botWhisper("Dan Miller", ana, "undercity")
	w:advance(0.1)
	eq(c.station, "Undercity", "the rider is routed to the open station")
	eq(c.forPlace, "Orgrimmar", "the place the request remembers is kept")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:783 (mutation run, mutant 3754: return -> nil)
test("mutation queue: inviting a queued rider by hand gives the rider's row back, invited", function()
	local w = T.newWorld()
	local a = openDriver(w)
	T.settle(w)
	local DR = a.W.Drive
	ok(DR.SetOpen(true), "driver opens")
	DR.opts().autoInvite = false
	w:advance(2)
	w:addBot(DAN, { spot = "Undercity" })
	w:botWhisper(DAN, a, "summon pls")
	w:advance(1)
	local c = DR.customers[a.W.Key(DAN)]
	eq(c and c.state, "queued", "setup: queued, not invited by itself")
	local got = DR.Invite(c)
	ok(got == c, "the same row comes back")
	eq(c.state, "invited", "and they are invited")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:839 (mutation run, mutant 195: if cond negated)
test("mutation queue: the game's 'declined' line changes nobody who is already riding, and nobody it does not know", function()
	local w = T.newWorld()
	local a = openDriver(w)
	T.settle(w)
	local DR = a.W.Drive
	ok(DR.SetOpen(true), "driver opens")
	w:advance(2)
	a.env.ERR_DECLINE_GROUP_S = "%s declines your group invitation."
	w:addBot(DAN, { spot = "Undercity" })
	w:botWhisper(DAN, a, "summon pls")
	w:advance(8)
	local c = DR.customers[a.W.Key(DAN)]
	ok(c and DR.Rank(c.state) >= DR.Rank("joined"), "setup: Dan is riding with the group")
	local state = c.state
	a:fire("CHAT_MSG_SYSTEM", "Dan Miller declines your group invitation.")
	a:fire("CHAT_MSG_SYSTEM", "Nobody Known declines your group invitation.")
	w:advance(1)
	ok(DR.customers[a.W.Key(DAN)] == c, "Dan keeps his row")
	eq(c.state, state, "and his state")
	T.clean(w)
end)
