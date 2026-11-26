-- Adopted from the fable-2411 draft in r52 (job 2706).
-- Final home: tests/ui/map/map_test.lua; add it to the per-module list in tests/run.lua.
-- Pins: the contract (registered, deps = header Uses, public names); the "Ride here" tag text (no drivers / one driver and its cheapest fare).
-- Pins: BookPlace refuses bad input and combat, opens Wuber otherwise; PlaceUnderCursor is nil with the map shut, off the map or past its edge.
-- Pins: Ctrl + left click books the place under the cursor; a plain click, a right click, a drag and a click in combat do not.
-- Pins: the corner "Ride here" button follows the cursor, stays 2 s (GRACE), then goes; SetShown(false) clears pins and the button; hidden drivers are not drawn.
-- Pins: RedrawSoon throttles a burst of DRIVERS events; Open ignores a bad mapID; ShowDriver refuses an unknown driver; PinLevel arithmetic.
-- Why it matters to a player: the world map is where riders find drivers. If this broke they would see no driver pins, a stuck or wrong "Ride here" button,
-- a Ctrl-click that books the wrong place (or fires while dragging the map or in a fight), or a map that stutters while many beacons arrive.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local DOT = "  \194\183  " -- the " · " of the tag text (UTF-8 middle dot), Map.lua TagText

-- Bob drives (online, 50s), Wuber rides: the map's pins are Bob's (the setup of tests/dec/dec_j_maptaint_test.lua)
local function mapWorld()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d, { price = 5000 })
	w:advance(2)
	return w, r, d
end

-- a lone rider with the map open on Orgrimmar's own map (1454: a city's map is the city), the cursor over the map
local function cityMap()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local wm = r.env.WorldMapFrame
	wm:SetMapID(1454) wm:Show() w:advance(1)
	r.mouseOver = wm.ScrollContainer
	r.mapCursorX, r.mapCursorY = 0.5, 0.5
	return w, r, wm
end

local function near(a, b, what)
	ok(type(a) == "number" and math.abs(a - b) < 1e-6, (what or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end

local function windowShown(r)
	local f = r.env.WuberFrame
	return f ~= nil and f:IsShown() == true
end

local function shownPins(r)
	local n = 0
	for _, p in ipairs(r.W.Mod("UI.Map.Base").pins) do
		if p:IsShown() then n = n + 1 end
	end
	return n
end

local function ctrlClick(r, button, between)
	local sc = r.env.WorldMapFrame.ScrollContainer
	r.mods.ctrl = true
	sc:GetScript("OnMouseDown")(sc, button or "LeftButton")
	if between then between() end
	sc:GetScript("OnMouseUp")(sc, button or "LeftButton")
	r.mods.ctrl = false
	r.world:advance(1)
end

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.map: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("UI.Map.Map", "tests/ui/map/map_test.lua", {
		["W.Map.PlaceUnderCursor"] = "function",
		["W.Map.DriversTo"] = "function",
		["W.Map.TagText"] = "function",
		["W.Map.BookPlace"] = "function",
		["W.Map.UpdateHover"] = "function",
		["W.Map.Refresh"] = "function",
		["W.Map.SetShown"] = "function",
		["W.Map.ShowDriver"] = "function",
		["W.Map.Open"] = "function",
		["W.Map.Veil"] = "function",
		["W.Map.OnlyPill"] = "function",
		["W.Map.RedrawSoon"] = "function",
		["W.Map.redraws"] = "number",
		["Mod.PinLevel"] = "function",
	})
	ok(Mod, "W.Mod(\"UI.Map.Map\")")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.map: the Ride here tag says 'no drivers yet' for a place nobody drives to", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local M = r.W.Map
	local n, price = M.DriversTo({ name = "Everlook" })
	eq(n, 0, "no drivers")
	eq(price, nil, "no fare")
	eq(M.TagText({ name = "Everlook" }), "|cffcd7df5Ride here|r" .. DOT .. "Everlook" .. DOT .. "no drivers yet") -- Map.lua TagText
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.map: the tag counts one driver to the place and shows the cheapest fare; another place stays empty", function()
	local w, r = mapWorld()
	local M = r.W.Map
	local bob = r.W.drivers["bob stone"]
	ok(bob and bob.dest, "Bob's beacon reached the rider with a destination")
	local place = { name = bob.dest }
	local n, price = M.DriversTo(place)
	eq(n, 1, "one driver to Bob's destination")
	eq(price, r.W.Num(bob.price), "his fare (Bob is open, so it is the cheapest open fare)")
	local text = M.TagText(place)
	ok(text:find(DOT .. "1 driver" .. DOT .. "from |cfff9c53e" .. r.W.Money(price) .. "|r", 1, true), text) -- singular "driver", gold fare
	ok(not text:find("1 drivers", 1, true), "never '1 drivers'")
	local n2 = M.DriversTo({ name = "Everlook" })
	eq(n2, 0, "nobody drives to Everlook")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.map: BookPlace refuses anything that is not a place; a plain name still opens Wuber", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local M = r.W.Map
	eq(M.BookPlace(nil), false, "nil") -- Map.lua BookPlace: type(place) ~= "table"
	eq(M.BookPlace(42), false, "a number")
	eq(M.BookPlace({}), false, "a table with no name")
	ok(not windowShown(r), "nothing opened")
	eq(M.BookPlace("Orgrimmar"), true, "a place typed as a name")
	w:advance(2)
	ok(windowShown(r), "Wuber is open")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.map: BookPlace in combat does nothing (Leave combat first); out of combat it opens Wuber", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local M = r.W.Map
	w:enterCombat(r)
	eq(M.BookPlace({ name = "Orgrimmar" }), false, "refused in combat")
	w:advance(1)
	ok(not windowShown(r), "Wuber stayed shut")
	w:leaveCombat(r)
	eq(M.BookPlace({ name = "Orgrimmar" }), true, "allowed again")
	w:advance(2)
	ok(windowShown(r), "Wuber opened")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.map: no place under the cursor with the map shut, off the map, or past its edge", function()
	local w, r, wm = cityMap()
	local M = r.W.Map
	eq(M.PlaceUnderCursor(false).name, "Orgrimmar", "control: over a city's own map the cursor is on the city") -- Map.lua PlaceUnderCursor
	r.mouseOver = nil
	eq(M.PlaceUnderCursor(false), nil, "cursor off the map")
	eq(M.PlaceUnderCursor(true), nil, "cursor off the map, wide")
	r.mouseOver = wm.ScrollContainer
	r.mapCursorX, r.mapCursorY = 1.5, 0.5
	eq(M.PlaceUnderCursor(false), nil, "past the right edge")
	eq(M.PlaceUnderCursor(true), nil, "past the right edge, wide")
	r.mapCursorX, r.mapCursorY = 0.5, 0.5
	wm:Hide()
	eq(M.PlaceUnderCursor(true), nil, "map shut")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.map: Ctrl + left click on a place opens Wuber; a plain click, a right click, a drag and a click in combat do not", function()
	local w, r, wm = cityMap()
	ok(not windowShown(r), "control: Wuber starts shut")
	r.mods.ctrl = false
	local sc = wm.ScrollContainer
	sc:GetScript("OnMouseDown")(sc, "LeftButton")
	sc:GetScript("OnMouseUp")(sc, "LeftButton") -- no Ctrl
	w:advance(1)
	ok(not windowShown(r), "a plain click leaves the map alone") -- Map.lua MouseUp: needs Ctrl
	ctrlClick(r, "RightButton")
	ok(not windowShown(r), "Ctrl + right click is not ours")
	ctrlClick(r, "LeftButton", function() r.cursorX = (r.cursorX or 960) + 40 end) -- the mouse moved 40 px: a drag
	ok(not windowShown(r), "a drag is not a click") -- MouseUp: |dx|+|dy| > 8
	r.cursorX = nil
	w:enterCombat(r)
	ctrlClick(r)
	ok(not windowShown(r), "in combat Wuber stays shut")
	w:leaveCombat(r)
	ctrlClick(r)
	ok(windowShown(r), "Ctrl + left click on Orgrimmar opens Wuber")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.map: the corner Ride here button names the place, stays 2 s after the cursor leaves, then goes; its click opens Wuber", function()
	local w, r, wm = cityMap()
	local M = r.W.Map
	w:advance(1) -- the 10 Hz tick runs UpdateHover
	M.UpdateHover()
	ok(#r:findText("Ride here: Orgrimmar", false, true) > 0, "the button shows the place") -- Map.lua UpdateHover
	r.mouseOver = nil -- the cursor leaves the map
	w:advance(1)
	ok(#r:findText("Ride here: Orgrimmar", false, true) > 0, "still there inside the grace (GRACE = 2 s)")
	w:advance(1.5)
	eq(#r:findText("Ride here: Orgrimmar", false, true), 0, "gone after the grace")
	r.mouseOver = wm.ScrollContainer
	w:advance(0.5)
	M.UpdateHover()
	ok(not windowShown(r), "control: Wuber still shut")
	r:clickText("Ride here: Orgrimmar") -- exact text of the button (Map.lua UpdateHover)
	w:advance(2)
	ok(windowShown(r), "the button opens Wuber")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.map: pins show for an online driver; SetShown(false) clears pins and button and fires SETTINGS; SetShown(true) brings them back", function()
	local w, r = mapWorld()
	local M = r.W.Map
	local fired
	r.W.Listen("SETTINGS", function(k) fired = k end)
	ok(M.ShowDriver("bob stone"), "the map opens on Bob")
	w:advance(1)
	eq(M.focus, "bob stone", "the driver ShowDriver showed is the focus")
	ok(shownPins(r) >= 1, "Bob's pin is drawn")
	eq(r.W.Mod("UI.Map.Base").pins[1].key, r.W.drivers["bob stone"].key, "pin 1 is Bob")
	ok(M.OnlyPill() and M.OnlyPill():IsShown(), "the Wuber-only pill shows with the pins")
	M.SetShown(false)
	eq(r.W.db.mapPins, false, "saved off")
	eq(fired, "mapPins", "SETTINGS fired with mapPins")
	eq(shownPins(r), 0, "no pins")
	ok(not M.OnlyPill():IsShown(), "pill gone")
	w:advance(1)
	eq(shownPins(r), 0, "still none after the tick")
	M.SetShown(true)
	eq(r.W.db.mapPins, true, "saved on")
	ok(shownPins(r) >= 1, "pins back")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.map: a hidden driver is never drawn; showing the driver again draws it", function()
	local w, r = mapWorld()
	local M = r.W.Map
	ok(M.ShowDriver("bob stone"), "map open on Bob")
	w:advance(1)
	ok(shownPins(r) >= 1, "control: pin drawn")
	r.W.db.hidden = r.W.db.hidden or {}
	r.W.db.hidden["bob stone"] = true -- Base.lua Drivers: Hidden(key)
	M.Refresh()
	eq(shownPins(r), 0, "hidden: no pin")
	r.W.db.hidden["bob stone"] = nil
	M.Refresh()
	ok(shownPins(r) >= 1, "unhidden: pin back") -- (unsure: needs W.drivers to keep Bob while hidden)
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.map: closing the map hides every pin; a burst of RedrawSoon makes at most one redraw now and one later; none while shut", function()
	local w, r = mapWorld()
	local M = r.W.Map
	local wm = r.env.WorldMapFrame
	ok(M.ShowDriver("bob stone"), "map open on Bob")
	w:advance(1)
	local base = M.redraws
	for _ = 1, 30 do M.RedrawSoon() end
	ok(M.redraws - base <= 1, "30 calls, at most one redraw at once: " .. (M.redraws - base)) -- Map.lua redrawSoon, REDRAW_GAP 0.25
	w:advance(0.3)
	ok(M.redraws - base >= 1 and M.redraws - base <= 2, "and one more after the gap: " .. (M.redraws - base))
	wm:Hide()
	w:advance(0.1)
	eq(shownPins(r), 0, "map shut: pins hidden (OnHide)")
	local shut = M.redraws
	M.RedrawSoon()
	eq(M.redraws, shut, "no redraw while the map is shut")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.map: Open ignores a bad map id (no move); ShowDriver of an unknown driver does nothing", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local M = r.W.Map
	local wm = r.env.WorldMapFrame
	local before = wm:GetMapID()
	eq(M.Open(-5), true, "a negative id just opens the map") -- Map.lua Open: mapID must be > 0
	ok(wm:IsShown(), "open")
	eq(wm:GetMapID(), before, "still on the same map")
	wm:Hide()
	eq(M.Open(0), true, "zero too")
	eq(wm:GetMapID(), before, "same map")
	wm:Hide()
	eq(M.ShowDriver("nobody here"), false, "no such driver") -- Map.lua ShowDriver: Driver(key) nil
	ok(not wm:IsShown(), "the map stayed shut")
	eq(M.focus, nil, "no focus")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.map: with OpenMap's stitched map, ShowDriver glides to the driver at least GLIDE_ZOOM close", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	local r = T.rider(w, T.TESTCHAR, { openMap = { stitched = true } })
	T.settle(w)
	T.goOnline(d, { price = 5000 })
	w:advance(2)
	local M, B = r.W.Map, r.W.Mod("UI.Map.Base")
	local bob = r.W.drivers["bob stone"]
	eq(#r.openMap.shown, 0, "control: nothing shown yet")
	ok(M.ShowDriver("bob stone"), "ShowDriver says yes")
	w:advance(0.3) -- OpenMap decides stitched or not as the map opens (W.After 0.05)
	ok(r.env.WorldMapFrame:IsShown(), "the map is open")
	ok(#r.openMap.shown >= 1, "OpenMapAPI.ShowWorld was asked to glide") -- Map.lua ShowDriver go()
	local last = r.openMap.shown[#r.openMap.shown]
	ok(type(last.u) == "number" and type(last.v) == "number", "to a stitched spot")
	local u, v = B.WorldUV(bob.mapID, bob.x, bob.y)
	near(last.u, u, "on Bob's world spot (u)")
	near(last.v, v, "on Bob's world spot (v)")
	eq(last.zoom, B.GLIDE_ZOOM, "zoomed to GLIDE_ZOOM (the fake's current zoom 1 is below it)")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.map: PinLevel puts pins above the canvas, never past 9000, and copes with a canvas that cannot say its level", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local Mod = r.W.Mod("UI.Map.Map")
	local above = r.W.Mod("UI.Map.Base").LEVEL_ABOVE
	eq(Mod.PinLevel({ GetFrameLevel = function() return 10 end }, false), 10 + above, "base + LEVEL_ABOVE") -- Map.lua PinLevel
	eq(Mod.PinLevel({ GetFrameLevel = function() return 99999 end }, false), 9000, "capped at 9000")
	eq(Mod.PinLevel({}, false), 1 + above, "no GetFrameLevel: starts from 1")
	T.clean(w)
end)
