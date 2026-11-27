-- Wuber 2.4 quick wins, part B1: a quiet "what Wuber won't do" line under "Invite riders who whisper me" and under
-- "Whisper back to public requests". The words are the author's picks of 22 Nov (UI.Settings.Rows NOTES).
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function open(wide)
	local w = T.newWorld()
	local c = T.driver(w, T.BOB)
	T.settle(w)
	c.W.db.coach = true
	if wide then c.wide = true c.W.db.fold = { v = 1, pages = {}, narrow = false } end
	c.W.UI.Toggle(true)
	w:advance(3)
	c.W.UI.OpenSettings("driving")
	w:advance(1)
	return w, c, c.W.UI.settings
end

local INVITE = "Wuber won't invite on an unclear whisper or for a place you don't summon to: those wait in your list. It never invites a blocked player."
local REPLY = "Wuber won't whisper the same person twice in an hour, and never in combat, in a raid, in an instance or during a ride."

local function check(c, st, key, words, label, sub, mode)
	local ctl = st.controls["drive." .. key]
	ok(ctl and ctl.row, mode .. " " .. key .. ": the switch and its row")
	local r = ctl.row
	local note = st.notes and st.notes[key]
	ok(note and note.text, mode .. " " .. key .. ": the line exists")
	eq(note.text:GetText(), words, mode .. " " .. key .. ": the words, exactly")
	ok(H.visible(note.text), mode .. " " .. key .. ": shown")
	-- the row above is as it was
	eq(r.title:GetText(), label, mode .. " " .. key .. ": label unchanged")
	eq(r.sub:GetText(), sub, mode .. " " .. key .. ": sub line unchanged")
	-- below the row's own words, above the next row, inside the row and the page, nothing cut
	local n = { t = note.text:GetTop(), b = note.text:GetBottom() }
	ok(n.t <= r.sub:GetBottom() + 0.5, mode .. " " .. key .. ": under the sub line: " .. n.t .. " vs " .. r.sub:GetBottom())
	ok(n.b >= r:GetBottom() - 0.5, mode .. " " .. key .. ": inside its row: " .. n.b .. " vs " .. r:GetBottom())
	local nextRow
	for i, row in ipairs(r.group.rows) do if row == r then nextRow = r.group.rows[i + 1] end end
	ok(nextRow, mode .. " " .. key .. ": a row follows")
	ok(nextRow:GetTop() <= n.b + 0.5, mode .. " " .. key .. ": the next row starts below the line: " .. nextRow:GetTop() .. " vs " .. n.b)
	ok(H.truncation(note.text, true) == nil, mode .. " " .. key .. ": not cut")
	local tl, tr = note.text:GetLeft(), note.text:GetRight()
	ok(tl >= r:GetLeft() - 0.5 and tr <= r:GetRight() + 0.5, mode .. " " .. key .. ": within the card's width")
	local card = r.group
	ok(r:GetBottom() >= card:GetBottom() - 0.5, mode .. " " .. key .. ": the card holds the row")
	return ctl, note
end

for _, wide in ipairs({ false, true }) do
	local mode = wide and "wide" or "narrow"
	test("v24 qw-b wontdo: both lines sit under their switch, wrapped, whole, " .. mode, function()
		local w, c, st = open(wide)
		check(c, st, "autoInvite", INVITE, "Invite riders who whisper me", "Whispers and Wuber app requests.", mode)
		check(c, st, "autoReply", REPLY, "Whisper back to public requests", "Advanced: one whisper, then they whisper you.", mode)
		T.clean(w)
	end)

	test("v24 qw-b wontdo: the lines stay with the switch off, " .. mode, function()
		local w, c, st = open(wide)
		for _, key in ipairs({ "autoInvite", "autoReply" }) do
			local ctl = st.controls["drive." .. key]
			ctl.put(false)
			c.W.UI.UpdateSettings()
			w:advance(1)
			ok(not c.W.Drive.opts()[key], key .. " is off")
		end
		check(c, st, "autoInvite", INVITE, "Invite riders who whisper me", "Whispers and Wuber app requests.", mode .. " off")
		check(c, st, "autoReply", REPLY, "Whisper back to public requests", "Advanced: one whisper, then they whisper you.", mode .. " off")
		T.clean(w)
	end)
end

test("v24 qw-b wontdo: the words live in one table", function()
	local w, c = open(false)
	local P = c.W.Mod("UI.Settings.Rows").NOTES
	eq(P.inviteNote, INVITE, "invite words")
	eq(P.replyNote, REPLY, "reply words")
	T.clean(w)
end)