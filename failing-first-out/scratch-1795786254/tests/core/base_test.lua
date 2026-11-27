-- Tests of Core.Base (BRIEF15 agent A): the Pioneer lists and their lookups (W.PIONEERS,
-- W.PioneerKind, W.IsPioneer, W.PioneerNames). Loaded by tests/run.lua with its helper table T.
-- The shipped lists are empty: every test that needs names sets its own fake lists on its own
-- client (a fresh world each time) and puts the shipped table back at the end.
local T = ...
local test, eq, ok, list = T.test, T.eq, T.ok, T.list
local TESTCHAR, BOB, BEA, CAL = T.TESTCHAR, T.BOB, T.BEA, T.CAL

local US = "CAMWOW US2 Realm 1 PvE"

-- the fake lists: EU-PvE has riders Bob (with a realm) and Mia, drivers Cal and Mia (on both);
-- US-PvE has rider Bea and driver Wuber
local function fake()
	return {
		riders = { ["EU-PvE"] = { "Bob Stone-CAMWOW EU5 Realm 5", "Mia Lift" }, ["US-PvE"] = { "Bea Jones" } },
		drivers = { ["EU-PvE"] = { "Cal Brown", "Mia Lift" }, ["US-PvE"] = { "Wuber TestCharacter" } },
	}
end

test("Core.Base contract: the Pioneer lists ship empty, so nobody is a Pioneer and the credits are empty", function()
	local W, w = T.contract("Core.Base", "tests/core/base_test.lua", {
		["W.PIONEERS"] = "table", ["W.PioneerKind"] = "function", ["W.IsPioneer"] = "function",
		["W.PioneerNames"] = "function", ["W.IsCreator"] = "function", ["W.Ruleset"] = "function",
	})
	for _, kind in ipairs({ "riders", "drivers" }) do
		eq(type(W.PIONEERS[kind]), "table", kind)
		for rs, names in pairs(W.PIONEERS[kind]) do eq(#names, 0, kind .. " " .. rs .. " ships empty") end
	end
	for _, n in ipairs({ TESTCHAR, BOB, "Anita Lift", "mia lift" }) do
		eq(W.PioneerKind(n), nil, n)
		eq(W.IsPioneer(n), false, n)
		eq(W.IsPioneer(n, "rider"), false, n .. " rider")
		eq(W.IsPioneer(n, "driver"), false, n .. " driver")
	end
	local names = W.PioneerNames()
	eq(#names.riders + #names.drivers, 0, "no credits")
	T.clean(w)
end)

test("Core.Base: Pioneers come from this ruleset's list (any spelling), a driver wins over a rider, and the credits are short sorted names", function()
	local w = T.newWorld({ realm = T.H.FOUNDER_REALM })
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local W = r.W
	local shipped = W.PIONEERS
	W.PIONEERS = fake()
	eq(W.PioneerKind("Mia Lift"), "driver", "on both lists: driver")
	eq(W.PioneerKind("mia lift"), "driver", "by key")
	eq(W.PioneerKind("Mia-Lift"), "driver", "hyphen spelling")
	eq(W.PioneerKind("Cal Brown-CAMWOW EU4 Realm 2"), "driver", "with a realm")
	eq(W.PioneerKind(BOB), "rider", "the list's realm is dropped")
	eq(W.PioneerKind(BEA), nil, "on another ruleset's list: not here")
	eq(W.PioneerKind("Nobody Here"), nil, "not listed")
	eq(W.PioneerKind(nil), nil, "nil")
	eq(W.PioneerKind(42), nil, "not a name")
	eq(W.IsPioneer("Mia Lift"), true)
	eq(W.IsPioneer("Mia Lift", "rider"), true, "Mia is on the riders' list too")
	eq(W.IsPioneer(CAL, "rider"), false, "Cal only drives")
	eq(W.IsPioneer(CAL, "driver"), true)
	eq(W.IsPioneer(BOB, "driver"), false)
	eq(W.IsPioneer(BOB, "pilot"), false, "an unknown kind")
	local names = W.PioneerNames()
	eq(list(names.drivers), "Cal; Mia", "drivers, short, sorted")
	eq(list(names.riders), "Bob", "riders: Mia is credited once, as a driver")
	-- Wuber is a US driver: on an EU client that is somebody else
	eq(W.PioneerKind(TESTCHAR), nil, "Wuber's own character on an EU client: only the EU list counts, so not here")
	eq(W.IsPioneer(TESTCHAR, "driver"), false, "nor as a driver")
	W.PIONEERS = shipped
	eq(W.PioneerKind("Mia Lift"), nil, "the shipped lists back")
	T.clean(w)
end)

test("Core.Base: on a US client only the US list counts; with no ruleset only my own name does", function()
	local w = T.newWorld()
	local r = T.rider(w, BEA)
	r.realm = US
	T.settle(w)
	local W = r.W
	local shipped = W.PIONEERS
	W.PIONEERS = fake()
	eq(W.PioneerKind(BEA), "rider", "me, on my ruleset's list")
	eq(W.PioneerKind(TESTCHAR), "driver", "Wuber, a US driver")
	eq(W.PioneerKind("Mia Lift"), nil, "an EU name: somebody else here")
	eq(list(W.PioneerNames().drivers), "Wuber")
	eq(list(W.PioneerNames().riders), "Bea")
	r.realm = "Somewhere Odd"
	eq(W.Ruleset(), nil, "a realm name that names no ruleset")
	eq(W.PioneerKind(TESTCHAR), nil, "no ruleset: nobody else")
	eq(W.PioneerKind(BEA), "rider", "but my own character still")
	eq(#W.PioneerNames().drivers + #W.PioneerNames().riders, 0, "no ruleset: no credits")
	W.PIONEERS = shipped
	T.clean(w)
end)

test("Core.Base: saved data or a network field claiming Pioneer gives nothing; only the shipped list does", function()
	local w = T.newWorld()
	local saved = { WuberDB = { PIONEERS = { riders = { ["EU-PvE"] = { TESTCHAR } }, drivers = { ["EU-PvE"] = { TESTCHAR } } },
		pioneer = true, pioneers = { [TESTCHAR:lower()] = "driver" } } }
	local r = T.rider(w, TESTCHAR, { saved = saved })
	T.settle(w)
	local W = r.W
	eq(W.PioneerKind(TESTCHAR), nil, "saved fields are not the list")
	eq(W.IsPioneer(TESTCHAR, "driver"), false)
	-- a beacon with every extra field saying pioneer
	w:inject(CAL, "D~1~Ratchet~1413~500~500~5000~~open~1~0~~2.3.0~pioneer~P~driver~1", "CHANNEL")
	w:advance(0.5)
	eq(W.PioneerKind(CAL), nil, "a beacon's field is not the list")
	eq(#W.PioneerNames().drivers, 0)
	for rs, names in pairs(W.PIONEERS.drivers) do eq(#names, 0, rs .. " still empty") end
	T.clean(w)
end)
