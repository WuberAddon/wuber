-- The big Drive button (docked on the Drive tab's slot, also when paused) stays in front of the open world map.
-- The fake game's map has a real strata, level and takes the mouse; Client:clickOn goes to whatever is drawn on top.
-- The window rides over the map at FULLSCREEN_DIALOG (UI.Raise); the lifted secure button must beat both, whether the
-- map was open before the Drive tab came up or opens or shuts while it is up.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function setup()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	W.db.coach = true
	W.Char().wizard = true
	W.Driver.SetOnline(true)
	w:advance(2)
	return w, d, W, d.env.WuberDriveButton
end

local function openMap(d, strata, level)
	local map = d.env.WorldMapFrame
	map:SetFrameStrata(strata)
	map:SetFrameLevel(level)
	map:EnableMouse(true)
	map:Show()
	return map
end

local function name(f) return f and (f:GetName() or f:GetObjectType()) or "nothing" end

local function check(label, d, b)
	ok(b:IsShown() and b:GetAlpha() > 0, label .. ": the big button shows")
	local hit = d:topAt(b)
	eq(hit, b, label .. ": the frame on top at the big button is the button (not " .. name(hit) .. ")")
end

local function run(strata, level, tag)
	test("front: the big button on the Drive tab is in front of a map already open (" .. tag .. ")", function()
		local w, d, W, b = setup()
		openMap(d, strata, level)
		w:advance(2)
		W.UI.Toggle(true) w:advance(1)
		W.UI.SelectTab("Drive") w:advance(1.5)
		ok(W.Drive.Button.Docked(), "docked on the Drive slot")
		check("map first", d, b)
		T.clean(w)
	end)
	test("front: the big button on the Drive tab follows the map opening and shutting (" .. tag .. ")", function()
		local w, d, W, b = setup()
		W.UI.Toggle(true) w:advance(1)
		W.UI.SelectTab("Drive") w:advance(1.5)
		ok(W.Drive.Button.Docked(), "docked on the Drive slot")
		check("no map", d, b)
		local map = openMap(d, strata, level)
		w:advance(2)
		check("map opened over the Drive tab", d, b)
		-- a click on the window raises it (toplevel); the button must still be on top
		W.UI.SelectTab("Ride") w:advance(1)
		W.UI.SelectTab("Drive") w:advance(1.5)
		check("after a tab change with the map open", d, b)
		map:Hide() w:advance(2)
		check("map shut", d, b)
		map:Show() w:advance(2)
		check("map open again", d, b)
		T.clean(w)
	end)
	test("front: the paused big button is in front of the map and takes the click (" .. tag .. ")", function()
		local w, d, W, b = setup()
		W.UI.Toggle(true) w:advance(1)
		W.UI.SelectTab("Drive") w:advance(1.5)
		openMap(d, strata, level)
		w:advance(2)
		W.Driver.SetOnline(false) w:advance(1.5)
		check("paused (offline) with the map open", d, b)
		local got = d:clickOn(b)
		eq(got, b, "the click reaches the big button, it went to " .. name(got))
		T.clean(w)
	end)
end

run("DIALOG", 900, "DIALOG 900")
run("FULLSCREEN", 100, "FULLSCREEN 100")
run("FULLSCREEN_DIALOG", 500, "FULLSCREEN_DIALOG 500")
run("FULLSCREEN_DIALOG", 9000, "FULLSCREEN_DIALOG 9000")

-- the rider's Request overlay (UI.Secure) lies over its pill; the map opening after it was placed must not cover it
local function runRequest(strata, level, tag)
	test("front: the Request overlay is in front of a map that opens while the card is up (" .. tag .. ")", function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
		local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
		T.settle(w)
		T.goOnline(d)
		w:advance(5)
		T.openConfirm(r, d.W.myKey)
		w:advance(1)
		local over = r.env.WuberRequestButton
		ok(over and over:IsShown(), "the Request overlay is up")
		eq(r:topAt(over), over, "no map: the overlay is on top")
		local map = openMap(r, strata, level)
		w:advance(2)
		ok(over:IsShown(), "still up")
		eq(r:topAt(over), over, "map open: the overlay is on top (not " .. name(r:topAt(over)) .. ")")
		map:Hide() w:advance(2)
		eq(r:topAt(over), over, "map shut: the overlay is on top")
		T.clean(w)
	end)
end
runRequest("FULLSCREEN_DIALOG", 500, "FULLSCREEN_DIALOG 500")
runRequest("FULLSCREEN_DIALOG", 9000, "FULLSCREEN_DIALOG 9000")
runRequest("DIALOG", 900, "DIALOG 900")
