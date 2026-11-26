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

local function member(me, captain, names, roles)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = (roles and roles[n]) or "lock", app = true } end
	end
	return { chars = { [key(me)] = { crew = crew, captain = captain, wizard = true } } }
end
test("r27 AUD-06: the Warlock's window says the Mage runner who leads cannot invite, though the runner invites riders", function()
	local w = T.newWorld()
	local mia = w:addClient(MIA, { spot = SPOT, class = "MAGE",
		saved = { Wuber = saved(MIA, { MIA, BEA }, { runner = true, summoners = { BEA } }, { [BEA] = "lock" }) } })
	local bea = w:addClient(BEA, { spot = SPOT, class = "WARLOCK", saved = { Wuber = member(BEA, MIA, { MIA, BEA }, { [MIA] = "helper", [BEA] = "lock" }) } })
	w:group({ MIA, BEA })
	w:advance(10)
	local DM, DB = DRof(mia), DRof(bea)
	ok(DM.IsLeader() and not DB.IsLeader(), "Mia leads")
	ok(DM.SetOpen(true)) w:advance(5)
	-- control: the runner really does invite a rider who whispers
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	w:botWhisper("Dan Miller", mia, "summon pls") w:advance(4)
	ok(customer(mia, "Dan Miller") and customer(mia, "Dan Miller").state ~= "lead", "control: Mia's window invited Dan (state "
		.. tostring(customer(mia, "Dan Miller") and customer(mia, "Dan Miller").state) .. ")")
	local warn
	for _, l in ipairs(DB.Readiness()) do if l.ok == false then warn = l.text or l[2] end end
	ok(DB.CanInvite() and DB.Ready(),
		"Bea's checklist warns '" .. tostring(warn) .. "' although the runner leads and invites (CanInvite " .. tostring(DB.CanInvite()) .. ", Ready " .. tostring(DB.Ready()) .. ")")
	clean(w)
end)
