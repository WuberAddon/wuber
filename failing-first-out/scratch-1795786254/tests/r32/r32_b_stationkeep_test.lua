local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local clean, settle = T.clean, T.settle
local ANA, BEA = "Ana Smith", "Bea Jones"
local UCH1, UCH2, OGH1, OGH2 = "Una Helper", "Uli Helper", "Ola Helper", "Oto Helper"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function DRof(c) return c.W.Drive end
local function customer(c, name) return c.W.Drive.customers[key(name)] end
local function runnerSaved(me, crew, extra)
	local ch = { crew = crew, captain = "", wizard = true }
	for k, v in pairs(extra or {}) do ch[k] = v end
	return { Wuber = { chars = { [key(me)] = ch } } }
end
local function memberSaved(me, captain, all)
	local crew = {}
	for _, m in ipairs(all) do
		if m.name ~= me then crew[#crew + 1] = { name = m.name, role = m.role, app = m.app ~= false } end
	end
	return { Wuber = { chars = { [key(me)] = { crew = crew, captain = captain, wizard = true } } } }
end
local function twoStations()
	local w = T.newWorld()
	local all = {
		{ name = ANA, role = "lock" }, { name = BEA, role = "lock" },
		{ name = UCH1, role = "helper" }, { name = UCH2, role = "helper" },
		{ name = OGH1, role = "helper" }, { name = OGH2, role = "helper" },
	}
	local crew = {}
	for i = 2, #all do crew[#crew + 1] = { name = all[i].name, role = all[i].role, app = true } end
	local c = {}
	c.ana = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK", saved = runnerSaved(ANA, crew) })
	c.bea = w:addClient(BEA, { spot = "Orgrimmar", class = "WARLOCK", saved = memberSaved(BEA, ANA, all) })
	c.u1 = w:addClient(UCH1, { spot = "Undercity", class = "PRIEST", saved = memberSaved(UCH1, ANA, all) })
	c.u2 = w:addClient(UCH2, { spot = "Undercity", class = "MAGE", saved = memberSaved(UCH2, ANA, all) })
	c.o1 = w:addClient(OGH1, { spot = "Orgrimmar", class = "PRIEST", saved = memberSaved(OGH1, ANA, all) })
	c.o2 = w:addClient(OGH2, { spot = "Orgrimmar", class = "MAGE", saved = memberSaved(OGH2, ANA, all) })
	w:group({ ANA, BEA, UCH1, UCH2, OGH1, OGH2 })
	settle(w)
	return w, c
end

test("r32 b: AUD-14 a rider who answered 'Where to?' with Orgrimmar is dropped as 'moved' when the driver arrives in Orgrimmar", function()
	local w, c = twoStations()
	local DA = DRof(c.ana)
	ok(DA.SetOpen(true)) w:advance(2)
	w:addBot("Fay Moon", { spot = "Thunder Bluff" })
	w:addBot("Eve Long", { spot = "Thunder Bluff" })
	w:botWhisper("Fay Moon", c.ana, "summon pls") w:advance(5)               -- no place: default station + "Where to?"
	w:botWhisper("Eve Long", c.ana, "summon to orgrimmar pls") w:advance(5)  -- control: named Orgrimmar at once
	w:botWhisper("Fay Moon", c.ana, "orgrimmar please") w:advance(3)         -- the answer
	eq(customer(c.ana, "Fay Moon").station, "Orgrimmar", "Fay routed to Orgrimmar")
	w:move(ANA, "Orgrimmar") w:advance(2)   -- the driver is now where both riders asked to go: one station, Orgrimmar
	w:advance(10)
	ok(customer(c.ana, "Eve Long") ~= nil, "control: Eve (asked Orgrimmar first) stays on the list")
	ok(customer(c.ana, "Fay Moon") ~= nil,
		"Fay answered 'Where to?' with Orgrimmar, the driver is in Orgrimmar now, yet Fay was dropped as 'moved' (forPlace stale = "
		.. tostring(DA.moved["fay moon"] and DA.moved["fay moon"].from) .. ")")
	clean(w)
end)

local function threeStations()
	local w = T.newWorld()
	local all = {
		{ name = ANA, role = "lock" }, { name = BEA, role = "lock" }, { name = "Cal Brown", role = "lock" },
		{ name = UCH1, role = "helper" }, { name = UCH2, role = "helper" },
		{ name = OGH1, role = "helper" }, { name = OGH2, role = "helper" },
	}
	local crew = {}
	for i = 2, #all do crew[#crew + 1] = { name = all[i].name, role = all[i].role, app = true } end
	local c = {}
	c.ana = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK", saved = runnerSaved(ANA, crew) })
	c.bea = w:addClient(BEA, { spot = "Orgrimmar", class = "WARLOCK", saved = memberSaved(BEA, ANA, all) })
	c.cal = w:addClient("Cal Brown", { spot = "Ironforge", class = "WARLOCK", saved = memberSaved("Cal Brown", ANA, all) })
	c.u1 = w:addClient(UCH1, { spot = "Undercity", class = "PRIEST", saved = memberSaved(UCH1, ANA, all) })
	c.u2 = w:addClient(UCH2, { spot = "Undercity", class = "MAGE", saved = memberSaved(UCH2, ANA, all) })
	c.o1 = w:addClient(OGH1, { spot = "Orgrimmar", class = "PRIEST", saved = memberSaved(OGH1, ANA, all) })
	c.o2 = w:addClient(OGH2, { spot = "Orgrimmar", class = "MAGE", saved = memberSaved(OGH2, ANA, all) })
	w:group({ ANA, BEA, "Cal Brown", UCH1, UCH2, OGH1, OGH2 })
	settle(w)
	return w, c
end

test("r32 b: AUD-15 a returning rider whose old station closed is dropped as 'moved' instead of going to an open station", function()
	local w, c = threeStations()
	local DA = DRof(c.ana)
	ok(DA.SetOpen(true)) w:advance(2)
	eq(#DA.Stations(), 3, "three stations")
	for _, n in ipairs{"Fay Moon","Eve Long"} do w:addBot(n, { spot = "Thunder Bluff" }) end
	w:botWhisper("Fay Moon", c.ana, "summon to orgrimmar pls") w:advance(5)
	w:botWhisper("Eve Long", c.ana, "summon to undercity pls") w:advance(5)
	local f, e = customer(c.ana, "Fay Moon"), customer(c.ana, "Eve Long")
	eq(f.station, "Orgrimmar") eq(e.station, "Undercity")
	DA.SetState(f, "done") DA.SetState(e, "done")        -- both rides finished
	ok(DA.SetStation("Orgrimmar", false)) w:advance(2)   -- Orgrimmar closes; Undercity and Ironforge stay open
	ok(DA.MultiStation(), "two stations still open")
	w:botWhisper("Fay Moon", c.ana, "summon pls") w:advance(1)  -- both ask again, naming no place
	w:botWhisper("Eve Long", c.ana, "summon pls") w:advance(11)
	ok(customer(c.ana, "Eve Long") ~= nil, "control: Eve (old station Undercity, still open) stays queued/joined")
	ok(customer(c.ana, "Fay Moon") ~= nil,
		"Fay asked again with no place; her old closed station Orgrimmar was kept, so she was dropped as 'moved' (from "
		.. tostring(DA.moved["fay moon"] and DA.moved["fay moon"].from) .. ") instead of going to an open station")
	clean(w)
end)
