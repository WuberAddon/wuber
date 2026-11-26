-- Run 1, group f: on the real client TAXIMAP_OPENED never reached the recorder (18 TAXIMAP_CLOSED, no OPENED).
-- Learning flight costs and the Bird card must also work when only the flight map frame's OnShow happens.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local NODES = function()
	return {
		{ name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 },
		{ name = "Orgrimmar, Durotar", type = "REACHABLE", cost = 5000, x = 0.5, y = 0.5 },
	}
end

-- the map opens the way the real client did: the frame is shown, TAXIMAP_OPENED never fires
local function showOnly(w, r, frameName, nodes)
	local env = r.env
	env.NumTaxiNodes = function() return #nodes end
	env.TaxiNodeName = function(i) return nodes[i] and nodes[i].name or nil end
	env.TaxiNodeGetType = function(i) return nodes[i] and nodes[i].type or "NONE" end
	env.TaxiNodeCost = function(i) return nodes[i] and nodes[i].cost or 0 end
	local f = rawget(env, frameName)
	if not f then
		f = env.CreateFrame("Frame", frameName, env.UIParent)
		f:SetSize(600, 640)
		f:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 0, -104)
		f:Hide()
		r:fire("ADDON_LOADED", "Blizzard_FlightMap") -- (the frame exists; Wuber looks for it again)
	end
	f:Show()
	return f
end

local function setup()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Orgrimmar", price = 5000, state = "open", team = 3, service = "Mia", heard = r.env.GetTime() }
	return w, r, W
end

for _, frameName in ipairs({ "TaxiFrame", "FlightMapFrame" }) do
	test("run1 f: " .. frameName .. " shown with no TAXIMAP_OPENED still learns the flight costs", function()
		local w, r, W = setup()
		showOnly(w, r, frameName, NODES())
		w:advance(0.5)
		eq(W.FlightCost("Undercity", "Orgrimmar"), 5000, "the cost was learned from the map's OnShow")
		T.clean(w)
	end)

	test("run1 f: " .. frameName .. " shown with no TAXIMAP_OPENED still shows the Bird card, once", function()
		local w, r, W = setup()
		W.FlightCost = function() return 1750, 1 end
		W.FlightTime = function() return 600, "own" end
		local Mod = W.Mod("UI.Bird")
		showOnly(w, r, frameName, NODES())
		w:advance(0.5)
		local c = Mod.Card()
		ok(c and H.visible(c), "the card is shown")
		-- hide and show again: a fresh open shows it again; the event after the show does not double it
		r.env[frameName]:Hide()
		w:advance(1)
		ok(not H.visible(Mod.Card()), "hidden with the map")
		T.clean(w)
	end)
end

test("run1 f: OnShow then TAXIMAP_OPENED learns once (no double open)", function()
	local w, r, W = setup()
	local n = 0
	local orig = W.LearnFlights
	W.LearnFlights = function(...) n = n + 1 return orig(...) end
	showOnly(w, r, "TaxiFrame", NODES())
	r:fire("TAXIMAP_OPENED")
	w:advance(0.5)
	eq(n, 1, "one learning pass for one open")
	T.clean(w)
end)
