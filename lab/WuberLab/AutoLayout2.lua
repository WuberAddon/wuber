-- Wuber Lab (developer only, never ship): AutoLayout2.lua, the second half of the Auto check's rows for the layout check's
-- screens (see AutoLayout.lua for what they are and how they differ from the layout check's copies): the scenes of
-- tests/layout/sheet_states.lua, gf_b1_screens.lua, f3_j_screens.lua, dec_n_screens.lua, toast_fit_screens.lua, dec_r_screens.lua, rem_screens.lua, d4_d_screens.lua and gf_b2/gf_d_screens.lua,
-- then pay_part (extra_screens.lua's; LAST on purpose: it leaves a ride under way, and a row after it that needs none, the tip
-- card, would be skipped). lab/AUTO-COVERAGE.md has the table of ids.
--
-- Everything a row changes besides the tour's shot stubs is put back by a function handed to KIT.undo (run by L.PhotoReset, before
-- every screen and at the end of the tour), or by this file's own putBack (the Simple mode, the saved rank, the rank card).
-- Nothing is sent: the tour has every sender stubbed; the only clicks are a named, local OnClick through X.press (the Undo toast).
-- Needs a full game restart (new files).

local _, L = ...

local KIT = L.AutoLayoutKit
if not KIT then return end -- (AutoLayout.lua comes first in the TOC)

local K, P, X = L.PhotoKit, L.PhotoShotKit, L.AutoKit
local mod, shotStub = P.mod, P.shotStub
local screen, tourScreen, runOf, hookOf, hookIf, timing = KIT.screen, KIT.tourScreen, KIT.runOf, KIT.hookOf, KIT.hookIf, KIT.timing
local haveTour, gate, undo, realOf = KIT.haveTour, KIT.gate, KIT.undo, KIT.realOf

local function refreshUI(w)
	if type(w.UI) == "table" and type(w.UI.RefreshNow) == "function" then pcall(w.UI.RefreshNow) end
	if type(w.Driver) == "table" and type(w.Driver.RefreshNow) == "function" then pcall(w.Driver.RefreshNow) end
end

---------------------------------------------------------------------------
-- tests/layout/sheet_states.lua: the Report a bug sheet over the states the bug hunt found it wrong in
---------------------------------------------------------------------------

-- (the layout check calls Core.Flights.Reset first for sheet_fm_unknown, to forget the flights it knows: this Wuber has no
-- such function, and the Lab never wipes what a real game has learned, so the booking card is the tour's own)
for _, sc in ipairs({
	{ id = "sheet_fm_unknown", base = "confirm", title = "Report a bug sheet over the booking card (flight to the drivers not known): the page under the dim" },
	{ id = "sheet_done", base = "done_paid", title = "Report a bug sheet over the Done screen after a ride: the page under the dim" },
	{ id = "sheet_home_online", base = "home", title = "Report a bug sheet over Home with drivers online: the page under the dim" },
}) do
	local b0 = tourScreen(sc.base)
	local function closeSheet(w)
		local B = type(w) == "table" and type(w.UI) == "table" and w.UI.Bug
		if type(B) == "table" and type(B.Close) == "function" then pcall(B.Close) end
	end
	screen({ id = sc.id, side = b0 and b0.side or "rider", unfold = b0 and b0.unfold, title = sc.title,
		need = gate("Report a bug sheet (UI.Bug.Open, the tour's " .. sc.base .. ")", function(W)
			return type(W.UI) == "table" and type(W.UI.Bug) == "table" and type(W.UI.Bug.Open) == "function" and haveTour(sc.base)
		end),
		run = function(w)
			local r = runOf(sc.base)(w)
			if r ~= true then return r end
			local B = w.UI.Bug
			if type(B) ~= "table" or type(B.Open) ~= "function" then return "W.UI.Bug.Open is missing" end
			undo(closeSheet)
			B.Open()
			return true
		end,
		hide = function()
			closeSheet(L.W())
			local b = tourScreen(sc.base)
			if b and type(b.hide) == "function" then pcall(b.hide) end
		end })
end

---------------------------------------------------------------------------
-- tests/layout/gf_b1_screens.lua: the driver console's Group Finder card and its sheet (gf_console_none, gf_console_still, sheet_gf_list)
---------------------------------------------------------------------------

-- Nothing here calls C_LFGList: the console's reads of the listing (On, MyListing, StillListed) and the Remove button's Delist are
-- stubbed for the shot (the tour's shot stubs put them back), so no listing is made or taken away and nothing reaches the network.
do
	local function closeGfSheet(w)
		local D = type(w) == "table" and w.Driver
		local sh = type(D) == "table" and D.ui and D.ui.sheets and D.ui.sheets.gflist
		if sh and sh.frame and sh.frame.Close then pcall(sh.frame.Close, sh.frame, true) end
	end
	for _, v in ipairs({
		{ "gf_console_none", false, false, "Driver console with the Group Finder on, not listed: the status line and the List me button" },
		{ "gf_console_still", true, false, "Driver console closed, still listed in the Group Finder: the longest reminder and Remove my listing" },
		{ "sheet_gf_list", false, true, "List me in the Group Finder sheet: the steps and the note with the longest place" },
	}) do
		local id, listed, sheet = v[1], v[2], v[3]
		screen({ id = id, side = "driver", unfold = true, declares = KIT.NO_UNFOLD, title = v[4],
			need = gate("Group Finder card (W.GroupFinder, W.Driver, the tour's console_closed)", function(W)
				return type(W.GroupFinder) == "table" and type(W.Driver) == "table" and haveTour("console_closed")
			end),
			run = function(w)
				local r = runOf("console_closed")(w)
				if r ~= true then return r end
				local GF = w.GroupFinder
				local csc = w.Driver.ui and w.Driver.ui.console and w.Driver.ui.console.scroll
				if csc and csc.ScrollTo then csc:ScrollTo(0, true) end
				shotStub(w.db, "groupFinder", true)
				shotStub(GF, "On", function() return true end)
				shotStub(GF, "MyListing", function() return listed end)
				shotStub(GF, "StillListed", function() return listed end)
				shotStub(GF, "Delist", function() return false end) -- never a real RemoveListing
				if sheet then
					local c = type(w.Char) == "function" and w.Char()
					if type(c) == "table" then
						local was = c.dest
						c.dest = "Feathermoon Stronghold"
						undo(function() c.dest = was end)
					end
					undo(closeGfSheet)
					if not w.Driver.ShowSheet("gflist") then return "the sheet did not open" end
				end
				if type(w.Fire) == "function" then w.Fire("GROUPFINDER") end
				refreshUI(w)
				if csc and csc.ScrollTo then csc:ScrollTo(0, true) end
				return true
			end,
			hide = function()
				closeGfSheet(L.W())
				local b = tourScreen("console_closed")
				if b and type(b.hide) == "function" then pcall(b.hide) end
			end })
	end
end

---------------------------------------------------------------------------
-- tests/layout/f3_j_screens.lua: the What's new card (whatsnew, whatsnew_list)
---------------------------------------------------------------------------

do
	-- in a whole run the scenes before this one (the floating button's, the mid-flight card's) leave their windows up: the stage is
	-- cleared of Wuber's other windows first, so the card is judged against the phone alone
	local shownWas
	local function bigButtonDB(w)
		local Cast = mod(w, "Drive.Cast")
		return Cast and type(Cast.btnDB) == "function" and Cast.btnDB() or nil
	end
	local function clearStage(w)
		-- the driver's big button is held away (its saved "shown" choice) while the shot is up, then given back
		local b = bigButtonDB(w)
		if type(b) == "table" then
			if shownWas == nil then shownWas = (b.shown == nil) and "nil" or b.shown end
			b.shown = false
		end
		local DR, D = w.Drive, w.Driver
		if type(DR) == "table" and type(DR.Button) == "table" and type(DR.Button.Refresh) == "function" then pcall(DR.Button.Refresh) end
		if type(D) == "table" then
			if type(D.SyncMini) == "function" then pcall(D.SyncMini) end
			if type(D.UpdateMini) == "function" then pcall(D.UpdateMini) end
		end
		local IF = mod(w, "UI.InFlight")
		if IF and type(IF.Hide) == "function" then pcall(IF.Hide) end
		-- (the big button may be a secure frame: never hidden here, only by Wuber's own refresh above)
		local btn = type(DR) == "table" and DR.button
		if type(btn) == "table" and type(btn.Hide) == "function" and not (type(btn.IsProtected) == "function" and btn:IsProtected()) then pcall(btn.Hide, btn) end
	end
	local function restoreStage(w)
		if shownWas == nil then return end
		local b = bigButtonDB(w)
		if type(b) == "table" then
			if shownWas == "nil" then b.shown = nil else b.shown = shownWas end
		end
		shownWas = nil
	end
	local function haveNews(W)
		local M = mod(W, "UI.WhatsNew")
		return M and type(M.Show) == "function" and type(M.Longest) == "function"
	end
	for _, v in ipairs({
		{ "whatsnew", false, "What's new card: the pop-up (title, See what's new, Not now), over the phone" },
		{ "whatsnew_list", true, "What's new card opened by [See what's new]: the longest entry (three long lines), over the phone" },
	}) do
		screen({ id = v[1], side = "rider", unfold = true, title = v[3],
			need = gate("What's new card (UI.WhatsNew)", haveNews),
			run = function(w)
				local M = mod(w, "UI.WhatsNew")
				w.db.coach = true
				local Coach = mod(w, "UI.Coach") -- the first-open marks may be up already: stop them (as the tip card's scene does)
				if Coach and type(Coach.stopCoachForNow) == "function" then Coach.stopCoachForNow() end
				w.UI.Show("home")
				-- the tour applies the fold after this run (the phone widens when unfolded): do it now, so the card is placed beside the final phone
				local F = w.UI.Fold
				if type(F) == "table" and type(F.Apply) == "function" then pcall(F.Apply, true) end
				undo(function(W) pcall(M.Hide) restoreStage(W) end)
				clearStage(w)
				local e = M.Longest()
				if not e then return "UI.WhatsNew has no entry" end
				if not (v[2] and M.Show(e, true) or (not v[2] and M.Show(e))) then return "the What's new card did not show" end
				return true
			end,
			hide = function()
				local W = L.W()
				local M = mod(W, "UI.WhatsNew")
				if M then pcall(M.Hide) end
				restoreStage(W)
			end })
	end
end

---------------------------------------------------------------------------
-- tests/layout/dec_n_screens.lua: the "What Wuber sends" row and the Undo toast
---------------------------------------------------------------------------

do
	local function newsOf(w)
		local M = mod(w, "UI.WhatsNew")
		if M and type(M.Hide) == "function" then return M end
		return nil
	end
	-- the stage as the existing Settings scenes find it: no What's new card, the Drive tab under Settings
	local function stage(w)
		local M = newsOf(w)
		if M then pcall(M.Hide) end
		local UI = w.UI
		if type(UI.SelectTab) == "function" and type(UI.state) == "table" and UI.state.tab ~= "Drive" then
			if type(UI.CloseSettings) == "function" then pcall(UI.CloseSettings, true) end
			if type(w.Char) == "function" and type(w.Char()) == "table" then w.Char().wizard = true end
			pcall(UI.SelectTab, "Drive")
		end
		-- the driver's Messages screen, as in a whole run (the tour's Messages scenes come just before its Settings ones)
		local D = w.Driver
		if type(D) == "table" and type(D.ShowScreen) == "function" then pcall(D.ShowScreen, "messages") end
	end
	local function haveRows(W)
		local Rows = mod(W, "UI.Settings.Rows")
		return Rows and haveTour("settings")
	end
	screen({ id = "settings_sending", side = "settings", unfold = true,
		title = "Settings: Riding, the row \"What Wuber sends\" (found by the search, opened)",
		need = gate("the \"What Wuber sends\" row (UI.Settings.Rows.sendingRow)", function(W)
			local Rows = mod(W, "UI.Settings.Rows")
			return haveRows(W) and type(Rows.sendingRow) == "function"
		end),
		run = function(w)
			stage(w)
			local r = runOf("settings")(w)
			if r ~= true then return r end
			local Rows = mod(w, "UI.Settings.Rows")
			local Find, Panel = mod(w, "UI.Settings.Find"), mod(w, "UI.Settings.Panel")
			if not (Find and Panel) then return "no Settings search" end
			local hit
			for _, m in ipairs(Find.match("what wuber sends")) do if m.label == "What Wuber sends" then hit = m end end
			if not hit then return "the search does not find the row" end
			Panel.openResult(hit)
			local st = w.UI.settings
			if not (st and st.sendingRow and st.sendingRow.sub:GetText() == Rows.SENDING.text) then return "the row does not hold the whole line" end
			return true
		end })
	local toast
	-- the toast: while the tour runs UI.Toast is sunk (no toasts over the shots), so this shot puts the real one back for the call
	local function undoToast(w)
		local sunk = w.UI.Toast
		w.UI.Toast = realOf(w.UI, "Toast") or sunk
		local okT, t = pcall(w.UI.UndoToast, "12 settings reset.", function() end)
		w.UI.Toast = sunk
		toast = okT and t or nil
		return type(toast) == "table" and toast.undo and toast.undo:IsShown()
	end
	-- the toast goes with its shot (as a click on Undo; its undo does nothing)
	local function dropToast()
		local t = toast
		toast = nil
		if t and t.undo and t.undoFn then X.press(t.undo) end
	end
	local function haveUndo(W) return haveRows(W) and type(W.UI.UndoToast) == "function" end
	screen({ id = "settings_undo", side = "settings", unfold = true,
		title = "Settings: This window, a reset's toast \"12 settings reset.\" with its Undo button",
		need = gate("the Undo toast (UI.UndoToast)", haveUndo),
		run = function(w)
			stage(w)
			local r = runOf("settings")(w)
			if r ~= true then return r end
			w.UI.OpenSettings("window")
			undo(dropToast)
			if not undoToast(w) then return "the Undo toast did not show" end
			return true
		end,
		afterShot = function() dropToast() end })
	screen({ id = "settings_undo_news", side = "settings", unfold = true,
		title = "Settings: a reset's Undo toast with the What's new card up beside the phone",
		need = gate("the Undo toast and the What's new card (UI.UndoToast, UI.WhatsNew)", function(W)
			local M = newsOf(W)
			return haveUndo(W) and M and type(M.Show) == "function" and type(M.Longest) == "function"
		end),
		run = function(w)
			stage(w)
			local r = runOf("settings")(w)
			if r ~= true then return r end
			w.UI.OpenSettings("window")
			-- the tour applies the fold after this run: now, so the card is placed beside the phone as it will stand
			local F = w.UI.Fold
			if type(F) == "table" and type(F.Apply) == "function" then pcall(F.Apply, true) end
			local M = newsOf(w)
			local e = M.Longest()
			if not e then return "UI.WhatsNew has no entry" end
			undo(function() dropToast() pcall(M.Hide) end)
			-- (with no room beside Wuber's windows the card rightly waits: the shot is then the toast alone)
			M.Show(e)
			if not undoToast(w) then return "the Undo toast did not show" end
			return true
		end,
		afterShot = function()
			dropToast()
			local M = newsOf(L.W())
			if M then pcall(M.Hide) end
		end })
end

---------------------------------------------------------------------------
-- tests/layout/toast_fit_screens.lua: a toast holds its whole text (toast_long, toast_longword, toast_long_stack)
---------------------------------------------------------------------------

do
	local up = {} -- the toasts a row put up (taken away with their shot)
	local function drop()
		local list = up
		up = {}
		for _, t in ipairs(list) do
			local click = t.GetScript and t:GetScript("OnClick")
			if click and t:IsShown() then pcall(click, t, "LeftButton", false) end
		end
	end
	-- UI.Toast is sunk while the tour runs (no toasts over the shots): the real one is put back for the call
	local function showToast(w, text, kind, withUndo)
		local sunk = w.UI.Toast
		local real = realOf(w.UI, "Toast") or sunk
		w.UI.Toast = real
		local okT, t = pcall(real, text, kind, function() end)
		if okT and t and withUndo and type(w.UI.UndoToast) == "function" then
			local okU, u = pcall(w.UI.UndoToast, "3 settings reset.", function() end)
			if okU and type(u) == "table" then up[#up + 1] = u end
		end
		w.UI.Toast = sunk
		if not okT or type(t) ~= "table" then return false end
		up[#up + 1] = t
		return true
	end
	for _, v in ipairs({
		{ "toast_long", "Rider home: the toast of a long typed place, several words",
			"No place called " .. ("Stormwind Harbour Crossing "):rep(3) .. "Inn", "warn" },
		{ "toast_longword", "Rider home: the toast of a long typed place, one long word",
			"No place called " .. ("x"):rep(44) .. "~", "warn" },
		{ "toast_long_stack", "Rider home: a long toast with an Undo toast stacked under it",
			"No place called " .. ("Stormwind Harbour Crossing "):rep(1) .. "Inn", "portal", true },
	}) do
		screen({ id = v[1], side = "rider", unfold = true, title = v[2],
			need = gate("the toast (UI.Toast, the tour's home)", function(W)
				return type(W.UI) == "table" and type(W.UI.Toast) == "function" and haveTour("home")
			end),
			run = function(w)
				undo(drop)
				return runOf("home")(w)
			end,
			-- (post runs once the page has settled, after the tour set the fold and the sizes: the toast is placed against the phone as it stands)
			post = function(w)
				if not showToast(w, v[3], v[4], v[5]) then return "the toast did not show" end
				return true
			end,
			afterShot = drop })
	end
end

---------------------------------------------------------------------------
-- tests/layout/dec_r_screens.lua: the messages that can go by themselves (messages_line_greet, _pay, _next)
---------------------------------------------------------------------------

do
	local function editorOf(w)
		local m = type(w.UI.drive) == "table" and type(w.UI.drive.screens) == "table" and w.UI.drive.screens.messages
		if type(m) == "table" and type(m.edit) == "function" then return m end
	end
	local was = {} -- each switch as it stood before a row changed it
	-- the message's editor with its switch in view (the switch sits under the preview: the editor is scrolled to its end)
	local function show(w, kind, on, scroll)
		local m = editorOf(w)
		if not m then return "no message editor" end
		if not (type(w.Drive) == "table" and type(w.Drive.SetLineOn) == "function" and type(w.Drive.LineOn) == "function") then return "no DR.SetLineOn" end
		if was[kind] == nil then
			was[kind] = w.Drive.LineOn(kind) == true
			undo(function(W)
				local prev = was[kind]
				was[kind] = nil
				if prev ~= nil and type(W.Drive) == "table" and type(W.Drive.SetLineOn) == "function" then W.Drive.SetLineOn(kind, prev) end
			end)
		end
		w.Drive.SetLineOn(kind, on)
		m.edit(kind)
		local e = m.editor
		local au = type(e) == "table" and e.auto
		if not (au and au:IsShown()) then return "the switch does not show" end
		if (au.toggle.on == true) ~= (on == true) then return "the switch does not follow the saved choice" end
		if not scroll then return true end
		local sc = e:GetParent() and e:GetParent():GetParent()
		-- unfolded, the editor has its own scroll in the side pane: the list beside it starts at its top (the folded shot before
		-- this one left the page's scroll at the editor's end)
		if type(m.scroll) == "table" and sc ~= m.scroll and type(m.scroll.ScrollTo) == "function" then pcall(m.scroll.ScrollTo, m.scroll, 0, true) end
		if type(sc) == "table" and type(sc.ScrollTo) == "function" then pcall(sc.ScrollTo, sc, tonumber(sc.max) or 0, true) end
		return true
	end
	local function scene(id, kind, on, title)
		screen({ id = id, side = "driver", unfold = true, title = title,
			need = gate("self-sent messages (Drive.AutoLines, the tour's messages)", function(W) return mod(W, "Drive.AutoLines") and haveTour("messages") end),
			run = function(w)
				local r = runOf("messages")(w)
				if r ~= true then return r end
				return show(w, kind, on, false)
			end,
			-- (the tour applies the fold after run: the editor may have moved into the side pane)
			post = function(w) return show(w, kind, on, true) end,
			hide = function()
				local W = L.W()
				local prev = was[kind]
				was[kind] = nil
				if prev ~= nil and type(W.Drive) == "table" and type(W.Drive.SetLineOn) == "function" then W.Drive.SetLineOn(kind, prev) end
			end })
	end
	scene("messages_line_greet", "greet", true, "Messages: the Greeting's editor, its switch Send the greeting by itself, on")
	scene("messages_line_pay", "pay", false, "Messages: the editor of Welcome, please pay, its switch Send the pay reminder by itself, off")
	scene("messages_line_next", "next", true, "Messages: the editor of You're next, its switch Send You're next by itself, on")
end

---------------------------------------------------------------------------
-- tests/layout/rem_screens.lua: Simple mode, driver ranks and the merged Settings rows
---------------------------------------------------------------------------

do
	local state = {}
	-- everything the scenes changed, back as it was (L.PhotoReset calls this before every screen and at the end of the tour)
	local function putBack(w)
		if type(w) ~= "table" then return end
		if state.rank then
			local ch = type(w.Char) == "function" and w.Char()
			if type(ch) == "table" then ch.rank = state.rank.old end
			state.rank = nil
		end
		local f = state.rankFrame
		state.rankFrame = nil
		if f and f.IsShown and f:IsShown() and f.Close then pcall(f.Close, f, true) end
		if state.button then
			local s = state.button
			if s.was == "nil" then s.db.shown = nil else s.db.shown = s.was end
			state.button = nil
		end
		if state.simple then
			local was = state.simple.was
			state.simple = nil
			if type(w.SetAdvanced) == "function" then pcall(w.SetAdvanced, was ~= false) end
		end
	end
	do
		local reset = L.PhotoReset
		L.PhotoReset = function(w, ...)
			if reset then pcall(reset, w, ...) end
			putBack(w)
		end
	end
	-- earlier scenes leave their cards up (the What's new card is never hidden by the tour) and the driver shots before them leave
	-- the big button and its mini list on the screen: the stage is cleared first. A rider scene is judged against the phone alone:
	-- the big button is held away (its saved "shown" choice, put back by putBack) while the shot is up.
	local function clearStage(w, rider)
		local WN = mod(w, "UI.WhatsNew")
		if WN and type(WN.Hide) == "function" then pcall(WN.Hide) end
		if not rider then return end
		local Cast = mod(w, "Drive.Cast")
		local b = Cast and type(Cast.btnDB) == "function" and Cast.btnDB() or nil
		if type(b) == "table" then
			if not state.button then state.button = { db = b, was = (b.shown == nil) and "nil" or b.shown } end
			b.shown = false
		end
		local DR, D = w.Drive, w.Driver
		if type(DR) == "table" and type(DR.Button) == "table" and type(DR.Button.Refresh) == "function" then pcall(DR.Button.Refresh) end
		if type(D) == "table" then
			if type(D.SyncMini) == "function" then pcall(D.SyncMini) end
			if type(D.UpdateMini) == "function" then pcall(D.UpdateMini) end
		end
		local btn = type(DR) == "table" and DR.button -- (a secure frame is never hidden here: Wuber's own refresh above does it)
		if type(btn) == "table" and type(btn.Hide) == "function" and not (type(btn.IsProtected) == "function" and btn:IsProtected()) then pcall(btn.Hide, btn) end
	end
	local function setSaved(w, rank)
		local ch = type(w.Char) == "function" and w.Char()
		if type(ch) ~= "table" then return false end
		if not state.rank then state.rank = { old = ch.rank } end
		ch.rank = rank
		return true
	end
	local function haveSimple(W) return type(W) == "table" and type(W.SetAdvanced) == "function" and type(W.Advanced) == "function" end

	-- o: base (a tour shot id), simple (true: Simple mode before it runs), side, unfold, only, title,
	--    before(w) after(w, view) -> true or why; need(W) an extra gate (true or why), declares its words
	local function scene(id, o)
		local b0 = tourScreen(o.base)
		local e = { id = id, side = o.side or (b0 and b0.side) or "rider", title = o.title, unfold = o.unfold, only = o.only,
			wait = b0 and b0.wait or nil, maxWait = b0 and b0.maxWait or nil, noChat = b0 and b0.noChat or nil,
			ready = hookIf(o.base, "ready"), check = hookIf(o.base, "check"), afterShot = hookIf(o.base, "afterShot"),
			declares = o.declares }
		local baseNeed = gate("Simple mode (W.SetAdvanced, the tour's " .. o.base .. ")", function(W) return haveSimple(W) and haveTour(o.base) end)
		e.need = function(W)
			local r = baseNeed(W)
			if r ~= true then return r end
			if o.need then return o.need(W) end
			return true
		end
		e.run = function(w, view)
			putBack(w)
			clearStage(w, (e.side or "") ~= "driver")
			if o.simple then
				state.simple = { was = w.Advanced() }
				w.SetAdvanced(false)
			end
			if o.before then
				local r0 = o.before(w, view)
				if r0 ~= true then return r0 end
			end
			local r = runOf(o.base)(w, view)
			if r ~= true then return r end
			if o.after then
				local r2 = o.after(w, view)
				if r2 ~= true then return r2 end
			end
			refreshUI(w)
			-- the console's list starts at its top whatever an earlier shot scrolled it to (a whole run leaves it where it was)
			local v = type(w.Driver) == "table" and type(w.Driver.ui) == "table" and w.Driver.ui.console
			if o.top ~= false and type(v) == "table" and type(v.scroll) == "table" and type(v.scroll.ScrollTo) == "function" and (e.side or "") == "driver" then
				pcall(v.scroll.ScrollTo, v.scroll, 0, true)
			end
			return true
		end
		if (b0 and type(b0.post) == "function") or o.post then
			e.post = function(w, view)
				local b = tourScreen(o.base)
				if b and type(b.post) == "function" and not o.post then
					local r = b.post(w, view)
					if r ~= true then return r end
				end
				if o.post then return o.post(w, view) end
				return true
			end
		end
		return screen(e)
	end
	local function S(id, baseId, title, extra)
		-- Simple is phone-sized by rule (UI.Fold narrow(): W.Advanced() false): no unfolded shot of these
		local o = { base = baseId, simple = true, title = title, unfold = false }
		for k, v in pairs(extra or {}) do o[k] = v end
		scene(id, o)
	end

	-- the rider
	S("simple_home", "home", "Simple: the rider's list, drivers listed")
	S("simple_home_empty", "home_empty", "Simple: nobody online, the quiet OpenMap line under Why?")
	S("simple_confirm", "confirm", "Simple: Confirm, the one line Summon ... Fly about ... in place of the dial")
	S("simple_ride", "pass_rider", "Simple: in the group, waiting for the portal")
	S("simple_pay", "pay", "Simple: time to pay, three tip keys")
	S("simple_done", "done_paid", "Simple: done, paid and rated")
	S("simple_trips", "trips", "Simple: Trips")
	-- Settings
	S("simple_settings", "settings", "Simple: Settings home, the Advanced mode switch on top")
	S("simple_settings_driving", "settings_driving", "Simple: Settings > Driving, a Warlock's four rows")
	-- the driver
	S("simple_console_open", "console_open", "Simple: the console, open, riders listed")
	S("simple_console_closed", "console_closed", "Simple: the console, closed")
	S("simple_menu", "menu_chat", "Simple: a rider row's menu, five choices")
	S("simple_sheet", "console_closed", "Simple: the price sheet without Also called or Name riders see", {
		after = function(w)
			local D = w.Driver
			if type(D) ~= "table" or type(D.ShowSheet) ~= "function" then return "W.Driver.ShowSheet is missing" end
			if not D.ShowSheet("sheet") then return "no price sheet" end
			return true
		end })
	S("simple_earnings", "earnings", "Simple: Earnings")
	S("simple_shift", "shift", "Simple: the end-of-shift card")

	-- ranks
	scene("rank_row", { base = "home", simple = true, unfold = false,
		title = "Rank chips in the rider's list: a driver at 73, and the Founder with a very long name at 1,000",
		before = function(w)
			local UI = w.UI
			if type(UI) ~= "table" or type(UI.Drivers) ~= "function" then return "no W.UI.Drivers" end
			local orig, origOne = UI.Drivers, UI.Driver
			local function list(...)
				local out, mia = {}, nil
				for i, d in ipairs(orig(...)) do
					local x = {}
					for k, v in pairs(d) do x[k] = v end
					if x.key == "mia runner" then x.rank, mia = 73, x end
					out[i] = x
				end
				local like = mia or out[1]
				if like then
					local x = {}
					for k, v in pairs(like) do x[k] = v end
					x.name, x.key, x.short = "Zebediah Wolfeschlegelsteinhausen", "zebediah wolfeschlegelsteinhausen", "Zebediah Wolfeschlegelsteinhausen"
					x.service, x.creator, x.rank = "Zebediah Wolfeschlegelsteinhausen's Grand Tours", true, 1000
					out[#out + 1] = x
				end
				return out
			end
			if not shotStub(UI, "Drivers", list) then return "the tour has no stub" end
			if type(origOne) == "function" then
				shotStub(UI, "Driver", function(key, ...)
					for _, d in ipairs(list()) do if d.key == key then return d end end
					return origOne(key, ...)
				end)
			end
			return true
		end,
		post = function(w)
			local cards = type(w.UI.state) == "table" and w.UI.state.cards
			for _, key in ipairs({ "mia runner", "zebediah wolfeschlegelsteinhausen" }) do
				local c = type(cards) == "table" and cards[key]
				if not (c and c.rankChip and c.rankChip.IsShown and c.rankChip:IsShown()) then return "no rank chip on the row of " .. key end
			end
			return true
		end })
	-- (the New title card's "Tell the guild" pill shows only for a character in a guild: the layout check makes IsInGuild say yes, a
	-- global the Lab never replaces in the real game, so a character in no guild leaves this row out, and says so)
	scene("rank_card", { base = "console_closed", simple = true, unfold = false,
		title = "The New title card with Tell the guild, a driver in a guild",
		need = function()
			if type(IsInGuild) == "function" and IsInGuild() then return true end
			return "this character is in no guild (the New title card's Tell the guild pill shows only for a guild member)"
		end,
		declares = "is in no guild",
		after = function(w)
			if not setSaved(w, { n = 10, seen = {} }) then return "no saved character" end
			-- the card's frame is the result of UI.RankCard (Wuber keeps it private): taken as the DRIVE_RANK listener asks for it
			local UI = w.UI
			if type(UI.RankCard) ~= "function" then return "no UI.RankCard" end
			local ask = UI.RankCard
			shotStub(UI, "RankCard", function(...)
				local f = ask(...)
				if type(f) == "table" then state.rankFrame = f end
				return f
			end)
			w.Fire("DRIVE_RANK", 10, 2, "Cabbie", true)
			local f = state.rankFrame
			if not (f and f.IsShown and f:IsShown()) then return "the New title card did not show" end
			if not (f.pill and f.pill.IsShown and f.pill:IsShown()) then return "the card has no Tell the guild pill (guild answer not seen)" end
			return true
		end })
	scene("rank_own", { base = "console_open", simple = false, only = "unfolded",
		title = "The wide Drive page: the driver's own title line and bar (Advanced)",
		before = function(w)
			if not setSaved(w, { n = 73, seen = {} }) then return "no saved character" end
			return true
		end })

	-- merged Settings rows (Advanced)
	local function merged(id, label, title)
		scene(id, { base = "settings_driving", simple = false, unfold = true, title = title,
			after = function(w)
				local Panel = mod(w, "UI.Settings.Panel")
				if type(L.PhotoOpenSetting) ~= "function" then return "no L.PhotoOpenSetting" end
				return L.PhotoOpenSetting(w.UI, Panel, label)
			end })
	end
	merged("settings_merged", "Chat channels", "Settings > Driving (Advanced) scrolled to Group size and Chat channels")
	merged("settings_merged_big", "Big button on screen", "Settings > Driving (Advanced) scrolled to Big button on screen and Alert character")
end

---------------------------------------------------------------------------
-- tests/layout/d4_d_screens.lua: Wuber's own tooltip, the frame WuberTip (tip_edge, tip_long, tip_whole, tip_chip)
---------------------------------------------------------------------------

do
	local LONG = "Aaaaaaaaaaaaaaa-Bbbbbbbbbbbbbbbbbbb of the Very Long Realm Name"
	local function children(f, out)
		if type(f) ~= "table" or type(f.GetChildren) ~= "function" then return out end
		for _, ch in ipairs({ f:GetChildren() }) do
			out[#out + 1] = ch
			children(ch, out)
		end
		return out
	end
	-- the visible controls of the window that have a tip, each with its box in the window's own units
	local function tipped(w)
		local win = rawget(_G, "WuberFrame")
		local list = {}
		if type(win) ~= "table" then return list end
		for _, f in ipairs(children(win, {})) do
			-- (a control: the window's thin drag edges have a tip too and are no place to show one)
			if type(f.wuberTip) == "table" and type(f.wuberTip.title) == "string" and f:IsVisible() and f:GetRight() and f:GetLeft()
				and (f:GetWidth() or 0) >= 16 and (f:GetHeight() or 0) >= 16 and f.wuberTip.title ~= "Wuber" then
				list[#list + 1] = f
			end
		end
		return list, win
	end
	local function show(w, frame)
		if not frame then return "no control with a tip shows" end
		undo(function(W) if type(W.Theme) == "table" and type(W.Theme.TipHide) == "function" then W.Theme.TipHide() end end)
		frame.wuberTipShown = true
		w.Theme.RefreshTip(frame)
		if w.Theme.TipOwner() ~= frame then return "the tip did not show" end
		return true
	end
	local function haveTip(W) return type(W.Theme) == "table" and type(W.Theme.TipShow) == "function" end
	screen({ id = "tip_edge", side = "driver", unfold = true,
		title = "Wuber's tooltip at the screen's edge: the tip of the control nearest the right edge, beside it and on the screen",
		need = gate("Wuber's own tooltip (Theme.TipShow, the tour's row_marks)", function(W) return haveTip(W) and haveTour("row_marks") end),
		run = function(w) return runOf("row_marks")(w) end,
		post = function(w)
			local best
			for _, f in ipairs(tipped(w)) do
				if not best or f:GetRight() * f:GetEffectiveScale() > best:GetRight() * best:GetEffectiveScale() then best = f end
			end
			return show(w, best)
		end })
	screen({ id = "tip_long", side = "driver", unfold = true,
		title = "Wuber's tooltip with many words: it wraps at the card's width and nothing is cut",
		need = gate("Wuber's own tooltip (Theme.TipShow, the tour's row_marks)", function(W) return haveTip(W) and haveTour("row_marks") end),
		run = function(w) return runOf("row_marks")(w) end,
		post = function(w)
			local best, most = nil, 0
			for _, f in ipairs(tipped(w)) do
				local text = f.wuberTip.text
				if type(text) == "function" then
					local ok, got = pcall(text, f)
					text = ok and got or nil
				end
				if type(text) == "string" and #text > most then best, most = f, #text end
			end
			return show(w, best)
		end })
	-- (group I2) a driver row whose name is cut: hovering it shows the name whole, first, on the same card
	screen({ id = "tip_whole", side = "driver", unfold = true,
		title = "Wuber's tooltip over a cut driver-row name: the whole name first, then the row's own words, beside the row",
		need = gate("Wuber's own tooltip (Theme.TipShow, the tour's row_marks)", function(W) return haveTip(W) and haveTour("row_marks") end),
		run = function(w) return runOf("row_marks")(w) end,
		post = function(w)
			local win = rawget(_G, "WuberFrame")
			if type(win) ~= "table" then return "no window" end
			local D = w.Driver
			if type(D) ~= "table" or type(D.PaintRow) ~= "function" or type(D.Row) ~= "function" then return "no driver rows" end
			-- the console paints its rows through D.PaintRow: one rider's name is a long one from now on (a shot stub: put back before the next screen)
			local paint = D.PaintRow
			shotStub(D, "PaintRow", function(r, c, ...)
				if type(c) == "table" and c.name == "Dan Rider" then
					local copy = {}
					for k, v in pairs(c) do copy[k] = v end
					copy.name = LONG
					c = copy
				end
				return paint(r, c, ...)
			end)
			if type(D.RefreshNow) == "function" then D.RefreshNow() end
			local row
			for _, f in ipairs(children(win, {})) do
				if type(f.name) == "table" and type(f.name.GetText) == "function" and f:IsVisible() and tostring(f.name:GetText()):find("^Aaaaaaaa") then row = f end
			end
			if not row then
				local seen = {}
				for _, f in ipairs(children(win, {})) do
					if type(f.name) == "table" and type(f.name.GetText) == "function" and f:IsVisible() then seen[#seen + 1] = tostring(f.name:GetText()) end
				end
				return "the long name did not reach a row: " .. table.concat(seen, ",")
			end
			w.Theme.WholeOnHover(row.name) -- (T.Fit sets it a moment after layout; a scene does not wait)
			local owner = row.name.wuberWhole
			if not owner then return "the long name got no hover" end
			if not w.Theme.CutOneLine(row.name) then return "the long name is not cut here" end
			return show(w, owner)
		end })
	-- (group I2) the Messages screen's chips: the tip beside a chip, not on the chips below it
	local edit = tourScreen("messages_edit")
	screen({ id = "tip_chip", side = edit and edit.side or "driver", unfold = true,
		title = "A message chip's tooltip: beside the chip, covering no chip of the rows below",
		need = gate("Wuber's own tooltip (Theme.TipShow, the tour's messages_edit)", function(W) return haveTip(W) and haveTour("messages_edit") end),
		run = function(w) return runOf("messages_edit")(w) end,
		post = function(w)
			local pick
			for _, f in ipairs(tipped(w)) do
				local text = f.wuberTip.text
				if type(text) == "function" then
					local ok, got = pcall(text, f)
					if ok and type(got) == "string" and got:find("Tap to put it", 1, true) then pick = pick or f end
				end
			end
			return show(w, pick)
		end })
end

---------------------------------------------------------------------------
-- tests/layout/gf_b2_screens.lua and gf_d_screens.lua: the rider's Group Finder rows on Home
-- (home_gf, home_gf_busy, home_gf_empty, home_gf_empty_tall)
---------------------------------------------------------------------------

-- Demo values only: the Group Finder's On, ListedZone, ExtraCount, Pending, SearchCategory and Search are stubbed for the shot
-- (the tour's shot stubs put them back), so no search is made and nothing reaches the network.
do
	for _, v in ipairs({
		{ "home_gf", "home", "Rider home: Group Finder card lines, 999 more listings, no category", { zone = "Eastern Plaguelands", count = 999, nocat = true } },
		{ "home_gf_busy", "home", "Rider home: Group Finder search pending (Searching...)", { zone = "Eastern Plaguelands", count = 999, pending = true } },
		{ "home_gf_empty", "home_empty", "Rider home, nobody online: Group Finder search row above the empty state", { count = 1 } },
		{ "home_gf_empty_tall", "home_empty", "Rider home, nobody online, usual place: the tallest Group Finder card goes under the stack, Pin a bounty stays in the page",
			{ count = 999, pending = true, usual = "Ironforge" } },
	}) do
		local id, base, o = v[1], v[2], v[4]
		screen({ id = id, side = "rider", unfold = true, declares = KIT.NO_UNFOLD, title = v[3],
			need = gate("Group Finder rows (W.GroupFinder, the tour's " .. base .. ")", function(W)
				return type(W.GroupFinder) == "table" and haveTour(base)
			end),
			run = function(w, view)
				local GF = w.GroupFinder
				shotStub(w.db, "groupFinder", true)
				shotStub(GF, "On", function() return true end)
				if o.zone then shotStub(GF, "ListedZone", function() return o.zone end) end
				shotStub(GF, "ExtraCount", function() return o.count or 0 end)
				shotStub(GF, "Pending", function() return o.pending == true end)
				shotStub(GF, "SearchCategory", function() if o.nocat then return nil end return 10 end)
				shotStub(GF, "Search", function() return true end)
				if o.usual then shotStub(w, "Usual", function() return { dest = o.usual } end) end
				local r = runOf(base)(w, view)
				if r ~= true then return r end
				if w.UI.RefreshNow then w.UI.RefreshNow() end
				return true
			end,
			wait = (timing(base)), maxWait = select(2, timing(base)),
			ready = hookIf(base, "ready"), post = hookIf(base, "post"), afterShot = hookIf(base, "afterShot") })
	end
end

---------------------------------------------------------------------------
-- pay_part: LAST of the rows on purpose
---------------------------------------------------------------------------

-- (round 47 lead) NEW ROWS GO ABOVE THIS LINE. (round 46 lead) LAST on purpose: this scene leaves a ride under way, and a scene
-- after it that needs none (the tip card) would be skipped.
-- (REV-r30-1) the pay card after a part payment, the longest realistic small line: 12g 34s 56c fare, 6g 17s 28c paid, a tip, a
-- 12-letter payee ("12g 34s 56c" = 123456 copper)
screen({ id = "pay_part", side = "rider", unfold = true, declares = KIT.NO_UNFOLD,
	title = "Pay card after a part payment: fare in g/s/c, part paid, a tip, a long payee",
	need = gate("the tour's pay", function() return haveTour("pay") end),
	run = function(w)
		local r = runOf("pay")(w)
		if r ~= true then return r end
		local ride = w.ride
		if type(ride) ~= "table" then return "the pay shot has no ride" end
		ride.price, ride.payto, ride.paidSoFar = 123456, "Wolfgangbert", 61728
		w.db.tipPct = 20
		w.UI.Show("found")
		if w.UI.RefreshNow then w.UI.RefreshNow() end
		return true
	end })
