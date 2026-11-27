-- Probe rows for window header/tab controls on home and every control on
-- earnings, earnings_heatmap, earnings_tips, earnings_empty, shift, trips,
-- wrapped, wrapped_summary, help, help_bug.
-- Note: Lib.show("shift") returns false ("no shift in the demo log"), so shift
-- produces no controls in the walk.

local function findControl(Lib, ctx, id, srcMatch)
	for _, ctl in ipairs(Lib.controls(ctx)) do
		if ctl.id == id and (not srcMatch or ctl.src:find(srcMatch)) then
			return ctl
		end
	end
end

local function isShown(f)
	return f ~= nil and f.IsShown ~= nil and f:IsShown() == true
end

return {
	-- Window header, tab bar, and phone chrome controls (probed once on home)
	{
		id = "[circle] <Button> @Window.lua",
		srcMatch = "Window%.lua:824",
		on = "home",
		does = "Close button hides the Wuber window.",
		before = function(ctx)
			return { shown = isShown(ctx.W.UI.state and ctx.W.UI.state.win) }
		end,
		check = function(ctx, before)
			assert(before.shown == true, "window should be shown before clicking close")
			assert(not isShown(ctx.W.UI.state and ctx.W.UI.state.win), "close button did not hide Wuber window")
		end,
	},
	{
		id = "[circle] <Button> @Window.lua",
		srcMatch = "Window%.lua:871",
		on = "home",
		does = "Gear button opens the Settings panel.",
		before = function(ctx)
			return { open = ctx.W.UI.SettingsShown and ctx.W.UI.SettingsShown() == true }
		end,
		check = function(ctx, before)
			assert(not before.open, "Settings should be closed before clicking gear")
			assert(ctx.W.UI.SettingsShown and ctx.W.UI.SettingsShown() == true, "gear button did not open Settings")
		end,
	},
	{
		id = "Wide <Button> @Phone.lua",
		on = "home",
		does = "Fold button unfolds the window or toggles its fold state.",
		before = function(ctx)
			ctx.c.wide = true
			local win = ctx.W.UI.state and ctx.W.UI.state.win
			-- Move chat frame away so Fold.Fits() allows unfolding on home
			local chat = ctx.c.env.DEFAULT_CHAT_FRAME
			if chat then
				chat:ClearAllPoints()
				chat:SetPoint("BOTTOMLEFT", ctx.c.env.UIParent, "BOTTOMLEFT", 0, 0)
				chat:SetSize(10, 10)
			end
			if ctx.W.db and type(ctx.W.db.fold) == "table" then
				ctx.W.db.fold.narrow = false
			end
			if ctx.W.UI.Fold and ctx.W.UI.Fold.Apply then ctx.W.UI.Fold.Apply() end
			return {
				width = win and win:GetWidth() or 0,
				unfolded = ctx.W.UI.Fold and ctx.W.UI.Fold.IsUnfolded and ctx.W.UI.Fold.IsUnfolded() or false,
			}
		end,
		check = function(ctx, before)
			local win = ctx.W.UI.state and ctx.W.UI.state.win
			local afterUnfolded = ctx.W.UI.Fold and ctx.W.UI.Fold.IsUnfolded and ctx.W.UI.Fold.IsUnfolded() or false
			local afterW = win and win:GetWidth() or 0
			local fits, why = ctx.W.UI.Fold and ctx.W.UI.Fold.Fits and ctx.W.UI.Fold.Fits()
			local page = ctx.W.UI.Fold and ctx.W.UI.Fold.Page and ctx.W.UI.Fold.Page()
			assert(afterUnfolded ~= before.unfolded or afterW ~= before.width,
				string.format("fold button did not change fold state or window width (page=%s, fits=%s, why=%s, before=%s, after=%s)",
					tostring(page), tostring(fits), tostring(why), tostring(before.unfolded), tostring(afterUnfolded)))
		end,
	},
	{
		id = "(no label) Phone.lua <Button> @Phone.lua",
		on = "home",
		does = "Home indicator bar at the bottom hides the Wuber window.",
		before = function(ctx)
			return { shown = isShown(ctx.W.UI.state and ctx.W.UI.state.win) }
		end,
		check = function(ctx, before)
			assert(before.shown == true, "window should be shown before clicking home bar")
			assert(not isShown(ctx.W.UI.state and ctx.W.UI.state.win), "home bar did not hide Wuber window")
		end,
	},
	{
		id = "[signal] <Frame> @Phone.lua",
		on = "home",
		does = "Signal bars open Help at the network status section.",
		before = function(ctx)
			return { shown = ctx.W.UI.HelpShown and ctx.W.UI.HelpShown() == true }
		end,
		check = function(ctx, before)
			assert(not before.shown, "Help should be closed before clicking signal bars")
			assert(ctx.W.UI.HelpShown and ctx.W.UI.HelpShown() == true, "signal bars did not open Help")
		end,
	},
	{
		id = "Ride <Button> @Window.lua",
		on = "home",
		does = "Ride tab switches the active tab to Ride.",
		before = function(ctx, _ctl, Lib)
			local tripsBtn = findControl(Lib, ctx, "Trips <Button> @Window.lua")
			assert(tripsBtn, "Trips tab button should exist")
			ctx.c:clickOn(tripsBtn.f)
			ctx.w:advance(0.5)
			return { tab = ctx.W.UI.state and ctx.W.UI.state.tab }
		end,
		check = function(ctx, before)
			assert(before.tab == "Trips", "tab should be Trips before clicking Ride")
			assert(ctx.W.UI.state and ctx.W.UI.state.tab == "Ride", "Ride tab did not switch tab to Ride")
		end,
	},
	{
		id = "Trips <Button> @Window.lua",
		on = "home",
		does = "Trips tab switches the active tab to Trips.",
		before = function(ctx)
			return { tab = ctx.W.UI.state and ctx.W.UI.state.tab }
		end,
		check = function(ctx, before)
			assert(before.tab == "Ride", "tab should be Ride before clicking Trips")
			assert(ctx.W.UI.state and ctx.W.UI.state.tab == "Trips", "Trips tab did not switch tab to Trips")
		end,
	},
	{
		id = "Drive <Button> @Window.lua",
		on = "home",
		does = "Drive tab switches the active tab to Drive.",
		before = function(ctx)
			return { tab = ctx.W.UI.state and ctx.W.UI.state.tab }
		end,
		check = function(ctx, before)
			assert(before.tab == "Ride", "tab should be Ride before clicking Drive")
			assert(ctx.W.UI.state and ctx.W.UI.state.tab == "Drive", "Drive tab did not switch tab to Drive")
		end,
	},
	{
		id = "[circle] <Button> @Minimap.lua",
		on = "home",
		does = "Minimap button toggles the Wuber window closed when open.",
		before = function(ctx)
			return { shown = isShown(ctx.W.UI.state and ctx.W.UI.state.win) }
		end,
		check = function(ctx, before)
			assert(before.shown == true, "window should be shown before clicking minimap button")
			assert(not isShown(ctx.W.UI.state and ctx.W.UI.state.win), "minimap button did not hide Wuber window")
		end,
	},

	-- Earnings screens (earnings, earnings_heatmap, earnings_tips, earnings_empty)
	{
		id = "[circle] <Button> @Screens.lua",
		on = "earnings",
		does = "Back button leaves Earnings and returns to the driver console.",
		before = function(ctx)
			local ds = ctx.W.UI.drive and ctx.W.UI.drive.screens
			return { earningsShown = isShown(ds and ds.earnings and ds.earnings.frame) }
		end,
		check = function(ctx, before)
			local ds = ctx.W.UI.drive and ctx.W.UI.drive.screens
			assert(before.earningsShown == true, "earnings screen should be shown before clicking back")
			assert(not isShown(ds and ds.earnings and ds.earnings.frame), "earnings screen still shown after back")
		end,
	},
	{
		id = "Today <Button> @Earnings.lua",
		on = "earnings",
		does = "Today button switches the earnings range back to today.",
		before = function(ctx, _ctl, Lib)
			local w7 = findControl(Lib, ctx, "7 days <Button> @Earnings.lua")
			assert(w7, "7 days button should exist")
			ctx.c:clickOn(w7.f)
			ctx.w:advance(0.3)
			local es = ctx.W.UI.drive and ctx.W.UI.drive.screens and ctx.W.UI.drive.screens.earnings
			return { range = es and es.range }
		end,
		check = function(ctx, before)
			local es = ctx.W.UI.drive and ctx.W.UI.drive.screens and ctx.W.UI.drive.screens.earnings
			assert(before.range == "week", "range should be week before clicking Today")
			assert(es and es.range == "today", "Today button did not set range to today")
		end,
	},
	{
		id = "7 days <Button> @Earnings.lua",
		on = "earnings",
		does = "7 days button switches the earnings range to week.",
		before = function(ctx, _ctl, Lib)
			local es = ctx.W.UI.drive and ctx.W.UI.drive.screens and ctx.W.UI.drive.screens.earnings
			if es and es.range == "week" then
				local td = findControl(Lib, ctx, "Today <Button> @Earnings.lua")
				assert(td, "Today button should exist")
				ctx.c:clickOn(td.f)
				ctx.w:advance(0.3)
			end
			return { range = es and es.range }
		end,
		check = function(ctx, before)
			local es = ctx.W.UI.drive and ctx.W.UI.drive.screens and ctx.W.UI.drive.screens.earnings
			assert(before.range ~= "week", "range should not be week before clicking 7 days")
			assert(es and es.range == "week", "7 days button did not set range to week")
		end,
	},
	{
		id = "30 days <Button> @Earnings.lua",
		on = "earnings",
		does = "30 days button switches the earnings range to month.",
		before = function(ctx, _ctl, Lib)
			local es = ctx.W.UI.drive and ctx.W.UI.drive.screens and ctx.W.UI.drive.screens.earnings
			if es and es.range == "month" then
				local td = findControl(Lib, ctx, "Today <Button> @Earnings.lua")
				assert(td, "Today button should exist")
				ctx.c:clickOn(td.f)
				ctx.w:advance(0.3)
			end
			return { range = es and es.range }
		end,
		check = function(ctx, before)
			local es = ctx.W.UI.drive and ctx.W.UI.drive.screens and ctx.W.UI.drive.screens.earnings
			assert(before.range ~= "month", "range should not be month before clicking 30 days")
			assert(es and es.range == "month", "30 days button did not set range to month")
		end,
	},
	{
		id = "[color] <Button> @Earnings.lua",
		on = "earnings_heatmap",
		does = "Heatmap cell selects that hour cell on the earnings heatmap.",
		before = function(ctx, ctl)
			local es = ctx.W.UI.drive and ctx.W.UI.drive.screens and ctx.W.UI.drive.screens.earnings
			if es and es.heat then
				es.heat.picked = nil
				if not es.heat.grid then
					es.heat.grid = { [ctl.f.wday] = { [ctl.f.hour] = { rides = 1, copper = 5000, open = 60, asks = 0 } } }
				end
			end
			return { picked = nil }
		end,
		check = function(ctx, before, ctl)
			local es = ctx.W.UI.drive and ctx.W.UI.drive.screens and ctx.W.UI.drive.screens.earnings
			assert(es and es.heat and es.heat.picked == ctl.f and es.heat.picked ~= before.picked,
				"clicking heatmap cell did not select it")
		end,
	},
	{
		id = "Reset stats <Button> @Earnings.lua",
		on = "earnings_heatmap",
		does = "Reset stats button arms the confirmation prompt on first click.",
		before = function(ctx)
			local es = ctx.W.UI.drive and ctx.W.UI.drive.screens and ctx.W.UI.drive.screens.earnings
			return { sure = es and es.sure }
		end,
		check = function(ctx, before)
			local es = ctx.W.UI.drive and ctx.W.UI.drive.screens and ctx.W.UI.drive.screens.earnings
			assert(not before.sure, "sure should be nil before clicking Reset stats")
			assert(es and es.sure == true, "Reset stats did not arm confirmation")
		end,
	},
	{
		id = "[circle] <Slider> @Earnings.lua",
		on = "earnings_heatmap",
		does = "Target per hour slider activates mouse wheel adjustment and updates target.",
		before = function(ctx, ctl)
			local opts = ctx.W.Mod("UI.Driver.Screens").opts
			return { wheelOn = ctl.f.wheelOn, target = opts().target }
		end,
		check = function(ctx, before, ctl)
			assert(ctl.f.wheelOn == true and ctl.f.wheelOn ~= before.wheelOn,
				"clicking earnings target slider did not enable wheelOn")
			ctx.c:wheelOn(ctl.f, 1)
			ctx.w:advance(0.5)
			local opts = ctx.W.Mod("UI.Driver.Screens").opts
			assert(opts().target ~= before.target, "scrolling earnings target slider did not update target")
		end,
	},

	-- Help and Help Bug screens (help, help_bug)
	{
		id = "[circle] <Button> @Panel.lua",
		srcMatch = "Panel%.lua:866",
		on = "help",
		does = "Help back button closes the Help panel.",
		before = function(ctx)
			return { shown = ctx.W.UI.HelpShown and ctx.W.UI.HelpShown() == true }
		end,
		check = function(ctx, before)
			assert(before.shown == true, "Help should be shown before clicking back")
			assert(not (ctx.W.UI.HelpShown and ctx.W.UI.HelpShown()), "Help back button did not close Help")
		end,
	},
	{
		id = "[circle] <Button> @Panel.lua",
		srcMatch = "Panel%.lua:115",
		on = "help",
		skip = "covered by help.panel (Settings back button underneath Help)",
	},
	{
		id = "Ask or search: how do I mute sounds? <Frame> @Find.lua",
		on = "help",
		skip = "covered by help.panel (Settings search box underneath Help)",
	},
	{
		id = "(no label) Find.lua <EditBox> @Find.lua",
		on = "help",
		skip = "covered by help.panel (Settings search EditBox underneath Help)",
	},
	{
		id = "[pill] <Button> @Find.lua",
		on = "help",
		skip = "covered by help.panel (Settings quick switch underneath Help)",
	},
	{
		id = "Riding <Button> @Find.lua",
		on = "help",
		skip = "covered by help.panel (Settings section row underneath Help)",
	},
	{
		id = "Driving <Button> @Find.lua",
		on = "help",
		skip = "covered by help.panel (Settings section row underneath Help)",
	},
	{
		id = "Map <Button> @Find.lua",
		on = "help",
		skip = "covered by help.panel (Settings section row underneath Help)",
	},
	{
		id = "Sound and effects <Button> @Find.lua",
		on = "help",
		skip = "covered by help.panel (Settings section row underneath Help)",
	},
	{
		id = "curseforge.com/wow/addons/wuber <Frame> @Panel.lua",
		on = "help_bug",
		does = "URL box wrapper focuses and highlights the CurseForge URL EditBox.",
		before = function(_ctx, ctl)
			local ueb = ctl.f.edit
			assert(ueb, "urlBox.edit should exist")
			local state = { highlighted = false }
			local orig = ueb.HighlightText
			ueb.HighlightText = function(self, ...)
				state.highlighted = true
				return orig(self, ...)
			end
			return state
		end,
		check = function(_ctx, before)
			assert(before.highlighted == true, "clicking URL box did not call HighlightText")
		end,
	},
	{
		id = "curseforge.com/wow/addons/wuber <EditBox> @Panel.lua",
		on = "help_bug",
		does = "URL EditBox highlights the CurseForge URL text for copying.",
		before = function(ctx, ctl)
			local state = { highlighted = false }
			local orig = ctl.f.HighlightText
			ctl.f.HighlightText = function(self, ...)
				state.highlighted = true
				return orig(self, ...)
			end
			return state
		end,
		check = function(_ctx, before)
			assert(before.highlighted == true, "clicking URL EditBox did not call HighlightText")
		end,
	},
	{
		id = "Show a tip <Button> @Panel.lua",
		on = "help_bug",
		does = "Show a tip closes Help and switches to the Ride tab.",
		before = function(ctx)
			return { helpShown = ctx.W.UI.HelpShown and ctx.W.UI.HelpShown() == true }
		end,
		check = function(ctx, before)
			assert(before.helpShown == true, "Help should be shown before clicking Show a tip")
			assert(not (ctx.W.UI.HelpShown and ctx.W.UI.HelpShown()), "Show a tip did not close Help")
			assert(ctx.W.UI.state and ctx.W.UI.state.tab == "Ride", "Show a tip did not switch to Ride tab")
		end,
	},
	{
		id = "Report a bug <Button> @Panel.lua",
		on = "help_bug",
		does = "Report a bug opens the WuberBug report window.",
		before = function(ctx)
			return { shown = isShown(ctx.c.env.WuberBug) }
		end,
		check = function(ctx, before)
			assert(not before.shown, "WuberBug should be hidden before clicking Report a bug")
			assert(isShown(ctx.c.env.WuberBug), "Report a bug did not open WuberBug")
		end,
	},
}
