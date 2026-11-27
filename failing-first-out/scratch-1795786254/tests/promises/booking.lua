-- Promises about booking a ride (owner HOME): the Confirm screen, the Fly-versus-Summon dial, the Request click, Finding,
-- cancelling, a driver declining or not answering, the Sorry screen, the paid screen and rating. Written from what the
-- player was told: the CurseForge page ("Hit Request. Wuber accepts the group invite for you", "what flying there would
-- cost, boats and zeppelins included"), the 2.3.2 changelog (bounties end when you book, the Done screen), tooltips (the
-- bounty chip: "It ends when you book a ride"; the stars: "Only you see your ratings, in Trips") and the screens' own words.
-- The checks reach things the way a player does: /wuber, a click on a driver card, a click on Request summon (a real
-- click on the secure button), Cancel, Try another driver, other players' windows. An unanswered request is made the way a
-- player can make one: the click is made in combat (no chat whisper goes) and the request message is lost on the way.
return function(Hunt)
	local function is(sit, dial, want)
		local v = sit[dial]
		if v == nil then return true end
		if type(want) == "table" then return want[v] == true end
		return v == want
	end

	local function kit(ctx)
		local K = ctx:mod("UI.Kit")
		return K and K.ui or {}
	end
	local function screens(ctx)
		local WM = ctx:mod("UI.Window")
		return WM and type(WM.screens) == "table" and WM.screens or {}
	end
	local function homeScr(ctx) return screens(ctx).home end

	local function gold(c)
		local g, s, k = math.floor(c / 10000), math.floor((c % 10000) / 100), c % 100
		local t = {}
		if g > 0 then t[#t + 1] = g .. "g" end
		if s > 0 then t[#t + 1] = s .. "s" end
		if k > 0 then t[#t + 1] = k .. "c" end
		if #t == 0 then return "0c" end
		return table.concat(t, " ")
	end
	-- "47s 80c", "1g 1s" or the coin-icon form ("47|TInterface\MoneyFrame\UI-SilverIcon:0:0:2:0|t 80|T...CopperIcon...|t") -> copper
	local function copperOf(text)
		local total, found = 0, false
		for n, kind in text:gmatch("(%d+)|TInterface\\MoneyFrame\\UI%-(%a+)Icon[^|]*|t") do
			total = total + tonumber(n) * (kind == "Gold" and 10000 or kind == "Silver" and 100 or 1)
			found = true
		end
		if found then return total end
		for n, unit in text:gmatch("(%d+)([gsc])") do
			total = total + tonumber(n) * (unit == "g" and 10000 or unit == "s" and 100 or 1)
			found = true
		end
		return found and total or nil
	end

	local function joined(ctx) return table.concat(ctx:texts(), " | ") end
	local function has(ctx, text)
		for _, t in ipairs(ctx:texts()) do
			if t:find(text, 1, true) then return t end
		end
		return nil
	end
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end

	-- a card below or above the Home list's clip is not on screen: the player scrolls the list (mouse wheel over it);
	-- when it is still not inside the list, the check does not apply (the card cannot be tapped)
	local function intoView(ctx, card)
		local function where()
			local r = ctx.H.rect(card)
			local par = card:GetParent()
			local clip = par and par:GetParent()
			local cr = clip and ctx.H.rect(clip)
			if not (r and cr) then return true end
			local cy = r.b + r.h / 2
			if cy < cr.b then return false, -1, clip end
			if cy > cr.b + cr.h then return false, 1, clip end
			return true
		end
		for _ = 1, 12 do
			local ok, dir, clip = where()
			if ok then return end
			local fn = clip.GetScript and clip:GetScript("OnMouseWheel")
			if not fn then break end
			fn(clip, dir)
			ctx:advance(0.6)
			ctx:note("scroll the list " .. (dir < 0 and "down" or "up"))
		end
		if not where() then ctx:na("the driver's card is outside the Home list and could not be scrolled into view") end
	end

	local function cards(ctx)
		local out = {}
		for k, c in pairs(kit(ctx).cards or {}) do
			if c.key and c.view and ctx:visible(c) then out[#out + 1] = { key = k, card = c, y = c.targetY or c.curY or 0 } end
		end
		table.sort(out, function(a, b) if a.y ~= b.y then return a.y > b.y end return a.key < b.key end)
		return out
	end

	local function conditions(ctx)
		if ctx.me.player.combat then ctx:na("in combat") end
		local db = ctx.W.db
		if type(db) ~= "table" or db.coach ~= true then ctx:na("the first-open coach marks are not done") end
		local K = ctx:mod("UI.Kit")
		if K and type(K.rideActive) == "function" then
			local ok, active = pcall(K.rideActive)
			if ok and active then ctx:na("a ride is on") end
		end
	end

	local function dismissTip(ctx)
		local Tips = ctx:mod("UI.Tips")
		if Tips and type(Tips.Card) == "function" then
			local ok, c = pcall(Tips.Card)
			if ok and type(c) == "table" and ctx:visible(c) then
				pcall(Tips.Hide)
				ctx:advance(0.5)
				ctx:note("the tip card is tapped away")
			end
		end
	end


	-- Settings, Help, the report or the Wrapped story open over the screen: the player presses Escape / closes them
	local function clearOverlays(ctx)
		local UI = ctx.W.UI
		for _ = 1, 3 do
			local ui = kit(ctx)
			local WM = ctx:mod("UI.Rider.Wrapped")
			if WM and type(WM.Shown) == "function" and WM.Shown() then ctx:na("the Wrapped story is open over the screen") end
			local over = ui.settingsOpen or (type(UI.HelpShown) == "function" and UI.HelpShown())
				or (type(UI.Bug) == "table" and type(UI.Bug.Shown) == "function" and UI.Bug.Shown())
				or (WM and type(WM.Shown) == "function" and WM.Shown())
			if not over then return end
			if ui.settingsOpen and type(UI.CloseSettings) == "function" then pcall(UI.CloseSettings, true) end
			ctx.me:pressEscape()
			ctx:advance(0.8)
			ctx:note("press Escape over what is open")
			if not UI.IsShown() then
				ctx.me:slash("/wuber")
				ctx:advance(2.5)
				ctx:note("/wuber again")
			end
		end
	end

	local function openPhone(ctx)
		local UI = ctx.W.UI
		if not UI.IsShown() then
			ctx.me:slash("/wuber")
			ctx:advance(0.3)
			ctx:note("/wuber")
		end
		ctx:advance(2.5)
		clearOverlays(ctx)
		local ui = kit(ctx)
		if ui.tab ~= "Ride" then
			for _, tab in ipairs(ui.tabs or {}) do
				if tab.name == "Ride" and tab.button then ctx.me:clickOn(tab.button) ctx:advance(0.8) ctx:note("click the Ride tab") break end
			end
		end
	end

	local function openHome(ctx)
		conditions(ctx)
		local UI = ctx.W.UI
		openPhone(ctx)
		local ui = kit(ctx)
		if ui.tab ~= "Ride" then
			for _, tab in ipairs(ui.tabs or {}) do
				if tab.name == "Ride" and tab.button then ctx.me:clickOn(tab.button) ctx:advance(0.8) ctx:note("click the Ride tab") break end
			end
		end
		if ui.screen ~= "home" then ctx:na("Home is not reachable from this screen (" .. tostring(ui.screen) .. ")") end
		dismissTip(ctx)
		ctx:advance(1.5)
		-- 2.4: the What's new card (Got it) and the Skip the bird card can sit over Home on the first tap: the player closes them
		for _ = 1, 3 do
			local b = ctx.me:button("Got it")
			if b and ctx:visible(b) then
				ctx.me:clickOn(b)
				ctx:advance(0.6)
				ctx:note("close the What's new card (Got it)")
			else
				break
			end
		end
		local BirdM = ctx:mod("UI.Bird")
		local okc, bc = pcall(BirdM and BirdM.Card or function() end)
		if okc and type(bc) == "table" and ctx:visible(bc) and bc.x and ctx:visible(bc.x) then
			ctx.me:clickOn(bc.x)
			ctx:advance(0.6)
			ctx:note("close the Skip the bird card")
		end
		return homeScr(ctx)
	end

	local function cardOf(ctx, name)
		for _, c in ipairs(cards(ctx)) do
			if key(c.card.view.name) == key(name) then return c.card end
		end
		return nil
	end

	-- the player taps a driver's card on Home: the booking (Confirm) screen opens
	local function tapDriver(ctx, d)
		-- a tip card can arrive late, after the cards were closed: the player taps it away again
		dismissTip(ctx)
		local c = cardOf(ctx, d.name)
		if not c then ctx:na(d.name .. " has no card on Home here") end
		if c.view.state == "paused" then ctx:na(d.name .. " is paused") end
		intoView(ctx, c)
		-- the row must sit clear of the tab bar and the phone's home bar: what is drawn at the title's centre must be the card
		local function hitIsCard()
			local okc, cx, cy = pcall(c.title.GetCenter, c.title)
			if not (okc and cx) then return true end
			local ratio = c.title:GetEffectiveScale() / ctx.me.env.UIParent:GetEffectiveScale()
			local hit = ctx.me:frameAt(cx * ratio, cy * ratio)
			local f = hit
			while f do
				if f == c then return true end
				f = f.GetParent and f:GetParent() or nil
			end
			return false
		end
		for _ = 1, 8 do
			if hitIsCard() then break end
			local clip = c:GetParent() and c:GetParent():GetParent()
			local fn = clip and clip.GetScript and clip:GetScript("OnMouseWheel")
			if not fn then break end
			local r, cr = ctx.H.rect(c), ctx.H.rect(clip)
			-- below the middle of the list: scroll down, else up
			local dir = (r and cr and (r.b + r.h / 2) < (cr.b + cr.h / 2)) and -1 or 1
			fn(clip, dir)
			ctx:advance(0.6)
			ctx:note("scroll the list " .. (dir < 0 and "down" or "up") .. " until the row is clear of the bars")
		end
		if not hitIsCard() then ctx:na(d.name .. "'s card cannot be scrolled clear of the tab bar and the home bar here") end
		ctx.me:clickOn(c.title)
		ctx:advance(1)
		ctx:note("tap " .. d.name .. "'s card")
		if kit(ctx).screen ~= "confirm" then
			ctx:fail(("You tap %s's card on Home and the booking screen does not open (it shows %s)."):format(d.name, tostring(kit(ctx).screen)), joined(ctx))
		end
	end

	local function requestClick(ctx)
		local ok, err = pcall(ctx.me.clickText, ctx.me, "^Request summon", { pattern = true })
		if not ok then ctx:fail("You are on the booking screen and there is no Request summon button to click.", joined(ctx)) end
		ctx:advance(1)
		ctx:note("click Request summon")
	end

	-- the driver the net dial set up first; its fare is what a driver can really charge (the net dial's cheapest 20s and 30s
	-- are below Wuber's minimum fare, 50s, which every beacon is raised to)
	local function firstDriver(ctx)
		local d = ctx.facts.drivers and ctx.facts.drivers[1]
		if not (d and ctx.W.drivers and ctx.W.drivers[key(d.name)]) then ctx:na("the driver was not heard") end
		return { name = d.name, dest = d.dest, price = math.max(d.price, tonumber(ctx.W.MIN_PRICE) or 5000) }
	end

	local function riderOnly(sit) return is(sit, "role", "rider") and is(sit, "ride", "none") and is(sit, "combat", "no") end
	local LIST_NETS = { one = true, many = true, late = true }

	local NEW_NAMES = { "Eli Marsh", "Fay Doyle", "Gus Hale", "Hal Nash", "Ivy Cole" }
	local function driverOpens(ctx, spot, price)
		local name
		for _, n in ipairs(NEW_NAMES) do if not ctx.w:player(n) then name = n break end end
		if not name then ctx:cannot("no free name for a driver") end
		local d = ctx.w:addClient(name, { spot = spot, class = "WARLOCK", shards = 10, money = 100000 })
		if d.W.Char then d.W.Char().welcomed = true if price then d.W.Char().price = price end end
		if not (d.W.Driver and type(d.W.Driver.SetOnline) == "function") then ctx:cannot("the driver window has no Driver.SetOnline") end
		if d.W.Driver.SetOnline(true) == false then ctx:cannot("the driver could not open") end
		ctx:note(name .. " opens in " .. spot)
		return d, name
	end

	---------------------------------------------------------------------------------------------------------------
	-- Confirm
	---------------------------------------------------------------------------------------------------------------
	Hunt.promise{
		id = "booking.confirm_shows_booking",
		area = "Booking",
		text = "Tap a driver on Home and the booking screen shows where you go, who takes you, the fare you were shown, and a Request button with that fare.",
		source = "CurseForge page: see the price, and book; Confirm screen (destination headline, fare, driver card, Request summon)",
		kind = "scenario",
		when = function(sit) return riderOnly(sit) and LIST_NETS[sit.net or "one"] and is(sit, "group", "solo") end,
		check = function(ctx)
			openHome(ctx)
			local d = firstDriver(ctx)
			tapDriver(ctx, d)
			local t = joined(ctx)
			if not has(ctx, "Summon to " .. d.dest) then ctx:fail(("You tap %s, who goes to %s, and the booking screen does not say Summon to %s."):format(d.name, d.dest, d.dest), t) end
			if not has(ctx, d.name) then ctx:fail(("You tap %s and the booking screen does not show them."):format(d.name), t) end
			if not has(ctx, "Request summon \194\183 " .. gold(d.price)) then
				ctx:fail(("You tap %s, who charges %s, and the Request button does not say %s."):format(d.name, gold(d.price), gold(d.price)), t)
			end
		end,
	}

	Hunt.promise{
		id = "booking.dial_numbers_agree",
		area = "Booking",
		text = "The Fly versus Summon dial's verdict adds up with the two prices beside it: what it says is cheaper or saved is the real difference between the summon's fare and the flight's price.",
		source = "tooltip on the dial (weighs time saved against extra cost); CurseForge page: what flying there would cost",
		kind = "scenario",
		when = function(sit) return riderOnly(sit) and LIST_NETS[sit.net or "one"] end,
		check = function(ctx)
			openHome(ctx)
			local d = firstDriver(ctx)
			tapDriver(ctx, d)
			local fly, summon
			for _, t in ipairs(ctx:texts()) do
				if t:find("min \194\183 ", 1, true) then
					if not fly then fly = t elseif not summon then summon = t end
				end
			end
			if not (fly and summon) then ctx:na("no Fly versus Summon dial on this screen") end
			local function costOf(t)
				local tail = t:match("\194\183 (.*)$") or ""
				if tail:find("free", 1, true) then return 0 end
				return copperOf(tail)
			end
			local flyCost, fare = costOf(fly), d.price
			if not flyCost then ctx:na("the flight price is not a number: " .. fly) end
			local diff = fare - flyCost
			for _, t in ipairs(ctx:texts()) do
				local amount, kind
				local a = t:match("^Flying is (.-) cheaper")
				if a then amount, kind = copperOf(a), "Flying is cheaper by" end
				local b = t:match("Saves (.-) vs flying")
				if b then amount, kind = copperOf(b), "Saves" end
				local c = t:match("Net (.-) vs flying")
				if c then amount, kind = copperOf(c), "Net" end
				if amount then
					local want = (kind == "Saves") and -diff or diff
					if math.abs(amount - want) > 1 then
						ctx:fail(("The dial says \"%s\" but flying costs %s and the summon %s, a difference of %s."):format(t:gsub("|T.-|t", ""), gold(flyCost), gold(fare), gold(math.abs(want))), joined(ctx))
					end
				end
			end
		end,
	}

	Hunt.promise{
		id = "booking.zeppelin_named",
		area = "Booking",
		text = "When flying to the driver's place needs a boat or zeppelin, the booking screen says so.",
		source = "CurseForge page: what flying there would cost, boats and zeppelins included; Home legend: Boat or zeppelin",
		kind = "scenario",
		needs = { net = "many" },
		when = function(sit) return riderOnly(sit) and is(sit, "place", "town") end,
		check = function(ctx)
			openHome(ctx)
			local d
			for _, x in ipairs(ctx.facts.drivers) do if x.dest == "Undercity" then d = x end end
			if not (d and ctx.W.drivers[key(d.name)]) then ctx:na("no Undercity driver heard") end
			-- I stand in Orgrimmar: Undercity is across the sea (by zeppelin)
			tapDriver(ctx, d)
			local t = joined(ctx):lower()
			if not (t:find("zeppelin", 1, true) or t:find("boat", 1, true)) then
				ctx:fail("You book a driver in Undercity while standing in Orgrimmar and the booking screen does not mention the zeppelin or a boat.", joined(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "booking.already_there",
		area = "Booking",
		text = "Booking a driver who goes to the place where you already stand says you are already there and does not let you request.",
		source = "Confirm: You're already in X (the request button says so); Net.Rides refuses it",
		kind = "scenario",
		when = function(sit) return riderOnly(sit) and LIST_NETS[sit.net or "one"] end,
		check = function(ctx)
			openHome(ctx)
			local d = firstDriver(ctx)
			ctx.w:move(ctx.name, d.dest)
			ctx:advance(2)
			ctx:note("walk to " .. d.dest)
			tapDriver(ctx, d)
			if not has(ctx, "already") then
				ctx:fail(("You stand in %s, tap %s who goes to %s, and the booking screen does not say you are already there."):format(d.dest, d.name, d.dest), joined(ctx))
			end
			local ok = pcall(ctx.me.clickText, ctx.me, "^Request summon", { pattern = true })
			ctx:advance(1)
			if ctx.W.ride and not ({ done = true, declined = true, cancelled = true, timeout = true, failed = true })[ctx.W.ride.state] then
				ctx:fail(("You stand in %s and a ride to %s was requested anyway."):format(d.dest, d.dest), joined(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "booking.group_leave",
		area = "Booking",
		text = "In a group, booking tells you to leave it so the driver can invite you, and Leave group does that.",
		source = "Confirm: You're in a group. Leave it so the driver can invite you (Leave group button)",
		kind = "scenario",
		needs = { group = "party" },
		when = function(sit) return riderOnly(sit) and LIST_NETS[sit.net or "one"] end,
		check = function(ctx)
			openHome(ctx)
			local d = firstDriver(ctx)
			tapDriver(ctx, d)
			if not has(ctx, "You're in a group") then
				ctx:fail("You are in a party and the booking screen does not tell you to leave it.", joined(ctx))
			end
			local ok = pcall(ctx.me.clickText, ctx.me, "Leave group")
			if not ok then ctx:fail("The booking screen tells you to leave your group and has no Leave group button.", joined(ctx)) end
			ctx:advance(2)
			ctx:note("tap Leave group")
			local inGroup = ctx.me.player.group ~= nil
			if inGroup then ctx:fail("You tap Leave group on the booking screen and you are still in the group.", joined(ctx)) end
			if has(ctx, "You're in a group") then ctx:fail("You leave the group and the booking screen still tells you to leave it.", joined(ctx)) end
		end,
	}

	Hunt.promise{
		id = "booking.confirm_not_yanked",
		area = "Booking",
		text = "A driver's booking screen opened by itself (from the map or a note) stays on screen; the first-open login tip does not pull you back to Home.",
		source = "inferred (the phone opens on a driver's booking: UI.Show confirm; round 26 login tips move a first open to Home)",
		kind = "scenario",
		needs = { phone = "confirm" },
		when = function(sit) return is(sit, "role", "rider") and is(sit, "ride", "none") and is(sit, "combat", "no") and sit.tipsOn ~= "off" and sit.session ~= "first" and is(sit, "coach", "done") end,
		check = function(ctx)
			conditions(ctx)
			if not ctx.facts.phoneOpened then ctx:cannot("the phone did not open") end
			ctx:advance(3)
			if kit(ctx).screen ~= "confirm" then
				ctx:fail(("You open a driver's booking screen from the map and a moment later Wuber has taken you to %s instead."):format(tostring(kit(ctx).screen)), joined(ctx))
			end
		end,
	}

	---------------------------------------------------------------------------------------------------------------
	-- The request, Finding, cancelling, declining, timing out
	---------------------------------------------------------------------------------------------------------------
	Hunt.promise{
		id = "booking.request_reaches_driver",
		area = "Booking",
		text = "Click Request summon and your request is with the driver, and the phone moves on to your ride with the fare and the driver's name.",
		source = "CurseForge page: Hit Request. Wuber accepts the group invite for you",
		kind = "scenario",
		when = function(sit) return riderOnly(sit) and LIST_NETS[sit.net or "one"] and is(sit, "group", "solo") end,
		check = function(ctx)
			openHome(ctx)
			local d = firstDriver(ctx)
			tapDriver(ctx, d)
			requestClick(ctx)
			ctx:advance(6)
			local peer = ctx.w:clientOf(d.name)
			local c = peer and peer.W.Drive and peer.W.Drive.customers and peer.W.Drive.customers[key(ctx.name)]
			if not c then
				ctx:fail(("You click Request summon on %s and six seconds later %s has no request from you."):format(d.name, d.name), joined(ctx))
			end
			local scr = kit(ctx).screen
			if scr == "confirm" or scr == "home" then
				ctx:fail(("You click Request summon and the phone stays on %s instead of showing your ride."):format(scr), joined(ctx))
			end
			if not has(ctx, gold(d.price)) then
				ctx:fail(("You click Request summon on a %s fare and your ride screen does not show that fare."):format(gold(d.price)), joined(ctx))
			end
			if not has(ctx, d.name:match("^(%S+)")) then
				ctx:fail("You click Request summon and your ride screen does not say who your driver is.", joined(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "booking.group_invite_taken",
		area = "Booking",
		text = "After Request, when the driver invites you, Wuber accepts the group invite for you.",
		source = "CurseForge page: Hit Request. Wuber accepts the group invite for you",
		kind = "scenario",
		when = function(sit) return riderOnly(sit) and LIST_NETS[sit.net or "one"] and is(sit, "autoAccept", { default = true, on = true }) and is(sit, "group", "solo") end,
		check = function(ctx)
			openHome(ctx)
			local d = firstDriver(ctx)
			local peer = ctx.w:clientOf(d.name)
			if peer.W.Drive.opts().autoInvite == false then ctx:na("the driver invites by hand") end
			tapDriver(ctx, d)
			requestClick(ctx)
			ctx:advance(8)
			if not ctx.me.player.group then
				ctx:fail(("You click Request, %s invites you, and ten seconds later you are not in their group: the invite was not accepted for you."):format(d.name), joined(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "booking.cancel_request",
		area = "Booking",
		text = "Cancel your ride before the summon and the driver drops you from their queue, you are free to book again, and Home is back.",
		source = "Finding / ride screen: Cancel ride button",
		kind = "scenario",
		when = function(sit) return riderOnly(sit) and LIST_NETS[sit.net or "one"] and is(sit, "group", "solo") end,
		check = function(ctx)
			openHome(ctx)
			local d = firstDriver(ctx)
			local peer = ctx.w:clientOf(d.name)
			peer.W.Drive.opts().autoInvite = false -- the driver invites by hand: the ride waits for the invite
			tapDriver(ctx, d)
			requestClick(ctx)
			ctx:advance(3)
			local ok = pcall(ctx.me.clickText, ctx.me, "^Cancel ", { pattern = true })
			if not ok then ctx:fail("You have requested a ride and no Cancel button shows on your ride screen.", joined(ctx)) end
			ctx:advance(8) -- the cancel waits in the shared outbox behind the login backlog (3-4 s with real saved data)
			ctx:note("tap Cancel")
			local c = peer.W.Drive.customers and peer.W.Drive.customers[key(ctx.name)]
			if c and c.state ~= "gone" and c.state ~= "left" and c.state ~= "done" then
				ctx:fail(("You cancel your ride and %s still has you in their queue (%s)."):format(d.name, tostring(c.state)), joined(ctx))
			end
			if ctx.W.RideActive and ctx.W.RideActive() then
				ctx:fail("You cancel your ride and Wuber still counts it as under way.", joined(ctx))
			end
			-- back on a screen where you can book again
			local scr = kit(ctx).screen
			if scr == "found" or scr == "finding" then ctx:fail("You cancel your ride and the phone still shows it.", joined(ctx)) end
			if scr ~= "home" then
				openHome(ctx)
			end
			if not has(ctx, d.name) then ctx:fail(("You cancel your ride and %s is not on Home to book again."):format(d.name), joined(ctx)) end
			tapDriver(ctx, d)
			requestClick(ctx)
			ctx:advance(3)
			if not ctx.W.RideActive() then
				ctx:fail("You cancel a ride and then cannot book again: the second Request does nothing.", joined(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "booking.driver_declines",
		area = "Booking",
		text = "If the driver says no, you get a Sorry screen with the reason and Try another driver, and that button takes you back to the list.",
		source = "Sorry screen (Done.lua): Try another driver",
		kind = "scenario",
		when = function(sit) return riderOnly(sit) and LIST_NETS[sit.net or "one"] and is(sit, "group", "solo") end,
		check = function(ctx)
			openHome(ctx)
			local d = firstDriver(ctx)
			local peer = ctx.w:clientOf(d.name)
			peer.W.Drive.opts().autoInvite = false
			tapDriver(ctx, d)
			requestClick(ctx)
			ctx:advance(3)
			peer.W.Drive.Do("DROP", ctx.name)
			ctx:advance(3)
			ctx:note(d.name .. " turns the rider down")
			if kit(ctx).screen ~= "sorry" then
				ctx:fail(("%s turns your request down and the phone shows %s instead of a Sorry screen."):format(d.name, tostring(kit(ctx).screen)), joined(ctx))
			end
			if not has(ctx, "Try another driver") then ctx:fail("The Sorry screen has no Try another driver button.", joined(ctx)) end
			ctx.me:clickText("Try another driver")
			ctx:advance(1.5)
			ctx:note("tap Try another driver")
			if kit(ctx).screen ~= "home" then
				ctx:fail("You tap Try another driver and you are not back on the driver list.", joined(ctx))
			end
			if ctx.W.RideActive and ctx.W.RideActive() then ctx:fail("You tap Try another driver and Wuber still counts the declined ride as under way.", joined(ctx)) end
		end,
	}

	Hunt.promise{
		id = "booking.sorry_next_best",
		area = "Booking",
		text = "After a no, if another driver goes to the same place the Sorry screen offers them as the next best, and tapping the offer starts booking them.",
		source = "Sorry screen (Done.lua): NEXT BEST TO THE SAME PLACE; tooltip: The cheapest other driver going to the same place",
		kind = "scenario",
		when = function(sit) return riderOnly(sit) and LIST_NETS[sit.net or "one"] and is(sit, "group", "solo") end,
		check = function(ctx)
			openHome(ctx)
			local d = firstDriver(ctx)
			local d2, name2 = driverOpens(ctx, d.dest, 8000)
			ctx:advance(10)
			if not ctx.W.drivers[key(name2)] then ctx:cannot("the second driver was not heard") end
			local peer = ctx.w:clientOf(d.name)
			peer.W.Drive.opts().autoInvite = false
			-- a fresh look at the list
			tapDriver(ctx, d)
			requestClick(ctx)
			ctx:advance(3)
			peer.W.Drive.Do("DROP", ctx.name)
			ctx:advance(3)
			if kit(ctx).screen ~= "sorry" then ctx:cannot("no Sorry screen (" .. tostring(kit(ctx).screen) .. ")") end
			local t = joined(ctx)
			if not (has(ctx, name2:match("^(%S+)")) and t:lower():find("next best", 1, true)) then
				ctx:fail(("%s says no and %s goes to the same place (%s) but the Sorry screen offers no next best driver."):format(d.name, name2, d.dest), t)
			end
			ctx.me:clickText(name2, { pattern = true })
			ctx:advance(1.2)
			if kit(ctx).screen ~= "confirm" then
				ctx:fail("You tap the next best driver on the Sorry screen and the booking screen does not open.", joined(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "booking.unanswered_times_out",
		area = "Booking",
		text = "While you wait for a driver who does not answer, you see who you wait for and the seconds left; when they run out you get a Sorry screen and can try another driver.",
		source = "Finding screen (Confirm.lua): who you are waiting for, a countdown and Cancel request; Sorry: No answer from X",
		kind = "scenario",
		when = function(sit) return riderOnly(sit) and LIST_NETS[sit.net or "one"] and is(sit, "group", "solo") end,
		check = function(ctx)
			openHome(ctx)
			local d = firstDriver(ctx)
			tapDriver(ctx, d)
			-- the click is made in combat (no chat whisper goes) and the request message is lost on the way
			ctx.w.drop = ctx.w.drop or {}
			ctx.w.drop.R = (ctx.w.drop.R or 0) + 2
			ctx.w:enterCombat(ctx.me)
			requestClick(ctx)
			ctx:advance(2)
			ctx.w:leaveCombat(ctx.me)
			if kit(ctx).screen ~= "finding" then ctx:cannot("the unanswered request does not wait on the Finding screen (" .. tostring(kit(ctx).screen) .. ")") end
			local short = d.name:match("^(%S+)")
			if not has(ctx, short) then ctx:fail("You wait for a driver and the Finding screen does not say who you are waiting for.", joined(ctx)) end
			local function secs() for _, t in ipairs(ctx:texts()) do local n = t:match("^(%d+) s$") if n then return tonumber(n) end end end
			local a = secs()
			if not a then ctx:fail("You wait for a driver and the Finding screen shows no seconds left.", joined(ctx)) end
			ctx:advance(10)
			local b = secs()
			if not b or b >= a then ctx:fail(("The Finding screen's countdown does not count down (%s s, ten seconds later %s)."):format(tostring(a), tostring(b)), joined(ctx)) end
			ctx:advance(60)
			if kit(ctx).screen ~= "sorry" then
				ctx:fail(("You wait over a minute for a driver who never answers and the phone still shows %s instead of Sorry."):format(tostring(kit(ctx).screen)), joined(ctx))
			end
			ctx.me:clickText("Try another driver")
			ctx:advance(1.5)
			if kit(ctx).screen ~= "home" then ctx:fail("After the time-out you tap Try another driver and you are not back on the list.", joined(ctx)) end
		end,
	}

	Hunt.promise{
		id = "booking.bounty_ends_on_booking",
		area = "Booking",
		text = "Your bounty ends when you book a ride: the chip goes and Wuber no longer shows the bounty as yours.",
		source = "bounty chip tooltip: It ends when you book a ride, a driver starts serving it, you take it down...; Net.Bounty header",
		kind = "scenario",
		when = function(sit) return riderOnly(sit) and LIST_NETS[sit.net or "one"] and is(sit, "group", "solo") end,
		check = function(ctx)
			local s = openHome(ctx)
			local d = firstDriver(ctx)
			ctx:advance(8)
			ctx.me:type(s.search.edit, "Ironforge")
			ctx:advance(1.2)
			local pin
			for _, t in ipairs(ctx:texts()) do if t:match("^Pin %d") then pin = t end end
			if not pin then ctx:na("no bounty offer for Ironforge here") end
			ctx.me:clickText(pin)
			ctx:advance(1)
			ctx.me:type(s.search.edit, "")
			ctx:advance(1.2)
			if not has(ctx, "Bounty: Ironforge") then ctx:na("the bounty did not pin") end
			tapDriver(ctx, d)
			requestClick(ctx)
			ctx:advance(4)
			if ctx.W.db.bounty then
				ctx:fail("You pin a bounty, then book a ride, and Wuber still holds your bounty.", joined(ctx))
			end
		end,
	}

	---------------------------------------------------------------------------------------------------------------
	-- The end of a ride
	---------------------------------------------------------------------------------------------------------------
	Hunt.promise{
		id = "booking.paid_screen",
		area = "Booking",
		text = "After a paid ride Wuber shows where you went, what you paid and to whom, and lets you rate the ride.",
		source = "CHANGELOG 2.3.2 / Done screen (destination, amount paid and who you paid, five stars)",
		kind = "scenario",
		needs = { ride = "ended" },
		when = function(sit) return is(sit, "role", "rider") and is(sit, "combat", "no") and sit.net ~= "none" end,
		check = function(ctx)
			if ctx.me.player.combat then ctx:na("in combat") end
			openPhone(ctx)
			if kit(ctx).screen ~= "done" then ctx:na("the phone is not on the paid screen (" .. tostring(kit(ctx).screen) .. ")") end
			local f = ctx.facts
			local t = joined(ctx)
			local short = tostring(f.driverName or ""):match("^(%S+)") or "?"
			if not has(ctx, "Paid " .. gold(f.price or 0)) then
				ctx:fail(("You paid %s for a ride and the final screen does not say what you paid."):format(gold(f.price or 0)), t)
			end
			if not has(ctx, "Paid " .. gold(f.price or 0) .. " to " .. short) then
				ctx:fail(("You paid %s to %s and the final screen does not say who you paid."):format(gold(f.price or 0), short), t)
			end
			if not has(ctx, "Ratchet") then ctx:fail("The final screen of a ride to Ratchet does not say where you went.", t) end
			if not has(ctx, "star") and not has(ctx, "Tap a star") then ctx:fail("The final screen offers no way to rate the ride.", t) end
		end,
	}

	Hunt.promise{
		id = "booking.rate_stars",
		area = "Booking",
		text = "Tap four stars after a paid ride and Wuber says you gave four stars, and your Trips list keeps them.",
		source = "star tooltip: Rate your ride. Only you see your ratings, in Trips",
		kind = "scenario",
		needs = { ride = "ended" },
		when = function(sit) return is(sit, "role", "rider") and is(sit, "combat", "no") and sit.net ~= "none" end,
		check = function(ctx)
			if ctx.me.player.combat then ctx:na("in combat") end
			openPhone(ctx)
			local s = screens(ctx).done
			if kit(ctx).screen ~= "done" or not (s and s.stars) then ctx:na("the phone is not on the paid screen") end
			if not (s.stars[4] and ctx:visible(s.stars[4])) then ctx:fail("The paid screen shows no stars to tap.", joined(ctx)) end
			ctx.me:clickOn(s.stars[4])
			ctx:advance(1)
			ctx:note("tap the fourth star")
			if not has(ctx, "4 stars") then ctx:fail("You tap the fourth star and Wuber does not say you gave four stars.", joined(ctx)) end
			local rides = ctx.W.db.rides or {}
			local last = rides[#rides]
			if not (last and last.stars == 4) then
				ctx:fail("You rate a ride four stars and your Trips list does not keep the rating.", joined(ctx))
			end
			ctx:reload()
			ctx:advance(3)
			rides = ctx.W.db.rides or {}
			last = rides[#rides]
			if not (last and last.stars == 4) then ctx:fail("You rate a ride four stars, /reload, and the rating is gone from Trips.", "") end
		end,
	}

	Hunt.promise{
		id = "booking.rating_stays_private",
		area = "Booking",
		text = "Your star rating: the star tooltip says your driver is told the stars, and they are (their chat says the rider rated the ride, N stars); you see your ratings in Trips. (job 146: was 'nobody else is told'; Done.lua:186, CHANGELOG-2.3.4 line 64.)",
		source = "star tooltip: Rate your ride. Only you see your ratings, in Trips",
		kind = "scenario",
		needs = { ride = "ended" },
		when = function(sit) return is(sit, "role", "rider") and is(sit, "combat", "no") and sit.net ~= "none" end,
		check = function(ctx)
			if ctx.me.player.combat then ctx:na("in combat") end
			openPhone(ctx)
			local s = screens(ctx).done
			if kit(ctx).screen ~= "done" or not (s and s.stars and s.stars[2] and ctx:visible(s.stars[2])) then ctx:na("the phone is not on the paid screen") end
			local d = ctx.peers.driver
			if not d then ctx:cannot("no driver window") end
			local before = #d.chatLines
			ctx.me:clickOn(s.stars[2])
			ctx:advance(4)
			ctx:note("tap the second star")
			local told = false
			for i = before + 1, #d.chatLines do
				local line = d.chatLines[i]
				local text = type(line) == "table" and (line.text or line.msg or line[1]) or line
				if tostring(text):find("rated", 1, true) and (tostring(text):find("star", 1, true) or tostring(text):find("out of 5", 1, true)) then told = true end
			end
			-- (job 146: the tooltip is 'Your driver is told the stars', so the driver's window must say so)
			if not told then
				ctx:fail("You give your driver two stars, the star tooltip says your driver is told the stars, and their chat never says you rated the ride.", joined(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "booking.ride_shown_when_opened",
		area = "Booking",
		text = "While a ride is under way, opening Wuber shows that ride (not the list), with the driver and, until the summon, a way to cancel.",
		source = "Finding / ride screens (Confirm.lua, Window.lua)",
		kind = "scenario",
		needs = { role = "rider" },
		when = function(sit) return (sit.ride == "requested" or (sit.ride == "invited" and sit.autoAccept == "off")) and is(sit, "combat", "no") and sit.net ~= "none" end,
		check = function(ctx)
			if ctx.me.player.combat then ctx:na("in combat") end
			openPhone(ctx)
			local scr = kit(ctx).screen
			if scr ~= "found" and scr ~= "finding" then
				ctx:fail(("You have a ride under way, open Wuber and it shows %s instead of your ride."):format(tostring(scr)), joined(ctx))
			end
			local short = tostring(ctx.facts.driverName or ""):match("^(%S+)")
			if short and not has(ctx, short) then ctx:fail("Your ride screen does not say who your driver is.", joined(ctx)) end
			local cancel = false
			for _, t in ipairs(ctx:texts()) do if t:find("^Cancel") then cancel = true end end
			if not cancel then ctx:fail("You have a ride that has not been summoned yet and the screen offers no way to cancel it.", joined(ctx)) end
		end,
	}

	Hunt.promise{
		id = "booking.raincheck_offered_on_rebooking",
		area = "Booking",
		text = "When you hold a rain check from a driver, booking that driver offers to use it and says what it covers.",
		source = "CHANGELOG 2.3.0 rain checks; Confirm: Use raincheck (covers 50s)",
		kind = "scenario",
		needs = { ride = "raincheck", role = "rider" },
		when = function(sit) return is(sit, "combat", "no") and is(sit, "net", { one = true, many = true, late = true }) end,
		check = function(ctx)
			openHome(ctx)
			local d = firstDriver(ctx)
			-- the driver's offer card may be waiting for an answer: the player takes the rain check
			if has(ctx, "No thanks") and has(ctx, "offers a raincheck") then
				ctx.me:clickText("Accept")
				ctx:advance(1.5)
				ctx:note("accept the raincheck offer")
			end
			tapDriver(ctx, d)
			local t = joined(ctx)
			if not has(ctx, "aincheck") then ctx:fail(("You hold a rain check from %s and the booking screen does not mention it."):format(d.name), t) end
			if not has(ctx, "covers") then ctx:fail("The booking screen offers a rain check but does not say what it covers.", t) end
		end,
	}
end
