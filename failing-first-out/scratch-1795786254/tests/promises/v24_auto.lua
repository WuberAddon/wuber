-- Promises about Auto mode and Oops (the careful auto mode of 2.4; job 146). LOGIC ONLY: what is sent, saved, counted.
-- Written from what the player is told: the 2.4.0 change log ("An auto mode you can trust"), the header of Drive/Careful.lua,
-- the Drive tab's record line ("214 auto-invites . 0 wrong") and the big button's "Oops: remove <name>" step.
return function(Hunt)
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end
	local function DR(ctx) return ctx.W.Drive end
	local function warlock(sit) return sit.role == "warlock" end
	local function invitesTo(ctx, name)
		local n, k = 0, key(name)
		for _, inv in ipairs(ctx.w.invites or {}) do if key(inv.to) == k then n = n + 1 end end
		return n
	end
	local function whispersTo(ctx, name)
		local out, k = {}, key(name)
		for _, x in ipairs(ctx.w.whispers or {}) do
			if key(x.from) == key(ctx.name) and key(x.to) == k then out[#out + 1] = x end
		end
		return out
	end
	local function stranger(ctx, name, text, opts)
		local w = ctx.w
		if not w:player(name) then w:addBot(name, opts or { acceptsInvites = false }) end
		w:botWhisper(name, ctx.me, text)
		ctx:note("whisper from " .. name .. ": " .. text)
		ctx:advance(3)
		return DR(ctx).customers[key(name)]
	end
	local function ready(ctx)
		local d = DR(ctx)
		if not (d and d.IsOpen and d.IsOpen()) then ctx:na("the driver is not open") end
		if ctx.me.player.combat then ctx:na("in combat") end
		if d.Role() ~= "driver" or not d.IsLeader() then ctx:na("not the group's driver") end
		d.opts().autoInvite = true
		return d
	end
	local function press(ctx)
		local b = ctx.me.env.WuberDriveButton
		if not (b and ctx:visible(b)) then ctx:cannot("the big button is not up") end
		ctx.me:click(b)
		ctx:note("click the big button")
		ctx:advance(2)
	end
	local function record(ctx) local a, wr = DR(ctx).AutoRecord() return a, wr end
	local CLEAR = "summ pls"

	Hunt.promise{
		id = "careful.clear_whisper_invites_once",
		area = "Auto mode",
		text = "A whisper that clearly asks you for a summon is invited once by itself, the row is marked as an automatic invite, and the record counts one auto-invite.",
		source = "release/CHANGELOG-2.4.0.md 'An auto mode you can trust'",
		kind = "scenario", when = warlock,
		check = function(ctx)
			local d = ready(ctx)
			local a0 = record(ctx)
			if d.GroupSize() >= 5 then ctx:na("the group is full or in a raid: no room to invite") end
			-- a name that no situation's own rider uses (the ride dials already have a Dan Miller in the group)
			local who = "Zed Hart"
			if DR(ctx).customers[key(who)] or ctx.w:player(who) then ctx:na(who .. " is already a customer or a player here") end
			local c = stranger(ctx, who, CLEAR)
			if invitesTo(ctx, who) ~= 1 then
				ctx:fail("A stranger whispers '" .. CLEAR .. "' and gets " .. invitesTo(ctx, who) .. " invites instead of one.")
			end
			if not (c and c.auto == "whisper") then ctx:fail("An invite Wuber sent by itself is not marked automatic, so Oops is not offered for it.") end
			local a1 = record(ctx)
			if a1 ~= a0 + 1 then ctx:fail("One automatic invite went out and the record moved from " .. a0 .. " to " .. a1 .. ".") end
		end,
	}

	Hunt.promise{
		id = "careful.unsure_waits_as_lead",
		area = "Auto mode",
		text = "A whisper Wuber is not sure about (a question, an offer, an unknown word) invites nobody and waits as a lead; one click on it invites.",
		source = "release/CHANGELOG-2.4.0.md 'An auto mode you can trust'",
		kind = "scenario", when = warlock,
		check = function(ctx)
			local d = ready(ctx)
			local c = stranger(ctx, "Eve Stone", "LF sleeping bag summons")
			if invitesTo(ctx, "Eve Stone") ~= 0 then ctx:fail("An unclear whisper was invited by itself.") end
			if not (c and c.state == "lead") then ctx:na("the line did not become a lead here (" .. tostring(c and c.state) .. ")") end
			if c.auto then ctx:fail("A lead you have not clicked is already marked as an automatic invite.") end
			-- with another rider still being invited or riding (the ride dials) the invite waits its turn: the click moves the lead into the queue
			local busy = d.Busy and d.Busy()
			local made = d.Invite(c)
			ctx:advance(3)
			if busy then
				if c.state == "lead" then ctx:fail("You click a lead while another rider is being served and nothing happens: it is still a lead.") end
				ctx:note("another rider is being served: the click queues the lead (state " .. tostring(c.state) .. ")")
			elseif invitesTo(ctx, "Eve Stone") ~= 1 then
				ctx:fail("You click a lead and it does not invite them.")
			end
			if made and d.CanOops(made) then ctx:fail("A lead you invited yourself offers Oops, as if Wuber had invited it by itself.") end
		end,
	}

	Hunt.promise{
		id = "careful.seller_never_invites",
		area = "Auto mode",
		text = "A line with a seller's word ('WTS', 'whisper me', 'pst') never invites by itself, in a whisper or in public chat, whatever your settings.",
		source = "release/CHANGELOG-2.4.0.md 'An auto mode you can trust'",
		kind = "scenario", when = warlock,
		check = function(ctx)
			local d = ready(ctx)
			d.opts().watchPublic = true
			d.opts().autoPublic = true
			local lines = { "WTS summons to Orgrimmar 1g, whisper me inv", "selling summ pls", "summ pls pst", "summ pls, dm me" }
			for i, text in ipairs(lines) do
				local name = ({ "Sam One", "Sam Two", "Sam Three", "Sam Four" })[i]
				stranger(ctx, name, text)
				if invitesTo(ctx, name) ~= 0 then ctx:fail("A whisper '" .. text .. "' was invited by itself though it is a seller's line.") end
				if d.Careful(text, "public", name .. "x") == "invite" then ctx:fail("The public line '" .. text .. "' would be invited by itself though it is a seller's line.") end
			end
		end,
	}

	Hunt.promise{
		id = "careful.auto_off_invites_nobody",
		area = "Auto mode",
		text = "With 'invite riders who whisper you' off, a clear whisper invites nobody, and the record does not count an auto-invite that never went out.",
		source = "release/CHANGELOG-2.4.0.md (the record: 'N auto-invites'); Queue.lua:508 counts the row, not the invite",
		kind = "scenario", when = warlock,
		check = function(ctx)
			local d = ready(ctx)
			d.opts().autoInvite = false
			ctx:note("switch automatic inviting off")
			local a0 = record(ctx)
			stranger(ctx, "Fay Wood", CLEAR)
			if invitesTo(ctx, "Fay Wood") ~= 0 then ctx:fail("Automatic inviting is off and a whisper was invited anyway.") end
			local a1 = record(ctx)
			if a1 ~= a0 then ctx:fail("Automatic inviting is off, nobody was invited, and the Drive tab's record still counts " .. (a1 - a0) .. " more auto-invite.") end
		end,
	}

	-- a rider Wuber invited by itself and who has joined the group
	local function joinedAuto(ctx, name)
		local d = ready(ctx)
		d.opts().kickAfter = false
		local c = stranger(ctx, name, CLEAR, { acceptsInvites = true })
		ctx:advance(2)
		c = d.customers[key(name)]
		if not (c and c.auto == "whisper" and (c.state == "joined" or c.state == "invited")) then
			ctx:na("the auto-invited rider is not in the group here (" .. tostring(c and c.state) .. ")")
		end
		return d, c
	end

	Hunt.promise{
		id = "careful.oops_waits_for_your_click",
		area = "Auto mode",
		text = "Oops says nothing and removes nobody until your next click on the big button; that one click whispers sorry once and takes them out of the group. (job 146: in whisper mode 'box' the sorry goes into the chat box for the player's Enter, and in 'off' no whisper is sent; Plan.lua:515-528, Chat.lua DR.ChatMode.)",
		source = "release/CHANGELOG-2.4.0.md: 'Your next click on the big button says sorry and takes them out of the group'",
		kind = "scenario", when = warlock,
		check = function(ctx)
			local d, c = joinedAuto(ctx, "Gil Moss")
			if not d.Oops(c) then ctx:fail("Oops on a rider Wuber invited by itself is refused.") end
			ctx:advance(3)
			if #whispersTo(ctx, "Gil Moss") ~= 0 then ctx:fail("Oops whispered the rider before you clicked the big button.") end
			press(ctx)
			local sent = whispersTo(ctx, "Gil Moss")
			local cm = type(d.ChatMode) == "function" and d.ChatMode() or "macro"
			if cm == "box" then
				-- (job 146) the whisper waits in the chat box for the player's Enter: nothing sent yet, but it is boxed for Gil
				local b = d.boxed
				if #sent ~= 0 then ctx:fail("In whisper mode box one click on Oops sent " .. #sent .. " whispers by itself instead of putting sorry in the chat box.") end
				if not (type(b) == "table" and b.kind == "oops" and b.key == key("Gil Moss")) then
					ctx:fail("In whisper mode box you click Oops and the sorry whisper is not put into your chat box.")
				end
			elseif cm == "off" then
				if #sent ~= 0 then ctx:fail("Whispers are off and one click on Oops whispered the rider anyway.") end
			elseif #sent ~= 1 then ctx:fail("One click on Oops sent " .. #sent .. " sorry whispers instead of one.") end
			local p = ctx.w:player("Gil Moss")
			if p and p.group ~= nil and p.group == ctx.me.player.group then ctx:fail("You clicked Oops and the rider is still in your group.") end
			press(ctx)
			if #whispersTo(ctx, "Gil Moss") ~= #sent then ctx:fail("A second click sent the sorry whisper again.") end
		end,
	}

	Hunt.promise{
		id = "careful.oops_learns_player_and_words",
		area = "Auto mode",
		text = "After Oops, that player and those words become leads from then on; other players with other words are still invited.",
		source = "release/CHANGELOG-2.4.0.md: 'Wuber then remembers that player and those words on your PC'",
		kind = "scenario", when = warlock,
		check = function(ctx)
			local d = ready(ctx)
			local c = stranger(ctx, "Hal Reed", "summ pls")
			if not (c and d.CanOops(c)) then ctx:na("no auto row to oops") end
			d.Oops(c)
			ctx:advance(1)
			if d.Careful("summ pls", "whisper", "Hal Reed") ~= "lead" then ctx:fail("You marked Hal's invite wrong and he is invited by itself the next time he whispers.") end
			if d.Careful("summ pls", "whisper", "Other Person") ~= "lead" then ctx:fail("You marked these words wrong and somebody else saying them is invited by itself.") end
			if d.Careful("need a summon", "whisper", "Third Person") ~= "invite" then ctx:fail("After one Oops, a different clear request from a stranger is no longer invited by itself.") end
		end,
	}

	Hunt.promise{
		id = "careful.oops_only_for_auto_rows",
		area = "Auto mode",
		text = "Oops is offered only for a rider Wuber invited by itself and not yet paid or done; never for one you added, a lead, or a row already oops'd.",
		source = "release/CHANGELOG-2.4.0.md; Careful.lua DR.CanOops",
		kind = "scenario", when = warlock,
		check = function(ctx)
			local d = ready(ctx)
			ctx.w:addBot("Ida Frost", { acceptsInvites = false })
			local m = d.Request("Ida Frost", "manual")
			ctx:advance(2)
			if m and d.CanOops(m) then ctx:fail("Oops is offered for a rider you added by hand.") end
			local c = stranger(ctx, "Jon Hale", CLEAR)
			if not (c and d.CanOops(c)) then ctx:na("no auto row") end
			if not d.Oops(c) then ctx:cannot("oops refused") end
			if d.CanOops(c) or d.Oops(c) then ctx:fail("A second Oops on the same rider is accepted.") end
			local paid = { key = "x y", name = "X Y", state = "paid", auto = "whisper", autoMsg = CLEAR }
			if d.CanOops(paid) then ctx:fail("Oops is offered for a rider who has already paid.") end
		end,
	}

	Hunt.promise{
		id = "careful.oops_counts_wrong_once",
		area = "Auto mode",
		text = "One Oops adds exactly one to the record's 'wrong' and never more wrong than auto-invites.",
		source = "release/CHANGELOG-2.4.0.md: the record '214 auto-invites . 0 wrong'",
		kind = "scenario", when = warlock,
		check = function(ctx)
			local d = ready(ctx)
			local c = stranger(ctx, "Kay Pine", CLEAR)
			if not (c and d.CanOops(c)) then ctx:na("no auto row") end
			local a0, w0 = record(ctx)
			d.Oops(c)
			d.Oops(c)
			local a1, w1 = record(ctx)
			if w1 ~= w0 + 1 then ctx:fail("You marked one invite wrong and the record's 'wrong' moved from " .. w0 .. " to " .. w1 .. ".") end
			if w1 > a1 then ctx:fail("The record shows more wrong invites (" .. w1 .. ") than auto-invites (" .. a1 .. ").") end
		end,
	}

	Hunt.promise{
		id = "careful.oops_learning_survives_reload",
		area = "Auto mode",
		text = "What Oops taught Wuber (the player, the words, the record) is still there after a /reload.",
		source = "release/CHANGELOG-2.4.0.md: 'on your PC'",
		kind = "scenario", when = warlock,
		check = function(ctx)
			local d = ready(ctx)
			local c = stranger(ctx, "Lee Marsh", "summ pls")
			if not (c and d.CanOops(c)) then ctx:na("no auto row") end
			d.Oops(c)
			local a0, w0 = record(ctx)
			ctx:reload()
			ctx:advance(5)
			local d2 = DR(ctx)
			if not d2 then ctx:cannot("no Drive after reload") end
			if d2.Careful("summ pls", "whisper", "Lee Marsh") ~= "lead" then ctx:fail("After a /reload Wuber has forgotten the player you marked as a wrong invite.") end
			if d2.Careful("summ pls", "whisper", "Nobody New") ~= "lead" then ctx:fail("After a /reload Wuber has forgotten the words you marked as a wrong invite.") end
			local a1, w1 = d2.AutoRecord()
			if a1 ~= a0 or w1 ~= w0 then ctx:fail("After a /reload the record reads " .. a1 .. " auto, " .. w1 .. " wrong instead of " .. a0 .. ", " .. w0 .. ".") end
		end,
	}

	Hunt.promise{
		id = "careful.oops_owed_survives_reload",
		area = "Auto mode",
		text = "If you click Oops and then /reload before the big button click, the sorry and the removal are still owed.",
		source = "inferred: Oops is a step that waits for the next click",
		kind = "scenario", when = warlock,
		check = function(ctx)
			local d, c = joinedAuto(ctx, "Max Dale")
			d.Oops(c)
			ctx:advance(1)
			ctx:reload()
			ctx:advance(5)
			local p = ctx.w:player("Max Dale")
			local stillIn = p and p.group ~= nil and p.group == ctx.me.player.group
			if not stillIn then ctx:na("the rider is no longer in the group after the reload") end
			local plan = DR(ctx).Plan()
			if not (plan and plan.title and plan.title:find("Oops", 1, true)) then
				ctx:fail("You clicked Oops and reloaded: the rider is still in your group and the big button no longer offers to remove them.")
			end
		end,
	}

	Hunt.promise{
		id = "careful.oops_rider_who_left",
		area = "Auto mode",
		text = "If an oops'd rider leaves the group by himself before your click, the big button does not stay stuck on 'Oops: remove' for somebody who is gone.",
		source = "inferred: a state that is never cleared",
		kind = "scenario", when = warlock,
		check = function(ctx)
			local d, c = joinedAuto(ctx, "Ned Oak")
			d.Oops(c)
			ctx:advance(1)
			local p = ctx.w:player("Ned Oak")
			if not (p and p.group) then ctx:na("not in the group") end
			ctx.w:leave("Ned Oak")
			ctx:note("Ned leaves the group")
			ctx:advance(6)
			local plan = d.Plan()
			if plan and plan.title and plan.title:find("Oops", 1, true) then
				ctx:fail("The rider left the group and the big button still says '" .. plan.title .. "'.")
			end
		end,
	}
end
