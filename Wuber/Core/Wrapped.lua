-- Module: Core.Wrapped
-- Purpose: Azeroth Wrapped, the monthly recap's numbers (pure): rides, places, time and flights
--   saved, favourite driver, longest hop, new places, streak, tier, and the driver's month.
-- API: Core.Wrapped.Month, Core.Wrapped.Range, Core.Wrapped.MonthName, Core.Wrapped.Key
-- Internals: monthRange, tripsIn, driverMonth
-- Uses: (none)
-- Later: (none)
-- Events: listens (none); fires (none)
-- Standalone: no
-- Test: tests/core/wrapped_test.lua
-- From: new in Wuber 2.3.0 (SPEC7 section 5.9; owner C)
--
-- Callers reach it through the handle:
--   local WrappedMod = W.Mod("Core.Wrapped")
--   WrappedMod.Month(year, month) -> { year, month, key ("2026-10"), name ("October"), rides,
--     places, topPlace, topDriver, topDriverN, saved (seconds), flightSaved (copper, exact
--     flight prices only), about (true when any time saved was worked out, not timed), spent, longestHop =
--     { from, to, yards } | nil, newPlaces (list; empty for the oldest month of a full 100-trip list, whose earlier visits are gone), streak (days in a row), tier (0, shown as nothing, when the full 100 kept cannot prove the level at the month's end), capped (the
--     trip list holds only the last 100 and this month may have more), driver = { rides, gold,
--     bestHour, helpers } | nil } or nil without saved data. Month boundaries in local time.
-- Reads W.db.rides (the rider's trips, newest last) and W.db.drive.log (the driver's lines
-- "time,copper,name,dest,how,price" and, from 2.3.0, log.cut shift entries). Stores nothing.

local _, W = ...
local Mod = W.Module("Core.Wrapped", {})

local MONTHS = { "January", "February", "March", "April", "May", "June", "July", "August", "September",
	"October", "November", "December" }

local function num(v) return type(v) == "number" and v or tonumber(v) end

-- "2026-10"
function Mod.Key(year, month)
	return string.format("%04d-%02d", year, month)
end

function Mod.MonthName(month) return MONTHS[month] or "" end

-- Local-time bounds of a month: first second, first second of the next month.
local function monthRange(year, month)
	if type(time) ~= "function" then return nil end
	local ny, nm = year, month + 1
	if nm > 12 then ny, nm = year + 1, 1 end
	local ok1, a = pcall(time, { year = year, month = month, day = 1, hour = 0, min = 0, sec = 0 })
	local ok2, b = pcall(time, { year = ny, month = nm, day = 1, hour = 0, min = 0, sec = 0 })
	if not (ok1 and ok2 and num(a) and num(b)) then return nil end
	return a, b
end
Mod.Range = monthRange

local function placeKey(dest)
	if type(W.PlaceKey) == "function" then
		local ok, k = pcall(W.PlaceKey, dest)
		if ok and type(k) == "string" then return k end
	end
	return tostring(dest or ""):lower()
end

local function placeName(dest)
	local p = type(W.ExactPlace) == "function" and W.ExactPlace(tostring(dest or "")) or nil
	return p and p.name or dest
end

-- A place's world position (continent, x, y) or nil.
local function worldOf(name)
	if type(W.PlaceWorld) ~= "function" or type(W.ExactPlace) ~= "function" then return nil end
	local ok, p = pcall(W.ExactPlace, tostring(name or ""))
	if not ok or type(p) ~= "table" then return nil end
	local ok2, c, x, y = pcall(W.PlaceWorld, p)
	if not ok2 or not (num(c) and num(x) and num(y)) then return nil end
	return c, x, y
end

local function dayOf(at)
	if type(W.DayInfo) == "function" then
		local ok, d = pcall(W.DayInfo, at)
		if ok and num(d) then return d end
	end
	return math.floor(at / 86400)
end

-- the paid trips in [a, b), oldest first
local function tripsIn(list, a, b)
	local out = {}
	for _, t in ipairs(list) do
		local at = type(t) == "table" and num(t.at)
		if at and at >= a and at < b and not t.unpaid then out[#out + 1] = t end
	end
	table.sort(out, function(x, y) return num(x.at) < num(y.at) end)
	return out
end

-- the most frequent key of a count map (ties: alphabetical)
local function top(count)
	local best, bn
	for k, n in pairs(count) do
		if not best or n > bn or (n == bn and tostring(k) < tostring(best)) then best, bn = k, n end
	end
	return best, bn
end

-- The driver's month from the earnings log: rides taken, gold, the best hour (most gold), and
-- the helpers thanked (people with clicks in the shift splits).
local function driverMonth(a, b)
	local d = W.db and W.db.drive
	local l = type(d) == "table" and d.log or nil
	if type(l) ~= "table" or type(l.rides) ~= "table" then return nil end
	local rides, gold, byHour = 0, 0, {}
	for _, line in ipairs(l.rides) do
		local at, copper = tostring(line):match("^(%d+),(%d+)")
		at, copper = num(at), num(copper)
		if at and at >= a and at < b then
			rides = rides + 1
			gold = gold + (copper or 0)
			local hour = 0
			if type(date) == "function" then
				local ok, h = pcall(date, "%H", at)
				hour = ok and num(h) or 0
			end
			byHour[hour] = (byHour[hour] or 0) + (copper or 0)
		end
	end
	if rides == 0 then return nil end
	local helpers, seen = 0, {}
	if type(l.cut) == "table" then
		for _, c in ipairs(l.cut) do
			local at = type(c) == "table" and num(c.at)
			if at and at >= a and at < b and type(c.clicks) == "table" then
				for who, n in pairs(c.clicks) do
					if not seen[who] and (num(n) or 0) > 0 then seen[who] = true helpers = helpers + 1 end
				end
			end
		end
	end
	local bestHour = top(byHour)
	return { rides = rides, gold = gold, bestHour = bestHour, helpers = helpers }
end

-- One month's recap (see the header).
function Mod.Month(year, month)
	year, month = num(year), num(month)
	if not (year and month) or month < 1 or month > 12 or type(W.db) ~= "table" then return nil end
	local a, b = monthRange(year, month)
	if not a then return nil end
	local all = type(W.db.rides) == "table" and W.db.rides or {}
	local list = tripsIn(all, a, b)
	local out = { year = year, month = month, key = Mod.Key(year, month), name = MONTHS[month], rides = #list,
		places = 0, saved = 0, flightSaved = 0, spent = 0, about = false, newPlaces = {}, streak = 0, tier = 0 }
	-- what was seen before this month (new places)
	-- with the full 100 kept and no trip kept from before this month, older visits are gone: a place
	-- cannot be called new (a later month still has earlier kept trips to compare with)
	local older = false
	local before = {}
	for _, t in ipairs(all) do
		local at = type(t) == "table" and num(t.at)
		if at and at < a then
			older = true
			if not t.unpaid then before[placeKey(t.dest)] = true end
		end
	end
	local cut = #all >= 100 and not older
	local placeN, driverN, driverName, seenPlace = {}, {}, {}, {}
	local lastDay, run = nil, 0
	local hop
	for _, t in ipairs(list) do
		local pk = placeKey(t.dest)
		placeN[pk] = (placeN[pk] or 0) + 1
		if not seenPlace[pk] then
			seenPlace[pk] = placeName(t.dest)
			out.places = out.places + 1
			if not before[pk] and not cut then out.newPlaces[#out.newPlaces + 1] = seenPlace[pk] end
		end
		local dk = t.driverKey or (t.driver and W.Key and W.Key(t.driver))
		if dk then
			driverN[dk] = (driverN[dk] or 0) + 1
			driverName[dk] = t.driver or driverName[dk]
		end
		local saved = num(t.saved) or 0
		if saved > 0 then
			out.saved = out.saved + saved
			if t.savedHow ~= "own" and t.savedHow ~= "shared" then out.about = true end
		end
		if num(t.flightCost) and num(t.flightExact) == 1 then out.flightSaved = out.flightSaved + num(t.flightCost) end
		out.spent = out.spent + math.max(0, num(t.price) or 0)
		-- the longest hop: from the zone booked in to the destination, by world distance
		local c1, x1, y1 = worldOf(t.fromZone)
		local c2, x2, y2 = worldOf(t.dest)
		if c1 and c2 and c1 == c2 then
			local yards = math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)
			if yards > 0 and (not hop or yards > hop.yards) then hop = { from = t.fromZone, to = placeName(t.dest), yards = math.floor(yards + 0.5) } end
		end
		-- the longest run of days in a row
		local day = dayOf(num(t.at))
		if lastDay == day then
		elseif lastDay and day == lastDay + 1 then
			run = run + 1
		else
			run = 1
		end
		lastDay = day
		if run > out.streak then out.streak = run end
	end
	out.longestHop = hop
	local tp = top(placeN)
	out.topPlace = tp and seenPlace[tp] or nil
	local td, tn = top(driverN)
	out.topDriver = td and driverName[td] and (W.Short and W.Short(driverName[td]) or driverName[td]) or nil
	out.topDriverN = tn
	-- the level at the month's end
	local paid = 0
	for _, t in ipairs(all) do
		local at = type(t) == "table" and num(t.at)
		if at and at < b and not t.unpaid then paid = paid + 1 end
	end
	out.tier = type(W.Tier) == "function" and (num(W.Tier(paid)) or 0) or 0
	-- with the full 100 kept, rides before the oldest kept one are gone: the count is a lower bound, so
	-- the level is only known when it is already the top one; otherwise it is hidden (0 shows nothing)
	local topAt = type(W.TIERS) == "table" and W.TIERS[#W.TIERS] and num(W.TIERS[#W.TIERS].at) or nil
	if #all >= 100 and not (topAt and paid >= topAt) then out.tier = 0 end
	-- only the last 100 trips are kept: an older month may be cut short
	local first = all[1]
	out.capped = #all >= 100 and type(first) == "table" and (num(first.at) or 0) > a or false
	out.driver = driverMonth(a, b)
	return out
end
