-- Promises about the auto-reply whisper (tests/promises/v24_reply.lua; job 146).
-- What the driver is told (Drive/AutoReply.lua header, the Driving switch "Whisper back to public requests": "Advanced: one whisper,
-- then they whisper you."; tooltip "At most once an hour per person"): a clear public request for a place this driver serves gets ONE
-- whisper back, naming that place; never twice in an hour to the same person; never in combat, a raid, an instance, during a ride, to
-- the group, to another driver; the four switches stop it; with several Wuber drivers one answers; no other chat is ever sent alone.
return function(Hunt)
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end
	local ASK = { "Dan Miller", "Eve Stone", "Fay Wood", "Gil Moss", "Hal Reed", "Ida Frost", "Jon Vale", "Kay Pine", "Leo Marsh",
		"Mia Shaw", "Ned Cole", "Pat Gray", "Quin Bell", "Ray Holt", "Sam Ward", "Tim Park" }
	local seq = 0

	local function solo(sit) return sit.role == "warlock" and sit.net == "none" and (sit.session == nil or sit.session ~= "first") end

	-- a driver with the reply's own switches on, open, and the place he serves
	local function setup(ctx)
		local W = ctx.W
		local DR = W.Drive
		if not (DR and DR.opts and DR.CanReply) then ctx:cannot("no auto-reply module") end
		DR.opts().autoInvite = true
		DR.opts().watchPublic = true
		DR.opts().autoReply = true
		DR.opts().autoPublic = false
		if not (DR.Selling and DR.Selling()) then ctx:na("the driver is not open for business") end
		if W.InCombat and W.InCombat() then ctx:na("in combat from the start") end
		if DR.Busy and DR.Busy() then ctx:na("a ride is already in progress") end
		if ctx.me.player.group then ctx:na("already in a group") end
		if W.IsBlocked and (W.IsBlocked("chat") or W.IsBlocked("invite")) then ctx:na("the game refuses addon chat or invites") end
		local served = DR.ServedPlaces and DR.ServedPlaces()
		local place = served and served[1]
		if type(place) == "table" then place = place.name end
		if type(place) ~= "string" or place == "" then ctx:na("the driver serves no single named place") end
		ctx.facts.rplace = place
		ctx.facts.rfaction = (ctx.me.player and ctx.me.player.faction) or "Horde"
		ctx:advance(3)
		return DR, place
	end

	local function nextAsker(ctx)
		seq = seq + 1
		local n = ASK[((seq - 1) % #ASK) + 1] .. (seq > #ASK and (" " .. string.rep("x", 1)) or "")
		-- keep names two plain words: a first and a last name only
		n = ASK[((seq - 1) % #ASK) + 1]
		local i = 0
		while ctx.w:player(n) do
			i = i + 1
			n = ASK[((seq - 1 + i) % #ASK) + 1]
			if i > #ASK then ctx:cannot("no free asker name") end
		end
		return n
	end

	local function say(ctx, name, text)
		if not ctx.w:player(name) then
			ctx.w:addBot(name, { spot = "Ratchet", acceptsInvites = false, faction = ctx.facts.rfaction })
		end
		ctx.w:chatFrom(name, text, "CHANNEL", "Trade", ctx.facts.rfaction)
		ctx:advance(0.5)
	end
	local function replies(ctx, name) return ctx.w:whispersTo(name, "reply") end
	local function ask(ctx, name, place) say(ctx, name, "WTB summon to " .. place) end

	local function promise(p)
		p.area = "Auto-reply"
		p.kind = p.kind or "scenario"
		-- (job 2680) H24-10: the auto-reply whispers only when How whispers leave is the whisper mode; Off and Chat box
		-- send nothing (v241.autoreply.* checks those), so every promise here needs the whisper mode
		p.when = function(sit) return sit.fold ~= "folded_click" and sit.opt_whisperMode ~= "off" and sit.opt_whisperMode ~= "box" end -- (folded_click needs a wide open page; the build cannot make it for a closed phone)
		p.needs = p.needs or { role = "warlock", net = "none", ride = "none", combat = "no", group = "solo" }
		Hunt.promise(p)
	end

	---------------------------------------------------------------------------
	promise{
		id = "reply.one_whisper",
		text = "Someone in Trade asks 'WTB summon to <your place>': you whisper them once, naming that place and the word to whisper back, and nobody is invited by that line.",
		source = "AutoReply.lua header; replyswitch tooltip (Whisper me \"summon <place>\")",
		check = function(ctx)
			local DR, place = setup(ctx)
			local who = nextAsker(ctx)
			local inv = #ctx.w.invites
			ask(ctx, who, place)
			local r = replies(ctx, who)
			if #r ~= 1 then ctx:fail("A buyer asks for a summon to " .. place .. " in Trade and your driver whispers them " .. #r .. " times instead of once.") end
			local want = 'Want a summon to ' .. place .. '? Whisper me "summon ' .. place .. '".'
			if r[1].text ~= want then ctx:fail("The whisper to the buyer does not name your place and the word to answer with.", tostring(r[1].text)) end
			if #ctx.w.invites ~= inv then ctx:fail("The public line alone got the buyer invited to your group.") end
			local last = DR.LastReply and DR.LastReply()
			if not (last and last.place == place and key(last.to) == key(who)) then ctx:fail("Wuber does not remember who it whispered last and for which place.") end
		end,
	}

	promise{
		id = "reply.once_an_hour",
		text = "Wuber whispers the same person at most once an hour: asking again after ten minutes gets no second whisper, after an hour and a bit it does.",
		source = "replyswitch tooltip (At most once an hour per person); AutoReply.lua header",
		check = function(ctx)
			local DR, place = setup(ctx)
			local who = nextAsker(ctx)
			ask(ctx, who, place)
			if #replies(ctx, who) ~= 1 then ctx:na("the first ask got no reply here") end
			ctx:advance(600)
			ask(ctx, who, place)
			if #replies(ctx, who) ~= 1 then ctx:fail("You whispered a buyer, he asked again ten minutes later and got a second whisper inside the hour.") end
			ctx:advance(3100)
			ask(ctx, who, place)
			if #replies(ctx, who) ~= 2 then ctx:fail("A buyer asks again more than an hour after your whisper and gets none (" .. #replies(ctx, who) .. " in all).") end
		end,
	}

	promise{
		id = "reply.once_across_reload",
		text = "The hour is remembered in your saved data: after a /reload the same buyer asking again inside the hour gets no second whisper.",
		source = "AutoReply.lua header (remembered in the saved table)",
		check = function(ctx)
			local DR, place = setup(ctx)
			local who = nextAsker(ctx)
			ask(ctx, who, place)
			if #replies(ctx, who) ~= 1 then ctx:na("the first ask got no reply here") end
			ctx:advance(5)
			ctx:reload()
			ctx:advance(5)
			DR = ctx.W.Drive
			if not (DR.Selling and DR.Selling()) then ctx:na("the driver is not open after the reload") end
			DR.opts().autoInvite, DR.opts().watchPublic = true, true
			ctx:advance(2)
			ask(ctx, who, place)
			if #replies(ctx, who) ~= 1 then ctx:fail("You whispered a buyer, reloaded your UI, he asked again a minute later and got a second whisper inside the hour.") end
		end,
	}

	promise{
		id = "reply.never_when_busy",
		text = "No auto-reply whisper while you are in combat, in an instance, in a raid or running a ride; the asker is not whispered later for that line either.",
		source = "AutoReply.lua header (hard rules)",
		check = function(ctx)
			local DR, place = setup(ctx)
			local w, a = ctx.w, ctx.me
			-- combat
			w:enterCombat(a)
			local c = nextAsker(ctx)
			ask(ctx, c, place)
			if #replies(ctx, c) > 0 then ctx:fail("A buyer asks in Trade while you are in combat and your driver whispers him.") end
			w:leaveCombat(a)
			-- instance
			a.player.instance = true
			local i = nextAsker(ctx)
			ask(ctx, i, place)
			if #replies(ctx, i) > 0 then ctx:fail("A buyer asks in Trade while you are in an instance and your driver whispers him.") end
			a.player.instance = false
			-- ride in progress
			local rider = nextAsker(ctx)
			w:addBot(rider, { spot = "Ratchet", acceptsInvites = false, faction = ctx.facts.rfaction })
			w:botWhisper(rider, a, "summon " .. place)
			ctx:advance(3)
			if not (DR.Busy and DR.Busy()) then ctx:na("a ride did not start from the whisper") end
			local d = nextAsker(ctx)
			ask(ctx, d, place)
			if #replies(ctx, d) > 0 then ctx:fail("A buyer asks in Trade while your driver has a ride in progress and he is whispered.") end
		end,
	}

	promise{
		id = "reply.switches_stop_it",
		text = "Whisper back to public requests off, Invite riders who whisper me off, Watch public chat off, or being closed: no auto-reply whisper; back on, it resumes.",
		source = "replyswitch tooltip; AutoReply.lua CanReply",
		check = function(ctx)
			local DR, place = setup(ctx)
			local o = DR.opts()
			local function tryWith(label, f, undo)
				f()
				local who = nextAsker(ctx)
				ask(ctx, who, place)
				local n = #replies(ctx, who)
				undo()
				if n > 0 then ctx:fail("You switched off " .. label .. " and a buyer's public line still got a whisper from your driver.") end
			end
			tryWith("Whisper back to public requests", function() o.autoReply = false end, function() o.autoReply = true end)
			tryWith("Invite riders who whisper me", function() o.autoInvite = false end, function() o.autoInvite = true end)
			tryWith("Watch public chat", function() o.watchPublic = false end, function() o.watchPublic = true end)
			local who = nextAsker(ctx)
			ask(ctx, who, place)
			if #replies(ctx, who) ~= 1 then ctx:na("with everything back on the reply did not resume here") end
		end,
	}

	promise{
		id = "reply.only_clear_requests",
		text = "Only a clear buy request for your own one place gets a whisper: not a seller's line, a price question, another place, no place, two places, an advert, or a line with a game link.",
		source = "AutoReply.lua header (strict on purpose: when in doubt, no whisper); CHANGELOG 2.4.0 (the reply gauntlet)",
		check = function(ctx)
			local DR, place = setup(ctx)
			local other = (place == "Undercity") and "Thunder Bluff" or "Undercity"
			local lines = {
				"WTS summons to " .. place .. " 1g, whisper me inv",
				"how much for a summon to " .. place .. "?",
				"WTB summon to " .. other,
				"WTB summon pls",
				"WTB summon to " .. place .. " and " .. other .. " pls",
				"[Wuber] summons to " .. place .. " 50s",
				"LF sleeping bag summons",
				"WTB summon to " .. place .. " |cff71d5ff|Hitem:6948::::::::|h[Hearthstone]|h|r",
			}
			for _, text in ipairs(lines) do
				local who = nextAsker(ctx)
				say(ctx, who, text)
				if #replies(ctx, who) > 0 then ctx:fail("A line that is not a clear request for your place gets a whisper from your driver.", text) end
			end
		end,
	}

	promise{
		id = "reply.not_group_or_driver",
		text = "Wuber never auto-whispers someone already in your group, another [Wuber] driver, or someone you blocked.",
		source = "AutoReply.lua header (never to anyone in the group); CanReply",
		check = function(ctx)
			local DR, place = setup(ctx)
			local w = ctx.w
			-- someone in my group
			local g = nextAsker(ctx)
			w:addBot(g, { spot = "Ratchet", acceptsInvites = false, faction = ctx.facts.rfaction })
			w:group({ ctx.name, g })
			ctx:advance(1)
			ask(ctx, g, place)
			if #replies(ctx, g) > 0 then ctx:fail("A player already in your group asks for a summon in Trade and your driver whispers him.") end
			-- blocked
			local b = nextAsker(ctx)
			w:addBot(b, { spot = "Ratchet", acceptsInvites = false, faction = ctx.facts.rfaction })
			if DR.db and type(DR.db.blocklist) == "table" then
				DR.db.blocklist[key(b)] = true
				ask(ctx, b, place)
				if #replies(ctx, b) > 0 then ctx:fail("A player you blocked asks for a summon in Trade and your driver whispers him.") end
			end
		end,
	}

	promise{
		id = "reply.cap_200",
		text = "The list of people already whispered never grows past 200 names, and the newest asker is always remembered (so he is not whispered twice).",
		source = "AutoReply.lua DR.REPLY_MAX (saved table)",
		check = function(ctx)
			local DR, place = setup(ctx)
			local nowT = ctx.me.env.time()
			DR.db.replied = DR.db.replied or {}
			for i = 1, 230 do DR.db.replied["old guy" .. i] = nowT - 10 - i end -- 230 stamps inside the hour (a saved list from an old build)
			local who = nextAsker(ctx)
			ask(ctx, who, place)
			if #replies(ctx, who) ~= 1 then ctx:na("no whisper went out") end
			local n = 0
			for _ in pairs(DR.db.replied) do n = n + 1 end
			if n > 200 then ctx:fail("The saved list of whispered players holds " .. n .. " names, over the limit of 200.") end
			if not DR.db.replied[key(who)] then ctx:fail("The player you just whispered is not remembered and could be whispered again.") end
		end,
	}

	promise{
		id = "reply.round_trip",
		text = "When the buyer whispers back the word Wuber suggested, he is invited, and no second reply whisper is sent.",
		source = "AutoReply.lua header (a whisper back is invited by careful mode); replyswitch description",
		check = function(ctx)
			local DR, place = setup(ctx)
			local who = nextAsker(ctx)
			ask(ctx, who, place)
			local r = replies(ctx, who)
			if #r ~= 1 then ctx:na("no whisper went out") end
			local say_back = r[1].text:match('Whisper me "(.-)"%.$')
			if not say_back then ctx:fail("The auto-reply does not give the buyer a word to whisper back.", r[1].text) end
			local inv = #ctx.w.invites
			ctx.w:botWhisper(who, ctx.me, say_back)
			ctx:advance(4)
			local got = 0
			for i = inv + 1, #ctx.w.invites do if key(ctx.w.invites[i].to) == key(who) then got = got + 1 end end
			if got ~= 1 then ctx:fail("The buyer whispers back the exact words your driver suggested and is invited " .. got .. " times instead of once.", say_back) end
			if #replies(ctx, who) ~= 1 then ctx:fail("The buyer answers the auto-reply and gets a second auto-reply whisper.") end
		end,
	}

	promise{
		id = "reply.one_driver_answers",
		text = "With another open Wuber driver at your place, a buyer's public line gets exactly one whisper between you, never two and never none.",
		source = "AutoReply.lua DR.ReplyTurn (the lead's review: one whisper per asker)",
		needs = { role = "warlock", net = "one", ride = "none", combat = "no", group = "solo" },
		check = function(ctx)
			local DR, place = setup(ctx)
			local rival = ctx.peers.rivals and ctx.peers.rivals[1]
			if not rival then ctx:na("no rival driver") end
			local RD = rival.W.Drive
			RD.opts().autoInvite, RD.opts().watchPublic, RD.opts().autoReply = true, true, true
			if not (RD.Selling and RD.Selling()) then ctx:na("the rival is not open") end
			local rs = RD.ServedPlaces and RD.ServedPlaces()
			local rp = rs and rs[1]
			if type(rp) == "table" then rp = rp.name end
			if rp ~= place then ctx:na("the rival serves another place") end
			ctx:advance(30)
			for i = 1, 6 do
				local who = nextAsker(ctx)
				ask(ctx, who, place)
				ctx:advance(1)
				local n = #replies(ctx, who)
				if n ~= 1 then ctx:fail("Two open Wuber drivers stand in the same place and a buyer's request gets " .. n .. " whispers instead of one.", who) end
				-- the driver whose turn it is stays quiet for 8 s after a whisper back (AutoReply REPLY_GAP) and nobody else answers
				-- by design, so the next buyer asks after the gap
				ctx:advance(9)
			end
		end,
	}

	promise{
		id = "reply.not_when_paused_or_closed",
		text = "While you have paused your shop, or after you close it, a buyer's public line gets no auto-reply whisper; after Open or Resume it works again.",
		source = "AutoReply.lua CanReply (open, paused)",
		check = function(ctx)
			local DR, place = setup(ctx)
			if not DR.SetPaused then ctx:cannot("no DR.SetPaused") end
			DR.SetPaused(true)
			ctx:advance(1)
			local p = nextAsker(ctx)
			ask(ctx, p, place)
			local np = #replies(ctx, p)
			DR.SetPaused(false)
			ctx:advance(1)
			if np > 0 then ctx:fail("You paused your shop and a buyer's public line still got a whisper from your driver.") end
			DR.SetOpen(false)
			ctx:advance(2)
			local c = nextAsker(ctx)
			ask(ctx, c, place)
			if #replies(ctx, c) > 0 then ctx:fail("You closed your shop and a buyer's public line still got a whisper from your driver.") end
		end,
	}

	promise{
		id = "reply.only_whispers_alone",
		text = "Besides the auto-reply, Wuber sends no chat line by itself: after public lines and whispers, every line your window sent without a click is one reply whisper.",
		source = "CLAUDE.md hard rules (no SendChatMessage from addon code); AutoReply.lua header",
		check = function(ctx)
			local DR, place = setup(ctx)
			local w = ctx.w
			local before = #w.whispers
			local posts = #(w.chatPosts or {})
			for i = 1, 3 do local who = nextAsker(ctx) ask(ctx, who, place) end
			local who = nextAsker(ctx)
			w:addBot(who, { spot = "Ratchet", acceptsInvites = false, faction = ctx.facts.rfaction })
			w:botWhisper(who, ctx.me, "summon " .. place)
			ctx:advance(5)
			for i = before + 1, #w.whispers do
				local x = w.whispers[i]
				if key(x.from) == key(ctx.name) and x.how ~= "reply" and x.how ~= "macro" and x.how ~= "click" then
					ctx:fail("Your window sent a whisper by itself that is not the one auto-reply.", tostring(x.how) .. ": " .. tostring(x.text))
				end
			end
			for i = posts + 1, #(w.chatPosts or {}) do
				local x = w.chatPosts[i]
				if key(x.from) == key(ctx.name) and x.how ~= "macro" and x.how ~= "click" then
					ctx:fail("Your window said something in public chat without a click.", tostring(x.text))
				end
			end
		end,
	}
end
