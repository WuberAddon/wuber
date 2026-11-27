-- Round 46 f: REV-r28-3 and REV-r28-4, the /wuber why lines for the login tip after a /reload and for "Your usual".
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

test("r46 f: /wuber why after a /reload with no tip shown says a tip shows at login, not after a /reload", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = true } } })
	w:advance(2)
	c.W.UI.Toggle(true) w:advance(5)
	local Tips = c.W.Mod("UI.Tips")
	ok(Tips.state.current ~= nil, "control: a tip showed in the first session")
	Tips.Card().close:Click() w:advance(1)
	local c2 = w:reload(c)
	w:advance(2)
	local Tips2 = c2.W.Mod("UI.Tips")
	eq(Tips2.Why(), "Login tip: one shows when you log in, not again after a /reload. /wuber tips shows one now.", "reload line")
	T.clean(w)
end)

test("r46 f: /wuber why keeps 'already shown this login' when a tip really was shown this login", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = true } } })
	w:advance(2)
	c.W.UI.Toggle(true) w:advance(5)
	local Tips = c.W.Mod("UI.Tips")
	ok(Tips.state.current ~= nil, "a tip showed")
	Tips.Card().close:Click() w:advance(1)
	eq(Tips.Why(), "Login tip: already shown this login. /wuber tips shows it again.", "shown line")
	T.clean(w)
end)

local function usualWorld(mutate)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	W.db.fold = { v = 1, pages = {}, narrow = true }
	W.AlreadyAt = function() return nil end
	W.Bounty = { Mine = function() return nil end, Demand = function() return {} end }
	W.db.rides = {}
	for i = 1, 3 do
		W.db.rides[i] = { dest = "Undercity", driver = "Mia Runner", driverKey = "mia runner", price = 5000, at = r.env.time() - i * 3600, saved = 600 }
	end
	if W.RebuildTotals then W.RebuildTotals() end
	W.UI.Toggle(true) w:advance(3)
	W.UI.Show("home") w:advance(1.5)
	local function drv(name, dest, state)
		local k = name:lower()
		W.drivers[k] = { name = name, key = k, dest = dest, price = 5000, state = state, team = 3, service = name .. "'s Rides", heard = r.env.GetTime(), queue = 0, ver = "2.3.0" }
	end
	mutate(drv, W)
	W.UI.Refresh(true) w:advance(1)
	local line = W.Mod("UI.Rider.Home").WhyUsual()
	T.clean(w)
	return line
end

test("r46 f: WhyUsual, usual driver paused: names them as paused", function()
	eq(usualWorld(function(drv) drv("Mia Runner", "Undercity", "paused") drv("Bea Jones", "Undercity", "open") end),
		"Your usual: Mia Runner is paused right now.", "paused")
end)

test("r46 f: WhyUsual, usual driver serves another place while another is open at the usual place", function()
	eq(usualWorld(function(drv) drv("Mia Runner", "Orgrimmar", "open") drv("Bea Jones", "Undercity", "open") end),
		"Your usual: Mia Runner is not open at Undercity right now.", "elsewhere")
end)

test("r46 f: WhyUsual, usual driver not listed while another is open at the usual place", function()
	eq(usualWorld(function(drv) drv("Bea Jones", "Undercity", "open") end),
		"Your usual: Mia Runner is not open at Undercity right now.", "unlisted")
end)

test("r46 f: WhyUsual, really nobody open keeps the nobody line", function()
	eq(usualWorld(function(drv) drv("Bea Jones", "Undercity", "paused") end),
		"Your usual: nobody is open at Undercity.", "nobody")
end)
