local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANA, BEA, CAL = "Ana Smith", "Bea Jones", "Cal Brown"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function crewSaved(me, crewList, captain)
	return { chars = { [key(me)] = { crew = crewList, captain = captain or "", wizard = true } } }
end

test("r32 i: after the captain removes a Warlock, the other crew windows still add her shards", function()
	local w = H.NewWorld({})
	local ana = w:addClient(ANA, { spot = "Orgrimmar", class = "WARLOCK", saved = { Wuber = crewSaved(ANA, {
		{ name = BEA, role = "lock", app = true }, { name = CAL, role = "lock", app = true } }) } })
	local bea = w:addClient(BEA, { spot = "Orgrimmar", class = "WARLOCK", shards = 7, saved = { Wuber = crewSaved(BEA, {
		{ name = CAL, role = "lock", app = true } }, ANA) } })
	local cal = w:addClient(CAL, { spot = "Orgrimmar", class = "WARLOCK", shards = 3, saved = { Wuber = crewSaved(CAL, {
		{ name = BEA, role = "lock", app = true } }, ANA) } })
	w:group({ ANA, BEA, CAL })
	w:advance(10)
	local _, line0 = cal.W.Drive.TeamShards()
	ok(line0:find("Bea", 1, true), "control: Cal's crew shard line lists Bea: " .. line0)
	ok(ana.W.Drive.RemoveCrew(BEA), "Ana removes Bea from the crew (Bea stays in the party)")
	w:advance(10)
	ok(not cal.W.Drive.IsCrewKey(key(BEA)), "control: Cal's crew list no longer holds Bea")
	local _, line1 = cal.W.Drive.TeamShards()
	ok(not line1:find("Bea", 1, true), "Bea is out of the crew but Cal's crew shard line still reads: " .. line1)
	T.clean(w)
end)
