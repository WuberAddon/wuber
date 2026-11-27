-- Promises about the phone's screens on the 2.4 code (tests/promises/v24_design.lua; job 097, design rounds 2 to 4).
-- What CHANGELOG-2.4.0 ("A phone that moves", design round 2; "The portal, tooltips and maps", round 4) and REPORT-design-3/4
-- promise: the tab bar, the cog, the back arrow, the one main button, the black pill, sheets, Reduce motion, a fight, the tabs
-- that hide during a live ride and come back, Wuber's own tooltip card, the Earnings key. Each looks for what is LEFT BEHIND:
-- a sheet or a dim layer after closing, a back arrow that leads nowhere, tabs that never return.
return function(Hunt)
	local function ui(ctx) local K = ctx:mod("UI.Kit") return K and K.ui or {} end
	local function S(ctx) return ctx.H.state end
	local function shown(ctx) local U = ctx.W.UI return U and type(U.IsShown) == "function" and U.IsShown() == true end
	local function inCombat(ctx) return ctx.me.player.combat == true end
	local function onScreen(ctx) return "on screen: " .. table.concat(ctx:texts(), " | ") end
	local function slash(ctx, line, wait) ctx.me:slash(line) ctx:advance(wait or 0.4) ctx:note(line) end
	local function inside(obj, top)
		local cur, n = obj, 0
		while cur and n < 40 do
			if cur == top then return true end
			local ok, p = pcall(cur.GetParent, cur)
			if not ok then return false end
			cur, n = p, n + 1
		end
		return false
	end
	-- a click the way a player makes it: on what is drawn at the control's centre
	local function press(ctx, obj)
		local okc, cx, cy = pcall(obj.GetCenter, obj)
		local ratio = okc and cx and obj:GetEffectiveScale() / ctx.me.env.UIParent:GetEffectiveScale() or 1
		local hit = okc and cx and ctx.me:frameAt(cx * ratio, cy * ratio) or nil
		if hit and inside(hit, obj) and pcall(ctx.me.clickOn, ctx.me, obj) then return end
		ctx.me:click(obj)
	end
	-- first tap: close the cards that can sit over the screen on older saved data (What's new, the "simpler" note)
	local function clearCards(ctx)
		for _ = 1, 3 do
			local b = ctx.me:button("Got it") or ctx.me:button("Close") or ctx.me:button("Not now")
			if b and ctx:visible(b) then pcall(press, ctx, b) ctx:advance(0.5) else break end
		end
	end
	local function ensureOpen(ctx)
		if not shown(ctx) then slash(ctx, "/wuber", 0.4) end
		ctx:advance(2.5)
		if not shown(ctx) then ctx:cannot("the phone would not open") end
	end
	local function tabByName(ctx, name)
		for _, t in ipairs(ui(ctx).tabs or {}) do if t.name == name then return t end end
	end
	local function wantTab(ctx, name)
		local t = tabByName(ctx, name)
		if not (t and t.button and ctx:visible(t.button)) then return false end
		press(ctx, t.button)
		ctx:advance(0.6)
		ctx:note("click the " .. name .. " tab")
		return true
	end
	-- every visible Back arrow (T.Tip title "Back")
	local function backs(ctx)
		local out = {}
		for _, obj in ipairs(ctx.me.widgets) do
			local s = S(ctx)[obj]
			if s and s.kind == "frame" and obj.wuberTip and obj.wuberTip.title == "Back" and ctx:visible(obj) then out[#out + 1] = obj end
		end
		return out
	end
	local function visibleSheets(ctx)
		local out = {}
		for _, obj in ipairs(ctx.me.widgets) do
			local s = S(ctx)[obj]
			if s and s.kind == "frame" and rawget(obj, "dim") ~= nil and rawget(obj, "card") ~= nil and ctx:visible(obj) then out[#out + 1] = obj end
		end
		return out
	end
	-- a dim layer that still shows (any Sheet's dim, even one whose sheet is gone)
	local function dimsLeft(ctx)
		local n = 0
		for _, obj in ipairs(ctx.me.widgets) do
			local s = S(ctx)[obj]
			if s and s.kind == "frame" and rawget(obj, "dim") ~= nil and rawget(obj, "card") ~= nil then
				local d = obj.dim
				if d and ctx:visible(d) and (tonumber(d:GetAlpha()) or 0) > 0.02 then n = n + 1 end
			end
		end
		return n
	end
	local function noFight(ctx) if inCombat(ctx) then ctx:na("in combat from the start") end end
	local function promise(p)
		p.area = "Phone design"
		p.kind = p.kind or "scenario"
		local w = p.when
		p.when = function(sit)
			if sit.fold == "folded_click" then return false end -- (needs a wide open page; this promise opens the phone itself)
			if sit.session == "first" and p.notFirst then return false end
			return (not w) or w(sit)
		end
		Hunt.promise(p)
	end
	local function color(fs) local r, g, b = fs:GetTextColor() return string.format("%.2f,%.2f,%.2f", r or -1, g or -1, b or -1) end

	---------------------------------------------------------------------------
	promise{
		id = "design.tabs_chosen_marked",
		text = "The tab bar has Ride, Trips and Drive (no Settings tab); the tab you click is the chosen one, marked in a colour the others do not have.",
		source = "CHANGELOG 2.4.0 'A phone that moves': Tabs at the bottom ... the chosen one violet. Settings is the cog, not a tab.",
		needs = { ride = "none", combat = "no", phone = "closed" },
		check = function(ctx)
			noFight(ctx)
			ensureOpen(ctx)
			clearCards(ctx)
			local tabs = ui(ctx).tabs or {}
			local seen = 0
			for _, t in ipairs(tabs) do
				if t.name ~= "Ride" and t.name ~= "Trips" and t.name ~= "Drive" then
					ctx:fail("The tab bar has a tab called " .. tostring(t.name) .. " beside Ride, Trips and Drive.")
				end
			end
			for _, name in ipairs({ "Ride", "Trips", "Drive" }) do
				local t = tabByName(ctx, name)
				if t and t.button and ctx:visible(t.button) then
					seen = seen + 1
					if not wantTab(ctx, name) then ctx:na("a tab button could not be clicked") end
					if ui(ctx).tab ~= name then ctx:fail("You click the " .. name .. " tab and the phone shows the " .. tostring(ui(ctx).tab) .. " tab.", onScreen(ctx)) end
					local mine = color(t.button.label)
					for _, o in ipairs(tabs) do
						if o ~= t and o.button and ctx:visible(o.button) and color(o.button.label) == mine then
							ctx:fail("On the " .. name .. " tab the " .. o.name .. " tab's words are the same colour as the chosen tab's, so you cannot tell which is chosen.")
						end
					end
				end
			end
			if seen < 2 then ctx:na("fewer than two tabs show here (Simple mode hides Drive for a rider)") end
		end,
	}

	promise{
		id = "design.cog_only_first_pages",
		text = "The cog (Settings) shows on the first pages (Ride, Trips, Drive) and is gone on a page opened from another, where an arrow takes its place.",
		source = "CHANGELOG 2.4.0: 'A page you open from another has a back arrow and its title at the top; the cog shows only on the first pages.'",
		needs = { ride = "none", combat = "no", phone = "closed" },
		check = function(ctx)
			noFight(ctx)
			ensureOpen(ctx)
			clearCards(ctx)
			local gear = ui(ctx).gear
			if not gear then ctx:cannot("no cog in the UI state") end
			for _, name in ipairs({ "Ride", "Trips", "Drive" }) do
				if wantTab(ctx, name) and not ctx:visible(gear) then
					ctx:fail("On the " .. name .. " tab, a first page, the cog is not on the screen.", onScreen(ctx))
				end
			end
			wantTab(ctx, "Ride")
			if not ctx:visible(gear) then ctx:na("no cog on the Ride tab to start with") end
			press(ctx, gear)
			ctx:advance(1)
			ctx:note("click the cog")
			if not ui(ctx).settingsOpen then ctx:fail("You click the cog and Settings does not open.", onScreen(ctx)) end
			if ctx:visible(gear) then ctx:fail("Settings is open (a page opened from another) and the cog still shows on it.", onScreen(ctx)) end
			if #backs(ctx) == 0 then ctx:fail("Settings is open and there is no back arrow at its top.", onScreen(ctx)) end
		end,
	}

	promise{
		id = "design.back_returns_where_you_were",
		text = "Open Settings from a tab, go into a section, and the back arrow takes you out one step at a time, ending on the tab you started from.",
		source = "CHANGELOG 2.4.0: a page you open from another has a back arrow (Panel.lua Back: 'Back to where you were.')",
		needs = { ride = "none", combat = "no", phone = "closed" },
		check = function(ctx)
			noFight(ctx)
			ensureOpen(ctx)
			clearCards(ctx)
			local did = 0
			for _, name in ipairs({ "Ride", "Trips", "Drive" }) do
				if wantTab(ctx, name) then
					did = did + 1
					local gear = ui(ctx).gear
					if not (gear and ctx:visible(gear)) then ctx:na("no cog on " .. name) end
					press(ctx, gear)
					ctx:advance(1)
					if not ui(ctx).settingsOpen then ctx:fail("From the " .. name .. " tab you click the cog and Settings does not open.") end
					local Fd = ctx.W.UI.Fold
					local wide = Fd and Fd.IsUnfolded and Fd.IsUnfolded() == true
					local row = (not wide) and ctx.me:button("Riding") or nil -- (unfolded, the list stays beside the section: the arrow then closes Settings)
					if row and ctx:visible(row) then
						press(ctx, row)
						ctx:advance(1)
						ctx:note("open Settings > Riding")
						local b = backs(ctx)
						if #b == 0 then ctx:fail("You open Settings > Riding and there is no back arrow.", onScreen(ctx)) end
						press(ctx, b[1])
						ctx:advance(1)
						ctx:note("back from Riding")
						if not ui(ctx).settingsOpen then ctx:fail("From Settings > Riding the back arrow closes Settings altogether instead of going to the Settings list.", onScreen(ctx)) end
					end
					-- Settings may reopen inside the section it was last in: the arrow then goes one step to the list, then out
					for _ = 1, 3 do
						if not ui(ctx).settingsOpen then break end
						local b = backs(ctx)
						if #b == 0 then ctx:fail("Settings is open and there is no back arrow to leave it.", onScreen(ctx)) end
						press(ctx, b[#b])
						ctx:advance(1)
						ctx:note("back from Settings")
					end
					if ui(ctx).settingsOpen then ctx:fail("You press the back arrow in Settings three times and Settings stays open.", onScreen(ctx)) end
					if ui(ctx).tab ~= name then
						ctx:fail("You opened Settings from the " .. name .. " tab, went back, and landed on the " .. tostring(ui(ctx).tab) .. " tab.", onScreen(ctx))
					end
					if #backs(ctx) > 0 then ctx:fail("After going back to the " .. name .. " tab a back arrow is still on screen.", onScreen(ctx)) end
				end
			end
			if did == 0 then ctx:na("no tab could be clicked") end
		end,
	}

	local PAGES = { settings = true, settings_riding = true, settings_driving = true, settings_map = true, settings_sound = true,
		settings_window = true, help = true, confirm = true, drive_earnings = true, drive_messages = true, drive_customers = true,
		drive_crew = true, drive_wizard = true }
	promise{
		id = "design.back_arrow_leads_somewhere",
		text = "On a page opened from another (Settings and its sections, Help, Confirm, Earnings, Messages, Customers, Crew) the back arrow is there and pressing it changes the screen.",
		source = "CHANGELOG 2.4.0: a page you open from another has a back arrow ... Set up driving has no Back button any more: the arrow at the top goes back.",
		needs = { ride = "none", combat = "no" },
		when = function(sit) return PAGES[sit.phone or "closed"] == true end,
		check = function(ctx)
			noFight(ctx)
			if not shown(ctx) then ctx:cannot("the phone is not open") end
			ctx:advance(2.5)
			clearCards(ctx)
			local b = backs(ctx)
			if #b == 0 then ctx:fail("A page opened from another (" .. tostring(ctx.sit.phone) .. ") has no back arrow.", onScreen(ctx)) end
			local before = table.concat(ctx:texts(), "|")
			local tab = ui(ctx).tab
			press(ctx, b[1])
			ctx:advance(1)
			ctx:note("press the back arrow")
			local after = table.concat(ctx:texts(), "|")
			if after == before and ctx.sit.phone ~= "drive_wizard" then
				ctx:fail("You press the back arrow on " .. tostring(ctx.sit.phone) .. " and nothing on the screen changes.", before)
			end
			if not shown(ctx) then ctx:fail("You press the back arrow and Wuber closes instead of going back one page.") end
		end,
	}

	promise{
		id = "design.main_button_words",
		text = "On the Ride screen the one main button reads 'Ride again · place · price' while Your usual shows, or 'Ping drivers' when nobody is online, and it stands above the tab bar.",
		source = "CHANGELOG 2.4.0: 'On the Ride screen it says \"Ride again · Undercity · 50s\"; with nobody online it is \"Ping drivers\"'",
		needs = { ride = "none", combat = "no", phone = "closed", role = "rider" },
		check = function(ctx)
			noFight(ctx)
			ensureOpen(ctx)
			clearCards(ctx)
			if not wantTab(ctx, "Ride") then ctx:na("no Ride tab") end
			local texts = ctx:texts()
			local function has(p) for _, t in ipairs(texts) do if t:find(p) then return t end end end
			local usual, ping = has("^Your usual"), has("^Ping drivers")
			local again = has("^Ride again")
			if usual and usual:find("nobody") then ctx:na("Your usual names a place nobody drives to right now (no main button is owed)") end
			if not (usual or ping or again) then ctx:na("Home shows neither Your usual nor the empty screen here") end
			local btn
			if again then
				if not again:find("^Ride again · .+ · .+") then ctx:fail("Your usual's main button reads '" .. again .. "', not 'Ride again · place · price'.", onScreen(ctx)) end
				btn = ctx.me:button("Ride again", { pattern = true })
			elseif usual then
				ctx:fail("Your usual shows but Home has no 'Ride again' main button.", onScreen(ctx))
			else
				btn = ctx.me:button("Ping drivers")
			end
			if btn then
				local tb = ui(ctx).tabbar
				if tb and ctx:visible(tb) and btn:GetBottom() < tb:GetTop() - 0.5 then
					ctx:fail("The main button on the Ride screen sits on the tab bar, not above it.")
				end
			end
		end,
	}


	---------------------------------------------------------------------------
	-- the black pill
	---------------------------------------------------------------------------
	local PILL = { requesting = "Finding a driver", accepted = "Accepted", invited = "Invited", ingroup = "Invited", summoning = "Summoning",
		portal = "Portal opening", arrived = "Arrived", paying = "Arrived" }
	local function pill(ctx) local p = ui(ctx).phone return p and p.island end
	local function rideState(ctx) return ctx.W.ride and ctx.W.ride.state end

	promise{
		id = "design.pill_words_per_step",
		text = "During a ride the black pill at the top says where it is: 'Finding a driver', 'Accepted', 'Invited', 'Summoning', 'Portal opening' (with '1 of 2'), 'Arrived' (with the price).",
		source = "CHANGELOG 2.4.0 'A phone that moves': The black pill at the top comes alive during a ride",
		needs = { combat = "no", phone = "closed", role = "rider" },
		when = function(sit) return sit.ride == "requested" or sit.ride == "invited" or sit.ride == "summoning" or sit.ride == "arrived" end,
		check = function(ctx)
			noFight(ctx)
			local st = rideState(ctx)
			if not st then ctx:na("no ride of mine in this build") end
			ensureOpen(ctx)
			clearCards(ctx)
			local isl = pill(ctx)
			if not isl then ctx:cannot("no pill in the UI state") end
			local want = PILL[st]
			if not want then ctx:na("ride state " .. tostring(st) .. " has no pill words in the notes") end
			local got = isl.state:GetText()
			if (st == "summoning" or st == "portal") and got and (got == "Portal opening" or got == "Portal open") then want = got end -- (open once the summon box is up)
			if got ~= want then
				ctx:fail("In ride step '" .. st .. "' the pill says '" .. tostring(got) .. "' instead of '" .. want .. "'.", onScreen(ctx))
			end
			if not (isl.words and ctx:visible(isl.words)) then ctx:fail("In ride step '" .. st .. "' the pill's words are not on screen.") end
			if st == "arrived" and not tostring(isl.step:GetText() or ""):find("%d") then
				ctx:fail("When you have arrived the pill shows no price.", tostring(isl.step:GetText()))
			end
		end,
	}

	local function goHome(ctx)
		local b = backs(ctx)
		if #b == 0 then return false end
		press(ctx, b[#b]) ctx:advance(1.2) ctx:note("press the back arrow")
		return true
	end

	promise{
		id = "design.pill_click_opens_ride_anywhere",
		text = "With a ride on, a click on the black pill opens your ride from Trips, Drive, Settings or Home, and the tab bar goes away again.",
		source = "CHANGELOG 2.4.0: 'A click on it opens your ride from anywhere.'",
		needs = { combat = "no", phone = "closed", role = "rider" },
		when = function(sit) return sit.ride == "invited" or sit.ride == "summoning" or sit.ride == "arrived" end,
		check = function(ctx)
			noFight(ctx)
			ensureOpen(ctx)
			clearCards(ctx)
			if ui(ctx).screen ~= "found" then ctx:na("the ride page is not what opens (" .. tostring(ui(ctx).screen) .. ")") end
			if not goHome(ctx) then ctx:fail("On the ride page there is no back arrow to the rest of Wuber.", onScreen(ctx)) end
			local starts = { "Home", "Trips", "Drive", "Settings" }
			for _, from in ipairs(starts) do
				if from == "Settings" then
					wantTab(ctx, "Ride")
					local gear = ui(ctx).gear
					if gear and ctx:visible(gear) then press(ctx, gear) ctx:advance(1) ctx:note("open Settings") end
				elseif from ~= "Home" then
					if not wantTab(ctx, from) then from = nil end
				end
				if from and (from ~= "Settings" or ui(ctx).settingsOpen) then
					local isl = pill(ctx)
					if not (isl and ctx:visible(isl)) then ctx:fail("From " .. from .. " with a ride on, the black pill is not on screen.", onScreen(ctx)) end
					press(ctx, isl) ctx:advance(1.5) ctx:note("click the pill from " .. from)
					if ui(ctx).screen ~= "found" or ui(ctx).settingsOpen then
						ctx:fail("You click the black pill from " .. from .. " and your ride does not open (the phone shows '" .. tostring(ui(ctx).screen) .. "' on the " .. tostring(ui(ctx).tab) .. " tab).", onScreen(ctx))
					end
					if not ui(ctx).barHidden then ctx:fail("Your ride opened from " .. from .. " and the tab bar is still showing under it.", onScreen(ctx)) end
					goHome(ctx)
				end
			end
		end,
	}

	promise{
		id = "design.tabs_hide_and_return",
		text = "During a live ride the tab bar is hidden; the arrow takes you to Home with the tabs and the ride carries on; the pill takes you back in; a cancelled ride brings the tabs back.",
		source = "CHANGELOG 2.4.0 (design round 4): 'During a ride the tabs make room for the ride. The arrow at the top left takes you back ... the black pill takes you back to it.'",
		needs = { combat = "no", phone = "closed", role = "rider" },
		when = function(sit) return sit.ride == "invited" or sit.ride == "summoning" or sit.ride == "arrived" end,
		check = function(ctx)
			noFight(ctx)
			ensureOpen(ctx)
			clearCards(ctx)
			if ui(ctx).screen ~= "found" then ctx:na("the ride page is not what opens (" .. tostring(ui(ctx).screen) .. ")") end
			if not ctx.W.UI.TabsHidden() then ctx:fail("A live ride is on the screen and the tab bar is still showing.", onScreen(ctx)) end
			for _, t in ipairs(ui(ctx).tabs or {}) do
				if t.button and ctx:visible(t.button) then ctx:fail("A live ride is on the screen and the " .. t.name .. " tab can still be clicked.") end
			end
			local st0 = rideState(ctx)
			if not goHome(ctx) then ctx:fail("On the ride page there is no back arrow.", onScreen(ctx)) end
			if ui(ctx).screen == "found" or ctx.W.UI.TabsHidden() then ctx:fail("You press the ride page's arrow and the tabs do not come back.", onScreen(ctx)) end
			if not rideState(ctx) or rideState(ctx) ~= st0 then ctx:fail("Leaving the ride page with the arrow ended or changed your ride (" .. tostring(st0) .. " -> " .. tostring(rideState(ctx)) .. ").") end
			local isl = pill(ctx)
			press(ctx, isl) ctx:advance(1.5) ctx:note("click the pill")
			if ui(ctx).screen ~= "found" or not ctx.W.UI.TabsHidden() then ctx:fail("The pill does not bring you back to your ride with the tabs away.", onScreen(ctx)) end
			local cancel = ctx.me:button("Cancel ride")
			if not (cancel and ctx:visible(cancel)) then ctx:na("no Cancel ride button in step " .. tostring(st0)) end
			press(ctx, cancel) ctx:advance(2) ctx:note("click Cancel ride")
			if rideState(ctx) and rideState(ctx) ~= "done" then ctx:na("the ride did not end from the Cancel click (state " .. tostring(rideState(ctx)) .. ")") end
			if ctx.W.UI.TabsHidden() or not (ui(ctx).tabbar and ctx:visible(ui(ctx).tabbar)) then
				ctx:fail("You cancel your ride and the tab bar does not come back.", onScreen(ctx))
			end
		end,
	}

	promise{
		id = "design.tabs_back_after_reload_midride",
		text = "After a /reload in the middle of a ride the tabs are still away on the ride page, and they come back when you leave it with the arrow.",
		source = "CHANGELOG 2.4.0 (design round 4: the tabs hide during a ride); round 4 report (tests/d4/d4_c_tabs)",
		needs = { combat = "no", phone = "closed", role = "rider" },
		when = function(sit) return sit.ride == "invited" or sit.ride == "summoning" or sit.ride == "arrived" end,
		check = function(ctx)
			noFight(ctx)
			ensureOpen(ctx)
			clearCards(ctx)
			if ui(ctx).screen ~= "found" then ctx:na("the ride page is not what opens") end
			local zoneBefore = ctx.W.ZoneHere and ctx.W.ZoneHere()
			local groupBefore = ctx.me.player.group ~= nil
			local st0 = rideState(ctx)
			ctx:reload()
			ctx:advance(3)
			ctx:note("ride before: " .. tostring(st0) .. ", after: " .. tostring(rideState(ctx)) .. "; group before " .. tostring(groupBefore) .. " after " .. tostring(ctx.me.player.group ~= nil))
			local zoneAfter = ctx.W.ZoneHere and ctx.W.ZoneHere()
			if zoneBefore ~= zoneAfter and (not rideState(ctx) or (ctx.W.ride and ctx.W.ride.endedBy == "auto")) then ctx:na("the fake game's /reload put the player back at the starting place (" .. tostring(zoneBefore) .. " -> " .. tostring(zoneAfter) .. "), which really ends an arrived ride") end
			if not rideState(ctx) then ctx:na("the ride did not survive the reload") end
			ensureOpen(ctx)
			clearCards(ctx)
			if ui(ctx).screen ~= "found" then ctx:fail("After a /reload mid-ride, opening Wuber does not show your ride (it shows '" .. tostring(ui(ctx).screen) .. "').", onScreen(ctx)) end
			if not ctx.W.UI.TabsHidden() then ctx:fail("After a /reload mid-ride the ride page shows with the tab bar under it.", onScreen(ctx)) end
			if not goHome(ctx) then ctx:fail("After a /reload the ride page has no back arrow.", onScreen(ctx)) end
			if ctx.W.UI.TabsHidden() or not (ui(ctx).tabbar and ctx:visible(ui(ctx).tabbar)) then
				ctx:fail("After a /reload mid-ride you leave the ride page with the arrow and the tabs stay away.", onScreen(ctx))
			end
		end,
	}

	---------------------------------------------------------------------------
	-- sheets
	---------------------------------------------------------------------------
	local function sheetReport(ctx)
		local sheets, dims = visibleSheets(ctx), dimsLeft(ctx)
		return #sheets, dims
	end
	promise{
		id = "design.sheets_leave_nothing",
		text = "Report a bug and the login tip open and close (x, a click beside them, Escape) and after closing and reopening the phone no sheet and no dim layer is left over the page.",
		source = "CHANGELOG 2.4.0: 'One kind of sheet: it rises from the tab bar ... and the page behind dims. The raincheck offer, Report a bug and the login tip are sheets now.'",
		needs = { combat = "no", phone = "closed", ride = "none" },
		check = function(ctx)
			noFight(ctx)
			ensureOpen(ctx)
			clearCards(ctx)
			local n0, d0 = sheetReport(ctx)
			-- the bug sheet, closed with its x
			slash(ctx, "/wuber bug", 1.2)
			local bugUp = ctx.W.UI.Bug and ctx.W.UI.Bug.Shown and ctx.W.UI.Bug.Shown()
			if not bugUp then ctx:fail("You type /wuber bug and no Report a bug sheet shows.", onScreen(ctx)) end
			local sheets = visibleSheets(ctx)
			local top
			for _, sh in ipairs(sheets) do if sh.close and ctx:visible(sh.close) then top = sh end end
			if not top then ctx:cannot("could not find the open sheet's x") end
			press(ctx, top.close) ctx:advance(1) ctx:note("close the bug sheet with its x")
			local n1, d1 = sheetReport(ctx)
			if ctx.W.UI.Bug.Shown() or n1 > n0 or d1 > d0 then
				ctx:fail("You close Report a bug with its x and a sheet or dim layer is still over the page (" .. n1 .. " sheets, " .. d1 .. " dims).", onScreen(ctx))
			end
			-- again, closed by Escape, then the phone closed and reopened
			slash(ctx, "/wuber bug", 1.2)
			ctx.me:pressEscape() ctx:advance(1) ctx:note("press Escape (bug sheet open)")
			if shown(ctx) then ctx.me:pressEscape() ctx:advance(1) ctx:note("press Escape again") end
			slash(ctx, "/wuber", 1.5)
			if not shown(ctx) then slash(ctx, "/wuber", 1.5) end
			clearCards(ctx)
			local bugNow = ctx.W.UI.Bug.Shown()
			local n2, d2 = sheetReport(ctx)
			if not bugNow and (n2 > n0 or d2 > d0) then
				ctx:fail("After closing Wuber with Escape over Report a bug and opening it again, no sheet is up yet the page is still dimmed (" .. n2 .. " sheets, " .. d2 .. " dims).", onScreen(ctx))
			end
			if bugNow and #visibleSheets(ctx) == 0 then ctx:fail("Wuber says the bug report is open after reopening, but no sheet shows.", onScreen(ctx)) end
			if bugNow then
				local top2
				for _, sh in ipairs(visibleSheets(ctx)) do if sh.close and ctx:visible(sh.close) then top2 = sh end end
				if top2 then press(ctx, top2.close) ctx:advance(1) end
			end
			-- a tip now, closed with its link, the phone closed and reopened
			slash(ctx, "/wuber tips", 1.2)
			local card = rawget(_G, "WuberTipCard") or ctx.me.env.WuberTipCard
			if card and ctx:visible(card) then
				local dont = card.never -- (the tip card's own link: the Skip the bird card has one of the same words)
				if dont and ctx:visible(dont) then press(ctx, dont) ctx:advance(1) ctx:note("Don't show again") end
				ctx:advance(20) -- the "Tips are off" line stays a few seconds by itself
				local n3, d3 = sheetReport(ctx)
				if ctx:visible(card) or n3 > 0 or d3 > 0 then
					ctx:fail("You press Don't show again on a login tip and the tip sheet or its dim layer stays over the page.", "card " .. tostring(card and ctx:visible(card)) .. " sheets " .. n3 .. "/" .. n0 .. " dims " .. d3 .. "/" .. d0 .. " " .. onScreen(ctx))
				end
			end
		end,
	}

	---------------------------------------------------------------------------
	-- Reduce motion and a fight
	---------------------------------------------------------------------------
	local function firstDriverName(ctx)
		local list = ctx.W.UI.Drivers and ctx.W.UI.Drivers() or {}
		local d = list[1]
		return d and (d.name or d.short or d.key)
	end
	-- the x of the first back arrow now (a page on its way slides it)
	-- (measured from the window's left edge: an unfolding window moves its left pane, which is not a page sliding)
	local function backX(ctx) local b = backs(ctx)[1] local w = ui(ctx).win if b and w then return (b:GetCenter()) - (w:GetLeft() or 0) end end
	local function openDriver(ctx)
		local n = firstDriverName(ctx)
		if not n then ctx:na("no driver listed") end
		local row = ctx.me:button(n) or ctx.me:button(n, { pattern = true })
		if not row then ctx:na("no clickable row for " .. tostring(n)) end
		press(ctx, row)
	end

	promise{
		id = "design.reduce_motion_no_slide",
		text = "With Reduce motion on, opening a driver's page does not slide in (it is in its place at once) and a sheet fades in place instead of rising.",
		source = "CHANGELOG 2.4.0: 'New setting, Settings > Sound and effects > Reduce motion: pages and sheets fade in place instead of sliding.'",
		needs = { combat = "no", phone = "closed", ride = "none", role = "rider" },
		when = function(sit) return sit.net ~= "none" and sit.net ~= "oldpeer" end,
		check = function(ctx)
			noFight(ctx)
			ensureOpen(ctx)
			clearCards(ctx)
			ctx.W.db.reduceMotion = true
			ctx:note("Reduce motion on")
			local n = firstDriverName(ctx)
			if not n then ctx:na("no driver listed") end
			openDriver(ctx)
			ctx:advance(0.03)
			local early = backX(ctx)
			ctx:advance(1.5)
			local late = backX(ctx)
			if not (early and late) then ctx:na("no back arrow on the driver's page") end
			if math.abs(early - late) > 1 then
				ctx:fail("With Reduce motion on, a driver's page still slides in (its arrow is " .. math.floor(math.abs(early - late)) .. " from its place just after you open it).")
			end
			-- a sheet
			slash(ctx, "/wuber bug", 0.03)
			local sh
			for _, s in ipairs(visibleSheets(ctx)) do sh = s end
			if sh and sh.card then
				local drop = math.abs((sh.card:GetBottom() or 0) - (sh:GetBottom() or 0))
				if drop > 1 then ctx:fail("With Reduce motion on, Report a bug rises from below instead of fading in place (" .. math.floor(drop) .. " below its place just after opening).") end
			end
		end,
	}

	promise{
		id = "design.combat_nothing_slides_nothing_stuck",
		text = "In a fight nothing slides (a page is in its place at once), and when the fight ends nothing is stuck half-way and the tab bar is back where it was.",
		source = "CHANGELOG 2.4.0: 'In a fight nothing slides.'; Window.lua header (a move ends at once when a fight starts)",
		needs = { combat = "no", phone = "closed", ride = "none", role = "rider" },
		when = function(sit) return sit.net ~= "none" and sit.net ~= "oldpeer" end,
		check = function(ctx)
			noFight(ctx)
			ensureOpen(ctx)
			clearCards(ctx)
			ctx.W.db.reduceMotion = false
			local tb = ui(ctx).tabbar
			local win0 = ui(ctx).win
			local before = tb and { tb:GetLeft() - win0:GetLeft(), tb:GetBottom() - win0:GetBottom(), tb:GetAlpha() } -- (against the window: it may move as it unfolds)
			ctx.w:enterCombat(ctx.me)
			ctx:advance(0.5) ctx:note("a fight starts")
			if not firstDriverName(ctx) then ctx:na("no driver listed") end
			openDriver(ctx)
			ctx:advance(0.03)
			local early = backX(ctx)
			ctx:advance(1.5)
			local mid = backX(ctx)
			if early and mid and math.abs(early - mid) > 1 then
				ctx:fail("In a fight a driver's page still slides in (its arrow is " .. math.floor(math.abs(early - mid)) .. " from its place just after you open it).")
			end
			ctx.w:leaveCombat(ctx.me)
			ctx:advance(2) ctx:note("the fight ends")
			local late = backX(ctx)
			if mid and late and math.abs(mid - late) > 1 then
				ctx:fail("After the fight the page moved again (its arrow went " .. math.floor(math.abs(mid - late)) .. " from where it stood in the fight): it was stuck half-way.")
			end
			local b = backs(ctx)
			if #b > 0 then press(ctx, b[1]) ctx:advance(1.5) end
			tb = ui(ctx).tabbar
			if before and tb then
				if not ctx:visible(tb) or math.abs(tb:GetBottom() - win0:GetBottom() - before[2]) > 1 or math.abs(tb:GetLeft() - win0:GetLeft() - before[1]) > 1 or tb:GetAlpha() < 0.99 then
					ctx:fail("After a fight and going back, the tab bar is not where it was (hidden, moved or faded).", onScreen(ctx))
				end
			end
		end,
	}

	---------------------------------------------------------------------------
	-- Wuber's own tooltip card
	---------------------------------------------------------------------------
	promise{
		id = "design.tip_card_hides",
		text = "Hovering a tab shows Wuber's own small tooltip card (not the game's), it goes when the mouse leaves, and it goes when the phone closes.",
		source = "CHANGELOG 2.4.0 (design round 4): 'Wuber's tooltips are its own small cards now, beside the thing they explain'; Widgets.lua WuberTip",
		needs = { combat = "no", phone = "closed", ride = "none" },
		check = function(ctx)
			noFight(ctx)
			ensureOpen(ctx)
			clearCards(ctx)
			local Hh, env = ctx.H, ctx.me.env
			local btn
			for _, t in ipairs(ui(ctx).tabs or {}) do if t.button and ctx:visible(t.button) then btn = t.button end end
			if not btn then ctx:cannot("no tab button to hover") end
			local gt = env.GameTooltip
			local gtBefore = gt and S(ctx)[gt] and S(ctx)[gt].shown
			pcall(Hh.runScript, btn, "OnEnter")
			ctx:advance(0.6)
			local card = env.WuberTip
			if not (card and ctx:visible(card)) then ctx:fail("You hover a tab and Wuber's tooltip card does not show.") end
			if gt and S(ctx)[gt] and S(ctx)[gt].shown and not gtBefore and S(ctx)[gt].wuberMirror == nil then -- (the fake game mirrors the card into its state: only a tooltip with no mirror counts)
				 ctx:fail("You hover a tab and the game's own tooltip shows as well as Wuber's card.") end
			pcall(Hh.runScript, btn, "OnLeave")
			ctx:advance(0.6)
			if card and ctx:visible(card) then ctx:fail("The mouse leaves a tab and its tooltip card stays on the screen.") end
			pcall(Hh.runScript, btn, "OnEnter")
			ctx:advance(0.6)
			ctx.me:pressEscape() ctx:advance(1) ctx:note("press Escape with a tip up")
			if shown(ctx) then ctx:na("Escape did not close the phone") end
			if card and ctx:visible(card) then ctx:fail("You close Wuber while a tooltip card is up and the card stays on the screen.") end
		end,
	}

	---------------------------------------------------------------------------
	-- Earnings key and the still portal
	---------------------------------------------------------------------------
	promise{
		id = "design.earnings_key",
		text = "The Earnings page's chart and its 'Best hours' squares have a 'less ... more' key beside them.",
		source = "CHANGELOG 2.4.0 (design round 4): 'Earnings: the chart and the \"Best hours\" squares run from pale to strong violet, with \"less\" and \"more\" beside them.'",
		needs = { phone = "drive_earnings", combat = "no", ride = "none" },
		check = function(ctx)
			noFight(ctx)
			if not shown(ctx) then ctx:cannot("the phone is not open") end
			ctx:advance(2.5)
			clearCards(ctx)
			local texts = ctx:texts()
			for _, t in ipairs(texts) do
				if t:find("your best times light up here", 1, true) then ctx:na("no open hours yet: the chart and squares show their empty words, no key is owed") end
			end
			local less, more = false, false
			for _, t in ipairs(texts) do if t == "less" then less = true elseif t == "more" then more = true end end
			if not (less and more) then ctx:fail("The Earnings page shows its chart with no 'less' and 'more' key (" .. tostring(less) .. "/" .. tostring(more) .. ").", onScreen(ctx)) end
		end,
	}

	local function portalTexture(ctx)
		for _, obj in ipairs(ctx.me.widgets) do
			local s = S(ctx)[obj]
			if s and s.otype == "Texture" and tostring(s.texture or ""):find("portal_still") and ctx:visible(obj) then return obj end
		end
	end
	local function angle(tex) local ok, a = pcall(tex.GetRotation, tex) return ok and a or nil end
	promise{
		id = "design.portal_still_with_reduce_motion",
		text = "The portal picture on your ride screen turns slowly, and stands still with Reduce motion on or Effects off.",
		source = "CHANGELOG 2.4.0 (design round 4): 'The portal on your ride screen is a new picture that turns slowly. \"Reduce motion\" keeps it still.' REPORT-design-4 item 15.",
		needs = { combat = "no", phone = "closed", role = "rider" },
		when = function(sit) return sit.ride == "summoning" or sit.ride == "arrived" or sit.ride == "invited" end,
		check = function(ctx)
			noFight(ctx)
			ensureOpen(ctx)
			clearCards(ctx)
			local t = portalTexture(ctx)
			if not t then ctx:na("no portal picture on this ride page (step " .. tostring(rideState(ctx)) .. ")") end
			if angle(t) == nil then ctx:cannot("the fake game does not report a texture's rotation") end
			if ctx.W.db.reduceMotion or (ctx.W.Theme and ctx.W.Theme.FxLevel and ctx.W.Theme.FxLevel() == "off") then ctx:na("already on Reduce motion or Effects off") end
			local a1 = angle(t)
			ctx:advance(2)
			local a2 = angle(t)
			if a1 == a2 then ctx:cannot("the fake game's clock does not turn the picture (no angle change in 2 s even with motion on)") end
			ctx.W.db.reduceMotion = true
			ctx:note("Reduce motion on")
			ctx:advance(0.5)
			local b1 = angle(t)
			ctx:advance(3)
			local b2 = angle(t)
			if b1 ~= b2 then ctx:fail("With Reduce motion on the portal picture on your ride screen still turns.", tostring(b1) .. " -> " .. tostring(b2)) end
		end,
	}
end
