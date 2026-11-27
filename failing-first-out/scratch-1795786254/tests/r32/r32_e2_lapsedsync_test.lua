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

local CAL="Cal Brown"
local function scene()
	local w = H.NewWorld({})
	local names = { BEA, ANA, CAL }   -- Bea is the captain
	local cs = {}
	for i, name in ipairs(names) do
		cs[i] = w:addClient(name, { spot = "Undercity", class = "WARLOCK", saved = { Wuber = crewSaved(name, names, BEA) } })
	end
	w:group(names)
	w:advance(15)
	return w, cs[2], cs[1], cs[3]
end

test("r32 e2: a crew mate who missed the rider's acceptance must not void the active raincheck on rejoin", function()
	local w, ana, bea, cal = scene()
	local t = ana.env.time()
	local exp = t + 6 * 86400
	local id = "Lapse001"
	-- control: Ana offers; Bea hears the offer
	ana.W.Drive.Do("IOU", "i", id, key(TESTCHAR), 5000, exp, "")
	w:advance(3)
	ok(book(bea)[id] and book(bea)[id].state == "offered", "control: Bea's book has the offer")
	-- Bea leaves the group (or logs off) and misses the rider's acceptance
	w:leave(BEA)
	w:advance(2)
	ana.W.Drive.Do("IOU", "a", id, key(TESTCHAR), 5000, exp, "")
	w:advance(3)
	eq(book(ana)[id].state, "active", "control: Ana's raincheck is active")
	-- 31 minutes later Bea's offer window lapses locally
	for i = 1, 31 do w:advance(60) end
	eq(book(bea)[id].state, "void", "Bea's own copy lapsed")
	eq(book(bea)[id].why, "lapsed", "lapsed")
	-- Bea regroups with Ana: her join sync
	w:join(w:player(ANA), w:player(BEA))
	w:advance(10)
	-- a third crew window (Cal) reloads and asks for a sync; the captain's window (Bea) answers with her book
	ok(book(cal)[id] and book(cal)[id].state == "active", "control: Cal's copy is active before the sync")
	cal = w:reload(cal)
	w:advance(30)
	local st = book(ana)[id].state
	local stc = book(cal)[id] and book(cal)[id].state
	ok(st == "active", "the rider's raincheck is still valid in Ana's window, but it reads '" .. tostring(st) .. "' in Ana's window and '" .. tostring(stc) .. "' in Cal's (voided by Bea's local lapse)")
	T.clean(w)
end)
