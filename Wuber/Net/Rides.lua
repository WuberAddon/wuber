-- Module: Net.Rides
-- Purpose: Rider side of a ride: W.RequestRide/CancelRide/Rate/EndRide, stage tracking,
--   arrival, auto-accept of invites and summons, the fare and trade-window payment,
--   restoring a ride after /reload.
-- API: W.RideActive, W.AlreadyAt, W.RequestRide, W.CancelRide, W.EndRide, W.Rate, W.ClearRide,
--   W.RequestWhisper, W.RequestMacro, W.CancelWhisper, W.CancelMacro, W.CheckArrival,
--   CX.autoEnd, CX.driverHeard, W.CheckRide, W.GroupKeys, W.AutoLeave, W.tradeOpen, W.FareSteps, W.PayFare,
--   W.RideTrader, W.TradePartnerOK, W.SummonerMapOK, W.FareLeft
-- Internals: heardAccept, heardDecline, heardQueue, heardStage, restoreRide, requestArgs,
--   noteTime, rideTimes (2.3.0: rideId -> { paidAt, endedAt })
-- Uses: Net.Base, Net.Community, Net.Transport
-- Later: Net.Raincheck (W.Raincheck.ForDriver/Using/Used), Net.Bounty (W.Bounty.Mine/Cancel)
-- Events: listens On CHAT_MSG_SYSTEM, On PARTY_INVITE_REQUEST, On GROUP_ROSTER_UPDATE, On
--   CONFIRM_SUMMON, On CANCEL_SUMMON, On ZONE_CHANGED_NEW_AREA, On PLAYER_REGEN_ENABLED,
--   On PLAYER_ENTERING_WORLD, On ZONE_CHANGED, On ZONE_CHANGED_INDOORS, On TRADE_SHOW, On
--   TRADE_CLOSED, On TRADE_REQUEST_CANCEL, On TRADE_SHOW, On TRADE_ACCEPT_UPDATE, On
--   UI_INFO_MESSAGE, On UI_ERROR_MESSAGE, On TRADE_CLOSED, On PLAYER_MONEY; fires
--   DRIVERS, RAINCHECK, RIDE, TRADE_STRANGER
-- Standalone: no
-- Test: tests/net/rides_test.lua
-- From: Net.lua 2132-2942 (Wuber 2.2.1)
--
---------------------------------------------------------------------------
-- Being a rider: the ride
---------------------------------------------------------------------------

-- Whether the rider has a ride under way (not ended).
local _, W = ...
local Mod = W.Module("Net.Rides", { "Net.Base", "Net.Community", "Net.Transport" })
local BaseMod = W.Mod("Net.Base")
local CommunityMod = W.Mod("Net.Community")
local TransportMod = W.Mod("Net.Transport")
local ENDED, NETK, RANK, REASONS, STAGES = BaseMod.ENDED, BaseMod.NETK, BaseMod.RANK, BaseMod.REASONS, BaseMod.STAGES
local STAGE_ALIAS, STATE_LIMIT, clamp, clock, fb = BaseMod.STAGE_ALIAS, BaseMod.STATE_LIMIT, BaseMod.clamp, BaseMod.clock, BaseMod.fb
local localInt, myKey, netInt, now, rideId = BaseMod.localInt, BaseMod.myKey, BaseMod.netInt, BaseMod.now, BaseMod.rideId
local whisperedRecently = BaseMod.whisperedRecently
local CX = CommunityMod.CX
local hideInvitePopup, money = TransportMod.hideInvitePopup, TransportMod.money
local plain, str, num = W.Plain, W.Str, W.Num

function W.RideActive()
	return W.ride ~= nil and not ENDED[W.ride.state]
end

local SAVED = { "id", "driver", "addr", "driverKey", "service", "dest", "price", "state", "stage",
	"eta", "rated", "stars", "paid", "from", "reason", "summonAccepted", "inviter",
	"destWire", "destOk", "saved", "savedHow", "fromZone", "position", "tier", "rides",
	"origGroup", "wasGrouped", "waitingOut", "autoAccepted", "payClicked", "noAddon",
	"startedAt", "arrivedAt", "arrivedZone", "unpaid", "endedBy", "flightCost", "flightExact", "paidSoFar",
	"payee", "payto", "summoner", "summonedBy", "crew",
	"voucher", "voucherCover", "voucherTaken", "voucherRefused", "fare", "raincheck", "paidAt", "endedAt", "showPass", "arrivalSent" } -- (2.3.0: raincheck; round 9: showPass; 2.4: arrivalSent)

-- 2.3.0 (W.Raincheck.CanAsk): rideId -> { paidAt (in full, by trade), endedAt } (time(); session, <= 20); also r.paidAt/endedAt (saved)
local rideTimes, rideTimesOrder = {}, {}
local function noteTime(r, field, at)
	local id = r and r.id
	if not id then return end
	if not rideTimes[id] then
		rideTimesOrder[#rideTimesOrder + 1] = id
		if #rideTimesOrder > 20 then rideTimes[table.remove(rideTimesOrder, 1)] = nil end
		rideTimes[id] = {}
	end
	rideTimes[id][field], r[field] = at or clock(), at or clock()
end

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

-- The finished ride into the trip history (W.AddTrip), then the milestones (one
-- "MILESTONE" event at most).
local function saveTrip(r)
	if r.trip then return end
	r.trip = { id = r.id, at = clock(), driver = r.driver, driverKey = r.driverKey, service = r.service,
		dest = r.dest, price = r.price, stars = r.stars, saved = r.saved,
		savedValue = r.saved and W.TimeValue(r.saved) or nil, fromZone = r.fromZone,
		flightCost = r.flightCost, flightExact = r.flightExact, unpaid = r.unpaid or nil, -- (ended by the rider or by itself, never paid through Wuber)
		savedHow = r.saved and (r.savedHow == "own" or r.savedHow == "shared") and r.savedHow or nil } -- (2.3.0: none = about)
	W.AddTrip(r.trip)
	W.Safe("milestones", W.CheckMilestones)
end

-- Moves the ride forward (never back). Fires "RIDE". Returns whether it moved.
local function advance(r, state)
	if r ~= W.ride or ENDED[r.state] then return false end
	if (RANK[state] or 0) <= (RANK[r.state] or 0) then return false end
	r.state, r.changed = state, now()
	r.heldAt = nil -- (time held in the old state must not be added to the new state's clock)
	if (RANK[state] or 0) >= RANK.arrived then r.summonUp, r.summonNoName = false, nil end
	if state == "arrived" then
		r.arrivedAt = r.arrivedAt or clock() -- time(): the 10 min after arriving survive a /reload
		if not r.arrivalSent and str(r.id) and r.id ~= "" and str(r.addr) and r.addr ~= "" then
			r.arrivalSent = true
			W.SendTo(r.addr, "L", r.id) -- (2.4) landed: the driver's verified count (Drive.Rank) needs the rider's own word
		end
	end
	if state == "done" then
		saveTrip(r)
		if W.AutoLeave then W.AutoLeave(r) end
	end
	fireRide(r)
	return true
end

-- Ends the ride (declined, cancelled, timeout, failed). Fires "RIDE".
local function finish(r, state, reason)
	if r ~= W.ride or ENDED[r.state] then return false end
	r.state, r.reason, r.changed = state, reason, now()
	r.summonUp, r.summonNoName = false, nil
	if r.paid then noteTime(r, "endedAt") end -- (2.3.0: a paid ride that failed may ask for a raincheck)
	fireRide(r)
	return true
end

-- A driver who logged off without saying so: the game answers our whisper with "No player
-- named ...". Drop the driver at once, and end a ride still waiting on them (no resend, no C).
W.On("CHAT_MSG_SYSTEM", function(text)
	local key = W.Key(W.NotFoundName(text))
	if not key then return end
	if whisperedRecently(key) then
		-- our whisper fallback asked someone offline: not again for 5 min (rider), and no
		-- more of our changes to a rider who left (driver)
		fb.offlineUntil[key] = now() + ((W.IsCreator(key) or W.IsSeed(key)) and 1800 or 300) -- founders and seeds: often not on
		fb.riders[key] = nil
		if fb.unconfirmed and fb.unconfirmed[key] then
			-- a name from gossip nobody plays: dropped, not taken again for 30 min
			fb.unconfirmed[key] = nil
			fb.rejected[key] = now()
		end
	end
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

-- The place's name when the rider already stands in dest (the same place by name, or the
-- city of dest on the rider's own map), else nil: no ride is booked there.
function W.AlreadyAt(dest)
	dest = str(dest)
	if not dest or dest == "" then return nil end
	local p = W.FindPlace and W.FindPlace(dest) or nil
	local name = (p and str(p.name)) or dest
	local here = W.DestHere()
	if here and W.SamePlace(here, dest) then return name end
	if p and p.kind == "city" and W.MyPosition then
		local okp, mapID = pcall(W.MyPosition)
		if okp and num(mapID) and num(mapID) == p.mapID then return name end
	end
	return nil
end

-- Asks a driver for a ride: sets up W.ride (state "requesting") and sends R (with our
-- level and ride count). Works in combat and inside an instance (addon messages aren't
-- protected; the UI skips the chat whisper in combat): inside, r.waitingOut is true and the
-- R's fields: rideId, dest, price, tier, rides; (2.3.0) field 6 this client's version and 7 the
-- raincheck id, sent only from 2.3.0 on or with a raincheck (an older Wuber's R is unchanged).
local function requestArgs(r)
	local v = r.voucher
	if v then return r.id, r.destWire or r.dest, r.fare or r.price, r.tier or 0, r.rides, W.VERSION, v end
	if W.VerAtLeast(W.VERSION, "2.3.0") then return r.id, r.destWire or r.dest, r.price, r.tier or 0, r.rides, W.VERSION end
	return r.id, r.destWire or r.dest, r.price, r.tier or 0, r.rides
end

-- accepted / invited timeouts wait until we are out (and out of combat). The flying time saved is worked out now, from where we stand:
-- r.saved (seconds or nil), r.savedHow (2.3.0: "own" | "shared" measured, else an estimate), r.fromZone. The chat whisper is the UI's secure
-- button (W.RequestWhisper). Returns the ride, or nil and why:
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
	local here = W.AlreadyAt(d.dest)
	if here then return nil, "here", here end
	if W.InGroup() and not W.InGroupWith(d.key) then return nil, "group" end
	local okT, saved, how, measured = pcall(W.TravelSaved, d.dest)
	if not okT then saved, how, measured = nil, nil, nil end
	-- (round 13, I14) by zeppelin or boat: Confirm compared against that (free), so the pay card does too
	local crossing = how == "by zeppelin" or how == "by boat"
	if measured then local okF, _, src = pcall(W.FlightTime, nil, d.dest) how = okF and src or how end -- (2.3.0: own | shared)
	-- what flying there would cost (SPEC5 flight costs): only what a flight master showed (exact 1)
	local fly = W.FlightInfo and W.FlightInfo(d.dest) or nil
	if crossing and type(fly) == "table" and fly.via ~= "boat" then fly = nil end
	local stats = W.Stats()
	local r = {
		id = W.NewRideId(), driver = d.name, addr = d.addr or d.name, driverKey = d.key,
		service = d.service, dest = d.dest, destWire = d.destWire or d.dest, destOk = d.destOk,
		price = d.price, state = "requesting", summoner = d.summoner,
		at = now(), changed = now(), from = (W.DestHere()), startedAt = clock(),
		saved = saved, savedHow = how, fromZone = W.ZoneHere(),
		flightCost = fly and fly.cost or nil, flightExact = fly and fly.exact or nil,
		tier = W.Tier(stats.rides), rides = clamp(stats.rides, 0, 9999),
		origGroup = W.GroupKeys(d.key), wasGrouped = W.InGroup() or nil, waitingOut = W.InInstance() or nil,
		-- this account can't send addon messages: the request goes only as the chat whisper
		noAddon = W.net.cantSend or nil,
		showPass = d.showPass == true or nil, -- round 9 (C10): the driver's passphrase flag, cached (Net.Beacons refreshes it)
	}
	-- 2.3.0: a raincheck the rider holds for this driver (Confirm's "Use raincheck", on by default)
	local RC = W.Raincheck
	if type(RC) == "table" and type(RC.ForDriver) == "function" and (type(RC.Using) ~= "function" or RC.Using(d.key)) then
		local okV, vid, cover = pcall(RC.ForDriver, d)
		if okV and vid then r.voucher, r.voucherCover, r.raincheck = vid, localInt(cover) or 0, { id = vid, cover = localInt(cover) or 0 } end
	end
	W.ride = r
	W.SendTo(r.addr, "R", requestArgs(r))
	fireRide(r)
	-- 2.3.0: booking any ride ends the rider's bounty
	local B = W.Bounty
	if type(B) == "table" and type(B.Mine) == "function" and B.Mine() then W.Safe("bounty", B.Cancel, "booked") end
	W.After(NETK.RESEND_AFTER, function() W.Safe("resend", W.CheckRide) end)
	W.After(NETK.RIDE_TIMEOUT, function() W.Safe("timeout", W.CheckRide) end)
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

-- Ends the rider's ride here after arriving (no trade came, the fare was paid another way
-- or waived): done, kept as a trip, marked unpaid if Wuber never saw the fare go, nothing
-- sent to the driver. reason: "rider" (the End ride button) or "auto" (W.CheckRide). Fires
-- "RIDE" as any finished ride. Returns whether it ended.
function W.EndRide(reason)
	local r = W.ride
	if not W.RideActive() or (RANK[r.state] or 0) < RANK.arrived then return false end
	r.endedBy = (reason == "auto") and "auto" or "rider"
	if not r.paid then r.unpaid = true end
	return advance(r, "done")
end

-- Rates the ride 1-5 stars (once, after arrival): whispers T and keeps the stars with the
-- saved trip. Returns whether it was sent.
function W.Rate(stars)
	local r = W.ride
	stars = localInt(stars)
	if not r or r.rated or not stars or r.unpaid then return false end -- unpaid: nothing to rate
	local rank = RANK[r.state]
	if not rank or rank < RANK.arrived then return false end
	-- a rating is for a ride that is paid (or over and not unpaid): not before paying
	if not r.paid and r.state ~= "done" then return false end
	stars = clamp(stars, 1, 5)
	r.rated, r.stars = true, stars
	local trip = r.trip
	if not trip and r.id then -- after a /reload the trip is only in the saved history: find it by id
		local list = W.db and W.db.rides
		for i = list and #list or 0, 1, -1 do
			if list[i].id == r.id then trip = list[i] break end
		end
	end
	if trip then trip.stars = stars end
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
-- "WTB summon to Ratchet for 50s", "Anita-Lift". The dest is the driver's beaconed text when
-- it passed the whitelist, else the name riders are shown. nil if the driver is unknown.
function W.RequestWhisper(driverKey)
	local key = W.Key(driverKey)
	local d = W.drivers[driverKey] or (key and W.drivers[key])
	local r = W.ride
	if not d and r and key and r.driverKey == key then
		d = { name = r.driver, dest = r.dest, destWire = r.destWire, destOk = r.destOk, price = r.price }
	end
	if not d then return nil end
	local dest = (d.destOk and d.destWire) or d.dest
	return "WTB summon to " .. tostring(dest) .. " for " .. W.Money(d.price), W.MacroName(d.name)
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
	if r.voucherTaken and type(W.Raincheck) == "table" and type(W.Raincheck.Used) == "function" then
		W.Safe("raincheck", W.Raincheck.Used, r.voucher) -- (2.3.0: the rider's copy; the driver's book decides)
	end
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

-- (review 2.2 #14) Booked: the other drivers we whispered a Q in the last 5.5 min hear B, so
-- they stop pushing us their D (SPEC5 stagger). One tiny whisper each, once.
local function tellBooked(except)
	local t = now()
	for k, addr in pairs(fb.qAddr) do
		local at = fb.qAt[k]
		fb.qAddr[k] = nil
		if k ~= except and at and t - at <= NETK.RIDER_KEEP then W.SendTo(addr, "B") end
	end
end

-- When the ride's driver was last heard: a ride message (A, S, P: r.heardAt), the driver's
-- beacon (also a private one), or the ride's last change, whichever is latest.
function CX.driverHeard(r)
	local at = math.max(r.heardAt or 0, r.changed or r.at or 0)
	local d = r.driverKey and ((W.drivers and W.drivers[r.driverKey]) or (W.hiddenDrivers and W.hiddenDrivers[r.driverKey]))
	local heard = type(d) == "table" and tonumber(d.heard)
	if heard and heard > at then at = heard end
	return at
end

-- A: rideId, price, eta
local function heardAccept(addr, key, f)
	local id = rideId(f[1])
	if not id then return end
	local r = rideFrom(key, id)
	local w = W.ride
	if not r and w and w.noAddon and w.state == "requesting" and w.driverKey == key then
		-- our request went by chat only: the driver's ride id is the one to use
		w.id = id
		r = w
	end
	if not r then
		W.SendTo(addr, "C", id) -- not a ride we are waiting for: let the driver drop it
		return
	end
	local price = W.Int(f[2])
	-- the fare may come down (the driver cut the price), never up past what the rider asked
	-- at, and never under the network's lowest fare
	if r.voucher then
		-- 2.3.0: we named a raincheck; field 4 "1" = the book took it: the fare less its cover is due
		r.fare = r.fare or localInt(r.price) or W.MIN_PRICE
		local fare = price and clamp(price, W.MIN_PRICE, math.max(W.MIN_PRICE, r.fare)) or r.fare
		r.fare = fare
		r.voucherTaken = f[4] == "1" or nil
		r.voucherRefused = not r.voucherTaken or nil
		if type(r.raincheck) == "table" then r.raincheck.taken = r.voucherTaken == true end -- (UI.RaincheckCover)
		r.price = r.voucherTaken and math.max(0, fare - (r.voucherCover or 0)) or fare
		W.Fire("RAINCHECK", r.voucherTaken and "taken" or "refused", r.voucher)
	elseif price then r.price = clamp(price, W.MIN_PRICE, math.max(W.MIN_PRICE, localInt(r.price) or W.MIN_PRICE)) end
	r.eta = netInt(f[3], 0, 3600, 0)
	r.etaAt = now() + r.eta
	r.heardAt = now()
	if not r.acceptedAt then tellBooked(key) end
	r.acceptedAt = r.acceptedAt or now()
	if not advance(r, "accepted") then fireRide(r) end
	if rideGroup(r) then advance(r, "ingroup") end
end

-- N: rideId, reason
-- (rideFrom: only this ride's driver; in the group still counts, as the driver's rideGone
-- sends N up to the summon; once it is cast a late N is not believed)
local function heardDecline(key, f)
	local r = rideFrom(key, rideId(f[1]))
	if not r or (RANK[r.state] or 0) >= RANK.summoning then return end
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
	r.heardAt = now()
	-- 2.1: whom to pay (the summoner who casts), shown as "Pay Bea"
	local payee = f[3] and W.CleanName(f[3])
	if payee and payee ~= "" and W.Key(payee) then r.payee, r.payto = payee, W.Short(payee) end
	-- 2.2: the rest of the driver's crew (fields 4 on), the only others a fare may go to
	if f[4] then
		local crew = {}
		for i = 4, math.min(#f, 9) do
			local k = W.Key(W.CleanName(f[i] or ""))
			if k then crew[#crew + 1] = k end
		end
		r.crew = crew
	end
	if stage == "arrived" then
		if not arrive(r) then fireRide(r) end
		return
	end
	-- 2.3.0: paid by trade before the summon: the driver's "paid" isn't arriving (a failure may ask for a raincheck)
	if stage == "paid" and r.paid and (RANK[r.state] or 0) < RANK.arrived then return fireRide(r) end
	if not advance(r, STAGE_STATE[stage]) then fireRide(r) end
end

-- P: rideId, position, eta (only from our ride's driver). Sets r.position (1 = next), r.heardAt,
-- r.eta and r.etaAt (GetTime() when the eta runs out: the UI counts down). The driver sends the same place again
-- every 60 s as a keep-alive: a repeat of the place the ride already has leaves a running countdown alone
-- (r.heardAt still renews). Fires "RIDE".
local function heardQueue(key, f)
	local r = rideFrom(key, rideId(f[1]))
	local position = W.Int(f[2])
	if not r or not position or position < 1 then return end
	local place = clamp(position, 1, 40)
	local same = r.position == place and r.etaAt
	r.position = place
	if not same then
		r.eta = netInt(f[3], 0, 3600, 0)
		r.etaAt = now() + r.eta
	end
	r.heardAt = now()
	fireRide(r)
end

-- An arrived (or paying) ride ends by itself (W.EndRide "auto") when the rider has been out
-- of the driver's group for 60 s, has left the destination's zone, or 10 min after arriving
-- (time(), so a /reload doesn't restart it). Returns whether it ended.
function CX.autoEnd(r, t)
	if W.InCombat() then return false end -- a fight at the portal is not leaving
	if rideGroup(r) then
		r.groupGoneAt = nil
		if r.state == "paying" then r.paySeenInGroup = true end
	else
		r.groupGoneAt = r.groupGoneAt or t
	end
	local arrivedAt = num(r.arrivedAt)
	if arrivedAt and clock() - arrivedAt >= 600 then return W.EndRide("auto") end
	-- a rider at the pay step whom the driver took out of the group (marked paid by hand, trade cancelled) isn't
	-- going to trade: that ends in 5 s, not 60 (run 1 item 7)
	-- (only a rider seen in the group at the pay step: one who was never grouped keeps the 60 s)
	local goneLimit = (r.state == "paying" and r.paySeenInGroup) and 5 or 60
	if r.groupGoneAt and t - r.groupGoneAt >= goneLimit then return W.EndRide("auto") end
	-- the zone we stood in at the destination; leaving it (a hearthstone, a flight) ends the ride
	local zone = W.ZoneHere()
	if W.SamePlace((W.DestHere()), r.dest) then
		r.arrivedZone = zone
	elseif r.arrivedZone and zone and zone ~= r.arrivedZone and not W.InInstance() then
		return W.EndRide("auto")
	end
	return false
end

-- The ride's clock: resends R once, times out a state that has lasted too long, and notices
-- the group and arrival. Run every second (and by timers).
function W.CheckRide()
	local r = W.ride
	if not W.RideActive() then return end
	local t = now()
	if r.state == "requesting" and not r.resent and t - (r.at or t) >= NETK.RESEND_AFTER then
		r.resent = true
		W.SendTo(r.addr, "R", requestArgs(r))
	end
	-- in combat or in an instance the accepted / invited clocks stand still
	local inside = W.InInstance()
	if (r.waitingOut == true) ~= inside then
		r.waitingOut = inside or nil
		fireRide(r)
	end
	local held = (r.state == "accepted" or r.state == "invited") and (inside or W.InCombat())
	if held then
		r.heldAt = r.heldAt or t
	elseif r.heldAt then
		r.changed = (r.changed or t) + (t - r.heldAt)
		r.heldAt = nil
	end
	if (r.state == "arrived" or r.state == "paying") and CX.autoEnd(r, t) then return end
	local limit = STATE_LIMIT[r.state]
	if r.noAddon and r.state == "requesting" then limit = { 120, "timeout" } end -- a chat request waits longer
	-- in line (a place was heard): the rider waits while the driver keeps him, and gives up only
	-- when nothing was heard from that driver for NETK.QUEUE_SILENCE
	local since = r.changed or r.at or t
	if r.state == "accepted" and r.position then limit, since = { NETK.QUEUE_SILENCE, "failed" }, CX.driverHeard(r) end
	if limit and not held and t - since >= limit[1] - 0.01 then
		if limit[2] == "done" then
			r.doneByTimeout = true
			if not r.paid then r.unpaid = true end -- as W.EndRide: no paid trip, no milestone, no rating
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

-- Accepts the ride's invite for the rider (W.db.autoAccept), the way a click on the game's
-- box would: AcceptGroup through W.Try("accept"), then the box is marked accepted and hidden
-- (now, and again as it may open after this). If the game refuses it, that is remembered for
-- this build and the UI's "Accept invite" button is used instead, without a message.
-- Returns whether it accepted.
local function autoAcceptInvite(r)
	if not (W.db and W.db.autoAccept) or W.IsBlocked("accept") or W.InGroup() then return false end
	if not W.Try("accept", AcceptGroup) then return false end
	r.autoAccepted = true
	hideInvitePopup()
	W.After(0.2, hideInvitePopup)
	W.After(1, hideInvitePopup)
	return true
end

-- Invited: any invite while we wait for one (a teammate of the driver may send it). Only
-- the driver's own invite is accepted for us automatically (a stranger could time an invite
-- to the same moment); anyone else's leaves the "Accept invite" button to the rider.
W.On("PARTY_INVITE_REQUEST", function(inviter)
	local r = W.ride
	if not W.RideActive() or (RANK[r.state] or 0) >= RANK.ingroup then return end
	local key = W.Key(W.CleanName(inviter))
	local fromDriver = key ~= nil and key == r.driverKey
	-- already invited (the driver's S "invited" came before the game's box, or a re-invite):
	-- the driver's own invite still counts; anyone else's only if no inviter is known yet
	if (RANK[r.state] or 0) >= RANK.invited and not fromDriver and r.inviter then return end
	-- (a request by chat only has no A: any invite then may be the driver's team)
	if not fromDriver and (RANK[r.state] or 0) < RANK.accepted and not r.noAddon then return end
	r.inviter = key
	local trusted = fromDriver
	-- accepted first, so the "invited" toast already knows Wuber joined the rider (no "Accept the invite.")
	local accepted = trusted and autoAcceptInvite(r)
	advance(r, "invited")
	if accepted then fireRide(r) end
end)

W.On("GROUP_ROSTER_UPDATE", function()
	local r = W.ride
	if not W.RideActive() then return end
	local rank = RANK[r.state] or 0
	if rank >= RANK.accepted and rank < RANK.ingroup and rideGroup(r) then advance(r, "ingroup") end
	-- the way back: "in the group" with no group (the summon ran out in the group and the rider left later) is waiting for the invite again
	if r.state == "ingroup" and not W.InGroup() then
		r.state, r.changed = "accepted", now()
		fireRide(r)
	end
end)

-- The summon is up: from any of the driver's Warlocks.
W.On("CONFIRM_SUMMON", function()
	local r = W.ride
	if not W.RideActive() or (RANK[r.state] or 0) < RANK.accepted then return end
	r.summonUp = true
	-- who really cast it (a Warlock of the driver's): may take the fare (review 2.2 #1)
	-- (the game may not have filled the name yet: askSummoner looks again each second for about 5 s)
	local function askSummoner()
		local SI = rawget(_G, "C_SummonInfo")
		local fn = type(SI) == "table" and SI.GetSummonConfirmSummoner or rawget(_G, "GetSummonConfirmSummoner")
		if type(fn) ~= "function" then return nil end
		local okS, who = pcall(fn)
		who = okS and str(who) or nil
		-- (the game's own words for "not known yet" are no name)
		if who == "" or who == "Unknown" or who == rawget(_G, "UNKNOWNOBJECT") or who == rawget(_G, "UNKNOWN") then who = nil end
		return who and W.Key(W.CleanName(who)) or nil
	end
	local k = askSummoner()
	if k then
		r.summonedBy = k
		r.summonNoName = nil
	else
		r.summonNoName = true
	end
	if not advance(r, "portal") then fireRide(r) end
	if not k then
		local function again(n)
			W.After(1, function()
				if W.ride ~= r or not r.summonUp or r.summonedBy or ENDED[r.state] then return end
				local late = askSummoner()
				if late then
					r.summonedBy = late
					r.summonNoName = nil
					fireRide(r) -- (the same state an immediate name gives; screens look again)
				elseif n < 5 then
					again(n + 1)
				end
			end)
		end
		again(1)
	end
end)

-- The summon ran out or was cancelled: back to waiting in the group. Every group exit fires it
-- too: out of the group there is nothing to wait in, so back to waiting for the invite.
W.On("CANCEL_SUMMON", function()
	local r = W.ride
	if not W.RideActive() or r.state ~= "portal" then return end
	r.summonUp, r.summonNoName = false, nil
	r.state, r.changed = (W.InGroup() and "ingroup" or "accepted"), now()
	fireRide(r)
	-- the game's roster update follows the group exit a moment later: if the group still counted
	-- just now, look once more
	if r.state == "ingroup" then
		W.After(0.3, function()
			if W.ride == r and r.state == "ingroup" and not W.InGroup() then
				r.state, r.changed = "accepted", now()
				fireRide(r)
			end
		end)
	end
end)

W.On("ZONE_CHANGED_NEW_AREA", function() W.CheckArrival() end)
W.On("PLAYER_REGEN_ENABLED", function() W.CheckRide() end) -- held clocks run again
W.On("PLAYER_ENTERING_WORLD", function() if W.loggedIn then W.CheckRide() end end)
W.On("ZONE_CHANGED", function() W.CheckArrival() end)
W.On("ZONE_CHANGED_INDOORS", function() W.CheckArrival() end)

-- The keys of everyone in our group now, as a set (without `except`).
function W.GroupKeys(except)
	local out = {}
	for i = 1, 4 do
		local k = W.Key(W.UnitName("party" .. i))
		if k and k ~= except then out[k] = true end
	end
	for i = 1, 40 do
		local k = W.Key(W.UnitName("raid" .. i))
		if k and k ~= except and k ~= myKey() then out[k] = true end
	end
	return out
end

-- Leaves the driver's group 3 s after a paid ride (W.db.autoLeave), never in combat (it
-- waits), and only when nobody from the group we were in before the ride is with us.
function W.AutoLeave(r)
	if not (W.db and W.db.autoLeave) or not r or r.doneByTimeout or r.endedBy or r.leaveQueued then return false end
	-- already in a group (even the driver's own) when booking: that group is the rider's to keep
	if r.wasGrouped then return false end
	r.leaveQueued = true
	W.After(3, function()
		W.AfterCombat(function()
			if W.ride ~= r and W.RideActive() then return end -- a new ride already
			if not W.InGroup() or not rideGroup(r) then return end
			if type(r.origGroup) == "table" then
				for k in pairs(W.GroupKeys()) do
					if r.origGroup[k] then return end
				end
			end
			local fn = type(C_PartyInfo) == "table" and C_PartyInfo.LeaveParty or nil
			if type(fn) ~= "function" then fn = LeaveParty end
			if W.Try("leave", fn) then
				r.autoLeft = true
				if r == W.ride then fireRide(r) end
			end
		end)
	end)
	return true
end

W.tradeOpen = false
W.On("TRADE_SHOW", function() W.tradeOpen = true end)
W.On("TRADE_CLOSED", function() W.tradeOpen = false end)
W.On("TRADE_REQUEST_CANCEL", function() W.tradeOpen = false end)

local function tradeShown()
	if W.tradeOpen then return true end
	local f = TradeFrame
	if type(f) ~= "table" or type(f.IsShown) ~= "function" then return false end
	local ok, shown = pcall(f.IsShown, f)
	return ok and W.Plain(shown) == true
end

-- How to pay (WoW Forever lets only the game's own interface put gold in a trade, and only
-- the player's click on Trade accepts it, so Wuber never touches the money): the exact words
-- to type, e.g. "Type 50 in silver, then click Trade." W.FareSteps(copper) -> that line.
function W.FareSteps(fare)
	fare = math.max(0, math.floor(tonumber(fare) or 0))
	local g, sv, c = math.floor(fare / 10000), math.floor(fare % 10000 / 100), fare % 100
	local parts = {}
	if g > 0 then parts[#parts + 1] = g .. " in gold" end
	if sv > 0 then parts[#parts + 1] = sv .. " in silver" end
	if c > 0 then parts[#parts + 1] = c .. " in copper" end
	if #parts == 0 then return "Nothing to pay." end
	return "Type " .. table.concat(parts, ", ") .. ", then click Trade."
end

-- W.PayFare(): kept for the UI and old callers; checks the ride and the trade and returns
-- ok and the line saying what to type. It puts nothing in the trade and accepts nothing.
function W.PayFare()
	local r = W.ride
	if not W.RideActive() then return false, "There's no ride to pay for." end
	if (RANK[r.state] or 0) < RANK.arrived then return false, "Pay once you've arrived." end
	if not tradeShown() then return false, "Wait for your driver to open a trade." end
	local partner = W.Key(W.UnitName("npc"))
	if partner then
		if not W.RideTrader(r, partner) then return false, "That trade isn't with your driver." end
	elseif not rideGroup(r) then
		return false, "That trade isn't with your driver."
	end
	local fare = clamp(localInt(r.price) or 0, 0, NETK.MAX_PRICE)
	if fare <= 0 then return false, "This ride costs nothing, so there is nothing to pay." end
	local m = money()
	if m and m < fare then return false, "You need " .. W.Money(fare) .. "." end
	if W.InCombat() then return false, "Leave combat first." end
	r.moneyBefore = r.moneyBefore or m
	return true, W.FareSteps(fare)
end

-- Whether `key` may take this ride's fare (SPEC5 tradecheck; review 2.2 #1): the driver, the
-- summoner to pay, the beacon's summoner, or a crew member the driver named in its S. Never
-- just anyone in the group: a group full of riders is not the driver's crew.
function W.RideTrader(r, key)
	key = key and W.Key(key)
	if type(r) ~= "table" or not key then return false end
	for _, f in ipairs({ "driverKey", "driver", "payee", "summoner", "summonedBy" }) do
		local k = str(r[f])
		if k and W.Key(k) == key then return true end
	end
	for _, k in ipairs(type(r.crew) == "table" and r.crew or {}) do
		if k == key then return true end
	end
	return false
end

-- Whether the trade open now is with our driver or the driver's crew (SPEC5 tradecheck,
-- review #3, 2.2 #1): true; false = anyone else (never pay them); nil = no ride, no trade, or
-- the game didn't say who.
function W.TradePartnerOK()
	local r = W.ride
	if not W.RideActive() or not tradeShown() then return nil end
	local partner = W.Key(W.UnitName("npc"))
	if not partner then return nil end
	return W.RideTrader(r, partner)
end

-- Paying (SPEC5 full + complete, review #3): only a trade with the driver or the driver's crew
-- (W.RideTrader), and only one that completed (both accepted, "Trade complete."), counts.
-- Part payments add up; the ride is paid at the whole (locked) fare. A trade that closed
-- without completing forgets the purse it saw, so a repair or a flight afterwards is never
-- taken for the fare.
-- Review 2.2 #2: on the real client TRADE_CLOSED can come before "Trade complete." (both from
-- one status packet) and the last one to accept never sees TRADE_ACCEPT_UPDATE(1,1); the
-- purse changes a moment later. So a close keeps the purse it saw for 5 s: "Trade complete."
-- in that time counts it (now, or the purse change within 3 s); a failure line, a new trade
-- or 5 s without the line forget it.
W.On("TRADE_SHOW", function()
	local r = W.ride
	if not W.RideActive() then return end
	local rank = RANK[r.state] or 0
	if rank < RANK.ingroup or rank >= RANK.done then return end
	r.tradeBothAt, r.tradeDoneAt, r.moneyUntil, r.tradeClosedAt = nil, nil, nil, nil
	if W.TradePartnerOK() == false then
		local who = W.UnitName("npc")
		r.moneyBefore = nil
		r.stranger = who
		W.Fire("TRADE_STRANGER", who, r)
		return
	end
	r.stranger = nil
	r.moneyBefore = money()
	if rank >= RANK.arrived and rank < RANK.paying then advance(r, "paying") end
end)

W.On("TRADE_ACCEPT_UPDATE", function(mine, theirs)
	local r = W.ride
	if not W.RideActive() then return end
	if num(mine) == 1 and num(theirs) == 1 then r.tradeBothAt = now() end
end)

local function tradeCompleted(r)
	local t = now()
	return (r.tradeBothAt and t - r.tradeBothAt <= 2) or (r.tradeDoneAt and t - r.tradeDoneAt <= 2)
end

-- The purse against the one seen when the trade opened: what went counts toward the fare.
-- Returns whether a payment was counted.
local function countPaid(r)
	local m = money()
	local fare = num(r.price) or 0
	if not r.moneyBefore or not m or fare <= 0 then return false end
	local spent = r.moneyBefore - m
	if spent <= 0 then return false end
	r.moneyBefore, r.moneyUntil, r.tradeClosedAt = nil, nil, nil
	r.paidSoFar = (r.paidSoFar or 0) + spent
	if r.paidSoFar >= fare then
		r.paid = r.paidSoFar -- (r.paid: paid in full)
		noteTime(r, "paidAt") -- (2.3.0: by a completed trade; a raincheck needs it)
		if (RANK[r.state] or 0) >= RANK.arrived then advance(r, "done") else fireRide(r) end
	else
		fireRide(r) -- part paid: the pay strip shows what is left
	end
	return true
end

local TRADE_FAILS = { "ERR_TRADE_CANCELLED", "ERR_TRADE_BAG_FULL", "ERR_TRADE_TARGET_BAG_FULL", "ERR_TRADE_TOO_FAR",
	"ERR_TRADE_TARGET_DEAD", "ERR_TRADE_MAX_COUNT_EXCEEDED", "ERR_TRADE_TARGET_MAX_COUNT_EXCEEDED",
	"ERR_TRADE_NOT_ON_TAPLIST", "ERR_TRADE_QUEST_ITEM", "ERR_TRADE_SELF", "ERR_TRADE_WRONG_REALM",
	"ERR_TRADE_EQUIPPED_BAG", "ERR_TRADE_GROUND_ITEM", "ERR_TRADE_BOUND_ITEM", "ERR_TRADE_TEMP_ENCHANT_BOUND" }

-- (messageType, message); an older client sends the message alone
local function riderTradeLine(a, b)
	local r = W.ride
	if not W.RideActive() then return end
	local message = str(b) or (type(a) == "string" and str(a)) or nil
	if not message then return end
	local done = rawget(_G, "ERR_TRADE_COMPLETE")
	if (done and message == done) or message == "Trade complete." then
		r.tradeDoneAt = now()
		if r.moneyBefore and r.tradeClosedAt and now() - r.tradeClosedAt <= 5 then
			-- the window closed first: count it now, or when the purse changes (3 s)
			if not countPaid(r) then r.moneyUntil = now() + 3 end
		end
		return
	end
	for _, k in ipairs(TRADE_FAILS) do
		local v = rawget(_G, k)
		if type(v) == "string" and v ~= "" and message == v then
			r.tradeBothAt, r.tradeDoneAt = nil, nil
			if r.tradeClosedAt or not tradeShown() then r.moneyBefore, r.moneyUntil, r.tradeClosedAt = nil, nil, nil end
			return
		end
	end
end
W.On("UI_INFO_MESSAGE", riderTradeLine)
W.On("UI_ERROR_MESSAGE", riderTradeLine)

W.On("TRADE_CLOSED", function()
	local r = W.ride
	if not W.RideActive() or not r.moneyBefore then return end
	if tradeCompleted(r) then
		r.moneyUntil = now() + 3 -- the purse may change just after the window closes
		countPaid(r)
		return
	end
	if r.tradeClosedAt then return end -- (the game sends TRADE_CLOSED twice)
	local closedAt = now()
	r.tradeClosedAt = closedAt
	W.After(5, function()
		-- no "Trade complete." in 5 s: it didn't go through
		if r.tradeClosedAt == closedAt and not tradeCompleted(r) and not (r.moneyUntil and now() <= r.moneyUntil) then
			r.moneyBefore, r.moneyUntil, r.tradeClosedAt = nil, nil, nil
		end
	end)
end)

W.On("PLAYER_MONEY", function()
	local r = W.ride
	if not W.RideActive() or not r.moneyBefore then return end
	if not (tradeCompleted(r) or (r.moneyUntil and now() <= r.moneyUntil)) then return end
	countPaid(r)
end)

-- Before "Accept summon" (SPEC5 mapcheck, review #26): whether the group really stands where
-- the ride goes. The game's own map of each party/raid member (server-side, not the driver's
-- beacon) against the booked place's map (or its zone's). Returns true (someone of the group
-- - the summoner first - is there), false (readable, and nobody is: the screen warns, never
-- blocks), or nil (can't tell: say nothing); then the summoner's (or driver's) map name.
function W.SummonerMapOK(ride)
	ride = ride or W.ride
	if type(ride) ~= "table" or not W.InGroup() then return nil end
	local place = W.ExactPlace and (W.ExactPlace(ride.dest or "") or W.FindPlace(ride.dest or ""))
	if not place or not place.mapID then return nil end
	local okMaps = { [place.mapID] = true }
	local zone = place.zone and W.ExactPlace(place.zone)
	if zone and zone.mapID then okMaps[zone.mapID] = true end
	local CM = C_Map
	if type(CM) ~= "table" or type(CM.GetBestMapForUnit) ~= "function" then return nil end
	-- whose map counts (review 2.2 #7): who the game says cast it (summonedBy, AUD-16), else the beacon's
	-- summoner, else the payee, else the driver (a runner may stand elsewhere: the driver only when none is known)
	local want = {}
	for rank, f in ipairs({ "summonedBy", "summoner", "payee", "driverKey" }) do
		local k = ride[f] and W.Key(ride[f])
		if k and not want[k] then want[k] = rank end
	end
	local me = myKey()
	local readable, anyOk, sumMap, sumRank = false, false, nil, 99
	local function look(unit)
		local k = W.Key(W.UnitName(unit))
		if not k or k == me then return end
		local okM, m = pcall(CM.GetBestMapForUnit, unit)
		m = okM and num(m) or nil
		if not m then return end
		readable = true
		if okMaps[m] then anyOk = true end
		if want[k] and want[k] < sumRank then sumMap, sumRank = m, want[k] end
	end
	for i = 1, 4 do look("party" .. i) end
	for i = 1, 40 do look("raid" .. i) end
	if not readable then return nil end
	local where
	if sumMap and type(CM.GetMapInfo) == "function" then
		local okI, info = pcall(CM.GetMapInfo, sumMap)
		info = okI and plain(info) or nil
		where = type(info) == "table" and str(info.name) or nil
	end
	-- the summoner himself elsewhere: false, even if someone else of the group is there
	if sumMap and not okMaps[sumMap] then return false, where end
	return anyOk, where
end

-- What is left to pay of the fare (copper), and what was paid so far.
function W.FareLeft()
	local r = W.ride
	if not W.RideActive() then return 0, 0 end
	local fare = num(r.price) or 0
	local paid = num(r.paidSoFar) or 0
	return math.max(0, fare - paid), paid
end

-- After a /reload: the ride saved in W.db.ride, if under way and under 10 min old (2.3.0: or paid, failed, within 30 min of paying).
local function restoreRide()
	local s = W.db and W.db.ride
	if type(s) ~= "table" then return end
	local age = clock() - (num(s.savedAt) or 0)
	local state = str(s.state)
	local started = num(s.startedAt)
	if state and not ENDED[state] and started and clock() - started > 7200 then
		W.db.ride = nil -- a ride left open for over 2 hours: gone, silently
		return
	end
	local since = clock() - (num(s.paidAt) or -1e9) -- (2.3.0: a paid ride that failed may ask for a raincheck for 30 min)
	local keep = state ~= nil and rideId(s.id) and str(s.driverKey) and ((ENDED[state] and state ~= "done" and s.paid and since >= 0 and since < 1800)
		or (age >= 0 and age < NETK.RESTORE_MAX_AGE and ((RANK[state] ~= nil and state ~= "done") or (state == "done" and not s.rated and not s.unpaid))))
	if not keep then
		W.db.ride = nil
		return
	end
	local r = {}
	for _, k in ipairs(SAVED) do r[k] = s[k] end
	r.at, r.changed, r.resent, r.addr = now(), now(), true, r.addr or r.driver
	if (RANK[r.state] or 0) >= RANK.accepted then r.acceptedAt = now() end -- (acceptedAt is not saved: the driver's live G is believed again after a reload)
	for _, f in ipairs({ "paidAt", "endedAt" }) do if num(r[f]) then noteTime(r, f, num(r[f])) end end -- (2.3.0)
	W.ride = r
	fireRide(r)
end

-- for the Net modules that load after this one (REFACTOR-MAP section 2)
Mod.rideTimes = rideTimes
Mod.heardAccept, Mod.heardDecline, Mod.heardQueue, Mod.heardStage, Mod.restoreRide = heardAccept, heardDecline, heardQueue, heardStage, restoreRide
