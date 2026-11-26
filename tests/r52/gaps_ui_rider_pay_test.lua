-- Final home: tests/ui/rider/pay_test.lua; add it to the per-module list in tests/run.lua.
-- Pins: the tip stops, only a stop can be saved, a bad saved tip reads as No tip, the tip is the fare's percent rounded UP to whole silver;
-- Pins: what to type (PayTotal): fare + tip, only what is left after a part payment, nothing for a free or missing ride;
-- Pins: the raincheck on a ride (cover, taken / refused / not answered) and its line ("covers 30s . type 20s", "nothing to pay");
-- Pins: the strip under the trade window (who to pay, how much to type, raincheck words, redrawn when the tip changes, gone when the trade closes);
-- Pins: a trade opened by a stranger mid-ride gets a warning and no "Type 50 in silver" strip; no strip before the arrival;
-- Pins: OpenForPay opens the window once per ride, never in combat (it waits for the end of the fight), and not for a free ride.
-- Why it matters to a player: this tells the rider how much gold to type into the driver's trade. If it broke, a rider would
-- pay the wrong amount, would be told to pay a stranger who opened a trade, or the app would not open when the driver is waiting.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local MIA = "Mia Runner"
local DOT = "\194\183" -- the middle dot in the strip's words

local function setup(opts)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, opts)
	w:advance(15)
	return w, r
end

-- the ride the suite's other pay tests use (tests/au24/proof_i_test.lua), set directly so no RIDE event opens the window
local function ride(r, over)
	local x = { id = "r6", driver = MIA, driverKey = "mia runner", dest = "Undercity", price = 5000, state = "arrived",
		at = r.env.GetTime(), payee = MIA, payto = "Mia", summoner = MIA, service = "Mia's Rides" }
	for k, v in pairs(over or {}) do x[k] = v end
	r.W.ride = x
	return x
end

local function has(r, text) return #r:findText(text, nil, true) > 0 end

local function toasts(r)
	local said = {}
	local UI = r.W.UI
	local toast = UI.Toast
	UI.Toast = function(text, ...) said[#said + 1] = tostring(text) return toast(text, ...) end
	return said
end

-- the driver (or anyone) opens a trade with the rider; the game's trade window is shown first (as AU24-08 does)
local function openTradeWith(w, r, name)
	if not w:player(name) then w:addBot(name, { spot = "Orgrimmar" }) end
	H.state[r.env.TradeFrame].shown = true
	ok(w:openTrade(w:player(name), r.player), name .. " opens the trade")
	w:advance(1.5)
end

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.pay: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("UI.Rider.Pay", "tests/ui/rider/pay_test.lua", {
		["UI.TIP_STOPS"] = "table", ["UI.TIP_QUICK"] = "table", ["UI.SetTipPct"] = "function", ["UI.TipPct"] = "function",
		["UI.TipFor"] = "function", ["UI.PayTotal"] = "function", ["UI.TradePartnerOK"] = "function",
		["UI.RaincheckCover"] = "function", ["UI.RaincheckLine"] = "function", ["UI.OpenForPay"] = "function",
	})
	ok(Mod, "W.Mod(\"UI.Rider.Pay\")")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.pay: the tip stops, and every quick pick is one of them", function()
	local w, r = setup()
	local UI = r.W.UI
	eq(table.concat(UI.TIP_STOPS, ","), "0,10,15,20,25,30,40,50,75,100", "the stops 0 to 100%") -- Pay.lua:37
	eq(table.concat(UI.TIP_QUICK, ","), "0,10,20", "No tip, 10%, 20%") -- Pay.lua:38
	for _, q in ipairs(UI.TIP_QUICK) do
		local found = false
		for _, s in ipairs(UI.TIP_STOPS) do if s == q then found = true end end
		ok(found, "quick pick " .. q .. " is a stop")
	end
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.pay: only a stop can be saved as the tip; anything else changes nothing", function()
	local w, r = setup()
	local UI, W = r.W.UI, r.W
	W.db.tipPct = 10
	eq(UI.SetTipPct(20), true, "20 is a stop") -- Pay.lua:42-51
	eq(W.db.tipPct, 20, "saved for the account")
	eq(UI.SetTipPct(12), false, "12 is not a stop")
	eq(UI.SetTipPct(-5), false, "negative")
	eq(UI.SetTipPct(101), false, "over 100")
	eq(UI.SetTipPct(7.5), false, "between stops")
	eq(W.db.tipPct, 20, "the refused values saved nothing")
	eq(UI.SetTipPct(100), true, "the top stop")
	eq(UI.SetTipPct(0), true, "No tip")
	eq(W.db.tipPct, 0, "saved as 0")
	eq(UI.SetTipPct(nil), true, "nothing given reads as No tip (N(nil) or 0)") -- Pay.lua:43
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.pay: a bad saved tip reads as No tip", function()
	local w, r = setup()
	local UI, W = r.W.UI, r.W
	W.db.tipPct = 15
	eq(UI.TipPct(), 15, "a saved stop is kept") -- Pay.lua:53-57
	W.db.tipPct = 12
	eq(UI.TipPct(), 0, "not a stop: 0")
	W.db.tipPct = -10
	eq(UI.TipPct(), 0, "negative: 0")
	W.db.tipPct = 101
	eq(UI.TipPct(), 0, "over 100: 0")
	W.db.tipPct = nil
	eq(UI.TipPct(), 0, "never chosen: 0")
	W.db.tipPct = 100
	eq(UI.TipPct(), 100, "the top stop")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.pay: the tip is the fare's percent rounded UP to a whole silver; an explicit 0 beats the saved tip", function()
	local w, r = setup()
	local UI, W = r.W.UI, r.W
	eq(UI.TipFor(5000, 10), 500, "10% of 50s = 5s") -- Pay.lua:63
	eq(UI.TipFor(5000, 15), 800, "15% of 50s = 7.5s, up to 8s")
	eq(UI.TipFor(7000, 15), 1100, "15% of 70s = 10.5s, up to 11s")
	eq(UI.TipFor(5000, 100), 5000, "100%")
	eq(UI.TipFor(10000, 10), 1000, "an exact silver stays exact (the 1e-9 guard)")
	eq(UI.TipFor(10001, 10), 1100, "one copper over rounds up a whole silver")
	eq(UI.TipFor(1, 10), 100, "a fare of 1 copper still tips 1s")
	eq(UI.TipFor(0, 10), 0, "a free ride: no tip")
	eq(UI.TipFor(-100, 10), 0, "a negative fare: no tip")
	eq(UI.TipFor(nil, 10), 0, "no fare: no tip")
	eq(UI.TipFor(5000, -10), 0, "a negative percent: no tip")
	W.db.tipPct = 20
	eq(UI.TipFor(5000), 1000, "no percent given: the saved one") -- Pay.lua:61
	eq(UI.TipFor(5000, 0), 0, "an explicit 0 is No tip, not the saved percent")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.pay: PayTotal is the fare plus the tip, only what is left after a part payment, nothing for a free ride", function()
	local w, r = setup()
	local UI, W = r.W.UI, r.W
	W.db.tipPct = 0
	eq(UI.PayTotal({ price = 5000 }), 5000, "no tip: the fare") -- Pay.lua:94-103
	W.db.tipPct = 10
	eq(UI.PayTotal({ price = 5000 }), 5500, "10% tip")
	eq(UI.PayTotal({ price = 0 }), 0, "a free ride asks for nothing, tip or not")
	eq(UI.PayTotal({ price = -5 }), 0, "a negative fare asks for nothing")
	eq(UI.PayTotal(nil), 0, "no ride")
	eq(UI.PayTotal({ price = 5000, raw = { paidSoFar = 2000 } }), 3500, "2000 already paid: 3000 left plus the tip on the whole fare (500)") -- Pay.lua:99-102
	eq(UI.PayTotal({ price = 5000, raw = { paidSoFar = 0 } }), 5500, "nothing paid yet")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.pay: RaincheckCover - cover, taken / refused / not answered, and what counts as none", function()
	local w, r = setup()
	local UI = r.W.UI
	eq(UI.RaincheckCover(nil), nil, "no ride") -- Pay.lua:71
	eq(UI.RaincheckCover("junk"), nil, "not a table")
	eq(UI.RaincheckCover({}), nil, "no voucher")
	eq(UI.RaincheckCover({ voucherCover = 3000 }), nil, "a cover without a voucher id")
	eq(UI.RaincheckCover({ voucher = "rc1" }), nil, "a voucher without a cover")
	eq(UI.RaincheckCover({ voucher = "rc1", voucherCover = 0 }), nil, "a cover of 0") -- Pay.lua:74
	eq(UI.RaincheckCover({ voucher = "rc1", voucherCover = -5 }), nil, "a negative cover")
	local c, taken, id = UI.RaincheckCover({ voucher = "rc1", voucherCover = 3000 })
	eq(c, 3000, "the cover")
	eq(taken, nil, "the driver has not answered")
	eq(id, "rc1", "the id")
	c, taken = UI.RaincheckCover({ raw = { voucher = "rc1", voucherCover = 3000, voucherTaken = true } })
	eq(taken, true, "taken (read through the ride view's raw)") -- Pay.lua:71, 76
	c, taken = UI.RaincheckCover({ voucher = "rc1", voucherCover = 3000, voucherRefused = true })
	eq(taken, false, "refused")
	c, taken = UI.RaincheckCover({ voucher = "rc1", voucherCover = 3000, voucherTaken = true, voucherRefused = true })
	eq(taken, true, "both set: taken wins") -- Pay.lua:76
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.pay: RaincheckLine says what it covers and what is left to type, and nothing before the driver answers", function()
	local w, r = setup()
	local UI, W = r.W.UI, r.W
	W.db.tipPct = 0
	eq(UI.RaincheckLine({ price = 5000 }), nil, "no raincheck: no line") -- Pay.lua:82-90
	eq(UI.RaincheckLine({ price = 5000, voucher = "rc1", voucherCover = 3000 }), nil, "not answered yet: no line")
	eq(UI.RaincheckLine({ price = 5000, voucher = "rc1", voucherCover = 3000, voucherRefused = true }), "Raincheck not taken: normal fare", "refused")
	eq(UI.RaincheckLine({ price = 2000, fare = 5000, voucher = "rc1", voucherCover = 3000, voucherTaken = true }),
		"Raincheck covers 30s " .. DOT .. " type 20s", "taken: 30s of the 50s fare covered, 20s due") -- Pay.lua:89
	eq(UI.RaincheckLine({ price = 0, fare = 5000, voucher = "rc1", voucherCover = 8000, voucherTaken = true }),
		"Raincheck covers 50s " .. DOT .. " nothing to pay", "a cover bigger than the fare is capped at the fare")
	eq(UI.RaincheckLine({ price = 5000, voucher = "rc1", voucherCover = 3000, voucherTaken = true }),
		"Raincheck covers 30s " .. DOT .. " type 50s", "no separate fare: the price is the fare") -- Pay.lua:87
	W.db.tipPct = 10
	eq(UI.RaincheckLine({ price = 2000, fare = 5000, voucher = "rc1", voucherCover = 3000, voucherTaken = true }),
		"Raincheck covers 30s " .. DOT .. " type 22s", "the tip is on what is due: 20s + 2s")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.pay: TradePartnerOK - the driver, the payee and a crew name are right; a stranger is wrong; no trade says nothing", function()
	local w, r = setup()
	local UI = r.W.UI
	ride(r, { payee = "Bea Jones", summoner = "Bea Jones" })
	local rv = UI.Ride()
	local okp, partner = UI.TradePartnerOK(rv)
	eq(okp, nil, "no trade open: the game didn't say") -- Pay.lua:126
	eq(partner, nil, "no partner")
	openTradeWith(w, r, MIA)
	okp, partner = UI.TradePartnerOK(rv)
	eq(okp, true, "the driver's trade") -- Net/Rides.lua:768-779 (W.RideTrader)
	eq(partner, "mia runner", "the partner's key")
	w:tradeCancel(w:player(MIA))
	w:advance(1)
	openTradeWith(w, r, "Sly Fox")
	okp, partner = UI.TradePartnerOK(rv)
	eq(okp, false, "a stranger's trade is not the driver's")
	eq(partner, "sly fox", "the stranger's key")
	w:tradeCancel(w:player("Sly Fox"))
	w:advance(1)
	openTradeWith(w, r, "Bea Jones")
	okp = UI.TradePartnerOK(rv)
	eq(okp, true, "the payee the driver named may be paid") -- Pay.lua:129
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.pay: the driver's trade shows the strip: who to pay and what to type, tip included", function()
	local w, r = setup()
	local UI, W = r.W.UI, r.W
	ride(r)
	W.db.tipPct = 0
	openTradeWith(w, r, MIA)
	ok(has(r, "Wuber: Pay Mia. Type 50 in silver, then click Trade."), "the strip (" .. T.list(r:visibleTexts()):sub(1, 400) .. ")") -- Pay.lua:166, Net/Rides.lua:740
	-- the tip changes under the open trade: the strip is redrawn
	UI.SetTipPct(20)
	w:advance(0.5)
	ok(has(r, "Wuber: Pay Mia. Type 60 in silver, then click Trade."), "20% of 50s is 10s more: type 60") -- Pay.lua:49
	ok(not has(r, "Type 50 in silver"), "the old amount is gone")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.pay: the strip carries the raincheck words; fully covered says nothing to pay", function()
	local w, r = setup()
	local W = r.W
	W.db.tipPct = 0
	ride(r, { price = 2000, fare = 5000, voucher = "rc1", voucherCover = 3000, voucherTaken = true })
	openTradeWith(w, r, MIA)
	ok(has(r, "Wuber: Pay Mia. Raincheck covers 30s " .. DOT .. " type 20s. Type 20 in silver, then click Trade."), "part covered (" .. T.list(r:visibleTexts()):sub(1, 400) .. ")") -- Pay.lua:166
	w:tradeCancel(w:player(MIA))
	w:advance(1)
	ride(r, { price = 0, fare = 5000, voucher = "rc1", voucherCover = 5000, voucherTaken = true })
	openTradeWith(w, r, MIA)
	ok(has(r, "Wuber: Raincheck covers 50s " .. DOT .. " nothing to pay"), "all covered: no 'Type' line") -- Pay.lua:163-164
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.pay: a stranger's trade mid-ride gets a warning toast and no pay strip", function()
	local w, r = setup()
	ride(r)
	local said = toasts(r)
	openTradeWith(w, r, "Sly Fox")
	local warned = false
	for _, t in ipairs(said) do
		if t:find(" isn't your driver or crew. Don't pay this trade: pay Mia.", 1, true) then warned = true end -- Pay.lua:145
	end
	ok(warned, "the warning names who to pay (" .. table.concat(said, " | ") .. ")")
	ok(not has(r, "Wuber: "), "no strip under a stranger's trade")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.pay: no strip before the arrival, none for a paid ride, and it goes when the trade closes", function()
	local w, r = setup()
	ride(r, { state = "summoning" })
	openTradeWith(w, r, MIA)
	ok(not has(r, "Wuber: "), "summoning: nothing to pay yet") -- Pay.lua:115
	w:tradeCancel(w:player(MIA))
	w:advance(1)
	ride(r, { state = "arrived", paid = 5000 })
	openTradeWith(w, r, MIA)
	ok(not has(r, "Wuber: "), "already paid: no strip") -- Pay.lua:117
	w:tradeCancel(w:player(MIA))
	w:advance(1)
	ride(r, { state = "paying" })
	openTradeWith(w, r, MIA)
	ok(has(r, "Wuber: Pay Mia."), "paying: the strip")
	w:tradeCancel(w:player(MIA))
	w:advance(1)
	ok(not has(r, "Wuber: "), "the trade closed: the strip is gone") -- Pay.lua:251
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.pay: OpenForPay opens the window on arrival once per ride, and not for a free ride or no ride", function()
	local w, r = setup()
	local UI = r.W.UI
	if UI.IsShown() then UI.Toggle() w:advance(1) end
	ok(not UI.IsShown(), "control: the window is closed")
	eq(UI.OpenForPay("arrived"), false, "no ride: nothing to open") -- Pay.lua:207
	ride(r, { price = 0 })
	eq(UI.OpenForPay("arrived"), false, "a free ride: nothing due, nothing opens") -- Pay.lua:208
	ride(r)
	eq(UI.OpenForPay("arrived"), true, "arrived with a fare due: it opens") -- Pay.lua:228-237
	w:advance(2)
	ok(UI.IsShown(), "the window is up")
	UI.Toggle()
	w:advance(1)
	ok(not UI.IsShown(), "the rider closes it")
	eq(UI.OpenForPay("arrived"), false, "once per ride") -- Pay.lua:209
	ride(r, { id = "r7" })
	eq(UI.OpenForPay("junk"), true, "any other reason counts as arrived, and a new ride opens again") -- Pay.lua:242
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.pay: OpenForPay never opens in a fight; it waits and opens when the fight ends", function()
	local w, r = setup()
	local UI = r.W.UI
	if UI.IsShown() then UI.Toggle() w:advance(1) end
	ride(r)
	w:enterCombat(r)
	w:advance(1)
	eq(UI.OpenForPay("arrived"), false, "in combat: not now") -- Pay.lua:215-226
	ok(not UI.IsShown(), "the window stays shut in the fight")
	w:leaveCombat(r)
	w:advance(2)
	ok(UI.IsShown(), "opened when combat ended (it was still wanted)") -- Pay.lua:220-224
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.pay: a window already open is left alone and counts as the arrival open", function()
	local w, r = setup()
	local UI = r.W.UI
	UI.Toggle(true)
	w:advance(2)
	ok(UI.IsShown(), "control: open")
	ride(r)
	eq(UI.OpenForPay("arrived"), false, "already open: nothing to do") -- Pay.lua:210-213
	UI.Toggle()
	w:advance(1)
	eq(UI.OpenForPay("arrived"), false, "and it is not opened later for the same ride") -- Pay.lua:211
	T.clean(w)
end)
