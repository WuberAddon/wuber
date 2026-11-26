-- Promises about the raid queue and raid mode on the 2.4.1 code (tests/promises/v241_raid.lua).
-- A raid-leading driver and a second crew window share ONE queue (the order keeper lists every raider for everyone),
-- and the typed drive commands say true things about raid mode (AU24-15, AU24-22, AU24-27, AU24-28).
return function(Hunt)
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end
	local function strip(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1")) end
	local RAIDERS = { "Alder Mate", "Birch Mate", "Cedar Mate" }

	local function queueOf(c)
		local out = {}
		local q = c.W.Drive.RaidQueue and c.W.Drive.RaidQueue() or {}
		for _, e in ipairs(q) do out[#out + 1] = key(e.name or e.key or "?") end
		return table.concat(out, ",")
	end
	local function said(ctx, text)
		local n = #ctx.me.chatLines
		ctx.me:slash(text)
		ctx:note(text)
		ctx:advance(1)
		local out = {}
		for i = n + 1, #ctx.me.chatLines do out[#out + 1] = strip(ctx.me.chatLines[i]) end
		return table.concat(out, " | ")
	end

	-- me (the Mage runner) and the Warlock friend's window are in one raid with the raiders; raid summons run on my window
	local function raidRunning(ctx)
		if ctx.me.player.combat then ctx:na("in combat") end
		local DR, friend = ctx.W.Drive, ctx.peers.summoner
		if not (DR and DR.SetMode and friend) then ctx:cannot("no crew window") end
		local names = { ctx.name, friend.player.name }
		for _, n in ipairs(RAIDERS) do
			if not ctx.w:player(n) then ctx.w:addBot(n, { spot = "Orgrimmar", class = "WARRIOR" }) end
			ctx.w:move(n, "Orgrimmar")
			names[#names + 1] = n
		end
		for i = 1, 5 do
			local n = "Filler Mate " .. string.char(64 + i)
			if not ctx.w:player(n) then ctx.w:addBot(n, { spot = "Orgrimmar", class = "WARRIOR" }) end
			names[#names + 1] = n
		end
		ctx.w:group(names)
		ctx:advance(3)
		local okm = DR.SetMode("raid")
		if okm == false then ctx:cannot("could not switch to raid mode") end
		ctx:advance(2)
		local can, why = DR.CanRunRaid()
		if can == false then ctx:cannot("raid cannot run: " .. tostring(why)) end
		local ok = DR.SetOpen(true)
		if ok == false then ctx:cannot("raid summons would not start") end
		ctx:advance(5)
		if not DR.RaidOn() then ctx:cannot("raid summons not on") end
		ctx:note("raid mode on, Start")
		return friend
	end
	local function ask(ctx, who)
		ctx.w:chatFrom(who, "123", "RAID")
		ctx:note(who .. " says 123 in raid chat")
		ctx:advance(3)
	end
	local raidSit = function(sit) return sit.role == "friend" and sit.ride == "none" end

	Hunt.promise{
		id = "v241.raid.same_queue",
		area = "Raid",
		text = "While raid summons run, the raiders who typed 123 are queued in the same order on your window and on your crew mate's window.",
		source = "Drive.Raid (the order keeper lists every raider for everyone); r17 C2",
		kind = "scenario",
		needs = { role = "friend", ride = "none", phone = "closed" },
		when = raidSit,
		check = function(ctx)
			local friend = raidRunning(ctx)
			for _, n in ipairs(RAIDERS) do ask(ctx, n) end
			ctx:advance(5)
			local mine, theirs = queueOf(ctx.me), queueOf(friend)
			if mine == "" then ctx:fail("Three raiders type 123 in raid chat and your queue is empty.") end
			if mine ~= theirs then
				ctx:fail("Three raiders type 123 and your queue reads [" .. mine .. "] but your crew mate's window reads [" .. theirs .. "].")
			end
			if mine ~= key(RAIDERS[1]) .. "," .. key(RAIDERS[2]) .. "," .. key(RAIDERS[3]) then
				ctx:fail("Alder, Birch and Cedar type 123 in that order and your queue reads [" .. mine .. "], not first asked first.")
			end
		end,
	}

	Hunt.promise{
		id = "v241.raid.drop_both",
		area = "Raid",
		text = "A raider you take off the queue on your window is gone from your crew mate's window too, and the others keep their places.",
		source = "Drive.Raid (RD goes to every window); Button.lua skip",
		kind = "scenario",
		needs = { role = "friend", ride = "none", phone = "closed" },
		when = raidSit,
		check = function(ctx)
			local friend = raidRunning(ctx)
			for _, n in ipairs(RAIDERS) do ask(ctx, n) end
			ctx:advance(3)
			if not ctx.W.Drive.RaidDrop(RAIDERS[2], "hand") then ctx:cannot("Birch was never queued") end
			ctx:note("take Birch off the queue")
			ctx:advance(5)
			local theirs = queueOf(friend)
			if theirs:find(key(RAIDERS[2]), 1, true) then ctx:fail("You take Birch off the raid queue and she is still listed on your crew mate's window.") end
			if queueOf(ctx.me) ~= theirs then ctx:fail("You take Birch off the raid queue and the two windows list [" .. queueOf(ctx.me) .. "] and [" .. theirs .. "].") end
			if theirs ~= key(RAIDERS[1]) .. "," .. key(RAIDERS[3]) then ctx:fail("Birch is taken off and the queue reads [" .. theirs .. "], not Alder then Cedar.") end
			-- the other way round: the crew mate takes Alder off
			friend.W.Drive.RaidDrop(RAIDERS[1], "hand")
			ctx:advance(5)
			if queueOf(ctx.me):find(key(RAIDERS[1]), 1, true) then ctx:fail("Your crew mate takes Alder off the raid queue and she is still listed on your window.") end
		end,
	}

	Hunt.promise{
		id = "v241.raid.top_both",
		area = "Raid",
		text = "A raider you move to the top of the raid queue is first on your crew mate's window too.",
		source = "Drive.Raid (RT); inferred",
		kind = "scenario",
		needs = { role = "friend", ride = "none", phone = "closed" },
		when = raidSit,
		check = function(ctx)
			local friend = raidRunning(ctx)
			for _, n in ipairs(RAIDERS) do ask(ctx, n) end
			ctx:advance(3)
			if not ctx.W.Drive.RaidTop(RAIDERS[3]) then ctx:cannot("Cedar was never queued") end
			ctx:note("move Cedar to the top")
			ctx:advance(5)
			local mine, theirs = queueOf(ctx.me), queueOf(friend)
			if mine ~= theirs then ctx:fail("You move Cedar to the top and the windows list [" .. mine .. "] and [" .. theirs .. "].") end
			if mine:sub(1, #key(RAIDERS[3])) ~= key(RAIDERS[3]) then ctx:fail("You move Cedar to the top and the queue reads [" .. mine .. "].") end
		end,
	}

	Hunt.promise{
		id = "v241.raid.open_words",
		area = "Raid",
		text = "In raid mode, typing /wuber drive open says raid summons are open and free, not a price and a whisper word; in selling mode it still names the price.",
		source = "AU24-15 (Drive commands: raid-mode on words); guard: selling words unchanged",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", group = "raid", phone = "closed" },
		check = function(ctx)
			local DR = ctx.W.Drive
			if ctx.me.player.combat then ctx:na("in combat") end
			ctx.me:slash("/wuber drive close")
			ctx:advance(1)
			local sell = said(ctx, "/wuber drive open")
			if DR.IsOpen() and not sell:find("whisper", 1, true) then
				ctx:fail("In selling mode /wuber drive open does not say what riders whisper: " .. sell)
			end
			ctx.me:slash("/wuber drive close")
			ctx:advance(1)
			said(ctx, "/wuber drive raid")
			if DR.Mode() ~= "raid" then ctx:cannot("could not switch to raid mode") end
			local line = said(ctx, "/wuber drive open")
			if not DR.IsOpen() then ctx:cannot("raid summons would not open: " .. line) end
			if not line:find("raid summons", 1, true) then ctx:fail("In raid mode you type /wuber drive open and Wuber says: " .. line) end
			if line:find("whisper", 1, true) then ctx:fail("In raid mode /wuber drive open tells you riders whisper a word, but raiders type 123 in raid chat: " .. line) end
		end,
	}

	Hunt.promise{
		id = "v241.raid.not_yet_one_stop",
		area = "Raid",
		text = "Typing /wuber drive raid when raid summons cannot run yet tells you why in one plain sentence, without a doubled full stop.",
		source = "AU24-28 (one full stop in the raid answer)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", group = "solo", phone = "closed" },
		check = function(ctx)
			if ctx.me.player.combat then ctx:na("in combat") end
			local line = said(ctx, "/wuber drive raid")
			if ctx.W.Drive.CanRunRaid() ~= false then ctx:na("raid summons can run here") end
			if not line:find("Not yet", 1, true) then ctx:fail("You are alone, type /wuber drive raid and nothing says why it cannot run yet: " .. line) end
			if line:find("[%.!?][%.!?]") or line:find("%. %.") then ctx:fail("/wuber drive raid answers with a doubled full stop: " .. line) end
			if not line:find("Make or join a raid first.", 1, true) and not line:find("raid") then ctx:fail("The answer does not say what to do: " .. line) end
		end,
	}

	Hunt.promise{
		id = "v241.raid.off_words",
		area = "Raid",
		text = "Typing /wuber drive raid off, or /wuber drive sell, takes you back to selling: it says Selling summons and the raid queue is cleared.",
		source = "guard: unchanged path beside AU24-15, 22, 27, 28",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", group = "raid", phone = "closed" },
		check = function(ctx)
			local DR = ctx.W.Drive
			if ctx.me.player.combat then ctx:na("in combat") end
			said(ctx, "/wuber drive raid")
			if DR.Mode() ~= "raid" then ctx:cannot("could not switch to raid mode") end
			local a = said(ctx, "/wuber drive raid off")
			if DR.Mode() ~= "sell" then ctx:fail("You type /wuber drive raid off and Wuber is still in raid mode: " .. a) end
			if not a:find("Selling summons", 1, true) then ctx:fail("You type /wuber drive raid off and Wuber says: " .. a) end
			said(ctx, "/wuber drive raid")
			said(ctx, "/wuber drive sell")
			if DR.Mode() ~= "sell" then ctx:fail("You type /wuber drive sell from raid mode and Wuber stays in raid mode.") end
		end,
	}
end
