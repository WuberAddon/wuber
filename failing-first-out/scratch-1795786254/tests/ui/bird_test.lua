-- Tests of UI.Bird. Loaded by tests/run.lua with its helper table T.
-- Shown once per flight-map open, still there after 10 s, gone on close; not with the setting off, in
-- combat, during a ride, with no match; anchored beside the map, never over it; the click opens
-- Confirm for that driver.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local NODES = { { name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 },
	{ name = "Tarren Mill, Hillsbrad", type = "REACHABLE", cost = 580, x = 0.47, y = 0.44 } }

local function setup(opts)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	local t0 = r.env.GetTime()
	W.drivers = W.drivers or {}
	W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Tarren Mill", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = t0 }
	W.FlightCost = function() return 2300, 1 end
	W.FlightTime = function() return 540, "est" end
	return w, r, W
end

local function overlaps(a, b)
	return not (a.l + a.w <= b.l + 0.5 or b.l + b.w <= a.l + 0.5 or a.b + a.h <= b.b + 0.5 or b.b + b.h <= a.b + 0.5)
end

test("ui.bird: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("UI.Bird", "tests/ui/bird_test.lua", {
		["Mod.Pick"] = "function", ["Mod.Show"] = "function", ["Mod.Hide"] = "function", ["Mod.Place"] = "function",
		["Mod.Card"] = "function",
	})
	ok(Mod, "W.Mod(\"UI.Bird\")")
	eq(Mod.Card(), nil, "nothing built at load")
	T.clean(w)
end)

test("ui.bird: once per open beside the map, still there after 10 s, gone on close; the click opens Confirm", function()
	local w, r, W = setup()
	local Mod = W.Mod("UI.Bird")
	w:openTaxiMap(r, NODES)
	w:advance(0.5)
	local c = Mod.Card()
	ok(c and H.visible(c), "the card shows")
	eq(c.text.wuberText, "Summon 30 sec. Fly about 9 min.", "its short line")
	eq(c.sub.wuberText, "Mia · Tarren Mill · 50s", "its second line")
	eq(c.open.label:GetText(), "Book", "the pill")
	local d, info = Mod.Pick()
	eq(Mod.Message(d, info), "Skip the bird: Mia summons to Tarren Mill for 50s. Flying is about 23s and about 9 min. 50s - 23s = really about 27s, and about 9 min back.", "the old sentence is still what Mod.Message says")
	ok(c.tipBody:find(Mod.Message(d, info), 1, true), "and the tooltip's second paragraph")
	local cr, mr = H.rect(c), H.rect(r.env.TaxiFrame)
	ok(not overlaps(cr, mr), "never over the map")
	ok(cr.l >= mr.l + mr.w - 0.5, "right of the map")
	ok(H.STRATA_RANK(c:GetFrameStrata()) < H.STRATA_RANK(r.env.TaxiFrame:GetFrameStrata()), "a strata below the map's")
	w:advance(11)
	ok(H.visible(c), "still there after 10 s (no timed hide)")
	-- still the same open: not again
	eq(Mod.Show(), false, "once per open")
	w:closeTaxiMap(r)
	w:openTaxiMap(r, NODES)
	w:advance(0.5)
	ok(H.visible(c), "shown again on the next open")
	w:closeTaxiMap(r)
	w:advance(0.1)
	ok(not H.visible(c), "hidden on close")
	-- the click opens Confirm for that driver
	w:openTaxiMap(r, NODES)
	w:advance(0.5)
	Mod.Open()
	w:advance(1)
	eq(W.UI.state.confirmKey, "mia runner", "Confirm for Mia")
	ok(r.env.TaxiFrame:IsShown(), "the taxi map stays")
	T.clean(w)
end)

test("ui.bird: not with the setting off, in combat, during a ride, with no match; left of the map near the edge", function()
	local w, r, W = setup()
	local Mod = W.Mod("UI.Bird")
	W.db.birdTip = false
	w:openTaxiMap(r, NODES)
	w:advance(0.5)
	ok(not (Mod.Card() and H.visible(Mod.Card())), "setting off")
	w:closeTaxiMap(r)
	W.db.birdTip = nil
	-- in combat
	r.player.combat = true
	w:openTaxiMap(r, NODES)
	w:advance(0.5)
	ok(not (Mod.Card() and H.visible(Mod.Card())), "in combat")
	w:closeTaxiMap(r)
	r.player.combat = false
	-- during a ride
	W.ride = { id = "b1", driver = "Bea Jones", driverKey = "bea jones", dest = "Undercity", price = 5000, state = "accepted", at = r.env.GetTime() }
	w:openTaxiMap(r, NODES)
	w:advance(0.5)
	ok(not (Mod.Card() and H.visible(Mod.Card())), "during a ride")
	w:closeTaxiMap(r)
	W.ride = nil
	-- no match: flying there is unknown
	W.FlightCost = function() return nil end
	w:openTaxiMap(r, NODES)
	w:advance(0.5)
	ok(not (Mod.Card() and H.visible(Mod.Card())), "no match")
	w:closeTaxiMap(r)
	-- a short hop (no longer than the summon's 30 s wait; r26 rule): no match either
	W.FlightCost = function() return 2300, 1 end
	W.FlightTime = function() return 25, "own" end
	eq(Mod.Pick(), nil, "not worth it")
	W.FlightTime = function() return 540, "own" end
	-- the map near the right edge: the card goes left of it
	w:openTaxiMap(r, NODES)
	local tf = r.env.TaxiFrame
	tf:ClearAllPoints()
	tf:SetPoint("TOPRIGHT", r.env.UIParent, "TOPRIGHT", -10, -116)
	w:advance(0.5)
	local c = Mod.Card()
	ok(c and H.visible(c), "shown")
	eq(c.text.wuberText, "Summon 30 sec. Fly about 9 min.", "its short line")
	local d, info = Mod.Pick()
	eq(Mod.Message(d, info), "Skip the bird: Mia summons to Tarren Mill for 50s. Flying is 23s and 9 min. 50s - 23s = really 27s, and 9 min back.", "a measured flight: no about, in the sentence")
	local cr, mr = H.rect(c), H.rect(tf)
	ok(not overlaps(cr, mr) and cr.l + cr.w <= mr.l + 0.5, "left of the map")
	T.clean(w)
end)
