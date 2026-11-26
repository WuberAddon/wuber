local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local MIA = "Mia Runner"

local function riderWorld()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local t0 = r.env.GetTime()
	r.W.drivers = r.W.drivers or {}
	r.W.drivers["mia runner"] = { name = MIA, key = "mia runner", dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = t0, queue = 0, ver = "2.3.0" }
	r.W.db.fold = { v = 1, pages = {}, narrow = true }
	return w, r
end

test("r34 n: a trade that opened and closed in combat does not cancel the arrival open after combat", function()
	local w, r = riderWorld()
	w:enterCombat(r)
	-- a ride that is on its way (due), a trade opens in combat and closes again
	r.W.ride = { id = "r34n", driver = MIA, driverKey = "mia runner", dest = "Undercity", price = 5000, state = "arrived",
		at = r.env.GetTime(), payee = MIA, payto = "Mia", service = "Mia's Rides" }
	local realName = r.W.UnitName
	r.W.UnitName = function() return MIA end -- the driver's trade is open
	r.W.UI.OpenForPay("trade")
	r.W.UnitName = realName -- and closed again
	print("PARTNER", tostring(p), tostring(who), tostring(r.W.UI.OpenForPay("trade")))
	-- the ride arrives, still in combat
	r.W.ride.state = "arrived"
	r.W.UI.OpenForPay("arrived")
	w:advance(1)
	ok(r.W.UI.IsShown() ~= true, "not open in combat")
	w:leaveCombat(r)
	w:advance(1.5)
	ok(r.W.UI.IsShown() == true, "the pay screen opens after combat")
	eq(#w.errors, 0, "no errors")
	T.clean(w)
end)
