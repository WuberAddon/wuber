local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local function setup(pin)
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
	if pin then W.Bounty.Pin(pin, 50000) w:advance(1) end
	Mod.Build(holder)
	Mod.Show("world")
	return w, W, Mod, Mod.cache.maps[holder]
end

test("r47 e: audit C25r-1: hovering a bounty coin on the World view shows its Wanted tooltip", function()
	local w, W, Mod, wm = setup()
	local c = wm.coins[1]
	ok(c and c:IsShown(), "control: a coin is drawn for the heard wish")
	ok(c.wuberTip and c.wuberTip.title == "Wanted: Undercity", "control: the coin has its tooltip text")
	ok(c:IsMouseEnabled(), "the coin never takes the mouse: hovering it shows no 'Wanted: Undercity' tooltip")
end)
