-- Wuber 2.4, p1 b: chat gauntlet tests proving never-invite and unclear lines are never invited by themselves, and measuring whisper recall. Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- (the lead, after the cross-marking) A label was given for the line IN ITS OWN CHANNEL. A never-invite line must
-- never be invited anywhere. An unclear line is tried where its doubt holds: a whisper as a whisper, a public line
-- (say, yell, trade, general, lfg, world) in public chat. An unclear line from party, guild or raid chat is unclear
-- BECAUSE of that channel ("need a summon to sw" among guild mates), and Wuber does not read those channels for
-- buyers, so it is not replayed elsewhere. The author's own lines and the real lines are always tried both ways.
local GROUP_CHAT = { party = true, guild = true, raid = true }
local function applies(item, how)
	if item.label == "never-invite" then return true end
	if item.label ~= "unclear" then return false end
	if item.real or item.writer == "author" then return true end
	if GROUP_CHAT[item.channel] then return false end
	if how == "whisper" then return item.channel == "whisper" end
	return item.channel ~= "whisper"
end

local RECALL_FLOOR = 21.9 -- the first measurement on the cross-marked gauntlet (1,471 lines from four writers) was 26.9% (135 of 502), 21 Nov 2026; the rule: never more than 5 points below it. On the first 300 lines it was 35.6%. A much larger fixture is a new first measurement: the lead sets this again then.
local REPLY_RECALL_FLOOR = 2.0 -- the first measurement (21 Nov 2026, 1,471 lines): 7.0% (17 of the 244 honest public requests, said to a driver in Orgrimmar and one in Stormwind); the rule: never more than 5 points below it. Per city (the tests below): of 137 honest public requests that name one of seven cities, 28 got a reply from the driver there. Strict on purpose: the reply goes only where careful mode would invite.

local ALL_PLACES = {
	"Orgrimmar", "Stormwind", "Stormwind City", "Ironforge", "Darnassus", "Undercity", "Thunder Bluff",
	"Ratchet", "Booty Bay", "Gadgetzan", "Everlook", "Kargath", "Cenarion Hold", "Silithus",
	"Blackrock Mountain", "Dire Maul", "Stranglethorn Vale", "Eastern Plaguelands", "Western Plaguelands",
	"Light's Hope Chapel", "Felwood", "Winterspring", "Tanaris", "Feralas", "Desolace", "Azshara",
	"Blasted Lands", "Swamp of Sorrows", "Dustwallow Marsh", "Theramore", "The Barrens", "Barrens",
	"Hillsbrad Foothills", "Arathi Highlands", "Ashenvale", "Darkshore", "Westfall", "Duskwood",
	"Loch Modan", "Redridge Mountains", "Wetlands", "Badlands", "Searing Gorge", "Burning Steppes",
	"Un'Goro Crater", "Moonglade", "The Hinterlands", "Hinterlands", "Thousand Needles",
	"Stonetalon Mountains", "Silverpine Forest", "Tirisfal Glades", "Mulgore", "Durotar",
	"Elwynn Forest", "Dun Morogh", "Teldrassil", "Alterac Mountains", "Deadwind Pass",
	"Zul'Gurub", "Molten Core", "Onyxia's Lair", "Blackwing Lair", "Naxxramas", "Ahn'Qiraj",
	"Scarlet Monastery", "Stratholme", "Scholomance", "Maraudon", "Zul'Farrak", "Gnomeregan",
	"Deadmines", "Wailing Caverns", "Shadowfang Keep", "Uldaman", "Sunken Temple", "Blackrock Depths",
	"Crossroads", "Tarren Mill", "Southshore", "Astranaar", "Menethil Harbor", "Refuge Pointe",
	"Hammerfall", "Grom'gol", "Stonard", "Nethergarde Keep", "Auberdine", "Sentinel Hill",
	"Lakeshire", "Darkshire", "Thelsamar", "Goldshire", "Razor Hill", "Brill", "Bloodhoof Village",
	"Sun Rock Retreat", "Camp Taurajo", "Splintertree Post", "Zoram'gar Outpost", "Shadowprey Village",
	"Nijel's Point", "Feathermoon Stronghold", "Camp Mojache", "Marshal's Refuge", "Morgan's Vigil",
	"Thorium Point", "Chillwind Camp", "Aerie Peak", "Revantusk Village",
}

local cachedFixture
local function loadFixture()
	if not cachedFixture then
		cachedFixture = assert(loadfile(T.dir .. "/fixtures/gauntlet/chat-lines.lua"))()
	end
	return cachedFixture
end

local function key(name)
	return (tostring(name or ""):lower():gsub("[%s%-]+", " "))
end

local function cleanText(text)
	return (tostring(text or ""):gsub("[\r\n]+", " "))
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

local function checkAndRemove(w, DR, sender, beforeInv)
	local k = key(sender)
	local c = DR.customers[k]
	local invited = (c ~= nil and c.state ~= "lead")
	if not invited then
		for i = beforeInv + 1, #w.invites do
			if key(w.invites[i].to) == k then
				invited = true
				break
			end
		end
	end
	if c then DR.Remove(c) end
	return invited, c ~= nil
end

local reportPath = os.getenv("WUBER_GAUNTLET_REPORT")
local reportStarted = false
local reportStats = { wrongWhisper = 0, wrongPublic = 0 }

local function writeReport(lines)
	if not reportPath or reportPath == "" then return end
	local mode = reportStarted and "a" or "w"
	local f = assert(io.open(reportPath, mode))
	for _, line in ipairs(lines) do
		f:write(line, "\n")
	end
	f:close()
	reportStarted = true
end

local function formatWrong(kind, wrong)
	local out = { string.format("%d wrong %s invite(s):", #wrong, kind) }
	local limit = math.min(#wrong, 25)
	for i = 1, limit do
		local e = wrong[i]
		out[#out + 1] = string.format("#%d [%s, %s] %s", e.n, e.lbl, e.writer, e.text)
	end
	if #wrong > 25 then
		out[#out + 1] = string.format("... and %d more", #wrong - 25)
	end
	return table.concat(out, "\n")
end

local function openDriver(spot, wantPublic)
	local w = H.NewWorld({})
	local a = w:addClient(T.ANITA, { spot = spot, class = "WARLOCK", shards = 10 })
	w:advance(15)
	local DR = a.W.Drive
	DR.opts().autoInvite = true
	if wantPublic then
		DR.opts().watchPublic = true
		DR.opts().autoPublic = true
	end
	ok(DR.SetOpen(true), spot .. ": driver open")
	w:advance(3)
	local faction = (a.player and a.player.faction) or (spot == "Stormwind" and "Alliance" or "Horde")
	return w, a, DR, faction
end

local function makeWhisperSender(w, a, DR, faction, genName)
	local probe = genName()
	w:addBot(probe, { spot = "Ratchet", acceptsInvites = false, faction = faction })
	w:botWhisper(probe, a, "hello")
	local k = key(probe)
	local step = 0
	if not DR.customers[k] then
		for _ = 1, 10 do
			w:advance(0.1)
			step = step + 0.1
			if DR.customers[k] then break end
		end
	end
	ok(DR.customers[k] ~= nil, "whisper probe reached driver")
	if DR.customers[k] then DR.Remove(DR.customers[k]) end
	return function(text)
		local sender = genName()
		w:addBot(sender, { spot = "Ratchet", acceptsInvites = false, faction = faction })
		local beforeInv = #w.invites
		w:botWhisper(sender, a, text)
		if step > 0 then w:advance(step) end
		local invited = checkAndRemove(w, DR, sender, beforeInv)
		return invited
	end
end

local function makePublicSender(w, a, DR, spot, faction, genName)
	local probeText = "WTB summon to " .. spot
	for _, ch in ipairs({ "Trade - City", "Trade" }) do
		if (not DR.Market) or DR.Market(ch) then
			local probe = genName()
			w:addBot(probe, { spot = "Ratchet", acceptsInvites = false, faction = faction })
			local beforeInv = #w.invites
			w:chatFrom(probe, probeText, "CHANNEL", ch, faction)
			local step = 0
			local k = key(probe)
			if not DR.customers[k] then
				for _ = 1, 5 do
					w:advance(0.1)
					step = step + 0.1
					if DR.customers[k] then break end
				end
			end
			local invited = checkAndRemove(w, DR, probe, beforeInv)
			if invited then
				return function(text)
					local sender = genName()
					w:addBot(sender, { spot = "Ratchet", acceptsInvites = false, faction = faction })
					local bInv = #w.invites
					w:chatFrom(sender, text, "CHANNEL", ch, faction)
					if step > 0 then w:advance(step) end
					local inv = checkAndRemove(w, DR, sender, bInv)
					return inv
				end
			end
		end
	end
	-- fallback if the fake client did not auto-join Trade: fire CHAT_MSG_CHANNEL directly
	local probe = genName()
	w:addBot(probe, { spot = "Ratchet", acceptsInvites = false, faction = faction })
	local beforeInv = #w.invites
	a:fire("CHAT_MSG_CHANNEL", probeText, probe, "", "2. Trade - City", "", "", 2, 2, "Trade - City")
	local invited = checkAndRemove(w, DR, probe, beforeInv)
	if invited then
		return function(text)
			local sender = genName()
			w:addBot(sender, { spot = "Ratchet", acceptsInvites = false, faction = faction })
			local bInv = #w.invites
			a:fire("CHAT_MSG_CHANNEL", text, sender, "", "2. Trade - City", "", "", 2, 2, "Trade - City")
			local inv = checkAndRemove(w, DR, sender, bInv)
			return inv
		end
	end
	-- last resort: DR.PublicLine with inMarket = true (as in queue_test.lua)
	local probe2 = genName()
	w:addBot(probe2, { spot = "Ratchet", acceptsInvites = false, faction = faction })
	local beforeInv2 = #w.invites
	DR.PublicLine(probeText, probe2, true)
	ok(checkAndRemove(w, DR, probe2, beforeInv2), "public chat probe reached driver")
	return function(text)
		local sender = genName()
		w:addBot(sender, { spot = "Ratchet", acceptsInvites = false, faction = faction })
		local bInv = #w.invites
		DR.PublicLine(text, sender, true)
		local inv = checkAndRemove(w, DR, sender, bInv)
		return inv
	end
end

local function placesAcceptable(DR, sendWhisper, needPublic)
	if DR.AskedFor then
		for _, place in ipairs({ "Orgrimmar", "Stormwind", "Undercity", "Ironforge" }) do
			if DR.AskedFor("summon to " .. place .. " pls") ~= "match" then return false end
		end
	end
	if needPublic and DR.PublicWant then
		for _, place in ipairs({ "Orgrimmar", "Stormwind", "Undercity", "Ironforge" }) do
			if DR.PublicWant("wtb summon to " .. place) ~= "match" then return false end
		end
	end
	return sendWhisper("summon to Stormwind pls") == true
end

local function tryAllPlaces(DR, sendWhisper, needPublic)
	local origServed = DR.ServedPlaces
	local origMulti = DR.MultiStation
	DR.ServedPlaces = function() return ALL_PLACES end
	if placesAcceptable(DR, sendWhisper, needPublic) then return true end
	DR.MultiStation = function() return true end
	if placesAcceptable(DR, sendWhisper, needPublic) then return true end
	DR.ServedPlaces = origServed
	DR.MultiStation = origMulti
	return false
end

local function entryMeta(item, idx)
	return item.n or idx, item.label or "", item.writer or "unknown", cleanText(item.text)
end

test("v24 gauntlet: no never-invite or unclear line is invited by a whisper", function()
	local data = loadFixture()
	local w, a, DR, faction = openDriver("Orgrimmar", false)
	local genName = makeNameGen()
	local sendWhisper = makeWhisperSender(w, a, DR, faction, genName)
	local allServed = tryAllPlaces(DR, sendWhisper, false)
	local wrong = {}
	local function scan(send)
		for i, item in ipairs(data.lines) do
			if applies(item, "whisper") then
				if send(item.text) then
					local n, lbl, writer, text = entryMeta(item, i)
					wrong[#wrong + 1] = { n = n, lbl = lbl, writer = writer, text = text }
				end
			end
		end
	end
	scan(sendWhisper)
	T.clean(w)
	if not allServed then
		local w2, a2, DR2, faction2 = openDriver("Stormwind", false)
		local sendWhisper2 = makeWhisperSender(w2, a2, DR2, faction2, genName)
		scan(sendWhisper2)
		T.clean(w2)
	end
	reportStats.wrongWhisper = #wrong
	local reportLines = {}
	for _, e in ipairs(wrong) do
		reportLines[#reportLines + 1] = string.format("WRONG whisper #%d [%s, %s] %s", e.n, e.lbl, e.writer, e.text)
	end
	writeReport(reportLines)
	eq(#wrong, 0, #wrong == 0 and "no wrong whisper invites" or formatWrong("whisper", wrong))
end)

test("v24 gauntlet: no never-invite or unclear line is invited from public chat, even with Invite public chat riders on", function()
	local data = loadFixture()
	local w, a, DR, faction = openDriver("Orgrimmar", true)
	local genName = makeNameGen()
	local sendWhisper = makeWhisperSender(w, a, DR, faction, genName)
	local allServed = tryAllPlaces(DR, sendWhisper, true)
	local sendPublic = makePublicSender(w, a, DR, "Orgrimmar", faction, genName)
	local wrong = {}
	local function scan(send)
		for i, item in ipairs(data.lines) do
			if applies(item, "public") then
				if send(item.text) then
					local n, lbl, writer, text = entryMeta(item, i)
					wrong[#wrong + 1] = { n = n, lbl = lbl, writer = writer, text = text }
				end
			end
		end
	end
	scan(sendPublic)
	T.clean(w)
	if not allServed then
		local w2, a2, DR2, faction2 = openDriver("Stormwind", true)
		local sendPublic2 = makePublicSender(w2, a2, DR2, "Stormwind", faction2, genName)
		scan(sendPublic2)
		T.clean(w2)
	end
	reportStats.wrongPublic = #wrong
	local reportLines = {}
	for _, e in ipairs(wrong) do
		reportLines[#reportLines + 1] = string.format("WRONG public #%d [%s, %s] %s", e.n, e.lbl, e.writer, e.text)
	end
	writeReport(reportLines)
	eq(#wrong, 0, #wrong == 0 and "no wrong public invites" or formatWrong("public", wrong))
end)

test("v24 gauntlet: lines marked invite are invited when whispered (recall)", function()
	local data = loadFixture()
	local w, a, DR, faction = openDriver("Orgrimmar", false)
	local genName = makeNameGen()
	local sendWhisper = makeWhisperSender(w, a, DR, faction, genName)
	local allServed = tryAllPlaces(DR, sendWhisper, false)
	local inviteItems = {}
	local hit = {}
	for i, item in ipairs(data.lines) do
		if item.label == "invite" then
			local idx = #inviteItems + 1
			local n, _, _, text = entryMeta(item, i)
			local _, why = DR.Careful(item.text, "whisper") -- (lead) the report says why a request was not clear
			inviteItems[idx] = { n = n, text = text, raw = item.text, why = tostring(why) }
			if sendWhisper(item.text) then hit[idx] = true end
		end
	end
	T.clean(w)
	if not allServed then
		local w2, a2, DR2, faction2 = openDriver("Stormwind", false)
		local sendWhisper2 = makeWhisperSender(w2, a2, DR2, faction2, genName)
		for idx, e in ipairs(inviteItems) do
			if not hit[idx] and sendWhisper2(e.raw) then hit[idx] = true end
		end
		T.clean(w2)
	end
	local total = #inviteItems
	local invited = 0
	local reportLines = {}
	for idx, e in ipairs(inviteItems) do
		if hit[idx] then
			invited = invited + 1
		else
			reportLines[#reportLines + 1] = string.format("MISSED #%d [%s] %s", e.n, e.why or "?", e.text)
		end
	end
	local recall = total > 0 and (invited * 100 / total) or 0
	local recallRounded = math.floor(recall * 10 + 0.5) / 10
	reportLines[#reportLines + 1] = string.format(
		"recall %.1f%% (%d/%d); wrong whisper %d; wrong public %d; lines %d",
		recallRounded, invited, total, reportStats.wrongWhisper, reportStats.wrongPublic, #data.lines
	)
	writeReport(reportLines)
	ok(total > 0, "gauntlet fixture has invite lines")
	ok(
		recallRounded >= RECALL_FLOOR,
		string.format("whisper recall %.1f%% (%d/%d), floor %.1f%%", recallRounded, invited, total, RECALL_FLOOR)
	)
end)

test("v24 gauntlet: the author's own examples are never invited", function()
	local data = loadFixture()
	local w, a, DR, faction = openDriver("Orgrimmar", true)
	local genName = makeNameGen()
	local sendWhisper = makeWhisperSender(w, a, DR, faction, genName)
	local allServed = tryAllPlaces(DR, sendWhisper, true)
	local sendPublic = makePublicSender(w, a, DR, "Orgrimmar", faction, genName)
	local checked = {}
	for i, item in ipairs(data.lines) do
		if item.writer == "author" or item.real == true then
			local n, lbl, writer, text = entryMeta(item, i)
			local wInv = sendWhisper(item.text)
			local pInv = sendPublic(item.text)
			checked[#checked + 1] = {
				n = n, lbl = lbl, writer = writer, text = text, raw = item.text,
				whisper = wInv, public = pInv,
			}
		end
	end
	T.clean(w)
	if not allServed then
		local w2, a2, DR2, faction2 = openDriver("Stormwind", true)
		local sendWhisper2 = makeWhisperSender(w2, a2, DR2, faction2, genName)
		local sendPublic2 = makePublicSender(w2, a2, DR2, "Stormwind", faction2, genName)
		for _, r in ipairs(checked) do
			if not r.whisper and sendWhisper2(r.raw) then r.whisper = true end
			if not r.public and sendPublic2(r.raw) then r.public = true end
		end
		T.clean(w2)
	end
	ok(#checked > 0, "gauntlet fixture has author or real examples")
	for _, r in ipairs(checked) do
		local where = (r.whisper and r.public) and "whisper and Trade"
			or (r.whisper and "whisper")
			or (r.public and "Trade")
			or "neither"
		ok(
			not r.whisper and not r.public,
			string.format("#%d [%s, %s] invited via %s: %s", r.n, r.lbl, r.writer, where, r.text)
		)
	end
end)

local NON_PUBLIC_CHAT = { whisper = true, party = true, guild = true, raid = true }
local ORG_WORDS = { "orgrimmar", "org", "og", "orgri", "ogri", "orgrimar", "orgimmar", "ogrimmar" }

-- (the lead, after the first run) The same rule as for invites (see applies above): a label belongs to a line in ITS OWN
-- channel. An unclear line from party, guild or raid chat ("need a summon to sw" among guild mates) is unclear BECAUSE
-- of that channel. Wuber does not read those channels, so such a line can never get a reply there; said in Trade the
-- same words are a plain request. So those lines are not replayed as public lines. Every never-invite line, every
-- unclear line from a whisper or a public channel, the author's lines and the real lines are replayed, always.
local function replayable(item)
	if item.label ~= "unclear" then return true end
	if item.real or item.writer == "author" then return true end
	return not GROUP_CHAT[item.channel]
end

-- (the lead) A driver's place is where they stand: one world per city the fake game knows, so that a line asking for
-- any of them meets a driver who serves it. words: the TEST's own list of how that place is written (whole words,
-- lower case, after every non-letter became a space), kept apart from Wuber's list on purpose. A reply to a line
-- marked invite that this list does not know fails the test: the lead reads the line and adds the spelling only
-- if it truly asks for that place (so far: "thunder bluf", "ironforgee", "boty bay").
local REPLY_SPOTS = {
	{ spot = "Orgrimmar", words = ORG_WORDS },
	{ spot = "Undercity", words = { "undercity", "uc", "under city", "entrañas", "entranas", "unterstadt", "fossoyeuse" } },
	{ spot = "Thunder Bluff", words = { "thunder bluff", "thunderbluff", "tb", "cima del trueno", "donnerfels", "bluff", "thunder bluf" } },
	{ spot = "Stormwind", words = { "stormwind", "stormwind city", "sw", "storm", "ventormenta", "sturmwind", "hurlevent", "stormwin", "stormwnd" } },
	{ spot = "Ironforge", words = { "ironforge", "if", "iron forge", "forjaz", "eisenschmiede", "forgefer", "ironforgee" } },
	{ spot = "Booty Bay", words = { "booty bay", "bootybay", "bb", "booty", "bahia del botin", "beutebucht", "boty bay" } },
	{ spot = "Gadgetzan", words = { "gadgetzan", "gadget", "gadge", "gz" } },
}

local function openReplyDriver(spot)
	local w = H.NewWorld({})
	local a = w:addClient(T.ANITA, { spot = spot, class = "WARLOCK", shards = 10 })
	w:advance(15)
	local DR = a.W.Drive
	DR.opts().autoInvite = true
	DR.opts().watchPublic = true
	ok(DR.SetOpen(true), spot .. ": driver open")
	w:advance(3)
	local faction = (a.player and a.player.faction) or (spot == "Stormwind" and "Alliance" or "Horde")
	return w, a, DR, faction
end

local function makeReplySender(w, a, DR, faction, genName, spot)
	spot = spot or (a.player and a.player.zone) or (faction == "Alliance" and "Stormwind" or "Orgrimmar")
	local probeText = "WTB summon to " .. spot
	local foundCh
	local step = 0.2
	for _, ch in ipairs({ "Trade - City", "Trade" }) do
		local probe = genName()
		w:addBot(probe, { spot = "Ratchet", acceptsInvites = false, faction = faction })
		w:chatFrom(probe, probeText, "CHANNEL", ch, faction)
		local replies = w:whispersTo(probe, "reply")
		local elapsed = 0
		if #replies == 0 then
			for _ = 1, 10 do
				w:advance(0.1)
				elapsed = elapsed + 0.1
				replies = w:whispersTo(probe, "reply")
				if #replies > 0 then break end
			end
		end
		local c = DR.customers[key(probe)]
		if c then DR.Remove(c) end
		if #replies > 0 then
			foundCh = ch
			step = elapsed > 0 and elapsed or 0.2
			break
		end
	end
	if not foundCh then
		ok(false, "the public chat probe got no reply whisper")
		return function()
			return {}, nil
		end
	end
	return function(text, kind, keepRow)
		w:advance(8) -- r51 SEC-M2: whisper-backs leave 8 s apart, so each asker comes 8 s after the last
		local sender = genName()
		w:addBot(sender, { spot = "Ratchet", acceptsInvites = false, faction = faction })
		if kind == "SAY" then
			w:chatFrom(sender, text, "SAY", nil, faction)
		else
			w:chatFrom(sender, text, "CHANNEL", foundCh, faction)
		end
		w:advance(step)
		local replies = w:whispersTo(sender, "reply")
		if not keepRow then
			local c = DR.customers[key(sender)]
			if c then DR.Remove(c) end
		end
		return replies, sender
	end
end

local function checkReplyFormat(replyText)
	local p1, p2 = tostring(replyText or ""):match('^Want a summon to (.+)%? Whisper me "summon (.+)"%.$')
	return p1 ~= nil and p1 == p2
end

local function formatWrongReply(wrong)
	local out = { string.format("%d wrong reply whisper(s):", #wrong) }
	local limit = math.min(#wrong, 25)
	for i = 1, limit do
		local e = wrong[i]
		out[#out + 1] = string.format("#%d [%s, %s] %s: %s", e.n, e.lbl, e.writer, e.what, e.text)
	end
	if #wrong > 25 then
		out[#out + 1] = string.format("... and %d more", #wrong - 25)
	end
	return table.concat(out, "\n")
end

test("v24 gauntlet: a reply whisper goes only to lines marked invite (a driver who serves every place)", function()
	local data = loadFixture()
	local w, a, DR, faction = openReplyDriver("Orgrimmar")
	local genName = makeNameGen()
	local sendWhisper = makeWhisperSender(w, a, DR, faction, genName)
	local allServed = tryAllPlaces(DR, sendWhisper, true)
	local sendReply = makeReplySender(w, a, DR, faction, genName, "Orgrimmar")
	local wrong = {}
	local replyCount = {}
	local whyByIdx = {}
	local function checkReplies(i, item, replies)
		local reasons = {}
		if item.label ~= "invite" then
			reasons[#reasons + 1] = "label is " .. tostring(item.label)
		end
		if #replies > 1 then
			reasons[#reasons + 1] = string.format("%d replies", #replies)
		end
		for _, r in ipairs(replies) do
			if not checkReplyFormat(r.text) then
				reasons[#reasons + 1] = "bad reply text: " .. cleanText(r.text)
				break
			end
		end
		if #reasons > 0 then
			local n, lbl, writer, text = entryMeta(item, i)
			wrong[#wrong + 1] = {
				n = n, lbl = lbl, writer = writer, text = text,
				what = table.concat(reasons, "; "),
			}
		end
	end
	for i, item in ipairs(data.lines) do
		local replies = replayable(item) and sendReply(item.text) or {}
		replyCount[i] = replayable(item) and #replies or -1
		if #replies > 0 then
			checkReplies(i, item, replies)
		elseif item.label == "invite" and not NON_PUBLIC_CHAT[item.channel] then
			local _, why = DR.Careful(item.text, "public")
			whyByIdx[i] = tostring(why)
		end
	end
	T.clean(w)
	if not allServed then
		local w2, a2, DR2, faction2 = openReplyDriver("Stormwind")
		local sendReply2 = makeReplySender(w2, a2, DR2, faction2, genName, "Stormwind")
		for i, item in ipairs(data.lines) do
			if replyCount[i] == 0 then
				local replies = sendReply2(item.text)
				if #replies > 0 then
					replyCount[i] = #replies
					checkReplies(i, item, replies)
				end
			end
		end
		T.clean(w2)
	end
	local total = 0
	local replied = 0
	local reportLines = {}
	for _, e in ipairs(wrong) do
		reportLines[#reportLines + 1] = string.format("WRONG reply #%d [%s, %s] %s: %s", e.n, e.lbl, e.writer, e.what, e.text)
	end
	for i, item in ipairs(data.lines) do
		if item.label == "invite" and not NON_PUBLIC_CHAT[item.channel] then
			total = total + 1
			if replyCount[i] == 1 then
				replied = replied + 1
			elseif replyCount[i] == 0 then
				local n, _, _, text = entryMeta(item, i)
				reportLines[#reportLines + 1] = string.format("NOREPLY #%d [%s] %s", n, whyByIdx[i] or "?", text)
			end
		end
	end
	local recall = total > 0 and (replied * 100 / total) or 0
	local recallRounded = math.floor(recall * 10 + 0.5) / 10
	reportLines[#reportLines + 1] = string.format(
		"reply recall %.1f%% (%d/%d); wrong replies %d; lines %d",
		recallRounded, replied, total, #wrong, #data.lines
	)
	writeReport(reportLines)
	eq(#wrong, 0, #wrong == 0 and "no wrong reply whispers" or formatWrongReply(wrong))
	ok(total > 0, "gauntlet fixture has public invite lines")
	ok(
		recallRounded >= REPLY_RECALL_FLOOR,
		string.format("reply recall %.1f%% (%d/%d), floor %.1f%%", recallRounded, replied, total, REPLY_RECALL_FLOOR)
	)
end)

-- whether the text names a place by the test's own word list
local function mentions(text, words)
	local s = " " .. tostring(text or ""):lower():gsub("[^a-zñ]", " "):gsub("%s+", " ") .. " "
	for _, word in ipairs(words) do
		if s:find(" " .. word .. " ", 1, true) then return true end
	end
	return false
end

local spotReplied = {} -- [spot] = how many lines got a right reply (the report's last lines)

for _, S in ipairs(REPLY_SPOTS) do
	local spot = S.spot
	test("v24 gauntlet: a driver in " .. spot .. " replies only to lines that ask for " .. spot, function()
		local data = loadFixture()
		local w, a, DR, faction = openReplyDriver(spot)
		local genName = makeNameGen()
		local sendReply = makeReplySender(w, a, DR, faction, genName, spot)
		local place = tostring(DR.Dest and DR.Dest() or spot)
		local wrong = {}
		local replied = 0
		local askedPublic, repliedPublic = 0, 0 -- (the lead, for the report) honest public requests that name this place
		local expected = 'Want a summon to ' .. place .. '? Whisper me "summon ' .. place .. '".'
		for i, item in ipairs(data.lines) do
			local replies = replayable(item) and sendReply(item.text) or {}
			local publicAsk = item.label == "invite" and not NON_PUBLIC_CHAT[item.channel] and mentions(item.text, S.words)
			if publicAsk then
				askedPublic = askedPublic + 1
				if #replies == 1 then
					repliedPublic = repliedPublic + 1
				else
					local _, why = DR.Careful(item.text, "public")
					local n, _, _, text = entryMeta(item, i)
					writeReport({ string.format("NOREPLY (%s) #%d [%s] %s", spot, n, tostring(why), text) })
				end
			end
			if #replies > 0 then
				local reasons = {}
				if item.label ~= "invite" then
					reasons[#reasons + 1] = "label is " .. tostring(item.label)
				end
				if not mentions(item.text, S.words) then
					reasons[#reasons + 1] = "does not ask for " .. spot
				end
				if #replies > 1 then
					reasons[#reasons + 1] = string.format("%d replies", #replies)
				end
				for _, r in ipairs(replies) do
					if r.text ~= expected then
						reasons[#reasons + 1] = "unexpected reply: " .. cleanText(r.text)
						break
					end
				end
				if #reasons > 0 then
					local n, lbl, writer, text = entryMeta(item, i)
					wrong[#wrong + 1] = {
						n = n, lbl = lbl, writer = writer, text = text,
						what = table.concat(reasons, "; "),
					}
				else
					replied = replied + 1
				end
			end
		end
		T.clean(w)
		spotReplied[spot] = replied
		local reportLines = {}
		for _, e in ipairs(wrong) do
			reportLines[#reportLines + 1] = string.format("WRONG reply (%s) #%d [%s, %s] %s: %s", spot, e.n, e.lbl, e.writer, e.what, e.text)
		end
		reportLines[#reportLines + 1] = string.format("replies of a driver in %s: %d right, %d wrong; of %d honest public requests that name it, %d got a reply",
			spot, replied, #wrong, askedPublic, repliedPublic)
		writeReport(reportLines)
		eq(#wrong, 0, #wrong == 0 and ("no wrong reply whispers in " .. spot) or formatWrongReply(wrong))
		ok(replied >= 1, "at least one line that asks for " .. spot .. " got a reply")
	end)
end

test("v24 gauntlet: the author's examples and the real lines get no reply, LF sleeping bag summons least of all", function()
	local data = loadFixture()
	local w, a, DR, faction = openReplyDriver("Orgrimmar")
	local genName = makeNameGen()
	local sendWhisper = makeWhisperSender(w, a, DR, faction, genName)
	local allServed = tryAllPlaces(DR, sendWhisper, true)
	local sendReply = makeReplySender(w, a, DR, faction, genName, "Orgrimmar")
	local checked = {}
	for i, item in ipairs(data.lines) do
		if item.writer == "author" or item.real == true then
			local n, lbl, writer, text = entryMeta(item, i)
			local tReplies = sendReply(item.text, "CHANNEL")
			local sReplies = sendReply(item.text, "SAY")
			checked[#checked + 1] = {
				n = n, lbl = lbl, writer = writer, text = text, raw = item.text,
				trade = #tReplies, say = #sReplies,
			}
		end
	end
	local bagText = "LF sleeping bag summons"
	local bagTrade = #sendReply(bagText, "CHANNEL")
	local bagSay = #sendReply(bagText, "SAY")
	T.clean(w)
	if not allServed then
		local w2, a2, DR2, faction2 = openReplyDriver("Stormwind")
		local sendReply2 = makeReplySender(w2, a2, DR2, faction2, genName, "Stormwind")
		for _, r in ipairs(checked) do
			if r.trade == 0 then r.trade = #sendReply2(r.raw, "CHANNEL") end
			if r.say == 0 then r.say = #sendReply2(r.raw, "SAY") end
		end
		if bagTrade == 0 then bagTrade = #sendReply2(bagText, "CHANNEL") end
		if bagSay == 0 then bagSay = #sendReply2(bagText, "SAY") end
		T.clean(w2)
	end
	ok(#checked > 0, "gauntlet fixture has author or real examples")
	for _, r in ipairs(checked) do
		ok(r.trade == 0, string.format("#%d [%s, %s] got reply in Trade: %s", r.n, r.lbl, r.writer, r.text))
		ok(r.say == 0, string.format("#%d [%s, %s] got reply in /say: %s", r.n, r.lbl, r.writer, r.text))
	end
	ok(bagTrade == 0, "got reply in Trade: " .. bagText)
	ok(bagSay == 0, "got reply in /say: " .. bagText)
end)

test("v24 gauntlet: the reply's own instruction is a clear request when whispered back", function()
	local w, a, DR, faction = openReplyDriver("Orgrimmar")
	ok(DR.opts().autoReply == true, "autoReply option defaults to true")
	local genName = makeNameGen()
	local sendReply = makeReplySender(w, a, DR, faction, genName, "Orgrimmar")
	local beforeInv = #w.invites
	local replies, botName = sendReply("WTB summon to Orgrimmar", "CHANNEL", true)
	eq(#replies, 1, "WTB summon to Orgrimmar got exactly one reply")
	eq(#w.invites, beforeInv, "public line did not invite anyone")
	if #replies >= 1 and botName then
		local replyText = replies[1].text
		eq(
			replyText,
			'Want a summon to Orgrimmar? Whisper me "summon Orgrimmar".',
			"reply text matches expected instruction"
		)
		local instruction = replyText:match('Whisper me "(.-)"')
		ok(instruction ~= nil and instruction ~= "", "extracted whisper instruction from reply")
		if instruction then
			local beforeWhisperInv = #w.invites
			w:botWhisper(botName, a, instruction)
			local k = key(botName)
			local function wasInvited()
				local c = DR.customers[k]
				if c ~= nil and c.state ~= "lead" then return true end
				for i = beforeWhisperInv + 1, #w.invites do
					if key(w.invites[i].to) == k then return true end
				end
				return false
			end
			if not wasInvited() then
				for _ = 1, 10 do
					w:advance(0.1)
					if wasInvited() then break end
				end
			end
			ok(wasInvited(), "bot was invited after whispering back the reply instruction")
			w:advance(0.2)
			eq(#w:whispersTo(botName, "reply"), 1, "bot got no second reply whisper")
		end
	end
	T.clean(w)
end)
