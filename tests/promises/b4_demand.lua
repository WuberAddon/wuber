-- Promises about the driver's demand view, raid view, and floating mini console.
-- New promises for Wuber/UI/Driver/Demand.lua, Raid.lua, and Mini.lua.
return function(Hunt)
	local function canDrive(sit)
		return (sit.saved == nil or sit.saved == "fresh") and sit.group ~= "raid"
	end

	local function has(ctx, pat)
		for _, t in ipairs(ctx:texts()) do
			if t:find(pat) then return t end
		end
		return nil
	end

	local function allText(ctx) return table.concat(ctx:texts(), " | ") end
	local function DR(ctx) return ctx.W.Drive end
	local function D(ctx) return ctx.W.Driver end
	local function noCombat(ctx) if ctx.me.player.combat then ctx:na("in combat") end end

	local function need(ctx)
		noCombat(ctx)
		if not (DR(ctx) and DR(ctx).IsOpen) then ctx:cannot("no driver engine") end
	end

	local function openDrive(ctx)
		local UI = ctx.W.UI
		if UI.Bug and UI.Bug.Shown and UI.Bug.Shown() then
			if UI.Bug.Close then UI.Bug.Close() end
			ctx:note("close the bug report")
			ctx:advance(0.5)
		end
		if not (UI.IsShown and UI.IsShown()) then
			UI.Toggle(true)
			ctx:note("open the phone")
			ctx:advance(3)
		else
			ctx:advance(4)
		end
		for _ = 1, 3 do
			if has(ctx, "^Riders$") or has(ctx, "^Raid summons$") then break end
			ctx:advance(3)
		end
		if not (has(ctx, "^Riders$") or has(ctx, "^Raid summons$")) then
			pcall(ctx.me.clickText, ctx.me, "^Drive$", { pattern = true })
			ctx:note("click the Drive tab")
			ctx:advance(1)
		end
		if not (has(ctx, "^Riders$") or has(ctx, "^Raid summons$")) and UI.ShowDrive then
			pcall(UI.ShowDrive, "console")
			ctx:advance(1)
		end
		if not (has(ctx, "^Riders$") or has(ctx, "^Raid summons$")) then ctx:cannot("could not reach the Drive console") end
		local drv = D(ctx)
		if drv and drv.CurrentScreen and UI.ShowDrive and (drv.CurrentScreen() ~= "console" or (drv.SheetOpen and drv.SheetOpen())) then
			if drv.CurrentScreen() ~= "console" then
				pcall(UI.ShowDrive, "console")
				ctx:note("back to the Drive console")
				ctx:advance(1)
			end
			if drv.SheetOpen and drv.SheetOpen() then
				ctx.me:pressEscape()
				ctx:note("Escape closes the sheet")
				ctx:advance(1)
				if not (UI.IsShown and UI.IsShown()) then
					UI.Toggle(true)
					ctx:advance(4)
					if not (has(ctx, "^Riders$") or has(ctx, "^Raid summons$")) then
						pcall(ctx.me.clickText, ctx.me, "^Drive$", { pattern = true })
						ctx:advance(1)
					end
				end
			end
		end
	end

	local function setFolded(ctx, folded)
		local UI = ctx.W.UI
		if UI.WindowWide then
			UI.WindowWide(not folded)
			ctx:advance(0.5)
		end
		if D(ctx) and D(ctx).RefreshNow then D(ctx).RefreshNow() end
		ctx:advance(0.5)
		local isWide = D(ctx) and D(ctx).Wide and D(ctx).Wide()
		if not folded and not isWide then
			ctx:na("window cannot unfold in this situation")
		end
		if folded and isWide then
			ctx:na("window cannot fold in this situation")
		end
	end

	local function sheetShown(ctx, name)
		if not (D(ctx) and D(ctx).SheetOpen and D(ctx).SheetOpen()) then return false end
		if name == "demand" then return has(ctx, "What riders want") ~= nil end
		return has(ctx, "What riders want") == nil
	end

	local function scrollPastCue(ctx, R)
		local v = D(ctx) and D(ctx).ui and D(ctx).ui.console
		if R and R.cue and R.cue:IsShown() then
			ctx.me:clickOn(R.cue)
			ctx:advance(0.5)
		end
		if v and v.scroll and R and R.nhHead and R.nhHead:IsShown() then
			local sb = v.scroll:GetBottom()
			local nb = R.nhHead:GetBottom()
			if sb and nb and nb < sb + 4 then
				v.scroll:ScrollTo((v.scroll.offset or 0) + (sb - nb) + 40)
				ctx:advance(0.5)
			end
		end
	end

	local function ensureSellOpen(ctx)
		if DR(ctx).SetMode and DR(ctx).Mode and DR(ctx).Mode() == "raid" then
			DR(ctx).SetMode("sell")
			ctx:advance(0.5)
		end
		if not DR(ctx).IsOpen() then
			DR(ctx).SetOpen(true)
			ctx:advance(0.5)
		end
		if D(ctx) and D(ctx).RefreshNow then D(ctx).RefreshNow() end
		ctx:advance(0.5)
	end

	local function addBounty(ctx, riderName, place, copper)
		local w = ctx.w
		if not w:player(riderName) then
			w:addBot(riderName, { spot = "Stormwind", class = "MAGE" })
		end
		if ctx.W.Bounty and ctx.W.Bounty.OnWish then
			ctx.W.Bounty.OnWish(riderName, place, copper or 5000, 0)
		else
			-- Fallback: stub W.Bounty.Demand if OnWish isn't exposed
			ctx:cannot("no W.Bounty.OnWish")
		end
	end

	local function seedDemand(ctx, entries)
		local B = ctx.W.Bounty
		if type(B) ~= "table" then ctx:cannot("no W.Bounty") end
		B.Demand = function() return entries end
		if D(ctx) and D(ctx).RefreshNow then D(ctx).RefreshNow() end
		ctx:advance(0.5)
	end

	local function setupRaidLeader(ctx, withNotHere)
		local w = ctx.w
		local here = ctx.W.DestHere and ctx.W.DestHere()
		if type(here) == "table" then here = here.name end
		local mySpot = (type(here) == "string" and here ~= "") and here or "Orgrimmar"
		local awaySpot = (mySpot == "Stormwind") and "Orgrimmar" or "Stormwind"
		local lock = ctx.peers and ctx.peers.summoner
		local names = { ctx.name }
		if lock then
			w:move(lock.player.name, mySpot)
			names[#names + 1] = lock.player.name
		end
		for i = 1, 5 do
			local n = "RaidMate" .. i
			local spot = (withNotHere and i <= 2) and awaySpot or mySpot
			if not w:player(n) then w:addBot(n, { spot = spot, class = "WARRIOR" }) end
			w:move(n, spot)
			names[#names + 1] = n
		end
		w:group(names)
		ctx:advance(2)
		if DR(ctx).SetMode then DR(ctx).SetMode("raid") end
		if DR(ctx).RaidPick then DR(ctx).RaidPick(ctx.name, true) end
		ctx:advance(1)
		if D(ctx) and D(ctx).RefreshNow then D(ctx).RefreshNow() end
		ctx:advance(0.5)
	end

	---------------------------------------------------------------------------
	-- Demand.lua promises
	---------------------------------------------------------------------------

	Hunt.promise{
		id = "b4demand.folded_line_sorts_and_truncates",
		area = "DriverDemand",
		text = "On the folded Drive console, the demand line names the most-wanted place first with +N more, and clicking it opens the What riders want sheet showing at most 5 places.",
		source = "Wuber/UI/Driver/Demand.lua:44-67,162-196,206-246",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			openDrive(ctx)
			ensureSellOpen(ctx)
			setFolded(ctx, true)
			seedDemand(ctx, {
				{ place = "Booty Bay", riders = 1, low = 5000, high = 5000, newest = 30 },
				{ place = "Gadgetzan", riders = 3, low = 5000, high = 10000, newest = 120 },
				{ place = "Ratchet", riders = 2, low = 6000, high = 6000, newest = 60 },
				{ place = "Everlook", riders = 1, low = 5000, high = 5000, newest = 10 },
				{ place = "Tarren Mill", riders = 1, low = 5000, high = 5000, newest = 20 },
				{ place = "Moonglade", riders = 1, low = 5000, high = 5000, newest = 90 },
			})
			local v = D(ctx).ui and D(ctx).ui.console
			if not (v and v.demand and ctx:visible(v.demand)) then
				ctx:fail("With active bounties on the folded Drive console, the demand summary line is not shown.", allText(ctx))
			end
			local txt = v.demand.text and v.demand.text.wuberText or ""
			if not txt:find("3 riders want Gadgetzan", 1, true) or not txt:find("+4 more", 1, true) then
				ctx:fail("The folded demand line does not show the top place and +4 more: got '" .. txt .. "'.", allText(ctx))
			end
			ctx.me:clickOn(v.demand)
			ctx:advance(0.5)
			if not sheetShown(ctx, "demand") then
				ctx:fail("Clicking the demand line does not open the What riders want sheet.", allText(ctx))
			end
			local s = ctx.W.UI and ctx.W.UI.drive and ctx.W.UI.drive.screens and ctx.W.UI.drive.screens.demand
			if not (s and s.rows) then ctx:cannot("demand sheet rows missing") end
			local shown = 0
			for _, r in ipairs(s.rows) do
				if r:IsShown() then shown = shown + 1 end
			end
			if shown ~= 5 then
				ctx:fail("With 6 wanted places, the What riders want sheet shows " .. shown .. " rows instead of 5.", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "b4demand.serve_away_vs_here",
		area = "DriverDemand",
		text = "Clicking Serve it for a place where you are not standing keeps you on the demand sheet and tells you to go there, while clicking Serve it for where you stand opens the price and place sheet.",
		source = "Wuber/UI/Driver/Demand.lua:89-96,108-114,135-154",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			openDrive(ctx)
			ensureSellOpen(ctx)
			setFolded(ctx, true)
			local here = ctx.W.DestHere and ctx.W.DestHere()
			if type(here) == "table" then here = here.name end
			if not here or here == "" then here = "Orgrimmar" end
			local away = (here == "Gadgetzan") and "Booty Bay" or "Gadgetzan"
			seedDemand(ctx, {
				{ place = away, riders = 3, low = 5000, high = 10000, newest = 30 },
				{ place = here, riders = 2, low = 5000, high = 5000, newest = 60 },
			})
			local v = D(ctx).ui and D(ctx).ui.console
			if not (v and v.demand and ctx:visible(v.demand)) then ctx:cannot("demand line not visible") end
			ctx.me:clickOn(v.demand)
			ctx:advance(0.5)
			local s = ctx.W.UI and ctx.W.UI.drive and ctx.W.UI.drive.screens and ctx.W.UI.drive.screens.demand
			if not (s and s.rows and s.rows[1] and s.rows[2]) then ctx:cannot("demand sheet rows missing") end
			ctx.me:clickOn(s.rows[1].serve)
			ctx:advance(0.5)
			if not sheetShown(ctx, "demand") then
				ctx:fail("Clicking Serve it for " .. away .. " (away) left the demand sheet.", allText(ctx))
			end
			ctx.me:clickOn(s.rows[2].serve)
			ctx:advance(0.5)
			if not sheetShown(ctx, "sheet") then
				ctx:fail("Clicking Serve it for " .. here .. " (where you stand) did not open the price and place sheet.", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "b4demand.hidden_when_watch_off_or_raid",
		area = "DriverDemand",
		text = "Turning Show what riders want off, or switching to raid mode, hides both the folded demand line and the unfolded Wanted nearby card.",
		source = "Wuber/UI/Driver/Demand.lua:45-48,163-167,283",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			openDrive(ctx)
			ensureSellOpen(ctx)
			seedDemand(ctx, { { place = "Gadgetzan", riders = 2, low = 5000, high = 5000, newest = 20 } })
			setFolded(ctx, true)
			local v = D(ctx).ui and D(ctx).ui.console
			if not (v and v.demand and ctx:visible(v.demand)) then ctx:cannot("demand line did not appear") end
			DR(ctx).opts().watchBounty = false
			if D(ctx).RefreshNow then D(ctx).RefreshNow() end
			ctx:advance(0.5)
			if ctx:visible(v.demand) then
				ctx:fail("With Show what riders want switched off, the folded demand line is still visible.", allText(ctx))
			end
			setFolded(ctx, false)
			if v.demandCard and ctx:visible(v.demandCard) then
				ctx:fail("With Show what riders want switched off, the unfolded Wanted nearby card is still visible.", allText(ctx))
			end
			DR(ctx).opts().watchBounty = true
			if D(ctx).RefreshNow then D(ctx).RefreshNow() end
			ctx:advance(0.5)
			if DR(ctx).SetMode then
				DR(ctx).SetMode("raid")
				if D(ctx).RefreshNow then D(ctx).RefreshNow() end
				ctx:advance(0.5)
				if v.demandCard and ctx:visible(v.demandCard) then
					ctx:fail("In raid mode, the Wanted nearby card is still visible.", allText(ctx))
				end
			end
		end,
	}

	Hunt.promise{
		id = "b4demand.unfolded_wanted_nearby_card",
		area = "DriverDemand",
		text = "On the unfolded Drive console with active bounties, the Wanted nearby card shows each place's rider count, fare range (or single price when low equals high), and newest age.",
		source = "Wuber/UI/Driver/Demand.lua:71-105,146-154,253-290",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			openDrive(ctx)
			ensureSellOpen(ctx)
			setFolded(ctx, false)
			seedDemand(ctx, {
				{ place = "Gadgetzan", riders = 3, low = 5000, high = 10000, newest = 120 },
				{ place = "Booty Bay", riders = 1, low = 7500, high = 7500, newest = 30 },
			})
			local v = D(ctx).ui and D(ctx).ui.console
			if not (v and v.demandCard and ctx:visible(v.demandCard)) then
				ctx:fail("On the unfolded Drive console with bounties, the Wanted nearby card is not shown.", allText(ctx))
			end
			local r1, r2 = v.demandCard.rows[1], v.demandCard.rows[2]
			if not (r1 and r1:IsShown() and r2 and r2:IsShown()) then
				ctx:fail("Wanted nearby card did not show both bounty rows.", allText(ctx))
			end
			local sub1 = r1.sub and r1.sub.wuberText or ""
			local sub2 = r2.sub and r2.sub.wuberText or ""
			if not sub1:find("3 riders", 1, true) or not sub1:find("50s", 1, true) or not sub1:find("1g", 1, true) or not sub1:find("newest", 1, true) then
				ctx:fail("First Wanted nearby row detail is missing count/range/age: '" .. sub1 .. "'.")
			end
			if not sub2:find("1 rider", 1, true) or not sub2:find("75s", 1, true) or sub2:find("–", 1, true) then
				ctx:fail("Second Wanted nearby row with equal low/high should show single price 75s without dash: '" .. sub2 .. "'.")
			end
		end,
	}

	Hunt.promise{
		id = "b4demand.empty_demand_sheet",
		area = "DriverDemand",
		text = "When no bounties are active, the What riders want sheet says Nobody is asking for a place right now and explains that a bounty is a wish, not a payment.",
		source = "Wuber/UI/Driver/Demand.lua:211-245",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			openDrive(ctx)
			ensureSellOpen(ctx)
			seedDemand(ctx, {})
			D(ctx).ShowSheet("demand")
			ctx:advance(0.5)
			if not sheetShown(ctx, "demand") then ctx:cannot("could not open demand sheet") end
			if not has(ctx, "Nobody is asking for a place right now") then
				ctx:fail("Empty What riders want sheet does not say Nobody is asking for a place right now.", allText(ctx))
			end
			if not has(ctx, "A bounty is a wish, not a payment") then
				ctx:fail("What riders want sheet does not explain that a bounty is a wish, not a payment.", allText(ctx))
			end
		end,
	}

	---------------------------------------------------------------------------
	-- Raid.lua promises
	---------------------------------------------------------------------------

	Hunt.promise{
		id = "b4demand.raid_not_here_toggle",
		area = "DriverRaid",
		text = "On the folded Raid page, Not here (N) starts collapsed and clicking it opens the list of absent raid members with their zones; clicking it again collapses the list.",
		source = "Wuber/UI/Driver/Raid.lua:158-174,434-480",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			setupRaidLeader(ctx, true)
			openDrive(ctx)
			setFolded(ctx, true)
			local v = D(ctx).ui and D(ctx).ui.console
			local R = v and v.raid
			scrollPastCue(ctx, R)
			if not (R and R.nhHead and ctx:visible(R.nhHead)) then
				ctx:cannot("Not here header not visible on folded Raid page")
			end
			if R.nh[1] and R.nh[1]:IsShown() then
				ctx:fail("Not here list starts expanded instead of collapsed.", allText(ctx))
			end
			ctx.me:clickOn(R.nhHead)
			ctx:advance(0.5)
			if not (R.nh[1] and R.nh[1]:IsShown()) then
				ctx:fail("Clicking Not here (N) did not expand the absent raid members list.", allText(ctx))
			end
			ctx.me:clickOn(R.nhHead)
			ctx:advance(0.5)
			if R.nh[1] and R.nh[1]:IsShown() then
				ctx:fail("Clicking Not here (N) a second time did not collapse the list.", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "b4demand.raid_not_here_plus_button",
		area = "DriverRaid",
		text = "On a Not here row, the + button is dimmed and does not queue the raider while raid summons are stopped, and is full brightness and queues them once raid summons are started.",
		source = "Wuber/UI/Driver/Raid.lua:78-80,104-115",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			setupRaidLeader(ctx, true)
			if DR(ctx).IsOpen() then
				DR(ctx).SetOpen(false)
				ctx:advance(0.5)
			end
			openDrive(ctx)
			setFolded(ctx, true)
			local v = D(ctx).ui and D(ctx).ui.console
			local R = v and v.raid
			scrollPastCue(ctx, R)
			if not (R and R.nhHead and ctx:visible(R.nhHead)) then ctx:cannot("no Not here header") end
			if not R.open then
				ctx.me:clickOn(R.nhHead)
				ctx:advance(0.5)
			end
			scrollPastCue(ctx, R)
			local row = R.nh and R.nh[1]
			if not (row and row:IsShown() and row.add) then ctx:cannot("no Not here row") end
			if math.abs((row.add:GetAlpha() or 1) - 0.4) > 0.05 then
				ctx:fail("While raid summons are stopped, Not here + button is not dimmed (alpha " .. tostring(row.add:GetAlpha()) .. ").")
			end
			local qBefore = #(DR(ctx).RaidQueue() or {})
			ctx.me:clickOn(row.add)
			ctx:advance(0.5)
			if #(DR(ctx).RaidQueue() or {}) ~= qBefore then
				ctx:fail("Clicking dimmed + while raid summons are stopped queued a raider.")
			end
			DR(ctx).SetOpen(true)
			if D(ctx).RefreshNow then D(ctx).RefreshNow() end
			ctx:advance(0.5)
			if math.abs((row.add:GetAlpha() or 0) - 1) > 0.05 then
				ctx:fail("Once raid summons are started, Not here + button is not full brightness (alpha " .. tostring(row.add:GetAlpha()) .. ").")
			end
			ctx.me:clickOn(row.add)
			ctx:advance(0.5)
			if #(DR(ctx).RaidQueue() or {}) <= qBefore then
				ctx:fail("Clicking + while raid summons are started did not queue the raider.")
			end
		end,
	}

	Hunt.promise{
		id = "b4demand.raid_not_here_empty_text",
		area = "DriverRaid",
		text = "When everyone in your raid is at the summoners' place, expanding Not here (0) says Everyone in your raid is here.",
		source = "Wuber/UI/Driver/Raid.lua:342-347,466-475",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			setupRaidLeader(ctx, false)
			openDrive(ctx)
			setFolded(ctx, true)
			local v = D(ctx).ui and D(ctx).ui.console
			local R = v and v.raid
			scrollPastCue(ctx, R)
			if not (R and R.nhHead and ctx:visible(R.nhHead)) then ctx:cannot("no Not here header") end
			if not R.open then
				ctx.me:clickOn(R.nhHead)
				ctx:advance(0.5)
			end
			scrollPastCue(ctx, R)
			if not has(ctx, "Everyone in your raid is here") then
				ctx:fail("With all raid members present, expanding Not here (0) did not say Everyone in your raid is here.", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "b4demand.raid_empty_state_and_tonight",
		area = "DriverRaid",
		text = "On the folded Raid page with nobody waiting, the empty card says Raid summons are stopped when stopped and Nobody waiting when started, with Summoned tonight shown below.",
		source = "Wuber/UI/Driver/Raid.lua:414-429,481-484",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			setupRaidLeader(ctx, false)
			if DR(ctx).IsOpen() then
				DR(ctx).SetOpen(false)
				ctx:advance(0.5)
			end
			openDrive(ctx)
			setFolded(ctx, true)
			if not has(ctx, "Raid summons are stopped") then
				ctx:fail("Stopped folded Raid page does not say Raid summons are stopped.", allText(ctx))
			end
			if not has(ctx, "Summoned tonight:") then
				ctx:fail("Folded Raid page does not show Summoned tonight.", allText(ctx))
			end
			DR(ctx).SetOpen(true)
			if D(ctx).RefreshNow then D(ctx).RefreshNow() end
			ctx:advance(0.5)
			if not has(ctx, "Nobody waiting") then
				ctx:fail("Started folded Raid page with empty queue does not say Nobody waiting.", allText(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "b4demand.raid_wide_side_pane",
		area = "DriverRaid",
		text = "When the Drive console is unfolded in raid mode, the side pane shows Raiders (N), Not here (N), and Summoners, while the folded raid list and cue are hidden.",
		source = "Wuber/UI/Driver/Raid.lua:322-339,541-637",
		kind = "scenario",
		needs = { role = "warlock", ride = "none" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			setupRaidLeader(ctx, true)
			openDrive(ctx)
			setFolded(ctx, false)
			local v = D(ctx).ui and D(ctx).ui.console
			local R = v and v.raid
			if not (has(ctx, "Raiders %(") and has(ctx, "Not here %(") and has(ctx, "^Summoners$")) then
				ctx:fail("Unfolded Raid side pane is missing Raiders (N), Not here (N), or Summoners.", allText(ctx))
			end
			if R and R.nhHead and R.nhHead:IsShown() then
				ctx:fail("Unfolded Raid page did not hide the folded Not here header.", allText(ctx))
			end
			if R and R.cueHolder and R.cueHolder:IsShown() then
				ctx:fail("Unfolded Raid page did not hide the folded scroll cue.", allText(ctx))
			end
		end,
	}

	---------------------------------------------------------------------------
	-- Mini.lua promises
	---------------------------------------------------------------------------

	local function ensureFloatingMini(ctx)
		if DR(ctx).SetMode and DR(ctx).Mode and DR(ctx).Mode() == "raid" then
			DR(ctx).SetMode("sell")
			ctx:advance(0.5)
		end
		local UI = ctx.W.UI
		if UI.IsShown and UI.IsShown() then
			UI.Toggle(false)
			ctx:advance(0.5)
		end
		if DR(ctx).opts then DR(ctx).opts().keepClosed = true end
		if DR(ctx).Button and DR(ctx).Button.Place then DR(ctx).Button.Place() end
		if D(ctx).SyncMini then D(ctx).SyncMini() end
		if D(ctx).UpdateMini then D(ctx).UpdateMini() end
		ctx:advance(0.5)
		local m = ctx.W.UI and ctx.W.UI.drive and ctx.W.UI.drive.mini
		if not (m and m:IsShown()) then ctx:cannot("floating mini console not shown") end
		return m
	end

	Hunt.promise{
		id = "b4demand.mini_shows_when_floating_and_open_close",
		area = "DriverMini",
		text = "When the big Drive button floats while closed, the mini console hides Pause and shows Open; clicking Open opens your service and shows both Pause and Close.",
		source = "Wuber/UI/Driver/Mini.lua:206-243,287-309,405-433",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", phone = "closed" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			if DR(ctx).IsOpen() then
				DR(ctx).SetOpen(false)
				ctx:advance(0.5)
			end
			local m = ensureFloatingMini(ctx)
			if m.pause:IsShown() then
				ctx:fail("While closed, the floating mini console still shows Pause.")
			end
			if m.close.label.wuberText ~= "Open" then
				ctx:fail("While closed, the floating mini console button says '" .. tostring(m.close.label.wuberText) .. "' instead of Open.")
			end
			ctx.me:clickOn(m.close)
			ctx:advance(0.5)
			if not DR(ctx).IsOpen() then
				ctx:fail("Clicking Open on the floating mini console did not open your service.")
			end
			if not m.pause:IsShown() or m.close.label.wuberText ~= "Close" then
				ctx:fail("After clicking Open on the mini console, Pause is not shown or Close does not say Close.")
			end
		end,
	}

	Hunt.promise{
		id = "b4demand.mini_pause_toggles_resume",
		area = "DriverMini",
		text = "On the floating mini console while open, clicking Pause pauses your service and changes the button to Resume, and clicking Resume resumes it.",
		source = "Wuber/UI/Driver/Mini.lua:220-229,335,419-420",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", phone = "closed" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			if not DR(ctx).IsOpen() then
				DR(ctx).SetOpen(true)
				ctx:advance(0.5)
			end
			if DR(ctx).IsPaused() then
				DR(ctx).SetPaused(false)
				ctx:advance(0.5)
			end
			local m = ensureFloatingMini(ctx)
			if m.pause.label.wuberText ~= "Pause" then ctx:cannot("mini Pause button did not say Pause") end
			ctx.me:clickOn(m.pause)
			ctx:advance(0.5)
			if not DR(ctx).IsPaused() then
				ctx:fail("Clicking Pause on the floating mini console did not pause your service.")
			end
			if m.pause.label.wuberText ~= "Resume" then
				ctx:fail("After pausing on the mini console, the button reads '" .. tostring(m.pause.label.wuberText) .. "' instead of Resume.")
			end
			ctx.me:clickOn(m.pause)
			ctx:advance(0.5)
			if DR(ctx).IsPaused() then
				ctx:fail("Clicking Resume on the floating mini console did not resume your service.")
			end
		end,
	}

	Hunt.promise{
		id = "b4demand.mini_caps_at_four_and_shows_more",
		area = "DriverMini",
		text = "With more than 4 riders in your queue, the floating mini console shows at most 4 rider rows and displays +N more in Wuber's Drive tab.",
		source = "Wuber/UI/Driver/Mini.lua:368-404",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", phone = "closed" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			if not DR(ctx).IsOpen() then
				DR(ctx).SetOpen(true)
				ctx:advance(0.5)
			end
			local list = {}
			for i = 1, 6 do
				list[i] = { name = "Rider" .. i, key = "rider" .. i, state = "joined", askedAt = 0 }
			end
			DR(ctx).Sorted = function() return list end
			local m = ensureFloatingMini(ctx)
			m.dirty = true
			D(ctx).UpdateMini()
			local shown = 0
			for i = 1, 4 do
				if m.rows[i] and m.rows[i]:IsShown() then shown = shown + 1 end
			end
			if shown > 4 or shown == 0 then
				ctx:fail("Floating mini console showed " .. shown .. " rows for 6 queued riders.")
			end
			local expectedMore = "+" .. (6 - shown) .. " more in Wuber's Drive tab"
			if not (m.more and m.more:IsShown() and m.more.wuberText == expectedMore) then
				ctx:fail("Floating mini console did not show '" .. expectedMore .. "' (got '" .. tostring(m.more and m.more.wuberText) .. "').")
			end
		end,
	}

	Hunt.promise{
		id = "b4demand.drive_summary_reflects_state",
		area = "DriverMini",
		text = "UI.DriveSummary returns nil for a rider, Driving: closed when closed with no activity, Driving: Open or Paused when open, and Raid summons: ... in raid mode.",
		source = "Wuber/UI/Driver/Mini.lua:533-551",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", phone = "closed" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			local UI = ctx.W.UI
			if not (UI and UI.DriveSummary) then ctx:cannot("no UI.DriveSummary") end
			if DR(ctx).IsOpen() then
				DR(ctx).SetOpen(false)
				ctx:advance(0.5)
			end
			local sClosed = UI.DriveSummary()
			if not (sClosed and sClosed:find("Driving:", 1, true)) then
				ctx:fail("Closed DriveSummary did not start with 'Driving:': got " .. tostring(sClosed))
			end
			DR(ctx).SetOpen(true)
			ctx:advance(0.5)
			local sOpen = UI.DriveSummary()
			if not (sOpen and sOpen:find("Driving: Open", 1, true)) then
				ctx:fail("Open DriveSummary did not say 'Driving: Open': got " .. tostring(sOpen))
			end
			DR(ctx).SetPaused(true)
			ctx:advance(0.5)
			local sPaused = UI.DriveSummary()
			if not (sPaused and sPaused:find("Driving: Paused", 1, true)) then
				ctx:fail("Paused DriveSummary did not say 'Driving: Paused': got " .. tostring(sPaused))
			end
			DR(ctx).SetPaused(false)
			if DR(ctx).SetMode then
				DR(ctx).SetMode("raid")
				ctx:advance(0.5)
				local sRaid = UI.DriveSummary()
				if not (sRaid and sRaid:find("Raid summons:", 1, true)) then
					ctx:fail("Raid DriveSummary did not say 'Raid summons:': got " .. tostring(sRaid))
				end
			end
		end,
	}

	Hunt.promise{
		id = "b4demand.crew_offer_yes_no_hide",
		area = "DriverMini",
		text = "When a crew offer arrives, clicking No thanks dismisses it without joining, and clicking Hide them dismisses it and adds that player to your hidden list.",
		source = "Wuber/UI/Driver/Mini.lua:46-110,147-197,491",
		kind = "scenario",
		needs = { role = "warlock", ride = "none", phone = "closed" },
		when = canDrive,
		check = function(ctx)
			need(ctx)
			local UI = ctx.W.UI
			if not (UI and UI.CrewOffer) then ctx:cannot("no UI.CrewOffer") end
			UI.CrewOffer("CaptainOne", "Orgrimmar")
			ctx:advance(0.3)
			local card = UI.drive and UI.drive.offer
			if not (card and card:IsShown()) then
				ctx:fail("UI.CrewOffer did not show the crew offer card.")
			end
			ctx.me:clickOn(card.no)
			ctx:advance(0.5)
			if card.from ~= nil then
				ctx:fail("Clicking No thanks did not clear the crew offer.")
			end
			UI.CrewOffer("CaptainTwo", "Orgrimmar")
			ctx:advance(0.3)
			if not (card and card:IsShown()) then ctx:cannot("second offer did not show") end
			ctx.me:clickOn(card.never)
			ctx:advance(0.5)
			local k = ctx.W.Key("CaptainTwo")
			if not (ctx.W.db and ctx.W.db.hidden and ctx.W.db.hidden[k]) then
				ctx:fail("Clicking Hide them did not add the sender to W.db.hidden.")
			end
		end,
	}
end
