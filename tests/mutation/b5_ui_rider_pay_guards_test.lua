-- Mutation guard tests for Wuber/UI/Rider/Pay.lua.
-- Each test guards one or more unprotected lines against player-visible promises.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- guards Wuber/UI/Rider/Pay.lua:48 (drop statement: SetTipPct does not refresh UI)
test("mutation b5 ui rider pay: SetTipPct refreshes the UI", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local W = c.W
	local UI = W.UI
	local refreshed = 0
	local origRefresh = UI.Refresh
	UI.Refresh = function(force)
		if force then refreshed = refreshed + 1 end
		return origRefresh(force)
	end
	eq(UI.SetTipPct(20), true, "SetTipPct(20) succeeds")
	eq(W.db.tipPct, 20, "tipPct saved")
	eq(refreshed, 1, "UI.Refresh(true) called by SetTipPct")
	UI.Refresh = origRefresh
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Pay.lua:130 (swap and->or: TradePartnerOK accepts stranger when RideTrader is absent)
-- guards Wuber/UI/Rider/Pay.lua:132 (return -> nil: TradePartnerOK returns nil instead of false for stranger)
test("mutation b5 ui rider pay: TradePartnerOK fallback checks partner key and returns false for stranger", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local W = c.W
	local UI = W.UI
	local origTrader = W.RideTrader
	local origUnitName = W.UnitName
	W.RideTrader = nil
	W.UnitName = function(unit)
		if unit == "npc" then return "Stranger" end
		return origUnitName(unit)
	end
	local rv = { raw = { driver = "Dan Driver", driverKey = "dan driver" } }
	local okPartner, partner = UI.TradePartnerOK(rv)
	eq(okPartner, false, "stranger returns false, not true or nil")
	eq(partner, "stranger", "partner key returned")

	W.UnitName = function(unit)
		if unit == "npc" then return "Dan Driver" end
		return origUnitName(unit)
	end
	local okDriver, driverPartner = UI.TradePartnerOK(rv)
	eq(okDriver, true, "matching driver returns true")
	eq(driverPartner, "dan driver", "driver key returned")

	W.RideTrader = origTrader
	W.UnitName = origUnitName
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Pay.lua:175 (drop statement: flight band size not set)
-- guards Wuber/UI/Rider/Pay.lua:176 (drop statement: flight band not anchored below tradePay)
-- guards Wuber/UI/Rider/Pay.lua:177 (drop statement: flight band background not created)
-- guards Wuber/UI/Rider/Pay.lua:179 (drop statement: flight band text not centered)
-- guards Wuber/UI/Rider/Pay.lua:180 (drop statement: flight band text width not set)
-- guards Wuber/UI/Rider/Pay.lua:184 (drop statement: flight band not shown when FlightLine returns text)
-- guards Wuber/UI/Rider/Pay.lua:186 (drop statement: flight band not hidden when FlightLine becomes nil)
test("mutation b5 ui rider pay: tradePay flight band lays out, shows, and hides with FlightLine", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local W = c.W
	local UI = W.UI
	local origFlight = UI.FlightLine
	local origUnitName = W.UnitName
	local origTrader = W.RideTrader
	local flightText = "Saves 8 min vs flying"
	UI.FlightLine = function() return flightText end
	W.RideTrader = function() return true end
	W.UnitName = function(unit)
		if unit == "npc" then return "Dan Driver" end
		return origUnitName(unit)
	end
	W.ride = {
		id = "r1",
		state = "arrived",
		price = 5000,
		driver = "Dan Driver",
		driverKey = "dan driver",
		payto = "Dan",
	}
	c.env.TradeFrame:Show()
	c:fire("TRADE_SHOW")
	w:advance(0.3)

	-- Find the tradePay pill anchored to TradeFrame and its .flight child
	local tf = c.env.TradeFrame
	local tp
	for _, ch in ipairs({ tf:GetChildren() }) do
		if ch.flight then tp = ch break end
	end
	ok(tp ~= nil, "tradePay pill with flight band created under TradeFrame")
	local fb = tp.flight
	eq(fb:GetWidth(), 330, "flight band width 330")
	eq(fb:GetHeight(), 24, "flight band height 24")
	local pt, rel, relPt, x, y = fb:GetPoint(1)
	eq(pt, "TOP", "flight band anchored TOP")
	eq(rel, tp, "flight band anchored to tradePay")
	eq(relPt, "BOTTOM", "flight band anchored to BOTTOM of tradePay")
	eq(y, -4, "flight band y offset -4")
	ok(fb.bg ~= nil, "flight band background created")
	local tpt, trel, trelPt = fb.text:GetPoint(1)
	eq(tpt, "CENTER", "flight band text centered")
	eq(trel, fb, "flight band text anchored to flight band")
	eq(fb.text:GetWidth(), 318, "flight band text width 318")
	eq(fb:IsShown(), true, "flight band shown when FlightLine returns text")

	-- Now FlightLine becomes nil -> flight band hides
	flightText = nil
	W.Fire("RIDE")
	eq(fb:IsShown(), false, "flight band hides when FlightLine becomes nil")

	-- FlightLine returns text again -> flight band shows again
	flightText = "Saves 5 min vs flying"
	W.Fire("RIDE")
	eq(fb:IsShown(), true, "flight band shows again when FlightLine returns text")

	c.env.TradeFrame:Hide()
	c:fire("TRADE_CLOSED")
	UI.FlightLine = origFlight
	W.UnitName = origUnitName
	W.RideTrader = origTrader
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Pay.lua:217 (local value -> nil: combat queue registers duplicate AfterCombat callbacks)
-- guards Wuber/UI/Rider/Pay.lua:218 (swap or->and: trade overwrites queued arrived reason in combat)
-- guards Wuber/UI/Rider/Pay.lua:222 (drop statement: payWaiting not cleared after combat, blocking next combat defer)
test("mutation b5 ui rider pay: combat-deferred OpenForPay deduplicates, prioritizes arrived, and resets payWaiting", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local W = c.W
	local UI = W.UI
	local origInCombat = c.env.InCombatLockdown
	local origAfterCombat = W.AfterCombat
	local origTrader = W.RideTrader
	local origUnitName = W.UnitName
	local inCombat = true
	local afterCallbacks = {}
	c.env.InCombatLockdown = function() return inCombat end
	W.AfterCombat = function(fn) afterCallbacks[#afterCallbacks + 1] = fn end
	W.RideTrader = function() return true end
	W.UnitName = function(unit)
		if unit == "npc" then return "Dan Driver" end
		return origUnitName(unit)
	end
	W.ride = {
		id = "r_combat_1",
		state = "arrived",
		price = 5000,
		driver = "Dan Driver",
		driverKey = "dan driver",
		payto = "Dan",
	}

	-- 1. Arrived in combat, then trade in combat: arrived must outrank trade and only 1 AfterCombat queued
	eq(UI.OpenForPay("arrived"), false, "arrived in combat defers")
	eq(UI.OpenForPay("trade"), false, "trade in combat defers")
	eq(#afterCallbacks, 1, "only one AfterCombat callback queued")

	-- Leave combat, make trade partner false so "trade" would fail if it overwrote "arrived"
	inCombat = false
	W.RideTrader = function() return false end
	afterCallbacks[1]()
	ok(UI.IsShown(), "window opened after combat with arrived reason outranking trade")

	-- Close window and test a second ride in combat to verify payWaiting was cleared
	UI.Toggle(false)
	w:advance(1)
	inCombat = true
	W.ride = {
		id = "r_combat_2",
		state = "arrived",
		price = 5000,
		driver = "Dan Driver",
		driverKey = "dan driver",
		payto = "Dan",
	}
	eq(UI.OpenForPay("arrived"), false, "second ride in combat defers")
	eq(#afterCallbacks, 2, "new AfterCombat callback queued because payWaiting was cleared")

	c.env.InCombatLockdown = origInCombat
	W.AfterCombat = origAfterCombat
	W.RideTrader = origTrader
	W.UnitName = origUnitName
	T.clean(w)
end)
