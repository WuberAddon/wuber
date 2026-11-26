local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local ANA, BEA, CAL, TESTCHAR = "Ana Smith", "Bea Jones", "Cal Brown", "Wuber TestCharacter"
local SPOT = "Undercity"
local FARE = 5000

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
	local s = { w = w, ana = cs[1], bea = cs[2], cal = cs[3], r = r, ivs = {}, accepts = {} }
	local DR = s.ana.W.Drive
	s.DR = DR
	-- V to the rider (Net.Raincheck's Give / Void): recorded, then sent as usual
	for _, c in ipairs(cs) do
		local list = {}
		s.ivs[c] = list
		local RC = c.W.Raincheck
		local give, void = RC.Give, RC.Void
		RC.Give = function(...) list[#list + 1] = { "give", ... } return give(...) end
		RC.Void = function(...) list[#list + 1] = { "void", ... } return void(...) end
	end
	local accept = s.ana.W.AcceptRequest
	s.ana.W.AcceptRequest = function(...)
		s.accepts[#s.accepts + 1] = { ... }
		return accept(...)
	end
	local engine = DR.ENGINE
	local onRequest = engine.onRequest
	engine.onRequest = function(x)
		x.riderVer, x.voucher = "2.3.0", s.voucher
		return onRequest(x)
	end
	DR.SetOpen(true)
	w:advance(8)
	return s
end

local function book(c) return c.W.db.drive.iou or {} end

local function book_ride(s)
	ok(s.r.W.RequestRide(key(ANA)), "requested")
	s.w:advance(9)
	local c = s.DR.customers[key(TESTCHAR)]
	ok(c and c.wuberRide, "Ana took the Wuber ride")
	return c
end

local function paidThenFailed(s, copper, how)
	local c = book_ride(s)
	s.DR.Do("PAID", TESTCHAR, copper or FARE, how)
	s.w:advance(1)
	s.DR.Do("CAST", TESTCHAR)
	s.w:advance(1)
	s.DR.Do("END", TESTCHAR, 0)
	s.w:advance(1)
	return c, c.wuberRide
end

local function closeShop(s)
	s.DR.SetOpen(false)
	s.w:advance(2)
end

local function give(s, ride)
	local okG, id = s.DR.GiveRaincheck(ride)
	ok(okG, "given: " .. tostring(id))
	s.w:advance(1)
	return id
end


test("r32 n: a rider who just paid for a whisper ride books a Wuber ride and is not ended as done at once", function()
	local s = scene()
	local w, DR = s.w, s.DR
	-- Wuber asked by whisper, was invited, summoned, and paid by trade: his row waits in "paid" for thanks
	local c = DR.Request(TESTCHAR, "whisper", "WTB summon to Undercity")
	ok(c, "control: Ana took Wuber's whisper request")
	w:advance(3)
	DR.Do("PAID", TESTCHAR, FARE, "t")
	w:advance(1)
	eq(DR.customers[key(TESTCHAR)].state, "paid", "control: the whisper ride is paid and still listed")
	ok(DR.customers[key(TESTCHAR)].wuberRide == nil, "control: it was no Wuber ride")
	-- a minute later Wuber books another summon in the app
	w:advance(30)
	s.r.W.ride = nil
	ok(s.r.W.RequestRide(key(ANA)), "Wuber books Ana in the app")
	w:advance(9)
	local ride = s.r.W.ride
	local st = ride and ride.state
	ok(st ~= "done" and st ~= "paid",
		"Wuber asked for a NEW ride but his app shows it as '" .. tostring(st) .. "' at once (Ana never invited or summoned him; row: "
		.. tostring(DR.customers[key(TESTCHAR)] and DR.customers[key(TESTCHAR)].state) .. ")")
	T.clean(s.w)
end)