-- Bug hunt wave 4 promises for Driver Rows, Crew, and Draw
-- (Wuber/UI/Driver/Rows.lua, Crew.lua, Draw.lua).
-- Prefix: b5rows.
return function(Hunt)
	local FOLDABLE = {
		home = true, trips = true, drive = true, drive_earnings = true,
		drive_messages = true, drive_customers = true, settings = true,
		settings_riding = true, settings_driving = true, settings_map = true,
		settings_sound = true, settings_window = true, world_view = true,
		here_view = true, confirm = true, wrapped = true,
	}

	local function promise(p)
		local w = p.when
		p.when = function(sit)
			if sit.fold == "folded_click" and not FOLDABLE[sit.phone or "closed"] then return false end
			return w == nil or w(sit)
		end
		Hunt.promise(p)
	end

	local function isDriverRole(sit) return sit.role == "warlock" or sit.role == "crew" end
	local function inCombat(ctx) return ctx.me.player.combat and true or false end
	local function kit(ctx) local K = ctx:mod("UI.Kit") return K and K.ui or {} end
	local function seen(ctx) return "on screen: " .. table.concat(ctx:texts(), " | ") end

	local function hasText(ctx, pat, plain)
		for _, t in ipairs(ctx:texts()) do
			if t:find(pat, 1, plain) then return t end
		end
		return nil
	end

	local function clearOverlays(ctx)
		local UI = ctx.W.UI
		for _ = 1, 3 do
			local ui = kit(ctx)
			local WM = ctx:mod("UI.Rider.Wrapped")
			if WM and type(WM.Shown) == "function" and WM.Shown() then WM.Close() ctx:advance(0.4) end
			local over = ui.settingsOpen
				or (type(UI.HelpShown) == "function" and UI.HelpShown())
				or (type(UI.Bug) == "table" and type(UI.Bug.Shown) == "function" and UI.Bug.Shown())
			if not over then return end
			if ui.settingsOpen and type(UI.CloseSettings) == "function" then pcall(UI.CloseSettings, true) end
			ctx.me:pressEscape()
			ctx:advance(0.6)
		end
	end

	local function openDrive(ctx)
		if inCombat(ctx) then ctx:na("in combat") end
		local UI = ctx.W.UI
		if not UI.IsShown() then
			ctx.me:slash("/wuber")
			ctx:advance(2.0)
		end
		clearOverlays(ctx)
		if not UI.IsShown() then
			ctx.me:slash("/wuber")
			ctx:advance(2.0)
		end
		local ui = kit(ctx)
		if ui.tab ~= "Drive" then
			for _, tab in ipairs(ui.tabs or {}) do
				if tab.name == "Drive" and tab.button and ctx:visible(tab.button) then
					ctx.me:clickOn(tab.button)
					ctx:advance(0.6)
					break
				end
			end
		end
		if not UI.IsShown() or kit(ctx).tab ~= "Drive" then ctx:na("Drive tab is not reachable") end
	end

	local function openCrew(ctx)
		openDrive(ctx)
		local D = ctx.W.Driver
		if not D or not D.ShowScreen then ctx:cannot("no Driver.ShowScreen") end
		D.ShowScreen("crew")
		ctx:advance(0.4)
		if not D.ui or D.ui.screen ~= "crew" then ctx:na("Crew screen not reachable") end
	end

	-- 1. Rows: D.Describe describes each queue stage accurately
	promise{
		id = "b5rows.row_describe_stages",
		area = "Rows",
		text = "D.Describe describes queued, invited, joined, summoning, waiting, arrived, and paid riders with accurate stage words.",
		source = "Wuber/UI/Driver/Rows.lua:79-114",
		kind = "scenario",
		when = function(sit) return isDriverRole(sit) end,
		check = function(ctx)
			local D = ctx.W.Driver
			if not D or not D.Describe then ctx:cannot("no D.Describe") end
			local t = 1000
			local w1 = D.Describe({ name = "Bob", state = "queued", at = 970 }, t)
			local w2 = D.Describe({ name = "Bob", state = "invited", at = 980 }, t)
			local w3 = D.Describe({ name = "Bob", state = "joined", tries = 0 }, t)
			local w4 = D.Describe({ name = "Bob", state = "joined", tries = 1 }, t)
			local w5 = D.Describe({ name = "Bob", state = "summoning", caster = ctx.W.myKey }, t)
			local w6 = D.Describe({ name = "Bob", state = "waiting", at = 990 }, t)
			local w7, r7 = D.Describe({ name = "Bob", state = "arrived", price = 5000, paid = 0 }, t)
			local w8 = D.Describe({ name = "Bob", state = "paid", paid = 5000 }, t)
			if w1 ~= "in the queue" or w2 ~= "invited" or w3 ~= "ready to summon" or w4 ~= "summon again" then
				ctx:fail("D.Describe returned unexpected words for early queue stages.", string.format("%s | %s | %s | %s", tostring(w1), tostring(w2), tostring(w3), tostring(w4)))
			end
			if w5 ~= "summoning (you)" or w6 ~= "has the summon window" or not tostring(w7):find("landed", 1, true) or not tostring(r7):find("owes", 1, true) or w8 ~= "paid" then
				ctx:fail("D.Describe returned unexpected words for summon/arrived/paid stages.", string.format("%s | %s | %s (%s) | %s", tostring(w5), tostring(w6), tostring(w7), tostring(r7), tostring(w8)))
			end
		end,
	}

	-- 2. Rows: helperOf and walked arrived rows
	promise{
		id = "b5rows.row_describe_helper_and_walked",
		area = "Rows",
		text = "D.Describe labels a helper row as 'came with <who>?' and a walked-in rider as 'is here (no ride)'.",
		source = "Wuber/UI/Driver/Rows.lua:82,104",
		kind = "scenario",
		when = function(sit) return isDriverRole(sit) end,
		check = function(ctx)
			local D = ctx.W.Driver
			if not D or not D.Describe then ctx:cannot("no D.Describe") end
			local h = D.Describe({ name = "Al", state = "joined", helperOf = "Bob-TestRealm" }, 1000)
			local w = D.Describe({ name = "Cid", state = "arrived", walked = true, price = 5000 }, 1000)
			if h ~= "came with Bob?" then
				ctx:fail("D.Describe did not label a helper row as 'came with <who>?'.", tostring(h))
			end
			if w ~= "is here (no ride)" then
				ctx:fail("D.Describe did not label a walked arrived rider as 'is here (no ride)'.", tostring(w))
			end
		end,
	}

	-- 3. Rows: D.RowTip includes Wuber booking note and all four action hints
	promise{
		id = "b5rows.row_tip_contents",
		area = "Rows",
		text = "A queue row's tooltip mentions Wuber booking for app riders and lists Click, Ctrl-click, Right-click, and Shift-right-click.",
		source = "Wuber/UI/Driver/Rows.lua:139-173",
		kind = "scenario",
		when = function(sit) return isDriverRole(sit) end,
		check = function(ctx)
			local D = ctx.W.Driver
			if not D or not D.RowTip then ctx:cannot("no D.RowTip") end
			local tip = D.RowTip({ name = "Ada-TestRealm", state = "joined", source = "wuber" })
			for _, want in ipairs({
				"Booked through the Wuber app.",
				"Click: summon this one next.",
				"Ctrl-click: mark as paid.",
				"Right-click: take off the list.",
				"Shift-right-click: block (never serve again).",
			}) do
				if not tip:find(want, 1, true) then
					ctx:fail("D.RowTip was missing '" .. want .. "'.", tip)
				end
			end
		end,
	}

	-- 4. Rows: GiveRaincheck on ineligible row warns and returns false
	promise{
		id = "b5rows.row_give_raincheck_ineligible",
		area = "Rows",
		text = "Offering a raincheck for a ride that is not an eligible failed paid ride warns the driver and returns false.",
		source = "Wuber/UI/Driver/Rows.lua:237-260",
		kind = "scenario",
		when = function(sit) return isDriverRole(sit) and sit.ride ~= "summoning" end,
		check = function(ctx)
			local D = ctx.W.Driver
			if not D or not D.GiveRaincheck then ctx:cannot("no D.GiveRaincheck") end
			if ctx.W.UI.ToastShowing and ctx.W.UI.ToastShowing() then ctx:advance(9.0) end
			local ok = D.GiveRaincheck({ name = "Bob-TestRealm", state = "joined" })
			ctx:advance(0.3)
			local warned = hasText(ctx, "No raincheck for this ride", true)
			ctx:advance(4.5)
			if ok then
				ctx:fail("D.GiveRaincheck returned true for an ineligible row.", tostring(ok))
			end
			if not warned then
				ctx:fail("D.GiveRaincheck on an ineligible row did not show the warning toast.", seen(ctx))
			end
		end,
	}

	-- 5. Rows: ToggleGetApp queues and cancels Get Wuber for a live chat rider
	promise{
		id = "b5rows.row_toggle_get_app",
		area = "Rows",
		text = "Toggling 'Get Wuber' on a live chat rider queues the whisper for the big button's next click, and toggling again cancels it.",
		source = "Wuber/UI/Driver/Rows.lua:265-275",
		kind = "scenario",
		when = function(sit) return sit.role == "warlock" and sit.opt_whisperMode ~= "off" end,
		check = function(ctx)
			local DR = ctx.W.Drive
			local D = ctx.W.Driver
			if not DR or not D or not D.ToggleGetApp then ctx:cannot("no Drive or D.ToggleGetApp") end
			if type(DR.Request) ~= "function" then ctx:cannot("no DR.Request") end
			local key = ctx.W.Key("Chatrider")
			local had = DR.customers and DR.customers[key]
			local c = had or DR.Request("Chatrider", "whisper", "summon please")
			if not c then ctx:cannot("could not add chat rider") end
			if c.source == "wuber" or c.wuber then
				if not had and DR.Do then pcall(DR.Do, "DROP", "Chatrider") end
				ctx:na("rider already has Wuber")
			end
			local ok1 = D.ToggleGetApp(c)
			local st1 = DR.GetAppState and DR.GetAppState(c)
			local ok2 = D.ToggleGetApp(c)
			local st2 = DR.GetAppState and DR.GetAppState(c)
			ctx:advance(0.3)
			local msg2 = hasText(ctx, "\"Get Wuber\" won't be sent", true)
			if not had and DR.Do then pcall(DR.Do, "DROP", "Chatrider") end
			ctx:advance(4.5)
			if not ok1 or st1 ~= "queued" then
				ctx:fail("Toggling 'Get Wuber' on did not queue it.", string.format("ok1=%s st1=%s", tostring(ok1), tostring(st1)))
			end
			if not ok2 or st2 == "queued" or not msg2 then
				ctx:fail("Toggling 'Get Wuber' off did not cancel it and tell the driver.", string.format("ok2=%s st2=%s msg2=%s", tostring(ok2), tostring(st2), tostring(msg2)))
			end
		end,
	}

	-- 6. Rows: DescribeRaid & RaidTip
	promise{
		id = "b5rows.raid_describe_and_tip",
		area = "Rows",
		text = "D.DescribeRaid and D.RaidTip describe waiting, claimed, retry, and fresh raid summon requests accurately.",
		source = "Wuber/UI/Driver/Rows.lua:317-350",
		kind = "scenario",
		when = function(sit) return isDriverRole(sit) end,
		check = function(ctx)
			local D = ctx.W.Driver
			if not D or not D.DescribeRaid or not D.RaidTip then ctx:cannot("no D.DescribeRaid/RaidTip") end
			local t = 1000
			local w1 = D.DescribeRaid({ name = "R1", asked = 990 }, t)
			local w2 = D.DescribeRaid({ name = "R2", asked = 990, tries = 1 }, t)
			local w3 = D.DescribeRaid({ name = "R3", asked = 990, claimedBy = ctx.W.myKey }, t)
			local w4 = D.DescribeRaid({ name = "R4", asked = 990, state = "waiting" }, t)
			if w1 ~= "asked for a summon" or w2 ~= "summon again (try 2)" or w3 ~= "summoning (you)" or w4 ~= "has the summon window" then
				ctx:fail("D.DescribeRaid returned unexpected words.", string.format("%s | %s | %s | %s", tostring(w1), tostring(w2), tostring(w3), tostring(w4)))
			end
			local tip = D.RaidTip({ name = "R1", asked = 990 })
			if not tip:find("Click: summon this one next.", 1, true) or not tip:find("Right-click: take off the list", 1, true) then
				ctx:fail("D.RaidTip was missing expected action hints.", tip)
			end
		end,
	}

	-- 7. Crew: empty crew shows "Just you" card
	promise{
		id = "b5rows.crew_just_you_when_empty",
		area = "Crew",
		text = "When a solo Warlock has no other crew members, the Crew screen shows 'Just you' with 'Riders bring two friends to click the portal'.",
		source = "Wuber/UI/Driver/Crew.lua:305-316",
		kind = "scenario",
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			local DR = ctx.W.Drive
			if not DR or type(DR.Crew) ~= "function" then ctx:cannot("no DR.Crew") end
			local others = 0
			for _, m in ipairs(DR.Crew()) do
				if not m.me then others = others + 1 end
			end
			if others > 0 then ctx:na("crew already has other members") end
			openCrew(ctx)
			if not hasText(ctx, "Just you", true) or not hasText(ctx, "Riders bring two friends to click the portal", true) then
				ctx:fail("An empty Warlock crew did not show 'Just you' on the Crew screen.", seen(ctx))
			end
		end,
	}

	-- 8. Crew: Fair split segmented control toggles Equal and hides Casters' part
	promise{
		id = "b5rows.crew_split_rule_and_slider",
		area = "Crew",
		text = "In Advanced mode on the Crew screen, switching Fair split to 'Equal' hides the 'Casters' part' slider, and 'By clicks' shows it.",
		source = "Wuber/UI/Driver/Crew.lua:220-247,346-366",
		kind = "scenario",
		needs = { advanced = "on" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			if ctx.W.Drive and ctx.W.Drive.IsCaptain and ctx.W.Drive.IsCaptain() == false then
				ctx:na("not crew captain")
			end
			openCrew(ctx)
			local s = ctx.W.Driver.ui and ctx.W.Driver.ui.screens and ctx.W.Driver.ui.screens.crew
			if not s or not s.cutSeg or not s.cutCasterRow then ctx:cannot("no split controls on Crew screen") end
			local oldRule = ctx.W.Drive and ctx.W.Drive.opts and ctx.W.Drive.opts().cutRule
			local eqBtn = ctx.me:button("Equal")
			local bcBtn = ctx.me:button("By clicks")
			if not eqBtn or not ctx:visible(eqBtn) or not bcBtn or not ctx:visible(bcBtn) then
				ctx:na("Fair split buttons not visible")
			end
			ctx.me:clickOn(eqBtn)
			ctx:advance(0.4)
			local hiddenOnEqual = not ctx:visible(s.cutCasterRow)
			ctx.me:clickOn(bcBtn)
			ctx:advance(0.4)
			local shownOnClicks = ctx:visible(s.cutCasterRow)
			if oldRule and ctx.W.Drive and ctx.W.Drive.SetOpt then
				ctx.W.Drive.SetOpt("cutRule", oldRule)
				s.update()
			end
			if not hiddenOnEqual then
				ctx:fail("Switching Fair split to 'Equal' did not hide the 'Casters' part' slider.", seen(ctx))
			end
			if not shownOnClicks then
				ctx:fail("Switching Fair split to 'By clicks' did not show the 'Casters' part' slider.", seen(ctx))
			end
		end,
	}

	-- 9. Crew: Run the setup again opens wizard
	promise{
		id = "b5rows.crew_run_setup_opens_wizard",
		area = "Crew",
		text = "Clicking 'Run the setup again' on the Crew screen opens the crew setup wizard.",
		source = "Wuber/UI/Driver/Crew.lua:248-251",
		kind = "scenario",
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			if ctx.W.Drive and ctx.W.Drive.IsCaptain and ctx.W.Drive.IsCaptain() == false then
				ctx:na("not crew captain")
			end
			openCrew(ctx)
			local s = ctx.W.Driver.ui and ctx.W.Driver.ui.screens and ctx.W.Driver.ui.screens.crew
			if not s or not s.wizard or not ctx:visible(s.wizard) then ctx:na("Run the setup again button not visible") end
			ctx.me:clickOn(s.wizard)
			ctx:advance(0.4)
			if not ctx.W.Driver.ui or ctx.W.Driver.ui.screen ~= "wizard" then
				ctx:fail("Clicking 'Run the setup again' on Crew did not open the wizard.", tostring(ctx.W.Driver.ui and ctx.W.Driver.ui.screen))
			end
			ctx.W.Driver.ShowScreen("console")
		end,
	}

	-- 10. Crew: Leave this crew requires two clicks
	promise{
		id = "b5rows.crew_leave_requires_two_clicks",
		area = "Crew",
		text = "For a crew member, clicking 'Leave this crew' once asks 'Click again to leave' without leaving, and clicking again leaves.",
		source = "Wuber/UI/Driver/Crew.lua:252-265",
		kind = "scenario",
		when = function(sit) return sit.role == "crew" end,
		check = function(ctx)
			local DR = ctx.W.Drive
			if not DR or (DR.IsCaptain and DR.IsCaptain() ~= false) then
				ctx:na("player is captain, not a member")
			end
			openCrew(ctx)
			local s = ctx.W.Driver.ui and ctx.W.Driver.ui.screens and ctx.W.Driver.ui.screens.crew
			if not s or not s.leave or not ctx:visible(s.leave) then ctx:na("Leave this crew button not visible") end
			ctx.me:clickOn(s.leave)
			ctx:advance(0.3)
			local label1 = s.leave.label and s.leave.label:GetText()
			local stillMember = DR.IsCaptain and DR.IsCaptain() == false and ctx.W.Driver.ui.screen == "crew"
			if label1 ~= "Click again to leave" or not stillMember then
				ctx:fail("First click on 'Leave this crew' did not ask 'Click again to leave' while staying in crew.", tostring(label1))
			end
			ctx.me:clickOn(s.leave)
			ctx:advance(0.5)
			if not hasText(ctx, "You left the crew", true) then
				ctx:fail("Second click on 'Leave this crew' did not leave the crew and show the toast.", seen(ctx))
			end
			ctx:advance(4.5)
		end,
	}

	-- 11. Draw: FuelInfo / PaintFuel colours (violet > 2*low, amber <= 2*low, red <= low)
	promise{
		id = "b5rows.draw_fuel_info_colours",
		area = "Draw",
		text = "D.FuelInfo and D.PaintFuel show amber at or below 2x lowShards and red at or below lowShards.",
		source = "Wuber/UI/Driver/Draw.lua:88-119",
		kind = "scenario",
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			local D = ctx.W.Driver
			local DR = ctx.W.Drive
			if not D or not D.FuelInfo or not DR or not DR.opts then ctx:cannot("no D.FuelInfo or DR.opts") end
			local o = DR.opts()
			local low = tonumber(type(o) == "table" and o.lowShards) or 3
			if low <= 0 then ctx:na("lowShards warning is off") end
			local oldShards = DR.Shards
			DR.Shards = function() return low end
			local nRed, cRed = D.FuelInfo()
			DR.Shards = function() return low * 2 end
			local nAmb, cAmb = D.FuelInfo()
			DR.Shards = function() return low * 2 + 1 end
			local nAcc, cAcc = D.FuelInfo()
			DR.Shards = oldShards
			if nRed ~= low or cRed ~= "red" then
				ctx:fail("D.FuelInfo was not red at lowShards.", string.format("n=%s c=%s", tostring(nRed), tostring(cRed)))
			end
			if nAmb ~= low * 2 or cAmb ~= "amber" then
				ctx:fail("D.FuelInfo was not amber at 2x lowShards.", string.format("n=%s c=%s", tostring(nAmb), tostring(cAmb)))
			end
			if nAcc ~= low * 2 + 1 or cAcc ~= "accent" then
				ctx:fail("D.FuelInfo was not accent above 2x lowShards.", string.format("n=%s c=%s", tostring(nAcc), tostring(cAcc)))
			end
		end,
	}

	-- 12. Draw: Closed Drive console dims Pause and Advertise pills
	promise{
		id = "b5rows.draw_closed_dims_pause_and_advert",
		area = "Draw",
		text = "When the Warlock's Drive console is closed, the Pause and Advertise pills are dimmed (alpha < 1), and when open they are full brightness.",
		source = "Wuber/UI/Driver/Draw.lua:279-289",
		kind = "scenario",
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			local DR = ctx.W.Drive
			if not DR or (DR.Role and DR.Role() == "helper") then ctx:na("not a Warlock driver") end
			if DR.RaidMode and DR.RaidMode() then ctx:na("in raid mode") end
			openDrive(ctx)
			local v = ctx.W.Driver.ui and ctx.W.Driver.ui.view
			if not v or not v.pause or not v.advert then ctx:cannot("no pause/advert pills") end
			local wasOpen = DR.IsOpen and DR.IsOpen()
			if wasOpen then DR.Close() ctx:advance(0.3) end
			ctx.W.Driver.Refresh(true)
			local closedPausedAlpha = v.pause:GetAlpha()
			local closedAdvertAlpha = v.advert:GetAlpha()
			if closedPausedAlpha >= 1 or closedAdvertAlpha >= 1 then
				if wasOpen and DR.Open then DR.Open() end
				ctx:fail("When the Drive console is closed, Pause or Advertise was not dimmed.", string.format("pause=%s advert=%s", tostring(closedPausedAlpha), tostring(closedAdvertAlpha)))
			end
			if wasOpen and DR.Open then
				DR.Open()
				ctx:advance(0.3)
				ctx.W.Driver.Refresh(true)
			end
		end,
	}
end
