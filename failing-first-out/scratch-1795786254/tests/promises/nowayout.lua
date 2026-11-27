-- Bug-hunt promises for Blind Spot 4 ("No way out": items 6, 7, 8, REC-04).
-- Format matches repo/tests/promises/*.lua.
return function(Hunt)
	local function canDrive(sit) return sit.saved == nil or sit.saved == "fresh" end
	local function isRider(sit) return sit.role == nil or sit.role == "rider" end

	local function has(ctx, pat)
		for _, t in ipairs(ctx:texts()) do if t:find(pat) then return t end end
		return nil
	end
	local function allText(ctx) return table.concat(ctx:texts(), " | ") end
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end
	local function noCombat(ctx) if ctx.me.player.combat then ctx:na("in combat") end end

	local function openDrive(ctx)
		local UI = ctx.W.UI
		if UI.Bug and UI.Bug.Shown and UI.Bug.Shown() then
			if UI.Bug.Close then UI.Bug.Close() end
			ctx:advance(0.5)
		end
		if not (UI.IsShown and UI.IsShown()) then
			UI.Toggle(true)
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
			ctx:advance(1)
		end
		if not has(ctx, "^Riders$") and UI.ShowDrive then
			pcall(UI.ShowDrive, "console")
			ctx:advance(1)
		end
		if not has(ctx, "^Riders$") then ctx:cannot("could not reach the Drive console") end
	end

	-- Item 6 (run 1): the driver can always remove a rider who is still in the group. A rider taken off the list ("Take off the
	-- list" keeps DR.ignored[key]) has no row; with "Remove riders after the thanks" on (kickAfter ~= false), the big button
	-- offers Remove (a /uninvite step) once nothing else is pending (201b, Drive/Plan.lua DR.StrayIgnored); with it off,
	-- the big button tells the driver "taken off the list: right-click their portrait to remove them" (Drive/Plan.lua:87-92).
	Hunt.promise{
		id = "nowayout.driver_can_remove_rider",
		area = "Driver",
		text = "A rider the driver took off the list but who is still in the group has a removal path: with auto-remove on, the big button offers Remove (/uninvite) once nothing else is pending; with auto-remove off, it tells the driver to right-click their portrait.",
		source = "RUN1 item 6 (Drive/Plan.lua:87-92, :628 DR.StrayIgnored; UI/Driver/Rows.lua drop)",
		kind = "scenario",
		needs = { role = "warlock", ride = "arrived" },
		when = canDrive,
		check = function(ctx)
			noCombat(ctx)
			local DR = ctx.W.Drive
			if not (DR and DR.IsOpen and DR.IsOpen()) then ctx:na("not open") end
			local rider = ctx.peers and ctx.peers.rider
			if not rider then ctx:cannot("no rider peer") end
			local rName = rider.player.name
			local rKey = key(rName)
			local c = DR.customers[rKey]
			if not c then ctx:cannot("rider not on customer list") end

			openDrive(ctx)
			DR.Do("DROP", rName) -- what the row's "Take off the list" does (UI/Driver/Rows.lua D.RowAction "drop")
			ctx:advance(1)

			local p = ctx.w:player(rName)
			if not (p and p.group) then ctx:na("rider already left the group") end
			-- the Remove offer waits for a trade that is open (run 1 item 6); once the rider's side has closed it, it must come
			if DR.trade and rider.env.CancelTrade then
				rider.env.CancelTrade()
				ctx:advance(1)
			end
			if DR.trade then ctx:na("the trade could not be closed") end
			if not DR.ignored[rKey] then ctx:na("not kept as taken off the list") end

			local plan = DR.Plan and DR.Plan() or {}
			local kickOn = not (DR.opts and DR.opts().kickAfter == false)
			if kickOn then
				local uninvite = type(plan.macrotext) == "string" and plan.macrotext:lower():find("/uninvite", 1, true) ~= nil
				local remove = type(plan.title) == "string" and plan.title:find("Remove", 1, true) ~= nil
				if not (uninvite and remove) then
					ctx:fail("You took " .. rName .. " off the list while they are still in your group, and Wuber gives you no way to remove them from the group (the button says: " .. tostring(plan.title) .. ").", allText(ctx))
				end
			else
				local titled = type(plan.title) == "string" and plan.title:find("is in the group", 1, true) ~= nil
				local subOk = type(plan.sub) == "string" and plan.sub:find("taken off the list: right-click their portrait to remove them", 1, true) ~= nil
				if not (titled and subOk) then
					ctx:fail("You took " .. rName .. " off the list with auto-remove off, and the big button does not tell you how to remove them (title=" .. tostring(plan.title) .. ", sub=" .. tostring(plan.sub) .. ").", allText(ctx))
				end
			end
		end,
	}

	-- Item 7 (run 1): a rider at the pay step whom the driver took out of the group (trade cancelled, marked paid by hand)
	-- is not left on "Waiting for <driver> to trade": the ride ends about 5 s after the group is gone (Net/Rides.lua CX.autoEnd).
	-- A rider who was never at the pay step keeps the 60 s (201b), so only "paying" counts as stuck here.
	Hunt.promise{
		id = "nowayout.rider_not_stuck_after_cancelled_trade",
		area = "Ride",
		text = "A rider at the pay step who is taken out of the driver's group after a cancelled trade is not left waiting for a trade: the ride ends within about 8 seconds.",
		source = "RUN1 item 7 (Net/Rides.lua CX.autoEnd, run1_j)",
		kind = "scenario",
		needs = { role = "rider", ride = "arrived" },
		when = function(sit) return isRider(sit) and sit.net ~= "none" and sit.net ~= "oldpeer" end,
		check = function(ctx)
			noCombat(ctx)
			local d = ctx.peers and ctx.peers.driver
			if not d then ctx:cannot("no driver peer") end
			if not (ctx.W.ride and (ctx.W.ride.state == "arrived" or ctx.W.ride.state == "paying")) then
				ctx:na("rider is not in arrived/paying state")
			end
			if not ctx.me.player.group then ctx:na("rider is not in the driver's group") end

			ctx.w:openTrade(d, ctx.me)
			ctx:advance(0.5)
			if ctx.me.env.CancelTrade then ctx.me.env.CancelTrade() end
			ctx:advance(0.5)
			if not (ctx.W.ride and ctx.W.ride.state == "paying") then ctx:na("the trade did not put the ride at the pay step") end

			-- the driver marked the rider paid by hand (the rider's side was not told) and took the rider out of the group
			ctx:advance(0.5)
			if ctx.me.player.group then ctx.w:uninvite(d, ctx.name) end
			ctx:advance(8)

			local st = ctx.W.ride and ctx.W.ride.state
			if st == "paying" then
				ctx:fail("After a cancelled trade the driver removed you from the group, yet your ride still says 'paying' ('Waiting for " .. tostring(d.player.name) .. " to trade') 8 seconds later.", allText(ctx))
			end
		end,
	}

	-- REC-04: "the rider is never stuck waiting" after CANCEL_SUMMON out of group
	Hunt.promise{
		id = "nowayout.rider_never_stuck_waiting",
		area = "Ride",
		text = "A rider who leaves the group while the summon box is up is not shown as 'in the group' afterwards.",
		source = "RUN1 REC-04 (Net/Rides.lua CANCEL_SUMMON)",
		kind = "scenario",
		needs = { role = "rider", ride = "summoning" },
		when = function(sit) return isRider(sit) and sit.net ~= "none" and sit.net ~= "oldpeer" end,
		check = function(ctx)
			noCombat(ctx)
			if not (ctx.W.ride and ctx.W.ride.state == "portal") then
				ctx:na("rider does not have an active summon portal")
			end
			-- Real-client order (recorded, 20 of 20): CANCEL_SUMMON fires at the exact instant of the group exit (the fake game's
			-- World:leave does the same); the roster update follows about 50 ms later.
			if ctx.me.player.group then ctx.w:leave(ctx.name) end
			ctx:advance(2)

			local st = ctx.W.ride and ctx.W.ride.state
			if st == "ingroup" and not ctx.W.InGroup() then
				ctx:fail("CANCEL_SUMMON fired as you left the group, and your ride still says 'ingroup' although you are no longer in a group.", allText(ctx))
			end
		end,
	}
	-- r53 A: Ride/confirm always has a way back (the author 24 Nov 13:21: the Ride tab did nothing, close + reopen came back to confirm)
	Hunt.promise{
		id = "nowayout.ride_confirm_back",
		area = "Ride",
		text = "A rider on a driver's confirm page reaches Ride/home with one click on the Ride tab, with the back chevron, and by closing and reopening.",
		source = "r53 A (Window.lua SelectTab, Toggle)",
		kind = "scenario",
		needs = { role = "rider" },
		when = function(sit) return isRider(sit) and sit.net ~= "oldpeer" end,
		check = function(ctx)
			local UI, K = ctx.W.UI, ctx.W.Mod("UI.Kit")
			if not (UI and UI.Show and K and K.ui) then ctx:na("no window") end
			if ctx.W.ride then ctx:na("a ride is in progress") end
			local key = "Nowayout Driver-Test"
			ctx.W.drivers = ctx.W.drivers or {}
			ctx.W.drivers[key] = { name = "Nowayout Driver", key = key, dest = "Orgrimmar", price = 5000, state = "open", team = 3, heard = ctx.W.Now and ctx.W.Now() or 0 }
			local function toConfirm()
				if not UI.IsShown() then UI.Toggle(true) ctx:advance(2) end
				UI.Show("confirm", key) ctx:advance(1)
				if K.ui.screen ~= "confirm" then ctx:na("the confirm page did not open") end
			end
			local function tabClick()
				for _, tab in ipairs(K.ui.tabs) do
					if tab.name == "Ride" then tab.button:GetScript("OnClick")(tab.button) end
				end
				ctx:advance(1)
			end
			toConfirm() tabClick()
			if K.ui.screen ~= "home" then ctx:fail("One click on the Ride tab left you on '" .. tostring(K.ui.screen) .. "' instead of Ride/home.", "") end
			toConfirm()
			local back = K.ui.screens and K.ui.screens.confirm and K.ui.screens.confirm.back
			if back then back:GetScript("OnClick")(back) ctx:advance(1) end
			if K.ui.screen ~= "home" then ctx:fail("The back chevron on the confirm page left you on '" .. tostring(K.ui.screen) .. "'.", "") end
			toConfirm()
			UI.Toggle(false) ctx:advance(2)
			UI.Toggle(true) ctx:advance(2)
			if K.ui.screen ~= "home" then ctx:fail("Closing and reopening on the confirm page opened '" .. tostring(K.ui.screen) .. "', not Ride/home.", "") end
		end,
	}
end
