local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
local ANA, BEA, CAT = "Ana Smith", "Bea Jones", "Cat Green"

local function invites(w, name)
	local n, from = 0, nil
	for _, i in ipairs(w.invites) do
		if key(i.to) == key(name) then n, from = n + 1, i.from end
	end
	return n, from
end

-- Ana (runner, Warlock) in Undercity, her crew Warlocks where spots says; Ana opens and watches
-- public chat with auto-invite on.
local function crew(spots)
	local w = T.newWorld()
	local names = { BEA, CAT }
	local summoners, crewList = { ANA }, {}
	for i = 1, #spots do
		summoners[#summoners + 1] = names[i]
		crewList[#crewList + 1] = { name = names[i], role = "lock", app = true }
	end
	local ana = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK",
		saved = { Wuber = { chars = { [key(ANA)] = { wizard = true, captain = "", runner = true, summoners = summoners,
			crew = crewList } } } } })
	local group = { ANA }
	for i = 1, #spots do
		w:addClient(names[i], { spot = spots[i], class = "WARLOCK",
			saved = { Wuber = { chars = { [key(names[i])] = { wizard = true, captain = ANA,
				crew = { { name = ANA, role = "lock", app = true } } } } } } })
		group[#group + 1] = names[i]
	end
	w:group(group)
	w:advance(10)
	local DR = ana.W.Drive
	ok(DR.SetOpen(true))
	w:advance(10)
	DR.opts().watchPublic, DR.opts().autoPublic = true, true
	return w, DR
end

test("r28 AUD-47: with two stations, 'WTB summon to org' in chat is invited for the Orgrimmar station", function()
	local w, DR = crew({ "Orgrimmar" })
	eq(DR.MultiStation(), true, "two stations (Undercity, Orgrimmar)")
	w:addBot("Cal Brown", { spot = "Thunder Bluff" })
	w:addBot("Dan Miller", { spot = "Thunder Bluff" })
	DR.PublicLine("WTB summon to UC", "Cal Brown", true)
	w:advance(3)
	eq(invites(w, "Cal Brown"), 1, "control: the buyer for Undercity is invited")
	eq(DR.PublicWant("WTB summon to org pls"), "match", "a buyer for our Orgrimmar station")
	DR.PublicLine("WTB summon to org pls", "Dan Miller", true)
	w:advance(3)
	local c = DR.customers[key("Dan Miller")]
	local n, from = invites(w, "Dan Miller")
	ok(n == 1 and c and c.station == "Orgrimmar",
		"'WTB summon to org pls' is for our Orgrimmar station: invites " .. n .. ", rider " .. tostring(c and c.state))
	eq(key(from or ""), key(ANA), "the runner's window (the group's leader) sends the invite")
	T.clean(w)
end)

test("r28 AUD-47: with two stations, a [Wuber] advert naming the other station is never a buyer", function()
	local w, DR = crew({ "Orgrimmar" })
	eq(DR.MultiStation(), true, "two stations")
	w:addBot("Dan Miller", { spot = "Thunder Bluff" })
	local line = "[Wuber] summons to org, ask for a ride"
	eq(DR.PublicWant(line), nil, "a tagged line is an advert")
	DR.PublicLine(line, "Dan Miller", true)
	w:advance(3)
	eq(invites(w, "Dan Miller"), 0, "nobody invited")
	eq(DR.customers[key("Dan Miller")], nil, "not listed")
	T.clean(w)
end)

test("r28 AUD-47: with two stations, a place no station serves is still elsewhere and nobody is invited", function()
	local w, DR = crew({ "Orgrimmar" })
	w:addBot("Dan Miller", { spot = "Thunder Bluff" })
	eq(DR.PublicWant("WTB summon to ratchet"), "elsewhere", "Ratchet: no station")
	eq(DR.PublicWant("WTB summon from org to ratchet"), "elsewhere", "standing in Org, going to Ratchet")
	DR.PublicLine("WTB summon to ratchet", "Dan Miller", true)
	w:advance(3)
	eq(invites(w, "Dan Miller"), 0, "nobody invited for Ratchet")
	T.clean(w)
end)

test("r28 AUD-47: with one station, 'WTB summon to org' is elsewhere as before and nobody is invited", function()
	local w, DR = crew({ "Undercity" })
	eq(DR.MultiStation(), false, "one station (both Warlocks in Undercity)")
	w:addBot("Cal Brown", { spot = "Thunder Bluff" })
	w:addBot("Dan Miller", { spot = "Thunder Bluff" })
	eq(DR.PublicWant("WTB summon to org pls"), "elsewhere", "Orgrimmar is not ours")
	DR.PublicLine("WTB summon to org pls", "Dan Miller", true)
	DR.PublicLine("WTB summon to UC", "Cal Brown", true)
	w:advance(3)
	eq(invites(w, "Dan Miller"), 0, "nobody invited for Orgrimmar")
	eq(invites(w, "Cal Brown"), 1, "the Undercity buyer is invited")
	T.clean(w)
end)

test("r28 AUD-47: a closed station's name does not make a buyer", function()
	local w, DR = crew({ "Orgrimmar", "Thunder Bluff" })
	ok(DR.SetStation("Thunder Bluff", false), "the runner closes Thunder Bluff")
	w:advance(3)
	eq(DR.MultiStation(), true, "Undercity and Orgrimmar stay open")
	w:addBot("Dan Miller", { spot = "Crossroads" })
	eq(DR.PublicWant("WTB summon to TB"), "elsewhere", "Thunder Bluff is closed")
	DR.PublicLine("WTB summon to TB", "Dan Miller", true)
	w:advance(3)
	eq(invites(w, "Dan Miller"), 0, "nobody invited for a closed station")
	eq(DR.PublicWant("WTB summon to org"), "match", "Orgrimmar is still open")
	T.clean(w)
end)
