-- Wuber 2.4, p7 b: auto-reply whisper gate, limits and round trip. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function invitesTo(w, name)
	local n, k = 0, key(name)
	for _, inv in ipairs(w.invites) do
		if key(inv.to) == k then n = n + 1 end
	end
	return n
end

local function openOrgDriver()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = a.W.Drive
	DR.opts().autoInvite = true
	DR.opts().watchPublic = true
	ok(DR.SetOpen(true), "driver open in Orgrimmar")
	w:advance(3)
	return w, a, DR, (a.player and a.player.faction) or "Horde"
end

local function sayInTrade(w, faction, name, text, wait)
	if wait then w:advance(8) end -- r51 SEC-M2: whisper-backs leave 8 s apart, so an asker who expects an answer comes 8 s after the last
	if not w:player(name) then
		w:addBot(name, { spot = "Ratchet", acceptsInvites = false, faction = faction })
	end
	w:chatFrom(name, text, "CHANNEL", "Trade", faction)
	w:advance(0.5)
end

test("v24 autoreply: a clear public request gets one whisper and is not invited", function()
	local w, a, DR, faction = openOrgDriver()
	local beforeInv = #w.invites
	sayInTrade(w, faction, "Dan Miller", "WTB summon to Orgrimmar")
	local replies = w:whispersTo("Dan Miller", "reply")
	eq(#replies, 1, "one reply whisper sent")
	eq(replies[1] and replies[1].to, "Dan Miller", "whisper went to the asker")
	eq(
		replies[1] and replies[1].text,
		'Want a summon to Orgrimmar? Whisper me "summon Orgrimmar".',
		"exact reply text"
	)
	eq(#w.invites, beforeInv, "nobody was invited")
	local c = DR.customers[key("Dan Miller")]
	ok(c ~= nil and c.state == "lead", "asker stays a lead in DR.customers")
	local saved = a.env.WuberDB and a.env.WuberDB.drive and a.env.WuberDB.drive.replied
	ok(type(saved) == "table" and type(saved[key("Dan Miller")]) == "number" and saved[key("Dan Miller")] > 0, "reply stamp saved in WuberDB")
	local last = DR.LastReply()
	ok(last ~= nil and last.to == "Dan Miller" and last.place == "Orgrimmar", "LastReply records the whisper")
	T.clean(w)
end)

test("v24 autoreply: the whisper back is invited by careful mode", function()
	local w, a, DR, faction = openOrgDriver()
	sayInTrade(w, faction, "Eve Stone", "WTB summon to Orgrimmar")
	eq(#w:whispersTo("Eve Stone", "reply"), 1, "one reply whisper sent")
	eq(invitesTo(w, "Eve Stone"), 0, "public line did not invite")
	w:botWhisper("Eve Stone", a, "summon Orgrimmar")
	w:advance(3)
	eq(invitesTo(w, "Eve Stone"), 1, "whisper back was invited")
	local c = DR.customers[key("Eve Stone")]
	ok(c ~= nil and c.state == "invited", "row moved to invited")
	eq(c and c.auto, "whisper", "row marked auto whisper")
	eq(#w:whispersTo("Eve Stone", "reply"), 1, "no second reply whisper")
	T.clean(w)
end)

test("v24 autoreply: once per person per hour", function()
	local w, a, DR, faction = openOrgDriver()
	sayInTrade(w, faction, "Fay Wood", "WTB summon to Orgrimmar")
	eq(#w:whispersTo("Fay Wood", "reply"), 1, "first ask gets a reply")
	w:advance(600)
	sayInTrade(w, faction, "Fay Wood", "WTB summon to Orgrimmar")
	eq(#w:whispersTo("Fay Wood", "reply"), 1, "second ask after 10 minutes gets no reply")
	sayInTrade(w, faction, "Gil Moss", "WTB summon to Orgrimmar")
	eq(#w:whispersTo("Gil Moss", "reply"), 1, "different player in between gets a reply")
	w:advance(3100)
	sayInTrade(w, faction, "Fay Wood", "WTB summon to Orgrimmar")
	eq(#w:whispersTo("Fay Wood", "reply"), 2, "ask after more than an hour gets a second reply")
	T.clean(w)
end)

test("v24 autoreply: never in combat, in a raid, in an instance, during a ride, or to the group", function()
	local w, a, DR, faction = openOrgDriver()

	-- in combat
	w:enterCombat(a)
	sayInTrade(w, faction, "Hal Reed", "WTB summon to Orgrimmar")
	eq(#w:whispersTo("Hal Reed", "reply"), 0, "no reply in combat")
	eq(DR.customers[key("Hal Reed")] and DR.customers[key("Hal Reed")].state, "lead", "asker stays a lead in combat")
	w:leaveCombat(a)
	sayInTrade(w, faction, "Ida Frost", "WTB summon to Orgrimmar")
	eq(#w:whispersTo("Ida Frost", "reply"), 1, "new asker gets a reply after combat")

	-- in an instance
	a.player.instance = true
	sayInTrade(w, faction, "Jon Vale", "WTB summon to Orgrimmar")
	eq(#w:whispersTo("Jon Vale", "reply"), 0, "no reply in an instance")
	eq(DR.customers[key("Jon Vale")] and DR.customers[key("Jon Vale")].state, "lead", "asker stays a lead in an instance")
	a.player.instance = false
	sayInTrade(w, faction, "Kay Pine", "WTB summon to Orgrimmar", true) -- r51 SEC-M2: 8 s after the last whisper-back
	eq(#w:whispersTo("Kay Pine", "reply"), 1, "new asker gets a reply outside an instance")

	-- during a ride in progress
	w:addBot("Leo Marsh", { spot = "Ratchet", acceptsInvites = false, faction = faction })
	w:botWhisper("Leo Marsh", a, "summ to org pls")
	w:advance(3)
	ok(DR.Busy(), "driver has a ride in progress")
	sayInTrade(w, faction, "Mia Shaw", "WTB summon to Orgrimmar")
	eq(#w:whispersTo("Mia Shaw", "reply"), 0, "no reply during a ride")
	eq(DR.customers[key("Mia Shaw")] and DR.customers[key("Mia Shaw")].state, "lead", "asker stays a lead during a ride")
	DR.Remove(DR.customers[key("Leo Marsh")])
	sayInTrade(w, faction, "Ned Cole", "WTB summon to Orgrimmar", true) -- r51 SEC-M2: 8 s after the last whisper-back
	eq(#w:whispersTo("Ned Cole", "reply"), 1, "new asker gets a reply once ride ends")

	w:advance(8) -- r51 SEC-M2: Pat Gray's reply below comes 8 s after Ned Cole's whisper-back
	-- to someone in the group
	w:addBot("Ora Dunn", { spot = "Ratchet", acceptsInvites = false, faction = faction })
	w:group({ T.ANITA, "Ora Dunn" })
	w:advance(1)
	if DR.customers[key("Ora Dunn")] then DR.Remove(DR.customers[key("Ora Dunn")]) end
	sayInTrade(w, faction, "Ora Dunn", "WTB summon to Orgrimmar")
	eq(#w:whispersTo("Ora Dunn", "reply"), 0, "no reply to a group member")
	eq(DR.customers[key("Ora Dunn")] and DR.customers[key("Ora Dunn")].state, "lead", "group member stays a lead")
	sayInTrade(w, faction, "Pat Gray", "WTB summon to Orgrimmar")
	eq(#w:whispersTo("Pat Gray", "reply"), 1, "new asker outside group gets a reply")

	-- in a raid
	a.player.group.raid = true
	eq(select(2, DR.CanReply("Quin Bell")), "in a raid", "the reason is the raid")
	sayInTrade(w, faction, "Quin Bell", "WTB summon to Orgrimmar")
	eq(#w:whispersTo("Quin Bell", "reply"), 0, "no reply in a raid")
	eq(DR.customers[key("Quin Bell")] and DR.customers[key("Quin Bell")].state, "lead", "asker stays a lead in a raid")
	-- (the lead) the raid made the grouped player a rider of a raid summon, so a ride is in progress afterwards: the
	-- check here is only that the raid itself no longer is the reason
	a.player.group.raid = false
	ok(select(2, DR.CanReply("Ray Holt")) ~= "in a raid", "the raid is no longer the reason once it is over")

	T.clean(w)
end)

test("v24 autoreply: the switch, auto mode and the public chat switch", function()
	local w, a, DR, faction = openOrgDriver()

	DR.opts().autoReply = false
	sayInTrade(w, faction, "Sam Ward", "WTB summon to Orgrimmar")
	eq(#w:whispersTo("Sam Ward", "reply"), 0, "no reply when autoReply is off")

	DR.opts().autoReply = true
	DR.opts().autoInvite = false
	sayInTrade(w, faction, "Tim Park", "WTB summon to Orgrimmar")
	eq(#w:whispersTo("Tim Park", "reply"), 0, "no reply when autoInvite is off")

	DR.opts().autoInvite = true
	DR.opts().watchPublic = false
	sayInTrade(w, faction, "Una Lane", "WTB summon to Orgrimmar")
	eq(#w:whispersTo("Una Lane", "reply"), 0, "no reply when watchPublic is off")

	DR.opts().watchPublic = true
	DR.SetOpen(false)
	w:advance(1)
	sayInTrade(w, faction, "Vic Hale", "WTB summon to Orgrimmar")
	eq(#w:whispersTo("Vic Hale", "reply"), 0, "no reply when driver is closed")

	ok(DR.SetOpen(true), "driver opened again")
	w:advance(1)
	sayInTrade(w, faction, "Wes Boyd", "WTB summon to Orgrimmar")
	eq(#w:whispersTo("Wes Boyd", "reply"), 1, "reply resumes when everything is back on")

	T.clean(w)
end)

test("v24 autoreply: never to a seller, a price question, another place, no place, or a nonsense line", function()
	local w, a, DR, faction = openOrgDriver()
	local lines = {
		{ "Amy West", "WTS summons to Orgrimmar 1g, whisper me inv" },
		{ "Ben West", "how much for a summon to Orgrimmar?" },
		{ "Cal West", "WTB summon to Undercity" },
		{ "Dot West", "WTB summon pls" },
		{ "Eli West", "LF sleeping bag summons" },
		{ "Fay West", "[Wuber] summons to Orgrimmar 50s" },
		{ "Gus West", "Port Orgrimmar" },
		{ "Hal West", "WTB summon to org and uc pls" },
	}
	for _, row in ipairs(lines) do
		sayInTrade(w, faction, row[1], row[2])
		eq(#w:whispersTo(row[1], "reply"), 0, "no reply for: " .. row[2])
	end
	w:chatFrom(T.ANITA, "WTB summon to Orgrimmar", "CHANNEL", "Trade", faction)
	w:advance(0.5)
	eq(#w:whispersTo(T.ANITA, "reply"), 0, "no reply to driver's own line in Trade")
	T.clean(w)
end)

test("v24 autoreply: Invite public chat buyers on: invited as today, no whisper", function()
	local w, a, DR, faction = openOrgDriver()
	DR.opts().autoPublic = true
	sayInTrade(w, faction, "Zoe Hart", "WTB summon to Orgrimmar")
	w:advance(2)
	eq(invitesTo(w, "Zoe Hart"), 1, "market line invited when autoPublic is on")
	eq(#w:whispersTo("Zoe Hart", "reply"), 0, "no reply whisper when invited directly")
	local c = DR.customers[key("Zoe Hart")]
	eq(c and c.auto, "public", "row marked auto public")
	T.clean(w)
end)

test("v24 autoreply: a game that refuses addon chat is asked once at most", function()
	local w, a, DR, faction = openOrgDriver()
	local build = a.W.Build()
	a.W.db.blockedBuild = a.W.db.blockedBuild or {}
	a.W.db.blockedBuild[build] = a.W.db.blockedBuild[build] or {}
	a.W.db.blockedBuild[build].chat = true
	sayInTrade(w, faction, "Rex Ford", "WTB summon to Orgrimmar")
	eq(#w:whispersTo("Rex Ford", "reply"), 0, "no whisper when chat is blocked on this build")
	eq(#w.blocked, 0, "no blocked call attempted")
	eq(#w.violations, 0, "no violation recorded")
	local can, why = DR.CanReply("Rex Ford")
	eq(can, false, "CanReply is false when chat is blocked")
	eq(why, "the game refuses addon chat", "CanReply gives blocked reason")
	T.clean(w)
end)

-- (the lead) the hour is remembered in the saved table, so a /reload or a restart does not forget it
test("v24 autoreply: a saved stamp still counts after a reload, a stale or absurd one does not", function()
	local w, a, DR, faction = openOrgDriver()
	local now = a.env.time()
	DR.db.replied = {
		[key("Amy Reed")] = now - 600,      -- whispered ten minutes before the reload
		[key("Bob Reed")] = now - 4000,     -- more than an hour ago
		[key("Cat Reed")] = now + 500000,   -- a clock that was wrong: absurd, dropped
	}
	sayInTrade(w, faction, "Amy Reed", "WTB summon to Orgrimmar")
	eq(#w:whispersTo("Amy Reed", "reply"), 0, "ten minutes after the saved whisper: none")
	sayInTrade(w, faction, "Bob Reed", "WTB summon to Orgrimmar")
	eq(#w:whispersTo("Bob Reed", "reply"), 1, "more than an hour after: one")
	sayInTrade(w, faction, "Cat Reed", "WTB summon to Orgrimmar", true) -- r51 SEC-M2: 8 s after the last whisper-back
	eq(#w:whispersTo("Cat Reed", "reply"), 1, "an absurd stamp does not silence Wuber for ever")
	local saved = a.env.WuberDB.drive.replied
	ok(saved[key("Amy Reed")] == now - 600, "the older stamp is kept as it was")
	ok(saved[key("Bob Reed")] >= now, "the new whisper is stamped")
	T.clean(w)
end)
