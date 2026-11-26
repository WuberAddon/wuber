-- r47 o4: AUD-204 (Esc in an empty Settings search box brings the placeholder back)
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

test("r47 o4: AUD-204 audit C34r-3: click Settings search, press Esc without typing: the placeholder comes back", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = false } } })
	w:advance(2)
	local UI = c.W.UI
	UI.Toggle(true)
	w:advance(3)
	UI.OpenSettings()
	w:advance(3)
	local box = UI.settings.find.box
	ok(H.visible(box.hint), "control: the 'Search settings' placeholder shows at first")
	box.edit:SetFocus()
	w:advance(0.5)
	ok(not box.hint:IsShown(), "control: the placeholder is hidden while the box has focus")
	c.world.hardware = c
	box.edit:GetScript("OnEscapePressed")(box.edit)
	c.world.hardware = nil
	w:advance(0.5)
	ok(H.visible(box.hint), "after Esc the empty search box shows no 'Search settings' hint (empty and blank)")
	T.clean(w)
end)
