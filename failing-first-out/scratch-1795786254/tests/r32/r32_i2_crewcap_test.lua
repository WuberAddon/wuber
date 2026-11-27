local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANA, GUS, HAL, BEA = "Ana Smith", "Gus Hill", "Hal Young", "Bea Jones"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function crewSaved(me, crewList, captain)
	return { chars = { [key(me)] = { crew = crewList, captain = captain or "", wizard = true } } }
end
local function wubert(w, kind, to)
	local out = {}
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBERT" and e.result == 0 and e.text:match("^([^~]*)") == kind and e.target and key(e.target) == key(to) then
			out[#out + 1] = e
		end
	end
	return out
end

test("r32 i2: the captain's 8th crew member reaches the other members' crew lists", function()
	local w = H.NewWorld({})
	local list = { { name = GUS, role = "helper", app = true } }
	for i = 2, 7 do list[#list + 1] = { name = "Helper" .. string.char(64 + i) .. " Brown", role = "helper", app = false } end
	list[#list + 1] = { name = HAL, role = "helper", app = true }
	local ana = w:addClient(ANA, { spot = "Orgrimmar", class = "WARLOCK", saved = { Wuber = crewSaved(ANA, list) } })
	local gus = w:addClient(GUS, { spot = "Orgrimmar", class = "MAGE", saved = { Wuber = crewSaved(GUS, {}, ANA) } })
	local hal = w:addClient(HAL, { spot = "Orgrimmar", class = "PRIEST", saved = { Wuber = crewSaved(HAL, {}, ANA) } })
	w:group({ ANA, GUS, HAL })
	w:advance(3)
	eq(#ana.W.Drive.char().crew, 8, "control: the captain holds 8 crew members")
	ana.W.Drive.SendCrew()
	w:advance(3)
	ok(gus.W.Drive.IsCrewKey(key("HelperG Brown")), "control: the 7th member reached Gus's window")
	ok(gus.W.Drive.IsCrewKey(key(HAL)), "Hal, the 8th member, is in Gus's crew window")
	-- worst case: captain plus 8 names of 48 characters, one CRW message
	local long = {}
	for i = 1, 8 do long[#long + 1] = { name = string.rep(string.char(64 + i), 47) .. "x", role = "helper", app = false } end
	ana.W.Drive.char().crew = long
	ana.W.Drive.SendCrew()
	w:advance(3)
	local worst = 0
	for _, e in ipairs(w.addonLog) do
		if e.text and e.text:match("^CRW") and #e.text > worst then worst = #e.text end
	end
	ok(worst > 0 and worst <= 250, "the longest CRW message is " .. worst .. " bytes (limit 250)")
	T.clean(w)
end)

test("r32 i2: a player who says Yes out of the group is whispered the crew list once", function()
	local w = H.NewWorld({})
	local ana = w:addClient(ANA, { spot = "Orgrimmar", class = "WARLOCK", saved = { Wuber = crewSaved(ANA, {}) } })
	local bea = w:addClient(BEA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(5)
	ok(ana.W.Drive.OfferCrew(BEA), "offer sent")
	w:advance(2)
	bea.W.Drive.AnswerOffer(ANA, true)
	w:advance(5)
	ok(ana.W.Drive.CrewEntry(key(BEA)), "control: Bea joined Ana's crew")
	eq(#wubert(w, "CRW", BEA), 1, "Bea is whispered the crew list exactly once")
	T.clean(w)
end)

test("r32 i2: a 9th player who says Yes to a full crew is not left thinking she joined", function()
	local w = H.NewWorld({})
	local list = {}
	for i = 1, 8 do list[#list + 1] = { name = "Helper" .. string.char(64 + i) .. " Brown", role = "helper", app = false } end
	local ana = w:addClient(ANA, { spot = "Orgrimmar", class = "WARLOCK", saved = { Wuber = crewSaved(ANA, list) } })
	local bea = w:addClient(BEA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(5)
	ana.W.Drive.OfferCrew(BEA)
	w:advance(2)
	bea.W.Drive.AnswerOffer(ANA, true)
	w:advance(5)
	eq(#ana.W.Drive.char().crew, 8, "Ana's crew stays at 8")
	ok(ana.W.Drive.CrewEntry(key(BEA)) == nil, "Bea is not in Ana's list")
	ok(ana.W.Drive.offers[key(BEA)].state ~= "yes", "her answer is not marked yes")
	ok(bea.W.Drive.CaptainKey() ~= key(ANA), "Bea's window no longer says she is in Ana's crew")
	T.clean(w)
end)
