local T = ...
do
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANA, BEA = "Ana Smith", "Bea Jones"
local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
local function crewSaved(me, names, captain)
	local crew = {}
	for _, n in ipairs(names) do if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end end
	return { chars = { [key(me)] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true } } }
end
local function team()
	local w = H.NewWorld({})
	local names = { ANA, BEA }
	local cs = {}
	for i, n in ipairs(names) do
		cs[i] = w:addClient(n, { spot = "Undercity", class = "WARLOCK", saved = { Wuber = crewSaved(n, names, ANA) } })
	end
	w:group(names)
	w:advance(1)
	cs[1].W.Drive.SetOpen(true)
	w:advance(2)
	return w, cs[1], cs[2]
end


local function crewRide(closeFirst)
	local w, ana, bea = team()
	local A = ana.W.Drive
	A.SetOpt("autoTrade", false)
	w:addBot("Dan Miller", { spot = "Undercity" })
	w:botWhisper("Dan Miller", ana, "summon pls")
	w:advance(6)
	local c = A.customers["dan miller"]
	if not c then return w, ana, bea, A, nil end
	c.state, c.tries, c.price, c.paid = "arrived", 1, 5000, 0
	c.caster, c.walked = ana.W.myKey, nil
	if closeFirst then A.SetOpen(false) end
	w:advance(1)
	return w, ana, bea, A, c
end

local function payAndLeave(w, ana, gap)
	local dan = w:player("Dan Miller")
	ok(w:openTrade(dan, ana.player), "trade opens")
	w:typeTradeMoney(dan, 0, 50, 0)
	w:tradeAccept(dan) w:tradeAccept(ana.player)
	w:advance(gap)
	w:leave("Dan Miller")
	w:advance(15)
end

test("r33 AUD-67: control, driver open, rider pays then leaves 0.1 s later in a crew: counted, not blocked", function()
	local w, ana, bea, A, c = crewRide(false)
	ok(c, "Dan is in the driver's list")
	payAndLeave(w, ana, 0.1)
	eq(A.BlockEntry("dan miller"), nil, "control: not blocked")
	eq(A.session.rides >= 1, true, "control: the ride counted")
end)

test("r33 AUD-67: driver closed, rider pays then leaves the group a tenth of a second later: not blocked as a non-payer", function()
	local w, ana, bea, A, c = crewRide(true)
	ok(c, "Dan is in the driver's list")
	payAndLeave(w, ana, 0.1)
	eq(A.BlockEntry("dan miller"), nil, "Dan paid 50s then left; the closed driver's crew never got the PAID and Dan is auto-blocked as a non-payer")
	T.clean(w)
end)

end
do
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"

-- a driver at Undercity, open, with rider Dan (arrived, fare 50s) in the list
local function landed(opts)
	local w = T.newWorld(opts)
	local a = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
	local A = a.W.Drive
	A.SetOpt("autoTrade", false)
	A.SetOpen(true)
	w:addBot("Dan Miller", { spot = "Undercity" })
	local c = { name = "Dan Miller", key = "dan miller", state = "arrived", price = 5000, paid = 0, at = 0, tries = 1 }
	A.customers["dan miller"] = c
	return w, a, A, c
end

test("r33 AUD-68: control, an amount that was read counts (real client order)", function()
	local w, a, A, c = landed({ tradeOrder = "real" })
	local dan = w:player("Dan Miller")
	ok(w:openTrade(dan, a.player), "trade opens")
	w:typeTradeMoney(dan, 0, 50, 0)
	w:tradeAccept(w:player(ANITA))
	w:tradeAccept(dan)
	w:advance(3)
	eq(c.paid, 5000, "control: a read amount is counted")
	T.clean(w)
end)

test("r33 AUD-68: a paid fare whose amount was not read before the close is still counted from the purse", function()
	local w, a, A, c = landed({ tradeOrder = "real" })
	local dan = w:player("Dan Miller")
	ok(w:openTrade(dan, a.player), "trade opens")
	-- Dan puts 50s in, but the driver's client answers 0 for the target's gold (never read before the close)
	a.env.GetTargetTradeMoney = function() return 0 end
	-- and the purse, as in the game, moves a moment after the close and the line (the harness's own 'real' order fires
	-- PLAYER_MONEY 0.3 s after; GetMoney here answers the old purse until 0.45 s after the accept)
	local oldMoney, realMoney, t0 = a.env.GetMoney(), a.env.GetMoney, nil
	a.env.GetMoney = function() if t0 and w.time < t0 + 0.45 then return oldMoney end return realMoney() end
	w:player(ANITA).trade.money["Dan Miller"] = 5000
	w:tradeAccept(w:player(ANITA))
	t0 = w.time
	w:tradeAccept(dan)
	-- real order: window closes, 'Trade complete.', the purse changes 0.3 s later
	w:advance(5)
	ok(w:player(ANITA).money - oldMoney >= 5000, "the purse did gain the 50s")
	eq(c.paid, 5000, "Dan paid 50s and the purse shows it, but the driver's row still reads unpaid (paid=" .. tostring(c.paid) .. ")")
	T.clean(w)
end)

end
