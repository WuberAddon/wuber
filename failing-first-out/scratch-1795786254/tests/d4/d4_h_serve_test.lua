-- Design round 4, group H: "Don't serve again until <date>" on a customer who left owing (UI.Driver.Customers, Drive.Book).
-- A local, private hold: the pill shows only (Advanced) for a rider who left owing; set, it is 30 days on and a click lifts it;
-- while it holds, Wuber does not invite or answer the rider by itself but their request stays on the list; it ends on its date;
-- and nothing it does ever leaves the client.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local DAY = 86400
local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end

local function invitesTo(w, name)
	local n, k = 0, key(name)
	for _, inv in ipairs(w.invites) do
		if key(inv.to) == k then n = n + 1 end
	end
	return n
end

-- a driver with the console open, Dan Rider owing (left without paying) and Eve Night not
local function console(o)
	o = o or {}
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	local cs = {
		{ name = "Dan Rider", key = "dan rider", state = "lead", source = "whisper", at = 0, price = 5000, paid = 0 },
		{ name = "Eve Night", key = "eve night", state = "lead", source = "whisper", at = 0, price = 5000, paid = 0 },
	}
	DR.Sorted = function() return cs end
	DR.customers = {}
	for _, c in ipairs(cs) do DR.customers[c.key] = c end
	DR.IsOpen = function() return true end
	local l = DR.Log()
	local t0 = a.env.time()
	for _, n in ipairs({ "Dan Rider", "Eve Night" }) do
		l.rides[#l.rides + 1] = table.concat({ t0 - 90000, 5000, n, "Orgrimmar", "t", 5000 }, ",")
	end
	DR.MailOwes({ name = "Dan Rider", key = "dan rider" }, 50000)
	if o.wide then
		a.wide = true
		W.db.coach = true
		W.UI.WindowWide(true)
	else
		W.UI.WindowWide(false)
	end
	T.openDrive(a)
	if W.UI and W.UI.ShowDrive then W.UI.ShowDrive("console") end
	w:advance(2)
	W.Driver.RefreshNow()
	w:advance(1)
	return w, a, W, DR, cs
end

local function noteSheet(W, who)
	W.Driver.ShowSheet("note", who)
	return W.Driver.ui.sheets.note
end

local function tipOf(a, f)
	local S = H.state
	local gt = a.env.GameTooltip
	S[gt].tipLines = {}
	local fn = S[f].scripts and S[f].scripts.OnEnter
	ok(fn, "the pill has a tooltip")
	fn(f)
	local out = {}
	for _, l in ipairs(S[gt].tipLines or {}) do out[#out + 1] = type(l) == "table" and tostring(l.text or l[1]) or tostring(l) end
	return table.concat(out, "\n")
end

test("d4 h: the pill shows only for a rider who left owing, and only in Advanced", function()
	local w, a, W, DR, cs = console()
	local s = noteSheet(W, cs[1])
	ok(s.serve and s.serve:IsShown(), "Dan left owing: the pill shows")
	local s2 = noteSheet(W, cs[2])
	ok(not s2.serve:IsShown(), "Eve owes nothing: no pill")
	W.Advanced = function() return false end
	s = noteSheet(W, cs[1])
	ok(not s.serve:IsShown(), "Simple: no pill, even for Dan")
	T.clean(w)
end)

test("d4 h: a click sets 30 days from today, shows the date, and a second click lifts it", function()
	local w, a, W, DR, cs = console()
	local s = noteSheet(W, cs[1])
	w:advance(3) -- the player waits for the note sheet to finish rising
	eq(DR.ServeHold("Dan Rider"), nil, "nothing held yet")
	local want = a.env.time() + DR.BOOK.HOLD_DAYS * DAY
	local day = W.Mod("UI.Driver.Customers").dayText(want)
	ok(s.serve.label:GetText():find("Don't serve again until " .. day, 1, true), "the label says what a click does: " .. tostring(s.serve.label:GetText()))
	a:click(s.serve)
	eq(DR.ServeHold("Dan Rider"), want, "stored: now plus 30 days")
	eq(DR.BOOK.HOLD_DAYS, 30, "the number lives in one constant")
	ok(s.serve.label:GetText():find("Don't serve again until " .. day, 1, true), "set: it shows the date")
	ok(tipOf(a, s.serve):find("Click to take it off", 1, true), "set: the tooltip says how to take it off")
	a:click(s.serve)
	eq(DR.ServeHold("Dan Rider"), nil, "a click took it off")
	ok(tipOf(a, s.serve):find("30 days", 1, true), "off: the tooltip says what it does")
	T.clean(w)
end)

test("d4 h: the side pane (unfolded) has the same pill", function()
	local w, a, W, DR, cs = console({ wide = true })
	W.Driver.ShowScreen("customers")
	w:advance(1)
	W.Driver.RefreshNow()
	local pane = nil
	for _, f in ipairs({ "WuberFrame" }) do pane = pane or a.env[f] end
	local found
	for _, t in ipairs(a:visibleTexts()) do
		if tostring(t):find("Don't serve again until", 1, true) then found = t end
	end
	ok(found, "the pill is on the Customers page for the first customer (Dan, who left owing)")
	T.clean(w)
end)

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

local function sayInTrade(w, faction, name, text)
	if not w:player(name) then w:addBot(name, { spot = "Ratchet", acceptsInvites = true, faction = faction }) end
	w:chatFrom(name, text, "CHANNEL", "Trade", faction)
	w:advance(0.5)
end

test("d4 h: while held: no invite, no auto reply, the request stays on the list; the date ends it by itself", function()
	local w, a, DR, faction = openOrgDriver()
	DR.SetServeHold("Dan Miller", true)
	sayInTrade(w, faction, "Dan Miller", "WTB summon to Orgrimmar")
	eq(#w:whispersTo("Dan Miller", "reply"), 0, "no reply whisper")
	eq(invitesTo(w, "Dan Miller"), 0, "not invited from public chat")
	local c = DR.customers[key("Dan Miller")]
	ok(c ~= nil and c.state == "lead", "the request is on the list, for the driver to decide")
	w:botWhisper("Dan Miller", a, "summon Orgrimmar")
	w:advance(5)
	eq(invitesTo(w, "Dan Miller"), 0, "not invited from a whisper either")
	c = DR.customers[key("Dan Miller")]
	ok(c ~= nil and c.state == "lead", "still a lead after the whisper")
	-- the date ends it, with nothing said to anyone and no timer
	local b = a.env.WuberDB.drive.book
	b.hold[key("Eve Stone")] = a.env.time() - 1
	eq(DR.ServeHold("Eve Stone"), nil, "past its date: gone")
	eq(b.hold[key("Eve Stone")], nil, "and tidied away")
	sayInTrade(w, faction, "Eve Stone", "WTB summon to Orgrimmar")
	eq(#w:whispersTo("Eve Stone", "reply"), 1, "served again: the reply whisper goes")
	-- the driver's own click decides
	DR.Invite(c)
	w:advance(3)
	eq(invitesTo(w, "Dan Miller"), 1, "the driver's own click still invites")
	T.clean(w)
end)

-- every message the client sent that is not to or about Dan: as strings, without clock times
local function wire(w, skip)
	local out = {}
	for _, e in ipairs(w.addonLog) do
		local keys = {}
		for k, v in pairs(e) do
			if type(v) ~= "table" and k ~= "at" and k ~= "time" then keys[#keys + 1] = k .. "=" .. tostring(v) end
		end
		table.sort(keys)
		local line = table.concat(keys, ";")
		if not line:lower():find(skip, 1, true) then out[#out + 1] = "A " .. line end
	end
	for _, x in ipairs(w.whispers) do
		local line = ("W %s>%s %s %s"):format(x.from, x.to, tostring(x.how), x.text)
		if not line:lower():find(skip, 1, true) then out[#out + 1] = line end
	end
	return out
end

-- mode "hold": Dan asks (public line and whisper) with the hold set; "none": Dan says nothing (the control)
local function exchange(mode)
	local w, a, DR, faction = openOrgDriver()
	if mode == "hold" then DR.SetServeHold("Dan Miller", true) end
	if mode == "hold" then sayInTrade(w, faction, "Dan Miller", "WTB summon to Orgrimmar") end
	sayInTrade(w, faction, "Fay Wood", "WTB summon to Orgrimmar")
	if mode == "hold" then w:botWhisper("Dan Miller", a, "summon Orgrimmar") end
	w:advance(30)
	w:advance(300) -- a beacon and an advert go by
	return w, a, DR
end

test("d4 h: nothing leaves the client: the exchange is the same as one without the rider, with the hold set", function()
	local w1, a1 = exchange("none")
	local w2, a2, DR2 = exchange("hold")
	local plain, held = wire(w1, "dan miller"), wire(w2, "dan miller")
	eq(#held, #plain, "the same number of messages that are not to Dan")
	for i = 1, #plain do eq(held[i], plain[i], "message " .. i .. " is the same") end
	-- what went to Dan: nothing more than before (no invite, no reply)
	eq(#w2:whispersTo("Dan Miller"), 0, "nothing whispered to Dan")
	eq(invitesTo(w2, "Dan Miller"), 0, "no invite to Dan")
	-- no outgoing text carries the date, a flag or the words
	local until_ = DR2.ServeHold("Dan Miller")
	ok(until_, "still held")
	local day = a2.W.Mod("UI.Driver.Customers").dayText(until_)
	local all = table.concat(wire(w2, "\0"), "\n"):lower()
	for _, bad in ipairs({ tostring(until_), tostring(until_ - 0):sub(1, 8), "hold", "serve", "until", "owe", "unpaid", (day or "?"):lower() }) do
		ok(not all:find(bad, 1, true), "no outgoing message contains " .. bad)
	end
	-- and it is only in this account's saved data, in the book's own table (never in a record the note sync sends)
	local book = a2.env.WuberDB.drive.book
	ok(book and book.hold and book.hold[key("Dan Miller")] == until_, "stored in the book's hold table")
	for k, rec in pairs(book.list or {}) do ok(rec.hold == nil, "no record carries it: " .. tostring(k)) end
	T.clean(w1)
	T.clean(w2)
end)
