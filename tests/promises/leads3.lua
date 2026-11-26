-- Promises from the bug hunt's third lead list (owner: LEADS-3). Each is a Google lead (two places of Wuber that disagree)
-- that a read of the code showed to be a real player-facing difference. Ids: leads.c###_short_name.
return function(Hunt)
	local function shown(ctx)
		local UI = ctx.W.UI
		return type(UI.IsShown) == "function" and UI.IsShown() == true
	end
	local function openPhone(ctx)
		if not shown(ctx) then
			if ctx.me.player.combat then ctx:na("in combat: the phone does not open") end
			ctx.me:slash("/wuber")
			ctx:note("/wuber")
			ctx:advance(0.3)
			if not shown(ctx) then ctx:cannot("the phone did not open on /wuber") end
			ctx:advance(2.2)
		end
	end
	local function kitUi(ctx)
		local K = ctx:mod("UI.Kit")
		return K and K.ui or {}
	end
	local function clickTab(ctx, name)
		for _, tab in ipairs(kitUi(ctx).tabs or {}) do
			if tab.name == name and tab.button then
				ctx.me:clickOn(tab.button)
				ctx:advance(0.8)
				ctx:note("click the " .. name .. " tab")
				return kitUi(ctx).tab == name
			end
		end
		return false
	end
	local function plain(ctx)
		local out = {}
		for _, t in ipairs(ctx:texts()) do out[#out + 1] = (t:gsub("|T.-|t", "")) end
		return out
	end
	local function onScreen(ctx) return "on screen: " .. table.concat(plain(ctx), " | ") end

	Hunt.promise{
		id = "leads.c137_unpaid_in_trips",
		area = "Trips",
		text = "A ride you ended without paying is not saved in Trips: the list and its trip count leave it out.",
		source = "Google lead C137: Core/Stats.lua:63-65 and the Done screen (an unpaid ride isn't saved in Trips) vs UI/Rider/Trips.lua:686-718 (fillHistory lists every W.db.rides entry)",
		kind = "scenario",
		needs = { role = "rider", ride = "arrived", combat = "no" },
		check = function(ctx)
			local W = ctx.W
			if type(W.EndRide) ~= "function" then ctx:cannot("no W.EndRide") end
			if not W.EndRide("rider") then ctx:na("the ride could not be ended by hand") end
			ctx:advance(1)
			local last = W.db.rides[#W.db.rides]
			if not (last and last.unpaid) then ctx:na("the ended ride was not saved as unpaid") end
			openPhone(ctx)
			if kitUi(ctx).tab ~= "Trips" and not clickTab(ctx, "Trips") then ctx:cannot("the Trips tab did not open") end
			ctx:advance(2)
			local m = ctx:mod("UI.Rider.Trips")
			if not (m and type(m.view) == "function") then ctx:cannot("no UI.Rider.Trips.view") end
			local live, unpaid = 0, 0
			for _, r in ipairs(m.view().rows or {}) do
				if r.live and r.trip then
					live = live + 1
					if r.trip.unpaid then unpaid = unpaid + 1 end
				end
			end
			if unpaid > 0 then
				ctx:fail("You end a ride without paying, the Done screen says it is not saved in Trips, and Trips lists it as one of your trips.", live .. " rows, " .. unpaid .. " unpaid; " .. onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "leads.c133_drive_open_tip_ring",
		area = "Tips",
		text = "The Show me ring for the tip \"Press Open and riders come to you\" sits on the Open button, not on the Drive tab.",
		source = "Google lead C133: UI/TipTexts.lua:34-35,119 (target go = UI.Kit ui.go) vs UI/Kit.lua:62-67 / UI/Driver/Console.lua:466 (ui.go only on the Drive console's own table)",
		kind = "scenario",
		needs = { role = "warlock", phone = "drive", combat = "no" },
		check = function(ctx)
			local TT = ctx:mod("UI.TipTexts")
			if not (TT and type(TT.Target) == "function") then ctx:cannot("no UI.TipTexts.Target") end
			local D = ctx.W.Driver
			local v = D and D.ui and D.ui.console
			local open = v and v.open
			if not (open and ctx:visible(open)) then ctx:na("the Open button is not on screen (console not showing Open)") end
			local f = TT.Target("drive_open")
			local function labelOf() return open.label and open.label.GetText and open.label:GetText() or "?" end
			if labelOf() == "Close" then
				ctx.me:clickOn(open)
				ctx:advance(1.5)
				local env = ctx.me and ctx.me.env
				if env and env.StaticPopup_FindVisible and env.StaticPopup_FindVisible("WUBER_CLOSE_RIDERS") then
					local dlg = env.StaticPopupDialogs and env.StaticPopupDialogs.WUBER_CLOSE_RIDERS
					env.StaticPopup_Hide("WUBER_CLOSE_RIDERS")
					if dlg and dlg.OnAccept then dlg.OnAccept() end
					ctx:advance(1)
				end
				ctx:note("click Close (the player stops driving, so the pill says Open)")
			end
			local label = labelOf()
			ctx:note("the console's big pill says: " .. tostring(label))
			if label ~= "Open" then ctx:na("the console's big pill says " .. tostring(label) .. ", not Open") end
			if f == nil then ctx:na("the tip has no ring target now") end
			if f ~= open then
				ctx:fail("You press Show me on the tip about the Open button and the ring lands on the Drive tab, not on Open.", "target is not the console's Open pill; " .. onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "leads.c146_drive_gear_no_driving",
		area = "Settings",
		text = "On the Drive tab the Settings button opens the driving options its tooltip promises.",
		source = "Google lead C146: UI/Window.lua:457,460-462 (Drive tab gear: \"Every driving option\") vs UI/Settings/Panel.lua:465-469,628-634 (no Driving section unless a Warlock or a driver or helper)",
		kind = "scenario",
		needs = { role = "rider", phone = "drive", combat = "no" },
		check = function(ctx)
			local K = kitUi(ctx)
			if K.tab ~= "Drive" then ctx:na("the phone is not on the Drive tab") end
			local gear = K.gear
			if not (gear and ctx:visible(gear)) then ctx:cannot("the Settings button is not on screen") end
			ctx.me:clickOn(gear)
			ctx:advance(1)
			ctx:note("click the Settings button on the Drive tab")
			if not K.settingsOpen then ctx:cannot("Settings did not open") end
			-- 2.4: the Driving page lists rows such as "Invite riders who whisper me" (section headings drop the page name)
			for _, t in ipairs(plain(ctx)) do
				if t:find("Invite riders who whisper me", 1, true) or t:find("Whispers and Wuber app requests", 1, true) then return end
			end
			ctx:fail("You are on the Drive tab, tap Settings (its tooltip says every driving option is there) and no driving option is on the page.", onScreen(ctx))
		end,
	}

	Hunt.promise{
		id = "leads.c136_toast_dodges_closed_phone",
		area = "Toasts",
		text = "With Wuber closed, a toast appears in its usual place at the top of the screen, not moved aside for a window that is not there.",
		source = "Google lead C136: UI/Toasts.lua:243-251 (toasts only dodge the open window) vs UI/Phone.lua:228-233 (ui.phone is a child that stays shown when the window closes)",
		kind = "scenario",
		needs = { phone = "closed", size = "1920x1080@1.5", combat = "no" },
		check = function(ctx)
			local UI = ctx.W.UI
			if not shown(ctx) then openPhone(ctx) end
			UI.Toggle(false)
			ctx:advance(1)
			ctx:note("close the phone")
			if shown(ctx) then ctx:na("the phone did not close") end
			if type(UI.ToastPlace) ~= "function" or type(UI.Toast) ~= "function" then ctx:cannot("no UI.ToastPlace") end
			local ph = kitUi(ctx).phone
			if not ph then ctx:na("the phone frame is not built") end
			local x, top = UI.ToastPlace()
			ctx:note("toast spot with Wuber closed: x " .. tostring(x) .. ", top " .. tostring(top))
			if x ~= 0 or top ~= -18 then
				ctx:fail("Wuber is closed and a toast turns up beside or above where the window would be, instead of at the top of the screen.", "toast offset x " .. tostring(x) .. ", top " .. tostring(top) .. " (usual 0, -18)")
			end
		end,
	}

	Hunt.promise{
		id = "leads.c118_largest_group_number",
		area = "Settings",
		text = "Settings > Driving > Largest group shows the group size Wuber really uses.",
		source = "Google lead C118: UI/Settings/Rows.lua:574-582 (#DR.Crew() >= 4 means 10) vs Drive/Core.lua:797-802 (DR.MaxGroup: me + crew >= 3 means 10)",
		kind = "scenario",
		needs = { role = "warlock", combat = "no" },
		check = function(ctx)
			local W = ctx.W
			local DR = W.Drive
			if not (DR and type(DR.SetCrewMember) == "function" and type(DR.MaxGroup) == "function") then ctx:cannot("no Drive crew API") end
			-- two helpers in the crew (the Crew screen's add does the same), "Largest group" left on auto
			DR.SetCrewMember("Helper One", "helper", true)
			DR.SetCrewMember("Helper Two", "helper", true)
			ctx:note("add two helpers to the crew")
			local o = DR.opts()
			if type(o) == "table" and (tonumber(o.maxGroup) or 0) >= 3 then ctx:na("Largest group is set by hand") end
			local used = DR.MaxGroup()
			openPhone(ctx)
			W.UI.OpenSettings("drive")
			ctx:advance(1)
			ctx:note("open Settings > Driving")
			local n
			for _, t in ipairs(plain(ctx)) do
				local v = t:match("^(%d+) people$")
				if v then n = tonumber(v) end
			end
			if not n then ctx:cannot("the Largest group value is not on screen") end
			if n ~= used then
				ctx:fail(("You have two helpers; Wuber keeps your group to %d people, but Settings > Driving > Largest group says %d people."):format(used, n), onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "leads.c114_queue_under_safety_card",
		area = "Ride",
		text = "On the way, the queue line is not drawn at the same spot as the safety warning card.",
		source = "Google lead C114: UI/Rider/Ride.lua:894 (the queue is never shown with the safety card) vs Ride.lua:832-834, 912-945 (queueTick ignores s.alert)",
		kind = "scenario",
		needs = { role = "rider", ride = "invited", autoAccept = "off", combat = "no" },
		check = function(ctx)
			local W = ctx.W
			local r = W.ride
			if not (r and r.driverKey and W.drivers and W.drivers[r.driverKey]) then ctx:na("no ride with a heard driver") end
			-- the driver says it has 2 riders ahead, and its beacon reports a hot drop (PvP) at the summon spot
			r.position, r.eta = 2, 90
			W.drivers[r.driverKey].danger = 2
			W.drivers[r.driverKey].dangerSecs = 30
			W.Fire("RIDE", r)
			openPhone(ctx)
			ctx:advance(1)
			local WinMod = ctx:mod("UI.Window")
			local sc = WinMod and WinMod.screens and WinMod.screens.found
			if not (sc and sc.queue and sc.alert) then ctx:cannot("the ride screen is not reachable") end
			if not ctx:visible(sc.alert) then ctx:na("the safety card is not showing") end
			if not ctx:visible(sc.queue) then ctx:na("the queue line is not showing") end
			-- they fail only when the two rectangles really overlap (2.4 stacks the queue line above the card, 6 px apart)
			local function rect(f)
				local l, b, w, h = f:GetLeft(), f:GetBottom(), f:GetWidth(), f:GetHeight()
				if not (l and b and w and h) then return nil end
				local s = f:GetEffectiveScale() or 1
				return { l = l * s, b = b * s, r = (l + w) * s, t = (b + h) * s }
			end
			local q, a = rect(sc.queue), rect(sc.alert)
			if not (q and a) then ctx:cannot("the queue line or the safety card has no place on screen") end
			if q.l < a.r and a.l < q.r and q.b < a.t and a.b < q.t then
				ctx:fail("A driver has a queue and a PvP warning: the queue line and the amber safety card are drawn on top of each other.",
					("queue %d,%d to %d,%d; card %d,%d to %d,%d; %s"):format(q.l, q.b, q.r, q.t, a.l, a.b, a.r, a.t, onScreen(ctx)))
			end
		end,
	}

	Hunt.promise{
		id = "leads.c119_reset_pos_in_combat",
		area = "Window",
		text = "If Settings says the window is back in its usual place, it is.",
		source = "Google lead C119/C147: UI/Settings/Panel.lua:395-412 (Reset in combat skips moving the window but still toasts) vs UI/Window.lua:158-162 (PlaceWindow refuses in combat)",
		kind = "scenario",
		needs = { role = "rider", phone = "settings_window", pos = "corner", combat = "after" },
		check = function(ctx)
			local W = ctx.W
			local K = kitUi(ctx)
			local win = K.win
			local b = W.UI.settings and W.UI.settings.controls and W.UI.settings.controls.resetPos
			if not (win and b) then ctx:cannot("no window or no Window position row") end
			if not ctx.me.player.combat then ctx:na("not in combat") end
			local function pt() local p, _, rp, x, y = win:GetPoint(1) return tostring(p) .. "/" .. tostring(rp) .. "/" .. tostring(x) .. "/" .. tostring(y) end
			local before = pt()
			if W.db and W.db.pos == nil then ctx:na("no saved window place to reset") end
			if ctx:visible(b) then ctx.me:clickOn(b) else pcall(b.Click, b) end
			ctx:advance(0.5)
			ctx:note("click Reset on Window position, in combat")
			local said
			for _, t in ipairs(plain(ctx)) do if t:find("Window back in its usual place", 1, true) then said = true end end
			if not said then ctx:na("the toast did not show") end
			if pt() == before then
				ctx:fail("You press Reset on Window position during a fight, Wuber says the window is back in its usual place, and it has not moved.", "window point still " .. before .. "; " .. onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "leads.c112_leave_group_never_offered",
		area = "Ride",
		text = "While your ride waits for the driver's invite and you are in another group, the Ride screen tells you to leave that group. (job 146: the button is on the Ride screen, Ride.lua:794-798; the check opens it first.)",
		source = "Google lead C112: UI/Rider/Ride.lua:774-780 and Confirm.lua:661 (read rv.grouped) vs Net/Rides.lua:45-51,207-219 (r.grouped is never set)",
		kind = "scenario",
		needs = { role = "rider", ride = "requested", group = "solo", combat = "no" },
		check = function(ctx)
			local W = ctx.W
			local r = W.ride
			if not (r and (r.state == "requesting" or r.state == "accepted")) then ctx:na("the ride is not waiting for an invite (" .. tostring(r and r.state) .. ")") end
			if not (ctx.w.addBot and ctx.w.group) then ctx:cannot("the fake game cannot add group members") end
			-- the rider joins two friends' party after asking for the summon
			local names = { ctx.me.player.name }
			for i, n in ipairs({ "Pal One", "Pal Two" }) do
				local p = ctx.w:addBot(n, { spot = "Orgrimmar", class = (i == 1) and "MAGE" or "PRIEST" })
				names[#names + 1] = p.name
			end
			ctx.w:group(names)
			ctx:advance(2)
			ctx:note("the rider joins a party of 3 after asking")
			if not W.InGroup() then ctx:cannot("the rider is not in a group") end
			openPhone(ctx)
			ctx:advance(1)
			-- (job 146) a player closes Settings and taps the Ride tab: the leave button lives there
			if W.UI.SettingsShown and W.UI.SettingsShown() then
				W.UI.CloseSettings(true)
				ctx:note("close Settings")
				ctx:advance(1)
			end
			if kitUi(ctx).tab ~= "Ride" and not clickTab(ctx, "Ride") then ctx:na("the Ride screen cannot be reached from here (tab " .. tostring(kitUi(ctx).tab) .. ")") end
			for _, t in ipairs(plain(ctx)) do
				local low = t:lower()
				if low:find("leave your group", 1, true) or low:find("leave it so", 1, true) then return end
			end
			ctx:fail("You asked for a summon, then joined another group, and the ride screen never tells you to leave it so the driver can invite you.", onScreen(ctx))
		end,
	}

	Hunt.promise{
		id = "leads.c148_ride_here_after_ride",
		area = "Window",
		text = "The world map's Ride here opens Wuber on that place's drivers, even when your last ride's Done screen has not been dismissed.",
		source = "Google lead C148: UI/Map/Map.lua:413 (Ride here tooltip) vs UI/Window.lua:304-317,642-652 (UI.Show(\"book\") sets no ui.peek, so the ride screen wins)",
		kind = "scenario",
		needs = { role = "rider", ride = "ended", combat = "no" },
		check = function(ctx)
			local W = ctx.W
			local UI = W.UI
			if type(UI.Show) ~= "function" then ctx:cannot("no UI.Show") end
			local r = W.ride
			if not r or r.state ~= "done" then ctx:na("the ride is not at its Done screen (" .. tostring(r and r.state) .. ")") end
			if W.RideActive and W.RideActive() then ctx:na("a ride is still active") end
			-- the Ride here button on the world map does exactly this
			UI.Show("book", "Orgrimmar")
			ctx:advance(1)
			ctx:note("Ride here on the world map: UI.Show(book, Orgrimmar)")
			local K = kitUi(ctx)
			if K.screen ~= "home" then
				ctx:fail("You press Ride here on the world map after a ride and Wuber opens on the old ride's screen (" .. tostring(K.screen) .. "), not on the drivers to that place.", onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "leads.c135_world_tip_when_narrow",
		area = "Tips",
		text = "The tip about the World view only comes to players whose window can show it, and its Show me opens it.",
		source = "Google lead C135: UI/TipTexts.lua:20-21,59-64 (Show me opens the World view) vs UI/Rider/WorldMap.lua:1245-1249 (never built while folded)",
		kind = "scenario",
		needs = { role = "rider", ride = "none", fold = "narrow", phone = "closed", combat = "no" },
		check = function(ctx)
			local Tips = ctx:mod("UI.Tips")
			local WM = ctx:mod("UI.Rider.WorldMap")
			if not (Tips and type(Tips.ShowNow) == "function" and type(Tips.Eligible) == "function" and WM and WM.cache) then ctx:cannot("no tips or World view module") end
			local F = ctx.W.UI.Fold
			if F and type(F.IsUnfolded) == "function" and F.IsUnfolded() then ctx:na("the window unfolded in spite of Always narrow") end
			local eligible = false
			for _, t in ipairs(Tips.Eligible()) do if t.id == "world_view" then eligible = true end end
			if not eligible then return end -- not offered to this player: fine
			openPhone(ctx)
			ctx:advance(1)
			local ok = Tips.ShowNow("world_view")
			ctx:note("the World tip comes up")
			ctx:advance(1)
			if not ok then ctx:na("the tip card did not show") end
			local card = Tips.Card()
			if not (card and card.show and ctx:visible(card.show)) then ctx:na("no Show me button on screen") end
			ctx.me:clickOn(card.show)
			ctx:advance(1)
			ctx:note("click Show me on the World tip")
			for _, wm in pairs(WM.cache.maps) do
				if wm.mode == "world" and wm.view and ctx:visible(wm.view) then return end
			end
			ctx:fail("Your window is set to Always narrow, a tip says Tap World, and Show me leaves you on Home with no World view anywhere.", onScreen(ctx))
		end,
	}
end
