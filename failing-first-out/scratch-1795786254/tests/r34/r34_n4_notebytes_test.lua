local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- Round 34 n4 (HUNT-67): the game's SetMaxBytes very probably counts an end byte, so both note boxes ask for
-- NOTE_MAX + 1; whatever the game lets through, a box never SHOWS more than Save keeps (W.Clean cuts at NOTE_MAX),
-- so a 199-letter note ending in an accented letter cannot lose that letter on Save.
local DAN = "Dan Rider"
local ACC = "\195\169" -- e acute: two bytes

local function console(wide)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	local c = { name = DAN, key = DAN:lower(), state = "lead", source = "whisper", at = 0, price = 5000, paid = 0 }
	DR.Sorted = function() return { c } end
	DR.customers = { [c.key] = c }
	DR.IsOpen = function() return true end
	if wide then
		a.wide = true
		W.db.coach = true
		W.UI.WindowWide(true)
	else
		W.UI.WindowWide(false)
	end
	T.openDrive(a)
	return w, a, W, DR, c
end

-- the one visible Save button
local function saveBtn(a)
	for _, f in ipairs(a.frames) do
		if f.label and H.visible(f) and f.label.GetText and f.label:GetText() == "Save" then return f end
	end
end

-- the right pane's note box: the visible edit box that is not the search box
local function paneBox(a, D)
	local box
	for _, f in ipairs(a.frames) do
		local st = H.state[f]
		if st and st.otype == "EditBox" and H.visible(f) and f ~= D.ui.subs.customers.search.edit then box = f end
	end
	return box
end

local function endsOnLetter(s)
	local b = s:byte(#s)
	return b == nil or b < 128 or b >= 192 -- not the first half of a two-byte letter, and not cut mid-letter
end

-- one case: type text into box with keys; return what the box shows
local function typed(a, box, text)
	a:type(box, text, false)
	return box:GetText()
end

local function checks(a, W, DR, box, label, saveOf)
	local max = DR.BOOK.NOTE_MAX
	eq(max, 200, "control: the book keeps 200 bytes")
	eq(H.state[box].maxBytes, max + 1, label .. ": asks the game for NOTE_MAX + 1 bytes (it counts an end byte)")
	local note = string.rep("a", 199) .. ACC
	eq(#note, 201, "control: 201 bytes")
	local shown = typed(a, box, note)
	ok(#shown <= max, label .. ": shows at most NOTE_MAX bytes: " .. #shown)
	ok(endsOnLetter(shown) and shown:sub(-1) == "a", label .. ": ends on a whole letter, no stray half")
	local before = shown
	a:click(saveOf())
	eq(DR.BookEntry(DAN).note, before, label .. ": Save keeps exactly what the box showed")
	-- exactly 200 bytes (199 letters and a one-byte one, or 100 two-byte letters): left alone
	local ok200 = string.rep("b", 200)
	eq(typed(a, box, ok200), ok200, label .. ": a 200-byte text is left alone")
	local two = string.rep(ACC, 100)
	eq(typed(a, box, two), two, label .. ": 100 two-byte letters (200 bytes) are left alone")
	local over = string.rep(ACC, 101)
	eq(typed(a, box, over), two, label .. ": 101 two-byte letters are cut to 100, whole")
end

test("r34 n4: the Note sheet's box asks NOTE_MAX + 1 bytes and never shows more than Save keeps", function()
	local w, a, W, DR = console(false)
	local D = W.Driver
	D.ShowSheet("note", { name = DAN, key = DAN:lower(), state = "lead", source = "whisper", at = 0, price = 5000, paid = 0 })
	w:advance(1)
	local sh = D.ui.sheets.note
	ok(sh and sh.frame.open, "the Note sheet is open")
	checks(a, W, DR, sh.field.edit, "sheet", function() return sh.save end)
	T.clean(w)
end)

test("r34 n4: the Customers pane's box asks NOTE_MAX + 1 bytes and never shows more than Save keeps", function()
	local w, a, W, DR = console(true)
	local D = W.Driver
	DR.Log().rides[1] = table.concat({ a.env.time() - 600, 5000, DAN, "Orgrimmar", "t", 5000 }, ",")
	D.ShowScreen("customers")
	w:advance(2)
	local box = paneBox(a, D)
	ok(box, "the right pane's note box")
	checks(a, W, DR, box, "pane", function() return saveBtn(a) end)
	T.clean(w)
end)
