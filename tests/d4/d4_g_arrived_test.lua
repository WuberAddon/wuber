local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"

local function scene(rspot)
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Orgrimmar", class = "WARLOCK", allowMissing = true })
	local A = a.W.Drive
	A.SetOpen(true)
	w:addBot("Dan Miller", { spot = rspot })
	a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan Miller")
	w:advance(6)
	return w, a, A
end

test("d4 G: a waiting rider who walks up to the driver leaves the list after the hold, as a hand removal", function()
	local w, a, A = scene("Undercity")
	local c = A.customers["dan miller"]
	ok(c and c.state == "joined", "Dan waits, joined: " .. tostring(c and c.state))
	w:advance(3)
	w:move("Dan Miller", "Orgrimmar")
	w:advance(2)
	ok(A.customers["dan miller"], "two seconds beside us is not enough: still listed")
	w:advance(8)
	ok(not A.customers["dan miller"], "after the hold the row is gone")
	ok(A.ignored["dan miller"], "ignored like a hand removal, so the group does not list him again")
	eq(A.session.rides, 0, "not counted as a summon")
	ok(not A.owing["dan miller"], "no fare owed")
	T.clean(w)
end)

test("d4 G: a flicker shorter than the hold keeps the row", function()
	local w, a, A = scene("Undercity")
	w:advance(3)
	w:move("Dan Miller", "Orgrimmar")
	w:advance(1)
	w:move("Dan Miller", "Undercity")
	w:advance(10)
	ok(A.customers["dan miller"] and A.customers["dan miller"].state == "joined", "still waiting")
	T.clean(w)
end)

test("d4 G: being summoned, paid, or waiting for Next is never dropped", function()
	for _, how in ipairs({ "summoning", "paid", "priority", "tries" }) do
		local w, a, A = scene("Undercity")
		w:advance(3)
		local c = A.customers["dan miller"]
		if how == "summoning" then c.state = "summoning"; c.caster = a.W.myKey
		elseif how == "paid" then c.paid = 10000
		elseif how == "priority" then c.priority = true
		else c.tries = 1 end
		w:advance(2)
		w:move("Dan Miller", "Orgrimmar")
		w:advance(10)
		ok(A.customers["dan miller"], how .. ": the row stays")
		T.clean(w)
	end
end)

test("d4 G: already beside the driver at the ask is not dropped (the row says he is here)", function()
	local w, a, A = scene("Orgrimmar")
	w:advance(10)
	local c = A.customers["dan miller"]
	ok(c, "still listed")
	ok(c.state == "arrived" and c.walked, "the walked-up row as before: " .. tostring(c and c.state))
	T.clean(w)
end)
