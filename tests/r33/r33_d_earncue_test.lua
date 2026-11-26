local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- HUNT-114: the "Scroll for more" pill on Earnings is never drawn above the Settings page (the panel sits at the window's level + 40).

test("r33 d: the Earnings cue pill is under the Settings panel, not floating over it", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	W.Drive.Heatmap = function()
		return { { wday = 3, hour = 20, copper = 29000, rides = 5, open = 60, asks = 6 } }
	end
	W.UI.WindowWide(false)
	T.openDrive(a)
	W.UI.ShowDrive("earnings")
	w:advance(1)
	local e = W.UI.drive.screens.earnings
	ok(e.cue and e.cue:IsVisible(), "control: the pill shows with more below")
	W.UI.OpenSettings()
	w:advance(1)
	ok(W.UI.SettingsShown(), "Settings is open")
	ok(not e.cue:IsVisible(), "the pill is not drawn over the Settings page")
	W.UI.CloseSettings(true)
	w:advance(2)
	ok(e.cue:IsVisible(), "and it is back when Settings closes")
	T.clean(w)
end)
