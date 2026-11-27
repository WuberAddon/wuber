local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- HUNT-109: opening Settings over the Trips tab never leaves the "Scroll for your trips" pill above the
-- Settings page: the pill's frame level stays under the Settings panel's.

test("r32 o: the Trips cue pill is under the Settings panel, not floating over it", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local W = r.W
	W.UI.Toggle(true)
	w:advance(1)
	W.UI.SelectTab("Trips")
	w:advance(1)
	local M = W.Mod("UI.Rider.Trips")
	local tr = M.view()
	W.UI.UpdateTrips()
	tr.clip.GetHeight = function() return 340 end
	tr.scrollMax = math.max(0, tr.height - 340)
	tr.scroll, tr.scrollTarget = 0, 0
	M.trimCells()
	ok(tr.cue:IsShown(), "control: the pill shows with more below")
	W.UI.OpenSettings = W.UI.OpenSettings
	local panel = W.Mod("UI.Settings.Rows").st.panel
	ok(panel, "the Settings panel is found")
	local pl = panel:GetFrameLevel()
	local cl = tr.cue:GetFrameLevel()
	ok(cl < pl, "cue level " .. tostring(cl) .. " is under the Settings panel's " .. tostring(pl))
end)
