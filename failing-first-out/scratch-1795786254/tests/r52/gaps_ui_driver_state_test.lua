-- Final home: tests/ui/driver/state_test.lua; add it to the per-module list in tests/run.lua.
-- Pins:
--   the plain-words helpers: D.CrewShards, D.Fix, D.StationReady, D.AdvertWhy, D.OPEN_WHY, kit.plural
--   which Drive view shows: welcome, console, another addon driving (D.Role, D.Mode); helpers never pause
--   Close with riders still listed asks first (FAB-02): Cancel stays open, Yes closes; nobody listed closes at once
--   the shift card's numbers (D.ShiftEnded) and the payee name hidden when it is me (D.PayeeName)
-- Why it matters to a player: a misclick on Close must not drop riders who are waiting on you; a crew
--   helper must not see "Paused" while the Warlocks still sell; the advert pill must say why it can't post.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local ANA, DAN = "Ana Smith", "Dan Miller"
local CLOSE_ASK = "WUBER_CLOSE_RIDERS" -- State.lua:293

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- a solo Warlock driver in Undercity, open, Dan queued (not invited)
local function openWithDan()
	local w = H.NewWorld({})
	local a = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK", shards = 10 })
	w:addBot(DAN, { spot = "Ratchet", acceptsInvites = false })
	w:advance(15)
	local DR = a.W.Drive
	a.W.Char().wizard = true
	DR.opts().autoInvite = false
	ok(DR.SetOpen(true), "open")
	w:advance(3)
	return w, a, DR
end

-- guard: coverage, fable-2411 draft adopted in r52
test("UI.Driver.State: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("UI.Driver.State", "tests/ui/driver/state_test.lua", {
		["D.screens"] = "table", ["D.kit"] = "table", ["D.FOLD"] = "table", ["D.wide"] = "table", ["D.OPEN_WHY"] = "table",
		["D.Wide"] = "function", ["D.CrewCount"] = "function", ["D.Fix"] = "function", ["D.Today"] = "function",
		["D.Stations"] = "function", ["D.StationReady"] = "function", ["D.PayeeName"] = "function", ["D.Role"] = "function",
		["D.Mode"] = "function", ["D.ShiftEnded"] = "function", ["D.SetOnline"] = "function", ["D.CanPause"] = "function",
		["D.SetPaused"] = "function", ["D.AdvertPlan"] = "function", ["D.AdvertWhy"] = "function", ["D.AdvertTarget"] = "function",
		["D.AdvertClicked"] = "function", ["D.PaintAdvert"] = "function", ["D.CrewShards"] = "function",
		["Mod.MAX_ROWS"] = "number", ["Mod.plural"] = "function", ["Mod.Price"] = "function",
	})
	eq(Mod.MAX_ROWS, 8) -- State.lua:65
	eq(W.Driver.Wide("console") == true or W.Driver.Wide("console") == false, true, "Wide answers a boolean")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.state: the plain-words helpers: crew shards, fixes, stations, advert reasons, plurals", function()
	local W, w, r, Mod = T.contract("UI.Driver.State", "tests/ui/driver/state_test.lua", {})
	local D = W.Driver
	-- the crew header's count: Warlocks with Wuber and a known count only (round 13, I10)
	eq(D.CrewShards(nil), nil) eq(D.CrewShards({}), nil, "none known: nil, not 0")
	eq(D.CrewShards({
		{ role = "lock", app = true, shards = 5 }, { role = "lock", app = false, shards = 9 },
		{ role = "helper", shards = 3 }, { role = "lock", shards = -1 }, { role = "lock", shards = 2.7 }, "junk",
	}), 7, "5 + 2 (floored); no plain Warlock, helper or unknown count") -- State.lua:177-184
	-- a Readiness fix: named or listed, else nothing
	local run = function() end
	eq(D.Fix(nil), nil) eq(D.Fix({ label = "Set a place" }), nil, "no run: no pill")
	local f = D.Fix({ label = "Set a place", run = run, tip = "Where you summon to" })
	eq(f and f.label, "Set a place") eq(f and f.tip, "Where you summon to") ok(f and f.run == run)
	f = D.Fix({ "Pick a summoner", run })
	eq(f and f.label, "Pick a summoner", "the listed form")
	-- a station is ready with a summoner and two others
	eq(D.StationReady(nil), false)
	eq(D.StationReady({ ready = false, summoners = { 1, 2, 3 } }), false, "the engine's word wins")
	eq(D.StationReady({ ready = true }), true)
	eq(D.StationReady({ summoners = { "a" }, helpers = { "b", "c" } }), true)
	eq(D.StationReady({ summoners = { "a", "b" } }), false, "two are not enough")
	eq(D.StationReady({ summoners = {}, helpers = { "a", "b", "c" } }), false, "no summoner")
	-- why the advert can't go, in plain words
	eq(D.AdvertWhy("wait", 61), "You can advertise again in 2 min", "minutes rounded up") -- State.lua:384-387
	eq(D.AdvertWhy("wait", 10), "You can advertise again in 1 min", "never 0 min")
	eq(D.AdvertWhy("digits"), "Your advert line was refused by the spam check. Change it in Messages.")
	eq(D.AdvertWhy("combat"), "Not in combat") eq(D.AdvertWhy("channel"), "Join Trade or General first")
	eq(D.AdvertWhy("text"), "Couldn't make the advert") eq(D.AdvertWhy(nil), "Couldn't post the advert")
	eq(D.OPEN_WHY.summoner, "Choose who summons first: a Warlock has to cast")
	eq(D.OPEN_WHY.rr, "Your old summoning addon is still on")
	eq(Mod.plural(1, "ride"), "1 ride") eq(Mod.plural(2, "ride"), "2 rides") eq(Mod.plural(0, "rider"), "0 riders")
	eq(Mod.plural(3, "person", "people"), "3 people")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.state: which Drive view: the welcome, the console for a helper, another addon; helpers never pause", function()
	local W, w = T.contract("UI.Driver.State", "tests/ui/driver/state_test.lua", {})
	local D, DR = W.Driver, W.Drive
	eq(D.Role(), nil, "a Mage rider") eq(D.Mode(), "welcome", "any class sees the welcome first") -- State.lua:262
	eq(D.CanPause(), true)
	-- in someone's crew: the console, no pause
	DR.char().captain = ANA
	eq(D.Role(), "helper") eq(D.Mode(), "console") -- State.lua:260
	eq(D.CanPause(), false, "a helper's pause would show Paused while the Warlocks sell") -- State.lua:353
	eq(D.SetPaused(true), false, "refused")
	eq(DR.char().paused, false, "nothing paused")
	DR.char().captain = ""
	-- a third-party addon drives
	W.provider = { name = "Other Rides" }
	eq(D.Mode(), "provider") -- State.lua:257
	eq(D.SetOnline(true), false, "never opens while another addon drives") -- State.lua:325
	W.provider = nil
	eq(D.Mode(), "welcome")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.state: a Warlock who never set up driving sees the welcome; set up, the console", function()
	local w = H.NewWorld({})
	local a = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(3)
	local D = a.W.Driver
	eq(D.Role(), "driver")
	eq(a.W.Char().wizard, false, "a new Warlock")
	eq(D.Mode(), "welcome", "Advanced, no wizard, closed, nobody queued, no crew") -- State.lua:265
	a.W.Char().wizard = true
	eq(D.Mode(), "console")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.state: Close with a rider listed asks first: Cancel stays open, Yes closes (FAB-02)", function()
	local w, a, DR = openWithDan()
	local D = a.W.Driver
	w:botWhisper(DAN, a, "summon pls")
	w:advance(1)
	ok(DR.customers[key(DAN)], "Dan is queued")
	eq(D.SetOnline(false), false, "the close waits for the answer") -- State.lua:311-317
	ok(a.env.StaticPopup_FindVisible(CLOSE_ASK), "the question is on screen")
	local dlg = a.env.StaticPopupDialogs[CLOSE_ASK]
	eq(dlg.text, "1 rider is still with you. Close anyway?")
	eq(dlg.button1, "Yes") eq(dlg.button2, "Cancel")
	eq(DR.IsOpen(), true, "still open while asked")
	-- Cancel
	a.env.StaticPopup_Hide(CLOSE_ASK)
	dlg.OnCancel()
	w:advance(1)
	eq(DR.IsOpen(), true, "Cancel: still open")
	ok(DR.customers[key(DAN)], "and Dan is still listed")
	-- Yes
	eq(D.SetOnline(false), false)
	dlg = a.env.StaticPopupDialogs[CLOSE_ASK]
	a.env.StaticPopup_Hide(CLOSE_ASK)
	dlg.OnAccept()
	w:advance(1)
	eq(DR.IsOpen(), false, "Yes: closed")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.state: Close with nobody listed closes at once, no question", function()
	local w, a, DR = openWithDan()
	local D = a.W.Driver
	eq(D.SetOnline(false), true)
	ok(not a.env.StaticPopup_FindVisible(CLOSE_ASK), "no question")
	eq(DR.IsOpen(), false)
	eq(a.W.Char().drive, false, "saved closed")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.driver.state: the shift card's numbers; no ride, no card; the payee is not named when it is me", function()
	local w, a, DR = openWithDan()
	local D = a.W.Driver
	eq(D.ShiftEnded(nil), nil) eq(D.ShiftEnded({ rides = 0, crewRides = 0, copper = 500 }), nil, "no ride: no card") -- State.lua:280
	local s = D.ShiftEnded({ rides = 2, copper = 10000, tips = 500, crewRides = 1, crewCopper = 5000 })
	ok(s, "a card")
	eq(s and s.rides, 2) eq(s and s.copper, 10000) eq(s and s.tips, 500)
	eq(s and s.crewRides, 1) eq(s and s.crewCopper, 5000)
	ok(D.lastShift == s, "kept for the shift sheet")
	-- a solo Warlock is paid herself: no "pay X" name on the row
	eq(D.PayeeName(nil), nil)
	eq(D.PayeeName({ name = DAN }), nil, "the payee is me") -- State.lua:244-245
	T.clean(w)
end)
