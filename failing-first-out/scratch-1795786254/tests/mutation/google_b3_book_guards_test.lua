-- Tests from the Big Batch 3 mutation run: Drive/Book.lua guards.
-- Each test guards one line that no other test noticed when it was broken. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function crewKey(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function crewSaved(me, names, captain)
	local crew, marks = {}, {}
	for _, n in ipairs(names) do
		if n ~= me then
			crew[#crew + 1] = { name = n, role = "lock", app = true }
			marks[crewKey(n)] = true
		end
	end
	return { chars = { [crewKey(me)] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true, bookOwn = marks } } }
end

local function crewPair(w)
	local names = { T.ANA, T.BEA }
	local a = w:addClient(T.ANA, { spot = "Orgrimmar", class = "WARLOCK", saved = { Wuber = crewSaved(T.ANA, names, T.ANA) } })
	local b = w:addClient(T.BEA, { spot = "Orgrimmar", class = "WARLOCK", saved = { Wuber = crewSaved(T.BEA, names, T.ANA) } })
	w:group(names)
	w:advance(15)
	return a, b
end

-- guards Wuber/Drive/Book.lua:383 (delete changed = true when earlier gift stamp arrives)
test("mutation b3 book: synced earlier gift stamp bumps book sequence and notifies UI", function()
	local w = T.newWorld()
	local a, b = crewPair(w)
	a.W.Drive.SetNote("Dan Miller", "nice rider")
	local seqBefore = a.W.db.drive.book.seq
	local changed = 0
	local origChanged = a.W.Drive.Changed
	a.W.Drive.Changed = function(...) changed = changed + 1; if origChanged then return origChanged(...) end end
	local earlier = a.env.time() - 3600
	a.W.Drive.BookHeard("BKR", a.W.Key(T.BEA), T.BEA, { "BKR", "1", "1", "Dan Miller", "0", tostring(earlier), "0", "1/1", "", "Bea" })
	a.W.Drive.Changed = origChanged
	eq(a.W.Drive.BookEntry("Dan Miller").gift, earlier, "earlier gift stamp is recorded")
	ok(a.W.db.drive.book.seq > seqBefore, "book seq incremented on earlier gift stamp")
	ok(changed > 0, "Changed callback fired on earlier gift stamp")
	T.clean(w)
end)

-- guards Wuber/Drive/Book.lua:387 (delete rec.app = app in apply)
-- guards Wuber/Drive/Book.lua:388 (delete changed = true when newer app stamp arrives)
test("mutation b3 book: synced Get Wuber stamp is saved, bumps seq, and prevents duplicate whisper", function()
	local w = T.newWorld()
	local a, b = crewPair(w)
	local nowEpoch = a.env.time()
	local changed = 0
	local origChanged = a.W.Drive.Changed
	a.W.Drive.Changed = function(...) changed = changed + 1; if origChanged then return origChanged(...) end end
	a.W.Drive.BookHeard("BKR", a.W.Key(T.BEA), T.BEA, { "BKR", "1", "1", "Dan Miller", "0", "0", tostring(nowEpoch), "1/1", "", "Bea" })
	a.W.Drive.Changed = origChanged
	local rec = a.W.Drive.BookEntry("Dan Miller")
	eq(rec and rec.app, nowEpoch, "synced app stamp is stored on customer record")
	ok(a.W.db.drive.book.seq > 0, "book seq incremented on new app stamp")
	ok(changed > 0, "Changed callback fired on new app stamp")
	eq(a.W.Drive.GetAppState({ name = "Dan Miller" }), "sent", "GetAppState sees Get Wuber was already sent today")
	T.clean(w)
end)

-- guards Wuber/Drive/Book.lua:409 (delete ask[key] = nil when peer book wiped)
test("mutation b3 book: wiped crewmate book clears open sync question and asks again", function()
	local w = T.newWorld()
	local a, b = crewPair(w)
	local bk = a.W.Key(T.BEA)
	a.W.Drive.BookHeard("BKH", bk, T.BEA, { "BKH", "1", "5", "0" })
	w:advance(1)
	a.W.db.drive.book = a.W.db.drive.book or { v = 1, seq = 0, list = {}, seen = {} }
	a.W.db.drive.book.seen[bk] = 5
	local logBefore = #w.addonLog
	a.W.Drive.BookHeard("BKH", bk, T.BEA, { "BKH", "1", "2", "0" })
	w:advance(3)
	local askedAgain = false
	for i = logBefore + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.prefix == "WUBERT" and e.from == T.ANA and type(e.text) == "string" and e.text:find("BKQ~1~0", 1, true) then
			askedAgain = true
		end
	end
	ok(askedAgain, "sent a fresh BKQ~1~0 after peer book reset below seen")
	T.clean(w)
end)

-- guards Wuber/Drive/Book.lua:449 (delete ask[key] = { since = upto, ... } on paged BKE)
test("mutation b3 book: paged book sync keeps open question for remaining records", function()
	local w = T.newWorld()
	local a, b = crewPair(w)
	local bk = a.W.Key(T.BEA)
	a.W.Drive.BookHeard("BKH", bk, T.BEA, { "BKH", "1", "20", "0" })
	w:advance(1)
	a.W.Drive.BookHeard("BKE", bk, T.BEA, { "BKE", "1", "0", "10", "0", "20" })
	w:advance(1)
	a.W.Drive.BookHeard("BKE", bk, T.BEA, { "BKE", "1", "10", "20", "0", "20" })
	w:advance(1)
	eq(a.W.db.drive.book and a.W.db.drive.book.seen[bk], 20, "second page BKE was accepted and updated seen to 20")
	T.clean(w)
end)

-- guards Wuber/Drive/Book.lua:469 (delete text = table.concat(e.parts) on multi-part note)
test("mutation b3 book: multi-part synced note joins all parts in order", function()
	local w = T.newWorld()
	local a, b = crewPair(w)
	local bk = a.W.Key(T.BEA)
	local ts = tostring(a.env.time())
	a.W.Drive.BookHeard("BKR", bk, T.BEA, { "BKR", "1", "1", "Dan Miller", ts, "0", "0", "1/2+", "First part", "Bea" })
	a.W.Drive.BookHeard("BKR", bk, T.BEA, { "BKR", "1", "2", "Dan Miller", ts, "0", "0", "2/2", "second part", "Bea" })
	local rec = a.W.Drive.BookEntry("Dan Miller")
	eq(rec and rec.note, "First part second part", "both note parts were joined")
	T.clean(w)
end)

-- guards Wuber/Drive/Book.lua:510 (delete unqueue(k) on CHAT_MSG_SYSTEM not found)
test("mutation b3 book: offline crewmate system message drops queued book sync whispers", function()
	local w = T.newWorld()
	local a, b = crewPair(w)
	local bk = a.W.Key(T.BEA)
	a.W.Drive.BookHeard("BKH", bk, T.BEA, { "BKH", "1", "10", "0" })
	a.W.Drive.BookTick()
	a.W.Drive.BookHeard("BKQ", bk, T.BEA, { "BKQ", "1", "0" })
	ok(a.W.Drive.BookBacklog() > 0, "control: book whisper is queued for Bea")
	a:chatEvent("CHAT_MSG_SYSTEM", "No player named 'Bea Jones' is currently playing.")
	eq(a.W.Drive.BookBacklog(), 0, "queued book whispers for offline crewmate were dropped")
	T.clean(w)
end)

-- guards Wuber/Drive/Book.lua:631 (return nil instead of b.hold[k] in SetServeHold)
test("mutation b3 book: SetServeHold returns the hold expiry timestamp when enabled", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local untilAt = a.W.Drive.SetServeHold("Dan Miller", true)
	ok(type(untilAt) == "number" and untilAt > a.env.time(), "SetServeHold returns future expiry timestamp")
	eq(a.W.Drive.SetServeHold("Dan Miller", false), nil, "clearing hold returns nil")
	T.clean(w)
end)

-- guards Wuber/Drive/Book.lua:724 (< to >= in Customers sort tie-break)
test("mutation b3 book: Customers sorts entries sharing timestamp and lowercase name without error", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	a.W.Drive.SetNote("Dan Miller", "one")
	local b = a.W.db.drive.book
	b.list["key1"] = { name = "Same Name", note = "a" }
	b.list["key2"] = { name = "Same Name", note = "b" }
	local sorted = a.W.Drive.Customers()
	eq(#sorted, 3, "Customers lists all three entries")
	local pos = {}
	for i, item in ipairs(sorted) do pos[item.key] = i end
	ok(pos["key1"] < pos["key2"], "tied entries sort ascending by key (key1 before key2)")
	T.clean(w)
end)

-- guards Wuber/Drive/Book.lua:786 (or to and in AskGetApp(c, false))
test("mutation b3 book: cancelling Get Wuber when not queued returns false", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	eq(a.W.Drive.AskGetApp({ name = "Dan Miller" }, false), false, "AskGetApp(c, false) returns false when not queued")
	T.clean(w)
end)
