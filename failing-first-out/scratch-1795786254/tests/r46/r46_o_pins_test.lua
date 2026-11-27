local T = ...
-- Round 46 o: HUNT-51 (Home's zone map pin and the World view pin say what the driver's state allows) and
-- HUNT-49 (the minimap tooltip offers Shift-right-click to pause only while you are open to drive).
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- (design 4) the lines of the tip that shows now. Wuber's tips are its own card (WuberTip), no longer lines added to
-- the game's tooltip, so this reads what the fake game copies from the card instead of wrapping GameTooltip.AddLine.
local function record(env)
	local got = {}
	for _, l in ipairs(H.state[env.GameTooltip].tipLines or {}) do got[#got + 1] = tostring(l) end
	return got
end
local function clear(env) H.state[env.GameTooltip].tipLines = {} end
local function has(got, text)
	for _, l in ipairs(got) do if l:find(text, 1, true) then return true end end
	return false
end

local function homeWith(state)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Tarren Mill" })
	w:advance(15)
	local W = r.W
	local mapID = r.env.C_Map.GetBestMapForUnit("player")
	W.drivers = W.drivers or {}
	W.drivers["mia runner"] = { name = "Mia Runner", short = "Mia", key = "mia runner", dest = "Undercity", price = 5000, state = state,
		team = 3, queue = 0, service = "Mia's Rides", heard = r.env.GetTime(), mapID = mapID, x = 0.5, y = 0.5 }
	W.UI.Toggle(true)
	w:advance(3)
	W.UI.RefreshNow()
	w:advance(0.5)
	return w, r, W
end

for _, c in ipairs({ { "open", "Click to request" }, { "busy", "Click to see this driver" }, { "paused", "Click to see this driver" } }) do
	test("r46 o: HUNT-51: Home zone map pin of a " .. c[1] .. " driver says " .. c[2], function()
		local w, r, W = homeWith(c[1])
		clear(r.env)
		local m = W.UI.state.screens.home and W.UI.state.screens.home.map
		ok(m and m.pins and m.pins[1] and m.pins[1].key == "mia runner", "a pin for Mia")
		H.state[m.pins[1]].scripts.OnEnter(m.pins[1])
		local got = record(r.env)
		ok(has(got, c[2]), "tooltip says " .. c[2] .. " (got " .. table.concat(got, " | ") .. ")")
		if c[1] ~= "open" then ok(not has(got, "Click to request"), "no request offer") end
		T.clean(w)
	end)
end

test("r46 o: HUNT-51: World view calls a paused driver paused and a busy one busy", function()
	for _, c in ipairs({ { "paused", " · paused" }, { "busy", " · busy" } }) do
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
		W.drivers["bob stone"] = { name = T.BOB, short = "Bob", key = "bob stone", dest = "Ratchet", price = 5000, state = c[1], team = 3,
			service = "Rides", heard = r.env.GetTime() }
		W.Bounty.Demand = function() return {} end
		Mod.Build(holder)
		Mod.Show("world")
		local wm = Mod.cache.maps[holder]
		clear(r.env)
		ok(wm.pinCount >= 1, c[1] .. ": a pin")
		H.state[wm.pins[1]].scripts.OnEnter(wm.pins[1])
		local got = record(r.env)
		local all = table.concat(got, "\n")
		ok(has(got, c[2]) or all:find(c[2], 1, true), c[1] .. ": says" .. c[2] .. " (got " .. all .. ")")
		T.clean(w)
	end
end)

local function minimapTip(open)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	r.W.Drive.IsOpen = function() return open end
	clear(r.env)
	local b = r.env.WuberMinimapButton
	H.state[b].scripts.OnEnter(b)
	local got = record(r.env)
	local all = table.concat(got, "\n")
	T.clean(w)
	return all
end
test("r46 o: HUNT-49: the minimap tooltip offers Shift-right-click to pause only while open", function()
	ok(not minimapTip(false):find("Shift-right-click", 1, true), "not open: no pause offer")
	ok(minimapTip(true):find("Shift-right-click", 1, true), "open: the pause offer")
end)
