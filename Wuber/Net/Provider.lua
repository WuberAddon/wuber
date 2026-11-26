-- Module: Net.Provider
-- Purpose: WuberAPI, the public API for driver addons.
-- API: WuberAPI, W.API, WuberAPI.version, WuberAPI.Driving, WuberAPI.SetDriver,
--   WuberAPI.Accept, WuberAPI.Decline, WuberAPI.Status, WuberAPI.Beacon, WuberAPI.Drivers,
--   WuberAPI.IsOnNetwork, WuberAPI.Queue
-- Internals: (none)
-- Uses: Net.Base
-- Later: (none)
-- Events: listens (none); fires PROVIDER
-- Standalone: no
-- Test: tests/net/provider_test.lua
-- From: Net.lua 4665-4745 (Wuber 2.2.1)
--
---------------------------------------------------------------------------
-- WuberAPI: for driver addons
---------------------------------------------------------------------------

-- Wraps fn so a call from another addon never raises an error (it returns nil instead).
local _, W = ...
local Mod = W.Module("Net.Provider", { "Net.Base" })
local BaseMod = W.Mod("Net.Base")
local copy = BaseMod.copy

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

-- The API's version: 2 adds WuberAPI.Queue and the beacon's badge and queue keys; 3 adds
-- WuberAPI.Driving().
WuberAPI.version = 3

-- Who drives for this client: "provider" (another addon), "engine" (Wuber's own) or nil.
WuberAPI.Driving = guarded("Driving", function()
	if type(W.provider) == "table" then return "provider" end
	if type(W.engine) == "table" then return "engine" end
	return nil
end)

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

-- Tells the buyer their place in the queue (position 1 = next, eta seconds): whispers P,
-- only when the position changed since the last for that ride. (API version 2.)
WuberAPI.Queue = guarded("Queue", function(id, buyer, position, eta)
	return W.SendQueue(id, position, eta, buyer)
end)
