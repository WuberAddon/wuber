-- Promises about the rider's Home screen and the driver list (owner HOME). Written from what the player was told:
-- the CurseForge page and the 2.3.2 changelog ("you'll see who's selling summons right now, where to, and for how much",
-- "every Wuber rider sees every open Wuber driver", bounties, "Home as a driver", "No bounty offer for the place you're
-- standing in"), the Help page ("If you see nobody": Ping drivers, the bell, favourites), tooltips (T.Tip) and toasts
-- (hide a driver, favourite, bell, ping), and the Home chips.
-- The checks reach things the way a player does: /wuber, the Ride tab, real clicks on cards, the heart, the bell, the
-- chips, the search box, other players' windows. The login tip card is tapped away first (a stand-in: tips are tested
-- in tips.lua; the empty state gives way to it by design).
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

	local function homeScr(ctx)
		local WM = ctx:mod("UI.Window")
		return WM and type(WM.screens) == "table" and WM.screens.home or nil
	end

	-- 5000 -> "50s", 15000 -> "1g 50s": how the player reads a fare (not the addon's own formatter)
	local function gold(c)
		local g, s, k = math.floor(c / 10000), math.floor((c % 10000) / 100), c % 100
		local t = {}
		if g > 0 then t[#t + 1] = g .. "g" end
		if s > 0 then t[#t + 1] = s .. "s" end
		if k > 0 then t[#t + 1] = k .. "c" end
		if #t == 0 then return "0c" end
		return table.concat(t, " ")
	end

	local function joined(ctx) return table.concat(ctx:texts(), " | ") end
	local function hasPat(ctx, pat) -- a visible text matching this Lua pattern
		for _, t in ipairs(ctx:texts()) do
			if t:find(pat) then return t end
		end
		return nil
	end
	local function has(ctx, text) -- a visible text containing this (plain)
		for _, t in ipairs(ctx:texts()) do
			if t:find(text, 1, true) then return t end
		end
		return nil
	end

	-- every driver card the list holds, top to bottom
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
		for key, c in pairs(kit(ctx).cards or {}) do
			if c.key and c.view and ctx:visible(c) then out[#out + 1] = { key = key, card = c, y = c.targetY or c.curY or 0 } end
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

	-- the player opens Wuber and looks at Home (the Ride tab)
	local function openHome(ctx)
		conditions(ctx)
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
		if ui.screen ~= "home" then ctx:na("Home is not reachable from this screen (" .. tostring(ui.screen) .. ")") end
		dismissTip(ctx)
		ctx:advance(1.5)
		-- 2.4: the What's new card (Got it) and the Skip the bird card can sit over Home on the first tap: the player closes them
		for _ = 1, 3 do
			-- (job 2680) 2.4.1: the pop-up is [See what's new] and [Not now]; [Got it] only after See what's new
			local b = ctx.me:button("Got it")
			local nn = ctx.me:button("Not now")
			if not (b and ctx:visible(b)) and nn and ctx:visible(nn) then b = nn end
			if b and ctx:visible(b) then
				ctx.me:clickOn(b)
				ctx:advance(0.6)
				ctx:note("close the What's new card (Got it / Not now)")
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
		-- a tip card can arrive late, after those were closed
		dismissTip(ctx)
		return homeScr(ctx)
	end

	local function riderish(sit) return is(sit, "ride", "none") and is(sit, "combat", "no") end

	local function search(ctx, text)
		local s = homeScr(ctx)
		ctx.me:type(s.search.edit, text)
		ctx:advance(1.2)
		ctx:note("type " .. text .. " in Where to?")
	end

	-- other drivers: the net dial's list of { name, dest, price }
	local function netDrivers(ctx)
		local out = {}
		for _, d in ipairs(ctx.facts.drivers or {}) do
			if not d.copy then out[#out + 1] = d end
		end
		return out
	end
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end

	local NEW_NAMES = { "Eli Marsh", "Fay Doyle", "Gus Hale", "Hal Nash", "Ivy Cole" }
	-- a new Wuber driver opens for business at a place (another window; its beacon reaches me by addon message)
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

	-- a toast lives a few seconds: look every half second
	local function waitFor(ctx, text, secs)
		for _ = 1, math.floor((secs or 12) * 2) do
			ctx:advance(0.5)
			if has(ctx, text) then return true end
		end
		return false
	end

	local WHEN_LIST = function(sit) return riderish(sit) and is(sit, "net", { one = true, many = true, late = true }) end

	---------------------------------------------------------------------------------------------------------------
	-- The list
	---------------------------------------------------------------------------------------------------------------
	Hunt.promise{
		id = "home.lists_every_driver",
		area = "Home",
		text = "Open Wuber and Home lists every open driver you can hear, with where they go and what they charge.",
		source = "CurseForge page: Open Wuber and you'll see who's selling summons right now, where to, and for how much",
		kind = "scenario",
		when = WHEN_LIST,
		check = function(ctx)
			openHome(ctx)
			for _, d in ipairs(netDrivers(ctx)) do
				if ctx.W.drivers and ctx.W.drivers[key(d.name)] then
					local short = d.name:match("^(%S+)")
					local list = joined(ctx)
					if not has(ctx, d.name) then
						ctx:fail(("You open Wuber with %s open at %s for %s and Home does not list them."):format(d.name, d.dest, gold(d.price)), list)
					end
					if not has(ctx, "To " .. d.dest) then
						ctx:fail(("Home lists %s but does not say they go to %s."):format(d.name, d.dest), list)
					end
					local fare = math.max(d.price, tonumber(ctx.W.MIN_PRICE) or 5000) -- (no beacon goes under the minimum fare)
					if not has(ctx, gold(fare)) then
						ctx:fail(("Home lists %s with a fare other than the %s they set."):format(d.name, gold(fare)), list)
					end
				end
			end
		end,
	}

	Hunt.promise{
		id = "home.cheapest_first",
		area = "Home",
		text = "On Home the open drivers are listed cheapest first.",
		source = "tooltip on the map: \"its drivers, cheapest first\"; Kit comment; inferred",
		kind = "scenario",
		needs = { net = "many" },
		when = function(sit) return riderish(sit) end,
		check = function(ctx)
			openHome(ctx)
			local list, prev, prevName = cards(ctx), nil, nil
			if #list < 2 then ctx:na("fewer than two cards") end
			for _, c in ipairs(list) do
				local v = c.card.view
				if v.state == "open" then
					if prev and v.price < prev then
						ctx:fail(("Home lists %s at %s above %s at %s: the dearer driver comes before the cheaper one."):format(
							prevName, gold(prev), v.name, gold(v.price)), joined(ctx))
					end
					prev, prevName = v.price, v.name
				end
			end
		end,
	}

	Hunt.promise{
		id = "home.open_before_paused",
		area = "Home",
		text = "A driver who has paused is listed below the drivers who are open, and is not a way to book.",
		source = "Kit: open first, then busy, then paused; Cards: a paused card does not open booking",
		kind = "scenario",
		needs = { net = "many" },
		when = function(sit) return riderish(sit) end,
		check = function(ctx)
			local d = ctx.peers.drivers and ctx.peers.drivers[1]
			if not (d and d.W.Driver and type(d.W.Driver.SetPaused) == "function") then ctx:cannot("no Driver.SetPaused on the driver window") end
			-- the cheapest driver pauses: by price he would be first, by state he must now be last
			d.W.Driver.SetPaused(true)
			ctx:note(d.player.name .. " pauses")
			ctx:advance(12)
			openHome(ctx)
			local list = cards(ctx)
			local seenPaused = false
			for _, c in ipairs(list) do
				local st = c.card.view.state
				if st == "paused" then seenPaused = true
				elseif seenPaused and st == "open" then
					ctx:fail("A paused driver is listed above an open driver on Home.", joined(ctx))
				end
			end
			if not seenPaused then ctx:na("the paused driver is not on the list in this situation") end
		end,
	}

	Hunt.promise{
		id = "home.driver_appears_live",
		area = "Home",
		text = "A driver who opens while you look at Home appears in the list within a few seconds, and goes when they close.",
		source = "Home empty state: Drivers show up here the moment they go online; Help: If you see nobody",
		kind = "scenario",
		when = function(sit) return riderish(sit) and is(sit, "net", { none = true, one = true, many = true }) and is(sit, "role", "rider") end,
		check = function(ctx)
			openHome(ctx)
			local d, name = driverOpens(ctx, "Gadgetzan", 12000)
			ctx:advance(8)
			if not has(ctx, name) then
				ctx:fail(("You are looking at Home and %s opens for business at Gadgetzan; ten seconds later they are not in the list."):format(name), joined(ctx))
			end
			d.W.Driver.SetOnline(false)
			ctx:note(name .. " closes")
			ctx:advance(12)
			if has(ctx, name) then
				ctx:fail(("%s closes for business and is still in your Home list twelve seconds later."):format(name), joined(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "home.sees_every_driver",
		area = "Home",
		text = "Every open Wuber driver on your realm is in your list, wherever the game put them (another layer or copy of the world).",
		source = "CHANGELOG 2.3.2: every Wuber rider sees every open Wuber driver, wherever the game puts them; Help: Wuber's own channel reaches every layer",
		kind = "scenario",
		needs = { net = "layers" },
		when = function(sit) return riderish(sit) and is(sit, "role", "rider") end,
		check = function(ctx)
			openHome(ctx)
			ctx:advance(20)
			for _, d in ipairs(ctx.facts.drivers or {}) do
				if not has(ctx, d.name) then
					ctx:fail(("%s is open for business at %s on another copy of the world and is not in your list a minute after you log in."):format(d.name, d.dest), joined(ctx))
				end
			end
		end,
	}

	Hunt.promise{
		id = "home.empty_says_so",
		area = "Home",
		text = "With nobody online, Home says no drivers are online and offers Ping drivers, instead of showing an empty list.",
		source = "Help: If you see nobody: tap Ping drivers",
		kind = "scenario",
		needs = { net = "none" },
		when = function(sit) return riderish(sit) and is(sit, "role", "rider") end,
		check = function(ctx)
			openHome(ctx)
			ctx:advance(10)
			if not has(ctx, "No drivers online") then
				ctx:fail("Nobody is online and Home does not say so.", joined(ctx))
			end
			if not (has(ctx, "Ping") ) then
				ctx:fail("Nobody is online and Home offers no Ping drivers button.", joined(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "home.empty_not_alarming",
		area = "Home",
		text = "Wuber only says it cannot reach its network when it truly cannot: opening it just after logging in, while it is still joining, does not say so.",
		source = "inferred (Home empty state: Can't reach the Wuber network. You may be in ten chat channels already)",
		kind = "scenario",
		needs = { net = "none", phone = "closed", session = "login" },
		when = function(sit) return riderish(sit) and is(sit, "role", "rider") end,
		check = function(ctx)
			-- the player opens Wuber the moment they are in (the network channel is joined a few seconds after login)
			conditions(ctx)
			ctx.me:slash("/wuber")
			ctx:note("/wuber, a moment after logging in")
			ctx:advance(1.6)
			dismissTip(ctx)
			ctx:advance(0.5)
			local bad = has(ctx, "Can't reach the Wuber network")
			if bad then
				ctx:advance(15)
				if not has(ctx, "Can't reach the Wuber network") then
					ctx:fail("You log in, open Wuber at once with nobody listed, and it says it can't reach the Wuber network; a few seconds later it has joined and the line is gone.", bad)
				end
			end
		end,
	}

	---------------------------------------------------------------------------------------------------------------
	-- Search and chips
	---------------------------------------------------------------------------------------------------------------
	Hunt.promise{
		id = "home.search_filters",
		area = "Home",
		text = "Typing a place in Where to? lists only the drivers going there.",
		source = "Home search box (Where to?); Help",
		kind = "scenario",
		needs = { net = "many" },
		when = function(sit) return riderish(sit) end,
		check = function(ctx)
			openHome(ctx)
			local want = ctx.facts.drivers[2]
			if not (want and ctx.W.drivers[key(want.name)]) then ctx:na("that driver was not heard") end
			search(ctx, want.dest)
			if not has(ctx, want.name) then
				ctx:fail(("You type %s in Where to? and %s, who goes there, is not listed."):format(want.dest, want.name), joined(ctx))
			end
			for _, d in ipairs(ctx.facts.drivers) do
				if d.dest ~= want.dest and has(ctx, d.name) then
					ctx:fail(("You type %s in Where to? and %s, who goes to %s, is still listed."):format(want.dest, d.name, d.dest), joined(ctx))
				end
			end
			search(ctx, "")
			for _, d in ipairs(ctx.facts.drivers) do
				if ctx.W.drivers[key(d.name)] and not has(ctx, d.name) then
					ctx:fail(("You clear Where to? and %s does not come back to the list."):format(d.name), joined(ctx))
				end
			end
		end,
	}

	Hunt.promise{
		id = "home.search_by_driver_name",
		area = "Home",
		text = "Typing a driver's name in Where to? finds that driver, and Wuber does not tell you there is no such place.",
		source = "Home search box: filters by destination, service or driver name (Cards.lua header)",
		kind = "scenario",
		needs = { net = "many" },
		when = function(sit) return riderish(sit) end,
		check = function(ctx)
			openHome(ctx)
			local want = ctx.facts.drivers[2]
			if not (want and ctx.W.drivers[key(want.name)]) then ctx:na("that driver was not heard") end
			search(ctx, want.name)
			if not has(ctx, want.name) then
				ctx:fail(("You type %s's name in Where to? and they are not listed."):format(want.name), joined(ctx))
			end
			local t = has(ctx, "No place called")
			if t then
				ctx:fail(("You type %s's name in Where to? and press Enter: the driver is listed but Wuber says \"%s\"."):format(want.name, t), joined(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "home.search_nobody_says_so",
		area = "Home",
		text = "Searching for a town nobody summons to says that nobody does, instead of an empty list.",
		source = "Home: Nobody summons to X right now (CHANGELOG 2.3.0 bounties)",
		kind = "scenario",
		when = function(sit) return riderish(sit) and is(sit, "net", { none = true, one = true, many = true }) end,
		check = function(ctx)
			openHome(ctx)
			search(ctx, "Ironforge")
			local t = joined(ctx)
			if not (t:find("Nobody summons to", 1, true) or t:find("No drivers to", 1, true) or t:find("Drivers to Ironforge", 1, true)) then
				ctx:fail("You search for Ironforge, where no driver goes, and Home says nothing about it.", t)
			end
			for _, d in ipairs(ctx.facts.drivers or {}) do
				if has(ctx, d.name) then
					ctx:fail(("You search for Ironforge and %s, who goes to %s, is listed."):format(d.name, d.dest), t)
				end
			end
		end,
	}

	Hunt.promise{
		id = "home.chip_filters",
		area = "Home",
		text = "Tapping a place chip under the search box lists only the drivers going there, and All brings everyone back.",
		source = "Home place chips (tooltip: Only drivers going to X)",
		kind = "scenario",
		needs = { net = "many" },
		when = function(sit) return riderish(sit) end,
		check = function(ctx)
			local s = openHome(ctx)
			-- the first place chip drawn
			local chip, place
			local function scan(f)
				if f.place and ctx:visible(f) and not chip then chip, place = f, f.place end
				for _, k in ipairs({ f:GetChildren() }) do scan(k) end
			end
			scan(s.chips)
			if not chip then ctx:cannot("no place chip found under the search box") end
			ctx.me:clickOn(chip)
			ctx:advance(1.2)
			ctx:note("tap the " .. tostring(place) .. " chip")
			for _, d in ipairs(ctx.facts.drivers) do
				local listed = has(ctx, d.name) ~= nil
				if d.dest == place and not listed and ctx.W.drivers[key(d.name)] then
					ctx:fail(("You tap the %s chip and %s, who goes to %s, is not listed."):format(place, d.name, place), joined(ctx))
				end
				if d.dest ~= place and listed then
					ctx:fail(("You tap the %s chip and %s, who goes to %s, is still listed."):format(place, d.name, d.dest), joined(ctx))
				end
			end
			ctx.me:clickText("All")
			ctx:advance(1.2)
			for _, d in ipairs(ctx.facts.drivers) do
				if ctx.W.drivers[key(d.name)] and not has(ctx, d.name) then
					ctx:fail(("You tap All after a place chip and %s does not come back."):format(d.name), joined(ctx))
				end
			end
		end,
	}

	---------------------------------------------------------------------------------------------------------------
	-- The bell, favourites, hidden drivers
	---------------------------------------------------------------------------------------------------------------
	Hunt.promise{
		id = "home.bell_tells_me",
		area = "Home",
		text = "Search a place nobody goes to and tap Tell me: when a driver then opens there you are told.",
		source = "Home empty state (e.watch: \"Tell me\" / \"We'll tell you when one's online\"); Help: Tap Tell me.",
		kind = "scenario",
		when = function(sit) return riderish(sit) and is(sit, "net", { none = true, one = true, many = true }) and is(sit, "role", "rider") end,
		check = function(ctx)
			local s = openHome(ctx)
			search(ctx, "Ironforge")
			local btn = (s.bell and ctx:visible(s.bell)) and s.bell
				or (s.empty and s.empty.watch and ctx:visible(s.empty.watch) and s.empty.watch) or nil
			if not btn then ctx:fail("You search for a place nobody goes to and there is no Tell me button.", joined(ctx)) end
			ctx.me:clickOn(btn)
			ctx:advance(0.5)
			ctx:note("tap Tell me")
			if not has(ctx, "tell you when") then
				ctx:fail("You tap Tell me for Ironforge and Wuber does not say it will tell you.", joined(ctx))
			end
			local _, name = driverOpens(ctx, "Ironforge", 9000)
			if not waitFor(ctx, "to Ironforge is online", 15) then
				ctx:fail(("You watch Ironforge with Tell me, then %s opens there and fifteen seconds later you have not been told."):format(name), joined(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "home.watch_not_in_combat",
		area = "Home",
		text = "A watched place or a favourite coming online never interrupts you in combat, and you are still told once the fight is over.",
		source = "Net.Favourites header (never in combat, held until it ends); inferred",
		kind = "scenario",
		when = function(sit) return riderish(sit) and is(sit, "net", { none = true, one = true, many = true }) and is(sit, "role", "rider") end,
		check = function(ctx)
			local s = openHome(ctx)
			search(ctx, "Ironforge")
			if s.bell and ctx:visible(s.bell) then
				ctx.me:clickOn(s.bell)
			else
				-- 2.4: nobody listed, so the empty state's own Tell me button is the bell
				local tm = ctx.me:findText("^Tell me$", false, false)
				if #tm == 0 and has(ctx, "Pin a bounty so drivers see you want it") and ctx.W.Advanced() then
					-- Home.lua (empty state): in Advanced mode a place nobody serves shows the bounty card instead of Tell me;
					-- the player types /wuber advanced to go back to Simple mode, where Tell me is on the page
					ctx.me:slash("/wuber advanced")
					ctx:advance(0.5)
					ctx:note("switch to Simple mode (/wuber advanced)")
					search(ctx, "")
					search(ctx, "Ironforge")
					tm = ctx.me:findText("^Tell me$", false, false)
				end
				if #tm == 0 then ctx:cannot("neither the bell nor Tell me is on screen for Ironforge") end
				ctx.me:clickOn(tm[1])
			end
			ctx:advance(0.5)
			ctx:note("watch Ironforge")
			search(ctx, "")
			ctx.w:enterCombat(ctx.me)
			ctx:note("combat starts")
			local _, name = driverOpens(ctx, "Ironforge", 9000)
			if waitFor(ctx, "to Ironforge is online", 12) then
				ctx:fail("A driver to the place you watch opens while you are in combat and Wuber tells you in the middle of the fight.", joined(ctx))
			end
			ctx.w:leaveCombat(ctx.me)
			ctx:note("combat ends")
			if not waitFor(ctx, "to Ironforge is online", 12) then
				ctx:fail(("%s opened at the place you watch while you were in combat and after the fight Wuber never told you."):format(name), joined(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "home.favourite_saved",
		area = "Home",
		text = "Tapping the heart on a driver makes them a favourite (the heart fills and Wuber says so), and they are still a favourite after a /reload.",
		source = "heart tooltip: Add to your favourites; Help: Favourite drivers you like",
		kind = "scenario",
		when = function(sit) return riderish(sit) and is(sit, "net", { one = true, many = true, late = true }) end,
		check = function(ctx)
			openHome(ctx)
			local list = cards(ctx)
			if not list[1] then ctx:na("no card to tap") end
			local c, name, k = list[1].card, list[1].card.view.name, list[1].key
			intoView(ctx, c)
			ctx.me:clickOn(c.heart)
			ctx:advance(0.8)
			ctx:note("tap the heart on " .. name)
			if not has(ctx, "is a favourite") then
				ctx:fail(("You tap the heart on %s and Wuber does not say they are a favourite."):format(name), joined(ctx))
			end
			if ctx.W.IsFav and not ctx.W.IsFav(k) then
				ctx:fail(("You tap the heart on %s and Wuber does not remember them as a favourite."):format(name), joined(ctx))
			end
			ctx:reload()
			ctx:advance(3)
			if ctx.W.IsFav and not ctx.W.IsFav(k) then
				ctx:fail(("You make %s a favourite, /reload, and they are no longer a favourite."):format(name), joined(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "home.favourite_online_note",
		area = "Home",
		text = "When a favourite driver comes back online you are told they are online.",
		source = "heart tooltip: we'll tell you when they come online; toast: We'll tell you when they're online",
		kind = "scenario",
		when = function(sit) return riderish(sit) and is(sit, "net", { one = true, many = true }) and is(sit, "role", "rider") end,
		check = function(ctx)
			openHome(ctx)
			local list = cards(ctx)
			if not list[1] then ctx:na("no card to tap") end
			local name, k = list[1].card.view.name, list[1].key
			intoView(ctx, list[1].card)
			ctx.me:clickOn(list[1].card.heart)
			ctx:advance(0.5)
			ctx:note("tap the heart on " .. name)
			local d = ctx.w:clientOf(name)
			if not d then ctx:cannot("the favourite's window is not there") end
			d.W.Driver.SetOnline(false)
			ctx:note(name .. " closes")
			ctx:advance(15)
			if has(ctx, name) then ctx:na("the favourite is still listed after closing") end
			d.W.Driver.SetOnline(true)
			ctx:note(name .. " opens again")
			if not waitFor(ctx, "is online", 14) then
				ctx:fail(("Your favourite %s closes and opens again and fourteen seconds later Wuber has not told you they are online."):format(name), joined(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "home.hide_driver",
		area = "Home",
		text = "Right-click a driver and Hide this driver: they are gone from your list, you are told how to bring them back, and Show all in Settings brings them back.",
		source = "card menu tooltip: You won't see this driver anywhere in Wuber. Settings can show them again; toast: Show them again in Settings",
		kind = "scenario",
		when = function(sit) return riderish(sit) and is(sit, "net", { one = true, many = true, late = true }) and is(sit, "role", "rider") end,
		check = function(ctx)
			openHome(ctx)
			local list = cards(ctx)
			if not list[1] then ctx:na("no card to right-click") end
			local name, k = list[1].card.view.name, list[1].key
			intoView(ctx, list[1].card)
			ctx.me:clickOn(list[1].card, "RightButton")
			ctx:advance(0.6)
			ctx:note("right-click " .. name)
			if not has(ctx, "Hide this driver") then ctx:fail("You right-click a driver card and no menu with Hide this driver shows.", joined(ctx)) end
			ctx.me:clickText("Hide this driver")
			ctx:advance(1.2)
			ctx:note("Hide this driver")
			if has(ctx, name) and not (has(ctx, "is hidden")) then
				ctx:fail(("You hide %s and they are still on Home."):format(name), joined(ctx))
			end
			local toast = has(ctx, "hidden")
			if not toast then ctx:fail(("You hide %s and Wuber does not tell you how to bring them back."):format(name), joined(ctx)) end
			-- the driver is still open: his next beacon must not bring him back
			ctx:advance(70)
			if cards and kit(ctx).cards and kit(ctx).cards[k] and ctx:visible(kit(ctx).cards[k]) then
				ctx:fail(("You hide %s, and a minute later their card is back on Home."):format(name), joined(ctx))
			end
			local UI = ctx.W.UI
			UI.OpenSettings("riding")
			ctx:advance(1)
			local st = UI.settings
			local btn = st and st.controls and st.controls.hidden
			if not (btn and ctx:visible(btn)) then ctx:cannot("the Show all button is not on screen (Settings > Riding)") end
			ctx.me:clickOn(btn)
			ctx:advance(0.8)
			ctx:note("tap Show all in Settings")
			pcall(UI.CloseSettings, true)
			ctx:advance(15)
			local UIt = ctx.W.UI
			if not ctx.W.drivers[k] then ctx:na("the driver's beacon has not come back yet") end
			openHome(ctx)
			if not has(ctx, name) then
				ctx:fail(("You hide %s, tap Show all in Settings, and they are not on Home again."):format(name), joined(ctx))
			end
		end,
	}

	---------------------------------------------------------------------------------------------------------------
	-- Your usual, bounties, being a driver yourself
	---------------------------------------------------------------------------------------------------------------
	local function wdb(ctx)
		local s = ctx.saved
		if type(s) ~= "table" then s = {} ctx.saved = s end
		if type(s.Wuber) == "table" then return s.Wuber end
		if s.chars ~= nil or s.rides ~= nil or s.fx ~= nil then return s end
		s.Wuber = {}
		return s.Wuber
	end

	Hunt.promise{
		id = "home.usual_card",
		area = "Home",
		text = "When the driver you ride with most is open and going where you usually go, Home shows a Your usual card, and tapping it takes you to booking them.",
		source = "Home: Your usual card (CHANGELOG 2.3.0); Ride again",
		kind = "scenario",
		needs = { saved = "fresh", net = "one", role = "rider" },
		when = function(sit) return riderish(sit) end,
		pre = function(ctx)
			local d = wdb(ctx)
			d.rides = d.rides or {}
			local t = 1700000000 - 5 * 86400
			for i = 1, 3 do
				d.rides[#d.rides + 1] = { dest = "Ratchet", driver = "Ana Smith", driverKey = "ana smith", price = 5000, at = t + i * 3600, stars = 5 }
			end
		end,
		check = function(ctx)
			openHome(ctx)
			if ctx.W.Usual then
				local u = ctx.W.Usual()
				if not (u and u.online) then ctx:na("the saved rides do not make Ana Smith the usual here") end
			end
			local t = joined(ctx)
			if not t:lower():find("your usual", 1, true) then
				ctx:fail("You have ridden with Ana Smith to Ratchet three times, she is open going to Ratchet, and Home has no Your usual card.", t)
			end
			local k = kit(ctx)
			-- 2.4: Home's main button reads "Ride again · <place> · <price>"
			local ra = ctx.me:findText("^Ride again", false, false)
			if #ra == 0 then ctx:fail("Home shows your usual card but no Ride again button to tap.", t) end
			-- the fake game lets a row scrolled out of its list's clip take a click aimed at the button under it; a player would
			-- simply press the Ride again button, so when what is "drawn" at its centre lies outside its own clip, press the button
			local rb = ra[1]
			while rb and rb.GetObjectType and rb:GetObjectType() ~= "Button" do rb = rb:GetParent() end
			local function strayHit()
				local okc, cx, cy = pcall(ra[1].GetCenter, ra[1])
				if not (okc and cx) then return false end
				local ratio = ra[1]:GetEffectiveScale() / ctx.me.env.UIParent:GetEffectiveScale()
				local hit = ctx.me:frameAt(cx * ratio, cy * ratio)
				if not hit or hit == rb then return false end
				local f = hit
				while f do if f == rb then return false end f = f.GetParent and f:GetParent() or nil end
				-- is the hit frame's centre outside its scroll list's clip?
				local hr = ctx.H.rect(hit)
				local c = hit:GetParent()
				while c do
					if c.GetScript and c:GetScript("OnMouseWheel") then
						local cr = ctx.H.rect(c)
						if hr and cr then
							local mid = hr.b + hr.h / 2
							return mid < cr.b or mid > cr.b + cr.h
						end
						return false
					end
					c = c.GetParent and c:GetParent() or nil
				end
				return false
			end
			if rb and strayHit() then ctx.me:click(rb) else ctx.me:clickOn(ra[1]) end
			ctx:advance(1)
			ctx:note("tap Ride again")
			if kit(ctx).screen ~= "confirm" then
				ctx:fail("You tap the Your usual card and you do not land on booking Ana Smith.", joined(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "home.usual_ignores_unpaid",
		area = "Home",
		text = "Rides that ended without being paid do not count: they do not make a driver your usual.",
		source = "CHANGELOG 2.3.2: A ride that timed out without being paid is no longer counted as a paid trip; Stats: a ride ended without paying counts for nothing",
		kind = "scenario",
		needs = { saved = "fresh", net = "one", role = "rider" },
		when = function(sit) return riderish(sit) end,
		pre = function(ctx)
			local d = wdb(ctx)
			d.rides = d.rides or {}
			local t = 1700000000 - 5 * 86400
			for i = 1, 3 do
				d.rides[#d.rides + 1] = { dest = "Ratchet", driver = "Ana Smith", driverKey = "ana smith", price = 5000, at = t + i * 3600, unpaid = true }
			end
		end,
		check = function(ctx)
			openHome(ctx)
			if joined(ctx):lower():find("your usual", 1, true) then
				ctx:fail("You have three rides with Ana Smith to Ratchet and none was ever paid, and Home still offers her as your usual.", joined(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "home.bounty_pin_and_take_down",
		area = "Home",
		text = "Search a town nobody summons to and pin a bounty: a chip shows the place, your pledge and the minutes left; the chip stays after a /reload, and taking it down removes it.",
		source = "CHANGELOG 2.3.0/2.3.2 (Bounties); bounty chip tooltip",
		kind = "scenario",
		when = function(sit) return riderish(sit) and is(sit, "net", { none = true, one = true, many = true }) and is(sit, "role", "rider") end,
		check = function(ctx)
			openHome(ctx)
			ctx:advance(8)
			search(ctx, "Ironforge")
			local pin = nil
			for _, t in ipairs(ctx:texts()) do if t:match("^Pin %d") then pin = t end end
			if not pin then ctx:fail("You search for Ironforge, where nobody goes, and Home offers no way to pin a bounty.", joined(ctx)) end
			ctx.me:clickText(pin)
			ctx:advance(1)
			ctx:note("tap " .. pin)
			search(ctx, "")
			local t = hasPat(ctx, "^Your bounty: .- for Ironforge")
			if not t then ctx:fail("You pin a bounty for Ironforge and Home shows no bounty chip.", joined(ctx)) end
			-- 2.4: the title is "Your bounty: 50s for Ironforge"; the minutes are in the sub-line under it
			local mins
			do
				local texts = ctx:texts()
				for i, x in ipairs(texts) do
					if x == t then
						for j = i, math.min(i + 3, #texts) do
							if texts[j]:find("%d+ min") then mins = texts[j] break end
						end
						break
					end
				end
			end
			if not mins then ctx:fail("The bounty chip does not say how many minutes are left.", t) end
			ctx:reload()
			ctx:advance(4)
			openHome(ctx)
			if not hasPat(ctx, "^Your bounty: .- for Ironforge") then
				ctx:fail("You pin a bounty for Ironforge, /reload, and the bounty chip is gone.", joined(ctx))
			end
			local s = homeScr(ctx)
			local close = s.bountyChip and s.bountyChip.close
			if not (close and ctx:visible(close)) then ctx:cannot("no close button on the bounty chip") end
			ctx.me:clickOn(close)
			ctx:advance(1)
			ctx:note("take the bounty down")
			if hasPat(ctx, "^Your bounty: .- for Ironforge") then ctx:fail("You take your bounty down and the chip is still there.", joined(ctx)) end
		end,
	}

	Hunt.promise{
		id = "home.bounty_not_where_served",
		area = "Home",
		text = "You cannot pin a bounty for a place an open driver already goes to: Home offers the driver instead.",
		source = "CHANGELOG 2.3.0 (a wish for a place nobody summons to); Bounty: served",
		kind = "scenario",
		when = function(sit) return riderish(sit) and is(sit, "net", { one = true, many = true }) and is(sit, "role", "rider") end,
		check = function(ctx)
			openHome(ctx)
			local d = ctx.facts.drivers[1]
			if not (d and ctx.W.drivers[key(d.name)]) then ctx:na("the driver was not heard") end
			search(ctx, d.dest)
			for _, t in ipairs(ctx:texts()) do
				if t:match("^Pin %d") or t == "Want a summon? Pin a bounty" then
					ctx:fail(("%s summons to %s and Home still offers you a bounty for %s."):format(d.name, d.dest, d.dest), joined(ctx))
				end
			end
		end,
	}

	Hunt.promise{
		id = "home.own_driver_not_a_card",
		area = "Home",
		text = "When you are open as a driver, Home says so with what riders see of you, and never lists you as a driver you can book.",
		source = "CHANGELOG 2.3.2: Home as a driver (You can't book yourself)",
		kind = "scenario",
		when = function(sit) return is(sit, "role", { warlock = true, crew = true, friend = true }) and riderish(sit) end,
		check = function(ctx)
			openHome(ctx)
			local W = ctx.W
			local me = W.Key and W.Key(ctx.name) or key(ctx.name)
			for k, c in pairs(kit(ctx).cards or {}) do
				if c.key and ctx:visible(c) and key(k) == key(me) then
					ctx:fail("You are open as a driver and Home lists you as a driver card you can book.", joined(ctx))
				end
			end
			-- riders see me when my own beacon is on the network (a crew member's captain is the listed driver)
			local ok, beacon = pcall(W.DriverBeacon)
			local open = ok and type(beacon) == "table" and not beacon.only
			if open and not has(ctx, "as a driver") then
				ctx:fail("You are open as a driver and Home does not say so.", joined(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "home.openmap_hint_gone_for_good",
		area = "Home",
		text = "Close the Get OpenMap hint and Wuber does not show it again, not even after a /reload.",
		source = "hint tooltip: Hide this tip. Wuber won't show it again",
		kind = "scenario",
		when = function(sit) return riderish(sit) end,
		check = function(ctx)
			local s = openHome(ctx)
			local h = s.mapHint
			if not (h and ctx:visible(h)) then ctx:na("the hint is not showing (OpenMap is there, or it was closed before)") end
			if not (h.close and ctx:visible(h.close)) then ctx:cannot("no close button on the hint") end
			-- the hint is the last row of the list: a player scrolls it into view, then taps its x
			if not ctx.me:onScreen(h.close) then ctx.me:scrollIntoView(h.close) ctx:advance(0.5) end
			if not ctx.me:onScreen(h.close) then ctx:cannot("the hint's x cannot be scrolled into view") end
			ctx.me:clickOn(h.close)
			ctx:advance(1)
			ctx:note("close the OpenMap hint")
			if has(ctx, "Get OpenMap") then ctx:fail("You close the Get OpenMap hint and it is still there.", joined(ctx)) end
			ctx:reload()
			ctx:advance(1)
			openHome(ctx)
			if has(ctx, "Get OpenMap") then
				ctx:fail("You close the Get OpenMap hint, /reload, and it is back although Wuber said it would not show it again.", joined(ctx))
			end
		end,
	}
end
