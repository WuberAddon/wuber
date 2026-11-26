-- r27 group B: elsewhere leads (AUD-02, AUD-03), from the audit proof tests C41b-8 and C41b-7.
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
local function two()
	local w = H.NewWorld({})
	local names = { ANA, BEA, CAL }
	local spots = { ANA = "Orgrimmar", BEA = "Undercity", CAL = "Undercity" }
	local cs = {}
	for i, n in ipairs(names) do
		cs[i] = w:addClient(n, { spot = (i == 1) and "Orgrimmar" or "Undercity", class = "WARLOCK", saved = { Wuber = crewSaved(n, names, ANA) } })
	end
	w:group(names)
	w:advance(2)
	cs[1].W.Drive.SetOpen(true)
	w:advance(5)
	return w, cs[1], cs[2], cs[3]
end


local function lead()
	local w, ana = two()
	local DR = ana.W.Drive
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	w:botWhisper("Dan Miller", ana, "summon to ratchet pls")
	w:advance(3)
	local c = DR.customers["dan miller"]
	eq(c and c.state, "lead", "Dan is a lead for Ratchet, a place nobody here serves")
	ok(c.elsewhere, "marked elsewhere: the 'Where would you like to go?' whisper is owed")
	return w, ana, DR
end

test("r27 AUD-02: control, answering the 'where' question with a full request is invited", function()
	local w, ana, DR = lead()
	w:botWhisper("Dan Miller", ana, "wtb summon to orgrimmar pls")
	w:advance(5)
	local c = DR.customers["dan miller"]
	ok(c and c.state ~= "lead", "Dan asked clearly for Orgrimmar: state " .. tostring(c and c.state))
	T.clean(w)
end)

test("r27 AUD-02: answering the 'where' question with just a served place name moves the lead on", function()
	local w, ana, DR = lead()
	w:botWhisper("Dan Miller", ana, "Orgrimmar")
	w:advance(5)
	local c = DR.customers["dan miller"]
	ok(c and c.state ~= "lead",
		"we asked Dan where he wants to go, he whispered 'Orgrimmar' (a station we serve), and he is still just a lead: " .. tostring(c and c.state))
	T.clean(w)
end)
test("r27 AUD-02: answering with a place nobody here serves stays a lead", function()
	local w, ana, DR = lead()
	w:botWhisper("Dan Miller", ana, "Ratchet")
	w:advance(5)
	local c = DR.customers["dan miller"]
	eq(c and c.state, "lead", "Ratchet is still nowhere we summon to")
	w:botWhisper("Dan Miller", ana, "loch modan")
	w:advance(5)
	eq(c and c.state, "lead", "an unknown zone stays a lead")
	T.clean(w)
end)

test("r27 AUD-03: control, a whisper for an unserved place becomes a lead in multi-station mode", function()
	local w, ana = two()
	local DR = ana.W.Drive
	eq(DR.MultiStation(), true, "two stations open")
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	w:botWhisper("Dan Miller", ana, "summon to ratchet pls")
	w:advance(3)
	local c = DR.customers["dan miller"]
	ok(c, "listed")
	eq(c.state, "lead", "a lead for Ratchet")
	T.clean(w)
end)

test("r27 AUD-03: the driver clicks the lead row to invite: the rider is invited, not put back as a lead", function()
	local w, ana = two()
	local DR = ana.W.Drive
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	w:botWhisper("Dan Miller", ana, "summon to ratchet pls")
	w:advance(3)
	local c = DR.customers["dan miller"]
	eq(c and c.state, "lead", "a lead")
	DR.Invite(c)
	w:advance(5)
	local after = DR.customers["dan miller"]
	ok(after and after.state ~= "lead",
		"the driver clicked Dan's lead row to invite him by hand, and he is still a lead: " .. tostring(after and after.state))
	T.clean(w)
end)