-- Round 32 group F, wave 2 (f2): the login tip and the first-open guide wait their turn.
-- HUNT-13: a first open on a booking screen (a driver pin, a toast, Skip the bird) stays there; the tip waits
-- for the next time Home shows (the move from the Drive tab stays, round 26).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local MIA = "mia runner"

local function login(w, saved)
	local c = T.rider(w, T.TESTCHAR, { saved = saved or { Wuber = { coach = true } } })
	w:advance(15)
	local W = c.W
	W.drivers = W.drivers or {}
	W.drivers[MIA] = { name = "Mia Runner", key = MIA, dest = "Ratchet", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = c.env.GetTime() }
	return c, W, W.Mod("UI.Tips"), W.Mod("UI.Kit").ui
end

local function cardUp(Mod)
	local c = Mod.Card()
	return c and H.visible(c) and true or false
end

test("r32 f2: HUNT-13 a first open on a driver's booking screen stays there; the tip shows when Home does", function()
	local w = T.newWorld()
	local _, W, Mod, ui = login(w)
	eq(Mod.state.armed, true, "a login tip is due")
	W.UI.Show("confirm", MIA) -- a driver pin on the world map, a toast, the Skip the bird card
	w:advance(5)
	eq(ui.tab, "Ride", "on the Ride tab")
	eq(ui.screen, "confirm", "still on the booking screen: " .. tostring(ui.screen))
	ok(not cardUp(Mod), "no tip card over the booking screen")
	eq(Mod.state.armed, true, "the tip still waits")
	W.UI.Show("home")
	w:advance(2)
	eq(ui.screen, "home", "back on Home")
	ok(cardUp(Mod), "the tip shows the next time Home does")
	T.clean(w)
end)

test("r32 f2: HUNT-13 control: a first open on the Drive tab still moves to Home for the tip", function()
	local w = T.newWorld()
	local _, W, Mod, ui = login(w)
	W.UI.Toggle(true)
	W.UI.SelectTab("Drive")
	w:advance(5)
	ok(cardUp(Mod), "the tip shows")
	eq(ui.tab, "Ride", "moved to the Ride tab")
	eq(ui.screen, "home", "on Home")
	T.clean(w)
end)
