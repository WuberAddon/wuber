-- Module: UI.Rider.Pay
-- Purpose: Tips (UI.TIP_STOPS, UI.SetTipPct, UI.TipFor, UI.PayTotal) and the how-to-pay strip under the
--   trade window (UI.TradePartnerOK).
-- API: UI.TIP_STOPS, UI.TIP_QUICK, UI.SetTipPct, UI.TipPct, UI.TipFor, UI.PayTotal, UI.TradePartnerOK,
--   UI.RaincheckCover, UI.RaincheckLine, UI.OpenForPay
-- Internals: tradePayWanted, showTradePay, openForPay (the app opens on the ride's pay screen)
-- Uses: UI.Kit
-- Later: (none)
-- Events: listens On TRADE_SHOW, Listen RIDE (shows the strip while a trade is open), On TRADE_CLOSED; fires (none)
--   (UI.Moments calls UI.OpenForPay("arrived") from its RIDE toast)
-- Standalone: no
-- Test: tests/ui/rider/pay_test.lua
-- From: UI.lua 2904-2944, 5295-5376 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Rider.Pay", { "UI.Kit" })
local KitMod = W.Mod("UI.Kit")
local N = KitMod.N
local S = KitMod.S
local call = KitMod.call
local inCombat = KitMod.inCombat
local rideActive = KitMod.rideActive
local rideView = KitMod.rideView
local ui = KitMod.ui
local T = W.Theme
local Try = T.Try
local UI = W.UI

---------------------------------------------------------------------------
-- Screen: Driver found (accepted to paying)
---------------------------------------------------------------------------

-- The tip (Uber-style, the author 18 Nov; buttons, the author's 04 v1 pick): No tip, 10%, 20% or Custom
-- (the stops 0 to 100%), rounded up to whole silver; the last choice is remembered for the
-- account (W.db.tipPct). The total drives every "what to type" line. The rider still types
-- the gold; Wuber never puts it in the trade.
UI.TIP_STOPS = { 0, 10, 15, 20, 25, 30, 40, 50, 75, 100 }
UI.TIP_QUICK = { 0, 10, 20 }

local showTradePay -- defined below; a tip picked under an open trade redraws the strip

function UI.SetTipPct(pct)
	pct = N(pct) or 0
	local okStop = false
	for _, x in ipairs(UI.TIP_STOPS) do if x == pct then okStop = true end end
	if not okStop then return false end
	if W.db then W.db.tipPct = pct end
	UI.Refresh(true)
	W.Safe("trade pay", showTradePay)
	return true
end

function UI.TipPct()
	local p = N(W.db and W.db.tipPct) or 0
	for _, x in ipairs(UI.TIP_STOPS) do if x == p then return p end end
	return 0
end

-- the tip in copper for a fare at pct (whole silver, rounded up)
function UI.TipFor(price, pct)
	price, pct = N(price) or 0, N(pct) or UI.TipPct()
	if price <= 0 or pct <= 0 then return 0 end
	return math.ceil(price * pct / 100 / 100 - 1e-9) * 100
end

-- A raincheck on this ride (Net.Rides keeps W.ride.voucher, .voucherCover,
-- .voucherTaken / .voucherRefused from the driver's A, and .fare = the full fare while .price is
-- what is due): cover (copper), taken (true: the driver's book took it; false: it didn't, normal
-- fare; nil: not answered yet), id. nil when the ride carries none.
function UI.RaincheckCover(rv)
	local r = type(rv) == "table" and (rv.raw or rv) or nil
	if not r or not S(r.voucher) then return nil end
	local cover = N(r.voucherCover)
	if not cover or cover <= 0 then return nil end
	local taken = nil
	if W.Plain(r.voucherTaken) == true then taken = true elseif W.Plain(r.voucherRefused) == true then taken = false end
	return cover, taken, S(r.voucher)
end

-- "Raincheck covers 50s · nothing to pay" / "Raincheck covers 40s · type 10s" / "Raincheck not
-- taken: normal fare"; nil without one (or before the driver answered).
function UI.RaincheckLine(rv)
	local cover, taken = UI.RaincheckCover(rv)
	if not cover or taken == nil then return nil end
	if not taken then return "Raincheck not taken: normal fare" end
	local r = rv.raw or rv
	local fare = N(r.fare) or N(rv.price) or 0
	local due = UI.PayTotal(rv)
	return "Raincheck covers " .. W.Money(math.min(cover, fare)) .. " · " .. (due > 0 and ("type " .. W.Money(due)) or "nothing to pay")
end

-- what to type for a ride: what is due (the fare, less a raincheck the driver took: Net.Rides
-- already put that in the ride's price) plus the chosen tip
function UI.PayTotal(rv)
	local price = rv and N(rv.price) or 0
	if price <= 0 then return 0 end
	-- part already paid (a trade that took only some of it): only what is left, plus the tip as before
	local raw = rv and type(rv.raw) == "table" and rv.raw or nil
	local paid = raw and N(raw.paidSoFar) or 0
	local left = price
	if paid > 0 and paid < price then left = price - paid end
	return left + UI.TipFor(price)
end

---------------------------------------------------------------------------
-- How to pay, right under the trade window: after the summon the app is usually closed, so
-- when the driver's trade opens during a ride a gold strip under the game's trade window says
-- exactly what to type ("Type 50 in silver, then click Trade"). It is only words: the game
-- lets only the player put gold in a trade.
---------------------------------------------------------------------------

local tradePay
local function tradePayWanted()
	local rv = rideView()
	if not rv or not (rv.state == "arrived" or rv.state == "paying") then return nil end
	local covered = UI.RaincheckCover(rv)
	if not ((rv.price or 0) > 0 or covered) or rv.raw and rv.raw.paid then return nil end
	return rv
end

-- Who opened the trade (review #3, 2.2 #1): true = the driver, the summoner to pay, or a crew
-- member the driver named (never just anyone in the group: other riders are in it too);
-- false = anyone else; nil = the game didn't say.
function UI.TradePartnerOK(rv)
	local partner = W.Key(S(call(W.UnitName, "npc")))
	if not partner then return nil, nil end
	local r = rv and rv.raw or {}
	if type(W.RideTrader) == "function" then return call(W.RideTrader, r, partner) == true, partner end
	for _, f in ipairs({ "driverKey", "driver", "payee", "summoner", "summonedBy" }) do
		if S(r[f]) and W.Key(r[f]) == partner then return true, partner end
	end
	return false, partner
end

function showTradePay()
	local tf = TradeFrame
	if type(tf) ~= "table" or type(tf.IsShown) ~= "function" or W.Plain(call(tf.IsShown, tf)) ~= true then return end
	local rv = tradePayWanted()
	local okPartner, partner = UI.TradePartnerOK(rv or rideView())
	if okPartner == false and rideActive(rideView()) then
		-- a stranger opened trade mid-ride: no "Type 50 in silver" under their trade, a warning
		if tradePay then tradePay:Hide() end
		local raw = (rv or rideView() or {}).raw or {}
		local payTo = S(raw.payto) or (S(raw.driver) and W.Short(raw.driver)) or "your driver"
		UI.Toast(W.Short(S(call(W.UnitName, "npc")) or partner) .. " isn't your driver or crew. Don't pay this trade: pay " .. payTo .. ".", "warn")
		return
	end
	if not rv then
		if tradePay then tradePay:Hide() end
		return
	end
	if not tradePay then
		-- (Design 2) the main button's height, the width of the trade window it hangs under (it cannot sit over the trade)
		tradePay = T.Pill(tf, "", "primary", tonumber((tf.GetWidth and tf:GetWidth())) or 330, T.MAIN.h)
		tradePay:SetPoint("TOPLEFT", tf, "BOTTOMLEFT", 0, -8)
		tradePay:SetPoint("TOPRIGHT", tf, "BOTTOMRIGHT", 0, -8)
		tradePay:SetHeight(T.MAIN.h)
		tradePay:SetFrameStrata("DIALOG")
		Try(tradePay, "EnableMouse", false)
	end
	local total = UI.PayTotal(rv)
	local rcLine = UI.RaincheckLine(rv)
	if total <= 0 and rcLine then
		tradePay:SetLabel("Wuber: " .. rcLine)
	else
		tradePay:SetLabel("Wuber: " .. (rv.payto and ("Pay " .. rv.payto .. ". ") or "") .. (rcLine and (rcLine .. ". ") or "") .. W.FareSteps(total))
	end
	tradePay:Show()
	-- what the summon really costs against flying (under the strip; hidden without data)
	local line = UI.FlightLine and UI.FlightLine(rv)
	if line then
		if not tradePay.flight then
			-- a dark band (it sits over the game world), gold words
			local fb = CreateFrame("Frame", nil, tradePay)
			fb:SetSize(330, 24)
			fb:SetPoint("TOP", tradePay, "BOTTOM", 0, -4)
			fb.bg = T.Rounded(fb, { 0.07, 0.07, 0.13, 0.92 }, 12, "BACKGROUND", 0)
			fb.text = T.Text(fb, "caption", "gold", "CENTER", "medium")
			fb.text:SetPoint("CENTER", fb, "CENTER", 0, 0)
			fb.text:SetWidth(318)
			tradePay.flight = fb
		end
		tradePay.flight.text:SetText(line)
		tradePay.flight:Show()
	elseif tradePay.flight then
		tradePay.flight:Hide()
	end
end

---------------------------------------------------------------------------
-- The app opens on the ride's pay screen (the author's test, 18 Nov #1: "Wuber didn't open for the
-- passenger when he got there"). On arrival with something still due, once per ride; when the
-- driver's (or the payee's) trade opens with something due. Never in combat (it opens when combat
-- ends, if still wanted); a window already open is left as it is; an open trade keeps its
-- keyboard focus (the player types the gold there: Wuber only says what to type).
---------------------------------------------------------------------------

local payOpened = {} -- ride id -> true (the arrival open happened, or the window was already open)
local payWaiting -- a combat-deferred open is queued: the reason it will run with ("arrived" outranks "trade")

local function tradeOpen()
	local tf = TradeFrame
	return type(tf) == "table" and type(tf.IsShown) == "function" and W.Plain(call(tf.IsShown, tf)) == true
end

local function openForPay(why)
	local rv = tradePayWanted()
	if not rv or (N(rv.price) or 0) <= 0 then return false end
	if why == "arrived" and payOpened[rv.id] then return false end
	if UI.IsShown and UI.IsShown() then
		payOpened[rv.id] = true
		return false
	end
	if why == "trade" and UI.TradePartnerOK(rv) ~= true then return false end
	if inCombat() then
		-- an arrival that comes while a trade open waits takes its place (that trade may be closed by then)
		local queued = payWaiting
		if why == "arrived" then payWaiting = "arrived" else payWaiting = payWaiting or why end
		if not queued then
			W.AfterCombat(function()
				local reason = payWaiting or why
				payWaiting = nil
				openForPay(reason)
			end)
		end
		return false
	end
	payOpened[rv.id] = true
	-- the ride's own screen, not a look at Home or a dismissed view
	ui.peek = nil
	if type(ui.dismissed) == "table" then ui.dismissed[rv.id] = nil end
	if ui.settingsOpen and UI.CloseSettings then UI.CloseSettings(true) end
	UI.Toggle(true)
	if ui.tab ~= "Ride" and UI.SelectTab then UI.SelectTab("Ride") end
	-- (no edit box of the pay screen takes the keyboard: an open trade's gold box keeps it)
	UI.Refresh(true)
	return true
end

-- UI.OpenForPay("arrived" | "trade"): true when it opened the window now.
function UI.OpenForPay(why)
	return openForPay(why == "trade" and "trade" or "arrived")
end

W.On("TRADE_SHOW", function()
	W.After(0.15, function()
		W.Safe("trade pay", showTradePay)
		if tradeOpen() then W.Safe("pay open", openForPay, "trade") end
	end)
end)
-- (AU24-08) the arrival can be noticed after the 0.15 s look above: show the strip when the ride changes with a trade open
W.Listen("RIDE", function()
	if tradeOpen() then W.Safe("trade pay", showTradePay) end
end)
W.On("TRADE_CLOSED", function()
	if tradePay then tradePay:Hide() end
end)
