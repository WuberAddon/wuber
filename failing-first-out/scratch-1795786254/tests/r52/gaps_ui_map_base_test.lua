-- Final home: tests/ui/map/base_test.lua; add it to the per-module list in tests/run.lua.
-- Pins: the contract (W.Map and the internals other map modules bind); the guarded helpers (call, XY, Text, hex, Seed, ScaleTo) with good and bad input.
-- Pins: PriceRanks and Prominence (cheaper open driver glows more; busy / unknown price; the fallback rule); Chosen (a live ride beats the focus; done does not).
-- Pins: Drivers (hidden drivers never listed) and Driver (unknown key); BlizzardPos (same map, edges, outside 0..1, another continent); BadgeInfo (unknown / full path).
-- Pins: Canvas / MapShown / ShownMapID / PinsOn follow the world map and W.db.mapPins; with OpenMap the stitched helpers answer, without it they say no.
-- Why it matters to a player: these are the building blocks of every driver pin on the world map. If they broke, a hidden driver would be drawn anyway, the cheapest
-- driver would not glow, pins would land on the wrong zone or continent, and a ride in progress would not highlight its driver.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function near(a, b, what)
	ok(type(a) == "number" and math.abs(a - b) < 1e-6, (what or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end

-- a lone rider and the Base module's table
local function setup(opts)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, opts)
	T.settle(w)
	return w, r, r.W, r.W.Mod("UI.Map.Base")
end

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.base: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("UI.Map.Base", "tests/ui/map/base_test.lua", {
		["W.Map"] = "table",
		["Mod.pins"] = "table",
		["Mod.call"] = "function",
		["Mod.XY"] = "function",
		["Mod.Canvas"] = "function",
		["Mod.MapShown"] = "function",
		["Mod.ShownMapID"] = "function",
		["Mod.PinsOn"] = "function",
		["Mod.OM"] = "function",
		["Mod.OMHas"] = "function",
		["Mod.Stitched"] = "function",
		["Mod.WorldUV"] = "function",
		["Mod.OpenMapPos"] = "function",
		["Mod.World"] = "function",
		["Mod.MapXY"] = "function",
		["Mod.BlizzardPos"] = "function",
		["Mod.Drivers"] = "function",
		["Mod.Driver"] = "function",
		["Mod.IsFav"] = "function",
		["Mod.PriceRanks"] = "function",
		["Mod.Prominence"] = "function",
		["Mod.Seed"] = "function",
		["Mod.BadgeInfo"] = "function",
		["Mod.Chosen"] = "function",
		["Mod.Text"] = "function",
		["Mod.Accent"] = "function",
		["Mod.ScaleTo"] = "function",
		["Mod.hex"] = "function",
		["Mod.PIN"] = "number",
		["Mod.TICK"] = "number",
		["Mod.MEDIA"] = "string",
		["Mod.ROUTE"] = "table",
		["Mod.VIOLET"] = "table",
	})
	ok(Mod, "W.Mod(\"UI.Map.Base\")")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.base: call answers false for a missing object or method, passes results through and swallows errors", function()
	local w, r, W, B = setup()
	eq(select("#", B.call(nil, "Anything")), 1, "no object: just false")
	eq((B.call(nil, "Anything")), false, "no object")
	eq((B.call({}, "Missing")), false, "no such method")
	local okc, v = B.call({ Get = function(self, n) return n * 2 end }, "Get", 21)
	eq(okc, true, "ok")
	eq(v, 42, "the method's result") -- Base.lua call: pcall(f, obj, ...)
	local okb = B.call({ Boom = function() error("no") end }, "Boom")
	eq(okb, false, "an error is swallowed")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.base: XY reads a vector's x and y and gives nothing for anything else", function()
	local w, r, W, B = setup()
	local x, y = B.XY({ GetXY = function() return 0.25, 0.75 end })
	eq(x, 0.25, "x")
	eq(y, 0.75, "y")
	eq(B.XY({}), nil, "a table with no GetXY")
	eq(B.XY("a string"), nil, "not a table")
	eq(B.XY(nil), nil, "nil")
	eq(B.XY({ GetXY = function() error("secret") end }), nil, "GetXY raises")
	eq(B.XY({ GetXY = function() return "a", "b" end }), nil, "not numbers")
	eq(B.XY({ GetXY = function() return 0.5 end }), nil, "only one number")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.base: Text falls back for nothing; hex reads RRGGBB; Seed is stable, small and tells names apart", function()
	local w, r, W, B = setup()
	eq(B.Text(nil, "?"), "?", "no value: the fallback") -- Base.lua Text: W.Str(v) or fallback
	eq(B.Text("Bob", "?"), "Bob", "a name stays")
	local c = B.hex("FF8000")
	near(c[1], 1, "red")
	near(c[2], 128 / 255, "green")
	near(c[3], 0, "blue")
	eq(B.Seed(nil), 0, "no text: 0")
	eq(B.Seed(""), 0, "empty: 0")
	eq(B.Seed("a"), 97, "one letter: its byte")
	eq(B.Seed("ab"), (97 * 31 + 98) % 9973, "two letters")
	eq(B.Seed("abc"), 6597, "three letters: (3105 * 31 + 99) % 9973")
	eq(B.Seed("Bob Stone"), B.Seed("Bob Stone"), "stable")
	ok(B.Seed("Bob Stone") ~= B.Seed("Cal Brown"), "two drivers get different seeds")
	for _, s in ipairs({ "x", "Zed Rides", string.rep("long ", 50) }) do
		ok(B.Seed(s) >= 0 and B.Seed(s) < 9973, "in range: " .. s)
	end
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.base: ScaleTo drives either animation API (SetScaleFrom / SetScaleTo, or SetFromScale / SetToScale)", function()
	local w, r, W, B = setup()
	local log = {}
	local retail = { SetScaleFrom = function(self, x, y) log[#log + 1] = "from " .. x .. "," .. y end, SetScaleTo = function(self, x, y) log[#log + 1] = "to " .. x .. "," .. y end }
	B.ScaleTo(retail, 0.8, 2)
	eq(table.concat(log, ";"), "from 0.8,0.8;to 2,2", "retail names") -- Base.lua ScaleTo
	log = {}
	local classic = { SetFromScale = function(self, x, y) log[#log + 1] = "from " .. x .. "," .. y end, SetToScale = function(self, x, y) log[#log + 1] = "to " .. x .. "," .. y end }
	B.ScaleTo(classic, 1, 3)
	eq(table.concat(log, ";"), "from 1,1;to 3,3", "classic names")
	B.ScaleTo({}, 1, 2) -- neither: nothing happens, no error
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.base: PriceRanks ranks the distinct prices of open drivers only", function()
	local w, r, W, B = setup()
	local rank, n = B.PriceRanks({
		{ state = "open", price = 5000 },
		{ state = "open", price = 3000 },
		{ state = "open", price = 3000 }, -- the same price: one rank
		{ state = "busy", price = 1000 }, -- not open: not ranked
		{ state = "paused", price = 500 },
		{ state = "open" }, -- no price
	})
	eq(n, 2, "two distinct open prices") -- Base.lua PriceRanks: d.state == "open" and p and not seen[p]
	eq(rank[3000], 1, "the cheapest is rank 1")
	eq(rank[5000], 2, "the dearer rank 2")
	eq(rank[1000], nil, "busy is not ranked")
	local r0, n0 = B.PriceRanks({})
	eq(n0, 0, "no drivers")
	eq(next(r0), nil, "no ranks")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.base: Prominence without Net's own rule: cheaper open drivers glow more, busy and paused ones not at all", function()
	local w, r, W, B = setup()
	local saved = W.Prominence
	W.Prominence = nil -- the fallback rule of Base.lua Prominence ("else the same rule here")
	local list = { { state = "open", price = 1000 }, { state = "open", price = 2000 }, { state = "open", price = 3000 }, { state = "busy", price = 500 } }
	local rank, n = B.PriceRanks(list)
	local g1, c1 = B.Prominence(list[1], rank, n)
	local g2 = B.Prominence(list[2], rank, n)
	local g3 = B.Prominence(list[3], rank, n)
	near(g1, 0.7, "cheapest: 0.7 (others at most 0.7)")
	near(g2, 0.425, "middle: 0.15 + 0.55 * (1 - 1/2)")
	near(g3, 0.15, "dearest: 0.15")
	eq(c1, false, "not the creator")
	local gb, cb = B.Prominence(list[4], rank, n)
	eq(gb, 0, "busy: no glow")
	eq(cb, false, "busy: not the creator")
	local gs = B.Prominence({ state = "open", price = 1000 }, { [1000] = 1 }, 1)
	near(gs, 0.7, "a single open price: 0.7")
	local gu = B.Prominence({ state = "open" }, rank, n)
	near(gu, 0.7, "an open driver with no known price: 0.7")
	W.Prominence = saved
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.base: Prominence with Net's own rule stays between 0 and 1 and never calls an ordinary driver the creator", function()
	local w, r, W, B = setup()
	ok(type(W.Prominence) == "function", "Net provides W.Prominence")
	local list = { { key = "zed", state = "open", price = 1000 }, { key = "yan", state = "open", price = 9000 } }
	local rank, n = B.PriceRanks(list)
	for _, d in ipairs(list) do
		local glow, creator = B.Prominence(d, rank, n)
		ok(type(glow) == "number" and glow >= 0 and glow <= 1, "glow in 0..1: " .. tostring(glow)) -- Base.lua Prominence: clamped
		eq(creator, false, d.key .. " is not the creator")
	end
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.base: Drivers lists the drivers Net knows and never a hidden one; Driver answers nothing for an unknown key", function()
	local w = T.newWorld()
	local d1 = T.driver(w, T.BOB)
	local d2 = T.driver(w, T.CAL)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d1, { price = 5000 })
	T.goOnline(d2, { price = 7000 })
	w:advance(2)
	local W = r.W
	local B = W.Mod("UI.Map.Base")
	local function keys()
		local out = {}
		for _, d in ipairs(B.Drivers()) do out[d.key] = true end
		return out
	end
	local k = keys()
	ok(k["bob stone"] and k["cal brown"], "both drivers are listed")
	W.db.hidden = W.db.hidden or {}
	W.db.hidden["bob stone"] = true
	k = keys()
	ok(not k["bob stone"], "a hidden driver is not listed") -- Base.lua Drivers: Hidden(d.key)
	ok(k["cal brown"], "the other still is")
	eq(B.Driver("bob stone").key, "bob stone", "Driver finds a known key (hidden or not)")
	eq(B.Driver("nobody"), nil, "unknown key")
	eq(B.Driver(nil), nil, "nil key")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.base: Chosen is the driver of a ride under way, else the driver last shown, else nobody", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d, { price = 5000 })
	w:advance(2)
	local W = r.W
	local B = W.Mod("UI.Map.Base")
	eq(B.Chosen(), nil, "nobody chosen at first")
	W.Map.focus = "nobody"
	eq(B.Chosen(), nil, "a focus that is no known driver counts for nothing") -- Base.lua Chosen: Driver(M.focus)
	W.Map.focus = "bob stone"
	eq(B.Chosen(), "bob stone", "the driver last shown")
	W.ride = { id = "x", driver = "Cal Brown", driverKey = "cal brown", dest = "Orgrimmar", state = "summoning" }
	eq(B.Chosen(), "cal brown", "a ride under way beats the focus")
	W.ride.state = "paying"
	eq(B.Chosen(), "cal brown", "paying is still live")
	W.ride.state = "done"
	eq(B.Chosen(), "bob stone", "a finished ride does not")
	W.ride = nil
	W.Map.focus = nil
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.base: BlizzardPos keeps a driver on his own map, drops one outside 0..1, and drops another continent's", function()
	local w, r, W, B = setup()
	local x, y = B.BlizzardPos(1413, 0.5, 0.25, 1413)
	eq(x, 0.5, "same map: same x") -- Base.lua MapXY: mapID == shown
	eq(y, 0.25, "same map: same y")
	local ex, ey = B.BlizzardPos(1413, 0, 1, 1413)
	eq(ex, 0, "the edge counts")
	eq(ey, 1, "the far edge counts")
	eq(B.BlizzardPos(1413, 1.2, 0.5, 1413), nil, "past the right edge")
	eq(B.BlizzardPos(1413, -0.1, 0.5, 1413), nil, "past the left edge")
	eq(B.BlizzardPos(1413, 0.5, 1.01, 1413), nil, "below the map")
	eq(B.BlizzardPos(1413, 0.5, 0.5, 1415), nil, "Barrens driver on the Eastern Kingdoms map: another continent")
	local ax, ay = B.BlizzardPos(1413, 0.2, 0.5, 1414)
	local bx = B.BlizzardPos(1413, 0.8, 0.5, 1414)
	ok(ax and ay and ax >= 0 and ax <= 1 and ay >= 0 and ay <= 1, "a Barrens driver is on the Kalimdor map")
	ok(bx and bx > ax, "further east in the Barrens is further east on Kalimdor")
	eq(B.BlizzardPos(1413, 0.5, 0.5, 1411), nil, "a Barrens driver is not on Durotar's map") -- (unsure: depends on the fake map rects)
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.base: World gives the continent and world spot of a map position, the same continent for zones of one continent", function()
	local w, r, W, B = setup()
	local c1, wx, wy = B.World(1413, 0.5, 0.5)
	ok(type(c1) == "number" and type(wx) == "number" and type(wy) == "number", "a Barrens spot has a continent and world coordinates")
	local c2 = B.World(1411, 0.5, 0.5)
	eq(c2, c1, "Durotar is on the same continent")
	local c3 = B.World(1429, 0.5, 0.5)
	ok(c3 ~= nil and c3 ~= c1, "Elwynn Forest is on another")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.base: Canvas, MapShown, ShownMapID and PinsOn follow the world map and the saved switch", function()
	local w, r, W, B = setup()
	local wm = r.env.WorldMapFrame
	eq(B.Canvas(), wm.ScrollContainer.Child, "the canvas is the scroll container's child")
	eq(B.MapShown(), false, "the map starts shut")
	wm:SetMapID(1411) wm:Show()
	eq(B.MapShown(), true, "open")
	eq(B.ShownMapID(), 1411, "on Durotar")
	eq(B.PinsOn(), true, "pins are on by default")
	W.db.mapPins = false
	eq(B.PinsOn(), false, "switched off")
	W.db.mapPins = nil
	eq(B.PinsOn(), true, "only an explicit false turns them off") -- Base.lua PinsOn: W.db.mapPins == false
	wm:Hide()
	eq(B.MapShown(), false, "shut again")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.base: without OpenMap the stitched helpers say no; with it they answer and the version gate holds", function()
	local w, r, W, B = setup()
	eq(B.OM(), nil, "no OpenMap")
	eq(B.OMHas("ShowWorld"), nil, "no OpenMap function")
	eq(B.Stitched(), false, "not stitched")
	eq(B.WorldUV(1413, 0.5, 0.5), nil, "no stitched spot")
	eq(B.OpenMapPos(1413, 0.5, 0.5, 947), nil, "no stitched position")
	T.clean(w)
	local w2, r2, W2, B2 = setup({ openMap = { stitched = true } })
	ok(B2.OM() ~= nil, "OpenMap's API (major 1)")
	ok(B2.OMHas("ShowWorld"), "a function it offers")
	eq(B2.OMHas("NoSuchFunction"), nil, "one it does not")
	ok(B2.OMHas("ArtTopLevel", 2), "ArtTopLevel needs version 2: the fake is version 4") -- Base.lua OMHas(name, version)
	eq(B2.OMHas("ArtTopLevel", 99), nil, "a version it is not")
	eq(B2.Stitched(), true, "stitched")
	local u, v = B2.WorldUV(1413, 0.5, 0.5)
	ok(type(u) == "number" and type(v) == "number", "a stitched spot")
	local cx, cy = B2.OpenMapPos(1413, 0.5, 0.5, 947)
	ok(type(cx) == "number" and type(cy) == "number", "a stitched position on the world map")
	T.clean(w2)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.base: the route shows only while the rider is on the way (not once arrived or paying), and driver pins stack open over busy over paused", function()
	local w, r, W, B = setup()
	for _, s in ipairs({ "requesting", "accepted", "invited", "ingroup", "summoning", "portal" }) do
		eq(B.ROUTE[s], true, s .. " draws the route") -- Base.lua ROUTE
	end
	for _, s in ipairs({ "arrived", "paying", "done" }) do
		eq(B.ROUTE[s], nil, s .. " does not")
	end
	ok(B.STATE_LEVEL.open > B.STATE_LEVEL.busy and B.STATE_LEVEL.busy > B.STATE_LEVEL.paused, "open above busy above paused")
	ok(B.CREATOR_LEVEL > B.STATE_LEVEL.open and B.CHOSEN_LEVEL > B.CREATOR_LEVEL, "the creator above them, the chosen on top")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.base: BadgeInfo knows no badge for nothing or for an unknown id, and gives a known one a name and a full texture path", function()
	local w, r, W, B = setup()
	eq(B.BadgeInfo(nil), nil, "nil")
	eq(B.BadgeInfo(""), nil, "empty")
	eq(B.BadgeInfo("no such badge id"), nil, "unknown")
	ok(type(W.BADGES) == "table", "W.BADGES is there")
	local id
	for k, e in pairs(W.BADGES) do
		if type(k) == "string" then id = k break end
		if type(e) == "table" and type(e.id) == "string" then id = e.id break end
	end
	ok(id, "found a badge id in W.BADGES")
	local info = B.BadgeInfo(id)
	ok(info, "a known badge")
	eq(info.id, id, "its id")
	ok(type(info.name) == "string" and info.name ~= "", "a name")
	if type(info.tex) == "string" then ok(info.tex:find("[\\/]"), "a texture name becomes a full Media path: " .. info.tex) end -- BRIEF18
	T.clean(w)
end)
