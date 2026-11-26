-- Module: UI.Driver.Build
-- Purpose: Building the console: status strip, the big-button slot, controls, middle list, crew chips,
--   the "Your business" list (v.business, v.links: the five pages as rows at the end of the page), mode bar,
--   welcome and provider views.
-- API: D.SetMode, D.CalmSegmented, D.FuelGauge, D.PlaceModeBar
-- Internals: buildConsole, buildProvider, buildWelcome, crewChip, layStatus, paintWelcome
-- Uses: UI.Driver.State, UI.Driver.Rows
-- Later: UI.Driver.Console (D.Refresh, when the header's buttons change beside the switch)
-- Events: (none)
-- Standalone: no
-- Test: tests/ui/driver/build_test.lua
-- From: Driver.lua 856-1488 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Driver.Build", { "UI.Driver.State", "UI.Driver.Rows" })

local StateMod = W.Mod("UI.Driver.State")
local RowsMod = W.Mod("UI.Driver.Rows")
local Char, HERO_H, IsOpen = StateMod.Char, StateMod.HERO_H, StateMod.IsOpen
local IsPaused, IsWarlock, MAX_ROWS, N = StateMod.IsPaused, StateMod.IsWarlock, StateMod.MAX_ROWS, StateMod.N
local PAD, PILL_H, QROW_H, RaidMode = StateMod.PAD, StateMod.PILL_H, StateMod.QROW_H, StateMod.RaidMode
local S, SLOT_H, SLOT_W, STRIP_H = StateMod.S, StateMod.SLOT_H, StateMod.SLOT_W, StateMod.STRIP_H
local TOP_FIXED, advertOn, call, dr = StateMod.TOP_FIXED, StateMod.advertOn, StateMod.call, StateMod.dr
local inCombat, plural, safeScript, short = StateMod.inCombat, StateMod.plural, StateMod.safeScript, StateMod.short
local toast = StateMod.toast
local textW = RowsMod.textW
local T = W.Theme
local noGlow = T.NoGlow -- (design round 1) the shared no-op glow, Theme.Widgets
local A = T.Animate
local Try = T.Try

local DR = W.Drive

local D = W.Driver
local GOLD_STEPS = { "heading", "body", "sub", "caption" } -- the take gives up size down the scale (round 30)

---------------------------------------------------------------------------
-- Building the console
---------------------------------------------------------------------------

-- (2.3; design 1 J) The fuel gauge: the Soul Shard count in words, "12 shards" ("1 shard"),
-- white (red when it warns), no picture. D.PaintFuel sets its words; g:SetShards(text, colour) fits its width
-- to them (g.w is that width), so a row's layout reads the real room. w, h and px are the first size and
-- the type size, a T.SIZE name (the mini console passes "caption" too: nothing is smaller).
function D.FuelGauge(parent, w, h, px)
	local g = CreateFrame("Frame", nil, parent)
	g:SetSize(w, h)
	g.w = w
	g.num = T.Text(g, px or "caption", "white", "CENTER", "medium", "OVERLAY")
	g.num:SetPoint("CENTER", g, "CENTER", 0, 0)
	g.num:SetWidth(w)
	g.num:SetText("")
	function g:SetShards(text, colour)
		self.num:SetWidth(200) -- room first, so the words are fitted at their own size
		self.num:SetText(text)
		self.num:SetTextColor(T.RGB(colour))
		local tw = text == "" and 1 or math.ceil(textW(self.num) * 1.06) + 2
		self.w = tw
		self.num:SetWidth(tw)
		self:SetWidth(tw)
	end
	g:EnableMouse(true)
	T.Tip(g, "Soul Shards", function()
		local _, _, tip = D.FuelInfo()
		return tip
	end)
	return g
end

-- the status strip, one line: the dot and word, "· 50s to Undercity" (a button: the sheet),
-- and today's take on the right, "8g today (16)" (a click: Earnings)
local function buildStatus(v)
	local s = CreateFrame("Frame", nil, v)
	s:SetPoint("TOPLEFT", v.up, "TOPLEFT", PAD, -2)
	s:SetPoint("TOPRIGHT", v.up, "TOPRIGHT", -PAD, -2)
	s:SetHeight(STRIP_H)
	v.statusBox = s
	s.dot = T.Circle(s, 10, "off", "ARTWORK")
	s.dot:SetPoint("LEFT", s, "LEFT", 4, 0)
	s.halo = noGlow() -- (design 1) no halo round the status dot; Draw.lua still colours and shows it
	s.word = T.Text(s, "body", "white", "LEFT", "bold")
	s.word:SetPoint("LEFT", s.dot, "RIGHT", 8, 0)
	s.word:SetWidth(60)
	-- (2.3) the Soul Shard gauge right of the words, the number on it
	s.fuel = D.FuelGauge(s, 34, 16, "caption")
	s.fuel:SetPoint("LEFT", s.word, "RIGHT", 6, 0)
	-- "· 50s to Undercity  ›": opens the price and place sheet
	local fare = CreateFrame("Button", nil, s)
	fare:SetPoint("LEFT", s.fuel, "RIGHT", 2, 0)
	fare:SetSize(160, 26)
	fare:RegisterForClicks("LeftButtonUp")
	fare.fill = T.PillFill(fare, "card", 26, "BACKGROUND", 0)
	fare.fill:SetColor("card") -- (design 1 J) a row with its chevron at the end, not a lone ">"
	fare.text = T.Text(fare, "body", "white", "LEFT", "regular")
	fare.text:SetPoint("LEFT", fare, "LEFT", 5, 0)
	fare.text:SetPoint("RIGHT", fare, "RIGHT", -16, 0)
	fare.text.wuberMin = T.SIZE.caption -- (round 9) a long place name fits by size (down to 11), not "..."
	fare.chev = T.Icon(fare, "back", 9, "muted", "OVERLAY")
	fare.chev:SetPoint("RIGHT", fare, "RIGHT", -5, 0)
	Try(fare.chev, "SetRotation", math.pi)
	safeScript(fare, "OnEnter", function(self) self.fill:SetColor("hover") end)
	safeScript(fare, "OnLeave", function(self) self.fill:SetColor("card") end)
	T.Press(fare, { fill = fare.fill })
	safeScript(fare, "OnClick", function() D.ShowSheet(RaidMode() and "raidpick" or "sheet") end)
	T.Tip(fare, function() return RaidMode() and "No charge for your raid" or "Price and place" end, function()
		if RaidMode() then return "Raid summons cost nothing and are only for your own raid. Click to pick which Warlocks summon." end
		return "Your fare and where you summon riders to. Click to change them, or the name riders see."
	end)
	v.fare = fare
	s.rides = T.Text(s, "body", "muted", "RIGHT", "regular")
	s.rides:SetPoint("RIGHT", s, "RIGHT", -2, 0)
	s.rides:SetWidth(90)
	s.gold = T.Text(s, "heading", "gold", "RIGHT", "bold")
	s.gold:SetPoint("RIGHT", s.rides, "LEFT", -3, 0)
	s.gold:SetWidth(60)
	local today = CreateFrame("Frame", nil, s)
	today:SetPoint("RIGHT", s, "RIGHT", 0, 0)
	today:SetSize(124, STRIP_H)
	today:EnableMouse(true)
	safeScript(today, "OnMouseUp", function() D.ShowScreen("earnings") end)
	T.Press(today)
	T.Tip(today, function() return RaidMode() and "Summoned tonight" or "Today" end, function()
		if RaidMode() then return "Raiders your Warlocks summoned in the last six hours. Click for your earnings from selling." end
		return "Gold and (rides) since midnight. Click for your earnings: which hours pay best."
	end)
	v.today = today
	-- (round 9) the fare's room reaches under the take's frame: the fare is on top there, so a click
	-- by its arrow opens the price sheet
	fare:SetFrameLevel(today:GetFrameLevel() + 2)
	local line = T.Line(v.up, "line", 0.7)
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", v.up, "TOPLEFT", PAD, -(STRIP_H + 4))
	line:SetPoint("TOPRIGHT", v.up, "TOPRIGHT", -PAD, -(STRIP_H + 4))
	v.status = s
end

-- The strip's widths follow its words: the word, the take on the right, the fare between.
local function layStatus(v)
	local s = v.status
	local fuelW = s.fuel and N(s.fuel.w) or 34 -- (design 1 J) the shard words' width
	-- (round 13, I18) the word with a little spare: the game draws it a touch wider than measured
	local ww = math.ceil(textW(s.word) * 1.06) + 1
	s.word:SetWidth(ww)
	ww = ww + (s.pioneerShift or 0) -- a Pioneer's badge before the dot takes room too
	local function spare(fs) return math.ceil(textW(fs) * 1.06) + 1 end
	-- (round 9) measured at the size asked for (a fitted label is smaller), plus 5 left, 16 for the
	-- chevron and a spare 3; then the words fit the room by size (T.Fit), never "..."
	local fs = v.fare.text
	local fw = ((T.poppins ~= false and fs.wuberBase) and math.ceil(T.MeasureText(fs.wuberText or "", fs.wuberBase, fs.wuberWeight)) or textW(fs)) + 24
	-- (round 13, I18) when the fare would not fit at its own size, "today (16)" says only "(16)"
	-- (its tooltip says Today): '50s to Orgrimmar' was cut at 'Orgrim...'
	local rides = S(s.rides:GetText()) or ""
	local short = rides:match("^today (%(%d+%))$")
	-- (round 47, AUD-160) measure the take at 16 every tick: its size from the last tick must not decide room
	if s.gold.wuberPx ~= T.SIZE.heading then pcall(T.SetFont, s.gold, "heading", "bold") end
	local rw, gw = spare(s.rides), spare(s.gold)
	-- (round 47, AUD-161) a hidden fare pill (a crew helper's strip) needs no room: no short word, no smaller take
	local fareOn = v.fare:IsShown()
	if fareOn and short and SLOT_W - 22 - ww - (fuelW + 8) - (rw + gw + 6) < fw * 1.06 then
		s.rides:SetText(short)
		rw = spare(s.rides)
	end
	local room = SLOT_W - 22 - ww - (fuelW + 8) - (rw + gw + 6)
	-- (round 30) a badge and a full day's take (or a long price) left the fare less than its smallest size
	-- needs: "50s to Thunder B...". Then the take gives up size first (down to 11), never its words.
	local fmin = math.ceil(T.MeasureText(fs.wuberText or "", fs.wuberMin or fs.wuberBase or "body", fs.wuberWeight) * 1.06) + 24
	local gpxStep = 1 -- the take steps down the scale: heading, body, sub, caption
	if fareOn and (fs.wuberBase and T.poppins ~= false) and room < fmin then
		while gpxStep < #GOLD_STEPS and room < fmin do
			gpxStep = gpxStep + 1
			pcall(T.SetFont, s.gold, GOLD_STEPS[gpxStep], "bold")
			gw = spare(s.gold)
			room = SLOT_W - 22 - ww - (fuelW + 8) - (rw + gw + 6)
		end
	elseif s.gold.wuberBase ~= T.SIZE.heading and s.gold.wuberPx ~= T.SIZE.heading then
		pcall(T.SetFont, s.gold, "heading", "bold")
		gw = spare(s.gold)
		room = SLOT_W - 22 - ww - (fuelW + 8) - (rw + gw + 6)
	end
	-- still short of its smallest size: the fare takes two lines at that size (the strip is tall enough)
	local two = fareOn and (fs.wuberBase and T.poppins ~= false) and room < fmin
	if two and not fs.wuberLines then
		fs.wuberMin = nil
		pcall(T.SetFont, fs, "caption", fs.wuberWeight)
		fs.wuberLines = 2
		fs:SetHeight(STRIP_H)
		fw = math.ceil(T.MeasureText(fs.wuberText or "", "caption", fs.wuberWeight)) + 24
	elseif not two and fs.wuberLines then
		fs.wuberLines = nil
		fs.wuberMin = T.SIZE.caption
		pcall(T.SetFont, fs, "body", fs.wuberWeight)
		pcall(fs.SetWordWrap, fs, false)
		fw = math.ceil(T.MeasureText(fs.wuberText or "", fs.wuberBase, fs.wuberWeight)) + 24
	end
	-- (2.4 fix round, HUNT-130) two lines must still hold the longest line: in a fight the pill had less room than
	-- "Booty Bay" needs at the smallest size, and the game cut it. The pill grows to the best split's width instead.
	local twoNeed = 0
	if two then
		local plain = (fs.wuberText or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
		local words = {}
		for word in plain:gmatch("%S+") do words[#words + 1] = word end
		local best = nil
		for cut = 0, math.max(0, #words - 1) do
			local left = table.concat(words, " ", 1, cut)
			local right = table.concat(words, " ", cut + 1)
			local wid = math.max(left ~= "" and T.MeasureText(left, "caption", fs.wuberWeight) or 0, T.MeasureText(right, "caption", fs.wuberWeight))
			if not best or wid < best then best = wid end
		end
		twoNeed = math.ceil((best or 0) * 1.06) + 1 + 21
		fw = math.min(fw, math.max(60, room))
	end
	local stack = two and twoNeed > room
	local takeW = rw + gw + 6
	if stack then
		if s.rides.wuberPx ~= T.SIZE.caption then pcall(T.SetFont, s.rides, "caption", "regular") end
		rw = spare(s.rides)
		if not s.stacked then
			s.stacked = true
			s.gold:ClearAllPoints()
			s.gold:SetPoint("TOPRIGHT", s, "TOPRIGHT", -2, -3)
			s.rides:ClearAllPoints()
			s.rides:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -2, 3)
		end
		takeW = math.max(rw, gw) + 3
		room = SLOT_W - 22 - ww - (fuelW + 8) - takeW
	elseif s.stacked then
		s.stacked = false
		if s.rides.wuberPx ~= T.SIZE.body then pcall(T.SetFont, s.rides, "body", "regular") end
		s.rides:ClearAllPoints()
		s.rides:SetPoint("RIGHT", s, "RIGHT", -2, 0)
		s.gold:ClearAllPoints()
		s.gold:SetPoint("RIGHT", s.rides, "LEFT", -3, 0)
	end
	s.rides:SetWidth(rw)
	s.gold:SetWidth(gw)
	v.today:SetWidth(stack and (math.max(rw, gw) + 4) or (rw + gw + 10))
	local fareW = math.max(math.min(60, math.max(room, 20)), math.min(room, fw)) -- (design 1 J) never wider than the room the take leaves
	if two and twoNeed > fareW then fareW = math.min(room, twoNeed) end
	v.fare:SetWidth(fareW)
	fs.wuberRoom = fareW - 21 -- (the room before the strip is laid out)
	fs.wuberSpare = 1.06 -- (round 13, I18) fitted with spare: 'Orgrimmar' drew wider and was cut at 'Orgrim...'
	T.Fit(fs)
end

-- The hero card's fill (the author's pick "06 v2"): a filled portal-violet card, bright at the top
-- left and deepening to night at the bottom right. Two rounded 9-slices lie over the dark
-- card: a violet one that fades left to right and a dark one that deepens top to bottom
-- (vertex gradients: SetGradient, or SetGradientAlpha on older clients, or a flat middle
-- shade). Shared with the floating big button (Drive_Button.lua's face).
-- D.HeroFill(frame, w, h, radius, sub) -> fill; fill:Paint(lit 0..1); fill:SetShown(on)
do
	local COL = { TL = 1, L = 1, BL = 1, T = 2, M = 2, B = 2, TR = 3, R = 3, BR = 3 }
	local ROW = { TL = 1, T = 1, TR = 1, L = 2, M = 2, R = 2, BL = 3, B = 3, BR = 3 }
	-- orient HORIZONTAL: a1 left, a2 right; VERTICAL: a1 bottom, a2 top (as the game has it)
	local function ramp(t, orient, c, a1, a2)
		local r, g, b = T.RGB(c)
		local ok = false
		if type(CreateColor) == "function" and t.SetGradient then
			ok = pcall(t.SetGradient, t, orient, CreateColor(r, g, b, a1), CreateColor(r, g, b, a2))
		end
		if not ok and t.SetGradientAlpha then
			ok = pcall(t.SetGradientAlpha, t, orient, r, g, b, a1, r, g, b, a2)
		end
		if not ok then t:SetVertexColor(r, g, b, (a1 + a2) / 2) end
	end
	local Fill = {}
	Fill.__index = Fill
	function Fill:Paint(lit)
		lit = math.max(0, math.min(1, N(lit) or 1))
		if self.lit == lit then return end
		self.lit = lit
		local w, h, r = self.w, self.h, self.r
		local xs = { 0, r / w, 1 - r / w, 1 }
		local ys = { 0, r / h, 1 - r / h, 1 }
		local function violet(x) return lit * (0.95 - 0.78 * x) end -- across: lit to dim
		local function night(y) return 0.6 * y end                    -- down: clear to dark
		for k, t in pairs(self.violet.parts) do
			ramp(t, "HORIZONTAL", "accent", violet(xs[COL[k]]), violet(xs[COL[k] + 1]))
		end
		for k, t in pairs(self.night.parts) do
			ramp(t, "VERTICAL", "card", night(ys[ROW[k] + 1]), night(ys[ROW[k]]))
		end
	end
	function Fill:SetShown(on)
		self.violet:SetShown(on)
		self.night:SetShown(on)
	end
	function D.HeroFill(frame, w, h, radius, sub)
		sub = sub or 1
		local f = setmetatable({ w = w, h = h, r = radius or 16 }, Fill)
		f.violet = T.NineSlice(frame, "rounded", f.r, 0.25, "BACKGROUND", sub)
		f.night = T.NineSlice(frame, "rounded", f.r, 0.25, "BACKGROUND", sub + 1)
		f.parts = f.violet.parts -- (marks it a slice for the button's skin)
		f:Paint(1)
		return f
	end
end

-- The hero card: the big button's slot (the lower part; the secure WuberDriveButton is laid
-- over it) under a band that holds the Skip pill. The card's violet fill, rim and glow are
-- drawn here; docked, the button shows only its words and its accent line on top.
local function buildSlot(v)
	local hero = CreateFrame("Frame", nil, v)
	hero:SetPoint("TOPLEFT", v.up, "TOPLEFT", PAD, -(STRIP_H + 10))
	hero:SetSize(SLOT_W, HERO_H)
	hero.glow = T.StateGlow(hero, "accent", 1, 14) -- (design 1) the big button keeps its state glow until its own redesign
	hero.glow:SetAlpha(0.5) -- strength by region alpha (D.HERO_LOOK)
	hero.rim = T.Rounded(hero, "glow", 17, "BACKGROUND", -2, 1.5)
	hero.bg = T.Rounded(hero, "hover", 16, "BACKGROUND", 0)
	hero.fill = D.HeroFill(hero, SLOT_W, HERO_H, 16, 1)
	-- a light that sweeps across once when a new click becomes due (moves; never scales)
	hero.shine = T.Tex(hero, "shimmer", "ARTWORK")
	hero.shine:SetSize(90, HERO_H - 6)
	hero.shine:SetPoint("LEFT", hero, "LEFT", 0, 0)
	hero.shine:SetAlpha(0)
	hero.shine:Hide()
	hero:EnableMouse(true)
	T.Tip(hero, "The big button", function()
		local plan = DR.button and DR.button.plan or dr("Plan")
		local say = type(plan) == "table" and S(plan.say)
		return (say and (say .. "\n\n") or "") .. "Its words always say what your next click does: summon, accept the gold, thank. Bind a key to it in Settings."
	end)
	v.hero = hero

	local slot = CreateFrame("Frame", nil, v)
	slot:SetPoint("BOTTOMLEFT", hero, "BOTTOMLEFT", 0, 0)
	slot:SetSize(SLOT_W, SLOT_H)
	-- what the button would say (seen only while no button is docked over the slot)
	slot.bar = CreateFrame("Frame", nil, slot)
	slot.bar:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", 16, 0) -- S3: the whole bottom, between the corners
	slot.bar:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -16, 0)
	slot.bar:SetHeight(3)
	slot.barFill = T.PillFill(slot.bar, "off", 3, "ARTWORK", 0)
	slot.title = T.Text(slot, "display", "white", "LEFT", "bold")
	slot.title:SetPoint("BOTTOMLEFT", slot, "LEFT", 20, 2)
	slot.title:SetPoint("BOTTOMRIGHT", slot, "RIGHT", -16, 2)
	slot.title.wuberMin = T.SIZE.heading
	slot.sub = T.Text(slot, "body", "white", "LEFT", "regular")
	slot.sub:SetTextColor(T.RGB("white", 0.82))
	slot.sub:SetPoint("TOPLEFT", slot, "LEFT", 20, -6)
	slot.sub:SetPoint("TOPRIGHT", slot, "RIGHT", -16, -6)
	slot.sub.wuberSpare = 1.06 -- (round 13, I18) fitted with spare: the game draws it a touch wider
	T.Lines(slot.sub, 2)
	slot:EnableMouse(true)
	T.Tip(slot, "The big button", function()
		local plan = DR.button and DR.button.plan or dr("Plan")
		local say = type(plan) == "table" and S(plan.say)
		return (say and (say .. "\n\n") or "") .. "Its words always say what your next click does: summon, accept the gold, thank. Bind a key to it in Settings."
	end)
	v.slot = slot

	-- Skip: a small pill in the card's top band (never over the button)
	local skip = CreateFrame("Button", nil, hero)
	skip:SetSize(58, 26)
	skip:RegisterForClicks("LeftButtonUp")
	skip:SetPoint("TOPRIGHT", hero, "TOPRIGHT", -12, -6)
	skip.fill = T.PillFill(skip, "white", 26, "BACKGROUND", 0)
	skip.fill:SetColor("white", 0.12)
	skip.label = T.Text(skip, "sub", "white", "CENTER", "medium")
	skip.label:SetPoint("CENTER", skip, "CENTER", 0, 0)
	skip.label:SetText("Skip")
	safeScript(skip, "OnEnter", function(self) self.fill:SetColor("white", 0.2) end)
	safeScript(skip, "OnLeave", function(self) self.fill:SetColor("white", 0.12) end)
	T.Press(skip, { fill = skip.fill })
	safeScript(skip, "OnClick", function()
		local block = call(IsShiftKeyDown) == true
		-- (AUD-196) "and blocked" only when Skip really put them on the blocklist: a rider only owed a
		-- sorry (or a raider) is just skipped, so Shift-click gets the plain Skip's toast
		local list = type(DR.db) == "table" and DR.db.blocklist
		local target = block and dr("SkipTarget")
		local key = type(target) == "table" and W.Key and call(W.Key, target.name)
		local was = key and type(list) == "table" and list[key] ~= nil
		local c = call(DR.Skip, block)
		if type(c) == "table" then
			local now = key and type(list) == "table" and list[key] ~= nil
			toast((block and now and not was) and (short(c.name) .. " is skipped and blocked") or (short(c.name) .. " is skipped"), "info")
		end
		D.Refresh()
	end)
	T.Tip(skip, "Skip", function()
		local c = dr("SkipTarget")
		local who = type(c) == "table" and short(c.name) or "this rider"
		return "Skip " .. who .. ": off the list, nothing is said. Shift-click: skip and block."
	end)
	skip:Hide()
	v.skip = skip
end

-- (Group Finder, B1) Called only from a button's OnClick that has just taken the driver offline, AFTER the offline call,
-- so going offline completes even when the game refuses the removal. Never from D.SetOnline (it may run without a click).
function D.DelistOnOffline()
	local GF = W.GroupFinder
	if type(GF) ~= "table" or type(GF.On) ~= "function" or not GF.On() then return end
	local ok, err = pcall(GF.Delist)
	if not ok then W.Error("GroupFinder delist", err) end
end

-- Open / Close, Pause / Resume, Advertise
local function buildControls(v)
	local w = math.floor((SLOT_W - 16) / 3)
	local y = -(STRIP_H + 10 + HERO_H + 12)
	v.open = T.Pill(v, "Open", "primary", w, PILL_H)
	v.open:SetPoint("TOPLEFT", v.up, "TOPLEFT", PAD, y)
	safeScript(v.open, "OnClick", function()
		if inCombat() and not IsOpen() then toast((RaidMode() and "Starting" or "Opening") .. " works after the fight", "warn") return end
		if RaidMode() and not IsOpen() then
			local can, why = dr("CanRunRaid")
			if can == false then toast(S(why) or "You need lead or assist", "warn") return end
		end
		local wasOpen = IsOpen()
		D.SetOnline(not wasOpen)
		if wasOpen and not IsOpen() then D.DelistOnOffline() end
	end)
	T.Tip(v.open, function()
		if RaidMode() then return IsOpen() and "Stop" or "Start" end
		return IsOpen() and "Close" or "Open"
	end, function()
		if RaidMode() then
			if IsOpen() then return "Stop raid summons. Nobody new is queued; your Warlocks' buttons go quiet." end
			return "Start raid summons: raiders who type 123 (or summ) in raid chat, or ask in Wuber, are queued and your Warlocks summon them one by one. No charge, no adverts, no invites."
		end
		if IsOpen() then return "Stop taking riders. If riders are still with you, Wuber asks first. You vanish from the map." end
		local t = "Start taking riders: Wuber shows you on riders' maps, answers whispers and invites people who ask."
		if advertOn() then t = t .. " This click also posts one advert line in public chat (Settings: Post an advert when I go online)." end
		return t
	end)
	v.pause = T.Pill(v, "Pause", "dark", w, PILL_H)
	v.pause:SetPoint("LEFT", v.open, "RIGHT", 8, 0)
	safeScript(v.pause, "OnClick", function()
		if not IsOpen() then return end -- dimmed while closed: a click changes nothing (AUD-195)
		D.SetPaused(not IsPaused())
	end)
	T.Tip(v.pause, function() return IsPaused() and "Resume" or "Pause" end, function()
		if RaidMode() then
			if IsPaused() then return "Summon raiders again." end
			return "A short break: raiders can still ask and stay in the queue, but nobody is summoned until you resume."
		end
		if IsPaused() then return "Start inviting new riders again." end
		return "A short break: no new invites. Riders already in your group are still summoned and paid."
	end)
	-- raid summons: who summons (in place of Advertise)
	-- (round 13, I17) "Warlocks": "Summoners" didn't fit its pill ("Summone...")
	v.pick = T.Pill(v, "Warlocks", "dark", w, PILL_H)
	v.pick:SetPoint("LEFT", v.pause, "RIGHT", 8, 0)
	safeScript(v.pick, "OnClick", function() D.ShowSheet("raidpick") end)
	T.Tip(v.pick, "Warlocks", "Pick which Warlocks in your raid summon, and in what order. Each one with Wuber gets a card to say yes.")
	-- (round 13, I18) its one word has the pill's width, less a small inset (not half its height)
	v.pick.label:SetPoint("LEFT", v.pick, "LEFT", 10, 0)
	v.pick.label:SetPoint("RIGHT", v.pick, "RIGHT", -10, 0)
	v.pick:Hide()
	v.advert = T.Pill(v, "Advertise", "dark", w, PILL_H)
	v.advert:SetPoint("LEFT", v.pause, "RIGHT", 8, 0)
	safeScript(v.advert, "OnClick", function()
		-- only reached when the secure button isn't over it: say why not
		if not IsOpen() then toast("Open first, then advertise", "info") return end
		local _, why, wait = D.AdvertPlan()
		toast(D.AdvertWhy(why, wait), "warn")
	end)
	T.Tip(v.advert, "Advertise", function()
		local plan = D.AdvertPlan()
		local line = type(plan) == "table" and S(plan.text)
		return "Posts one line in public chat, always starting [Wuber], so buyers find you and get the addon."
			.. (line and ("\n\n" .. line) or "")
			.. "\n\nTyping your own adverts in Trade? Put Wuber in them: other Wuber players' addons hear it and add you."
			.. "\n\nAt most once every 15 minutes, never in combat, only when you click. Change the line in Messages."
	end)
end

-- the scrolling middle: Ready to drive, the queue, the crew strip, the community card
local function buildMiddle(v)
	-- (round 9 previews) lift 12: the rows sit 3 levels up; Earnings, Messages, Crew... open over the
	-- console at its level + 20, and a higher fade showed through them
	local sc = T.Scroll(v, { lift = 12 })
	sc:SetPoint("TOPLEFT", v, "TOPLEFT", 0, -TOP_FIXED)
	sc:SetPoint("BOTTOMRIGHT", v, "BOTTOMRIGHT", 0, 0) -- (design 2) down to the body's bottom: no bar of its own
	v.scroll = sc
	local c = sc.content

	-- Ready to drive
	local ready = T.Card(c, SLOT_W, 60, { colour = "card", radius = 14, shadow = false, border = "red" })
	ready:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -2)
	ready.title = T.Text(ready, "body", "red", "LEFT", "bold")
	ready.title:SetPoint("TOPLEFT", ready, "TOPLEFT", 14, -12)
	ready.title:SetText("Ready to drive?")
	ready.lines = {}
	ready:Hide()
	v.ready = ready

	-- the queue
	v.qhead = T.Text(c, "body", "white", "LEFT", "bold")
	v.qhead:SetText("Riders")
	v.qcount = T.Text(c, "caption", "muted", "LEFT", "regular")
	v.qcount:SetPoint("LEFT", v.qhead, "RIGHT", 8, 0)
	v.qcount:SetWidth(200)
	v.empty = CreateFrame("Frame", nil, c)
	v.empty:SetSize(SLOT_W, 64)
	v.empty.bg = T.Rounded(v.empty, "card", 14, "BACKGROUND", 0)
	v.empty.pulse = A.Pulse(v.empty, { size = 44, colour = "accent", alpha = 0.5, period = 2.2, rings = 2, start = false })
	v.empty.pulse.frame:ClearAllPoints()
	v.empty.pulse.frame:SetPoint("CENTER", v.empty, "LEFT", 32, 0)
	v.empty.ring = T.Icon(v.empty, "ring", 26, "accent", "ARTWORK")
	v.empty.ring:SetPoint("CENTER", v.empty, "LEFT", 32, 0)
	v.empty.icon = T.Icon(v.empty, "radar", 24, "glow", "OVERLAY")
	v.empty.icon:SetPoint("CENTER", v.empty, "LEFT", 32, 0)
	v.empty.text = T.Text(v.empty, "body", "white", "LEFT", "medium")
	v.empty.text:SetPoint("TOPLEFT", v.empty, "TOPLEFT", 60, -15)
	v.empty.text:SetPoint("RIGHT", v.empty, "RIGHT", -12, 0)
	v.empty.sub = T.Text(v.empty, "caption", "muted", "LEFT", "regular")
	v.empty.sub:SetPoint("TOPLEFT", v.empty.text, "BOTTOMLEFT", 0, -3)
	v.empty.sub:SetPoint("RIGHT", v.empty, "RIGHT", -12, 0)
	v.coach = T.Text(c, "caption", "muted", "LEFT", "regular")
	v.coach:SetText("Tip: hold a name (or tap its Options button) for more.")
	v.coach:SetWidth(SLOT_W)
	v.coach:Hide()
	v.rows = {}
	for i = 1, MAX_ROWS do
		v.rows[i] = D.Row(c, SLOT_W)
		v.rows[i]:SetHeight(QROW_H)
	end
	v.more = T.Text(c, "caption", "muted", "CENTER", "medium")
	v.more:SetWidth(SLOT_W)

	-- the crew strip
	v.crewHead = T.Text(c, "body", "white", "LEFT", "bold")
	v.crewHead:SetText("Crew")
	v.shards = T.Text(c, "caption", "muted", "RIGHT", "medium")
	v.shards:SetWidth(200)
	v.chips = {}
end

-- one crew chip: role glyph, name, shards, a star on the caster whose turn it is
local function crewChip(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(100, 30)
	b:RegisterForClicks("LeftButtonUp")
	b.fill = T.PillFill(b, "card", 30, "BACKGROUND", 0)
	b.glyph = T.Icon(b, "summon", 14, "glow", "ARTWORK")
	b.glyph:SetPoint("LEFT", b, "LEFT", 10, 0)
	b.name = T.Text(b, "caption", "white", "LEFT", "bold")
	b.name:SetPoint("LEFT", b.glyph, "RIGHT", 6, 0)
	b.count = T.Text(b, "caption", "gold", "LEFT", "bold")
	b.count:SetPoint("LEFT", b.name, "RIGHT", 5, 0)
	b.star = T.Icon(b, "star", 12, "glow", "OVERLAY")
	b.star:SetPoint("RIGHT", b, "RIGHT", -9, 0)
	safeScript(b, "OnEnter", function(self) self.fill:SetColor("hover") end)
	safeScript(b, "OnLeave", function(self) self.fill:SetColor("card") end)
	safeScript(b, "OnClick", function() D.ShowScreen("crew") end)
	T.Tip(b, function(self) return S(self.m and self.m.name) or "Crew" end, function(self)
		local m = self.m or {}
		local t = m.role == "lock" and "A Warlock in your crew: summons and clicks." or "A helper in your crew: clicks the portal."
		if m.role == "lock" and N(m.shards) and m.shards >= 0 then t = t .. " " .. plural(m.shards, "Soul Shard") .. "." end
		if self.turn then t = t .. " Casts the next summon." end
		if m.silent then t = t .. " Not heard from for a while (no Wuber running, or away)." end
		if m.app == false then t = t .. " Doesn't have Wuber: never treated as a rider." end
		-- (2.3) this shift's casts and clicks
		local casts, clicks
		if D.CutFor then casts, clicks = D.CutFor(m.key) end
		if casts and D.CutWords then t = t .. "\nThis shift: " .. D.CutWords(casts, clicks) .. "." end
		return t .. "\nClick: your crew."
	end)
	return b
end

-- Crew · Messages · Blocked (N) · Earnings · Customers (round 13, I20: Settings is the top bar's
-- gear only)
local LINKS = {
	{ "crew", "Crew", "Who summons and clicks with you. Add friends or your own other characters.", "summon" },
	{ "messages", "Messages", "What Wuber whispers to riders (greeting, price, thanks...). Change any of them.", "chat" },
	{ "blocked", "Blocked", "Players you won't serve, and why. Unblock anyone here.", "lock" },
	{ "earnings", "Earnings", "Rides, gold and which hours of the day pay best.", "coin" },
	-- round 9 (Y3): everyone who rode with you, your notes and gifts (UI.Driver.Customers)
	{ "customers", "Customers", "Everyone who rode with you: your notes, gifts and their rides. Search by name.", "note" },
}

-- (design round 2, item 11) "Your business": Crew, Messages, Blocked, Earnings, Customers as ONE grouped list
-- (T.RowGroup) at the END of the console's scrolling page, after the riders. The console has no bar of its own at
-- the bottom any more: the window's tab bar sits there. v.links[i] / v.links[name] is the row (a link is a row):
-- .what, :SetLabel(words), .icon, .label, .dot, .badge, .count, .glow (Messages, until it was opened once).
-- "Blocked (2)": the count is in the row's words (UI.Driver.Draw), so .dot and .badge stay hidden.
local function buildBusiness(v)
	local c = v.scroll.content
	local g = T.RowGroup(c, SLOT_W)
	g:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -40)
	v.business = g
	v.businessHead = T.RowHeading(c, "Your business", g)
	v.links = {}
	for i, l in ipairs(LINKS) do
		local b = g:Row({ title = l[2], icon = l[4], right = "chevron", tip = { body = l[3] },
			onClick = function(row) D.ShowScreen(row.what) end })
		b.what = l[1]
		b.label = b.title
		b.badge = T.Text(b.lead, "caption", "ink", "CENTER", "bold")
		b.dot = T.Circle(b.lead, 14, "red", "ARTWORK")
		b.dot:SetPoint("CENTER", b.lead, "TOPRIGHT", -2, -2)
		b.badge:SetPoint("CENTER", b.dot, "CENTER", 0, 0)
		b.dot:Hide()
		b.badge:Hide()
		function b.SetLabel(self, t) self:SetTitle(t) end
		if l[1] == "messages" then
			-- (round 9, S5) until the driver has opened Messages once: a small dot at the icon's
			-- corner that breathes (alpha only, never Scale).
			b.glow = T.Circle(b.lead, 7, "accent", "OVERLAY")
			b.glow:SetPoint("CENTER", b.lead, "TOPRIGHT", -3, -3)
			b.glow:SetAlpha(0)
			local t0 = 0
			safeScript(b, "OnUpdate", function(self, el)
				local db = W.db
				if type(db) == "table" and db.msgSeen then
					self.glow:Hide()
					self:SetScript("OnUpdate", nil)
					return
				end
				t0 = t0 + (el or 0)
				self.glow:SetAlpha(0.55 + 0.45 * (0.5 + 0.5 * math.sin(t0 * 3)))
			end)
		end
		v.links[l[1]] = b
		v.links[i] = b
	end
	g:Layout()
end

-- Sell summons / Raid summons: only for characters that set up driving
function D.SetMode(m)
	if type(DR.SetMode) ~= "function" then
		toast("Raid summons aren't ready in this Wuber yet", "warn")
		return false
	end
	if m == dr("Mode") then return true end
	local ok, why = call(DR.SetMode, m)
	if ok == false then toast(S(why) or "Couldn't switch", "warn") end
	D.Refresh(true)
	return ok ~= false
end

-- A segmented choice made calm (round 7): gold is for the big button; the chosen part is a
-- violet pill with ink words (item 2 of the design audit), the others muted (UI_Drive.lua's Earnings uses it too).
-- T.Segmented lights the chosen part with its own opaque pill (shown or hidden, never an
-- alpha change); this only sets its look: no gold glow (ghost), the lighter pill, white words.
function D.CalmSegmented(seg)
	seg.bg:SetColor("panel")
	seg.onStyle, seg.onText = "ghost", "ink"
	seg.litFor = function() return "glow" end
	seg:SetValue(seg.value)
	return seg
end

-- (design 2, P2) The switch sits IN the window's header zone, at the left: 16 from the edge, on the line of the
-- header's buttons, ending 8 before the leftmost of them (UI.HeadRoom(): folded they are over this pane; unfolded
-- they are over the side pane and the switch is as wide as the pane less its margins). Its words keep their size
-- and are never cut: the space at each side of a word shrinks (12 down to 3: beside all three buttons the switch
-- is 191 wide, a half 93.5, and "Raid summons" measures 86), and when even that is too little the
-- switch goes back under the buttons, full width, as (design 2, C) had it. Called on every draw of the controls
-- (the fold button comes and goes, the window folds); lays out only on a change.
-- Returns inZone, the switch's width, the widest word.
-- (r54 E) the game draws regular and medium text 6 to 8 per cent wider than the width table says (the game's own check, 24 Nov: "Raid summons"
-- cut on every folded console), so a word is measured with 8 per cent over (the table is at most 7.7 under) and may touch the switch's halves' edges before the switch leaves the zone, and with the game's own width when it gives one.
local MODE = { h = 28, left = 16, gap = 8, pad = 12, minPad = 0, safety = 1.08 }
local function wordWidth(label)
	local w = (N(T.MeasureText(label:GetText(), "sub", "medium")) or 0) * MODE.safety
	local real = type(label.GetUnboundedStringWidth) == "function" and N(label:GetUnboundedStringWidth())
		or (type(label.GetStringWidth) == "function" and N(label:GetStringWidth())) or 0
	return math.max(w, real)
end
function D.PlaceModeBar(v)
	local seg = v and v.modeBar
	if not seg then return false end
	local UI = W.UI
	local room = type(UI.HeadRoom) == "function" and N(UI.HeadRoom()) or 0
	local w = SLOT_W + PAD * 2 - MODE.left - (room > 0 and (room + MODE.gap) or MODE.left)
	local need = 0
	for _, b in ipairs(seg.buttons) do
		need = math.max(need, wordWidth(b.label))
	end
	local zone = need + MODE.minPad * 2 <= (w - 4) / 2
	local x, y = MODE.left, -((N(UI.HEAD_H) or 56) - MODE.h) / 2
	if not zone then w, x, y = SLOT_W, PAD, -((N(UI.HEAD_ROW) or 44) + 4) end
	seg.room, seg.zone = room, zone
	local key = w .. (zone and " zone" or " row")
	if seg.placed ~= key then
		seg.placed = key
		seg:ClearAllPoints()
		seg:SetPoint("TOPLEFT", v, "TOPLEFT", x, y)
		seg:SetWidth(w)
		if W.UI and W.UI.HeadHit then pcall(W.UI.HeadHit) end
		local bw = (w - 4) / 2
		local pad = math.max(MODE.minPad, math.min(MODE.pad, math.floor((bw - need) / 2)))
		for i, b in ipairs(seg.buttons) do
			b:SetWidth(bw)
			b:ClearAllPoints()
			b:SetPoint("LEFT", seg, "LEFT", 2 + (i - 1) * bw, 0)
			b.label:ClearAllPoints()
			b.label:SetPoint("LEFT", b, "LEFT", pad, 0)
			b.label:SetPoint("RIGHT", b, "RIGHT", -pad, 0)
			b.label.wuberRoom = bw - pad * 2
		end
	end
	return zone, w, need
end

local function buildModeBar(v)
	local seg = T.Segmented(v, {
		{ value = "sell", label = "Sell summons", tip = "Paying riders from anywhere: they find you on the map and in chat, and pay the Warlock who summons them." },
		{ value = "raid", label = "Raid summons", tip = "Summons at no charge for your own raid: raiders type 123 in raid chat and your Warlocks bring them to where they stand." },
	}, "sell", function(m) D.SetMode(m) end, SLOT_W, MODE.h)
	D.CalmSegmented(seg)
	seg:SetValue("sell")
	seg:Hide()
	v.modeBar = seg
	D.PlaceModeBar(v)
	-- (#36) the switch lies in the header zone, under the window's drag strip: the strip leaves it free (UI.HeadHit)
	if W.UI and W.UI.HeadControl then
		W.UI.HeadControl(seg)
		seg:HookScript("OnShow", function() pcall(W.UI.HeadHit) end)
		seg:HookScript("OnHide", function() pcall(W.UI.HeadHit) end)
	end
	-- the fold button comes and goes between two draws (UI.HeadLayout): the switch follows on the next frame, and
	-- the console is drawn again only when the switch changed between the zone and its own row (the rows under it move)
	safeScript(seg, "OnUpdate", function(self)
		local room = type(W.UI.HeadRoom) == "function" and N(W.UI.HeadRoom()) or 0
		if room == self.room then return end
		local was = self.zone
		if D.PlaceModeBar(v) ~= was and type(D.Refresh) == "function" then D.Refresh(true) end
	end)
end

local function buildConsole(root)
	local v = CreateFrame("Frame", nil, root)
	v:SetAllPoints(root)
	-- everything above the scroll hangs from v.up, which starts under the window's buttons (and under the Sell/Raid
	-- switch when that has to be a row of its own: D.PlaceModeBar)
	v.up = CreateFrame("Frame", nil, v)
	v.up:SetPoint("TOPLEFT", v, "TOPLEFT", 0, -(W.UI.HEAD_ROW or 44))
	v.up:SetPoint("TOPRIGHT", v, "TOPRIGHT", 0, -(W.UI.HEAD_ROW or 44))
	v.up:SetHeight(TOP_FIXED)
	v.hdr = 0
	buildModeBar(v)
	buildStatus(v)
	buildSlot(v)
	buildControls(v)
	buildMiddle(v)
	buildBusiness(v)
	v:Hide()
	return v
end

-- Closed and never set up: "Sell summons with Wuber" (a Warlock), "Run a summoning service"
-- (any other class: a Warlock friend or your own Warlock casts)
local WELCOME = {
	lock = {
		title = "Sell summons with Wuber",
		sub = "Riders find you on the map and in chat. Wuber invites them, whispers and reads the trade: you press one big button.",
		points = { "You set your own price (50s or more)", "Drive alone, with friends, or multibox", "Nothing goes in chat without your click, except the short auto-reply to riders who ask in public and the Messages lines you switch on (Settings can turn the auto-reply off)" },
	},
	other = {
		title = "Run a summoning service",
		sub = "Any class can run it: a Warlock friend or your own Warlock casts, you invite riders, set the price and press one big button.",
		points = { "A Warlock friend or your own Warlock summons", "Riders pay the Warlock who summons them", "Raid summons at no charge for your own raid too" },
	},
}

local function buildWelcome(root)
	local v = CreateFrame("Frame", nil, root)
	v:SetAllPoints(root)
	v.art = T.Tex(v, "portal", "ARTWORK")
	v.art:SetSize(132, 132)
	v.art:SetPoint("TOP", v, "TOP", 0, -56)
	v.title = T.Text(v, "title", "white", "CENTER", "bold")
	v.title:SetPoint("TOP", v.art, "BOTTOM", 0, -20)
	v.title:SetWidth(330)
	v.sub = T.Para(v, "sub", "muted", 296)
	v.sub:SetJustifyH("CENTER")
	v.sub:SetPoint("TOP", v.title, "BOTTOM", 0, -10)
	v.points = {}
	for i = 1, 3 do
		local icon = T.Icon(v, "check", 14, "glow", "OVERLAY")
		local t = T.Para(v, "sub", "white", 280, "medium") -- wraps: the longest point (the auto-reply exception) takes more lines
		t:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 0)
		v.points[i] = { icon = icon, text = t }
	end
	-- (Design 2) the main button's place; the link under it ("Just open the console") takes the 12 under the page's foot
	v.go = T.MainButton(v, "Set up driving", { foot = T.MAIN.foot + 30 + 6 })
	safeScript(v.go, "OnClick", function() D.ShowScreen("wizard") end)
	T.Tip(v.go, "Set up driving", function()
		if IsWarlock() then return "Three short steps: who summons with you, your crew, then a quick check. No commands to type." end
		return "Three short steps: whose Warlock summons, your crew, then who casts. No commands to type."
	end)
	v.skip = T.Pill(v, "Just open the console", "ghost", 240, 30)
	v.skip:SetPoint("TOP", v.go, "BOTTOM", 0, -6)
	v.skip.label:SetTextColor(T.RGB("muted"))
	safeScript(v.skip, "OnClick", function()
		if not IsWarlock() then
			toast("When a Warlock adds you to their crew, a card asks you to say yes", "info")
			return
		end
		local c = Char()
		if c then c.welcomed = true end
		D.Refresh()
	end)
	T.Tip(v.skip, function() return IsWarlock() and "Just open the console" or "Just help a friend's summons" end, function()
		if IsWarlock() then return "Skip the setup and drive on your own. You can set up a crew any time from Crew." end
		return "Any class can click a Warlock's portal. When a friend adds you to their crew, a card asks you to say yes; then Wuber calls you when it's time to click."
	end)
	v:Hide()
	return v
end

local function paintWelcome(v)
	local lock = IsWarlock()
	local w = lock and WELCOME.lock or WELCOME.other
	if v.paintedFor == lock then return end
	v.paintedFor = lock
	v.title:SetText(w.title)
	local h = v.sub:SetPara(w.sub) or 40
	-- (2.4.4 gauntlet) 12 under the sub text, was 22: the points wrap onto more lines since #267 #269 (7% room) and the longest one
	-- ended 8 below the top of the main button
	local y = -(56 + 132 + 20 + 26 + 10 + h + 12)
	for i, p in ipairs(v.points) do
		p.icon:ClearAllPoints()
		p.icon:SetPoint("TOPLEFT", v, "TOPLEFT", 36, y)
		local ph = p.text:SetPara(w.points[i]) or 14
		y = y - math.max(24, ph + 10)
	end
	v.skip:SetLabel(lock and "Just open the console" or "Just help a friend's summons")
end

-- Another addon drives (a third-party provider, or the old 1.x summoning addon): its requests,
-- and the retire card for the old addon (UI_Drive.lua's D.screens.retire builds the card)
local function buildProvider(root)
	local v = CreateFrame("Frame", nil, root)
	v:SetAllPoints(root)
	local glyph = T.Icon(v, "summon", 26, "glow", "ARTWORK")
	glyph:SetPoint("TOPLEFT", v, "TOPLEFT", 16, -16)
	v.title = T.Text(v, "heading", "white", "LEFT", "bold")
	v.title:SetPoint("LEFT", glyph, "RIGHT", 10, 0)
	v.title:SetWidth(290)
	v.sub = T.Text(v, "caption", "muted", "LEFT", "regular")
	v.sub:SetPoint("TOPLEFT", v, "TOPLEFT", 16, -50)
	v.sub:SetWidth(328)
	T.Lines(v.sub, 2) -- (2.4 fix round, HUNT-140) a long addon name wraps onto a second line, the words are never cut
	v.top = 82
	v.head = T.Text(v, "body", "white", "LEFT", "bold")
	v.head:SetText("Wuber requests")
	v.empty = T.Text(v, "sub", "muted", "CENTER", "regular")
	v.empty:SetText("No Wuber requests yet")
	v.empty:SetWidth(SLOT_W)
	v.cards = {}
	v:Hide()
	return v
end

-- for other modules (REFACTOR-MAP section 2): set at the end, when every local holds its final value
Mod.buildConsole = buildConsole
Mod.buildProvider = buildProvider
Mod.buildWelcome = buildWelcome
Mod.crewChip = crewChip
Mod.layStatus = layStatus
Mod.paintWelcome = paintWelcome
