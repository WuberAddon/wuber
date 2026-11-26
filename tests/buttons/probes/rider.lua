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
	-- Shared header, tab bar and minimap chrome (probed on home)
	{
		id = "[signal] <Frame> @Phone.lua",
		on = "home",
		does = "Clicking the signal badge opens the connection check view.",
		check = function(ctx, before)
			ok(ctx.sig ~= before.sig, "signal badge click changed visible state")
		end,
	},
	{
		id = "Wide <Button> @Phone.lua",
		on = "home",
		does = "Clicking Wide at the default window position leaves the pane folded when room is tight.",
		check = function(ctx)
			eq(ctx.W.UI.Fold.IsUnfolded(), false, "pane stays folded when beside chat")
		end,
	},
	{
		id = "(no label) Phone.lua <Button> @Phone.lua",
		on = "home",
		does = "Clicking the window close button hides the Wuber window.",
		check = function(ctx)
			eq(ctx.W.UI.IsShown(), false, "window closed")
		end,
	},
	{
		id = "[circle] <Button> @Window.lua",
		on = "home",
		does = "Clicking the window header close button hides the Wuber window.",
		check = function(ctx)
			eq(ctx.W.UI.IsShown(), false, "window hidden by header close button")
		end,
	},
	{
		id = "Ride <Button> @Window.lua",
		on = "home",
		does = "Clicking the already-active Ride tab keeps the Ride tab selected.",
		check = function(ctx)
			eq(ctx.W.UI.state.tab, "Ride", "Ride tab remains active")
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
		check = function(ctx, before)
			eq(ctx.W.UI.IsShown(), not before.shown, "window visibility toggled")
		end,
	},

	-- Home screen controls
	{
		id = "(no label) Cards.lua <EditBox> @Cards.lua",
		on = "home",
		does = "Clicking the destination search box gives it keyboard focus.",
		check = function(ctx)
			ok(ctx.ctl.f:HasFocus(), "search edit box gained focus")
		end,
	},
	{
		id = "All <Button> @Home.lua",
		on = "home",
		does = "Clicking the All destination chip keeps the destination filter empty.",
		check = function(ctx)
			eq(ctx.W.UI.state.search or "", "", "destination filter is empty")
		end,
	},
	{
		id = "Undercity <Button> @Home.lua",
		on = "home",
		does = "Clicking the Undercity chip filters the driver list to Undercity.",
		check = function(ctx, before)
			ok(ctx.sig ~= before.sig, "Undercity filter changed visible state")
		end,
	},
	{
		id = "Booty Bay <Button> @Home.lua",
		on = "home",
		does = "Clicking the Booty Bay chip filters the driver list to Booty Bay.",
		check = function(ctx, before)
			ok(ctx.sig ~= before.sig, "Booty Bay filter changed visible state")
		end,
	},
	{
		id = "Ratchet <Button> @Home.lua",
		on = "home",
		does = "Clicking the Ratchet chip filters the driver list to Ratchet.",
		check = function(ctx, before)
			ok(ctx.sig ~= before.sig, "Ratchet filter changed visible state")
		end,
	},
	{
		id = "Mia's Rides <Button> @Cards.lua",
		on = "home",
		does = "Clicking Mia's Rides opens the confirm screen for Mia Runner.",
		check = function(ctx)
			eq(ctx.W.UI.state.screen, "confirm", "confirm screen opened")
		end,
	},
	{
		id = "Nia's Portals <Button> @Cards.lua",
		on = "home",
		does = "Clicking Nia's Portals opens the confirm screen for Nia Quill.",
		check = function(ctx)
			eq(ctx.W.UI.state.screen, "confirm", "confirm screen opened")
		end,
	},
	{
		id = "Bob's Rides <Button> @Cards.lua",
		on = "home",
		does = "Clicking Bob's Rides opens the confirm screen for Bob Stone.",
		check = function(ctx)
			eq(ctx.W.UI.state.screen, "confirm", "confirm screen opened")
		end,
	},
	{
		id = "Ivy's Express <Button> @Cards.lua",
		on = "home",
		does = "Clicking Ivy's Express opens the confirm screen for Ivy Moss.",
		check = function(ctx)
			eq(ctx.W.UI.state.screen, "confirm", "confirm screen opened")
		end,
	},
	{
		id = "[heart_outline] <Button> @Cards.lua",
		on = "home",
		does = "Clicking a driver card's favourite heart toggles that driver in saved favourites.",
		check = function(ctx, before)
			local n = 0
			for _, v in pairs(ctx.W.db.favs or {}) do if v then n = n + 1 end end
			ok(n ~= before.favCount, "saved favourite count changed")
		end,
	},

	-- home_search controls
	{
		id = "Undercity <EditBox> @Cards.lua",
		on = "home_search",
		does = "Clicking the populated search box gives it keyboard focus.",
		check = function(ctx)
			ok(ctx.ctl.f:HasFocus(), "populated search box gained focus")
		end,
	},
	{
		id = "[circle] <Button> @Cards.lua",
		on = "home_search",
		does = "Clicking the search clear button empties the destination search.",
		check = function(ctx)
			eq(ctx.W.UI.state.search or "", "", "search cleared")
		end,
	},
	{
		id = "Tell me when one opens <Button> @Home.lua",
		on = "home_search",
		does = "Clicking Tell me when one opens toggles the destination watch.",
		check = function(ctx, before)
			ok(ctx.sig ~= before.sig, "watch button state changed")
		end,
	},
	{
		id = "(long text) <Button> @Home.lua",
		on = "home_search",
		does = "Clicking the long banner button on home_search updates the screen state.",
		check = function(ctx, before)
			ok(ctx.sig ~= before.sig, "banner click changed visible state")
		end,
	},
	{
		id = "[close] <Button> @Home.lua",
		on = "home_search",
		does = "Clicking the banner close button dismisses it.",
		check = function(ctx, before)
			ok(ctx.sig ~= before.sig, "banner dismissed")
		end,
	},

	-- home_empty controls
	{
		id = "Ping drivers <Button> @Home.lua",
		on = "home_empty",
		skip = "sends an addon message to other players to ping online drivers",
	},
	{
		id = "Tell me <Button> @Home.lua",
		on = "home_empty",
		does = "Clicking Tell me toggles watching for online drivers.",
		check = function(ctx, before)
			ok(ctx.sig ~= before.sig, "Tell me toggled watch state")
		end,
	},
	{
		id = "Pin a bounty <Button> @Home.lua",
		on = "home_empty",
		does = "Clicking Pin a bounty reveals the bounty amount picker.",
		check = function(ctx, before)
			ok(ctx.sig ~= before.sig, "bounty picker opened")
		end,
	},
	{
		id = "Why? <Button> @Home.lua",
		on = "home_empty",
		does = "Clicking Why? opens the explanation card.",
		check = function(ctx, before)
			ok(ctx.sig ~= before.sig, "Why? explanation shown")
		end,
	},

	-- home_bounty controls
	{
		id = "Take down <Button> @Home.lua",
		on = "home_bounty",
		skip = "sends a bounty cancellation broadcast to other players",
	},

	-- confirm controls
	{
		id = "[circle] <Button> @Confirm.lua",
		on = "confirm",
		does = "Clicking the back button on Confirm returns to the home screen.",
		check = function(ctx)
			eq(ctx.W.UI.state.screen, "home", "returned to home screen")
		end,
	},
	{
		id = "Favourite <Button> @Cards.lua",
		on = "confirm",
		does = "Clicking Favourite on Confirm toggles the driver's favourite state.",
		check = function(ctx, before)
			ok((ctx.W.db.favs["mia runner"] == true) ~= before.favMia, "Mia favourite toggled")
		end,
	},
	{
		id = "You're already in Undercity. <Button> @Confirm.lua",
		on = "confirm",
		does = "Clicking the disabled already-there button keeps the Confirm screen open.",
		check = function(ctx)
			eq(ctx.W.UI.state.screen, "confirm", "stayed on confirm screen")
		end,
	},

	-- worldmap controls (unfolded)
	{
		id = "Narrow <Button> @Phone.lua",
		on = "worldmap",
		does = "Clicking Narrow folds the side pane closed.",
		check = function(ctx)
			eq(ctx.W.UI.Fold.IsUnfolded(), false, "side pane folded")
		end,
	},
	{
		id = "Here <Button> @WorldMap.lua",
		on = "worldmap",
		does = "Clicking Here switches the map pane to the local zone view.",
		check = function(ctx)
			eq(ctx.W.db.mapView, "here", "mapView set to here")
		end,
	},
	{
		id = "World <Button> @WorldMap.lua",
		on = "worldmap",
		does = "Clicking World keeps the map pane in the world view.",
		check = function(ctx)
			ok(ctx.ctl.f.chosen ~= nil or ctx.W.db.mapView == "world", "World segment is active")
		end,
	},
	{
		id = "[circle] <Button> @WorldMap.lua",
		on = "worldmap",
		does = "Clicking a flight master node dot leaves the screen unchanged.",
		check = function(ctx)
			eq(ctx.W.UI.state.screen, "home", "screen remained home")
		end,
	},
	{
		id = "[pin] <Button> @WorldMap.lua",
		on = "worldmap",
		does = "Clicking a driver pin on the world map opens the confirm screen.",
		check = function(ctx)
			eq(ctx.W.UI.state.screen, "confirm", "confirm screen opened from driver pin")
		end,
	},
	{
		id = "2 <Button> @WorldMap.lua",
		on = "worldmap",
		does = "Clicking a queued driver pin on the world map opens the confirm screen.",
		check = function(ctx)
			eq(ctx.W.UI.state.screen, "confirm", "confirm screen opened from queued driver pin")
		end,
	},
	{
		id = "60s <Button> @WorldMap.lua",
		on = "worldmap",
		does = "Clicking the 60s driver pin on the world map opens the confirm screen.",
		check = function(ctx)
			eq(ctx.W.UI.state.screen, "confirm", "confirm screen opened from 60s driver pin")
		end,
	},

	-- done_paid and done_unpaid controls
	{
		id = "(no label) Secure.lua <Button> @Secure.lua",
		on = "done_paid",
		skip = "secure button",
	},
	{
		id = "[star] <Button> @Done.lua",
		on = "done_paid",
		does = "Clicking a rating star updates the ride rating.",
		check = function(ctx)
			ok(type(ctx.W.ride.stars) == "number", "ride stars recorded")
		end,
	},
	{
		id = "Done <Button> @Done.lua",
		on = "done_paid",
		does = "Clicking Done dismisses the completed ride and returns to home.",
		check = function(ctx)
			eq(ctx.W.UI.state.screen, "home", "returned to home after Done")
		end,
	},
	{
		id = "Share <Button> @Done.lua",
		on = "done_paid",
		skip = "posts to party chat via secure button overlay",
	},

	-- raincheck controls
	{
		id = "(no label) Moments.lua <Frame> @Moments.lua",
		on = "raincheck",
		does = "Clicking the raincheck offer backdrop closes the offer card.",
		check = function(ctx)
			ok(not (ctx.W.UI.state.rcOffer and ctx.W.UI.state.rcOffer.open), "raincheck offer closed on backdrop click")
		end,
	},
	{
		id = "[circle] <Button> @Moments.lua",
		on = "raincheck",
		does = "Clicking the raincheck close button hides the offer card.",
		check = function(ctx)
			ok(not (ctx.W.UI.state.rcOffer and ctx.W.UI.state.rcOffer.open), "raincheck offer closed")
		end,
	},
	{
		id = "Accept <Button> @Moments.lua",
		on = "raincheck",
		skip = "sends raincheck acceptance to another player",
	},
	{
		id = "No thanks <Button> @Moments.lua",
		on = "raincheck",
		skip = "sends raincheck decline to another player",
	},
}
