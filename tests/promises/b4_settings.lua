-- Promises about Settings, Search, Simple/Advanced views, Help and Options page (lane c4).
-- Written from docs/PLAYER-GUIDE.md, Settings/Help tooltips and inferred behaviour of UI.Settings.*.
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

	local function settingsMod(ctx)
		return ctx:mod("UI.Settings.Rows")
	end

	local function settingsUp(ctx)
		local st = ctx.W.UI and ctx.W.UI.settings
		return st and st.controls and ui(ctx).settingsOpen == true and st or nil
	end

	local function closeBug(ctx)
		local B = ctx.W.UI and ctx.W.UI.Bug
		if type(B) == "table" and type(B.Shown) == "function" and B.Shown() and type(B.Close) == "function" then
			B.Close()
			ctx:note("close the bug report")
			ctx:advance(0.5)
		end
	end

	local function openSettings(ctx, section)
		closeBug(ctx)
		if not settingsUp(ctx) then
			ctx.me:slash("/wuber help")
			ctx:note("/wuber help")
			ctx:advance(2.4)
		end
		local st = settingsUp(ctx)
		if not st then ctx:cannot("/wuber help did not open Settings") end
		local offer
		pcall(function() offer = ui(ctx).rcOffer end)
		if offer and offer.IsShown and offer:IsShown() then
			ctx:na("the rain check offer card is up over Settings until the player answers it")
		end
		if section and type(ctx.W.UI.OpenSettings) == "function" then
			ctx.W.UI.OpenSettings(section)
			ctx:advance(1)
			ctx:note("open the " .. section .. " section of Settings")
			st = settingsUp(ctx) or st
		end
		return st
	end

	local function openSettingsHome(ctx)
		local st = openSettings(ctx)
		if type(ctx.W.UI.OpenSettings) == "function" then
			ctx.W.UI.OpenSettings()
			ctx:advance(1)
		end
		return settingsUp(ctx) or st
	end

	local function press(ctx, obj)
		ctx.me:clickOn(obj)
	end

	local function typeInto(ctx, st, word)
		local box = st.find and st.find.box and st.find.box.edit
		if not box then ctx:cannot("no search box in Settings") end
		ctx.me:type(box, word, false)
		ctx:advance(0.6)
		ctx:note("type \"" .. word .. "\" in the settings search")
	end

	local function matches(ctx, st)
		local out = {}
		for _, b in ipairs((st.find and st.find.items) or {}) do
			if b.m and ctx:visible(b) then out[#out + 1] = b end
		end
		return out
	end

	local function onScreen(ctx)
		return "on screen: " .. table.concat(ctx:texts(), " | ")
	end

	Hunt.promise{
		id = "b4settings.search_question", area = "Settings",
		text = "Typing a question like \"how do I turn off sounds?\" into the Settings search still finds the Sounds row.",
		source = "docs/PLAYER-GUIDE.md (\"Ask or search: understands a question. Type 'how do I turn off sounds?'\")",
		kind = "scenario",
		check = function(ctx)
			local st = openSettingsHome(ctx)
			typeInto(ctx, st, "how do I turn off sounds?")
			local found = false
			for _, b in ipairs(matches(ctx, st)) do
				if b.m.label == "Sounds" then found = true break end
			end
			if not found then
				ctx:fail("You type \"how do I turn off sounds?\" in the Settings search and Sounds is not listed.", onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "b4settings.search_clear_x", area = "Settings",
		text = "Clicking the X button inside the Settings search box clears your search text and brings back the Settings list.",
		source = "Wuber/UI/Settings/Find.lua:351 (tooltip: \"Esc or the x clears it.\")",
		kind = "scenario",
		check = function(ctx)
			local st = openSettingsHome(ctx)
			typeInto(ctx, st, "sound")
			local f = st.find
			if not (f and f.box and f.box.clear and ctx:visible(f.box.clear)) then
				ctx:fail("You type \"sound\" in the Settings search and the X clear button does not show.", onScreen(ctx))
			end
			press(ctx, f.box.clear)
			ctx:advance(0.6)
			ctx:note("click the X button in the Settings search box")
			if (f.box.edit:GetText() or "") ~= "" then
				ctx:fail("You click the X button in the Settings search box and your typed word stays in the box.")
			end
			if #matches(ctx, st) > 0 or ctx:visible(f.none) then
				ctx:fail("You click the X button in the Settings search box and search results stay on screen.", onScreen(ctx))
			end
			if not st.wide and not ctx:visible(f.home) then
				ctx:fail("You click the X button in the folded Settings search box and the Settings home does not come back.", onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "b4settings.search_why_matches", area = "Settings",
		text = "When a search match only matched by its description or keywords rather than its title, the result card shows a \"matches:\" line naming the matched word.",
		source = "inferred (Wuber/UI/Settings/Find.lua:545-561)",
		kind = "scenario",
		check = function(ctx)
			local st = openSettingsHome(ctx)
			typeInto(ctx, st, "mute")
			local soundItem
			for _, b in ipairs(matches(ctx, st)) do
				if b.m.label == "Sounds" then soundItem = b break end
			end
			if not soundItem then
				ctx:fail("You type \"mute\" in the Settings search and Sounds is not listed.", onScreen(ctx))
			end
			if not (soundItem.why and ctx:visible(soundItem.why)) then
				ctx:fail("You type \"mute\" in the Settings search and the Sounds result does not show why it matched.", onScreen(ctx))
			end
			local whyText = soundItem.why:GetText() or ""
			if not whyText:find("matches: mute", 1, true) then
				ctx:fail(("You type \"mute\" in the Settings search and the match reason says \"%s\" instead of \"matches: mute\"."):format(whyText))
			end
		end,
	}

	Hunt.promise{
		id = "b4settings.search_match_opens_section", area = "Settings",
		text = "Clicking a search match opens that setting's section with its control visible.",
		source = "inferred (Wuber/UI/Settings/Panel.lua:1333)",
		kind = "scenario",
		check = function(ctx)
			local st = openSettingsHome(ctx)
			typeInto(ctx, st, "sound")
			local soundItem
			for _, b in ipairs(matches(ctx, st)) do
				if b.m.label == "Sounds" then soundItem = b break end
			end
			if not soundItem then
				ctx:fail("You type \"sound\" in the Settings search and Sounds is not listed.", onScreen(ctx))
			end
			press(ctx, soundItem)
			ctx:advance(0.8)
			ctx:note("click the Sounds search match")
			local ctl = st.controls.sound
			if not (ctl and ctx:visible(ctl)) then
				ctx:fail("You click the Sounds search match and the Sounds switch is not shown.", onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "b4settings.quick_switches_sync", area = "Settings",
		text = "Flipping a quick switch on the Settings home also flips the matching switch inside its section.",
		source = "docs/PLAYER-GUIDE.md (\"Related switches share one row\")",
		kind = "scenario",
		when = function(sit) return is(sit, "combat", "no") end,
		check = function(ctx)
			if ctx.me.player.combat then ctx:na("in combat") end
			local st = openSettingsHome(ctx)
			if st.wide then ctx:na("unfolded Settings has no home quick switches") end
			local quickRow
			for _, r in ipairs((st.find and st.find.quick) or {}) do
				if r.key == "sound" and ctx:visible(r) then quickRow = r break end
			end
			if not quickRow then ctx:cannot("no Sounds quick switch on Settings home") end
			if st.find and st.find.home and st.find.home.ScrollTo then
				st.find.home:ScrollTo(st.find.home.scrollMax or 400, true)
				ctx:advance(0.2)
			end
			local before = st.controls.sound.get() == true
			press(ctx, quickRow.switch)
			ctx:advance(0.6)
			ctx:note("click the Sounds quick switch on Settings home")
			if (st.controls.sound.get() == true) == before then
				ctx:fail("You flip the Sounds quick switch on Settings home and the Sounds setting does not change.")
			end
			openSettings(ctx, "sound")
			if (st.controls.sound.on == true) == before then
				ctx:fail("You flip the Sounds quick switch on Settings home, open Sound and effects, and the Sounds switch still looks unchanged.")
			end
		end,
	}

	Hunt.promise{
		id = "b4settings.back_arrow_navigation", area = "Settings",
		text = "In a folded Settings section, clicking the back arrow returns to the Settings home, and clicking it again closes Settings.",
		source = "Wuber/UI/Settings/Panel.lua:124-127 (Back tooltip)",
		kind = "scenario",
		check = function(ctx)
			local st = openSettings(ctx, "map")
			if st.wide then ctx:na("unfolded Settings has no section back step") end
			if not (st.back and ctx:visible(st.back)) then ctx:cannot("no Back button in Settings") end
			press(ctx, st.back)
			ctx:advance(0.8)
			ctx:note("click Back from Map section")
			if not (ctx.W.UI.SettingsShown() and st.find and ctx:visible(st.find.home)) then
				ctx:fail("You click Back inside a folded Settings section and it does not return to the Settings home.", onScreen(ctx))
			end
			press(ctx, st.back)
			ctx:advance(0.8)
			ctx:note("click Back on Settings home")
			if ctx.W.UI.SettingsShown() then
				ctx:fail("You click Back on the Settings home and Settings stays open.")
			end
		end,
	}

	Hunt.promise{
		id = "b4settings.unfolded_nav_switches_section", area = "Settings",
		text = "When Wuber is unfolded, clicking a section in the left-hand Settings list switches the right-hand pane to that section.",
		source = "inferred (Wuber/UI/Settings/Panel.lua:1402-1416)",
		kind = "scenario",
		check = function(ctx)
			local st = openSettingsHome(ctx)
			if not st.wide then ctx:na("Settings is folded on this window") end
			if not (st.nav and ctx:visible(st.nav)) then ctx:fail("Settings is unfolded and the left-hand section list is not shown.") end
			local soundRow
			for _, b in ipairs(st.nav.rows or {}) do
				if b.key == "sound" and ctx:visible(b) then soundRow = b break end
			end
			if not soundRow then ctx:cannot("no Sound and effects row in unfolded nav") end
			press(ctx, soundRow)
			ctx:advance(0.6)
			ctx:note("click Sound and effects in the unfolded nav")
			if st.sec ~= "sound" or not ctx:visible(st.controls.sound) then
				ctx:fail("You click Sound and effects in the unfolded Settings list and the Sound switch does not show.", onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "b4settings.window_size_slider_and_reset", area = "Settings",
		text = "Changing Window size in Settings > This window scales the window, and clicking Reset puts it back to its usual size with an Undo option.",
		source = "Wuber/UI/Settings/Panel.lua:451,495 (Window size and Reset tooltips); docs/PLAYER-GUIDE.md (Undo button)",
		kind = "scenario",
		when = function(sit) return is(sit, "combat", "no") end,
		check = function(ctx)
			if ctx.me.player.combat then ctx:na("in combat") end
			local st = openSettings(ctx, "window")
			local sl, rst = st.controls.scale, st.controls.resetPos
			if not (sl and rst) then ctx:cannot("no Window size slider or Reset button") end
			sl:SetValue(1.4)
			local up = sl:GetScript("OnMouseUp")
			if up then up(sl) end
			ctx:advance(0.4)
			ctx:note("set Window size to 140%")
			if math.abs((ctx.W.db.scale or 1) - 1.4) > 0.05 then
				ctx:fail(("You set Window size to 140%% and the saved scale is %s."):format(tostring(ctx.W.db.scale)))
			end
			press(ctx, rst)
			ctx:advance(0.8)
			ctx:note("click Reset beside Window size")
			if ctx.W.db.scale ~= nil then
				ctx:fail(("You click Reset beside Window size and the saved scale is still %s."):format(tostring(ctx.W.db.scale)))
			end
			local winScale = ui(ctx).win and ui(ctx).win:GetScale() or 1
			if math.abs((sl.value or 0) - winScale) > 0.05 then
				ctx:fail(("You click Reset beside Window size and the slider still reads %.2f while the window scale is %.2f."):format(tonumber(sl.value) or 0, tonumber(winScale) or 0))
			end
			if not (type(ctx.W.UI.UndoPending) == "function" and ctx.W.UI.UndoPending()) then
				ctx:fail("You click Reset after changing Window size and no Undo option appears.")
			end
		end,
	}

	Hunt.promise{
		id = "b4settings.wide_pages_narrow_and_reset", area = "Settings",
		text = "Setting Wide pages to Always narrow keeps Settings phone-sized, and clicking Reset beside it puts Wide pages back to Auto.",
		source = "Wuber/UI/Settings/Rows.lua:1110-1150 (Wide pages and Reset tooltips)",
		kind = "scenario",
		when = function(sit) return is(sit, "combat", "no") end,
		check = function(ctx)
			if ctx.me.player.combat then ctx:na("in combat") end
			local st = openSettings(ctx, "window")
			if not (type(ctx.W.Advanced) == "function" and ctx.W.Advanced() == true) then
				if st.controls.advanced then
					press(ctx, st.controls.advanced)
					ctx:advance(0.8)
					ctx:note("turn on Advanced mode")
				else
					ctx:cannot("cannot turn on Advanced mode")
				end
			end
			local fw, rst = st.controls.foldWide, st.controls.foldReset
			if not (fw and rst and ctx:visible(fw)) then ctx:cannot("Wide pages control is not visible") end
			local narrowBtn
			for _, b in ipairs(fw.buttons or {}) do
				if b.value == "narrow" then narrowBtn = b break end
			end
			if not narrowBtn then ctx:cannot("no Always narrow segment button") end
			press(ctx, narrowBtn)
			ctx:advance(0.8)
			ctx:note("click Always narrow")
			local win = ui(ctx).win
			if st.wide or (win and win:GetWidth() > 370) then
				ctx:fail(("You set Wide pages to Always narrow and Settings stays wide (width %s)."):format(tostring(win and win:GetWidth())))
			end
			press(ctx, rst)
			ctx:advance(0.8)
			ctx:note("click Reset beside Wide pages")
			if fw.value ~= "auto" then
				ctx:fail(("You click Reset beside Wide pages and it stays on \"%s\" instead of Auto."):format(tostring(fw.value)))
			end
		end,
	}

	Hunt.promise{
		id = "b4settings.help_show_a_tip", area = "Settings",
		text = "Clicking Show a tip on the Help page shows a tip on the Ride tab (or tells you in chat why none can show right now).",
		source = "Wuber/UI/Settings/Panel.lua:980 (Show a tip tooltip)",
		kind = "scenario",
		when = function(sit) return is(sit, "combat", "no") and is(sit, "ride", "none") end,
		check = function(ctx)
			if ctx.me.player.combat then ctx:na("in combat") end
			local st = openSettings(ctx)
			if not (ctx.W.UI.OpenHelp and ctx.W.UI.OpenHelp("settings")) then ctx:cannot("Help did not open") end
			ctx:advance(0.8)
			ctx:note("open Help")
			if ctx.W.UI.ScrollHelp then
				ctx.W.UI.ScrollHelp(-20)
				ctx:advance(1.2)
			end
			local tipBtn = st.help and st.help.tip
			if not (tipBtn and ctx:visible(tipBtn)) then ctx:cannot("no Show a tip button on Help") end
			local chat0 = #(ctx.me.chatLines or {})
			press(ctx, tipBtn)
			ctx:advance(1.2)
			ctx:note("click Show a tip")
			local tipsMod = ctx:mod("UI.Tips")
			local card = tipsMod and type(tipsMod.Card) == "function" and tipsMod.Card()
			local tipShown = card and ctx:visible(card) == true
			local printed = #(ctx.me.chatLines or {}) > chat0
			if not tipShown and not printed then
				ctx:fail("You click Show a tip on the Help page and neither a tip card nor a chat message appears.", onScreen(ctx))
			end
		end,
	}

	Hunt.promise{
		id = "b4settings.help_url_readonly", area = "Settings",
		text = "The \"Where to get Wuber\" address box on the Help page keeps the CurseForge address even if you type into it.",
		source = "Wuber/UI/Settings/Panel.lua:940-962 (Where to get Wuber tooltip)",
		kind = "scenario",
		check = function(ctx)
			local st = openSettings(ctx)
			if not (ctx.W.UI.OpenHelp and ctx.W.UI.OpenHelp("settings")) then ctx:cannot("Help did not open") end
			ctx:advance(0.8)
			local box = st.help and st.help.urlBox
			if not (box and box.edit) then ctx:cannot("no Where to get Wuber box on Help") end
			local want = tostring(ctx.W.UPDATE_URL or "")
			if want == "" then ctx:cannot("no UPDATE_URL configured") end
			ctx.me:type(box.edit, "not-the-url", false)
			ctx:advance(0.4)
			ctx:note("type into the Where to get Wuber box")
			local got = box.edit:GetText() or ""
			if got ~= want then
				ctx:fail(("You type into \"Where to get Wuber\" on the Help page and the address changes to \"%s\" instead of staying \"%s\"."):format(got, want))
			end
		end,
	}

	Hunt.promise{
		id = "b4settings.options_page_opens_settings", area = "Settings",
		text = "Clicking \"Open Wuber settings\" on the game's Options > AddOns > Wuber page opens Wuber's Settings window (or says it is in combat during a fight).",
		source = "docs/PLAYER-GUIDE.md (\"Open Wuber settings\"); Wuber/UI/Settings/Pages.lua:166-180",
		kind = "scenario",
		check = function(ctx)
			local pages = ctx:mod("UI.Settings.Pages")
			local f = pages and type(pages.optionsFrame) == "function" and pages.optionsFrame()
			if not f then ctx:na("this client has no Options > AddOns Wuber page") end
			if ui(ctx).win and ctx:visible(ui(ctx).win) then
				ctx.W.UI.Toggle(false)
				ctx:advance(0.5)
			end
			f:ClearAllPoints()
			f:SetPoint("BOTTOMLEFT", ctx.me.env.UIParent, "BOTTOMLEFT", 16, 16)
			f:SetFrameStrata("DIALOG")
			f:Show()
			press(ctx, f.openBtn)
			ctx:advance(1.2)
			ctx:note("click Open Wuber settings in game Options")
			local msg = f.status and f.status:GetText() or ""
			f:Hide()
			if ctx.me.player.combat then
				if not msg:find("combat", 1, true) then
					ctx:fail(("You click Open Wuber settings during a fight and it says \"%s\" instead of explaining you are in combat."):format(msg))
				end
			else
				if not ctx.W.UI.SettingsShown() then
					ctx:fail("You click Open Wuber settings in the game's AddOns options and Wuber's Settings window does not open.")
				end
			end
		end,
	}

	Hunt.promise{
		id = "b4settings.hidden_drivers_show_all", area = "Settings",
		text = "When you have hidden a driver, Settings > Riding shows \"Hidden drivers\" with a \"Show all\" button that unhides them.",
		source = "Wuber/UI/Settings/Panel.lua:197-208 (Hidden drivers tooltip)",
		kind = "scenario",
		when = function(sit) return is(sit, "combat", "no") end,
		check = function(ctx)
			if ctx.me.player.combat then ctx:na("in combat") end
			local db = ctx.W.db
			if type(db) ~= "table" then ctx:cannot("no W.db") end
			db.hidden = db.hidden or {}
			db.hidden["ana driver"] = true
			ctx.W.Fire("SETTINGS", "hidden")
			local st = openSettings(ctx, "riding")
			if not (st.hiddenRow and ctx:visible(st.hiddenRow)) then
				ctx:fail("You have a hidden driver, open Settings > Riding, and the \"Hidden drivers\" Show all button is not shown.", onScreen(ctx))
			end
			press(ctx, st.hiddenRow)
			ctx:advance(0.6)
			ctx:note("click Show all under Hidden drivers")
			if next(ctx.W.db.hidden or {}) ~= nil then
				ctx:fail("You click Show all under Hidden drivers and the hidden driver is still hidden.")
			end
		end,
	}
end
