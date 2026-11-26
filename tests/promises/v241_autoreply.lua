-- Promises about "How whispers leave" and the auto-reply, and the chat box reminder (2.4.1 fixes H24-10, AU24-10, AU24-35).
-- Source: Settings "How whispers leave" (Off sends nothing; Chat box waits for your own Enter; the whisper mode sends by itself),
-- Drive/AutoReply.lua CanReply, Drive/Chat.lua (CHAT_MSG_WHISPER_INFORM marks the boxed line sent).
return function(Hunt)
	local ASK = { "Dan Miller", "Eve Stone", "Fay Wood", "Gil Moss", "Hal Reed", "Ida Frost", "Jon Vale", "Kay Pine" }
	local seq = 0

	local function setup(ctx, mode)
		local W = ctx.W
		local DR = W.Drive
		if not (DR and DR.opts and DR.CanReply) then ctx:cannot("no auto-reply module") end
		DR.opts().autoInvite = true
		DR.opts().watchPublic = true
		DR.opts().autoReply = true
		DR.opts().autoPublic = false
		DR.opts().whisperMode = mode
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
		for i = 0, #ASK do
			local n = ASK[((seq - 1 + i) % #ASK) + 1]
			if not ctx.w:player(n) then return n end
		end
		ctx:cannot("no free asker name")
	end
	local function ask(ctx, name, place)
		if not ctx.w:player(name) then
			ctx.w:addBot(name, { spot = "Ratchet", acceptsInvites = false, faction = ctx.facts.rfaction })
		end
		ctx.w:chatFrom(name, "WTB summon to " .. place, "CHANNEL", "Trade", ctx.facts.rfaction)
		ctx:advance(0.5)
	end
	local function replies(ctx, name) return ctx.w:whispersTo(name, "reply") end

	local function promise(p)
		p.area = "Auto-reply"
		p.kind = "scenario"
		p.needs = { role = "warlock", net = "none", ride = "none", combat = "no", group = "solo" }
		p.when = function(sit) return sit.fold ~= "folded_click" end
		Hunt.promise(p)
	end

	promise{
		id = "v241.autoreply.off_sends_nothing",
		text = "With How whispers leave set to Off, a buyer asking in Trade for your place is not whispered by Wuber, however long you wait.",
		source = "H24-10 (AutoReply.lua CanReply)",
		check = function(ctx)
			local DR, place = setup(ctx, "off")
			local who = nextAsker(ctx)
			ask(ctx, who, place)
			ctx:advance(30)
			local n = #replies(ctx, who)
			if n ~= 0 then ctx:fail("You set How whispers leave to Off, a buyer asked for " .. place .. " in Trade and Wuber whispered them anyway (" .. n .. " whisper).") end
		end,
	}

	promise{
		id = "v241.autoreply.box_sends_nothing",
		text = "With How whispers leave set to Chat box, Wuber never whispers a Trade buyer by itself (only your own Enter sends).",
		source = "H24-10 (AutoReply.lua CanReply)",
		check = function(ctx)
			local DR, place = setup(ctx, "box")
			local who = nextAsker(ctx)
			ask(ctx, who, place)
			ctx:advance(30)
			local n = #replies(ctx, who)
			if n ~= 0 then ctx:fail("You set How whispers leave to Chat box, a buyer asked for " .. place .. " in Trade and Wuber whispered them without your Enter (" .. n .. " whisper).") end
		end,
	}

	promise{
		id = "v241.autoreply.back_to_whisper_replies_again",
		text = "Guard: Off or Chat box stops the auto-reply, but switching How whispers leave back to the whisper mode makes the next buyer get exactly one reply naming your place.",
		source = "H24-10 guard (the whisper mode and the default still reply)",
		check = function(ctx)
			local DR, place = setup(ctx, "off")
			local a = nextAsker(ctx)
			ask(ctx, a, place)
			if #replies(ctx, a) ~= 0 then ctx:na("Off did not stop the reply here (see the Off promise)") end
			for _, mode in ipairs({ "auto", "macro", false }) do
				DR.opts().whisperMode = mode or nil
				-- r51 (HUNT F001/F002): replies to public asks wait DR.REPLY_GAP (8 s) between them (SEC-M2), so wait past it
				ctx:advance((tonumber(DR.REPLY_GAP) or 8) + 1)
				local b = nextAsker(ctx)
				ask(ctx, b, place)
				local n = #replies(ctx, b)
				if n ~= 1 then ctx:fail("You set How whispers leave back to the whisper mode (" .. tostring(mode or "default") .. ") and a buyer asking for " .. place .. " in Trade got " .. n .. " whispers instead of one.") end
			end
		end,
	}

	-- a reminder waiting in the chat box (the Chat box mode) for a rider who landed
	local function boxed(ctx)
		local DR = ctx.W.Drive
		if not (DR and DR.OpenBox and DR.Text) then ctx:cannot("no chat box module") end
		local who = nextAsker(ctx)
		if not ctx.w:player(who) then ctx.w:addBot(who, { spot = "Ratchet", acceptsInvites = false }) end
		ctx:advance(1)
		local c = { name = who, key = who:lower() }
		if DR.OpenBox(c, "pay") == false then ctx:na("no chat box to open here") end
		ctx:advance(1)
		return DR, c, who
	end

	promise{
		id = "v241.autoreply.box_other_whisper_not_the_reminder",
		text = "You open the pay reminder into the chat box but type something else to that rider and press Enter: the reminder is not counted as sent.",
		source = "AU24-10 (Chat.lua CHAT_MSG_WHISPER_INFORM compares the words)",
		check = function(ctx)
			local DR, c, who = boxed(ctx)
			ctx:advance(5)
			ctx.me:fire("CHAT_MSG_WHISPER_INFORM", "ok one sec", who)
			if c.reminded then ctx:fail("You opened the pay reminder in the chat box, whispered the rider something else, and Wuber counted the reminder as sent.") end
		end,
	}

	promise{
		id = "v241.autoreply.box_late_enter_counts",
		text = "You leave the pay reminder in the chat box, press Enter more than a minute later: it counts as sent and is not offered again.",
		source = "AU24-35 (Chat.lua; the box stays open until Enter or Escape)",
		check = function(ctx)
			local DR, c, who = boxed(ctx)
			ctx:advance(80)
			ctx.me:fire("CHAT_MSG_WHISPER_INFORM", DR.Text("pay", c), who)
			if not c.reminded then ctx:fail("You pressed Enter on the pay reminder 80 seconds after it went into the chat box and Wuber still counts it as unsent, so it is offered again.") end
		end,
	}

	promise{
		id = "v241.autoreply.box_prompt_enter_counts",
		text = "Guard: you press Enter at once on the pay reminder in the chat box: it counts as sent.",
		source = "AU24-10 guard (the line's own words)",
		check = function(ctx)
			local DR, c, who = boxed(ctx)
			ctx:advance(3)
			ctx.me:fire("CHAT_MSG_WHISPER_INFORM", DR.Text("pay", c), who)
			if not c.reminded then ctx:fail("You pressed Enter on the pay reminder in the chat box and Wuber does not count it as sent.") end
		end,
	}
end
