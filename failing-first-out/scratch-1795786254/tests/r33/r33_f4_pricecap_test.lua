local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- Round 33 f4 (HUNT-58): /wuber price 50000g said "Your price is now 50000g" while the driver engine and
-- the network cap a price at 99,999,999 copper (9,999g 99s 99c).
test("r33 f4 HUNT-58: /wuber price above the cap is refused and says the highest fare", function()
	local w = H.NewWorld({})
	local a = w:addClient("Ana Smith", { spot = "Orgrimmar", class = "WARLOCK" })
	w:advance(5)
	a:slash("/wuber price 50s")
	local good = a.W.Char().price
	a:slash("/wuber price 50000g")
	eq(a.W.Char().price, good, "price unchanged by an impossible one")
	ok(not a:said("is now 50000g"), "no false confirmation")
	ok(a:said("highest fare"), "it says the highest fare")
	a:slash("/wuber price 9999g")
	eq(a.W.Char().price, 99990000, "a price inside the cap is still taken")
end)
