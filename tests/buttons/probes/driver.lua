-- tests/buttons/probes/driver.lua: one probe row per control returned by Lib.controls on the 13 driver screens.
-- Screens: console_open, console_closed, button_waiting, row_marks, note, customers, customers_queued,
-- crew, raid, demand, pvp, wizard_notlock, wizard_summoner.
return {
	-- Secure buttons (never clicked)
	{ id = "(no label) Secure.lua <Button> @Secure.lua", on = "console_open",
		skip = "secure button: runs a game macro or secure action, never clicked" },
	{ id = "Closed <Button> @Button.lua", on = "console_open",
		skip = "secure button: WuberDriveButton runs a game macro or secure action, never clicked" },
	{ id = "Open <Button> @Build.lua", on = "console_open",
		skip = "covered by secure button WuberGoButton in this state, never clicked" },
	{ id = "Closed <Frame> @Build.lua", on = "note",
		skip = "covered by the Note sheet backdrop in this state" },

	-- Phone header / window chrome (probed on console_open)
	{ id = "[signal] <Frame> @Phone.lua", on = "console_open",
		does = "Opens the signal status popover from the phone header.",
		check = function(ctx, before)
			return before.sig ~= before.afterSig, "expected signal popover to change visible state"
		end },
	{ id = "Wide <Button> @Phone.lua", on = "console_open",
		does = "Leaves folded window unchanged when space is too small for wide view.",
		check = function(ctx, before)
			return before.sig == before.afterSig, "expected folded window to stay unchanged"
		end },
	{ id = "(no label) Phone.lua <Button> @Phone.lua", on = "console_open",
		does = "Hides the Wuber window from the phone home bar.",
		check = function(ctx)
			local ui = ctx.W.UI and ctx.W.UI.state
			return ui and ui.win and not ui.win:IsShown(), "expected Wuber window to hide"
		end },
	{ id = "[circle] <Button> @Window.lua", on = "console_open",
		does = "Closes the Wuber window via the header close button.",
		check = function(ctx)
			local ui = ctx.W.UI and ctx.W.UI.state
			return ui and ui.win and not ui.win:IsShown(), "expected Wuber window to close"
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
		does = "Keeps the Drive tab active when already on Drive.",
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
		does = "Keeps sell summons mode selected when already active.",
		check = function(ctx)
			return ctx.W.Drive.Mode() == "sell", "expected mode sell, got " .. tostring(ctx.W.Drive.Mode())
		end },
	{ id = "Raid summons <Button> @Build.lua", on = "console_open",
		does = "Switches mode or shows raid summons feedback when clicked.",
		check = function(ctx, before)
			return before.sig ~= before.afterSig, "expected Raid summons click to update visible state"
		end },
	{ id = "50s to Undercity <Button> @Build.lua", on = "console_open",
		does = "Opens the price and place sheet from the fare pill.",
		check = function(ctx, before)
			return before.sig ~= before.afterSig, "expected fare pill click to open sheet"
		end },
	{ id = "(no label) Build.lua <Frame> @Build.lua", on = "console_open",
		does = "Opens the Earnings screen when clicking today's takings.",
		check = function(ctx, before)
			return before.sig ~= before.afterSig, "expected today's takings click to open Earnings"
		end },
	{ id = "Pause <Button> @Build.lua", on = "console_open",
		does = "Leaves pause state unchanged when the driver console is closed.",
		check = function(ctx, before)
			return before.sig == before.afterSig, "expected Pause while closed to leave state unchanged"
		end },
	{ id = "Advertise <Button> @Build.lua", on = "console_open",
		does = "Shows a toast explaining why advertising is not ready when closed.",
		check = function(ctx, before)
			return before.sig ~= before.afterSig, "expected Advertise click to show toast"
		end },
	{ id = "Crew <Button> @Build.lua", on = "console_open",
		does = "Opens the Crew screen from the driver console.",
		check = function(ctx, before)
			return before.sig ~= before.afterSig, "expected Crew link to open Crew screen"
		end },
	{ id = "Messages <Button> @Build.lua", on = "console_open",
		does = "Opens the Messages screen from the driver console.",
		check = function(ctx, before)
			return before.sig ~= before.afterSig, "expected Messages link to open Messages screen"
		end },

	-- Note sheet (probed on note)
	{ id = "? <Frame> @Customers.lua", on = "note",
		does = "Receives a click on the Note sheet card without closing it.",
		check = function(ctx, before)
			return before.sig == before.afterSig, "expected Note card click to keep sheet open"
		end },
	{ id = "[circle] <Button> @Customers.lua", on = "note",
		does = "Closes the Note sheet via its close button.",
		check = function(ctx, before)
			return before.sig ~= before.afterSig, "expected Note close button to dismiss sheet"
		end },
	{ id = "(long text) <Frame> @Customers.lua", on = "note",
		does = "Focuses the note input box and hides its placeholder.",
		check = function(ctx, before)
			return before.sig ~= before.afterSig, "expected note frame click to focus input"
		end },
	{ id = "(no label) Customers.lua <EditBox> @Customers.lua", on = "note",
		does = "Focuses the note EditBox directly.",
		check = function(ctx, before)
			return before.sig ~= before.afterSig, "expected note EditBox click to focus input"
		end },
	{ id = "Save <Button> @Customers.lua", on = "note",
		does = "Saves or updates the Note sheet when Save is clicked.",
		check = function(ctx, before)
			return before.sig ~= before.afterSig, "expected Save click to update Note sheet"
		end },
	{ id = "Gifted <Button> @Customers.lua", on = "note",
		does = "Updates the customer's gifted state on the Note sheet.",
		check = function(ctx, before)
			return before.sig ~= before.afterSig, "expected Gifted click to update Note sheet"
		end },

	-- Customers screen (probed on customers)
	{ id = "[circle] <Button> @Screens.lua", on = "customers",
		does = "Returns from Customers to the driver console.",
		check = function(ctx, before)
			return before.sig ~= before.afterSig, "expected Back button to return to console"
		end },
	{ id = "Search by name <Frame> @Customers.lua", on = "customers",
		does = "Focuses the customer search box and hides its placeholder.",
		check = function(ctx, before)
			return before.sig ~= before.afterSig, "expected search frame click to focus input"
		end },

	-- Crew screen (probed on crew)
	{ id = "Name or Name-Realm <Frame> @Wizard.lua", on = "crew",
		does = "Focuses the crew member name input and hides its placeholder.",
		check = function(ctx, before)
			return before.sig ~= before.afterSig, "expected crew name frame click to focus input"
		end },
	{ id = "(no label) Wizard.lua <EditBox> @Wizard.lua", on = "crew",
		does = "Focuses the crew member name EditBox directly.",
		check = function(ctx, before)
			return before.sig ~= before.afterSig, "expected crew name EditBox click to focus input"
		end },
	{ id = "Add <Button> @Wizard.lua", on = "crew",
		does = "Shows a validation toast when Add is clicked with an empty name.",
		check = function(ctx, before)
			return before.sig ~= before.afterSig, "expected Add click with empty name to show toast"
		end },
	{ id = "By clicks <Button> @Crew.lua", on = "crew",
		does = "Keeps the By clicks fair-split rule selected when already active.",
		check = function(ctx)
			local rule = ctx.W.Drive.opts().cutRule or "clicks"
			return rule == "clicks", "expected cutRule clicks, got " .. tostring(rule)
		end },
	{ id = "Equal <Button> @Crew.lua", on = "crew",
		does = "Switches the fair-split rule from By clicks to Equal.",
		check = function(ctx)
			local rule = ctx.W.Drive.opts().cutRule
			return rule == "equal", "expected cutRule equal, got " .. tostring(rule)
		end },
	{ id = "[circle] <Slider> @Crew.lua", on = "crew",
		does = "Enables mouse-wheel control on the Casters' part slider when clicked.",
		check = function(ctx, before)
			return before.ctl and before.ctl.f and before.ctl.f.wheelOn == true, "expected wheelOn to be enabled on slider"
		end },
	{ id = "Run the setup again <Button> @Crew.lua", on = "crew",
		does = "Opens the driver setup wizard from the Crew screen.",
		check = function(ctx, before)
			return before.sig ~= before.afterSig, "expected Run the setup again to open wizard"
		end },
}
