-- Module: Drive.Danger
-- Purpose: the hot-drop shield's engine: while open, PvP danger at the summon spot from enemy
--   player nameplates and my entering combat near one; the crew's level (HI) and the beacon value.
-- API: DR.danger, DR.DangerLevel, DR.MyDanger, DR.DangerWire, DR.DangerHeard, DR.DangerTick,
--   DR.DangerCombat, DR.DangerPlate, DR.DANGER
-- Internals: (none)
-- Uses: (none)
-- Later: (none)
-- Events: listens NAME_PLATE_UNIT_ADDED and PLAYER_REGEN_DISABLED on its own frame, registered
--   only while open (made the first time the driver opens); fires DRIVE_DANGER. Never the combat
--   log: this client forbids it to addons (round 12).
-- Standalone: no
-- Test: tests/drive/danger_test.lua
-- From: new in Wuber 2.3.0; round 12: rebuilt without the combat log
--
-- Only enemy players who can fight me count (UnitCanAttack either way: on a PvE realm an unflagged
-- one can't, though UnitIsEnemy is true). Levels: 2 = in the last 5 minutes I entered
-- combat with such a player as my target, or with one near (nameplate in the 30 s before) who is
-- in combat or targeting me, or such a player's nameplate showed while we were both in combat (or
-- they targeted me); 1 = such players seen (nameplates) in the last 2 minutes; 0 otherwise. It
-- only sees players whose nameplates show. (Round 17, D1: the zone's PvP type is not read: this
-- client has no GetZonePVPInfo; HI keeps an empty third field, which older windows still parse.)
-- Only while open (selling): closed, nothing is listened to and my level is 0. The crew's level is
-- the highest of mine and every crew window's at the same station (their HI's field 11,
-- "level:seconds:", heard in the last 45 s).
--
--   DR.DangerLevel() -> level 0|1|2, seconds since (nil at 0): the crew's, what riders are told
--   DR.MyDanger() -> level, seconds, "" (the old zone letter, always empty): this window's own
--   DR.DangerWire() -> "2:40:" for HI (nil when my level is 0)
--   DR.DangerHeard(key, field) -- Drive.Team: a crew window's HI field 11 (nil/"" = no danger)
--   DR.DangerTick(t) -- DR.Tick, once a second: listens while open, recomputes, fires DRIVE_DANGER
--     (level, secs) on a change, an early HI when my level rises (30 s apart), a beacon check
--   DR.DangerCombat() -- PLAYER_REGEN_DISABLED: a fight when an enemy player near is fighting
--   DR.DangerPlate(unit) -- NAME_PLATE_UNIT_ADDED: an enemy player seen (a fight when we both fight)
--
-- Opening also counts the nameplates already showing (nameplate1..40), like ones that appear later.
--
-- Cheap by design: two events, each read at most once per 2 s while something is counted.

local _, W = ...
local Mod = W.Module("Drive.Danger", {})
W.Drive = W.Drive or {}
local DR = W.Drive

local plain, str = W.Plain, W.Str

local DANGER = {
	FIGHT = 300,     -- level 2 lasts 5 minutes after a fight with an enemy player
	SEEN = 120,      -- level 1 lasts 2 minutes after an enemy player's nameplate
	NEAR = 30,       -- entering combat within 30 s of an enemy player's plate is a fight
	GAP = 2,         -- a fight or a sighting is counted again at most every 2 s
	EARLY_HI = 30,   -- an early HI when my level rises, at most every 30 s
	PEER_TTL = 45,   -- a crew window's danger counts while its HI is this fresh
}
DR.DANGER = DANGER

-- session only: my own sightings, the crew's, the level last told
-- (near: nameplate unit token -> when it showed an enemy player who can fight me; at most one per token)
local danger = { level = 0, secs = nil, fightAt = nil, seenAt = nil, peers = {}, near = {}, listening = false }
DR.danger = danger

local frame -- made the first time the driver opens; nothing at load

local function now() return GetTime() end

local function call(name, ...)
	local fn = DR[name]
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if not ok then
		W.Error("drive " .. name, a)
		return nil
	end
	return a, b
end

local function isOpen()
	local v = call("Selling")
	if v == nil then v = call("IsOpen") end
	return v == true
end

-- true when api(...) is a function that answers true
local function yes(api, ...)
	if type(api) ~= "function" then return false end
	local ok, v = pcall(api, ...)
	return ok and plain(v) == true
end

-- an enemy player (not an NPC) in `unit` who can fight me: on a PvE realm an unflagged one is an
-- enemy (UnitIsEnemy) but can't attack me or be attacked (UnitCanAttack), so is no danger
local function enemyPlayer(unit)
	if not yes(UnitIsPlayer, unit) or not yes(UnitIsEnemy, "player", unit) then return false end
	return yes(UnitCanAttack, unit, "player") or yes(UnitCanAttack, "player", unit)
end

-- that unit is fighting: in combat, or targeting me
local function fighting(unit)
	return yes(UnitAffectingCombat, unit) or yes(UnitIsUnit, unit .. "target", "player")
end

local function inCombat()
	if type(InCombatLockdown) ~= "function" then return false end
	local ok, v = pcall(InCombatLockdown)
	return ok and plain(v) == true
end

local function fought(t)
	if danger.fightAt and t - danger.fightAt < DANGER.GAP then return end
	danger.fightAt = t
	DR.DangerTick(t)
end

---------------------------------------------------------------------------
-- What I see
---------------------------------------------------------------------------

-- PLAYER_REGEN_DISABLED (I enter combat): a fight when an enemy player who can fight me is my
-- target, or one whose nameplate showed in the last 30 s is in combat or targeting me
function DR.DangerCombat()
	local t = now()
	if enemyPlayer("target") then return fought(t) end
	for unit, at in pairs(danger.near) do
		if t - at < DANGER.NEAR and enemyPlayer(unit) and fighting(unit) then return fought(t) end
	end
end

-- NAME_PLATE_UNIT_ADDED: the nameplate of an enemy player who can fight me (a fight when I am in
-- combat and they are in combat or targeting me)
function DR.DangerPlate(unit)
	unit = str(unit)
	if not unit or not enemyPlayer(unit) then return end
	local t = now()
	local was = danger.seenAt
	danger.seenAt = t
	danger.near[unit] = t
	if inCombat() and fighting(unit) then return fought(t) end
	if not was or t - was >= DANGER.GAP then DR.DangerTick(t) end
end

local function onEvent(_, event, ...)
	if event == "PLAYER_REGEN_DISABLED" then
		W.Safe("danger combat", DR.DangerCombat)
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		W.Safe("danger plate", DR.DangerPlate, ...)
	end
end

-- Listening only while open.
local function listen(on)
	if on == danger.listening then return end
	if on and not frame then
		if type(CreateFrame) ~= "function" then return end
		frame = CreateFrame("Frame")
		frame:SetScript("OnEvent", onEvent)
	end
	if not frame then return end
	danger.listening = on
	if on then
		pcall(frame.RegisterEvent, frame, "NAME_PLATE_UNIT_ADDED")
		pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_DISABLED")
		-- plates already showing when I open count like ones that appear later
		if C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function" then
			for i = 1, 40 do
				local unit = "nameplate" .. i
				local okp, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
				if okp and plate then W.Safe("danger plate", DR.DangerPlate, unit) end
			end
		end
	else
		pcall(frame.UnregisterEvent, frame, "NAME_PLATE_UNIT_ADDED")
		pcall(frame.UnregisterEvent, frame, "PLAYER_REGEN_DISABLED")
		danger.fightAt, danger.seenAt, danger.near = nil, nil, {}
	end
end

-- My own level, seconds since, "" (the zone letter HI used to carry).
function DR.MyDanger(t)
	t = t or now()
	if not danger.listening then return 0, nil, "" end
	if danger.fightAt and t - danger.fightAt < DANGER.FIGHT then return 2, t - danger.fightAt, "" end
	if danger.seenAt and t - danger.seenAt < DANGER.SEEN then return 1, t - danger.seenAt, "" end
	return 0, nil, ""
end

-- HI's field 11: "level:seconds:" (the empty third field kept for older windows), or nil with no danger.
function DR.DangerWire()
	local level, secs = DR.MyDanger()
	if level <= 0 then return nil end
	return level .. ":" .. math.min(999, math.floor(secs or 0)) .. ":"
end

---------------------------------------------------------------------------
-- The crew
---------------------------------------------------------------------------

-- Drive.Team: a crew window's HI. field nil or "" = no danger there. (A zone letter from an
-- older window is accepted and ignored.)
function DR.DangerHeard(key, field)
	if not key then return end
	local l, s = tostring(field or ""):match("^(%d):(%d+):%a?$")
	l, s = tonumber(l), tonumber(s)
	if not l or l < 1 then
		if danger.peers[key] then
			danger.peers[key] = nil
			DR.DangerTick()
		end
		return
	end
	local t = now()
	danger.peers[key] = { level = math.min(2, l), at = t - math.min(999, s or 0), heard = t }
	DR.DangerTick(t)
end

local function samePlace(key)
	local peer = DR.peers and DR.peers[key]
	if DR.peers and not peer then return false end -- left the group: their old report says nothing about this station
	local theirs = peer and peer.place
	local mine = call("PlaceOf", "player")
	if not theirs or not mine or theirs == "" or mine == "" then return true end
	return W.SamePlace(theirs, mine) == true
end

local function peerLevel(p, t)
	if t - p.heard > DANGER.PEER_TTL then return 0 end
	if p.level >= 2 and t - p.at < DANGER.FIGHT then return 2, t - p.at end
	if t - p.at < DANGER.SEEN then return 1, t - p.at end
	return 0
end

local function crewLevel(t)
	local level, secs = DR.MyDanger(t)
	if not danger.listening then return 0, nil end
	for key, p in pairs(danger.peers) do
		if call("IsCrewKey", key) and samePlace(key) then
			local l, s = peerLevel(p, t)
			if l > level or (l == level and l > 0 and s and (not secs or s < secs)) then level, secs = l, s end
		end
	end
	return level, level > 0 and secs or nil
end

-- the crew's danger level at the summon spot, and how long ago it was seen
function DR.DangerLevel()
	return crewLevel(now())
end

-- Once a second (DR.Tick) and when something is seen or heard.
function DR.DangerTick(t)
	t = t or now()
	listen(isOpen() and DR.on == true)
	local mine = DR.MyDanger(t)
	local higher = mine > (danger.hiLevel or 0) -- a rise past the last early HI's level goes at once
	if mine > (danger.mine or 0) and W.InGroup() and (higher or t - (danger.hiAt or -1000) >= DANGER.EARLY_HI) then
		danger.hiAt, danger.hiLevel = t, mine
		call("Hello")
	end
	danger.mine = mine
	local level, secs = crewLevel(t)
	danger.secs = secs
	if level ~= danger.level then
		danger.level = level
		W.Fire("DRIVE_DANGER", level, secs)
		call("NetCheck")
		call("Changed")
	end
end
