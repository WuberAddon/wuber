-- Net: the Wuber network. Drivers send beacons over a hidden chat channel; riders keep a
-- list of the drivers they hear. A ride is asked for, accepted and followed by addon
-- whispers between the rider and the driver. See SPEC.md, "Protocol" and "Advisor fixes".
--
-- Rider side:  W.drivers, W.ride, W.RequestRide, W.CancelRide, W.Rate, W.ClearRide, W.Ping,
--              W.RequestWhisper / W.CancelWhisper (text for the UI's secure buttons),
--              W.AcceptInvite, W.AcceptSummon, W.LeaveGroup
-- Driver side: W.incoming, W.AcceptRequest, W.DeclineRequest, W.SendStage, W.SetDriving,
--              W.SetLocalDriver (Driver.lua), WuberAPI (for driver addons)
-- Both:        W.SendChannel, W.SendTo, W.OnNetwork, W.Encode, W.Decode
--
-- Every outgoing message goes through one queue: about one a second, bursts of 4,
-- whispers ahead of channel messages, and a queued beacon (or a queued stage for the same
-- ride) is replaced by a newer one rather than sent twice.
--
-- Trust: D/X/Q count only from the channel, R/A/N/C/S/T only by whisper. A/N/S count only
-- from the driver of our ride; C/T only from that ride's buyer. Every field is cleaned on
-- receipt; whispers go to the event's sender, never to a name inside a message.

local _, W = ...

local plain, str, num = W.Plain, W.Str, W.Num

local DRIVER_TTL = 150    -- a driver is dropped this long after its last beacon
local RIDE_TIMEOUT = 40   -- a request with no answer times out
local RESEND_AFTER = 8    -- R is sent once more after this long without A or N
local BEACON_EVERY = 60   -- seconds between beacons (plus or minus BEACON_JITTER)
local BEACON_JITTER = 10
local BEACON_GAP = 5      -- changes are beaconed at most once per this many seconds
local Q_QUIET = 15        -- a driver answers at most one Q in this many seconds
local PING_GAP = 20       -- a rider sends Q at most once per this, and not after hearing one
local ACCEPT_WINDOW = 30  -- Wuber's own driver mode: unanswered requests get "N busy"
local BURST = 4           -- messages that may go out at once
local RATE = 1            -- messages a second after that
local MAX_QUEUE = 40
local MAX_BYTES = 255
local MAX_INCOMING = 20   -- open requests a driver holds before saying "full"
local INCOMING_MAX_AGE = 1800
local RESTORE_MAX_AGE = 600 -- a saved ride is picked up again after /reload if this fresh

local MAX_PRICE = 99999999

W.drivers = W.drivers or {}
W.incoming = W.incoming or {}
W.ride = nil
W.net = { sent = 0, failed = 0, heard = 0, dropped = 0, joined = false, warned = false }

local STATES = { open = true, busy = true, paused = true }
local REASONS = { busy = true, full = true, closed = true, blocked = true, price = true }
local KINDS = { D = true, X = true, Q = true, R = true, A = true, N = true, C = true, S = true, T = true }
local CHANNEL_KINDS = { D = true, X = true, Q = true }
-- S stages on the wire; "waiting" (an older word for portal) is sent as "portal"
local STAGES = { invited = true, summoning = true, portal = true, arrived = true, paid = true, done = true }
local STAGE_ALIAS = { waiting = "portal" }
W.STAGES = { "invited", "summoning", "portal", "arrived", "paid", "done" }
W.DECLINE_REASONS = { "busy", "full", "closed", "blocked", "price" }

-- The rider's ride states, in order (never moving back, except a cancelled summon:
-- portal -> ingroup). Ended states have no rank.
local RANK = { requesting = 1, accepted = 2, invited = 3, ingroup = 4, summoning = 5, portal = 6, arrived = 7, paying = 8, done = 9 }
local ENDED = { done = true, declined = true, cancelled = true, timeout = true, failed = true }
W.RIDE_RANK = RANK
W.RIDE_ENDED = ENDED
-- How long a ride may stay in a state, and what it becomes then.
local STATE_LIMIT = {
	requesting = { RIDE_TIMEOUT, "timeout" },
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
	local person = name:match("^(%S+ %S+)%-.+$")
	if person then name = person end
	if not name:find(" ", 1, true) then
		local first, last = name:match("^([^%-]+)%-([^%-]+)$")
		if first then name = first .. W.Sep() .. last end
	end
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
		if #text <= MAX_BYTES then return text end
		if limit <= 4 then return text:sub(1, MAX_BYTES) end
		limit = limit - 8
	end
end

-- A message's kind, protocol version and fields (a list of strings, empty ones kept), or
-- nil for anything that is not a Wuber message this version understands.
function W.Decode(text)
	text = str(text)
	if not text or #text > MAX_BYTES then return nil end
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

-- Hides "No player named ..." when it is about a Wuber driver (our addon whispers to a
-- driver who went offline would otherwise print it).
function W.SystemFilter(_, _, text)
	local ok, hide = pcall(function()
		local key = W.Key(W.NotFoundName(text))
		if not key then return false end
		return W.drivers[key] ~= nil or (W.ride ~= nil and W.ride.driverKey == key)
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
local onJoined -- defined with the beacons

-- Looks at the channel: hides it, notices joining or losing it (fires "NETWORK" with
-- true/false), and with tryJoin joins it when not in it (at most every 10 s). Returns
-- whether we are in it.
function W.CheckChannel(tryJoin)
	if W.OnNetwork() then
		hideChannel()
		if not wasOn then
			wasOn = true
			W.net.joined = true
			W.Fire("NETWORK", true)
			onJoined()
		end
		return true
	end
	if wasOn then
		wasOn = false
		W.net.joined = false
		W.Fire("NETWORK", false)
	end
	if tryJoin and now() - lastJoinTry >= 10 then
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
				W.Print("Couldn't join the Wuber network. You may be in 10 chat channels already. You can't see drivers, but requests still work by whisper.")
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

---------------------------------------------------------------------------
-- Sending: one queue, rate-limited
---------------------------------------------------------------------------

local queue = {}
local tokens, lastRefill = BURST, nil
local flushPending = false

local THROTTLED = { [3] = true, [8] = true } -- AddonMessageThrottle, ChannelThrottle
do
	local E = type(Enum) == "table" and Enum.SendAddonMessageResult
	if type(E) == "table" then
		if num(E.AddonMessageThrottle) then THROTTLED[E.AddonMessageThrottle] = true end
		if num(E.ChannelThrottle) then THROTTLED[E.ChannelThrottle] = true end
	end
end

-- true: done with (sent, or can never be sent); false: the game said "too fast", later
local function transmit(item)
	local CI = C_ChatInfo
	if type(CI) ~= "table" or type(CI.SendAddonMessage) ~= "function" then
		W.net.failed = W.net.failed + 1
		return true
	end
	local target = item.target
	if item.chan == "CHANNEL" then
		target = W.ChannelIndex() -- read again: the index can change
		if not target then
			W.net.dropped = W.net.dropped + 1
			return true
		end
	end
	local ok, res = pcall(CI.SendAddonMessage, W.PREFIX, item.text, item.chan, target)
	if not ok then
		W.net.failed = W.net.failed + 1
		return true
	end
	res = plain(res)
	if type(res) == "number" and THROTTLED[res] then
		item.tries = (item.tries or 0) + 1
		if item.tries < 10 then return false end
		W.net.failed = W.net.failed + 1
		return true
	end
	if res == nil or res == true or res == 0 then
		W.net.sent = W.net.sent + 1
	else
		W.net.failed = W.net.failed + 1
	end
	return true
end

local function refill()
	local t = now()
	if not lastRefill then lastRefill = t end
	if t > lastRefill then tokens = math.min(BURST, tokens + (t - lastRefill) * RATE) end
	lastRefill = t
end

-- Sends what the rate allows now; the rest waits for a timer.
function W.FlushQueue()
	refill()
	while #queue > 0 and tokens >= 1 do
		if not transmit(queue[1]) then
			tokens = 0
			break
		end
		table.remove(queue, 1)
		tokens = tokens - 1
	end
	if #queue > 0 and not flushPending then
		flushPending = true
		W.After(math.max(0.1, (1 - tokens) / RATE), function()
			flushPending = false
			W.FlushQueue()
		end)
	end
end

-- How many messages are waiting to go out.
function W.QueueLength() return #queue end

local function enqueue(chan, target, kind, text, coalesce)
	if coalesce then
		for _, item in ipairs(queue) do
			if item.coalesce == coalesce and item.chan == chan then
				item.text, item.kind, item.target, item.tries = text, kind, target, 0
				return true
			end
		end
	end
	if #queue >= MAX_QUEUE then
		table.remove(queue, 1)
		W.net.dropped = W.net.dropped + 1
	end
	local item = { chan = chan, target = target, kind = kind, text = text, coalesce = coalesce }
	local at = #queue + 1
	if chan == "WHISPER" then
		-- a whisper goes ahead of every channel message still waiting
		for i, other in ipairs(queue) do
			if other.chan == "CHANNEL" then
				at = i
				break
			end
		end
	end
	table.insert(queue, at, item)
	W.FlushQueue()
	return true
end

-- Sends a message to everyone on the channel: W.SendChannel("D", dest, mapID, ...).
-- A queued D or X is replaced by the newer one, a queued Q is not doubled. Returns false
-- when not on the network.
function W.SendChannel(kind, ...)
	if not CHANNEL_KINDS[kind] or not W.OnNetwork() then return false end
	local coalesce = (kind == "Q") and "ping" or "beacon"
	return enqueue("CHANNEL", nil, kind, W.Encode(kind, ...), coalesce)
end

-- Sends a message by addon whisper to one player: W.SendTo("Anita Lift", "R", id, ...).
-- A queued S for the same ride and player is replaced. Returns false for a bad name, or
-- ourselves.
function W.SendTo(name, kind, ...)
	local target = address(name)
	local key = W.Key(target)
	if not KINDS[kind] or CHANNEL_KINDS[kind] or not key or key == myKey() then return false end
	local coalesce = nil
	if kind == "S" then coalesce = "S:" .. tostring((...)) .. ":" .. key end
	return enqueue("WHISPER", target, kind, W.Encode(kind, ...), coalesce)
end

---------------------------------------------------------------------------
-- Groups, invites, summons (each call guarded)
---------------------------------------------------------------------------

-- Whether the player with this name or key is in our party or raid.
function W.InGroupWith(key)
	key = key and W.Key(key)
	if not key then return false end
	for i = 1, 4 do
		if W.Key(W.UnitName("party" .. i)) == key then return true end
	end
	for i = 1, 40 do
		if W.Key(W.UnitName("raid" .. i)) == key then return true end
	end
	return false
end

-- Invites a player to our group (no click needed). Returns whether the call went through.
function W.Invite(name)
	name = address(name)
	if not name then return false end
	local fn = type(C_PartyInfo) == "table" and C_PartyInfo.InviteUnit or nil
	if type(fn) ~= "function" then fn = InviteUnit end
	if type(fn) ~= "function" then return false end
	return (pcall(fn, name))
end

-- Leaves the group (for "Leave your group first"). Returns whether the call went through.
function W.LeaveGroup()
	local fn = type(C_PartyInfo) == "table" and C_PartyInfo.LeaveParty or nil
	if type(fn) ~= "function" then fn = LeaveParty end
	if type(fn) ~= "function" then return false end
	return (pcall(fn))
end

-- Marks the visible party invite box as accepted and hides it. Hiding it without the mark
-- would decline the invite, so it is only hidden when found.
local function hideInvitePopup()
	if type(StaticPopup_FindVisible) ~= "function" then return end
	local dialog = plain(call(StaticPopup_FindVisible, "PARTY_INVITE"))
	if type(dialog) ~= "table" then return end
	pcall(function() dialog.inviteAccepted = 1 end)
	if type(StaticPopup_Hide) == "function" then pcall(StaticPopup_Hide, "PARTY_INVITE") end
end

-- Accepts the party invite (only from a button click). Returns whether AcceptGroup ran.
function W.AcceptInvite()
	if type(AcceptGroup) ~= "function" then return false end
	local ok = pcall(AcceptGroup)
	hideInvitePopup()
	W.After(0.2, hideInvitePopup)
	return ok
end

-- Accepts the summon (only from a button click). Returns true, or false and a short line
-- for the player.
function W.AcceptSummon()
	if W.InCombat() then return false, "Leave combat first." end
	local fn = type(C_SummonInfo) == "table" and C_SummonInfo.ConfirmSummon or nil
	if type(fn) ~= "function" then fn = ConfirmSummon end
	if type(fn) ~= "function" or not pcall(fn) then
		return false, "Click Accept on the game's summon box."
	end
	local r = W.ride
	if r then
		r.summonAccepted = true
		W.After(2, function() if W.CheckArrival then W.CheckArrival() end end)
		W.After(5, function() if W.CheckArrival then W.CheckArrival() end end)
	end
	return true
end

-- Whether the player is a Warlock.
function W.IsWarlock()
	if type(UnitClass) ~= "function" then return false end
	local ok, _, class = pcall(UnitClass, "player")
	return ok and str(class) == "WARLOCK"
end

local function money()
	return num(call(GetMoney))
end

---------------------------------------------------------------------------
-- Drivers (what a rider hears)
---------------------------------------------------------------------------

-- Drops drivers not heard from for 150 s. Fires "DRIVERS" if any went.
function W.ExpireDrivers()
	local t, gone = now(), false
	for key, d in pairs(W.drivers) do
		if t - (d.heard or 0) > DRIVER_TTL then
			W.drivers[key] = nil
			gone = true
		end
	end
	if gone then W.Fire("DRIVERS") end
	return gone
end

-- D: dest, mapID, x, y, price, service, state, team, seats, faction, ver
local function heardBeacon(addr, name, key, f, proto)
	local faction, mine = f[10], W.Faction()
	if (faction == "H" or faction == "A") and mine ~= "" and faction ~= mine then
		-- the other faction: not a driver for us
		if W.drivers[key] then
			W.drivers[key] = nil
			W.Fire("DRIVERS")
		end
		return
	end
	local d = W.drivers[key] or {}
	d.key, d.name, d.addr = key, name, addr
	local dest = W.CleanDest(f[1])
	d.dest = dest ~= "" and dest or "Unknown"
	local mapID = W.Int(f[2])
	d.mapID = (mapID and mapID > 0) and mapID or nil
	local x, y = W.Int(f[3]), W.Int(f[4])
	d.x = x and clamp(x, 0, 1000) / 1000 or nil
	d.y = y and clamp(y, 0, 1000) / 1000 or nil
	d.price = netInt(f[5], 0, MAX_PRICE, 0)
	if d.price < W.MIN_PRICE then
		-- below the network's lowest fare: not shown to riders at all
		if W.drivers[key] then
			W.drivers[key] = nil
			W.Fire("DRIVERS")
		end
		return
	end
	local service = W.CleanDest(f[6])
	d.service = service ~= "" and service or name
	d.state = STATES[f[7] or ""] and f[7] or "paused"
	d.team = netInt(f[8], 1, 3, 1)
	d.seats = netInt(f[9], 0, 40, 0)
	d.faction = (faction == "H" or faction == "A") and faction or nil
	local ver = (f[11] or ""):gsub("[^%d%.]", "")
	d.ver = ver ~= "" and ver:sub(1, 12) or nil
	d.proto = proto
	d.heard = now()
	W.drivers[key] = d
	W.Fire("DRIVERS")
end

-- All known drivers, sorted by price then name (the tables themselves: read only).
function W.DriversSorted()
	local list = {}
	for _, d in pairs(W.drivers) do list[#list + 1] = d end
	table.sort(list, function(a, b)
		local pa, pb = a.price or 0, b.price or 0
		if pa ~= pb then return pa < pb end
		local na, nb = tostring(a.name):lower(), tostring(b.name):lower()
		if na ~= nb then return na < nb end
		return tostring(a.key) < tostring(b.key)
	end)
	return list
end

local lastPing, lastQHeard = -1000, -1000

-- Asks every driver to send a beacon now (Q). Not sent within 20 s of our own Q or of
-- hearing someone else's (the drivers are answering that one).
-- Returns true when sent; true, "recent" when someone else just asked; false, "offline"
-- off the network; false, seconds to wait.
function W.Ping()
	if not W.OnNetwork() then return false, "offline" end
	local t = now()
	local wait = PING_GAP - (t - lastPing)
	if wait > 0 then return false, math.ceil(wait) end
	if t - lastQHeard < PING_GAP then return true, "recent" end
	lastPing = t
	W.SendChannel("Q")
	return true
end

---------------------------------------------------------------------------
-- Being a driver: beacons
---------------------------------------------------------------------------

W.provider = nil
local localDriver = nil

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

-- A beacon table made safe. Named keys (the same nine in order are also read).
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
	local service = W.CleanDest(pick(b, "service", 6))
	if service == "" then service = W.CleanDest(W.Me()) end
	return {
		dest = dest,
		mapID = (mapID and mapID > 0) and mapID or nil,
		x = x and clamp(x, 0, 1) or nil,
		y = y and clamp(y, 0, 1) or nil,
		price = clamp(localInt(pick(b, "price", 5)) or 0, W.MIN_PRICE, MAX_PRICE),
		service = service,
		state = STATES[state or ""] and state or "open",
		team = clamp(localInt(pick(b, "team", 8)) or 1, 1, 3),
		seats = clamp(localInt(pick(b, "seats", 9)) or 0, 0, 40),
	}
end

-- What this client would beacon as a driver: { dest, mapID, x, y, price, service, state,
-- team, seats } from the provider if one is set, else from Driver.lua; nil when not driving.
function W.DriverBeacon()
	local fn
	if type(W.provider) == "table" then fn = W.provider.beacon else fn = localDriver end
	if type(fn) ~= "function" then return nil end
	local ok, b = pcall(fn)
	if not ok then
		W.Error("beacon", b)
		return nil
	end
	return normaliseBeacon(b)
end

local beacon = { online = false, sig = nil, at = -1000, nextAt = 0, pending = false }
local beaconedPrices = {} -- price -> when last beaconed

local function signature(b) -- position alone is not a change
	return table.concat({ b.dest, tostring(b.mapID), b.price, b.service, b.state, b.team, b.seats }, "|")
end

-- Whether a request at `price` is fair: at least our price now, or a price we beaconed in
-- the last 150 s (the rider saw that one).
function W.PriceOk(price, current)
	price = localInt(price) or 0
	if price >= (current or 0) then return true end
	local at = beaconedPrices[price]
	return at ~= nil and now() - at <= DRIVER_TTL
end

-- Sends our beacon (D) now, or once 5 s have passed since the last; or X once if we have
-- just stopped driving. Returns whether a D was sent or is on its way.
function W.SendBeacon()
	local b = W.DriverBeacon()
	if not b then
		if beacon.online then
			beacon.online, beacon.sig = false, nil
			W.SendChannel("X")
		end
		return false
	end
	if not W.OnNetwork() then return false end
	local wait = BEACON_GAP - (now() - beacon.at)
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
	local x = b.x and math.floor(b.x * 1000 + 0.5) or nil
	local y = b.y and math.floor(b.y * 1000 + 0.5) or nil
	W.SendChannel("D", b.dest, b.mapID, x, y, b.price, b.service, b.state, b.team, b.seats, W.Faction(), W.VERSION)
	beacon.online, beacon.sig, beacon.at = true, signature(b), now()
	beacon.nextAt = now() + BEACON_EVERY + (math.random() * 2 - 1) * BEACON_JITTER
	beaconedPrices[b.price] = now()
	return true
end

local function tickBeacon()
	local b = W.DriverBeacon()
	if not b then
		if beacon.online then W.SendBeacon() end
		return
	end
	if beacon.pending or not W.OnNetwork() then return end
	if not beacon.online or signature(b) ~= beacon.sig or now() >= beacon.nextAt then
		W.SendBeacon()
	end
end

-- A rider asked "who's driving?". Every Q gets an answer (a rider who just arrived missed
-- the last beacon), but a driver answers at most one Q per Q_QUIET seconds: riders hold
-- their own Q for 20 s after hearing any, so this keeps a crowd from flooding the channel.
local replyPending, lastQReply = false, -1000
local function heardPing()
	lastQHeard = now()
	if replyPending or not W.DriverBeacon() then return end
	if now() - lastQReply < Q_QUIET then return end
	replyPending = true
	lastQReply = now()
	W.After(0.5 + math.random() * 2.5, function()
		replyPending = false
		W.SendBeacon()
	end)
end

onJoined = function()
	W.Ping() -- just arrived: ask the drivers where they are
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

---------------------------------------------------------------------------
-- Being a driver: requests coming in
---------------------------------------------------------------------------

local finished = {}       -- rideId -> buyer key, for rides that ended (a rating comes later)
local finishedOrder = {}
local rated = {}          -- rideId -> true once a rating was taken
local closedReply = {}    -- buyer key -> when we last said "closed" (no floods)

-- The request with this id (and from this buyer key, if given).
local function findIncoming(id, key)
	for i, r in ipairs(W.incoming) do
		if r.id == id and (not key or r.buyerKey == key) then return r, i end
	end
	return nil
end

local function remember(id, key)
	if not id or finished[id] then return end
	finished[id] = key or true
	finishedOrder[#finishedOrder + 1] = id
	if #finishedOrder > 40 then finished[table.remove(finishedOrder, 1)] = nil end
end

local function removeIncoming(r)
	for i, other in ipairs(W.incoming) do
		if other == r then
			table.remove(W.incoming, i)
			remember(r.id, r.buyerKey)
			return true
		end
	end
	return false
end

local function providerCall(name, ...)
	local p = W.provider
	local fn = type(p) == "table" and p[name] or nil
	if type(fn) ~= "function" then return end
	local ok, err = pcall(fn, ...)
	if not ok then W.Error("provider " .. name, err) end
end

local function sayClosed(addr, key, id)
	local t = closedReply[key]
	if t and now() - t < 10 then return end
	closedReply[key] = now()
	W.SendTo(addr, "N", id, "closed")
end

-- R: rideId, dest, price
local function heardRequest(addr, name, key, f)
	local id = rideId(f[1])
	if not id then return end
	-- the same request again (the rider resends after 8 s): answer A again if accepted
	for _, r in ipairs(W.incoming) do
		if r.buyerKey == key and r.id == id then
			if r.state == "accepted" then W.SendTo(r.buyer, "A", r.id, r.price, r.eta or 5) end
			return
		end
	end
	local b = W.DriverBeacon()
	if not b or (not W.provider and b.state == "paused") then
		sayClosed(addr, key, id)
		return
	end
	local price = netInt(f[3], 0, MAX_PRICE, 0)
	if price < W.MIN_PRICE or (not W.provider and not W.PriceOk(price, b.price)) then
		W.SendTo(addr, "N", id, "price")
		return
	end
	-- one request per rider: a new one replaces the old
	for i = #W.incoming, 1, -1 do
		if W.incoming[i].buyerKey == key then table.remove(W.incoming, i) end
	end
	if #W.incoming >= MAX_INCOMING then
		W.SendTo(addr, "N", id, "full")
		W.Fire("REQUESTS", W.incoming)
		return
	end
	local dest = W.CleanDest(f[2])
	local ride = {
		id = id, buyer = addr, name = name, buyerKey = key,
		dest = dest ~= "" and dest or b.dest,
		price = price, at = now(), state = "new",
	}
	W.incoming[#W.incoming + 1] = ride
	W.Fire("REQUESTS", W.incoming)
	if W.provider then providerCall("onRequest", copy(ride)) end
end

local function target(r, buyer)
	return (r and r.buyer) or address(buyer)
end

-- Accepts a request: whispers A (price, eta = seconds until the invite) to the rider.
-- buyer (optional) picks the rider when ids could clash, and is the address used for a ride
-- this client no longer lists. price (optional, copper): the fare the driver will really
-- charge, when it differs from the request's (e.g. after a price change); it replaces the
-- ride's price. The invite is up to the caller (W.Invite). Returns whether A was sent.
function W.AcceptRequest(id, eta, buyer, price)
	id = rideId(id)
	if not id then return false end
	local r = findIncoming(id, W.Key(buyer))
	local to = target(r, buyer)
	if not to then return false end
	eta = clamp(localInt(eta) or 5, 0, 3600)
	local charged = localInt(price)
	if charged then
		charged = clamp(charged, W.MIN_PRICE, MAX_PRICE)
		if r then r.price = charged end
	end
	price = charged or (r and r.price)
	if not price then
		local b = W.DriverBeacon()
		price = b and b.price or 0
	end
	if not W.SendTo(to, "A", id, price, eta) then return false end
	if r then
		r.state, r.eta, r.acceptedAt = "accepted", eta, now()
		W.Fire("REQUESTS", W.incoming)
	end
	return true
end

-- Declines a request: whispers N with a reason (busy, full, closed, blocked, price; any
-- other is sent as busy) and drops it from W.incoming. Returns whether N was sent.
function W.DeclineRequest(id, reason, buyer)
	id = rideId(id)
	if not id then return false end
	local r = findIncoming(id, W.Key(buyer))
	local to = target(r, buyer)
	if not to then return false end
	reason = str(reason)
	if not (reason and REASONS[reason]) then reason = "busy" end
	local sent = W.SendTo(to, "N", id, reason)
	if r and removeIncoming(r) then W.Fire("REQUESTS", W.incoming) end
	return sent
end

-- Tells the rider how the ride is going: stage invited, summoning (ritual being cast),
-- portal (the summon is up; "waiting" is taken as portal), arrived, paid or done. After
-- paid or done the ride leaves W.incoming. Returns whether S was sent.
function W.SendStage(id, stage, buyer)
	id = rideId(id)
	stage = str(stage)
	stage = stage and (STAGE_ALIAS[stage] or stage)
	if not id or not (stage and STAGES[stage]) then return false end
	local r = findIncoming(id, W.Key(buyer))
	local to = target(r, buyer)
	if not to then return false end
	local sent = W.SendTo(to, "S", id, stage)
	if r then
		r.stage = stage
		if stage == "paid" or stage == "done" then removeIncoming(r) end
		W.Fire("REQUESTS", W.incoming)
	end
	return sent
end

-- C: rideId (only from that ride's buyer)
local function heardCancel(key, f)
	local id = rideId(f[1])
	local r = id and findIncoming(id, key)
	if not r then return end
	removeIncoming(r)
	W.Fire("REQUESTS", W.incoming)
	if W.provider then providerCall("onCancel", id, r.buyer) end
end

-- T: rideId, stars (only from that ride's buyer, once)
local function heardRating(addr, name, key, f)
	local id = rideId(f[1])
	local stars = W.Int(f[2])
	if not id or not stars or rated[id] then return end
	stars = clamp(stars, 1, 5)
	local r = findIncoming(id, key)
	if not r and finished[id] ~= key then return end
	rated[id] = true
	if W.provider then
		providerCall("onRating", id, r and r.buyer or addr, stars)
		return
	end
	W.Fire("RATING", id, name, stars)
	W.Print(W.Short(name) .. " rated your ride " .. stars .. " out of 5.")
end

local function tickIncoming()
	local t, changed = now(), false
	for i = #W.incoming, 1, -1 do
		local r = W.incoming[i]
		local age = t - (r.at or 0)
		if r.state == "new" and not W.provider and age >= ACCEPT_WINDOW then
			W.DeclineRequest(r.id, "busy", r.buyer) -- removes it
			changed = true
		elseif (r.state == "new" and age >= RIDE_TIMEOUT) or age >= INCOMING_MAX_AGE then
			removeIncoming(r)
			changed = true
		end
	end
	if changed then W.Fire("REQUESTS", W.incoming) end
end

---------------------------------------------------------------------------
-- Being a rider: the ride
---------------------------------------------------------------------------

-- Whether the rider has a ride under way (not ended).
function W.RideActive()
	return W.ride ~= nil and not ENDED[W.ride.state]
end

local SAVED = { "id", "driver", "addr", "driverKey", "service", "dest", "price", "state", "stage",
	"eta", "rated", "stars", "paid", "from", "reason", "summonAccepted", "inviter" }

-- Keeps the ride in W.db.ride (picked up again after a /reload).
local function persist(r)
	if not W.db then return end
	if not r then
		W.db.ride = nil
		return
	end
	local saved = { savedAt = clock() }
	for _, k in ipairs(SAVED) do saved[k] = r[k] end
	W.db.ride = saved
end

local function fireRide(r)
	if r == W.ride then persist(r) end
	W.Fire("RIDE", r)
end

local function saveTrip(r)
	if r.trip then return end
	r.trip = { at = clock(), driver = r.driver, dest = r.dest, price = r.price, stars = r.stars }
	W.AddTrip(r.trip)
end

-- Moves the ride forward (never back). Fires "RIDE". Returns whether it moved.
local function advance(r, state)
	if r ~= W.ride or ENDED[r.state] then return false end
	if (RANK[state] or 0) <= (RANK[r.state] or 0) then return false end
	r.state, r.changed = state, now()
	if state == "done" then saveTrip(r) end
	fireRide(r)
	return true
end

-- Ends the ride (declined, cancelled, timeout, failed). Fires "RIDE".
local function finish(r, state, reason)
	if r ~= W.ride or ENDED[r.state] then return false end
	r.state, r.reason, r.changed = state, reason, now()
	fireRide(r)
	return true
end

-- A driver who logged off without saying so: the game answers our whisper with "No player
-- named ...". Drop the driver at once, and end a ride still waiting on them (no resend, no C).
W.On("CHAT_MSG_SYSTEM", function(text)
	local key = W.Key(W.NotFoundName(text))
	if not key then return end
	if W.drivers[key] then
		W.drivers[key] = nil
		W.Fire("DRIVERS")
	end
	local r = W.ride
	if r and r.driverKey == key and (r.state == "requesting" or r.state == "accepted") then
		finish(r, "declined", "closed")
	end
end)

-- Whether the ride's driver, or whoever invited us for it, is in our group.
local function rideGroup(r)
	return W.InGroupWith(r.driverKey) or (r.inviter ~= nil and W.InGroupWith(r.inviter))
end

-- Asks a driver for a ride: sets up W.ride (state "requesting") and sends R. The chat
-- whisper is the UI's secure button (W.RequestWhisper). Returns the ride, or nil and why:
-- "gone" (no such driver), "self", "active" (another ride is under way), "paused",
-- "group" (we are in a group without that driver: "Leave your group first").
-- Asking the same driver again while still requesting returns the same ride.
function W.RequestRide(driverKey)
	local d = W.drivers[driverKey] or W.drivers[W.Key(driverKey) or ""]
	if not d then return nil, "gone" end
	if d.key == myKey() then return nil, "self" end
	if W.RideActive() then
		if W.ride.state == "requesting" and W.ride.driverKey == d.key then return W.ride end
		return nil, "active"
	end
	if d.state == "paused" then return nil, "paused" end
	if W.InGroup() and not W.InGroupWith(d.key) then return nil, "group" end
	local r = {
		id = W.NewRideId(), driver = d.name, addr = d.addr or d.name, driverKey = d.key,
		service = d.service, dest = d.dest, price = d.price, state = "requesting",
		at = now(), changed = now(), from = (W.DestHere()),
	}
	W.ride = r
	W.SendTo(r.addr, "R", r.id, r.dest, r.price)
	fireRide(r)
	W.After(RESEND_AFTER, function() W.Safe("resend", W.CheckRide) end)
	W.After(RIDE_TIMEOUT, function() W.Safe("timeout", W.CheckRide) end)
	return r
end

-- Cancels the ride before arrival: whispers C to the driver; state "cancelled". The chat
-- line is an optional extra (W.CancelWhisper). Returns whether it cancelled.
function W.CancelRide()
	local r = W.ride
	if not W.RideActive() or (RANK[r.state] or 0) >= RANK.arrived then return false end
	W.SendTo(r.addr, "C", r.id)
	return finish(r, "cancelled")
end

-- Rates the ride 1-5 stars (once, after arrival): whispers T and keeps the stars with the
-- saved trip. Returns whether it was sent.
function W.Rate(stars)
	local r = W.ride
	stars = localInt(stars)
	if not r or r.rated or not stars then return false end
	local rank = RANK[r.state]
	if not rank or rank < RANK.arrived then return false end
	stars = clamp(stars, 1, 5)
	r.rated, r.stars = true, stars
	if r.trip then r.trip.stars = stars end
	W.SendTo(r.addr, "T", r.id, stars)
	fireRide(r)
	return true
end

-- Forgets the ride (after "Done" or "Try another driver"), cancelling it first if it is
-- still under way. Does not fire "RIDE".
function W.ClearRide()
	if W.RideActive() then W.CancelRide() end
	W.ride = nil
	persist(nil)
end

-- The chat line the Request button whispers, and the name to whisper (with a hyphen):
-- "WTB summon to Ratchet for 50s", "Anita-Lift". The dest is the driver's beaconed text.
-- nil if the driver is unknown.
function W.RequestWhisper(driverKey)
	local key = W.Key(driverKey)
	local d = W.drivers[driverKey] or (key and W.drivers[key])
	local r = W.ride
	if not d and r and key and r.driverKey == key then d = { name = r.driver, dest = r.dest, price = r.price } end
	if not d then return nil end
	return "WTB summon to " .. tostring(d.dest) .. " for " .. W.Money(d.price), W.MacroName(d.name)
end

-- The Request button's whole macro: "/w Anita-Lift WTB summon to Ratchet for 50s", or nil.
function W.RequestMacro(driverKey)
	local text, to = W.RequestWhisper(driverKey)
	if not (text and to) then return nil end
	return "/w " .. to .. " " .. text
end

-- The chat line the (optional) Cancel whisper sends and the name to whisper (with a
-- hyphen), for the current ride; nil without one.
function W.CancelWhisper()
	local r = W.ride
	if not r or not r.driver then return nil end
	return "Sorry, I have to cancel - thanks anyway", W.MacroName(r.driver)
end

-- The Cancel whisper's whole macro, or nil.
function W.CancelMacro()
	local text, to = W.CancelWhisper()
	if not (text and to) then return nil end
	return "/w " .. to .. " " .. text
end

local STAGE_STATE = { invited = "invited", summoning = "summoning", portal = "portal", arrived = "arrived", paid = "done", done = "done" }

local function rideFrom(key, id)
	local r = W.ride
	if r and id and r.id == id and r.driverKey == key and not ENDED[r.state] then return r end
	return nil
end

-- Arrival: at the dest (and paid, or free) -> arrived / done.
local function arrive(r)
	local moved = advance(r, "arrived")
	if (r.price or 0) <= 0 or r.paid then moved = advance(r, "done") or moved end
	return moved
end

-- Checks whether the rider stands at the ride's destination now.
function W.CheckArrival()
	local r = W.ride
	if not W.RideActive() then return end
	local rank = RANK[r.state] or 0
	if rank < RANK.ingroup or rank >= RANK.arrived then return end
	if not W.SamePlace((W.DestHere()), r.dest) then return end
	-- standing there all along is not arriving: only after accepting a summon, or if we
	-- came from elsewhere
	if not r.summonAccepted and W.SamePlace(r.from, r.dest) then return end
	arrive(r)
end

-- A: rideId, price, eta
local function heardAccept(addr, key, f)
	local id = rideId(f[1])
	if not id then return end
	local r = rideFrom(key, id)
	if not r then
		W.SendTo(addr, "C", id) -- not a ride we are waiting for: let the driver drop it
		return
	end
	local price = W.Int(f[2])
	if price then r.price = clamp(price, 0, MAX_PRICE) end
	r.eta = netInt(f[3], 0, 3600, 0)
	r.etaAt = now() + r.eta
	r.acceptedAt = r.acceptedAt or now()
	if not advance(r, "accepted") then fireRide(r) end
	if rideGroup(r) then advance(r, "ingroup") end
end

-- N: rideId, reason
local function heardDecline(key, f)
	local r = rideFrom(key, rideId(f[1]))
	if not r or (RANK[r.state] or 0) >= RANK.ingroup then return end
	local reason = f[2]
	if not (reason and REASONS[reason]) then reason = "busy" end
	finish(r, "declined", reason)
end

-- S: rideId, stage
local function heardStage(key, f)
	local r = rideFrom(key, rideId(f[1]))
	local stage = f[2] and (STAGE_ALIAS[f[2]] or f[2])
	if not r or not (stage and STAGES[stage]) then return end
	r.stage = stage
	if stage == "arrived" then
		if not arrive(r) then fireRide(r) end
		return
	end
	if not advance(r, STAGE_STATE[stage]) then fireRide(r) end
end

-- The ride's clock: resends R once, times out a state that has lasted too long, and notices
-- the group and arrival. Run every second (and by timers).
function W.CheckRide()
	local r = W.ride
	if not W.RideActive() then return end
	local t = now()
	if r.state == "requesting" and not r.resent and t - (r.at or t) >= RESEND_AFTER then
		r.resent = true
		W.SendTo(r.addr, "R", r.id, r.dest, r.price)
	end
	local limit = STATE_LIMIT[r.state]
	if limit and t - (r.changed or r.at or t) >= limit[1] - 0.01 then
		if limit[2] == "done" then
			advance(r, "done")
		else
			W.SendTo(r.addr, "C", r.id) -- the driver's card goes too
			finish(r, limit[2])
		end
		return
	end
	if (RANK[r.state] or 0) >= RANK.accepted and (RANK[r.state] or 0) < RANK.ingroup and rideGroup(r) then
		advance(r, "ingroup")
	end
	W.CheckArrival()
end

-- Invited: any invite while we wait for one (a teammate of the driver may send it).
W.On("PARTY_INVITE_REQUEST", function(inviter)
	local r = W.ride
	if not W.RideActive() or (RANK[r.state] or 0) >= RANK.invited then return end
	local key = W.Key(W.CleanName(inviter))
	if key ~= r.driverKey and (RANK[r.state] or 0) < RANK.accepted then return end
	r.inviter = key
	advance(r, "invited")
end)

W.On("GROUP_ROSTER_UPDATE", function()
	local r = W.ride
	if not W.RideActive() then return end
	local rank = RANK[r.state] or 0
	if rank >= RANK.accepted and rank < RANK.ingroup and rideGroup(r) then advance(r, "ingroup") end
end)

-- The summon is up: from any of the driver's Warlocks.
W.On("CONFIRM_SUMMON", function()
	local r = W.ride
	if not W.RideActive() or (RANK[r.state] or 0) < RANK.accepted then return end
	r.summonUp = true
	if not advance(r, "portal") then fireRide(r) end
end)

-- The summon ran out or was cancelled: back to waiting in the group.
W.On("CANCEL_SUMMON", function()
	local r = W.ride
	if not W.RideActive() or r.state ~= "portal" then return end
	r.summonUp = false
	r.state, r.changed = "ingroup", now()
	fireRide(r)
end)

W.On("ZONE_CHANGED_NEW_AREA", function() W.CheckArrival() end)
W.On("ZONE_CHANGED", function() W.CheckArrival() end)
W.On("ZONE_CHANGED_INDOORS", function() W.CheckArrival() end)

-- Paying: any trade (the cashier can be any of the driver's Warlocks) once in the group.
W.On("TRADE_SHOW", function()
	local r = W.ride
	if not W.RideActive() then return end
	local rank = RANK[r.state] or 0
	if rank < RANK.ingroup or rank >= RANK.paying then return end
	r.moneyBefore = money()
	if rank >= RANK.arrived then advance(r, "paying") end
end)

W.On("PLAYER_MONEY", function()
	local r = W.ride
	if not W.RideActive() or not r.moneyBefore then return end
	local m = money()
	if not m or (r.price or 0) <= 0 then return end
	local spent = r.moneyBefore - m
	if spent >= r.price * 0.9 then
		r.paid = spent
		r.moneyBefore = nil
		if (RANK[r.state] or 0) >= RANK.arrived then advance(r, "done") else fireRide(r) end
	end
end)

-- After a /reload: the ride saved in W.db.ride, if under way and under 10 min old.
local function restoreRide()
	local s = W.db and W.db.ride
	if type(s) ~= "table" then return end
	local age = clock() - (num(s.savedAt) or 0)
	local state = str(s.state)
	local keep = age >= 0 and age < RESTORE_MAX_AGE and state ~= nil
		and (RANK[state] ~= nil or (state == "done" and not s.rated))
		and rideId(s.id) and str(s.driverKey)
	if not keep then
		W.db.ride = nil
		return
	end
	local r = {}
	for _, k in ipairs(SAVED) do r[k] = s[k] end
	r.at, r.changed, r.resent = now(), now(), true
	r.addr = r.addr or r.driver
	W.ride = r
	fireRide(r)
end

---------------------------------------------------------------------------
-- Hearing messages
---------------------------------------------------------------------------

W.On("CHAT_MSG_ADDON", function(prefix, text, chan, sender)
	if str(prefix) ~= W.PREFIX then return end
	local addr = address(sender)
	local name = W.CleanName(addr)
	local key = W.Key(addr)
	if not (addr and name and key) or key == myKey() then return end -- our own echo
	local kind, proto, f = W.Decode(text)
	if not kind then return end
	chan = str(chan)
	if CHANNEL_KINDS[kind] then
		if chan ~= "CHANNEL" then return end
	elseif chan ~= "WHISPER" then
		return
	end
	W.net.heard = W.net.heard + 1
	if kind == "D" then
		heardBeacon(addr, name, key, f, proto)
	elseif kind == "X" then
		if W.drivers[key] then
			W.drivers[key] = nil
			W.Fire("DRIVERS")
		end
	elseif kind == "Q" then
		heardPing()
	elseif kind == "R" then
		heardRequest(addr, name, key, f)
	elseif kind == "C" then
		heardCancel(key, f)
	elseif kind == "T" then
		heardRating(addr, name, key, f)
	elseif kind == "A" then
		heardAccept(addr, key, f)
	elseif kind == "N" then
		heardDecline(key, f)
	elseif kind == "S" then
		heardStage(key, f)
	end
end)

W.On("CHAT_MSG_CHANNEL_NOTICE", function(_, _, _, chanString, _, _, _, _, chanBase)
	if isOurChannel(chanString) or isOurChannel(chanBase) then
		hideChannel()
		if W.loggedIn then W.CheckChannel(false) end
	end
end)

W.On("CHANNEL_UI_UPDATE", function()
	if W.loggedIn then W.CheckChannel(false) end
end)

---------------------------------------------------------------------------
-- Start-up and the clock
---------------------------------------------------------------------------

local ticks = 0
local function tick()
	ticks = ticks + 1
	W.Safe("beacon", tickBeacon)
	W.Safe("ride", W.CheckRide)
	W.Safe("requests", tickIncoming)
	if ticks % 5 == 0 then W.Safe("drivers", W.ExpireDrivers) end
end
W.NetTick = tick

W.OnLogin(function()
	local CI = C_ChatInfo
	if type(CI) == "table" and type(CI.RegisterAddonMessagePrefix) == "function" then
		pcall(CI.RegisterAddonMessagePrefix, W.PREFIX)
	end
	addFilters()
	W.Safe("restore ride", restoreRide)
	if W.OnNetwork() then
		W.CheckChannel(false) -- after a /reload: still in it, beacon at once
	else
		-- join once the game's own channels are in (so they keep /1 and /2), or after 10 s
		local waited, started = 0, false
		local ticker
		ticker = W.Every(1, function()
			if started then return end
			waited = waited + 1
			-- (6 s matches the timing proven in game; joining earlier can fail silently)
			if W.OnNetwork() or (hasChannels() and waited >= 6) or waited >= 10 then
				started = true
				if ticker and ticker.Cancel then pcall(ticker.Cancel, ticker) end
				W.CheckChannel(true)
			end
		end)
	end
	W.Every(10, function() W.CheckChannel(true) end) -- joins are still at most one per 10 s
	W.Every(1, tick)
end)

---------------------------------------------------------------------------
-- WuberAPI: for driver addons
---------------------------------------------------------------------------

-- Wraps fn so a call from another addon never raises an error (it returns nil instead).
local function guarded(where, fn)
	return function(...)
		local res = { pcall(fn, ...) }
		if not res[1] then
			W.Error("WuberAPI." .. where, res[2])
			return nil
		end
		return unpack(res, 2, table.maxn(res))
	end
end

WuberAPI = {}
W.API = WuberAPI

-- The API's version.
WuberAPI.version = 1

-- Sets the driver addon (nil removes it). provider = { name, beacon() -> beacon table with
-- named keys or nil, onRequest(ride), onCancel(rideId, buyer), onRating(rideId, buyer,
-- stars) }. ride = { id, buyer (the address to whisper/invite), name, buyerKey, dest,
-- price, at }. While set, Wuber's own driver mode stays off. Fires "PROVIDER".
-- Returns true, or false for something that is not a table.
WuberAPI.SetDriver = guarded("SetDriver", function(provider)
	if provider ~= nil and type(provider) ~= "table" then return false end
	W.provider = provider
	W.Fire("PROVIDER", provider)
	return true
end)

-- Accepts a ride: whispers A (price, eta) to the buyer. eta: seconds until the invite.
WuberAPI.Accept = guarded("Accept", function(id, buyer, eta, price)
	return W.AcceptRequest(id, eta, buyer, price)
end)

-- Declines a ride: whispers N to the buyer (reason busy, full, closed, blocked, price).
WuberAPI.Decline = guarded("Decline", function(id, buyer, reason)
	return W.DeclineRequest(id, reason, buyer)
end)

-- Tells the buyer how the ride is going (stage invited, summoning, portal, arrived, paid,
-- done; "waiting" is taken as portal).
WuberAPI.Status = guarded("Status", function(id, buyer, stage)
	return W.SendStage(id, stage, buyer)
end)

-- Sends a beacon now (after a change of price, place, state...); at most one per 5 s.
WuberAPI.Beacon = guarded("Beacon", function()
	return W.SendBeacon()
end)

-- A copy of the driver list, sorted by price then name.
WuberAPI.Drivers = guarded("Drivers", function()
	local out = {}
	for i, d in ipairs(W.DriversSorted()) do out[i] = copy(d) end
	return out
end)

-- Whether this client is in the network's channel.
WuberAPI.IsOnNetwork = guarded("IsOnNetwork", function()
	return W.OnNetwork()
end)
