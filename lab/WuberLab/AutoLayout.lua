-- Wuber Lab (developer only, never ship): AutoLayout.lua, the first half of the Auto check's rows for the screens the layout
-- check (tools/layout-check.lua) draws that the photo tour and AutoSteps*.lua did not: the extra tour screens of
-- tests/layout/extra_screens.lua (tipcard ... inflight) and of f3_e, dec_q, d4_h and d4_c _screens.lua. AutoLayout2.lua has the
-- rest (sheet_states, f3_j, dec_n, dec_r, rem, d4_d, and pay_part last). Same ids, sides, views and titles as the layout check's,
-- and the same run / post / ready / wait / maxWait logic, so a screen has one look in both checks. lab/AUTO-COVERAGE.md has the table;
-- tests/lessons/l26_lab_auto_coverage_test.lua keeps the two lists in step.
--
-- What differs from the layout check's copies (it runs in the fake game and has W in hand when it installs them):
--   * the base screen of a row (confirm, home, console_open ...) is looked up in L.PHOTO_SCREENS when the row runs;
--   * a Wuber module a row shows is checked in its need(W): a Wuber that lacks it leaves the row out, one log line, never an error
--     (s.declares: the words that reason starts with; the test lets a row skip only for the reason it declares);
--   * every demo value goes through the tour's shot stubs (P.shotStub: L.PhotoReset puts it back before the next screen), and
--     whatever else a row changes is put back by a function it hands to KIT.undo (run by L.PhotoReset, before every screen and
--     at the end of the tour; the tour never calls a row's hide, so hide is the same function for a reader's sake);
--   * nothing here is fake-game only: no c.env, w:advance, H.* or X.stubWorld (the World map stubs are for the fake game).
-- The only clicks are a named, local, insecure OnClick through X.press (the Back chevron, "Check my game", the Undo toast); nothing
-- sends, invites, whispers, trades or summons (the tour has every sender stubbed), no secure frame is touched, no protected call made.
-- Rows the layout check has that stay by hand (login_paused, login_drive) are in L.AUTO_MANUAL, with the reason.
--
-- Needs a full game restart (new files).

local _, L = ...

local K, P, X = L.PhotoKit, L.PhotoShotKit, L.AutoKit
local fn = K.fn
local mod, shotStub = P.mod, P.shotStub

local SCREENS = L.AUTO_SCREENS
-- s.declares: the words a skip of this row may start with (a string or a list): the test lets a row skip only for a reason it declares
local function screen(s)
	s.auto = true
	local d = type(s.declares) == "table" and s.declares or (s.declares and { s.declares } or {})
	if s.need then d[#d + 1] = "this Wuber has no" end -- (a need that says no, never an error)
	s.declares = d
	SCREENS[#SCREENS + 1] = s
	return s
end
local NO_UNFOLD = "doesn't unfold here" -- the tour's own words for a page Wuber's Fold has no wide form of (the layout check notes the same)

local function tourScreen(id)
	for _, s in ipairs(L.PHOTO_SCREENS or {}) do if s.id == id then return s end end
	return nil
end
-- the tour's own set-up of one of its screens (looked up when it runs)
local function runOf(id)
	return function(W, view)
		local s = tourScreen(id)
		if not (s and type(s.run) == "function") then return "the tour has no screen " .. id end
		return s.run(W, view)
	end
end
-- the tour screen's own ready / post / afterShot / check, looked up when it is called (a screen without one: ready and post say yes)
local function hookOf(id, key)
	return function(...)
		local s = tourScreen(id)
		local f = s and s[key]
		if type(f) == "function" then return f(...) end
		if key == "ready" or key == "post" then return true end
		return nil
	end
end
-- ... only when the tour screen has one now (a row without a post is settled once, as the layout check's is)
local function hookIf(id, key)
	local s = tourScreen(id)
	if s and type(s[key]) == "function" then return hookOf(id, key) end
	return nil
end
local function timing(id)
	local s = tourScreen(id)
	return s and s.wait or nil, s and s.maxWait or nil
end

-- Meant to be so (not findings), the same cases and reasons as tests/layout/allow.lua; each is for one row only
do
	local ALLOW = L.AUTO_ALLOW
	local function allow(kind, screen, text, reason) ALLOW[#ALLOW + 1] = { kind = kind, screen = screen, text = text, reason = reason } end
	allow("cut", "^tip_whole", '^"Aaaaaaaaaaaaaaa%-Bbbbbbbbbbbbbbbbbbb"', "the scene gives one rider a name too long for its place on purpose, to show the hover tip carrying the name whole")
	allow("under", "^finding_grouped", "route", "Waiting for the driver: the route header sits at the radar's top left corner on purpose")
	allow("under", "^confirm_dial_low", "destPin", "Confirm, the destination far to the top right of the map strip: the destination pin is part of the map the window's buttons lie on")
	allow("under", "^raid", 'half under .-"%+%d+ more below"', "the raid page's scroll hint pill sits over the list's bottom edge on purpose (Raid.lua updateCue); the rows it covers are faded, the texts just past the view edge only touch it by a few pixels")
	-- (worldmap_sea: tests/layout/allow.lua allows price tags beside pins, cut pin counts at the map edge and a tag over its
	-- own pin. No allow here yet: in the fake game the row reports none of them, and an allow for the whole row would hide
	-- real findings. Add one, scoped to its text, only when an in-game run reports it.)
end

local function haveMods(W, ...)
	for _, name in ipairs({ ... }) do if not mod(W, name) then return false end end
	return true
end
local function haveTour(...)
	for _, id in ipairs({ ... }) do if not tourScreen(id) then return false end end
	return true
end
-- need(W): true, or why the row is left out (the words start "this Wuber has no")
local function gate(what, test)
	return function(W)
		local ok, r = pcall(test, W)
		if ok and r then return true end
		return "this Wuber has no " .. what
	end
end

-- What a row changed outside the tour's stubs, put back by L.PhotoReset (before every screen and at the end of the tour)
local UNDO = {}
local function undo(f) UNDO[#UNDO + 1] = f end
do
	local base = L.PhotoReset
	L.PhotoReset = function(W, ...)
		local list = UNDO
		UNDO = {}
		for i = #list, 1, -1 do pcall(list[i], W) end
		if base then return pcall(base, W, ...) end
	end
end

-- the tour's first record of a name (before the quiet tour or the Auto check stubbed it): the real UI.Toast
local function realOf(tbl, key)
	local t = K.tour()
	for _, s in ipairs(t and t.saved or {}) do
		if s[1] == tbl and s[2] == key then
			local v = s[3]
			if type(v) == "function" then return v end
			return nil
		end
	end
	return tbl[key]
end

-- Rows the layout check has that cannot run in the real game: a screen id and why. The test insists on a reason for each.
local MANUAL = L.AUTO_MANUAL or {}
L.AUTO_MANUAL = MANUAL
MANUAL.login_paused = "The layout check starts a new game window whose font arrives 25 s after login and looks at the Paused bar of the floating Drive bar at that moment. "
	.. "The Auto check runs in a game that has been up for a while (the font is long loaded), so it cannot make that moment. a_font (AutoSteps2.lua: the font files, "
	.. "Wuber's widths) and a_ruler (AutoSteps6.lua: real text widths and cuts) look at the font once it is there, not at the seconds before it arrives. "
	.. "Stays a hand step: log in fresh, open nothing, set the Drive bar to Open then Paused, and watch it until the font arrives."
MANUAL.login_drive = "The layout check opens the window on the Drive tab while the font is still loading and looks again when it arrives (25 s after login). "
	.. "The Auto check runs in a game that has been up for a while, so the loading moment cannot be made again; a_font and a_ruler (see login_paused) only see the finished font. "
	.. "Stays a hand step: log in fresh, open Wuber on the Drive tab at once, and watch the page until the font arrives."

L.AutoLayoutKit = { NO_UNFOLD = NO_UNFOLD, screen = screen, tourScreen = tourScreen, runOf = runOf, hookOf = hookOf, hookIf = hookIf, timing = timing,
	haveMods = haveMods, haveTour = haveTour, gate = gate, undo = undo, realOf = realOf }

---------------------------------------------------------------------------
-- Helpers of the rows
---------------------------------------------------------------------------

local function homeWith(W)
	W.db.coach = true
	local Coach = mod(W, "UI.Coach") -- the first-open marks may be up already; tips start once they are done
	if Coach and type(Coach.stopCoachForNow) == "function" then Coach.stopCoachForNow() end
	W.UI.Show("home")
	return true
end

local function refreshUI(w)
	if type(w.UI.RefreshNow) == "function" then w.UI.RefreshNow() end
end

-- (round 37, REV-r37-2) what the booking card's map strip draws for the route, in the strip's own units (x right, y down
-- from its top): the sheet's top (s.cardTop), the route header's box, the destination pin's, the you dot's, the driver
-- pins' and the route's two ends (ends: { from = {x, y}, to = {x, y} } as fractions, from W.Map.RouteOnPanel's calls)
local function shown(f) return f and f.IsVisible and f:IsVisible() end
local function stripBox(m, f)
	if not (shown(m) and shown(f)) then return nil end
	local me, fe = m:GetEffectiveScale(), f:GetEffectiveScale()
	local ml, mt, fl, ft = m:GetLeft(), m:GetTop(), f:GetLeft(), f:GetTop()
	if not (ml and mt and fl and ft) then return nil end
	local l, t = (fl * fe - ml * me) / me, (mt * me - ft * fe) / me
	local w, h = f:GetWidth() * fe / me, f:GetHeight() * fe / me
	return { l = l, r = l + w, t = t, b = t + h }
end
local function stripBoxes(s, ends)
	local m = s.map
	local out = { cardTop = s.cardTop, header = stripBox(m, s.route), pin = stripBox(m, m.destPin), you = stripBox(m, m.me), drivers = {} }
	for _, p in ipairs(m.pins or {}) do
		local b = stripBox(m, p)
		if b then out.drivers[#out.drivers + 1] = b end
	end
	if ends and ends.from and ends.to then
		local w, h = m.mapW or m:GetWidth(), m.mapH or m:GetHeight()
		out.from = { x = ends.from[1] * w, y = ends.from[2] * h }
		out.to = { x = ends.to[1] * w, y = ends.to[2] * h }
	end
	return out
end
local function fmtBox(b) return b and string.format("x %d..%d y %d..%d", math.floor(b.l + 0.5), math.floor(b.r + 0.5), math.floor(b.t + 0.5), math.floor(b.b + 0.5)) or "none" end
local function stripText(o)
	local t = { "sheet top " .. tostring(o.cardTop), "header " .. fmtBox(o.header), "pin " .. fmtBox(o.pin), "you " .. fmtBox(o.you) }
	for i, d in ipairs(o.drivers) do t[#t + 1] = "driver pin " .. i .. " " .. fmtBox(d) end
	if o.from then t[#t + 1] = string.format("route (%d,%d) to (%d,%d)", math.floor(o.from.x + 0.5), math.floor(o.from.y + 0.5), math.floor(o.to.x + 0.5), math.floor(o.to.y + 0.5)) end
	return table.concat(t, "; ")
end
-- the problems: anything of the route under the sheet (y below its top) or in the header's box (1 px of rounding)
local function stripProblems(o)
	local bad, top, hd = {}, o.cardTop or 168, o.header
	local function inHeader(b) return hd and b.l < hd.r - 1 and b.r > hd.l + 1 and b.t < hd.b - 1 and b.b > hd.t + 1 end
	local function point(name, p)
		if not p then return end
		if p.y > top + 1 then bad[#bad + 1] = name .. " at y " .. math.floor(p.y + 0.5) .. " is under the sheet (top " .. top .. ")" end
		if hd and p.x > hd.l + 1 and p.x < hd.r - 1 and p.y > hd.t + 1 and p.y < hd.b - 1 then bad[#bad + 1] = name .. " is in the route header" end
	end
	local function box(name, b)
		if not b then return end
		if b.b > top + 1 then bad[#bad + 1] = name .. " (" .. fmtBox(b) .. ") goes under the sheet (top " .. top .. ")" end
		if inHeader(b) then bad[#bad + 1] = name .. " (" .. fmtBox(b) .. ") is in the route header (" .. fmtBox(hd) .. ")" end
	end
	box("the destination pin", o.pin)
	box("the you dot", o.you)
	for i, d in ipairs(o.drivers) do if inHeader(d) then bad[#bad + 1] = "driver pin " .. i .. " is in the route header" end end
	point("the route's start", o.from)
	point("the route's end", o.to)
	return bad
end

-- the strip drawn again with the route's ends recorded (W.Map.RouteOnPanel is put back at once): true, or the problems.
-- Folded only: unfolded the map is docked beside the sheet (nothing covers it)
local function stripCheck(w, s, what)
	if not (s and s.map) then return what .. ": no booking card" end
	if s.wide then return true end
	local Map, ends = w.Map, nil
	local route = type(Map) == "table" and Map.RouteOnPanel
	if type(route) == "function" and s.map:IsVisible() then
		local HM = mod(w, "UI.Rider.HomeMap")
		Map.RouteOnPanel = function(m, a, b, o)
			if m == s.map and a then ends = { from = a, to = b } end
			return route(m, a, b, o)
		end
		local ok = HM and pcall(HM.updateMap, s.map, w.UI.Drivers())
		Map.RouteOnPanel = route
		if not ok then return what .. ": the map strip could not be drawn" end
	end
	local o = stripBoxes(s, ends)
	local bad = stripProblems(o)
	if #bad > 0 then return what .. ": " .. table.concat(bad, "; ") .. " [" .. stripText(o) .. "]" end
	return true
end

local function confirmSide(w)
	local C = mod(w, "UI.Rider.Confirm")
	return C and type(C.side) == "table" and C.side.conf or nil
end

---------------------------------------------------------------------------
-- tests/layout/extra_screens.lua, in its order
---------------------------------------------------------------------------

-- the login tip card with the longest tip text
screen({ id = "tipcard", side = "rider", unfold = true,
	title = "Login tip card: the longest tip, in the phone",
	need = gate("login tips (UI.Tips)", function(W) local T = mod(W, "UI.Tips") return T and type(T.ShowNow) == "function" end),
	run = function(w)
		homeWith(w)
		local Tips = mod(w, "UI.Tips")
		local TT = mod(w, "UI.TipTexts")
		local id
		if type(Tips.Longest) == "function" then
			local t = Tips.Longest()
			id = t and t.id
		end
		if not id then
			local best = ""
			for k, v in pairs(TT and type(TT.list) == "table" and TT.list or {}) do
				local s = type(v) == "string" and v or (type(v) == "table" and (v.text or v.body or v.msg or v[1])) or nil
				if type(s) == "string" and #s > #best then best, id = s, (type(v) == "table" and v.id) or k end
			end
		end
		w.db.tipsOn = true
		w.db.tipsSeen = {}
		local shownOk, why = Tips.ShowNow(id)
		if not shownOk then return "the tip card did not show: " .. tostring(why) end
		return true
	end })

-- the World view with both continents, price-tag pins and a sea route with the zeppelin arrow (the fake game's map calibration
-- stubs, X.stubWorld, are for the fake game only: not ported)
screen({ id = "worldmap_sea", side = "rider", only = "unfolded",
	title = "World view: both continents, price-tag pins, a sea route with the zeppelin arrow",
	need = gate("World view or sea route (UI.Rider.WorldMap, UI.Rider.SeaRoute)", function(W)
		local WM = mod(W, "UI.Rider.WorldMap")
		return WM and type(WM.Show) == "function" and mod(W, "UI.Rider.SeaRoute")
	end),
	run = function(w) return homeWith(w) end,
	post = function(w)
		local WM = mod(w, "UI.Rider.WorldMap")
		-- a Horde crossing (Orgrimmar to Undercity: flight, then the zeppelin) so the cut-edge arrow is drawn
		if not WM.Show("world", { route = { from = "Orgrimmar", to = "Undercity" } }) then return "the World view isn't built" end
		-- the shot must really show the arrow, or the check says so (a silent miss would cover nothing)
		local last = WM.cache and WM.cache.last
		if not (last and last.seaArrow) then return "the sea route drew no zeppelin arrow" end
		return true
	end })

-- the Confirm screen's dial with a driver's own average as the wait: the tour's confirm shot, then Bob's beacon (to Ratchet)
-- carries 900 s (and 59 s) and he is ready (queue 0), so the dial shows it
for _, secs in ipairs({ 900, 59 }) do
	screen({ id = "confirm_avg" .. secs, side = "rider", unfold = true,
		title = "Confirm: the Fly or summon dial with the driver's average summon of " .. secs .. " s",
		need = gate("booking card (UI.Rider.Booking, the tour's confirm)", function(W) return mod(W, "UI.Rider.Booking") and haveTour("confirm") end),
		run = function(w)
			local r = runOf("confirm")(w)
			if r ~= true then return r end
			local d = type(w.drivers) == "table" and w.drivers["bob stone"]
			if not d then return "the tour has no Bob Stone" end
			shotStub(d, "avgSummon", secs) -- this shot only: Bob is as before for the screens after it
			shotStub(d, "queue", 0)
			shotStub(d, "state", "open")
			-- the tour's spot has no flight time there (the dial stays hidden): 25 min, as a long flight
			if shotStub(w, "TravelSaved", function() return 1500, "same continent", true end) == false then return "no shot stub (L.PhotoKit)" end
			w.UI.Show("confirm", "bob stone")
			if w.UI.RefreshNow then w.UI.RefreshNow() end
			local info = mod(w, "UI.Rider.Booking").DialInfo(w.UI.Driver("bob stone"), d.price)
			if not (info and info.wait == secs) then return "the dial's wait is " .. tostring(info and info.wait) .. ", not " .. secs .. "" end
			return true
		end })
end

-- the Drive console's "Today's takings" card with its "Your summons: about N" line: the tour's console_open shot with three
-- counted summons seeded (W.db.drive.summons); 900 s is the longest text, "about 15 min"
for _, secs in ipairs({ 45, 900 }) do
	screen({ id = "console_summons" .. secs, side = "driver", unfold = true,
		title = "Driver console: the takings card with the average summon line (" .. secs .. " s)",
		need = gate("the tour's console_open", function() return haveTour("console_open") end),
		run = function(w)
			w.db.drive = w.db.drive or {}
			local keep = w.db.drive.summons
			w.db.drive.summons = { { total = secs, cast = 20 }, { total = secs, cast = 20 }, { total = secs, cast = 20 } }
			undo(function() if type(w.db.drive) == "table" then w.db.drive.summons = keep end end)
			local r = runOf("console_open")(w)
			if r ~= true then
				w.db.drive.summons = keep
				return r
			end
			if w.Driver and w.Driver.RefreshNow then w.Driver.RefreshNow() end
			return true
		end })
end

-- the usual summon said: on the rider's list (the tour's home shot, the open drivers sending 59 s and 900 s, nobody waiting)
screen({ id = "home_usual", side = "rider", unfold = true,
	title = "Rider home: open drivers' cards say Usually about 59 sec and Usually about 15 min",
	need = gate("driver cards (UI.Rider.Cards, the tour's home)", function(W) return mod(W, "UI.Rider.Cards") and haveTour("home") end),
	run = function(w)
		local r = runOf("home")(w)
		if r ~= true then return r end
		local set = { ["mia runner"] = 59, ["bob stone"] = 900, ["anita lift"] = 59 }
		for key, secs in pairs(set) do
			local d = type(w.drivers) == "table" and w.drivers[key]
			if d then
				shotStub(d, "avgSummon", secs)
				shotStub(d, "queue", 0)
				shotStub(d, "state", "open")
			end
		end
		w.UI.Show("home")
		if w.UI.RefreshNow then w.UI.RefreshNow() end
		return true
	end })

-- the longest place (Feathermoon Stronghold), with two friends to bring, or with a 12-letter Warlock who summons
for _, v in ipairs({ { "confirm_usual_long", 1, nil }, { "confirm_usual_summoner", 2, "Bartholomewx" } }) do
	screen({ id = v[1], side = "rider", unfold = true,
		title = "Confirm: the longest place and usually about 59 sec at the end of the grey line" .. (v[3] and ", a Warlock who summons" or ""),
		need = gate("booking card (UI.Rider.Confirm, the tour's confirm)", function(W) return mod(W, "UI.Rider.Confirm") and haveTour("confirm") end),
		run = function(w)
			local r = runOf("confirm")(w)
			if r ~= true then return r end
			local d = type(w.drivers) == "table" and w.drivers["bob stone"]
			if not d then return "the tour has no Bob Stone" end
			shotStub(d, "avgSummon", 59)
			shotStub(d, "queue", 0)
			shotStub(d, "state", "open")
			shotStub(d, "team", v[2])
			shotStub(d, "summoner", v[3])
			shotStub(d, "dest", "Feathermoon Stronghold")
			w.UI.Show("confirm", "bob stone")
			if w.UI.RefreshNow then w.UI.RefreshNow() end
			return true
		end })
end

-- (REV-r37-1) the tour's own Confirm shot (Mia Runner, to Undercity) with a flight time there known, the usual case in the game:
-- the dial shows, the sheet moves up and the route header sits on the map strip by the pin
screen({ id = "confirm_dial", side = "rider", unfold = true,
	title = "Confirm: the booking card with the Fly or summon dial showing",
	need = gate("booking card (UI.Rider.Confirm, the tour's confirm)", function(W) return mod(W, "UI.Rider.Confirm") and haveTour("confirm") end),
	run = function(w)
		local r = runOf("confirm")(w)
		if r ~= true then return r end
		if shotStub(w, "TravelSaved", function() return 1500, "same continent", true end) == false then return "no shot stub (L.PhotoKit)" end
		w.UI.Show("confirm", "mia runner")
		if w.UI.RefreshNow then w.UI.RefreshNow() end
		local s = confirmSide(w)
		if not (s and s.dial and s.dial:IsShown()) then return "the Fly or summon dial is not showing" end
		return true
	end,
	-- (REV-r37-2) once the page has settled, folded: the strip's route above the sheet and out of the header
	post = function(w) return stripCheck(w, confirmSide(w), "confirm_dial") end })
-- (REV-r37-2) the same with the destination low on the strip (x 0.5, y 0.99 of the rider's map): the sheet is lifted for the dial,
-- and the pin, the route and the you dot keep above it and out of the route header
screen({ id = "confirm_dial_low", side = "rider", unfold = true,
	title = "Confirm: the dial showing and the destination low on the map strip",
	need = gate("booking card (UI.Rider.Confirm, the tour's confirm)", function(W) return mod(W, "UI.Rider.Confirm") and haveTour("confirm") end),
	run = function(w)
		local r = runOf("confirm")(w)
		if r ~= true then return r end
		if shotStub(w, "TravelSaved", function() return 1500, "same continent", true end) == false then return "no shot stub (L.PhotoKit)" end
		w.UI.Show("confirm", "mia runner")
		if w.UI.RefreshNow then w.UI.RefreshNow() end
		local s = confirmSide(w)
		local mapID = s and s.map and s.map.artFor
		if not mapID then return "the map strip has no map" end
		shotStub(w, "ExactPlace", function(name)
			if name == "Undercity" then return { name = "Undercity", mapID = mapID, x = 0.5, y = 0.99 } end
		end)
		if w.UI.RefreshNow then w.UI.RefreshNow() end
		if not (s.dial and s.dial:IsShown()) then return "the Fly or summon dial is not showing" end
		return true
	end,
	post = function(w) return stripCheck(w, confirmSide(w), "confirm_dial_low") end })

-- (round 32, k4) the Waiting-for-the-driver screen with a rider in another group: the "You're in a group. Leave it so <driver>
-- can invite you." line and its Leave button. The ride and the group answers are shot stubs here (the layout check leaves them in
-- for the rest of its tour), put back before the next screen
screen({ id = "finding_grouped", side = "rider", unfold = true,
	title = "Waiting for the driver, the rider in another group: the Leave your group line and button",
	need = gate("booking card (UI.Rider.Confirm)", function(W) return mod(W, "UI.Rider.Confirm") end),
	run = function(w)
		homeWith(w)
		local t = K.tour()
		if t then t.rides.k4finding = true end
		shotStub(w, "ride", { id = "k4finding", driver = "Mia Runner", driverKey = "mia runner", dest = "Undercity", price = 5000,
			state = "requesting", at = K.now(), service = "Mia's Rides" })
		shotStub(w, "InGroup", function() return true end)
		shotStub(w, "InGroupWith", function() return false end)
		w.UI.Show("finding")
		if w.UI.RefreshNow then w.UI.RefreshNow() end
		return true
	end })

-- (HUNT-76) the empty Blocked screen with "Block riders who leave without paying" off: its longest note
screen({ id = "blocked_off", side = "driver", unfold = true, declares = NO_UNFOLD,
	title = "Blocked, nobody blocked, the self-block switch off: the longer empty note",
	need = gate("Messages screen (UI.Driver.Messages, the tour's messages)", function(W) return mod(W, "UI.Driver.Messages") and haveTour("messages") end),
	run = function(w)
		local r = runOf("messages")(w) -- the Messages scene sets the console up (driver, closed); then this screen goes over it
		if r ~= true then return r end
		if w.Drive and w.Drive.SetOpt then w.Drive.SetOpt("autoBlock", false) end
		w.Driver.ShowScreen("blocked")
		if w.Driver.RefreshNow then w.Driver.RefreshNow() end
		return true
	end })
-- (r50 M, AU24-34) a filled Blocked list: a rider the addon blocked for leaving owing, whose reason wraps to a second line
screen({ id = "blocked_full", side = "driver", unfold = true, declares = NO_UNFOLD,
	title = "Blocked, one rider auto-blocked for not paying: the long reason wraps, the row grows",
	need = gate("Messages screen (UI.Driver.Messages, the tour's messages)", function(W) return mod(W, "UI.Driver.Messages") and haveTour("messages") end),
	run = function(w)
		local r = runOf("messages")(w)
		if r ~= true then return r end
		w.Drive.SetOpt("autoBlock", true)
		w.Drive.NonPayer({ name = "Dan Rider", key = "dan rider", state = "arrived", price = 5000, paid = 0, at = 0, tries = 1, caster = w.myKey })
		w.Driver.ShowScreen("blocked")
		if w.Driver.RefreshNow then w.Driver.RefreshNow() end
		return true
	end })

-- (HUNT-108) Settings > Check my game with the longest heading: every game check passed and twelve driver lines need a look
-- ("All 14 game checks passed. 12 driver lines need a look: see your Drive tab.")
screen({ id = "settings_check_long", side = "settings", unfold = true,
	title = "Settings: Check my game, the longest heading (twelve driver lines need a look)",
	need = gate("the tour's settings", function() return haveTour("settings") end),
	run = function(w)
		local r = runOf("settings")(w)
		if r ~= true then return r end
		local DR = w.Drive
		if type(DR) ~= "table" then return "no Drive" end
		-- the twelve stand-in lines only for the click: left in place they also fill the Drive console's own checklist,
		-- which no real driver has that long
		local keep = DR.Readiness
		local st = w.UI.settings
		if not (st and st.controls and st.controls.check) then return "no Check my game button" end
		DR.Readiness = function()
			local t = {}
			for i = 1, 12 do t[i] = { text = "Driver line number " .. i .. " needs a look", ok = false } end
			return t
		end
		local pressed, why = X.press(st.controls.check)
		DR.Readiness = keep
		if not pressed then return "Check my game: " .. tostring(why) end
		if w.Driver and w.Driver.RefreshNow then w.Driver.RefreshNow() end
		local head = st.results and st.results.head and st.results.head:GetText() or ""
		if not head:find("12 driver lines need a look", 1, true) then return "heading is: " .. head end
		return true
	end })

-- (AUD-155) the Confirm screen's dial for a free zeppelin trip: "The zeppelin is free, about 25 min slower" takes two lines at the
-- unfolded verdict's 15 px, and the dial makes room for the second
screen({ id = "confirm_dial_zeppelin", side = "rider", unfold = true,
	title = "Confirm: the Fly or summon dial, a free zeppelin trip with a two-line verdict",
	need = gate("booking card (UI.Rider.Confirm, the tour's confirm)", function(W) return mod(W, "UI.Rider.Confirm") and haveTour("confirm") end),
	run = function(w)
		local r = runOf("confirm")(w)
		if r ~= true then return r end
		-- worked out from the flight paths (about), free, and time worth little: the zeppelin wins
		if shotStub(w, "TravelSaved", function() return 1500, "by zeppelin", false end) == false then return "no shot stub (L.PhotoKit)" end
		shotStub(w.UI, "FlightCostTo", function() return 0 end)
		shotStub(w.db, "timeValue", 1)
		w.UI.Show("confirm", "mia runner")
		if w.UI.RefreshNow then w.UI.RefreshNow() end
		local s = confirmSide(w)
		local dial = s and s.dial
		if not (dial and dial:IsShown()) then return "the Fly or summon dial is not showing" end
		return true
	end,
	-- once the page has settled (unfolded: the dial 96 high, the verdict at 15 px, two lines where the card is narrow enough):
	-- the room under the verdict is the lines it is drawn on
	post = function(w)
		local s = confirmSide(w)
		local dial = s and s.dial
		if not (dial and dial:IsShown()) then return "the Fly or summon dial is not showing" end
		local fs = dial.verdict
		local said = fs.wuberText or ""
		if not said:find("costs nothing, about", 1, true) then return "the verdict is: " .. said end
		if ((dial.extra or 0) > 0) ~= (fs.wuberWrapped == true) then
			return "the verdict at " .. tostring(fs.wuberPx) .. " px has room for the wrong number of lines (extra "
				.. tostring(dial.extra) .. "): " .. said
		end
		return true
	end })

-- (AUD-163) the Drive console with the "Join the Wuber community" card showing: a driver who holds a founder invitation (the
-- community calls are stubbed for this shot only)
screen({ id = "console_join", side = "driver", unfold = true,
	title = "Driver console: the Join the Wuber community card (a club invitation held)",
	need = gate("the tour's console_open", function() return haveTour("console_open") end),
	run = function(w)
		local r = runOf("console_open")(w)
		if r ~= true then return r end
		if shotStub(w, "CommunityAvailable", function() return true end) == false then return "no shot stub" end
		shotStub(w, "CommunityMember", function() return false end)
		shotStub(w, "CommunityInvite", function() return 12345 end)
		if w.Driver and w.Driver.RefreshNow then w.Driver.RefreshNow() end
		-- the card is the foot of the scroll: show the bottom, or the check would not see it
		local ui = w.Driver and w.Driver.ui
		local sc = ui and ui.console and ui.console.scroll
		if not (sc and sc.ScrollTo) then return "no console scroll" end
		sc:ScrollTo(sc.max or 9999, true)
		return true
	end })

-- (AUD-157/158) the Price and place card with three long place matches ("ea"): pills at their normal size, none past the card's edge
screen({ id = "sheet_places", side = "driver", unfold = true, declares = NO_UNFOLD,
	title = "Price and place card: three long place matches typed (ea)",
	need = gate("the tour's console_open", function() return haveTour("console_open") end),
	run = function(w)
		local r = runOf("console_open")(w)
		if r ~= true then return r end
		if not (w.Driver and w.Driver.ShowSheet) then return "no ShowSheet" end
		w.Driver.ShowSheet("sheet")
		local s = w.UI.drive and w.UI.drive.screens and w.UI.drive.screens.sheet
		if not (s and s.layout and s.results) then return "no price and place card" end
		s.mode = "choose" s.layout()
		s.results("ea")
		return true
	end })

-- (AUD-147) the setup's Step 2 (and the Crew screen) with one row in "No answer: <name> may not have Wuber" for the longest allowed
-- name (12 letters) and the Add anyway button showing: the line must be whole, inside its row and clear of the button, at every size
local function noAnswer(w)
	local DR = w.Drive
	if type(DR) ~= "table" then return "no Drive" end
	local key = "wolfgangbert"
	shotStub(DR, "Crew", function() return {} end)
	shotStub(DR, "Roster", function() return { { name = "Wolfgangbert", key = key, class = "WARLOCK" } } end)
	shotStub(DR, "offers", { [key] = { name = "Wolfgangbert", at = 0, state = "noapp" } })
	return true
end
local function rowCheck(rows, want)
	for _, r in ipairs(rows or {}) do
		if type(r) == "table" and r.sub and r.IsShown and r:IsShown() and r.person then
			local txt = r.sub:GetText() or ""
			if txt ~= "No answer: Wolfgangbert may not have Wuber" then return "the row says: " .. txt end
			if not (r.btn and r.btn:IsShown()) then return "no Add anyway button on the row" end
			-- whole, inside the row and clear of the button (the frame edges, in screen units)
			local sb, rb, sr, bl = r.sub:GetBottom(), r:GetBottom(), r.sub:GetRight(), r.btn:GetLeft()
			if sb and rb and sb < rb then return "the line runs below its row (" .. sb .. " < " .. rb .. ")" end
			if sr and bl and sr > bl then return "the line reaches the button (" .. sr .. " > " .. bl .. ")" end
			if r.sub.IsTruncated and r.sub:IsTruncated() then return "the line is cut" end
			return true
		end
	end
	return "no " .. want .. " row is showing"
end
screen({ id = "wizard_noanswer_long", side = "driver",
	title = "Setup step 2: a 12-letter name with \"No answer\" and the Add anyway button",
	need = gate("the tour's wizard_summoner", function() return haveTour("wizard_summoner") end),
	run = function(w)
		local r = runOf("wizard_summoner")(w)
		if r ~= true then return r end
		return noAnswer(w)
	end,
	post = function(w)
		if not w.UI.ShowDrive("wizard") then return "no setup screen" end
		local ui = type(w.Driver) == "table" and w.Driver.ui
		local s = type(ui) == "table" and type(ui.subs) == "table" and ui.subs.wizard
		if not (type(s) == "table" and type(s.paint) == "function") then return "no setup screen" end
		s.choice, s.step = "friends", 2
		s.paint()
		return rowCheck(s.people and s.people.list, "setup")
	end })
screen({ id = "crew_noanswer_long", side = "driver",
	title = "Your crew: a 12-letter name with \"No answer\" and the Add anyway button",
	need = gate("the tour's wizard_summoner", function() return haveTour("wizard_summoner") end),
	run = function(w)
		local r = runOf("wizard_summoner")(w)
		if r ~= true then return r end
		return noAnswer(w)
	end,
	post = function(w)
		if not w.UI.ShowDrive("crew") then return "no crew screen" end
		local ui = type(w.Driver) == "table" and w.Driver.ui
		local s = type(ui) == "table" and type(ui.subs) == "table" and ui.subs.crew
		if type(s) ~= "table" then return "no crew screen" end
		if type(s.paint) == "function" then s.paint() end
		local rows = {}
		for _, key in ipairs({ "others", "members" }) do
			if type(s[key]) == "table" and type(s[key].list) == "table" then
				for _, r in ipairs(s[key].list) do rows[#rows + 1] = r end
			end
		end
		return rowCheck(rows, "crew")
	end })

-- (AUD-168) busy driver cards with the longest sub line ("To Feathermoon Stronghold · Summoned by Bartholomewx") beside the amber
-- state text: busy with a long queue, busy and the group full
screen({ id = "home_busy_long", side = "rider", unfold = true,
	title = "Rider home: busy cards with the longest place and Warlock name beside Busy, N waiting",
	need = gate("driver cards (UI.Rider.Cards, the tour's home)", function(W) return mod(W, "UI.Rider.Cards") and haveTour("home") end),
	run = function(w)
		local r = runOf("home")(w)
		if r ~= true then return r end
		local mix = { ["mia runner"] = { "busy", 12, 3 }, ["bob stone"] = { "busy", 99, 0 } }
		local n = 0
		for key, v in pairs(mix) do
			local d = type(w.drivers) == "table" and w.drivers[key]
			if d then
				n = n + 1
				shotStub(d, "state", v[1])
				shotStub(d, "queue", v[2])
				shotStub(d, "seats", v[3])
				shotStub(d, "dest", "Feathermoon Stronghold")
				shotStub(d, "summoner", "Bartholomewx")
			end
		end
		if n == 0 then return "the tour has no drivers to make busy" end
		w.UI.Show("home")
		if w.UI.RefreshNow then w.UI.RefreshNow() end
		-- the list scrolls and the tour's window puts a card across its bottom edge: scroll to the end. The tour then changes the
		-- window's size (folded, unfolded, the scale), which changes the list's room, so the scroll is taken again from the
		-- list's own numbers at every step until the tour has shot it
		local kit = mod(w, "UI.Kit")
		local kui = kit and kit.ui
		local function toEnd()
			if type(kui) ~= "table" or type(kui.cards) ~= "table" then return end
			-- only while this scene's own stub is up: once the tour has put Bob back, the timers below do nothing, so no later
			-- scene is scrolled by them
			local bob = type(w.drivers) == "table" and w.drivers["bob stone"]
			if not (type(bob) == "table" and bob.queue == 99) then return end
			local any = next(kui.cards)
			-- (design 2) a driver is a row of one card: the row's parent is that card, the card's is the content
			local row = any and kui.cards[any]
			local content = row and (row.group and row.group:GetParent() or row:GetParent())
			local clip = content and content:GetParent()
			if not (clip and clip.GetHeight and content.GetHeight) then return end
			local gap = row.group and 0 or (kit.CARD_GAP or 8)
			local mx = math.max(0, content:GetHeight() - gap - clip:GetHeight())
			kui.scrollMax, kui.scroll, kui.scrollTarget = mx, mx, mx
			content:ClearAllPoints()
			content:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, mx)
		end
		toEnd()
		if type(w.After) == "function" then
			for i = 1, 40 do w.After(i * 0.25, toEnd) end
		end
		return true
	end })

-- (REV-r47-1) Home searched for the longest place: "Drivers to Feathermoon Stronghold" beside "N open · M online"
screen({ id = "home_search_long", side = "rider", unfold = true,
	title = "Rider home: a search for the longest place, the heading beside its count and the bell",
	need = gate("the tour's home", function() return haveTour("home") end),
	run = function(w)
		local r = runOf("home")(w)
		if r ~= true then return r end
		local n = 0
		local d = type(w.drivers) == "table" and w.drivers["bob stone"]
		if d then n = 1 shotStub(d, "dest", "Feathermoon Stronghold") end
		if n == 0 then return "the tour has no drivers" end
		w.UI.Show("home")
		if w.UI.SetSearch then w.UI.SetSearch("Feathermoon Stronghold") end
		if w.UI.RefreshNow then w.UI.RefreshNow() end
		return true
	end })

-- Wuber 2.4, part 6: mid-flight offer card with 6 min left to the longest flight point and 123g 45s 67c.
-- (the flight map's own point names when it is open, else the longest place Wuber knows: the Lab never opens the flight map)
do
	local saved = {}
	local function stub(tbl, key, val)
		if saved[tbl] == nil then saved[tbl] = {} end
		if saved[tbl][key] == nil then saved[tbl][key] = { had = tbl[key] ~= nil, val = tbl[key] } end
		return shotStub(tbl, key, val)
	end
	local function restoreAll()
		for tbl, keys in pairs(saved) do
			for key, rec in pairs(keys) do tbl[key] = rec.had and rec.val or nil end
		end
		saved = {}
	end
	-- Wuber's own check of the offer card with W.OnTaxi said to be false (hides it) or true, put back at once
	local function withOnTaxi(w, IF, value)
		local orig = w.OnTaxi
		w.OnTaxi = function() return value end
		local ok, err = pcall(function()
			IF.Hide()
			IF.Check()
		end)
		w.OnTaxi = orig
		if not ok then error(err, 0) end
	end
	local function hideOffer(w)
		restoreAll()
		local IF = mod(w, "UI.InFlight")
		if IF then pcall(withOnTaxi, w, IF, false) end
	end
	screen({ id = "inflight", side = "rider", unfold = true,
		title = "Mid-flight offer: card with longest place name and longest price text",
		need = gate("mid-flight offer (UI.InFlight)", function(W)
			local IF = mod(W, "UI.InFlight")
			return IF and type(IF.Check) == "function" and type(IF.Hide) == "function"
		end),
		run = function(w)
			saved = {}
			local IF = mod(w, "UI.InFlight")
			homeWith(w)
			local bestPlace
			local okN, numNodes = pcall(function() return type(NumTaxiNodes) == "function" and NumTaxiNodes() or 0 end)
			if not okN or type(numNodes) ~= "number" then numNodes = 0 end
			for i = 1, numNodes do
				local okT, raw = pcall(TaxiNodeName, i)
				if okT and type(raw) == "string" and raw ~= "" then
					local place = (type(w.FLY) == "table" and type(w.FLY.NodePlace) == "function" and w.FLY.NodePlace(raw))
						or raw:match("^([^,]+)") or raw
					place = place:match("^%s*(.-)%s*$")
					if place ~= "" and (not bestPlace or #place > #bestPlace) then bestPlace = place end
				end
			end
			bestPlace = bestPlace or "Feathermoon Stronghold" -- (no flight map open: the longest place Wuber knows)
			undo(function() hideOffer(w) end)
			pcall(withOnTaxi, w, IF, false)
			if stub(w, "OnTaxi", function() return true end) == false then
				restoreAll()
				return "no shot stub (L.PhotoKit)"
			end
			stub(w, "FlightLeft", function() return 372, bestPlace end)
			local now = K.now()
			stub(w.UI, "Drivers", function()
				return { {
					name = "Wolfgangbert", short = "Wolfgangbert", key = "inflight demo", dest = bestPlace, price = 1234567,
					state = "open", queue = 0, team = 3, service = "Wolfgangbert's Rides", heard = now,
				} }
			end)
			if w.ride ~= nil then stub(w, "ride", nil) end
			if type(w.db) == "table" then
				if w.db.flightOffers == false then stub(w.db, "flightOffers", true) end
				if w.db.midFlight == false then stub(w.db, "midFlight", true) end
			end
			local shownOk = IF.Check()
			if not shownOk then
				local why = type(IF.Why) == "function" and IF.Why() or "unknown"
				hideOffer(w)
				-- with no room beside Wuber's window the card rightly waits: the shot is the phone alone
				if tostring(why):find("no room beside", 1, true) then return true end
				return "the mid-flight offer card did not show: " .. tostring(why)
			end
			return true
		end,
		hide = function() hideOffer(L.W()) end })
end

---------------------------------------------------------------------------
-- tests/layout/f3_e_screens.lua: the game's word on a rider's summon (console_summon_long, console_summon_seen, float_summon_held)
---------------------------------------------------------------------------

do
	local TITLE = "Wolfgangbert has a summon waiting"
	local SUB = "no second summon while it is up: it would waste a Soul Shard"
	local function haveSummonWord(W)
		local DR, D = W.Drive, W.Driver
		return type(DR) == "table" and type(D) == "table" and type(DR.SummonSeen) == "function" and type(DR.SummonHeld) == "function"
	end
	-- the game says every rider who is not here yet declined; the button holds its cast for a rider with a summon waiting
	local function dress(w, longName)
		local dr = w.Drive
		local now = type(w.Now) == "function" and w.Now() or 0
		if shotStub(dr, "SummonSeen", function(c)
			if type(c) == "table" and (c.state == "joined" or c.state == "waiting") then return "declined", now - 5 end
			return nil
		end) == false then return "no shot stub (L.PhotoKit)" end
		if longName then
			-- (the tour makes a fresh demo queue for every shot: the name needs no putting back)
			for _, c in ipairs(type(dr.Sorted) == "function" and dr.Sorted() or {}) do
				if type(c) == "table" and c.state == "joined" then c.name = "Wolfgangbert Rider" end
			end
		end
		shotStub(dr, "Plan", function() return { marks = {}, color = "wait", title = TITLE, sub = SUB } end)
		if type(dr.Button) == "table" and type(dr.Button.Refresh) == "function" then dr.Button.Refresh() end
		local d = w.Driver
		if type(d.RefreshNow) == "function" then d.RefreshNow() elseif type(d.Refresh) == "function" then d.Refresh(true) end
		-- the scene checks itself: the button shows the guard's line (a shot of something else would prove nothing)
		local b = dr.button
		local title = type(b) == "table" and type(b.title) == "table" and b.title:GetText() or nil
		if title ~= TITLE then return "the big button does not show the guard's line: " .. tostring(title) end
		return true
	end
	-- a console row that shows the declined words (whole or a shorter form), or nil
	local function declinedRow(w)
		local v = type(w.Driver.ui) == "table" and w.Driver.ui.console
		for _, r in ipairs(type(v) == "table" and type(v.rows) == "table" and v.rows or {}) do
			local t = r:IsShown() and r.what and r.what:GetText() or ""
			if t:find("declined", 1, true) then return t end
		end
		return nil
	end
	-- (the second is added first in the layout check, so the two end up in this order after console_open)
	for _, v in ipairs({ { "console_summon_long", true, "Driver console: the same with a 12-letter rider name (the row's shorter form)" },
		{ "console_summon_seen", false, "Driver console: a rider declined the summon; the button holds its cast for a rider with a summon waiting" } }) do
		screen({ id = v[1], side = "driver", unfold = true, title = v[3],
			need = gate("the game's summon word (Drive.SummonSeen, Drive.SummonHeld, the tour's console_open)", function(W) return haveSummonWord(W) and haveTour("console_open") end),
			run = function(w)
				local r = runOf("console_open")(w)
				if r ~= true then return r end
				r = dress(w, v[2])
				if r ~= true then return r end
				if not declinedRow(w) then return "no console row shows the declined words" end
				return true
			end })
	end
	do
		local wait, maxWait = timing("float_summon_sent")
		screen({ id = "float_summon_held", side = "driver", wait = wait, maxWait = maxWait,
			title = "Floating button + console: a rider has a summon waiting; a row that declined",
			need = gate("the game's summon word (Drive.SummonSeen, Drive.SummonHeld, the tour's float_summon_sent)", function(W) return haveSummonWord(W) and haveTour("float_summon_sent") end),
			run = function(w)
				-- the mid-flight card (an earlier scene's) can be left up; it is no part of this shot
				local IF = mod(w, "UI.InFlight")
				if IF and type(IF.Hide) == "function" then pcall(IF.Hide) end
				local r = runOf("float_summon_sent")(w)
				if r ~= true then return r end
				return dress(w, false)
			end,
			post = hookIf("float_summon_sent", "post") })
	end
end

---------------------------------------------------------------------------
-- tests/layout/dec_q_screens.lua: payment by mail (done_unpaid_mail, customers_mail)
---------------------------------------------------------------------------

do
	local LINE = "Still owe the fare? Send 123g 45s 67c to Wolfgangbert Longsurname by mail, subject Wuber."
	local NOTE = "Mail seen: 123g 45s 67c from Wolfgangbert, 21 Nov."
	local function haveMail(W)
		local Mail = mod(W, "Drive.Mail")
		return Mail and type(Mail.RiderLine) == "function" and type(W.Drive) == "table" and type(W.Drive.MailNote) == "function"
	end
	local done = tourScreen("done_unpaid")
	screen({ id = "done_unpaid_mail", side = "rider", unfold = done and done.unfold, only = done and done.only,
		title = "Done, not paid after arriving: what to send by mail, the longest amount and name",
		need = gate("payment by mail (Drive.Mail, the tour's done_unpaid)", function(W) return haveMail(W) and haveTour("done_unpaid") end),
		run = function(w)
			local r = runOf("done_unpaid")(w)
			if r ~= true then return r end
			local Mail = mod(w, "Drive.Mail")
			-- (the tour makes a fresh demo ride for every shot: these need no putting back)
			local ride = w.ride
			if type(ride) ~= "table" then return "no demo ride" end
			ride.arrivedAt = type(time) == "function" and time() or 1
			ride.price, ride.paidSoFar = 1234567, nil
			ride.payee, ride.payto = "Wolfgangbert Longsurname", "Wolfgangbert"
			if Mail.RiderLine(ride) ~= LINE then return "the line is not the longest: " .. tostring(Mail.RiderLine(ride)) end
			w.Fire("RIDE")
			w.UI.Show("done")
			local scr = type(w.UI.state) == "table" and type(w.UI.state.screens) == "table" and w.UI.state.screens.done
			if type(scr) == "table" and type(scr.update) == "function" then scr.update() end
			-- the scene checks itself: the card shows the line (a shot of something else would prove nothing)
			local text = type(scr) == "table" and scr.unpaidText and scr.unpaidText:GetText() or ""
			if not tostring(text):find(LINE, 1, true) then return "the unpaid card does not show the mail line" end
			return true
		end })
	local cust = tourScreen("customers")
	screen({ id = "customers_mail", side = "driver", unfold = cust and cust.unfold, only = cust and cust.only,
		title = "Customers: a mail was seen from every customer (the longest note under each name)",
		need = gate("payment by mail (Drive.Mail, the tour's customers)", function(W) return haveMail(W) and haveTour("customers") end),
		run = function(w)
			local r = runOf("customers")(w)
			if r ~= true then return r end
			-- the tour's demo customer book stands in for DR.Customers: each of its customers gets the note, as Drive.Book's own
			-- list carries it (e.mail); the tooltip's source says the same. (A copy of each entry: never the book's own.)
			local dr = w.Drive
			local list0 = dr.Customers
			if shotStub(dr, "Customers", function(...)
				local out, mine = list0(...), {}
				for i, e in ipairs(type(out) == "table" and out or {}) do
					if type(e) == "table" then
						local copy = {}
						for k, v in pairs(e) do copy[k] = v end
						copy.mail = NOTE
						e = copy
					end
					mine[i] = e
				end
				return mine
			end) == false then return "no shot stub (L.PhotoKit)" end
			shotStub(dr, "MailNote", function() return NOTE end)
			local d = w.Driver
			if type(d.ShowScreen) == "function" then d.ShowScreen("customers") end
			if type(d.RefreshNow) == "function" then d.RefreshNow() elseif type(d.Refresh) == "function" then d.Refresh(true) end
			local Screens = mod(w, "UI.Driver.Screens")
			local s = type(Screens) == "table" and type(Screens.st) == "table" and type(Screens.st.screens) == "table" and Screens.st.screens.customers or nil
			local list = type(s) == "table" and type(s.pool) == "table" and s.pool.list or {}
			for _, row in ipairs(list) do
				local t = row:IsShown() and row.sub and row.sub:GetText() or ""
				if tostring(t):find(NOTE, 1, true) then return true end
			end
			return "no customer row shows the mail note"
		end })
end

---------------------------------------------------------------------------
-- tests/layout/extra_screens.lua (words244 C): the ended page of a rider removed from the group (done_removed)
---------------------------------------------------------------------------

do
	local done = tourScreen("done_unpaid")
	screen({ id = "done_removed", side = "rider", unfold = done and done.unfold, only = done and done.only,
		title = "Ride ended: removed from the group while the summon box was up",
		need = gate("the tour's done_unpaid", function() return haveTour("done_unpaid") end),
		run = function(w)
			local r = runOf("done_unpaid")(w)
			if r ~= true then return r end
			if type(w.ride) ~= "table" then return "no demo ride" end
			w.ride.removed = true
			w.Fire("RIDE")
			w.UI.Show("done")
			local scr = type(w.UI.state) == "table" and type(w.UI.state.screens) == "table" and w.UI.state.screens.done
			if type(scr) == "table" and type(scr.update) == "function" then scr.update() end
			local text = type(scr) == "table" and scr.unpaidText and scr.unpaidText:GetText() or ""
			if not tostring(text):find("Removed from the group", 1, true) then return "the card does not show the line" end
			return true
		end })
end

---------------------------------------------------------------------------
-- tests/layout/d4_h_screens.lua: "Don't serve again until" (note_serve, customers_serve)
---------------------------------------------------------------------------

do
	local function haveServe(W) return type(W.Drive) == "table" and type(W.Drive.ServeHold) == "function" and type(W.Drive.OwesFare) == "function" end
	local function stubs()
		local DR = L.W().Drive
		local at = (type(time) == "function" and time() or 0) + 30 * 86400
		if shotStub(DR, "OwesFare", function() return true end) == false then return false end
		shotStub(DR, "ServeHold", function() return at end)
		return true
	end
	local note = tourScreen("note")
	screen({ id = "note_serve", side = "driver", unfold = note and note.unfold, only = note and note.only,
		title = "Note sheet of a rider who left owing, \"Don't serve again until\" set (Advanced)",
		need = gate("\"Don't serve again until\" (Drive.ServeHold, the tour's note)", function(W) return haveServe(W) and haveTour("note") end),
		run = function(w)
			local r = runOf("note")(w)
			if r ~= true then return r end
			if not stubs() then return "no shot stub (L.PhotoKit)" end
			local d = w.Driver
			local s = type(d.ui) == "table" and type(d.ui.sheets) == "table" and d.ui.sheets.note or nil
			if type(s) ~= "table" or type(s.update) ~= "function" then return "no note sheet" end
			s.update()
			if not (s.serve and s.serve:IsShown()) then return "the pill is not shown" end
			return true
		end })
	local cust = tourScreen("customers")
	screen({ id = "customers_serve", side = "driver", unfold = true, only = cust and cust.only,
		title = "Customers, wide: the side pane's \"Don't serve again until\" pill, set (Advanced)",
		need = gate("\"Don't serve again until\" (Drive.ServeHold, the tour's customers)", function(W) return haveServe(W) and haveTour("customers") end),
		run = function(w)
			local r = runOf("customers")(w)
			if r ~= true then return r end
			if not stubs() then return "no shot stub (L.PhotoKit)" end
			local d = w.Driver
			if type(d.ShowScreen) == "function" then d.ShowScreen("customers") end
			if type(d.RefreshNow) == "function" then d.RefreshNow() elseif type(d.Refresh) == "function" then d.Refresh(true) end
			return true
		end })
end

---------------------------------------------------------------------------
-- tests/layout/d4_c_screens.lua: the tab bar that hides during a ride (d4c_ride_stranger, d4c_ride_pay, d4c_ride_tabs, d4c_home_ride)
---------------------------------------------------------------------------

do
	local function haveHidden(W) return type(W.UI) == "table" and type(W.UI.TabsHidden) == "function" and type(W.UI.state) == "table" end
	-- the look at Home (ui.peek) is put away again before every screen
	do
		local base = L.PhotoReset
		L.PhotoReset = function(w, ...)
			if base then pcall(base, w, ...) end
			local t = K.tour()
			if t and t.auto and type(w) == "table" and type(w.UI) == "table" and type(w.UI.state) == "table" then w.UI.state.peek = nil end
		end
	end
	-- the ride page as the round wants it, or why not. Not yet settled (right after the page is set up): the tab bar's slide and the main
	-- button's drop are still under way, so only the page, the hidden bar and the chevron are asked; settled (post): all of it.
	-- (The layout check asks for all of it at once, and only gets it because the screen before its row is a ride page too, with the
	-- bar already away; the Auto check's rows follow other pages.)
	local function rideLook(w, settled)
		local ui = w.UI.state
		local s = type(ui.screens) == "table" and ui.screens.found
		if ui.screen ~= "found" or type(s) ~= "table" then return "the ride page is not up: " .. tostring(ui.screen) end
		if not w.UI.TabsHidden() then return "the tab bar is not hidden on the ride page" end
		if settled and ui.tabbar:IsShown() and (ui.tabbar:GetAlpha() or 1) > 0.01 and ui.barP ~= 1 then return "the tab bar still shows" end
		if not (s.back and s.back:IsVisible()) then return "the ride page has no back chevron" end
		if settled then
			local foot = s.action:GetBottom() - ui.win:GetBottom()
			if math.abs(foot - w.Theme.MAIN.foot) > 1 then return "the main button is not at the phone's foot: " .. tostring(foot) end
		end
		return true
	end
	for _, v in ipairs({
		{ "d4c_ride_stranger", "stranger", "Ride, tabs hidden: a stranger's trade, the warning beside the back chevron" },
		{ "d4c_ride_pay", "pay", "Ride, tabs hidden: time to pay, the back chevron and the title" },
		{ "d4c_ride_tabs", "portal", "Ride, tabs hidden: the portal is up, the main button at the phone's foot" },
	}) do
		local wait, maxWait = timing(v[2])
		screen({ id = v[1], side = "rider", unfold = false, title = v[3], wait = wait, maxWait = maxWait,
			need = gate("hidden tab bar (UI.TabsHidden, the tour's " .. v[2] .. ")", function(W) return haveHidden(W) and haveTour(v[2]) end),
			ready = hookOf(v[2], "ready"), afterShot = hookOf(v[2], "afterShot"),
			run = function(w, view)
				local r = runOf(v[2])(w, view)
				if r ~= true then return r end
				refreshUI(w)
				return rideLook(w, false)
			end,
			post = function(w, view)
				local b = tourScreen(v[2])
				if b and type(b.post) == "function" then
					local r = b.post(w, view)
					if r ~= true then return r end
				end
				return rideLook(w, true)
			end })
	end
	local wait, maxWait = timing("portal")
	screen({ id = "d4c_home_ride", side = "rider", unfold = true, title = "Home during a ride (after Back): the tabs are there, the pill is alive",
		wait = wait, maxWait = maxWait,
		need = gate("hidden tab bar (UI.TabsHidden, the tour's portal)", function(W) return haveHidden(W) and haveTour("portal") end),
		run = function(w, view)
			local r = runOf("portal")(w, view)
			if r ~= true then return r end
			refreshUI(w)
			local ui = w.UI.state
			local s = ui.screens.found
			if not (s and s.back) then return "the ride page has no back chevron" end
			local pressed, why = X.press(s.back, "LeftButton") -- the chevron's own OnClick: Back to Home
			if not pressed then return "the back chevron: " .. tostring(why) end
			refreshUI(w)
			if ui.screen ~= "home" then return "Back did not show Home: " .. tostring(ui.screen) end
			if w.UI.TabsHidden() then return "the tab bar is hidden on Home" end
			if type(w.ride) ~= "table" then return "the ride is gone" end
			return true
		end,
		post = function(w)
			local ui = w.UI.state
			if ui.screen ~= "home" then return "Home did not stay: " .. tostring(ui.screen) end
			if not (ui.tabbar:IsVisible() and (ui.tabbar:GetAlpha() or 0) > 0.99) then return "the tab bar is not back" end
			return true
		end })
end
