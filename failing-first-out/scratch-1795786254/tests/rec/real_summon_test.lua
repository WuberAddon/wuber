-- Conformance (the flight recorder, lane B2): a summon's arrival in the fake game against the real client
-- (fact summon.arrival.pew; the test addon's "ev" and "probe" lines, 18-21 Nov 2026).
--
-- The 14 accepted summons of the recording (ConfirmSummon called -> what came after), verbatim pairs:
--   near, no PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA only:
--     Durotar -> Orgrimmar         +0.86, +0.85 (one summon, two calls), +0.32, +0.33 s
--     Tirisfal Glades -> Undercity +0.62, +0.66, +0.70 s          (and one from an unknown zone: +0.93 s)
--   far, PLAYER_ENTERING_WORLD(false, false), then ZONE_CHANGED_NEW_AREA:
--     Thunder Bluff -> Undercity   PEW +3.92, +3.89, +4.01 s; zone +0.24 to +0.76 s after the PEW
--     Thunder Bluff -> Orgrimmar   PEW +3.25, +2.40, +2.80 s; zone +0.35 to +2.73 s after the PEW
--     Undercity -> Orgrimmar       PEW +2.88 s; zone +0.62 s after
-- Thunder Bluff -> Orgrimmar is on one continent and still far, so "same continent" is not the rule.
-- The rule that fits all 14: near when both places lie in the same zone (a city and the zone around
-- it: Orgrimmar in Durotar, Undercity in Tirisfal Glades); far otherwise. Neighbouring zones (The
-- Barrens -> Orgrimmar) were never recorded; the fake counts them as far.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local L = dofile(T.dir .. "/rec/real_lib.lua")

local ARRIVE = L.set({ "LOADING_SCREEN_ENABLED", "PLAYER_LEAVING_WORLD", "LOADING_SCREEN_DISABLED",
	"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" })
local TIRISFAL = { mapID = 1420, x = 0.5, y = 0.5, zone = "Tirisfal Glades", sub = "Ruins of Lordaeron" }

-- a Warlock bot summons Wuber Rocks from `from` to `to`; the summon is accepted; what the rider's
-- window gets in the next 8 s, timed from ConfirmSummon
local function summonFrom(from, to, opts)
	local w = T.newWorld(opts)
	w:addBot("Hayley Cab", { spot = to, class = "WARLOCK" })
	local r = T.rider(w, "Wuber Rocks", { spot = from })
	-- past the login's own zone event (it comes loginDelay = 3 s after a fresh login, lane B1),
	-- so the recording below holds only what the summon makes
	w:advance(4)
	w:summon(w:player("Hayley Cab"), "Wuber Rocks")
	w:advance(0.5)
	local rec = L.record(w, r, ARRIVE)
	local t0 = w.time
	w.hardware = r
	r.env.C_SummonInfo.ConfirmSummon()
	w.hardware = nil
	w:advance(8)
	local at = {}
	for _, e in ipairs(rec.list) do at[e[1]] = at[e[1]] or (e[2] - t0) end
	return w, r, rec, at
end

local NEAR = { { "Durotar", "Orgrimmar" }, { TIRISFAL, "Undercity" } }
local FAR = { { "Thunder Bluff", "Orgrimmar" }, { "Thunder Bluff", "Undercity" }, { "Undercity", "Orgrimmar" } }
local function label(s) return type(s) == "table" and s.zone or s end

test("rec: real: a summon from the same zone: no loading screen, the zone 0.3-0.9 s after (summon.arrival.pew)", function()
	for _, pair in ipairs(NEAR) do
		local w, r, rec, at = summonFrom(pair[1], pair[2])
		local what = label(pair[1]) .. " -> " .. pair[2]
		eq(rec.names(), "ZONE_CHANGED_NEW_AREA", what .. ": the zone event alone")
		ok(at.ZONE_CHANGED_NEW_AREA >= 0.3 and at.ZONE_CHANGED_NEW_AREA <= 0.9, what .. ": +" .. tostring(at.ZONE_CHANGED_NEW_AREA))
		eq(r.player.zone, pair[2], what .. ": there")
		T.clean(w)
	end
end)

test("rec: real: a summon from far: PLAYER_ENTERING_WORLD(false, false) 2.4-4.0 s after, then the zone (summon.arrival.pew)", function()
	for _, pair in ipairs(FAR) do
		local w, r, rec, at = summonFrom(pair[1], pair[2])
		local what = label(pair[1]) .. " -> " .. pair[2]
		local pew = rec.find("PLAYER_ENTERING_WORLD")
		ok(pew, what .. ": a PLAYER_ENTERING_WORLD")
		eq(tostring(pew and pew[3]) .. "," .. tostring(pew and pew[4]), "false,false", what .. ": not a login, not a reload")
		ok(at.PLAYER_ENTERING_WORLD >= 2.4 and at.PLAYER_ENTERING_WORLD <= 4.0, what .. ": PEW +" .. tostring(at.PLAYER_ENTERING_WORLD))
		local dz = at.ZONE_CHANGED_NEW_AREA - at.PLAYER_ENTERING_WORLD
		ok(dz >= 0.2 and dz <= 2.8, what .. ": the zone after the PEW +" .. dz)
		eq(r.player.zone, pair[2], what .. ": there")
		T.clean(w)
	end
end)

test("rec: real: the old arrival stays on request (summonArrival = \"old\")", function()
	local w, r, rec, at = summonFrom("Durotar", "Orgrimmar", { summonArrival = "old" })
	eq(rec.names(), "LOADING_SCREEN_ENABLED PLAYER_LEAVING_WORLD LOADING_SCREEN_DISABLED PLAYER_ENTERING_WORLD(false,false) ZONE_CHANGED_NEW_AREA")
	ok(math.abs(at.PLAYER_ENTERING_WORLD - 1) < 0.05, "1 s after")
	T.clean(w)
end)

-- How Wuber notices the arrival in each case: the ride goes to "arrived" from the zone event (near:
-- the common case in real play, no PLAYER_ENTERING_WORLD) or from PLAYER_ENTERING_WORLD (far).
local function ride(from, to)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = to })
	local r = T.rider(w, "Wuber Rocks", { spot = from })
	T.settle(w)
	r.W.db.autoAccept = false
	T.goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(4)
	r.W.UI.Toggle(true)
	w:advance(2.5)
	r:clickText("Accept invite")
	w:advance(1)
	eq(T.rideState(r), "ingroup", "in the group")
	w:summon(d, "Wuber Rocks")
	w:advance(1)
	eq(T.rideState(r), "portal", "the summon is up")
	r:clickText("Accept summon")
	return w, d, r
end

test("rec: real: Wuber sees a near arrival (no PLAYER_ENTERING_WORLD) within a second (summon.arrival.pew)", function()
	local w, d, r = ride("Durotar", "Orgrimmar")
	w:advance(1)
	eq(T.rideState(r), "arrived", "arrived from the zone event")
	T.clean(w)
end)

test("rec: real: Wuber sees a far arrival after the loading screen (summon.arrival.pew)", function()
	local w, d, r = ride("Thunder Bluff", "Orgrimmar")
	w:advance(2)
	ok(T.rideState(r) ~= "arrived", "not yet: still loading (" .. tostring(T.rideState(r)) .. ")")
	w:advance(2.5)
	eq(T.rideState(r), "arrived", "arrived once in the world")
	T.clean(w)
end)

test("rec: real: a slower far summon on request (summonFar = 4.0, the slowest recorded) (summon.arrival.pew)", function()
	local w, r, rec, at = summonFrom("Thunder Bluff", "Undercity", { summonFar = 4.0 })
	ok(math.abs(at.PLAYER_ENTERING_WORLD - 4.0) < 0.05, "PEW +" .. tostring(at.PLAYER_ENTERING_WORLD))
	T.clean(w)
end)
