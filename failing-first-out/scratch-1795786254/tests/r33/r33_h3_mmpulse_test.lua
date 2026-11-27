local T = ...
-- r33 h3 HUNT-46: the minimap button pulses while the summon is up and the window is shut,
-- also after the player opened the window and closed it again.
local test, ok = T.test, T.ok
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function setup()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	local MIA = "Mia Runner"
	r.W.ride = { id = "r33h3", driver = MIA, driverKey = key(MIA), dest = "Undercity", price = 5000, state = "portal",
		at = r.env.GetTime(), payee = "Bea Jones", payto = "Bea", summoner = "Bea Jones", service = "Mia's Rides" }
	r.W.Fire("RIDE")
	w:advance(1)
	return w, r
end
test("r33 h3: HUNT-46: the minimap button pulses while the summon is up and the window is shut", function()
	local w, r = setup()
	local m = r.env.WuberMinimapButton
	ok(m and m.pulse, "minimap button with a pulse")
	ok(m.pulse.running, "pulses with the window shut")
	T.clean(w)
end)
test("r33 h3: HUNT-46: after opening and closing the window the button pulses again", function()
	local w, r = setup()
	local m = r.env.WuberMinimapButton
	r.W.UI.Toggle(true) w:advance(1)
	ok(not m.pulse.running, "no pulse while the window is open")
	r.W.UI.Toggle(false) w:advance(2)
	ok(not r.W.UI.IsShown(), "window closed")
	ok(m.pulse.running, "pulses again once the window is closed")
	T.clean(w)
end)
