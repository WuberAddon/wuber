-- Wuber 2.2 (round six, SPEC5.md) tests: agent C's part (UI). Loaded by run.lua with the
-- same helpers as round five. Test names start "r6 ui:".
--
-- Each item of SPEC5's C list has a regression test here (the purely visual ones are checked
-- in the previews, tools/preview6.png). The engine's answers (A: W.FlightCost,
-- W.SummonerMapOK; B: DR.RideCount, DR.ShiftSummary, DR.Heatmap) are set on the window where
-- a scenario needs them, so the screens are checked against the interfaces of BUILD-NOTES.

local T = ...
local SI = "s" -- (design 1 H: money is letters, "23s", no coin icons)
local function G(s) return "|cfff9c53e" .. s .. "|r" end -- (design 1 P) an amount beside a time is gold letters
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list
local newWorld, clean = T.newWorld, T.clean
local S = H.state

local MIA, BEA, DAN, GUS, SLY = "Mia Runner", "Bea Jones", "Dan Rider", "Gus Hill", "Sly Fox"

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function texts(c) return list(c:visibleTexts(), " | ") end
local function has(c, pattern, plain) return #c:findText(pattern, false, plain) > 0 end

local function openTab(c, tab)
	c.W.db.coach = true
	c.W.UI.Toggle(true)
	c.world:advance(2.5)
	c:clickText(tab or "Drive")
	c.world:advance(1)
end

-- a rider whose ride (driven by Mia, summoned by Bea) is at `state`
local function riderWithRide(state, extra, opts)
	local w = newWorld()
	local r = T.rider(w, T.TESTCHAR, opts)
	w:advance(15)
	local ride = { id = "r6", driver = MIA, driverKey = key(MIA), dest = "Undercity", price = 5000, state = state,
		at = r.env.GetTime(), payee = BEA, payto = "Bea", summoner = BEA, service = "Mia's Rides" }
	for k, v in pairs(extra or {}) do ride[k] = v end
	r.W.ride = ride
	r.W.db.tipPct = 0
	r.W.Fire("RIDE")
	return w, r
end

-- the text of every toast this client asked for (UI.Toast wrapped)
local function catchToasts(c)
	local seen = {}
	local orig = c.W.UI.Toast
	c.W.UI.Toast = function(text, kind, onClick)
		seen[#seen + 1] = tostring(text) .. " [" .. tostring(kind) .. "]"
		return orig(text, kind, onClick)
	end
	return seen
end

local function anyFind(l, pattern)
	for _, t in ipairs(l) do if tostring(t):find(pattern, 1, true) then return true end end
	return false
end

test("r6 ui: the file loads", function()
	ok(H ~= nil, "the harness")
	eq(type(T.newWorld), "function")
end)

---------------------------------------------------------------------------
-- tradecheck (#3): the pay strip only for the driver or the crew; a stranger gets a warning
---------------------------------------------------------------------------

test("r6 ui: tradecheck - a stranger's trade mid-ride gets no pay strip and a warning toast; the driver's trade gets the strip", function()
	local w, r = riderWithRide("arrived")
	local seen = catchToasts(r)
	w:addBot(SLY, { spot = "Orgrimmar" })
	H.state[r.env.TradeFrame].shown = true
	ok(w:openTrade(w:player(SLY), r.player), "the stranger opens trade")
	w:advance(1)
	ok(#r:findText("^Wuber: ") == 0, "no 'Wuber: Pay Bea. Type 50 in silver' under a stranger's trade: " .. texts(r))
	ok(anyFind(seen, "Sly isn't your driver"), "warning toast: " .. list(seen))
	ok(anyFind(seen, "[warn]"), "a warning: " .. list(seen))
	w:tradeCancel(r.player)
	w:advance(0.5)
	-- the driver (Mia) opens trade: the strip says what to type
	w:addBot(MIA, { spot = "Orgrimmar" })
	ok(w:openTrade(w:player(MIA), r.player), "Mia opens trade")
	w:advance(1)
	ok(#r:findText("^Wuber: Pay Bea") > 0, "the strip for the driver: " .. texts(r))
	w:tradeCancel(r.player)
	w:advance(0.5)
	-- someone else in the ride's group is not the crew (review 2.2 #1: a group full of riders)
	w:addBot(GUS, { spot = "Orgrimmar" })
	w:group({ MIA, T.TESTCHAR, GUS })
	w:advance(0.5)
	ok(w:openTrade(w:player(GUS), r.player), "Gus (in the group, not named crew) opens trade")
	w:advance(1)
	ok(#r:findText("^Wuber: Pay Bea") == 0, "no strip for a group member the driver never named: " .. texts(r))
	eq(r.W.UI.TradePartnerOK(r.W.UI.Ride()), false, "Gus is not the crew")
	w:tradeCancel(r.player)
	w:advance(0.5)
	-- a crew member the driver named in its S counts
	r.W.ride.crew = { key(GUS) }
	ok(w:openTrade(w:player(GUS), r.player), "Gus (named crew) opens trade")
	w:advance(1)
	ok(#r:findText("^Wuber: Pay Bea") > 0, "the strip for the crew: " .. texts(r))
	eq(r.W.UI.TradePartnerOK(r.W.UI.Ride()), true, "Gus is fine")
	clean(w)
end)

test("r6 ui: tradecheck - no ride, no warning (strangers may trade you any time)", function()
	local w = newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local seen = catchToasts(r)
	w:addBot(SLY, { spot = "Orgrimmar" })
	H.state[r.env.TradeFrame].shown = true
	w:openTrade(w:player(SLY), r.player)
	w:advance(1)
	ok(not anyFind(seen, "isn't your driver"), "no warning without a ride: " .. list(seen))
	ok(#r:findText("^Wuber: ") == 0, "no strip")
	clean(w)
end)

---------------------------------------------------------------------------
-- unpaidtext (#14)
---------------------------------------------------------------------------

test("r6 ui: unpaidtext - the unpaid end never says 'saved to your trips' and says drivers can block", function()
	local w, r = riderWithRide("done", { unpaid = true, saved = 600 })
	r.W.UI.Show("done")
	w:advance(3)
	ok(has(r, "Ride ended", true), texts(r))
	ok(not has(r, "saved to your trips", true) and not has(r, "Saved to your trips", true), "no 'saved to your trips': " .. texts(r))
	ok(has(r, "Drivers can block riders who don't pay.", true), "the block line: " .. texts(r))
	ok(not has(r, "You saved", true), "no time-saved brag on an unpaid end")
	-- a paid ride still says it
	r.W.ride.unpaid, r.W.ride.paid = nil, 5000
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(has(r, "saved to your trips", true), "paid: " .. texts(r))
	ok(not has(r, "Drivers can block", true), "paid: no warning")
	clean(w)
end)

---------------------------------------------------------------------------
-- mapcheck (#26): a warning line before Accept summon, never a block
---------------------------------------------------------------------------

test("r6 ui: mapcheck - Accept summon shows the warning line when nobody is in the booked place, and stays clickable", function()
	local w, r = riderWithRide("portal", { summonUp = true })
	local answer, where = false, "Deadwind Pass"
	local asked = 0
	r.W.SummonerMapOK = function(ride)
		asked = asked + 1
		eq(ride, r.W.ride, "called with the ride")
		return answer, where
	end
	r.W.UI.Show("found")
	w:advance(2)
	ok(asked > 0, "asked the engine")
	-- the amber safety card over Accept summon (03 v1)
	ok(has(r, "Summoner is in Deadwind Pass", true) and has(r, "Not Undercity - check before accepting", true), "the warning: " .. texts(r))
	local s = r.W.UI.state.screens.found
	ok(H.visible(s.alert), "the amber card")
	ok(H.rect(s.alert).b > H.rect(s.action).b + H.rect(s.action).h, "above Accept summon")
	ok(has(r, "Accept summon", true), "Accept summon still there: " .. texts(r))
	local btn = r:button("Accept summon")
	ok(btn and not btn.inactive, "and active (a warning, not a block)")
	-- no name: the general line
	where = nil
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(has(r, "Nobody in this group seems to be in Undercity.", true), texts(r))
	-- fine or unknown: nothing
	for _, a in ipairs({ true, "nil" }) do
		answer = a ~= "nil" and a or nil
		r.W.UI.Refresh(true)
		w:advance(1)
		ok(not has(r, "Summoner is in", true) and not has(r, "seems to be in", true) and not H.visible(r.W.UI.state.screens.found.alert),
			tostring(a) .. ": no warning: " .. texts(r))
	end
	clean(w)
end)

---------------------------------------------------------------------------
-- helperpause (#17): helpers can't pause from the mini console or the minimap
---------------------------------------------------------------------------

test("r6 ui: helperpause - a helper's mini Pause, minimap shift-right-click and D.SetPaused never pause", function()
	local w = newWorld()
	local h = T.rider(w, "Pat Helper", { class = "PRIEST" })
	w:advance(15)
	local DR = h.W.Drive
	local pauses = 0
	DR.Role = function() return "helper" end
	DR.IsOpen = function() return true end
	DR.IsPaused = function() return false end
	DR.SetPaused = function() pauses = pauses + 1 return true end
	local D = h.W.Driver
	eq(D.CanPause(), false, "a helper can't pause")
	eq(h.W.UI.MayPause(), false, "UI.MayPause")
	eq(D.SetPaused(true), false, "D.SetPaused refuses")
	-- the minimap: shift-right-click
	h.env.IsShiftKeyDown = function() return true end
	local mm = h.env.WuberMinimapButton
	ok(mm, "the minimap button")
	h:click(mm, "RightButton")
	w:advance(1)
	eq(pauses, 0, "no pause from the minimap")
	-- the mini console's Pause (built on demand): its click does nothing, its label says so
	local mini = h.W.UI.drive.mini
	if not mini then
		DR.button = DR.button or h.env.WuberDriveButton
		D.UpdateMini()
		mini = h.W.UI.drive.mini
	end
	if mini then
		H.runScript(mini.pause, "OnClick", "LeftButton")
		eq(pauses, 0, "no pause from the mini console")
	end
	-- a Warlock can
	DR.Role = function() return "driver" end
	eq(D.CanPause(), true)
	h:click(mm, "RightButton")
	w:advance(1)
	eq(pauses, 1, "the driver's shift-right-click pauses")
	clean(w)
end)

---------------------------------------------------------------------------
-- timers (#27): no idle OnUpdate on queue rows; the mini ticker only while floating
---------------------------------------------------------------------------

test("r6 ui: timers - queue rows run an OnUpdate only while pressed; the long press still opens the menu", function()
	local w = newWorld()
	local a = w:addClient(T.ANA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(15)
	local DR = a.W.Drive
	a.W.Char().wizard = true
	local c = { name = DAN, key = key(DAN), state = "queued", at = a.env.GetTime(), source = "whisper" }
	DR.Sorted = function() return { c } end
	DR.customers = { [key(DAN)] = c }
	openTab(a)
	local v = a.W.Driver.ui.console
	local row = v.rows[1]
	ok(row:IsShown(), "a row")
	for i, r in ipairs(v.rows) do eq(S[r].scripts.OnUpdate, nil, "row " .. i .. " idle: no OnUpdate") end
	-- press and hold
	local menus = 0
	local open = a.W.Driver.OpenMenu
	a.W.Driver.OpenMenu = function(...) menus = menus + 1 end
	H.runScript(row, "OnMouseDown", "LeftButton")
	ok(S[row].scripts.OnUpdate ~= nil, "pressed: the hold timer runs")
	w:advance(0.6)
	eq(menus, 1, "the long press opened the menu")
	eq(S[row].scripts.OnUpdate, nil, "and the timer stopped")
	H.runScript(row, "OnMouseDown", "LeftButton")
	H.runScript(row, "OnMouseUp", "LeftButton")
	eq(S[row].scripts.OnUpdate, nil, "let go: stopped")
	H.runScript(row, "OnMouseDown", "LeftButton")
	H.runScript(row, "OnLeave")
	eq(S[row].scripts.OnUpdate, nil, "left: stopped")
	a.W.Driver.OpenMenu = open
	clean(w)
end)

test("r6 ui: timers - the mini console's ticker never runs on a rider, and only while the big button floats", function()
	local w = newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	eq(r.W.Driver.MiniTicking(), false, "a rider: no ticker")
	-- count the 0.25 s tickers this client has
	local function quarterTickers(c)
		local n = 0
		for _, t in ipairs(w.timers) do
			if t.client == c and t.every == 0.25 and not t.cancelled then n = n + 1 end
		end
		return n
	end
	local base = quarterTickers(r)
	-- a Warlock with the big button floating: it runs; docked or hidden: it stops
	local a = w:addClient(T.ANA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(15)
	local DR, D = a.W.Drive, a.W.Driver
	local floating = false
	DR.Button = DR.Button or {}
	local realFloating = DR.Button.Floating
	DR.Button.Floating = function() return floating end
	DR.button = DR.button or a.env.WuberDriveButton
	ok(DR.button, "the big button")
	H.state[DR.button].shown = true
	D.SyncMini()
	eq(D.MiniTicking(), false, "docked: no ticker")
	floating = true
	D.SyncMini()
	eq(D.MiniTicking(), true, "floating: the ticker runs")
	floating = false
	a.W.Fire("DRIVE")
	eq(D.MiniTicking(), false, "docked again: stopped (on the DRIVE event)")
	DR.Button.Floating = realFloating
	eq(quarterTickers(r), base, "the rider never got one")
	clean(w)
end)

---------------------------------------------------------------------------
-- redraws (#10): the map's pins redraw at most 4 times a second
---------------------------------------------------------------------------

test("r6 ui: redraws - 60 DRIVERS events in half a second redraw the map pins at most 3 times", function()
	local w = newWorld()
	local r = T.rider(w, T.TESTCHAR, { openMap = { stitched = true } })
	w:advance(15)
	r.env.WorldMapFrame:Show()
	r.env.WorldMapFrame:SetMapID(1414)
	w:advance(1)
	local M = r.W.Map
	local refreshes = 0
	local orig = M.Refresh
	M.Refresh = function(...) refreshes = refreshes + 1 return orig(...) end
	local before = M.redraws
	for i = 1, 60 do
		r.W.Fire("DRIVERS")
		if i % 6 == 0 then w:advance(0.05) end
	end
	w:advance(1)
	ok(M.redraws - before >= 1, "redrawn at least once")
	ok(M.redraws - before <= 3, "at most 3 redraws for 60 events: " .. (M.redraws - before))
	M.Refresh = orig
	-- closed map: none
	r.env.WorldMapFrame:Hide()
	before = M.redraws
	for _ = 1, 10 do r.W.Fire("DRIVERS") end
	w:advance(1)
	eq(M.redraws, before, "closed map: nothing")
	clean(w)
end)

---------------------------------------------------------------------------
-- repeat (#19): "3rd ride with you" on the queue row
---------------------------------------------------------------------------

test("r6 ui: repeat - a returning rider's row says '3rd ride with you'; a first ride says nothing", function()
	local w = newWorld()
	local a = w:addClient(T.ANA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(15)
	local DR = a.W.Drive
	a.W.Char().wizard = true
	local t0 = a.env.GetTime()
	local cs = { { name = DAN, key = key(DAN), state = "queued", at = t0, source = "whisper" },
		{ name = GUS, key = key(GUS), state = "queued", at = t0, source = "wuber" } }
	DR.Sorted = function() return cs end
	DR.customers = { [key(DAN)] = cs[1], [key(GUS)] = cs[2] }
	local counts = { [DAN] = 2, [GUS] = 0 }
	DR.RideCount = function(name) return counts[name] or 0 end
	openTab(a)
	local v = a.W.Driver.ui.console
	ok(v.rows[1].again:IsShown(), "Dan's chip")
	ok(has(a, "3rd ride with you", true), texts(a))
	ok(not v.rows[2].again:IsShown(), "Gus: first ride, no chip")
	-- the count is cached until a payment
	counts[GUS] = 1
	a.W.Fire("DRIVE_PAID", GUS, 5000, 0, nil, true, "t", 5000)
	a.W.Driver.RefreshNow()
	w:advance(1)
	ok(has(a, "2nd ride with you", true), "after a payment: " .. texts(a))
	eq(a.W.Driver.RideCount("Nobody"), 0)
	clean(w)
end)

---------------------------------------------------------------------------
-- coinfx (#20): the coin effect on DRIVE_PAID
---------------------------------------------------------------------------

test("r6 ui: coinfx - DRIVE_PAID (a trade this window took) bursts coins, once; tips get the bigger shower", function()
	local w = newWorld()
	local a = w:addClient(T.ANA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(15)
	local FX = a.W.FX
	local played = {}
	local orig = FX.Fullscreen
	FX.Fullscreen = function(name, ...) played[#played + 1] = name return orig(name, ...) end
	a.W.Fire("DRIVE_PAID", DAN, 5000, 0, key(T.ANA), true, "t", 5000)
	eq(played[#played], "paid", "a plain fare: the paid burst")
	local n = #played
	-- the same payment's W.SendStage("paid") burst right after: not a second one
	FX.OnPaid("ride-1")
	eq(#played, n, "no double burst")
	w:advance(6)
	a.W.Fire("DRIVE_PAID", GUS, 6000, 1000, key(T.ANA), true, "t", 5000)
	eq(played[#played], "coins", "with a tip: the coin shower")
	n = #played
	w:advance(6)
	a.W.Fire("DRIVE_PAID", GUS, 5000, 0, key(T.ANA), true, "m", 5000)
	a.W.Fire("DRIVE_PAID", GUS, 5000, 0, key(BEA), false, "t", 5000)
	eq(#played, n, "marked by hand, or a crew mate's payment: nothing")
	FX.Fullscreen = orig
	clean(w)
end)

---------------------------------------------------------------------------
-- shift (#20): the end-of-shift card when the driver closes
---------------------------------------------------------------------------

test("r6 ui: shift - closing after a shift with rides shows the summary card; a shift with none shows nothing", function()
	local w = newWorld()
	local a = w:addClient(T.ANA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(15)
	local DR = a.W.Drive
	a.W.Char().wizard = true
	local open = true
	DR.IsOpen = function() return open end
	DR.SetOpen = function(on) open = on return true end
	local sum = { rides = 7, copper = 41000, tips = 3000, open = 7200, bestHour = 20, bestCopper = 15000, crewRides = 0, crewCopper = 0 }
	local called = 0
	DR.ShiftSummary = function() called = called + 1 return sum end
	openTab(a)
	a:clickOn(a.W.Driver.ui.console.open) -- Close
	w:advance(1)
	eq(open, false, "closed")
	eq(called, 1, "DR.ShiftSummary once, after closing")
	ok(has(a, "Shift complete", true), "the card: " .. texts(a))
	ok(has(a, "4g 10s", true), "gold: " .. texts(a))
	ok(has(a, "20:00", true), "best hour: " .. texts(a))
	ok(has(a, "2 h", true), "time open: " .. texts(a))
	ok(has(a, "this shift · 2g an hour", true), "gold per hour: " .. texts(a))
	a.W.UI.drive.screens.shift.frame:Close(true)
	w:advance(1)
	-- open and close with no rides: no card
	open = true
	sum = { rides = 0, copper = 0, tips = 0, open = 600, crewRides = 0 }
	a.W.Driver.Refresh(true)
	w:advance(1)
	a:clickOn(a.W.Driver.ui.console.open)
	w:advance(1)
	ok(not a.W.UI.drive.screens.shift.frame.open, "no card for an empty shift")
	clean(w)
end)

---------------------------------------------------------------------------
-- streaks (#19): streak days, favourite driver, lifetime spent on Trips and Done
---------------------------------------------------------------------------

local function statsOf(r, s)
	r.W.Stats = function()
		local base = { rides = 6, places = 3, spent = 32000, saved = 3600, savedValue = 10000, favouriteDriver = MIA,
			favouriteKey = key(MIA), favouriteCount = 5, streakDays = 4 }
		for k, v in pairs(s or {}) do base[k] = v end
		return base
	end
end

test("r6 ui: streaks - Trips shows the streak, the go-to driver and the lifetime spent; Done the same in one line", function()
	local w, r = riderWithRide("done", { paid = 5000 })
	statsOf(r)
	r.W.UI.Show("done")
	w:advance(3)
	ok(has(r, "4-day ride streak · 5 rides with Mia · 3g 20s in all", true), "Done: " .. texts(r))
	r.W.UI.Dismiss(true)
	w:advance(1)
	r:clickText("Trips")
	w:advance(2)
	-- the chips (07 v2); their tooltips keep the long lines
	ok(has(r, "^4%-day streak$"), "Trips streak: " .. texts(r))
	ok(has(r, "^Go%-to: Mia %(5%)$"), "go-to driver: " .. texts(r))
	ok(has(r, "^Spent 3g 20s$"), "spent: " .. texts(r))
	local long = r.W.UI.TripsHabits()
	eq(long[2], "4-day ride streak · ride tomorrow to keep it", "the streak chip's tooltip")
	eq(long[1], "Your go-to driver: Mia · 5 rides", "the go-to chip's tooltip")
	eq(long[3], "Spent 3g 20s on summons in all", "the spent chip's tooltip")
	-- a one-day streak or a one-ride favourite says nothing
	statsOf(r, { streakDays = 1, favouriteCount = 1 })
	r.W.UI.UpdateTrips()
	w:advance(1)
	ok(not has(r, "day streak", true) and not has(r, "Go-to:", true), "nothing to say: " .. texts(r))
	clean(w)
end)

---------------------------------------------------------------------------
-- coach (#22): paying and driving tips; done only on Got it / Skip; Replay in Settings
---------------------------------------------------------------------------

test("r6 ui: coach - the tips cover paying and driving, stay inside the window, survive closing it, and Replay brings them back", function()
	local w = newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	r.W.UI.Toggle(true)
	w:advance(3)
	ok(has(r, "Tip 1 of 5", true), "five tips: " .. texts(r))
	local titles = {}
	for _, c in ipairs(r.W.UI.COACH) do titles[#titles + 1] = c.title .. ": " .. c.text end
	ok(anyFind(titles, "type the fare in your driver's trade and click Trade"), "paying: " .. list(titles))
	ok(anyFind(titles, "Drive tab"), "driving: " .. list(titles))
	-- the card is inside the window
	local card = r.W.UI.state.coach
	local cr, wr = H.rect(card), H.rect(r.env.WuberFrame)
	ok(cr.l >= wr.l - 1 and cr.l + cr.w <= wr.l + wr.w + 1, "inside the window (x)")
	ok(cr.b >= wr.b - 1 and cr.b + cr.h <= wr.b + wr.h + 1, "inside the window (y)")
	r:clickText("Next")
	w:advance(1)
	ok(has(r, "Tip 2 of 5", true), texts(r))
	-- closing the window: not "done"
	r.W.UI.Toggle(false)
	w:advance(1)
	ok(r.W.db.coach ~= true, "closing the window doesn't finish the tips")
	r.W.UI.Toggle(true)
	w:advance(3)
	ok(has(r, "Tip 2 of 5", true), "back where they were: " .. texts(r))
	-- another tab: hidden, not done
	r:clickText("Trips")
	w:advance(1)
	ok(not has(r, "Tip 2 of 5", true), "hidden on Trips")
	ok(r.W.db.coach ~= true, "still not done")
	r:clickText("Ride")
	w:advance(3)
	ok(has(r, "Tip 2 of 5", true), "back on Home: " .. texts(r))
	-- through to the end: Got it
	for i = 3, 5 do
		r:clickText("Next")
		w:advance(1)
		ok(has(r, "Tip " .. i .. " of 5", true), "tip " .. i .. ": " .. texts(r))
	end
	r:clickText("Got it")
	w:advance(1)
	eq(r.W.db.coach, true, "done on Got it")
	-- Settings > Riding > Tips > Replay (round 9, G1: one section at a time; the row lives in Riding, not This window)
	r.W.UI.OpenSettings("riding")
	w:advance(1)
	ok(has(r, "Replay", true), "the Settings row: " .. texts(r))
	r:clickText("Replay")
	w:advance(3)
	ok(has(r, "Tip 1 of 5", true), "replayed from the first: " .. texts(r))
	r:clickText("Skip tips")
	w:advance(1)
	eq(r.W.db.coach, true, "done on Skip")
	clean(w)
end)

---------------------------------------------------------------------------
-- openmap (#22): the hint stays until dismissed; the OpenMap row in Settings
---------------------------------------------------------------------------

test("r6 ui: openmap - the OpenMap hint stays across reloads until its x; Settings has the OpenMap row", function()
	local w = newWorld()
	local r = T.rider(w, T.TESTCHAR)
	-- (design 2) the hint is the last row of the drivers list: a driver is listed
	local d = T.driver(w, "Bob Stone")
	w:advance(15)
	T.goOnline(d)
	w:advance(5)
	r.W.db.coach = true
	r.W.UI.Toggle(true)
	w:advance(3)
	ok(has(r, "Get OpenMap to see drivers on your world map", true), "shown")
	local r2 = w:reload(r)
	w:advance(15)
	r2.W.UI.Toggle(true)
	w:advance(3)
	ok(has(r2, "Get OpenMap to see drivers on your world map", true), "still there after a reload (never dismissed)")
	r2.W.UI.OpenSettings("map") -- (round 9, G1: one section at a time)
	w:advance(1)
	ok(has(r2, "Best with OpenMap: not installed", true), "the Settings row: " .. texts(r2))
	r2.W.UI.CloseSettings(true)
	w:advance(1)
	r2:click(r2.W.UI.state.screens.home.mapHint.close)
	w:advance(1)
	ok(not has(r2, "Get OpenMap to see drivers on your world map", true), "dismissed")
	local r3 = w:reload(r2)
	w:advance(15)
	r3.W.UI.Toggle(true)
	w:advance(3)
	ok(not has(r3, "Get OpenMap to see drivers on your world map", true), "and gone for good")
	-- with OpenMap: the row says Installed
	local o = T.rider(w, "Map Fan", { openMap = { stitched = true } })
	w:advance(15)
	o.W.db.coach = true
	o.W.UI.Toggle(true)
	w:advance(2)
	o.W.UI.OpenSettings("map")
	w:advance(1)
	ok(has(o, "Best with OpenMap: installed", true), texts(o))
	clean(w)
end)

---------------------------------------------------------------------------
-- heatmap (#28): the in-game heatmap on Earnings
---------------------------------------------------------------------------

test("r6 ui: heatmap - Earnings draws a 7 x 24 grid from DR.Heatmap; a tap says that hour's numbers; no tools\\heatmap.cmd", function()
	local w = newWorld()
	local a = w:addClient(T.ANA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(15)
	local DR = a.W.Drive
	a.W.Char().wizard = true
	local asked
	DR.Heatmap = function(days, scope)
		asked = days
		local g = { max = 30000, days = days }
		for d = 0, 6 do
			g[d] = {}
			for h = 0, 23 do g[d][h] = { copper = 0, rides = 0, open = 0, asks = 0 } end
		end
		g[2][20] = { copper = 15000, rides = 2, open = 30, asks = 1, perHour = 30000 }
		g[5][9] = { copper = 0, rides = 0, open = 0, asks = 3 }
		return g
	end
	openTab(a)
	a.W.UI.ShowDrive("earnings")
	w:advance(1)
	local e = a.W.UI.drive.screens.earnings
	ok(not has(a, "heatmap.cmd", true), "no tool to run: " .. texts(a))
	ok(has(a, "Best hours, last 7 days", true), texts(a)) -- (round 7: the card's title; word rule: "Best hours, last N days")
	local hm = e.heat
	eq(#hm.cells, 168, "7 x 24 squares")
	ok(asked and asked >= 7, "at least a week asked: " .. tostring(asked))
	local tue8
	for _, b in ipairs(hm.cells) do if b.wday == 2 and b.hour == 20 then tue8 = b end end
	ok(tue8, "Tue 20:00")
	eq(hm.bestCell, tue8, "the brightest square")
	H.runScript(tue8, "OnClick", "LeftButton")
	-- (round 7: the pill as in the mockup, "Fri 20:00 · 4g/hr · ..."; round 13: "g/h", as the chart)
	-- folded, too long for one line: two even lines in a taller pill (never cut)
	eq((hm.info:GetText() or ""):gsub("\n", " · "), "Tue 20:00 · 3g/h · 2 rides · open 30 min · 1 rider asked", "the numbers")
	ok(has(a, "1 rider asked", false), "on screen: " .. texts(a))
	-- no data: the empty line
	DR.Heatmap = function() return nil end
	e.update()
	ok(has(a, "Open for a few hours and your best times light up here.", true), texts(a))
	clean(w)
end)

---------------------------------------------------------------------------
-- flight costs (Wuber): Confirm, the pay strip, Done, Trips; hidden without data
---------------------------------------------------------------------------

test("r6 ui: flight - Confirm says what flying costs against the summon (exact costs only, review 2.2 #10); nothing without data", function()
	local w = newWorld()
	local r = T.rider(w, T.TESTCHAR)
	w:advance(15)
	r.W.db.coach, r.W.db.tipPct = true, 0
	r.W.drivers = r.W.drivers or {}
	-- (round 13, I14) a place a flight goes from Orgrimmar: Undercity is by zeppelin (free, no flight)
	r.W.drivers[key(MIA)] = { name = MIA, key = key(MIA), dest = "Thunder Bluff", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = r.env.GetTime() }
	local cost, exact = 2300, 0
	r.W.FlightCost = function(from, to)
		eq(from, nil, "from where I stand")
		eq(to, "Thunder Bluff")
		return cost, exact
	end
	r.W.UI.Show("confirm", key(MIA))
	w:advance(2)
	ok(not has(r, "vs flying", true), "a cost no flight master showed: no line: " .. texts(r))
	ok(not has(r, "about 23s", true), "never 'about'")
	exact = 1
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(has(r, "Net " .. G("27" .. SI) .. " vs flying", true), "learnt: " .. texts(r))
	-- flying costs more than the fare: the summon saves
	cost = 6200
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(has(r, "Saves " .. G("12" .. SI) .. " vs flying", true), "saves: " .. texts(r))
	ok(not has(r, "Net -", true) and not has(r, "really costs -", true), "never negative")
	-- no data: no line
	cost = nil
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(not has(r, "vs flying", true), "hidden: " .. texts(r))
	r.W.FlightCost = nil
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(not has(r, "vs flying", true), "no engine: hidden")
	clean(w)
end)

test("r6 ui: flight - the pay strip, Found and Done use the ride's cost (fare + tip); Trips shows the lifetime", function()
	local w, r = riderWithRide("arrived", { flightCost = 2300, flightExact = 1 })
	r.W.FlightCost = function() return 9999, 1 end -- the ride's own cost wins
	r.W.db.tipPct = 20
	r.W.UI.Show("found")
	w:advance(2)
	-- fare 50s + 20% tip = 60s: 60 - 23 = 37
	ok(has(r, "Flying here costs " .. G("23" .. SI) .. " · this summon really costs " .. G("37" .. SI), true), "Found: " .. texts(r))
	-- the trade with the driver: the strip's line
	w:addBot(MIA, { spot = "Orgrimmar" })
	H.state[r.env.TradeFrame].shown = true
	r.W.ride.state = "paying"
	w:openTrade(w:player(MIA), r.player)
	w:advance(1)
	ok(#r:findText("^Wuber: Pay Bea") > 0, "the strip")
	ok(#r:findText("Flying here costs 23s · this summon really costs 37s", false, true) >= 1, "under the strip (the game world: plain s): " .. texts(r))
	w:tradeCancel(r.player)
	-- Done: what was paid
	r.W.ride.state, r.W.ride.paid = "done", 6000
	r.W.Fire("RIDE")
	r.W.UI.Show("done")
	w:advance(2)
	ok(has(r, "Flying: " .. G("23" .. SI) .. " · this summon really cost " .. G("37" .. SI), true), "Done: " .. texts(r))
	-- unpaid: no flight line
	r.W.ride.unpaid, r.W.ride.paid = true, nil
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(not has(r, "Flying", true), "unpaid: no flight line")
	-- Trips: the lifetime (the engine's W.Stats().flightSaved; exact costs only, never "about")
	statsOf(r, { flightSaved = 41200, flightAbout = true })
	r.W.UI.Dismiss(true)
	w:advance(1)
	r:clickText("Trips")
	w:advance(2)
	ok(has(r, "4g 12s saved vs flying", true), "Trips, the time-saved caption: " .. texts(r))
	eq(r.W.UI.TripsHabits()[4], "Saved 4g 12s of flight costs", "and the long line")
	ok(not has(r, "Saved about", true), "never 'about'")
	statsOf(r, { flightSaved = 0 })
	r.W.db.uiFlightSaved = nil
	r.W.UI.UpdateTrips()
	ok(not has(r, "saved vs flying", true), "none: hidden")
	clean(w)
end)

---------------------------------------------------------------------------
-- rrmentions (#4): the old addon is never named on screen
---------------------------------------------------------------------------

test("r6 ui: rrmentions - the retire card says 'Your old summoning addon is still on'; no UI file has a 'Ritual Rides' string", function()
	local files = {}
	for _, old in ipairs({ "Driver", "UI_Drive", "UI", "UI_Settings", "UI_Trips", "Theme", "FX", "Map", "Nameplates" }) do
		local src = H.F.sources(old) -- the old file, or the modules its code moved to (tests/lib/files.lua)
		ok(#src > 0, old .. "'s files in the TOC")
		for _, f in ipairs(src) do files[#files + 1] = f end
	end
	for _, f in ipairs(files) do
		local t = T.readFile(H.ADDONS.Wuber .. "/" .. f) or ""
		ok(not t:lower():find("ritual rides", 1, true), f .. " names it")
		for s in t:gmatch('"([^"\n]*)"') do
			ok(not s:lower():find("ritualrides", 1, true) or s == "RitualRides", f .. ": " .. s)
		end
	end
	-- the card itself, with the old addon still driving
	local w = newWorld()
	local a = w:addClient(T.ANA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(15)
	local DR = a.W.Drive
	DR.Lock = function() return "rr" end
	local db = DR.db or a.W.db.drive
	db.imported = db.imported or { at = 1 }
	openTab(a)
	ok(has(a, "Your old summoning addon is still on", true), "the card: " .. texts(a))
	ok(has(a, "Switch it off and reload", true), texts(a))
	ok(has(a, "Your old addon is driving", true), "the provider view: " .. texts(a))
	for _, t in ipairs(a:visibleTexts()) do ok(not t:lower():find("ritual rides", 1, true), "on screen: " .. t) end
	clean(w)
end)

test("r6 ui: wuberhint - bare 'wuber' in Trade is asked, never a buyer, shown only once the sender answers as a driver; tip toast once; editor line", function()
	local w = newWorld()
	local d = T.driver(w, "Bob Stone")
	local r = T.rider(w)
	w:splitChannel(d, "other")
	T.settle(w, 20)
	T.goOnline(d)
	w:advance(5)
	local function qs()
		local n = 0
		for _, e in ipairs(T.msgs(w, "Q", "Wuber TestCharacter", "WHISPER")) do
			if H.key(e.target) == "bob stone" then n = n + 1 end
		end
		return n
	end
	-- a non-driver saying wuber: asked, never shown, never a buyer
	-- (job 2884: a bare "wuber" is a mention now; mentions wait a minute after login and go 3-15 s later)
	w:advance(60)
	local q0 = qs()
	w:chatFrom("Some Body", "anyone use wuber? wts summons", "CHANNEL", "Trade")
	w:advance(8)
	eq(r.W.drivers["some body"], nil, "a non-driver is never listed")
	eq(r.W.net.advertsHeard, 0, "a hint is not a tagged advert")
	ok(not (r.W.queue and r.W.queue["some body"]), "never a buyer")
	-- the driver typed wuber himself: a Q goes out, he is listed only after his own D
	w:chatFrom("Bob Stone", "WTS summons, Wuber ok", "CHANNEL", "Trade")
	w:advance(1)
	eq(r.W.fallback.unconfirmed["bob stone"], nil, "a mention is not an unconfirmed advert name")
	w:advance(25)
	ok(qs() > q0, "a Q went to the hint sender")
	ok(r.W.drivers["bob stone"], "listed once his addon answered as a driver")
	-- tip toast: once per character
	local d2 = T.driver(w, "Cal Lock")
	T.settle(w, 5)
	local seen = catchToasts(d2)
	T.goOnline(d2)
	d2.W.Driver.SetOnline(false)
	T.goOnline(d2)
	local n = 0
	for _, t in ipairs(seen) do if t:find("put the word Wuber in any advert", 1, true) then n = n + 1 end end
	eq(n, 1, "the tip toast shows once: " .. list(seen))
	ok(d2.W.Char().advertTipShown, "flag stored")
	-- the editor line
	openTab(d, "Drive")
	d.W.UI.ShowDrive("messages", "advert")
	w:advance(1)
	ok(has(d, "Put Wuber in them", true), "editor line: " .. texts(d))
	clean(w)
end)

-- (round 20, B7) shot 14: the "60s" pay card is dimmed while the stranger warning shows (a shaded card that is
-- Shown/Hidden, as the real client draws it), and back to normal for the driver's own trade
test("r6 ui: tradecheck r20 B7 - the pay card is dimmed under a stranger's warning, not for the driver", function()
	local w, r = riderWithRide("arrived")
	r.W.UI.Toggle(true)
	w:advance(3)
	local pay = r.W.UI.state.screens.found.pay
	ok(pay and pay.dim, "the pay card has a dim layer")
	ok(not H.visible(pay.dim), "no trade: not dimmed")
	w:addBot(SLY, { spot = "Orgrimmar" })
	H.state[r.env.TradeFrame].shown = true
	ok(w:openTrade(w:player(SLY), r.player), "the stranger opens trade")
	w:advance(1.5)
	ok(has(r, "isn't your driver", true), "the warning shows: " .. texts(r))
	ok(H.visible(pay.dim), "the pay card is dimmed while the warning shows")
	local pr, dr = H.rect(pay), H.rect(pay.dim)
	ok(math.abs(pr.l - dr.l) < 1 and math.abs(pr.w - dr.w) < 1 and math.abs(pr.h - dr.h) < 1, "the dim covers the whole card")
	w:tradeCancel(r.player)
	w:advance(1.5)
	ok(not H.visible(pay.dim), "the stranger left: normal again")
	w:addBot(MIA, { spot = "Orgrimmar" })
	ok(w:openTrade(w:player(MIA), r.player), "Mia opens trade")
	w:advance(1.5)
	ok(not H.visible(pay.dim), "the driver's trade: the card is not dimmed")
	clean(w)
end)
