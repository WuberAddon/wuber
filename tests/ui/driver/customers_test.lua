-- Tests of UI.Driver.Customers (round 9: FIXROUND-2.3.0 items 1 and 3; owner D). Loaded by tests/run.lua
-- with its helper table T. The row menu's Get Wuber / Note... / Gifted, the row marks and tooltip lines,
-- the Note sheet and the Customers screen (the footer link). The engine's queue is stubbed.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local DAN, EVE = "Dan Rider", "Eve Night"

local function key(n) return n:lower() end

-- a driver with the console open; o.queue = the customers (stubbed DR.Sorted)
local function console(o)
	o = o or {}
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	local cs = o.queue or {}
	DR.Sorted = function() return cs end
	DR.customers = {}
	for _, c in ipairs(cs) do DR.customers[c.key] = c end
	DR.IsOpen = function() return true end
	if o.wide then
		a.wide = true
		W.db.coach = true
		W.UI.WindowWide(true)
	elseif W.UI and W.UI.WindowWide then
		W.UI.WindowWide(false)
	end
	T.openDrive(a)
	if W.UI and W.UI.ShowDrive then W.UI.ShowDrive("console") end
	w:advance(2)
	W.Driver.RefreshNow()
	w:advance(1)
	return w, a, W, DR
end

local function texts(c) return table.concat(c:visibleTexts(), " | ") end

local function tipOf(c, f)
	local S = H.state
	local gt = c.env.GameTooltip
	S[gt].tipLines = {}
	local fn = S[f].scripts and S[f].scripts.OnEnter
	ok(fn, "the control has a tooltip")
	fn(f)
	local out = {}
	for _, l in ipairs(S[gt].tipLines or {}) do out[#out + 1] = type(l) == "table" and tostring(l.text or l[1]) or tostring(l) end
	return table.concat(out, "\n")
end

local function rider(name, o)
	local c = { name = name, key = key(name), state = "lead", source = "whisper", at = 0, price = 5000, paid = 0 }
	for k, v in pairs(o or {}) do c[k] = v end
	return c
end

test("ui.driver.customers: contract (registered, deps, header, public names); idle rows make no marks", function()
	local W, w, r, Mod = T.contract("UI.Driver.Customers", "tests/ui/driver/customers_test.lua", {
		["D.CustomerMenu"] = "function", ["D.CustomerPick"] = "function", ["D.CustomerTip"] = "function",
		["D.PaintMarks"] = "function", ["D.CustomerFacts"] = "function", ["D.screens.note"] = "function",
		["D.screens.customers"] = "function", ["Mod.dayText"] = "function", ["Mod.factsText"] = "function",
	})
	ok(Mod, "W.Mod(\"UI.Driver.Customers\")")
	T.clean(w)
	local w2, a, W2 = console({ queue = { rider(DAN) } })
	local row = W2.Driver.ui.console.rows[1]
	ok(row and row.c, "a row")
	eq(row.noteMark, nil, "no note mark made") eq(row.giftMark, nil, "no gift mark made")
	ok(not tipOf(a, row):find("Note:", 1, true), "no note line")
	T.clean(w2)
end)

test("ui.driver.customers: row menu - Get Wuber (chat rider only), Note..., Gifted; the stamp marks the row", function()
	local dan, eve = rider(DAN), rider(EVE, { source = "wuber", wuberRide = "abcdef", state = "joined" })
	local w, a, W, DR = console({ queue = { dan, eve } })
	local D = W.Driver
	ok(D.OpenMenu(dan), "menu")
	w:advance(1)
	local t = texts(a)
	ok(t:find("Send \"Get Wuber\"", 1, true), "Get Wuber for a chat rider: " .. t)
	ok(t:find("Note...", 1, true), "Note...") ok(t:find("Gifted", 1, true), "Gifted")
	local menu = D.ui.sheets.menu
	ok(menu.items.getapp and H.visible(menu.items.getapp), "the item shows")
	ok(tipOf(a, menu.items.getapp):find("once a day", 1, true), "its tooltip")
	a:click(menu.items.getapp)
	w:advance(1)
	ok(dan.getapp, "asked: owed on the next click")
	eq(DR.GetAppState(dan), "queued")
	ok(D.RowTip(dan):find("Get Wuber", 1, true), "the row tip says it waits for the click")
	-- an app rider: no Get Wuber
	D.OpenMenu(eve)
	w:advance(1)
	ok(not H.visible(menu.items.getapp), "no Get Wuber for an app rider")
	ok(H.visible(menu.items.custnote), "Note and Gifted for everyone")
	-- Gifted
	D.OpenMenu(dan)
	w:advance(1)
	a:click(menu.items.custnote.gift)
	w:advance(1)
	ok(DR.BookEntry(DAN) and DR.BookEntry(DAN).gift, "stamped")
	D.RefreshNow()
	w:advance(1)
	local row
	for _, r in ipairs(D.ui.console.rows) do if r.c == dan then row = r end end
	ok(row and row.giftMark and H.visible(row.giftMark), "the gift mark on Dan's row")
	ok(not (row.noteMark and H.visible(row.noteMark)), "no note mark yet")
	ok(D.RowTip(dan):find("Gifted on ", 1, true), "the tooltip says when")
	T.clean(w)
end)

test("ui.driver.customers: the Note sheet saves one note; the row shows the mark and the tooltip the text", function()
	local dan = rider(DAN)
	local w, a, W, DR = console({ queue = { dan } })
	local D = W.Driver
	D.OpenMenu(dan)
	w:advance(1)
	local menu = D.ui.sheets.menu
	a:click(menu.items.custnote.note)
	w:advance(1)
	local sh = D.ui.sheets.note
	ok(sh and sh.frame.open, "the Note sheet")
	ok(texts(a):find("No rides with you yet", 1, true), "the facts line")
	sh.field:SetText("Pays in silver, likes Org")
	a:click(sh.save)
	w:advance(1)
	eq(DR.BookEntry(DAN).note, "Pays in silver, likes Org", "saved")
	D.RefreshNow()
	w:advance(1)
	local row = D.ui.console.rows[1]
	ok(row.noteMark and H.visible(row.noteMark), "the note mark")
	ok(D.RowTip(dan):find("Note: Pays in silver, likes Org", 1, true), "the tooltip shows the note")
	T.clean(w)
end)

test("ui.driver.customers: the Customers screen - from the footer, newest ride first, search, a click opens the note", function()
	local w, a, W, DR = console({})
	local D = W.Driver
	local t0 = a.env.time()
	local l = DR.Log()
	l.rides[#l.rides + 1] = table.concat({ t0 - 90000, 5000, DAN, "Orgrimmar", "t", 5000 }, ",")
	l.rides[#l.rides + 1] = table.concat({ t0 - 600, 5000, EVE, "Undercity", "t", 5000 }, ",")
	DR.SetNote(DAN, "regular")
	local link = D.ui.console.links.customers
	ok(link and H.visible(link), "the footer's Customers link")
	ok(tipOf(a, link):find("notes", 1, true), "its tooltip")
	-- the player scrolls the console down to the footer link first
	ok(a:scrollIntoView(link), "the Customers link scrolls into view")
	a:click(link)
	w:advance(1)
	eq(D.CurrentScreen(), "customers", "the screen")
	local s = D.ui.subs.customers
	local r1, r2 = s.pool.list[1], s.pool.list[2]
	ok(r1 and r1.e and r1.e.name == EVE, "Eve rode last: first")
	ok(r2 and r2.e and r2.e.name == DAN, "then Dan")
	ok(H.visible(r2.note), "Dan's note mark")
	ok(texts(a):find("2 customers", 1, true), "the count")
	s.search:SetText("da")
	s.update()
	ok(s.pool.list[1].e.name == DAN and not H.visible(s.pool.list[2]), "search")
	ok(a:scrollIntoView(s.pool.list[1]), "the row scrolls into view")
	a:click(s.pool.list[1])
	w:advance(1)
	ok(D.ui.sheets.note and D.ui.sheets.note.frame.open, "a click opens the note")
	eq(D.ui.sheets.note.field:Text(), "regular")
	T.clean(w)
end)

test("ui.driver.customers: a long Customers list keeps the soft edge fade (S6), at the top and scrolled", function()
	local check = dofile(T.dir .. "/lib/listfade.lua")(H)
	local w, a, W, DR = console({})
	local D = W.Driver
	local t0 = a.env.time()
	local l = DR.Log()
	for i = 1, 30 do
		l.rides[#l.rides + 1] = table.concat({ t0 - i * 600, 5000, "Rider " .. string.char(64 + i % 26 + 1) .. i, "Orgrimmar", "t", 5000 }, ",")
	end
	D.ShowScreen("customers")
	w:advance(1)
	local bad = {}
	local function look(name)
		for _, b in ipairs(check(a, name)) do bad[#bad + 1] = b end
	end
	look("customers")
	local S = H.state
	for _, f in ipairs(a.frames) do
		local s = S[f]
		if s and s.clips and H.visible(f) and s.scripts.OnMouseWheel then
			for _ = 1, 4 do pcall(s.scripts.OnMouseWheel, f, -1) end
		end
	end
	w:advance(1.5)
	look("customers scrolled")
	ok(#D.ui.subs.customers.pool.list >= 30, "30 rows")
	eq(#bad, 0, "rows cut by a hard edge:\n  " .. table.concat(bad, "\n  "))
	T.clean(w)
end)

test("ui.driver.customers: (review) the note box takes 200 bytes; an empty Get Wuber template is not offered", function()
	local dan = rider(DAN)
	local w, a, W, DR = console({ queue = { dan } })
	local D = W.Driver
	D.ShowSheet("note", dan)
	w:advance(1)
	eq(H.state[D.ui.sheets.note.field.edit].maxBytes, DR.BOOK.NOTE_MAX + 1, "SetMaxBytes: the book's limit (plus the end byte)")
	D.ui.sheets.note.frame:Close(true)
	W.db.drive.templates.getapp = "||"
	D.OpenMenu(dan)
	w:advance(1)
	local menu = D.ui.sheets.menu
	ok(not (menu.items.getapp and H.visible(menu.items.getapp)), "no Get Wuber with nothing to send")
	T.clean(w)
end)

test("ui.driver.customers: (review) the Crew card's 'My own account' switch marks who gets the notes", function()
	local w, a, W, DR = console({})
	local D = W.Driver
	local BEA = "Bea Jones"
	DR.Crew = function()
		return { { name = a.player.name, key = W.myKey, role = "lock", app = true, me = true, here = true },
			{ name = BEA, key = "bea jones", role = "lock", app = true, here = true },
			{ name = "Cal Brown", key = "cal brown", role = "helper", app = false, here = true } }
	end
	D.ShowScreen("crew")
	w:advance(1)
	local rows = D.ui.subs.crew.members.list
	local bea, cal = rows[1], rows[2]
	ok(bea.own and H.visible(bea.own), "a switch on Bea's card")
	ok(tipOf(a, bea.own):find("Only mark your own characters", 1, true), "its tooltip")
	ok(not (cal.own and H.visible(cal.own)), "none for a helper without Wuber")
	-- the label clears the card's bottom edge: the card is taller than switch + label + gap
	ok(bea:GetHeight() >= 60, "member card height " .. tostring(bea:GetHeight()))
	ok(bea.ownLabel:GetWidth() <= 72, "label stays narrow (design 3: 72, \"my account\" measures 65 at Inter's smallest size)")
	eq(DR.BookOwn("bea jones"), false, "not marked yet")
	a:click(bea.own)
	w:advance(1)
	eq(DR.BookOwn("bea jones"), true, "marked")
	eq(W.Char().bookOwn["bea jones"], true, "kept on this character")
	a:click(bea.own)
	w:advance(1)
	eq(DR.BookOwn("bea jones"), false, "unmarked")
	-- (review 6) the toast says the other window has to mark this one too; a refused change snaps back
	a:click(bea.own)
	w:advance(1)
	ok(texts(a):find("once it marks this window too", 1, true), "the toast: " .. texts(a))
	local real = DR.SetBookOwn
	DR.SetBookOwn = function() return false end
	a:click(bea.own)
	w:advance(1)
	DR.SetBookOwn = real
	eq(bea.own.on, true, "not changed: the switch shows what is saved")
	eq(bea.own.pos, 1, "its knob too")
	T.clean(w)
end)

test("ui.driver.customers: (review) unfolded, Customers is two panes: the list left, the picked customer's note right", function()
	local w, a, W, DR = console({ wide = true })
	local D, UI = W.Driver, W.UI
	local t0 = a.env.time()
	local l = DR.Log()
	l.rides[#l.rides + 1] = table.concat({ t0 - 90000, 5000, DAN, "Orgrimmar", "t", 5000 }, ",")
	l.rides[#l.rides + 1] = table.concat({ t0 - 600, 5000, EVE, "Undercity", "t", 5000 }, ",")
	DR.SetNote(DAN, "regular")
	D.ShowScreen("customers")
	w:advance(2)
	eq(UI.Fold.Page(), "customers", "a page of its own")
	ok(UI.Fold.IsUnfolded(), "unfolded")
	eq(a.env.WuberFrame:GetWidth(), 720, "720 wide")
	local s = D.ui.subs.customers
	ok(texts(a):find("1 ride with you", 1, true), "the right pane shows the first (Eve): " .. texts(a))
	a:click(s.pool.list[2])
	w:advance(1)
	ok(not (D.ui.sheets.note and D.ui.sheets.note.frame.open), "no sheet: the right pane instead")
	ok(texts(a):find("regular", 1, true), "Dan's note on the right")
	-- the Save there keeps an edit
	local side
	for _, f in ipairs(a.frames) do
		local st = H.state[f]
		if st and st.otype == "EditBox" and H.visible(f) and f:GetText() == "regular" then side = f end
	end
	ok(side, "the note box on the right")
	side:SetText("regular, tips well")
	local save
	for _, f in ipairs(a.frames) do
		if f.label and H.visible(f) and f.label.GetText and f.label:GetText() == "Save" then save = f end
	end
	ok(save, "a Save button")
	a:click(save)
	w:advance(1)
	eq(DR.BookEntry(DAN).note, "regular, tips well", "saved from the right pane")
	-- folded, a click opens the Note sheet again
	UI.Fold.Toggle()
	w:advance(2)
	ok(not UI.Fold.IsUnfolded(), "folded by the button")
	a:click(s.pool.list[1])
	w:advance(1)
	ok(D.ui.sheets.note and D.ui.sheets.note.frame.open, "folded: the Note sheet")
	T.clean(w)
end)

test("ui.driver.customers: (review, 2.4 fix round 3) a long note on the Customers list wraps whole, the row grows", function()
	local w, a, W, DR = console({})
	local D, T2 = W.Driver, W.Theme
	local t0 = a.env.time()
	DR.Log().rides[1] = table.concat({ t0 - 600, 5000, DAN, "Orgrimmar", "t", 5000 }, ",")
	DR.SetNote(DAN, "Tips well, always Orgrimmar. Asked about Pioneers and the raid on Thursday night")
	D.ShowScreen("customers")
	w:advance(1)
	local r = D.ui.subs.customers.pool.list[1]
	local text = r.sub:GetText()
	ok(text:find("last ", 1, true) and text:find("Orgrimmar", 1, true), "the facts stay: " .. text)
	ok(text:find("Thursday night\"", 1, true) and not text:find("...", 1, true), "the whole note, never cut with ...: " .. text)
	ok(r:GetHeight() > 48, "the row grew for the second line: " .. r:GetHeight())
	T.clean(w)
end)

-- (Design 2) Save is the sheet's one main button (full width at the bottom); Gifted sits above it, to the right
test("ui.driver.customers: (round 9 previews) the Note sheet's Save and Gifted sit apart, inside the card", function()
	local dan = rider(DAN)
	local w, a, W = console({ queue = { dan } })
	local D = W.Driver
	D.ShowSheet("note", dan)
	w:advance(1)
	local sh = D.ui.sheets.note
	ok(sh and sh.frame.open, "the Note sheet")
	local sv, gf, fl, card = H.rect(sh.save), H.rect(sh.gift), H.rect(sh.field), H.rect(sh.frame.card)
	ok(gf.b >= sv.b + sv.h, "Gifted sits above Save, not over it")
	local e = sv.h / 46 -- the window's scale: 46 high on any screen
	ok(math.abs(sv.l - (card.l + 16 * e)) < 0.5, "Save is 16 from the card's left")
	ok(math.abs((card.l + card.w) - (sv.l + sv.w) - 16 * e) < 0.5, "Save is 16 from the card's right")
	ok(math.abs((card.l + card.w) - (gf.l + gf.w) - 16 * e) < 0.5, "Gifted lines up with Save's right")
	ok(gf.l + gf.w <= card.l + card.w, "inside the card")
	T.clean(w)
end)

test("ui.driver.customers: (review 5) the right pane takes a crew window's newer note while its box is unedited", function()
	local w, a, W, DR = console({ wide = true })
	local D = W.Driver
	local t0 = a.env.time()
	DR.Log().rides[1] = table.concat({ t0 - 600, 5000, DAN, "Orgrimmar", "t", 5000 }, ",")
	DR.SetNote(DAN, "old words")
	D.ShowScreen("customers")
	w:advance(2)
	local function box()
		for _, f in ipairs(a.frames) do
			local st = H.state[f]
			if st and st.otype == "EditBox" and H.visible(f) and f ~= D.ui.subs.customers.search.edit then return f end
		end
	end
	eq(box():GetText(), "old words", "the note on the right")
	-- a crew window's newer edit arrives (the merge a sync does)
	local rec = DR.BookEntry(DAN)
	rec.note, rec.noteAt = "newer words", rec.noteAt + 5
	W.Fire("DRIVE")
	D.RefreshNow()
	w:advance(1)
	eq(box():GetText(), "newer words", "the box shows the newer note")
	-- edited here: a later sync does not wipe what is being typed
	box():SetText("my typing")
	rec.note, rec.noteAt = "newest", rec.noteAt + 5
	W.Fire("DRIVE")
	D.RefreshNow()
	w:advance(1)
	eq(box():GetText(), "my typing", "an edit in progress stays")
	T.clean(w)
end)

test("ui.driver.customers: (round 12) no Get Wuber in the row menu for a rider Wuber knows runs Wuber", function()
	-- the 19 Nov screenshot: a Wuber user listed by whisper; Wuber heard his addon messages
	local rocks = rider("Wuber Rocks")
	local line = rider(EVE, { msg = "WTB summon to Orgrimmar for 50s" })
	local dan = rider(DAN)
	local w, a, W, DR = console({ queue = { rocks, line, dan } })
	local D = W.Driver
	a:fire("CHAT_MSG_ADDON", "WUBER", "Q~1", "CHANNEL", "Wuber Rocks", "", 0, 5, "WuberNet", 0)
	local menu
	for _, c in ipairs({ rocks, line }) do
		ok(D.OpenMenu(c), "menu")
		w:advance(1)
		menu = D.ui.sheets.menu
		ok(not (menu.items.getapp and H.visible(menu.items.getapp)), "no Get Wuber for " .. c.name .. ": " .. texts(a))
		ok(H.visible(menu.items.custnote), "Note and Gifted still there")
		ok(not D.RowTip(c):find("Get Wuber", 1, true), "no Get Wuber line in the tooltip")
		menu.frame:Close()
		w:advance(1)
	end
	D.OpenMenu(dan)
	w:advance(1)
	ok(menu.items.getapp and H.visible(menu.items.getapp), "a chat rider without the app still gets the offer")
	T.clean(w)
end)

test("ui.driver.customers: (round 12) Save says Saved with a tick, the note survives closing and reopening (sheet and right pane)", function()
	local dan = rider(DAN)
	local w, a, W, DR = console({ queue = { dan } })
	local D = W.Driver
	D.OpenMenu(dan)
	w:advance(1)
	a:click(D.ui.sheets.menu.items.custnote.note)
	w:advance(1)
	local sh = D.ui.sheets.note
	ok(sh and sh.frame.open, "the Note sheet")
	eq(sh.save.label:GetText(), "Save")
	sh.field:SetText("Tips well, always Org")
	a:click(sh.save)
	w:advance(0.3)
	eq(DR.BookEntry(DAN).note, "Tips well, always Org", "saved")
	eq(sh.save.label:GetText(), "Saved", "the button says so")
	ok(sh.save.tick and H.visible(sh.save.tick), "with a tick")
	ok(sh.frame.open, "the sheet stays a moment so it can be seen")
	w:advance(3)
	ok(not sh.frame.open, "then it closes by itself")
	-- the whole window closed and opened again: the sheet shows the note, the button says Save
	a.env.WuberFrame:Hide()
	w:advance(1)
	T.openDrive(a)
	w:advance(1)
	D.ShowSheet("note", dan)
	w:advance(1)
	ok(sh.frame.open, "the sheet again")
	eq(sh.field:Text(), "Tips well, always Org", "the note is still there")
	eq(sh.save.label:GetText(), "Save", "Save again")
	ok(not (sh.save.tick and H.visible(sh.save.tick)), "no tick")
	-- and after a reload
	w:reload(a)
	w:advance(5)
	eq(a.W.Drive.BookEntry(DAN) and a.W.Drive.BookEntry(DAN).note, "Tips well, always Org", "kept over a reload")
	T.clean(w)
	-- unfolded: the right pane's Save says Saved too, then Save again
	local w2, a2, W2, DR2 = console({ wide = true })
	local D2 = W2.Driver
	DR2.Log().rides[1] = table.concat({ a2.env.time() - 600, 5000, DAN, "Orgrimmar", "t", 5000 }, ",")
	D2.ShowScreen("customers")
	w2:advance(2)
	local side, save
	for _, f in ipairs(a2.frames) do
		local st = H.state[f]
		if st and st.otype == "EditBox" and H.visible(f) and f ~= D2.ui.subs.customers.search.edit then side = f end
		if f.label and H.visible(f) and f.label.GetText and f.label:GetText() == "Save" then save = f end
	end
	ok(side and save, "the right pane's box and Save")
	side:SetText("Likes  the zeppelin")
	a2:click(save)
	w2:advance(0.3)
	eq(DR2.BookEntry(DAN).note, "Likes the zeppelin", "saved")
	eq(save.label:GetText(), "Saved", "the button says so")
	ok(save.tick and H.visible(save.tick), "with a tick")
	eq(side:GetText(), "Likes the zeppelin", "the box shows what was kept")
	w2:advance(3)
	eq(save.label:GetText(), "Save", "Save again after a moment")
	ok(not H.visible(save.tick), "the tick goes")
	-- away and back: still there
	D2.ShowScreen("console")
	w2:advance(1)
	D2.ShowScreen("customers")
	w2:advance(1)
	eq(side:GetText(), "Likes the zeppelin", "the note is still there")
	T.clean(w2)
end)

test("ui.driver.customers: (round 12) pointing at a queue row shows 'Note: ...' and 'Gifted on' in the game tooltip (lab f9_marks)", function()
	local dan, eve = rider(DAN, { state = "joined" }), rider(EVE)
	local w, a, W, DR = console({ queue = { dan, eve } })
	local D = W.Driver
	local function rowOf(c)
		for _, r in ipairs(D.ui.console.rows) do if r.c == c and H.visible(r) then return r end end
	end
	ok(not tipOf(a, rowOf(dan)):find("Note:", 1, true), "no note yet: no line")
	DR.SetNote(DAN, "Tips well, always Orgrimmar")
	DR.SetGifted(DAN)
	D.RefreshNow()
	w:advance(1)
	local r = rowOf(dan)
	ok(r, "Dan's row")
	local tip = tipOf(a, r)
	ok(tip:find("Note: Tips well, always Orgrimmar", 1, true), "the note in the tooltip: " .. tip)
	ok(tip:find("Gifted on ", 1, true), "and the stamp")
	ok(r.noteMark and H.visible(r.noteMark) and r.giftMark and H.visible(r.giftMark), "both marks on the row")
	ok(not tipOf(a, rowOf(eve)):find("Note:", 1, true), "Eve has no note line")
	-- a note that came from my own crew window (the sync's merge) shows the same way
	local rec = DR.BookEntry(DAN)
	rec.note, rec.noteAt, rec.noteBy = "From Farra: pays in gold", rec.noteAt + 5, "farra way"
	W.Fire("DRIVE")
	D.RefreshNow()
	w:advance(1)
	ok(tipOf(a, rowOf(dan)):find("Note: From Farra: pays in gold", 1, true), "the synced note in the tooltip")
	-- a rider listed under a realm-qualified name finds the same record
	local dan2 = rider(DAN .. "-Realm", { key = key(DAN) })
	ok(D.RowTip(dan2):find("Note: From Farra", 1, true), "realm suffix: the same note")
	T.clean(w)
end)

test("ui.driver.customers: (round 12) a row's tooltip that is showing takes a note saved or synced under it", function()
	local dan = rider(DAN, { state = "joined" })
	local w, a, W, DR = console({ queue = { dan } })
	local D = W.Driver
	local r = D.ui.console.rows[1]
	ok(r and r.c == dan, "Dan's row")
	local gt = a.env.GameTooltip
	ok(not tipOf(a, r):find("Note:", 1, true), "pointing at it: no note yet")
	H.state[gt].tipLines = {}
	DR.SetNote(DAN, "Pays in gold")
	D.RefreshNow()
	w:advance(1)
	local out = {}
	for _, l in ipairs(H.state[gt].tipLines or {}) do out[#out + 1] = type(l) == "table" and tostring(l.text or l[1]) or tostring(l) end
	ok(table.concat(out, "\n"):find("Note: Pays in gold", 1, true), "the open tooltip shows the new note: " .. table.concat(out, " / "))
	T.clean(w)
end)

---------------------------------------------------------------------------
-- Round 13 (agent B), I27: a stamped Gifted pill shows a tick and says what it means; the Note
-- sheet and the unfolded Customers pane put the note, the privacy line and Save | Gifted in one order
---------------------------------------------------------------------------

local function giftTip(a, pill)
	return tipOf(a, pill)
end

test("ui.driver.customers: I27 Gifted - a tick once stamped, a tooltip that says 'You gave them a free ride'", function()
	local dan = rider(DAN)
	local w, a, W, DR = console({ queue = { dan } })
	local D = W.Driver
	D.ShowSheet("note", dan)
	w:advance(1)
	local sh = D.ui.sheets.note
	ok(not (sh.gift.gtick and sh.gift.gtick:IsShown()), "not stamped: no tick")
	ok(giftTip(a, sh.gift):find("ride as a gift", 1, true), "the tooltip says what Gifted is for")
	a:click(sh.gift)
	w:advance(1)
	ok(DR.BookEntry(DAN) and DR.BookEntry(DAN).gift, "stamped")
	ok(sh.gift.gtick and H.visible(sh.gift.gtick), "a tick on the stamped pill")
	ok(sh.gift.label.wuberText:find("^Gifted "), "Gifted and the day: " .. tostring(sh.gift.label.wuberText))
	ok(giftTip(a, sh.gift):find("You gave them a ride as a gift on ", 1, true), "stamped tooltip: " .. giftTip(a, sh.gift))
	ok(D.RowTip(dan):find("ride as a gift", 1, true), "the queue row's tooltip says it too")
	T.clean(w)
end)

test("ui.driver.customers: I27 the Note sheet and the unfolded Customers pane: note, privacy line, then Save | Gifted", function()
	local dan = rider(DAN)
	-- the Note sheet (folded)
	local w, a, W = console({ queue = { dan } })
	local D = W.Driver
	D.ShowSheet("note", dan)
	w:advance(1)
	local sh = D.ui.sheets.note
	local fl, pv, sv, gf = H.rect(sh.field), H.rect(sh.privacy), H.rect(sh.save), H.rect(sh.gift)
	-- (H.rect: l, b, w, h with y up; "under" = its top at or below the other's bottom)
	ok(pv.b + pv.h <= fl.b + 0.5, "sheet: the privacy line under the note box")
	ok(sv.b + sv.h <= pv.b + 0.5 and gf.b + gf.h <= pv.b + 0.5, "sheet: Save and Gifted under the privacy line")
	T.clean(w)
	-- the Customers screen unfolded: the right pane
	local w2, a2, W2, DR2 = console({ wide = true })
	local t0 = a2.env.time()
	DR2.Log().rides[1] = table.concat({ t0 - 600, 5000, DAN, "Orgrimmar", "t", 5000 }, ",")
	DR2.SetNote(DAN, "words")
	W2.Driver.ShowScreen("customers")
	w2:advance(2)
	local function visibleOne(text)
		for _, fs in ipairs(a2:findText(text, true, true)) do if H.visible(fs) and fs:GetParent() then return fs end end
	end
	local privacy = visibleOne("Only you and your own windows see notes. Never the rider.")
	local save = visibleOne("Save")
	local gift = visibleOne("Gifted")
	local box
	for _, f in ipairs(a2.frames) do
		local st = H.state[f]
		if st and st.otype == "EditBox" and H.visible(f) and f ~= W2.Driver.ui.subs.customers.search.edit then box = f end
	end
	ok(privacy and save and gift and box, "the pane's parts")
	local fl2, pv2, sv2, gf2 = H.rect(box), H.rect(privacy), H.rect(save:GetParent()), H.rect(gift:GetParent())
	ok(pv2.b + pv2.h <= fl2.b + 0.5, "pane: the privacy line under the note box")
	ok(sv2.b + sv2.h <= pv2.b + 0.5 and gf2.b + gf2.h <= pv2.b + 0.5, "pane: Save and Gifted under the privacy line (as the sheet)")
	T.clean(w2)
end)


---------------------------------------------------------------------------
-- BRIEF17 (2.3.2 fix round 3, group b): B2 "Invite to Wuber" on the queue row, B3 why it isn't
-- offered, S6 the Customers list says it scrolls, B1 the note Save tells the truth
---------------------------------------------------------------------------

local function catchToasts(c)
	local seen = {}
	local orig = c.W.UI.Toast
	c.W.UI.Toast = function(text, kind, onClick)
		seen[#seen + 1] = tostring(text)
		return orig(text, kind, onClick)
	end
	return seen
end

local function said(l, text)
	for _, t in ipairs(l) do if t:find(text, 1, true) then return true end end
	return false
end

local function rowOf(D, c)
	for _, r in ipairs(D.ui.console.rows) do if r.c == c and r:IsShown() then return r end end
end

test("ui.driver.customers: (BRIEF17 B2) a chat rider's row has Invite to Wuber: one tap queues it, again cancels", function()
	local dan, eve = rider(DAN), rider(EVE, { source = "wuber", wuberRide = "abcdef", state = "joined" })
	local w, a, W, DR = console({ queue = { dan, eve } })
	local D = W.Driver
	local seen = catchToasts(a)
	local r = rowOf(D, dan)
	ok(r, "Dan's row")
	ok(r.getapp and H.visible(r.getapp), "the pill on a chat rider's row")
	eq(r.getapp.label:GetText(), "Invite to Wuber")
	ok(tipOf(a, r.getapp):find("big-button click", 1, true), "its tooltip says the big button sends it")
	local er = rowOf(D, eve)
	ok(er and not (er.getapp and H.visible(er.getapp)), "none on an app rider's row")
	a:click(r.getapp)
	w:advance(1)
	ok(dan.getapp, "one tap: queued")
	eq(DR.GetAppState(dan), "queued")
	ok(said(seen, "Your next big-button click tells Dan"), "the toast: " .. table.concat(seen, " / "))
	eq(dan.state, "lead", "the tap did nothing else (no invite)")
	local owed = DR.GetAppOwed({})
	eq(#owed, 1, "owed to the big button's next click (the only way it is sent)")
	D.RefreshNow()
	w:advance(1)
	r = rowOf(D, dan)
	eq(r.getapp.label:GetText(), "Next click sends", "queued shows on the row")
	ok(tipOf(a, r.getapp):find("cancel", 1, true), "the tooltip says a tap cancels")
	a:click(r.getapp)
	w:advance(1)
	ok(not dan.getapp, "tapped again: cancelled")
	eq(DR.GetAppState(dan), "ok")
	ok(said(seen, "won't be sent"), "the toast says so")
	D.RefreshNow()
	w:advance(1)
	eq(rowOf(D, dan).getapp.label:GetText(), "Invite to Wuber", "back to the offer")
	-- sent today: no pill
	DR.GetAppSent(dan)
	D.RefreshNow()
	w:advance(1)
	r = rowOf(D, dan)
	ok(not H.visible(r.getapp), "no pill once sent today")
	T.clean(w)
end)

test("ui.driver.customers: (BRIEF17 B2) rows without a pill make none (idle rows keep their widgets)", function()
	local eve = rider(EVE, { source = "wuber", wuberRide = "abcdef", state = "joined" })
	local w, a, W = console({ queue = { eve } })
	local r = rowOf(W.Driver, eve)
	ok(r, "Eve's row")
	eq(r.getapp, nil, "no pill made for an app rider")
	T.clean(w)
end)

test("ui.driver.customers: (BRIEF17 B3) the row menu and Customers say why Get Wuber isn't offered", function()
	local dan, eve = rider(DAN), rider(EVE, { source = "wuber", wuberRide = "abcdef", state = "joined" })
	local w, a, W, DR = console({ queue = { dan, eve } })
	local D = W.Driver
	D.OpenMenu(eve)
	w:advance(1)
	local menu = D.ui.sheets.menu
	ok(not (menu.items.getapp and H.visible(menu.items.getapp)), "no offer for an app rider")
	ok(menu.items.getappwhy and H.visible(menu.items.getappwhy), "a line says why")
	eq(menu.items.getappwhy.label:GetText(), "Already uses Wuber")
	ok(tipOf(a, menu.items.getappwhy) ~= "", "its tooltip")
	a:click(menu.items.getappwhy)
	w:advance(1)
	ok(menu.frame.open, "a click on the reason does nothing (the menu stays)")
	menu.frame:Close(true)
	w:advance(1)
	DR.GetAppSent(dan)
	D.OpenMenu(dan)
	w:advance(1)
	ok(not (menu.items.getapp and H.visible(menu.items.getapp)), "no offer once sent today")
	eq(menu.items.getappwhy.label:GetText(), "Sent \"Get Wuber\" today")
	menu.frame:Close(true)
	w:advance(1)
	-- a chat rider still offered: no reason line
	local gus = rider("Gus Hill")
	DR.customers[gus.key] = gus
	D.OpenMenu(gus)
	w:advance(1)
	ok(menu.items.getapp and H.visible(menu.items.getapp), "the offer for a new chat rider")
	ok(not H.visible(menu.items.getappwhy), "and no reason line")
	menu.frame:Close(true)
	w:advance(1)
	-- the Note sheet (folded Customers) says it too
	D.ShowSheet("note", eve)
	w:advance(1)
	ok(texts(a):find("Already uses Wuber", 1, true), "the Note sheet: " .. texts(a))
	D.ui.sheets.note.frame:Close(true)
	D.ShowSheet("note", dan)
	w:advance(1)
	ok(texts(a):find("Sent \"Get Wuber\" today", 1, true), "the Note sheet for Dan")
	T.clean(w)
	-- unfolded: the right pane says it
	local dan2 = rider(DAN)
	local w2, a2, W2, DR2 = console({ wide = true, queue = { dan2 } })
	local D2 = W2.Driver
	DR2.Log().rides[1] = table.concat({ a2.env.time() - 600, 5000, DAN, "Orgrimmar", "t", 5000 }, ",")
	DR2.GetAppSent(dan2)
	D2.ShowScreen("customers")
	w2:advance(2)
	ok(texts(a2):find("Sent \"Get Wuber\" today", 1, true), "the right pane: " .. texts(a2))
	local row = D2.ui.subs.customers.pool.list[1]
	ok(tipOf(a2, row):find("Sent \"Get Wuber\" today", 1, true), "the list row's tooltip")
	T.clean(w2)
end)

test("ui.driver.customers: (BRIEF17 S6) a long Customers list says it scrolls, and how many more", function()
	local w, a, W, DR = console({})
	local D = W.Driver
	local t0 = a.env.time()
	local l = DR.Log()
	for i = 1, 22 do
		l.rides[#l.rides + 1] = table.concat({ t0 - i * 600, 5000, "Rider " .. string.char(64 + i % 26 + 1) .. i, "Orgrimmar", "t", 5000 }, ",")
	end
	D.ShowScreen("customers")
	w:advance(1)
	local s = D.ui.subs.customers
	ok(s.cue and H.visible(s.cue), "a scroll cue under the list")
	local text = s.cue.label:GetText() or ""
	ok(text:find("^Scroll for %d+ more$"), "it says how many more: " .. text)
	local n = tonumber(text:match("(%d+)"))
	ok(n and n >= 1 and n < 22, "a count of the rows below: " .. tostring(n))
	ok(not s.cue:IsMouseEnabled(), "it never takes the mouse (the wheel and clicks reach the list)")
	local cutN, drawnN = 0, 0
	for i = 1, s.rowsShown or 0 do
		local row = s.pool.list[i]
		if row.cutAlpha == 0 then
			cutN = cutN + 1
			ok(not row:IsMouseEnabled(), "a row hidden under the cue takes no mouse (row " .. i .. ")")
		else
			drawnN = drawnN + 1
			ok(row:IsMouseEnabled(), "a drawn row takes the mouse (row " .. i .. ")")
		end
	end
	ok(cutN > 0 and drawnN > 0, "both kinds seen")
	s.scroll:ScrollTo(s.scroll.max, true)
	w:advance(1)
	ok(not H.visible(s.cue), "gone at the bottom")
	s.scroll:ScrollTo(0, true)
	w:advance(1)
	ok(H.visible(s.cue), "back at the top")
	T.clean(w)
	-- a short list: no cue
	local w2, a2, W2, DR2 = console({})
	DR2.Log().rides[1] = table.concat({ a2.env.time() - 600, 5000, DAN, "Orgrimmar", "t", 5000 }, ",")
	W2.Driver.ShowScreen("customers")
	w2:advance(1)
	local s2 = W2.Driver.ui.subs.customers
	ok(not (s2.cue and H.visible(s2.cue)), "no cue when everything shows")
	T.clean(w2)
end)

test("ui.driver.customers: (BRIEF17 B1) Save tells the truth: nothing to save, no change, and an empty Save asks before it removes", function()
	local dan = rider(DAN)
	local w, a, W, DR = console({ queue = { dan } })
	local D = W.Driver
	local seen = catchToasts(a)
	D.ShowSheet("note", dan)
	w:advance(1)
	local sh = D.ui.sheets.note
	-- an empty box and no note: nothing is saved, and nothing says it was
	sh.field:SetText("")
	a:click(sh.save)
	w:advance(0.3)
	ok(not said(seen, "Note saved"), "no 'saved' toast for nothing: " .. table.concat(seen, " / "))
	ok(said(seen, "Nothing to save"), "it says why")
	eq(sh.save.label:GetText(), "Save", "no Saved on the button")
	ok(sh.frame.open, "the sheet stays to be typed in")
	-- a real note saves
	sh.field:SetText("Tips well")
	a:click(sh.save)
	w:advance(0.3)
	eq(DR.BookEntry(DAN).note, "Tips well")
	ok(said(seen, "Note saved for Dan"), "saved")
	w:advance(3)
	-- the same words again: no change
	D.ShowSheet("note", dan)
	w:advance(1)
	for i = #seen, 1, -1 do seen[i] = nil end
	a:click(sh.save)
	w:advance(0.3)
	ok(said(seen, "No changes to save"), "unchanged: " .. table.concat(seen, " / "))
	ok(not said(seen, "Note saved"), "not 'saved'")
	w:advance(3)
	-- an empty Save over a note (the box emptied by mistake): it asks first
	D.ShowSheet("note", dan)
	w:advance(1)
	sh.field:SetText("")
	a:click(sh.save)
	w:advance(0.3)
	eq(DR.BookEntry(DAN).note, "Tips well", "not removed on the first click")
	eq(sh.save.label:GetText(), "Remove note?", "the button asks")
	ok(said(seen, "click again"), "the toast says how: " .. table.concat(seen, " / "))
	-- left alone, it stops asking; the next empty Save asks again
	w:advance(6)
	eq(sh.save.label:GetText(), "Save", "back to Save after a moment")
	a:click(sh.save)
	w:advance(0.3)
	eq(DR.BookEntry(DAN).note, "Tips well", "still kept")
	eq(sh.save.label:GetText(), "Remove note?")
	-- typed again while it asks: a normal save
	sh.field:SetText("Pays in gold")
	a:click(sh.save)
	w:advance(0.3)
	eq(DR.BookEntry(DAN).note, "Pays in gold", "a real edit saves")
	w:advance(3)
	-- the second click removes it
	D.ShowSheet("note", dan)
	w:advance(1)
	sh.field:SetText("")
	a:click(sh.save)
	w:advance(0.3)
	a:click(sh.save)
	w:advance(0.3)
	local rec = DR.BookEntry(DAN)
	ok(not (rec and rec.note), "removed on the second click")
	ok(said(seen, "Note removed for Dan"), "the toast says removed")
	T.clean(w)
	-- the unfolded right pane: the same rules
	local w2, a2, W2, DR2 = console({ wide = true })
	local D2 = W2.Driver
	local seen2 = catchToasts(a2)
	DR2.Log().rides[1] = table.concat({ a2.env.time() - 600, 5000, DAN, "Orgrimmar", "t", 5000 }, ",")
	DR2.SetNote(DAN, "old words")
	D2.ShowScreen("customers")
	w2:advance(2)
	local side, save
	for _, f in ipairs(a2.frames) do
		local st = H.state[f]
		if st and st.otype == "EditBox" and H.visible(f) and f ~= D2.ui.subs.customers.search.edit then side = f end
		if f.label and H.visible(f) and f.label.GetText and f.label:GetText() == "Save" then save = f end
	end
	ok(side and save, "the right pane's box and Save")
	side:SetText("")
	a2:click(save)
	w2:advance(0.3)
	eq(DR2.BookEntry(DAN).note, "old words", "the pane asks before removing too")
	eq(save.label:GetText(), "Remove note?")
	a2:click(save)
	w2:advance(0.3)
	ok(not DR2.BookEntry(DAN).note, "then removes")
	ok(said(seen2, "Note removed for Dan"), "and says so")
	T.clean(w2)
end)

test("ui.driver.customers: (BRIEF17 review) painting rows and the Customers pane writes nothing to the book (GetAppState peek)", function()
	local eve = rider(EVE, { source = "wuber", wuberRide = "abcdef", state = "joined" })
	local w, a, W, DR = console({ wide = true, queue = { eve } })
	local D = W.Driver
	DR.Log().rides[1] = table.concat({ a.env.time() - 600, 5000, EVE, "Orgrimmar", "t", 5000 }, ",")
	DR.SetNote(EVE, "regular")
	eq(DR.BookEntry(EVE).wuber, nil, "no mark yet")
	D.RefreshNow()
	w:advance(1)
	D.ShowScreen("customers")
	w:advance(2)
	DR.customers[eve.key] = eve -- the live queue (the stub engine's tick may have pruned it)
	D.ui.subs.customers.update()
	ok(texts(a):find("Already uses Wuber", 1, true), "the pane still says why: " .. texts(a))
	tipOf(a, D.ui.subs.customers.pool.list[1])
	eq(DR.BookEntry(EVE).wuber, nil, "painting stamped nothing")
	eq(DR.GetAppState(eve, true), "app", "peek: the same answer")
	eq(DR.BookEntry(EVE).wuber, nil, "and no write")
	eq(DR.GetAppState(eve), "app")
	ok(DR.BookEntry(EVE).wuber, "without peek: stamped, as before")
	T.clean(w)
end)


test("ui.driver.customers: (BRIEF19 F4) a past customer (not in the queue) gets no invite and no extra line", function()
	local w, a, W, DR = console({ wide = true })
	DR.Log().rides[1] = table.concat({ a.env.time() - 600, 5000, DAN, "Orgrimmar", "t", 5000 }, ",")
	W.Driver.ShowScreen("customers")
	w:advance(2)
	ok(texts(a):find("Only you and your own windows", 1, true), "the privacy line stays")
	ok(not texts(a):find("Not in your queue", 1, true), "no queue line")
	T.clean(w)
end)

test("ui.driver.customers: (BRIEF19 F4) the unfolded pane offers Invite to Wuber, queued like the row's pill", function()
	local dan = rider(DAN)
	local w, a, W, DR = console({ wide = true, queue = { dan } })
	local D = W.Driver
	DR.Log().rides[1] = table.concat({ a.env.time() - 600, 5000, DAN, "Orgrimmar", "t", 5000 }, ",")
	D.ShowScreen("customers")
	w:advance(2)
	local p = D.ui.subs.customers
	local inv
	for _, f in ipairs(a.frames) do
		if f.SetLabel and f.label and H.visible(f) and f.label:GetText() == "Invite to Wuber" then inv = f end
	end
	ok(inv, "the Invite to Wuber pill is in the right pane: " .. texts(a))
	a:click(inv)
	w:advance(1)
	eq(DR.GetAppState(dan), "queued", "queued for the next big-button click, not whispered")
	ok(texts(a):find("Next click sends", 1, true), "the pane says it waits: " .. texts(a))
	a:click(inv)
	w:advance(1)
	eq(DR.GetAppState(dan), "ok", "a second click cancels")
	T.clean(w)
end)

test("ui.driver.customers: (BRIEF19 F4) a row that would peek under the Scroll pill is hidden whole", function()
	local w, a, W, DR = console({})
	local D = W.Driver
	local t0 = a.env.time()
	local l = DR.Log()
	for i = 1, 22 do
		l.rides[#l.rides + 1] = table.concat({ t0 - i * 600, 5000, "Rider " .. string.char(64 + i % 26 + 1) .. i, "Orgrimmar", "t", 5000 }, ",")
	end
	D.ShowScreen("customers")
	w:advance(1)
	local s = D.ui.subs.customers
	ok(H.visible(s.cue), "the cue shows")
	local hidden = 0
	for i = 1, 22 do local r = s.pool.list[i]; if r and r:GetAlpha() == 0 then hidden = hidden + 1 end end
	eq(hidden, tonumber(s.cue.label:GetText():match("(%d+)")) , "the cue counts exactly the hidden rows")
	ok(hidden > 0, "some rows are hidden")
	s.scroll:ScrollTo(s.scroll.max, true)
	w:advance(1)
	for i = 1, 22 do local r = s.pool.list[i]; if r then eq(r:GetAlpha(), 1, "row " .. i .. " back at the bottom") end end
	T.clean(w)
end)

-- (BRIEF20 B1, the same cause as the top nav) the note's Save asks "Remove note?" in a pink look and
-- goes back to Save. In the game a fill kept its alpha when it changed while not drawn (the sheet shut
-- before the ask ran out, or another customer's note opened): Save would come back pale (alpha 0.16).
-- Here an alpha change on a texture that isn't drawn is not drawn, as in the game, and any alpha change
-- on a drawn texture is noted: the ask is its own pill, shown or hidden.
local function asGameBtn(btn, changed)
	for _, r in ipairs({ btn:GetRegions() }) do
		if r:GetObjectType() == "Texture" then
			local orig = r.SetVertexColor
			r.SetVertexColor = function(self, cr, cg, cb, ca)
				local _, _, _, a0 = self:GetVertexColor()
				if math.abs((ca or 1) - (a0 or 1)) > 0.01 then
					if self:IsVisible() then changed[#changed + 1] = ("%.2f -> %.2f"):format(a0 or 1, ca or 1) end
					if not self:IsVisible() then return orig(self, cr, cg, cb, a0) end
				end
				return orig(self, cr, cg, cb, ca)
			end
		end
	end
end

-- the look of a pill as the game draws it: "solid" (a drawn texture at alpha over 0.9, not pink),
-- "pink" (a drawn pinkish texture), or "pale"
local function drawn(btn)
	local look = "pale"
	for _, r in ipairs({ btn:GetRegions() }) do
		if r:GetObjectType() == "Texture" and r:IsVisible() then
			local cr, cg, cb, al = r:GetVertexColor()
			if cr > 0.9 and cg < 0.5 and cb < 0.6 and (al or 1) > 0.05 then return "pink" end
			if (al or 1) > 0.9 then look = "solid" end
		end
	end
	return look
end
-- (Design 1) a destructive ask has red words and no fill (was a pink pill): nothing solid is drawn, the words are red
local function asks(btn)
	local r, g, b = btn.label:GetTextColor()
	return drawn(btn) == "pale" and r > 0.9 and g < 0.5 and b < 0.6
end

test("ui.driver.customers: (BRIEF20 B1) Remove note? and back to Save draw right in the game (shut while asking, another note)", function()
	local dan, eve = rider(DAN), rider(EVE)
	local w, a, W, DR = console({ queue = { dan, eve } })
	local D = W.Driver
	DR.SetNote(DAN, "Tips well")
	D.ShowSheet("note", dan)
	w:advance(1)
	local sh = D.ui.sheets.note
	local changed = {}
	asGameBtn(sh.save, changed)
	eq(drawn(sh.save), "solid", "Save: the solid violet pill")
	sh.field:SetText("")
	a:click(sh.save)
	w:advance(0.3)
	eq(sh.save.label:GetText(), "Remove note?", "the button asks")
	ok(asks(sh.save), "asking: red words, no fill")
	-- the sheet shut while it asks; the ask runs out unseen; another customer's note opens
	sh.frame:Close()
	w:advance(6)
	D.ShowSheet("note", eve)
	w:advance(1)
	eq(sh.save.label:GetText(), "Save", "Save again")
	eq(drawn(sh.save), "solid", "Save is the solid violet pill again, as the game draws it")
	-- asked and answered by typing, while it shows
	DR.SetNote(EVE, "Quiet")
	D.ShowSheet("note", eve)
	w:advance(1)
	sh.field:SetText("")
	a:click(sh.save)
	w:advance(0.3)
	ok(asks(sh.save), "asking again")
	sh.save:GetScript("OnEnter")(sh.save)
	ok(asks(sh.save), "hovered while asking: still the ask")
	sh.save:GetScript("OnLeave")(sh.save)
	sh.field:SetText("Pays in gold")
	a:click(sh.save)
	w:advance(0.3)
	eq(drawn(sh.save), "solid", "saved: solid again")
	eq(#changed, 0, "no alpha change on a drawn texture: " .. table.concat(changed, ", "))
	T.clean(w)
end)
