-- prep-242 group G (Drive/Queue.lua): H24-12 crew windows agree on the split when END/HELP arrive late;
-- H24-13 a PAID that arrives after the rider left the group still shows paid, with the amount.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local ANA, BEA, CAL = "Ana Smith", "Bea Jones", "Cal Brown"
local RIDER, BOB = "Dan Miller", "Bob Helper"
local STEPS = { 1, 5 } -- seconds between the late messages: the result is the same at both

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function crewSaved(me, names, captain)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end
	end
	return { chars = { [key(me)] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true } } }
end

local function team()
	local w = H.NewWorld({})
	local names = { ANA, BEA, CAL }
	local cs = {}
	for i, name in ipairs(names) do
		cs[i] = w:addClient(name, { spot = "Undercity", class = "WARLOCK", saved = { Wuber = crewSaved(name, names, ANA) } })
		cs[i].W.VERSION = "2.3.0"
	end
	local all = { ANA, BEA, CAL, RIDER, BOB }
	w:addBot(RIDER, { spot = "Orgrimmar" })
	w:addBot(BOB, { spot = "Orgrimmar" })
	w:group(all)
	w:advance(1)
	cs[1].W.Drive.SetOpen(true)
	w:advance(3)
	return w, cs[1], cs[2], cs[3]
end

local function rowsOf(c)
	local rows = c.W.Drive.Cut()
	local out = {}
	for _, r in ipairs(rows) do out[r.name] = r end
	return out
end

local function mark(c)
	local rows = rowsOf(c)
	local s = {}
	for _, n in ipairs({ ANA, BEA, CAL, BOB }) do
		local r = rows[n]
		s[#s + 1] = n .. ":" .. (r and r.casts or 0) .. ":" .. (r and r.clicks or 0)
	end
	return table.concat(s, " ")
end

-- Promise: every crew window counts the same split: the same casts and clicks, whatever order and delay the
-- END and HELP messages come in. 'late' in bea's window: the caster's HELP (naming Bob) comes after the END.
-- A window with the messages in order is the reference.
local function agree(step, order)
	local w, ana, bea, cal = team()
	local anaKey = ana.W.myKey
	local function feed(c, kind, ...) c.W.Drive.Apply(kind, anaKey, ...) end
	-- cal: in order
	feed(cal, "CAST", RIDER) w:advance(1)
	feed(cal, "HELP", RIDER, BOB) w:advance(1)
	feed(cal, "END", RIDER, "1") w:advance(1)
	-- bea: the order under test
	feed(bea, "CAST", RIDER) w:advance(1)
	for _, m in ipairs(order) do
		if m == "HELP" then feed(bea, "HELP", RIDER, BOB) else feed(bea, "END", RIDER, "1") end
		w:advance(step)
	end
	eq(mark(bea), mark(cal), "bea (" .. table.concat(order, ",") .. ", step " .. step .. ") and cal agree")
	eq(rowsOf(bea)[BOB] and rowsOf(bea)[BOB].clicks, 1, "Bob's click is counted")
	eq(rowsOf(bea)[ANA] and rowsOf(bea)[ANA].casts, 1, "Ana's cast is counted")
	T.clean(w)
end

for _, step in ipairs(STEPS) do
	test("p242 G H24-12: a named HELP that comes after the END is still counted (step " .. step .. " s)", function()
		agree(step, { "END", "HELP" })
	end)
	-- guard: the old order already worked
	test("p242 G H24-12 guard: HELP then END counts the same (step " .. step .. " s)", function()
		agree(step, { "HELP", "END" })
	end)
end

test("p242 G H24-12: an END that comes after another window already moved the rider on still counts the cast", function()
	for _, step in ipairs(STEPS) do
		local w, ana, bea, cal = team()
		local anaKey = ana.W.myKey
		bea.W.Drive.Apply("CAST", anaKey, RIDER) w:advance(1)
		local c = bea.W.Drive.customers[key(RIDER)]
		ok(c, "bea has a row for the rider")
		bea.W.Drive.SetState(c, "waiting") -- the leader's state arrived first
		w:advance(step)
		bea.W.Drive.Apply("END", anaKey, RIDER, "1")
		w:advance(1)
		eq(rowsOf(bea)[ANA] and rowsOf(bea)[ANA].casts, 1, "the cast is counted (step " .. step .. ")")
		-- twice is still once
		bea.W.Drive.Apply("END", anaKey, RIDER, "1")
		w:advance(1)
		eq(rowsOf(bea)[ANA].casts, 1, "a repeated END is not counted twice")
		T.clean(w)
	end
end)

-- guard: no summon was ever cast: END and HELP count nothing (the condition under which a late one has no job)
test("p242 G H24-12 guard: an END or HELP with no CAST before it counts nothing", function()
	local w, ana, bea = team()
	local anaKey = ana.W.myKey
	bea.W.Drive.Apply("END", anaKey, RIDER, "1")
	bea.W.Drive.Apply("HELP", anaKey, RIDER, BOB)
	w:advance(1)
	eq(mark(bea), ANA .. ":0:0 " .. BEA .. ":0:0 " .. CAL .. ":0:0 " .. BOB .. ":0:0")
	T.clean(w)
end)

-- guard: a HELP long after the END (a new, unrelated moment) is not counted
test("p242 G H24-12 guard: a HELP a minute after the END is not counted", function()
	local w, ana, bea = team()
	local anaKey = ana.W.myKey
	bea.W.Drive.Apply("CAST", anaKey, RIDER) w:advance(1)
	bea.W.Drive.Apply("END", anaKey, RIDER, "1") w:advance(60)
	bea.W.Drive.Apply("HELP", anaKey, RIDER, BOB) w:advance(1)
	eq(rowsOf(bea)[BOB], nil, "no click for Bob")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- H24-13
---------------------------------------------------------------------------
local ANITA = "Anita Lift"
local function driver()
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
	a.W.Drive.SetOpen(true)
	w:addBot(RIDER, { spot = "Orgrimmar" })
	a:chatEvent("CHAT_MSG_WHISPER", "summon pls", RIDER)
	w:advance(3)
	return w, a, a.W.Drive
end

for _, step in ipairs(STEPS) do
	test("p242 G H24-13: a PAID after the rider left the group still counts and shows the amount (step " .. step .. " s)", function()
		local w, a, A = driver()
		local c = A.customers[key(RIDER)]
		ok(c and c.price and c.price > 0, "the rider is listed with a price")
		local price = c.price
		local got = {}
		a.W.Listen("DRIVE_PAID", function(name, copper, tip, from, mine, how, p) got[#got + 1] = { name, copper, p } end)
		w:leave(RIDER)
		w:advance(step)
		eq(A.customers[key(RIDER)], nil, "the row is gone")
		A.Apply("PAID", a.W.myKey, RIDER, tostring(price), "t")
		w:advance(1)
		eq(#got, 1, "DRIVE_PAID fired once")
		eq(got[1] and got[1][1], RIDER, "with the rider's name")
		eq(got[1] and got[1][2], price, "and the amount")
		eq(got[1] and got[1][3], price, "and the fare it was for")
		eq(A.session.rides, 1, "the ride counts")
		eq(A.session.copper, price, "the gold counts")
		T.clean(w)
	end)
end

-- guard: a PAID from somebody who was never on the list is still only a gift (no ride)
test("p242 G H24-13 guard: a PAID for a stranger who never was a rider counts gold, no ride", function()
	local w, a, A = driver()
	A.Apply("PAID", a.W.myKey, "Zed Stranger", "1000", "t")
	w:advance(1)
	eq(A.session.rides, 0, "no ride")
	eq(A.session.copper, 1000, "the gift is counted")
	T.clean(w)
end)

-- guard: a PAID for a rider long gone (10 min) is not matched to the old row
test("p242 G H24-13 guard: a PAID ten minutes after the rider left is a gift, not their ride", function()
	local w, a, A = driver()
	local price = A.customers[key(RIDER)].price
	w:leave(RIDER)
	w:advance(600)
	A.Apply("PAID", a.W.myKey, RIDER, tostring(price), "t")
	w:advance(1)
	eq(A.session.rides, 0, "no ride")
	T.clean(w)
end)

-- guard: a PAID while the rider is still on the list works as before
test("p242 G H24-13 guard: a PAID for a listed rider marks them paid", function()
	local w, a, A = driver()
	local c = A.customers[key(RIDER)]
	A.Apply("PAID", a.W.myKey, RIDER, tostring(c.price), "t")
	w:advance(1)
	eq(c.paid, c.price, "paid in full")
	T.clean(w)
end)
