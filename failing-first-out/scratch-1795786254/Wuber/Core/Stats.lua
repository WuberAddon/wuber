-- Module: Core.Stats
-- Purpose: trips, lifetime totals, W.Stats, rider tiers and milestones (data only).
-- API: W.DayInfo, W.PlaceKey, W.RebuildTotals, W.AddTrip, W.Stats, W.TIERS, W.Tier, W.TierName,
--   W.TierProgress, W.RiderLabel, W.RANKS, W.RankOf, W.MILESTONES, W.MilestoneInfo, W.CheckMilestones
-- Internals: (none)
-- Uses: (none)
-- Later: (none)
-- Events: listens (none); fires MILESTONE
-- Standalone: no
-- Test: tests/core/stats_test.lua
-- From: Core.lua 275-529 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("Core.Stats", {})

---------------------------------------------------------------------------
-- Trips, lifetime totals, stats, rider levels and milestones (data only; UI draws them)
---------------------------------------------------------------------------
-- W.db.rides keeps the last 100 trips; W.db.totals keeps lifetime counts so levels and
-- milestones survive the cap:
--   { rides, spent, saved, savedValue, places = { [placeKey] = true }, placeCount,
--     drivers = { [driverKey] = { name, n } }, firstAt, lastAt, lastDay, streak,
--     nightOwl, weekend, satDay }

-- A local calendar day number, the hour and the weekday (1 Sunday .. 7 Saturday) of a
-- time() value. Without date(): UTC days, no hour or weekday.
local function dayInfo(at)
	at = tonumber(at)
	if not at then return nil end
	if type(date) == "function" then
		local ok, t = pcall(date, "*t", at)
		if ok and type(t) == "table" and t.year then
			local noon
			if type(time) == "function" then
				local ok2, v = pcall(time, { year = t.year, month = t.month, day = t.day, hour = 12 })
				if ok2 and type(v) == "number" then noon = v end
			end
			return math.floor((noon or at) / 86400), t.hour, t.wday
		end
	end
	return math.floor(at / 86400), nil, nil
end
W.DayInfo = dayInfo

local function placeKey(dest)
	dest = tostring(dest or "")
	if W.ExactPlace then
		local p = W.ExactPlace(dest)
		if p then dest = p.name end
	end
	if W.NormPlace then return W.NormPlace(dest) end
	return dest:lower()
end
W.PlaceKey = placeKey

local function newTotals()
	return { paidOnly = true, rides = 0, spent = 0, saved = 0, savedValue = 0, places = {}, placeCount = 0, drivers = {} }
end

-- Adds one trip to the lifetime totals.
local function countTrip(t, trip)
	if type(trip) ~= "table" then return end
	-- a ride ended without paying (End ride, or ended by itself) counts for nothing: no ride,
	-- place, level, milestone or time saved
	if trip.unpaid then return end
	t.rides = t.rides + 1
	t.spent = t.spent + math.max(0, tonumber(trip.price) or 0)
	t.saved = t.saved + math.max(0, tonumber(trip.saved) or 0)
	t.savedValue = t.savedValue + math.max(0, tonumber(trip.savedValue) or 0)
	-- the flight costs a summon spared: only what a flight master showed (exact); a cost
	-- from before that rule is left out (review 2.2 #10: never a number we can't back)
	local fc = tonumber(trip.flightCost)
	if fc and fc > 0 and tonumber(trip.flightExact) == 1 then
		t.flightSaved = (t.flightSaved or 0) + fc
		t.flightRides = (t.flightRides or 0) + 1
	end
	local pk = placeKey(trip.dest)
	if pk ~= "" and not t.places[pk] then
		t.places[pk] = true
		t.placeCount = t.placeCount + 1
	end
	local dk = trip.driverKey or (W.Key and W.Key(trip.driver))
	if dk then
		local e = t.drivers[dk] or { name = trip.driver, n = 0 }
		e.n = e.n + 1
		e.name = trip.driver or e.name
		t.drivers[dk] = e
	end
	local at = tonumber(trip.at)
	if at then
		if not t.firstAt or at < t.firstAt then t.firstAt = at end
		if not t.lastAt or at > t.lastAt then t.lastAt = at end
		local day, hour, wday = dayInfo(at)
		if hour and hour < 5 then t.nightOwl = true end
		if wday == 7 then t.satDay = day end
		if wday == 1 and t.satDay == day - 1 then t.weekend = true end
		if t.lastDay == day then
			-- same day: the streak stands
		elseif t.lastDay == day - 1 then
			t.streak = (t.streak or 0) + 1
			t.lastDay = day
		elseif not t.lastDay or day > t.lastDay then
			t.streak = 1
			t.lastDay = day
		end
	end
end

-- Builds W.db.totals again from the saved trips (first load after the update).
function W.RebuildTotals()
	local db = W.db or W.InitDB()
	local t = newTotals()
	for _, trip in ipairs(db.rides) do countTrip(t, trip) end
	db.totals = t
	return t
end

local function totals()
	local db = W.db or W.InitDB()
	if type(db.totals) ~= "table" then return W.RebuildTotals() end
	return db.totals
end

-- Saves a finished trip: { at = time(), driver, driverKey, dest, price, stars, saved
-- (seconds of flying saved, or nil), savedValue (copper, at the rate then), fromZone,
-- service }. Keeps the last 100 trips; the lifetime totals count every one.
function W.AddTrip(trip)
	local list = (W.db or W.InitDB()).rides
	local t = totals() -- built (from the trips so far) before this one is added: counted once
	list[#list + 1] = trip
	while #list > 100 do table.remove(list, 1) end
	countTrip(t, trip)
end

-- The rider's stats: { rides, places (distinct destinations), spent (copper), saved
-- (seconds), savedValue (copper), favouriteDriver (name), favouriteKey, favouriteCount,
-- firstAt, lastAt, streakDays (days in a row with a ride, up to today or yesterday),
-- nightOwl, weekend (booleans) }.
function W.Stats()
	local t = totals()
	local favKey, fav
	for k, e in pairs(t.drivers) do
		if not fav or e.n > fav.n or (e.n == fav.n and tostring(k) < tostring(favKey)) then favKey, fav = k, e end
	end
	local streak = 0
	if t.lastDay and type(time) == "function" then
		local ok, nowT = pcall(time)
		local today = ok and dayInfo(nowT)
		if today and today - t.lastDay <= 1 then streak = t.streak or 0 end
	end
	return {
		rides = t.rides, places = t.placeCount, spent = t.spent, saved = t.saved,
		savedValue = t.savedValue, favouriteDriver = fav and fav.name or nil, favouriteKey = favKey,
		favouriteCount = fav and fav.n or 0, firstAt = t.firstAt, lastAt = t.lastAt,
		streakDays = streak, nightOwl = t.nightOwl == true, weekend = t.weekend == true,
		flightSaved = t.flightSaved or 0, flightRides = t.flightRides or 0, flightAbout = false,
	}
end

-- Rider levels: Bronze from 3 rides, Silver from 10, Gold from 25.
W.TIERS = { { name = "Bronze", at = 3 }, { name = "Silver", at = 10 }, { name = "Gold", at = 25 } }

-- The rider's level 0..3 (0: none yet), from `rides` or the lifetime total.
function W.Tier(rides)
	rides = tonumber(rides) or totals().rides
	local tier = 0
	for i, t in ipairs(W.TIERS) do
		if rides >= t.at then tier = i end
	end
	return tier
end

-- "Bronze", "Silver", "Gold"; "New rider" for 0.
function W.TierName(t)
	t = tonumber(t) or 0
	local e = W.TIERS[t]
	return e and e.name or "New rider"
end

-- For the level bar: tier, rides, rides where this level began, rides for the next (nil at Gold).
function W.TierProgress()
	local rides = totals().rides
	local tier = W.Tier(rides)
	local from = tier > 0 and W.TIERS[tier].at or 0
	local nextT = W.TIERS[tier + 1]
	return tier, rides, from, nextT and nextT.at or nil
end

-- What a driver sees about a rider: "Gold rider · 31 rides", "3 rides", or "" (round-one
-- riders send neither).
function W.RiderLabel(tier, rides)
	tier, rides = tonumber(tier) or 0, tonumber(rides)
	local parts = {}
	if tier >= 1 and tier <= 3 then parts[#parts + 1] = W.TierName(tier) .. " rider" end
	if rides and rides > 0 then parts[#parts + 1] = rides .. (rides == 1 and " ride" or " rides") end
	return table.concat(parts, " \194\183 ")
end

-- Driver ranks (from verified summons): rung 1..5, title, nextAt (nil on the top rung).
W.RANKS = {
	{ at = 0, title = "Learner" },
	{ at = 10, title = "Cabbie" },
	{ at = 50, title = "Black Cab" },
	{ at = 250, title = "Chauffeur" },
	{ at = 1000, title = "Has The Knowledge" },
}

function W.RankOf(count)
	if type(count) ~= "number" or count ~= count or count < 0 then return nil end
	local rung = 1
	for i = 2, #W.RANKS do
		if count >= W.RANKS[i].at then rung = i end
	end
	local nxt = W.RANKS[rung + 1]
	return rung, W.RANKS[rung].title, nxt and nxt.at or nil
end

-- Milestones: id, name, desc (how to earn it), icon (a Media file name), test(stats).
local function M(id, name, desc, icon, test)
	return { id = id, name = name, desc = desc, icon = icon, test = test }
end
W.MILESTONES = {
	M("first", "First Ride", "Take your first ride.", "ride", function(s) return s.rides >= 1 end),
	M("rides5", "5 Rides", "Take 5 rides.", "star", function(s) return s.rides >= 5 end),
	M("rides10", "10 Rides", "Take 10 rides.", "star", function(s) return s.rides >= 10 end),
	M("rides25", "25 Rides", "Take 25 rides.", "star", function(s) return s.rides >= 25 end),
	M("rides50", "50 Rides", "Take 50 rides.", "star", function(s) return s.rides >= 50 end),
	M("rides100", "100 Rides", "Take 100 rides.", "star", function(s) return s.rides >= 100 end),
	M("explorer", "Explorer", "Ride to 5 different places.", "pin", function(s) return s.places >= 5 end),
	M("globetrotter", "Globetrotter", "Ride to 10 different places.", "pin", function(s) return s.places >= 10 end),
	M("worldwalker", "World Walker", "Ride to 20 different places.", "pin", function(s) return s.places >= 20 end),
	M("hoursaver", "Hour Saver", "Save an hour of flying in total.", "radar", function(s) return s.saved >= 3600 end),
	M("daysaver", "Day Saver", "Save a whole day of flying in total.", "radar", function(s) return s.saved >= 86400 end),
	M("loyal", "Loyal", "Take 5 rides with the same driver.", "check", function(s) return s.favouriteCount >= 5 end),
	M("nightowl", "Night Owl", "Take a ride between midnight and 5 am.", "circle", function(s) return s.nightOwl end),
	M("weekend", "Weekend Warrior", "Ride on a Saturday and the Sunday after it.", "summon", function(s) return s.weekend end),
}

-- Name, how to earn and icon for any milestone id, including level-ups "tier1".."tier3".
function W.MilestoneInfo(id)
	for _, m in ipairs(W.MILESTONES) do
		if m.id == id then return m end
	end
	local n = type(id) == "string" and tonumber(id:match("^tier(%d)$"))
	if n and W.TIERS[n] then
		return { id = id, name = W.TIERS[n].name .. " rider", icon = "badge",
			desc = "Take " .. W.TIERS[n].at .. " rides." }
	end
	return nil
end

-- Marks newly earned milestones (W.db.milestones[id] = time()) and a new level
-- ("tier<n>"). Fires ONE "MILESTONE" event per call: (mainId, ids) - mainId is the level-up
-- if there is one, else the first milestone; ids lists every new one. silent: mark only,
-- no event (the first load backfill). Returns the list of new ids.
function W.CheckMilestones(silent)
	local db = W.db or W.InitDB()
	local s = W.Stats()
	local stamp = 0
	if type(time) == "function" then
		local ok, v = pcall(time)
		if ok and type(v) == "number" then stamp = v end
	end
	local new, main = {}, nil
	for _, m in ipairs(W.MILESTONES) do
		if not db.milestones[m.id] then
			local ok, earned = pcall(m.test, s)
			if ok and earned then
				db.milestones[m.id] = stamp
				new[#new + 1] = m.id
			end
		end
	end
	local tier, seen = W.Tier(s.rides), tonumber(db.tierSeen) or 0
	if tier > seen then
		for n = seen + 1, tier do
			local id = "tier" .. n
			if not db.milestones[id] then
				db.milestones[id] = stamp
				table.insert(new, 1, id)
			end
		end
		main = "tier" .. tier
		db.tierSeen = tier
	end
	if #new > 0 and not silent then W.Fire("MILESTONE", main or new[1], new) end
	return new
end
