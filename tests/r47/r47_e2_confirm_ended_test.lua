local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function world()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { netOnly = true })
	local r = T.rider(w, T.TESTCHAR, { money = 100000 })
	T.settle(w)
	T.goOnline(d)
	w:advance(8)
	return w, d, r
end

test("r47 e2: control: with no ride, Show('confirm', driver) opens the booking card", function()
	local w, d, r = world()
	local key
	for k, drv in pairs(r.W.drivers) do key = k end
	ok(key, "control: the rider sees a driver")
	r.W.UI.Show("confirm", key)
	w:advance(1)
	eq(r.W.UI.state.screen, "confirm", "control: the booking card opens")
	T.clean(w)
end)

test("r47 e2: after a cancelled ride (window closed), clicking a driver opens the old ride-end screen, not the booking card", function()
	local w, d, r = world()
	local key
	for k, drv in pairs(r.W.drivers) do key = k end
	ok(key, "control: the rider sees a driver")
	local ride = r.W.RequestRide("anita lift")
	w:advance(1)
	ok(ride, "control: a ride was requested")
	ok(r.W.CancelRide(), "control: the rider cancels")
	w:advance(2)
	ok(not r.W.UI.IsShown(), "control: the window was never opened / is closed")
	r.W.UI.Show("confirm", key) -- what a favourite toast click or a map pin does
	w:advance(1)
	local scr = r.W.UI.state.screen
	ok(scr == "confirm", "the player clicked a driver to book but the window opens on the '" .. tostring(scr) .. "' screen: " .. T.list(r:visibleTexts()):sub(1, 150))
	T.clean(w)
end)
