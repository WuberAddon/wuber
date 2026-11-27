-- Mutation run guards for Wuber/Drive/Mail.lua.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function setupClient()
	local w = T.newWorld()
	local c = w:addClient("Ana Smith", { spot = "Undercity", class = "WARLOCK" })
	w:advance(2)
	return w, c, c.W.Drive, c.W.Mod("Drive.Mail")
end

-- guards Wuber/Drive/Mail.lua:75 (cmp ~=->==: normal mail ignored when issecretvalue is absent)
test("mutation b2 mail: normal mail is still read when issecretvalue is not defined", function()
	local w, c, DR = setupClient()
	local orig = c.env.issecretvalue
	c.env.issecretvalue = false
	DR.MailOwes({ name = "Dan Miller", key = "dan miller" }, 5000)
	w:mail(c, { sender = "Dan Miller", money = 5000, subject = "Wuber" })
	w:openMailbox(c)
	w:advance(1)
	c.env.issecretvalue = orig
	ok(DR.MailNote("Dan Miller") ~= nil, "normal mail is noted without issecretvalue")
	T.clean(w)
end)

-- guards Wuber/Drive/Mail.lua:77 (return -> nil: secret mail header not treated as hidden)
test("mutation b2 mail: mail with a secret returned flag is ignored", function()
	local w, c, DR = setupClient()
	DR.MailOwes({ name = "Dan Miller", key = "dan miller" }, 5000)
	local origGet = c.env.GetInboxHeaderInfo
	local origNum = c.env.GetInboxNumItems
	c.env.GetInboxNumItems = function() return 1, 1 end
	c.env.GetInboxHeaderInfo = function(i)
		if i == 1 then
			return nil, nil, "Dan Miller", "Wuber", 5000, 0, 30, nil, false, T.H.SECRET, true, true, false
		end
	end
	local n = DR.MailScan()
	c.env.GetInboxNumItems, c.env.GetInboxHeaderInfo = origNum, origGet
	eq(n, 0, "mail with secret field is ignored")
	eq(DR.MailNote("Dan Miller"), nil, "secret mail produces no note")
	T.clean(w)
end)

-- guards Wuber/Drive/Mail.lua:94 (swap or->and: old mailOwed records never pruned)
test("mutation b2 mail: records older than DR.MAIL.KEEP are pruned when adding a new record", function()
	local w, c, DR = setupClient()
	local nowEpoch = c.env.time()
	c.W.db.drive.mailOwed = {
		["old rider"] = { name = "Old Rider", due = 5000, at = nowEpoch - DR.MAIL.KEEP - 10 },
	}
	DR.MailOwes({ name = "Dan Miller", key = "dan miller" }, 5000)
	eq(DR.MailRecord("Old Rider"), nil, "expired record was pruned")
	ok(DR.MailRecord("Dan Miller") ~= nil, "new record was kept")
	T.clean(w)
end)

-- guards Wuber/Drive/Mail.lua:103 (swap or->and: date error leaks error string into MailNote)
test("mutation b2 mail: date failure omits day from MailNote without error", function()
	local w, c, DR = setupClient()
	DR.MailOwes({ name = "Dan Miller", key = "dan miller" }, 5000)
	w:mail(c, { sender = "Dan Miller", money = 5000, subject = "Wuber" })
	w:openMailbox(c)
	w:advance(1)
	local origDate = c.env.date
	c.env.date = function() error("bad date") end
	local note = DR.MailNote("Dan Miller")
	c.env.date = origDate
	eq(note, "Mail seen: 50s from Dan.", "note falls back cleanly when date errors")
	T.clean(w)
end)

-- guards Wuber/Drive/Mail.lua:141 (swap and->or: missing CrewEntry causes nil index in payeeName)
test("mutation b2 mail: MailOwes falls back to peer name when CrewEntry is missing", function()
	local w, c, DR = setupClient()
	local origPayee, origCrew = DR.PayeeKey, DR.CrewEntry
	DR.PayeeKey = function() return "bea jones" end
	DR.CrewEntry = function() return nil end
	DR.peers["bea jones"] = { name = "Bea Jones" }
	local rec = DR.MailOwes({ name = "Dan Miller", key = "dan miller" }, 5000)
	DR.PayeeKey, DR.CrewEntry = origPayee, origCrew
	ok(rec ~= nil, "record created")
	eq(rec.payto, "Bea Jones", "fell back to peer name")
	T.clean(w)
end)

-- guards Wuber/Drive/Mail.lua:191 (swap and->or: zero-due mailOwed record treated as owing)
test("mutation b2 mail: record with zero due is not treated as owing on scan", function()
	local w, c, DR = setupClient()
	c.W.db.drive.mailOwed = {
		["dan miller"] = { name = "Dan Miller", due = 0, at = c.env.time() },
	}
	w:mail(c, { sender = "Dan Miller", money = 5000, subject = "Wuber" })
	w:openMailbox(c)
	w:advance(1)
	eq(DR.MailNote("Dan Miller"), nil, "zero-due rider gets no mail note")
	T.clean(w)
end)

-- guards Wuber/Drive/Mail.lua:194 (swap or->and: non-table entry in DR.owing crashes row())
test("mutation b2 mail: non-table entry in DR.owing is ignored without error", function()
	local w, c, DR = setupClient()
	DR.MailOwes({ name = "Dan Miller", key = "dan miller" }, 5000)
	local origOwing = DR.owing
	DR.owing = { { c = false, at = c.env.GetTime() } }
	local n = DR.MailScan()
	DR.owing = origOwing
	eq(n, 0, "no new mail")
	eq(#w.errors, 0, "no error on non-table owing entry")
	T.clean(w)
end)

-- Line 228 (swap or->and): skipped as unobservable; both GetInboxNumItems (line 231) and
-- GetInboxHeaderInfo (line 235) are wrapped in pcall, so missing either still returns 0 with no error.

-- guards Wuber/Drive/Mail.lua:264 (cmp >-> <=: Changed called when no new mail was found)
test("mutation b2 mail: MailScan does not call Changed when no new mail is seen", function()
	local w, c, DR = setupClient()
	DR.MailOwes({ name = "Dan Miller", key = "dan miller" }, 5000)
	local changed = 0
	local origChanged = DR.Changed
	DR.Changed = function(...)
		changed = changed + 1
		if origChanged then return origChanged(...) end
	end
	local n = DR.MailScan()
	DR.Changed = origChanged
	eq(n, 0, "no new mail seen")
	eq(changed, 0, "Changed not called when nothing new was seen")
	T.clean(w)
end)

-- guards Wuber/Drive/Mail.lua:281 (swap or->and: partial DRIVE_PAID computes negative left and deletes record)
test("mutation b2 mail: partial DRIVE_PAID reduces due instead of clearing the record", function()
	local w, c, DR = setupClient()
	DR.MailOwes({ name = "Dan Miller", key = "dan miller" }, 5000)
	c.W.Fire("DRIVE_PAID", "Dan Miller", 2000)
	local rec = DR.MailRecord("Dan Miller")
	ok(rec ~= nil, "record remains after partial payment")
	eq(rec and rec.due, 3000, "due reduced by paid amount")
	T.clean(w)
end)

-- guards Wuber/Drive/Mail.lua:282 (if cond negated: full DRIVE_PAID keeps record instead of clearing)
test("mutation b2 mail: full DRIVE_PAID removes rider from mailOwed list", function()
	local w, c, DR = setupClient()
	DR.MailOwes({ name = "Dan Miller", key = "dan miller" }, 5000)
	c.W.Fire("DRIVE_PAID", "Dan Miller", 5000)
	eq(DR.MailRecord("Dan Miller"), nil, "record cleared after full payment")
	T.clean(w)
end)

-- guards Wuber/Drive/Mail.lua:284 (drop statement: DRIVE_PAID leaves mailpay whisper offer queued)
test("mutation b2 mail: full DRIVE_PAID clears pending mailpay whisper offer", function()
	local w, c, DR = setupClient()
	DR.MailOwes({ name = "Dan Miller", key = "dan miller" }, 5000)
	c.W.Fire("DRIVE_PAID", "Dan Miller", 5000)
	local out = {}
	DR.MailOwed(out)
	eq(#out, 0, "no mailpay whisper owed after paying")
	T.clean(w)
end)

-- guards Wuber/Drive/Mail.lua:286 (drop statement: partial DRIVE_PAID leaves rec.due unchanged)
test("mutation b2 mail: partial DRIVE_PAID updates rec.due to remaining balance", function()
	local w, c, DR = setupClient()
	DR.MailOwes({ name = "Dan Miller", key = "dan miller" }, 5000)
	c.W.Fire("DRIVE_PAID", "Dan Miller", 1500)
	local rec = DR.MailRecord("Dan Miller")
	eq(rec and rec.due, 3500, "rec.due updated to 3500")
	T.clean(w)
end)

-- guards Wuber/Drive/Mail.lua:302 (drop statement: expired or sent offers never removed from Offers)
test("mutation b2 mail: MailOwed removes sent offers from Mod.Offers", function()
	local w, c, DR, Mail = setupClient()
	DR.MailOwes({ name = "Dan Miller", key = "dan miller" }, 5000)
	local out = {}
	DR.MailOwed(out)
	eq(#out, 1, "one offer queued")
	DR.MailSent(out[1].c)
	local out2 = {}
	DR.MailOwed(out2)
	eq(#out2, 0, "no offer queued after sent")
	eq(Mail.Offers()["dan miller"], nil, "sent offer was removed")
	T.clean(w)
end)

-- guards Wuber/Drive/Mail.lua:308 (cmp ~=->==: MailOwed sorts by key instead of oldest-first)
test("mutation b2 mail: MailOwed orders offers oldest-first when timestamps differ", function()
	local w, c, DR = setupClient()
	DR.MailOwes({ name = "Zed Alpha", key = "zed alpha" }, 5000)
	w:advance(5)
	DR.MailOwes({ name = "Amy Beta", key = "amy beta" }, 5000)
	local out = {}
	DR.MailOwed(out)
	eq(#out, 2, "both offers returned")
	eq(out[1].c.key, "zed alpha", "earlier offer comes first despite key order")
	eq(out[2].c.key, "amy beta", "later offer comes second")
	T.clean(w)
end)
