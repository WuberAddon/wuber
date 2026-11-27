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

test("r28 AUD-63: control, an exact payment is a fare with no tip", function()
	local w, a, A, c = landed()
	local tipSeen
	a.W.Listen("DRIVE_PAID", function(name, copper, tip) tipSeen = tip end)
	local dan = w:player("Dan Miller")
	ok(w:openTrade(dan, a.player), "trade opens")
	w:typeTradeMoney(dan, 0, 50, 0)
	w:tradeAccept(dan) w:tradeAccept(w:player(ANITA))
	w:advance(3)
	eq(c.paid, 5000, "control: paid exactly")
	eq(tipSeen, 0, "control: no tip")
end)

test("r28 AUD-63: the driver giving change back is a fare, not a tip", function()
	local w, a, A, c = landed()
	local tipSeen
	a.W.Listen("DRIVE_PAID", function(name, copper, tip) tipSeen = tip end)
	local dan = w:player("Dan Miller")
	ok(w:openTrade(dan, a.player), "trade opens")
	w:typeTradeMoney(dan, 1, 0, 0)           -- Dan hands over 1g for a 50s fare
	w:typeTradeMoney(w:player(ANITA), 0, 50, 0) -- the driver puts 50s change in
	w:tradeAccept(dan) w:tradeAccept(w:player(ANITA))
	w:advance(3)
	eq(tipSeen, 0, "net the driver got 50s (the fare); Wuber logs a tip of " .. tostring(tipSeen) .. " copper and paid=" .. tostring(c.paid))
	T.clean(w)
end)