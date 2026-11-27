local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function sheet(dest)
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	W.Char().dest = dest
	T.openDrive(a)
	W.Driver.ShowSheet("sheet")
	w:advance(2)
	local s = W.UI.drive.screens.sheet
	return w, a, W, s
end

test("r47 j2: control: a driver with no saved place who types one in Price and place saves what was typed", function()
	local w, a, W, s = sheet("")
	a:click(s.where.buttons and s.where.buttons[2] or s.where)
	s.mode = "choose" s.layout()
	a:type(s.search.edit, "Orgrimmar", false)
	a:click(s.save)
	w:advance(1)
	eq(W.Char().dest, "Orgrimmar", "control: typed place is saved")
	T.clean(w)
end)

test("r47 j2: a driver with a saved place types another one and presses Save: the new place is saved", function()
	local w, a, W, s = sheet("Undercity")
	eq(s.mode, "choose", "control: the sheet opens on Choose with the saved place")
	eq(s.search:Text(), "Undercity", "control: the box shows the saved place")
	a:type(s.search.edit, "Orgrimmar", false)
	eq(s.search:Text(), "Orgrimmar", "control: the box now reads what the driver typed")
	a:click(s.save)
	w:advance(1)
	eq(W.Char().dest, "Orgrimmar", "riders were summoned to the old place '" .. tostring(W.Char().dest) .. "'")
	T.clean(w)
end)

test("r47 j2: a driver with a saved place clears the box and presses Save: no place is saved", function()
	local w, a, W, s = sheet("Undercity")
	a:type(s.search.edit, "", false)
	a:click(s.save)
	w:advance(1)
	eq(W.Char().dest or "", "", "cleared box saves no place")
	T.clean(w)
end)
