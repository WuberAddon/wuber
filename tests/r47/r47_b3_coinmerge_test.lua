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

test("r47 b3: audit C25r-3: my bounty and other riders' wish for the same place are one coin", function()
	local w, W, Mod, wm = setup("Undercity")
	ok(W.Bounty.Mine() and W.Bounty.Mine().place, "control: I have a bounty")
	local shown, at = 0, {}
	for _, c in ipairs(wm.coins) do
		if c:IsShown() then
			shown = shown + 1
			local _, _, _, x, y = c:GetPoint()
			local k = string.format("%.1f,%.1f", x or 0, y or 0)
			at[k] = (at[k] or 0) + 1
		end
	end
	ok(shown >= 1, "control: coins are drawn")
	for k, n in pairs(at) do
		ok(n == 1, n .. " coins are drawn on the same spot (" .. k .. "): my own coin '1' covers the '2 riders' coin")
	end
end)