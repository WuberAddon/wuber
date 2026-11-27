-- Round 32 group F, wave 2 (f2): REV-r28-2 Help > Show a tip before the first-open guide has run shows the tip;
-- the guide waits for a later look (it never shows together with the tip card).
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

test("r32 f2: REV-r28-2 Help's Show a tip before the first-open guide has run: the tip now, the guide later", function()
	local w = T.newWorld()
	local _, W, Mod, ui = login(w, { Wuber = {} })
	local shown, why = W.Mod("UI.Settings.Panel").showTip()
	w:advance(3)
	eq(shown, true, "Show a tip says it showed")
	eq(why, nil, "no reason given")
	ok(cardUp(Mod), "the tip card shows")
	ok(not ui.coaching, "the first-open guide is not up at the same time")
	ok(not (ui.coach and H.visible(ui.coach)), "no guide bubble on screen")
	-- the tip closed: the guide comes on the next look at Home (a closed and reopened phone)
	Mod.Hide()
	W.UI.Toggle(false)
	w:advance(1)
	W.UI.Toggle(true)
	w:advance(5)
	ok(ui.coaching == true, "the guide starts on the next open")
	ok(not cardUp(Mod), "and no tip card with it")
	T.clean(w)
end)
