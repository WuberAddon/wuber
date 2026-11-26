-- Module: Net.Flights
-- Purpose: Shared flight prices between Wuber users (W.FlyNet, F~ messages).
-- API: W.FlyNet, CX.flyCapable, CX.flyMaybe, W.AskFlight, CX.flyHeard,
--   NETK.{FLY_GAP,FLY_CAP,FLY_PEER_MAX,FLY_ENTRIES,FLY_BYTES,FLY_IN_CAP,FLY_WANTS}
-- Internals: (none)
-- Uses: Net.Base, Net.Community, Net.Transport, Net.Discovery
-- Later: (none)
-- Events: listens (none); fires FLIGHTS
-- Standalone: no
-- Test: tests/net/flights_test.lua
-- From: Net.lua 4226-4478 (Wuber 2.2.1)
--
---------------------------------------------------------------------------
-- Shared flight prices (2.2.1; the author: riders see real prices they never saw themselves)
---------------------------------------------------------------------------
-- Every Wuber user who opens a flight map adds its real prices (and Enhanced Flight Map's
-- measured times) to a pool that spreads peer to peer (Places.lua keeps and checks it).
-- F, whisper only, between 2.2.1+ clients (older ones drop the kind; proto stays 1):
--   F~1~<side>~<from>:<to>:<copper>:<age>:<secs>~...  up to 6 entries: store keys of two
--        towns, copper ("" when only a time is known), minutes since a player saw it,
--        measured seconds ("" when none)
--   F~1~<side>~?~<from>:<to>   a rider on Confirm asks the driver what that flight costs
-- Who gets one: after any Wuber whisper from a peer, or a D from a 2.2.1+ driver, the entries
-- that peer hasn't had from us (nor told us) this session, the asked ones first, then those
-- that end where the peer drives, then our own, newest first. At most one F a peer a minute,
-- 10 a peer a session, 4 a minute in all; the outbox's lowest priority, sent only with the
-- whole send allowance free (a ride message never waits for one). Heard: 3 Fs a peer a
-- minute at most, 8 entries each, each checked by W.FlightMerge (our side only).
local _, W = ...
local Mod = W.Module("Net.Flights", { "Net.Base", "Net.Community", "Net.Transport", "Net.Discovery" })
local BaseMod = W.Mod("Net.Base")
local CommunityMod = W.Mod("Net.Community")
local TransportMod = W.Mod("Net.Transport")
local DiscoveryMod = W.Mod("Net.Discovery")
local NETK, address, clock, myKey, now = BaseMod.NETK, BaseMod.address, BaseMod.clock, BaseMod.myKey, BaseMod.now
local CX = CommunityMod.CX
local enqueue = TransportMod.enqueue
local capLeft = DiscoveryMod.capLeft

do
NETK.FLY_GAP = 60
NETK.FLY_CAP = 4
NETK.FLY_PEER_MAX = 10
NETK.FLY_ENTRIES = 6
NETK.FLY_BYTES = 250
NETK.FLY_IN_CAP = 3
NETK.FLY_WANTS = 8
local fly = { sent = {}, lastTo = {}, count = {}, sentTo = {}, heardFrom = {}, wants = {}, capable = {}, inAt = {},
	asked = {}, retry = {}, checked = {}, queued = {}, out = 0, heard = 0 }
W.FlyNet = fly -- read by the tests

local function verNum(v)
	local a, b, c = tostring(v or ""):match("^(%d+)%.(%d+)%.?(%d*)")
	if not a then return 0 end
	return tonumber(a) * 10000 + tonumber(b) * 100 + (tonumber(c) or 0)
end
local FLY_VER = verNum("2.2.1")

-- Whether a peer speaks F: it sent us one, or beacons 2.2.1 or later.
local function capable(key)
	if fly.capable[key] then return true end
	local d = W.drivers[key] or W.hiddenDrivers[key]
	return d ~= nil and verNum(d.ver) >= FLY_VER
end
CX.flyCapable = capable

local function side()
	local s = W.Faction()
	if s == "H" or s == "A" then return s end
	return nil
end

local function sig(c, t) return tostring(c or "") .. "/" .. tostring(t or "") end

-- The entries for an F to `key`, ranked, fitting one message; and their texts.
local function pick(key)
	local list = W.FlightShareList()
	if #list == 0 then return nil end
	local sentTo, heard, wants = fly.sentTo[key] or {}, fly.heardFrom[key] or {}, fly.wants[key] or {}
	local wantFrom = {}
	for pk in pairs(wants) do
		local a = pk:match("^([^|]+)|")
		if a then wantFrom[a] = true end
	end
	local d = W.drivers[key]
	local dp = d and W.ExactPlace(d.dest or "")
	local dest = dp and W.NormPlace(dp.name) or nil
	local cand = {}
	for _, e in ipairs(list) do
		local sg = sig(e.c, e.t)
		if sentTo[e.k] ~= sg and heard[e.k] ~= sg then
			local rank = 3
			if wants[e.from .. "|" .. e.to] then
				rank = 0
			elseif (dest and e.to == dest) or wantFrom[e.from] then
				rank = 1
			elseif e.own then
				rank = 2
			end
			cand[#cand + 1] = { e = e, sig = sg, rank = rank }
		end
	end
	if #cand == 0 then return nil end
	table.sort(cand, function(a, b)
		if a.rank ~= b.rank then return a.rank < b.rank end
		if a.e.at ~= b.e.at then return a.e.at > b.e.at end
		return a.e.k < b.e.k
	end)
	local t0, out, texts = clock(), {}, {}
	local size = #("F~" .. W.PROTO .. "~H")
	for _, x in ipairs(cand) do
		if #out >= NETK.FLY_ENTRIES then break end
		local e = x.e
		local age = math.max(0, math.floor((t0 - e.at) / 60))
		local text = e.from .. ":" .. e.to .. ":" .. (e.c and string.format("%d", e.c) or "") .. ":"
			.. string.format("%d", age) .. ":" .. (e.t and string.format("%d", e.t) or "")
		if size + 1 + #text <= NETK.FLY_BYTES then
			size = size + 1 + #text
			out[#out + 1] = x
			texts[#texts + 1] = text
		end
	end
	if #out == 0 then return nil end
	return out, texts
end

-- The limits count what went out (the outbox may hold an F a while): per peer the last one
-- sent and any still waiting; in all, those sent in the last minute plus those waiting.
local function waiting(key, t)
	local q = fly.queued[key]
	return q ~= nil and t - q < 2 * NETK.FLY_GAP
end

local function roomLeft(t)
	local n = 0
	for _, q in pairs(fly.queued) do
		if t - q < 2 * NETK.FLY_GAP then n = n + 1 end
	end
	return capLeft(fly.sent, t, NETK.FLY_CAP) - n
end

-- Queues one F to a peer; the limits count it once it goes.
local function flySend(addr, key, text)
	local went = false
	local ok = enqueue("WHISPER", addr, "F", text, nil, function()
		local t1 = now()
		went = true
		fly.queued[key] = nil
		fly.lastTo[key] = t1
		fly.sent[#fly.sent + 1] = t1
		fly.out = fly.out + 1
	end)
	if not ok then return false end
	if not went then fly.queued[key] = now() end
	fly.count[key] = (fly.count[key] or 0) + 1
	return true
end

-- One F to a peer, if the limits allow and there is something they haven't had from us.
-- Returns true when one was queued.
function CX.flyMaybe(addr, key)
	if W.net.cantSend or not W.db or not addr or not key or key == myKey() or not capable(key) then return false end
	local s = side()
	if not s then return false end
	local t = now()
	local last = fly.lastTo[key]
	if waiting(key, t) or (last and t - last < NETK.FLY_GAP) then
		-- asked meanwhile: once the minute is up
		if fly.wants[key] and not fly.retry[key] then
			fly.retry[key] = true
			W.After(math.max(1, NETK.FLY_GAP - (t - (last or t)) + 0.5), function()
				fly.retry[key] = nil
				W.Safe("flight share", CX.flyMaybe, addr, key)
			end)
		end
		return false
	end
	if (fly.count[key] or 0) >= NETK.FLY_PEER_MAX then return false end
	-- nothing new since we last looked for this peer: no work
	local ver = W.FLY and W.FLY.ver or 0
	local ck = fly.checked[key]
	if ck and ck.ver == ver and ck.side == s and not fly.wants[key] then return false end
	if roomLeft(t) <= 0 then return false end
	local picked, texts = pick(key)
	fly.wants[key] = nil
	if not picked then
		fly.checked[key] = { ver = ver, side = s }
		return false
	end
	fly.checked[key] = nil
	local sentTo = fly.sentTo[key] or {}
	fly.sentTo[key] = sentTo
	local before = {}
	for i, x in ipairs(picked) do
		before[i] = sentTo[x.e.k]
		sentTo[x.e.k] = x.sig
	end
	local text = "F~" .. W.PROTO .. "~" .. s .. "~" .. table.concat(texts, "~")
	if not flySend(addr, key, text) then
		for i, x in ipairs(picked) do sentTo[x.e.k] = before[i] end
		return false
	end
	return true
end

-- A rider on Confirm asks the driver what flying there from here costs, when we have no price
-- at all (the game's table can't route it and no flight master showed us):
-- once per driver and flight a minute, within the same limits as any F. true when asked.
function W.AskFlight(driverKey)
	local d = driverKey and W.drivers[driverKey]
	if not d or W.net.cantSend or not W.db or not capable(d.key) then return false end
	local s = side()
	if not s then return false end
	-- (only for a trip the game's own table can't price, and no flight master showed us)
	if W.FlightCost(nil, d.dest) then return false end
	local _, here = W.DestHere()
	local a, b = W.FLY.places(s, here and here.name, d.dest)
	if not a then return false end
	local t = now()
	local ak = d.key .. "|" .. a .. "|" .. b
	local last, lt = fly.asked[ak], fly.lastTo[d.key]
	if (last and t - last < NETK.FLY_GAP) or (lt and t - lt < NETK.FLY_GAP) or waiting(d.key, t) then return false end
	if roomLeft(t) <= 0 then return false end
	local addr = address(d.addr or d.name)
	if not addr or not flySend(addr, d.key, "F~" .. W.PROTO .. "~" .. s .. "~?~" .. a .. ":" .. b) then return false end
	fly.asked[ak] = t
	return true
end

-- F heard (by whisper): an ask, or entries for the pool.
function CX.flyHeard(addr, key, f)
	local t = now()
	local inList = fly.inAt[key] or {}
	fly.inAt[key] = inList
	if capLeft(inList, t, NETK.FLY_IN_CAP) <= 0 then return end
	inList[#inList + 1] = t
	fly.capable[key] = true
	local s = side()
	local d = W.drivers[key]
	if not s or f[1] ~= s or (d and d.faction and d.faction ~= s) then return end -- the other side's
	if f[2] == "?" then
		local wants = fly.wants[key] or {}
		local n = 0
		for _ in pairs(wants) do n = n + 1 end
		for i = 3, math.min(#f, 5) do
			local a, b = W.FLY.places(s, tostring(f[i]):match("^([^:]+):([^:]+)$"))
			if a and n < NETK.FLY_WANTS then
				wants[a .. "|" .. b] = true
				n = n + 1
			end
		end
		if n > 0 then fly.wants[key] = wants end
		return
	end
	local heard = fly.heardFrom[key] or {}
	fly.heardFrom[key] = heard
	local t0, changed = clock(), false
	for i = 2, math.min(#f, 9) do
		local a, b, c, age, secs = tostring(f[i]):match("^([^:]+):([^:]+):(%d*):(%d+):(%d*)$")
		local fa, fb0 = W.FLY.places(s, a, b)
		local mins = fa and W.Int(age)
		if mins then
			local cn, sn = W.Int(c), W.Int(secs)
			if cn and (cn <= 0 or cn > W.FLY.MAX_COPPER) then cn = nil end
			if sn and (sn < W.FLY.MIN_SECS or sn > W.FLY.MAX_SECS) then sn = nil end
			if cn or sn then
				heard[s .. "|" .. fa .. "|" .. fb0] = sig(cn, sn)
				if W.FlightMerge(s, fa, fb0, cn, sn, t0 - mins * 60, key) then changed = true end
				fly.heard = fly.heard + 1
			end
		end
	end
	if changed then W.Fire("FLIGHTS") end
end
end -- shared flight prices
