-- Module: UI.Kit
-- Purpose: Rider app shared kit: window constants, the ui state table (UI.state), small helpers, driver and
--   ride views (UI.Drivers, UI.Driver, UI.Ride, UI.Prominence), flight-cost lines, UI.HabitLine,
--   group/network checks.
-- API: W.UI, UI.DEFAULT_SCALE, UI.PHONE, UI.LIST_PAD, UI.state, UI.Duration, UI.SummonWait, UI.Ordinal, UI.FillSaved,
--   UI.Prominence, UI.Drivers, UI.Driver, UI.Ride, UI.HabitLine, UI.FitOrWrap, UI.MayOpen
--   MayOpen(what): the one "may I open now?" answer for everything that opens by itself. what: "bird", "inflight",
--   "tip", "coach", "milestone" or "news". Returns true, or false and the first common rule that says no: "combat",
--   "cinematic" (a cinematic or movie plays), "login" (the first 2 s after login), "other" (with the name of the
--   self-opening thing already up that it waits for). Read-only. Each thing keeps its own extra rules.
-- Internals: BEZEL, BODY_H, CARD_GAP, CARD_H, ENDED, HOME_H, INNER, ISLAND_H, ISLAND_W, LIST_TOP, MAP_H, N,
--   PAD, PHONE_H, PHONE_W, REFRESH_GAP, REQUEST_TIMEOUT, RIDE_RANK, S, SHEET_TOP, STATUS_H, TOP_H, WIN_H,
--   WIN_W, call, cancellable, clamp, driverView, duration, inCombat, inGroup, inGroupWith, macroSafe,
--   money, myKey, now, onNetwork, ordinal, prominence, rideActive, rideView, safeScript, setShown, ui,
--   WIDE_W, inRaid, threeSlice (the Fold's 3-slice backgrounds: UI.Phone, UI.Settings.Panel)
-- Uses: (none: Core via W)
-- Later: UI.Bird (Card: is the Skip the bird card up, for UI.MayOpen)
-- Events: listens login (the moment UI.MayOpen counts from); fires (none)
-- Standalone: yes
-- Test: tests/ui/kit_test.lua
-- From: UI.lua 1-421 (Wuber 2.2.1)
--
-- Wuber: the rider's app window (Home, Confirm, Finding, Driver found, Done, Sorry), its
-- tabs (Ride; Trips from UI_Trips.lua; Drive from Driver.lua), Settings (UI_Settings.lua,
-- the cog), the splash, toasts (one at a time), the milestone / level-up pop card, the
-- first-open coach marks and the minimap button. Round two: prominence (W.Prominence: the
-- cheaper the open driver, the stronger the glow; the founder's card brightest, with a
-- gold-violet edge, crown, shimmer and Founder chip), favourites, "Your usual", the watch
-- bell, time saved, queue place + countdown, the "book" screen (UI.Show("book", place),
-- UI.SetSearch), the route on the map strips, how to pay and combat requests.
-- Reads the network only through W.drivers / W.DriversSorted(), W.ride and Net's
-- functions, each guarded, so a missing piece never raises an error.
--
-- The Request and Cancel chat whispers need a hardware click on a secure macro button.
-- Those buttons (WuberRequestButton, WuberCancelButton) are parented to UIParent and laid
-- over the visible pill out of combat, never parented or anchored to the window: a
-- protected child would lock the window in combat.

local _, W = ...
local Mod = W.Module("UI.Kit", {})
local T = W.Theme
local A = T.Animate
local Try = T.Try

local UI = {}
W.UI = UI

local WIN_W, WIN_H, TOP_H = 360, 600, 56
-- The phone round the window (WuberFrame is the app's screen; the handset is drawn round it):
-- the status bar above it, the home indicator below, a bezel all round.
local STATUS_H, HOME_H, BEZEL = 26, 15, 8
local PHONE_W, PHONE_H = WIN_W + BEZEL * 2, WIN_H + STATUS_H + HOME_H + BEZEL * 2
local ISLAND_W, ISLAND_H = 92, 20
UI.DEFAULT_SCALE = 1.15 -- 15% bigger than round two's 1.0 (the author, 17 Nov)
UI.PHONE = { w = PHONE_W, h = PHONE_H, status = STATUS_H, home = HOME_H, bezel = BEZEL }
local BODY_H = WIN_H - TOP_H
local PAD = 18
local INNER = WIN_W - PAD * 2
local CARD_H, CARD_GAP = 64, 8 -- calm two-line rows (the author's pick, 01 v2)
local MAP_H, SHEET_TOP = 212, 170
local LIST_TOP = 128 -- the list's clip starts here; its content is inset by UI.LIST_PAD so glows fit
UI.LIST_PAD = 14
local REQUEST_TIMEOUT = 40
local REFRESH_GAP = 0.25 -- at most 4 refreshes a second

local ui = {
	screen = nil, manual = "home", confirmKey = nil, dismissed = {}, toasted = {},
	tabs = {}, pendingTabs = {}, dirty = true, lastRefresh = 0, animUntil = 0,
	cards = {}, cardPool = {}, filter = nil, scroll = 0, scrollTarget = 0,
}
UI.state = ui -- for tests and /dump

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

local function S(v) return W.Str(v) end
local function N(v) return W.Num(v) end

local function ret(ok, ...)
	if not ok then
		W.Error("UI", (...))
		return nil
	end
	return ...
end

-- Calls another file's function if it is there; errors are reported, never raised.
local function call(fn, ...)
	if type(fn) ~= "function" then return nil end
	return ret(pcall(fn, ...))
end

local function now() return N(call(GetTime)) or 0 end
local function inCombat()
	if type(W.InCombat) == "function" then return call(W.InCombat) == true end
	return type(InCombatLockdown) == "function" and W.Plain(call(InCombatLockdown)) == true
end

local function safeScript(frame, script, fn)
	frame:SetScript(script, function(...)
		local ok, err = pcall(fn, ...)
		if not ok then W.Error(script, err) end
	end)
end

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function money(c) return W.Money(c or 0) end

-- One line for a macro: no line breaks or pipes, at most `max` bytes.
local function macroSafe(text, max)
	text = S(text)
	if not text then return nil end
	text = text:gsub("[\r\n|]", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
	if text == "" then return nil end
	return W.Clean(text, max or 200)
end

local function setShown(region, shown)
	if shown then region:Show() else region:Hide() end
end

-- "14 min", "1 h 20 min", "3 h", "under a minute"
local function duration(sec)
	sec = N(sec) or 0
	if sec < 60 then return "under a minute" end
	local m = math.floor(sec / 60 + 0.5)
	if m < 60 then return m .. " min" end
	local h = math.floor(m / 60)
	m = m - h * 60
	if m == 0 then return h .. " h" end
	return h .. " h " .. m .. " min"
end
UI.Duration = duration

-- A ready driver's summon wait in seconds: their own average (d.avgSummon, 10..900, floored) when they
-- send one, else the shared W.SUMMON_SECS (30). d is a driver view or record; anything else gives the default.
function UI.SummonWait(d)
	local v = type(d) == "table" and N(d.avgSummon) or nil
	if v and v >= 10 and v <= 900 then return math.floor(v) end
	return W.SUMMON_SECS or 30
end

-- 1st, 2nd, 3rd, 4th, 11th, 22nd
local function ordinal(n)
	n = math.floor(N(n) or 0)
	local tens, ones = n % 100, n % 10
	local suffix = "th"
	if tens < 11 or tens > 13 then
		if ones == 1 then suffix = "st" elseif ones == 2 then suffix = "nd" elseif ones == 3 then suffix = "rd" end
	end
	return n .. suffix
end
UI.Ordinal = ordinal

-- The time a ride to dest saves: "Saves about 14 min of flying", and "Worth about 2g 30s of
-- your time" only when that is more than the fare. Fills the Confirm screen's strip.
function UI.FillSaved(strip, dest, price, seconds)
	if not strip then return nil end
	local sec = N(seconds)
	if not sec and type(W.TravelSaved) == "function" then sec = N((call(W.TravelSaved, dest))) end
	if not sec or sec <= 0 then
		strip:Hide()
		return nil
	end
	strip.head:SetText("Saves about " .. duration(sec) .. " of flying")
	local value = type(W.TimeValue) == "function" and N(call(W.TimeValue, sec)) or nil
	local worth = value and value > (N(price) or 0) and value > 0
	strip.sub:SetText(worth and ("Worth about " .. money(value) .. " of your time") or "")
	strip.head:ClearAllPoints()
	if worth then
		strip.head:SetPoint("TOPLEFT", strip, "TOPLEFT", 48, -10)
	else
		strip.head:SetPoint("LEFT", strip, "LEFT", 48, 0)
	end
	if not strip:IsShown() then A.FadeIn(strip, 0.25) end
	return sec
end

---------------------------------------------------------------------------
-- Reading the network's data (plain values only)
---------------------------------------------------------------------------

local STATE_ORDER = { open = 1, busy = 2, paused = 3 }

local function driverView(d)
	if type(d) ~= "table" then return nil end
	local name = S(d.name)
	local key = S(d.key) or (name and W.Key(name))
	if not (name and key) then return nil end
	local x, y = N(d.x), N(d.y)
	if x and x > 1 then x = x / 1000 end
	if y and y > 1 then y = y / 1000 end
	local state = S(d.state)
	if not STATE_ORDER[state or ""] then state = "paused" end
	local team = N(d.team) or 1
	team = clamp(math.floor(team), 1, 3)
	local service = S(d.service)
	local queue = N(d.queue)
	if queue then queue = clamp(math.floor(queue), 0, 40) end
	local creator = type(W.IsCreator) == "function" and call(W.IsCreator, key) == true
	-- FEAT-01: the driver's average summon in seconds (D field 21), 10..900 or nil
	local avg = N(d.avgSummon)
	if avg and (avg < 10 or avg > 900) then avg = nil end
	-- 2.4: the driver's verified summons (D field 22), 1..99999 or nil
	local rank = N(d.rank)
	if rank and (rank < 1 or rank > 99999) then rank = nil end
	return {
		key = key, name = name, short = W.Short(name), dest = S(d.dest) or "Unknown",
		price = math.max(0, N(d.price) or 0), service = service or name, state = state,
		team = team, seats = N(d.seats), heard = N(d.heard), mapID = N(d.mapID), x = x, y = y,
		badge = S(d.badge), queue = queue, creator = creator, raw = d, avgSummon = avg and math.floor(avg) or nil,
		rank = rank and math.floor(rank) or nil,
		-- the Warlock who casts, when the one riders talk to isn't one
		summoner = (S(d.summoner) and W.Key(S(d.summoner)) ~= key) and W.Short(S(d.summoner)) or nil,
	}
end

-- How strongly a driver glows (0..1) and whether it is the creator. W.Prominence (NET) when
-- it is there; else the same rule here: open drivers by price rank, cheapest brightest,
-- capped at 0.7; the creator always 1.
local function prominence(d, list)
	if type(W.Prominence) == "function" then
		local ok, glow, isCreator = pcall(W.Prominence, d.raw or d)
		glow = ok and N(glow) or nil
		if glow then
			if isCreator ~= nil then d.creator = W.Plain(isCreator) == true end
			return clamp(glow, 0, 1), d.creator
		end
	end
	if d.creator then return 1, true end
	if d.state ~= "open" then return 0, false end
	local cheaper, n = 0, 0
	for _, o in ipairs(list or {}) do
		if o.state == "open" then
			n = n + 1
			if o.price < d.price then cheaper = cheaper + 1 end
		end
	end
	if n <= 1 then return 0.7, false end
	return 0.7 - 0.55 * cheaper / (n - 1), false
end
UI.Prominence = prominence

local function sortDrivers(list)
	table.sort(list, function(a, b)
		local oa, ob = STATE_ORDER[a.state] or 3, STATE_ORDER[b.state] or 3
		if oa ~= ob then return oa < ob end
		if a.price ~= b.price then return a.price < b.price end
		-- the creator first among drivers of the same price
		if a.creator ~= b.creator then return a.creator == true end
		local na, nb = a.name:lower(), b.name:lower()
		if na ~= nb then return na < nb end
		return a.key < b.key
	end)
	return list
end

-- Every driver heard, open first, then busy, then paused; cheapest first within each.
function UI.Drivers()
	local src
	if type(W.DriversSorted) == "function" then
		local list = call(W.DriversSorted)
		if type(list) == "table" then src = list end
	end
	if not src then
		src = {}
		if type(W.drivers) == "table" then
			for _, d in pairs(W.drivers) do src[#src + 1] = d end
		end
	end
	local out, seen = {}, {}
	for _, d in ipairs(src) do
		local v = driverView(d)
		if v and not seen[v.key] then
			seen[v.key] = true
			out[#out + 1] = v
		end
	end
	return sortDrivers(out)
end

function UI.Driver(key)
	if not key or type(W.drivers) ~= "table" then return nil end
	local d = W.drivers[key]
	if not d and W.Key then d = W.drivers[W.Key(key) or ""] end
	return driverView(d)
end

local RIDE_RANK = { requesting = 1, accepted = 2, invited = 3, ingroup = 4, summoning = 5, portal = 6, arrived = 7, paying = 8, done = 9 }
local ENDED = { done = true, declined = true, cancelled = true, timeout = true, failed = true }

local function rideView()
	local r = W.ride
	if type(r) ~= "table" then return nil end
	local v = {
		id = S(r.id) or tostring(r), driver = S(r.driver) or "your driver", driverKey = S(r.driverKey),
		dest = S(r.dest) or "your destination", price = N(r.price), state = S(r.state) or "requesting",
		at = N(r.at), eta = N(r.eta), etaAt = N(r.etaAt), stage = S(r.stage), reason = S(r.reason),
		service = S(r.service), summonUp = W.Plain(r.summonUp) == true, grouped = W.Plain(r.grouped) == true,
		stars = N(r.stars), rated = W.Plain(r.rated) == true, raw = r,
		position = N(r.position), saved = N(r.saved),
		-- who to pay: the summoner who cast you; who casts, when not the driver
		payto = (S(r.payto) or S(r.payee)) and W.Short(S(r.payto) or S(r.payee)) or nil,
		summoner = S(r.summoner),
	}
	v.short = W.Short(v.driver)
	if v.summoner and W.Key(v.summoner) == (v.driverKey or W.Key(v.driver)) then v.summoner = nil end
	if v.summoner then v.summoner = W.Short(v.summoner) end
	v.rank = RIDE_RANK[v.state] or 0
	-- the summon is up and waiting to be accepted
	v.portalUp = v.state == "portal" or (v.state == "summoning" and v.summonUp)
	return v
end
UI.Ride = rideView

local function rideActive(rv)
	rv = rv or rideView()
	return rv ~= nil and not ENDED[rv.state]
end

-- What flying costs, against the summon (the author, 18 Nov: "money saved vs flight paths"):
-- "Flying here costs 23s · this summon really costs 27s" (really = fare + tip - cost).
-- A's W.FlightCost(from, to) -> copper, exact (1 = what a flight master showed on this account;
-- anything else is never shown; from nil = where the player stands); the ride carries
-- flightCost / flightExact from request time; W.Stats().flightSaved is the lifetime. No number
-- we can't back: no cost, no line. (W.db.uiFlight* only stand in while the engine has none.)
do
	local function isExact(e) return e == true or e == 1 end
	local function costTo(dest)
		if type(W.FlightCost) ~= "function" or not S(dest) then return nil end
		local c, exact, _, via = call(W.FlightCost, nil, dest)
		c = N(c)
		if not c or c <= 0 or not isExact(exact) then return nil end
		-- (round 13, I14) by zeppelin or boat the trip is free: no flight price unless the priced
		-- route has the crossing on it (Confirm compares the same way)
		if via ~= "boat" and type(W.TravelSaved) == "function" then
			local _, how = call(W.TravelSaved, dest)
			if how == "by zeppelin" or how == "by boat" then return nil end
		end
		return math.floor(c + 0.5), true
	end
	UI.FlightCostTo = costTo

	local function qdb()
		if type(W.db) ~= "table" then return nil end
		return W.db
	end

	-- The cost from where the rider stood when booking: the ride's own (the engine's, at
	-- request time), else quoted here once before the summon and kept.
	function UI.FlightQuote(rv)
		rv = rv or rideView()
		if not rv then return nil end
		local r = rv.raw or {}
		local own = N(r.flightCost)
		if own and own > 0 then
			if not isExact(W.Plain(r.flightExact)) then return nil end
			return math.floor(own + 0.5), true
		end
		local db = qdb()
		if not db then return nil end
		local q = db.uiFlightQuote
		if type(q) == "table" and q.id == rv.id then
			if N(q.cost) and q.cost > 0 and q.exact == true then return q.cost, true end
			return nil
		end
		if (RIDE_RANK[rv.state] or 0) > RIDE_RANK.ingroup then return nil end
		local cost, exact = costTo(rv.dest)
		db.uiFlightQuote = { id = rv.id, cost = cost, exact = exact or nil }
		return cost, exact
	end

	-- The line. rvOrDest: a ride view (its quote; pays fare + tip) or a place name (Confirm:
	-- a fresh quote) with price = what the rider would pay. done: past tense.
	-- coins (round 9, S18): kept as a flag for the callers that sit next to times (the pay card, Done's pills);
	-- design 1 H: the amounts are letters like everywhere ("23s", W.Money), not coin icons
	function UI.FlightLine(rvOrDest, done, price, coins)
		local cost, exact
		if type(rvOrDest) == "table" then
			cost, exact = UI.FlightQuote(rvOrDest)
			local paid = done and rvOrDest.raw and N(rvOrDest.raw.paid)
			price = price or (paid and paid > 0 and paid) or (UI.PayTotal and UI.PayTotal(rvOrDest)) or rvOrDest.price
			-- a part payment: PayTotal is only what is left, so add back the part already paid (the whole cost)
			local so = rvOrDest.raw and N(rvOrDest.raw.paidSoFar) or 0
			local fare = N(rvOrDest.price) or 0
			if not done and so > 0 and so < fare and price == (UI.PayTotal and UI.PayTotal(rvOrDest)) then price = price + so end
		else
			cost, exact = costTo(rvOrDest)
		end
		price = N(price)
		if not cost or not price or price <= 0 then return nil end
		-- (design 1 P) beside a time the amount is gold letters, so "23s" is never read as seconds
		local function amt(c) return coins and (T.Code("gold") .. money(c) .. "|r") or money(c) end
		local head = "Flying here " .. (done and "would cost " or "costs ") .. amt(cost)
		if price > cost then
			return head .. " · this summon really cost" .. (done and " " or "s ") .. amt(price - cost), cost, exact
		end
		if price == cost then
			return head .. " · the summon cost" .. (done and " " or "s ") .. "the same", cost, exact
		end
		-- never a negative: the summon is the cheaper way
		return head .. " · this summon " .. (done and "saved" or "saves") .. " you " .. amt(cost - price), cost, exact
	end

	-- A paid ride adds what flying would have cost to the stand-in lifetime total, once (only
	-- used while W.Stats() has no flightSaved).
	function UI.CountFlightSaved(rv)
		local db = qdb()
		if not (rv and db and rv.state == "done") or (rv.raw and rv.raw.unpaid) then return false end
		local cost, exact = UI.FlightQuote(rv)
		local t = type(db.uiFlightSaved) == "table" and db.uiFlightSaved or { copper = 0, ids = {} }
		t.ids = type(t.ids) == "table" and t.ids or {}
		if not cost or t.ids[rv.id] then return false end
		t.ids[rv.id] = true
		t.copper = (N(t.copper) or 0) + cost
		db.uiFlightSaved = t
		return true
	end

	-- Lifetime: "Saved 4g 12s of flight costs" (exact costs only), else nil.
	function UI.FlightSavedLine(stats)
		stats = stats or (type(W.Stats) == "function" and call(W.Stats)) or {}
		local copper = N(stats.flightSaved)
		if not copper then
			local db = qdb()
			local t = db and db.uiFlightSaved
			if type(t) == "table" then copper = N(t.copper) end
		end
		if not copper or copper <= 0 then return nil end
		return "Saved " .. money(copper) .. " of flight costs", copper
	end
end

-- One line while a slightly smaller size fits the text (T.Fit); two lines only when it would still be cut.
-- Call it right after the label's SetText; it reads fs.wuberWrapped afterwards.
function UI.FitOrWrap(fs)
	if type(fs) ~= "table" or not fs.wuberBase then return end
	fs.wuberLines = nil
	Try(fs, "SetWordWrap", false) -- back to one line: T.Text's wrapper runs T.Fit, which shrinks as far as it may
	fs.wuberWrapped = false
	local room = N(fs.wuberRoom)
	local wide = room and (N(T.MeasureText(fs.wuberText or "", fs.wuberPx or fs.wuberBase, fs.wuberWeight)) or 0) > room
	if wide or Try(fs, "IsTruncated") == true then T.Lines(fs, 2) end
end

-- The rider's habits in one line (review #19, Done and Trips): "4-day ride streak · 5 rides
-- with Anita · 3g 20s in all". driverKey: only name the favourite when it is this ride's driver
-- (nil: always). nil when there is nothing worth saying yet.
function UI.HabitLine(driverKey, stats)
	stats = stats or (type(W.Stats) == "function" and call(W.Stats)) or nil
	if type(stats) ~= "table" then return nil end
	local parts = {}
	local streak = N(stats.streakDays) or 0
	if streak >= 2 then parts[#parts + 1] = streak .. "-day ride streak" end
	local favN = N(stats.favouriteCount) or 0
	local fav = S(stats.favouriteDriver)
	if fav and favN >= 2 and (not driverKey or W.Key(fav) == driverKey or S(stats.favouriteKey) == driverKey) then
		parts[#parts + 1] = favN .. " rides with " .. W.Short(fav)
	end
	local spent = N(stats.spent) or 0
	if spent > 0 and (N(stats.rides) or 0) >= 2 then parts[#parts + 1] = money(spent) .. " in all" end
	if #parts == 0 then return nil end
	return table.concat(parts, " · ")
end

local function myKey() return W.myKey or (W.Key and W.Key(call(W.UnitName, "player"))) end

local function inGroup() return call(W.InGroup) == true end
local function inGroupWith(key)
	if type(W.InGroupWith) ~= "function" then return false end
	return call(W.InGroupWith, key) == true
end

local function onNetwork()
	if type(W.OnNetwork) ~= "function" then return true end
	return call(W.OnNetwork) ~= false
end

local function cancellable(rv)
	return rv and not ENDED[rv.state] and rv.rank < RIDE_RANK.arrived
end

local function inRaid()
	return type(IsInRaid) == "function" and W.Plain(call(IsInRaid)) == true
end

---------------------------------------------------------------------------
-- The Fold: unfolded, the window is two panes of WIN_W side by side (the primary pane
-- on the left keeps every folded page and every secure pill; the side pane opens to its right)
---------------------------------------------------------------------------

local WIDE_W = WIN_W * 2
local SLICE_CAP = 126 -- the rounded ends of a 3-slice background (window units)

-- A background cut in three from one stretched texture: a left cap, a middle that
-- stretches, a right cap, so the window can widen without stretching the art's rounded
-- corners. tex: the texture that covered the whole width (it becomes the left cap); path: its
-- art; u1, v0, v1: its texcoords as it was laid over WIN_W (u from 0 to u1); top, bottom: its
-- y offsets from the frame's top and bottom. At WIN_W wide it draws exactly as before.
-- Returns { left, mid, right }.
local function threeSlice(tex, frame, path, layer, sub, u1, v0, v1, top, bottom)
	local k = u1 / WIN_W -- texcoord per window unit
	local a, b = SLICE_CAP * k, (WIN_W - SLICE_CAP) * k
	local mid = frame:CreateTexture(nil, layer, nil, sub)
	local right = frame:CreateTexture(nil, layer, nil, sub)
	tex:SetTexture(path)
	mid:SetTexture(path)
	right:SetTexture(path)
	tex:ClearAllPoints()
	tex:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, top)
	tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, bottom)
	tex:SetWidth(SLICE_CAP)
	tex:SetTexCoord(0, a, v0, v1)
	right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, top)
	right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, bottom)
	right:SetWidth(SLICE_CAP)
	right:SetTexCoord(b, u1, v0, v1)
	mid:SetPoint("TOPLEFT", tex, "TOPRIGHT", 0, 0)
	mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
	mid:SetTexCoord(a, b, v0, v1)
	return { left = tex, mid = mid, right = right }
end

-- internals other modules use (bound at load by later modules, or called late)
Mod.BEZEL = BEZEL
Mod.BODY_H = BODY_H
Mod.CARD_GAP = CARD_GAP
Mod.CARD_H = CARD_H
Mod.ENDED = ENDED
Mod.HOME_H = HOME_H
Mod.INNER = INNER
Mod.ISLAND_H = ISLAND_H
Mod.ISLAND_W = ISLAND_W
Mod.LIST_TOP = LIST_TOP
Mod.MAP_H = MAP_H
Mod.N = N
Mod.PAD = PAD
Mod.PHONE_H = PHONE_H
Mod.PHONE_W = PHONE_W
Mod.REFRESH_GAP = REFRESH_GAP
Mod.REQUEST_TIMEOUT = REQUEST_TIMEOUT
---------------------------------------------------------------------------
-- UI.MayOpen: one rule for everything that opens by itself (the login tip, the first-open guide, Skip the bird,
-- the What's new card). The common rules are answered here once; each thing adds its own (a ride, a flight, room).
---------------------------------------------------------------------------

-- the order they give way in: a thing waits for anything already up that stands before it (or beside it: the tip
-- and the guide wait for each other). Skip the bird and the mid-flight offer come first (the player's own journey),
-- the What's new card last. A name not listed waits for all of them.
local GATE = {
	LOGIN = 2, -- seconds after login before anything opens by itself (a thing with a longer delay keeps its own)
	order = { "bird", "inflight", "splash", "tip", "coach", "milestone", "news" },
	rank = { bird = 1, inflight = 2, splash = 3, tip = 4, coach = 4, milestone = 5, news = 6 },
	loginAt = nil,
}

local function frameUp(f)
	return type(f) == "table" and type(f.IsShown) == "function" and W.Plain(call(f.IsShown, f)) == true
end
local function namedUp(name) return frameUp(rawget(_G, name)) end

-- is that thing on screen now (the frames by their names: asking a module for its card could build it)
GATE.up = {
	bird = function()
		local m = W.Mod("UI.Bird")
		return type(m) == "table" and type(m.Card) == "function" and frameUp(call(m.Card)) or false
	end,
	inflight = function() return namedUp("WuberInFlight") end,
	splash = function() return ui.splashing and true or false end,
	tip = function() return namedUp("WuberTipCard") end,
	coach = function() return ui.coaching and true or false end,
	milestone = function() return frameUp(ui.pop) end,
	news = function() return namedUp("WuberNewsCard") end,
}

-- a cinematic or a movie plays (the game hides the whole interface for it)
local function inCinematic()
	if namedUp("CinematicFrame") or namedUp("MovieFrame") then return true end
	for _, name in ipairs({ "InCinematic", "IsInCinematicScene" }) do
		local fn = rawget(_G, name)
		if type(fn) == "function" and W.Plain(call(fn)) == true then return true end
	end
	return false
end

function UI.MayOpen(what)
	if inCombat() then return false, "combat" end
	if inCinematic() then return false, "cinematic" end
	if not GATE.loginAt or now() - GATE.loginAt < GATE.LOGIN then return false, "login" end
	local mine = GATE.rank[what] or (#GATE.order + 1)
	for _, name in ipairs(GATE.order) do
		if name ~= what and GATE.rank[name] <= mine and GATE.up[name]() then return false, "other", name end
	end
	return true
end
W.OnLogin(function() GATE.loginAt = now() end)

Mod.RIDE_RANK = RIDE_RANK
Mod.S = S
Mod.SHEET_TOP = SHEET_TOP
Mod.STATUS_H = STATUS_H
Mod.TOP_H = TOP_H
Mod.WIN_H = WIN_H
Mod.WIN_W = WIN_W
Mod.WIDE_W = WIDE_W
Mod.call = call
Mod.cancellable = cancellable
Mod.clamp = clamp
Mod.driverView = driverView
Mod.duration = duration
Mod.inCombat = inCombat
Mod.inGroup = inGroup
Mod.inGroupWith = inGroupWith
Mod.inRaid = inRaid
Mod.macroSafe = macroSafe
Mod.money = money
Mod.myKey = myKey
Mod.now = now
Mod.onNetwork = onNetwork
Mod.ordinal = ordinal
Mod.prominence = prominence
Mod.rideActive = rideActive
Mod.rideView = rideView
Mod.safeScript = safeScript
Mod.setShown = setShown
Mod.threeSlice = threeSlice
Mod.ui = ui
