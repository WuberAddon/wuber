-- Promises about the Driver Console (open and closed, rows and marks).
-- New promises for Wuber/UI/Driver/Console.lua, Rows.lua, and Draw.lua.
return function(Hunt)
	local function canDrive(sit)
		return (sit.saved == nil or sit.saved == "fresh") and sit.group ~= "raid"
	end

	local function has(ctx, pat)
		for _, t in ipairs(ctx:texts()) do
			if t:find(pat) then return t end
		end
		return nil
	end

	local function allText(ctx) return table.concat(ctx:texts(), " | ") end
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end
	local function DR(ctx) return ctx.W.Drive end
	local function D(ctx) return ctx.W.Driver end
	local function noCombat(ctx) if ctx.me.player.combat then ctx:na("in combat") end end

	local function openDrive(ctx)
		local UI = ctx.W.UI
		if UI.Bug and UI.Bug.Shown and UI.Bug.Shown() then
			if UI.Bug.Close then UI.Bug.Close() end
			ctx:note("close the bug report")
			ctx:advance(0.5)
		end
		if not (UI.IsShown and UI.IsShown()) then
			UI.Toggle(true)
			ctx:note("open the phone")
			ctx:advance(3)
		else
			ctx:advance(4)
		end
		for _ = 1, 3 do
			if has(ctx, "^Riders$") then break end
			ctx:advance(3)
		end
		if not has(ctx, "^Riders$") then
			pcall(ctx.me.clickText, ctx.me, "^Drive$", { pattern = true })
			ctx:note("click the Drive tab")
			ctx:advance(1)
		end
		if not has(ctx, "^Riders$") and UI.ShowDrive then
			pcall(UI.ShowDrive, "console")
			ctx:advance(1)
		end
		if not has(ctx, "^Riders$") then ctx:cannot("could not reach the Drive console") end
		local drv = D(ctx)
		if drv and drv.CurrentScreen and UI.ShowDrive and (drv.CurrentScreen() ~= "console" or (drv.SheetOpen and drv.SheetOpen())) then
			if drv.CurrentScreen() ~= "console" then
				pcall(UI.ShowDrive, "console")
				ctx:note("back to the Drive console")
				ctx:advance(1)
			end
			if drv.SheetOpen and drv.SheetOpen() then
				ctx.me:pressEscape()
				ctx:note("Escape closes the sheet")
				ctx:advance(1)
				if not (UI.IsShown and UI.IsShown()) then
					UI.Toggle(true)
					ctx:advance(4)
					if not has(ctx, "^Riders$") then
						pcall(ctx.me.clickText, ctx.me, "^Drive$", { pattern = true })
						ctx:advance(1)
					end
				end
			end
		end
	end

	local function press(ctx, pat, opts)
		opts = opts or {}
		opts.pattern = true
		local ok, err = pcall(ctx.me.clickText, ctx.me, pat, opts)
		ctx:note("click " .. pat)
		ctx:advance(opts.wait or 1)
		return ok, err
	end

	local function confirmClose(ctx)
		local env = ctx.me and ctx.me.env
		if env and env.StaticPopup_FindVisible and env.StaticPopup_FindVisible("WUBER_CLOSE_RIDERS") then
			local dlg = env.StaticPopupDialogs and env.StaticPopupDialogs.WUBER_CLOSE_RIDERS
			env.StaticPopup_Hide("WUBER_CLOSE_RIDERS")
			if dlg and dlg.OnAccept then dlg.OnAccept() end
			ctx:advance(1)
		end
	end

	local function closeShop(ctx)
		if DR(ctx).IsOpen() then
			press(ctx, "^Close$")
			confirmClose(ctx)
			local drv = D(ctx)
			if drv and drv.SheetOpen and drv.SheetOpen() and has(ctx, "^Nice$") then press(ctx, "^Nice$") end
		end
	end

	local function clearQueue(ctx)
		local cs = DR(ctx).customers
		if type(cs) ~= "table" then return end
		local names = {}
		for _, c in pairs(cs) do
			if type(c) == "table" and c.name then names[#names + 1] = c.name end
		end
		for _, name in ipairs(names) do
			pcall(DR(ctx).Do, "DROP", name)
		end
		if D(ctx) and D(ctx).RefreshNow then D(ctx).RefreshNow() end
		ctx:advance(0.5)
	end

	local function strangerWhisper(ctx, name, text)
		local w = ctx.w
		if not w:player(name) then w:addBot(name, {}) end
		w:botWhisper(name, ctx.me, text)
		ctx:note("whisper from " .. name .. ": " .. text)
		ctx:advance(2)
	end

	local function rowFrameOf(ctx, name)
		local ui = D(ctx) and D(ctx).ui and D(ctx).ui.console
		if not (ui and ui.rows) then return nil end
		local k = key(name)
		for _, r in ipairs(ui.rows) do
			if r:IsShown() and r.c and r.c.name and key(r.c.name):find(k, 1, true) then
				return r
			end
		end
		return nil
	end

	local function need(ctx)
		noCombat(ctx)
		if not (DR(ctx) and DR(ctx).IsOpen) then ctx:cannot("no driver engine") end
	end

	Hunt.promise{
		id = "b4console.closed_dims_pause_and_advertise",
		area = "DriverConsole",
		text = "When you are closed, Pause and Advertise are dimmed and clicking Pause does nothing.",
		source = "Wuber/UI/Driver/Draw.lua:286-288; Wuber/UI/Driver/Build.lua:430,455",
		kind = "scenario",
		needs = { role = "warlock" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			openDrive(ctx)
			closeShop(ctx)
			if DR(ctx).IsOpen() then ctx:na("could not close") end
			local ui = D(ctx).ui and D(ctx).ui.console
			if not (ui and ui.pause and ui.advert) then ctx:cannot("no Pause or Advertise button") end
			if math.abs((ui.pause:GetAlpha() or 1) - 0.5) > 0.05 then
				ctx:fail("You are closed on the Drive console and Pause is not dimmed (alpha " .. tostring(ui.pause:GetAlpha()) .. ").")
			end
			if math.abs((ui.advert:GetAlpha() or 1) - 0.5) > 0.05 then
				ctx:fail("You are closed on the Drive console and Advertise is not dimmed (alpha " .. tostring(ui.advert:GetAlpha()) .. ").")
			end
			ctx.me:clickOn(ui.pause)
			ctx:advance(0.5)
			if DR(ctx).IsPaused() or DR(ctx).IsOpen() then
				ctx:fail("You are closed, click Pause, and Wuber changed your open or paused state.")
			end
		end,
	}

	Hunt.promise{
		id = "b4console.closed_empty_state",
		area = "DriverConsole",
		text = "When you are closed with no riders in your queue, the console says You're closed and Riders who ask show up here.",
		source = "Wuber/UI/Driver/Draw.lua:551-553",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			openDrive(ctx)
			closeShop(ctx)
			clearQueue(ctx)
			if #DR(ctx).Sorted() > 0 then ctx:na("riders still in queue") end
			if not has(ctx, "You're closed") then
				ctx:fail("You are closed with an empty queue and the console does not say You're closed.", allText(ctx))
			end
			if not has(ctx, "Riders who ask show up here") then
				ctx:fail("You are closed with an empty queue and the console does not say Riders who ask show up here.", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "b4console.paused_empty_state",
		area = "DriverConsole",
		text = "When you are paused with no riders in your queue, the console says Paused and No new invites until you resume.",
		source = "Wuber/UI/Driver/Draw.lua:554-556",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			openDrive(ctx)
			if not DR(ctx).IsOpen() then press(ctx, "^Open$") end
			if not DR(ctx).IsOpen() then ctx:na("not open") end
			clearQueue(ctx)
			if #DR(ctx).Sorted() > 0 then ctx:na("riders still in queue") end
			if not DR(ctx).IsPaused() then press(ctx, "^Pause$") end
			if not DR(ctx).IsPaused() then ctx:na("could not pause") end
			if not has(ctx, "^Paused$") then
				ctx:fail("You are paused with an empty queue and the console does not say Paused.", allText(ctx))
			end
			if not has(ctx, "No new invites until you resume") then
				ctx:fail("You are paused with an empty queue and the console does not say No new invites until you resume.", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "b4console.open_empty_shows_whisper_word",
		area = "DriverConsole",
		text = "When you are open with no riders in your queue, the console says Waiting for riders and names your whisper word.",
		source = "Wuber/UI/Driver/Draw.lua:557-560",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			openDrive(ctx)
			if not DR(ctx).IsOpen() then press(ctx, "^Open$") end
			if not DR(ctx).IsOpen() then ctx:na("not open") end
			if DR(ctx).IsPaused() then press(ctx, "^Resume$") end
			if DR(ctx).IsPaused() then ctx:na("paused") end
			clearQueue(ctx)
			if #DR(ctx).Sorted() > 0 then ctx:na("riders still in queue") end
			if not has(ctx, "Waiting for riders") then
				ctx:fail("You are open with an empty queue and the console does not say Waiting for riders.", allText(ctx))
			end
			local word = D(ctx).WhisperWord and D(ctx).WhisperWord() or "summon"
			if not has(ctx, "Whisper word: " .. word) then
				ctx:fail("You are open with an empty queue and the console does not name your whisper word (" .. tostring(word) .. ").", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "b4console.fare_pill_opens_price_sheet",
		area = "DriverConsole",
		text = "Clicking your fare and destination on the status strip opens the price and place sheet.",
		source = "Wuber/UI/Driver/Build.lua:104-108",
		kind = "scenario",
		needs = { role = "warlock" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			openDrive(ctx)
			local ui = D(ctx).ui and D(ctx).ui.console
			if not (ui and ui.fare and ctx:visible(ui.fare)) then ctx:cannot("no fare pill on status strip") end
			ctx.me:clickOn(ui.fare)
			ctx:advance(0.5)
			if not (D(ctx).SheetOpen and D(ctx).SheetOpen()) then
				ctx:fail("You click your fare and destination on the status strip and the price and place sheet does not open.", allText(ctx))
			end
			if not has(ctx, "My price") then
				ctx:fail("You click your fare on the status strip and the opened sheet does not show My price.", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "b4console.today_strip_opens_earnings",
		area = "DriverConsole",
		text = "Clicking today's takings on the status strip opens your Earnings screen.",
		source = "Wuber/UI/Driver/Build.lua:120-125",
		kind = "scenario",
		needs = { role = "warlock" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			openDrive(ctx)
			local ui = D(ctx).ui and D(ctx).ui.console
			if not (ui and ui.today and ctx:visible(ui.today)) then ctx:cannot("no today's takings strip") end
			ctx.me:clickOn(ui.today)
			ctx:advance(0.8)
			if D(ctx).CurrentScreen() ~= "earnings" then
				ctx:fail("You click today's takings on the status strip and the Earnings screen does not open (on " .. tostring(D(ctx).CurrentScreen()) .. ").", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "b4console.skip_pill_skips_and_shift_blocks",
		area = "DriverConsole",
		text = "When a rider is waiting on the big button, clicking Skip takes them off the list silently, and Shift-clicking Skip skips and blocks them.",
		source = "Wuber/UI/Driver/Build.lua:380-384",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = function(sit) return canDrive(sit) and sit.opt_autoInvite ~= "off" end,
		check = function(ctx)
			need(ctx)
			if ctx.w:player("Zed Skip") or ctx.w:player("Zed Block") then ctx:na("names taken") end
			openDrive(ctx)
			if not DR(ctx).IsOpen() then press(ctx, "^Open$") end
			if DR(ctx).IsPaused() then press(ctx, "^Resume$") end
			if not DR(ctx).IsOpen() or DR(ctx).IsPaused() then ctx:na("not open and unpaused") end
			if ctx.W.Advanced and not ctx.W.Advanced() then
				ctx.me:slash("/wuber advanced")
				ctx:advance(1)
			end
			D(ctx).RefreshNow()
			strangerWhisper(ctx, "Zed Skip", "summon pls")
			local z = ctx.w:player("Zed Skip")
			if z and z.pendingInvite then
				ctx.w:acceptInvite(z)
				ctx:advance(2)
			end
			D(ctx).RefreshNow()
			local ui = D(ctx).ui and D(ctx).ui.console
			if not (ui and ui.skip and ctx:visible(ui.skip)) then ctx:na("Skip pill not shown for this rider") end
			ctx.me:clickOn(ui.skip)
			ctx:advance(0.5)
			if DR(ctx).customers[key("Zed Skip")] then
				ctx:fail("You click Skip on the hero card and the rider is still in your queue.", allText(ctx))
			end
			if DR(ctx).BlockEntry(key("Zed Skip")) then
				ctx:fail("You plain-click Skip and the rider is blocked.")
			end
			strangerWhisper(ctx, "Zed Block", "summon pls")
			local zb = ctx.w:player("Zed Block")
			if zb and zb.pendingInvite then
				ctx.w:acceptInvite(zb)
				ctx:advance(2)
			end
			D(ctx).RefreshNow()
			if not (ui.skip and ctx:visible(ui.skip)) then ctx:na("Skip pill not shown for second rider") end
			ctx.me.mods.shift = true
			local ok, err = pcall(ctx.me.clickOn, ctx.me, ui.skip)
			ctx.me.mods.shift = false
			if not ok then error(err, 0) end
			ctx:advance(0.5)
			if DR(ctx).customers[key("Zed Block")] then
				ctx:fail("You Shift-click Skip and the rider is still in your queue.", allText(ctx))
			end
			if not DR(ctx).BlockEntry(key("Zed Block")) then
				ctx:fail("You Shift-click Skip and the rider is not added to your blocked list.")
			end
		end,
	}

	Hunt.promise{
		id = "b4console.row_note_and_gift_marks",
		area = "DriverConsole",
		text = "A rider with a saved note or a gifted ride shows a mark on their queue row and shows the note or gift date in the row's tooltip.",
		source = "Wuber/UI/Driver/Rows.lua:150; Wuber/UI/Driver/Customers.lua:255-279",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			if ctx.w:player("Zed Mark") then ctx:na("name taken") end
			openDrive(ctx)
			if not DR(ctx).IsOpen() then press(ctx, "^Open$") end
			if not DR(ctx).IsOpen() then ctx:na("not open") end
			if not (DR(ctx).SetNote and DR(ctx).SetGifted) then ctx:cannot("no customer book note/gift API") end
			DR(ctx).SetNote("Zed Mark", "Fast payer")
			DR(ctx).SetGifted("Zed Mark")
			strangerWhisper(ctx, "Zed Mark", "summon pls")
			local r = rowFrameOf(ctx, "Zed Mark")
			if not r then ctx:na("rider row not shown") end
			if not (r.noteMark and r.noteMark:IsShown()) then
				ctx:fail("A rider has a saved note and their queue row shows no note mark.")
			end
			if not (r.giftMark and r.giftMark:IsShown()) then
				ctx:fail("A rider has a gifted ride stamp and their queue row shows no gift mark.")
			end
			local tip = D(ctx).RowTip(r.c) or ""
			if not tip:find("Note: Fast payer", 1, true) then
				ctx:fail("A rider has a saved note and the row's tooltip does not show it (" .. tip .. ").")
			end
			if not tip:find("Gifted on ", 1, true) then
				ctx:fail("A rider has a gifted ride stamp and the row's tooltip does not show the gift date (" .. tip .. ").")
			end
		end,
	}

	Hunt.promise{
		id = "b4console.row_returning_rider_chip",
		area = "DriverConsole",
		text = "In Advanced mode, a returning rider who has paid you before shows how many rides they have taken with you on their queue row.",
		source = "Wuber/UI/Driver/Rows.lua:612-633",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			if ctx.w:player("Zed Return") then ctx:na("name taken") end
			openDrive(ctx)
			if not DR(ctx).IsOpen() then press(ctx, "^Open$") end
			if not DR(ctx).IsOpen() then ctx:na("not open") end
			if ctx.W.Advanced and not ctx.W.Advanced() then
				ctx.me:slash("/wuber advanced")
				ctx:advance(1)
			end
			-- Record one prior paid ride so the next ride is their 2nd
			strangerWhisper(ctx, "Zed Return", "summon pls")
			DR(ctx).Do("PAID", "Zed Return", 5000, "m")
			ctx:advance(2)
			DR(ctx).Do("DROP", "Zed Return")
			ctx:advance(1)
			if (DR(ctx).RideCount and DR(ctx).RideCount("Zed Return") or 0) < 1 then
				ctx:cannot("prior paid ride was not counted")
			end
			strangerWhisper(ctx, "Zed Return", "summon pls")
			D(ctx).RefreshNow()
			local r = rowFrameOf(ctx, "Zed Return")
			if not r then ctx:na("rider row not shown") end
			if not (r.again and r.again:IsShown()) then
				ctx:fail("In Advanced mode, a returning rider who paid you before has no returning-rider chip on their queue row.")
			end
			local txt = r.again.label and r.again.label:GetText() or ""
			if not txt:find("with you", 1, true) then
				ctx:fail("A returning rider's chip does not say how many rides they have with you (" .. tostring(txt) .. ").")
			end
		end,
	}

	Hunt.promise{
		id = "b4console.row_invite_to_wuber_toggles",
		area = "DriverConsole",
		text = "In Advanced mode, tapping Invite to Wuber on a chat rider's row queues the whisper for your next big-button click, and tapping again cancels it.",
		source = "Wuber/UI/Driver/Rows.lua:651-675",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			if ctx.w:player("Zed Chat") then ctx:na("name taken") end
			openDrive(ctx)
			if not DR(ctx).IsOpen() then press(ctx, "^Open$") end
			if not DR(ctx).IsOpen() then ctx:na("not open") end
			if ctx.W.Advanced and not ctx.W.Advanced() then
				ctx.me:slash("/wuber advanced")
				ctx:advance(1)
			end
			strangerWhisper(ctx, "Zed Chat", "summon pls")
			local r = rowFrameOf(ctx, "Zed Chat")
			if not r then ctx:na("rider row not shown") end
			if not (r.getapp and r.getapp:IsShown()) then ctx:na("Invite to Wuber pill not offered on this row") end
			ctx.me:scrollIntoView(r.getapp)
			ctx:advance(0.2)
			if not ctx.me:onScreen(r.getapp) or ctx.me:topAt(r.getapp) ~= r.getapp then
				ctx:na("the Invite to Wuber pill is outside the reachable list view")
			end
			ctx.me:clickOn(r.getapp)
			ctx:advance(0.5)
			if DR(ctx).GetAppState(r.c, true) ~= "queued" then
				ctx:fail("You tap Invite to Wuber on a chat rider's row and it is not queued for your next big-button click.")
			end
			if not (r.getapp.label and r.getapp.label:GetText() == "Next click sends") then
				ctx:fail("You tap Invite to Wuber and the pill does not change to Next click sends.")
			end
			ctx.me:clickOn(r.getapp)
			ctx:advance(0.5)
			if DR(ctx).GetAppState(r.c, true) == "queued" then
				ctx:fail("You tap Next click sends to cancel Invite to Wuber and it stays queued.")
			end
		end,
	}

	Hunt.promise{
		id = "b4console.row_hold_opens_menu",
		area = "DriverConsole",
		text = "Holding the mouse button on a rider's queue row opens the menu with all options for that rider.",
		source = "Wuber/UI/Driver/Rows.lua:171,405-433",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			if ctx.w:player("Zed Hold") then ctx:na("name taken") end
			openDrive(ctx)
			if not DR(ctx).IsOpen() then press(ctx, "^Open$") end
			if not DR(ctx).IsOpen() then ctx:na("not open") end
			strangerWhisper(ctx, "Zed Hold", "summon pls")
			local r = rowFrameOf(ctx, "Zed Hold")
			if not r then ctx:na("rider row not shown") end
			local down = r:GetScript("OnMouseDown")
			local up = r:GetScript("OnMouseUp")
			if type(down) ~= "function" then ctx:cannot("no OnMouseDown on queue row") end
			down(r, "LeftButton")
			ctx:advance(0.5)
			if type(up) == "function" then up(r, "LeftButton") end
			ctx:advance(0.3)
			if not (D(ctx).SheetOpen and D(ctx).SheetOpen()) then
				ctx:fail("You hold the mouse button on a rider's queue row and the options menu does not open.", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "b4console.wide_console_shows_side_pane",
		area = "DriverConsole",
		text = "When the Drive console is unfolded, the side pane shows your Crew, Today's takings, and your best hours alongside the riders.",
		source = "Wuber/UI/Driver/Console.lua:6-9,426-572",
		kind = "scenario",
		needs = { role = "warlock" },
		when = function(sit) return canDrive(sit) and sit.fold ~= "narrow" end,
		check = function(ctx)
			need(ctx)
			openDrive(ctx)
			local Fold = ctx.W.UI and ctx.W.UI.Fold
			if Fold and Fold.Can and not Fold.Can() then ctx:na("screen too narrow to unfold") end
			if Fold and Fold.IsOpen and not Fold.IsOpen() and Fold.Set then
				Fold.Set(true)
				ctx:advance(0.5)
			end
			if not (D(ctx).Wide and D(ctx).Wide("console")) then ctx:na("console is not unfolded") end
			D(ctx).RefreshNow()
			ctx:advance(0.5)
			if not has(ctx, "^Crew$") then
				ctx:fail("The Drive console is unfolded and the side pane does not show Crew.", allText(ctx))
			end
			if not has(ctx, "Today's takings") then
				ctx:fail("The Drive console is unfolded and the side pane does not show Today's takings.", allText(ctx))
			end
			if not (has(ctx, "Top window:") or has(ctx, "Open a few hours to find your best ones")) then
				ctx:fail("The Drive console is unfolded and the side pane does not show your best hours.", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "b4console.business_blocked_count",
		area = "DriverConsole",
		text = "At the bottom of the Drive console, Your business shows Blocked with the number of blocked players when any are blocked.",
		source = "Wuber/UI/Driver/Draw.lua:838-841",
		kind = "scenario",
		needs = { role = "warlock" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			openDrive(ctx)
			if not DR(ctx).Blacklist then ctx:cannot("no Blacklist API") end
			DR(ctx).Blacklist("Zed BlockedOne", "test")
			D(ctx).RefreshNow()
			ctx:advance(0.5)
			local bl = DR(ctx).BlockedList()
			local n = type(bl) == "table" and #bl or 0
			if n < 1 then ctx:cannot("could not add blocked player") end
			if not has(ctx, "Blocked %(" .. n .. "%)") then
				ctx:fail("You have " .. n .. " blocked player(s) and Your business does not show Blocked (" .. n .. ").", allText(ctx))
			end
		end,
	}
end
