-- Tests of UI.Driver.Demand (SPEC7 5.3; owner D). Loaded by tests/run.lua with its helper table T.
-- The contract, then what the driver sees of riders' bounties: the folded console's line, the
-- sheet with "Serve it" (only where the driver stands), the unfolded "Wanted nearby" card, and
-- the Driving setting "Show what riders want". W.Bounty.Demand (Net.Bounty) is stubbed here.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("ui.driver.demand: contract (registered, deps, header, public names); idle with no demand", function()
	local W, w, r, Mod = T.contract("UI.Driver.Demand", "tests/ui/driver/demand_test.lua", {
		["D.screens.demand"] = "function", ["D.DemandCard"] = "function",
		["Mod.List"] = "function", ["Mod.Range"] = "function", ["Mod.drawLine"] = "function", ["Mod.hideLine"] = "function",
	})
	ok(Mod, "W.Mod(\"UI.Driver.Demand\")")
	eq(#Mod.List(), 0, "no demand while Net.Bounty has none")
	T.clean(w)
end)

-- a selling driver standing in Undercity with the console open and riders wanting places
local function driverWith(demand, o)
	o = o or {}
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = o.spot or "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.IsOpen = function() return true end
	DR.Sorted = function() return {} end
	W.Bounty.Demand = function() return demand end
	-- (2.3) the folded console (the harness screen is wide enough to unfold it)
	if not o.wide and W.UI.WindowWide then W.UI.WindowWide(false) end
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(2)
	W.Driver.RefreshNow()
	return w, a, W, DR
end

test("ui.driver.demand: the list is most riders first, at most five, with the pledge range", function()
	local w, a, W = driverWith({})
	local Mod = W.Mod("UI.Driver.Demand")
	-- (round 9, C5) newest is W.Bounty.Demand's age in seconds: the smaller, the newer
	W.Bounty.Demand = function()
		return {
			{ place = "Gadgetzan", riders = 3, low = 5000, high = 10000, newest = 120 },
			{ place = "Booty Bay", riders = 1, low = 7500, high = 7500, newest = 30 },
			{ place = "Ratchet", riders = 2, low = 5000, high = 6000, newest = 600 },
			{ place = "Tarren Mill", riders = 1, newest = 10 },
			{ place = "Everlook", riders = 1, low = 5000, high = 5000 },
			{ place = "Moonglade", riders = 1, low = 5000, high = 5000 },
			{ place = "", riders = 4 }, { place = "Bad", riders = 0 },
		}
	end
	local l = Mod.List()
	eq(#l, 5, "at most five places")
	eq(l[1].place, "Gadgetzan", "most riders first")
	eq(l[2].place, "Ratchet", "then the next")
	eq(l[3].place, "Tarren Mill", "ties: the newest first")
	eq(Mod.Range(l[1]), "50s–1g", "a range")
	eq(Mod.Range({ low = 7500, high = 7500 }), "75s", "one price")
	eq(Mod.Range({}), nil, "no pledge known")
	-- off: the Driving setting "Show what riders want"
	W.Drive.opts().watchBounty = false
	eq(#Mod.List(), 0, "nothing with the setting off")
	W.Drive.opts().watchBounty = true
	-- raid summons and helpers never see it
	W.Drive.Mode = function() return "raid" end
	eq(#Mod.List(), 0, "raid summons: nothing")
	W.Drive.Mode = function() return "sell" end
	W.Drive.Role = function() return "helper" end
	eq(#Mod.List(), 0, "a helper: nothing")
	T.clean(w)
end)

test("ui.driver.demand: the folded console shows one line above the queue (round 13, I9); a tap opens the sheet", function()
	local t0 = os.time()
	local w, a, W = driverWith({ { place = "Gadgetzan", riders = 3, low = 5000, high = 10000, newest = t0 } })
	local D = W.Driver
	local v = D.ui.console
	ok(v.demand and T.H.visible(v.demand), "the line shows")
	eq(v.demand.text.wuberText, "3 riders want Gadgetzan", "its words")
	-- (round 13, I9) it sits above the queue (under three riders it was out of sight)
	ok(v.demand:GetBottom() > v.empty:GetTop(), "above the queue")
	a:clickOn(v.demand)
	w:advance(1)
	local s = W.UI.drive.screens.demand
	ok(s and s.frame.open, "the sheet opened")
	ok(T.H.visible(s.rows[1]), "one row")
	eq(s.rows[1].place.wuberText, "Gadgetzan", "the place")
	ok(s.rows[1].sub.wuberText:find("3 riders · 50s–1g", 1, true), s.rows[1].sub.wuberText)
	-- one rider: "1 rider wants"
	W.Bounty.Demand = function() return { { place = "Ratchet", riders = 1 } } end
	D.RefreshNow()
	eq(v.demand.text.wuberText, "1 rider wants Ratchet", "singular")
	-- none: the line goes
	W.Bounty.Demand = function() return {} end
	D.RefreshNow()
	ok(not v.demand:IsShown(), "gone with no demand")
	T.clean(w)
end)

test("ui.driver.demand: Serve it opens the price and place sheet with the place, only where the driver stands", function()
	local w, a, W = driverWith({ { place = "Undercity", riders = 2 }, { place = "Gadgetzan", riders = 1 } })
	local D = W.Driver
	D.ShowSheet("demand")
	w:advance(1)
	local s = W.UI.drive.screens.demand
	local uc, gz = s.rows[1], s.rows[2]
	eq(uc.place.wuberText, "Undercity", "first row")
	ok(not uc.serve.inactive, "Serve it is live where I stand")
	-- not here: the pill is quiet and its click doesn't open the sheet
	eq(gz.place.wuberText, "Gadgetzan", "second row")
	ok(gz.serve.inactive, "not where I stand: inactive")
	a:clickOn(gz.serve)
	w:advance(1)
	ok(not (W.UI.drive.screens.sheet and W.UI.drive.screens.sheet.frame.open), "no price sheet from elsewhere")
	-- here: the price and place sheet, that place chosen
	D.ShowSheet("demand")
	w:advance(1)
	a:clickOn(uc.serve)
	w:advance(1)
	local ps = W.UI.drive.screens.sheet
	ok(ps and ps.frame.open, "the price and place sheet opened")
	eq(ps.mode, "choose", "Choose a place")
	eq(ps.search:Text(), "Undercity", "that place")
	T.clean(w)
end)

test("ui.driver.demand: the Wanted nearby card (unfolded console) lists up to five places", function()
	local w, a, W = driverWith({ { place = "Gadgetzan", riders = 3, low = 5000, high = 10000 }, { place = "Ratchet", riders = 1 } })
	local D = W.Driver
	local host = a.env.CreateFrame("Frame", nil, a.env.UIParent)
	host:SetSize(360, 544)
	local card = D.DemandCard(host, 340)
	local h = card:Update()
	ok(h > 0 and card:IsShown(), "it shows")
	eq(card.rows[1].place.wuberText, "Gadgetzan", "the top place")
	eq(card.rows[2].place.wuberText, "Ratchet", "the next")
	W.Bounty.Demand = function() return {} end
	eq(card:Update(), 0, "nothing: height 0")
	ok(not card:IsShown(), "hidden")
	T.clean(w)
end)

-- (round 9, C5) the real W.Bounty.Demand gives the newest bounty's AGE in seconds: a bounty pinned
-- ten minutes ago reads "newest 10 min ago" (not the game's uptime); ties: the newest first
test("ui.driver.demand: newest is an age (round 9 C5): the real demand reads minutes ago, newest first", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	DR.IsOpen = function() return true end
	DR.Sorted = function() return {} end
	local t = W.Mod("Net.Base").now()
	W.bounties = W.bounties or {}
	W.bounties["Gadgetzan"] = { ["wuber testcharacter"] = { copper = 5000, at = t - 600, untilAt = t + 900, name = "Wuber TestCharacter" } }
	W.bounties["Ratchet"] = { ["bob stone"] = { copper = 5000, at = t - 30, untilAt = t + 900, name = "Bob Stone" } }
	local Mod = W.Mod("UI.Driver.Demand")
	local l = Mod.List()
	eq(#l, 2, "two places")
	eq(l[1].place, "Ratchet", "ties: the newest (smallest age) first")
	eq(l[2].place, "Gadgetzan", "then the older")
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	W.Driver.ShowSheet("demand")
	w:advance(1)
	local s = W.UI.drive.screens.demand
	local sub = s.rows[2].sub.wuberText
	ok(sub:find("newest 10 min ago", 1, true), "ten minutes ago: " .. sub)
	ok(not sub:find(" h ago", 1, true), "never hours: " .. sub)
	ok(s.rows[1].sub.wuberText:find("newest just now", 1, true), s.rows[1].sub.wuberText)
	T.clean(w)
end)
