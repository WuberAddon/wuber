-- Promises about first-run setup (welcome + crew wizard) and the driver screen switcher.
-- Covers Wuber/UI/Driver/Wizard.lua, Build.lua, Screens.lua, State.lua (and Console.lua switcher).
return function(Hunt)
	local function DR(ctx) return ctx.W.Drive end
	local function D(ctx) return ctx.W.Driver end
	local function UI(ctx) return ctx.W.UI end

	local function noCombat(ctx)
		if ctx.me and ctx.me.player and ctx.me.player.combat then ctx:na("in combat") end
	end

	local function hasText(ctx, pat)
		for _, t in ipairs(ctx:texts()) do
			if t:find(pat) then return t end
		end
		return nil
	end

	local function findTabButton(ctx, name)
		local s = UI(ctx) and UI(ctx).state
		for _, tab in ipairs(s and s.tabs or {}) do
			if tab.name == name and tab.button then return tab.button end
		end
		return nil
	end

	local function openDrive(ctx)
		local u = UI(ctx)
		if not u then ctx:cannot("no W.UI") end
		if u.Bug and u.Bug.Shown and u.Bug.Shown() and u.Bug.Close then
			u.Bug.Close()
			ctx:advance(0.5)
		end
		if u.state and u.state.settingsOpen and u.CloseSettings then
			u.CloseSettings()
			ctx:advance(0.4)
		end
		if not (u.IsShown and u.IsShown()) then
			u.Toggle(true)
			ctx:note("open the phone")
			ctx:advance(3)
		else
			ctx:advance(4)
		end
		local drvBtn = findTabButton(ctx, "Drive")
		if drvBtn and ctx:visible(drvBtn) then
			ctx.me:clickOn(drvBtn)
			ctx:note("click the Drive tab")
			ctx:advance(0.8)
		end
		local s = u.state
		if not s or s.tab ~= "Drive" then
			if u.SelectTab then
				u.SelectTab("Drive")
				ctx:advance(0.8)
			end
		end
		if not (D(ctx) and D(ctx).ui) then ctx:cannot("Drive tab did not build") end
		if D(ctx).Mode and D(ctx).Mode() == "provider" then ctx:na("another addon drives") end
	end

	local function ensureBase(ctx)
		local drv = D(ctx)
		if drv.SheetOpen and drv.SheetOpen() then
			ctx.me:pressEscape()
			ctx:advance(0.6)
		end
		if drv.CurrentScreen and drv.CurrentScreen() ~= "console" then
			drv.ShowScreen("console")
			ctx:advance(0.6)
		end
	end

	local function clickObj(ctx, obj, label)
		if not (obj and ctx:visible(obj)) then
			ctx:cannot("target not visible: " .. tostring(label))
		end
		ctx.me:clickOn(obj)
		ctx:note("click " .. tostring(label))
		ctx:advance(0.6)
	end

	local function openWizard(ctx)
		openDrive(ctx)
		ensureBase(ctx)
		local drv = D(ctx)
		local wel = drv.ui and drv.ui.welcome
		if wel and wel:IsShown() and wel.go and ctx:visible(wel.go) then
			clickObj(ctx, wel.go, "Set up driving")
		else
			drv.ShowScreen("wizard")
			ctx:note("open wizard screen")
			ctx:advance(0.6)
		end
		local w = drv.ui and drv.ui.subs and drv.ui.subs.wizard
		if not (w and w.frame and w.frame:IsShown()) then
			ctx:cannot("wizard did not open")
		end
		return w
	end

	local function freshCanWelcome(sit)
		return sit.saved == nil or sit.saved == "fresh"
	end

	-- 1. Non-Warlock first-run welcome
	Hunt.promise{
		id = "b4setup.welcome_non_warlock",
		area = "DriverSetup",
		text = "A non-Warlock who is not set up sees the summoning-service welcome, and clicking 'Just help a friend's summons' keeps them there with a tip toast.",
		source = "Wuber/UI/Driver/State.lua:288-291; Wuber/UI/Driver/Build.lua:759-763,795-798,812-829",
		kind = "scenario",
		needs = { role = "rider" },
		when = freshCanWelcome,
		check = function(ctx)
			noCombat(ctx)
			openDrive(ctx)
			ensureBase(ctx)
			local drv = D(ctx)
			if drv.Mode() ~= "welcome" then
				ctx:fail("A non-Warlock without a driver setup did not land on the welcome view.", "mode=" .. tostring(drv.Mode()))
			end
			local wel = drv.ui.welcome
			if not (wel and wel:IsShown()) then
				ctx:fail("The welcome frame is not shown on the Drive tab.")
			end
			if not hasText(ctx, "Run a summoning service") then
				ctx:fail("The non-Warlock welcome does not say 'Run a summoning service'.")
			end
			clickObj(ctx, wel.skip, "Just help a friend's summons")
			if drv.Mode() ~= "welcome" or not wel:IsShown() then
				ctx:fail("Clicking 'Just help a friend's summons' left the welcome view.")
			end
		end,
	}

	-- 2. Warlock first-run welcome in Advanced mode + skip
	Hunt.promise{
		id = "b4setup.welcome_warlock_skip",
		area = "DriverSetup",
		text = "A fresh Warlock in Advanced mode sees 'Sell summons with Wuber', and clicking 'Just open the console' marks welcomed and opens the console.",
		source = "Wuber/UI/Driver/State.lua:289-292; Wuber/UI/Driver/Build.lua:754-758,795-803",
		kind = "scenario",
		needs = { role = "warlock", saved = "fresh", group = "solo", ride = "none" },
		check = function(ctx)
			noCombat(ctx)
			if ctx.W.SetAdvanced then ctx.W.SetAdvanced(true) end
			local c = ctx.W.Char and ctx.W.Char()
			if not c then ctx:cannot("no character table") end
			c.wizard = nil
			c.welcomed = nil
			if DR(ctx).IsOpen() then
				DR(ctx).SetOpen(false)
				ctx:advance(0.5)
			end
			openDrive(ctx)
			ensureBase(ctx)
			local drv = D(ctx)
			if drv.Mode() ~= "welcome" then
				ctx:fail("A fresh Warlock in Advanced mode did not see the welcome view.", "mode=" .. tostring(drv.Mode()))
			end
			if not hasText(ctx, "Sell summons with Wuber") then
				ctx:fail("The Warlock welcome does not say 'Sell summons with Wuber'.")
			end
			clickObj(ctx, drv.ui.welcome.skip, "Just open the console")
			if c.welcomed ~= true then
				ctx:fail("Clicking 'Just open the console' did not mark the character as welcomed.")
			end
			if drv.Mode() ~= "console" or not (drv.ui.console and drv.ui.console:IsShown()) then
				ctx:fail("Clicking 'Just open the console' did not switch to the Drive console.")
			end
		end,
	}

	-- 3. Wizard Step 1: non-Warlock has "Just me" disabled
	Hunt.promise{
		id = "b4setup.wizard_step1_non_warlock_solo_disabled",
		area = "DriverSetup",
		text = "On Wizard Step 1 as a non-Warlock, the heading asks 'Who casts?', 'Just me' is disabled, and clicking it keeps Next inactive.",
		source = "Wuber/UI/Driver/Wizard.lua:50-58,261-268,278-300,850",
		kind = "scenario",
		needs = { role = "rider" },
		when = freshCanWelcome,
		check = function(ctx)
			noCombat(ctx)
			local w = openWizard(ctx)
			if w.step ~= 1 then ctx:fail("Wizard did not open on Step 1.", "step=" .. tostring(w.step)) end
			if not hasText(ctx, "Who casts%?") then
				ctx:fail("Non-Warlock Wizard Step 1 does not ask 'Who casts?'.")
			end
			local solo = w.choices and w.choices[1]
			if not (solo and solo.off == true) then
				ctx:fail("'Just me' is not marked disabled for a non-Warlock.")
			end
			clickObj(ctx, solo, "Just me (disabled)")
			if w.choice == "solo" then
				ctx:fail("Clicking disabled 'Just me' selected solo for a non-Warlock.")
			end
			if w.next and w.next.inactive ~= true then
				ctx:fail("Next is active even though no valid Step 1 choice is selected.")
			end
		end,
	}

	-- 4. Wizard Step 1: Warlock "Just me" skips Step 2 and Back from Step 3 returns to Step 1
	Hunt.promise{
		id = "b4setup.wizard_solo_skips_step2",
		area = "DriverSetup",
		text = "As a Warlock, picking 'Just me' on Step 1 skips Step 2 to Step 3, and clicking Back on Step 3 returns to Step 1.",
		source = "Wuber/UI/Driver/Wizard.lua:777-789",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			noCombat(ctx)
			local w = openWizard(ctx)
			clickObj(ctx, w.choices[1], "Just me")
			if w.choice ~= "solo" then
				ctx:fail("Clicking 'Just me' did not select solo.")
			end
			clickObj(ctx, w.next, "Next")
			if w.step ~= 3 then
				ctx:fail("Picking 'Just me' and clicking Next did not jump to Step 3.", "step=" .. tostring(w.step))
			end
			if not hasText(ctx, "Who summons%?") then
				ctx:fail("Wizard Step 3 does not show 'Who summons?'.")
			end
			clickObj(ctx, w.back, "Back")
			if w.step ~= 1 then
				ctx:fail("Clicking Back from Step 3 after 'Just me' did not return to Step 1.", "step=" .. tostring(w.step))
			end
		end,
	}

	-- 5. Wizard Step 2 -> Back -> Step 1 -> Back -> base view
	Hunt.promise{
		id = "b4setup.wizard_step2_back_to_step1",
		area = "DriverSetup",
		text = "Picking friends on Step 1 goes to Step 2 ('Pick your crew'), Back returns to Step 1, and Back on Step 1 leaves the wizard.",
		source = "Wuber/UI/Driver/Wizard.lua:777-790",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			noCombat(ctx)
			local w = openWizard(ctx)
			clickObj(ctx, w.choices[2], "My friends help")
			clickObj(ctx, w.next, "Next")
			if w.step ~= 2 then
				ctx:fail("Clicking Next after 'My friends help' did not go to Step 2.", "step=" .. tostring(w.step))
			end
			if not hasText(ctx, "Pick your crew") then
				ctx:fail("Wizard Step 2 does not show 'Pick your crew'.")
			end
			clickObj(ctx, w.back, "Back from Step 2")
			if w.step ~= 1 then
				ctx:fail("Clicking Back on Step 2 did not return to Step 1.", "step=" .. tostring(w.step))
			end
			clickObj(ctx, w.back, "Back from Step 1")
			if D(ctx).CurrentScreen() ~= "console" then
				ctx:fail("Clicking Back on Step 1 did not leave the wizard.", "screen=" .. tostring(D(ctx).CurrentScreen()))
			end
		end,
	}

	-- 6. Wizard Step 2: Add by name refuses empty or invalid name
	Hunt.promise{
		id = "b4setup.wizard_step2_bad_name_refused",
		area = "DriverSetup",
		text = "On Wizard Step 2, submitting an empty or invalid name in Add by name does not send an offer or list the name.",
		source = "Wuber/UI/Driver/Wizard.lua:195-207,317-324",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			noCombat(ctx)
			local w = openWizard(ctx)
			clickObj(ctx, w.choices[2], "My friends help")
			clickObj(ctx, w.next, "Next")
			if w.step ~= 2 then ctx:cannot("did not reach Step 2") end
			if w.scroll and w.scroll.ScrollTo then w.scroll:ScrollTo(9999, true) ctx:advance(0.2) end
			w.adder.field:SetText("")
			clickObj(ctx, w.adder.add, "Add (empty)")
			if w.sent then
				ctx:fail("Submitting an empty name marked Step 2 offers as sent.")
			end
			if w.scroll and w.scroll.ScrollTo then w.scroll:ScrollTo(9999, true) ctx:advance(0.2) end
			w.adder.field:SetText("123")
			clickObj(ctx, w.adder.add, "Add (invalid '123')")
			if w.sent then
				ctx:fail("Submitting an invalid name ('123') marked Step 2 offers as sent.")
			end
			if DR(ctx).offers and DR(ctx).offers["123"] then
				ctx:fail("An invalid name ('123') created a crew offer.")
			end
		end,
	}

	-- 7. Wizard Step 2: Add by name with valid player sends offer and switches buttons
	Hunt.promise{
		id = "b4setup.wizard_step2_add_by_name_sends_offer",
		area = "DriverSetup",
		text = "On Wizard Step 2, adding a valid player name sends a crew offer, shows 'Waiting for ... to tap Yes', and reveals Next.",
		source = "Wuber/UI/Driver/Wizard.lua:218-231,317-324,816-837",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			noCombat(ctx)
			local targetName = "Bea Jones"
			if not ctx.w:player(targetName) then
				ctx.w:addBot(targetName, { class = "MAGE", online = true })
			end
			local w = openWizard(ctx)
			clickObj(ctx, w.choices[2], "My friends help")
			clickObj(ctx, w.next, "Next")
			if w.step ~= 2 then ctx:cannot("did not reach Step 2") end
			if w.scroll and w.scroll.ScrollTo then w.scroll:ScrollTo(9999, true) ctx:advance(0.2) end
			w.adder.field:SetText(targetName)
			clickObj(ctx, w.adder.add, "Add " .. targetName)
			local key = ctx.W.Key(targetName)
			if not (DR(ctx).offers and DR(ctx).offers[key]) then
				ctx:fail("Adding a valid player name did not record a crew offer.")
			end
			if not hasText(ctx, "Waiting for Bea to tap Yes") then
				ctx:fail("Step 2 does not show 'Waiting for Bea to tap Yes' after adding Bea Jones.")
			end
			if not (w.next and w.next:IsShown()) then
				ctx:fail("Next button did not appear after sending a crew offer on Step 2.")
			end
		end,
	}

	-- 8. Wizard Step 2: Send offers with nobody picked stays on Step 2; Skip for now advances to Step 3
	Hunt.promise{
		id = "b4setup.wizard_step2_skip_and_empty_send",
		area = "DriverSetup",
		text = "On Wizard Step 2 with nobody in the group, clicking 'Send offers' stays on Step 2, and clicking 'Skip for now' advances to Step 3.",
		source = "Wuber/UI/Driver/Wizard.lua:328-348,740-744,784",
		kind = "scenario",
		needs = { role = "warlock", saved = "fresh", group = "solo", ride = "none" },
		check = function(ctx)
			noCombat(ctx)
			local w = openWizard(ctx)
			clickObj(ctx, w.choices[2], "My friends help")
			clickObj(ctx, w.next, "Next")
			if w.step ~= 2 then ctx:cannot("did not reach Step 2") end
			if not (w.send and w.send:IsShown()) then
				ctx:fail("'Send offers' button is not shown on Step 2 before offers are sent.")
			end
			clickObj(ctx, w.send, "Send offers (empty)")
			if w.step ~= 2 or w.sent then
				ctx:fail("Clicking 'Send offers' with nobody picked advanced or marked sent.")
			end
			if not (w.skip and w.skip:IsShown()) then
				ctx:fail("'Skip for now' is not shown on Step 2.")
			end
			clickObj(ctx, w.skip, "Skip for now")
			if w.step ~= 3 then
				ctx:fail("Clicking 'Skip for now' on Step 2 did not advance to Step 3.", "step=" .. tostring(w.step))
			end
		end,
	}

	-- 9. Wizard Step 3: Done marks wizard complete, returns to console, and persists across reload
	Hunt.promise{
		id = "b4setup.wizard_step3_done_saves_and_persists",
		area = "DriverSetup",
		text = "Clicking Done on Step 3 marks setup complete, saves you as summoner, returns to the console, and stays out of welcome after /reload.",
		source = "Wuber/UI/Driver/Wizard.lua:791-801; Wuber/UI/Driver/State.lua:290-292",
		kind = "scenario",
		needs = { role = "warlock", saved = "fresh" },
		check = function(ctx)
			noCombat(ctx)
			if ctx.W.SetAdvanced then ctx.W.SetAdvanced(true) end
			local w = openWizard(ctx)
			clickObj(ctx, w.choices[1], "Just me")
			clickObj(ctx, w.next, "Next")
			if w.step ~= 3 then ctx:cannot("did not reach Step 3") end
			clickObj(ctx, w.next, "Done")
			local c = ctx.W.Char and ctx.W.Char()
			if not (c and c.wizard == true) then
				ctx:fail("Clicking Done on Step 3 did not save wizard = true.")
			end
			if D(ctx).CurrentScreen() ~= "console" then
				ctx:fail("Clicking Done on Step 3 did not return to the Drive console.", "screen=" .. tostring(D(ctx).CurrentScreen()))
			end
			local sum = DR(ctx).Summoners and DR(ctx).Summoners()
			if type(sum) ~= "table" or #sum == 0 then
				ctx:fail("Clicking Done as a Warlock did not save any summoner in DR.Summoners().")
			end
			ctx:reload()
			ctx:advance(2)
			openDrive(ctx)
			if D(ctx).Mode() ~= "console" then
				ctx:fail("After /reload, a driver who finished the wizard was sent back to welcome.", "mode=" .. tostring(D(ctx).Mode()))
			end
		end,
	}

	-- 10. Wizard Step 3: Reordering two Warlock summoners and toggling "Whoever clicks first"
	Hunt.promise{
		id = "b4setup.wizard_step3_reorder_and_whoever_first",
		area = "DriverSetup",
		text = "On Step 3 with two Warlocks in the crew, the up/down arrows reorder main caster and 'Whoever clicks first' toggles caster mode.",
		source = "Wuber/UI/Driver/Wizard.lua:548-576,638-685",
		kind = "scenario",
		needs = { role = "warlock", saved = "fresh" },
		check = function(ctx)
			noCombat(ctx)
			local allyName = "Cal Brown"
			if not ctx.w:player(allyName) then
				ctx.w:addBot(allyName, { class = "WARLOCK", online = true })
			end
			local allyKey = ctx.W.Key(allyName)
			DR(ctx).AddPlainHelper(allyName, "lock")
			ctx:advance(0.5)
			local w = openWizard(ctx)
			D(ctx).ShowScreen("wizard", 3)
			ctx:advance(0.6)
			if w.step ~= 3 then ctx:cannot("did not reach Step 3") end
			-- Tick all Warlocks if not already ticked
			local foundSecond = false
			for _, r in ipairs(w.summoners.list) do
				if r:IsShown() and r.p then
					if r.p.key == allyKey then foundSecond = true end
					if r.toggle and not r.toggle.on then
						clickObj(ctx, r.toggle, "tick summoner " .. tostring(r.p.key))
					end
				end
			end
			if not foundSecond then
				ctx:fail("The Warlock crewmate did not appear in Step 3's summoner list.")
			end
			if #w.order < 2 then
				ctx:fail("Expected 2 Warlocks in summoner order after ticking both.", "count=" .. tostring(#w.order))
			end
			local firstBefore = w.order[1]
			-- Click down arrow on the first row
			local firstRow = w.summoners.list[1]
			if not (firstRow and firstRow:IsShown() and firstRow.down and firstRow.down:IsShown()) then
				ctx:fail("The first summoner row does not show a down arrow when two Warlocks are ticked.")
			end
			clickObj(ctx, firstRow.down, "move first summoner down")
			if w.order[1] == firstBefore then
				ctx:fail("Clicking the down arrow did not swap the first summoner with the second.")
			end
			-- "Whoever clicks first" should be visible with 2+ ticked
			if not (w.any and w.any:IsShown()) then
				ctx:fail("'Whoever clicks first' is hidden when two Warlocks are ticked.")
			end
			clickObj(ctx, w.any, "Whoever clicks first (on)")
			local c = ctx.W.Char and ctx.W.Char()
			if not (c and c.caster == "-") then
				ctx:fail("Clicking 'Whoever clicks first' did not set caster to '-'.")
			end
			clickObj(ctx, w.any, "Whoever clicks first (off)")
			if c and c.caster == "-" then
				ctx:fail("Clicking 'Whoever clicks first' a second time did not restore ordered caster.")
			end
		end,
	}

	-- 11. Wizard direct entry to Step 3 via D.ShowScreen("wizard", 3)
	Hunt.promise{
		id = "b4setup.wizard_enter_step3_direct",
		area = "DriverSetup",
		text = "Opening the wizard with step 3 lands directly on Step 3 ('Who summons?') with CurrentScreen() == 'wizard'.",
		source = "Wuber/UI/Driver/Wizard.lua:863-878",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			noCombat(ctx)
			openDrive(ctx)
			ensureBase(ctx)
			D(ctx).ShowScreen("wizard", 3)
			ctx:advance(0.6)
			if D(ctx).CurrentScreen() ~= "wizard" then
				ctx:fail("CurrentScreen() is not 'wizard' after ShowScreen('wizard', 3).", "screen=" .. tostring(D(ctx).CurrentScreen()))
			end
			local w = D(ctx).ui and D(ctx).ui.subs and D(ctx).ui.subs.wizard
			if not (w and w.step == 3) then
				ctx:fail("ShowScreen('wizard', 3) did not open on Step 3.", "step=" .. tostring(w and w.step))
			end
			if not hasText(ctx, "Who summons%?") then
				ctx:fail("Direct Step 3 entry does not display 'Who summons?'.")
			end
		end,
	}

	-- 12. Driver screen switcher: Your business rows -> sub-screens -> Back to console
	Hunt.promise{
		id = "b4setup.switcher_business_rows_and_back",
		area = "DriverSetup",
		text = "Clicking each 'Your business' row on the console opens its screen and clicking Back returns to the console.",
		source = "Wuber/UI/Driver/Build.lua:589-594; Wuber/UI/Driver/Console.lua:89-138; Wuber/UI/Driver/Screens.lua:148-151",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			noCombat(ctx)
			openDrive(ctx)
			ensureBase(ctx)
			local drv = D(ctx)
			if drv.Mode() ~= "console" then ctx:na("not on console mode") end
			local con = drv.ui.console
			local checks = {
				{ key = "crew", screen = "crew" },
				{ key = "blocked", screen = "blocked" },
				{ key = "earnings", screen = "earnings" },
				{ key = "customers", screen = "customers" },
			}
			-- Messages row is "messages" in Advanced or "advert" in Simple
			if con.links.messages and con.links.messages:IsShown() then
				checks[#checks + 1] = { key = "messages", screen = "messages" }
			elseif con.links.advert and con.links.advert:IsShown() then
				checks[#checks + 1] = { key = "advert", screen = "messages" }
			end
			for _, item in ipairs(checks) do
				if con.scroll and con.scroll.ScrollTo then
					con.scroll:ScrollTo(9999, true)
					ctx:advance(0.2)
				end
				local row = con.links[item.key]
				if not (row and row:IsShown()) then
					ctx:fail("Your business row '" .. item.key .. "' is not shown on the console.")
				end
				clickObj(ctx, row, "Your business: " .. item.key)
				if drv.CurrentScreen() ~= item.screen then
					ctx:fail("Clicking '" .. item.key .. "' did not switch to '" .. item.screen .. "'.", "got=" .. tostring(drv.CurrentScreen()))
				end
				local scr = drv.ui.subs and drv.ui.subs[item.screen]
				if not (scr and scr.frame and scr.frame:IsShown()) then
					ctx:fail("Screen frame for '" .. item.screen .. "' is not shown after clicking '" .. item.key .. "'.")
				end
				clickObj(ctx, scr.back, "Back from " .. item.screen)
				if drv.CurrentScreen() ~= "console" then
					ctx:fail("Clicking Back on '" .. item.screen .. "' did not return to 'console'.", "got=" .. tostring(drv.CurrentScreen()))
				end
			end
		end,
	}

	-- 13. Driver mode bar: switching between Sell summons and Raid summons
	Hunt.promise{
		id = "b4setup.switcher_mode_bar_sell_and_raid",
		area = "DriverSetup",
		text = "Clicking 'Raid summons' and 'Sell summons' on the mode bar switches DR.Mode() between 'raid' and 'sell'.",
		source = "Wuber/UI/Driver/Build.lua:628-638,705-713; Wuber/UI/Driver/Draw.lua:237-240",
		kind = "scenario",
		needs = { role = "warlock" },
		check = function(ctx)
			noCombat(ctx)
			if ctx.W.SetAdvanced then ctx.W.SetAdvanced(true) end
			openDrive(ctx)
			ensureBase(ctx)
			local drv = D(ctx)
			if drv.Mode() ~= "console" then ctx:na("not on console mode") end
			local seg = drv.ui.console and drv.ui.console.modeBar
			if not (seg and seg:IsShown() and seg.buttons and #seg.buttons >= 2) then
				ctx:na("mode bar not shown")
			end
			local sellBtn, raidBtn = seg.buttons[1], seg.buttons[2]
			clickObj(ctx, raidBtn, "Raid summons")
			if DR(ctx).Mode() ~= "raid" then
				ctx:fail("Clicking 'Raid summons' did not switch DR.Mode() to 'raid'.", "mode=" .. tostring(DR(ctx).Mode()))
			end
			clickObj(ctx, sellBtn, "Sell summons")
			if DR(ctx).Mode() ~= "sell" then
				ctx:fail("Clicking 'Sell summons' did not switch DR.Mode() back to 'sell'.", "mode=" .. tostring(DR(ctx).Mode()))
			end
		end,
	}
end
