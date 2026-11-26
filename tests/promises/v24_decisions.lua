-- Promises about the decisions round of 2.4 (tests/promises/v24_decisions.lua; job 097).
-- Sources: release/CHANGELOG-2.4.0.md "Answers of 21 November (the decisions round)", For players. Payment by mail (Drive/Mail.lua: read-only,
-- "Mail seen: ...", a mail never marks a ride paid), the three lines that may go by themselves (Drive/AutoLines.lua: each its own switch,
-- all off, never in combat, a raid or an instance, never to anyone who did not ask), Close asks first, waiting in a driver's line, the Undo
-- line, the "What Wuber sends" row, one rule for the cards that open by themselves.
return function(Hunt)
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end
	local function DRof(ctx) return ctx.W.Drive end
	local function isDriver(sit) return sit.role == "warlock" end
	local function notFirst(sit) return sit.session ~= "first" end
	local function promise(p)
		p.area = "Decisions 2.4"
		p.kind = p.kind or "scenario"
		Hunt.promise(p)
	end
	local function waitFor(ctx, pred, max, step)
		step = step or 0.5
		local t = 0
		while not pred() do
			if t >= max then return false end
			ctx:advance(step)
			t = t + step
		end
		return true
	end
	-- the whispers MY window sent by itself (how = "auto"), to one person or to anyone
	local function autos(ctx, name)
		local out = {}
		for _, x in ipairs(ctx.w.whispers) do
			if x.how == "auto" and x.from == ctx.name and (not name or key(x.to) == key(name)) then out[#out + 1] = x end
		end
		return out
	end
	local function sentTo(ctx, name, find)
		local n = 0
		for _, x in ipairs(ctx.w.whispers) do
			if x.from == ctx.name and key(x.to) == key(name) and tostring(x.text):find(find, 1, true) then n = n + 1 end
		end
		return n
	end
	-- the saved data the game would hold at login: the lines' switches on (the way Messages saves them)
	local function linesSaved(ctx, kinds)
		local s = ctx.saved
		if type(s) ~= "table" then s = {} ctx.saved = s end
		s.Wuber = s.Wuber or {}
		s.Wuber.drive = s.Wuber.drive or {}
		local l = s.Wuber.drive.lines or {}
		s.Wuber.drive.lines = l
		for _, k in ipairs(kinds) do l[k] = true end
	end
	local function myRider(ctx)
		local r = ctx.peers.rider
		if not r then ctx:cannot("no rider window") end
		return r.player.name, r
	end
	local function reqText(ctx)
		local d = DRof(ctx).Dest and DRof(ctx).Dest()
		return "summon " .. ((type(d) == "string" and d ~= "") and d or "Ratchet")
	end
	local function row(ctx, name)
		return DRof(ctx).customers and DRof(ctx).customers[key(name)]
	end
	local function startFacts(ctx)
		if not (DRof(ctx) and DRof(ctx).LineOn) then ctx:cannot("no AutoLines module") end
	end

	---------------------------------------------------------------------------
	-- the three lines that may go by themselves
	---------------------------------------------------------------------------
	promise{
		id = "dec.lines_off_by_default",
		text = "The greeting, the pay reminder and 'You're next' are all off until you switch them on: with a rider landed and left waiting for minutes, your window whispers nobody by itself, and no fourth line can be switched on.",
		source = "CHANGELOG 2.4.0 decisions round (Messages: three lines can go by themselves, each with its own switch, all off until you switch them on)",
		needs = { role = "warlock", ride = "arrived" },
		when = notFirst,
		check = function(ctx)
			startFacts(ctx)
			local DR = DRof(ctx)
			for _, k in ipairs({ "greet", "pay", "next" }) do
				if DR.LineOn(k) then ctx:na("the saved data already has " .. k .. " switched on") end
			end
			ctx:advance(150)
			if #autos(ctx) > 0 then
				ctx:fail("You never switched on a line that goes by itself, and your window whispered a rider by itself anyway.", tostring(autos(ctx)[1].text))
			end
			if DR.SetLineOn("thanks", true) or DR.LineOn("thanks") then ctx:fail("A fourth message (Thanks) can be made to go by itself, though only three lines may.") end
		end,
	}

	promise{
		id = "dec.lines_greet_once",
		text = "With the greeting's switch on, your own rider gets your greeting once when you start their summon, by itself; the big button does not whisper it a second time.",
		source = "CHANGELOG 2.4.0 (the greeting, when you start their summon); AutoLines.lua header",
		needs = { role = "warlock", ride = "summoning" },
		when = notFirst,
		pre = function(ctx) linesSaved(ctx, { "greet" }) end,
		check = function(ctx)
			startFacts(ctx)
			local name = myRider(ctx)
			local DR = DRof(ctx)
			if not DR.LineOn("greet") then ctx:na("the greeting's switch did not stay on at login") end
			if DR.ChatMode and DR.ChatMode() == "off" then ctx:na("whispers are switched off (How whispers are sent: Off)") end
			if ctx.me.player.combat then ctx:na("in combat") end
			local c = row(ctx, name)
			if not c then ctx:na("the rider is not on my list") end
			if c.source ~= "wuber" and c.source ~= "whisper" then ctx:na("the rider did not ask by the app or a whisper: " .. tostring(c.source)) end
			ctx:advance(5)
			local greet = DR.Text("greet", c)
			local n = sentTo(ctx, name, greet)
			if n == 0 then ctx:fail("You switched the greeting on, started your rider's summon, and no greeting reached them.") end
			if n > 1 then ctx:fail("Your rider got your greeting " .. n .. " times for one summon.") end
			if #autos(ctx, name) ~= 1 then ctx:fail("The greeting did not go by itself (" .. #autos(ctx, name) .. " lines by itself).") end
		end,
	}

	promise{
		id = "dec.lines_pay_once",
		text = "With the pay reminder's switch on, a rider who landed and has not paid gets the reminder once by themselves, and not again on the same ride, however long it takes.",
		source = "CHANGELOG 2.4.0 (the pay reminder, 25 seconds after they land); AutoLines.lua header (once per ride)",
		needs = { role = "warlock", ride = "arrived" },
		when = notFirst,
		pre = function(ctx) linesSaved(ctx, { "pay" }) end,
		check = function(ctx)
			startFacts(ctx)
			local name = myRider(ctx)
			local DR = DRof(ctx)
			if not DR.LineOn("pay") then ctx:na("the pay reminder's switch did not stay on") end
			if DR.ChatMode and DR.ChatMode() == "off" then ctx:na("whispers are switched off (How whispers are sent: Off)") end
			if ctx.W.InCombat and ctx.W.InCombat() then ctx:na("in combat: the line waits for its click") end
			local c = row(ctx, name)
			if not c or c.state ~= "arrived" then ctx:na("the rider is not landed on my list") end
			if DR.opts().remindPay == false then ctx:na("Remind riders who haven't paid is off") end
			ctx:advance(60)
			local pay = DR.Text("pay", c)
			local n = sentTo(ctx, name, pay)
			if n == 0 then ctx:fail("You switched the pay reminder on, your rider landed a minute ago without paying, and no reminder came.") end
			ctx:advance(400)
			local m = sentTo(ctx, name, pay)
			if m > n or m > 1 then ctx:fail("The pay reminder went to the same rider " .. m .. " times on one ride.") end
		end,
	}

	promise{
		id = "dec.lines_never_busy",
		text = "A line that goes by itself is never sent while you are in combat or in an instance; the rider is not whispered later for it either.",
		source = "CHANGELOG 2.4.0 (never in combat, in a raid or in an instance); AutoLines.lua header",
		needs = { role = "warlock", ride = "none", group = "solo" },
		when = notFirst,
		pre = function(ctx) linesSaved(ctx, { "greet", "pay", "next" }) end,
		check = function(ctx)
			startFacts(ctx)
			local DR, w, me = DRof(ctx), ctx.w, ctx.me
			if not (DR.Selling and DR.Selling()) then ctx:na("not open") end
			if me.player.combat then ctx:na("in combat from the start") end
			DR.opts().autoInvite = true
			local function asker(n)
				w:addBot(n, { spot = "Orgrimmar" })
				w:botWhisper(n, me, reqText(ctx))
				ctx:advance(3)
				local c = row(ctx, n)
				if not c then ctx:na("the whisper did not make a row") end
				if c.state == "lead" then ctx:na("the whisper made only a lead, not a rider (" .. tostring(c.state) .. ")") end
				return c
			end
			local c1 = asker("Kim Ford")
			w:enterCombat(me)
			me.W.Fire("DRIVE_RITUAL", c1.name, "c", { key = c1.key, mine = true })
			ctx:advance(40)
			if #autos(ctx) > 0 then ctx:fail("A line went by itself to a rider while you were in combat.", tostring(autos(ctx)[1].text)) end
			w:leaveCombat(me)
			ctx:advance(30)
			if #autos(ctx, c1.name) > 0 and DR.LineOn("greet") then
				-- a later line for the same fight is a bug only for the greeting (tried once, at its moment)
				for _, x in ipairs(autos(ctx, c1.name)) do
					if x.text == DR.Text("greet", c1) then ctx:fail("The greeting dropped in combat was sent anyway after the fight.", x.text) end
				end
			end
			local before = #autos(ctx)
			local c2 = asker("Lou Grey")
			me.player.instance = true
			me.W.Fire("DRIVE_RITUAL", c2.name, "c", { key = c2.key, mine = true })
			ctx:advance(40)
			me.player.instance = false
			if #autos(ctx) > before then ctx:fail("A line went by itself to a rider while you were in an instance.", tostring(autos(ctx)[#autos(ctx)].text)) end
			-- control: with the busy states over, the same moment does send, so the quiet above was the rule and not a dead line
			ctx:advance(25)
			local c3 = asker("Mo Pratt")
			me.W.Fire("DRIVE_RITUAL", c3.name, "c", { key = c3.key, mine = true })
			ctx:advance(3)
			if #autos(ctx, c3.name) == 0 then ctx:na("control: the greeting did not go to a third rider either, so the quiet proves nothing (" .. tostring(select(2, DR.CanLine("greet", c3))) .. ")") end
		end,
	}

	promise{
		id = "dec.lines_never_to_strangers",
		text = "Lines that go by themselves never reach someone who did not ask you for a ride: not a stranger who whispered hello, not a player in your group who never asked, not a public chat buyer.",
		source = "CHANGELOG 2.4.0 (never to anyone who did not ask you for a ride)",
		needs = { role = "warlock", ride = "none", group = "solo" },
		when = notFirst,
		pre = function(ctx) linesSaved(ctx, { "greet", "pay", "next" }) end,
		check = function(ctx)
			startFacts(ctx)
			local DR, w, me = DRof(ctx), ctx.w, ctx.me
			if not (DR.Selling and DR.Selling()) then ctx:na("not open") end
			if me.player.combat then ctx:na("in combat") end
			local fac = (me.player and me.player.faction) or "Horde"
			DR.opts().autoInvite = true
			DR.opts().watchPublic = true
			w:addBot("Sam Stranger", { spot = "Ratchet" })
			w:botWhisper("Sam Stranger", me, "hello there")
			w:addBot("Pub Buyer", { spot = "Ratchet", acceptsInvites = false, faction = fac })
			w:chatFrom("Pub Buyer", "WTB summon to " .. tostring(DR.Dest and DR.Dest() or "Ratchet"), "CHANNEL", "Trade", fac)
			w:addBot("Gus Group", { spot = "Ratchet" })
			if me.player.group then w:join(w:player(me.player.group.leader) or me.player, w:player("Gus Group")) else w:group({ ctx.name, "Gus Group" }) end
			ctx:advance(5)
			for _, n in ipairs({ "Sam Stranger", "Pub Buyer", "Gus Group" }) do
				local c = row(ctx, n)
				if c then me.W.Fire("DRIVE_RITUAL", c.name, "c", { key = c.key, mine = true }) end
			end
			ctx:advance(90)
			for _, n in ipairs({ "Sam Stranger", "Pub Buyer", "Gus Group" }) do
				if #autos(ctx, n) > 0 then ctx:fail("A line went by itself to " .. n .. ", who never asked you for a ride.", tostring(autos(ctx, n)[1].text)) end
			end
			if #w.violations > 0 then ctx:fail("The game refused a line your window sent by itself.", tostring(w.violations[1])) end
		end,
	}

	promise{
		id = "dec.lines_next_only_to_waiting",
		text = "'You're next' goes by itself only to a rider without Wuber who whispered you and waits first in your line: once, not to the rider already in your group.",
		source = "CHANGELOG 2.4.0 (a new line 'You're next' (to a rider without Wuber who is first in your line)); AutoLines.lua header",
		needs = { role = "warlock", ride = "none", group = "solo" },
		-- with whispers Off no line goes by itself (Drive/AutoLines.lua: "whispers are off")
		when = function(sit) return notFirst(sit) and (sit.opt_whisperMode or "default") ~= "off" end,
		pre = function(ctx) linesSaved(ctx, { "next" }) end,
		check = function(ctx)
			startFacts(ctx)
			local DR, w, me = DRof(ctx), ctx.w, ctx.me
			if not (DR.Selling and DR.Selling()) then ctx:na("not open") end
			if me.player.combat then ctx:na("in combat") end
			DR.opts().autoInvite = true
			DR.opts().oneAtATime = true
			for _, n in ipairs({ "Kim Ford", "Lou Grey" }) do
				w:addBot(n, { spot = "Orgrimmar" })
				w:botWhisper(n, me, reqText(ctx))
				ctx:advance(4)
			end
			local a, b = row(ctx, "Kim Ford"), row(ctx, "Lou Grey")
			if not (a and b and b.state == "queued") then ctx:na("the second rider is not waiting in line (" .. tostring(b and b.state) .. ")") end
			ctx:advance(30)
			if #autos(ctx, "Kim Ford") > 0 then ctx:fail("The rider already in your group got a line by itself while another waits.", tostring(autos(ctx, "Kim Ford")[1].text)) end
			local n = #autos(ctx, "Lou Grey")
			if n ~= 1 then ctx:fail("The first rider in your line, without Wuber, got " .. n .. " 'You're next' lines by themselves instead of one.") end
			ctx:advance(300)
			if #autos(ctx, "Lou Grey") > 1 then ctx:fail("The rider waiting in your line was told 'You're next' more than once.") end
		end,
	}

	promise{
		id = "dec.lines_switch_after_reload",
		text = "A line's switch stays as you set it through a /reload: on stays on, and turned off again it stays off, for each of the three.",
		source = "CHANGELOG 2.4.0 (each with its own switch); AutoLines.lua (saved per account)",
		needs = { role = "warlock" },
		when = notFirst,
		check = function(ctx)
			startFacts(ctx)
			local DR = DRof(ctx)
			DR.SetLineOn("greet", true)
			DR.SetLineOn("next", true)
			ctx:advance(1)
			ctx:reload()
			ctx:advance(3)
			DR = DRof(ctx)
			if not (DR.LineOn("greet") and DR.LineOn("next")) then ctx:fail("You switched a line on, reloaded, and the switch is off again.") end
			if DR.LineOn("pay") then ctx:fail("A /reload switched on a line you never touched (the pay reminder).") end
			DR.SetLineOn("greet", false)
			ctx:advance(1)
			ctx:reload()
			ctx:advance(3)
			DR = DRof(ctx)
			if DR.LineOn("greet") then ctx:fail("You switched the greeting off, reloaded, and it is on again.") end
			if not DR.LineOn("next") then ctx:fail("Switching the greeting off and reloading also switched off You're next.") end
		end,
	}

	---------------------------------------------------------------------------
	-- payment by mail
	---------------------------------------------------------------------------
	local function walkOut(ctx)
		local DR = DRof(ctx)
		local name, r = myRider(ctx)
		local c = row(ctx, name)
		if not c or c.state ~= "arrived" then ctx:na("the rider is not landed on my list") end
		local w = ctx.w
		if r.player.trade then w:tradeCancel(r.player) end
		if ctx.me.player.trade then w:tradeCancel(ctx.me.player) end
		w:leave(name)
		ctx:advance(3 + (DR.OWING_GRACE or 20))
		return DR, name
	end

	promise{
		id = "dec.mail_never_pays",
		text = "A rider who left owing sends you a mail with money: at your open mailbox Wuber notes 'Mail seen: <amount> from <name>, <day>.', but the ride is never marked paid and nothing is taken from the mail.",
		source = "CHANGELOG 2.4.0 (Payment by mail: 'Mail seen: 5g from Dan, 21 Nov.'; a mail never marks a ride paid)",
		needs = { role = "warlock", ride = "arrived" },
		when = notFirst,
		check = function(ctx)
			if not (DRof(ctx).MailNote and ctx.w.mail and ctx.w.openMailbox) then ctx:cannot("no mail module or fake mailbox") end
			local DR, name = walkOut(ctx)
			local rec = DR.MailRecord(name)
			if not rec then ctx:na("the rider who left is not on the mail list (he may have paid or never been owing)") end
			local life0 = DR.Stats()
			local paid0 = 0
			for _, f in ipairs(ctx.me.fired) do if f.name == "DRIVE_PAID" then paid0 = paid0 + 1 end end
			ctx.w:mail(ctx.me, { sender = name, money = rec.due, subject = "Wuber" })
			ctx:advance(2)
			if DR.MailNote(name) then ctx:fail("Wuber noted a mail before you opened a mailbox.") end
			ctx.w:openMailbox(ctx.me)
			ctx:advance(1)
			local note = DR.MailNote(name)
			if not (note and note:find("^Mail seen: ") and note:find("from " .. name:match("^%S+"), 1, true)) then
				ctx:fail("You open your mailbox with money from a rider who left owing and Wuber does not note 'Mail seen: ... from " .. name:match("^%S+") .. "'.", tostring(note))
			end
			local paid1 = 0
			for _, f in ipairs(ctx.me.fired) do if f.name == "DRIVE_PAID" then paid1 = paid1 + 1 end end
			local life1 = DR.Stats()
			if paid1 ~= paid0 or life1.copper ~= life0.copper then ctx:fail("A mail from a rider who owes made Wuber count the ride as paid.") end
			if DR.MailRecord(name) == nil then ctx:fail("The mail took the rider off the owing list, as if it were a payment.") end
			ctx.w:closeMailbox(ctx.me)
			ctx:advance(1)
			ctx.w:openMailbox(ctx.me)
			ctx:advance(1)
			if DR.MailNote(name) ~= note then ctx:fail("Opening the mailbox a second time changed the note.", tostring(DR.MailNote(name))) end
			if #ctx.w.violations > 0 then ctx:fail("Wuber touched the mail (the game refused a call).", tostring(ctx.w.violations[1])) end
		end,
	}

	promise{
		id = "dec.mail_note_survives_reload",
		text = "The note about a mail from a rider who owes you is still there after a /reload and the next time you open the mailbox, and it still does not mark anyone paid.",
		source = "CHANGELOG 2.4.0 (Payment by mail); Mail.lua (a record lives 30 days in the saved data)",
		needs = { role = "warlock", ride = "arrived" },
		when = notFirst,
		check = function(ctx)
			if not (DRof(ctx).MailNote and ctx.w.mail and ctx.w.openMailbox) then ctx:cannot("no mail module or fake mailbox") end
			local DR, name = walkOut(ctx)
			local rec = DR.MailRecord(name)
			if not rec then ctx:na("the rider who left is not on the mail list") end
			ctx.w:mail(ctx.me, { sender = name, money = rec.due, subject = "Wuber" })
			ctx.w:openMailbox(ctx.me)
			ctx:advance(1)
			local note = DR.MailNote(name)
			if not note then ctx:na("no note was made here") end
			ctx:advance(2)
			ctx:reload()
			ctx:advance(5)
			DR = DRof(ctx)
			if DR.MailNote(name) ~= note then ctx:fail("You reloaded your UI and the note 'Mail seen' about a rider's mail is gone.", tostring(DR.MailNote(name))) end
			if not DR.MailRecord(name) then ctx:fail("After a /reload the rider who owes is no longer on the mail list.") end
		end,
	}

	promise{
		id = "dec.mail_whisper_needs_click",
		text = "Wuber never whispers 'send ... by mail' to a rider who left owing by itself, even with every self-sent line switched on: only your click on the big button does.",
		source = "CHANGELOG 2.4.0 (the driver's big button can whisper the same on a click); Mail.lua; AutoLines.lua (three lines only)",
		needs = { role = "warlock", ride = "arrived" },
		when = notFirst,
		pre = function(ctx) linesSaved(ctx, { "greet", "pay", "next" }) end,
		check = function(ctx)
			if not DRof(ctx).MailRecord then ctx:cannot("no mail module") end
			local DR, name = walkOut(ctx)
			if not DR.MailRecord(name) then ctx:na("the rider who left is not on the mail list") end
			ctx:advance(60)
			local n = sentTo(ctx, name, "by mail")
			if n > 0 then ctx:fail("A rider left owing and Wuber whispered him how to pay by mail without your click.") end
		end,
	}

	---------------------------------------------------------------------------
	-- Close, waiting in line, Undo, the row, the cards
	---------------------------------------------------------------------------
	promise{
		id = "dec.close_asks_with_riders",
		text = "Closing your shop with riders still listed asks first ('N rider(s) is/are still with you. Close anyway?'); Cancel keeps it open; with nobody listed it closes at once.",
		source = "CHANGELOG 2.4.0 (The Drive page, Close: with riders still listed, Close asks first)",
		needs = { role = "warlock" },
		when = function(sit) return sit.ride ~= "paid" and sit.ride ~= "ended" and sit.ride ~= "timedout" and sit.ride ~= "raincheck" end,
		check = function(ctx)
			local DR, W = DRof(ctx), ctx.W
			if not (DR.IsOpen and DR.IsOpen()) then ctx:na("not open") end
			if not (W.Driver and W.Driver.SetOnline) then ctx:cannot("no Driver.SetOnline") end
			local n = 0
			-- r50 AU24-19: a rider who paid and left is not "still with you"
			for _, c in pairs(DR.customers or {}) do if c.state ~= "lead" and not (c.state == "paid" and c.gone) then n = n + 1 end end
			W.Driver.SetOnline(false)
			ctx:advance(1)
			local env = ctx.me.env
			local shown = env.StaticPopup_FindVisible and env.StaticPopup_FindVisible("WUBER_CLOSE_RIDERS")
			if n == 0 then
				if shown then ctx:fail("You close your shop with nobody listed and Wuber asks 'Close anyway?'.") end
				if DR.IsOpen() then ctx:fail("You close your shop with nobody listed and it stays open.") end
				return
			end
			local dlg = env.StaticPopupDialogs and env.StaticPopupDialogs.WUBER_CLOSE_RIDERS
			if not (shown and dlg) then ctx:fail("You close your shop with " .. n .. " rider(s) listed and Wuber does not ask first.") end
			local want = (n == 1) and "1 rider is still with you. Close anyway?" or (n .. " riders are still with you. Close anyway?")
			if dlg.text ~= want then ctx:fail("The question about closing with riders listed does not give the real count.", tostring(dlg.text) .. " (wanted: " .. want .. ")") end
			if not DR.IsOpen() then ctx:fail("Your shop closed before you answered the question.") end
			env.StaticPopup_Hide("WUBER_CLOSE_RIDERS")
			if dlg.OnCancel then dlg.OnCancel() end
			ctx:advance(1)
			if not DR.IsOpen() then ctx:fail("You pressed Cancel on 'Close anyway?' and your shop closed.") end
			-- a second time, then Yes
			W.Driver.SetOnline(false)
			ctx:advance(1)
			env.StaticPopup_Hide("WUBER_CLOSE_RIDERS")
			dlg.OnAccept()
			ctx:advance(1)
			if DR.IsOpen() then ctx:fail("You pressed Yes on 'Close anyway?' and your shop stayed open.") end
		end,
	}

	promise{
		id = "dec.queue_waits_while_driver_heard",
		text = "Out of combat, a rider waiting in a driver's line, who was told his place, is still waiting after five minutes while the driver is heard, and gives up only about 150 seconds after the driver goes silent.",
		source = "CHANGELOG 2.4.0 (Waiting in a driver's line: gives up only after 150 seconds of silence)",
		needs = { role = "rider", ride = "requested", net = "one" },
		when = notFirst,
		check = function(ctx)
			local W, d = ctx.W, ctx.peers.driver
			if not (W.ride and d) then ctx:na("no ride to wait in") end
			-- the wait clock stands still in combat or in an instance, by design (Net/Rides.lua held, Net/Base.lua)
			if (type(W.InCombat) == "function" and W.InCombat()) or ctx.me.player.combat then ctx:na("in combat: the wait clock stands still") end
			if type(W.InInstance) == "function" and W.InInstance() then ctx:na("in an instance: the wait clock stands still") end
			ctx:advance(10)
			if not (W.ride and W.ride.state == "accepted" and W.ride.position) then ctx:na("the driver told no place in line (" .. tostring(W.ride and W.ride.state) .. ")") end
			ctx:advance(300)
			if not (ctx.W.ride and ctx.W.ride.state == "accepted") then
				ctx:fail("You wait in a driver's line, he is still online, and your Wuber gives up before five minutes (" .. tostring(ctx.W.ride and ctx.W.ride.state) .. ").")
			end
			ctx.w:closeClient(d)
			ctx:advance(60)
			if not (ctx.W.ride and ctx.W.ride.state == "accepted") then
				ctx:fail("The driver went silent a minute ago and your Wuber already gave up waiting (under the 150 seconds).")
			end
			local gone = waitFor(ctx, function() return ctx.W.ride == nil or ctx.W.ride.state ~= "accepted" end, 160, 5)
			if not gone then ctx:fail("The driver has been silent for over three minutes and your Wuber still waits in his line.") end
		end,
	}

	promise{
		id = "dec.undo_after_reset",
		text = "After a reset in Settings (Wide pages: Reset) a line with Undo shows for 10 seconds; Undo puts back what was reset, and after 10 seconds the reset is final.",
		source = "CHANGELOG 2.4.0 (Settings: after a reset ... a line with Undo shows for 10 seconds)",
		needs = { phone = "closed" },
		when = notFirst,
		check = function(ctx)
			local W = ctx.W
			if not (W.UI and W.UI.OpenSettings and W.UI.UndoPending) then ctx:cannot("no UI.OpenSettings / UndoPending") end
			if ctx.me.player.combat then ctx:na("in combat") end
			W.db.coach = true
			W.db.fold = { v = 1, pages = { home = "open" }, narrow = true }
			W.UI.Toggle(true)
			ctx:advance(3)
			W.UI.OpenSettings("window")
			ctx:advance(1)
			local st = W.UI.settings
			local btn = st and st.controls and st.controls.foldReset
			if not btn then ctx:na("no Wide pages Reset on this Settings page") end
			btn:Click()
			ctx:advance(0.5)
			if W.db.fold.narrow ~= false then ctx:fail("You press Reset beside Wide pages and Always narrow is still saved.") end
			if not W.UI.UndoPending() then ctx:fail("You reset the window pages and no line with Undo shows.") end
			ctx:advance(5)
			if not W.UI.UndoPending() then ctx:fail("The Undo line after a reset is gone after 5 seconds (it should last 10).") end
			local t
			for _, x in ipairs(ctx:texts()) do if tostring(x):find("Undo", 1, true) then t = x end end
			if not t then ctx:fail("The Undo line is pending but no 'Undo' button text is visible.") end
			ctx:advance(7)
			if W.UI.UndoPending() then ctx:fail("The Undo line is still up after 12 seconds.") end
			for _, x in ipairs(ctx:texts()) do if tostring(x) == "Undo" then ctx:fail("An 'Undo' button is still on screen 12 seconds after the reset.") end end
			if W.db.fold.narrow ~= false then ctx:fail("The reset was undone by itself after 10 seconds.") end
		end,
	}

	promise{
		id = "dec.what_wuber_sends_row",
		text = "Settings, Riding has a row 'What Wuber sends' that says in plain words the sending limits: how many hidden messages, the one whisper back to a public request, and that every other line waits for your click.",
		source = "CHANGELOG 2.4.0 (Settings, Riding: a new row 'What Wuber sends'); words from the 20 approved rewrites (7defb438, job 2680 mend)",
		needs = { phone = "closed" },
		when = notFirst,
		check = function(ctx)
			local W = ctx.W
			if not (W.UI and W.UI.OpenSettings) then ctx:cannot("no UI.OpenSettings") end
			if W.Advanced and not W.Advanced() then ctx:na("Simple mode: the row is in Advanced") end
			W.db.coach = true
			W.UI.Toggle(true)
			ctx:advance(3)
			W.UI.OpenSettings("riding")
			ctx:advance(1)
			local st = W.UI.settings
			local r = st and st.sendingRow
			if not r then ctx:na("this build has no sendingRow handle") end
			if not ctx:visible(r) then ctx:fail("Settings, Riding has no visible row 'What Wuber sends'.") end
			local text = r.sub and r.sub:GetText() or ""
			for _, w in ipairs({ "at most 12", "One whisper back", "waits for your click" }) do
				if not text:find(w, 1, true) then ctx:fail("The 'What Wuber sends' row does not say '" .. w .. "'.", text) end
			end
			-- the row shows the short line; the never-situations are in its tooltip (the 20 rewrites, W-13): read both
			local tip = r.wuberTip and r.wuberTip.text or ""
			local both = text .. " " .. tip
			for _, w in ipairs({ "in combat", "in a raid", "in an instance", "during a ride", "your own click" }) do
				if not both:find(w, 1, true) then ctx:fail("The 'What Wuber sends' row and its tooltip do not say '" .. w .. "'.", both) end
			end
		end,
	}

	promise{
		id = "dec.guide_held_in_combat_says_why",
		text = "A card that opens by itself (the first-open guide) does not open in combat, and /wuber why says so in words.",
		source = "CHANGELOG 2.4.0 (Cards and tips that open by themselves share one rule ... /wuber why says which rule holds one back)",
		needs = { phone = "closed", coach = "not_done" },
		when = function(sit) return sit.session ~= "first" end,
		check = function(ctx)
			local W = ctx.W
			if not (W.UI and W.UI.Toggle and ctx.me.env.SlashCmdList and ctx.me.env.SlashCmdList.WUBER) then ctx:cannot("no slash command") end
			ctx:advance(5)
			ctx.w:enterCombat(ctx.me)
			W.UI.Toggle(true)
			ctx:advance(5)
			local out = {}
			local orig = W.Print
			W.Print = function(...) out[#out + 1] = table.concat({ ... }, " ") end
			ctx.me.env.SlashCmdList.WUBER("why")
			W.Print = orig
			local said = table.concat(out, " | ")
			local ui = W.UI.state
			if ui and ui.coaching then ctx:fail("The first-open guide started in combat.") end
			if not said:lower():find("combat", 1, true) then
				ctx:fail("A card that should wait for the fight is held back and /wuber why does not say combat.", said)
			end
		end,
	}

	promise{
		id = "dec.drive_lists_every_rider",
		text = "The Drive page lists every rider on your list, also the ninth and later, with no '+N more' line.",
		source = "CHANGELOG 2.4.0 (The Drive page lists every rider, also past the eighth)",
		needs = { role = "warlock", ride = "none", group = "solo" },
		when = notFirst,
		check = function(ctx)
			local DR, W, w, me = DRof(ctx), ctx.W, ctx.w, ctx.me
			if not (DR.Selling and DR.Selling()) then ctx:na("not open") end
			DR.opts().autoInvite = false
			for i = 1, 10 do
				local n = ({ "Aa Ford", "Bb Ford", "Cc Ford", "Dd Ford", "Ee Ford", "Ff Ford", "Gg Ford", "Hh Ford", "Ii Ford", "Jj Ford" })[i]
				w:addBot(n, { spot = "Orgrimmar" })
				w:botWhisper(n, me, reqText(ctx))
				ctx:advance(2)
			end
			local listed = 0
			for _, c in pairs(DR.customers or {}) do if c.state ~= "lead" then listed = listed + 1 end end
			if listed < 9 then ctx:na("only " .. listed .. " riders made a row") end
			W.db.coach = true
			if not (W.UI.ShowDrive and W.Driver and W.Driver.ui) then ctx:cannot("no Drive page API") end
			W.UI.ShowDrive("console")
			ctx:advance(1)
			local v = W.Driver.ui.console
			if not (v and v.rows) then ctx:na("no console view") end
			local shown = 0
			for _, r in ipairs(v.rows) do if r:IsShown() and r.c then shown = shown + 1 end end
			if shown < listed then ctx:fail("You have " .. listed .. " riders listed and the Drive page shows only " .. shown .. " rows.") end
			if v.more and v.more:IsShown() then ctx:fail("The Drive page still has a '+N more' line past the eighth rider.") end
		end,
	}
end
