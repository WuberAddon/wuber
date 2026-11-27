-- Tests from the Big Batch 3 mutation run: UI/Driver/Build.lua guards.
-- Each test guards one line that no other test noticed when it was broken. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function openConsole(w, a, raid)
	T.openDrive(a)
	a.W.UI.ShowDrive("console")
	w:advance(1)
	if raid then
		a.W.Drive.SetMode("raid")
		w:advance(1)
	end
	a.W.Driver.RefreshNow()
	w:advance(1)
	return a.W.Driver.ui.console
end

-- guards Wuber/UI/Driver/Build.lua:348 (and to or in v.slot tooltip)
test("mutation b3 driver build: big button tooltip handles missing plan say and includes it when present", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local v = openConsole(w, a)
	a.W.Drive.button = { plan = {} }
	v.slot:GetScript("OnEnter")(v.slot)
	ok(#a:findText("Its words always say", false, true) > 0, "tooltip shows base explanation when plan has no say")
	a.W.Drive.button = { plan = { say = "Summon Bob Jones to Orgrimmar" } }
	v.slot:GetScript("OnEnter")(v.slot)
	ok(#a:findText("Summon Bob Jones to Orgrimmar", false, true) > 0, "tooltip shows the current plan say line")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Build.lua:366 (== to ~= on IsShiftKeyDown in v.skip OnClick)
test("mutation b3 driver build: plain click on Skip removes rider without blocking", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	w:addBot(T.BOB, { spot = "Ratchet", class = "MAGE" })
	T.settle(w)
	a.W.Drive.Request(T.BOB, "whisper", "123")
	w:advance(1)
	local v = openConsole(w, a)
	a.env.IsShiftKeyDown = function() return false end
	v.skip:GetScript("OnClick")(v.skip)
	w:advance(1)
	eq(a.W.Drive.db.blocklist[a.W.Key(T.BOB)], nil, "plain Skip does not add rider to blocklist")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Build.lua:369 (local list = nil in v.skip OnClick)
-- guards Wuber/UI/Driver/Build.lua:370 (and to or in target = block and dr("SkipTarget"))
test("mutation b3 driver build: shift-click on Skip toasts that the rider was skipped and blocked", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	w:addBot(T.BOB, { spot = "Ratchet", class = "MAGE" })
	T.settle(w)
	a.W.Drive.Request(T.BOB, "whisper", "123")
	w:advance(1)
	local v = openConsole(w, a)
	a.env.IsShiftKeyDown = function() return true end
	v.skip:GetScript("OnClick")(v.skip)
	w:advance(1)
	ok(a.W.Drive.db.blocklist[a.W.Key(T.BOB)] ~= nil, "control: shift-Skip added rider to blocklist")
	ok(#a:findText("is skipped and blocked", false, true) > 0, "toast says rider is skipped and blocked")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Build.lua:415 (and to or in v.open raid tooltip title)
test("mutation b3 driver build: closed raid Start button tooltip title says Start", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local v = openConsole(w, a, true)
	a.W.Drive.SetOpen(false)
	w:advance(1)
	local st = (T.H and T.H.state) or T.state
	st[v.open].scripts.OnEnter(v.open)
	local tip = a.env.WuberTip
	ok(tip and tip:IsShown(), "tooltip card is shown")
	eq(tip.title:GetText(), "Start", "tooltip title says Start when raid summons are stopped")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Build.lua:554 (== to ~= on m.app == false in crewChip tooltip)
test("mutation b3 driver build: crew chip tooltip does not claim a Wuber crewmate lacks Wuber", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANA, { spot = "Orgrimmar" })
	local b = T.driver(w, T.BEA, { spot = "Orgrimmar" })
	T.settle(w)
	w:group({ T.ANA, T.BEA })
	w:advance(2)
	ok(a.W.Drive.OfferCrew(T.BEA), "setup: Ana offers crew")
	w:advance(2)
	b.W.Drive.AnswerOffer(T.ANA, true)
	w:advance(2)
	local v = openConsole(w, a)
	local chip = v.chips and v.chips[1]
	ok(chip and chip:IsShown(), "control: crew chip is shown")
	local st = (T.H and T.H.state) or T.state
	st[chip].scripts.OnEnter(chip)
	eq(#a:findText("Doesn't have Wuber", false, true), 0, "Wuber crewmate tooltip does not say Doesn't have Wuber")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Build.lua:626 (delete toast in D.SetMode when DR.SetMode missing)
-- guards Wuber/UI/Driver/Build.lua:627 (return nil instead of false in D.SetMode when DR.SetMode missing)
test("mutation b3 driver build: SetMode warns and returns false when Drive.SetMode is unavailable", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	openConsole(w, a)
	local orig = a.W.Drive.SetMode
	a.W.Drive.SetMode = nil
	local res = a.W.Driver.SetMode("raid")
	a.W.Drive.SetMode = orig
	eq(res, false, "SetMode returns false when Drive.SetMode is missing")
	ok(#a:findText("Raid summons aren't ready", false, true) > 0, "warning toast is shown")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Build.lua:633 (~= to == in D.SetMode return)
test("mutation b3 driver build: SetMode returns true when switching mode succeeds", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	openConsole(w, a)
	eq(a.W.Driver.SetMode("raid"), true, "SetMode returns true when switching to raid succeeds")
	eq(a.W.Drive.Mode(), "raid", "mode switched to raid")
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Build.lua:792 (negate if not IsWarlock() in welcome skip OnClick)
test("mutation b3 driver build: warlock clicking Just open the console on welcome marks welcomed and opens console", function()
	local w = T.newWorld()
	local a = T.rider(w, T.ANITA, { spot = "Orgrimmar", class = "WARLOCK" })
	T.settle(w)
	T.openDrive(a)
	a.W.UI.ShowDrive("welcome")
	w:advance(1)
	local welcome = a.W.Driver.ui.welcome
	ok(welcome and welcome.skip, "control: welcome skip button exists")
	welcome.skip:GetScript("OnClick")(welcome.skip)
	w:advance(1)
	eq(a.W.Char().welcomed, true, "warlock clicking Just open the console sets welcomed = true")
	T.clean(w)
end)
