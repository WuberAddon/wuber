local T = ...
-- Round 32 group L (wave 2): HUNT-27: the Ride screen tells a rider in another group to leave it;
local test, eq, ok = T.test, T.eq, T.ok

local function has(c, text)
	for _, t in ipairs(c:visibleTexts()) do if t == text then return true end end
	return false
end

test("r32 l2: asked for a summon, then in another group: the Ride screen says Leave your group first", function()
	local w = T.newWorld()
	local d = T.driver(w, "Anita Lift")
	local r = T.rider(w)
	w:addBot("Sly Fox", { spot = "Orgrimmar" })
	T.settle(w)
	T.goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(0.5)
	ok(r.W.ride, "a ride")
	-- the rider is pulled into someone else's party before the driver's invite lands
	w:group({ "Wuber TestCharacter", "Sly Fox" })
	w:advance(0.5)
	r.W.ride.state = "accepted"
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.RefreshNow()
	ok(has(r, "Leave your group first"), "the button: " .. table.concat(r:visibleTexts(), " | "))
	T.clean(w)
end)

