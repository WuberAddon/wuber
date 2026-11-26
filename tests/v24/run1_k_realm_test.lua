-- In-game run 1, group k: REC-02 and REC-03. Build 71037 gives GetRealmName() "" (nil in the fake); the realm part of
-- UnitFullName("player") is the other place the game may name it. It is used only when it reads as a real realm
-- name (region and ruleset in it): never assumed, so the founder status stays locked to EU-PvE.
local T = ...
local test, eq = T.test, T.eq

local function make(w, name, opts)
	opts = opts or {}
	return w:addClient(name, { spot = opts.driver and "Ratchet" or "Orgrimmar", class = opts.driver and "WARLOCK" or "MAGE",
		money = 100000, realm = false, allowMissing = not T.HAVE_UI })
end

-- the player's own UnitFullName gives this realm part (the fake's gives "Forever")
local function fullNameRealm(c, realm)
	local old = c.env.UnitFullName
	c.env.UnitFullName = function(unit, ...)
		local a, b = old(unit, ...)
		if unit == "player" then return a, realm end
		return a, b
	end
end

test("run1 k: no GetRealmName, UnitFullName names the EU PvE realm: the ruleset is found, the founder crowned, the seeds listed", function()
	local w = T.newWorld()
	local d = make(w, T.ANITA, { driver = true })
	local r = make(w, T.TESTCHAR)
	fullNameRealm(d, "CAMWOWEU5Realm5PvE")
	fullNameRealm(r, "CAMWOWEU5Realm5PvE")
	T.settle(w)
	w:group({ T.ANITA, T.TESTCHAR })
	eq(r.env.GetRealmName(), nil, "the game names no realm")
	eq(r.W.Ruleset(), "EU-PvE", "from the full name")
	eq(r.W.IsCreator(T.ANITA), true, "crowned")
	eq(r.W.FounderSummon({ id = "AbCdEf", driverKey = T.ANITA:lower(), driver = T.ANITA, state = "portal" }), true, "gold")
	eq(r.W.SeedList()[1], T.ANITA, "the founders first")
	T.clean(w)
end)

test("run1 k: UnitFullName gives no realm Wuber can read (empty, a bare 'Forever'): the ruleset stays unknown, nothing assumed", function()
	for _, realm in ipairs({ "", "Forever", false }) do
		local w = T.newWorld()
		local r = make(w, T.TESTCHAR)
		if realm ~= false then fullNameRealm(r, realm) end
		T.settle(w)
		eq(r.W.Ruleset(), nil, "ruleset for " .. tostring(realm))
		eq(r.W.OnFounderRuleset(), false, "not on the founders' ruleset")
		T.clean(w)
	end
end)

test("run1 k: another ruleset in UnitFullName is read as that ruleset (a PvP realm is not the founders')", function()
	local w = T.newWorld()
	local r = make(w, T.TESTCHAR)
	fullNameRealm(r, "CAMWOWEU4Realm7PvP")
	T.settle(w)
	eq(r.W.Ruleset(), "EU-PvP", "ruleset")
	eq(r.W.OnFounderRuleset(), false, "not the founders'")
	T.clean(w)
end)
