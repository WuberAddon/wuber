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


test("r33 d4 AUD-106: a refused app request drops the ghost invited row the chat line made", function()
	local s = scene()
	local w, DR = s.w, s.DR
	s.r.W.db.autoAccept = false
	local c = DR.Request(TESTCHAR, "whisper", "WTB summon to " .. SPOT .. " for 50s")
	ok(c, "control: Ana took the chat line")
	eq(c.state, "invited", "control: with room in the group Ana invites at once")
	-- the app's request follows, for another place: Ana's engine refuses it
	local calls = {}
	local doit = DR.Do
	DR.Do = function(k, ...) calls[#calls + 1] = tostring(k) return doit(k, ...) end
	DR.ENGINE.onRequest({ id = "ZZtest", buyer = TESTCHAR, dest = "Orgrimmar", price = FARE })
	w:advance(3)
	local row = DR.customers[key(TESTCHAR)]
	eq(#s.accepts, 0, "control: the app request was never accepted")
	ok(row == nil or row.state ~= "invited",
		"Wuber is still listed as '" .. tostring(row and row.state) .. "' after the refusal")
	T.clean(s.w)
end)
