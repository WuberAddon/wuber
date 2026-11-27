-- Module: FX.Moments
-- Purpose: when effects play: the ride's screen moments, paid/rating bursts, combat and loading stops, the
--   W.SendStage hook.
-- API: FX.OnRide, FX.OnPaid, FX.OnDrivePaid, FX.OnRating, FX.OnDriveRitual (gold portal on the founder's own cast)
-- Internals: Mod.markRestored (called by Net.Inbox before the ride is restored)
-- Uses: (none)
-- Later: (none)
-- Events: listens Listen RIDE, Listen DRIVE_RITUAL, Listen RATING, Listen PAID, Listen DRIVE_PAID, Listen SETTINGS, On
--   PLAYER_LEAVING_WORLD, On PLAYER_ENTERING_WORLD, On PLAYER_REGEN_DISABLED, login; fires (none); wraps
--   W.SendStage at load (hookSendStage, allow-listed)
-- Standalone: no
-- Test: tests/fx/moments_test.lua
-- From: FX.lua 1079-1217 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("FX.Moments", {})

local FX = W.FX

---------------------------------------------------------------------------
-- The ride's screen moments (rider) and the driver's bursts
---------------------------------------------------------------------------

local seen = {}         -- [rideId .. ":" .. state] = true: each moment once
local loading = false   -- between PLAYER_LEAVING_WORLD and PLAYER_ENTERING_WORLD
local pendingArrival = nil
local portalHandle = nil
local AFTER_ARRIVED = { arrived = true, paying = true, done = true }

-- genuine founder's summon (Net.Portal decides; any doubt or a missing check: violet)
local function isGold(r, what)
	local f = W.FounderSummon
	if type(f) ~= "function" then return false end
	local ok, res = pcall(f, r, what)
	return ok and res == true
end

local pendingGold = false

local function playArrival()
	pendingArrival = nil
	if portalHandle then
		pcall(portalHandle.Stop, portalHandle, true)
		portalHandle = nil
	end
	-- the name stays "arrival" (gold is an option) so FX.Fullscreen hooks see the moment by its name
	FX.Fullscreen("arrival", pendingGold and { gold = true } or nil)
	pendingGold = false
end

local function scheduleArrival(gold)
	pendingArrival = true
	pendingGold = gold == true
	if loading then return end -- PLAYER_ENTERING_WORLD plays it
	W.After(0.05, function()
		if pendingArrival and not loading then playArrival() end
	end)
end

function FX.OnRide(r)
	if type(r) ~= "table" then
		if portalHandle then
			pcall(portalHandle.Stop, portalHandle)
			portalHandle = nil
		end
		return
	end
	local id = tostring(W.Plain(r.id) or "?")
	local state = W.Str(r.state)
	if not state then return end
	if state == "portal" then
		local key = id .. ":portal"
		if not seen[key] then
			seen[key] = true
			portalHandle = FX.Fullscreen("portal_open", { loop = true, hold = 3, gold = isGold(r) or nil })
		end
	elseif AFTER_ARRIVED[state] then
		if portalHandle then
			pcall(portalHandle.Stop, portalHandle)
			portalHandle = nil
		end
		local key = id .. ":arrived"
		if not seen[key] then
			seen[key] = true
			scheduleArrival(isGold(r, "arrival")) -- the arrival also needs the game's own summoner
		end
	elseif portalHandle then
		-- the summon expired or the ride ended: let the portal fade away
		pcall(portalHandle.Stop, portalHandle)
		portalHandle = nil
	end
end

-- The founder's own cast: when the cast watcher says the founder is casting for a rider
-- (DRIVE_RITUAL phase "c", caster = me) the gold portal opens on their own screen too. data.caster, when
-- given, must be me (a key, or "me"/true); a missing caster means the watcher's own cast. Net.Portal
-- decides (W.FounderSummon{own}: a W.CREATOR character on the founders' ruleset; any doubt: nothing).
-- Once per ride (data.ride, else the rider's name).
local castSeen = {}
function FX.OnDriveRitual(name, phase, data)
	if phase ~= "c" then return nil end
	local f = W.FounderSummon
	if type(f) ~= "function" then return nil end
	local who = type(data) == "table" and data.caster or nil
	if who == true or who == "me" then who = nil end
	local okF, founder = pcall(f, { own = true, caster = who ~= nil and W.Plain(who) or nil })
	if not okF or founder ~= true then return nil end
	local ride = type(data) == "table" and W.Plain(data.ride) or nil
	local key = tostring(ride or W.Plain(name) or "?")
	if castSeen[key] then return nil end
	castSeen[key] = true
	-- ownRandom: 2.2.3 played nothing here, so this must not shift the shared random numbers
	return FX.Fullscreen("portal_open", { loop = false, gold = true, ownRandom = true })
end

local paidSeen = {}
-- the same buyer (short name, any case) paid just now: one payment is never two bursts
local function shortWho(n)
	n = W.Plain(n)
	if type(n) ~= "string" or n == "" then return nil end
	return W.Key(n)
end
-- Two spellings of one rider: equal keys, or a bare first name ("Ed", from a stage hook) against
-- the same first name carrying a realm or surname tail ("Ed-Realm" reads as "ed realm").
local function samePayer(who)
	local was = FX.paidWho
	if was == nil or who == nil or was == who then return true end
	if not was:find(" ", 1, true) then return was == who:match("^(%S+)") end
	if not who:find(" ", 1, true) then return who == was:match("^(%S+)") end
	return false
end
function FX.OnPaid(id, buyer)
	local key = tostring(W.Plain(id) or "?")
	if paidSeen[key] then return end
	paidSeen[key] = true
	local t = W.Num(GetTime()) or 0
	local who = shortWho(buyer)
	if FX.paidAt and t - FX.paidAt < 5 and samePayer(who) then return end -- DRIVE_PAID just burst for it
	FX.paidAt, FX.paidWho = t, who
	FX.Fullscreen("paid")
end

-- DRIVE_PAID (review #20): a trade this window took (Trade-chat and whisper buyers, and crew
-- cashier windows, never reach W.SendStage) gets the coin burst too; a generous tip gets the
-- bigger shower. Once per payment, never twice with the SendStage burst (5 s apart).
-- name, copper, tip, cashierKey, mine, how ("t" traded | "m" marked by hand)
function FX.OnDrivePaid(name, copper, tip, cashierKey, mine, how)
	copper, tip = W.Num(copper) or 0, W.Num(tip) or 0
	if not mine or how ~= "t" or copper <= 0 then return nil end
	local t = W.Num(GetTime()) or 0
	local who = shortWho(name)
	if FX.paidAt and t - FX.paidAt < 5 and samePayer(who) then return nil end -- (another rider's payment still bursts)
	FX.paidAt, FX.paidWho = t, who
	local which = tip > 0 and "coins" or "paid"
	FX.lastDrivePaid = which
	FX.Fullscreen(which)
	return which
end

function FX.OnRating(id, name, stars)
	if W.Num(stars) == 5 then FX.Fullscreen("coins") end
end

W.Listen("RIDE", function(r) FX.OnRide(r) end)
W.Listen("RATING", function(id, name, stars) FX.OnRating(id, name, stars) end)
W.Listen("PAID", function(id) FX.OnPaid(id) end) -- if NET ever fires it
W.Listen("DRIVE_RITUAL", function(...) FX.OnDriveRitual(...) end)
W.Listen("DRIVE_PAID", function(...) FX.OnDrivePaid(...) end)
W.Listen("SETTINGS", function(key)
	if key == nil or key == "fx" then FX.Refresh() end
end)

W.On("PLAYER_LEAVING_WORLD", function() loading = true end)
W.On("PLAYER_ENTERING_WORLD", function()
	loading = false
	if pendingArrival then
		W.After(0.3, function()
			if pendingArrival and not loading then playArrival() end
		end)
	end
end)
W.On("PLAYER_REGEN_DISABLED", function() FX.StopAll(true) end)

-- The driver's "paid" stage goes out through W.SendStage (Driver.lua and WuberAPI.Status
-- both call it): a small burst on the driver's screen once per ride.
local function hookSendStage()
	local orig = W.SendStage
	if type(orig) ~= "function" or FX.sendStageHooked then return end
	FX.sendStageHooked = true
	W.SendStage = function(id, stage, buyer, ...)
		local a, b, c = orig(id, stage, buyer, ...)
		if stage == "paid" and a then
			local ok, err = pcall(FX.OnPaid, id, buyer)
			if not ok then W.Error("fx paid", err) end
		end
		return a, b, c
	end
end
hookSendStage()

-- a ride restored after /reload must not replay its moments. Net.Inbox calls this just before it restores
-- the ride (its login handler runs before this module's, and the restore fires RIDE at once).
function Mod.markRestored()
	local saved = W.db and W.db.ride
	if type(saved) == "table" and saved.id ~= nil then
		local id = tostring(saved.id)
		if saved.state == "portal" or AFTER_ARRIVED[saved.state] then seen[id .. ":portal"] = true end -- (a ride only asked for still plays its portal later)
		if AFTER_ARRIVED[saved.state] then seen[id .. ":arrived"] = true end
	end
end

W.OnLogin(function()
	hookSendStage()
	Mod.markRestored()
end)
