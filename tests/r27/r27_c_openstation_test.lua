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

test("r27 AUD-05: control, two open stations serve both places", function()
	local w, ana = two()
	local DR = ana.W.Drive
	local list = DR.ServedPlaces()
	ok(list and #list == 2, "two stations are open and both are served; got " .. (list and table.concat(list, ",") or "nil"))
	T.clean(w)
end)

test("r27 AUD-05: with the runner's own station switched off, only the open one is served", function()
	local w, ana = two()
	local DR = ana.W.Drive
	local sts = DR.Stations()
	eq(#sts, 2, "two stations")
	eq(sts[1].place, "Orgrimmar", "the runner's station is first")
	ok(DR.SetStation("Orgrimmar", false), "runner switches Orgrimmar off")
	w:advance(1)
	local list = DR.ServedPlaces()
	eq(list and list[1], "Undercity",
		"Orgrimmar is switched off, only Undercity is open, but the driver serves: " .. (list and table.concat(list, ",") or "nil"))
	T.clean(w)
end)

test("r27 AUD-05: a rider asking for the open station is queued, not left as a lead", function()
	local w, ana = two()
	local DR = ana.W.Drive
	DR.SetStation("Orgrimmar", false)
	w:advance(1)
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	w:botWhisper("Dan Miller", ana, "summon to undercity pls")
	w:advance(3)
	local c = DR.customers["dan miller"]
	ok(c, "Dan is listed")
	ok(c and c.state ~= "lead", "Dan asked for Undercity, the one open station, but sits as a lead: " .. tostring(c and c.state))
	T.clean(w)
end)