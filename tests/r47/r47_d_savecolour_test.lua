local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

test("r47 d: AUD-152  the Note sheet's Save button keeps red 'Remove note?' text colour after the ask times out", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	local dan = { name = "Dan Rider", key = "dan rider", state = "lead", source = "whisper", at = 0, price = 5000, paid = 0 }
	DR.Sorted = function() return { dan } end
	DR.customers = { [dan.key] = dan }
	DR.IsOpen = function() return true end
	W.UI.WindowWide(false)
	T.openDrive(a)
	if W.UI.ShowDrive then W.UI.ShowDrive("console") end
	w:advance(2)
	W.Driver.RefreshNow()
	w:advance(1)
	DR.SetNote("Dan Rider", "Tips well")
	local D = W.Driver
	D.ShowSheet("note", dan)
	w:advance(1)
	local sh = D.ui.sheets.note
	local r0, g0, b0 = sh.save.label:GetTextColor()
	sh.field:SetText("")
	a:click(sh.save)
	w:advance(0.3)
	eq(sh.save.label:GetText(), "Remove note?", "control: the button asks")
	local r1, g1, b1 = sh.save.label:GetTextColor()
	ok(not (r1 == r0 and g1 == g0 and b1 == b0), "control: while asking the label is red, not the normal colour")
	w:advance(6)
	eq(sh.save.label:GetText(), "Save", "control: back to Save after the ask times out")
	local r2, g2, b2 = sh.save.label:GetTextColor()
	ok(r2 == r0 and g2 == g0 and b2 == b0, string.format(
		"the Save button reads 'Save' again but its text is still the red ask colour (%.2f,%.2f,%.2f) instead of the normal (%.2f,%.2f,%.2f)",
		r2, g2, b2, r0, g0, b0))
	T.clean(w)
end)
