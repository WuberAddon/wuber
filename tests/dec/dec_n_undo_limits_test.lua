-- Decisions round, group N (Polestar ideas 8 and 10).
-- Idea 8: Undo for 10 seconds after a reset. Settings' three resets (Window position, Wide or narrow per page, Big button
-- position) and Earnings' Reset stats show a toast with an "Undo" button (UI.UndoToast); Undo puts back exactly what the
-- reset removed; after 10 s the reset is final and what it removed is forgotten.
-- Idea 10: one quiet Settings row, "What Wuber sends", states the sending limits with the code's own numbers, and the
-- Settings search finds it.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function tipOf(c, f)
	local S = H.state
	local gt = c.env.GameTooltip
	S[gt].tipLines = {}
	local fn = S[f].scripts and S[f].scripts.OnEnter
	ok(fn, "the control has a tooltip")
	if not fn then return "" end
	fn(f)
	local out = {}
	for _, l in ipairs(S[gt].tipLines or {}) do out[#out + 1] = type(l) == "table" and tostring(l.text or l[1]) or tostring(l) end
	return table.concat(out, "\n")
end

-- every toast, as said and as returned
local function watch(W)
	local log = { said = {}, toasts = {} }
	local real = W.UI.Toast
	W.UI.Toast = function(text, ...)
		local t = real(text, ...)
		log.said[#log.said + 1] = tostring(text)
		log.toasts[#log.toasts + 1] = t or false
		log.last = t
		return t
	end
	return log
end

local function open(warlock, where)
	local w = T.newWorld()
	local c = warlock and T.driver(w, T.BOB) or T.rider(w, T.TESTCHAR)
	T.settle(w)
	c.W.db.coach = true
	c.W.db.fold = { v = 1, pages = {}, narrow = true }
	c.W.UI.Toggle(true)
	w:advance(3)
	c.W.UI.OpenSettings(where)
	w:advance(1)
	return w, c, c.W.UI.settings
end

test("dec n: Wide or narrow Reset says '3 settings reset.' with an Undo button; Undo puts every page's choice and Always narrow back", function()
	local w, c, st = open(false, "window")
	local W = c.W
	W.db.fold.pages = { home = "open", trips = "closed" }
	local log = watch(W)
	st.controls.foldReset:Click()
	w:advance(0.5)
	eq(W.db.fold.narrow, false, "the reset happened: Auto")
	eq(next(W.db.fold.pages), nil, "the reset happened: no page choice")
	eq(log.said[#log.said], "3 settings reset.", "the line counts what was reset")
	local t = log.last
	ok(type(t) == "table" and H.visible(t), "the toast shows")
	ok(t.undo and H.visible(t.undo), "with an Undo button")
	eq(t.undo.label:GetText(), "Undo", "the button's word")
	local tip = tipOf(c, t.undo)
	ok(tip:find("Undo", 1, true) and tip:find("Puts back what was just reset.", 1, true), "the button's tooltip: " .. tip)
	local tr, ur = H.rect(t), H.rect(t.undo)
	ok(ur.l >= tr.l and ur.l + ur.w <= tr.l + tr.w and ur.b >= tr.b and ur.b + ur.h <= tr.b + tr.h, "the button sits inside the toast")
	local xr = H.rect(t.text)
	ok(xr.l + xr.w <= ur.l, "the words end before the button")
	ok(W.UI.UndoPending(), "an Undo is up")
	w:advance(5)
	ok(H.visible(t), "still there after 5 s")
	t.undo:Click()
	w:advance(0.5)
	eq(W.db.fold.narrow, true, "Undo: Always narrow is back")
	eq(W.db.fold.pages.home, "open", "Undo: the home page's choice is back")
	eq(W.db.fold.pages.trips, "closed", "Undo: the trips page's choice is back")
	eq(st.controls.foldWide.value, "narrow", "Undo: the control shows Always narrow")
	ok(not H.visible(t), "the toast is gone")
	ok(not W.UI.UndoPending(), "no Undo is up")
	T.clean(w)
end)

test("dec n: the Undo lasts 10 seconds, then the reset is final and what it removed is forgotten", function()
	local w, c, st = open(false, "window")
	local W = c.W
	W.db.fold.pages = { home = "open" }
	local log = watch(W)
	st.controls.foldReset:Click()
	local t = log.last
	ok(type(t) == "table" and t.undoFn, "the Undo is armed")
	w:advance(9)
	ok(H.visible(t) and W.UI.UndoPending(), "there at 9 s")
	w:advance(2)
	ok(not H.visible(t), "gone after 10 s")
	ok(not W.UI.UndoPending(), "no Undo is up")
	eq(t.undoFn, nil, "the removed values are forgotten")
	if t.undo then t.undo:Click() end
	eq(W.db.fold.narrow, false, "a late click changes nothing")
	eq(next(W.db.fold.pages), nil, "the reset is final")
	T.clean(w)
end)

test("dec n: Reset twice: the second, empty reset does not take the Undo away; alone it says the old line", function()
	local w, c, st = open(false, "window")
	local W = c.W
	local log = watch(W)
	st.controls.foldReset:Click()
	w:advance(0.5)
	eq(log.said[#log.said], "1 setting reset.", "one thing was set (Always narrow): singular")
	local t = log.last
	st.controls.foldReset:Click()
	w:advance(0.5)
	eq(#log.said, 1, "the empty second reset says nothing")
	ok(H.visible(t) and W.UI.UndoPending(), "the Undo is still up")
	w:advance(11)
	st.controls.foldReset:Click()
	w:advance(0.5)
	eq(log.said[#log.said], "Every page is back to Auto", "nothing to undo: the old line")
	ok(not (log.last and log.last.undo and H.visible(log.last.undo)), "and no Undo button")
	T.clean(w)
end)

test("dec n: Window position Reset: '2 settings reset.' and Undo puts the saved place and size back", function()
	local w, c, st = open(true, "window")
	local W = c.W
	local win = W.UI.state.win
	win:ClearAllPoints()
	win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 5, -5)
	W.db.pos = { "TOPLEFT", "TOPLEFT", 5, -5 }
	W.db.scale = 1.2
	local pos0 = W.db.pos
	local log = watch(W)
	st.controls.resetPos:Click()
	w:advance(0.5)
	eq(W.db.pos, nil, "the place is forgotten")
	eq(W.db.scale, nil, "the size is forgotten")
	eq(log.said[#log.said], "2 settings reset.")
	local t = log.last
	ok(t and t.undo and H.visible(t.undo), "the Undo button")
	t.undo:Click()
	w:advance(0.5)
	eq(W.db.pos, pos0, "Undo: the saved place is back")
	eq(W.db.scale, 1.2, "Undo: the size is back")
	local p, _, rp, x, y = win:GetPoint(1)
	eq(tostring(p) .. tostring(rp) .. tostring(x) .. tostring(y), "TOPLEFTTOPLEFT5-5", "Undo: the window stands where it was")
	T.clean(w)
end)

test("dec n: Big button position Reset: '1 setting reset.' and Undo puts the saved place back", function()
	local w, c, st = open(true, "driving")
	local W = c.W
	local b = W.db.drive.button
	ok(type(b) == "table", "the big button's saved table")
	b.pos = { "CENTER", "CENTER", 111, -77 }
	local pos0 = b.pos
	local log = watch(W)
	st.controls["drive.resetPos"]:Click()
	w:advance(0.5)
	eq(W.db.drive.button.pos, nil, "the place is forgotten")
	eq(log.said[#log.said], "1 setting reset.")
	local t = log.last
	ok(t and t.undo and H.visible(t.undo), "the Undo button")
	t:Click() -- a click on the toast itself undoes too
	w:advance(0.5)
	eq(W.db.drive.button.pos, pos0, "Undo: the saved place is back")
	T.clean(w)
end)

test("dec n: Earnings Reset stats: 'Counts reset.' with Undo; Undo adds back exactly what was taken away", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	local DR = W.Drive
	W.db.drive.stats = { rides = 7, copper = 12345, tips = 300 }
	DR.session = { rides = 2, copper = 400, tips = 0 }
	T.openDrive(a)
	W.UI.ShowDrive("earnings")
	w:advance(1)
	local e = W.UI.drive.screens.earnings
	local log = watch(W)
	-- the player scrolls down to Reset stats
	ok(a:scrollIntoView(e.reset), "Reset stats scrolls into view")
	a:click(e.reset)
	a:click(e.reset)
	w:advance(0.5)
	local ever, sess = DR.Stats()
	eq(ever.rides + ever.copper + ever.tips + sess.rides + sess.copper + sess.tips, 0, "the counts are zero")
	eq(log.said[#log.said], "Counts reset.")
	local t = log.last
	ok(t and t.undo and H.visible(t.undo), "the Undo button")
	eq(t.undo.label:GetText(), "Undo")
	-- a ride counted in between stays counted
	W.db.drive.stats.rides = 1
	t.undo:Click()
	w:advance(0.5)
	ever, sess = DR.Stats()
	eq(ever.rides, 8, "ever: 7 back, and the one since")
	eq(ever.copper, 12345)
	eq(ever.tips, 300)
	eq(sess.rides, 2)
	eq(sess.copper, 400)
	-- nothing to take away: the old line, no Undo
	DR.ResetStats()
	w:advance(11)
	ok(a:scrollIntoView(e.reset), "Reset stats scrolls into view again")
	a:click(e.reset)
	a:click(e.reset)
	w:advance(0.5)
	eq(log.said[#log.said], "Counts reset", "all zero already: the old line")
	T.clean(w)
end)

test("dec n: DR.ResetStats returns what it took away and DR.RestoreStats adds it back", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(5)
	local DR = a.W.Drive
	a.W.db.drive.stats = { rides = 3, copper = 50, tips = 0 }
	DR.session = { rides = 1, copper = 50, tips = 0 }
	local removed = DR.ResetStats()
	ok(type(removed) == "table", "ResetStats returns what it removed")
	eq(removed.n, 4, "four of the six counts were not zero")
	eq(removed.ever.rides, 3)
	eq(removed.session.copper, 50)
	eq(DR.RestoreStats(removed), true)
	local ever, sess = DR.Stats()
	eq(ever.rides, 3)
	eq(ever.copper, 50)
	eq(sess.rides, 1)
	eq(DR.RestoreStats(nil), false, "nothing to put back")
	T.clean(w)
end)

local function read(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local s = f:read("*a")
	f:close()
	return s
end

test("dec n: Settings has one quiet row 'What Wuber sends' in Riding, with the code's own numbers, and the search finds it", function()
	local w, c, st = open(true, "riding")
	local W = c.W
	local Rows = W.Mod("UI.Settings.Rows")
	local Find = W.Mod("UI.Settings.Find")
	local r = st.sendingRow
	ok(r and H.visible(r), "the row shows on the Riding page")
	eq(r.title:GetText(), "What Wuber sends")
	local short = r.sub:GetText()
	eq(short, Rows.SENDING.text, "the row shows the short line (the 20 rewrites, W-13)")
	local text = Rows.SENDING.tip -- the whole of what is sent is the row's tooltip
	eq(r.wuberTip and r.wuberTip.text, text, "the tooltip holds the whole line")
	ok(short:find("at most 12 at once", 1, true) and short:find("2 a second", 1, true), "the short line keeps both numbers")
	ok(short:find("once an hour for each person", 1, true), "and the once an hour")
	ok(short:find("switched it on in Messages", 1, true) and short:find("your click", 1, true), "and the click rule")
	-- (the Settings diet) it sits in Riding's Advanced rows, after My time is worth, on the Riding page
	eq(r.group:GetParent().page, "riding", "on the Riding page")
	ok(r.group:GetParent().adv, "in the Riding Advanced rows")	ok(r.switch == nil and r.button == nil, "a text row: no control")
	-- the numbers are the code's
	local K = W.Mod("Net.Base").NETK
	local team = read(T.dir .. "/../Wuber/Drive/Team.lua") or ""
	local crewBurst = tonumber(team:match("local tokens, lastFill = (%d+), 0"))
	ok(crewBurst and team:find("tokens = math.min(" .. crewBurst .. ", tokens + math.floor(now - lastFill))", 1, true), "the crew outbox: " .. tostring(crewBurst) .. " at once, one a second")
	ok(text:find("at most " .. (K.BURST + crewBurst) .. " at once", 1, true), "at once: the two outboxes together (" .. K.BURST .. " + " .. tostring(crewBurst) .. ")")
	ok(text:find("at most " .. (K.RATE + 1) .. " a second", 1, true), "a second: the two outboxes together")
	eq(W.Drive.REPLY_EVERY, 3600, "the whisper back: once an hour for each person")
	ok(text:find("at most once an hour for each person", 1, true), "says once an hour")
	for _, never in ipairs({ "in combat", "in a raid", "in an instance", "during a ride" }) do
		ok(text:find(never, 1, true), "says never " .. never)
	end
	ok(text:find("the lines you switch on in Messages", 1, true), "stays true with the Messages switches")
	ok(text:find("your own click", 1, true), "every other line needs the player's own click")
	ok(not text:lower():find("addon", 1, true), "no jargon")
	local sentences = select(2, text:gsub("%. ", "")) + 1
	ok(sentences <= 2, "two sentences at most: " .. sentences)
	-- whole in its row: the row grew to hold it
	local rr, sr = H.rect(r), H.rect(r.sub)
	ok(sr.b >= rr.b - 0.5 and sr.b + sr.h <= rr.b + rr.h + 0.5, "the text is inside its row (" .. sr.h .. " of " .. rr.h .. ")")
	-- the search
	for _, q in ipairs({ "what wuber sends", "privacy", "hidden messages", "limits", "spam" }) do
		local found
		for _, m in ipairs(Find.match(q)) do if m.label == "What Wuber sends" then found = m end end
		ok(found, "the search finds it by '" .. q .. "'")
		if found then eq(found.section, "Riding", "in Riding") end
	end
	T.clean(w)
end)
