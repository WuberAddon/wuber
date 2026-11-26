-- tests/buttons/probes/rider.lua: one probe row per control returned by Lib.controls on
-- home, home_search, home_empty, home_bounty, confirm, worldmap, done_paid, done_unpaid, raincheck.
local function ok(cond, msg)
	if not cond then error(msg or "probe assertion failed", 2) end
end

local function eq(a, b, msg)
	if a ~= b then
		error((msg or "mismatch") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
	end
end

return {
	-- Shared header, tab bar, minimap and home controls (on home)
	{
		id = "[signal] <Frame> @Phone.lua",
		on = "home",
		does = "Clicking the signal badge opens the connection status Help page.",
		check = function(ctx)
			eq(ctx.W.UI.HelpShown(), true, "Help overlay opened for connection status")
		end,
	},
	{
		id = "Wide <Button> @Phone.lua",
		on = "home",
		does = "Clicking Wide unfolds the side pane when the window has room.",
		setup = function(ctx)
			if ctx.W.UI.Fold then ctx.W.UI.Fold.Fits = function() return true end end
		end,
		check = function(ctx)
			eq(ctx.W.UI.Fold.IsUnfolded(), true, "side pane unfolded")
		end,
	},
	{
		id = "(no label) Phone.lua <Button> @Phone.lua",
		on = "home",
		does = "Clicking the phone home indicator bar hides the Wuber window.",
		check = function(ctx)
			eq(ctx.W.UI.IsShown(), false, "window hidden by home bar")
		end,
	},
	{
		id = "[circle] <Button> @Window.lua",
		srcMatch = "Window%.lua:824",
		on = "home",
		does = "Clicking the window close button hides the Wuber window.",
		check = function(ctx)
			eq(ctx.W.UI.IsShown(), false, "window hidden by close button")
		end,
	},
	{
		id = "[circle] <Button> @Window.lua",
		srcMatch = "Window%.lua:871",
		on = "home",
		does = "Clicking the settings gear button opens the Settings overlay.",
		check = function(ctx)
			eq(ctx.W.UI.SettingsShown(), true, "Settings overlay opened")
		end,
	},
	{
		id = "Ride <Button> @Window.lua",
		on = "home",
		does = "Clicking the Ride tab switches back to the Ride tab.",
		setup = function(ctx)
			ctx.W.UI.SelectTab("Trips")
			ctx.w:advance(0.2)
		end,
		check = function(ctx)
			eq(ctx.W.UI.state.tab, "Ride", "switched to Ride tab")
		end,
	},
	{
		id = "(no label) Cards.lua <EditBox> @Cards.lua",
		on = "home",
		does = "Clicking the destination search box gives it keyboard focus.",
		check = function(ctx)
			eq(ctx.ctl.f:HasFocus(), true, "search edit box gained focus")
		end,
	},
	{
		id = "Ping drivers <Button> @Home.lua",
		on = "home",
		skip = "sends an addon message to other players to ping online drivers",
	},
	{
		id = "Tell me <Button> @Home.lua",
		on = "home",
		does = "Clicking Tell me toggles watching for a driver in saved watch state.",
		check = function(ctx)
			ok(next(ctx.W.db.watch or {}) ~= nil, "saved watch table updated")
		end,
	},
	{
		id = "Pin a bounty <Button> @Home.lua",
		on = "home",
		does = "Clicking Pin a bounty sets the place filter and opens the bounty picker.",
		check = function(ctx)
			local st = ctx.W.UI.state
			local empty = ctx.ctl.f:GetParent()
			ok(st.filter and st.filter.place ~= nil, "place filter set for bounty")
			ok(empty and empty.bounty and empty.bounty.pin:IsShown(), "bounty Pin button shown")
		end,
	},
	{
		id = "Why? <Button> @Home.lua",
		on = "home",
		does = "Clicking Why? opens the home Help page.",
		check = function(ctx)
			eq(ctx.W.UI.HelpShown(), true, "Help overlay opened from Why?")
		end,
	},
	{
		id = "Trips <Button> @Window.lua",
		on = "home",
		does = "Clicking the Trips tab switches to the Trips tab.",
		check = function(ctx)
			eq(ctx.W.UI.state.tab, "Trips", "switched to Trips tab")
		end,
	},
	{
		id = "Drive <Button> @Window.lua",
		on = "home",
		does = "Clicking the Drive tab switches to the Drive tab.",
		check = function(ctx)
			eq(ctx.W.UI.state.tab, "Drive", "switched to Drive tab")
		end,
	},
	{
		id = "[circle] <Button> @Minimap.lua",
		on = "home",
		does = "Clicking the minimap button toggles the Wuber window closed.",
		check = function(ctx)
			eq(ctx.W.UI.IsShown(), false, "window toggled closed by minimap button")
		end,
	},

	-- home_search controls
	{
		id = "Undercity <EditBox> @Cards.lua",
		on = "home_search",
		does = "Clicking the populated search box gives it keyboard focus.",
		check = function(ctx)
			eq(ctx.ctl.f:HasFocus(), true, "populated search box gained focus")
		end,
	},
	{
		id = "[circle] <Button> @Cards.lua",
		on = "home_search",
		does = "Clicking the search clear button empties the destination filter.",
		check = function(ctx)
			local f = ctx.W.UI.state.filter
			eq(f and f.place or nil, nil, "destination filter cleared")
		end,
	},
	{
		id = "All <Button> @Home.lua",
		on = "home_search",
		does = "Clicking the All chip clears the active destination filter.",
		check = function(ctx)
			local f = ctx.W.UI.state.filter
			eq(f and f.place or nil, nil, "All chip cleared destination filter")
		end,
	},
	{
		id = "Undercity <Button> @Home.lua",
		on = "home_search",
		does = "Clicking the Undercity chip sets the destination filter to Undercity.",
		setup = function(ctx)
			local W = ctx.W
			W.drivers = {
				["mia runner"] = {
					name = "Mia Runner", key = "mia runner", dest = "Undercity",
					price = 5000, state = "open", heard = W.Now and W.Now() or 100,
				},
			}
			W.UI.SetSearch("")
			if W.UI.RefreshNow then W.UI.RefreshNow() end
			eq(W.UI.state.filter and W.UI.state.filter.place or nil, nil, "filter starts cleared before clicking Undercity")
		end,
		check = function(ctx)
			local f = ctx.W.UI.state.filter
			eq(f and f.place or nil, "Undercity", "Undercity filter active")
		end,
	},

	-- home_bounty controls
	{
		id = "Gadgetzan <EditBox> @Cards.lua",
		on = "home_bounty",
		does = "Clicking the Gadgetzan search box gives it keyboard focus.",
		check = function(ctx)
			eq(ctx.ctl.f:HasFocus(), true, "Gadgetzan search box gained focus")
		end,
	},
	{
		id = "50s <Button> @Home.lua",
		on = "home_bounty",
		does = "Clicking 50s selects 5000 copper as the bounty amount.",
		check = function(ctx)
			local bb = ctx.ctl.f:GetParent()
			eq(bb.copper, 5000, "bounty amount set to 50s (5000c)")
		end,
	},
	{
		id = "75s <Button> @Home.lua",
		on = "home_bounty",
		does = "Clicking 75s selects 7500 copper as the bounty amount.",
		check = function(ctx)
			local bb = ctx.ctl.f:GetParent()
			eq(bb.copper, 7500, "bounty amount set to 75s (7500c)")
		end,
	},
	{
		id = "1g <Button> @Home.lua",
		on = "home_bounty",
		does = "Clicking 1g selects 10000 copper as the bounty amount.",
		check = function(ctx)
			local bb = ctx.ctl.f:GetParent()
			eq(bb.copper, 10000, "bounty amount set to 1g (10000c)")
		end,
	},
	{
		id = "Custom <Button> @Home.lua",
		on = "home_bounty",
		does = "Clicking Custom reveals the custom bounty amount input.",
		check = function(ctx)
			local bb = ctx.ctl.f:GetParent()
			eq(bb.custom:IsShown(), true, "custom bounty input shown")
		end,
	},
	{
		id = "Pin 50s <Button> @Home.lua",
		on = "home_bounty",
		skip = "broadcasts a bounty to other players (and covered by toast in home_bounty)",
	},
	{
		id = "Gadgetzan <Button> @Home.lua",
		on = "home_bounty",
		does = "Clicking the Gadgetzan chip keeps the destination filter on Gadgetzan.",
		check = function(ctx)
			local f = ctx.W.UI.state.filter
			eq(f and f.place or nil, "Gadgetzan", "Gadgetzan filter active")
		end,
	},

	-- confirm controls
	{
		id = "[circle] <Button> @Confirm.lua",
		on = "confirm",
		does = "Clicking the Confirm back button returns to the home screen.",
		check = function(ctx)
			eq(ctx.W.UI.state.screen, "home", "returned to home screen")
		end,
	},
	{
		id = "Driver went offline <Button> @Confirm.lua",
		on = "confirm",
		does = "Clicking the disabled Driver went offline button leaves Confirm open.",
		check = function(ctx)
			eq(ctx.ctl.f.inactive, true, "offline button is disabled")
			eq(ctx.W.UI.state.screen, "confirm", "stayed on confirm screen")
		end,
	},
}
