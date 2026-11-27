local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- HUNT-55: with Settings > Driving "Show what riders want" off, wishes already heard get no coin on the World view.
local function setup()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Orgrimmar" })
	T.settle(w)
	local W = r.W
	local Mod = W.Mod("UI.Rider.WorldMap")
	Mod.Reset()
	for k in pairs(Mod.cache.maps) do Mod.cache.maps[k] = nil end
	Mod.cache.last = nil
	W.UI.Fold.IsUnfolded = function() return true end
	local holder = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	holder:SetSize(360, 544)
	holder:SetPoint("TOPLEFT", r.env.UIParent, "TOPLEFT", 400, -100)
	W.Bounty.Demand = function() return { { place = "Undercity", riders = 2 } } end
	Mod.Build(holder)
	Mod.Show("world")
	return W, Mod, Mod.cache.maps[holder]
end
local function coins(wm) local n = 0 for _ in pairs(wm.coinAt or {}) do n = n + 1 end return n end

test("r33.l3: World view draws no wish coins while Show what riders want is off", function()
	local W, Mod, wm = setup()
	ok(coins(wm) >= 1, "on: the heard wish has a coin")
	W.db.drive = W.db.drive or {}
	W.db.drive.opts = W.db.drive.opts or {}
	W.db.drive.opts.watchBounty = false
	Mod.Show("world")
	eq(coins(wm), 0, "off: no coin")
end)
