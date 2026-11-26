local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- A driver pin's price tag never lands on the sea arrow's "continues by ..." label (World view, booking to
-- another continent).
local function setup(dest, price)
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Orgrimmar", faction = "Horde" })
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
	local t0 = r.env.GetTime()
	W.drivers["bob stone"] = { name = T.BOB, key = "bob stone", dest = dest, price = price, state = "open", team = 3,
		service = "Rides", heard = t0 }
	W.Bounty.Demand = function() return {} end
	Mod.Build(holder)
	Mod.Show("world", { route = { from = "Orgrimmar", to = "Undercity" } })
	return w, r, W, Mod, Mod.cache.maps[holder]
end

local function hit(a, b)
	return a.l < b.l + b.w and b.l < a.l + a.w and a.b < b.b + b.h and b.b < a.b + a.h
end

-- the driver's place is nudged over a grid of world offsets, so a pin (and its tag) passes every spot around the label
test("r31.n: no price tag sits on the sea arrow's label", function()
	local w, r, W, Mod, wm = setup("Orgrimmar", 123 * 10000 + 45 * 100 + 67)
	local dx, dy = 0, 0
	local orig = W.PlaceWorld
	W.PlaceWorld = function(p, ...)
		local c, x, y = orig(p, ...)
		if type(p) == "table" and p.name == "Orgrimmar" and x then return c, x + dx, y + dy end
		return c, x, y
	end
	local lab = wm.seaArrow and wm.seaArrow.label
	ok(lab and lab:IsShown(), "control: the label shows")
	local shown, hits = 0, 0
	for ix = -8, 8 do
		for iy = -10, 10 do
			dx, dy = ix * 1500, iy * 1200
			W.Fire("DRIVERS")
			w:advance(1)
			lab = wm.seaArrow and wm.seaArrow.label
			local p = wm.pins[1]
			if lab and lab:IsShown() and p and p.tag and H.visible(p.tag) then
				shown = shown + 1
				if hit(H.rect(p.tag), H.rect(lab)) then hits = hits + 1 end
			end
		end
	end
	ok(shown > 5, "control: the tag shows at many spots (" .. shown .. ")")
	eq(hits, 0, "a visible price tag on the sea label")
	T.clean(w)
end)
