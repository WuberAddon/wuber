-- Wuber Lab (developer only, never ship): ProofWords.lua - read-only in-game checks that Settings and tooltip
-- words match what the clicks do.
--
-- Five fixed wording promises:
--   1. a_proof_words_openmap       OpenMap row tooltip no longer claims the map glides to a driver.
--   2. a_proof_words_drive_gear    Settings opened from the Drive tab gear shows the Driving page.
--   3. a_proof_words_share_notes   /wuber drive sharenotes off turns shareNotes off and says so.
--   4. a_proof_words_minimap_pause Minimap tooltip offers Shift-right-click to pause only while open to drive.
--   5. a_proof_words_crew_own      Crew card offers 'my account' only while sharing is on.
--
-- Read-only: changes nothing, sends nothing, runs only out of combat, and puts every widget and setting back.
-- At load this file makes NO frame, event, or timer.
-- New file: needs a full game restart (a /reload does not find it).

local _, L = ...

local K = L.PhotoKit
local str = L.str
local fn = K and K.fn or function(t, k) return type(t) == "table" and type(t[k]) == "function" end

local SCREENS = L.AUTO_SCREENS
local function screen(s)
	if type(SCREENS) ~= "table" then return s end
	s.auto = true
	SCREENS[#SCREENS + 1] = s
	return s
end

local function result(name, status, detail)
	return { name = name, status = status, detail = detail }
end

local function callm(o, name, ...)
	if type(o) ~= "table" or not fn(o, name) then return nil end
	local r = { pcall(o[name], o, ...) }
	if not r[1] then return nil end
	return unpack(r, 2)
end

local function isTrue(o, name)
	local v = callm(o, name)
	local sec = rawget(_G, "issecretvalue")
	if type(sec) == "function" and sec(v) then return false end
	return v == true
end

local function inCombat()
	local icl = rawget(_G, "InCombatLockdown")
	return type(icl) == "function" and pcall(icl) and icl() == true
end

local function script(f, name)
	if type(f) ~= "table" or not fn(f, "GetScript") then return nil end
	local h = callm(f, "GetScript", name)
	return type(h) == "function" and h or nil
end

local function readTipLines(f)
	if type(f) ~= "table" then return nil, "no frame" end
	local enter = script(f, "OnEnter")
	if not enter then return nil, "no OnEnter" end
	local gt = rawget(_G, "GameTooltip")
	if L.Tip and L.Tip.hide then pcall(L.Tip.hide) end
	if type(gt) == "table" and fn(gt, "Hide") then pcall(gt.Hide, gt) end
	local okE, err = pcall(enter, f, false)
	if not okE then return nil, "OnEnter error: " .. tostring(err) end
	local lines = {}
	if L.Tip and L.Tip.surface and L.Tip.lines then
		local s, kind = L.Tip.surface()
		if s then
			for _, l in ipairs(L.Tip.lines(s, kind)) do
				local t = str(l.text)
				if t then lines[#lines + 1] = t end
			end
		end
	end
	local leave = script(f, "OnLeave")
	if leave then pcall(leave, f, false) end
	if L.Tip and L.Tip.hide then pcall(L.Tip.hide) end
	if type(gt) == "table" and fn(gt, "Hide") then pcall(gt.Hide, gt) end
	return table.concat(lines, "\n")
end

local function findTipTarget(root, matchText, depth, seen)
	depth = depth or 0
	seen = seen or {}
	if type(root) ~= "table" or depth > 14 or seen[root] then return nil end
	seen[root] = true
	local tip = rawget(root, "wuberTip")
	if type(tip) == "table" then
		local combined = tostring(tip.title or "") .. "\n" .. tostring(tip.text or "")
		if combined:find(matchText, 1, true) then return root end
	end
	for _, k in ipairs({ callm(root, "GetChildren") }) do
		local hit = findTipTarget(k, matchText, depth + 1, seen)
		if hit then return hit end
	end
	return nil
end

---------------------------------------------------------------------------
-- 1. OpenMap row tooltip no longer promises a glide
---------------------------------------------------------------------------

screen({
	id = "a_proof_words_openmap",
	side = "settings",
	title = "Proof words: OpenMap tooltip says Best with OpenMap and not glides the map",
	need = function(W)
		return type(W.UI) == "table" and type(W.UI.OpenSettings) == "function" and type(W.UI.CloseSettings) == "function"
	end,
	run = function(W)
		if inCombat() then return "in combat" end
		W.UI.Toggle(true)
		W.UI.OpenSettings("map")
		return true
	end,
	hide = function()
		local W = L.W()
		if type(W) == "table" and type(W.UI) == "table" and type(W.UI.CloseSettings) == "function" then
			pcall(W.UI.CloseSettings)
		end
	end,
	verify = function(W)
		if inCombat() then return { result("OpenMap tooltip", "skip", "in combat") } end
		local st = type(W.UI) == "table" and W.UI.settings
		local panel = type(st) == "table" and st.panel
		if not panel then return { result("OpenMap tooltip", "look", "W.UI.settings.panel missing") } end

		local target = findTipTarget(panel, "OpenMap")
		if not target then return { result("OpenMap tooltip", "look", "OpenMap tip target not found") } end

		local tip, err = readTipLines(target)
		if not tip or tip == "" then
			local wt = rawget(target, "wuberTip")
			tip = type(wt) == "table" and (tostring(wt.title or "") .. "\n" .. tostring(wt.text or "")) or ""
			if tip == "" then return { result("OpenMap tooltip", "look", "empty tooltip: " .. tostring(err)) } end
		end

		local hasGlide = tip:find("glides the map", 1, true) ~= nil
		local hasBest = tip:find("Best with OpenMap; works without it.", 1, true) ~= nil
		if not hasGlide and hasBest then
			return { result("OpenMap tooltip", "pass", "says Best with OpenMap; works without it. (no glide promise)") }
		end
		return { result("OpenMap tooltip", "look", ("hasGlide=%s hasBest=%s tip=%s"):format(tostring(hasGlide), tostring(hasBest), tip:sub(1, 120))) }
	end,
})

---------------------------------------------------------------------------
-- 2. Drive tab gear opens Settings on the Driving page
---------------------------------------------------------------------------

screen({
	id = "a_proof_words_drive_gear",
	side = "driver",
	title = "Proof words: Drive tab gear opens Settings on the Driving page",
	need = function(W)
		return type(W.UI) == "table" and type(W.UI.SelectTab) == "function" and type(W.UI.CloseSettings) == "function"
	end,
	run = function(W)
		if inCombat() then return "in combat" end
		W.UI.Toggle(true)
		if W.UI.SettingsShown and W.UI.SettingsShown() then W.UI.CloseSettings(true) end
		W.UI.SelectTab("Drive")
		return true
	end,
	hide = function()
		local W = L.W()
		if type(W) == "table" and type(W.UI) == "table" then
			if type(W.UI.CloseSettings) == "function" then pcall(W.UI.CloseSettings) end
			if type(W.UI.SelectTab) == "function" then pcall(W.UI.SelectTab, "Ride") end
		end
	end,
	verify = function(W)
		if inCombat() then return { result("Drive gear opens Driving", "skip", "in combat") } end
		local st = type(W.UI) == "table" and W.UI.state
		local gear = type(st) == "table" and st.gear
		if not gear then return { result("Drive gear opens Driving", "look", "W.UI.state.gear missing") } end
		local onClick = script(gear, "OnClick")
		if not onClick then return { result("Drive gear opens Driving", "look", "gear has no OnClick") } end

		pcall(onClick, gear, "LeftButton")
		local open = st.settingsOpen == true
		local settings = W.UI.settings
		local shown = type(settings) == "table" and type(settings.drive) == "table" and isTrue(settings.drive, "IsVisible")
		pcall(W.UI.CloseSettings)
		if open and shown then
			return { result("Drive gear opens Driving", "pass", "gear opened Settings with Driving section shown") }
		end
		return { result("Drive gear opens Driving", "look", ("settingsOpen=%s driveShown=%s"):format(tostring(open), tostring(shown))) }
	end,
})

---------------------------------------------------------------------------
-- 3. /wuber drive sharenotes off says notes stay on this account
---------------------------------------------------------------------------

local capturing = false
local capturedLines = {}
local dcfHooked = false
local function ensureDcfHook()
	if dcfHooked then return end
	local dcf = rawget(_G, "DEFAULT_CHAT_FRAME")
	local hsf = rawget(_G, "hooksecurefunc")
	if type(dcf) == "table" and type(hsf) == "function" then
		dcfHooked = true
		hsf(dcf, "AddMessage", function(_, msg)
			if capturing then capturedLines[#capturedLines + 1] = tostring(msg or "") end
		end)
	end
end

screen({
	id = "a_proof_words_share_notes",
	side = "driver",
	title = "Proof words: /wuber drive sharenotes off turns shareNotes off and says so",
	need = function(W)
		return type(W.Drive) == "table" and type(W.Drive.opts) == "function"
			and type(rawget(_G, "SlashCmdList")) == "table" and type(rawget(_G, "SlashCmdList").WUBER) == "function"
	end,
	run = function(W)
		if inCombat() then return "in combat" end
		W.UI.Toggle(true)
		return true
	end,
	verify = function(W)
		if inCombat() then return { result("Share notes off", "skip", "in combat") } end
		local opts = W.Drive.opts()
		if type(opts) ~= "table" then return { result("Share notes off", "look", "W.Drive.opts() missing") } end
		local savedShare = opts.shareNotes

		ensureDcfHook()
		capturedLines = {}
		capturing = true

		local slash = rawget(_G, "SlashCmdList").WUBER
		local okS, err = pcall(slash, "drive sharenotes off")
		local afterVal = opts.shareNotes

		capturing = false
		opts.shareNotes = savedShare

		if not okS then return { result("Share notes off", "look", "slash error: " .. tostring(err)) } end
		local joined = table.concat(capturedLines, "\n")
		local saidOff = joined:find("Sharing notes with your own accounts: off.", 1, true) ~= nil
		if afterVal == false and saidOff then
			return { result("Share notes off", "pass", "shareNotes=false and printed Sharing notes with your own accounts: off.") }
		end
		return { result("Share notes off", "look", ("shareNotes=%s saidOff=%s lines=%s"):format(tostring(afterVal), tostring(saidOff), joined:sub(1, 120))) }
	end,
})

---------------------------------------------------------------------------
-- 4. Minimap tooltip offers Shift-right-click to pause only while open
---------------------------------------------------------------------------

screen({
	id = "a_proof_words_minimap_pause",
	side = "rider",
	title = "Proof words: minimap tooltip shows Shift-right-click pause line only while open",
	need = function(W)
		return type(W.Drive) == "table" and type(W.Drive.IsOpen) == "function" and type(rawget(_G, "WuberMinimapButton")) == "table"
	end,
	run = function(W)
		if inCombat() then return "in combat" end
		W.UI.Toggle(true)
		return true
	end,
	verify = function(W)
		if inCombat() then return { result("Minimap pause line", "skip", "in combat") } end
		local btn = rawget(_G, "WuberMinimapButton")
		local origIsOpen = W.Drive.IsOpen

		W.Drive.IsOpen = function() return false end
		local closedTip, err1 = readTipLines(btn)

		W.Drive.IsOpen = function() return true end
		local openTip, err2 = readTipLines(btn)

		W.Drive.IsOpen = origIsOpen

		if not closedTip or not openTip then
			return { result("Minimap pause line", "look", ("tip error: closed=%s open=%s"):format(tostring(err1), tostring(err2))) }
		end
		local hasClosed = closedTip:find("Shift-right-click", 1, true) ~= nil
		local hasOpen = openTip:find("Shift-right-click", 1, true) ~= nil
		if not hasClosed and hasOpen then
			return { result("Minimap pause line", "pass", "Shift-right-click shown only while open to drive") }
		end
		return { result("Minimap pause line", "look", ("hasClosed=%s hasOpen=%s"):format(tostring(hasClosed), tostring(hasOpen))) }
	end,
})

---------------------------------------------------------------------------
-- 5. Crew card offers 'my account' only while sharing is on
---------------------------------------------------------------------------

screen({
	id = "a_proof_words_crew_own",
	side = "driver",
	title = "Proof words: Crew card shows 'my account' only while sharing is on",
	need = function(W)
		return type(W.Driver) == "table" and type(W.Driver.ShowScreen) == "function" and type(W.Drive) == "table"
	end,
	run = function(W)
		if inCombat() then return "in combat" end
		W.UI.Toggle(true)
		if W.UI.SettingsShown and W.UI.SettingsShown() then W.UI.CloseSettings(true) end
		W.UI.SelectTab("Drive")
		return true
	end,
	hide = function()
		local W = L.W()
		if type(W) == "table" and type(W.UI) == "table" and type(W.UI.SelectTab) == "function" then
			pcall(W.UI.SelectTab, "Ride")
		end
	end,
	verify = function(W)
		if inCombat() then return { result("Crew my account", "skip", "in combat") } end
		local D, DR = W.Driver, W.Drive
		local origCrew = DR.Crew
		local origShare = DR.BookShareOn
		local sharing = true

		DR.Crew = function()
			return {
				{ name = "Anita Lift", key = W.myKey or "anita lift", role = "lock", app = true, me = true, here = true },
				{ name = "Bea Jones", key = "bea jones", role = "lock", app = true, here = true },
			}
		end
		DR.BookShareOn = function() return sharing end

		local ok1, err1 = pcall(D.ShowScreen, "crew")
		if not ok1 then
			DR.Crew, DR.BookShareOn = origCrew, origShare
			return { result("Crew my account", "look", "ShowScreen crew failed: " .. tostring(err1)) }
		end

		local crewUI = D.ui and D.ui.subs and D.ui.subs.crew
		local list = crewUI and crewUI.members and crewUI.members.list
		local bea = list and list[1]
		if type(bea) ~= "table" or not bea.own or not bea.ownLabel then
			DR.Crew, DR.BookShareOn = origCrew, origShare
			pcall(D.ShowScreen, "console")
			return { result("Crew my account", "look", "crew member row bea.own/ownLabel missing") }
		end

		local onOwn = isTrue(bea.own, "IsVisible")
		local onLbl = isTrue(bea.ownLabel, "IsVisible")

		sharing = false
		pcall(D.RefreshNow)
		local offOwn = isTrue(bea.own, "IsVisible")
		local offLbl = isTrue(bea.ownLabel, "IsVisible")

		sharing = true
		pcall(D.RefreshNow)
		local backOwn = isTrue(bea.own, "IsVisible")
		local backLbl = isTrue(bea.ownLabel, "IsVisible")

		DR.Crew = origCrew
		DR.BookShareOn = origShare
		pcall(D.RefreshNow)
		pcall(D.ShowScreen, "console")

		if onOwn and onLbl and not offOwn and not offLbl and backOwn and backLbl then
			return { result("Crew my account", "pass", "my account switch and label shown when sharing=true, hidden when false, restored") }
		end
		return { result("Crew my account", "look",
			("on=(%s,%s) off=(%s,%s) back=(%s,%s)"):format(tostring(onOwn), tostring(onLbl), tostring(offOwn), tostring(offLbl), tostring(backOwn), tostring(backLbl))) }
	end,
})
