-- A stand-in for an old driver addon that is still installed next to Wuber.
-- Written for the tests; it holds only what Wuber looks at: the global "RitualRides" table that
-- Wuber's lock reads (DR.Lock), a driver registered through the public WuberAPI.SetDriver,
-- and saved data in RitualRidesDB (which Wuber imports). Nothing here comes from the real addon.
local _, SI = ...
SI.VERSION = "1.4.1"
RitualRides = SI

-- the settings a test changes (all plain fields)
SI.cfg = { open = true, lead = true, dest = "Ratchet", price = 50000, team = 3, seats = 3, max = nil }
SI.blocked = {} -- buyerKey -> true
SI.customers = {} -- ride id -> ride
SI.queue = {} -- rides waiting for a place
SI.ratings = {} -- { id, buyer, stars }
SI.cancels = {} -- ride ids

local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
SI.count = count

-- the beacon: named keys only; nil when this window does not beacon (a team's other windows)
function SI.beacon()
	local c = SI.cfg
	if not c.open or not c.lead then return nil end
	return { dest = c.dest, price = c.price, state = "open", team = c.team, seats = c.seats }
end

function SI.onRequest(ride)
	local c = SI.cfg
	if not c.open then return WuberAPI.Decline(ride.id, ride.buyer, "closed") end
	if SI.blocked[ride.buyerKey] then return WuberAPI.Decline(ride.id, ride.buyer, "blocked") end
	if (tonumber(ride.price) or 0) < c.price then return WuberAPI.Decline(ride.id, ride.buyer, "price") end
	if c.max and count(SI.customers) >= c.max then
		SI.queue[#SI.queue + 1] = ride
		return WuberAPI.Queue(ride.id, ride.buyer, #SI.queue, 60)
	end
	SI.customers[ride.id] = ride
	return WuberAPI.Accept(ride.id, ride.buyer, 5, ride.price)
end

function SI.onCancel(id)
	SI.customers[id] = nil
	SI.cancels[#SI.cancels + 1] = id
end

function SI.onRating(id, buyer, stars)
	SI.ratings[#SI.ratings + 1] = { id = id, buyer = buyer, stars = stars }
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	if type(WuberAPI) == "table" then
		WuberAPI.SetDriver({ name = "Ritual Rides", beacon = SI.beacon, onRequest = SI.onRequest, onCancel = SI.onCancel, onRating = SI.onRating })
	end
end)
