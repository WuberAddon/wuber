local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"

local function ride(pause)
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
	local A = a.W.Drive
	A.SetOpen(true)
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan Miller")
	w:advance(3)
	A.Do("CAST", "Dan Miller")
	A.Do("END", "Dan Miller", 1)
	w:move("Dan Miller", "Undercity")
	w:advance(2)
	return w, a, A
end

test("r28 AUD-04: control, a rider who leaves long after paying is not blocked", function()
	local w, a, A = ride()
	local dan = w:player("Dan Miller")
	ok(w:openTrade(dan, w:player(ANITA)), "trade opens")
	w:typeTradeMoney(dan, 0, 50, 0)
	w:tradeAccept(dan)
	w:tradeAccept(w:player(ANITA))
	w:advance(3)
	w:leave("Dan Miller")
	w:advance(2)
	eq(A.BlockEntry("dan miller"), nil, "a rider who paid must not be blocked")
	T.clean(w)
end)

test("r28 AUD-04: a rider who pays then leaves the party a moment later is not blocked as a non-payer", function()
	local w, a, A = ride()
	local dan = w:player("Dan Miller")
	ok(w:openTrade(dan, w:player(ANITA)), "trade opens")
	w:typeTradeMoney(dan, 0, 50, 0)
	w:tradeAccept(dan)
	w:tradeAccept(w:player(ANITA))
	w:advance(0.1)
	w:leave("Dan Miller")
	w:advance(3)
	eq(A.BlockEntry("dan miller"), nil,
		"Dan paid 50s then left the party 0.1 s later, and the driver sees him auto-blocked as a non-payer")
	T.clean(w)
end)

test("r28 AUD-04: a solo driver's rider who leaves without paying is still recorded as owing after the grace", function()
	local w, a, A = ride()
	w:leave("Dan Miller")
	w:advance(5)
	ok(A.BlockEntry("dan miller") ~= nil, "a rider who left owing is blocked once the grace is over")
	T.clean(w)
end)
