-- Promises about the NETWORK (owner NET): who the rider hears and sees, how fast the list changes, older and newer Wuber
-- versions, the "A newer Wuber is out" notice, the public API for other driver addons, the message budget.
-- Written from what the player was told (Help: finding drivers, the Ride tab's list, Settings > This window > Tell me
-- about updates, the CurseForge page, BRIEF11 / BRIEF15 / BRIEF25, the file headers of Wuber/Net) and never from the
-- code's own early returns. Where a promise needs a second player, it is another game window (ctx.w:addClient) and
-- it acts the way a player does: /wuber drive on, /wuber drive price 75s, /wuber drive off, a log off.
return function(Hunt)
	local function is(sit, dial, want)
		local v = sit[dial]
		if v == nil then return true end -- the dial is not loaded: its default world
		if type(want) == "table" then return want[v] == true end
		return v == want
	end

	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end

	-- where the phone shows the Ride tab's list at the start (or can be opened the way a player opens it)
	local LISTY = { closed = true, home = true, splash = true }
	-- the Ride tab shows the list of drivers only while no ride is on (with a ride it shows the ride)
	local FREE = { "Zed Hale", "Uma Shaw", "Val Pike", "Wes Dane", "Xan Moss", "Yul Penn", "Abe Cross", "Bri Nash" }

	local function freeName(ctx)
		for _, n in ipairs(FREE) do
			if key(n) ~= key(ctx.name) and not ctx.w:player(n) then return n end
		end
		ctx:cannot("no free name for another player")
	end

	-- another player's window: a Warlock at a place, with the first-run welcome already done
	local function newDriver(ctx, opts)
		opts = opts or {}
		local name = opts.name or freeName(ctx)
		if ctx.w:player(name) then ctx:cannot("the name " .. name .. " is taken") end
		local d = ctx.w:addClient(name, { spot = opts.spot or "Ratchet", class = "WARLOCK", faction = opts.faction,
			realm = opts.realm, version = opts.version, shards = 10, money = 100000 })
		local Ch = d.W.Char and d.W.Char()
		if Ch then Ch.welcomed = true Ch.wizard = true end
		return d, name
	end

	local function goOnline(ctx, d, name)
		if d.W.Driver.SetOnline(true) == false then ctx:cannot(name .. " could not go online") end
		ctx:note(name .. " goes online (/wuber drive on)")
	end

	local function riderOnly(ctx)
		if ctx.sit.role ~= nil and ctx.sit.role ~= "rider" then ctx:na("not a rider") end
	end

	-- the phone on its Ride tab, the way a player gets there: open it and click Ride
	local function showRideTab(ctx)
		local UI = ctx.W.UI
		if not (UI.IsShown and UI.IsShown()) then UI.Toggle(true) ctx:advance(3) end
		local K = ctx:mod("UI.Kit")
		local tab = K and K.ui and K.ui.tab
		if tab ~= "Ride" then
			if not ctx.me:clickText("Ride") then ctx:cannot("no Ride tab to click") end
			ctx:advance(1)
		end
		local K2 = ctx:mod("UI.Kit")
		if K2 and K2.ui and (K2.ui.settingsOpen or K2.ui.tab ~= "Ride") then ctx:na("the phone is on another screen") end
	end

	local function onScreen(ctx, text)
		for _, t in ipairs(ctx:texts()) do
			if t == text then return true end
		end
		return false
	end

	-- (2.4) the What's new card can sit over Home: a player taps Got it, then taps the driver's card (again if nothing opened)
	local function dismissTipCard(ctx)
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
	local function tapCard(ctx, card, name)
		for _ = 1, 3 do
			local gb = ctx.me:button("Got it")
			if gb and ctx:visible(gb) then pcall(function() ctx.me:click(gb) end) ctx:note("tap Got it on the card in the way") ctx:advance(0.5) else break end
		end
		dismissTipCard(ctx)
		ctx.me:clickOn(card)
		ctx:advance(1.5)
		ctx:note("tap " .. name .. "'s card")
		if (ctx:mod("UI.Kit").ui.screen or "") ~= "confirm" then
			dismissTipCard(ctx)
			ctx.me:clickOn(card)
			ctx:advance(1.5)
			ctx:note("tap " .. name .. "'s card again")
		end
	end

	local function nameShown(ctx, name)
		for _, t in ipairs(ctx:texts()) do
			if t == name then return true end
		end
		return false
	end

	local function listText(ctx) return "on screen: " .. table.concat(ctx:texts(), " | ") end

	local function heard(ctx, name)
		local W = ctx.W
		return type(W.drivers) == "table" and W.drivers[key(name)] ~= nil
	end

	-- wait up to secs for pred; true when it came
	local function waitFor(ctx, pred, secs, step)
		step = step or 1
		local t = 0
		while not pred() do
			if t >= secs then return false end
			ctx:advance(step)
			t = t + step
		end
		return true
	end

	---------------------------------------------------------------------------------------------------------------
	-- 1. A driver goes online: riders see him
	---------------------------------------------------------------------------------------------------------------
	Hunt.promise{
		id = "net.driver_appears",
		area = "Network",
		text = "A Warlock who goes online as a Wuber driver shows in your driver list within 20 seconds, with his name and place.",
		source = "Help: finding drivers (the Ride tab lists open drivers); Net.Beacons header",
		kind = "scenario",
		when = function(sit) return is(sit, "role", "rider") and is(sit, "phone", LISTY) and is(sit, "ride", "none") end,
		check = function(ctx)
			riderOnly(ctx)
			local d, name = newDriver(ctx, { spot = "Crossroads" })
			ctx.peers.newDriver = d
			goOnline(ctx, d, name)
			if not waitFor(ctx, function() return heard(ctx, name) end, 20) then
				ctx:fail(("%s goes online as a Wuber driver at Crossroads and 20 seconds later you still do not hear him: he is not in your list."):format(name),
					listText(ctx))
			end
			showRideTab(ctx)
			ctx:advance(1)
			if not nameShown(ctx, name) then
				ctx:fail(("%s is online at Crossroads and the Ride tab does not show his name."):format(name), listText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "net.driver_leaves",
		area = "Network",
		text = "When a driver stops driving, his card goes from your list straight away (within 5 seconds), and from the screen if the phone is open.",
		source = "Net.Inbox / Net.Beacons headers (the leave message); Drive tab: 'Stop taking riders ... you vanish from the map'",
		kind = "scenario",
		when = function(sit) return is(sit, "role", "rider") and is(sit, "phone", LISTY) and is(sit, "ride", "none") end,
		check = function(ctx)
			riderOnly(ctx)
			local d, name = newDriver(ctx, { spot = "Undercity" })
			goOnline(ctx, d, name)
			if not waitFor(ctx, function() return heard(ctx, name) end, 20) then ctx:cannot("his beacon never reached me") end
			showRideTab(ctx)
			ctx:advance(4) -- he has been open for a few seconds: a real shift, not a flicker
			if not nameShown(ctx, name) then ctx:na("he is not on the visible part of the list") end
			d.W.Driver.SetOnline(false)
			ctx:note(name .. " stops driving (/wuber drive off)")
			ctx:advance(5)
			if heard(ctx, name) and ctx.W.drivers[key(name)].state ~= "off" then
				ctx:fail(("%s stops driving and five seconds later he is still in your driver list."):format(name), listText(ctx))
			end
			if nameShown(ctx, name) then
				ctx:fail(("%s stops driving and five seconds later his card is still on the Ride tab."):format(name), listText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "net.driver_logoff",
		area = "Network",
		text = "A driver who logs off (so says nothing more) disappears from your list within about two and a half minutes.",
		source = "Net.Base: a driver is dropped 150 seconds after his last beacon; Help: finding drivers",
		kind = "scenario",
		when = function(sit) return is(sit, "role", "rider") and is(sit, "phone", LISTY) and is(sit, "ride", "none") and not is(sit, "net", "late") end,
		check = function(ctx)
			riderOnly(ctx)
			local d, name = newDriver(ctx, { spot = "Gadgetzan" })
			goOnline(ctx, d, name)
			if not waitFor(ctx, function() return heard(ctx, name) end, 20) then ctx:cannot("his beacon never reached me") end
			-- the window just closes: no goodbye (the game can drop a leaving player's last messages)
			ctx.w:closeClient(d, true)
			ctx:note(name .. " logs off without a word")
			if not waitFor(ctx, function() return not heard(ctx, name) end, 190, 5) then
				ctx:fail(("%s logged off three minutes ago and is still in your driver list."):format(name), listText(ctx))
			end
			showRideTab(ctx)
			ctx:advance(1)
			if nameShown(ctx, name) then
				ctx:fail(("%s logged off three minutes ago and his card is still on the Ride tab."):format(name), listText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "net.price_updates",
		area = "Network",
		text = "When a driver changes his price, your list shows the new price within 10 seconds (the old one goes).",
		source = "Net.Beacons header (the updated beacon goes out within 5 seconds of a change)",
		kind = "scenario",
		when = function(sit) return is(sit, "role", "rider") and is(sit, "phone", LISTY) and is(sit, "ride", "none") end,
		check = function(ctx)
			riderOnly(ctx)
			local d, name = newDriver(ctx, { spot = "Booty Bay" })
			d.W.Char().price = 6000
			goOnline(ctx, d, name)
			if not waitFor(ctx, function() return heard(ctx, name) end, 20) then ctx:cannot("his beacon never reached me") end
			ctx:advance(2)
			d:slash("/wuber drive price 90s")
			ctx:note(name .. " sets his price to 90 silver (/wuber drive price 90s)")
			local e
			local ok = waitFor(ctx, function() e = ctx.W.drivers[key(name)] return e and e.price == 9000 end, 10)
			if not ok then
				ctx:fail(("%s changes his price to 90 silver and ten seconds later your list still has %s."):format(name,
					e and ctx.W.Money(e.price) or "nothing"), listText(ctx))
			end
			showRideTab(ctx)
			ctx:advance(1)
			if not nameShown(ctx, name) then ctx:na("he is not on the visible part of the list") end
		end,
	}

	Hunt.promise{
		id = "net.all_open_listed",
		area = "Network",
		text = "Every open Wuber driver you can hear is in your list, and the line at the top counts them.",
		source = "Ride tab: 'Drivers online ... N open · N online'",
		kind = "scenario",
		needs = { role = "rider" },
		when = function(sit) return is(sit, "phone", LISTY) and is(sit, "ride", "none") and is(sit, "net", { one = true, many = true, late = true, layers = true }) end,
		check = function(ctx)
			local list = ctx.facts.drivers or {}
			if #list == 0 then ctx:na("no drivers on this network") end
			showRideTab(ctx)
			ctx:advance(2)
			for _, d in ipairs(list) do
				-- a driver on another copy of the channel is heard only when he posted his [Wuber] advert
				if (not d.copy or d.advert) and not heard(ctx, d.name) then
					ctx:fail(("%s is open at %s%s and is not in your driver list."):format(d.name, d.dest,
						d.copy and " on another layer, and posted his [Wuber] advert in Trade" or ""), listText(ctx))
				end
			end
			local n
			for _, t in ipairs(ctx:texts()) do
				local a = t:match("^(%d+) open") 
				if a then n = tonumber(a) end
			end
			if n and n ~= #list and not ctx.facts.drivers[1].copy then
				ctx:fail(("%d drivers are open and the Ride tab says %d open."):format(#list, n), listText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "net.cheapest_first",
		area = "Network",
		text = "The driver list is in price order, cheapest first.",
		source = "Net.Beacons header (DriversSorted: price, then the founder, then name); Ride tab",
		kind = "scenario",
		needs = { role = "rider", net = "many" },
		when = function(sit) return is(sit, "phone", LISTY) and is(sit, "ride", "none") end,
		check = function(ctx)
			showRideTab(ctx)
			ctx:advance(2)
			-- the order of the cards on screen: each driver's name, top to bottom
			local order = {}
			for _, t in ipairs(ctx:texts()) do
				local e = ctx.W.drivers[key(t)]
				if e then order[#order + 1] = e end
			end
			if #order < 3 then ctx:na("fewer than three drivers on screen") end
			for i = 2, #order do
				if (order[i].price or 0) < (order[i - 1].price or 0) then
					ctx:fail(("The list shows %s at %s above %s at %s: dearer before cheaper."):format(order[i - 1].name,
						ctx.W.Money(order[i - 1].price), order[i].name, ctx.W.Money(order[i].price)), listText(ctx))
				end
			end
		end,
	}

	Hunt.promise{
		id = "net.late_leave_wins",
		area = "Network",
		text = "When messages arrive late, a driver who went online and then straight offline is not left in your list.",
		source = "inferred (the last thing a driver said is the truth; late and out-of-order messages)",
		kind = "scenario",
		needs = { role = "rider", net = "late" },
		check = function(ctx)
			local d, name = newDriver(ctx, { spot = "Everlook" })
			goOnline(ctx, d, name)
			ctx:advance(0.5)
			d.W.Driver.SetOnline(false)
			ctx:note(name .. " goes online and straight offline")
			ctx:advance(30)
			local e = ctx.W.drivers[key(name)]
			if e and e.state ~= "off" then
				ctx:fail(("%s opened and closed within a second, the messages arrived late, and 30 seconds later you still see him as %s."):format(name, tostring(e.state)),
					listText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "net.old_peer_listed",
		area = "Network",
		text = "A driver still on an older Wuber is listed like any other and you can book him.",
		source = "inferred (nothing breaks with older Wuber versions); Net headers (proto field)",
		kind = "scenario",
		needs = { role = "rider", net = "oldpeer" },
		when = function(sit) return is(sit, "phone", LISTY) and is(sit, "group", "solo") and is(sit, "ride", "none") end,
		check = function(ctx)
			local d = (ctx.facts.drivers or {})[1]
			if not d then ctx:cannot("no old driver") end
			showRideTab(ctx)
			ctx:advance(2)
			if not nameShown(ctx, d.name) then
				ctx:fail(("%s drives on the first Wuber (version %s) and is not on your Ride tab."):format(d.name, tostring(d.version)), listText(ctx))
			end
			local card = ctx.W.UI.state and ctx.W.UI.state.cards and ctx.W.UI.state.cards[key(d.name)]
			if not card then ctx:cannot("no card object to click") end
			tapCard(ctx, card, d.name)
			local okr = pcall(ctx.me.clickText, ctx.me, "^Request summon", { pattern = true })
			if not okr then
				ctx:fail(("You tap %s's card (he is on the first Wuber) and the booking screen has no Request summon button."):format(d.name), listText(ctx))
			end
			ctx:advance(3)
			local got
			for _, e in ipairs(ctx.w.addonLog) do
				if e.from == ctx.name and tostring(e.text):find(d.name, 1, true) then got = true end
			end
			for _, e in ipairs(ctx.w.whispers or {}) do if e.from == ctx.name then got = true end end
			if not (ctx.W.ride and ctx.W.ride.state) and not got then
				ctx:fail(("You pick %s (on the first Wuber) and click Request: nothing happens, no request reaches him."):format(d.name), listText(ctx))
			end
		end,
	}
	---------------------------------------------------------------------------------------------------------------
	-- 2. "A newer Wuber is out"
	---------------------------------------------------------------------------------------------------------------
	local NEWER = "2.9.0"
	local OLDER = "2.3.0"

	-- a released build's number (a test build says "-dev" and, as designed, never shows the notice)
	local function asReleased(ctx)
		ctx.W.VERSION = OLDER
		ctx:note("my Wuber is " .. OLDER)
	end

	local NOTE_PAT = "Wuber %d+%.%d+%.%d+ is out"

	-- records every toast the phone raises (the quiet note is a toast); returns the list it fills
	local function watchToasts(ctx)
		local list = {}
		local UI = ctx.W.UI
		local real = UI.Toast
		UI.Toast = function(text, kind, fn)
			if tostring(text):find(NOTE_PAT) then list[#list + 1] = tostring(text) end
			return real(text, kind, fn)
		end
		return list
	end

	-- the conditions in which the notice may show (it waits for a quiet moment)
	local function quiet(ctx)
		if ctx.me.player.combat then ctx:na("in combat") end
		local K = ctx:mod("UI.Kit")
		if K and type(K.rideActive) == "function" then
			local ok, active = pcall(K.rideActive)
			if ok and active then ctx:na("a ride is on") end
		end
		if ctx.W.db and ctx.W.db.updateNotes == false then ctx:na("Tell me about updates is off") end
	end

	local function peerOnVersion(ctx, spot)
		local d, name = newDriver(ctx, { spot = spot, version = NEWER })
		goOnline(ctx, d, name)
		return d, name
	end

	Hunt.promise{
		id = "net.newer_notice",
		area = "Network",
		text = "When two other players are on a newer Wuber, you get one quiet note a few seconds later that it is out on CurseForge.",
		source = "BRIEF11; Settings > This window > Tell me about updates; CHANGELOG 2.3.3",
		kind = "scenario",
		needs = { role = "rider" },
		when = function(sit) return is(sit, "ride", "none") and is(sit, "combat", "no") and sit.updateNotes ~= "off" and sit.session ~= "first" end,
		check = function(ctx)
			quiet(ctx)
			asReleased(ctx)
			local toasts = watchToasts(ctx)
			peerOnVersion(ctx, "Orgrimmar")
			peerOnVersion(ctx, "Undercity")
			ctx:advance(2)
			local seen
			local ok = waitFor(ctx, function() seen = toasts[1] return seen ~= nil end, 25)
			if not ok then
				ctx:fail("Two players you can hear run Wuber " .. NEWER .. ", yours is older, and half a minute later no note says a newer Wuber is out.", listText(ctx))
			end
			if not seen:find(NEWER, 1, true) then
				ctx:fail("The note about the newer Wuber does not say which version is out (" .. NEWER .. ").", seen)
			end
		end,
	}

	Hunt.promise{
		id = "net.newer_one_stranger",
		area = "Network",
		text = "One stranger claiming a newer Wuber is not enough to make Wuber tell you an update is out.",
		source = "Net.Update header (two different players, or the founder, so a forged claim does nothing)",
		kind = "scenario",
		needs = { role = "rider" },
		when = function(sit) return is(sit, "ride", "none") and is(sit, "combat", "no") and sit.updateNotes ~= "off" and sit.session ~= "first" end,
		check = function(ctx)
			quiet(ctx)
			asReleased(ctx)
			local toasts = watchToasts(ctx)
			peerOnVersion(ctx, "Orgrimmar")
			ctx:advance(30)
			local seen = toasts[1]
			if seen then
				ctx:fail("Only one player claims a newer Wuber and you are told one is out anyway.", seen)
			end
		end,
	}

	Hunt.promise{
		id = "net.newer_off_silent",
		area = "Network",
		text = "With Tell me about updates off, Wuber never tells you a newer Wuber is out.",
		source = "Settings > This window > Tell me about updates",
		kind = "scenario",
		needs = { role = "rider", updateNotes = "off" },
		when = function(sit) return is(sit, "ride", "none") and is(sit, "combat", "no") end,
		check = function(ctx)
			if ctx.me.player.combat then ctx:na("in combat") end
			asReleased(ctx)
			local toasts = watchToasts(ctx)
			peerOnVersion(ctx, "Orgrimmar")
			peerOnVersion(ctx, "Undercity")
			ctx:advance(30)
			local seen = toasts[1]
			if seen then ctx:fail("You switched Tell me about updates off and Wuber still says a newer Wuber is out.", seen) end
		end,
	}

	Hunt.promise{
		id = "net.newer_once",
		area = "Network",
		text = "You are told about a newer Wuber once per play session, not again and again.",
		source = "Net.Update header (one quiet toast per session)",
		kind = "scenario",
		needs = { role = "rider" },
		when = function(sit) return is(sit, "ride", "none") and is(sit, "combat", "no") and sit.updateNotes ~= "off" and sit.session ~= "first" end,
		check = function(ctx)
			quiet(ctx)
			asReleased(ctx)
			local list = watchToasts(ctx)
			peerOnVersion(ctx, "Orgrimmar")
			peerOnVersion(ctx, "Undercity")
			local d3 = peerOnVersion(ctx, "Thunder Bluff")
			ctx:advance(20)
			if #list == 0 then ctx:na("no notice came, net.newer_notice says why") end
			ctx:advance(300)
			if #list > 1 then
				ctx:fail(("You are told a newer Wuber is out %d times in one session."):format(#list))
			end
		end,
	}

	---------------------------------------------------------------------------------------------------------------
	-- 3. The founders' look, only on the founders' ruleset; only [Wuber] drivers
	---------------------------------------------------------------------------------------------------------------
	Hunt.promise{
		id = "net.founder_first",
		area = "Network",
		text = "On the founders' ruleset (EU-PvE) the founder's card comes first among drivers at the same price.",
		source = "Net.Beacons header (DriversSorted: price, then the founder, then name)",
		kind = "scenario",
		needs = { role = "rider" },
		pre = function(ctx) ctx.worldOpts.realm = ctx.H.FOUNDER_REALM end,
		when = function(sit) return is(sit, "phone", LISTY) and is(sit, "ride", "none") end,
		check = function(ctx)
			if ctx.W.OnFounderRuleset and not ctx.W.OnFounderRuleset() then ctx:na("not on the founders' ruleset") end
			local d, name = newDriver(ctx, { name = "Anita Lift", spot = "Orgrimmar" })
			d.W.Char().price = 5000
			goOnline(ctx, d, name)
			if not waitFor(ctx, function() return heard(ctx, name) end, 20) then ctx:cannot("her beacon never reached me") end
			-- another driver at the same price whose name comes before hers
			local d2, n2 = newDriver(ctx, { name = "Abe Cross", spot = "Orgrimmar" })
			d2.W.Char().price = 5000
			goOnline(ctx, d2, n2)
			if not waitFor(ctx, function() return heard(ctx, n2) end, 20) then ctx:cannot("his beacon never reached me") end
			ctx:advance(3)
			showRideTab(ctx)
			local order = {}
			for _, t in ipairs(ctx:texts()) do
				local e = ctx.W.drivers[key(t)]
				if e and e.price == 5000 then order[#order + 1] = key(e.name) end
			end
			local ia, ib
			for i, k in ipairs(order) do
				if k == "anita lift" then ia = i end
				if k == "abe cross" then ib = i end
			end
			if not (ia and ib) then ctx:na("both are not on the visible part of the list") end
			if ia > ib then
				ctx:fail("Anita Lift (a founder) and Abe Cross drive at the same price and the list shows Abe Cross above the founder.", listText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "net.founder_only_eupve",
		area = "Network",
		text = "Outside the founders' ruleset a player with a founder's name is just a player: no founder status, no priority.",
		source = "CLAUDE.md: founder status is locked to EU-PvE + the founders' names; Core.Base header",
		kind = "scenario",
		needs = { role = "rider" },
		check = function(ctx)
			local W = ctx.W
			if type(W.IsCreator) ~= "function" then ctx:cannot("no W.IsCreator") end
			-- I play on a PvP realm of another region: nobody there is a founder
			local oldRealm = ctx.me.realm
			ctx.me.realm = "CAMWOW US2 Realm 1 PvP"
			if W.OnFounderRuleset and W.OnFounderRuleset() then
				ctx.me.realm = oldRealm
				ctx:cannot("could not move the player to another ruleset")
			end
			local d, name = newDriver(ctx, { name = "Anita Lift", spot = "Orgrimmar", realm = "CAMWOW US2 Realm 1 PvP" })
			goOnline(ctx, d, name)
			ctx:advance(15)
			local e = W.drivers[key(name)]
			if not e then ctx.me.realm = oldRealm ctx:cannot("her beacon never reached me") end
			local crowned = e.creator == true or W.IsCreator(name) == true
			ctx.me.realm = oldRealm
			if crowned then
				ctx:fail("You play on a PvP realm of another region and a player called Anita Lift is shown as a Wuber founder.", listText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "net.other_faction_hidden",
		area = "Network",
		text = "A driver of the other faction never shows in your driver list.",
		source = "Net.Beacons header (opposing faction drivers are never shown); a summon cannot cross factions",
		kind = "scenario",
		needs = { role = "rider" },
		when = function(sit) return is(sit, "phone", LISTY) and is(sit, "ride", "none") end,
		check = function(ctx)
			local d, name = newDriver(ctx, { spot = "Stormwind", faction = "Alliance" })
			goOnline(ctx, d, name)
			ctx:advance(25)
			if heard(ctx, name) then
				ctx:fail(("%s drives for the Alliance and is in your Horde driver list."):format(name))
			end
			showRideTab(ctx)
			if nameShown(ctx, name) then
				ctx:fail(("%s drives for the Alliance and his card is on your Horde Ride tab."):format(name), listText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "net.min_fare",
		area = "Network",
		text = "No driver is listed for less than 50 silver, however low he sets his price.",
		source = "Core.Base: the lowest fare is 50 silver (W.MIN_PRICE)",
		kind = "scenario",
		needs = { role = "rider" },
		check = function(ctx)
			local d, name = newDriver(ctx, { spot = "Orgrimmar" })
			goOnline(ctx, d, name)
			d:slash("/wuber drive price 1s")
			ctx:note(name .. " tries /wuber drive price 1s")
			ctx:advance(12)
			local e = ctx.W.drivers[key(name)]
			if e and (e.price or 0) < 5000 then
				ctx:fail(("%s sets his price to 1 silver and you see him listed at %s (the lowest fare is 50 silver)."):format(name, ctx.W.Money(e.price)))
			end
		end,
	}

	Hunt.promise{
		id = "net.advert_not_a_buyer",
		area = "Network",
		text = "Another driver's [Wuber] advert in Trade chat is never taken for a rider: it adds nothing to your queue and nobody is invited.",
		source = "CLAUDE.md: a line tagged [Wuber] is another driver's advert, never a buyer",
		kind = "scenario",
		when = function(sit) return is(sit, "role", { warlock = true, friend = true, crew = true }) end,
		check = function(ctx)
			local W = ctx.W
			local d, name = newDriver(ctx, { spot = "Ratchet" })
			goOnline(ctx, d, name)
			local DR = d.W.Drive
			local text = DR and DR.AdvertText and DR.AdvertText()
			if not text then ctx:cannot("no advert text on the other window") end
			ctx:advance(2)
			local before = type(W.incoming) == "table" and #W.incoming or 0
			ctx.w:chatFrom(name, text, "CHANNEL", "Trade")
			ctx:note(name .. " posts his [Wuber] advert in Trade")
			ctx:advance(12)
			local after = type(W.incoming) == "table" and #W.incoming or 0
			if after > before then
				ctx:fail(name .. " posts his own [Wuber] advert in Trade and it lands in your queue as a rider asking for a summon.", "queue " .. before .. " -> " .. after)
			end
		end,
	}
	---------------------------------------------------------------------------------------------------------------
	-- 4. The public API for driver addons (WuberAPI), the Wuber community
	---------------------------------------------------------------------------------------------------------------
	local function otherAddon(ctx, name, price, seats)
		local nm = freeName(ctx)
		local d = ctx.w:addClient(nm, { spot = "Ratchet", class = "WARLOCK", shards = 10 })
		local API = d.env.WuberAPI
		if type(API) ~= "table" then ctx:cannot("no WuberAPI on the other window") end
		local requests = {}
		API.SetDriver({ name = name, beacon = function() return { dest = "Ratchet", price = price, state = "open", seats = seats } end,
			onRequest = function(ride) requests[#requests + 1] = ride end, onCancel = function() end, onRating = function() end })
		ctx:note(nm .. " runs the driver addon '" .. name .. "' (WuberAPI.SetDriver)")
		return d, nm, requests, API
	end

	Hunt.promise{
		id = "net.api_driver_listed",
		area = "Network",
		text = "A driver using another driver addon (through WuberAPI) is listed for riders like any Wuber driver, with the price his addon gives.",
		source = "WuberAPI (Net.Provider header: the public API for driver addons)",
		kind = "scenario",
		needs = { role = "rider" },
		when = function(sit) return is(sit, "phone", LISTY) and is(sit, "ride", "none") end,
		check = function(ctx)
			local d, nm, _, API = otherAddon(ctx, "Other Rides", 7000)
			API.Beacon()
			if not waitFor(ctx, function() return heard(ctx, nm) end, 25) then
				ctx:fail(nm .. " drives with another driver addon that follows the Wuber API and never shows in your list.", listText(ctx))
			end
			local e = ctx.W.drivers[key(nm)]
			if e.price ~= 7000 then
				ctx:fail(("The driver addon says 70 silver and your list says %s."):format(ctx.W.Money(e.price)))
			end
			showRideTab(ctx)
			ctx:advance(1)
			if not nameShown(ctx, nm) then ctx:fail(nm .. " is heard but not on the Ride tab.", listText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "net.api_request_reaches_addon",
		area = "Network",
		text = "When you book a driver who uses another driver addon, that addon is told about your request.",
		source = "WuberAPI (onRequest); Net.Provider header",
		kind = "scenario",
		needs = { role = "rider" },
		when = function(sit) return is(sit, "phone", LISTY) and is(sit, "group", "solo") and is(sit, "ride", "none") and is(sit, "ride", "none") and is(sit, "net", "none") end,
		check = function(ctx)
			local d, nm, requests, API = otherAddon(ctx, "Other Rides", 7000)
			API.Beacon()
			if not waitFor(ctx, function() return heard(ctx, nm) end, 25) then ctx:cannot("his beacon never reached me") end
			showRideTab(ctx)
			ctx:advance(1)
			local card = ctx.W.UI.state and ctx.W.UI.state.cards and ctx.W.UI.state.cards[key(nm)]
			if not card then ctx:na("his card is not on screen") end
			tapCard(ctx, card, nm)
			local okr = pcall(ctx.me.clickText, ctx.me, "^Request summon", { pattern = true })
			if not okr then ctx:fail("You tap a driver's card who uses another driver addon and the booking screen has no Request summon button.", listText(ctx)) end
			ctx:advance(5)
			if #requests == 0 then
				ctx:fail("You click Request summon on a driver who uses another driver addon and that addon never hears of it.", listText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "net.api_never_breaks_addons",
		area = "Network",
		text = "A driver addon that calls Wuber's public API with wrong or missing values never gets a Lua error back.",
		source = "WuberAPI (Net.Provider: calls from another addon never raise)",
		kind = "scenario",
		check = function(ctx)
			local API = ctx.env and ctx.env.WuberAPI or ctx.me.env.WuberAPI
			if type(API) ~= "table" then ctx:cannot("no WuberAPI") end
			local junk = { nil, false, 0, -1, "", "x", {}, function() end, 1e300, "\0" }
			for _, fname in ipairs({ "Accept", "Decline", "Status", "Beacon", "Drivers", "IsOnNetwork", "Queue", "Driving" }) do
				local f = API[fname]
				if type(f) == "function" then
					for i = 1, 10 do
						local ok, err = pcall(f, junk[i], junk[(i % 10) + 1], junk[((i + 3) % 10) + 1], junk[((i + 5) % 10) + 1])
						if not ok then
							ctx:fail(("A driver addon calls WuberAPI.%s with odd values and gets a Lua error back."):format(fname), tostring(err))
						end
					end
				end
			end
			local ok, err = pcall(API.SetDriver, 5)
			if not ok then ctx:fail("A driver addon calls WuberAPI.SetDriver with something that is not a table and gets a Lua error back.", tostring(err)) end
		end,
	}

	Hunt.promise{
		id = "net.api_stops_own_driving",
		area = "Network",
		text = "While another driver addon is in charge, Wuber's own driver mode stays off, so you never drive twice.",
		source = "WuberAPI (Net.Provider header: while a provider is set Wuber's own driver mode stays off)",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			local W = ctx.W
			local API = ctx.me.env.WuberAPI
			if type(API) ~= "table" then ctx:cannot("no WuberAPI") end
			API.SetDriver({ name = "Other Rides", beacon = function() return nil end, onRequest = function() end })
			ctx:advance(3)
			ctx:note("another driver addon takes charge")
			if type(W.engine) == "table" then
				ctx:fail("Another driver addon takes charge and Wuber's own driver mode is still driving as well.")
			end
			local DRm = ctx:mod("Drive.Core")
			local DR = W.Drive
			if DR and type(DR.Lock) == "function" and DR.Lock() ~= "provider" then
				ctx:fail("Another driver addon takes charge and Wuber does not say so on the Drive tab (it is not locked to the other addon).")
			end
		end,
	}

	Hunt.promise{
		id = "net.community_join",
		area = "Network",
		text = "When the Wuber community invites a Warlock, the Drive tab offers a Join card and clicking Join joins the community without adding a chat channel.",
		source = "Drive tab: 'Join the Wuber community' (tooltip: No channel, nothing in your chat); Net.Community header",
		kind = "scenario",
		needs = { role = "warlock", session = "login" },
		-- gap: with a ride on, the Join card sits below the fold and the check cannot scroll to it
		when = function(sit) return is(sit, "phone", LISTY) and is(sit, "ride", "none") end,
		gap = "the check cannot scroll the Drive tab to reach the Join card when the page is long",
		pre = function(ctx) ctx.worldOpts.clubs = true end,
		check = function(ctx)
			local w, W = ctx.w, ctx.W
			if not (w.clubsOn and type(W.CommunityAvailable) == "function") then ctx:cannot("no communities in this world") end
			if ctx.me.player.combat then ctx:na("in combat") end
			-- the inviter must not be the player's own character (saved=acct4_main logs in as Anita Lift: she would already be a member)
			local inviter = (key(ctx.name) == "wuber rocks") and "Wuber TestCharacter" or "Wuber Rocks"
			local club = w:addClub({ id = 77, name = "Wuber", members = { [inviter] = 1 }, streams = {
				{ streamId = 2, name = "Wuber", streamType = 3, leadersAndModeratorsOnly = true }, { streamId = 1, name = "General", streamType = 0 } } })
			if W.OnFounderRuleset and not W.OnFounderRuleset() then ctx:na("not on the founders' ruleset") end
			w:clubInvite(club, inviter, ctx.name)
			ctx:advance(2)
			ctx:note("the founder's community invites me")
			-- the Drive tab: scroll to the card
			local UI = W.UI
			UI.Toggle(true) ctx:advance(3)
			-- (2.4) a player closes what is over the screen first: Help, and the What's new card (Got it)
			local function clearOver()
				if type(UI.HelpShown) == "function" and UI.HelpShown() and type(UI.CloseHelp) == "function" then
					UI.CloseHelp(true)
					ctx:note("close Help")
					ctx:advance(0.5)
				end
				for _ = 1, 3 do
					local gb = ctx.me:button("Got it")
					if gb and ctx:visible(gb) then pcall(function() ctx.me:click(gb) end) ctx:note("tap Got it on the card in the way") ctx:advance(0.5) else break end
				end
				-- (job 2680) older saved data: the What's new pop-up (See what's new / Not now) is over the page; a player taps Not now
				for _ = 1, 3 do
					local nb = ctx.me:button("Not now")
					if nb and ctx:visible(nb) then pcall(function() ctx.me:click(nb) end) ctx:note("tap Not now on the What's new card in the way") ctx:advance(0.5) else break end
				end
			end
			clearOver()
			ctx.me:clickText("Drive") ctx:advance(1)
			clearOver()
			local function found() for _, t in ipairs(ctx:texts()) do if t == "Join the Wuber community" then return true end end end
			if not found() then
				if not (W.CommunityInvite and W.CommunityInvite()) then
					ctx:fail("The Wuber community invites you and Wuber does not know of the invitation (no Join card can show).", listText(ctx))
				end
				ctx:na("Wuber knows of the invitation; its card is below the fold and the check cannot scroll")
			end
			-- (counted here, not before the invite: with real saved data the net channel can still be joining at login)
			local chans = 0
			for i = 1, 20 do if (ctx.me.env.GetChannelName(i) or 0) > 0 then chans = chans + 1 end end
			clearOver()
			local hit = ctx.me:clickText("Join")
			-- (job 2680) the Join text is below the fold, behind the tab bar: the click landed on another button, not on Join (known false alarm)
			if hit and hit.label and hit.label.GetText and hit.label:GetText() ~= "Join" then ctx:cannot("the Join card is below the fold; the click landed on " .. tostring(hit.label:GetText())) end
			ctx:advance(3)
			if club.members[key(ctx.name)] == nil and not (W.CommunityMember and W.CommunityMember()) then
				ctx:fail("You click Join on the Wuber community card and you are not in the community.", listText(ctx))
			end
			local after = 0
			for i = 1, 20 do if (ctx.me.env.GetChannelName(i) or 0) > 0 then after = after + 1 end end
			if after > chans then
				ctx:fail("Joining the Wuber community takes one of your chat channel slots (it says it would not).")
			end
		end,
	}
	Hunt.promise{
		id = "net.place_updates",
		area = "Network",
		text = "When a driver changes where he summons to, your list shows the new place within 10 seconds.",
		source = "Net.Beacons header (an updated beacon goes out within 5 seconds of a change of price, destination, state)",
		kind = "scenario",
		when = function(sit) return is(sit, "role", "rider") and is(sit, "phone", LISTY) and is(sit, "ride", "none") end,
		check = function(ctx)
			riderOnly(ctx)
			local d, name = newDriver(ctx, { spot = "Ratchet" })
			goOnline(ctx, d, name)
			if not waitFor(ctx, function() return heard(ctx, name) end, 20) then ctx:cannot("his beacon never reached me") end
			ctx:advance(2)
			d:slash("/wuber drive dest Undercity")
			ctx:note(name .. " sets his place to Undercity (/wuber drive dest Undercity)")
			local e
			if not waitFor(ctx, function() e = ctx.W.drivers[key(name)] return e and tostring(e.dest):lower() == "undercity" end, 10) then
				ctx:fail(("%s changes his place to Undercity and ten seconds later your list still says %s."):format(name, e and tostring(e.dest) or "nothing"), listText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "net.pause_shows",
		area = "Network",
		text = "A driver who pauses is no longer shown to you as open, and shows as open again when he resumes.",
		source = "Drive tab: Pause / Resume; Net.Beacons header (state open, busy, paused)",
		kind = "scenario",
		when = function(sit) return is(sit, "role", "rider") and is(sit, "phone", LISTY) and is(sit, "ride", "none") end,
		check = function(ctx)
			riderOnly(ctx)
			local d, name = newDriver(ctx, { spot = "Ratchet" })
			goOnline(ctx, d, name)
			if not waitFor(ctx, function() return heard(ctx, name) end, 20) then ctx:cannot("his beacon never reached me") end
			ctx:advance(2)
			d:slash("/wuber drive pause")
			ctx:note(name .. " pauses (/wuber drive pause)")
			local e
			if not waitFor(ctx, function() e = ctx.W.drivers[key(name)] return e == nil or e.state ~= "open" end, 10) then
				ctx:fail(name .. " pauses and ten seconds later you still see him as open.", listText(ctx))
			end
			d:slash("/wuber drive resume")
			ctx:note(name .. " resumes")
			if not waitFor(ctx, function() e = ctx.W.drivers[key(name)] return e ~= nil and e.state == "open" end, 10) then
				ctx:fail(name .. " resumes and ten seconds later you do not see him as open.", listText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "net.api_not_full",
		area = "Network",
		text = "A driver who uses another driver addon and says he has seats is not shown to you as 'Group full'.",
		-- (judge4, F016: the first wording, "says nothing about seats", was the hunt's own inference. SPEC.md:287 says "seats = free group
		-- slots only (0 = Full)" and Net/Beacons.lua defaults a missing seats to 0, so a beacon with no seats reads as Full by design.
		-- SPEC.md:85 says the opposite: "seats: 0 if the rider must bring 2 helpers". The two lines contradict each other.)
		source = "WuberAPI beacon seats (SPEC.md:287: seats = free group slots; 0 = Full)",
		kind = "scenario",
		needs = { role = "rider" },
		when = function(sit) return is(sit, "phone", LISTY) and is(sit, "ride", "none") end,
		check = function(ctx)
			local d, nm, _, API = otherAddon(ctx, "Other Rides", 7000, 3)
			API.Beacon()
			if not waitFor(ctx, function() return heard(ctx, nm) end, 25) then ctx:cannot("his beacon never reached me") end
			showRideTab(ctx)
			ctx:advance(1)
			if not nameShown(ctx, nm) then ctx:na("his card is not on the visible part of the list") end
			for _, t in ipairs(ctx:texts()) do
				if t:find("Group full", 1, true) then
					ctx:fail(nm .. " is open with another driver addon that says he has 3 seats, and his card says Group full.", listText(ctx))
				end
			end
		end,
	}
end
