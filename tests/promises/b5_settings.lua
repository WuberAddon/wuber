-- Bug hunt wave 4 promises for Settings Find, Pages, and Panel
-- (Wuber/UI/Settings/Find.lua, Pages.lua, Panel.lua).
-- Prefix: b5settings.
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

	local function inCombat(ctx) return ctx.me.player.combat and true or false end
	local function kit(ctx) local K = ctx:mod("UI.Kit") return K and K.ui or {} end
	local function seen(ctx) return "on screen: " .. table.concat(ctx:texts(), " | ") end

	local function hasText(ctx, pat, plain)
		for _, t in ipairs(ctx:texts()) do
			if t:find(pat, 1, plain) then return t end
		end
		return nil
	end

	local function openSettings(ctx, where)
		if inCombat(ctx) then ctx:na("in combat") end
		local UI = ctx.W.UI
		UI.OpenSettings(where)
		ctx:advance(0.6)
		if not UI.SettingsShown() then ctx:na("Settings could not open here") end
	end

	-- 1. Find: summary updates between Simple and Advanced modes
	promise{
		id = "b5settings.find_summary_updates_with_mode",
		area = "Settings",
		text = "Settings section summaries show Simple-mode words ('Tips', 'Size') in Simple mode and Advanced-mode words ('Auto-accept', 'wide pages') in Advanced mode.",
		source = "Wuber/UI/Settings/Find.lua:71-106",
		kind = "scenario",
		check = function(ctx)
			local Find = ctx:mod("UI.Settings.Find")
			if not Find or not Find.summary then ctx:cannot("no UI.Settings.Find.summary") end
			openSettings(ctx)
			local adv = ctx.W.Advanced()
			local rSum = Find.summary("riding")
			local wSum = Find.summary("window")
			if adv then
				if not rSum:find("Auto-accept", 1, true) or not wSum:find("wide pages", 1, true) then
					ctx:fail("In Advanced mode, Settings section summaries did not show Advanced fields.", rSum .. " | " .. wSum)
				end
			else
				if not rSum:find("Tips", 1, true) or wSum:find("wide pages", 1, true) then
					ctx:fail("In Simple mode, Settings section summaries did not match Simple mode.", rSum .. " | " .. wSum)
				end
			end
		end,
	}

	-- 2. Find: Driving rows hidden from non-Warlock riders who haven't used Drive
	promise{
		id = "b5settings.find_driving_hidden_for_nonwarlock_rider",
		area = "Settings",
		text = "For a rider who is not a Warlock and has not used Drive, searching Settings for 'advert' does not return Driving section rows.",
		source = "Wuber/UI/Settings/Find.lua:10,113-140",
		kind = "scenario",
		when = function(sit) return sit.role == "rider" and sit.saved ~= "acct4_main" end,
		check = function(ctx)
			local Find = ctx:mod("UI.Settings.Find")
			if not Find or not Find.match then ctx:cannot("no UI.Settings.Find.match") end
			openSettings(ctx)
			local Rows = ctx:mod("UI.Settings.Rows")
			local st = Rows and Rows.st
			local drivingShown = false
			for _, fr in ipairs(st and st.chain or {}) do
				if fr.page == "driving" and fr:IsShown() then drivingShown = true break end
			end
			if drivingShown then ctx:na("Driving section is shown for this character") end
			local matches = Find.match("advert")
			for _, m in ipairs(matches) do
				if m.section == "Driving" then
					ctx:fail("Searching Settings for 'advert' returned a Driving row even though Driving is hidden.", tostring(m.label))
				end
			end
		end,
	}

	-- 3. Find: Advanced-only match marked adv in Simple mode
	promise{
		id = "b5settings.find_advanced_rows_marked_when_simple",
		area = "Settings",
		text = "In Simple mode, searching Settings for an Advanced-only setting marks that result as requiring Advanced mode.",
		source = "Wuber/UI/Settings/Find.lua:128-140",
		kind = "scenario",
		needs = { advanced = "off" },
		check = function(ctx)
			if ctx.W.Advanced() then ctx:na("Advanced mode is on") end
			local Find = ctx:mod("UI.Settings.Find")
			if not Find or not Find.match then ctx:cannot("no UI.Settings.Find.match") end
			openSettings(ctx)
			local matches = Find.match("Auto-accept")
			if #matches == 0 then ctx:na("no Auto-accept match in this state") end
			local foundAdv = false
			for _, m in ipairs(matches) do
				if m.label and m.label:find("Auto-accept", 1, true) and m.adv then foundAdv = true break end
			end
			if not foundAdv then
				ctx:fail("In Simple mode, searching for 'Auto-accept' did not mark the match as adv-locked.", tostring(matches[1] and matches[1].adv))
			end
		end,
	}

	-- 4. Find: No settings match message and clear restores home
	promise{
		id = "b5settings.find_no_matches_message",
		area = "Settings",
		text = "Typing a non-matching query in Settings search shows 'No settings match', and clearing it restores the section list.",
		source = "Wuber/UI/Settings/Find.lua:3,400-500",
		kind = "scenario",
		check = function(ctx)
			openSettings(ctx)
			local Rows = ctx:mod("UI.Settings.Rows")
			local st = Rows and Rows.st
			local f = st and st.find
			if not f or not f.edit or not ctx:visible(f.edit) then ctx:na("Settings search box not visible") end
			ctx.me:typeText(f.edit, "zzznotasetting999")
			ctx:advance(0.4)
			local noMatch = hasText(ctx, "No settings match", true)
			if f.clear and ctx:visible(f.clear) then
				ctx.me:clickOn(f.clear)
			else
				ctx.me:typeText(f.edit, "")
			end
			ctx:advance(0.4)
			local cleared = not hasText(ctx, "No settings match", true)
			if not noMatch then
				ctx:fail("Searching Settings for 'zzznotasetting999' did not show 'No settings match'.", seen(ctx))
			end
			if not cleared then
				ctx:fail("Clearing the Settings search box did not remove 'No settings match'.", seen(ctx))
			end
		end,
	}

	-- 5. Find: Search box never steals focus on open
	promise{
		id = "b5settings.find_search_never_steals_focus",
		area = "Settings",
		text = "Opening Settings never gives keyboard focus to the search box automatically.",
		source = "Wuber/UI/Settings/Find.lua:10-11",
		kind = "scenario",
		check = function(ctx)
			openSettings(ctx)
			local Rows = ctx:mod("UI.Settings.Rows")
			local f = Rows and Rows.st and Rows.st.find
			if not f or not f.edit then ctx:cannot("no Settings search box") end
			if f.edit.HasFocus and f.edit:HasFocus() then
				ctx:fail("Opening Settings automatically gave keyboard focus to the search box.", "HasFocus=true")
			end
		end,
	}

	-- 6. Pages: WuberOptionsPage combat guard
	promise{
		id = "b5settings.pages_options_frame_combat_guard",
		area = "Settings",
		text = "Clicking 'Open Wuber settings' on the game's AddOns Wuber page during combat does not open Settings and says to try after combat.",
		source = "Wuber/UI/Settings/Pages.lua:166-178",
		kind = "scenario",
		when = function(sit) return sit.combat ~= "in" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("already in combat") end
			local Pages = ctx:mod("UI.Settings.Pages")
			local f = Pages and Pages.optionsFrame and Pages.optionsFrame()
			if not f or not f.openBtn then ctx:na("no WuberOptionsPage") end
			local UI = ctx.W.UI
			if UI.SettingsShown() then UI.CloseSettings(true) ctx:advance(0.4) end
			if UI.IsShown() then UI.Toggle(false) ctx:advance(0.4) end
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", ctx.me.env.UIParent, "TOPLEFT", 20, -20)
			f:Show()
			ctx.w:enterCombat(ctx.me)
			ctx:advance(0.2)
			if not ctx:visible(f.openBtn) then
				ctx.w:leaveCombat(ctx.me)
				f:Hide()
				ctx:na("options page button not visible")
			end
			ctx.me:clickOn(f.openBtn)
			ctx:advance(0.3)
			local msg = f.status and f.status:GetText()
			local opened = UI.SettingsShown()
			ctx.w:leaveCombat(ctx.me)
			f:Hide()
			ctx:advance(0.2)
			if opened then
				ctx:fail("Clicking 'Open Wuber settings' on WuberOptionsPage opened Settings during combat.", seen(ctx))
			end
			if not msg or not msg:find("In combat", 1, true) then
				ctx:fail("Clicking 'Open Wuber settings' during combat did not show the combat message.", tostring(msg))
			end
		end,
	}

	-- 7. Pages: WuberOptionsPage opens Settings out of combat
	promise{
		id = "b5settings.pages_options_frame_opens_settings",
		area = "Settings",
		text = "Out of combat, clicking 'Open Wuber settings' on the game's AddOns Wuber page opens Wuber's Settings panel.",
		source = "Wuber/UI/Settings/Pages.lua:166-178",
		kind = "scenario",
		when = function(sit) return sit.combat ~= "in" end,
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local Pages = ctx:mod("UI.Settings.Pages")
			local f = Pages and Pages.optionsFrame and Pages.optionsFrame()
			if not f or not f.openBtn then ctx:na("no WuberOptionsPage") end
			local UI = ctx.W.UI
			if UI.SettingsShown() then UI.CloseSettings(true) ctx:advance(0.4) end
			if UI.IsShown() then UI.Toggle(false) ctx:advance(0.4) end
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", ctx.me.env.UIParent, "TOPLEFT", 20, -20)
			f:Show()
			if not ctx:visible(f.openBtn) then
				f:Hide()
				ctx:na("options page button not visible")
			end
			local hit = ctx.me:clickOn(f.openBtn)
			ctx:advance(0.6)
			local opened = UI.SettingsShown()
			f:Hide()
			UI.CloseSettings(true)
			ctx:advance(0.3)
			if hit ~= f.openBtn then ctx:na("options page button covered by another frame") end
			if not opened then
				ctx:fail("Clicking 'Open Wuber settings' out of combat did not open Wuber's Settings.", seen(ctx))
			end
		end,
	}

	-- 8. Pages: mayTravel only true when folded and already shown
	promise{
		id = "b5settings.pages_may_travel_only_folded_open",
		area = "Settings",
		text = "Pages.mayTravel is false when the window was closed or unfolded, and true when the window was already open and folded.",
		source = "Wuber/UI/Settings/Pages.lua:70-78",
		kind = "scenario",
		check = function(ctx)
			local Pages = ctx:mod("UI.Settings.Pages")
			if not Pages or not Pages.mayTravel then ctx:cannot("no Pages.mayTravel") end
			local ui = kit(ctx)
			if not ui.win then ctx:cannot("no window") end
			if Pages.mayTravel(ui, false) then
				ctx:fail("Pages.mayTravel returned true when the window was not previously shown.", "wasShown=false")
			end
		end,
	}

	-- 9. Panel: UI.OpenSettings("drive") and ("bell") open Driving
	promise{
		id = "b5settings.panel_open_alias_drive_and_bell",
		area = "Settings",
		text = "Opening Settings with 'drive' or 'bell' opens the Driving section directly.",
		source = "Wuber/UI/Settings/Panel.lua:23-25",
		kind = "scenario",
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			openSettings(ctx, "drive")
			local d1 = hasText(ctx, "Post an advert", true)
			ctx.W.UI.CloseSettings(true)
			ctx:advance(0.3)
			openSettings(ctx, "bell")
			local d2 = hasText(ctx, "Post an advert", true)
			ctx.W.UI.CloseSettings(true)
			ctx:advance(0.3)
			if not d1 or not d2 then
				ctx:fail("UI.OpenSettings('drive') or ('bell') did not show the Driving section.", string.format("d1=%s d2=%s", tostring(d1), tostring(d2)))
			end
		end,
	}

	-- 10. Panel: UI.OpenHelp shows Help over Settings; UI.OpenSettings closes Help
	promise{
		id = "b5settings.panel_open_help_and_close_help",
		area = "Settings",
		text = "Opening Help shows 'How Wuber finds drivers' over Settings, and opening Settings while Help is up closes Help.",
		source = "Wuber/UI/Settings/Panel.lua:753-754,1148",
		kind = "scenario",
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local UI = ctx.W.UI
			openSettings(ctx)
			UI.OpenHelp()
			ctx:advance(0.6)
			local helpUp = UI.HelpShown()
			local settingsKept = UI.SettingsShown()
			local titleOk = hasText(ctx, "How Wuber finds drivers", true)
			UI.OpenSettings()
			ctx:advance(0.4)
			local helpClosedBySettings = not UI.HelpShown()
			UI.CloseSettings(true)
			ctx:advance(0.3)
			if not helpUp or not settingsKept or not titleOk then
				ctx:fail("UI.OpenHelp did not open Help over Settings.", string.format("help=%s settings=%s", tostring(helpUp), tostring(settingsKept)))
			end
			if not helpClosedBySettings then
				ctx:fail("UI.OpenSettings did not close Help.", seen(ctx))
			end
		end,
	}

	-- 11. Panel: Escape closes Settings/Help without closing main window when unfolded or subpage
	promise{
		id = "b5settings.panel_escape_closes_settings_and_help",
		area = "Settings",
		text = "Pressing Escape while Help is open closes Help cleanly.",
		source = "Wuber/UI/Settings/Panel.lua:13-16",
		kind = "scenario",
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			local UI = ctx.W.UI
			UI.OpenHelp()
			ctx:advance(0.6)
			if not UI.HelpShown() then ctx:cannot("Help did not open") end
			ctx.me:pressEscape()
			ctx:advance(0.6)
			if UI.HelpShown() then
				UI.CloseHelp(true)
				ctx:fail("Pressing Escape did not close Help.", seen(ctx))
			end
		end,
	}

	-- 12. Panel: Advanced toggle while Settings is open refreshes cleanly
	promise{
		id = "b5settings.panel_advanced_toggle_updates_sections",
		area = "Settings",
		text = "Toggling Advanced mode while Settings is open updates the visible Settings sections and rows cleanly.",
		source = "Wuber/UI/Settings/Panel.lua:29",
		kind = "scenario",
		check = function(ctx)
			if inCombat(ctx) then ctx:na("in combat") end
			openSettings(ctx)
			local oldAdv = ctx.W.db and ctx.W.db.advanced
			local wasAdv = ctx.W.Advanced()
			if ctx.W.db then ctx.W.db.advanced = not wasAdv end
			ctx.W.Fire("SETTINGS", "advanced")
			ctx:advance(0.4)
			local stillShown = ctx.W.UI.SettingsShown()
			if ctx.W.db then ctx.W.db.advanced = oldAdv end
			ctx.W.Fire("SETTINGS", "advanced")
			ctx:advance(0.3)
			if not stillShown then
				ctx:fail("Toggling Advanced mode closed Settings unexpectedly.", seen(ctx))
			end
		end,
	}
end
