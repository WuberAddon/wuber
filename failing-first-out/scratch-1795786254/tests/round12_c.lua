-- Round 12 (Wuber 2.3.x fix round, TEST-FINDINGS-1119), agent C (rider): items 5, 8 and 9.
-- Test names start "r12 c:". Loaded by run.lua with the module tests' helpers.
--   5. The Confirm dial: the verdict, the line under it and the knob agree (the author's screenshot:
--      "Fly about 5 min / Summon ~2 min · 55s" said "Flying wins / 3 min faster").
--   8. The Fold never changes the window's scale (lab pb_fold on a 4K window: 1.00 -> 1.15).
--   9. The side pane's map: World first, Here one click away, the player's last choice remembered.

local T = ...
local SI = "s" -- (design 1 H: money is letters, "23s", no coin icons)
local function G(s) return "|cfff9c53e" .. s .. "|r" end -- (design 1 P) an amount beside a time is gold letters
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list
local newWorld, clean = T.newWorld, T.clean

local MIA = "Mia Runner"
local function texts(c) return list(c:visibleTexts(), " | ") end

-- a rider with one open driver to Undercity (50s, empty queue: the summon takes about 2 min),
-- a 10% tip (55s in all, as Wuber's), flying `fly` seconds, the flight's price `cost` (nil: unknown)
local function riderWorld(fly, cost)
	local w = newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local t0 = r.env.GetTime()
	r.W.drivers = r.W.drivers or {}
	r.W.drivers["mia runner"] = { name = MIA, key = "mia runner", dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = t0, queue = 0, ver = "2.3.0" }
	r.W.FlightCost = function() if cost then return cost, 1 end return nil end
	r.W.TravelSaved = function() return fly end
	r.W.db.tipPct = 10
	r.W.db.fold = { v = 1, pages = {}, narrow = true }
	return w, r
end

local function show(w, r, screen, key)
	r.W.UI.Toggle(true)
	w:advance(3)
	r.W.UI.Show(screen, key)
	w:advance(1.5)
	return r.W.UI.state.screens[screen]
end

---------------------------------------------------------------------------
-- 5. The Confirm dial
---------------------------------------------------------------------------

local function dialOf(fly, cost)
	local w, r = riderWorld(fly, cost)
	local s = show(w, r, "confirm", "mia runner")
	ok(H.visible(s.dial), "the dial: " .. texts(r))
	return w, r, s.dial
end

test("r12 c: confirm dial - the author's 19 Nov state (fly about 5 min, summon ~2 min, 55s): verdict, line and knob agree", function()
	-- 280 s flying less the 2 min wait = 160 s saved ("3 min"); at 10g an hour that is worth about 44s,
	-- r50 AU24-18: a worked-out flight time says about
	-- less than the 55s fare: flying is the better deal, by a little
	local w, r, dial = dialOf(280, nil)
	eq(dial.summonText.wuberText, "30 sec · costing " .. G("55" .. SI), "the summon side (19 Nov screenshot said ~2 min; a ready driver is now W.SUMMON_SECS)")
	eq(dial.flyText.wuberText, "about 5 min", "the fly side as on the screenshot")
	eq(dial.verdict.wuberText, "Summon wins by about 4 min", "the verdict (a ready driver now takes 30 s, not 2 min)")
	ok(dial.p > 0.5, "the knob leans to Summon: " .. tostring(dial.p))
	-- the line under it must not read as if flying were the faster one
	ok(dial.line.wuberText:sub(1, #"about 4 min faster") == "about 4 min faster", "the line under the verdict: " .. tostring(dial.line.wuberText))
	clean(w)
end)

test("r12 c: confirm dial - summon wins: the headline's time and the line's agree, the knob leans to Summon", function()
	-- 600 s flying - 120 s wait = 8 min saved, worth about 1g 33s: more than the 55s fare
	local w, r, dial = dialOf(600, nil)
	eq(dial.verdict.wuberText, "Summon wins by about 10 min", "the verdict")
	ok(dial.p > 0.5, "the knob leans to Summon: " .. tostring(dial.p))
	ok(dial.line.wuberText:sub(1, #"about 10 min faster") == "about 10 min faster", "the line starts with the verdict's time: " .. tostring(dial.line.wuberText))
	clean(w)
end)

test("r12 c: confirm dial - about the same: the knob in the middle, the line names the summon", function()
	-- 300 s - 120 s = 3 min, worth 50s against 55s: within 10s
	local w, r, dial = dialOf(210, nil)
	eq(dial.verdict.wuberText, "About the same", "the verdict")
	ok(dial.p > 0.4 and dial.p < 0.6, "the knob near the middle: " .. tostring(dial.p))
	eq(dial.line.wuberText, "Summon is about 3 min faster", "the line")
	clean(w)
end)

test("r12 c: confirm dial - flying wins with a known flight price: cheaper and slower, the line from the summon's side", function()
	-- 190 s - 120 s = 70 s ("1 min"), worth about 19s; the summon costs 32s more than the 23s flight
	local w, r, dial = dialOf(100, 2300)
	eq(dial.verdict.wuberText, "Flying is 32s cheaper, about 1 min slower", "the verdict (plain money, BRIEF22 C1)")
	ok(dial.p < 0.5, "the knob leans to Fly: " .. tostring(dial.p))
	eq(dial.line.wuberText, "Summon is about 1 min faster · Net " .. G("32" .. SI) .. " vs flying", "the line")
	clean(w)
end)

---------------------------------------------------------------------------
-- 8. The Fold never changes the window's scale
---------------------------------------------------------------------------

test("r12 c: fold on a 4K-like screen - the window has its scale from login; opening, Settings and folding never SetScale", function()
	local w = newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 2560, screenH = 1440 })
	r.wide = true -- (the harness keeps old tests folded; this one asks for room)
	T.settle(w)
	local W, UI = r.W, r.W.UI
	W.db.coach = true
	local win = r.env.WuberFrame
	ok(win, "the window is built at login")
	local want = UI.WantedScale()
	ok(math.abs(want - UI.DEFAULT_SCALE) < 0.001, "room for the usual 1.15 here: " .. tostring(want))
	-- the lab's pb_fold reads the scale before the window first opens (the author's Anita: 1.00, then 1.15)
	ok(math.abs((win:GetScale() or 0) - want) < 0.001, "the scale before the first open: " .. tostring(win:GetScale()))
	local calls = {}
	local set = win.SetScale
	win.SetScale = function(self, s, ...)
		calls[#calls + 1] = tostring(s)
		return set(self, s, ...)
	end
	UI.Toggle(true)
	w:advance(3)
	UI.OpenSettings()
	w:advance(1)
	eq(UI.Fold.Page(), "settings", "the Settings page")
	local fits, why = UI.Fold.Fits()
	eq(win:GetWidth(), 720, "Settings unfolds: " .. tostring(fits) .. " " .. tostring(why) .. " " .. tostring(UI.Fold.IsUnfolded()))
	UI.Fold.Toggle() w:advance(1)
	eq(win:GetWidth(), 360, "folded")
	UI.Fold.Toggle() w:advance(1)
	eq(win:GetWidth(), 720, "unfolded again")
	-- a setting changes while the window is open (SETTINGS re-applies the scale)
	W.Fire("SETTINGS", "sound")
	r:fire("UI_SCALE_CHANGED")
	r:fire("DISPLAY_SIZE_CHANGED")
	w:advance(1)
	eq(#calls, 0, "SetScale calls while opening and folding: " .. table.concat(calls, ", "))
	ok(math.abs(win:GetScale() - want) < 0.001, "the scale kept: " .. tostring(win:GetScale()))
	-- the Window size slider still changes it (once)
	W.db.scale = 1.3
	UI.ApplyScale()
	w:advance(1)
	eq(table.concat(calls, ", "), "1.3", "the slider's new size")
	clean(w)
end)

---------------------------------------------------------------------------
-- 9. The side pane's map: World first, the player's last choice remembered
---------------------------------------------------------------------------

local function wideRider()
	local w = newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 2560, screenH = 1440 })
	r.wide = true
	T.settle(w)
	local W = r.W
	W.db.coach = true
	W.drivers = W.drivers or {}
	W.drivers["mia runner"] = { name = MIA, key = "mia runner", dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = r.env.GetTime(), queue = 0, ver = "2.3.0" }
	W.FlightCost = function() return nil end -- (no crossing known: before, Confirm opened on Here)
	return w, r, W, W.UI, W.Mod("UI.Rider.WorldMap")
end

local function paneMap(Map) return Map.cache.last end

test("r12 c: map view - World first on the unfolded Ride and Confirm; Here one click away; the choice is remembered", function()
	local w, r, W, UI, Map = wideRider()
	UI.Toggle(true)
	w:advance(3)
	eq(UI.Fold.Page(), "ride", "the Ride page")
	ok(UI.Fold.IsUnfolded(), "unfolded")
	local ride = paneMap(Map)
	eq(ride and ride.mode, "world", "Ride opens on World")
	eq(ride.seg.value, "world", "the control shows World chosen")
	ok(H.visible(ride.view), "the world view shows")
	eq(W.db.mapView, nil, "nothing saved until the player picks")
	UI.Show("confirm", "mia runner")
	w:advance(1.5)
	eq(UI.Fold.Page(), "confirm", "the Confirm page")
	local conf = paneMap(Map)
	ok(conf ~= ride, "Confirm's own pane")
	eq(conf.mode, "world", "Confirm opens on World too")
	-- the player picks Here: remembered (per account) and used on both pages
	conf.seg.buttons[1]:Click()
	w:advance(0.5)
	eq(conf.mode, "here", "Here is one click away")
	eq(W.db.mapView, "here", "the choice is saved")
	UI.Show("home")
	w:advance(1.5)
	eq(UI.Fold.Page(), "ride", "back on Ride")
	eq(ride.mode, "here", "Ride follows the choice")
	-- fold and unfold again: still Here
	UI.Fold.Toggle() w:advance(1)
	UI.Fold.Toggle() w:advance(1)
	ok(UI.Fold.IsUnfolded(), "unfolded again")
	eq(ride.mode, "here", "still Here after folding")
	UI.Show("confirm", "mia runner")
	w:advance(1.5)
	eq(conf.mode, "here", "Confirm remembers Here")
	-- and back to World
	conf.seg.buttons[2]:Click()
	w:advance(0.5)
	eq(W.db.mapView, "world", "World saved")
	UI.Show("home")
	w:advance(1.5)
	eq(ride.mode, "world", "Ride on World again")
	clean(w)
end)
