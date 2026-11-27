-- Promises about the summon guard and the summon status (tests/promises/v24_summon.lua; job 146, the logic half).
-- What the player is told (Drive/Cast.lua header, release/CHANGELOG-2.4.0.md "Summons, seen from the driver's side"):
-- "The big button does not cast on a rider it has seen get a summon. It says '<Name> has a summon waiting' and
-- summons the next rider instead, so no Soul Shard goes on a second summon." A row says "has the summon window",
-- "summon accepted" or "declined: summon again?". "A summon that went out with two helpers Wuber could not hear is not
-- cast a second time: the Soul Shard that went during the ritual is the proof." "If the game does not have the
-- summoner's name the moment the summon box opens, Wuber asks again for a few seconds."
-- Logic only: what is sent, saved or decided; no promise about layout.
return function(Hunt)
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end
	-- (the driver's own switches that keep a rider from joining or the button from showing are left out: other jobs hunt those)
	local function warlockOnly(sit)
		return sit.role == "warlock" and (sit.group == nil or sit.group == "solo") and sit.button_shown ~= "off" and sit.button_keepClosed ~= "on"
			and sit.opt_autoInvite ~= "off" and sit.opt_whisperMode ~= "off" and sit.opt_oneAtATime ~= "on" and sit.combat ~= "before" and sit.combat ~= "after"
	end
	local function game(ctx) ctx.worldOpts.incomingSummon = true end -- the fake game gives clients C_IncomingSummon

	local function must(ctx, v, why) if not v then ctx:cannot("summon: " .. why) end end
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

	-- the Warlock driver (me, open) with two helpers without Wuber, Wes (another Warlock, far away) and Dan (a rider
	-- without Wuber, ready to be summoned); o.wes = false leaves Wes out of the group
	local function setup(ctx, o)
		o = o or {}
		local w, me = ctx.w, ctx.me
		must(ctx, me.player.class == "WARLOCK", "not a Warlock")
		must(ctx, me.env.C_IncomingSummon ~= nil, "no C_IncomingSummon on this client")
		local DR = ctx.W.Drive
		local spot = o.spot or "Ratchet"
		w:addBot("Bob Helper", { spot = spot })
		w:addBot("Bo Second", { spot = spot })
		w:addBot("Wes Other", { spot = "Thunder Bluff", class = "WARLOCK", shards = 5 })
		local names = { ctx.name, "Bob Helper", "Bo Second" }
		if o.wes ~= false then names[#names + 1] = "Wes Other" end
		-- (the helpers stand in the group before the shop opens, so they are never taken for riders)
		if DR.IsOpen() then DR.SetOpen(false) ctx:advance(1) end
		w:group(names)
		ctx:advance(1)
		DR.SetOpen(true)
		ctx:advance(2)
		w:addBot("Dan Moss", { spot = "Orgrimmar", acceptsSummon = false })
		w:botWhisper("Dan Moss", me, "summon pls")
		local c
		must(ctx, waitFor(ctx, function() c = DR.Find("Dan Moss") return c and c.state == "joined" end, 8), "Dan never joined the group (" .. tostring(c and c.state) .. ")")
		local b = me.env.WuberDriveButton
		must(ctx, b and ctx.H.visible(b), "the big button is not shown")
		must(ctx, (DR.Plan() or {}).title == "Summon Dan", "the button does not offer Dan's summon: " .. tostring((DR.Plan() or {}).title))
		ctx:advance(2) -- (a few looks of the game's answer before anything happens: a "waiting" there at the first look is not believed)
		return { w = w, me = me, DR = DR, c = c, b = b }
	end
	local function casts(b) return tostring(b:GetAttribute("macrotext") or ""):find("/cast", 1, true) ~= nil end
	local function title(s) return tostring((s.DR.Plan() or {}).title) end
	local HELD = "Dan has a summon waiting"

	---------------------------------------------------------------------------
	Hunt.promise{
		id = "guard.no_cast_on_waiting",
		area = "Summon guard",
		text = "When another Warlock's summon is already waiting for a rider, the big button holds no cast, says so, and a click wastes no Soul Shard.",
		source = "CHANGELOG 2.4.0: The big button does not cast on a rider it has seen get a summon",
		kind = "scenario", needs = { role = "warlock", ride = "none" }, when = warlockOnly, pre = game,
		check = function(ctx)
			local s = setup(ctx)
			s.w:summon(s.w:player("Wes Other"), "Dan Moss")
			ctx:advance(2)
			local shards, casts0 = s.w:player(ctx.name).shards, s.w.casts
			if casts(s.b) or (s.DR.Plan() or {}).summon ~= nil then
				ctx:fail("Dan already has another Warlock's summon waiting and your big button still holds a cast on him.", tostring(s.b:GetAttribute("macrotext")) .. " | status " .. tostring(s.w:summonStatus(s.w:player("Dan Moss"))) .. " pending " .. tostring(s.DR.SummonPending(s.c)) .. " title " .. title(s))
			end
			if title(s) ~= HELD then ctx:fail("Dan has a summon waiting and the button does not say so.", "title: " .. title(s)) end
			ctx.me:click(s.b)
			ctx:advance(3)
			if s.w.casts ~= casts0 or s.w:player(ctx.name).shards ~= shards then
				ctx:fail("You click the big button for a rider who already has a summon waiting and a second summon goes out.", "casts " .. casts0 .. " -> " .. s.w.casts)
			end
		end,
	}

	Hunt.promise{
		id = "guard.last_second_look",
		area = "Summon guard",
		text = "A summon that appeared a moment before your click is still caught: the click casts nothing.",
		source = "Cast.lua header: the button's PreClick looks once more first",
		kind = "scenario", needs = { role = "warlock", ride = "none" }, when = warlockOnly, pre = game,
		check = function(ctx)
			local s = setup(ctx)
			if not casts(s.b) then ctx:na("the button does not hold the cast before the summon") end
			s.w:summon(s.w:player("Wes Other"), "Dan Moss") -- no tick since
			local casts0 = s.w.casts
			ctx.me:click(s.b)
			ctx:advance(3)
			if s.w.casts ~= casts0 then ctx:fail("Another Warlock's summon for Dan came up just before your click and your click cast a second summon on him.", "casts " .. casts0 .. " -> " .. s.w.casts) end
		end,
	}

	Hunt.promise{
		id = "guard.next_rider",
		area = "Summon guard",
		text = "While one rider has a summon waiting, the button summons the next rider instead, even after you click the held rider's row to summon him next.",
		source = "CHANGELOG 2.4.0: summons the next rider instead",
		kind = "scenario", needs = { role = "warlock", ride = "none" }, when = warlockOnly, pre = game,
		check = function(ctx)
			local s = setup(ctx, { wes = false })
			s.w:addBot("Eve Night", { spot = "Orgrimmar", acceptsSummon = false })
			s.w:botWhisper("Eve Night", ctx.me, "summon pls")
			must(ctx, waitFor(ctx, function() local e = s.DR.Find("Eve Night") return e and e.state == "joined" end, 8), "Eve never joined")
			-- (Wes is a Warlock with shards who is not in the group: the fake's World:summon does not ask who is grouped)
			s.w:summon(s.w:player("Wes Other"), "Dan Moss")
			ctx:advance(2)
			local n = s.DR.NextSummon()
			if not (n and n.name == "Eve Night") then ctx:fail("Dan has a summon waiting and the next summon is not Eve's.", "next: " .. tostring(n and n.name)) end
			ctx.W.Driver.RowAction(s.c, "next")
			ctx:advance(1)
			n = s.DR.NextSummon()
			if not (n and n.name == "Eve Night") then ctx:fail("You click Dan's row to summon him next although he has a summon waiting, and the button offers a second summon on him.", "next: " .. tostring(n and n.name)) end
		end,
	}

	Hunt.promise{
		id = "guard.released_after_decline",
		area = "Summon guard",
		text = "When the rider declines the waiting summon, the hold ends and the button offers your summon again.",
		source = "Cast.lua header: DR.SummonPending is true only while the game says a summon waits",
		kind = "scenario", needs = { role = "warlock", ride = "none" }, when = warlockOnly, pre = game,
		check = function(ctx)
			local s = setup(ctx)
			s.w:summon(s.w:player("Wes Other"), "Dan Moss")
			ctx:advance(2)
			if title(s) ~= HELD then ctx:na("the hold did not start: " .. title(s)) end
			s.w:answerSummon("Dan Moss", false)
			ctx:advance(2.5)
			if title(s) ~= "Summon Dan" then ctx:fail("Dan declined the other summon and your button still says he has one waiting.", "title: " .. title(s)) end
			local casts0 = s.w.casts
			ctx.me:click(s.b)
			ctx:advance(1)
			if s.w.casts ~= casts0 + 1 then ctx:fail("Dan declined the other summon and your click on the big button casts nothing.", "casts " .. casts0 .. " -> " .. s.w.casts) end
		end,
	}

	Hunt.promise{
		id = "guard.hold_ends",
		area = "Summon guard",
		text = "A hold on a rider never lasts longer than a summon box does (about 200 seconds): a stuck answer from the game cannot lock a paying rider out.",
		source = "Cast.lua: SUMMON.HOLD_MAX; a box lasts 2 to 3 minutes",
		kind = "scenario", needs = { role = "warlock", ride = "none" }, when = warlockOnly, pre = game,
		check = function(ctx)
			local s = setup(ctx)
			s.w:summon(s.w:player("Wes Other"), "Dan Moss")
			ctx:advance(2)
			if title(s) ~= HELD then ctx:na("the hold did not start: " .. title(s)) end
			-- the game keeps saying "pending" for good
			ctx.me.env.C_IncomingSummon.IncomingSummonStatus = function() return 1 end
			ctx:advance(215)
			if title(s) == HELD then ctx:fail("The game has said 'summon waiting' for Dan for over 3 minutes and your big button still refuses to summon him.", "title: " .. title(s)) end
		end,
	}

	Hunt.promise{
		id = "guard.secret_answer_holds_nothing",
		area = "Summon guard",
		text = "When the game hides its answer about a summon, the button acts as before (offers the summon) and no hidden value is used.",
		source = "tests/v24/f3_e_summonguard_test.lua (secret answer); Cast.lua summonRead",
		kind = "scenario", needs = { role = "warlock", ride = "none" }, when = warlockOnly, pre = game,
		check = function(ctx)
			local s = setup(ctx)
			if type(ctx.me.secret) ~= "function" then ctx:na("this client cannot hide values") end
			ctx.me:secret("IncomingSummon")
			s.w:summon(s.w:player("Wes Other"), "Dan Moss")
			ctx:advance(3)
			if title(s) ~= "Summon Dan" then ctx:fail("The game hides its summon answer and your button no longer offers Dan's summon.", "title: " .. title(s)) end
			if #s.w.violations > 0 then ctx:fail("Wuber used a value the game hides while looking at Dan's summon.", tostring(s.w.violations[1])) end
		end,
	}

	local function ends(w)
		local out = {}
		for _, e in ipairs(w.addonLog) do
			local f = e.text:match("^END~[^~]*~Dan Moss~(%d)")
			if f then out[#out + 1] = f end
		end
		return table.concat(out, ",")
	end

	Hunt.promise{
		id = "guard.shard_proves_summon",
		area = "Summon guard",
		text = "A summon that went out (its Soul Shard is gone) is not reported failed, even when two helpers without Wuber clicked too quickly to be heard.",
		source = "CHANGELOG 2.4.0: the Soul Shard that went during the ritual is the proof",
		kind = "scenario", needs = { role = "warlock", ride = "none" }, when = warlockOnly, pre = game,
		check = function(ctx)
			local s = setup(ctx, { wes = false })
			s.DR.opts().helpSeen = ctx.W.Build()
			local shards = s.w:player(ctx.name).shards
			ctx.me:click(s.b)
			ctx:advance(3)
			if s.c.state ~= "summoning" then ctx:na("the ritual did not start: " .. tostring(s.c.state)) end
			if not (s.w:clickPortal("Bob Helper") and s.w:clickPortal("Bo Second")) then ctx:na("a helper could not click the portal") end
			ctx:advance(2.5)
			if #s.w.summons ~= 1 or s.w:player(ctx.name).shards ~= shards - 1 then ctx:na("the fake game did not finish the summon") end
			if s.c.state ~= "waiting" or ends(s.w) ~= "1" then
				ctx:fail("Dan's summon went out and used a Soul Shard, but your row sends him back to 'summon again'.", "state " .. tostring(s.c.state) .. ", END facts: " .. ends(s.w))
			end
		end,
	}

	Hunt.promise{
		id = "guard.no_shard_no_summon_claim",
		area = "Summon guard",
		text = "A summon that never went out (ritual dropped, no shard gone) is told to the crew as failed, and Dan is to be summoned again with no shard lost.",
		source = "CHANGELOG 2.4.0 (shard proof); Cast.lua: no shard gone is never proof",
		kind = "scenario", needs = { role = "warlock", ride = "none" }, when = warlockOnly, pre = game,
		check = function(ctx)
			local s = setup(ctx, { wes = false })
			s.DR.opts().helpSeen = ctx.W.Build()
			local shards = s.w:player(ctx.name).shards
			ctx.me:click(s.b)
			ctx:advance(3)
			if s.c.state ~= "summoning" then ctx:na("the ritual did not start: " .. tostring(s.c.state)) end
			s.w:cancelRitual()
			ctx:advance(2.5)
			if #s.w.summons ~= 0 or s.w:player(ctx.name).shards ~= shards then ctx:na("the ritual was not dropped cleanly") end
			if s.c.state ~= "joined" or ends(s.w) ~= "0" then
				ctx:fail("Your ritual was dropped and nothing was summoned, yet Dan is not shown as ready to summon again.", "state " .. tostring(s.c.state) .. ", END facts: " .. ends(s.w))
			end
		end,
	}

	local function says(ctx, c) return (ctx.W.Driver.Describe(c)) end

	local function summoned(ctx)
		local s = setup(ctx, { wes = false })
		ctx.me:click(s.b)
		ctx:advance(3)
		must(ctx, s.w:clickPortal("Bob Helper"), "Bob could not click the portal")
		must(ctx, s.w:clickPortal("Bo Second"), "Bo could not click the portal")
		ctx:advance(2.5)
		must(ctx, s.c.state == "waiting", "Dan has no summon window: " .. tostring(s.c.state))
		return s
	end

	Hunt.promise{
		id = "guard.status_declined_then_gone",
		area = "Summon guard",
		text = "A rider without Wuber who declines your summon reads 'declined: summon again?' on your row, the engine does not change, and the words go when the game stops saying it.",
		source = "CHANGELOG 2.4.0: declined: summon again?",
		kind = "scenario", needs = { role = "warlock", ride = "none" }, when = warlockOnly, pre = game,
		check = function(ctx)
			local s = summoned(ctx)
			ctx.w:answerSummon("Dan Moss", false)
			ctx:advance(2)
			if says(ctx, s.c) ~= "declined: summon again?" then ctx:fail("Dan declined your summon and his row does not say so.", "row: " .. tostring(says(ctx, s.c))) end
			if s.c.state ~= "waiting" then ctx:fail("Dan declined your summon and the driver's state for him changed by itself.", "state " .. tostring(s.c.state)) end
			ctx:advance((ctx.H.SUMMON_STICKY or 150) + 5)
			if says(ctx, s.c) == "declined: summon again?" then ctx:fail("The game stopped saying Dan declined minutes ago and his row still says it.", "row: " .. says(ctx, s.c)) end
		end,
	}

	Hunt.promise{
		id = "guard.status_accepted_until_landed",
		area = "Summon guard",
		text = "A rider without Wuber who accepts your summon reads 'summon accepted' until he lands, then the arrived row.",
		source = "CHANGELOG 2.4.0: summon accepted",
		kind = "scenario", needs = { role = "warlock", ride = "none" }, when = warlockOnly, pre = game,
		check = function(ctx)
			local s = summoned(ctx)
			ctx.w:answerSummon("Dan Moss", true)
			ctx:advance(1.2)
			if says(ctx, s.c) ~= "summon accepted" then ctx:fail("Dan accepted your summon and his row does not say so.", "row: " .. tostring(says(ctx, s.c))) end
			ctx:advance(5)
			if s.c.state ~= "arrived" then ctx:na("Dan did not land in the fake game") end
			if says(ctx, s.c) == "summon accepted" then ctx:fail("Dan landed and his row still says 'summon accepted'.", "row: " .. says(ctx, s.c)) end
		end,
	}

	Hunt.promise{
		id = "guard.status_old_answer_ignored",
		area = "Summon guard",
		text = "After you cast a second summon on a rider, the game's old 'declined' from the first one is not shown as his answer to the second.",
		source = "Cast.lua header: an answer older than the latest cast is ignored",
		kind = "scenario", needs = { role = "warlock", ride = "none" }, when = warlockOnly, pre = game,
		check = function(ctx)
			local s = summoned(ctx)
			ctx.w:answerSummon("Dan Moss", false)
			ctx:advance(2)
			ctx.W.Driver.RowAction(s.c, "next")
			ctx:advance(1)
			ctx.me:click(s.b)
			ctx:advance(1)
			if s.c.state ~= "summoning" then ctx:na("the second cast did not start: " .. tostring(s.c.state)) end
			ctx.w:cancelRitual()
			ctx:advance(3)
			if s.c.state ~= "joined" then ctx:na("the second ritual was not dropped: " .. tostring(s.c.state)) end
			if says(ctx, s.c) == "declined: summon again?" then
				ctx:fail("Your second summon on Dan was dropped before anyone clicked, and his row says he declined it.", "row: " .. says(ctx, s.c))
			end
		end,
	}

	---------------------------------------------------------------------------
	-- the rider's side: the summoner's name may arrive late after the summon box opens
	Hunt.promise{
		id = "guard.summoner_named_late",
		area = "Summon guard",
		text = "If the game gives the summoner's name a few seconds after the summon box opens, your ride still learns who summons you ('Unknown' is never taken as a name).",
		source = "CHANGELOG 2.4.0: Wuber asks again for a few seconds",
		kind = "scenario", needs = { role = "rider", ride = "none" },
		when = function(sit) return (sit.role == nil or sit.role == "rider") and sit.net ~= "none" and sit.net ~= "oldpeer" and sit.net ~= "layers" and sit.net ~= "late" and (sit.group == nil or sit.group == "solo") end,
		check = function(ctx)
			local d = ctx.peers.driver
			must(ctx, d, "no driver window")
			local W = ctx.W
			local k = key(d.player.name)
			local U = dofile("tests/hunt/lib/universal_util.lua")
			ctx.w:move(ctx.name, { mapID = 1411, x = 0.04, y = 0.45, zone = "The Barrens", sub = "" })
			must(ctx, waitFor(ctx, function() return W.drivers[k] ~= nil end, 15), "I never saw the driver")
			local ride, why = U.asClick(ctx, function()
				local r, y = W.RequestRide(k)
				local text = r and W.RequestWhisper(k)
				if text then ctx.w:whisper(ctx.me, d.player.name, text, "macro") end
				return r, y
			end)
			must(ctx, ride, "the request was refused: " .. tostring(why))
			must(ctx, waitFor(ctx, function()
				local p = ctx.me.player
				if not p.group and p.pendingInvite then
					ctx.w.hardware = ctx.me
					ctx.me.env.AcceptGroup()
					ctx.w.hardware = nil
					ctx.me.popups.PARTY_INVITE = nil
				end
				return W.ride and W.RIDE_RANK[W.ride.state] >= W.RIDE_RANK.ingroup
			end, 12), "never joined the driver's group")
			ctx.w:summon(d.player, ctx.name, { nameLate = 3, lateWord = "Unknown" })
			ctx:advance(1)
			if not (W.ride and W.ride.state == "portal") then ctx:na("no summon box on my ride: " .. tostring(W.ride and W.ride.state)) end
			if W.ride.summonedBy == "unknown" then ctx:fail("The game said 'Unknown' for the summoner and your ride took it as his name.", "summonedBy " .. tostring(W.ride.summonedBy)) end
			ctx:advance(5)
			if W.ride and W.ride.state == "portal" and W.ride.summonedBy ~= k then
				ctx:fail("The summoner's name came 3 seconds after the summon box opened and your ride never learned who summons you.", "summonedBy " .. tostring(W.ride.summonedBy))
			end
		end,
	}
	Hunt.promise{
		id = "guard.survives_reload",
		area = "Summon guard",
		text = "After a /reload in the middle of a ride, a rider who already has another Warlock's summon waiting is still not summoned a second time.",
		source = "CHANGELOG 2.4.0: The big button does not cast on a rider it has seen get a summon",
		kind = "scenario", needs = { role = "warlock", ride = "none", session = "login" }, when = warlockOnly, pre = game,
		check = function(ctx)
			local s = setup(ctx)
			s.w:summon(s.w:player("Wes Other"), "Dan Moss")
			ctx:advance(2)
			if title(s) ~= HELD then ctx:na("the hold did not start: " .. title(s)) end
			ctx:reload()
			ctx:advance(4)
			local DR = ctx.W.Drive
			local c = DR.Find("Dan Moss")
			if not (c and c.state == "joined") then ctx:na("Dan is not joined after the reload: " .. tostring(c and c.state)) end
			local b = ctx.me.env.WuberDriveButton
			local casts0 = ctx.w.casts
			if not (b and ctx.H.visible(b)) then ctx:na("the big button is not shown after the reload") end
			ctx.me:click(b)
			ctx:advance(2)
			if ctx.w.casts ~= casts0 then
				ctx:fail("You /reload while another Warlock's summon is waiting for Dan, and your big button casts a second summon on him.", "casts " .. casts0 .. " -> " .. ctx.w.casts)
			end
		end,
	}

	Hunt.promise{
		id = "guard.no_shards_no_summon",
		area = "Summon guard",
		text = "With no Soul Shard in your bags the big button does not offer or cast a summon.",
		source = "Cast.lua shardProof / opts needShards",
		kind = "scenario", needs = { role = "warlock", ride = "none" }, when = function(sit) return warlockOnly(sit) and sit.opt_needShards ~= "off" end, pre = game,
		check = function(ctx)
			local s = setup(ctx, { wes = false })
			ctx.w:player(ctx.name).shards = 0
			ctx:advance(3)
			if casts(s.b) or (s.DR.Plan() or {}).summon ~= nil then
				ctx:fail("You have no Soul Shard and your big button still holds a summon cast.", tostring(s.b:GetAttribute("macrotext")))
			end
		end,
	}
end
