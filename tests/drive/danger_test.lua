-- Tests of Drive.Danger (owner F; round 12: no combat log, which the client now forbids). Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local ANA, BEA, CAL = "Ana Smith", "Bea Jones", "Cal Brown"
local SPOT = "Undercity"

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function crewSaved(me, names, captain)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end
	end
	return { chars = { [key(me)] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true } } }
end

-- n Warlocks of one crew (Ana the captain), grouped; open unless opts.open == false
local function team(n, opts)
	opts = opts or {}
	local w = H.NewWorld({})
	local names = { ANA, BEA, CAL }
	while #names > n do names[#names] = nil end
	local cs = {}
	for i, name in ipairs(names) do
		cs[i] = w:addClient(name, { spot = SPOT, class = "WARLOCK", saved = { Wuber = crewSaved(name, names, ANA) } })
	end
	if n > 1 then w:group(names) end
	w:advance(1)
	if opts.open ~= false then cs[1].W.Drive.SetOpen(true) end
	w:advance(2)
	return w, cs[1], cs[2], cs[3]
end

local function registered(c, event)
	for _, obj in ipairs(c.widgets or {}) do
		local s = H.state[obj]
		if s and s.events and s.events[event] then return true end
	end
	return false
end

local function registrations(c, event)
	local n = 0
	for _, obj in ipairs(c.widgets or {}) do
		local s = H.state[obj]
		if s and s.events and s.events[event] then n = n + 1 end
	end
	return n
end

local function fired(c, name)
	local n, last = 0, nil
	for _, f in ipairs(c.fired) do
		if f.name == name then n, last = n + 1, f.args end
	end
	return n, last
end

test("drive.danger: contract (registered, deps, header, public names); closed = level 0, nothing listened to", function()
	local W, w, r, Mod = T.contract("Drive.Danger", "tests/drive/danger_test.lua", {
		["DR.DangerLevel"] = "function", ["DR.MyDanger"] = "function", ["DR.DangerWire"] = "function",
		["DR.DangerHeard"] = "function", ["DR.DangerTick"] = "function", ["DR.danger"] = "table",
	})
	ok(Mod, "W.Mod(\"Drive.Danger\")")
	local level, secs = W.Drive.DangerLevel()
	eq(level, 0, "no danger")
	eq(secs, nil, "never seen")
	eq(registered(r, "COMBAT_LOG_EVENT_UNFILTERED"), false, "a rider never listens to the combat log")
	T.clean(w)
end)

test("drive.danger: listens only while open, never to the combat log; an enemy player's plate then combat -> 2 for 5 minutes, then 0", function()
	local w, ana = team(1, { open = false })
	local DR = ana.W.Drive
	w:addBot("Ally Foe", { faction = "Alliance", spot = SPOT })
	w:advance(2)
	local plates, regen = registrations(ana, "NAME_PLATE_UNIT_ADDED"), registrations(ana, "PLAYER_REGEN_DISABLED")
	eq(registered(ana, "COMBAT_LOG_EVENT_UNFILTERED"), false, "closed: never the combat log")
	DR.SetOpen(true)
	w:advance(2)
	eq(registrations(ana, "NAME_PLATE_UNIT_ADDED"), plates + 1, "open: plates")
	eq(registrations(ana, "PLAYER_REGEN_DISABLED"), regen + 1, "open: entering combat")
	eq(registered(ana, "COMBAT_LOG_EVENT_UNFILTERED"), false, "open: never the combat log (forbidden in this client)")
	w:pvpFight(ana, "Ally Foe")
	local level, secs = DR.DangerLevel()
	eq(level, 2, "in combat with an enemy player near")
	eq(secs, 0)
	eq(fired(ana, "DRIVE_DANGER"), 2, "DRIVE_DANGER: seen (1), then the fight (2)")
	eq(DR.DangerWire(), "2:0:", "HI field 11 (no zone type)")
	w:advance(120)
	level, secs = DR.DangerLevel()
	eq(level, 2, "still 2 after 2 minutes")
	ok(secs >= 119 and secs <= 121, "seconds since: " .. tostring(secs))
	w:advance(181)
	eq((DR.DangerLevel()), 0, "over 5 minutes: 0")
	-- closing stops listening and forgets
	ana:hidePlate("Ally Foe")
	w:pvpFight(ana, "Ally Foe")
	eq((DR.DangerLevel()), 2, "a second fight: 2 again")
	DR.SetOpen(false)
	w:advance(2)
	eq(registrations(ana, "NAME_PLATE_UNIT_ADDED"), plates, "closed: unregistered")
	eq(registrations(ana, "PLAYER_REGEN_DISABLED"), regen, "closed: unregistered")
	eq((DR.DangerLevel()), 0, "closed: 0")
	T.clean(w)
end)

test("drive.danger: combat with an NPC, or long after a plate, is no fight; an enemy player as target is; a plate in combat is", function()
	local w, ana = team(1)
	local DR = ana.W.Drive
	w:addBot("Ally Foe", { faction = "Alliance", spot = SPOT })
	w:addNpc("Angry Boar", { spot = SPOT })
	w:advance(1)
	w:pvpFight(ana, "Angry Boar")
	eq((DR.DangerLevel()), 0, "a fight with an NPC")
	ana:showPlate("Ally Foe")
	eq((DR.DangerLevel()), 1, "an enemy player seen")
	w:advance(31)
	w:enterCombat(ana)
	w:leaveCombat(ana)
	eq((DR.DangerLevel()), 1, "combat 31 s after the plate: still only seen")
	-- an enemy player as my target when combat starts
	ana.player.target = w:player("Ally Foe")
	w:enterCombat(ana)
	w:leaveCombat(ana)
	eq((DR.DangerLevel()), 2, "an enemy player targeted: a fight")
	ana.player.target = nil
	-- a plate while I am already in combat
	w:advance(301)
	ana:hidePlate("Ally Foe")
	eq((DR.DangerLevel()), 0, "calm again")
	local foe = w:player("Ally Foe")
	w:enterCombat(ana)
	ana:showPlate("Ally Foe")
	w:leaveCombat(ana)
	eq((DR.DangerLevel()), 1, "an enemy player's plate while in combat, they are not fighting: only seen")
	ana:hidePlate("Ally Foe")
	foe.combat = true
	w:enterCombat(ana)
	ana:showPlate("Ally Foe")
	w:leaveCombat(ana)
	foe.combat = false
	eq((DR.DangerLevel()), 2, "an enemy player in combat, their plate while I am in combat: a fight")
	-- a plate seen just before combat counts when that player is targeting me
	w:advance(301)
	ana:hidePlate("Ally Foe")
	ana:showPlate("Ally Foe")
	eq((DR.DangerLevel()), 1, "seen")
	foe.target = ana.player
	w:enterCombat(ana)
	w:leaveCombat(ana)
	foe.target = nil
	eq((DR.DangerLevel()), 2, "an enemy player near targeting me when combat starts: a fight")
	T.clean(w)
end)

test("drive.danger: an enemy player who can't attack (unflagged on a PvE realm) is no danger; one walking past while I fight a mob is only seen", function()
	local w, ana = team(1)
	local DR = ana.W.Drive
	local foe = w:addBot("Ally Foe", { faction = "Alliance", spot = SPOT })
	foe.pvp = false -- unflagged: UnitIsEnemy is true, UnitCanAttack is false both ways
	local boar = w:addNpc("Angry Boar", { spot = SPOT })
	w:advance(1)
	ok(ana.api.UnitIsEnemy("player", "target") == false, "no target yet")
	-- I fight a mob while the unflagged enemy walks past
	ana.player.target = boar
	ana:showPlate("Ally Foe")
	w:enterCombat(ana)
	w:leaveCombat(ana)
	eq((DR.DangerLevel()), 0, "an unflagged enemy seen before my fight with a mob: nothing")
	ana:hidePlate("Ally Foe")
	w:enterCombat(ana)
	ana:showPlate("Ally Foe")
	w:leaveCombat(ana)
	eq((DR.DangerLevel()), 0, "an unflagged enemy's plate during my fight with a mob: nothing")
	-- even fighting someone else, or as my target, they can't fight me
	foe.combat = true
	ana.player.target = foe
	ana:hidePlate("Ally Foe")
	w:enterCombat(ana)
	ana:showPlate("Ally Foe")
	w:leaveCombat(ana)
	foe.combat = false
	eq((DR.DangerLevel()), 0, "an enemy who can't attack is never danger")
	-- flagged, but only walking past while I fight a mob: seen, not a fight
	foe.pvp = nil
	ana.player.target = boar
	ana:hidePlate("Ally Foe")
	ana:showPlate("Ally Foe")
	w:enterCombat(ana)
	ana:hidePlate("Ally Foe")
	ana:showPlate("Ally Foe")
	w:leaveCombat(ana)
	eq((DR.DangerLevel()), 1, "a flagged enemy walking past my fight with a mob: only seen")
	T.clean(w)
end)

test("drive.danger: never the combat log, even when the client offers it", function()
	local w = H.NewWorld({})
	local calls = 0
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", prepare = function(env, c)
		c.api.CombatLogGetCurrentEventInfo = function() calls = calls + 1 end
	end })
	w:addBot("Ally Foe", { faction = "Alliance", spot = SPOT })
	w:advance(1)
	ana.W.Drive.SetOpen(true)
	w:advance(2)
	w:pvpFight(ana, "Ally Foe")
	eq((ana.W.Drive.DangerLevel()), 2)
	eq(calls, 0, "CombatLogGetCurrentEventInfo never called")
	eq(registered(ana, "COMBAT_LOG_EVENT_UNFILTERED"), false, "never registered")
	T.clean(w)
end)

test("drive.danger: an enemy player's plate -> 1 for 2 minutes; the zone's PvP type is never read (round 17, D1)", function()
	local w = H.NewWorld({})
	local zoneCalls = 0
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", prepare = function(env, c)
		local real = c.api.GetZonePVPInfo
		c.api.GetZonePVPInfo = function(...)
			zoneCalls = zoneCalls + 1
			if real then return real(...) end
		end
	end })
	w:advance(1)
	ana.W.Drive.SetOpen(true)
	w:advance(2)
	local DR = ana.W.Drive
	w:addBot("Ally Foe", { faction = "Alliance", spot = SPOT })
	w:addNpc("Angry Boar", { spot = SPOT })
	w:advance(1)
	ana:showPlate("Angry Boar")
	eq((DR.DangerLevel()), 0, "an NPC's plate is no danger")
	ana:showPlate("Ally Foe")
	local level = DR.DangerLevel()
	eq(level, 1, "an enemy player seen")
	eq(DR.DangerWire(), "1:0:", "HI field 11: no zone letter")
	w:advance(121)
	eq((DR.DangerLevel()), 0, "2 minutes later: 0")
	w:setZonePvp(SPOT, "hostile", "Alliance")
	w:advance(1)
	eq((DR.DangerLevel()), 0, "a hostile zone alone is no danger (the zone half is gone)")
	w:setZonePvp(SPOT, "combat")
	w:advance(1)
	eq((DR.DangerLevel()), 0, "nor a zone at war")
	eq(DR.DangerWire(), nil)
	eq(zoneCalls, 0, "GetZonePVPInfo never called")
	T.clean(w)
end)

test("drive.danger: the crew's level is the highest at the station (HI field 11); a beacon carries it", function()
	local w, ana, bea, cal = team(3)
	w:addBot("Ally Foe", { faction = "Alliance", spot = SPOT })
	w:advance(1)
	for _, c in ipairs({ ana, bea, cal }) do eq((c.W.Drive.DangerLevel()), 0, c.player.name .. ": calm") end
	w:pvpFight(cal, "Ally Foe")
	eq((cal.W.Drive.DangerLevel()), 2, "Cal fought")
	w:advance(2)
	-- Cal's early HI carries it at once
	local hi
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBERT" and e.from == CAL and e.text:match("^HI~") then hi = e.text end
	end
	ok(hi and hi:find("~2:%d+:$"), "Cal's HI ends with field 11: " .. tostring(hi))
	eq((ana.W.Drive.DangerLevel()), 2, "Ana's crew level")
	eq((bea.W.Drive.DangerLevel()), 2, "Bea's crew level")
	-- the beacon (Ana's window is the one on the network)
	local b = ana.W.Drive.NetBeacon()
	ok(b, "Ana beacons")
	eq(b.danger, 2, "beacon danger")
	ok(b.dangerSecs >= 0 and b.dangerSecs <= 5, "beacon seconds: " .. tostring(b.dangerSecs))
	-- another station doesn't count
	bea.W.Drive.peers[key(CAL)].place = "Orgrimmar"
	bea.W.Drive.DangerTick()
	eq((bea.W.Drive.DangerLevel()), 0, "Cal stands at another station for Bea")
	-- Cal's next HI without the field: back to 0
	w:advance(301)
	eq((cal.W.Drive.DangerLevel()), 0)
	w:advance(16)
	eq((ana.W.Drive.DangerLevel()), 0, "Ana hears Cal is calm again")
	eq(ana.W.Drive.NetBeacon().danger, nil, "no danger in the beacon")
	T.clean(w)
end)

test("drive.danger: HI field 11 parsed strictly; a stranger's or silent window's danger never counts", function()
	local w, ana, bea = team(2)
	local DR = ana.W.Drive
	DR.DangerHeard(key(BEA), "9:5:h")
	eq((DR.DangerLevel()), 2, "a level over 2 is clamped to 2")
	DR.DangerHeard(key(BEA), "junk")
	eq((DR.DangerLevel()), 0, "junk = no danger")
	DR.DangerHeard("stranger x", "2:0:c")
	eq((DR.DangerLevel()), 0, "not crew")
	DR.DangerHeard(key(BEA), "1:10:c")
	eq((DR.DangerLevel()), 1)
	-- Bea's window goes quiet (no HI for 45 s): its word lapses
	bea.alive = false
	w:advance(50)
	DR.DangerTick()
	eq((DR.DangerLevel()), 0, "a silent window's danger lapses")
	T.clean(w)
end)
