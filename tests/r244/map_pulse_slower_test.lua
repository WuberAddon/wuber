-- The map pulses are slow like the Waiting for riders ring: one ring every 3 s, a softer start (alpha 0.4 or less).
-- Covers the map pin (UI.Map.Pins), the Home map's you dot and driver pins, and the world map overlay's you dot.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function slow(p, what)
	eq(p.period, 3, what .. ": one cycle every 3 s")
	eq(#p.rings, 1, what .. ": one ring")
	ok(p.alpha <= 0.4, what .. ": a soft start: " .. tostring(p.alpha))
end

test("map pulse: the map pin's ring takes 3 s, and still starts and stops with the pin", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local Mod = r.W.Mod("UI.Map.Pins")
	local parent = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	parent:SetSize(1000, 600)
	local pin = Mod.NewPin(parent)
	pin.key, pin.nx, pin.ny = "zed", 0.5, 0.5
	local d = { key = "zed", name = "Zed", service = "Zed Rides", state = "open", price = 5000, dest = "Ratchet", team = 1, seats = 4 }
	ok(not pin.pulsing, "control: still before it is chosen")
	Mod.Paint(pin, d, true, 0, false)
	ok(pin.pulsing, "the chosen open pin pulses")
	ok(pin.pulse:IsShown(), "its ring shows")
	eq(pin.pulsePeriod, 3, "one ring every 3 s")
	Mod.Paint(pin, { key = "zed", name = "Zed", service = "Zed Rides", state = "busy", price = 5000, dest = "Ratchet", team = 1, seats = 4 }, true, 0, false)
	ok(not pin.pulsing and not pin.pulse:IsShown(), "it stops with the pin")
	T.clean(w)
end)

test("map pulse: the Home map's you dot and driver pins are one soft ring every 3 s", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local home = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	home:SetSize(360, 600)
	home:SetPoint("TOPLEFT", r.env.UIParent, "TOPLEFT", 10, -10)
	local HM = r.W.Mod("UI.Rider.HomeMap")
	local m = HM.buildMapPanel(home)
	slow(m.me.pulse, "the you dot")
	local mapID = r.env.C_Map.GetBestMapForUnit("player")
	HM.updateMap(m, { { name = "Ana", key = "ana", short = "Ana", dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Ana's Rides", heard = r.env.GetTime(), queue = 0, mapID = mapID, x = 0.4, y = 0.5 } })
	ok(m.pins[1].pulse.running, "an open driver's pin still pulses")
	slow(m.pins[1].pulse, "the driver pin")
	T.clean(w)
end)

test("map pulse: the world map's you dot is one soft ring every 3 s", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Orgrimmar", faction = "Horde" })
	T.settle(w)
	local Mod = r.W.Mod("UI.Rider.WorldMap")
	Mod.Reset()
	r.W.UI.Fold.IsUnfolded = function() return true end
	local holder = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	holder:SetSize(360, 544)
	holder:SetPoint("TOPLEFT", r.env.UIParent, "TOPLEFT", 400, -100)
	r.W.Bounty.Demand = function() return {} end
	Mod.Build(holder)
	Mod.Show("world", { route = { from = "Orgrimmar", to = "Undercity" } })
	local wm = Mod.cache.maps[holder]
	slow(wm.me.pulse, "the world map dot")
	T.clean(w)
end)
