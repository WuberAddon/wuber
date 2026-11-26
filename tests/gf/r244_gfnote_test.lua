-- The "List me in the Group Finder" sheet: the game's Note box refuses paste and addon SetText, so the sheet shows a short note in
-- big letters for the driver to TYPE by hand (no copy box, no Ctrl+C step). The note must still match Wuber's own detection.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function sheet(dest)
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
	d.W.Drive.SetDest(dest)
	w:advance(1.5)
	d:clickText(d.W.GroupFinder.DRAFT_WORDS.listButton)
	w:advance(1.5)
	local sh = d.W.Driver.ui.sheets.gflist
	ok(sh and sh.note, "the sheet has its note")
	return w, d, sh
end

test("gf typed note 1: the note is big letters of 'Wuber summons to <destination>', not a box", function()
	local w, d, sh = sheet("Orgrimmar")
	eq(sh.note:GetText(), "Wuber summons to Orgrimmar", "the note names the destination")
	ok(sh.note.GetText and not sh.note.edit, "a label, not an edit box (nothing to select or copy)")
	ok(#d:findText("Wuber summons to Orgrimmar", true, true) > 0, "it is on screen")
	T.clean(w)
end)

test("gf typed note 2: the steps say type, never paste or Ctrl", function()
	local w, d, sh = sheet("Orgrimmar")
	local WD = d.W.GroupFinder.DRAFT_WORDS
	local low = WD.steps:lower()
	ok(low:find("type", 1, true), "the steps say type")
	ok(not low:find("paste", 1, true) and not low:find("ctrl", 1, true) and not low:find("copy", 1, true), "no paste, Ctrl or copy: " .. WD.steps)
	ok(#d:findText(WD.steps, true, true) > 0, "the steps show")
	T.clean(w)
end)

test("gf typed note 3: the note still matches Wuber's own detection (a rider's search marks the driver)", function()
	local w, d, sh = sheet("Ashenvale")
	local WD = d.W.GroupFinder.DRAFT_WORDS
	ok(sh.note:GetText():lower():find("wuber", 1, true), "the note holds Wuber")
	for _, dest in ipairs({ "Orgrimmar", "Booty Bay", WD.here }) do
		ok(string.format(WD.note, dest):lower():find("wuber", 1, true), "Wuber is in the note for " .. dest)
	end
	T.clean(w)
end)

test("gf typed note 4: a longer destination wraps and is shown whole, never shortened", function()
	local dest = "Booty Bay harbour"
	local w, d, sh = sheet(dest)
	ok(sh.note:GetText():find(dest, 1, true), "the whole destination is in the note: " .. sh.note:GetText())
	T.clean(w)
end)
