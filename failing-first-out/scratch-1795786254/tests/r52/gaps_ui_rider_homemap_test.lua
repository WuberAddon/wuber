-- Tests of UI.Rider.Homemap. Adopted in r52 from the fable-2411 draft (job 2694); loaded by tests/run.lua with its helper table T.
-- Pins: updateMap with the game's map art (tiles, you dot, zone pill), without art (the hero picture) and with unusable art.
-- Pins: driver pins (only drivers on this map with a place, at most 24, pooled and hidden again, size and crown, click books).
-- Pins: your own "You" pin while you are open as a driver (hidden for a private beacon, another map or no spot; a tap opens Drive).
-- Pins: the location pill gives way to the raincheck sheet; UI.RouteOnMap (place lookup, clamps, clears an old line, no route fn).
-- Pins: Dock / Undock edge cases (nil arguments, options, hidden panels stay hidden, levels and shade restored).
-- Why it matters to a player: the map behind Home is where a rider sees who is near. If these broke the map could show pins for
-- drivers who are not on it, cover the raincheck sheet, leave a stale route line, or lose its place after the world view docks it.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function drv(env, name, mapID, x, y, extra)
	local d = { name = name, key = name:lower(), short = name, dest = "Undercity", price = 5000, state = "open", team = 3,
		service = name .. "'s Rides", heard = env.GetTime(), queue = 0, mapID = mapID, x = x, y = y }
	for k, v in pairs(extra or {}) do d[k] = v end
	return d
end

-- a rider in Orgrimmar and a fresh map panel (as tests/ui/rider/worldmap_test.lua builds one)
local function setup()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local W = r.W
	local home = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	home:SetSize(360, 600)
	home:SetPoint("TOPLEFT", r.env.UIParent, "TOPLEFT", 10, -10)
	local HM = W.Mod("UI.Rider.HomeMap")
	return w, r, W, HM, HM.buildMapPanel(home), home
end

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.homemap: contract (registered, deps, header, public names)", function()
	local W, w = T.contract("UI.Rider.HomeMap", "tests/ui/rider/homemap_test.lua", {
		["UI.RouteOnMap"] = "function", ["Mod.buildMapPanel"] = "function", ["Mod.updateMap"] = "function",
		["Mod.Dock"] = "function", ["Mod.Undock"] = "function",
	})
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.homemap: with the game's map art the panel draws its tiles, hides the hero picture and stands the you dot", function()
	local w, r, W, HM, m = setup()
	local mapID = r.env.C_Map.GetBestMapForUnit("player")
	ok(mapID, "the rider stands on a map")
	HM.updateMap(m, {})
	ok(not m.hero:IsShown(), "no hero picture over real art") -- HomeMap.lua:437
	ok(m.canvas:IsShown(), "the canvas shows")
	eq(#m.tiles, 12, "the fake's art layer is 4 x 3 tiles of 256") -- harness.lua:5966
	for i = 1, 12 do ok(m.tiles[i]:IsShown(), "tile " .. i) end
	ok(m.me:IsShown(), "the you dot stands on the map")
	eq(m.artFor, mapID, "the art is remembered for this map")
	eq(m.zone.label:GetText(), r.env.C_Map.GetMapInfo(mapID).name, "the zone pill names the map") -- HomeMap.lua:427
	-- the same map again: the art is not looked up a second time
	local looked = 0
	local real = r.env.C_Map.GetMapArtLayers
	r.env.C_Map.GetMapArtLayers = function(id) looked = looked + 1 return real(id) end
	HM.updateMap(m, {})
	eq(looked, 0, "cached art for the same map") -- HomeMap.lua:433
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.homemap: no map, or art the game cannot give, shows the hero picture and no pins; the pill says Azeroth with no map", function()
	local bad = {
		{ "no art layers", function(C) C.GetMapArtLayers = function() return nil end end },
		{ "a zero-width layer", function(C) C.GetMapArtLayers = function() return { { layerWidth = 0, layerHeight = 668, tileWidth = 256, tileHeight = 256 } } end end },
		{ "more than 64 tiles", function(C) C.GetMapArtLayers = function() return { { layerWidth = 256 * 9, layerHeight = 256 * 8, tileWidth = 256, tileHeight = 256 } } end end }, -- HomeMap.lua:143
		{ "no textures", function(C) C.GetMapArtLayerTextures = function() return nil end end },
		{ "a texture missing", function(C) C.GetMapArtLayerTextures = function() return {} end end }, -- HomeMap.lua:147
	}
	local w, r, W, HM, m0, home = setup()
	local C = r.env.C_Map
	local mapID = C.GetBestMapForUnit("player")
	local realLayers, realTextures, realBest = C.GetMapArtLayers, C.GetMapArtLayerTextures, C.GetBestMapForUnit
	for _, b in ipairs(bad) do
		C.GetMapArtLayers, C.GetMapArtLayerTextures = realLayers, realTextures
		b[2](C)
		local m = HM.buildMapPanel(home) -- a fresh panel: no cached art
		HM.updateMap(m, { drv(r.env, "Ana", mapID, 0.5, 0.5) })
		ok(m.hero:IsShown(), b[1] .. ": the hero picture") -- HomeMap.lua:521
		ok(not m.canvas:IsShown(), b[1] .. ": no canvas")
		ok(not m.me:IsShown(), b[1] .. ": no you dot")
		eq(#m.pins, 0, b[1] .. ": no pins")
	end
	C.GetMapArtLayers, C.GetMapArtLayerTextures = realLayers, realTextures
	C.GetBestMapForUnit = function() return nil end
	local m = HM.buildMapPanel(home)
	HM.updateMap(m, { drv(r.env, "Ana", 1, 0.5, 0.5) })
	eq(m.zone.label:GetText(), "Azeroth", "no map: Azeroth") -- HomeMap.lua:427
	ok(m.hero:IsShown(), "and the hero picture")
	C.GetBestMapForUnit = realBest
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.homemap: driver pins: only drivers on this map with a place, at most 24, sized by Founder, pooled and hidden again", function()
	local w, r, W, HM, m = setup()
	local mapID = r.env.C_Map.GetBestMapForUnit("player")
	local list = {
		drv(r.env, "Ana", mapID, 0.4, 0.5),
		drv(r.env, "Bea", mapID, 0.6, 0.5, { state = "busy" }),
		drv(r.env, "Cal", mapID + 1, 0.5, 0.5), -- another map
		drv(r.env, "Dan", mapID, nil, nil), -- no place
		drv(r.env, "Eve", mapID, 0.5, 0.6, { creator = true }),
	}
	HM.updateMap(m, list)
	eq(#m.pins, 3, "three drivers are on this map with a place") -- HomeMap.lua:483
	eq(m.pins[1].key, "ana", "first") eq(m.pins[2].key, "bea", "second") eq(m.pins[3].key, "eve", "third")
	for i = 1, 3 do ok(m.pins[i]:IsShown(), "pin " .. i .. " shown") end
	eq(m.pins[1]:GetWidth(), 22, "a driver's pin") -- HomeMap.lua:493
	eq(m.pins[3]:GetWidth(), 30, "a Founder's pin is bigger")
	ok(m.pins[3].crown and m.pins[3].crown:IsShown(), "and wears a crown") -- HomeMap.lua:501
	ok(not m.pins[1].crown, "no crown on a plain driver")
	ok(m.pins[1].pulse.running, "an open driver's pin pulses") -- HomeMap.lua:510
	ok(not m.pins[2].pulse.running, "a busy driver's pin does not")
	-- the click books that driver
	local booked = {}
	local real = W.UI.Show
	W.UI.Show = function(screen, key) booked[#booked + 1] = screen .. ":" .. tostring(key) end
	m.pins[2]:Click()
	W.UI.Show = real
	eq(booked[1], "confirm:bea", "a tap on a pin opens that driver's booking") -- HomeMap.lua:187
	-- only Ana is left: the other pins are kept, hidden and still
	HM.updateMap(m, { list[1] })
	eq(#m.pins, 3, "the pool is kept")
	ok(m.pins[1]:IsShown(), "Ana's pin stays")
	ok(not m.pins[2]:IsShown() and not m.pins[3]:IsShown(), "the others are hidden") -- HomeMap.lua:526
	ok(not m.pins[3].pulse.running, "and stop pulsing")
	-- thirty drivers: the first 24
	local crowd = {}
	for i = 1, 30 do crowd[i] = drv(r.env, "Pilot" .. i, mapID, 0.1 + i / 100, 0.5) end
	HM.updateMap(m, crowd)
	eq(#m.pins, 24, "never more than 24 pins") -- HomeMap.lua:483
	eq(m.pins[24].key, "pilot24", "the first 24 in the list's order")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.homemap: your own pin: shown while you are an open driver on this map, never for a private beacon, a tap opens Drive", function()
	local w, r, W, HM, m = setup()
	local mapID = r.env.C_Map.GetBestMapForUnit("player")
	local beacon = { mapID = mapID, x = 0.3, y = 0.4, state = "open" }
	W.DriverBeacon = function() return beacon end
	HM.updateMap(m, {})
	ok(m.ownPin and m.ownPin:IsShown(), "your pin shows") -- HomeMap.lua:241
	eq(m.ownPin.tag.label:GetText(), "You", "labelled You")
	beacon.only = true
	HM.updateMap(m, {})
	ok(not m.ownPin:IsShown(), "a private test beacon is not on the public map") -- HomeMap.lua:213
	beacon.only = nil
	beacon.mapID = mapID + 1
	HM.updateMap(m, {})
	ok(not m.ownPin:IsShown(), "another map: hidden")
	beacon.mapID, beacon.x = mapID, nil
	HM.updateMap(m, {})
	ok(not m.ownPin:IsShown(), "no spot: hidden")
	beacon.x = 0.3
	HM.updateMap(m, {})
	ok(m.ownPin:IsShown(), "back on the map")
	local tab
	W.UI.SelectTab = function(name) tab = name end
	m.ownPin:Click()
	eq(tab, "Drive", "a tap opens the Drive tab") -- HomeMap.lua:236
	W.DriverBeacon = function() return nil end
	HM.updateMap(m, {})
	ok(not m.ownPin:IsShown(), "no longer driving: gone")
	-- a strip (Confirm's or Found's panel) never shows your own pin
	W.DriverBeacon = function() return { mapID = mapID, x = 0.3, y = 0.4 } end
	local m2 = HM.buildMapPanel(r.env.UIParent)
	m2.strip = true
	HM.updateMap(m2, {})
	eq(m2.ownPin, nil, "strips draw no own pin") -- HomeMap.lua:211
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.homemap: the location pill gives way to the raincheck sheet while it shows", function()
	local w, r, W, HM, m = setup()
	local Kit = W.Mod("UI.Kit")
	HM.updateMap(m, {})
	ok(m.zone:IsShown(), "control: the pill shows")
	local sheet = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	Kit.ui.rcOffer = sheet
	HM.updateMap(m, {})
	ok(not m.zone:IsShown(), "hidden behind the raincheck sheet") -- HomeMap.lua:430
	sheet:Hide()
	HM.updateMap(m, {})
	ok(m.zone:IsShown(), "back once the sheet is gone")
	Kit.ui.rcOffer = nil
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.homemap: RouteOnMap finds the place, keeps the ends on the panel, clears an old line and does nothing without a route drawer", function()
	local w, r, W, HM, m = setup()
	local UI, Kit = W.UI, W.Mod("UI.Kit")
	local calls = {}
	W.Map = W.Map or {}
	W.Map.RouteOnPanel = function(panel, from, to, opts) calls[#calls + 1] = { from, to, opts } return "line" end
	W.ExactPlace = function(name) return { name = name, mapID = 1, x = 0.5, y = 0.5 } end
	local w0, h = m.mapW or Kit.WIN_W, m:GetHeight()
	local vb = m.visH or m.mapH
	m.routeDest = "Lowtown"
	UI.RouteOnMap(m, 1, 0.2, 0.3, 0, 0, 400, 300)
	eq(#calls, 1, "one line drawn")
	local from, to = calls[1][1], calls[1][2]
	ok(math.abs(from[1] - Kit.clamp(0.2 * 400 / w0, 0.03, 0.97)) < 1e-6, "from x: the rider's spot over the width") -- HomeMap.lua:370
	ok(math.abs(from[2] - Kit.clamp(0.3 * 300 / h, 0.05, math.min(0.95, (vb - 6) / h))) < 1e-6, "from y: kept above the sheet")
	eq(calls[1][3].level, 3, "drawn at level 3")
	eq(m.route, "line", "the panel remembers its line")
	ok(m.routed, "and that it drew one")
	-- a place far off the panel's edge is clamped to 3% / 97% and 5% / above the sheet
	W.ExactPlace = function(name) return { name = name, mapID = 1, x = 9, y = 9 } end
	UI.RouteOnMap(m, 1, 0.2, 0.3, 0, 0, 400, 300)
	to = calls[2][2]
	eq(to[1], 0.97, "x clamped") -- HomeMap.lua:370
	ok(math.abs(to[2] - math.min(0.95, (vb - 6) / h)) < 1e-6, "y clamped above the sheet")
	-- the exact lookup finds nothing: the plain lookup still routes
	W.ExactPlace = function() return nil end
	W.FindPlace = function(name) return { name = name, mapID = 1, x = 0.5, y = 0.5 } end
	UI.RouteOnMap(m, 1, 0.2, 0.3, 0, 0, 400, 300)
	eq(#calls, 3, "FindPlace is the fallback") -- HomeMap.lua:338
	ok(calls[3][1], "a line from the rider")
	-- a place on another map that the world cannot place: no line, and the old one is cleared
	W.ExactPlace = function(name) return { name = name, mapID = 999 } end
	W.PlaceWorld = function() return nil end
	UI.RouteOnMap(m, 1, 0.2, 0.3, 0, 0, 400, 300)
	eq(#calls, 4, "the old line is cleared") -- HomeMap.lua:395
	eq(calls[4][1], nil, "with nil, nil")
	eq(m.routed, false, "nothing drawn now")
	-- no rider spot: nothing to route from
	W.ExactPlace = function(name) return { name = name, mapID = 1, x = 0.5, y = 0.5 } end
	UI.RouteOnMap(m, 1, nil, nil, 0, 0, 400, 300)
	eq(m.routed, false, "no spot, no line") -- HomeMap.lua:364
	-- no destination and no ride: the panel still holds its old line, so it is cleared once more with nil, nil
	m.routeDest = nil
	local n = #calls
	UI.RouteOnMap(m, 1, 0.2, 0.3, 0, 0, 400, 300)
	eq(#calls, n + 1, "the old line is cleared when the destination goes") -- HomeMap.lua:395
	eq(calls[n + 1][1], nil, "from nil")
	eq(calls[n + 1][2], nil, "to nil")
	-- no drawer at all: returns quietly
	W.Map.RouteOnPanel = nil
	m.routeDest = "Lowtown"
	UI.RouteOnMap(m, 1, 0.2, 0.3, 0, 0, 400, 300)
	eq(#calls, n + 1, "no RouteOnPanel: nothing drawn, no error") -- HomeMap.lua:357
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.homemap: Dock and Undock ignore missing arguments, take options, keep a hidden panel hidden and restore levels and shade", function()
	local w, r, W, HM, m, home = setup()
	local holder = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	holder:SetSize(400, 600)
	holder:SetPoint("TOPLEFT", r.env.UIParent, "TOPLEFT", 500, -10)
	eq(HM.Dock(nil, holder), nil, "no panel") -- HomeMap.lua:565
	eq(HM.Dock(m, nil), nil, "no holder")
	eq(m:GetParent(), home, "nothing moved")
	eq(HM.Undock(nil), nil, "no panel to undock")
	eq(HM.Undock(m), m, "a panel never docked comes back as it is") -- HomeMap.lua:601
	local lvl = m.dots:GetFrameLevel() - m:GetFrameLevel()
	local shade = m.shadeBottom:GetHeight()
	m:Hide()
	HM.Dock(m, holder, { w = 300, h = 400, vis = 200, top = 10 })
	eq(m:GetWidth(), 300, "option w") eq(m:GetHeight(), 400, "option h")
	eq(m.mapW, 300, "mapW") eq(m.mapH, 400, "mapH") eq(m.visH, 200, "option vis") -- HomeMap.lua:581
	eq(m.canvas:GetWidth(), 300, "the canvas follows")
	eq(math.floor(holder:GetTop() - m:GetTop() + 0.5), 10, "option top")
	eq(m.shadeBottom:GetHeight(), 64, "the dock's own shade") -- HomeMap.lua:584
	eq(m.dots:GetFrameLevel() - m:GetFrameLevel(), lvl, "the dots stay the same distance above the panel") -- HomeMap.lua:577
	ok(not m:IsShown(), "docking does not show a hidden panel")
	-- docked again into the same holder, then undocked: the first place is the one restored
	HM.Dock(m, holder)
	HM.Undock(m)
	eq(m:GetParent(), home, "back in Home")
	ok(not m:IsShown(), "still hidden, as it was when docked") -- HomeMap.lua:620
	eq(m.shadeBottom:GetHeight(), shade, "the shade is back")
	eq(m.dots:GetFrameLevel() - m:GetFrameLevel(), lvl, "levels restored")
	eq(m.docked, nil, "no longer docked")
	eq(m.undocked, nil, "and nothing left to restore")
	T.clean(w)
end)
