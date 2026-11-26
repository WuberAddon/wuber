-- Promises about the 2.3.4 fix rounds (rounds 31 to 48), tests/promises/v234_fixes.lua.
-- Each one is a line of release/CHANGELOG-2.3.4.md that depends on the situation (a part payment, a /reload, a paused or raid
-- driver, a group the driver does not lead), tried in a state the round's own test did not use. Logic only.
return function(Hunt)
	local BORDER = { mapID = 1411, x = 0.04, y = 0.45, zone = "The Barrens", sub = "" }
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end
	local function strip(s) return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")) end
	local function asRider(sit)
		return (sit.role == nil or sit.role == "rider") and sit.net ~= "none" and sit.net ~= "oldpeer" and sit.net ~= "layers"
			and sit.net ~= "late" and (sit.group == nil or sit.group == "solo")
	end
	local function asLoneDriver(sit) return sit.role == "warlock" and sit.net == "none" and sit.session ~= "first" end
	local FOLDABLE = { home = true, trips = true, drive = true, drive_earnings = true, drive_messages = true, drive_customers = true,
		settings = true, settings_riding = true, settings_driving = true, settings_map = true, settings_sound = true,
		settings_window = true, world_view = true, here_view = true, confirm = true, wrapped = true }
	local function promise(p, rider)
		p.area = "Fixes 2.3.4"
		p.kind = "scenario"
		local w = p.when or (rider and asRider or asLoneDriver)
		p.when = function(sit)
			if sit.fold == "folded_click" and not FOLDABLE[sit.phone or "closed"] then return false end
			return w(sit)
		end
		if rider then p.needs = p.needs or { ride = "none" }
		else p.needs = p.needs or { role = "warlock", net = "none", ride = "none", combat = "no", group = "solo" } end
		Hunt.promise(p)
	end
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
	local function must(ctx, v, why) if not v then ctx:cannot("fix234: " .. why) end end
	local function click(ctx, r, fn)
		local w = ctx.w
		if w.huntU then w.huntU.lastHW[r.name or ctx.name] = w.time end
		w.hardware = r
		local res = { pcall(fn) }
		w.hardware = nil
		if not res[1] then error(res[2], 0) end
		return unpack(res, 2)
	end
	local function M(ctx, c) return ctx.W.Money(c) end

	-- the rider r books the driver d and joins the group; nothing is paid yet
	local function book(ctx, r, d)
		local W = r.W
		local t = { r = r, d = d, key = key(d.player.name), rkey = key(r.player.name) }
		ctx.w:move(r.player.name, BORDER)
		if not waitFor(ctx, function() return W.drivers[t.key] ~= nil end, 240, 1) then ctx:cannot("fix234: the rider never saw the driver") end
		local ride, why = click(ctx, r, function()
			local x, y = W.RequestRide(t.key)
			local text = x and W.RequestWhisper(t.key)
			if text then ctx.w:whisper(r, d.player.name, text, "macro") end
			return x, y
		end)
		must(ctx, ride, "the request was refused: " .. tostring(why))
		must(ctx, waitFor(ctx, function()
			local p = r.player
			if not p.group and p.pendingInvite then
				ctx.w.hardware = r
				r.env.AcceptGroup()
				ctx.w.hardware = nil
				r.popups.PARTY_INVITE = nil
			end
			return W.ride and W.RIDE_RANK[W.ride.state] >= W.RIDE_RANK.ingroup
		end, 12), "the rider never joined the group")
		t.fare = W.ride.price
		t.id = W.ride.id
		must(ctx, waitFor(ctx, function() t.c = d.W.Drive.customers[t.rkey] return t.c ~= nil end, 8), "the driver's list never got the rider")
		return t
	end
	-- the rider puts in 'give' copper, the driver puts in 'back' copper (change); both accept
	local function trade(ctx, t, give, back)
		local rp, dp = t.r.player, t.d.player
		if rp.trade then ctx.w:tradeCancel(rp) end
		if dp.trade then ctx.w:tradeCancel(dp) end
		ctx:advance(0.5)
		must(ctx, ctx.w:openTrade(dp, rp), "no trade between the two")
		ctx.w:tradeMoney(rp, give)
		if back and back > 0 then ctx.w:tradeMoney(dp, back) end
		ctx.w:tradeAccept(dp)
		ctx.w:tradeAccept(rp)
		ctx:note(t.r.player.name .. " puts in " .. give .. " copper, the driver gives back " .. tostring(back or 0))
		ctx:advance(2.5)
	end
	local function snap(d)
		local life, sess = d.W.Drive.Stats()
		return { copper = life.copper, tips = life.tips, rides = life.rides, scopper = sess.copper, stips = sess.tips }
	end
	local function driverOf(ctx)
		local d = ctx.peers.driver
		must(ctx, d, "no driver window")
		if ctx.me.player.combat then ctx:na("combat") end
		return d
	end
	local function lines(ctx, from) local out = {} for i = from + 1, #ctx.me.chatLines do out[#out + 1] = strip(ctx.me.chatLines[i]) end return out end

	---------------------------------------------------------------------------
	-- RIDER SIDE
	promise({
		id = "fix234.change_after_part_not_tip",
		text = "After a part payment, when the last trade has the driver giving change back, only what the driver keeps counts: the fare is paid once and no tip is recorded.",
		source = "CHANGELOG 2.3.4: When you give change in the trade, only what you keep counts as the fare. The change is no longer shown as a tip.",
		check = function(ctx)
			local d = driverOf(ctx)
			local b = snap(d)
			local t = book(ctx, ctx.me, d)
			local half = math.floor(t.fare / 200) * 100
			if half <= 0 or half >= t.fare then ctx:na("fare too small to split") end
			trade(ctx, t, half, 0)
			local change = 1000
			trade(ctx, t, (t.fare - half) + change, change)
			local a = snap(d)
			if a.tips - b.tips ~= 0 then
				ctx:fail(("A rider pays part of a %s fare, then hands over %s more while the driver gives %s change back, and the driver is told of a %s tip."):format(
					M(ctx, t.fare), M(ctx, t.fare - half + change), M(ctx, change), M(ctx, a.tips - b.tips)))
			end
			if a.copper - b.copper ~= t.fare then
				ctx:fail(("A rider pays a %s fare in two trades, the second with %s change given back, and the driver's earnings grow by %s."):format(
					M(ctx, t.fare), M(ctx, change), M(ctx, a.copper - b.copper)))
			end
			local c = d.W.Drive.customers[t.rkey]
			if c and (c.paid or 0) ~= t.fare then
				ctx:fail(("A rider pays a %s fare with change given back and the driver's queue shows %s paid."):format(M(ctx, t.fare), M(ctx, c.paid or 0)))
			end
		end,
	}, true)

	promise({
		id = "fix234.rated_ride_not_back_after_reload",
		text = "A ride you have paid and rated does not come back as the Done screen asking for stars after a /reload.",
		source = "CHANGELOG 2.3.4: A finished ride you already rated (or ended without paying) no longer comes back as the Done screen after a /reload.",
		check = function(ctx)
			local d = driverOf(ctx)
			local t = book(ctx, ctx.me, d)
			trade(ctx, t, t.fare, 0)
			ctx.w:summon(d.player, ctx.me.player.name)
			ctx:advance(1)
			ctx.W.UI.Toggle(true)
			ctx:advance(2.5)
			click(ctx, ctx.me, function() ctx.me:clickText("Accept summon") end)
			ctx:advance(4)
			if not (ctx.W.ride and ctx.W.ride.state == "done") then ctx:na("the ride did not reach Done here (" .. tostring(ctx.W.ride and ctx.W.ride.state) .. ")") end
			if not ctx.W.Rate(5) then ctx:na("the rating was not accepted") end
			ctx:advance(2)
			ctx:reload()
			ctx:advance(5)
			local r = ctx.W.ride
			if r and r.state == "done" and not r.rated then
				ctx:fail("You paid and rated your ride, pressed /reload, and the Done screen is back asking you to rate it again.")
			end
			for _, tx in ipairs(ctx:texts()) do
				if strip(tx):find("Tap a star", 1, true) then ctx:fail("You paid and rated your ride, pressed /reload, and the screen says Tap a star again.") end
			end
		end,
	}, true)

	promise({
		id = "fix234.paid_then_left_not_blocked",
		text = "A rider who pays by trade and leaves the group at once is not blocked as a non-payer by the driver.",
		source = "CHANGELOG 2.3.4: A rider who pays and leaves the group straight away is no longer blocked as a non-payer.",
		check = function(ctx)
			local d = driverOf(ctx)
			local t = book(ctx, ctx.me, d)
			trade(ctx, t, t.fare, 0)
			ctx.w:leave(ctx.me.player.name, "left")
			ctx:note("the rider leaves the group right after paying")
			ctx:advance(150)
			local DR = d.W.Drive
			if DR.BlockEntry(t.rkey) then
				ctx:fail("You pay your driver by trade, leave the group at once, and the driver's list has you blocked as a non-payer.")
			end
		end,
	}, true)

	promise({
		id = "fix234.second_booking_keeps_first_ride",
		text = "If you ask for a ride again while your summon is under way, the first ride keeps working: it is still your ride and your payment still counts.",
		source = "CHANGELOG 2.3.4: A rider who books again while their summon is under way is told the driver is busy, and the first ride keeps working: its cancel, its payment and its rating still count.",
		check = function(ctx)
			local d = driverOf(ctx)
			local t = book(ctx, ctx.me, d)
			local DR = d.W.Drive
			DR.SetState(t.c, "summoning")
			ctx:advance(1)
			local b = snap(d)
			click(ctx, ctx.me, function()
				local x = ctx.W.RequestRide(t.key)
				local text = x and ctx.W.RequestWhisper(t.key)
				if text then ctx.w:whisper(ctx.me, d.player.name, text, "macro") end
			end)
			ctx:note("the rider asks for the same driver again while the summon is under way")
			ctx:advance(6)
			if not ctx.W.ride then ctx:fail("You ask again while your summon is under way and your ride is gone.") end
			trade(ctx, t, t.fare, 0)
			local a = snap(d)
			if a.copper - b.copper ~= t.fare then
				ctx:fail(("You ask for a second ride while the first summon is under way, then pay the %s fare, and the driver's earnings grow by %s."):format(M(ctx, t.fare), M(ctx, a.copper - b.copper)))
			end
		end,
	}, true)

	promise({
		id = "fix234.driver_drops_joined_rider",
		text = "If the driver removes you from their group after you joined it, Wuber ends the ride as declined; you are not left waiting for a portal.",
		source = "CHANGELOG 2.3.4: If a driver drops you after you have joined their group, Wuber now tells you the ride was declined instead of waiting for a portal.",
		check = function(ctx)
			local d = driverOf(ctx)
			local t = book(ctx, ctx.me, d)
			ctx.w:uninvite(d, ctx.me.player.name)
			ctx:note("the driver removes the rider from the group")
			ctx:advance(30)
			local r = ctx.W.ride
			if r and (r.state == "ingroup" or r.state == "accepted" or r.state == "summoning") then
				ctx:fail("Your driver removes you from their group and your ride screen keeps waiting for a portal (" .. tostring(r.state) .. ").")
			end
		end,
	}, true)

	---------------------------------------------------------------------------
	-- DRIVER SIDE
	local function openDriver(ctx)
		local DR = ctx.W.Drive
		if not (DR and DR.opts) then ctx:cannot("no Drive") end
		DR.opts().autoInvite = true
		if not (DR.Selling and DR.Selling()) then ctx:na("the driver is not open for business") end
		if ctx.W.InCombat and ctx.W.InCombat() then ctx:na("in combat from the start") end
		if ctx.me.player.group then ctx:na("already in a group") end
		ctx:advance(3)
		return DR
	end
	local function invitesTo(ctx, name) local n = 0 for _, i in ipairs(ctx.w.invites) do if key(i.to) == key(name) then n = n + 1 end end return n end
	local seq = 0
	local NAMES = { "Dan Miller", "Eve Stone", "Fay Wood", "Gil Moss", "Hal Reed", "Ida Frost", "Jon Vale", "Kay Pine", "Leo Marsh", "Mia Shaw", "Ned Cole", "Pat Gray" }
	local function bot(ctx)
		for _ = 1, #NAMES do
			seq = seq + 1
			local n = NAMES[((seq - 1) % #NAMES) + 1]
			if not ctx.w:player(n) then ctx.w:addBot(n, { spot = "Durotar", acceptsInvites = false }) return n end
		end
		ctx:cannot("no free bot name")
	end

	promise({
		id = "fix234.im_in_place_is_invited",
		text = "A buyer who whispers 'summon pls, I'm in <a place>' is invited once, as a rider who stands there; it is not read as a place to go to (also after a /reload).",
		source = "CHANGELOG 2.3.4: A rider who whispers \"I'm in the badlands\" (or any \"in the <place>\") is invited, not held as if they wanted to go there.",
		check = function(ctx)
			local DR = openDriver(ctx)
			local function try(place)
				local n = bot(ctx)
				local before = invitesTo(ctx, n)
				ctx.w:botWhisper(n, ctx.me, "summon pls, I'm in " .. place)
				ctx:advance(3)
				if invitesTo(ctx, n) - before < 1 then
					ctx:fail("A buyer whispers 'summon pls, I'm in " .. place .. "' to your open driver and is not invited.")
				end
			end
			try("the badlands")
			local one = DR.opts and DR.opts().oneAtATime
			if one then ctx:na("one rider at a time is on: the first buyer was invited, a second buyer rightly waits in the queue behind them") end
			try("the crossroads")
			ctx:reload()
			ctx:advance(6)
			DR = ctx.W.Drive
			if not (DR.Selling and DR.Selling()) then ctx:na("not open after the reload") end
			try("the barrens")
		end,
	})

	promise({
		id = "fix234.drive_log_zero_not_free",
		text = "/wuber drive log says 0c, never 'free', when you took no gold (also after a /reload).",
		source = "CHANGELOG 2.3.4: /wuber drive log shows 0c, not \"free\", when you took nothing.",
		check = function(ctx)
			local DR = openDriver(ctx)
			ctx:advance(900)
			local function look(when)
				local n = #ctx.me.chatLines
				ctx.me:slash("/wuber drive log")
				ctx:advance(1)
				local txt = table.concat(lines(ctx, n), "\n")
				if txt == "" then ctx:na("the command printed nothing here") end
				if txt:lower():find("free", 1, true) then
					ctx:fail("You took no gold and /wuber drive log " .. when .. " says free.", txt)
				end
			end
			look("")
			ctx:reload()
			ctx:advance(5)
			look("after a /reload")
		end,
	})

	promise({
		id = "fix234.why_command_after_reload",
		text = "After a login tip has shown and you /reload, /wuber why says the login tip does not come again after a /reload.",
		source = "CHANGELOG 2.3.4: /wuber why says \"Login tip: one shows when you log in, not again after a /reload. /wuber tips shows one now.\" after a /reload.",
		needs = { ride = "none", combat = "no" },
		when = function(sit) return sit.tips ~= "off" and sit.session ~= "first" and sit.session ~= "reload" end,
		check = function(ctx)
			local n = #ctx.me.chatLines
			ctx.me:slash("/wuber why")
			ctx:advance(1)
			if #lines(ctx, n) == 0 then ctx:fail("You type /wuber why and nothing is printed.") end
			-- let the login's tip show: open Wuber and wait
			if not (ctx.W.UI and ctx.W.UI.Toggle) then ctx:cannot("no UI toggle") end
			ctx.W.UI.Toggle(true)
			ctx:advance(12)
			local seenTips = ctx.W.db and ctx.W.db.tipsSeen
			if not (type(seenTips) == "table" and next(seenTips) ~= nil) then ctx:na("no login tip showed in this situation") end
			ctx:reload()
			ctx:advance(5)
			n = #ctx.me.chatLines
			ctx.me:slash("/wuber why")
			ctx:advance(1)
			local txt = table.concat(lines(ctx, n), "\n")
			if txt == "" then ctx:fail("You type /wuber why after a /reload and nothing is printed.") end
			local tipline = txt:match("Login tip:[^\n]*")
			if tipline and not tipline:find("not again after a /reload", 1, true) and not tipline:find("seen every tip", 1, true)
				and not tipline:find("off in Settings", 1, true) and not tipline:find("first%-open guide") then
				ctx:fail("A login tip already showed, you pressed /reload, and /wuber why says: " .. tipline)
			end
		end,
	}, false)

	promise({
		id = "fix234.drive_on_refused_in_plain_words",
		text = "/wuber drive on, when it is refused, says why in plain words, not a bare code such as 'lead.' or 'Can't open: lead.'.",
		source = "CHANGELOG 2.3.4: /wuber drive on and /wuber drive off say why they were refused in the Start button's plain words (they printed a code such as \"Can't open: lead.\").",
		needs = { role = "rider", ride = "none", combat = "no" },
		when = function(sit) return sit.role == nil or sit.role == "rider" end,
		check = function(ctx)
			local DR = ctx.W.Drive
			if not (DR and DR.SetOpen) then ctx:cannot("no Drive") end
			if DR.IsOpen and DR.IsOpen() then ctx:na("already open") end
			local c = #ctx.me.chatLines
			ctx.me:slash("/wuber drive on")
			ctx:advance(1)
			local out = lines(ctx, c)
			if DR.IsOpen and DR.IsOpen() then ctx:na("the player could open here") end
			if #out == 0 then ctx:fail("You type /wuber drive on, it is refused, and nothing is said.") end
			for _, l in ipairs(out) do
				if l:find("Can't open: %l+%.?%s*$") or l:find("^%s*%a*:?%s*%l+%.?%s*$") then ctx:fail("/wuber drive on is refused and prints a code instead of a reason.", l) end
			end
			ctx:note("it printed: " .. table.concat(out, " / "))
		end,
	})

	promise({
		id = "fix234.old_ask_not_invited_on_reopen",
		text = "A buyer who asked for a summon more than 15 minutes before you closed is not invited the moment you reopen.",
		source = "CHANGELOG 2.3.4: A rider who asked for a summon more than 15 minutes before you closed is no longer invited the moment you reopen.",
		check = function(ctx)
			local DR = openDriver(ctx)
			local n = bot(ctx)
			-- the rider asks while the driver is closed, then a long time passes, then he opens
			ctx.me:slash("/wuber drive close")
			ctx:advance(2)
			ctx.w:botWhisper(n, ctx.me, "summon pls")
			ctx:advance(3)
			ctx:advance(20 * 60)
			ctx:reload()
			ctx:advance(5)
			DR = ctx.W.Drive
			local before = invitesTo(ctx, n)
			ctx.me:slash("/wuber drive open")
			ctx:advance(15)
			if invitesTo(ctx, n) > before then
				ctx:fail("A buyer asked for a summon twenty minutes ago, you were closed, and the moment you reopen he is invited.")
			end
		end,
	})

	promise({
		id = "fix234.raid_cancel_words",
		text = "In raid summons, a raider who whispers 'nvm summon' or 'cancel summon' is taken off the list, running or paused, and 'no summon' never adds anyone.",
		source = "CHANGELOG 2.3.4: A raider who types \"nvm summon\" or \"cancel summon\" is taken off the raid summon list, \"no summon\" no longer adds them, and \"nvm\" also works while raid summons are paused.",
		check = function(ctx)
			local DR = openDriver(ctx)
			if not (DR.SetMode and DR.RaidAdd) then ctx:na("no raid module") end
			local names = { ctx.me.player.name }
			for _ = 1, 6 do names[#names + 1] = bot(ctx) end
			ctx.w:group(names)
			ctx:advance(10)
			if not DR.SetMode("raid") then ctx:na("raid mode refused here") end
			local okOpen, why = DR.SetOpen(true)
			if not okOpen then ctx:na("raid summons did not start here: " .. tostring(why)) end
			ctx:advance(5)
			local function queued(n) return DR.raidRows and DR.raidRows[key(n)] end
			local a, b, c = bot(ctx), bot(ctx), bot(ctx)
			ctx.w:botWhisper(a, ctx.me, "summon here")
			ctx.w:botWhisper(b, ctx.me, "summon here")
			ctx:advance(3)
			if not (queued(a) and queued(b)) then ctx:cannot("the raid roster of the fake game never lists the raiders (DR.units empty) when the runner is the leader of a made-up 7-player group: not built") end
			ctx.w:botWhisper(a, ctx.me, "nvm summon")
			ctx:advance(2)
			if queued(a) then ctx:fail("A raider whispers 'nvm summon' and is still on the raid summon list.") end
			ctx.w:botWhisper(c, ctx.me, "no summon")
			ctx:advance(2)
			if queued(c) then ctx:fail("A raider whispers 'no summon' and is put on the raid summon list.") end
			if DR.SetPaused and DR.SetPaused(true) then
				ctx:advance(2)
				ctx.w:botWhisper(b, ctx.me, "cancel summon")
				ctx:advance(2)
				DR.SetPaused(false)
				ctx:advance(3)
				if queued(b) then ctx:fail("A raider whispers 'cancel summon' while raid summons are paused and is still on the list after you resume.") end
			end
		end,
	})
end
