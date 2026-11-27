-- The "List me in the Group Finder" sheet's steps name the buttons the real Group Finder has, and say to type the note by hand (the game's Note box refuses paste).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local WANT = "Open the Group Finder, go to List yourself, pick a Playstyle, click the Note box and type the note below by hand, then List me."

test("playtest Q3: the sheet shows the new Group Finder steps", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	d.W.db.groupFinder = true
	T.goOnline(d)
	d.W.Char().wizard = true
	d.W.UI.Toggle(true)
	w:advance(2.5)
	d:clickText("Drive")
	w:advance(1.5)
	d.W.Drive.SetDest("Ashenvale")
	w:advance(1.5)
	eq(d.W.GroupFinder.DRAFT_WORDS.steps, WANT, "the steps words")
	d:clickText(d.W.GroupFinder.DRAFT_WORDS.listButton)
	w:advance(1.5)
	local sh = d.W.Driver.ui.sheets.gflist
	ok(sh and sh.steps, "the sheet has its steps line")
	eq(sh.steps:GetText(), WANT, "the sheet shows the steps")
	ok(not sh.steps:GetText():find("Create Listing", 1, true) and not sh.steps:GetText():find("press Post", 1, true), "the old buttons are gone")
	T.clean(w)
end)
