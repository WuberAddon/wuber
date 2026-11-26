-- Tests of Drive.Kitchen. Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local ANA, BEA, CAL, TESTCHAR = "Ana Smith", "Bea Jones", "Cal Brown", "Wuber TestCharacter"
local SPOT = "Undercity"

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function crewSaved(me, names, captain)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end
	end
	return { chars = { [key(me)] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true } } }
end

-- Three Warlocks of one crew (Ana leads), open; a rider with the app requests a ride from Ana and
-- joins. Every window's W.SendRitual is a spy: the G each would send.
local function rideScene(opts)
	opts = opts or {}
	local w = H.NewWorld({})
	local names = { ANA, BEA, CAL }
	local cs = {}
	for i, name in ipairs(names) do
		cs[i] = w:addClient(name, { spot = SPOT, class = "WARLOCK", saved = { Wuber = crewSaved(name, names, ANA) } })
	end
	local r = w:addClient(TESTCHAR, { spot = "Orgrimmar", class = "MAGE", money = 100000 })
	w:group(names)
	w:advance(15)
	cs[1].W.Drive.SetOpen(true)
	w:advance(8)
	local sent = {}
	for _, c in ipairs(cs) do
		sent[c] = {}
		c.W.SendRitual = function(...)
			local t = sent[c]
			t[#t + 1] = { at = w.time, ... }
			return true
		end
	end
	-- R field 6 (Net.Raincheck/Requests hand it to the engine as ride.version)
	local engine = cs[1].W.Drive.ENGINE
	local onRequest = engine.onRequest
	engine.onRequest = function(x)
		-- version = false: an old rider's R without field 6 (the test clients are 2.3.0 now)
		if opts.version == false then x.riderVer, x.version = nil, nil else x.riderVer = opts.version or "2.3.0" end
		return onRequest(x)
	end
	local ride = r.W.RequestRide(key(ANA))
	ok(ride, "the rider requested")
	w:advance(9)
	local c = cs[1].W.Drive.customers[key(TESTCHAR)]
	ok(c and c.wuberRide, "Ana took the Wuber ride")
	return w, cs[1], cs[2], cs[3], r, sent, c
end

local function phases(list)
	local out = {}
	for _, g in ipairs(list) do out[#out + 1] = g[3] end
	return table.concat(out, " ")
end

test("drive.kitchen: contract (registered, deps, header, public names); version compare", function()
	local W, w, r, Mod = T.contract("Drive.Kitchen", "tests/drive/kitchen_test.lua", {
		["DR.CLICKERS"] = "number", ["DR.KitchenSend"] = "function", ["DR.RiderVersionOk"] = "function",
		["DR.kitchen"] = "table",
	})
	ok(Mod, "W.Mod(\"Drive.Kitchen\")")
	local DR = W.Drive
	eq(DR.CLICKERS, 2, "two clickers besides the caster")
	eq(DR.RiderVersionOk("2.3.0"), true)
	eq(DR.RiderVersionOk("2.3.1"), true)
	eq(DR.RiderVersionOk("2.10"), true)
	eq(DR.RiderVersionOk("3"), true)
	eq(DR.RiderVersionOk("2.2.3"), false)
	eq(DR.RiderVersionOk("2.2.10"), false)
	eq(DR.RiderVersionOk(nil), false)
	eq(DR.RiderVersionOk("junk"), false)
	eq(DR.KitchenSend({}, "c"), nil, "not a Wuber ride: nothing")
	T.clean(w)
end)

test("drive.kitchen: the phases in order from the facts; only the network driver's window sends G", function()
	local w, ana, bea, cal, r, sent, c = rideScene()
	eq(c.state, "joined", "the rider joined")
	eq(phases(sent[ana]), "q", "in the group: q")
	local q = sent[ana][1]
	eq(q[1], c.wuberRide, "ride id") eq(q[2], c.wuberBuyer, "the buyer") eq(q[4], 0, "tapped") eq(q[5], 2, "need")
	eq(q[6], "", "no caster yet") eq(q[7], 0, "no danger")
	ana.W.Drive.Do("GR", TESTCHAR)
	w:advance(2)
	ana.W.Drive.Do("CAST", TESTCHAR)
	w:advance(2)
	bea.W.Drive.Do("HELP", TESTCHAR)
	w:advance(2)
	cal.W.Drive.Do("HELP", TESTCHAR)
	w:advance(2)
	ana.W.Drive.Do("END", TESTCHAR, 1)
	w:advance(2)
	eq(phases(sent[ana]), "q t c h h s", "every step once, in order")
	local list = sent[ana]
	eq(list[3][6], "Ana", "the caster's short name") eq(list[3][4], 0, "nobody tapped yet")
	eq(list[4][4], 1, "1/2 tapped") eq(list[5][4], 2, "2/2 tapped")
	eq(list[6][4], 2, "s keeps the count")
	eq(#sent[bea] + #sent[cal], 0, "the crew windows send nothing")
	-- a failed retry
	ana.W.Drive.Do("CAST", TESTCHAR)
	w:advance(2)
	ana.W.Drive.Do("END", TESTCHAR, 0)
	w:advance(0.1)
	eq(phases(sent[ana]), "q t c h h s c f", "the rift closed")
	T.clean(w)
end)

test("drive.kitchen: on change only; 1.5 s apart (the latest held change goes when the gap ends); s/f at once; 15 per ride", function()
	local w, ana, bea, cal, r, sent, c = rideScene()
	local list = sent[ana]
	local n0 = #list
	ana.W.Drive.Do("CAST", TESTCHAR)
	bea.W.Drive.Do("HELP", TESTCHAR) -- within the gap: held
	w:advance(0.5)
	eq(#list, n0 + 1, "c went at once, h waits")
	cal.W.Drive.Do("HELP", TESTCHAR) -- replaces the held one
	w:advance(2)
	eq(#list, n0 + 2, "one more G: the latest state")
	eq(list[#list][3], "h") eq(list[#list][4], 2, "2 tapped, not 1")
	ok(list[#list].at - list[#list - 1].at >= 1.5, "1.5 s apart")
	-- the same state again: nothing
	eq(ana.W.Drive.KitchenSend(c, "h"), nil, "no change, no G")
	-- s goes at once even inside the gap
	ana.W.Drive.Do("END", TESTCHAR, 1)
	eq(list[#list][3], "s", "s at once")
	-- the cap
	for i = 1, 30 do
		ana.W.Drive.KitchenSend(c, i % 2 == 0 and "s" or "f")
	end
	eq(#list, 15, "15 G per ride at most")
	T.clean(w)
end)

test("drive.kitchen: an old rider (no R field 6, or under 2.3.0) and a whisper rider get no G", function()
	local w, ana, bea, cal, r, sent, c = rideScene({ version = false })
	ana.W.Drive.Do("CAST", TESTCHAR)
	w:advance(2)
	eq(#sent[ana], 0, "no version: no G")
	c.wuberVer = "2.2.3"
	ana.W.Drive.Do("END", TESTCHAR, 0)
	w:advance(2)
	eq(#sent[ana], 0, "2.2.3: no G")
	local plain = { key = "dan miller", name = "Dan Miller", state = "joined" }
	eq(ana.W.Drive.KitchenSend(plain, "c"), nil, "a whisper rider: no ride id, no G")
	T.clean(w)
end)

test("drive.kitchen: G carries the crew's danger level", function()
	local w, ana, bea, cal, r, sent, c = rideScene()
	w:addBot("Ally Foe", { faction = "Alliance", spot = SPOT })
	w:pvpFight(bea, "Ally Foe")
	w:advance(2)
	eq((ana.W.Drive.DangerLevel()), 2, "Bea's fight reached Ana")
	ana.W.Drive.Do("CAST", TESTCHAR)
	w:advance(2)
	eq(sent[ana][#sent[ana]][7], 2, "danger 2 in G")
	T.clean(w)
end)
