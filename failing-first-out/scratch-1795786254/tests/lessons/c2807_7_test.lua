-- c2807 #7: the empty Ride screen shows the quiet "Get OpenMap to see drivers on your world map" line under "Why can't I see
-- anyone?" (Simple and Advanced, no x), only for players without OpenMap, and only when it fits: the round icon gives way first.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local LINE = "Get OpenMap to see drivers on your world map"

local function setup(opts)
	opts = opts or {}
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = opts.sw or 1920, screenH = opts.sh or 1080, simple = opts.simple,
		saved = { Wuber = { coach = true } } })
	w:advance(15)
	local UI = c.W.UI
	if opts.openMap then UI.HasOpenMap = function() return true end end
	UI.Toggle(true)
	w:advance(3)
	c.W.db.fold = { v = 1, pages = {}, narrow = true }
	UI.Fold.Apply()
	w:advance(2)
	UI.Show("home")
	w:advance(2)
	UI.Refresh(true)
	w:advance(1)
	return w, c, UI, UI.state.screens.home.empty
end

local function lineShown(c)
	return #c:findText(LINE, false, true) > 0
end

for _, mode in ipairs({ "Simple", "Advanced" }) do
	test("c2807 #7 empty Ride screen without OpenMap shows the OpenMap line under Why (" .. mode .. ")", function()
		local w, c, UI, e = setup({ simple = (mode == "Simple") })
		c.W.SetAdvanced(mode == "Advanced")
		w:advance(1)
		UI.Refresh(true)
		w:advance(1)
		ok(H.visible(e), "the empty Ride screen shows")
		ok(H.visible(e.why), "Why can't I see anyone? shows")
		ok(lineShown(c), "the OpenMap line shows")
		ok(e.mapHint:IsVisible(), "the quiet line frame is visible")
		ok(e.mapHint:GetTop() < e.why:GetBottom() + 0.5, "it sits under Why")
		eq(e.mapHint.close, nil, "it has no x")
		T.clean(w)
	end)

	test("c2807 #7 empty Ride screen with OpenMap does not show the OpenMap line (" .. mode .. ")", function()
		local w, c, UI, e = setup({ simple = (mode == "Simple"), openMap = true })
		c.W.SetAdvanced(mode == "Advanced")
		w:advance(1)
		UI.Refresh(true)
		w:advance(1)
		ok(H.visible(e), "the empty Ride screen shows")
		ok(not lineShown(c), "no OpenMap line")
		T.clean(w)
	end)
end

test("c2807 #7 on a small window the round icon hides first and the OpenMap line stays", function()
	local seenBoth = false
	for _, sh in ipairs({ 1080, 900, 768, 700, 640, 600, 560, 520, 480 }) do
		local w, c, UI, e = setup({ sw = 1365, sh = sh })
		if lineShown(c) and not e.disc:IsVisible() then seenBoth = true end
		-- the icon never gives way after the line: where the icon shows, the line shows too
		if e.disc:IsVisible() then ok(lineShown(c), "icon shown at height " .. sh .. " so the line shows") end
		T.clean(w)
	end
	ok(seenBoth, "somewhere the icon is hidden while the line stays")
end)
