-- Fix round group j (ING-11, HUNT-131, HUNT-145): a list's soft edge or "more below" cue is never drawn over a
-- page that opens on top of its list (Settings, Messages, Earnings, Crew, sheets).
local T = ...
local H, test, ok = T.H, T.test, T.ok

local function raidWorld()
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
	return w, a, W
end

test("fx j: the raid cue is not drawn over Messages, Earnings or Crew opened over the raid page (HUNT-131)", function()
	local w, a, W = raidWorld()
	local R = W.Driver.ui.console.raid
	ok(R.cue and H.visible(R.cue), "control: the cue shows on the raid page")
	for _, name in ipairs({ "messages", "earnings", "crew" }) do
		W.Driver.ShowScreen(name)
		w:advance(2)
		ok(not H.visible(R.cue), "no raid cue over " .. name)
		W.Driver.ShowScreen("console")
		w:advance(2)
		ok(H.visible(R.cue), "and the cue is back after " .. name)
	end
	T.clean(w)
end)

-- every shown frame under root whose level reaches the Settings panel's
local function over(root, lvl, out)
	if root.IsShown and not root:IsShown() then return out end
	if root.GetFrameLevel and root:GetFrameLevel() >= lvl then out[#out + 1] = root end
	for _, c in ipairs({ root:GetChildren() }) do over(c, lvl, out) end
	return out
end

test("fx j: nothing in the Earnings list reaches the Settings panel's level (ING-11)", function()
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
	W.UI.OpenSettings()
	w:advance(1)
	local panel = W.Mod("UI.Settings.Rows").st.panel
	local lvl = panel:GetFrameLevel()
	local bad = over(e.scroll, lvl, {})
	ok(#bad == 0, #bad .. " frame(s) in the Earnings list at or over level " .. lvl .. (bad[1] and (" first at " .. bad[1]:GetFrameLevel()) or ""))
	T.clean(w)
end)

test("fx j: the Earnings pill is not drawn over a page opened over Earnings, nor over a sheet (ING-11)", function()
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
	ok(e.cue:IsVisible(), "control: the pill shows")
	ok(not W.Driver.PageOver("earnings"), "nothing over Earnings yet")
	W.UI.OpenSettings()
	w:advance(1)
	ok(W.Driver.PageOver("earnings"), "Settings counts as over it")
	ok(not e.cue:IsVisible(), "no pill over Settings")
	T.clean(w)
end)
