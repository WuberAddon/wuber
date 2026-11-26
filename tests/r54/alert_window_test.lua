-- Item 1 (2.4.4): "This is my alert window" Settings switch and first-hello guard.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end

test("alert window: stranger hello ignored when on (including spoofed payload)", function()
	local w = T.newWorld()
	local wub = T.rider(w, T.BOB, { spot = "Orgrimmar", class = "MAGE" })
	local stranger = T.driver(w, T.CAL, { spot = "Undercity", class = "WARLOCK" })
	T.settle(w)

	eq(wub.W.Drive.AlertWindow and wub.W.Drive.AlertWindow() or false, false, "off by default")
	wub.W.SetAdvanced(true)
	wub.W.UI.OpenSettings("driving")
	w:advance(1)
	local sw = wub.W.UI.settings and wub.W.UI.settings.controls and wub.W.UI.settings.controls["drive.alertWindow"]
	ok(sw ~= nil, "Settings switch drive.alertWindow exists")
	eq(sw.get(), false, "Settings switch is off by default")
	eq(sw.row.title:GetText(), "This is my alert window", "exact row name")
	local tip
	for _, e in ipairs(wub.W.UI.settings.index or {}) do
		if e.frame == sw.row then tip = e.tip break end
	end
	eq(tip, "On: this window takes the first crew hello only from your own driver, so nobody else can make your alert ring. Turn it on in the window you keep for alerts.", "exact tooltip")

	sw:Click()
	w:advance(1)
	eq(sw.get(), true, "Settings switch is on after click")
	eq(wub.W.Drive.AlertWindow(), true, "switch turns AlertWindow on")

	-- Stranger sends BH directly and also tries a spoofed BH naming another driver in payload
	stranger.W.Drive.BellSet(T.BOB)
	w:advance(3)
	eq(#wub.W.db.drive.bell.team, 0, "stranger BH ignored when alert window is on")
	ok(wub.W.Drive.bell.ignored >= 1, "stranger hello counted as ignored")

	wub:fire("CHAT_MSG_ADDON", "WUBERT", "BH~1~Ana~ana smith," .. key(T.CAL) .. "~Ana~2.4.4", "WHISPER", T.CAL)
	w:advance(1)
	eq(#wub.W.db.drive.bell.team, 0, "spoofed payload BH from stranger still ignored")

	wub:fire("CHAT_MSG_ADDON", "WUBERT", "BE~1~Cal~Cal: fake alert", "WHISPER", T.CAL)
	w:advance(1)
	eq(wub.W.db.drive.bell.count, 0, "stranger BE does not ring")
	T.clean(w)
end)

test("alert window: own driver accepted when on", function()
	local w = T.newWorld()
	local ana = T.driver(w, T.ANA, { spot = "Undercity", class = "WARLOCK" })
	local wub = T.rider(w, T.BOB, { spot = "Orgrimmar", class = "MAGE" })
	T.settle(w)

	wub.W.Drive.SetAlertWindow(true)
	wub.W.Drive.SetBookOwn(key(T.ANA), true)

	ana.W.Drive.BellSet(T.BOB)
	w:advance(3)
	eq(#wub.W.db.drive.bell.team, 1, "own driver BH accepted when alert window is on")
	eq(wub.W.db.drive.bell.team[1], key(T.ANA), "own driver key learned")

	ana.W.Drive.BellTest()
	w:advance(2)
	eq(wub.W.db.drive.bell.count, 1, "own driver alert rings")

	-- Also works when own driver is known via crew/captain
	local w2 = T.newWorld()
	local ana2 = T.driver(w2, T.ANA, { spot = "Undercity", class = "WARLOCK" })
	local savedCrew = { Wuber = { chars = { [key(T.BOB)] = { captain = T.ANA, alertWindow = true } } } }
	local wub2 = T.rider(w2, T.BOB, { spot = "Orgrimmar", class = "MAGE", saved = savedCrew })
	T.settle(w2)
	ana2.W.Drive.BellSet(T.BOB)
	w2:advance(3)
	eq(#wub2.W.db.drive.bell.team, 1, "crew captain BH accepted when alert window is on")
	eq(wub2.W.db.drive.bell.team[1], key(T.ANA), "crew captain key learned")

	T.clean(w)
	T.clean(w2)
end)

test("alert window: today's behaviour unchanged when off", function()
	local w = T.newWorld()
	local stranger = T.driver(w, T.CAL, { spot = "Undercity", class = "WARLOCK" })
	local wub = T.rider(w, T.BOB, { spot = "Orgrimmar", class = "MAGE" })
	T.settle(w)

	eq(wub.W.Drive.AlertWindow(), false, "off by default")
	stranger.W.Drive.BellSet(T.BOB)
	w:advance(3)
	eq(#wub.W.db.drive.bell.team, 1, "first hello accepted when off")
	eq(wub.W.db.drive.bell.team[1], key(T.CAL), "sender learned when off")
	T.clean(w)
end)

test("alert window: setting saved over a reload", function()
	local w = T.newWorld()
	local wub = T.rider(w, T.BOB, { spot = "Orgrimmar", class = "MAGE" })
	T.settle(w)

	wub.W.Drive.SetAlertWindow(true)
	eq(wub.W.Char().alertWindow, true, "saved per character before reload")

	wub = w:reload(wub)
	T.settle(w)

	eq(wub.W.Drive.AlertWindow(), true, "AlertWindow still true after reload")
	eq(wub.W.Char().alertWindow, true, "Char().alertWindow still true after reload")
	wub.W.SetAdvanced(true)
	wub.W.UI.OpenSettings("driving")
	w:advance(1)
	local sw = wub.W.UI.settings and wub.W.UI.settings.controls and wub.W.UI.settings.controls["drive.alertWindow"]
	ok(sw ~= nil and sw.get() == true, "Settings switch still on after reload")
	T.clean(w)
end)
