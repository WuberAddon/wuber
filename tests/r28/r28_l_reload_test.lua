local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANA, BEA, DAN, EVE, FAY = "Ana Smith", "Bea Lock", "Dan Miller", "Eve Stone", "Fay Brook"
local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end

-- crew facts travel on the WUBERT prefix: DROP~1~<rider> tells every crew window to forget that rider
local function drops(w, from)
	local out = {}
	for i = (from or 0) + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.prefix == "WUBERT" and e.result == 0 and e.text:match("^DROP~") then out[#out + 1] = e.text end
	end
	return out
end

local function saved(me, captain, crew)
	return { Wuber = { chars = { [key(me)] = { crew = crew, captain = captain, wizard = true } } } }
end

-- the rows as a window sees them: order (by rank), state and price
local function rows(DR, names)
	local out = {}
	for _, n in ipairs(names) do
		local c = DR.customers[key(n)]
		out[#out + 1] = c and { state = c.state, price = c.price, order = c.order, cameWith = c.cameWith } or false
	end
	return out
end

test("r28 AUD-49: an open driver who reloads with two riders in the group does not tell the crew to drop the second", function()
	local w = H.NewWorld({})
	local a = w:addClient(ANA, { spot = "Ratchet", class = "WARLOCK", shards = 10 })
	w:addBot(DAN, { spot = "Ratchet", acceptsInvites = true })
	w:addBot(EVE, { spot = "Ratchet", acceptsInvites = true })
	w:advance(15)
	local DR = a.W.Drive
	ok(DR.SetOpen(true), "open")
	w:advance(3)
	w:botWhisper(DAN, a, "summon pls")
	w:botWhisper(EVE, a, "summon pls")
	w:advance(20)
	ok(DR.customers[key(DAN)] and DR.customers[key(EVE)], "both riders are listed")
	eq(#drops(w), 0, "control: no DROP was sent while the riders were invited and joined normally")
	a = w:reload(a)
	w:advance(5)
	local d = drops(w)
	eq(#d, 0, "after the /reload the leader told the crew: " .. table.concat(d, " ; ") .. " (the crew windows would erase that rider and ignore them mid-ride)")
	T.clean(w)
end)

test("r28 AUD-49: after the leader's /reload both riders keep their order, state and price on the leader's and the crew's window", function()
	local w = H.NewWorld({})
	local a = w:addClient(ANA, { spot = "Ratchet", class = "WARLOCK", shards = 10,
		saved = saved(ANA, "", { { name = BEA, role = "lock", app = true } }) })
	local b = w:addClient(BEA, { spot = "Ratchet", class = "WARLOCK", shards = 10,
		saved = saved(BEA, ANA, { { name = ANA, role = "lock", app = true } }) })
	w:group({ ANA, BEA })
	w:addBot(DAN, { spot = "Ratchet", acceptsInvites = true })
	w:addBot(EVE, { spot = "Ratchet", acceptsInvites = true })
	w:advance(15)
	ok(a.W.Drive.SetOpen(true), "open")
	w:advance(3)
	w:botWhisper(DAN, a, "summon pls")
	w:advance(3)
	w:botWhisper(EVE, a, "summon pls")
	w:advance(20)
	local names = { DAN, EVE }
	local la, lb = rows(a.W.Drive, names), rows(b.W.Drive, names)
	ok(la[1] and la[2], "control: both riders on the leader's window")
	ok(lb[1] and lb[2], "control: both riders on the crew window")
	ok(la[1].order < la[2].order, "control: Dan came first")
	local mark = #w.addonLog
	a = w:reload(a)
	w:advance(5)
	local d = drops(w, mark)
	eq(#d, 0, "no DROP after the /reload: " .. table.concat(d, " ; "))
	local na, nb = rows(a.W.Drive, names), rows(b.W.Drive, names)
	for i, n in ipairs(names) do
		ok(na[i], n .. " is still on the leader's window")
		ok(nb[i], n .. " is still on the crew window")
		eq(na[i] and na[i].state, la[i].state, n .. "'s state on the leader's window")
		eq(na[i] and na[i].price, la[i].price, n .. "'s price on the leader's window")
		eq(na[i] and na[i].cameWith, nil, n .. " is a rider, not 'came with', on the leader's window")
		eq(nb[i] and nb[i].state, lb[i].state, n .. "'s state on the crew window")
		eq(nb[i] and nb[i].price, lb[i].price, n .. "'s price on the crew window")
		ok(not b.W.Drive.ignored[key(n)], n .. " is not ignored on the crew window")
	end
	ok(na[1] and na[2] and na[1].order < na[2].order, "Dan still comes before Eve on the leader's window")
	ok(nb[1] and nb[2] and nb[1].order < nb[2].order, "Dan still comes before Eve on the crew window")
	T.clean(w)
end)

test("r28 AUD-49: a friend who came with a rider is still a 'came with' row after the leader's /reload", function()
	local w = H.NewWorld({})
	local a = w:addClient(ANA, { spot = "Ratchet", class = "WARLOCK", shards = 10 })
	w:addBot(DAN, { spot = "Orgrimmar", acceptsInvites = true })
	w:addBot(FAY, { spot = "Orgrimmar" })
	w:advance(15)
	local DR = a.W.Drive
	ok(DR.SetOpen(true), "open")
	w:advance(3)
	w:botWhisper(DAN, a, "summon pls")
	w:advance(10)
	eq(DR.customers[key(DAN)] and DR.customers[key(DAN)].state, "joined", "control: Dan joined")
	w:join(a.player, w:player(FAY))
	w:advance(3)
	local f = DR.customers[key(FAY)]
	eq(f and f.cameWith, DAN, "control: Fay came with Dan")
	a = w:reload(a)
	w:advance(5)
	DR = a.W.Drive
	eq(DR.customers[key(DAN)] and DR.customers[key(DAN)].state, "joined", "Dan is still a joined rider")
	f = DR.customers[key(FAY)]
	eq(f and f.cameWith, DAN, "Fay is still a 'came with' row, not a rider")
	T.clean(w)
end)
