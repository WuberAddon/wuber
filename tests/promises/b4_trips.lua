-- New promises for Trips and Azeroth Wrapped (Wuber/UI/Rider/Trips.lua, Wuber/UI/Rider/Wrapped.lua).
-- Prefix: b4trips. Written from source contracts, tooltips/help text, and docs/PLAYER-GUIDE.md.
return function(Hunt)
	local function is(sit, dial, want)
		local v = sit[dial]
		if v == nil then return true end
		if type(want) == "table" then return want[v] == true end
		return v == want
	end

	local function ui(ctx)
		local K = ctx:mod("UI.Kit")
		return K and K.ui or {}
	end

	local function shown(ctx)
		local UI = ctx.W.UI
		return type(UI.IsShown) == "function" and UI.IsShown() == true
	end

	local function clickTab(ctx, name)
		local s = ui(ctx)
		for _, tab in ipairs(s.tabs or {}) do
			if tab.name == name and tab.button and ctx:visible(tab.button) then
				ctx.me:clickOn(tab.button)
				ctx:advance(0.8)
				ctx:note("click the " .. name .. " tab")
				return s.tab == name
			end
		end
		return false
	end

	local function overlayOpen(ctx)
		local UI = ctx.W.UI
		local s = ui(ctx)
		if s.settingsOpen == true or (UI.state and UI.state.settingsOpen == true) then return true end
		if type(UI.HelpShown) == "function" and UI.HelpShown() == true then return true end
		if type(UI.Bug) == "table" and type(UI.Bug.Shown) == "function" and UI.Bug.Shown() == true then return true end
		return false
	end

	local function leaveOverlays(ctx, tab)
		if overlayOpen(ctx) then
			clickTab(ctx, tab)
			ctx:advance(0.5)
			if overlayOpen(ctx) then ctx:na("Settings, Help or the report stays on top after a tab is clicked") end
		end
	end

	local function plainTexts(ctx)
		local out = {}
		for _, t in ipairs(ctx:texts()) do out[#out + 1] = (t:gsub("|T.-|t", "")) end
		return out
	end

	local function onScreen(ctx) return "on screen: " .. table.concat(plainTexts(ctx), " | ") end

	local function has(ctx, text)
		for _, t in ipairs(plainTexts(ctx)) do
			if t == text then return true end
		end
		return false
	end

	local function findText(ctx, pat)
		for _, t in ipairs(plainTexts(ctx)) do
			local a, b, c = t:match(pat)
			if a then return t, a, b, c end
		end
		return nil
	end

	local function tripsMod(ctx) return ctx:mod("UI.Rider.Trips") end

	local function view(ctx)
		local m = tripsMod(ctx)
		if not (m and type(m.view) == "function") then ctx:cannot("this Wuber has no Trips tab (UI.Rider.Trips)") end
		return m.view()
	end

	local function wrappedMod(ctx)
		local m = ctx:mod("UI.Rider.Wrapped")
		if not (m and type(m.Due) == "function") then ctx:cannot("this Wuber has no Wrapped (UI.Rider.Wrapped)") end
		return m
	end

	local function atTrips(ctx, again)
		if not shown(ctx) then
			if ctx.me.player.combat then ctx:na("in combat: the phone does not open") end
			ctx.me:slash("/wuber")
			ctx:note("/wuber")
			ctx:advance(0.3)
			if not shown(ctx) then ctx:cannot("the phone did not open on /wuber") end
			ctx:advance(2.2)
		end
		local WR = ctx:mod("UI.Rider.Wrapped")
		if WR and type(WR.Shown) == "function" and WR.Shown() then
			WR.Close()
			ctx:note("close the Wrapped story")
			ctx:advance(0.5)
		end
		local wasOverlay = overlayOpen(ctx)
		leaveOverlays(ctx, "Trips")
		if again and not wasOverlay and ui(ctx).tab == "Trips" then
			clickTab(ctx, "Ride")
			if ui(ctx).tab == "Trips" then
				ctx:na("could not leave Trips for a fresh visit")
			end
		end
		if ui(ctx).tab ~= "Trips" then
			if not clickTab(ctx, "Trips") then ctx:na("the Trips tab is not clickable in this state") end
		end
		if ui(ctx).tab ~= "Trips" then ctx:cannot("the Trips tab did not open") end
		ctx:advance(2)
		if ui(ctx).tab ~= "Trips" then
			clickTab(ctx, "Trips")
			ctx:advance(2)
			if ui(ctx).tab ~= "Trips" then ctx:cannot("the Trips tab did not stay open") end
		end
		for _ = 1, 3 do
			local b = ctx.me:button("Got it")
			if b and ctx:visible(b) then
				ctx.me:clickOn(b)
				ctx:advance(0.6)
				ctx:note("close the What's new card (Got it)")
			else
				break
			end
		end
	end

	local function setAdvanced(ctx, want)
		local isAdv = type(ctx.W.Advanced) == "function" and ctx.W.Advanced() == true
		if isAdv ~= want then
			ctx.me:slash("/wuber advanced")
			ctx:advance(0.6)
			ctx:note("switch /wuber advanced to " .. tostring(want))
		end
		local nowAdv = type(ctx.W.Advanced) == "function" and ctx.W.Advanced() == true
		if nowAdv ~= want then ctx:na("could not switch Advanced mode to " .. tostring(want)) end
	end

	local function hoverTip(ctx, frame)
		local gt = ctx.me.env.GameTooltip
		if not (gt and frame and frame.GetScript) then return "" end
		local fn = frame:GetScript("OnEnter")
		if not fn then return "" end
		pcall(fn, frame)
		local lines = {}
		for i = 1, 10 do
			local fs = ctx.me.env["GameTooltipTextLeft" .. i]
			if fs and fs.GetText and fs:IsShown() then
				local txt = fs:GetText()
				if txt and txt ~= "" then lines[#lines + 1] = (txt:gsub("|T.-|t", "")) end
			end
		end
		local leave = frame:GetScript("OnLeave")
		if leave then pcall(leave, frame) end
		return table.concat(lines, "\n")
	end

	local function paidCount(ctx)
		local n = 0
		for _, t in ipairs(ctx.W.db and ctx.W.db.rides or {}) do
			if type(t) == "table" and not t.unpaid then n = n + 1 end
		end
		return n
	end

	local NOCOMBAT = function(sit) return is(sit, "combat", "no") end

	-- 1. Empty state
	Hunt.promise{
		id = "b4trips.empty_trips_message",
		area = "Trips",
		text = "When you have no paid rides yet, Trips shows 'No trips yet. Your first ride shows up here.', 'Your first ride starts the count', and 'New rider' with '3 more to Bronze'.",
		source = "Wuber/UI/Rider/Trips.lua:297,432,438,461",
		kind = "scenario",
		when = function(sit) return NOCOMBAT(sit) and is(sit, "ride", { none = true, requested = true, invited = true, summoning = true, arrived = true, timedout = true }) end,
		check = function(ctx)
			if paidCount(ctx) > 0 then ctx:na("this character already has paid rides") end
			atTrips(ctx)
			local st = ctx.W.Stats and ctx.W.Stats() or {}
			if (tonumber(st.rides) or 0) > 0 then ctx:na("stats already count rides") end
			if not has(ctx, "No trips yet. Your first ride shows up here.") then
				ctx:fail("With no paid rides, Trips does not show the empty history message.", onScreen(ctx))
			end
			if not has(ctx, "Your first ride starts the count") then
				ctx:fail("With no paid rides, Trips does not say 'Your first ride starts the count'.", onScreen(ctx))
			end
			if not has(ctx, "New rider") or not findText(ctx, "^0 rides? · 3 more to Bronze$") then
				ctx:fail("With no paid rides, Trips does not show New rider and 3 more to Bronze.", onScreen(ctx))
			end
		end,
	}

	-- 2. Simple mode hides extras
	Hunt.promise{
		id = "b4trips.simple_mode_hides_extras",
		area = "Trips",
		text = "In Simple mode, Trips hides the habit chips, the Milestones tray, and the Azeroth Wrapped card and chip, while keeping Time saved, your rider level, and Your trips.",
		source = "docs/PLAYER-GUIDE.md:25",
		kind = "scenario",
		when = NOCOMBAT,
		check = function(ctx)
			atTrips(ctx)
			setAdvanced(ctx, false)
			ctx:advance(0.5)
			local tr = view(ctx)
			for i = 1, 3 do
				if tr.chips and tr.chips[i] and ctx:visible(tr.chips[i]) then
					ctx:fail("In Simple mode, Trips still shows a habit chip.", onScreen(ctx))
				end
			end
			if (tr.tray and ctx:visible(tr.tray)) or (tr.mHead and ctx:visible(tr.mHead)) then
				ctx:fail("In Simple mode, Trips still shows Milestones.", onScreen(ctx))
			end
			if (tr.wrapCard and ctx:visible(tr.wrapCard)) or (tr.wrapChip and ctx:visible(tr.wrapChip)) then
				ctx:fail("In Simple mode, Trips still shows the Wrapped card or chip.", onScreen(ctx))
			end
			if not has(ctx, "Time saved") or not has(ctx, "Your trips") then
				ctx:fail("In Simple mode, Trips does not keep Time saved and Your trips.", onScreen(ctx))
			end
		end,
	}

	-- 3. Gold Rider top level
	Hunt.promise{
		id = "b4trips.gold_level_top_message",
		area = "Trips",
		text = "Once you have 25 or more paid rides, Trips shows 'Gold Rider' and 'the top level. Legend.' instead of asking for more rides to the next level.",
		source = "Wuber/UI/Rider/Trips.lua:432,442-443",
		kind = "scenario",
		when = function(sit) return NOCOMBAT(sit) and sit.session ~= "first" end,
		check = function(ctx)
			local rides = ctx.W.db and ctx.W.db.rides
			if type(rides) ~= "table" then ctx:cannot("no rides table") end
			local have = paidCount(ctx)
			local now = ctx.me.env.time()
			for i = have + 1, 25 do
				rides[#rides + 1] = { dest = "Ratchet", driver = "Real Driver", driverKey = "real driver", price = 5000, at = now - i * 3600, saved = 600 }
			end
			if type(ctx.W.RebuildTotals) == "function" then ctx.W.RebuildTotals() end
			atTrips(ctx, true)
			if not has(ctx, "Gold Rider") then
				ctx:fail("With 25+ rides, Trips does not show Gold Rider.", onScreen(ctx))
			end
			if not findText(ctx, "the top level%. Legend%.") then
				ctx:fail("With 25+ rides, Trips does not say 'the top level. Legend.'.", onScreen(ctx))
			end
			if findText(ctx, "more to ") then
				ctx:fail("With 25+ rides, Trips still asks for more rides to the next level.", onScreen(ctx))
			end
		end,
	}

	-- 4. Rainchecks chip lists active only
	Hunt.promise{
		id = "b4trips.raincheck_chip_lists_active",
		area = "Trips",
		text = "When you hold active, unexpired rainchecks, Trips shows a 'Rainchecks (N)' chip whose tooltip names each driver, the amount covered, and when it expires; expired or used rainchecks are not counted.",
		source = "Wuber/UI/Rider/Trips.lua:552-562,601-620",
		kind = "scenario",
		when = function(sit) return NOCOMBAT(sit) and sit.session ~= "first" end,
		check = function(ctx)
			local R = ctx.W.Raincheck
			if type(R) ~= "table" or type(R.Mine) ~= "function" then ctx:cannot("no W.Raincheck.Mine") end
			local now = ctx.me.env.time()
			ctx.W.db.rainchecks = ctx.W.db.rainchecks or {}
			ctx.W.db.rainchecks["rcactv01"] = { id = "rcactv01", driver = "Kindlock", cover = 50000, expires = now + 5 * 86400, state = "active" }
			ctx.W.db.rainchecks["rcexpr02"] = { id = "rcexpr02", driver = "Oldlock", cover = 50000, expires = now - 60, state = "active" }
			ctx.W.db.rainchecks["rcused03"] = { id = "rcused03", driver = "Usedlock", cover = 50000, expires = now + 5 * 86400, state = "used" }
			local expected = #ctx.W.UI.RaincheckList()
			atTrips(ctx, true)
			local tr = view(ctx)
			if not (tr.rain and ctx:visible(tr.rain)) then
				ctx:fail("You hold an active raincheck and Trips does not show the Rainchecks chip.", onScreen(ctx))
			end
			local label = tr.rain.text and tr.rain.text:GetText() or ""
			if label ~= ("Rainchecks (" .. expected .. ")") then
				ctx:fail(("Trips shows '%s' instead of 'Rainchecks (%d)' (expired or used rainchecks may be counted)."):format(label, expected), onScreen(ctx))
			end
			local tip = hoverTip(ctx, tr.rain)
			if not tip:find("Kindlock", 1, true) or not tip:find("5g", 1, true) then
				ctx:fail("The Rainchecks chip tooltip does not name the active driver and amount covered.", tip)
			end
			if tip:find("Oldlock", 1, true) or tip:find("Usedlock", 1, true) then
				ctx:fail("The Rainchecks chip tooltip still lists an expired or used raincheck.", tip)
			end
		end,
	}

	-- 5. Trip row shows destination, driver, price, and stars
	Hunt.promise{
		id = "b4trips.trip_row_shows_details",
		area = "Trips",
		text = "Each row in Your trips shows the destination, 'with <driver>', the fare paid, and if you rated the ride, that many glowing stars (and no stars when unrated).",
		source = "inferred",
		kind = "scenario",
		when = function(sit) return NOCOMBAT(sit) and sit.session ~= "first" end,
		check = function(ctx)
			local now = ctx.me.env.time()
			ctx.W.db.rides = {
				{ dest = "Booty Bay", driver = "Unratedlock", driverKey = "unratedlock", price = 20000, at = now - 7200, saved = 300 },
				{ dest = "Winterspring", driver = "Fivestarlock", driverKey = "fivestarlock", price = 30000, at = now - 3600, saved = 600, stars = 3 },
			}
			atTrips(ctx, true)
			local tr = view(ctx)
			local r1, r2 = tr.rows and tr.rows[1], tr.rows and tr.rows[2]
			if not (r1 and r1.live and r2 and r2.live) then
				ctx:fail("Trips does not list the two paid rides.", onScreen(ctx))
			end
			if (r1.dest and r1.dest:GetText()) ~= "Winterspring" or not (r1.sub and r1.sub:GetText() or ""):find("with Fivestarlock", 1, true) then
				ctx:fail("The newest trip row does not show its destination and driver.", tostring(r1.dest and r1.dest:GetText()) .. " / " .. tostring(r1.sub and r1.sub:GetText()))
			end
			local gr, gg, gb = ctx.W.Theme.RGB("glow")
			local lit = 0
			for _, st in ipairs(r1.stars or {}) do
				if st:IsShown() then
					local r, g, b = st:GetVertexColor()
					if r and math.abs(r - gr) < 0.05 and math.abs(g - gg) < 0.05 and math.abs(b - gb) < 0.05 then lit = lit + 1 end
				end
			end
			if lit ~= 3 then
				ctx:fail(("A 3-star trip row shows %d glowing stars instead of 3."):format(lit), onScreen(ctx))
			end
			for _, st in ipairs(r2.stars or {}) do
				if st:IsShown() then
					ctx:fail("An unrated trip row still shows star icons.", onScreen(ctx))
				end
			end
		end,
	}

	-- 6. Trip row tooltip
	Hunt.promise{
		id = "b4trips.trip_row_tooltip_details",
		area = "Trips",
		text = "Hovering a trip row shows a tooltip with the destination, the driver, and either how many stars you gave or 'Not rated.'.",
		source = "Wuber/UI/Rider/Trips.lua:199-208",
		kind = "scenario",
		when = function(sit) return NOCOMBAT(sit) and sit.session ~= "first" end,
		check = function(ctx)
			local now = ctx.me.env.time()
			ctx.W.db.rides = {
				{ dest = "Gadgetzan", driver = "Desertlock", driverKey = "desertlock", price = 10000, at = now - 7200, saved = 300 },
				{ dest = "Ratchet", driver = "Portlock", driverKey = "portlock", price = 10000, at = now - 3600, saved = 300, stars = 5 },
			}
			atTrips(ctx, true)
			local tr = view(ctx)
			local tip1 = hoverTip(ctx, tr.rows[1])
			local tip2 = hoverTip(ctx, tr.rows[2])
			if not tip1:find("To Ratchet", 1, true) or not tip1:find("Portlock", 1, true) or not tip1:find("5 stars.", 1, true) then
				ctx:fail("Hovering a rated trip row does not show destination, driver, and star rating.", tip1)
			end
			if not tip2:find("To Gadgetzan", 1, true) or not tip2:find("Desertlock", 1, true) or not tip2:find("Not rated.", 1, true) then
				ctx:fail("Hovering an unrated trip row does not show 'Not rated.'.", tip2)
			end
		end,
	}

	-- 7. Milestone tooltip earned vs locked
	Hunt.promise{
		id = "b4trips.milestone_tooltip_earned_vs_locked",
		area = "Trips",
		text = "Hovering an earned milestone on Trips says 'Earned' plus how to earn it, while hovering a locked milestone says 'How to earn: ...'.",
		source = "Wuber/UI/Rider/Trips.lua:165-174",
		kind = "scenario",
		when = NOCOMBAT,
		check = function(ctx)
			atTrips(ctx)
			setAdvanced(ctx, true)
			ctx:advance(0.4)
			local tr = view(ctx)
			local earnedCell, lockedCell
			for _, cell in ipairs(tr.cells or {}) do
				if cell.m then
					if cell.earned and not earnedCell then earnedCell = cell end
					if not cell.earned and not lockedCell then lockedCell = cell end
				end
			end
			if earnedCell then
				local tip = hoverTip(ctx, earnedCell)
				if not tip:find("Earned", 1, true) then
					ctx:fail("Hovering an earned milestone does not say 'Earned'.", tip)
				end
			end
			if lockedCell then
				local tip = hoverTip(ctx, lockedCell)
				if not tip:find("How to earn:", 1, true) then
					ctx:fail("Hovering a locked milestone does not say 'How to earn:'.", tip)
				end
			end
			if not earnedCell and not lockedCell then ctx:cannot("no milestone cells found") end
		end,
	}

	-- 8. Scroll cue when more below
	Hunt.promise{
		id = "b4trips.scroll_cue_when_more_below",
		area = "Trips",
		text = "When folded Trips is too tall for the window, a 'Scroll for ...' cue appears at the bottom; scrolling to the bottom hides the cue.",
		source = "inferred",
		kind = "scenario",
		needs = { fold = "narrow" },
		when = function(sit) return NOCOMBAT(sit) and sit.session ~= "first" end,
		check = function(ctx)
			local now = ctx.me.env.time()
			ctx.W.db.rides = ctx.W.db.rides or {}
			for i = #ctx.W.db.rides + 1, 15 do
				ctx.W.db.rides[#ctx.W.db.rides + 1] = { dest = "Ratchet", driver = "Scrolllock", driverKey = "scrolllock", price = 10000, at = now - i * 3600, saved = 300 }
			end
			atTrips(ctx, true)
			local tr = view(ctx)
			if not (tr.scrollMax and tr.scrollMax > 5) then ctx:na("Trips fits in the window without scrolling") end
			if not (tr.cue and ctx:visible(tr.cue)) then
				ctx:fail("Folded Trips has content below the fold and does not show the scroll cue.", onScreen(ctx))
			end
			local wheel = tr.clip and tr.clip:GetScript("OnMouseWheel")
			if not wheel then ctx:cannot("Trips clip has no OnMouseWheel") end
			for _ = 1, 30 do wheel(tr.clip, -1) end
			ctx:advance(2)
			if tr.cue and ctx:visible(tr.cue) then
				ctx:fail("After scrolling to the bottom of Trips, the scroll cue is still showing.", onScreen(ctx))
			end
		end,
	}

	-- 9. Wrapped chip cycles past months
	Hunt.promise{
		id = "b4trips.wrapped_chip_cycles_past_months",
		area = "Wrapped",
		text = "In Advanced mode, when no Wrapped card is due and you have rides in multiple past months, left-clicking the Wrapped chip opens the newest past month and right-clicking cycles to the earlier months.",
		source = "Wuber/UI/Rider/Wrapped.lua:212-230",
		kind = "scenario",
		needs = { day = "same" },
		when = function(sit) return NOCOMBAT(sit) and sit.session ~= "first" end,
		check = function(ctx)
			local env = ctx.me.env
			local t = env.date("*t", env.time())
			local m1 = env.time({ year = t.year, month = t.month, day = 1, hour = 12 }) - 5 * 86400
			local m2 = env.time({ year = t.year, month = t.month, day = 1, hour = 12 }) - 40 * 86400
			ctx.W.db.rides = {
				{ dest = "Booty Bay", driver = "Earlierlock", driverKey = "earlierlock", price = 10000, at = m2, saved = 300 },
				{ dest = "Ratchet", driver = "Newerlock", driverKey = "newerlock", price = 10000, at = m1, saved = 300 },
			}
			atTrips(ctx, true)
			setAdvanced(ctx, true)
			ctx:advance(0.4)
			local tr = view(ctx)
			local WR = wrappedMod(ctx)
			if not (tr.wrapChip and ctx:visible(tr.wrapChip)) then
				ctx:fail("With rides in two past months and no card due, Trips does not show the Wrapped chip.", onScreen(ctx))
			end
			ctx.me:clickOn(tr.wrapChip, "LeftButton")
			ctx:advance(0.5)
			if not WR.Shown() then ctx:fail("Left-clicking the Wrapped chip did not open the story.", onScreen(ctx)) end
			local firstKey = WR.Story().key
			WR.Close()
			ctx:advance(0.4)
			ctx.me:clickOn(tr.wrapChip, "RightButton")
			ctx:advance(0.5)
			if not WR.Shown() then ctx:fail("Right-clicking the Wrapped chip did not open the earlier month.", onScreen(ctx)) end
			local secondKey = WR.Story().key
			if secondKey == firstKey then
				ctx:fail(("Right-clicking the Wrapped chip opened %s again instead of cycling to the earlier month."):format(tostring(secondKey)), onScreen(ctx))
			end
		end,
	}

	-- 10. Wrapped story covers Trips cleanly
	Hunt.promise{
		id = "b4trips.wrapped_story_covers_trips_cleanly",
		area = "Wrapped",
		text = "While the Wrapped story is open over Trips, the Trips page underneath is hidden out of sight so numbers do not ghost through, and closing the story brings Trips back.",
		source = "inferred",
		kind = "scenario",
		needs = { day = "next_month" },
		when = function(sit) return NOCOMBAT(sit) and sit.session ~= "first" end,
		check = function(ctx)
			local env = ctx.me.env
			local t = env.date("*t", env.time())
			local at = env.time() - (t.day + 10) * 86400
			ctx.W.db.rides = {
				{ dest = "Ratchet", driver = "Real Driver", driverKey = "real driver", price = 5000, at = at + 3600, saved = 600 },
				{ dest = "Ratchet", driver = "Real Driver", driverKey = "real driver", price = 5000, at = at + 7200, saved = 600 },
				{ dest = "Ratchet", driver = "Real Driver", driverKey = "real driver", price = 5000, at = at + 10800, saved = 600 },
			}
			ctx.W.db.wrapped = ctx.W.db.wrapped or {}
			ctx.W.db.wrapped.seen = nil
			atTrips(ctx, true)
			setAdvanced(ctx, true)
			ctx:advance(0.4)
			local tr = view(ctx)
			local WR = wrappedMod(ctx)
			local target = (tr.wrapCard and ctx:visible(tr.wrapCard)) and tr.wrapCard or tr.wrapChip
			if not target then ctx:cannot("no Wrapped card or chip to open") end
			ctx.me:clickOn(target)
			ctx:advance(0.6)
			if not WR.Shown() then ctx:cannot("Wrapped story did not open") end
			if (tr.clip:GetAlpha() or 1) ~= 0 then
				ctx:fail("While the Wrapped story is open, the Trips page underneath is still visible.", tostring(tr.clip:GetAlpha()))
			end
			WR.Close()
			ctx:advance(0.5)
			if (tr.clip:GetAlpha() or 0) ~= 1 then
				ctx:fail("After closing the Wrapped story, the Trips page underneath did not come back.", tostring(tr.clip:GetAlpha()))
			end
		end,
	}

	-- 11. Unfolded Wrapped month list
	Hunt.promise{
		id = "b4trips.wrapped_unfolded_month_list",
		area = "Wrapped",
		text = "When Trips is unfolded and you open a Wrapped story, the side pane shows 'Your <Month> in short' with clickable rows that jump the story to that slide.",
		source = "Wuber/UI/Rider/Wrapped.lua:393,415",
		kind = "scenario",
		needs = { day = "next_month", fold = "unfolded" },
		when = function(sit) return NOCOMBAT(sit) and sit.session ~= "first" end,
		check = function(ctx)
			local env = ctx.me.env
			local t = env.date("*t", env.time())
			local at = env.time() - (t.day + 10) * 86400
			ctx.W.db.rides = {
				{ dest = "Ratchet", driver = "Real Driver", driverKey = "real driver", price = 5000, at = at + 3600, saved = 600 },
				{ dest = "Ratchet", driver = "Real Driver", driverKey = "real driver", price = 5000, at = at + 7200, saved = 600 },
				{ dest = "Ratchet", driver = "Real Driver", driverKey = "real driver", price = 5000, at = at + 10800, saved = 600 },
			}
			ctx.W.db.wrapped = ctx.W.db.wrapped or {}
			ctx.W.db.wrapped.seen = nil
			atTrips(ctx, true)
			setAdvanced(ctx, true)
			ctx:advance(0.4)
			local tr = view(ctx)
			if not tr.wide then ctx:na("window did not unfold") end
			local WR = wrappedMod(ctx)
			local target = (tr.wrapCard and ctx:visible(tr.wrapCard)) and tr.wrapCard or tr.wrapChip
			if not target then ctx:cannot("no Wrapped card or chip to open") end
			ctx.me:clickOn(target)
			ctx:advance(0.6)
			if not WR.Shown() then ctx:cannot("Wrapped story did not open") end
			local sum = WR.Summary and WR.Summary()
			if not (sum and ctx:visible(sum)) then
				ctx:fail("Unfolded Wrapped does not show the month list in the side pane.", onScreen(ctx))
			end
			if not findText(ctx, "^Your .+ in short$") then
				ctx:fail("Unfolded Wrapped side pane does not show 'Your <Month> in short'.", onScreen(ctx))
			end
			local row3 = sum.rows and sum.rows[3]
			if not (row3 and ctx:visible(row3)) then ctx:cannot("no third row in Wrapped month list") end
			ctx.me:clickOn(row3)
			ctx:advance(0.4)
			if WR.Story().index ~= 3 then
				ctx:fail(("Clicking row 3 in the Wrapped month list left the story on slide %s."):format(tostring(WR.Story().index)), onScreen(ctx))
			end
		end,
	}

	-- 12. Driver-only month has no Share button
	Hunt.promise{
		id = "b4trips.wrapped_driver_only_no_share",
		area = "Wrapped",
		text = "If a past month has only driver rides and zero rider summons, you can still open that month's Wrapped story from the chip, it includes 'Behind the portal', and the summary slide has no Share button.",
		source = "inferred",
		kind = "scenario",
		needs = { day = "next_month", group = "party" },
		when = function(sit) return NOCOMBAT(sit) and sit.session ~= "first" end,
		check = function(ctx)
			local env = ctx.me.env
			local t = env.date("*t", env.time())
			local at = env.time() - (t.day + 10) * 86400
			ctx.W.db.rides = {}
			ctx.W.db.drive = ctx.W.db.drive or {}
			ctx.W.db.drive.log = ctx.W.db.drive.log or {}
			ctx.W.db.drive.log.rides = {
				tostring(at + 3600) .. ",50000,Riderone,Ratchet,trade,50000",
			}
			atTrips(ctx, true)
			setAdvanced(ctx, true)
			ctx:advance(0.4)
			local tr = view(ctx)
			local WR = wrappedMod(ctx)
			if not (tr.wrapChip and ctx:visible(tr.wrapChip)) then
				ctx:fail("With only driver rides last month, Trips does not show the Wrapped chip.", onScreen(ctx))
			end
			ctx.me:clickOn(tr.wrapChip, "LeftButton")
			ctx:advance(0.5)
			if not WR.Shown() then ctx:fail("Clicking the Wrapped chip for a driver-only month did not open the story.", onScreen(ctx)) end
			local st = WR.Story()
			local sawPortal = false
			for i = 1, #st.slides do
				if has(ctx, "Behind the portal") then sawPortal = true end
				if i < #st.slides then WR.Next() ctx:advance(0.3) end
			end
			if not sawPortal then
				ctx:fail("A driver-only month's Wrapped story did not include 'Behind the portal'.", onScreen(ctx))
			end
			if st.share and ctx:visible(st.share) then
				ctx:fail("On a driver-only month's Wrapped summary, the Share button is still shown.", onScreen(ctx))
			end
		end,
	}

	-- 13. Last slide stays open
	Hunt.promise{
		id = "b4trips.wrapped_last_slide_stays_open",
		area = "Wrapped",
		text = "When the Wrapped story reaches its last ('That's a wrap') slide, it stops advancing automatically and stays on screen until you go back or close it.",
		source = "inferred",
		kind = "scenario",
		needs = { day = "next_month" },
		when = function(sit) return NOCOMBAT(sit) and sit.session ~= "first" end,
		check = function(ctx)
			local env = ctx.me.env
			local t = env.date("*t", env.time())
			local at = env.time() - (t.day + 10) * 86400
			ctx.W.db.rides = {
				{ dest = "Ratchet", driver = "Real Driver", driverKey = "real driver", price = 5000, at = at + 3600, saved = 600 },
				{ dest = "Ratchet", driver = "Real Driver", driverKey = "real driver", price = 5000, at = at + 7200, saved = 600 },
				{ dest = "Ratchet", driver = "Real Driver", driverKey = "real driver", price = 5000, at = at + 10800, saved = 600 },
			}
			ctx.W.db.wrapped = ctx.W.db.wrapped or {}
			ctx.W.db.wrapped.seen = nil
			atTrips(ctx, true)
			setAdvanced(ctx, true)
			ctx:advance(0.4)
			local tr = view(ctx)
			local WR = wrappedMod(ctx)
			local target = (tr.wrapCard and ctx:visible(tr.wrapCard)) and tr.wrapCard or tr.wrapChip
			if not target then ctx:cannot("no Wrapped card or chip to open") end
			ctx.me:clickOn(target)
			ctx:advance(0.5)
			if not WR.Shown() then ctx:cannot("Wrapped story did not open") end
			local st = WR.Story()
			for _ = 1, #st.slides - 1 do WR.Next() end
			ctx:advance(0.4)
			if not has(ctx, "That's a wrap") then
				ctx:fail("The last slide of Wrapped does not say 'That's a wrap'.", onScreen(ctx))
			end
			ctx:advance(8)
			if not WR.Shown() or st.index ~= #st.slides then
				ctx:fail("On the last Wrapped slide, waiting 8 seconds closed or left the slide.", onScreen(ctx))
			end
		end,
	}
end
