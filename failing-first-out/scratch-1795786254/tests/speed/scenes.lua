-- tests/speed/scenes.lua: the screen changes the speed profiler measures (job 2749; tools/profile-tests.lua --screens).
-- One Warlock with the Drive tab (advanced), 40 drivers on Home and 60 trips, at 1920x1080; each step is one
-- player-visible change. Scenes.run(H, P, { deep, only }) -> { { id, label, m } } (m: tests/lib/screenprof.lua).
-- Tests in tests/speed/ use Scenes.world() and Scenes.STEPS to hold a change to a written budget.
local Scenes = {}

local DRIVERS, TRIPS = 40, 60
local PLACES = { "Undercity", "Ratchet", "Thunder Bluff", "Crossroads", "Booty Bay", "Gadgetzan", "Tarren Mill", "Orgrimmar" }

-- the key of the i-th demo driver (Scenes.world): "drvba lift1", "drvca lift2", ...
function Scenes.driverKey(i)
	return ("Drv" .. string.char(96 + (i % 26) + 1) .. string.char(96 + math.floor(i / 26) + 1) .. " Lift" .. i):lower()
end

function Scenes.world(H, opts)
	opts = opts or {}
	local w = H.NewWorld({})
	w:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" })
	local c = w:addClient(opts.name or "Anita Lift", { spot = "Orgrimmar", class = "WARLOCK", money = 1000000,
		screenW = 1920, screenH = 1080, addons = { "Wuber" } })
	w:advance(15)
	local W = c.W
	W.db.coach = true
	W.db.openMapHint = true
	if W.Char then pcall(function() W.Char().wizard = true end) end
	local t0 = c.env.GetTime()
	for i = 1, (opts.drivers or DRIVERS) do
		local first = "Drv" .. string.char(96 + (i % 26) + 1) .. string.char(96 + math.floor(i / 26) + 1)
		local n = first .. " Lift" .. i
		local k = n:lower()
		W.drivers[k] = { name = n, key = k, dest = PLACES[(i % #PLACES) + 1], price = 4000 + i * 50, state = "open",
			team = (i % 3) + 1, service = first .. "'s Rides", heard = t0 }
	end
	local stamp = c.env.time()
	for i = 1, (opts.trips or TRIPS) do
		W.db.rides[#W.db.rides + 1] = { dest = PLACES[(i % #PLACES) + 1], driver = "Old Driver" .. i, driverKey = "old driver" .. i,
			price = 3000 + i * 10, at = stamp - i * 3600, stars = (i % 5) + 1, saved = 300 }
	end
	return w, c
end

local function D(c) return c.W.Driver end
local function tabs(c, name) return c.W.UI.SelectTab(name) end

-- { id, label, fn(c, w) }; ids are stable (the budget tests name them)
Scenes.STEPS = {
	{ "open1", "open the window (first time: builds it)", function(c) c.W.UI.Toggle(true) end },
	{ "close1", "close the window", function(c) c.W.UI.Toggle(false) end },
	{ "open2", "open the window again", function(c) c.W.UI.Toggle(true) end },
	{ "home_refresh", "Home redraw with 40 drivers (UI.RefreshNow)", function(c) c.W.UI.RefreshNow() end },
	{ "trips1", "Ride -> Trips (first time)", function(c) tabs(c, "Trips") end },
	{ "ride1", "Trips -> Ride", function(c) tabs(c, "Ride") end },
	{ "trips2", "Ride -> Trips (again)", function(c) tabs(c, "Trips") end },
	{ "trips_refresh", "Trips redraw with 60 trips (UI.RefreshNow)", function(c) c.W.UI.RefreshNow() end },
	{ "drive1", "Trips -> Drive (first time)", function(c) tabs(c, "Drive") end },
	{ "ride2", "Drive -> Ride", function(c) tabs(c, "Ride") end },
	{ "drive2", "Ride -> Drive (again)", function(c) tabs(c, "Drive") end },
	{ "earn1", "Drive console -> Earnings (first time)", function(c) D(c).ShowScreen("earnings") end },
	{ "earn_back", "Earnings -> back to the console", function(c) D(c).ShowScreen("console") end },
	{ "earn2", "Drive console -> Earnings (again)", function(c) D(c).ShowScreen("earnings") end },
	{ "earn_back2", "Earnings -> back (again)", function(c) D(c).ShowScreen("console") end },
	{ "cust1", "Drive console -> Customers (first time)", function(c) D(c).ShowScreen("customers") end },
	{ "cust_back", "Customers -> back", function(c) D(c).ShowScreen("console") end },
	{ "crew1", "Drive console -> Crew (first time)", function(c) D(c).ShowScreen("crew") end },
	{ "crew_back", "Crew -> back", function(c) D(c).ShowScreen("console") end },
	{ "demand1", "Drive console -> Demand (first time)", function(c) D(c).ShowScreen("demand") end },
	{ "demand_back", "Demand -> back", function(c) D(c).ShowScreen("console") end },
	{ "msgs1", "Drive console -> Messages (first time)", function(c) D(c).ShowScreen("messages") end },
	{ "msgs_back", "Messages -> back", function(c) D(c).ShowScreen("console") end },
	{ "sheet1", "Drive price/place sheet (first time)", function(c) D(c).ShowSheet("sheet") end },
	{ "drive_refresh", "Drive console redraw (D.RefreshNow)", function(c) D(c).RefreshNow() end },
	{ "ride3", "Drive -> Ride (third time)", function(c) tabs(c, "Ride") end },
	{ "settings1", "Ride -> cog -> Settings (first time)", function(c) c.W.UI.OpenSettings() end },
	{ "settings_back1", "Settings -> back", function(c) c.W.UI.CloseSettings() end },
	{ "settings2", "Ride -> Settings (again)", function(c) c.W.UI.OpenSettings() end },
	{ "settings_refresh", "Settings redraw (UI.RefreshNow)", function(c) c.W.UI.RefreshNow() end },
	{ "settings_back2", "Settings -> back (again)", function(c) c.W.UI.CloseSettings() end },
	{ "help1", "Help (first time)", function(c) c.W.UI.OpenHelp() end },
	{ "help_back", "Help -> back", function(c) c.W.UI.CloseHelp() end },
	{ "confirm1", "Home -> a driver's page (first time)", function(c) c.W.UI.Show("confirm", Scenes.driverKey(1)) end },
	{ "confirm_home", "driver's page -> Home", function(c) c.W.UI.Show("home") end },
	{ "confirm2", "Home -> a driver's page (again)", function(c) c.W.UI.Show("confirm", Scenes.driverKey(2)) end },
	{ "confirm_home2", "driver's page -> Home (again)", function(c) c.W.UI.Show("home") end },
	{ "unfold", "unfold the window (wide)", function(c) c.W.db.fold = nil c.W.UI.Fold.Apply() end },
	{ "fold", "fold the window (narrow)", function(c) c.W.db.fold = { v = 1, pages = {}, narrow = true } c.W.UI.Fold.Apply() end },
	{ "idle_open", "5 s with the window open on Home (nothing clicked)", function() end, 5 },
	{ "close2", "close the window", function(c) c.W.UI.Toggle(false) end },
	{ "idle_closed", "5 s with the window closed", function() end, 5 },
}

function Scenes.run(H, P, opts)
	opts = opts or {}
	local w, c = Scenes.world(H, opts)
	local sess = P.session(c)
	local out = {}
	for _, st in ipairs(Scenes.STEPS) do
		local m = sess:measure(function() st[3](c, w) end, { settle = st[4] or 1, deep = opts.deep })
		out[#out + 1] = { id = st[1], label = st[2], m = m }
	end
	sess:close()
	out.errors = {}
	for _, e in ipairs(w.errors) do out.errors[#out.errors + 1] = tostring(e):match("^[^\n]*") end
	return out, w, c
end

return Scenes
