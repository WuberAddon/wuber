-- Second-wave promises about the Warlock DRIVER's deeper parts (owner driver2): raid summons end to end, the crew
-- wizard, several summoning places, the ready-to-drive checks, the alert character (bell), every /wuber drive command
-- and the big button's show / lock / key. Written from what the driver is told: the Raid summons screen, the wizard's
-- own words, the Ready to drive lines, Settings tooltips (Driving: the big button, the alert character), the /wuber
-- drive help line, and the file headers where nothing else says it.
return function(Hunt)
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end
	local function strip(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1")) end
	local function say(ctx, fmt, ...) ctx:fail((select("#", ...) > 0 and fmt:format(...) or fmt)) end
	local function find(ctx, pat)
		for _, t in ipairs(ctx:texts()) do local p = strip(t) if p:find(pat) then return p end end
		return nil
	end
	local function allText(ctx) return table.concat(ctx:texts(), " | ") end
	local function DR(ctx) return ctx.W.Drive end
	local function opt(sit, name) return sit[name] or "default" end
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
	local function press(ctx, pat, o)
		o = o or {}
		o.pattern = true
		local ok, err = pcall(ctx.me.clickText, ctx.me, pat, o)
		ctx:note("click " .. pat)
		ctx:advance(o.wait or 1)
		return ok, err
	end
	-- a click on the button or row a text belongs to. (The fake game lets a tall page that is clipped on screen take the
	-- click aimed at a button below it, and rows scrolled out of view have no mouse: a player taps the button itself,
	-- or scrolls to the row first with the "more below" cue.)
	local function pressRow(ctx, pat, button)
		for _ = 1, 5 do
			local row
			for _, obj in ipairs(ctx.me.widgets) do
				if not row and obj.GetObjectType and obj:GetObjectType() == "FontString" and ctx:visible(obj) and strip(obj:GetText() or ""):find(pat) then
					row = ctx.me:clickable(obj)
				end
			end
			if not row then return false end
			if not row.IsMouseEnabled or row:IsMouseEnabled() then
				ctx.me:click(row, button)
				ctx:note("click the row " .. pat .. (button and (" with " .. button) or ""))
				ctx:advance(1.5)
				return true
			end
			-- the row is out of view: the player taps the "more below" cue (it scrolls down) and looks again
			if not pcall(ctx.me.clickText, ctx.me, "more below", { pattern = true }) then return false end
			ctx:note("tap the more-below cue")
			ctx:advance(1)
		end
		return false
	end
	local function noCombat(ctx) if ctx.me.player.combat then ctx:na("in combat") end end
	-- my whispers to somebody (the world's record)
	local function myWhispers(ctx, to)
		local out = {}
		for _, x in ipairs(ctx.w.whispers) do
			if key(x.from) == key(ctx.name) and (not to or key(x.to) == key(to)) then out[#out + 1] = x end
		end
		return out
	end
	local function myPosts(ctx)
		local out = {}
		for _, p in ipairs(ctx.w.chatPosts or {}) do
			if key(p.from) == key(ctx.name) then out[#out + 1] = p end
		end
		return out
	end

	---------------------------------------------------------------------------
	-- raid summons
	---------------------------------------------------------------------------
	local MATES = { "Alder Mate", "Birch Mate", "Cedar Mate", "Dune Mate" }

	local function inRaidScreen(ctx)
		if not find(ctx, "^Raid summons$") then ctx:cannot("no Raid summons tab on screen") end
	end
	local function raidTab(ctx)
		noCombat(ctx)
		local ok = press(ctx, "^Raid summons$")
		if not ok then ctx:cannot("no Raid summons tab") end
	end
	local function startRaid(ctx)
		raidTab(ctx)
		local ok = press(ctx, "^Start", { wait = 2 })
		if not ok then ctx:cannot("no Start button") end
		if not DR(ctx).RaidOn() then ctx:cannot("raid summons did not start") end
	end
	-- the raiders stand in another city (a summon is for those who are not at the spot)
	local function sendAway(ctx, names)
		local away = "Orgrimmar"
		if tostring(ctx.me.player.zone or "") == "Orgrimmar" then away = "Undercity" end
		for _, n in ipairs(names) do
			if not ctx.w:player(n) then ctx:cannot("no raider " .. n) end
			ctx.w:move(n, away)
		end
		ctx:advance(4)
		ctx:note("the raiders " .. table.concat(names, ", ") .. " stand in " .. away)
	end
	local function raidSay(ctx, who, text)
		ctx.w:chatFrom(who, text, "RAID")
		ctx:advance(2)
		ctx:note(who .. " says in raid chat: " .. text)
	end
	local function queue(ctx)
		local out = {}
		for _, e in ipairs(DR(ctx).RaidQueue() or {}) do out[#out + 1] = key(e.name or e.key or "?") end
		return out
	end
	local function bigButton(ctx)
		local b = ctx.me.env.WuberDriveButton
		if not (b and ctx:visible(b)) then ctx:na("no big button on screen") end
		return b
	end
	-- the first raider asks, the leader clicks the big button until the summon is under way
	local function summonStarted(ctx, name)
		local b = bigButton(ctx)
		for _ = 1, 4 do
			ctx.me:click(b)
			ctx:advance(2)
			local row = DR(ctx).raidRows[key(name)]
			if row and row.state == "summoning" then return true end
		end
		return false
	end

	local RAID_NEEDS = { phone = "drive", role = "warlock", group = "raid" }

	Hunt.promise{
		id = "raidsum.whisper_request",
		area = "Raid summons",
		text = "A raider who whispers you 123 while raid summons run is put in the queue, the same as in raid chat.",
		source = "Drive.Raid header (a raid member asks in raid or party chat, or by a whisper)",
		kind = "scenario",
		needs = RAID_NEEDS,
		check = function(ctx)
			noCombat(ctx)
			startRaid(ctx)
			sendAway(ctx, { MATES[1] })
			ctx.w:botWhisper(MATES[1], ctx.me, "123")
			ctx:advance(2)
			ctx:note(MATES[1] .. " whispers: 123")
			local q = queue(ctx)
			if #q ~= 1 then say(ctx, "Raid summons run, a raider whispers you 123 and the queue holds %d raiders.", #q) end
		end,
	}

	Hunt.promise{
		id = "raidsum.stopped_no_queue",
		area = "Raid summons",
		text = "While raid summons are stopped, a raider who types 123 in raid chat is not queued, and the screen still says they are stopped.",
		source = "Raid screen (Raid summons are stopped / Press Start, then raiders type 123 in raid chat)",
		kind = "scenario",
		needs = RAID_NEEDS,
		check = function(ctx)
			raidTab(ctx)
			if DR(ctx).RaidOn() then ctx:na("raid summons are already running") end
			sendAway(ctx, { MATES[1] })
			raidSay(ctx, MATES[1], "123")
			if #queue(ctx) ~= 0 then ctx:fail("Raid summons are stopped, a raider types 123 in raid chat and they are put in your queue anyway.") end
			if not find(ctx, "Raid summons are stopped") then ctx:fail("Raid summons are stopped, a raider types 123 and the Raid summons screen no longer says they are stopped.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "raidsum.inv_not_request",
		area = "Raid summons",
		text = "A raider who only asks for an invite ('inv') in raid chat is not put in the summon queue.",
		source = "Drive.Raid (inv is not a request); inferred",
		kind = "scenario",
		needs = RAID_NEEDS,
		check = function(ctx)
			startRaid(ctx)
			sendAway(ctx, { MATES[1] })
			raidSay(ctx, MATES[1], "inv")
			if #queue(ctx) ~= 0 then ctx:fail("A raider types inv in raid chat while raid summons run and is put in the summon queue.") end
		end,
	}

	Hunt.promise{
		id = "raidsum.stop_clears_queue",
		area = "Raid summons",
		text = "Tap Stop and the raiders who were waiting are dropped: start again and nobody is waiting.",
		source = "Drive.Raid (SetRaidRun: stopping empties the queue); Raid screen (Stop)",
		kind = "scenario",
		needs = RAID_NEEDS,
		check = function(ctx)
			startRaid(ctx)
			sendAway(ctx, { MATES[1], MATES[2] })
			raidSay(ctx, MATES[1], "123")
			raidSay(ctx, MATES[2], "summon")
			if #queue(ctx) ~= 2 then ctx:cannot("the raiders did not queue") end
			if not press(ctx, "^Stop$", { wait = 2 }) then ctx:cannot("no Stop button") end
			if #queue(ctx) ~= 0 then say(ctx, "You tap Stop on raid summons with two raiders waiting and the queue still holds %d.", #queue(ctx)) end
			if not press(ctx, "^Start", { wait = 2 }) then ctx:cannot("no Start button") end
			if not find(ctx, "Nobody waiting") then ctx:fail("You stop raid summons and start them again and the screen does not say Nobody waiting.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "raidsum.summon_whispers_raider",
		area = "Raid summons",
		text = "When your big button starts a raider's summon, that raider is whispered that a summon is coming.",
		source = "Messages (Raid: summon coming: whisper to the raider)",
		kind = "scenario",
		needs = RAID_NEEDS,
		when = function(sit) return opt(sit, "opt_raidsum") ~= "off" end,
		check = function(ctx)
			noCombat(ctx)
			startRaid(ctx)
			sendAway(ctx, { MATES[1] })
			raidSay(ctx, MATES[1], "123")
			if not summonStarted(ctx, MATES[1]) then ctx:cannot("the summon did not start") end
			if #myWhispers(ctx, MATES[1]) == 0 then
				ctx:fail("You click the big button to summon a raider who asked in raid chat and they are not whispered that a summon is coming.", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "raidsum.whisper_switch_off",
		area = "Raid summons",
		text = "With the raid whisper switched off, summoning a raider whispers them nothing.",
		source = "Messages (Raid: summon coming: whisper to the raider); /wuber drive raidsum off",
		kind = "scenario",
		needs = { phone = "drive", role = "warlock", group = "raid", opt_raidsum = "off" },
		check = function(ctx)
			noCombat(ctx)
			startRaid(ctx)
			sendAway(ctx, { MATES[1] })
			raidSay(ctx, MATES[1], "123")
			if not summonStarted(ctx, MATES[1]) then ctx:cannot("the summon did not start") end
			local w = myWhispers(ctx, MATES[1])
			if #w > 0 then ctx:fail("The raid whisper is switched off, you summon a raider and they are whispered anyway: " .. tostring(w[1].text)) end
		end,
	}

	Hunt.promise{
		id = "raidsum.click_portal_line",
		area = "Raid summons",
		text = "When a raider's summon starts, a line in raid chat asks the raid to click the portal.",
		source = "Messages (Raid: click the portal: a raid chat line)",
		kind = "scenario",
		needs = RAID_NEEDS,
		when = function(sit) return opt(sit, "opt_raidclick") ~= "off" end,
		check = function(ctx)
			noCombat(ctx)
			startRaid(ctx)
			sendAway(ctx, { MATES[1] })
			raidSay(ctx, MATES[1], "123")
			if not summonStarted(ctx, MATES[1]) then ctx:cannot("the summon did not start") end
			local found
			for _, p in ipairs(myPosts(ctx)) do
				if tostring(p.kind) == "RAID" and tostring(p.text):lower():find("portal", 1, true) then found = p end
			end
			if not found then ctx:fail("You start a raid summon and no line in raid chat asks the raid to click the portal.") end
		end,
	}

	Hunt.promise{
		id = "raidsum.click_line_off",
		area = "Raid summons",
		text = "With the raid 'click the portal' line switched off, summoning a raider says nothing in raid chat.",
		source = "Messages (Raid: click the portal: a raid chat line); /wuber drive raidclick off",
		kind = "scenario",
		needs = { phone = "drive", role = "warlock", group = "raid", opt_raidclick = "off" },
		check = function(ctx)
			noCombat(ctx)
			startRaid(ctx)
			sendAway(ctx, { MATES[1] })
			raidSay(ctx, MATES[1], "123")
			if not summonStarted(ctx, MATES[1]) then ctx:cannot("the summon did not start") end
			for _, p in ipairs(myPosts(ctx)) do
				if tostring(p.kind) == "RAID" then ctx:fail("The raid 'click the portal' line is switched off, you summon a raider and you say this in raid chat anyway: " .. tostring(p.text)) end
			end
		end,
	}

	Hunt.promise{
		id = "raidsum.free_nothing_asked",
		area = "Raid summons",
		text = "Raid summons are free: nothing in them asks for gold, posts an advert or invites anybody.",
		source = "Raid screen (Free); Drive.Raid header (No price, trade, invites, kicks, adverts)",
		kind = "scenario",
		needs = RAID_NEEDS,
		check = function(ctx)
			noCombat(ctx)
			startRaid(ctx)
			sendAway(ctx, { MATES[1] })
			raidSay(ctx, MATES[1], "123")
			if not summonStarted(ctx, MATES[1]) then ctx:cannot("the summon did not start") end
			for _, x in ipairs(myWhispers(ctx)) do
				if tostring(x.text):find("%d+%s*[gs]%f[%A]") or tostring(x.text):lower():find("price", 1, true) then
					ctx:fail("You run free raid summons and a raider is whispered something about gold: " .. tostring(x.text))
				end
			end
			for _, p in ipairs(myPosts(ctx)) do
				if tostring(p.text):find("%[Wuber%]") then ctx:fail("You run free raid summons and an advert goes out in chat: " .. tostring(p.text)) end
			end
			if #(ctx.w.tradeLog or {}) > 0 then ctx:fail("You run free raid summons and a trade is opened.") end
		end,
	}

	Hunt.promise{
		id = "raidsum.landed_counts",
		area = "Raid summons",
		text = "When a summoned raider lands, they leave the queue and the Summoned tonight count goes up by one.",
		source = "Raid screen (Summoned tonight)",
		kind = "scenario",
		needs = RAID_NEEDS,
		check = function(ctx)
			noCombat(ctx)
			if ctx.W.Driver.RaidTonight() ~= 0 then ctx:na("raiders were already counted tonight") end
			startRaid(ctx)
			sendAway(ctx, { MATES[1] })
			raidSay(ctx, MATES[1], "123")
			if not summonStarted(ctx, MATES[1]) then ctx:cannot("the summon did not start") end
			ctx:advance(2)
			-- two raiders click the portal (a summon needs three)
			local a, b = ctx.w:clickPortal(MATES[2]), ctx.w:clickPortal(MATES[3])
			ctx:note(MATES[2] .. " and " .. MATES[3] .. " click the portal")
			if not (a and b) then ctx:cannot("the portal could not be clicked") end
			ctx:advance(6)
			local p = ctx.w:player(MATES[1])
			if p.zone ~= ctx.me.player.zone then ctx:cannot("the raider did not land") end
			if #queue(ctx) ~= 0 then ctx:fail("A raider lands after your summon and is still in the raid queue.", allText(ctx)) end
			if ctx.W.Driver.RaidTonight() ~= 1 then
				say(ctx, "You summon one raider and the Summoned tonight count reads %s.", tostring(ctx.W.Driver.RaidTonight()))
			end
		end,
	}


	Hunt.promise{
		id = "raidsum.not_here_lists_away",
		area = "Raid summons",
		text = "The Not here list counts exactly the raid members who are not where your summoners stand, and drops one when you queue them or they arrive.",
		source = "Raid screen (Not here (N): Raid members who aren't where your summoners stand)",
		kind = "scenario",
		needs = RAID_NEEDS,
		check = function(ctx)
			startRaid(ctx)
			if not find(ctx, "^Not here %(0%)") then ctx:na("someone is already away at the start") end
			sendAway(ctx, { MATES[1], MATES[2] })
			ctx:advance(3)
			if not find(ctx, "^Not here %(2%)") then
				say(ctx, "Two raiders stand in another city and the Not here header reads: %s.", tostring(find(ctx, "^Not here") or "missing"))
			end
			-- one of them walks to the spot
			local me = ctx.me.player
			ctx.w:placePlayer(ctx.w:player(MATES[2]), { mapID = me.mapID, x = me.x, y = me.y, zone = me.zone, sub = me.subZone })
			ctx:advance(4)
			ctx:note(MATES[2] .. " arrives at the spot")
			if not find(ctx, "^Not here %(1%)") then
				say(ctx, "One of two away raiders arrives at your spot and the Not here header reads: %s.", tostring(find(ctx, "^Not here") or "missing"))
			end
		end,
	}

	Hunt.promise{
		id = "raidsum.plus_queues",
		area = "Raid summons",
		text = "Tap + on a raider in Not here and they are in the summon queue, and no longer under Not here.",
		source = "Raid screen (+ tooltip: Adds them to the summon queue by hand)",
		kind = "scenario",
		needs = RAID_NEEDS,
		check = function(ctx)
			startRaid(ctx)
			sendAway(ctx, { MATES[1] })
			ctx:advance(2)
			if not find(ctx, "^Not here %(1%)") then ctx:cannot("the away raider is not under Not here") end
			-- the list may be folded: tap its header
			if not find(ctx, "^Alder") then press(ctx, "^Not here") end
			if not find(ctx, "^Alder") then ctx:cannot("the Not here list does not show the raider") end
			if not press(ctx, "^%+$", { wait = 2 }) then ctx:cannot("no + button") end
			if #queue(ctx) ~= 1 then say(ctx, "You tap + beside a raider under Not here and the queue holds %d raiders.", #queue(ctx)) end
			if not find(ctx, "^Not here %(0%)") then
				say(ctx, "You queue a raider from Not here and the Not here header still reads: %s.", tostring(find(ctx, "^Not here") or "missing"))
			end
		end,
	}

	Hunt.promise{
		id = "raidsum.here_not_summoned",
		area = "Raid summons",
		text = "A raider who is already standing where your summoners stand, and types 123, is not left waiting in the summon queue.",
		source = "Drive.Raid (the next raider is one 'not at the spot'); inferred",
		kind = "scenario",
		needs = RAID_NEEDS,
		check = function(ctx)
			startRaid(ctx)
			raidSay(ctx, MATES[1], "123")
			ctx:advance(4)
			if #queue(ctx) ~= 0 then ctx:fail("A raider who is already standing with you types 123 and stays in the summon queue.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "raidsum.leaver_dropped",
		area = "Raid summons",
		text = "A raider who asked for a summon and then leaves the raid is taken off the queue.",
		source = "Drive.Raid (RaidTick: leavers); Raid screen",
		kind = "scenario",
		needs = RAID_NEEDS,
		check = function(ctx)
			startRaid(ctx)
			sendAway(ctx, { MATES[1], MATES[2] })
			raidSay(ctx, MATES[1], "123")
			raidSay(ctx, MATES[2], "123")
			if #queue(ctx) ~= 2 then ctx:cannot("the raiders did not queue") end
			ctx.w:leave(MATES[1])
			ctx:advance(4)
			ctx:note(MATES[1] .. " leaves the raid")
			local q = queue(ctx)
			if #q ~= 1 or q[1] ~= key(MATES[2]) then
				say(ctx, "A queued raider leaves the raid and the queue reads [%s].", table.concat(q, ", "))
			end
		end,
	}

	Hunt.promise{
		id = "raidsum.runner_leaves_stops",
		area = "Raid summons",
		text = "If you leave the raid while raid summons run, they stop, and you are told so.",
		source = "Drive.Raid (the toast 'Raid summons stopped: you left the raid')",
		kind = "scenario",
		needs = RAID_NEEDS,
		check = function(ctx)
			startRaid(ctx)
			if not DR(ctx).RaidOn() then ctx:cannot("raid summons did not start") end
			ctx.w:leave(ctx.name)
			ctx:advance(4)
			ctx:note("I leave the raid")
			if ctx.me.player.group then ctx:cannot("still grouped") end
			if DR(ctx).RaidOn() then ctx:fail("You leave the raid while raid summons run and they are still running.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "raidsum.row_tap_next",
		area = "Raid summons",
		text = "Tap a raider's row and they are summoned next, before the others who asked earlier.",
		source = "Raid row menu (Move to top: Summoned next, before the others (click))",
		kind = "scenario",
		needs = RAID_NEEDS,
		check = function(ctx)
			startRaid(ctx)
			sendAway(ctx, { MATES[1], MATES[2], MATES[3] })
			raidSay(ctx, MATES[1], "123")
			raidSay(ctx, MATES[2], "123")
			raidSay(ctx, MATES[3], "123")
			if #queue(ctx) ~= 3 then ctx:cannot("the raiders did not queue") end
			local ok = pressRow(ctx, "^Cedar")
			if not ok then ctx:cannot("no Cedar row on screen") end
			local q = queue(ctx)
			if q[1] ~= key(MATES[3]) then
				say(ctx, "Three raiders wait, you tap the last one's row to summon them next and the queue reads [%s].", table.concat(q, ", "))
			end
		end,
	}

	Hunt.promise{
		id = "raidsum.row_right_click_drops",
		area = "Raid summons",
		text = "Right-click a raider's row and they are off the list, and nothing is said to them.",
		source = "Raid row menu (Take off the list: Nothing is said (right-click))",
		kind = "scenario",
		needs = RAID_NEEDS,
		check = function(ctx)
			startRaid(ctx)
			sendAway(ctx, { MATES[1], MATES[2] })
			raidSay(ctx, MATES[1], "123")
			raidSay(ctx, MATES[2], "123")
			if #queue(ctx) ~= 2 then ctx:cannot("the raiders did not queue") end
			local before = #myWhispers(ctx)
			local ok = pressRow(ctx, "^Alder", "RightButton")
			if not ok then ctx:cannot("no Alder row on screen") end
			local q = queue(ctx)
			if #q ~= 1 or q[1] ~= key(MATES[2]) then
				say(ctx, "You right-click a raider's row to take them off the list and the queue reads [%s].", table.concat(q, ", "))
			end
			if #myWhispers(ctx) > before or #myPosts(ctx) > 0 then
				ctx:fail("You take a raider off the raid list and something is said to them or to the raid.")
			end
		end,
	}

	Hunt.promise{
		id = "raidsum.reload_keeps_running",
		area = "Raid summons",
		text = "After a /reload in the middle of a raid, raid summons are still running and the screen still says so.",
		source = "inferred (Drive.Raid: raidRun is saved)",
		kind = "scenario",
		needs = RAID_NEEDS,
		check = function(ctx)
			startRaid(ctx)
			if not DR(ctx).RaidOn() then ctx:cannot("raid summons did not start") end
			ctx:reload()
			ctx:note("/reload")
			ctx:advance(4)
			if not DR(ctx).RaidOn() then
				ctx:fail("You run raid summons, /reload in the raid, and raid summons are stopped.")
			end
		end,
	}


	---------------------------------------------------------------------------
	-- the crew wizard
	---------------------------------------------------------------------------
	local function wizUp(ctx)
		if not (find(ctx, "^Who summons") or find(ctx, "^Pick your crew$")) then ctx:cannot("the crew wizard is not on screen") end
	end
	-- a second window with Wuber (any class) standing with me, in my group
	local function addFriend(ctx, name, class)
		if ctx.w:player(name) then ctx:cannot("name taken: " .. name) end
		local me = ctx.me.player
		local ok, c = pcall(ctx.w.addClient, ctx.w, name, { spot = { mapID = me.mapID, x = me.x, y = me.y, zone = me.zone, sub = me.subZone }, class = class or "MAGE", money = 1000 })
		if not ok then ctx:cannot("could not add a window: " .. tostring(c)) end
		ctx.w:join(ctx.me.player, ctx.w:player(name))
		ctx:advance(2)
		return c
	end

	Hunt.promise{
		id = "wizard.warlock_three_choices",
		area = "Wizard",
		text = "The crew wizard asks a Warlock Who summons with you? and offers three choices: Just me, My friends help, and My other characters.",
		source = "Wizard (step 1)",
		kind = "scenario",
		needs = { phone = "drive_wizard", role = "warlock" },
		check = function(ctx)
			wizUp(ctx)
			if not find(ctx, "^Who summons with you%?") then ctx:fail("A Warlock opens the crew wizard and it does not ask Who summons with you?", allText(ctx)) end
			for _, t in ipairs({ "^Just me$", "^My friends help$", "^My other characters$" }) do
				if not find(ctx, t) then ctx:fail("A Warlock opens the crew wizard and the choice " .. t:gsub("[%^%$]", "") .. " is missing.", allText(ctx)) end
			end
		end,
	}

	Hunt.promise{
		id = "wizard.just_me_done",
		area = "Wizard",
		text = "A Warlock who picks Just me and taps Next and Done is set up: the console stops saying the crew is not set up and says you drive alone.",
		source = "Wizard (Just me: You summon alone. Riders bring two friends to click the portal; You're set up. Press Open when you're ready)",
		kind = "scenario",
		needs = { phone = "drive_wizard", role = "warlock" },
		when = function(sit) return sit.saved == nil or sit.saved == "fresh" end,
		check = function(ctx)
			wizUp(ctx)
			if not pressRow(ctx, "^Just me$") then ctx:cannot("no Just me choice") end
			if not pressRow(ctx, "^Next$") then ctx:cannot("no Next button") end
			if not pressRow(ctx, "^Done$") then
				ctx:fail("A Warlock picks Just me, taps Next, and there is no Done button to finish with.", allText(ctx))
			end
			if find(ctx, "^Who summons") then ctx:fail("A Warlock finishes the crew wizard with Done and the wizard is still on screen.", allText(ctx)) end
			if #DR(ctx).Crew() ~= 1 then ctx:fail("A Warlock picks Just me and finishes the wizard and somebody is in the crew.") end
			if find(ctx, "Crew not set up yet") then ctx:fail("A Warlock finishes the crew wizard with Just me and the Ready to drive list still says the crew is not set up.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "wizard.back_keeps_choice",
		area = "Wizard",
		text = "Tap Back in the wizard and your choice is still there: Next goes straight on again.",
		source = "tooltip (Back: The step before. Nothing is lost.)",
		kind = "scenario",
		needs = { phone = "drive_wizard", role = "warlock" },
		check = function(ctx)
			wizUp(ctx)
			if not pressRow(ctx, "^My friends help$") then ctx:cannot("no My friends help choice") end
			if not pressRow(ctx, "^Next$") then ctx:cannot("no Next button") end
			if not find(ctx, "^Pick your crew$") then ctx:cannot("step 2 did not open") end
			if not pressRow(ctx, "^Back$") then ctx:cannot("no Back button") end
			if not find(ctx, "^Who summons with you%?") then ctx:cannot("Back did not go to step 1") end
			if not pressRow(ctx, "^Next$") then ctx:fail("You tap Back in the wizard and Next is gone.", allText(ctx)) end
			if not find(ctx, "^Pick your crew$") then
				ctx:fail("You pick My friends help, tap Next, then Back, then Next again and you are not on Pick your crew: the choice was lost.", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "wizard.nonwarlock_needs_caster",
		area = "Wizard",
		text = "A player who is not a Warlock cannot pick Just me: the wizard says a Warlock must cast and Next never skips the pick of a Warlock.",
		source = "Wizard (You need a Warlock to cast: pick one in the next step)",
		kind = "scenario",
		needs = { phone = "drive_wizard", role = "friend" },
		check = function(ctx)
			wizUp(ctx)
			if not find(ctx, "^Who summons for you%?") then ctx:fail("A Mage opens the crew wizard and it does not ask Who summons for you?", allText(ctx)) end
			if not find(ctx, "^A Warlock friend$") then ctx:fail("A Mage opens the crew wizard and there is no A Warlock friend choice.", allText(ctx)) end
			if not find(ctx, "You need a Warlock to cast") then ctx:fail("A Mage opens the crew wizard and nothing says a Warlock has to cast.", allText(ctx)) end
			pressRow(ctx, "^Just me$")
			if not pressRow(ctx, "^Next$") then ctx:cannot("no Next button") end
			if find(ctx, "^Who summons%?$") and not find(ctx, "^Pick your crew$") then
				ctx:fail("A Mage taps Just me and Next and the wizard goes straight to Who summons? as if he could cast himself.", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "wizard.offer_waits_for_yes",
		area = "Wizard",
		text = "In the wizard, Send offers gives each picked player one card; nobody is in your crew until they tap Yes themselves, and you are told you are waiting for them.",
		source = "tooltip (Send offers: Each person you picked gets one card: Join your summoning crew? ... Nobody joins without their own click)",
		kind = "scenario",
		needs = { phone = "drive_wizard", role = "warlock" },
		when = function(sit) return sit.saved == nil or sit.saved == "fresh" end,
		check = function(ctx)
			wizUp(ctx)
			local friend = addFriend(ctx, "Wiz Friend", "MAGE")
			if not pressRow(ctx, "^My friends help$") then ctx:cannot("no My friends help choice") end
			if not pressRow(ctx, "^Next$") then ctx:cannot("no Next button") end
			if not find(ctx, "^Wiz Friend") then ctx:cannot("the wizard does not list the friend in my group") end
			if not pressRow(ctx, "^Send offers") then ctx:fail("You pick a friend in the wizard and there is no Send offers button.", allText(ctx)) end
			-- in a raid the offers go through the throttled outbox: the card comes about 2 s later
			waitFor(ctx, function() local p = friend.W.Drive.pendingOffers return p and p[key(ctx.name)] ~= nil end, 10)
			local pend = friend.W.Drive.pendingOffers
			if not (pend and pend[key(ctx.name)]) then ctx:fail("You send an offer in the wizard and the friend's window gets no crew card.") end
			if #DR(ctx).Crew() > 1 then ctx:fail("You send a crew offer in the wizard and the friend is in your crew before they tapped Yes.") end
			if not find(ctx, "Waiting for Wiz") then ctx:fail("You send a crew offer in the wizard and it does not say you are waiting for them to tap Yes.", allText(ctx)) end
			friend.W.Drive.AnswerOffer(ctx.name, true)
			ctx:advance(3)
			ctx:note("Wiz Friend taps Yes")
			if #DR(ctx).Crew() < 2 then ctx:fail("The friend taps Yes on your crew card and is not in your crew.") end
			if key(friend.W.Drive.char().captain) ~= key(ctx.name) then ctx:fail("The friend taps Yes and their own window does not show them in your crew.") end
		end,
	}

	Hunt.promise{
		id = "wizard.lists_my_group",
		area = "Wizard",
		text = "On the Pick your crew step, everybody in your group is listed, so you can offer them a place.",
		source = "Wizard (People in your group now. Warlocks summon and click; anyone else clicks the portal)",
		kind = "scenario",
		needs = { phone = "drive_wizard", role = "warlock", group = "party" },
		check = function(ctx)
			wizUp(ctx)
			if not pressRow(ctx, "^My friends help$") then ctx:cannot("no My friends help choice") end
			if not pressRow(ctx, "^Next$") then ctx:cannot("no Next button") end
			if not find(ctx, "^Pick your crew$") then ctx:cannot("step 2 did not open") end
			for _, n in ipairs({ "Alder Mate", "Birch Mate" }) do
				if not find(ctx, "^" .. n .. "$") then
					say(ctx, "You are in a party with %s and the Pick your crew step does not list them.", n)
				end
			end
		end,
	}

	---------------------------------------------------------------------------
	-- several summoning places (stations)
	---------------------------------------------------------------------------
	-- a Mage runs the service (role friend: a Warlock friend at Ratchet summons); a second Warlock in Orgrimmar joins
	-- the crew and the summoner order: two places
	local function twoStations(ctx)
		local me = ctx.me
		if not (ctx.peers and ctx.peers.summoner) then ctx:cannot("no Warlock friend window") end
		if ctx.w:player("Stat Two") then ctx:cannot("name taken") end
		local c2 = ctx.w:addClient("Stat Two", { spot = "Orgrimmar", class = "WARLOCK", shards = 10, money = 100000 })
		ctx:advance(1)
		local okO = me.W.Drive.OfferCrew("Stat Two")
		if not okO then ctx:cannot("the crew offer to Stat Two was refused") end
		if not waitFor(ctx, function() local p = c2.W.Drive.pendingOffers return p and p[key(ctx.name)] ~= nil end, 5) then ctx:cannot("no crew card for Stat Two") end
		c2.W.Drive.AnswerOffer(ctx.name, true)
		ctx:advance(3)
		ctx.w:group({ ctx.name, ctx.peers.summoner.player.name, "Stat Two" })
		ctx:advance(2)
		me.W.Drive.SetSummoners({ key(ctx.peers.summoner.player.name), "stat two" })
		ctx:advance(4)
		ctx:note("a second Warlock, Stat Two, joins the crew in Orgrimmar and summons too")
		if #(me.W.Drive.Stations() or {}) < 2 then ctx:cannot("the crew does not summon from two places") end
	end
	local function say2(ctx, cmd)
		ctx.me:slash(cmd)
		ctx:advance(1)
		ctx:note(cmd)
	end
	local function chatSince(ctx, n)
		local out = {}
		for i = n + 1, #ctx.me.chatLines do out[#out + 1] = strip(ctx.me.chatLines[i]) end
		return table.concat(out, "\n")
	end

	Hunt.promise{
		id = "stations.command_lists_places",
		area = "Stations",
		text = "/wuber drive stations lists every place your summoners stand, with how many summon and help there.",
		source = "/wuber drive help (stations)",
		kind = "scenario",
		needs = { role = "friend" },
		check = function(ctx)
			twoStations(ctx)
			local n = #ctx.me.chatLines
			say2(ctx, "/wuber drive stations")
			local out = chatSince(ctx, n)
			for _, st in ipairs(DR(ctx).Stations()) do
				if not out:find(st.place, 1, true) then
					ctx:fail("Your two summoners stand in two places, one of them " .. tostring(st.place) .. ", and /wuber drive stations says: " .. out:gsub("\n", " / "))
				end
			end
			if not out:find("summoner", 1, true) then ctx:fail("/wuber drive stations does not say how many summoners each place has: " .. out:gsub("\n", " / ")) end
		end,
	}

	Hunt.promise{
		id = "stations.ready_names_places",
		area = "Stations",
		text = "With summoners in two places, the Ready to drive list names both places and says which one needs riders to bring a friend.",
		source = "Ready to drive (Stations: ... - riders bring a friend)",
		kind = "scenario",
		needs = { role = "friend" },
		check = function(ctx)
			twoStations(ctx)
			local text
			for _, l in ipairs(DR(ctx).Readiness()) do if tostring(l.text):find("^Stations:") then text = l.text end end
			if not text then ctx:fail("Your summoners stand in two places and the Ready to drive list has no Stations line.") end
			for _, st in ipairs(DR(ctx).Stations()) do
				if not text:find(st.place, 1, true) then ctx:fail("The Stations line misses a place (" .. tostring(st.place) .. "): " .. text) end
			end
		end,
	}

	Hunt.promise{
		id = "stations.off_command",
		area = "Stations",
		text = "/wuber drive stations <place> off switches a place off: it says so, riders are no longer sent there, and 'on' brings it back.",
		source = "/wuber drive help (stations Orgrimmar off)",
		kind = "scenario",
		needs = { role = "friend" },
		check = function(ctx)
			twoStations(ctx)
			local n = #ctx.me.chatLines
			say2(ctx, "/wuber drive stations Orgrimmar off")
			if not chatSince(ctx, n):find("switched off", 1, true) then ctx:fail("You switch the Orgrimmar place off and the command does not say it is switched off.") end
			if DR(ctx).MultiStation() then ctx:fail("You switch one of two places off and Wuber still routes riders to both.") end
			local text
			for _, l in ipairs(DR(ctx).Readiness()) do if tostring(l.text):find("^Stations:") then text = l.text end end
			if text and not text:find("Orgrimmar (off)", 1, true) then ctx:fail("You switch Orgrimmar off and the Ready list says: " .. text) end
			say2(ctx, "/wuber drive stations Orgrimmar on")
			if not DR(ctx).MultiStation() then ctx:fail("You switch Orgrimmar off and on again and it is still not a place riders are sent to.") end
		end,
	}

	Hunt.promise{
		id = "stations.console_shows_places",
		area = "Stations",
		text = "With two places open, the Drive console says the fare is to 2 places and lets you look at each place's riders.",
		source = "Drive console (the fare line; place tabs); inferred",
		kind = "scenario",
		needs = { role = "friend", phone = "drive" },
		check = function(ctx)
			twoStations(ctx)
			ctx:advance(3)
			if not find(ctx, "to 2 places") then ctx:fail("Your crew summons from two places and the Drive console does not say the fare is to 2 places.", allText(ctx)) end
		end,
	}


	---------------------------------------------------------------------------
	-- ready to drive
	---------------------------------------------------------------------------
	-- the player opens the phone on the Drive tab
	local function openDrive(ctx)
		local UI = ctx.W.UI
		if not (UI.IsShown and UI.IsShown()) then
			UI.Toggle(true)
			ctx:note("open the phone")
			ctx:advance(3)
		else
			ctx:advance(3)
		end
		for _ = 1, 3 do
			if find(ctx, "^Riders$") or find(ctx, "^Ready to drive") then break end
			ctx:advance(3)
		end
		if not (find(ctx, "^Riders$") or find(ctx, "^Ready to drive")) then
			pcall(ctx.me.clickText, ctx.me, "^Drive$", { pattern = true })
			ctx:note("click the Drive tab")
			ctx:advance(1)
		end
		if not (find(ctx, "^Riders$") or find(ctx, "^Ready to drive")) and UI.ShowDrive then
			pcall(UI.ShowDrive, "console")
			ctx:advance(1)
		end
		if not (find(ctx, "^Riders$") or find(ctx, "^Ready to drive")) then ctx:cannot("could not reach the Drive console") end
	end
	local function lines(ctx)
		local out = {}
		for _, l in ipairs(DR(ctx).Readiness() or {}) do out[#out + 1] = l end
		return out
	end
	local function lineWith(ctx, pat)
		for _, l in ipairs(lines(ctx)) do if tostring(l.text):find(pat) then return l end end
		return nil
	end

	Hunt.promise{
		id = "ready.no_shards_cure",
		area = "Ready",
		text = "A Warlock with no Soul Shards is told so on the Ready to drive list; once a shard is made the list says how many shards there are.",
		source = "Ready to drive (No Soul Shards: Drain Soul a mob as it dies to make one; N Soul Shards (one per summon))",
		kind = "scenario",
		needs = { role = "warlock", phone = "drive" },
		when = function(sit) return opt(sit, "opt_needShards") ~= "off" end,
		check = function(ctx)
			ctx.me.player.shards = 0
			ctx:advance(4)
			ctx:note("my last Soul Shard is used")
			if not lineWith(ctx, "No Soul Shards") then ctx:fail("You have no Soul Shards and the Ready to drive list does not say so.", allText(ctx)) end
			if not find(ctx, "No Soul Shards") then ctx:fail("You have no Soul Shards and the Drive console does not say so anywhere.", allText(ctx)) end
			ctx.me.player.shards = 3
			ctx:advance(4)
			ctx:note("Drain Soul makes three shards")
			if lineWith(ctx, "No Soul Shards") then ctx:fail("You have three Soul Shards again and the Ready to drive list still says No Soul Shards.", allText(ctx)) end
			if not lineWith(ctx, "3 Soul Shards") then ctx:fail("You have three Soul Shards and the Ready to drive list does not say 3 Soul Shards.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "ready.spell_unknown_cure",
		area = "Ready",
		text = "A Warlock who has not learned the summoning spell is told to see a trainer; after learning it the list says it is known.",
		source = "Ready to drive (The summoning spell isn't known yet: a Warlock trainer teaches it at level 20)",
		kind = "scenario",
		needs = { role = "warlock", phone = "drive" },
		check = function(ctx)
			ctx.me.player.knowsRitual = false
			ctx:advance(4)
			ctx:note("the summoning spell is not in the spellbook")
			if not lineWith(ctx, "isn't known yet") then ctx:fail("The Warlock has not learned the summoning spell and the Ready to drive list does not say so.", allText(ctx)) end
			ctx.me.player.knowsRitual = true
			ctx:advance(4)
			ctx:note("the Warlock learns the summoning spell")
			if lineWith(ctx, "isn't known yet") then ctx:fail("The Warlock learns the summoning spell and the list still says it isn't known.", allText(ctx)) end
			if not lineWith(ctx, "Knows the summoning spell") then ctx:fail("The Warlock learns the summoning spell and the list does not say Knows the summoning spell.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "ready.set_up_crew_button",
		area = "Ready",
		text = "When the list says the crew is not set up yet, its Set up my crew button opens the crew wizard.",
		source = "Ready to drive (Crew not set up yet: who summons with you? / Set up my crew)",
		kind = "scenario",
		needs = { role = "warlock", phone = "drive" },
		check = function(ctx)
			if not find(ctx, "Crew not set up yet") then ctx:na("the list does not say the crew is not set up") end
			if not press(ctx, "^Set up my crew$", { wait = 2 }) then ctx:fail("The Ready list says the crew is not set up and shows no Set up my crew button.", allText(ctx)) end
			if not find(ctx, "^Who summons with you%?") then ctx:fail("You tap Set up my crew and the crew wizard does not open.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "ready.choose_summoner_cure",
		area = "Ready",
		text = "When a runner who is not a Warlock has nobody picked to summon, the list says Choose who summons, and its Choose button leads to the wizard's Who summons? step.",
		source = "Ready to drive (Choose who summons / Choose)",
		kind = "scenario",
		needs = { role = "friend", phone = "drive" },
		check = function(ctx)
			ctx.me:slash("/wuber drive summoners clear")
			ctx:advance(2)
			ctx:note("/wuber drive summoners clear")
			if not lineWith(ctx, "^Choose who summons") then ctx:fail("A Mage runs the service with nobody picked to summon and the Ready list does not say Choose who summons.", allText(ctx)) end
			if not press(ctx, "^Choose$", { wait = 2 }) then ctx:fail("The list says Choose who summons and shows no Choose button.", allText(ctx)) end
			if not find(ctx, "^Who summons%?$") then ctx:fail("You tap Choose on the Ready list and the wizard's Who summons? step does not open.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "ready.helper_told_to_click",
		area = "Ready",
		text = "A helper in a Warlock's crew is told whose crew they are in and that they click the portal.",
		source = "Ready to drive (In X's crew: you click the portal)",
		kind = "scenario",
		needs = { role = "crew", phone = "drive" },
		when = function(sit) return sit.saved == nil or sit.saved == "fresh" end,
		check = function(ctx)
			if ctx.me.player.class == "WARLOCK" then ctx:na("a Warlock member, not a helper") end
			local l = lineWith(ctx, "crew: you click the portal")
			if not l then ctx:fail("A Priest is in a Warlock's crew and the Ready list does not say they click the portal.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "ready.status_command_lists",
		area = "Ready",
		text = "/wuber drive status says whether you are open and prints every line of the Ready to drive list.",
		source = "/wuber drive help (status)",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			local n = #ctx.me.chatLines
			ctx.me:slash("/wuber drive status")
			ctx:advance(1)
			ctx:note("/wuber drive status")
			local out = chatSince(ctx, n)
			if not out:find("Driving open", 1, true) then ctx:fail("You are open and /wuber drive status does not say Driving open: " .. out:gsub("\n", " / ")) end
			for _, l in ipairs(lines(ctx)) do
				if not out:find(tostring(l.text), 1, true) then
					ctx:fail("/wuber drive status leaves out a line the Ready to drive list shows: " .. tostring(l.text))
				end
			end
		end,
	}

	Hunt.promise{
		id = "ready.status_info_not_alarm",
		area = "Ready",
		text = "/wuber drive status marks only real problems with the red !!: a line that is plain information, such as how whispers go out, is not marked as one.",
		source = "inferred (the console shows information lines without a warning mark)",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			local n = #ctx.me.chatLines
			ctx.me:slash("/wuber drive status")
			ctx:advance(1)
			ctx:note("/wuber drive status")
			for i = n + 1, #ctx.me.chatLines do
				local raw = ctx.me.chatLines[i]
				if raw:find("ff5050 !!", 1, true) and raw:find("Whispers go out when you click the big button", 1, true) then
					ctx:fail("You type /wuber drive status and the line 'Whispers go out when you click the big button' is marked !! as a problem, though nothing is wrong.")
				end
			end
		end,
	}

	---------------------------------------------------------------------------
	-- the alert character (bell)
	---------------------------------------------------------------------------
	local function bellWindow(ctx)
		if ctx.w:player("Bell Ringer") then ctx:na("a name is taken") end
		local ok, c = pcall(ctx.w.addClient, ctx.w, "Bell Ringer", { spot = "Orgrimmar", class = "MAGE", money = 10000 })
		if not ok then ctx:cannot("could not add a second window: " .. tostring(c)) end
		ctx:advance(2)
		return c
	end
	local function bellName(ctx)
		local b = ctx.W.db and ctx.W.db.drive and ctx.W.db.drive.bell
		return b and b.name or ""
	end

	Hunt.promise{
		id = "bell.command_sets_and_clears",
		area = "Alert character",
		text = "/wuber drive bell <name> makes that character your alert character and says so, a bare /wuber drive bell tells you who it is, and off clears it.",
		source = "/wuber drive help (bell <name>); Settings (Alert character: Empty: off)",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			bellWindow(ctx)
			local n = #ctx.me.chatLines
			say2(ctx, "/wuber drive bell Bell Ringer")
			if key(bellName(ctx)) ~= key("Bell Ringer") then ctx:fail("You type /wuber drive bell Bell Ringer and your alert character is not saved as Bell Ringer.") end
			n = #ctx.me.chatLines
			say2(ctx, "/wuber drive bell")
			if not chatSince(ctx, n):find("Bell Ringer", 1, true) then ctx:fail("You type /wuber drive bell with an alert character set and it does not tell you who it is.") end
			n = #ctx.me.chatLines
			say2(ctx, "/wuber drive bell off")
			if bellName(ctx) ~= "" then ctx:fail("You type /wuber drive bell off and you still have an alert character.") end
			if not chatSince(ctx, n):find("No alert character", 1, true) then ctx:fail("You type /wuber drive bell off and it does not say there is no alert character now.") end
		end,
	}

	Hunt.promise{
		id = "bell.crewmate_refused",
		area = "Alert character",
		text = "Naming one of your own crew as the alert character does not work, and you are not told it did: the alert character has to be on another account.",
		source = "Settings tooltip (Alert character: A character on another account)",
		kind = "scenario",
		needs = { role = "friend" },
		check = function(ctx)
			local who = ctx.peers.summoner and ctx.peers.summoner.player.name
			if not who then ctx:cannot("no crew mate") end
			local n = #ctx.me.chatLines
			say2(ctx, "/wuber drive bell " .. who)
			-- (an alert character saved from before stays; only the crew mate being saved is a failure)
			if key(bellName(ctx)) == key(who) then ctx:fail("You name your own crew mate as the alert character and Wuber accepts it.") end
			if chatSince(ctx, n):find("Your alert character is", 1, true) then
				ctx:fail("You type /wuber drive bell with your own crew mate's name, Wuber refuses it, and the chat line still says: Your alert character is " .. who .. ".")
			end
		end,
	}

	Hunt.promise{
		id = "bell.test_reaches_other_window",
		area = "Alert character",
		text = "The test alert makes your alert character's window show a banner that names you and tells them to swap to you.",
		source = "Settings tooltip (Test the alert: it should flash, beep and show a banner)",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			local bc = bellWindow(ctx)
			local okSet, why = DR(ctx).BellSet("Bell Ringer")
			ctx:note("Alert character set to Bell Ringer")
			if okSet == false then ctx:fail("You set a character on another account as your alert character and Wuber refuses: " .. tostring(why)) end
			ctx:advance(3)
			local okT = DR(ctx).BellTest()
			ctx:note("Test the alert")
			ctx:advance(4)
			if not okT then ctx:fail("You press Test the alert with an alert character set and Wuber says it could not send.") end
			local seen = ""
			for _, t in ipairs(bc:visibleTexts()) do seen = seen .. strip(t) .. " | " end
			if not seen:find("Test", 1, true) then ctx:fail("You press Test the alert and the alert character's window shows no banner.", seen) end
			if not seen:find(strip(ctx.me.player.name):match("^%S+"), 1, true) then ctx:fail("You press Test the alert and the banner does not say who it is from.", seen) end
		end,
	}

	Hunt.promise{
		id = "bell.test_command_answers",
		area = "Alert character",
		text = "With no alert character set, pressing Test the alert in Settings tells you so (a note), not nothing.",
		source = "Settings > Driving (Test the alert: Test sent / No alert character set)",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			if bellName(ctx) ~= "" then ctx:na("an alert character is set") end
			local U = ctx.W.UI
			if type(U.OpenSettings) ~= "function" then ctx:cannot("no Settings") end
			if ctx.me.player.combat then ctx:na("in combat") end
			U.OpenSettings("drive")
			ctx:advance(1.2)
			ctx:note("open Settings > Driving")
			local b = U.settings and U.settings.controls and U.settings.controls["drive.bellTest"]
			if not (b and ctx:visible(b)) then ctx:cannot("no Test the alert button on screen") end
			ctx.me:clickOn(b)
			ctx:note("press Test the alert")
			local seen = false
			for _ = 1, 6 do
				ctx:advance(0.5)
				for _, t in ipairs(ctx:texts()) do
					if tostring(t):find("alert character", 1, true) or tostring(t):find("Test sent", 1, true) then seen = true end
				end
				if seen then break end
			end
			if not seen then ctx:fail("You have no alert character, press Test the alert in Settings and no note says anything.") end
		end,
	}

	Hunt.promise{
		id = "bell.nothing_without_character",
		area = "Alert character",
		text = "With no alert character set, no alert goes out to anybody when a rider whispers you.",
		source = "Drive.Bell header (Nothing goes when no alert character is set)",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			if bellName(ctx) ~= "" then ctx:na("an alert character is set") end
			if ctx.w:player("Zed Quick") then ctx:na("a name is taken") end
			ctx.w:addBot("Zed Quick", {})
			ctx.w:botWhisper("Zed Quick", ctx.me, "summon pls")
			ctx:advance(4)
			for _, e in ipairs(ctx.w.addonLog or {}) do
				if key(e.from) == key(ctx.name) and e.prefix == "WUBERT" and (tostring(e.text):find("^BE~") or tostring(e.text):find("^BH~")) then
					ctx:fail("You have no alert character, a rider whispers you, and Wuber still sends an alert message: " .. tostring(e.text):sub(1, 60))
				end
			end
		end,
	}

	---------------------------------------------------------------------------
	-- every /wuber drive command does what its help line says
	---------------------------------------------------------------------------
	local function strangerWhisper(ctx, name, text)
		if not ctx.w:player(name) then ctx.w:addBot(name, {}) end
		ctx.w:botWhisper(name, ctx.me, text)
		ctx:note("whisper from " .. name .. ": " .. text)
		ctx:advance(2)
	end
	local function listed(ctx, name) return DR(ctx).customers[key(name)] ~= nil end

	Hunt.promise{
		id = "drivecmd.pause_resume",
		area = "Drive commands",
		text = "/wuber drive pause says nobody new is invited and the console shows Paused; /wuber drive resume says Resumed and the console is open again.",
		source = "/wuber drive help (pause, resume)",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			noCombat(ctx)
			openDrive(ctx)
			local n = #ctx.me.chatLines
			say2(ctx, "/wuber drive pause")
			if not DR(ctx).IsPaused() then ctx:fail("You type /wuber drive pause and you are not paused.") end
			if not chatSince(ctx, n):find("Paused", 1, true) then ctx:fail("You type /wuber drive pause and it does not say you are paused.") end
			ctx:advance(1)
			if not find(ctx, "^Paused$") then ctx:fail("You type /wuber drive pause and the Drive console does not show Paused.", allText(ctx)) end
			n = #ctx.me.chatLines
			say2(ctx, "/wuber drive resume")
			if DR(ctx).IsPaused() then ctx:fail("You type /wuber drive resume and you are still paused.") end
			if not chatSince(ctx, n):find("Resumed", 1, true) then ctx:fail("You type /wuber drive resume and it does not say Resumed.") end
			ctx:advance(1)
			if find(ctx, "^Paused$") then ctx:fail("You type /wuber drive resume and the console still shows Paused.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "drivecmd.price_sets",
		area = "Drive commands",
		text = "/wuber drive price 2g sets your price to 2g, says so, and the console shows the new price.",
		source = "/wuber drive help (price 1g)",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			openDrive(ctx)
			local n = #ctx.me.chatLines
			say2(ctx, "/wuber drive price 2g")
			if ctx.W.Char().price ~= 20000 then say(ctx, "You type /wuber drive price 2g and your price is %s copper.", tostring(ctx.W.Char().price)) end
			if not chatSince(ctx, n):find("2g", 1, true) then ctx:fail("You type /wuber drive price 2g and the answer does not say 2g: " .. chatSince(ctx, n):gsub("\n", " / ")) end
			ctx:advance(2)
			if not find(ctx, "2g to") then ctx:fail("You set your price to 2g and the console does not show 2g.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "drivecmd.dest_sets",
		area = "Drive commands",
		text = "/wuber drive dest Orgrimmar makes you summon to Orgrimmar and says so; /wuber drive dest auto goes back to where you stand.",
		source = "/wuber drive help (dest <place> (or auto))",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			local n = #ctx.me.chatLines
			say2(ctx, "/wuber drive dest Orgrimmar")
			if not chatSince(ctx, n):find("You summon to Orgrimmar", 1, true) then ctx:fail("You type /wuber drive dest Orgrimmar and it does not say you summon to Orgrimmar: " .. chatSince(ctx, n):gsub("\n", " / ")) end
			if tostring(DR(ctx).Dest()) ~= "Orgrimmar" then say(ctx, "You type /wuber drive dest Orgrimmar and your place is %s.", tostring(DR(ctx).Dest())) end
			say2(ctx, "/wuber drive dest auto")
			if tostring(DR(ctx).Dest()) == "Orgrimmar" then ctx:fail("You type /wuber drive dest auto and you still summon to Orgrimmar.") end
		end,
	}

	Hunt.promise{
		id = "drivecmd.block_unblock",
		area = "Drive commands",
		text = "/wuber drive block <name> - <reason> stops a player being served and listed; /wuber drive unblock <name> serves them again.",
		source = "/wuber drive help (block, unblock)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		check = function(ctx)
			if ctx.w:player("Zed Quick") then ctx:na("a name is taken") end
			ctx.w:addBot("Zed Quick", {})
			local n = #ctx.me.chatLines
			say2(ctx, "/wuber drive block Zed Quick - never paid")
			if not chatSince(ctx, n):find("won't be served again", 1, true) then ctx:fail("You block a player by command and it does not say they won't be served again: " .. chatSince(ctx, n):gsub("\n", " / ")) end
			strangerWhisper(ctx, "Zed Quick", "summon pls")
			if listed(ctx, "Zed Quick") then ctx:fail("You block a player by command and when they whisper 'summon pls' they are put on your list.") end
			n = #ctx.me.chatLines
			say2(ctx, "/wuber drive unblock Zed Quick")
			if not chatSince(ctx, n):find("is served again", 1, true) then ctx:fail("You unblock a player by command and it does not say they are served again: " .. chatSince(ctx, n):gsub("\n", " / ")) end
			strangerWhisper(ctx, "Zed Quick", "summon pls")
			if not listed(ctx, "Zed Quick") then ctx:fail("You unblock a player by command and their next whisper 'summon pls' does not put them on your list.") end
		end,
	}

	Hunt.promise{
		id = "drivecmd.add_drop",
		area = "Drive commands",
		text = "/wuber drive add <name> puts a player on your list and invites them; /wuber drive drop <name> takes them off it.",
		source = "/wuber drive help (add <name> invites a player yourself; drop)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = function(sit) return sit.group ~= "raid" end,
		check = function(ctx)
			if ctx.w:player("Zed Quick") then ctx:na("a name is taken") end
			ctx.w:addBot("Zed Quick", { spot = "Orgrimmar" })
			say2(ctx, "/wuber drive add Zed Quick")
			ctx:advance(3)
			if not listed(ctx, "Zed Quick") then ctx:fail("You type /wuber drive add Zed Quick while open and they are not on your list.") end
			local invited = ctx.w:player("Zed Quick").group ~= nil
			if not invited then
				for _, e in ipairs(ctx.w.invites or {}) do if key(tostring(e.to or e.target or "")) == key("Zed Quick") then invited = true end end
			end
			if not invited and not (ctx.me.chatLines and #ctx.me.chatLines > 0) then ctx:fail("You type /wuber drive add Zed Quick and they are not invited.") end
			local n = #ctx.me.chatLines
			say2(ctx, "/wuber drive drop Zed Quick")
			if listed(ctx, "Zed Quick") then ctx:fail("You type /wuber drive drop Zed Quick and they are still on your list.") end
			if not chatSince(ctx, n):find("off the list", 1, true) then ctx:fail("You type /wuber drive drop Zed Quick and it does not say they are off the list.") end
		end,
	}

	Hunt.promise{
		id = "drivecmd.keywords_change_word",
		area = "Drive commands",
		text = "/wuber drive keywords hop makes 'hop' the word riders whisper: a whisper of 'hop' is listed, and the console names the new word.",
		source = "/wuber drive help (keywords); Drive console (whisper word)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		check = function(ctx)
			openDrive(ctx)
			say2(ctx, "/wuber drive keywords hop")
			ctx:advance(2)
			if not find(ctx, "[Ww]hisper word: hop") then ctx:fail("You set your request word to hop and the console does not say 'whisper word: hop'.", allText(ctx)) end
			strangerWhisper(ctx, "Zed Quick", "hop")
			if not listed(ctx, "Zed Quick") then ctx:fail("You set your request word to hop and a stranger who whispers 'hop' is not put on your list.") end
		end,
	}

	Hunt.promise{
		id = "drivecmd.raid_sell",
		area = "Drive commands",
		text = "/wuber drive raid switches you to raid summons and /wuber drive sell switches back to selling, each with a line saying which.",
		source = "/wuber drive help (raid / sell (raid summons or selling))",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		check = function(ctx)
			local n = #ctx.me.chatLines
			say2(ctx, "/wuber drive raid")
			if DR(ctx).Mode() ~= "raid" then ctx:fail("You type /wuber drive raid and you are not on raid summons.") end
			if not chatSince(ctx, n):find("Raid summons", 1, true) then ctx:fail("You type /wuber drive raid and it does not say raid summons.") end
			n = #ctx.me.chatLines
			say2(ctx, "/wuber drive sell")
			if DR(ctx).Mode() == "raid" then ctx:fail("You type /wuber drive sell and you are still on raid summons.") end
			if not chatSince(ctx, n):find("Selling summons", 1, true) then ctx:fail("You type /wuber drive sell and it does not say you are selling summons.") end
		end,
	}

	Hunt.promise{
		id = "drivecmd.help_words_exist",
		area = "Drive commands",
		text = "Every command the /wuber drive help lines name is a command: none of them answers Unknown.",
		source = "/wuber drive help",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			local n = #ctx.me.chatLines
			say2(ctx, "/wuber drive help")
			local words = {}
			for i = n + 1, #ctx.me.chatLines do
				for w in ctx.me.chatLines[i]:gmatch("|cffffd200([%a]+)[^|]*|r") do words[#words + 1] = w end
			end
			if #words < 20 then ctx:cannot("the help names only " .. #words .. " commands") end
			local skip = { ad = true, retry = true, log = true, add = true, drop = true, paid = true, block = true, unblock = true, market = true, public = true }
			for _, w in ipairs(words) do
				if not skip[w] then
					local before = #ctx.me.chatLines
					pcall(ctx.me.slash, ctx.me, "/wuber drive " .. w)
					ctx:advance(0.5)
					if chatSince(ctx, before):find("Unknown: " .. w, 1, true) then
						ctx:fail("The /wuber drive help names the command '" .. w .. "' and typing it answers Unknown.")
					end
				end
			end
		end,
	}

	Hunt.promise{
		id = "drivecmd.switches_flip",
		area = "Drive commands",
		text = "Each switch the /wuber drive help lists (for example oneatatime) turns on and off with 'on' and 'off', says which, and the setting really changes.",
		source = "/wuber drive help (Switches, each with on or off)",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			local T = DR(ctx).COMMAND_TOGGLES
			if type(T) ~= "table" then ctx:cannot("no switch table") end
			local names = {}
			for k in pairs(T) do names[#names + 1] = k end
			table.sort(names)
			for _, name in ipairs(names) do
				local sw = T[name]
				if name ~= "market" then
					for _, v in ipairs({ "off", "on" }) do
						local n = #ctx.me.chatLines
						pcall(ctx.me.slash, ctx.me, "/wuber drive " .. name .. " " .. v)
						ctx:advance(0.3)
						local out = chatSince(ctx, n)
						local now
						if sw.db then now = ctx.W.db[sw.key] else now = DR(ctx).opts()[sw.key] end
						if (now ~= false) ~= (v == "on") then
							ctx:fail("You type /wuber drive " .. name .. " " .. v .. " and the setting is " .. tostring(now ~= false and "on" or "off") .. ".")
						end
						if not out:find(": " .. v .. ".", 1, true) then
							ctx:fail("You type /wuber drive " .. name .. " " .. v .. " and the answer does not say " .. v .. ": " .. out:gsub("\n", " / "))
						end
					end
				end
			end
		end,
	}

	Hunt.promise{
		id = "drivecmd.unknown_word_helps",
		area = "Drive commands",
		text = "A /wuber drive word that is not a command says it is unknown and points you to /wuber drive help.",
		source = "/wuber drive (Unknown: ... lists the commands)",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			local n = #ctx.me.chatLines
			say2(ctx, "/wuber drive banana")
			local out = chatSince(ctx, n)
			if not (out:find("Unknown", 1, true) and out:find("/wuber drive help", 1, true)) then
				ctx:fail("You type /wuber drive banana and the answer does not point you to /wuber drive help: " .. out:gsub("\n", " / "))
			end
		end,
	}

	---------------------------------------------------------------------------
	-- the floating big button and the mini list
	---------------------------------------------------------------------------
	local function bigVisible(ctx)
		local b = ctx.me.env.WuberDriveButton
		return b ~= nil and ctx:visible(b)
	end
	local function closePhone(ctx)
		local UI = ctx.W.UI
		if UI.IsShown and UI.IsShown() then
			UI.Toggle(false)
			ctx:advance(1)
			ctx:note("close the phone")
		end
		if UI.IsShown and UI.IsShown() then ctx:cannot("the phone would not close") end
	end

	Hunt.promise{
		id = "button.names_waiting_rider",
		area = "Big button",
		text = "With the Wuber window closed and a rider waiting, the floating big button names that rider and the mini list under it shows them.",
		source = "Settings tooltip (Show the big button: Shows the floating big button (with the mini list under it) while the Wuber window is closed)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = function(sit) return opt(sit, "button_shown") ~= "off" and sit.group ~= "raid" end,
		check = function(ctx)
			noCombat(ctx)
			closePhone(ctx)
			strangerWhisper(ctx, "Zed Quick", "summon pls")
			ctx:advance(2)
			if not bigVisible(ctx) then ctx:fail("You are open with a rider waiting, the Wuber window is closed and the big button is not on screen.", allText(ctx)) end
			local seen = false
			for _, t in ipairs(ctx:texts()) do if strip(t):find("Zed") then seen = true end end
			if not seen then ctx:fail("A rider waits, the Wuber window is closed and neither the big button nor the mini list names them.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "button.hide_show_commands",
		area = "Big button",
		text = "/wuber drive hide takes the big button and its mini list off the screen, even with a rider waiting; /wuber drive show brings them back.",
		source = "/wuber drive help (show, hide); Settings tooltip (Show the big button)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = function(sit) return sit.group ~= "raid" end,
		check = function(ctx)
			noCombat(ctx)
			closePhone(ctx)
			strangerWhisper(ctx, "Zed Quick", "summon pls")
			ctx:advance(2)
			if not bigVisible(ctx) then ctx:na("the big button is not up to begin with") end
			say2(ctx, "/wuber drive hide")
			if bigVisible(ctx) then ctx:fail("You type /wuber drive hide and the big button is still on screen.", allText(ctx)) end
			for _, t in ipairs(ctx:texts()) do
				if strip(t):find("^Summon Zed") then ctx:fail("You type /wuber drive hide and the big button's words are still on screen.") end
			end
			say2(ctx, "/wuber drive show")
			if not bigVisible(ctx) then ctx:fail("You type /wuber drive show and the big button does not come back.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "button.closed_hides_unless_kept",
		area = "Big button",
		text = "When you close, with nobody on your list, the big button leaves the screen, unless 'Keep it on screen when closed' is on.",
		source = "Settings tooltip (Keep it on screen when closed: Keeps the big button on screen while you're closed and nobody is in your list)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = function(sit) return opt(sit, "button_keepClosed") ~= "on" end,
		check = function(ctx)
			noCombat(ctx)
			closePhone(ctx)
			ctx.me:slash("/wuber drive close")
			ctx:advance(3)
			ctx:note("/wuber drive close")
			if DR(ctx).IsOpen() then ctx:cannot("still open") end
			if next(DR(ctx).customers) ~= nil then ctx:na("somebody is on the list") end
			if bigVisible(ctx) then ctx:fail("You close with nobody on your list and 'Keep it on screen when closed' off, and the big button is still on screen.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "button.keep_closed_keeps",
		area = "Big button",
		text = "With 'Keep it on screen when closed' on, the big button stays on screen after you close with nobody on your list.",
		source = "Settings tooltip (Keep it on screen when closed)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", button_keepClosed = "on" },
		when = function(sit) return opt(sit, "button_shown") ~= "off" end,
		check = function(ctx)
			noCombat(ctx)
			closePhone(ctx)
			ctx.me:slash("/wuber drive close")
			ctx:advance(3)
			ctx:note("/wuber drive close")
			if DR(ctx).IsOpen() then ctx:cannot("still open") end
			if not bigVisible(ctx) then ctx:fail("'Keep it on screen when closed' is on, you close with nobody on your list and the big button leaves the screen.", allText(ctx)) end
		end,
	}

	Hunt.promise{
		id = "button.lock_stops_drag",
		area = "Big button",
		text = "Locked, the big button does not move when you shift-drag it; unlocked it does, and /wuber drive resetpos puts it back where it started.",
		source = "Settings tooltip (Lock the big button: Locked: shift-drag doesn't move the floating big button); /wuber drive help (lock, unlock, resetpos)",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = function(sit) return opt(sit, "button_shown") ~= "off" end,
		check = function(ctx)
			noCombat(ctx)
			closePhone(ctx)
			local b = ctx.me.env.WuberDriveButton
			if not (b and ctx:visible(b)) then ctx:na("no floating big button") end
			if not (b.IsMovable and b:IsMovable() or b.IsMovable == nil) then ctx:na("the button cannot be moved") end
			local function pos() return ("%.0f,%.0f"):format(b:GetLeft() or -1, b:GetBottom() or -1) end
			-- where the button starts: the place /wuber drive resetpos gives (a saved place may differ)
			say2(ctx, "/wuber drive resetpos")
			local start = pos()
			ctx.me.mods = ctx.me.mods or {}
			ctx.me.mods.shift = true
			say2(ctx, "/wuber drive lock")
			pcall(ctx.me.drag, ctx.me, b, -150, 100)
			ctx:advance(1)
			local locked = pos()
			say2(ctx, "/wuber drive unlock")
			pcall(ctx.me.drag, ctx.me, b, -150, 100)
			ctx:advance(1)
			local moved = pos()
			ctx.me.mods.shift = false
			if locked ~= start then ctx:fail("You lock the big button, shift-drag it, and it moves anyway.") end
			if moved == start then ctx:fail("You unlock the big button, shift-drag it, and it does not move.") end
			say2(ctx, "/wuber drive resetpos")
			if pos() ~= start then ctx:fail("You type /wuber drive resetpos after moving the big button and it is not back where resetpos put it before.") end
		end,
	}

	Hunt.promise{
		id = "button.bind_says_key",
		area = "Big button",
		text = "/wuber drive bind F5 puts the big button on F5 and says so; /wuber drive bind none removes it and says so.",
		source = "/wuber drive help (bind F5); Settings (Key for the big button: Clear removes it)",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			noCombat(ctx)
			local n = #ctx.me.chatLines
			say2(ctx, "/wuber drive bind F5")
			if not chatSince(ctx, n):find("F5", 1, true) then ctx:fail("You type /wuber drive bind F5 and the answer does not say F5: " .. chatSince(ctx, n):gsub("\n", " / ")) end
			local k = ctx.W.db.drive.button and ctx.W.db.drive.button.key
			if k ~= "F5" then ctx:fail("You type /wuber drive bind F5 and the saved key is " .. tostring(k) .. ".") end
			n = #ctx.me.chatLines
			say2(ctx, "/wuber drive bind none")
			if ctx.W.db.drive.button and ctx.W.db.drive.button.key then ctx:fail("You type /wuber drive bind none and a key is still saved: " .. tostring(ctx.W.db.drive.button.key)) end
			if not chatSince(ctx, n):find("Key removed", 1, true) then ctx:fail("You type /wuber drive bind none and it does not say the key is removed.") end
		end,
	}

end
