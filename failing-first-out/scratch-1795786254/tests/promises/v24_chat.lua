-- Promises about chat reading, leads and the hidden channel (2.4): who counts as a buyer in public chat and whispers, the
-- chat lock, and the hidden channel's password. Logic only (what happens, what is sent, what is saved). Owner: job 146.
-- What the player is told: CLAUDE.md "a line tagged [Wuber] is another driver's advert, never a buyer"; the 2.4 notes
-- "A chat line with a linked item or spell is never read as a ride request", "A password on Wuber's hidden channel: the
-- channel's owner clears it by itself. If you cannot join because of one, Wuber says 'The Wuber channel has a password;
-- requests still work by whisper.' and no longer talks about 10 channels", and the auto-reply note (once an hour per
-- person, never in combat, never to anyone in your group).
return function(Hunt)
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end
	local U = dofile("tests/hunt/lib/universal_util.lua") -- (U.asClick: a stand-in for a click that the universal send check sees as one)
	local function DRof(ctx) return ctx.W.Drive end

	-- the driver, open at his place with the public reader and the invites on (as a player leaves them)
	local function driverReady(ctx)
		local DR = DRof(ctx)
		if not (DR and DR.Careful and DR.opts) then ctx:cannot("no Drive module") end
		if not ctx.W.Drive.IsOpen or not DR.IsOpen() then
			if DR.SetOpen then DR.SetOpen(true) end
			ctx:advance(3)
		end
		DR.opts().autoInvite = true
		DR.opts().watchPublic = true
		ctx:advance(1)
		return DR
	end
	local function place(ctx, DR)
		local d = DR.Dest and DR.Dest() or "Ratchet"
		if type(d) ~= "string" or d == "" then ctx:na("no destination") end
		return d
	end
	local function bot(ctx, name)
		local fac = (ctx.me.player and ctx.me.player.faction) or "Horde"
		ctx.w:addBot(name, { spot = "Ratchet", acceptsInvites = false, faction = fac })
		return fac
	end
	local function say(ctx, name, text)
		local fac = bot(ctx, name)
		ctx.w:chatFrom(name, text, "CHANNEL", "Trade", fac)
		ctx:advance(1)
	end
	local function leadOrInvite(ctx, DR, name, nInv0)
		local row = DR.customers and DR.customers[key(name)]
		return row ~= nil or #ctx.w.invites > nInv0
	end
	local function drivers(sit) return sit.role == "warlock" end
	local function inCombat(ctx) return ctx.me.player.combat and true or false end
	-- (job 146) only MY window's reply whispers: a rival Wuber driver in the world (the net dial) may rightly answer the
	-- same asker when I cannot (in combat) or when it is his turn
	local function myReplies(ctx, name)
		local out = {}
		for _, x in ipairs(ctx.w:whispersTo(name, "reply")) do if x.from == ctx.name then out[#out + 1] = x end end
		return out
	end

	local TAGS = { "[Wuber]", "[WUBER]", "[wuber]" }
	local LINKS = {
		"|cff9d9d9d|Hitem:12345::::::::60:::::|h[Portal Scroll]|h|r",
		"|cff71d5ff|Hspell:23161|h[Summon Dreadsteed]|h|r",
		"|cffffff00|Hquest:123:60|h[A Quest]|h|r",
		"|cffffd000|Hachievement:6:0:0:0:0:0:0:0:0:0|h[Level 10]|h|r",
		"|cffffd000|Henchant:7418|h[Enchant Bracer]|h|r",
		"|cffffd000|Htrade:2259:1:1|h[Alchemy]|h|r",
	}

	---------------------------------------------------------------------------
	Hunt.promise{
		id = "chatv.wuber_tag_never_buyer",
		area = "Chat reading",
		text = "A public line tagged [Wuber] is another driver's advert: it is never a lead, never an invite and never gets a reply, however it asks.",
		source = "CLAUDE.md hard rules (Only [Wuber] drivers...; a line tagged [Wuber] is never a buyer)",
		kind = "scenario",
		needs = { role = "warlock" },
		when = drivers,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			local DR = driverReady(ctx)
			local dest = place(ctx, DR)
			local tag = ctx.rng:pick(TAGS)
			local lines = {
				tag .. " Summons to " .. dest .. ", whisper me",
				"WTB summon to " .. dest .. " pls " .. tag,
				"need a summon to " .. dest .. "? " .. tag,
			}
			local inv0 = #ctx.w.invites
			for i, line in ipairs(lines) do
				local name = "Taggy" .. string.char(64 + i) .. " Test"
				say(ctx, name, line)
				if leadOrInvite(ctx, DR, name, inv0) then
					ctx:fail("Another driver's advert tagged " .. tag .. " is in public chat and it shows up as a lead or gets an invite.", line)
				end
				if #ctx.w:whispersTo(name, "reply") > 0 then
					ctx:fail("Another driver's advert tagged " .. tag .. " is in public chat and you whisper the sender a reply.", line)
				end
				local v = DR.Careful(line, "public", name)
				if v ~= "ignore" then ctx:fail("A public line tagged " .. tag .. " is read as '" .. tostring(v) .. "' instead of being ignored.", line) end
			end
		end,
	}

	Hunt.promise{
		id = "chatv.wuber_tag_whisper_never_invited",
		area = "Chat reading",
		text = "A whisper that is another driver's [Wuber] advert never gets the sender invited by itself.",
		source = "CLAUDE.md hard rules (a line tagged [Wuber] is never a buyer)",
		kind = "scenario",
		needs = { role = "warlock" },
		when = drivers,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			local DR = driverReady(ctx)
			local dest = place(ctx, DR)
			local line = "[Wuber] Summons to " .. dest .. " for 50s, whisper me"
			local v, why = DR.Careful(line, "whisper", "Rival Driver")
			if v == "invite" then
				ctx:fail("Another driver's tagged advert arrives as a whisper and you invite the sender at once.", line .. " -> " .. tostring(why))
			end
		end,
	}

	Hunt.promise{
		id = "chatv.link_line_never_buyer",
		area = "Chat reading",
		text = "A public line carrying a game link (item, spell, quest, achievement, enchant, trade skill) is never a lead, an invite or a reply.",
		source = "2.4 notes: A chat line with a linked item or spell is never read as a ride request",
		kind = "scenario",
		needs = { role = "warlock" },
		when = drivers,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			local DR = driverReady(ctx)
			local dest = place(ctx, DR)
			local link = ctx.rng:pick(LINKS)
			local forms = {
				link .. " wtb summon to " .. dest .. " pls",
				"WTB summon to " .. dest .. " pls " .. link,
				"anyone summon to " .. dest .. "? " .. link .. " thx",
			}
			local inv0 = #ctx.w.invites
			for i, line in ipairs(forms) do
				local name = "Linker" .. string.char(64 + i) .. " Test"
				say(ctx, name, line)
				if leadOrInvite(ctx, DR, name, inv0) then
					ctx:fail("Someone says a summon wish in public chat with an item or spell link in the line and it becomes a lead or an invite.", line)
				end
				if #ctx.w:whispersTo(name, "reply") > 0 then
					ctx:fail("Someone says a summon wish in public chat with a game link in the line and you whisper them a reply.", line)
				end
			end
		end,
	}

	Hunt.promise{
		id = "chatv.link_whisper_still_read",
		area = "Chat reading",
		text = "A whisper to you that has a game link in it is still read as a request (a lead or an invite): only public lines drop for a link.",
		source = "tests/v24/f3_d_linkline_test.lua (the link is only a part of the text in a whisper)",
		kind = "scenario",
		needs = { role = "warlock" },
		when = drivers,
		check = function(ctx)
			local DR = driverReady(ctx)
			local dest = place(ctx, DR)
			local line = ctx.rng:pick(LINKS) .. " summon to " .. dest .. " please"
			local v, why = DR.Careful(line, "whisper", "Dan Miller")
			if v == "ignore" then
				ctx:fail("Someone whispers you a summon request with a link in it and you drop it without even a lead.", line .. " -> " .. tostring(why))
			end
		end,
	}

	Hunt.promise{
		id = "chatv.seller_never_buyer",
		area = "Chat reading",
		text = "A seller's advert (WTS, selling, whisper me) in public chat is never read as a buyer, even if it names your place.",
		source = "tests/chatlines/misread.txt",
		kind = "scenario",
		needs = { role = "warlock" },
		when = drivers,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			local DR = driverReady(ctx)
			local dest = place(ctx, DR)
			local lines = {
				"WTS summons to " .. dest .. " 1g, whisper me inv",
				"WTS summon to " .. dest .. " 1g, w me",
				"Selling portals to " .. dest .. " cheap, pst",
				"WTS " .. dest .. " summon, WTB mage portal to SW",
			}
			local inv0 = #ctx.w.invites
			for i, line in ipairs(lines) do
				local name = "Seller" .. string.char(64 + i) .. " Test"
				say(ctx, name, line)
				if leadOrInvite(ctx, DR, name, inv0) then
					ctx:fail("A seller advertises summons to your place in public chat and Wuber lists or invites him as a buyer.", line)
				end
			end
		end,
	}

	Hunt.promise{
		id = "chatv.reply_once_an_hour",
		area = "Chat reading",
		text = "Wuber whispers a person who clearly asks for a summon to your place at most once an hour.",
		source = "2.4 notes: At most once an hour per person",
		kind = "scenario",
		needs = { role = "warlock" },
		when = drivers,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			local DR = driverReady(ctx)
			local dest = place(ctx, DR)
			local name = "Repeat Buyer"
			local line = "WTB summon to " .. dest
			say(ctx, name, line)
			local first = #myReplies(ctx, name)
			if first == 0 then ctx:na("no auto-reply in this situation") end
			for i = 1, 3 do
				ctx:advance(ctx.rng:int(600))
				ctx.w:chatFrom(name, line, "CHANNEL", "Trade", ctx.me.player.faction or "Horde")
				ctx:advance(1)
			end
			local n = #myReplies(ctx, name)
			local elapsed = 0
			if n > 1 then
				ctx:fail("A player asks for a summon in public chat again and again within the hour and Wuber whispers them " .. n .. " times.", "whispers: " .. n)
			end
		end,
	}

	Hunt.promise{
		id = "chatv.reply_never_in_combat",
		area = "Chat reading",
		text = "Wuber sends no reply whisper while you are in combat.",
		source = "2.4 notes: Never in combat, in a raid, in an instance or during a ride",
		kind = "scenario",
		needs = { role = "warlock" },
		when = drivers,
		check = function(ctx)
			local DR = driverReady(ctx)
			local dest = place(ctx, DR)
			if not ctx.w.enterCombat then ctx:cannot("the fake game has no combat") end
			ctx.w:enterCombat(ctx.me)
			ctx:note("I am in combat")
			say(ctx, "Combat Buyer", "WTB summon to " .. dest)
			local n = #myReplies(ctx, "Combat Buyer")
			ctx.w:leaveCombat(ctx.me)
			if n > 0 then ctx:fail("You are in combat and Wuber whispers a buyer in public chat.", "whispers: " .. n) end
		end,
	}

	Hunt.promise{
		id = "chatv.reply_never_to_group",
		area = "Chat reading",
		text = "Wuber sends no reply whisper to someone who is already in your group.",
		source = "2.4 notes: never to anyone in your group",
		kind = "scenario",
		needs = { role = "warlock" },
		when = drivers,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("combat") end
			local DR = driverReady(ctx)
			local dest = place(ctx, DR)
			if not ctx.w.group then ctx:cannot("the fake game cannot group") end
			local name = "Grouped Buyer"
			local fac = (ctx.me.player and ctx.me.player.faction) or "Horde"
			ctx.w:addClient(name, { spot = "Ratchet", faction = fac }) -- a real second client, so the group member has a name
			ctx.w:group({ ctx.name, name })
			ctx:advance(2)
			if not ctx.me.player.group then ctx:cannot("no group made") end
			ctx.w:chatFrom(name, "WTB summon to " .. dest, "CHANNEL", "Trade", ctx.me.player.faction or "Horde")
			ctx:advance(1)
			local n = #myReplies(ctx, name)
			if n > 0 then ctx:fail("Someone already in your group asks for a summon in public chat and Wuber whispers them.", "whispers: " .. n) end
		end,
	}

	---------------------------------------------------------------------------
	-- the chat lock
	local function inChannel(ctx)
		if not (ctx.W.OnNetwork and ctx.W.OnNetwork()) then ctx:na("not in the hidden channel") end
	end
	local function backlog(ctx)
		ctx:advance(30) -- the login quiet time is over, the outbox empty
	end

	Hunt.promise{
		id = "chatv.chat_lock_holds_and_sends",
		area = "Chat reading",
		text = "While the game's chat is locked, Wuber's messages are kept (never lost, never counted as a failure to send) and all go out once the lock ends.",
		source = "Net/Transport.lua header; tests/v24/f3_a_chatlock_test.lua",
		kind = "scenario",
		when = function(sit) return sit.net ~= "none" end,
		check = function(ctx)
			inChannel(ctx)
			backlog(ctx)
			local W = ctx.W
			if W.QueueLength() ~= 0 then ctx:na("the outbox is busy") end
			ctx.me.chatLock = true
			local sent0 = W.net.sent
			local n = ctx.rng:int(6) + 1
			for i = 1, n do U.asClick(ctx, function() W.SendTo("Tina Trial", "S", i, "invited") end) end
			ctx:advance(20)
			ctx:note("the chat is locked for 20 seconds, " .. n .. " messages queued")
			if W.net.sent ~= sent0 then
				ctx:fail("The game's chat is locked and Wuber's messages go out anyway.", "sent " .. tostring(W.net.sent - sent0))
			end
			if (W.net.hardFails or 0) > 0 or W.net.cantSend then
				ctx:fail("The game's chat is locked for 20 seconds and Wuber decides this account cannot send.", "hardFails " .. tostring(W.net.hardFails))
			end
			ctx.me.chatLock = false
			ctx:advance(15)
			if W.QueueLength() ~= 0 then
				ctx:fail("The lock ended 15 seconds ago and " .. W.QueueLength() .. " of Wuber's messages are still waiting.", "queue " .. W.QueueLength())
			end
		end,
	}

	Hunt.promise{
		id = "chatv.boss_fight_never_lost",
		area = "Chat reading",
		text = "Messages queued during a boss fight are sent after it ends, none lost.",
		source = "Net/Transport.lua (ENCOUNTER_START to ENCOUNTER_END holds sends)",
		kind = "scenario",
		when = function(sit) return sit.net ~= "none" end,
		check = function(ctx)
			inChannel(ctx)
			backlog(ctx)
			local W = ctx.W
			if W.QueueLength() ~= 0 then ctx:na("the outbox is busy") end
			ctx.me.env.C_ChatInfo.InChatMessagingLockdown = nil
			ctx.me:fire("ENCOUNTER_START", 1, "Boss", 1, 5)
			local before = #ctx.w.addonLog
			local n = ctx.rng:int(5) + 1
			for i = 1, n do U.asClick(ctx, function() W.SendTo("Tina Trial", "S", i, "invited") end) end
			ctx:advance(ctx.rng:int(120))
			ctx.me:fire("ENCOUNTER_END", 1, "Boss", 1, 5, 1)
			ctx:advance(20)
			if W.QueueLength() ~= 0 then
				ctx:fail("A boss fight ended 20 seconds ago and " .. W.QueueLength() .. " of Wuber's messages never left.", "queue " .. W.QueueLength())
			end
			if #ctx.w.addonLog - before < n then
				ctx:fail("You queue " .. n .. " messages in a boss fight and fewer than that arrive after it.", "arrived " .. (#ctx.w.addonLog - before))
			end
		end,
	}

	---------------------------------------------------------------------------
	-- the hidden channel's password
	local LOCKED = "The Wuber channel has a password; requests still work by whisper."
	local OLD = "10 chat channels"
	local function capture(W)
		local lines = {}
		local real = W.Print
		W.Print = function(s, ...) lines[#lines + 1] = tostring(s); return real(s, ...) end
		return lines
	end
	local function anyLine(lines, text)
		for _, s in ipairs(lines) do if s:find(text, 1, true) then return true end end
		return false
	end

	Hunt.promise{
		id = "chatv.password_join_says_so",
		area = "Chat reading",
		text = "If you cannot join the Wuber channel because it has a password, Wuber says so and does not talk about 10 channels.",
		source = "2.4 notes: A password on Wuber's hidden channel",
		kind = "scenario",
		when = function(sit) return sit.net ~= "none" end,
		check = function(ctx)
			inChannel(ctx)
			if not ctx.w.leaveChannel then ctx:cannot("the fake game cannot leave a channel") end
			local ch = ctx.w.channels["wubernet"]
			if not ch then ctx:cannot("no channel record") end
			ctx.w:leaveChannel(ctx.me, "WuberNet")
			ch.password = "secret"
			local lines = capture(ctx.W)
			ctx:note("a stranger put a password on the channel while I was out")
			ctx:advance(200)
			if ctx.W.OnNetwork() then ctx:na("joined all the same") end
			if not anyLine(lines, LOCKED) then
				ctx:fail("You cannot join the Wuber channel because of a password and Wuber never says so.", table.concat(lines, " | "))
			end
			if anyLine(lines, OLD) then
				ctx:fail("You cannot join the Wuber channel because of a password and Wuber blames having 10 channels.", table.concat(lines, " | "))
			end
		end,
	}

	local function owner(ctx)
		inChannel(ctx)
		ctx.w:setChannelOwner("WuberNet", ctx.me)
	end

	Hunt.promise{
		id = "chatv.owner_clears_password",
		area = "Chat reading",
		text = "When you own the Wuber channel and someone puts a password on it, you clear it by yourself, also after a /reload.",
		source = "2.4 notes: the channel's owner clears it by itself",
		kind = "scenario",
		when = function(sit) return sit.net ~= "none" end,
		check = function(ctx)
			inChannel(ctx)
			if ctx.rng:chance(0.5) then
				ctx:reload()
				ctx:advance(30)
				ctx:note("a /reload first")
				inChannel(ctx)
			end
			owner(ctx)
			ctx.w:setChannelPassword("WuberNet", "secret", "Stranger")
			ctx:advance(5)
			local ch = ctx.w.channels["wubernet"]
			if ch.password ~= nil then
				ctx:fail("You own the Wuber channel, a stranger puts a password on it, and five seconds later it still has one.", "password " .. tostring(ch.password))
			end
		end,
	}

	Hunt.promise{
		id = "chatv.password_not_owner_left_alone",
		area = "Chat reading",
		text = "If you do not own the Wuber channel, you never touch its password.",
		source = "2.4 notes; Net/Base.lua channelPassword",
		kind = "scenario",
		when = function(sit) return sit.net ~= "none" end,
		check = function(ctx)
			inChannel(ctx)
			ctx.w:setChannelOwner("WuberNet", nil)
			ctx.w:setChannelPassword("WuberNet", "secret", "Stranger")
			ctx:advance(60)
			if (ctx.me.passwordClears or 0) > 0 then
				ctx:fail("You are only a member of the Wuber channel and Wuber still tries to clear its password.", "clears " .. tostring(ctx.me.passwordClears))
			end
		end,
	}

	Hunt.promise{
		id = "chatv.password_clear_rate",
		area = "Chat reading",
		text = "However often a stranger sets the password again, the owner clears it at most once every 30 seconds, and it is open again afterwards.",
		source = "Net/Base.lua channelPassword (at most one clear in 30 s)",
		kind = "scenario",
		when = function(sit) return sit.net ~= "none" end,
		check = function(ctx)
			owner(ctx)
			local c0 = ctx.me.passwordClears or 0
			local t0 = ctx.w.time
			for i = 1, 6 do
				ctx.w:setChannelPassword("WuberNet", "pw" .. i, "Stranger")
				ctx:advance(ctx.rng:int(8))
			end
			local spent = ctx.w.time - t0
			local clears = (ctx.me.passwordClears or 0) - c0
			if clears > math.floor(spent / 30) + 1 then
				ctx:fail("A stranger keeps putting a password on your channel and you clear it " .. clears .. " times in " .. math.floor(spent) .. " seconds.", "clears " .. clears)
			end
			ctx:advance(90)
			if ctx.w.channels["wubernet"].password ~= nil then
				ctx:fail("A stranger put a password on your channel 90 seconds ago and it is still there.", "password " .. tostring(ctx.w.channels["wubernet"].password))
			end
		end,
	}
end
