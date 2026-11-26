-- Final home: tests/ui/rider/confirm_test.lua; add it to the per-module list in tests/run.lua.
-- Pins: the booking card's words (headline, fare, crew line, Request pill, how-you-pay row, group full);
-- Pins: why the Request pill is blocked (paused driver, standing in the place, yourself, a driver who went offline) and that a click then sends nothing;
-- Pins: the group warning with its Leave group pill, and no warning when the rider is grouped with the driver;
-- Pins: the raincheck row (cover vs fare, nothing to pay, toggled off, a cover of 0 hides it);
-- Pins: "About this driver" lines (first ride, Nth ride, the usual-fare 100-copper boundary, crew line) and the "10th ride with Mia" line from the kept trips;
-- Pins: the Finding screen (waiting line, countdown clamped 0..limit, 120 s for a whisper-only request, leave-group line) and the rider-level chip;
-- Pins: the sheet's place folded (100..168) against unfolded (62), and the plain click on the pill when the secure button is not over it.
-- Why it matters to a player: this is the screen where the rider spends gold. If it broke, a rider would book a driver who is gone or
-- who is already where they stand, would not be told to leave their group, or would see the wrong fare or "nothing to pay" line.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local KEY = "mia runner"

-- a fresh rider who has settled, and Mia in the driver list (injected as the suite's other card tests do)
local function setup(opts, over)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, opts)
	w:advance(15)
	local d = { name = "Mia Runner", key = KEY, dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = r.env.GetTime(), queue = 0, ver = "2.3.0" }
	for k, v in pairs(over or {}) do d[k] = v end
	r.W.drivers = r.W.drivers or {}
	r.W.drivers[d.key] = d
	-- Mia must be a player in the fake world: a whisper to nobody is answered "No player named" and Net drops her from the list (Net/Rides.lua:130)
	w:addBot(d.name)
	return w, r, d
end

local function open(w, r, key)
	T.openConfirm(r, key or KEY) -- loads the UI first (needUI), then Show and the splash
	w:advance(1)
	return r.W.UI.state.screens.confirm
end

local function refresh(w, r)
	r.W.UI.RefreshNow()
	w:advance(0.5)
end

local function has(r, text) return #r:findText(text, nil, true) > 0 end

-- every toast the UI shows from now on
local function toasts(r)
	local said = {}
	local UI = r.W.UI
	local toast = UI.Toast
	UI.Toast = function(text, ...) said[#said + 1] = tostring(text) return toast(text, ...) end
	return said
end

local function toasted(said, text)
	for _, t in ipairs(said) do if t == text then return true end end
	return false
end

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("UI.Rider.Confirm", "tests/ui/rider/confirm_test.lua", {
		["Mod.buildConfirm"] = "function", ["Mod.buildFinding"] = "function", ["Mod.leaveGroup"] = "function", ["Mod.tierChip"] = "function",
		["Mod.againLine"] = "function", ["Mod.againChip"] = "function", ["Mod.aboutLines"] = "function", ["Mod.aboutBuild"] = "function",
		["Mod.foldedAbout"] = "function", ["Mod.wideBlocks"] = "function", ["Mod.widenDial"] = "function", ["Mod.sideUpdate"] = "function",
		["Mod.foldBuild"] = "function", ["Mod.foldLayout"] = "function", ["Mod.side"] = "table",
		["Mod.ROW_AGAIN"] = "number", ["Mod.DIAL_SHORT"] = "number", ["Mod.PVP_COMPACT"] = "number",
		["UI.TierChip"] = "function", ["UI.RaincheckCover"] = "function", -- the header's API line (RaincheckCover is defined in Pay.lua)
	})
	ok(Mod, "W.Mod(\"UI.Rider.Confirm\")")
	eq(Mod.ROW_AGAIN, 90, "the driver card with the again chip is 90 high") -- Confirm.lua:812
	eq(Mod.DIAL_SHORT, 62, "the short flight card") -- Confirm.lua:810
	eq(Mod.PVP_COMPACT, 50, "the compact PvP warning") -- Confirm.lua:811
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: the booking card says where, who, how much and what you pay", function()
	local w, r = setup()
	local s = open(w, r)
	ok(has(r, "Summon to Undercity"), "headline. Visible: " .. T.list(r:visibleTexts()):sub(1, 400)) -- Confirm.lua:513
	ok(has(r, "Mia's Rides"), "the driver's service name") -- Confirm.lua:470
	ok(has(r, "Undercity \194\183 Crew ready \194\183 Open"), "the grey line: place, crew, state (" .. T.list(r:visibleTexts()):sub(1, 500) .. ")") -- Confirm.lua:476
	ok(has(r, "Request summon \194\183 50s"), "the Request pill carries the fare") -- Confirm.lua:617
	ok(has(r, "Trade 50s after you arrive"), "how you pay: you type the gold after the summon") -- Confirm.lua:602
	ok(not has(r, "group full"), "a driver with free seats is not marked full")
	ok(s.request:IsShown(), "the pill is up")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: crew line counts the friends still needed; no seats says group full; busy says busy", function()
	local w, r, d = setup(nil, { team = 1 })
	open(w, r)
	ok(has(r, "Bring 2 friends"), "a crew of one needs two friends") -- Confirm.lua:471
	d.team = 2
	refresh(w, r)
	ok(has(r, "Bring 1 friend"), "a crew of two needs one friend, singular")
	ok(not has(r, "Bring 1 friends"), "no 'Bring 1 friends'")
	d.team = 0 -- malformed: clamped to a crew of one (Kit.lua:202)
	refresh(w, r)
	ok(has(r, "Bring 2 friends"), "a crew of zero reads as a crew of one")
	d.team, d.seats = 3, 0
	refresh(w, r)
	ok(has(r, "Trade 50s after you arrive \194\183 group full"), "no seats left is said on the pay row") -- Confirm.lua:607
	d.seats, d.state = nil, "busy"
	refresh(w, r)
	ok(has(r, "Request summon \194\183 50s (busy)"), "a busy driver can still be asked; the pill says busy") -- Confirm.lua:620
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: a paused driver blocks the pill, and a click sends nothing", function()
	local w, r = setup(nil, { state = "paused" })
	local s = open(w, r)
	local said = toasts(r)
	ok(has(r, "That driver has paused for now"), "the pill says why (" .. T.list(r:visibleTexts()):sub(1, 400) .. ")") -- Secure.lua:55, Confirm.lua:614
	s.request:GetScript("OnClick")(s.request)
	w:advance(1)
	eq(#T.msgs(w, "R", T.TESTCHAR), 0, "no request (R) was sent")
	eq(r.W.ride, nil, "no ride was started")
	ok(#said == 0, "an inactive pill is silent: " .. table.concat(said, " | ")) -- Confirm.lua:366
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: a driver whose place you already stand in is not bookable and the route is left off", function()
	local w, r = setup({ spot = "Orgrimmar" }, { dest = "Orgrimmar" })
	local s = open(w, r)
	ok(has(r, "You're already in Orgrimmar."), "the pill says you are there (" .. T.list(r:visibleTexts()):sub(1, 400) .. ")") -- Confirm.lua:611
	ok(not s.route:IsShown(), "no 'Orgrimmar > Orgrimmar' route header") -- Confirm.lua:521
	eq(s.map.routeDest, nil, "no route on the map, no portal pin") -- Confirm.lua:469
	s.request:GetScript("OnClick")(s.request)
	w:advance(1)
	eq(#T.msgs(w, "R", T.TESTCHAR), 0, "no request to a place you are in")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: you cannot book yourself", function()
	local w, r = setup(nil, { name = "Wuber TestCharacter", key = "wuber testcharacter", service = "Wuber's Rides" })
	local s = open(w, r, "wuber testcharacter")
	ok(has(r, "That's you!"), "the pill says so (" .. T.list(r:visibleTexts()):sub(1, 400) .. ")") -- Secure.lua:54
	s.request:GetScript("OnClick")(s.request)
	w:advance(1)
	eq(#T.msgs(w, "R", T.TESTCHAR), 0, "no request to yourself")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: a driver who goes offline while the card is open: the pill says so and sends nothing; reopened it says the driver went offline", function()
	local w, r = setup()
	local s = open(w, r)
	ok(has(r, "Request summon \194\183 50s"), "control: bookable")
	r.W.drivers[KEY] = nil
	refresh(w, r)
	ok(has(r, "That driver has gone offline"), "the pill says gone (" .. T.list(r:visibleTexts()):sub(1, 400) .. ")") -- Secure.lua:53, Confirm.lua:587
	s.request:GetScript("OnClick")(s.request)
	w:advance(1)
	eq(#T.msgs(w, "R", T.TESTCHAR), 0, "no request to a driver who has gone")
	r.W.UI.Show("home")
	w:advance(1)
	open(w, r)
	ok(has(r, "This driver went offline"), "reopened: the gone card") -- Confirm.lua:456
	ok(has(r, "Driver went offline"), "the pill says so") -- Confirm.lua:457
	ok(not has(r, "50s"), "the earlier driver's fare is gone from the card") -- Confirm.lua:460
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: in another group, the card says to leave it and Leave group takes you out", function()
	local w, r = setup()
	w:addBot("Sly Fox", { spot = "Orgrimmar" })
	w:group({ T.TESTCHAR, "Sly Fox" })
	w:advance(1)
	local said = toasts(r)
	open(w, r)
	ok(has(r, "You're in a group. Leave it so the driver can invite you."), "the warning (" .. T.list(r:visibleTexts()):sub(1, 500) .. ")") -- Confirm.lua:592
	ok(has(r, "Leave your group first"), "the pill is blocked with the group reason") -- Secure.lua:57
	ok(#r:findText("Leave group", nil, true) > 0, "the Leave group pill is up")
	r:clickText("Leave group")
	w:advance(2)
	ok(toasted(said, "You left your group"), "the toast (" .. table.concat(said, " | ") .. ")") -- Confirm.lua:84
	ok(not r.W.InGroup(), "the rider is out of the group")
	refresh(w, r)
	ok(not has(r, "You're in a group."), "the warning is gone")
	ok(has(r, "Request summon \194\183 50s"), "the pill is bookable again")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: grouped with the driver already: no warning, the pill is bookable", function()
	local w, r = setup()
	w:addBot("Mia Runner", { spot = "Orgrimmar" })
	w:group({ T.TESTCHAR, "Mia Runner" })
	w:advance(1)
	open(w, r)
	ok(not has(r, "You're in a group."), "no group warning when the group is the driver's") -- Confirm.lua:586 (inGroupWith)
	ok(has(r, "Request summon \194\183 50s"), "bookable (" .. T.list(r:visibleTexts()):sub(1, 400) .. ")")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: leaveGroup toasts by what the game allowed", function()
	local w, r = setup()
	local Mod = r.W.Mod("UI.Rider.Confirm")
	local said = toasts(r)
	r.W.LeaveGroup = function() return true end
	Mod.leaveGroup()
	r.W.LeaveGroup = function() return false end
	Mod.leaveGroup()
	r.W.LeaveGroup = function() return nil end
	Mod.leaveGroup()
	eq(said[1], "You left your group", "leave went through") -- Confirm.lua:84
	eq(said[2], "Leave your group from your portrait menu", "leave refused: say where to do it by hand")
	eq(said[3], "Leave your group from your portrait menu", "no answer counts as refused")
	w:advance(1)
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: a held raincheck shows what it covers and what is left to trade", function()
	local w, r = setup()
	local R = r.W.Raincheck
	ok(R, "W.Raincheck is loaded")
	R.ForDriver = function() return "rc1", 3000 end
	local s = open(w, r)
	ok(s.rc:IsShown(), "the raincheck row shows") -- Confirm.lua:576
	ok(not s.pay:IsShown(), "how-you-pay steps aside while it does") -- Confirm.lua:578
	ok(has(r, "Use raincheck (covers 30s)"), "the label names the cover") -- Confirm.lua:574
	ok(has(r, "Raincheck covers 30s \194\183 trade 20s after"), "the fare left to trade: 50s less 30s") -- Confirm.lua:604
	R.ForDriver = function() return "rc1", 8000 end
	refresh(w, r)
	ok(has(r, "Use raincheck (covers 80s)"), "a bigger cover")
	ok(has(r, "Raincheck covers 50s \194\183 nothing to pay"), "the cover is capped at the fare: nothing to pay") -- Confirm.lua:604
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: raincheck switched off asks for the whole fare; a cover of 0 or less shows no row", function()
	local w, r = setup()
	local R = r.W.Raincheck
	R.ForDriver = function() return "rc1", 3000 end
	local s = open(w, r)
	R.Use(false) -- what the row's toggle does (Confirm.lua:343)
	refresh(w, r)
	ok(s.rc:IsShown(), "the row stays, so it can be switched on again")
	ok(not has(r, "Raincheck covers"), "no cover is claimed while it is off")
	ok(has(r, "Trade 50s after you arrive"), "the whole fare is traded") -- Confirm.lua:602, 608
	R.Use(true)
	R.ForDriver = function() return "rc1", 0 end
	refresh(w, r)
	ok(not s.rc:IsShown(), "a zero cover shows no row") -- Confirm.lua:95
	ok(s.pay:IsShown(), "how you pay is back")
	R.ForDriver = function() return "rc1", -500 end
	refresh(w, r)
	ok(not s.rc:IsShown(), "a negative cover shows no row")
	R.ForDriver = function() return nil end
	refresh(w, r)
	ok(not s.rc:IsShown(), "no raincheck, no row")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: aboutLines - first ride, the usual-fare line needs 3 drivers and uses a 100 copper band, crew line", function()
	local w, r = setup()
	local W = r.W
	W.DriversSorted = nil -- the plain W.drivers path (Kit.lua:271), so the list is exactly the drivers set here
	local Mod = W.Mod("UI.Rider.Confirm")
	local d = W.UI.Driver(KEY)
	local short = d.short
	-- alone to Undercity: no fare line (fewer than 3 prices)
	local lines = Mod.aboutLines(d)
	eq(#lines, 2, "first ride and crew only")
	eq(lines[1], "Your first ride with " .. short, "first ride") -- Confirm.lua:860
	eq(lines[2], "Their crew clicks the portal", "a full crew") -- Confirm.lua:882
	-- three to Undercity: Mia is the median
	local t = r.env.GetTime()
	W.drivers["bea jones"] = { name = "Bea Jones", key = "bea jones", dest = "Undercity", price = 4000, state = "open", team = 3, service = "B", heard = t }
	W.drivers["cal brown"] = { name = "Cal Brown", key = "cal brown", dest = "Undercity", price = 6000, state = "open", team = 3, service = "C", heard = t }
	lines = Mod.aboutLines(W.UI.Driver(KEY))
	eq(lines[2], "The usual fare to Undercity (50s)", "the median fare is the usual") -- Confirm.lua:871-874
	eq(Mod.aboutLines(W.UI.Driver("bea jones"))[2], "10s under the usual 50s to Undercity", "cheaper: under") -- Confirm.lua:876
	eq(Mod.aboutLines(W.UI.Driver("cal brown"))[2], "10s over the usual 50s to Undercity", "dearer: over") -- Confirm.lua:878
	-- the boundary: 99 copper off the usual is the usual, 100 is not
	W.drivers["cal brown"].price = 5099
	eq(Mod.aboutLines(W.UI.Driver("cal brown"))[2], "The usual fare to Undercity (50s)", "99 copper over: still the usual") -- Confirm.lua:873 (< 100)
	W.drivers["cal brown"].price = 5100
	eq(Mod.aboutLines(W.UI.Driver("cal brown"))[2], "1s over the usual 50s to Undercity", "100 copper over: over") -- Confirm.lua:873, 878
	-- a crew of one
	W.drivers[KEY].team = 1
	lines = Mod.aboutLines(W.UI.Driver(KEY))
	eq(lines[#lines], "Bring friends to click the portal", "an incomplete crew: bring friends") -- Confirm.lua:882
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: againLine counts the kept trips with this driver (by key or by name); junk entries and nil are skipped", function()
	local w, r = setup()
	local W = r.W
	local Mod = W.Mod("UI.Rider.Confirm")
	local d = W.UI.Driver(KEY)
	W.db.rides = nil
	eq(Mod.againLine(d), nil, "no trips table: no line") -- Confirm.lua:840
	W.db.rides = { "junk", 7, {}, { driverKey = "somebody else" }, { driver = false } }
	eq(Mod.againLine(d), nil, "junk and other drivers' trips do not count")
	W.db.rides = { { driverKey = KEY, dest = "Undercity" } }
	eq(Mod.againLine(d), "2nd ride with " .. d.short, "one kept trip: this is the 2nd") -- Confirm.lua:852
	W.db.rides = { { driverKey = KEY }, { driver = "Mia Runner" }, { driver = "Mia Runner", driverKey = "x" } }
	eq(Mod.againLine(d), "4th ride with " .. d.short, "a trip is matched by key or by the name's key; each trip counts once") -- Confirm.lua:842
	local many = {}
	for i = 1, 11 do many[i] = { driverKey = KEY } end
	W.db.rides = many
	eq(Mod.againLine(d), "12th ride with " .. d.short, "11 trips: the 12th, not the 12st") -- Kit.lua ordinal: 11-13 take th
	eq(Mod.againLine(nil), nil, "no driver")
	eq(Mod.againLine({ name = "No Key" }), nil, "a driver without a key")
	eq(Mod.aboutLines(d)[1], "12th ride with " .. d.short, "the About card uses the same count") -- Confirm.lua:860
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: a returning rider's card says the Nth ride and the About card drops its own first line", function()
	local w, r = setup()
	r.W.db.rides = { { driverKey = KEY, dest = "Undercity" }, { driverKey = KEY, dest = "Undercity" } }
	open(w, r)
	local short = r.W.UI.Driver(KEY).short
	ok(has(r, "3rd ride with " .. short), "the card says the 3rd ride (" .. T.list(r:visibleTexts()):sub(1, 500) .. ")") -- Confirm.lua:482-483
	local n = 0
	for _, t in ipairs(r:visibleTexts()) do if t:find("ride with " .. short, 1, true) then n = n + 1 end end
	eq(n, 1, "said once: the About card leaves its first line out when the chip says it") -- Confirm.lua:939
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: folded the sheet sits at 100..168, unfolded at 62 with no grab handle", function()
	local w, r = setup()
	local s = open(w, r)
	ok(not s.wide, "control: folded")
	ok(s.cardTop >= 100 and s.cardTop <= 168, "folded sheet top: " .. tostring(s.cardTop)) -- Confirm.lua:124
	ok(s.card.grab:IsShown(), "the grab handle shows folded")
	T.clean(w)
	local w2 = T.newWorld()
	local r2 = T.rider(w2, T.TESTCHAR, { spot = "Orgrimmar" })
	r2.wide = true
	w2:advance(15)
	r2.W.drivers = r2.W.drivers or {}
	r2.W.drivers[KEY] = { name = "Mia Runner", key = KEY, dest = "Undercity", price = 5000, state = "open", team = 3, service = "Mia's Rides", heard = r2.env.GetTime() }
	r2.W.UI.Show("confirm", KEY)
	w2:advance(3)
	local s2 = r2.W.UI.state.screens.confirm
	ok(s2.wide, "control: unfolded")
	eq(s2.cardTop, 62, "unfolded: the sheet starts under the back and route row") -- Confirm.lua:115, 124
	ok(not s2.card.grab:IsShown(), "no grab handle unfolded") -- Confirm.lua:1122
	T.clean(w2)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: a plain click on the pill (secure button not over it) asks for one more click", function()
	local w, r = setup()
	local s = open(w, r)
	local said = toasts(r)
	s.request:GetScript("OnClick")(s.request)
	ok(toasted(said, "One moment - click Request again"), "the toast (" .. table.concat(said, " | ") .. ")") -- Confirm.lua:386
	eq(#T.msgs(w, "R", T.TESTCHAR), 0, "a click that did not land on the secure button sends nothing")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: in combat with a blocked pill a click says nothing and sends nothing", function()
	local w, r = setup(nil, { state = "paused" })
	local s = open(w, r)
	w:enterCombat(r)
	w:advance(1)
	local said = toasts(r)
	s.request:GetScript("OnClick")(s.request)
	w:advance(1)
	eq(#T.msgs(w, "R", T.TESTCHAR), 0, "nothing sent")
	eq(#said, 0, "no toast from an inactive pill")
	w:leaveCombat(r)
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: opening the card asks the driver for flight prices, with the driver's key", function()
	local w, r = setup()
	local asked = {}
	r.W.AskFlight = function(key) asked[#asked + 1] = key end
	open(w, r)
	ok(#asked >= 1, "asked on open") -- Confirm.lua:399
	for _, k in ipairs(asked) do eq(k, KEY, "always for this driver") end
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: finding screen - waiting line, countdown clamps to 0 and to the limit, a whisper-only request waits 120 s", function()
	local w, r = setup()
	local W = r.W
	local t = r.env.GetTime()
	W.ride = { id = "r9", driver = "Mia Runner", driverKey = KEY, dest = "Undercity", price = 5000, state = "requesting", at = t }
	W.Fire("RIDE")
	W.UI.Toggle(true)
	w:advance(3)
	W.UI.RefreshNow()
	local s = W.UI.state.screens.finding
	ok(has(r, "Finding your driver"), "the title (" .. T.list(r:visibleTexts()):sub(1, 400) .. ")") -- Confirm.lua:726
	ok(has(r, "Waiting for Mia to accept..."), "who it waits for") -- Confirm.lua:771
	ok(has(r, "Cancel request"), "the Cancel request pill") -- Confirm.lua:777
	local left = tonumber((s.left:GetText() or ""):match("^(%d+) s$"))
	ok(left and left > 0 and left <= 40, "a countdown of at most 40 s: " .. tostring(s.left:GetText())) -- Kit.lua:63, Confirm.lua:795
	-- long past the limit: the bar is at its floor and the text says 0 s
	W.ride.at = r.env.GetTime() - 100
	s.frameTick()
	eq(s.left:GetText(), "0 s", "past the limit: 0 s") -- Confirm.lua:793
	eq(s.fill:GetWidth(), 4, "the bar keeps its 4 px floor") -- Confirm.lua:794
	-- a request time in the future (clock skew): never more than the limit
	W.ride.at = r.env.GetTime() + 50
	s.frameTick()
	eq(s.left:GetText(), "40 s", "a future time is capped at the limit")
	eq(s.fill:GetWidth(), 260, "a full bar")
	-- no request time at all
	W.ride.at = nil
	s.frameTick()
	eq(s.left:GetText(), "40 s", "no time: the full limit")
	-- a request that goes by whisper waits 120 s
	W.ride.noAddon = true
	s.frameTick()
	eq(s.left:GetText(), "120 s", "whisper-only: 120 s (FAB-08)") -- Confirm.lua:791
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: finding screen tells a rider in another group to leave it, but not one grouped with the driver", function()
	local w, r = setup()
	local W = r.W
	w:addBot("Sly Fox", { spot = "Orgrimmar" })
	w:group({ T.TESTCHAR, "Sly Fox" })
	w:advance(1)
	W.ride = { id = "r9", driver = "Mia Runner", driverKey = KEY, dest = "Undercity", price = 5000, state = "requesting", at = r.env.GetTime() }
	W.Fire("RIDE")
	W.UI.Toggle(true)
	w:advance(3)
	W.UI.RefreshNow()
	ok(has(r, "You're in a group. Leave it so Mia can invite you."), "the line names the driver (" .. T.list(r:visibleTexts()):sub(1, 500) .. ")") -- Confirm.lua:776
	ok(#r:findText("Leave group", nil, true) > 0, "with the pill")
	T.clean(w)
	local w2, r2 = setup()
	w2:addBot("Mia Runner", { spot = "Orgrimmar" })
	w2:group({ T.TESTCHAR, "Mia Runner" })
	w2:advance(1)
	r2.W.ride = { id = "r9", driver = "Mia Runner", driverKey = KEY, dest = "Undercity", price = 5000, state = "requesting", at = r2.env.GetTime() }
	r2.W.Fire("RIDE")
	r2.W.UI.Toggle(true)
	w2:advance(3)
	r2.W.UI.RefreshNow()
	ok(not has(r2, "You're in a group."), "in the driver's own group: no warning") -- Confirm.lua:773 (inGroupWith)
	T.clean(w2)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: rider level chip - hidden below Bronze, clamped to the top level, hidden in Simple mode", function()
	local w, r = setup()
	local W = r.W
	local c = W.UI.TierChip(r.env.UIParent)
	c:SetPoint("CENTER", r.env.UIParent, "CENTER")
	W.TierName = function(t) return "Tier" .. t end
	W.Tier = function() return 0 end
	c:Update()
	ok(not c:IsShown(), "no rides yet: no chip") -- Confirm.lua:667
	W.Tier = function() return nil end
	c:Update()
	ok(not c:IsShown(), "no answer: no chip")
	W.Tier = function() return -4 end
	c:Update()
	ok(not c:IsShown(), "a negative level: no chip") -- Confirm.lua:666 (clamp 0..3)
	W.Tier = function() return 2.7 end
	c:Update()
	ok(c:IsShown(), "level 2 shows")
	ok(#r:findText("Tier2 rider", true, true) > 0, "the chip says '<name> rider' with the floor of the level") -- Confirm.lua:672
	W.Tier = function() return 9 end
	c:Update()
	ok(#r:findText("Tier3 rider", true, true) > 0, "above the top level: the top level") -- Confirm.lua:666
	T.clean(w)
	local w2 = T.newWorld()
	local r2 = T.rider(w2, T.TESTCHAR, { simple = true })
	w2:advance(15)
	local c2 = r2.W.UI.TierChip(r2.env.UIParent)
	r2.W.Tier = function() return 3 end
	c2:Update()
	ok(not c2:IsShown(), "Simple mode never shows the level chip") -- Confirm.lua:661
	T.clean(w2)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.rider.confirm: Simple mode - no dial and no About card on the booking card", function()
	local w, r = setup({ simple = true })
	local s = open(w, r)
	ok(not s.dial:IsShown(), "no Fly or summon dial in Simple mode") -- Confirm.lua:536 (adv false)
	local side = r.W.Mod("UI.Rider.Confirm").side
	ok(not (side.about and side.about:IsShown()), "no About this driver card") -- Confirm.lua:1038
	ok(has(r, "Request summon \194\183 50s"), "booking still works (" .. T.list(r:visibleTexts()):sub(1, 400) .. ")")
	T.clean(w)
end)
