local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- r53 C (bug 2): build 71037 names no realm; the player's GUID server id says EU-PvE for the founders' servers.
local function client(w, name, opts)
	opts = opts or {}
	local c = w:addClient(name, { spot = opts.driver and "Ratchet" or "Orgrimmar", class = opts.driver and "WARLOCK" or "MAGE",
		money = 100000, realm = opts.realm, allowMissing = not T.HAVE_UI })
	if opts.server then
		local old = c.env.UnitGUID
		c.env.UnitGUID = function(unit)
			local g = old(unit)
			if unit == "player" and type(g) == "string" then return "Player-" .. opts.server .. "-0A1B2C3D" end
			return g
		end
	end
	return c
end

-- Promise: a client whose game names no realm, on a founders' server, is on EU-PvE.
test("r53 c: no realm named, GUID on a founders' server (6947): EU-PvE, founders crowned, remembered", function()
	local w = T.newWorld()
	local d = client(w, T.ANITA, { driver = true, realm = false, server = 6947 })
	local r = client(w, T.TESTCHAR, { realm = false, server = 6947 })
	T.settle(w)
	eq(r.W.Ruleset(), "EU-PvE", "ruleset from the GUID")
	eq(r.W.OnFounderRuleset(), true, "on the founders' ruleset")
	eq(r.W.IsCreator(T.ANITA), true, "the other founder is crowned")
	eq(r.W.db.chars[r.W.myKey].ruleset, "EU-PvE", "remembered")
	T.clean(w)
end)

test("r53 c: every listed server id gives EU-PvE; unlisted ids, odd GUIDs and no UnitGUID give nothing", function()
	local w = T.newWorld()
	local r = client(w, T.TESTCHAR, { realm = false })
	T.settle(w)
	for id in pairs(r.W.FOUNDER_SERVERS) do
		r.W.db.chars[r.W.myKey].ruleset = nil
		r.env.UnitGUID = function() return "Player-" .. id .. "-00FF" end
		eq(r.W.Ruleset(), "EU-PvE", "server " .. id)
	end
	for _, g in ipairs({ "Player-6000-0A1B", "Player-6947", "Creature-0-6947-0-0-1-0", "garbage", "Player-6947-ZZ" }) do
		r.W.db.chars[r.W.myKey].ruleset = nil
		r.env.UnitGUID = function() return g end
		eq(r.W.Ruleset(), nil, "guid " .. g)
	end
	r.W.db.chars[r.W.myKey].ruleset = nil
	r.env.UnitGUID = function() return nil end
	eq(r.W.Ruleset(), nil, "no GUID")
	T.clean(w)
end)

-- guard: a named realm always wins over a listed GUID
test("r53 c: a named PvP realm with a listed GUID is EU-PvP, not the founders'", function()
	local w = T.newWorld()
	local r = client(w, T.TESTCHAR, { server = 6947 })
	r.env.GetRealmName = function() return "CAMWOW EU4 Realm 7 PvP" end
	T.settle(w)
	eq(r.W.Ruleset(), "EU-PvP", "named wins")
	eq(r.W.OnFounderRuleset(), false, "not the founders'")
	T.clean(w)
end)

-- guard: an unlisted server gives no founder status (the lock; passes on the base too)
test("r53 c: unknown server id: no ruleset, no founder crown on the other founder", function()
	local w = T.newWorld()
	local r = client(w, T.TESTCHAR, { realm = false, server = 7001 })
	T.settle(w)
	eq(r.W.Ruleset(), nil, "nothing assumed")
	eq(r.W.IsCreator(T.ANITA), false, "not crowned")
	T.clean(w)
end)

test("r53 c: end to end, the driver card shows the Founder badge for Anita Lift when the rider's GUID is on 6947", function()
	local w = T.newWorld()
	local d = client(w, T.ANITA, { driver = true, realm = false, server = 6947 })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar", realm = false })
	local old = r.env.UnitGUID
	r.env.UnitGUID = function(u) if u == "player" then return ("Player-%d-%s"):format(6947, "0A1B2C3D") end return old(u) end
	T.settle(w)
	T.goOnline(d)
	w:advance(10)
	local UI = r.W.UI
	UI.Toggle(true)
	w:advance(3)
	UI.Refresh(true)
	w:advance(2)
	local dr = UI.Driver(T.ANITA:lower())
	ok(dr, "the driver is listed")
	eq(dr and dr.creator, true, "d.creator")
	local card = UI.state.cards[T.ANITA:lower()]
	ok(card and card.royal and card.royal.chip:IsShown(), "the Founder badge shows on the card")
	T.clean(w)
end)
