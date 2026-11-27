-- Module: UI.Driver.State
-- Purpose: Drive tab kit and state: layout constants, helpers (D.kit), engine read-outs, D.Role/Mode,
--   going online and pausing (D.SetOnline, D.SetPaused), advert hooks for the secure overlays
--   (D.AdvertPlan/Target/Clicked/Why, D.PaintAdvert).
-- API: W.Drive, W.Driver, D.screens, D.kit, D.FOLD, D.wide, D.Wide, D.CrewCount, D.Fix, D.Today,
--   D.Stations, D.StationReady, D.PayeeName, D.Role, D.Mode, D.OPEN_WHY, D.ShiftEnded, D.SetOnline,
--   (D.SetOnline(false) asks "N riders are still with you. Close anyway?" when riders are listed),
--   D.CanPause, D.SetPaused, D.AdvertPlan, D.AdvertWhy, D.AdvertTarget, D.AdvertClicked, D.PaintAdvert,
--   D.CrewShards
-- Internals: Char, Crew, Dest, FOOT_H, HERO_H, IsOpen, IsPaused, IsWarlock, List, MAX_ROWS, N, PAD,
--   PILL_H, Price, Provider, QROW_GAP, QROW_H, Queue, ROW_GAP, ROW_H, RaidMode, S, SLOT_H, SLOT_W,
--   STRIP_H, TOP_FIXED, advertOn, call, dr, inCombat, money, now, plural, safeScript, setShown, short,
--   toast
-- Uses: (none)
-- Later: (none)
-- Events: listens Listen DRIVE_MODE (2.3: fires PAGE); fires SETTINGS, PAGE; the built tab `ui` (old line 52) is owned by UI.Driver.Console;
--   read here as D.ui
-- Standalone: no
-- Test: tests/ui/driver/state_test.lua
-- From: Driver.lua 1-437 (Wuber 2.2.1)
--
-- Wuber: the Drive tab, the driver console (2.0). The engine (W.Drive, Drive_*.lua) does the
-- work: it invites, whispers, summons, reads trades and thanks. This tab only shows it and
-- gives the driver a few clear controls, phone style:
--
--   status line        Open / Paused / Closed / In combat, "50s to Undercity" (tap: the price
--                      and place sheet), today's rides and gold
--   the big button     WuberDriveButton (Drive_Button.lua) docks over the slot here; its title
--                      always says what its next click does. A Skip pill sits beside it.
--   control row        Open / Close (the secure WuberGoButton lies over it when going online
--                      also posts the advert), Pause / Resume, Advertise (WuberAdvertButton)
--   Ready to drive     only while something needs fixing, each with one fix pill
--   the queue          rows of riders (click, ctrl, right, shift-right, hold or "..." menu)
--   the crew strip     one chip per crew member in the group
--   Your business      at the end of the scrolling page: Crew · Messages · Blocked (N) · Earnings · Customers
--
-- The other screens (wizard, crew, messages, blocked, earnings, the sheets, the row menu, the
-- mini console and the retire card) are UI_Drive.lua's; they register in D.screens.
-- Reads DR.* only from events, timers and clicks, always nil-guarded: any engine file may be
-- a stub. Nothing here is secure; nothing here scales text.
--
-- W.Driver.Build(parent), .Refresh(), .Toggle(), .SetOnline(on), and the advert hooks UI.lua's
-- secure overlays call: .AdvertPlan(), .AdvertTarget(which), .AdvertClicked(which, plan),
-- .AdvertWhy(why, wait), .PaintAdvert(v, online).

local _, W = ...
local Mod = W.Module("UI.Driver.State", {})
local T = W.Theme
local A = T.Animate
local Try = T.Try

W.Drive = W.Drive or {}
local DR = W.Drive

local D = W.Driver or {}
W.Driver = D
D.screens = D.screens or {}  -- UI_Drive.lua: name -> builder(parent) -> { frame, update, enter }
D.kit = D.kit or {}
-- (2.3) the driver pages that unfold: page -> { build = fn(holder), layout = fn(unfolded,
-- holder) }, filled by UI.Driver.Console (console), Raid (raid), Earnings (earnings) and Messages
-- (messages); UI.Driver.Console registers them with UI.Fold when the Drive tab is built
D.FOLD = D.FOLD or {}
D.wide = D.wide or {} -- page -> true while its layout is the unfolded one

local PAD = 10
-- (round 7, the author's pick "06 v2") one status strip, the hero card (its top band holds Skip, the
-- big button docks over the slot under it), three quiet pills, calm one-line queue rows
local SLOT_W = 340
local STRIP_H = 34
local HERO_H, BAND_H = 146, 34
local SLOT_H = HERO_H - BAND_H
local PILL_H = 40
local ROW_H, ROW_GAP = 44, 6 -- the mini console's rows
local QROW_H, QROW_GAP = 52, 8 -- the console's
local MAX_ROWS = 8
local TOP_FIXED = STRIP_H + 10 + HERO_H + 12 + PILL_H + 12 -- the strip, the hero card and the pills
local FOOT_H = 42 -- the console has no footer bar any more (its list is at the page's end); the name stays exported


---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

local function S(v) return W.Str(v) end
local function N(v) return W.Num(v) end

local function call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if not ok then
		W.Error("drive ui", a)
		return nil
	end
	return a, b, c, d
end

-- DR[name](...) if the engine has it (any Drive file may still be a stub)
local function dr(name, ...) return call(DR[name], ...) end

local function now() return N(call(GetTime)) or 0 end
local function inCombat() return call(W.InCombat) == true end
local function setShown(f, on) if on then f:Show() else f:Hide() end end
local function money(c) return W.Money(N(c) or 0) end
local function short(n) return W.Short(S(n) or "?") end
local function safeScript(frame, script, fn)
	frame:SetScript(script, function(...)
		local ok, err = pcall(fn, ...)
		if not ok then W.Error("drive " .. script, err) end
	end)
end

local function toast(text, kind, onClick)
	if W.UI and type(W.UI.Toast) == "function" then call(W.UI.Toast, text, kind, onClick) end
end

local function Char()
	if not W.myKey or type(W.Char) ~= "function" then return nil end
	local ok, c = pcall(W.Char)
	if ok and type(c) == "table" then return c end
	return nil
end

local function IsWarlock()
	if type(W.IsWarlock) == "function" then return call(W.IsWarlock) == true end
	local ok, _, class = pcall(UnitClass, "player")
	return ok and S(class) == "WARLOCK"
end

-- an external provider's name (a third-party addon, or the old 1.x summoning addon), else nil
local function Provider()
	local p = W.provider
	if p == nil or p == false then return nil end
	if type(p) == "table" then return S(p.name) or "another addon" end
	return "another addon"
end

local function Price()
	local c = Char()
	local p = c and N(c.price)
	local floor = W.MIN_PRICE or 5000
	if not p or p < floor then return floor end
	return math.floor(p + 0.5)
end

local function Dest()
	local d = S(dr("Dest"))
	if d and d ~= "" then return d end
	if type(W.DestHere) == "function" then
		local ok, name = pcall(W.DestHere)
		if ok then
			if type(name) == "table" then return S(name.name) or "here" end
			return S(name) or "here"
		end
	end
	return "here"
end

local function IsOpen() return dr("IsOpen") == true end
local function IsPaused() return dr("IsPaused") == true end
-- raid summon mode: free summons for your own raid; "sell" otherwise
local function RaidMode() return dr("Mode") == "raid" end

-- a list from the engine (nil or a stub: empty)
local function List(name, ...)
	local l = dr(name, ...)
	return type(l) == "table" and l or {}
end

-- the customers, as the engine sorts them
local function Queue()
	local list = dr("Sorted")
	if type(list) ~= "table" then return {} end
	return list
end

local function Crew()
	local list = dr("Crew")
	if type(list) ~= "table" then return {} end
	return list
end

-- (round 13, I10) the crew header's count: the sum its chips show (Warlocks with Wuber and a known
-- count; DR.TeamShards counts every Warlock heard, here or not). nil when none is known.
function D.CrewShards(list)
	local total
	for _, m in ipairs(type(list) == "table" and list or {}) do
		local sh = type(m) == "table" and m.role == "lock" and m.app ~= false and N(m.shards) or nil
		if sh and sh >= 0 then total = (total or 0) + math.floor(sh) end
	end
	return total
end

-- the crew without me (DR.Crew() lists me first)
function D.CrewCount()
	local n = 0
	for _, m in ipairs(Crew()) do
		if type(m) == "table" and not m.me and m.key ~= W.myKey then n = n + 1 end
	end
	return n
end

-- a Readiness fix as { label, run } (named or listed)
function D.Fix(fix)
	if type(fix) ~= "table" then return nil end
	local label = S(fix.label) or S(fix[1])
	local run = fix.run or fix[2]
	if not label or type(run) ~= "function" then return nil end
	return { label = label, run = run, tip = S(fix.tip) }
end

-- seconds since local midnight -> the start of today (time()); nil if the clock can't say
local function TodayStart()
	local t = N(call(time))
	if not t then return nil end
	local ok, d = pcall(date, "*t", t)
	if not ok or type(d) ~= "table" then return t - (t % 86400) end
	return t - ((N(d.hour) or 0) * 3600 + (N(d.min) or 0) * 60 + (N(d.sec) or 0))
end

-- today's rides and gold (the log when Drive_Log has it, else this session's count)
function D.Today()
	local since = TodayStart()
	local tot = since and dr("LogTotals", since, "me")
	if type(tot) == "table" then return N(tot.rides) or 0, N(tot.copper) or 0 end
	local s = type(DR.session) == "table" and DR.session or {}
	return N(s.rides) or 0, N(s.copper) or 0
end

-- (2.3) is this page drawn unfolded now (its layout said so, and the window is wide)?
function D.Wide(page)
	if D.wide[page] ~= true then return false end
	local F = W.UI and W.UI.Fold
	return type(F) == "table" and type(F.IsUnfolded) == "function" and call(F.IsUnfolded) == true
end

-- (2.3) selling or raid summons: the console's page is "console" or "raid"
W.Listen("DRIVE_MODE", function() W.Fire("PAGE") end)

local function plural(n, one, many) return n == 1 and ("1 " .. one) or (n .. " " .. (many or (one .. "s"))) end

D.kit.call, D.kit.dr, D.kit.now, D.kit.money, D.kit.short, D.kit.toast = call, dr, now, money, short, toast
D.kit.Char, D.kit.IsWarlock, D.kit.Provider, D.kit.Price, D.kit.Dest = Char, IsWarlock, Provider, Price, Dest
D.kit.safeScript, D.kit.plural, D.kit.inCombat = safeScript, plural, inCombat
D.kit.RaidMode, D.kit.List = RaidMode, List

-- The stations: places where a crew summoner stands. 2+ = several stations.
function D.Stations()
	local out = {}
	for _, st in ipairs(List("Stations")) do
		if type(st) == "table" and S(st.place) then out[#out + 1] = st end
	end
	return out
end

-- a station is ready with a summoner and two others there
function D.StationReady(st)
	if type(st) ~= "table" then return false end
	if st.ready ~= nil then return st.ready == true end
	local n1 = type(st.summoners) == "table" and #st.summoners or 0
	local n2 = type(st.helpers) == "table" and #st.helpers or 0
	return n1 >= 1 and n1 + n2 >= 3
end

-- the payee's short name for a rider when it isn't the one speaking, else nil
function D.PayeeName(c)
	if type(c) ~= "table" then return nil end
	local k = S(dr("Payee", c.name)) or S(c.payee)
	if not k or k == W.myKey then return nil end
	return short(S(dr("WhoIs", k)) or k)
end

---------------------------------------------------------------------------
-- Which view: the console, the welcome (any class: "Run a summoning service"), or another
-- addon driving
---------------------------------------------------------------------------

function D.Role()
	local r = S(dr("Role"))
	if r then return r end
	return IsWarlock() and "driver" or nil
end

function D.Mode()
	if dr("Lock") == "rr" or Provider() then return "provider" end
	local role = D.Role()
	if role == "helper" then return "console" end
	-- any class runs a service once set up; before that: the welcome
	if role ~= "driver" then return "welcome" end
	if type(W.Advanced) == "function" and not W.Advanced() and IsWarlock() and D.CrewCount() == 0 then return "console" end
	local c = Char()
	if c and c.wizard ~= true and c.welcomed ~= true and not IsOpen() and #Queue() == 0 and D.CrewCount() == 0 then return "welcome" end
	return "console"
end

---------------------------------------------------------------------------
-- Going online (GO ONLINE = Open), pausing
---------------------------------------------------------------------------

-- why DR.SetOpen said no, in plain words
D.OPEN_WHY = {
	summoner = "Choose who summons first: a Warlock has to cast",
	lead = "You need lead or assist in your raid",
	class = "Set up driving first",
	rr = "Your old summoning addon is still on",
	provider = "Another addon drives for you right now",
	member = "Your captain starts and stops the raid summons.",
}

-- The shift that ends when a seller closes (review #20): DR.ShiftSummary() taken just before
-- the close, shown as a card (UI_Drive.lua's "shift" sheet) when there was a ride.
-- (2.3) `cut` = the crew's casts, clicks and shares taken just before the close
-- ({ rows, rule, pct, text }; else read now): the card's "Fair split".
local function cutNow()
	if type(D.CutRows) ~= "function" then return nil end
	local rows, rule, pct = D.CutRows()
	if type(rows) ~= "table" or #rows == 0 then return nil end
	return { rows = rows, rule = rule, pct = pct, text = S(dr("CutText")) }
end

function D.ShiftEnded(sum, cut)
	if type(sum) ~= "table" then return nil end
	local rides, crewRides = N(sum.rides) or 0, N(sum.crewRides) or 0
	if rides + crewRides < 1 then return nil end
	if type(cut) ~= "table" or type(cut.rows) ~= "table" or #cut.rows == 0 then cut = cutNow() end
	D.lastShift = { rides = rides, copper = N(sum.copper) or 0, tips = N(sum.tips) or 0, open = N(sum.open),
		bestHour = N(sum.bestHour), bestCopper = N(sum.bestCopper), crewRides = crewRides,
		crewCopper = N(sum.crewCopper) or 0, at = now(), cut = cut }
	rides = rides + crewRides
	local onDrive = W.UI and W.UI.IsShown and W.UI.IsShown() and W.UI.state and W.UI.state.tab == "Drive"
	if onDrive and D.ShowSheet("shift") then return D.lastShift end
	-- (round 13, I11) the crew's whole takings, as the card's headline
	toast("Shift closed: " .. plural(rides, "ride") .. " · " .. money(D.lastShift.copper + D.lastShift.crewCopper) .. ". Click for your summary.", "found", function()
		if W.UI and W.UI.ShowDrive then W.UI.ShowDrive("console") end
		D.ShowSheet("shift")
	end)
	return D.lastShift
end

-- (decisions round, FAB-02) Close with riders still listed asks first: "2 riders are still with you.
-- Close anyway?" Yes closes as before, Cancel leaves it open. Grey lead rows and finished rides are not riders.
local CLOSE_ASK = "WUBER_CLOSE_RIDERS"
local function ridersListed()
	local n = 0
	for _, c in pairs(type(DR.customers) == "table" and DR.customers or {}) do
		if type(c) == "table" and c.state ~= "lead" and c.state ~= "done" and not (c.state == "paid" and c.gone) then n = n + 1 end
	end
	return n
end

local setOnline

-- true when the question is up (the close waits for the answer)
local function askClose(n)
	local dialogs, show = rawget(_G, "StaticPopupDialogs"), rawget(_G, "StaticPopup_Show")
	if type(dialogs) ~= "table" or type(show) ~= "function" then return false end
	dialogs[CLOSE_ASK] = {
		text = n .. (n == 1 and " rider is" or " riders are") .. " still with you. Close anyway?",
		button1 = "Yes", button2 = "Cancel",
		OnAccept = function() W.Safe("close", setOnline, false) end,
		OnCancel = function() end,
		timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
	}
	local ok, dlg = pcall(show, CLOSE_ASK)
	return ok and dlg ~= nil
end

function D.SetOnline(on)
	on = on and true or false
	if not on and IsOpen() and not RaidMode() and D.Role() == "driver" then
		local n = ridersListed()
		if n > 0 and askClose(n) then return false end
	end
	return setOnline(on)
end

function setOnline(on)
	on = on and true or false
	local c = Char()
	if not c then return false end
	if on and (Provider() or dr("Lock")) then return false end
	local shiftEnds = not on and IsOpen() and not RaidMode() and D.Role() == "driver"
	local cut = shiftEnds and cutNow() or nil
	if type(DR.SetOpen) == "function" then
		local ok, why = call(DR.SetOpen, on)
		if on and not ok then
			if why then toast(D.OPEN_WHY[why] or tostring(why), "warn") end
			return false
		end
		-- a crew member cannot stop the captain's raid summons: say so, no close sound
		if not on and ok == false and why == "member" then
			toast(D.OPEN_WHY.member, "warn")
			return false
		end
	else
		if on and not IsWarlock() then return false end
		c.drive = on
		if type(W.SetDriving) == "function" then call(W.SetDriving, on) else W.Fire("SETTINGS", "drive") end
	end
	W.Sound(on and "open" or "close")
	if on and not RaidMode() and D.Role() == "driver" and IsOpen() and not c.advertTipShown then
		c.advertTipShown = true
		toast("Tip: put the word Wuber in any advert you type yourself. Wuber players' addons hear it and find you.", "info")
	end
	D.Refresh()
	if shiftEnds and not IsOpen() then D.ShiftEnded(dr("ShiftSummary"), cut) end
	return true
end

-- Only the people who summon pause the crew: a helper's pause would flip their own screen to
-- "Paused" while the Warlocks stay open (review #17), so helpers get no pause anywhere.
function D.CanPause() return D.Role() ~= "helper" end

function D.SetPaused(on)
	if type(DR.SetPaused) ~= "function" then return false end
	if not D.CanPause() then
		toast("Only your crew's Warlocks can pause", "info")
		return false
	end
	call(DR.SetPaused, on and true or false)
	D.Refresh()
	return true
end

---------------------------------------------------------------------------
-- Adverts (the line, the channel and the 15 min wait are Net.lua's W.AdvertPlan; the secure
-- macro buttons are UI.lua's WuberGoButton and WuberAdvertButton)
---------------------------------------------------------------------------

local WHY_TEXT = { combat = "Not in combat", channel = "Join Trade or General first", text = "Couldn't make the advert" }

-- What a click would post now, or nil and why (see W.AdvertPlan).
function D.AdvertPlan()
	if type(W.AdvertPlan) ~= "function" then return nil, "text" end
	local opts
	local own = S(dr("AdvertText"))
	local nextAd = dr("NextAd")
	if (own and own ~= "") or type(nextAd) == "table" then
		opts = { text = own ~= "" and own or nil, channel = type(nextAd) == "table" and nextAd.index or nil }
	end
	local ok, plan, why, wait = pcall(W.AdvertPlan, Dest(), Price(), opts)
	if not ok then return nil, "text" end
	return plan, why, wait
end

function D.AdvertWhy(why, wait)
	if why == "wait" then
		local m = math.max(1, math.ceil((tonumber(wait) or 60) / 60))
		return "You can advertise again in " .. m .. " min"
	end
	if why == "spam" or why == "word" or why == "link" or why == "digits" or why == "letters" then
		return "Your advert line was refused by the spam check. Change it in Messages."
	end
	return WHY_TEXT[why or ""] or "Couldn't post the advert"
end

local function advertOn()
	return not (W.db and W.db.advertOnline == false)
end

-- The frame a secure advert button lies over now, or nil: "go" (the Open pill while closed,
-- when opening would also post the advert) or "advert" (the Advertise pill, while open).
function D.AdvertTarget(which)
	local v = D.ui and D.ui.console
	if not (v and v:IsVisible()) or D.sub or D.SheetOpen() or Provider() or not Char() then return nil end
	-- any class may run (and advertise) a service; raid summons never advertise
	if D.Role() ~= "driver" or RaidMode() then return nil end
	if inCombat() then return nil end
	local open = IsOpen()
	if which == "go" then
		if open or not advertOn() then return nil end
		if not v.open:IsVisible() then return nil end
		-- (AUD-130) Open would be refused (a non-Warlock with nobody to summon): no advert goes out
		if not IsWarlock() then
			local s = dr("Summoners")
			if type(s) ~= "table" or #s == 0 then return nil end
		end
		if not D.AdvertPlan() then return nil end
		return v.open
	elseif which == "advert" then
		if not open or not v.advert:IsVisible() then return nil end
		if not D.AdvertPlan() then return nil end
		return v.advert
	end
	return nil
end

local function channelLabel(plan)
	local c = S(plan and plan.channel) or "chat"
	return (c:gsub("^%d+%.%s*", ""):match("^([^%-]+)") or c):gsub("%s+$", "")
end

-- After a click on a secure advert button (plan: the line it posted, or nil if none went).
function D.AdvertClicked(which, plan)
	if which == "go" then
		if not IsOpen() then D.SetOnline(true) end
		-- (AUD-131) a line that went out is always recorded (15-minute wait), open or refused
		if plan and type(W.AdvertPosted) == "function" then
			call(W.AdvertPosted, plan)
			if IsOpen() then toast("You're open · advert posted in " .. channelLabel(plan), "info") end
		end
	elseif plan and type(W.AdvertPosted) == "function" then
		call(W.AdvertPosted, plan)
		toast("Advert posted in " .. channelLabel(plan), "info")
	else
		local _, why, wait = D.AdvertPlan()
		toast(D.AdvertWhy(why, wait), "warn")
	end
	D.Refresh()
end

-- The Advertise pill: quiet when it may go (violet when a reminder says it's due), else muted
-- with a countdown ("Advert 12m") or why not.
function D.PaintAdvert(v, online)
	local b = v and v.advert
	if not b then return end
	if not online then
		b:SetLabel("Advertise")
		b:SetStyle("dark")
		b:SetActive(false)
		return
	end
	local plan, why, wait = D.AdvertPlan()
	if plan then
		-- quiet like its neighbours (round 7: gold is the big button's); a due reminder glows violet
		local due = dr("AdvertDue") == true
		b:SetLabel(due and "Advertise!" or "Advertise")
		b:SetStyle(due and "violet" or "dark")
		b:SetActive(true)
	else
		if why == "wait" then
			local m = math.max(1, math.ceil((tonumber(wait) or 60) / 60))
			b:SetLabel("Advert " .. m .. "m")
		elseif why == "combat" then
			b:SetLabel("In combat")
		elseif why == "channel" then
			b:SetLabel("No channel")
		else
			b:SetLabel("Advertise")
		end
		b:SetStyle("dark")
		b:SetActive(true)
		b.label:SetTextColor(T.RGB("muted"))
	end
end

-- for other modules (REFACTOR-MAP section 2): set at the end, when every local holds its final value
Mod.Char = Char
Mod.Crew = Crew
Mod.Dest = Dest
Mod.FOOT_H = FOOT_H
Mod.HERO_H = HERO_H
Mod.IsOpen = IsOpen
Mod.IsPaused = IsPaused
Mod.IsWarlock = IsWarlock
Mod.List = List
Mod.MAX_ROWS = MAX_ROWS
Mod.N = N
Mod.PAD = PAD
Mod.PILL_H = PILL_H
Mod.Price = Price
Mod.Provider = Provider
Mod.QROW_GAP = QROW_GAP
Mod.QROW_H = QROW_H
Mod.Queue = Queue
Mod.ROW_GAP = ROW_GAP
Mod.ROW_H = ROW_H
Mod.RaidMode = RaidMode
Mod.S = S
Mod.SLOT_H = SLOT_H
Mod.SLOT_W = SLOT_W
Mod.STRIP_H = STRIP_H
Mod.TOP_FIXED = TOP_FIXED
Mod.advertOn = advertOn
Mod.call = call
Mod.dr = dr
Mod.inCombat = inCombat
Mod.money = money
Mod.now = now
Mod.plural = plural
Mod.safeScript = safeScript
Mod.setShown = setShown
Mod.short = short
Mod.toast = toast
