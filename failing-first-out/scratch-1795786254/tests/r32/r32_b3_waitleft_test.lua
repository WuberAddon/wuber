local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"

local function waiting()
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
	local A = a.W.Drive
	A.SetOpen(true)
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan Miller")
	w:advance(3)
	A.Do("CAST", "Dan Miller")
	A.Do("END", "Dan Miller", 1)
	w:advance(2)
	eq(A.customers["dan miller"].state, "waiting", "the summon went out: Dan waits for the accept")
	return w, a, A
end

test("r32 b3: AUD-19: control, a rider who never accepts the summon goes back to joined after the wait", function()
	local w, a, A = waiting()
	w:advance(160)
	eq(A.customers["dan miller"].state, "joined", "Dan never accepted: back to joined so the driver can summon again")
	T.clean(w)
end)

test("r32 b3: AUD-19: after a /reload while waiting, a rider who never accepts also goes back to joined", function()
	local w, a, A = waiting()
	w:reload(a)
	w:advance(2)
	local a2 = w:clientOf(ANITA)
	local c = a2.W.Drive.customers["dan miller"]
	ok(c, "the queue was restored")
	eq(c.state, "waiting", "restored as waiting")
	w:advance(400)
	eq(a2.W.Drive.customers["dan miller"].state, "joined",
		"400 s after the reload Dan never accepted, yet the row still says waiting (never goes back to joined for another summon)")
	T.clean(w)
end)
