local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local clean = T.clean
local MIA, BEA, PAT = "Mia Stone", "Bea Jones", "Pat Hill"
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

test("r27 AUD-07: after a plain Warlock's summon fails, the runner's button does not ask her again at once", function()
	local w = T.newWorld()
	local mia = w:addClient(MIA, { spot = SPOT, class = "MAGE",
		saved = { Wuber = saved(MIA, { MIA, BEA }, { runner = true, summoners = { BEA } }, { [BEA] = "lock" }, { [BEA] = false }) } })
	w:addBot(BEA, { spot = SPOT, class = "WARLOCK", shards = 10 })
	w:addBot(PAT, { spot = SPOT, class = "PRIEST" })
	w:group({ MIA, BEA, PAT })
	w:advance(2)
	local DR = DRof(mia)
	ok(DR.SetOpen(true)) w:advance(2)
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	w:botWhisper("Dan Miller", mia, "summon pls") w:advance(4)
	eq(state(mia, "Dan Miller"), "joined")
	eq(plan(mia).title, "Ask Bea to summon Dan", "control: the first call is offered")
	press(mia) w:advance(1)
	w:botCast(BEA, "Dan Miller") w:advance(1)
	eq(state(mia, "Dan Miller"), "summoning", "control: the summon started")
	w:botCastEnd(BEA) w:advance(3)                    -- nobody clicked the portal: the summon ends without arrival
	eq(state(mia, "Dan Miller"), "joined", "the failed summon puts Dan back to joined")
	w:advance(3)
	local p = plan(mia)
	ok(p.title == "Ask Bea to summon Dan",
		"the failed summon is over, but the big button reads '" .. tostring(p.title) .. "' / '" .. tostring(p.sub) .. "' instead of asking Bea again (calledAt "
		.. tostring(customer(mia, "Dan Miller").calledAt) .. " not cleared)")
	clean(w)
end)
