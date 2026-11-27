local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

test("r33 n6 AUD-86: a first-time rider who paid just before a /reload is shown as '2nd ride with you'", function()
	local w = T.newWorld()
	local ana = w:addClient("Ana Smith", { spot = "Undercity", class = "WARLOCK" })
	w:addBot("Dan Miller", { spot = "Undercity" })
	w:group({ "Ana Smith", "Dan Miller" })
	w:advance(1)
	local DR = ana.W.Drive
	DR.SetOpt("autoTrade", false)
	DR.SetOpen(true)
	w:advance(2)
	local c = DR.customers["dan miller"]
	ok(c, "Dan is a customer of the driver's window (first sight)")
	c.state, c.price, c.tries = "arrived", 5000, 1
	local dan = w:player("Dan Miller")
	ok(w:openTrade(dan, ana.player), "trade open")
	w:typeTradeMoney(dan, 0, 50, 0)
	w:tradeAccept(dan)
	w:tradeAccept(ana.player)
	w:advance(2)
	eq(c.paid, 5000, "Dan paid his first ride")
	eq(DR.RideCount("Dan Miller"), 0, "control: before the reload this is his first ride")
	-- /reload, a few seconds later; Dan is still in the group
	local ana2 = w:reload(ana)
	w:advance(5)
	local DR2 = ana2.W.Drive
	local n = DR2.RideCount("Dan Miller")
	ok(DR2.customers["dan miller"], "Dan is restored as a customer after the reload")
	eq(n, 0, "after the /reload the driver's row for Dan reads '2nd ride with you' (RideCount=" .. n .. ") although he never rode before")
	T.clean(w)
end)