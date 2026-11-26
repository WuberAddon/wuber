local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANA, BEA, CAL = "Ana Smith", "Bea Jones", "Cal Brown"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function crewSaved(me, crewList, captain)
	return { chars = { [key(me)] = { crew = crewList, captain = captain or "", wizard = true } } }
end
local function build()
	local w = H.NewWorld({})
	local ana = w:addClient(ANA, { spot = "Orgrimmar", class = "WARLOCK", saved = { Wuber = crewSaved(ANA, {
		{ name = BEA, role = "lock", app = true }, { name = CAL, role = "helper", app = true } }) } })
	local bea = w:addClient(BEA, { spot = "Orgrimmar", class = "WARLOCK", saved = { Wuber = crewSaved(BEA, {
		{ name = CAL, role = "helper", app = true } }, ANA) } })
	local cal = w:addClient(CAL, { spot = "Orgrimmar", class = "MAGE", saved = { Wuber = crewSaved(CAL, {
		{ name = BEA, role = "lock", app = true } }, ANA) } })
	w:group({ CAL, ANA, BEA }) -- the Mage helper leads, not the captain
	w:advance(3)
	return w, ana, bea, cal
end

test("r32 i: a helper who leads after the captain left does not close the crew Warlock", function()
	local w, ana, bea, cal = build()
	ok(ana.W.Drive.SetOpen(true), "captain opens")
	w:advance(5)
	eq(bea.W.Drive.IsOpen(), true, "control: Bea's window follows the captain and is open")
	eq(cal.W.Drive.IsLeader(), true, "Cal (helper) leads")
	w:leave(ANA) -- the captain leaves the group (reload, relog, or goes to the spot)
	w:advance(3)
	eq(bea.W.Drive.IsOpen(), true, "control: still open after the captain left")
	-- Bea relogs / joins late: she asks for a sync, the one who answers is the leader (Cal)
	bea.W.Drive.Hello(true)
	w:advance(5)
	ok(bea.W.Drive.IsOpen(),
		"Bea's crew window was Open; after the helper Cal (who leads) answered her sync it reads Closed (Cal sent CFG selling=0)")
	T.clean(w)
end)
