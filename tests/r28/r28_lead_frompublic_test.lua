local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
local ANA, BEA = "Ana Smith", "Bea Jones"

-- Groups G (AUD-46) and H (AUD-47) together: a public buyer who writes where he stands and where he wants to go.
test("r28 AUD-46 + AUD-47: with two stations, 'WTB summon from UC to org' in public chat is queued at Orgrimmar", function()
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
	DR.opts().watchPublic, DR.opts().autoPublic = true, true
	eq(DR.MultiStation(), true, "two stations (Undercity, Orgrimmar)")
	w:addBot("Dan Miller", { spot = "Undercity" })
	DR.PublicLine("WTB summon from UC to org", "Dan Miller", true)
	w:advance(3)
	local c = DR.customers[key("Dan Miller")]
	ok(c, "the buyer is listed")
	eq(c and c.station, "Orgrimmar", "queued for the place after 'to', not the place he stands in")
	T.clean(w)
end)
