local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local clean = T.clean
local MIA = "Mia Runner"

-- HUNT-100: the driver status chip on Home (open as a driver, others listed) never cuts its line short.
test("r33 f5: HUNT-100: the open-as-driver chip shows the whole line at the highest price and a long place", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.drivers = { ["mia runner"] = { name = MIA, key = "mia runner", dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = r.env.GetTime(), queue = 0, ver = "2.3.0" } }
	W.db.fold = { v = 1, pages = {}, narrow = true }
	W.Bounty = { Mine = function() return nil end, Demand = function() return {} end }
	W.db.rides = {}
	W.DriverBeacon = function() return { dest = "Ironforge", destShown = "The Undercity Apothecarium", price = 999999,
		state = "paused", service = "A", team = 1, seats = 0, queue = 0 } end
	W.UI.Toggle(true)
	w:advance(3)
	W.UI.Show("home")
	w:advance(1.5)
	local s = W.UI.state.screens.home
	local chip = s.ownChip
	ok(H.visible(chip), "the chip is up")
	local txt = chip.text
	ok(txt.wuberText:find("999999", 1, true) or txt.wuberText:find("99g", 1, true), "full text set: " .. tostring(txt.wuberText))
	ok(txt.IsTruncated == nil or txt:IsTruncated() ~= true, "the line is not cut short")
	ok(txt.wuberWrapped == true or (txt.wuberPx or 0) >= 9, "it wrapped or shrank")
	if txt.wuberWrapped then
		ok(chip:GetHeight() > 28, "a wrapped line gets a taller chip: " .. tostring(chip:GetHeight()))
	end
	clean(w)
end)
