-- Round 33, group E (HUNT-115): the raid console's "Not here (n) below" pill is never drawn above Settings
-- or an open sheet (their level is the window's + 40), yet stays above the raid list rows.
local T = ...
local H, test, ok = T.H, T.test, T.ok

test("r33 e: the raid cue pill is under the Settings panel but over the raid rows", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.Shards = function() return 10 end
	if W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	W.Drive.SetMode("raid")
	w:advance(2)
	DR.Role = function() return "driver" end
	DR.IsOpen = function() return true end
	DR.CanRunRaid = function() return true end
	local names = { "Dan Rider", "Gus Hill", "Ivy Moss", "Jo King", "Kim Lane", "Lou Park" }
	DR.RaidQueue = function()
		local q = {}
		for i = 1, 6 do q[i] = { name = names[i], asked = a.env.GetTime() - 10 * i, state = "queued", tries = 0 } end
		return q
	end
	DR.NotHere = function() return { { name = "Fay Storm", class = "PRIEST", zone = "Orgrimmar" }, "Hal Stone" } end
	W.Driver.RefreshNow()
	w:advance(2)
	local v = W.Driver.ui.console
	local R = v.raid
	ok(R.cue and H.visible(R.cue), "control: the cue shows")
	W.UI.OpenSettings()
	w:advance(1)
	local panel = W.Mod("UI.Settings.Rows").st.panel
	ok(panel, "the Settings panel is found")
	local cl, pl = R.cue:GetFrameLevel(), panel:GetFrameLevel()
	ok(cl < pl, "cue level " .. tostring(cl) .. " is under the Settings panel's " .. tostring(pl))
	for i = 1, 6 do
		local r = v.rows[i]
		ok(r:GetFrameLevel() < cl, "cue is over row " .. i .. " (" .. tostring(r:GetFrameLevel()) .. " vs " .. tostring(cl) .. ")")
	end
	T.clean(w)
end)
