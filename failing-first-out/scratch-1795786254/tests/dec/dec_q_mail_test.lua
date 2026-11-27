-- Decisions round, group Q: payment by mail (Drive.Mail). Wuber prepares and explains; the player sends the mail
-- himself. The driver's Wuber only READS the inbox headers at an open mailbox and notes a mail with money from a
-- rider who still owes ("Mail seen: 5g from Dan, 21 Nov."); a mail never makes a ride paid. The rider is told what
-- to do in plain words, on his own Done screen and by a whisper only the driver's click sends.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local ANA, BEA, CAL, DAN = "Ana Smith", "Bea Jones", "Cal Brown", "Dan Miller"
local SPOT = "Undercity"

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function crewSaved(me, names, captain)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end
	end
	return { chars = { [key(me)] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true } } }
end

-- Three Warlocks (Ana leads and is the captain), the crew agreed, grouped, open (as tests/round4.lua's team).
local function team()
	local w = H.NewWorld({})
	local names = { ANA, BEA, CAL }
	local cs = {}
	for i, n in ipairs(names) do
		cs[i] = w:addClient(n, { spot = SPOT, class = "WARLOCK", saved = { Wuber = crewSaved(n, names, ANA) } })
	end
	w:group(names)
	w:advance(1)
	cs[1].W.Drive.SetOpen(true)
	w:advance(2)
	return w, cs[1], cs[2], cs[3]
end

local function press(c)
	local b = c.env.WuberDriveButton
	ok(b and H.visible(b), c.player.name .. ": the big button shows")
	return c:click(b)
end

-- Dan asks, is summoned, lands and walks out without paying; Ana's window decides it after the grace.
local function walkOut(w, ana, bea, cal)
	if not w:player(DAN) then w:addBot(DAN) end
	w:botWhisper(DAN, ana, "summon pls")
	w:advance(3)
	press(ana)
	w:advance(3)
	ok(w:clickPortal(bea), "the first helper clicks the portal")
	ok(w:clickPortal(cal), "the second helper clicks the portal")
	w:advance(1.5)
	w:advance(8)
	w:tradeCancel(w:player(DAN))
	w:leave(DAN)
	w:advance(3 + ana.W.Drive.OWING_GRACE)
end

local function fired(c, name)
	local n, last = 0, nil
	for _, f in ipairs(c.fired) do
		if f.name == name then n, last = n + 1, f.args end
	end
	return n, last
end

local function mailWhispers(w)
	local n = 0
	for _, x in ipairs(w:whispersTo(DAN)) do
		if tostring(x.text or x.msg or ""):find("by mail", 1, true) then n = n + 1 end
	end
	return n
end

local function day(c)
	return (c.env.date("%d %b", c.env.time()):gsub("^0", ""))
end

local WRITES = { "SetSendMailMoney", "SetSendMailCOD", "SendMail", "ClickSendMailItemButton", "TakeInboxMoney", "TakeInboxItem",
	"AutoLootMailItem", "ReturnInboxItem", "DeleteInboxItem" }

test("dec q: the calls that fill, send or empty a mail are on the forbidden list: the fake game raises on each, and check.lua refuses the names", function()
	local w = T.newWorld()
	local c = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	w:advance(2)
	for _, name in ipairs(WRITES) do
		local fn = c.env[name]
		eq(type(fn), "function", name .. " is there to be refused")
		local okc, err = pcall(fn or error, 1, 50000)
		ok(not okc and tostring(err):find("ADDON_ACTION_FORBIDDEN", 1, true), name .. " raises: " .. tostring(err))
	end
	eq(#H.forbiddenLeft(), #WRITES, "each one is a violation that would fail a test")
	w.violations = {}
	-- the reading calls are not refused
	eq(c.env.GetInboxNumItems(), 0, "the inbox can be counted (closed: 0)")
	-- check.lua: the names fail in addon code; Wuber's mail module names none of them
	local root = T.dir .. "/.."
	local list = T.CHECK.readForbidden(root)
	for _, name in ipairs(WRITES) do
		eq(#T.CHECK.scanForbidden("local function f() " .. name .. "(1) end", list), 1, "check.lua refuses " .. name)
	end
	local src = T.readFile(root .. "/Wuber/Drive/Mail.lua")
	ok(src and #src > 1000, "the mail module's source")
	eq(#T.CHECK.scanForbidden(src, list), 0, "Drive.Mail names no forbidden call")
	for _, word in ipairs({ "MailFrame", "SendMailNameEditBox", "SendMailMoney", "MoneyInputFrame", "ShowUIPanel", "OpenMail" }) do
		ok(not src:find(word, 1, true), "Drive.Mail never touches the mail window (" .. word .. ")")
	end
	T.clean(w)
end)

test("dec q: a rider who walks out owing is on the mail list; \"you can still pay by mail\" names the real amount and the real driver and goes only with the driver's click", function()
	local w, ana, bea, cal = team()
	walkOut(w, ana, bea, cal)
	local DR = ana.W.Drive
	ok(DR.BlockEntry("dan miller"), "blocked as before")
	local rec = DR.MailRecord(DAN)
	ok(rec, "on the mail list")
	eq(rec.due, 5000, "what he owes")
	eq(rec.payto, ANA, "who he was summoned by, the whole name")
	eq(DR.MailNote(DAN), nil, "no note without a mail")
	-- the whisper is owed, not sent
	local owedKind
	for _, p in ipairs(DR.Pending()) do
		if p.kind == "mailpay" then owedKind = p end
	end
	ok(owedKind, "one of the whispers this window owes")
	eq(DR.Text("mailpay", owedKind.c), "You can still pay by mail, Dan: send 50s to Ana Smith by mail, subject Wuber.", "the line")
	eq(mailWhispers(w), 0, "nothing is whispered by itself")
	w:advance(20)
	eq(mailWhispers(w), 0, "nor later, without a click")
	local p = DR.Plan()
	ok(p.macrotext and p.macrotext:find("/w Dan-Miller You can still pay by mail, Dan: send 50s to Ana Smith by mail, subject Wuber.", 1, true),
		"the big button's click carries it: " .. tostring(p.macrotext))
	ok(tostring(p.say):find("how to pay by mail", 1, true), "the button says what the click does: " .. tostring(p.say))
	press(ana)
	w:advance(1)
	eq(mailWhispers(w), 1, "the driver's click sent it once")
	press(ana)
	w:advance(1)
	eq(mailWhispers(w), 1, "not sent again")
	for _, q in ipairs(DR.Pending()) do ok(q.kind ~= "mailpay", "no longer owed") end
	-- the other windows did not decide it: they owe no whisper
	for _, q in ipairs(bea.W.Drive.Pending()) do ok(q.kind ~= "mailpay", "one window only") end
	T.clean(w)
end)

test("dec q: a mail with money from a rider who left owing adds a note and an alert; it never unblocks, never pays, never says paid", function()
	local w, ana, bea, cal = team()
	walkOut(w, ana, bea, cal)
	local DR = ana.W.Drive
	local rides, copper = DR.session.rides, DR.session.copper
	local paidBefore, alertsBefore = fired(ana, "DRIVE_PAID"), fired(ana, "DRIVE_ALERT")
	w:mail(ana, { sender = DAN, money = 5000, subject = "Wuber" })
	w:advance(2)
	eq(DR.MailNote(DAN), nil, "a mail is only seen at an open mailbox")
	w:openMailbox(ana)
	w:advance(1)
	local want = "Mail seen: 50s from Dan, " .. day(ana) .. "."
	eq(DR.MailNote(DAN), want, "the note")
	local n, args = fired(ana, "DRIVE_ALERT")
	eq(n, alertsBefore + 1, "the driver is told once")
	eq(args[1], want, "in the same words")
	w:closeMailbox(ana)
	w:openMailbox(ana)
	w:advance(1)
	eq(fired(ana, "DRIVE_ALERT"), alertsBefore + 1, "the same mail is not told twice")
	-- nothing was paid by it
	eq(fired(ana, "DRIVE_PAID"), paidBefore, "no payment was recorded")
	eq(DR.session.rides, rides, "no ride counted")
	eq(DR.session.copper, copper, "no money counted")
	ok(DR.BlockEntry("dan miller"), "still blocked: the driver decides")
	eq(DR.MailRecord(DAN).due, 5000, "still owing on the list")
	ok(not want:lower():find("paid", 1, true), "the note never says paid")
	-- the customer book lists him for the note alone, and his row would show it
	local found
	for _, e in ipairs(DR.Customers()) do
		if e.key == "dan miller" then found = e end
	end
	ok(found and found.mail == want, "the Customers list carries the note")
	local lines = {}
	ana.W.Driver.CustomerTip({ name = DAN, key = "dan miller" }, lines)
	ok(table.concat(lines, "\n"):find(want, 1, true), "a row's tooltip carries the note")
	-- the other crew windows read nothing: the mail lies in Ana's mailbox
	eq(bea.W.Drive.MailNote(DAN), nil, "another window has no note")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)

test("dec q: a mail from a stranger, without money, cash on delivery, sent back or from a game master is ignored; a first name alone counts only for one rider", function()
	local w = T.newWorld()
	local c = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	w:advance(2)
	local DR = c.W.Drive
	DR.MailOwes({ name = DAN, key = "dan miller", price = 50000, paid = 0 }, 50000)
	w:mail(c, { sender = "Eve Long", money = 50000, subject = "Wuber" }) -- a stranger
	w:mail(c, { sender = DAN, money = 0, subject = "hello" }) -- no money
	w:mail(c, { sender = DAN, money = 0, cod = 50000, subject = "pay me" }) -- cash on delivery
	w:mail(c, { sender = DAN, money = 50000, returned = true }) -- the driver's own mail, sent back
	w:mail(c, { sender = DAN, money = 50000, gm = true })
	w:openMailbox(c)
	w:advance(1)
	eq(DR.MailNote(DAN), nil, "none of them is his payment")
	eq(DR.MailNote("Eve Long"), nil, "a stranger gets no note")
	eq(DR.MailRecord("Eve Long"), nil, "and no record")
	eq(fired(c, "DRIVE_ALERT"), 0, "nothing is told")
	-- two mails with money from him: the note says their sum
	w:mail(c, { sender = DAN, money = 30000 })
	w:mail(c, { sender = "Dan", money = 20000 }) -- the sender shown by first name only
	w:advance(1)
	eq(DR.MailNote(DAN), "Mail seen: 5g from Dan, " .. day(c) .. ".", "the money of his mails")
	-- a first name two riders share is nobody's
	w:clearMail(c)
	DR.MailOwes({ name = "Fay Stone", key = "fay stone", price = 10000, paid = 0 }, 10000)
	DR.MailOwes({ name = "Fay Brook", key = "fay brook", price = 10000, paid = 0 }, 10000)
	w:mail(c, { sender = "Fay", money = 10000 })
	w:advance(1)
	eq(DR.MailNote("Fay Stone"), nil, "never a guess between two")
	eq(DR.MailNote("Fay Brook"), nil)
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)

test("dec q: a rider who does not owe gets no note; one still on a row who owes does, and stays unpaid until the driver marks it by hand", function()
	local w, ana, bea, cal = team()
	local DR = ana.W.Drive
	-- Dan asks, is summoned and lands; the trade is closed without a payment; he stays in the group
	w:addBot(DAN)
	w:botWhisper(DAN, ana, "summon pls")
	w:advance(3)
	press(ana)
	w:advance(3)
	ok(w:clickPortal(bea), "the first helper clicks the portal")
	ok(w:clickPortal(cal), "the second helper clicks the portal")
	w:advance(1.5)
	w:advance(8)
	w:tradeCancel(w:player(DAN))
	w:advance(1)
	local owes = DR.customers["dan miller"]
	ok(owes, "Dan has a row")
	eq(owes.state, "arrived", "he is here and has not paid")
	eq(DR.Due(owes), 5000, "the fare is due")
	local paidBefore = fired(ana, "DRIVE_PAID")
	w:mail(ana, { sender = DAN, money = 5000, subject = "Wuber" })
	w:mail(ana, { sender = BEA, money = 70000, subject = "a gift" }) -- somebody who owes nothing
	w:openMailbox(ana)
	w:advance(1)
	eq(DR.MailNote(BEA), nil, "somebody who owes nothing: their mail is their own business")
	eq(DR.MailRecord(BEA), nil)
	local want = "Mail seen: 50s from Dan, " .. day(ana) .. "."
	eq(DR.MailNote(DAN), want, "the rider who owes")
	local lines = {}
	ana.W.Driver.CustomerTip(owes, lines)
	ok(table.concat(lines, "\n"):find(want, 1, true), "his row's tooltip carries the note")
	-- never auto-paid
	w:advance(5)
	eq(owes.state, "arrived", "the row is still unpaid")
	eq(owes.paid or 0, 0, "nothing was counted as paid")
	eq(DR.Due(owes), 5000, "the fare is still due")
	eq(fired(ana, "DRIVE_PAID"), paidBefore, "no payment was recorded")
	-- the driver's own click settles it, by hand (so no raincheck, as before)
	DR.MarkPaid(owes)
	w:advance(1)
	local n, args = fired(ana, "DRIVE_PAID")
	eq(n, paidBefore + 1, "Mark as paid is the payment")
	eq(args[6], "m", "by hand")
	ok(DR.Rank(owes.state) >= DR.RANK.paid, "the row is paid now: " .. tostring(owes.state))
	eq(DR.MailRecord(DAN), nil, "and he is off the mail list")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)

test("dec q: a mail whose header is secret is ignored whole, without an error", function()
	local w = T.newWorld()
	local c = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	w:advance(2)
	local DR = c.W.Drive
	DR.MailOwes({ name = DAN, key = "dan miller", price = 50000, paid = 0 }, 50000)
	w:mail(c, { sender = DAN, money = 50000, secret = true })
	w:openMailbox(c)
	w:advance(1)
	eq(#w.errors, 0, "no error: " .. table.concat(w.errors, "\n"))
	eq(DR.MailNote(DAN), nil, "a secret mail is unknown, never a note")
	eq(DR.MailScan(), 0, "nothing new")
	-- a readable one beside it still counts
	w:mail(c, { sender = DAN, money = 20000 })
	w:advance(1)
	eq(DR.MailNote(DAN), "Mail seen: 2g from Dan, " .. day(c) .. ".", "only the readable mail")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)

test("dec q: the rider's Done screen, after a ride that ended unpaid, says what to send, to whom and how; a paid ride and one that never arrived say nothing of mail", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar", screenW = 1024, screenH = 768 })
	T.settle(w)
	T.goOnline(d) w:advance(5)
	r.W.db.coach = true
	r.W.UI.Toggle(true) w:advance(2.5)
	local Mail = r.W.Mod("Drive.Mail")
	local function ride(extra)
		local x = { id = "decq", driver = "Mia Runner", driverKey = "mia runner", dest = "Undercity", price = 50000, state = "done",
			at = r.env.GetTime(), service = "Mia's Rides", arrivedAt = r.env.time() }
		for k, v in pairs(extra or {}) do x[k] = v end
		return x
	end
	eq(Mail.RiderLine(ride({ unpaid = true })), "Still owe the fare? Send 5g to Mia Runner by mail, subject Wuber.", "the real amount and the real driver")
	eq(Mail.RiderLine(ride({ unpaid = true, paidSoFar = 20000 })), "Still owe the fare? Send 3g to Mia Runner by mail, subject Wuber.", "what is still owed")
	eq(Mail.RiderLine(ride({ unpaid = true, payee = "Bea Jones" })), "Still owe the fare? Send 5g to Bea Jones by mail, subject Wuber.", "who was to be paid")
	eq(Mail.RiderLine(ride({ paid = 50000 })), nil, "a paid ride")
	local never = ride({ unpaid = true })
	never.arrivedAt = nil
	eq(Mail.RiderLine(never), nil, "a ride that never arrived owes nothing")
	eq(Mail.RiderLine(ride({ unpaid = true, price = 0 })), nil, "nothing owed, nothing to send")
	eq(Mail.Line(0, "Mia Runner"), nil)
	eq(Mail.Line(50000, nil), nil)
	-- on the screen
	r.W.ride = ride({ unpaid = true })
	r.W.Fire("RIDE")
	w:advance(1)
	r.W.UI.Show("done") w:advance(3)
	local scr = r.W.UI.state.screens.done
	eq(scr.title:GetText(), "Ride ended")
	ok(H.visible(scr.unpaidText), "the unpaid card's words show")
	local text = scr.unpaidText:GetText() or ""
	ok(text:find("Still owe the fare? Send 5g to Mia Runner by mail, subject Wuber.", 1, true), "the card says it: " .. text)
	ok(text:find("Drivers can block riders who don't pay.", 1, true), "the old words stay")
	-- every word inside its card
	local card, words = H.rect(scr.unpaidText:GetParent()), H.rect(scr.unpaidText)
	ok(words.b >= card.b - 0.5 and words.b + words.h <= card.b + card.h + 0.5, "the words end inside the card")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)

test("dec q: none of the new words claims proof or a payment made, or that one click pays", function()
	local w = T.newWorld()
	local c = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	w:advance(2)
	local DR = c.W.Drive
	local Cast = c.W.Mod("Drive.Cast")
	DR.MailOwes({ name = DAN, key = "dan miller", price = 50000, paid = 0 }, 50000)
	w:mail(c, { sender = DAN, money = 50000 })
	w:openMailbox(c)
	w:advance(1)
	local Mail = c.W.Mod("Drive.Mail")
	local words = { DR.TEMPLATES.mailpay, DR.MailLine(50000, ANA), DR.MailNote(DAN), Cast.SAY.mailpay, Cast.VERB.mailpay,
		Mail.RiderLine({ unpaid = true, arrivedAt = 1, price = 50000, driver = ANA }) }
	eq(#words, 6, "all six lines are there")
	for _, s in ipairs(words) do
		local l = s:lower()
		for _, bad in ipairs({ "paid", "proof", "proved", "received", "confirmed", "one click", "one tap", "free", "guarantee", "done" }) do
			ok(not l:find(bad, 1, true), "\"" .. s .. "\" does not say " .. bad)
		end
	end
	-- the whisper is not one a driver edits (no new control), and with whispers off it is never owed
	for _, k in ipairs(DR.TEMPLATE_ORDER) do ok(k ~= "mailpay", "not in the Messages list") end
	DR.opts().whisperMode = "off"
	for _, q in ipairs(DR.Pending()) do ok(q.kind ~= "mailpay", "whispers off: not owed") end
	w.violations = w.violations
	T.clean(w)
end)
