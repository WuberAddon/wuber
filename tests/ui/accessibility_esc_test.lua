-- Accessibility (job 2767): Escape closes the top sheet first; a second Escape closes the phone.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("ui.accessibility: another addon shifting the Escape list while a sheet is open: the sheet gives back only its own slot", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	if W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	local D = W.Driver
	ok(D.ShowSheet("sheet"), "the price sheet opens")
	w:advance(1)
	local list = a.env.UISpecialFrames
	local n = #list
	local sheetAt
	for i = 1, n do if tostring(list[i]):find("^WuberSheet%d+$") then sheetAt = i end end
	ok(sheetAt, "control: the sheet's name holds its window's slot")
	local other = "OtherAddonFrame"
	table.insert(list, 1, other) -- another addon puts its frame first: every index moves up one
	for i = 1, #list do T.H.taint.accept(a, list, i) end -- (the test's own planted write is not the addon's)
	a:pressEscape()
	w:advance(1)
	ok(not D.SheetOpen(), "the sheet closed")
	local seen = 0
	for i = 1, #list do
		ok(not tostring(list[i]):find("^WuberSheet%d+$"), "no sheet name left behind at " .. i)
		if list[i] == other then seen = seen + 1 end
	end
	eq(seen, 1, "the other addon's entry is untouched")
	eq(#list, n + 1, "the list length is what it was plus the other addon's entry")
	T.clean(w)
end)

test("ui.accessibility: Escape closes an open sheet and leaves the phone up; the next Escape closes the phone", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	if W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	local D = W.Driver
	ok(D.ShowSheet("sheet"), "the price sheet opens")
	w:advance(1)
	ok(D.SheetOpen(), "control: the sheet is open")
	a:pressEscape()
	w:advance(1)
	ok(not D.SheetOpen(), "Escape closed the sheet")
	ok(W.UI.IsShown(), "the phone is still up after the first Escape")
	a:pressEscape()
	w:advance(1)
	ok(not W.UI.IsShown(), "the second Escape closes the phone")
	T.clean(w)
end)
