-- Wuber 2.4, p2 cd: the careful record of auto-invites and its line in the driver side pane.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

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

local function openUnfoldedConsole(w, d)
	d.wide = true
	d.W.db.coach = true
	if d.W.UI and d.W.UI.WindowWide then d.W.UI.WindowWide(true) end
	T.openDrive(d)
	if d.W.UI and d.W.UI.ShowDrive then d.W.UI.ShowDrive("console") end
	w:advance(2)
	d.W.Driver.RefreshNow()
	w:advance(1)
end

test("v24 record: clear and unclear whispers, CountWrong, reload survival, and ResetStats", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	w:addBot(T.BOB, { spot = "Orgrimmar", class = "MAGE", acceptsInvites = false })
	w:addBot(T.TESTCHAR, { spot = "Orgrimmar", class = "MAGE", acceptsInvites = false })
	w:addBot(T.ANA, { spot = "Orgrimmar", class = "MAGE", acceptsInvites = false })
	w:addBot(T.CAL, { spot = "Orgrimmar", class = "MAGE", acceptsInvites = false })
	T.settle(w)
	T.goOnline(d, { price = 5000 })
	w:advance(1)

	local DR = d.W.Drive
	local a0, w0 = DR.AutoRecord()
	eq(a0, 0, "starts at 0 auto")
	eq(w0, 0, "starts at 0 wrong")
	eq(DR.AutoRecordText(), nil, "no line while 0")

	w:botWhisper(T.BOB, d, "LF sleeping bag summons")
	w:advance(1)
	local a1, w1 = DR.AutoRecord()
	eq(a1, 0, "unclear whisper counts nothing")
	eq(w1, 0, "still 0 wrong")
	eq(DR.AutoRecordText(), nil, "still nil")

	w:botWhisper(T.TESTCHAR, d, "summon pls")
	w:advance(1)
	local a2, w2 = DR.AutoRecord()
	eq(a2, 1, "clear whisper counts 1 auto-invite")
	eq(w2, 0, "0 wrong")
	eq(DR.AutoRecordText(), "1 auto-invite · 0 wrong", "singular line")

	local c = DR.customers[T.TESTCHAR:lower()]
	DR.CountWrong(c)
	local a3, w3 = DR.AutoRecord()
	eq(a3, 1, "still 1 auto")
	eq(w3, 1, "1 wrong")
	eq(DR.AutoRecordText(), "1 auto-invite · 1 wrong", "line with 1 wrong")

	w:botWhisper(T.ANA, d, "summon pls")
	w:advance(1)
	eq(DR.AutoRecordText(), "2 auto-invites · 1 wrong", "plural line")

	w:reload(d)
	T.settle(w)
	DR = d.W.Drive
	local ar, wr = DR.AutoRecord()
	eq(ar, 2, "auto survives reload")
	eq(wr, 1, "wrong survives reload")
	eq(DR.AutoRecordText(), "2 auto-invites · 1 wrong", "text survives reload")

	DR.ResetStats()
	local a4, w4 = DR.AutoRecord()
	eq(a4, 2, "ResetStats keeps auto")
	eq(w4, 1, "ResetStats keeps wrong")

	T.clean(w)
end)

test("v24 record: unfolded driver side pane hides the line at 0, shows it with tooltip, and shifts below", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	w:addBot(T.TESTCHAR, { spot = "Orgrimmar", class = "MAGE", acceptsInvites = false })
	T.settle(w)
	T.goOnline(d, { price = 5000 })
	openUnfoldedConsole(w, d)

	eq(#d:findText("auto-invite", false, true), 0, "hidden while auto count is 0")
	local head0 = d:findText("Today's takings", false, true)[1]
	local top0 = d:findText("Open a few hours", false, true)[1]
	ok(head0 and top0, "today head and top window line visible")
	local gap0 = H.rect(head0).b - H.rect(top0).b

	w:botWhisper(T.TESTCHAR, d, "summon pls")
	w:advance(1)

	local recFs = d:findText("1 auto-invite · 0 wrong", false, true)[1]
	ok(recFs and H.visible(recFs), "record line shown in side pane")
	local tip = tipOf(d, recFs:GetParent())
	ok(tip:find("Auto-invites", 1, true), "tooltip title")
	ok(tip:find("Invites Wuber sent by itself after a clear request, and how many of them you marked as wrong.", 1, true), "tooltip text")

	local head1 = d:findText("Today's takings", false, true)[1]
	local top1 = d:findText("Open a few hours", false, true)[1]
	local gap1 = H.rect(head1).b - H.rect(top1).b
	local recH = H.rect(recFs:GetParent()).h
	ok(recH >= 16 and math.abs((gap1 - gap0) - recH) < 1, "everything below moved down by the line height: " .. tostring(gap1 - gap0) .. " vs " .. tostring(recH))

	-- also with the summons average line shown: record sits right under it and shifts below again
	d.W.db.drive.summons = { { total = 40, cast = 10 }, { total = 45, cast = 12 }, { total = 50, cast = 11 } }
	d.W.Driver.RefreshNow()
	w:advance(1)
	local avgFs = d:findText("Your summons:", false, true)[1]
	recFs = d:findText("1 auto-invite · 0 wrong", false, true)[1]
	ok(avgFs and recFs, "both lines shown")
	local rAvg, rRec = H.rect(avgFs), H.rect(recFs)
	ok(rRec.b + rRec.h <= rAvg.b + 0.5, "record line sits under Your summons")
	local head2 = d:findText("Today's takings", false, true)[1]
	local top2 = d:findText("Open a few hours", false, true)[1]
	local gap2 = H.rect(head2).b - H.rect(top2).b
	local avgH = H.rect(avgFs:GetParent()).h
	ok(avgH >= 16 and math.abs((gap2 - gap1) - avgH) < 1, "shifts down again when summons average also shows: " .. tostring(gap2 - gap1) .. " vs " .. tostring(avgH))
	T.clean(w)
end)
