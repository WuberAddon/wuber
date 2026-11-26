-- Tests of UI.Settings.Rows (round 13, agent B: a reviewer's in-game screenshot findings). Loaded by
-- tests/run.lua with its helper table T. Driving's rows sit under a heading that fits them.
-- Round 13, A, I7: a row's name and line never run under its button or switch; in every section,
-- folded and unfolded, each label ends before the control on its row, and its words fit the room it has.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function open(c, w, where)
	c.W.db.coach = true
	c.W.UI.Toggle(true)
	w:advance(3)
	c.W.UI.OpenSettings(where)
	w:advance(1)
	return c.W.UI.settings
end

-- the section heading right above a row (headings are sentence case, "Driving: ...")
local function headingOver(c, row)
	local best, bestTop
	-- (design 2) headings do not say the page's name again: "Riders and notes", not "Riders and notes"
	for _, fs in ipairs(c.W.UI.settings.headings or {}) do
		local t = fs:GetTop()
		if t and t > row:GetTop() and (not bestTop or t < bestTop) then best, bestTop = fs, t end
	end
	return best and best:GetText()
end

test("ui.settings.rows: I26 the passphrase has its own heading, not Fair split's; the rows that left (Show what riders want, notes, the split) are not on Settings", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local st = open(d, w, "driving")
	local row = st.controls["drive.showPass"] and st.controls["drive.showPass"]:GetParent()
	ok(row, "drive.showPass: its row")
	eq(headingOver(d, row), "Riders and notes", "drive.showPass: under its own heading")
	-- (the Settings diet) these rows left for good; the options live on (typed commands, the Crew page)
	for _, key in ipairs({ "drive.watchBounty", "drive.shareNotes", "drive.cutRule", "drive.cutCaster" }) do
		ok(st.controls[key] == nil, key .. ": no longer a Settings row")
	end
	T.clean(w)
end)

test("ui.settings.rows r13 I7: no row's name or line runs under its button or switch", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local W = d.W
	local UI = W.UI
	W.db.coach = true
	UI.Toggle(true)
	w:advance(3)
	local bad, looked = {}, 0
	for _, wide in ipairs({ false, true }) do
		d.wide = wide
		W.db.fold = (not wide) and { v = 1, pages = {}, narrow = true } or nil
		UI.Fold.Apply()
		w:advance(1)
		for _, where in ipairs({ "riding", "driving", "map", "sound", "window" }) do
			UI.OpenSettings(where)
			w:advance(1)
			local st = UI.settings
			for key, ctl in pairs(st.controls or {}) do
				local row = type(ctl) == "table" and ctl.GetParent and ctl:GetParent()
				if row and row.label and H.visible(ctl) and H.visible(row.label) then
					looked = looked + 1
					local cr = H.rect(ctl)
					for _, fs in ipairs({ row.label, row.desc }) do
						local text = fs and fs:GetText()
						if text and text ~= "" and H.visible(fs) then
							local lr = H.rect(fs)
							local overlapY = lr.b < cr.b + cr.h and lr.b + lr.h > cr.b
							if overlapY and lr.l + lr.w > cr.l - 2 then
								bad[#bad + 1] = ("%s %s: %q ends at %d, its control starts at %d"):format(wide and "unfolded" or "folded", key, text, lr.l + lr.w, cr.l)
							end
							local need = W.Theme.MeasureText(text, fs.wuberPx or 13, fs.wuberWeight)
							if fs:CanWordWrap() == false and need / 1.03 > lr.w + 1 then
								bad[#bad + 1] = ("%s %s: %q needs %d px, has %d"):format(wide and "unfolded" or "folded", key, text, need, lr.w)
							end
						end
					end
				end
			end
		end
	end
	ok(looked >= 20, "rows with a control looked at (" .. looked .. ")")
	eq(#bad, 0, "labels under their controls or cut:\n  " .. table.concat(bad, "\n  "))
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("ui.settings.rows 2.3.2 S7: a one-line toggle card is as tall as its neighbour (wrapped at its final width)", function()
	local w = T.newWorld()
	local c = T.rider(w)
	T.settle(w)
	local st = open(c, w, "riding")
	local a, b = st.controls.autoAccept.row, st.controls.autoLeave.row
	ok(a and b, "rows")
	eq(a:GetHeight(), b:GetHeight(), "same height")
	T.clean(w)
end)

test("ui.settings.rows: BRIEF18 00:55 the two invite switches say what each covers (whispers and app; public chat)", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local st = open(d, w, "driving")
	local function texts(key)
		local t = st.controls[key]
		ok(t, key .. ": the switch")
		local row = t.row or t:GetParent()
		local tip = row.wuberTip or t.wuberTip
		local body = tip and (type(tip.text) == "function" and tip.text(row) or tip.text) or ""
		return row.label:GetText(), row.desc:GetText(), body
	end
	local l1, d1, t1 = texts("drive.autoInvite")
	eq(l1, "Invite riders who whisper me")
	eq(d1, "Whispers and Wuber app requests.")
	ok(t1:find("app requests", 1, true), "its tooltip names the other way in (the 20 rewrites, W-7): " .. t1)
	ok(t1:find("A place you don't summon to waits in your list", 1, true), "and says who is never invited: " .. t1)
	local l2, d2, t2 = texts("drive.autoPublic")
	eq(l2, "Invite public chat buyers")
	ok(d2:find("chat channels you read", 1, true), "the line names the channels: " .. d2)
	ok(t2:find("Wuber can misread chat, so it asks first", 1, true) and t2:find("Off: click a name to invite", 1, true),
		"its tooltip keeps the safety fact and the off case (the 20 rewrites, W-5): " .. t2)
	T.clean(w)
end)


test("ui.settings.rows: BRIEF19 R4 Invite public chat buyers: off by default, says not whispers, asks before it turns on", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local st = open(d, w, "driving")
	local DR = d.W.Drive
	local t = st.controls["drive.autoPublic"]
	ok(t, "the switch")
	eq(t.on, false, "off for a new player")
	eq(DR.opts().autoPublic, false)
	local desc = t.row.desc:GetText()
	ok(desc:find("chat channels you read", 1, true) and desc:find("not whispers", 1, true), "the line: " .. desc)
	local which = DR.PUBLIC_POPUP
	local function shown() return d.env.StaticPopup_FindVisible(which) ~= nil end
	local function answer(yes)
		ok(shown(), "the warning is on screen")
		local dlg = d.env.StaticPopupDialogs[which]
		ok(dlg.text:find("^Wuber reads public chat channels %(Trade, LookingForGroup, Services, World, General%) and invites players who seem to want your place%."), dlg.text)
		d.env.StaticPopup_Hide(which)
		if yes then dlg.OnAccept() else dlg.OnCancel() end
		w:advance(0.5)
	end
	d:click(t)
	w:advance(0.5)
	ok(shown(), "a click asks first")
	eq(t.on, false, "the switch stays off while it asks")
	eq(DR.opts().autoPublic, false)
	answer(false)
	eq(t.on, false, "Cancel: off")
	eq(DR.opts().autoPublic, false)
	d:click(t)
	w:advance(0.5)
	answer(true)
	eq(DR.opts().autoPublic, true, "Yes: on")
	eq(t.on, true, "and the switch shows it")
	d:click(t)
	w:advance(0.5)
	ok(not shown(), "turning it off asks nothing")
	eq(DR.opts().autoPublic, false, "off")
	eq(t.on, false)
	T.clean(w)
end)


test("ui.settings.rows: R4 review #6 the warning can't be shown: the switch stays off and a toast says why", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local st = open(d, w, "driving")
	local t = st.controls["drive.autoPublic"]
	local toasts = {}
	local real = d.W.UI.Toast
	d.W.UI.Toast = function(text, ...) toasts[#toasts + 1] = text return real(text, ...) end
	local show = d.env.StaticPopup_Show
	d.env.StaticPopup_Show = function() error("no popup in this client") end -- the game would not show one
	d:click(t)
	w:advance(0.5)
	d.env.StaticPopup_Show = show
	d.W.UI.Toast = real
	eq(t.on, false, "still off")
	eq(d.W.Drive.opts().autoPublic, false)
	eq(table.concat(toasts, " / "), "Invite public chat buyers: off (the warning can't be shown right now).")
	T.clean(w)
end)

-- summons are paid: the footer never calls Wuber free
test("ui.settings.rows: BRIEF22 T1 the footer does not call Wuber free", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local txt = d.W.Mod("UI.Settings.Rows").aboutText()
	ok(not txt:lower():find("free", 1, true), "no 'free' in the footer: " .. txt)
	ok(txt:find("summons on demand", 1, true) and txt:find("no website, no server", 1, true), "still says what it is: " .. txt)
	T.clean(w)
end)

-- (E1-05) Real-game text widths can run +4.2% wider than Theme/Tokens.lua's table;
-- Driving's "One at a time" slider label and "Block and tell them" / "Block quietly"
-- segmented buttons must have enough room even at +5% text width.
test("ui.settings.rows: E1-05 Driving labels fit even with +5% real-game text width", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	local st = open(d, w, "driving")
	local Measure = d.W.Theme.MeasureText
	local bad = {}

	local sl = st.controls["drive.maxGroup"]
	ok(sl, "drive.maxGroup slider")
	sl:Set(1)
	local slText = sl.label:GetText()
	eq(slText, "One at a time", "slider value 1 shows One at a time")
	local slNeed = Measure(slText, sl.label.wuberPx or "sub", sl.label.wuberWeight or "bold") * 1.05
	local slHave = sl.label:GetWidth()
	if slHave < slNeed then
		bad[#bad + 1] = ("drive.maxGroup %q: have %.1f px, need %.1f px (+5%%)"):format(slText, slHave, slNeed)
	end

	local lseg = st.controls["drive.leavers"]
	ok(lseg, "drive.leavers segmented control")
	for i, b in ipairs(lseg.buttons or {}) do
		local txt = b.label:GetText()
		local need = Measure(txt, b.label.wuberPx or "sub", b.label.wuberWeight or "medium") * 1.05
		local have = b.label:GetWidth()
		if have < need then
			bad[#bad + 1] = ("drive.leavers[%d] %q: have %.1f px, need %.1f px (+5%%)"):format(i, txt, have, need)
		end
	end
	eq(#bad, 0, table.concat(bad, "\n  "))
	T.clean(w)
end)
