local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local clean = T.clean
local MIA, BEA, PAT = "Mia Frost", "Bea Jones", "Pat Priest"
local SPOT = "Undercity"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function DRof(c) return c.W.Drive end
local function customer(c, name) return c.W.Drive.customers[key(name)] end
local function state(c, name) local x = customer(c, name) return x and x.state or nil end
local function plan(c) return c.W.Drive.Plan() end
local function press(c)
	local b = c.env.WuberDriveButton
	ok(b, "no WuberDriveButton") ok(H.visible(b), "the big button is hidden")
	return c:click(b)
end
local function saved(me, names, extra, roles, apps)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = (roles and roles[n]) or "lock", app = not (apps and apps[n] == false) } end
	end
	local ch = { crew = crew, captain = "", wizard = true }
	for k, v in pairs(extra or {}) do ch[k] = v end
	return { chars = { [key(me)] = ch } }
end

local function member(me, captain, names, roles)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = (roles and roles[n]) or "lock", app = true } end
	end
	return { chars = { [key(me)] = { crew = crew, captain = captain, wizard = true } } }
end
local function setup()
	local w = T.newWorld()
	local names = { MIA, BEA, PAT }
	local roles = { [BEA] = "lock", [PAT] = "helper" }
	local mia = w:addClient(MIA, { spot = SPOT, class = "MAGE", saved = { Wuber = saved(MIA, names, { runner = true, summoners = { BEA } }, roles) } })
	local bea = w:addClient(BEA, { spot = SPOT, class = "WARLOCK", saved = { Wuber = member(BEA, MIA, names, roles) } })
	local pat = w:addClient(PAT, { spot = SPOT, class = "PRIEST", saved = { Wuber = member(PAT, MIA, names, roles) } })
	w:group(names)
	w:advance(2)
	ok(DRof(mia).SetOpen(true)) w:advance(3)
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	w:botWhisper("Dan Miller", mia, "summon pls") w:advance(4)
	press(bea) w:advance(1.5)
	w:clickPortal(mia) w:clickPortal(pat)
	return w, mia, bea, pat
end

local function toArrival(w, bea)
	for i = 1, 40 do
		w:advance(0.5)
		if state(bea, "Dan Miller") == "arrived" then return true end
	end
	return false
end

-- Bea's (or Pat's) window crashes right after Dan lands (nothing saved) and logs in again.
local function relog(w, who, name)
	w:logout(who)
	local names = { MIA, BEA, PAT }
	local roles = { [BEA] = "lock", [PAT] = "helper" }
	name = name or BEA
	local class = name == PAT and "PRIEST" or "WARLOCK"
	local nc = w:addClient(name, { spot = SPOT, class = class, saved = { Wuber = member(name, MIA, names, roles) } })
	eq(nc.W.myKey, key(name), "the window that came back is " .. name .. "'s")
	return nc
end
local function owesPay(c, name)
	for _, p in ipairs(c.W.Drive.Pending()) do
		if p.kind == "pay" and p.c and p.c.name == name then return true end
	end
	return false
end
local function countTrades(c)
	local n = { 0 }
	local real = c.env.InitiateTrade
	c.env.InitiateTrade = function(...) n[1] = n[1] + 1 return real(...) end
	return n
end

test("r29 AUD-12: a control ride: the payee Warlock's window opens the trade with a rider who landed", function()
	local w, mia, bea = setup()
	ok(toArrival(w, bea), "control: Dan arrives")
	w:advance(15)
	eq(w.tradeOpens or 0, 1, "control: Bea's window opens the trade by itself")
	clean(w)
end)

test("r29 AUD-12: a Warlock window that comes back after the rider landed opens the trade with them", function()
	local w, mia, bea = setup()
	ok(toArrival(w, bea), "Dan arrives")
	local nb = relog(w, bea)
	local n = countTrades(nb)
	w:advance(30)
	local c = customer(nb, "Dan Miller")
	eq(c and c.state, "arrived", "Bea's window learned Dan is at the spot")
	ok(c and c.arrivedAt, "Bea's window knows when Dan landed (arrivedAt)")
	eq(n[1], 1, "Bea (the payee) opens the trade with Dan once she knows he landed, but no trade opened (arrivedAt = "
		.. tostring(c and c.arrivedAt) .. ")")
	clean(w)
end)

test("r29 AUD-12: a Warlock window that comes back after the rider landed sends the 25 s pay reminder", function()
	local w, mia, bea = setup()
	ok(toArrival(w, bea), "Dan arrives")
	local nb = relog(w, bea)
	w:advance(10)
	ok(not owesPay(nb, "Dan Miller"), "no pay reminder before 25 s")
	w:advance(20)
	ok(owesPay(nb, "Dan Miller"), "Bea (the caster) owes Dan the pay reminder 25 s after her window learned he landed")
	clean(w)
end)

test("r29 AUD-12: a window that comes back never sends a second pay reminder", function()
	local w, mia, bea = setup()
	ok(toArrival(w, bea), "Dan arrives")
	-- Bea's first window reminded Dan (MarkSent), the crew knows it (ST flag r)
	customer(bea, "Dan Miller").reminded = true
	customer(mia, "Dan Miller").reminded = true
	local nb = relog(w, bea)
	w:advance(40)
	local c = customer(nb, "Dan Miller")
	eq(c and c.state, "arrived", "Bea's window learned Dan is at the spot")
	ok(c and c.reminded, "the reminder already sent is known")
	ok(not owesPay(nb, "Dan Miller"), "no second pay reminder")
	clean(w)
end)

test("r29 AUD-12: a window that comes back neither reminds nor trades a rider who paid", function()
	local w, mia, bea = setup()
	ok(toArrival(w, bea), "Dan arrives")
	mia.W.Drive.MarkPaid(customer(mia, "Dan Miller"))
	w:advance(1)
	eq(state(mia, "Dan Miller"), "paid", "Dan paid (marked by hand)")
	local nb = relog(w, bea)
	local n = countTrades(nb)
	w:advance(40)
	eq(state(nb, "Dan Miller"), "paid", "Bea's window learned Dan paid")
	ok(not owesPay(nb, "Dan Miller"), "no pay reminder for a rider who paid")
	eq(n[1], 0, "no trade with a rider who paid")
	clean(w)
end)

test("r29 AUD-12: a helper window that comes back after the rider landed neither trades nor reminds", function()
	local w, mia, bea, pat = setup()
	ok(toArrival(w, bea), "Dan arrives")
	local np = relog(w, pat, PAT)
	local n = countTrades(np)
	w:advance(40)
	local c = customer(np, "Dan Miller")
	eq(c and c.state, "arrived", "Pat's window learned Dan is at the spot")
	eq(n[1], 0, "Pat (not the payee) opens no trade")
	ok(not owesPay(np, "Dan Miller"), "Pat (not the caster) sends no pay reminder")
	clean(w)
end)
