-- Promises of the second wave (shell2): CHECK MY GAME, the first-open coach marks step by step, the minimap button's
-- clicks, the share pills, the toast queue, the "A newer Wuber is out" note, the founders' looks, and the Help page.
-- Written from what the player was told: Settings > This window > Check my game ("See what your game supports."),
-- the coach card's own words (TIP n OF 5, Next, Skip tips, Got it, "Settings > Replay tips shows them again"), the
-- minimap tooltip ("Left-click: open or close. Right-click: your driver console. Shift-right-click: pause or resume
-- driving. Drag: move."), the Update switch's tooltip, "How Wuber finds drivers" (Help) and its footer.
-- A stand-in used here: a released build's version number for the update note (this build says "-dev", for which the note
-- is off by design): the check hands its window a plain version at login, as a CurseForge build has.
return function(Hunt)
	local function is(sit, dial, want)
		local v = sit[dial]
		if v == nil then return true end
		if type(want) == "table" then return want[v] == true end
		return v == want
	end

	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end

	local function ui(ctx)
		local K = ctx:mod("UI.Kit")
		return K and K.ui or {}
	end

	local function shown(ctx)
		local U = ctx.W.UI
		if U and type(U.IsShown) == "function" then return U.IsShown() == true end
		local win = ui(ctx).win
		return win ~= nil and win:IsShown() == true
	end

	local function inCombat(ctx) return ctx.me.player.combat == true end

	-- cards a player closes before going on: the Report a bug sheet (its x) and the What's new card (Got it)
	local function closeCardsInTheWay(ctx)
		local U = ctx.W.UI
		if U.Bug and type(U.Bug.Shown) == "function" and U.Bug.Shown() == true and type(U.Bug.Close) == "function" then
			U.Bug.Close()
			ctx:advance(0.8)
			ctx:note("close the Report a bug sheet")
		end
		local nc = rawget(ctx.me.env, "WuberNewsCard")
		if type(nc) == "table" and type(nc.IsShown) == "function" and nc:IsShown() == true then
			local b = ctx.me:button("Got it")
			if b and ctx:visible(b) then
				ctx.me:clickOn(b)
				ctx:advance(0.8)
				ctx:note("click Got it on the What's new card")
			end
		end
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

	local function visibleText(ctx, pattern)
		for _, t in ipairs(ctx:texts()) do
			if t:find(pattern) then return t end
		end
		return nil
	end

	-- the player opens Wuber (the minimap button's toggle)
	local function openPhone(ctx)
		if not shown(ctx) then
			ctx.W.UI.Toggle(true)
			ctx:note("open the phone")
		end
	end

	local function lastChat(ctx, from, pattern)
		local lines = ctx.me.chatLines or {}
		for i = #lines, from + 1, -1 do
			if tostring(lines[i]):find(pattern) then return lines[i] end
		end
		return nil
	end

	---------------------------------------------------------------------------------------------------------------
	-- CHECK MY GAME
	---------------------------------------------------------------------------------------------------------------
	Hunt.promise{
		id = "check.skipped_not_passed",
		area = "Check my game",
		text = "In combat Wuber does not try its request button: /wuber test counts only the checks it ran (one fewer than out of combat) and no check in the list says the request button was tried.",
		source = "Settings > This window > Check my game (\"See what your game supports.\"); Commands.lua (SelfTest)",
		kind = "scenario",
		when = function(sit) return sit.combat == "before" or sit.combat == "after" end,
		check = function(ctx)
			if not inCombat(ctx) then ctx:na("not in combat") end
			local n0 = #(ctx.me.chatLines or {})
			ctx.me:slash("/wuber test")
			ctx:note("type /wuber test in combat")
			ctx:advance(0.5)
			if type(ctx.W.SelfTest) ~= "function" then ctx:cannot("no W.SelfTest") end
			local okL, list = pcall(ctx.W.SelfTest)
			if not (okL and type(list) == "table") then ctx:cannot("W.SelfTest raised") end
			for _, c in ipairs(list) do
				if tostring(c.name):find("SecureActionButton", 1, true) then
					ctx:fail("You are in combat and Check my game lists the request button as tried although it cannot be.", tostring(c.name))
				end
			end
			local l = lastChat(ctx, n0, "checks? ")
			local said = l and tostring(l):match("(%d+) checks? passed") or (l and tostring(l):match("%d+ of (%d+) checks failed"))
			if not said then ctx:cannot("/wuber test said no count: " .. tostring(l)) end
			if tonumber(said) ~= #list then
				ctx:fail("You are in combat, type /wuber test, and the count it says is not the number of checks it ran.", tostring(l) .. " (list has " .. #list .. ")")
			end
		end,
	}

	local function settingsCheck(ctx)
		local U = ctx.W.UI
		if type(U.OpenSettings) ~= "function" then ctx:cannot("no Settings") end
		-- the Report a bug sheet dims the whole page: a player closes it before tapping Check
		if U.Bug and type(U.Bug.Shown) == "function" and U.Bug.Shown() and type(U.Bug.Close) == "function" then
			U.Bug.Close()
			ctx:advance(0.8)
			ctx:note("close the Report a bug sheet")
		end
		if not ui(ctx).settingsOpen then
			if (type(U.HelpShown) == "function" and U.HelpShown()) and type(U.CloseHelp) == "function" then U.CloseHelp(true) ctx:advance(0.8) end
			U.OpenSettings("window")
			ctx:advance(1.2)
			ctx:note("open Settings > This window")
		end
		local st = U.settings
		local b = st and st.controls and st.controls.check
		if not (b and ctx:visible(b)) then ctx:cannot("no Check my game button on screen") end
		ctx.me:clickOn(b)
		ctx:advance(1.5)
		ctx:note("click Check my game")
		local res = st.results
		if not (res and ctx:visible(res)) then ctx:fail("You press Check in Check my game and no result shows.", onScreen(ctx)) end
		return st, res
	end

	local function linesOf(ctx, res)
		local out = {}
		for _, l in ipairs(res.lines or {}) do
			if ctx:visible(l) then out[#out + 1] = l end
		end
		return out
	end

	Hunt.promise{
		id = "check.head_agrees_with_lines",
		area = "Check my game",
		text = "Check my game's heading agrees with the list under it: it says everything passed only when no line under it has a cross, and it counts every cross.",
		source = "Settings > This window > Check my game (heading 'All N checks passed. Your game runs Wuber fully.')",
		kind = "scenario",
		when = function(sit) return is(sit, "combat", "no") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local st, res = settingsCheck(ctx)
			local lines = linesOf(ctx, res)
			local crosses, names = 0, {}
			for _, l in ipairs(lines) do
				if l.ok ~= true then crosses = crosses + 1 names[#names + 1] = tostring(l.name) end
			end
			local head = res.head and res.head:GetText() or ""
			-- 2.4 heading: "All 14 game checks passed. 1 driver line needs a look: see your Drive tab." when only driver lines are crossed
			local n = head:match("^All (%d+) game checks passed") or head:match("^All (%d+) checks passed")
			local gameWords = head:find("^All %d+ game checks passed") ~= nil
			if n and crosses > 0 and gameWords then
				local k = tonumber(head:match("(%d+) [%a ]-lines? needs? a look") or head:match("(%d+) [%a ]-lines? need a look"))
				if not k then
					ctx:fail(("Check my game says \"All %s game checks passed\" and a line under it has a cross (%s), but the heading does not say that lines need a look."):format(n, table.concat(names, ", ")), head)
				elseif k ~= crosses then
					ctx:fail(("Check my game says %d lines need a look and %d lines under it have a cross (%s)."):format(k, crosses, table.concat(names, ", ")), head)
				end
			elseif n and crosses > 0 then
				ctx:fail(("Check my game says \"All %s checks passed. Your game runs Wuber fully.\" and a line under it has a cross (%s)."):format(n, table.concat(names, ", ")), head)
			end
			local p, f = head:match("^(%d+) passed, (%d+) not working")
			if p and tonumber(f) < crosses then
				ctx:fail(("Check my game says %s lines are not working and %d lines have a cross."):format(f, crosses), head)
			end
			if not n and not p then ctx:fail("Check my game's heading says neither that everything passed nor how many did not.", head) end
		end,
	}

	Hunt.promise{
		id = "check.test_command_agrees_with_panel",
		area = "Check my game",
		text = "/wuber test and Settings' Check my game tell the same story: what the command says failed is what the panel shows with a cross.",
		source = "Commands.lua header (W.SelfTest feeds Settings' panel and /wuber test)",
		kind = "scenario",
		when = function(sit) return is(sit, "combat", "no") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			ctx:advance(10) -- the network channel is joined a few seconds after login: let the game settle first
			local n0 = #(ctx.me.chatLines or {})
			ctx.me:slash("/wuber test")
			ctx:note("type /wuber test")
			ctx:advance(0.5)
			local say = lastChat(ctx, n0, "checks? ")
			if not say then ctx:fail("You type /wuber test and nothing is said in chat.") end
			local st, res = settingsCheck(ctx)
			-- only the lines W.SelfTest gives (the panel adds the driver's own readiness lines after them)
			local list = ctx.W.SelfTest()
			local fails = 0
			for _, c in ipairs(list) do if not c.ok then fails = fails + 1 end end
			local cmdAll = say:find("All %d+ checks passed") ~= nil
			local cmdN = tonumber(say:match("^.-(%d+) of %d+ checks failed") or say:match("(%d+) of %d+ checks failed"))
			local head = res.head and res.head:GetText() or ""
			-- with a crossed driver line the heading reads "All N game checks passed. 1 driver line needs a look"; only the game checks count here
			local panelAll = (head:find("^All %d+ game checks passed") or head:find("^All %d+ checks passed")) ~= nil
			if cmdAll ~= panelAll then
				ctx:fail("/wuber test and the Check my game panel disagree: one says everything passed and the other does not.", tostring(say) .. " / " .. head)
			end
			if cmdN and cmdN ~= fails then ctx:fail("/wuber test says a different number of checks failed than the panel shows.", tostring(say) .. " / " .. head) end
		end,
	}



	---------------------------------------------------------------------------------------------------------------
	-- The first-open coach marks, step by step
	---------------------------------------------------------------------------------------------------------------
	-- the player opens Wuber for the first time, on Home, with the coach marks not finished, no ride, not in combat
	local COACH_WHEN = function(sit)
		return is(sit, "coach", "not_done") and is(sit, "combat", "no") and is(sit, "ride", "none")
			and is(sit, "phone", { closed = true, splash = true, home = true })
	end

	local function coachCard(ctx)
		local b = ui(ctx).coach
		if b and ctx:visible(b) and ctx:visible(b.step) then return b end
		return nil
	end

	local function stepNo(b)
		local n = tostring(b.step:GetText() or ""):match("Tip (%d+) of")
		return tonumber(n)
	end

	local function coachSetup(ctx)
		if inCombat(ctx) then ctx:na("in combat") end
		local db = ctx.W.db
		if type(db) == "table" and db.coach == true then ctx:na("the coach marks are done") end
		local K = ctx:mod("UI.Kit")
		if K and type(K.rideActive) == "function" then
			local ok, a = pcall(K.rideActive)
			if ok and a then ctx:na("a ride is on") end
		end
		openPhone(ctx)
		local b
		waitFor(ctx, function() b = coachCard(ctx) return b ~= nil end, 8, 0.5)
		if not b then
			-- (2.4) UI.MayOpen: at a known flight master the Skip the bird card stands before the tips; a player taps
			-- "Don't show again" on it and then the tip comes
			local Bird = ctx:mod("UI.Bird")
			local card = Bird and type(Bird.Card) == "function" and Bird.Card() or nil
			if type(card) == "table" and type(card.IsShown) == "function" and card:IsShown() == true then
				local d = ctx.me:button("Don't show again")
				if not (d and ctx:visible(d)) then ctx:cannot("the Skip the bird card is up and has no Don't show again button to tap") end
				ctx.me:click(d)
				ctx:note("dismiss the Skip the bird card (Don't show again): it stands before the tips")
				ctx:advance(0.5)
				waitFor(ctx, function() b = coachCard(ctx) return b ~= nil end, 8, 0.5)
			end
		end
		if not b then
			ctx:fail("You open Wuber for the first time (the first-open tips were never finished) and no tip card with a gold ring shows.",
				"tab " .. tostring(ui(ctx).tab) .. ", screen " .. tostring(ui(ctx).screen) .. "; " .. onScreen(ctx))
		end
		return b
	end

	-- the card's box and the ringed thing's box, in the window's own units
	local function box(f)
		local l, r, b, t = f:GetLeft(), f:GetRight(), f:GetBottom(), f:GetTop()
		if not (l and r and b and t) then return nil end
		return { l = l, r = r, b = b, t = t }
	end
	local function overlap(a, b, slack)
		slack = slack or 0
		return a.l < b.r - slack and a.r > b.l + slack and a.b < b.t - slack and a.t > b.b + slack
	end

	Hunt.promise{
		id = "coachsteps.each_step_points_at_something",
		area = "Coach marks",
		text = "On your first open the tips go one by one (TIP 1 OF 5 and on), each with a gold ring round something that is on screen, the card never covering that thing, and the last one's button says Got it.",
		source = "Coach.lua header (five short tips inside the window, a gold ring round the thing a tip is about); the card's own words",
		kind = "scenario",
		when = COACH_WHEN,
		check = function(ctx)
			local b = coachSetup(ctx)
			local seen, lastN = {}, 0
			local sw, sh = ctx.me.env.UIParent:GetWidth(), ctx.me.env.UIParent:GetHeight()
			for _ = 1, 8 do
				local n = stepNo(b)
				if not n then ctx:fail("A tip card shows and its counter does not say which tip it is.", onScreen(ctx)) end
				if n == lastN then
					local nx = b.next
					local sc = nx:GetEffectiveScale() / ctx.me.env.UIParent:GetEffectiveScale()
					local hit = ctx.me:frameAt((nx:GetLeft() + nx:GetRight()) / 2 * sc, (nx:GetBottom() + nx:GetTop()) / 2 * sc)
					local over = hit and (hit.GetName and hit:GetName()) or tostring(hit)
					ctx:fail(("You click Next on TIP %d and the same tip stays: the Next button does not work."):format(n),
						"a click on the Next button lands on: " .. tostring(over))
				end
				if n < lastN then ctx:fail(("The tips go back: TIP %d comes after TIP %d."):format(n, lastN)) end
				lastN = n
				seen[#seen + 1] = n
				if tostring(b.title:GetText() or "") == "" then ctx:fail(("TIP %d has no title."):format(n)) end
				local ring = b.ring
				if not ctx:visible(ring) then ctx:fail(("TIP %d is up and no gold ring shows round the thing it is about."):format(n), onScreen(ctx)) end
				local rb, cb = box(ring), box(b)
				local ratio = ring:GetEffectiveScale() / ctx.me.env.UIParent:GetEffectiveScale()
				if rb and (rb.l * ratio < -1 or rb.b * ratio < -1 or rb.r * ratio > sw + 1 or rb.t * ratio > sh + 1) then
					ctx:fail(("TIP %d points at something that is off the edge of the screen."):format(n))
				end
				if rb and cb and overlap(rb, cb, 6) then
					ctx:fail(("TIP %d's card sits on top of the very thing it points at (\"%s\")."):format(n, tostring(b.title:GetText())))
				end
				local label = b.next.label and b.next.label:GetText() or ""
				if n == 5 and label ~= "Got it" then ctx:fail("On the last tip the button does not say Got it.", tostring(label)) end
				ctx.me:clickOn(b.next)
				ctx:advance(0.6)
				ctx:note(("click %s on tip %d"):format(tostring(label), n))
				b = coachCard(ctx)
				if not b then break end
			end
			if lastN < 3 then ctx:fail(("The tips stop after TIP %d: the first-open tour is cut short."):format(lastN), table.concat(seen, ",")) end
			if coachCard(ctx) then ctx:fail("You keep clicking Next and the tips never finish.", table.concat(seen, ",")) end
			if ctx.W.db.coach ~= true then ctx:fail("You click through every tip to Got it and Wuber does not remember it: the tips are not marked as done.") end
		end,
	}

	local function wasDoneThen(ctx, how)
		local b = coachSetup(ctx)
		if how == "skip" then
			ctx.me:clickOn(b.skip)
			ctx:note("click Skip tips")
		else
			for _ = 1, 8 do
				if not coachCard(ctx) then break end
				ctx.me:clickOn(b.next)
				ctx:advance(0.6)
				ctx:note("click Next")
			end
		end
		ctx:advance(1)
		if coachCard(ctx) then
			ctx:fail(how == "skip" and "You click Skip tips and the tip card stays." or ("You click Next again and again on the first-open tips and they never finish (stuck on " .. tostring(ui(ctx).coach.step:GetText()) .. ")."), onScreen(ctx))
		end
	end

	local function neverAgain(ctx, how)
		wasDoneThen(ctx, how)
		local W = ctx.W
		-- close and open again
		if shown(ctx) then W.UI.Toggle(false) ctx:advance(1) ctx:note("close Wuber") end
		W.UI.Toggle(true)
		ctx:advance(5)
		ctx:note("open Wuber again")
		if coachCard(ctx) then ctx:fail("You finished the first-open tips, closed Wuber and opened it again, and the tips are back.", onScreen(ctx)) end
		-- a /reload, then a real logout and login
		for _, how2 in ipairs({ "reload", "relog" }) do
			if how2 == "reload" then ctx:reload() else ctx:relog() end
			ctx:note(how2)
			ctx:advance(2)
			if not shown(ctx) then ctx.W.UI.Toggle(true) end
			ctx:advance(6)
			if coachCard(ctx) then
				ctx:fail(("You finished the first-open tips, did a %s and opened Wuber, and the tips start again."):format(how2 == "reload" and "/reload" or "logout and login"), onScreen(ctx))
			end
		end
	end

	Hunt.promise{
		id = "coachsteps.skip_is_final",
		area = "Coach marks",
		text = "Skip tips ends the first-open tips for good: not when you open Wuber again, not after a /reload, not after you log in again.",
		source = "Coach.lua (done only on Got it or Skip tips); tooltip (Skip tips: Hide these tips. Settings > Replay tips shows them again)",
		kind = "scenario",
		when = function(sit) return COACH_WHEN(sit) and sit.session ~= "first" end,
		check = function(ctx) neverAgain(ctx, "skip") end,
	}

	Hunt.promise{
		id = "coachsteps.got_it_is_final",
		area = "Coach marks",
		text = "Clicking through to Got it ends the first-open tips for good: not when you open Wuber again, not after a /reload, not after you log in again.",
		source = "Coach.lua (done only on Got it or Skip tips); Settings > Replay tips again",
		kind = "scenario",
		when = function(sit) return COACH_WHEN(sit) and sit.session ~= "first" end,
		check = function(ctx) neverAgain(ctx, "next") end,
	}

	Hunt.promise{
		id = "coachsteps.closing_is_not_skipping",
		area = "Coach marks",
		text = "Closing Wuber half way through the first-open tips does not end them: you only skip them with Skip tips or Got it, so they are there when you open it again.",
		source = "Coach.lua (a closed window is hidden for now, never done: only Got it / Skip tips finish; review #22)",
		kind = "scenario",
		when = COACH_WHEN,
		check = function(ctx)
			local b = coachSetup(ctx)
			ctx.me:clickOn(b.next)
			ctx:advance(0.6)
			ctx:note("click Next")
			ctx.me:pressEscape()
			ctx:advance(1)
			ctx:note("press Escape (close Wuber)")
			if shown(ctx) then ctx:na("Escape did not close the phone") end
			if ctx.W.db.coach == true then ctx:fail("You close Wuber in the middle of the first-open tips and Wuber counts them as finished.") end
			ctx.W.UI.Toggle(true)
			ctx:note("open Wuber again")
			local b2
			waitFor(ctx, function() b2 = coachCard(ctx) return b2 ~= nil end, 8, 0.5)
			if not b2 then ctx:fail("You close Wuber in the middle of the first-open tips and when you open it again there are no tips.", onScreen(ctx)) end
		end,
	}

	---------------------------------------------------------------------------------------------------------------
	-- The minimap button
	---------------------------------------------------------------------------------------------------------------
	local function mmButton(ctx)
		local b = ctx.me.env.WuberMinimapButton
		if not b then ctx:cannot("no minimap button in this game") end
		return b
	end

	local MM_WHEN = function(sit) return is(sit, "combat", "no") and sit.minimapHidden ~= "on" and is(sit, "phone", { closed = true }) end

	Hunt.promise{
		id = "minimap.right_click_driver_console",
		area = "Minimap button",
		text = "Right-clicking the Wuber button by the minimap opens your driver console, or tells you driving is not available here.",
		source = "tooltip (Right-click: your driver console.)",
		kind = "scenario",
		when = MM_WHEN,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local b = mmButton(ctx)
			if not ctx:visible(b) then ctx:na("the minimap button is not on screen") end
			ctx.me:clickOn(b, "RightButton")
			ctx:advance(1)
			ctx:note("right-click the minimap button")
			local toast = visibleText(ctx, "Driving isn't available")
			if toast then return end
			if not shown(ctx) then ctx:fail("You right-click the Wuber button by the minimap and nothing happens.", onScreen(ctx)) end
			if ui(ctx).tab ~= "Drive" then
				ctx:fail("You right-click the Wuber button by the minimap (it says: your driver console) and Wuber opens on the " .. tostring(ui(ctx).tab) .. " tab.", onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "minimap.shift_right_click_pauses",
		area = "Minimap button",
		text = "While you are open as a driver, Shift-right-clicking the Wuber button by the minimap pauses your driving, and doing it again resumes it, each with a note saying so.",
		source = "tooltip (Shift-right-click: pause or resume driving.); Minimap.lua toasts 'Paused: no new invites' / 'Resumed: inviting riders again'",
		kind = "scenario",
		needs = { role = "warlock" },
		when = function(sit) return MM_WHEN(sit) and is(sit, "ride", "none") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local DR = ctx.W.Drive
			if not (DR and type(DR.IsOpen) == "function" and DR.IsOpen()) then ctx:na("not open as a driver") end
			if DR.IsPaused() then ctx:na("already paused") end
			local b = mmButton(ctx)
			if not ctx:visible(b) then ctx:na("the minimap button is not on screen") end
			ctx.me.mods.shift = true
			local okc, err = pcall(ctx.me.clickOn, ctx.me, b, "RightButton")
			ctx.me.mods.shift = false
			if not okc then ctx:cannot("the click failed: " .. tostring(err)) end
			ctx:advance(0.8)
			ctx:note("Shift-right-click the minimap button")
			if not DR.IsPaused() then
				ctx:fail("You are open as a driver, Shift-right-click the Wuber button by the minimap (it says: pause or resume driving) and you are not paused.", onScreen(ctx))
			end
			if not visibleText(ctx, "Paused") then ctx:fail("You Shift-right-click the Wuber button to pause and no note says you are paused.", onScreen(ctx)) end
			ctx:advance(5)
			ctx.me.mods.shift = true
			okc, err = pcall(ctx.me.clickOn, ctx.me, b, "RightButton")
			ctx.me.mods.shift = false
			ctx:advance(0.8)
			ctx:note("Shift-right-click the minimap button again")
			if DR.IsPaused() then ctx:fail("You are paused, Shift-right-click the Wuber button by the minimap again (pause or resume) and you are still paused.", onScreen(ctx)) end
		end,
	}

	Hunt.promise{
		id = "minimap.drag_is_remembered",
		area = "Minimap button",
		text = "You can drag the Wuber button round the minimap's edge, and it is still where you left it after a /reload.",
		source = "tooltip (Drag: move.)",
		kind = "scenario",
		when = function(sit) return MM_WHEN(sit) and sit.session ~= "first" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local b = mmButton(ctx)
			local env = ctx.me.env
			local MM = env.Minimap
			if not ctx:visible(b) then ctx:na("the minimap button is not on screen") end
			local mx, my = MM:GetCenter()
			local scale = MM:GetEffectiveScale()
			-- the mouse is taken to the left of the minimap's centre, and the button follows
			ctx.me.cursorX, ctx.me.cursorY = (mx - 60) * scale, my * scale
			local ds, dp = b:GetScript("OnDragStart"), b:GetScript("OnDragStop")
			if not (ds and dp) then ctx:cannot("the button is not draggable") end
			ds(b, "LeftButton")
			ctx:advance(0.3)
			dp(b)
			ctx:note("drag the minimap button to the left of the minimap")
			local bx = b:GetCenter()
			if not (bx and bx < mx - 20) then ctx:fail("You drag the Wuber button to the left side of the minimap and it does not follow the mouse.", ("button x %s, minimap x %s"):format(tostring(bx), tostring(mx))) end
			ctx:reload()
			ctx:advance(2)
			ctx:note("/reload")
			local b2 = ctx.me.env.WuberMinimapButton
			local MM2 = ctx.me.env.Minimap
			local mx2 = MM2:GetCenter()
			local bx2 = b2 and b2:GetCenter()
			if not (bx2 and bx2 < mx2 - 20) then ctx:fail("You drag the Wuber button to the left side of the minimap, /reload, and it is back where it was.", ("button x %s, minimap x %s"):format(tostring(bx2), tostring(mx2))) end
		end,
	}

	Hunt.promise{
		id = "minimap.visible_follows_switch",
		area = "Minimap button",
		text = "The Wuber button by the minimap is there unless you turned the Minimap button switch off, and it is still hidden or shown that way after a /reload or a new login.",
		source = "Settings > Map > Minimap button (\"Shows the Wuber button by the minimap\"); /wuber minimap",
		kind = "always",
		check = function(ctx)
			local b = ctx.me.env.WuberMinimapButton
			if not b then return end
			local db = ctx.W.db
			if type(db) ~= "table" then return end
			local hidden = db.minimapHidden == true
			local up = ctx:visible(b)
			if hidden and up then ctx:fail("The Minimap button switch is off and the Wuber button is still by the minimap.") end
			if not hidden and not up then ctx:fail("The Minimap button switch is on and there is no Wuber button by the minimap.") end
		end,
	}


	---------------------------------------------------------------------------------------------------------------
	-- "A newer Wuber is out"
	---------------------------------------------------------------------------------------------------------------
	local FOUNDER = "Anita Lift"
	local NOTE_PAT = "is out%. Get it on CurseForge"

	-- a released build (a plain number: the dev build the author tests with is silent by design)
	local function released(ctx) ctx.clientOpts.version = "2.3.0" end

	local UPD_WHEN = function(sit)
		return sit.session ~= "first" and is(sit, "combat", "no") and is(sit, "ride", "none") and is(sit, "role", "rider")
	end

	-- another player's Wuber, on the network, says its version (what a driver's beacon carries)
	local function heard(ctx, from, ver)
		ctx.w:inject(from, "D~1~Ratchet~1413~500~500~5000~~open~1~0~~" .. ver, "CHANNEL")
		ctx:note(from .. "'s Wuber says it is version " .. ver)
		ctx:advance(0.5)
	end

	local function noteUp(ctx) return visibleText(ctx, NOTE_PAT) end

	-- waits for the note; true when it showed
	local function waitNote(ctx, secs) return waitFor(ctx, function() return noteUp(ctx) ~= nil end, secs, 0.5) end

	local function settled(ctx, secs)
		-- the build may have left a toast up: let it go before the check starts
		ctx:advance(secs or 12)
	end

	Hunt.promise{
		id = "update.founders_word_shows_note",
		area = "Update note",
		text = "When the founder's Wuber says a newer version is out, a quiet note tells you so, with where to get it, within a minute or so of you being idle.",
		source = "BRIEF11 (the founder's word is enough); Settings > This window > Tell me about updates",
		kind = "scenario",
		pre = released,
		when = function(sit) return UPD_WHEN(sit) and sit.updateNotes ~= "off" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			if ctx.W.OnFounderRuleset and not ctx.W.OnFounderRuleset() then ctx:na("not on the founders' ruleset") end
			if ctx.W.VERSION ~= "2.3.0" then ctx:cannot("could not give the window a released version number") end
			settled(ctx)
			heard(ctx, FOUNDER, "2.3.1")
			if not waitNote(ctx, 60) then
				ctx:fail("The founder's Wuber says version 2.3.1 is out, you are idle and have the update note on, and a minute later no note has told you.", onScreen(ctx))
			end
			if not visibleText(ctx, "2%.3%.1") then ctx:fail("The update note does not name the new version.", tostring(noteUp(ctx))) end
		end,
	}

	Hunt.promise{
		id = "update.one_stranger_is_not_enough",
		area = "Update note",
		text = "One ordinary player saying a newer Wuber is out does not make a note, but two different players saying it do.",
		source = "BRIEF11; Settings > Tell me about updates tooltip (\"the founder's word, or two players'\")",
		kind = "scenario",
		pre = released,
		when = function(sit) return UPD_WHEN(sit) and sit.updateNotes ~= "off" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			if ctx.W.VERSION ~= "2.3.0" then ctx:cannot("could not give the window a released version number") end
			settled(ctx)
			heard(ctx, "Bea Jones", "2.3.1")
			if waitNote(ctx, 40) then ctx:fail("One ordinary player says a newer Wuber is out and you are already told.", tostring(noteUp(ctx))) end
			heard(ctx, "Cal Brown", "2.3.1")
			if not waitNote(ctx, 60) then
				ctx:fail("Two different players say version 2.3.1 is out, you are idle with the note on, and a minute later no note has told you.", onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "update.switch_off_is_silent",
		area = "Update note",
		text = "With Tell me about updates switched off you are never told a newer Wuber is out, even when the founder says so.",
		source = "Settings > This window > Tell me about updates",
		kind = "scenario",
		pre = released,
		needs = { updateNotes = "off" },
		when = UPD_WHEN,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			if ctx.W.VERSION ~= "2.3.0" then ctx:cannot("could not give the window a released version number") end
			if ctx.W.db.updateNotes ~= false then ctx:na("the switch is not off") end
			settled(ctx)
			heard(ctx, FOUNDER, "2.3.1")
			if waitNote(ctx, 60) then ctx:fail("You switched Tell me about updates off and the founder says a newer Wuber is out: a note tells you anyway.", tostring(noteUp(ctx))) end
		end,
	}


	Hunt.promise{
		id = "update.waits_for_the_fight",
		area = "Update note",
		text = "The newer-version note never comes in the middle of a fight: it waits, and then comes once the fight is over.",
		source = "Net.Update header (shows one quiet toast once the player is idle: not in combat, not on a ride)",
		kind = "scenario",
		pre = released,
		when = function(sit) return sit.session ~= "first" and is(sit, "role", "rider") and is(sit, "ride", "none") and sit.updateNotes ~= "off" and is(sit, "combat", "no") end,
		check = function(ctx)
			if ctx.W.VERSION ~= "2.3.0" then ctx:cannot("could not give the window a released version number") end
			settled(ctx)
			ctx.w:enterCombat(ctx.me)
			ctx:note("a foe attacks: combat starts")
			heard(ctx, FOUNDER, "2.3.1")
			-- r51 (HUNT F005): off the founders' ruleset one player's word is not trusted (Net/Update.lua NEED = 2),
			-- so a second player is heard too; on the founders' realm the founder alone was already enough.
			heard(ctx, "Bea Jones", "2.3.1")
			if waitNote(ctx, 40) then ctx:fail("You are in a fight and the note that a newer Wuber is out pops up in the middle of it.", tostring(noteUp(ctx))) end
			ctx.w:leaveCombat(ctx.me)
			ctx:note("the fight ends")
			if not waitNote(ctx, 60) then
				ctx:fail("A newer Wuber was announced during a fight; the fight is over for a minute and you were never told.", onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "update.once_a_session",
		area = "Update note",
		text = "The newer-version note comes once in a session, however many players say it afterwards, and once more the next time you log in.",
		source = "Net.Update header (one quiet toast per session); BRIEF11",
		kind = "scenario",
		pre = released,
		when = function(sit) return UPD_WHEN(sit) and sit.updateNotes ~= "off" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			if ctx.W.VERSION ~= "2.3.0" then ctx:cannot("could not give the window a released version number") end
			settled(ctx)
			heard(ctx, FOUNDER, "2.3.1")
			if not waitNote(ctx, 60) then ctx:na("the note did not come (another promise says so)") end
			ctx:advance(15)
			heard(ctx, FOUNDER, "2.3.1")
			heard(ctx, "Bea Jones", "2.3.1")
			heard(ctx, "Cal Brown", "2.3.1")
			if waitNote(ctx, 90) then ctx:fail("The note that a newer Wuber is out has shown, and it comes up again in the same session.", tostring(noteUp(ctx))) end
			ctx:relog()
			ctx:note("log out and in again, still on the old version")
			settled(ctx, 3)
			if not waitNote(ctx, 90) then
				ctx:fail("You still have the old Wuber after logging in again and no note tells you a newer one is out.", onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "update.click_shows_the_address",
		area = "Update note",
		text = "Clicking the newer-version note opens Settings where the CurseForge address is, and where you can turn the note off.",
		source = "Net.Update (tip: Click to see where to get it (Settings, This window), where you can also turn this off.)",
		kind = "scenario",
		pre = released,
		when = function(sit) return UPD_WHEN(sit) and sit.updateNotes ~= "off" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			if ctx.W.VERSION ~= "2.3.0" then ctx:cannot("could not give the window a released version number") end
			settled(ctx)
			heard(ctx, FOUNDER, "2.3.1")
			if not waitNote(ctx, 60) then ctx:na("the note did not come (another promise says so)") end
			local fs = ctx.me:findText(NOTE_PAT)
			if #fs == 0 then ctx:cannot("the note's text is not findable") end
			ctx.me:clickOn(fs[1])
			ctx:advance(2)
			ctx:note("click the note")
			if not shown(ctx) or not ui(ctx).settingsOpen then
				ctx:fail("You click the note that says a newer Wuber is out and Settings does not open.", onScreen(ctx))
			end
			local addr = false
			for _, t in ipairs(ctx.me:findText("curseforge", true, true)) do addr = true end
			if not addr then
				for _, t in ipairs(ctx:texts()) do if t:find("curseforge", 1, true) then addr = true end end
			end
			if not addr then ctx:fail("You click the note that says a newer Wuber is out and the Settings page that opens shows no CurseForge address.", onScreen(ctx)) end
		end,
	}


	---------------------------------------------------------------------------------------------------------------
	-- The toast queue
	---------------------------------------------------------------------------------------------------------------
	local function toastTexts(ctx, pat)
		local n = 0
		for _, t in ipairs(ctx:texts()) do if t:find(pat, 1, true) then n = n + 1 end end
		return n
	end

	local TOAST_WHEN = function(sit) return is(sit, "combat", "no") end


	Hunt.promise{
		id = "toastq.goes_by_itself",
		area = "Toasts",
		text = "A pop-up note goes by itself within about ten seconds, whatever kind it is, and leaves nothing behind.",
		source = "Toasts.lua (each kind stays 4 to 10 seconds)",
		kind = "scenario",
		when = TOAST_WHEN,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local UI = ctx.W.UI
			ctx:advance(10)
			for _, kind in ipairs({ "info", "found", "fav", "watch", "warn", "error", "portal", "advert", "nonpayer", "away", "offer", "raincheck", "update" }) do
				local text = "Zed note of kind " .. kind
				UI.Toast(text, kind)
				ctx:advance(0.5)
				if toastTexts(ctx, text) == 0 then ctx:fail(("A note of kind %s is sent and it never shows."):format(kind), onScreen(ctx)) end
				ctx:advance(11.5)
				if toastTexts(ctx, text) > 0 then ctx:fail(("A note of kind %s is still on screen 12 seconds after it came."):format(kind), onScreen(ctx)) end
				if UI.ToastShowing() then ctx:fail(("A note of kind %s is gone from the screen and Wuber still counts a note as showing."):format(kind)) end
			end
		end,
	}


	Hunt.promise{
		id = "toastq.click_opens_wuber",
		area = "Toasts",
		text = "Clicking a pop-up note takes it off the screen and opens Wuber (its tooltip says: Click to open Wuber).",
		source = "Toasts.lua tooltip (Click to open Wuber.)",
		kind = "scenario",
		needs = { phone = "closed" },
		when = TOAST_WHEN,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			if shown(ctx) then ctx:na("Wuber is already open") end
			local UI = ctx.W.UI
			ctx:advance(10)
			UI.Toast("Zed says hello.", "info")
			ctx:advance(0.6)
			local fs = ctx.me:findText("Zed says hello.", false, true)
			if #fs == 0 then ctx:fail("A note arrives and it is not on screen.", onScreen(ctx)) end
			ctx.me:clickOn(fs[1])
			ctx:advance(1)
			ctx:note("click the note")
			if toastTexts(ctx, "Zed says hello.") > 0 then ctx:fail("You click a note and it stays on screen.", onScreen(ctx)) end
			if not shown(ctx) then ctx:fail("You click a note (its tooltip says: Click to open Wuber) and Wuber does not open.", onScreen(ctx)) end
		end,
	}

	Hunt.promise{
		id = "toastq.update_note_never_pushes_another_off",
		area = "Toasts",
		text = "The newer-version note waits for another note to finish: it never takes the place of a note you are reading.",
		source = "Net.Update header (shows once the player is idle: no other toast is on screen)",
		kind = "scenario",
		pre = released,
		when = function(sit) return UPD_WHEN(sit) and sit.updateNotes ~= "off" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			if ctx.W.VERSION ~= "2.3.0" then ctx:cannot("could not give the window a released version number") end
			settled(ctx)
			ctx.W.UI.Toast("Zed has not paid before.", "nonpayer")
			ctx:note("a ten-second warning note comes up")
			heard(ctx, FOUNDER, "2.3.1")
			for i = 1, 16 do
				ctx:advance(0.5)
				if i <= 17 and noteUp(ctx) and toastTexts(ctx, "Zed has not paid") == 0 and i < 18 then
					ctx:fail("A ten-second warning note is on screen and the newer-version note takes its place after " .. (i * 0.5) .. " seconds.", onScreen(ctx))
				end
			end
		end,
	}


	---------------------------------------------------------------------------------------------------------------
	-- The share pills
	---------------------------------------------------------------------------------------------------------------
	local function sharePill(ctx)
		local S = ctx.W.UI and ctx.W.UI.Share
		if not (S and type(S.Target) == "function") then ctx:cannot("this Wuber has no share pills") end
		return S, S.Target()
	end

	-- every public line (party, raid, say, channel) I sent, from the fake game's record
	local function myLines(ctx)
		local n = 0
		for _, p in ipairs(ctx.w.chatPosts or {}) do
			if key(p.from) == key(ctx.name) then n = n + 1 end
		end
		return n
	end

	local SHARE_WHEN = function(sit) return is(sit, "combat", "no") and is(sit, "role", "rider") and is(sit, "ride", { arrived = true, paid = true }) and is(sit, "phone", { home = true, closed = true, splash = true }) end

	local function arrivedSetup(ctx)
		if inCombat(ctx) then ctx:na("in combat") end
		openPhone(ctx)
		ctx:advance(3)
		local S, pill = sharePill(ctx)
		if not (pill and ctx:visible(pill)) then
			ctx:na("no share pill is up on this page (nothing to share, or not in a group)")
		end
		return S, pill
	end

	Hunt.promise{
		id = "sharepill.click_posts_one_line_to_party",
		area = "Share pills",
		text = "Clicking the Share pill after your summon puts one line in your party's chat, says so, and the pill goes: it is for once.",
		source = "Share.lua header (posts it to party/raid on the player's click; flex once per ride); toast 'Shared with your party'",
		kind = "scenario",
		when = SHARE_WHEN,
		check = function(ctx)
			local S, pill = arrivedSetup(ctx)
			local before = myLines(ctx)
			ctx.me:clickOn(pill)
			ctx:advance(1)
			ctx:note("click the Share pill")
			local n = myLines(ctx) - before
			if n == 0 then ctx:fail("You click Share on the arrived screen, in a party, and no line goes out in party chat.", onScreen(ctx)) end
			if n > 1 then ctx:fail(("You click Share once and %d lines go out in chat."):format(n)) end
			if not visibleText(ctx, "Shared with your") then ctx:fail("You click Share and nothing says the line went out.", onScreen(ctx)) end
			local last = ctx.w.chatPosts[#ctx.w.chatPosts]
			if last and last.kind ~= "PARTY" and last.kind ~= "RAID" then
				ctx:fail("You click Share in a party and the line goes to " .. tostring(last.kind) .. " chat, not your party.", tostring(last.text))
			end
			local S2, pill2 = sharePill(ctx)
			if pill2 and ctx:visible(pill2) then ctx:fail("You have shared once and the Share pill is still there for another go.", onScreen(ctx)) end
		end,
	}


	Hunt.promise{
		id = "sharepill.line_tells_the_truth",
		area = "Share pills",
		text = "The line the Share pill would post names the place you really went and the driver who really took you, and never says 'gold' or carries a link.",
		source = "Share.lua header (the checks: one line, at most 240 characters, no links, never the word gold); the Ride screen",
		kind = "scenario",
		when = SHARE_WHEN,
		check = function(ctx)
			local S, pill = arrivedSetup(ctx)
			local macro, line = S.Macro(pill)
			if not line then ctx:na("no line to share now") end
			local r = ctx.W.ride or {}
			local dest, drv = tostring(r.dest or ""), tostring(r.driverName or r.driver or "")
			if dest ~= "" and not line:find(dest, 1, true) then ctx:fail("The Share pill's line does not name the place you went to (" .. dest .. ").", line) end
			local short = ctx.W.Short and ctx.W.Short(drv) or drv
			if drv ~= "" and not (line:find(short, 1, true) or line:find(drv, 1, true)) then
				ctx:fail("The Share pill's line does not name the driver who took you (" .. short .. ").", line)
			end
			local low = line:lower()
			if low:find("%f[%a]gold%f[%A]") or low:find("http", 1, true) or low:find("www.", 1, true) then ctx:fail("The Share pill's line says gold or carries a link.", line) end
			if #line > 240 or line:find("[\r\n|]") then ctx:fail("The Share pill's line is not one short plain line.", line) end
		end,
	}

	Hunt.promise{
		id = "sharepill.gone_when_alone",
		area = "Share pills",
		text = "When you leave the group, the Share pill goes: there is nobody to share with.",
		source = "Share.lua header (hidden when not in a group)",
		kind = "scenario",
		when = SHARE_WHEN,
		check = function(ctx)
			local S, pill = arrivedSetup(ctx)
			local env = ctx.me.env
			local leave = (env.C_PartyInfo and env.C_PartyInfo.LeaveParty) or env.LeaveParty
			if not leave then ctx:cannot("no way to leave the group") end
			leave()
			ctx:note("leave the group")
			ctx:advance(3)
			local _, pill2 = sharePill(ctx)
			if pill2 and ctx:visible(pill2) then ctx:fail("You have left the group and the Share pill is still there.", onScreen(ctx)) end
			for _, t in ipairs(ctx:texts()) do
				if t == "Share" or t == "Share after combat" then ctx:fail("You have left the group and a Share pill is still on screen.", onScreen(ctx)) end
			end
		end,
	}

	Hunt.promise{
		id = "sharepill.combat_posts_nothing",
		area = "Share pills",
		text = "In a fight the Share pill waits (it says Share after combat) and clicking it posts nothing.",
		source = "Share.lua header ('Share after combat' dimmed in combat; out of combat only)",
		kind = "scenario",
		when = function(sit) return is(sit, "role", "rider") and is(sit, "ride", { arrived = true, paid = true }) and is(sit, "phone", { home = true, closed = true, splash = true }) and is(sit, "combat", "no") end,
		check = function(ctx)
			local S, pill = arrivedSetup(ctx)
			ctx.w:enterCombat(ctx.me)
			ctx:note("a foe attacks: combat starts")
			ctx:advance(2)
			local before = myLines(ctx)
			local pills = {}
			for _, t in ipairs(ctx.me:findText("^Share", false)) do pills[#pills + 1] = t end
			local words = visibleText(ctx, "^Share")
			if not words then ctx:na("the pill is not on screen in combat") end
			if not words:find("after combat", 1, true) then ctx:fail("You are in a fight and the Share pill still says " .. words .. " instead of waiting.", onScreen(ctx)) end
			pcall(ctx.me.clickOn, ctx.me, pills[1])
			ctx:advance(1)
			ctx:note("click the Share pill in combat")
			if myLines(ctx) ~= before then ctx:fail("You click the Share pill in a fight and a line goes out in chat.") end
		end,
	}


	---------------------------------------------------------------------------------------------------------------
	-- Founders and Pioneers
	---------------------------------------------------------------------------------------------------------------
	local OTHER_REALM = "CAMWOW US2 Realm 1 PvP"

	-- a driver of the given name opens a shop; the rider's list hears him
	local function addDriver(ctx, name, price)
		if ctx.w:player(name) then ctx:cannot("the name " .. name .. " is taken") end
		local d = ctx.w:addClient(name, { spot = "Ratchet", class = "WARLOCK", shards = 10, money = 100000, realm = ctx.me.realm })
		local Ch = d.W.Char()
		if Ch then Ch.welcomed = true Ch.wizard = true Ch.price = price or 5000 end
		if d.W.Driver.SetOnline(true) == false then ctx:cannot(name .. " could not go online") end
		ctx:note(name .. " goes online")
		if not waitFor(ctx, function() return ctx.W.drivers and ctx.W.drivers[key(name)] end, 25, 1) then
			ctx:cannot(name .. "'s beacon never reached the rider")
		end
		return d
	end

	local function foundersChips(ctx)
		local n = 0
		for _, t in ipairs(ctx:texts()) do if t == "Founder" then n = n + 1 end end
		return n
	end

	local FOUNDER_WHEN = function(sit) return is(sit, "role", "rider") and is(sit, "ride", "none") and is(sit, "phone", { home = true }) and is(sit, "combat", "no") end

	Hunt.promise{
		id = "founder.card_chip_for_a_founder",
		area = "Founders",
		text = "On the founders' own ruleset a driver who is one of the founders has the gold Founder chip on his card in your list, and an ordinary driver has none.",
		source = "Kit.lua / Cards.lua (the founder's card: crown, Founder chip); BRIEF2 founders' look",
		kind = "scenario",
		when = FOUNDER_WHEN,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			if ctx.W.OnFounderRuleset and not ctx.W.OnFounderRuleset() then ctx:na("not on the founders' ruleset") end
			addDriver(ctx, "Zed Hale")
			ctx:advance(2)
			if foundersChips(ctx) > 0 then ctx:fail("An ordinary driver (Zed Hale) has the gold Founder chip on his card.", onScreen(ctx)) end
			addDriver(ctx, FOUNDER)
			ctx:advance(3)
			if foundersChips(ctx) == 0 then
				ctx:fail("Anita Lift, one of the founders, is open as a driver on the founders' ruleset and her card in your list has no Founder chip.", onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "founder.no_chip_on_another_ruleset",
		area = "Founders",
		text = "On any other ruleset, a driver who happens to have a founder's name gets no Founder chip: the name alone proves nothing.",
		source = "Base.lua (founder status is locked to the founders' ruleset); CLAUDE.md",
		kind = "scenario",
		pre = function(ctx) ctx.clientOpts.realm = OTHER_REALM end,
		when = function(sit) return FOUNDER_WHEN(sit) end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			if ctx.W.OnFounderRuleset and ctx.W.OnFounderRuleset() then ctx:cannot("could not put the player on another ruleset") end
			addDriver(ctx, FOUNDER)
			ctx:advance(3)
			if foundersChips(ctx) > 0 then
				ctx:fail("You play on a PvP realm of another region and a driver called Anita Lift has the gold Founder chip on her card.", onScreen(ctx))
			end
		end,
	}


	Hunt.promise{
		id = "founder.pioneers_dormant_when_empty",
		area = "Founders",
		text = "While nobody is named a Pioneer, no Pioneer words, emblems switches or thank-you credits show in Wuber's Settings.",
		source = "Base.lua (empty lists: nothing shows anywhere); Settings > Map (Pioneer switches only when a Pioneer list names someone)",
		kind = "scenario",
		when = function(sit) return is(sit, "combat", "no") and sit.session ~= "first" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local P = ctx.W.PIONEERS
			for _, list in pairs(P or {}) do
				for _, names in pairs(list) do if type(names) == "table" and names[1] ~= nil then ctx:na("a Pioneer list names someone in this build") end end
			end
			local U = ctx.W.UI
			if type(U.OpenSettings) ~= "function" then ctx:cannot("no Settings") end
			for _, section in ipairs({ "riding", "map", "sound", "window" }) do
				if (type(U.HelpShown) == "function" and U.HelpShown()) or ui(ctx).settingsOpen then
					if type(U.CloseSettings) == "function" then U.CloseSettings() end
					if type(U.HelpShown) == "function" and U.HelpShown() and type(U.CloseHelp) == "function" then U.CloseHelp(true) end
					ctx:advance(0.8)
				end
				U.OpenSettings(section)
				ctx:advance(1)
				ctx:note("open the " .. section .. " page of Settings")
				for _, t in ipairs(ctx:texts()) do
					if t:lower():find("pioneer", 1, true) or t:find("Thanks to our first", 1, true) then
						ctx:fail("No player is named a Pioneer and Settings (" .. section .. ") talks about Pioneers: " .. t, onScreen(ctx))
					end
				end
			end
		end,
	}


	---------------------------------------------------------------------------------------------------------------
	-- The Help page: How Wuber finds drivers
	---------------------------------------------------------------------------------------------------------------
	local HELP_TITLE = "How Wuber finds drivers"

	local function helpUp(ctx)
		local U = ctx.W.UI
		return type(U.HelpShown) == "function" and U.HelpShown() == true and visibleText(ctx, HELP_TITLE) ~= nil
	end

	local function dismissTip(ctx)
		local Tips = ctx:mod("UI.Tips")
		if Tips and type(Tips.Card) == "function" then
			local ok, c = pcall(Tips.Card)
			if ok and type(c) == "table" and ctx:visible(c) then
				pcall(Tips.Hide)
				ctx:advance(0.5)
				ctx:note("the tip card is tapped away")
			end
		end
	end

	local HELP_WHEN = function(sit) return is(sit, "combat", "no") and is(sit, "phone", { home = true }) and sit.session ~= "first" end

	Hunt.promise{
		id = "help.signal_bars_open_it",
		area = "Help",
		text = "Tapping the signal bars at the top of the phone opens How Wuber finds drivers (its tooltip says: Few drivers? Tap to see how Wuber finds them).",
		source = "tooltip (Network: Few drivers? Tap to see how Wuber finds them); Phone.lua",
		kind = "scenario",
		when = HELP_WHEN,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local ph = ui(ctx).phone
			local bars = ph and ph.signal
			if not (bars and ctx:visible(bars)) then ctx:cannot("the signal bars are not on screen") end
			ctx.me:clickOn(bars)
			ctx:advance(1)
			ctx:note("tap the signal bars")
			if not helpUp(ctx) then ctx:fail("You tap the signal bars at the top of the phone (Few drivers? Tap to see how Wuber finds them) and the help page does not open.", onScreen(ctx)) end
		end,
	}

	Hunt.promise{
		id = "help.why_cant_i_see_anyone",
		area = "Help",
		text = "With nobody online, Home's Why? link opens How Wuber finds drivers.",
		source = "Home empty state (f.why.label: \"Why?\"; opens How Wuber finds drivers)",
		kind = "scenario",
		needs = { net = "none", role = "rider" },
		when = function(sit) return HELP_WHEN(sit) and is(sit, "coach", "done") end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			ctx:advance(70)
			dismissTip(ctx)
			ctx:advance(1.5)
			local fs = ctx.me:findText("^Why%?$", false, false)
			if #fs == 0 then ctx:fail("Nobody is online and Home has no Why? link.", onScreen(ctx)) end
			ctx.me:clickOn(fs[1])
			ctx:advance(1)
			ctx:note("tap Why?")
			if not helpUp(ctx) then ctx:fail("You tap Why? on Home and the help page does not open.", onScreen(ctx)) end
		end,
	}

	Hunt.promise{
		id = "help.back_returns",
		area = "Help",
		text = "The Back arrow on the help page takes you back to where you were: Home if you came from Home, Settings if you came from Settings.",
		source = "Settings.Panel (UI.CloseHelp: Back to where you were.)",
		kind = "scenario",
		when = HELP_WHEN,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local U = ctx.W.UI
			local ph = ui(ctx).phone
			local bars = ph and ph.signal
			if not (bars and ctx:visible(bars)) then ctx:cannot("the signal bars are not on screen") end
			local tab0 = ui(ctx).tab -- the tab the situation opened (Drive for a driver in a ride, else Ride): Back returns to it
			ctx.me:clickOn(bars)
			ctx:advance(1)
			if not helpUp(ctx) then ctx:cannot("the help page did not open") end
			local back = U.settings and U.settings.help and U.settings.help.back
			if not (back and ctx:visible(back)) then ctx:fail("The help page has no Back arrow on screen.", onScreen(ctx)) end
			ctx.me:clickOn(back)
			ctx:advance(1)
			ctx:note("tap Back on the help page")
			if helpUp(ctx) then ctx:fail("You tap Back on the help page and it stays.", onScreen(ctx)) end
			if ui(ctx).settingsOpen then ctx:fail("You opened the help page from the signal bars on Home, tap Back, and land in Settings instead of Home.", onScreen(ctx)) end
			if ui(ctx).tab ~= tab0 then ctx:fail("You opened the help page from the " .. tostring(tab0) .. " tab, tap Back, and you are on the " .. tostring(ui(ctx).tab) .. " tab.", onScreen(ctx)) end
		end,
	}

	Hunt.promise{
		id = "help.ping_finds_a_missed_driver",
		area = "Help",
		text = "If a driver was missed, tapping Ping drivers (as the help page says) makes him answer and he shows in your list.",
		source = "Help: If you see nobody: Tap Ping drivers; tooltip (Ping drivers: Ask every driver online to check in now, in case one was missed.)",
		kind = "scenario",
		needs = { net = "none", role = "rider" },
		when = function(sit) return HELP_WHEN(sit) end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local name = "Zed Hale"
			if ctx.w:player(name) then ctx:cannot("the name is taken") end
			local d = ctx.w:addClient(name, { spot = "Ratchet", class = "WARLOCK", shards = 10, money = 100000 })
			local Ch = d.W.Char()
			if Ch then Ch.welcomed = true Ch.wizard = true Ch.price = 5000 end
			-- his first announcement is lost on the way (the game drops it)
			local send, dropping = ctx.w.sendAddon, true
			ctx.w.sendAddon = function(self, client, ...)
				if dropping and client == d then return 0 end
				return send(self, client, ...)
			end
			if d.W.Driver.SetOnline(true) == false then dropping = false ctx.w.sendAddon = send ctx:cannot("he could not go online") end
			ctx:note(name .. " goes online, but his announcement is lost")
			ctx:advance(20)
			dropping = false
			ctx.w.sendAddon = send
			if ctx.W.drivers and ctx.W.drivers[key(name)] then ctx:na("his announcement still reached the rider") end
			ctx:advance(30)
			dismissTip(ctx)
			ctx:advance(1.5)
			local fs = ctx.me:findText("Ping drivers", false, true)
			if #fs == 0 then ctx:cannot("no Ping drivers button on screen") end
			ctx.me:clickOn(fs[1])
			ctx:advance(1)
			ctx:note("tap Ping drivers")
			local ok = waitFor(ctx, function() return ctx.W.drivers and ctx.W.drivers[key(name)] end, 20, 1)
			if not ok then
				ctx:fail("A driver is open but you cannot see him; you tap Ping drivers (as Help says) and 20 seconds later he is still not in your list.", onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "help.empty_help_not_hidden_by_tip",
		area = "Help",
		text = "With nobody online, the first-open tip card does not hide what to do about it: No drivers online, Ping drivers and Why? stay on Home.",
		source = "Help: If you see nobody (tap Ping drivers); Home empty state (Why?); inferred",
		kind = "scenario",
		needs = { net = "none", role = "rider" },
		when = function(sit) return HELP_WHEN(sit) and is(sit, "coach", "done") and sit.tipsOn ~= "off" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			ctx:advance(10)
			local Tips = ctx:mod("UI.Tips")
			local ok, c = pcall(Tips and Tips.Card or function() end)
			if not (ok and type(c) == "table" and ctx:visible(c)) then ctx:na("no tip card is up") end
			-- deliberate (Home.lua: the tip card holds the foot of the page): the empty state is judged once the tip is closed
			if type(Tips.Hide) ~= "function" then ctx:cannot("no way to close the tip card") end
			Tips.Hide()
			ctx:advance(3)
			ctx:note("close the tip card")
			if Tips.Up and Tips.Up() then ctx:cannot("the tip card did not close") end
			local missing = {}
			for _, want in ipairs({ "No drivers online", "Ping drivers", "Why?" }) do
				if not visibleText(ctx, want:gsub("%p", "%%%0")) then missing[#missing + 1] = want end
			end
			if #missing > 0 then
				ctx:fail("Nobody is online and a tip card is up on Home: the page does not say " .. table.concat(missing, ", ") .. " even after you close the tip.", onScreen(ctx))
			end
		end,
	}


	---------------------------------------------------------------------------------------------------------------
	-- Switches, seen from what they control
	---------------------------------------------------------------------------------------------------------------
	local function openSettingsPage(ctx, section)
		local U = ctx.W.UI
		if type(U.OpenSettings) ~= "function" then ctx:cannot("no Settings") end
		closeCardsInTheWay(ctx)
		if (type(U.HelpShown) == "function" and U.HelpShown()) or ui(ctx).settingsOpen then
			if type(U.CloseSettings) == "function" then U.CloseSettings() end
			if type(U.HelpShown) == "function" and U.HelpShown() and type(U.CloseHelp) == "function" then U.CloseHelp(true) end
			ctx:advance(0.8)
		end
		U.OpenSettings(section)
		ctx:advance(1)
		ctx:note("open the " .. section .. " page of Settings")
		return U.settings
	end

	local function clickSwitch(ctx, st, k)
		local c = st and st.controls and st.controls[k]
		if not (c and ctx:visible(c)) then ctx:cannot("the " .. k .. " switch is not on screen") end
		ctx.me:clickOn(c)
		ctx:advance(0.6)
		ctx:note("click the " .. k .. " switch")
		return c
	end

	Hunt.promise{
		id = "switch.minimap_command_both_ways",
		area = "Switches",
		text = "Typing /wuber minimap takes the Wuber button off the minimap and says so, and typing it again puts it back and says so.",
		source = "Settings > Map > Minimap button; /wuber minimap (prints the new state)",
		kind = "scenario",
		when = function(sit) return is(sit, "combat", "no") and sit.session ~= "first" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local b = ctx.me.env.WuberMinimapButton
			if not b then ctx:cannot("no minimap button in this game") end
			local was = ctx:visible(b)
			local n0 = #(ctx.me.chatLines or {})
			ctx.me:slash("/wuber minimap")
			ctx:advance(0.5)
			ctx:note("type /wuber minimap")
			if ctx:visible(b) == was then ctx:fail("You type /wuber minimap and the Wuber button by the minimap stays " .. (was and "there" or "hidden") .. ".") end
			local say = lastChat(ctx, n0, "Minimap button")
			if not say then ctx:fail("You type /wuber minimap and chat does not say what happened.") end
			if say:find(was and ": on" or ": off", 1, true) then
				ctx:fail("You type /wuber minimap, the button " .. (was and "goes" or "comes back") .. " and chat says it is " .. (was and "on" or "off") .. ".", say)
			end
			ctx.me:slash("/wuber minimap")
			ctx:advance(0.5)
			ctx:note("type /wuber minimap again")
			if ctx:visible(b) ~= was then ctx:fail("You type /wuber minimap twice and the button is not back as it was.") end
		end,
	}

	Hunt.promise{
		id = "switch.updates_back_on_brings_the_note",
		area = "Switches",
		text = "If you turned Tell me about updates off and a newer Wuber is announced, switching it back on lets the note come.",
		source = "Net.Update (the setting turned back on: the toast may still come this session)",
		kind = "scenario",
		pre = released,
		needs = { updateNotes = "off" },
		when = function(sit) return UPD_WHEN(sit) and sit.session ~= "first" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			if ctx.W.VERSION ~= "2.3.0" then ctx:cannot("could not give the window a released version number") end
			if ctx.W.db.updateNotes ~= false then ctx:na("the switch is not off") end
			settled(ctx)
			heard(ctx, FOUNDER, "2.3.1")
			ctx:advance(40)
			local st = openSettingsPage(ctx, "window")
			if noteUp(ctx) then ctx:fail("Tell me about updates is off and the note came anyway.", onScreen(ctx)) end
			clickSwitch(ctx, st, "updateNotes")
			if ctx.W.db.updateNotes == false then ctx:cannot("the click did not turn the switch on") end
			if not waitNote(ctx, 60) then
				ctx:fail("A newer Wuber was announced while Tell me about updates was off; you switch it on and a minute later no note comes.", onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "switch.crowns_off_then_on",
		area = "Switches",
		text = "Turning Crowns and badges over heads off and then on again brings the founder's crown back over her head.",
		source = "Settings > Map > Crowns and badges over heads; FX.Nameplates header",
		kind = "scenario",
		when = function(sit) return is(sit, "combat", "no") and sit.session ~= "first" and sit.plates ~= "off" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			if ctx.W.OnFounderRuleset and not ctx.W.OnFounderRuleset() then ctx:na("not on the founders' ruleset") end
			if ctx.W.db.plates == false then ctx:na("Crowns and badges over heads is off") end
			ctx.me.cvars.nameplateShowFriends = "1"
			if not ctx.w:player(FOUNDER) then ctx.w:addBot(FOUNDER, { spot = "Orgrimmar", class = "MAGE" }) end
			ctx.me:showPlate(FOUNDER, { force = true })
			ctx:advance(3)
			local function crowned()
				for _, f in ipairs(ctx.me:onPlate(FOUNDER)) do if f.plateKind == "crown" then return true end end
				return false
			end
			if not crowned() then ctx:na("no crown to start with (another promise says so)") end
			local st = openSettingsPage(ctx, "map")
			clickSwitch(ctx, st, "plates")
			ctx:advance(2)
			if crowned() then ctx:fail("You turn Crowns and badges over heads off and the crown is still over her head.") end
			clickSwitch(ctx, st, "plates")
			ctx:advance(3)
			if not crowned() then
				ctx:fail("You turn Crowns and badges over heads off and on again, with the founder still in view, and her crown does not come back.")
			end
		end,
	}

end
