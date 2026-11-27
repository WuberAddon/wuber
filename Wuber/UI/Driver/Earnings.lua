-- Module: UI.Driver.Earnings
-- Purpose: Earnings screen, the 24 h chart, best hours, the 7x24 heatmap (D.HeatGrid,
--   D.BuildHeatmap...), the crew's cut and the rainchecks given (the end-of-shift card is
--   UI.Driver.Sheets' since 2.3).
-- API: D.TopWindow, D.screens.earnings, D.HeatGrid, D.BuildHeatmap, D.HeatInfo, D.PaintHeatmap,
--   D.CutRows, D.CutFor, D.CutWords, D.CutRowWords, D.CutRuleText, D.RaincheckCounts, D.PaintCut,
--   D.PaintIou, D.FOLD.earnings
-- Internals: figureSize (the per-hour number steps hero, display, title until it fits its 160 px room), steady (the lit part of a choice: shown or hidden, never an alpha change), moreCue
--   ("Scroll for more" on narrow Earnings); hm.onResize (a heatmap card's owner re-lays out after a tap)
-- Uses: UI.Driver.Screens
-- Later: (none)
-- Events: SETTINGS
-- Standalone: no
-- Test: tests/ui/driver/earnings_test.lua
-- From: UI_Drive.lua 1458-2110 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Driver.Earnings", { "UI.Driver.Screens" })
local ScreensMod = W.Mod("UI.Driver.Screens")
local INNER, PAD, Screen, WIDTH = ScreensMod.INNER, ScreensMod.PAD, ScreensMod.Screen, ScreensMod.WIDTH
local call, dr, money, now = ScreensMod.call, ScreensMod.dr, ScreensMod.money, ScreensMod.now
local opts, plural, safeScript, setShown = ScreensMod.opts, ScreensMod.plural, ScreensMod.safeScript, ScreensMod.setShown
local st, toast = ScreensMod.st, ScreensMod.toast
local T = W.Theme

local DR = W.Drive
local D = W.Driver

local S, N = W.Str, W.Num

-- (design round 3) the big per-hour figure: the largest name on the scale whose text fits the room beside Me | Crew
local FIGURE_ROOM = 160
local function figureSize(figure)
	for _, name in ipairs({ "hero", "display" }) do
		if T.MeasureText(figure, name, "bold") * 1.08 <= FIGURE_ROOM then return name end
	end
	return "title"
end
Mod.figureSize = figureSize

local function adv() return type(W.Advanced) == "function" and W.Advanced() == true end

local function setOpt(key, v)
	local d = W.Drive
	if type(d) == "table" and type(d.SetOpt) == "function" then call(d.SetOpt, key, v) else opts()[key] = v end
	W.Fire("SETTINGS", "drive." .. key)
end

local eside -- (2.3) the earnings page's side pane, when it has unfolded once (D.FOLD.earnings)
local SIDE_W = 324 -- what fits in it at x PAD (18 px padding, as the rider's pages)

---------------------------------------------------------------------------
-- Earnings: tiles, the 24-hour chart, best hours, try these
---------------------------------------------------------------------------

local WDAY = { [0] = "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
local function dayName(n)
	n = N(n)
	if not n then return "?" end
	local names = type(DR.WDAYS) == "table" and DR.WDAYS or WDAY
	return S(names[n]) or WDAY[n % 7] or "?"
end
local ENOUGH = 30 -- open minutes a bar needs before it counts

-- (round 9, S2) money earned: never "free" (W.Money's word for a fare of nothing): nothing earned is "0g".
-- (design 1 H) in letters like W.Money, no coin icons
local function earned(copper)
	copper = math.max(0, math.floor((N(copper) or 0) + 0.5))
	return copper > 0 and W.Money(copper) or "0g"
end

local function gph(copper)
	copper = N(copper) or 0
	if copper >= 10000 then
		local g = copper / 10000
		return (g >= 10 and tostring(math.floor(g + 0.5)) or (("%.1f"):format(g):gsub("%.0$", ""))) .. "g"
	end
	if copper < 1 then return "0g" end
	return money(copper)
end

local function hoursText(minutes)
	minutes = N(minutes) or 0
	if minutes < 60 then return math.floor(minutes + 0.5) .. " min" end
	local h = minutes / 60
	return (h >= 10 and tostring(math.floor(h + 0.5)) or (("%.1f"):format(h):gsub("%.0$", ""))) .. " h"
end

local CHART_H, BAR_W, BAR_GAP = 96, 10, 3

-- (design round 4, F) a share 0..1 of the busiest hour -> a step of T.RAMP (stronger for more)
local function rampStep(k)
	local n = #T.RAMP
	return math.max(1, math.min(n, math.ceil((tonumber(k) or 0) * n - 1e-9)))
end

-- the two-word key of the ramp: "less" [four steps] "more", caption size, muted; the steps are the squares' own
-- colours. Returns the frame and its width; the caller places it.
local KEY = { less = "less", more = "more", sw = 10, gap = 2, pad = 6 }
function D.BuildRampKey(parent)
	local f = CreateFrame("Frame", nil, parent)
	f.less = T.Text(f, "caption", "muted", "LEFT", "regular")
	f.more = T.Text(f, "caption", "muted", "LEFT", "regular")
	f.less:SetText(KEY.less)
	f.more:SetText(KEY.more)
	local lw = math.ceil(T.MeasureText(KEY.less, "caption", "regular") * 1.08) + 2
	local mw = math.ceil(T.MeasureText(KEY.more, "caption", "regular") * 1.08) + 2
	f.less:SetWidth(lw)
	f.more:SetWidth(mw)
	f.less:SetPoint("LEFT", f, "LEFT", 0, 0)
	f.steps = {}
	local x = lw + KEY.pad
	for i = 1, #T.RAMP do
		local t = f:CreateTexture(nil, "ARTWORK")
		t:SetColorTexture(T.RampRGB(i))
		t:SetSize(KEY.sw, KEY.sw)
		t:SetPoint("LEFT", f, "LEFT", x, 0)
		f.steps[i] = t
		x = x + KEY.sw + KEY.gap
	end
	x = x - KEY.gap + KEY.pad
	f.more:SetPoint("LEFT", f, "LEFT", x, 0)
	f:SetSize(x + mw, 16)
	f.keyW = x + mw
	return f
end

-- the 24 bars of gold per open hour, by hour of the day, against the dashed target line
local function buildChart(s, ch, top)
	local box = CreateFrame("Frame", nil, ch)
	box:SetAllPoints(ch)
	ch.chartBox = box
	local left = math.floor((INNER - 24 * (BAR_W + BAR_GAP) + BAR_GAP) / 2)
	ch.base = top + CHART_H
	ch.bars = {}
	for h = 0, 23 do
		local b = CreateFrame("Frame", nil, box)
		b:SetSize(BAR_W, 4)
		b:SetPoint("BOTTOMLEFT", ch, "TOPLEFT", left + h * (BAR_W + BAR_GAP), -ch.base)
		b.fill = b:CreateTexture(nil, "ARTWORK")
		b.fill:SetTexture(T.MEDIA .. "rounded")
		b.fill:SetTexCoord(0.25, 0.75, 0, 0.5)
		b.fill:SetPoint("TOPLEFT", b, "TOPLEFT")
		b.fill:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT")
		b.fill:SetVertexColor(T.RampRGB(#T.RAMP))
		-- a bar under the target: its own paler fill, shown or hidden (never an alpha change)
		b.dim = b:CreateTexture(nil, "ARTWORK")
		b.dim:SetTexture(T.MEDIA .. "rounded")
		b.dim:SetTexCoord(0.25, 0.75, 0, 0.5)
		b.dim:SetAllPoints(b.fill)
		b.dim:SetVertexColor(T.RampRGB(2)) -- (design round 4, F) never shown: the ramp's step colours every bar
		b.dim:Hide()
		-- a lighter top (the mockup's gold gradient), alpha only
		b.shine = b:CreateTexture(nil, "ARTWORK", nil, 1)
		b.shine:SetTexture(T.MEDIA .. "fade")
		b.shine:SetTexCoord(0, 1, 1, 0)
		b.shine:SetPoint("TOPLEFT", b, "TOPLEFT")
		b.shine:SetPoint("TOPRIGHT", b, "TOPRIGHT")
		b.shine:SetHeight(4)
		b.shine:SetVertexColor(T.RGB("white", 0.12))
		-- hollow: an outline for hours with under 30 open minutes
		b.edges = {}
		for i = 1, 4 do
			local e = T.Line(b, "muted", 0.7, "ARTWORK")
			b.edges[i] = e
		end
		b.edges[1]:SetPoint("TOPLEFT", b, "TOPLEFT") b.edges[1]:SetPoint("TOPRIGHT", b, "TOPRIGHT") b.edges[1]:SetHeight(1)
		b.edges[2]:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT") b.edges[2]:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT") b.edges[2]:SetHeight(1)
		b.edges[3]:SetPoint("TOPLEFT", b, "TOPLEFT") b.edges[3]:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT") b.edges[3]:SetWidth(1)
		b.edges[4]:SetPoint("TOPRIGHT", b, "TOPRIGHT") b.edges[4]:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT") b.edges[4]:SetWidth(1)
		-- the hover area: the whole column
		local hit = CreateFrame("Frame", nil, box)
		hit:SetSize(BAR_W + BAR_GAP, CHART_H + 4)
		hit:SetPoint("BOTTOMLEFT", ch, "TOPLEFT", left + h * (BAR_W + BAR_GAP) - 1, -ch.base)
		hit:EnableMouse(true)
		hit.hour = h
		T.Tip(hit, function(self) return ("%02d:00-%02d:00"):format(self.hour, (self.hour + 1) % 24) end, function(self)
			local d = s.hours and s.hours[self.hour] or {}
			local open = N(d.open) or 0
			local parts = {}
			if open >= ENOUGH then
				parts[1] = gph((N(d.copper) or 0) / (open / 60)) .. " per open hour"
			elseif open > 0 then
				parts[1] = "not enough time open yet"
			else
				parts[1] = "never open at this hour"
			end
			parts[#parts + 1] = plural(N(d.rides) or 0, "ride")
			parts[#parts + 1] = hoursText(open) .. " open"
			parts[#parts + 1] = plural(N(d.asks) or 0, "rider", "riders") .. " asked"
			return table.concat(parts, " · ")
		end)
		b.hit = hit
		ch.bars[h] = b
	end
	-- the target line, dashed
	ch.target = {}
	for i = 0, 40 do
		local d = T.Line(box, "muted", 0.7, "OVERLAY")
		d:SetSize(5, 1)
		ch.target[i] = d
	end
	ch.left = left
	ch.targetText = T.Text(box, "caption", "muted", "RIGHT", "medium")
	ch.targetText:SetWidth(120)
	for _, h in ipairs({ 0, 6, 12, 18, 23 }) do
		local lbl = T.Text(box, "caption", "off", "CENTER", "medium")
		lbl:SetWidth(24)
		lbl:SetPoint("TOP", ch, "TOPLEFT", left + h * (BAR_W + BAR_GAP) + BAR_W / 2, -(ch.base + 5))
		lbl:SetText(("%02d"):format(h))
	end
	ch.legend = T.Text(box, "caption", "muted", "LEFT", "regular")
	ch.legend:SetPoint("TOPLEFT", ch, "TOPLEFT", 14, -(ch.base + 22))
	ch.key = D.BuildRampKey(box)
	ch.key:SetPoint("TOPRIGHT", ch, "TOPRIGHT", -14, -(ch.base + 21))
	ch.legend:SetWidth(INNER - 28 - ch.key.keyW - 8)
	ch.legend:SetText("Gold an hour, by time of day")
	ch.legendHit = CreateFrame("Frame", nil, box)
	ch.legendHit:SetPoint("TOPLEFT", ch, "TOPLEFT", 14, -(ch.base + 20))
	ch.legendHit:SetSize(INNER - 28 - ch.key.keyW - 8, 16)
	ch.legendHit:EnableMouse(true)
	T.Tip(ch.legendHit, "Gold an hour, by time of day", "Hollow: under 30 min open")
	return ch.base + 22 + 24
end

local function paintChart(s)
	local ch = s.dash
	local hours = s.hours or {}
	local target = N(opts().target) or 100000
	local top = target * 1.25
	for h = 0, 23 do
		local d = hours[h] or {}
		local open = N(d.open) or 0
		local per = open > 0 and (N(d.copper) or 0) / (open / 60) or 0
		if open >= ENOUGH and per > top then top = per end
	end
	top = math.max(top, 10000)
	local anyOpen = false
	for h = 0, 23 do
		local d = hours[h] or {}
		local b = ch.bars[h]
		local open = N(d.open) or 0
		local per = open > 0 and (N(d.copper) or 0) / (open / 60) or 0
		local hollow = open < ENOUGH
		local hgt = hollow and math.max(6, math.min(CHART_H, (open / ENOUGH) * 24)) or math.max(3, math.floor(CHART_H * per / top + 0.5))
		if open <= 0 then hgt = 2 end
		ch.hgts = ch.hgts or {}
		ch.hgts[h] = hgt
		b:SetHeight(hgt)
		local dim = not hollow and per < target
		anyOpen = anyOpen or open > 0
		setShown(b.fill, not hollow)
		setShown(b.dim, false) -- (design round 4, F) under the target is the dotted line's story, not a second colour
		setShown(b.shine, false)
		for _, e in ipairs(b.edges) do setShown(e, hollow and open > 0) end
		if not hollow then b.fill:SetVertexColor(T.RampRGB(rampStep(per / top))) end
		if open <= 0 then
			b.fill:Show()
			b.fill:SetVertexColor(T.RGB("line"))
		end
	end
	setShown(ch.key, anyOpen)
	local ty = ch.base - math.floor(CHART_H * target / top + 0.5)
	local width = 24 * (BAR_W + BAR_GAP)
	for i = 0, 40 do
		local d = ch.target[i]
		local x = i * 9
		d:ClearAllPoints()
		if x + 5 <= width then
			d:SetPoint("TOPLEFT", ch, "TOPLEFT", ch.left + x, -ty)
			d:Show()
		else
			d:Hide()
		end
	end
	-- (2.3.2, S4) the label sits over the end of the line with the lower bars: a bar taller than the
	-- line under the words would cut through them
	local lineH = ch.base - ty
	local function tallest(from, to)
		local m = 0
		for h = from, to do m = math.max(m, (ch.hgts and ch.hgts[h]) or 0) end
		return m
	end
	local cols = math.ceil(64 / (BAR_W + BAR_GAP))
	local rightHit, leftHit = tallest(24 - cols, 23), tallest(0, cols - 1)
	ch.targetText:ClearAllPoints()
	ch.targetText:SetText("target " .. gph(target))
	if rightHit > lineH and leftHit < rightHit then
		ch.targetText:SetJustifyH("LEFT")
		ch.targetText:SetPoint("BOTTOMLEFT", ch, "TOPLEFT", ch.left, -(ty - 2))
	else
		ch.targetText:SetJustifyH("RIGHT")
		ch.targetText:SetPoint("BOTTOMRIGHT", ch, "TOPLEFT", ch.left + width, -(ty - 2))
	end
end

local RANGES = { today = { 1, "Today" }, week = { 7, "7 days" }, month = { 30, "30 days" } }

local function since(range)
	if range == "today" then
		local t = N(call(time)) or 0
		local ok, d = pcall(date, "*t", t)
		if ok and type(d) == "table" then return t - ((N(d.hour) or 0) * 3600 + (N(d.min) or 0) * 60 + (N(d.sec) or 0)) end
		return t - 86400
	end
	return (N(call(time)) or 0) - RANGES[range][1] * 86400
end

---------------------------------------------------------------------------
-- (2.3) The clicker cut: each crew member's casts and clicks this shift
-- (Drive.Cut's DR.Cut() -> rows { name, key, casts, clicks, share }, rule), and (5.8) the
-- rainchecks this crew gave (Drive.Raincheck's DR.Rainchecks())
---------------------------------------------------------------------------

-- D.CutRows() -> rows { name, key, casts, clicks, share }, rule "clicks" | "equal", caster %
function D.CutRows()
	local raw, rule = dr("Cut")
	local out = {}
	if type(raw) == "table" then
		for _, x in ipairs(raw) do
			local name = type(x) == "table" and S(x.name)
			if name then
				out[#out + 1] = { name = name, key = S(x.key) or W.Key(name), casts = math.max(0, math.floor(N(x.casts) or 0)),
					clicks = math.max(0, math.floor(N(x.clicks) or 0)), share = N(x.share) }
			end
		end
	end
	local pct
	if type(rule) == "table" then rule, pct = S(rule.rule), N(rule.pct) end
	rule = S(rule) or S(opts().cutRule) or "clicks"
	pct = pct or N(opts().cutCaster) or 40
	return out, rule, math.max(0, math.min(100, math.floor(pct + 0.5)))
end

-- one member's casts and clicks this shift (nil when the ledger has nobody by that key)
function D.CutFor(key)
	key = S(key)
	if not key then return nil end
	for _, x in ipairs((D.CutRows())) do
		if x.key == key then return x.casts, x.clicks end
	end
	return nil
end

-- "2 casts · 9 clicks" (only the parts that aren't zero; "no clicks yet" when both are)
function D.CutWords(casts, clicks)
	casts, clicks = N(casts) or 0, N(clicks) or 0
	local bits = {}
	if casts > 0 then bits[#bits + 1] = plural(casts, "cast") end
	if clicks > 0 then bits[#bits + 1] = plural(clicks, "click") end
	if #bits == 0 then return "no clicks yet" end
	return table.concat(bits, " · ")
end

-- one row of the split card: "7 casts · 2 clicks · 1g 82s" (design 1 H: the money in letters, no coin icons);
-- too long for the room, the money alone rather than the row's font shrinking
local function rowMeasure(text) return T.MeasureText((text:gsub("|T.-|t", "0")), "sub", "regular") end
function D.CutRowWords(x, share, room)
	local money = share and (" · " .. earned(share)) or ""
	local full = D.CutWords(x.casts, x.clicks) .. money
	if not room or rowMeasure(full) * 1.04 <= room then return full end
	-- too long for the row: the coins alone, never cryptic short forms (the Shift complete card keeps the casts and clicks)
	if share then return (money:gsub("^ · ", "")) end
	return D.CutWords(x.casts, x.clicks)
end

-- the rule in small words
-- (round 13, I11) one "rest" only: the clickers' part is named, the leftover is "any silver left"
-- `rows` (optional, DR.Cut's rows): the line then says what DR.CutSplit did when nobody clicked or cast
function D.CutRuleText(rule, pct, rows, short)
	if type(rule) == "boolean" then
		short = rule
		rule = nil
	end
	local casts, clicks
	for _, r in ipairs(type(rows) == "table" and rows or {}) do
		if type(r) == "table" then casts, clicks = (casts or 0) + (N(r.casts) or 0), (clicks or 0) + (N(r.clicks) or 0) end
	end
	local tail = ", in whole silver; any silver left goes to the runner."
	if casts and casts + clicks <= 0 then return "Nobody cast or clicked, so it all goes to the runner." end
	if casts and rule ~= "equal" and clicks <= 0 then return "Nobody clicked, so casters share it all by casts" .. tail end
	if casts and rule ~= "equal" and casts <= 0 then return "Nobody cast, so clickers share it all by clicks" .. tail end
	if rule == "equal" then return "Everyone who cast or clicked gets the same, in whole silver; any silver left goes to the runner." end
	pct = math.max(0, math.min(100, math.floor((N(pct) or 40) + 0.5)))
	if short then return ("Casters %d%%, clickers %d%%."):format(pct, 100 - pct) end
	return ("Casters share %d%% by casts, clickers %d%% by clicks, in whole silver; any silver left goes to the runner."):format(pct, 100 - pct)
end

-- rainchecks given and used since `from` (time()); given is DR.RaincheckGiven (the rider accepted it:
-- active or used, or void after they took it; an offer still waiting, declined or lapsed is not)
function D.RaincheckCounts(from)
	local list = dr("Rainchecks")
	local given, used = 0, 0
	if type(list) ~= "table" then return 0, 0 end
	for _, e in pairs(list) do
		local at = type(e) == "table" and (N(e.issued) or N(e.at)) or nil
		if type(e) == "table" and (not from or not at or at >= from) and S(e.state) and dr("RaincheckGiven", e) == true then
			given = given + 1
			if e.state == "used" then used = used + 1 end
		end
	end
	return given, used
end

-- The best three hours in a row by gold per open hour (an hour of the day: s.hours), or nil.
function D.TopWindow(hours)
	if type(hours) ~= "table" then return nil end
	local best, bestH, bestPer
	for h = 0, 23 do
		local copper, open = 0, 0
		for k = 0, 2 do
			local d = hours[(h + k) % 24] or {}
			copper, open = copper + (N(d.copper) or 0), open + (N(d.open) or 0)
		end
		if open >= ENOUGH * 2 and copper > 0 then
			local per = copper / (open / 60)
			if not best or per > best then best, bestH, bestPer = per, h, per end
		end
	end
	return bestH, bestPer
end

-- a quiet chip under the heatmap ("Top window: 19:00-22:00")
local function chip(parent)
	local b = CreateFrame("Frame", nil, parent)
	b:SetSize(120, 30)
	-- (design round 4, F) the two tips under the heatmap are caption text (muted), not pills that look like buttons
	b.text = T.Text(b, "caption", "muted", "LEFT", "regular")
	b.text:SetPoint("LEFT", b, "LEFT", 2, 0)
	b:EnableMouse(true)
	-- (round 13, I18) the words are never held to a width ('Top window: 17:00-20:...' in a reviewer's
	-- shot): the chip is sized to them with room to spare
	function b.Set(self, text, colour)
		self.text:SetText(text)
		local wd = math.ceil(T.MeasureText(text, "caption", "regular") * 1.08) + 2
		self:SetWidth(wd + 6)
	end
	return b
end

-- (2.3) Earnings' Crew view: "This shift" with each member's casts and clicks
-- (made the first time there is something to show); returns the y under it
-- (unfolded: c is the side pane's content, and the card is s.cutW, 324 wide)
function D.PaintCut(s, c, y, crewView, shares)
	local rows = (crewView and adv()) and (D.CutRows()) or {}
	local wide = s.side ~= nil and c == s.side.content
	local key, w = wide and "cutW" or "cut", wide and SIDE_W or INNER
	local other = s[wide and "cut" or "cutW"]
	if other then other:Hide() end
	if #rows == 0 then
		if s[key] then s[key]:Hide() end
		return y
	end
	local card = s[key]
	if not card then
		card = T.Card(c, w, 60, { colour = "card", radius = 16, shadow = false })
		card.title = T.Text(card, "body", "white", "LEFT", "bold")
		card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -12)
		card.title:SetText("This shift")
		card.sub = T.Text(card, "caption", "muted", "RIGHT", "regular")
		card.sub:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -14)
		card.sub:SetWidth(w - 120)
		card.sub:SetText("casts and clicks")
		card.lines = {}
		card:EnableMouse(true)
		T.Tip(card, "This shift", "Who cast and who clicked the portal since you opened. Every crew window counts the same way, so you all see the same numbers.")
		s[key] = card
	end
	card.title:SetText(shares and "Fair split, this shift" or "This shift")
	card.sub:SetText(shares and "so far" or "casts and clicks")
	local ly = 36
	for i, x in ipairs(rows) do
		if i > 8 then break end
		local l = card.lines[i]
		if not l then
			l = { name = T.Text(card, "sub", "white", "LEFT", "bold"), what = T.Text(card, "sub", "muted", "RIGHT", "regular") }
			-- every row is drawn at sub (12), never shrunk to fit: no size steps in the fit
			l.name.wuberMin = T.SIZE.sub
			l.what.wuberMin = T.SIZE.sub
			card.lines[i] = l
		end
		local nm = x.key == W.myKey and "You" or W.Short(x.name)
		-- the name takes what it needs, the words and the money get the rest of the row
		local nameW = math.min(140, math.ceil(T.MeasureText(nm, "sub", "bold") * 1.08) + 6)
		l.name:SetWidth(nameW)
		l.what:SetWidth(w - 28 - nameW - 6)
		l.name:SetText(nm)
		l.what:SetText(D.CutRowWords(x, shares and N(x.share) and x.share or nil, w - 28 - nameW - 6))
		l.name:ClearAllPoints()
		l.name:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -ly)
		l.what:ClearAllPoints()
		l.what:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -ly)
		l.name:Show()
		l.what:Show()
		ly = ly + 20
	end
	for i = math.min(#rows, 8) + 1, #card.lines do
		card.lines[i].name:Hide()
		card.lines[i].what:Hide()
	end
	card:SetHeight(ly + 8)
	card:ClearAllPoints()
	card:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
	card:Show()
	return y + ly + 8 + 12
end

-- (2.3) "Rainchecks: given 2 · used 1" in the chosen range (only when any were given)
function D.PaintIou(s, c, y, from)
	if not adv() then
		if s.iou then s.iou:Hide() end
		return y
	end
	local given, used = D.RaincheckCounts(from)
	if given < 1 then
		if s.iou then s.iou:Hide() end
		return y
	end
	if not s.iou then
		s.iou = CreateFrame("Frame", nil, c)
		s.iou:SetSize(INNER, 20)
		s.iou.text = T.Text(s.iou, "caption", "muted", "LEFT", "medium")
		s.iou.text:SetPoint("LEFT", s.iou, "LEFT", 4, 0)
		s.iou.text:SetWidth(INNER - 8)
		s.iou:EnableMouse(true)
		T.Tip(s.iou, "Rainchecks", "One summon later at no charge, given instead of a refund when a paid ride failed before the rider arrived. Used: they rode on it.")
	end
	local w = (s.side ~= nil and c == s.side.content) and SIDE_W or INNER
	s.iou:SetWidth(w)
	s.iou.text:SetWidth(w - 8)
	s.iou.text:SetText("Rainchecks: given " .. given .. " · used " .. used)
	s.iou:ClearAllPoints()
	s.iou:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
	s.iou:Show()
	return y + 28
end

-- Today | 7 days | 30 days and Me | Crew: the chosen part is lit by its own opaque pill,
-- shown or hidden; the parts' own fills stay hidden. In the game (tour #47-#52) a part's fill kept the
-- alpha it was made with (T.Pill paints a clear part with alpha 0): Today stayed lit and 7 days clear
-- while the words, and the totals, said 7 days. So nothing lit here changes alpha: it shows or hides.
local function steady(seg)
	local h = (N(seg:GetHeight()) or 26) - 4
	for _, b in ipairs(seg.buttons) do
		b.fill:SetShown(false)
		b.lit = T.PillFill(b, "accent", h, "BACKGROUND", 1) -- (design 1) the chosen part is violet with ink words
	end
	function seg.Paint(self)
		for _, b in ipairs(self.buttons) do
			local on = b.value == self.value
			b.lit:SetShown(on)
			if on then b.lit:SetColor("accent") end
		end
	end
	local set = seg.SetValue
	function seg.SetValue(self, v)
		set(self, v)
		self:Paint()
	end
	local function paint() seg:Paint() end
	for _, b in ipairs(seg.buttons) do
		for _, ev in ipairs({ "OnEnter", "OnLeave", "OnMouseUp" }) do b:HookScript(ev, paint) end
	end
	seg:Paint()
	return seg
end

-- narrow Earnings is taller than its view: "Scroll for more" over the bottom
-- edge until the bottom is in view (the soft fade alone read as a cut-off pill). Never takes the mouse.
local dataVer = 0 -- bumped when anything the page's words come from changes (the lift's stamp)
for _, ev in ipairs({ "DRIVE", "DRIVE_CREW", "DRIVE_LOG", "DRIVE_PAID", "DRIVE_RANK", "SETTINGS" }) do W.Listen(ev, function() dataVer = dataVer + 1 end) end
local CUE_STRIP = 28 -- the cue's height (22) plus a gap, kept free at the view's bottom while it may show
-- the view's bottom edge never slices a text at the top of the page (the layout checker's
-- "clipped"): it ends just above the first text it would cut, so the rest waits whole below it. Positions are
-- from the content's top, so the scroll offset doesn't matter; shown, not visible: the page may be hidden yet. Returns how far the edge goes up (px).
local function sliceLift(content, view)
	local top = N(content:GetTop())
	if not top or view <= 0 then return 0 end
	local edge = view
	local function walk(f)
		for _, r in ipairs({ f:GetRegions() }) do
			local tx = r:GetObjectType() == "FontString" and r:IsShown() and r:GetText()
			local t, b = N(r:GetTop()), N(r:GetBottom())
			if type(tx) == "string" and tx:match("%S") and t and b and top - t < edge - 0.5 and top - b > edge + 0.5 then
				edge = top - t - 2
			end
		end
		for _, ch in ipairs({ f:GetChildren() }) do if ch:IsShown() then walk(ch) end end
	end
	for _ = 1, 4 do -- a lifted edge can land in a text above: again until it rests in a gap
		local was = edge
		walk(content)
		if edge == was then break end
	end
	return math.max(0, math.min(80, math.floor(view - edge + 0.5)))
end
-- (r50 H24-05) the cue's strip: kept only while a word or button (up to `bottom`, the last control's edge) lies below the view
local function applyStrip(s, c, bottom)
	local full = (N(s.scroll:GetHeight()) or 0) + (s.strip or 0)
	local need = full > 0 and bottom > full
	local strip = need and CUE_STRIP or 0
	-- and a little more when the edge would slice the heatmap's hour labels (or any text)
	if need then
		-- (speed) the lift walks every text on the page asking the layout for its edges; the page only moves when its data, words
		-- or sizes do, so the answer is kept under a stamp of what they are and asked again only when the stamp changes
		local iou, cut = s.iou, s.cutW or s.cut
		local heat = s.heatW or s.heat
		local stamp = table.concat({ dataVer, full, bottom, s.range, s.scope, tostring(adv()), tostring(c == (s.side and s.side.content)),
			tostring(s.stats:GetText()), tostring(s.topText), tostring(s.tryText), tostring(iou and iou:IsShown() and iou.text:GetText()),
			tostring(cut and cut:IsShown() and cut:GetHeight()), tostring(N(s.dash and s.dash:GetHeight())), tostring(heat and heat.picked),
			tostring(heat and N(heat:GetHeight())) }, "|")
		if s.liftStamp ~= stamp then
			s.liftValue = sliceLift(c, full - CUE_STRIP)
			-- a page the game has not placed yet (no top) answers 0: asked again next time, not kept
			s.liftStamp = N(c:GetTop()) and stamp or nil
		end
		strip = strip + (s.liftValue or 0)
	end
	if (s.strip or 0) ~= strip then
		s.strip = strip
		s.scroll:ClearAllPoints()
		s.scroll:SetPoint("TOPLEFT", s.frame, "TOPLEFT", 0, -s.scrollY)
		s.scroll:SetPoint("BOTTOMRIGHT", s.frame, "BOTTOMRIGHT", 0, 6 + strip)
	end
end
local function moreCue(s)
	local sc, cue = s.scroll, s.cue
	local lvl = (N(sc:GetFrameLevel()) or 1) + 45 -- above the list's soft edges (40)
	if N(cue:GetFrameLevel()) ~= lvl then cue:SetFrameLevel(lvl) end
	-- (HUNT-114) the Settings page slides over this screen and sits under the cue's level: no pill while it is open
	local over = D.PageOver("earnings")
	setShown(cue, not over and (s.strip or 0) > 0 and (N(sc.max) or 0) - (N(sc.offset) or 0) > 1)
end

D.screens.earnings = function(parent)
	local s = Screen(parent, "Earnings", nil, { bigTitle = true })
	st.screens.earnings = s
	s.range, s.scope = "today", "me"
	local c = s.content
	-- the dashboard: gold per open hour, the hours' bars
	local dash = T.Card(c, INNER, 300, { colour = "card", radius = 18, shadow = false })
	dash:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -2)
	s.dash = dash
	s.seg = T.Segmented(dash, {
		{ value = "today", label = "Today", tip = "Since midnight." },
		{ value = "week", label = "7 days", tip = "The last seven days." },
		{ value = "month", label = "30 days", tip = "The last thirty days." },
	}, "today", function(v) s.range = v s.update() end, 232, 26, { byLabel = true })
	s.seg:SetPoint("TOPLEFT", dash, "TOPLEFT", 12, -12)
	if D.CalmSegmented then D.CalmSegmented(s.seg) end
	steady(s.seg)
	s.who = T.Segmented(dash, {
		{ value = "me", label = "Me", tip = "Rides this character's window was paid for." },
		{ value = "crew", label = "Crew", tip = "Every ride your crew took, whoever was paid." },
	}, "me", function(v) s.scope = v s.update() end, 144, 30) -- (2.3.2, S4) 116 clipped "Crew" to "Cre..."
	s.who:SetPoint("TOPRIGHT", dash, "TOPRIGHT", -14, -54)
	if D.CalmSegmented then D.CalmSegmented(s.who) end
	steady(s.who)
	s.per = T.Text(dash, "hero", "gold", "LEFT", "bold")
	s.per:SetPoint("TOPLEFT", dash, "TOPLEFT", 14, -48)
	s.per:SetWidth(160)
	s.perSub = T.Text(dash, "sub", "muted", "LEFT", "regular")
	s.perSub:SetPoint("TOPLEFT", dash, "TOPLEFT", 15, -94)
	s.perSub:SetWidth(INNER - 30)
	s.stats = T.Text(dash, "caption", "white", "LEFT", "medium")
	s.stats:SetPoint("TOPLEFT", dash, "TOPLEFT", 15, -114)
	s.stats:SetWidth(INNER - 30)
	s.statsHit = CreateFrame("Frame", nil, dash)
	s.statsHit:SetPoint("TOPLEFT", dash, "TOPLEFT", 15, -112)
	s.statsHit:SetSize(INNER - 30, 18)
	s.statsHit:EnableMouse(true)
	T.Tip(s.statsHit, function() return s.stats:GetText() end, function()
		local tot = s.tot or {}
		local tips = N(tot.tips) or 0
		local parts = {}
		if tips > 0 then parts[#parts + 1] = earned(tips) .. " tips" end
		parts[#parts + 1] = plural(N(tot.asks) or 0, "rider", "riders") .. " asked"
		return table.concat(parts, " · ")
	end)
	dash:EnableMouse(true)
	T.Tip(dash, "Gold per open hour", function()
		local tot = s.tot or {}
		return "Gold earned divided by the hours you were open (not paused): the number to beat.\n\n"
			.. ("Riders seen asking: %d for your place, %d in all. Wuber requests: %d (%d declined). Most rival drivers online: %d.")
			:format(N(tot.match) or 0, N(tot.asks) or 0, N(tot.wreq) or 0, N(tot.wdec) or 0, N(tot.rivals) or 0)
	end)
	local h = buildChart(s, dash, 146)
	s.dashFullH = h
	dash:SetHeight(h)
	s.chart = dash
	-- the heatmap, then the top window and the quiet reset link
	s.heat = D.BuildHeatmap(c)
	s.heat:SetPoint("TOPLEFT", dash, "BOTTOMLEFT", 0, -12)
	s.heat.onResize = function() call(s.update) end -- a two-line tapped hour makes the card taller
	s.cue = CreateFrame("Frame", nil, s.frame)
	s.cue:SetSize(120, 22)
	s.cue:SetPoint("BOTTOM", s.frame, "BOTTOM", 0, 6)
	s.cue:EnableMouse(false)
	s.cue.fill = T.PillFill(s.cue, "panel", 22, "BACKGROUND", 0)
	s.cue.label = T.Text(s.cue, "caption", "muted", "CENTER", "medium")
	s.cue.label:SetPoint("CENTER", s.cue, "CENTER", 0, 0)
	s.cue.label:SetText("Scroll for more")
	s.cue:SetWidth(math.ceil(T.MeasureText("Scroll for more", "caption", "medium") * 1.08) + 26)
	s.cue:Hide()
	s.cueTick = CreateFrame("Frame", nil, s.frame)
	s.cueTick.wait = 0
	safeScript(s.cueTick, "OnUpdate", function(self, elapsed)
		self.wait = self.wait - (N(elapsed) or 0)
		if self.wait > 0 then return end
		self.wait = 0.2
		moreCue(s)
	end)
	s.top = chip(c)
	T.Tip(s.top, "Top window", "Your best three hours in a row, by gold per open hour. Open then.")
	s.try = chip(c)
	T.Tip(s.try, "Try this hour", "Riders asked for summons at this hour while you were closed.")
	s.reset = CreateFrame("Button", nil, c)
	s.reset:SetSize(84, 30)
	s.reset:RegisterForClicks("LeftButtonUp")
	s.reset.label = T.Text(s.reset, "sub", "muted", "RIGHT", "regular")
	s.reset.label:SetPoint("RIGHT", s.reset, "RIGHT", -2, 1)
	s.reset.label:SetWidth(120)
	s.reset.line = T.Line(s.reset, "muted", 0.7)
	s.reset.line:SetHeight(1)
	function s.reset.SetLabel(self, t)
		self.label:SetText(t)
		local wd = math.ceil(T.MeasureText(t, "sub", "regular")) + 2
		self.label:SetWidth(wd)
		self:SetWidth(wd + 4)
		self.line:ClearAllPoints()
		self.line:SetPoint("TOPRIGHT", self.label, "BOTTOMRIGHT", 0, -1)
		self.line:SetWidth(wd - 2)
	end
	s.reset:SetLabel("Reset stats")
	safeScript(s.reset, "OnEnter", function(self) self.label:SetTextColor(T.RGB("white")) end)
	safeScript(s.reset, "OnLeave", function(self) self.label:SetTextColor(T.RGB(s.sure and "amber" or "muted")) end)
	T.Press(s.reset)
	safeScript(s.reset, "OnClick", function()
		if not s.sure then
			s.sure = true
			s.reset:SetLabel("Click again to reset")
			s.reset.label:SetTextColor(T.RGB("amber"))
			W.After(4, function()
				s.sure = nil
				if s.reset.label.wuberText ~= "Reset stats" then
					s.reset:SetLabel("Reset stats")
					s.reset.label:SetTextColor(T.RGB("muted"))
				end
			end)
			return
		end
		s.sure = nil
		s.reset:SetLabel("Reset stats")
		s.reset.label:SetTextColor(T.RGB("muted"))
		-- (decisions N) Undo for 10 s: the counts taken away are kept only in the toast's undo
		local removed = dr("ResetStats")
		local UIm = W.UI
		if type(removed) == "table" and (removed.n or 0) > 0 and type(UIm.UndoToast) == "function" then
			UIm.UndoToast("Counts reset.", function()
				dr("RestoreStats", removed)
				s.update()
			end)
		elseif not (type(UIm.UndoPending) == "function" and UIm.UndoPending()) then
			toast("Counts reset", "info")
		end
		s.update()
	end)
	T.Tip(s.reset, "Reset stats", "Sets the counters of /wuber drive stats and of this session back to zero (click twice). The totals here come from the hour-by-hour log, which stays.")
	local targetTip = "The gold per open hour you aim for: the dotted line on the Earnings chart."
	local function getTarget() return N(opts().target) or 100000 end
	local tr = T.Card(c, INNER, 94, { colour = "card", radius = 14, shadow = false })
	tr.title = T.Text(tr, "body", "white", "LEFT", "bold")
	tr.title:SetPoint("TOPLEFT", tr, "TOPLEFT", 14, -10)
	tr.title:SetWidth(INNER - 28)
	tr.title:SetText("My target per hour")
	tr.desc = T.Text(tr, "caption", "muted", "LEFT", "regular")
	tr.desc:SetPoint("TOPLEFT", tr, "TOPLEFT", 14, -27)
	tr.desc:SetWidth(INNER - 28)
	tr.desc:SetText("for the Earnings chart")
	tr:EnableMouse(true)
	T.Tip(tr, "My target per hour", targetTip)
	-- (#264) the value's room is the widest value ("50g / hour") as the game draws it, about 6% over the font table, not a fixed 60
	local targetLabelW = math.max(60, math.ceil((N(T.MeasureText("50g / hour", "sub", "bold")) or 56) * 1.08) + 4)
	local sl = T.Slider(tr, INNER - 28, {
		labelW = targetLabelW,
		min = 10000, max = 500000, step = 10000, value = 100000, get = getTarget,
		format = function(v) return math.floor(v / 10000 + 0.5) .. "g / hour" end,
		onChange = function(v)
			setOpt("target", v)
			s.update()
		end,
	})
	sl.holder:SetPoint("TOPLEFT", tr, "TOPLEFT", 14, -44)
	T.Tip(sl, "My target per hour", targetTip)
	sl.get = getTarget
	tr:SetHeight(44 + (N(sl.holder:GetHeight()) or 40) + 10)
	s.target = sl
	s.targetRow = tr
	s.update = function()
		s.side = s.side or eside
		local isAdv = adv()
		-- the totals' period is s.range; the lit pill follows it in every path (a tap, the
		-- photo tour setting it, a fold, a tab coming back)
		if not RANGES[s.range] then s.range = "today" end
		if s.seg.value ~= s.range then s.seg:SetValue(s.range) else s.seg:Paint() end
		local days = RANGES[s.range][1]
		local crewN = 0
		local crew = dr("Crew")
		if type(crew) == "table" then for _, m in ipairs(crew) do if not m.me then crewN = crewN + 1 end end end
		setShown(s.who, isAdv and crewN > 0)
		if s.who.value ~= s.scope then s.who:SetValue(s.scope) else s.who:Paint() end
		local scope = crewN > 0 and s.scope or "me"
		local tot = dr("LogTotals", since(s.range), scope)
		tot = type(tot) == "table" and tot or {}
		s.tot = tot
		local hrs = dr("Hours", days, scope)
		s.hours = type(hrs) == "table" and hrs or {}
		local copper, open = N(tot.copper) or 0, N(tot.open) or 0
		local target = N(opts().target) or 100000
		local per = open >= 1 and copper / (open / 60) or nil
		-- (2.3.2, S4) the figure keeps clear of Me | Crew: a long one ("99s 99c", "1234g") is set smaller, not cut
		local figure = per and gph(per) or "-"
		T.SetFont(s.per, figureSize(figure), "bold")
		s.per:SetText(figure)
		s.per:SetTextColor(T.RGB(per and "gold" or "off"))
		s.perSub:SetText(per and ("an hour · " .. ((per >= target) and ("above your " .. gph(target) .. " target")
			or ("target " .. gph(target)))) or "an hour · open for a while to see it")
		s.stats:SetText(plural(N(tot.rides) or 0, "ride") .. " · " .. T.Code("gold") .. earned(copper) .. "|r · " .. hoursText(open) .. " open")
		setShown(dash.chartBox, isAdv)
		dash:SetHeight(isAdv and s.dashFullH or 144)
		if isAdv then paintChart(s) end
		-- (2.3) unfolded: the numbers stay left, the patterns go right (the heatmap,
		-- its chips, this shift's fair split, the rainchecks), 324 wide in the side pane
		local wide = isAdv and D.Wide("earnings") and s.side ~= nil
		if isAdv then
			if wide and not s.heatW then
				s.heatW = D.BuildHeatmap(s.side.content, SIDE_W)
				s.heatW:SetPoint("TOPLEFT", s.side.content, "TOPLEFT", PAD, -4)
				s.heatW.onResize = s.heat.onResize
			end
			local heat = wide and s.heatW or s.heat
			-- (round 13) folded and unfolded have a heatmap each: the square tapped last stays tapped
			local other = wide and s.heat or s.heatW
			if other and other.picked and (N(other.pickedAt) or 0) > (N(heat.pickedAt) or -1) then
				heat.picked = nil
				for _, b in ipairs(heat.cells) do
					if b.wday == other.picked.wday and b.hour == other.picked.hour then heat.picked = b end
				end
				heat.pickedAt = other.pickedAt
			end
			setShown(s.heat, not wide)
			if s.heatW then setShown(s.heatW, wide) end
			local heatData = D.PaintHeatmap(heat, math.max(days, 7), scope)
			s.Wide(wide)
			local rc = wide and s.side.content or c
			if s.rc ~= rc then
				s.rc = rc
				for _, f in pairs({ s.top, s.try, s.iou or false }) do if f then f:SetParent(rc) end end
			end
			-- the chips under the heatmap: the top window, the first busy hour you missed
			local y = (wide and 4 or (2 + (N(dash:GetHeight()) or 300) + 12)) + (N(heat:GetHeight()) or 200) + 12
			local th, tper = D.TopWindow(s.hours)
			if th then
				s.topText = ("Top window: %02d:00–%02d:00"):format(th, (th + 3) % 24)
				s.top:Set(s.topText, "white")
				T.RefreshTip(s.top)
			else
				s.topText = "Open a few hours to find your best ones"
				s.top:Set(s.topText, "muted")
			end
			s.top.per = tper
			s.top:ClearAllPoints()
			s.top:SetPoint("TOPLEFT", rc, "TOPLEFT", PAD, -y)
			-- (round 9, S13) nothing logged: the heatmap's own note says it; not again under it
			setShown(s.top, th ~= nil or heatData == true)
			local try = dr("TryHours", math.max(days, 7), 1)
			try = type(try) == "table" and try[1] or nil
			local x = PAD + (s.top:IsShown() and ((N(s.top:GetWidth()) or 120) + 6) or 0)
			if type(try) == "table" and N(try.hour) then
				s.tryText = "Try " .. dayName(try.wday) .. " " .. ("%02d:00"):format(N(try.hour))
				s.try:Set(s.tryText, "glow")
				-- both tips never run past the pane: the second goes under the first
				local tw = N(s.try:GetWidth()) or 100
				local edge = PAD + (wide and SIDE_W or INNER)
				local ty = y
				if x > PAD and x + tw > edge then x, ty, y = PAD, y + 36, y + 36 end
				s.try:ClearAllPoints()
				s.try:SetPoint("TOPLEFT", rc, "TOPLEFT", x, -ty)
				s.try:Show()
			else
				s.tryText = nil
				s.try:Hide()
			end
			if s.top:IsShown() or s.try:IsShown() then y = y + 40 end
			if wide then
				-- the target row and reset link stay with the numbers
				local ly = 2 + (N(dash:GetHeight()) or 300) + 12
				s.targetRow:ClearAllPoints()
				s.targetRow:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -ly)
				s.targetRow:Show()
				ly = ly + (N(s.targetRow:GetHeight()) or 94) + 8
				s.reset:ClearAllPoints()
				s.reset:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PAD - 2, -ly)
				s.reset:Show()
				-- (r50 H24-05) unfolded too: the cue's strip follows the real bottom (the reset link), not the padding
				applyStrip(s, c, ly + (N(s.reset:GetHeight()) or 30))
				s.scroll:SetContentHeight(ly + 40)
			end
			-- (2.3) the crew's casts and clicks this shift (Crew view; unfolded: always, with the
			-- shares), the rainchecks given
			-- (2.3.2, S4) folded too: the fair split with its shares, as unfolded
			y = D.PaintCut(s, rc, y, true, true)
			y = D.PaintIou(s, rc, y, since(s.range))
			if wide then
				s.side.scroll:SetContentHeight(y)
			else
				s.targetRow:ClearAllPoints()
				s.targetRow:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
				s.targetRow:Show()
				y = y + (N(s.targetRow:GetHeight()) or 94) + 8
				s.reset:ClearAllPoints()
				s.reset:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PAD - 2, -y)
				s.reset:Show()
				y = y + 40
				-- taller than the view: the view gives up a strip at its bottom for the cue (the cue
				-- lives in it, so nothing is drawn under the pill); it stays while the page is taller than the view
				applyStrip(s, c, y - 40 + (N(s.reset:GetHeight()) or 30))
				s.scroll:SetContentHeight(y)
			end
		else
			setShown(s.heat, false)
			if s.heatW then setShown(s.heatW, false) end
			s.Wide(false)
			s.top:Hide()
			s.try:Hide()
			s.targetRow:Hide()
			s.reset:Hide()
			D.PaintCut(s, c, 0, false, true)
			D.PaintIou(s, c, 0, since(s.range))
			local y = 2 + (N(dash:GetHeight()) or 144) + 12
			if (s.strip or 0) ~= 0 then
				s.strip = 0
				s.scroll:ClearAllPoints()
				s.scroll:SetPoint("TOPLEFT", s.frame, "TOPLEFT", 0, -s.scrollY)
				s.scroll:SetPoint("BOTTOMRIGHT", s.frame, "BOTTOMRIGHT", 0, 6)
			end
			s.scroll:SetContentHeight(y)
		end
		moreCue(s)
	end
	return s
end

-- (2.3) the earnings page's side pane (made the first time it unfolds)

D.FOLD.earnings = {
	build = function(holder)
		if eside or type(D.SidePane) ~= "function" then return end
		eside = D.SidePane(holder)
		local e = st.screens.earnings
		if e then e.side = eside end
	end,
	layout = function(unfolded)
		D.wide.earnings = unfolded == true
		local e = st.screens.earnings
		if e then
			e.side = e.side or eside
			if e.update then call(e.update) end
		end
	end,
}

W.Listen("SETTINGS", function(key)
	if key ~= nil and key ~= "advanced" and key ~= "drive.target" then return end
	local e = st.screens.earnings
	if e and e.update then call(e.update) end
end)

---------------------------------------------------------------------------
-- The heatmap (review #28): when you earn, by weekday and hour (7 x 24 squares of gold per
-- open hour, from B's DR.Heatmap(days)); tap a square for its numbers. In the game, nothing
-- to install.
---------------------------------------------------------------------------

local HM_LEFT, HM_CELL, HM_GAP = 36, 15, 1
-- the heatmap's tip: the original sentence with only the colour words changed (one local so it can be swapped)
local HEAT_TIP = "Each square is one hour of one weekday: the stronger the violet, the more you earned per hour open. "
	.. "Outlined squares: riders asked while you were closed. Tap a square for its numbers."
local PILL_PAD = 14 -- the tapped hour's words to its pill's ends
local HM_ORDER = { 1, 2, 3, 4, 5, 6, 0 } -- Mon .. Sun (wday 0 = Sunday, as DR.WDAYS)
local HM_DAYS = { [0] = "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

-- DR.Heatmap's answer as grid[wday][hour] = { copper, rides, open, asks }; also takes a flat
-- list of slots ({ wday, hour, ... }, as DR.BestHours' slots). nil when there is none.
function D.HeatGrid(days, scope)
	local raw = dr("Heatmap", days, scope)
	if type(raw) ~= "table" then return nil end
	local grid = {}
	for w = 0, 6 do grid[w] = {} end
	local any = false
	local function put(w, h, e)
		w, h = N(w), N(h)
		if not (w and h and grid[w] and h >= 0 and h <= 23 and type(e) == "table") then return end
		local cell = { copper = N(e.copper) or 0, rides = N(e.rides) or 0, open = N(e.open) or 0, asks = N(e.asks) or 0 }
		grid[w][h] = cell
		if cell.open > 0 or cell.rides > 0 or cell.asks > 0 then any = true end
	end
	for k, row in pairs(raw) do
		if type(row) == "table" and N(row.wday) and N(row.hour) then
			put(row.wday, row.hour, row)
		elseif type(row) == "table" and N(k) and N(k) <= 7 then
			for h, e in pairs(row) do put(N(k) == 7 and 0 or k, h, e) end
		end
	end
	return any and grid or nil
end

-- the tapped square's white frame glides to it (position only, 0.12 s)
local function glide(hm, cell)
	local sel = hm.sel
	sel:SetScript("OnUpdate", nil) -- a glide still running must not carry on from an older square
	if not cell then sel:Hide() return end
	local x1 = HM_LEFT + cell.hour * hm.cw - 1
	local y1 = hm.top + cell.row * (HM_CELL + HM_GAP) - 1
	local x0, y0 = sel.x or x1, sel.y or y1
	if not sel:IsShown() then x0, y0 = x1, y1 end
	-- above the squares, whatever levels the scroll frame gave them since
	sel:SetFrameLevel((N(cell:GetFrameLevel()) or 1) + 3)
	sel:Show()
	local t0 = now()
	local function at(p)
		sel.x, sel.y = x0 + (x1 - x0) * p, y0 + (y1 - y0) * p
		sel:ClearAllPoints()
		sel:SetPoint("TOPLEFT", hm, "TOPLEFT", sel.x, -sel.y)
	end
	at(0)
	if x0 == x1 and y0 == y1 then return end
	safeScript(sel, "OnUpdate", function(self)
		local p = (now() - t0) / 0.12
		if p >= 1 then
			at(1)
			self:SetScript("OnUpdate", nil)
		else
			at(p)
		end
	end)
end

function D.BuildHeatmap(parent, w)
	w = N(w) or INNER
	local hm = T.Card(parent, w, 196, { colour = "card", radius = 18, shadow = false })
	hm.title = T.Text(hm, "body", "white", "LEFT", "bold")
	hm.title:SetPoint("TOPLEFT", hm, "TOPLEFT", 14, -14)
	hm.title:SetWidth(w - 118)
	hm.title:SetText("Best hours, last 7 days")
	hm.sub = T.Text(hm, "caption", "muted", "RIGHT", "regular")
	hm.sub:SetPoint("TOPRIGHT", hm, "TOPRIGHT", -14, -16)
	hm.sub:SetWidth(84)
	local cw = math.floor((w - HM_LEFT - 14) / 24) -- 12 px columns on the 340 px card
	hm.cw = cw
	hm.cells, hm.days = {}, {}
	local top = 40
	hm.top = top
	local function pick(cell)
		if not hm.grid then return end -- nothing logged yet: no frame, no pill
		hm.picked, hm.pickedAt = cell, now()
		glide(hm, cell)
		-- a two-line pill makes the card taller: what sits under it moves down
		if D.HeatInfo(hm, cell) then
			if hm.onResize then hm.onResize(hm) elseif D.Refresh then call(D.Refresh, true) end
		end
	end
	for i, wd in ipairs(HM_ORDER) do
		local l = T.Text(hm, "caption", "muted", "RIGHT", "medium")
		l:SetPoint("RIGHT", hm, "TOPLEFT", HM_LEFT - 5, -(top + (i - 1) * (HM_CELL + HM_GAP) + HM_CELL / 2))
		l:SetText(HM_DAYS[wd])
		hm.days[i] = l
		for h = 0, 23 do
			local b = CreateFrame("Button", nil, hm)
			b:SetSize(cw - HM_GAP, HM_CELL)
			b:SetPoint("TOPLEFT", hm, "TOPLEFT", HM_LEFT + h * cw, -(top + (i - 1) * (HM_CELL + HM_GAP)))
			b:RegisterForClicks("LeftButtonUp")
			b.fill = b:CreateTexture(nil, "ARTWORK")
			b.fill:SetAllPoints(b)
			b.fill:SetColorTexture(T.RGB("panel"))
			b.wday, b.hour, b.row = wd, h, i - 1
			T.Press(b)
			safeScript(b, "OnClick", pick)
			b.wuberNoTip = true
			hm.cells[#hm.cells + 1] = b
		end
	end
	-- the tapped square: a white frame (four lines) that glides from square to square
	local sel = CreateFrame("Frame", nil, hm)
	sel:SetSize(cw - HM_GAP + 2, HM_CELL + 2)
	sel:SetFrameLevel((N(hm:GetFrameLevel()) or 1) + 5)
	for i = 1, 4 do
		local e = sel:CreateTexture(nil, "OVERLAY")
		e:SetColorTexture(T.RGB("white"))
		local a, b = ({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } })[i][1],
			({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } })[i][2]
		e:SetPoint(a, sel, a)
		e:SetPoint(b, sel, b)
		if i <= 2 then e:SetHeight(1.5) else e:SetWidth(1.5) end
	end
	sel:Hide()
	hm.sel = sel
	local gy = top + 7 * (HM_CELL + HM_GAP) + 3
	hm.hours = {}
	for _, h in ipairs({ 0, 6, 12, 18, 23 }) do
		local t = T.Text(hm, "caption", "off", "CENTER", "medium")
		t:SetPoint("TOP", hm, "TOPLEFT", HM_LEFT + h * cw + cw / 2, -gy)
		t:SetText(("%02d"):format(h))
		hm.hours[#hm.hours + 1] = t
	end
	-- the numbers of the tapped square, in a violet pill under the grid
	hm.pill = CreateFrame("Frame", nil, hm)
	hm.pill:SetSize(200, 28)
	hm.pill.x = HM_LEFT + 12 * cw - 6 -- its centre, from the card's left
	hm.pill:SetPoint("TOP", hm, "TOPLEFT", hm.pill.x, -(gy + 18))
	hm.pill.fill = T.PillFill(hm.pill, { T.RGB("accent", 0.3) }, 28, "BACKGROUND", 0) -- its alpha from the start
	hm.info = T.Text(hm.pill, "caption", "white", "CENTER", "medium")
	hm.info:SetPoint("LEFT", hm.pill, "LEFT", PILL_PAD, 0)
	hm.info:SetPoint("RIGHT", hm.pill, "RIGHT", -PILL_PAD, 0)
	T.Lines(hm.info, 2)
	-- nothing logged yet: a note in a pill over the dark squares (its own frame, above them)
	-- (round 9, S13) centred on the squares (not the card: the day names are left of them), inside them
	local gridW = 24 * cw - HM_GAP
	hm.empty = CreateFrame("Frame", nil, hm)
	hm.empty:SetSize(gridW - 12, 44)
	hm.empty:SetPoint("CENTER", hm, "TOPLEFT", HM_LEFT + gridW / 2, -(top + 3.5 * (HM_CELL + HM_GAP) - HM_GAP / 2))
	hm.empty.fill = T.Rounded(hm.empty, { T.RGB("hover", 0.96) }, 14, "BACKGROUND", 0) -- its alpha from the start
	hm.empty.text = T.Text(hm.empty, "caption", "muted", "CENTER", "regular")
	hm.empty.text:SetPoint("CENTER", hm.empty, "CENTER", 0, 0)
	hm.empty.text:SetWidth(gridW - 36) -- its own width: it wraps in two even before its card is placed
	T.Lines(hm.empty.text, 2)
	hm.empty.text:SetText("Open for a few hours and your best times light up here.")
	hm:EnableMouse(true)
	T.Tip(hm, "Peak hours", HEAT_TIP)
	hm.key = D.BuildRampKey(hm)
	hm.key:SetPoint("BOTTOMRIGHT", hm, "BOTTOMRIGHT", -14, 12)
	hm.baseH = gy + 18 + 28 + 14 + 18
	hm:SetHeight(hm.baseH)
	return hm
end

-- the pill under the grid for a square (or a hint when none is tapped); it fits its words
-- (BRIEF19 F6, tour #49, #50: "asked" squeezed onto a second line, "6 buyers..." cut) one line when
-- they fit, else two even lines in a taller pill with room round them; the card grows to hold it.
-- Returns true when the card's height changed.
local HEAT_ENOUGH = 30 -- open minutes an hour needs before its rate means anything (as Drive.Log's best-hours list)

function D.HeatInfo(hm, cell)
	local e = cell and hm.grid and hm.grid[cell.wday] and hm.grid[cell.wday][cell.hour]
	local text, bits
	if not cell then
		text = hm.grid and "Tap a square for its numbers." or ""
	else
		local when = HM_DAYS[cell.wday] .. " " .. ("%02d:00"):format(cell.hour)
		if not e or (e.open <= 0 and e.rides <= 0 and e.asks <= 0) then
			text = when .. " · nothing yet"
		else
			bits = { when }
			if e.open >= HEAT_ENOUGH then bits[#bits + 1] = gph(e.copper / (e.open / 60)) .. "/h" end -- (round 13) as the chart's "g/h"
			bits[#bits + 1] = plural(e.rides, "ride")
			bits[#bits + 1] = "open " .. hoursText(e.open)
			if e.asks > 0 then bits[#bits + 1] = plural(e.asks, "rider") .. " asked" end
			text = table.concat(bits, " · ")
		end
	end
	local cardW = N(hm:GetWidth()) or INNER
	local cx = N(hm.pill.x) or cardW / 2
	local room = 2 * math.min(cx, cardW - cx) - 16 - 2 * PILL_PAD -- the words' width: 8 px clear of the card each side
	local function measure(t) return math.ceil(T.MeasureText(t, "caption", "medium") * 1.08) end
	local need, two = measure(text), false
	if need > room and bits and #bits > 1 then
		local best
		for k = 1, #bits - 1 do
			local a, b = table.concat(bits, " · ", 1, k), table.concat(bits, " · ", k + 1)
			local m = math.max(measure(a), measure(b))
			if not best or m < best then best, text = m, a .. "\n" .. b end
		end
		need, two = best, true
	end
	local h = two and 44 or 28
	hm.pill:SetHeight(h)
	hm.pill.fill:SetHeight(h)
	hm.pill:SetWidth(math.min(room, need) + 2 * PILL_PAD) -- sized first, so the text's fit measures the new width
	-- (design round 4, F) the hint ("Tap a square for its numbers.") is caption text, no pill; a tapped square's numbers keep theirs
	hm.pill.fill:SetShown(cell ~= nil)
	hm.info:SetTextColor(T.RGB(cell and "white" or "muted"))
	hm.info:SetText(text)
	setShown(hm.pill, text ~= "")
	local cardH = (N(hm.baseH) or 0) + (two and 16 or 0)
	local grew = math.abs((N(hm:GetHeight()) or 0) - cardH) > 0.5
	if hm.baseH then hm:SetHeight(cardH) end
	return grew
end

-- a square's colour: a step of the violet ramp (T.RampRGB) by gold per open hour, dark where nothing happened;
-- an hour open under HEAT_ENOUGH that took gold stays at the faintest step (it never sets the strongest square).
-- An hour when buyers asked while you were closed (and took no gold) is not a step: the empty square's fill
-- and a fifth return, true, for the caller's violet outline (design round 4, F2).
local function heatColour(e, best)
	local short = e and e.open >= 1 and e.open < HEAT_ENOUGH and e.copper > 0
	if e and e.open < 1 and e.copper > 0 then -- took gold: earning wins, the faintest step
		local r, g, b = T.RampRGB(1)
		return r, g, b, 1
	end
	if short or (e and e.open >= HEAT_ENOUGH and best > 0 and e.copper > 0) then
		local k = short and 0 or math.min(1, (e.copper / (e.open / 60)) / best)
		local r, g, b = T.RampRGB(rampStep(k))
		return r, g, b, 1
	elseif e and e.asks > 0 and e.open < 1 then -- (HUNT-16) asks while closed: outlined, no fill
		local r, g, b = T.RGB("panel")
		return r, g, b, 1, true
	elseif e and e.open >= 1 then
		local r, g, b = T.RGB("raised")
		return r, g, b, 1
	end
	return T.RGB("panel")
end

function D.PaintHeatmap(hm, days, scope)
	local grid = D.HeatGrid(days, scope)
	hm.grid = grid
	hm.title:SetText("Best hours, last " .. days .. " days")
	hm.sub:SetText("tap a square")
	local best, bestCell = 0, nil
	if grid then
		for _, row in pairs(grid) do
			for _, e in pairs(row) do
				if e.open >= HEAT_ENOUGH then best = math.max(best, e.copper / (e.open / 60)) end
			end
		end
	end
	for _, b in ipairs(hm.cells) do
		local e = grid and grid[b.wday] and grid[b.wday][b.hour]
		local r, g, bl, al, outlined = heatColour(e, best)
		b.fill:SetColorTexture(r, g, bl, al)
		if outlined and not b.edge then b.edge = T.Outline(b, "accent", 1) end
		if b.edge then b.edge:SetShown(outlined == true) end
		if e and e.open >= HEAT_ENOUGH and best > 0 and e.copper / (e.open / 60) >= best and not bestCell then bestCell = b end
	end
	setShown(hm.empty, grid == nil)
	setShown(hm.key, grid ~= nil)
	if grid == nil then
		hm.empty:SetFrameLevel((N(hm.cells[1]:GetFrameLevel()) or 1) + 3) -- above the squares
		-- nothing to tap: no frame, no numbers pill
		hm.picked = nil
		glide(hm, nil)
	end
	if hm.picked then glide(hm, hm.picked) end
	if hm.picked then D.HeatInfo(hm, hm.picked) else D.HeatInfo(hm, nil) end
	hm.bestCell = bestCell
	return grid ~= nil
end
