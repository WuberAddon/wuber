-- #22 (HUNT-R53-1): net.founder_first must run on the founders' ruleset (EU-PvE), where the founder
-- is listed first at equal price; outside EU-PvE the founder lock applies and alphabetical order holds.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local Hunt

test("issue 22: hunt promise net.founder_first runs on EU-PvE and puts the founder first at equal price", function()
	if not Hunt then
		Hunt = dofile(T.dir .. "/hunt/lib.lua")
		Hunt.init({})
	end
	local p = Hunt.promises["net.founder_first"]
	ok(p, "no promise net.founder_first")
	local okc, res = pcall(Hunt.runPromise, p, {}, 1, { always = false })
	assert(okc, res)
	eq(res.status, "pass", tostring(res.seen or res.detail or res.status))
end)

test("issue 22: on EU-PvE (named realm or founder server GUID) the founder comes first at equal price", function()
	local function checkOrder(w, r)
		local d1 = T.driver(w, T.ANITA, { spot = "Orgrimmar", realm = w.realm })
		local d2 = T.driver(w, "Abe Cross", { spot = "Orgrimmar", realm = w.realm })
		d1.W.Char().price = 5000
		d2.W.Char().price = 5000
		T.settle(w)
		T.goOnline(d1)
		T.goOnline(d2)
		w:advance(10)
		local netList = r.W.DriversSorted()
		local ia, ib
		for i, d in ipairs(netList) do
			if d.key == "anita lift" then ia = i end
			if d.key == "abe cross" then ib = i end
		end
		ok(ia and ib, "both drivers heard")
		ok(ia < ib, "W.DriversSorted puts founder before Abe Cross at equal price")
		if T.HAVE_UI then
			local uiList = r.W.UI.Drivers()
			local ua, ub
			for i, d in ipairs(uiList) do
				if d.key == "anita lift" then ua = i end
				if d.key == "abe cross" then ub = i end
			end
			ok(ua and ub, "both drivers in UI.Drivers")
			ok(ua < ub, "UI.Drivers puts founder before Abe Cross at equal price")
		end
	end

	-- 1. Named EU-PvE realm
	local w1 = T.newWorld({ realm = T.H.FOUNDER_REALM })
	local r1 = T.rider(w1, T.TESTCHAR, { spot = "Orgrimmar" })
	checkOrder(w1, r1)
	T.clean(w1)

	-- 2. Build 71037 empty realm with a founder server GUID (6947)
	local w2 = T.newWorld()
	local r2 = T.rider(w2, T.TESTCHAR, { spot = "Orgrimmar", realm = false })
	local oldGuid = r2.env.UnitGUID
	r2.env.UnitGUID = function(u)
		if u == "player" then return ("Player-%d-%s"):format(6947, "0A1B2C3D") end
		return oldGuid(u)
	end
	checkOrder(w2, r2)
	T.clean(w2)
end)

-- guard: outside EU-PvE, founder status is locked off and alphabetical order holds at equal price
test("issue 22 guard: outside EU-PvE, a player named Anita Lift gets no priority over Abe Cross", function()
	local w = T.newWorld({ realm = "CAMWOW US2 Realm 1 PvP" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	local d1 = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local d2 = T.driver(w, "Abe Cross", { spot = "Orgrimmar" })
	d1.W.Char().price = 5000
	d2.W.Char().price = 5000
	T.settle(w)
	T.goOnline(d1)
	T.goOnline(d2)
	w:advance(10)
	eq(r.W.OnFounderRuleset(), false, "not on founders' ruleset")
	local netList = r.W.DriversSorted()
	local ia, ib
	for i, d in ipairs(netList) do
		if d.key == "anita lift" then ia = i end
		if d.key == "abe cross" then ib = i end
	end
	ok(ia and ib, "both drivers heard")
	ok(ib < ia, "outside EU-PvE, Abe Cross sorts before Anita Lift alphabetically")
	T.clean(w)
end)
