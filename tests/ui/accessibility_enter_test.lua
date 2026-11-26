-- Accessibility (job 2767): Enter confirms in the one-line boxes that have a confirm button next to them.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("ui.accessibility: Enter in the block-reason box blocks, like the Block button", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	if W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	local D = W.Driver
	local got
	local real = D.RowAction
	D.RowAction = function(c, what, why) got = { c = c, what = what, why = why } return true end
	local c = { name = "Dan Moss", key = "dan moss", state = "waiting" }
	ok(D.ShowSheet("menu", c), "the rider menu opens")
	w:advance(1)
	local dv = W.UI.drive
	local s = dv.menu or (dv.screens and dv.screens.menu) or (dv.sheets and dv.sheets.menu)
	s.pick("block")
	w:advance(1)
	ok(s.reason:IsShown(), "control: the reason box is up")
	a:type(s.reason.edit, "rude", true)
	w:advance(1)
	D.RowAction = real
	ok(got and got.what == "block", "Enter blocked the rider")
	eq(got and got.why, "rude", "with the typed reason")
	ok(not D.SheetOpen(), "and the sheet closed")
	T.clean(w)
end)
