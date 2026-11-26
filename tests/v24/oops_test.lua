-- Wuber 2.4, p3: oops undo engine, big button step, message template and learning. Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local DAN, EVE, FAY, GIL = "Dan Miller", "Eve Stone", "Fay Wood", "Gil Moss"
local DEFAULT_OOPS = "Sorry Dan, that invite was my mistake. Have a good one!"

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function invitesTo(w, name)
	local n, k = 0, key(name)
	for _, inv in ipairs(w.invites) do
		if key(inv.to) == k then n = n + 1 end
	end
	return n
end

local function countMap(tbl)
	local n = 0
	for _ in pairs(tbl or {}) do n = n + 1 end
	return n
end

local function press(c)
	local b = c.env.WuberDriveButton
	ok(b and H.visible(b), c.player.name .. ": the big button")
	return c:click(b)
end

local function openDriver(opts)
	opts = opts or {}
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar", shards = 10 })
	T.settle(w)
	local DR = a.W.Drive
	DR.opts().autoInvite = opts.noInvite ~= true
	if opts.kickAfter ~= nil then DR.opts().kickAfter = opts.kickAfter end
	ok(DR.SetOpen(true), "driver open in Orgrimmar")
	w:advance(3)
	return w, a, DR
end

test("v24 oops: CanOops is true for auto-invited rows and false for manual adds, clicked leads, leads, paid, done", function()
	local w, a, DR = openDriver()
	w:addBot(DAN, { spot = "Ratchet", acceptsInvites = false })
	w:addBot(EVE, { spot = "Ratchet", acceptsInvites = false })
	w:addBot(FAY, { spot = "Ratchet", acceptsInvites = false })
	w:addBot(GIL, { spot = "Ratchet", acceptsInvites = false })
	w:advance(1)

	-- clear whisper: invited automatically -> CanOops is true
	w:botWhisper(DAN, a, "summ to org pls")
	w:advance(3)
	local dan = DR.customers[key(DAN)]
	eq(dan and dan.state, "invited", "Dan auto-invited")
	eq(DR.CanOops(dan), true, "CanOops true for auto-invited row")

	-- manual add by the driver -> CanOops is false
	local fay = DR.Request(FAY, "manual")
	w:advance(3)
	ok(fay ~= nil, "Fay added by hand")
	eq(DR.CanOops(fay), false, "CanOops false for driver-added row")
	eq(DR.Oops(fay), false, "Oops returns false for driver-added row")

	-- unclear whisper -> lead (CanOops false); clicking the lead invites it (still CanOops false)
	w:botWhisper(EVE, a, "LF sleeping bag summons")
	w:advance(3)
	local eveLead = DR.customers[key(EVE)]
	eq(eveLead and eveLead.state, "lead", "Eve is a lead")
	eq(DR.CanOops(eveLead), false, "CanOops false for a lead")
	local eve = DR.Invite(eveLead)
	w:advance(3)
	ok(eve and eve.state ~= "lead", "clicked lead becomes a rider")
	eq(DR.CanOops(eve), false, "CanOops false for a lead clicked by the driver")
	eq(DR.Oops(eve), false, "Oops returns false for clicked lead")

	-- Wuber app request line -> not marked auto -> CanOops is false
	w:botWhisper(GIL, a, "WTB summon to Orgrimmar for 50s")
	w:advance(3)
	local gil = DR.customers[key(GIL)]
	eq(DR.CanOops(gil), false, "CanOops false for Wuber app request line")

	-- paid and done auto rows -> CanOops is false
	local paidRow = { key = "x y", name = "X Y", state = "paid", auto = "whisper", autoMsg = "summon pls" }
	local doneRow = { key = "z w", name = "Z W", state = "done", auto = "whisper", autoMsg = "summon pls" }
	eq(DR.CanOops(paidRow), false, "CanOops false for paid row")
	eq(DR.CanOops(doneRow), false, "CanOops false for done row")
	eq(DR.CanOops(nil), false, "CanOops false for nil")
	T.clean(w)
end)

test("v24 oops: Oops on a joined or invited player waits for the big button, whispers once to full name, removes from group", function()
	local w, a, DR = openDriver({ kickAfter = false })
	w:addBot(DAN, { spot = "Ratchet", acceptsInvites = true })
	w:addBot(EVE, { spot = "Ratchet", acceptsInvites = false })
	w:advance(1)

	-- spy on DR.CountWrong (preserve existing if present)
	local wrongCalls = 0
	local origWrong = DR.CountWrong
	DR.CountWrong = function(c)
		wrongCalls = wrongCalls + 1
		if origWrong then origWrong(c) end
	end

	-- 1. Dan accepts the auto-invite and joins the group
	w:botWhisper(DAN, a, "summ to org pls")
	w:advance(4)
	local dan = DR.customers[key(DAN)]
	eq(dan and dan.state, "joined", "Dan joined the group")
	ok(w:player(DAN).group ~= nil and w:player(DAN).group == a.player.group, "Dan is in the driver's group")

	local msgsBefore = #w:messages()
	eq(DR.Oops(dan), true, "Oops succeeds for Dan")
	eq(wrongCalls, 1, "CountWrong called once")
	eq(DR.CanOops(dan), false, "CanOops becomes false after Oops")
	eq(DR.Oops(dan), false, "second Oops returns false")
	eq(#w:messages(), msgsBefore, "Oops sends no addon messages")

	-- nothing is whispered and nobody is removed before the big button click
	w:advance(2)
	eq(#w:whispersTo(DAN), 0, "no whisper before click")
	ok(w:player(DAN).group == a.player.group, "Dan still in group before click")
	ok(DR.customers[key(DAN)] == dan, "Dan row still stays until click")

	-- big button shows Oops step (even with kickAfter = false, and before casting a summon)
	local plan = DR.Plan()
	eq(plan.title, "Oops: remove Dan", "button title is Oops: remove Dan")
	eq(plan.say, "says sorry to Dan and takes them out of the group", "button says line")
	ok((plan.macrotext or ""):find("/uninvite Dan Miller", 1, true) ~= nil, "macro uninvites Dan's full name")
	ok((plan.macrotext or ""):find("/cast", 1, true) == nil, "no summon cast on the oops click")
	ok(#a:findText("Oops: remove Dan", false, true) > 0, "player sees Oops: remove Dan on the button")

	-- one click whispers the sorry line to full two-part name, takes Dan out of the group, removes the row
	press(a)
	w:advance(2)
	local sent = w:whispersTo(DAN)
	eq(#sent, 1, "exactly one whisper sent to Dan")
	eq(sent[1] and sent[1].how, "macro", "whisper sent by the secure macro")
	eq(sent[1] and sent[1].text, DEFAULT_OOPS, "default oops message whispered")
	ok(sent[1] and sent[1].to and sent[1].to:find("Dan", 1, true) and sent[1].to:find("Miller", 1, true),
		"whisper addressed to full two-part name: " .. tostring(sent[1] and sent[1].to))
	eq(w:player(DAN).group, nil, "Dan is taken out of the group")
	eq(DR.customers[key(DAN)], nil, "Dan's row is gone")

	-- a second click whispers nothing more to Dan
	press(a)
	w:advance(2)
	eq(#w:whispersTo(DAN), 1, "second click sends no extra whisper to Dan")

	-- 2. Eve is invited (has not joined yet): same flow, cancels invite and removes row
	w:botWhisper(EVE, a, "need a summon")
	w:advance(3)
	local eve = DR.customers[key(EVE)]
	eq(eve and eve.state, "invited", "Eve is invited")
	eq(DR.Oops(eve), true, "Oops succeeds for invited Eve")
	eq(#w:whispersTo(EVE), 0, "nothing whispered to Eve before click")
	w:advance(1) -- (lead) the big button redraws on its next tick
	ok(#a:findText("Oops: remove Eve", false, true) > 0, "button shows Oops: remove Eve")
	press(a)
	w:advance(2)
	local eveSent = w:whispersTo(EVE)
	eq(#eveSent, 1, "one oops whisper sent to Eve")
	eq(eveSent[1] and eveSent[1].text, "Sorry Eve, that invite was my mistake. Have a good one!", "Eve oops wording")
	ok(eveSent[1] and eveSent[1].to and eveSent[1].to:find("Eve", 1, true) and eveSent[1].to:find("Stone", 1, true),
		"Eve whisper addressed to full two-part name: " .. tostring(eveSent[1] and eveSent[1].to))
	eq(DR.customers[key(EVE)], nil, "Eve's row is gone after click")
	press(a)
	w:advance(2)
	eq(#w:whispersTo(EVE), 1, "second click sends nothing more to Eve")

	DR.CountWrong = origWrong
	T.clean(w)
end)

test("v24 oops: Oops on a queued-only player removes at once and owes no whisper", function()
	local w, a, DR = openDriver({ noInvite = true })
	w:addBot(DAN, { spot = "Ratchet", acceptsInvites = false })
	w:advance(1)

	w:botWhisper(DAN, a, "summ to org pls")
	w:advance(2)
	local dan = DR.customers[key(DAN)]
	eq(dan and dan.state, "queued", "Dan is only queued")
	eq(invitesTo(w, DAN), 0, "no invite went out")
	eq(DR.CanOops(dan), true, "CanOops is true for auto-queued row")

	eq(DR.Oops(dan), true, "Oops succeeds")
	eq(DR.customers[key(DAN)], nil, "queued row removed at once")
	eq(#DR.Pending(), 0, "no pending whisper owed")
	eq(DR.Plan().macrotext, nil, "big button owes no macro")
	eq(#w:whispersTo(DAN), 0, "nothing whispered")
	ok(DR.db.oops and DR.db.oops.players[key(DAN)] ~= nil, "player was learned")
	ok(DR.db.oops and DR.db.oops.lines[DR.Norm("summ to org pls")] ~= nil, "words were learned")
	T.clean(w)
end)

test("v24 oops: learning turns the same player and the same words into leads, leaves others invited, and clicking a lead still invites", function()
	local w, a, DR = openDriver()
	w:addBot(DAN, { spot = "Ratchet", acceptsInvites = false })
	w:addBot(EVE, { spot = "Ratchet", acceptsInvites = false })
	w:addBot(FAY, { spot = "Ratchet", acceptsInvites = false })
	w:addBot(GIL, { spot = "Ratchet", acceptsInvites = false })
	w:advance(1)

	-- Dan auto-invited, then oops'd and removed via big button
	w:botWhisper(DAN, a, "summ to org pls")
	w:advance(3)
	eq(invitesTo(w, DAN), 1, "Dan invited initially")
	ok(DR.Oops(DR.customers[key(DAN)]), "Oops Dan")
	press(a)
	w:advance(2)
	eq(DR.customers[key(DAN)], nil, "Dan removed")
	eq(DR.db.blocklist[key(DAN)], nil, "Dan is not blocked")

	-- DR.Careful checks both player and words, with exact reasons, and nil sender
	local v1, r1 = DR.Careful("need a summon", "whisper", DAN)
	eq(v1, "lead", "learned player with different words -> lead")
	eq(r1, "you marked this player's invite as wrong", "learned player reason")

	local v2, r2 = DR.Careful("summ to org pls", "whisper", EVE)
	eq(v2, "lead", "another player with learned words -> lead")
	eq(r2, "you marked these words as a wrong invite", "learned words reason")

	local v3, r3 = DR.Careful("summ to org pls", "whisper", nil)
	eq(v3, "lead", "nil sender with learned words -> lead")
	eq(r3, "you marked these words as a wrong invite", "nil sender words reason")

	local v4 = DR.Careful("need a summon", "whisper", FAY)
	eq(v4, "invite", "unlearned player and words -> invite")

	local vApp = DR.Careful("WTB summon to Orgrimmar for 50s", "whisper", DAN)
	eq(vApp, "invite", "Wuber app request line is never affected")

	-- end to end: Dan whispers again -> lead, not invited
	w:botWhisper(DAN, a, "summ to org pls")
	w:advance(3)
	local danLead = DR.customers[key(DAN)]
	eq(danLead and danLead.state, "lead", "same player whispering again becomes a lead")
	eq(invitesTo(w, DAN), 1, "same player is not auto-invited again")

	-- another player whispers the very same words -> lead, not invited
	w:botWhisper(EVE, a, "summ to org pls")
	w:advance(3)
	local eveLead = DR.customers[key(EVE)]
	eq(eveLead and eveLead.state, "lead", "another player with same words becomes a lead")
	eq(invitesTo(w, EVE), 0, "another player with same words is not invited")

	-- a third player whispers a different clear request -> still invited
	w:botWhisper(FAY, a, "need a summon")
	w:advance(3)
	eq(invitesTo(w, FAY), 1, "third player with different clear request is still invited")

	-- clicking a learned lead by hand still invites as any lead does
	local madeEve = DR.Invite(eveLead)
	w:advance(3)
	ok(madeEve and madeEve.state ~= "lead", "clicked learned lead (Eve) becomes a rider")
	eq(invitesTo(w, EVE), 1, "clicking Eve's learned lead invites her")

	local madeDan = DR.Invite(danLead)
	w:advance(3)
	ok(madeDan and madeDan.state ~= "lead", "clicked learned lead (Dan) becomes a rider")

	-- Wuber app whisper from a learned player still invites end to end
	eq(DR.Oops({ key = key(GIL), name = GIL, state = "queued", auto = "whisper", autoMsg = "inv pls" }), true, "learn Gil")
	w:botWhisper(GIL, a, "WTB summon to Orgrimmar for 50s")
	w:advance(3)
	eq(invitesTo(w, GIL), 1, "Wuber app whisper line still invites a learned player")
	T.clean(w)
end)

test("v24 oops: learned data persists across reload, caps at 200 entries, and OopsLog returns the newest ten", function()
	local w, a, DR = openDriver()
	for i = 1, 205 do
		local name = "Rider " .. i
		local c = {
			key = key(name),
			name = name,
			state = "queued",
			auto = "whisper",
			autoMsg = "summon pls " .. i,
		}
		eq(DR.Oops(c), true, "Oops #" .. i)
	end

	local o = DR.db.oops
	ok(type(o) == "table", "DR.db.oops created")
	eq(countMap(o.players), 200, "players capped at 200")
	eq(countMap(o.lines), 200, "lines capped at 200")
	eq(#o.log, 200, "log capped at 200")

	-- oldest five evicted, newest kept
	eq(o.players[key("Rider 1")], nil, "oldest player evicted")
	eq(o.players[key("Rider 5")], nil, "5th oldest player evicted")
	ok(o.players[key("Rider 6")] ~= nil, "6th player kept")
	ok(o.players[key("Rider 205")] ~= nil, "newest player kept")
	eq(o.lines[DR.Norm("summon pls 1")], nil, "oldest line evicted")
	ok(o.lines[DR.Norm("summon pls 205")] ~= nil, "newest line kept")

	-- OopsLog(10) and default OopsLog() return newest ten, newest first
	local log10 = DR.OopsLog(10)
	eq(#log10, 10, "OopsLog(10) returns 10 strings")
	eq(log10[1], "summon pls 205", "newest first")
	eq(log10[10], "summon pls 196", "10th newest last")
	local logDef = DR.OopsLog()
	eq(#logDef, 10, "OopsLog() defaults to 10")
	eq(logDef[1], "summon pls 205", "default newest first")

	-- reload the client: learned data persists in DR.db.oops
	a = w:reload(a)
	w:advance(5)
	local DR2 = a.W.Drive
	ok(type(DR2.db.oops) == "table", "DR.db.oops survives reload")
	eq(countMap(DR2.db.oops.players), 200, "200 players after reload")
	eq(countMap(DR2.db.oops.lines), 200, "200 lines after reload")
	eq(#DR2.db.oops.log, 200, "200 log entries after reload")
	local afterLog = DR2.OopsLog(10)
	eq(#afterLog, 10, "OopsLog(10) after reload")
	eq(afterLog[1], "summon pls 205", "newest line survives reload")
	eq(afterLog[10], "summon pls 196", "10th newest survives reload")
	local v, r = DR2.Careful("summon pls 205", "whisper", "Fresh Rider")
	eq(v, "lead", "learned line still turns invite into lead after reload")
	eq(r, "you marked these words as a wrong invite", "learned words reason after reload")
	local vp, rp = DR2.Careful("need a summon", "whisper", "Rider 205")
	eq(vp, "lead", "learned player still turns invite into lead after reload")
	eq(rp, "you marked this player's invite as wrong", "learned player reason after reload")
	T.clean(w)
end)

test("v24 oops: custom edited oops template is what gets whispered", function()
	local w, a, DR = openDriver()
	w:addBot(DAN, { spot = "Ratchet", acceptsInvites = true })
	w:advance(1)

	-- verify template default and order after "refuse"
	eq(DR.TEMPLATES.oops, "Sorry {name}, that invite was my mistake. Have a good one!", "default oops template")
	local refuseAt, oopsAt
	for i, k in ipairs(DR.TEMPLATE_ORDER) do
		if k == "refuse" then refuseAt = i end
		if k == "oops" then oopsAt = i end
	end
	ok(refuseAt ~= nil and oopsAt == refuseAt + 1, "oops is in TEMPLATE_ORDER right after refuse")

	-- driver edits the oops message
	local okSet, err = DR.SetTemplate("oops", "My bad {name}, wrong invite to {dest}!")
	eq(okSet, true, "SetTemplate oops succeeds: " .. tostring(err))

	w:botWhisper(DAN, a, "summ to org pls")
	w:advance(4)
	local dan = DR.customers[key(DAN)]
	ok(dan ~= nil, "Dan auto-invited")
	eq(DR.Oops(dan), true, "Oops Dan")
	press(a)
	w:advance(2)

	local sent = w:whispersTo(DAN)
	eq(#sent, 1, "one whisper sent")
	eq(sent[1] and sent[1].text, "My bad Dan, wrong invite to Orgrimmar!", "driver's edited oops message was whispered")
	T.clean(w)
end)
