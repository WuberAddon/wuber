local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- Round 33, group b6 (AUD-114, AUD-116): the ride screen's spinner turns again after a peek at Home;
-- the Share pill stays away from the stranger's-trade card.


test("r33 b6 (AUD-114): back on the waiting ride screen after a peek at Home, the spinner is frozen", function()
	local w = T.newWorld()
	local d = T.driver(w, "Anita Lift")
	local r = T.rider(w)
	T.settle(w)
	T.goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(0.5)
	r.W.ride.state = "accepted"
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.RefreshNow()
	local WinMod = r.W.Mod("UI.Window")
	local s = WinMod.screens.found
	ok(s and s.spin, "found screen spin")
	ok(s.spin:IsShown(), "control: the waiting spinner shows")
	local a0 = s.spin:GetRotation()
	w:advance(0.3)
	ok(s.spin:GetRotation() ~= a0, "control: the spinner turns while the ride screen is up")
	-- peek at Home, then come back
	r.W.UI.Show("home")
	w:advance(1)
	r.W.UI.state.peek = nil -- the way back to the ride (Window.lua, HomeMap.lua)
	r.W.UI.Show("found")
	w:advance(1)
	r.W.UI.RefreshNow()
	w:advance(1)
	ok(s.spin:IsShown(), "spinner is shown on return")
	local b0 = s.spin:GetRotation()
	w:advance(0.4)
	ok(s.spin:GetRotation() ~= b0, "the 'waiting' spinner on the ride screen sits motionless after a peek at Home and back")
	T.clean(w)
end)


test("r33 b6 (AUD-116): a grouped rider's Share pill sits on top of the 'isn't your driver' warning", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local MIA = "Mia Fox"
	r.W.ride = { id = "r7", driver = MIA, driverKey = MIA:lower(), dest = "Undercity", price = 5000, state = "arrived",
		at = r.env.GetTime(), payee = MIA, payto = "Mia", service = "Mia's Rides", flightCost = 2300, flightExact = 1 }
	r.W.Fire("RIDE")
	w:addBot("Sly Fox", { spot = "Orgrimmar" })
	w:addBot("Mia Fox", { spot = "Orgrimmar" })
	w:group({ "Wuber TestCharacter", "Mia Fox" })
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.Show("found")
	w:advance(2)
	r.W.UI.Refresh(true)
	w:advance(1)
	local s = r.W.UI.state.screens.found
	-- control: with no stranger the Share pill shows (grouped, paying)
	ok(H.visible(s.share), "control: the Share pill shows while grouped on the pay screen")
	H.state[r.env.TradeFrame].shown = true
	w:openTrade(w:player("Sly Fox"), r.player)
	w:advance(1)
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(H.visible(s.alert) and #r:findText("isn't your driver", false, true) > 0, "the stranger card is up")
	local a, b = H.rect(s.alert), H.rect(s.share)
	local over = H.visible(s.share) and a.l < b.l + b.w and b.l < a.l + a.w and a.b < b.b + b.h and b.b < a.b + a.h
	ok(not over, "the Share pill is drawn over the amber 'not your driver' card")
	T.clean(w)
end)
