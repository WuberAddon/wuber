local T = ...
local test, ok, eq = T.test, T.ok, T.eq
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
test("r32 k2: Ride here on the map opens that place's drivers when the last ride's Done screen is still up", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	local MIA = "Mia Runner"
	r.W.ride = { id = "r32k2", driver = MIA, driverKey = key(MIA), dest = "Undercity", price = 5000, state = "done",
		at = r.env.GetTime(), payee = "Bea Jones", payto = "Bea", summoner = "Bea Jones", service = "Mia's Rides" }
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(3)
	ok(#r:findText("Where to?") == 0, "starts on the Done screen, not Home")
	r.W.Map.BookPlace({ name = "Orgrimmar" })
	w:advance(2)
	local shown = r.env.WuberFrame and r.env.WuberFrame:IsShown()
	ok(shown, "the window is open")
	ok(#r:findText("Where to?") > 0, "Home (Where to?) shows, not the old Done screen")
	T.clean(w)
end)
