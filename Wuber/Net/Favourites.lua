-- Module: Net.Favourites
-- Purpose: Favourites, watched destinations, hidden drivers, "your usual", and the FAV_ONLINE /
--   WATCH_HIT toasts (sets Net.Beacons.noteOnline).
-- API: W.WatchKey, W.IsFav, W.ToggleFav, W.IsWatched, W.ToggleWatch, W.HideDriver,
--   W.ShowAllDrivers, W.Usual, NETK.{TOAST_GAP}
-- Internals: db
-- Uses: Net.Base
-- Later: (none)
-- Events: listens (none); fires DRIVERS, FAV_ONLINE, SETTINGS, WATCH_HIT; sets
--   Net.Beacons.noteOnline
-- Standalone: no
-- Test: tests/net/favourites_test.lua
-- From: Net.lua 2943-3141 (Wuber 2.2.1)
--
---------------------------------------------------------------------------
-- Favourites, watched destinations, hidden drivers, "your usual"
---------------------------------------------------------------------------
-- Toasts: a favourite coming online (not listed, or paused, before) and an open driver to a
-- watched destination are collected for 4 s and fired as ONE merged event each:
--   W.Fire("FAV_ONLINE", driver, count, list)   "Anita is online" / "3 favourites online"
--   W.Fire("WATCH_HIT", driver, count, list)    "A driver to Ratchet is online"
-- driver: the cheapest in list. WATCH_HIT fires once per watched place (list holds that place's drivers only), 6 s apart. Only open drivers (riders never hear the other faction),
-- never in combat (held until it ends), a WATCH_HIT 6 s after a FAV_ONLINE (one toast at a
-- time), and each driver (per destination, for watch) at most once per 10 min, kept in
-- W.db.toastAt with time() so a /reload doesn't repeat them.

local _, W = ...
local Mod = W.Module("Net.Favourites", { "Net.Base" })
local BaseMod = W.Mod("Net.Base")
local BeaconsMod = W.Mod("Net.Beacons")
local NETK, clock, now = BaseMod.NETK, BaseMod.clock, BaseMod.now
local num = W.Num

NETK.TOAST_GAP = 600
local pendingFav, pendingWatch = {}, {}
local toastTimer, toastCombat = false, false

local function db() return W.db or W.InitDB() end

local function recent(what)
	local t = num(db().toastAt[what])
	return t ~= nil and clock() - t < NETK.TOAST_GAP and clock() >= t
end

local function byPrice(a, b)
	if (a.price or 0) ~= (b.price or 0) then return (a.price or 0) < (b.price or 0) end
	return tostring(a.key) < tostring(b.key)
end

-- The key a destination is watched under ("Booty Bay", "bb" -> "booty bay").
function W.WatchKey(dest)
	return W.PlaceKey(dest)
end

local function flushToasts()
	toastTimer = false
	if W.InCombat() then
		if not toastCombat then
			toastCombat = true
			W.AfterCombat(function()
				toastCombat = false
				flushToasts()
			end)
		end
		return
	end
	local d0 = db()
	local stamp = clock()
	for what, t in pairs(d0.toastAt) do -- forget old ones
		if type(t) ~= "number" or stamp - t > 86400 or t > stamp + 60 then d0.toastAt[what] = nil end
	end
	local favs, seen = {}, {}
	for key in pairs(pendingFav) do
		local d = W.drivers[key]
		if d and d.state == "open" and W.IsFav(key) and not W.IsHidden(key) and not recent("fav:" .. key) then
			favs[#favs + 1] = d
			seen[key] = true
			d0.toastAt["fav:" .. key] = stamp
		end
	end
	pendingFav = {}
	local hits = {}
	for key, wk in pairs(pendingWatch) do
		local d = W.drivers[key]
		local what = "watch:" .. wk .. ":" .. key
		local favToasted = W.IsFav(key) and recent("fav:" .. key) -- told already, as a favourite
		if d and d.state == "open" and not seen[key] and not favToasted and not W.IsHidden(key) and d0.watch[wk]
			and W.WatchKey(d.dest) == wk and not recent(what) then
			hits[#hits + 1] = d
			d0.toastAt[what] = stamp
		end
	end
	pendingWatch = {}
	table.sort(favs, byPrice)
	table.sort(hits, byPrice)
	if #favs > 0 then W.Fire("FAV_ONLINE", favs[1], #favs, favs) end
	-- one toast per watched place (each names its own place and counts its own drivers), 6 s apart
	local order, byPlace = {}, {}
	for _, d in ipairs(hits) do
		local wk = W.WatchKey(d.dest)
		if not byPlace[wk] then byPlace[wk] = {}; order[#order + 1] = wk end
		local g = byPlace[wk]
		g[#g + 1] = d
	end
	for i, wk in ipairs(order) do
		local g = byPlace[wk]
		local function fireHits() -- the toast is dropped in combat: hold this one until it ends
			W.AfterCombat(function() W.Fire("WATCH_HIT", g[1], #g, g) end)
		end
		local delay = (i - 1 + (#favs > 0 and 1 or 0)) * 6
		if delay > 0 then W.After(delay, fireHits) else fireHits() end
	end
end

-- Called for every beacon heard (after the driver list changed). was: the driver's state,
-- dest and whether it was listed before this beacon (nil: not known).
BeaconsMod.noteOnline = function(d, was)
	if d.state ~= "open" then return end
	local d0 = db()
	local queued = false
	local wasOnline = was and was.listed and was.state ~= "paused"
	if not wasOnline and d0.favs[d.key] then
		pendingFav[d.key] = true
		queued = true
	end
	local wk = W.WatchKey(d.dest)
	if wk ~= "" and d0.watch[wk] then
		local wasThere = was and was.listed and was.state == "open" and W.WatchKey(was.dest) == wk
		if not wasThere then
			pendingWatch[d.key] = wk
			queued = true
		end
	end
	if queued and not toastTimer then
		toastTimer = true
		W.After(4, flushToasts)
	end
end

-- Whether a driver (key or name) is a favourite.
function W.IsFav(key)
	key = W.Key(key)
	return key ~= nil and db().favs[key] == true
end

-- Makes a driver a favourite or not (heart on cards and pins). Fires "SETTINGS" ("favs").
-- Returns the new state.
function W.ToggleFav(key)
	key = W.Key(key)
	if not key then return false end
	local on = not W.IsFav(key)
	db().favs[key] = on or nil
	W.Fire("SETTINGS", "favs")
	return on
end

-- Whether the rider asked to be told about drivers to this destination.
function W.IsWatched(dest)
	local wk = W.WatchKey(dest)
	return wk ~= "" and db().watch[wk] == true
end

-- "Tell me when a driver to X comes online": on or off (stays on until turned off; toasts
-- are rate-limited). Fires "SETTINGS" ("watch"). Returns the new state.
function W.ToggleWatch(dest)
	local wk = W.WatchKey(dest)
	if wk == "" then return false end
	local on = not W.IsWatched(dest)
	db().watch[wk] = on or nil
	W.Fire("SETTINGS", "watch")
	return on
end

-- Hides a driver (on = true, the default) or shows them again (on = false): W.db.hidden[key].
-- A hidden driver has no card, pin, toast or nameplate badge. Fires "SETTINGS" ("hidden")
-- and "DRIVERS". Returns the new state.
function W.HideDriver(key, on)
	key = W.Key(key)
	if not key then return false end
	if on == nil then on = true end
	on = on and true or false
	db().hidden[key] = on or nil
	if on then
		local d = W.drivers[key]
		if d then
			W.hiddenDrivers[key] = d
			W.drivers[key] = nil
		end
		pendingFav[key], pendingWatch[key] = nil, nil
	else
		local d = W.hiddenDrivers[key]
		W.hiddenDrivers[key] = nil
		if d and now() - (d.heard or 0) <= NETK.DRIVER_TTL then W.drivers[key] = d end
	end
	W.Fire("SETTINGS", "hidden")
	W.Fire("DRIVERS")
	return on
end

-- Settings' "Hidden drivers: show all again". Returns how many were hidden.
function W.ShowAllDrivers()
	local n = 0
	for key in pairs(db().hidden) do
		n = n + 1
		W.HideDriver(key, false)
	end
	return n
end

-- The rider's most frequent trip (driver and destination; the latest wins a tie), or nil
-- with no trips: { driverKey, driver (name), dest, count, online (the driver table when
-- that driver is listed and open now, else nil) }.
function W.Usual()
	local counts, best, bestN, bestAt = {}, nil, 0, 0
	for i, t in ipairs(db().rides) do
		local key = type(t) == "table" and (t.driverKey or W.Key(t.driver))
		if key and t.dest and not t.unpaid then -- an ended-unpaid ride is no usual
			local id = key .. "|" .. W.PlaceKey(t.dest)
			local c = counts[id] or { driverKey = key, driver = t.driver, dest = t.dest, count = 0 }
			c.count = c.count + 1
			c.driver, c.dest = t.driver or c.driver, t.dest
			counts[id] = c
			if c.count > bestN or (c.count == bestN and i >= bestAt) then best, bestN, bestAt = c, c.count, i end
		end
	end
	if not best then return nil end
	local d = W.drivers[best.driverKey]
	local out = { driverKey = best.driverKey, driver = best.driver, dest = best.dest, count = best.count }
	if d and d.state == "open" and not W.IsHidden(best.driverKey) then out.online = d end
	return out
end

-- for the Net modules that load after this one (REFACTOR-MAP section 2)
Mod.db = db
