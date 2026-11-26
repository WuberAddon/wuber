-- Flight recorder, lane B1: a client whose realm name the addon cannot read (WoW Forever build 71037, 20-21 Nov
-- 2026). Fact realm.name.empty71037 in tests/fixtures/rec/lab-real-facts.lua: "all 9 logins on 20-21 Nov log
-- realm=?" (the test addon: L.str(GetRealmName()) or "?", so nil, "" or a secret) where the 51 logins before
-- named "CAMWOW EU4 Realm 5 PvE" and the like; Wuber's beacon then carried an empty realm
-- ("Anita Lift 21 Nov 00:05:27 msg> 'D C>7 D~1~Orgrimmar~...~2.3.3-dev~star~0~0~~1'" against 20 Nov 17:59
-- '...~0~0~CAMWOW EU5 Realm 5 PvE~1'), and the summon box of a founder's summon showed the violet portal
-- ("Wuber Rocks 21 Nov 00:06 summon box: ... names Anita Lift, portal violet"; gold on 6 earlier summons).
-- The fake game's client option realm = false is that client (not the default: one build, cause unknown).
-- REC_PENDING=1 in the environment runs the pending tests' bodies as tests (they fail until the bug is fixed).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local pending = os.getenv("REC_PENDING") and function(name, _, fn) return test(name, fn) end or T.pending

local function make(w, name, opts)
	opts = opts or {}
	local warlock = opts.driver
	return w:addClient(name, { spot = opts.spot or (warlock and "Ratchet" or "Orgrimmar"), class = warlock and "WARLOCK" or "MAGE",
		money = 100000, realm = opts.realm, saved = opts.saved, allowMissing = not T.HAVE_UI })
end

local function lastD(w, from)
	local list = T.msgs(w, "D", from)
	return list[#list] and T.fields(list[#list]) or nil
end

test("rec: real: realm = false: GetRealmName and GetNormalizedRealmName give nothing, Wuber's beacon an empty realm (realm.name.empty71037)", function()
	local w = T.newWorld()
	local d = make(w, T.ANITA, { driver = true, realm = false })
	eq(d.env.GetRealmName(), nil, "GetRealmName")
	eq(d.env.GetNormalizedRealmName(), nil, "GetNormalizedRealmName")
	T.settle(w)
	T.goOnline(d)
	w:advance(10)
	local f = lastD(w, T.ANITA)
	ok(f, "a beacon went out")
	eq(f[#f], "1", "listed (the last field)")
	eq(f[#f - 1], "", "the realm field is empty, as in the game")
	-- the same driver on a client that names its realm
	local w2 = T.newWorld({ realm = T.H.FOUNDER_REALM })
	local d2 = make(w2, T.ANITA, { driver = true })
	T.settle(w2)
	T.goOnline(d2)
	w2:advance(10)
	local f2 = lastD(w2, T.ANITA)
	eq(f2 and f2[#f2 - 1], H.FOUNDER_REALM, "named before 20 Nov")
	T.clean(w)
	T.clean(w2)
end)

-- What Wuber knows then: no ruleset at all; its own founder character still counts as a founder on its own screen.
test("rec: real: realm unknown: Wuber knows no ruleset, its own founder character still counts (realm.name.empty71037)", function()
	local w = T.newWorld()
	local r = make(w, T.TESTCHAR, { realm = false })
	local d = make(w, T.ANITA, { driver = true, realm = false })
	T.settle(w)
	eq(r.W.Ruleset(), nil, "no ruleset")
	eq(r.W.OnFounderRuleset(), false, "not known to be on the founders' ruleset")
	eq(d.W.IsCreator(T.ANITA), true, "the founder's own character, on its own screen")
	eq(r.W.db.ruleset, nil, "the saved ruleset (for tools/build-seeds.js) is empty")
	T.clean(w)
end)

-- REC bug: the founder's look goes. With no realm name Wuber cannot tell the ruleset, so on every rider's screen the
-- founders are other people: no gold portal for a founder's summon (seen in the game on 21 Nov), no crown.
local function founderRide(realm)
	local w = T.newWorld()
	local d = make(w, T.ANITA, { driver = true, realm = realm })
	local r = make(w, T.TESTCHAR, { realm = realm })
	T.settle(w)
	w:group({ T.ANITA, T.TESTCHAR })
	local ride = { id = "AbCdEf", driverKey = T.ANITA:lower(), driver = T.ANITA, state = "portal" }
	return w, d, r, ride
end

test("rec: real: a founder's summon is gold when the realm is named (the reference for the pending test below)", function()
	local w, _, r, ride = founderRide(H.FOUNDER_REALM)
	eq(r.W.FounderSummon(ride), true, "gold")
	eq(r.W.IsCreator(T.ANITA), true, "crowned")
	T.clean(w)
end)

pending("rec: real: realm unknown: a founder's summon still shows the gold portal and the crown (REC bug)",
	"REC-02: Wuber/Core/Base.lua:90 W.Ruleset is nil when GetRealmName gives nothing (build 71037); the 2.4.1 Lab census: GetRealmName.len=0, GetNormalizedRealmName.len=0, no other call names the realm (lab-latest.txt 228, 410, 423); left pending on purpose", function()
	local w, _, r, ride = founderRide(false)
	eq(r.W.IsCreator(T.ANITA), true, "the founder is crowned")
	eq(r.W.FounderSummon(ride), true, "the founder's summon is gold")
	T.clean(w)
end)

-- REC bug: the founders stop being seed drivers. A rider with no contacts whispers W.SeedList() at login; with no
-- ruleset the list is empty and the founders are never asked (nor announced to, nor is the community offered).
pending("rec: real: realm unknown: a new rider still has the founders as seed drivers (REC bug)",
	"REC-03: Wuber/Core/Base.lua:135 W.SeedList is {} when W.Ruleset is nil (build 71037); the 2.4.1 Lab census: GetRealmName.len=0, GetNormalizedRealmName.len=0, no other call names the realm (lab-latest.txt 228, 410, 423); left pending on purpose", function()
	local w = T.newWorld()
	local r = make(w, T.TESTCHAR, { realm = false })
	T.settle(w)
	local list = r.W.SeedList()
	eq(list[1], T.ANITA, "the founders first")
	T.clean(w)
end)
