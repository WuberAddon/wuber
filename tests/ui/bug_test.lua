-- Tests of UI.Bug (2.3.2, R3): /wuber bug makes a report to copy. Loaded by tests/run.lua with
-- its helper table T.
--   The contract; the report has every field (version, build, scale, folded, role, open, the
--   error log, the event log, what happened); other players' names become "player 1", "player 2"
--   (the same name the same number); nothing from chat; nothing is sent; /wuber bug, the Settings
--   row and the Help row open it; every control has a tooltip.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end

local function sent(w)
	return #w.addonLog + #w.whispers + #(w.chatPosts or {})
end

test("ui.bug: contract (registered, deps, header, public names)", function()
	local W, w = T.contract("UI.Bug", "tests/ui/bug_test.lua", {
		["UI.Bug"] = "table", ["UI.Bug.Open"] = "function", ["UI.Bug.Close"] = "function",
		["UI.Bug.Shown"] = "function", ["UI.Bug.Report"] = "function",
		["W.errorLog"] = "table", ["W.eventLog"] = "table",
	})
	ok(W, "loaded")
	T.clean(w)
end)

test("ui.bug: the report has every field, the last errors and events, and what happened", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	local W = r.W
	for i = 1, 12 do W.Error("test", "boom " .. i) end
	W.Error("test", "boom 12")
	for i = 1, 25 do W.Fire("BUG_TEST_" .. i) end
	W.Fire("BUG_TEST_25")
	local text = W.UI.Bug.Report("The button did nothing")
	for _, part in ipairs({ "Wuber " .. W.VERSION, "Game build: ", "UI scale: ", "Window: closed", "folded",
		"Role: rider", "Service: ", "Errors (last 10)", "Events (last 20)", "What happened", "The button did nothing" }) do
		ok(has(text, part), "the report has " .. part .. "\n" .. text)
	end
	ok(has(text, "boom 12 (x2)"), "a repeat only counts")
	ok(has(text, "boom 3"), "the 10th last error")
	ok(not has(text, "boom 2\n") and not has(text, "boom 1\n"), "only the last 10 errors")
	ok(has(text, "BUG_TEST_25 (x2)") and has(text, "BUG_TEST_7"), "the last 20 events")
	ok(not has(text, "BUG_TEST_5\n"), "only the last 20 events")
	-- a driver's report says driver and whether the service is open
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	local dt = d.W.UI.Bug.Report("")
	ok(has(dt, "Role: driver"), "a Warlock is a driver: " .. dt)
	ok(has(dt, "Service: closed") or has(dt, "Service: open"), "open or closed")
	W.lastError = nil
	T.clean(w)
end)

test("ui.bug: other players' names become player 1, player 2; nothing from chat", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	local b = T.driver(w, T.BOB)
	T.settle(w)
	d.W.Char().drive = true
	b.W.Char().drive = true
	w:advance(40)
	local W = r.W
	ok(W.drivers and next(W.drivers), "drivers heard")
	W.Error("RIDE", "Anita Lift's ride: no reply from Bob Stone")
	W.Error("RIDE", "again Anita-Lift")
	w:chatFrom(T.CAL, "WTB summon to Ratchet zebrafish", "CHANNEL", "Trade")
	W.Debug("advert", "posted in Trade: summons to Ratchet aardvark")
	w:advance(2)
	local text = W.UI.Bug.Report("Anita Lift invited me, then Bob left. I am Wuber TestCharacter.")
	for _, name in ipairs({ "Anita", "Bob", "Stone", "TestCharacter", "Lift" }) do
		ok(not has(text, name), "no " .. name .. " in the report:\n" .. text)
	end
	ok(has(text, "player 1's ride: no reply from player 2"), "each name a number")
	ok(has(text, "again player 1"), "the same name, the same number")
	ok(has(text, "player 1 invited me, then player 2 left"), "in what happened too")
	ok(has(text, "I am me."), "your own name is me")
	ok(not has(text, "zebrafish") and not has(text, "aardvark") and not has(text, "WTB"), "nothing from chat")
	W.lastError = nil
	-- a driver's riders (DR.customers) are left out too
	d.W.Drive.customers["cal brown"] = { key = "cal brown", name = T.CAL }
	d.W.Error("trade", "Cal Brown paid twice")
	local dt = d.W.UI.Bug.Report("")
	ok(not has(dt, "Cal") and has(dt, "player 1 paid twice"), "a rider's name is left out: " .. dt)
	d.W.Drive.customers["cal brown"] = nil
	d.W.lastError = nil
	T.clean(w)
end)

test("ui.bug: two-letter names, whole and capitalised only; Name-Realm in errors (review)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.BOB)   -- (the default rider is the test character, whose first name "Wuber" the report would hide inside "Wuber/UI/Bug.lua")
	T.settle(w)
	local W = r.W
	W.db.hidden["Al"] = true
	W.Error("RIDE", "Al left; an alpaca, al dente, Halo, Al")
	W.Error("net", "whisper to Zed-Argent failed; Zed-Argent again; DRIVE-STATE; Wuber/UI/Bug.lua")
	local text = W.UI.Bug.Report("Al said hi to all at Algalon")
	ok(has(text, "player 1 left; an alpaca, al dente, Halo, player 1"), "only the whole, capitalised Al:\n" .. text)
	ok(has(text, "player 1 said hi to all at Algalon"), "in what happened too")
	ok(has(text, "whisper to player 2 failed; player 2 again; DRIVE-STATE; Wuber/UI/Bug.lua"), "Name-Realm is a player, the same number:\n" .. text)
	ok(not has(text, "Zed") and not has(text, "Argent"), "no Zed-Argent")
	W.db.hidden["Al"] = nil
	W.lastError = nil
	T.clean(w)
end)

test("ui.bug: W.Fire's repeats only count (no new entry)", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	local W = r.W
	W.Fire("BUG_REPEAT")
	local log = W.eventLog
	local last, n = log[#log], #log
	for _ = 1, 50 do W.Fire("BUG_REPEAT") end
	eq(#log, n, "no new entries")
	ok(log[#log] == last and last.n == 51, "the same entry counts: " .. tostring(last.n))
	T.clean(w)
end)

test("ui.bug: /wuber bug opens it, the box holds the report, typing folds in, nothing is sent", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	local W, UI = r.W, r.W.UI
	local before = sent(w)
	W.SlashCommand("bug")
	ok(UI.Bug.Shown(), "/wuber bug opens it")
	w:advance(3) -- the sheet rises before the player can reach its buttons
	local f = UI.Bug.frame
	ok(f and H.visible(f), "the window shows")
	ok(#r:findText("CurseForge", true, true) > 0, "it says where to paste it")
	ok(has(f.copy:Text(), "Wuber " .. W.VERSION), "the copy box holds the report")
	ok(f.copy.edit:HasFocus(), "the copy box has the focus (select all, Ctrl+C)")
	r:type(f.note.edit, "It froze on the map", false)
	ok(has(f.copy:Text(), "It froze on the map"), "what happened is folded in")
	-- the copy box is read-only: typing puts the report back
	r:type(f.copy.edit, "rubbish", false)
	ok(has(f.copy:Text(), "Wuber " .. W.VERSION) and not has(f.copy:Text(), "rubbish"), "read-only")
	r:click(f.select)
	ok(f.copy.edit:HasFocus(), "Select all focuses the report")
	eq(sent(w), before, "nothing sent (no addon message, whisper or chat)")
	for _, c in ipairs({ f.note.edit, f.copy.edit, f.select, f.close }) do
		ok(c.wuberTip and c.wuberTip.title, "every control has a tooltip")
	end
	r:click(f.close)
	ok(not UI.Bug.Shown(), "Close closes it")
	W.SlashCommand("bug")
	ok(UI.Bug.Shown(), "opens again")
	eq(f.note:Text(), "", "a fresh report each time")
	r:pressEscape()
	ok(not UI.Bug.Shown(), "Escape closes it")
	eq(sent(w), before, "still nothing sent")
	T.clean(w)
end)

test("ui.bug: Report a bug in Settings and in Help opens it", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	local UI = r.W.UI
	r.W.db.coach = true
	UI.Toggle(true)
	w:advance(3)
	-- (the Settings diet) the row on This window left; the Report a bug card on the folded home stays
	UI.OpenSettings("window")
	w:advance(1)
	ok(UI.settings.controls.bug == nil, "no Report a bug row on This window any more")
	UI.settings.view = "home"
	UI.LayoutSettings()
	local b = UI.settings.find and UI.settings.find.bug
	ok(b and H.visible(b), "a Report a bug card on the Settings home")
	ok(b.wuberTip, "its card has a tooltip")
	ok(r:scrollIntoView(b), "the player scrolls to the card")
	r:click(b)
	ok(UI.Bug.Shown(), "the Settings card opens it")
	UI.Bug.Close()
	UI.OpenHelp("settings")
	w:advance(1)
	local hb = UI.settings.help.bug
	ok(hb and H.visible(hb), "a Report a bug row in Help")
	ok(hb.wuberTip, "its button has a tooltip")
	ok(r:scrollIntoView(hb), "the player scrolls to the row")
	r:click(hb)
	ok(UI.Bug.Shown(), "the Help row opens it")
	T.clean(w)
end)
