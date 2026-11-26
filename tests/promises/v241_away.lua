-- Promises for the 2.4.1 away pause (AU24-01/02/29; commits f84aa8e4 and ac8c6d25): the pause is about the driver being away,
-- not about one rider's wait. Each acts like a player: a rider whispers, time passes, the driver clicks Resume or does not.
return function(Hunt)
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end
	local function DR(ctx) return ctx.W.Drive end
	local function canDrive(sit) return sit.saved == nil or sit.saved == "fresh" end
	local function guardOn(sit) return canDrive(sit) and sit.opt_awayGuard ~= "off" and sit.opt_autoInvite ~= "off" and sit.group ~= "raid" end -- (the guard counts invited riders: a queued one is not "joined")
	local function paused(ctx) return DR(ctx).IsPaused() and true or false end
	local function run(ctx, secs)
		for _ = 1, math.floor(secs / 10) do ctx:advance(10) end -- (10 s steps: the slow phone situations run out of CPU time at 5 s)
	end
	local function ready(ctx)
		if not (DR(ctx) and DR(ctx).IsPaused) then ctx:cannot("no Drive module") end
		if not DR(ctx).IsOpen() then ctx:na("not open") end
		if DR(ctx).IsPaused() then ctx:na("already paused") end
	end
	-- a stranger whispers 'summon pls' and is listed; returns their name
	local function rider(ctx, name)
		if not ctx.w:player(name) then ctx.w:addBot(name, {}) end
		ctx.w:botWhisper(name, ctx.me, "summon pls")
		ctx:note("whisper from " .. name)
		ctx:advance(3)
		if not DR(ctx).customers or not (function() for k in pairs(DR(ctx).customers) do if key(k) == key(name) or tostring(k):lower():find(key(name):match("^%S+"), 1, true) then return true end end end)() then
			ctx:cannot("the rider was not listed")
		end
		return name
	end
	local NEEDS = { role = "warlock", ride = "none" }

	Hunt.promise{
		id = "v241.away.idle_driver_paused",
		area = "Away pause",
		text = "You are open, 'Pause me if I'm away' is on, a rider waits and you do nothing for a good while: Wuber pauses you, but not before about four minutes.",
		source = "AU24-01 guard (f84aa8e4): the pause still fires for an idle driver",
		kind = "scenario", needs = NEEDS, when = guardOn,
		check = function(ctx)
			ready(ctx)
			rider(ctx, "Zed Quick")
			run(ctx, 200)
			if paused(ctx) then ctx:fail("You are open and idle, a rider has waited under four minutes and you are already paused as away.") end
			run(ctx, 80)
			if not paused(ctx) then ctx:fail("You are open and do nothing for over five minutes with a rider waiting, and Wuber never pauses you as away.") end
		end,
	}

	Hunt.promise{
		id = "v241.away.resume_holds",
		area = "Away pause",
		text = "After the away pause you press Resume: you are not paused again at once; the pause only comes back after another full four minutes of nothing.",
		source = "AU24-02 (f84aa8e4)",
		kind = "scenario", needs = NEEDS, when = guardOn,
		check = function(ctx)
			ready(ctx)
			rider(ctx, "Zed Quick")
			run(ctx, 260)
			if not paused(ctx) then ctx:na("the away pause did not fire") end
			DR(ctx).SetPaused(false)
			ctx:note("Resume")
			ctx:advance(1)
			run(ctx, 180)
			if paused(ctx) then ctx:fail("You press Resume after the away pause and, three minutes later, Wuber has paused you again for the same waiting rider.") end
			run(ctx, 100)
			if not paused(ctx) then ctx:fail("You press Resume and then stay idle for over four minutes with a rider waiting, and the away pause never comes back.") end
		end,
	}

	Hunt.promise{
		id = "v241.away.crew_resume_holds",
		area = "Away pause",
		text = "When a crew mate presses Resume for your crew, the away clock starts again: you are not paused again within the next few minutes.",
		source = "Google G12 (ac8c6d25): a crew Resume (PAU) restarts the away clock",
		kind = "scenario", needs = NEEDS, when = guardOn,
		check = function(ctx)
			ready(ctx)
			rider(ctx, "Zed Quick")
			run(ctx, 260)
			if not paused(ctx) then ctx:na("the away pause did not fire") end
			DR(ctx).Apply("PAU", "Crew Mate", "0")
			ctx:note("crew mate Resume (PAU 0)")
			ctx:advance(1)
			if paused(ctx) then ctx:na("a crew Resume from a stranger did not resume me (not my crew)") end
			run(ctx, 180)
			if paused(ctx) then ctx:fail("A crew mate presses Resume and three minutes later you are paused again as away.") end
		end,
	}

	Hunt.promise{
		id = "v241.away.offline_rider_not_counted",
		area = "Away pause",
		text = "A rider who logs off while waiting on your list does not get you paused as away.",
		source = "AU24-29 (f84aa8e4): offline riders do not count",
		kind = "scenario", needs = NEEDS, when = guardOn,
		check = function(ctx)
			ready(ctx)
			rider(ctx, "Zed Quick")
			local p = ctx.w:player("Zed Quick")
			if not p then ctx:cannot("no rider") end
			p.online = false
			ctx:note("rider logs off")
			run(ctx, 320)
			if paused(ctx) then ctx:fail("The only rider on your list logged off and, five minutes on, Wuber paused you as away because of them.") end
		end,
	}

	Hunt.promise{
		id = "v241.away.busy_driver_not_paused",
		area = "Away pause",
		text = "While you keep summoning riders one after another, a rider who waits at the back of the queue for over four minutes does not get you paused as away.",
		source = "AU24-01 (f84aa8e4): fires only when the driver is idle",
		kind = "scenario", needs = NEEDS, when = guardOn,
		check = function(ctx)
			ready(ctx)
			local names = { "Zed Quick", "Eve Long", "Fay Stone", "Gus Hale" }
			for _, n in ipairs(names) do rider(ctx, n) end
			for i = 1, 3 do
				run(ctx, 75)
				local ok1 = pcall(DR(ctx).Do, "CAST", names[i])
				local ok2 = pcall(DR(ctx).Do, "END", names[i], 1)
				ctx:note("summoned " .. names[i])
				if not (ok1 and ok2) then ctx:cannot("could not summon") end
			end
			run(ctx, 85)
			if paused(ctx) then ctx:fail("You summoned a rider less than two minutes ago, another rider has waited over four minutes, and Wuber paused you as away.") end
		end,
	}

	Hunt.promise{
		id = "v241.away.guard_off_never_pauses",
		area = "Away pause",
		text = "With 'Pause me if I'm away' switched off, a waiting rider and an idle driver never get you paused.",
		source = "guard for the unchanged awayGuard setting path",
		kind = "scenario", needs = { role = "warlock", ride = "none", opt_awayGuard = "off" },
		when = function(sit) return canDrive(sit) and sit.group ~= "raid" end,
		check = function(ctx)
			ready(ctx)
			rider(ctx, "Zed Quick")
			run(ctx, 320)
			if paused(ctx) then ctx:fail("'Pause me if I'm away' is off, you sit idle with a rider waiting, and Wuber pauses you anyway.") end
		end,
	}
end
