local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANA, CAL = "Ana Smith", "Cal Brown"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function crewSaved(me, crewList, captain)
	return { chars = { [key(me)] = { crew = crewList, captain = captain or "", wizard = true } } }
end

test("r33 l2 AUD-62: an offer nobody answered still says 'Waiting for X to tap Yes' long after it ran out", function()
	local w = H.NewWorld({})
	local ana = w:addClient(ANA, { spot = "Orgrimmar", class = "WARLOCK", saved = { Wuber = crewSaved(ANA, {}) } })
	local cal = w:addClient(CAL, { spot = "Orgrimmar", class = "WARLOCK" })
	w:group({ ANA, CAL })
	w:advance(5)
	local DR = ana.W.Drive
	ok(DR.apps[key(CAL)], "control: Ana knows Cal runs Wuber")
	ok(DR.OfferCrew(CAL), "offer sent")
	w:advance(2)
	eq(DR.offers[key(CAL)].state, "waiting", "control: waiting just after the offer")
	ok(cal.W.Drive.pendingOffers[key(ANA)], "control: Cal (a Warlock with Wuber) got the card and ignores it")
	w:advance(60) w:advance(60) w:advance(60) w:advance(60) w:advance(60) w:advance(60) -- 6 minutes: past the 5 minute life of an offer
	local o = DR.offers[key(CAL)]
	ok(not o or o.state ~= "waiting",
		"the offer is over 5 minutes old (a Yes would now be ignored) but the crew wizard still reads 'Waiting for Cal to tap Yes' (state=" .. tostring(o and o.state) .. ")")
	T.clean(w)
end)
