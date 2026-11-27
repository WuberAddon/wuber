local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- HUNT-33: a rider booked before PvP danger starts sees "Hot drop" from the driver's beacon (D field
-- 18) even when the live tracker's last phase message said no danger.

local ANA = "Ana Smith"
local KEY = "ana smith"

local function setup(ritual, beacon)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	local t0 = r.env.GetTime()
	r.W.drivers = r.W.drivers or {}
	local d = { name = ANA, key = KEY, dest = "Ratchet", price = 5000, state = "open", team = 3,
		service = "Ana's Rides", heard = t0, queue = 1, ver = "2.3.0" }
	for k, v in pairs(beacon or {}) do d[k] = v end
	r.W.drivers[KEY] = d
	r.W.ride = { id = "r32l3", driver = ANA, driverKey = KEY, dest = "Ratchet", price = 5000, state = "accepted",
		at = t0, position = 1, eta = 50, ritual = ritual }
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(3)
	return w, r, r.W.UI.state.screens.found
end

test("r32 l3: tracker said no danger, the driver's beacon says a fight -> Hot drop", function()
	local w, r, s = setup({ phase = "q", danger = 0, need = 2 }, { danger = 2, dangerSecs = 120 })
	ok(s.alertHead and H.visible(s.alert), "the warning card is up")
	eq(s.alert.head.wuberText, "Hot drop", "its head")
	ok(tostring(s.alert.body and s.alert.body.wuberText):find("fought enemy players", 1, true), "the beacon's fight words")
	T.clean(w)
end)

test("r32 l3: danger starts after booking: the beacon's level shows without a new phase message", function()
	local w, r, s = setup({ phase = "q", danger = 0, need = 2 }, { danger = 0 })
	ok(not s.alertHead, "control: no danger, no card")
	r.W.drivers[KEY].danger, r.W.drivers[KEY].dangerSecs = 1, 10
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(s.alertHead and H.visible(s.alert), "the card is up from the beacon")
	eq(s.alert.head.wuberText, "Hot drop", "its head")
	T.clean(w)
end)

test("r32 l3: the tracker's level still shows when the beacon has none", function()
	local w, r, s = setup({ phase = "c", danger = 2, need = 2 }, { danger = 0 })
	ok(s.alertHead and H.visible(s.alert), "the card is up from the tracker")
	eq(s.alert.head.wuberText, "Hot drop", "its head")
	T.clean(w)
end)
