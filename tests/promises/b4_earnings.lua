-- Bug hunt promises for Earnings (ranges, heat map, tips, and shift views).
return function(Hunt)
	local function strip(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")) end
	local function find(ctx, pat) for _, t in ipairs(ctx:texts()) do local p = strip(t) if p:find(pat) then return p, t end end return nil end
	local function logOf(ctx) local d = ctx.W.db and ctx.W.db.drive return d and d.log end
	local function env(ctx) return ctx.me.env end
	local function isDriver(sit) return sit.role == "warlock" or sit.role == "friend" or sit.role == "crew" end

	local function earningsScreen(ctx)
		local S = ctx:mod("UI.Driver.Screens")
		local e = S and S.st and S.st.screens and S.st.screens.earnings
		if not (e and e.seg and e.per) then ctx:cannot("the Earnings screen is not built") end
		if not find(ctx, "^Earnings$") then ctx:cannot("the Earnings screen is not up") end
		return e
	end

	local function dismissWhatsNew(ctx)
		if find(ctx, "What's new in Wuber") then
			pcall(function() ctx.me:clickText("Got it") end)
			ctx:advance(0.5)
		end
	end

	local function setAdvanced(ctx, want)
		local isAdv = type(ctx.W.Advanced) == "function" and ctx.W.Advanced() == true
		if isAdv ~= want then
			ctx.me:slash("/wuber advanced")
			ctx:advance(0.5)
			ctx:note("toggle /wuber advanced to " .. tostring(want))
		end
		local nowAdv = type(ctx.W.Advanced) == "function" and ctx.W.Advanced() == true
		if nowAdv ~= want then ctx:cannot("could not switch Advanced mode to " .. tostring(want)) end
	end

	local function scrollBottom(ctx, e)
		if e and e.scroll and e.scroll.ScrollTo then
			pcall(e.scroll.ScrollTo, e.scroll, e.scroll.max or 0, true)
			ctx:advance(0.5)
		end
	end

	local function scrollToHeatmap(ctx, e)
		if e and e.scroll and e.scroll.ScrollTo and e.dash and not (e.heatW and ctx:visible(e.heatW)) then
			local dashH = (e.dash.GetHeight and e.dash:GetHeight()) or 260
			pcall(e.scroll.ScrollTo, e.scroll, math.min(e.scroll.max or 0, math.max(0, dashH - 40)), true)
			ctx:advance(0.3)
		end
	end

	local function activeHeat(ctx, e)
		if e.heatW and ctx:visible(e.heatW) then return e.heatW end
		if e.heat and ctx:visible(e.heat) then return e.heat end
		return nil
	end

	local function hourKey(ctx, t) return env(ctx).date("%Y%m%d%H", t) end

	local function squareAt(ctx, heat, t)
		local wd, hr = tonumber(env(ctx).date("%w", t)), tonumber(env(ctx).date("%H", t))
		for _, b in ipairs(heat.cells or {}) do
			if b.wday == wd and b.hour == hr then return b end
		end
		ctx:cannot("no heatmap square for that hour")
	end

	local function amounts(text)
		local t = tostring(text or "")
		t = t:gsub("(%d+)|TInterface\\MoneyFrame\\UI%-(%a+)Icon[^|]*|t", function(n, k) return n .. k:sub(1, 1):lower() end)
		t = strip(t)
		local out, pos = {}, 1
		while true do
			local s1, e1, n1, u1 = t:find("(%d+)([gsc])%f[%A]", pos)
			if not s1 then break end
			local sum, cur = 0, e1
			local mult = { g = 10000, s = 100, c = 1 }
			sum = sum + tonumber(n1) * mult[u1]
			while true do
				local s2, e2, n2, u2 = t:find("^%s?(%d+)([gsc])%f[%A]", cur + 1)
				if not s2 then break end
				sum = sum + tonumber(n2) * mult[u2]
				cur = e2
			end
			out[#out + 1] = sum
			pos = cur + 1
		end
		return out
	end

	Hunt.promise{
		id = "b4earnings.simple_mode_hides_extras",
		area = "Earnings",
		text = "In Simple mode, Earnings shows your per-hour rate and totals, and hides the 24-hour chart, the Best hours grid, the target slider and Reset stats.",
		source = "docs/PLAYER-GUIDE.md:75-78",
		kind = "scenario",
		needs = { phone = "drive_earnings" },
		when = function(sit) return isDriver(sit) end,
		check = function(ctx)
			local e = earningsScreen(ctx)
			dismissWhatsNew(ctx)
			setAdvanced(ctx, false)
			if not find(ctx, "^%d+ rides? ") then
				ctx:fail("In Simple mode, Earnings does not show the totals line.")
			end
			if find(ctx, "Gold an hour, by time of day") then
				ctx:fail("In Simple mode, Earnings still shows the 24-hour chart.")
			end
			if find(ctx, "Best hours, last") then
				ctx:fail("In Simple mode, Earnings still shows the Best hours grid.")
			end
			if find(ctx, "My target per hour") then
				ctx:fail("In Simple mode, Earnings still shows the target slider.")
			end
			if find(ctx, "Reset stats") then
				ctx:fail("In Simple mode, Earnings still shows Reset stats.")
			end
			if activeHeat(ctx, e) then
				ctx:fail("In Simple mode, the Best hours heatmap is still visible.")
			end
		end,
	}

	Hunt.promise{
		id = "b4earnings.advanced_mode_shows_extras",
		area = "Earnings",
		text = "In Advanced mode, Earnings shows the 24-hour chart, the Best hours grid, My target per hour and Reset stats.",
		source = "docs/PLAYER-GUIDE.md:77",
		kind = "scenario",
		needs = { phone = "drive_earnings" },
		when = function(sit) return isDriver(sit) end,
		check = function(ctx)
			local e = earningsScreen(ctx)
			dismissWhatsNew(ctx)
			setAdvanced(ctx, true)
			if not find(ctx, "Gold an hour, by time of day") then
				ctx:fail("In Advanced mode, Earnings does not show the 24-hour chart.")
			end
			if not find(ctx, "Best hours, last") or not activeHeat(ctx, e) then
				ctx:fail("In Advanced mode, Earnings does not show the Best hours grid.")
			end
			scrollBottom(ctx, e)
			if not find(ctx, "My target per hour") then
				ctx:fail("In Advanced mode, Earnings does not show My target per hour.")
			end
			if not find(ctx, "Reset stats") then
				ctx:fail("In Advanced mode, Earnings does not show Reset stats.")
			end
		end,
	}

	Hunt.promise{
		id = "b4earnings.heatmap_days_follow_range",
		area = "Earnings",
		text = "In Advanced mode, switching Earnings between Today, 7 days and 30 days updates the Best hours heading to last 7 days for Today and 7 days, and last 30 days for 30 days.",
		source = "Wuber/UI/Driver/Earnings.lua:853,1227",
		kind = "scenario",
		needs = { phone = "drive_earnings" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			local e = earningsScreen(ctx)
			dismissWhatsNew(ctx)
			setAdvanced(ctx, true)
			for _, step in ipairs({ { 3, "30 days", "Best hours, last 30 days" }, { 2, "7 days", "Best hours, last 7 days" }, { 1, "Today", "Best hours, last 7 days" } }) do
				ctx.me:clickOn(e.seg.buttons[step[1]])
				ctx:note("click " .. step[2])
				ctx:advance(0.5)
				if not find(ctx, step[3]) then
					ctx:fail(("You switch Earnings to %s and the Best hours heading does not say %q."):format(step[2], step[3]))
				end
			end
		end,
	}

	Hunt.promise{
		id = "b4earnings.heatmap_empty_note",
		area = "Earnings",
		text = "In Advanced mode with no open hours or buyer asks logged, the Best hours grid shows 'Open for a few hours and your best times light up here.' and hides 'Tap a square for its numbers.'.",
		source = "Wuber/UI/Driver/Earnings.lua:1137,1157",
		kind = "scenario",
		needs = { phone = "drive_earnings" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			local e = earningsScreen(ctx)
			dismissWhatsNew(ctx)
			setAdvanced(ctx, true)
			local heat = activeHeat(ctx, e)
			if not heat then ctx:cannot("no Best hours heatmap visible") end
			if heat.grid ~= nil then ctx:na("this saved data already has logged hours or asks") end
			if not find(ctx, "Open for a few hours and your best times light up here%.") then
				ctx:fail("With no hours logged, the Best hours grid does not show its empty-state note.")
			end
			if find(ctx, "Tap a square for its numbers%.") then
				ctx:fail("With no hours logged, the Best hours grid still shows 'Tap a square for its numbers.'.")
			end
		end,
	}

	Hunt.promise{
		id = "b4earnings.heatmap_tap_shows_pill",
		area = "Earnings",
		text = "In Advanced mode when hours are logged, tapping a square on the Best hours grid shows that weekday and hour's numbers (or 'nothing yet') underneath.",
		source = "Wuber/UI/Driver/Earnings.lua:988",
		kind = "scenario",
		needs = { phone = "drive_earnings" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			local e = earningsScreen(ctx)
			dismissWhatsNew(ctx)
			setAdvanced(ctx, true)
			local l = logOf(ctx)
			if not l then ctx:cannot("no earnings log") end
			local t = env(ctx).time()
			l.open[hourKey(ctx, t)] = 60
			table.insert(l.rides, t .. ",50000,Heat Rider,Ratchet,t,50000")
			ctx:note("log 60 open minutes and a 5g ride for this hour")
			if type(e.update) == "function" then e.update() end
			ctx:advance(0.5)
			local heat = activeHeat(ctx, e)
			if not heat then ctx:cannot("no Best hours heatmap visible") end
			scrollToHeatmap(ctx, e)
			local b = squareAt(ctx, heat, t)
			ctx.me:clickOn(b)
			ctx:note("tap this hour's heatmap square")
			ctx:advance(0.3)
			local when = env(ctx).date("%a %H:00", t)
			local line = find(ctx, when)
			if not line then
				ctx:fail("You tap a logged square on the Best hours grid and no pill shows " .. when .. ".")
			end
			if not line:find("/h") or not line:find("ride") then
				ctx:fail("You tap a logged square on the Best hours grid and its pill is missing rate or rides: " .. line)
			end
			local emptyCell
			for _, c in ipairs(heat.cells or {}) do
				local cellData = heat.grid and heat.grid[c.wday] and heat.grid[c.wday][c.hour]
				if not cellData or (cellData.open <= 0 and cellData.rides <= 0 and cellData.asks <= 0) then
					emptyCell = c
					break
				end
			end
			if emptyCell then
				ctx.me:clickOn(emptyCell)
				ctx:note("tap an empty heatmap square")
				ctx:advance(0.3)
				if not find(ctx, "nothing yet") then
					ctx:fail("You tap an empty square on the Best hours grid and it does not say 'nothing yet'.")
				end
			end
		end,
	}

	Hunt.promise{
		id = "b4earnings.heatmap_tap_survives_fold",
		area = "Earnings",
		text = "In Advanced mode, tapping a square on the Best hours grid and then unfolding or folding the window keeps the same weekday and hour selected.",
		source = "inferred",
		kind = "scenario",
		needs = { phone = "drive_earnings", combat = "no" },
		when = function(sit) return sit.role == "warlock" and sit.fold ~= "narrow" end,
		check = function(ctx)
			local e = earningsScreen(ctx)
			dismissWhatsNew(ctx)
			setAdvanced(ctx, true)
			local Fold = ctx.W.UI and ctx.W.UI.Fold
			if not (Fold and Fold.Fits and Fold.Toggle) then ctx:cannot("UI.Fold not available") end
			local fits = Fold.Fits()
			if not fits then ctx:na("screen too narrow to unfold") end
			local l = logOf(ctx)
			if not l then ctx:cannot("no earnings log") end
			local t = env(ctx).time()
			l.open[hourKey(ctx, t)] = 60
			table.insert(l.rides, t .. ",50000,Fold Rider,Ratchet,t,50000")
			if type(e.update) == "function" then e.update() end
			ctx:advance(0.5)
			local heat = activeHeat(ctx, e)
			if not heat then ctx:cannot("no Best hours heatmap visible") end
			scrollToHeatmap(ctx, e)
			local b = squareAt(ctx, heat, t)
			ctx.me:clickOn(b)
			ctx:advance(0.3)
			local when = env(ctx).date("%a %H:00", t)
			if not find(ctx, when) then ctx:cannot("selected hour pill did not show before fold") end
			Fold.Toggle()
			ctx:note("toggle fold on Earnings")
			ctx:advance(0.5)
			if not find(ctx, when) then
				ctx:fail("You tap a Best hours square (" .. when .. "), fold or unfold the window, and the selected hour is lost.")
			end
		end,
	}

	Hunt.promise{
		id = "b4earnings.top_window_shown",
		area = "Earnings",
		text = "In Advanced mode, once you have logged at least an hour open across three consecutive hours with gold earned, Earnings shows a Top window tip naming the best three-hour span.",
		source = "Wuber/UI/Driver/Earnings.lua:714",
		kind = "scenario",
		needs = { phone = "drive_earnings" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			local e = earningsScreen(ctx)
			dismissWhatsNew(ctx)
			setAdvanced(ctx, true)
			local l = logOf(ctx)
			if not l then ctx:cannot("no earnings log") end
			local t = env(ctx).time()
			l.open[hourKey(ctx, t)] = 40
			l.open[hourKey(ctx, t - 3600)] = 40
			table.insert(l.rides, t .. ",50000,Window Rider,Ratchet,t,50000")
			ctx:note("log 80 open minutes across two consecutive hours with a 5g ride")
			if type(e.update) == "function" then e.update() end
			ctx:advance(0.5)
			if not find(ctx, "Top window: %d%d:00") then
				ctx:fail("You logged over an hour open with gold earned and Earnings does not show a Top window tip.")
			end
		end,
	}

	Hunt.promise{
		id = "b4earnings.try_this_hour_when_closed_asks",
		area = "Earnings",
		text = "In Advanced mode, when riders asked for summons in an hour while you were closed, Earnings shows a 'Try <Day> <HH>:00' tip.",
		source = "Wuber/UI/Driver/Earnings.lua:716",
		kind = "scenario",
		needs = { phone = "drive_earnings" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			local e = earningsScreen(ctx)
			dismissWhatsNew(ctx)
			setAdvanced(ctx, true)
			local l = logOf(ctx)
			if not l then ctx:cannot("no earnings log") end
			-- pick an hour 5 hours ago where we have no open minutes
			local t = env(ctx).time() - 5 * 3600
			if (l.open[hourKey(ctx, t)] or 0) > 0 then ctx:na("that hour already had open minutes") end
			table.insert(l.asks, t .. ",nomatch,Closed Ask,wtb summon")
			table.insert(l.asks, (t + 60) .. ",nomatch,Closed Ask 2,wtb summon")
			ctx:note("log 2 buyer asks in a closed hour")
			if type(e.update) == "function" then e.update() end
			ctx:advance(0.5)
			if not find(ctx, "^Try %a+ %d%d:00$") then
				ctx:fail("Buyers asked while you were closed and Earnings does not show a 'Try <Day> <HH>:00' tip.")
			end
		end,
	}

	Hunt.promise{
		id = "b4earnings.target_slider_updates_subtext",
		area = "Earnings",
		text = "In Advanced mode, moving My target per hour changes the target shown on the chart and under your per-hour figure, and says 'above your <X> target' when your rate beats it.",
		source = "Wuber/UI/Driver/Earnings.lua:769",
		kind = "scenario",
		needs = { phone = "drive_earnings" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			local e = earningsScreen(ctx)
			dismissWhatsNew(ctx)
			setAdvanced(ctx, true)
			local l = logOf(ctx)
			if not l then ctx:cannot("no earnings log") end
			local t = env(ctx).time()
			local d = env(ctx).date("*t", t)
			local mid = t - (d.hour * 3600 + d.min * 60 + d.sec)
			local tot = ctx.W.Drive.LogTotals(mid, "me") or {}
			local existingOpen = tonumber(tot.open) or 0
			local existingCopper = tonumber(tot.copper) or 0
			local needCopper = math.max(200000, math.ceil((existingOpen + 60) / 60 * 250000) - existingCopper)
			l.open[hourKey(ctx, t)] = (l.open[hourKey(ctx, t)] or 0) + 60
			table.insert(l.rides, t .. "," .. needCopper .. ",Target Rider,Ratchet,t," .. needCopper)
			ctx:note("log 60 open minutes and " .. math.floor(needCopper / 10000) .. "g earned today")
			if type(e.update) == "function" then e.update() end
			ctx:advance(0.5)
			if not (e.target and e.target.SetValue) then ctx:cannot("no target slider") end
			e.target:SetValue(100000) -- 10g
			ctx:advance(0.3)
			if not find(ctx, "above your 10g target") then
				ctx:fail("Your rate is at least 20g/h with target 10g, and the subtext does not say 'above your 10g target'.")
			end
			if not find(ctx, "target 10g") then
				ctx:fail("You set target to 10g and the chart label does not say 'target 10g'.")
			end
			e.target:SetValue(500000) -- 50g
			ctx:advance(0.3)
			if find(ctx, "above your") then
				ctx:fail("You raised your target above your rate (to 50g) and the subtext still says 'above your ... target'.")
			end
			if not find(ctx, "target 50g") then
				ctx:fail("You set target to 50g and the chart label does not say 'target 50g'.")
			end
		end,
	}

	Hunt.promise{
		id = "b4earnings.reset_stats_undo_restores",
		area = "Earnings",
		text = "In Advanced mode, clicking Reset stats twice shows an Undo toast, and clicking Undo restores your session rides and gold.",
		source = "docs/PLAYER-GUIDE.md:106",
		kind = "scenario",
		needs = { phone = "drive_earnings", ride = "paid" },
		when = function(sit) return sit.role == "warlock" end,
		check = function(ctx)
			local e = earningsScreen(ctx)
			dismissWhatsNew(ctx)
			setAdvanced(ctx, true)
			local function sessionStats()
				local before = #ctx.me.chatLines
				ctx.me:slash("/wuber drive stats")
				for i = before + 1, #ctx.me.chatLines do
					local line = strip(ctx.me.chatLines[i])
					local r, rest = line:match("This session: (%d+) rides?, (.*)%.$")
					if r then return tonumber(r), amounts(rest)[1] or 0 end
				end
				return nil, nil
			end
			local s0, c0 = sessionStats()
			if not s0 or s0 < 1 then ctx:na("no paid ride counted in this session") end
			scrollBottom(ctx, e)
			ctx.me:clickText("Reset stats")
			ctx:advance(0.3)
			if not find(ctx, "Click again to reset") then ctx:cannot("first Reset stats click did not arm") end
			ctx.me:clickText("Click again to reset")
			ctx:advance(0.4)
			if not find(ctx, "^Undo$") then
				ctx:fail("You click Reset stats twice and no Undo button appears on the toast.")
			end
			ctx.me:clickText("^Undo$", { pattern = true })
			ctx:note("click Undo on the toast")
			ctx:advance(0.4)
			local s1, c1 = sessionStats()
			if s1 ~= s0 or c1 ~= c0 then
				ctx:fail(("You click Undo after resetting stats and session stats are %s rides / %s instead of %d rides / %s."):format(
					tostring(s1), ctx.W.Money(c1 or 0), s0, ctx.W.Money(c0 or 0)))
			end
		end,
	}

	Hunt.promise{
		id = "b4earnings.fair_split_shows_crew",
		area = "Earnings",
		text = "In Advanced mode with a crew and casts or clicks this shift, Earnings shows a 'Fair split, this shift' card listing 'You' and your crew members.",
		source = "Wuber/UI/Driver/Earnings.lua:444-470",
		kind = "scenario",
		needs = { phone = "drive_earnings", ride = "paid" },
		when = function(sit) return sit.role == "friend" or sit.role == "crew" end,
		check = function(ctx)
			local e = earningsScreen(ctx)
			dismissWhatsNew(ctx)
			setAdvanced(ctx, true)
			local crew = ctx.W.Drive.Crew() or {}
			if #crew < 2 then ctx:na("need at least 2 crew members for Fair split") end
			local rows = ctx.W.Driver.CutRows() or {}
			if #rows == 0 then ctx:na("no casts or clicks recorded in this shift yet") end
			scrollBottom(ctx, e)
			if not find(ctx, "Fair split, this shift") then
				ctx:fail("In Advanced mode with a crew, Earnings does not show the 'Fair split, this shift' card.")
			end
			if not find(ctx, "^You$") then
				ctx:fail("On the 'Fair split, this shift' card, 'You' is not listed.")
			end
		end,
	}
end
