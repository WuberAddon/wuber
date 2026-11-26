-- Round 30, group K (HUNT-87): on the narrow Raid summons screen the "Not here (0) below" pill is not shown
-- while the "Raid summons are stopped" message is up: it would point at an empty section and sit on the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("r30 k: no Not here (0) pill over the Raid summons are stopped message (narrow)", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	W.Drive.Shards = function() return 10 end
	if W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	W.Drive.SetMode("raid")
	w:advance(2)
	local D = W.Driver
	for _ = 1, 4 do
		D.RefreshNow()
		w:advance(1)
	end
	local R = D.ui.console.raid
	ok(R and R.empty and R.empty:IsShown(), "the stopped message is up")
	eq(R.empty.text.wuberText, "Raid summons are stopped", "message text kept")
	local nh = R.cueItems and R.cueItems.nh
	local shown = R.cue and R.cue:IsShown()
	ok(not shown, "no pill: " .. tostring(R.cue and R.cue.text) .. " nh=" .. tostring(nh))
	T.clean(w)
end)
