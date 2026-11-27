-- Module: UI.TipTexts
-- Purpose: The 14 login-tip texts (rider tips 1-8, driver tips 9-14), which screen each "Show me" opens and
--   which thing on it Show me rings (target).
-- API: TipTextsMod.list (entries { id, text, driver, screen, target }), TipTextsMod.Show(tip), TipTextsMod.Target(tip)
-- Internals: OPEN, TARGET, tipOf
-- Uses: UI.Coach
-- Later: UI.Window, UI.Settings.Panel, UI.Rider.WorldMap, UI.Driver.Mini, UI.Driver.Console (its Open button, W.Driver.ui.console.open) (all through W.Mod / W.UI at run time)
-- Events: none
-- Standalone: no
-- Test: tests/r25_c_tiptexts.lua
-- From: BRIEF25 T3
--
local _, W = ...
local Mod = W.Module("UI.TipTexts", { "UI.Coach" })

-- Ids are saved in tipsSeen: never rename or reuse one. Order is the order they are shown in.
Mod.list = {
	{ id = "fly_or_summon", driver = false, screen = "home", target = "search",
		text = "Fly or summon? Wuber shows what flying costs and how long, before you book." },
	{ id = "world_view", driver = false, advanced = true, screen = "world", target = "world",
		text = "Tap World to see every driver on the whole map, with flight routes and boats." },
	{ id = "bounty", driver = false, advanced = true, screen = "bounty", target = "search",
		text = "No driver going your way? Pin a bounty; Warlocks see it." },
	{ id = "passphrase", driver = false, advanced = true, screen = "help", target = "gear",
		text = "Drivers can show a two-word passphrase, so you know you've got the right Warlock." },
	{ id = "raincheck", driver = false, screen = "trips", target = "trips",
		text = "Paid and the summon fell through? Your driver can give you a rain check." },
	{ id = "skip_the_bird", driver = false, screen = "settings_riding", target = "gear",
		text = "At a flight master, look for the card that says \"Summon ... Fly ...\"." },
	{ id = "trips_wrapped", driver = false, advanced = true, screen = "trips", target = "trips",
		text = "Trips keeps your ride history; Azeroth Wrapped sums up your month." },
	{ id = "check_game", driver = false, screen = "settings_check", target = "gear",
		text = "Not sure it's working? Type /wuber test. Found a bug? /wuber bug." },
	{ id = "drive_open", driver = true, screen = "drive", target = "go",
		text = "Press Open and riders come to you. The big button always says the next click." },
	{ id = "drive_setup", driver = true, screen = "drive_setup", target = "drive",
		text = "Not a Warlock? Pick a Warlock friend or your own alt in Set up driving." },
	{ id = "earnings", driver = true, screen = "earnings", target = "drive",
		text = "Earnings shows your gold per hour and your best hours to open." },
	{ id = "crews", driver = true, advanced = true, screen = "crew", target = "drive",
		text = "Crews: sell with friends, share the Soul Shards and split the gold fairly." },
	{ id = "customers", driver = true, advanced = true, screen = "customers", target = "drive",
		text = "Customers remembers your regulars; add your own note to each." },
	{ id = "advert", driver = true, screen = "messages", target = "drive",
		text = "Put \"Wuber\" in your Trade adverts so riders find you faster." },
}

local function ui() return W.UI end
local function try(f, ...)
	if type(f) ~= "function" then return false end
	local ok, r = pcall(f, ...)
	return ok and r ~= false
end

-- screen name -> opener (each returns true if it opened something). Nearest screen when none exists:
-- "bounty" opens Home (the bounty card needs a searched place), "world" opens Home then the World view.
local OPEN = {
	home = function() return try(ui().Show, "home") end,
	world = function()
		local ok = try(ui().Show, "home")
		local WorldMod = W.Mod("UI.Rider.WorldMap")
		if type(WorldMod) == "table" then try(WorldMod.Show, "world") end
		return ok
	end,
	bounty = function() return try(ui().Show, "home") end,
	help = function() return try(ui().Show, "home") and try(ui().OpenHelp) end,
	trips = function() return try(ui().Show, "trips") end,
	settings_riding = function() return try(ui().OpenSettings, "riding") end,
	settings_check = function() return try(ui().OpenSettings, "window") end,
	drive = function() return try(ui().ShowDrive, "console") end,
	drive_setup = function() return try(ui().ShowDrive, "wizard") end,
	earnings = function() return try(ui().ShowDrive, "earnings") end,
	crew = function() return try(ui().ShowDrive, "crew") end,
	customers = function() return try(ui().ShowDrive, "customers") end,
	messages = function() return try(ui().ShowDrive, "messages") end,
}

local function tipOf(tip)
	if type(tip) == "string" then
		for _, t in ipairs(Mod.list) do if t.id == tip then return t end end
		return nil
	end
	return type(tip) == "table" and tip or nil
end

-- "Show me": opens the tip's screen; true if it opened something.
function Mod.Show(tip)
	local t = tipOf(tip)
	local open = t and OPEN[t.screen]
	if not open then return false end
	local ok, r = pcall(open)
	return ok and r == true
end

-- target name -> the frame Show me rings (UI.Tips.Spot), or nil. Each falls back to the nearest thing
-- that shows, so Show me always rings something on the screen it opened.
local function shown(f) return type(f) == "table" and type(f.IsVisible) == "function" and f:IsVisible() and f or nil end
local function kit() local k = W.Mod("UI.Kit") return type(k) == "table" and k.ui or {} end
local function tabButton(name)
	for _, tab in ipairs(kit().tabs or {}) do
		if tab.name == name then return shown(tab.button) end
	end
	return nil
end
local function homeSearch()
	local wm = W.Mod("UI.Window")
	local scr = type(wm) == "table" and wm.screens
	return shown(type(scr) == "table" and type(scr.home) == "table" and scr.home.search)
end
local TARGET = {
	search = homeSearch,
	world = function()
		local WorldMod = W.Mod("UI.Rider.WorldMap")
		local last = type(WorldMod) == "table" and type(WorldMod.cache) == "table" and WorldMod.cache.last
		return shown(type(last) == "table" and last.seg) or homeSearch()
	end,
	-- (HUNT-141) Help and Settings hide the cog: there the page itself (the window) is what shows
	gear = function() return shown(kit().gear) or shown(type(W.UI) == "table" and type(W.UI.state) == "table" and W.UI.state.win) end,
	trips = function() return tabButton("Trips") or shown(kit().gear) end,
	go = function()
		local D = W.Driver
		local v = type(D) == "table" and type(D.ui) == "table" and D.ui.console
		return shown(kit().go) or shown(type(v) == "table" and v.open) or tabButton("Drive")
	end,
	drive = function() return tabButton("Drive") end,
}

-- the frame Show me rings for this tip (shown now), or nil
function Mod.Target(tip)
	local t = tipOf(tip)
	local find = t and TARGET[t.target]
	if not find then return nil end
	local ok, f = pcall(find)
	return ok and f or nil
end
