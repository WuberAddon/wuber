-- Module: UI.Driver.Draw
-- Purpose: Drawing the console each refresh: status, slot, controls, ready list, filter, queue, crew
--   chips, community strip, the "Your business" list at the page's end, drawConsole/drawProvider.
-- API: D.RaidTonight, D.HERO_LOOK, D.SlotWords, D.FuelInfo, D.PaintFuel, D.ChipCount, D.WhisperWord
-- Internals: drawConsole, drawFilter, drawProvider, layChips, slotWords, crewLocks, drawDanger, drawBusiness
-- Uses: UI.Driver.State, UI.Driver.Build
-- Later: UI.Driver.Console (D.Refresh), UI.Driver.Raid (drawRaid, hideRaid), UI.Driver.Demand (drawLine, hideLine, List, D.DemandCard)
-- Events: listens Listen SETTINGS; fires -
-- Standalone: no
-- Test: tests/ui/driver/draw_test.lua
-- From: Driver.lua 1489-1979; Driver.lua 2266-2454 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Driver.Draw", { "UI.Driver.State", "UI.Driver.Build" })
local StateMod = W.Mod("UI.Driver.State")
local BuildMod = W.Mod("UI.Driver.Build")
local RaidMod = W.Mod("UI.Driver.Raid")
local DemandMod = W.Mod("UI.Driver.Demand")
local Char, Crew, Dest = StateMod.Char, StateMod.Crew, StateMod.Dest
local IsOpen, IsPaused, IsWarlock, List = StateMod.IsOpen, StateMod.IsPaused, StateMod.IsWarlock, StateMod.List
local MAX_ROWS, N, PAD, PILL_H = StateMod.MAX_ROWS, StateMod.N, StateMod.PAD, StateMod.PILL_H
local Price, Provider, QROW_GAP, QROW_H = StateMod.Price, StateMod.Provider, StateMod.QROW_GAP, StateMod.QROW_H
local Queue, ROW_GAP, ROW_H, RaidMode = StateMod.Queue, StateMod.ROW_GAP, StateMod.ROW_H, StateMod.RaidMode
local S, SLOT_W, TOP_FIXED, call = StateMod.S, StateMod.SLOT_W, StateMod.TOP_FIXED, StateMod.call
local dr, inCombat, money, now = StateMod.dr, StateMod.inCombat, StateMod.money, StateMod.now
local plural, safeScript, setShown, short = StateMod.plural, StateMod.safeScript, StateMod.setShown, StateMod.short
local crewChip, layStatus = BuildMod.crewChip, BuildMod.layStatus
local T = W.Theme
local A = T.Animate

local DR = W.Drive

local D = W.Driver

local function adv()
	return type(W.Advanced) ~= "function" or W.Advanced() == true
end

local function inRaid()
	if type(IsInRaid) ~= "function" then return false end
	local r = W.Plain(call(IsInRaid))
	return r == true or r == 1
end

---------------------------------------------------------------------------
-- Drawing the console
---------------------------------------------------------------------------

local STATUS = {
	open = { "Open", "glow" }, paused = { "Paused", "amber" }, closed = { "Closed", "off" }, combat = { "In combat", "red" },
	-- raid summons
	ropen = { "Running", "glow" }, rpaused = { "Paused", "amber" }, rclosed = { "Stopped", "off" },
}

-- raiders summoned "tonight": the last six hours (Drive_Log's raid count)
function D.RaidTonight()
	local t = N(call(time))
	local n = N(dr("RaidCount", t and (t - 6 * 3600) or nil))
	return n and math.max(0, math.floor(n)) or 0
end

-- (2.3) The fuel gauge's number, colour, tip and fill (0..1). The number is my own
-- Soul Shards when I'm a Warlock selling, else the summoners' total (a runner who isn't a
-- Warlock; raid summons). Violet above 2 x lowShards, amber at or below it, red at or below
-- lowShards, grey "?" when nobody's count is known.
local function crewLocks()
	local out = {}
	for _, m in ipairs(Crew()) do
		if type(m) == "table" and m.role == "lock" and not m.me and m.key ~= W.myKey then out[#out + 1] = m end
	end
	return out
end

local function shardList(list)
	local total, known, parts = 0, false, {}
	for _, m in ipairs(list) do
		local n = N(m.shards)
		if n and n >= 0 then
			total, known = total + n, true
			parts[#parts + 1] = short(m.name) .. " " .. math.floor(n)
		elseif m.app ~= false then
			parts[#parts + 1] = short(m.name) .. " ?"
		end
	end
	return known and math.floor(total) or nil, parts
end

function D.FuelInfo()
	local o = dr("opts")
	local low = N(type(o) == "table" and o.lowShards) or 3
	local n, tip
	local each = " Each summon uses one."
	if RaidMode() or not IsWarlock() then
		local list = RaidMode() and (D.RaidSummoners and D.RaidSummoners() or {}) or crewLocks()
		local parts
		n, parts = shardList(list)
		if n then
			tip = "Soul Shards: your summoners " .. n .. (#parts > 1 and (" (" .. table.concat(parts, ", ") .. ")") or "") .. "." .. each
		end
	else
		local mine = N(dr("Shards"))
		n = mine and mine >= 0 and math.floor(mine) or nil
		local crewN, parts = shardList(crewLocks())
		if n then
			tip = "Soul Shards: you " .. n .. (crewN and (" · crew " .. crewN .. " (" .. table.concat(parts, ", ") .. ")") or "") .. "." .. each
		end
	end
	if not n then return nil, "off", "Soul Shards: not known yet." .. each, 0 end
	local colour = (n <= low and "red") or (n <= 2 * low and "amber") or "accent"
	return n, colour, tip, math.min(1, n / 20)
end

function D.PaintFuel(g)
	if type(g) ~= "table" or not g.num then return end
	local n, colour = D.FuelInfo()
	-- (design 1 J) the count in words, white; red only when it warns; an unknown count shows nothing
	g:SetShards(n and plural(n, "shard") or "", colour == "red" and "red" or "white")
	g.colour = n and colour or "off"
end

local function drawStatus(v)
	local s = v.status
	D.PaintFuel(s.fuel)
	local key = inCombat() and "combat" or (IsOpen() and (IsPaused() and "paused" or "open") or "closed")
	local helper = D.Role() == "helper"
	if helper and key == "closed" then key = "open" end
	local raid = RaidMode()
	if raid and key ~= "combat" then key = "r" .. key end
	local st = STATUS[key]
	local pb = T.ShowPioneer(s, "pioneer", T.PioneerLook(W.myKey), 16, nil, true) -- mine, left of the dot
	if pb then pb:ClearAllPoints() pb:SetPoint("LEFT", s, "LEFT", 0, 0) end
	if (s.pioneerShift or 0) ~= (pb and 20 or 0) then
		s.pioneerShift = pb and 20 or 0
		s.dot:ClearAllPoints()
		s.dot:SetPoint("LEFT", s, "LEFT", 4 + s.pioneerShift, 0)
	end
	s.dot:SetVertexColor(T.RGB(st[2]))
	s.halo:SetVertexColor(T.RGB(st[2], 0.45))
	s.halo:SetShown(key ~= "closed" and key ~= "rclosed") -- hidden when closed, never an alpha change
	local c = Char()
	local cap = c and S(c.captain) or nil
	s.word:SetText(helper and ((cap and cap ~= "" and short(cap) or "Your captain") .. "'s crew") or st[1])
	s.word:SetTextColor(T.RGB((key == "closed" or key == "rclosed") and "muted" or "white"))
	-- (round 9) no "· " before the fare: the pill and its chevron set it apart (and the room is tight)
	if raid then
		if not helper then s.word:SetText(st[1]) end
		v.fare.text:SetText(T.Code("glow") .. "No charge|r")
		setShown(v.fare, not helper)
		s.gold:SetText(tostring(D.RaidTonight()))
		s.rides:SetText("summoned tonight")
		layStatus(v)
		return
	end
	-- 2+ stations: one price, each Warlock summons where they stand
	local nst = #D.Stations()
	v.fare.text:SetText(T.Code("gold") .. money(Price()) .. "|r to " .. (nst >= 2 and (nst .. " places") or Dest()))
	setShown(v.fare, not helper)
	local rides, copper = D.Today()
	s.gold:SetText(copper > 0 and money(copper) or "0g")
	s.rides:SetText("today (" .. rides .. ")")
	layStatus(v)
end

-- the hero card follows the plan: lit violet for a click, an amber or red rim while waiting
-- or for the portal, dimmer while idle ({ glow, glow alpha, rim, rim alpha, how lit })
local HERO = {
	go = { "accent", 0.5, "glow", 0.95, 1 }, wait = { "amber", 0.22, "amber", 0.6, 0.75 },
	alert = { "red", 0.4, "red", 0.85, 0.7 }, off = { "accent", 0.16, "glow", 0.3, 0.42 },
}
D.HERO_LOOK = HERO -- (the floating button's face reads the same table)

-- one sweep of light across the card (position only, 0.65 s)
local function sweep(hero)
	if T.FxLevel and T.FxLevel() == "off" then return end
	local t0 = now()
	local travel = SLOT_W - 90
	hero.shine:SetVertexColor(T.RGB("white"))
	hero.shine:Show()
	safeScript(hero, "OnUpdate", function(self)
		local p = (now() - t0) / 0.65
		if p >= 1 then
			self.shine:SetAlpha(0)
			self.shine:Hide()
			self:SetScript("OnUpdate", nil)
			return
		end
		self.shine:SetPoint("LEFT", self, "LEFT", travel * p, 0)
		self.shine:SetAlpha(0.25 * math.sin(math.pi * p))
	end)
end

-- the slot's own words show only while no big button is docked over it
local function slotWords(v, docked)
	local slot = v.slot
	setShown(slot.title, not docked)
	setShown(slot.sub, not docked)
	setShown(slot.bar, not docked)
end
D.SlotWords = slotWords

local function drawSlot(v)
	local plan = dr("Plan")
	plan = type(plan) == "table" and plan or {}
	local slot, hero = v.slot, v.hero
	slot.title:SetText(S(plan.title) or (IsOpen() and "Open - waiting for riders" or "Closed"))
	slot.sub:SetText(S(plan.here) or S(plan.sub) or "") -- (the slot is in the Drive tab)
	local pc = S(plan.color) or "off"
	local colour = ({ go = "gold", wait = "amber", alert = "red", off = "off", idle = "off" })[pc] or "accent"
	slot.barFill:SetColor(colour)
	local look = HERO[pc] or HERO.off
	-- the colours keep alpha 1; how strong each is, is the region's alpha
	hero.glow:SetColor(look[1])
	hero.glow:SetAlpha(look[2])
	hero.rim:SetColor(look[3])
	hero.rim:SetAlpha(look[4])
	hero.fill:Paint(look[5])
	local B = DR.Button
	slotWords(v, type(B) == "table" and call(B.Docked) == true and DR.button ~= nil and DR.button:IsShown())
	if colour == "off" then setShown(slot.bar, false) end -- S3: no line while idle or closed
	-- Skip in the card's top band (not secure: it may come and go in a fight)
	setShown(v.skip, adv() and type(dr("SkipTarget")) == "table")
	-- a new click is due: one sweep of light
	local due = plan.type ~= nil
	if due and not hero.wasDue and hero:IsVisible() then sweep(hero) end
	hero.wasDue = due
end

local function drawControls(v)
	local open, paused = IsOpen(), IsPaused()
	local helper = D.Role() == "helper"
	local raid = RaidMode()
	setShown(v.open, not helper)
	setShown(v.pause, not helper)
	setShown(v.advert, not helper and not raid)
	setShown(v.pick, not helper and raid)
	-- the Sell / Raid header: for the character that runs the service
	local runs = D.Role() == "driver" and (type(DR.SetMode) == "function" or raid)
	local bar = runs and (adv() or raid or inRaid())
	setShown(v.modeBar, bar)
	if bar and v.modeBar.value ~= (raid and "raid" or "sell") then v.modeBar:SetValue(raid and "raid" or "sell") end
	-- (design 2, P2) the switch is in the header zone, left of the window's buttons (D.PlaceModeBar, looked at on
	-- every draw: the fold button comes and goes): it takes 2 more than the buttons do. Only when its words do not
	-- fit there is it a row of its own under them (36).
	local hdr = 0
	-- (#23) in Simple a driver keeps the 2 the switch takes in Advanced (the switch itself is only hidden there), so the
	-- Drive tab, and the big summon button docked in its slot, do not move when the mode is switched in a fight.
	-- The one case that still moves: Advanced needing the row of its own (36, its words do not fit the header zone):
	-- a switch to Simple in a fight then moves the slot, and the button follows it when the fight ends.
	if bar then hdr = D.PlaceModeBar(v) and 2 or 36 elseif runs then hdr = 2 end
	-- (design 2, C) the status strip is full width: it starts under the window's buttons (UI.HEAD_ROW)
	local head = N(W.UI.HEAD_ROW) or 44
	if v.hdr ~= hdr then
		v.hdr = hdr
		v.up:ClearAllPoints()
		v.up:SetPoint("TOPLEFT", v, "TOPLEFT", 0, -(hdr + head))
		v.up:SetPoint("TOPRIGHT", v, "TOPRIGHT", 0, -(hdr + head))
	end
	local top = (helper and (TOP_FIXED - PILL_H - 12) or TOP_FIXED) + hdr + head
	if v.scrollTop ~= top then
		v.scrollTop = top
		v.scroll:ClearAllPoints()
		v.scroll:SetPoint("TOPLEFT", v, "TOPLEFT", 0, -top)
		v.scroll:SetPoint("BOTTOMRIGHT", v, "BOTTOMRIGHT", 0, 0)
	end
	if helper then return end
	if raid then
		v.open:SetLabel(open and "Stop" or "Start")
		v.open:SetStyle(open and "dark" or "primary")
		if open then v.open.label:SetTextColor(T.RGB("white")) end
		v.pause:SetLabel(paused and "Resume" or "Pause")
		v.pause:SetStyle(paused and "violet" or "dark")
		v.pause:SetActive(open)
		v.pause:SetAlpha(open and 1 or 0.5) -- (round 13, I24) dimmed while stopped
		local n = #List("Summoners")
		v.pick:SetLabel("Warlocks") -- (round 13, I17: whole in its pill; the chips below list them)
		v.pick:SetStyle(n > 0 and "dark" or "violet")
		return
	end
	v.open:SetLabel(open and "Close" or "Open")
	v.open:SetStyle(open and "dark" or "primary")
	if open then v.open.label:SetTextColor(T.RGB("white")) end
	v.pause:SetLabel(paused and "Resume" or "Pause")
	v.pause:SetStyle(paused and "violet" or "dark")
	v.pause:SetActive(open)
	D.PaintAdvert(v, open)
	-- (round 13, I24) closed: Pause and Advertise do nothing, so they look dimmed (alpha only)
	v.pause:SetAlpha(open and 1 or 0.5)
	v.advert:SetAlpha(open and 1 or 0.5)
end

-- (round 9) the first whisper word riders can use ("summon" when none is set)
function D.WhisperWord()
	local kw = (dr("opts") or {}).keywords
	return type(kw) == "table" and S(kw[1]) or (S(kw) or ""):match("%S+") or "summon"
end

-- (round 9) a summoner chip's count, the same words folded and unfolded: "10 shards" (red at 0),
-- "no Wuber" for a Warlock without the app (nobody sees their shards), else "".
-- D.ChipCount(m) -> words, colour
function D.ChipCount(m)
	local sh = N(m.shards)
	if m.role == "lock" and m.app == false then return "no Wuber", "muted" end
	-- (design 1) a shard count is not a price: white, never gold (red at 0)
	if m.role == "lock" and sh and sh >= 0 then return math.floor(sh) .. " shards", sh == 0 and "red" or "white" end
	return "", "white"
end

-- the Ready card: DR.Readiness() lines that are not ok, each with its fix pill. (Round 9, S7) In
-- raid mode it is "Ready to summon?"; while raid summons run it shows only "You need lead or
-- assist" (DR.CanRunRaid false), else it hides.
local function drawReady(v, y)
	local card = v.ready
	local running = RaidMode() and IsOpen()
	card.title:SetText(RaidMode() and "Ready to summon?" or "Ready to drive?")
	local list = not running and dr("Readiness") or nil
	local bad = {}
	if type(list) == "table" then
		for _, l in ipairs(list) do
			if type(l) == "table" and l.ok == false then bad[#bad + 1] = l end
		end
	end
	-- lines only the UI knows to add (the engine's own come first; same words are not repeated)
	local function addBad(text, fix)
		for _, l in ipairs(bad) do if (S(l.text) or ""):lower() == text:lower() then return end end
		bad[#bad + 1] = { ok = false, text = text, fix = fix }
	end
	local runner = D.Role() == "driver"
	local raid = RaidMode()
	if runner and raid then
		local can, why = dr("CanRunRaid")
		if can == false then addBad(S(why) or "You need lead or assist", nil) end
		-- (round 9, S7/S10) one way to pick: the Warlocks pill beside Start (no second button here)
		if not running and #List("Summoners") == 0 then addBad("Pick who summons: tap Warlocks", nil) end
	elseif runner and not IsWarlock() and #List("Summoners") == 0 then
		-- a runner who isn't a Warlock needs a Warlock to cast
		addBad("Choose who summons", { label = "Choose", run = function() D.ShowScreen("wizard", 3) end, tip = "Pick the Warlock (a friend or your own) who casts the summons." })
	end
	local c = Char()
	if c and c.wizard ~= true and runner and not raid then
		local seen = false
		for _, l in ipairs(bad) do
			local f = D.Fix(l.fix)
			if f and f.label == "Set up my crew" then seen = true end
		end
		if not seen then
			bad[#bad + 1] = { ok = false, text = "Your crew isn't set up yet", fix = { label = "Set up my crew", run = function() D.ShowScreen("wizard") end } }
		end
	end
	if #bad == 0 then
		card:Hide()
		return y
	end
	local ly = 36
	for i, l in ipairs(bad) do
		local line = card.lines[i]
		if not line then
			line = CreateFrame("Frame", nil, card)
			line:SetSize(SLOT_W - 28, 30)
			line.icon = T.Icon(line, "close", 11, "red", "OVERLAY")
			line.icon:SetPoint("LEFT", line, "LEFT", 0, 0)
			line.text = T.Text(line, "caption", "white", "LEFT", "medium")
			line.text:SetPoint("LEFT", line, "LEFT", 18, 0)
			line.text:SetPoint("RIGHT", line, "RIGHT", -112, 0)
			T.Lines(line.text, 2)
			line.fix = T.Pill(line, "Fix", "primary", 104, 26)
			line.fix:SetPoint("RIGHT", line, "RIGHT", 0, 0)
			safeScript(line.fix, "OnClick", function(self)
				local fix = self.fixData
				if type(fix) == "table" and type(fix.run) == "function" then
					local ok, err = pcall(fix.run)
					if not ok then W.Error("ready fix", err) end
				end
				D.Refresh()
			end)
			T.Tip(line.fix, function(self) return S(self.fixData and self.fixData.label) or "Fix" end,
				function(self) return S(self.fixData and self.fixData.tip) or "Puts this right in one click." end)
			line:EnableMouse(true)
			T.Tip(line, function() return RaidMode() and "Ready to summon" or "Ready to drive" end, function(self) return self.tipText end)
			card.lines[i] = line
		end
		line.tipText = S(l.text) or ""
		line.text:SetText(S(l.text) or "")
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -ly)
		local fix = D.Fix(l.fix)
		-- (round 9) a line with no Fix button gets its room for the words
		-- (2.4 fix round, HUNT-134) the Fix pill is as wide as its label needs (never under 104): "Set up my crew" was cut
		local fixW = 104
		if fix then
			local lw = T.MeasureText(S(fix.label) or "Fix", "sub", "medium")
			fixW = math.max(104, math.ceil(lw * 1.06) + 26 + 4)
		end
		line.fix:SetWidth(fixW)
		line.text:SetPoint("RIGHT", line, "RIGHT", fix and -(fixW + 8) or -4, 0)
		T.Fit(line.text)
		line.fix.fixData = fix
		if fix then
			line.fix:SetLabel(fix.label)
			line.fix:Show()
		else
			line.fix:Hide()
		end
		line:Show()
		ly = ly + 32
	end
	for i = #bad + 1, #card.lines do card.lines[i]:Hide() end
	card:SetHeight(ly + 8)
	card:ClearAllPoints()
	card:SetPoint("TOPLEFT", v.scroll.content, "TOPLEFT", PAD, -y)
	card:Show()
	return y + ly + 8 + 12
end

-- (2.3) "PvP nearby · riders are warned": a chip while Drive.Danger's level is 1 or
-- 2 (made the first time it shows; no setting hides it)
local function drawDanger(v, y)
	local level, ago = dr("DangerLevel")
	level = N(level) or 0
	if level < 1 then
		if v.pvp then v.pvp:Hide() end
		return y
	end
	if not v.pvp then
		v.pvp = T.Chip(v.scroll.content, "", "amber")
		v.pvp:EnableMouse(true)
		T.Tip(v.pvp, "PvP nearby", function(self)
			local mins = self.ago and math.max(1, math.floor(self.ago / 60 + 0.5))
			if self.level >= 2 then
				return "Your crew fought enemy players" .. (mins and (" " .. mins .. " min ago") or " a few minutes ago")
					.. ". Riders booking you see a warning that they may land in a fight. It clears after 5 quiet minutes."
					.. " Wuber only sees enemy players whose nameplates show."
			end
			return "An enemy player who can attack you showed near your summon spot."
				.. " Riders booking you see a warning. Wuber can't see players without nameplates, and never stops a booking for it."
		end)
	end
	v.pvp.level, v.pvp.ago = level, N(ago)
	v.pvp:SetChip("PvP nearby · riders are warned", level >= 2 and "red" or "amber")
	v.pvp:ClearAllPoints()
	v.pvp:SetPoint("TOPLEFT", v.scroll.content, "TOPLEFT", PAD, -y)
	v.pvp:Show()
	return y + 20 + 10
end

-- 2+ stations: filter chips over the queue, "All · Undercity · Orgrimmar"
local function filterChip(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(60, 24)
	b:RegisterForClicks("LeftButtonUp")
	b.fill = T.PillFill(b, "card", 24, "BACKGROUND", 0)
	b.dot = T.Circle(b, 6, "glow", "ARTWORK")
	b.dot:SetPoint("LEFT", b, "LEFT", 10, 0)
	b.label = T.Text(b, "caption", "muted", "LEFT", "medium")
	b.label:SetPoint("LEFT", b, "LEFT", 21, 0)
	T.Press(b, { fill = b.fill })
	safeScript(b, "OnClick", function(self)
		local ui2 = D.ui and D.ui.console
		if ui2 then ui2.stationFilter = self.place end
		D.Refresh(true)
	end)
	T.Tip(b, function(self) return self.place or "All places" end, function(self)
		if not self.place then return "Show the riders for every place your crew summons to." end
		return "Show only riders summoned at " .. self.place .. (self.ready and "." or " (not enough people there to click the portal yet).")
	end)
	return b
end

local function drawFilter(v, y, stations)
	v.fchips = v.fchips or {}
	if #stations < 2 then
		for _, b in ipairs(v.fchips) do b:Hide() end
		v.stationFilter = nil
		return y
	end
	local items = { { label = "All" } }
	local seen = false
	for _, st in ipairs(stations) do
		items[#items + 1] = { label = W.Clean(S(st.place), 16), place = S(st.place), ready = D.StationReady(st), off = st.open == false }
		if S(st.place) == v.stationFilter then seen = true end
	end
	if not seen then v.stationFilter = nil end
	local x, c = PAD, v.scroll.content
	for i, it in ipairs(items) do
		local b = v.fchips[i]
		if not b then
			b = filterChip(c)
			v.fchips[i] = b
		end
		b.place, b.ready = it.place, it.ready
		local on = v.stationFilter == it.place
		b.label:SetText(it.label)
		b.label:SetTextColor(T.RGB(on and "ink" or (it.off and "off" or "white")))
		b.fill:SetColor(on and "gold" or "card")
		setShown(b.dot, it.place ~= nil)
		b.dot:SetVertexColor(T.RGB(it.off and "off" or (it.ready and "glow" or "amber")))
		b.label:ClearAllPoints()
		b.label:SetPoint("LEFT", b, "LEFT", it.place and 21 or 12, 0)
		local wdt = math.floor(T.TextWidth(b.label, it.label) + (it.place and 33 or 24))
		b:SetWidth(wdt)
		if x + wdt > PAD + SLOT_W then
			x = PAD
			y = y + 30
		end
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", c, "TOPLEFT", x, -y)
		b:Show()
		x = x + wdt + 6
	end
	for i = #items + 1, #v.fchips do v.fchips[i]:Hide() end
	return y + 32
end

-- (r18) the riders, their place filter and the empty state are always the left column's, folded or
-- unfolded, right under the buttons; the side pane has the crew, today's takings and the best hours
-- (D.DrawConsoleSide), so each rider is still listed once

local function drawQueue(v, y, t)
	local c = v.scroll.content
	local all = Queue()
	local helper = D.Role() == "helper"
	v.qhead:ClearAllPoints()
	v.qhead:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -y)
	v.qhead:SetText("Riders")
	v.qhead:Show()
	v.qcount:Show()
	local waiting, asking = 0, 0
	for _, x in ipairs(all) do
		if x.state == "lead" then asking = asking + 1
		elseif x.state ~= "paid" and x.state ~= "done" then waiting = waiting + 1 end
	end
	v.qcount:SetText(#all == 0 and "" or (waiting > 0 and (waiting .. " in progress") or (asking > 0 and plural(asking, "asking", "asking") or "")))
	y = y + 24
	local stations = D.Stations()
	D.multiStation = #stations >= 2
	y = drawFilter(v, y, stations)
	local list = all
	if v.stationFilter then
		list = {}
		for _, x in ipairs(all) do if S(x.station) == v.stationFilter then list[#list + 1] = x end end
	end
	if #list == 0 then
		for _, r in ipairs(v.rows) do r:Hide() r.c = nil end
		v.more:Hide()
		v.coach:Hide()
		v.empty:ClearAllPoints()
		v.empty:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
		local open = IsOpen() or helper
		if #all > 0 then
			v.empty.text:SetText("Nobody at " .. tostring(v.stationFilter) .. " right now")
			v.empty.sub:SetText("Tap All to see every rider")
		elseif not open then
			v.empty.text:SetText("You're closed")
			v.empty.sub:SetText("Riders who ask show up here") -- (round 9: the card above says how to open)
		elseif IsPaused() then
			v.empty.text:SetText("Paused")
			v.empty.sub:SetText("No new invites until you resume")
		else
			v.empty.text:SetText("Waiting for riders")
			v.empty.sub:SetText("Whisper word: " .. D.WhisperWord() .. " · or the Wuber app")
		end
		v.empty.icon:SetVertexColor(T.RGB(open and "glow" or "off"))
		if open and not IsPaused() then
			if not v.empty.pulse.running then v.empty.pulse:Start() end
			if not v.empty.spinning then
				v.empty.spinning = A.Spin(v.empty.icon, 6) -- (20 Nov hotfix, the author: too fast) one slow turn every 6 s
			elseif not v.empty.spinOn then
				v.empty.spinning:Start()
			end
			v.empty.spinOn = true
			v.empty.icon:Show()
		else
			if v.empty.pulse.running then v.empty.pulse:Stop() end
			if v.empty.spinning and v.empty.spinOn then v.empty.spinning:Stop() end
			v.empty.spinOn = false
		end
		v.empty:Show()
		return y + 64 + 14
	end
	v.empty:Hide()
	if v.empty.pulse.running then v.empty.pulse:Stop() end
	-- the one-time coach tip: hold a name for options
	local db = W.db
	if db and not db.holdTip then
		v.coach:ClearAllPoints()
		v.coach:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -y)
		v.coach:Show()
		y = y + 18
		v.coachShown = (v.coachShown or 0) + 1
		if v.coachShown > 40 then db.holdTip = true end
	else
		v.coach:Hide()
	end
	-- (decisions I, FAB-10) a row for every listed rider: rows past the first MAX_ROWS are made here, on demand
	-- (plain Buttons, nothing secure); the page's own scroll reaches them. "+N more" stays for a row that cannot be made.
	local n = #list
	for i = #v.rows + 1, n do
		local okMake, row = pcall(D.Row, c, SLOT_W)
		if not okMake or not row then n = i - 1 break end
		row:SetHeight(QROW_H)
		v.rows[i] = row
	end
	for i = 1, math.max(MAX_ROWS, #v.rows) do
		local r = v.rows[i]
		if i <= n then
			D.PaintRow(r, list[i], t)
			-- (2.3.2, S6; r19 tour 43: or the PvP warning) with the demand line above, a row that would straddle the bottom of the list (cut in
			-- half by the tab bar) starts below it instead: the fade says there is more, a scroll brings it in
			local view = N(v.scroll:GetHeight()) or 0
			local card = (v.demand and v.demand:IsShown()) or (v.pvp and v.pvp:IsShown())
			local rh = N(r:GetHeight()) or QROW_H -- (design 3) a row with a third line of chips is taller
			if i > 1 and card and view > 0 and y < view - 2 and y + rh > view - 2 then
				y = view
			end
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
			y = y + rh + QROW_GAP
		else
			r:Hide()
			r.c = nil
		end
	end
	if #list > n then
		v.more:ClearAllPoints()
		v.more:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
		v.more:SetText("+" .. (#list - n) .. " more")
		v.more:Show()
		y = y + 20
	else
		v.more:Hide()
	end
	return y + 8
end

-- a row of crew chips from y (wrapping); returns the y under them.
local function layChips(pool, parent, list, y, turn)
	local x, rowY = PAD, y
	for i, m in ipairs(list) do
		local b = pool[i]
		if not b then
			b = crewChip(parent)
			pool[i] = b
		end
		b.m = m
		b.turn = turn ~= nil and m.key == turn
		b.glyph:SetTexture(T.MEDIA .. (m.role == "lock" and "summon" or "ride"))
		local silent = m.silent == true
		b.glyph:SetVertexColor(T.RGB(silent and "off" or (m.role == "lock" and "glow" or "gold")))
		local nm = m.key == W.myKey and "You" or short(m.name)
		b.name:SetText(nm)
		b.name:SetTextColor(T.RGB(silent and "off" or "white"))
		-- (round 9, S7) "You · 10 shards", never "You10"; "· no Wuber" (D.ChipCount)
		local words, colour = D.ChipCount(m)
		b.count:SetText(words ~= "" and ("· " .. words) or "")
		b.count:SetTextColor(T.RGB(colour))
		setShown(b.star, b.turn)
		local w = 10 + 14 + 6 + T.TextWidth(b.name, nm) + 5 + T.TextWidth(b.count, b.count.wuberText) + (b.turn and 24 or 12)
		w = math.floor(math.max(56, w))
		b:SetWidth(w)
		if x + w > PAD + SLOT_W then
			x = PAD
			rowY = rowY + 36
		end
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -rowY)
		b:Show()
		x = x + w + 6
	end
	for i = #list + 1, #pool do pool[i]:Hide() end
	return rowY + 36
end

local function drawCrew(v, y)
	local c = v.scroll.content
	local crew = {}
	for _, m in ipairs(Crew()) do
		if type(m) == "table" and (m.here ~= false) and not m.me and m.key ~= W.myKey then crew[#crew + 1] = m end
	end
	local _, turn = dr("MayCast")
	if #crew == 0 then
		v.crewHead:Hide()
		v.shards:Hide()
		for _, b in ipairs(v.chips) do b:Hide() end
		return y
	end
	v.crewHead:ClearAllPoints()
	v.crewHead:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 4, -y)
	v.crewHead:Show()
	v.shards:ClearAllPoints()
	v.shards:SetPoint("TOPRIGHT", c, "TOPRIGHT", -(PAD + 4), -y) -- (2.3.2, C8) it had no anchor and never showed
	-- me first, then the crew
	local me = { name = W.Me and W.Me() or "Me", key = W.myKey, role = IsWarlock() and "lock" or "helper", shards = dr("Shards"), app = true }
	table.insert(crew, 1, me)
	local total = D.CrewShards(crew) -- (round 13, I10) the chips' own counts added up
	v.shards:SetText(total and (plural(total, "shard") .. " in the team") or "")
	v.shards:Show()
	y = y + 24
	return layChips(v.chips, c, crew, y, turn) + 8
end

local function hideSell(v)
	for _, f in ipairs({ v.qhead, v.qcount, v.empty, v.coach, v.crewHead, v.shards }) do f:Hide() end
	if v.empty.pulse.running then v.empty.pulse:Stop() end
	for _, b in ipairs(v.chips) do b:Hide() end
	for _, b in ipairs(v.fchips or {}) do b:Hide() end
	if v.comm then v.comm:Hide() end
	if v.commHint then v.commHint:Hide() end
	if v.pvp then v.pvp:Hide() end
	if DemandMod.hideLine then DemandMod.hideLine(v) end
	if v.wanted then v.wanted:Hide() end
	D.multiStation = false
end

-- the Wuber community card at the foot of the scroll (a Join card when invited, else nothing)
local function drawCommunity(v, y)
	local avail = type(W.CommunityAvailable) == "function" and call(W.CommunityAvailable) == true
	local member = avail and type(W.CommunityMember) == "function" and call(W.CommunityMember) == true
	local clubId = (avail and not member and type(W.CommunityInvite) == "function") and call(W.CommunityInvite) or nil
	local card = v.comm
	-- not in the community yet and no invitation: one quiet line with a tip
	if not v.commHint then
		local h = CreateFrame("Frame", nil, v.scroll.content)
		h:SetSize(SLOT_W, 20)
		h.text = T.Text(h, "caption", "muted", "CENTER", "regular")
		h.text:SetAllPoints(h)
		h.text:SetText("Tip: join the Wuber community for more visibility")
		h:EnableMouse(true)
		T.Tip(h, "Wuber community", "The Wuber community's member list (Guild & Communities, J) helps riders on other realm copies find you. "
			.. "Ask the founder's team for an invitation. Wuber adds no channel and nothing shows in your chat.")
		v.commHint = h
	end
	-- (AUD-182) the tip talks of the founder's team: off the founder ruleset it is hidden
	local hinted = adv() and avail and not member and clubId == nil and call(W.OnFounderRuleset) == true
	setShown(v.commHint, hinted)
	if hinted then
		v.commHint:ClearAllPoints()
		v.commHint:SetPoint("TOPLEFT", v.scroll.content, "TOPLEFT", PAD, -(y + 2))
		y = y + 26
	end
	if clubId == nil then
		if card then card:Hide() end
		return y
	end
	if not card then
		card = T.Card(v.scroll.content, SLOT_W, 70, { colour = "card", radius = 14, shadow = false, border = "goldDeep" })
		local crown = T.Icon(card, "crown", 20, "gold", "OVERLAY")
		crown:SetPoint("LEFT", card, "LEFT", 14, 0)
		card.title = T.Text(card, "body", "white", "LEFT", "bold")
		card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 44, -10)
		card.title:SetPoint("RIGHT", card, "RIGHT", -90, 0)
		card.title:SetText("Join the Wuber community")
		card.text = T.Text(card, "caption", "muted", "LEFT", "regular")
		card.text:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -3)
		card.text:SetPoint("RIGHT", card, "RIGHT", -90, 0)
		T.Lines(card.text, 2) -- (r47 AUD-163) wraps to a second line before it is cut
		card.join = T.Pill(card, "Join", "primary", 70, 30)
		card.join:SetPoint("RIGHT", card, "RIGHT", -12, 0)
		safeScript(card.join, "OnClick", function()
			-- a hardware click on Join: the only place AcceptInvitation is called
			local fine = type(W.CommunityAccept) == "function" and call(W.CommunityAccept, card.clubId) == true
			card.failed = not fine
			D.Refresh()
		end)
		T.Tip(card.join, "Join", "Accepts the invitation to the Wuber community. Its member list helps riders find you across realms.")
		card:EnableMouse(true)
		T.Tip(card, "Wuber community", "The community's member list helps riders on other realm copies find you (Guild & Communities, J). No channel, nothing in your chat.")
		v.comm = card
	end
	if card.clubId ~= clubId then card.failed = nil end
	card.clubId = clubId
	setShown(card.join, not card.failed)
	card.text:SetText(card.failed and "Open Guild & Communities (J) to accept" or "Its member list helps riders find you across realms.")
	card:ClearAllPoints()
	card:SetPoint("TOPLEFT", v.scroll.content, "TOPLEFT", PAD, -y)
	card:Show()
	return y + 70 + 10
end

-- (Group Finder, B1) with the setting on: one card, the driver's status in the Group Finder, "List me" (a sheet with the steps and
-- the note) and "Remove my listing" (his click calls GF.Delist). Built the first time it is wanted: with the setting off nothing
-- is built, nothing is drawn and no C_LFGList call is made. Its words are W.GroupFinder.DRAFT_WORDS (drafts).
local GF_PAD, GF_PILL_H = 14, 36
local function drawGroupFinder(v, y)
	local GF = W.GroupFinder
	local card = v.gf
	if type(GF) ~= "table" or not GF.On() then
		if card then card:Hide() end
		return y
	end
	local WD = GF.DRAFT_WORDS
	if not card then
		local w = SLOT_W - 2 * GF_PAD
		card = T.Card(v.scroll.content, SLOT_W, 100, { colour = "card", radius = 14, shadow = false })
		card.status = T.Para(card, "body", "white", w, "medium")
		card.status:SetPoint("TOPLEFT", card, "TOPLEFT", GF_PAD, -GF_PAD)
		card.list = T.Pill(card, WD.listButton, "dark", w, GF_PILL_H)
		card.list.fill:SetColor("raised")
		card.list:HookScript("OnLeave", function(self) self.fill:SetColor("raised") end)
		safeScript(card.list, "OnClick", function() D.ShowSheet("gflist") end)
		T.Tip(card.list, WD.listButton, WD.steps)
		card.remove = T.Pill(card, WD.removeButton, "dark", w, GF_PILL_H)
		card.remove.fill:SetColor("raised")
		card.remove:HookScript("OnLeave", function(self) self.fill:SetColor("raised") end)
		-- the driver's own click: the only place (besides the offline clicks) the listing is removed
		safeScript(card.remove, "OnClick", function()
			if type(GF.Delist) == "function" then GF.Delist() end
			D.Refresh(true)
		end)
		T.Tip(card.remove, WD.removeButton, WD.removeButton)
		v.gf = card
	end
	local mine = GF.MyListing() == true
	local still = GF.StillListed() == true
	local text = still and WD.stillListed or (mine and WD.listed or WD.notListed)
	local h = card.status:SetPara(text)
	local yy = GF_PAD + h + 10
	card.list:ClearAllPoints()
	card.remove:ClearAllPoints()
	setShown(card.list, not mine)
	setShown(card.remove, mine)
	local btn = mine and card.remove or card.list
	btn:SetPoint("TOPLEFT", card, "TOPLEFT", GF_PAD, -yy)
	yy = yy + GF_PILL_H + GF_PAD
	card:SetHeight(yy)
	card:ClearAllPoints()
	card:SetPoint("TOPLEFT", v.scroll.content, "TOPLEFT", PAD, -y)
	card:Show()
	return y + yy + 8
end

-- (design round 2, item 11) "Your business" at the end of the page, after the riders: the quiet heading, then the
-- one card of rows (built by UI.Driver.Build). "Blocked (2)" in the row's words; a helper has no Messages or Blocked.
local BUSINESS = { above = 16, head = 13, foot = 12 }
local function drawBusiness(v, y)
	local g, links = v.business, v.links
	local n = 0
	local bl = dr("BlockedList")
	if type(bl) == "table" then n = #bl end
	local blocked = links.blocked
	blocked.count = n
	blocked.badge:SetText(n > 99 and "99" or tostring(n))
	blocked:SetLabel(n > 0 and ("Blocked (" .. n .. ")") or "Blocked")
	local isAdv = adv()
	local helper = D.Role() == "helper"
	local inCrew = helper or (type(D.CrewCount) == "function" and (N(D.CrewCount()) or 0) >= 1)
	local showCrew = isAdv or inCrew
	local showMessages = isAdv and not helper
	local showBlocked = not helper and (isAdv or n > 0)
	local showCustomers = isAdv
	local key = (showCrew and "1" or "0") .. (showMessages and "1" or "0") .. (showBlocked and "1" or "0") .. (showCustomers and "1" or "0")
	if v.linksFor ~= key then
		v.linksFor = key
		links.crew:SetShown(showCrew)
		links.messages:SetShown(showMessages)
		links.blocked:SetShown(showBlocked)
		links.earnings:SetShown(true)
		links.customers:SetShown(showCustomers)
	end
	-- the page scrolls: what comes next simply follows, and the view's bottom edge may cut a row (the fade says more)
	local lead = BUSINESS.head + (N(v.businessHead.gap) or 8)
	local top = y + BUSINESS.above
	y = top + lead
	g:ClearAllPoints()
	g:SetPoint("TOPLEFT", v.scroll.content, "TOPLEFT", PAD, -y)
	return y + (N(g.height) or 0)
end

local function drawConsole(v)
	local t = now()
	drawStatus(v)
	drawSlot(v)
	drawControls(v)
	local y = 4
	y = drawGroupFinder(v, y) -- (Group Finder, B1) nothing at all with the setting off
	y = drawReady(v, y)
	if RaidMode() then
		hideSell(v)
		y = RaidMod.drawRaid(v, y, t)
	else
		RaidMod.hideRaid(v)
		y = drawDanger(v, y)
		-- (2.3; r18) unfolded: the riders stay on the left under the buttons; the crew, today's takings
		-- and the best hours are in the side pane
		local wide = D.Wide("console")
		-- (round 13, I9) what riders want: folded, a line above the riders; unfolded, a card at the top of the side pane
		if wide then
			if DemandMod.hideLine then DemandMod.hideLine(v) end
		else
			if v.wanted then v.wanted:Hide() end
			if adv() then
				if DemandMod.drawLine then y = DemandMod.drawLine(v, y) end
			elseif DemandMod.hideLine then
				DemandMod.hideLine(v)
			end
		end
		y = drawQueue(v, y, t)
		if wide then
			v.crewHead:Hide()
			v.shards:Hide()
			for _, b in ipairs(v.chips) do b:Hide() end
			if D.DrawConsoleSide then call(D.DrawConsoleSide, v, t) end
		else
			y = drawCrew(v, y)
		end
		y = drawCommunity(v, y)
	end
	y = drawBusiness(v, y)
	v.scroll:SetContentHeight(y + BUSINESS.foot)
end

local function drawProvider(v)
	-- (never the old addon's own name on screen: "your old summoning addon")
	if dr("Lock") == "rr" then
		v.title:SetText("Your old addon is driving")
		v.sub:SetText("Your old addon answers Wuber requests until you switch it off.")
	else
		local name = Provider() or "another addon"
		v.title:SetText("Driving with " .. name)
		v.sub:SetText(name .. " answers your Wuber requests. Use its window to drive.")
	end
	local top = v.top
	-- the retire card (the old addon, once its data is copied in): UI_Drive.lua
	local retire = D.retire
	if not retire and type(D.screens.retire) == "function" then
		local ok, card = pcall(D.screens.retire, v)
		if ok and type(card) == "table" then
			retire = card
			D.retire = card
		end
	end
	if retire then
		local shown = false
		if type(retire.update) == "function" then shown = call(retire.update) == true end
		if shown then
			retire:ClearAllPoints()
			retire:SetPoint("TOPLEFT", v, "TOPLEFT", PAD, -top)
			top = top + (N(retire:GetHeight()) or 150) + 14
		end
	end
	v.head:ClearAllPoints()
	v.head:SetPoint("TOPLEFT", v, "TOPLEFT", PAD + 4, -top)
	top = top + 24
	local list = {}
	if type(W.incoming) == "table" then
		for _, r in pairs(W.incoming) do
			if type(r) == "table" and r.id then list[#list + 1] = r end
		end
	end
	table.sort(list, function(a, b) return (N(a.at) or 0) > (N(b.at) or 0) end)
	local n = math.min(#list, 6)
	-- (only as many cards as fit under the retire card and the heading: the rest stay out of the list, never below the window)
	local room = N(v:GetHeight()) or 0
	if room > 0 then n = math.min(n, math.max(1, math.floor((room - top) / (ROW_H + ROW_GAP)))) end
	for i = 1, n do
		local r = list[i]
		local card = v.cards[i]
		if not card then
			card = CreateFrame("Frame", nil, v)
			card:SetSize(SLOT_W, ROW_H)
			card.bg = T.Rounded(card, "card", 12, "BACKGROUND", 0)
			card.name = T.Text(card, "body", "white", "LEFT", "bold")
			card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -7)
			card.name:SetWidth(200)
			card.info = T.Text(card, "caption", "muted", "LEFT", "regular")
			card.info:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -24)
			card.info:SetWidth(220)
			card.state = T.Text(card, "caption", "glow", "RIGHT", "bold")
			card.state:SetPoint("RIGHT", card, "RIGHT", -14, 0)
			card.state:SetWidth(90)
			v.cards[i] = card
		end
		card.name:SetText(short(r.buyer))
		card.info:SetText("to " .. (S(r.dest) or "?") .. "  ·  " .. money(r.price))
		local st = S(r.stage) or S(r.state) or ""
		card.state:SetText((st:gsub("^%l", string.upper)))
		card:ClearAllPoints()
		card:SetPoint("TOPLEFT", v, "TOPLEFT", PAD, -top)
		card:Show()
		top = top + ROW_H + ROW_GAP
	end
	for i = n + 1, #v.cards do v.cards[i]:Hide() end
	v.empty:ClearAllPoints()
	v.empty:SetPoint("TOPLEFT", v, "TOPLEFT", PAD, -(top + 12))
	setShown(v.empty, #list == 0)
end

W.Listen("SETTINGS", function(key)
	if (key == "advanced" or key == "groupFinder") and type(D.Refresh) == "function" then D.Refresh(true) end
end)
-- (Group Finder, B1) the driver's listing changed (a post, a removal, a search)
W.Listen("GROUPFINDER", function()
	if type(D.Refresh) == "function" then D.Refresh(true) end
end)

-- for other modules (REFACTOR-MAP section 2): set at the end, when every local holds its final value
Mod.drawConsole = drawConsole
Mod.drawFilter = drawFilter
Mod.drawProvider = drawProvider
Mod.layChips = layChips
Mod.slotWords = slotWords
