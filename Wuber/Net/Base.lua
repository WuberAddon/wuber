-- Module: Net.Base
-- Purpose: Net constants (NETK, kinds, stages, badges, ride ranks), small helpers, names, the
--   wire codec (W.Encode/Decode), the hidden channel (W.ChannelIndex, filters,
--   W.CheckChannel) and the whisper-fallback state table fb (W.fallback).
-- API: W.drivers, W.incoming, W.ride, W.net, W.STAGES, W.DECLINE_REASONS, W.BADGES,
--   W.BADGE_BY_ID, W.ValidBadge, W.RIDE_RANK, W.RIDE_ENDED, W.RIDE_LIMITS, W.CleanName,
--   W.MacroName, W.Encode, W.Decode, W.NewRideId, W.Faction, W.ChannelIndex, W.OnNetwork,
--   W.HideChannel, W.ChannelFilter, W.NotFoundName, W.fallback, W.SystemFilter,
--   W.CheckChannel, W.NetKind, W.VerAtLeast,
--   NETK.{DRIVER_TTL,RIDE_TIMEOUT,QUEUE_SILENCE,RESEND_AFTER,BEACON_EVERY,BEACON_JITTER,BEACON_GAP,Q_QUIET,PING_GAP,ACCEPT_WINDOW,BURST,RATE,MAX_QUEUE,MAX_BYTES,MAX_INCOMING,INCOMING_MAX_AGE,RESTORE_MAX_AGE,MAX_PRICE,NOT_FOUND_WINDOW,SEEN_MAX,SEEN_KEEP}
-- Internals: CHANNEL_KINDS, ENDED, KINDS, NETK, NET_HANDLERS, RANK, REASONS, STAGES, STAGE_ALIAS, STATES,
--   STATE_LIMIT, WHISPER_TOO, addFilters, address, call, clamp, clock, copy, fb,
--   hasChannels, hideChannel, isOurChannel, localInt, myKey, netInt, now, pruneSeen,
--   rememberSeen, rideId, seenList, whisperedRecently, lateHandler, netHandler; hook slot
--   onJoined (set by Net.Beacons); accessor resetJoinTry
-- Uses: (none)
-- Later: Net.Portal, Net.Raincheck, Net.Bounty, Drive.Rank (their `heard`, for kinds G, V, W, L)
-- Events: listens (none); fires NETWORK
-- Standalone: no
-- Test: tests/net/base_test.lua
-- From: Net.lua 1-511 (Wuber 2.2.1)
--
-- Net: the Wuber network. Drivers send beacons over a hidden chat channel; riders keep a
-- list of the drivers they hear. A ride is asked for, accepted and followed by addon
-- whispers between the rider and the driver. See SPEC.md, "Protocol" and "Advisor fixes".
--
-- Rider side:  W.drivers, W.ride, W.RequestRide, W.CancelRide, W.Rate, W.ClearRide, W.Ping,
--              W.RequestWhisper / W.CancelWhisper (text for the UI's secure buttons),
--              W.AcceptInvite, W.AcceptSummon, W.LeaveGroup, W.Prominence,
--              favourites (W.ToggleFav, W.IsFav), watch (W.ToggleWatch, W.IsWatched),
--              hiding (W.HideDriver, W.IsHidden, W.ShowAllDrivers), W.Usual
-- Driver side: W.incoming, W.AcceptRequest, W.DeclineRequest, W.SendStage, W.SendQueue,
--              W.SetDriving, W.SetLocalDriver (Driver.lua), W.BADGES, WuberAPI
-- Both:        W.SendChannel, W.SendTo, W.OnNetwork, W.Encode, W.Decode
--
-- Round two (SPEC2), backward compatible (proto stays 1, fields only added at the end):
--   D ... faction, ver, badge (12), queue (13)   R ... tier (4), rides (5)
--   P rideId, position, eta  (whisper, driver -> rider: place in the driver's queue)
-- A round-one peer ignores the extra fields and the P kind; missing fields read as
-- badge "", queue nil, tier 0, rides nil.
--
-- Every outgoing message goes through one queue: about one a second, bursts of 4,
-- whispers ahead of channel messages, and a queued beacon (or a queued stage for the same
-- ride) is replaced by a newer one rather than sent twice.
--
-- Whisper fallback and gossip (Forever's internal realms split the channel; see the
-- sections below), still proto 1: D gains 14 "1" = hears others on the channel and 15 the
-- internal realm (display only); a whispered Q may carry the same flag as field 1; new
-- whisper kind K = up to 8 driver names (suggestions to ask, never shown until confirmed).
-- D/X/Q by whisper count only for the sender itself; old peers drop them, and K.
--
-- Trust: D/X/Q count only from the channel (or by whisper from the sender itself),
-- R/A/N/C/S/T/P/K only by whisper. A/N/S count only
-- from the driver of our ride; C/T only from that ride's buyer. Every field is cleaned on
-- receipt; whispers go to the event's sender, never to a name inside a message.

local _, W = ...
local Mod = W.Module("Net.Base", {})

local plain, str, num = W.Plain, W.Str, W.Num

-- Net's tunable numbers live in one table (NETK): the file's main chunk must stay far under
-- Lua 5.1's 200 locals, or the whole addon fails to load.
local NETK = {}

NETK.DRIVER_TTL = 150    -- a driver is dropped this long after its last beacon
NETK.RIDE_TIMEOUT = 40   -- a request with no answer times out
NETK.QUEUE_SILENCE = 150 -- a rider in line gives up only after this long with nothing heard from the driver
NETK.RESEND_AFTER = 8    -- R is sent once more after this long without A or N
NETK.BEACON_EVERY = 60   -- seconds between beacons (plus or minus BEACON_JITTER)
NETK.BEACON_JITTER = 10
NETK.BEACON_GAP = 5      -- changes are beaconed at most once per this many seconds
NETK.Q_QUIET = 15        -- a driver answers at most one Q in this many seconds
NETK.PING_GAP = 20       -- a rider sends Q at most once per this, and not after hearing one
NETK.ACCEPT_WINDOW = 30  -- Wuber's own driver mode: unanswered requests get "N busy"
NETK.BURST = 4           -- messages that may go out at once
NETK.RATE = 1            -- messages a second after that
NETK.MAX_QUEUE = 40
NETK.MAX_BYTES = 255
NETK.MAX_INCOMING = 20   -- open requests a driver holds before saying "full"
NETK.INCOMING_MAX_AGE = 1800
NETK.RESTORE_MAX_AGE = 600 -- a saved ride is picked up again after /reload if this fresh

NETK.MAX_PRICE = 99999999

W.drivers = W.drivers or {}
W.incoming = W.incoming or {}
W.ride = nil
W.net = { sent = 0, failed = 0, heard = 0, dropped = 0, joined = false, warned = false,
	whisperOnly = false, -- in the channel, but only our own echoes heard there for 3 min while drivers answer by whisper
	byWhisper = 0,       -- drivers listed now whose last beacon came by whisper
	rejoined = false }   -- the channel was left and joined again once this session (see the whisper fallback)

local STATES = { open = true, busy = true, paused = true }
local REASONS = { busy = true, full = true, closed = true, blocked = true, price = true }
-- (B, 2.2: "booked elsewhere" by whisper from a rider; F, 2.2.1: shared flight prices (see
-- "Shared flight prices"); older clients drop both)
local KINDS = { D = true, X = true, Q = true, R = true, A = true, N = true, C = true, S = true, T = true, P = true, K = true, B = true, F = true }
local CHANNEL_KINDS = { D = true, X = true, Q = true }
-- channel kinds that may also come by whisper, from the driver or rider itself (the whisper
-- fallback below); round-one peers drop them, as they drop any channel kind by whisper
local WHISPER_TOO = { D = true, X = true, Q = true }

-- 2.3.0 (SPEC7 section 6): kinds added by W.NetKind. Each has a handler that Net.Inbox calls
-- with (addr, name, key, fields, chan, viaComm, proto) once the usual trust checks passed
-- (channel kinds over the channel or by whisper from the sender itself, the rest by whisper
-- only). Old clients don't know the kind: W.Decode returns nil there and it is dropped.
local NET_HANDLERS = {}

-- Adds a message kind: opts.channel (heard over the channel), opts.whisperToo (a channel kind
-- that may also come by whisper from its sender). handler: as above (nil keeps the old one).
-- Table writes only. Returns true, or false for a bad kind or one Wuber already had.
function W.NetKind(kind, opts, handler)
	kind = str(kind)
	if not kind or not kind:match("^%u$") then return false end
	if KINDS[kind] and not NET_HANDLERS[kind] then return false end -- one of the built-in kinds
	opts = type(opts) == "table" and opts or {}
	KINDS[kind] = true
	CHANNEL_KINDS[kind] = opts.channel and true or nil
	WHISPER_TOO[kind] = (opts.channel and opts.whisperToo) and true or nil
	if type(handler) == "function" then NET_HANDLERS[kind] = handler end
	NET_HANDLERS[kind] = NET_HANDLERS[kind] or function() end
	return true
end

-- the 2.3.0 kinds: the handler is the owning module's `heard` (it loads after Net.Inbox, so it
-- is looked up when a message comes, never at load)
local function lateHandler(module)
	return function(...)
		local m = W.Mod(module)
		if m and type(m.heard) == "function" then return m.heard(...) end
	end
end
W.NetKind("G", {}, lateHandler("Net.Portal"))         -- portal tracker (driver -> rider)
W.NetKind("V", {}, lateHandler("Net.Raincheck"))      -- raincheck (both ways)
W.NetKind("W", { channel = true, whisperToo = true }, lateHandler("Net.Bounty")) -- want-to-go bounty
W.NetKind("L", {}, lateHandler("Drive.Rank"))         -- 2.4: landed, the rider's own arrival report (rider -> driver; an older Wuber drops it)
-- S stages on the wire; "waiting" (an older word for portal) is sent as "portal"
local STAGES = { invited = true, summoning = true, portal = true, arrived = true, paid = true, done = true }
local STAGE_ALIAS = { waiting = "portal" }
W.STAGES = { "invited", "summoning", "portal", "arrived", "paid", "done" }
W.DECLINE_REASONS = { "busy", "full", "closed", "blocked", "price" }

-- Driver badges a driver may pick (W.Char().badge) and beacon: id, name, texture (the Media
-- file FX makes for it; FX owns the id -> sheet-cell map). Unknown ids show nothing. The
-- founder's crown is not a badge: it comes from W.CREATOR and can't be claimed.
W.BADGES = {
	{ id = "bolt", name = "Bolt", texture = "badge_bolt" },
	{ id = "star", name = "Star", texture = "badge_star" },
	{ id = "flame", name = "Flame", texture = "badge_flame" },
	{ id = "moon", name = "Moon", texture = "badge_moon" },
	{ id = "crystal", name = "Crystal", texture = "badge_crystal" },
	{ id = "skull", name = "Skull", texture = "badge_skull" },
}
W.BADGE_BY_ID = {}
for _, b in ipairs(W.BADGES) do W.BADGE_BY_ID[b.id] = b end

-- A badge id as sent or shown: a known id, else "".
function W.ValidBadge(id)
	id = str(id)
	id = id and id:lower()
	if id and W.BADGE_BY_ID[id] then return id end
	return ""
end

-- The rider's ride states, in order (never moving back, except a cancelled summon:
-- portal -> ingroup). Ended states have no rank.
local RANK = { requesting = 1, accepted = 2, invited = 3, ingroup = 4, summoning = 5, portal = 6, arrived = 7, paying = 8, done = 9 }
local ENDED = { done = true, declined = true, cancelled = true, timeout = true, failed = true }
W.RIDE_RANK = RANK
W.RIDE_ENDED = ENDED
-- How long a ride may stay in a state, and what it becomes then. (A rider who was told a place
-- in line is not held to "accepted": W.CheckRide waits while the driver is heard, NETK.QUEUE_SILENCE.)
local STATE_LIMIT = {
	requesting = { NETK.RIDE_TIMEOUT, "timeout" },
	accepted = { 120, "failed" },
	invited = { 60, "failed" },
	ingroup = { 600, "failed" },
	summoning = { 300, "failed" },
	portal = { 120, "failed" },
	arrived = { 600, "done" },
	paying = { 300, "done" },
}
W.RIDE_LIMITS = STATE_LIMIT

local function now()
	if type(GetTime) ~= "function" then return 0 end
	local ok, t = pcall(GetTime)
	return ok and num(t) or 0
end

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

-- A network number: W.Int (digits only), clamped; `default` when missing or bad.
local function netInt(s, lo, hi, default)
	local v = W.Int(s)
	if not v then return default end
	return clamp(v, lo, hi)
end

-- A local number (an API return or a provider's value) as a whole number, or nil.
local function localInt(v)
	v = num(v)
	if not v or v == math.huge or v == -math.huge then return nil end
	return math.floor(v + 0.5)
end

local function myKey()
	if W.myKey and W.myKey ~= "?" then return W.myKey end
	return W.Key(W.UnitName("player"))
end

local function call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if not ok then return nil end
	return a, b
end

local function clock()
	return num(call(time)) or 0
end

local function copy(t)
	local out = {}
	for k, v in pairs(t) do out[k] = v end
	return out
end

---------------------------------------------------------------------------
-- Names
---------------------------------------------------------------------------

-- A player's name to show: "Anita Lift-Realm" -> "Anita Lift", "Anita-Lift" -> "Anita Lift"
-- (with the game's own separator). nil if there is none.
function W.CleanName(name)
	name = str(name)
	if not name then return nil end
	name = W.Clean(name, 48)
	if name == "" then return nil end
	-- (SPEC5 realms: any realm tail goes, hyphenated first names stay; W.SplitName)
	name = W.SplitName(name) or name
	local first, last = name:match("^(%S+) (.+)$")
	if first then name = first .. W.Sep() .. last end
	return name
end

-- The address to whisper or invite: the sender exactly as the game gave it (cleaned of
-- control codes only). nil if there is none.
local function address(sender)
	sender = str(sender)
	if not sender then return nil end
	sender = W.Clean(sender, 64)
	if sender == "" then return nil end
	return sender
end

-- A name as a whisper macro needs it: "Anita Lift" -> "Anita-Lift" (W.Tell).
function W.MacroName(name)
	name = str(name)
	if not name then return nil end
	return W.Tell(W.Clean(name, 48))
end

---------------------------------------------------------------------------
-- Encoding: "kind~proto~field~field..."
---------------------------------------------------------------------------

local function field(v, limit)
	v = plain(v)
	if v == nil then return "" end
	if type(v) == "number" then
		local n = localInt(v) or 0
		return string.format("%d", clamp(n, 0, 999999999))
	end
	if type(v) == "boolean" then return v and "1" or "0" end
	return W.Clean(tostring(v), limit)
end

-- One message as text, never more than 255 bytes: numbers are sent as whole numbers
-- (0..999999999), text fields are cleaned (W.Clean: no "~", "|" or line breaks) and
-- shortened if need be.
function W.Encode(kind, ...)
	local n = select("#", ...)
	local args = { ... }
	local limit = 60
	while true do
		local parts = { W.Clean(kind, 4), tostring(W.PROTO) }
		for i = 1, n do parts[#parts + 1] = field(args[i], limit) end
		local text = table.concat(parts, "~")
		if #text <= NETK.MAX_BYTES then return text end
		if limit <= 0 then return text:sub(1, NETK.MAX_BYTES) end
		limit = math.max(0, limit - 8) -- shorten the text fields, keep every field
	end
end

-- A message's kind, protocol version and fields (a list of strings, empty ones kept), or
-- nil for anything that is not a Wuber message this version understands.
function W.Decode(text)
	text = str(text)
	if not text or #text > NETK.MAX_BYTES then return nil end
	local p = W.Split(text)
	local kind, proto = p[1], W.Int(p[2])
	if not (kind and KINDS[kind] and proto) then return nil end
	if proto > W.PROTO then return nil end
	local fields = {}
	for i = 3, #p do fields[#fields + 1] = p[i] end
	return kind, proto, fields
end

-- A ride id: six random letters.
function W.NewRideId()
	local letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
	local out = {}
	for i = 1, 6 do
		local k = math.random(1, #letters)
		out[i] = letters:sub(k, k)
	end
	return table.concat(out)
end

local function rideId(v)
	v = str(v)
	if v and #v == 6 and v:match("^%a+$") then return v end
	return nil
end

-- Whether a version string ("2.3.0", as a beacon or R field 6 carries it) is at least `min`.
-- An internal build's "-suffix" ("2.3.2-dev", PLAN-2.3.2 release rule) counts as its number:
-- a pre-release of 2.3.2 passes every 2.3.0 gate. Missing or garbled: false.
function W.VerAtLeast(ver, min)
	ver, min = str(ver), str(min)
	if ver then ver = ver:match("^(%d+[%d%.]*)%-%a[%w%.]*$") or ver end
	if not ver or not min or not ver:match("^%d+[%d%.]*$") then return false end
	local a, b = {}, {}
	for n in ver:gmatch("%d+") do a[#a + 1] = tonumber(n) end
	for n in min:gmatch("%d+") do b[#b + 1] = tonumber(n) end
	for i = 1, math.max(#a, #b) do
		local x, y = a[i] or 0, b[i] or 0
		if x ~= y then return x > y end
	end
	return true
end

-- The handler W.NetKind recorded for a kind, or nil (Net.Inbox: kinds it has no branch for).
local function netHandler(kind)
	return kind and NET_HANDLERS[kind] or nil
end

-- Our faction as the beacon carries it: "H", "A" or "".
function W.Faction()
	if type(UnitFactionGroup) ~= "function" then return "" end
	local f = str(call(UnitFactionGroup, "player"))
	if f == "Horde" then return "H" end
	if f == "Alliance" then return "A" end
	return ""
end

---------------------------------------------------------------------------
-- The channel
---------------------------------------------------------------------------

-- The channel's index once joined, else nil.
function W.ChannelIndex()
	if type(GetChannelName) ~= "function" then return nil end
	local ok, id = pcall(GetChannelName, W.CHANNEL)
	id = ok and num(id) or nil
	if id and id > 0 then return id end
	return nil
end

-- Whether this client is on the network (in the channel).
function W.OnNetwork()
	return W.ChannelIndex() ~= nil
end

-- Takes the channel out of every chat window: it is for addons only.
local function hideChannel()
	local n = num(NUM_CHAT_WINDOWS) or 10
	for i = 1, n do
		local f = _G["ChatFrame" .. i]
		if f then
			if type(ChatFrame_RemoveChannel) == "function" then
				pcall(ChatFrame_RemoveChannel, f, W.CHANNEL)
			elseif type(ChatFrameUtil) == "table" and type(ChatFrameUtil.RemoveChannel) == "function" then
				pcall(ChatFrameUtil.RemoveChannel, f, W.CHANNEL)
			end
		end
	end
end
W.HideChannel = hideChannel

local function isOurChannel(s)
	s = str(s)
	if not s then return false end
	s = s:lower():gsub("^%d+%.%s*", "")
	return s == W.CHANNEL:lower()
end

-- Chat filter (self, event, text, author, language, channelString, target, flags, zoneID,
-- channelIndex, channelBaseName): hides the join notice and anything said in our channel.
local function channelFilter(_, _, _, _, _, chanString, _, _, _, chanIndex, chanBase)
	local ok, ours = pcall(function()
		if isOurChannel(chanString) or isOurChannel(chanBase) then return true end
		local idx = num(chanIndex)
		return idx ~= nil and idx > 0 and idx == W.ChannelIndex()
	end)
	return (ok and ours) and true or false
end
W.ChannelFilter = channelFilter

-- "No player named X is currently playing." (ERR_CHAT_PLAYER_NOT_FOUND_S) -> "X", else nil.
local notFoundPattern
function W.NotFoundName(text)
	text = W.Str(text)
	if not text then return nil end
	if not notFoundPattern then
		local fmt = (type(ERR_CHAT_PLAYER_NOT_FOUND_S) == "string" and ERR_CHAT_PLAYER_NOT_FOUND_S)
			or "No player named '%s' is currently playing."
		local escaped = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
		notFoundPattern = "^" .. escaped:gsub("%%%%s", "(.+)") .. "$"
	end
	local ok, who = pcall(string.match, text, notFoundPattern)
	return ok and who or nil
end

---------------------------------------------------------------------------
-- The whisper fallback's state (its rounds are further down)
---------------------------------------------------------------------------
-- In game (Forever 1.60.1, a cluster of server nodes) a relog can put a client in a copy of
-- the channel of its own: its sends echo back, but nobody else hears it and it hears nobody,
-- while addon whispers between the same characters keep working. So a rider also asks the
-- drivers it knows by whisper (Q), and a driver answers a whispered Q with a whispered D
-- (and whispers its changes to those riders for 5.5 min). Channel kinds by whisper count only
-- for the sender itself, as on the channel.

local fb = {
	chanHeard = {},     -- key -> GetTime() of their last message over the channel
	chanOthersAt = nil, -- our last message from anyone else over the channel
	echoAt = nil,       -- our last echo of our own channel message
	joinedAt = nil,     -- when we joined the channel (this time)
	whispered = {},     -- key -> when our last addon whisper to them went out
	qAt = {},           -- key -> when we last whispered them a Q (rider)
	qAddr = {},         -- key -> the address that Q went to (rider; for B)
	offlineUntil = {},  -- key -> no Q to them before this: they were offline (rider)
	answeredAt = {},    -- key -> when a whispered D last came from them (rider)
	lastBeacon = {},    -- key -> { state, dest, at } of their last beacon (rider; toasts)
	peerOnChanAt = nil, -- last whispered D from a peer who hears others on the channel
	riders = {},        -- key -> { addr, at }: riders who whispered us a Q (driver)
	replyAt = {},       -- key -> when we last answered their whispered Q (driver)
	replies = {},       -- times of our whispered answers, for a cap (driver)
	qSent = {},         -- times of our whispered Qs, for a cap (rider)
	replyPending = {},  -- key -> true while our staggered answer to them waits (driver)
	booked = {},        -- key -> when they asked us for a ride or it ended paid (driver)
}
W.fallback = fb -- read by the tests and /wuber status

NETK.NOT_FOUND_WINDOW = 10 -- "No player named" this soon after our whisper to them is ours
NETK.SEEN_MAX = 60          -- drivers kept in W.db.seenDrivers (SPEC5 gossip: was 30)
NETK.SEEN_KEEP = 14 * 86400 -- ... for this long after they were last heard (time())

-- The rider's saved list of drivers heard lately: W.db.seenDrivers[key] = { name, addr, at = time() }.
local function seenList()
	local d0 = W.db or W.InitDB()
	if type(d0.seenDrivers) ~= "table" then d0.seenDrivers = {} end
	return d0.seenDrivers
end

-- Forgets drivers not heard for 14 days, and the oldest past 30.
local function pruneSeen()
	local list, stamp, n = seenList(), num(call(time)) or 0, 0
	for key, s in pairs(list) do
		local at = type(s) == "table" and num(s.at) or nil
		if not at or stamp - at > NETK.SEEN_KEEP or at > stamp + 86400 or type(key) ~= "string" then
			list[key] = nil
		else
			n = n + 1
		end
	end
	while n > NETK.SEEN_MAX do
		local oldKey, oldAt = nil, nil
		for key, s in pairs(list) do
			if not oldAt or s.at < oldAt or (s.at == oldAt and key < oldKey) then oldKey, oldAt = key, s.at end
		end
		list[oldKey] = nil
		n = n - 1
	end
end

-- A driver was heard (a beacon that passed the faction and fare filters).
local function rememberSeen(key, name, addr, ruleset, unlisted)
	local list = seenList()
	local s = list[key]
	local isNew = type(s) ~= "table"
	if isNew then s = {} end
	s.name, s.addr, s.at = name, addr, num(call(time)) or 0
	-- for tools/build-seeds.js: the driver's ruleset, and whether he opted out of the starter list
	s.ruleset = ruleset or s.ruleset
	s.unlisted = unlisted and true or nil
	list[key] = s
	if isNew then pruneSeen() end
end

-- Whether we whispered this key in the last few seconds (an addon whisper of ours).
local function whisperedRecently(key)
	local t = key and fb.whispered[key]
	return t ~= nil and now() - t <= NETK.NOT_FOUND_WINDOW
end

-- Hides "No player named ..." when it is about a Wuber driver or anyone our addon whispered
-- in the last 10 s (our addon whispers to someone offline would otherwise print it).
function W.SystemFilter(_, _, text)
	local ok, hide = pcall(function()
		local key = W.Key(W.NotFoundName(text))
		if not key then return false end
		return W.drivers[key] ~= nil or (W.ride ~= nil and W.ride.driverKey == key) or whisperedRecently(key)
	end)
	return (ok and hide) and true or false
end

local filtersAdded = false
local function addFilters()
	if filtersAdded then return end
	local add = (type(ChatFrame_AddMessageEventFilter) == "function" and ChatFrame_AddMessageEventFilter)
		or (type(ChatFrameUtil) == "table" and type(ChatFrameUtil.AddMessageEventFilter) == "function"
			and function(event, fn) return ChatFrameUtil.AddMessageEventFilter(event, fn) end) or nil
	if not add then return end
	filtersAdded = true
	for _, event in ipairs({ "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER", "CHAT_MSG_CHANNEL" }) do
		pcall(add, event, channelFilter)
	end
	pcall(add, "CHAT_MSG_SYSTEM", W.SystemFilter)
end
addFilters()

local wasOn, lastJoinTry = false, -100

-- Said instead of the 10-channels line when the join was refused for a password (requests go by whisper,
-- the same as with no channel at all).
local LOCKED_LINE = "The Wuber channel has a password; requests still work by whisper."
local lastClear, clearLater -- when this character last cleared a password, and whether one more clear is waiting (Mod.channelPassword)

-- A notice of a password on our channel (Net.Inbox). refused = false: a password was set; when we own the channel,
-- clear it (SetChannelPassword with an empty word; if that fails, treat the channel as locked), otherwise do nothing.
-- refused = true: our join was refused for a password. Locked means the failed-join line is the password one. Says it at once if the 10-channels line was already printed.
function Mod.channelPassword(refused)
	if not refused then
		local owner = type(IsDisplayChannelOwner) == "function" and select(2, pcall(IsDisplayChannelOwner))
		if owner ~= true then return end -- not ours to clear
		-- at most one clear in 30 s, whatever the notices say (a second player setting it again and again must not
		-- make this character answer each time)
		local t = now()
		if lastClear and t - lastClear < 30 then
			if not clearLater then
				clearLater = true
				W.After(31 - (t - lastClear), function() clearLater = false; Mod.channelPassword(false) end)
			end
			return
		end
		lastClear = t
		if type(SetChannelPassword) == "function" and pcall(SetChannelPassword, W.CHANNEL, "") then return end
	end
	W.net.locked = true
	if W.net.warned and not W.net.lockedSaid then
		W.net.lockedSaid = true
		W.Print(LOCKED_LINE)
	end
end

-- Looks at the channel: hides it, notices joining or losing it (fires "NETWORK" with
-- true/false), and with tryJoin joins it when not in it (at most every 10 s). Returns
-- whether we are in it.
function W.CheckChannel(tryJoin)
	if W.OnNetwork() then
		hideChannel()
		if not wasOn then
			wasOn = true
			W.net.joined = true
			W.net.locked = nil
			fb.joinedAt, fb.echoAt = now(), nil
			W.Fire("NETWORK", true)
			Mod.onJoined()
		end
		return true
	end
	if wasOn then
		wasOn = false
		W.net.joined = false
		fb.joinedAt = nil
		W.Fire("NETWORK", false)
	end
	-- after two failed joins (10 channels already?) ask only once a minute: a refused join
	-- may print a line in chat each time
	if tryJoin and now() - lastJoinTry >= (((W.net.joinFails or 0) >= 2) and 60 or 10) then
		lastJoinTry = now()
		local join = (type(JoinTemporaryChannel) == "function" and JoinTemporaryChannel)
			or (type(JoinChannelByName) == "function" and JoinChannelByName) or nil
		if join then pcall(join, W.CHANNEL) end
		W.After(3, function()
			if W.CheckChannel(false) then
				W.net.joinFails = 0
				return
			end
			W.net.joinFails = (W.net.joinFails or 0) + 1
			if W.net.joinFails >= 2 and not W.net.warned then
				W.net.warned = true
				if W.net.locked then
					W.net.lockedSaid = true
					W.Print(LOCKED_LINE)
				else
					W.Print("Couldn't join the Wuber network. You may be in 10 chat channels already. You may see fewer drivers, but requests still work by whisper.")
				end
			end
		end)
	end
	return false
end

-- Whether the game has put us in any channel yet (General, Trade...): we join after them
-- so they keep /1 and /2.
local function hasChannels()
	if type(GetChannelList) ~= "function" then return false end
	local ok, first = pcall(GetChannelList)
	return ok and plain(first) ~= nil
end

-- for the Net modules that load after this one (REFACTOR-MAP section 2)
Mod.CHANNEL_KINDS, Mod.ENDED, Mod.KINDS, Mod.NETK, Mod.RANK, Mod.REASONS = CHANNEL_KINDS, ENDED, KINDS, NETK, RANK, REASONS
Mod.STAGES, Mod.STAGE_ALIAS, Mod.STATES, Mod.STATE_LIMIT, Mod.WHISPER_TOO, Mod.addFilters = STAGES, STAGE_ALIAS, STATES, STATE_LIMIT, WHISPER_TOO, addFilters
Mod.address, Mod.call, Mod.clamp, Mod.clock, Mod.copy, Mod.fb = address, call, clamp, clock, copy, fb
Mod.hasChannels, Mod.hideChannel, Mod.isOurChannel, Mod.localInt, Mod.myKey, Mod.netInt = hasChannels, hideChannel, isOurChannel, localInt, myKey, netInt
Mod.now, Mod.pruneSeen, Mod.rememberSeen, Mod.rideId, Mod.seenList, Mod.whisperedRecently = now, pruneSeen, rememberSeen, rideId, seenList, whisperedRecently
function Mod.resetJoinTry() lastJoinTry = -100 end -- (Net.Discovery: the channel rejoin)
Mod.netHandler = netHandler
