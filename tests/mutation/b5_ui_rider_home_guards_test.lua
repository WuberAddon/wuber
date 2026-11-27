-- Mutation guard tests for Wuber/UI/Rider/Home.lua.
-- Each test guards one or more unprotected lines against player-visible promises.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function openHome(opts)
	opts = opts or {}
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	w:advance(15)
	local W = c.W
	local UI = W.UI
	W.db.coach = true
	if opts.withDriver then
		W.drivers["dan driver"] = {
			name = "Dan Driver",
			key = "dan driver",
			dest = "Gadgetzan",
			price = 5000,
			state = "open",
			team = 1,
			service = "Dan's Rides",
			heard = c.env.GetTime(),
		}
	end
	UI.Toggle(true)
	w:advance(2.5)
	local s = UI.state and UI.state.screens and UI.state.screens.home
	return w, c, W, UI, s
end

local function hoverBody(c, region)
	local enter = region:GetScript("OnEnter")
	if enter then enter(region) end
	local fs = c.env.GameTooltipTextLeft2
	local text = fs and fs:GetText()
	local leave = region:GetScript("OnLeave")
	if leave then leave(region) end
	return text
end

-- guards Wuber/UI/Rider/Home.lua:83 (cmp ==->~=: empty key from WatchKey/PlaceKey returned instead of lowercase fallback)
-- guards Wuber/UI/Rider/Home.lua:85 (swap and->or: lowercase fallback returns nil when place is set)
-- guards Wuber/UI/Rider/Home.lua:91 (local value -> nil: W.db.watch not read)
-- guards Wuber/UI/Rider/Home.lua:92 (cmp ~=->==: returns false when W.db.watch is a table)
-- guards Wuber/UI/Rider/Home.lua:93 (return -> nil: IsWatching returns nil instead of checking watch table)
-- guards Wuber/UI/Rider/Home.lua:104 (cmp ~=->==: W.db.watch not initialized when nil)
-- guards Wuber/UI/Rider/Home.lua:106 (drop statement: ToggleWatch fails to flip watch state)
-- guards Wuber/UI/Rider/Home.lua:107 (swap or->and: unwatching leaves key in W.db.watch)
-- guards Wuber/UI/Rider/Home.lua:108 (drop statement: SETTINGS watch event not fired)
test("mutation b5 ui rider home: watchKey, IsWatching and ToggleWatch fallback to W.db.watch", function()
	local w, c, W, UI = openHome()
	local origIsWatched = W.IsWatched
	local origToggleWatch = W.ToggleWatch
	local origWatchKey = W.WatchKey
	local origPlaceKey = W.PlaceKey
	W.IsWatched = nil
	W.ToggleWatch = nil
	W.WatchKey = nil
	W.PlaceKey = function(p) return "" end
	W.db.watch = nil

	local fired = 0
	W.Listen("SETTINGS", function(k) if k == "watch" then fired = fired + 1 end end)

	eq(UI.IsWatching("Stormwind"), false, "not watching before toggle")
	local on = UI.ToggleWatch("Stormwind")
	eq(on, true, "ToggleWatch turns watch on")
	eq(type(W.db.watch), "table", "W.db.watch initialized as table")
	eq(W.db.watch["stormwind"], true, "empty PlaceKey falls back to lowercase key")
	eq(UI.IsWatching("Stormwind"), true, "IsWatching sees watched place")
	eq(fired, 1, "SETTINGS watch fired on enable")

	-- Also verify WatchKey/PlaceKey non-empty string is honoured when present
	W.PlaceKey = function(p) return "custom_sw" end
	UI.ToggleWatch("Stormwind")
	eq(W.db.watch["custom_sw"], true, "non-empty PlaceKey is used")
	local off = UI.ToggleWatch("Stormwind")
	eq(off, false, "ToggleWatch turns watch off")
	eq(W.db.watch["custom_sw"], nil, "unwatching clears key from W.db.watch")
	eq(fired, 3, "SETTINGS watch fired on each toggle")

	W.IsWatched = origIsWatched
	W.ToggleWatch = origToggleWatch
	W.WatchKey = origWatchKey
	W.PlaceKey = origPlaceKey
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Home.lua:192 (return -> nil: Your usual tooltip body missing)
test("mutation b5 ui rider home: Your usual card tooltip shows its description", function()
	local w, c, W, UI, s = openHome()
	ok(s and s.usual, "usual card exists")
	s.usual:Show()
	local text = hoverBody(c, s.usual)
	ok(type(text) == "string" and text:find("frequent ride", 1, true) ~= nil, "usual tooltip describes one-click booking")
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Home.lua:209 (local value -> nil: raidAction loses W.Drive)
-- guards Wuber/UI/Rider/Home.lua:212 (if cond negated: queued state inverted on click)
-- guards Wuber/UI/Rider/Home.lua:213 (drop statement: RaidCancel not called when queued)
-- guards Wuber/UI/Rider/Home.lua:214 (drop statement: off summon list toast missing)
-- guards Wuber/UI/Rider/Home.lua:216 (swap or->and: RaidAsk error toast broken)
-- guards Wuber/UI/Rider/Home.lua:217 (drop statement: RaidAsk toast missing)
-- guards Wuber/UI/Rider/Home.lua:935 (drop statement: clicking main button in raid mode does nothing)
-- guards Wuber/UI/Rider/Home.lua:944 (return -> nil: main button raid tooltip body missing)
test("mutation b5 ui rider home: main button in raid mode asks, cancels, and shows tooltip", function()
	local w, c, W, UI, s = openHome()
	local DR = W.Drive
	local origHere = DR.RaidHere
	local origAsk = DR.RaidAsk
	local origCancel = DR.RaidCancel
	local queued = false
	local asked, cancelled = 0, 0
	local askOk, askWhy = true, nil
	local toasts = {}
	local origToast = UI.Toast
	UI.Toast = function(msg, kind)
		toasts[#toasts + 1] = { msg = msg, kind = kind }
		return origToast(msg, kind)
	end
	DR.RaidHere = function() return { runner = "Dan", queued = queued } end
	DR.RaidAsk = function() asked = asked + 1; return askOk, askWhy end
	DR.RaidCancel = function() cancelled = cancelled + 1; queued = false end

	UI.Refresh(true)
	w:advance(1)
	ok(H.visible(s.main) and s.main.mode == "raid", "main button is in raid mode")

	-- Tooltip in raid mode
	local body = hoverBody(c, s.main)
	ok(type(body) == "string" and body:find("summon list", 1, true) ~= nil, "raid main button tooltip explains summon list")

	-- Click to ask (success)
	c:clickOn(s.main)
	w:advance(1)
	eq(asked, 1, "clicking main button in raid mode calls RaidAsk")
	ok(toasts[#toasts] and toasts[#toasts].msg:find("Asked", 1, true) ~= nil, "success toast shown")

	-- Click to ask (failure)
	askOk, askWhy = false, "full"
	c:clickOn(s.main)
	w:advance(1)
	eq(asked, 2, "RaidAsk called again")
	eq(toasts[#toasts].msg, "full", "failure reason toasted")

	-- Click when queued -> cancel
	queued = true
	UI.Refresh(true)
	c:clickOn(s.main)
	w:advance(1)
	eq(cancelled, 1, "clicking main button when queued calls RaidCancel")
	ok(toasts[#toasts] and toasts[#toasts].msg:find("off the summon list", 1, true) ~= nil, "cancel toast shown")

	UI.Toast = origToast
	DR.RaidHere = origHere
	DR.RaidAsk = origAsk
	DR.RaidCancel = origCancel
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Home.lua:359 (local value -> nil: bounty pill x offset nil)
-- guards Wuber/UI/Rider/Home.lua:408 (return -> nil: Pin button tooltip missing)
test("mutation b5 ui rider home: bounty panel starts hidden, positions picks, and Pin tooltip describes bounty", function()
	local w, c, W, UI, s = openHome()
	local bb = s.empty and s.empty.bounty
	ok(bb, "empty.bounty exists")
	ok(not bb:IsShown(), "empty.bounty starts hidden")
	local _, _, _, x1 = bb.picks[1]:GetPoint(1)
	eq(x1, 0, "first bounty pick starts at x = 0")
	bb.place = "Gadgetzan"
	bb.copper = 5000
	bb:Show()
	local body = hoverBody(c, bb.pin)
	ok(type(body) == "string" and body:find("Gadgetzan", 1, true) ~= nil, "Pin tooltip names the destination")
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Home.lua:469 (cmp ==->~=: clicking own pill fails to open Drive tab)
-- guards Wuber/UI/Rider/Home.lua:482 (return -> nil: own pill/chip tooltip missing)
test("mutation b5 ui rider home: own driver pill opens Drive tab and shows tooltip", function()
	local w, c, W, UI, s = openHome()
	local switchedTo
	local origSelect = UI.SelectTab
	local origBeacon = W.DriverBeacon
	UI.SelectTab = function(tab) switchedTo = tab end
	W.DriverBeacon = function() return { dest = "Orgrimmar", price = 5000, state = "open", service = "Test Rides", team = 1 } end
	s.update()
	ok(H.visible(s.empty.own), "own pill is visible when open as driver with no other drivers")
	local body = hoverBody(c, s.empty.own)
	ok(type(body) == "string" and body:find("Drive tab", 1, true) ~= nil, "own pill tooltip mentions Drive tab")

	c:clickOn(s.empty.own)
	eq(switchedTo, "Drive", "clicking own pill switches to Drive tab")
	UI.SelectTab = origSelect
	W.DriverBeacon = origBeacon
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Home.lua:622 (drop statement: bountyGo icon not anchored)
-- guards Wuber/UI/Rider/Home.lua:633 (return -> nil: bountyGo tooltip missing)
test("mutation b5 ui rider home: empty watch and bountyGo pills anchor cleanly and bountyGo tooltip describes bounty", function()
	local w, c, W, UI, s = openHome()
	local lpt, lrel = s.empty.watch.label:GetPoint(1)
	eq(lpt, "LEFT", "watch label anchored LEFT")
	eq(lrel, s.empty.watch.icon, "watch label anchored to watch icon after ClearAllPoints")
	local pt, rel, relPt, x = s.empty.bountyGo.icon:GetPoint(1)
	eq(pt, "LEFT", "bountyGo icon anchored LEFT")
	eq(x, 18, "bountyGo icon offset 18")
	s.empty.bountyGo.place = "Winterspring"
	local body = hoverBody(c, s.empty.bountyGo)
	ok(type(body) == "string" and body:find("30 minutes", 1, true) ~= nil, "bountyGo tooltip mentions 30 minutes")
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Home.lua:643 (drop statement: SendChannel Q fallback not called)
-- guards Wuber/UI/Rider/Home.lua:644 (drop statement: SendChannel Q fallback not treated as ok)
-- guards Wuber/UI/Rider/Home.lua:652 (drop statement: offline ping toast missing)
-- guards Wuber/UI/Rider/Home.lua:654 (drop statement: cooldown pingAt adjustment missing)
-- guards Wuber/UI/Rider/Home.lua:655 (drop statement: cooldown toast missing)
-- guards Wuber/UI/Rider/Home.lua:657 (drop statement: generic ping failure toast missing)
test("mutation b5 ui rider home: Ping drivers button handles SendChannel fallback, offline, cooldown and error", function()
	local w, c, W, UI, s = openHome()
	local origPing = W.Ping
	local origSend = W.SendChannel
	local origToast = UI.Toast
	local toasts = {}
	UI.Toast = function(msg, kind)
		toasts[#toasts + 1] = { msg = msg, kind = kind }
		return origToast(msg, kind)
	end

	-- Fallback to SendChannel("Q") when W.Ping is absent
	local sent = {}
	W.Ping = nil
	W.SendChannel = function(msg) sent[#sent + 1] = msg end
	s.empty:Show()
	s.empty.ping:Show()
	s.empty.ping:SetActive(true)
	c:clickOn(s.empty.ping)
	eq(sent[1], "Q", "SendChannel('Q') called when W.Ping is absent")
	ok(toasts[#toasts].msg:find("Asked every driver", 1, true) ~= nil, "fallback ping treated as ok")

	-- Offline
	W.Ping = function() return false, "offline" end
	c:clickOn(s.empty.ping)
	ok(toasts[#toasts].msg:find("Can't reach the network", 1, true) ~= nil, "offline toast shown")

	-- Cooldown number
	UI.state.pingAt = nil
	W.Ping = function() return false, "5" end
	c:clickOn(s.empty.ping)
	ok(toasts[#toasts].msg:find("5 s", 1, true) ~= nil, "cooldown toast shown")
	ok(UI.state.pingAt ~= nil, "pingAt updated from cooldown")

	-- Generic failure
	W.Ping = function() return false, "busy" end
	c:clickOn(s.empty.ping)
	ok(toasts[#toasts].msg:find("Can't ping right now", 1, true) ~= nil, "generic ping failure toast shown")

	W.Ping = origPing
	W.SendChannel = origSend
	UI.Toast = origToast
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Home.lua:750 (return -> nil: place chip tooltip body missing)
test("mutation b5 ui rider home: place chip tag does not intercept mouse and chip tooltip names destination", function()
	local w, c, W, UI, s = openHome({ withDriver = true })
	UI.Refresh(true)
	w:advance(1)
	local chip = s.chips and s.chips.list and s.chips.list[2]
	ok(chip and chip.place == "Gadgetzan", "place chip for Gadgetzan built")
	eq(chip.tag:IsMouseEnabled(), false, "chip tag does not intercept mouse clicks")
	local body = hoverBody(c, chip)
	ok(type(body) == "string" and body:find("Gadgetzan", 1, true) ~= nil, "chip tooltip names destination")
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Home.lua:874 (swap or->and: mousewheel scroll delta ignored)
-- guards Wuber/UI/Rider/Home.lua:875 (drop statement: mousewheel scrollTarget not clamped)
test("mutation b5 ui rider home: mousewheel scrolls and clamps scrollTarget", function()
	local w, c, W, UI, s = openHome()
	UI.state.scrollMax = 100
	UI.state.scrollTarget = 0
	local wheel = s.clip:GetScript("OnMouseWheel")
	ok(type(wheel) == "function", "clip has OnMouseWheel")
	wheel(s.clip, -1)
	eq(UI.state.scrollTarget, 64, "scrolling down advances scrollTarget by 64")
	wheel(s.clip, -5)
	eq(UI.state.scrollTarget, 100, "scrollTarget clamped to scrollMax")
	wheel(s.clip, 5)
	eq(UI.state.scrollTarget, 0, "scrollTarget clamped to 0")
	T.clean(w)
end)

-- guards Wuber/UI/Rider/Home.lua:903 (cmp ==->~=: clicking OpenMap hint does not open help)
-- guards Wuber/UI/Rider/Home.lua:932 (drop statement: s.main Ride again button not created)
test("mutation b5 ui rider home: OpenMap hint opens help and main Ride again button exists", function()
	local w, c, W, UI, s = openHome({ withDriver = true })
	ok(s.main ~= nil, "s.main Ride again button is created")
	local opened
	local origHelp = UI.OpenHelp
	UI.OpenHelp = function(page) opened = page end
	UI.Refresh(true)
	w:advance(1)
	ok(H.visible(s.mapHint), "OpenMap hint row is visible")
	c:clickOn(s.mapHint)
	eq(opened, "home", "clicking OpenMap hint opens home help")
	UI.OpenHelp = origHelp
	T.clean(w)
end)
