-- Wuber Lab (developer only, never ship): the tester's test plan (TESTPLAN.md) as data for the Plan tab.
-- sections -> steps. A step: id, text, who (a small tag), check (a "Checks" item), sub (a
-- sub-heading shown above it), and how it can tick itself:
--   sig   = { signal, ... }  any one of these signals (Hooks.lua / Plan.lua send them)
--   all   = { signal, ... }  every one of these, seen this session
--   fake  = true             fake drivers count (otherwise a fake ride never ticks it)
--   probe = name, perChar = { keys }   a check run at login on each named character; ticks when
--                            every one of them reported ok (results are shared like ticks)
-- Steps with none of these are ticked by hand.

local _, L = ...

local ALL = { "anita lift", "farra way", "hayley cab", "wuber rocks" }
local ROCKS = { "wuber rocks" }

local function S(id, text, who, auto)
	local s = { id = id, text = text, who = who }
	for k, v in pairs(auto or {}) do s[k] = v end
	return s
end
local function C(id, text, who, auto)
	local s = S(id, text, who, auto)
	s.check = true
	return s
end

L.PLAN = {
	{ id = "r232", title = "Wuber 2.3.2 release checklist (tonight)",
		intro = "About 10 minutes. Quit WoW and start it again first (not /reload). Passive mode records the evidence; tick each line as you go.",
		steps = {
			S("r232_1", "Before you play: type /console taintLog 1. Play the whole session: no \"blocked\" popup at any time.", "all four"),
			S("r232_2", "Type /lab passive on in all four windows before selling. At the end, /lab passive status: no fails.", "all four"),
			S("r232_3", "A real trade: the rider opens the trade and types the gold themselves; Wuber sees the payment and the ride is paid.", "Anita, Wuber Rocks",
				{ sig = { "paid_trade", "cashier" } }),
			S("r232_4", "A real portal click: summon the rider; they click the portal and arrive; the ride ends as done for both.", "all four"),
			S("r232_5", "Photo tour on Anita only: Tools > Start photo tour (or /lab tour) with no trade open. Leave that window alone till it finishes, then look through the shots.", "Anita"),
			S("r232_6", "Nameplates on (Ctrl+V): look at a Wuber user's nameplate. Then in a dungeon: no error, nothing drawn.", "any"),
			S("r232_7", "Open Confirm folded and unfolded: the driver card, the map and the verdict are all readable.", "Wuber Rocks"),
			S("r232_8", "Open the world map and the Ride map: pins, the route and their tooltips show.", "Wuber Rocks"),
			S("r232_9", "As a rider: Home lists only [Wuber] drivers; book one; the Ride screen follows them.", "Wuber Rocks"),
			S("r232_10", "Driver console: go online, take a rider from the queue, read the row tooltip, go offline.", "Anita"),
			S("r232_11", "If time allows, a quick look: Trips, Settings search and the Settings panel, the update notice line in Settings.", "Wuber Rocks"),
			S("r232_12", "Log out of all four normally (not Alt-F4) so WoW saves the logs, then tell the person running the test \"done\".", "all four",
				{ probe = "logout", perChar = ALL }),
		} },
	{ id = "v22", title = "Wuber 2.2: today's tests (no shards needed)",
		intro = "Restart WoW fully once (Wuber Lab has a new file). Then /lab sim on Anita AND Wuber Rocks: both show TEST MODE. Tick each line by hand.",
		steps = {
			S("v22_1", "Drive tab on each Warlock: if it says your old summoning addon is still on, switch it off and let it reload.", "Warlocks"),
			S("v22_2", "Anita: Set up driving > My own characters > send offers; Yes on Farra and Hayley; Done; press Open.", "Anita"),
			S("v22_3", "Wuber Rocks next to Anita: tap Anita's card. The confirm screen is one clean sheet with a 'Flying here costs' line.", "Wuber Rocks"),
			S("v22_4", "Tip slider to 10%: it says 'type 55s'. Press Request summon; Anita invites by herself.", "Wuber Rocks"),
			S("v22_5", "Anita: click the big button (Summon Wuber Rocks). Farra and Hayley turn red CLICK THE PORTAL: /lab simclick on each.", "Anita, Farra, Hayley"),
			S("v22_6", "Wuber Rocks: Accept the pretend summon card. Then open a trade with Anita, type 55s, click Trade.", "Wuber Rocks"),
			C("v22_7", "Anita: thank-you whisper sent, gold coin effect, the ride on Earnings (heatmap) and the payment counted once.", "Anita"),
			C("v22_8", "Second ride: Anita's queue shows '2nd ride with you'.", "Anita"),
			C("v22_9", "Stranger check: mid-ride, Farra opens a trade with Wuber Rocks: Wuber Rocks gets a warning and no 'type the fare' strip.", "Farra, Wuber Rocks"),
			C("v22_10", "Raid summons: make a raid, Drive tab > Raid summons, tick Anita, Start. Wuber Rocks types 123 in raid chat: queued; Anita's button summons; 'nvm' drops them.", "all four"),
			C("v22_11", "Any class: on a non-Warlock set up driving with Anita as summoner: the rider's pay strip says Pay Anita.", "any"),
			C("v22_12", "Close the service on Anita: the end-of-shift card shows. Trips: time saved counts up. Settings: Replay tips works.", "Anita, Wuber Rocks"),
			C("v22_13", "Toasts never cover the Ride/Trips/Drive tabs; unpaid ride end shows a grey coin, not a tick.", "Wuber Rocks"),
		} },
	{ id = "s0", title = "Before you start",
		intro = "Wuber 1.1 adds new files, so close every WoW window fully before you start; a /reload won't load them.",
		steps = {
			S("s0_1", "Close all WoW clients.", "all four", { probe = "fresh", perChar = ALL }),
			S("s0_2", "At the character screen on each account, open AddOns and set: Wuber ticked on all four; Ritual Rides ticked on Anita, Farra and Hayley, and left ticked on Wuber Rocks too (needed for the bell); Wuber Test unticked everywhere; Wuber Lab ticked on all four; OpenMap ticked if you use it.",
				"all four", { probe = "addons", perChar = ALL }),
			S("s0_3", "Turn on System > Sound > Sound in Background on Wuber Rocks, so you hear the bell while Anita's window is in front.",
				"Wuber Rocks", { probe = "sound", perChar = ROCKS }),
			S("s0_4", "F1 is the multibox swap key, so it may stay bound in game (this step always ticks; /lab f1 require makes it insist F1 is unbound).", "all four",
				{ probe = "f1", perChar = ALL }),
		} },
	{ id = "s1", title = "Windows: three locks, Wuber Rocks on top, F1 to swap",
		steps = {
			S("s1_1", "In PowerShell: cd <the Lab scripts folder> then .\\start4.ps1. It opens the three Warlocks, then a fourth window exactly over Anita's, then the F1 swap key in a minimised window. Log in all four.",
				"PC", { probe = "fresh", perChar = ALL }),
			S("s1_2", "Your three windows didn't move or shrink, and Wuber Rocks sits exactly over Anita.", "PC"),
			S("s1_3", "Press F1 to flip between Wuber Rocks and Anita, and again to flip back.", "PC"),
			S("s1_4", "On Anita (a Warlock window, not Wuber Rocks) type /rr bell Wuber Rocks, then /rr bell test. Wuber Rocks, not Anita, should show the banner, ring and flash its taskbar icon.",
				"Anita, then Wuber Rocks", { sig = { "bell_rang" } }),
			C("s1_c1", "Wuber Rocks sits exactly over Anita", "PC"),
			C("s1_c2", "The other two windows didn't move", "PC"),
			C("s1_c3", "F1 swaps both ways", "PC"),
			C("s1_c4", "The bell rings on Wuber Rocks", "Wuber Rocks", { sig = { "bell_rang" } }),
		} },
	{ id = "s2", title = "Test 1: the app on Wuber Rocks (5 minutes)",
		steps = {
			S("s2_1", "Type /wuber. The app opens on Home with the logo top left and Ride, Trips and Drive tabs.", "Wuber Rocks", { sig = { "app_open" } }),
			S("s2_2", "Click the gear, scroll to the bottom and click Check my game. Take a screenshot of the results.", "Wuber Rocks", { sig = { "selftest_ui" } }),
			S("s2_3", "In Settings, hover over a few options. Each should show a tooltip.", "Wuber Rocks", { sig = { "tip" }, minCount = 3 }),
			S("s2_4", "Drag the \"My time is worth\" slider and the window size slider. If they won't drag, try the mouse wheel.", "Wuber Rocks", { sig = { "slider" } }),
			S("s2_5", "Open Trips: level, stats tiles and the milestone grid, all locked for now.", "Wuber Rocks", { sig = { "trips_tab" } }),
			S("s2_6", "Close the app and open it from the minimap button.", "Wuber Rocks", { sig = { "minimap" } }),
			C("s2_c1", "No red Lua errors on login or opening the app", "Wuber Rocks"),
			C("s2_c2", "Check my game screenshot taken", "Wuber Rocks"),
			C("s2_c3", "Tooltips show", "Wuber Rocks", { sig = { "tip" }, minCount = 3 }),
			C("s2_c4", "Sliders drag (or only the wheel works)", "Wuber Rocks", { sig = { "slider" } }),
			C("s2_c5", "Minimap button opens the app", "Wuber Rocks", { sig = { "minimap" } }),
		} },
	{ id = "s3", title = "Test 2: a full ride, Wuber Rocks to your team",
		intro = "Put Wuber Rocks in a different zone first (Orgrimmar works if the team is elsewhere).",
		steps = {
			S("s3_d1", "/rr price 50s (or your normal price, at least 50s) and /rr on. Don't type /rr on on Wuber Rocks.", "Anita",
				{ sub = "Driver side (Anita)", sig = { "beacon_open" } }),
			S("s3_d2", "Team grouped with Anita as leader, or ungrouped with Anita as main caster.", "Anita", { sub = "Driver side (Anita)" }),
			S("s3_r1", "/wuber. Anita's card is at the top with the crown, Founder chip and the strongest glow.", "Wuber Rocks",
				{ sub = "Rider side (F1 to Wuber Rocks)" }),
			S("s3_r2", "Click Anita's card. The confirm screen shows price, destination and time saved.", "Wuber Rocks",
				{ sub = "Rider side (F1 to Wuber Rocks)", sig = { "confirm_shown", "ride_requesting" } }),
			S("s3_r3", "Click Request. Wuber Rocks whispers Anita \"WTB summon to (place) for 50s\". Check Anita's chat.", "Wuber Rocks",
				{ sub = "Rider side (F1 to Wuber Rocks)", sig = { "whisper_wtb", "whisper_wtb_in" } }),
			S("s3_r4", "Anita's side accepts. Wuber Rocks shows Accepted and your place in line with a countdown.", "Wuber Rocks",
				{ sub = "Rider side (F1 to Wuber Rocks)", sig = { "accept_msg", "ride_accepted" } }),
			S("s3_r5", "The invite arrives and is accepted with no click, then the bell rings on Wuber Rocks.", "Wuber Rocks",
				{ sub = "Rider side (F1 to Wuber Rocks)", sig = { "auto_accept" } }),
			S("s3_r6", "The team summons. Accept the summon box. The portal effect plays, then the arrival scene.", "Wuber Rocks",
				{ sub = "Rider side (F1 to Wuber Rocks)", sig = { "ride_arrived" } }),
			S("s3_r7", "A trade opens from the cashier. Wuber shows what to type under the trade window: type 50 in silver, click Trade. Wuber sees the payment.", "Wuber Rocks",
				{ sub = "Rider side (F1 to Wuber Rocks)", all = { "pay_clicked", "pay_exact" } }),
			S("s3_r8", "A few seconds after paying, Wuber Rocks leaves the group by itself. Rate the ride. First Ride milestone pops.", "Wuber Rocks",
				{ sub = "Rider side (F1 to Wuber Rocks)", all = { "auto_left", "rated", "milestone_pop" } }),
			C("s3_c1", "Visible WTB whisper reached Anita", "Anita", { sig = { "whisper_wtb_in" } }),
			C("s3_c2", "Invite accepted with no click", "Wuber Rocks", { sig = { "auto_accept" } }),
			C("s3_c3", "Summon arrived and the effects played", "Wuber Rocks", { all = { "ride_arrived", "fx_arrival" } }),
			C("s3_c4", "Paid the fare by typing it; Wuber marked the ride paid", "Wuber Rocks", { sig = { "pay_exact" } }),
			C("s3_c5", "Left the group by itself", "Wuber Rocks", { sig = { "auto_left" } }),
			C("s3_c6", "Milestone pop and rating worked", "Wuber Rocks", { all = { "milestone_pop", "rated" } }),
			C("s3_c7", "Ritual Rides logged the ride (/rr log on Anita)", "Anita", { sig = { "rr_logride" } }),
		} },
	{ id = "s4", title = "Test 3: shortcuts and things going wrong",
		intro = "Any order, after Test 2 works.",
		steps = {
			S("s4_1", "Rebook: open /wuber after Test 2 -> a \"Your usual\" card with Ride again at the top of Home.", "Wuber Rocks"),
			S("s4_2", "Cancel: Request, then Cancel ride before Anita accepts -> cancelled on both sides, no invite.", "Wuber Rocks + Anita",
				{ sig = { "cancel_early" } }),
			S("s4_3", "Driver busy: Lab Tools > Fake drivers, book the busy one -> you can book and see your place in the queue.", "Wuber Rocks",
				{ sig = { "busy_queue" }, fake = true }),
			S("s4_4", "Combat: Request while fighting a mob -> Wuber waits or tells you to finish the fight; no Lua error.", "Wuber Rocks",
				{ sig = { "combat_request" } }),
			S("s4_5", "Book from map: world map, hover the team's town, Ctrl-click (and try the Ride here button) -> booking screen for that place.",
				"Wuber Rocks", { sig = { "map_ctrl", "map_button" } }),
			S("s4_6", "Driver offline: Request, then log Anita out -> Wuber Rocks says the driver went offline and lets you pick again.",
				"Wuber Rocks + Anita", { sig = { "driver_offline" } }),
			S("s4_7", "Price below 50s: on Anita /rr price 30s -> Anita disappears from Wuber with a message to set 50s. Set it back.", "Anita",
				{ sig = { "rr_lowfare" } }),
			S("s4_8", "Hide a driver: right-click a card, Hide -> the card goes; Settings > Hidden drivers brings it back.", "Wuber Rocks",
				{ sig = { "hidden" }, fake = true }),
			S("s4_9", "Favourite: heart on Anita's card, log Anita out and back in -> a toast on Wuber Rocks: Anita is online.", "Wuber Rocks + Anita",
				{ sig = { "fav_toast" } }),
		} },
	{ id = "s5", title = "Test 4: looks and fun (judged by eye)",
		steps = {
			S("s5_1", "On Wuber Rocks, Settings > Turn on friendly nameplates. Near the team: a spinning gold crown over Anita, Farra and Hayley.", "Wuber Rocks"),
			S("s5_2", "Mouse over Anita: tooltip says \"Wuber founder\".", "Wuber Rocks"),
			S("s5_3", "Anita's card on Home: gold-violet border, crown, Founder chip, shimmer every few seconds.", "Wuber Rocks"),
			S("s5_4", "World map: Anita's pin bigger, crowned, sparkling; dotted route line flowing to it during a ride.", "Wuber Rocks"),
			S("s5_5", "Settings > Effects: try Full, Light and Off during a ride.", "Wuber Rocks"),
			S("s5_6", "On Anita: a small burst when paid; a 5-star rating shows a coin shower.", "Anita", { all = { "fx_paid", "fx_coins" } }),
			C("s5_c1", "Crowns over the team's heads", "Wuber Rocks"),
			C("s5_c2", "Founder card shimmer and glow look right", "Wuber Rocks"),
			C("s5_c3", "Map pin and route line", "Wuber Rocks"),
			C("s5_c4", "Effects look good, not blocky or with dark edges", "Wuber Rocks"),
		} },
	{ id = "s6", title = "When you're done",
		steps = {
			S("s6_1", "Log out of all four characters normally (not Alt-F4) so WoW saves the logs, then tell the person running the test \"done\".", "all four",
				{ probe = "logout", perChar = ALL }),
			S("s6_2", "Also send: the Check my game screenshot, screenshots of anything that looked wrong, any red Lua error text.", "you"),
		} },
}

L.PLAN_CAST = ALL
