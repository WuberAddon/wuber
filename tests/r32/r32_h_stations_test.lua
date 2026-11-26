local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- Round 32, group H: stations (Wuber/Drive/Places.lua).
-- AUD-50: with two stations, a rider in the same zone as his station but far from it (Crossroads
-- while the station is Ratchet) was marked arrived at once (same map id), and nobody summoned him.
-- AUD-51: a returning rider who named no place kept the station the runner had closed, was never
-- asked "Where to?" and was dropped a few seconds later with the "we moved" sorry.
local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
local ANA, BEA, DAN = "Ana Smith", "Bea Jones", "Dan Miller"

-- Ana summons at Ratchet. With twoStations, Bea (Wuber too) summons at Orgrimmar.
-- Dan stands at Crossroads (same zone map 1413, far from Ratchet: the game says he is NOT visible), asks for Ratchet.
local function scenario(twoStations)
	local w = T.newWorld()
	local crew = { { name = BEA, role = "lock", app = true } }
	if not twoStations then crew = {} end
	local ana = w:addClient(ANA, { spot = "Ratchet", class = "WARLOCK",
		saved = { Wuber = { chars = { [key(ANA)] = { wizard = true, captain = "", runner = true,
			summoners = twoStations and { ANA, BEA } or { ANA }, crew = crew } } } } })
	local bea
	if twoStations then
		bea = w:addClient(BEA, { spot = "Orgrimmar", class = "WARLOCK",
			saved = { Wuber = { chars = { [key(BEA)] = { wizard = true, captain = ANA, crew = { { name = ANA, role = "lock", app = true } } } } } } })
	end
	local orig = ana.env.UnitIsVisible
	ana.env.UnitIsVisible = function(u)
		local n = ana.env.UnitName(u)
		if n == "Dan" then return false end -- 600 yards away: not loaded for Ana
		return orig(u)
	end
	if twoStations then w:group({ ANA, BEA }) end
	w:advance(10)
	local DR = ana.W.Drive
	ok(DR.SetOpen(true))
	w:advance(10)
	w:addBot(DAN, { spot = "Crossroads" })
	w:botWhisper(DAN, ana, "summon to ratchet pls")
	w:advance(8)
	local c = DR.customers[key(DAN)]
	return w, DR, c, bea
end

test("r32 h: AUD-50 with two stations a rider far away in the same zone as his station waits for his summon", function()
	-- control: one station, Dan is far away: he is waiting for his summon
	local w1, DR1, c1 = scenario(false)
	ok(c1, "control: Dan is a rider")
	eq(c1.state, "joined", "control (one station): far-away Dan waits to be summoned")
	eq(DR1.MultiStation(), false)
	-- bug: two stations
	local w2, DR2, c2, bea = scenario(true)
	eq(DR2.MultiStation(), true, "two stations")
	ok(c2, "Dan is a rider")
	eq(c2.station, "Ratchet", "routed to Ratchet")
	eq(c2.state, "joined", "Dan is 600 yards from Ratchet and must wait for his summon, but the phone shows him as: " .. tostring(c2.state) .. (c2.walked and " (walked: nobody summons him)" or ""))
	-- Bea's window (her station is Orgrimmar) judges Ratchet's riders by where they stand on the map
	local BDR = bea.W.Drive
	local unit = BDR.units[key(DAN)]
	ok(unit, "Dan is in Bea's group too")
	eq(BDR.ArrivedAt({ station = "Ratchet" }, unit), false, "Bea's window: Dan at Crossroads is not at Ratchet")
	w2:addBot("Eve Clark", { spot = "Ratchet" })
	w2:group({ ANA, BEA, DAN, "Eve Clark" })
	w2:advance(2)
	local eve = BDR.units[key("Eve Clark")]
	ok(eve, "Eve is in Bea's group")
	eq(BDR.ArrivedAt({ station = "Ratchet" }, eve), true, "Bea's window: Eve at Ratchet has arrived")
	T.clean(w1) T.clean(w2)
end)
local CAL = "Cal Brown"

local function member(me, cap, others)
	local crew = {}
	for _, n in ipairs(others) do crew[#crew + 1] = { name = n, role = "lock", app = true } end
	return { Wuber = { chars = { [key(me)] = { wizard = true, captain = cap, crew = crew } } } }
end

test("r32 h: AUD-51 a returning rider who names no place after his station closed goes to an open station", function()
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK",
		saved = { Wuber = { chars = { [key(ANA)] = { wizard = true, captain = "", runner = true, summoners = { ANA, BEA, CAL },
			crew = { { name = BEA, role = "lock", app = true }, { name = CAL, role = "lock", app = true } } } } } } })
	w:addClient(BEA, { spot = "Orgrimmar", class = "WARLOCK", saved = member(BEA, ANA, { ANA, CAL }) })
	w:addClient(CAL, { spot = "Ironforge", class = "WARLOCK", saved = member(CAL, ANA, { ANA, BEA }) })
	w:group({ ANA, BEA, CAL })
	w:advance(10)
	local DR = ana.W.Drive
	ok(DR.SetOpen(true))
	w:advance(10)
	eq(#DR.Stations(), 3, "three stations")
	-- first ride: Dan names no place and is queued at the runner's station
	w:addBot(DAN, { spot = "Thunder Bluff" })
	w:botWhisper(DAN, ana, "summon pls")
	w:advance(6)
	local c = DR.customers[key(DAN)]
	ok(c and c.state == "joined", "control: Dan is a rider")
	eq(c.station, "Undercity", "control: Dan was put at the runner's station (Undercity)")
	DR.SetState(c, "done") -- his ride is over
	-- the runner then closes Undercity (two stations stay open)
	ok(DR.SetStation("Undercity", false))
	w:advance(5)
	eq(#DR.StationList():gsub("[^,]", ""), 1, "control: two stations open: " .. DR.StationList())
	-- Dan comes back for another summon and again names no place
	w:botWhisper(DAN, ana, "summon pls")
	w:advance(10)
	local c2 = DR.customers[key(DAN)]
	local mv = DR.moved[key(DAN)]
	ok(c2 and c2.state == "joined" and c2.station ~= "Undercity",
		"Dan asked for a summon again with Undercity closed and two stations open: he should be queued at an open station (or asked Where to?), but after 10 s he is "
		.. (c2 and ("kept for " .. tostring(c2.station)) or "gone from the list") .. (mv and (" and got the 'we moved' sorry (from " .. tostring(mv.from) .. ")") or ""))
	T.clean(w)
end)