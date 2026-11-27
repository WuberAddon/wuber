-- Tests from the Big Batch 3 mutation run: Drive/Bell.lua guards.
-- Each test guards one line that no other test noticed when it was broken. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function bellPayloads(w, from)
	local out = {}
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBERT" and (not from or e.from == from) and type(e.text) == "string" then
			out[#out + 1] = e.text
		end
	end
	return out
end

-- guards Wuber/Drive/Bell.lua:153 (delete queue = {} when canSend becomes false)
test("mutation b3 bell: queued alerts are dropped when sending becomes blocked", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local wub = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	ok(a.W.Drive.BellSet(wub.player.name), "setup: alert character is set")
	w:advance(2)
	ok(a.W.Drive.Ring("First alert", true), "control: first alert sends immediately")
	ok(a.W.Drive.Ring("Stale queued alert", true), "second alert within gap is queued")
	local origSend = a.env.C_ChatInfo.SendAddonMessage
	a.env.C_ChatInfo.SendAddonMessage = nil
	w:advance(2)
	a.env.C_ChatInfo.SendAddonMessage = origSend
	ok(a.W.Drive.Ring("Fresh alert", true), "fresh alert after send restored sends")
	w:advance(3)
	local sentStale, sentFresh = false, false
	for _, msg in ipairs(bellPayloads(w, T.ANITA)) do
		if msg:find("Stale queued alert", 1, true) then sentStale = true end
		if msg:find("Fresh alert", 1, true) then sentFresh = true end
	end
	ok(sentFresh, "fresh alert was delivered after send restored")
	eq(sentStale, false, "stale alert queued before unsendable state was cleared and not sent later")
	T.clean(w)
end)

-- guards Wuber/Drive/Bell.lua:205 (return nil instead of me() in leadName)
test("mutation b3 bell: non-leader driver in a non-crew group falls back to own name as lead", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local wub = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	w:addBot(T.BOB, { spot = "Orgrimmar", class = "MAGE" })
	T.settle(w)
	w:group({ T.BOB, T.ANITA })
	w:advance(2)
	ok(a.W.Drive.BellSet(wub.player.name), "setup: alert character is set")
	w:advance(2)
	ok(a.W.Drive.Ring("Test lead fallback", true), "driver sends an alert")
	w:advance(2)
	eq(wub.W.db.drive.bell.lead, "Anita", "alert character records the driver as lead when group leader is not crew")
	ok(wub.env.WuberBell and wub.env.WuberBell.sub:GetText() == "Swap to Anita", "banner shows driver name, not generic fallback")
	T.clean(w)
end)

-- guards Wuber/Drive/Bell.lua:316 (order = nil in ringsForCast)
-- guards Wuber/Drive/Bell.lua:317 (~= to == in ringsForCast)
-- guards Wuber/Drive/Bell.lua:322 (== to ~= in ringsForCast)
test("mutation b3 bell: second warlock in whoever-clicks crew does not ring for a cast", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANA, { spot = "Orgrimmar" })
	local b = T.driver(w, T.BEA, { spot = "Orgrimmar" })
	local wub = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	w:addBot("Dan Miller", { spot = "Ratchet", class = "MAGE" })
	T.settle(w)
	w:group({ T.ANA, T.BEA })
	w:advance(2)
	ok(a.W.Drive.OfferCrew(T.BEA), "setup: Ana offers crew")
	w:advance(2)
	b.W.Drive.AnswerOffer(T.ANA, true)
	w:advance(2)
	a.W.Drive.SetCaster("-")
	ok(a.W.Drive.SetOpen(true), "setup: Ana opens")
	ok(b.W.Drive.SetOpen(true), "setup: Bea opens")
	ok(a.W.Drive.BellSet(wub.player.name), "setup: Ana sets alert character")
	ok(b.W.Drive.BellSet(wub.player.name), "setup: Bea sets alert character")
	w:advance(2)
	local logBefore = #w.addonLog
	a.W.Drive.Request("Dan Miller", "whisper", "123")
	w:group({ T.ANA, T.BEA, "Dan Miller" })
	w:advance(2)
	local beaCastPlan = b.W.Drive.button and b.W.Drive.button.plan
	ok(beaCastPlan and (beaCastPlan.type == "macro" or beaCastPlan.type == "click") and beaCastPlan.title:find("Summon", 1, true), "control: Bea has a summon cast plan for Dan Miller")
	local beaRang = false
	for i = logBefore + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.prefix == "WUBERT" and e.from == T.BEA and type(e.text) == "string" and e.text:find("Summon", 1, true) then
			beaRang = true
		end
	end
	eq(beaRang, false, "second warlock alphabetically does not ring for cast")
	T.clean(w)
end)

-- guards Wuber/Drive/Bell.lua:320 (CanCast == true flipped to ~= true in ringsForCast)
test("mutation b3 bell: warlock rings for cast even when an earlier crewmate cannot cast", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANA, { spot = "Orgrimmar" })
	local b = T.driver(w, T.BEA, { spot = "Orgrimmar" })
	local wub = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	w:addBot("Dan Miller", { spot = "Ratchet", class = "MAGE" })
	T.settle(w)
	w:group({ T.ANA, T.BEA })
	w:advance(2)
	ok(b.W.Drive.OfferCrew(T.ANA), "setup: Bea offers crew to warlock Ana")
	w:advance(2)
	a.W.Drive.AnswerOffer(T.BEA, true)
	w:advance(2)
	b.W.Drive.opts().needShards = true
	b.W.Drive.peers[b.W.Key(T.ANA)].shards = 0
	b.W.Drive.SetCaster("-")
	ok(b.W.Drive.SetOpen(true), "setup: Bea opens")
	ok(b.W.Drive.BellSet(wub.player.name), "setup: Bea sets alert character")
	w:advance(2)
	local logBefore = #w.addonLog
	b.W.Drive.Request("Dan Miller", "whisper", "123")
	w:group({ T.ANA, T.BEA, "Dan Miller" })
	w:advance(2)
	local beaCastPlan = b.W.Drive.button and b.W.Drive.button.plan
	ok(beaCastPlan and (beaCastPlan.type == "macro" or beaCastPlan.type == "click") and beaCastPlan.title:find("Summon", 1, true), "control: Bea has a summon cast plan for Dan Miller")
	local beaRang = false
	for i = logBefore + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.prefix == "WUBERT" and e.from == T.BEA and type(e.text) == "string" and e.text:find("Summon", 1, true) then
			beaRang = true
		end
	end
	eq(beaRang, true, "only warlock who can cast rings even when a non-caster precedes her")
	T.clean(w)
end)

-- guards Wuber/Drive/Bell.lua:323 (first(can) == myKey() flipped to ~= in ringsForCast)
test("mutation b3 bell: first warlock in whoever-clicks crew rings for a cast", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANA, { spot = "Orgrimmar" })
	local b = T.driver(w, T.BEA, { spot = "Orgrimmar" })
	local wub = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	w:addBot("Dan Miller", { spot = "Ratchet", class = "MAGE" })
	T.settle(w)
	w:group({ T.ANA, T.BEA })
	w:advance(2)
	ok(a.W.Drive.OfferCrew(T.BEA), "setup: Ana offers crew")
	w:advance(2)
	b.W.Drive.AnswerOffer(T.ANA, true)
	w:advance(2)
	a.W.Drive.SetCaster("-")
	ok(a.W.Drive.SetOpen(true), "setup: Ana opens")
	ok(b.W.Drive.SetOpen(true), "setup: Bea opens")
	ok(a.W.Drive.BellSet(wub.player.name), "setup: Ana sets alert character")
	ok(b.W.Drive.BellSet(wub.player.name), "setup: Bea sets alert character")
	w:advance(2)
	local logBefore = #w.addonLog
	a.W.Drive.Request("Dan Miller", "whisper", "123")
	w:group({ T.ANA, T.BEA, "Dan Miller" })
	w:advance(2)
	local anaCastPlan = a.W.Drive.button and a.W.Drive.button.plan
	ok(anaCastPlan and (anaCastPlan.type == "macro" or anaCastPlan.type == "click") and anaCastPlan.title:find("Summon", 1, true), "control: Ana has a summon cast plan for Dan Miller")
	local anaRang = false
	for i = logBefore + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.prefix == "WUBERT" and e.from == T.ANA and type(e.text) == "string" and e.text:find("Summon", 1, true) then
			anaRang = true
		end
	end
	eq(anaRang, true, "first warlock alphabetically rings for cast")
	T.clean(w)
end)

-- guards Wuber/Drive/Bell.lua:497 (delete b.team = {} when team exceeds MAX_TEAM)
test("mutation b3 bell: new crew hello exceeding max team resets team without duplicates", function()
	local w = T.newWorld()
	local ana = T.rider(w, T.ANA)
	local wub = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	wub.W.db.drive.bell.team = { "ana smith", "bea jones", "cal brown", "dan miller", "eve long", "fay moss" }
	ana.env.C_ChatInfo.SendAddonMessage("WUBERT", "BH~1~Fast Rides~ana smith,gus reed,hal cole,ivy park~Ana~2.4.0", "WHISPER", wub.player.name)
	w:advance(1)
	local team = wub.W.db.drive.bell.team
	eq(#team, 4, "team was reset to the new hello's 4 keys instead of overflowing past MAX_TEAM")
	T.clean(w)
end)

-- guards Wuber/Drive/Bell.lua:736 (return nil instead of true when clearing BellSet)
test("mutation b3 bell: clearing alert character with empty string returns true", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	ok(a.W.Drive.BellSet(T.TESTCHAR), "setup: alert character is set")
	eq(a.W.Drive.BellSet(""), true, "BellSet('') returns true")
	eq(a.W.db.drive.bell.name, "", "alert character name is cleared")
	T.clean(w)
end)

-- guards Wuber/Drive/Bell.lua:760 (delete sendHello() in BellTest)
test("mutation b3 bell: BellTest re-sends hello so an alert character that forgot still hears it", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local wub = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	ok(a.W.Drive.BellSet(wub.player.name), "setup: alert character is set")
	w:advance(2)
	ok(#wub.W.db.drive.bell.team > 0, "control: alert character learned the crew")
	ok(wub.W.Drive.BellForget(), "alert character forgets the crew")
	eq(#wub.W.db.drive.bell.team, 0, "control: alert character team is now empty")
	local okTest, kind = a.W.Drive.BellTest()
	eq(okTest, true, "BellTest succeeds")
	eq(kind, "sent", "BellTest reports sent")
	w:advance(2)
	ok(#wub.W.db.drive.bell.team > 0, "BellTest re-sent hello so alert character re-learned crew")
	ok(wub.env.WuberBell and wub.env.WuberBell:IsShown(), "alert character shows the test alert banner")
	T.clean(w)
end)
