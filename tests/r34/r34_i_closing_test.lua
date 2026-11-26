local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local MIA = "Mia Runner"
test("r34 i: the secure Request button reappears over the window while it is closing", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	r.W.FlightCost = function() return 2300, 1 end
	r.W.TravelSaved = function() return 300 end
	r.W.drivers = r.W.drivers or {}
	r.W.drivers[key(MIA)] = { name = MIA, key = key(MIA), dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = r.env.GetTime() }
	local UI = r.W.UI
	UI.Toggle(true) w:advance(3)
	UI.Show("confirm", key(MIA)) w:advance(1.5)
	ok(H.visible(r.env.WuberRequestButton), "control: the Request button is over its pill while open")
	UI.Toggle(false)
	ok(not H.visible(r.env.WuberRequestButton), "control: closing hides it at once")
	ok(UI.state.closing, "the window is mid close animation")
	UI.Refresh(true)
	w:advance(0.06)
	ok(UI.state.closing, "still closing")
	ok(not H.visible(r.env.WuberRequestButton), "the Request button was put back over the shrinking window by a refresh during the close animation")
	T.clean(w)
end)