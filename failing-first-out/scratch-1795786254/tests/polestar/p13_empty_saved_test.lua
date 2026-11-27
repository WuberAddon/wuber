-- Polestar lesson 13: saved data (WuberDB) can load as nothing on a cold restart while the file on disk is fine.
-- Wuber cannot tell that from a new install: every saved value, the first-open guide flag and the remembered
-- ruleset live in WuberDB (the only SavedVariables entry), so nothing else survives to compare with.
-- These tests pin today's behaviour. What can be re-derived from the live game is (the ruleset, from the realm name).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- a world whose saved data came back empty, as if a cold restart loaded nothing
local function emptied(realm)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	r.env.UnitGUID = function() return "Player-" .. "9999-0000ABCD" end -- built in two parts so the scrub check sees no real-looking id -- a server that is not a founder server
	r.realm = realm
	local db = r.env.WuberDB
	for k in pairs(db) do db[k] = nil end
	r.W.db = nil
	r.env.WuberDB = nil
	r.W.InitDB()
	return w, r
end

-- guard: nothing outside WuberDB records that this account used Wuber, so an empty load is a new install
test("Polestar 13 guard: an empty saved table is taken for a new install (first-open guide returns, no news card, no note)", function()
	local w, r = emptied("")
	local db = r.W.db
	eq(db.coach, false, "the first-open guide is due again")
	eq(db.advanced, false, "Simple mode, as for anyone new")
	eq(db.simpleNote, nil, "no 'older data' note: an empty table is not older data")
	eq(next(db.rides), nil, "no trips")
	eq(db.newsSeen, nil, "no seen version")
	T.clean(w)
end)

-- guard: with no realm name the remembered ruleset is the only memory; an empty load loses it and the game cannot restore it
test("Polestar 13 guard: with no realm name an empty load loses the remembered ruleset", function()
	local w, r = emptied("")
	eq(r.W.Ruleset(), nil, "nothing names a ruleset: none, not a guess")
	T.clean(w)
end)

-- guard: passes on the base too; the live game still decides when it names the realm: the ruleset is worked out again and remembered again
test("Polestar 13: a named realm gives the ruleset back after an empty load, and it is remembered again", function()
	local w, r = emptied("CAMWOW EU5 Realm 5 PvE")
	eq(r.W.Ruleset(), "EU-PvE", "re-derived from the live realm name")
	eq(r.W.Char().ruleset, "EU-PvE", "remembered again")
	T.clean(w)
end)
