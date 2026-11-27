-- The "List me in the Group Finder" sheet explains itself when the mouse rests on the big note: the card has the
-- button's name as its title and the steps as its line (2.4.3 had it on the copy box; the note is a label now).
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

test("gf note tip 1: hovering the big note shows the steps under the button's name", function()
	local w, d, sh = sheet("Orgrimmar")
	local WD = d.W.GroupFinder.DRAFT_WORDS
	d:hoverOn(sh.note)
	w:advance(0.5)
	local card = d.env.WuberTip
	ok(card and card:IsShown(), "a tip card is up over the note")
	if card then
		eq(card.title:GetText(), WD.listButton, "its title")
		eq(card.lines[1] and card.lines[1]:GetText(), WD.steps, "its line is the steps")
	end
	T.clean(w)
end)

-- guard: the note stays a label with its words and the sheet still sizes itself around it
test("gf note tip 2: the note keeps its words and the tip frame does not change them", function()
	local w, d, sh = sheet("Orgrimmar")
	eq(sh.note:GetText(), "Wuber summons to Orgrimmar", "the note")
	ok(not sh.note.edit, "still no edit box")
	T.clean(w)
end)
