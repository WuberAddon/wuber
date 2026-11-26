-- Module: Net.Discovery
-- Purpose: Whisper rounds, the gossip mesh (K), known drivers and contacts, community seeds,
--   the founders' directory and driver announces (sets Net.Beacons.noteDirectory).
-- API: W.NameFromKey, W.CommunitySeeds, W.KnownDrivers, W.IsKeptKnown, W.Contacts, W.WhisperRound,
--   W.AmFounder, W.PruneDirectory, W.DirectoryNames, W.TickAnnounce,
--   NETK.{CHANNEL_FRESH,ROUND_MAX,ROUND_STEP,OPEN_EVERY,CLOSED_EVERY,Q_GAP,Q_CAP,OFFLINE_FOR,OFFLINE_FOUNDER,KNOWN_MAX,PEERS_MAX,GOSSIP_NAMES,GOSSIP_FRESH,GOSSIP_PEER_GAP,GOSSIP_CAP,GOSSIP_LIVE_MIN,GOSSIP_SEEN,UNCONFIRMED_MAX,UNCONFIRMED_FOUNDER,UNCONFIRMED_TRIES,ADVERT_FRESH,MENTION_GAP,MENTION_CAP,MENTION_STEP,MENTION_QUEUE,MENTION_QUIET,DIRECTORY_KEEP,DIRECTORY_MAX,ANNOUNCE_EVERY,ANNOUNCE_MAX}
-- Internals: capLeft, goodName, heardGossip, maybeGossip, rememberPeer, round, sendMentionQ, tickWhisper
-- Uses: Net.Base, Net.Community, Net.Transport, Net.Beacons, Net.Favourites
-- Later: FX.Emblem (W.EmblemFlag: the whispered Q's field 2)
-- Events: listens (none); fires (none); sets Net.Beacons.noteDirectory
-- Standalone: no
-- Test: tests/net/discovery_test.lua
-- From: Net.lua 3142-3851 (Wuber 2.2.1)
--
---------------------------------------------------------------------------
-- Being a rider: the whisper fallback and the gossip mesh
---------------------------------------------------------------------------
-- The channel is only a bonus. Every client keeps the drivers it knows (the founder's team,
-- favourites, trips, drivers heard in the last 14 days) and the Wuber users it has
-- whispered with ("contacts", 14 days), and asks them by whisper (Q) in small rounds. Two
-- clients that whisper may swap a K: up to 8 names of drivers each heard DIRECTLY (their
-- own D) in the last 30 min. A name from a K is only "unconfirmed": it is never shown as a
-- driver; we ask it (Q) and list it only when that character answers with its own D. So a
-- K can only suggest names to ask; price, state and dest always come from the driver.

local _, W = ...
local Mod = W.Module("Net.Discovery", { "Net.Base", "Net.Community", "Net.Transport", "Net.Beacons", "Net.Favourites" })
local BaseMod = W.Mod("Net.Base")
local CommunityMod = W.Mod("Net.Community")
local TransportMod = W.Mod("Net.Transport")
local BeaconsMod = W.Mod("Net.Beacons")
local FavouritesMod = W.Mod("Net.Favourites")
local NETK, address, call, clock, fb = BaseMod.NETK, BaseMod.address, BaseMod.call, BaseMod.clock, BaseMod.fb
local myKey, now, pruneSeen, seenList = BaseMod.myKey, BaseMod.now, BaseMod.pruneSeen, BaseMod.seenList
local CX, comm = CommunityMod.CX, CommunityMod.comm
local whisperKind = TransportMod.whisperKind
local beaconFor, chanFlag, whisperBeacon = BeaconsMod.beaconFor, BeaconsMod.chanFlag, BeaconsMod.whisperBeacon
local db = FavouritesMod.db
local plain, str, num = W.Plain, W.Str, W.Num

NETK.CHANNEL_FRESH = 90    -- a driver heard on the channel this recently needs no whispered Q
NETK.ROUND_MAX = 8         -- whispered Qs per round
NETK.ROUND_STEP = 1        -- seconds between them
NETK.OPEN_EVERY = 60       -- a round this often while the Wuber window is open
NETK.CLOSED_EVERY = 300    -- ... and this often while it is closed (a smaller one)
NETK.Q_GAP = 45            -- one whispered Q per driver per this (see qGap)
NETK.Q_CAP = 16            -- whispered Qs in any 60 s
NETK.OFFLINE_FOR = 300     -- "No player named": no Q to them for 5 min
NETK.OFFLINE_FOUNDER = 1800 -- ... 30 min for a founder (usually not logged in)
NETK.KNOWN_MAX = 40        -- known drivers (confirmed) asked at most
NETK.PEERS_MAX = 30        -- contacts kept (W.db.peers)
NETK.GOSSIP_NAMES = 8      -- names in a K
NETK.GOSSIP_FRESH = 1800   -- only drivers heard directly in the last 30 min are passed on
NETK.GOSSIP_PEER_GAP = 600 -- a K to the same peer at most once per 10 min
NETK.GOSSIP_CAP = 6        -- Ks we send in any 60 s
NETK.GOSSIP_LIVE_MIN = 6   -- fewer live names than this: recently seen ones follow (SPEC5 gossip)
NETK.GOSSIP_SEEN = 4       -- ... at most this many
NETK.UNCONFIRMED_MAX = 60  -- names to confirm (150 on a founder's client: the hub)
NETK.UNCONFIRMED_FOUNDER = 150
NETK.UNCONFIRMED_TRIES = 2 -- Qs to an unconfirmed name before it is dropped (and ignored 30 min)

fb.unconfirmed = {} -- key -> { key, name, at, from, tries }
fb.rejected = {}    -- key -> when an unconfirmed name was dropped (not taken again for 30 min)
fb.direct = {}      -- key -> { name, at }: drivers whose own D we heard (for K)
fb.kSentTo = {}     -- key -> when we last sent them a K
fb.kSent = {}       -- times of our Ks, for the cap
fb.advertHeard = {} -- key -> { name, at, channel, confirmed }: senders of "[Wuber]" lines in public chat
fb.announceAt = {}  -- founder key -> when our driver D was last whispered to them (driver announces)

NETK.MENTION_GAP = 3600   -- a name that says "wuber" in public chat gets one hidden Q per this (seconds)
NETK.MENTION_CAP = 12      -- ... and at most this many such Qs in any hour
NETK.MENTION_STEP = 10     -- ... at most one per this many seconds
NETK.MENTION_QUEUE = 5     -- ... at most this many wait to be sent (more mentions are dropped)
NETK.MENTION_QUIET = 60    -- ... none in the first this many seconds after login or reload
NETK.ADVERT_FRESH = 120    -- a "[Wuber]" line's sender is asked (Q) in the next rounds for this long

-- "anita lift" -> "Anita Lift": a name to whisper when only the key is known.
function W.NameFromKey(key)
	key = str(key)
	if not key then return nil end
	return (key:gsub("(%a)([^%s%-]*)", function(a, b) return a:upper() .. b end))
end

-- A character name fit to whisper: "First Surname" (letters, ' and - in each part), at most
-- 40 bytes; else nil.
local function goodName(name)
	name = W.CleanName(name)
	if not name or #name > 40 then return nil end
	local first, last = name:match("^(%S+) (%S+)$")
	if not first then return nil end
	local part = "^[%a\128-\255][%a\128-\255'%-]*$"
	if not (first:match(part) and last:match(part)) then return nil end
	return name
end

-- The Wuber community's members online now (SPEC5 community, review #7): whisper seeds that
-- reach across Forever's internal realms. Up to 10, Warlocks first, then the latest asked
-- least; { key, name, addr, lock }. Read again at most once a minute; every field guarded
-- (a secret or missing field just leaves that member out).
function W.CommunitySeeds()
	if comm.state ~= "member" or not comm.clubId then return {} end
	local t = now()
	if CX.seeds and t - (CX.seedsAt or -1000) < 60 then return CX.seeds end
	local out, locks, others = {}, {}, {}
	local okc, ids = CX.call("GetClubMembers", comm.clubId)
	if okc and type(plain(ids)) == "table" then
		local E = type(Enum) == "table" and type(Enum.ClubMemberPresence) == "table" and Enum.ClubMemberPresence or {}
		local off = num(E.Offline) or 3
		local me = myKey()
		for i, mid in ipairs(ids) do
			if i > 500 then break end
			local okm, info = CX.call("GetMemberInfo", comm.clubId, plain(mid))
			info = okm and plain(info) or nil
			if type(info) == "table" then
				local raw = str(info.name)
				local pres = num(info.presence)
				local key = raw and W.Key(raw)
				local name = raw and goodName(raw)
				if key and name and key ~= me and plain(info.isSelf) ~= true and pres and pres ~= off and pres ~= 0
					and not W.IsHidden(key) then
					local e = { key = key, name = name, addr = address(raw) or name, lock = num(info.classID) == 9 }
					if e.lock then locks[#locks + 1] = e else others[#others + 1] = e end
				end
			end
		end
	end
	local function byAsked(a, b)
		local qa, qb = fb.qAt[a.key] or -1, fb.qAt[b.key] or -1
		if qa ~= qb then return qa < qb end
		return a.key < b.key
	end
	table.sort(locks, byAsked)
	table.sort(others, byAsked)
	for _, list in ipairs({ locks, others }) do
		for _, e in ipairs(list) do
			if #out < CX.SEEDS_MAX then out[#out + 1] = e end
		end
	end
	CX.seeds, CX.seedsAt = out, t
	return out
end

-- The saved contacts: W.db.peers[key] = { name, addr, at = time() }.
local function peerList()
	local d0 = db()
	if type(d0.peers) ~= "table" then d0.peers = {} end
	return d0.peers
end

-- Forgets contacts not heard for SEEN_KEEP and the oldest past PEERS_MAX.
local function prunePeers(stamp)
	local list = peerList()
	local n = 0
	for k, e in pairs(list) do
		if type(e) ~= "table" or not num(e.at) or stamp - e.at > NETK.SEEN_KEEP or type(k) ~= "string" then
			list[k] = nil
		else
			n = n + 1
		end
	end
	while n > NETK.PEERS_MAX do
		local oldKey, oldAt
		for k, e in pairs(list) do
			if not oldAt or e.at < oldAt or (e.at == oldAt and k < oldKey) then oldKey, oldAt = k, e.at end
		end
		list[oldKey] = nil
		n = n - 1
	end
end

local function rememberPeer(key, name, addr)
	local list, stamp = peerList(), clock()
	local p = list[key]
	if type(p) ~= "table" then p = {} end
	p.name, p.addr, p.at = name, addr, stamp
	list[key] = p
	prunePeers(stamp)
end

-- The drivers this client knows and may ask by whisper: the founder's team, favourites,
-- drivers heard in the last 14 days (W.db.seenDrivers, 30 at most) and from the trip
-- history (40 in all), then the unconfirmed names from gossip; never ourselves or a hidden
-- driver. A list of { key, name, addr, founder, fav, seen (time() last heard), trip,
-- unconfirmed }: founders first, then favourites, then the latest heard.
function W.KnownDrivers()
	local me = myKey()
	local out, by = {}, {}
	-- the founders' names are only whispered on the founders' own ruleset (elsewhere they are
	-- other people, or nobody)
	local founderWorld = W.OnFounderRuleset()
	local function entry(key, make)
		key = W.Key(key)
		if not key or key == me or key == "?" or W.IsHidden(key) then return nil end
		if W.CREATOR[key] and not founderWorld then return nil end
		local e = by[key]
		if not e and make then
			e = { key = key }
			by[key] = e
			out[#out + 1] = e
		end
		return e
	end
	local function named(e, name, addr)
		if not e then return end
		if not e.name then e.name = goodName(name) end
		if not e.addr then e.addr = address(addr) end
	end
	-- the seeds of our ruleset (W.SEEDS; the founders first on theirs); none when unknown
	for _, sname in ipairs(W.SeedList()) do
		local e = entry(sname, true)
		if e then
			if W.CREATOR[e.key] then e.founder = true else e.seed = true end
			if not e.name then e.name = goodName(sname) end
		end
	end
	for key, on in pairs(db().favs) do
		local e = on and entry(key, true)
		if e then e.fav = true end
	end
	-- the Wuber community's members online (SPEC5 community): seeds across internal realms
	local okS, club = pcall(W.CommunitySeeds)
	for _, m in ipairs(okS and club or {}) do
		local e = entry(m.key, true)
		if e then
			e.club = true
			e.name = e.name or m.name
			e.addr = e.addr or m.addr
		end
	end
	pruneSeen()
	for key, s in pairs(seenList()) do
		local e = entry(key, true)
		if e then e.seen = s.at end
	end
	local rides = db().rides
	for i = #rides, 1, -1 do
		local t = rides[i]
		if type(t) == "table" then
			local e = entry(t.driverKey or t.driver, true)
			if e then e.trip = true end
		end
	end
	-- names and addresses: as last heard, then as saved, then from the key
	for key, d in pairs(W.drivers) do named(entry(key), d.name, d.addr) end
	for key, s in pairs(seenList()) do named(entry(key), s.name, s.addr) end
	for i = #rides, 1, -1 do
		local t = rides[i]
		if type(t) == "table" then named(entry(t.driverKey or t.driver), t.driver, nil) end
	end
	local function rank(e) return (e.founder or e.seed) and 1 or ((e.fav or e.club) and 2 or 3) end
	table.sort(out, function(a, b)
		local ra, rb = rank(a), rank(b)
		if ra ~= rb then return ra < rb end
		local sa, sb = num(a.seen) or 0, num(b.seen) or 0
		if sa ~= sb then return sa > sb end
		return a.key < b.key
	end)
	while #out > NETK.KNOWN_MAX do table.remove(out) end
	by = {} -- the drivers trimmed out are no longer known (AUD-35)
	for _, e in ipairs(out) do
		e.name = e.name or goodName(W.NameFromKey(e.key)) or W.NameFromKey(e.key)
		e.addr = e.addr or e.name
		by[e.key] = e
	end
	-- unconfirmed names last, oldest first (they wait their turn)
	local un = {}
	for key, u in pairs(fb.unconfirmed) do
		if not by[key] and key ~= me and not W.IsHidden(key) and (founderWorld or not W.CREATOR[key]) then un[#un + 1] = u end
	end
	-- (fresh before stale, SPEC5 gossip: a name a peer heard live goes before one seen hours ago)
	table.sort(un, function(a, b)
		local fa, fb2 = (a.age or 0) < 60, (b.age or 0) < 60
		if fa ~= fb2 then return fa end
		if a.at ~= b.at then return a.at < b.at end
		return a.key < b.key
	end)
	for _, u in ipairs(un) do
		out[#out + 1] = { key = u.key, name = u.name, addr = u.name, unconfirmed = true }
	end
	return out
end

-- The contacts (Wuber users we whispered with), latest first: { key, name, addr, contact = true }.
function W.Contacts()
	local out, me = {}, myKey()
	prunePeers(clock())
	for key, p in pairs(peerList()) do
		if key ~= me and not W.CREATOR[key] then
			local name = goodName(p.name) or goodName(W.NameFromKey(key))
			if name then out[#out + 1] = { key = key, name = name, addr = address(p.addr) or name, contact = true, at = p.at } end
		end
	end
	table.sort(out, function(a, b)
		if a.at ~= b.at then return a.at > b.at end
		return a.key < b.key
	end)
	return out
end

local round = { loginAt = nil, loginDone = false, lastFull = -1000, lastCore = -1000, shown = false, pruneAt = 0, confirmAt = nil }

local function capLeft(list, t, cap, window)
	for i = #list, 1, -1 do
		if t - list[i] >= (window or 60) then table.remove(list, i) end
	end
	return cap - #list
end

-- How long since our last Q to this one before another: 15 s for "Ping drivers"; while the
-- window is closed 5 min (favourites) or 10 min (founders, contacts); else 10 min for a
-- contact, 5 min for a driver who didn't answer our last Q (not driving now: they whisper
-- us when they go online), 100 s for one who answers (their changes come to us anyway),
-- otherwise 45 s.
local function qGap(e, scope, force)
	if force then return 15 end
	-- a "[Wuber]" advert newer than our last Q: he is on now, ask soon
	local adv, q0 = fb.advertHeard[e.key], fb.qAt[e.key]
	if adv and now() - adv.at < NETK.ADVERT_FRESH and (not q0 or adv.at > q0) then return 15 end
	if e.contact then return 600 end
	if scope == "core" and not e.unconfirmed then return e.fav and 300 or 600 end
	local q, a = fb.qAt[e.key], fb.answeredAt[e.key]
	if q and not (a and a >= q) then return 300 end
	if a then return 100 end
	return NETK.Q_GAP
end

local function askable(e, t, scope, force)
	local key = e.key
	local heard = fb.chanHeard[key]
	if heard and t - heard < NETK.CHANNEL_FRESH and W.drivers[key] then return false end
	local off = fb.offlineUntil[key]
	if off and t < off then return false end
	local q = fb.qAt[key]
	if q and t - q < qGap(e, scope, force) then return false end
	return true
end

-- One round of whispered Qs: to up to 8 known drivers (and contacts, and unconfirmed names)
-- not heard on the channel in the last 90 s, not known to be offline and not asked too
-- lately, a second apart; 16 at most in any minute. scope: "full" (window open, login,
-- "Ping drivers"), "core" (window closed: favourites, founders, contacts, unconfirmed),
-- "confirm" (unconfirmed names only, just after a K). Returns how many were queued.
function W.WhisperRound(scope, force)
	if not W.db or W.net.cantSend then return 0 end
	-- (SPEC5 stagger: a rider whose ride is under way has booked: no Qs, so no answers)
	if W.RideActive and W.RideActive() then return 0 end
	local t = now()
	if scope == "full" then round.lastFull = t end
	if scope ~= "confirm" then round.lastCore = t end
	local list = {}
	local function consider(e)
		local adv = fb.advertHeard[e.key]
		local advFresh = adv ~= nil and t - adv.at < NETK.ADVERT_FRESH and not W.drivers[e.key]
		local fits = scope == "full" or e.unconfirmed or advFresh or (scope == "core" and (e.founder or e.seed or e.fav or e.contact or e.club))
		if scope == "confirm" then fits = e.unconfirmed or advFresh end
		if fits and e.addr and askable(e, t, scope, force) then
			e.order = #list + 1
			list[#list + 1] = e
		end
	end
	for _, e in ipairs(W.KnownDrivers()) do consider(e) end
	if scope ~= "confirm" then
		local known = {}
		for _, e in ipairs(list) do known[e.key] = true end
		for _, e in ipairs(W.Contacts()) do
			if not known[e.key] and not W.IsHidden(e.key) then consider(e) end
		end
	end
	local function tier(e)
		if e.founder or e.seed or e.fav then return 1 end
		if e.club then return 2 end
		local a = fb.answeredAt[e.key]
		if a and t - a < 300 then return 2 end
		if e.unconfirmed then return 4 end
		if e.contact then return 5 end
		return 3
	end
	table.sort(list, function(a, b)
		local ta, tb = tier(a), tier(b)
		if ta ~= tb then return ta < tb end
		local qa, qb = fb.qAt[a.key] or -1, fb.qAt[b.key] or -1
		if qa ~= qb then return qa < qb end
		return a.order < b.order
	end)
	-- (counted when planned; sent within 8 s: a 70 s window keeps any 60 s of sends to 16)
	local left = capLeft(fb.qSent, t, NETK.Q_CAP, 70)
	-- names from a K never use the whole allowance: half is kept for the drivers we know
	-- (a peer flooding K could otherwise keep every real Q from going out)
	if scope == "confirm" then left = left - NETK.ROUND_MAX end
	local n = math.min(#list, NETK.ROUND_MAX, math.max(0, left))
	for i = 1, n do
		local e = list[i]
		fb.qAt[e.key] = t
		fb.qSent[#fb.qSent + 1] = t
		if e.unconfirmed then
			local u = fb.unconfirmed[e.key]
			if u then u.tries = (u.tries or 0) + 1 end
		end
		local function send()
			if W.RideActive and W.RideActive() then return end -- booked meanwhile (an A came)
			-- heard on the channel meanwhile, or found offline: no Q
			local h = fb.chanHeard[e.key]
			if h and now() - h < NETK.CHANNEL_FRESH and W.drivers[e.key] then return end
			local off = fb.offlineUntil[e.key]
			if off and now() < off then return end
			fb.qAddr[e.key] = e.addr
			local emblemOff = W.EmblemFlag and W.EmblemFlag() -- 2.3.2: field 2 "0" (a hidden Pioneer emblem)
			if emblemOff then whisperKind(e.addr, "Q", chanFlag(), emblemOff) else whisperKind(e.addr, "Q", chanFlag()) end
		end
		if i == 1 then send() else W.After((i - 1) * NETK.ROUND_STEP + math.random() * 0.3, send) end
	end
	return n
end

-- The drivers we heard directly in the last 30 min, latest first, as names for a K (not
-- `except`, not ourselves, not hidden), fitting one message.
local function gossipNames(except)
	local t, me, list = now(), myKey(), {}
	for key, e in pairs(fb.direct) do
		if t - e.at > NETK.GOSSIP_FRESH then
			fb.direct[key] = nil
		elseif key ~= except and key ~= me and not W.IsHidden(key) and goodName(e.name) then
			list[#list + 1] = { key = key, name = goodName(e.name), at = e.at }
		end
	end
	table.sort(list, function(a, b)
		if a.at ~= b.at then return a.at > b.at end
		return a.key < b.key
	end)
	-- (SPEC5 gossip, review #13: with few drivers live, up to 4 seen in the last 24 h follow,
	-- each as "Name Surname:minutes" since last heard; old clients skip those names)
	if #list < NETK.GOSSIP_LIVE_MIN then
		local stamp, old, have = num(call(time)) or 0, {}, {}
		for _, e in ipairs(list) do have[e.key] = true end
		for key, sd in pairs(seenList()) do
			local at = type(sd) == "table" and num(sd.at)
			local name = at and goodName(sd.name)
			if name and not have[key] and key ~= except and key ~= me and not sd.unlisted and not W.IsHidden(key)
				and stamp - at >= 0 and stamp - at < 86400 then
				old[#old + 1] = { key = key, name = name, age = math.floor((stamp - at) / 60) }
			end
		end
		table.sort(old, function(a, b)
			if a.age ~= b.age then return a.age < b.age end
			return a.key < b.key
		end)
		for i = 1, math.min(#old, NETK.GOSSIP_SEEN) do
			list[#list + 1] = { key = old[i].key, name = old[i].name .. ":" .. old[i].age, at = -1 }
		end
	end
	local names, size = {}, #W.Encode("K")
	for _, e in ipairs(list) do
		if #names >= NETK.GOSSIP_NAMES or size + 1 + #e.name > NETK.MAX_BYTES then break end
		names[#names + 1] = e.name
		size = size + 1 + #e.name
	end
	return names
end

---------------------------------------------------------------------------
-- The founders' directory (founder clients only)
---------------------------------------------------------------------------
-- Drivers announce themselves to the founders (below), so a founder's client learns every
-- Wuber driver of its ruleset directly. It keeps each driver it confirmed itself (his own D,
-- same faction, a real version, not opted out of the starter list) in W.db.directory
-- [key] = { name, lastSeen = time(), dest, ruleset }: 30 days, 300 at most. Anyone who
-- whispers a founder a Q gets a K of up to 8 of those names (latest seen first, rotating so
-- different askers get different names). The usual K rules hold for the asker: a name is
-- shown only once that driver answers with his own D.

function W.AmFounder() return W.IsCreator(myKey()) end
local amFounder = W.AmFounder
do
NETK.DIRECTORY_KEEP = 30 * 86400
NETK.DIRECTORY_MAX = 300
local dirCursor = 0

local function directory()
	local d0 = db()
	if type(d0.directory) ~= "table" then d0.directory = {} end
	return d0.directory
end

-- Forgets entries older than 30 days and the oldest past 300. Returns the count left.
function W.PruneDirectory()
	local list, stamp, n = directory(), num(call(time)) or 0, 0
	for key, e in pairs(list) do
		local at = type(e) == "table" and num(e.lastSeen) or nil
		if type(key) ~= "string" or not at or stamp - at > NETK.DIRECTORY_KEEP or at > stamp + 86400 then
			list[key] = nil
		else
			n = n + 1
		end
	end
	while n > NETK.DIRECTORY_MAX do
		local oldKey, oldAt
		for key, e in pairs(list) do
			if not oldAt or e.lastSeen < oldAt or (e.lastSeen == oldAt and key < oldKey) then oldKey, oldAt = key, e.lastSeen end
		end
		list[oldKey] = nil
		n = n - 1
	end
	return n
end

BeaconsMod.noteDirectory = function(key, name, d)
	if not amFounder() or W.CREATOR[key] then return end
	local list = directory()
	if d.unlisted then
		list[key] = nil -- opted out: never passed on
		return
	end
	name = goodName(name)
	if not name then return end
	local e = list[key]
	local isNew = type(e) ~= "table"
	if isNew then e = {} end
	e.name, e.lastSeen, e.dest, e.ruleset = name, num(call(time)) or 0, d.dest, d.ruleset
	list[key] = e
	if isNew then W.PruneDirectory() end
end

-- Up to 8 directory names for a K to `except` (not them, not us, not hidden, our ruleset),
-- the latest seen first, the window moving on by 8 at every call.
function W.DirectoryNames(except)
	W.PruneDirectory()
	local rs, me, all = W.Ruleset(), myKey(), {}
	for key, e in pairs(directory()) do
		if type(e) == "table" and key ~= except and key ~= me and not W.IsHidden(key) and goodName(e.name)
			and (not e.ruleset or not rs or e.ruleset == rs) then
			all[#all + 1] = { key = key, name = goodName(e.name), at = num(e.lastSeen) or 0 }
		end
	end
	table.sort(all, function(a, b)
		if a.at ~= b.at then return a.at > b.at end
		return a.key < b.key
	end)
	local names, size = {}, #W.Encode("K")
	local n = #all
	if n == 0 then return names end
	local start = dirCursor % n
	for i = 0, math.min(n, NETK.GOSSIP_NAMES) - 1 do
		local e = all[(start + i) % n + 1]
		if size + 1 + #e.name > NETK.MAX_BYTES then break end
		names[#names + 1] = e.name
		size = size + 1 + #e.name
	end
	dirCursor = dirCursor + #names
	return names
end
end -- the directory

-- After any Wuber whisper from a peer: our K to them, if we have names and haven't sent
-- them one in 10 min (6 Ks a minute at most; 12 on a founder's client), a moment later. A
-- founder answers a Q with names from the directory.
local function maybeGossip(addr, key, kind)
	local t = now()
	local last = fb.kSentTo[key]
	if last and t - last < NETK.GOSSIP_PEER_GAP then return end
	local founderQ = kind == "Q" and amFounder()
	local names = founderQ and W.DirectoryNames(key) or gossipNames(key)
	if #names == 0 and founderQ then names = gossipNames(key) end
	if #names == 0 then return end
	if capLeft(fb.kSent, t, amFounder() and NETK.GOSSIP_CAP * 2 or NETK.GOSSIP_CAP) <= 0 then return end
	fb.kSentTo[key] = t
	fb.kSent[#fb.kSent + 1] = t
	W.After(0.5 + math.random() * 1.5, function()
		local fresh = founderQ and names or gossipNames(key)
		if #fresh > 0 then W.SendTo(addr, "K", unpack(fresh)) end
	end)
end

-- K: names of drivers (whisper only, from any Wuber user). Unknown good names become
-- unconfirmed (asked soon; listed only when they answer with their own D).
-- A seen driver counts as known only while he is inside the kept 40 (AUD-36).
function W.IsKeptKnown(key)
	if not seenList()[key] then return false end
	for _, e in ipairs(W.KnownDrivers()) do
		if e.key == key then return not e.unconfirmed end
	end
	return false
end

local function heardGossip(key, f)
	local t, me = now(), myKey()
	local cap = W.IsCreator(me) and NETK.UNCONFIRMED_FOUNDER or NETK.UNCONFIRMED_MAX
	local n = 0
	for _ in pairs(fb.unconfirmed) do n = n + 1 end
	local known = {}
	for k in pairs(W.drivers) do known[k] = true end
	-- a seen driver counts only while he is inside the kept list (AUD-36); one look at the list, and a
	-- driver heard live stays known whatever his place in it
	local kept = {}
	for _, e in ipairs(W.KnownDrivers()) do
		if not e.unconfirmed then kept[e.key] = true end
	end
	for k in pairs(seenList()) do
		if kept[k] then known[k] = true end
	end
	local added = 0
	for i = 1, math.min(#f, NETK.GOSSIP_NAMES) do
		-- "Name Surname:minutes": a driver the peer saw that long ago (SPEC5 gossip)
		local raw, age = f[i], nil
		local base, mins = tostring(raw or ""):match("^(.-):(%d+)$")
		if base then raw, age = base, math.min(1440, tonumber(mins) or 1440) end
		local name = goodName(raw)
		local k = name and W.Key(name)
		local rej = k and fb.rejected[k]
		if k and k ~= me and k ~= key and not known[k] and not W.CREATOR[k] and not fb.unconfirmed[k]
			and not W.IsHidden(k) and not (rej and t - rej < NETK.GOSSIP_FRESH) and n < cap then
			fb.unconfirmed[k] = { key = k, name = name, at = t, from = key, tries = 0, age = age or 0 }
			n, added = n + 1, added + 1
		end
	end
	if added > 0 and not round.confirmAt then round.confirmAt = t + 3 + math.random() * 2 end
end

local function uiShown()
	local UI = W.UI
	if type(UI) ~= "table" or type(UI.IsShown) ~= "function" then return false end
	local ok, shown = pcall(UI.IsShown)
	return ok and shown == true
end

-- W.net.byWhisper, W.net.whisperOnly (see W.net).
local function health(t)
	local n = 0
	for _, d in pairs(W.drivers) do
		if d.via == "WHISPER" then n = n + 1 end
	end
	W.net.byWhisper = n
	local since = fb.joinedAt
	local quiet = since ~= nil and t - since >= 180 and (fb.chanOthersAt == nil or t - fb.chanOthersAt >= 180) and W.OnNetwork()
	local answered = false
	for _, a in pairs(fb.answeredAt) do
		if t - a < 180 then
			answered = true
			break
		end
	end
	W.net.whisperOnly = (quiet and answered) and true or false
	local u = 0
	for _ in pairs(fb.unconfirmed) do u = u + 1 end
	W.net.unconfirmed = u
end

-- Leaves the channel and joins it again, once a session, when for 5 min we have heard only
-- our own echoes there while a peer tells us by whisper they hear others on it (D's field
-- 14 or a whispered Q's flag): we are probably in a copy of the channel of our own.
local function maybeRejoin(t)
	if W.net.rejoined or not W.OnNetwork() then return end
	local since = fb.joinedAt
	if not since or t - since < 300 then return end
	if fb.chanOthersAt and t - fb.chanOthersAt < 300 then return end
	if not (fb.echoAt and fb.echoAt >= since) then return end
	if not (fb.peerOnChanAt and t - fb.peerOnChanAt < 120) then return end
	if W.InCombat() or type(LeaveChannelByName) ~= "function" then return end
	W.net.rejoined = true
	pcall(LeaveChannelByName, W.CHANNEL)
	W.After(3, function()
		W.CheckChannel(false) -- notices it is gone
		BaseMod.resetJoinTry()
		W.CheckChannel(true)
	end)
end

local function pruneFallback(t)
	local function older(map, age)
		for k, v in pairs(map) do
			local at = type(v) == "table" and v.at or v
			if type(at) ~= "number" or t - at > age then map[k] = nil end
		end
	end
	older(fb.chanHeard, 600)
	older(fb.whispered, 60)
	older(fb.qAt, 1800)
	older(fb.answeredAt, 1800)
	older(fb.lastBeacon, 330)
	older(fb.replyAt, 60)
	older(fb.riders, 330) -- (RIDER_KEEP) a client that never drives would keep every asker
	older(fb.kSentTo, NETK.GOSSIP_PEER_GAP)
	older(fb.rejected, NETK.GOSSIP_FRESH)
	older(fb.direct, NETK.GOSSIP_FRESH)
	for k, until_ in pairs(fb.offlineUntil) do
		if t >= until_ then fb.offlineUntil[k] = nil end
	end
	for k, u in pairs(fb.unconfirmed) do
		local q = fb.qAt[k]
		if (u.tries or 0) >= NETK.UNCONFIRMED_TRIES and q and t - q > 20 then -- no D within 20 s
			fb.unconfirmed[k] = nil
			fb.rejected[k] = t
		elseif t - u.at > NETK.GOSSIP_FRESH then
			fb.unconfirmed[k] = nil
		end
	end
end

-- Every second: the rounds (10 s after login; when the window opens; every 60 s while it is
-- open, every 5 min while closed; unconfirmed names a few seconds after a K), the health
-- figures and the rejoin check.
local function tickWhisper()
	local t = now()
	round.loginAt = round.loginAt or t
	local shown = uiShown()
	if not round.loginDone then
		-- (SPEC5 firstround, review #13: with the window open the first round goes at once)
		if t - round.loginAt >= 10 or (shown and t - round.loginAt >= 1.5) then
			round.loginDone = true
			W.WhisperRound("full")
		end
	elseif shown and (not round.shown or t - round.lastFull >= NETK.OPEN_EVERY) then
		W.WhisperRound("full")
	elseif not shown and t - round.lastCore >= NETK.CLOSED_EVERY then
		W.WhisperRound("core")
	elseif round.confirmAt and t >= round.confirmAt then
		round.confirmAt = nil
		W.WhisperRound("confirm")
	end
	round.shown = shown
	health(t)
	maybeRejoin(t)
	if t >= round.pruneAt then
		round.pruneAt = t + 15
		pruneFallback(t)
	end
end

---------------------------------------------------------------------------
-- Drivers announce themselves to the founders
---------------------------------------------------------------------------
-- A driver (Wuber's own driver mode or a provider) whispers his D to each founder character
-- when he goes online and every 15 min while online, so founder clients learn every driver
-- of the ruleset (their directory, above) and can pass the names on. Only on the founders'
-- ruleset; not to a founder known to be offline ("No player named": 30 min back-off); not
-- from a founder's own client (founders are everyone's seeds anyway); at most 4 a round.

do
NETK.ANNOUNCE_EVERY = 900
NETK.ANNOUNCE_MAX = 4
local announce = { online = false, nextAt = 0 }

local function tickAnnounce(b)
	local t = now()
	if not b then
		announce.online = false
		return
	end
	if announce.online and t < announce.nextAt then return end
	announce.online, announce.nextAt = true, t + NETK.ANNOUNCE_EVERY
	if W.net.cantSend or amFounder() or not W.OnFounderRuleset() then return end
	local sent = 0
	for _, fname in ipairs(W.SEED_FOUNDERS) do
		local key = W.Key(fname)
		local off = key and fb.offlineUntil[key]
		local last = key and fb.announceAt[key]
		if key and key ~= myKey() and not (off and t < off) and not (last and t - last < NETK.ANNOUNCE_EVERY - 5)
			and sent < NETK.ANNOUNCE_MAX then
			sent = sent + 1
			fb.announceAt[key] = t
			W.After(0.2 + sent * 0.7, function()
				local off2 = fb.offlineUntil[key]
				if off2 and now() < off2 then return end
				local nb = beaconFor(key)
				if nb then whisperBeacon(goodName(fname) or fname, nb) end
			end)
		end
	end
end
W.TickAnnounce = tickAnnounce
end -- announces

-- One hidden Q to a name that mentioned Wuber in public chat (Net.Outreach decides who and when and
-- re-checks its rules just before): it counts against the normal whispered-Q cap, like a round's Q.
local function sendMentionQ(key, addr)
	local t = now()
	if capLeft(fb.qSent, t, NETK.Q_CAP, 70) <= 0 then return false end
	fb.qSent[#fb.qSent + 1] = t
	fb.qAt[key] = t
	fb.qAddr[key] = addr
	local emblemOff = W.EmblemFlag and W.EmblemFlag()
	if emblemOff then whisperKind(addr, "Q", chanFlag(), emblemOff) else whisperKind(addr, "Q", chanFlag()) end
	return true
end

-- for the Net modules that load after this one (REFACTOR-MAP section 2)
Mod.capLeft, Mod.goodName, Mod.heardGossip, Mod.maybeGossip, Mod.rememberPeer, Mod.round = capLeft, goodName, heardGossip, maybeGossip, rememberPeer, round
Mod.sendMentionQ = sendMentionQ
Mod.tickWhisper = tickWhisper
