-- Module: Drive.Rank
-- Purpose: a driver's rank count from VERIFIED summons (W.Char().rank = { n, seen }): the rider's own Wuber reports
--   the arrival (kind L, Net.Rides), and it counts only for an app ride this Wuber ran with a summon, never for crew,
--   once per rider per day. Nothing here is shown or sent: the beacon (Drive.Net) carries the count, UI draws it.
-- API: DR.RankCount, DR.RankInfo
-- Internals: heard
-- Uses: (none)
-- Later: Drive.Core (DR.IsCrewKey), Drive.Queue (DR.NeverRider, DR.customers), Core.Stats (W.RankOf, W.DayInfo) (all through the W / DR tables at run time)
-- Events: listens (none); fires DRIVE_RANK
-- Standalone: no
-- Test: tests/v24/rem_rank_test.lua
-- From: new in 2.4
--
local _, W = ...
local Mod = W.Module("Drive.Rank", {})
W.Drive = W.Drive or {}
local DR = W.Drive

local str, num = W.Str, W.Num

local MAX_IDS = 100
local countedIds, countedOrder = {}, {}

local function callDR(name, ...)
	local fn = DR[name]
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, ...)
	if not ok then
		W.Error("drive " .. name, v)
		return nil
	end
	return v
end

local function readRank()
	local ch = W.Char()
	return type(ch) == "table" and type(ch.rank) == "table" and ch.rank or nil
end

local function ensureRank()
	local ch = W.Char()
	if type(ch.rank) ~= "table" then ch.rank = { n = 0, seen = {} } end
	if type(ch.rank.seen) ~= "table" then ch.rank.seen = {} end
	local n = num(ch.rank.n)
	if not n or n < 0 then n = 0 else n = math.floor(n) end
	ch.rank.n = n
	return ch.rank
end

local function todayDay()
	local stamp = 0
	if type(time) == "function" then
		local ok, v = pcall(time)
		if ok and type(v) == "number" then stamp = v end
	end
	if type(W.DayInfo) ~= "function" then return math.floor(stamp / 86400) end
	local ok, day = pcall(W.DayInfo, stamp)
	return ok and num(day) or math.floor(stamp / 86400)
end

local function rememberId(id)
	if countedIds[id] then return end
	countedIds[id] = true
	countedOrder[#countedOrder + 1] = id
	if #countedOrder > MAX_IDS then
		countedIds[table.remove(countedOrder, 1)] = nil
	end
end

-- Verified summon count for this character (0 when none).
function DR.RankCount()
	local r = readRank()
	local n = r and num(r.n) or 0
	if not n or n < 0 then return 0 end
	return math.floor(n)
end

-- Rank summary for this character: { n, rung, title, nextAt, toNext }.
function DR.RankInfo()
	local n = DR.RankCount()
	local rung, title, nextAt = W.RankOf(n)
	return {
		n = n,
		rung = rung,
		title = title,
		nextAt = nextAt,
		toNext = nextAt and math.max(0, nextAt - n) or nil,
	}
end

-- Arrival report (kind L, 1 field: rideId) from a rider's own Wuber.
-- Counts only when all five rules hold: app ride (c.wuberRide == id), row present with a summon
-- started (c.tries >= 1) and not walked (not c.walked), real sender matches row's rider, not crew
-- or never-rider, and at most once per rider per day (and once per ride id per session).
function Mod.heard(addr, name, key, fields)
	key = W.Key(str(key))
	if not key or key == "" or key == W.myKey then return false end
	if type(fields) ~= "table" then return false end
	local id = str(fields[1])
	if not id or id == "" or #id > 24 then return false end
	if countedIds[id] then return false end
	local list = DR.customers
	local c = type(list) == "table" and list[key] or nil
	if type(c) ~= "table" then return false end
	if c.key and W.Key(c.key) ~= key then return false end
	if not c.wuberRide or c.wuberRide ~= id then return false end
	if (num(c.tries) or 0) < 1 then return false end
	if c.walked == true then return false end
	if callDR("IsCrewKey", key) then return false end
	if callDR("NeverRider", key) then return false end
	local today = todayDay()
	if not today then return false end
	local r = ensureRank()
	if r.seen[key] == today then return false end
	local oldN = r.n
	local oldRung = W.RankOf(oldN)
	local newN = oldN + 1
	r.n = newN
	for k, d in pairs(r.seen) do
		if type(d) ~= "number" or d < today then r.seen[k] = nil end
	end
	r.seen[key] = today
	rememberId(id)
	local rung, title = W.RankOf(newN)
	local rungChanged = oldRung ~= nil and rung ~= nil and rung > oldRung
	W.Fire("DRIVE_RANK", newN, rung, title, rungChanged)
	return true
end
