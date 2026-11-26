-- Module: Net.Requests
-- Purpose: Driver side of a ride: incoming R, accept/decline, stages, queue places, cancels and
--   ratings (W.AcceptRequest, W.SendStage, W.SendQueue...).
-- API: W.RestoreFinished, W.RestoreIncoming, W.AcceptRequest, W.DeclineRequest, W.SendStage,
--   W.SendQueue
-- Internals: heardCancel, heardRating, heardRequest, tickIncoming, lastR, verByRide (2.3.0:
--   rideId -> { key, ver } from R field 6, or W.RestoreIncoming's ver after a /reload), acceptArgs,
--   noteVersion, cleanVer
-- Uses: Net.Base, Net.Beacons
-- Later: (none)
-- Events: listens (none); fires RATING, REQUESTS
-- Standalone: no
-- Test: tests/net/requests_test.lua
-- From: Net.lua 1830-2131 (Wuber 2.2.1)
--
---------------------------------------------------------------------------
-- Being a driver: requests coming in
---------------------------------------------------------------------------

local _, W = ...
local Mod = W.Module("Net.Requests", { "Net.Base", "Net.Beacons" })
local BaseMod = W.Mod("Net.Base")
local BeaconsMod = W.Mod("Net.Beacons")
local NETK, REASONS, STAGES, STAGE_ALIAS, address = BaseMod.NETK, BaseMod.REASONS, BaseMod.STAGES, BaseMod.STAGE_ALIAS, BaseMod.address
local clamp, clock, copy, fb, localInt = BaseMod.clamp, BaseMod.clock, BaseMod.copy, BaseMod.fb, BaseMod.localInt
local netInt, now, rideId = BaseMod.netInt, BaseMod.now, BaseMod.rideId
local beaconFor, impl = BeaconsMod.beaconFor, BeaconsMod.impl
local str = W.Str

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

-- A ride that ended paid or done (never a declined, cancelled
-- or timed-out one): its rating may come later, also after a /reload (W.db.netFinished
-- keeps the last 40 for 30 min).
local function remember(id, key)
	if not id or finished[id] then return end
	finished[id] = key or true
	if type(key) == "string" then fb.booked[key] = now() end
	finishedOrder[#finishedOrder + 1] = id
	if #finishedOrder > 40 then finished[table.remove(finishedOrder, 1)] = nil end
	if W.db then
		local list, at = {}, clock()
		for _, fid in ipairs(finishedOrder) do
			local k = finished[fid]
			list[#list + 1] = { id = fid, key = type(k) == "string" and k or nil, at = at }
		end
		W.db.netFinished = list
	end
end

function W.RestoreFinished()
	local list = W.db and W.db.netFinished
	if type(list) ~= "table" then return end
	local t = clock()
	for _, e in ipairs(list) do
		if type(e) == "table" and rideId(e.id) and tonumber(e.at) and t - e.at < 1800 and not finished[e.id] then
			finished[e.id] = str(e.key) or true
			finishedOrder[#finishedOrder + 1] = e.id
		end
	end
end

local function removeIncoming(r, done)
	for i, other in ipairs(W.incoming) do
		if other == r then
			table.remove(W.incoming, i)
			if done then remember(r.id, r.buyerKey) end
			return true
		end
	end
	return false
end

-- 2.3.0: the rider's version from R field 6, per ride id (kept after the request is gone, for
-- Net.Portal's G: only riders on 2.3.0 or later get it). At most 40 rides.
local verByRide, verOrder = {}, {}
local function noteVersion(id, key, ver)
	if not verByRide[id] then
		verOrder[#verOrder + 1] = id
		if #verOrder > 40 then verByRide[table.remove(verOrder, 1)] = nil end
	end
	verByRide[id] = { key = key, ver = ver }
end

-- A rider's version as R field 6 carries it ("2.3.3-rc1": 2.3.3), or "".
local function cleanVer(v)
	return (str(v) or ""):gsub("%-.*$", ""):gsub("[^%d%.]", ""):sub(1, 12)
end

-- A Wuber ride the driver's engine still has after a /reload:
-- back in W.incoming as accepted, so the rider's cancel and rating still count. ver (2.3.2,
-- optional): the rider's version the engine kept (c.wuberVer), so Net.Portal's G still goes.
function W.RestoreIncoming(id, buyer, dest, price, stage, ver)
	id = rideId(id)
	local addr = address(buyer)
	local key = addr and W.Key(addr)
	if not id or not key or findIncoming(id, key) then return false end
	ver = cleanVer(ver)
	if ver ~= "" then noteVersion(id, key, ver) end
	if stage == "paid" or stage == "done" then
		remember(id, key)
		return false
	end
	W.incoming[#W.incoming + 1] = {
		id = id, buyer = addr, name = W.CleanName(addr) or addr, buyerKey = key,
		dest = W.CleanDest(dest or ""), price = localInt(price) or 0, at = now(), acceptedAt = now(),
		state = "accepted", stage = str(stage), eta = 5, restored = true, riderVer = ver ~= "" and ver or nil,
	}
	W.Fire("REQUESTS", W.incoming)
	return true
end

local function providerCall(name, ...)
	local p = impl()
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

-- A's fields: rideId, price, eta, and (2.3.0) "1" / "0" when the R named a raincheck: taken
-- or not (old riders ignore it; a ride without one sends A as before).
local function acceptArgs(id, price, eta, r)
	if r and r.voucher then return id, price, eta, r.voucherTaken and "1" or "0" end
	return id, price, eta
end

-- R: rideId, dest, price, tier, rides (the last two self-reported, clamped: 0..3, 0..9999;
-- missing from round-one riders: tier 0, rides nil), (2.3.0) rider version, raincheck id
-- (8 letters or digits; the driver's book decides whether it counts, never this message)
local lastR = {} -- buyer key -> when their last R came
local lastN = {} -- id, reason: the last N this window sent (W.DeclineRequest)

-- Takes every request from this buyer key off W.incoming (but keep, if given); returns whether
-- any went.
local function dropOlder(key, keep)
	local gone = false
	for i = #W.incoming, 1, -1 do
		local r = W.incoming[i]
		if r.buyerKey == key and r ~= keep then table.remove(W.incoming, i) gone = true end
	end
	return gone
end

local function heardRequest(addr, name, key, f, byChat)
	local id = rideId(f[1])
	if not id then return end
	if not byChat and lastR then lastR[key] = now() end
	if not byChat and W.HeardVersion then W.Safe("version", W.HeardVersion, key, f[6]) end -- round 11 (Net.Update)
	-- the same request again (the rider resends after 8 s): answer A again if accepted
	for _, r in ipairs(W.incoming) do
		if r.buyerKey == key and r.id == id then
			if r.state == "accepted" then W.SendTo(r.buyer, "A", acceptArgs(r.id, r.price, r.eta or 5, r)) end
			return
		end
	end
	local b = beaconFor(key)
	if not b or (not impl() and b.state == "paused") then
		sayClosed(addr, key, id)
		return
	end
	local price = netInt(f[3], 0, NETK.MAX_PRICE, 0)
	if price < W.MIN_PRICE or (not impl() and not W.PriceOk(price, b.price)) then
		W.SendTo(addr, "N", id, "price")
		return
	end
	-- one request per rider: a new one replaces the old. With a driver engine (impl) the old one
	-- goes only once the engine has not declined the new one: a ride it holds (a raincheck, a
	-- summon under way) answers the new id N busy and keeps the old ride, so its cancel, paid/done
	-- and rating still count (AUD-30)
	local others = 0
	for _, r in ipairs(W.incoming) do
		if r.buyerKey ~= key then others = others + 1 end
	end
	if not impl() or others >= NETK.MAX_INCOMING then dropOlder(key) end
	if others >= NETK.MAX_INCOMING then
		W.SendTo(addr, "N", id, "full")
		W.Fire("REQUESTS", W.incoming)
		return
	end
	local dest = W.CleanDest(f[2])
	local tier = netInt(f[4], 0, 3, 0)
	local rides = netInt(f[5], 0, 9999, nil)
	local ver = cleanVer(f[6]) -- "2.3.3-rc1": 2.3.3
	local voucher = (f[7] or ""):match("^%w%w%w%w%w%w%w%w$")
	if ver ~= "" then noteVersion(id, key, ver) end
	local ride = {
		id = id, buyer = addr, name = name, buyerKey = key,
		dest = dest ~= "" and dest or b.dest,
		price = price, at = now(), state = "new",
		tier = tier, rides = rides, label = W.RiderLabel(tier, rides),
		chat = byChat or nil, -- asked by chat only (the rider can't send addon messages)
		riderVer = ver ~= "" and ver or nil, voucher = voucher, -- (2.3.0)
	}
	W.incoming[#W.incoming + 1] = ride
	W.Fire("REQUESTS", W.incoming)
	if impl() then
		providerCall("onRequest", copy(ride))
		local stays = false
		for _, r in ipairs(W.incoming) do
			if r == ride then stays = true end
		end
		-- not declined: the new request replaces the old. Declined for another reason than a ride the
		-- engine holds ("busy"): the old one goes too, as it always did (a blocked rider, a closed driver)
		local gone = false
		if stays then
			gone = dropOlder(key, ride)
		elseif lastN.id == id and lastN.reason ~= "busy" then
			gone = dropOlder(key)
		end
		if gone then W.Fire("REQUESTS", W.incoming) end
	end
end

local function target(r, buyer)
	return (r and r.buyer) or address(buyer)
end

-- Accepts a request: whispers A (price, eta = seconds until the invite) to the rider.
-- buyer (optional) picks the rider when ids could clash, and is the address used for a ride
-- this client no longer lists. price (optional, copper): the fare the driver will really
-- charge, when it differs from the request's (e.g. after a price change); it replaces the
-- ride's price. The invite is up to the caller (W.Invite). Returns whether A was sent.
-- taken (2.3.0, optional): the driver's raincheck book took the raincheck the R named (A's
-- last field "1"; the price is then the fare it covers part of, as locked).
function W.AcceptRequest(id, eta, buyer, price, taken)
	id = rideId(id)
	if not id then return false end
	local r = findIncoming(id, W.Key(buyer))
	local to = target(r, buyer)
	if not to then return false end
	eta = clamp(localInt(eta) or 5, 0, 3600)
	local charged = localInt(price)
	if charged then
		charged = clamp(charged, W.MIN_PRICE, NETK.MAX_PRICE)
		if r then r.price = charged end
	end
	price = charged or (r and r.price)
	if not price then
		local b = W.DriverBeacon()
		price = b and b.price or 0
	end
	if r and r.voucher then r.voucherTaken = taken and true or nil end
	if not W.SendTo(to, "A", acceptArgs(id, price, eta, r)) then return false end
	local bk = (r and r.buyerKey) or W.Key(to)
	if bk then fb.booked[bk] = now() end -- (no more D answers or pushes to them)
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
	lastN.id, lastN.reason = id, reason
	local sent = W.SendTo(to, "N", id, reason)
	if r and removeIncoming(r) then W.Fire("REQUESTS", W.incoming) end
	return sent
end

-- Tells the rider how the ride is going: stage invited, summoning (ritual being cast),
-- portal (the summon is up; "waiting" is taken as portal), arrived, paid or done. After
-- paid or done the ride leaves W.incoming. Returns whether S was sent.
-- payee (2.1, optional): the full name of whom the rider pays (the summoner who casts them),
-- sent as S's third field; old riders ignore it. crew (2.2, optional): the full names of the
-- rest of the crew, S's fields 4 on (as many as fit): the rider's app trusts a trade only with
-- the driver, the payee, the summoner or one of these (review 2.2 #1), never any group member.
function W.SendStage(id, stage, buyer, payee, crew)
	id = rideId(id)
	stage = str(stage)
	stage = stage and (STAGE_ALIAS[stage] or stage)
	if not id or not (stage and STAGES[stage]) then return false end
	local r = findIncoming(id, W.Key(buyer))
	local to = target(r, buyer)
	if not to then return false end
	payee = str(payee)
	payee = payee and W.CleanName(payee) or nil
	local args = { id, stage, payee or "" }
	for _, n in ipairs(type(crew) == "table" and crew or {}) do
		n = str(n) and W.CleanName(str(n))
		if n and n ~= "" and #args < 9 then
			args[#args + 1] = n
			if #W.Encode("S", unpack(args)) > NETK.MAX_BYTES - 8 then args[#args] = nil break end
		end
	end
	if #args == 3 and not payee then args[3] = nil end
	local sent = W.SendTo(to, "S", unpack(args))
	if r then
		r.stage = stage
		if stage == "paid" or stage == "done" then removeIncoming(r, true) end
		W.Fire("REQUESTS", W.incoming)
	elseif sent and (stage == "paid" or stage == "done") then
		remember(id, W.Key(to)) -- the ride is no longer listed: its rating may still come
	end
	return sent
end

-- Tells the rider their place in the queue: whispers P (rideId, position 1 = next, eta
-- seconds). Sent only when the position changed since the last P for that ride (the rider
-- counts the eta down). buyer: as for W.SendStage. Driver.lua and WuberAPI.Queue both use
-- this. Returns whether P was sent.
function W.SendQueue(id, position, eta, buyer)
	id = rideId(id)
	position = localInt(position)
	if not id or not position then return false end
	position = clamp(position, 1, 40)
	eta = clamp(localInt(eta) or 0, 0, 3600)
	local r = findIncoming(id, W.Key(buyer))
	local to = target(r, buyer)
	if not to then return false end
	if r and r.position == position then return false end
	local sent = W.SendTo(to, "P", id, position, eta)
	if r and sent then
		r.position, r.queueEta = position, eta
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
	if impl() then providerCall("onCancel", id, r.buyer) end
end

-- T: rideId, stars (only from that ride's buyer, once)
local function heardRating(addr, name, key, f)
	local id = rideId(f[1])
	local stars = W.Int(f[2])
	if not id or not stars or rated[id] then return end
	stars = clamp(stars, 1, 5)
	-- (only a ride that ended paid/done, or one the rider has landed on; never
	-- from a player the driver blocked)
	local r = findIncoming(id, key)
	if r and r.stage ~= "arrived" then r = nil end
	if not r and finished[id] ~= key then return end
	local DRv = W.Drive
	if type(DRv) == "table" and type(DRv.BlockEntry) == "function" then
		local okB, e = pcall(DRv.BlockEntry, key)
		if okB and e then return end
	end
	rated[id] = true
	if impl() then
		providerCall("onRating", id, r and r.buyer or addr, stars)
		W.Fire("RATING", id, name, stars) -- the driver's screen still celebrates (coin shower)
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
		if r.state == "new" and not impl() and age >= NETK.ACCEPT_WINDOW then
			W.DeclineRequest(r.id, "busy", r.buyer) -- removes it
			changed = true
		elseif (r.state == "new" and age >= NETK.RIDE_TIMEOUT) or age >= NETK.INCOMING_MAX_AGE then
			removeIncoming(r)
			changed = true
		end
	end
	if changed then W.Fire("REQUESTS", W.incoming) end
end

-- for the Net modules that load after this one (REFACTOR-MAP section 2)
Mod.verByRide = verByRide
Mod.heardCancel, Mod.heardRating, Mod.heardRequest, Mod.tickIncoming, Mod.lastR = heardCancel, heardRating, heardRequest, tickIncoming, lastR
