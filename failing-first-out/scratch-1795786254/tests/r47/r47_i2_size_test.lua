local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

test("r47 i2: Settings home card says the real window size", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = false } } })
	w:advance(2)
	local W = c.W
	local UI = W.UI
	UI.Toggle(true)
	w:advance(3)
	eq(W.db.scale, nil, "control: no saved scale (the default)")
	UI.OpenSettings()
	w:advance(3)
	local real = math.floor(UI.state.win:GetScale() * 100 + 0.5)
	local got = c:findText("Size %d+%%")
	ok(#got > 0, "control: the Size card line shows: " .. T.list(c:visibleTexts()):sub(1, 200))
	local shown = tonumber(got[1]:GetText():match("Size (%d+)%%"))
	ok(real ~= 100, "control: the window is not at 100% (is " .. real .. "%)")
	eq(shown, real, "the Window card says 'Size " .. tostring(shown) .. "%' but the window is really " .. real .. "%")
	T.clean(w)
end)
