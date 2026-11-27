-- Module: UI.Rider.Wrapped
-- Purpose: Azeroth Wrapped on the Trips tab: the "Your October in Azeroth" card, the 5-slide story
--   (tap or 6 s, progress bars, paused on hover), the share pill and the last 6 months' chip.
-- API: Mod.Due, Mod.Months, Mod.Card, Mod.Chip, Mod.Open, Mod.Close, Mod.Shown, Mod.Next, Mod.Prev,
--   Mod.Slides, Mod.ShareText, Mod.Story, Mod.SyncSummary
-- Internals: buildStory, showSlide, slideLines, lastMonth, buildSummary, summary
-- Uses: UI.Kit
-- Later: Core.Wrapped (the numbers, through W.Mod at run time), UI.Share (the share pill)
-- Events: listens (none); fires (none)
-- Standalone: no
-- Test: tests/ui/rider/wrapped_test.lua
-- From: new in Wuber 2.3.0
--
-- Trips (UI.Rider.Trips) asks Due() on each visit: in the first 10 days of a month, the month
-- before with 3+ rides gives the card once (W.db.wrapped.seen = "2026-10"); afterwards Chip()
-- opens any of the last 6 months with rides. Open(year, month) shows the story over the Trips
-- tab: slides of the recap (Core.Wrapped.Month), the driver's slide when they drove that month,
-- and a summary with Share (UI.Share: the player's click posts to party or raid, at most once a
-- minute per month). Slides move by translation and alpha only (no scale); a time worked out,
-- not timed, says about; unknown flight savings are left out.
-- Unfolded: the slide stays on the left, the whole month is a list in
-- the Trips side pane (UI.trips.side.holder); a row's click shows that slide. Folded: no list.
-- (round 13, I1) The story and the list are solid (a reviewer saw '1h 50m', 'Bronze Rider' and the
-- milestones ghost through them): while they show, the Trips page under them is put out of sight
-- (alpha 0: its scroll area, the side pane's, the Wrapped card) and comes back on Close. Unfolded,
-- the story's x is the list's, at the window's right edge (not a second x mid-window).

local _, W = ...
local Mod = W.Module("UI.Rider.Wrapped", { "UI.Kit" })
local KitMod = W.Mod("UI.Kit")
local INNER = KitMod.INNER
local N = KitMod.N
local PAD = KitMod.PAD
local S = KitMod.S
local call = KitMod.call
local duration = KitMod.duration
local money = KitMod.money
local safeScript = KitMod.safeScript
local setShown = KitMod.setShown
local T = W.Theme
local A = T.Animate
local Try = T.Try
local UI = W.UI

local SLIDE_SECS = 6
local SHARE_GAP = 60
local story -- the overlay (built on first open)
local summary -- the unfolded month list (built the first time the story shows unfolded)
local syncSummary -- (defined below the story)
local NIGHT = { 0.06, 0.04, 0.12, 1 } -- the story's solid background

-- (I1) the Trips page under the story: out of sight while it shows (on = true), back after
local function coverTrips(on)
	local tr = UI.trips
	if type(tr) ~= "table" then return end
	local a = on and 0 or 1
	-- (a field list with holes: ipairs would stop at the first nil, so each is named)
	local list = { tr.clip, tr.wrapCard, tr.title, tr.cue }
	list[#list + 1] = tr.side and tr.side.clip or nil
	for i = 1, 5 do
		local f = list[i]
		if f and f.SetAlpha then f:SetAlpha(a) end
	end
end

local function recap(year, month)
	local CW = W.Mod("Core.Wrapped")
	if type(CW) ~= "table" or type(CW.Month) ~= "function" then return nil end
	local m = call(CW.Month, year, month)
	return type(m) == "table" and m or nil
end

local function today()
	if type(date) ~= "function" then return nil end
	local ok, t = pcall(date, "*t")
	if ok and type(t) == "table" and t.year then return t end
	return nil
end

local function lastMonth(y, m)
	if m <= 1 then return y - 1, 12 end
	return y, m - 1
end

local function wdb()
	if type(W.db) ~= "table" then return nil end
	if type(W.db.wrapped) ~= "table" then W.db.wrapped = { shared = {} } end
	if type(W.db.wrapped.shared) ~= "table" then W.db.wrapped.shared = {} end
	return W.db.wrapped
end

-- The month whose card is due on this Trips visit (first 10 days, 3+ rides, not seen): y, m, recap.
function Mod.Due()
	local t = today()
	if not t or t.day > 10 or type(W.db) ~= "table" then return nil end
	local y, m = lastMonth(t.year, t.month)
	local seen = type(W.db.wrapped) == "table" and S(W.db.wrapped.seen) or nil
	local key = string.format("%04d-%02d", y, m)
	if seen and seen >= key then return nil end
	local r = recap(y, m)
	if not r or (N(r.rides) or 0) < 3 then return nil end
	return y, m, r
end

-- The card was shown: never again for that month.
function Mod.MarkSeen(y, m)
	local d = wdb()
	if d then d.seen = string.format("%04d-%02d", y, m) end
end

-- The last 6 months (before this one) with rides, newest first: { { year, month, recap } }.
function Mod.Months()
	local t = today()
	local out = {}
	if not t then return out end
	local y, m = t.year, t.month
	for _ = 1, 6 do
		y, m = lastMonth(y, m)
		local r = recap(y, m)
		if r and ((N(r.rides) or 0) > 0 or r.driver) then out[#out + 1] = { year = y, month = m, recap = r } end
	end
	return out
end

-- "My October on Wuber: 14 summons, 3 h 20 min saved, favourite driver Anita."
function Mod.ShareText(r)
	if type(r) ~= "table" then return nil end
	local parts = { (N(r.rides) or 0) .. ((N(r.rides) or 0) == 1 and " summon" or " summons") }
	if (N(r.saved) or 0) >= 60 then parts[#parts + 1] = (r.about and "about " or "") .. duration(r.saved) .. " saved" end
	if S(r.topDriver) then parts[#parts + 1] = "favourite driver " .. r.topDriver end
	local line = "My " .. (S(r.name) or "month") .. " on Wuber: " .. table.concat(parts, ", ") .. "."
	if type(W.SentenceSpam) == "function" and call(W.SentenceSpam, line) then return nil end
	return W.Clean(line, 240)
end

-- The slides for a recap: { { kicker, big, lines = { ... } } } (only what we can back).
function Mod.Slides(r)
	local slides = {}
	local rides = N(r.rides) or 0
	slides[#slides + 1] = { kicker = "Your " .. (S(r.name) or "month") .. " in Azeroth", big = rides .. (rides == 1 and " summon" or " summons"),
		lines = { (N(r.places) or 0) .. ((N(r.places) or 0) == 1 and " place" or " places") .. (S(r.topPlace) and (" · most of all " .. r.topPlace) or "") } }
	local saved = N(r.saved) or 0
	local s2 = { kicker = "Time saved", big = saved >= 60 and ((r.about and "about " or "") .. duration(saved)) or "A few minutes", lines = {} }
	if (N(r.flightSaved) or 0) > 0 then s2.lines[#s2.lines + 1] = money(r.flightSaved) .. " of flights skipped" end
	s2.lines[#s2.lines + 1] = "Flying you didn't have to do."
	slides[#slides + 1] = s2
	local s3 = { kicker = "Favourite driver", big = S(r.topDriver) or "Lots of drivers", lines = {} }
	if N(r.topDriverN) and r.topDriverN > 1 then s3.lines[#s3.lines + 1] = r.topDriverN .. " rides together" end
	local hop = r.longestHop
	if type(hop) == "table" and S(hop.from) and S(hop.to) then s3.lines[#s3.lines + 1] = "Longest hop: " .. hop.from .. " to " .. hop.to end
	slides[#slides + 1] = s3
	local newN = type(r.newPlaces) == "table" and #r.newPlaces or 0
	local s4 = { kicker = "New this month", big = newN .. (newN == 1 and " new place" or " new places"), lines = {} }
	if newN > 0 then s4.lines[#s4.lines + 1] = table.concat(r.newPlaces, ", ", 1, math.min(3, newN)) .. (newN > 3 and " and more" or "") end
	if (N(r.streak) or 0) >= 2 then s4.lines[#s4.lines + 1] = r.streak .. " days in a row" end
	local tier = N(r.tier) or 0
	if tier >= 1 and type(W.TierName) == "function" then s4.lines[#s4.lines + 1] = S(call(W.TierName, tier)) .. " rider" end
	slides[#slides + 1] = s4
	local dr = r.driver
	if type(dr) == "table" and (N(dr.rides) or 0) > 0 then
		local s5 = { kicker = "Behind the portal", big = dr.rides .. (dr.rides == 1 and " ride given" or " rides given"), lines = {} }
		if (N(dr.gold) or 0) > 0 then s5.lines[1] = money(dr.gold) .. " taken" end
		if N(dr.bestHour) then s5.lines[#s5.lines + 1] = string.format("Best hour: %02d:00", dr.bestHour) end
		if (N(dr.helpers) or 0) > 0 then s5.lines[#s5.lines + 1] = dr.helpers .. (dr.helpers == 1 and " helper thanked" or " helpers thanked") end
		slides[#slides + 1] = s5
	end
	local sum = { kicker = (S(r.name) or "Month") .. " in short", big = "That's a wrap", lines = {}, summary = true }
	local nPlaces = N(r.places) or 0
	sum.lines[#sum.lines + 1] = rides .. (rides == 1 and " summon" or " summons") .. " · " .. nPlaces .. (nPlaces == 1 and " place" or " places")
	if saved >= 60 then sum.lines[#sum.lines + 1] = (r.about and "About " or "") .. duration(saved) .. " saved" end
	if S(r.topDriver) then sum.lines[#sum.lines + 1] = "Favourite driver: " .. r.topDriver end
	if r.capped then sum.lines[#sum.lines + 1] = "From your last 100 rides" end
	slides[#slides + 1] = sum
	return slides
end

---------------------------------------------------------------------------
-- The card, the chip
---------------------------------------------------------------------------

-- "Your October in Azeroth is ready" (324 x 96); card:SetMonth(y, m) fills it.
function Mod.Card(parent)
	local c = CreateFrame("Button", nil, parent)
	c:SetSize(INNER, 96)
	c.bg = T.Rounded(c, { 0.24, 0.13, 0.42, 1 }, 18, "BACKGROUND", 0)
	c.art = T.Tex(c, "gradient", "BACKGROUND", 1)
	c.art:SetPoint("TOPLEFT", c, "TOPLEFT", 4, -4)
	c.art:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -4, 4)
	c.art:SetVertexColor(T.RGB("glow", 0.25))
	c.kicker = T.Text(c, "caption", "muted", "LEFT", "bold")
	c.kicker:SetPoint("TOPLEFT", c, "TOPLEFT", 16, -14)
	c.kicker:SetText("Azeroth Wrapped") -- the feature's name keeps its capitals
	c.title = T.Text(c, "heading", "white", "LEFT", "bold")
	c.title:SetPoint("TOPLEFT", c, "TOPLEFT", 16, -32)
	c.title:SetWidth(INNER - 32)
	c.sub = T.Text(c, "sub", "muted", "LEFT", "regular")
	c.sub:SetPoint("TOPLEFT", c, "TOPLEFT", 16, -58)
	c.sub:SetWidth(INNER - 32)
	c.sub:SetText("Tap to see your month")
	c:RegisterForClicks("LeftButtonUp")
	T.Press(c, { fill = c.bg })
	safeScript(c, "OnClick", function(self) if self.year then Mod.Open(self.year, self.month) end end)
	T.Tip(c, "Azeroth Wrapped", "Your month in summons: places, time saved, your favourite driver. Tap to play it.")
	function c.SetMonth(self, y, m)
		self.year, self.month = y, m
		self.title:SetText("Your " .. W.Mod("Core.Wrapped").MonthName(m) .. " in Azeroth is ready")
	end
	c:Hide()
	return c
end

-- the small "Wrapped" chip: opens the newest of the last 6 months (right-click: the one before)
function Mod.Chip(parent)
	local c = CreateFrame("Button", nil, parent)
	c:SetSize(86, 26)
	c.tag = T.Tag(c, "Wrapped", { fill = { 0.24, 0.13, 0.42, 1 }, text = "white", h = 26, size = "caption", pad = 12, icon = "star", iconColour = "glow", iconSize = 12 })
	c.tag:SetPoint("RIGHT", c, "RIGHT", 0, 0)
	c.tag:EnableMouse(false)
	-- the button is as wide as the tag, so the whole chip (star end too) clicks and shows its tip
	c:SetWidth(N(c.tag:GetWidth()) or 86)
	c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	T.Press(c, { fill = c.tag.fill })
	safeScript(c, "OnClick", function(self, button)
		local list = Mod.Months()
		if #list == 0 then return end
		self.pick = button == "RightButton" and ((self.pick or 1) % #list) + 1 or 1
		local e = list[self.pick]
		Mod.Open(e.year, e.month)
	end)
	T.Tip(c, "Azeroth Wrapped", "Your months in summons. Click: the last month. Right-click: the months before (up to 6).")
	c:Hide()
	return c
end

---------------------------------------------------------------------------
-- The story
---------------------------------------------------------------------------

local function buildStory(host)
	local st = CreateFrame("Frame", nil, host)
	st:SetAllPoints(host)
	st:SetFrameLevel((N(host:GetFrameLevel()) or 0) + 30)
	st:EnableMouse(true)
	st.bg = st:CreateTexture(nil, "BACKGROUND")
	st.bg:SetColorTexture(NIGHT[1], NIGHT[2], NIGHT[3], NIGHT[4])
	st.bg:SetAllPoints(st)
	st.bars = {}
	st.close = T.RoundButton(st, "close", 30, "card")
	-- (design 2, C) the story is a pushed page: the cog hides, and its own x stands where the window's x does
	st.close:SetPoint("TOPRIGHT", st, "TOPRIGHT", -16, -13)
	if UI.HeadPush then
		UI.HeadPush(st)
		st:HookScript("OnShow", function() pcall(UI.HeadPush) end)
		st:HookScript("OnHide", function() pcall(UI.HeadPush) end)
	end
	st.close:SetFrameLevel((N(st:GetFrameLevel()) or 0) + 6)
	safeScript(st.close, "OnClick", function() Mod.Close() end)
	T.Tip(st.close, "Close", "Back to your trips.")
	-- the slide (moved by translation and alpha only)
	local sl = CreateFrame("Frame", nil, st)
	sl:SetPoint("TOPLEFT", st, "TOPLEFT", PAD, -70)
	sl:SetSize(INNER, 400)
	sl.kicker = T.Text(sl, "caption", "muted", "LEFT", "bold")
	sl.kicker:SetPoint("TOPLEFT", sl, "TOPLEFT", 0, -40)
	sl.kicker:SetWidth(INNER)
	sl.big = T.Text(sl, "display", "white", "LEFT", "bold")
	sl.big:SetPoint("TOPLEFT", sl, "TOPLEFT", 0, -62)
	sl.big:SetWidth(INNER)
	T.Lines(sl.big, 2)
	sl.lines = {}
	for i = 1, 5 do
		local l = T.Text(sl, "body", "muted", "LEFT", "medium")
		l:SetPoint("TOPLEFT", sl, "TOPLEFT", 0, -130 - (i - 1) * 26)
		l:SetWidth(INNER)
		sl.lines[i] = l
	end
	st.slide = sl
	-- tap halves: left = back, right = next; hovering pauses the clock
	local function half(side)
		local b = CreateFrame("Button", nil, st)
		b:SetPoint("TOP" .. side, st, "TOP" .. side, 0, -60)
		b:SetSize(180, 420)
		b:SetFrameLevel((N(st:GetFrameLevel()) or 0) + 2)
		b:RegisterForClicks("LeftButtonUp")
		safeScript(b, "OnEnter", function() st.paused = true end)
		safeScript(b, "OnLeave", function() st.paused = false end)
		safeScript(b, "OnClick", function() if side == "LEFT" then Mod.Prev() else Mod.Next() end end)
		T.Press(b)
		T.Tip(b, side == "LEFT" and "Back" or "Next", "Tap the left or right half to move through your month. Hover to pause.")
		return b
	end
	st.left, st.right = half("LEFT"), half("RIGHT")
	-- the share pill on the summary (UI.Share's secure button posts it on your click)
	st.share = T.Pill(st, "Share", "primary", INNER, 46)
	st.share:SetPoint("BOTTOMLEFT", st, "BOTTOMLEFT", PAD, PAD)
	st.share:SetFrameLevel((N(st:GetFrameLevel()) or 0) + 6)
	safeScript(st.share, "OnClick", function()
		UI.Toast(KitMod.inCombat() and "Share after combat" or "Join a group to share", "info")
	end)
	T.Tip(st.share, "Share", function() return st.shareLine and ("Posts to your group: \"" .. st.shareLine .. "\"") or "Posts one line to your party." end, "ANCHOR_TOP")
	st.share:Hide()
	if UI.Share and type(UI.Share.Register) == "function" then
		pcall(UI.Share.Register, st.share, function() return st:IsShown() and st.shareLine or nil end, { label = "Share", onShared = function()
			local d = wdb()
			if d and st.key then d.shared[st.key] = type(time) == "function" and time() or 0 end
			st.shareLine = nil
		end })
	end
	-- the clock (only while the story is shown)
	safeScript(st, "OnUpdate", function(_, elapsed)
		if st.paused or not st.slides then return end
		st.t = (st.t or 0) + (elapsed or 0)
		local bar = st.bars[st.index]
		if bar then bar.fill:SetWidth(math.max(1, bar.w * math.min(1, st.t / SLIDE_SECS))) end
		if st.t >= SLIDE_SECS and st.index < #st.slides then Mod.Next() end
	end)
	st:Hide()
	return st
end

local function showSlide(i, dir)
	local st = story
	local sl = st.slide
	st.index, st.t = i, 0
	local e = st.slides[i]
	sl.kicker:SetText(e.kicker)
	sl.big:SetText(e.big)
	for k, l in ipairs(sl.lines) do
		local text = e.lines[k]
		l:SetText(text or "")
		setShown(l, text ~= nil)
	end
	for k, bar in ipairs(st.bars) do
		bar.fill:SetWidth(k < i and bar.w or 1)
		bar.fill:SetAlpha(k <= i and 1 or 0)
	end
	-- the share pill on the summary: once a minute per month, in a group
	local d = wdb()
	local last = d and N(d.shared[st.key]) or nil
	local t = type(time) == "function" and time() or 0
	-- (AUD-183) a month of only driving has no rides as a rider: no line to share, so no Share pill
	local rode = (N(st.recap and st.recap.rides) or 0) > 0
	st.shareLine = (e.summary and rode and not (last and t - last < SHARE_GAP)) and Mod.ShareText(st.recap) or nil
	if UI.Share and UI.Share.Sync then W.Safe("share", UI.Share.Sync) end
	-- (round 9, C9) dock the secure share button now, not on the window's next tick
	if UI.SyncSecure then W.Safe("share", UI.SyncSecure) end
	if T.FxLevel() ~= "off" then A.SlideIn(sl, (dir or 1) * 30, 0.25) end
	syncSummary()
end

---------------------------------------------------------------------------
-- Unfolded: the month as a list in the Trips side pane, the current slide lit
---------------------------------------------------------------------------

local ROW = { h = 72, gap = 6, top = 60, max = 6 }

local function buildSummary(holder)
	local f = CreateFrame("Frame", nil, holder)
	f:SetAllPoints(holder)
	f:SetFrameLevel((N(holder:GetFrameLevel()) or 0) + 40)
	f:EnableMouse(true)
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetColorTexture(NIGHT[1], NIGHT[2], NIGHT[3], NIGHT[4])
	f.bg:SetAllPoints(f)
	f.head = T.Text(f, "heading", "white", "LEFT", "bold")
	f.head:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -22)
	f.head:SetWidth(INNER - 44)
	-- (I1) unfolded, the story's one x: here, at the window's right edge
	f.close = T.RoundButton(f, "close", 30, "card")
	f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -16)
	f.close:SetFrameLevel((N(f:GetFrameLevel()) or 0) + 6)
	safeScript(f.close, "OnClick", function() Mod.Close() end)
	T.Tip(f.close, "Close", "Back to your trips.")
	f.rows = {}
	for i = 1, ROW.max do
		local r = CreateFrame("Button", nil, f)
		r:SetSize(INNER, ROW.h)
		r:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(ROW.top + (i - 1) * (ROW.h + ROW.gap)))
		r.bg = T.Rounded(r, "card", 14, "BACKGROUND", 0)
		r.kicker = T.Text(r, "caption", "muted", "LEFT", "bold")
		r.kicker:SetPoint("TOPLEFT", r, "TOPLEFT", 14, -10)
		r.big = T.Text(r, "heading", "white", "LEFT", "bold")
		r.big:SetPoint("TOPLEFT", r, "TOPLEFT", 14, -26)
		r.big:SetWidth(INNER - 28)
		r.line = T.Text(r, "caption", "muted", "LEFT", "regular")
		r.line:SetPoint("TOPLEFT", r, "TOPLEFT", 14, -50)
		r.line:SetWidth(INNER - 28)
		r:RegisterForClicks("LeftButtonUp")
		T.Press(r, { fill = r.bg })
		safeScript(r, "OnClick", function(self)
			if story and story:IsShown() and self.index then showSlide(self.index, self.index >= (story.index or 1) and 1 or -1) end
		end)
		T.Tip(r, "Your month", "Shows this part of your month on the left.")
		r:Hide()
		f.rows[i] = r
	end
	f:Hide()
	return f
end

-- Shows the list while the story shows on an unfolded Trips page; hides it otherwise.
syncSummary = function()
	local tr = UI.trips
	local holder = tr and tr.wide and tr.side and tr.side.holder
	if not (holder and story and story:IsShown() and story.slides) then
		if summary then summary:Hide() end
		if story and story.close then story.close:SetShown(story:IsShown()) end
		coverTrips(story ~= nil and story:IsShown())
		return
	end
	story.close:Hide()
	coverTrips(true)
	summary = summary or buildSummary(holder)
	local name = story.recap and S(story.recap.name) or "month"
	summary.head:SetText("Your " .. name .. " in short")
	for i, row in ipairs(summary.rows) do
		local e = story.slides[i]
		if e then
			row.index = i
			row.kicker:SetText(e.kicker)
			row.big:SetText(e.big)
			row.line:SetText(e.lines and e.lines[1] or "")
			row.bg:SetColor(i == story.index and "raised" or "card")
			row:Show()
		else
			row:Hide()
		end
	end
	summary:Show()
end
function Mod.SyncSummary() syncSummary() end
-- (tests) the list, or nil before it was needed
function Mod.Summary() return summary end

-- Opens the story for a month over the Trips tab.
function Mod.Open(year, month)
	local tr = UI.trips
	local host = tr and tr.body
	if not host then return false end
	local r = recap(year, month)
	if not r then return false end
	story = story or buildStory(host)
	local st = story
	st.recap, st.key = r, string.format("%04d-%02d", year, month)
	st.slides = Mod.Slides(r)
	-- one progress bar per slide
	local n = #st.slides
	local gap = 4
	local w = (INNER - 40 - (n - 1) * gap) / n
	for i = 1, math.max(n, #st.bars) do
		local bar = st.bars[i]
		if not bar and i <= n then
			bar = CreateFrame("Frame", nil, st)
			bar:SetHeight(3)
			bar.track = T.PillFill(bar, "line", 3, "BACKGROUND", 0)
			bar.fill = CreateFrame("Frame", nil, bar)
			bar.fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
			bar.fill:SetHeight(3)
			T.PillFill(bar.fill, "white", 3, "ARTWORK", 0)
			st.bars[i] = bar
		end
		if bar then
			if i <= n then
				bar.w = w
				bar:SetWidth(w)
				bar:ClearAllPoints()
				bar:SetPoint("TOPLEFT", st, "TOPLEFT", PAD + (i - 1) * (w + gap), -5) -- above the header's buttons
				bar:Show()
			else
				bar:Hide()
			end
		end
	end
	st.paused = false
	st.close:Show()
	st:Show()
	if UI.SyncClose then UI.SyncClose() end -- (design 1, K) one x: the window's steps aside
	coverTrips(true)
	A.FadeIn(st, 0.2)
	showSlide(1)
	if UI.SyncSecure then UI.SyncSecure() end
	return true
end

function Mod.Close()
	if summary then summary:Hide() end
	coverTrips(false)
	if story then
		story.shareLine = nil
		story:Hide()
		if UI.Share and UI.Share.Sync then W.Safe("share", UI.Share.Sync) end
	end
	if UI.SyncClose then UI.SyncClose() end
	if UI.SyncSecure then UI.SyncSecure() end
end

function Mod.Shown() return story ~= nil and story:IsShown() end

function Mod.Next()
	if not Mod.Shown() then return end
	if story.index < #story.slides then showSlide(story.index + 1, 1) end
end

function Mod.Prev()
	if not Mod.Shown() then return end
	if story.index > 1 then showSlide(story.index - 1, -1) end
end

-- the open story (tests, the Fold's trips page): the overlay frame or nil
function Mod.Story() return story end
