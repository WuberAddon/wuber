-- Wuber 2.4, part 6c: mid-flight offer marks the offered driver's pin as chosen on the world map. Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local UC_TM = {
	{ name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 },
	{ name = "Tarren Mill, Hillsbrad", type = "REACHABLE", cost = 330, x = 0.47, y = 0.44 },
	{ name = "Hammerfall, Arathi", type = "REACHABLE", cost = 530 },
	{ name = "Kalimdor's Nowhere, Somewhere", type = "REACHABLE", cost = 100 },
}

local function setTime(r, secs)
	r.W.db.flights = r.W.db.flights or {}
	r.W.db.flights["H|undercity|tarren mill"] = { t = secs, tat = r.env.time(), tsrc = "own" }
end

local function placeOf(r, name)
	if type(r.W.ExactPlace) == "function" then
		local p = r.W.ExactPlace(name)
		if type(p) == "table" then return p end
	end
	for _, p in ipairs(r.W.PLACES or {}) do
		if type(p) == "table" and p.name == name then return p end
	end
end

local function setDriver(r, key, name, dest, price)
	local p = placeOf(r, dest)
	r.W.drivers = r.W.drivers or {}
	r.W.drivers[key] = {
		name = name,
		key = key,
		dest = dest,
		mapID = p and p.mapID,
		x = p and p.x,
		y = p and p.y,
		price = price or 5000,
		state = "open",
		team = 3,
		service = name .. "'s Rides",
		heard = r.env.GetTime(),
	}
end

local function setupRider(secs)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Undercity", screenW = 1365, screenH = 768 })
	T.settle(w)
	if secs then setTime(r, secs) end
	return w, r
end

local function findPin(child, key)
	for _, f in ipairs({ child:GetChildren() }) do
		if f.key == key and H.visible(f) then return f end
	end
end

local function anyChosenPin(child)
	for _, f in ipairs({ child:GetChildren() }) do
		if f.key and H.visible(f) and f.chosen then return f end
	end
end

test("v24 inflightmap: while the card shows, the offered driver's pin is chosen, and after clicking x no pin is chosen", function()
	local w, r = setupRider(240)
	local W = r.W
	local Mod = W.Mod("UI.InFlight")
	setDriver(r, "mia runner", "Mia Runner", "Tarren Mill", 5000)

	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 240, "Tarren Mill")
	w:advance(3)

	local c = Mod.Card()
	ok(c and H.visible(c), "WuberInFlight card is visible")

	local p = placeOf(r, "Tarren Mill")
	ok(p and p.mapID, "Tarren Mill has a mapID")
	r.env.WorldMapFrame:SetMapID(p.mapID)
	r.env.WorldMapFrame:Show()
	w:advance(0.1)

	local child = r.env.WorldMapFrame.ScrollContainer.Child
	local pin = findPin(child, "mia runner")
	ok(pin, "offered driver's pin is showing on the world map")
	eq(pin.chosen, true, "offered driver's pin is chosen while the card shows")

	r:clickOn(c.x)
	w:advance(0.5)
	ok(not H.visible(c), "x hides the card")
	eq(anyChosenPin(child), nil, "no pin is chosen after closing the card")

	w:advance(245)
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)

test("v24 inflightmap: open map repaints when the card shows, and an explicit map choice wins over the card", function()
	local w, r = setupRider(240)
	local W = r.W
	local Mod = W.Mod("UI.InFlight")
	setDriver(r, "mia runner", "Mia Runner", "Tarren Mill", 5000)
	setDriver(r, "bob stone", "Bob Stone", "Tarren Mill", 6000)

	local p = placeOf(r, "Tarren Mill")
	ok(p and p.mapID, "Tarren Mill has a mapID")
	r.env.WorldMapFrame:SetMapID(p.mapID)
	r.env.WorldMapFrame:Show()
	w:advance(0.1)

	local child = r.env.WorldMapFrame.ScrollContainer.Child
	eq(anyChosenPin(child), nil, "no pin is chosen before flying")

	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 240, "Tarren Mill")
	w:advance(3)

	local c = Mod.Card()
	ok(c and H.visible(c), "WuberInFlight card is visible")
	local miaPin = findPin(child, "mia runner")
	local bobPin = findPin(child, "bob stone")
	ok(miaPin and bobPin, "both driver pins are visible on the map")
	eq(miaPin.chosen, true, "open map repaints and marks the offered driver's pin as chosen")
	eq(bobPin.chosen, false, "the other driver's pin is not chosen")

	ok(W.Map.ShowDriver("bob stone"), "ShowDriver chooses Bob explicitly")
	w:advance(0.1)
	eq(bobPin.chosen, true, "explicit map choice wins over the card's driver")
	eq(miaPin.chosen, false, "card's driver is no longer chosen when another driver is focused")

	w:advance(245)
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)
