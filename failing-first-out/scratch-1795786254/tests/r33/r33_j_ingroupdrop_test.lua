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

local function setup14()
	local w = T.newWorld()
	local names = { MIA, BEA, PAT }
	local roles = { [BEA] = "lock", [PAT] = "helper" }
	local mia = w:addClient(MIA, { spot = SPOT, class = "MAGE", saved = { Wuber = saved(MIA, names, { runner = true, summoners = { BEA } }, roles) } })
	local bea = w:addClient(BEA, { spot = SPOT, class = "WARLOCK", saved = { Wuber = member(BEA, MIA, names, roles) } })
	local pat = w:addClient(PAT, { spot = SPOT, class = "PRIEST", saved = { Wuber = member(PAT, MIA, names, roles) } })
	w:group(names)
	w:advance(2)
	ok(DRof(mia).SetOpen(true)) w:advance(3)
	return w, mia, bea, pat
end

test("r33 j: AUD-21: a rider already in another group is dropped from the crew's other windows, not left invited",function()
	local w, mia, bea, pat = setup14()
	-- control: a normal rider is invited and joins; both windows agree
	w:addBot("Fay Moon", { spot = "Orgrimmar" })
	w:botWhisper("Fay Moon", mia, "summon pls") w:advance(6)
	eq(state(mia, "Fay Moon"), "joined", "control: Fay joined on the leader's window")
	eq(state(bea, "Fay Moon"), "joined", "control: and on Bea's")
	-- the bug: Dan is in someone else's group, so the invite is refused with "is already in a group"
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	w:addBot("Eve Long", { spot = "Orgrimmar" })
	w:group({ "Dan Miller", "Eve Long" })
	w:botWhisper("Dan Miller", mia, "summon pls") w:advance(10)
	eq(state(mia, "Dan Miller"), "lead", "the leader's window shows Dan as a lead (busy)")
	ok(state(bea, "Dan Miller") ~= "invited", "Bea still lists Dan as invited: " .. tostring(state(bea, "Dan Miller")))
	ok(state(bea, "Dan Miller") == nil, "Bea no longer lists Dan at all")
	clean(w)
end)
