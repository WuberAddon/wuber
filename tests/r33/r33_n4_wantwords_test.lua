local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
local ANA = "Ana Smith"

local function invites(w, name)
	local n = 0
	for _, i in ipairs(w.invites) do if key(i.to) == key(name) then n = n + 1 end end
	return n
end

test("audit C39b-6: a whisper for an unlisted place starting with our 2-letter alias is auto-invited", function()
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = "Orgrimmar", class = "WARLOCK",
		saved = { Wuber = { chars = { [key(ANA)] = { wizard = true, captain = "", runner = true, crew = {} } } } } })
	w:advance(10)
	local DR = ana.W.Drive
	DR.SetDest("Sunken Temple")
	ok(DR.SetOpen(true))
	w:advance(5)
	-- control: an unknown place after "to" (not starting with st) is a lead, never invited
	w:addBot("Cal Brown", { spot = "Thunder Bluff" })
	w:botWhisper("Cal Brown", ana, "summon to xanadu pls")
	w:advance(3)
	eq(invites(w, "Cal Brown"), 0, "control: 'summon to xanadu' is not invited while we serve Sunken Temple")
	-- bug: Steamwheedle starts with our alias "st"
	w:addBot("Dan Miller", { spot = "Thunder Bluff" })
	w:botWhisper("Dan Miller", ana, "summon to steamwheedle pls")
	w:advance(3)
	eq(invites(w, "Dan Miller"), 0, "'summon to steamwheedle pls' asks for a place we do not summon to (we serve Sunken Temple) but Dan is invited")
	T.clean(w)
end)
local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
local ANA = "Ana Smith"

local function invites(w, name)
	local n = 0
	for _, i in ipairs(w.invites) do if key(i.to) == key(name) then n = n + 1 end end
	return n
end

test("audit C39b-7: a rival's advert containing 'can invite' is read as a buyer and invited", function()
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = "Orgrimmar", class = "WARLOCK",
		saved = { Wuber = { chars = { [key(ANA)] = { wizard = true, captain = "", runner = true, crew = {} } } } } })
	w:advance(10)
	local DR = ana.W.Drive
	ok(DR.SetOpen(true))
	DR.opts().watchPublic, DR.opts().autoPublic = true, true
	w:advance(5)
	w:addBot("Rival One", { spot = "Orgrimmar" })
	w:addBot("Rival Two", { spot = "Orgrimmar" })
	-- control: a plain advert is no buyer
	DR.PublicLine("Summon service to Orgrimmar 1g, pst me, will invite fast", "Rival One", true)
	w:advance(3)
	eq(invites(w, "Rival One"), 0, "control: the advert is not a buyer")
	-- bug: "can invite" starts with the phrase "can i"
	DR.PublicLine("Summon service to Orgrimmar 1g, pst me, can invite fast", "Rival Two", true)
	w:advance(3)
	eq(invites(w, "Rival Two"), 0, "a seller's advert ('Summon service to Orgrimmar 1g, pst me, can invite fast') was read as a buyer and the seller got an invite")
	T.clean(w)
end)