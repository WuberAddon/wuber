local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"
local function scene(assist)
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Orgrimmar", class = "WARLOCK", allowMissing = true })
	local names = { "Raider Ra", ANITA }
	w:addBot("Raider Ra", { spot = "Orgrimmar" })
	for i = 2, 6 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar" })
		names[#names + 1] = n
	end
	w:group(names)
	if assist then w:setAssist(ANITA, true) end
	w:advance(3)
	return w, a, a.W.Drive
end


local SAME = "Your captain starts and stops the raid summons."

test("r46 B AUD-126: /wuber drive on refused prints the Start button's sentence", function()
	local w, a, DR = scene(false)
	a:slash("/wuber drive raid")
	a:slash("/wuber drive on")
	ok(not DR.RaidOn(), "control: raid summons did not start")
	ok(a:said("You need lead or assist in your raid"), "the sentence is printed")
	ok(not a:said("Can't open: lead"), "no raw code")
	T.clean(w)
end)

test("r46 B AUD-126b/AUD-132: a crew member's /wuber drive on and off say the captain sentence", function()
	local w, a, DR = scene(true)
	DR.char().captain = "Boss Captain"
	DR.crewMode = "raid"
	a:slash("/wuber drive on")
	ok(a:said(SAME), "on: captain sentence")
	a:slash("/wuber drive off")
	ok(a:said(SAME), "off: captain sentence")
	ok(not a:said("Can't open"), "never says Can't open")
	T.clean(w)
end)

test("r46 B AUD-132: crew Warlock in raid mode, Start and Stop toast the captain sentence", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	local DR = W.Drive
	DR.char().captain = "Boss Captain"
	DR.crewMode = "raid"
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(2)
	local D = W.Driver
	ok(D.SetOnline(true) == false, "start refused")
	ok(#a:findText(SAME) > 0, "start toast: " .. T.list(a:visibleTexts()):sub(-200))
	ok(#a:findText("^member$") == 0, "no raw member")
	DR.crewRaidRun = true
	local played = false
	local old = W.Sound
	W.Sound = function(k, ...) if k == "close" then played = true end return old(k, ...) end
	ok(D.SetOnline(false) == false, "stop refused")
	W.Sound = old
	ok(not played, "no close sound")
	ok(DR.RaidOn(), "still running")
	T.clean(w)
end)

test("r46 B AUD-129: bind escape says the key was removed", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	w:advance(15)
	d:slash("/wuber drive bind F5")
	ok(d:said("The big button is on F5"), "control")
	d:slash("/wuber drive bind escape")
	ok(d.W.db.drive.button.key == nil, "not saved")
	ok(d:said("Escape can't be the big button's key. The key was removed."), "new line")
	ok(not d:said("The big button is on ESCAPE"), "no false claim")
	T.clean(w)
end)
