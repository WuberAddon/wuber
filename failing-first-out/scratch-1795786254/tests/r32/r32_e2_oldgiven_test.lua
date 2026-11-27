local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANA, BEA, TESTCHAR = "Ana Smith", "Bea Jones", "Wuber TestCharacter"
local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
local function crewSaved(me, names, captain)
	local crew = {}
	for _, n in ipairs(names) do if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end end
	return { chars = { [key(me)] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true } } }
end
local function book(c) return c.W.db.drive.iou or {} end

test("r32 e2: a raincheck given 3 days ago and learnt by join sync must not count as given today", function()
	local w = H.NewWorld({})
	local names = { ANA, BEA }
	local cs = {}
	for i, name in ipairs(names) do
		cs[i] = w:addClient(name, { spot = "Undercity", class = "WARLOCK", saved = { Wuber = crewSaved(name, names, ANA) } })
	end
	w:group(names)
	w:advance(15)
	local ana, bea = cs[1], cs[2]
	local t = ana.env.time()
	local from = t - 60 -- stand-in for the start of today
	-- control: one issued just now (expires in 7 days) counts as given today in Bea's window
	ana.W.Drive.Do("IOU", "i", "Today001", key(TESTCHAR), 5000, t + 7 * 86400, "")
	ana.W.Drive.Do("IOU", "a", "Today001", key(TESTCHAR), 5000, t + 7 * 86400, "")
	w:advance(3)
	local g0 = bea.W.Drive.RaincheckCounts(from)
	eq(g0, 1, "control: a raincheck given now counts as given today")
	-- a raincheck given 3 days ago (expires in 4 days) reaches Bea the way a join sync delivers it
	ana.W.Drive.Do("IOU", "i", "Old00001", "dan miller", 5000, t + 4 * 86400, "")
	ana.W.Drive.Do("IOU", "a", "Old00001", "dan miller", 5000, t + 4 * 86400, "")
	w:advance(3)
	ok(book(bea).Old00001 and book(bea).Old00001.state == "active", "control: Bea learnt the older raincheck")
	local g1 = bea.W.Drive.RaincheckCounts(from)
	eq(g1, 1, "Earnings' 'Today' says " .. g1 .. " rainchecks given, but only 1 was given today (the other was given 3 days ago; Bea's book stamps it issued=now)")
	T.clean(w)
end)
