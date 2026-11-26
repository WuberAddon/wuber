-- bs2: Daylight UI (a skin that resizes TaxiFrame, a "Flying to" bar at the top) against the flight price tags
-- (UI.FlightPins, run 1 item 3) and the mid-flight card (UI.InFlight, run 1 item 4). The fake is tests/lib/fakes_daylight.lua.
local T = ...
local H, test, eq, ok, newWorld, rider, settle, clean = T.H, T.test, T.eq, T.ok, T.newWorld, T.rider, T.settle, T.clean
local Daylight = dofile(T.dir .. "/lib/fakes_daylight.lua")

local function rectOf(f)
	local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
	if not (l and r and t and b) then return nil end
	return { l = l, r = r, t = t, b = b }
end

local function overlaps(a, b)
	return a.l < b.r and b.l < a.r and a.b < b.t and b.b < a.t
end

local function addDriver(r, key, name, dest, price)
	r.W.drivers = r.W.drivers or {}
	r.W.drivers[key] = {
		name = name,
		key = key,
		dest = dest,
		price = price or 5000,
		state = "open",
		team = 3,
		service = name .. "'s Rides",
		heard = r.env.GetTime(),
	}
end

local function setTime(r, secs)
	r.W.db.flights = r.W.db.flights or {}
	r.W.db.flights["H|undercity|tarren mill"] = { t = secs, tat = r.env.time(), tsrc = "own" }
end

local UC_TM = {
	{ name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 },
	{ name = "Tarren Mill, Hillsbrad", type = "REACHABLE", cost = 330, x = 0.47, y = 0.44 },
}

-- Item 3a: FlightPins must stay aligned with Daylight-resized/moved TaxiFrame after open.
test("bs2 item03: flight price tag stays aligned with Daylight-resized TaxiFrame and shifted node", function()
	local w = newWorld()
	local r = rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	settle(w)
	addDriver(r, "anita lift", "Anita Lift", "Orgrimmar", 5000)

	-- Daylight resizes TaxiFrame after open (0.2s, after FlightPins' 0.1s refresh) and shifts it
	Daylight.attach(H, w, r, { taxiDelay = 0.2, moveTo = { 180, -80 }, flightTimer = false })

	local Mod = r.W.Mod("UI.FlightPins")
	local nodes = H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } })
	w:openTaxiMap(r, nodes)
	w:advance(0.5)

	local tf = r.env.TaxiFrame
	local tr = rectOf(tf)
	ok(tr ~= nil, "TaxiFrame has rect")
	eq(math.floor(tf:GetWidth()), 617, "TaxiFrame resized by Daylight")

	local pins = Mod.Pins()
	eq(#pins, 1, "one price pin shown")
	local holder = r.env.WuberFlightPins
	ok(holder and H.visible(holder), "WuberFlightPins holder is visible")
	eq(math.floor(holder:GetWidth() + 0.5), math.floor(tf:GetWidth() + 0.5), "WuberFlightPins width matches resized TaxiFrame")
	eq(math.floor(holder:GetHeight() + 0.5), math.floor(tf:GetHeight() + 0.5), "WuberFlightPins height matches resized TaxiFrame")

	local tag = pins[1].tag
	ok(tag and H.visible(tag), "price tag is visible")
	local tagRect = rectOf(tag)
	ok(tagRect ~= nil, "price tag has rect")
	ok(tagRect.l >= tr.l and tagRect.r <= tr.r and tagRect.b >= tr.b and tagRect.t <= tr.t,
		("tag (%d..%d, %d..%d) is inside resized TaxiFrame (%d..%d, %d..%d)"):format(
			tagRect.l, tagRect.r, tagRect.b, tagRect.t, tr.l, tr.r, tr.b, tr.t))

	-- Find Orgrimmar's TaxiButtonN and verify the tag is anchored near its shifted position
	local orgIdx
	for i, n in ipairs(nodes) do
		if n.name == "Orgrimmar, Durotar" then orgIdx = i break end
	end
	local btn = r.env["TaxiButton" .. orgIdx]
	local br = rectOf(btn)
	-- the tag sits beside its button (never over it): the gap between the two rects is small, and far smaller than
	-- the distance the button moved when Daylight shifted and grew the window (a tag left at the old place would be far off)
	local gx = math.max(br.l - tagRect.r, tagRect.l - br.r, 0)
	local gy = math.max(br.b - tagRect.t, tagRect.b - br.t, 0)
	ok(gx <= 25 and gy <= 25, ("tag stays beside the shifted TaxiButton%d (gap %.1f, %.1f)"):format(orgIdx, gx, gy))
	clean(w)
end)

-- Item 3b: FlightPins must still draw when TAXIMAP_OPENED is omitted (real-client recording).
test("bs2 item03: flight price tag appears when TaxiFrame opens without TAXIMAP_OPENED", function()
	local w = newWorld()
	local r = rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	settle(w)
	addDriver(r, "anita lift", "Anita Lift", "Orgrimmar", 5000)

	Daylight.attach(H, w, r, { omitTaximapOpened = true, taxiDelay = 0.2, flightTimer = false })

	local Mod = r.W.Mod("UI.FlightPins")
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } }))
	w:advance(0.5)

	local pins = Mod.Pins()
	eq(#pins, 1, "price pin drawn even without TAXIMAP_OPENED")
	ok(pins[1].tag and H.visible(pins[1].tag), "price tag is visible")
	clean(w)
end)

-- Item 4a: WuberInFlight must not overlap DaylightUIFlightTimer.
test("bs2 item04: WuberInFlight is clear of DaylightUIFlightTimer bar", function()
	local w = newWorld()
	local r = rider(w, T.TESTCHAR, { spot = "Undercity", screenW = 1365, screenH = 768 })
	settle(w)
	setTime(r, 240)
	addDriver(r, "mia runner", "Mia Runner", "Tarren Mill", 5000)

	Daylight.attach(H, w, r, { flightTimer = true, unitFrames = true })

	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 240, "Tarren Mill")
	w:advance(3)

	local c = r.env.WuberInFlight
	local ft = r.env.DaylightUIFlightTimer
	ok(c and H.visible(c), "WuberInFlight is visible")
	ok(ft and H.visible(ft), "DaylightUIFlightTimer is visible")

	local cr = rectOf(c)
	local fr = rectOf(ft)
	ok(not overlaps(cr, fr),
		("WuberInFlight (%d..%d, %d..%d) overlaps DaylightUIFlightTimer (%d..%d, %d..%d)"):format(
			cr.l, cr.r, cr.b, cr.t, fr.l, fr.r, fr.b, fr.t))
	w:advance(245)
	clean(w)
end)

-- Item 4b: WuberInFlight must be movable/draggable and remember its position.
test("bs2 item04: WuberInFlight is movable and saves dragged position", function()
	local w = newWorld()
	local r = rider(w, T.TESTCHAR, { spot = "Undercity", screenW = 1365, screenH = 768 })
	settle(w)
	setTime(r, 240)
	addDriver(r, "mia runner", "Mia Runner", "Tarren Mill", 5000)

	Daylight.attach(H, w, r, { flightTimer = true })

	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 240, "Tarren Mill")
	w:advance(3)

	local c = r.env.WuberInFlight
	ok(c and H.visible(c), "WuberInFlight is visible")
	eq(c:IsMovable(), true, "WuberInFlight is movable")
	eq(c:IsMouseEnabled(), true, "WuberInFlight is mouse-enabled")
	local onDragStart = c:GetScript("OnDragStart")
	local onDragStop = c:GetScript("OnDragStop")
	ok(type(onDragStart) == "function", "OnDragStart is wired")
	ok(type(onDragStop) == "function", "OnDragStop is wired")

	onDragStart(c)
	c:ClearAllPoints()
	c:SetPoint("TOPLEFT", r.env.UIParent, "TOPLEFT", 120, -260)
	onDragStop(c)
	ok(r.W.db.flightCardPos ~= nil, "flightCardPos saved after drag")

	w:advance(245)
	-- Second flight (from Undercity again, as the flight map says) restores the dragged position
	w:placePlayer(r.player, "Undercity")
	w:advance(1)
	addDriver(r, "mia runner", "Mia Runner", "Tarren Mill", 5000) -- (the first advert has gone stale by now)
	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 240, "Tarren Mill")
	w:advance(3)
	ok(H.visible(c), "WuberInFlight visible on second flight: " .. tostring(r.W.Mod("UI.InFlight").Why()))
	eq(math.floor(c:GetLeft() + 0.5), 120, "restored dragged x")
	w:advance(245)
	clean(w)
end)

