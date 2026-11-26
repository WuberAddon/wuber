-- Fix round 2.4, group m1: HUNT-121 (the mid-flight card follows its driver) and HUNT-127 (the Skip the bird card stays above
-- the Wuber window). Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local UC_TM = {
	{ name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 },
	{ name = "Tarren Mill, Hillsbrad", type = "REACHABLE", cost = 330, x = 0.47, y = 0.44 },
}

local function setup()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Undercity", screenW = 1365, screenH = 768 })
	T.settle(w)
	r.W.db.flights = r.W.db.flights or {}
	r.W.db.flights["H|undercity|tarren mill"] = { t = 400, tat = r.env.time(), tsrc = "own" }
	r.W.drivers = r.W.drivers or {}
	r.W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Tarren Mill", price = 5000, state = "open",
		team = 3, service = "Mia's Rides", heard = r.env.GetTime() }
	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 400, "Tarren Mill")
	w:advance(3)
	return w, r
end

test("fr m1 HUNT-121: the mid-flight card shows the driver's new price while it is up", function()
	local w, r = setup()
	local Mod = r.W.Mod("UI.InFlight")
	ok(#r:findText("Book · 50s", false, true) > 0, "starts at 50s")
	r.W.drivers["mia runner"].price = 7200
	w:advance(3)
	ok(#r:findText("Book · 72s", false, true) > 0, "now 72s")
	eq(#r:findText("Book · 50s", false, true), 0, "the old price is gone")
	eq(Mod.Driver(), "mia runner", "still his card")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)

test("fr m1 HUNT-121: the mid-flight card goes when its driver closes his shop", function()
	local w, r = setup()
	local Mod = r.W.Mod("UI.InFlight")
	eq(Mod.Driver(), "mia runner", "offered")
	r.W.drivers["mia runner"].state = "closed"
	w:advance(3)
	eq(Mod.Driver(), nil, "no driver named any more")
	ok(not H.visible(r.env.WuberInFlight), "the card is gone")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)

test("fr m1 HUNT-127: the Skip the bird card is in a strata above the window, so a click in the window cannot cover it", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local Bird = r.W.Mod("UI.Bird")
	local function box(l, b, wd, h, strata, level)
		local f = { l = l, b = b, w = wd, h = h, strata = strata, level = level, shown = true }
		function f.GetLeft() return f.l end
		function f.GetRight() return f.l + f.w end
		function f.GetBottom() return f.b end
		function f.GetTop() return f.b + f.h end
		function f.GetEffectiveScale() return 1 end
		function f.IsShown() return f.shown end
		function f.GetFrameStrata() return f.strata end
		function f.GetFrameLevel() return f.level end
		function f.SetFrameStrata(_, s) f.strata = s end
		function f.SetFrameLevel(_, n) f.level = n end
		function f.ClearAllPoints() end
		function f.SetPoint() end
		return f
	end
	local UI = r.W.UI
	UI.state = UI.state or {}
	local old = UI.state.win
	local win = box(0, 0, 1365, 768, "HIGH", 10)
	UI.state.win = win
	local card = box(0, 0, 10, 10, "MEDIUM", 1)
	card.text = { GetStringHeight = function() return 20 end, SetText = function() end }
	local prev = Bird.Layout
	Bird.Layout = function() return 200, 100 end
	ok(Bird.Place(card, box(100, 100, 300, 300, "HIGH", 1)), "placed")
	Bird.Layout = prev
	UI.state.win = old
	-- the window is Toplevel: a click raises its level a long way; the card's strata still wins
	win.level = 9000
	ok(H.STRATA_RANK(card.strata) > H.STRATA_RANK(win.strata), "card strata " .. tostring(card.strata) .. " is above the window's HIGH")
	T.clean(w)
end)
