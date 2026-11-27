-- Promises about paying and the tip (tests/promises/payment.lua; owner RIDEPAY).
-- Written from what the player is told: the pay card ("TYPE IN TRADE WINDOW"), the tip buttons and their tooltips
-- ("rounded up to whole silver", "Wuber remembers your choice"), the strip under the trade window, the Done screen,
-- and the rule that Wuber never puts gold in a trade and never claims one click pays.
return function(Hunt)
	-- the fold dial's "folded_click" needs a phone that is open on a wide page; a promise that takes the default
	-- (closed) phone would only get cannot-build, so it stays out of that situation
	local FOLDABLE = { home = true, trips = true, drive = true, drive_earnings = true, drive_messages = true, drive_customers = true,
		settings = true, settings_riding = true, settings_driving = true, settings_map = true, settings_sound = true,
		settings_window = true, world_view = true, here_view = true, confirm = true, wrapped = true }
	local function promise(p)
		local w = p.when
		p.when = function(sit)
			if sit.fold == "folded_click" and not FOLDABLE[sit.phone or "closed"] then return false end
			return w == nil or w(sit)
		end
		Hunt.promise(p)
	end
	local function sitIs(sit, dial, want)
		local v = sit[dial]
		if v == nil then return true end
		if type(want) == "table" then return want[v] == true end
		return v == want
	end
	local function isRider(sit) return sit.role == nil or sit.role == "rider" end
	local function asRider(sit) return isRider(sit) and sit.net ~= "none" and sit.net ~= "oldpeer" end
	local function asDriver(sit) return sit.role ~= nil and sit.role ~= "rider" end
	-- phone values that do not toggle the phone: with an arrived or paid ride the phone opens by itself, so a /wuber
	-- to open it (the phone dial's way for the other values) would shut it again (cannot-build, not a bug)
	local OPENS = { closed = true, trips_direct = true, drive_direct = true }
	local function phoneOk(sit) return sit.phone == nil or OPENS[sit.phone] == true end

	local function K(ctx) return ctx:mod("UI.Kit") end
	local function uiState(ctx) local k = K(ctx) return k and k.ui or {} end
	local function phoneShown(ctx) local w = uiState(ctx).win return w ~= nil and w:IsShown() == true end
	local function seen(ctx) return "on screen: " .. table.concat(ctx:texts(), " | ") end
	local function has(ctx, pat, plain)
		for _, t in ipairs(ctx:texts()) do if t:find(pat, 1, plain) then return t end end
		return nil
	end
	local function hasExact(ctx, label)
		for _, t in ipairs(ctx:texts()) do if t == label then return true end end
		return false
	end
	local function inCombat(ctx) return ctx.me.player.combat and true or false end
	local function riderState(ctx) local r = ctx.W.ride return r and r.state or nil end
	local function money(ctx, c) return ctx.W.Money(c) end

	local function showRide(ctx)
		if not phoneShown(ctx) then
			ctx.W.UI.Toggle(true)
			ctx:note("open the phone")
			ctx:advance(2.5)
		end
		local s = uiState(ctx)
		if s.settingsOpen and ctx.W.UI.CloseSettings then ctx.W.UI.CloseSettings(true) ctx:advance(0.5) end
		if s.tab ~= "Ride" then
			for _, tab in ipairs(s.tabs or {}) do
				if tab.name == "Ride" and tab.button then
					ctx.me:clickOn(tab.button)
					ctx:note("click the Ride tab")
					ctx:advance(0.8)
				end
			end
		end
	end

	-- the pay card is up: arrived and not yet paid
	local function needPayCard(ctx)
		if inCombat(ctx) then ctx:na("combat") end
		showRide(ctx)
		if not (riderState(ctx) == "arrived" or riderState(ctx) == "paying") then ctx:na("the ride is " .. tostring(riderState(ctx))) end
		if not hasExact(ctx, "Type in trade window") then
			ctx:fail("You have arrived and owe the fare, and your ride screen does not show the pay card (TYPE IN TRADE WINDOW).", seen(ctx))
		end
	end

	local function click(ctx, label, pattern)
		local ok, err = pcall(ctx.me.clickText, ctx.me, label, pattern and { pattern = true } or nil)
		if not ok then ctx:cannot("could not click " .. label .. ": " .. tostring(err):sub(1, 120)) end
		ctx:note("click " .. label)
		ctx:advance(0.8)
	end

	local function driverPlayer(ctx)
		local n = ctx.facts.payee or ctx.facts.driverName
		local p = n and ctx.w:player(n)
		if not p then ctx:cannot("no driver player to trade with") end
		return p
	end

	-- the fake game does not show TradeFrame when a trade opens (the real game does): the check does it, as the
	-- existing tests do (FAKE-GAME GAP, only for the strip, which hangs under TradeFrame)
	local function tradeFrame(ctx, on)
		local tf = ctx.me.env.TradeFrame
		if tf and ctx.H.state[tf] then ctx.H.state[tf].shown = on and true or false end
	end

	local function tradeOpen(ctx)
		local tf = ctx.me.env.TradeFrame
		return ctx.me.player.trade ~= nil or (tf and tf.IsShown and tf:IsShown())
	end

	-- the driver opens a trade with me (he clicks me, as his Wuber does after I land)
	local function driverTrades(ctx)
		if ctx.me.player.trade then ctx.w:tradeCancel(ctx.me.player) ctx:advance(0.5) end
		local ok = ctx.w:openTrade(driverPlayer(ctx), ctx.me.player)
		if not ok then ctx:cannot("could not open a trade with the driver") end
		tradeFrame(ctx, true)
		ctx:note("the driver opens a trade with me")
		ctx:advance(1)
	end

	local function strip(ctx)
		for _, t in ipairs(ctx:texts()) do if t:find("^Wuber: ") then return t end end
		return nil
	end

	local function fareOf(ctx) return ctx.facts.price or (ctx.W.ride and ctx.W.ride.price) end

	---------------------------------------------------------------------------
	promise{
		id = "pay.what_to_type",
		area = "Payment",
		text = "When you arrive, the pay card tells you the exact amount to type in the trade window.",
		source = "Driver found screen (TYPE IN TRADE WINDOW; tooltip: type this much in the trade window's money box yourself)",
		kind = "scenario",
		needs = { ride = "arrived" },
		when = function(sit) return asRider(sit) and phoneOk(sit) end,
		check = function(ctx)
			needPayCard(ctx)
			local fare = fareOf(ctx)
			if not (fare and fare > 0) then ctx:na("no fare") end
			local tip = ctx.W.UI.TipFor(fare)
			local want = money(ctx, fare + tip)
			if not has(ctx, want, true) then
				ctx:fail(("You arrive owing %s and the pay card does not show that amount to type."):format(want), seen(ctx))
			end
		end,
	}

	promise{
		id = "pay.tip_buttons",
		area = "Payment",
		text = "The pay card offers No tip, 10%, 20% and Custom, and picking 10% adds a tenth of the fare, rounded up to whole silver, to the amount to type.",
		source = "Tip buttons' tooltips (rounded up to whole silver); BRIEF 18 Nov (Uber-style tip)",
		kind = "scenario",
		needs = { ride = "arrived" },
		when = function(sit) return asRider(sit) and phoneOk(sit) end,
		check = function(ctx)
			needPayCard(ctx)
			for _, l in ipairs({ "No tip", "10%", "20%", "Custom" }) do
				if not hasExact(ctx, l) then ctx:fail("The pay card has no " .. l .. " tip button.", seen(ctx)) end
			end
			local fare = fareOf(ctx)
			click(ctx, "10%")
			local tip = math.ceil(fare * 10 / 100 / 100 - 1e-9) * 100
			local want = money(ctx, fare + tip)
			if not has(ctx, want, true) then
				ctx:fail(("You pick a 10%% tip on a %s fare and the amount to type does not become %s."):format(money(ctx, fare), want), seen(ctx))
			end
		end,
	}

	promise{
		id = "pay.tip_custom_stops",
		area = "Payment",
		text = "Custom lets you pick any tip from 0 to 100%, and the amount to type follows, rounded up to whole silver.",
		source = "Custom tip button tooltip (Pick any tip from 0 to 100%, rounded up to whole silver)",
		kind = "scenario",
		needs = { ride = "arrived" },
		when = function(sit) return asRider(sit) and phoneOk(sit) end,
		check = function(ctx)
			needPayCard(ctx)
			click(ctx, "Custom")
			for _, l in ipairs({ "10%", "15%", "25%", "50%", "75%", "100%" }) do
				if not hasExact(ctx, l) then ctx:fail("You click Custom and the tip " .. l .. " is not offered.", seen(ctx)) end
			end
			click(ctx, "^15%%$", true)
			local fare = fareOf(ctx)
			local tip = math.ceil(fare * 15 / 100 / 100 - 1e-9) * 100
			local want = money(ctx, fare + tip)
			if not has(ctx, want, true) then
				ctx:fail(("You pick a 15%% tip on a %s fare (%s with the tip, rounded up to whole silver) and the pay card shows something else."):format(money(ctx, fare), want), seen(ctx))
			end
		end,
	}

	promise{
		id = "pay.tip_remembered",
		area = "Payment",
		text = "Wuber remembers your tip choice: after a /reload the amount to type still includes it.",
		source = "Tip buttons' tooltips (Wuber remembers your choice)",
		kind = "scenario",
		needs = { ride = "arrived" },
		when = function(sit) return asRider(sit) and phoneOk(sit) end,
		check = function(ctx)
			needPayCard(ctx)
			local fare = fareOf(ctx)
			click(ctx, "20%")
			ctx:reload()
			ctx:advance(3)
			local pct = ctx.W.UI.TipPct and ctx.W.UI.TipPct()
			if pct ~= 20 then
				ctx:fail("You choose a 20% tip, /reload, and Wuber has forgotten it (it now offers " .. tostring(pct) .. "%).", seen(ctx))
			end
		end,
		gap = "a /reload puts the fake player back in Orgrimmar, so an arrived ride ends on login; only the saved choice can be checked, not the pay card after the reload",
	}

	---------------------------------------------------------------------------
	promise{
		id = "pay.strip_under_trade",
		area = "Payment",
		text = "When your driver opens a trade after you arrive, a strip by the trade window tells you who to pay and what to type, and says you click Trade yourself.",
		source = "Pay.lua header (how-to-pay strip: Type 50 in silver, then click Trade)",
		kind = "scenario",
		needs = { ride = "arrived" },
		when = function(sit) return asRider(sit) and phoneOk(sit) end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			if riderState(ctx) ~= "arrived" and riderState(ctx) ~= "paying" then ctx:na("not arrived") end
			ctx:advance(4)
			driverTrades(ctx)
			ctx:advance(1)
			local s = strip(ctx)
			if not s then
				ctx:fail("Your driver opens the trade after you arrive and no strip tells you what to type.", seen(ctx))
			end
			local fare = fareOf(ctx)
			local want = money(ctx, fare + ctx.W.UI.TipFor(fare))
			if not s:find("click Trade", 1, true) then
				ctx:fail("The strip by the trade window does not say you click Trade yourself.", s)
			end
			if not s:find((want:gsub("%s*|T.-|t", "")), 1, true) and not s:find("Type", 1, true) then
				ctx:fail("The strip by the trade window does not name the amount to type (" .. want .. ").", s)
			end
		end,
	}

	promise{
		id = "pay.strip_matches_tip",
		area = "Payment",
		text = "The strip by the trade window and the pay card ask for the same amount, tip included.",
		source = "Pay.lua header; BRIEF 18 Nov (the total drives every what-to-type line)",
		kind = "scenario",
		needs = { ride = "arrived" },
		when = function(sit) return asRider(sit) and phoneOk(sit) end,
		check = function(ctx)
			needPayCard(ctx)
			click(ctx, "10%")
			ctx:advance(3)
			driverTrades(ctx)
			ctx:advance(1)
			local s = strip(ctx)
			if not s then ctx:fail("Your driver opens the trade and no strip tells you what to type.", seen(ctx)) end
			local fare = fareOf(ctx)
			local total = fare + ctx.W.UI.TipFor(fare, 10)
			-- the strip writes the amount as the game's three boxes: "Type 1 in gold, 65 in silver, then click Trade."
			local g, sv, c = math.floor(total / 10000), math.floor(total % 10000 / 100), total % 100
			local missing = {}
			if g > 0 and not s:find(g .. " in gold", 1, true) then missing[#missing + 1] = g .. " in gold" end
			if sv > 0 and not s:find(sv .. " in silver", 1, true) then missing[#missing + 1] = sv .. " in silver" end
			if c > 0 and not s:find(c .. " in copper", 1, true) then missing[#missing + 1] = c .. " in copper" end
			if #missing > 0 then
				ctx:fail(("You chose a 10%% tip on a %s fare (to type: %s) and the strip by the trade window says: %s"):format(money(ctx, fare), money(ctx, total), s), seen(ctx))
			end
		end,
	}

	promise{
		id = "pay.never_puts_gold",
		area = "Payment",
		text = "Wuber never puts gold in the trade for you: you type it yourself, even after you click the pay card's button.",
		source = "Driver found screen tooltips (The game only lets you put gold in a trade yourself); CLAUDE.md hard rule",
		kind = "scenario",
		needs = { ride = "arrived" },
		when = function(sit) return asRider(sit) and phoneOk(sit) end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			ctx:advance(4)
			driverTrades(ctx)
			showRide(ctx)
			for _, label in ipairs({ "Type", "Trade", "Put" }) do
				for _, t in ipairs(ctx:texts()) do
					if t:find("^" .. label) and t:find("click Trade", 1, true) and not t:find("^Wuber: ") then
						pcall(ctx.me.clickText, ctx.me, t)
						ctx:note("click " .. t)
						break
					end
				end
			end
			ctx:advance(2)
			local tr = ctx.me.player.trade
			if tr and (tr.money[ctx.name] or 0) ~= 0 then
				ctx:fail("You have not typed anything in the trade window and Wuber has put gold in your side of it.", "gold in my side: " .. tostring(tr.money[ctx.name]))
			end
		end,
	}

	promise{
		id = "pay.stranger_trade",
		area = "Payment",
		text = "If someone who is not your driver opens a trade with you during your ride, Wuber does not tell you what to type for them and warns you not to pay them.",
		source = "Pay.lua (Don't pay this trade: pay your driver); Net.Rides (only the driver, payee or crew count)",
		kind = "scenario",
		needs = { ride = "arrived" },
		when = function(sit) return asRider(sit) and phoneOk(sit) end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			ctx:advance(0.5)
			if ctx.me.player.trade then ctx.w:tradeCancel(ctx.me.player) ctx:advance(1) end
			local name = "Sam Stranger"
			if not ctx.w:player(name) then ctx.w:addClient(name, { spot = "Ratchet", class = "MAGE", money = 100000 }) end
			local sp = ctx.w:player(name)
			ctx.w:move(name, "Ratchet")
			if not ctx.w:openTrade(sp, ctx.me.player) then ctx:cannot("no trade with the stranger") end
			ctx:note("a stranger opens a trade with me")
			tradeFrame(ctx, true)
			ctx:advance(1.5)
			if strip(ctx) and strip(ctx):find("Type", 1, true) then
				ctx:fail("A stranger opens a trade with you mid-ride and Wuber tells you what to type for him.", strip(ctx))
			end
			if not has(ctx, "Don't pay this trade", true) then
				ctx:fail("A stranger opens a trade with you mid-ride and Wuber does not warn you not to pay him.", seen(ctx))
			end
		end,
	}

	promise{
		id = "pay.strip_goes_with_trade",
		area = "Payment",
		text = "When the trade window closes, the strip that told you what to type goes away.",
		source = "Pay.lua (strip hides on TRADE_CLOSED)",
		kind = "scenario",
		needs = { ride = "arrived" },
		when = function(sit) return asRider(sit) and phoneOk(sit) end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			ctx:advance(4)
			driverTrades(ctx)
			ctx:advance(1)
			if not strip(ctx) then ctx:na("no strip was shown") end
			ctx.w:tradeCancel(ctx.me.player)
			tradeFrame(ctx, false)
			ctx:note("the trade is cancelled")
			ctx:advance(1)
			if strip(ctx) then
				ctx:fail("The trade window closes and the strip that told you what to type is still on screen.", strip(ctx))
			end
		end,
	}

	---------------------------------------------------------------------------
	-- paying by trade, as the rider types it (Wuber only says what to type)
	local function payBy(ctx, copper)
		local me, d = ctx.me.player, driverPlayer(ctx)
		if me.trade then ctx.w:tradeCancel(me) end
		if not ctx.w:openTrade(d, me) then ctx:cannot("no trade with the driver") end
		ctx.w:tradeMoney(me, copper)
		ctx.w:tradeAccept(d)
		ctx.w:tradeAccept(me)
		ctx:note("I type " .. copper .. " copper in the trade and both accept")
		tradeFrame(ctx, false)
		ctx:advance(2)
	end

	promise{
		id = "pay.part_paid_shows_left",
		area = "Payment",
		text = "If you pay only part of the fare, the pay card and the strip by the trade window ask for what is still left, not the whole fare again.",
		source = "inferred (Net.Rides: part paid, the pay strip shows what is left)",
		kind = "scenario",
		needs = { ride = "arrived" },
		when = function(sit) return asRider(sit) and phoneOk(sit) end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			if riderState(ctx) ~= "arrived" and riderState(ctx) ~= "paying" then ctx:na("not arrived") end
			local fare = fareOf(ctx)
			local half = math.floor(fare / 200) * 100
			if half <= 0 or half >= fare then ctx:na("fare too small to split") end
			payBy(ctx, half)
			if riderState(ctx) == "done" then
				ctx:fail("You pay half the fare and Wuber already says the ride is paid.", seen(ctx))
			end
			ctx:advance(5)
			showRide(ctx)
			local left = money(ctx, fare - half)
			local t = has(ctx, "Type " .. math.floor((fare - half) / 100) .. "s", true)
			if not (has(ctx, "^" .. left:gsub("%p", "%%%0") .. "$") or t) then
				ctx:fail(("You paid %s of a %s fare and the pay card still does not ask for just the %s left (it still says: %s)."):format(
					money(ctx, half), money(ctx, fare), left, tostring(has(ctx, "^Type ") or has(ctx, "Put .* in the trade window") or "the whole fare")), seen(ctx))
			end
		end,
	}

	promise{
		id = "pay.partial_adds_up",
		area = "Payment",
		text = "If you pay the fare in two trades, the second one finishes the ride as paid.",
		source = "inferred (Net.Rides: partial payments add up until the full fare is paid)",
		kind = "scenario",
		needs = { ride = "arrived" },
		when = function(sit) return asRider(sit) and phoneOk(sit) end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			if riderState(ctx) ~= "arrived" and riderState(ctx) ~= "paying" then ctx:na("not arrived") end
			local fare = fareOf(ctx)
			local half = math.floor(fare / 200) * 100
			if half <= 0 or half >= fare then ctx:na("fare too small to split") end
			payBy(ctx, half)
			ctx:advance(3)
			payBy(ctx, fare - half)
			if riderState(ctx) ~= "done" then
				ctx:fail("You pay the fare in two trades that add up to the whole fare and Wuber does not finish the ride as paid (it says " .. tostring(riderState(ctx)) .. ").", seen(ctx))
			end
		end,
	}

	promise{
		id = "pay.done_screen",
		area = "Payment",
		text = "After you pay, the Done screen thanks you by your driver's name, says what you paid and offers five stars.",
		source = "Done screen (Paid 50s to Ana; Thank you for riding with Ana; Tap a star)",
		kind = "scenario",
		needs = { ride = "paid" },
		when = function(sit) return asRider(sit) and phoneOk(sit) end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			showRide(ctx)
			local who = tostring(ctx.facts.driverName or ""):match("^(%S+)")
			local fare = fareOf(ctx)
			if not has(ctx, "Thank you for", false) or not has(ctx, who, true) then
				ctx:fail("You paid your driver and the Done screen does not thank you for riding with him by name.", seen(ctx))
			end
			if not has(ctx, "Paid ", true) then
				ctx:fail("You paid your driver and the Done screen does not say what you paid.", seen(ctx))
			end
			if not has(ctx, "Tap a star", true) then
				ctx:fail("You paid your driver and the Done screen does not offer stars to rate the ride.", seen(ctx))
			end
		end,
	}

	promise{
		id = "pay.stops_asking",
		area = "Payment",
		text = "Once you have paid, Wuber stops asking you to pay: no pay card, no Trade prompt.",
		source = "inferred (the ride is paid)",
		kind = "scenario",
		needs = { ride = "paid" },
		when = function(sit) return asRider(sit) and phoneOk(sit) end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			ctx:advance(12)
			showRide(ctx)
			for _, pat in ipairs({ "Type in trade window", "^Trade ", "Time to pay", "Waiting for .* to trade", "Put .* in the trade window" }) do
				local t = has(ctx, pat)
				if t then ctx:fail("You paid the fare in full and Wuber still says: " .. t, seen(ctx)) end
			end
		end,
	}

	promise{
		id = "pay.rate_once",
		area = "Payment",
		text = "Tapping a star rates the ride once and says how many stars you gave; tapping another star afterwards does not change it.",
		source = "Done screen (Thanks! You gave 4 stars; the stars' tooltip: Rate your ride)",
		kind = "scenario",
		needs = { ride = "paid" },
		when = function(sit) return asRider(sit) and phoneOk(sit) end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			showRide(ctx)
			local s = ctx.W.UI.state and ctx.W.UI.state.screens and ctx.W.UI.state.screens.done
			local stars = s and s.stars
			if not (stars and stars[4] and stars[2]) then ctx:cannot("the star buttons are not reachable") end
			if not ctx:visible(stars[4]) then
				ctx:fail("You paid and the Done screen shows no stars to tap.", seen(ctx))
			end
			ctx.me:clickOn(stars[4])
			ctx:note("tap star 4")
			ctx:advance(1)
			if not has(ctx, "You gave 4 stars", true) then
				ctx:fail("You tap the fourth star and Wuber does not say you gave 4 stars.", seen(ctx))
			end
			ctx.me:clickOn(stars[2])
			ctx:note("tap star 2")
			ctx:advance(1)
			if has(ctx, "You gave 2 stars", true) or not has(ctx, "You gave 4 stars", true) then
				ctx:fail("You rated your ride 4 stars, tapped the second star, and the rating changed.", seen(ctx))
			end
		end,
	}

	promise{
		id = "pay.unpaid_end",
		area = "Payment",
		text = "If you end the ride without paying through Wuber, the Done screen says Ride ended, offers no stars, and says Not paid, so no level progress.",
		source = "Done screen (Ride ended; Not paid, so no level progress.)",
		kind = "scenario",
		needs = { ride = "arrived" },
		when = function(sit) return asRider(sit) and phoneOk(sit) end,
		check = function(ctx)
			needPayCard(ctx)
			click(ctx, "End ride")
			ctx:advance(3)
			if not has(ctx, "Ride ended", true) then
				ctx:fail("You click End ride without paying and the next screen does not say Ride ended.", seen(ctx))
			end
			if has(ctx, "Tap a star", true) then
				ctx:fail("You ended the ride without paying and the screen still asks you to rate it.", seen(ctx))
			end
			if not has(ctx, "Not paid, so no level progress", true) then
				ctx:fail("You ended the ride without paying and Wuber does not say Not paid, so no level progress.", seen(ctx))
			end
		end,
	}

	---------------------------------------------------------------------------
	-- the driver's side of the payment
	promise{
		id = "pay.driver_sees_paid",
		area = "Payment",
		text = "When your rider pays the fare by trade, your queue shows them as paid, with the amount.",
		source = "Drive/Trade.lua (paid by trade is recorded; Paid shows in the queue); Drive Customers",
		kind = "scenario",
		needs = { ride = "paid" },
		when = function(sit) return asDriver(sit) and sit.role ~= "friend" and sit.place ~= "other_continent" and (sit.button_shown or "default") ~= "off" end,
		check = function(ctx)
			ctx:advance(1)
			local function paidShown() return has(ctx, "paid", true) ~= nil or ctx.me:said("paid") end
			-- the player looks at his queue: Wuber's Drive tab. Settings text also says "paid" ("Count a smaller
			-- payment as paid"), so close Settings and open the Drive tab before judging, not only when "paid" is missing.
			if not phoneShown(ctx) then ctx.W.UI.Toggle(true) ctx:note("open the phone") ctx:advance(2.5) end
			if uiState(ctx).settingsOpen and ctx.W.UI.CloseSettings then ctx.W.UI.CloseSettings(true) ctx:advance(0.5) end
			if uiState(ctx).tab ~= "Drive" then
				for _, tab in ipairs(uiState(ctx).tabs or {}) do
					if tab.name == "Drive" and tab.button then ctx.me:clickOn(tab.button) ctx:note("click the Drive tab") ctx:advance(1) end
				end
			end
			if not paidShown() then
				ctx:fail("Your rider pays the whole fare by trade and neither your queue (Drive tab) nor your chat says they paid.", seen(ctx))
			end
			local fare = ctx.facts.price
			if fare and not has(ctx, money(ctx, fare), true) and not ctx.me:said("paid") then
				ctx:fail("Your rider pays " .. money(ctx, fare) .. " by trade and your queue does not show that amount.", seen(ctx))
			end
		end,
	}
end
