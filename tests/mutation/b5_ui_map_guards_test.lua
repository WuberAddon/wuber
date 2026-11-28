local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function addDriver(r, key, opts)
	opts = opts or {}
	local d = {
		key = key,
		name = opts.name or key,
		service = opts.service,
		dest = opts.dest or "Orgrimmar",
		state = opts.state or "open",
		price = opts.price or 5000,
		team = opts.team or 1,
		queue = opts.queue or 0,
		seats = opts.seats,
		rank = opts.rank,
		mapID = opts.mapID,
		x = opts.x,
		y = opts.y,
		creator = opts.creator,
		seen = opts.seen or r.env.GetTime(),
	}
	r.W.drivers[key] = d
	return d
end

local function findOnlyPill(wm)
	local sc = wm and wm.ScrollContainer
	if not sc then return nil end
	for _, ch in ipairs({ sc:GetChildren() }) do
		if ch.text and ch.text.GetText and ch.text:GetText() == "Wuber only" then
			return ch
		end
	end
end

local function findVisiblePins(r)
	local out = {}
	local base = r.W.Mod("UI.Map.Base")
	for _, p in ipairs(base and base.pins or {}) do
		if p:IsShown() then
			out[#out + 1] = p
		end
	end
	return out
end

local function mapWithBob(opts)
	opts = opts or {}
	local w = T.newWorld()
	local d = T.driver(w, T.BOB, { spot = opts.spot or "Orgrimmar" })
	local r = T.rider(w, T.TESTCHAR, { spot = opts.spot or "Orgrimmar" })
	T.settle(w)
	T.goOnline(d, { price = opts.price or 5000 })
	w:advance(2)
	return w, r, d
end

-- guards Wuber/UI/Map/Map.lua:86 (owner == onlyPill -> not (owner == onlyPill): TipHide skipped on onlyPill)
-- guards Wuber/UI/Map/Map.lua:90 (owner == pins[i] -> owner ~= pins[i]: TipHide skipped on pin)
test("mutation b5 map: hiding map hides active tooltip on onlyPill and pins", function()
	local w, r = mapWithBob()
	local wm = r.env.WorldMapFrame
	wm:SetMapID(1454)
	wm:Show()
	w:advance(1)
	r.W.Map.Refresh()

	local hid = {}
	local owner = nil
	local origOwner, origHide = r.W.Theme.TipOwner, r.W.Theme.TipHide
	r.W.Theme.TipOwner = function() return owner end
	r.W.Theme.TipHide = function(f) hid[#hid + 1] = f end

	local pill = findOnlyPill(wm)
	ok(pill, "Wuber only pill exists")
	owner = pill
	r.W.Map.SetShown(false)
	eq(hid[#hid], pill, "SetShown(false) hides tip owned by onlyPill")

	r.W.Map.SetShown(true)
	r.W.Map.Refresh()
	local pins = findVisiblePins(r)
	ok(#pins >= 1, "driver pin visible")
	owner = pins[1]
	r.W.Map.SetShown(false)
	eq(hid[#hid], pins[1], "SetShown(false) hides tip owned by pin")

	r.W.Theme.TipOwner, r.W.Theme.TipHide = origOwner, origHide
	T.clean(w)
end)

-- guards Wuber/UI/Map/Map.lua:101 (api -> not api: ArtTopLevel ignored on stitched map)
-- guards Wuber/UI/Map/Map.lua:104 (top + 10 > level -> <=: PinLevel not raised above ArtTopLevel)
test("mutation b5 map: PinLevel rises above OpenMap ArtTopLevel on stitched map", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local origOM = r.env.OpenMapAPI
	r.env.OpenMapAPI = {
		major = 1,
		version = 2,
		IsStitched = function() return true end,
		Has = function(name) return name == "ArtTopLevel" or name == "MapAt" or name == "MapFromWorld" end,
		ArtTopLevel = function() return 500 end,
	}
	local MapMod = r.W.Mod("UI.Map.Map")
	local wm = r.env.WorldMapFrame
	local lvl = MapMod.PinLevel(wm.ScrollContainer.Child, true)
	ok(lvl >= 510, "PinLevel is at least ArtTopLevel + 10")
	r.env.OpenMapAPI = origOM
	T.clean(w)
end)

-- guards Wuber/UI/Map/Map.lua:202 (type(info) == "table" -> or: nil GetMapInfo crashes MapName)
test("mutation b5 map: PlaceUnderCursor handles missing cursor position and missing GetMapInfo", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Barrens" })
	T.settle(w)
	local wm = r.env.WorldMapFrame
	wm:SetMapID(1413)
	wm:Show()
	w:advance(1)

	local origCursor = r.env.GetCursorPosition
	r.env.GetCursorPosition = function() return nil, 100 end
	eq(r.W.Map.PlaceUnderCursor(true), nil, "partial nil cursor returns nil")
	r.env.GetCursorPosition = origCursor

	local origGetMapInfo = r.env.C_Map.GetMapInfo
	r.env.C_Map.GetMapInfo = function() return nil end
	r.mouseOver = wm.ScrollContainer
	r.mapCursorX, r.mapCursorY = 0.05, 0.05
	local p = r.W.Map.PlaceUnderCursor(true)
	ok(type(p) == "table" and p.mapID == 1413, "MainPlace still resolves by mapID when GetMapInfo returns nil")
	r.env.C_Map.GetMapInfo = origGetMapInfo
	T.clean(w)
end)

-- guards Wuber/UI/Map/Map.lua:252 (stitched -> not stitched: stitched MapAt branch skipped)
test("mutation b5 map: PlaceUnderCursor wide resolves zone via OpenMapAPI when stitched", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Barrens", openMap = { stitched = true } })
	T.settle(w)
	local wm = r.env.WorldMapFrame
	wm:SetMapID(1414)
	wm:Show()
	w:advance(1)
	local origCursor, origAt, origFromWorld = r.env.OpenMapAPI.CursorPosition, r.env.OpenMapAPI.MapAt, r.env.OpenMapAPI.MapFromWorld
	r.env.OpenMapAPI.CursorPosition = function() return 0.123, 0.456 end
	r.env.OpenMapAPI.MapAt = function() return 1413 end
	r.env.OpenMapAPI.MapFromWorld = function(m, u, v)
		if u == 0.123 and v == 0.456 then return 5.0, 5.0 end
		return origFromWorld(m, u, v)
	end
	r.mouseOver = wm.ScrollContainer
	eq(r.W.Mod("UI.Map.Base").Stitched(), true, "stitched is true")
	local p = r.W.Map.PlaceUnderCursor(true)
	ok(type(p) == "table" and p.mapID == 1413, "stitched wide cursor resolves Barrens via MapAt (got " .. tostring(p and p.name) .. ")")
	r.env.OpenMapAPI.CursorPosition, r.env.OpenMapAPI.MapAt, r.env.OpenMapAPI.MapFromWorld = origCursor, origAt, origFromWorld
	T.clean(w)
end)

-- guards Wuber/UI/Map/Map.lua:450 (drop statement: veil frame not created when mapOnly is on)
-- guards Wuber/UI/Map/Map.lua:473 (drop statement: onlyPill text not white when mapOnly is on)
-- guards Wuber/UI/Map/Map.lua:475 (drop statement: onlyPill text not muted when mapOnly is off)
-- guards Wuber/UI/Map/Map.lua:572 (drop statement: clicking Wuber only pill does nothing)
test("mutation b5 map: clicking Wuber only pill toggles mapOnly, veil, and pill text colour", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local wm = r.env.WorldMapFrame
	wm:SetMapID(1454)
	wm:Show()
	w:advance(1)
	r.W.Map.Refresh()

	local pill = findOnlyPill(wm)
	ok(pill, "Wuber only pill exists")
	eq(r.W.db.mapOnly, nil, "mapOnly starts off")

	r:clickOn(pill)
	w:advance(0.2)
	eq(r.W.db.mapOnly, true, "clicking Wuber only turns mapOnly on")
	local cr, cg, cb = pill.text:GetTextColor()
	eq(cr, 1, "active pill text red=1")
	eq(cg, 1, "active pill text green=1")
	eq(cb, 1, "active pill text blue=1")

	-- Verify veil child was created on Canvas
	local foundVeil = false
	for _, ch in ipairs({ wm.ScrollContainer.Child:GetChildren() }) do
		if ch.tex and ch:IsShown() then foundVeil = true break end
	end
	ok(foundVeil, "veil is created and shown when mapOnly is on")

	r:clickOn(pill)
	w:advance(0.2)
	eq(r.W.db.mapOnly, nil, "clicking Wuber only again turns mapOnly off")
	local mr = pill.text:GetTextColor()
	ok(mr < 1, "inactive pill text is muted (< 1)")
	T.clean(w)
end)

-- guards Wuber/UI/Map/Pins.lua:224 (name = nil: pin tooltip loses driver name)
-- guards Wuber/UI/Map/Pins.lua:256 (drop statement: Bring helpers line omitted in pin tooltip)
-- guards Wuber/UI/Map/Pins.lua:260 (and -> or: queue=0 wrongly shows 0 riders waiting)
test("mutation b5 map: pin tooltip shows rank, helpers needed, and queue count", function()
	local w, r = mapWithBob()
	local bob = r.W.drivers["bob stone"]
	bob.name = "Bob"
	bob.service = nil
	bob.team = 1
	bob.queue = 0
	bob.rank = 3
	local wm = r.env.WorldMapFrame
	wm:SetMapID(1454)
	wm:Show()
	w:advance(1)
	r.W.Map.Refresh()
	local pins = findVisiblePins(r)
	ok(#pins >= 1, "pin visible")

	local tipTitle, tipLines
	local origShow = r.W.Theme.TipShow
	r.W.Theme.TipShow = function(_, title, body)
		tipTitle, tipLines = title, body
	end
	pins[1]:GetScript("OnEnter")(pins[1])
	local flat0 = {}
	for _, entry in ipairs(tipLines or {}) do
		flat0[#flat0 + 1] = type(entry) == "table" and tostring(entry[1]) or tostring(entry)
	end
	ok(table.concat(flat0, "\n"):find("riders waiting", 1, true) == nil, "queue=0 omits riders waiting")

	bob.queue = 2
	pins[1]:GetScript("OnEnter")(pins[1])
	r.W.Theme.TipShow = origShow

	ok(tipTitle == "Bob", "tooltip title is driver name")
	local flat = {}
	for _, entry in ipairs(tipLines or {}) do
		flat[#flat + 1] = type(entry) == "table" and tostring(entry[1]) or tostring(entry)
	end
	local joined = table.concat(flat, "\n")
	ok(joined:find("Bring 2 helpers", 1, true) ~= nil, "tooltip shows Bring 2 helpers")
	ok(joined:find("2 riders waiting", 1, true) ~= nil, "tooltip shows 2 riders waiting")
	ok(joined:find("· 3", 1, true) ~= nil, "tooltip shows rank title and number")
	T.clean(w)
end)

-- guards Wuber/UI/Map/Pins.lua:583 (d.state == "paused" -> ~=: paused pin opens confirm, open pin ignored)
-- guards Wuber/UI/Map/Pins.lua:585 (drop statement: clicking pin skips click sound)
test("mutation b5 map: clicking open pin plays sound and opens confirm; paused pin does not", function()
	local w, r = mapWithBob()
	local wm = r.env.WorldMapFrame
	wm:SetMapID(1454)
	wm:Show()
	w:advance(1)
	r.W.Map.Refresh()

	local pins = findVisiblePins(r)
	eq(#pins, 1, "one pin visible")
	local pin = pins[1]

	local sounds = {}
	local shownScreen, shownKey
	local origSound, origShow = r.W.Sound, r.W.UI.Show
	r.W.Sound = function(s) sounds[#sounds + 1] = s end
	r.W.UI.Show = function(scr, k) shownScreen, shownKey = scr, k end

	r.W.drivers["bob stone"].state = "paused"
	r.W.Map.Refresh()
	r:clickOn(pin)
	eq(shownScreen, nil, "paused pin does not open confirm")

	r.W.drivers["bob stone"].state = "open"
	r.W.Map.Refresh()
	r:clickOn(pin)
	eq(sounds[#sounds], "click", "open pin plays click sound")
	eq(shownScreen, "confirm", "open pin opens confirm")
	eq(shownKey, "bob stone", "confirm opens for clicked driver key")

	r.W.Sound, r.W.UI.Show = origSound, origShow
	T.clean(w)
end)

-- guards Wuber/UI/Map/Pins.lua:622 (type(f) == "table" -> ~=: creator crown falls back to plain star)
-- guards Wuber/UI/Map/Pins.lua:626 (drop statement: creator crown not cached on pin.crowns)
test("mutation b5 map: creator pin uses W.FX.Crown and caches it on pin.crowns", function()
	local w, r = mapWithBob()
	local crownCalls = 0
	local fakeCrown = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	local origCrown, origCreator = r.W.FX.Crown, r.W.IsCreator
	r.W.IsCreator = function(k) return k == "bob stone" end
	r.W.FX.Crown = function()
		crownCalls = crownCalls + 1
		return fakeCrown
	end
	local wm = r.env.WorldMapFrame
	wm:SetMapID(1454)
	wm:Show()
	w:advance(1)
	r.W.Map.Refresh()
	local pins = findVisiblePins(r)
	ok(#pins >= 1, "creator pin visible")
	eq(pins[1].crown, fakeCrown, "pin.crown is the W.FX.Crown frame")
	eq(crownCalls, 1, "W.FX.Crown called once")
	r.W.Map.Refresh()
	eq(crownCalls, 1, "cached pin.crowns prevents recreating crown on Refresh")
	r.W.FX.Crown, r.W.IsCreator = origCrown, origCreator
	T.clean(w)
end)

-- guards Wuber/UI/Map/Route.lua:195 (type(W.FindPlace) == "function" -> ~=: FindPlace fallback skipped)
-- guards Wuber/UI/Map/Route.lua:242 (return nil: ViewRect fallback missing when ScrollContainer edges nil)
-- guards Wuber/UI/Map/Route.lua:275 (drop statement: mapRoute not created)
test("mutation b5 map: route draws using FindPlace fallback, driver coords, and ViewRect fallback", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Barrens", mapID = 1413, x = 0.2, y = 0.2 })
	T.settle(w)
	addDriver(r, "bob barrens", { dest = "Crossroads" })
	r.W.ride = { driverKey = "bob barrens", dest = "Crossroads", state = "invited" }

	local origExact, origFind, origPos = r.W.ExactPlace, r.W.FindPlace, r.W.MyPosition
	r.W.MyPosition = function() return 1413, 0.2, 0.2 end
	r.W.ExactPlace = function() return nil end
	r.W.FindPlace = function() return { name = "The Crossroads", mapID = 1413, x = 0.5, y = 0.5 } end

	local wm = r.env.WorldMapFrame
	wm:SetMapID(1413)
	wm:Show()
	w:advance(1)

	-- Clear ScrollContainer GetLeft so ViewRect exercises its (0, 0, w, h) fallback
	local origGetLeft = wm.ScrollContainer.GetLeft
	wm.ScrollContainer.GetLeft = function() return nil end
	r.W.Map.Refresh()
	wm.ScrollContainer.GetLeft = origGetLeft

	-- Route holder should be created as a child of Canvas
	local foundRoute = false
	for _, ch in ipairs({ wm.ScrollContainer.Child:GetChildren() }) do
		if ch.IsShown and ch:IsShown() and not ch.key and not ch.tex then
			foundRoute = true
			break
		end
	end
	ok(foundRoute, "route frame created and shown on map canvas")

	r.W.ExactPlace, r.W.FindPlace, r.W.MyPosition = origExact, origFind, origPos
	T.clean(w)
end)
