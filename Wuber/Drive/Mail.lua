-- Module: Drive.Mail
-- Purpose: payment by mail, as an after-the-ride option only (the author's decision of 21 Nov 2026). Wuber
--   prepares and explains; the player sends the mail himself. The rider is told what to do ("Send 5g to
--   Anita Lift by mail, subject Wuber."; on his own Done screen after "Still owe the fare?"); at an open
--   mailbox the driver's Wuber READS the inbox headers and notes a mail with money from a rider who still
--   owes ("Mail seen: 5g from Dan, 21 Nov."). A mail never makes a ride paid: the driver still clicks Mark
--   as paid (DR.MarkPaid, by hand, so no raincheck).
-- API: DR.MAIL, DR.MailLine, DR.MailOwes, DR.MailRecord, DR.MailList, DR.MailNote, DR.MailScan, DR.MailOwed,
--   DR.MailSent;
--   Mod.Line (the sentence, for the rider's Done screen), Mod.RiderLine (the sentence for a ride that ended
--   unpaid after arriving, or nil), Mod.Offers (the whispers this window still owes, for tests)
-- Internals: owed (W.db.drive.mailOwed, made the first time something is written), offers (this session's
--   "you can still pay by mail" whispers, never saved), owing (who still owes: the records and the rows),
--   match (a mail's sender against them), hidden (a secret value), payeeName, prune (records older than
--   DR.MAIL.KEEP go), dayText
-- Uses: (none)
-- Later: (none) (Drive.Core, Drive.Queue, Drive.Chat and Drive.Ready load earlier: reached through DR at run
--   time: DR.Due, DR.customers, DR.owing, DR.PayeeKey, DR.CrewEntry, DR.peers, DR.ChatMode, DR.Alert, DR.Changed)
-- Events: listens On MAIL_SHOW, On MAIL_INBOX_UPDATE (reads the headers, nothing else), Listen DRIVE_PAID (a
--   rider who pays after all is off the list); Drive.Ready's DR.NonPayer calls DR.MailOwes; Drive.Chat's
--   DR.Pending / DR.MarkSent call DR.MailOwed / DR.MailSent; fires DRIVE_ALERT (through DR.Alert: the note)
-- Standalone: no
-- Test: tests/dec/dec_q_mail_test.lua
-- From: new in Wuber 2.4 (decisions round, group Q; PLANS-2.4-LESSONS Plan 4)
--
-- The honest limits (they are why nothing here ever says "paid"):
--   A mail has no "both accepted" moment as a trade has. Wuber can know that a mail from this player with
--   this much money lies in this character's mailbox. It can't know that the mail is for this ride, that it
--   will not be sent back, or that a mail from another character is the rider's. So a mail only adds a note;
--   the fare is settled by the driver's own click, as before.
--   Wuber never opens the mail window, never fills a field of it, never sets its money box, never sends a
--   mail and never takes anything out of one: those calls are on tools/forbidden.lua (check.lua and the
--   tests refuse them). The only mail functions named here are the two that read the inbox list.
--   Every header value is tested for a secret value first; a mail with any secret field is ignored whole.
--
-- The list is the driver's own: W.db.drive.mailOwed[rider key] = { name, due (copper), at (epoch), payto (who
-- the rider was told to mail), told (epoch the whisper went), row (true: noted while still on a row),
-- seen = { copper, at } (the money in mails from them at this mailbox, and the day it was first seen) }.
-- A record goes after DR.MAIL.KEEP (30 days: a mail waits that long), or when the rider pays after all.

local _, W = ...
local Mod = W.Module("Drive.Mail", {})
W.Drive = W.Drive or {}
local DR = W.Drive

local S, N = W.Str, W.Num

local MAIL = {
	KEEP = 30 * 86400, -- a record lives as long as a mail waits in a mailbox
	OFFER = 600,       -- the whisper is owed this long after the rider left; then it is dropped unsent
	MOST = 100,        -- headers read at one mailbox visit
	SUBJECT = "Wuber", -- the subject the rider is asked to write
}
DR.MAIL = MAIL

local offers = {} -- [rider key] = { name, key, price (what is owed), paid = 0, payto, at }: whispers owed
function Mod.Offers() return offers end

local function stamp() return (type(time) == "function" and time()) or 0 end
local function now() return (type(GetTime) == "function" and GetTime()) or 0 end

local function call(name, ...)
	local fn = DR[name]
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if not ok then
		W.Error("drive mail " .. name, a)
		return nil
	end
	return a, b
end

-- even comparing a secret value is an error: asked first, and a secret is unknown
local function hidden(v)
	if type(issecretvalue) ~= "function" then return false end
	local ok, is = pcall(issecretvalue, v)
	return not ok or is == true
end

local function owed(make)
	local db = W.db
	local d = type(db) == "table" and db.drive or nil
	if type(d) ~= "table" then return nil end
	if type(d.mailOwed) ~= "table" then
		if not make then return nil end
		d.mailOwed = {}
	end
	return d.mailOwed
end

local function prune(list)
	local t = stamp()
	for k, rec in pairs(list) do
		if type(rec) ~= "table" or t - (N(rec.at) or 0) > MAIL.KEEP then list[k] = nil end
	end
end

-- "21 Nov" (an epoch), or nil
local function dayText(t)
	t = N(t)
	if not t or type(date) ~= "function" then return nil end
	local ok, s = pcall(date, "%d %b", t)
	if not ok or type(s) ~= "string" then return nil end
	return (s:gsub("^0", ""))
end

---------------------------------------------------------------------------
-- What the rider is told
---------------------------------------------------------------------------

-- "Send 5g to Anita Lift by mail, subject Wuber." The whole name: a mail needs it exactly. nil without an
-- amount or a name (never "free", never a guess).
function Mod.Line(copper, to)
	copper, to = N(copper), S(to)
	if not copper or copper < 1 or not to then return nil end
	return "Send " .. W.Money(copper) .. " to " .. W.Clean(to, 40) .. " by mail, subject " .. MAIL.SUBJECT .. "."
end
DR.MailLine = Mod.Line

-- The rider's own ride (W.ride), ended unpaid after arriving: "Still owe the fare? Send 5g to Anita Lift by mail,
-- subject Wuber.", else nil. A question first: an unpaid end can also be a fare paid another way or waived
-- (W.EndRide), and Wuber can't tell which.
function Mod.RiderLine(r)
	if type(r) ~= "table" or W.Plain(r.unpaid) ~= true then return nil end
	if not N(r.arrivedAt) and W.Plain(r.arrived) ~= true then return nil end
	local due = (N(r.price) or 0) - (N(r.paidSoFar) or 0)
	-- (r.payee is the whole name of who is paid; r.payto is only its first name, for the screens)
	local line = Mod.Line(due, S(r.payee) or S(r.driver))
	return line and ("Still owe the fare? " .. line) or nil
end

---------------------------------------------------------------------------
-- The driver's list of riders who left owing
---------------------------------------------------------------------------

-- the whole name of who the rider pays: the crew member who cast them, else this character
local function payeeName(c)
	local k = call("PayeeKey", c)
	if type(k) == "string" and k ~= W.myKey then
		local m = call("CrewEntry", k)
		if type(m) == "table" and S(m.name) then return m.name end
		local peer = type(DR.peers) == "table" and DR.peers[k] or nil
		if type(peer) == "table" and S(peer.name) then return peer.name end
	end
	return W.Me()
end

-- (Drive.Ready's DR.NonPayer) rider c left owing `due`: on the list, and "you can still pay by mail" is one
-- of the whispers this window owes (DR.Pending: only the driver's click sends it).
function DR.MailOwes(c, due)
	if type(c) ~= "table" or not S(c.name) then return nil end
	due = N(due) or 0
	local key = S(c.key) or W.Key(c.name)
	local list = owed(true)
	if due < 1 or not key or not list then return nil end
	prune(list)
	local to = payeeName(c)
	local was = type(list[key]) == "table" and list[key] or nil
	list[key] = { name = c.name, due = due, at = stamp(), payto = to, seen = was and was.seen or nil }
	offers[key] = { name = c.name, key = key, price = due, paid = 0, payto = to, at = now() }
	call("Changed")
	return list[key]
end

-- the whole list ([rider key] = record), for the customer book; never nil
function DR.MailList() return owed(false) or {} end

function DR.MailRecord(name)
	local key = S(name) and W.Key(name)
	local list = owed(false)
	local rec = key and list and list[key]
	return type(rec) == "table" and rec or nil
end

-- "Mail seen: 5g from Dan, 21 Nov." for a rider whose mail was seen, else nil. It says what was seen and
-- when, never that anything is paid.
function DR.MailNote(name)
	local rec = DR.MailRecord(name)
	local seen = rec and type(rec.seen) == "table" and rec.seen or nil
	local copper = seen and N(seen.copper) or 0
	if copper < 1 then return nil end
	local day = dayText(seen.at)
	return "Mail seen: " .. W.Money(copper) .. " from " .. W.Short(S(rec.name) or name) .. (day and (", " .. day) or "") .. "."
end

-- everyone who still owes: [key] = { name, due, rec (the record, if any) }: the records (left owing), the
-- riders decided in a moment (DR.owing) and the rows (arrived, not paid)
local function owing()
	local out = {}
	for k, rec in pairs(owed(false) or {}) do
		if type(rec) == "table" and S(rec.name) and (N(rec.due) or 0) > 0 then out[k] = { name = rec.name, due = rec.due, rec = rec } end
	end
	local function row(c)
		if type(c) ~= "table" or not S(c.name) or not S(c.key) or out[c.key] then return end
		local due = N(call("Due", c)) or 0
		if due > 0 then out[c.key] = { name = c.name, due = due } end
	end
	for _, c in pairs(type(DR.customers) == "table" and DR.customers or {}) do
		if type(c) == "table" and c.state == "arrived" then row(c) end
	end
	for _, e in pairs(type(DR.owing) == "table" and DR.owing or {}) do
		if type(e) == "table" then row(e.c) end
	end
	return out
end

-- the key of the rider a mail's sender is: the whole name; a first name alone only when exactly one rider
-- who owes has it (never a guess between two)
local function match(who, sender)
	local key = W.Key(sender)
	if not key then return nil end
	if who[key] then return key end
	if key:find(" ", 1, true) then return nil end
	local found
	for k in pairs(who) do
		if k:match("^(%S+)") == key then
			if found then return nil end
			found = k
		end
	end
	return found
end

-- Reads the open mailbox's headers (nothing is opened, taken or changed). A mail counts when it carries
-- money, is no cash-on-delivery mail, was not sent back, is not from a game master, and its sender is a
-- rider who still owes. Returns how many riders' notes are new or grew.
function DR.MailScan()
	if type(GetInboxNumItems) ~= "function" or type(GetInboxHeaderInfo) ~= "function" then return 0 end
	local who = owing()
	if next(who) == nil then return 0 end
	local okN, n = pcall(GetInboxNumItems)
	n = okN and N(n) or 0
	local sums = {}
	for i = 1, math.min(n, MAIL.MOST) do
		local ok, _, _, sender, _, money, cod, _, _, _, returned, _, _, gm = pcall(GetInboxHeaderInfo, i)
		if ok and not (hidden(sender) or hidden(money) or hidden(cod) or hidden(returned) or hidden(gm)) then
			sender, money, cod = S(sender), N(money) or 0, N(cod) or 0
			if sender and money > 0 and cod <= 0 and returned ~= true and gm ~= true then
				local key = match(who, sender)
				if key then sums[key] = (sums[key] or 0) + money end
			end
		end
	end
	local new = 0
	for key, sum in pairs(sums) do
		local e = who[key]
		local rec = e.rec
		if not rec then
			-- still on a row (or left a moment ago): the note needs a record to live in
			local list = owed(true)
			if list then
				rec = { name = e.name, due = e.due, at = stamp(), row = true }
				list[key] = rec
			end
		end
		local seen = rec and type(rec.seen) == "table" and rec.seen or nil
		if rec and (not seen or sum > (N(seen.copper) or 0)) then
			rec.seen = { copper = sum, at = seen and N(seen.at) or stamp() }
			new = new + 1
			local note = DR.MailNote(rec.name)
			if note then call("Alert", note, "info") end
		end
	end
	if new > 0 then call("Changed") end
	return new
end

W.On("MAIL_SHOW", function() DR.MailScan() end)
W.On("MAIL_INBOX_UPDATE", function() DR.MailScan() end)

-- A rider who pays after all (a trade, or the driver's Mark as paid) is off the list; part of it lowers
-- what they owe. The mail itself never comes here: nothing in this file fires DRIVE_PAID.
W.Listen("DRIVE_PAID", function(name, copper, _, _, _, how)
	local key = S(name) and W.Key(name)
	local list = owed(false)
	local rec = key and list and list[key]
	if type(rec) ~= "table" then
		if key then offers[key] = nil end
		return
	end
	local left = (N(rec.due) or 0) - (N(copper) or 0)
	if how == "m" or left < 1 then
		list[key] = nil
		offers[key] = nil
	else
		rec.due = left
		if offers[key] then offers[key].price = left end
	end
end)

---------------------------------------------------------------------------
-- "You can still pay by mail": one of the whispers this window owes
---------------------------------------------------------------------------

-- (Drive.Chat's DR.Pending) adds { c, kind = "mailpay" } for each rider who left owing a moment ago and
-- was not told yet. Only the big button's click (or the chat box and the driver's Enter) sends it.
function DR.MailOwed(out)
	if type(out) ~= "table" or call("ChatMode") == "off" then return end
	local t, list = now(), {}
	for k, e in pairs(offers) do
		if e.told or t - (e.at or 0) > MAIL.OFFER then
			offers[k] = nil
		else
			list[#list + 1] = e
		end
	end
	table.sort(list, function(a, b)
		if a.at ~= b.at then return a.at < b.at end
		return a.key < b.key
	end)
	for _, e in ipairs(list) do out[#out + 1] = { c = e, kind = "mailpay" } end
end

-- (Drive.Chat's DR.MarkSent) the whisper went out (or was skipped): not owed again.
function DR.MailSent(c)
	if type(c) ~= "table" then return end
	c.told = true
	local rec = c.key and DR.MailRecord(c.name)
	if rec then rec.told = stamp() end
end
