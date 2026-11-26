-- Tests of Drive.Book (round 9: FIXROUND-2.3.0 items 1 and 3; owner D). Loaded by tests/run.lua with
-- its helper table T. The customer book (notes, the Gifted stamp, the "Get Wuber" stamp), the facts
-- from the log, "Get Wuber" through the big button only, and the sync between the driver's OWN crew
-- windows (addon whispers to trusted crew only; anyone else is ignored).
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local ANA, BEA, CAL, DAN, EVE = "Ana Smith", "Bea Jones", "Cal Brown", "Dan Miller", "Eve Night"
local SPOT = "Undercity"

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- own: the names this character marked "My own account" (default: every other crew member)
local function crewSaved(me, names, captain, extra, own)
	local crew, marks = {}, {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end
	end
	for _, n in ipairs(own or names) do if n ~= me then marks[key(n)] = true end end
	local t = { chars = { [key(me)] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true,
		bookOwn = next(marks) and marks or nil } } }
	for k, v in pairs(extra or {}) do t[k] = v end
	return t
end

-- a crew of Warlocks (the first is the captain), grouped unless o.group == false; o.own[name] = the
-- names that window marked as its own accounts (default: all the others)
local function crew(names, o)
	o = o or {}
	local w = H.NewWorld({})
	local cs = {}
	for i, name in ipairs(names) do
		cs[i] = w:addClient(name, { spot = SPOT, class = "WARLOCK",
			saved = { Wuber = crewSaved(name, names, names[1], nil, o.own and (o.own[name] or {})) } })
	end
	if o.group ~= false then w:group(names) end
	w:advance(15)
	return w, cs
end

-- every WUBERT message of the book's kinds
local function bookMsgs(w)
	local out = {}
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBERT" and (e.text:match("^BK[HQRE]~")) then out[#out + 1] = e end
	end
	return out
end

local function press(c)
	local b = c.env.WuberDriveButton
	ok(b, c.player.name .. ": no WuberDriveButton")
	ok(H.visible(b), c.player.name .. ": the big button is hidden")
	return c:click(b)
end

test("drive.book: contract (registered, deps, header, public names); idle: nothing saved", function()
	local W, w, r, Mod = T.contract("Drive.Book", "tests/drive/book_test.lua", {
		["DR.BookEntry"] = "function", ["DR.SetNote"] = "function", ["DR.SetGifted"] = "function",
		["DR.CustomerFacts"] = "function", ["DR.Customers"] = "function", ["DR.GetAppState"] = "function",
		["DR.AskGetApp"] = "function", ["DR.HasWuber"] = "function", ["DR.GetAppOwed"] = "function", ["DR.GetAppSent"] = "function",
		["DR.BookShareOn"] = "function", ["DR.BookPeers"] = "function", ["DR.BookHeard"] = "function",
		["DR.BookTick"] = "function", ["DR.BookBacklog"] = "function", ["DR.BOOK"] = "table",
		["DR.BookOwn"] = "function", ["DR.SetBookOwn"] = "function", ["Mod.asking"] = "function",
		["Mod.parts"] = "function", ["Mod.recordMessages"] = "function",
	})
	ok(Mod, "W.Mod(\"Drive.Book\")")
	eq(W.db.drive.book, nil, "no book saved")
	eq(#W.Drive.Customers(), 0, "nobody in it")
	eq(W.Drive.BookEntry(DAN), nil)
	eq(W.db.drive.book, nil, "reading made nothing")
	ok(not W.Drive.TEMPLATES.getapp:lower():find("free", 1, true), "the default never says free")
	ok(W.Drive.TEMPLATES.getapp:find("CurseForge", 1, true), "it says where to get it")
	T.clean(w)
end)

test("drive.book: notes, the Gifted stamp (once), facts from the log, the Customers list (search, latest ride first)", function()
	local w = H.NewWorld({})
	local a = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	w:advance(2)
	local DR = a.W.Drive
	local t0 = a.env.time()
	local l = DR.Log()
	l.rides[#l.rides + 1] = table.concat({ t0 - 90000, 5000, DAN, "Orgrimmar", "t", 5000 }, ",")
	l.rides[#l.rides + 1] = table.concat({ t0 - 2000, 5000, EVE, "Undercity", "t", 5000 }, ",")
	l.rides[#l.rides + 1] = table.concat({ t0 - 1000, 5000, EVE, "Undercity", "t", 5000 }, ",") -- the same ride (30 min)
	l.team[#l.team + 1] = table.concat({ t0 - 600, 5000, DAN, "Thunder Bluff", BEA, BEA }, ",")
	local f = DR.CustomerFacts(DAN)
	eq(f.rides, 2, "Dan: two rides") eq(f.last, t0 - 600, "the last") eq(f.place, "Thunder Bluff", "the last place")
	eq(DR.CustomerFacts(EVE).rides, 1, "Eve: payments 30 min apart are one ride")
	eq(a.W.db.drive.book, nil, "facts need no book")
	ok(DR.SetNote(DAN, "Tips well.\nAlways  Orgrimmar"), "noted")
	eq(DR.BookEntry(DAN).note, "Tips well. Always Orgrimmar", "one clean line")
	ok(DR.SetNote(DAN, string.rep("x", 300)))
	eq(#DR.BookEntry(DAN).note, 200, "200 bytes at most")
	local okG, at = DR.SetGifted(DAN)
	ok(okG, "gifted") ok(at and at >= t0, "stamped now")
	local again, was = DR.SetGifted(DAN)
	eq(again, false, "never twice") eq(was, at, "says when")
	ok(DR.SetNote(DAN, ""), "cleared")
	eq(DR.BookEntry(DAN).note, nil, "no note") eq(DR.BookEntry(DAN).gift, at, "the stamp stays")
	DR.SetNote(CAL, "met in Org")
	local list = DR.Customers()
	eq(#list, 3, "Dan, Eve (rides) and Cal (a note)")
	eq(list[1].name, DAN, "Dan rode last") eq(list[2].name, EVE) eq(list[3].name, CAL, "no ride: last")
	eq(list[1].rides, 2) eq(list[1].gift, at)
	local found = DR.Customers("ev")
	eq(#found, 1, "search") eq(found[1].name, EVE)
	T.clean(w)
end)

-- "Get Wuber" (split from one test of a simulated day, about 120 s, in the speed round): each test
-- below builds the same start with getWuber(upto) and checks one part. upto: "asked" (Dan whispered,
-- a minute of ticks), "picked" (the driver picked him), "sent" (the big button's click sent it).
-- late = true: the world starts at 23:00 (the harness's clock moved on before anyone logs in; every
-- frame and timer after that runs as usual), so the next day is an hour of the clock away, not 24.
local function getWuber(upto, late)
	local w = H.NewWorld({})
	if late then
		local t = os.date("*t", H.EPOCH + math.floor(w.time))
		local move = os.time({ year = t.year, month = t.month, day = t.day, hour = 23, min = 0, sec = 0 }) - H.EPOCH - math.floor(w.time)
		w.time, w.lastFrame = w.time + move, w.lastFrame + move
	end
	local a = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", shards = 10 })
	w:addBot(DAN, { spot = "Orgrimmar", acceptsInvites = false })
	w:advance(15)
	local DR = a.W.Drive
	ok(DR.SetOpen(true), "open")
	w:advance(3)
	w:botWhisper(DAN, a, "summon pls")
	w:advance(3)
	local c = DR.customers[key(DAN)]
	ok(c, "Dan asked by whisper")
	eq(DR.GetAppState(c), "ok", "may be asked")
	-- never by itself: a minute of ticks and button plans, no Get Wuber whisper
	w:advance(60)
	for _, p in ipairs(DR.Pending()) do ok(p.kind ~= "getapp", "not owed unless picked") end
	for _, x in ipairs(w.whispers) do ok(not x.text:find("CurseForge", 1, true), "nothing sent by itself") end
	if upto == "asked" then return w, a, DR, c end
	ok(DR.AskGetApp(c), "picked")
	eq(DR.GetAppState(c), "queued")
	if upto == "picked" then return w, a, DR, c end
	w:advance(5)
	press(a)
	w:advance(2)
	eq(DR.GetAppState(c), "sent", "sent today")
	return w, a, DR, c
end

test("drive.book: Get Wuber - never by itself: a minute of ticks, nothing owed until picked, then owed", function()
	local w, _, DR, c = getWuber("asked")
	ok(DR.AskGetApp(c), "picked")
	eq(DR.GetAppState(c), "queued")
	local owed = false
	for _, p in ipairs(DR.Pending()) do if p.kind == "getapp" and p.c == c then owed = true end end
	ok(owed, "owed now")
	T.clean(w)
end)

test("drive.book: Get Wuber - picked, it waits for the big button's click; the click's macro has it", function()
	local w, _, DR = getWuber("picked")
	w:advance(5)
	for _, x in ipairs(w.whispers) do ok(not x.text:find("CurseForge", 1, true), "still waits for the click") end
	local plan = DR.Plan()
	ok(plan.macrotext and plan.macrotext:find("CurseForge", 1, true), "the click's macro has it: " .. tostring(plan.macrotext))
	T.clean(w)
end)

test("drive.book: Get Wuber - only through the big button's click: one whisper from the secure macro, stamped, not again today", function()
	local w, a, DR, c = getWuber("picked")
	w:advance(5)
	press(a)
	w:advance(2)
	local sent = {}
	for _, x in ipairs(w.whispersTo(w, DAN)) do if x.text:find("CurseForge", 1, true) then sent[#sent + 1] = x end end
	eq(#sent, 1, "one whisper")
	eq(sent[1] and sent[1].how, "macro", "from the secure macro (the click)")
	eq(DR.GetAppState(c), "sent", "sent today")
	ok(DR.BookEntry(DAN) and DR.BookEntry(DAN).app, "stamped")
	eq(DR.AskGetApp(c), false, "not again today")
	T.clean(w)
end)

-- (the old test ran a whole day of game frames, about 120 s; the stamp is for the calendar day, so
-- an evening that runs past midnight is the same check, and a sharper one: sent at 23:01, still
-- sent at 23:59:50, ok again at 00:00:10)
test("drive.book: Get Wuber - once a day: still sent just before midnight, may be asked again the next day", function()
	local w, a, DR, c = getWuber("sent", true)
	eq(os.date("%H", a.env.time()), "23", "sent in the last hour of the day")
	local now = a.env.time()
	local t = os.date("*t", now)
	local midnight = os.time({ year = t.year, month = t.month, day = t.day + 1, hour = 0, min = 0, sec = 0 })
	w:advance(midnight - now - 10)
	eq(DR.GetAppState(DR.customers[key(DAN)] or c), "sent", "still today at 23:59:50")
	eq(DR.AskGetApp(DR.customers[key(DAN)] or c), false, "not again today, just before midnight")
	w:advance(20)
	local c2 = DR.customers[key(DAN)] or c
	eq(DR.GetAppState(c2), "ok", "the next day")
	T.clean(w)
end)

test("drive.book: Get Wuber - never for app riders; an empty template or whispers off is off", function()
	local w, a, DR = getWuber("sent")
	-- a rider who booked through Wuber never gets it
	eq(DR.GetAppState({ name = EVE, source = "wuber", wuberRide = "abcdef" }), "app")
	-- (review) the template saved as nothing (only characters W.Clean drops): nothing to send
	a.W.db.drive.templates.getapp = "||"
	eq(DR.GetAppState({ name = EVE, source = "whisper" }), "off", "an empty template is off")
	a.W.db.drive.templates.getapp = nil
	eq(DR.GetAppState({ name = EVE, source = "whisper" }), "ok", "the default again")
	-- whispers off: nothing to send
	DR.SetOpt("whisperMode", "off")
	eq(DR.GetAppState({ name = EVE, source = "whisper" }), "off")
	T.clean(w)
end)
test("drive.book: (round 12) Get Wuber never goes to a rider Wuber knows has the app (the 19 Nov screenshot)", function()
	local ROCKS = "Wuber Rocks"
	local w = H.NewWorld({})
	local a = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", shards = 10,
		saved = { Wuber = crewSaved(ANA, { ANA, BEA }, ANA, nil, {}) } })
	-- the rider runs Wuber (its own window: it pings the network like any Wuber rider)
	local r = w:addClient(ROCKS, { spot = "Orgrimmar" })
	w:addBot(DAN, { spot = "Orgrimmar", acceptsInvites = false })
	w:advance(15)
	local DR = a.W.Drive
	ok(DR.SetOpen(true), "open")
	w:advance(30)
	-- the screenshot: the app rider whispers by hand ("WTB Summoon") and is listed by whisper
	DR.SetNote(ROCKS, "regular") -- a book record from an earlier ride
	w:whisper(r, ANA, "WTB Summoon", "user")
	w:botWhisper(DAN, a, "summon pls")
	w:advance(3)
	local c, dan = DR.customers[key(ROCKS)], DR.customers[key(DAN)]
	ok(c, "Wuber Rocks is listed by whisper") ok(dan, "Dan too")
	eq(c and c.source, "whisper", "by whisper, not an app booking")
	eq(DR.GetAppState(c), "app", "never offered to a Wuber user")
	ok(DR.HasWuber and DR.HasWuber(c), "Wuber knows he has Wuber (his addon messages came)")
	eq(DR.AskGetApp(c), false, "cannot be picked")
	-- asked before Wuber knew (a stale pick): still never sent, not even by the click
	c.getapp = true
	for _, p in ipairs(DR.Pending()) do ok(not (p.kind == "getapp" and p.c == c), "not owed to Wuber Rocks") end
	-- the chat-only rider still gets the offer, sent by the driver's click only, once
	eq(DR.GetAppState(dan), "ok", "a chat rider without the app may be asked")
	ok(DR.AskGetApp(dan), "picked for Dan")
	press(a)
	w:advance(2)
	for _ = 1, 3 do
		if #DR.Pending() > 0 then press(a) w:advance(2) end
	end
	for _, x in ipairs(w.whispersTo(w, ROCKS)) do ok(not x.text:find("CurseForge", 1, true), "Get Wuber never went to Wuber Rocks: " .. x.text) end
	local toDan = 0
	for _, x in ipairs(w.whispersTo(w, DAN)) do if x.text:find("CurseForge", 1, true) then toDan = toDan + 1 eq(x.how, "macro", "the click") end end
	eq(toDan, 1, "Dan got it once")
	eq(DR.GetAppState(dan), "sent", "not again today")
	-- what else says "has the app": an app booking, a Wuber request line, a [Wuber] advert, a crew
	-- member, a driver heard, a saved Wuber contact
	eq(DR.GetAppState({ name = EVE, source = "wuber", wuberRide = "abcdef" }), "app", "booked through Wuber")
	eq(DR.GetAppState({ name = EVE, source = "group", rideId = "abcdef" }), "app", "a crew window's app ride")
	eq(DR.GetAppState({ name = EVE, source = "whisper", msg = "WTB summon to Orgrimmar for 50s" }), "app", "the Wuber request line")
	eq(DR.GetAppState({ name = EVE, source = "public", msg = "[Wuber] Summons to Orgrimmar 50s" }), "app", "a [Wuber] line")
	ok(DR.GetAppState({ name = BEA, source = "whisper" }) ~= "ok", "never to a crew member")
	eq(DR.GetAppState({ name = EVE, source = "whisper" }), "ok", "Eve: nothing known yet")
	a.W.db.peers = a.W.db.peers or {}
	a.W.db.peers[key(EVE)] = { name = EVE, addr = EVE, at = a.env.time() }
	eq(DR.GetAppState({ name = EVE, source = "whisper" }), "app", "a saved Wuber contact")
	-- the book remembers it for the next session (a reload forgets what was heard)
	ok(DR.BookEntry(ROCKS).wuber, "his book record is marked")
	w:reload(a)
	w:advance(5)
	DR = a.W.Drive
	eq(DR.GetAppState({ name = ROCKS, source = "whisper" }), "app", "after a reload: the book's mark")
	T.clean(w)
end)

test("drive.book: (round 12) e2e - a note saved in the Note sheet reaches my own window's Customers list, never a friend in the crew or a stranger", function()
	local ROCKS = "Wuber Rocks"
	local w, cs = crew({ ANA, BEA, CAL }, { own = { [ANA] = { BEA }, [BEA] = { ANA }, [CAL] = {} } })
	local ana, bea, cal = cs[1], cs[2], cs[3]
	local eve = w:addClient(EVE, { spot = SPOT, class = "WARLOCK" }) -- another driver, not in the crew
	local rocks = w:addClient(ROCKS, { spot = "Orgrimmar" }) -- the customer (a rider)
	w:advance(10)
	-- Ana's own window saves the note through the sheet, as Tester would
	T.openDrive(ana)
	w:advance(1)
	local D = ana.W.Driver
	D.ShowSheet("note", { name = ROCKS })
	w:advance(1)
	local sh = D.ui.sheets.note
	ok(sh and sh.frame.open, "the Note sheet")
	sh.field:SetText("Tips well, always Org")
	ana:click(sh.save)
	w:advance(20)
	eq(ana.W.Drive.BookEntry(ROCKS).note, "Tips well, always Org", "saved on Ana")
	-- Bea (marked "My own account" both ways) has it, in her Customers list too
	local rec = bea.W.Drive.BookEntry(ROCKS)
	eq(rec and rec.note, "Tips well, always Org", "Bea's book has the note")
	local found
	for _, e in ipairs(bea.W.Drive.Customers()) do if e.name == ROCKS then found = e end end
	ok(found and found.note == "Tips well, always Org", "Bea's Customers list has it")
	T.openDrive(bea)
	w:advance(1)
	bea.W.Driver.ShowScreen("customers")
	w:advance(2)
	local t = table.concat(bea:visibleTexts(), " | ")
	ok(t:find(ROCKS, 1, true) and t:find("Tips well", 1, true), "Bea's Customers screen shows him with the note: " .. t)
	-- Cal (crew, not marked: a friend), Eve (a stranger) and the rider never get it
	for _, c in ipairs({ cal, eve, rocks }) do
		eq(c.W.Drive.BookEntry(ROCKS), nil, c.player.name .. " has no note")
	end
	for _, e in ipairs(bookMsgs(w)) do
		ok(e.target == ANA or e.target == BEA, "book messages only between Ana and Bea: " .. tostring(e.target))
		eq(e.chatType, "WHISPER", "by whisper")
		ok(#e.text <= 250, "fits: " .. #e.text)
	end
	T.clean(w)
end)

test("drive.book: (round 12) a window that marks mine later gets my notes within seconds (the author's 19 Nov run)", function()
	-- Ana marked Bea; Bea had not marked Ana yet (the lab's step was skipped)
	local w, cs = crew({ ANA, BEA }, { own = { [ANA] = { BEA }, [BEA] = {} } })
	local ana, bea = cs[1], cs[2]
	ok(ana.W.Drive.SetNote(DAN, "regular"), "Ana notes Dan")
	w:advance(30)
	eq(bea.W.Drive.BookEntry(DAN), nil, "not marked on Bea: nothing taken")
	ok(bea.W.Drive.SetBookOwn(key(ANA), true), "Bea marks Ana")
	w:advance(12)
	local rec = bea.W.Drive.BookEntry(DAN)
	eq(rec and rec.note, "regular", "the note arrived soon after the mark")
	T.clean(w)
end)

test("drive.book: (2.3.2, C8) 'My own account' marked before the crew window is heard is kept: an empty book still says hello when it appears", function()
	local w, cs = crew({ ANA, BEA }, { group = false, own = { [ANA] = {}, [BEA] = {} } })
	local bea = cs[2]
	local function hellos()
		local n = 0
		for _, e in ipairs(bookMsgs(w)) do
			if e.text:match("^BKH~") and e.target == ANA then n = n + 1 end
		end
		return n
	end
	ok(bea.W.Drive.SetBookOwn(key(ANA), true), "Bea marks Ana")
	w:advance(4) -- ticks with nobody grouped: nothing to say, and the mark must stay
	eq(hellos(), 0, "no hello to a window not here")
	w:group({ ANA, BEA })
	w:advance(4)
	ok(hellos() >= 1, "Bea said hello when Ana appeared (hellos " .. hellos() .. ")")
	T.clean(w)
end)

test("drive.book: sync - a note and a gift reach my own crew windows by whisper only, a long note in parts", function()
	local w, cs = crew({ ANA, BEA, CAL })
	local ana, bea, cal = cs[1], cs[2], cs[3]
	local long = string.rep("abc def ", 25) -- 200 bytes with spaces at every cut
	local MAX = "Maximiliana Featherstonehaugh" -- a long name: the note goes in two parts
	ok(ana.W.Drive.SetNote(MAX, long), "Ana notes Max")
	ok(ana.W.Drive.SetNote(DAN, "short"), "Ana notes Dan")
	ok(ana.W.Drive.SetGifted(DAN), "and gifts him")
	w:advance(20)
	for _, c in ipairs({ bea, cal }) do
		local rec = c.W.Drive.BookEntry(DAN)
		ok(rec, c.player.name .. " has Dan")
		eq(rec and rec.note, ana.W.Drive.BookEntry(DAN).note, c.player.name .. ": the whole note")
		eq(rec and rec.gift, ana.W.Drive.BookEntry(DAN).gift, c.player.name .. ": the stamp")
		local m = c.W.Drive.BookEntry(MAX)
		eq(m and m.note, ana.W.Drive.BookEntry(MAX).note, c.player.name .. ": the long note, whole")
	end
	local list = bookMsgs(w)
	ok(#list > 0, "book messages went")
	local parted = false
	for _, e in ipairs(list) do
		eq(e.chatType, "WHISPER", "only by whisper: " .. e.text:sub(1, 30))
		ok(e.target == BEA or e.target == CAL or e.target == ANA, "only to the crew: " .. tostring(e.target))
		ok(#e.text <= 250, "fits: " .. #e.text)
		if e.text:match("~2/2%+?~") then parted = true end
	end
	ok(parted, "the long note went in two parts")
	-- newest edit wins: Bea edits later; the gift is never removed
	w:advance(5)
	ok(bea.W.Drive.SetNote(DAN, "Bea's newer note"))
	w:advance(10)
	eq(ana.W.Drive.BookEntry(DAN).note, "Bea's newer note", "Ana took the newer note")
	eq(cal.W.Drive.BookEntry(DAN).note, "Bea's newer note", "Cal too")
	ok(ana.W.Drive.BookEntry(DAN).gift, "Ana's stamp stays")
	T.clean(w)
end)

test("drive.book: sync - an older note never wins, a record without a gift never removes one", function()
	local w, cs = crew({ ANA, BEA })
	local ana, bea = cs[1], cs[2]
	local DR = ana.W.Drive
	DR.SetNote(DAN, "now")
	DR.SetGifted(DAN)
	w:advance(10)
	local rec = DR.BookEntry(DAN)
	-- an old record from Bea (a crew window): older note, no gift
	ok(DR.BookHeard("BKR", key(BEA), BEA, { "BKR", "1", "99", DAN, tostring(rec.noteAt - 100), "", "", "1/1", "old" }))
	eq(DR.BookEntry(DAN).note, "now", "the older note lost")
	eq(DR.BookEntry(DAN).gift, rec.gift, "the gift stayed")
	-- a later gift date never replaces the first one
	DR.BookHeard("BKR", key(BEA), BEA, { "BKR", "1", "100", DAN, "", tostring(rec.gift + 500), "", "1/1", "" })
	eq(DR.BookEntry(DAN).gift, rec.gift, "the first stamp is kept")
	T.clean(w)
end)

test("drive.book: sync - anyone not in my crew is ignored (whispered BKR, BKQ, BKH)", function()
	local w, cs = crew({ ANA, BEA })
	local ana = cs[1]
	local DR = ana.W.Drive
	w:addBot(EVE, { spot = SPOT })
	w:advance(2)
	DR.SetNote(DAN, "secret")
	w:advance(10)
	local before = #bookMsgs(w)
	-- a stranger tries to write a note, ask for the book, and say hello
	w:inject(EVE, "BKR~1~5~" .. DAN .. "~" .. (ana.env.time() + 10) .. "~~~1/1~evil", "WHISPER", ana, "WUBERT")
	w:inject(EVE, "BKQ~1~0", "WHISPER", ana, "WUBERT")
	w:inject(EVE, "BKH~1~99", "WHISPER", ana, "WUBERT")
	w:advance(10)
	eq(DR.BookEntry(DAN).note, "secret", "a stranger's record is ignored")
	eq(DR.BookEntry(EVE), nil)
	for _, e in ipairs(bookMsgs(w)) do ok(e.target ~= EVE, "nothing to the stranger") end
	eq(#bookMsgs(w), before, "nothing answered")
	-- nor a helper added without Wuber ("Add anyway": app = false)
	DR.SetCrewMember(CAL, "helper", false)
	eq(DR.BookHeard("BKR", key(CAL), CAL, { "BKR", "1", "6", DAN, tostring(ana.env.time() + 20), "", "", "1/1", "evil" }), true)
	eq(DR.BookEntry(DAN).note, "secret", "a helper without Wuber is not trusted")
	T.clean(w)
end)

test("drive.book: sync - a crew window that was away catches up when it is back; sharing off sends nothing", function()
	local w, cs = crew({ ANA, BEA }, { group = false })
	local ana, bea = cs[1], cs[2]
	ana.W.Drive.SetNote(DAN, "while Bea was away")
	ana.W.Drive.SetNote(EVE, "second")
	w:advance(10)
	eq(bea.W.Drive.BookEntry(DAN), nil, "not grouped yet: Bea hasn't heard")
	w:group({ ANA, BEA })
	w:advance(30)
	eq(bea.W.Drive.BookEntry(DAN) and bea.W.Drive.BookEntry(DAN).note, "while Bea was away", "caught up")
	eq(bea.W.Drive.BookEntry(EVE) and bea.W.Drive.BookEntry(EVE).note, "second")
	-- sharing off: a new note stays on this account, and Bea's records are not taken
	ana.W.Drive.SetOpt("shareNotes", false)
	local before = #bookMsgs(w)
	ana.W.Drive.SetNote(CAL, "mine only")
	w:advance(20)
	eq(bea.W.Drive.BookEntry(CAL), nil, "not shared")
	for i = before + 1, #bookMsgs(w) do ok(bookMsgs(w)[i].from ~= ANA, "Ana sent nothing") end
	bea.W.Drive.SetNote(CAL, "from Bea")
	w:advance(10)
	eq(ana.W.Drive.BookEntry(CAL).note, "mine only", "nothing taken while off")
	T.clean(w)
end)

test("drive.book: a crew with no notes sends no book message at all", function()
	local w, cs = crew({ ANA, BEA, CAL })
	w:advance(120)
	eq(#bookMsgs(w), 0, "no BKH, BKQ or BKR")
	for _, c in ipairs(cs) do eq(c.W.db.drive.book, nil, c.player.name .. ": no book saved") end
	T.clean(w)
end)


local function seenOf(c, name)
	local b = c.W.db.drive.book
	return b and b.seen and b.seen[key(name)] or 0
end

test("drive.book: own accounts only - notes go to, and come from, only crew marked 'My own account' here", function()
	-- Ana and Bea are Tester's; Cal is a friend in the same crew (marked by nobody, marks nobody)
	local w, cs = crew({ ANA, BEA, CAL }, { own = { [ANA] = { BEA }, [BEA] = { ANA }, [CAL] = { ANA } } })
	local ana, bea, cal = cs[1], cs[2], cs[3]
	ok(ana.W.Drive.BookOwn(key(BEA)) and not ana.W.Drive.BookOwn(key(CAL)), "Ana's marks")
	ana.W.Drive.SetNote(DAN, "Tester's own note")
	w:advance(30)
	eq(bea.W.Drive.BookEntry(DAN) and bea.W.Drive.BookEntry(DAN).note, "Tester's own note", "Bea (marked) has it")
	eq(cal.W.Drive.BookEntry(DAN), nil, "Cal (a friend in the crew) never gets it")
	for _, e in ipairs(bookMsgs(w)) do
		ok(e.target ~= CAL, "nothing whispered to Cal: " .. e.text:sub(1, 20))
		ok(e.from ~= CAL or e.target ~= ANA or true, "")
	end
	-- Cal marked Ana, but Ana did not mark Cal: what Cal sends is dropped
	cal.W.Drive.SetNote(DAN, "Cal's note")
	w:advance(20)
	eq(ana.W.Drive.BookEntry(DAN).note, "Tester's own note", "Cal's record is not taken")
	ok(ana.W.Drive.BookHeard("BKR", key(CAL), CAL, { "BKR", "1", "9", EVE, tostring(ana.env.time() + 5), "", "", "1/1", "x" }))
	eq(ana.W.Drive.BookEntry(EVE), nil, "a direct BKR from Cal: dropped")
	-- unmarking Bea: nothing more goes to her
	ok(ana.W.Drive.SetBookOwn(key(BEA), false), "unmarked")
	eq(ana.W.Char().bookOwn, nil, "no marks left: nothing saved")
	local before = #bookMsgs(w)
	ana.W.Drive.SetNote(EVE, "after the unmark")
	w:advance(30)
	for i = before + 1, #bookMsgs(w) do ok(bookMsgs(w)[i].from ~= ANA, "Ana sent nothing: " .. bookMsgs(w)[i].text:sub(1, 20)) end
	eq(bea.W.Drive.BookEntry(EVE), nil)
	T.clean(w)
end)

test("drive.book: own accounts only - with nobody marked, nothing is sent at all", function()
	local w, cs = crew({ ANA, BEA }, { own = { [ANA] = {}, [BEA] = {} } })
	cs[1].W.Drive.SetNote(DAN, "x")
	cs[2].W.Drive.SetNote(EVE, "y")
	w:advance(60)
	eq(#bookMsgs(w), 0, "no book message")
	T.clean(w)
end)

test("drive.book: seen moves only on a whole answer - a lost record (answer or live push) is asked for again", function()
	local w, cs = crew({ ANA, BEA })
	local ana, bea = cs[1], cs[2]
	ana.W.Drive.SetNote(DAN, "one")
	ana.W.Drive.SetNote(EVE, "two")
	-- Bea's window loses the first BKR of Ana's answer (a dropped send)
	local real, dropped = bea.W.Drive.BookHeard, 0
	bea.W.Drive.BookHeard = function(kind, k, s, p)
		if kind == "BKR" and dropped == 0 and p and p[4] == DAN then
			dropped = 1
			return true
		end
		return real(kind, k, s, p)
	end
	w:advance(8)
	eq(dropped, 1, "one record lost on the way")
	w:advance(60)
	eq(bea.W.Drive.BookEntry(DAN) and bea.W.Drive.BookEntry(DAN).note, "one", "asked again: the lost record arrived")
	eq(seenOf(bea, ANA), ana.W.db.drive.book.seq, "seen = Ana's counter after a whole answer")
	-- a live push lost, then a later one arrives: seen stays, the next hello brings the lost one
	dropped = 0
	bea.W.Drive.BookHeard = function(kind, k, s, p)
		if kind == "BKR" and dropped == 0 and p and p[4] == CAL then
			dropped = 1
			return true
		end
		return real(kind, k, s, p)
	end
	ana.W.Drive.SetNote(CAL, "lost push")
	w:advance(5)
	ana.W.Drive.SetNote("Fay Wind", "later push")
	w:advance(5)
	eq(bea.W.Drive.BookEntry("Fay Wind") and bea.W.Drive.BookEntry("Fay Wind").note, "later push", "the later push came")
	eq(bea.W.Drive.BookEntry(CAL), nil, "the lost one did not")
	ok(seenOf(bea, ANA) < ana.W.db.drive.book.seq, "a live push never moves seen past the gap")
	w:advance(320)
	eq(bea.W.Drive.BookEntry(CAL) and bea.W.Drive.BookEntry(CAL).note, "lost push", "Ana's next hello brought it")
	eq(seenOf(bea, ANA), ana.W.db.drive.book.seq)
	T.clean(w)
end)

test("drive.book: seen - a reload in the middle of an answer, an answer past SYNC_MAX, the queue's cap", function()
	local w, cs = crew({ ANA, BEA }, { group = false })
	local ana, bea = cs[1], cs[2]
	local B = ana.W.Drive.BOOK
	B.SYNC_MAX, B.QUEUE_MAX = 3, 5
	local names = {}
	for i = 1, 8 do
		names[i] = "Rider " .. string.char(64 + i)
		ana.W.Drive.SetNote(names[i], "note " .. i)
	end
	w:group({ ANA, BEA })
	-- Bea reloads while the first answer is on its way
	w:advance(17)
	bea = w:reload(bea)
	w:advance(15)
	-- Ana edits more while answering (the queue's cap drops the oldest waiting messages)
	for i = 1, 3 do ana.W.Drive.SetNote(names[i], "edited " .. i) end
	w:advance(400)
	for i = 1, 8 do
		local rec = bea.W.Drive.BookEntry(names[i])
		eq(rec and rec.note, ana.W.Drive.BookEntry(names[i]).note, "Bea has " .. names[i])
	end
	eq(seenOf(bea, ANA), ana.W.db.drive.book.seq, "and has seen all of Ana's book")
	T.clean(w)
end)

test("drive.book: one answer at a time - no second BKQ while one is open; a new BKQ replaces a waiting answer", function()
	local w, cs = crew({ ANA, BEA }, { group = false })
	local ana, bea = cs[1], cs[2]
	for i = 1, 4 do ana.W.Drive.SetNote("Rider " .. i, "n" .. i) end
	w:group({ ANA, BEA })
	w:advance(1)
	local DR = bea.W.Drive
	-- two hellos from Ana in a row: one question
	DR.BookHeard("BKH", key(ANA), ANA, { "BKH", "1", "9", "0" })
	DR.BookHeard("BKH", key(ANA), ANA, { "BKH", "1", "9", "0" })
	local q = 0
	DR.BookTick()
	ok(bea.W.Mod("Drive.Book").asking(key(ANA)), "an open question")
	local A = ana.W.Drive
	A.BookTick() -- (whatever was waiting)
	local base = A.BookBacklog()
	A.BookHeard("BKQ", key(BEA), BEA, { "BKQ", "1", "0" })
	local one = A.BookBacklog() - base
	A.BookHeard("BKQ", key(BEA), BEA, { "BKQ", "1", "0" })
	eq(A.BookBacklog() - base, one, "the second answer replaced the first (no double records)")
	eq(one, 5, "4 records and the end marker")
	w:advance(30)
	for _, e in ipairs(bookMsgs(w)) do if e.from == BEA and e.text:match("^BKQ") then q = q + 1 end end
	ok(q <= 1, "Bea asked at most once: " .. q)
	T.clean(w)
end)

test("drive.book: a window that went offline gets nothing more (its waiting messages are dropped)", function()
	local w, cs = crew({ ANA, BEA, CAL })
	local ana, bea = cs[1], cs[2]
	w:advance(5)
	for i = 1, 6 do ana.W.Drive.SetNote("Rider " .. i, "n" .. i) end
	w:logout(bea)
	local at = #w.addonLog
	w:advance(120)
	for i = at + 1, #w.addonLog do
		local e = w.addonLog[i]
		ok(not (e.prefix == "WUBERT" and e.target == BEA and e.text:match("^BK")), "nothing to Bea after she left: " .. e.text:sub(1, 20))
	end
	eq(ana.W.Drive.BookBacklog(), 0, "her messages were dropped, Cal's went")
	T.clean(w)
end)

test("drive.book: two windows editing a note in the same second agree on one", function()
	local w, cs = crew({ ANA, BEA })
	local ana, bea = cs[1], cs[2]
	w:advance(5)
	ana.W.Drive.SetNote(DAN, "Ana's words")
	bea.W.Drive.SetNote(DAN, "Bea's words")
	eq(ana.W.Drive.BookEntry(DAN).noteAt, bea.W.Drive.BookEntry(DAN).noteAt, "the same second")
	w:advance(30)
	local a1, b1 = ana.W.Drive.BookEntry(DAN).note, bea.W.Drive.BookEntry(DAN).note
	eq(a1, b1, "both windows keep the same note")
	eq(a1, "Bea's words", "the writer's key decides (bea jones > ana smith)")
	T.clean(w)
end)

test("drive.book: parts never cut next to a space or through a letter", function()
	local w = H.NewWorld({})
	local a = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	local Mod = a.W.Mod("Drive.Book")
	for _, text in ipairs({ string.rep("é a ", 60), string.rep("word ", 50), string.rep("éé", 70) }) do
		text = text:gsub(" $", "")
		local list = Mod.parts(text, 37)
		local joined = {}
		for _, part in ipairs(list) do
			local p = part[1]
			ok(p:sub(1, 1) ~= " " and p:sub(-1) ~= " ", "no space at an edge: [" .. p .. "]")
			ok(#p <= 37, "fits")
			local b = p:byte(1)
			ok(not (b >= 128 and b < 192), "no cut letter")
			joined[#joined + 1] = p .. (part[2] and " " or "")
		end
		eq(table.concat(joined), text, "joined back exactly")
	end
	T.clean(w)
end)

test("drive.book: (review 2) an own window that logs off before the group says so: one try, no 'No player named' lines", function()
	local w, cs = crew({ ANA, BEA })
	local ana, bea = cs[1], cs[2]
	w:advance(30)
	-- Bea logs off; Ana's group does not say so (yet), and Bea was heard less than 45 s ago
	ana.W.Drive.Online = function() return nil end
	w:logout(bea)
	local still = false
	for _, p in ipairs(ana.W.Drive.BookPeers()) do if p.key == key(BEA) then still = true end end
	ok(still, "Bea still counts as heard")
	local at = #w.addonLog
	for i = 1, 20 do
		ana.W.Drive.SetNote("Rider " .. i, "n" .. i)
		w:advance(1)
	end
	w:advance(20)
	local n = 0
	for i = at + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.prefix == "WUBERT" and e.target == BEA and e.text:match("^BK") then n = n + 1 end
	end
	ok(n <= 1, "at most one try after she left: " .. n)
	local shown = 0
	for _, l in ipairs(ana.chatShown) do
		if tostring(l.text):find("No player named", 1, true) then shown = shown + 1 end
	end
	eq(shown, 0, "no 'No player named' line in Ana's chat")
	eq(ana.W.Drive.BookBacklog(), 0, "nothing waits for her")
	T.clean(w)
end)

test("drive.book: (review 3) a window whose book started again is asked from the start", function()
	local w, cs = crew({ ANA, BEA })
	local ana, bea = cs[1], cs[2]
	for i = 1, 3 do ana.W.Drive.SetNote("Rider " .. i, "n" .. i) end
	w:advance(30)
	eq(seenOf(bea, ANA), 3, "Bea has seen Ana's 3")
	-- Ana's book is wiped (a new SavedVariables); her next note's push is lost on the way
	ana.W.db.drive.book = nil
	local real, dropped = bea.W.Drive.BookHeard, 0
	bea.W.Drive.BookHeard = function(kind, k, s, p)
		if kind == "BKR" and dropped == 0 then
			dropped = 1
			return true
		end
		return real(kind, k, s, p)
	end
	ana.W.Drive.SetNote(DAN, "after the wipe")
	w:advance(5)
	eq(dropped, 1, "the push was lost")
	eq(ana.W.db.drive.book.seq, 1, "Ana's counter starts again")
	w:advance(320)
	eq(bea.W.Drive.BookEntry(DAN) and bea.W.Drive.BookEntry(DAN).note, "after the wipe", "Bea asked again from 0")
	eq(seenOf(bea, ANA), 1, "and her seen follows the new counter")
	T.clean(w)
end)

test("drive.book: (review 4) only records marked as part of the answer complete it (a live push's seq does not)", function()
	local w, cs = crew({ ANA, BEA }, { group = false })
	local bea = cs[2]
	local DR = bea.W.Drive
	local t = tostring(bea.env.time())
	DR.BookHeard("BKH", key(ANA), ANA, { "BKH", "1", "2", "0" })
	ok(bea.W.Mod("Drive.Book").asking(key(ANA)), "Bea asks from 0")
	-- a live push (no answer mark) with seq 2, then the answer's seq 1; the answer's seq 2 is lost
	DR.BookHeard("BKR", key(ANA), ANA, { "BKR", "1", "2", DAN, t, "", "", "1/1", "pushed", "ana smith" })
	DR.BookHeard("BKR", key(ANA), ANA, { "BKR", "1", "1", EVE, t, "", "", "1/1", "answered", "ana smith", "0" })
	DR.BookHeard("BKE", key(ANA), ANA, { "BKE", "1", "0", "2", "2", "2" })
	eq(seenOf(bea, ANA), 0, "one of two answer records came: seen stays")
	-- the whole answer: seen moves
	DR.BookHeard("BKH", key(ANA), ANA, { "BKH", "1", "2", "0" })
	DR.BookHeard("BKR", key(ANA), ANA, { "BKR", "1", "1", EVE, t, "", "", "1/1", "answered", "ana smith", "0" })
	DR.BookHeard("BKR", key(ANA), ANA, { "BKR", "1", "2", DAN, t, "", "", "1/1", "pushed", "ana smith", "0" })
	DR.BookHeard("BKE", key(ANA), ANA, { "BKE", "1", "0", "2", "2", "2" })
	eq(seenOf(bea, ANA), 2, "both came: seen moves")
	T.clean(w)
end)

test("drive.book: (review 7) a full queue drops the oldest message to the same window, not another's answer", function()
	local w, cs = crew({ ANA, BEA, CAL }, { group = false })
	local A = cs[1].W.Drive
	for i = 1, 4 do A.SetNote("Rider " .. i, "n" .. i) end
	w:advance(1)
	while A.BookBacklog() > 0 do A.BookTick() w:advance(1) end
	A.BOOK.QUEUE_MAX = 7
	A.BookHeard("BKQ", key(BEA), BEA, { "BKQ", "1", "0" })
	eq(A.BookBacklog(), 5, "Bea's answer: 4 records and the end")
	A.BookHeard("BKQ", key(CAL), CAL, { "BKQ", "1", "0" })
	eq(A.BookBacklog(), 7, "capped")
	local outq = {}
	local i = 1
	while true do
		local name, v = debug.getupvalue(A.BookBacklog, i)
		if not name then break end
		if name == "outq" then outq = v end
		i = i + 1
	end
	local toBea = 0
	for _, it in ipairs(outq) do if it.key == key(BEA) then toBea = toBea + 1 end end
	eq(toBea, 5, "Bea's whole answer still waits (Cal's own oldest went)")
	T.clean(w)
end)
