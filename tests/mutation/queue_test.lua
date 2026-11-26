-- Tests from the mutation run (job 2765): the driver queue, leads and invites (Drive/Queue.lua).
-- Each test guards one line that no other test noticed when it was broken. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local DAN = "Dan Miller"

local function dropsFor(w, name)
	local n = 0
	for _, e in ipairs(w.addonLog) do
		if type(e.text) == "string" and e.text:sub(1, 7) == "DROP~1~" and e.text:find(name, 1, true) then n = n + 1 end
	end
	return n
end

local function invitesTo(w, name)
	local n = 0
	for _, i in ipairs(w.invites) do if i.to == name then n = n + 1 end end
	return n
end

-- the alerts the driver's window raised (DRIVE_ALERT) that hold a piece of text
local function alertsOf(a, part)
	local out = {}
	for _, f in ipairs(a.fired) do
		if f.name == "DRIVE_ALERT" and tostring(f.args[1]):find(part, 1, true) then out[#out + 1] = f.args[1] end
	end
	return out
end

-- a solo Warlock driver in Undercity, open
local function openDriver(w)
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	return a
end

-- guards Wuber/Drive/Queue.lua:730 (mutation run 2765, mutant 20811: return -> nil)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation queue: the raid-conversion hint names the game's question even when the game gives no text for it", function()
	local w = T.newWorld()
	local a = openDriver(w)
	local names = { "Bea Four", "Cy Five", "Di Six", "Ed Seven", "Flo Eight" }
	for _, n in ipairs(names) do w:addBot(n, { spot = "Ratchet", acceptsInvites = true }) end
	T.settle(w)
	a.env.CONVERT_TO_RAID = ""
	ok(a.W.Drive.SetOpen(true), "driver opens")
	a.W.Drive.opts().oneAtATime = false
	a.W.Drive.opts().maxGroup = 10
	w:advance(3)
	for _, n in ipairs(names) do w:botWhisper(n, a, "summon pls") end
	w:advance(15)
	ok(a.popups.CONVERT_TO_RAID, "control: the game asks to make the party a raid")
	eq(#alertsOf(a, "The game asks \"Convert to raid\" - say yes so"), 1, "the driver is told which question to say yes to")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:824 (mutation run 2765, mutant 12726: drop statement)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation queue: after the game says the party is full, nobody is invited for the next 15 seconds", function()
	local w = T.newWorld()
	local a = openDriver(w)
	w:addBot(T.BOB, { spot = "Ratchet", acceptsInvites = false })
	T.settle(w)
	ok(a.W.Drive.SetOpen(true), "driver opens")
	w:advance(3)
	a:fire("CHAT_MSG_SYSTEM", "Your party is full.")
	w:botWhisper(T.BOB, a, "summon pls")
	w:advance(8)
	eq(invitesTo(w, T.BOB), 0, "no invite while the party is full")
	w:advance(20)
	eq(invitesTo(w, T.BOB), 1, "the invite goes out once the hold is over")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1674 (mutation run 2765, mutant 3358: drop statement)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation queue: three invites in a row that go unanswered tell the driver to invite by hand", function()
	local w = T.newWorld()
	local a = openDriver(w)
	local names = { "Bo One", "Bo Two", "Bo Three" }
	for _, n in ipairs(names) do w:addBot(n, { spot = "Ratchet", acceptsInvites = false }) end
	T.settle(w)
	ok(a.W.Drive.SetOpen(true), "driver opens")
	w:advance(3)
	for _, n in ipairs(names) do w:botWhisper(n, a, "summon pls") end
	w:advance(30)
	ok(#alertsOf(a, "Three invites in a row") == 0, "not yet: they have not timed out")
	w:advance(a.W.Drive.opts().inviteTimeout + 30)
	ok(#alertsOf(a, "Three invites in a row went unanswered") == 1, "the driver is told to invite by hand")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:845 (mutation run 2765, mutant 21540: swap and->or)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation queue: a rider who was only queued and turns out to be in a group is not dropped from the crew's lists", function()
	local w = T.newWorld()
	local a = openDriver(w)
	w:addBot(T.BEA, { spot = "Undercity" })
	w:addBot(DAN, { spot = "Ratchet", acceptsInvites = false })
	T.settle(w)
	w:group({ T.ANITA, T.BEA })
	w:advance(2)
	ok(a.W.Drive.SetOpen(true), "driver opens")
	a.W.Drive.opts().autoInvite = false
	w:advance(2)
	w:botWhisper(DAN, a, "summon pls")
	w:advance(3)
	local c = a.W.Drive.customers[a.W.Key(DAN)]
	eq(c and c.state, "queued", "control: Dan waits in the queue, not invited")
	a:fire("CHAT_MSG_SYSTEM", DAN .. " is already in a group.")
	w:advance(1)
	eq(c.state, "lead", "Dan is busy: back to a lead")
	eq(dropsFor(w, DAN), 0, "no crew window is told to drop a rider who was never invited")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1345 (mutation run 2765, mutant 16761: drop statement)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation queue: the fare a crew window locked for a listed rider becomes that rider's price here", function()
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
	w:botWhisper(T.BOB, a, "summon pls")
	w:advance(3)
	local c = a.W.Drive.customers[a.W.Key(T.BOB)]
	eq(c and c.state, "queued", "control: Bob waits in the queue")
	ok(c.price ~= 77777, "control: not the locked fare yet")
	-- the crew window that heard Bob sends its ASK line over the wire (name, no state, no station, the fare)
	b.W.Drive.Send("ASK", T.BOB, nil, nil, 77777)
	w:advance(3)
	eq(c.price, 77777, "the locked fare is the rider's price")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:706 (mutation run 2765, mutant 25100: cmp <->>=)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation queue: a helper hands the lead over at once, and does not ask again within five seconds", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANA, { spot = "Orgrimmar" })
	local b = T.rider(w, T.BEA, { spot = "Orgrimmar", class = "PRIEST" })
	T.settle(w)
	b.W.Drive.char().crew = { T.ANA }
	b.W.Drive.char().captain = T.ANA
	w:group({ T.BEA, T.ANA })
	w:advance(2)
	ok(a.W.Drive.SetOpen(true), "the driver is open")
	w:advance(3)
	ok(b.W.Drive.IsOpen(), "the helper's window is open with the driver's")
	local promoted = 0
	b.env.C_PartyInfo.PromoteToLeader = function() promoted = promoted + 1 end
	ok(b.W.Drive.LeadFix(), "control: Bea has a lead to hand over")
	ok(b.W.Drive.HandLead(), "the first hand-over goes out")
	eq(promoted, 1, "the lead was offered once")
	b.W.Drive.HandLead()
	eq(promoted, 1, "a second try straight after is held back")
	w:advance(6)
	b.W.Drive.HandLead()
	eq(promoted, 2, "after five seconds it tries again")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:374 (mutation run 2765, mutant 30754: cmp <->>=)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation queue: when the lead list is full, the oldest lead makes room for the newest", function()
	local w = T.newWorld()
	local a = openDriver(w)
	T.settle(w)
	local DR = a.W.Drive
	local names = { "Ann Aa", "Bea Bb", "Cyd Cc", "Dee Dd", "Eve Ee", "Fay Ff", "Gus Gg" }
	for i, n in ipairs(names) do
		ok(DR.Lead(n, "summon?", "say"), "lead " .. i)
		w:advance(1)
	end
	local list = {}
	for _, c in pairs(DR.customers) do if c.state == "lead" then list[#list + 1] = c.name end end
	eq(#list, 6, "the list keeps six leads")
	eq(DR.customers[a.W.Key("Ann Aa")], nil, "the oldest lead is the one that goes")
	ok(DR.customers[a.W.Key("Gus Gg")], "the newest lead is on the list")
	ok(DR.customers[a.W.Key("Fay Ff")], "and so is the one before it")
	T.clean(w)
end)

-- guards Wuber/Drive/Queue.lua:1039 (mutation run 2765, mutant 10030: drop statement)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation queue: a friend who came along and leaves the group is off the list as soon as the group changes", function()
	local w = T.newWorld()
	local a = openDriver(w)
	w:addBot(DAN, { spot = "Ratchet", acceptsInvites = true })
	w:addBot("Eve Ee", { spot = "Ratchet" })
	T.settle(w)
	ok(a.W.Drive.SetOpen(true), "driver opens")
	w:advance(2)
	w:botWhisper(DAN, a, "summon pls")
	w:advance(6)
	local DR = a.W.Drive
	eq(DR.customers[a.W.Key(DAN)] and DR.customers[a.W.Key(DAN)].state, "joined", "control: Dan is a waiting rider")
	w:group({ T.ANITA, DAN, "Eve Ee" })
	w:advance(0.2)
	local eve = DR.customers[a.W.Key("Eve Ee")]
	eq(eve and eve.cameWith, DAN, "control: Eve is listed as having come with Dan")
	w:leave("Eve Ee")
	eq(DR.customers[a.W.Key("Eve Ee")], nil, "Eve is off the list the moment she leaves")
	T.clean(w)
end)
