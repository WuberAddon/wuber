-- PST-05: the straight-line travel model (W.TravelSaved, for a character whose flights are not yet
-- calibrated) flies at the same speed as Core/Flights.lua (W.FLY.SPEED), not a number of its own.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- seconds the straight-line model gives for a straight distance at a given speed (the code's rounding)
local function model(dist, speed)
	return math.floor(math.min(60 + dist * 1.35 / speed, 2400) + 0.5)
end

test("pst05 flyspeed: an uncalibrated straight-line estimate uses W.FLY.SPEED", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	local W = r.W
	ok(type(W.FLY) == "table" and type(W.FLY.SPEED) == "number", "W.FLY.SPEED exists")
	ok(not (W.db.flyCal and W.db.flyCal.n), "control: this character has no calibration")
	local p = w:player(T.TESTCHAR)
	local place
	for _, q in ipairs(W.PLACES) do if q.name == "Ratchet" then place = q end end
	local rc, rx, ry = W.WorldPos(p.mapID, p.x, p.y)
	local dc, dx, dy = W.PlaceWorld(place)
	eq(rc, dc, "control: same continent")
	local dist = math.sqrt((rx - dx) ^ 2 + (ry - dy) ^ 2)
	ok(dist > 400, "control: far enough to be told: " .. dist)
	local got = W.TravelSaved("Ratchet")
	eq(got, model(dist, W.FLY.SPEED), "seconds = 60 + dist x 1.35 / W.FLY.SPEED (speed " .. W.FLY.SPEED .. ")")
	W.FLY.SPEED = 20
	local slower = W.TravelSaved("Ratchet")
	eq(slower, model(dist, 20), "changing W.FLY.SPEED changes the estimate")
	ok(slower > got, "a slower bird takes longer: " .. tostring(slower) .. " vs " .. tostring(got))
	T.clean(w)
end)
