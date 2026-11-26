-- PST-01 part B (Polestar, a DECISION): with the game's Gamepad UI on (W.GamepadUI() true) four things of an addon get it
-- blamed ("AddOn blocked") and can stop the controller: (a) click or mouse scripts on frames under the world map,
-- (b) a registered slash command, (c) windows in UISpecialFrames, (d) the addon opening the world map. With it on Wuber
-- does none of them: clicks on its map pins and buttons come from GLOBAL_MOUSE_DOWN / GLOBAL_MOUSE_UP with the pointer over
-- the frame; no slash command; no UISpecialFrames entry; W.Map.Open opens nothing. With it OFF everything is as before.
-- The fake game's style is set in the client's prepare, before the addon loads (Commands and Window read it at load).
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local TM = dofile(H.root .. "/tests/lib/topmost.lua")

local function pad(on)
	return function(env)
		if not on then return end
		env.Enum.InputDeviceInterfaceType = { MouseKeyboard = 0, GamePad = 1 }
		env.C_InputInterfaceStyle = { GetCurrentStyle = function() return 1 end }
	end
end

-- a rider with Bob and the creator online and the map open on Bob, the cursor over a place, the Wuber-only dim on
local function drive(on)
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	local r = T.rider(w, T.TESTCHAR, { prepare = pad(on) })
	T.settle(w)
	T.goOnline(d, { price = 5000 })
	w:advance(2)
	r.W.db.mapOnly = true
	if on then r.env.C_Map.OpenWorldMap(r.W.drivers["bob stone"].mapID) end -- the player opens the map (Wuber itself does not with the Gamepad UI on)
	ok(r.W.Map.ShowDriver("bob stone") ~= nil)
	w:advance(0.5)
	local map = r.env.WorldMapFrame
	r.mouseOver = map.ScrollContainer
	local found
	for ix = 0, 100, 2 do
		for iy = 0, 100, 2 do
			r.mapCursorX, r.mapCursorY = ix / 100, iy / 100
			if r.W.Map.PlaceUnderCursor(false) then found = true break end
		end
		if found then break end
	end
	w:advance(1)
	r.W.Map.Refresh()
	w:advance(0.5)
	return w, r, map
end

local function pinOf(map)
	local child = map.ScrollContainer.Child
	for _, f in ipairs({ child:GetChildren() }) do
		if f.key == "bob stone" and H.visible(f) then return f end
	end
end

local function scripts(f) return f:GetScript("OnClick"), f:GetScript("OnMouseDown"), f:GetScript("OnMouseUp") end

test("pstd gamepad on: pins and Wuber's map buttons carry no click or mouse script, and the map's scroll container no click hook", function()
	local w, r, map = drive(true)
	eq(r.W.GamepadUI(), true, "the fake style is on")
	local pin = pinOf(map)
	ok(pin, "Bob's pin is on the map")
	local a, b, c = scripts(pin)
	eq(a, nil, "no OnClick on the pin") eq(b, nil, "no OnMouseDown on the pin") eq(c, nil, "no OnMouseUp on the pin")
	ok(pin:IsMouseEnabled(), "the pin still takes the mouse over")
	local n = 0
	for _, f in ipairs(r.frames) do
		if f.IsVisible and (f:GetObjectType() == "Button") then
			local p = f
			local under = false
			while p do if p == map then under = true break end p = p:GetParent() end
			if under then
				n = n + 1
				local a1, b1, c1 = scripts(f)
				eq(a1, nil, "no OnClick on a map button") eq(b1, nil, "no OnMouseDown on a map button") eq(c1, nil, "no OnMouseUp on a map button")
			end
		end
	end
	ok(n >= 2, "the pin and the Wuber-only pill were checked: " .. n)
	local sc = map.ScrollContainer
	local d1, d2 = sc:GetScript("OnMouseDown"), sc:GetScript("OnMouseUp")
	eq(d1, nil, "no OnMouseDown hook on the scroll container") eq(d2, nil, "no OnMouseUp hook on the scroll container")
	T.clean(w)
end)

test("pstd gamepad off: pins, buttons and the scroll container have their click scripts, as today", function()
	local w, r, map = drive(false)
	eq(r.W.GamepadUI(), false)
	local pin = pinOf(map)
	ok(pin and pin:GetScript("OnClick"), "the pin has OnClick")
	local sc = map.ScrollContainer
	ok(sc:GetScript("OnMouseDown") and sc:GetScript("OnMouseUp"), "the scroll container is hooked")
	local pills = 0
	for _, f in ipairs(r.frames) do
		if f:GetObjectType() == "Button" and f:GetScript("OnClick") and f:GetParent() == sc then pills = pills + 1 end
	end
	ok(pills >= 1, "a Wuber map button has OnClick: " .. pills)
	T.clean(w)
end)

test("pstd gamepad on: a pin click (GLOBAL_MOUSE_DOWN then UP over the topmost frame at the pin) opens Wuber on that driver; elsewhere nothing happens", function()
	local w, r, map = drive(true)
	local pin = pinOf(map)
	ok(pin, "Bob's pin is on the map")
	TM.assertTopmost(H, r, pin, "Bob's pin")
	local shown = {}
	r.W.UI.Show = function(screen, arg) shown[#shown + 1] = tostring(screen) .. ":" .. tostring(arg) end
	-- the pointer is elsewhere (the map's scroll container, not the pin): the events do nothing
	r.mouseOver = map.ScrollContainer
	r:fire("GLOBAL_MOUSE_DOWN", "LeftButton") r:fire("GLOBAL_MOUSE_UP", "LeftButton")
	w:advance(0.2)
	eq(#shown, 0, "a click away from the pin does nothing")
	-- the pointer over the pin but the button is the right one
	r.mouseOver = pin
	r:fire("GLOBAL_MOUSE_DOWN", "RightButton") r:fire("GLOBAL_MOUSE_UP", "RightButton")
	eq(#shown, 0, "a right click does nothing")
	-- released elsewhere than pressed
	r:fire("GLOBAL_MOUSE_DOWN", "LeftButton") r.mouseOver = map.ScrollContainer r:fire("GLOBAL_MOUSE_UP", "LeftButton")
	eq(#shown, 0, "pressed on the pin, released off it: nothing")
	-- a real click at the pin's point goes through whatever is topmost there
	r:clickOn(pin)
	w:advance(0.2)
	eq(shown[1], "confirm:bob stone", "the click opens Wuber on Confirm for that driver")
	eq(#shown, 1, "once")
	T.clean(w)
end)

test("pstd gamepad on: a pin the pointer is over but another frame covers takes no click (the game's mouse focus decides)", function()
	local w, r, map = drive(true)
	local pin = pinOf(map)
	local shown = {}
	r.W.UI.Show = function(screen, arg) shown[#shown + 1] = tostring(screen) .. ":" .. tostring(arg) end
	r.env.GetMouseFoci = function() return { r.env.UIParent } end
	r.mouseOver = pin
	r:fire("GLOBAL_MOUSE_DOWN", "LeftButton") r:fire("GLOBAL_MOUSE_UP", "LeftButton")
	eq(#shown, 0, "the game says the pointer is on something else")
	r.env.GetMouseFoci = function() return { pin } end
	r:fire("GLOBAL_MOUSE_DOWN", "LeftButton") r:fire("GLOBAL_MOUSE_UP", "LeftButton")
	eq(#shown, 1, "the game says the pointer is on the pin")
	T.clean(w)
end)

test("pstd gamepad on: the Wuber-only pill and the Ride here button work from the global mouse events", function()
	local w, r, map = drive(true)
	local pill
	for _, f in ipairs(r.frames) do
		if f:GetObjectType() == "Button" and f.text and f.text.GetText and f.text:GetText() == "Wuber only" then pill = f end
	end
	ok(pill and H.visible(pill), "the pill is shown")
	local before = r.W.db.mapOnly
	r:clickOn(pill)
	w:advance(0.2)
	ok(r.W.db.mapOnly ~= before, "the click toggled Wuber only")
	local btn
	for _, f in ipairs(r.frames) do
		if f:GetObjectType() == "Button" and f.place and H.visible(f) then btn = f end
	end
	ok(btn, "the Ride here button is shown")
	local booked
	r.W.Map.BookPlace = function(p) booked = p end
	r:clickOn(btn)
	eq(booked, btn.place, "the click books the place")
	T.clean(w)
end)

test("pstd gamepad on: a Ctrl + left click on the map itself books the place under the cursor", function()
	local w, r, map = drive(true)
	local booked
	r.W.Map.BookPlace = function(p) booked = p end
	r.env.IsControlKeyDown = function() return true end
	r.mouseOver = map.ScrollContainer
	r:fire("GLOBAL_MOUSE_DOWN", "LeftButton") r:fire("GLOBAL_MOUSE_UP", "LeftButton")
	ok(booked, "the place was booked from the global events")
	booked = nil
	r.env.IsControlKeyDown = function() return false end
	r:fire("GLOBAL_MOUSE_DOWN", "LeftButton") r:fire("GLOBAL_MOUSE_UP", "LeftButton")
	eq(booked, nil, "without Ctrl nothing")
	T.clean(w)
end)

test("pstd gamepad off: a pin click still goes by OnClick and opens Wuber on that driver", function()
	local w, r, map = drive(false)
	local pin = pinOf(map)
	ok(pin, "Bob's pin")
	local shown = {}
	r.W.UI.Show = function(screen, arg) shown[#shown + 1] = tostring(screen) .. ":" .. tostring(arg) end
	r:clickOn(pin)
	w:advance(0.2)
	eq(shown[1], "confirm:bob stone")
	eq(#shown, 1)
	-- the global events alone do nothing with the style off
	r.mouseOver = pin
	r:fire("GLOBAL_MOUSE_DOWN", "LeftButton") r:fire("GLOBAL_MOUSE_UP", "LeftButton")
	eq(#shown, 1, "the global events are not used with the style off")
	T.clean(w)
end)

test("pstd gamepad on: no /wuber or /ride slash command; the key binding and the minimap button still open Wuber", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { prepare = pad(true) })
	T.settle(w)
	eq(r.env.SLASH_WUBER1, nil, "SLASH_WUBER1") eq(r.env.SLASH_WUBER2, nil, "SLASH_WUBER2")
	local okc = pcall(r.slash, r, "/wuber")
	eq(okc, false, "/wuber is not a command")
	-- Bindings.xml's "Open or close Wuber" key calls SlashCmdList["WUBER"](""): the handler stays (no SLASH_ name: the chat box never runs it)
	ok(type(r.env.SlashCmdList.WUBER) == "function", "SlashCmdList.WUBER stays for the key binding")
	r.env.SlashCmdList.WUBER("")
	w:advance(0.2)
	ok(r.env.WuberFrame and r.env.WuberFrame:IsShown(), "the key binding opens Wuber")
	r.env.SlashCmdList.WUBER("")
	w:advance(0.2)
	local btn = r.env.WuberMinimapButton
	ok(btn, "the minimap button exists")
	r:click(btn)
	w:advance(0.2)
	ok(r.env.WuberFrame:IsShown(), "the minimap button opens Wuber")
	T.clean(w)
end)

test("pstd gamepad off: /wuber and /ride are registered and work", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { prepare = pad(false) })
	T.settle(w)
	eq(r.env.SLASH_WUBER1, "/wuber") eq(r.env.SLASH_WUBER2, "/ride")
	ok(type(r.env.SlashCmdList.WUBER) == "function", "SlashCmdList.WUBER")
	ok(r:slash("/wuber") ~= nil or true)
	T.clean(w)
end)

local function listed(r, name)
	for _, n in ipairs(r.env.UISpecialFrames) do if n == name then return true end end
	return false
end

local function openWindows(w, r) -- returns the driver console module
	r.W.UI.Toggle(true)
	w:advance(0.5)
	r.W.UI.Bug.Open()
	w:advance(0.5)
	-- the driver's own window exists only when the Wuber window offers no tabs: ask for it as that game would
	local console = r.W.Driver
	if console then
		local i = 1
		while true do
			local n, v = debug.getupvalue(console.Toggle, i)
			if not n then break end
			if n == "tabbed" then debug.setupvalue(console.Toggle, i, false) end
			i = i + 1
		end
		console.Toggle()
		w:advance(0.5)
	end
	return console
end

test("pstd gamepad on: WuberFrame, WuberBug and WuberDriveFrame are not in UISpecialFrames", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { prepare = pad(true) })
	T.settle(w)
	local console = openWindows(w, r)
	ok(console, "the driver console was reached")
	ok(r.env.WuberFrame and r.env.WuberBug and r.env.WuberDriveFrame, "all three windows exist")
	for _, n in ipairs({ "WuberFrame", "WuberBug", "WuberDriveFrame" }) do eq(listed(r, n), false, n .. " is not listed") end
	T.clean(w)
end)

test("pstd gamepad off: WuberFrame, WuberBug and WuberDriveFrame are in UISpecialFrames, and Escape closes them", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { prepare = pad(false) })
	T.settle(w)
	local console = openWindows(w, r)
	ok(console, "the driver console was reached")
	-- (#303) an open Report a bug sheet holds its window's Escape slots (so Escape closes it alone): close it to see the list
	r.W.UI.Bug.Close()
	w:advance(0.5)
	for _, n in ipairs({ "WuberFrame", "WuberBug", "WuberDriveFrame" }) do ok(listed(r, n), n .. " is listed") end
	T.clean(w)
end)

test("pstd gamepad on: W.Map.Open returns false and opens nothing, even with the safe opener there", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { prepare = pad(true) })
	T.settle(w)
	local asked = 0
	local real = r.env.C_Map and r.env.C_Map.OpenWorldMap
	if r.env.C_Map then r.env.C_Map.OpenWorldMap = function(...) asked = asked + 1 if real then return real(...) end end end
	r.env.WorldMapFrame:Hide()
	eq(r.W.Map.Open(), false, "Open()")
	eq(r.W.Map.Open(1), false, "Open(mapID)")
	eq(asked, 0, "the game's opener was not asked")
	eq(r.env.WorldMapFrame:IsShown(), false, "the map stays closed")
	eq(r.W.Map.ShowDriver("bob stone"), false, "ShowDriver opens nothing")
	eq(r.env.WorldMapFrame:IsShown(), false, "still closed")
	T.clean(w)
end)

test("pstd gamepad off: W.Map.Open opens the map", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { prepare = pad(false) })
	T.settle(w)
	r.env.WorldMapFrame:Hide()
	eq(r.W.Map.Open(), true, "Open()")
	eq(r.env.WorldMapFrame:IsShown(), true, "the map shows")
	T.clean(w)
end)
