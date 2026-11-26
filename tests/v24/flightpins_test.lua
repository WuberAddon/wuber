-- Wuber 2.4, part 4: flight map summon price tags on TaxiFrame. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function addDriver(r, key, opts)
	local W = r.W
	W.drivers = W.drivers or {}
	W.drivers[key] = {
		name = opts.name or key,
		key = key,
		dest = opts.dest,
		price = opts.price or 5000,
		state = opts.state or "open",
		team = opts.team or 3,
		service = opts.service,
		heard = r.env.GetTime(),
	}
end

local function overlaps(a, b)
	return not (a.l + a.w <= b.l + 0.5 or b.l + b.w <= a.l + 0.5 or a.b + a.h <= b.b + 0.5 or b.b + b.h <= a.b + 0.5)
end

local function readTip(r, btn)
	local onEnter = btn:GetScript("OnEnter")
	if onEnter then onEnter(btn) end
	local gt = r.env.GameTooltip
	local parts = {}
	if gt and type(gt.NumLines) == "function" then
		for i = 1, gt:NumLines() do
			local fs = r.env["GameTooltipTextLeft" .. i]
			local txt = fs and type(fs.GetText) == "function" and fs:GetText()
			if txt and txt ~= "" then parts[#parts + 1] = txt end
		end
	end
	if #parts == 0 and gt and type(gt.lines) == "table" then
		for _, ln in ipairs(gt.lines) do
			if type(ln) == "string" then
				parts[#parts + 1] = ln
			elseif type(ln) == "table" and type(ln.text) == "string" then
				parts[#parts + 1] = ln.text
			elseif type(ln) == "table" and type(ln[1]) == "string" then
				parts[#parts + 1] = ln[1]
			end
		end
	end
	if #parts == 0 then
		for _, txt in ipairs(r:visibleTexts()) do
			if txt:find("summon to", 1, true) then parts[#parts + 1] = txt end
		end
	end
	local onLeave = btn:GetScript("OnLeave")
	if onLeave then onLeave(btn) end
	return table.concat(parts, "\n")
end

test("v24 pins: open drivers on the map get a price tag; closed or off-map drivers get none", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	T.settle(w)
	addDriver(r, "anita lift", { name = "Anita Lift", dest = "Orgrimmar", price = 5000, state = "open" })
	addDriver(r, "bob stone", { name = "Bob Stone", dest = "Ratchet", price = 4000, state = "closed" })
	addDriver(r, "cal north", { name = "Cal North", dest = "Undercity", price = 3000, state = "open" })

	local Mod = r.W.Mod("UI.FlightPins")
	eq(rawget(r.env, "WuberFlightPins"), nil, "no holder built at load")
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } }))
	w:advance(0.5)

	local pins = Mod.Pins()
	eq(#pins, 1, "only the one open driver on this map gets a pin")
	eq(pins[1].node, "Orgrimmar, Durotar", "matched node")
	eq(pins[1].driver, "anita lift", "matched driver")
	eq(pins[1].price, 5000, "matched price")
	ok(pins[1].tag and H.visible(pins[1].tag), "price tag is visible")
	ok(pins[1].marker and H.visible(pins[1].marker), "marker is visible")
	ok(#r:findText("^50s$") > 0, "player sees 50s tag")
	eq(#r:findText("^40s$"), 0, "closed driver shows no tag")
	eq(#r:findText("^30s$"), 0, "off-map driver shows no tag")
	eq(Mod.Why(), nil, "Why is nil while pins show")

	-- remove the open driver on this map: no pins show and Why explains why
	w:closeTaxiMap(r)
	r.W.drivers["anita lift"] = nil
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } }))
	w:advance(0.5)
	eq(#Mod.Pins(), 0, "no pins when no open driver matches this map")
	local why = Mod.Why()
	ok(type(why) == "string" and why:find("^Flight map prices: ") ~= nil, "Why starts with Flight map prices:")
	T.clean(w)
end)

test("v24 pins: none for my own beacon; none when flightOffers is false and Why mentions Settings", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar", screenW = 1365, screenH = 768 })
	T.goOnline(d, { price = 5000 })
	T.settle(w)
	addDriver(d, "anita lift", { name = "Anita Lift", dest = "Orgrimmar", price = 5000, state = "open" })

	local Mod = d.W.Mod("UI.FlightPins")
	w:openTaxiMap(d, H.realTaxi("Kalimdor", "Orgrimmar", { known = { "Crossroads", "Ratchet", "Camp Taurajo" } }))
	w:advance(0.5)
	eq(#Mod.Pins(), 0, "my own beacon gets no pin")
	eq(#d:findText("^50s$"), 0, "no price tag for my own beacon")

	-- another open driver exists, but flightOffers is off in Settings
	w:closeTaxiMap(d)
	addDriver(d, "bob stone", { name = "Bob Stone", dest = "Ratchet", price = 4500, state = "open" })
	d.W.db.flightOffers = false
	w:openTaxiMap(d, H.realTaxi("Kalimdor", "Orgrimmar", { known = { "Crossroads", "Ratchet", "Camp Taurajo" } }))
	w:advance(0.5)
	eq(#Mod.Pins(), 0, "setting off hides all pins")
	eq(#d:findText("^45s$"), 0, "no price tag when setting is off")
	local whyOff = Mod.Why()
	ok(type(whyOff) == "string" and whyOff:find("^Flight map prices: ") ~= nil, "Why starts with Flight map prices:")
	ok(whyOff:find("Settings", 1, true) ~= nil, "Why mentions Settings")

	-- turning the setting back on shows Bob's pin (and still not my own)
	d.W.db.flightOffers = true
	eq(Mod.Refresh(), 1, "Refresh shows one tag")
	eq(#Mod.Pins(), 1, "only Bob gets a pin")
	eq(Mod.Pins()[1].driver, "bob stone", "Bob is the pinned driver")
	ok(#d:findText("^45s$") > 0, "45s tag is shown")

	-- when TaxiFrame is not shown, no pins show and Why is nil
	w:closeTaxiMap(d)
	eq(#Mod.Pins(), 0, "no pins when map is closed")
	local whyMap = Mod.Why()
	eq(whyMap, nil, "Why is nil when no flight map is showing")
	T.clean(w)
end)

test("v24 pins: two open drivers to one place show one tag with the cheaper price", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	T.settle(w)
	addDriver(r, "bob stone", { name = "Bob Stone", dest = "Orgrimmar", price = 8000, state = "open", service = "Bob Express" })
	addDriver(r, "mia runner", { name = "Mia Runner", dest = "Orgrimmar", price = 4500, state = "open", service = "Mia's Rides" })

	local Mod = r.W.Mod("UI.FlightPins")
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } }))
	w:advance(0.5)

	local pins = Mod.Pins()
	eq(#pins, 1, "one pin for two drivers at the same place")
	eq(pins[1].driver, "mia runner", "cheaper driver wins")
	eq(pins[1].price, 4500, "cheaper price wins")
	ok(#r:findText("^45s$") > 0, "cheaper price tag is shown")
	eq(#r:findText("^80s$"), 0, "dearer price is not shown")
	T.clean(w)
end)

test("v24 pins: clicking the tag opens Wuber on that driver and keeps the flight map open", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	T.settle(w)
	addDriver(r, "bob stone", { name = "Bob Stone", dest = "Orgrimmar", price = 8000, state = "open" })
	addDriver(r, "mia runner", { name = "Mia Runner", dest = "Orgrimmar", price = 4500, state = "open", service = "Mia's Rides" })

	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } }))
	w:advance(0.5)

	r:clickText("45s")
	w:advance(0.5)

	eq(r.W.UI.state.confirmKey, "mia runner", "Confirm opened on the cheaper driver")
	ok(r.W.UI.state.win and H.visible(r.W.UI.state.win), "Wuber window opened")
	ok(#r:findText("Request") > 0, "Request button is visible on Confirm")
	ok(r.env.TaxiFrame:IsShown(), "flight map stays open")
	T.clean(w)
end)

test("v24 pins: geometry keeps tags clear of every flight button and mouse off holder and markers", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar", screenW = 1365, screenH = 768 })
	T.settle(w)
	addDriver(r, "d1", { name = "Driver One", dest = "Crossroads", price = 5000, state = "open" })
	addDriver(r, "d2", { name = "Driver Two", dest = "Ratchet", price = 5500, state = "open" })
	addDriver(r, "d3", { name = "Driver Three", dest = "Camp Taurajo", price = 6000, state = "open" })
	addDriver(r, "d4", { name = "Driver Four", dest = "Thunder Bluff", price = 6500, state = "open" })
	addDriver(r, "d5", { name = "Driver Five", dest = "Orgrimmar", price = 7000, state = "open" })

	local Mod = r.W.Mod("UI.FlightPins")
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Orgrimmar", { known = { "Crossroads", "Ratchet", "Camp Taurajo" } }))
	w:advance(0.5)

	local holder = r.env.WuberFlightPins
	ok(holder and H.visible(holder), "holder frame WuberFlightPins is visible")
	ok(not holder:IsMouseEnabled(), "holder has mouse off")
	-- run1 e: the holder sits one strata above the map, so a skin (Daylight UI) cannot cover the tags
	local above = { BACKGROUND = "LOW", LOW = "MEDIUM", MEDIUM = "HIGH", HIGH = "DIALOG", DIALOG = "FULLSCREEN", FULLSCREEN = "FULLSCREEN_DIALOG" }
	eq(holder:GetFrameStrata(), above[r.env.TaxiFrame:GetFrameStrata()] or r.env.TaxiFrame:GetFrameStrata(), "holder is one strata above TaxiFrame")

	local mr = H.rect(r.env.TaxiFrame)
	local btnRects = {}
	for i = 1, r.env.NumTaxiNodes() do
		local btn = r.env["TaxiButton" .. i]
		if btn and H.visible(btn) then
			btnRects[#btnRects + 1] = H.rect(btn)
		else
			local nx, ny = r.env.TaxiNodePosition(i)
			if nx and ny and not (nx == 0 and ny == 0) then
				local cx = mr.l + nx * mr.w
				local cy = (mr.b + mr.h) - ny * mr.h
				btnRects[#btnRects + 1] = { l = cx - 9, b = cy - 9, w = 18, h = 18 }
			end
		end
	end
	ok(#btnRects >= 21, "recorded flight buttons read")

	local pins = Mod.Pins()
	eq(#pins, 5, "all five open drivers get pins")
	local tagsCount = 0
	for _, p in ipairs(pins) do
		ok(p.marker and H.visible(p.marker), p.node .. ": marker visible")
		ok(not p.marker:IsMouseEnabled(), p.node .. ": marker has mouse off")
		if p.tag then
			tagsCount = tagsCount + 1
			ok(p.tag:IsMouseEnabled(), p.node .. ": tag has mouse on")
			local tr = H.rect(p.tag)
			for j, br in ipairs(btnRects) do
				ok(not overlaps(tr, br), p.node .. " tag does not overlap flight button " .. j)
			end
		end
	end
	ok(tagsCount >= 4, "tags placed cleanly beside points")
	T.clean(w)
end)

test("v24 pins: TAXIMAP_CLOSED hides pins and reopening reuses the same frames", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	T.settle(w)
	addDriver(r, "anita lift", { name = "Anita Lift", dest = "Orgrimmar", price = 5000, state = "open" })
	addDriver(r, "bob stone", { name = "Bob Stone", dest = "Ratchet", price = 6000, state = "open" })

	local Mod = r.W.Mod("UI.FlightPins")
	local nodes = H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } })
	w:openTaxiMap(r, nodes)
	w:advance(0.5)

	local holder1 = r.env.WuberFlightPins
	local pins1 = Mod.Pins()
	eq(#pins1, 2, "two pins shown on first open")
	local m1, t1 = pins1[1].marker, pins1[1].tag
	local m2, t2 = pins1[2].marker, pins1[2].tag

	w:closeTaxiMap(r)
	w:advance(0.2)
	eq(#Mod.Pins(), 0, "Pins() is empty after close")
	ok(not H.visible(holder1), "holder hidden on close")
	ok(not H.visible(m1) and not H.visible(t1), "first pin hidden on close")
	ok(not H.visible(m2) and not H.visible(t2), "second pin hidden on close")

	w:openTaxiMap(r, nodes)
	w:advance(0.5)
	local pins2 = Mod.Pins()
	eq(#pins2, 2, "two pins shown on second open")
	eq(r.env.WuberFlightPins, holder1, "holder reused")
	eq(pins2[1].marker, m1, "first marker reused")
	eq(pins2[1].tag, t1, "first tag reused")
	eq(pins2[2].marker, m2, "second marker reused")
	eq(pins2[2].tag, t2, "second tag reused")
	ok(H.visible(holder1) and H.visible(t1) and H.visible(t2), "reused pins visible again")
	T.clean(w)
end)

test("v24 pins: tooltip shows driver label, summon to place, price, about wait, and flight time when known", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	T.settle(w)
	addDriver(r, "mia runner", { name = "Mia Runner", dest = "Orgrimmar", price = 5000, state = "open", service = "Mia's Rides" })
	r.W.FlightTime = function() return 540, "est" end

	local Mod = r.W.Mod("UI.FlightPins")
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } }))
	w:advance(0.5)

	local pins = Mod.Pins()
	eq(#pins, 1, "one pin")
	ok(pins[1].tag, "tag shown")
	local tip = readTip(r, pins[1].tag)
	ok(tip:find("Mia's Rides", 1, true) ~= nil, "tooltip holds driver label")
	ok(tip:find("summon to Orgrimmar", 1, true) ~= nil, "tooltip holds summon to place")
	ok(tip:find("50s", 1, true) ~= nil, "tooltip holds price")
	ok(tip:find("· 30 sec · costing ", 1, true) ~= nil, "tooltip holds the wait, then costing and the price (decisions H)")
	ok(tip:find("Flying: about 9 min.", 1, true) ~= nil, "tooltip holds flight time when known")

	-- without a known flight time, the second sentence is omitted
	r.W.FlightTime = function() return nil end
	Mod.Refresh()
	local tipNoFly = readTip(r, Mod.Pins()[1].tag)
	ok(tipNoFly:find("Mia's Rides", 1, true) ~= nil, "tooltip still holds driver label")
	ok(tipNoFly:find("summon to Orgrimmar", 1, true) ~= nil, "tooltip still holds summon to place")
	ok(tipNoFly:find("50s", 1, true) ~= nil, "tooltip still holds price")
	ok(tipNoFly:find("· 30 sec · costing ", 1, true) ~= nil, "tooltip still holds the wait and costing (decisions H: no about beside the price)")
	eq(tipNoFly:find("Flying:", 1, true), nil, "no Flying sentence when flight time is unknown")
	T.clean(w)
end)

local function flightPointCentre(r, i, mr)
	local btn = r.env["TaxiButton" .. i]
	if btn and H.visible(btn) then
		local br = H.rect(btn)
		return br.l + br.w / 2, br.b + br.h / 2
	end
	local nx, ny = r.env.TaxiNodePosition(i)
	if nx and ny and not (nx == 0 and ny == 0) then
		return mr.l + nx * mr.w, (mr.b + mr.h) - ny * mr.h
	end
end

test("v24 pins: north is up: the marker of a northern flight point is drawn above a southern one's", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar", screenW = 1365, screenH = 768 })
	T.settle(w)
	addDriver(r, "d1", { name = "Driver One", dest = "Everlook", price = 5000, state = "open" })
	addDriver(r, "d2", { name = "Driver Two", dest = "Gadgetzan", price = 6000, state = "open" })

	local Mod = r.W.Mod("UI.FlightPins")
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Orgrimmar", { known = { "Everlook", "Gadgetzan" } }))
	w:advance(0.5)

	local mr = H.rect(r.env.TaxiFrame)
	local evFx, evFy, gaFx, gaFy
	for i = 1, r.env.NumTaxiNodes() do
		local name = r.env.TaxiNodeName(i)
		if name == "Everlook, Winterspring" then
			evFx, evFy = flightPointCentre(r, i, mr)
		elseif name == "Gadgetzan, Tanaris" then
			gaFx, gaFy = flightPointCentre(r, i, mr)
		end
	end
	ok(evFx and evFy, "Everlook flight point position read")
	ok(gaFx and gaFy, "Gadgetzan flight point position read")

	local pins = Mod.Pins()
	eq(#pins, 2, "two pins shown for Everlook and Gadgetzan")
	local evPin, gaPin
	for _, p in ipairs(pins) do
		if p.node == "Everlook, Winterspring" then evPin = p end
		if p.node == "Gadgetzan, Tanaris" then gaPin = p end
	end
	ok(evPin and evPin.marker and H.visible(evPin.marker), "Everlook marker visible")
	ok(gaPin and gaPin.marker and H.visible(gaPin.marker), "Gadgetzan marker visible")

	local evR = H.rect(evPin.marker)
	local gaR = H.rect(gaPin.marker)
	local evCx, evCy = evR.l + evR.w / 2, evR.b + evR.h / 2
	local gaCx, gaCy = gaR.l + gaR.w / 2, gaR.b + gaR.h / 2

	ok(evCy > gaCy, "Everlook marker centre is higher on screen than Gadgetzan's")
	ok(math.abs(evCx - evFx) <= 2 and math.abs(evCy - evFy) <= 2, "Everlook marker centre within 2px of flight point")
	ok(math.abs(gaCx - gaFx) <= 2 and math.abs(gaCy - gaFy) <= 2, "Gadgetzan marker centre within 2px of flight point")
	T.clean(w)
end)

test("v24 pins: the tag never takes a click meant for a flight point", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar", screenW = 1365, screenH = 768 })
	T.settle(w)
	addDriver(r, "d1", { name = "Driver One", dest = "Crossroads", price = 5000, state = "open" })
	addDriver(r, "d2", { name = "Driver Two", dest = "Ratchet", price = 5500, state = "open" })
	addDriver(r, "d3", { name = "Driver Three", dest = "Camp Taurajo", price = 6000, state = "open" })
	addDriver(r, "d4", { name = "Driver Four", dest = "Thunder Bluff", price = 6500, state = "open" })
	addDriver(r, "d5", { name = "Driver Five", dest = "Orgrimmar", price = 7000, state = "open" })

	local Mod = r.W.Mod("UI.FlightPins")
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Orgrimmar", { known = { "Crossroads", "Ratchet", "Camp Taurajo" } }))
	w:advance(0.5)

	local mr = H.rect(r.env.TaxiFrame)
	local centres = {}
	for i = 1, r.env.NumTaxiNodes() do
		local cx, cy = flightPointCentre(r, i, mr)
		if cx and cy then
			centres[#centres + 1] = { i = i, x = cx, y = cy }
		end
	end
	ok(#centres >= 21, "recorded flight point centres read")

	local sw = r.env.UIParent:GetWidth() or 1365
	local sh = r.env.UIParent:GetHeight() or 768
	local pins = Mod.Pins()
	eq(#pins, 5, "all five open drivers get pins")
	local tagsCount = 0
	for _, p in ipairs(pins) do
		if p.tag and H.visible(p.tag) then
			tagsCount = tagsCount + 1
			local tr = H.rect(p.tag)
			ok(tr.l >= 0 and tr.l + tr.w <= sw and tr.b >= 0 and tr.b + tr.h <= sh, p.node .. ": tag lies inside the screen")
			for _, pt in ipairs(centres) do
				local inside = pt.x >= tr.l and pt.x <= tr.l + tr.w and pt.y >= tr.b and pt.y <= tr.b + tr.h
				ok(not inside, p.node .. " tag does not cover centre of flight point " .. pt.i)
			end
		end
	end
	ok(tagsCount >= 4, "shown tags checked")
	T.clean(w)
end)

test("v24 pins: e3b-07 tags step aside from Wuber's window on open, move, fold, and close", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	T.settle(w)
	addDriver(r, "anita lift", { name = "Anita Lift", dest = "Orgrimmar", price = 5000, state = "open" })

	local Mod = r.W.Mod("UI.FlightPins")
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } }))
	w:advance(0.5)

	local pins1 = Mod.Pins()
	eq(#pins1, 1, "one pin shown")
	ok(pins1[1].tag and H.visible(pins1[1].tag), "tag initially visible")
	local tr1 = H.rect(pins1[1].tag)

	-- Open Wuber right over the tag's initial position (leaving left/above/below clear).
	r.W.UI.Toggle(true)
	w:advance(0.5)
	local win = r.W.UI.state.win
	local ph = r.W.UI.state.phone or win
	win:ClearAllPoints()
	win:SetPoint("LEFT", r.env.UIParent, "BOTTOMLEFT", tr1.l + 2, tr1.b + tr1.h / 2)
	w:advance(1.1)

	local pins2 = Mod.Pins()
	ok(pins2[1].tag and H.visible(pins2[1].tag), "tag still visible on a clear side")
	local tr2 = H.rect(pins2[1].tag)
	local pr2 = H.rect(ph)
	ok(not overlaps(tr2, pr2), "tag stepped clear of Wuber's window")

	-- Fold/unfold Wuber while open: tag stays clear of Wuber's window.
	if r.W.UI.Fold and r.W.UI.Fold.Toggle then
		r.W.UI.Fold.Toggle()
		w:advance(0.6)
		local pinsFold = Mod.Pins()
		if pinsFold[1].tag and H.visible(pinsFold[1].tag) then
			ok(not overlaps(H.rect(pinsFold[1].tag), H.rect(ph)), "tag stays clear of Wuber's window after fold toggle")
		end
	end

	-- Move Wuber to cover all 4 sides of the flight point: tag hides instead of overlapping.
	local mr = H.rect(pins2[1].marker)
	local mcx, mcy = mr.l + mr.w / 2, mr.b + mr.h / 2
	win:ClearAllPoints()
	win:SetPoint("CENTER", r.env.UIParent, "BOTTOMLEFT", mcx, mcy)
	w:advance(1.1)
	local pins3 = Mod.Pins()
	ok(not pins3[1].tag or not H.visible(pins3[1].tag), "tag hides when all 4 sides overlap Wuber's window")

	-- Close Wuber: tag returns.
	r.W.UI.Toggle(false)
	w:advance(0.5)
	local pins4 = Mod.Pins()
	ok(pins4[1].tag and H.visible(pins4[1].tag), "tag returns when Wuber closes")
	T.clean(w)
end)
