-- prep-242 group G (Drive/Queue.lua), Google finding G11: one paid ride counts once, however many PAID
-- messages arrive for the rider. Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local RIDER = "Dan Miller"

local function driver()
	local w = T.newWorld()
	local a = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK", allowMissing = true })
	a.W.Drive.SetOpen(true)
	w:addBot(RIDER, { spot = "Orgrimmar" })
	a:chatEvent("CHAT_MSG_WHISPER", "summon pls", RIDER)
	w:advance(3)
	return w, a, a.W.Drive
end

for _, step in ipairs({ 1, 5 }) do
	test("p242 G3: two PAIDs for a rider who left count the ride once (step " .. step .. " s)", function()
		local w, a, A = driver()
		local price = A.customers["dan miller"].price
		w:leave(RIDER)
		w:advance(step)
		A.Apply("PAID", a.W.myKey, RIDER, tostring(price), "t")
		w:advance(step)
		A.Apply("PAID", a.W.myKey, RIDER, tostring(price), "t")
		w:advance(1)
		eq(A.session.rides, 1, "one ride, two messages")
		T.clean(w)
	end)
end

-- guard: a listed rider's second PAID also counts one ride
test("p242 G3 guard: two PAIDs for a listed rider count the ride once", function()
	local w, a, A = driver()
	local price = A.customers["dan miller"].price
	A.Apply("PAID", a.W.myKey, RIDER, tostring(price), "t")
	w:advance(1)
	A.Apply("PAID", a.W.myKey, RIDER, tostring(price), "t")
	w:advance(1)
	eq(A.session.rides, 1, "one ride")
	T.clean(w)
end)
