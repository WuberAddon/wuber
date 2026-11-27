-- Module: Net.Beacons
-- Purpose: D/X/Q both ways: drivers heard by riders (heardBeacon, W.DriversSorted,
--   W.Prominence, W.Ping) and the driver side (provider/engine, W.SendBeacon, the
--   whisper push to riders, Q answers, W.SetDriving).
-- API: W.hiddenDrivers, W.ExpireDrivers, W.IsHidden, W.DriversChanged, W.DriversSorted,
--   W.Prominence, CX.ping, W.Ping, W.provider, W.engine, W.DriverImpl, W.SetEngine,
--   W.SetLocalDriver, W.Provider, W.DriverBeacon, W.BeaconFor, W.PriceOk, W.RealmHere,
--   W.CleanRealm, CX.isolated, CX.beacon, CX.found, W.SendBeacon, W.RiderBooked,
--   W.SetDriving, NETK.{RIDER_KEEP,PUSH_MAX,REPLY_QUIET,REPLY_CAP,STAGGER_MAX,BOOKED_FOR}
-- Internals: beaconFor, chanFlag, dangerLevel, heardBeacon, heardPing, heardWhisperPing, impl, tickBeacon,
--   tickPass (the passphrase flag to whisper riders riding with us), whisperBeacon; hook slots noteOnline (set by Net.Favourites), noteDirectory (Net.Discovery),
--   noteInvite (nothing sets it since round 12, when community invites were forbidden; still
--   called when set)
-- Uses: Net.Base, Net.Community, Net.Transport
-- Later: FX.Emblem (W.EmblemHeard: beacon D field 20, W.EmblemFlag: our D field 20 and Q field 2)
-- Events: listens (none); fires ADVERT, DRIVERS, ENGINE, SETTINGS; sets Net.Base.onJoined
-- Standalone: no
-- Test: tests/net/beacons_test.lua
-- From: Net.lua 1174-1829 (Wuber 2.2.1)
--
---------------------------------------------------------------------------
-- Drivers (what a rider hears)
---------------------------------------------------------------------------

local _, W = ...
local Mod = W.Module("Net.Beacons", { "Net.Base", "Net.Community", "Net.Transport" })
local BaseMod = W.Mod("Net.Base")
local CommunityMod = W.Mod("Net.Community")
local TransportMod = W.Mod("Net.Transport")
local NETK, STATES, call, clamp, fb = BaseMod.NETK, BaseMod.STATES, BaseMod.call, BaseMod.clamp, BaseMod.fb
local localInt, netInt, now, rememberSeen = BaseMod.localInt, BaseMod.netInt, BaseMod.now, BaseMod.rememberSeen
local CX, comm = CommunityMod.CX, CommunityMod.comm
local whisperKind = TransportMod.whisperKind
local plain, str, num = W.Plain, W.Str, W.Num

W.hiddenDrivers = W.hiddenDrivers or {} -- beacons of hidden drivers (shown again at once if unhidden)

-- Drops drivers not heard from for 150 s. Fires "DRIVERS" if any went.
function W.ExpireDrivers()
	local t, gone = now(), false
	for key, d in pairs(W.drivers) do
		if t - (d.heard or 0) > NETK.DRIVER_TTL then
			W.drivers[key] = nil
			gone = true
		end
	end
	for key, d in pairs(W.hiddenDrivers) do
		if t - (d.heard or 0) > NETK.DRIVER_TTL then W.hiddenDrivers[key] = nil end
	end
	if gone then W.Fire("DRIVERS") end
	return gone
end

-- Whether the rider hid this driver ("Hide this driver" on the card's menu).
function W.IsHidden(key)
	key = W.Key(key)
	local h = W.db and W.db.hidden
	return key ~= nil and type(h) == "table" and h[key] == true
end
local ownIsHidden = W.IsHidden
-- (speed) true when some driver may be hidden; false only when W.IsHidden is this file's own and nobody is in the list,
-- so the per-driver lookups can be skipped (a replaced W.IsHidden is always asked)
local function maybeHidden()
	if W.IsHidden ~= ownIsHidden then return true end
	local h = W.db and W.db.hidden
	return type(h) == "table" and next(h) ~= nil
end

-- "DRIVERS" once for a burst of beacons: 80 beacons in 2 s make
-- one map / list / nameplate pass, not 80. A tenth of a second later.
local driversSoon = false
function W.DriversChanged()
	if driversSoon then return end
	driversSoon = true
	W.After(0.1, function()
		driversSoon = false
		W.Fire("DRIVERS")
	end)
end


-- D: dest, mapID, x, y, price, service, state, team, seats, faction, ver, badge, queue
-- A driver table: { key, name, addr, dest (the name to show: a known place, the driver's
-- map name, the place at its position, or "Unknown"), destWire (the beaconed text, used in
-- R), destOk (destWire passed the whitelist: whisper it as is), mapID, x, y, price,
-- service (anti-spam filtered), serviceRefused, state, team, seats, faction, ver, badge
-- ("" none), queue (nil if not sent), creator (W.CREATOR, checked locally), proto, heard,
-- danger (2.3.0 field 18: 0, 1 enemy players seen, 2 a fight), dangerAt (GetTime() of it),
-- dangerSecs (how long before the beacon, as sent), avgSummon (2.3.4 field 21: the driver's average
-- summon in whole seconds, 10..900, or nil), rank (2.4 field 22: verified summons, 1..99999, or nil) }
-- via: "CHANNEL", or "WHISPER" (the whisper fallback: the driver answering our Q, or telling
-- us of a change). Field 14 (whisper fallback): "1" when the driver hears others on the channel.
local function heardBeacon(addr, name, key, f, proto, via, viaComm)
	fb.unconfirmed[key] = nil -- the driver himself: confirmed (or filtered out below)
	local faction, mine = f[10], W.Faction()
	if (faction == "H" or faction == "A") and mine ~= "" and faction ~= mine then
		-- the other faction: not a driver for us
		fb.rejected[key] = now() -- and not taken from a K again for 30 min (no Q, D, Q... each K)
		if W.drivers[key] then
			W.drivers[key] = nil
			W.Fire("DRIVERS")
		end
		return
	end
	local old = W.drivers[key] or W.hiddenDrivers[key]
	local was = old and { state = old.state, dest = old.dest, listed = W.drivers[key] ~= nil }
	if via == "WHISPER" and not (was and was.listed) then
		-- asked by whisper only every few minutes (window closed): a driver who dropped off
		-- the list in between was online all along (no "is online" toast each time)
		local m = fb.lastBeacon[key]
		if m and now() - m.at < 330 then was = { state = m.state, dest = m.dest, listed = true } end
	end
	local d = old or {}
	d.key, d.name, d.addr = key, name, addr
	local mapID = W.Int(f[2])
	d.mapID = (mapID and mapID > 0) and mapID or nil
	local x, y = W.Int(f[3]), W.Int(f[4])
	d.x = x and clamp(x, 0, 1000) / 1000 or nil
	d.y = y and clamp(y, 0, 1000) / 1000 or nil
	local wire = W.CleanDest(f[1])
	d.destWire = wire ~= "" and wire or nil
	d.dest, d.destOk = W.ValidDest(wire, d.mapID, d.x, d.y)
	if not d.destWire then d.destWire = d.dest end
	d.price = netInt(f[5], 0, NETK.MAX_PRICE, 0)
	if d.price < W.MIN_PRICE then
		-- below the network's lowest fare: not shown to riders at all
		fb.rejected[key] = now()
		W.hiddenDrivers[key] = nil
		if W.drivers[key] then
			W.drivers[key] = nil
			W.Fire("DRIVERS")
		end
		return
	end
	d.service, d.serviceRefused = W.CleanService(f[6], name)
	d.state = STATES[f[7] or ""] and f[7] or "paused"
	d.team = netInt(f[8], 1, 3, 1)
	d.seats = netInt(f[9], 0, 40, 0)
	d.faction = (faction == "H" or faction == "A") and faction or nil
	local ver = (f[11] or ""):gsub("%-.*$", ""):gsub("[^%d%.]", "") -- "2.3.3-rc1": 2.3.3, never 2.3.31
	d.ver = ver ~= "" and ver:sub(1, 12) or nil
	if W.HeardVersion then W.Safe("version", W.HeardVersion, key, f[11]) end -- round 11: "a newer Wuber is out" (Net.Update)
	d.badge = W.ValidBadge(f[12])
	d.queue = netInt(f[13], 0, 40, nil)
	d.creator = W.IsCreator(key)
	d.proto = proto
	d.heard = now()
	local realm = W.CleanRealm(f[15])
	d.realm = realm ~= "" and realm or nil -- the driver's internal realm (shown only)
	d.via = (via == "WHISPER") and "WHISPER" or "CHANNEL"
	d.viaComm = (d.via == "CHANNEL" and viaComm) and true or nil -- last heard over the Wuber community
	if d.via == "WHISPER" then
		d.whisperAt = d.heard
		fb.answeredAt[key] = d.heard
		if f[14] == "1" then fb.peerOnChanAt = d.heard end
	end
	fb.lastBeacon[key] = { state = d.state, dest = d.dest, at = d.heard }
	-- heard from the driver himself: may go in a K (only a client that says its version: a test
	-- double or anything that doesn't is never passed on)
	d.unlisted = f[16] == "0" or nil -- opted out of the starter list (Settings)
	-- 2.1: the Warlock who summons for a runner of another class ("Summoned by Bea")
	local summoner = f[17] and W.CleanName(f[17])
	d.summoner = (summoner and summoner ~= "" and W.Key(summoner)) and summoner or nil
	-- 2.3.0: field 18 "level:seconds" (PvP near the summon spot: 1 enemy players seen, 2 a
	-- fight); absent or garbled: 0
	local lvl, secs = (f[18] or ""):match("^(%d):(%d+)$")
	lvl, secs = W.Int(lvl), W.Int(secs)
	d.danger = lvl and clamp(lvl, 0, 2) or 0
	d.dangerAt = (d.danger > 0 and secs) and (d.heard - clamp(secs, 0, 3600)) or nil
	d.dangerSecs = d.dangerAt and clamp(secs, 0, 3600) or nil
	-- round 9: field 19 "1" = this driver shows riders the ride passphrase (absent, an older driver: off)
	d.showPass = f[19] == "1" or nil
	-- 2.3.2: field 20 "0" hides a listed Pioneer's emblem (it can never give one)
	if W.EmblemHeard then W.Safe("emblem", W.EmblemHeard, key, f[20]) end
	-- 2.3.4 (FEAT-01): field 21 = the driver's average summon, whole seconds request to arrival (3+ rides);
	-- absent (older drivers, fewer rides), not plain digits or outside 10..900: not sent, never clamped
	local avg = (f[21] or ""):match("^%d+$") and W.Int(f[21]) or nil
	d.avgSummon = (avg and avg >= 10 and avg <= 900) and avg or nil
	-- 2.4: field 22 = the driver's verified summons (1..99999); absent, not plain digits or out of range: nil
	local rank = (f[22] or ""):match("^%d+$") and W.Int(f[22]) or nil
	d.rank = (rank and rank >= 1 and rank <= 99999) and rank or nil
	d.ruleset = W.RulesetOf(d.realm) or W.Ruleset()
	if d.ver then
		fb.direct[key] = { name = name, at = d.heard }
		rememberSeen(key, name, addr, d.ruleset, d.unlisted)
		if Mod.noteDirectory then Mod.noteDirectory(key, name, d) end
	end
	local adv = fb.advertHeard and fb.advertHeard[key]
	if adv and not adv.confirmed and not (was and was.listed) then
		adv.confirmed = true
		W.Fire("ADVERT", "confirmed", name)
	end
	-- round 9 (C10): the ride keeps its driver's passphrase flag, so the line doesn't vanish when
	-- this entry expires (whisper fallback) or the driver closes while finishing the group
	local ride = W.ride
	if type(ride) == "table" and ride.driverKey == key then ride.showPass = d.showPass == true or nil end
	if W.IsHidden(key) then
		-- kept aside: no card, pin, toast or nameplate badge
		W.hiddenDrivers[key] = d
		if W.drivers[key] then
			W.drivers[key] = nil
			W.Fire("DRIVERS")
		end
		return
	end
	W.hiddenDrivers[key] = nil
	W.drivers[key] = d
	W.DriversChanged()
	if Mod.noteOnline then Mod.noteOnline(d, was) end
	if Mod.noteInvite then Mod.noteInvite(d) end
end

-- All known drivers, sorted by price, the founder first among equal prices, then by name
-- (the tables themselves: read only). Hidden drivers are never in the list.
function W.DriversSorted()
	local list = {}
	local anyHidden = maybeHidden() -- nobody hidden (the usual): no key needs looking up
	for key, d in pairs(W.drivers) do
		if not (anyHidden and W.IsHidden(key)) then list[#list + 1] = d end
	end
	table.sort(list, function(a, b)
		local pa, pb = a.price or 0, b.price or 0
		if pa ~= pb then return pa < pb end
		local ca, cb = a.creator == true, b.creator == true
		if ca ~= cb then return ca end
		local na, nb = tostring(a.name):lower(), tostring(b.name):lower()
		if na ~= nb then return na < nb end
		return tostring(a.key) < tostring(b.key)
	end)
	return list
end

-- How strongly a driver's card and pin glow: glow 0..1, isCreator. Open drivers are ranked
-- by price (the cheapest 0.7 down to 0.2 for the dearest; a lone open driver 0.7); busy and
-- paused drivers 0.15; the founder always 1.0, brighter than anyone.
function W.Prominence(d)
	if type(d) ~= "table" then return 0, false end
	if d.creator or W.IsCreator(d.key) then return 1, true end
	if d.state ~= "open" then return 0.15, false end
	local n, cheaper = 0, 0
	local price = d.price or 0
	local anyHidden = maybeHidden()
	for key, o in pairs(W.drivers) do
		if o.state == "open" and not (anyHidden and W.IsHidden(key)) then
			n = n + 1
			if (o.price or 0) < price then cheaper = cheaper + 1 end
		end
	end
	if n <= 1 then return 0.7, false end
	return clamp(0.2 + 0.5 * (1 - cheaper / (n - 1)), 0.2, 0.7), false
end

local lastPing, lastQHeard = -1000, -1000

-- Q over the channel. Not sent within 20 s of our own Q or of hearing someone else's (the
-- drivers are answering that one).
-- The community copy of a Q: at most once a minute, not within 20 s of a Q heard there.
function CX.ping(t)
	if t - comm.lastQ < CX.Q_GAP or t - comm.lastQHeard < NETK.PING_GAP then return false end
	local emblemOff = W.EmblemFlag and W.EmblemFlag() -- 2.3.2: field 2 "0" (a hidden Pioneer emblem)
	local sent
	if emblemOff then sent = CX.send("Q", "", emblemOff) else sent = CX.send("Q") end
	if not sent then return false end
	comm.lastQ = t
	return true
end

local function channelPing()
	local onNet, onComm = W.OnNetwork(), W.CommunityIndex() ~= nil
	if not onNet and not onComm then return false, "offline" end
	local t = now()
	local wait = NETK.PING_GAP - (t - lastPing)
	if wait > 0 then return false, math.ceil(wait) end
	local netRecent = not onNet or t - lastQHeard < NETK.PING_GAP
	local commRecent = not onComm or t - comm.lastQHeard < NETK.PING_GAP
	if netRecent and commRecent then return true, "recent" end
	lastPing = t
	if not netRecent then
		local emblemOff = W.EmblemFlag and W.EmblemFlag() -- 2.3.2: field 2 "0" (a hidden Pioneer emblem)
		if emblemOff then W.SendChannel("Q", "", emblemOff) else W.SendChannel("Q") end
	end
	if not commRecent then CX.ping(t) end
	return true
end

-- Asks every driver to send a beacon now ("Ping drivers"): Q over the channel, and by
-- whisper to the drivers we know but haven't heard there lately (W.WhisperRound).
-- Returns true when sent; true, "recent" when someone else just asked; false, "offline"
-- off the network (unless a whispered Q went out); false, seconds to wait.
function W.Ping()
	local n = 0
	if W.WhisperRound then n = W.WhisperRound("full", true) or 0 end
	local sent, why = channelPing()
	if not sent and n > 0 then return true end -- asked by whisper at least
	return sent, why
end

---------------------------------------------------------------------------
-- Being a driver: beacons
---------------------------------------------------------------------------

W.provider = nil
W.engine = nil
local localDriver = nil

-- Who drives for this client, if anyone: an external provider (another addon, through
-- WuberAPI.SetDriver) wins over Wuber's own engine (W.Drive, set by W.SetEngine). With
-- either, Net leaves requests to it: no PriceOk check, no 30 s auto-decline, no chat-only
-- "WTB summon to" requests (the engine reads whispers itself).
local function impl()
	if type(W.provider) == "table" then return W.provider end
	if type(W.engine) == "table" then return W.engine end
	return nil
end
W.DriverImpl = impl

-- The built-in driver engine (Drive_Net.lua) attaches here, with the same table shape as a
-- provider: { name, beacon, onRequest, onCancel, onRating }. nil detaches it. W.Provider()
-- still names only an external provider. Fires "ENGINE". Returns true, or false.
function W.SetEngine(t)
	if t ~= nil and type(t) ~= "table" then return false end
	W.engine = t
	W.Fire("ENGINE", t)
	return true
end

-- Driver.lua hands over fn; fn() returns the beacon table (named keys, as a provider's
-- beacon) or nil while offline. nil removes it. Not used while a provider is set.
function W.SetLocalDriver(fn)
	if fn ~= nil and type(fn) ~= "function" then return false end
	localDriver = fn
	return true
end

-- The name of the driver addon in charge (its provider.name), or nil.
function W.Provider()
	local p = W.provider
	if type(p) ~= "table" then return nil end
	return str(p.name) or "another addon"
end

local function pick(t, key, index)
	local v = plain(t[key])
	if v == nil then v = plain(t[index]) end
	return v
end

-- An average summon in whole seconds (FEAT-01, D field 21), or nil outside 10..900: never clamped.
local function summonSecs(v)
	v = localInt(v)
	return (v and v >= 10 and v <= 900) and v or nil
end

-- Verified summons (2.4, D field 22), whole number 1..99999, else nil: never clamped.
local function rankCount(v)
	v = localInt(v)
	return (v and v >= 1 and v <= 99999) and v or nil
end

-- A beacon's PvP level (2.3.0, Drive.Danger through the engine's beacon): 0, 1 or 2.
local function dangerLevel(v)
	v = localInt(v)
	return v and clamp(v, 0, 2) or 0
end

-- A beacon table made safe. Named keys (the same nine in order are also read), plus
-- round two's badge (an id from W.BADGES; nil: this character's W.Char().badge) and queue
-- (riders waiting 0..40; nil: Wuber's own driver mode counts its requests, a provider's is
-- left out). The result also carries destShown (the dest as riders will show it) and
-- serviceRefused (why the service name was refused by the anti-spam filter, or nil).
local function normaliseBeacon(b)
	b = plain(b)
	if type(b) ~= "table" then return nil end
	local dest = W.CleanDest(pick(b, "dest", 1))
	if dest == "" then dest = W.DestHere() end
	local mapID, x, y = localInt(pick(b, "mapID", 2)), num(pick(b, "x", 3)), num(pick(b, "y", 4))
	if not (mapID and x and y) then
		local m, mx, my = W.MyPosition()
		mapID, x, y = mapID or m, x or mx, y or my
	end
	local state = str(pick(b, "state", 7))
	local service, refused = W.CleanService(pick(b, "service", 6), W.Me())
	local badge = plain(b.badge)
	if badge == nil then badge = W.Char().badge end
	local queue = localInt(plain(b.queue))
	if queue == nil and not impl() then queue = #W.incoming end
	local cleanMap = (mapID and mapID > 0) and mapID or nil
	-- opted out of the starter list: the beacon's own unlisted = true, else this character's setting
	local unlisted = plain(b.unlisted)
	if unlisted == nil then unlisted = W.Char().starter == false end
	return {
		only = type(b.only) == "table" and b.only or nil, -- a private beacon: see beaconFor
		unlisted = unlisted == true or nil,
		summoner = str(plain(b.summoner)) and W.CleanName(str(plain(b.summoner))) or nil,
		danger = dangerLevel(plain(b.danger)),
		dangerSecs = clamp(localInt(plain(b.dangerSecs)) or 0, 0, 3600),
		showPass = plain(b.showPass) == true or nil, -- round 9: riders see the ride passphrase
		-- FEAT-01: the engine's average summon (D field 21); a provider addon's beacon never carries one
		avgSummon = (not W.provider) and summonSecs(plain(b.avgSummon)) or nil,
		-- 2.4: the engine's verified summons (D field 22); a provider addon's beacon never carries one
		rank = (not W.provider) and rankCount(plain(b.rank)) or nil,
		dest = dest,
		destShown = (W.ValidDest(dest, cleanMap, x, y)),
		serviceRefused = refused,
		badge = W.ValidBadge(badge),
		queue = queue and clamp(queue, 0, 40) or nil,
		mapID = (mapID and mapID > 0) and mapID or nil,
		x = x and clamp(x, 0, 1) or nil,
		y = y and clamp(y, 0, 1) or nil,
		price = clamp(localInt(pick(b, "price", 5)) or 0, W.MIN_PRICE, NETK.MAX_PRICE),
		service = service,
		state = STATES[state or ""] and state or "open",
		team = clamp(localInt(pick(b, "team", 8)) or 1, 1, 3),
		seats = clamp(localInt(pick(b, "seats", 9)) or 0, 0, 40),
	}
end

-- What this client would beacon as a driver: { dest, mapID, x, y, price, service, state,
-- team, seats, badge, queue, destShown, serviceRefused } from the provider if one is set,
-- else from Driver.lua; nil when not driving.
function W.DriverBeacon()
	local fn
	local p = impl()
	if p then fn = p.beacon else fn = localDriver end
	if type(fn) ~= "function" then return nil end
	local ok, b = pcall(fn)
	if not ok then
		W.Error("beacon", b)
		return nil
	end
	return normaliseBeacon(b)
end

-- The beacon a rider (key) may see, or nil (not driving, for them). A private beacon (b.only
-- = { [key] = name }: the test addon's test mode, review 2.2 #3) is off the public network:
-- no channel, community, answers, pushes or requests from anyone but the keys it names.
local function beaconFor(key)
	local b = W.DriverBeacon()
	if b and b.only and not (key and b.only[key]) then return nil end
	return b
end
W.BeaconFor = beaconFor

local beacon = { online = false, sig = nil, at = -1000, nextAt = 0, pending = false }
local beaconedPrices = {} -- price -> when last beaconed

local function signature(b) -- position alone is not a change (a queue change is, within the 5 s gap)
	return table.concat({ b.dest, tostring(b.mapID), b.price, b.service, b.state, b.team, b.seats,
		b.badge or "", tostring(b.queue), b.unlisted and "u" or "", b.summoner or "", b.danger or 0, b.showPass and "s" or "" }, "|")
	-- (2.4) the verified count (b.rank) is not part of it, like the average summon time: a new count rides the next
	-- regular beacon, it never sends one of its own
end

-- Whether a request at `price` is fair: at least our price now, or a price we beaconed in
-- the last 150 s (the rider saw that one).
function W.PriceOk(price, current)
	price = localInt(price) or 0
	if price >= (current or 0) then return true end
	local at = beaconedPrices[price]
	return at ~= nil and now() - at <= NETK.DRIVER_TTL
end

-- Whether we hear anyone else on the channel (sent as D's field 14, for the whisper
-- fallback's rejoin check): "1" or "0".
local function chanFlag()
	local t = fb.chanOthersAt
	return (t ~= nil and now() - t < 180 and W.OnNetwork()) and "1" or "0"
end

-- Our internal realm as the game names it ("CAMWOW EU4 Realm 7"; Forever runs several per
-- ruleset, and the channel reaches only our own), cleaned to letters, digits and spaces,
-- 32 bytes at most; "" when unknown. Sent as D's field 15, for /wuber status (no logic).
function W.RealmHere()
	local r = type(GetRealmName) == "function" and str(call(GetRealmName)) or nil
	return W.CleanRealm(r)
end

function W.CleanRealm(r)
	r = str(r)
	if not r then return "" end
	r = r:gsub("[^%w ]", ""):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
	return r:sub(1, 32)
end

-- The fields of a D for beacon table b. Fields 17-22 only up to the last one in use (each "" when
-- unused below it), so a beacon without them is as before: 17 the summoner, 18 (2.3.0, PvP
-- "level:seconds") only while there is danger, 19 (round 9) "1" = riders see the ride passphrase,
-- 20 (2.3.2) "0" = this Pioneer hid their emblem (FX.Emblem; hide-only), 21 (2.3.4, FEAT-01) the
-- driver's average summon in whole seconds (only with 3 or more whole rides), 22 (2.4) the
-- driver's verified summons (1..99999, omitted when 0).
local function beaconArgs(b)
	local x = b.x and math.floor(b.x * 1000 + 0.5) or nil
	local y = b.y and math.floor(b.y * 1000 + 0.5) or nil
	local t = { b.dest, b.mapID, x, y, b.price, b.service, b.state, b.team, b.seats, W.Faction(),
		W.VERSION, b.badge, b.queue, chanFlag(), W.RealmHere(), b.unlisted and "0" or "1" }
	local tail = { b.summoner, (b.danger or 0) > 0 and (b.danger .. ":" .. (b.dangerSecs or 0)) or nil,
		b.showPass and "1" or nil, (W.EmblemFlag and W.EmblemFlag()) or nil, b.avgSummon, b.rank }
	local last = 16
	for i = 1, 6 do if tail[i] ~= nil then last = 16 + i end end
	for i = 17, last do
		local v = tail[i - 16]
		if v == nil then v = "" end
		t[i] = v
	end
	return unpack(t, 1, last)
end

-- Whether WuberNet looks cut off: not joined, or joined a minute or more and nobody but
-- ourselves heard there for 3 min (the community then gets every beacon).
function CX.isolated()
	if not W.OnNetwork() then return true end
	local since = fb.joinedAt
	if not since or now() - since < 60 then return false end
	return fb.chanOthersAt == nil or now() - fb.chanOthersAt >= 180
end

-- The community copy of beacon b (see "The Wuber community" for when).
function CX.beacon(b, changed)
	if not b or not W.CommunityIndex() then return false end
	local t = now()
	if not (changed or comm.force or not comm.online or CX.isolated() or t - comm.lastD >= CX.EVERY) then return false end
	if not CX.send("D", beaconArgs(b)) then return false end
	comm.force, comm.online, comm.lastD = false, true, t
	return true
end

-- The community channel just became usable: ask the drivers there, and beacon there.
function CX.found()
	comm.online = false
	CX.ping(now())
	local b = beaconFor(nil)
	if b then
		beaconedPrices[b.price] = now()
		CX.beacon(b, true)
	end
end

-- Sends our beacon (D) now, or once 5 s have passed since the last; or X once if we have
-- just stopped driving. Returns whether a D was sent or is on its way.
function W.SendBeacon()
	local b = beaconFor(nil)
	if not b then
		if beacon.online then
			beacon.online, beacon.sig = false, nil
			W.SendChannel("X")
		end
		if comm.online then
			comm.online = false
			CX.send("X")
		end
		return false
	end
	if not (W.OnNetwork() or W.CommunityIndex()) then return false end
	local wait = NETK.BEACON_GAP - (now() - beacon.at)
	if beacon.online and wait > 0 then
		if not beacon.pending then
			beacon.pending = true
			W.After(wait, function()
				beacon.pending = false
				W.SendBeacon()
			end)
		end
		return true
	end
	local changed = not beacon.online or signature(b) ~= beacon.sig
	W.SendChannel("D", beaconArgs(b))
	CX.beacon(b, changed)
	beacon.online, beacon.sig, beacon.at = true, signature(b), now()
	beacon.nextAt = now() + NETK.BEACON_EVERY + (math.random() * 2 - 1) * NETK.BEACON_JITTER
	beaconedPrices[b.price] = now()
	return true
end

---------------------------------------------------------------------------
-- Being a driver: the whisper fallback (riders who can't hear us on the channel)
---------------------------------------------------------------------------

NETK.RIDER_KEEP = 330   -- a rider who whispered us a Q gets our changes for this long (5.5 min: riders ask a quiet driver every 5 min)
NETK.PUSH_MAX = 25      -- ... at most this many riders (the latest; was 10)
NETK.REPLY_QUIET = 15   -- one whispered answer per rider per this many seconds
NETK.REPLY_CAP = 10     -- whispered answers in any 15 s at once (more are staggered, below)
NETK.STAGGER_MAX = 24   -- answers past the cap: one about a second apart, at most this many more
NETK.BOOKED_FOR = 600   -- a rider who booked with us gets no answers or pushes for this long

-- Our beacon by addon whisper to one rider. Returns whether it was queued.
local function whisperBeacon(addr, b)
	if not b then return false end
	if not whisperKind(addr, "D", beaconArgs(b)) then return false end
	beaconedPrices[b.price] = now()
	return true
end

-- The riders who whispered us a Q in the last 5.5 min, the latest first (at most 10).
local function recentRiders()
	local t, list = now(), {}
	for key, r in pairs(fb.riders) do
		if t - r.at <= NETK.RIDER_KEEP then
			list[#list + 1] = r
		else
			fb.riders[key] = nil
		end
	end
	table.sort(list, function(a, b)
		if a.at ~= b.at then return a.at > b.at end
		return a.key < b.key
	end)
	while #list > NETK.PUSH_MAX do table.remove(list) end
	return list
end

-- Whether a rider has booked already (no answers to riders who have a ride):
-- they asked us for a ride (R), their ride with us ended paid/done, or they are in our group.
local function booked(key)
	local at = fb.booked[key]
	if at and now() - at < NETK.BOOKED_FOR then return true end
	fb.booked[key] = nil
	for _, r in ipairs(W.incoming) do
		if r.buyerKey == key and r.state == "accepted" then return true end
	end
	return W.InGroupWith(key)
end
W.RiderBooked = booked

-- Q by whisper: a rider who can't hear the channel asks us. Answered with our D by whisper
-- after a moment (0.3-1.5 s), at most once per rider per 15 s and ten in any 15 s; not at
-- all while we aren't driving (the rider still gets our D when we go online, for 5.5 min).
-- (past ten answers in 15 s the next 24 are spread about a second
-- apart instead of dropped; one answer per rider per Q (a pending one is not doubled); none
-- to a rider who has booked, checked again when it goes.)
local pushPending = {} -- [key] = true: a staggered push to this rider is still to go (tickPush)
local function heardWhisperPing(addr, key)
	local t = now()
	fb.riders[key] = { key = key, addr = addr, at = t }
	if not beaconFor(key) or booked(key) then return end
	if fb.replyPending[key] or pushPending[key] then return end
	local last = fb.replyAt[key]
	if last and t - last < NETK.REPLY_QUIET then return end
	for i = #fb.replies, 1, -1 do
		if t - fb.replies[i] >= NETK.REPLY_QUIET then table.remove(fb.replies, i) end
	end
	local n = #fb.replies
	if n >= NETK.REPLY_CAP + NETK.STAGGER_MAX then return end
	-- the first few at once (the send burst), then about one a second: the outbox's own pace,
	-- so the queue never backs up past its whisper-fallback limit
	local delay = 0.3 + math.random() * 1.2
	if n >= 4 then delay = (n - 3) * 1.0 + math.random() * 0.5 end
	fb.replyAt[key] = t
	fb.replies[#fb.replies + 1] = t
	fb.replyPending[key] = true
	W.After(delay, function()
		fb.replyPending[key] = nil
		if booked(key) then return end
		whisperBeacon(addr, beaconFor(key))
	end)
end

-- Every second: our beacon changed (state, price, dest... not the position), or we went
-- online or offline -> the same D (or X) by whisper to the riders who asked by whisper in
-- the last 5.5 min. At most one such round per 5 s.
-- (AUD-29: the first PUSH_NOW go at once (the outbox's burst), the rest about a second
-- apart, the outbox's own pace, so a busy driver's 25 riders all hear it and the outbox's
-- whisper-fallback limit never drops one. A staggered one sends what is true when it goes:
-- our beacon then, or X if we went offline meanwhile; a send the outbox refused is tried
-- again a little later, and a rider counts as told only once it went.)
local push = { sig = nil, at = -1000, online = false }
local PUSH_NOW, PUSH_RETRY, PUSH_TRIES = 4, 5, 3
local function pushOne(r, tries)
	local b, sent = beaconFor(nil), nil
	if b then
		if booked(r.key) then return end
		sent = whisperBeacon(r.addr, b)
		if sent then fb.replyAt[r.key] = now() end -- just told: a Q from them now needs no answer
	else
		sent = whisperKind(r.addr, "X")
	end
	if not sent and tries < PUSH_TRIES then
		pushPending[r.key] = true
		W.After(PUSH_RETRY, function()
			pushPending[r.key] = nil
			pushOne(r, tries + 1)
		end)
	end
end
local function pushAll(list)
	local n = 0
	for _, r in ipairs(list) do
		n = n + 1
		if n <= PUSH_NOW then
			pushOne(r, 1)
		else
			pushPending[r.key] = true
			W.After((n - PUSH_NOW) * 1.0, function()
				pushPending[r.key] = nil
				pushOne(r, 1)
			end)
		end
	end
end
local function tickPush(b)
	if not b then
		if push.online then
			push.online, push.sig = false, nil
			local list = {}
			for _, r in ipairs(recentRiders()) do
				if not pushPending[r.key] then list[#list + 1] = r end
			end
			pushAll(list)
		end
		return
	end
	local sig = signature(b)
	if push.online and sig == push.sig then return end
	if now() - push.at < NETK.BEACON_GAP then return end
	push.online, push.sig, push.at = true, sig, now()
	local list = {}
	for _, r in ipairs(recentRiders()) do
		-- (not to a rider who booked, nor one whose answer or push is about to go: one D, not two)
		if not booked(r.key) and not fb.replyPending[r.key] and not pushPending[r.key] then list[#list + 1] = r end
	end
	pushAll(list)
end

-- HUNT-112: a rider who asks us by whisper (another copy of the channel: no channel D reaches
-- them) and rides with us now gets no pushes (booked), so a change of the passphrase flag (D
-- field 19) goes to such riders alone: our D by whisper, once per change (a refused send is
-- tried again after BEACON_GAP; HUNT-125: also a rider we only know from his booking, who never
-- heard a beacon and so starts as "told nothing"). A rider stays on this list while the ride lasts, also once
-- their last Q is older than RIDER_KEEP.
local passTold = {} -- [key] = { addr, on (the flag they last heard), at (last try) }
local function ridingWithUs(key)
	for _, r in ipairs(W.incoming) do
		if r.buyerKey == key and r.state == "accepted" then return true end
	end
	return W.InGroupWith(key)
end
local function tickPass(b)
	local on, t = b and b.showPass == true or false, now()
	for key in pairs(passTold) do
		if not ridingWithUs(key) then passTold[key] = nil end
	end
	for key, r in pairs(fb.riders) do
		if not passTold[key] and ridingWithUs(key) then passTold[key] = { addr = r.addr, on = on, at = -1000 } end
	end
	-- HUNT-125: a rider who booked from our [Wuber] advert alone never asked (no fb.riders row) and
	-- never heard our beacon: he has heard nothing, so the flag goes to him once it is on
	for _, r in ipairs(W.incoming) do
		local key = r.buyerKey
		if key and r.state == "accepted" and not passTold[key] and r.buyer then passTold[key] = { addr = r.buyer, on = false, at = -1000 } end
	end
	if not b then return end
	for key, p in pairs(passTold) do
		if p.on ~= on and t - p.at >= NETK.BEACON_GAP then
			p.at = t
			if whisperBeacon(p.addr, beaconFor(key)) then p.on = on end
		end
	end
end

-- A private beacon (see beaconFor) by whisper to the riders it names: on a change, or every
-- BEACON_EVERY; one per rider per BEACON_GAP.
local privateSent = {} -- [key] = { at, sig }
local function tickPrivate(b)
	if not (b and b.only) then
		privateSent = {}
		return
	end
	local sig, t = signature(b), now()
	for key, name in pairs(b.only) do
		local last = privateSent[key]
		if type(name) == "string" and (not last or ((last.sig ~= sig or t - last.at >= NETK.BEACON_EVERY) and t - last.at >= NETK.BEACON_GAP)) then
			privateSent[key] = { at = t, sig = sig }
			whisperBeacon(name, b)
		end
	end
end

local function tickBeacon()
	tickPrivate(W.DriverBeacon())
	local b = beaconFor(nil)
	tickPush(b)
	tickPass(b)
	if W.TickAnnounce then W.TickAnnounce(b) end
	if not b then
		if beacon.online then W.SendBeacon() end
		return
	end
	if beacon.pending or not (W.OnNetwork() or W.CommunityIndex()) then return end
	if not beacon.online or signature(b) ~= beacon.sig or now() >= beacon.nextAt then
		W.SendBeacon()
	end
end

-- A rider asked "who's driving?". Every Q gets an answer (a rider who just arrived missed
-- the last beacon), but a driver answers at most one Q per Q_QUIET seconds: riders hold
-- their own Q for 20 s after hearing any, so this keeps a crowd from flooding the channel.
local replyPending, lastQReply = false, -1000
local function heardPing(viaComm)
	if viaComm then
		-- a Q over the community: answered there alone, with the same quiet time
		comm.lastQHeard = now()
		if comm.replyPending or not beaconFor(nil) or now() - comm.lastQReply < NETK.Q_QUIET then return end
		comm.replyPending, comm.lastQReply = true, now()
		W.After(0.5 + math.random() * 2.5, function()
			comm.replyPending = false
			local b = beaconFor(nil)
			if b and CX.beacon(b, true) then beaconedPrices[b.price] = now() end
		end)
		return
	end
	lastQHeard = now()
	local b = beaconFor(nil)
	if replyPending or not b then return end
	if now() - lastQReply < NETK.Q_QUIET then return end
	replyPending = true
	lastQReply = now()
	-- (our unchanged D went on the channel in the last 25 s: answer
	-- later and further apart, so one Q doesn't set off every driver's beacon at once)
	local recent = beacon.online and now() - beacon.at < 25 and signature(b) == beacon.sig
	local delay = recent and (1.5 + math.random() * 5.5) or (0.5 + math.random() * 2.5)
	W.After(delay, function()
		replyPending = false
		W.SendBeacon()
	end)
end

BaseMod.onJoined = function()
	channelPing() -- just arrived: ask the drivers where they are
	beacon.online = false -- a new channel session: the first beacon goes at once
	W.SendBeacon()
end

-- Driver mode on or off for a Warlock without a provider: sets W.Char().drive, fires
-- "SETTINGS" ("drive") and beacons (or sends X) at once. Returns true, or false and why
-- ("provider", "class").
function W.SetDriving(on)
	if W.Provider() then return false, "provider" end
	if on and not W.IsWarlock() then return false, "class" end
	W.Char().drive = on and true or false
	W.Fire("SETTINGS", "drive")
	W.SendBeacon()
	return true
end

-- for the Net modules that load after this one (REFACTOR-MAP section 2)
Mod.beaconFor, Mod.chanFlag, Mod.heardBeacon, Mod.heardPing, Mod.heardWhisperPing, Mod.impl = beaconFor, chanFlag, heardBeacon, heardPing, heardWhisperPing, impl
Mod.tickBeacon, Mod.whisperBeacon = tickBeacon, whisperBeacon
