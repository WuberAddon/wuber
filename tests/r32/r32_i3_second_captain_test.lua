local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANA, BEA, CAL = "Ana Smith", "Bea Jones", "Cal Brown"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function crewSaved(me, crewList, captain)
	return { chars = { [key(me)] = { crew = crewList, captain = captain or "", wizard = true } } }
end

test("r32 i3: a helper who joins a second captain's crew is still listed in the first captain's crew", function()
	local w = H.NewWorld({})
	local ana = w:addClient(ANA, { spot = "Orgrimmar", class = "WARLOCK", saved = { Wuber = crewSaved(ANA, { { name = CAL, role = "helper", app = true } }) } })
	local bea = w:addClient(BEA, { spot = "Undercity", class = "WARLOCK", saved = { Wuber = crewSaved(BEA, {}) } })
	local cal = w:addClient(CAL, { spot = "Orgrimmar", class = "MAGE", saved = { Wuber = crewSaved(CAL, {}, ANA) } })
	w:group({ ANA, CAL })
	w:advance(5)
	eq(cal.W.Drive.CaptainKey(), key(ANA), "control: Cal is in Ana's crew")
	ok(ana.W.Drive.CrewEntry(key(CAL)), "control: Ana lists Cal")
	ok(bea.W.Drive.OfferCrew(CAL), "Bea offers Cal a place in her crew")
	w:advance(2)
	ok(cal.W.Drive.pendingOffers[key(BEA)], "control: Cal has Bea's offer card")
	cal.W.Drive.AnswerOffer(BEA, true)
	w:advance(5)
	eq(cal.W.Drive.CaptainKey(), key(BEA), "control: Cal is now in Bea's crew")
	ok(bea.W.Drive.CrewEntry(key(CAL)), "control: Bea lists Cal")
	ok(not ana.W.Drive.CrewEntry(key(CAL)),
		"Cal moved to Bea's crew but Ana still lists him as her crew member (Cal never whispered 'TL' to Ana), so Ana's crew list and facts still count him")
	T.clean(w)
end)