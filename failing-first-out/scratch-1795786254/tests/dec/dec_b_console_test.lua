-- Decisions round, group B: the driver console. FAB-02 (Close asks while riders are listed), AUD-196 (Shift-Skip on a
-- rider only owed a sorry says the plain toast), AUD-182 (the community tip is hidden off the founder ruleset).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function ridden(w)
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d)
	T.requestVia(r, "anita lift")
	w:advance(8)
	local c = d.W.Drive.customers[key(T.TESTCHAR)]
	ok(c and c.state == "joined", "setup: Wuber is in Anita's group (" .. tostring(c and c.state) .. ")")
	return d, r, c
end

local function popup(d)
	local env = d.env
	local dlg = env.StaticPopupDialogs and env.StaticPopupDialogs.WUBER_CLOSE_RIDERS
	local shown = env.StaticPopup_FindVisible and env.StaticPopup_FindVisible("WUBER_CLOSE_RIDERS")
	return dlg, shown
end

test("dec b: Close with a rider listed asks '1 rider is still with you. Close anyway?'; Cancel keeps it open, Yes closes", function()
	local w = T.newWorld()
	local d = ridden(w)
	local D = d.W.Driver
	D.SetOnline(false)
	w:advance(1)
	local dlg, shown = popup(d)
	ok(dlg and shown, "a question is on screen")
	eq(dlg and dlg.text, "1 rider is still with you. Close anyway?")
	eq(dlg and dlg.button1, "Yes")
	eq(dlg and dlg.button2, "Cancel")
	ok(d.W.Drive.IsOpen(), "still open while the question is up")
	d.env.StaticPopup_Hide("WUBER_CLOSE_RIDERS")
	dlg.OnCancel()
	w:advance(1)
	ok(d.W.Drive.IsOpen(), "Cancel: stays open")
	D.SetOnline(false)
	w:advance(1)
	dlg = popup(d)
	d.env.StaticPopup_Hide("WUBER_CLOSE_RIDERS")
	dlg.OnAccept()
	w:advance(1)
	ok(not d.W.Drive.IsOpen(), "Yes: closed as before")
	T.clean(w)
end)

test("dec b: the question says '2 riders are' with two riders, and a grey lead row is not a rider", function()
	local w = T.newWorld()
	local d = ridden(w)
	local DR = d.W.Drive
	DR.customers["fake lead"] = { name = "Fake Lead", key = "fake lead", state = "lead", order = 98 }
	d.W.Driver.SetOnline(false)
	local dlg = popup(d)
	eq(dlg and dlg.text, "1 rider is still with you. Close anyway?", "the lead row is not counted")
	d.env.StaticPopup_Hide("WUBER_CLOSE_RIDERS")
	DR.customers["fake two"] = { name = "Fake Two", key = "fake two", state = "queued", order = 99 }
	d.W.Driver.SetOnline(false)
	dlg = popup(d)
	eq(dlg and dlg.text, "2 riders are still with you. Close anyway?")
	d.env.StaticPopup_Hide("WUBER_CLOSE_RIDERS")
	T.clean(w)
end)

test("dec b: Close with nobody listed closes at once", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	T.goOnline(d)
	d.W.Driver.SetOnline(false)
	local dlg, shown = popup(d)
	ok(not shown, "no question")
	ok(not d.W.Drive.IsOpen(), "closed")
	T.clean(w)
end)

test("dec b: AUD-196 Shift-click Skip on a rider only owed a sorry says the plain toast", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:addBot("Dan Miller", { spot = "Ratchet", acceptsInvites = false })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	ok(DR.SetOpen(true), "open")
	w:advance(3)
	w:botWhisper("Dan Miller", a, "summon pls")
	w:advance(3)
	w:move(T.ANITA, "Orgrimmar")
	w:advance(5)
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(2)
	local c, kind = DR.SkipTarget()
	ok(c and kind == "moved", "setup: kind=" .. tostring(kind))
	local v = W.Driver.ui.console
	a.mods.shift = true
	a:click(v.skip)
	a.mods.shift = nil
	w:advance(1)
	ok(not (DR.db.blocklist and DR.db.blocklist["dan miller"]), "Dan was not blocked")
	local fs = a:findText("skipped")[1]
	local txt = fs and fs:GetText() or "(no toast)"
	ok(fs and not txt:find("blocked", 1, true), "toast is '" .. txt .. "'")
	T.clean(w)
end)

test("dec b: AUD-182 off the founder ruleset the community tip is hidden", function()
	local w = T.newWorld({ clubs = true })
	local d = w:addClient("Bob Stone", { spot = "Ratchet", class = "WARLOCK", money = 100000, realm = "CAMWOW US2 Realm 1 PvE" })
	T.settle(w, 25)
	ok(d.W.Ruleset() == "US-PvE", "ruleset is " .. tostring(d.W.Ruleset()))
	d.W.Char().wizard = true
	d.W.UI.Toggle(true) w:advance(2.5)
	d:clickText("Drive") w:advance(1)
	ok(#d:findText("Tip: join the Wuber community for more visibility") == 0, "the tip is not shown")
	T.clean(w)
end)
