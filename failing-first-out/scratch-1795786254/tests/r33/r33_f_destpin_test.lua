local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- HUNT-116: on the booking card the destination pin sits in the part of the strip the sheet leaves
-- visible (the sheet starts 168 down), not under it.
test("r33 f: HUNT-116 - the booking card's destination pin tip stays above the sheet for a low place", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	local UI = W.UI
	UI.Toggle(true)
	w:advance(3)
	UI.Show("confirm", "mia runner")
	w:advance(1.5)
	local s = UI.state.screens.confirm
	local m = s.map
	ok(m and m.destPin, "the strip and its pin are there")
	W.ExactPlace = function() return { name = "Lowtown", mapID = 1, x = 0.5, y = 0.99 } end
	m.routeDest = "Lowtown"
	UI.RouteOnMap(m, 1, 0.5, 0.3, 0, 0, 196, 196)
	ok(H.visible(m.destPin), "the pin shows")
	local _, _, _, _, y = m.destPin:GetPoint()
	-- the tip is at -y below the strip's top; the sheet covers from 168
	ok(-y <= 168, "tip above the sheet: " .. tostring(-y))
	T.clean(w)
end)
