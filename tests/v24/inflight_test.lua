-- Wuber 2.4, part 6: mid-flight summon offer, W.OnTaxi, W.FlightLeft and dropping summoned flights. Loaded by tests/run.lua with its helper table T.
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

local function setDriver(r, key, name, dest, price)
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

local function setupRider(secs)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Undercity", screenW = 1365, screenH = 768 })
	T.settle(w)
	if secs then setTime(r, secs) end
	return w, r
end

test("v24 inflight: W.OnTaxi follows the taxi and W.FlightLeft counts down on a known route, nil otherwise", function()
	local w, r = setupRider(200)
	local W = r.W
	eq(W.OnTaxi(), false, "not on taxi before flight")
	eq(W.FlightLeft(), nil, "no flight: FlightLeft is nil")

	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 200, "Tarren Mill")
	w:advance(11)
	eq(W.OnTaxi(), true, "on taxi during flight")
	local left1, dest1 = W.FlightLeft()
	ok(left1 and left1 >= 185 and left1 <= 195, "about 190 s left: " .. tostring(left1))
	eq(dest1, "Tarren Mill", "destination name returned as second value")

	w:advance(30)
	local left2, dest2 = W.FlightLeft()
	ok(left2 and left2 < left1 - 25 and left2 >= 155, "counted down by 30 s: " .. tostring(left2))
	eq(dest2, "Tarren Mill", "destination stays Tarren Mill")

	w:advance(170)
	eq(W.OnTaxi(), false, "off taxi after landing")
	eq(W.FlightLeft(), nil, "nil after landing")

	-- unknown route: FlightLeft is nil while OnTaxi is true
	w:openTaxiMap(r, UC_TM)
	w:fly(r, 4, 150, "Tarren Mill")
	w:advance(10)
	eq(W.OnTaxi(), true, "on taxi on unknown route")
	eq(W.FlightLeft(), nil, "unknown route: FlightLeft is nil")
	w:advance(150)
	eq(W.OnTaxi(), false, "off taxi after unknown route")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)

test("v24 inflight: summon offered mid-flight records no flight time; a normal flight still records", function()
	local w, r = setupRider()
	local W = r.W

	-- fast flight with a summon offered mid-flight: nothing saved
	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 40, "Tarren Mill")
	w:advance(15)
	r:fire("CONFIRM_SUMMON")
	w:advance(30)
	local entry = W.db.flights and W.db.flights["H|undercity|tarren mill"]
	eq(entry and entry.t, nil, "no time recorded when summon offered mid-flight")

	-- normal flight records its real time
	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 180, "Tarren Mill")
	w:advance(185)
	entry = W.db.flights and W.db.flights["H|undercity|tarren mill"]
	eq(entry and entry.t, 180, "normal flight records 180 s")

	-- another mid-flight summon leaves the saved time unchanged
	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 30, "Tarren Mill")
	w:advance(10)
	r:fire("CONFIRM_SUMMON")
	w:advance(25)
	entry = W.db.flights and W.db.flights["H|undercity|tarren mill"]
	eq(entry and entry.t, 180, "saved flight time unchanged after mid-flight summon")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)

test("v24 inflight: card shows once with >90 s left and an open driver, showing place and world-map sentence", function()
	local w, r = setupRider(240)
	local W = r.W
	local Mod = W.Mod("UI.InFlight")
	setDriver(r, "mia runner", "Mia Runner", "Tarren Mill", 5000)

	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 240, "Tarren Mill")
	w:advance(3)

	local c = r.env.WuberInFlight
	ok(c and H.visible(c), "WuberInFlight card is visible")
	eq(Mod.Card(), c, "Mod.Card returns the frame")
	eq(Mod.Driver(), "mia runner", "Mod.Driver returns the offered driver key")
	eq(Mod.Why(), nil, "Why is nil while the card shows")
	eq(c:GetFrameStrata(), "HIGH", "card strata is HIGH")
	ok(#r:findText("About %d+ min left%. A summon takes about %d+ sec%.") > 0, "line 1 shown with real numbers")
	ok(#r:findText("The summon is at Tarren Mill: check your world map to see it.", false, true) > 0, "line 2 exact text shown")
	ok(#r:findText("Book · 50s", false, true) > 0, "Book button with price shown")
	ok(#r:findText("Don't show", false, true) > 0, "Don't show button shown")
	eq(Mod.Check(), false, "Check returns false while already shown")

	w:advance(245)
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)

test("v24 inflight: blocked under 90 s, in combat, on a ride, settings off, or own beacon, each with Why()", function()
	local w, r = setupRider(80)
	local W = r.W
	local Mod = W.Mod("UI.InFlight")
	setDriver(r, "mia runner", "Mia Runner", "Tarren Mill", 5000)

	-- under 90 s
	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 80, "Tarren Mill")
	w:advance(3)
	ok(not (Mod.Card() and H.visible(Mod.Card())), "hidden under 90 s")
	local why = Mod.Why()
	ok(why and why:find("^Mid%-flight offer: ") and why:find("90"), "Why under 90 s: " .. tostring(why))
	w:advance(85)

	-- in combat
	setTime(r, 240)
	setDriver(r, "mia runner", "Mia Runner", "Tarren Mill", 5000)
	w:enterCombat(r)
	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 240, "Tarren Mill")
	w:advance(3)
	ok(not (Mod.Card() and H.visible(Mod.Card())), "hidden in combat")
	why = Mod.Why()
	ok(why and why:find("^Mid%-flight offer: ") and why:find("combat"), "Why combat: " .. tostring(why))
	w:advance(245)
	w:leaveCombat(r)

	-- on a ride
	setDriver(r, "mia runner", "Mia Runner", "Tarren Mill", 5000)
	W.ride = { id = "r1", driver = "Bea Jones", driverKey = "bea jones", dest = "Undercity", price = 5000, state = "accepted", at = r.env.GetTime() }
	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 240, "Tarren Mill")
	w:advance(3)
	ok(not (Mod.Card() and H.visible(Mod.Card())), "hidden on a ride")
	why = Mod.Why()
	ok(why and why:find("^Mid%-flight offer: ") and why:find("ride"), "Why ride: " .. tostring(why))
	w:advance(245)
	W.ride = nil

	-- W.db.flightOffers = false
	setDriver(r, "mia runner", "Mia Runner", "Tarren Mill", 5000)
	W.db.flightOffers = false
	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 240, "Tarren Mill")
	w:advance(3)
	ok(not (Mod.Card() and H.visible(Mod.Card())), "hidden when flightOffers is false")
	why = Mod.Why()
	ok(why and why:find("^Mid%-flight offer: ") and why:find("Settings"), "Why flightOffers off: " .. tostring(why))
	w:advance(245)
	W.db.flightOffers = nil

	-- W.db.midFlight = false
	setDriver(r, "mia runner", "Mia Runner", "Tarren Mill", 5000)
	W.db.midFlight = false
	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 240, "Tarren Mill")
	w:advance(3)
	ok(not (Mod.Card() and H.visible(Mod.Card())), "hidden when midFlight is false")
	why = Mod.Why()
	ok(why and why:find("^Mid%-flight offer: ") and why:find("Settings"), "Why midFlight off: " .. tostring(why))
	w:advance(245)
	W.db.midFlight = nil

	-- own beacon only
	W.drivers = {}
	setDriver(r, W.Key(r.player.name), r.player.name, "Tarren Mill", 5000)
	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 240, "Tarren Mill")
	w:advance(3)
	ok(not (Mod.Card() and H.visible(Mod.Card())), "hidden for my own beacon")
	why = Mod.Why()
	ok(why and why:find("^Mid%-flight offer: ") and why:find("no open driver"), "Why own beacon: " .. tostring(why))
	w:advance(245)

	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)

test("v24 inflight: x hides for this flight only, landing hides it, and a new flight shows it again", function()
	local w, r = setupRider(240)
	local W = r.W
	local Mod = W.Mod("UI.InFlight")
	setDriver(r, "mia runner", "Mia Runner", "Tarren Mill", 5000)

	-- flight 1: close with x, stays hidden for the rest of the flight
	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 240, "Tarren Mill")
	w:advance(3)
	local c = Mod.Card()
	ok(c and H.visible(c), "shown on flight 1")
	r:clickOn(c.x)
	w:advance(3)
	ok(not H.visible(c), "x hides the card")
	eq(Mod.Driver(), nil, "Driver is nil after close")
	eq(Mod.Check(), false, "does not come back on same flight")
	local why = Mod.Why()
	ok(why and why:find("^Mid%-flight offer: ") and why:find("already shown"), "Why says already shown: " .. tostring(why))
	w:advance(245)

	-- flight 2: shows again, then hides on landing
	setDriver(r, "mia runner", "Mia Runner", "Tarren Mill", 5000)
	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 240, "Tarren Mill")
	w:advance(3)
	ok(H.visible(c), "shown again on flight 2")
	w:advance(245)
	ok(not H.visible(c), "hidden on landing")
	eq(Mod.Driver(), nil, "Driver is nil after landing")
	eq(Mod.Why(), nil, "Why is nil when not flying")

	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)

test("v24 inflight: Don't show saves midFlight = false, shows exact toast, and next flight shows nothing", function()
	local w, r = setupRider(240)
	local W = r.W
	local Mod = W.Mod("UI.InFlight")
	setDriver(r, "mia runner", "Mia Runner", "Tarren Mill", 5000)

	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 240, "Tarren Mill")
	w:advance(3)
	ok(Mod.Card() and H.visible(Mod.Card()), "card visible")
	r:clickText("Don't show")
	w:advance(0.5)

	eq(W.db.midFlight, false, "W.db.midFlight saved as false")
	ok(not H.visible(Mod.Card()), "card hidden after Don't show")
	ok(#r:findText("No more offers while you fly. To get them back, turn Flight offers off and on in Settings (Riding).", false, true) > 0, "exact toast text appears")
	w:advance(245)

	-- next flight shows nothing
	setDriver(r, "mia runner", "Mia Runner", "Tarren Mill", 5000)
	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 240, "Tarren Mill")
	w:advance(3)
	ok(not H.visible(Mod.Card()), "next flight shows nothing")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)

test("v24 inflight: Book opens Wuber on that driver, hides card, and requests nothing by itself", function()
	local w, r = setupRider(240)
	local W = r.W
	local Mod = W.Mod("UI.InFlight")
	setDriver(r, "mia runner", "Mia Runner", "Tarren Mill", 5000)

	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 240, "Tarren Mill")
	w:advance(3)
	ok(Mod.Card() and H.visible(Mod.Card()), "card visible")

	r:clickText("Book · 50s")
	w:advance(0.5)

	ok(not H.visible(Mod.Card()), "card hidden after Book")
	ok(W.UI.state.win and H.visible(W.UI.state.win), "Wuber window opened")
	eq(W.UI.state.confirmKey, "mia runner", "Confirm opened for Mia")
	ok(#r:findText("Request") > 0, "Request button visible for player to click")
	eq(W.ride, nil, "no ride started automatically")
	eq(#w:messages("R"), 0, "no R message sent")
	eq(#w.whispers, 0, "no whisper sent")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)

local function rectsCross(a, b)
	return not (a.l + a.w <= b.l or b.l + b.w <= a.l or a.b + a.h <= b.b or b.b + b.h <= a.b)
end

test("v24 inflight: the card never overlaps Wuber's own window", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Undercity", screenW = 2662, screenH = 2089 })
	T.settle(w)
	local W = r.W
	local longPlace = "Revantusk Village, The Hinterlands"
	local nodePlace = "Revantusk Village"
	W.db.flights = W.db.flights or {}
	local norm = (W.NormPlace and W.NormPlace(nodePlace)) or nodePlace:lower()
	W.db.flights["H|undercity|" .. norm] = { t = 720, tat = r.env.time(), tsrc = "own" }
	local Mod = W.Mod("UI.InFlight")
	setDriver(r, "mia runner", "Mia Runner", longPlace, 1234567)

	W.UI.Toggle(true)
	w:advance(0.2)
	local wf = r.env.WuberFrame
	ok(wf and H.visible(wf), "WuberFrame is open before the card shows")

	local longTaxi = {
		{ name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 },
		{ name = longPlace, type = "REACHABLE", cost = 500, x = 0.72, y = 0.36 },
	}
	w:openTaxiMap(r, longTaxi)
	w:fly(r, 2, 720, nodePlace)
	for _ = 1, 20 do
		if Mod.Card() and H.visible(Mod.Card()) then break end
		w:advance(0.1)
	end

	local c = Mod.Card()
	ok(c and H.visible(c), "card is visible while WuberFrame is open")
	ok(#r:findText("Book · 123g 45s 67c", false, true) > 0, "long price button shown")
	ok(#r:findText(longPlace, false, true) > 0, "long place name shown")
	local sw = r.env.UIParent:GetWidth() or 2662
	local sh = r.env.UIParent:GetHeight() or 2089
	local cr1 = H.rect(c)
	local wr1 = H.rect(wf)
	ok(not rectsCross(cr1, wr1), "card and WuberFrame rectangles do not cross right after show")
	ok(cr1.l >= 0 and cr1.l + cr1.w <= sw and cr1.b >= 0 and cr1.b + cr1.h <= sh, "card is fully on screen right after show")

	W.UI.Toggle(false)
	w:advance(2)
	ok(H.visible(c) and not H.visible(wf), "card stays visible when WuberFrame closes")
	local cr2 = H.rect(c)
	ok(cr2.l >= 0 and cr2.l + cr2.w <= sw and cr2.b >= 0 and cr2.b + cr2.h <= sh, "card is fully on screen after close")

	W.UI.Toggle(true)
	w:advance(2)
	ok(H.visible(c) and H.visible(wf), "card and WuberFrame visible after reopen")
	local cr3 = H.rect(c)
	local wr3 = H.rect(wf)
	ok(not rectsCross(cr3, wr3), "card and WuberFrame rectangles do not cross after reopen")
	ok(cr3.l >= 0 and cr3.l + cr3.w <= sw and cr3.b >= 0 and cr3.b + cr3.h <= sh, "card is fully on screen after reopen")

	eq(#w.errors, 0, table.concat(w.errors, "\n")) -- (lead) the fake game cannot land at this flight point: the test ends in the air
	T.clean(w)
end)
