local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANA, BEA, CAL = "Ana Smith", "Bea Jones", "Cal Brown"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function crewSaved(me, names, captain)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end
	end
	return { chars = { [key(me)] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true } } }
end

test("r33 h2 AUD-112: a crew member's danger at another station counts as 'Hot drop' once they leave the group", function()
	local w = H.NewWorld({})
	local names = { ANA, BEA, CAL }
	local cs = {}
	for i, n in ipairs(names) do
		cs[i] = w:addClient(n, { spot = (n == CAL) and "Orgrimmar" or "Undercity", class = "WARLOCK", saved = { Wuber = crewSaved(n, names, ANA) } })
	end
	local ana, bea, cal = cs[1], cs[2], cs[3]
	w:group(names)
	w:addBot("Ally Foe", { faction = "Alliance", spot = "Orgrimmar" })
	w:advance(1)
	ana.W.Drive.SetOpen(true)
	w:advance(5)
	w:pvpFight(cal, "Ally Foe") -- Cal fights at Orgrimmar, a different station
	w:advance(3)
	eq((cal.W.Drive.DangerLevel()), 2, "control: Cal's own window knows he fought")
	eq(ana.W.Drive.peers[key(CAL)].place ~= nil and true or false, true, "control: Ana knows Cal's place: " .. tostring(ana.W.Drive.peers[key(CAL)].place))
	eq((ana.W.Drive.DangerLevel()), 0, "control: Cal's fight at another station does not count for Ana at Undercity")
	w:leave(CAL) -- Cal leaves the group (or is kicked) a few seconds later
	w:advance(3)
	eq(ana.W.Drive.peers[key(CAL)], nil, "control: Ana's peer record for Cal is gone")
	eq((ana.W.Drive.DangerLevel()), 0, "Cal is out of the group and was never at Ana's station, yet Ana's crew now reports danger level " .. ana.W.Drive.DangerLevel() .. " ('Hot drop' warning to riders)")
	T.clean(w)
end)
