-- Module: Net.Bounty
-- Purpose: want-to-go bounties: the rider's pinned bounty (kind W on the channel, community copy
--   and whisper copies) and the driver side's demand per place.
-- API: W.Bounty, W.Bounty.Pin, W.Bounty.Cancel, W.Bounty.Mine, W.Bounty.Demand, W.Bounty.Place,
--   W.bounties
-- Internals: BK, last, bySender, senders, cancelPending, lastSendAt, knownPlace, mine, served,
--   minutesLeft, sendNow, trySend, finish, forget, pruneDemand, ignored; hook slots heard (kind W,
--   called by Net.Base's W.NetKind handler), tick (Net.Inbox's 1 s clock)
-- Uses: Net.Base, Net.Community, Net.Transport
-- Later: (none)
-- Events: listens (none); fires BOUNTY
-- Standalone: no
-- Test: tests/net/bounty_test.lua
-- From: new in Wuber 2.3.0
--
-- A bounty is a wish, not a payment: a rider who wants a place no open driver serves pins one
-- ("Gadgetzan, 60s") so drivers see the demand. Pledges never move gold; the rider still pays
-- the driver's fare.
--
-- Kind W (channel kind, also as a community copy and by whisper from the rider itself):
--   W~1~<place <=32>~<copper>~<faction H|A>~<minutes left 1-30>   (<= 50 bytes; cancel: copper 0)
-- Rider: W.db.bounty = { place, copper, at = time(), sends, lastAt } (one at a time; survives a
-- /reload, ends by time). Sent on pin, then every 5 min while active (at most 6 sends), never
-- more than one a minute, counted on GetTime with a second to spare (a newer state waits and
-- replaces a queued one); a send counts only when a copy was queued (off the network it stays due); whisper copies only to
-- drivers already in this rider's whisper round (asked by Q in the last 5.5 min). It ends when
-- the rider books any ride (Net.Rides), an open driver serves that place, Cancel, or 30 min.
-- Driver: W.bounties[place][senderKey] = { copper, at, untilAt, name } (session; <= 200
-- senders): counted per sender (the event's sender, never a payload name), a newer one replaces
-- the older, at most one counted per sender a minute (a cancel always counts), a known non-zone
-- place only, copper clamped, other faction / hidden / blocked senders and the driver's own crew
-- ignored, nothing while Settings > Driving "Show what riders want" is off.
-- Events: BOUNTY("mine", bounty or nil, why) on the rider's side (why on an end: "cancel",
-- "booked", "served", "expired"; "served" also gives the driver's name as a 4th value),
-- BOUNTY("demand") on the driver's side.

local _, W = ...
local Mod = W.Module("Net.Bounty", { "Net.Base", "Net.Community", "Net.Transport" })
local BaseMod = W.Mod("Net.Base")
local CommunityMod = W.Mod("Net.Community")
local NETK, clamp, clock, fb, localInt, myKey = BaseMod.NETK, BaseMod.clamp, BaseMod.clock, BaseMod.fb, BaseMod.localInt, BaseMod.myKey
local netInt, now = BaseMod.netInt, BaseMod.now
local CX = CommunityMod.CX
local str = W.Str

local BK = {
	LIFE = 1800,       -- a bounty lasts 30 minutes
	EVERY = 300,       -- re-sent every 5 minutes
	SENDS = 6,         -- at most this many sends
	GAP = 60,          -- never more than one send a minute
	SENDER_GAP = 60,   -- driver: one counted update per sender a minute
	CHANGE_GAP = 30,   -- driver: a CHANGED wish (other place or price) from the same sender counts after this many seconds
	                   -- (the rider sends at most one a minute, but its queue can bring two arrivals closer: HUNT-128)
	MAX_SENDERS = 200, -- driver: senders kept
	WHISPERS = 6,      -- whisper copies per send
	OUTLIER = 3,       -- driver: pledges over 3 x the median are left out of the range
}

local Bounty = {}
W.Bounty = Bounty
W.bounties = W.bounties or {}

local last = {}       -- driver: senderKey -> GetTime() of their last counted bounty
local bySender = {}   -- driver: senderKey -> the place their bounty is for
local senders = 0     -- driver: senders in W.bounties
local cancelPending   -- rider: { place } of a cancel still to send
local lastSendAt      -- rider: GetTime() of our last W that went out (the driver's gap is on GetTime too)

-- The cancel still to send, kept in the saved data too (a /reload must not lose it: drivers keep the demand up to 30 minutes).
local function setCancel(c)
	cancelPending = c
	if W.db then
		if c then W.db.bountyCancel = { place = c.place, replaced = c.replaced, at = clock() } else W.db.bountyCancel = nil end
	end
end

-- A known place that is not a whole zone (W.PLACES, any of its names): its name, else nil.
local function knownPlace(text)
	local d = W.CleanDest(text)
	if d == "" then return nil end
	local name, ok = W.ValidDest(d)
	if not ok then return nil end
	for _, p in ipairs(W.PLACES) do
		if p.name == name then return p.kind ~= "zone" and p.name or nil end
	end
	return nil
end
Bounty.Place = knownPlace -- (for the UI: whether a search names a place a bounty can be for)

-- The rider's bounty while it lasts, else nil (read only).
local function mine()
	local b = W.db and W.db.bounty
	if type(b) ~= "table" or type(b.place) ~= "string" then return nil end
	local at = tonumber(b.at)
	if not at or clock() - at >= BK.LIFE or at > clock() + 60 then return nil end
	return b
end

-- An open driver who serves this place now (W.drivers: same faction, not hidden), or nil.
local function served(place)
	for _, d in pairs(W.drivers) do
		if d.state == "open" and d.dest and W.SamePlace(d.dest, place) then return d end
	end
	return nil
end

local function minutesLeft(b)
	return clamp(math.ceil((tonumber(b.at) + BK.LIFE - clock()) / 60), 1, 30)
end

-- One W out: over the channel, the community copy and the whisper round. Returns whether any
-- copy was queued (false off the network, or with no faction: nothing was told, nothing counts).
local function sendNow(place, copper, minutes)
	local fac = W.Faction()
	if fac ~= "H" and fac ~= "A" then return false end
	local sent = W.SendChannel("W", place, copper, fac, minutes) == true
	if CX.send and CX.send("W", place, copper, fac, minutes) == true then sent = true end
	local t, n = now(), 0
	for k, addr in pairs(fb.qAddr) do
		local at = fb.qAt[k]
		if n < BK.WHISPERS and at and t - at <= (NETK.RIDER_KEEP or 330) then
			n = n + 1
			if W.SendTo(addr, "W", place, copper, fac, minutes) == true then sent = true end
		end
	end
	if sent then lastSendAt = now() end
	return sent
end

-- (after a /reload: the saved cancel is picked up again while it is younger than a bounty's life)
local function restoreCancel()
	local c = W.db and W.db.bountyCancel
	if cancelPending or c == nil then return end
	local at = tonumber(type(c) == "table" and c.at)
	if at and type(c.place) == "string" and clock() - at < BK.LIFE and at <= clock() + 60 then
		cancelPending = { place = c.place, replaced = c.replaced }
	else
		W.db.bountyCancel = nil
	end
end

-- Sends what is due when the minute allows: a pending cancel, else the bounty's next send.
local function trySend()
	local t = clock()
	-- (a margin of a second: the driver counts one a minute on GetTime, this clock is whole seconds)
	if lastSendAt and now() - lastSendAt < BK.GAP + 1 then return false end
	local b = mine()
	-- (an older pledge that a newer bounty replaces waits: the newer one's first send replaces it on
	-- the drivers; only if that never goes out does the cancel)
	if cancelPending and cancelPending.replaced and b and (tonumber(b.sends) or 0) == 0 then
		if not sendNow(b.place, b.copper, minutesLeft(b)) then return false end
		setCancel(nil)
		b.sends, b.lastAt = 1, t
		return true
	end
	if cancelPending and not (b and b.place == cancelPending.place) then
		local place = cancelPending.place
		if not sendNow(place, 0, 1) then return false end -- (still pending: the next tick tries again)
		setCancel(nil)
		return true
	end
	setCancel(nil)
	if not b then return false end
	local sends = tonumber(b.sends) or 0
	if sends >= BK.SENDS or (sends > 0 and t - (tonumber(b.lastAt) or 0) < BK.EVERY) then return false end
	if not sendNow(b.place, b.copper, minutesLeft(b)) then return false end -- (left due for the next tick)
	b.sends, b.lastAt = sends + 1, t
	return true
end

-- The rider's bounty ends: drivers hear copper 0 if it was ever sent.
local function finish(why, extra)
	local b = W.db and W.db.bounty
	if type(b) ~= "table" then return false end
	W.db.bounty = nil
	if (tonumber(b.sends) or 0) > 0 and type(b.place) == "string" then
		setCancel({ place = b.place })
		trySend()
	end
	W.Fire("BOUNTY", "mine", nil, why, extra)
	return true
end

---------------------------------------------------------------------------
-- Rider side
---------------------------------------------------------------------------

-- The rider pins a bounty for a place no open driver serves. copper is clamped to the
-- network's fares. A newer one replaces the rider's older one. The place is also watched
-- (the "now summons to" toast). Returns true, or false and why: "place" (not a known town,
-- city or dungeon), "served" (an open driver serves it), "ride" (a ride is under way).
function Bounty.Pin(place, copper)
	place = knownPlace(place)
	if not place then return false, "place" end
	if served(place) then return false, "served" end
	if W.RideActive and W.RideActive() then return false, "ride" end
	copper = clamp(localInt(copper) or W.MIN_PRICE, W.MIN_PRICE, NETK.MAX_PRICE)
	if not W.db then return false, "place" end
	-- (a newer bounty replaces the older on a driver that heard it, but one not sent yet would
	-- leave the older pledge up: so an older sent one for another place is cancelled first)
	local old = W.db.bounty
	setCancel(nil)
	if type(old) == "table" and (tonumber(old.sends) or 0) > 0 and type(old.place) == "string" and old.place ~= place then
		setCancel({ place = old.place, replaced = true })
	end
	W.db.bounty = { place = place, copper = copper, at = clock(), sends = 0, lastAt = 0 }
	if W.IsWatched and not W.IsWatched(place) then W.ToggleWatch(place) end
	trySend()
	W.Fire("BOUNTY", "mine", Bounty.Mine())
	return true
end

-- The rider's bounty ends (why: "cancel" by default; Net.Rides says "booked"). Sends copper
-- 0 when drivers heard it. Returns whether there was one.
function Bounty.Cancel(why)
	if not mine() then
		if W.db and W.db.bounty ~= nil then W.db.bounty = nil end
		return false
	end
	return finish(str(why) or "cancel")
end

-- The rider's active bounty: a copy { place, copper, at, sends, left (seconds) }, or nil.
function Bounty.Mine()
	local b = mine()
	if not b then return nil end
	return { place = b.place, copper = tonumber(b.copper) or W.MIN_PRICE, at = tonumber(b.at),
		sends = tonumber(b.sends) or 0, left = math.max(0, tonumber(b.at) + BK.LIFE - clock()) }
end

---------------------------------------------------------------------------
-- Driver side
---------------------------------------------------------------------------

local function forget(key)
	local place = bySender[key]
	if not place then return false end
	local t = W.bounties[place]
	if t and t[key] then
		t[key] = nil
		senders = senders - 1
		if next(t) == nil then W.bounties[place] = nil end
	end
	bySender[key] = nil
	return true
end

-- Expired pledges go. Returns whether any went.
local function pruneDemand()
	local t, gone = now(), false
	for place, list in pairs(W.bounties) do
		for key, e in pairs(list) do
			if type(e) ~= "table" or (e.untilAt or 0) <= t then
				bySender[key] = nil
				list[key] = nil
				senders = senders - 1
				gone = true
			end
		end
		if next(list) == nil then W.bounties[place] = nil end
	end
	return gone
end

-- Whether this sender's bounty is not for us: hidden, blocked, or one of our own crew.
local function ignored(key)
	if W.IsHidden and W.IsHidden(key) then return true end
	local d = W.db and W.db.drive
	if type(d) ~= "table" then return false end
	if type(d.blocklist) == "table" and d.blocklist[key] ~= nil then return true end
	local DR = W.Drive
	if type(DR) == "table" and type(DR.IsCrewKey) == "function" then
		local ok, crew = pcall(DR.IsCrewKey, key)
		if ok and crew then return true end
	end
	return false
end

-- W: place, copper, faction, minutes (Net.Inbox: over the channel, or by whisper from the
-- rider itself)
function Mod.heard(addr, name, key, f)
	if key == myKey() then return end
	local d = W.db and W.db.drive
	if type(d) == "table" and type(d.opts) == "table" and d.opts.watchBounty == false then return end
	local place = knownPlace(f[1])
	local copper = netInt(f[2], 0, NETK.MAX_PRICE, nil)
	local fac, mineFac = f[3], W.Faction()
	if not (place and copper) or not (fac == "H" or fac == "A") or (mineFac ~= "" and fac ~= mineFac) then return end
	if ignored(key) then return end
	local t = now()
	if copper == 0 then
		if forget(key) then W.Fire("BOUNTY", "demand") end
		return
	end
	-- (one counted update per sender a minute; a newer bounty for another place or price replaces the older one
	-- after CHANGE_GAP, so a delay in the rider's queue between the two sends cannot keep the old one up)
	local was = bySender[key] and W.bounties[bySender[key]] and W.bounties[bySender[key]][key]
	local changed = not (was and bySender[key] == place and was.copper == clamp(copper, W.MIN_PRICE, NETK.MAX_PRICE))
	if last[key] and t - last[key] < (changed and BK.CHANGE_GAP or BK.SENDER_GAP) then return end
	last[key] = t
	forget(key)
	if senders >= BK.MAX_SENDERS then
		local oldKey, oldAt, oldPlace
		for p, list in pairs(W.bounties) do
			for k, e in pairs(list) do
				if not oldAt or e.at < oldAt then oldKey, oldAt, oldPlace = k, e.at, p end
			end
		end
		if oldKey then forget(oldKey) end
		if oldPlace and W.bounties[oldPlace] and next(W.bounties[oldPlace]) == nil then W.bounties[oldPlace] = nil end
	end
	local list = W.bounties[place] or {}
	W.bounties[place] = list
	list[key] = { copper = clamp(copper, W.MIN_PRICE, NETK.MAX_PRICE), at = t,
		untilAt = t + netInt(f[4], 1, 30, 30) * 60, name = name }
	bySender[key] = place
	senders = senders + 1
	W.Fire("BOUNTY", "demand")
end

-- What riders want, per place, most wanted first: { { place, riders, low, high, newest }, ... }
-- low..high: the median pledge to the highest (pledges over 3 x the median left out), copper;
-- newest: seconds since the latest.
function Bounty.Demand()
	pruneDemand()
	local out, t = {}, now()
	for place, list in pairs(W.bounties) do
		local vals, newest = {}, nil
		for _, e in pairs(list) do
			vals[#vals + 1] = e.copper
			if not newest or e.at > newest then newest = e.at end
		end
		if #vals > 0 then
			table.sort(vals)
			local median = vals[math.floor((#vals + 1) / 2)]
			local high = median
			for _, v in ipairs(vals) do
				if v <= median * BK.OUTLIER and v > high then high = v end
			end
			out[#out + 1] = { place = place, riders = #vals, low = median, high = high, newest = math.max(0, t - newest) }
		end
	end
	table.sort(out, function(a, b)
		if a.riders ~= b.riders then return a.riders > b.riders end
		if a.newest ~= b.newest then return a.newest < b.newest end
		return a.place < b.place
	end)
	return out
end

---------------------------------------------------------------------------
-- The clock (Net.Inbox, every second)
---------------------------------------------------------------------------

function Mod.tick()
	if next(W.bounties) ~= nil and pruneDemand() then W.Fire("BOUNTY", "demand") end
	restoreCancel()
	local raw = W.db and W.db.bounty
	if raw == nil and not cancelPending then return end
	local b = mine()
	if raw ~= nil and not b then
		finish("expired")
		return
	end
	if b then
		local d = served(b.place)
		if d then
			finish("served", d.name)
			return
		end
	end
	trySend()
end
