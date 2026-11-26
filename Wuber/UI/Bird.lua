-- Module: UI.Bird
-- Purpose: "Skip the bird": when the flight map opens and an open driver's summon beats flying, a
--   small card beside the map (never over it), once per open, with Open Wuber.
-- API: Mod.Pick, Mod.Card, Mod.Layout, Mod.Place, Mod.Show, Mod.Hide, Mod.Why
--   Why(): nil, or the line /wuber why prints for a hidden card ("Skip the bird: ..."); read-only.
-- Internals: mapFrame, lowerStrata, aboveStrata, buildCard, onOpen
-- Uses: UI.Kit
-- Later: (none)
-- Events: listens On TAXIMAP_OPENED, On TAXIMAP_CLOSED, Listen FLIGHTMAP_SHOWN (the map frame's OnShow, from Core.Flights); fires SETTINGS (birdTip, from "Don't show again")
-- Standalone: no
-- Test: tests/ui/bird_test.lua
-- From: new in Wuber 2.3.0 (SPEC7 section 5.11; owner C)
--
-- The common rules for opening by itself (combat, a cinematic, the first seconds after login) are UI.MayOpen("bird") (UI.Kit).
-- Not annoying: at most once per flight-map open (reset on close), and on EVERY open where a summon beats flying by at least a minute (no per-session limit); never in combat or during a
-- ride before the summon lands (a ride that arrived, is paying, done or ended does not block); never when no driver matches; never over the map (beside TaxiFrame / FlightMapFrame's
-- right edge, else its left edge, else below it; on screen, clear of MinimapCluster when it can), a strata below the map's, the mouse only on
-- the card. Setting (Riding): "Flight offers" (W.db.birdTip, default on); the card's x
-- offers "Don't show again". The card fades in 0.2 s and stays until the player closes it (x, Don't show again, Open Wuber), takes a flight or closes the flight map (TAXIMAP_CLOSED, or a once-a-second check that the map is still shown); no timer hides it. It fades out 0.2 s. Its click opens
-- Confirm for that driver (not secure; the taxi map stays). Core.Flights keeps its own
-- TAXIMAP listeners (learning prices).

local _, W = ...
local Mod = W.Module("UI.Bird", { "UI.Kit" })
local KitMod = W.Mod("UI.Kit")
local N = KitMod.N
local S = KitMod.S
local call = KitMod.call
local duration = KitMod.duration
local money = KitMod.money
local myKey = KitMod.myKey
local rideActive = KitMod.rideActive
local safeScript = KitMod.safeScript
local T = W.Theme
local A = T.Animate
local UI = W.UI

local MAXW = 300
local LABEL_MIN = 98 -- the "Don't show again" label's least width (#258: the game draws it about 6% wider than the font table: 92 at 11 px)
local W_, H_, GAP, CHECK = 220, 74, 8, 1
local MIN_BACK = 60 -- the card is only worth showing when the summon gives at least a minute back
-- the wait a summon takes off the flight is UI.SummonWait(d): the driver's own average when they send one, else W.SUMMON_SECS; the same number the Fly or summon card uses for that driver
local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }

local card, shownThisOpen, placeTried

-- the game's flight map that is showing (TaxiFrame, else the newer FlightMapFrame)
local function mapFrame()
	for _, f in ipairs({ TaxiFrame or false, FlightMapFrame or false }) do
		if type(f) == "table" and type(f.IsShown) == "function" and W.Plain(call(f.IsShown, f)) == true then return f end
	end
	return nil
end

local STRATA_UP = { BACKGROUND = "LOW", LOW = "MEDIUM", MEDIUM = "HIGH", HIGH = "DIALOG", DIALOG = "FULLSCREEN",
	FULLSCREEN = "FULLSCREEN_DIALOG", FULLSCREEN_DIALOG = "TOOLTIP", TOOLTIP = "TOOLTIP" }
local function aboveStrata(strata) return STRATA_UP[strata] or "TOOLTIP" end

local function strataRank(strata)
	for i, s in ipairs(STRATA) do
		if s == strata then return i end
	end
	return 0
end

local function lowerStrata(strata)
	for i, s in ipairs(STRATA) do
		if s == strata then return STRATA[math.max(1, i - 1)] end
	end
	return "MEDIUM"
end

-- The driver worth suggesting: open, not you, flying there is known from here and the summon
-- beats flying by at least a minute (the flight less that driver's summon wait, UI.SummonWait, is MIN_BACK or more, so the
-- card's time back is never "under a minute"); the most prominent, then the cheapest. Returns d, info or nil.
function Mod.Pick()
	local best, bestInfo
	for _, d in ipairs(UI.Drivers()) do
		if d.state == "open" and d.key ~= myKey() then
			local cost = type(W.FlightCost) == "function" and N((call(W.FlightCost, nil, d.dest))) or nil
			local secs, src = nil, nil
			if cost and type(W.FlightTime) == "function" then secs, src = call(W.FlightTime, nil, d.dest) end
			secs = N(secs)
			if cost and not secs and type(W.TravelSaved) == "function" then secs, src = N((call(W.TravelSaved, d.dest))), "est" end
			local wait = UI.SummonWait(d)
			if cost and secs and secs - wait >= MIN_BACK then
				local glow = UI.Prominence and select(1, UI.Prominence(d)) or 0
				local info = { cost = cost, secs = secs, back = secs - wait, about = S(src) ~= "own" and S(src) ~= "shared", glow = N(glow) or 0 }
				if not best or info.glow > bestInfo.glow or (info.glow == bestInfo.glow and d.price < best.price) then
					best, bestInfo = d, info
				end
			end
		end
	end
	return best, bestInfo
end

local function buildCard()
	local c = CreateFrame("Button", nil, UIParent)
	c:SetSize(W_, H_)
	c:SetClampedToScreen(true)
	c.card = T.Card(c, W_, H_, { colour = { 0.09, 0.08, 0.17, 0.97 }, radius = 14, border = "accent" })
	c.card:SetAllPoints(c)
	c.icon = T.Icon(c.card, "summon", 18, "glow", "ARTWORK")
	c.icon:SetPoint("TOPLEFT", c, "TOPLEFT", 10, -10)
	c.text = T.Text(c.card, "caption", "white", "LEFT", "medium")
	c.text:SetPoint("TOPLEFT", c, "TOPLEFT", 34, -8)
	c.text:SetWidth(W_ - 60)
	T.Lines(c.text, 4) -- never cut: a long wait or flight wraps
	c.sub = T.Text(c.card, "caption", "muted", "LEFT", "regular")
	c.sub:SetPoint("TOPLEFT", c.text, "BOTTOMLEFT", 0, -2)
	c.sub:SetWidth(W_ - 60)
	T.Lines(c.sub, 4) -- a long name or place wraps
	c.open = T.Pill(c.card, "Book", "primary", 76, 22)
	c.open:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 34, 7)
	safeScript(c.open, "OnClick", function() Mod.Open() end)
	T.Tip(c.open, "Book", "Book this summon instead of flying. The flight map stays open.")
	c.x = CreateFrame("Button", nil, c.card)
	c.x:SetSize(22, 22)
	c.x:SetPoint("TOPRIGHT", c, "TOPRIGHT", -3, -3)
	c.x:RegisterForClicks("LeftButtonUp")
	c.x.glyph = T.Icon(c.x, "close", 9, "muted", "ARTWORK")
	c.x.glyph:SetPoint("CENTER", c.x, "CENTER")
	T.Press(c.x)
	safeScript(c.x, "OnClick", function() Mod.Hide() end)
	T.Tip(c.x, "Close", "Hide this tip.")
	c.never = CreateFrame("Button", nil, c.card)
	c.never:SetSize(76, 18)
	c.never:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -8, 9)
	c.never:RegisterForClicks("LeftButtonUp")
	c.never.label = T.Text(c.never, "caption", "muted", "RIGHT", "regular")
	c.never.label:SetPoint("RIGHT", c.never, "RIGHT", 0, 0)
	c.never.label:SetText("Don't show again")
	T.Press(c.never)
	safeScript(c.never, "OnClick", function()
		if W.db then W.db.birdTip = false end
		W.Fire("SETTINGS", "birdTip")
		UI.Toast("No more flight master tips. Turn them back on in Settings > Riding > Flight offers.", "info")
		Mod.Hide()
	end)
	T.Tip(c.never, "Don't show again", "No more of these tips. Turn them back on in Settings > Riding > Flight offers.")
	c:RegisterForClicks("LeftButtonUp")
	T.Press(c)
	safeScript(c, "OnClick", function() Mod.Open() end)
	c.tipBody = "A Wuber driver summons there faster than the flight. Click to book."
	T.Tip(c, "Skip the bird", function(self) return self.tipBody end)
	c:Hide()
	return c
end

function Mod.Card() return card end

-- Sizes the card from its real contents: the Open Wuber pill and the "Don't show again" label
-- share the bottom row when both fit in MAXW (pill left, label right, a gap between), else the
-- label goes on its own row under the pill. Returns width, height, stacked.
function Mod.Layout(c)
	local lw = N(call(c.never.label.GetStringWidth, c.never.label)) or 76
	-- the font may not be loaded yet (a narrower stand-in measures about 60): never less than the real width, about 86 at 9pt
	lw = math.max(LABEL_MIN, math.ceil(lw) + 2)
	local pillW, left, pad, gapRow = 76, 34, 10, 10
	local w, h, stacked = math.max(W_, left + pillW + gapRow + lw + pad), H_, false
	if w > MAXW then
		stacked = true
		w, h = math.max(W_, left + pillW + pad, 10 + lw + pad), H_ + 20
	end
	c:SetSize(w, h)
	c.card:SetSize(w, h)
	c.text:SetWidth(w - 60)
	c.sub:SetWidth(w - 60)
	-- the card follows the two lines: taller if either wraps (11pt text is about 13 high)
	local th1 = N(call(c.text.GetStringHeight, c.text)) or 0
	local th2 = N(call(c.sub.GetStringHeight, c.sub)) or 0
	local lh = 13
	if th1 <= 0 then th1 = lh end
	if th2 <= 0 then th2 = lh end
	local th = th1 + 2 + th2
	h = math.max(h, math.ceil(th) + 8 + 8 + 29 + (stacked and 20 or 0))
	c:SetSize(w, h)
	c.card:SetSize(w, h)
	c.never:SetSize(lw, 18)
	c.never.label:SetWidth(lw)
	c.never:ClearAllPoints()
	c.never:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -pad, stacked and 5 or 9)
	c.open:ClearAllPoints()
	c.open:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", left, stacked and 27 or 7)
	return w, h, stacked
end

-- a frame's rectangle in UIParent units (l, r, t, b) or nil when it has none
local function rectOf(f)
	if type(f) ~= "table" or type(f.GetLeft) ~= "function" then return nil end
	local l, r, t, b = N(call(f.GetLeft, f)), N(call(f.GetRight, f)), N(call(f.GetTop, f)), N(call(f.GetBottom, f))
	if not (l and r and t and b) then return nil end
	local fs, us = N(call(f.GetEffectiveScale, f)) or 1, N(call(UIParent.GetEffectiveScale, UIParent)) or 1
	local k = us > 0 and fs / us or 1
	return { l = l * k, r = r * k, t = t * k, b = b * k }
end

local function hits(x, y)
	return x.l < y.r and y.l < x.r and x.b < y.t and y.b < x.t
end

-- Puts the card beside the map, fully on screen and clear of the minimap cluster: right of the
-- map, else left of it, else below it; a spot over MinimapCluster is skipped (if every spot
-- would, the first that fits the screen is used). Returns false when none fits the screen.
function Mod.Place(c, map)
	local m = rectOf(map)
	if not m then return false end
	local screenW, screenH = N(UIParent:GetWidth()) or 0, N(UIParent:GetHeight()) or 0
	local cw, ch = Mod.Layout(c)
	local top = screenH > 0 and math.min(m.t, screenH) or m.t
	top = math.max(top, ch)
	local mini
	local mc = _G["MinimapCluster"]
	if type(mc) == "table" and type(mc.IsShown) == "function" and W.Plain(call(mc.IsShown, mc)) == true then mini = rectOf(mc) end
	local below = m.l
	if below + cw > screenW then below = screenW - cw end
	local spots = {
		{ ok = m.r + GAP + cw <= screenW, l = m.r + GAP, t = top, pt = "TOPLEFT", rel = "TOPRIGHT", x = GAP },
		{ ok = m.l - GAP - cw >= 0, l = m.l - GAP - cw, t = top, pt = "TOPRIGHT", rel = "TOPLEFT", x = -GAP },
		{ ok = m.b - GAP - ch >= 0 and below >= 0, l = below, t = m.b - GAP, pt = "TOPLEFT", rel = "BOTTOMLEFT", x = below - m.l, y = -GAP },
	}
	-- the Wuber window and the What's new card, when open: a spot clear of them is preferred (the card stays clickable)
	-- (the What's new card, when up, is the same: it sits in a high strata, so a card under it cannot be clicked)
	local others = {}
	for _, fr in ipairs({ UI.state and UI.state.win or false, _G["WuberNewsCard"] or false }) do
		if type(fr) == "table" and type(fr.IsShown) == "function" and W.Plain(call(fr.IsShown, fr)) == true then
			local r = rectOf(fr)
			if r then others[#others + 1] = { frame = fr, rect = r } end
		end
	end
	local function box(sp) return { l = sp.l, r = sp.l + cw, t = sp.t, b = sp.t - ch } end
	local function coveredBy(sp)
		for _, o in ipairs(others) do if hits(box(sp), o.rect) then return o end end
		return nil
	end
	local pick, firstFit, clearOfMini
	for _, sp in ipairs(spots) do
		if sp.ok then
			firstFit = firstFit or sp
			if not (mini and hits(box(sp), mini)) then
				clearOfMini = clearOfMini or sp
				if not coveredBy(sp) then pick = sp break end
			end
		end
	end
	pick = pick or clearOfMini or firstFit
	if not pick then return false end
	c:ClearAllPoints()
	c:SetPoint(pick.pt, map, pick.rel, pick.x, pick.y or (pick.t - m.t))
	c:SetFrameStrata(lowerStrata(S(map:GetFrameStrata()) or "HIGH"))
	-- no spot clear of them: draw the card above them, so every button on it can be clicked
	local strata, level
	for _, o in ipairs(others) do
		if hits(box(pick), o.rect) then
			local fr = o.frame
			local s = S(call(fr.GetFrameStrata, fr)) or "FULLSCREEN_DIALOG"
			local up = aboveStrata(s)
			-- the strata ABOVE theirs: the window is Toplevel, so a click inside it raises its level (not its strata)
			if not strata or strataRank(up) > strataRank(strata) then strata = up end
			level = math.max(level or 0, (N(call(fr.GetFrameLevel, fr)) or 1) + 20)
		end
	end
	if strata then
		c:SetFrameStrata(strata)
		c:SetFrameLevel(level)
	end
	return true
end

function Mod.Hide()
	if card and card:IsShown() then
		card.token = nil
		A.FadeOut(card, 0.2)
	end
end

function Mod.Open()
	local key = card and card.key
	Mod.Hide()
	if not key then return end
	if UI.Toggle and not (UI.state and UI.state.win and UI.state.win:IsShown()) then UI.Toggle(true) end
	UI.Show("confirm", key)
end

-- The card's words: the summon's price, the flight's gold and time, and what the summon really
-- costs once the flight money is saved (or that it saves gold, when the flight costs more).
function Mod.Message(d, info)
	local ab = info.about and "about " or ""
	local s = "Skip the bird: " .. d.short .. " summons to " .. d.dest .. " for " .. money(d.price) .. ". Flying is "
		.. ab .. money(info.cost) .. " and " .. ab .. duration(info.secs) .. ". "
	local diff = (N(d.price) or 0) - info.cost
	if diff > 0 then
		s = s .. money(d.price) .. " - " .. money(info.cost) .. " = really " .. ab .. money(diff)
	elseif diff == 0 then
		s = s .. "The summon costs the same as flying"
	else
		s = s .. "The summon saves " .. ab .. money(-diff) .. " of gold"
	end
	return s .. ", and " .. ab .. duration(info.back or info.secs) .. " back."
end

-- Shows the card for this open if everything allows it; returns true when shown.
function Mod.Show()
	if shownThisOpen or not W.db or W.db.birdTip == false then return false end
	-- the common rules for opening by itself (combat, a cinematic, just logged in): second return "wait"
	if not UI.MayOpen("bird") then return false, "wait" end
	-- only a ride still before the summon lands blocks it (arrived, paying, done, ended do not)
	local rv = KitMod.rideView()
	if rideActive(rv) and (rv.rank or 0) < KitMod.RIDE_RANK.arrived then return false end
	local map = mapFrame()
	if not map then return false end
	local d, info = Mod.Pick()
	if not d then return false end
	card = card or buildCard()
	placeTried = true
	local wait = N(UI.SummonWait(d)) or 30
	local sumText = wait < 60 and (math.floor(wait + 0.5) .. " sec") or ("about " .. duration(wait))
	local flySecs = N(info.secs) or 60
	local flyText = flySecs < 60 and "about 1 min" or ("about " .. duration(flySecs))
	card.text:SetText("Summon " .. sumText .. ". Fly " .. flyText .. ".")
	card.sub:SetText((S(d.short) or "") .. " · " .. (S(d.dest) or "") .. " · " .. money(d.price))
	card.tipBody = "A Wuber driver summons there faster than the flight. Click to book.\n\n" .. Mod.Message(d, info)
	if not Mod.Place(card, map) then return false end
	shownThisOpen = true
	card.key = d.key
	A.FadeIn(card, 0.2)
	local token = {}
	card.token = token
	-- no timed hide (the player reads at their own pace); a light check only so the card is never left
	-- on screen once the flight map is gone without TAXIMAP_CLOSED
	local function watch()
		if card.token ~= token then return end
		if not mapFrame() then Mod.Hide() return end
		W.After(CHECK, watch)
	end
	W.After(CHECK, watch)
	return true
end

-- /wuber why: nil while the card shows (or no rule hides it), else one line naming the first of
-- Mod.Show's rules that hides it; Mod.Pick's per-driver rules name the driver nearest to passing.
-- Read-only (it never builds, places or shows the card).
function Mod.Why()
	if card and card:IsShown() then return nil end
	if shownThisOpen then return "Skip the bird: already shown for this flight map." end
	if not W.db then return nil end
	if W.db.birdTip == false then return "Skip the bird: off in Settings (Riding, Flight offers)." end
	local _, gate = UI.MayOpen("bird")
	if gate == "combat" then return "Skip the bird: not in combat." end
	if gate == "cinematic" then return "Skip the bird: not during a cinematic." end
	if gate == "login" then return "Skip the bird: shows a few seconds after login." end
	local rv = KitMod.rideView()
	if rideActive(rv) and (rv.rank or 0) < KitMod.RIDE_RANK.arrived then return "Skip the bird: your ride is waiting for its summon." end
	if not mapFrame() then return "Skip the bird: no flight map is open." end
	if Mod.Pick() then
		-- until Mod.Show has tried to place the card (the 0.1 s after the map opens) nothing is known about room
		if not placeTried then return nil end
		return "Skip the bird: no room beside the flight map."
	end
	-- why no driver passed Mod.Pick: the longest known flight, else the first unknown one
	local open, unknown, longest, longestSecs, longestWait
	for _, d in ipairs(UI.Drivers() or {}) do
		if type(d) == "table" and d.state == "open" and d.key ~= myKey() then
			open = true
			local dest = S(d.dest)
			local cost = dest and type(W.FlightCost) == "function" and N((call(W.FlightCost, nil, dest))) or nil
			local secs
			if cost and type(W.FlightTime) == "function" then secs = N((call(W.FlightTime, nil, dest))) end
			if cost and not secs and type(W.TravelSaved) == "function" then secs = N((call(W.TravelSaved, dest))) end
			if cost and secs then
				local wait = UI.SummonWait(d)
				if not longestSecs or secs > longestSecs then
					longest, longestSecs, longestWait = dest, secs, wait
				elseif secs == longestSecs and wait < longestWait then
					longestWait = wait
				end
			elseif dest and not unknown then
				unknown = dest
			end
		end
	end
	if not open then return "Skip the bird: no driver is open." end
	if longest then
		local how = longestSecs < 60 and "under a minute" or ("about " .. duration(longestSecs))
		if longestSecs <= longestWait then
			return "Skip the bird: the flight to " .. longest .. " is " .. how .. ", shorter than a summon's wait."
		end
		return "Skip the bird: the flight to " .. longest .. " is " .. how .. ", so a summon gives under a minute back."
	end
	if unknown then return "Skip the bird: Wuber does not know the flight from here to " .. unknown .. " yet." end
	return nil
end

-- one try for this open of the flight map; held by a common rule (UI.MayOpen), it looks again each second while
-- that map stays open
local openToken = 0
local function tryShow(token)
	if token ~= openToken then return end
	W.Safe("bird", function()
		local _, why = Mod.Show()
		if why == "wait" and mapFrame() then W.After(CHECK, function() tryShow(token) end) end
	end)
end

local function mapOpened()
	shownThisOpen, placeTried = false, false
	openToken = openToken + 1
	local token = openToken
	W.After(0.1, function() tryShow(token) end)
end
W.On("TAXIMAP_OPENED", function()
	-- (the map's OnShow, see Core.Flights, may have opened it a moment ago: one open, not two)
	local at = W.FlightMapShownAt
	if type(at) == "number" and at > 0 and GetTime() - at < 1 then return end
	mapOpened()
end)
-- the real client showed the flight map without TAXIMAP_OPENED (recorder, run 1): Core.Flights tells us
W.Listen("FLIGHTMAP_SHOWN", mapOpened)
W.On("TAXIMAP_CLOSED", function()
	shownThisOpen, placeTried = false, false
	openToken = openToken + 1
	if card then
		card.token = nil
		card:Hide()
	end
end)
