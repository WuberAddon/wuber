-- Mutation guard tests for Wuber/Drive/Commands.lua and Wuber/Drive/Cast.lua.
-- Each test guards one line from commit 1d24ac7 (mapped to current line numbers)
-- that no other test noticed when broken. Loaded by tests/run.lua with helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function addonCount(w, prefix, needle)
	local n = 0
	for _, e in ipairs(w.addonLog) do
		if type(e.text) == "string" and e.text:sub(1, #prefix) == prefix then
			if not needle or e.text:find(needle, 1, true) then n = n + 1 end
		end
	end
	return n
end

local function addonEntries(w, prefix)
	local out = {}
	for _, e in ipairs(w.addonLog) do
		if type(e.text) == "string" and e.text:sub(1, #prefix) == prefix then
			out[#out + 1] = e
		end
	end
	return out
end

---------------------------------------------------------------------------
-- Wuber/Drive/Commands.lua guards
---------------------------------------------------------------------------

-- guards Wuber/Drive/Commands.lua:196 (and -> or in team clear)
test("mutation commands: clearing the crew as captain removes helpers without whispering team-leave to self", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	a.W.Drive.SetCrewMember(T.BOB, "lock")
	w:advance(1)
	local beforeTL = addonCount(w, "TL~")
	a.W.SlashCommand("drive team clear")
	w:advance(3)
	eq(addonCount(w, "TL~") - beforeTL, 1, "only one TL whisper is sent (to Bob, not to captain herself)")
	eq(#a.W.Drive.Crew(), 1, "only the captain remains in the crew")
	T.clean(w)
end)

-- guards Wuber/Drive/Commands.lua:209 (~= -> == in C.ad)
test("mutation commands: ad command saves channel when given and keeps it when run with no argument", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	a.W.SlashCommand("drive ad Trade")
	w:advance(1)
	eq(a.W.Drive.opts().adChannels, "Trade", "ad with channel name sets adChannels")
	a.W.SlashCommand("drive ad")
	w:advance(1)
	eq(a.W.Drive.opts().adChannels, "Trade", "ad with no argument preserves adChannels")
	T.clean(w)
end)

-- guards Wuber/Drive/Commands.lua:322 (== -> ~= in C.paid)
test("mutation commands: paid command marks the rider paid via MarkPaid with zero recorded copper", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	w:addBot(T.BOB, { spot = "Ratchet", acceptsInvites = true })
	T.settle(w)
	ok(a.W.Drive.SetOpen(true), "driver opens")
	w:advance(2)
	w:botWhisper(T.BOB, a, "summon pls")
	w:advance(5)
	a.W.SlashCommand("drive paid " .. T.BOB)
	w:advance(1)
	local paid = addonEntries(w, "PAID~1~")
	ok(#paid >= 1, "PAID message sent")
	local last = paid[#paid].text
	ok(last:find("~0~m", 1, true) ~= nil, "MarkPaid records 0 copper with manual flag: " .. tostring(last))
	T.clean(w)
end)

-- guards Wuber/Drive/Commands.lua:533 (and -> or in keyOf RaidWarlocks)
test("mutation commands: summoners command in raid resolves a first name to the matching raid warlock, not another", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local warlock1 = "Ada Hex"
	local warlock2 = "Vex Shadow"
	w:addBot(warlock1, { spot = "Orgrimmar", class = "WARLOCK" })
	w:addBot(warlock2, { spot = "Orgrimmar", class = "WARLOCK" })
	T.settle(w)
	w:group({ T.ANITA, warlock1, warlock2 }, true)
	w:advance(2)
	a.W.SlashCommand("drive summoners Vex")
	w:advance(1)
	eq(a.W.Char().summoners[1], warlock2, "first name resolves to Vex Shadow, not Ada Hex")
	T.clean(w)
end)

-- guards Wuber/Drive/Commands.lua:536 (== -> ~= in keyOf DR.units)
test("mutation commands: summoners command resolves a first name to the matching group member's full key", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local bob = "Bob Builder"
	local other = "Zed Helper"
	w:addBot(other, { spot = "Orgrimmar", class = "MAGE" })
	w:addBot(bob, { spot = "Orgrimmar", class = "MAGE" })
	T.settle(w)
	w:group({ T.ANITA, other, bob })
	w:advance(2)
	a.W.SlashCommand("drive summoners Bob")
	w:advance(1)
	eq(a.W.Char().summoners[1], bob, "first name resolves to Bob Builder")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- Wuber/Drive/Cast.lua guards
---------------------------------------------------------------------------

-- guards Wuber/Drive/Cast.lua:139 (~= -> == in myStation / DR.ButtonStation)
test("mutation cast: ButtonStation returns the driver's station when two or more stations are active", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local b = T.driver(w, T.BEA, { spot = "Ratchet" })
	w:group({ T.ANITA, T.BEA })
	T.settle(w)
	a.W.Drive.OfferCrew(T.BEA, "lock")
	w:advance(1)
	b.W.Drive.AnswerOffer(T.ANITA, true)
	w:advance(3)
	a.W.Drive.SetDest("Orgrimmar")
	b.W.Drive.SetDest("Ratchet")
	w:advance(3)
	-- MultiStation nil fallback path: ensure Stations() has 2+ and MultiStation is nil
	local origMulti = a.W.Drive.MultiStation
	a.W.Drive.MultiStation = nil
	local st = a.W.Drive.ButtonStation()
	a.W.Drive.MultiStation = origMulti
	eq(st, "orgrimmar", "ButtonStation returns driver's station when crew has 2+ stations")
	T.clean(w)
end)

-- guards Wuber/Drive/Cast.lua:490 (was 454, and -> or in isRitual hidden spell fallback)
test("mutation cast: hidden spellcast without recent castIntent does not start a summon cast", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	w:addBot(T.BOB, { spot = "Ratchet", acceptsInvites = true })
	T.settle(w)
	ok(a.W.Drive.SetOpen(true), "driver opens")
	w:advance(2)
	w:botWhisper(T.BOB, a, "summon pls")
	w:advance(5)
	a.player.target = w:player(T.BOB)
	-- Simulate a hidden spellcast (spellID = nil) with no castIntent
	a:fire("UNIT_SPELLCAST_START", "player", "cast-hidden-1", nil)
	w:advance(1)
	eq(addonCount(w, "CAST~1~"), 0, "no CAST sent when hidden spell has no recent castIntent")
	T.clean(w)
end)

-- guards Wuber/Drive/Cast.lua:512 (was 476, and -> or in castTarget)
test("mutation cast: in sell mode, targeting an unlisted player during Ritual of Summoning does not emit CAST for them", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local stranger = "Random Stranger"
	w:addBot(stranger, { spot = "Orgrimmar", class = "MAGE" })
	T.settle(w)
	w:group({ T.ANITA, stranger })
	w:advance(2)
	a.player.target = w:player(stranger)
	a:fire("UNIT_SPELLCAST_START", "player", "cast-unlisted-1", a.W.Drive.RITUAL_ID)
	w:advance(1)
	eq(addonCount(w, "CAST~1~", stranger), 0, "no CAST sent for unlisted target in sell mode")
	T.clean(w)
end)

-- guards Wuber/Drive/Cast.lua:577 (was 541, == -> ~= in holdStart crew role check)
test("mutation cast: an add-anyway crew helper without Wuber who holds the portal 2s is reported via HELP", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local helper = "Dan Helper"
	w:addBot(helper, { spot = "Orgrimmar", class = "MAGE" })
	w:addBot(T.BOB, { spot = "Ratchet", acceptsInvites = true })
	T.settle(w)
	a.W.Drive.SetCrewMember(helper, "helper", false) -- app = false ("Add anyway")
	ok(a.W.Drive.SetOpen(true), "driver opens")
	w:advance(2)
	w:botWhisper(T.BOB, a, "summon pls")
	w:advance(5)
	w:group({ T.ANITA, helper, T.BOB })
	w:advance(2)
	a.player.target = w:player(T.BOB)
	a:fire("UNIT_SPELLCAST_START", "player", "cast-help-1", a.W.Drive.RITUAL_ID)
	a:fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-help-1", a.W.Drive.RITUAL_ID)
	w:advance(0.5)
	local hUnit
	for i = 1, 4 do
		if a.W.UnitName("party" .. i) == helper then hUnit = "party" .. i break end
	end
	ok(hUnit ~= nil, "helper is in party")
	a:fire("UNIT_SPELLCAST_CHANNEL_START", hUnit, "help-chan-1", a.W.Drive.RITUAL_ID)
	w:advance(2.5)
	a:fire("UNIT_SPELLCAST_CHANNEL_STOP", hUnit, "help-chan-1", a.W.Drive.RITUAL_ID)
	w:advance(1)
	eq(addonCount(w, "HELP~1~", helper), 1, "HELP sent for add-anyway crew helper")
	T.clean(w)
end)

-- guards Wuber/Drive/Cast.lua:581 (was 545, and -> or in holdStart old.stop and not old.told)
test("mutation cast: a duplicate channel-start while a helper is already holding does not reset their 2s hold timer", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local helper = "Dan Helper"
	w:addBot(helper, { spot = "Orgrimmar", class = "MAGE" })
	w:addBot(T.BOB, { spot = "Ratchet", acceptsInvites = true })
	T.settle(w)
	a.W.Drive.SetCrewMember(helper, "helper", false)
	ok(a.W.Drive.SetOpen(true), "driver opens")
	w:advance(2)
	w:botWhisper(T.BOB, a, "summon pls")
	w:advance(5)
	w:group({ T.ANITA, helper, T.BOB })
	w:advance(2)
	a.player.target = w:player(T.BOB)
	a:fire("UNIT_SPELLCAST_START", "player", "cast-help-2", a.W.Drive.RITUAL_ID)
	a:fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-help-2", a.W.Drive.RITUAL_ID)
	w:advance(0.5)
	local hUnit
	for i = 1, 4 do
		if a.W.UnitName("party" .. i) == helper then hUnit = "party" .. i break end
	end
	ok(hUnit ~= nil, "helper is in party")
	-- Helper starts holding, then a duplicate CHANNEL_START arrives at 1.5s, then stops at 2.5s total
	a:fire("UNIT_SPELLCAST_CHANNEL_START", hUnit, "help-chan-a", a.W.Drive.RITUAL_ID)
	w:advance(1.5)
	a:fire("UNIT_SPELLCAST_CHANNEL_START", hUnit, "help-chan-a", a.W.Drive.RITUAL_ID)
	w:advance(1.0)
	a:fire("UNIT_SPELLCAST_CHANNEL_STOP", hUnit, "help-chan-a", a.W.Drive.RITUAL_ID)
	w:advance(0.5)
	eq(addonCount(w, "HELP~1~", helper), 1, "HELP sent because total hold was 2.5s without resetting timer")
	T.clean(w)
end)

-- guards Wuber/Drive/Cast.lua:683 (was 647, and -> or in plainTarget)
test("mutation cast: runner sees a plain summoner channel on a listed rider they targeted without a prior call", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local plainLock = "Plain Lock"
	w:addBot(plainLock, { spot = "Orgrimmar", class = "WARLOCK" })
	w:addBot(T.BOB, { spot = "Ratchet", acceptsInvites = true })
	T.settle(w)
	a.W.Drive.SetCrewMember(plainLock, "lock", false) -- app = false plain summoner
	ok(a.W.Drive.SetOpen(true), "driver opens")
	w:advance(2)
	w:botWhisper(T.BOB, a, "summon pls")
	w:advance(5)
	w:group({ T.ANITA, plainLock, T.BOB })
	w:advance(2)
	local pUnit
	for i = 1, 4 do
		if a.W.UnitName("party" .. i) == plainLock then pUnit = "party" .. i break end
	end
	ok(pUnit ~= nil, "plain summoner is in party")
	w:player(plainLock).target = w:player(T.BOB)
	a:fire("UNIT_SPELLCAST_CHANNEL_START", pUnit, "plain-chan-1", a.W.Drive.RITUAL_ID)
	w:advance(1)
	eq(addonCount(w, "CAST~1~", T.BOB), 1, "runner sends CAST for plain summoner's listed target")
	T.clean(w)
end)

-- guards Wuber/Drive/Cast.lua:688 (was 652, == -> ~= in plainTarget)
test("mutation cast: runner in sell mode ignores a plain summoner channeling on an unlisted target", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local plainLock = "Plain Lock"
	local stranger = "Unlisted Player"
	w:addBot(plainLock, { spot = "Orgrimmar", class = "WARLOCK" })
	w:addBot(stranger, { spot = "Orgrimmar", class = "MAGE" })
	T.settle(w)
	a.W.Drive.SetCrewMember(plainLock, "lock", false)
	w:group({ T.ANITA, plainLock, stranger })
	w:advance(2)
	local pUnit
	for i = 1, 4 do
		if a.W.UnitName("party" .. i) == plainLock then pUnit = "party" .. i break end
	end
	ok(pUnit ~= nil, "plain summoner is in party")
	w:player(plainLock).target = w:player(stranger)
	a:fire("UNIT_SPELLCAST_CHANNEL_START", pUnit, "plain-chan-2", a.W.Drive.RITUAL_ID)
	w:advance(1)
	eq(addonCount(w, "CAST~1~", stranger), 0, "no CAST sent for unlisted target of plain summoner in sell mode")
	T.clean(w)
end)

-- guards Wuber/Drive/Cast.lua:707 (was 671, and -> or in plainStart raid claimed check)
test("mutation cast: runner in raid mode sends CAST when a plain summoner channels on an unclaimed raider", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local plainLock = "Plain Lock"
	local raider1 = "Raider One"
	local raider2 = "Raider Two"
	local raider3 = "Raider Three"
	local raider4 = "Raider Four"
	w:addBot(plainLock, { spot = "Orgrimmar", class = "WARLOCK" })
	w:addBot(raider1, { spot = "Ratchet", class = "MAGE" })
	w:addBot(raider2, { spot = "Ratchet", class = "WARRIOR" })
	w:addBot(raider3, { spot = "Ratchet", class = "PRIEST" })
	w:addBot(raider4, { spot = "Ratchet", class = "ROGUE" })
	T.settle(w)
	a.W.Drive.SetCrewMember(plainLock, "lock", false)
	w:group({ T.ANITA, plainLock, raider1, raider2, raider3, raider4 })
	w:setAssist(T.ANITA, true)
	w:advance(2)
	ok(a.W.Drive.SetMode("raid"), "driver switches to raid mode")
	ok(a.W.Drive.SetOpen(true), "driver opens")
	w:advance(1)
	-- Raider Two is in raidRows (unclaimed); plainLock channels on Raider One
	ok(a.W.Drive.RaidAdd(raider2), "raider2 added to raidRows")
	w:advance(1)
	local pUnit
	for i = 1, 40 do
		if a.W.UnitName("raid" .. i) == plainLock then pUnit = "raid" .. i break end
	end
	ok(pUnit ~= nil, "plain summoner is in raid")
	w:player(plainLock).target = w:player(raider1)
	a:fire("UNIT_SPELLCAST_CHANNEL_START", pUnit, "plain-raid-1", a.W.Drive.RITUAL_ID)
	w:advance(1)
	eq(addonCount(w, "CAST~1~", raider1), 1, "runner sends CAST for unclaimed raider before CH")
	T.clean(w)
end)
