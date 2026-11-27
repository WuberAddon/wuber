-- Promises about the LOOKS (owner NET): crowns and badges over heads, the Pioneers' emblem, the mouse-over line, and the
-- screen effects (stopping in combat, on loading screens, with the Effects setting).
-- Written from what the player was told: Settings > Sound and effects > Effects (Full / Light / Off tooltips), Settings >
-- Map (Crowns and badges over heads, Pioneer emblems), /wuber emblem, the file headers of Wuber/FX.
-- Stand-ins: the shipped Pioneer lists are empty today, so the emblem promises give the check's own list (a poke of the
-- list, the way tests/fx/emblem_test.lua does); the arrival-over-a-loading-screen promise fires the game's own
-- loading-screen events and the ride's arrival event (the real summon click is the ride dial's, not reachable here).
return function(Hunt)
	local function is(sit, dial, want)
		local v = sit[dial]
		if v == nil then return true end
		if type(want) == "table" then return want[v] == true end
		return v == want
	end

	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end

	local function fxMod(ctx)
		local FX = ctx.W.FX
		if not (type(FX) == "table" and type(FX.Stats) == "function") then ctx:cannot("this Wuber has no effects (W.FX)") end
		return FX
	end

	-- a full-screen effect is up now (what FX.Stats counts: the layered screen effects and the shared driver frame)
	local function screenEffect(ctx)
		local FX = fxMod(ctx)
		local s = FX.Stats()
		-- (s.driver is the shared animation frame: it also runs crowns and badges, so it says nothing about screen effects.
		-- s.playing counts every FX effect, also the small ones inside a window (the First Ride card's disc): only the effects
		-- FX.Fullscreen starts are full-screen, and their box is a frame of Effects.lua parented to UIParent, strata LOW)
		if (s.playing or 0) == 0 then return false, s end
		local U = dofile("tests/hunt/lib/universal_util.lua")
		local St, UIP, n = ctx.H.state, ctx.me.env.UIParent, 0
		for _, obj in ipairs(ctx.me.widgets or {}) do
			local o = St[obj]
			if o and o.otype == "Frame" and o.parent == UIP and ctx.H.visible(obj) and tostring(U.E.nameOf(obj)):find("Effects.lua", 1, true)
				and obj:GetFrameStrata() == "LOW" then
				n = n + 1
			end
		end
		s.fullscreen = n
		return n > 0, s
	end

	local function inCombat(ctx) return ctx.me.player.combat == true end

	-- Settings, as the gear button opens them: an open Help page (or Settings) is closed first (Window.lua gear: CloseSettings
	-- closes both), else Help stays on top of Settings and a click lands on Help
	local function openSettings(ctx, page)
		local UI = ctx.W.UI
		if type(UI.OpenSettings) ~= "function" then ctx:cannot("no Settings") end
		if (type(UI.HelpShown) == "function" and UI.HelpShown()) or (UI.state and UI.state.settingsOpen) then
			if type(UI.CloseSettings) == "function" then UI.CloseSettings() end
			if type(UI.HelpShown) == "function" and UI.HelpShown() and type(UI.CloseHelp) == "function" then UI.CloseHelp(true) end
			ctx:note("close the open Help / Settings page first")
			ctx:advance(0.8)
		end
		-- (job 2680) an open Report a bug sheet is a modal dim over the page (UI.Bug, E3b-01): the player closes it first
		if UI.Bug and UI.Bug.Shown and UI.Bug.Shown() and UI.Bug.Close then UI.Bug.Close() ctx:note("close the Report a bug sheet first") ctx:advance(0.5) end
		UI.OpenSettings(page)
	end

	local function onScreen(ctx) return "on screen: " .. table.concat(ctx:texts(), " | ") end

	local function waitFor(ctx, pred, secs, step)
		step = step or 0.5
		local t = 0
		while not pred() do
			if t >= secs then return false end
			ctx:advance(step)
			t = t + step
		end
		return true
	end

	---------------------------------------------------------------------------------------------------------------
	-- 1. Screen effects
	---------------------------------------------------------------------------------------------------------------
	Hunt.promise{
		id = "looks.light_no_fullscreen",
		area = "Looks",
		text = "With Effects on Light there are no full-screen effects (only badges and small effects in the window).",
		source = "Settings > Sound and effects > Effects: 'Light: no full-screen effects, still badges' / 'Effects in the window only'",
		kind = "scenario",
		needs = { role = "rider", ride = "summoning", fx = "light" },
		when = function(sit) return is(sit, "combat", "no") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local FX = fxMod(ctx)
			if FX.Mode() ~= "light" then ctx:na("effects are not on Light") end
			local up, s = screenEffect(ctx)
			if up then
				ctx:fail("You set Effects to Light (the setting says there are no full-screen effects) and your summon is ready: a full-screen portal still plays.",
					("FX.Stats: playing %s"):format(tostring(s.playing)))
			end
		end,
	}

	Hunt.promise{
		id = "looks.off_nothing_plays",
		area = "Looks",
		text = "With Effects Off, no screen effect is playing.",
		source = "Settings > Sound and effects > Effects: 'Off: no effects at all, nothing moves'",
		kind = "always",
		when = function(sit) return sit.fx == "off" end,
		check = function(ctx)
			local FX = ctx.W.FX
			if not (type(FX) == "table" and type(FX.Stats) == "function" and type(FX.Mode) == "function") then return end
			if FX.Mode() ~= "off" then return end
			local up, s = screenEffect(ctx)
			if up then ctx:fail("Effects are Off and a screen effect is playing.", ("FX.Stats: playing %s"):format(tostring(s.playing))) end
		end,
	}

	Hunt.promise{
		id = "looks.combat_nothing_plays",
		area = "Looks",
		text = "While you are in combat no full-screen effect is playing.",
		source = "FX.Effects / FX.Moments headers: never in combat; entering combat stops them",
		kind = "always",
		when = function(sit) return sit.combat ~= nil and sit.combat ~= "no" end,
		check = function(ctx)
			local FX = ctx.W.FX
			if not (type(FX) == "table" and type(FX.Stats) == "function") then return end
			if not inCombat(ctx) then return end
			local up, s = screenEffect(ctx)
			if up then ctx:fail("You are in combat and a full-screen effect is on your screen.", ("FX.Stats: playing %s"):format(tostring(s.playing))) end
		end,
	}

	Hunt.promise{
		id = "looks.combat_stops_effect",
		area = "Looks",
		text = "When combat starts while a full-screen effect is playing, the effect stops at once.",
		source = "FX.Moments header: 'Entering combat immediately stops all active full-screen effects'; FX.Effects header",
		kind = "scenario",
		needs = { role = "rider", ride = "summoning" },
		when = function(sit) return is(sit, "combat", "no") and sit.fx ~= "off" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("already in combat") end
			local up = screenEffect(ctx)
			if not up then ctx:na("no full-screen effect was playing") end
			ctx.w:enterCombat(ctx.me)
			ctx:note("a foe attacks: combat starts")
			ctx:advance(1)
			local up2, s = screenEffect(ctx)
			if up2 then
				ctx:fail("A portal effect is on screen, combat starts, and a second later the effect is still there.", ("FX.Stats: playing %s"):format(tostring(s.playing)))
			end
		end,
	}

	Hunt.promise{
		id = "looks.off_switch_stops",
		area = "Looks",
		text = "Switching Effects to Off in Settings stops a playing screen effect at once.",
		source = "Settings > Sound and effects > Effects: Off; FX.Effects header (Refresh)",
		kind = "scenario",
		needs = { role = "rider", ride = "summoning" },
		when = function(sit) return is(sit, "combat", "no") and sit.fx ~= "off" and sit.session ~= "first" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local up = screenEffect(ctx)
			if not up then ctx:na("no full-screen effect was playing") end
			local UI = ctx.W.UI
			openSettings(ctx, "sound")
			ctx:advance(1)
			local c = UI.settings and UI.settings.controls and UI.settings.controls.fx
			if not (c and ctx:visible(c)) then ctx:cannot("the Effects choice is not on screen (Settings > Sound and effects)") end
			if not ctx.me:clickText("Off") then ctx:cannot("no Off segment to click") end
			ctx:note("click Off under Effects")
			ctx:advance(0.5)
			local up2, s = screenEffect(ctx)
			if up2 then
				ctx:fail("A portal effect is playing, you click Off under Effects, and the effect carries on.", ("FX.Stats: playing %s"):format(tostring(s.playing)))
			end
		end,
	}

	Hunt.promise{
		id = "looks.loading_screen_holds_arrival",
		area = "Looks",
		text = "While a loading screen is up no screen effect starts; the arrival effect plays once it is over.",
		source = "FX.Moments header: the arrival effect is delayed if a loading screen is active",
		kind = "scenario",
		needs = { role = "rider", ride = "summoning" },
		when = function(sit) return is(sit, "combat", "no") and sit.fx ~= "off" and sit.fx ~= "light" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local W = ctx.W
			local r = W.ride
			if not (type(r) == "table" and r.id) then ctx:cannot("no ride") end
			ctx.me:fire("PLAYER_LEAVING_WORLD")
			ctx:note("a loading screen starts (you take the summon)")
			-- the summon is taken (the game's own ride event: the ride has arrived)
			W.Fire("RIDE", { id = r.id, state = "arrived", dest = r.dest })
			ctx:advance(2)
			local up, s = screenEffect(ctx)
			if up then
				ctx:fail("You take a summon and the loading screen is up: a screen effect already plays behind it.", ("FX.Stats: playing %s"):format(tostring(s.playing)))
			end
			ctx.me:fire("PLAYER_ENTERING_WORLD", false, false)
			ctx:note("the loading screen ends")
			local came = waitFor(ctx, function() return (screenEffect(ctx)) end, 3, 0.2)
			if not came then
				ctx:fail("You take a summon through a loading screen and, when it ends, no arrival effect plays.", onScreen(ctx))
			end
		end,
	}

	---------------------------------------------------------------------------------------------------------------
	-- 2. Crowns, badges and the mouse-over line
	---------------------------------------------------------------------------------------------------------------
	local FOUNDER = "Anita Lift"
	local OTHER_REALM = "CAMWOW US2 Realm 1 PvP"

	local function plates(ctx)
		-- friendly nameplates are the player's own game setting (Settings > Map has a button for it)
		ctx.me.cvars.nameplateShowFriends = "1"
	end

	local function bot(ctx, name, class)
		if not ctx.w:player(name) then ctx.w:addBot(name, { spot = "Orgrimmar", class = class or "MAGE" }) end
	end

	local function show(ctx, name)
		ctx.me:showPlate(name, { force = true })
	end

	local function kinds(ctx, name)
		local out = {}
		for _, f in ipairs(ctx.me:onPlate(name)) do out[#out + 1] = tostring(f.plateKind or (f.orb and "emblem") or "?") end
		return out
	end

	local function hasKind(ctx, name, kind)
		for _, k in ipairs(kinds(ctx, name)) do if k == kind then return true end end
		return false
	end

	local function line(lines, part)
		for _, l in ipairs(lines) do if tostring(l):find(part, 1, true) then return l end end
		return nil
	end

	local function plateSetting(ctx)
		local db = ctx.W.db
		if type(db) == "table" and db.plates == false then ctx:na("Crowns and badges over heads is off") end
	end

	local PLATE_WHEN = function(sit) return sit.session ~= "first" end

	Hunt.promise{
		id = "looks.founder_crown",
		area = "Looks",
		text = "On the founders' ruleset a founder's nameplate carries the spinning crown.",
		source = "FX.Nameplates header; Settings > Map > Crowns and badges over heads",
		kind = "scenario",
		when = function(sit) return sit.mapPins ~= "off" and not is(sit, "combat", { before = true }) end,
		check = function(ctx)
			plateSetting(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			if ctx.W.OnFounderRuleset and not ctx.W.OnFounderRuleset() then ctx:na("not on the founders' ruleset") end
			plates(ctx)
			bot(ctx, FOUNDER)
			show(ctx, FOUNDER)
			ctx:advance(3)
			if not hasKind(ctx, FOUNDER, "crown") then
				ctx:fail("Anita Lift (a founder) stands in view with her nameplate showing and there is no crown over her head.",
					"frames on her plate: " .. table.concat(kinds(ctx, FOUNDER), ","))
			end
		end,
	}

	Hunt.promise{
		id = "looks.founder_ruleset_only",
		area = "Looks",
		text = "Outside the founders' ruleset a player called Anita Lift gets no crown and no founder line: the name alone proves nothing.",
		source = "CLAUDE.md: founder status is locked to EU-PvE and the founders' names",
		kind = "scenario",
		when = function(sit) return not is(sit, "combat", { before = true }) end,
		check = function(ctx)
			plateSetting(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local oldRealm = ctx.me.realm
			ctx.me.realm = OTHER_REALM
			if ctx.W.OnFounderRuleset and ctx.W.OnFounderRuleset() then
				ctx.me.realm = oldRealm
				ctx:cannot("could not move the player to another ruleset")
			end
			plates(ctx)
			bot(ctx, FOUNDER)
			show(ctx, FOUNDER)
			ctx:advance(3)
			local crown = hasKind(ctx, FOUNDER, "crown")
			local tip = line(ctx.me:hover(FOUNDER), "founder")
			ctx.me.realm = oldRealm
			if crown then ctx:fail("You play on a PvP realm of another region and a player called Anita Lift wears the founder's crown.") end
			if tip then ctx:fail("You play on a PvP realm of another region and the mouse-over of a player called Anita Lift says " .. tostring(tip) .. ".") end
		end,
	}

	Hunt.promise{
		id = "looks.founder_tooltip",
		area = "Looks",
		text = "Out of combat, pointing the mouse at the founder shows a Wuber founder line in the tooltip, and at an ordinary player no Wuber line.",
		source = "FX.Nameplates header: the tooltip line 'Wuber founder'",
		kind = "scenario",
		when = function(sit) return is(sit, "combat", "no") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			if ctx.W.OnFounderRuleset and not ctx.W.OnFounderRuleset() then ctx:na("not on the founders' ruleset") end
			bot(ctx, FOUNDER)
			bot(ctx, "Dee Nobody")
			ctx:advance(1)
			local a = ctx.me:hover(FOUNDER)
			if not line(a, "Wuber founder") then
				ctx:fail("You point the mouse at Anita Lift (a founder) and her tooltip has no Wuber founder line.", "tooltip: " .. table.concat(a, " / "))
			end
			local b = ctx.me:hover("Dee Nobody")
			local l = line(b, "Wuber")
			if l then ctx:fail("You point the mouse at an ordinary player and her tooltip has a Wuber line: " .. l .. ".", "tooltip: " .. table.concat(b, " / ")) end
		end,
	}

	Hunt.promise{
		id = "looks.driver_badge_and_line",
		area = "Looks",
		text = "An open Wuber driver who picked a badge wears it over his head, and pointing the mouse at him shows a Wuber driver line.",
		source = "FX.Nameplates header: 'Wuber driver · 50s to Undercity'; Settings > Map > Crowns and badges over heads",
		kind = "scenario",
		needs = { role = "rider" },
		when = function(sit) return is(sit, "combat", "no") end,
		check = function(ctx)
			plateSetting(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			plates(ctx)
			local name = "Zed Hale"
			if ctx.w:player(name) then ctx:cannot("the name is taken") end
			local d = ctx.w:addClient(name, { spot = "Orgrimmar", class = "WARLOCK", shards = 10 })
			if d.W.Char then d.W.Char().welcomed = true d.W.Char().wizard = true d.W.Char().badge = "star" end -- the driver picked a badge
			if d.W.Driver.SetOnline(true) == false then ctx:cannot("he could not go online") end
			ctx:note(name .. " goes online")
			if not waitFor(ctx, function() return ctx.W.drivers and ctx.W.drivers[key(name)] end, 20, 1) then ctx:cannot("his beacon never reached me") end
			show(ctx, name)
			ctx:advance(3)
			local ks = kinds(ctx, name)
			if #ks == 0 then
				ctx:fail("A Wuber driver who picked the star badge is open, in view with his nameplate showing, and has no badge over his head.")
			end
			local l = ctx.me:hover(name)
			if not line(l, "Wuber driver") then
				ctx:fail("You point the mouse at an open Wuber driver and his tooltip has no Wuber driver line.", "tooltip: " .. table.concat(l, " / "))
			end
		end,
	}

	Hunt.promise{
		id = "looks.plates_off_clears",
		area = "Looks",
		text = "Turning Crowns and badges over heads off in Settings takes every crown and badge off at once.",
		source = "Settings > Map > Crowns and badges over heads; FX.Nameplates header",
		kind = "scenario",
		when = function(sit) return is(sit, "combat", "no") and PLATE_WHEN(sit) end,
		check = function(ctx)
			plateSetting(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			if ctx.W.OnFounderRuleset and not ctx.W.OnFounderRuleset() then ctx:na("not on the founders' ruleset") end
			plates(ctx)
			bot(ctx, FOUNDER)
			show(ctx, FOUNDER)
			ctx:advance(3)
			if not hasKind(ctx, FOUNDER, "crown") then ctx:na("no crown to take away") end
			local UI = ctx.W.UI
			openSettings(ctx, "map")
			ctx:advance(1)
			local c = UI.settings and UI.settings.controls and UI.settings.controls.plates
			if not (c and ctx:visible(c)) then ctx:cannot("the Crowns and badges switch is not on screen") end
			ctx.me:clickOn(c)
			ctx:note("click Crowns and badges over heads (off)")
			ctx:advance(3)
			if #kinds(ctx, FOUNDER) > 0 then
				ctx:fail("You switch Crowns and badges over heads off and the founder still wears her crown.", "frames: " .. table.concat(kinds(ctx, FOUNDER), ","))
			end
		end,
	}

	---------------------------------------------------------------------------------------------------------------
	-- 3. The Pioneers' emblem (the shipped lists are empty today: the check names its own Pioneers)
	---------------------------------------------------------------------------------------------------------------
	local PIO_RIDER, PIO_DRIVER = "Bob Stone", "Cal Brown"

	local function emblemOf(ctx, name)
		for _, f in ipairs(ctx.me:onPlate(name)) do
			if f.orb and f.halo and f.ring then return f end
		end
		return nil
	end

	local function pioneers(ctx, riders, drivers)
		local W = ctx.W
		if not (type(W.Emblem) == "table" and type(W.Emblem.Command) == "function") then ctx:cannot("this Wuber has no Pioneer emblem (W.Emblem)") end
		if ctx.me.realm and W.OnFounderRuleset and not W.OnFounderRuleset() and W.Ruleset() == nil then ctx:cannot("the realm names no ruleset") end
		local rs = W.Ruleset() or "EU-PvE"
		W.PIONEERS = { riders = { [rs] = riders }, drivers = { [rs] = drivers } }
		ctx:note("the Pioneer lists name " .. table.concat(riders, ", ") .. " (riders) and " .. table.concat(drivers, ", ") .. " (drivers)")
	end

	local function showAll(ctx, names)
		for _, n in ipairs(names) do bot(ctx, n) show(ctx, n) end
		ctx:advance(3)
	end

	local EMBLEM_WHEN = function(sit) return is(sit, "combat", "no") and sit.session ~= "first" end

	Hunt.promise{
		id = "looks.emblem_colours",
		area = "Looks",
		text = "A Pioneer driver shows a teal emblem and a Pioneer rider a violet one; the founder keeps the crown, and an ordinary player has nothing.",
		source = "BRIEF15 / BRIEF16; FX.Emblem header",
		kind = "scenario",
		when = EMBLEM_WHEN,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			plateSetting(ctx)
			if ctx.W.db and ctx.W.db.emblems == false then ctx:na("Pioneer emblems are off") end
			if ctx.W.OnFounderRuleset and not ctx.W.OnFounderRuleset() then ctx:na("not on the founders' ruleset") end
			plates(ctx)
			pioneers(ctx, { PIO_RIDER, FOUNDER }, { PIO_DRIVER })
			showAll(ctx, { PIO_RIDER, PIO_DRIVER, FOUNDER, "Dee Nobody" })
			local r, d = emblemOf(ctx, PIO_RIDER), emblemOf(ctx, PIO_DRIVER)
			if not r then ctx:fail("A Pioneer rider is in view with his nameplate showing and has no emblem over his head.") end
			if not d then ctx:fail("A Pioneer driver is in view with his nameplate showing and has no emblem over his head.") end
			local function tex(f) return tostring(ctx.H.S and ctx.H.S[f.orb] and ctx.H.S[f.orb].texture or "") end
			local tr, td = tex(r), tex(d)
			if tr ~= "" and td ~= "" and tr == td then
				ctx:fail("A Pioneer rider and a Pioneer driver stand side by side and both emblems have the same colour.", tr)
			end
			if emblemOf(ctx, FOUNDER) then ctx:fail("A founder who is also on the Pioneer list wears an emblem as well as her crown (the crown should be all).") end
			if emblemOf(ctx, "Dee Nobody") then ctx:fail("An ordinary player, not on any list, has an emblem over her head.") end
		end,
	}

	Hunt.promise{
		id = "looks.emblem_command_off",
		area = "Looks",
		text = "/wuber emblem off takes every Pioneer emblem off your screen and /wuber emblem on brings them back.",
		source = "/wuber help (emblem [on|off]); Settings > Map > Pioneer emblems over heads",
		kind = "scenario",
		when = EMBLEM_WHEN,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			if ctx.W.OnFounderRuleset and not ctx.W.OnFounderRuleset() then ctx:na("not on the founders' ruleset") end
			plates(ctx)
			pioneers(ctx, { PIO_RIDER }, { PIO_DRIVER })
			showAll(ctx, { PIO_RIDER, PIO_DRIVER })
			if not emblemOf(ctx, PIO_RIDER) then ctx:na("no emblem to take away (see looks.emblem_colours)") end
			ctx.me:slash("/wuber emblem off")
			ctx:note("/wuber emblem off")
			ctx:advance(3)
			if emblemOf(ctx, PIO_RIDER) or emblemOf(ctx, PIO_DRIVER) then
				ctx:fail("You type /wuber emblem off and Pioneer emblems are still over heads.")
			end
			ctx.me:slash("/wuber emblem on")
			ctx:note("/wuber emblem on")
			showAll(ctx, { PIO_RIDER, PIO_DRIVER })
			if not emblemOf(ctx, PIO_RIDER) then ctx:fail("You type /wuber emblem on and the Pioneer emblems do not come back.") end
		end,
	}

	Hunt.promise{
		id = "looks.emblem_at_most_six",
		area = "Looks",
		text = "No more than six Pioneer emblems show at the same time, however many Pioneers are in view.",
		source = "FX.Emblem header: at most 6 holders",
		kind = "scenario",
		when = EMBLEM_WHEN,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			if ctx.W.OnFounderRuleset and not ctx.W.OnFounderRuleset() then ctx:na("not on the founders' ruleset") end
			plates(ctx)
			local names = { "Pia One", "Pia Two", "Pia Three", "Pia Four", "Pia Five", "Pia Six", "Pia Seven", "Pia Eight" }
			pioneers(ctx, names, {})
			showAll(ctx, names)
			local n = 0
			for _, name in ipairs(names) do if emblemOf(ctx, name) then n = n + 1 end end
			if n > 6 then ctx:fail(("Eight Pioneers stand in view and %d of them have an emblem (the most is six)."):format(n)) end
			if n == 0 then ctx:na("no emblem shows at all") end
		end,
	}

	Hunt.promise{
		id = "looks.emblem_look_remembered",
		area = "Looks",
		text = "The emblem look you pick with /wuber emblem 1, 2 or 3 is still your pick after a /reload.",
		source = "/wuber help (emblem [1|2|3]); FX.Emblem header ('the choice is remembered')",
		kind = "scenario",
		when = function(sit) return sit.session ~= "first" end,
		check = function(ctx)
			local W = ctx.W
			if not (type(W.Emblem) == "table" and type(W.Emblem.Look) == "function") then ctx:cannot("no emblem look") end
			local want = W.Emblem.Look() == 3 and 1 or 3
			ctx.me:slash("/wuber emblem " .. want)
			ctx:note("/wuber emblem " .. want)
			ctx:advance(1)
			if W.Emblem.Look() ~= want then
				ctx:fail(("You type /wuber emblem %d and the look is %s."):format(want, tostring(W.Emblem.Look())))
			end
			ctx:reload()
			ctx:advance(2)
			local now = ctx.W.Emblem.Look()
			if now ~= want then
				ctx:fail(("You pick emblem look %d, /reload, and the look is %s again."):format(want, tostring(now)))
			end
		end,
	}
end
