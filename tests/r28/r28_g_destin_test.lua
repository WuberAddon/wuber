local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
local ANA, BEA = "Ana Smith", "Bea Jones"

local function world()
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK",
		saved = { Wuber = { chars = { [key(ANA)] = { wizard = true, captain = "", runner = true, summoners = { ANA, BEA },
			crew = { { name = BEA, role = "lock", app = true } } } } } } })
	w:addClient(BEA, { spot = "Orgrimmar", class = "WARLOCK",
		saved = { Wuber = { chars = { [key(BEA)] = { wizard = true, captain = ANA, crew = { { name = ANA, role = "lock", app = true } } } } } } })
	w:group({ ANA, BEA })
	w:advance(10)
	local DR = ana.W.Drive
	ok(DR.SetOpen(true))
	w:advance(10)
	eq(DR.MultiStation(), true, "two stations (Undercity, Orgrimmar)")
	return w, ana, DR
end

local function ask(w, ana, name, text)
	w:addBot(name, { spot = "Thunder Bluff" })
	w:botWhisper(name, ana, text)
	w:advance(6)
	local c = ana.W.Drive.customers[key(name)]
	return c
end

local function one()
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK",
		saved = { Wuber = { chars = { [key(ANA)] = { wizard = true, captain = "", runner = true } } } } })
	w:advance(10)
	local DR = ana.W.Drive
	ok(DR.SetOpen(true))
	w:advance(10)
	eq(DR.MultiStation(), false, "one station (Undercity)")
	return w, ana, DR
end

local function st(c)
	return c and (c.state .. "/" .. tostring(c.station) .. (c.elsewhere and "/elsewhere" or "")) or "no rider"
end

test("r28 AUD-46: with two stations, 'summon from Ironforge to UC' is queued at Undercity and 'from Undercity to Org' at Orgrimmar", function()
	local w, ana, DR = world()
	local c0 = ask(w, ana, "Cal Brown", "summon to uc pls")
	ok(c0 and c0.state == "joined" and c0.station == "Undercity", "control: 'summon to uc pls' is queued at Undercity, got " .. st(c0))
	local c1 = ask(w, ana, "Dan Miller", "summon from ironforge to uc pls")
	local c2 = ask(w, ana, "Eve Long", "summon from undercity to org pls")
	ok(c1 and c1.state == "joined" and c1.station == "Undercity" and c2 and c2.station == "Orgrimmar",
		"'summon from ironforge to uc pls' should queue at Undercity but is " .. st(c1) .. "; 'summon from undercity to org pls' should queue at Orgrimmar but is " .. st(c2))
	T.clean(w)
end)

test("r28 AUD-46: with two stations, plain 'summon to org' goes to Orgrimmar and 'org pls' is unchanged", function()
	local w, ana, DR = world()
	local c1 = ask(w, ana, "Dan Miller", "summon to org")
	local c2 = ask(w, ana, "Eve Long", "org pls")
	ok(c1 and c1.state == "joined" and c1.station == "Orgrimmar", "'summon to org' is queued at Orgrimmar, got " .. st(c1))
	-- 'org pls' names no summon: today it waits as a lead (this pins that it does not change)
	eq(st(c2), "lead/nil", "'org pls' waits as a lead as before")
	T.clean(w)
end)

test("r28 AUD-46: with one station at Undercity, 'summon from Ironforge to UC' is queued as before", function()
	local w, ana, DR = one()
	local c1 = ask(w, ana, "Dan Miller", "summon from ironforge to uc pls")
	ok(c1 and c1.state == "joined" and c1.station == "Undercity", "one station: queued at Undercity, got " .. st(c1))
	T.clean(w)
end)
