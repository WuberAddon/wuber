-- Group G, round fga (job 2611): A4 the realm name (research row D16).
-- Measured on build 71037 (since 20 Nov, four accounts): GetRealmName and GetNormalizedRealmName give "" and
-- UnitFullName's second value is the surname. A test that needs a realm gives the world (or a client) one.
-- The founders' hard rule (Core.Base): a founder only on EU-PvE and only W.CREATOR names; a realm the game does not
-- name is no ruleset, so nobody is crowned (REC-02/03 stay open for a character that never saw a named realm).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function make(w, name, opts)
	opts = opts or {}
	local warlock = opts.driver
	return w:addClient(name, { spot = warlock and "Ratchet" or "Orgrimmar", class = warlock and "WARLOCK" or "MAGE",
		money = 100000, realm = opts.realm, allowMissing = not T.HAVE_UI })
end

local function founderRide(wopts, copts)
	local w = T.newWorld(wopts)
	local d = make(w, T.ANITA, { driver = true, realm = copts and copts.realm })
	local r = make(w, T.TESTCHAR, { realm = copts and copts.realm })
	T.settle(w)
	w:group({ T.ANITA, T.TESTCHAR })
	local ride = { id = "AbCdEf", driverKey = T.ANITA:lower(), driver = T.ANITA, state = "portal" }
	return w, d, r, ride
end

test("fga g: a client names no realm by default: GetRealmName and GetNormalizedRealmName give an empty string (build 71037)", function()
	local w = T.newWorld()
	local r = make(w, T.TESTCHAR)
	eq(r.env.GetRealmName(), "", "GetRealmName")
	eq(r.env.GetNormalizedRealmName(), "", "GetNormalizedRealmName")
	T.clean(w)
end)

test("fga g: UnitFullName gives the first name and the surname, not a realm", function()
	local w = T.newWorld()
	local r = make(w, T.TESTCHAR)
	local first, second = r.env.UnitFullName("player")
	local f, s = T.TESTCHAR:match("^(%S+)%s+(.+)$")
	eq(first, f, "the first name")
	eq(second, s, "the surname as the second value")
	ok(second ~= "Forever", "never the old fake 'Forever'")
	T.clean(w)
end)

test("fga g: a world's realm names every client's realm; a client's own realm wins; false gives nil", function()
	local w = T.newWorld({ realm = H.FOUNDER_REALM })
	local a = make(w, T.TESTCHAR)
	local b = make(w, T.ANITA, { realm = "CAMWOW US2 Realm 1 PvP" })
	local c = make(w, T.BOB, { realm = false })
	eq(a.env.GetRealmName(), H.FOUNDER_REALM, "the world's realm")
	eq(a.env.GetNormalizedRealmName(), "CAMWOWEU5Realm5PvE", "normalised: no spaces")
	eq(b.env.GetRealmName(), "CAMWOW US2 Realm 1 PvP", "the client's own")
	eq(c.env.GetRealmName(), nil, "false: nothing")
	eq(c.env.GetNormalizedRealmName(), nil, "false: nothing (normalised)")
	T.clean(w)
end)

-- the hard rule with the measured default: no realm named, nothing remembered, so no founder anywhere
test("fga g: with no realm named nobody is a founder: no ruleset, no crown, a founder's summon stays violet, no seed drivers", function()
	local w, _, r, ride = founderRide()
	eq(r.W.Ruleset(), nil, "no ruleset from an empty realm or a surname")
	eq(r.W.OnFounderRuleset(), false, "not on the founders' ruleset")
	eq(r.W.IsCreator(T.ANITA), false, "the founder's name alone crowns nobody")
	eq(r.W.FounderSummon(ride), false, "the violet portal, not the gold one")
	eq(#r.W.SeedList(), 0, "no seed drivers on an unknown ruleset")
	T.clean(w)
end)

-- a surname that reads like a realm must not make a ruleset (W.Ruleset reads UnitFullName's second value)
test("fga g: a surname is never read as a realm: an ordinary surname gives no ruleset", function()
	local w = T.newWorld()
	local r = make(w, "Pve Eu5")
	local _, second = r.env.UnitFullName("player")
	eq(second, "Eu5", "the surname")
	eq(r.W.RulesetOf(second), nil, "a surname alone names no region and ruleset")
	eq(r.W.Ruleset(), nil, "no ruleset")
	T.clean(w)
end)

-- guard: a world that names the founders' realm crowned the founders before this change too (the old default)
test("fga g: a world naming the founders' EU PvE realm: the founder is crowned and her summon gold", function()
	local w, _, r, ride = founderRide({ realm = H.FOUNDER_REALM })
	eq(r.W.Ruleset(), "EU-PvE", "the founders' ruleset")
	eq(r.W.IsCreator(T.ANITA), true, "crowned")
	eq(r.W.FounderSummon(ride), true, "gold")
	eq(r.W.SeedList()[1], T.ANITA, "the founders first among the seed drivers")
	T.clean(w)
end)

-- guard: another ruleset was never the founders' and still is not
test("fga g: a client on another ruleset (US PvP) never crowns a founder, whatever the world names", function()
	local w, _, r, ride = founderRide({ realm = H.FOUNDER_REALM }, { realm = "CAMWOW US2 Realm 1 PvP" })
	eq(r.W.Ruleset(), "US-PvP", "the client's own realm wins")
	eq(r.W.IsCreator(T.ANITA), false, "no crown")
	eq(r.W.FounderSummon(ride), false, "violet")
	T.clean(w)
end)
