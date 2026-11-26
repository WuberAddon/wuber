-- Flight recorder, lane B1: C_Map answering nothing for a moment (fact selftest.login in
-- tests/fixtures/rec/lab-real-facts.lua). The one real case: "Wuber Rocks 20 Nov 12:46:27 '[login +60 s] 12 of 14
-- passed; failed: Your position on the map (C_Map.GetBestMapForUnit); Distances (time saved, map pins) (C_Map world
-- positions)'". The lines around it show when: not right after the login but at a loading screen 60 s later
-- (PLAYER_MONEY +2g 13 s before, PLAYER_ENTERING_WORLD(false, false) 0.2 s after the check, ZONE_CHANGED_NEW_AREA
-- Thunder Bluff 0.8 s after), so the fact's "after a login" is weaker than its summary: C_Map was blank during a
-- summon's loading screen. The fake game's client option mapBlank = s (from the login) and Client:blankMap(s) (from
-- now) give that blank; neither is the default.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function make(w, blank)
	return w:addClient(T.TESTCHAR, { spot = "Orgrimmar", class = "MAGE", money = 100000, mapBlank = blank, allowMissing = not T.HAVE_UI })
end

local function check(W, name)
	for _, c in ipairs(W.SelfTest()) do if c.name == name then return c.ok end end
	error("no self-test item " .. name)
end

test("rec: real: mapBlank: C_Map.GetBestMapForUnit and GetPlayerMapPosition give nil until it ends (selftest.login)", function()
	local w = T.newWorld()
	local r = make(w, 10)
	local CM = r.env.C_Map
	eq(CM.GetBestMapForUnit("player"), nil, "no map at first")
	eq(CM.GetPlayerMapPosition(1454, "player"), nil, "no position at first")
	w:advance(11)
	eq(CM.GetBestMapForUnit("player"), 1454, "Orgrimmar once it ends")
	ok(CM.GetPlayerMapPosition(1454, "player"), "a position once it ends")
	r:blankMap(2)
	eq(CM.GetBestMapForUnit("player"), nil, "Client:blankMap: blank from now")
	w:advance(2.5)
	eq(CM.GetBestMapForUnit("player"), 1454, "and back")
	local w2 = T.newWorld()
	local r2 = make(w2, nil)
	eq(r2.env.C_Map.GetBestMapForUnit("player"), 1454, "not blank by default")
	T.clean(w)
	T.clean(w2)
end)

-- What Wuber shows then: its self-test fails the same two items as in the game, and passes again when C_Map answers.
test("rec: real: while C_Map is blank Wuber's self-test fails the map and distances, as in the game, then passes (selftest.login)", function()
	local w = T.newWorld()
	local r = make(w, 10)
	w:advance(5)
	eq(check(r.W, "Your position on the map"), false, "the map item fails while blank")
	eq(check(r.W, "Distances (time saved, map pins)"), false, "the distances item too")
	w:advance(6)
	eq(check(r.W, "Your position on the map"), true, "passes once C_Map answers")
	eq(check(r.W, "Distances (time saved, map pins)"), true, "distances too")
	T.clean(w)
end)

-- And Home's map: while blank its place pill says "Azeroth" over no map art (a fallback, not wrong words about the
-- player's place); it comes back by itself, with no zone event, once C_Map answers. In the game the blank sat inside
-- a loading screen, when no window can be seen, so nothing to report as a bug.
test("rec: real: while C_Map is blank Home's map falls back to Azeroth and comes back by itself (selftest.login)", function()
	if not T.HAVE_UI then return end
	local w = T.newWorld()
	local r = make(w, 8)
	w:advance(5)
	r.W.UI.Toggle(true)
	w:advance(1)
	local m = r.W.Mod("UI.Kit").ui.screens.home.map
	eq(m.zone.label:GetText(), "Azeroth", "the fallback place")
	eq(m.artFor, nil, "no map art")
	w:advance(6)
	eq(m.zone.label:GetText(), "Orgrimmar", "the place once C_Map answers")
	eq(m.artFor, 1454, "Orgrimmar's art")
	T.clean(w)
end)
