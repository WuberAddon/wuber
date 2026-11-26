-- Wuber Lab (developer only, never ship): the photo tour's shot list and its demo data. Photo.lua
-- runs the tour (stubs, the WuberDB snapshot, the window's place, the Fold, waiting until a screen has
-- settled, the shots and their log); this file only says what each shot shows.
--
-- L.PHOTO_SCREENS: { id, side, title, run(W, view), post(W, view), unfold, only, wait, maxWait, ready }
--   run    sets the screen up (true = shoot it; a string = skipped, why). It runs again for the
--          unfolded shot, so it is idempotent (data seeded once per tour, see once()).
--   post   after the Fold is applied (the side pane is built then): tooltips, the World view
--   unfold true: an unfolded shot (720 wide) follows the folded one; only = "unfolded": no folded shot
--   wait / maxWait / ready: a shorter settle (Settings' highlight fades in 1.6 s)
--   noWin  the shot is of the game's own maps with Wuber's window shut: the settle doesn't wait on it
--   video  in the launch video's group (/lab tour video)
-- L.PHOTO_GATED (job 041): shots that need OpenMap or the game's flight map, each with after (the screen it
--   follows) or first (the tour's first shot) and need(W) (true, or why it is left out of a tour); not in
--   L.PHOTO_SCREENS.
-- (job 042) noChat: the chat frames out of the shot; check(W, view): a line for the tour log, at the shot;
--   afterShot(W, more): after the shot (more: shots follow).
-- L.PhotoReset(W): before every screen and at the end: no tooltip, no raincheck card, no Wrapped
-- story, the World view back to Here.
-- Only Wuber's public names (W.*, W.UI.*, W.Driver.*, W.Drive.*, W.Mod) and table fields tests
-- replace too; every demo value goes through K.stub (put back at the end) or into WuberDB (put back
-- exactly from the snapshot).
-- (round 13) The demo adds up: the driver's numbers (Earnings, Customers, the queue's ride counts, today's
-- takings, the shift card and its fair split) come from one demo driving log (PhotoDemo.lua) through
-- Wuber's own functions; the rider's level and milestones from the demo trips by Wuber's own rules.

local _, L = ...

local K = L.PhotoKit
local str, num, call = L.str, L.num, L.call
local stub, fn, now = K.stub, K.fn, K.now

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- true the first time in this tour (data seeded once, so a run can run twice)
local function once(name)
	local t = K.tour()
	if not t then return false end
	t.once = t.once or {}
	if t.once[name] then return false end
	t.once[name] = true
	return true
end

local function mod(W, name)
	if not fn(W, "Mod") then return nil end
	local ok, m = pcall(W.Mod, name)
	return ok and type(m) == "table" and m or nil
end

local function epoch() return num(call(time)) or 0 end

-- (job 2858) The tour's own driver is never the player's character: every name the demo shows for "you" and for the
-- founder row is made up, so no shot needs blurring. Demo only, never saved.
local DEMO_ME = "Mia Runner"
local DEMO_FOUNDER, DEMO_FOUNDER_KEY = "Nia Quill", "nia quill"

-- a Wuber tooltip (T.Tip) shown as if the mouse were over the frame; hidden by L.PhotoReset
local function tipOn(W, frame)
	local T = W.Theme
	if type(frame) ~= "table" or type(frame.wuberTip) ~= "table" or not fn(T, "RefreshTip") then return false end
	frame.wuberTipShown = true
	T.RefreshTip(frame)
	local t = K.tour()
	if t then t.tip = frame end
	return true
end

local function tipOff()
	local t = K.tour()
	local f = t and t.tip
	if t then t.tip = nil end
	if type(f) == "table" then f.wuberTipShown = nil end
	if f then L.Tip.hide() end -- Wuber's own card (WuberTip), or the game's tooltip for an older Wuber
end

local function refresh(W)
	local UI = W.UI
	if fn(UI, "RefreshNow") then UI.RefreshNow() elseif fn(UI, "Refresh") then UI.Refresh(true) end
end

local function driveRefresh(W)
	local D = W.Driver
	if fn(D, "RefreshNow") then D.RefreshNow() elseif fn(D, "Refresh") then D.Refresh(true) end
end

local function closeSheets(W)
	local D = W.Driver
	local sheets = type(D) == "table" and type(D.ui) == "table" and D.ui.sheets
	if type(sheets) ~= "table" then return end
	for _, s in pairs(sheets) do
		local f = type(s) == "table" and s.frame
		if type(f) == "table" and f.open and fn(f, "Close") then pcall(f.Close, f, true) end
	end
end
L.PhotoCloseSheets = closeSheets

local function closeOverlays(W)
	local UI = W.UI
	if fn(UI, "HelpShown") and UI.HelpShown() and fn(UI, "CloseHelp") then UI.CloseHelp(true) end
	if type(UI.state) == "table" and UI.state.settingsOpen and fn(UI, "CloseSettings") then UI.CloseSettings(true) end
end
L.PhotoCloseOverlays = closeOverlays

local function openApp(W)
	local UI = W.UI
	if not (fn(UI, "Toggle") and fn(UI, "Show")) then return false end
	if not (fn(UI, "IsShown") and UI.IsShown()) then UI.Toggle(true) end
	if fn(UI, "EndSplash") then pcall(UI.EndSplash) end
	if fn(UI, "EndCoach") and type(UI.state) == "table" and UI.state.coaching then pcall(UI.EndCoach) end
	return true
end

local function rider(W, screen, arg)
	local UI = W.UI
	if not openApp(W) then return "W.UI.Show is missing" end
	closeOverlays(W)
	if fn(UI, "SelectTab") and type(UI.state) == "table" and UI.state.tab ~= "Ride" then UI.SelectTab("Ride") end
	if UI.Show(screen, arg) == false then return "W.UI.Show(" .. screen .. ") said no" end
	refresh(W)
	return true
end

-- (job 041) A stub for this shot only: L.PhotoReset puts the value from before the shot back before the
-- next screen (K.stub still keeps the tour's original for the end). For stubs no base resets each shot.
local function shotStub(tbl, key, value)
	local t = K.tour()
	if not t or type(tbl) ~= "table" then return false end
	t.shotStubs = t.shotStubs or {}
	t.shotStubs[#t.shotStubs + 1] = { tbl, key, tbl[key] }
	return stub(tbl, key, value)
end

local function shotUnstub()
	local t = K.tour()
	local list = t and t.shotStubs
	if not list then return end
	t.shotStubs = nil
	for i = #list, 1, -1 do
		local s = list[i]
		s[1][s[2]] = s[3]
	end
end

-- (job 041) the game's world map: opened for the OpenMap shots, shut again after each (only when the tour
-- opened it). ShowUIPanel / HideUIPanel, as Wuber's own W.Map.ShowDriver opens it.
local function worldMap()
	local m = rawget(_G, "WorldMapFrame")
	return type(m) == "table" and m or nil
end

local function mapShown()
	local m = worldMap()
	return m ~= nil and fn(m, "IsShown") and m:IsShown() and true or false
end

local function openWorldMap()
	local m = worldMap()
	if not m then return false end
	if mapShown() then return true end
	local showPanel = rawget(_G, "ShowUIPanel")
	if type(showPanel) == "function" then pcall(showPanel, m) end
	if not mapShown() and fn(m, "Show") then pcall(m.Show, m) end
	local t = K.tour()
	if t and mapShown() then t.mapOpened = true end
	return mapShown()
end

local function closeWorldMap()
	local t = K.tour()
	if not (t and t.mapOpened) then return end
	t.mapOpened = nil
	local m = worldMap()
	if not (m and mapShown()) then return end
	local hidePanel = rawget(_G, "HideUIPanel")
	if type(hidePanel) == "function" then pcall(hidePanel, m) end
	if mapShown() and fn(m, "Hide") then pcall(m.Hide, m) end
end

-- (job 042) OpenMap's window on the screen for its two shots. The tester's window was wider than his screen (its
-- left part, with a pin and the route's end, off it) and the quest list took the map's right third. OpenMap
-- puts its saved place and size (OpenMapDB.worldmap: window, windowSize, windowScale) back whenever the map
-- is shown, laid out or moved (its Window.lua), so for the shot those are set to the screen less a margin,
-- centred, and OpenMap lays the window out itself; the quest list is collapsed with Blizzard's side-panel
-- toggle, as OpenMap's own menu button does. Everything is put back exactly after the shot (L.PhotoReset):
-- the saved values (the same tables), the quest list, the window's scale, points and size.
local function omDB()
	local db = rawget(_G, "OpenMapDB")
	db = type(db) == "table" and db.worldmap or nil
	return type(db) == "table" and db or nil
end

local function sidePanelShown(m)
	if fn(m, "IsSidePanelShown") then
		local ok, v = pcall(m.IsSidePanelShown, m)
		if ok then return v and true or false end
	end
	local q = m.QuestLog
	return type(q) == "table" and fn(q, "IsShown") and q:IsShown() and true or false
end

local function toggleSidePanel(m)
	if not fn(m, "HandleUserActionToggleSidePanel") then return false end
	local ok = pcall(m.HandleUserActionToggleSidePanel, m)
	local tg = m.SidePanelToggle
	if type(tg) == "table" and fn(tg, "Refresh") then pcall(tg.Refresh, tg) end
	return ok
end

local function framePoints(f)
	local out = {}
	local okN, n = pcall(f.GetNumPoints, f)
	for i = 1, (okN and num(n)) or 0 do
		local ok, p, rel, rp, x, y = pcall(f.GetPoint, f, i)
		if ok and p then out[#out + 1] = { p, rel, rp, x, y } end
	end
	return out
end

local function lockdown()
	local f = rawget(_G, "InCombatLockdown")
	local ok, v = pcall(f)
	return type(f) == "function" and ok and v == true
end

-- -> a line for the log (what was done), or nil
local function omFit()
	local t, m = K.tour(), worldMap()
	if not (t and m) or lockdown() then return nil end
	if fn(m, "IsMaximized") and m:IsMaximized() then return "the map is full screen: left as it is" end
	local db = omDB()
	if not t.omWin then
		t.omWin = { db = db, points = framePoints(m), w = num(m:GetWidth()), h = num(m:GetHeight()), scale = num(m:GetScale()),
			side = sidePanelShown(m) }
		if db then t.omWin.saved = { window = db.window, windowSize = db.windowSize, windowScale = db.windowScale } end
	end
	local ue = num(UIParent:GetEffectiveScale()) or 1
	local s = (num(m:GetEffectiveScale()) or ue) / ue
	local uw, uh = num(UIParent:GetWidth()) or 1024, num(UIParent:GetHeight()) or 768
	local margin = math.floor(math.max(24, math.min(uw, uh) * 0.04))
	local w, h = math.floor((uw - 2 * margin) / s), math.floor((uh - 2 * margin) / s)
	if db then
		-- OpenMap's own layout (its hooks on the map's SetScale etc. put the saved place and size back)
		db.window, db.windowSize = { "CENTER", "CENTER", 0, 0 }, { w, h }
		pcall(m.SetScale, m, m:GetScale())
	end
	local mw, mh = num(m:GetWidth()) or 0, num(m:GetHeight()) or 0
	local p = { m:GetPoint(1) }
	if math.abs(mw - w) > 0.5 or math.abs(mh - h) > 0.5 or p[1] ~= "CENTER" or math.abs(num(p[4]) or 0) > 0.5 or math.abs(num(p[5]) or 0) > 0.5 then
		pcall(m.ClearAllPoints, m)
		pcall(m.SetPoint, m, "CENTER", UIParent, "CENTER", 0, 0)
		pcall(m.SetSize, m, w, h)
	end
	if t.omWin.side and not t.omWin.collapsed and sidePanelShown(m) then t.omWin.collapsed = toggleSidePanel(m) end
	return ("OpenMap's window %dx%d, centred, %d margin%s"):format(w, h, margin, t.omWin.collapsed and ", quest list collapsed" or "")
end

-- OpenMap's window as the tester had it: the saved values, the quest list, then the window's scale, points, size
local function omUnfit()
	local t = K.tour()
	local o = t and t.omWin
	if not o then return end
	t.omWin = nil
	if o.db and o.saved then o.db.window, o.db.windowSize, o.db.windowScale = o.saved.window, o.saved.windowSize, o.saved.windowScale end
	local m = worldMap()
	if not m or lockdown() then return end
	if o.collapsed and not sidePanelShown(m) then toggleSidePanel(m) end
	if o.scale then pcall(m.SetScale, m, o.scale) end
	if #o.points > 0 then
		pcall(m.ClearAllPoints, m)
		for _, p in ipairs(o.points) do pcall(m.SetPoint, m, p[1], p[2] or UIParent, p[3] or p[1], p[4] or 0, p[5] or 0) end
	end
	if o.w and o.h then pcall(m.SetSize, m, o.w, o.h) end
end

-- Before every screen and at the end of the tour.
function L.PhotoReset(W)
	tipOff()
	local stand = rawget(_G, "WuberLabTaxiStand") -- (job 2858) the bird card's stand-in goes with its shot
	if type(stand) == "table" and fn(stand, "Hide") then pcall(stand.Hide, stand) end
	shotUnstub()
	omUnfit()
	closeWorldMap()
	local tour = K.tour()
	if tour then tour.alt = nil end -- back to the demo log
	-- (job 041) the "Skip the bird" card the tour showed goes with its shot
	if tour and tour.bird then
		tour.bird = nil
		local Bd = mod(W, "UI.Bird")
		local card = Bd and fn(Bd, "Card") and call(Bd.Card)
		if type(card) == "table" and fn(card, "IsShown") and card:IsShown() and fn(Bd, "Hide") then pcall(Bd.Hide) end
	end
	-- the bug window and the public-chat warning belong to one shot each
	local B = type(W) == "table" and type(W.UI) == "table" and W.UI.Bug
	if type(B) == "table" and fn(B, "Close") and fn(B, "Shown") and B.Shown() then pcall(B.Close) end
	local hide = rawget(_G, "StaticPopup_Hide")
	local pop = type(W) == "table" and type(W.Drive) == "table" and W.Drive.PUBLIC_POPUP
	if type(hide) == "function" and pop then pcall(hide, pop) end
	local UI = type(W) == "table" and W.UI
	if type(UI) ~= "table" then return end
	local st = type(UI.state) == "table" and UI.state or {}
	if type(st.rcOffer) == "table" and fn(st.rcOffer, "Hide") then st.rcOffer:Hide() end
	local Wr = mod(W, "UI.Rider.Wrapped")
	if Wr and fn(Wr, "Shown") and Wr.Shown() and fn(Wr, "Close") then pcall(Wr.Close) end
	local WM = mod(W, "UI.Rider.WorldMap")
	if WM and fn(WM, "Show") then pcall(WM.Show, "here") end
end

---------------------------------------------------------------------------
-- Demo data
---------------------------------------------------------------------------

local rideN = 0
local function demoRide(W, state, extra)
	rideN = rideN + 1
	local r = { id = "labphoto" .. rideN, driver = "Mia Runner", driverKey = "mia runner", dest = "Undercity", price = 5000,
		state = state, at = now(), payee = "Mia Runner", payto = "Mia", service = "Mia's Rides" }
	-- (round 13, I14) no made-up flight price: Undercity from Orgrimmar is a zeppelin (free), and Wuber's
	-- Confirm works out the real way from wherever the tour stands
	for k, v in pairs(extra or {}) do r[k] = v end
	local t = K.tour()
	if t then t.rides[r.id] = true end
	stub(W, "ride", r)
	return r
end

local function demoDrivers()
	local t0 = now()
	return {
		[DEMO_FOUNDER_KEY] = { name = DEMO_FOUNDER, key = DEMO_FOUNDER_KEY, dest = "Undercity", price = 5000, state = "open", team = 3,
			service = "Nia's Portals", heard = t0, ver = "2.3.0", badge = "skull" },
		["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Undercity", price = 5000, state = "open", team = 3,
			service = "Mia's Rides", heard = t0, ver = "2.3.0", badge = "bolt" },
		["bob stone"] = { name = "Bob Stone", key = "bob stone", dest = "Ratchet", price = 6000, state = "open", team = 1,
			service = "Bob's Rides", heard = t0, badge = "star" },
		["ivy moss"] = { name = "Ivy Moss", key = "ivy moss", dest = "Booty Bay", price = 7500, state = "busy", team = 2,
			service = "Ivy's Express", heard = t0, queue = 2, badge = "flame" },
	}
end

-- what riders want (W.Bounty.Demand), for the World view's coins and the driver's demand card
local DEMAND = {
	{ place = "Gadgetzan", riders = 3, low = 4000, high = 6000, newest = 120 },
	{ place = "Booty Bay", riders = 2, low = 5000, high = 5000, newest = 600 },
	{ place = "Thunder Bluff", riders = 1, low = 3000, high = 3000, newest = 1500 },
}

local function bounty(W, mine, demand)
	local B = W.Bounty
	if type(B) ~= "table" then return end
	if fn(B, "Mine") then stub(B, "Mine", function() return mine end) end
	if fn(B, "Demand") then stub(B, "Demand", function() return demand or {} end) end
end

-- A rider who rides in the evenings: six rides last week, five last month (for Wrapped). Replaces
-- W.db.rides for the tour (WuberDB is put back exactly afterwards).
local function riderHistory(W)
	if type(W.db) ~= "table" or not once("history") then return end
	local t = epoch()
	local base = type(date) == "function" and call(date, "*t", t) or nil
	local function at(y, m, d, h, fallback)
		if type(base) ~= "table" then return fallback end
		local ok, v = pcall(time, { year = y, month = m, day = d, hour = h, min = 10 })
		return (ok and num(v)) or fallback
	end
	local rides = {}
	for i = 1, 6 do
		rides[#rides + 1] = { dest = "Undercity", driver = "Mia Runner", driverKey = "mia runner", price = 5000, saved = 600,
			savedValue = 9000, stars = 5,
			at = at(base and base.year, base and base.month, base and (base.day - i), 19 + (i % 3), t - i * 86400) }
	end
	local py, pm = base and base.year or 2026, (base and base.month or 11) - 1
	if pm < 1 then pm, py = 12, py - 1 end
	for i = 1, 5 do
		local even = i % 2 == 0
		rides[#rides + 1] = { dest = even and "Ratchet" or "Undercity", driver = even and "Bob Stone" or "Mia Runner",
			driverKey = even and "bob stone" or "mia runner", price = 5000, saved = 600, stars = 5,
			at = at(py, pm, i * 5, 20, t - (25 + i) * 86400) }
	end
	stub(W.db, "rides", rides)
	local tr = K.tour()
	if tr then tr.wrapMonth = { py, pm } end
	if fn(W, "RebuildTotals") then pcall(W.RebuildTotals) end
	-- (round 13, I33) the milestones these rides earned by Wuber's own tests (Hour Saver after an hour
	-- saved), and the levels they reached: nothing locked that the numbers on screen have earned
	local ms = {}
	local okS, s = pcall(W.Stats)
	local tier = 0
	if okS and type(s) == "table" then
		for _, m in ipairs(type(W.MILESTONES) == "table" and W.MILESTONES or {}) do
			local okT, earned = pcall(m.test, s)
			if okT and earned == true and m.id then ms[m.id] = t - 3600 end
		end
		if fn(W, "Tier") then tier = num(call(W.Tier, s.rides)) or 0 end
		for i = 1, tier do ms["tier" .. i] = t - 3600 end
	end
	stub(W.db, "milestones", ms)
	stub(W.db, "tierSeen", tier)
end

local function homeBase(W, drivers, mine)
	if type(W.db) == "table" then W.db.coach, W.db.openMapHint, W.db.tipPct = true, true, 0 end
	riderHistory(W)
	stub(W, "drivers", drivers or {})
	stub(W, "incoming", {})
	stub(W, "ride", nil)
	stub(W, "tradeOpen", false)
	stub(W, "SummonerMapOK", function() return true end)
	stub(W, "AlreadyAt", function() return nil end) -- (wherever the tester stands, the demo rider is elsewhere)
	stub(W, "IsCreator", function(k) return k == DEMO_FOUNDER_KEY end)
	stub(W, "FounderSummon", function() return false end)
	stub(W, "InGroup", function() return false end)
	bounty(W, mine, DEMAND)
	if fn(W.UI, "SetSearch") then W.UI.SetSearch(mine and mine.place or "") end
	if type(W.UI.state) == "table" then W.UI.state.manual, W.UI.state.confirmKey = "home", nil end
end

local function foundBase(W)
	homeBase(W, demoDrivers())
	if fn(W.UI, "SetSearch") then W.UI.SetSearch("") end
end

---------------------------------------------------------------------------
-- The driver's demo: a queue, a customer book, a crew, a log
---------------------------------------------------------------------------

local function demoQueue()
	local t0 = now()
	return {
		{ name = "Dan Rider", key = "dan rider", state = "joined", source = "whisper", msg = "summon to org pls", at = t0 - 40, price = 5000, paid = 0 },
		{ name = "Eve Night", key = "eve night", state = "arrived", source = "wuber", wuberRide = "abcdef", at = t0 - 90, price = 5000, paid = 0 },
		{ name = "Gus Hill", key = "gus hill", state = "lead", source = "public", msg = "summon to UC?", at = t0 - 10, wantsPrice = true },
	}
end

local function demoBook()
	local t = epoch()
	return {
		["dan rider"] = { name = "Dan Rider", note = "Tips well, always Orgrimmar. Asked about Pioneers.", noteAt = t - 3600, gift = t - 2 * 86400 },
		["fay storm"] = { name = "Fay Storm", note = "Friend of Bea's guild", noteAt = t - 5 * 86400 },
	}
end

local function keyOf(n) return (tostring(n or ""):lower():gsub("[%s%-]+", " ")) end

-- (round 13, I33) the tour's one driving log (PhotoDemo.lua), in place of the real one (WuberDB is put
-- back after the tour): Earnings, Customers, the queue's "11th ride with you", today's takings and the
-- shift card all come from it through Wuber's own functions, so they agree. -> log, info
local function demoLog(W)
	local DR = W.Drive
	local t = K.tour()
	if not t or type(DR) ~= "table" or not fn(DR, "Log") or not L.PhotoDemoLog then return nil end
	if not t.demoLog then
		pcall(DR.Log) -- (makes W.db.drive where there is none yet)
		t.demoLog, t.demoInfo = L.PhotoDemoLog(epoch(), W.myKey)
		-- a target the demo's evenings reach in their best hours (the chart's line)
		local o = fn(DR, "opts") and call(DR.opts)
		if type(o) == "table" then stub(o, "target", 20000) end
	end
	local d = type(W.db) == "table" and W.db.drive
	if type(d) ~= "table" then return nil end
	-- t.alt: a shot with its own log (earnings_empty, earnings_tips). The Customers and Cut
	-- stubs ask for the demo log all the time, and each ask used to put the full one back (the real game's
	-- "empty" Earnings showed 65 rides): while t.alt is set it is the log, until L.PhotoReset clears it.
	local want = t.alt or t.demoLog
	if d.log ~= want then
		stub(d, "log", want)
		if fn(W, "Fire") then pcall(W.Fire, "DRIVE_LOG") end -- (cached ride counts forget the real log)
	end
	-- the demo's shift stays the last one (an open console starts a new one)
	local sh = t.demoInfo and t.demoInfo.shift
	if sh and not t.alt then t.demoLog.shift = { start = sh.start, stop = sh.stop, seen = sh.stop } end
	if t.alt then return want, nil end
	return t.demoLog, t.demoInfo
end

local function myName() return DEMO_ME end

-- this shift's clicker cut (DR.Cut) and the card's fair split (D.lastShift.cut): the demo shift's casts
-- and clicks, shared by Wuber's own rule over everything the crew took in it (PhotoDemo.lua)
local function cutRows(W)
	local l, info = demoLog(W)
	if not (l and info and L.PhotoDemoCut) then return {}, "clicks", 40 end
	return L.PhotoDemoCut(W, l, info, myName(W))
end

-- Customers: everyone in the demo log and the demo book; the rides are Wuber's own count from the log
local function demoCustomers(W, book, filter)
	local DR = W.Drive
	local l = demoLog(W)
	local names = {}
	for _, list in ipairs(l and { l.rides, l.team } or {}) do
		for _, line in ipairs(list) do
			local name = tostring(line):match("^%d+,%d+,([^,]+)")
			if name then names[keyOf(name)] = name end
		end
	end
	for k, rec in pairs(book) do names[k] = names[k] or rec.name end
	filter = str(filter) and str(filter):lower() or nil
	local out = {}
	for k, name in pairs(names) do
		if not filter or name:lower():find(filter, 1, true) then
			local f = fn(DR, "CustomerFacts") and call(DR.CustomerFacts, name) or {}
			local rec = book[k] or {}
			local rides = num(type(f) == "table" and f.rides) or 0
			if rides > 0 or rec.note or rec.gift then
				out[#out + 1] = { key = k, name = name, rides = rides, last = f.last, place = f.place, note = rec.note, gift = rec.gift, noteAt = rec.noteAt }
			end
		end
	end
	table.sort(out, function(a, b)
		local x, y = a.last or 0, b.last or 0
		if x ~= y then return x > y end
		return a.name < b.name
	end)
	return out
end

local function crewList(W, helper, myShards)
	local me = DEMO_ME
	return { { name = me, key = W.myKey, role = helper and "helper" or "lock", app = true, here = true, heard = true, me = true, captain = not helper, shards = (not helper) and (myShards or 12) or nil },
		{ name = "Vex Ember", key = "vex ember", role = "lock", app = true, here = true, heard = true, shards = 14 },
		{ name = "Nyla Frost", key = "nyla frost", role = "lock", app = true, here = true, heard = true, shards = 9 },
		{ name = "Bea Jones", key = "bea jones", role = "helper", app = true, here = true, heard = true } }
end

local function driverBase(W)
	local DR, D, UI = W.Drive, W.Driver, W.UI
	if type(DR) ~= "table" or type(D) ~= "table" then return "W.Drive / W.Driver are missing" end
	if not fn(UI, "ShowDrive") then return "W.UI.ShowDrive is missing" end
	stub(W, "IsWarlock", function() return true end)
	stub(W, "InGroup", function() return false end)
	stub(DR, "Lock", function() return nil end)
	stub(DR, "Role", function() return "driver" end)
	stub(DR, "Active", function() return true end)
	stub(DR, "Mode", function() return "sell" end)
	stub(DR, "Stations", function() return {} end)
	stub(DR, "IsPaused", function() return false end)
	stub(DR, "Readiness", function() return {} end) -- (no "Ready to drive?" card in the shots)
	stub(DR, "CanRunRaid", function() return true end)
	stub(DR, "Summoners", function() return { W.myKey or "anita lift" } end)
	stub(DR, "Shards", function() return 12 end)
	stub(DR, "DangerLevel", function() return 0 end)
	stub(DR, "IsCaptain", function() return true end)
	stub(DR, "Captain", function() return DEMO_ME end)
	stub(DR, "Crew", function() return crewList(W) end)
	local book = demoBook()
	demoLog(W)
	-- (as Wuber's DR.Cut: rows, the rule, { gold, pct, since, stop })
	stub(DR, "Cut", function()
		local rows, rule, pct, gold = cutRows(W)
		local _, info = demoLog(W)
		local sh = info and info.shift or {}
		return rows, rule, { gold = gold or 0, pct = pct, since = sh.start, stop = sh.stop }
	end)
	stub(DR, "BookEntry", function(name) return book[keyOf(name)] end)
	stub(DR, "BookOwn", function(k) return k == "vex ember" end)
	stub(DR, "Customers", function(filter) return demoCustomers(W, book, filter) end)
	-- (round 13, I33) the queue's "11th ride with you": the rides before this one, as Customers counts them
	stub(DR, "RideCount", function(name)
		local f = fn(DR, "CustomerFacts") and call(DR.CustomerFacts, name)
		if type(f) ~= "table" then return 0 end
		return num(f.rides) or 0, f.last
	end)
	stub(DR, "GetAppState", function(c)
		if type(c) ~= "table" then return "none" end
		if c.source == "wuber" or c.wuberRide then return "app" end
		return "ok"
	end)
	bounty(W, nil, {})
	if fn(W, "Char") then
		local c = W.Char()
		if type(c) == "table" then c.wizard = true end
	end
	if type(W.db) == "table" then W.db.holdTip, W.db.coach = true, true end
	return true
end

-- a harmless macro for the secure big button (never casts; not the sim mode's own line)
local NOOP = "/stopmacro [nocombat,combat]"

local function plan(DR, p)
	stub(DR, "Plan", function()
		local x = { marks = {} }
		for k, v in pairs(p) do x[k] = v end
		if x.type == "macro" then x.macrotext = NOOP end
		return x
	end)
	if type(DR.Button) == "table" and fn(DR.Button, "Refresh") and not L.InCombat() then DR.Button.Refresh() end
end

local function console(W, opts)
	local DR, D, UI = W.Drive, W.Driver, W.UI
	local base = driverBase(W)
	if base ~= true then return base end
	local cs = opts.queue or {}
	local byKey = {}
	for _, c in ipairs(cs) do byKey[c.key] = c end
	stub(DR, "customers", byKey)
	stub(DR, "Sorted", function() return cs end)
	stub(DR, "IsOpen", function() return opts.open == true end)
	stub(DR, "SkipTarget", function() if opts.open and cs[1] then return cs[1], "cast" end return nil end)
	if opts.demand then bounty(W, nil, DEMAND) end
	if opts.danger then stub(DR, "DangerLevel", function() return opts.danger, 40 end) end
	plan(DR, opts.plan)
	if not openApp(W) then return "W.UI.Show is missing" end
	closeOverlays(W)
	closeSheets(W)
	if fn(UI, "SelectTab") and not (type(UI.state) == "table" and UI.state.tab == "Drive") then
		if UI.SelectTab("Drive") == false then return "no Drive tab" end
	end
	UI.ShowDrive("console")
	driveRefresh(W)
	return true
end

-- (round 13, I13) while the big button summons Dan, his row says so too ("summoning (you)")
-- caster: who is casting (default me); "vex ember" for the states that say Vex Ember is casting
local function summoningDan(W, caster)
	local q = demoQueue()
	q[1].state, q[1].caster = "summoning", caster or W.myKey or "anita lift"
	return q
end

local function openConsole(W, extra)
	local o = { open = true, queue = demoQueue(),
		plan = { type = "macro", color = "go", title = "Summon Dan", sub = "click: targets and casts  -  12 shards" } }
	for k, v in pairs(extra or {}) do o[k] = v end
	return console(W, o)
end

local function driveScreen(W, name)
	local D = W.Driver
	closeSheets(W)
	if fn(D, "ShowScreen") then D.ShowScreen(name) elseif not W.UI.ShowDrive(name) then return "no " .. name .. " screen" end
	driveRefresh(W)
	return true
end

local function earningsScreen(W)
	local d = type(W.UI.drive) == "table" and W.UI.drive
	local e = d and type(d.screens) == "table" and d.screens.earnings
	return type(e) == "table" and e or nil
end

-- mode: false (the full demo log), "empty" (a new driver: nothing logged) or "sparse" (a little history: the
-- "Open a few hours" and "Try ..." tips). The log is the tour's t.alt, so the Customers / Cut
-- stubs can't put the full demo back (the real game showed the full week for "empty"), and the heatmap's
-- tapped square from the shot before is let go.
local function earningsBase(W, mode)
	local empty = mode == "empty"
	local DR = W.Drive
	local tour = K.tour()
	if tour and mode then
		local alt = { v = 1, rides = {}, team = {}, asks = {}, open = {}, seen = {}, wreq = {}, wdec = {}, rivals = {}, raid = {} }
		if mode == "sparse" and L.PhotoSparseLog then alt = L.PhotoSparseLog(epoch()) end
		tour.alt = alt
	end
	local r = console(W, { open = false, queue = {}, plan = { color = "off", title = "Closed", sub = "" } })
	if r ~= true then return r end
	-- (round 13, I33) Wuber's own sums over the demo log (driverBase put it in place): the summary, the
	-- bars, the heatmap and the best and missed hours all come from the same rides. A new driver: an
	-- empty log (the console's "today" says nothing too; the next driver shot has the demo log back)
	if mode then
		demoLog(W) -- (puts t.alt in place)
		stub(DR, "Cut", function() return {}, "clicks", { gold = 0, pct = 40 } end)
	end
	local ok = driveScreen(W, "earnings")
	if ok ~= true then return ok end
	local e = earningsScreen(W)
	-- (round 13, I15) the 7 days tab: the bars, the summary and the 7-day heatmap cover the same days
	if e and mode then
		for _, hm in ipairs({ e.heat or false, e.heatW or false }) do
			if type(hm) == "table" then
				hm.picked, hm.pickedAt = nil, nil
				if type(hm.sel) == "table" and fn(hm.sel, "Hide") then hm.sel:Hide() end
			end
		end
	end
	if e and not empty then
		e.range = "week"
		if type(e.seg) == "table" and fn(e.seg, "SetValue") then e.seg:SetValue("week") end
	end
	if e and type(e.update) == "function" then pcall(e.update) end
	return true, e
end

local function scrollTo(e, bottom)
	if type(e) == "table" and type(e.scroll) == "table" and fn(e.scroll, "ScrollTo") then
		e.scroll:ScrollTo(bottom and (e.scroll.max or 9999) or 0, true)
	end
end

-- (round 13, I34) taps the best full hour on the heatmap that is shown (unfolded, the side pane has its
-- own): after the Fold is applied, so the unfolded shot has its square tapped too
local function tapHour(W)
	local e = earningsScreen(W)
	if not e then return "no Earnings screen" end
	local hm = e.heat
	if type(e.heatW) == "table" and fn(e.heatW, "IsShown") and e.heatW:IsShown() then hm = e.heatW end
	local cells, grid = type(hm) == "table" and hm.cells, type(hm) == "table" and hm.grid
	if type(cells) ~= "table" or type(grid) ~= "table" then return "no heatmap" end
	local best, bestPer
	for _, b in ipairs(cells) do
		local c = type(b) == "table" and grid[b.wday] and grid[b.wday][b.hour]
		local open = c and num(c.open) or 0
		if open >= 45 then
			local per = (num(c.copper) or 0) / (open / 60)
			if not bestPer or per > bestPer then best, bestPer = b, per end
		end
	end
	if not (best and fn(best, "GetScript")) then return "no square to tap" end
	local click = best:GetScript("OnClick")
	if type(click) ~= "function" then return "the square can't be tapped" end
	click(best, "LeftButton", false)
	return true
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

local function panel(W) return mod(W, "UI.Settings.Panel") end

local function settings(W, fnc)
	local UI = W.UI
	if not fn(UI, "OpenSettings") then return "W.UI.OpenSettings is missing" end
	if not openApp(W) then return "W.UI.Show is missing" end
	closeSheets(W)
	if fn(UI, "HelpShown") and UI.HelpShown() and fn(UI, "CloseHelp") then UI.CloseHelp(true) end
	if type(W.Char) == "function" and type(W.Char()) == "table" then W.Char().wizard = true end
	if not UI.OpenSettings() then return "settings didn't open" end
	local P = panel(W)
	if P and fn(P, "search") then P.search("") end
	if fnc then return fnc(UI, P) end
	return true
end

local function settingsScrolled(W)
	local st = W.UI.settings
	if type(st) ~= "table" or not num(st.scroll) or not num(st.scrollTarget) then return true end
	return math.abs(st.scroll - st.scrollTarget) < 1
end

---------------------------------------------------------------------------
-- The shots, in order (the README's list)
---------------------------------------------------------------------------

-- Settings' own search, then its first match with this name opened and scrolled to (as a tap on it)
function L.PhotoOpenSetting(UI, P, label)
	if not (P and fn(P, "search") and fn(P, "openResult")) then return "no settings search" end
	P.search(label)
	local f = UI and type(UI.settings) == "table" and type(UI.settings.find) == "table" and UI.settings.find
	local m
	for _, x in ipairs(f and type(f.list) == "table" and f.list or {}) do
		if type(x) == "table" and x.label == label then m = x break end
	end
	if not m then return "no setting called " .. label end
	P.openResult(m)
	return true
end

-- the Customers page's right pane for a rider: its own picked row
function L.PhotoPickCustomer(W, name)
	local d = type(W.UI.drive) == "table" and W.UI.drive
	local s = d and type(d.screens) == "table" and d.screens.customers
	if type(s) ~= "table" or type(s.update) ~= "function" then return "no Customers screen" end
	s.picked = name
	s.update()
	return true
end


---------------------------------------------------------------------------
-- (job 041) The launch video's shots: the passphrase, a non-Warlock's summoner, /wuber test,
-- OpenMap's world map, "Skip the bird"
---------------------------------------------------------------------------

-- the demo ride both passphrase shots share: the rider (this window) and the driver's row see the same words
local PASS_RIDE = "labphotopass"

-- the queue row for this rider's name (folded or unfolded), shown and visible, or nil
local function queueRow(W, name)
	local D = W.Driver
	local v = type(D.ui) == "table" and D.ui.console
	for _, list in ipairs({ type(v) == "table" and v.rows, type(v) == "table" and v.sideRows }) do
		if type(list) == "table" then
			for _, r in ipairs(list) do
				if type(r) == "table" and type(r.c) == "table" and r.c.name == name and fn(r, "IsVisible") and r:IsVisible() then return r end
			end
		end
	end
	return nil
end

-- A runner who isn't a Warlock: two Warlocks in the crew summon (Vex Ember is "my account", an alt). For
-- this shot only (the next driver shot's driverBase, or L.PhotoReset, puts the Warlock back).
local function notLock(W)
	local DR = W.Drive
	shotStub(W, "IsWarlock", function() return false end)
	shotStub(DR, "Role", function() return "driver" end)
	shotStub(DR, "Crew", function() return crewList(W, true) end)
	shotStub(DR, "Summoners", function() return { "vex ember", "nyla frost" } end)
	shotStub(DR, "Shards", function() return 0 end)
	shotStub(DR, "BookOwn", function(k) return k == "vex ember" end)
end

-- the Drive tab's setup (the crew wizard) as built (W.Driver.ui.subs, "for tests"), or nil
local function wizardScreen(W)
	local ui = type(W.Driver) == "table" and W.Driver.ui
	local w = type(ui) == "table" and type(ui.subs) == "table" and ui.subs.wizard
	return (type(w) == "table" and type(w.paint) == "function") and w or nil
end

-- for this shot, the setup's enter also picks a step-one card (as a tap would), so Wuber's own first paint
-- shows it (a paint later, during the slide-in's alpha animation, would set alphas the game doesn't draw)
local function pickOnEnter(W, choice)
	local function wrap(w)
		local enter = w.enter
		if type(enter) ~= "function" then return end
		shotStub(w, "enter", function(...)
			enter(...)
			if w.step == 1 then w.choice = choice end
		end)
	end
	local w = wizardScreen(W)
	if w then return wrap(w) end
	local D = W.Driver
	local maker = type(D) == "table" and type(D.screens) == "table" and D.screens.wizard
	if type(maker) ~= "function" then return end
	shotStub(D.screens, "wizard", function(...)
		local s = maker(...)
		if type(s) == "table" then wrap(s) end
		return s
	end)
end

-- the setup at a step (Wuber's own D.ShowScreen: enter, paint, slide in). Called from a shot's post, once the
-- Drive tab's fade has settled (the setup's paint under it would set alphas the game doesn't draw).
local function wizardAt(W, step, choice)
	if choice then pickOnEnter(W, choice) end
	if not W.UI.ShowDrive("wizard", step == 3 and 3 or nil) then return "no setup screen" end
	if not wizardScreen(W) then return "no setup screen" end
	return true
end

-- OpenMap (OpenMapAPI major 1: docs/api.md in OpenMap): only its read calls and ShowWorld (glide the view)
local function omAPI()
	local api = rawget(_G, "OpenMapAPI")
	if type(api) ~= "table" or api.major ~= 1 then return nil end
	for _, k in ipairs({ "IsStitched", "WorldFromMap", "GetView", "ShowWorld" }) do
		if not fn(api, k) then return nil end
	end
	return api
end

local function needOpenMap(W)
	if not omAPI() then return "OpenMap isn't loaded" end
	if not (type(W.Map) == "table" and fn(W.Map, "Refresh")) then return "W.Map.Refresh is missing" end
	if not (fn(W, "ExactPlace") and fn(W, "PlaceWorld")) then return "W.ExactPlace / W.PlaceWorld are missing" end
	if not worldMap() then return "the game has no world map" end
	return true
end

-- hubs on both continents: the demo drivers stand at the first four on the player's own continent
local MAP_SPOTS = { "Tarren Mill", "Undercity", "Grom'gol", "Hammerfall", "Kargath", "Stonard", "Booty Bay",
	"Crossroads", "Ratchet", "Camp Mojache", "Splintertree Post", "Sun Rock Retreat", "Gadgetzan" }

local function uvOf(api, mapID, x, y)
	if not (mapID and x and y) then return nil end
	local ok, u, v = pcall(api.WorldFromMap, mapID, x, y)
	u, v = ok and num(u) or nil, ok and num(v) or nil
	if u and v then return u, v end
	return nil
end

-- -> spots { { place, u, v } } (the 4 nearest the player on their continent, on OpenMap's map, not where
-- the player stands), me { m, x, y, u, v } (nil where the position can't be read: an instance)
local function mapSpots(W, api)
	local me
	if fn(W, "MyPosition") then
		local m, x, y = call(W.MyPosition)
		m, x, y = num(m), num(x), num(y)
		if m and x and y then
			local u, v = uvOf(api, m, x, y)
			me = { m = m, x = x, y = y, u = u, v = v, cont = fn(W, "WorldPos") and num((call(W.WorldPos, m, x, y))) or nil }
		end
	end
	local out, cont = {}, me and me.cont
	for _, name in ipairs(MAP_SPOTS) do
		local p = call(W.ExactPlace, name)
		if type(p) == "table" then
			local pc = num((call(W.PlaceWorld, p)))
			local u, v = uvOf(api, num(p.mapID), num(p.x), num(p.y))
			if pc and u and (not cont or pc == cont) then
				cont = cont or pc
				local d = (me and me.u) and math.abs(u - me.u) + math.abs(v - me.v) or #out
				if d > 0.01 then out[#out + 1] = { place = p, u = u, v = v, d = d } end
			end
		end
	end
	table.sort(out, function(a, b) return a.d < b.d end)
	-- (L1) a hub within 0.03 of a nearer one is left out: pins that close would stack on one blur
	local kept = {}
	for _, s in ipairs(out) do
		local near = false
		for _, k in ipairs(kept) do if math.abs(s.u - k.u) + math.abs(s.v - k.v) < 0.03 then near = true end end
		if not near then kept[#kept + 1] = s end
	end
	out = kept
	for i = #out, 5, -1 do out[i] = nil end
	return out, me
end

-- the demo drivers, each at a spot: Mia, the route's driver, at the farthest of them (a longer line), the
-- others nearest first; those without a spot go. -> drivers, Mia's spot
local function mapDrivers(spots)
	local ds = demoDrivers()
	local order = { DEMO_FOUNDER_KEY, "bob stone", "ivy moss" }
	table.insert(order, math.min(#spots, 4), "mia runner")
	for i, key in ipairs(order) do
		local d, s = ds[key], spots[i]
		if s then
			d.mapID, d.x, d.y, d.dest = num(s.place.mapID), num(s.place.x), num(s.place.y), s.place.name
			s.who = d.name
		else
			ds[key] = nil
		end
	end
	return ds, spots[math.min(#spots, 4)]
end

-- the world map open (Wuber's window shut) with the demo drivers' pins; withRide: Mia booked to her
-- spot, so Wuber draws the route from the player to her
local function mapBase(W, withRide)
	local api = omAPI()
	if not api then return "OpenMap isn't loaded" end
	local spots, me = mapSpots(W, api)
	if #spots == 0 then return "no Wuber place on OpenMap's map on this continent" end
	if withRide and not (me and me.u) then return "your position can't be read here (an instance?): no route to draw" end
	local ds, mia = mapDrivers(spots)
	homeBase(W, ds)
	if type(W.db) == "table" then W.db.mapPins = true end
	stub(W.Map, "focus", nil)
	local t = K.tour()
	if t then t.omView, t.omLast, t.omSpots, t.omMe, t.omMia, t.omFits, t.omWinNoted, t.omPosted = nil, nil, spots, me, mia, 0, nil, nil end
	if withRide then demoRide(W, "accepted", { dest = mia.place.name, acceptedAt = now() - 20 }) end
	if fn(W.UI, "IsShown") and W.UI.IsShown() and fn(W.UI, "Toggle") then W.UI.Toggle(false) end
	if not openWorldMap() then return "the world map didn't open" end
	-- (job 042) the whole window on the screen, the quest list out of the way (put back after the shot)
	local okF, note = pcall(omFit)
	note = okF and note or ("couldn't fit OpenMap's window: " .. tostring(note))
	if note then L.Log("photo", (withRide and "openmap_route" or "openmap_pins") .. ": " .. note) end
	W.Map.Refresh()
	return true
end

-- once the map is up: OpenMap's own map must be showing; the view glides to frame the pins (withRide:
-- the player and Mia's spot)
local OM_MIN_SPAN = 0.15   -- (pins shot) the least of the stitched world (0..1) a frame may show
local OM_MAX_ZOOM = 3       -- the most OpenMap zoom a shot may use (past it the map is a blur)
local OM_MIN_SPREAD = 0.15  -- the pins' box (its longer side) must be at least this share of the visible map's smaller side
local function mapPost(W, withRide)
	local api = omAPI()
	if not api then return "OpenMap went away" end
	local okS, on = pcall(api.IsStitched)
	if not (okS and on) then return "the world map isn't OpenMap's (its own map is switched off?)" end
	local t = K.tour()
	local spots = t and t.omSpots or {}
	local u0, v0, u1, v1
	local function add(u, v)
		u0, u1 = math.min(u0 or u, u), math.max(u1 or u, u)
		v0, v1 = math.min(v0 or v, v), math.max(v1 or v, v)
	end
	for _, s in ipairs(spots) do if not withRide or s == t.omMia then add(s.u, s.v) end end
	if withRide and t.omMe and t.omMe.u then add(t.omMe.u, t.omMe.v) end
	if not u0 then return "nothing to show" end
	-- (L1) the whole area that holds the pins, as the route shot does: never framed tighter than OM_MIN_SPAN
	-- of the world, never zoomed past OM_MAX_ZOOM
	-- the route shot keeps its old framing (zoom 2..8)
	local zoom = math.max(1, math.min(OM_MAX_ZOOM, 0.45 / math.max(u1 - u0, v1 - v0, OM_MIN_SPAN)))
	if withRide then zoom = math.max(2, math.min(8, 0.45 / math.max(u1 - u0, v1 - v0, 0.04))) end
	local u, v = (u0 + u1) / 2, (v0 + v1) / 2
	local ok, moved = pcall(api.ShowWorld, u, v, zoom)
	if not (ok and moved) then return "OpenMap didn't move the view" end
	t.omView, t.omPosted = { u, v, zoom }, true
	W.Map.Refresh()
	return true
end

-- the glide has ended: the view is where it was sent, or it has stopped moving
local function viewSettled()
	local t = K.tour()
	local want, api = t and t.omView, omAPI()
	if not (want and api) then return true end
	local ok, u, v, z = pcall(api.GetView)
	u, v, z = ok and num(u) or nil, ok and num(v) or nil, ok and num(z) or nil
	if not (u and v and z) then return true end
	local last = t.omLast
	t.omLast = { u, v, z }
	if math.abs(u - want[1]) < 0.002 and math.abs(v - want[2]) < 0.002 and math.abs(z - want[3]) < 0.02 * want[3] then return true end
	return last ~= nil and math.abs(u - last[1]) < 1e-5 and math.abs(v - last[2]) < 1e-5 and math.abs(z - last[3]) < 1e-4
end

-- (job 042) Where a point of the stitched world (u, v) is on the screen, in pixels: OpenMap's own
-- MapFromWorld onto the canvas Wuber draws its pins and route on (as Wuber's UI.Map places them)
local function rectPx(f)
	if type(f) ~= "table" then return nil end
	local function get(k)
		if not fn(f, k) then return nil end
		local ok, v = pcall(f[k], f)
		return ok and num(v) or nil
	end
	local l, r, t, b, e = get("GetLeft"), get("GetRight"), get("GetTop"), get("GetBottom"), get("GetEffectiveScale")
	if not (l and r and t and b and e and e > 0) then return nil end
	return { l = l * e, r = r * e, t = t * e, b = b * e }
end

local function toScreen(api, m, u, v)
	local sc = m.ScrollContainer
	local c = rectPx(type(sc) == "table" and sc.Child or nil)
	local okID, id = pcall(m.GetMapID, m)
	id = okID and num(id) or nil
	if not (c and id and u and v) then return nil end
	local ok, cx, cy = pcall(api.MapFromWorld, id, u, v)
	cx, cy = ok and num(cx) or nil, ok and num(cy) or nil
	if not (cx and cy) then return nil end
	return c.l + cx * (c.r - c.l), c.t - cy * (c.t - c.b)
end

-- the part of the map's view that is on the screen and not under the quest list (pixels), or nil
local function visibleRect(m)
	local v, s = rectPx(m.ScrollContainer), rectPx(UIParent)
	if not (v and s) then return nil end
	v = { l = math.max(v.l, s.l), r = math.min(v.r, s.r), t = math.min(v.t, s.t), b = math.max(v.b, s.b) }
	local q = m.QuestLog
	if type(q) == "table" and fn(q, "IsShown") and q:IsShown() then
		local qr = rectPx(q)
		if qr and qr.l < v.r and qr.r > v.l then v.r = math.min(v.r, qr.l) end
	end
	if v.r - v.l < 60 or v.t - v.b < 60 then return nil end
	return v
end

-- what the shot must show: { label, u, v }: the four pins, or the route's two ends (you and Mia)
local function omPoints(withRide)
	local t = K.tour()
	local out = {}
	if not t then return out end
	if withRide then
		if t.omMe and t.omMe.u then out[#out + 1] = { "you", t.omMe.u, t.omMe.v } end
		local mia = t.omMia
		if mia then out[#out + 1] = { "Mia Runner at " .. tostring(mia.place.name), mia.u, mia.v } end
	else
		for _, s in ipairs(t.omSpots or {}) do out[#out + 1] = { tostring(s.who or "a pin") .. " at " .. tostring(s.place.name), s.u, s.v } end
	end
	return out
end

-- the points on the screen: list of { label, x, y }, their box, and the visible rect; nil, why
local function omMeasure(withRide)
	local api, m = omAPI(), worldMap()
	if not (api and m) then return nil, "OpenMap or the world map went away" end
	local vis = visibleRect(m)
	if not vis then return nil, "the visible map couldn't be measured" end
	local pts, box = {}, nil
	for _, p in ipairs(omPoints(withRide)) do
		local x, y = toScreen(api, m, p[2], p[3])
		if not x then return nil, p[1] .. " has no place on the screen" end
		pts[#pts + 1] = { p[1], x, y }
		box = box or { l = x, r = x, b = y, t = y }
		box.l, box.r, box.b, box.t = math.min(box.l, x), math.max(box.r, x), math.min(box.b, y), math.max(box.t, y)
	end
	if not box then return nil, "nothing to show" end
	return pts, box, vis, api, m
end

local FIT_TRIES = 4      -- views asked for at most, per shot
local FIT_PAD = 0.12     -- the margin kept clear inside the visible map (a share of its smaller side; 40 px at least)

-- once OpenMap's view has settled: every point inside the visible map less a margin -> true (shoot); else
-- one better view is asked for (OpenMapAPI.ShowWorld: the box of the points centred, zoomed to fit) -> false
local function omReady(withRide)
	if not viewSettled() then return false end
	local t = K.tour()
	if not (t and t.omPosted) then return true end -- (the settle before mapPost's first view: nothing to frame yet)
	local pts, box, vis, api, m = omMeasure(withRide)
	if not pts then return true end -- (the shot's check says why)
	if not t.omWinNoted then
		t.omWinNoted = true
		local r, s = rectPx(m), rectPx(UIParent)
		if r and s and (r.l < s.l - 1 or r.r > s.r + 1 or r.b < s.b - 1 or r.t > s.t + 1) then
			L.Log("photo", ("OpenMap's window is still partly off the screen (%d..%d x %d..%d px of %d x %d): framed inside its visible part"):format(
				r.l, r.r, r.b, r.t, s.r, s.t))
		end
	end
	local pad = math.max(40, math.min(vis.r - vis.l, vis.t - vis.b) * FIT_PAD)
	local safe = { l = vis.l + pad, r = vis.r - pad, b = vis.b + pad, t = vis.t - pad }
	local inside = box.l >= safe.l and box.r <= safe.r and box.b >= safe.b and box.t <= safe.t
	local bw, bh, sw, sh = box.r - box.l, box.t - box.b, safe.r - safe.l, safe.t - safe.b
	-- (route only) a lone point or a tight box: zoomed in no further than the box filling a third of the view
	local tooSmall = withRide and #pts > 1 and bw < sw * 0.33 and bh < sh * 0.33
	if (inside and not tooSmall) or (t.omFits or 0) >= FIT_TRIES then return true end
	local okV, u, v, z = pcall(api.GetView)
	u, v, z = okV and num(u) or nil, okV and num(v) or nil, okV and num(z) or nil
	if not (u and v and z and z > 0) then return true end
	-- pixels per unit of u and of v at this view (OpenMap's map is flat: two probes)
	local x0, y0 = toScreen(api, m, u, v)
	local x1 = toScreen(api, m, u + 0.01, v)
	local _, y1 = toScreen(api, m, u, v + 0.01)
	if not (x0 and x1 and y1) then return true end
	local kx, ky = (x1 - x0) / 0.01, (y1 - y0) / 0.01
	if math.abs(kx) < 1e-6 or math.abs(ky) < 1e-6 then return true end
	local f = 0.95 * math.min(bw > 1 and sw / bw or 4, bh > 1 and sh / bh or 4)
	local z2 = math.max(1, math.min(withRide and 8 or OM_MAX_ZOOM, z * math.min(f, 4)))
	f = z2 / z
	-- the box's centre on the safe rect's centre; the view's centre stays where it is on the screen
	local cu, cv = u + ((box.l + box.r) / 2 - x0) / kx, v + ((box.b + box.t) / 2 - y0) / ky
	local u2 = cu - ((safe.l + safe.r) / 2 - x0) / (kx * f)
	local v2 = cv - ((safe.b + safe.t) / 2 - y0) / (ky * f)
	t.omFits = (t.omFits or 0) + 1
	local ok, moved = pcall(api.ShowWorld, u2, v2, z2)
	if not (ok and moved) then return true end
	t.omView, t.omLast = { u2, v2, z2 }, nil
	return false
end

-- after the shot: were the pins (or both route ends) inside the visible map? A line for the tour log
local function omCheck(withRide)
	local pts, box, vis = omMeasure(withRide)
	if not pts then return "check: couldn't check the pins (" .. tostring(box) .. ")" end
	local out = {}
	for _, p in ipairs(pts) do
		if p[2] < vis.l or p[2] > vis.r or p[3] < vis.b or p[3] > vis.t then
			out[#out + 1] = ("%s (%d, %d)"):format(p[1], p[2], p[3])
		end
	end
	local what = withRide and "both route ends" or (#pts .. " pins")
	local rect = ("%d..%d x %d..%d px"):format(vis.l, vis.r, vis.b, vis.t)
	local t = K.tour()
	local tries = t and t.omFits or 0
	-- (L1) too close together on screen = an over-zoomed or tiny view (the blur of 20 Nov), or zoomed past the bound
	local apiV = omAPI()
	local okV, _, _, z = pcall(apiV.GetView)
	z = okV and num(z) or nil
	local spread = math.max(box.r - box.l, box.t - box.b) / math.max(1, math.min(vis.r - vis.l, vis.t - vis.b))
	local bad
	if withRide then bad = nil
	elseif z and z > OM_MAX_ZOOM + 0.05 then bad = ("zoomed in too far (%.1f, the most is %d)"):format(z, OM_MAX_ZOOM)
	elseif #pts > 1 and spread < OM_MIN_SPREAD then
		bad = ("too close together on screen (%d%% of the map, the least is %d%%)"):format(spread * 100, OM_MIN_SPREAD * 100)
	end
	if bad and #out == 0 then return ("check: NOT framed: %s (%s)"):format(bad, ("%d..%d x %d..%d px"):format(vis.l, vis.r, vis.b, vis.t)) end
	if #out == 0 then return ("check: %s inside the visible map (%s; %d reframe%s)"):format(what, rect, tries, tries == 1 and "" or "s") end
	return ("check: NOT inside the visible map (%s): %s"):format(rect, table.concat(out, ", "))
end

-- (job 042) The game's flight map. Wuber's own "Skip the bird" card (UI.Bird's mapFrame) looks for
-- TaxiFrame, else FlightMapFrame, shown; the lab looks for the same frames the same way (the card can only
-- stand beside one of them). It also keeps the flight master's events (TAXIMAP_OPENED until
-- TAXIMAP_CLOSED): a map the events say is open while neither frame shows is told apart in the log, with
-- each frame's state, so the frame this client really uses can be read from the tour log.
local TAXI_FRAMES = { "TaxiFrame", "FlightMapFrame" }
local taxiSeen = { open = false }
L.On("TAXIMAP_OPENED", function() taxiSeen.open, taxiSeen.at = true, now() end)
L.On("TAXIMAP_CLOSED", function() taxiSeen.open = false end)

-- the flight map's frame that is showing and its name, else nil and each frame's state
local function flightMap()
	local states = {}
	for _, n in ipairs(TAXI_FRAMES) do
		local f = rawget(_G, n)
		local shown = false
		if type(f) == "table" and fn(f, "IsShown") then
			local ok, v = pcall(f.IsShown, f)
			shown = ok and L.plain(v) == true
		end
		if shown then return f, n end
		states[#states + 1] = n .. (type(f) == "table" and " hidden" or " not loaded")
	end
	return nil, table.concat(states, ", ")
end

local function needBird(W)
	local Bd = mod(W, "UI.Bird")
	if not (Bd and fn(Bd, "Show") and fn(Bd, "Pick") and fn(Bd, "Card") and fn(Bd, "Hide")) then return "UI.Bird is missing (Wuber before 2.3.0)" end
	local f, states = flightMap()
	if f then return true end
	if taxiSeen.open then
		-- (open by the events, in neither frame: the shot tries, and its skip names the frames)
		L.Log("photo", "bird: the flight master's map is open (TAXIMAP_OPENED) but not in " .. states)
		return true
	end
	return "the flight map isn't open (at a flight master: open it, then /lab tour bird; " .. states .. ")"
end

-- Bird.Pick's own rule: flying there is known from here and the summon saves more than 2 minutes
-- after a 2-minute wait (UI.Bird: secs - WAIT > MIN_SAVED)
local BIRD_BEATS = 240
local BIRD_SPOTS = { "Thunder Bluff", "Gadgetzan", "Camp Mojache", "Freewind Post", "Sun Rock Retreat", "Ratchet", "Crossroads",
	"Splintertree Post", "Orgrimmar", "Undercity", "Tarren Mill", "Hammerfall", "Kargath", "Stonard", "Grom'gol", "Booty Bay" }

-- the places a summon beats flying to from this flight master, by Wuber's own lookups (W.FlightCost,
-- W.FlightTime, else W.TravelSaved, as UI.Bird.Pick asks them), longest flight first. -> list, what was seen
local function birdSpots(W)
	local names, seen = {}, {}
	local function add(n) if type(n) == "string" and not seen[n] then seen[n] = true names[#names + 1] = n end end
	for _, n in ipairs(BIRD_SPOTS) do add(n) end
	local tx = type(W.TAXI) == "table" and W.TAXI.nodes
	if type(tx) == "table" then for _, node in pairs(tx) do if type(node) == "table" then add(node[1]) end end end
	local out, notes = {}, {}
	for _, name in ipairs(names) do
		local cost, _, _, via = call(W.FlightCost, nil, name)
		cost = num(cost)
		local secs, src
		if cost and fn(W, "FlightTime") then secs, src = call(W.FlightTime, nil, name) end
		secs = num(secs)
		if cost and not secs and fn(W, "TravelSaved") then secs, src = num((call(W.TravelSaved, name))), "est" end
		if cost and secs and via ~= "boat" then
			if secs > BIRD_BEATS then out[#out + 1] = { name = name, secs = secs, cost = cost } end
			if #notes < 6 then notes[#notes + 1] = ("%s %ds"):format(name, secs) end
		end
	end
	table.sort(out, function(a, b) return a.secs > b.secs end)
	return out, (#notes > 0 and table.concat(notes, ", ") or "no flight known from here")
end

L.PHOTO_SCREENS = {
	-- the rider
	{ id = "home", side = "rider", unfold = true, video = true, title = "Rider home: drivers near you", run = function(W)
		homeBase(W, demoDrivers())
		return rider(W, "home")
	end },
	-- (job 2858) the launch film's and the Short's "drivers online" screen: one founder row and the usual driver
	{ id = "drivers_online_real", side = "rider", unfold = true, video = true, title = "Rider home: drivers online, a founder row and your usual",
		run = function(W)
			local ds = demoDrivers()
			ds["bob stone"], ds["ivy moss"] = nil, nil
			ds[DEMO_FOUNDER_KEY].team = 1
			homeBase(W, ds)
			return rider(W, "home")
		end },
	-- (job 041) the video's line 4: a rider looking for a summon, the drivers to that place listed
	{ id = "home_search", side = "rider", unfold = true, video = true, title = "Rider home: looking for a summon to Undercity, drivers listed",
		run = function(W)
			homeBase(W, demoDrivers())
			if not fn(W.UI, "SetSearch") then return "W.UI.SetSearch is missing" end
			W.UI.SetSearch("Undercity")
			return rider(W, "home")
		end },
	{ id = "home_empty", side = "rider", unfold = true, title = "Rider home, nobody online: when drivers are usually around, bounty, watch",
		run = function(W)
			homeBase(W, {})
			return rider(W, "home")
		end },
	{ id = "home_bounty", side = "rider", unfold = true, title = "Rider home: your bounty for Gadgetzan", run = function(W)
		homeBase(W, {}, { place = "Gadgetzan", copper = 5000, at = epoch() - 120, left = 1680 })
		return rider(W, "home")
	end },
	{ id = "worldmap", side = "rider", only = "unfolded", title = "World view: flight routes, boats and zeppelins, driver pins, bounty coins",
		run = function(W)
			homeBase(W, demoDrivers())
			return rider(W, "home")
		end,
		post = function(W)
			local WM = mod(W, "UI.Rider.WorldMap")
			if not (WM and fn(WM, "Show")) then return "no World view" end
			if not WM.Show("world") then return "the World view isn't built" end
			return true
		end },
	{ id = "confirm", side = "rider", unfold = true, title = "Confirm: flight vs summon, with the coin icons", run = function(W)
		homeBase(W, demoDrivers())
		return rider(W, "confirm", "mia runner")
	end },
	{ id = "portal", side = "rider", title = "Driver found: the portal is up (violet)", run = function(W)
		foundBase(W)
		demoRide(W, "portal", { summonUp = true, acceptedAt = now() - 30 })
		return rider(W, "found")
	end },
	{ id = "portal_founder", side = "rider", title = "A ride from Nia, the founder: the gold portal", run = function(W)
		foundBase(W)
		stub(W, "FounderSummon", function() return true end)
		demoRide(W, "portal", { summonUp = true, acceptedAt = now() - 30, driver = DEMO_FOUNDER, driverKey = DEMO_FOUNDER_KEY,
			payee = DEMO_FOUNDER, payto = "Nia", service = "Nia's Portals" })
		return rider(W, "found")
	end },
	{ id = "tracker", side = "rider", title = "The live portal tracker: one of two clickers tapped", run = function(W)
		foundBase(W)
		demoRide(W, "summoning", { acceptedAt = now() - 40, ritual = { phase = "h", tapped = 1, need = 2, caster = "Mia", at = now() } })
		return rider(W, "found")
	end },
	-- (job 041) the two-word passphrase on the rider's screen (in the driver's group, waiting for the portal);
	-- pass_driver shows the same words on the driver's queue row
	{ id = "pass_rider", side = "rider", video = true, title = "Passphrase on the rider's screen: the two words, \"your driver sees the same words\"",
		run = function(W)
			if not fn(W, "Passphrase") then return "W.Passphrase is missing" end
			foundBase(W)
			demoRide(W, "ingroup", { id = PASS_RIDE, showPass = true, acceptedAt = now() - 25 })
			return rider(W, "found")
		end },
	{ id = "pay", side = "rider", title = "Time to pay: the tip buttons, the arrival Share pill", run = function(W)
		foundBase(W)
		if type(W.db) == "table" then W.db.tipPct = 20 end
		stub(W, "InGroup", function() return true end)
		demoRide(W, "arrived", { acceptedAt = now() - 60, arrivedAt = now() - 5, saved = 600 })
		return rider(W, "found")
	end },
	-- (job 2858) the rider's "You've arrived" (the trade not open yet: "Waiting for Mia to open trade"), then the trade open
	{ id = "arrived", side = "rider", video = true, title = "You've arrived: Pay Mia, waiting for her to open trade", run = function(W)
		foundBase(W)
		if type(W.db) == "table" then W.db.tipPct = 20 end
		stub(W, "InGroup", function() return true end)
		demoRide(W, "arrived", { acceptedAt = now() - 60, arrivedAt = now() - 5, saved = 600 })
		return rider(W, "found")
	end },
	{ id = "pay_trade", side = "rider", video = true, title = "Time to pay: the trade is open, put the fare in", run = function(W)
		foundBase(W)
		if type(W.db) == "table" then W.db.tipPct = 20 end
		stub(W, "InGroup", function() return true end)
		stub(W, "tradeOpen", true)
		demoRide(W, "paying", { acceptedAt = now() - 70, arrivedAt = now() - 15, saved = 600 })
		return rider(W, "found")
	end },
	{ id = "stranger", side = "rider", title = "A stranger's trade: the warning", run = function(W)
		if not fn(W.UI, "TradePartnerOK") then return "W.UI.TradePartnerOK is missing" end
		foundBase(W)
		if type(W.db) == "table" then W.db.tipPct = 20 end
		stub(W, "tradeOpen", true)
		stub(W.UI, "TradePartnerOK", function() return false, "sly fox" end)
		if fn(W, "UnitName") then
			local t = K.tour()
			local orig = t and t.unitName or W.UnitName
			if t then t.unitName = orig end
			stub(W, "UnitName", function(unit, ...)
				if unit == "npc" then return "Sly Fox" end
				return orig(unit, ...)
			end)
		end
		demoRide(W, "arrived", { acceptedAt = now() - 60, arrivedAt = now() - 8 })
		return rider(W, "found")
	end },
	{ id = "done_paid", side = "rider", title = "Done: paid and rated, the Share pill", run = function(W)
		foundBase(W)
		stub(W, "InGroup", function() return true end)
		demoRide(W, "done", { paid = 6000, saved = 600, stars = 5, rated = true })
		return rider(W, "done")
	end },
	{ id = "done_unpaid", side = "rider", title = "Done: not paid", run = function(W)
		foundBase(W)
		demoRide(W, "done", { unpaid = true })
		return rider(W, "done")
	end },
	{ id = "raincheck", side = "rider", title = "A raincheck offered to the rider", run = function(W)
		local R = W.Raincheck
		if not (type(R) == "table" and fn(R, "Mine") and fn(W.UI, "RaincheckOffer")) then return "W.Raincheck.Mine / W.UI.RaincheckOffer are missing" end
		homeBase(W, demoDrivers())
		local t = epoch()
		stub(R, "Mine", function()
			return { { id = "labphotorc", state = "offered", driver = "Mia Runner", service = "Mia's Rides", cover = 5000, expires = t + 7 * 86400 } }
		end)
		local st = W.UI.state
		if type(st) == "table" and type(st.rcSeen) == "table" then st.rcSeen.labphotorc = nil end
		return rider(W, "home")
	end,
		post = function(W)
			if not W.UI.RaincheckOffer() then return "no raincheck card" end
			return true
		end },
	{ id = "trips", side = "rider", unfold = true, title = "Trips: level, milestones, habits", run = function(W) return L.PhotoTrips(W) end },
	{ id = "wrapped", side = "rider", unfold = true, title = "Azeroth Wrapped: the story", run = function(W) return L.PhotoTrips(W) end,
		post = function(W) return L.PhotoWrapped(W, false) end },
	{ id = "wrapped_summary", side = "rider", unfold = true, title = "Azeroth Wrapped: the summary", run = function(W) return L.PhotoTrips(W) end,
		post = function(W) return L.PhotoWrapped(W, true) end },

	-- the driver
	{ id = "console_open", side = "driver", unfold = true, title = "Driver console: open, three riders, the shard fuel gauge", run = function(W)
		return openConsole(W)
	end },
	{ id = "button_summoning", side = "driver", unfold = true, title = "Big button: summoning", run = function(W)
		return openConsole(W, { queue = summoningDan(W), plan = { color = "wait", title = "Summoning Dan", sub = "two clickers on the portal" } })
	end },
	{ id = "button_portal", side = "driver", unfold = true, title = "Big button: click the portal", run = function(W)
		return openConsole(W, { queue = summoningDan(W, "vex ember"), plan = { type = "macro", color = "alert", title = "CLICK THE PORTAL", sub = "right-click the portal (Vex Ember is casting)" } })
	end },
	{ id = "button_waiting", side = "driver", unfold = true, title = "Big button: waiting for the fare", run = function(W)
		return openConsole(W, { plan = { color = "wait", title = "Waiting for Eve's 50s", sub = "Eve is here · waiting for the trade" } })
	end },
	{ id = "console_closed", side = "driver", unfold = true, title = "Driver console: closed", run = function(W)
		return console(W, { open = false, queue = {}, plan = { color = "off", title = "Closed", sub = "tap Open to take riders" } })
	end },
	{ id = "menu_chat", side = "driver", title = "Row menu for a rider from chat: Send \"Get Wuber\"", run = function(W)
		local D = W.Driver
		if not fn(D, "OpenMenu") then return "W.Driver.OpenMenu is missing" end
		local r = openConsole(W)
		if r ~= true then return r end
		D.OpenMenu(W.Drive.customers["dan rider"])
		return true
	end },
	{ id = "note", side = "driver", title = "Customer note sheet: the note, Gifted, the rides", run = function(W)
		local D = W.Driver
		if not fn(D, "ShowSheet") then return "W.Driver.ShowSheet is missing" end
		local r = openConsole(W)
		if r ~= true then return r end
		if not D.ShowSheet("note", W.Drive.customers["dan rider"]) then return "no note sheet" end
		return true
	end },
	{ id = "row_marks", side = "driver", unfold = true, title = "Queue row with note and Gifted marks, and its tooltip", run = function(W)
		return openConsole(W)
	end,
		post = function(W)
			local D = W.Driver
			local v = type(D.ui) == "table" and D.ui.console
			-- (r18) unfolded, the riders' rows are the left column's again (v.rows); v.sideRows is gone, kept here for older builds
			local rows = {}
			for _, list in ipairs({ type(v) == "table" and v.rows, type(v) == "table" and v.sideRows }) do
				if type(list) == "table" then for _, r in ipairs(list) do rows[#rows + 1] = r end end
			end
			for _, r in ipairs(rows) do
				if type(r) == "table" and type(r.c) == "table" and r.c.name == "Dan Rider" and fn(r, "IsVisible") and r:IsVisible() then
					if tipOn(W, r) then return true end
				end
			end
			return "no row for Dan"
		end },
	-- (job 041) the same passphrase on the driver's side: Eve booked through Wuber (the ride pass_rider shows),
	-- in the group; her row's second line and its tooltip
	{ id = "pass_driver", side = "driver", unfold = true, video = true, title = "Passphrase on the driver's queue row and its tooltip: the same two words",
		run = function(W)
			if not fn(W, "Passphrase") then return "W.Passphrase is missing" end
			shotStub(W, "PassphraseOn", function() return true end)
			local q = demoQueue()
			q[2] = { name = "Eve Night", key = "eve night", state = "joined", source = "wuber", wuberRide = PASS_RIDE,
				wuberBuyer = W.myKey or "anita lift", at = now() - 30, price = 5000, paid = 0 }
			return openConsole(W, { queue = q, plan = { type = "macro", color = "go", title = "Summon Eve",
				sub = "click: targets and casts  -  12 shards" } })
		end,
		post = function(W)
			local r = queueRow(W, "Eve Night")
			if not r then return "no row for Eve" end
			if not tipOn(W, r) then return "no tooltip on Eve's row" end
			return true
		end },
	{ id = "customers", side = "driver", unfold = true, title = "Customers: everyone you summoned, with notes and gifts", run = function(W)
		local r = openConsole(W)
		if r ~= true then return r end
		return driveScreen(W, "customers")
	end },
	-- wide Customers with a rider who is in the queue picked: the right pane offers "Invite to Wuber"
	{ id = "customers_queued", side = "driver", only = "unfolded", title = "Customers, wide: a queued rider picked, the Invite to Wuber pill", run = function(W)
		local r = openConsole(W)
		if r ~= true then return r end
		local ok = driveScreen(W, "customers")
		if ok ~= true then return ok end
		return L.PhotoPickCustomer(W, "Dan Rider")
	end,
		post = function(W) return L.PhotoPickCustomer(W, "Dan Rider") end },
	{ id = "crew", side = "driver", title = "Your crew: the \"my account\" switch on each member", run = function(W)
		local r = openConsole(W)
		if r ~= true then return r end
		return driveScreen(W, "crew")
	end },
	-- (job 041) not a Warlock: the Drive tab's setup, a Warlock friend or your own Warlock (an alt) casts
	{ id = "wizard_notlock", side = "driver", video = true, title = "Not a Warlock: the setup's first step, \"My own Warlock (multibox)\" picked",
		run = function(W)
			local r = console(W, { open = false, queue = {}, plan = { color = "off", title = "Closed", sub = "tap Open to take riders" } })
			if r ~= true then return r end
			notLock(W)
			return true
		end,
		post = function(W) return wizardAt(W, 1, "multi") end },
	{ id = "wizard_summoner", side = "driver", video = true, title = "Not a Warlock: \"Who summons?\", two Warlocks of the crew ticked in order",
		run = function(W)
			local r = console(W, { open = false, queue = {}, plan = { color = "off", title = "Closed", sub = "tap Open to take riders" } })
			if r ~= true then return r end
			notLock(W)
			return true
		end,
		post = function(W) return wizardAt(W, 3) end },
	{ id = "demand", side = "driver", unfold = true, title = "What riders want: the demand line, Wanted nearby (unfolded)", run = function(W)
		return openConsole(W, { demand = true })
	end },
	{ id = "pvp", side = "driver", unfold = true, title = "PvP hot-drop warning on the console", run = function(W)
		return openConsole(W, { danger = 2 })
	end },
	{ id = "raid", side = "driver", unfold = true, title = "Raid summons console", run = function(W)
		local DR = W.Drive
		local t0 = now()
		local r = console(W, { open = true, queue = {}, plan = { type = "macro", color = "go", title = "Summon Dan",
			sub = "click: calls the clickers, targets and casts" } })
		if r ~= true then return r end
		stub(DR, "Mode", function() return "raid" end)
		stub(DR, "SetMode", function() return true end)
		stub(DR, "RaidCount", function() return 14 end)
		stub(DR, "RaidQueue", function()
			return { { name = "Dan Rider", asked = t0 - 30, state = "queued", tries = 0 },
				{ name = "Gus Hill", asked = t0 - 50, state = "summoning", claimedBy = W.myKey or "anita lift", tries = 0 },
				{ name = "Ivy Moss", asked = t0 - 70, state = "queued", tries = 1 } }
		end)
		driveRefresh(W)
		return true
	end },
	{ id = "earnings", side = "driver", unfold = true, title = "Earnings: gold per open hour, best hours, this shift's cut (unfolded)",
		run = function(W)
			local r, e = earningsBase(W, false)
			if r ~= true then return r end
			scrollTo(e, false)
			return true
		end },
	{ id = "earnings_heatmap", side = "driver", unfold = true, title = "Earnings: the heatmap, an hour tapped", run = function(W)
		local r, e = earningsBase(W, false)
		if r ~= true then return r end
		scrollTo(e, true)
		return true
	end,
		post = function(W) return tapHour(W) end },
	-- (r18, 01:00) rides logged but no three-hour top window yet: the "Open a few hours..." and "Try ..." tips must both stay inside the pane
	{ id = "earnings_tips", side = "driver", unfold = true, title = "Earnings: the tip strip under the heatmap (no top window yet)", run = function(W)
		-- a sparse log, so Wuber's own TopWindow has none: the tip is true, not a stub
		local r, e = earningsBase(W, "sparse")
		if r ~= true then return r end
		scrollTo(e, true)
		return true
	end },
	{ id = "earnings_empty", side = "driver", unfold = true, title = "Earnings: a new driver, nothing logged yet", run = function(W)
		local r, e = earningsBase(W, "empty")
		if r ~= true then return r end
		scrollTo(e, false)
		return true
	end },
	{ id = "shift", side = "driver", title = "End-of-shift card: the fair split", run = function(W)
		local D = W.Driver
		if not fn(D, "ShowSheet") then return "W.Driver.ShowSheet is missing" end
		local r = console(W, { open = false, queue = {}, plan = { color = "off", title = "Closed", sub = "tap Open to take riders" } })
		if r ~= true then return r end
		-- (round 13, I11/I33) the demo shift as Wuber sums it from the demo log, and its fair split
		local DR = W.Drive
		local sum = fn(DR, "ShiftSummary") and call(DR.ShiftSummary)
		if type(sum) ~= "table" then return "no shift in the demo log" end
		local rows, rule, pct = cutRows(W)
		stub(D, "lastShift", { rides = sum.rides, copper = sum.copper, tips = sum.tips, open = sum.open, bestHour = sum.bestHour,
			bestCopper = sum.bestCopper, crewRides = sum.crewRides, crewCopper = sum.crewCopper, at = now(),
			cut = { rows = rows, rule = rule, pct = pct } })
		if not D.ShowSheet("shift") then return "no shift card" end
		return true
	end },
	{ id = "messages", side = "driver", unfold = true, title = "Messages", run = function(W)
		local r = console(W, { open = false, queue = {}, plan = { color = "off", title = "Closed", sub = "" } })
		if r ~= true then return r end
		return driveScreen(W, "messages")
	end },
	{ id = "messages_edit", side = "driver", unfold = true, title = "Messages: the editor, a chip's tooltip", run = function(W)
		local r = console(W, { open = false, queue = {}, plan = { color = "off", title = "Closed", sub = "" } })
		if r ~= true then return r end
		r = driveScreen(W, "messages")
		if r ~= true then return r end
		local m = type(W.UI.drive) == "table" and type(W.UI.drive.screens) == "table" and W.UI.drive.screens.messages
		if not (type(m) == "table" and type(m.edit) == "function") then return "no message editor" end
		m.edit("greet")
		return true
	end,
		post = function(W)
			local m = W.UI.drive.screens.messages
			if type(m.edit) == "function" then m.edit("greet") end
			local e = m.editor
			local chip = type(e) == "table" and type(e.chips) == "table" and (e.chips[2] or e.chips[1])
			if not chip then return "no chips" end
			if not tipOn(W, chip) then return "no chip tooltip" end
			return true
		end },

	-- Settings
	{ id = "settings", side = "settings", unfold = true, title = "Settings home: the sections", run = function(W) return settings(W) end },
	{ id = "settings_driving", side = "settings", unfold = true, title = "Settings: Driving", run = function(W)
		return settings(W, function(UI)
			if not UI.OpenSettings("driving") then return "Driving didn't open" end
			return true
		end)
	end },
	-- (job 041) Settings for a runner who isn't a Warlock: Driving's "Who summons" (Vex and Nyla, in that order)
	{ id = "settings_summoner", side = "settings", unfold = true, video = true, ready = settingsScrolled,
		title = "Settings: Driving, \"Who summons\" for a runner who isn't a Warlock (a crew of Warlocks)", run = function(W)
			notLock(W)
			return settings(W, function(UI, P) return L.PhotoOpenSetting(UI, P, "Who summons") end)
		end },
	{ id = "settings_search", side = "settings", unfold = true, title = "Settings search: \"price\"", run = function(W)
		return settings(W, function(_, P)
			if not (P and fn(P, "search")) then return "no settings search" end
			P.search("price")
			return true
		end)
	end },
	{ id = "settings_nomatch", side = "settings", unfold = true, title = "Settings search: no match", run = function(W)
		return settings(W, function(_, P)
			if not (P and fn(P, "search")) then return "no settings search" end
			P.search("zzqx")
			return true
		end)
	end },
	{ id = "settings_opened", side = "settings", unfold = true, wait = 0.15, maxWait = 0.5, ready = settingsScrolled,
		title = "Settings: a match opened, highlighted (\"Show ride passphrase\")", run = function(W)
			return settings(W, function(UI, P)
				if not (P and fn(P, "search") and fn(P, "openResult")) then return "no settings search" end
				P.search("passphrase")
				local f = type(UI.settings) == "table" and type(UI.settings.find) == "table" and UI.settings.find
				local m = f and type(f.list) == "table" and f.list[1]
				if not m then return "no match for passphrase" end
				P.openResult(m)
				return true
			end)
		end },
	-- the bug report where a player looks for it, and the one Driving switch that asks first
	{ id = "settings_bug", side = "settings", unfold = true, title = "Settings: Report a bug (in This window)", run = function(W)
		return settings(W, function(UI, P) return L.PhotoOpenSetting(UI, P, "Report a bug") end)
	end },
	{ id = "settings_invite", side = "settings", unfold = true, title = "Settings: Driving, Invite public chat buyers (off by default)", run = function(W)
		return settings(W, function(UI, P) return L.PhotoOpenSetting(UI, P, "Invite public chat buyers") end)
	end },
	{ id = "settings_invite_warning", side = "settings", unfold = true, title = "Settings: the warning asked before Invite public chat buyers turns on", run = function(W)
		return settings(W, function(UI, P)
			local r = L.PhotoOpenSetting(UI, P, "Invite public chat buyers")
			if r ~= true then return r end
			local DR = W.Drive
			if not fn(DR, "SetAutoPublic") then return "no DR.SetAutoPublic" end
			-- (the popup is hidden by L.PhotoReset before the next shot; Cancel or Yes is never pressed)
			if DR.SetAutoPublic(true, function() end) ~= "asked" then return "the warning didn't show" end
			return true
		end)
	end },
	{ id = "help", side = "settings", unfold = true, title = "Help: how Wuber finds drivers", run = function(W)
		local r = settings(W)
		if r ~= true then return r end
		if not fn(W.UI, "OpenHelp") then return "W.UI.OpenHelp is missing" end
		if not W.UI.OpenHelp("settings") then return "the help page didn't open" end
		return true
	end },
	-- Help's last part, "Something not working?" with its Report a bug pill (the page scrolled to its end)
	{ id = "help_bug", side = "settings", unfold = true, title = "Help: Something not working? Report a bug (the page's end)", run = function(W)
		local r = settings(W)
		if r ~= true then return r end
		if not fn(W.UI, "OpenHelp") then return "W.UI.OpenHelp is missing" end
		if not W.UI.OpenHelp("settings") then return "the help page didn't open" end
		if not fn(W.UI, "ScrollHelp") then return "W.UI.ScrollHelp is missing" end
		W.UI.ScrollHelp(-60)
		return true
	end,
		post = function(W) if fn(W.UI, "ScrollHelp") then W.UI.ScrollHelp(-60) end return true end },
	-- (job 041) /wuber test: Settings' "Check my game" pressed (the same checks) and the line /wuber test says in chat
	{ id = "wuber_test", side = "settings", video = true, ready = settingsScrolled,
		title = "/wuber test: Check my game's results, and the /wuber test line in chat", run = function(W)
			return settings(W, function(UI, P)
				local r = L.PhotoOpenSetting(UI, P, "Check my game")
				if r ~= true then return r end
				local b = type(UI.settings) == "table" and type(UI.settings.controls) == "table" and UI.settings.controls.check
				local click = type(b) == "table" and fn(b, "GetScript") and b:GetScript("OnClick")
				if type(click) ~= "function" then return "no Check button" end
				click(b, "LeftButton", false)
				local t = K.tour()
				if fn(W, "SlashCommand") and t and not t.testSaid then
					t.testSaid = true
					W.SlashCommand("test")
				end
				return true
			end)
		end },
	-- the /wuber bug window
	{ id = "bug_window", side = "settings", video = true, title = "/wuber bug: the report to copy", run = function(W)
		local B = W.UI.Bug
		if type(B) ~= "table" or not fn(B, "Open") then return "W.UI.Bug.Open is missing" end
		local r = settings(W)
		if r ~= true then return r end
		B.Open()
		return true
	end },
}

-- (job 041) Shots that need something outside Wuber: OpenMap loaded, or the game's flight map open. Each
-- stands after the screen its "after" names (Photo.lua: L.PhotoScreens); a tour leaves it out, with one
-- log line per reason, when its need(W) says why not. Wuber's window is shut for these (noWin: the
-- settle doesn't wait on it). Kept out of L.PHOTO_SCREENS: the offline harness has neither map.
L.PHOTO_GATED = {
	-- "Skip the bird": Wuber's own card (UI.Bird.Show) beside the game's flight map, the demo drivers
	-- (job 042) first in any tour that has it, while the flight map is surely still open; when more shots
	-- follow, the flight map is closed after it (it would stand behind every other shot). Mia, the one open
	-- demo driver, summons to the place with the longest flight from here that a summon beats (Wuber's own
	-- FlightCost / FlightTime: the author's 20 Nov shots were skipped, Undercity being a zeppelin from Orgrimmar)
	{ first = true, id = "bird", side = "rider", video = true, noWin = true, need = needBird,
		title = "Skip the bird: Wuber's card beside the flight map", run = function(W)
			local Bd = mod(W, "UI.Bird")
			local f, states = flightMap()
			if not f then return "the flight map isn't in a frame Wuber's card can stand beside (" .. states .. ")" end
			local spots, seen = birdSpots(W)
			local here = fn(W, "DestHere") and str((call(W.DestHere))) or "?"
			L.Log("photo", ("bird: the flight map is %s; from %s: %s"):format(states, here, seen))
			if #spots == 0 then return ("no flight from here is long enough for a summon to beat it (over %d s): %s"):format(BIRD_BEATS, seen) end
			local ds = demoDrivers()
			for _, d in pairs(ds) do
				d.short = d.name:match("^(%S+)")
				if d.key ~= "mia runner" then d.state = "busy" end
			end
			ds["mia runner"].dest = spots[1].name
			homeBase(W, ds)
			if type(W.db) == "table" then W.db.birdTip = true end
			if fn(W.UI, "IsShown") and W.UI.IsShown() and fn(W.UI, "Toggle") then W.UI.Toggle(false) end
			if not call(Bd.Pick) then return "no demo driver's summon beats flying from this flight master (" .. seen .. ")" end
			if not call(Bd.Show) then return "no card (it shows once per flight map: close the map, open it again)" end
			local t = K.tour()
			if t then t.bird = true end
			return true
		end,
		afterShot = function(W, more)
			if not more then return end
			local close = rawget(_G, "CloseTaxiMap")
			if type(close) == "function" then pcall(close) end
			local f = flightMap()
			local hide = rawget(_G, "HideUIPanel")
			if f and type(hide) == "function" then pcall(hide, f) end
			if f and flightMap() and fn(f, "Hide") then pcall(f.Hide, f) end
			L.Log("photo", "bird: the flight map closed for the rest of the tour")
		end },
	-- (job 2858) "Skip the bird", the card's own words, where no flight master is at hand (a hands-off tour): Wuber's real card
	-- beside an invisible stand-in frame (alpha 0, named WuberLabTaxiStand) that stands for the flight map only for this
	-- shot (FlightMapFrame, which this client does not have, points at it; put back by the tour's own stubs). The card is
	-- 220 x 64 units at the stand's top right: the exporter crops it from the shot (tour record: ui = UIParent size).
	{ first = true, id = "bird_card_text", side = "rider", video = true, noWin = true, need = function(W)
			local Bd = mod(W, "UI.Bird")
			if not (Bd and fn(Bd, "Show") and fn(Bd, "Pick") and fn(Bd, "Hide")) then return "UI.Bird is missing" end
			if flightMap() or taxiSeen.open then return "the flight master's map is open: the bird shot has the card" end
			if rawget(_G, "FlightMapFrame") ~= nil then return "this client has a FlightMapFrame: the card waits for the real flight map" end
			local spots, seen = birdSpots(W)
			if #spots == 0 then return "no flight known from here is long enough for a summon to beat it: " .. seen end
			return true
		end,
		title = "Skip the bird: Wuber's own card (its words)", run = function(W)
			local Bd = mod(W, "UI.Bird")
			local spots = birdSpots(W)
			if #spots == 0 then return "no flight from here is long enough for a summon to beat it" end
			local ds = demoDrivers()
			for _, d in pairs(ds) do
				d.short = d.name:match("^(%S+)")
				if d.key ~= "mia runner" then d.state = "busy" end
			end
			ds["mia runner"].dest = spots[1].name
			homeBase(W, ds)
			if type(W.db) == "table" then W.db.birdTip = true end
			if fn(W.UI, "IsShown") and W.UI.IsShown() and fn(W.UI, "Toggle") then W.UI.Toggle(false) end
			local stand = rawget(_G, "WuberLabTaxiStand")
			if not stand then
				stand = CreateFrame("Frame", "WuberLabTaxiStand", UIParent)
				stand:SetSize(260, 120)
				stand:SetAlpha(0)
				stand:EnableMouse(false)
			end
			stand:ClearAllPoints()
			stand:SetPoint("CENTER", UIParent, "CENTER", -300, 100)
			stand:SetFrameStrata("HIGH")
			stand:Show()
			shotStub(_G, "FlightMapFrame", stand)
			if not call(Bd.Pick) then return "no demo driver's summon beats flying" end
			if not call(Bd.Show) then return "no card (it shows once per flight map)" end
			local t = K.tour()
			if t then t.bird = true end
			return true
		end },
	-- OpenMap's world map with the demo drivers' pins (Warlocks; Nia's crowned founder pin), framed on them
	-- (job 042) the window fitted to the screen, the view framed until every pin is inside the visible map
	-- (ready), the chat frames out of the shot (noChat), the pins checked at the shot (check)
	{ after = "worldmap", id = "openmap_pins", side = "rider", video = true, noWin = true, need = needOpenMap, noChat = true,
		wait = 0.6, maxWait = 8, ready = function() return omReady(false) end, check = function() return omCheck(false) end,
		title = "OpenMap: the world map with Wuber's driver pins", run = function(W) return mapBase(W, false) end,
		post = function(W) return mapPost(W, false) end },
	-- a driver picked (a ride under way): Wuber's route line from the player to the driver on OpenMap's map
	{ after = "worldmap", id = "openmap_route", side = "rider", video = true, noWin = true, need = needOpenMap, noChat = true,
		wait = 0.6, maxWait = 8, ready = function() return omReady(true) end, check = function() return omCheck(true) end,
		title = "OpenMap: a driver picked, Wuber's route from you to the driver", run = function(W) return mapBase(W, true) end,
		post = function(W) return mapPost(W, true) end },
}

-- (round 18, 3c) The floating big button and its console (the mini card under it) in EVERY plan state of
-- Wuber's Drive/Plan.lua, the window shut (the button floats only then), each with the console's three
-- rows and its Pause / gauge / Close line. The words are Wuber's own (copied from Plan.lua, the demo
-- names): the 20 Nov bug (a sub cut to one line, a shard gauge covered by the Resume pill) showed in
-- exactly these, and no shot showed them. o: open (default true), paused, queue = "demo" | "none" |
-- "summoning", raid, cantpause (the "Warlocks pause" label), plan = { color, title, sub, type }.
L.PHOTO_FLOATS = {
	{ "open", "Open, waiting for riders", { queue = "none", plan = { title = "Open - waiting for riders", sub = "50s to Undercity - whisper word: summon" } } },
	{ "paused", "Paused (the 20 Nov bug: Resume pill and the gauge)", { paused = true, queue = "none", plan = { color = "wait", title = "Paused", sub = "nobody new is invited: tap Resume" } } },
	{ "paused_queue", "Paused with a queue", { paused = true, plan = { color = "wait", title = "Paused - 3 waiting", sub = "nobody new is invited: tap Resume" } } },
	{ "summon_sent", "Summon sent, waiting for them to accept", { queue = "summoning", plan = { color = "wait", title = "Summon sent to Dan", sub = "waiting for them to accept it" } } },
	{ "invited", "Invited, waiting for them to join", { plan = { title = "Invited Dan", sub = "waiting for them to join the group" } } },
	{ "arrived", "Arrived: waiting for the gold", { plan = { color = "wait", title = "Waiting for Eve's 50s", sub = "they open a trade with any of you and type the gold" } } },
	{ "queued", "Queued: the invite goes out", { plan = { title = "Dan is in the queue", sub = "the invite goes out as soon as there is room" } } },
	{ "queued_member", "Queued, a crew member's console", { plan = { title = "Dan is in the queue", sub = "the group leader invites" } } },
	{ "summon", "Summon: click targets and casts", { plan = { type = "macro", color = "go", title = "Summon Dan", sub = "click: tells the price, targets and casts" } } },
	{ "trade_accept", "Accept the trade", { plan = { type = "macro", color = "go", title = "Accept 50s from Eve", sub = "click: accepts the trade" } } },
	{ "trade_accept_hand", "Accept by hand", { plan = { color = "go", title = "Accept 50s from Eve", sub = "click Trade in the trade window" } } },
	{ "trade_waiting", "Waiting for them to accept the trade", { plan = { color = "wait", title = "Waiting for Eve to accept", sub = "50s is in the trade window" } } },
	{ "trade_offer", "Trade: offers less than due", { plan = { color = "wait", title = "Eve offers 30s", sub = "50s is due - accept by hand if that is fine" } } },
	{ "portal_click", "Click the portal", { queue = "summoning_vex", plan = { type = "macro", color = "alert", title = "CLICK THE PORTAL", sub = "right-click the portal (Vex Ember is casting)" } } },
	{ "crew_summons", "The crew summons (click the portal here)", { plan = { color = "wait", title = "Vex Ember summons Dan", sub = "click the portal here when it opens" } } },
	{ "crew_clicks", "Summoning: the crew clicks the portal", { queue = "summoning", plan = { color = "wait", title = "Summoning Dan", sub = "your crew clicks the portal" } } },
	{ "no_shards", "No Soul Shards", { shards = 0, plan = { color = "wait", title = "No Soul Shards on this Warlock", sub = "summon Dan from another window" } } },
	{ "lead", "Give lead", { plan = { type = "macro", color = "go", title = "Give lead to Vex Ember", sub = "click: makes Vex Ember the group leader, so riders get their invites" } } },
	{ "cantpause", "Open, a crew helper: Warlocks pause", { cantpause = true, helper = true, plan = { title = "Open - waiting for riders", sub = "50s to Undercity - whisper word: summon" } } },
	{ "combat", "Paused during combat", { plan = { paused = true, color = "off", title = "Paused during combat", sub = "the button works again after the fight" } } },
	{ "closed", "Closed with riders still listed: tap Open", { open = false, plan = { color = "off", title = "Closed", sub = "tap Open in Wuber's Drive tab", below = "tap Open below" } } },
	{ "raid_summon", "Raid: summon, clickers, shards", { raid = true, plan = { type = "macro", color = "go", title = "Summon Dan", sub = "click: calls the clickers, targets and casts  -  12 shards" } } },
	{ "raid_paused", "Raid: paused", { raid = true, paused = true, plan = { color = "wait", title = "Paused - 3 waiting", sub = "nobody is summoned: tap Resume" } } },
	{ "raid_wants", "Raid: raiders want a summon", { raid = true, plan = { color = "wait", title = "3 raiders want a summon", sub = "your summoners take them in turn" } } },
	{ "raid_idle", "Raid: nobody waiting", { raid = true, queue = "none", plan = { title = "Raid summons - nobody waiting", sub = "raiders say 123 in raid chat to ask" } } },
	{ "raid_stopped", "Raid: stopped (Start)", { raid = true, open = false, plan = { color = "off", title = "Raid summons stopped", sub = "tap Start in Wuber's Drive tab", below = "tap Start below" } } },
}

local function floating(W, o)
	local DR, D = W.Drive, W.Driver
	local q = o.queue == "none" and {} or (o.queue == "summoning" and summoningDan(W)
		or (o.queue == "summoning_vex" and summoningDan(W, "vex ember") or demoQueue()))
	local r = console(W, { open = o.open ~= false, queue = q, plan = o.plan })
	if r ~= true then return r end
	-- the demo agrees with the title: no shards means the gauge says 0; a crew helper is not a
	-- Warlock (no shards of its own, the Warlocks' gauge, "Warlocks pause"). driverBase resets these next shot.
	if o.shards ~= nil then
		stub(DR, "Shards", function() return o.shards end)
		stub(DR, "Crew", function() return crewList(W, nil, o.shards) end)
	end
	if o.helper then
		stub(W, "IsWarlock", function() return false end)
		stub(DR, "Role", function() return "helper" end)
		stub(DR, "IsCaptain", function() return false end)
		stub(DR, "Crew", function() return crewList(W, true) end)
	end
	if not (type(DR.Button) == "table" and fn(DR.Button, "Refresh") and fn(D, "SyncMini") and fn(D, "UpdateMini")) then
		return "the floating button or its console is missing"
	end
	stub(DR, "IsPaused", function() return o.paused == true end)
	-- (every shot sets these, so one shot's stub never leaks into the next)
	stub(D, "CanPause", function() return o.cantpause ~= true end)
	if type(D.kit) == "table" then
		stub(D.kit, "RaidMode", function() return o.raid == true end)
		stub(DR, "RaidQueue", function() return q end)
	end
	-- the window shut: only then the big button floats (open, it is docked in the Drive tab)
	if fn(W.UI, "IsShown") and W.UI.IsShown() then W.UI.Toggle(false) end
	return true
end

-- once the window has gone: the button re-places itself floating, the console under it
local function floated(W)
	local DR, D = W.Drive, W.Driver
	DR.Button.Refresh()
	D.SyncMini()
	D.UpdateMini()
	if not (DR.Button.Floating and DR.Button.Floating()) then
		local b = DR.button
		return "the button is not floating (window " .. tostring(fn(W.UI, "IsShown") and W.UI.IsShown()) .. ", button shown " .. tostring(b and b:IsShown())
			.. ", docked " .. tostring(DR.Button.Docked and DR.Button.Docked()) .. ")"
	end
	return true
end

for _, f in ipairs(L.PHOTO_FLOATS) do
	L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "float_" .. f[1], side = "driver", title = "Floating button + console: " .. f[2],
		wait = 0.3, maxWait = 1.5, run = function(W) return floating(W, f[3]) end, post = floated }
end

-- (round 19, R6) The whole game window as it is (narrow, square or wide): Wuber's frames at their
-- DEFAULT places keep off the chat frame (20 Nov: on a squarer window the chat ended up
-- underneath). The saved places are put aside for the shot (WuberDB is put back after the tour).
-- chat_home: the phone at its default place (W.UI.PlaceWindow; the wide phone only where it clears
-- the chat, so on a square window the unfolded shot is skipped as "doesn't unfold here");
-- chat_float: the floating big button and its console at their default place, the window shut.
L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "chat_home", side = "rider", unfold = true,
	title = "This game window: the phone at its default place, clear of the chat frame", run = function(W)
		if not fn(W.UI, "PlaceWindow") then return "W.UI.PlaceWindow is missing (Wuber before 2.3.2)" end
		homeBase(W, demoDrivers())
		local r = rider(W, "home")
		if r ~= true then return r end
		stub(W.db, "pos", nil)
		if not W.UI.PlaceWindow() then return "the window could not be placed (combat?)" end
		return true
	end }
L.PHOTO_SCREENS[#L.PHOTO_SCREENS + 1] = { id = "chat_float", side = "driver",
	title = "This game window: the big button and its console at their default place, clear of the chat frame",
	wait = 0.3, maxWait = 1.5, run = function(W)
		local r = floating(W, L.PHOTO_FLOATS[1][3])
		if r ~= true then return r end
		local d = type(W.db) == "table" and type(W.db.drive) == "table" and W.db.drive.button
		if type(d) ~= "table" then return "no saved button settings" end
		stub(d, "pos", nil)
		return true
	end, post = function(W)
		local DR = W.Drive
		if fn(DR.Button, "Place") then DR.Button.Place() end
		return floated(W)
	end }

-- The Trips tab with the demo rider's rides
function L.PhotoTrips(W)
	local UI = W.UI
	if not fn(UI, "SelectTab") then return "W.UI.SelectTab is missing" end
	homeBase(W, demoDrivers())
	if not openApp(W) then return "W.UI.Show is missing" end
	closeOverlays(W)
	UI.Show("home")
	if UI.SelectTab("Trips") == false then return "no Trips tab" end
	refresh(W)
	return true
end

-- Azeroth Wrapped for last month (the demo rides) over Trips: the story, or its summary (the last slide)
function L.PhotoWrapped(W, summary)
	local Wr = mod(W, "UI.Rider.Wrapped")
	if not (Wr and fn(Wr, "Open")) then return "no Wrapped" end
	local t = K.tour()
	local m = t and t.wrapMonth
	if not m then return "no month to wrap" end
	if Wr.Shown() then Wr.Close() end
	if not Wr.Open(m[1], m[2]) then return "Wrapped didn't open" end
	if summary then
		local st = fn(Wr, "Story") and Wr.Story()
		for _ = 1, (type(st) == "table" and type(st.slides) == "table" and #st.slides or 1) - 1 do Wr.Next() end
	end
	return true
end

-- (job 105c) for AutoSteps.lua (the Auto check's extra screens): this file's own helpers and demo data
L.PhotoShotKit = { once = once, mod = mod, refresh = refresh, driveRefresh = driveRefresh, closeSheets = closeSheets,
	closeOverlays = closeOverlays, openApp = openApp, rider = rider, shotStub = shotStub, demoDrivers = demoDrivers, homeBase = homeBase,
	driverBase = driverBase, console = console, openConsole = openConsole, driveScreen = driveScreen, earningsBase = earningsBase,
	scrollTo = scrollTo, panel = panel, settings = settings, notLock = notLock, wizardScreen = wizardScreen, wizardAt = wizardAt,
	tipOff = tipOff }
