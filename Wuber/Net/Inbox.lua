-- Module: Net.Inbox
-- Purpose: Hearing messages: the CHAT_MSG_ADDON / CHAT_MSG_WHISPER dispatchers, channel
--   notices, club events, the 1 s net tick and Net start-up at login.
-- API: W.NetTick
-- Internals: (none)
-- Uses: Net.Base, Net.Community, Net.Beacons, Net.Requests, Net.Rides, Net.Favourites, Net.Discovery
-- Later: Net.Bounty (tick), FX.Moments (markRestored), FX.Emblem (W.EmblemHeard: the Q ping's field 2)
-- Events: listens On CHAT_MSG_ADDON, On CHAT_MSG_WHISPER, On CHAT_MSG_CHANNEL_NOTICE, On
--   CHAT_MSG_CHANNEL_NOTICE_USER (a password on the channel), On CHANNEL_UI_UPDATE, On (loop over several events), login; fires COMMUNITY, DRIVERS
-- Standalone: no
-- Test: tests/net/inbox_test.lua
-- From: Net.lua 4479-4664 (Wuber 2.2.1)
--
---------------------------------------------------------------------------
-- Hearing messages
---------------------------------------------------------------------------

local _, W = ...
local Mod = W.Module("Net.Inbox", { "Net.Base", "Net.Community", "Net.Beacons", "Net.Requests", "Net.Rides", "Net.Favourites", "Net.Discovery" })
local BaseMod = W.Mod("Net.Base")
local CommunityMod = W.Mod("Net.Community")
local BeaconsMod = W.Mod("Net.Beacons")
local RequestsMod = W.Mod("Net.Requests")
local RidesMod = W.Mod("Net.Rides")
local FavouritesMod = W.Mod("Net.Favourites")
local DiscoveryMod = W.Mod("Net.Discovery")
local CHANNEL_KINDS, WHISPER_TOO, addFilters, address, fb = BaseMod.CHANNEL_KINDS, BaseMod.WHISPER_TOO, BaseMod.addFilters, BaseMod.address, BaseMod.fb
local hasChannels, hideChannel, isOurChannel, myKey, now = BaseMod.hasChannels, BaseMod.hideChannel, BaseMod.isOurChannel, BaseMod.myKey, BaseMod.now
local netHandler = BaseMod.netHandler
local CX, comm = CommunityMod.CX, CommunityMod.comm
local heardBeacon, heardPing, heardWhisperPing, impl, tickBeacon = BeaconsMod.heardBeacon, BeaconsMod.heardPing, BeaconsMod.heardWhisperPing, BeaconsMod.impl, BeaconsMod.tickBeacon
local heardCancel, heardRating, heardRequest, tickIncoming = RequestsMod.heardCancel, RequestsMod.heardRating, RequestsMod.heardRequest, RequestsMod.tickIncoming
local heardAccept, heardDecline, heardQueue, heardStage, restoreRide = RidesMod.heardAccept, RidesMod.heardDecline, RidesMod.heardQueue, RidesMod.heardStage, RidesMod.restoreRide
local db = FavouritesMod.db
local goodName, heardGossip, maybeGossip, rememberPeer, round = DiscoveryMod.goodName, DiscoveryMod.heardGossip, DiscoveryMod.maybeGossip, DiscoveryMod.rememberPeer, DiscoveryMod.round
local tickWhisper = DiscoveryMod.tickWhisper
local lastR = RequestsMod.lastR
local str = W.Str

W.On("CHAT_MSG_ADDON", function(prefix, text, chan, sender, _, _, localID, chanName)
	if str(prefix) ~= W.PREFIX then return end
	local addr = address(sender)
	local name = W.CleanName(addr)
	local key = W.Key(addr)
	chan = str(chan)
	if not (addr and name and key) then return end
	-- over the Wuber community's channel rather than WuberNet (counted apart: WuberNet's
	-- echo and "others heard" figures drive the whisper fallback's rejoin check)
	local viaComm = chan == "CHANNEL" and W.IsCommunityChannel(localID, chanName)
	if key == myKey() then -- our own echo
		if viaComm then
			comm.echoAt = now()
		elseif chan == "CHANNEL" then
			fb.echoAt = now()
		end
		return
	end
	local kind, proto, f = W.Decode(text)
	if not kind then return end
	if CHANNEL_KINDS[kind] then
		-- D, X, Q: over the channel, or by whisper from that driver / rider itself
		if chan ~= "CHANNEL" and not (chan == "WHISPER" and WHISPER_TOO[kind]) then return end
	elseif chan ~= "WHISPER" then
		return
	end
	if chan == "CHANNEL" then
		fb.chanHeard[key] = now()
		if viaComm then
			comm.othersAt = now()
			comm.heard = comm.heard + 1
		else
			fb.chanOthersAt = now()
		end
	end
	W.net.heard = W.net.heard + 1
	if kind == "D" then
		heardBeacon(addr, name, key, f, proto, chan, viaComm)
	elseif kind == "X" then
		if W.drivers[key] then
			W.drivers[key] = nil
			W.Fire("DRIVERS")
		end
		-- AUD-42: a hidden driver who signs off is gone too (Show all hidden drivers must not bring her back)
		if W.hiddenDrivers and W.hiddenDrivers[key] then W.hiddenDrivers[key] = nil end
	elseif kind == "Q" then
		-- 2.3.2: field 2 "0" hides a listed Pioneer's emblem (FX.Emblem; it can never give one)
		if W.EmblemHeard then W.Safe("emblem", W.EmblemHeard, key, f[2]) end
		if chan == "CHANNEL" then
			heardPing(viaComm)
		else
			if f[1] == "1" then fb.peerOnChanAt = now() end -- they hear others on the channel
			heardWhisperPing(addr, key)
		end
	elseif kind == "K" then
		heardGossip(key, f)
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
	elseif kind == "P" then
		heardQueue(key, f)
	elseif kind == "B" then
		-- a rider booked with another driver: no more answers or pushes to them
		fb.booked[key], fb.riders[key] = now(), nil
	elseif kind == "F" then
		CX.flyHeard(addr, key, f) -- shared flight prices (2.2.1)
	else
		-- a kind added by W.NetKind (2.3.0: G, V, W)
		local h = netHandler(kind)
		if h then h(addr, name, key, f, chan, viaComm, proto) end
	end
	if chan == "WHISPER" then
		-- a Wuber user who whispers us: a contact (asked now and then, for their K), and
		-- our K to them (at most once per 10 min)
		fb.offlineUntil[key] = nil
		local good = goodName(name)
		if good then rememberPeer(key, good, addr) end
		maybeGossip(addr, key, kind)
	end
	-- shared flight prices ride on the same exchanges (and on a 2.2.1 driver's beacon)
	if chan == "WHISPER" or (kind == "D" and W.drivers[key]) then W.Safe("flight share", CX.flyMaybe, addr, key) end
end)

-- A request by chat only ("WTB summon to Ratchet for 50s"): a rider whose account can't
-- send addon messages (trial or veteran accounts on Forever). Wuber's own driver mode lists
-- it like an R that came 2 s later; Ritual Rides takes chat requests itself. Not while a
-- provider is set, nor when an R from them came (it is the same request).
W.On("CHAT_MSG_WHISPER", function(text, sender)
	text, sender = str(text), address(sender)
	if not (text and sender) or impl() then return end
	local dest, price = text:match("^WTB summon to (.-) for (.+)$")
	if not dest then return end
	local key, name = W.Key(sender), W.CleanName(sender)
	if not key or not name or key == myKey() then return end
	W.After(2, function()
		local t = lastR[key]
		if t and now() - t < 30 then return end
		for _, r in ipairs(W.incoming) do
			if r.buyerKey == key then return end
		end
		local copper = W.ParseMoney(price)
		if not copper then return end
		heardRequest(sender, name, key, { W.NewRideId(), dest, tostring(math.floor(copper)), "0", "" }, true)
	end)
end)

-- A password on the hidden channel (not proven in game; the notice names are the documented ones). The owner clears it;
-- a refused join (WRONG_PASSWORD) makes the failed-join line the password one.
-- The game also tells the owner about its own change (clearing counts as one): a notice that names this character is
-- never answered, or clearing would answer itself for ever.
W.On("CHAT_MSG_CHANNEL_NOTICE_USER", function(kind, _, _, chanString, who, _, _, _, chanBase)
	if str(kind) == "PASSWORD_CHANGED" and (isOurChannel(chanString) or isOurChannel(chanBase)) then
		local by = str(who)
		if by and by ~= "" and W.Key(by) == W.Key(W.Me()) then return end
		BaseMod.channelPassword(false)
	end
end)

W.On("CHAT_MSG_CHANNEL_NOTICE", function(kind, _, _, chanString, _, _, _, _, chanBase)
	if isOurChannel(chanString) or isOurChannel(chanBase) then
		if str(kind) == "WRONG_PASSWORD" then BaseMod.channelPassword(true) end
		hideChannel()
		if W.loggedIn then W.CheckChannel(false) end
	end
end)

W.On("CHANNEL_UI_UPDATE", function()
	if W.loggedIn then W.CheckChannel(false) end
	if comm.state == "member" and comm.startAt and now() >= comm.startAt then W.CommunityCheck() end
end)

-- The community's own events (each skipped by a client that doesn't know it).
for _, event in ipairs({ "CLUB_ADDED", "CLUB_REMOVED", "CLUB_STREAMS_LOADED", "CLUB_STREAM_ADDED", "CLUB_STREAM_REMOVED",
	"INITIAL_CLUBS_LOADED", "CLUB_MEMBER_ROLE_UPDATED", "CLUB_INVITATION_ADDED_FOR_SELF", "CLUB_INVITATION_REMOVED_FOR_SELF" }) do
	W.On(event, function()
		if not W.loggedIn then return end
		if comm.startAt and now() >= comm.startAt then W.CommunityCheck() end
		W.Fire("COMMUNITY", comm.state) -- an invitation changes the Drive tab, not the state
	end)
end

---------------------------------------------------------------------------
-- Start-up and the clock
---------------------------------------------------------------------------

local ticks = 0
local function tick()
	ticks = ticks + 1
	W.Safe("beacon", tickBeacon)
	W.Safe("ride", W.CheckRide)
	W.Safe("requests", tickIncoming)
	W.Safe("whisper", tickWhisper)
	W.Safe("community invites", CX.tickInvites)
	local bounty = W.Mod("Net.Bounty") -- (2.3.0: the rider's re-sends and expiry, the demand's TTL)
	if bounty and bounty.tick then W.Safe("bounty", bounty.tick) end
	if ticks % 5 == 0 then W.Safe("drivers", W.ExpireDrivers) end
	if comm.startAt and now() >= comm.startAt and (comm.checkedAt == nil or now() - comm.checkedAt >= 30) then
		comm.checkedAt = now()
		W.Safe("community", W.CommunityCheck)
	end
end
W.NetTick = tick

W.OnLogin(function()
	local CI = C_ChatInfo
	if type(CI) == "table" and type(CI.RegisterAddonMessagePrefix) == "function" then
		pcall(CI.RegisterAddonMessagePrefix, W.PREFIX)
	end
	addFilters()
	round.loginAt = now()
	db().ruleset = W.Ruleset() -- for tools/build-seeds.js
	W.Safe("restore finished", W.RestoreFinished)
	local fxm = W.Mod("FX.Moments") -- (it loads later: its moments for the saved ride are marked seen first)
	if fxm and fxm.markRestored then W.Safe("restore moments", fxm.markRestored) end
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
	comm.startAt = now() + CX.START -- the community after WuberNet (see "The Wuber community")
	W.Every(1, tick)
end)
