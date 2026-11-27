-- Round 33 c2, AUD-105: a rider already in the group who books again (after cancelling and staying in)
-- gets a new ride id; the crew's other Warlock windows now hear it (ST field 9), as for a rider who joins.
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


local function wire(s, oldPrice)
	local engine = s.DR.ENGINE
	local prev = engine.onRequest
	engine.onRequest = function(x) x.price = oldPrice return prev(x) end
end

test("r33 c2 AUD-105: a rider already in the group books again: the crew's other Warlocks learn the new ride id", function()
	local s = scene()
	local w, DR = s.w, s.DR
	-- control path first: a rider outside the group, fare unchanged: Bea learns the ride id (ST on joining)
	local c = book_ride(s)
	w:advance(3)
	local cb = s.bea.W.Drive.customers[key(TESTCHAR)]
	eq(cb and s.bea.W.Drive.RideIdOf(cb), c.wuberRide, "control: a rider who joins after booking: Bea's window knows the ride id")
	-- Wuber cancels, stays in the group; Ana then raises her fare; Wuber (still showing the old fare) books again
	ok(s.r.W.CancelRide(), "Wuber cancels")
	w:advance(3)
	s.r.W.ride = nil
	ok(w:player(TESTCHAR).group, "Wuber is still in the group")
	DR.char().price = FARE + 1500
	wire(s, FARE)
	ok(s.r.W.RequestRide(key(ANA)), "Wuber books Ana again")
	w:advance(9)
	local c2 = DR.customers[key(TESTCHAR)]
	ok(c2 and c2.wuberRide, "Ana took the new ride")
	eq(c2.price, FARE, "control: Ana locked the old fare for him")
	local cb2 = s.bea.W.Drive.customers[key(TESTCHAR)]
	ok(cb2, "Bea lists Wuber")
	local bid = cb2 and s.bea.W.Drive.RideIdOf(cb2)
	ok(bid == c2.wuberRide,
		"Ana's window has the new ride " .. tostring(c2.wuberRide) .. " for Wuber but Bea's window shows ride " .. tostring(bid)
		.. " (the crew never hears the ride id, so passphrase and prepaid tracking miss it)")
	eq(cb2 and tonumber(cb2.price), FARE, "Bea's window has the fare Ana locked for him")
	T.clean(s.w)
end)
