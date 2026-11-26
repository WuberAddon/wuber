-- Run 1 fix round, group e (item 3): the flight map price tags with Daylight UI. The real client never fired
-- TAXIMAP_OPENED (recorder: 18 TAXIMAP_CLOSED, no OPENED), Daylight resizes TaxiFrame after it shows and moves
-- its buttons, and FlightMapFrame may be the map. Loaded by tests/run.lua (tests/v24/*_test.lua) with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }

local function addDriver(r, key, opts)
	local W = r.W
	W.drivers = W.drivers or {}
	W.drivers[key] = { name = opts.name or key, key = key, dest = opts.dest, price = opts.price or 5000,
		state = "open", team = 3, heard = r.env.GetTime() }
end

local function slotOf(nodes, town)
	for i, n in ipairs(nodes) do
		if (n.name:match("^([^,]+)") or n.name) == town then return i end
	end
end

local function inside(a, b)
	return a.l >= b.l - 0.5 and a.l + a.w <= b.l + b.w + 0.5 and a.b >= b.b - 0.5 and a.b + a.h <= b.b + b.h + 0.5
end

-- The map frame as the real client has it before any open (FrameXML / Blizzard_FlightMap made it), hidden.
local function makeMap(r, fname)
	local env = r.env
	local f = rawget(env, fname)
	if f then return f end
	local g = (fname == "FlightMapFrame") and { w = 618, h = 482 } or { w = 603, h = 638 }
	f = H.createFrame(r, "Frame", fname, env.UIParent)
	f:SetSize(g.w, g.h)
	f:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 16, -118)
	f:SetFrameStrata("MEDIUM")
	if T.S and T.S[f] then T.S[f].gameFrame = true end
	f:Hide()
	return f
end

-- Opens the map the way the real client did: the frame shows (OnShow), the taxi API answers, and
-- TAXIMAP_OPENED never fires.
local function openSilently(r, nodes, fname)
	local env = r.env
	local f = makeMap(r, fname)
	r.taxi = { nodes = nodes, open = true, frame = f }
	env.NumTaxiNodes = function() return #nodes end
	env.TaxiNodeName = function(i) return nodes[i] and nodes[i].name or nil end
	env.TaxiNodeGetType = function(i) return nodes[i] and nodes[i].type or "NONE" end
	env.TaxiNodeCost = function(i) return nodes[i] and nodes[i].cost or 0 end
	f:Show()
	return f
end

local function setup()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	T.settle(w)
	addDriver(r, "anita lift", { name = "Anita Lift", dest = "Orgrimmar", price = 5000 })
	return w, r, r.W.Mod("UI.FlightPins")
end

local function shownTag(Mod)
	local pins = Mod.Pins()
	return pins[1] and pins[1].tag, pins
end

test("run1 e pins: the map opened by OnShow alone (no TAXIMAP_OPENED) gets its price tag, above the map", function()
	local w, r, Mod = setup()
	local nodes = H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } })
	makeMap(r, "TaxiFrame")
	r:fire("ADDON_LOADED", "DaylightUI_Skins") -- the frame exists from login in the real client
	local map = openSilently(r, nodes, "TaxiFrame")
	w:advance(1.5)
	local tag, pins = shownTag(Mod)
	eq(#pins, 1, "one pin")
	ok(tag and H.visible(tag), "the price tag shows")
	ok(tag and tag:IsMouseEnabled(), "the tag takes clicks")
	ok(#r:findText("^50s$") > 0, "the player sees 50s")
	local holder = r.env.WuberFlightPins
	ok(STRATA[holder:GetFrameStrata()] > STRATA[map:GetFrameStrata()], "the tags sit in a strata above the map's")
	ok(inside(H.rect(tag), H.rect(map)), "the tag is on the map")
	map:Hide()
	w:advance(1.5)
	ok(not H.visible(tag), "closing the map hides the tag")
	T.clean(w)
end)

test("run1 e pins: Daylight resizes the map and moves its buttons after the open: the tag follows, inside the map", function()
	local w, r, Mod = setup()
	local env = r.env
	local nodes = H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } })
	w:openTaxiMap(r, nodes)
	w:advance(0.3) -- after Wuber's own refreshes at the open
	local map = env.TaxiFrame
	map:SetSize(880, 950) -- Daylight's taxiLayout: a bigger window, the map inset 12 px in under a header
	local slot = slotOf(nodes, "Orgrimmar")
	local btn = H.createFrame(r, "Button", "TaxiButton" .. slot, map)
	btn:SetSize(18, 18)
	btn:SetPoint("CENTER", map, "TOPLEFT", 700, -420)
	btn:Show()
	w:advance(1.5)
	local tag, pins = shownTag(Mod)
	ok(tag and H.visible(tag), "the tag still shows")
	local mr, br, kr = H.rect(map), H.rect(btn), H.rect(pins[1].marker)
	ok(math.abs((kr.l + kr.w / 2) - (br.l + br.w / 2)) < 1 and math.abs((kr.b + kr.h / 2) - (br.b + br.h / 2)) < 1,
		"the marker is centred on the moved button")
	ok(inside(H.rect(tag), mr), "the tag is inside the resized map")
	local tr = H.rect(tag)
	ok(math.abs((tr.b + tr.h / 2) - (br.b + br.h / 2)) < 30 and math.abs((tr.l + tr.w / 2) - (br.l + br.w / 2)) < 80,
		"the tag is beside the moved button")
	T.clean(w)
end)

test("run1 e pins: FlightMapFrame only gets the price tag too", function()
	local w, r, Mod = setup()
	local nodes = H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } })
	w:openTaxiMap(r, nodes, { frame = "FlightMapFrame" })
	w:advance(0.5)
	local tag = shownTag(Mod)
	ok(tag and H.visible(tag), "the price tag shows on FlightMapFrame")
	ok(inside(H.rect(tag), H.rect(r.env.FlightMapFrame)), "on the map")
	eq(Mod.Why(), nil, "Why is quiet while the tag shows")
	T.clean(w)
end)

test("run1 e pins: FlightMapFrame opened by OnShow alone, made late by Blizzard_FlightMap, gets the tag", function()
	local w, r, Mod = setup()
	local nodes = H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } })
	makeMap(r, "FlightMapFrame")
	r:fire("ADDON_LOADED", "Blizzard_FlightMap")
	openSilently(r, nodes, "FlightMapFrame")
	w:advance(1.5)
	local tag = shownTag(Mod)
	ok(tag and H.visible(tag), "the price tag shows")
	T.clean(w)
end)
