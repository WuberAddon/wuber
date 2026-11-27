local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local SPOT = "Undercity"
local MIA, BEA, CAL = "Mia Stone", "Bea Jones", "Cal Brown"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

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

-- Mia (a Mage) runs the service; Bea is the ticked summoner; Cal is another crew Warlock, NOT ticked.
local function crew(caster)
	local w = T.newWorld()
	local all = { { name = MIA, role = "helper" }, { name = BEA, role = "lock" }, { name = CAL, role = "lock" } }
	local mia = w:addClient(MIA, { spot = SPOT, class = "MAGE", saved = runnerSaved(MIA,
		{ { name = BEA, role = "lock", app = true }, { name = CAL, role = "lock", app = true } },
		{ runner = true, summoners = { BEA }, caster = caster }) })
	local bea = w:addClient(BEA, { spot = SPOT, class = "WARLOCK", saved = memberSaved(BEA, MIA, all) })
	local cal = w:addClient(CAL, { spot = SPOT, class = "WARLOCK", saved = memberSaved(CAL, MIA, all) })
	w:group({ MIA, BEA, CAL })
	T.settle(w)
	return w, mia, bea, cal
end

test("r32 j: control, with a main caster set, an unticked crew Warlock does not get the Summon button", function()
	local w, mia, bea, cal = crew("")
	ok(bea.W.Drive.MayCast(), "Bea, the ticked summoner, casts")
	local may, turn = cal.W.Drive.MayCast()
	ok(not may, "Cal (not ticked) should wait for Bea")
	eq(turn, key(BEA))
	T.clean(w)
end)

test("r32 j: with Whoever clicks first on, an unticked crew Warlock waits for the ticked summoner", function()
	local w, mia, bea, cal = crew("-")
	ok(bea.W.Drive.MayCast(), "Bea, the ticked summoner, may cast")
	local may, turn = cal.W.Drive.MayCast()
	ok(not may, "Cal's window says he casts the next summon (his big button reads Summon, not the portal) although only Bea is ticked as summoner; the wizard says 'Any ticked Warlock casts' (caster = " .. tostring(cal.W.Char().caster) .. ", turn = " .. tostring(turn) .. ")")
	T.clean(w)
end)
