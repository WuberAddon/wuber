-- Run 1, item 10 (updated E1-03): on the live ride page with the portal up, the you dot does not pulse and the whole map strip
-- is hidden altogether (its picture, shade, pins, route and the you dot).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- the alpha a frame is drawn with: its own times each parent's
local function drawn(f)
	local a = 1
	while f do
		a = a * (f:GetAlpha() or 1)
		f = f:GetParent()
	end
	return a
end

local function portalRide(w, r)
	r.W.ride = { id = "r1n", driver = "Mia Runner", driverKey = "mia runner", dest = "Rut",
		price = 5000, state = "portal", at = r.env.GetTime(), payee = "Mia Runner", payto = "Mia", service = "Mia's Rides" }
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.Show("found")
	w:advance(3)
	return r.W.UI.state.screens.found
end

test("run1 n: portal up: the you dot is hidden, not pulsing, and the whole map strip is hidden", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local s = portalRide(w, r)
	ok(s.hero.art:IsShown(), "the portal picture is up")
	ok(not s.map.me.pulse.running, "the dot is not pulsing")
	eq(s.map.me:GetAlpha(), 0, "the dot is hidden")
	ok(drawn(s.map.me) < 0.05, "the dot is not drawn")
	eq(s.map.hero:GetAlpha(), 0, "the strip's picture is hidden")
	eq(s.map.canvas:GetAlpha(), 0, "the map art is hidden")
	eq(s.map.shade:GetAlpha(), 0, "the strip's shade is hidden")
	for _, ch in ipairs({ s.map.dots:GetChildren() }) do
		eq(ch:GetAlpha(), 0, "every child of the strip's dots frame is hidden")
	end
	T.clean(w)
end)

test("run1 n: the strip comes back when the portal goes", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local s = portalRide(w, r)
	eq(s.map.canvas:GetAlpha(), 0, "hidden while the portal is up")
	r.W.ride.state = "arrived"
	r.W.Fire("RIDE")
	w:advance(3)
	eq(s.map.canvas:GetAlpha(), 1, "the map art is back")
	eq(s.map.hero:GetAlpha(), 1, "the strip's picture is back")
	eq(s.map.shade:GetAlpha(), 1, "the shade is back")
	T.clean(w)
end)

test("e1-03: live ride page hides m.me and its pulse rings while Home map keeps them", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local s = portalRide(w, r)
	ok(s.hero.art:IsShown(), "setup: portal picture is up on live ride page")
	ok(not s.map.me.pulse.running, "m.me pulse is stopped on live ride page")
	ok(drawn(s.map.me) < 0.05, "m.me is hidden on live ride page")
	for _, ring in ipairs(s.map.me.pulse.rings) do
		ok(drawn(ring) < 0.05, "m.me pulse ring is hidden on live ride page")
	end
	r.W.UI.Show("home")
	w:advance(1)
	local home = r.W.UI.state.screens.home
	ok(home and home.map and home.map.me, "home screen has map and m.me")
	ok(home.map.me:IsShown() and drawn(home.map.me) > 0.9, "m.me is shown on Home map")
	ok(home.map.me.pulse.running, "m.me pulse is running on Home map")
	T.clean(w)
end)
