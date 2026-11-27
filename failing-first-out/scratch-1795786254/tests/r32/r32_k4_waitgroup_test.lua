local T = ...
-- Round 32 group K (wave 3): HUNT-27 follow-up: the "Waiting for <driver> to accept..." screen tells a rider
-- who is in another group to leave it (it asked the never-set ride.grouped, so the line never showed).
local test, ok = T.test, T.ok

local function has(c, text)
	for _, t in ipairs(c:visibleTexts()) do if t == text then return true end end
	return false
end

test("r32 k4: waiting for the driver to accept, in another group: the screen says to leave it", function()
	local w = T.newWorld()
	local d = T.driver(w, "Anita Lift")
	local r = T.rider(w)
	w:addBot("Sly Fox", { spot = "Orgrimmar" })
	T.settle(w)
	T.goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(0.5)
	ok(r.W.ride, "a ride")
	w:group({ "Wuber TestCharacter", "Sly Fox" })
	w:advance(0.5)
	r.W.ride.state = "requesting"
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.RefreshNow()
	local all = table.concat(r:visibleTexts(), " | ")
	ok(all:find("Waiting for", 1, true), "the waiting screen: " .. all)
	ok(all:find("You're in a group. Leave it so", 1, true), "the group line: " .. all)
	T.clean(w)
end)
