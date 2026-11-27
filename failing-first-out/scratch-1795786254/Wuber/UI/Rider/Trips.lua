-- Module: UI.Rider.Trips
-- Purpose: The Trips tab (was UI_Trips.lua): time saved, rider level, habit chips, milestones and trip
--   history.
-- API: UI.trips, UI.TripsHM, UI.BuildTrips, UI.TripsHabits, UI.TripsChips, UI.UpdateTrips, UI.RaincheckList
-- Internals: fillRound8, foldBuild, foldLayout (Mod.foldBuild, Mod.foldLayout), Mod.trimCells (folded: no sliced
--   milestone row, the "Scroll for your trips" cue, tr.cue), Mod.fit (the scroll range from the view's laid-out
--   height, again when it changes)
-- Uses: (none: Core via W)
-- Later: UI.Rider.Wrapped (the Wrapped card, chip and story, through W.Mod at run time), UI.Fold
--   (Register: the unfolded "trips" page)
-- Events: listens Listen MILESTONE, Listen RAINCHECK, Listen SETTINGS; fires (none)
-- Standalone: no
-- Test: tests/ui/rider/trips_test.lua
-- From: UI_Trips.lua 1-553 (Wuber 2.2.1)
--
-- Wuber: the Trips tab (Ride · Trips · Drive), the author's 07 v2 pick: time saved big (counting up),
-- your rider level and the bar to the next, habit chips, the milestones (earned ones glow, locked ones say how to earn them) and
-- your trip history with your own ratings. Data from Core/Net (W.Stats, W.TierProgress,
-- W.MILESTONES, W.db.rides), every call guarded: a missing piece shows a plain zero.
-- Unfolded: stats and trips on the left, the milestones (3 to a row, scrolling)
-- and the Wrapped card on the right, in the Fold's side pane. Folded: one column, as before.

local _, W = ...
local Mod = W.Module("UI.Rider.Trips", {})

local T = W.Theme
local noGlow = T.NoGlow -- (design round 1) the shared no-op glow, Theme.Widgets
local A = T.Animate
local Try = T.Try
local UI = W.UI

local WIN_W, PAD = 360, 18
local INNER = WIN_W - PAD * 2
local COLS, CELL_W, CELL_H = 4, INNER / 4, 96
local HALO = 64 -- the earned glow's size: under a cell's width (81) and the side pane's pitch (108)
local WIDE = { cols = 3, pitch = 108, rowH = 86, top = 16, wrapH = 96 }
local ROW_H = 54

local function S(v) return W.Str(v) end
local function N(v) return W.Num(v) end

local function call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if not ok then
		W.Error("trips", a)
		return nil
	end
	return a, b, c, d
end

local function safeScript(frame, script, fn)
	frame:SetScript(script, function(...)
		local ok, err = pcall(fn, ...)
		if not ok then W.Error(script, err) end
	end)
end

local function money(c) return W.Money(c or 0) end

-- A total, rounded so it fits a tile: whole gold from 100g, whole silver from 1g.
local function roundMoney(c)
	c = math.floor(N(c) or 0)
	if c >= 1000000 then return W.Money(math.floor(c / 10000 + 0.5) * 10000) end
	if c >= 10000 then return W.Money(math.floor(c / 100 + 0.5) * 100) end
	return W.Money(c)
end

local function day(at)
	at = N(at)
	if not at or type(date) ~= "function" then return nil end
	local ok, text = pcall(date, "%d %b", at)
	if ok and type(text) == "string" then return (text:gsub("^0", "")) end
	return nil
end

local tr = { cells = {}, rows = {}, seen = nil, scroll = 0, scrollTarget = 0 }
UI.trips = tr -- for tests

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------

-- "4h 42m", "42m", "0m"
local function hm(sec)
	local m = math.floor((N(sec) or 0) / 60 + 0.5)
	local h = math.floor(m / 60)
	m = m - h * 60
	if h > 0 then return h .. "h " .. m .. "m" end
	return m .. "m"
end
UI.TripsHM = hm

-- Time saved, Uber-style (the author's pick, 07 v2): a "TIME SAVED" label, one big number that
-- counts up when the tab opens, and one quiet caption. (Round 13, I25: the label has no pill of
-- its own, so it never reads as a button next to Wrapped.) The number changes by SetText in an
-- OnUpdate (never a Scale animation on text).
local function buildHero(parent)
	local h = CreateFrame("Frame", nil, parent)
	h:SetSize(INNER, 128)
	h.kicker = T.Tag(h, "Time saved", { fill = { 0.42, 0.22, 0.72, 1 }, text = "muted", weight = "bold", size = "sub", h = 30,
		icon = "clock", iconColour = "muted", iconSize = 14, pad = 14 })
	for _, t in ipairs(h.kicker.fill.parts) do t:Hide() end
	h.kicker:SetPoint("TOP", h, "TOP", 0, 0)
	h.big = T.Text(h, "hero", "white", "CENTER", "bold")
	h.big:SetPoint("TOP", h, "TOP", 0, -38)
	h.big:SetWidth(INNER)
	h.cap = T.Text(h, "sub", "muted", "CENTER", "regular")
	h.cap:SetPoint("TOP", h, "TOP", 0, -98)
	h.cap:SetWidth(INNER)
	h:EnableMouse(true)
	T.Tip(h, "Time saved", function() return h.tip or "Flying you didn't have to do, added up over every ride, and what that time is worth (your rate is in Settings)." end)
	-- the count-up
	safeScript(h, "OnUpdate", function(self)
		if not self.to then return end
		local t = (N(call(GetTime)) or 0) - (self.at or 0)
		local k = math.min(1, math.max(0, t / 1.3))
		k = 1 - (1 - k) * (1 - k) * (1 - k) -- ease out
		local v = (self.from or 0) + ((self.to or 0) - (self.from or 0)) * k
		self.big:SetText(hm(v))
		self.shown = v
		if k >= 1 then self.to = nil end
	end)
	return h
end

-- A habit chip (07 v2): a dark rounded tile, a round icon, one line. Half the width when the
-- words fit, else the whole row.
local function buildChip(parent, icon, colour)
	local c = CreateFrame("Frame", nil, parent)
	c:SetSize(INNER, 44)
	c.bg = T.Rounded(c, "card", 14, "BACKGROUND", 0)
	c.disc = T.Circle(c, 30, { 0.53, 0.25, 0.85, 0.28 }, "ARTWORK")
	c.disc:SetPoint("LEFT", c, "LEFT", 10, 0)
	c.icon = T.Icon(c, icon, 15, colour or "glow", "OVERLAY")
	c.icon:SetPoint("CENTER", c.disc, "CENTER")
	c.text = T.Text(c, "sub", "white", "LEFT", "medium")
	c.text:SetPoint("LEFT", c, "LEFT", 50, 0)
	c:EnableMouse(true)
	return c
end

local function buildCell(parent, i)
	local c = CreateFrame("Frame", nil, parent)
	c:SetSize(CELL_W, CELL_H)
	c.index = i
	local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
	c:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + col * CELL_W, -row * CELL_H)
	c.halo = noGlow() -- (design 1) an earned milestone has no glow; the ring and disc say it
	c.disc = T.Circle(c, 48, "card", "ARTWORK")
	c.disc:SetPoint("CENTER", c, "TOP", 0, -30)
	c.ring = T.Tex(c, "ring", "ARTWORK", 1)
	c.ring:SetSize(50, 50)
	c.ring:SetPoint("CENTER", c.disc, "CENTER")
	c.icon = T.Icon(c, "star", 24, "white", "OVERLAY")
	c.icon:SetPoint("CENTER", c.disc, "CENTER")
	c.lock = T.Icon(c, "lock", 14, "muted", "OVERLAY")
	c.lock:SetPoint("CENTER", c.disc, "BOTTOMRIGHT", -6, 6)
	c.name = T.Text(c, "caption", "white", "CENTER", "medium")
	c.name:SetPoint("TOP", c, "TOP", 0, -60)
	c.name:SetWidth(CELL_W - 6)
	Try(c.name, "SetWordWrap", true)
	Try(c.name, "SetMaxLines", 2)
	c:EnableMouse(true)
	T.Tip(c, function(self) return self.m and (S(self.m.name) or self.m.id) end, function(self)
		local m = self.m
		if not m then return nil end
		local how = S(m.desc) or ""
		if self.earned then
			local when = day(self.earnedAt)
			return (when and ("Earned on " .. when .. ". ") or "Earned. ") .. how
		end
		return "How to earn: " .. how
	end)
	return c
end

local function buildRow(parent)
	local r = CreateFrame("Frame", nil, parent)
	r:SetSize(INNER, ROW_H - 6)
	r.bg = T.Rounded(r, "card", 12, "BACKGROUND", 0)
	r.icon = T.Icon(r, "summon", 18, "glow", "ARTWORK")
	r.icon:SetPoint("LEFT", r, "LEFT", 14, 0)
	r.dest = T.Text(r, "body", "white", "LEFT", "bold")
	r.dest:SetPoint("TOPLEFT", r, "TOPLEFT", 44, -9)
	r.dest:SetWidth(170)
	r.sub = T.Text(r, "caption", "muted", "LEFT", "regular")
	r.sub:SetPoint("TOPLEFT", r.dest, "BOTTOMLEFT", 0, -3)
	r.sub:SetWidth(190)
	r.price = T.Text(r, "body", "gold", "RIGHT", "bold")
	r.price:SetPoint("TOPRIGHT", r, "TOPRIGHT", -12, -9)
	r.stars = {}
	for i = 1, 5 do
		local st = T.Icon(r, "star", 10, "glow", "ARTWORK")
		st:SetPoint("TOPRIGHT", r, "TOPRIGHT", -12 - (5 - i) * 11, -29)
		r.stars[i] = st
	end
	r:EnableMouse(true)
	T.Tip(r, function(self) return self.trip and ("To " .. (S(self.trip.dest) or "?")) end, function(self)
		local t = self.trip
		if not t then return nil end
		local parts = { "With " .. (S(t.driver) or "a driver") .. (day(t.at) and (" on " .. day(t.at)) or "") .. "." }
		local saved = N(t.saved)
		if saved and saved > 0 then parts[#parts + 1] = "Saved about " .. UI.Duration(saved) .. " of flying." end
		local stars = N(t.stars)
		parts[#parts + 1] = stars and ("You gave " .. stars .. (stars == 1 and " star." or " stars.")) or "Not rated."
		return table.concat(parts, " ")
	end)
	return r
end

function UI.BuildTrips(body)
	tr.body = body
	local clip = CreateFrame("Frame", nil, body)
	-- (design 2, C) the scrolled page starts under the window's buttons (its first row, Time saved and the Wrapped
	-- chip, is full width, and rows would scroll up under them)
	clip:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -(UI.HEAD_ROW or 44))
	clip:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)
	Try(clip, "SetClipsChildren", true)
	clip:EnableMouseWheel(true)
	safeScript(clip, "OnMouseWheel", function(_, delta)
		tr.scrollTarget = math.max(0, math.min(tr.scrollMax or 0, tr.scrollTarget - (tonumber(delta) or 0) * 64))
	end)
	tr.clip = clip
	-- S6: the shared soft edges (more below / scrolled)
	-- (lift 12: the rows sit 5 levels up; Wrapped's story opens over the tab 30 up and must cover the fade)
	T.EdgeFade(clip, { source = function() return tr.scroll, tr.scrollMax end, lift = 12 })
	local c = CreateFrame("Frame", nil, clip)
	c:SetSize(WIN_W, 400)
	c:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, 0)
	tr.content = c

	-- (E3b-05 / D3-10) big page title on the page itself, then time saved (07 v2) and the level card
	tr.title = T.Text(c, "display", "white", "LEFT", "bold")
	tr.title:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -4)
	tr.title:SetText("Trips")
	tr.hero = buildHero(c)
	tr.hero:SetPoint("TOP", c, "TOP", 0, -48)
	local lv = T.Card(c, INNER, 100, { colour = "card", radius = 22 })
	lv:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -184)
	lv.medal = CreateFrame("Frame", nil, lv)
	lv.medal:SetSize(70, 70)
	lv.medal:SetPoint("LEFT", lv, "LEFT", 18, 0)
	lv.halo = noGlow() -- (design 1) no glow behind the level medal
	lv.disc = T.Circle(lv.medal, 66, "gold", "ARTWORK")
	lv.disc:SetPoint("CENTER", lv.medal, "CENTER")
	lv.ring = T.Tex(lv.medal, "ring", "ARTWORK", 1)
	lv.ring:SetSize(70, 70)
	lv.ring:SetPoint("CENTER", lv.medal, "CENTER")
	lv.ring:SetVertexColor(1, 1, 1, 0.7)
	lv.icon = T.Icon(lv.medal, "trophy", 34, "ink", "OVERLAY")
	lv.icon:SetPoint("CENTER", lv.medal, "CENTER")
	lv.title = T.Text(lv, "title", "white", "LEFT", "bold")
	lv.title:SetPoint("TOPLEFT", lv, "TOPLEFT", 106, -24)
	lv.title:SetWidth(INNER - 124)
	lv.bar = T.Bar(lv, INNER - 126, 8, "accent")
	lv.bar:SetPoint("TOPLEFT", lv, "TOPLEFT", 106, -54)
	lv.sub = T.Text(lv, "sub", "muted", "LEFT", "regular")
	lv.sub:SetPoint("TOPLEFT", lv, "TOPLEFT", 106, -70)
	lv.sub:SetWidth(INNER - 124)
	lv:EnableMouse(true)
	T.Tip(lv, "Rider levels", "Bronze from 3 rides, Silver from 10, Gold from 25. Drivers see your level when you request.")
	tr.level = lv
	-- a hairline under the level card
	tr.rule = T.Line(c, "line", 0.8)
	tr.rule:SetHeight(1)
	tr.rule:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -298)
	tr.rule:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PAD, -298)

	-- you and Wuber (review #19 + the author's flight costs): go-to driver, streak, spent, flight
	-- costs saved; only the chips with something to say
	tr.chips = {
		buildChip(c, "heart", "magenta"), buildChip(c, "star", "glow"), buildChip(c, "coin", "gold"),
	}
	T.Tip(tr.chips[1], "Your go-to driver", function() return tr.chipTips and tr.chipTips[1] or "The driver you've ridden with most." end)
	T.Tip(tr.chips[2], "Ride streak", function() return tr.chipTips and tr.chipTips[2] or "Days in a row you've taken a Wuber ride." end)
	T.Tip(tr.chips[3], "Spent on summons", function() return tr.chipTips and tr.chipTips[3] or "Every fare you've paid through Wuber, tips not counted." end)
	for _, ch in ipairs(tr.chips) do ch:Hide() end

	-- milestones, on a tray of their own (the medals exactly as they were)
	tr.tray = T.Card(c, INNER + 12, 150, { colour = "panel", radius = 22, shadow = false })
	tr.mHead = T.Text(tr.tray, "heading", "white", "LEFT", "bold")
	tr.mHead:SetText("Milestones")
	tr.mCount = T.Text(tr.tray, "heading", "muted", "LEFT", "regular")
	tr.grid = CreateFrame("Frame", nil, c)
	tr.grid:SetSize(WIN_W, CELL_H)
	tr.grid:SetFrameLevel((tonumber(tr.tray:GetFrameLevel()) or 0) + 2)

	-- history
	tr.hHead = T.Text(c, "heading", "white", "LEFT", "bold")
	tr.hHead:SetText("Your trips")
	tr.hCount = T.Text(c, "sub", "muted", "RIGHT", "regular")
	tr.list = CreateFrame("Frame", nil, c)
	tr.list:SetSize(WIN_W, 10)
	tr.empty = T.Text(c, "sub", "muted", "CENTER", "regular")
	tr.empty:SetWidth(INNER)
	tr.empty:SetText("No trips yet. Your first ride shows up here.")

	-- round 8: Azeroth Wrapped (its card, its chip) and the rainchecks you hold
	local WR = W.Mod("UI.Rider.Wrapped")
	if type(WR) == "table" and type(WR.Card) == "function" then
		tr.wrapCard = WR.Card(c)
		tr.wrapChip = WR.Chip(c)
		tr.wrapChip:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PAD, -10) -- (design 3) its right end stands on the cards' edge, not 4 past it
	end
	tr.rain = buildChip(c, "ride", "glow")
	T.Tip(tr.rain, "Rainchecks", function() return tr.rainTip or "Summons at no charge that drivers gave you after a paid ride failed." end)
	tr.rain:Hide()

	safeScript(body, "OnShow", function()
		tr.fresh = true
		tr.wrapChecked = false
		UI.UpdateTrips()
	end)
	-- the smooth scroll
	safeScript(clip, "OnUpdate", function(_, elapsed)
		-- the view's real height, once the game has laid it out: fitted again on a change
		-- the clip's own height when it has one (> 1; DS24-01), else the body's less the head row
		local h = type(clip.GetHeight) == "function" and N(clip:GetHeight())
		if not (h and h > 1) then
			local bh = N(body:GetHeight())
			h = bh and bh > 1 and (bh - (UI.HEAD_ROW or 44)) or nil
		end
		if h and h > 1 and h ~= tr.clipH then Mod.fit() end
		if tr.scroll == tr.scrollTarget then return end
		local k = math.min(1, (elapsed or 0) * 14)
		local y = tr.scroll + (tr.scrollTarget - tr.scroll) * k
		if math.abs(y - tr.scrollTarget) < 0.5 then y = tr.scrollTarget end
		tr.scroll = y
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, y)
		Mod.trimCells()
	end)
	-- "Scroll for your trips" below the scroll area while more lies below
	local cue = CreateFrame("Frame", nil, body)
	cue:SetSize(150, 22)
	cue:SetPoint("BOTTOM", body, "BOTTOM", 0, 8)
	-- (HUNT-109) above the rows but under the Settings panel (the window's level + 40), which slides over this tab
	cue:SetFrameLevel((tonumber(clip:GetFrameLevel()) or 1) + 30)
	cue:EnableMouse(false)
	cue.fill = T.PillFill(cue, "panel", 22, "BACKGROUND", 0)
	cue.label = T.Text(cue, "caption", "muted", "CENTER", "medium")
	cue.label:SetPoint("CENTER", cue, "CENTER", 0, 0)
	cue:Hide()
	tr.cue = cue
	-- the unfolded page
	local F = UI.Fold
	if type(F) == "table" and type(F.Register) == "function" then
		F.Register("trips", { build = Mod.foldBuild, layout = Mod.foldLayout })
	end
end

---------------------------------------------------------------------------
-- Unfolded: the milestones and the Wrapped card in the side pane
---------------------------------------------------------------------------

-- the side pane's own scroll (made on the first unfold)
function Mod.foldBuild(holder)
	local sd = { holder = holder, scroll = 0, scrollTarget = 0 }
	sd.clip = CreateFrame("Frame", nil, holder)
	sd.clip:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(UI.HEAD_ROW or 44)) -- (design 2, C) under the window's buttons
	sd.clip:SetWidth(WIN_W)
	sd.clip:SetHeight(N(holder:GetHeight()) or 544)
	Try(sd.clip, "SetClipsChildren", true)
	sd.clip:EnableMouseWheel(true)
	safeScript(sd.clip, "OnMouseWheel", function(_, delta)
		sd.scrollTarget = math.max(0, math.min(sd.scrollMax or 0, sd.scrollTarget - (tonumber(delta) or 0) * 64))
	end)
	T.EdgeFade(sd.clip, { source = function() return sd.scroll, sd.scrollMax end }) -- S6
	sd.content = CreateFrame("Frame", nil, sd.clip)
	sd.content:SetSize(WIN_W, 400)
	sd.content:SetPoint("TOPLEFT", sd.clip, "TOPLEFT", 0, 0)
	safeScript(sd.clip, "OnUpdate", function(_, elapsed)
		if sd.scroll == sd.scrollTarget then return end
		local k = math.min(1, (elapsed or 0) * 14)
		local y = sd.scroll + (sd.scrollTarget - sd.scroll) * k
		if math.abs(y - sd.scrollTarget) < 0.5 then y = sd.scrollTarget end
		sd.scroll = y
		sd.content:ClearAllPoints()
		sd.content:SetPoint("TOPLEFT", sd.clip, "TOPLEFT", 0, y)
	end)
	tr.side = sd
end

-- folded: the milestones and the card back in the one column; unfolded: in the side pane
function Mod.foldLayout(unfolded, holder)
	local sd = tr.side
	if not sd then return end
	tr.wide = unfolded and true or false
	local host = tr.wide and sd.content or tr.content
	for _, f in ipairs({ tr.tray, tr.grid }) do
		f:SetParent(host)
	end
	tr.grid:SetFrameLevel((N(tr.tray:GetFrameLevel()) or 0) + 2)
	if tr.wrapCard then tr.wrapCard:SetParent(tr.wide and holder or tr.content) end
	UI.UpdateTrips()
	-- the Wrapped story's month list (unfolded only)
	local WR = W.Mod("UI.Rider.Wrapped")
	if type(WR) == "table" and type(WR.SyncSummary) == "function" then WR.SyncSummary() end
end

---------------------------------------------------------------------------
-- Filling
---------------------------------------------------------------------------

local function stats()
	local s = type(W.Stats) == "function" and call(W.Stats) or nil
	if type(s) ~= "table" then s = {} end
	return {
		rides = N(s.rides) or 0, places = N(s.places) or 0, saved = N(s.saved) or 0,
		savedValue = N(s.savedValue) or 0, spent = N(s.spent) or 0,
	}
end

local function fillLevel(st)
	local lv = tr.level
	local tier, rides, from, nextAt
	if type(W.TierProgress) == "function" then tier, rides, from, nextAt = call(W.TierProgress) end
	-- (round 13, I12) one number on the whole page: the rides the line under the time saved
	-- counts. A level from another count is worked out again from that one (W.TIERS).
	if N(rides) ~= st.rides and type(W.TIERS) == "table" then
		rides = st.rides
		tier = type(W.Tier) == "function" and N(call(W.Tier, rides)) or 0
		from = (tier and tier > 0 and type(W.TIERS[tier]) == "table") and N(W.TIERS[tier].at) or 0
		nextAt = type(W.TIERS[(tier or 0) + 1]) == "table" and N(W.TIERS[(tier or 0) + 1].at) or nil
	end
	rides = N(rides) or st.rides
	tier = math.max(0, math.min(3, math.floor(N(tier) or (type(W.Tier) == "function" and N(call(W.Tier)) or 0))))
	from, nextAt = N(from) or 0, N(nextAt)
	local look = T.TIER[tier] or T.TIER[0]
	local name = type(W.TierName) == "function" and S(call(W.TierName, tier)) or look.name
	lv.title:SetText(tier >= 1 and (name .. " Rider") or "New rider")
	local rideText = rides .. (rides == 1 and " ride" or " rides")
	if nextAt then
		local need = math.max(0, nextAt - rides)
		local nextName = (T.TIER[tier + 1] and T.TIER[tier + 1].name) or "the next level"
		if type(W.TierName) == "function" then nextName = S(call(W.TierName, tier + 1)) or nextName end
		lv.sub:SetText(rideText .. " · " .. need .. " more to " .. nextName)
		local span = math.max(1, nextAt - from)
		lv.bar:SetValue((rides - from) / span, true)
	else
		lv.sub:SetText(rideText .. " · the top level. Legend.")
		lv.bar:SetValue(1, true)
	end
	local colour = tier >= 1 and look.colour or "raised"
	lv.disc:SetVertexColor(T.RGB(colour))
	lv.icon:SetVertexColor(T.RGB(tier >= 1 and "ink" or "muted"))
	lv.halo:SetVertexColor(T.RGB(colour, 0.5))
	lv.halo:SetShown(tier >= 1) -- hidden below the first level, never an alpha change
	lv.bar:SetColor("accent")
	-- my own Pioneer badge on the medal (the shipped list only; a founder: none)
	local pb = T.ShowPioneer(lv, "pioneer", T.PioneerLook(W.myKey), 22, lv.medal, true)
	if pb then pb:ClearAllPoints() pb:SetPoint("CENTER", lv.medal, "TOPRIGHT", -6, -6) end
end

local function fillHero(st)
	local h = tr.hero
	-- "4g 12s saved vs flying · 12 rides across 5 places" (flight costs: exact only, else what
	-- the time is worth, else just the rides)
	local cap = st.rides > 0 and (st.rides .. (st.rides == 1 and " ride" or " rides") .. " across " .. st.places .. (st.places == 1 and " place" or " places"))
		or "Your first ride starts the count"
	local flight
	if UI.FlightSavedLine then flight = select(2, UI.FlightSavedLine()) end
	local worth = st.savedValue > 0 and ("worth " .. roundMoney(st.savedValue) .. " of your time") or nil
	if flight then
		cap = roundMoney(flight) .. " saved vs flying · " .. cap
	elseif worth then
		cap = cap .. " · " .. worth
	end
	h.cap:SetText(cap)
	local into = st.saved % 3600
	h.tip = "Flying you didn't have to do, added up over every ride (" .. math.ceil((3600 - into) / 60) .. " min to "
		.. (math.floor(st.saved / 3600) + 1) .. "h)" .. (worth and (", " .. worth) or "")
		.. (flight and (". What the flight masters would have charged for the same trips: " .. money(flight)) or "")
		.. ". Your time's worth is in Settings."
	-- count up when the tab opens (or the number grows); else just show it
	if tr.fresh or (h.target and st.saved > h.target) then
		h.from = tr.fresh and 0 or (h.shown or h.target or 0)
		h.to, h.at = st.saved, N(call(GetTime)) or 0
		h.big:SetText(hm(h.from))
	elseif not h.to then
		h.big:SetText(hm(st.saved))
	end
	h.target = st.saved
end

-- The habits (long lines, for the chips' tooltips): only those with data.
function UI.TripsHabits(raw)
	raw = raw or (type(W.Stats) == "function" and call(W.Stats)) or {}
	local out = {}
	local streak = N(raw.streakDays) or 0
	out[2] = streak >= 2 and (streak .. "-day ride streak · ride tomorrow to keep it") or nil
	local favN, fav = N(raw.favouriteCount) or 0, S(raw.favouriteDriver)
	out[1] = (fav and favN >= 2) and ("Your go-to driver: " .. W.Short(fav) .. " · " .. favN .. " rides") or nil
	local spent = N(raw.spent) or 0
	out[3] = spent > 0 and ("Spent " .. money(spent) .. " on summons in all") or nil
	out[4] = UI.FlightSavedLine and UI.FlightSavedLine() or nil
	return out
end

-- The chips' own words (07 v2): "Go-to: Mia (5)", "4-day streak", "Spent 6g 40s" (the flight costs
-- saved are in the hero's caption).
function UI.TripsChips(raw)
	raw = raw or (type(W.Stats) == "function" and call(W.Stats)) or {}
	local out = {}
	local favN, fav = N(raw.favouriteCount) or 0, S(raw.favouriteDriver)
	out[1] = (fav and favN >= 2) and ("Go-to: " .. W.Short(fav) .. " (" .. favN .. ")") or nil
	local streak = N(raw.streakDays) or 0
	out[2] = streak >= 2 and (streak .. "-day streak") or nil
	local spent = N(raw.spent) or 0
	out[3] = spent > 0 and ("Spent " .. money(spent)) or nil
	return out
end

local function fillChips(top)
	if not W.Advanced() then
		for i = 1, 3 do tr.chips[i]:Hide() end
		tr.rule:SetShown(false)
		return top
	end
	local raw = (type(W.Stats) == "function" and call(W.Stats)) or {}
	local words, tips = UI.TripsChips(raw), UI.TripsHabits(raw)
	tr.chipTips = tips
	local half = (INNER - 8) / 2
	local x, y, any = 0, top, false
	for i = 1, 3 do
		local ch = tr.chips[i]
		if words[i] then
			ch.text:SetWidth(INNER - 60) -- measure at the full size, never at a width an earlier, shorter text left
			ch.text:SetText(words[i])
			local need = 50 + T.TextWidth(ch.text, words[i]) + 14
			local w = need <= half and half or INNER
			if w == INNER and x > 0 then x, y = 0, y + 52 end
			ch:SetSize(w, 44)
			ch.text:SetWidth(w - 60)
			ch:ClearAllPoints()
			ch:SetPoint("TOPLEFT", tr.content, "TOPLEFT", PAD + x, -y)
			ch:Show()
			any = true
			if w == INNER or x > 0 then x, y = 0, y + 52 else x = half + 8 end
		else
			ch:Hide()
		end
	end
	if x > 0 then y = y + 52 end
	tr.rule:SetShown(any)
	if not any then return top end
	return y + 4
end

-- The rider's rainchecks still usable (W.Raincheck.Mine(): active, not expired), newest first.
function UI.RaincheckList()
	local R = W.Raincheck
	local list = type(R) == "table" and type(R.Mine) == "function" and call(R.Mine) or nil
	local out = {}
	if type(list) ~= "table" then return out end
	local t = type(time) == "function" and time() or 0
	for _, rc in ipairs(list) do
		if type(rc) == "table" and S(rc.state) == "active" and (N(rc.expires) or t + 1) > t then out[#out + 1] = rc end
	end
	return out
end

-- The Wrapped card (first visit in the first 10 days of a month), the Wrapped chip, and the
-- "Rainchecks (2)" row, under the habit chips. Returns the next free y.
local function fillRound8(top)
	local WR = W.Mod("UI.Rider.Wrapped")
	if tr.wrapCard and type(WR) == "table" then
		tr.wrapTop = nil
		if not W.Advanced() then
			tr.wrapCard:Hide()
			tr.wrapChip:Hide()
		else
			local y, m = nil, nil
			if tr.fresh or not tr.wrapChecked then
				tr.wrapChecked = true
				y, m = WR.Due()
				if y then WR.MarkSeen(y, m) tr.wrapDue = { y, m } else tr.wrapDue = nil end
			elseif tr.wrapDue then
				y, m = tr.wrapDue[1], tr.wrapDue[2]
			end
			if y and tr.wide then
				-- unfolded: at the foot of the side pane
				tr.wrapCard:SetMonth(y, m)
				tr.wrapCard:ClearAllPoints()
				tr.wrapCard:SetPoint("BOTTOMLEFT", tr.side.holder, "BOTTOMLEFT", PAD, PAD)
				tr.wrapCard:Show()
			elseif y then
				tr.wrapCard:SetMonth(y, m)
				tr.wrapCard:ClearAllPoints()
				tr.wrapCard:SetPoint("TOPLEFT", tr.content, "TOPLEFT", PAD, -top)
				tr.wrapCard:Show()
				tr.wrapTop = top
				top = top + 104
			else
				tr.wrapCard:Hide()
			end
			tr.wrapChip:SetShown(not y and #WR.Months() > 0)
		end
	end
	local list = UI.RaincheckList()
	if #list > 0 then
		local ch = tr.rain
		ch.text:SetText("Rainchecks (" .. #list .. ")")
		ch:SetSize(INNER, 44)
		ch.text:SetWidth(INNER - 60)
		ch:ClearAllPoints()
		ch:SetPoint("TOPLEFT", tr.content, "TOPLEFT", PAD, -top)
		ch:Show()
		local tips = {}
		for _, rc in ipairs(list) do
			local who = S(rc.driver) and W.Short(S(rc.driver)) or S(rc.service) or "a crew"
			local untilDay = UI.RaincheckDate and UI.RaincheckDate(rc.expires) or nil
			tips[#tips + 1] = who .. ": one summon at no charge, up to " .. money(N(rc.cover) or 0) .. (untilDay and (", until " .. untilDay) or "")
		end
		tr.rainTip = table.concat(tips, "\n") .. "\nUsed when you book that crew again (Confirm says so)."
		top = top + 52
	else
		tr.rain:Hide()
	end
	return top
end

local function fillMilestones(top)
	-- folded: in the one column; unfolded: in the side pane's scroll, 3 to a row
	local host = tr.wide and tr.side.content or tr.content
	local cols, pitch, rowH = COLS, CELL_W, CELL_H
	if tr.wide then cols, pitch, rowH = WIDE.cols, WIDE.pitch, WIDE.rowH end
	tr.tray:ClearAllPoints()
	tr.tray:SetPoint("TOPLEFT", host, "TOPLEFT", PAD - 6, -top)
	tr.mHead:ClearAllPoints()
	tr.mHead:SetPoint("TOPLEFT", host, "TOPLEFT", PAD + 6, -(top + 18))
	tr.mCount:ClearAllPoints()
	tr.mCount:SetPoint("LEFT", tr.mHead, "RIGHT", 6, 0)
	tr.grid:ClearAllPoints()
	tr.grid:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -(top + 50))
	local list = type(W.MILESTONES) == "table" and W.MILESTONES or {}
	local earnedMap = (W.db and type(W.db.milestones) == "table") and W.db.milestones or {}
	local n, got = 0, 0
	local fx = T.FxLevel()
	local first = tr.seen == nil
	tr.seen = tr.seen or {}
	for _, m in ipairs(list) do
		if type(m) == "table" and S(m.id) then
			n = n + 1
			local cell = tr.cells[n]
			if not cell then
				cell = buildCell(tr.grid, n)
				tr.cells[n] = cell
			end
			local at = earnedMap[m.id]
			local earned = at ~= nil and at ~= false
			cell.m, cell.earned, cell.earnedAt = m, earned, N(at)
			cell:ClearAllPoints()
			cell:SetPoint("TOPLEFT", tr.grid, "TOPLEFT", PAD + ((n - 1) % cols) * pitch, -math.floor((n - 1) / cols) * rowH)
			cell.name:SetText(S(m.name) or m.id)
			cell.icon:SetTexture(T.MEDIA .. UI.MilestoneIcon(m.id, m))
			if earned then
				got = got + 1
				cell.disc:SetVertexColor(T.RGB("accent"))
				cell.ring:SetVertexColor(T.RGB("glow"))
				cell.icon:SetVertexColor(T.RGB("ink"))
				cell.halo:SetVertexColor(T.RGB("magenta", 0.45))
				cell.halo:Show()
				cell.lock:Hide()
				cell.name:SetTextColor(T.RGB("white"))
				cell:SetAlpha(1)
				-- one burst for a milestone earned since you last looked
				if not first and not tr.seen[m.id] and tr.body:IsVisible() then
					A.Pop(cell, 0.4)
					if fx ~= "off" and W.FX and type(W.FX.Play) == "function" then
						pcall(W.FX.Play, "milestone", cell, { size = 72 })
					end
				end
				tr.seen[m.id] = true
			else
				cell.disc:SetVertexColor(T.RGB("card"))
				cell.ring:SetVertexColor(T.RGB("line"))
				cell.icon:SetVertexColor(T.RGB("off"))
				cell.halo:Hide()
				cell.lock:Show()
				cell.name:SetTextColor(T.RGB("muted"))
				cell:SetAlpha(0.6)
			end
			cell:Show()
		end
	end
	for i = n + 1, #tr.cells do tr.cells[i]:Hide() end
	tr.mCount:SetText(n > 0 and ("(" .. got .. " of " .. n .. ")") or "")
	local rows = math.ceil(n / cols)
	tr.grid:SetHeight(math.max(1, rows * rowH))
	tr.tray:SetHeight(50 + rows * rowH + 6)
	return rows * rowH
end

local function fillHistory(top)
	local trips = (W.db and type(W.db.rides) == "table") and W.db.rides or {}
	tr.hHead:ClearAllPoints()
	tr.hHead:SetPoint("TOPLEFT", tr.content, "TOPLEFT", PAD, -top)
	tr.hCount:ClearAllPoints()
	tr.hCount:SetPoint("TOPRIGHT", tr.content, "TOPRIGHT", -PAD, -top - 4)
	tr.list:ClearAllPoints()
	tr.list:SetPoint("TOPLEFT", tr.content, "TOPLEFT", PAD, -top - 30)
	tr.listTop = top + 30 -- the first row's top in content px, for the cue's clearance
	tr.histTop = top
	local shown = 0
	for i = #trips, 1, -1 do
		local t = trips[i]
		if type(t) == "table" and not t.unpaid then -- (an unpaid end is not saved in Trips; the saved row stays)
			shown = shown + 1
			local r = tr.rows[shown]
			if not r then
				r = buildRow(tr.list)
				tr.rows[shown] = r
			end
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", tr.list, "TOPLEFT", 0, -(shown - 1) * ROW_H)
			r.trip = t
			r.dest:SetText(S(t.dest) or "Somewhere")
			local when = day(t.at)
			local saved = N(t.saved)
			local sub = "with " .. W.Short(S(t.driver) or "a driver") .. (when and (" · " .. when) or "")
			if saved and saved > 0 then sub = sub .. " · saved " .. UI.Duration(saved) end
			r.sub:SetText(sub)
			r.price:SetText(money(N(t.price) or 0))
			local stars = math.floor(N(t.stars) or 0)
			for k, st in ipairs(r.stars) do
				st:SetVertexColor(T.RGB(k <= stars and "glow" or "line"))
				if stars > 0 then st:Show() else st:Hide() end
			end
			r.live = true
			r:Show()
		end
	end
	for i = shown + 1, #tr.rows do
		tr.rows[i].live = false
		tr.rows[i]:Hide()
	end
	tr.hCount:SetText(shown > 0 and (shown .. (shown == 1 and " trip" or " trips")) or "")
	if shown == 0 then
		tr.empty:ClearAllPoints()
		tr.empty:SetPoint("TOP", tr.content, "TOP", 0, -top - 44)
		tr.empty:Show()
		return top + 80
	end
	tr.empty:Hide()
	return top + 30 + shown * ROW_H + 10
end

-- folded: a milestone row the view's edge would slice is left out (never half a medal),
-- and the cue says there is more below. Each time the page is drawn or scrolls.
-- the page's state (for tests: tr.cue, tr.cells, tr.clip)
function Mod.view() return tr end

-- the view's height. In the real client GetHeight() is 0 until the game has laid the
-- clip out (on the unfolded page, right after the window re-anchored): then the last height measured,
-- else the body's 544. A 0 here hid every trip row under the cue (tour 19).
local function viewH()
	local h = tr.clip and type(tr.clip.GetHeight) == "function" and N(tr.clip:GetHeight())
	if not (h and h > 1) and tr.body then
		local bh = N(tr.body:GetHeight())
		h = bh and bh > 1 and (bh - (UI.HEAD_ROW or 44)) or nil
	end
	if h and h > 1 then tr.clipH = h end
	return tr.clipH or 544
end

-- the scroll range for the page's height and the view's, then the cells, rows and cue
function Mod.fit()
	if not tr.clip then return end
	tr.scrollMax = math.max(0, (tr.height or 0) - viewH())
	tr.scrollTarget = math.max(0, math.min(tr.scrollMax, tr.scrollTarget or 0))
	Mod.trimCells()
end

function Mod.trimCells()
	if not tr.clip or not tr.cue then return end
	-- the full view: while the page is cut above the cue the clip itself is 30 shorter (its true height,
	-- DS24-01), and the cue's pill lies in those 30; the bands below are worked out on the full view
	local clipH = viewH() + (tr.cueClipped and 30 or 0)
	local y = tr.scroll or 0
	local below = (tr.scrollMax or 0) - y
	local lo, hi = y + clipH - 30, y + clipH - 8
	-- (E3b-02) keep the cue visible whenever content lies below; if the Wrapped card reaches the cue's band,
	-- anchor clip above the cue band so the cue never lies across the card
	local wrapInBand = not tr.wide and tr.wrapTop and tr.wrapCard and tr.wrapCard:IsShown()
		and tr.wrapTop < hi and tr.wrapTop + 96 > lo
	local showCue = below > 1
	-- (r50 H24-01) a medal the cue's band would touch is hidden whole, the first row too (see below), so the
	-- clip only needs to end above the cue for the Wrapped card
	local clipForCue = showCue and wrapInBand
	local reanchored = false -- the clip's own height is stale until the game lays it out again
	if tr.body and tr.cueClipped ~= clipForCue then
		reanchored = true
		tr.cueClipped = clipForCue
		tr.clip:ClearAllPoints()
		tr.clip:SetPoint("TOPLEFT", tr.body, "TOPLEFT", 0, -(UI.HEAD_ROW or 44))
		tr.clip:SetPoint("BOTTOMRIGHT", tr.body, "BOTTOMRIGHT", 0, clipForCue and 30 or 0)
	end
	local anyCell = false
	local lowest = nil -- the bottom (view px) of the lowest whole thing still shown: the cue sits right under it
	if not tr.wide and tr.gridTop then
		-- a cell the cue's pill band (the view's bottom 30) would touch is left out while the cue shows
		local room = clipH - (showCue and 30 or 0)
		for _, cell in ipairs(tr.cells) do
			if cell.m then
				local row = math.floor((cell.index - 1) / COLS)
				local top = tr.gridTop + row * CELL_H - y
				local whole = top >= -0.5 and top + CELL_H <= room + 0.5
				-- (r50 H24-01) no exception for the first row: the cue never covers a shown medal. With no cue
				-- (nothing below) the whole page fits, so the first row stays whenever it fits at all
				cell:SetShown(whole or (not showCue and row == 0 and y <= 0.5))
				if cell:IsShown() then lowest = math.max(lowest or 0, top + CELL_H); anyCell = true end
			end
		end
		-- (#2) a card with no medal shown has no job: hidden, on every pass (open and after each scroll)
		if tr.tray:IsShown() ~= anyCell then tr.tray:SetShown(anyCell) end
	end
	-- a trip row the cue's pill would touch is hidden whole, never covered;
	-- hidden, not faded, and only by the cue: shown again on every pass
	local edge = y + clipH - 30 -- the cue's height plus its gap
	for i, r in ipairs(tr.rows) do
		r.cut = (r.live and showCue and tr.listTop
			and tr.listTop + (i - 1) * ROW_H + (ROW_H - 6) > edge + 0.5) and true or false
		r:SetShown(r.live and not r.cut)
		if r.live and not r.cut and tr.listTop then lowest = math.max(lowest or 0, tr.listTop + (i - 1) * ROW_H + (ROW_H - 6) - y) end
	end
	-- like a trip row, a heading the pill's band (the view's bottom 30 down to 8) would touch is hidden
	-- whole (with its count), never covered; shown again on every pass, and always on the unfolded page
	local adv = W.Advanced()
	local mCut, hCut = false, false
	if not tr.wide and showCue and tr.histTop then
		if tr.gridTop then mCut = tr.gridTop - 32 < hi and tr.gridTop - 6 > lo end
		hCut = tr.histTop < hi and tr.histTop + 26 > lo
	end
	-- folded: no medal shown means no title and no card (never a heading over an empty card)
	local emptyCard = not tr.wide and tr.gridTop and not anyCell
	if emptyCard then mCut = true end
	tr.mHead:SetShown(adv and not mCut)
	tr.mCount:SetShown(adv and not mCut)
	tr.hHead:SetShown(not hCut)
	tr.hCount:SetShown(not hCut)
	-- (only what lies in the view: a heading still below it is not what the cue sits under)
	local function seen(bottom)
		if bottom <= clipH - 30 then lowest = math.max(lowest or 0, bottom) end
	end
	if tr.histTop and not hCut then seen(tr.histTop + 26 - y) end
	-- (r50 H24-01 with r3e) the first medal row can be out whole at the top of the page: the cue then sits
	-- under the Medals heading, not under a blank band where the row was
	if not tr.wide and tr.gridTop and adv and not mCut then seen(tr.gridTop - 6 - y) end
	-- the card left out whole: the cue sits under what lies above it (chips, Rainchecks), not over a blank band
	if emptyCard and adv then seen(tr.gridTop - 50 - y) end
	if not tr.wide and tr.wrapTop and tr.wrapCard and tr.wrapCard:IsShown() then seen(tr.wrapTop + 104 - y) end
	-- the cue sits right under the last whole thing shown, never over a blank band the rows left out (the
	-- cue's band is the view's bottom 30; a row too tall for the room is out whole, so blank can lie above it)
	local lift = 0
	if showCue and lowest and lowest > 0 and not (reanchored or tr.cueClipped or wrapInBand) then lift = math.max(0, math.min(clipH - 30 - lowest - 6, clipH - 80)) end
	if tr.cueLift ~= lift then
		tr.cueLift = lift
		tr.cue:ClearAllPoints()
		tr.cue:SetPoint("BOTTOM", tr.body, "BOTTOM", 0, 8 + lift)
	end
	if showCue then
		local t = (tr.histTop and tr.histTop - y > clipH) and "Scroll for your trips" or "Scroll for more"
		tr.cue.label:SetText(t)
		tr.cue:SetWidth(math.floor((T.TextWidth(tr.cue.label, t) or 100) + 28))
		tr.cue:Show()
	else
		tr.cue:Hide()
	end
end

function UI.UpdateTrips()
	if not tr.body then return end
	-- (round 13, I12) a milestone whose rule holds now is recorded first, by the recorder with its
	-- celebration (it fires only for new ones), so W.db.milestones is the one source and an earned
	-- one never locks again. Before anything is drawn, and its MILESTONE redraws nothing: a redraw
	-- inside this one would take the first visit's Wrapped card away (MarkSeen already done)
	if type(W.CheckMilestones) == "function" and not tr.recording then
		tr.recording = true
		pcall(W.CheckMilestones)
		tr.recording = false
	end
	local st = stats()
	fillLevel(st)
	fillHero(st)
	local top = fillChips(310)
	top = fillRound8(top)
	local adv = W.Advanced()
	local height
	if not adv then
		tr.tray:Hide()
		tr.grid:Hide()
		tr.mHead:Hide()
		tr.mCount:Hide()
		tr.gridTop = nil
		if tr.wide and tr.side then
			tr.side.content:SetHeight(10)
			tr.side.scrollMax = 0
			tr.side.scrollTarget = 0
		end
		tr.histTop = top + (tr.wide and 10 or 0)
		height = fillHistory(tr.histTop)
	elseif tr.wide then
		tr.tray:Show()
		tr.grid:Show()
		-- unfolded: the milestones scroll on their own in the side pane
		local gridH = fillMilestones(WIDE.top)
		local sd = tr.side
		local sideH = WIDE.top + 50 + gridH + 6 + WIDE.top
		sd.content:SetHeight(sideH)
		local room = (N(sd.holder:GetHeight()) or 544) - (UI.HEAD_ROW or 44) - ((tr.wrapCard and tr.wrapCard:IsShown()) and (WIDE.wrapH + PAD + 8) or 0)
		-- the card keeps a margin above the pane's bottom edge (it scrolls when it is longer)
		room = room - WIDE.top
		sd.clip:SetHeight(math.max(10, room))
		sd.scrollMax = math.max(0, sideH - WIDE.top - room)
		sd.scrollTarget = math.max(0, math.min(sd.scrollMax, sd.scrollTarget or 0))
		height = fillHistory(top + 10)
	else
		tr.tray:Show()
		tr.grid:Show()
		local gridH = fillMilestones(top)
		tr.gridTop = top + 50
		tr.histTop = top + 50 + gridH + 6 + 20
		height = fillHistory(tr.histTop)
	end
	tr.content:SetHeight(height)
	tr.height = height
	Mod.fit()
	if tr.fresh then
		tr.fresh = false
		A.Stagger({ tr.hero, tr.level }, 0.05, "SlideUp")
	end
end

W.Listen("MILESTONE", function()
	if tr.body and tr.body:IsVisible() and not tr.recording then UI.UpdateTrips() end
end)
W.Listen("RAINCHECK", function()
	if tr.body and tr.body:IsVisible() then UI.UpdateTrips() end
end)
W.Listen("SETTINGS", function(key)
	if key == "advanced" and tr.body and tr.body:IsVisible() then UI.UpdateTrips() end
end)
