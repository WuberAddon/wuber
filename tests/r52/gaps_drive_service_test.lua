-- Final home: tests/drive/service_test.lua; add it to the per-module list in tests/run.lua.
-- Pins:
--   the contract (W.Drive and the DR settings / caster / advert functions)
--   SetPrice: rounded, clamped up to the lowest fare (and says so), capped at 99999999, junk keeps the old price
--   SetOpen: GO ONLINE opens, a price under the lowest fare is raised, SETTINGS fires only on a change; Close closes
--   SetPaused: saved, IsPaused, SETTINGS "paused"
--   summoners: de-duplicated, only Warlocks count, Add is idempotent, Remove of a stranger is refused
--   MainCaster ("" = me as a Warlock, "-" = whoever clicks); WhoIs short names; SetOpt refuses unknown habits; SetDest cleans
-- Why it matters to a player: these are the driver's own settings. If they broke, a driver could sell below the
-- lowest fare, look open while closed (or the other way round), pause without riders being held, or have the
-- wrong Warlock expected to cast (and the rider told to pay the wrong person).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local ANITA = T.ANITA
local AKEY = "anita lift"

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.service: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("Drive.Service", "tests/drive/service_test.lua", {
		["W.Drive"] = "table",
		["DR.refusals"] = "table", ["DR.adPosted"] = "table",
		["DR.IsOpen"] = "function", ["DR.Selling"] = "function", ["DR.Mode"] = "function", ["DR.RaidOn"] = "function",
		["DR.IsPaused"] = "function", ["DR.SetOpen"] = "function", ["DR.SetPaused"] = "function", ["DR.SetPrice"] = "function",
		["DR.SetDest"] = "function", ["DR.SetService"] = "function", ["DR.SetCaster"] = "function", ["DR.NameOf"] = "function",
		["DR.Summoners"] = "function", ["DR.SetSummoners"] = "function", ["DR.AddSummoner"] = "function",
		["DR.RemoveSummoner"] = "function", ["DR.SetOpt"] = "function", ["DR.CastOrder"] = "function",
		["DR.MainCaster"] = "function", ["DR.CanCast"] = "function", ["DR.MayCast"] = "function", ["DR.NextCaster"] = "function",
		["DR.Payee"] = "function", ["DR.PayeeHasApp"] = "function", ["DR.WhoIs"] = "function", ["DR.TeamShards"] = "function",
		["DR.ShardsChanged"] = "function", ["DR.AdTargets"] = "function", ["DR.NextAd"] = "function",
		["DR.MarkAdvert"] = "function", ["DR.AdvertDue"] = "function", ["DR.AdvertText"] = "function",
		["DR.CheckAdvert"] = "function",
		["Mod.myKey"] = "function", ["Mod.o"] = "function",
	})
	ok(Mod, "W.Mod(\"Drive.Service\")")
	T.clean(w)
end)

-- a Warlock driver (Anita, Ratchet), not yet online
local function setup()
	local w = T.newWorld()
	local d = T.driver(w, ANITA)
	T.settle(w)
	return w, d, d.W.Drive
end

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.service: SetPrice rounds, clamps up to the lowest fare and says so, caps, and ignores junk", function()
	local w, d, DR = setup()
	local MIN = d.W.MIN_PRICE or 5000
	local p, clamped = DR.SetPrice(MIN + 0.4)
	eq(p, MIN, "rounded") eq(clamped, false, "not clamped") -- Service.lua:136
	p, clamped = DR.SetPrice(1)
	eq(p, MIN, "clamped up to the lowest fare") eq(clamped, true, "says so")
	eq(DR.char().price, MIN, "saved")
	p, clamped = DR.SetPrice(1e12)
	eq(p, 99999999, "capped") eq(clamped, false, "a cap is not a clamp")
	p, clamped = DR.SetPrice("lots")
	eq(p, 99999999, "junk: the old price") eq(clamped, false, "junk")
	p = DR.SetPrice(0 / 0)
	eq(p, 99999999, "NaN: the old price")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.service: GO ONLINE opens (raising a too-low price), SETTINGS fires once per change; Close closes", function()
	local w, d, DR = setup()
	local MIN = d.W.MIN_PRICE or 5000
	local fired = 0
	d.W.Listen("SETTINGS", function(what) if what == "drive" then fired = fired + 1 end end)
	DR.char().price = 1
	local okO, why = DR.SetOpen(true)
	eq(okO, true, "opened: " .. tostring(why))
	eq(DR.char().drive, true, "saved: Open is W.Char().drive") -- Service.lua:95
	eq(DR.IsOpen(), true, "open")
	eq(DR.char().price, MIN, "a price under the lowest fare is raised") -- Service.lua:93
	eq(fired, 1, "SETTINGS drive once")
	DR.SetOpen(true)
	eq(fired, 1, "no change, no SETTINGS") -- Service.lua:101
	eq(DR.SetOpen(false), true, "closed")
	eq(DR.IsOpen(), false, "not open")
	eq(fired, 2, "SETTINGS on close")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.service: Pause is saved, IsPaused says so, SETTINGS paused; Resume clears it", function()
	local w, d, DR = setup()
	local fired = 0
	d.W.Listen("SETTINGS", function(what) if what == "paused" then fired = fired + 1 end end)
	eq(DR.SetPaused(true), true, "a driver may pause")
	eq(DR.IsPaused(), true, "paused")
	eq(DR.char().paused, true, "saved")
	eq(DR.SetPaused(false), true, "resume")
	eq(DR.IsPaused(), false, "not paused")
	eq(fired, 2, "SETTINGS paused each time") -- Service.lua:130
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.service: summoners: de-duplicated, only Warlocks count, Add is idempotent, Remove of a stranger is refused", function()
	local w, d, DR = setup()
	eq(DR.SetSummoners({ ANITA, "anita lift", ANITA }), true, "the runner picks")
	eq(#DR.char().summoners, 1, "de-duplicated") -- Service.lua:232
	eq(DR.char().runner, true, "marks this character a runner")
	local s = DR.Summoners()
	eq(#s, 1, "one summoner") eq(s[1], AKEY, "Anita (a Warlock: me)")
	eq(DR.AddSummoner(ANITA), true, "already there: fine")
	eq(#DR.char().summoners, 1, "not doubled") -- Service.lua:259
	eq(DR.SetSummoners({ "Bob Stone" }), true, "a name that is no Warlock of ours")
	eq(#DR.Summoners(), 0, "is not a summoner") -- lockKey, Service.lua:208
	eq(DR.RemoveSummoner("Cal Brown"), false, "not in the list: refused")
	eq(DR.RemoveSummoner("Bob Stone"), true, "removed")
	eq(#DR.char().summoners, 0, "empty")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.service: MainCaster: \"\" is me (a Warlock), \"-\" is whoever clicks; chosen summoners come first", function()
	local w, d, DR = setup()
	DR.SetCaster("")
	eq(DR.MainCaster(), AKEY, "me") -- Service.lua:353
	DR.SetCaster("-")
	eq(DR.MainCaster(), nil, "whoever clicks")
	DR.SetCaster("")
	DR.SetSummoners({ ANITA })
	eq(DR.MainCaster(), AKEY, "the first chosen summoner")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.service: WhoIs gives short names; SetOpt refuses an unknown habit; SetDest cleans the place", function()
	local w, d, DR = setup()
	eq(DR.WhoIs(AKEY), "Anita", "me, short")
	eq(DR.WhoIs("bob stone"), "Bob", "a stranger: the first name, capitalised") -- Service.lua:461
	eq(DR.SetOpt("noSuchHabit", true), nil, "an unknown habit is refused") -- Drive/Core.lua:116
	local dest = DR.SetDest("Ratchet|cffff0000\nRed")
	ok(not dest:find("[|\n]"), "no escape codes or newlines: " .. dest) -- W.Clean, Core/Runtime.lua:325
	ok(#DR.SetDest(string.rep("x", 40)) <= 32, "at most 32 bytes")
	T.clean(w)
end)
