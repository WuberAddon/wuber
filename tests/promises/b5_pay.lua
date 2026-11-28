-- Bug hunt wave 4 promises for Pay, Cards, Wrapped, and Share
-- (Wuber/UI/Rider/Pay.lua, Cards.lua, Wrapped.lua, Wuber/UI/Share.lua).
-- Prefix: b5pay.
return function(Hunt)
	local FOLDABLE = {
		home = true, trips = true, drive = true, drive_earnings = true,
		drive_messages = true, drive_customers = true, settings = true,
		settings_riding = true, settings_driving = true, settings_map = true,
		settings_sound = true, settings_window = true, world_view = true,
		here_view = true, confirm = true, wrapped = true,
	}

	local function promise(p)
		local w = p.when
		p.when = function(sit)
			if sit.fold == "folded_click" and not FOLDABLE[sit.phone or "closed"] then return false end
			return w == nil or w(sit)
		end
		Hunt.promise(p)
	end

	local function isRider(sit) return sit.role == nil or sit.role == "rider" end
	local function asRider(sit) return isRider(sit) and sit.net ~= "none" and sit.net ~= "oldpeer" end
	local function inCombat(ctx) return ctx.me.player.combat and true or false end
	local function kit(ctx) local K = ctx:mod("UI.Kit") return K and K.ui or {} end
	local function seen(ctx) return "on screen: " .. table.concat(ctx:texts(), " | ") end

	local function hasText(ctx, pat, plain)
		for _, t in ipairs(ctx:texts()) do
			if t:find(pat, 1, plain) then return t end
		end
		return nil
	end

	local function tradeFrame(ctx, on)
		local tf = ctx.me.env.TradeFrame
		if tf and ctx.H.state[tf] then ctx.H.state[tf].shown = on and true or false end
	end

	local function stripText(ctx)
		for _, t in ipairs(ctx:texts()) do
			if t:find("^Wuber: ") then return t end
		end
		return nil
	end

	local function clearOverlays(ctx)
		local UI = ctx.W.UI
		for _ = 1, 3 do
			local ui = kit(ctx)
			local WM = ctx:mod("UI.Rider.Wrapped")
			if WM and type(WM.Shown) == "function" and WM.Shown() then WM.Close() ctx:advance(0.4) end
			local over = ui.settingsOpen
				or (type(UI.HelpShown) == "function" and UI.HelpShown())
				or (type(UI.Bug) == "table" and type(UI.Bug.Shown) == "function" and UI.Bug.Shown())
			if not over then return end
			if ui.settingsOpen and type(UI.CloseSettings) == "function" then pcall(UI.CloseSettings, true) end
			ctx.me:pressEscape()
			ctx:advance(0.6)
		end
	end

	local function dismissOverlays(ctx)
		local Tips = ctx:mod("UI.Tips")
		if Tips and type(Tips.Card) == "function" then
			local ok, c = pcall(Tips.Card)
			if ok and type(c) == "table" and ctx:visible(c) then
				pcall(Tips.Hide)
				ctx:advance(0.4)
			end
		end
		for _ = 1, 3 do
			local b = ctx.me:button("Got it")
			local nn = ctx.me:button("Not now")
			if not (b and ctx:visible(b)) and nn and ctx:visible(nn) then b = nn end
			if b and ctx:visible(b) then
				ctx.me:clickOn(b)
				ctx:advance(0.5)
			else
				break
			end
		end
		local BirdM = ctx:mod("UI.Bird")
		local okc, bc = pcall(BirdM and BirdM.Card or function() end)
		if okc and type(bc) == "table" and ctx:visible(bc) and bc.x and ctx:visible(bc.x) then
			ctx.me:clickOn(bc.x)
			ctx:advance(0.5)
		end
	end

	local function openHome(ctx)
		if inCombat(ctx) then ctx:na("in combat") end
		local db = ctx.W.db
		if type(db) ~= "table" or db.coach ~= true then ctx:na("coach marks not done") end
		local K = ctx:mod("UI.Kit")
		if K and type(K.rideActive) == "function" and K.rideActive() then ctx:na("ride is active") end
		local UI = ctx.W.UI
		if not UI.IsShown() then
			ctx.me:slash("/wuber")
			ctx:advance(2.0)
		end
		clearOverlays(ctx)
		if not UI.IsShown() then
			ctx.me:slash("/wuber")
			ctx:advance(2.0)
		end
		local ui = kit(ctx)
		if ui.tab ~= "Ride" then
			for _, tab in ipairs(ui.tabs or {}) do
				if tab.name == "Ride" and tab.button and ctx:visible(tab.button) then
					ctx.me:clickOn(tab.button)
					ctx:advance(0.6)
					break
				end
			end
		end
		dismissOverlays(ctx)
		if not UI.IsShown() or kit(ctx).screen ~= "home" then ctx:na("Home is not reachable") end
	end

	local function visibleCards(ctx)
		local out = {}
		for key, c in pairs(kit(ctx).cards or {}) do
			if c.key and c.view and ctx:visible(c) then
				out[#out + 1] = { key = key, card = c, y = c.targetY or c.curY or 0 }
			end
		end
		table.sort(out, function(a, b)
			if a.y ~= b.y then return a.y > b.y end
			return a.key < b.key
		end)
		return out
	end

	local function openTrips(ctx)
		if inCombat(ctx) then ctx:na("in combat") end
		local db = ctx.W.db
		if type(db) ~= "table" or db.coach ~= true then ctx:na("coach marks not done") end
		local UI = ctx.W.UI
		if not UI.IsShown() then
			ctx.me:slash("/wuber")
			ctx:advance(2.0)
		end
		clearOverlays(ctx)
		if not UI.IsShown() then
			ctx.me:slash("/wuber")
			ctx:advance(2.0)
		end
		local ui = kit(ctx)
		if ui.tab ~= "Trips" then
			for _, tab in ipairs(ui.tabs or {}) do
				if tab.name == "Trips" and tab.button and ctx:visible(tab.button) then
					ctx.me:clickOn(tab.button)
					ctx:advance(0.8)
					break
				end
			end
		end
		dismissOverlays(ctx)
		if not UI.IsShown() or kit(ctx).tab ~= "Trips" then ctx:na("Trips is not reachable") end
	end

	-- 1. Pay: raincheck covering the full fare shows "nothing to pay" in the trade strip
	promise{
		id = "b5pay.raincheck_full_cover_strip",
		area = "Pay",
		text = "When a taken raincheck covers your entire fare, the trade strip says 'nothing to pay' instead of telling you to type gold.",
		source = "Wuber/UI/Rider/Pay.lua:82-90,161-167",
		kind = "scenario",
		needs = { ride = "arrived" },
		when = function(sit) return asRider(sit) end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local r = ctx.W.ride
			if not r or (r.price or 0) <= 0 then ctx:na("no fare due") end
			r.fare = r.price
			r.price = 0
			r.voucher = "rc-full"
			r.voucherCover = r.fare
			r.voucherTaken = true
			r.voucherRefused = nil
			local drvName = ctx.facts.payee or ctx.facts.driverName
			local drv = drvName and ctx.w:player(drvName)
			if not drv then ctx:cannot("no driver player") end
			if ctx.me.player.trade then ctx.w:tradeCancel(ctx.me.player) ctx:advance(0.3) end
			if not ctx.w:openTrade(drv, ctx.me.player) then ctx:cannot("could not open trade") end
			tradeFrame(ctx, true)
			ctx:advance(1.0)
			local s = stripText(ctx)
			if not s or not s:find("nothing to pay", 1, true) then
				ctx:fail("A taken raincheck covered the whole fare, but the trade strip did not say 'nothing to pay'.", tostring(s))
			end
		end,
	}

	-- 2. Pay: tip percentage remembered across /reload
	promise{
		id = "b5pay.tip_remembered_reload",
		area = "Pay",
		text = "Picking a tip percentage updates what you are told to type in the trade strip and is remembered across a /reload.",
		source = "Wuber/UI/Rider/Pay.lua:34-57,161-167",
		kind = "scenario",
		needs = { ride = "arrived" },
		when = function(sit) return asRider(sit) and sit.session ~= "first" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local r = ctx.W.ride
			if not r or (r.price or 0) <= 0 then ctx:na("no fare due") end
			local UI = ctx.W.UI
			if not UI.SetTipPct(20) then ctx:cannot("could not set tip to 20%") end
			ctx:advance(0.5)
			local drvName = ctx.facts.payee or ctx.facts.driverName
			local drv = drvName and ctx.w:player(drvName)
			if not drv then ctx:cannot("no driver player") end
			if ctx.me.player.trade then ctx.w:tradeCancel(ctx.me.player) ctx:advance(0.4) end
			if not ctx.w:openTrade(drv, ctx.me.player) then ctx:cannot("could not open driver trade") end
			tradeFrame(ctx, true)
			ctx:advance(1.0)
			local wantTotal = UI.PayTotal(ctx:mod("UI.Kit").rideView())
			local expected = ctx.W.FareSteps(wantTotal)
			local s1 = stripText(ctx)
			if not s1 or not s1:find(expected, 1, true) then
				ctx:fail("After picking a 20% tip, the trade strip did not show the updated amount to type.", tostring(s1))
			end
			ctx:reload()
			ctx:advance(1.5)
			if ctx.W.UI.TipPct() ~= 20 then
				ctx:fail("Your chosen 20% tip was forgotten after a /reload.", "TipPct=" .. tostring(ctx.W.UI.TipPct()))
			end
		end,
	}

	-- 3. Pay: open deferred in combat, opens after combat ends
	promise{
		id = "b5pay.pay_open_after_combat",
		area = "Pay",
		text = "If you arrive with a fare due while in combat and the phone is closed, Wuber waits until combat ends and then opens on the Ride pay screen.",
		source = "Wuber/UI/Rider/Pay.lua:191-243",
		kind = "scenario",
		needs = { ride = "arrived", phone = "closed" },
		when = function(sit) return asRider(sit) and sit.combat ~= "in" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("already in combat") end
			local r = ctx.W.ride
			if not r or (r.price or 0) <= 0 then ctx:na("no fare due") end
			local UI = ctx.W.UI
			if UI.IsShown() then UI.Toggle(false) ctx:advance(0.5) end
			ctx.w:enterCombat(ctx.me)
			ctx:advance(0.3)
			local drvName = ctx.facts.payee or ctx.facts.driverName
			local drv = drvName and ctx.w:player(drvName)
			if not drv then ctx:cannot("no driver player") end
			if ctx.me.player.trade then ctx.w:tradeCancel(ctx.me.player) ctx:advance(0.3) end
			if not ctx.w:openTrade(drv, ctx.me.player) then ctx:cannot("could not open trade") end
			tradeFrame(ctx, true)
			ctx:advance(0.8)
			if UI.IsShown() then
				ctx:fail("Wuber opened the pay screen while you were still in combat.", seen(ctx))
			end
			ctx.w:leaveCombat(ctx.me)
			ctx:advance(1.0)
			if not UI.IsShown() or kit(ctx).tab ~= "Ride" then
				ctx:fail("Combat ended with a fare due and trade open, but Wuber did not open on the Ride pay screen.", seen(ctx))
			end
		end,
	}

	-- 4. Pay: raincheck refused shows normal fare line
	promise{
		id = "b5pay.raincheck_not_taken_strip",
		area = "Pay",
		text = "When a raincheck on your ride is refused by the driver, the trade strip says the raincheck was not taken and shows the normal fare.",
		source = "Wuber/UI/Rider/Pay.lua:80-90,161-167",
		kind = "scenario",
		needs = { ride = "arrived" },
		when = function(sit) return asRider(sit) end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local r = ctx.W.ride
			if not r or (r.price or 0) <= 0 then ctx:na("no fare due") end
			r.voucher = "rc-test"
			r.voucherCover = r.price
			r.voucherTaken = nil
			r.voucherRefused = true
			local drvName = ctx.facts.payee or ctx.facts.driverName
			local drv = drvName and ctx.w:player(drvName)
			if not drv then ctx:cannot("no driver player") end
			if ctx.me.player.trade then ctx.w:tradeCancel(ctx.me.player) ctx:advance(0.3) end
			if not ctx.w:openTrade(drv, ctx.me.player) then ctx:cannot("could not open trade") end
			tradeFrame(ctx, true)
			ctx:advance(1.0)
			local s = stripText(ctx)
			if not s or not s:find("Raincheck not taken: normal fare", 1, true) then
				ctx:fail("Your raincheck was refused, but the trade strip did not say 'Raincheck not taken: normal fare'.", tostring(s))
			end
		end,
	}

	-- 5. Cards: heart button toggles favourite
	promise{
		id = "b5pay.card_fav_heart",
		area = "Cards",
		text = "Clicking the heart on a driver card toggles their favourite state, updates the heart icon, and shows a confirmation toast.",
		source = "Wuber/UI/Rider/Cards.lua:51-67,85-113",
		kind = "scenario",
		when = function(sit) return isRider(sit) and sit.coach ~= "not_done" end,
		check = function(ctx)
			openHome(ctx)
			local list = visibleCards(ctx)
			if #list == 0 then ctx:na("no drivers on Home") end
			local c = list[1].card
			if not c.heart or not ctx:visible(c.heart) then ctx:cannot("driver card heart not visible") end
			local wasFav = ctx.W.UI.IsFav(c.key)
			ctx.me:clickOn(c.heart)
			ctx:advance(0.8)
			local nowFav = ctx.W.UI.IsFav(c.key)
			if nowFav == wasFav then
				ctx:fail("Clicking the heart on a driver card did not toggle their favourite state.", "key=" .. tostring(c.key))
			end
			local expectToast = nowFav and "is a favourite" or "is no longer a favourite"
			if not hasText(ctx, expectToast, true) then
				ctx:fail("Clicking the heart on a driver card did not show the favourite toast.", seen(ctx))
			end
		end,
	}

	-- 6. Cards: right-click menu in Advanced vs Simple mode
	promise{
		id = "b5pay.card_right_click_menu",
		area = "Cards",
		text = "Right-clicking a driver card opens the Favourite / Hide menu in Advanced mode, and does not open it in Simple mode.",
		source = "Wuber/UI/Rider/Cards.lua:117-169,265-270",
		kind = "scenario",
		when = function(sit) return isRider(sit) and sit.coach ~= "not_done" end,
		check = function(ctx)
			openHome(ctx)
			local list = visibleCards(ctx)
			if #list == 0 then ctx:na("no drivers on Home") end
			local c = list[1].card
			local wasAdv = ctx.W.Advanced()
			if wasAdv then
				ctx.me:clickOn(c, "RightButton")
				ctx:advance(0.6)
				if not hasText(ctx, "Hide this driver", true) then
					ctx:fail("In Advanced mode, right-clicking a driver card did not open the Favourite / Hide menu.", seen(ctx))
				end
			else
				ctx.me:clickOn(c, "RightButton")
				ctx:advance(0.6)
				if hasText(ctx, "Hide this driver", true) then
					ctx:fail("In Simple mode, right-clicking a driver card opened the Advanced Favourite / Hide menu.", seen(ctx))
				end
			end
		end,
	}

	-- 7. Cards: Hide this driver removes them from Home
	promise{
		id = "b5pay.card_hide_driver",
		area = "Cards",
		text = "Clicking 'Hide this driver' in a driver card's menu removes that driver from the Home list and tells you Settings can show them again.",
		source = "Wuber/UI/Rider/Cards.lua:70-82,135-138",
		kind = "scenario",
		needs = { advanced = "on" },
		when = function(sit) return isRider(sit) and sit.coach ~= "not_done" end,
		check = function(ctx)
			openHome(ctx)
			local list = visibleCards(ctx)
			if #list == 0 then ctx:na("no drivers on Home") end
			local targetKey = list[1].key
			ctx.me:clickOn(list[1].card, "RightButton")
			ctx:advance(0.6)
			if not hasText(ctx, "Hide this driver", true) then
				ctx:cannot("card menu did not open")
			end
			ctx.me:clickText("Hide this driver")
			ctx:advance(0.8)
			if not hasText(ctx, "Settings", true) then
				ctx:fail("Hiding a driver did not tell you that Settings can show them again.", seen(ctx))
			end
			for _, item in ipairs(visibleCards(ctx)) do
				if item.key == targetKey then
					ctx:fail("After clicking 'Hide this driver', that driver still appeared in the Home list.", targetKey)
				end
			end
		end,
	}

	-- 8. Cards: paused driver toast
	promise{
		id = "b5pay.card_paused_toast",
		area = "Cards",
		text = "Clicking a paused driver card does not open booking and tells you they have paused for now.",
		source = "Wuber/UI/Rider/Cards.lua:271-275",
		kind = "scenario",
		when = function(sit) return isRider(sit) and sit.coach ~= "not_done" end,
		check = function(ctx)
			openHome(ctx)
			local pausedCard
			for _, item in ipairs(visibleCards(ctx)) do
				if item.card.disabled then pausedCard = item.card break end
			end
			if not pausedCard then ctx:na("no paused driver card on Home") end
			ctx.me:clickOn(pausedCard)
			ctx:advance(0.8)
			if not hasText(ctx, "has paused for now", true) then
				ctx:fail("Clicking a paused driver card did not tell you they have paused for now.", seen(ctx))
			end
			if kit(ctx).confirmKey then
				ctx:fail("Clicking a paused driver card opened the Confirm booking screen.", tostring(kit(ctx).confirmKey))
			end
		end,
	}

	-- 9. Cards: search box filters and clear button restores
	promise{
		id = "b5pay.card_search_clear",
		area = "Cards",
		text = "Typing a place in the Home search box filters the driver list, and clicking the clear button restores all drivers.",
		source = "Wuber/UI/Rider/Cards.lua:598-683",
		kind = "scenario",
		when = function(sit) return isRider(sit) and sit.coach ~= "not_done" end,
		check = function(ctx)
			openHome(ctx)
			local before = visibleCards(ctx)
			if #before == 0 then ctx:na("no drivers on Home") end
			local search = kit(ctx).search
			if not search or not search.edit then ctx:cannot("no Home search box") end
			ctx.me:typeText(search.edit, "zzznoplace999")
			ctx:advance(0.6)
			local filtered = visibleCards(ctx)
			if #filtered ~= 0 then
				ctx:fail("Typing a non-existent place in the Home search box still left drivers visible.", "count=" .. #filtered)
			end
			if not search.clear or not ctx:visible(search.clear) then
				ctx:fail("Typing in the Home search box did not show the clear button.", seen(ctx))
			end
			ctx.me:clickOn(search.clear)
			ctx:advance(0.6)
			local after = visibleCards(ctx)
			if #after ~= #before then
				ctx:fail("Clicking the search clear button did not restore all drivers.", string.format("before=%d after=%d", #before, #after))
			end
		end,
	}

	-- 10. Cards: danger shield on hot drop
	promise{
		id = "b5pay.card_danger_shield",
		area = "Cards",
		text = "A driver card with PvP near the summon spot shows a red shield icon, while a safe driver card does not.",
		source = "Wuber/UI/Rider/Cards.lua:449-498,568-570",
		kind = "scenario",
		when = function(sit) return isRider(sit) and sit.coach ~= "not_done" end,
		check = function(ctx)
			openHome(ctx)
			local list = visibleCards(ctx)
			if #list == 0 then ctx:na("no drivers on Home") end
			local c = list[1].card
			local d = c.view
			local target = type(d.raw) == "table" and d.raw or d
			local oldD, oldS, oldA = target.danger, target.dangerSecs, target.dangerAt
			target.danger = 2
			target.dangerSecs = 30
			target.dangerAt = nil
			ctx:mod("UI.Rider.Cards").fillCard(c, d, 0, false)
			local shownHot = c.shield and ctx:visible(c.shield)
			target.danger = 0
			target.dangerSecs = nil
			target.dangerAt = nil
			ctx:mod("UI.Rider.Cards").fillCard(c, d, 0, false)
			local shownSafe = c.shield and ctx:visible(c.shield)
			target.danger, target.dangerSecs, target.dangerAt = oldD, oldS, oldA
			ctx:mod("UI.Rider.Cards").fillCard(c, d, 0, false)
			if not shownHot then
				ctx:fail("A driver card with PvP danger level 2 did not show its shield icon.", c.key)
			end
			if shownSafe then
				ctx:fail("A safe driver card (danger 0) still showed a PvP shield icon.", c.key)
			end
		end,
	}

	-- 11. Wrapped: opening hides Trips list, closing restores it
	promise{
		id = "b5pay.wrapped_open_and_close",
		area = "Wrapped",
		text = "Opening a month's Azeroth Wrapped story hides the Trips list underneath and closing it brings the Trips list back.",
		source = "Wuber/UI/Rider/Wrapped.lua:53-64,436-495",
		kind = "scenario",
		needs = { day = "next_month", saved = "acct3_rider" },
		when = function(sit) return isRider(sit) and sit.coach ~= "not_done" end,
		check = function(ctx)
			openTrips(ctx)
			local WM = ctx:mod("UI.Rider.Wrapped")
			if not WM then ctx:cannot("no Wrapped module") end
			local months = WM.Months()
			if #months == 0 then ctx:na("no Wrapped months available") end
			if not WM.Open(months[1].year, months[1].month) then
				ctx:cannot("could not open Wrapped story")
			end
			ctx:advance(0.5)
			local tr = ctx.W.UI.trips
			if tr and tr.clip and tr.clip:GetAlpha() ~= 0 then
				ctx:fail("While the Wrapped story was open, the Trips list underneath was not hidden (alpha ~= 0).", tostring(tr.clip:GetAlpha()))
			end
			WM.Close()
			ctx:advance(0.5)
			if tr and tr.clip and tr.clip:GetAlpha() ~= 1 then
				ctx:fail("After closing the Wrapped story, the Trips list underneath did not come back (alpha ~= 1).", tostring(tr.clip:GetAlpha()))
			end
		end,
	}

	-- 12. Wrapped: driver-only month has no Share pill on summary
	promise{
		id = "b5pay.wrapped_driver_only_no_share",
		area = "Wrapped",
		text = "A Wrapped month where you only drove (0 rider summons) does not show the Share button on the summary slide.",
		source = "Wuber/UI/Rider/Wrapped.lua:341-345",
		kind = "scenario",
		needs = { group = "party" },
		when = function(sit) return sit.coach ~= "not_done" end,
		check = function(ctx)
			openTrips(ctx)
			local WM = ctx:mod("UI.Rider.Wrapped")
			local CW = ctx:mod("Core.Wrapped")
			if not WM or not CW then ctx:cannot("no Wrapped modules") end
			local env = ctx.me.env
			local t = env.date("*t", env.time())
			local y, m = t.year, t.month - 1
			if m < 1 then y, m = y - 1, 12 end
			local ts = env.time({ year = y, month = m, day = 15, hour = 12, min = 0, sec = 0 })
			local oldRides = ctx.W.db.rides
			local oldDrive = ctx.W.db.drive
			local oldLog = oldDrive and oldDrive.log
			ctx.W.db.rides = {}
			ctx.W.db.drive = ctx.W.db.drive or {}
			ctx.W.db.drive.log = {
				string.format("%d,5000,Bob,Orgrimmar,direct,5000", ts),
			}
			local okOpen = WM.Open(y, m)
			local st = okOpen and WM.Story()
			local shareShown = false
			if st and st.slides then
				for _ = 1, #st.slides do WM.Next() end
				ctx:advance(0.5)
				shareShown = st.share and ctx:visible(st.share)
			end
			WM.Close()
			ctx.W.db.rides = oldRides
			if oldDrive then
				oldDrive.log = oldLog
			else
				ctx.W.db.drive = nil
			end
			if ctx.W.UI.UpdateTrips then ctx.W.UI.UpdateTrips() end
			ctx:advance(0.3)
			if not okOpen then ctx:cannot("could not open driver-only Wrapped") end
			if not st or not st.slides then ctx:cannot("Wrapped story has no slides") end
			if shareShown then
				ctx:fail("On a driver-only Wrapped month (0 rider summons), the Share button still appeared on the summary slide.", seen(ctx))
			end
		end,
	}

	-- 13. Wrapped: Share pill is only on the summary slide, never on slide 1
	promise{
		id = "b5pay.wrapped_no_share_on_first_slide",
		area = "Wrapped",
		text = "On the first slide of Azeroth Wrapped, the Share button is hidden even when you are in a group.",
		source = "Wuber/UI/Rider/Wrapped.lua:341-345",
		kind = "scenario",
		needs = { day = "next_month", group = "party", saved = "acct3_rider" },
		when = function(sit) return isRider(sit) and sit.coach ~= "not_done" end,
		check = function(ctx)
			openTrips(ctx)
			local WM = ctx:mod("UI.Rider.Wrapped")
			if not WM then ctx:cannot("no Wrapped module") end
			local months = WM.Months()
			if #months == 0 then ctx:na("no Wrapped months available") end
			if not WM.Open(months[1].year, months[1].month) then
				ctx:cannot("could not open Wrapped story")
			end
			ctx:advance(0.4)
			local st = WM.Story()
			if st and st.share and ctx:visible(st.share) then
				ctx:fail("The Share button was visible on the first slide of Wrapped instead of waiting for the summary slide.", seen(ctx))
			end
			WM.Close()
		end,
	}

	-- 14. Share: solo hidden, combat shows "Share after combat", out of combat restores
	promise{
		id = "b5pay.share_solo_and_combat",
		area = "Share",
		text = "A registered Share pill is hidden while solo, shows 'Share after combat' in combat while grouped, and returns to its normal label when combat ends.",
		source = "Wuber/UI/Share.lua:105-141",
		kind = "scenario",
		when = function(sit) return sit.combat ~= "in" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("already in combat") end
			local Share = ctx.W.UI.Share
			local T = ctx.W.Theme
			if not Share or not T then ctx:cannot("no UI.Share or Theme") end
			local host = ctx.me.env.UIParent
			local pill = T.Pill(host, "Share", "primary", 100, 32)
			T.Tip(pill, "Share", "Posts a line to your group.")
			local currentLine = "Summoned to Orgrimmar!"
			Share.Register(pill, function() return currentLine end, { label = "Share" })
			Share.Sync()
			if ctx.me.player.group == nil then
				local vis = ctx:visible(pill)
				currentLine = nil
				Share.Sync()
				pill:Hide()
				if vis then
					ctx:fail("While solo, a party Share pill was still visible.", tostring(Share.State(pill)))
				end
				return
			end
			if not ctx:visible(pill) or Share.State(pill) ~= "ok" then
				currentLine = nil
				Share.Sync()
				pill:Hide()
				ctx:fail("While in a group out of combat, the Share pill was not ready.", tostring(Share.State(pill)))
			end
			ctx.w:enterCombat(ctx.me)
			ctx:advance(0.3)
			Share.Sync()
			local inCbtOk = Share.State(pill) == "combat" and pill.label and pill.label:GetText() == "Share after combat"
			ctx.w:leaveCombat(ctx.me)
			ctx:advance(0.3)
			Share.Sync()
			local outCbtOk = Share.State(pill) == "ok" and pill.label and pill.label:GetText() == "Share"
			currentLine = nil
			Share.Sync()
			pill:Hide()
			if not inCbtOk then
				ctx:fail("In combat, the Share pill did not switch to 'Share after combat'.", tostring(Share.State(pill)))
			end
			if not outCbtOk then
				ctx:fail("After combat ended, the Share pill did not return to 'Share'.", tostring(Share.State(pill)))
			end
		end,
	}

	-- 15. Share: macro filter blocks "gold" and links, allows "Goldshire", uses /p or /ra
	promise{
		id = "b5pay.share_macro_filter",
		area = "Share",
		text = "Share refuses lines containing the standalone word 'gold' or web links, while allowing place names like 'Goldshire', and formats /p or /ra for party vs raid.",
		source = "Wuber/UI/Share.lua:94-103,152-167",
		kind = "scenario",
		needs = { group = "party" },
		when = function(sit) return sit.combat ~= "in" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("already in combat") end
			local Share = ctx.W.UI.Share
			local T = ctx.W.Theme
			if not Share or not T then ctx:cannot("no UI.Share or Theme") end
			local pill = T.Pill(ctx.me.env.UIParent, "Share", "primary", 100, 32)
			T.Tip(pill, "Share", "Posts a line to your group.")
			local line = "Paid 5 gold for a summon"
			Share.Register(pill, function() return line end, { label = "Share" })
			local m1 = Share.Macro(pill)
			line = "Check https://example.com for rides"
			local m2 = Share.Macro(pill)
			line = "Summoned to Goldshire in 30s!"
			local m3 = Share.Macro(pill)
			line = nil
			Share.Sync()
			pill:Hide()
			if m1 ~= nil then
				ctx:fail("Share allowed a line containing the standalone word 'gold'.", tostring(m1))
			end
			if m2 ~= nil then
				ctx:fail("Share allowed a line containing a web link.", tostring(m2))
			end
			local wantPrefix = ctx.me.player.group == "raid" and "/ra " or "/p "
			if not m3 or m3:sub(1, #wantPrefix) ~= wantPrefix then
				ctx:fail("Share did not allow 'Goldshire' or did not format with " .. wantPrefix .. ".", tostring(m3))
			end
		end,
	}
end
