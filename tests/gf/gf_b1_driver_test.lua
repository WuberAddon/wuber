-- Group Finder (group B1): the Settings row and the driver's side of the console. Design: docs/DESIGN-GROUP-FINDER.md.
-- Every click here is a real click (client:clickOn / clickText), never Button:Click.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local WORDS
local function words(d)
	WORDS = d.W.GroupFinder.DRAFT_WORDS
	return WORDS
end

local function calls(w, name)
	local n = 0
	for _, c in ipairs(w.lfg.calls) do
		if name == nil or c == name then n = n + 1 end
	end
	return n
end

local function texts(c)
	return table.concat(c:visibleTexts(), " | ")
end
local function sees(c, text)
	for _, t in ipairs(c:visibleTexts()) do
		if t == text then return true end
	end
	return false
end

-- a driver online with his console open on the Drive tab
local function world(on)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	if on then d.W.db.groupFinder = true end
	T.goOnline(d)
	d.W.Char().wizard = true
	d.W.UI.Toggle(true)
	w:advance(2.5)
	d:clickText("Drive")
	w:advance(1.5)
	return w, d
end

local function pill(d) return d.W.Driver.ui.console.open end
local function isOpen(d) return d.W.Drive.IsOpen() == true end

test("gf b1.1: Settings: a real click on the Group Finder row's switch turns the setting on and off, and fires SETTINGS", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	local W = d.W
	local fired = {}
	W.Listen("SETTINGS", function(key) fired[#fired + 1] = key end)
	W.UI.Toggle(true)
	w:advance(2.5)
	W.UI.OpenSettings("driving")
	w:advance(1.5)
	local sw = W.UI.settings.controls.groupFinder
	ok(sw, "the Group Finder row has a switch")
	-- the player scrolls the page with the wheel until the row is on screen
	-- (visibleTexts does not look at the clip, so the label counts as seen while the row is still below the scroll frame: scroll until the switch itself is drawn)
	ok(d:scrollIntoView(sw), "the switch scrolls into view")
	ok(d:onScreen(sw), "the switch is drawn inside the scroll frame")
	ok(sees(d, words(d).settingName), "the row says its label: " .. texts(d))
	eq(W.db.groupFinder == true, false, "off by default")
	d:clickOn(sw)
	w:advance(0.5)
	eq(W.db.groupFinder, true, "a click turns it on")
	local n = 0
	for _, k in ipairs(fired) do if k == "groupFinder" then n = n + 1 end end
	ok(n >= 1, "SETTINGS groupFinder fired")
	d:clickOn(sw)
	w:advance(0.5)
	eq(W.db.groupFinder, false, "a second click turns it off")
	T.clean(w)
end)

test("gf b1.2: setting off (default): the console has no Group Finder row and no C_LFGList call happens", function()
	local w, d = world(false)
	local texts_ = texts(d)
	local WD = words(d)
	for _, key in ipairs({ "listButton", "removeButton", "listed", "notListed", "stillListed" }) do
		ok(WD[key], "DRAFT_WORDS." .. key .. " exists")
		ok(not texts_:find(WD[key], 1, true), "no '" .. key .. "' text with the setting off")
	end
	ok(not d.W.Driver.ui.console.gf or not d.W.Driver.ui.console.gf:IsShown(), "no Group Finder row is shown")
	d:lfgPost("Wuber summons to Ashenvale", 1001, "Ashenvale")
	w:advance(3)
	d:clickOn(pill(d))
	w:advance(1)
	eq(calls(w), 0, "C_LFGList calls with the setting off, even after a listing and going offline")
	T.clean(w)
end)

test("gf b1.3: setting on: the row says not listed, then listed after the driver posts in Blizzard's window", function()
	local w, d = world(true)
	local WD = words(d)
	ok(sees(d, WD.notListed), "not listed shows: " .. texts(d))
	ok(sees(d, WD.listButton), "the List me button shows")
	ok(not sees(d, WD.removeButton), "no Remove button while not listed")
	d:lfgPost("Wuber summons to Ashenvale", 1001, "Ashenvale")
	w:advance(3)
	ok(sees(d, WD.listed), "listed shows: " .. texts(d))
	ok(not sees(d, WD.notListed), "not listed is gone")
	ok(sees(d, WD.removeButton), "the Remove button shows")
	T.clean(w)
end)

test("gf b1.4: a real click on Remove my listing takes the listing away", function()
	local w, d = world(true)
	local WD = words(d)
	d:lfgPost("Wuber summons to Ashenvale", 1001, "Ashenvale")
	w:advance(3)
	d:clickText(WD.removeButton)
	w:advance(3)
	eq(w.lfg.listings[T.ANITA], nil, "the listing is gone")
	eq(d.W.GroupFinder.MyListing(), false)
	ok(sees(d, WD.notListed), "the row says not listed")
	ok(not sees(d, WD.removeButton), "the Remove button is gone")
	T.clean(w)
end)

test("gf b1.5: going offline with a real click on the Open pill while listed removes the listing and goes offline", function()
	local w, d = world(true)
	d:lfgPost("Wuber summons to Ashenvale", 1001, "Ashenvale")
	w:advance(3)
	ok(isOpen(d), "online first")
	d:clickOn(pill(d))
	w:advance(2)
	eq(isOpen(d), false, "the driver is offline")
	eq(w.lfg.listings[T.ANITA], nil, "the listing is gone")
	T.clean(w)
end)

test("gf b1.6: the game refuses RemoveListing: the driver still goes offline, no Lua error, the reminder shows", function()
	local w, d = world(true)
	local WD = words(d)
	d:lfgPost("Wuber summons to Ashenvale", 1001, "Ashenvale")
	w:advance(3)
	w.lfg.removeError = true
	d:clickOn(pill(d))
	w:advance(3)
	eq(isOpen(d), false, "the driver is offline")
	ok(w.lfg.listings[T.ANITA], "the listing is still there")
	ok(sees(d, WD.stillListed), "the reminder shows: " .. texts(d))
	T.clean(w)
end)

test("gf b1.7: offline without a click (a timer's SetOnline): the listing stays and the reminder shows with Remove", function()
	local w, d = world(true)
	local WD = words(d)
	d:lfgPost("Wuber summons to Ashenvale", 1001, "Ashenvale")
	w:advance(3)
	d.W.Driver.SetOnline(false)
	w:advance(3)
	eq(isOpen(d), false, "offline")
	ok(w.lfg.listings[T.ANITA], "the listing is NOT removed by SetOnline")
	eq(calls(w, "RemoveListing"), 0, "RemoveListing was not called")
	ok(sees(d, WD.stillListed), "the reminder shows: " .. texts(d))
	ok(sees(d, WD.removeButton), "with the Remove button")
	d:clickText(WD.removeButton)
	w:advance(2)
	eq(w.lfg.listings[T.ANITA], nil, "his click removes it")
	ok(not sees(d, WD.stillListed), "the reminder is gone")
	T.clean(w)
end)

test("gf b1.8: the List me button opens a sheet with the steps and the note for the driver's destination, in a box he can copy", function()
	local w, d = world(true)
	local WD = words(d)
	d.W.Drive.SetDest("Ashenvale")
	w:advance(1.5)
	d:clickText(WD.listButton)
	w:advance(1.5)
	ok(sees(d, WD.steps), "the steps show: " .. texts(d))
	local sh = d.W.Driver.ui.sheets.gflist
	ok(sh and sh.note and sh.note.edit, "the sheet has its own box")
	eq(sh.note.edit:GetText(), string.format(WD.note, "Ashenvale"), "the note names the destination")
	eq(calls(w, "CreateListing"), 0)
	eq(calls(w, "UpdateListing"), 0)
	T.clean(w)
end)

test("gf b1.9: the mini console's toggle takes the driver offline and removes the listing in the same click", function()
	local w, d = world(true)
	d:lfgPost("Wuber summons to Ashenvale", 1001, "Ashenvale")
	w:advance(3)
	d.W.UI.Toggle(false)
	w:advance(2)
	w:advance(1)
	local mini = d.env.WuberDriveMini
	ok(mini and mini:IsShown(), "the mini console shows while the big button floats")
	d:clickOn(mini.close)
	w:advance(2)
	eq(isOpen(d), false, "offline")
	eq(w.lfg.listings[T.ANITA], nil, "the listing is gone")
	T.clean(w)
end)
