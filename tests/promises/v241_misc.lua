-- Promises for the 2.4.1 fixes of the audit round that no other promise file pins (tests/promises/v241_misc.lua).
-- AU24-09 price words are whole words; AU24-03 a buyer line with "whisper me" or "ready" is still a buyer; AU24-31 leaving a crew gives
-- back the service name, invite words, pause and who-casts; AU24-13 a bounty cancel survives /reload; AU24-06 only the summoning channel
-- is a portal helper; AU24-21 Add anyway on a full crew says the crew is full. Each acts like a player (a whisper, a click, a wait).
return function(Hunt)
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end
	local function DR(ctx) return ctx.W.Drive end
	local function noCombat(ctx) if ctx.me.player.combat then ctx:na("in combat") end end
	local function strip(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
	local SOLO = { role = "warlock", net = "none", ride = "none", group = "solo", combat = "no" }
	local function copy(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end

	---------------------------------------------------------------------------------------------------------------------
	-- AU24-09: price words
	local function asker(ctx, name, text)
		local DRm = DR(ctx)
		if not (DRm and DRm.customers and DRm.SetOpen) then ctx:cannot("no Drive module") end
		noCombat(ctx)
		if not ctx.w:player(name) then ctx.w:addBot(name, { spot = "Orgrimmar" }) end
		ctx.w:botWhisper(name, ctx.me, text)
		ctx:advance(2)
		return DRm.customers[key(name)]
	end
	local ASKERS = { "Dan Miller", "Eve Stone", "Fay Wood", "Gil Moss" }

	Hunt.promise{
		id = "v241.misc.price_words_whole",
		area = "Customers",
		text = "A whisper that asks for a summon and only has fee, cost or charge hidden inside another word (feel, costume, recharge) is not listed as asking the price.",
		source = "AU24-09 (price words match whole words only)",
		kind = "scenario",
		needs = SOLO,
		check = function(ctx)
			local lines = { "summon me pls, i feel stuck", "inv pls my feet hurt", "summon me pls nice costume", "inv pls i will recharge" }
			for i, text in ipairs(lines) do
				local c = asker(ctx, ASKERS[i], text)
				if not c then ctx:na("no row was made for: " .. text) end
				if c.wantsPrice then ctx:fail("Someone whispers '" .. text .. "' and the row says they ask the price, though they never asked about money.") end
			end
		end,
	}

	Hunt.promise{
		id = "v241.misc.price_question_still_read",
		area = "Customers",
		text = "A whisper that does ask how much, or what it costs, is still listed as asking the price.",
		source = "AU24-09 guard (the whole-word match still finds the real words)",
		kind = "scenario",
		needs = SOLO,
		check = function(ctx)
			local lines = { "summon me pls how much", "inv pls what is the cost", "summon me pls what do you charge" }
			for i, text in ipairs(lines) do
				local c = asker(ctx, ASKERS[i], text)
				if not c then ctx:na("no row was made for: " .. text) end
				if not c.wantsPrice then ctx:fail("Someone whispers '" .. text .. "' and the row does not say they ask the price.") end
			end
		end,
	}

	---------------------------------------------------------------------------------------------------------------------
	-- AU24-03: a buyer who says "whisper me" or "ready"
	local function careful(ctx, text)
		if not (DR(ctx) and DR(ctx).Careful) then ctx:cannot("no Careful gate") end
		return (DR(ctx).Careful(text, "public"))
	end
	local function servedName(ctx)
		local served = DR(ctx).ServedPlaces and DR(ctx).ServedPlaces()
		local p = served and served[1]
		if type(p) == "table" then p = p.name end
		if type(p) ~= "string" or p == "" then ctx:na("the driver serves no single named place") end
		return p:lower()
	end
	Hunt.promise{
		id = "v241.misc.buyer_whisper_me_is_buyer",
		area = "Auto-invite",
		text = "A Trade line that asks to buy a summon (wtb, lf) and ends 'whisper me' or 'ready' is still read as a buyer: Careful keeps it as a lead, so the Trade row shows.",
		source = "AU24-03 (Careful.lua, Places.PublicWant)",
		kind = "scenario",
		needs = SOLO,
		check = function(ctx)
			local pl = servedName(ctx)
			for _, l in ipairs({ "wtb summon to " .. pl .. ", whisper me", "LF summon to " .. pl .. ", whisper me", "wtb summon " .. pl .. ", ready now" }) do
				local r = careful(ctx, l)
				if r == "ignore" then ctx:fail("A buyer writes '" .. l .. "' in Trade and Careful ignores the line: no Trade row.") end
			end
			-- and the row itself: the line comes in over Trade chat
			local DRm = DR(ctx)
			DRm.opts().watchPublic = true
			local who = "Wanda Buyer"
			ctx.w:addBot(who, { spot = "Orgrimmar", acceptsInvites = false })
			ctx.w:chatFrom(who, "wtb summon to " .. pl .. ", whisper me", "CHANNEL", "Trade", ctx.me.player.faction or "Horde")
			ctx:advance(2)
			local seen = false
			for _, t in ipairs(ctx:texts()) do if strip(t):find(who, 1, true) then seen = true end end
			if not (seen or DRm.customers[key(who)]) then ctx:note("(no row seen for the Trade line: the build may not watch public chat here)") end
		end,
	}
	Hunt.promise{
		id = "v241.misc.seller_whisper_me_not_buyer",
		area = "Auto-invite",
		text = "A seller's line ('WTS summon to Orgrimmar, whisper me') and another driver's [Wuber] advert are still never read as a buyer.",
		source = "AU24-03 guard (sellers and [Wuber] lines were never buyers)",
		kind = "scenario",
		needs = SOLO,
		check = function(ctx)
			local pl = servedName(ctx)
			for _, l in ipairs({ "WTS summon to " .. pl .. ", whisper me", "selling summons " .. pl .. " ready, whisper me", "[Wuber] wtb summon to " .. pl .. ", whisper me" }) do
				local r = careful(ctx, l)
				if r ~= "ignore" then ctx:fail("A line '" .. l .. "' (an advert, not a buyer) is kept as a buyer in the Trade list.") end
			end
		end,
	}

	---------------------------------------------------------------------------------------------------------------------
	-- AU24-31: leaving a crew
	local function joinedCrew(ctx, own)
		local w = ctx.w
		local capName = "Captain Vale"
		if w:player(capName) then ctx:cannot("the captain's name is taken") end
		local cap = w:addClient(capName, { spot = ctx.me.player.zone and "Ratchet" or "Ratchet", class = "WARLOCK", shards = 10, money = 100000 })
		w:group({ ctx.name, capName })
		ctx:advance(5)
		local mine = ctx.W.Drive
		if not (mine.SetService and mine.SetOpt and mine.SetCaster and mine.LeaveCrew and mine.AnswerOffer) then ctx:cannot("no crew API") end
		if mine.char().captain and mine.char().captain ~= "" then ctx:na("already in a crew") end
		if own then own() end
		cap.W.Drive.OfferCrew(ctx.name)
		ctx:advance(2)
		-- the player taps Yes on the offer card
		local card = ctx.me.env.WuberCrewOffer
		if card and card.yes and ctx:visible(card.yes) then ctx.me:clickOn(card.yes) ctx:note("tap Yes on the crew offer") else mine.AnswerOffer(capName, true) end
		ctx:advance(6)
		if key(mine.char().captain or "") ~= key(capName) then ctx:cannot("the crew offer did not join") end
		return cap
	end
	Hunt.promise{
		id = "v241.misc.leave_crew_gives_back",
		area = "Crew",
		text = "You have your own service name, invite words and who-casts; you join a crew whose captain sets his own and pauses; when you leave the crew your own service, invite words and who-casts are back and your shop is not paused.",
		source = "AU24-31 (Team.lua KeepOwnConfig / RestoreOwnConfig)",
		kind = "scenario",
		needs = SOLO,
		check = function(ctx)
			local me = DR(ctx)
			local own
			local cap = joinedCrew(ctx, function()
				if not me.SetService("My Express") then ctx:cannot("could not set my service name") end
				me.SetOpt("keywords", "hop ride")
				me.SetCaster(ctx.name)
				own = me.char().caster
			end)
			local D = cap.W.Drive
			D.SetService("Fast Rides") D.SetOpt("keywords", "taxi portal") D.SetCaster("Captain Vale") D.SetPaused(true)
			ctx:advance(6)
			if me.char().service ~= "Fast Rides" then ctx:na("the captain's service name did not reach the member") end
			me.LeaveCrew()
			ctx:advance(6)
			local ch, o = me.char(), me.opts()
			if ch.service ~= "My Express" then ctx:fail("You leave a crew and your service name is '" .. tostring(ch.service) .. "', the captain's, not your own 'My Express'.") end
			local kw = type(o.keywords) == "table" and table.concat(o.keywords, " ") or tostring(o.keywords)
			if kw ~= "hop ride" then ctx:fail("You leave a crew and your invite words are '" .. kw .. "', the captain's, not your own 'hop ride'.") end
			if me.IsPaused() then ctx:fail("You leave a crew the captain had paused and your own shop is still paused.") end
			if ch.caster ~= own then ctx:fail("You leave a crew and your own 'who casts' is not back (it is '" .. tostring(ch.caster) .. "').") end
		end,
	}
	Hunt.promise{
		id = "v241.misc.leave_crew_keeps_own_pause",
		area = "Crew",
		text = "If your shop was paused before you joined a crew, it is paused again after you leave (the captain's open shop does not make you open).",
		source = "AU24-31 guard (paused is restored as it was)",
		kind = "scenario",
		needs = SOLO,
		check = function(ctx)
			local me = DR(ctx)
			local cap = joinedCrew(ctx, function() me.SetPaused(true) end)
			cap.W.Drive.SetPaused(false)
			ctx:advance(6)
			me.LeaveCrew()
			ctx:advance(6)
			if not me.IsPaused() then ctx:fail("You paused your shop, joined a crew, left it, and your shop is open again though you paused it.") end
		end,
	}

	---------------------------------------------------------------------------------------------------------------------
	-- AU24-13: a bounty cancel survives /reload
	local function bountyZeros(ctx)
		local n, all = 0, {}
		for _, e in ipairs(ctx.w.addonLog or {}) do
			if e.prefix == "WUBER" and e.result == 0 and not e.dropped and key(e.from or "") == key(ctx.name) and e.chatType == "CHANNEL"
				and type(e.text) == "string" and e.text:match("^W~") then
				local f = {}
				for p in (e.text .. "~"):gmatch("([^~]*)~") do f[#f + 1] = p end
				all[#all + 1] = f[4]
				if f[4] == "0" then n = n + 1 end
			end
		end
		return n, table.concat(all, ",")
	end
	Hunt.promise{
		id = "v241.misc.bounty_cancel_survives_reload",
		area = "Bounty",
		text = "You pin a bounty, cancel it, and /reload before the minute is up: drivers still hear the cancel, once, and the demand stops showing.",
		source = "AU24-13 (Bounty.lua, W.db.bountyCancel)",
		kind = "scenario",
		needs = { role = "rider", ride = "none", net = "none" },
		check = function(ctx)
			local B = ctx.W.Bounty
			if not (B and B.Pin and B.Cancel) then ctx:cannot("no bounty module") end
			if not B.Pin("Gadgetzan", 6000) then ctx:na("the bounty could not be pinned here") end
			ctx:advance(10)
			if not B.Cancel() then ctx:na("the bounty could not be cancelled here") end
			ctx:advance(1)
			ctx:reload()
			ctx:advance(140)
			local n, all = bountyZeros(ctx)
			if n == 0 then ctx:fail("You cancel your bounty, /reload within the minute, and drivers never hear the cancel (sent: " .. all .. ").") end
			if n > 1 then ctx:fail("You cancel your bounty and /reload, and the cancel goes out " .. n .. " times.") end
			ctx:advance(200)
			local n2 = bountyZeros(ctx)
			if n2 > 1 then ctx:fail("The kept cancel goes out again later (" .. n2 .. " times).") end
		end,
	}

	---------------------------------------------------------------------------------------------------------------------
	-- AU24-06: portal helpers
	local function ritualRide(ctx)
		noCombat(ctx)
		local w = ctx.w
		-- two group mates: whichever one the queue picks as the rider, the other is a helper
		w:addBot("Bob Helper", { spot = "Ratchet" })
		w:addBot("Carl Helper", { spot = "Ratchet" })
		w:group({ ctx.name, "Bob Helper", "Carl Helper" })
		ctx:advance(1)
		local me = ctx.me
		local helped = {}
		ctx.W.Listen("DRIVE_RITUAL", function(_, phase, data)
			if phase == "h" and type(data) == "table" then helped[#helped + 1] = tostring(data.helperName or data.helper) end
		end)
		w:addBot("Dan Moss", { spot = "Orgrimmar" })
		w:botWhisper("Dan Moss", me, "summon pls")
		ctx:advance(3)
		local b = me.env.WuberDriveButton
		if not (b and ctx:visible(b)) then ctx:na("the big button is not shown") end
		pcall(me.click, me, b)
		ctx:note("click the big button")
		ctx:advance(1)
		-- a card over the button (What's new, Wrapped) can take the tap: then no summon began and there is no channel to help with
		if not (ctx.W.Drive.Busy and ctx.W.Drive.Busy()) then ctx:na("the tap did not start a summon here") end
		local tok = {}
		for i = 1, 4 do
			local n = ctx.W.UnitName("party" .. i)
			if n == "Bob Helper" or n == "Carl Helper" then tok[#tok + 1] = "party" .. i end
		end
		if #tok < 2 then ctx:cannot("no party tokens for the helpers") end
		return helped, tok
	end
	local function holds(ctx, toks, spell)
		for i, tok in ipairs(toks) do ctx.me:fire("UNIT_SPELLCAST_CHANNEL_START", tok, "Mate-" .. i, spell) end
		ctx:advance(3)
		for i, tok in ipairs(toks) do ctx.me:fire("UNIT_SPELLCAST_CHANNEL_STOP", tok, "Mate-" .. i, spell) end
		ctx:advance(3)
	end
	local function credited(helped) for _, h in ipairs(helped) do if h:lower():find("helper", 1, true) then return true end end return false end
	Hunt.promise{
		id = "v241.misc.other_channel_not_helper",
		area = "Summon",
		text = "A group mate who channels some other spell for 3 seconds while your summon channel runs is not counted as a portal helper.",
		source = "AU24-06 (Cast.lua: only the summoning channel counts)",
		kind = "scenario",
		needs = SOLO,
		check = function(ctx)
			local helped, tok = ritualRide(ctx)
			holds(ctx, tok, 15407)
			if credited(helped) then ctx:fail("A group mate channels Mind Flay for 3 seconds and Wuber credits him as a portal helper.") end
		end,
	}
	Hunt.promise{
		id = "v241.misc.summon_channel_is_helper",
		area = "Summon",
		text = "A group mate who holds the summoning channel for 3 seconds while you summon is counted as a portal helper.",
		source = "AU24-06 guard (the real channel still counts)",
		kind = "scenario",
		needs = SOLO,
		check = function(ctx)
			local helped, tok = ritualRide(ctx)
			holds(ctx, tok, 698)
			if not credited(helped) then ctx:fail("A group mate holds the summoning channel for 3 seconds and is not credited as a portal helper.") end
		end,
	}

	---------------------------------------------------------------------------------------------------------------------
	-- AU24-21: Add anyway on a full crew
	Hunt.promise{
		id = "v241.misc.add_anyway_full_crew",
		area = "Crew",
		text = "Your crew is full (eight beside you) and you click Add anyway on a ninth person: Wuber says the crew is full, and never that he was added.",
		source = "AU24-21 (UI/Driver/Crew.lua)",
		kind = "scenario",
		needs = SOLO,
		check = function(ctx)
			local W, me = ctx.W, ctx.me
			local D = DR(ctx)
			if not (D.AddPlainHelper and D.CREW_MAX and W.Driver and W.Driver.ShowScreen) then ctx:cannot("no crew API") end
			local extra = "Ninth Guy"
			ctx.w:addBot(extra, { spot = "Ratchet", class = "WARRIOR" })
			ctx.w:group({ ctx.name, extra })
			ctx:advance(3)
			for i = 1, D.CREW_MAX do
				if not D.AddPlainHelper("Helper " .. string.char(96 + i) .. "x", nil) then ctx:cannot("helper " .. i .. " did not fit") end
			end
			local k = W.Key(extra)
			D.offers[k] = { name = extra, at = me.env.GetTime(), state = "noapp" }
			local seen = {}
			local orig = W.UI.Toast
			W.UI.Toast = function(text, kind, onClick) seen[#seen + 1] = strip(text) return orig(text, kind, onClick) end
			W.Char().wizard = true
			W.UI.Toggle(true)
			ctx:advance(2.5)
			pcall(me.clickText, me, "Drive")
			ctx:note("open the Drive tab")
			ctx:advance(1)
			W.Driver.ShowScreen("crew")
			ctx:advance(1)
			local s = W.Mod("UI.Driver.Screens").st.screens.crew
			s.update()
			local row
			for i = 1, 12 do
				local r = s.others.get(i)
				if r and ctx:visible(r) and r.person and W.Key(r.person.name) == k then row = r break end
			end
			if not (row and row.anyway) then W.UI.Toast = orig ctx:na("the ninth person has no Add anyway button here") end
			me:clickOn(row.btn)
			ctx:note("click Add anyway on " .. extra)
			ctx:advance(1)
			W.UI.Toast = orig
			local full, added = false, false
			for _, t in ipairs(seen) do
				if t:lower():find("full", 1, true) then full = true end
				if t:find("added as a helper", 1, true) then added = t end
			end
			if added then ctx:fail("You click Add anyway on a full crew and Wuber says '" .. added .. "', but he was not added.") end
			if not full then ctx:fail("You click Add anyway on a full crew and nothing says the crew is full (" .. (#seen == 0 and "no message" or table.concat(seen, " | ")) .. ").") end
		end,
	}
end
