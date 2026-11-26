-- Conformance, group B (job 2766): the fake game against the real client's facts about trades, forbidden
-- calls, the flight map, animations, the API census and the trade button. Evidence: tests/fixtures/rec/lab-real-facts.lua
-- (ids trade.*, forbidden.*, taxi.*) and the Lab's Game facts of build 71037 (PROVEN-FACTS PF-057, PF-059, PF-060,
-- PF-065). Facts already pinned by tests/rec/real_trade_test.lua, real_forbidden_test.lua, real_taxi_test.lua and
-- conform_test.lua are not repeated; the guards below pin the ones that had no test.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function taxiWorld()
	local w = T.newWorld()
	local r = T.rider(w, "Wuber Rocks", { spot = "Orgrimmar" })
	w:advance(1)
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Orgrimmar", { known = { "Crossroads" } }))
	return w, r
end

-- PF-057 (B16, build 71037): "TaxiFrame shown, FlightMapFrame absent; 22 TaxiButtons (2 shown); inner area 580 x 580".
-- PROVEN: 22 buttons, 2 shown, inner area 580 x 580, TaxiFrame shown, no FlightMapFrame.
-- INFERRED (not recorded): WHICH buttons are shown (read as the current node and the known ones), the route map's offset
-- inside TaxiFrame (11, -28), and the buttons' size (18) and positions (the node's x, y within the route map).
test("conform b: the flight map has one TaxiButton per node, shown for the current and reachable ones (PF-057)", function()
	local w, r = taxiWorld()
	local n, shown = 0, 0
	for i = 1, 60 do
		local b = rawget(r.env, "TaxiButton" .. i)
		if b then
			n = n + 1
			if b:IsShown() then shown = shown + 1 end
		end
	end
	eq(n, 22, "22 TaxiButtons on Kalimdor")
	eq(shown, 2, "2 shown: here and Crossroads")
	T.clean(w)
end)

-- reopening with a shorter list must not leave the old buttons shown
test("conform b: a shorter map hides the buttons beyond its nodes (PF-057)", function()
	local w, r = taxiWorld()
	local all = H.realTaxi("Kalimdor", "Orgrimmar")
	for _, n in ipairs(all) do if n.type == "NONE" then n.type = "REACHABLE" end end
	w:openTaxiMap(r, all) -- every button shown; then opened again, still open, with a shorter list
	local short = H.realTaxi("Kalimdor", "Orgrimmar", { known = { "Crossroads" } })
	for _, n in ipairs(short) do if n.type == "NONE" then n.type = "REACHABLE" end end
	while #short > 5 do short[#short] = nil end
	w:openTaxiMap(r, short)
	local shown = 0
	for i = 1, 60 do
		local b = rawget(r.env, "TaxiButton" .. i)
		if b and b:IsShown() then
			shown = shown + 1
			ok(i <= 5, "TaxiButton" .. i .. " is beyond the 5 nodes but shown")
		end
	end
	ok(shown <= 5, "at most 5 shown")
	T.clean(w)
end)

test("conform b: the flight map's inner area (TaxiRouteMap) is 580 x 580 (PF-057)", function()
	local w, r = taxiWorld()
	local m = rawget(r.env, "TaxiRouteMap")
	ok(m, "TaxiRouteMap exists")
	eq(m and (m:GetWidth() .. "x" .. m:GetHeight()), "580x580")
	T.clean(w)
end)

-- guard: PF-057 TaxiFrame shown, FlightMapFrame absent (real_taxi_test.lua pins the size too)
test("conform b: TaxiFrame shown, no FlightMapFrame (PF-057)", function()
	local w, r = taxiWorld()
	ok(r.env.TaxiFrame:IsShown(), "TaxiFrame")
	eq(rawget(r.env, "FlightMapFrame"), nil)
	T.clean(w)
end)

-- PF-060 (census, 299 answers): SetGradientAlpha is nil on a texture; SetGradient is there
test("conform b: a texture has no SetGradientAlpha, but SetGradient (PF-060)", function()
	local w = T.newWorld()
	local r = T.rider(w, "Wuber Rocks")
	local t = r.env.CreateFrame("Frame"):CreateTexture()
	eq(t.SetGradientAlpha, nil, "SetGradientAlpha")
	eq(type(t.SetGradient), "function", "SetGradient")
	T.clean(w)
end)

-- guard: PF-060 WOW_PROJECT_ID is 18 and the edge getters of an unplaced frame give nothing
test("conform b: WOW_PROJECT_ID 18; an unplaced frame's edge getters answer nothing (PF-060)", function()
	local w = T.newWorld()
	local r = T.rider(w, "Wuber Rocks")
	eq(r.env.WOW_PROJECT_ID, 18)
	local f = r.env.CreateFrame("Frame")
	eq(select("#", f:GetLeft()), 0, "GetLeft gives no value")
	eq(select("#", f:GetRect()), 0, "GetRect gives no value")
	T.clean(w)
end)

-- PF-065 (TRADEBTN): TradeFrameTradeButton has no access constraints, is not forbidden and not protected
test("conform b: TradeFrameTradeButton: no access constraints (PF-065)", function()
	local w = T.newWorld()
	local r = T.rider(w, "Wuber Rocks")
	local b = r.env.TradeFrameTradeButton
	ok(b, "the button exists")
	eq(b:HasAccessConstraints(), false, "access constraints")
	T.clean(w)
end)

-- guard: PF-065 the button is not forbidden and not protected
test("conform b: TradeFrameTradeButton is not forbidden and not protected (PF-065)", function()
	local w = T.newWorld()
	local r = T.rider(w, "Wuber Rocks")
	local b = r.env.TradeFrameTradeButton
	eq(b:IsForbidden(), false, "forbidden")
	eq(b:IsProtected(), false, "protected")
	T.clean(w)
end)

-- guard: PF-059 (ANIM): an Alpha animation leaves GetAlpha / GetEffectiveAlpha at the from value while it plays, a
-- Translation moves nothing GetLeft says, a hidden frame keeps playing its group, OnUpdate does not run on a hidden one
test("conform b: animation facts: alpha stays at from, translation does not move, hidden plays, no OnUpdate hidden (PF-059)", function()
	local w = T.newWorld()
	local r = T.rider(w, "Wuber Rocks")
	w:advance(1)
	local e = r.env
	local f = e.CreateFrame("Frame", nil, e.UIParent)
	f:SetSize(50, 50)
	f:SetPoint("CENTER")
	f:Show()
	local g = f:CreateAnimationGroup()
	local a = g:CreateAnimation("Alpha")
	a:SetFromAlpha(1) a:SetToAlpha(0) a:SetDuration(0.4)
	local tr = g:CreateAnimation("Translation")
	tr:SetOffset(100, 0) tr:SetDuration(0.4)
	local l0 = f:GetLeft()
	g:Play()
	w:advance(0.2)
	eq(f:GetEffectiveAlpha(), 1, "alpha at mid: the from value")
	eq(f:GetLeft(), l0, "translation moves nothing")
	local par = e.CreateFrame("Frame", nil, e.UIParent)
	par:Hide()
	local c = e.CreateFrame("Frame", nil, par)
	local cg = c:CreateAnimationGroup()
	local ca = cg:CreateAnimation("Alpha")
	ca:SetFromAlpha(1) ca:SetToAlpha(0) ca:SetDuration(0.4)
	local n = 0
	c:SetScript("OnUpdate", function() n = n + 1 end)
	cg:Play()
	w:advance(0.15)
	eq(cg:IsPlaying(), true, "a hidden frame keeps playing")
	eq(n, 0, "OnUpdate does not run on a hidden frame")
	T.clean(w)
end)

-- guard: trade.* (default order is the real one, no tradeOrder needed) and forbidden.* (UNKNOWN()) are pinned in
-- tests/rec/real_trade_test.lua and real_forbidden_test.lua; this one pins the DEFAULT of a plain world
test("conform b: a plain world's trade ends with TRADE_CLOSED twice then PLAYER_MONEY (trade.close.double, trade.complete.order)", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local r = T.rider(w, "Wuber Rocks")
	w:advance(2)
	local got = {}
	local real = r.fire
	r.fire = function(self, ev, ...)
		if ev == "TRADE_CLOSED" or ev == "PLAYER_MONEY" then got[#got + 1] = ev end
		return real(self, ev, ...)
	end
	ok(w:openTrade(r, d))
	w:tradeMoney(r, 5000)
	w:tradeAccept(d)
	w:tradeAccept(r)
	w:advance(1)
	eq(table.concat(got, " "), "TRADE_CLOSED TRADE_CLOSED PLAYER_MONEY")
	r.fire = nil
	T.clean(w)
end)
