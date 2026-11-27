-- Round 28, group A: REC-02 and REC-03 (build 71037 gives Wuber no realm name). Wuber remembers, per character,
-- the ruleset the GAME named on an earlier login, and uses it only while the game names no realm at all.
-- Helpers copied from tests/rec/real_realm_test.lua (that folder belongs to another job).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function make(w, name, opts)
	opts = opts or {}
	local warlock = opts.driver
	return w:addClient(name, { spot = opts.spot or (warlock and "Ratchet" or "Orgrimmar"), class = warlock and "WARLOCK" or "MAGE",
		money = 100000, realm = opts.realm, saved = opts.saved, allowMissing = not T.HAVE_UI })
end

-- one earlier login of each character on a realm the game named (nil: the founders' EU PvE realm, H.FOUNDER_REALM); their saved data
local function earlierLogin(names, realm)
	local w = T.newWorld()
	local cs = {}
	for i, n in ipairs(names) do cs[i] = make(w, n, { driver = n == T.ANITA, realm = realm or T.H.FOUNDER_REALM }) end
	T.settle(w)
	local out = {}
	for i, n in ipairs(names) do out[n] = rawget(cs[i].env, "WuberDB") end
	T.clean(w)
	return out
end

local function founderRide(realm, saved)
	local w = T.newWorld()
	local d = make(w, T.ANITA, { driver = true, realm = realm, saved = saved and { Wuber = saved[T.ANITA] } })
	local r = make(w, T.TESTCHAR, { realm = realm, saved = saved and { Wuber = saved[T.TESTCHAR] } })
	T.settle(w)
	w:group({ T.ANITA, T.TESTCHAR })
	local ride = { id = "AbCdEf", driverKey = T.ANITA:lower(), driver = T.ANITA, state = "portal" }
	return w, d, r, ride
end

test("r28 REC-02: realm unknown after an earlier named login: a founder's summon is gold and the founder crowned", function()
	local saved = earlierLogin({ T.ANITA, T.TESTCHAR })
	eq(saved[T.TESTCHAR].chars[T.TESTCHAR:lower()].ruleset, "EU-PvE", "the rider's character remembered the ruleset the game named")
	local w, _, r, ride = founderRide(false, saved)
	eq(r.env.GetRealmName(), nil, "the game names no realm now")
	eq(r.W.Ruleset(), "EU-PvE", "the remembered ruleset")
	eq(r.W.IsCreator(T.ANITA), true, "the founder is crowned")
	eq(r.W.FounderSummon(ride), true, "the founder's summon is gold")
	T.clean(w)
end)

test("r28 REC-03: realm unknown after an earlier named login: the rider still has the founders as seed drivers", function()
	local saved = earlierLogin({ T.TESTCHAR })
	local w = T.newWorld()
	local r = make(w, T.TESTCHAR, { realm = false, saved = { Wuber = saved[T.TESTCHAR] } })
	T.settle(w)
	local list = r.W.SeedList()
	eq(list[1], T.ANITA, "the founders first")
	eq(r.W.db.ruleset, "EU-PvE", "the account's last-login ruleset (tools/build-seeds.js) is the remembered one, not cleared")
	T.clean(w)
end)

test("r28 REC-02: a named realm of another ruleset always wins over a remembered founders' ruleset, and replaces it", function()
	local saved = earlierLogin({ T.TESTCHAR })
	local w = T.newWorld()
	local r = make(w, T.TESTCHAR, { realm = "CAMWOW US2 Realm 1 PvP", saved = { Wuber = saved[T.TESTCHAR] } })
	T.settle(w)
	eq(r.W.Ruleset(), "US-PvP", "the realm the game names now")
	eq(r.W.OnFounderRuleset(), false, "not the founders' ruleset")
	eq(r.W.IsCreator(T.ANITA), false, "another player's founder name is not crowned")
	eq(#r.W.SeedList(), 0, "no founders as seed drivers")
	eq(r.W.db.chars[T.TESTCHAR:lower()].ruleset, "US-PvP", "the memory now holds the named ruleset")
	-- the realm goes quiet again: the newer memory is the one used
	r.realm = false
	eq(r.W.Ruleset(), "US-PvP", "still US-PvP")
	-- a named realm whose name gives no ruleset: named, so the memory is not used
	r.realm = "Somewhere Odd"
	eq(r.W.Ruleset(), nil, "a named realm that names no ruleset: unknown")
	T.clean(w)
end)

test("r28 REC-02: nothing remembered and no realm name: the ruleset stays unknown (a new install on build 71037)", function()
	local w = T.newWorld()
	local r = make(w, T.TESTCHAR, { realm = false })
	T.settle(w)
	eq(r.W.Ruleset(), nil, "no ruleset")
	eq(r.W.IsCreator(T.ANITA), false, "nobody else is crowned")
	eq(#r.W.SeedList(), 0, "no seed drivers")
	eq(r.W.db.chars[T.TESTCHAR:lower()] and r.W.db.chars[T.TESTCHAR:lower()].ruleset, nil, "nothing remembered")
	T.clean(w)
end)

test("r28 REC-02: only a ruleset the game could name is used: an edited memory of another shape counts for nothing", function()
	local w = T.newWorld()
	local r = make(w, T.TESTCHAR, { realm = false, saved = { Wuber = { chars = { [T.TESTCHAR:lower()] = { ruleset = "eu-pve founder" } } } } })
	T.settle(w)
	eq(r.W.Ruleset(), nil, "not a ruleset")
	-- another character's memory is not mine
	local w2 = T.newWorld()
	local r2 = make(w2, T.TESTCHAR, { realm = false, saved = { Wuber = { chars = { ["mia lift"] = { ruleset = "EU-PvE" } } } } })
	T.settle(w2)
	eq(r2.W.Ruleset(), nil, "another character's memory")
	T.clean(w)
	T.clean(w2)
end)
