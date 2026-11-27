-- Wuber 2.1 (round five, SPEC4.md) tests: C (UI)'s part. Loaded by run.lua with the same
-- helpers as round four (T.H, T.test, T.eq, T.ok, T.newWorld, ...). Test names start "r5 ui:".
--
-- The engine's own behaviour (routing, claims, payees) is A's and B's tests; here the screens
-- are driven by the engine's answers. Where a scenario needs engine state the engine does not
-- build by itself in a few seconds (a raid queue, stations), the DR.* answer is set on that
-- window (the interface of SPEC4 5.1) and the screens are checked against it.

local T = ...
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list
local newWorld, clean = T.newWorld, T.clean

local MIA, BEA, DAN, GUS = "Mia Runner", "Bea Jones", "Dan Rider", "Gus Hill"

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function texts(c) return list(c:visibleTexts(), " | ") end

local function has(c, pattern, plain)
	return #c:findText(pattern, false, plain) > 0
end

-- (design 2) the tab bar is at the bottom of the window, so the end of a long page lies under it until the player
-- scrolls: brings a region of a T.Scroll list well inside the list's view (the wheel does the same in the game),
-- clear of a toast that may lie over the view's last line
local function scrollTo(sc, region, bar)
	local view, r = H.rect(sc), H.rect(region)
	local scale = view.w / sc:GetWidth()
	-- the tab bar lies over the foot of the scroll frame: what is under it cannot be seen or clicked
	local floorB = view.b
	if bar then local br = H.rect(bar) if br and br.b + br.h > floorB then floorB = br.b + br.h end end
	-- and a toast may lie over the view's last 60: a region that low is brought up as well
	if bar then floorB = floorB + 60 end
	if r.b < floorB then sc:ScrollTo((sc.offset or 0) + (floorB - r.b) / scale + 10, true) end
end

-- opens the window on the Drive tab
local function openTab(c, tab)
	c.W.db.coach = true
	c.W.UI.Toggle(true)
	c.world:advance(2.5)
	c:clickText(tab or "Drive")
	c.world:advance(1)
end

test("r5 ui: the file loads", function()
	ok(H ~= nil, "the harness")
	eq(type(T.newWorld), "function")
end)

---------------------------------------------------------------------------
-- Scenario 7: the rider app
---------------------------------------------------------------------------

-- a rider whose ride is at `state`, driven by Mia (a Mage runner) and summoned by Bea
local function riderWithRide(state, extra)
	local w = newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local ride = { id = "r5", driver = MIA, driverKey = key(MIA), dest = "Undercity", price = 5000, state = state,
		at = r.env.GetTime(), payee = BEA, payto = "Bea", summoner = BEA, service = "Mia's Rides" }
	for k, v in pairs(extra or {}) do ride[k] = v end
	r.W.ride = ride
	r.W.Fire("RIDE")
	return w, r
end

test("r5 ui: scenario 7: the rider is told to pay Bea (the summoner), on the Found screen and the trade strip", function()
	local w, r = riderWithRide("arrived")
	r.W.UI.Show("found")
	w:advance(3)
	ok(has(r, "Pay Bea", true), "Found screen says Pay Bea (" .. texts(r) .. ")")
	ok(has(r, "Summoned by Bea", true), "the driver card says Summoned by Bea (" .. texts(r) .. ")")
	ok(not has(r, "Trade Mia", true), "not 'Trade Mia'")
	-- the trade opens: the gold strip under it names the payee and says what to type
	r.W.ride.state = "paying"
	H.state[r.env.TradeFrame].shown = true
	r.W.tradeOpen = true
	r.W.Fire("RIDE")
	r:fire("TRADE_SHOW")
	w:advance(1)
	ok(has(r, "Pay Bea", true), "pay strip: " .. texts(r))
	local strip = r:findText("^Wuber: Pay Bea")
	ok(#strip > 0, "the strip under the trade window: " .. texts(r))
	ok(not has(r, "one click"), "never a one-click payment claim")
	clean(w)
end)

test("r5 ui: scenario 7: the Done screen says who was paid", function()
	local w, r = riderWithRide("done", { paid = true })
	r.W.UI.Show("done")
	w:advance(3)
	ok(has(r, "Paid 50s to Bea", true), "done: " .. texts(r))
	clean(w)
end)

test("r5 ui: scenario 7: the driver card on Home says who summons (the beacon's summoner)", function()
	local w = newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	r.W.drivers = r.W.drivers or {}
	r.W.drivers[key(MIA)] = { name = MIA, key = key(MIA), dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", summoner = BEA, heard = r.env.GetTime() }
	r.W.UI.Show("home")
	w:advance(3)
	ok(has(r, "Summoned by Bea", true), "home card: " .. texts(r))
	clean(w)
end)

test("r5 ui: scenario 7: the Ride tab shows Request a summon while my raid runs raid summons", function()
	local w = newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	r.W.db.coach = true -- the first-open tips are over, as for a returning player
	local DR = r.W.Drive
	local asked = 0
	local here = nil
	DR.RaidHere = function() return here end
	DR.RaidAsk = function() asked = asked + 1 here.queued, here.position = true, 2 return true end
	DR.RaidCancel = function() here.queued = false end
	r.W.UI.Show("home")
	w:advance(3)
	ok(not has(r, "Request a summon", true), "no raid: no button")
	here = { runner = "Dru Lead", summoners = { BEA }, place = "Orgrimmar" }
	r.W.Fire("DRIVE_RAID")
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(has(r, "Request a summon", true), "the button: " .. texts(r))
	-- asking is the screen's one main button at the foot (the raid card has no gold button of its own)
	r:click(r:clickable(r:findText("Request a summon", false, true)[1]))
	w:advance(1)
	eq(asked, 1, "DR.RaidAsk once")
	ok(has(r, "You're on the summon list", true) and has(r, "2nd in line", true), "queued: " .. texts(r))
	r:clickText("Cancel request")
	w:advance(1)
	eq(here.queued, false, "cancelled")
	clean(w)
end)

---------------------------------------------------------------------------
-- Scenario 3 (UI): a non-Warlock runner with no summoner
---------------------------------------------------------------------------

test("r5 ui: scenario 3: a Mage runs the service: welcome, wizard (Just me off), Readiness red, not open", function()
	local w = newWorld()
	local m = T.rider(w, MIA, { class = "MAGE" })
	w:advance(15)
	openTab(m)
	ok(has(m, "Run a summoning service", true), "welcome: " .. texts(m))
	ok(not has(m, "Only Warlocks", true), "no 'Only Warlocks can drive'")
	m:clickText("Set up driving")
	w:advance(1)
	local wz = m.W.UI.drive.wizard
	ok(wz and wz.step == 1, "wizard step 1")
	ok(has(m, "A Warlock friend", true) and has(m, "My other account", true), "non-Warlock choices (word rule): " .. texts(m))
	m:clickOn(wz.choices[1]) -- Just me: off
	w:advance(0.5)
	eq(wz.choice, nil, "Just me can't be picked")
	m:clickText("A Warlock friend")
	m:clickOn(wz.next)
	w:advance(1)
	eq(wz.step, 2, "pick your crew")
	m:clickOn(wz.skip) -- Skip for now (a link now, Design 2)
	w:advance(1)
	eq(wz.step, 3, "who summons")
	ok(has(m, "Who summons?", true), "step 3 title: " .. texts(m))
	ok(has(m, "No Warlock in your crew yet", true), "says nobody can cast: " .. texts(m))
	m:clickOn(wz.next) -- Done
	w:advance(1.5)
	eq(m.W.Drive.Role(), "driver", "a runner now")
	eq(m.W.Driver.ui.mode, "console", "the console")
	local ready = m.W.Driver.ui.console.ready
	ok(ready:IsShown(), "the Ready card")
	ok(has(m, "Choose who summons", true), "red line: " .. texts(m))
	ok(m.W.Drive.IsOpen() ~= true, "not open")
	-- Open is refused while nobody can cast
	m:clickOn(m.W.Driver.ui.console.open)
	w:advance(3)
	ok(m.W.Drive.IsOpen() ~= true, "still not open on the network")
	eq(#T.msgs(w, "D", MIA), 0, "no beacon")
	clean(w)
end)

test("r5 ui: wizard step 3 orders the summoners (ticks and arrows) and saves them", function()
	local w = newWorld()
	local a = w:addClient(T.ANA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(15)
	local DR = a.W.Drive
	a.W.Char().wizard = true
	-- the crew: two Warlocks (one without Wuber)
	local ch = a.W.Char()
	ch.crew = { { name = BEA, role = "lock", app = true }, { name = "Cal Brown", role = "lock", app = false } }
	openTab(a)
	a.W.UI.ShowDrive("wizard", 3)
	w:advance(1)
	local wz = a.W.UI.drive.wizard
	eq(wz.step, 3, "opened on step 3")
	local saved
	DR.SetSummoners = function(l) saved = l ch.summoners = l return true end
	DR.Summoners = function() return ch.summoners or {} end
	local rows = wz.summoners.list
	ok(#rows >= 3, "me + 2 Warlocks: " .. #rows)
	-- tick Bea (2nd), then move her up
	local bea
	for _, r in ipairs(rows) do if r:IsShown() and r.p and r.p.key == key(BEA) then bea = r end end
	ok(bea, "Bea's row")
	a:clickOn(bea.toggle)
	w:advance(0.5)
	eq(saved and #saved, 2, "me + Bea")
	eq(saved[2], key(BEA))
	for _, r in ipairs(rows) do if r:IsShown() and r.p and r.p.key == key(BEA) then bea = r end end
	ok(bea.up:IsShown(), "Bea can move up")
	a:clickOn(bea.up)
	w:advance(0.5)
	eq(saved[1], key(BEA), "Bea casts first")
	ok(has(a, "main caster", true), texts(a))
	ok(has(a, "no Wuber", true), "the no-Wuber Warlock is marked: " .. texts(a))
	clean(w)
end)

---------------------------------------------------------------------------
-- Scenario 6 (UI): the raid summons console
---------------------------------------------------------------------------

local function raidRunner()
	local w = newWorld()
	local d = w:addClient("Dru Lead", { spot = "Orgrimmar", class = "DRUID" })
	w:advance(15)
	local DR = d.W.Drive
	local st = { mode = "sell", run = false, offers = {}, adds = {}, tops = {}, drops = {} }
	d.W.Char().runner = true
	d.W.Char().wizard = true
	DR.Role = function() return "driver" end
	DR.Mode = function() return st.mode end
	DR.SetMode = function(m) st.mode = m return true end
	DR.IsOpen = function() return st.run end
	DR.SetOpen = function(on) st.run = on return true end
	DR.CanRunRaid = function() return true end
	DR.Summoners = function() return { key(BEA), "cal brown" } end
	DR.RaidWarlocks = function()
		return { { key = key(BEA), name = BEA, shards = 4, app = true }, { key = "cal brown", name = "Cal Brown", app = false },
			{ key = "eve night", name = "Eve Night", shards = 0, app = true } }
	end
	DR.RaidQueue = function()
		return { { name = DAN, asked = d.env.GetTime() - 30, state = "queued", tries = 0 },
			{ name = GUS, asked = d.env.GetTime() - 50, state = "summoning", claimedBy = key(BEA), tries = 0 } }
	end
	DR.NotHere = function() return { { name = "Fay Storm", class = "PRIEST", zone = "Orgrimmar" }, "Hal Stone" } end
	DR.RaidAdd = function(n) st.adds[#st.adds + 1] = n return true end
	DR.RaidOn = function() return st.run == true end -- (AUD-173) the + works only once Start is pressed
	DR.RaidTop = function(n) st.tops[#st.tops + 1] = n end
	DR.RaidDrop = function(n, why) st.drops[#st.drops + 1] = n .. ":" .. tostring(why) end
	DR.RaidCount = function() return 14 end
	DR.OfferCrew = function(n, svc) st.offers[#st.offers + 1] = n .. ":" .. tostring(svc) return true end
	return w, d, st
end

test("r5 ui: scenario 6: the Sell / Raid header switches to the raid console (Start, summoners, queue, Not here, tonight)", function()
	local w, d, st = raidRunner()
	openTab(d)
	local v = d.W.Driver.ui.console
	ok(v.modeBar:IsShown(), "the header: " .. texts(d))
	d:clickText("Raid summons")
	w:advance(1)
	eq(st.mode, "raid", "DR.SetMode('raid')")
	ok(has(d, "Start", true), "Start pill: " .. texts(d))
	ok(not v.advert:IsShown(), "no Advertise in raid mode")
	ok(has(d, "Summoned tonight: 14", true) and has(d, "summoned tonight", true), "tonight: " .. texts(d))
	ok(has(d, "no Wuber", true), "the summoner strip marks Cal: " .. texts(d))
	ok(has(d, "summoning (Bea)", true), "a claimed raider: " .. texts(d))
	ok(has(d, "Not here (2)", true), "Not here: " .. texts(d))
	-- nothing in public chat, no invites from the console
	ok(d.W.Driver.AdvertTarget("go") == nil, "Start never posts an advert")
	d:clickOn(v.open)
	w:advance(1)
	eq(st.run, true, "started")
	ok(has(d, "Running", true), "status Running: " .. texts(d))
	-- a raider row: click = move to top, right-click = off the list
	local row = v.rows[1]
	eq(row.raidRow, true, "a raid row")
	d:click(row, "LeftButton")
	eq(st.tops[1], DAN, "moved to top")
	d:click(row, "RightButton")
	eq(st.drops[1], DAN .. ":hand", "off the list")
	-- Not here: open it, + queues by hand
	-- (design 2) the tab bar is at the bottom: a row below the list's view is scrolled to, as the player does
	scrollTo(v.scroll, d:findText("Not here (2)", false, true)[1], d.W.UI.state.tabbar)
	w:advance(0.3) -- (HUNT-145) the pill's check runs five times a second: a header it covered is back by then
	d:clickText("Not here (2)")
	w:advance(1)
	local R = v.raid
	-- the opened rows start under the view: scroll to the first one, as the player does
	scrollTo(v.scroll, R.nh[1].add, d.W.UI.state.tabbar)
	w:advance(0.5)
	ok(has(d, "Orgrimmar", true), "where they are: " .. texts(d))
	d:clickOn(R.nh[1].add)
	eq(st.adds[1], "Fay Storm", "queued by hand")
	eq(#(w.chatPosts or {}), 0, "nothing said in chat")
	clean(w)
end)

test("r5 ui: scenario 6: Pick summoners lists the raid's Warlocks (Wuber yes/no, shards) and sends a raid offer", function()
	local w, d, st = raidRunner()
	st.mode = "raid"
	openTab(d)
	d:clickOn(d.W.Driver.ui.console.pick)
	w:advance(1)
	ok(has(d, "Pick summoners", true), texts(d))
	ok(has(d, "4 shards", true) and has(d, "0 shards", true), "shards: " .. texts(d))
	ok(has(d, "no Wuber", true) and has(d, "Wuber", true), "Wuber yes/no: " .. texts(d))
	local s = d.W.UI.drive.screens.raidpick
	local eve
	for _, r in ipairs(s.rows.list) do if r:IsShown() and r.p and r.p.key == "eve night" then eve = r end end
	ok(eve and not eve.toggle.on, "Eve not picked yet")
	d:clickOn(eve.toggle)
	w:advance(0.5)
	eq(st.offers[1], "Eve Night:raid", "a raid crew offer")
	clean(w)
end)

test("r5 ui: scenario 6: a summoner's card says 'Summon for Dru's raid?'", function()
	local w = newWorld()
	local b = w:addClient(BEA, { spot = "Orgrimmar", class = "WARLOCK" })
	w:advance(15)
	b.W.UI.CrewOffer("Dru Lead", "raid")
	w:advance(1)
	ok(has(b, "Summon for Dru's raid?", true), texts(b))
	ok(has(b, "big button that summons the next raider", true), texts(b))
	clean(w)
end)

---------------------------------------------------------------------------
-- Stations (SPEC4 2, UI parts of scenarios 1/4)
---------------------------------------------------------------------------

test("r5 ui: two stations: filter chips and station chips on the queue, the Stations card, the price sheet's note", function()
	local w = newWorld()
	local a = w:addClient(T.ANA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(15)
	local DR = a.W.Drive
	a.W.Char().wizard = true
	local off = {}
	DR.Stations = function()
		return { { place = "Undercity", summoners = { key(T.ANA) }, helpers = { "x", "y" }, open = true, ready = true },
			{ place = "Orgrimmar", summoners = { key(BEA) }, helpers = {}, open = off.Orgrimmar ~= true, ready = false } }
	end
	DR.SetStation = function(p, on) off[p] = not on end
	local t0 = a.env.GetTime()
	local cs = { { name = DAN, key = key(DAN), state = "queued", at = t0, station = "Undercity", source = "whisper" },
		{ name = GUS, key = key(GUS), state = "queued", at = t0, station = "Orgrimmar", source = "wuber" } }
	DR.Sorted = function() return cs end
	DR.customers = { [key(DAN)] = cs[1], [key(GUS)] = cs[2] }
	openTab(a)
	local v = a.W.Driver.ui.console
	ok(has(a, "All", true), "filter chips: " .. texts(a))
	ok(v.rows[1].station:IsShown(), "station chip on the row")
	a:clickOn(v.fchips[3]) -- Orgrimmar
	w:advance(1)
	eq(v.stationFilter, "Orgrimmar")
	eq(v.rows[1].c.name, GUS, "only Orgrimmar's rider")
	ok(not v.rows[2]:IsShown(), "one row")
	-- the price sheet: no place to choose
	a.W.UI.ShowDrive("sheet")
	w:advance(1)
	ok(has(a, "Each Warlock summons to where they stand", true), texts(a))
	ok(not a.W.UI.drive.screens.sheet.where:IsShown(), "the place picker is hidden")
	a.W.UI.drive.screens.sheet.frame:Close(true)
	-- the Crew screen's Stations card, with the switch
	a.W.UI.ShowDrive("crew")
	w:advance(1)
	ok(has(a, "Stations", true) and has(a, "riders bring a friend", true), texts(a))
	local card = a.W.UI.drive.screens.crew.stCard
	a:clickOn(card.rows.list[2].toggle)
	eq(off.Orgrimmar, true, "Orgrimmar switched off")
	clean(w)
end)

test("r5 ui: a rider whose payee has no Wuber: 'paid? ask Bea' on the row", function()
	local w = newWorld()
	local a = w:addClient("Mia Runner", { spot = "Undercity", class = "MAGE" })
	w:advance(15)
	local DR = a.W.Drive
	a.W.Char().wizard = true
	a.W.Char().runner = true
	DR.Role = function() return "driver" end
	local c = { name = DAN, key = key(DAN), state = "arrived", at = a.env.GetTime(), price = 5000, payeeBlind = true }
	DR.Sorted = function() return { c } end
	DR.customers = { [key(DAN)] = c }
	DR.Payee = function() return key(BEA) end
	DR.WhoIs = function(k) return k == key(BEA) and BEA or k end
	openTab(a)
	ok(has(a, "paid? ask Bea", true), texts(a))
	clean(w)
end)

---------------------------------------------------------------------------
-- the author's UI fixes (18 Nov): Done unpaid, the Uber-like Confirm, the tip slider, toasts
---------------------------------------------------------------------------

test("r5 ui: Done, unpaid: no victory tick (a quiet grey coin), and the note wraps whole", function()
	local w, r = riderWithRide("done", { unpaid = true })
	r.W.UI.Show("done")
	w:advance(3)
	local s = r.W.UI.state.screens.done
	ok(has(r, "Ride ended", true), texts(r))
	local tex = H.state[s.mark].texture or ""
	ok(tostring(tex):find("coin"), "the coin, not the check: " .. tostring(tex))
	local cr, cg, cb = s.circle:GetVertexColor()
	local ar, ag, ab = r.W.Theme.RGB("accent")
	ok(not (math.abs(cr - ar) < 0.01 and math.abs(cg - ag) < 0.01 and math.abs(cb - ab) < 0.01), "not the violet victory disc")
	-- the whole sentence, wrapped (a paragraph tall enough for its lines)
	local sub = s.unpaidText
	ok(tostring(H.state[sub].text):find("Not paid, so no level progress.", 1, true) == 1,
		"the note: " .. tostring(H.state[sub].text))
	ok(has(r, "Drivers can block riders who don't pay.", true), "and what leaving unpaid risks: " .. texts(r))
	ok((sub.paraLines or 1) >= 2, "wraps onto two lines: " .. tostring(sub.paraLines))
	ok(sub:GetHeight() >= (sub.paraLines or 2) * 13, "tall enough: " .. tostring(sub:GetHeight()))
	-- and a paid ride still gets the tick
	r.W.ride.unpaid = nil
	r.W.Fire("RIDE")
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(tostring(H.state[s.mark].texture or ""):find("check"), "paid: the check")
	clean(w)
end)

test("r5 ui: Confirm, one sheet: 'Request summon · 50s' is still the secure button, and one click requests", function()
	local w = newWorld()
	local d = T.driver(w)
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	T.goOnline(d)
	T.openConfirm(r, "anita lift")
	ok(has(r, "Request summon · 50s", true), "the big button: " .. texts(r))
	ok(has(r, "Trade 50s after you arrive", true), "how you pay: " .. texts(r))
	local pill = r.W.UI.state.screens.confirm.request
	local b = r.env.WuberRequestButton
	ok(H.visible(b), "the secure button is over it")
	local pr, br = H.rect(pill), H.rect(b)
	ok(math.abs(pr.l - br.l) < 0.6 and math.abs(pr.b - br.b) < 0.6 and math.abs(pr.w - br.w) < 0.6, "same place and size")
	local hit = r:clickOn(pill)
	ok(H.state[hit].secure, "the click lands on the secure button")
	w:advance(2)
	ok(r.W.ride and r.W.ride.driverKey == "anita lift", "the request went out: " .. tostring(r.W.ride and r.W.ride.state))
	clean(w)
end)

-- the tip buttons (Wuber's 04 v1 pick): No tip / 10% / 20% / Custom (the stops 0-100%), remembered
-- per account, feeding every "what to type" line; the rider still types the gold in the trade
local function tipKeyFor(s, label)
	for _, b in ipairs(s.tipKeys) do
		if b:IsShown() and b.top.wuberText == label then return b end
	end
	for _, b in ipairs(s.pick.keys) do
		if b:IsVisible() and b.top.wuberText == label then return b end
	end
end

test("r5 ui: tip buttons: 10% on 50s = 55s (rounded up to whole silver), every pay line follows, remembered", function()
	local w, r = riderWithRide("arrived")
	local UI = r.W.UI
	eq(UI.TipFor(5000, 10), 500, "10% of 50s")
	eq(UI.TipFor(5000, 15), 800, "15% of 50s = 7.5s -> 8s")
	eq(UI.TipFor(12345, 20), 2500, "20% of 1g 23s 45c = 24.69s -> 25s")
	eq(UI.TipFor(5000, 0), 0, "no tip")
	r.W.db.tipPct = 0
	UI.Show("found")
	w:advance(3)
	local s = UI.state.screens.found
	ok(H.visible(s.pay), "the pay card once arrived: " .. texts(r))
	ok(has(r, "Type in trade window", true), texts(r))
	for _, label in ipairs({ "No tip", "10%", "20%", "Custom" }) do
		ok(tipKeyFor(s, label), "the " .. label .. " button: " .. texts(r))
	end
	ok(has(r, "(+5s)", true) and has(r, "(+10s)", true), "what each adds: " .. texts(r))
	ok(tipKeyFor(s, "No tip").on, "No tip chosen")
	eq(H.state[s.pay.big].text, "50s", "the fare alone")
	-- 10%: type 55s
	r:clickOn(tipKeyFor(s, "10%"))
	w:advance(1)
	eq(r.W.db.tipPct, 10, "remembered for the account")
	ok(tipKeyFor(s, "10%").on and not tipKeyFor(s, "No tip").on, "10% lit, No tip not")
	eq(H.state[s.pay.big].text, "55s", "the big number")
	ok(has(r, "50s fare + 5s tip · Pay Bea", true), "the fare and tip: " .. texts(r))
	-- the trade opens: the button and the strip under the trade window say the same total
	r.W.ride.state = "paying"
	H.state[r.env.TradeFrame].shown = true
	r.W.tradeOpen = true
	r.W.Fire("RIDE")
	r:fire("TRADE_SHOW")
	w:advance(1)
	ok(#r:findText("Type 55 in silver, then click Trade", false, true) > 0, "trade strip: " .. texts(r))
	ok(has(r, "Type 55s, click Trade", true), "the button: " .. texts(r))
	ok(not has(r, "one click"), "no one-click claim")
	-- a new ride starts at the remembered 10%
	local w2, r2 = riderWithRide("arrived")
	r2.W.db.tipPct = 10
	eq(r2.W.UI.PayTotal(r2.W.UI.Ride()), 5500, "55s")
	clean(w)
	clean(w2)
end)

test("r5 ui: tip buttons: Custom opens the stops 0-100%; a stop is chosen, remembered, and shown on the Custom button", function()
	local w, r = riderWithRide("arrived")
	local UI = r.W.UI
	r.W.db.tipPct = 0
	UI.Show("found")
	w:advance(3)
	local s = UI.state.screens.found
	ok(not H.visible(s.pick), "the stops stay closed")
	r:clickOn(tipKeyFor(s, "Custom"))
	w:advance(1)
	ok(H.visible(s.pick), "Custom opens the stops: " .. texts(r))
	for _, label in ipairs({ "None", "10%", "15%", "25%", "50%", "75%", "100%" }) do
		ok(has(r, "^" .. label:gsub("%%", "%%%%") .. "$"), "the " .. label .. " stop: " .. texts(r))
	end
	-- each stop sits inside the pay card (nothing cut off)
	local card = H.rect(s.pay)
	for _, b in ipairs(s.pick.keys) do
		local k = H.rect(b)
		ok(k.l >= card.l - 0.5 and k.l + k.w <= card.l + card.w + 0.5 and k.b >= card.b - 0.5, "stop inside the card: " .. tostring(b.pct))
	end
	-- 25% of 50s = 12.5s -> 13s: type 63s
	local stop
	for _, b in ipairs(s.pick.keys) do if b.pct == 25 then stop = b end end
	r:clickOn(stop)
	w:advance(1)
	eq(r.W.db.tipPct, 25, "remembered")
	ok(not H.visible(s.pick), "the stops close")
	eq(H.state[s.pay.big].text, "63s", "50s + 13s")
	ok(has(r, "^25%%$") and has(r, "(+13s)", true), "the Custom button shows the choice: " .. texts(r))
	ok(tipKeyFor(s, "25%").on, "and is lit")
	ok(has(r, "Waiting for Bea to trade", true), "still waiting for the trade: " .. texts(r))
	-- not a stop: refused, the choice stays
	eq(UI.SetTipPct(33), false, "33% is no stop")
	eq(r.W.db.tipPct, 25)
	-- back to a quick button: Custom says Custom again
	r:clickOn(tipKeyFor(s, "No tip"))
	w:advance(1)
	eq(r.W.db.tipPct, 0)
	eq(H.state[s.pay.big].text, "50s")
	ok(tipKeyFor(s, "Custom") and not tipKeyFor(s, "Custom").on, "Custom unlit")
	clean(w)
end)

test("r5 ui: toasts never land on the window's tabs", function()
	local w = newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	r.W.UI.Show("home")
	w:advance(3)
	local t = r.W.UI.Toast("Anita accepted", "found")
	w:advance(1)
	local tr = H.rect(t)
	for _, name in ipairs({ "Ride", "Trips", "Drive" }) do
		local tab = r:findText("^" .. name .. "$")[1]
		local b = H.rect(tab)
		local overlap = tr.l < b.l + b.w and b.l < tr.l + tr.w and tr.b < b.b + b.h and b.b < tr.b + tr.h
		ok(not overlap, "the toast covers the " .. name .. " tab")
	end
	clean(w)
end)
