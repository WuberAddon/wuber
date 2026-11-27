-- tests/buttons/probes/driver.lua: one probe row per control returned by Lib.controls on the 13 driver screens.
-- Screens: console_open, console_closed, button_waiting, row_marks, note, customers, customers_queued,
-- crew, raid, demand, pvp, wizard_notlock, wizard_summoner.
local function hasText(ctx, needle)
	for _, t in ipairs(ctx.c:visibleTexts()) do
		if tostring(t):find(needle, 1, true) then return true end
	end
	return false
end

local function findEditChild(f)
	if not f then return nil end
	if f.GetObjectType and f:GetObjectType() == "EditBox" then return f end
	for _, ch in ipairs({ f:GetChildren() }) do
		local found = findEditChild(ch)
		if found then return found end
	end
end

return {
	-- Secure / covered controls (never clicked)
	{ id = "(no label) Secure.lua <Button> @Secure.lua", on = "console_open",
		skip = "secure button: runs a game macro or secure action, never clicked" },
	{ id = "Closed <Button> @Button.lua", on = "console_open",
		skip = "secure button: WuberDriveButton runs a game macro or secure action, never clicked" },
	{ id = "Open <Button> @Build.lua", on = "console_open",
		skip = "covered by secure button WuberGoButton in this state, never clicked" },
	{ id = "(no label) Build.lua <Frame> @Build.lua", srcMatch = "Build%.lua:325", on = "console_open",
		skip = "covered by secure button WuberDriveButton in this state, never clicked" },
	{ id = "Closed <Frame> @Build.lua", on = "note",
		skip = "covered by the Note sheet backdrop in this state" },

	-- Phone header / window chrome (probed on console_open)
	{ id = "[signal] <Frame> @Phone.lua", on = "console_open",
		does = "Opens the Help status page from the phone header signal bars.",
		check = function(ctx)
			return ctx.W.UI.HelpShown() == true, "expected HelpShown() == true"
		end },
	{ id = "Wide <Button> @Phone.lua", on = "console_open",
		setup = function(ctx)
			ctx.W.db.pos = { point = "CENTER", x = 0, y = 0 }
			local page = ctx.W.UI.Fold.Page()
			ctx.W.db.fold = { pages = { [page] = "closed" } }
			ctx.W.UI.Fold.Apply(true)
			ctx.w:advance(0.2)
		end,
		does = "Unfolds the Wuber window into wide view when room is available.",
		check = function(ctx)
			return ctx.W.UI.Fold.IsUnfolded() == true, "expected Fold.IsUnfolded() == true"
		end },
	{ id = "(no label) Phone.lua <Button> @Phone.lua", on = "console_open",
		does = "Hides the Wuber window from the phone home bar.",
		check = function(ctx)
			local ui = ctx.W.UI and ctx.W.UI.state
			return ui and ui.win and not ui.win:IsShown(), "expected Wuber window to hide"
		end },
	{ id = "[circle] <Button> @Window.lua", srcMatch = "Window%.lua:824", on = "console_open",
		does = "Closes the Wuber window via the header close button.",
		check = function(ctx)
			local ui = ctx.W.UI and ctx.W.UI.state
			return ui and ui.win and not ui.win:IsShown(), "expected Wuber window to close"
		end },
	{ id = "[circle] <Button> @Window.lua", srcMatch = "Window%.lua:871", on = "console_open",
		does = "Opens Settings from the header gear button.",
		check = function(ctx)
			return ctx.W.UI.SettingsShown() == true, "expected SettingsShown() == true"
		end },
	{ id = "Ride <Button> @Window.lua", on = "console_open",
		does = "Switches from the Drive tab to the Ride tab.",
		check = function(ctx)
			return ctx.W.UI.state.tab == "Ride", "expected tab Ride, got " .. tostring(ctx.W.UI.state.tab)
		end },
	{ id = "Trips <Button> @Window.lua", on = "console_open",
		does = "Switches from the Drive tab to the Trips tab.",
		check = function(ctx)
			return ctx.W.UI.state.tab == "Trips", "expected tab Trips, got " .. tostring(ctx.W.UI.state.tab)
		end },
	{ id = "Drive <Button> @Window.lua", on = "console_open",
		setup = function(ctx, findControl)
			local ride = findControl(ctx, { id = "Ride <Button> @Window.lua" })
			if ride then ctx.c:clickOn(ride.f) ctx.w:advance(0.3) end
		end,
		does = "Switches from the Ride tab back to the Drive tab.",
		check = function(ctx)
			return ctx.W.UI.state.tab == "Drive", "expected tab Drive, got " .. tostring(ctx.W.UI.state.tab)
		end },
	{ id = "[circle] <Button> @Minimap.lua", on = "console_open",
		does = "Toggles the Wuber window closed from the minimap button.",
		check = function(ctx)
			local ui = ctx.W.UI and ctx.W.UI.state
			return ui and ui.win and not ui.win:IsShown(), "expected Wuber window to hide"
		end },

	-- Driver console (probed on console_open)
	{ id = "Sell summons <Button> @Build.lua", on = "console_open",
		setup = function(ctx)
			ctx.W.Driver.SetMode("raid")
			ctx.w:advance(0.3)
		end,
		does = "Switches from raid summons mode back to sell summons mode.",
		check = function(ctx)
			return ctx.W.Drive.Mode() == "sell", "expected mode sell, got " .. tostring(ctx.W.Drive.Mode())
		end },
	{ id = "Raid summons <Button> @Build.lua", on = "console_open",
		does = "Switches the driver console from sell mode to raid summons mode.",
		check = function(ctx)
			return ctx.W.Drive.Mode() == "raid", "expected mode raid, got " .. tostring(ctx.W.Drive.Mode())
		end },
	{ id = "50s to Undercity <Button> @Build.lua", on = "console_open",
		does = "Opens the price and place sheet from the fare pill.",
		check = function(ctx)
			local sh = ctx.W.Driver.ui and ctx.W.Driver.ui.sheets and ctx.W.Driver.ui.sheets.sheet
			return sh and sh.frame and sh.frame:IsShown() == true, "expected price/place sheet to be shown"
		end },
	{ id = "(no label) Build.lua <Frame> @Build.lua", srcMatch = "Build%.lua:116", on = "console_open",
		does = "Opens the Earnings screen when clicking today's takings.",
		check = function(ctx)
			local scr = ctx.W.UI.drive and ctx.W.UI.drive.screens and ctx.W.UI.drive.screens.earnings
			return scr and scr.frame and scr.frame:IsShown() == true, "expected Earnings screen to be shown"
		end },
	{ id = "Pause <Button> @Build.lua", on = "console_open",
		setup = function(ctx)
			ctx.W.Driver.SetOnline(true)
			ctx.w:advance(0.3)
		end,
		does = "Pauses the open driver console so no new riders are invited.",
		check = function(ctx)
			return ctx.W.Drive.IsPaused() == true, "expected Drive.IsPaused() == true"
		end },
	{ id = "Advertise <Button> @Build.lua", on = "console_open",
		does = "Shows the 'Open first, then advertise' toast when the console is closed.",
		check = function(ctx)
			return hasText(ctx, "Open first, then advertise"), "expected toast 'Open first, then advertise'"
		end },
	{ id = "Crew <Button> @Build.lua", on = "console_open",
		does = "Opens the Crew screen from the driver console.",
		check = function(ctx)
			local scr = ctx.W.UI.drive and ctx.W.UI.drive.screens and ctx.W.UI.drive.screens.crew
			return scr and scr.frame and scr.frame:IsShown() == true, "expected Crew screen to be shown"
		end },
	{ id = "Messages <Button> @Build.lua", on = "console_open",
		does = "Opens the Messages screen from the driver console.",
		check = function(ctx)
			local scr = ctx.W.UI.drive and ctx.W.UI.drive.screens and ctx.W.UI.drive.screens.messages
			return scr and scr.frame and scr.frame:IsShown() == true, "expected Messages screen to be shown"
		end },

	-- Note sheet (probed on note)
	{ id = "? <Frame> @Customers.lua", on = "note",
		does = "Keeps the Note sheet open when clicking the sheet card.",
		check = function(ctx)
			local sh = ctx.W.Driver.ui and ctx.W.Driver.ui.sheets and ctx.W.Driver.ui.sheets.note
			return sh and sh.frame and sh.frame:IsShown() == true, "expected Note sheet to remain shown"
		end },
	{ id = "[circle] <Button> @Customers.lua", on = "note",
		does = "Closes the Note sheet via its close button.",
		check = function(ctx)
			local sh = ctx.W.Driver.ui and ctx.W.Driver.ui.sheets and ctx.W.Driver.ui.sheets.note
			return sh and sh.frame and not sh.frame:IsShown(), "expected Note sheet to close"
		end },
	{ id = "(long text) <Frame> @Customers.lua", on = "note",
		does = "Focuses the Note EditBox when clicking its container frame.",
		check = function(ctx)
			local sh = ctx.W.Driver.ui and ctx.W.Driver.ui.sheets and ctx.W.Driver.ui.sheets.note
			return sh and sh.field and sh.field.edit:HasFocus() == true, "expected Note EditBox to have focus"
		end },
	{ id = "(no label) Customers.lua <EditBox> @Customers.lua", srcMatch = "Customers%.lua:509", on = "note",
		does = "Focuses the Note EditBox directly.",
		check = function(ctx)
			local sh = ctx.W.Driver.ui and ctx.W.Driver.ui.sheets and ctx.W.Driver.ui.sheets.note
			return sh and sh.field and sh.field.edit:HasFocus() == true, "expected Note EditBox to have focus"
		end },
	{ id = "Save <Button> @Customers.lua", on = "note",
		setup = function(ctx)
			local sh = ctx.W.Driver.ui and ctx.W.Driver.ui.sheets and ctx.W.Driver.ui.sheets.note
			sh.field:SetText("good rider")
		end,
		does = "Saves the entered note to the customer book.",
		check = function(ctx)
			local sh = ctx.W.Driver.ui and ctx.W.Driver.ui.sheets and ctx.W.Driver.ui.sheets.note
			local saved = sh and sh.save and sh.save.label and sh.save.label:GetText() == "Saved"
			local closed = sh and sh.frame and not sh.frame:IsShown()
			return (saved or closed) == true, "expected Save button to flash Saved or close Note sheet"
		end },
	{ id = "Gifted <Button> @Customers.lua", on = "note",
		does = "Stamps the customer as gifted in the customer book.",
		check = function(ctx)
			local sh = ctx.W.Driver.ui and ctx.W.Driver.ui.sheets and ctx.W.Driver.ui.sheets.note
			local lbl = sh and sh.gift and sh.gift.label and sh.gift.label:GetText() or ""
			return lbl:find("Gifted", 1, true) ~= nil and hasText(ctx, "stamped gifted"), "expected Gifted toast and stamped label"
		end },

	-- Customers screen (probed on customers)
	{ id = "[circle] <Button> @Screens.lua", on = "customers",
		does = "Returns from Customers to the driver console.",
		check = function(ctx)
			local scr = ctx.W.UI.drive and ctx.W.UI.drive.screens and ctx.W.UI.drive.screens.customers
			local con = ctx.W.Driver.ui and ctx.W.Driver.ui.console
			return scr and not scr.frame:IsShown() and con and con:IsShown(), "expected return to driver console"
		end },
	{ id = "Search by name <Frame> @Customers.lua", on = "customers",
		does = "Focuses the Customers search EditBox when clicking its container frame.",
		check = function(ctx)
			local scr = ctx.W.UI.drive and ctx.W.UI.drive.screens and ctx.W.UI.drive.screens.customers
			return scr and scr.search and scr.search.edit:HasFocus() == true, "expected Customers search EditBox to have focus"
		end },
	{ id = "(no label) Customers.lua <EditBox> @Customers.lua", srcMatch = "Customers%.lua:832", on = "customers",
		does = "Focuses the Customers search EditBox directly.",
		check = function(ctx)
			local scr = ctx.W.UI.drive and ctx.W.UI.drive.screens and ctx.W.UI.drive.screens.customers
			return scr and scr.search and scr.search.edit:HasFocus() == true, "expected Customers search EditBox to have focus"
		end },

	-- Crew screen (probed on crew)
	{ id = "Name or Name-Realm <Frame> @Wizard.lua", on = "crew",
		does = "Focuses the Crew add-member EditBox when clicking its container frame.",
		check = function(ctx, before)
			local ed = findEditChild(before.ctl.f)
			return ed ~= nil and ed:HasFocus() == true, "expected Crew add-member EditBox to have focus"
		end },
	{ id = "(no label) Wizard.lua <EditBox> @Wizard.lua", on = "crew",
		does = "Focuses the Crew add-member EditBox directly.",
		check = function(ctx, before)
			return before.ctl.f:HasFocus() == true, "expected Crew add-member EditBox to have focus"
		end },
	{ id = "Add <Button> @Wizard.lua", on = "crew",
		does = "Shows a validation toast when Add is clicked with an empty name.",
		check = function(ctx)
			return hasText(ctx, "Type a name first"), "expected validation toast 'Type a name first'"
		end },
	{ id = "By clicks <Button> @Crew.lua", on = "crew",
		setup = function(ctx)
			ctx.W.Drive.opts().cutRule = "equal"
			local scr = ctx.W.UI.drive.screens.crew
			if scr and scr.cutSeg then scr.cutSeg:SetValue("equal") end
			ctx.w:advance(0.2)
		end,
		does = "Switches the fair-split rule from Equal back to By clicks.",
		check = function(ctx)
			return ctx.W.Drive.opts().cutRule == "clicks", "expected cutRule clicks, got " .. tostring(ctx.W.Drive.opts().cutRule)
		end },
	{ id = "Equal <Button> @Crew.lua", on = "crew",
		does = "Switches the fair-split rule from By clicks to Equal.",
		check = function(ctx)
			return ctx.W.Drive.opts().cutRule == "equal", "expected cutRule equal, got " .. tostring(ctx.W.Drive.opts().cutRule)
		end },
	{ id = "[circle] <Slider> @Crew.lua", on = "crew",
		does = "Enables mouse-wheel control on the Casters' part slider when clicked.",
		check = function(ctx, before)
			return before.ctl and before.ctl.f and before.ctl.f.wheelOn == true, "expected wheelOn to be enabled on slider"
		end },
	{ id = "Run the setup again <Button> @Crew.lua", on = "crew",
		does = "Opens the driver setup wizard from the Crew screen.",
		check = function(ctx)
			local wiz = ctx.W.UI.drive and ctx.W.UI.drive.wizard
			return wiz and wiz.frame and wiz.frame:IsShown() == true, "expected Wizard screen to be shown"
		end },
}
