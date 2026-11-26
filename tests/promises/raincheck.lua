-- Promises about the rain check (tests/promises/raincheck.lua; owner RIDEPAY).
-- What the player is told: the tip "Paid and the summon fell through? Your driver can give you a rain check.",
-- the Ask for a raincheck button ("You paid and the summon didn't happen. Ask the driver for one free summon later
-- instead. Wuber never sends gold back; the driver decides."), the offer card ("One free summon, up to 50s, until
-- 24 Nov."), "Use raincheck (covers 50s)" on the Confirm screen and "Raincheck covers 50s . nothing to pay".
-- Each check plays the whole story the way the people do: the rider books and pays by trade, the driver closes before
-- the summon, the rider gives up, asks, the driver gives, the rider answers the card.
return function(Hunt)
	local U = dofile("tests/hunt/lib/universal_util.lua") -- (U.asClick: a stand-in for a click that the universal send check sees as one)
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
	local BORDER = { mapID = 1411, x = 0.04, y = 0.45, zone = "The Barrens", sub = "" } -- a trade with Ratchet, not arrived
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end
	local function isRider(sit) return sit.role == nil or sit.role == "rider" end
	local function asRider(sit) return isRider(sit) and sit.net ~= "none" and sit.net ~= "oldpeer" and sit.net ~= "layers" and sit.net ~= "late" end

	local function waitFor(ctx, pred, max, step)
		step = step or 0.25
		local t = 0
		while not pred() do
			if t >= max then return false end
			ctx:advance(step)
			t = t + step
		end
		return true
	end
	local function must(ctx, v, why) if not v then ctx:cannot("raincheck: " .. why) end end
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
	local function riderW(ctx) return ctx.W end
	local function driverTexts(d)
		local ok, t = pcall(d.visibleTexts, d)
		return ok and table.concat(t, " | ") or ""
	end

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

	-- I book the driver, join his group and pay the whole fare by trade at the border (before any summon);
	-- t = { d = the driver's window, key, name, ride, fare }
	local function bookAndPay(ctx)
		local d = ctx.peers.driver
		must(ctx, d, "no driver window")
		local t = { d = d, name = d.player.name, key = key(d.player.name) }
		local W = ctx.W
		ctx.w:move(ctx.name, BORDER)
		must(ctx, waitFor(ctx, function() return W.drivers[t.key] ~= nil end, 15), "I never saw the driver in the list")
		-- the Request click: W.RequestRide and the button's secure-macro whisper happen inside the player's hardware event (as AcceptGroup below)
		local ride, why = U.asClick(ctx, function()
			local r, y = W.RequestRide(t.key)
			local text = r and W.RequestWhisper(t.key)
			if text then ctx.w:whisper(ctx.me, t.name, text, "macro") end
			return r, y
		end)
		must(ctx, ride, "the request was refused: " .. tostring(why))
		ctx:note("click Request (the whisper goes with the click)")
		t.ride = ride
		must(ctx, waitFor(ctx, function()
			local p = ctx.me.player
			if not p.group and p.pendingInvite then
				ctx.w.hardware = ctx.me
				ctx.me.env.AcceptGroup()
				ctx.w.hardware = nil
				ctx.me.popups.PARTY_INVITE = nil
			end
			return W.ride and W.RIDE_RANK[W.ride.state] >= W.RIDE_RANK.ingroup
		end, 12), "I never joined the driver's group (" .. tostring(W.ride and W.ride.state) .. ")")
		local rp, dp = ctx.me.player, d.player
		if rp.trade then ctx.w:tradeCancel(rp) end
		must(ctx, ctx.w:openTrade(rp, dp), "no trade with the driver")
		t.fare = W.ride.price
		ctx.w:tradeMoney(rp, t.fare)
		ctx.w:tradeAccept(dp)
		ctx.w:tradeAccept(rp)
		must(ctx, waitFor(ctx, function() return W.ride and (W.ride.paid or 0) >= t.fare end, 5, 0.1), "my Wuber never saw the fare go")
		t.moneyAfterPay = rp.money
		ctx:note("I pay " .. t.fare .. " copper by trade")
		return t
	end

	-- the driver closes before the cast and I give up: the paid ride has failed
	local function fall(ctx, t)
		t.d.W.Drive.SetOpen(false)
		ctx:advance(2)
		local W = ctx.W
		if W.RideActive() then U.asClick(ctx, W.CancelRide) end -- the Cancel click
		ctx:note("the driver closed; I cancel the ride")
		must(ctx, waitFor(ctx, function() return not W.RideActive() end, 5), "the ride never ended")
		ctx:advance(1)
	end

	local function askClick(ctx, t)
		showRide(ctx)
		if not hasExact(ctx, "Ask for a raincheck") then return false end
		ctx.me:clickText("Ask for a raincheck")
		ctx:note("click Ask for a raincheck")
		ctx:advance(1.5)
		return true
	end

	-- the driver's own click on Give raincheck
	local function give(ctx, t)
		local DR = t.d.W.Drive
		must(ctx, waitFor(ctx, function() return DR.RaincheckEligible(t.ride.id) == true end, 5), "the driver's book says no raincheck")
		local ok, id = DR.GiveRaincheck(t.ride.id)
		must(ctx, ok, "the driver could not give one: " .. tostring(id))
		ctx:note("the driver clicks Give raincheck")
		ctx:advance(2)
		-- the offer is a whisper-like message in the driver's busy outbox: it can take a few seconds more to reach the rider
		must(ctx, waitFor(ctx, function() return ctx.W.Raincheck and ctx.W.Raincheck.Mine()[1] ~= nil end, 15), "the raincheck offer never reached the rider")
		return id
	end

	-- the whole story up to the rider holding an offer
	local function offered(ctx)
		local t = bookAndPay(ctx)
		fall(ctx, t)
		must(ctx, askClick(ctx, t), "no Ask for a raincheck button")
		t.id = give(ctx, t)
		return t
	end

	local function offerCard(ctx)
		for _, t in ipairs(ctx:texts()) do if t:find(" offers a raincheck", 1, true) then return t end end
	end

	local SETUP = { net = "one" }
	local function when(sit) return asRider(sit) and sit.group == nil or sit.group == "solo" end

	---------------------------------------------------------------------------
	promise{
		id = "raincheck.ask_button",
		area = "Raincheck",
		text = "If you paid by trade and the summon fell through, your ride's screen offers Ask for a raincheck.",
		source = "Tip: Paid and the summon fell through? Your driver can give you a rain check; Done.lua tooltip",
		kind = "scenario",
		needs = { ride = "none" },
		when = function(sit) return asRider(sit) and (sit.group == nil or sit.group == "solo") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			local t = bookAndPay(ctx)
			fall(ctx, t)
			showRide(ctx)
			if not hasExact(ctx, "Ask for a raincheck") then
				ctx:fail("You paid your driver by trade, he closed before the summon and you gave up: nothing on your screen offers Ask for a raincheck.", seen(ctx))
			end
		end,
	}

	promise{
		id = "raincheck.unpaid_no_ask",
		area = "Raincheck",
		text = "If you never paid, Wuber does not offer a raincheck: there is nothing to make good.",
		source = "Done.lua tooltip (You paid and the summon didn't happen)",
		kind = "scenario",
		needs = { ride = "none" },
		when = function(sit) return asRider(sit) and (sit.group == nil or sit.group == "solo") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			local d = ctx.peers.driver
			must(ctx, d, "no driver window")
			local W = ctx.W
			local k = key(d.player.name)
			must(ctx, waitFor(ctx, function() return W.drivers[k] ~= nil end, 15), "I never saw the driver")
			local ride = U.asClick(ctx, function() return W.RequestRide(k) end) -- the Request click
			must(ctx, ride, "request refused")
			ctx:advance(3)
			d.W.Drive.SetOpen(false)
			ctx:advance(2)
			if W.RideActive() then U.asClick(ctx, W.CancelRide) end -- the Cancel click
			ctx:advance(2)
			showRide(ctx)
			if hasExact(ctx, "Ask for a raincheck") then
				ctx:fail("You never paid, you cancel the ride, and Wuber still offers Ask for a raincheck.", seen(ctx))
			end
		end,
	}

	promise{
		id = "raincheck.ask_once",
		area = "Raincheck",
		text = "Ask for a raincheck can be used once: after you click it the button goes and the driver sees your request.",
		source = "Done.lua (Asked <driver> for a raincheck); Drive alert",
		kind = "scenario",
		needs = { ride = "none" },
		when = function(sit) return asRider(sit) and (sit.group == nil or sit.group == "solo") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			local t = bookAndPay(ctx)
			fall(ctx, t)
			must(ctx, askClick(ctx, t), "no Ask for a raincheck button")
			if hasExact(ctx, "Ask for a raincheck") then
				ctx:fail("You click Ask for a raincheck and the button is still there to click again.", seen(ctx))
			end
			if not has(ctx, "Asked ", true) and not has(ctx, "raincheck", true) then
				ctx:fail("You click Ask for a raincheck and nothing on your screen says it was sent.", seen(ctx))
			end
			local dt = driverTexts(t.d)
			if not dt:lower():find("raincheck", 1, true) then
				ctx:fail("You asked your driver for a raincheck and nothing on his screen tells him.", dt)
			end
		end,
	}

	promise{
		id = "raincheck.offer_card",
		area = "Raincheck",
		text = "When the driver gives you a raincheck, a card names him, says it is one free summon up to a stated amount and until a date, with Accept and No thanks.",
		source = "Moments.lua offer card (One free summon, up to 50s, until 24 Nov.)",
		kind = "scenario",
		needs = { ride = "none" },
		when = function(sit) return asRider(sit) and (sit.group == nil or sit.group == "solo") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			local t = offered(ctx)
			local who = t.name:match("^(%S+)")
			if not offerCard(ctx) or not has(ctx, who, true) then
				ctx:fail("Your driver gives you a raincheck and no card on your screen says " .. who .. " offers one.", seen(ctx))
			end
			if not has(ctx, "One summon at no charge, up to " .. ctx.W.Money(t.fare), true) then
				ctx:fail("Your driver's raincheck card does not say it is one free summon up to the fare you paid (" .. ctx.W.Money(t.fare) .. ").", seen(ctx))
			end
			if not has(ctx, "until ", true) then
				ctx:fail("Your driver's raincheck card does not say when it runs out.", seen(ctx))
			end
			if not (hasExact(ctx, "Accept") and hasExact(ctx, "No thanks")) then
				ctx:fail("Your driver's raincheck card does not have both Accept and No thanks.", seen(ctx))
			end
		end,
	}

	promise{
		id = "raincheck.accept",
		area = "Raincheck",
		text = "Clicking Accept on the raincheck card keeps it: the card goes, you are told it is kept, it is listed under Trips, and no gold comes back to you.",
		source = "Moments.lua (Raincheck kept: one free summon; Nothing is paid back in gold); Trips Rainchecks row",
		kind = "scenario",
		needs = { ride = "none" },
		when = function(sit) return asRider(sit) and (sit.group == nil or sit.group == "solo") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			local t = offered(ctx)
			must(ctx, hasExact(ctx, "Accept"), "no Accept button on the card")
			local before = ctx.me.player.money
			ctx.me:clickText("Accept")
			ctx:note("click Accept on the raincheck card")
			ctx:advance(2)
			if offerCard(ctx) then
				ctx:fail("You click Accept on the raincheck card and the card is still on your screen.", seen(ctx))
			end
			local mine = ctx.W.Raincheck.Mine()[1]
			if not (mine and mine.state == "active") then
				ctx:fail("You click Accept on the raincheck and it is not listed as yours to use (state " .. tostring(mine and mine.state) .. ").", seen(ctx))
			end
			-- listed under Trips (Rainchecks (1))
			local s = uiState(ctx)
			for _, tab in ipairs(s.tabs or {}) do
				if tab.name == "Trips" and tab.button then ctx.me:clickOn(tab.button) ctx:note("click the Trips tab") ctx:advance(1) end
			end
			if not has(ctx, "Rainchecks (1)", true) then
				ctx:fail("You keep a raincheck and Trips does not list it (no Rainchecks (1) row).", seen(ctx))
			end
			if ctx.me.player.money ~= before then
				ctx:fail("You accept a raincheck and your purse changes: a raincheck never pays gold back.", "before " .. tostring(before) .. " after " .. tostring(ctx.me.player.money))
			end
		end,
	}

	promise{
		id = "raincheck.decline",
		area = "Raincheck",
		text = "Clicking No thanks on the raincheck card turns it down: the card goes and it is not left in your list.",
		source = "Moments.lua offer card (No thanks)",
		kind = "scenario",
		needs = { ride = "none" },
		when = function(sit) return asRider(sit) and (sit.group == nil or sit.group == "solo") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			local t = offered(ctx)
			must(ctx, hasExact(ctx, "No thanks"), "no No thanks button on the card")
			ctx.me:clickText("No thanks")
			ctx:note("click No thanks on the raincheck card")
			ctx:advance(2)
			if offerCard(ctx) then
				ctx:fail("You click No thanks on the raincheck card and the card is still on your screen.", seen(ctx))
			end
			for _, m in ipairs(ctx.W.Raincheck.Mine()) do
				if m.state == "active" or m.state == "offered" then
					ctx:fail("You turned the raincheck down and it is still in your list (" .. tostring(m.state) .. ").", seen(ctx))
				end
			end
		end,
	}

	promise{
		id = "raincheck.next_request",
		area = "Raincheck",
		text = "With a raincheck from a driver, your next request to him shows the ride as free (the raincheck covers the fare) instead of asking you to pay.",
		source = "Confirm screen (Use raincheck, on by default); Pay.lua (Raincheck covers 50s . nothing to pay)",
		kind = "scenario",
		needs = { ride = "none" },
		when = function(sit) return asRider(sit) and (sit.group == nil or sit.group == "solo") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			local t = offered(ctx)
			must(ctx, hasExact(ctx, "Accept"), "no Accept button on the card")
			ctx.me:clickText("Accept")
			ctx:advance(2)
			-- back to the start: out of the old ride, the driver open again, at home
			local W = ctx.W
			if ctx.me.player.group then ctx.w:leave(ctx.name) end
			if W.ClearRide then W.ClearRide() end
			t.d.W.Drive.SetOpen(true)
			ctx:advance(3)
			must(ctx, waitFor(ctx, function() local dd = W.drivers[t.key] return dd and dd.state == "open" end, 10), "the driver did not open again")
			local ride, why = U.asClick(ctx, function() -- the Request click: the request and the button's secure-macro whisper
				local r, y = W.RequestRide(t.key)
				local text = r and W.RequestWhisper(t.key)
				if text then ctx.w:whisper(ctx.me, t.name, text, "macro") end
				return r, y
			end)
			must(ctx, ride, "the next request was refused: " .. tostring(why))
			ctx:note("click Request again, with the raincheck")
			ctx:advance(4)
			showRide(ctx)
			if not (has(ctx, "Raincheck covers", true) or hasExact(ctx, "free") or has(ctx, "nothing to pay", true)) then
				ctx:fail("You hold a raincheck covering the whole fare, request your driver again, and your ride screen still shows a price to pay instead of free.", seen(ctx))
			end
		end,
	}

	promise{
		id = "raincheck.expires",
		area = "Raincheck",
		text = "A raincheck is good for about a week: after that it is gone and your next request does not use it.",
		source = "Moments.lua offer card (until <date>, a week on); Net.Raincheck",
		kind = "scenario",
		needs = { ride = "none" },
		when = function(sit) return asRider(sit) and (sit.group == nil or sit.group == "solo") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			local t = offered(ctx)
			must(ctx, hasExact(ctx, "Accept"), "no Accept button on the card")
			ctx.me:clickText("Accept")
			ctx:advance(2)
			local W = ctx.W
			-- (let the outbox empty first: with real saved data a message of the earlier clicks can still be queued, and it would go out
			-- after the jump, long after the click that made it)
			ctx:advance(20)
			-- eight days pass (the fake clock jumps, then the game runs a few seconds)
			ctx.w.time = ctx.w.time + 8 * 86400
			ctx.w.lastFrame = ctx.w.lastFrame + 8 * 86400
			ctx:note("eight days pass")
			ctx:advance(5)
			for _, m in ipairs(W.Raincheck.Mine()) do
				if m.state == "active" then
					ctx:fail("A raincheck you were given eight days ago is still active and usable.", "state " .. tostring(m.state))
				end
			end
		end,
	}
end
