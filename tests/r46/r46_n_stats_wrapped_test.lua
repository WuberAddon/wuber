-- Round 46 n: HUNT-45 (a ride marked paid by hand counts its gold in the drive stats, once) and
-- HUNT-84 second half (Wrapped hides a month-end level that the kept rides cannot prove).
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANA, BEA, CAL, TESTCHAR = "Ana Smith", "Bea Jones", "Cal Brown", "Wuber TestCharacter"
local SPOT, FARE = "Undercity", 5000
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function crewSaved(me, names, captain)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end
	end
	return { chars = { [key(me)] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true } } }
end

local function scene()
	local w = H.NewWorld({})
	local names = { ANA, BEA, CAL }
	local cs = {}
	for i, name in ipairs(names) do
		cs[i] = w:addClient(name, { spot = SPOT, class = "WARLOCK", saved = { Wuber = crewSaved(name, names, ANA) } })
	end
	local r = w:addClient(TESTCHAR, { spot = "Orgrimmar", class = "MAGE", money = 1000000 })
	w:group(names)
	w:advance(15)
	local s = { w = w, ana = cs[1], r = r }
	s.DR = s.ana.W.Drive
	s.DR.SetOpen(true)
	w:advance(8)
	return s
end

test("r46 n: HUNT-45 a ride marked paid by hand adds its gold to the drive stats, once", function()
	local s = scene()
	local DR = s.DR
	ok(s.r.W.RequestRide(key(ANA)), "requested")
	s.w:advance(9)
	local c = DR.customers[key(TESTCHAR)]
	ok(c and c.wuberRide, "Ana took the ride")
	DR.Do("PAID", TESTCHAR, FARE, "m")
	s.w:advance(1)
	local life = DR.Stats()
	eq(life.rides, 1, "one ride")
	eq(life.copper, FARE, "the hand-marked gold counts in the stats")
	-- a real payment of the same ride afterwards must not count the fare again
	DR.Do("PAID", TESTCHAR, FARE)
	s.w:advance(1)
	life = DR.Stats()
	eq(life.copper, FARE, "a later trade for the same fare does not count twice")
	T.clean(s.w)
end)

local function at(y, m, d, h) return os.time({ year = y, month = m, day = d, hour = h or 12, min = 0, sec = 0 }) end

test("r46 n: HUNT-84 Wrapped hides the month-end level when older rides may be gone", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W = r.W
	local Mod = W.Mod("Core.Wrapped")
	local function build(old, new)
		local t = {}
		for i = 1, old do t[#t + 1] = { at = at(2026, 9, 1) + i * 60, dest = "Undercity", price = 1000 } end
		for i = 1, new do t[#t + 1] = { at = at(2026, 11, 1) + i * 60, dest = "Undercity", price = 1000 } end
		return t
	end
	W.db.rides = build(5, 20)
	eq(Mod.Month(2026, 9).tier, 1, "whole history kept: five rides is Bronze")
	W.db.rides = build(5, 95)
	eq(Mod.Month(2026, 9).tier, 0, "full list: the level at the end of September cannot be trusted, hidden")
	eq(Mod.Month(2026, 11).tier, 3, "a month whose kept rides already reach the top level keeps it")
	T.clean(w)
end)
