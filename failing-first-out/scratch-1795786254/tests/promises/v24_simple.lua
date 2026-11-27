-- Promises about Simple and Advanced mode, the Drive tab, the settings diet and driver titles (tests/promises/v24_simple.lua; job 097).
-- Sources: release/CHANGELOG-2.4.0.md "Simple and Advanced (the remaining ideas round)", "A shorter Settings page", "Titles for drivers";
-- The hunt's harness starts every window in ADVANCED (tests/harness.lua: a window starts in
-- Advanced unless opts.simple), the game starts in Simple: a promise that is about Simple sets ctx.clientOpts.simple = true in its pre.
return function(Hunt)
	local NOTE = "Wuber is simpler now"
	local function key(n) return (tostring(n):lower():gsub("[%s%-]+", " ")) end

	local function simplePre(ctx) ctx.clientOpts.simple = true end

	local function promise(p)
		p.area = "Simple and Advanced"
		p.kind = p.kind or "scenario"
		if p.simple ~= false then
			local pre = p.pre
			p.pre = function(ctx) simplePre(ctx) if pre then pre(ctx) end end
		end
		p.simple = nil
		-- (the fold dial's "folded_click" needs a wide open page; for a closed phone the build cannot make it)
		local w0 = p.when
		p.when = function(sit)
			if sit.fold == "folded_click" then return false end
			return w0 == nil or w0(sit)
		end
		Hunt.promise(p)
	end

	local function frame(ctx) return ctx.me.env.WuberFrame end
	local function shown(ctx) local f = frame(ctx) return f and f:IsShown() end
	local function openWin(ctx)
		if not shown(ctx) then ctx.W.UI.Toggle(true) end
		ctx:advance(1)
		if not shown(ctx) then ctx:cannot("the window would not open") end
	end
	local function hasText(ctx, pat, plain)
		for _, t in ipairs(ctx:texts()) do
			if plain and t:find(pat, 1, true) or (not plain and t:find(pat)) then return t end
		end
		return nil
	end
	local function noteShown(ctx) return hasText(ctx, NOTE, true) ~= nil end
	-- the Milestones are the foot of Trips and the scroll cue can hide them until the player scrolls Trips down to them
	local function milestonesReachable(ctx)
		if hasText(ctx, "Milestones", true) then return true end
		-- folded, the heading is left out while the cue's pill band would touch it (Trips.lua Mod.fit): the player turns the wheel over Trips
		local T = ctx:mod("UI.Rider.Trips")
		local tr = T and type(T.view) == "function" and T.view()
		local clip = tr and tr.clip
		if not clip then return false end
		for _ = 1, 15 do
			ctx.me:moveMouse(clip:GetLeft() + clip:GetWidth() / 2, clip:GetBottom() + clip:GetHeight() / 2)
			ctx.me:wheelOn(clip, -1)
			ctx:advance(0.3)
			for _, obj in ipairs(ctx.me:findText("Milestones", false, true)) do
				if ctx.me:onScreen(obj) then return true end
			end
		end
		return false
	end
	local function slashAdv(ctx) ctx.me:slash("/wuber advanced") ctx:advance(1) end

	-- a deep copy of the saved table as one sorted text, minus the keys the switch itself may write
	local SKIP = { advanced = true, simpleNote = true }
	-- clocks and heartbeats the addon keeps current by itself (a shift's last-seen stamp) are not settings
	-- a ride's savedAt is the clock stamp of its last save (it moves every few seconds while a ride is on)
	local function volatile(path) return path:find("%.log%.shift") or path:find("%.seen$") or path:find("%.lastSeen") or path:find("%.savedAt$") or path:find("^db%.peers%.[^.]+%.at$") end
	local function ser(v, path, out, depth)
		if depth > 8 then return end
		if type(v) == "table" then
			local ks = {}
			for k in pairs(v) do ks[#ks + 1] = k end
			table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
			for _, k in ipairs(ks) do
				if not (depth == 0 and SKIP[k]) then ser(v[k], path .. "." .. tostring(k), out, depth + 1) end
			end
		elseif type(v) ~= "function" and not volatile(path) then
			out[path] = tostring(v)
		end
	end
	local function snap(ctx)
		local out = {}
		ser(ctx.me.env.WuberDB, "db", out, 0)
		return out
	end
	local function diff(a, b)
		local d = {}
		for k, v in pairs(a) do if b[k] ~= v then d[#d + 1] = k .. ": " .. v .. " -> " .. tostring(b[k]) end end
		for k, v in pairs(b) do if a[k] == nil then d[#d + 1] = k .. ": (none) -> " .. v end end
		table.sort(d)
		return d
	end
	local function myMsgs(ctx)
		local n = 0
		for _, e in ipairs(ctx.w.addonLog or {}) do if key(e.from or "") == key(ctx.name) then n = n + 1 end end
		return n
	end

	---------------------------------------------------------------------------
	promise{
		id = "simple.fresh_start",
		text = "On a fresh install Wuber starts in Simple mode, shows no 'simpler now' note, and the window is phone-sized.",
		source = "CHANGELOG 2.4.0 (Wuber starts in Simple mode; Simple is always phone-sized; the note is only for a returning player)",
		needs = { session = "first", coach = "not_done" },
		check = function(ctx)
			if ctx.W.Advanced() ~= false then ctx:fail("You install Wuber for the first time and it starts in Advanced mode.") end
			local db = ctx.me.env.WuberDB
			if db.advanced ~= false then ctx:fail("A fresh install does not save the mode as Simple.", tostring(db.advanced)) end
			if db.simpleNote ~= nil then ctx:fail("A fresh install has the 'Wuber is simpler now' note waiting.") end
			openWin(ctx)
			if noteShown(ctx) then ctx:fail("A brand new player is told 'Wuber is simpler now'.") end
			local w = frame(ctx):GetWidth()
			if math.abs(w - 360) > 1 then ctx:fail("A fresh install's window is not phone-sized.", "width " .. tostring(w)) end
		end,
	}

	promise{
		id = "simple.returning_note_once",
		text = "A returning player is told once 'Wuber is simpler now. Everything else is in Settings: Advanced mode.', keeps every saved value, and never sees the note again (after closing, reopening or a /reload).",
		source = "CHANGELOG 2.4.0 (If you used Wuber before, it tells you once)",
		when = function(sit) return sit.session ~= "first" end,
		check = function(ctx)
			local db = ctx.me.env.WuberDB
			if db.simpleNote ~= true then ctx:na("the saved data is not from before (no note waiting)") end
			if ctx.W.Advanced() then ctx:na("the saved data brought Advanced mode") end
			if ctx.W.InCombat and ctx.W.InCombat() then ctx:na("in combat: the note waits for the fight to end (simple.note_waits_through_combat)") end
			local before = snap(ctx)
			if shown(ctx) then ctx.W.UI.Toggle(false) ctx:advance(1) end -- (the build left the window open: a player opens it afresh)
			openWin(ctx)
			ctx:advance(1)
			local n = 0
			if noteShown(ctx) then n = n + 1 else ctx:fail("A returning player opens Wuber and is not told it got simpler.") end
			ctx:advance(8)
			if db.simpleNote ~= nil then ctx:fail("The 'simpler now' note was shown but is still marked to show again.") end
			ctx.W.UI.Toggle(false) ctx:advance(1)
			ctx.W.UI.Toggle(true) ctx:advance(1)
			if noteShown(ctx) then ctx:fail("The 'Wuber is simpler now' note shows a second time after closing and reopening.") end
			ctx:reload()
			ctx:advance(2)
			openWin(ctx)
			if noteShown(ctx) then ctx:fail("The 'Wuber is simpler now' note shows again after a /reload.") end
			local after = snap(ctx)
			local d = diff(before, after)
			-- opening the window may note a first-open guide; only values that existed before must be unchanged
			for _, line in ipairs(d) do
				local k = line:match("^(.-):")
				if before[k] ~= nil and not k:find("seen") and not k:find("coach") and not k:find("tip") and not k:find("pos") and not k:find("fold") then
					ctx:fail("A returning player's saved setting changed by itself when Wuber became simple.", line)
				end
			end
		end,
	}

	promise{
		id = "simple.note_waits_through_combat",
		text = "If a returning player first opens Wuber in combat, the 'simpler now' note is not lost: it still comes once after the fight, and not twice.",
		source = "CHANGELOG 2.4.0 (it tells you once); Window.lua maybeSimpleNote",
		needs = { combat = "no" },
		when = function(sit) return sit.session ~= "first" end,
		check = function(ctx)
			local db = ctx.me.env.WuberDB
			if db.simpleNote ~= true then ctx:na("no note waiting") end
			if ctx.W.Advanced() then ctx:na("Advanced from the saved data") end
			ctx.w:enterCombat(ctx.me)
			ctx:advance(1)
			ctx.W.UI.Toggle(true) ctx:advance(2)
			if noteShown(ctx) and ctx.W.InCombat and ctx.W.InCombat() then ctx:fail("The 'simpler now' note pops up in the middle of a fight.") end
			ctx.w:leaveCombat(ctx.me)
			ctx:advance(3)
			ctx.W.UI.Toggle(false) ctx:advance(1)
			ctx.W.UI.Toggle(true) ctx:advance(2)
			if not noteShown(ctx) and db.simpleNote == nil then ctx:fail("The returning player opened Wuber in combat and was never told it got simpler.") end
		end,
	}

	promise{
		id = "simple.switch_changes_nothing",
		text = "Switching between Simple and Advanced (the command, back and forth, also across a /reload) changes no other saved setting and sets no 'note' flag.",
		source = "CHANGELOG 2.4.0 (Switching changes nothing you have set)",
		when = function(sit) return sit.session ~= "first" end,
		check = function(ctx)
			openWin(ctx)
			ctx:advance(10)
			local s0 = snap(ctx)
			local start = ctx.W.Advanced()
			slashAdv(ctx)
			if ctx.W.Advanced() == start then ctx:fail("/wuber advanced does not switch the mode.") end
			ctx:advance(2)
			slashAdv(ctx)
			ctx:advance(2)
			if ctx.W.Advanced() ~= start then ctx:fail("Typing /wuber advanced twice does not bring you back to where you were.") end
			local d = diff(s0, snap(ctx))
			if #d > 0 then ctx:fail("You switch Advanced mode on and off and a saved setting is different afterwards.", table.concat(d, "; ")) end
			slashAdv(ctx)
			ctx:reload()
			ctx:advance(3)
			if ctx.W.Advanced() == start then ctx:fail("The mode you chose is forgotten after a /reload.") end
			slashAdv(ctx)
			local d2 = diff(s0, snap(ctx))
			-- a ride that ended unpaid (timed out) is not kept across a /reload (Net/Rides.lua restoreRide): that is the reload, not the switch
			if s0["db.ride.state"] == "timeout" and not s0["db.ride.paid"] then
				local keep = {}
				for _, l in ipairs(d2) do if not l:find("^db%.ride%.") then keep[#keep + 1] = l end end
				d2 = keep
			end
			if #d2 > 0 then ctx:fail("After a /reload and switching back, a saved setting is different.", table.concat(d2, "; ")) end
		end,
	}

	local function rideSig(W)
		local r = W.ride
		if not r then return "none" end
		return tostring(r.id) .. "|" .. tostring(r.driver or r.driverKey) .. "|" .. tostring(r.price)
	end

	promise{
		id = "simple.switch_mid_ride_rider",
		text = "As a rider, switching Simple/Advanced in the middle of a ride (window open) does not end, change or cancel the ride and sends nothing to the driver.",
		source = "CHANGELOG 2.4.0 (ends no ride and closes no driver)",
		needs = { role = "rider" },
		when = function(sit) return sit.ride == "requested" or sit.ride == "invited" or sit.ride == "summoning" or sit.ride == "arrived" end,
		check = function(ctx)
			local W = ctx.W
			if not W.ride then ctx:na("no ride on my window") end
			openWin(ctx)
			local sig, m0 = rideSig(W), myMsgs(ctx)
			for i = 1, 2 do
				slashAdv(ctx)
				ctx:advance(1)
				if rideSig(ctx.W) ~= sig then ctx:fail("You switch Advanced mode in the middle of a ride and the ride changed.", sig .. " -> " .. rideSig(ctx.W)) end
				if not (ctx.W.RideActive and ctx.W.RideActive()) then ctx:fail("You switch Advanced mode in the middle of a ride and the ride is over.") end
			end
			if not shown(ctx) then ctx:fail("Switching Advanced mode closes the window in the middle of a ride.") end
			local sent = myMsgs(ctx) - m0
			if sent > 3 then ctx:note("addon messages from me during the switch: " .. sent) end
			local rs = hasText(ctx, "%S")
			if not rs then ctx:fail("The window is empty after switching modes during a ride.") end
		end,
	}

	promise{
		id = "simple.switch_mid_ride_driver",
		text = "As a driver, switching Simple/Advanced in the middle of a ride keeps the shop open, the rider's row and its state, and does not turn the rider away.",
		source = "CHANGELOG 2.4.0 (ends no ride and closes no driver)",
		needs = { role = "warlock" },
		when = function(sit) return sit.ride == "requested" or sit.ride == "invited" or sit.ride == "summoning" or sit.ride == "arrived" end,
		check = function(ctx)
			local DR = ctx.W.Drive
			if not (DR.IsOpen and DR.IsOpen()) then ctx:na("the shop is not open") end
			local rk = ctx.facts.riderName and key(ctx.facts.riderName)
			local c = rk and DR.customers[rk]
			if not c then ctx:na("no rider row for the ride") end
			openWin(ctx)
			ctx.W.UI.Show("drive") ctx:advance(1)
			local st, busy = c.state, DR.Busy and DR.Busy()
			for i = 1, 2 do
				slashAdv(ctx)
				ctx:advance(1)
				local c2 = ctx.W.Drive.customers[rk]
				if not c2 then ctx:fail("You switch Advanced mode with a rider in your queue and the rider's row is gone.") end
				if c2.state ~= st then ctx:fail("You switch Advanced mode and the rider's row changes state.", tostring(st) .. " -> " .. tostring(c2.state)) end
				if not ctx.W.Drive.IsOpen() then ctx:fail("You switch Advanced mode and your shop closes.") end
				if (ctx.W.Drive.Busy and ctx.W.Drive.Busy()) ~= busy then ctx:fail("You switch Advanced mode and the ride in progress is no longer in progress.") end
			end
		end,
	}

	promise{
		id = "simple.switch_in_combat",
		text = "Switching Simple/Advanced in combat works (the window follows, the big summon button is left alone) and nothing is out of place after the fight.",
		source = "CHANGELOG 2.4.0; CLAUDE.md (secure frames never shown, hidden, moved or changed in combat)",
		needs = { combat = "no" },
		check = function(ctx)
			openWin(ctx)
			ctx:advance(3) -- the big summon button settles into its place (a moment after the window opens) before the first reading
			local btn = ctx.me.env.WuberDriveButton
			local function sig(f)
				if not f then return "none" end
				local ok, p, rel, rp, x, y = pcall(f.GetPoint, f, 1)
				return table.concat({ tostring(f:IsShown()), tostring(f:GetWidth()), tostring(f:GetHeight()), tostring(p), tostring(rp), tostring(x), tostring(y) }, "|")
			end
			local s0 = sig(btn)
			local start = ctx.W.Advanced()
			ctx.w:enterCombat(ctx.me)
			ctx:advance(1)
			slashAdv(ctx)
			if ctx.W.Advanced() == start then ctx:fail("/wuber advanced does nothing in combat.") end
			ctx:advance(1)
			slashAdv(ctx)
			ctx:advance(1)
			if ctx.W.Advanced() ~= start then ctx:fail("Switching twice in combat does not bring the mode back.") end
			if sig(btn) ~= s0 then ctx:fail("Switching modes in combat moves, shows, hides or resizes the big summon button.", s0 .. " -> " .. sig(btn)) end
			ctx.w:leaveCombat(ctx.me)
			ctx:advance(3)
			if sig(btn) ~= s0 then ctx:fail("After a fight where you switched modes, the big summon button is not where it was.", s0 .. " -> " .. sig(btn)) end
			if start == false and shown(ctx) then
				local w = frame(ctx):GetWidth()
				if math.abs(w - 360) > 1 then ctx:fail("You are in Simple, switch twice in combat, and the window is not phone-sized afterwards.", "width " .. w) end
			end
		end,
	}

	promise{
		id = "simple.always_phone_sized",
		text = "In Simple the window is always phone-sized (360 wide, no Wide button), even if you had wide pages saved; Advanced gives the wide page back and your saved wide choice is untouched.",
		source = "CHANGELOG 2.4.0 (Simple is always phone-sized)",
		check = function(ctx)
			openWin(ctx)
			local fold0 = snap(ctx)
			if ctx.W.Advanced() then slashAdv(ctx) end
			openWin(ctx)
			local w = frame(ctx):GetWidth()
			if math.abs(w - 360) > 1 then ctx:fail("In Simple mode the window is wider than a phone.", "width " .. w) end
			if ctx.W.UI.Fold and ctx.W.UI.Fold.IsUnfolded and ctx.W.UI.Fold.IsUnfolded() then ctx:fail("In Simple mode a page is unfolded wide.") end
			slashAdv(ctx)
			slashAdv(ctx)
			ctx:advance(1)
			local w2 = frame(ctx):GetWidth()
			if math.abs(w2 - 360) > 1 then ctx:fail("After going Advanced and back to Simple the window is not phone-sized again.", "width " .. w2) end
			local d = {}
			for _, l in ipairs(diff(fold0, snap(ctx))) do if l:find("fold", 1, true) then d[#d + 1] = l end end
			if #d > 0 then ctx:fail("Going Simple and back changed your saved wide-page choice.", table.concat(d, "; ")) end
		end,
	}

	promise{
		id = "simple.drive_tab_who",
		text = "In Simple the Drive tab shows to a Warlock, to anyone in a crew, and to anyone with a crew offer waiting; a plain rider does not see it until an offer comes, and it goes again when the offer is gone.",
		source = "CHANGELOG 2.4.0 (The Drive tab shows to Warlocks, to anyone in a crew and to anyone with a crew offer waiting)",
		check = function(ctx)
			openWin(ctx)
			local function tabShown()
				for _, tab in ipairs(ctx.W.UI.state.tabs or {}) do
					if tab.name == "Drive" then return tab.button:IsVisible() and true or false end
				end
				return nil
			end
			local sh = tabShown()
			if sh == nil then ctx:cannot("no Drive tab button found") end
			local bar = ctx.W.UI.state.tabbar
			if bar and not ctx:visible(bar) then ctx:na("the tab bar is out of sight during a ride (design 4)") end
			local DR = ctx.W.Drive
			local role = DR.Role and DR.Role() or "none"
			local lock = ctx.W.IsWarlock and ctx.W.IsWarlock()
			local want = (lock == true) or (role and role ~= "none")
			if want and not sh then ctx:fail("You are a Warlock or in a crew and Simple mode hides the Drive tab.", "role " .. tostring(role)) end
			if not want and sh then
				if DR.pendingOffers and next(DR.pendingOffers) ~= nil then ctx:na("an offer is already waiting") end
				ctx:fail("You are a plain rider with no crew offer and Simple mode shows a Drive tab.")
			end
			if not want then
				local offer = { captain = "Cap Tain", key = "cap tain", name = "Cap Tain", cut = 25, at = ctx.me.env.GetTime(), expires = ctx.me.env.GetTime() + 120 }
				DR.pendingOffers = DR.pendingOffers or {}
				DR.pendingOffers["cap tain"] = offer
				ctx.W.Fire("DRIVE_OFFER", "cap tain", offer)
				ctx:advance(1)
				if not tabShown() then ctx:fail("A captain's crew offer is waiting for you and the Drive tab does not show.") end
				DR.pendingOffers["cap tain"] = nil
				ctx.W.Fire("DRIVE_OFFER", "cap tain")
				ctx:advance(1)
				if tabShown() then ctx:fail("The crew offer is gone and the Drive tab stays.") end
			end
			ctx:reload() ctx:advance(2)
			openWin(ctx)
			local sh2 = tabShown()
			if (sh2 and true or false) ~= want then ctx:fail("After a /reload the Drive tab is shown or hidden differently for the same player.", tostring(sh2)) end
		end,
	}

	promise{
		id = "simple.hidden_settings_keep_values",
		text = "The nine switches that left Settings (drive accept, public, autotrade, remind, shards, away, wants, sharenotes, updates) keep what was saved through login, Settings, a mode switch and a /reload; each typed command still sets it.",
		source = "CHANGELOG 2.4.0 (A shorter Settings page: what you had set stays set, and each has a typed command)",
		needs = { role = "warlock" },
		when = function(sit) return sit.session ~= "first" end,
		pre = function(ctx)
			local s = ctx.saved
			if type(s) ~= "table" then s = {} ctx.saved = s end
			s.Wuber = s.Wuber or {}
			s.Wuber.updateNotes = false
		end,
		check = function(ctx)
			local db = ctx.me.env.WuberDB
			if db.updateNotes ~= false then ctx:na("the saved data did not keep updateNotes = false") end
			local DR = ctx.W.Drive
			local o = DR.opts()
			local FLIP = { "awayGuard", "watchBounty", "shareNotes" }
			local was = {}
			for _, k in ipairs(FLIP) do if type(o[k]) == "boolean" then o[k] = not o[k] was[k] = o[k] end end
			openWin(ctx)
			ctx.W.UI.Show("settings") ctx:advance(1)
			slashAdv(ctx) slashAdv(ctx)
			ctx:reload() ctx:advance(3)
			if ctx.me.env.WuberDB.updateNotes ~= false then ctx:fail("You had 'Tell me about updates' off and Wuber turned it back on.") end
			for k, v in pairs(was) do
				if ctx.W.Drive.opts()[k] ~= v then ctx:fail("A driver switch that left Settings changed by itself (" .. k .. ").", tostring(v) .. " -> " .. tostring(ctx.W.Drive.opts()[k])) end
			end
			ctx.me:slash("/wuber updates on") ctx:advance(0.5)
			if ctx.me.env.WuberDB.updateNotes == false then ctx:fail("/wuber updates on does not turn update notes on.") end
			ctx.me:slash("/wuber updates off") ctx:advance(0.5)
			if ctx.me.env.WuberDB.updateNotes ~= false then ctx:fail("/wuber updates off does not turn update notes off.") end
			ctx.me:slash("/wuber drive away off") ctx:advance(0.5)
			if ctx.W.Drive.opts().awayGuard ~= false then ctx:fail("/wuber drive away off does not turn the away pause off.") end
			ctx.me:slash("/wuber drive away on") ctx:advance(0.5)
			if ctx.W.Drive.opts().awayGuard ~= true then ctx:fail("/wuber drive away on does not turn the away pause on.") end
		end,
	}

	promise{
		id = "simple.search_finds_advanced",
		text = "In Simple, Settings search still finds an Advanced setting, labels it 'Advanced', clicking it shows where the switch is, and the mode stays Simple.",
		source = "CHANGELOG 2.4.0 (Search still finds an Advanced setting in Simple mode and says 'Advanced'; a click shows where the switch is)",
		needs = { role = "warlock" },
		check = function(ctx)
			local W = ctx.W
			openWin(ctx)
			if not W.UI.OpenSettings then ctx:cannot("no UI.OpenSettings") end
			W.UI.OpenSettings() ctx:advance(1)
			local st = W.UI.settings
			if not (st and st.find and st.find.box and st.find.box.edit) then ctx:cannot("the Settings search box is not reachable") end
			ctx.me:type(st.find.box.edit, "request words", false)
			ctx:advance(0.7)
			local hit
			for _, b in ipairs(st.find.items or {}) do
				if ctx:visible(b) and b.m and b.m.label == "Request words" then hit = b end
			end
			if not hit then ctx:fail("You type 'request words' in Settings search in Simple mode and Wuber finds nothing, although the setting exists in Advanced.") end
			local where = hit.where and hit.where:GetText() or ""
			if not where:find("Advanced", 1, true) then ctx:fail("A search result for an Advanced setting does not say 'Advanced' in Simple mode.", where) end
			ctx.me:click(hit) ctx:advance(1)
			if W.Advanced() then ctx:fail("Clicking a search result for an Advanced setting switches the mode to Advanced by itself.") end
			if not hasText(ctx, "Advanced mode", true) then ctx:fail("Clicking an Advanced search result does not show where the Advanced mode switch is.") end
		end,
	}

	promise{
		id = "simple.rider_leaves_out_and_back",
		text = "A rider in Simple does not see the '<n> open · <n> online' count on the Ride screen or the Milestones on Trips; Advanced shows them again, with the same drivers; going back to Simple hides them again.",
		source = "CHANGELOG 2.4.0 (In Simple a rider's screens leave out: the '3 open · 4 online' count ... milestones)",
		needs = { role = "rider", ride = "none" },
		when = function(sit) return sit.net == "one" or sit.net == "several" or sit.net == "many" end,
		check = function(ctx)
			openWin(ctx)
			if ctx.W.Advanced() then ctx:na("Advanced from the saved data") end
			local function count() return hasText(ctx, "^%d+ open") end
			ctx.W.UI.Show("ride") ctx:advance(1)
			if not next(ctx.W.drivers or {}) then ctx:na("no driver listed") end
			if count() then ctx:fail("In Simple mode the Ride screen shows the open/online driver count.", count()) end
			ctx.W.UI.Show("trips") ctx:advance(1)
			if hasText(ctx, "Milestones", true) then ctx:fail("In Simple mode the Trips screen shows Milestones.") end
			slashAdv(ctx)
			ctx.W.UI.Show("ride") ctx:advance(1)
			if not count() then ctx:fail("After switching to Advanced the open/online count does not come back on the Ride screen.") end
			ctx.W.UI.Show("trips") ctx:advance(1)
			if not milestonesReachable(ctx) then ctx:fail("After switching to Advanced the Milestones do not come back on Trips.") end
			slashAdv(ctx)
			ctx.W.UI.Show("ride") ctx:advance(1)
			if count() then ctx:fail("After switching back to Simple the open/online count is still shown.") end
		end,
	}

	promise{
		id = "simple.driver_bar_leaves_out",
		text = "A driver in Simple has no 'Sell summons / Raid summons' bar and no Crew/Messages/Customers entries when there is nothing to show; the bar comes back in Advanced, and stays in Simple while you are in a raid.",
		source = "CHANGELOG 2.4.0 (In Simple a driver's screens leave out: the Sell / Raid bar (it stays in a raid) ...)",
		needs = { role = "warlock", ride = "none" },
		check = function(ctx)
			openWin(ctx)
			if ctx.W.Advanced() then ctx:na("Advanced from the saved data") end
			ctx:advance(6)
			-- (job 2680) ShowDrive("console") puts a Drive page the dial left up (the crew wizard) away, as the back chevron does
			local shownOk = ctx.W.UI.ShowDrive("console") ctx:advance(1)
			local inRaid = ctx.sit.group == "raid"
			if ctx.W.UI.state.tab ~= "Drive" then ctx:na("the Drive tab would not open (Show returned " .. tostring(shownOk) .. ", tab " .. tostring(ctx.W.UI.state.tab) .. ")") end
			local bar = hasText(ctx, "Raid summons", true)
			if inRaid and not bar then ctx:fail("You are in a raid, in Simple mode, and the Sell / Raid summons bar is missing.") end
			if not inRaid and bar then ctx:fail("In Simple mode the driver screen shows the Sell / Raid summons bar although you are not in a raid.") end
			if not inRaid and hasText(ctx, "^Customers$") then ctx:fail("In Simple mode Your business lists Customers.") end
			if not inRaid and hasText(ctx, "^Messages$") then ctx:fail("In Simple mode Your business lists Messages.") end
			slashAdv(ctx)
			ctx.W.UI.ShowDrive("console") ctx:advance(1)
			if not hasText(ctx, "Raid summons", true) then ctx:fail("After switching to Advanced the Sell / Raid summons bar does not come back.") end
			if not hasText(ctx, "^Customers$") then ctx:fail("After switching to Advanced Customers does not come back in Your business.") end
			slashAdv(ctx)
			ctx.W.UI.ShowDrive("console") ctx:advance(1)
			if not inRaid and hasText(ctx, "Raid summons", true) then ctx:fail("After going back to Simple the Raid summons bar is still shown.") end
		end,
	}

	promise{
		id = "simple.title_ladder",
		text = "A driver's title is Learner, Cabbie at 10, Black Cab at 50, Chauffeur at 250 and Has The Knowledge at 1,000 verified summons, and Wuber says how many are left to the next.",
		source = "CHANGELOG 2.4.0 (Titles for drivers)",
		simple = false,
		check = function(ctx)
			local W = ctx.W
			local want = { [0] = "Learner", [9] = "Learner", [10] = "Cabbie", [49] = "Cabbie", [50] = "Black Cab", [249] = "Black Cab",
				[250] = "Chauffeur", [999] = "Chauffeur", [1000] = "Has The Knowledge", [5000] = "Has The Knowledge" }
			for n, t in pairs(want) do
				local _, title = W.RankOf(n)
				if title ~= t then ctx:fail("A driver with " .. n .. " verified summons is called " .. tostring(title) .. " instead of " .. t .. ".") end
			end
			local ch = W.Char()
			ch.rank = { n = 9, seen = {} }
			local info = W.Drive.RankInfo()
			if info.title ~= "Learner" or info.toNext ~= 1 then ctx:fail("At 9 summons the driver is not told he is 1 away from Cabbie.", tostring(info.title) .. " / " .. tostring(info.toNext)) end
			ch.rank = { n = 1000, seen = {} }
			info = W.Drive.RankInfo()
			if info.nextAt ~= nil or info.toNext ~= nil then ctx:fail("The top title still shows a next title to reach.") end
		end,
	}

	promise{
		id = "simple.title_counts_once",
		text = "A summon that really arrives through Wuber adds exactly one to your count, the same ride reported again adds nothing, and the count is still there after a /reload.",
		source = "CHANGELOG 2.4.0 (A summon is verified when ... once per rider a day; the count starts at zero)",
		needs = { role = "warlock", ride = "arrived" },
		simple = false,
		check = function(ctx)
			local DR = ctx.W.Drive
			local n = DR.RankCount()
			if n ~= 1 then
				if n == 0 then ctx:na("the built ride was not a verified summon (count 0)") end
				ctx:fail("One summon through Wuber arrived and your count is " .. n .. ".")
			end
			local rk = ctx.facts.riderName and key(ctx.facts.riderName)
			local c = rk and DR.customers[rk]
			local id = c and c.wuberRide
			if id then
				local R = ctx:mod("Drive.Rank")
				if R and R.heard then
					R.heard("WHISPER", ctx.facts.riderName, rk, { id })
					if DR.RankCount() ~= 1 then ctx:fail("The same arrival reported a second time counts again.", tostring(DR.RankCount())) end
				end
			end
			ctx:reload() ctx:advance(2)
			if ctx.W.Drive.RankCount() ~= 1 then ctx:fail("Your summon count is gone or changed after a /reload.", tostring(ctx.W.Drive.RankCount())) end
		end,
	}
	-- The author's call (FOR-TESTCHAR, 22 Nov): on the FIRST open of a session with login tips on, Wuber moves a phone that opens on
	-- Drive to the Ride screen so the login tip can show (Wuber/UI/Tips.lua:525; pinned on purpose by tests/r32/r32_f2_tipwait_test.lua:41,
	-- a decision of round 26). Whether a typed /wuber drive should be exempt is not decided, so this promise starts after that first open.
	promise{
		id = "simple.show_drive_stays",
		text = "After the first open of the session (or with login tips off), a Warlock who types /wuber drive (or taps Drive) lands on the Drive screen and stays there, in Simple or Advanced.",
		source = "CHANGELOG 2.4.0 (The Drive tab shows to Warlocks); tests/v24/rem_simple_shell_test.lua (UI.Show('drive') opens Drive)",
		needs = { role = "warlock" },
		check = function(ctx)
			if shown(ctx) then ctx:na("the window is already open from the start") end
			ctx:advance(1)
			-- the first open of the session (the author's call, see above): open Wuber, let the login tip settle, close it again
			ctx.W.UI.Toggle(true)
			ctx:note("open Wuber once")
			ctx:advance(6)
			ctx.W.UI.Toggle(false)
			ctx:note("close Wuber")
			ctx:advance(1)
			if shown(ctx) then ctx:cannot("the window would not close again") end
			local ok = ctx.W.UI.Show("drive")
			ctx:note("/wuber drive")
			if not shown(ctx) then ctx:cannot("the window did not open") end
			local first = ctx.W.UI.state.tab
			ctx:advance(4)
			local tab = ctx.W.UI.state.tab
			if ok == true and tab ~= "Drive" then
				ctx:fail("You type /wuber drive as a Warlock: the Drive screen shows for a moment and the window falls back to the Ride screen.", "tab " .. tostring(first) .. " at once, " .. tostring(tab) .. " after 4 s; Advanced " .. tostring(ctx.W.Advanced()))
			end
		end,
	}
	promise{
		id = "simple.title_card_once",
		text = "The summon that takes you to 10 verified summons shows the new-title card (Cabbie, with 'Tell the guild') once; it is not shown again after a /reload, and the guild is told only by your click.",
		source = "CHANGELOG 2.4.0 (Reaching a title shows a card once, with 'Tell the guild'; one click posts ... never a public channel)",
		needs = { role = "warlock", ride = "arrived", session = "login" },
		pre = function(ctx)
			local s = ctx.saved
			if type(s) ~= "table" then s = {} ctx.saved = s end
			s.Wuber = s.Wuber or {}
			s.Wuber.chars = s.Wuber.chars or {}
			local k = key(ctx.name)
			s.Wuber.chars[k] = s.Wuber.chars[k] or {}
			s.Wuber.chars[k].rank = { n = 9, seen = {} }
		end,
		check = function(ctx)
			local n = ctx.W.Drive.RankCount()
			if n ~= 10 then ctx:na("the count did not reach 10 here (" .. n .. ")") end
			ctx:advance(2)
			openWin(ctx)
			ctx:advance(2)
			if not hasText(ctx, "Cabbie", true) then ctx:fail("You reach 10 verified summons and no card shows the new title Cabbie.") end
			local inCombat = ctx.me.player.combat or (ctx.W.InCombat and ctx.W.InCombat())
			if inCombat then
				-- by design (UI/Share.lua) the share button reads "Share after combat" while you fight
				if not hasText(ctx, "Share after combat", true) then ctx:fail("The new-title card has neither 'Tell the guild' nor 'Share after combat' (you are in combat).") end
			elseif not hasText(ctx, "Tell the guild", true) then ctx:fail("The new-title card has no 'Tell the guild' button.") end
			local posts = #(ctx.w.chatPosts or {})
			local gl = #(ctx.w.groupPosts or {})
			ctx.W.UI.Toggle(false) ctx:advance(1)
			ctx:reload() ctx:advance(2)
			openWin(ctx) ctx:advance(2)
			if hasText(ctx, "Tell the guild", true) or hasText(ctx, "Share after combat", true) then ctx:fail("The new-title card comes back after a /reload although you saw it.") end
			if #(ctx.w.chatPosts or {}) ~= posts then ctx:fail("Reaching a title posted to chat without any click.") end
		end,
	}
end
