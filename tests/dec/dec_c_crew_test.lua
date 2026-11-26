-- Decisions round, group C: the crew. FAB-03 (a member's own price, typed place, largest group, kick and whisper mode
-- come back on every way out of a crew), FAB-09 (the crew outbox holds and retries while the game's chat is locked),
-- AUD-226 (a full crew and one more Warlock ticked: "Crew is full (8 players)"). Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- FAB-03 ------------------------------------------------------------------------------------------------------------
-- Ana (captain) and Bea (member) in one party; Bea has her own price, largest group automatic, kick off, whisper "box".
local function crewOf(saved)
	local w = T.newWorld()
	local ana = w:addClient(T.ANA, { spot = "Orgrimmar", class = "WARLOCK" })
	local bea = w:addClient(T.BEA, { spot = "Orgrimmar", class = "WARLOCK", saved = saved })
	w:group({ T.ANA, T.BEA })
	T.settle(w)
	local A, B = ana.W.Drive, bea.W.Drive
	B.SetPrice(70000)
	B.SetOpt("maxGroup", 0)
	B.SetOpt("kickAfter", false)
	B.SetOpt("whisperMode", "box")
	eq(B.Dest(), "Orgrimmar", "setup: Bea alone summons to where she stands")
	ok(A.OfferCrew(T.BEA), "setup: the crew offer")
	w:advance(3)
	B.AnswerOffer(T.ANA, true)
	w:advance(3)
	ok(B.char().captain ~= "", "setup: Bea is in Ana's crew")
	A.SetPrice(20000)
	A.SetDest("Undercity")
	A.SetOpt("maxGroup", 10)
	A.SetOpt("kickAfter", true)
	A.SetOpt("whisperMode", "macro")
	A.SendConfig()
	w:advance(5)
	eq(B.Dest(), "Undercity", "control: in the crew Bea follows the captain's place")
	eq(bea.W.Char().price, 20000, "control: and the captain's price")
	eq(B.opts().maxGroup, 10, "control: and the captain's largest group")
	return w, ana, bea
end

local function isOwn(bea, how)
	local B = bea.W.Drive
	eq(B.char().captain, "", how .. ": Bea is out of the crew")
	eq(B.Dest(), "Orgrimmar", how .. ": she summons to where she stands again")
	eq(bea.W.Char().dest, "", how .. ": no typed place")
	eq(bea.W.Char().price, 70000, how .. ": her own price")
	eq(tonumber(B.opts().maxGroup) or 0, 0, how .. ": largest group is automatic again")
	eq(B.MaxGroup(), 5, how .. ": so alone it is a party of 5")
	eq(B.opts().kickAfter, false, how .. ": her own 'remove after the summon'")
	eq(B.opts().whisperMode, "box", how .. ": her own whisper mode")
	eq(bea.W.Char().crewOwn, nil, how .. ": nothing is kept aside any more")
end

test("dec c: FAB-03 a member who leaves a crew has her own price, place, largest group, kick and whisper mode back", function()
	local w, ana, bea = crewOf()
	bea.W.Drive.LeaveCrew()
	w:advance(5)
	isOwn(bea, "left")
	T.clean(w)
end)

test("dec c: FAB-03 a member the captain removes has her own values back", function()
	local w, ana, bea = crewOf()
	ana.W.Drive.RemoveCrew(T.BEA)
	w:advance(5)
	isOwn(bea, "removed")
	T.clean(w)
end)

test("dec c: FAB-03 the captain ends the crew: the member has her own values back", function()
	local w, ana, bea = crewOf()
	ana.W.Drive.LeaveCrew()
	w:advance(5)
	isOwn(bea, "crew ended")
	T.clean(w)
end)

test("dec c: FAB-03 the captain's later changes never replace what was kept aside, and her values come back once", function()
	local w, ana, bea = crewOf()
	local A, B = ana.W.Drive, bea.W.Drive
	A.SetPrice(30000)
	A.SetDest("Thunder Bluff")
	A.SendConfig()
	w:advance(5)
	eq(bea.W.Char().price, 30000, "control: the second config arrived")
	eq(bea.W.Char().crewOwn.price, 70000, "still her own price aside")
	B.LeaveCrew()
	w:advance(5)
	isOwn(bea, "left after two configs")
	-- alone she changes her price; a second way out (a late TL, a second Leave) changes nothing
	B.SetPrice(90000)
	B.LeaveCrew()
	eq(B.RestoreOwnConfig(), false, "nothing to put back a second time")
	eq(bea.W.Char().price, 90000, "her new price stays")
	T.clean(w)
end)

test("dec c: FAB-03 her own values are saved with the character, so a reload inside the crew does not lose them", function()
	local w, ana, bea = crewOf()
	local own = bea.W.Char().crewOwn
	ok(type(own) == "table", "kept aside in the character's saved settings")
	eq(own.price, 70000, "price")
	eq(own.dest, "", "place")
	eq(tonumber(own.maxGroup) or 0, 0, "largest group automatic")
	eq(own.kickAfter, false, "kick")
	eq(own.whisperMode, "box", "whisper mode")
	bea = w:reload(bea)
	w:advance(5)
	ok(type(bea.W.Char().crewOwn) == "table", "still there after a reload")
	eq(bea.W.Char().price, 20000, "control: still the captain's price in the crew")
	bea.W.Drive.LeaveCrew()
	w:advance(5)
	isOwn(bea, "left after a reload")
	T.clean(w)
end)

test("dec c: FAB-03 a solo driver (no crew) keeps nothing aside", function()
	local w = T.newWorld()
	local bea = w:addClient(T.BEA, { spot = "Orgrimmar", class = "WARLOCK" })
	T.settle(w)
	eq(bea.W.Drive.KeepOwnConfig(), false, "not in a crew: nothing kept")
	eq(bea.W.Char().crewOwn, nil, "nothing aside")
	T.clean(w)
end)

-- FAB-09 ------------------------------------------------------------------------------------------------------------
test("dec c: FAB-09 a crew fact sent while the game's chat is locked (answer 11) is held and goes when the lock ends", function()
	local w = T.newWorld()
	local ana = w:addClient(T.ANA, { spot = "Orgrimmar", class = "WARLOCK" })
	local bea = w:addClient(T.BEA, { spot = "Orgrimmar", class = "WARLOCK" })
	w:group({ T.ANA, T.BEA })
	T.settle(w)
	local A, B = ana.W.Drive, bea.W.Drive
	ok(A.OfferCrew(T.BEA), "setup: the crew offer")
	w:advance(3)
	B.AnswerOffer(T.ANA, true)
	w:advance(5)
	ok(B.char().captain ~= "", "setup: Bea is in Ana's crew")
	eq((A.CommBacklog()), 0, "setup: Ana's crew outbox is empty")
	local failed = A.comm.failed
	ana.chatLock = true
	A.SetPrice(40000)
	A.SendConfig()
	A.Send("TPL", "thanks", "dec c test line")
	w:advance(8)
	ok(bea.W.Char().price ~= 40000, "control: nothing reached Bea during the lock")
	local held = A.CommBacklog()
	ok(held >= 2, "the two crew messages are still in the outbox (" .. tostring(held) .. " held; failed went from "
		.. tostring(failed) .. " to " .. tostring(A.comm.failed) .. ")")
	eq(A.comm.failed, failed, "a locked chat is no failed send")
	ok((ana.lockRefused or 0) <= 8, "asked again about every 2 s, not every tick (" .. tostring(ana.lockRefused) .. " tries in 8 s)")
	ana.chatLock = false
	w:advance(6)
	eq((A.CommBacklog()), 0, "the outbox emptied after the lock")
	eq(bea.W.Char().price, 40000, "Bea's window has the captain's price: the fact was not lost")
	T.clean(w)
end)

-- AUD-226 -----------------------------------------------------------------------------------------------------------
local DRU, LEA, WAR = "Dru Oak", "Lea Dorn", "Wick Lock"

local function raidPick(crewN)
	local w = H.NewWorld({})
	local crew = {}
	for i = 1, crewN do crew[i] = { name = "Helper H" .. string.char(96 + i), role = "helper", app = true } end
	w:addBot(LEA, { spot = "Blackrock Mountain", class = "WARRIOR" })
	w:addBot(WAR, { spot = "Blackrock Mountain", class = "WARLOCK" }) -- a Warlock with no Wuber
	local dru = w:addClient(DRU, { spot = "Blackrock Mountain", class = "DRUID",
		saved = { Wuber = { chars = { [key(DRU)] = { crew = crew, captain = "", wizard = true } } } } })
	local names = { LEA, DRU, WAR }
	for i = 1, 5 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar", class = "WARRIOR" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(DRU, true)
	T.settle(w)
	ok(dru.W.Drive.SetMode("raid"))
	T.openDrive(dru)
	dru.W.Driver.ShowSheet("raidpick") w:advance(1)
	local s = dru.W.UI.drive.screens.raidpick
	local row
	for _, r in ipairs(s.rows.list) do if r:IsShown() and r.p and r.p.key == key(WAR) then row = r end end
	ok(row, "control: the Warlock without Wuber is listed")
	return w, dru, row
end

test("dec c: AUD-226 a full crew of 8 and one more Warlock ticked: the toast says 'Crew is full (8 players)' and he is not added", function()
	local w, dru, row = raidPick(8)
	eq(dru.W.Drive.CREW_MAX, 8, "the limit is the code's constant")
	eq(#dru.W.Char().crew, 8, "control: the crew is full")
	dru:clickOn(row.toggle) w:advance(1)
	ok(dru.W.Drive.CrewEntry(key(WAR)) == nil, "he is not added")
	eq(#dru:findText("Wick summons", false, true), 0, "no 'summons' toast")
	ok(#dru:findText("Crew is full (8 players)", true, true) > 0 or #dru:findText("Crew is full (8 players)", false, true) > 0,
		"the toast 'Crew is full (8 players)' shows: " .. T.list(dru:visibleTexts()):sub(1, 300))
	T.clean(w)
end)

test("dec c: AUD-226 with room in the crew the Warlock is added and nothing says the crew is full", function()
	local w, dru, row = raidPick(7)
	dru:clickOn(row.toggle) w:advance(1)
	ok(dru.W.Drive.CrewEntry(key(WAR)), "he is in the crew")
	ok(#dru:findText("Wick summons", false, true) > 0, "the toast says he summons")
	eq(#dru:findText("Crew is full", false, true), 0, "no 'Crew is full' toast")
	T.clean(w)
end)
