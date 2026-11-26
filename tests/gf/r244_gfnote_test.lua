-- r244 gfnote: the note box on the "List me in the Group Finder" sheet must be copyable: the whole text is selected when the box
-- is clicked or gets focus, typing cannot change it, and Escape lets go of the keyboard. No words are tested or changed here.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function sheet()
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
	d:clickText(d.W.GroupFinder.DRAFT_WORDS.listButton)
	w:advance(1.5)
	local sh = d.W.Driver.ui.sheets.gflist
	ok(sh and sh.note and sh.note.edit, "the sheet has its note box")
	return w, d, sh, sh.note.edit
end

local function whole(e)
	local h = H.state[e].highlight
	return h ~= nil and h[1] == 0 and (h[2] == -1 or h[2] >= #e:GetText())
end

test("r244 gfnote 1: clicking the note box selects its whole text", function()
	local w, d, sh, e = sheet()
	H.state[e].highlight = nil
	d:clickOn(e)
	w:advance(0.2) -- the client places the cursor on the click; the box selects again a frame later
	ok(whole(e), "the whole note is selected after a click")
	T.clean(w)
end)

-- guard: the focus-gained hook already selects the whole note; this keeps it
test("r244 gfnote 2: the note box getting keyboard focus selects its whole text", function()
	local w, d, sh, e = sheet()
	H.state[e].highlight = nil
	e:ClearFocus()
	e:SetFocus()
	ok(whole(e), "the whole note is selected on focus")
	T.clean(w)
end)

-- guard: the onChange restore already undoes an edit; this keeps it
test("r244 gfnote 3: typing into the note box is undone and the whole text stays selected", function()
	local w, d, sh, e = sheet()
	local note = e:GetText()
	d:type(e, note .. " extra", false)
	eq(e:GetText(), note, "the typed edit is undone")
	ok(whole(e), "the whole note is selected again")
	d:type(e, "", false)
	eq(e:GetText(), note, "clearing it is undone too")
	T.clean(w)
end)

-- guard: Escape already lets go of the keyboard (Field's OnEscapePressed); this keeps it so the player can move again
test("r244 gfnote 4: Escape in the note box lets go of the keyboard", function()
	local w, d, sh, e = sheet()
	e:SetFocus()
	ok(e:HasFocus(), "the box has focus")
	H.state[e].scripts.OnEscapePressed(e)
	ok(not e:HasFocus(), "the box let go of the keyboard")
	T.clean(w)
end)
