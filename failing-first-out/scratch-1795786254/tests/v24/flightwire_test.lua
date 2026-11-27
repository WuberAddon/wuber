-- Wuber 2.4, part 6: wiring FlightPins, InFlight, /wuber why and Settings Flight offers. Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local UC_TM = {
	{ name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 },
	{ name = "Tarren Mill, Hillsbrad", type = "REACHABLE", cost = 330, x = 0.47, y = 0.44 },
	{ name = "Hammerfall, Arathi", type = "REACHABLE", cost = 530 },
	{ name = "Kalimdor's Nowhere, Somewhere", type = "REACHABLE", cost = 100 },
}

local function addDriver(c, key, name, dest, price)
	c.W.drivers = c.W.drivers or {}
	c.W.drivers[key] = {
		name = name,
		key = key,
		dest = dest,
		price = price or 5000,
		state = "open",
		team = 3,
		service = name .. "'s Rides",
		heard = c.env.GetTime(),
	}
end

local function runWhy(c)
	local from = #c.chatLines + 1
	c:slash("/wuber why")
	local lines = {}
	for i = from, #c.chatLines do
		lines[#lines + 1] = c.chatLines[i]
	end
	return lines
end

local function findLine(lines, prefix)
	for _, ln in ipairs(lines) do
		if ln:find(prefix, 1, true) then return ln end
	end
	return nil
end

local function findRowByLabel(st, label)
	for key, ctl in pairs(st.controls or {}) do
		local row = type(ctl) == "table" and (ctl.row or (ctl.GetParent and ctl:GetParent()))
		if row and row.label and row.label:GetText() == label then
			return ctl, row, key
		end
	end
end

test("v24 flightwire: /wuber why prints Flight map prices only in its three cases and is quiet when nothing is hidden", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	T.settle(w)

	-- nothing hidden: neither Flight map prices nor Mid-flight offer appears
	local lines = runWhy(r)
	eq(findLine(lines, "Flight map prices:"), nil, "quiet when no flight map is open")
	eq(findLine(lines, "Mid-flight offer:"), nil, "quiet when not flying")

	-- TaxiFrame open without pins
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } }))
	w:advance(0.5)
	lines = runWhy(r)
	local ln = findLine(lines, "Flight map prices:")
	ok(ln and ln:find("Flight map prices: no open driver summons to a place on this flight map.", 1, true) ~= nil, "why explains missing pins on TaxiFrame")
	eq(findLine(lines, "Mid-flight offer:"), nil, "still quiet for Mid-flight offer")

	-- TaxiFrame open with pins
	w:closeTaxiMap(r)
	addDriver(r, "anita lift", "Anita Lift", "Orgrimmar", 5000)
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } }))
	w:advance(0.5)
	lines = runWhy(r)
	eq(findLine(lines, "Flight map prices:"), nil, "quiet while pins show on TaxiFrame")
	eq(findLine(lines, "Mid-flight offer:"), nil, "still quiet for Mid-flight offer")

	-- FlightMapFrame open (not TaxiFrame)
	w:closeTaxiMap(r)
	local fm = r.env.CreateFrame("Frame", "FlightMapFrame", r.env.UIParent)
	fm:SetSize(400, 300)
	fm:SetPoint("CENTER")
	fm:Show()
	w:advance(0.2)
	lines = runWhy(r)
	ln = findLine(lines, "Flight map prices:")
	ok(ln and ln:find("Flight map prices: this flight map is not one Wuber knows.", 1, true) ~= nil, "why explains unknown flight map")
	eq(findLine(lines, "Mid-flight offer:"), nil, "still quiet for Mid-flight offer")
	fm:Hide()
	r.env.FlightMapFrame = nil

	-- Settings off (even with no flight map open)
	r.W.db.flightOffers = false
	lines = runWhy(r)
	ln = findLine(lines, "Flight map prices:")
	ok(ln and ln:find("Flight map prices: off in Settings (Riding, Flight offers).", 1, true) ~= nil, "why reports Flight map prices off in Settings")
	ln = findLine(lines, "Mid-flight offer:")
	ok(ln and ln:find("Mid-flight offer: off in Settings (Riding, Flight offers).", 1, true) ~= nil, "why reports Mid-flight offer off in Settings")

	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)

test("v24 flightwire: /wuber why prints Mid-flight offer only when off in Settings or blocked while flying", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Undercity", screenW = 1365, screenH = 768 })
	T.settle(w)
	r.W.db.flights = r.W.db.flights or {}
	r.W.db.flights["H|undercity|tarren mill"] = { t = 240, tat = r.env.time(), tsrc = "own" }
	addDriver(r, "mia runner", "Mia Runner", "Tarren Mill", 5000)

	-- not flying, midFlight false: prints Mid-flight offer only
	r.W.db.midFlight = false
	local lines = runWhy(r)
	local ln = findLine(lines, "Mid-flight offer:")
	ok(ln and ln:find("Mid-flight offer: off in Settings (Riding, Flight offers).", 1, true) ~= nil, "why reports midFlight off in Settings")
	eq(findLine(lines, "Flight map prices:"), nil, "Flight map prices stays quiet when flightOffers is on")
	r.W.db.midFlight = nil

	-- flying with card visible: quiet
	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 240, "Tarren Mill")
	w:advance(3)
	local card = r.W.Mod("UI.InFlight").Card()
	ok(card and H.visible(card), "mid-flight card is visible")
	lines = runWhy(r)
	eq(findLine(lines, "Mid-flight offer:"), nil, "quiet while mid-flight card is showing")

	-- closed with x during flight: reports why
	r:clickOn(card.x)
	w:advance(1)
	lines = runWhy(r)
	ln = findLine(lines, "Mid-flight offer:")
	ok(ln and ln:find("Mid-flight offer: already shown on this flight.", 1, true) ~= nil, "why explains mid-flight card hidden for this flight")

	-- after landing: quiet again
	w:advance(245)
	lines = runWhy(r)
	eq(findLine(lines, "Mid-flight offer:"), nil, "quiet again after landing")

	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)

test("v24 flightwire: Settings Flight offers row toggles flightOffers, hides pins on refresh, and clears midFlight", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	T.settle(w)
	addDriver(r, "anita lift", "Anita Lift", "Orgrimmar", 5000)

	local PinsMod = r.W.Mod("UI.FlightPins")
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = { "Orgrimmar" } }))
	w:advance(0.5)
	eq(#PinsMod.Pins(), 1, "one pin shown before toggling setting off")
	local tag1 = PinsMod.Pins()[1] and PinsMod.Pins()[1].tag
	ok(tag1 and H.visible(tag1), "50s price tag visible")

	r.W.db.coach = true
	r.W.UI.Toggle(true)
	w:advance(3)
	r.W.UI.OpenSettings("riding")
	w:advance(1)

	local ctl, row, key = findRowByLabel(r.W.UI.settings, "Flight offers")
	ok(ctl and row, "Flight offers row exists in Settings > Riding")
	eq(key, "flightOffers", "row control key is flightOffers")
	eq(ctl.on, true, "Flight offers starts on")
	eq(row.desc:GetText(), "A summon that beats flying: beside the flight map, on it, and while you fly.", "row short line matches")
	local tipBody = row.wuberTip and (type(row.wuberTip.text) == "function" and row.wuberTip.text(row) or row.wuberTip.text) or ""
	ok(tipBody:find("Shows a faster summon at a flight master's map, and once mid-flight. Never in combat or during a ride. Off: no cards.", 1, true), "row tooltip says where it shows and ends with the Off line (the 20 rewrites, W-2): " .. tipBody)

	-- toggle off: saves flightOffers = false and hides shown pins on next refresh
	r:click(ctl)
	w:advance(0.5)
	eq(r.W.db.flightOffers, false, "toggling off saves flightOffers = false")
	eq(ctl.on, false, "toggle knob is off")
	eq(PinsMod.Refresh(), 0, "Refresh hides pins when flightOffers is false")
	eq(#PinsMod.Pins(), 0, "no pins remain after refresh")
	ok(not H.visible(tag1), "price tag hidden after refresh")
	ok(not H.visible(r.env.WuberFlightPins), "pin holder hidden after refresh")

	-- toggle back on: saves flightOffers = true and clears midFlight
	r.W.db.midFlight = false
	r:click(ctl)
	w:advance(0.5)
	eq(r.W.db.flightOffers, true, "toggling on saves flightOffers = true")
	eq(r.W.db.midFlight, nil, "toggling on clears midFlight")
	eq(ctl.on, true, "toggle knob is on")
	eq(PinsMod.Refresh(), 1, "Refresh shows pin again when flightOffers is on")
	eq(#PinsMod.Pins(), 1, "pin returns after refresh")
	ok(PinsMod.Pins()[1] and H.visible(PinsMod.Pins()[1].tag), "50s price tag visible again")

	-- sync8 keeps the toggle aligned with saved value
	r.W.db.flightOffers = false
	r.W.UI.UpdateSettings()
	eq(ctl.on, false, "UpdateSettings syncs toggle to flightOffers = false")

	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)
