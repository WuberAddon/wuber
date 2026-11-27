-- Promises about riding and queue fixes of 2.4.1: a tap on a lead with whisper invites off (HUNT-122/123), the beacon for a rider who
-- booked from the advert alone (HUNT-125), a newer bounty replacing the older inside the gap (HUNT-128), Add by name (ING-02).
-- Each acts like a player (taps, whispers, waits) and checks the one thing the fix names.
return function(Hunt)
	local ASK = { "Dan Miller", "Eve Stone", "Fay Wood", "Gil Moss", "Hal Reed", "Ida Frost", "Jon Vale", "Kay Pine" }
	local seq = 0
	local function key(n) return (tostring(n):lower()) end

	local function free(ctx)
		seq = seq + 1
		for i = 0, #ASK do
			local n = ASK[((seq - 1 + i) % #ASK) + 1]
			if not ctx.w:player(n) then return n end
		end
		ctx:cannot("no free name")
	end

	local function need(ctx)
		local DR = ctx.W.Drive
		if not (DR and DR.opts and DR.Lead) then ctx:cannot("no Drive module") end
		if ctx.W.InCombat and ctx.W.InCombat() then ctx:na("in combat from the start") end
		if DR.Busy and DR.Busy() then ctx:na("a ride is already in progress") end
		if ctx.me.player.group then ctx:na("already in a group") end
		if ctx.W.IsBlocked and (ctx.W.IsBlocked("chat") or ctx.W.IsBlocked("invite")) then ctx:na("the game refuses addon chat or invites") end
		return DR
	end

	local function goOnline(ctx)
		local DR = need(ctx)
		if not (DR.Selling and DR.Selling()) then
			if ctx.W.Driver.SetOnline(true) == false then ctx:cannot("could not go online") end
			ctx:note("go online")
			ctx:advance(3)
		end
		if not (DR.Selling and DR.Selling()) then ctx:na("the driver is not open for business") end
		return DR
	end

	local function invitesTo(ctx, name)
		local n = 0
		for _, i in ipairs(ctx.w.invites or {}) do if key(i.to) == key(name) then n = n + 1 end end
		return n
	end

	local function bot(ctx, name)
		if not ctx.w:player(name) then
			ctx.w:addBot(name, { spot = "Ratchet", class = "MAGE", acceptsInvites = false, faction = (ctx.me.player and ctx.me.player.faction) or "Horde" })
		end
	end

	local function tapLead(ctx, DR, name)
		local c = DR.Lead(name, "anyone doing summons?", "whisper")
		if not (c and c.state == "lead") then ctx:cannot("no lead row was made") end
		ctx.w.hardware = ctx.me
		local ok, err = pcall(ctx.W.Driver.RowClick, c, "LeftButton")
		ctx.w.hardware = nil
		ctx:note("tap the lead " .. name)
		ctx:advance(1)
		if not ok then ctx:cannot("row tap threw: " .. tostring(err)) end
	end

	local function promise(p)
		p.area = p.area or "Queue"
		p.kind = "scenario"
		p.needs = p.needs or { role = "warlock", net = "none", ride = "none", combat = "no", group = "solo" }
		p.when = function(sit) return sit.fold ~= "folded_click" end
		Hunt.promise(p)
	end

	promise{
		id = "v241.rides.tap_lead_invites_whisper_invites_off",
		text = "With 'Invite riders who whisper me' off, one tap on a chat lead sends that player a group invite.",
		source = "HUNT-122 (Drive/Queue.lua tap on a lead)",
		check = function(ctx)
			local DR = goOnline(ctx)
			DR.opts().autoInvite = false
			local who = free(ctx)
			bot(ctx, who)
			tapLead(ctx, DR, who)
			local n = invitesTo(ctx, who)
			if n == 0 then ctx:fail("Invite riders who whisper me is off, you tap " .. who .. " on your lead list and nobody is invited.") end
		end,
	}

	promise{
		id = "v241.rides.tap_lead_invites_whisper_invites_on",
		text = "With 'Invite riders who whisper me' on, one tap on a chat lead still invites that player (once).",
		source = "HUNT-122 guard (the other value of the switch)",
		check = function(ctx)
			local DR = goOnline(ctx)
			DR.opts().autoInvite = true
			local who = free(ctx)
			bot(ctx, who)
			tapLead(ctx, DR, who)
			local n = invitesTo(ctx, who)
			if n == 0 then ctx:fail("Invite riders who whisper me is on, you tap " .. who .. " on your lead list and nobody is invited.") end
			if n > 1 then ctx:fail("You tap one lead once and " .. who .. " is invited " .. n .. " times.") end
		end,
	}

	promise{
		id = "v241.rides.no_auto_invite_counted_when_off",
		text = "With 'Invite riders who whisper me' off, a plain whisper from a player invites nobody and adds nothing to the automatic invites count.",
		source = "HUNT-123 (Drive/Queue.lua AutoRecord)",
		check = function(ctx)
			local DR = goOnline(ctx)
			if not DR.AutoRecord then ctx:cannot("no AutoRecord") end
			DR.opts().autoInvite = false
			local before = DR.AutoRecord()
			local who = free(ctx)
			bot(ctx, who)
			ctx.w:botWhisper(who, ctx.me, "summon pls")
			ctx:advance(5)
			if invitesTo(ctx, who) > 0 then ctx:fail("Invite riders who whisper me is off and " .. who .. " was invited by Wuber after a whisper.") end
			local after = DR.AutoRecord()
			if after ~= before then ctx:fail("Invite riders who whisper me is off, nobody was invited, and the automatic invites count went up by " .. tostring(after - before) .. ".") end
		end,
	}

	promise{
		id = "v241.rides.advert_only_rider_told_passphrase_flag",
		text = "With 'Show ride passphrase' on, a rider who booked from your advert alone (no beacon heard) is told that you show the passphrase.",
		source = "HUNT-125 (Net/Beacons.lua whispers the beacon to an accepted rider with no Q row)",
		check = function(ctx)
			local DR = goOnline(ctx)
			local W = ctx.W
			local rname = free(ctx)
			local r = ctx.w:addClient(rname, { spot = "Thunder Bluff", class = "MAGE", money = 10000, faction = (ctx.me.player and ctx.me.player.faction) or "Horde" })
			local Ch = r.W.Char and r.W.Char()
			if Ch then Ch.welcomed = true end
			ctx:advance(15)
			local drv = ctx.name
			if not (r.W.drivers and (r.W.drivers[key(drv)] or r.W.drivers[r.W.Key(drv) or ""])) then ctx:cannot("the rider never heard the driver's beacon") end
			ctx.w:splitChannel(r, "B") -- from now on only whispers reach the rider
			if not DR.SetOpt then ctx:cannot("no Drive.SetOpt") end
			DR.SetOpt("showPass", true)
			ctx:advance(1)
			local ok, why = r.W.RequestRide(drv)
			ctx:note(rname .. " books " .. drv)
			if not ok then ctx:cannot("the rider could not book: " .. tostring(why)) end
			local fb = W.Mod("Net.Base").fb
			if not (fb and fb.riders) then ctx:cannot("no rider book") end
			for k in pairs(fb.riders) do fb.riders[k] = nil end
			if not r.W.ride then ctx:cannot("the rider has no ride") end
			r.W.ride.showPass = nil
			local dd = r.W.drivers[key(drv)] or r.W.drivers[r.W.Key(drv) or ""]
			if dd then dd.showPass = nil end
			for _ = 1, 70 do
				for k in pairs(fb.riders) do fb.riders[k] = nil end
				ctx:advance(1)
			end
			if not (r.W.ride and r.W.ride.showPass == true) then
				ctx:fail("You show the ride passphrase and a rider who booked from your advert alone is never told (the rider's window does not know you show it).")
			end
		end,
	}

	promise{
		id = "v241.rides.newer_bounty_replaces_older",
		text = "When a rider changes their wish (another place) after half a minute, your demand list shows only the newer place, not both.",
		source = "HUNT-128 (Net/Bounty.lua CHANGE_GAP)",
		check = function(ctx)
			local W = ctx.W
			local BM = W.Mod("Net.Bounty")
			if not (BM and BM.heard and W.Bounty and W.Bounty.Demand) then ctx:cannot("no bounty module") end
			local fac = W.Faction()
			BM.heard("addr", "Wuber", "Wuber-Tester", { "Gadgetzan", 6000, fac, 10 })
			ctx:advance(35)
			BM.heard("addr", "Wuber", "Wuber-Tester", { "Ratchet", 6000, fac, 10 })
			local places, riders = {}, 0
			for _, row in ipairs(W.Bounty.Demand()) do places[row.place] = true riders = riders + (row.riders or 0) end
			if not places.Ratchet and not places.Gadgetzan then ctx:na("the bounty is not shown here (other faction or no demand list)") end
			if places.Gadgetzan or not places.Ratchet then ctx:fail("A rider changed their wish from Gadgetzan to Ratchet half a minute later and your demand list still shows the old wish (Gadgetzan).") end
			-- guard: the same wish repeated is not counted twice
			ctx:advance(35)
			BM.heard("addr", "Wuber", "Wuber-Tester", { "Ratchet", 6000, fac, 10 })
			local n = 0
			for _, row in ipairs(W.Bounty.Demand()) do n = n + (row.riders or 0) end
			if n ~= riders then ctx:fail("One rider repeated the same wish and your demand list counts " .. n .. " riders instead of " .. riders .. ".") end
		end,
		needs = { role = "warlock" },
	}

	promise{
		id = "v241.rides.add_by_name_refuses_non_names",
		text = "Add by name refuses what cannot be a character's name (spaces, dots, digits, one letter): no crew offer is made.",
		source = "ING-02 (Drive OfferCrew / ValidName)",
		area = "Crew",
		check = function(ctx)
			local DR = ctx.W.Drive
			if not (DR and DR.OfferCrew and DR.offers) then ctx:cannot("no crew module") end
			local bad = {}
			for _, name in ipairs({ "Anita Lift ...", "---", "...", "a.b", "Bob!!", "12345", "x" }) do
				local r = DR.OfferCrew(name)
				if r == true or DR.offers[ctx.W.Key(name) or "?"] then bad[#bad + 1] = name end
			end
			if #bad > 0 then ctx:fail("You type " .. bad[1] .. " in Add by name and Wuber sends a crew offer to it.", table.concat(bad, " | ")) end
		end,
	}

	promise{
		id = "v241.rides.no_player_named_drops_crew_offer",
		text = "When you add a name that is not online and the game says 'No player named', the waiting crew offer is dropped; a real online name still waits for its answer.",
		source = "ING-02 (CHAT_MSG_SYSTEM handler drops the waiting offer)",
		area = "Crew",
		check = function(ctx)
			local W = ctx.W
			local DR = W.Drive
			if not (DR and DR.OfferCrew and DR.offers) then ctx:cannot("no crew module") end
			if ctx.me.player.group then ctx:na("already in a group") end
			local ok = DR.OfferCrew("Nobodyhere")
			local k = W.Key("Nobodyhere")
			if not ok or not (DR.offers[k] and DR.offers[k].state == "waiting") then ctx:na("the crew offer did not wait here") end
			-- guard: another waiting offer for a name the game did not complain about stays
			local other = free(ctx)
			bot(ctx, other)
			local ok2 = DR.OfferCrew(other)
			local k2 = W.Key(other)
			ctx.me:chatEvent("CHAT_MSG_SYSTEM", "No player named 'Nobodyhere' is currently playing.")
			ctx:advance(1)
			if DR.offers[k] then ctx:fail("You add Nobodyhere, the game says no player of that name is playing, and the crew offer is still waiting.") end
			if ok2 and not DR.offers[k2] then ctx:fail("The game said 'No player named' about one name and the waiting offer to a different name was dropped too.") end
		end,
		needs = { role = "warlock" },
	}
end
