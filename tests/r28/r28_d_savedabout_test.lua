local T = ...
local test, ok = T.test, T.ok

local function done(how)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local A = "Mia Rides"
	r.W.ride = { id = "t62", driver = "Mia", driverKey = "mia", dest = "Undercity", price = 5000, state = "done",
		at = r.env.GetTime(), payee = "Mia", payto = "Mia", service = "Mia's Rides", paid = 5000,
		saved = 840, savedHow = how }
	r.W.db.tipPct = 20
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true) w:advance(2)
	r.W.UI.Show("done") w:advance(3)
	return w, r
end

test("r28 AUD-27: the Done screen says 'You saved about 14 min of flying' for a worked-out saving, plain for a timed one", function()
	-- control: a measured flight (own) may state the time plainly
	local w1, r1 = done("own")
	ok(#r1.findText(r1, "You saved 14 min of flying", false, true) > 0, "control: measured saving shown: " .. T.list(r1:visibleTexts()):sub(1, 300))
	T.clean(w1)
	-- the bug: an estimate (savedHow = "same continent") must say about
	local w, r = done("same continent")
	local shown = T.list(r:visibleTexts())
	ok(#r:findText("about 14 min", false, true) > 0 or #r:findText("About 14 min", false, true) > 0,
		"the Done screen reads 'You saved 14 min of flying' for an ESTIMATED saving, no 'about' (Trips and the share line say about): " .. shown:sub(1, 300))
	T.clean(w)
end)
