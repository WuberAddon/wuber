local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function addFakeDriver(r, key, dest, state, price)
	r.W.drivers[key] = {
		key = key,
		name = key,
		dest = dest,
		state = state,
		price = price,
	}
end

-- guards Wuber/UI/Map/Map.lua:134 (Same uses W.SamePlace instead of skipping it)
test("mutation b3 map DriversTo matches place aliases via W.SamePlace", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	addFakeDriver(r, "bob stone", "Org", "open", 5000)
	local n, price = r.W.Map.DriversTo({ name = "Orgrimmar" })
	eq(n, 1, "driver with alias destination is counted")
	eq(price, 5000, "driver fare is returned")
	T.clean(w)
end)

-- guards Wuber/UI/Map/Map.lua:207 (MainPlace does not bail when W.PLACES is a table)
test("mutation b3 map PlaceUnderCursor wide falls back to zone MainPlace", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Barrens" })
	T.settle(w)
	local wm = r.env.WorldMapFrame
	wm:SetMapID(1413)
	wm:Show()
	w:advance(1)
	r.mouseOver = wm.ScrollContainer
	r.mapCursorX, r.mapCursorY = 0.05, 0.05
	local p = r.W.Map.PlaceUnderCursor(true)
	ok(type(p) == "table" and p.name == "The Barrens", "wide cursor over empty part of Barrens resolves to MainPlace")
	T.clean(w)
end)

-- guards Wuber/UI/Map/Map.lua:267 (PlaceUnderCursor wide switches to child zone on continent map)
test("mutation b3 map PlaceUnderCursor wide resolves child zone on continent map", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local wm = r.env.WorldMapFrame
	wm:SetMapID(1414)
	wm:Show()
	w:advance(1)
	r.mouseOver = wm.ScrollContainer
	-- Orgrimmar/Durotar area on Kalimdor: use GetMapRectOnMap for 1413 (The Barrens) center
	local l, rr, t, b = r.env.C_Map.GetMapRectOnMap(1413, 1414)
	ok(l ~= nil, "Barrens rect on Kalimdor exists")
	r.mapCursorX, r.mapCursorY = (l + rr) / 2, (t + b) / 2
	local p = r.W.Map.PlaceUnderCursor(true)
	ok(type(p) == "table" and p.mapID == 1413, "wide cursor over Barrens on Kalimdor resolves to a Barrens place")
	T.clean(w)
end)

-- guards Wuber/UI/Map/Map.lua:282 (PlaceUnderCursor wide uses W.PlaceAt for nearest place)
test("mutation b3 map PlaceUnderCursor wide picks nearest place via PlaceAt", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Barrens" })
	T.settle(w)
	local wm = r.env.WorldMapFrame
	wm:SetMapID(1413)
	wm:Show()
	w:advance(1)
	r.mouseOver = wm.ScrollContainer
	-- Slightly outside RADIUS (26px) of Ratchet (0.627, 0.370) so spot loop misses, but within PlaceAt 0.08
	r.mapCursorX, r.mapCursorY = 0.627 + 0.04, 0.370 + 0.04
	local p = r.W.Map.PlaceUnderCursor(true)
	ok(type(p) == "table" and p.name == "Ratchet", "wide cursor near Ratchet resolves to Ratchet, not zone MainPlace")
	T.clean(w)
end)

-- guards Wuber/UI/Map/Map.lua:298 (DriversTo prefers cheapest open fare over cheaper busy fare)
test("mutation b3 map DriversTo prefers cheapest open fare over cheaper busy fare", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	addFakeDriver(r, "busy cheap", "Orgrimmar", "busy", 2000)
	addFakeDriver(r, "open fair", "Orgrimmar", "open", 5000)
	local n, price = r.W.Map.DriversTo({ name = "Orgrimmar" })
	eq(n, 2, "both drivers counted")
	eq(price, 5000, "cheapest open fare is returned, not busy driver's lower fare")
	T.clean(w)
end)

-- guards Wuber/UI/Map/Map.lua:322 (BookPlace resolves canonical place via W.ExactPlace)
test("mutation b3 map BookPlace resolves alias via W.ExactPlace", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local shownScreen, shownArg
	local origShow = r.W.UI.Show
	r.W.UI.Show = function(screen, arg)
		shownScreen, shownArg = screen, arg
		return origShow(screen, arg)
	end
	local res = r.W.Map.BookPlace("org")
	eq(res, true, "BookPlace succeeds")
	eq(shownScreen, "book", "opens book screen")
	eq(shownArg, "Orgrimmar", "canonical place name is passed to UI.Show")
	T.clean(w)
end)

-- guards Wuber/UI/Map/Map.lua:330 (BookPlace in combat shows Leave combat first toast)
test("mutation b3 map BookPlace in combat shows Leave combat first toast", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local toastMsg, toastKind
	r.W.UI.Toast = function(msg, kind)
		toastMsg, toastKind = msg, kind
	end
	w:enterCombat(r)
	local res = r.W.Map.BookPlace("Orgrimmar")
	eq(res, false, "BookPlace refused in combat")
	eq(toastMsg, "Leave combat first", "combat toast is shown")
	eq(toastKind, "warn", "combat toast is warn")
	T.clean(w)
end)

-- guards Wuber/UI/Map/Map.lua:339 (BookPlace fallback to home populates search box)
test("mutation b3 map BookPlace fallback to home fills search box", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local origShow = r.W.UI.Show
	r.W.UI.Show = function(screen, arg)
		if screen == "book" then return false end
		return origShow(screen, arg)
	end
	local searched
	r.W.UI.SetSearch = function(q)
		searched = q
	end
	local res = r.W.Map.BookPlace("Orgrimmar")
	eq(res, true, "BookPlace fallback returns true")
	eq(searched, "Orgrimmar", "SetSearch is called with place name")
	T.clean(w)
end)

-- guards Wuber/UI/Map/Map.lua:638 (UpdateHover shows hover tag when cursor and canvas metrics exist)
test("mutation b3 map UpdateHover shows Ride here tag over a place", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local wm = r.env.WorldMapFrame
	wm:SetMapID(1454)
	wm:Show()
	w:advance(1)
	r.mouseOver = wm.ScrollContainer
	r.mapCursorX, r.mapCursorY = 0.5, 0.5
	r.W.Map.UpdateHover()
	ok(#r:findText("no drivers yet", false, true) > 0, "hover tag with Ride here text is shown on canvas")
	T.clean(w)
end)

-- guards Wuber/UI/Map/Map.lua:883 (Open fallback path returns true when map opens)
test("mutation b3 map Open fallback returns true when C_Map.OpenWorldMap is absent", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	r.env.C_Map.OpenWorldMap = nil
	local res = r.W.Map.Open(1454)
	eq(res, true, "Open fallback returns true")
	ok(r.env.WorldMapFrame:IsShown() == true, "WorldMapFrame is shown")
	T.clean(w)
end)
