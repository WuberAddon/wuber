local T = ...
do
local test, eq, ok = T.test, T.eq, T.ok

-- the rider (in Tarren Mill) on the booking card for Mia Runner (to Undercity)
local function booking()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Tarren Mill" })
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Undercity", price = 5000, state = "open",
		team = 3, queue = 0, service = "Mia's Rides", heard = r.env.GetTime() }
	W.UI.Toggle(true)
	w:advance(3)
	W.UI.Show("confirm", "mia runner")
	w:advance(1.5)
	return w, r, W.UI.state.screens.confirm
end

local function walk(event)
	local w, r, s = booking()
	local before = s.route.fromText
	ok(s.route:IsVisible(), "setup: the route header shows")
	-- the rider hearths / is portalled to Orgrimmar; only the one event the game sends
	w:placePlayer(w:player(T.TESTCHAR), "Orgrimmar")
	r:fire(event)
	w:advance(0.5)
	local after = s.route.fromText
	T.clean(w)
	return before, after, r.W.Mod("UI.Rider.Booking").RouteFrom()
end

test("r47 o5: the route header follows the rider on ZONE_CHANGED (control)", function()
	local before, after, now = walk("ZONE_CHANGED")
	ok(before ~= now, "setup: the origin really changed (" .. tostring(before) .. " to " .. tostring(now) .. ")")
	eq(after, now, "control: after ZONE_CHANGED the header says where the rider is")
end)

test("r47 o5: the route header follows the rider into a new zone (ZONE_CHANGED_NEW_AREA)", function()
	local before, after, now = walk("ZONE_CHANGED_NEW_AREA")
	eq(after, now, "the rider stands in " .. tostring(now) .. " but the open booking card's route header still starts at " .. tostring(after))
end)

test("r47 o5: the route header follows the rider indoors (ZONE_CHANGED_INDOORS)", function()
	local before, after, now = walk("ZONE_CHANGED_INDOORS")
	eq(after, now, "the rider stands in " .. tostring(now) .. " but the open booking card's route header still starts at " .. tostring(after))
end)

end
do
local test, eq, ok = T.test, T.eq, T.ok

test("r47 o5: a summon that costs exactly the flight says (saves 0)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local B = r.W.Mod("UI.Rider.Booking")
	local function summonText(fare)
		local d = B.Dial(r.env.UIParent, 324, 88)
		d:SetPoint("CENTER", r.env.UIParent, "CENTER", 0, 0)
		d:SetSize(324, 88)
		d:Set({ dest = "Thunder Bluff", flySecs = 900, flyAbout = true, flightCost = 500, fare = fare, wait = nil, waitKnown = false, timeSaved = 870 })
		return d.summonText:GetText() or ""
	end
	ok(summonText(200):find("saves", 1, true), "control: a summon cheaper than the flight says what it saves: " .. summonText(200))
	ok(summonText(900):find("net", 1, true), "control: a dearer one says the net: " .. summonText(900))
	local same = summonText(500)
	ok(not same:find("saves", 1, true), "the summon side reads '" .. same .. "': it costs exactly what the flight costs, yet says it saves nothing")
	T.clean(w)
end)

end
do
local test, eq, ok = T.test, T.eq, T.ok

local function head(spot, pos)
	local w = T.newWorld()
	local r = T.rider(w, "Anita Lift", { spot = "Stormwind", faction = "Alliance" })
	T.settle(w)
	local W = r.W
	local B = W.Mod("UI.Rider.Booking")
	if not pos then W.MyPosition = function() return nil end end -- indoors / on a boat: no map position
	local ts, how = W.TravelSaved("Ratchet")
	local info = B.DialInfo({ dest = "Ratchet", queue = 0 }, 0)
	return w, info, ts, how
end

test("r47 o5: Stormwind to Ratchet by boat: the Fly side says so even when the rider has no map position", function()
	local w, info, ts, how = head("Stormwind", true)
	eq(info and info.crossing, "boat", "control: standing outdoors the card says boat")
	eq(info and info.flyHead, "Fly + boat", "control: head")
	local w2, info2, ts2, how2 = head("Stormwind", false)
	ok(info2 and info2.flightCost, "setup: the flight price is still known (" .. tostring(info2 and info2.flightCost) .. ", TravelSaved " .. tostring(ts2) .. "/" .. tostring(how2) .. ")")
	eq(info2 and info2.flyHead, "Fly + boat", "with no map position for the rider the Fly side reads '" .. tostring(info2 and info2.flyHead)
		.. "' for a Stormwind to Ratchet trip that takes a boat")
	T.clean(w) T.clean(w2)
end)

end
