local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local settle = T.settle
local MIA, BEA, PIA = "Mia Stone", "Bea Jones", "Pia Rose"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function memberSaved(me, captain, all)
	local crew = {}
	for _, m in ipairs(all) do
		if m.name ~= me then crew[#crew + 1] = { name = m.name, role = m.role, app = m.app ~= false } end
	end
	return { Wuber = { chars = { [key(me)] = { crew = crew, captain = captain, wizard = true } } } }
end

-- A Mage runs the service from Orgrimmar; the Warlock who summons (Bea) stands in Undercity.
-- The runner never typed a place. A rider in Orgrimmar books the Mage.
test("r32 n2: a runner in one city, its Warlock summoner in another, no typed place: the rider is taken", function()
	local w = T.newWorld()
	local all = { { name = MIA, role = "helper" }, { name = BEA, role = "lock", app = true }, { name = PIA, role = "helper" } }
	local mia = w:addClient(MIA, { spot = "Orgrimmar", class = "MAGE", saved = { Wuber = { chars = { [key(MIA)] = {
		crew = { { name = BEA, role = "lock", app = true }, { name = PIA, role = "helper", app = true } },
		captain = "", wizard = true, runner = true, summoners = { BEA } } } } } })
	local bea = w:addClient(BEA, { spot = "Undercity", class = "WARLOCK", saved = memberSaved(BEA, MIA, all) })
	local pia = w:addClient(PIA, { spot = "Undercity", class = "PRIEST", saved = memberSaved(PIA, MIA, all) })
	w:group({ MIA, BEA, PIA })
	settle(w)
	local DM = mia.W.Drive
	ok(DM.SetOpen(true), "the Mage opens")
	w:advance(3)
	ok(DM.NetDriver(), "control: the Mage's window is on the network")
	local served = DM.ServedPlaces()
	eq(served and served[1], "Undercity", "control: the crew summons in Undercity")
	local dan = T.rider(w, "Dan Miller", { spot = "Orgrimmar" })
	settle(w)
	local d = dan.W.drivers[key(MIA)]
	ok(d, "control: Dan sees the Mage in his list")
	local shown = d and d.dest
	dan.W.RequestRide(key(MIA))
	w:advance(5)
	local c = DM.customers["dan miller"]
	ok(c and c.state ~= "lead", "Dan asked for a summon to '" .. tostring(shown) .. "' (the Mage's own city) but the Mage's window did not take him (row: "
		.. tostring(c and c.state) .. ", rider's ride: " .. tostring(T.rideState and T.rideState(dan)) .. ", served: " .. tostring(served and served[1]) .. ")")
	T.clean(w)
end)

-- control: the same crew, the Mage has typed the place Undercity: the same request is taken
test("r32 n2 control: same crew with the place typed in is taken", function()
	local w = T.newWorld()
	local all = { { name = MIA, role = "helper" }, { name = BEA, role = "lock", app = true }, { name = PIA, role = "helper" } }
	local mia = w:addClient(MIA, { spot = "Orgrimmar", class = "MAGE", saved = { Wuber = { chars = { [key(MIA)] = {
		crew = { { name = BEA, role = "lock", app = true }, { name = PIA, role = "helper", app = true } },
		captain = "", wizard = true, runner = true, summoners = { BEA }, dest = "Undercity" } } } } })
	local bea = w:addClient(BEA, { spot = "Undercity", class = "WARLOCK", saved = memberSaved(BEA, MIA, all) })
	local pia = w:addClient(PIA, { spot = "Undercity", class = "PRIEST", saved = memberSaved(PIA, MIA, all) })
	w:group({ MIA, BEA, PIA })
	settle(w)
	local DM = mia.W.Drive
	ok(DM.SetOpen(true), "the Mage opens")
	w:advance(3)
	local dan = T.rider(w, "Dan Miller", { spot = "Orgrimmar" })
	settle(w)
	dan.W.RequestRide(key(MIA))
	w:advance(5)
	local c = DM.customers["dan miller"]
	ok(c and c.state ~= "lead", "taken with the place typed (row: " .. tostring(c and c.state) .. ")")
	T.clean(w)
end)
