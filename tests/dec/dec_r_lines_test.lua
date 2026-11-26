-- Decisions round, group R: "More lines sent by themselves" (the author's yes of 21 Nov 2026 22:28). With its
-- switch on (Messages, off by default) the greeting (when the rider's summon cast starts), the pay reminder or
-- "You're next" (to a rider without the app who is first in the line) goes out by itself as a whisper to the
-- driver's own rider (Wuber/Drive/AutoLines.lua). These tests hold the guards: the fake game's rule (H.linesRule,
-- which raises on a self-sent line to anyone who is not a rider on the sender's list), tools/check.lua (check 8),
-- each limit of the module, the switches in Messages, and the chat gauntlet replayed with the switches on (no line
-- to a stranger) and off (no self-sent line at all). Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"
local SPOT = "Undercity"
local SITE = "/x/Wuber/Drive/AutoLines.lua"

-- the whispers that went by themselves (how = "auto"), to one player or to anyone
local function autos(w, name)
	local out = {}
	for _, x in ipairs(w.whispers) do
		if x.how == "auto" and (not name or H.key(x.to) == H.key(name)) then out[#out + 1] = x end
	end
	return out
end

-- a Warlock driver, open, with two helpers in the group (they click the portal); on: the lines switched on
local function scene(on, spot)
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = spot or SPOT, class = "WARLOCK", shards = 10 })
	w:addBot("Bob Helper", { spot = spot or SPOT })
	w:addBot("Bo Second", { spot = spot or SPOT })
	w:group({ ANITA, "Bob Helper", "Bo Second" })
	w:advance(1)
	local DR = a.W.Drive
	ok(DR.SetOpen(true), "the driver opens")
	w:advance(2)
	for _, kind in ipairs(on or {}) do DR.SetLineOn(kind, true) end
	return w, a, DR
end

-- a player without Wuber whispers a clear request and joins the group
local function asks(w, a, DR, name, text)
	w:addBot(name, { spot = "Orgrimmar" })
	w:botWhisper(name, a, text or "summon pls")
	w:advance(3)
	return DR.Find(name)
end

local function press(a)
	local b = a.env.WuberDriveButton
	ok(b and H.visible(b), "the big button is shown")
	return a:click(b)
end

-- the click casts, both helpers click the portal, the rider takes the summon and lands
local function lands(w, a, DR, name)
	press(a)
	w:advance(3)
	w:clickPortal("Bob Helper")
	w:clickPortal("Bo Second")
	w:advance(12)
	local c = DR.Find(name)
	eq(c and c.state, "arrived", name .. " landed")
	return c
end

-- the summon cast for rider c starts (the fact every crew window hears), without a click
local function castStarts(a, c)
	a.W.Fire("DRIVE_RITUAL", c.name, "c", { key = c.key, mine = true })
end

-- calls the fake game's chat function as if from the lines call site (a chunk named as that file)
local function fromSite(a, text, kind, target)
	local chunk = assert(loadstring("local send, a, b, c, d = ... local r = send(a, b, c, d) return r",
		"@" .. H.ADDONS.Wuber .. "/Drive/AutoLines.lua"))
	return pcall(chunk, a.env.C_ChatInfo.SendChatMessage, text, kind, nil, target)
end

---------------------------------------------------------------------------
-- 1. the fake game's rule
---------------------------------------------------------------------------

test("dec r: the fake game lets a self-sent whisper go only to a rider on the sender's list, and raises otherwise", function()
	local w, a, DR = scene()
	local c = asks(w, a, DR, "Dan Moss")
	eq(c and c.state, "joined", "Dan asked by a whisper and is in the group")
	w:addBot("Sam Stranger", { spot = "Orgrimmar" })
	w:addBot("Lea Lead", { spot = "Orgrimmar" })
	w:botWhisper("Lea Lead", a, "hello there")
	w:advance(1)
	local rule = H.linesRule
	eq(rule(w, a, "WHISPER", "Dan-Moss", SITE, "hi"), nil, "allowed: a whisper from the call site to the driver's rider")
	ok(rule(w, a, "SAY", "Dan-Moss", SITE, "hi"), "never a say line")
	ok(rule(w, a, "PARTY", nil, SITE, "hi"), "never a party line")
	ok(rule(w, a, "CHANNEL", "2", SITE, "hi"), "never a channel line")
	ok(rule(w, a, "WHISPER", "Dan-Moss", "/x/Wuber/Drive/Queue.lua", "hi"), "never from another file")
	eq(rule(w, a, "WHISPER", "Sam-Stranger", SITE, "hi"), "to a player who is not on the sender's list", "never to a stranger")
	ok(tostring(rule(w, a, "WHISPER", "Bob-Helper", SITE, "hi")):find("did not ask this driver", 1, true), "never to a group member who is no rider")
	local lead = DR.Find("Lea Lead")
	ok(lead and lead.state == "lead", "Lea is a lead row: " .. tostring(lead and lead.state))
	eq(rule(w, a, "WHISPER", "Lea-Lead", SITE, "hi"), "to a lead row, not a rider", "never to a lead row")
	eq(rule(w, a, "WHISPER", ANITA, SITE, "hi"), "a whisper to yourself", "never to yourself")
	w:enterCombat(a)
	eq(rule(w, a, "WHISPER", "Dan-Moss", SITE, "hi"), "in combat", "never in combat")
	w:leaveCombat(a)
	a.player.instance = true
	eq(rule(w, a, "WHISPER", "Dan-Moss", SITE, "hi"), "in an instance", "never in an instance")
	a.player.instance = nil
	-- the list alone is not enough: the fake game's own facts must agree
	local was = c.source
	c.source = "public"
	ok(rule(w, a, "WHISPER", "Dan-Moss", SITE, "hi"), "never to a rider from public chat")
	c.source = "manual"
	ok(rule(w, a, "WHISPER", "Dan-Moss", SITE, "hi"), "never to a rider added by hand")
	c.source = was
	DR.customers[H.key("Sam Stranger")] = { name = "Sam Stranger", key = H.key("Sam Stranger"), state = "joined", source = "whisper" }
	eq(rule(w, a, "WHISPER", "Sam-Stranger", SITE, "hi"), "to a player who is not in the sender's group", "a made-up row for someone outside the group")
	DR.customers[H.key("Sam Stranger")] = nil
	local bobRow = DR.customers[H.key("Bob Helper")]
	DR.customers[H.key("Bob Helper")] = { name = "Bob Helper", key = H.key("Bob Helper"), state = "joined", source = "whisper" }
	eq(rule(w, a, "WHISPER", "Bob-Helper", SITE, "hi"), "to a player who never whispered the sender", "a made-up row for a group member who never asked")
	DR.customers[H.key("Bob Helper")] = bobRow
	DR.db.blocklist[c.key] = { name = c.name, reason = "test" }
	eq(rule(w, a, "WHISPER", "Dan-Moss", SITE, "hi"), "to a blocked player", "never to a blocked player")
	DR.db.blocklist[c.key] = nil
	a.W.drivers[c.key] = { state = "open" }
	eq(rule(w, a, "WHISPER", "Dan-Moss", SITE, "hi"), "to another Wuber driver", "never to a [Wuber] driver")
	a.W.drivers[c.key] = nil
	-- pacing
	w.autoLines = { [ANITA] = { { to = "Dan Moss", text = "hi", at = w.time } } }
	ok(rule(w, a, "WHISPER", "Dan-Moss", SITE, "other words"), "not within 2 seconds of the last one")
	w:advance(5)
	eq(rule(w, a, "WHISPER", "Dan-Moss", SITE, "other words"), "two self-sent lines to the same player within 20 seconds", "20 seconds between two lines to one player")
	w:advance(20)
	eq(rule(w, a, "WHISPER", "Dan-Moss", SITE, "other words"), nil, "another line after 20 seconds")
	eq(rule(w, a, "WHISPER", "Dan-Moss", SITE, "hi"), "the same line twice to the same player within 10 minutes", "the same words: 10 minutes")
	local log = {}
	for i = 1, 8 do log[i] = { to = "Someone Else", text = "x", at = w.time - 50 + i * 5 } end
	w.autoLines = { [ANITA] = log }
	eq(rule(w, a, "WHISPER", "Dan-Moss", SITE, "hi"), "more than 8 self-sent whispers in a minute", "8 a minute")
	w.autoLines = nil
	-- the real call: from the call site to a stranger it is a violation AND it raises; to the rider it goes
	local okCall, err = fromSite(a, "hello", "WHISPER", "Sam-Stranger")
	ok(not okCall, "the fake game raises")
	ok(tostring(err):find("a self-sent line broke its rule", 1, true), tostring(err))
	eq(#w.violations, 1, "and records a violation")
	ok(tostring(w.violations[1]):find("not on the sender's list", 1, true), tostring(w.violations[1]))
	eq(#autos(w), 0, "nothing was whispered")
	w.violations = {}
	ok(fromSite(a, "hello Dan", "WHISPER", "Dan-Moss"), "to the rider the call goes through")
	eq(#autos(w, "Dan Moss"), 1, "recorded as a self-sent whisper (how = auto)")
	eq(#w.violations, 0, "no violation")
	a.W.lastError = nil
	T.clean(w)
end)

test("dec r: check.lua allows SendChatMessage on one line of Drive/AutoLines.lua and nowhere new", function()
	local scan = T.CHECK.scanChat
	local call = "local _, W = ...\nlocal function send(t, n) C_ChatInfo.SendChatMessage(t, 'WHISPER', nil, n) end\n"
	eq(scan("Drive/AutoLines.lua", call), nil, "the call site may name it once")
	eq(scan("Drive/AutoLines.lua", call .. "SendChatMessage('x', 'SAY')\n"), 3, "a second line in the call site fails")
	eq(scan("UI/Driver/Messages.lua", call), 2, "the Messages screen may not")
	eq(scan("Drive/Chat.lua", call), 2, "Drive/Chat.lua may not")
	eq(T.CHECK.CHAT_ALLOW["Drive/AutoLines.lua"], 1, "one line")
	local n = 0
	for _ in pairs(T.CHECK.CHAT_ALLOW) do n = n + 1 end
	eq(n, 3, "three files on the list: the two call sites, and Core/Runtime.lua's table of names")
	local res = T.CHECK.check({ root = H.root, files = { "Drive/AutoLines.lua" }, globals = nil })
	for _, f in ipairs(res.fails) do ok(not f:find("SendChatMessage", 1, true), f) end
end)

---------------------------------------------------------------------------
-- 2. the switches, and the two lines
---------------------------------------------------------------------------

test("dec r: with the switches off (the default) nothing goes by itself: the click sends the greeting, as before", function()
	local w, a, DR = scene()
	eq(DR.LineOn("greet"), false, "the greeting's switch is off by default")
	eq(DR.LineOn("pay"), false, "the pay reminder's switch is off by default")
	eq(a.W.db.drive.lines, nil, "nothing is saved until a switch is turned on")
	local c = asks(w, a, DR, "Dan Moss")
	eq(c and c.state, "joined", "Dan is in the group")
	w:advance(5)
	eq(#autos(w), 0, "no self-sent whisper")
	ok(not c.greeted, "not greeted yet: it waits for the click")
	c = lands(w, a, DR, "Dan Moss")
	local got = w:whispersTo("Dan Moss", "macro")
	eq(#got, 1, "the click whispered the greeting")
	eq(got[1].text, DR.Text("greet", c), "the greeting's words")
	w:advance(60)
	eq(#autos(w), 0, "the pay reminder waits for its click too")
	ok(not c.reminded, "not reminded")
	eq(DR.LineOn("next"), false, "the switch of You're next is off by default")
	eq(#DR.LINE_KINDS, 3, "three lines can go by themselves")
	eq(DR.SetLineOn("oops", true), false, "there is no fourth line")
	eq(DR.LineOn("thanks"), false, "no other message can be switched on")
	eq(DR.SetLineOn("thanks", true), false, "no other message can be switched on")
	T.clean(w)
end)

test("dec r: the greeting's switch on: it goes by itself when the rider's summon cast starts, in the driver's own words, once; the click goes straight to the cast", function()
	local w, a, DR = scene({ "greet" })
	ok(DR.SetTemplate("greet", "Hello {name}, your summon to {dest} is on its way."), "the driver's own words")
	eq(a.W.db.drive.lines.greet, true, "saved with the account's messages")
	local c = asks(w, a, DR, "Dan Moss")
	eq(c and c.state, "joined", "Dan is in the group")
	w:advance(20)
	eq(#autos(w), 0, "no greeting while the driver is idle: nothing is cast yet")
	ok(not c.greeted, "not greeted yet")
	eq(DR.LineTakes("greet", c), true, "the greeting of a rider who asked is this file's, not the click's")
	local plan = DR.Plan()
	eq(plan.summon, c, "the big button's click is the cast for Dan")
	ok(plan.macrotext and not plan.macrotext:find("/w ", 1, true), "and holds no whisper: the click goes straight to the cast: " .. tostring(plan.macrotext))
	ok(not plan.greets and not plan.box, "no greeting step, in the macro or the chat box")
	press(a)
	w:advance(1)
	local got = autos(w, "Dan Moss")
	eq(#got, 1, "the cast started: one self-sent whisper to Dan")
	eq(got[1].text, "Hello Dan, your summon to Undercity is on its way.", "the driver's own words, filled in")
	ok(c.greeted, "marked as greeted")
	eq(DR.LastLine().kind, "greet", "DR.LastLine says what went")
	w:advance(2)
	w:clickPortal("Bob Helper")
	w:clickPortal("Bo Second")
	w:advance(12)
	c = DR.Find("Dan Moss")
	eq(c and c.state, "arrived", "Dan landed")
	eq(#w:whispersTo("Dan Moss", "macro"), 0, "the click did not greet")
	eq(#autos(w, "Dan Moss"), 1, "still one")
	castStarts(a, c)
	eq(#autos(w, "Dan Moss"), 1, "a second cast on the same ride greets no second time")
	w:advance(60)
	eq(#autos(w, "Dan Moss"), 1, "the pay reminder's switch is off: it waits for its click")
	ok(not c.reminded, "not reminded by itself")
	-- a rider the line never goes to (added by hand) is greeted by the click, as before
	w:addBot("Hank Hand", { spot = "Orgrimmar" })
	local h = DR.Request("Hank Hand", "manual")
	w:advance(4)
	h = DR.Find("Hank Hand")
	if h and h.state == "joined" then
		eq(DR.LineTakes("greet", h), false, "a name added by hand: the click greets")
		c.walked = true
		local p2 = DR.Plan()
		if p2.summon == h then ok(p2.greets == true, "the click's macro holds Hank's greeting") end
	end
	-- the switch off: everything as before, the click greets
	DR.SetLineOn("greet", false)
	eq(DR.LineTakes("greet", c), false, "with the switch off the greeting is the click's")
	T.clean(w)
end)

test("dec r: the pay reminder's switch on: it goes by itself only after the rider landed, once per ride", function()
	local w, a, DR = scene({ "pay" })
	DR.SetOpt("autoTrade", false)
	local c = asks(w, a, DR, "Dan Moss")
	eq(c and c.state, "joined", "Dan is in the group")
	local can, why = DR.CanLine("pay", c)
	eq(can, false, "not before the summon")
	eq(why, "not landed yet", "why")
	eq(#autos(w), 0, "the greeting's switch is off: nothing by itself")
	c = lands(w, a, DR, "Dan Moss")
	eq(#w:whispersTo("Dan Moss", "macro"), 1, "the click greeted")
	eq(#autos(w), 0, "nothing yet: the reminder is due 25 seconds after landing")
	w:advance(30)
	local got = autos(w, "Dan Moss")
	eq(#got, 1, "the pay reminder went by itself")
	eq(got[1].text, DR.Text("pay", c), "the words of the Welcome, please pay message")
	ok(c.reminded, "marked as reminded")
	local plan = DR.Plan()
	ok(not (plan.macrotext or ""):find("/w ", 1, true), "the button does not offer it again: " .. tostring(plan.macrotext))
	w:advance(900)
	eq(#autos(w, "Dan Moss"), 1, "never a second reminder on this ride")
	can, why = DR.CanLine("pay", c)
	eq(can, false, "refused")
	eq(why, "already reminded on this ride", "why")
	c.reminded = nil
	can, why = DR.CanLine("pay", c)
	eq(can, true, "(a control: with the mark taken away and 15 minutes gone it could go)")
	DR.SetOpt("remindPay", false)
	can, why = DR.CanLine("pay", c)
	eq(why, "pay reminders are off", "never with Remind riders who haven't paid switched off in Settings")
	DR.SetOpt("remindPay", true)
	c.reminded = true
	T.clean(w)
end)

---------------------------------------------------------------------------
-- 3. the limits
---------------------------------------------------------------------------

test("dec r: never in combat: a greeting that cannot go when the cast starts is dropped for that ride; the pay reminder waits for its click", function()
	local w, a, DR = scene({ "greet", "pay" })
	DR.SetOpt("autoTrade", false)
	local c = asks(w, a, DR, "Dan Moss")
	eq(c and c.state, "joined", "Dan is in the group")
	w:enterCombat(a)
	local can, why = DR.CanLine("greet", c)
	eq(can, false, "refused in combat")
	eq(why, "in combat", "why")
	castStarts(a, c)
	eq(#autos(w), 0, "nothing by itself in combat")
	w:leaveCombat(a)
	w:advance(30)
	eq(#autos(w), 0, "and nothing after the fight either: the line is not queued")
	castStarts(a, c)
	eq(#autos(w), 0, "nor at a second cast on the same ride: the greeting was dropped")
	ok(not c.greeted, "Dan was not greeted")
	local plan = DR.Plan()
	ok(plan.macrotext and not plan.macrotext:find("/w ", 1, true), "and the click does not offer it afterwards: " .. tostring(plan.macrotext))
	a.player.instance = true
	can, why = DR.CanLine("greet", c)
	eq(why, "in an instance", "never in an instance")
	a.player.instance = nil
	-- (a control) the next rider's cast, out of combat: greeted
	local e = asks(w, a, DR, "Eve Hall")
	eq(e and e.state, "joined", "Eve is in the group")
	castStarts(a, e)
	eq(#autos(w, "Eve Hall"), 1, "(a control: Eve's greeting went)")
	e.greeted = true
	-- the pay reminder is still a click's line: in combat at its moment it waits for the click
	c = lands(w, a, DR, "Dan Moss")
	eq(#autos(w, "Dan Moss"), 0, "the cast of the click greeted nobody again")
	w:enterCombat(a)
	w:advance(30)
	w:leaveCombat(a)
	w:advance(5)
	eq(#autos(w, "Dan Moss"), 0, "no pay reminder by itself in or after combat")
	ok(not c.reminded, "it waits")
	plan = DR.Plan()
	ok(plan.macrotext and plan.macrotext:find("/w Dan-Moss ", 1, true), "for its click: " .. tostring(plan.macrotext))
	T.clean(w)
end)

test("dec r: never to anyone who is not the driver's rider: a lead, a public chat buyer, a hand-added name, a driver, a crew member, a blocked player", function()
	local w, a, DR = scene({ "greet", "pay" })
	local c = asks(w, a, DR, "Dan Moss")
	castStarts(a, c)
	eq(#autos(w, "Dan Moss"), 1, "(a control: Dan, who asked by a whisper, was greeted when his summon started)")
	c.greeted = nil
	a.W.Mod("Drive.AutoLines").sent[1] = nil
	local function why(kind, x) local _, y = DR.CanLine(kind, x or c) return y end
	eq(why("greet"), nil, "(a control: Dan could be greeted)")
	local function with(field, value, want, what)
		local was = c[field]
		c[field] = value
		eq(why("greet"), want, what)
		eq((DR.TryLine("greet", c)), false, what .. ": nothing is sent")
		c[field] = was
	end
	with("state", "lead", "a lead, not a rider", "a grey lead row")
	with("state", "invited", "not a rider in your group", "invited, not in the group yet")
	with("state", "queued", "not a rider in your group", "queued")
	with("state", "paid", "not a rider in your group", "paid")
	with("state", "done", "not a rider in your group", "done")
	with("source", "public", "did not ask you by the app or a whisper", "invited from public chat")
	with("source", "manual", "did not ask you by the app or a whisper", "added by hand")
	with("source", "relay", "did not ask you by the app or a whisper", "heard by another crew window")
	with("source", "group", "did not ask you by the app or a whisper", "found in the group")
	with("source", nil, "did not ask you by the app or a whisper", "no source")
	with("offer", true, "invited from public chat", "a public chat offer")
	-- a whisper alone is not enough: it must be one the careful gate took as a clear request (c.auto), or the
	-- app's own request line
	eq(c.auto, "whisper", "(a control: Dan's whisper was taken as a clear request)")
	with("auto", nil, "their whisper was not a clear request", "someone who whispered something else and got into the group another way")
	c.auto, c.msg = nil, "WTB summon to Undercity for 50s"
	eq(why("greet"), nil, "the app's own request line, whispered, is a request")
	c.auto, c.msg = "whisper", "summon pls"
	a.W.drivers[c.key] = { state = "open", dest = "Undercity" }
	eq(why("greet"), "another driver", "a [Wuber] driver")
	a.W.drivers[c.key] = nil
	DR.db.blocklist[c.key] = { name = c.name, reason = "test" }
	eq(why("greet"), "blocked", "a blocked player")
	DR.db.blocklist[c.key] = nil
	local realCrew = DR.IsCrewKey
	DR.IsCrewKey = function(k) return k == c.key or realCrew(k) end
	eq(why("greet"), "a crew member", "a crew member")
	DR.IsCrewKey = realCrew
	DR.helpers[c.key] = true
	eq(why("greet"), "never a rider", "a group member marked Not a rider")
	DR.helpers[c.key] = nil
	-- a row that is not the one on the list, and people who are on no list
	eq(why("greet", { name = "Dan Moss", key = c.key, state = "joined", source = "whisper" }), "not on your list", "a copy of the row")
	eq(why("greet", { name = "Sam Stranger", state = "joined", source = "whisper" }), "not on your list", "a stranger")
	eq(why("greet"), nil, "(a control: Dan could still be greeted)")
	eq(#autos(w), 1, "and through all of it nothing more was sent")
	-- a test-only violation: a made-up row says a helper in the group asked by a whisper. The module believes its
	-- list; the fake game does not (it never saw that whisper): it records a violation, raises, and nothing goes
	local bobRow = DR.customers[H.key("Bob Helper")]
	local fake = { name = "Bob Helper", key = H.key("Bob Helper"), state = "joined", source = "whisper", auto = "whisper" }
	DR.customers[fake.key] = fake
	eq((DR.CanLine("greet", fake)), true, "(the module believes its list)")
	eq((DR.TryLine("greet", fake)), false, "the made-up rider gets nothing")
	eq(#w.violations, 1, "the fake game recorded a violation")
	ok(tostring(w.violations[1]):find("never whispered the sender", 1, true), tostring(w.violations[1]))
	eq(#autos(w), 1, "nothing was whispered")
	DR.customers[fake.key] = bobRow
	w.violations = {}
	a.W.lastError = nil
	T.clean(w, { violations = true })
end)

test("dec r: pacing: the same line not twice in 10 minutes, 20 seconds between two lines to one rider, one whisper every 2 seconds, 8 a minute", function()
	local w, a, DR = scene({ "greet", "pay" })
	local c = asks(w, a, DR, "Dan Moss")
	castStarts(a, c)
	eq(#autos(w, "Dan Moss"), 1, "Dan was greeted by itself")
	local sent = a.W.Mod("Drive.AutoLines").sent
	eq(#sent, 1, "one line on the record")
	local at = sent[1].at
	local function why(kind, x) local _, y = DR.CanLine(kind, x or c) return y end
	-- the same line again (as if the mark were lost)
	c.greeted = nil
	eq(why("greet"), "another line went by itself under 2 seconds ago", "not within 2 seconds of the last self-sent whisper")
	sent[1].at = a.W.Now() - 5
	eq(why("greet"), "another line went to them under 20 seconds ago", "20 seconds between two lines to one rider")
	sent[1].at = a.W.Now() - 300
	eq(why("greet"), "the same line went to them under 10 minutes ago", "the same line: 10 minutes")
	eq((DR.TryLine("greet", c)), false, "and nothing is sent")
	sent[1].at = a.W.Now() - 601
	eq(why("greet"), nil, "after 10 minutes it may go again")
	-- another line to the same rider: 20 seconds
	sent[1].at = a.W.Now() - 5
	c.state, c.reminded = "arrived", nil
	eq(why("pay"), "another line went to them under 20 seconds ago", "the pay reminder waits 20 seconds after the greeting")
	sent[1].at = a.W.Now() - 21
	eq(why("pay"), nil, "then it may go")
	-- over all riders: one every 2 seconds
	sent[1] = { key = "someone else", kind = "greet", at = a.W.Now() - 1 }
	eq(why("pay"), "another line went by itself under 2 seconds ago", "one self-sent whisper every 2 seconds over all riders")
	-- and 8 a minute
	for i = 1, 8 do sent[i] = { key = "rider " .. i, kind = "greet", at = a.W.Now() - 58 + i * 6 } end
	eq(why("pay"), "8 lines went by themselves in the last minute", "8 a minute over all riders")
	eq((DR.TryLine("pay", c)), false, "more than that waits for a click")
	sent[1].at = a.W.Now() - 61
	eq(why("pay"), nil, "with only 7 in the last minute it may go")
	eq(#autos(w), 1, "nothing more was sent by these checks")
	for i = #sent, 1, -1 do sent[i] = nil end
	sent[1] = { key = c.key, kind = "greet", at = at }
	c.state, c.greeted = "joined", true
	T.clean(w)
end)

test("dec r: only the window the rider asked sends by itself, never in raid mode, never with whispers switched off", function()
	local w, a, DR = scene({ "greet", "pay" })
	local c = asks(w, a, DR, "Dan Moss")
	local function why(kind) local _, y = DR.CanLine(kind, c) return y end
	eq(why("greet"), nil, "(a control)")
	-- a crew window that only heard of the rider (the row's source is relay) never greets, whoever casts
	c.source = "relay"
	castStarts(a, c)
	eq(#autos(w), 0, "the cast starts in a window the rider did not ask: nothing by itself")
	eq(DR.LineTakes("greet", c), false, "there the click greets, as before")
	c.source = "whisper"
	a.W.Mod("Drive.AutoLines").sent[1] = nil
	local real = DR.ModeNow
	DR.ModeNow = function() return "raid" end
	eq(why("greet"), "raid summons", "never in raid mode")
	DR.ModeNow = real
	DR.SetOpt("whisperMode", "off")
	eq(why("greet"), "whispers are off", "never with whispers switched off")
	DR.SetOpt("whisperMode", "auto")
	local realRaid = DR.InRaid
	DR.InRaid = function() return true end
	eq(why("greet"), "in a raid", "never in a raid")
	DR.InRaid = realRaid
	DR.SetLineOn("greet", false)
	eq(why("greet"), "switched off", "the switch off")
	eq(a.W.db.drive.lines.greet, nil, "the saved table holds only switches that are on")
	eq(DR.LineOn("pay"), true, "the other switch is its own")
	DR.SetLineOn("greet", true)
	DR.SetOpen(false)
	eq(why("greet"), "not open", "never while closed")
	c.greeted = true
	T.clean(w)
end)

---------------------------------------------------------------------------
-- 3b. "You're next" (the author asked for it by name): only ever sent by itself, to a rider without the app who
-- waits in the driver's line for room
---------------------------------------------------------------------------

local NEXT_WORDS = "You're next, %s. I'll invite you as soon as there is room."

-- a driver who serves one rider at a time, busy with Dan (in the group, not summoned yet): whoever asks now waits
-- in the line for room
local function lineScene(on)
	local w, a, DR = scene(on)
	DR.SetOpt("oneAtATime", true)
	local dan = asks(w, a, DR, "Dan Moss")
	eq(dan and dan.state, "joined", "Dan is in the group: the driver is busy")
	return w, a, DR, dan
end

-- a player without Wuber whispers a clear request and stays in the line
local function queues(w, a, DR, name, text)
	local c = asks(w, a, DR, name, text)
	eq(c and c.state, "queued", name .. " waits in the line")
	return c
end

test("dec r: You're next: the default words are written out, the message can be edited, and it is off by default", function()
	local w, a, DR = scene()
	eq(DR.TEMPLATES.next, "You're next, {name}. I'll invite you as soon as there is room.", "the default words")
	eq(DR.LineOn("next"), false, "off by default")
	local found = false
	for _, k in ipairs(DR.TEMPLATE_ORDER) do found = found or k == "next" end
	ok(found, "listed with the messages a driver can edit")
	eq(DR.Text("next", { name = "Eve Hall" }), NEXT_WORDS:format("Eve"), "filled in for a rider")
	ok(DR.SetTemplate("next", "Nearly there {name}, you are first in my line."), "the driver's own words")
	eq(DR.Text("next", { name = "Eve Hall" }), "Nearly there Eve, you are first in my line.", "used as written")
	ok(DR.SetTemplate("next", ""), "and put back")
	eq(DR.SetLineOn("next", true), true, "its switch can be turned on")
	eq(a.W.db.drive.lines.next, true, "saved with the account's messages")
	eq(DR.LineOn("greet"), false, "the greeting's switch is its own")
	eq(DR.LineOn("pay"), false, "the pay reminder's switch is its own")
	T.clean(w)
end)

test("dec r: You're next: a rider without the app who is first in the line and has waited 10 seconds gets it once; the big button never offers it", function()
	local w, a, DR = lineScene({ "next" })
	local eve = queues(w, a, DR, "Eve Hall")
	w:advance(4)
	eq(#autos(w), 0, "nothing in the first seconds")
	local can, why = DR.CanLine("next", eve)
	eq(can, false, "not yet")
	eq(why, "in your line under 10 seconds", "why")
	local finn = queues(w, a, DR, "Finn Gray")
	w:advance(5)
	local got = autos(w, "Eve Hall")
	eq(#got, 1, "after 10 seconds in the line Eve, the first, was told")
	eq(got[1].text, NEXT_WORDS:format("Eve"), "the words of the You're next message")
	eq(DR.LastLine().kind, "next", "DR.LastLine says what went")
	eq(eve.state, "queued", "she still waits in the line: the line promised nothing more")
	w:advance(30)
	eq(#autos(w, "Eve Hall"), 1, "once")
	eq(#autos(w, "Finn Gray"), 0, "Finn is second in the line: nothing for him")
	can, why = DR.CanLine("next", finn)
	eq(why, "not first in your line", "why")
	can, why = DR.CanLine("next", eve)
	eq(why, "already told on this ride", "Eve is not told twice")
	-- the big button never offers the line
	local plan = DR.Plan()
	for _, m in ipairs(plan.marks or {}) do ok(m.kind ~= "next", "no You're next step in the click") end
	ok(not (plan.box and plan.box.kind == "next"), "nor in the chat box")
	ok(not (plan.macrotext or ""):find("You're next", 1, true), "the click's macro does not hold it: " .. tostring(plan.macrotext))
	-- Eve leaves the line: Finn becomes first, has waited long enough, and is told at once
	DR.Remove(eve)
	w:advance(1)
	got = autos(w, "Finn Gray")
	eq(#got, 1, "Finn, now first in the line, was told")
	eq(got[1].text, NEXT_WORDS:format("Finn"), "his own name in it")
	eq(#autos(w), 2, "two self-sent lines in all")
	eq(#autos(w, "Dan Moss"), 0, "the rider in the group got none")
	T.clean(w)
end)

test("dec r: You're next: with its switch off nothing is sent; a rider who is invited at once gets none", function()
	local w, a, DR = lineScene({ "greet", "pay" })
	local eve = queues(w, a, DR, "Eve Hall")
	w:advance(40)
	eq(#autos(w), 0, "the switch of You're next is off: nothing to the rider in the line")
	local can, why = DR.CanLine("next", eve)
	eq(why, "switched off", "why")
	T.clean(w)
	-- room at once: invited and in the group within seconds, never 10 seconds in the line
	local w2, a2, DR2 = scene({ "next" })
	local dan = asks(w2, a2, DR2, "Dan Moss")
	eq(dan and dan.state, "joined", "Dan was invited at once and joined")
	w2:advance(40)
	eq(#autos(w2), 0, "a rider who is invited at once gets no You're next")
	can, why = DR2.CanLine("next", dan)
	eq(why, "not waiting in your line", "why")
	T.clean(w2)
end)

test("dec r: You're next: a rider with the app gets none (their own screen shows their place)", function()
	local w, a, DR = lineScene({ "next" })
	-- the app's own request line, whispered: a rider whose app could not send its request
	local eve = queues(w, a, DR, "Eve Hall", "WTB summon to Undercity for 50s")
	ok(DR.WuberLine(eve.msg), "(the app's own request line)")
	w:advance(30)
	eq(#autos(w), 0, "nothing to a rider with the app")
	local can, why = DR.CanLine("next", eve)
	eq(why, "has the app: their own screen shows their place", "why")
	-- a request that came by the app: the row's source says so
	eve.msg, eve.auto, eve.source = "summon pls", "whisper", "wuber"
	can, why = DR.CanLine("next", eve)
	eq(why, "has the app: their own screen shows their place", "a row the app's request made")
	eve.source, eve.wuberRide = "whisper", "r1"
	can, why = DR.CanLine("next", eve)
	eq(why, "has the app: their own screen shows their place", "a row that carries a ride of the app")
	eve.wuberRide = nil
	T.clean(w)
end)

test("dec r: You're next: never to a lead, a public chat buyer, a hand-added name, a driver, a crew member or a blocked player; never when the driver invites by hand or is paused", function()
	local w, a, DR = lineScene({ "next" })
	local eve = queues(w, a, DR, "Eve Hall")
	w:advance(4)
	eve.at = a.W.Now() - 11 -- (as if she had waited long enough; the try itself comes after 10 real seconds)
	local function why(x) local _, y = DR.CanLine("next", x or eve) return y end
	eq(why(), nil, "(a control: Eve could be told)")
	local function with(field, value, want, what)
		local was = eve[field]
		eve[field] = value
		eq(why(), want, what)
		eq((DR.TryLine("next", eve)), false, what .. ": nothing is sent")
		eve[field] = was
	end
	with("state", "lead", "a lead, not a rider", "a grey lead row")
	with("state", "invited", "not waiting in your line", "invited already")
	with("state", "joined", "not waiting in your line", "in the group")
	with("state", "arrived", "not waiting in your line", "landed")
	with("state", "done", "not waiting in your line", "done")
	with("source", "public", "did not ask you by the app or a whisper", "a public chat buyer")
	with("source", "manual", "did not ask you by the app or a whisper", "added by hand")
	with("source", "relay", "did not ask you by the app or a whisper", "heard by another crew window")
	with("offer", true, "invited from public chat", "a public chat offer")
	with("auto", nil, "their whisper was not a clear request", "a whisper that was no clear request")
	a.W.drivers[eve.key] = { state = "open", dest = "Undercity" }
	eq(why(), "another driver", "a [Wuber] driver")
	a.W.drivers[eve.key] = nil
	DR.db.blocklist[eve.key] = { name = eve.name, reason = "test" }
	eq(why(), "blocked", "a blocked player")
	DR.db.blocklist[eve.key] = nil
	local realCrew = DR.IsCrewKey
	DR.IsCrewKey = function(k) return k == eve.key or realCrew(k) end
	eq(why(), "a crew member", "a crew member")
	DR.IsCrewKey = realCrew
	DR.opts().autoInvite = false
	eq(why(), "you invite riders yourself", "the driver invites by hand: the rider waits for a click, not for room")
	DR.opts().autoInvite = true
	local realPaused = DR.IsPaused
	DR.IsPaused = function() return true end
	eq(why(), "paused", "paused: nobody is invited")
	DR.IsPaused = realPaused
	eq(why({ name = "Eve Hall", key = eve.key, state = "queued", source = "whisper", auto = "whisper" }), "not on your list", "a copy of the row")
	eq(why(), nil, "(a control: Eve could still be told)")
	eq(#autos(w), 0, "and through all of it nothing was sent")
	-- the fake game's own rule: to a rider in the line only the You're next words, and only to one who whispered
	ok(tostring(H.linesRule(w, a, "WHISPER", "Eve-Hall", SITE, "hello")):find("only the You're next line", 1, true), "other words to a rider in the line")
	eq(H.linesRule(w, a, "WHISPER", "Eve-Hall", SITE, DR.Text("next", eve)), nil, "the You're next words to her are allowed")
	local okCall = fromSite(a, DR.Text("greet", eve), "WHISPER", "Eve-Hall")
	ok(not okCall, "the greeting to a rider in the line raises")
	eq(#w.violations, 1, "and is a violation")
	w.violations = {}
	w:addBot("Sam Stranger", { spot = "Orgrimmar" })
	local fake = { name = "Sam Stranger", key = H.key("Sam Stranger"), state = "queued", source = "whisper", auto = "whisper", order = 0, at = a.W.Now() - 60 }
	DR.customers[fake.key] = fake
	eq((DR.CanLine("next", fake)), true, "(a made-up row: the module believes its list)")
	eq((DR.TryLine("next", fake)), false, "the made-up rider gets nothing")
	eq(#w.violations, 1, "the fake game recorded a violation")
	ok(tostring(w.violations[1]):find("never whispered the sender", 1, true), tostring(w.violations[1]))
	DR.customers[fake.key] = nil
	eq(#autos(w), 0, "nothing was whispered")
	w.violations = {}
	a.W.lastError = nil
	T.clean(w, { violations = true })
end)

test("dec r: You're next: combat at its moment drops it for that ride", function()
	local w, a, DR = lineScene({ "next" })
	local eve = queues(w, a, DR, "Eve Hall")
	w:advance(3)
	w:enterCombat(a)
	w:advance(12)
	eq(#autos(w), 0, "nothing by itself in combat")
	local can, why = DR.CanLine("next", eve)
	eq(why, "in combat", "why")
	w:leaveCombat(a)
	w:advance(60)
	eq(eve.state, "queued", "(Eve still waits in the line)")
	eq(#autos(w), 0, "and nothing after the fight: refused once, the line is dropped for that ride")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- 5. the switches in Messages
---------------------------------------------------------------------------

test("dec r: Messages: Greeting, Welcome, please pay and You're next each have their own switch, off by default, with a tooltip; no other message has one", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local W = d.W
	local UI, DR = W.UI, W.Drive
	W.db.coach = true
	W.Char().wizard = true
	UI.Toggle(true)
	w:advance(3)
	UI.SelectTab("Drive")
	w:advance(1)
	DR.SetMode("sell")
	w:advance(1)
	for _, wide in ipairs({ false, true }) do
		local how = wide and "unfolded" or "folded"
		d.wide = wide
		W.db.fold = (not wide) and { v = 1, pages = {}, narrow = true } or nil
		UI.Fold.Apply()
		w:advance(1)
		W.Driver.ShowScreen("messages")
		w:advance(1)
		local s = (W.Driver.ui.subs and W.Driver.ui.subs.messages) or UI.drive.screens.messages
		ok(s and s.edit, "the Messages screen")
		DR.SetLineOn("greet", false)
		DR.SetLineOn("pay", false)
		DR.SetLineOn("next", false)
		local labels = { greet = "Send the greeting by itself", pay = "Send the pay reminder by itself", next = "Send You're next by itself" }
		-- when the line goes (the line under the switch), and what happens when it cannot (the tooltip)
		local whenText = { greet = "when you start their summon", pay = "25 seconds after they land", next = "first in your line and has waited 10 seconds" }
		local cannot = { greet = "Skipped when it cannot go, like in combat", pay = "waits for your click", next = "Skipped when it cannot go, such as in combat" }
		local others = { greet = "pay", pay = "next", next = "greet" }
		for _, kind in ipairs({ "greet", "pay", "next" }) do
			s.edit(kind)
			w:advance(1)
			local au = s.editor.auto
			ok(au and au:IsShown(), how .. " " .. kind .. ": the switch's card is shown")
			eq(au.label:GetText(), labels[kind], how .. " " .. kind .. ": its label")
			ok(not H.truncation(au.label), how .. " " .. kind .. ": the label is whole")
			ok((au.note:GetText() or ""):find("without your click", 1, true), how .. " " .. kind .. ": the line under it")
			ok((au.note:GetText() or ""):find(whenText[kind], 1, true), how .. " " .. kind .. ": it says when the line goes: " .. tostring(au.note:GetText()))
			ok(not H.truncation(au.note), how .. " " .. kind .. ": the line under it is whole")
			eq(au.toggle.on, false, how .. " " .. kind .. ": off by default")
			local tip = au.toggle.wuberTip
			ok(tip and tip.title and tip.text, how .. " " .. kind .. ": the switch has a tooltip")
			eq(type(tip.title) == "function" and tip.title() or tip.title, labels[kind], "the tooltip's title")
			local tipText = type(tip.text) == "function" and tip.text() or tip.text
			ok(tostring(tipText):find(cannot[kind], 1, true), how .. " " .. kind .. ": the tooltip says what happens when it cannot go: " .. tostring(tipText))
			ok(au.wuberTip ~= nil, "the card has the tooltip too")
			-- a click turns this line on, and only this line
			ok(d:scrollIntoView(au.toggle), how .. " " .. kind .. ": the switch scrolls into view")
			d:click(au.toggle)
			w:advance(0.5)
			eq(DR.LineOn(kind), true, how .. " " .. kind .. ": the click switches it on")
			local other = others[kind]
			eq(DR.LineOn(other), false, how .. " " .. kind .. ": the other line's switch is its own")
			s.edit(other)
			w:advance(0.5)
			eq(s.editor.auto.toggle.on, false, how .. ": the other editor's switch shows off")
			s.edit(kind)
			w:advance(0.5)
			eq(s.editor.auto.toggle.on, true, how .. " " .. kind .. ": back here it shows on")
			ok(d:scrollIntoView(s.editor.auto.toggle), how .. " " .. kind .. ": the switch scrolls into view again")
			d:click(s.editor.auto.toggle)
			w:advance(0.5)
			eq(DR.LineOn(kind), false, how .. " " .. kind .. ": a second click switches it off")
		end
		-- the editor of You're next is an editor like the others: its default words in the field
		s.edit("next")
		w:advance(0.5)
		eq(s.kind, "next", how .. ": the editor of You're next opens")
		for _, kind in ipairs({ "price", "offer", "thanks", "tip", "short", "busy", "refuse", "oops", "advert", "where", "getapp", "callsum", "raidsum", "raidclick" }) do
			s.edit(kind)
			w:advance(0.2)
			ok(not s.editor.auto:IsShown(), how .. " " .. kind .. ": no switch")
		end
		if not wide then s.list() end
	end
	eq(#autos(w), 0, "nothing was sent")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- 4. the chat gauntlet, replayed (tests/v24/chat_gauntlet_test.lua's worlds and lines; that file is not changed)
---------------------------------------------------------------------------
-- Every fixture line is said to a driver whose switches are on: whispered to a driver in auto mode, said in Trade
-- to a driver who invites public chat buyers, and said in Trade to a driver in each of the seven cities who only
-- whispers back. Here the players ACCEPT their invite, so a ride really starts: the greeting's moment comes for
-- everyone who joined, and every eighth rider is summoned and left unpaid until the pay reminder is due.
-- "That driver's rider" is worked out by the test from the fake game's own facts, not from the addon: a player who
-- WHISPERED the driver and whom the driver then invited. Anyone else (a public chat speaker, invited or not, a
-- helper, a whisperer who was not invited) is a stranger, and a self-sent line to a stranger is a failure.

local cachedFixture
local function loadFixture()
	if not cachedFixture then cachedFixture = assert(loadfile(T.dir .. "/fixtures/gauntlet/chat-lines.lua"))() end
	return cachedFixture
end

local function makeNameGen()
	local idx = 0
	return function()
		local n = idx
		idx = idx + 1
		local c4 = n % 26
		n = math.floor(n / 26)
		local c3 = n % 26
		n = math.floor(n / 26)
		local c2 = n % 26
		n = math.floor(n / 26)
		local c1 = n % 26
		local first = c1 == 0 and "Bot" or ("Bot" .. string.char(97 + c1))
		return first .. " " .. string.char(65 + c2, 97 + c3, 97 + c4)
	end
end

local GAUNTLET_SPOTS = { "Orgrimmar", "Undercity", "Thunder Bluff", "Stormwind", "Ironforge", "Booty Bay", "Gadgetzan" }

-- how: "whisper" (auto mode), "public" (invites public chat buyers), "reply" (only whispers back)
local function gauntletDriver(spot, how, on)
	local w = H.NewWorld({})
	local a = w:addClient(T.ANITA, { spot = spot, class = "WARLOCK", shards = 10 })
	w:advance(15)
	local faction = (a.player and a.player.faction) or (spot == "Stormwind" and "Alliance" or "Horde")
	w:addBot("Bob Helper", { spot = spot, faction = faction })
	w:addBot("Bo Second", { spot = spot, faction = faction })
	w:group({ T.ANITA, "Bob Helper", "Bo Second" })
	w:advance(1)
	local DR = a.W.Drive
	DR.opts().autoInvite = true
	DR.opts().autoTrade = false
	if how ~= "whisper" then DR.opts().watchPublic = true end
	if how == "public" then DR.opts().autoPublic = true end
	ok(DR.SetOpen(true), spot .. ": driver open")
	w:advance(3)
	if on then
		eq(#DR.LINE_KINDS, 3, "three lines: the greeting, the pay reminder, You're next")
		for _, kind in ipairs(DR.LINE_KINDS) do ok(DR.SetLineOn(kind, true), kind .. " switched on") end
	end
	return w, a, DR, faction
end

-- Replays every fixture line; returns { lines, invited, rode, auto, wrong = { ... }, greet, pay, queued, next }.
-- line: the driver is busy and serves one rider at a time, so whoever is accepted WAITS IN THE LINE. Then one
-- player at a time is left in the line for 11 seconds (the moment of You're next) while the next lines are said.
local function replay(spot, how, on, line)
	local data = loadFixture()
	local w, a, DR, faction = gauntletDriver(spot, how, on)
	local genName = makeNameGen()
	local me = a.player.name
	local riders = {} -- [name] = true: whispered the driver and was invited by the driver
	local st = { lines = 0, invited = 0, rode = 0, auto = 0, wrong = {}, pay = 0, greet = 0, queued = 0, next = 0 }
	local head, headAt -- (line) the player left waiting in the line, and since when
	-- the public channel the driver really hears (as the old gauntlet finds it): a plain request for this place is
	-- invited there (public), or whispered back to (reply)
	local channel
	if how ~= "whisper" then
		for _, ch in ipairs({ "Trade - City", "Trade" }) do
			local probe = genName()
			w:addBot(probe, { spot = "Ratchet", acceptsInvites = false, faction = faction })
			local before = #w.invites
			w:chatFrom(probe, "WTB summon to " .. spot, "CHANNEL", ch, faction)
			w:advance(1)
			local heard = #w.invites > before or #w:whispersTo(probe, "reply") > 0
			local c = DR.customers[H.key(probe)]
			if c then DR.Remove(c) end
			w:advance(0.1)
			if heard then
				channel = ch
				break
			end
		end
		ok(channel ~= nil, spot .. " (" .. how .. "): the driver hears a public channel")
	end
	if line then
		-- one rider at a time, and a rider in the group who is never summoned: everyone who is accepted from now on
		-- waits in the line (set up after the channel was found: a busy driver invites no probe)
		DR.opts().oneAtATime = true
		w:addBot("Rita Rider", { spot = "Ratchet", faction = faction })
		w:botWhisper("Rita Rider", a, "summon pls")
		w:advance(3)
		local r = DR.Find("Rita Rider")
		eq(r and r.state, "joined", spot .. ": the driver is busy with a rider")
	end
	for _, item in ipairs(data.lines) do
		local sender = genName()
		w:addBot(sender, { spot = "Ratchet", faction = faction })
		local before = #w.invites
		if how == "whisper" then
			w:botWhisper(sender, a, item.text)
		else
			w:chatFrom(sender, item.text, "CHANNEL", channel, faction)
		end
		w:advance(0.3)
		st.lines = st.lines + 1
		if line then
			-- the player the driver left in the line (they whispered, and the driver's list holds them as queued)
			local q = DR.customers[H.key(sender)]
			if q and q.state == "queued" then
				-- that driver's rider: whispered the driver and waits in the line (a public chat buyer in the line is
				-- left waiting too, and is nobody's rider who asked)
				if how == "whisper" and q.source == "whisper" then
					st.queued = st.queued + 1
					riders[w:player(sender).name] = true
				end
				if not head then
					head, headAt = sender, w.time
					st.heads = (st.heads or 0) + 1
				end
			end
			if head and w.time - headAt >= 11 then
				local hc = DR.customers[H.key(head)]
				if hc then DR.Remove(hc) end
				head, headAt = nil, nil
			end
		end
		local invited = false
		for i = before + 1, #w.invites do
			if w.invites[i].from == me and H.key(w.invites[i].to) == H.key(sender) then invited = true end
		end
		if invited then
			st.invited = st.invited + 1
			if how == "whisper" then riders[w:player(sender).name] = true end
			w:advance(3) -- they join: the greeting's moment
			local c = DR.customers[H.key(sender)]
			if c and c.state == "joined" and st.invited % 8 == 1 then
				-- a whole ride: the click casts, the helpers click, the rider lands and does not pay
				local b = a.env.WuberDriveButton
				if b and H.visible(b) then
					a:click(b)
					w:advance(1)
					local first = DR.LastLine()
					if first and first.kind == "greet" and H.key(first.to) == H.key(sender) then st.greet = st.greet + 1 end
					w:advance(2)
					w:clickPortal("Bob Helper")
					w:clickPortal("Bo Second")
					w:advance(12)
					if c.state == "arrived" then
						st.rode = st.rode + 1
						w:advance(30) -- the pay reminder's moment
						local last = DR.LastLine()
						if last and last.kind == "pay" and H.key(last.to) == H.key(sender) then st.pay = st.pay + 1 end
					end
				end
			end
		end
		-- tidy: off the list and out of the group, so the next player finds room (the one left in the line stays)
		local c = DR.customers[H.key(sender)]
		if c and sender ~= head then DR.Remove(c) end
		if w:player(sender).group then w:leave(sender) end
		w:advance(0.1)
	end
	for _, x in ipairs(w.whispers) do
		if x.how == "auto" then
			st.auto = st.auto + 1
			if x.text:find("You're next", 1, true) then st.next = st.next + 1 end
			if x.from ~= me or not riders[x.to] then st.wrong[#st.wrong + 1] = x.from .. " to " .. x.to .. ": " .. x.text end
		end
	end
	st.violations = #w.violations
	st.firstViolation = w.violations[1]
	st.errors = #w.errors
	st.firstError = w.errors[1]
	return st
end

local function sample(list)
	local out = {}
	for i = 1, math.min(#list, 5) do out[i] = list[i] end
	return table.concat(out, "\n")
end

test("dec r gauntlet: every line whispered to a driver with the switches on: no self-sent line to anyone but that driver's rider", function()
	local st = replay("Orgrimmar", "whisper", true)
	eq(#st.wrong, 0, #st.wrong .. " self-sent line(s) to a stranger:\n" .. sample(st.wrong))
	eq(st.violations, 0, "the fake game's rule held: " .. tostring(st.firstViolation))
	eq(st.errors, 0, "no Lua error: " .. tostring(st.firstError and (st.firstError.msg or st.firstError)))
	ok(st.invited >= 20, "the gauntlet has riders: " .. st.invited .. " of " .. st.lines .. " lines were invited")
	ok(st.rode >= 3 and st.greet >= st.rode, "and those whose summon was cast were greeted by themselves when it started: " .. st.greet .. " greetings for " .. st.rode .. " whole rides")
	ok(st.auto <= st.greet + st.pay, "nobody was greeted before a cast: " .. st.auto .. " self-sent lines, " .. st.greet .. " greetings and " .. st.pay .. " pay reminders")
	ok(st.pay >= st.rode - 1, "the pay reminder went by itself too: " .. st.pay .. " of " .. st.rode .. " whole rides")
	eq(st.next, 0, "nobody waited in a line here: no You're next")
end)

test("dec r gauntlet: every line whispered to a busy driver with the three switches on: You're next goes only to a rider waiting in that driver's line", function()
	local st = replay("Orgrimmar", "whisper", true, true)
	eq(#st.wrong, 0, #st.wrong .. " self-sent line(s) to someone who is not that driver's rider:\n" .. sample(st.wrong))
	eq(st.violations, 0, "the fake game's rule held: " .. tostring(st.firstViolation))
	eq(st.errors, 0, "no Lua error: " .. tostring(st.firstError and (st.firstError.msg or st.firstError)))
	ok(st.queued >= 20, "the gauntlet has riders in the line: " .. st.queued .. " of " .. st.lines .. " lines")
	ok(st.next >= 10, "and the first of the line was told: " .. st.next .. " You're next lines")
	eq(st.auto, st.next, "nothing else went by itself: nobody was summoned")
	local off = replay("Orgrimmar", "whisper", false, true)
	eq(off.auto, 0, "self-sent lines with the three switches off")
	eq(off.violations, 0, "no violation: " .. tostring(off.firstViolation))
	ok(off.queued >= 20, "the same line formed: " .. off.queued)
end)

test("dec r gauntlet: every line whispered to a driver with the switches off: no self-sent line at all", function()
	local st = replay("Orgrimmar", "whisper", false)
	eq(st.auto, 0, "self-sent lines with the switches off")
	eq(st.violations, 0, "no violation: " .. tostring(st.firstViolation))
	ok(st.invited >= 20 and st.rode >= 3, "the same rides happened: " .. st.invited .. " invited, " .. st.rode .. " whole rides")
end)

test("dec r gauntlet: every line said in Trade to a driver who invites public chat buyers: no self-sent line, switches on or off", function()
	local on = replay("Orgrimmar", "public", true)
	eq(on.auto, 0, "a public chat buyer is no rider who asked the driver: " .. sample(on.wrong))
	eq(on.violations, 0, "no violation: " .. tostring(on.firstViolation))
	ok(on.invited >= 5, "public chat buyers were invited and joined: " .. on.invited)
	local off = replay("Orgrimmar", "public", false)
	eq(off.auto, 0, "self-sent lines with the switches off")
	eq(off.violations, 0, "no violation: " .. tostring(off.firstViolation))
	-- and to a busy driver, where whoever is accepted waits in the line: a public chat buyer is never told You're next
	local busy = replay("Orgrimmar", "public", true, true)
	eq(busy.auto, 0, "a public chat buyer in the line is no rider who asked the driver: " .. sample(busy.wrong))
	eq(busy.violations, 0, "no violation: " .. tostring(busy.firstViolation))
	ok((busy.heads or 0) >= 3, "public chat buyers did wait in the line for 11 seconds each: " .. tostring(busy.heads))
end)

for _, spot in ipairs(GAUNTLET_SPOTS) do
	test("dec r gauntlet: every line said in Trade to a driver in " .. spot .. " who whispers back: no self-sent line, switches on or off", function()
		local on = replay(spot, "reply", true)
		eq(on.auto, 0, "self-sent lines with the switches on: " .. sample(on.wrong))
		eq(on.violations, 0, "no violation: " .. tostring(on.firstViolation))
		local off = replay(spot, "reply", false)
		eq(off.auto, 0, "self-sent lines with the switches off")
		eq(off.violations, 0, "no violation: " .. tostring(off.firstViolation))
	end)
end
