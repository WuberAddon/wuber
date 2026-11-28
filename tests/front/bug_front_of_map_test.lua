-- The report window opens in front of the game's world map (Settings > Report a bug with the map open).
-- The fake game's map takes the mouse and has a real strata and level, so a click goes to whatever is drawn on top
-- (Client:clickOn: strata first, then frame level, then creation order). The window rides over the map at
-- FULLSCREEN_DIALOG (UI.Raise); the report sheet used to stay at DIALOG, under the window's own page and under the map.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- is f drawn at or inside frame top (top, or one of its children)?
local function inside(f, top)
	local g = f
	while g do
		if g == top then return true end
		g = g:GetParent()
	end
	return false
end

-- the game's map: DIALOG or higher, level high (a UI panel is raised to the top of its layer when it opens), takes the mouse
local function runWith(strata, level, label)
	test("front: Report a bug opens in front of the open world map (" .. label .. ") and its box and x take the click", function()
		local w = T.newWorld()
		local r = T.rider(w)
		T.settle(w)
		local UI = r.W.UI
		r.W.db.coach = true
		UI.Toggle(true)
		w:advance(3)
		local map = r.env.WorldMapFrame
		map:SetFrameStrata(strata)
		map:SetFrameLevel(level)
		map:EnableMouse(true)
		map:Show()
		w:advance(3)
		ok(map:IsShown(), "the map is open")
		UI.OpenSettings("window")
		w:advance(1)
		UI.settings.view = "home"
		UI.LayoutSettings()
		local card = UI.settings.find and UI.settings.find.bug
		ok(card and H.visible(card), "the Report a bug card shows")
		ok(r:scrollIntoView(card), "the player scrolls to it")
		eq(r:clickOn(card):GetName() ~= "WorldMapFrame", true, "the click on the card reaches Wuber's card, not the map")
		w:advance(1)
		ok(UI.Bug.Shown(), "the report is open")
		local f = UI.Bug.frame
		-- clicking through the topmost frame: the report box and the x are what the click reaches
		local box = f.copy.edit
		ok(r:onScreen(box), "the report box is on screen")
		local hit = r:topAt(box)
		ok(hit and (inside(hit, f.holder) or inside(hit, f)), "the frame on top at the report box belongs to the report, not the map or the page: "
			.. tostring(hit and (hit:GetName() or hit:GetObjectType())))
		local x = f.close
		ok(x and H.visible(x), "the x shows")
		local got = r:clickOn(x)
		ok(not UI.Bug.Shown(), "a click on the x reaches the x and closes the report (the click went to " .. tostring(got and (got:GetName() or got:GetObjectType())) .. ")")
		T.clean(w)
	end)
end

test("front: the map opens while the report is already up: the report moves in front of it, and goes back when the map shuts", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	local UI = r.W.UI
	UI.Toggle(true)
	w:advance(3)
	ok(UI.Bug.Open(), "the report opens")
	w:advance(2)
	local f = UI.Bug.frame
	eq(f.holder:GetFrameStrata(), "DIALOG", "no map: the usual layer")
	local map = r.env.WorldMapFrame
	map:SetFrameStrata("DIALOG")
	map:SetFrameLevel(900)
	map:EnableMouse(true)
	map:Show()
	w:advance(3)
	local box = f.copy.edit
	local hit = r:topAt(box)
	ok(hit and (inside(hit, f.holder) or inside(hit, f)), "with the map open the report box is on top: " .. tostring(hit and (hit:GetName() or hit:GetObjectType())))
	map:Hide()
	w:advance(3)
	eq(f.holder:GetFrameStrata(), "DIALOG", "the map shut: back to the usual layer")
	T.clean(w)
end)

runWith("DIALOG", 900, "DIALOG, level 900")
runWith("FULLSCREEN", 100, "FULLSCREEN, level 100")
