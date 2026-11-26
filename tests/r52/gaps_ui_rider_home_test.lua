-- Tests of UI.Rider.Home. Adopted in r52 from the fable-2411 draft (job 2694); loaded by tests/run.lua with its helper table T.
-- Pins: UI.PinBounty / UI.CancelBounty / UI.BountyMine / UI.BountyPlace (what is refused, which toast says what).
-- Pins: UI.ToggleWatch / UI.IsWatching (the bell's saved state, its toasts, the odd-answer fallback).
-- Pins: the raid card (title and line per state, Request a summon as the main button, ask / cancel toasts).
-- Pins: Your usual (not offered for a paused or re-routed driver, re-checked at click time) and Mod.WhyUsual's words.
-- Pins: Mod.WhyBounty's words (why no bounty is offered), Mod.usualHours' evidence rules (5 sightings, 3 days, 3 hours).
-- Pins: the empty state's sub line (usual hours, last driver seen, plain line), the Ping button's failure toasts and cooldown.
-- Pins: UI.FillPlaceChips order (most drivers first, paused half, Unknown left out) and that a chip filters and All clears.
-- Why it matters to a player: Home is the first screen a rider sees. If these broke they could pin a bounty that silently does
-- nothing, be offered "Ride again" with a driver who has gone, see "nobody's there" while someone is, or tap a chip and see no filter.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function drv(env, name, dest, price, extra)
	local d = { name = name, key = name:lower(), short = name, dest = dest, price = price, state = "open", team = 3,
		service = name .. "'s Rides", heard = env.GetTime(), queue = 0 }
	for k, v in pairs(extra or {}) do d[k] = v end
	return d
end

-- a rider with Home open and the drivers given (UI.Drivers / UI.Driver answer from the list); usual: { dest, driverKey }
-- (the shape tests/d2/d2_g_home_test.lua uses)
local function world(make, usual)
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local UI = c.W.UI
	local list = make and make(c.env) or {}
	UI.Drivers = function() return list end
	UI.Driver = function(key)
		for _, d in ipairs(list) do if d.key == key then return d end end
	end
	c.W.Usual = function() return usual end
	c.W.AlreadyAt = function() return nil end
	UI.Toggle(true)
	w:advance(3)
	UI.Refresh(true)
	w:advance(2)
	return w, c, UI.state.screens.home, list
end

-- every toast the UI raises, as { text, kind }
local function toasts(UI)
	local got = {}
	UI.Toast = function(msg, kind) got[#got + 1] = { msg, kind } end
	return got
end

-- a W.Bounty stand-in (Demand kept: other modules ask for it)
local function bounty(mine, pinResult, pinWhy, cancelResult)
	return { Mine = function() return mine end, Demand = function() return {} end,
		Pin = function(place, copper) return pinResult, pinWhy end, Cancel = function() return cancelResult end }
end

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.home: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("UI.Rider.Home", "tests/ui/rider/home_test.lua", {
		["UI.IsWatching"] = "function", ["UI.ToggleWatch"] = "function", ["UI.RaidHere"] = "function", ["UI.BuildRaidCard"] = "function",
		["UI.FillPlaceChips"] = "function", ["UI.LayoutCards"] = "function", ["UI.BountyMine"] = "function", ["UI.BountyPlace"] = "function",
		["UI.PinBounty"] = "function", ["UI.CancelBounty"] = "function", ["UI.BOUNTY_PICKS"] = "table", ["UI.BOUNTY_NOTE"] = "string",
		["Mod.WhyUsual"] = "function", ["Mod.WhyBounty"] = "function", ["Mod.buildHome"] = "function", ["Mod.homeFrame"] = "function",
		["Mod.foldLayout"] = "function", ["Mod.usualHours"] = "function", ["Mod.usualPlace"] = "function",
	})
	local UI = W.UI
	eq(UI.BOUNTY_PICKS[1], 5000, "first quick pick: 50s") -- Home.lua:278
	eq(UI.BOUNTY_PICKS[2], 7500, "second: 75s")
	eq(UI.BOUNTY_PICKS[3], 10000, "third: 1g")
	eq(#UI.BOUNTY_PICKS, 3, "three picks, then Custom")
	eq(UI.BOUNTY_NOTE, "A bounty is a wish, not a payment. You still pay the driver's fare.", "the note under every bounty") -- Home.lua:279
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.home: PinBounty refuses nonsense, hands place and price to the bounty wire, and says why a pin failed", function()
	local w, c = world(nil, nil)
	local W, UI = c.W, c.W.UI
	local Kit = W.Mod("UI.Kit")
	local got, pins = toasts(UI), {}
	local result, why = true, nil
	W.Bounty = bounty(nil)
	W.Bounty.Pin = function(place, copper) pins[#pins + 1] = { place, copper } return result, why end
	eq(UI.PinBounty(nil, 5000), false, "no place") -- Home.lua:315
	eq(UI.PinBounty("Gadgetzan", 0), false, "zero is not a bounty")
	eq(UI.PinBounty("Gadgetzan", -5), false, "nor a negative one")
	eq(UI.PinBounty("Gadgetzan", nil), false, "nor no price")
	eq(#pins, 0, "nothing reached the wire")
	eq(#got, 0, "a refused ask raises no toast")
	eq(UI.PinBounty("Gadgetzan", 7500), true, "a good pin")
	eq(pins[1][1], "Gadgetzan", "the place")
	eq(pins[1][2], 7500, "the price in copper")
	eq(got[1][1], "Bounty pinned: drivers see you want Gadgetzan", "the toast") -- Home.lua:320
	eq(got[1][2], "watch", "its kind")
	eq(Kit.ui.bountyPlace, "Gadgetzan", "Home remembers the pinned place")
	result = false
	for _, row in ipairs({ { "served", "Someone summons there now: book them" }, { "ride", "Not during a ride" },
		{ "place", "Pick a town or city" }, { "nonsense", "Couldn't pin a bounty right now" } }) do
		why = row[1]
		eq(UI.PinBounty("Gadgetzan", 5000), false, "refused: " .. row[1])
		eq(got[#got][1], row[2], "toast for " .. row[1]) -- Home.lua:322
		eq(got[#got][2], "warn", "a warning")
	end
	why = nil
	UI.PinBounty("Gadgetzan", 5000)
	eq(got[#got][1], "Couldn't pin a bounty right now", "no reason given")
	W.Bounty.Pin = nil
	eq(UI.PinBounty("Gadgetzan", 5000), false, "no Pin on the wire: false, no error")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.home: CancelBounty clears the remembered place, thanks only when the wire took it down", function()
	local w, c = world(nil, nil)
	local W, UI = c.W, c.W.UI
	local Kit = W.Mod("UI.Kit")
	local got = toasts(UI)
	W.Bounty = bounty(nil, true, nil, true)
	Kit.ui.bountyPlace = "Gadgetzan"
	eq(UI.CancelBounty(), true, "taken down") -- Home.lua:329
	eq(got[1][1], "Bounty taken down", "toast")
	eq(got[1][2], "info", "kind")
	eq(Kit.ui.bountyPlace, nil, "forgotten")
	W.Bounty = bounty(nil, true, nil, false)
	Kit.ui.bountyPlace = "Gadgetzan"
	eq(UI.CancelBounty(), false, "the wire said no")
	eq(#got, 1, "no second toast")
	eq(Kit.ui.bountyPlace, nil, "the place is dropped either way")
	W.Bounty.Cancel = nil
	eq(UI.CancelBounty(), false, "no Cancel on the wire: false, no error")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.home: BountyMine needs a table with a place; BountyPlace only offers a known town nobody open serves", function()
	local w, c = world(nil, nil)
	local W, UI = c.W, c.W.UI
	local mine
	W.Bounty = bounty(nil)
	W.Bounty.Mine = function() return mine end
	eq(UI.BountyMine(), nil, "none")
	mine = "Gadgetzan"
	eq(UI.BountyMine(), nil, "not a table")
	mine = { copper = 5000 }
	eq(UI.BountyMine(), nil, "no place") -- Home.lua:287
	mine = { place = "Gadgetzan", copper = 5000 }
	eq(UI.BountyMine(), mine, "the wire's own table")
	W.Bounty.Mine = "nope"
	eq(UI.BountyMine(), nil, "Mine is not a function")
	W.Bounty.Mine = function() return nil end
	local exact = { name = "Gadgetzan", kind = "town" }
	W.ExactPlace = function(p) return exact end
	eq(UI.BountyPlace("Gadgetzan", {}), "Gadgetzan", "a town nobody serves")
	eq(UI.BountyPlace(nil, {}), nil, "no place")
	eq(UI.BountyPlace("Gadgetzan", { { state = "open", dest = "gadgetzan" } }), nil, "an open driver serves it (case-insensitive)") -- Home.lua:306
	eq(UI.BountyPlace("Gadgetzan", { { state = "busy", dest = "Gadgetzan" }, { state = "paused", dest = "Gadgetzan" } }), "Gadgetzan", "busy and paused drivers do not count")
	eq(UI.BountyPlace("Gadgetzan", { { state = "open", dest = "Ratchet" } }), "Gadgetzan", "an open driver elsewhere does not block it")
	exact = { name = "Tanaris", kind = "zone" }
	eq(UI.BountyPlace("Tanaris", {}), nil, "a zone is not a place to pin")
	exact = { kind = "town" }
	eq(UI.BountyPlace("Gadgetzan", {}), nil, "no name")
	exact = nil
	eq(UI.BountyPlace("Gadgetzan", {}), nil, "unknown place")
	exact = { name = "Gadgetzan", kind = "town" }
	W.Bounty.Place = function(p) return nil end
	eq(UI.BountyPlace("Gadgetzan", {}), nil, "the wire refuses the place") -- Home.lua:296
	local asked
	W.Bounty.Place = function(p) return "Gadgetzan" end
	W.ExactPlace = function(p) asked = p return exact end
	eq(UI.BountyPlace("gadget", {}), "Gadgetzan", "the wire's name is the one looked up")
	eq(asked, "Gadgetzan", "ExactPlace got the wire's name")
	W.ExactPlace = nil
	eq(UI.BountyPlace("Gadgetzan", {}), nil, "no ExactPlace in the game: nothing offered")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.home: the bell: ToggleWatch flips IsWatching, tells the rider, and a nonsense answer falls back to the saved state", function()
	local w, c = world(nil, nil)
	local W, UI = c.W, c.W.UI
	local got = toasts(UI)
	W.ToggleWatch, W.IsWatched = nil, nil -- the plain saved-variable path
	local fired = 0
	W.Listen("SETTINGS", function(key) if key == "watch" then fired = fired + 1 end end)
	eq(UI.IsWatching(nil), false, "no place, no watch") -- Home.lua:89
	eq(UI.IsWatching("Undercity"), false, "not watched yet")
	eq(UI.ToggleWatch(nil), nil, "no place: nothing happens")
	eq(UI.ToggleWatch("Undercity"), true, "on")
	eq(UI.IsWatching("Undercity"), true, "watched")
	eq(got[1][1], "We'll tell you when a driver to Undercity comes online", "toast on") -- Home.lua:110
	eq(got[1][2], "watch", "kind")
	eq(UI.ToggleWatch("Undercity"), false, "off")
	eq(UI.IsWatching("Undercity"), false, "no longer watched")
	eq(got[2][1], "No more alerts for Undercity", "toast off")
	eq(got[2][2], "info", "kind")
	eq(fired, 2, "SETTINGS watch fired each time") -- Home.lua:108
	-- Net's own toggle answers something that is not a boolean: Home asks IsWatched instead
	W.ToggleWatch = function() return "weird" end
	W.IsWatched = function() return true end
	eq(UI.ToggleWatch("Ratchet"), true, "falls back to IsWatched") -- Home.lua:101
	W.IsWatched = function() return false end
	eq(UI.ToggleWatch("Ratchet"), false, "and to its false")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.home: the raid card: its words per state, Request a summon is the main button, ask and cancel toast", function()
	local w, c, home = world(nil, nil)
	local W, UI = c.W, c.W.UI
	local Kit = W.Mod("UI.Kit")
	local got = toasts(UI)
	local info = { runner = "Ana Smith", place = "Ratchet", summoners = { "a", "b" } }
	W.Drive.RaidHere = function() return info end
	UI.Refresh(true)
	w:advance(1)
	local rc = home.raidCard
	ok(H.visible(rc), "the raid card is up")
	ok(not H.visible(home.empty), "and the empty screen gives way (Home.lua:1099)")
	eq(rc.title:GetText(), "Get summoned to Ratchet", "title") -- Home.lua:252
	eq(rc.sub:GetText(), W.Short("Ana Smith") .. " runs summons · 2 Warlocks", "who runs it") -- Home.lua:255
	ok(not H.visible(rc.go), "no Cancel while not queued")
	ok(H.visible(home.main) and home.main.label:GetText() == "Request a summon", "the one main button")
	info.place, info.summoners = nil, { "a" }
	UI.Refresh(true)
	w:advance(1)
	eq(rc.title:GetText(), "Get summoned to the raid", "no place named")
	eq(rc.sub:GetText(), W.Short("Ana Smith") .. " runs summons · 1 Warlock", "one Warlock, singular")
	local asks, cancels = 0, 0
	local askResult, askWhy = true, nil
	W.Drive.RaidAsk = function() asks = asks + 1 return askResult, askWhy end
	W.Drive.RaidCancel = function() cancels = cancels + 1 end
	home.main:Click()
	eq(asks, 1, "the main button asks the raid's runner")
	eq(got[#got][1], "Asked " .. W.Short("Ana Smith") .. "'s Warlocks for a summon", "toast") -- Home.lua:217
	eq(got[#got][2], "found", "kind")
	askResult, askWhy = false, "full"
	home.main:Click()
	eq(got[#got][1], "full", "the refusal's own reason")
	eq(got[#got][2], "warn", "a warning")
	askWhy = nil
	home.main:Click()
	eq(got[#got][1], "Couldn't ask right now", "no reason given")
	-- queued: a Cancel pill on the card, no main button
	info.queued, info.position = true, 1
	UI.Refresh(true)
	w:advance(1)
	eq(rc.title:GetText(), "You're on the summon list", "queued title")
	eq(rc.sub:GetText(), "You're next", "first in line")
	ok(H.visible(rc.go) and rc.go.label:GetText() == "Cancel request", "Cancel request shows")
	ok(not H.visible(home.main), "no main button while queued (Home.lua:1076)")
	info.position = 3
	UI.Refresh(true)
	w:advance(1)
	eq(rc.sub:GetText(), "You're " .. Kit.ordinal(3) .. " in line", "third in line")
	info.position = nil
	UI.Refresh(true)
	w:advance(1)
	eq(rc.sub:GetText(), "Accept when it pops", "no position known")
	info.state = "summoning"
	UI.Refresh(true)
	w:advance(1)
	eq(rc.title:GetText(), "Your summon is coming", "the Warlock has started")
	rc.go:Click()
	eq(cancels, 1, "Cancel request leaves the list")
	eq(got[#got][1], "You're off the summon list", "toast")
	eq(got[#got][2], "info", "kind")
	-- no runner: no card at all
	W.Drive.RaidHere = function() return { runner = "" } end
	eq(UI.RaidHere(), nil, "a raid with no runner is no raid") -- Home.lua:204
	W.Drive.RaidHere = function() return "raid" end
	eq(UI.RaidHere(), nil, "nor is a non-table answer")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.home: Your usual is not offered for a paused or re-routed driver, and a click re-checks the driver first", function()
	local w, c, home, list = world(function(env)
		return { drv(env, "Anita", "Undercity", 5000, { service = "Anita's Portals" }), drv(env, "Mia", "Thunder Bluff", 7500) }
	end, { dest = "Undercity", driverKey = "anita" })
	local UI = c.W.UI
	ok(H.visible(home.usual) and home.usual.key == "anita", "control: the usual card is up for Anita")
	eq(home.usual.title:GetText(), "Undercity", "the place")
	eq(home.usual.sub:GetText(), "with Anita's Portals", "the driver's service") -- Home.lua:1055
	-- she is busy: still offered, and the card says so
	list[1].state = "busy"
	UI.Refresh(true)
	w:advance(1)
	eq(home.usual.sub:GetText(), "with Anita's Portals · busy", "busy is said")
	-- she pauses between the last refresh and the click: the click does not open a booking for her
	local shown = {}
	local real = UI.Show
	UI.Show = function(screen, key) if screen == "confirm" then shown[#shown + 1] = key else return real(screen, key) end end
	list[1].state = "paused"
	home.main:Click()
	eq(#shown, 0, "no booking opened for a paused driver") -- Home.lua:152
	eq(home.usual.key, nil, "the card forgot her")
	ok(not H.visible(home.usual), "and is hidden")
	-- she is back but now serves Orgrimmar: the usual place is not offered while she summons elsewhere
	list[1].state, list[1].dest = "open", "Orgrimmar"
	UI.Refresh(true)
	w:advance(1)
	ok(not H.visible(home.usual), "re-routed driver: no card (Home.lua:145)")
	-- back on route: the card returns and the click books her
	list[1].dest = "Undercity"
	UI.Refresh(true)
	w:advance(1)
	ok(H.visible(home.usual), "back on the usual route")
	home.main:Click()
	eq(shown[1], "anita", "the click opens the booking for Anita")
	UI.Show = real
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.home: WhyUsual says why Your usual is not on Home, in the order the screen checks", function()
	local Home
	local usualIs = { dest = "Undercity", driverKey = "anita", driver = "Anita" }
	local w, c, home, list = world(function(env) return { drv(env, "Anita", "Undercity", 5000) } end, usualIs)
	local W, UI = c.W, c.W.UI
	Home = W.Mod("UI.Rider.Home")
	eq(Home.WhyUsual(), nil, "shown: nothing to explain")
	-- paused
	list[1].state = "paused"
	eq(Home.WhyUsual(), "Your usual: Anita is paused right now.", "paused") -- Home.lua:1433
	-- another driver is open at the place while the usual one is re-routed
	list[1].state, list[1].dest = "open", "Orgrimmar"
	list[2] = drv(c.env, "Bob", "Undercity", 5000)
	eq(Home.WhyUsual(), "Your usual: Anita is not open at Undercity right now.", "somebody else is open there") -- Home.lua:1434
	-- the usual driver is gone from the list altogether, another is open at the place
	table.remove(list, 1)
	eq(Home.WhyUsual(), "Your usual: Anita is not open at Undercity right now.", "offline, somebody else is there") -- Home.lua:1441
	table.remove(list, 1)
	eq(Home.WhyUsual(), "Your usual: nobody is open at Undercity.", "nobody at all") -- Home.lua:1445
	-- standing there
	W.AlreadyAt = function() return "Undercity" end
	eq(Home.WhyUsual(), "Your usual: you are already there.", "already there") -- Home.lua:1412
	W.AlreadyAt = function() return nil end
	-- no rides
	W.Usual = function() return nil end
	eq(Home.WhyUsual(), "Your usual: no rides yet, so no usual place.", "no usual at all") -- Home.lua:1411
	-- a search hides it, whatever else is true
	W.Usual = function() return usualIs end
	UI.SetSearch("zzzq")
	eq(Home.WhyUsual(), "Your usual: hidden while you search.", "hidden while you search") -- Home.lua:1408
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.home: WhyBounty says why no bounty is offered (driving switch, served, online, raid, place, already there, pinned, open driver)", function()
	local w, c, home, list = world(nil, { dest = "Undercity", driverKey = "nobody" })
	local W, UI = c.W, c.W.UI
	local Home = W.Mod("UI.Rider.Home")
	local mine
	W.Bounty = bounty(nil)
	W.Bounty.Mine = function() return mine end
	local exact = { name = "Gadgetzan", kind = "town" }
	W.ExactPlace = function(p) return exact end
	-- nothing searched and no usual place: nothing to explain
	W.Usual = function() return nil end
	eq(Home.WhyBounty(), nil, "no search, no usual place") -- Home.lua:1481
	-- the usual place, drivers online
	W.Usual = function() return { dest = "Undercity" } end
	list[1] = drv(c.env, "Bob", "Ratchet", 5000)
	eq(Home.WhyBounty(), "Bounty offers: drivers are online right now.", "drivers online, usual place") -- Home.lua:1484
	table.remove(list, 1)
	-- the raid runs summons
	W.Drive.RaidHere = function() return { runner = "Ana" } end
	eq(Home.WhyBounty(), "Bounty offers: not while your raid runs summons.", "raid") -- Home.lua:1486
	W.Drive.RaidHere = function() return nil end
	-- the usual place, nothing in the way, the bounty is already pinned
	mine = { place = "Gadgetzan", copper = 5000 }
	eq(Home.WhyBounty(), "Bounty offers: you already have one pinned.", "pinned") -- Home.lua:1494
	mine = nil
	-- you are an open driver yourself
	local realBeacon = W.DriverBeacon
	W.DriverBeacon = function() return { state = "open", dest = "Undercity", price = 5000 } end
	eq(Home.WhyBounty(), "Bounty offers: you are an open driver.", "own beacon") -- Home.lua:1496
	W.DriverBeacon = realBeacon
	-- standing in the usual place
	W.AlreadyAt = function() return "Undercity" end
	eq(Home.WhyBounty(), "Bounty offers: you are already there.", "already there (usual)") -- Home.lua:1493
	W.AlreadyAt = function() return nil end
	-- a searched place
	UI.SetSearch("Gadgetzan")
	eq(Home.WhyBounty(), nil, "a town nobody serves: the offer is due") -- Home.lua:1490
	W.AlreadyAt = function() return "Gadgetzan" end
	eq(Home.WhyBounty(), "Bounty offers: you are already there.", "already there (searched)")
	W.AlreadyAt = function() return nil end
	exact = { name = "Gadgetzan", kind = "zone" }
	eq(Home.WhyBounty(), "Bounty offers: only for a town or city.", "a zone") -- Home.lua:1489
	exact = { name = "Gadgetzan", kind = "town" }
	list[1] = drv(c.env, "Cal", "Gadgetzan", 5000)
	eq(Home.WhyBounty(), "Bounty offers: a driver already serves that place.", "served") -- Home.lua:1484
	-- the driving switch beats all of it
	W.Drive.IsOpen = function() return true end
	W.db.drive = W.db.drive or {}
	W.db.drive.opts = W.db.drive.opts or {}
	W.db.drive.opts.watchBounty = false
	eq(Home.WhyBounty(), "Bounties (driving): off in Settings.", "the console's switch") -- Home.lua:1474
	T.clean(w)
end)

-- a local-time stamp: the given hour, `back` days before today (the PC's own clock, as Home reads it)
local function at(base, back, hour)
	local t = os.date("*t", base)
	return os.time({ year = t.year, month = t.month, day = t.day - back, hour = hour, min = 30 })
end

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.home: usualHours needs 5 sightings on 3 days, half in one 3-hour stretch, none stale or from the future", function()
	local w, c = world(nil, nil)
	local W = c.W
	local Home = W.Mod("UI.Rider.Home")
	local base = c.env.time()
	local function rides(list) W.db.rides = {} for i, p in ipairs(list) do W.db.rides[i] = { at = at(base, p[1], p[2]), dest = "Undercity" } end W.db.seenDrivers = nil end
	rides({ { 1, 19 }, { 2, 19 }, { 3, 19 }, { 4, 19 }, { 5, 19 } })
	eq(Home.usualHours(), "7-8pm", "five evenings at 7: 7-8pm") -- Home.lua:501
	rides({ { 1, 11 }, { 2, 11 }, { 3, 11 }, { 4, 12 }, { 5, 12 } })
	eq(Home.usualHours(), "11am-1pm", "across noon both halves say am / pm")
	rides({ { 1, 19 }, { 2, 19 }, { 3, 19 }, { 4, 19 } })
	eq(Home.usualHours(), nil, "four sightings are not enough")
	rides({ { 1, 19 }, { 1, 20 }, { 1, 21 }, { 2, 19 }, { 2, 20 } })
	eq(Home.usualHours(), nil, "five sightings on two days are not enough") -- Home.lua:521
	rides({ { 1, 19 }, { 1, 19 }, { 1, 19 }, { 1, 19 }, { 1, 19 } })
	eq(Home.usualHours(), nil, "the same day and hour counts once")
	rides({ { 1, 1 }, { 2, 6 }, { 3, 11 }, { 4, 16 }, { 5, 21 } })
	eq(Home.usualHours(), nil, "spread all day: no stretch holds half of them") -- Home.lua:527
	rides({ { 63, 19 }, { 64, 19 }, { 65, 19 }, { 66, 19 }, { 67, 19 } })
	eq(Home.usualHours(), nil, "older than 60 days is ignored") -- Home.lua:508
	rides({ { -2, 19 }, { -3, 19 }, { -4, 19 }, { -5, 19 }, { -6, 19 } })
	eq(Home.usualHours(), nil, "stamps from the future are ignored")
	-- the rider's rides and the drivers heard both count
	W.db.rides = { { at = at(base, 1, 19) }, { at = at(base, 2, 19) }, { at = at(base, 3, 19) } }
	W.db.seenDrivers = { a = { at = at(base, 4, 19) }, b = { at = at(base, 5, 19) }, c = "junk" }
	eq(Home.usualHours(), "7-8pm", "rides and sightings together")
	W.db.rides, W.db.seenDrivers = "junk", "junk"
	eq(Home.usualHours(), nil, "malformed saved data: no hours, no error")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.home: the empty screen's line: usual hours, else the last driver seen, else the plain line", function()
	local w, c, home = world(nil, nil)
	local W, UI = c.W, c.W.UI
	local Kit = W.Mod("UI.Kit")
	local base = c.env.time()
	local e = home.empty
	W.db.rides, W.db.seenDrivers = {}, nil
	UI.Refresh(true)
	w:advance(1)
	eq(e.sub:GetText(), "Drivers show up here the moment they go online. Fares from " .. Kit.money(W.MIN_PRICE or 5000) .. ".", "the plain line") -- Home.lua:1213
	ok(not H.visible(e.subHit), "no tip target on the plain line")
	W.db.seenDrivers = { a = { at = base - 3 * 86400 - 100 } }
	UI.Refresh(true)
	w:advance(1)
	eq(e.sub:GetText(), "Last driver seen 3 days ago. Drivers appear here as soon as they open.", "the last driver heard") -- Home.lua:549
	W.db.seenDrivers = { a = { at = base - 1 * 86400 - 100 } }
	UI.Refresh(true)
	w:advance(1)
	ok(e.sub:GetText():find("Last driver seen yesterday.", 1, true), "a day and a bit: yesterday, said in words")
	W.db.rides, W.db.seenDrivers = {}, nil
	for i = 1, 5 do W.db.rides[i] = { at = at(base, i, 19) } end
	UI.Refresh(true)
	w:advance(1)
	eq(e.sub:GetText(), "Usually here 7-8pm", "real hours beat the last-seen line") -- Home.lua:1209
	ok(H.visible(e.subHit), "its tip target shows")
	eq(e.subTipTitle, "Usually here 7-8pm", "tip title")
	eq(e.subTipBody, "You've mostly seen drivers around 7-8pm (local time). They appear here as soon as they open.", "tip body, says local time") -- Home.lua:1259
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.home: place chips list where drivers go (most first, paused half, Unknown left out); a chip filters and All clears", function()
	local w, c, home, list = world(function(env)
		return { drv(env, "Ana", "Undercity", 5000), drv(env, "Bea", "Undercity", 5000), drv(env, "Cal", "Ratchet", 5000),
			drv(env, "Dan", "Ratchet", 5000, { state = "paused" }), drv(env, "Eve", "Booty Bay", 5000), drv(env, "Fay", "Unknown", 5000) }
	end, nil)
	local UI = c.W.UI
	local row = home.chips
	ok(H.visible(row), "the chips show with drivers listed")
	eq(#row.list, 4, "All and three places; Unknown is no place") -- Home.lua:706
	eq(row.list[1].place, nil, "All first")
	eq(row.list[2].place, "Undercity", "two open drivers")
	eq(row.list[3].place, "Ratchet", "one open and one paused is 1.5") -- Home.lua:708
	eq(row.list[4].place, "Booty Bay", "one")
	-- equal weight: alphabetical; spare chips are hidden
	UI.FillPlaceChips(home, { drv(c.env, "Cal", "Ratchet", 5000), drv(c.env, "Eve", "Booty Bay", 5000) })
	eq(row.list[2].place, "Booty Bay", "a tie goes alphabetical")
	eq(row.list[3].place, "Ratchet", "then Ratchet")
	ok(not row.list[4]:IsShown(), "the spare chip is hidden")
	UI.FillPlaceChips(home, {})
	ok(not row:IsShown(), "no drivers: no chip row") -- Home.lua:776
	-- a chip filters like a search; All clears it
	UI.Refresh(true)
	w:advance(1)
	c:click(row.list[2])
	w:advance(1)
	eq(home.header:GetText(), "Drivers to Undercity", "the chip searched Undercity") -- Home.lua:971
	c:click(row.list[1])
	w:advance(1)
	eq(home.header:GetText(), "Drivers online", "All clears the search")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.home: Ping drivers: failures toast their reason, a wait says how long, a success starts the 20 s cooldown", function()
	local w, c, home = world(nil, nil)
	local W, UI = c.W, c.W.UI
	local e = home.empty
	local got = toasts(UI)
	W.Ping = function() return false, "offline" end
	e.ping:Click()
	w:advance(1)
	eq(got[#got][1], "Can't reach the network right now", "offline") -- Home.lua:642
	eq(got[#got][2], "warn", "a warning")
	W.Ping = function() return false, nil end
	e.ping:Click()
	w:advance(1)
	eq(got[#got][1], "Can't ping right now", "any other refusal") -- Home.lua:647
	W.Ping = function() return false, 12 end
	e.ping:Click()
	w:advance(1)
	eq(got[#got][1], "You can ping again in 12 s", "the wait the wire named") -- Home.lua:645
	eq(got[#got][2], "info", "not alarming")
	eq(e.ping.label:GetText(), "Ping again in 12 s", "the button counts it down") -- Home.lua:1267
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.home: Ping drivers: a success thanks once, the button waits, and a second tap is ignored until the cooldown ends", function()
	local w, c, home = world(nil, nil)
	local W, UI = c.W, c.W.UI
	local e = home.empty
	local got = toasts(UI)
	local pings, why = 0, nil
	W.Ping = function() pings = pings + 1 return true, why end
	e.ping:Click()
	w:advance(1)
	eq(pings, 1, "pinged")
	eq(got[#got][1], "Asked every driver to check in", "toast") -- Home.lua:638
	eq(e.ping.label:GetText(), "Ping again in 20 s", "cooldown starts at 20 s")
	e.ping:Click()
	w:advance(1)
	eq(pings, 1, "a tap during the cooldown does nothing") -- Home.lua:628
	w:advance(21)
	UI.Refresh(true)
	eq(e.ping.label:GetText(), "Ping drivers", "back to normal after 20 s")
	why = "recent"
	e.ping:Click()
	w:advance(1)
	eq(pings, 2, "pinged again")
	eq(got[#got][1], "Drivers were just asked - they're answering", "someone else just asked")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.home: the list scrolls smoothly toward its target, the wheel moves 64 a notch and never past either end", function()
	local w, c, home = world(nil, nil)
	local Home = c.W.Mod("UI.Rider.Home")
	local ui = c.W.Mod("UI.Kit").ui
	ui.scroll, ui.scrollTarget = 0, 100
	Home.homeFrame(home, 0.01)
	ok(math.abs(ui.scroll - 14) < 0.001, "a frame of 0.01 s covers 14 x 0.01 of the gap: " .. tostring(ui.scroll)) -- Home.lua:1394
	Home.homeFrame(home, 1)
	eq(ui.scroll, 100, "a long frame lands exactly on the target")
	ui.scroll, ui.scrollTarget = 99.8, 100
	Home.homeFrame(home, 0.001)
	eq(ui.scroll, 100, "within half a pixel it snaps") -- Home.lua:1397
	local wheel = home.clip:GetScript("OnMouseWheel")
	ok(wheel, "the list takes the mouse wheel")
	ui.scrollMax, ui.scrollTarget = 200, 0
	wheel(home.clip, 1)
	eq(ui.scrollTarget, 0, "up at the top stays at the top") -- Home.lua:866
	wheel(home.clip, -1)
	eq(ui.scrollTarget, 64, "one notch down")
	wheel(home.clip, -1) wheel(home.clip, -1)
	eq(ui.scrollTarget, 192, "three notches")
	wheel(home.clip, -1)
	eq(ui.scrollTarget, 200, "never past the end of the list")
	wheel(home.clip, 1)
	eq(ui.scrollTarget, 136, "one notch back up")
	wheel(home.clip, nil)
	eq(ui.scrollTarget, 136, "no delta: no move")
	T.clean(w)
end)
