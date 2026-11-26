-- Tests of the harness's round-8 game fakes (tests/lib/fakes8.lua, SPEC7 section 8): what the
-- other agents' tests rely on. Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list

-- a frame in the client's own environment that records the events it is given
local function listener(c, events)
	local got = {}
	local f = c.env.CreateFrame("Frame")
	for _, e in ipairs(events) do f:RegisterEvent(e) end
	f:SetScript("OnEvent", function(_, event, ...) got[#got + 1] = { event = event, n = select("#", ...), ... } end)
	return got
end

local function names(got)
	local out = {}
	for i, g in ipairs(got) do out[i] = g.event end
	return list(out, ",")
end

test("harness r8: bit library (band, bor, bxor, bnot, shifts) and the combat log flag constants", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local bit, env = r.env.bit, r.env
	ok(type(bit) == "table", "bit exists")
	eq(bit.band(0x548, 0x400), 0x400, "band: a player")
	eq(bit.band(0x548, 0x40), 0x40, "band: hostile")
	eq(bit.band(0x518, 0x40), 0, "band: friendly is not hostile")
	eq(bit.band(0xFF, 0x0F, 0x03), 3, "band of three")
	eq(bit.bor(0x400, 0x40, 0x8), 0x448, "bor")
	eq(bit.bxor(0xF0, 0xFF), 0x0F, "bxor")
	eq(bit.bnot(0), 4294967295, "bnot 0")
	eq(bit.band(-1, 0xFF), 0xFF, "negative numbers as 32-bit")
	eq(bit.lshift(1, 10), 1024, "lshift")
	eq(bit.rshift(1024, 3), 128, "rshift")
	eq(bit.arshift(0x80000000, 1), 0xC0000000, "arshift keeps the sign bit")
	eq(env.COMBATLOG_OBJECT_TYPE_PLAYER, 0x400, "TYPE_PLAYER")
	eq(env.COMBATLOG_OBJECT_REACTION_HOSTILE, 0x40, "REACTION_HOSTILE")
	-- a client without the library (to test the guard)
	local c2 = T.rider(w, "Ana Smith", { prepare = function(_, c) c.api.bit = nil end })
	eq(c2.env.bit, nil, "bit removed for one client")
	T.clean(w)
end)

-- Round 12: the client forbids these to addons (tools/forbidden.lua); the fake client does too:
-- ADDON_ACTION_FORBIDDEN ("UNKNOWN()", as the real one says), a violation, and an error.
test("harness r12: what this client forbids (combat log events and info, community invites) raises ADDON_ACTION_FORBIDDEN", function()
	local w = T.newWorld({ clubs = true })
	local r = T.rider(w)
	local got = listener(r, { "ADDON_ACTION_FORBIDDEN" })
	local f = r.env.CreateFrame("Frame")
	local okR, errR = pcall(f.RegisterEvent, f, "COMBAT_LOG_EVENT_UNFILTERED")
	eq(okR, false, "RegisterEvent raises")
	ok(tostring(errR):find("ADDON_ACTION_FORBIDDEN", 1, true), tostring(errR))
	eq(f:IsEventRegistered("COMBAT_LOG_EVENT_UNFILTERED"), false, "not registered")
	eq((pcall(f.UnregisterEvent, f, "COMBAT_LOG_EVENT_UNFILTERED")), false, "UnregisterEvent raises too")
	eq((pcall(r.env.CombatLogGetCurrentEventInfo)), false, "CombatLogGetCurrentEventInfo raises")
	ok(r.env.C_Club, "communities in this world")
	eq((pcall(r.env.C_Club.SendCharacterInvitation, 1, "Bob Stone")), false, "C_Club.SendCharacterInvitation raises")
	eq((pcall(f.RegisterAllEvents, f)), false, "RegisterAllEvents raises (it would pull in the combat log)")
	eq(#got, 5, "ADDON_ACTION_FORBIDDEN each time")
	eq(got[1][2], "UNKNOWN()", "the function name, as the real client gives it")
	eq(#w.violations, 5, "five violations")
	ok(tostring(w.violations[1]):find("COMBAT_LOG_EVENT_UNFILTERED", 1, true), tostring(w.violations[1]))
	eq((pcall(w.combatLog, w, r, "SWING_DAMAGE", {})), false, "w:combatLog is gone (use w:pvpFight)")
	w.violations = {}
	T.clean(w)
end)

test("harness r8: enemy nameplates: UnitIsEnemy, UnitIsPlayer (NPCs are not players), NAME_PLATE_UNIT_ADDED", function()
	local w = T.newWorld()
	local r = T.rider(w)
	w:addBot("Ally Foe", { faction = "Alliance", spot = "Orgrimmar" })
	w:addNpc("Angry Boar", { spot = "Orgrimmar" })
	w:addNpc("Tame Kitten", { spot = "Orgrimmar", hostile = false })
	local got = listener(r, { "NAME_PLATE_UNIT_ADDED" })
	local u1 = r:showPlate("Ally Foe")
	local u2 = r:showPlate("Angry Boar")
	local u3 = r:showPlate("Tame Kitten")
	eq(names(got), "NAME_PLATE_UNIT_ADDED,NAME_PLATE_UNIT_ADDED,NAME_PLATE_UNIT_ADDED", "plates added")
	local env = r.env
	eq(env.UnitIsPlayer(u1), true, "the enemy is a player")
	eq(env.UnitIsEnemy("player", u1), true, "the other faction is an enemy")
	eq(env.UnitIsFriend("player", u1), false, "not a friend")
	eq(env.UnitIsPlayer(u2), false, "an NPC is not a player")
	eq(env.UnitIsEnemy("player", u2), true, "a hostile NPC is an enemy")
	eq(env.UnitIsEnemy("player", u3), false, "a friendly NPC is not")
	eq(env.UnitIsPlayer("player"), true, "I am a player")
	eq(env.UnitIsEnemy("player", "player"), false, "never my own enemy")
	T.clean(w)
end)

test("harness r8: GetZonePVPInfo per zone and subzone, and a player's override", function()
	-- (rec) the real client has no GetZonePVPInfo: this tests the old fake one, which a world asks for
	local w = T.newWorld({ zonePvpInfo = true })
	local r = T.rider(w) -- Orgrimmar
	eq(r.env.GetZonePVPInfo(), nil, "a normal zone: nil")
	w:setZonePvp("Orgrimmar", "friendly", "Horde")
	local t, ffa, fac = r.env.GetZonePVPInfo()
	eq(t, "friendly", "type") eq(ffa, false, "not FFA") eq(fac, "Horde", "faction")
	w:move(r.player.name, "Crossroads")
	w:setZonePvp("The Crossroads", "hostile", "Alliance")
	eq((r.env.GetZonePVPInfo()), "hostile", "the subzone wins")
	r.player.pvpZone = "sanctuary"
	eq((r.env.GetZonePVPInfo()), "sanctuary", "a player's override")
	r.player.pvpZone = nil
	w:setZonePvp("The Crossroads", nil)
	eq((r.env.GetZonePVPInfo()), nil, "cleared")
	T.clean(w)
end)

test("harness r8: the flight map (TaxiFrame, TaxiNodePosition), TakeTaxiNode hooks, take-off and landing", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Undercity" })
	w:advance(4) -- (REC login.pew.fresh) the login's own ZONE_CHANGED_NEW_AREA comes about 3 s after it
	local env = r.env
	eq(rawget(env, "TaxiFrame"), nil, "no TaxiFrame before the first open")
	local got = listener(r, { "TAXIMAP_OPENED", "TAXIMAP_CLOSED", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED",
		"ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED" })
	local hooked = {}
	env.hooksecurefunc("TakeTaxiNode", function(slot) hooked[#hooked + 1] = { slot = slot, to = env.TaxiNodeName(slot) } end)
	local nodes = { { name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 },
		{ name = "Tarren Mill, Hillsbrad", type = "REACHABLE", cost = 580, x = 0.47, y = 0.44 } }
	w:openTaxiMap(r, nodes)
	local tf = env.TaxiFrame
	ok(tf and tf:IsShown(), "TaxiFrame shown")
	eq(math.floor(tf:GetWidth()), 603, "TaxiFrame width") -- (rec: the real client's, measured; was 384)
	local x, y = env.TaxiNodePosition(2)
	eq(x, 0.47, "node x") eq(y, 0.44, "node y")
	eq(env.UnitOnTaxi("player"), false, "on the ground")
	w:fly(r, 2, 95, "Tarren Mill")
	eq(#hooked, 1, "the hook ran once") eq(hooked[1].to, "Tarren Mill, Hillsbrad", "while the map still answered")
	ok(not tf:IsShown(), "the map closed")
	w:advance(1.5)
	eq(env.UnitOnTaxi("player"), true, "in the air")
	w:advance(95)
	eq(env.UnitOnTaxi("player"), false, "landed")
	eq(r.player.subZone, "Tarren Mill", "at Tarren Mill")
	eq(names(got), "TAXIMAP_OPENED,TAXIMAP_CLOSED,PLAYER_CONTROL_LOST,ZONE_CHANGED_NEW_AREA,ZONE_CHANGED,PLAYER_CONTROL_GAINED",
		"events in order")
	-- a loading screen mid-flight; FlightMapFrame instead of TaxiFrame
	local got2 = listener(r, { "PLAYER_ENTERING_WORLD", "PLAYER_CONTROL_GAINED" })
	w:openTaxiMap(r, { { name = "Tarren Mill, Hillsbrad", type = "CURRENT" }, { name = "Undercity, Tirisfal", type = "REACHABLE" } },
		{ frame = "FlightMapFrame", takeoff = 2 })
	ok(env.FlightMapFrame and env.FlightMapFrame:IsShown(), "FlightMapFrame shown")
	w:fly(r, 2, 60, "Undercity", { loadingScreen = 20 })
	w:advance(70)
	eq(names(got2), "PLAYER_ENTERING_WORLD,PLAYER_CONTROL_GAINED", "a loading screen, then the landing")
	eq(r.player.zone, "Undercity", "back in Undercity")
	T.clean(w)
end)

test("harness r8: CONFIRM_SUMMON names the caster, or World:summon's shownBy", function()
	local w = T.newWorld()
	local r = T.rider(w)
	w:addBot("Anita Lift", { class = "WARLOCK", spot = "Undercity" })
	w:addBot("Fake Lift", { class = "WARLOCK", spot = "Undercity" })
	local got = listener(r, { "CONFIRM_SUMMON" })
	w:summon(w:player("Anita Lift"), r.player.name)
	eq(#got, 1, "CONFIRM_SUMMON")
	eq(r.env.C_SummonInfo.GetSummonConfirmSummoner(), "Anita Lift", "the caster")
	r.env.C_SummonInfo.CancelSummon()
	w:summon(w:player("Fake Lift"), r.player.name, { shownBy = "Somebody Else" })
	eq(r.env.C_SummonInfo.GetSummonConfirmSummoner(), "Somebody Else", "shownBy")
	eq(r.env.GetSummonConfirmSummoner(), "Somebody Else", "the old global too")
	r.env.C_SummonInfo.CancelSummon()
	T.clean(w)
end)
