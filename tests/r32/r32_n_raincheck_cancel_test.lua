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


test("r32 n: a cancelled raincheck ride does not use the raincheck up on a later plain summon", function()
	local s = scene()
	local w, DR = s.w, s.DR
	local _, ride = paidThenFailed(s)
	closeShop(s)
	local id = give(s, ride)
	DR.RaincheckHeard("ok", key(TESTCHAR), TESTCHAR, id)
	w:advance(1)
	DR.SetOpen(true)
	w:advance(2)
	s.r.W.ride = nil
	s.voucher = id
	local c2 = book_ride(s)
	eq(c2.voucher, id, "control: the raincheck is redeemed on the new ride")
	eq(book(s.ana)[id].onRide, c2.wuberRide, "control: the book ties it to that ride")
	-- Wuber cancels the raincheck ride before the summon
	ok(s.r.W.CancelRide(), "Wuber cancels")
	w:advance(3)
	ok(DR.customers[key(TESTCHAR)] == nil, "control: the row is off Ana's list")
	eq(book(s.ana)[id].state, "active", "control: the raincheck is still good after the cancel")
	-- a normal ride from the same driver, no raincheck on it, full fare
	s.r.W.ride = nil
	s.voucher = nil
	local c3 = book_ride(s)
	eq(c3.voucher, nil, "control: no raincheck on this ride")
	c3.tries = 1 -- (d4 x4) summoned once: a rider who walks up with no summon of ours now leaves the list
	w:move(TESTCHAR, SPOT)
	w:advance(3)
	eq(book(s.ana)[id].state, "active",
		"Wuber cancelled the raincheck ride and then paid a full-fare ride, but his raincheck is now '" .. tostring(book(s.ana)[id].state) .. "' (used up for a ride it did not pay for)")
	T.clean(s.w)
end)
