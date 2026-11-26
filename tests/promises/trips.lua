-- Promises about the Trips tab and Azeroth Wrapped (owner MAPS/FLIGHTS/TRIPS): time saved, rider level, habit chips, milestones,
-- trip history, rain checks, and the monthly Wrapped card and story. Written from what the player is told on the tab and in
-- the tooltips (Trips header: "time saved big, your rider level and the bar to the next, habit chips, the milestones (earned
-- ones glow, locked ones say how to earn them), your trip history"; Done screen: "An unpaid ride isn't saved in Trips";
-- the Wrapped card: "Tap to see your month"; BRIEF round 13 I12 "one number on the whole page").
return function(Hunt)

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
			if tab.name == name and tab.button then
				ctx.me:clickOn(tab.button)
				ctx:advance(0.8)
				ctx:note("click the " .. name .. " tab")
				return s.tab == name
			end
		end
		return false
	end
	-- Settings, Help or the bug report on top of a page: the player clicks a tab to get out of it
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
	-- the player opens Wuber with /wuber, lets the splash end and stands on the Ride tab's Home page
	local function atHome(ctx)
		if not shown(ctx) then
			if ctx.me.player.combat then ctx:na("in combat: the phone does not open") end
			ctx.me:slash("/wuber")
			ctx:note("/wuber")
			ctx:advance(0.3)
			if not shown(ctx) then ctx:cannot("the phone did not open on /wuber") end
			ctx:advance(2.2)
		end
		leaveOverlays(ctx, "Ride")
		local s = ui(ctx)
		if s.tab ~= "Ride" then clickTab(ctx, "Ride") end
		if s.screen ~= "home" then
			pcall(function() ctx.W.UI.Show("ride") end)
			ctx:advance(0.5)
		end
		if ui(ctx).screen ~= "home" then ctx:na("the Ride tab is not on its Home page (" .. tostring(ui(ctx).screen) .. ")") end
	end
	local function unfolded(ctx)
		local F = ctx.W.UI.Fold
		return F and type(F.IsUnfolded) == "function" and F.IsUnfolded() == true
	end
	local function worldMod(ctx)
		local m = ctx:mod("UI.Rider.WorldMap")
		if not (m and m.cache and m.cache.maps) then ctx:cannot("this Wuber has no World view (UI.Rider.WorldMap)") end
		return m
	end
	-- the world view that is on screen now (nil when none)
	local function shownWorld(ctx)
		local m = worldMod(ctx)
		for _, wm in pairs(m.cache.maps) do
			if wm.mode == "world" and wm.view and ctx:visible(wm.view) then return wm end
		end
		return nil
	end
	local function plainTexts(ctx)
		local out = {}
		for _, t in ipairs(ctx:texts()) do out[#out + 1] = (t:gsub("|T.-|t", "")) end
		return out
	end
	local function onScreen(ctx) return "on screen: " .. table.concat(plainTexts(ctx), " | ") end
	local function has(ctx, text)
		for _, t in ipairs(plainTexts(ctx)) do if t == text then return true end end
		return false
	end
	local function is(sit, dial, want)
		local v = sit[dial]
		if v == nil then return true end
		if type(want) == "table" then return want[v] == true end
		return v == want
	end

	local function trips(ctx) return ctx:mod("UI.Rider.Trips") end
	local function view(ctx)
		local m = trips(ctx)
		if not (m and type(m.view) == "function") then ctx:cannot("this Wuber has no Trips tab (UI.Rider.Trips)") end
		return m.view()
	end
	local function wrapped(ctx)
		local m = ctx:mod("UI.Rider.Wrapped")
		if not (m and type(m.Due) == "function") then ctx:cannot("this Wuber has no Wrapped (UI.Rider.Wrapped)") end
		return m
	end

	-- the player has the phone open on the Trips tab (a fresh visit when 'again': Ride tab, then Trips)
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
		if WR and type(WR.Shown) == "function" and WR.Shown() then WR.Close() ctx:note("close the Wrapped story") ctx:advance(0.5) end
		local wasOverlay = overlayOpen(ctx)
		leaveOverlays(ctx, "Trips")
		-- (clicking the Trips tab to leave Settings is itself the visit)
		if again and not wasOverlay and ui(ctx).tab == "Trips" then
			clickTab(ctx, "Ride")
			if ui(ctx).tab == "Trips" then
				-- the click did not leave Trips: say what sits over the Ride tab instead of going on in the same visit
				local over
				for _, tab in ipairs(ui(ctx).tabs or {}) do
					if tab.name == "Ride" and tab.button then
						local r = ctx.H.rect(tab.button)
						local top = r and ctx.me:frameAt(r.l + r.w / 2, r.b + r.h / 2)
						over = top and top.GetName and top:GetName() or tostring(top)
					end
				end
				ctx:na("the Ride tab could not be clicked to leave Trips (on top of it: " .. tostring(over) .. "), so this is not a fresh visit")
			end
		end
		if ui(ctx).tab ~= "Trips" then clickTab(ctx, "Trips") end
		if ui(ctx).tab ~= "Trips" then ctx:cannot("the Trips tab did not open") end
		ctx:advance(2)
		-- the login tip's first-open move can take the phone to Ride during that wait: the player looks at Trips again
		if ui(ctx).tab ~= "Trips" then
			clickTab(ctx, "Trips")
			ctx:advance(2)
			if ui(ctx).tab ~= "Trips" then ctx:cannot("the Trips tab did not stay open") end
		end
		-- 2.4: the What's new card can sit over the page: the player closes it (Got it) before reading the page
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

	local function paidRows(ctx)
		local n = 0
		for _, t in ipairs(ctx.W.db.rides or {}) do
			if type(t) == "table" and not t.unpaid then n = n + 1 end
		end
		return n
	end
	local function firstNumber(s, pat)
		local n = s and s:match(pat)
		return n and tonumber(n) or nil
	end
	local function findText(ctx, pat)
		for _, t in ipairs(plainTexts(ctx)) do
			local a, b, c = t:match(pat)
			if a then return t, a, b, c end
		end
		return nil
	end

	local NOCOMBAT = function(sit) return is(sit, "combat", "no") end

	---------------------------------------------------------------------------------------------------------------
	-- The numbers at the top
	---------------------------------------------------------------------------------------------------------------
	Hunt.promise{
		id = "trips.ride_count_agrees",
		area = "Trips",
		text = "On the Trips tab the rider level is right for your rides (Bronze at 3, Silver at 10, Gold at 25), and the line under your time saved counts the same rides.",
		source = "Trips tab (rider level card, \"N more to Gold\"); BRIEF13 I12 (one number on the whole page)",
		kind = "scenario",
		when = NOCOMBAT,
		check = function(ctx)
			atTrips(ctx)
			local title = findText(ctx, "^(.-) Rider$") or (has(ctx, "New rider") and "New rider")
			local lvl, rides = findText(ctx, "^(%d+) rides? ")
			local sub = findText(ctx, "^%d+ rides? · ")
			local cap = findText(ctx, "^.*(%d+) rides? across")
			if not sub then ctx:na("no rider level line on screen (scrolled out of the page)") end
			rides = tonumber(sub:match("^(%d+)"))
			local want = rides >= 25 and "Gold Rider" or rides >= 10 and "Silver Rider" or rides >= 3 and "Bronze Rider" or "New rider"
			if not has(ctx, want) then
				ctx:fail(("Trips says you have %d rides and your level is not %s."):format(rides, want), onScreen(ctx))
			end
			local need = sub:match("· (%d+) more to")
			local nextAt = rides >= 25 and nil or rides >= 10 and 25 or rides >= 3 and 10 or 3
			if nextAt and need and tonumber(need) ~= nextAt - rides then
				ctx:fail(("Trips says you have %d rides and %s more to the next level, but the next level is at %d rides."):format(rides, need, nextAt), onScreen(ctx))
			end
			local capN = firstNumber(cap, "(%d+) rides? across")
			if capN and capN ~= rides then
				ctx:fail(("Trips counts %d rides in one place and %d in another."):format(rides, capN), onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "trips.time_saved_total",
		area = "Trips",
		text = "The big Time saved number on Trips is the flying time all your paid rides saved you, in hours and minutes.",
		source = "Trips header (time saved big, counting up)",
		kind = "scenario",
		when = NOCOMBAT,
		check = function(ctx)
			atTrips(ctx)
			local saved = ctx.W.Stats and (ctx.W.Stats() or {}).saved
			if type(saved) ~= "number" then ctx:cannot("no saved total") end
			local m = math.floor(saved / 60 + 0.5)
			local h = math.floor(m / 60)
			m = m - h * 60
			local want = h > 0 and (h .. "h " .. m .. "m") or (m .. "m")
			if not has(ctx, want) then
				ctx:fail(("Your rides saved %d seconds of flying and Trips does not show %s as your time saved."):format(saved, want), onScreen(ctx))
			end
		end,
	}

	---------------------------------------------------------------------------------------------------------------
	-- The history
	---------------------------------------------------------------------------------------------------------------
	Hunt.promise{
		id = "trips.history_newest_first",
		area = "Trips",
		text = "Your trip history lists the newest trip first, and the number above it is how many trips are listed.",
		source = "Trips header (your trip history); inferred",
		kind = "scenario",
		when = NOCOMBAT,
		check = function(ctx)
			atTrips(ctx)
			local tr = view(ctx)
			local live, last = 0, nil
			for _, r in ipairs(tr.rows or {}) do
				if r.live and r.trip then
					live = live + 1
					local at = tonumber(r.trip.at)
					if last and at and at > last then
						ctx:fail("Your trips are not listed newest first: an older trip is above a newer one.", ("row %d is later than the row above it"):format(live))
					end
					if at then last = at end
				end
			end
			local label = tr.hCount and tr.hCount:GetText() or ""
			local n = tonumber(label:match("^(%d+) trips?$"))
			if live > 0 and n ~= live then
				ctx:fail(("Trips says '%s' and lists %d trips."):format(label, live), onScreen(ctx))
			end
			if live == 0 and label ~= "" then ctx:fail("Trips lists no trips and the heading still counts some.", label) end
		end,
	}

	Hunt.promise{
		id = "trips.only_paid_listed",
		area = "Trips",
		text = "Trips lists only rides you paid for, and the ride count is the number of those rides: an unpaid ride is not saved in Trips. (job 146: the count is compared only when the trips came through the addon; the Wrapped phone dial writes rides straight into W.db.rides, phone.lua:204-210.)",
		source = "Done screen: \"An unpaid ride isn't saved in Trips.\"",
		kind = "scenario",
		when = NOCOMBAT,
		check = function(ctx)
			atTrips(ctx)
			local tr = view(ctx)
			local unpaid, live = 0, 0
			for _, r in ipairs(tr.rows or {}) do
				if r.live and r.trip then
					live = live + 1
					if r.trip.unpaid then unpaid = unpaid + 1 end
				end
			end
			if unpaid > 0 then
				ctx:fail(("Trips lists %d trips as your rides, and %d of them were never paid for."):format(live, unpaid), onScreen(ctx))
			end
			local stats = ctx.W.Stats and ctx.W.Stats() or {}
			if ctx.sit.phone ~= "wrapped" and live > 0 and live < 100 and type(stats.rides) == "number" and stats.rides ~= live then
				ctx:fail(("Trips lists %d trips and says you have had %d rides."):format(live, stats.rides), onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "trips.paid_ride_listed",
		area = "Trips",
		text = "After you pay for a ride, it is the first trip in your history and your ride count is at least one.",
		source = "Done screen: \"This trip is saved in Trips.\"",
		kind = "scenario",
		needs = { role = "rider" },
		when = function(sit) return is(sit, "ride", { paid = true, ended = true }) and is(sit, "combat", "no") and sit.phone ~= "wrapped" end,
		check = function(ctx)
			local d = ctx.facts.driverName
			if not d then ctx:cannot("the build did not say who the driver is") end
			atTrips(ctx)
			local tr = view(ctx)
			local first = tr.rows and tr.rows[1]
			if not (first and first.live and first.trip) then
				ctx:fail("You paid for a ride and your Trips history is empty.", onScreen(ctx))
			end
			local short = ctx.W.Short and ctx.W.Short(d) or d
			local sub = first.sub and first.sub:GetText() or ""
			if not sub:find(short, 1, true) then
				ctx:fail(("You paid %s for a ride and the first trip in your history is not with him."):format(short), "first row: " .. tostring(first.dest and first.dest:GetText()) .. " / " .. sub)
			end
			local rides = (ctx.W.Stats() or {}).rides or 0
			if rides < 1 then ctx:fail("You paid for a ride and Trips still says you have no rides.", onScreen(ctx)) end
		end,
	}

	---------------------------------------------------------------------------------------------------------------
	-- Habit chips and milestones
	---------------------------------------------------------------------------------------------------------------
	Hunt.promise{
		id = "trips.chips_only_with_data",
		area = "Trips",
		text = "Trips shows a go-to driver chip only once you have ridden with someone twice, a streak chip only for two days in a row, and a spent chip only once you have spent gold.",
		source = "Trips header (habit chips, only those with data)",
		kind = "scenario",
		when = NOCOMBAT,
		check = function(ctx)
			atTrips(ctx)
			local st = ctx.W.Stats and ctx.W.Stats() or {}
			-- the go-to driver: the most rides with one driver, from the saved totals
			local best = 0
			for _, e in pairs((ctx.W.db.totals or {}).drivers or {}) do
				if type(e) == "table" and (tonumber(e.n) or 0) > best then best = tonumber(e.n) end
			end
			local _, name, n = findText(ctx, "^Go%-to: (.+) %((%d+)%)$")
			if n and tonumber(n) < 2 then ctx:fail("Trips shows a go-to driver you have ridden with fewer than twice.", onScreen(ctx)) end
			if not n and best >= 2 then ctx:fail(("You have ridden with one driver %d times and Trips shows no go-to chip."):format(best), onScreen(ctx)) end
			if n and tonumber(n) ~= best then
				ctx:fail(("Trips says your go-to driver took you %s times; your trips say %d."):format(n, best), onScreen(ctx))
			end
			local _, days = findText(ctx, "^(%d+)%-day streak$")
			if days and tonumber(days) < 2 then ctx:fail("Trips shows a ride streak shorter than two days.", onScreen(ctx)) end
			if not days and (tonumber(st.streakDays) or 0) >= 2 then
				ctx:fail(("You have a %d-day ride streak and Trips shows no streak chip."):format(st.streakDays), onScreen(ctx))
			end
			local spent = findText(ctx, "^Spent ")
			local gold = tonumber(st.spent) or 0
			if spent and gold <= 0 then ctx:fail("Trips says you spent gold on summons but you have spent none.", onScreen(ctx)) end
			if not spent and gold > 0 then ctx:fail("You have paid for summons and Trips shows no Spent chip.", onScreen(ctx)) end
		end,
	}

	Hunt.promise{
		id = "trips.milestones_earned",
		area = "Trips",
		text = "Every milestone you have met is shown as earned, and the counter says how many you have earned out of how many there are.",
		source = "Trips header (earned milestones glow, locked ones are dimmed); Core.Stats milestone list",
		kind = "scenario",
		when = NOCOMBAT,
		check = function(ctx)
			atTrips(ctx)
			local W = ctx.W
			local tr = view(ctx)
			local stats = W.Stats and W.Stats() or {}
			local earnedDb = W.db.milestones or {}
			local met, shownEarned, total = {}, 0, 0
			for _, cell in ipairs(tr.cells or {}) do
				if cell.m then
					total = total + 1
					if cell.earned then shownEarned = shownEarned + 1 end
				end
			end
			for _, m in ipairs(W.MILESTONES or {}) do
				local ok, yes = pcall(m.test, stats)
				if ok and yes and not (earnedDb[m.id]) then
					ctx:fail(("You have met '%s' (%s) and Trips shows it as locked."):format(tostring(m.name), tostring(m.desc)), onScreen(ctx))
				end
			end
			local _, got, of = findText(ctx, "^%((%d+) of (%d+)%)$")
			if got and (tonumber(got) ~= shownEarned or tonumber(of) ~= total) then
				ctx:fail(("Trips says you earned %s of %s milestones, but %d of %d glow."):format(got, of, shownEarned, total), onScreen(ctx))
			end
		end,
	}

	---------------------------------------------------------------------------------------------------------------
	-- Azeroth Wrapped
	---------------------------------------------------------------------------------------------------------------
	-- the player has had three rides last month (what riding gives); the card has not been seen
	local function lastMonthRides(ctx, n)
		local env = ctx.me.env
		local t = env.date("*t", env.time())
		local at = env.time() - (t.day + 10) * 86400
		local rides = ctx.W.db.rides
		local have = 0
		for _, r in ipairs(rides) do
			local rt = tonumber(r.at)
			if rt and not r.unpaid and env.date("%Y-%m", rt) == env.date("%Y-%m", at) then have = have + 1 end
		end
		for i = have + 1, n do
			rides[#rides + 1] = { dest = "Ratchet", driver = "Real Driver", driverKey = "real driver", price = 5000, at = at + i * 3600, stars = 4, saved = 600 }
		end
		ctx.W.db.wrapped = ctx.W.db.wrapped or {}
		ctx.W.db.wrapped.seen = nil
		ctx:note("three paid rides last month are in the trip history, the card not yet seen")
		return env.date("%Y-%m", at)
	end

	local function cardShown(ctx)
		local tr = view(ctx)
		return tr.wrapCard and ctx:visible(tr.wrapCard) and true or false, tr
	end

	Hunt.promise{
		id = "trips.wrapped_card_due",
		area = "Wrapped",
		gap = "the fake game hit-tests a frame inside a clipping scroll area even where the clip hides it; the check ignores such a hit (a milestone medal under the card in the wide Trips pane)",
		text = "In the first ten days of a month, with three or more rides last month, the first time you open Trips shows the Wrapped card, and clicking it plays your month.",
		source = "Wrapped header (first 10 days, 3+ rides, once); card text \"Tap to see your month\"",
		kind = "scenario",
		needs = { day = "next_month" },
		when = function(sit) return NOCOMBAT(sit) and sit.session ~= "first" end,
		check = function(ctx)
			local WR = wrapped(ctx)
			lastMonthRides(ctx, 3)
			atTrips(ctx, true)
			local on, tr = cardShown(ctx)
			if not on then ctx:fail("It is the 2nd of the month, you had 3 rides last month, you open Trips and no Wrapped card is there.", onScreen(ctx)) end
			local r = ctx.H.rect(tr.wrapCard)
			local px, py = r and (r.l + r.w / 2), r and (r.b + r.h / 2)
			local top = r and ctx.me:frameAt(px, py) or nil
			-- the fake game hit-tests a frame inside a scrolling clip even where the clip hides it; the game does not
			-- (a clipped part takes no click). A frame the point is clipped away from is not on top of the card.
			local function clippedAway(f)
				local a, n = f, 0
				while a and n < 20 do
					local ar = ctx.H.rect(a)
					if ar and (px < ar.l or px > ar.l + ar.w or py < ar.b or py > ar.b + ar.h) then return true end
					local ok, p = pcall(a.GetParent, a)
					if not ok then return false end
					a, n = p, n + 1
				end
				return false
			end
			if top and top ~= tr.wrapCard and clippedAway(top) then
				ctx.me:click(tr.wrapCard)
			else
				ctx.me:clickOn(tr.wrapCard)
			end
			ctx:note("click the Wrapped card")
			ctx:advance(1)
			if not WR.Shown() then
				ctx:fail("You click your Wrapped card on Trips and your month does not play.",
					(top == tr.wrapCard and "the click reached the card" or "another frame sits on top of the middle of the card (a milestone medal?)") .. "; " .. onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "trips.wrapped_once",
		area = "Wrapped",
		text = "Once you have opened your month's Wrapped card it does not come back by itself that month: Trips offers the small Wrapped chip instead.",
		source = "Wrapped header (the card once; afterwards the chip)",
		kind = "scenario",
		needs = { day = "next_month" },
		when = function(sit) return NOCOMBAT(sit) and sit.session ~= "first" end,
		check = function(ctx)
			local WR = wrapped(ctx)
			lastMonthRides(ctx, 3)
			atTrips(ctx, true)
			local on, tr = cardShown(ctx)
			if not on then ctx:na("no card was offered (trips.wrapped_card_due says so)") end
			WR.Open(tr.wrapCard.year, tr.wrapCard.month)
			ctx:advance(1)
			WR.Close()
			ctx:note("watch and close the Wrapped story")
			ctx:advance(1)
			atTrips(ctx, true)
			local again, tr2 = cardShown(ctx)
			if again then ctx:fail("You watched this month's Wrapped, came back to Trips later and the same card is offered again.", onScreen(ctx)) end
			if not (tr2.wrapChip and ctx:visible(tr2.wrapChip)) then
				ctx:fail("You watched this month's Wrapped and Trips offers no way to see it again.", onScreen(ctx))
			end
		end,
	}

	-- opens last month's story the way a player does (the card, else the chip)
	local function openStory(ctx)
		local WR = wrapped(ctx)
		atTrips(ctx)
		local tr = view(ctx)
		local target = (tr.wrapCard and ctx:visible(tr.wrapCard)) and tr.wrapCard or (tr.wrapChip and ctx:visible(tr.wrapChip) and tr.wrapChip) or nil
		if not target then ctx:na("neither the Wrapped card nor the chip is on Trips") end
		pcall(function() ctx.me:click(target) end)
		ctx:note("click the Wrapped " .. (target == tr.wrapCard and "card" or "chip"))
		ctx:advance(1)
		if not WR.Shown() then ctx:cannot("the story did not play (trips.wrapped_card_due says so)") end
		return WR, WR.Story()
	end

	Hunt.promise{
		id = "trips.wrapped_story_moves",
		area = "Wrapped",
		text = "Your Wrapped story moves to the next slide by itself after about six seconds, tapping the right half goes forward, the left half goes back, and the close button returns you to Trips.",
		source = "Wrapped header (tap or 6 s, paused on hover)",
		kind = "scenario",
		needs = { day = "next_month" },
		when = function(sit) return NOCOMBAT(sit) and sit.session ~= "first" end,
		check = function(ctx)
			lastMonthRides(ctx, 3)
			atTrips(ctx, true)
			local WR, st = openStory(ctx)
			if #st.slides < 5 then ctx:fail("Your Wrapped story has fewer than five slides.", #st.slides .. " slides") end
			local first = st.index
			ctx:advance(6.6)
			if st.index ~= first + 1 then
				ctx:fail("You watch your Wrapped story and it does not move on by itself after six seconds.", "slide " .. first .. " then " .. tostring(st.index))
			end
			WR.Next()
			local after = st.index
			WR.Prev()
			if st.index ~= after - 1 then ctx:fail("In your Wrapped story going back does not go back a slide.", "slide " .. after .. " then " .. tostring(st.index)) end
			WR.Close()
			ctx:advance(1)
			if WR.Shown() then ctx:fail("You close your Wrapped story and it is still there.", onScreen(ctx)) end
			if not has(ctx, "Your trips") then ctx:fail("You close your Wrapped story and you are not back on your trips.", onScreen(ctx)) end
		end,
	}

	Hunt.promise{
		id = "trips.wrapped_counts",
		area = "Wrapped",
		text = "The first Wrapped slide says how many summons you had last month, the number of rides you paid for in that month.",
		source = "Wrapped header (\"Your October in Azeroth\", the month's summons)",
		kind = "scenario",
		needs = { day = "next_month" },
		when = function(sit) return NOCOMBAT(sit) and sit.session ~= "first" end,
		check = function(ctx)
			local month = lastMonthRides(ctx, 3)
			atTrips(ctx, true)
			local WR, st = openStory(ctx)
			local env = ctx.me.env
			local n = 0
			for _, r in ipairs(ctx.W.db.rides) do
				local at = tonumber(r.at)
				if at and not r.unpaid and env.date("%Y-%m", at) == month then n = n + 1 end
			end
			local want = n .. (n == 1 and " summon" or " summons")
			if not has(ctx, want) then
				ctx:fail(("You paid for %d rides last month and your Wrapped does not say %s."):format(n, want), onScreen(ctx))
			end
		end,
	}
end
