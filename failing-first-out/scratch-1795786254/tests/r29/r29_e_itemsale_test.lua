local T = ...
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

local function putItem(a)
	a.env.GetTradePlayerItemInfo = function(i) if i == 1 then return "Greater Healing Potion", 134, 1, 1 end end
end

test("r29 AUD-64: a stranger's gold with nothing given back still counts as before", function()
	local w, a, A = landed()
	w:addBot("Pat Stranger", { spot = "Undercity" })
	local pat = w:player("Pat Stranger")
	ok(w:openTrade(pat, a.player), "trade opens")
	w:typeTradeMoney(pat, 0, 10, 0)
	w:tradeAccept(pat) w:tradeAccept(w:player(ANITA))
	w:advance(3)
	eq(A.session.copper, 1000, "a plain gift counts in the session")
end)

test("r29 AUD-64: selling an item to a stranger is not summon takings and is not announced", function()
	local w, a, A = landed()
	local paid = 0
	a.W.Listen("DRIVE_PAID", function() paid = paid + 1 end)
	w:addBot("Pat Stranger", { spot = "Undercity" })
	local pat = w:player("Pat Stranger")
	putItem(a)
	ok(w:openTrade(pat, a.player), "trade opens")
	w:typeTradeMoney(pat, 0, 10, 0)
	w:tradeAccept(pat) w:tradeAccept(w:player(ANITA))
	w:advance(3)
	eq(A.session.copper, 0, "session takings after an item sale: " .. tostring(A.session.copper))
	eq(paid, 0, "no PAID announced")
	T.clean(w)
end)

test("r29 AUD-64: a real rider who pays the fare while the driver hands over an item still counts", function()
	local w, a, A, c = landed()
	local dan = w:player("Dan Miller")
	putItem(a)
	ok(w:openTrade(dan, a.player), "trade opens")
	w:typeTradeMoney(dan, 0, 50, 0)
	w:tradeAccept(dan) w:tradeAccept(w:player(ANITA))
	w:advance(3)
	eq(c.paid, 5000, "the fare counts with an item in the trade")
	T.clean(w)
end)
