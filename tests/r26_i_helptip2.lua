-- Round 26 I: Help's "Show a tip" with the real UI.Tips: the card shows on the Ride tab (Settings closed);
-- with a ride active, the button prints why and no card shows.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function open()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = true } } })
	w:advance(15)
	return w, r.W
end

test("r26 I: Help > Show a tip shows the tip card on the Ride tab, Settings closed", function()
	local w, W = open()
	local ui = W.Mod("UI.Kit").ui
	W.UI.Toggle(true)
	w:advance(5)
	W.UI.OpenHelp("settings")
	w:advance(1)
	local btn = W.UI.settings.help.tip
	btn:GetScript("OnClick")(btn)
	w:advance(5)
	local card = W.Mod("UI.Tips").Card()
	ok(card and H.visible(card), "the tip card shows")
	eq(ui.tab, "Ride"); eq(ui.screen, "home")
	ok(not ui.settingsOpen, "Settings closed")
end)

test("r26 I: with a ride active the button says why and no card shows", function()
	local w, W = open()
	W.UI.Toggle(true)
	w:advance(5)
	W.ride = { id = "gJBrSi", state = "BOOKED", driver = "anita lift", driverKey = "anita lift", dest = "Orgrimmar", price = 5000 }
	W.UI.OpenHelp("settings")
	w:advance(1)
	local lines = {}
	local orig = W.Print
	W.Print = function(t) lines[#lines + 1] = tostring(t) end
	local btn = W.UI.settings.help.tip
	btn:GetScript("OnClick")(btn)
	W.Print = orig
	local card = W.Mod("UI.Tips").Card()
	ok(not (card and H.visible(card)), "no card")
	eq(lines[1], "No tip now: try again after your ride.")
	local a, why = W.Mod("UI.Settings.Panel").showTip()
	eq(a, false); eq(why, "ride")
end)
