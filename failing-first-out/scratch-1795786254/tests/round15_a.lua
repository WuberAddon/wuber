-- BRIEF15, agent A: Pioneer badges (FIXROUND-2.3.0 "LATER: 2.3.1" items 1 and 2) on every surface,
-- with the tests' own fake lists (W.PIONEERS ships empty, put back after each test): the queue row,
-- its tooltip and menu header, raid rows; driver cards, Confirm, the map pins' tooltips, the driver's
-- own console header, the rider's own Trips card; the nameplate variant and its tooltip line; the
-- credits in Settings. With the shipped (empty) lists nothing is made or shown; a network field or
-- saved data claiming Pioneer gives nothing; the founder's look wins.
local T = ...
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list
local S = H.state
local ANITA, TESTCHAR, BOB = T.ANITA, T.TESTCHAR, T.BOB

local RIDER_TIP = "Pioneer: one of Wuber's first riders"
local DRIVER_TIP = "Pioneer Driver: one of Wuber's first drivers"
local DAN, EVE, FARRA = "Dan Rider", "Eve Night", "Farra Way"

-- this client's fake lists (EU-PvE, the harness's ruleset); returns the restorer
local function fake(c, riders, drivers)
	local W = c.W
	local shipped = W.PIONEERS
	W.PIONEERS = { riders = { ["EU-PvE"] = riders or {} }, drivers = { ["EU-PvE"] = drivers or {} } }
	return function() W.PIONEERS = shipped end
end

local function shown(f) return f ~= nil and H.visible(f) end

-- a world map / OpenMap pin's tooltip lines (UI.Map.Pins' Tooltip, the pin not placed)
local function pinTip(c, key, creator)
	local Pins = c.W.Mod("UI.Map.Pins")
	local pin = Pins.NewPin(c.env.UIParent)
	pin.key, pin.creator = key, creator
	local gt = c.env.GameTooltip
	S[gt].tipLines = {}
	Pins.Tooltip(pin)
	local out = {}
	for _, l in ipairs(S[gt].tipLines or {}) do out[#out + 1] = type(l) == "table" and tostring(l.text or l[1]) or tostring(l) end
	return table.concat(out, "\n")
end

local function tipOf(c, f)
	local gt = c.env.GameTooltip
	S[gt].tipLines = {}
	local fn = S[f].scripts and S[f].scripts.OnEnter
	ok(fn, "the frame has a tooltip")
	fn(f)
	local out = {}
	for _, l in ipairs(S[gt].tipLines or {}) do out[#out + 1] = type(l) == "table" and tostring(l.text or l[1]) or tostring(l) end
	return table.concat(out, "\n")
end

-- a driver (Bob) with the console open and a stubbed queue (as tests/ui/driver/customers_test.lua)
local function console(queue, before)
	local w = T.newWorld({ realm = T.H.FOUNDER_REALM })
	local a = T.driver(w, BOB, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	if before then before(a) end
	DR.Sorted = function() return queue end
	DR.customers = {}
	for _, c in ipairs(queue) do DR.customers[c.key] = c end
	DR.IsOpen = function() return true end
	T.openDrive(a)
	if W.UI and W.UI.ShowDrive then W.UI.ShowDrive("console") end
	w:advance(2)
	W.Driver.RefreshNow()
	w:advance(1)
	return w, a, W
end

local function rider(name, o)
	local c = { name = name, key = name:lower(), state = "lead", source = "whisper", at = 0, price = 5000, paid = 0 }
	for k, v in pairs(o or {}) do c[k] = v end
	return c
end

local function rowOf(W, name)
	for _, r in ipairs(W.Driver.ui.console.rows or {}) do
		if r.c and r.c.name == name and r:IsShown() then return r end
	end
end

test("r15 a: the shipped Pioneer lists are empty - no badge, line or credit anywhere, nothing made", function()
	local W0 = nil
	local w, a, W = console({ rider(DAN), rider(FARRA) })
	W0 = W
	for rs, names in pairs(W.PIONEERS.riders) do eq(#names, 0, "riders " .. rs) end
	for rs, names in pairs(W.PIONEERS.drivers) do eq(#names, 0, "drivers " .. rs) end
	for _, r in ipairs(W.Driver.ui.console.rows or {}) do eq(r.pioneer, nil, "no badge made on a row") end
	eq(W.Driver.ui.console.status.pioneer, nil, "no badge in the console header")
	ok(not W.Driver.RowTip(rider(DAN)):find("Pioneer", 1, true), "no line in the row tip")
	ok(not W.Driver.RaidTip({ name = DAN, state = "asked" }):find("Pioneer", 1, true), "nor the raid tip")
	ok(not table.concat(a:visibleTexts(), " "):find("Pioneer", 1, true), "no Pioneer text on screen")
	T.clean(w)
	-- a rider: cards, Trips, Settings
	local w2 = T.newWorld()
	local d = T.driver(w2, BOB, { netOnly = true })
	local r = T.rider(w2)
	T.settle(w2)
	T.goOnline(d)
	r.W.db.coach = true
	r.W.UI.Toggle(true)
	w2:advance(3)
	local card = r.W.UI.state.cards["bob stone"]
	ok(card, "Bob's card")
	eq(card.pioneer, nil, "no badge on the card")
	r.W.UI.Show("trips")
	w2:advance(2)
	eq(r.W.UI.trips.level.pioneer, nil, "no badge on Trips")
	r.W.UI.OpenSettings("window")
	w2:advance(1)
	eq(r.W.UI.settings.credits, nil, "no credits made")
	ok(not table.concat(r:visibleTexts(), " "):find("Thanks to our first", 1, true), "no credits shown")
	ok(not table.concat(r:visibleTexts(), " "):find("Pioneer", 1, true), "no Pioneer text on screen")
	eq(r.W.Theme.PioneerLook(BOB), nil)
	T.clean(w2)
end)

test("r15 a: driver side - a Pioneer rider's queue row has the badge, its tooltip and menu header say so; raid rows too; a founder gets none", function()
	local dan, eve, farra = rider(DAN), rider(EVE), rider(FARRA)
	local restore
	local w, a, W = console({ dan, eve, farra }, function(c) restore = fake(c, { DAN, FARRA }) end)
	local D = W.Driver
	local rd, re, rf = rowOf(W, DAN), rowOf(W, EVE), rowOf(W, FARRA)
	ok(rd and re and rf, "three rows")
	ok(shown(rd.pioneer), "Dan's row: the badge")
	eq(rd.pioneer.kind, "rider", "the rider look")
	eq(rd.pioneer.tipText, RIDER_TIP, "its tooltip")
	ok(not (re.pioneer and re.pioneer:IsShown()), "Eve: none")
	ok(not (rf.pioneer and rf.pioneer:IsShown()), "Farra (a founder) on the list: the founder look wins, no badge")
	ok(not S[rd.pioneer].mouse, "the badge takes no clicks from the row")
	ok(D.RowTip(dan):find(RIDER_TIP, 1, true), "the row tip: " .. D.RowTip(dan))
	ok(tipOf(a, rd):find(RIDER_TIP, 1, true), "hovering the row")
	ok(not D.RowTip(eve):find("Pioneer", 1, true), "not in Eve's")
	ok(not D.RowTip(farra):find("Pioneer", 1, true), "not in a founder's")
	-- the menu's header
	ok(D.OpenMenu(dan), "menu")
	w:advance(1)
	local sh = D.ui.sheets.menu
	ok(sh.frame.sub:GetText():find("^Pioneer"), "the menu header: " .. tostring(sh.frame.sub:GetText()))
	D.OpenMenu(eve)
	w:advance(1)
	ok(not tostring(sh.frame.sub:GetText()):find("Pioneer", 1, true), "Eve's header: " .. tostring(sh.frame.sub:GetText()))
	-- a raid row and its tip
	local r = D.Row(a.env.UIParent, 320)
	D.PaintRaidRow(r, { name = DAN, state = "asked", asked = 0 })
	ok(shown(r.pioneer), "the raid row's badge")
	ok(D.RaidTip({ name = DAN, state = "asked" }):find(RIDER_TIP, 1, true), "the raid tip")
	D.PaintRaidRow(r, { name = EVE, state = "asked", asked = 0 })
	ok(not r.pioneer:IsShown(), "repainted for Eve: hidden")
	restore()
	D.PaintRow(rd, dan)
	ok(not rd.pioneer:IsShown(), "the lists back to empty: hidden")
	T.clean(w)
end)

test("r15 a: the driver's own console header shows his Pioneer Driver badge (with its tooltip); the status still lays out", function()
	local restore
	local w, a, W = console({ rider(DAN) }, function(c) restore = fake(c, {}, { BOB }) end)
	local s = W.Driver.ui.console.status
	ok(shown(s.pioneer), "the badge in the header")
	eq(s.pioneer.kind, "driver")
	ok(S[s.pioneer].mouse, "it has its own tooltip")
	ok(tipOf(a, s.pioneer):find(DRIVER_TIP, 1, true), "the tooltip")
	eq(s.pioneerShift, 20, "the dot moved right of it")
	ok(H.visible(s.word), "the status word still shows")
	restore()
	W.Driver.RefreshNow()
	w:advance(1)
	ok(not s.pioneer:IsShown(), "lists empty: gone")
	eq(s.pioneerShift, 0, "the dot back")
	T.clean(w)
end)

-- a rider (Wuber) with Bob driving (Net-only), the app open on Home; lists set before the window opens
local function riderWorld(riders, drivers, spot)
	local w = T.newWorld({ realm = T.H.FOUNDER_REALM })
	local d = T.driver(w, BOB, { netOnly = true })
	local r = T.rider(w, TESTCHAR, { spot = spot })
	local restore = fake(r, riders, drivers)
	T.settle(w)
	T.goOnline(d)
	r.W.db.coach = true
	r.W.UI.Toggle(true)
	w:advance(3)
	return w, r, restore
end

test("r15 a: rider side - a Pioneer Driver's card, Confirm and both map pins' tooltips; the rider's own Trips card", function()
	local w, r, restore = riderWorld({ TESTCHAR }, { BOB }, "Crossroads") -- (on Bob's map: his pin on the panel)
	local UI = r.W.UI
	local card = UI.state.cards["bob stone"]
	-- (design 2) no emblem after the name: the Pioneer line is in the row's tooltip
	ok(card and not (card.pioneer and card.pioneer:IsShown()), "no Pioneer emblem on the row")
	ok(tipOf(r, card):find(DRIVER_TIP, 1, true), "the card's tooltip: " .. tipOf(r, card))
	-- Confirm
	UI.Show("confirm", "bob stone")
	w:advance(2)
	local s = UI.state.screens.confirm
	local cc = s and s.card
	ok(cc and shown(cc.pioneer), "Confirm: the badge by the avatar")
	ok(tipOf(r, cc.pioneer):find(DRIVER_TIP, 1, true), "Confirm: its tooltip")
	-- the app's map pins (Home / Confirm map panel)
	local hit
	r.W.Mod("UI.Rider.HomeMap").updateMap(s.map, UI.Drivers()) -- (folded, Confirm's panel draws only when shown)
	for _, p in ipairs((s.map and s.map.pins) or {}) do if p.key == "bob stone" then hit = p end end
	ok(hit, "Bob's pin on Confirm's map panel")
	ok(tipOf(r, hit):find(DRIVER_TIP, 1, true), "the panel pin's tooltip")
	-- the world map / OpenMap pin's tooltip
	local pt = pinTip(r, "bob stone")
	ok(pt:find(DRIVER_TIP, 1, true), "the world map pin's tooltip: " .. pt)
	-- Trips: my own card
	UI.Show("trips")
	w:advance(2)
	local lv = UI.trips.level
	ok(shown(lv.pioneer), "Trips: my Pioneer badge")
	eq(lv.pioneer.kind, "rider")
	ok(tipOf(r, lv.pioneer):find(RIDER_TIP, 1, true), "its tooltip")
	restore()
	T.clean(w)
end)

-- the colour (r, g, b) of the line holding text in a client's GameTooltip
local function tipColour(c, text)
	local s = S[c.env.GameTooltip]
	for i, l in ipairs(s.tipLines or {}) do
		if tostring(l):find(text, 1, true) then
			local m = (s.tipMeta or {})[i] or {}
			return m[1], m[2], m[3]
		end
	end
end

test("r15 a: the world map pin's Pioneer line has the theme's Pioneer colour (driver and rider)", function()
	local w, r, restore = riderWorld({}, { BOB })
	local Th = r.W.Theme
	local pt = pinTip(r, "bob stone")
	ok(pt:find(DRIVER_TIP, 1, true), "the driver line: " .. pt)
	local er, eg, eb = Th.RGB(Th.PIONEER.driver.colour)
	local cr, cg, cb = tipColour(r, DRIVER_TIP)
	eq(cr, er, "driver line red")
	eq(cg, eg, "driver line green")
	eq(cb, eb, "driver line blue")
	restore()
	restore = fake(r, { BOB }, {})
	pt = pinTip(r, "bob stone")
	ok(pt:find(RIDER_TIP, 1, true), "the rider line: " .. pt)
	er, eg, eb = Th.RGB(Th.PIONEER.rider.colour)
	cr, cg, cb = tipColour(r, RIDER_TIP)
	eq(cr, er, "rider line red")
	eq(cg, eg, "rider line green")
	eq(cb, eb, "rider line blue")
	restore()
	T.clean(w)
end)

test("r15 a: the founder's look wins - a founder on the lists gets the crown and no Pioneer badge or line", function()
	local w = T.newWorld({ realm = T.H.FOUNDER_REALM })
	local d = T.driver(w, ANITA, { netOnly = true })
	local r = T.rider(w)
	local restore = fake(r, { ANITA }, { ANITA })
	T.settle(w)
	T.goOnline(d)
	r.W.db.coach = true
	r.W.UI.Toggle(true)
	w:advance(3)
	local card = r.W.UI.state.cards["anita lift"]
	ok(card, "Anita's card")
	ok(not (card.pioneer and card.pioneer:IsShown()), "no Pioneer badge on a founder's card")
	-- (design 2) the crown after the name is gone: the Founder badge and the tooltip say it
	ok(not (card.crown and card.crown:IsShown()), "no crown after the name")
	ok(card.royal and card.royal.chip and card.royal.chip:IsShown(), "the Founder badge")
	ok(tipOf(r, card):find("A Wuber founder. Wuber was made by this driver's team.", 1, true), "the crown's words are in the tooltip")
	ok(not tipOf(r, card):find("Pioneer", 1, true), "no Pioneer line")
	local t = pinTip(r, "anita lift", true)
	ok(t:find("Wuber founder", 1, true) and not t:find("Pioneer", 1, true), "map pin: founder only: " .. t)
	restore()
	T.clean(w)
end)

test("r15 a: nameplates - the Pioneer variant over a listed player (no mouse), its tooltip line; the founder keeps the crown", function()
	local w = T.newWorld({ realm = T.H.FOUNDER_REALM })
	w:addBot(ANITA, { spot = "Orgrimmar" })
	w:addBot(DAN, { spot = "Orgrimmar" })
	w:addBot("Zed Ox", { spot = "Orgrimmar" })
	local r = T.rider(w)
	r.cvars.nameplateShowFriends = "1"
	local restore = fake(r, { DAN, ANITA }, {})
	T.settle(w)
	r:showPlate(DAN)
	r:showPlate(ANITA)
	r:showPlate("Zed Ox")
	w:advance(2.5)
	-- (merged with agent B) FX.Emblem's emblem floats above the badge: set it aside, the badge is the one frame
	local on, em = {}, nil
	for _, f in ipairs(r:onPlate(DAN)) do
		if f.orb and f.halo and f.ring then em = f else on[#on + 1] = f end
	end
	ok(em, "the emblem over Dan too (FX.Emblem)")
	eq(#on, 1, "one badge frame over Dan")
	eq(on[1].plateKind, "pioneer", "the Pioneer variant")
	eq(on[1].kind, "rider")
	ok(not S[on[1]].mouse, "no mouse")
	eq(#S[on[1]].points, 1, "one anchor")
	eq(#r:onPlate("Zed Ox"), 0, "nothing over others")
	local an = r:onPlate(ANITA)
	eq(#an, 1) eq(an[1].plateKind, "crown", "the founder keeps the crown")
	local function has(lines, pat) for _, l in ipairs(lines) do if l:find(pat, 1, true) then return l end end end
	ok(has(r:hover(DAN), RIDER_TIP), "Dan's tooltip line: " .. list(r:hover(DAN)))
	eq(has(r:hover("Zed Ox"), "Pioneer"), nil, "none for others")
	eq(has(r:hover(ANITA), "Pioneer"), nil, "the founder: no Pioneer line")
	-- the lists emptied: the sweep drops the frame
	restore()
	w:advance(2.5)
	eq(#r:onPlate(DAN), 0, "dropped once the lists are empty")
	T.clean(w)
end)

test("r15 a: Settings > About credits - short sorted names under 'Thanks to our first riders and drivers', hidden while the lists are empty", function()
	local w, r, restore = riderWorld({ "Mia Lift-CAMWOW EU5 Realm 5", TESTCHAR }, { BOB, "Cal Brown" })
	r.W.UI.OpenSettings("window")
	w:advance(1)
	local st = r.W.UI.settings
	ok(st.credits and H.visible(st.credits), "the credits show")
	local t = st.credits:GetText()
	ok(t:find("Thanks to our first riders and drivers", 1, true), "the heading: " .. t)
	ok(t:find("Drivers: Bob, Cal", 1, true), "the drivers, short, sorted: " .. t)
	ok(t:find("Riders: Mia, Wuber", 1, true), "the riders: " .. t)
	restore()
	r.W.UI.LayoutSettings()
	ok(not st.credits:IsShown(), "lists empty: hidden entirely")
	T.clean(w)
end)

test("r15 a: unforgeable - a beacon, a saved field or a service name claiming Pioneer gives no badge anywhere", function()
	local saved = { Wuber = { pioneer = true, pioneers = { ["bob stone"] = "driver" },
		PIONEERS = { riders = { ["EU-PvE"] = { TESTCHAR } }, drivers = { ["EU-PvE"] = { "Bob Stone" } } } } }
	local w = T.newWorld()
	local d = T.driver(w, BOB, { netOnly = true })
	local r = T.rider(w, TESTCHAR, { saved = saved })
	T.settle(w)
	T.goOnline(d)
	-- another driver's beacon with every extra field saying pioneer
	w:inject(T.CAL, "D~1~Ratchet~1413~500~500~5000~Pioneer Driver~open~1~0~~2.3.0~pioneer~P~driver~1~~P~1", "CHANNEL")
	w:advance(1)
	r.W.db.coach = true
	r.W.UI.Toggle(true)
	w:advance(3)
	for key, c in pairs(r.W.UI.state.cards) do ok(not (c.pioneer and c.pioneer:IsShown()), "no badge on " .. key .. "'s card") end
	eq(r.W.PioneerKind(BOB), nil) eq(r.W.PioneerKind(T.CAL), nil) eq(r.W.PioneerKind(TESTCHAR), nil)
	r.W.UI.Show("trips")
	w:advance(2)
	eq(r.W.UI.trips.level.pioneer, nil, "no badge on Trips")
	r.W.UI.OpenSettings("window")
	w:advance(1)
	eq(r.W.UI.settings.credits, nil, "no credits")
	T.clean(w)
end)
