-- Module: UI.FlightPins
-- Purpose: Summon price tags on the flight master's map (TaxiFrame or FlightMapFrame): a marker centred on each
--   flight point an open driver summons to, and a clickable price tag beside it. Neither is drawn over Wuber's
--   window (a marker whose ring meets it is hidden; a tag steps to a clear side, else hides).
-- API: Mod.Refresh, Mod.Hide, Mod.Pins, Mod.Why
-- Internals: mapFrame, aboveStrata, anyNodePlaced, rectOf, hits, hitsAny, onScreen, shownRect, windowRects, shortName, placeKey, driverName,
--   tooltipLine, openDriver, getHolder, buildMarker, buildTag, placeTag, onOpen, onResize, onHidden, onWinChange,
--   onWinResize, hookWin (hooks the window, phone, status bar, pill and Wuber's small frames), windowRects (the shown Wuber rectangles), hookMaps
-- Uses: UI.Kit
-- Later: UI.Map.Pins (Mod.Aura)
-- Events: listens On TAXIMAP_OPENED, On TAXIMAP_CLOSED, On ADDON_LOADED, On PLAYER_LOGIN, On PLAYER_ENTERING_WORLD,
--   Listen FOLD, Listen PAGE (the window moved or changed shape: place the tags again), Listen NEWS_MOVED; fires (none)
-- Standalone: no
-- Test: tests/v24/flightpins_test.lua
-- From: new in Wuber 2.4 (part 4)

local _, W = ...
local Mod = W.Module("UI.FlightPins", { "UI.Kit" })
local KitMod = W.Mod("UI.Kit")
local N = KitMod.N
local S = KitMod.S
local call = KitMod.call
local money = KitMod.money
local myKey = KitMod.myKey
local safeScript = KitMod.safeScript
local T = W.Theme
local UI = W.UI

local MEDIA = "Interface\\AddOns\\Wuber\\Media\\"
local CFG = {
	markerInner = 14,
	markerSize = 38,
	markerHalf = 19,
	btnHalf = 9,
	tagMinW = 32,
	tagH = 18,
	tagPadX = 6,
	tagGap = 4,
	hitPad = 1,
	check = 0.25, -- (r49 D) how often the map watch looks at the Wuber frames: the mini card follows the window a moment after a fold
	levelOffset = 20,
	ringChrome = 24, -- the aura frame is its inner size plus this (Pins.lua ApplyAuraSizes)
	ringMinInner = 4, -- a ring smaller than this is not drawn
}

local holder
local pool = {}
local active = {}
local watchToken, openToken, resizePending, winResizePending, lastWinKey
local hooked = {}
local winHooked = {}
local hookWin
local MAP_NAMES = { "TaxiFrame", "FlightMapFrame" }
local REFRESH_AFTER = { 0.1, 0.5, 1 } -- (run 1, item 3) Daylight UI re-lays the map out after it shows

-- The game's flight map that is showing: TaxiFrame, else the newer FlightMapFrame (as UI.Bird).
local function mapFrame()
	for _, name in ipairs(MAP_NAMES) do
		local f = _G[name]
		if type(f) == "table" and type(f.IsShown) == "function" and W.Plain(call(f.IsShown, f)) == true then return f end
	end
	return nil
end

local STRATA_UP = { BACKGROUND = "LOW", LOW = "MEDIUM", MEDIUM = "HIGH", HIGH = "DIALOG", DIALOG = "FULLSCREEN",
	FULLSCREEN = "FULLSCREEN_DIALOG", FULLSCREEN_DIALOG = "TOOLTIP", TOOLTIP = "TOOLTIP" }
-- One strata above the map's, so a skin's art on the map (Daylight UI) never covers the tags.
local function aboveStrata(strata) return STRATA_UP[strata] or "HIGH" end

-- A frame's rectangle in UIParent units (l, r, t, b), or nil when it cannot be read.
local function rectOf(f)
	if type(f) ~= "table" or type(f.GetLeft) ~= "function" then return nil end
	local l, r, t, b = N((call(f.GetLeft, f))), N((call(f.GetRight, f))), N((call(f.GetTop, f))), N((call(f.GetBottom, f)))
	if not (l and r and t and b) then return nil end
	local fs = N((call(f.GetEffectiveScale, f))) or 1
	local us = N((call(UIParent.GetEffectiveScale, UIParent))) or 1
	local k = us > 0 and fs / us or 1
	return { l = l * k, r = r * k, t = t * k, b = b * k }
end

local function hits(a, b, pad)
	local p = pad or 0
	return a.l < b.r + p and b.l < a.r + p and a.b < b.t + p and b.b < a.t + p
end

local function hitsAny(rect, list, pad)
	for i = 1, #list do
		if hits(rect, list[i], pad) then return true end
	end
	return false
end

local function onScreen(rect, sw, sh)
	if sw <= 0 or sh <= 0 then return true end
	return rect.l >= 0 and rect.r <= sw and rect.b >= 0 and rect.t <= sh
end

-- (r49 D) Every shown Wuber frame a pin must not lie over: the window (whichever of win, phone, top shows) and the
-- small named frames the player sees beside it (the drive button and its mini card, the crew offer, the bell, the news card).
local WUBER_FRAMES = { "WuberDriveButton", "WuberDriveMini", "WuberDriveFrame", "WuberInFlight", "WuberNewsCard", "WuberCrewOffer", "WuberBell" }

local function shownRect(f)
	if type(f) ~= "table" or type(f.IsVisible) ~= "function" then return nil end
	if W.Plain(call(f.IsVisible, f)) ~= true then return nil end
	local r = rectOf(f)
	if not r or r.r <= r.l or r.t <= r.b then return nil end
	return r
end

local function windowRects()
	local ui = KitMod.ui
	local out = {}
	if type(ui) == "table" then
		for _, f in ipairs({ ui.win, ui.phone, ui.top }) do
			local r = shownRect(f)
			if r then out[#out + 1] = r end
		end
	end
	for _, name in ipairs(WUBER_FRAMES) do
		local r = shownRect(rawget(_G, name))
		if r then out[#out + 1] = r end
	end
	return out
end

local function winRectKey(list)
	local parts = {}
	for i = 1, #(list or {}) do
		local r = list[i]
		parts[i] = math.floor(r.l + 0.5) .. "," .. math.floor(r.r + 0.5) .. "," .. math.floor(r.b + 0.5) .. "," .. math.floor(r.t + 0.5)
	end
	return table.concat(parts, ";")
end

-- Strips the ", <Zone>" suffix from a taxi node name and trims whitespace.
local function shortName(raw)
	local s = S(raw)
	if not s then return nil end
	local head = s:match("^([^,]+)") or s
	head = head:match("^%s*(.-)%s*$")
	if head == "" then return nil end
	return head
end

-- Canonical place key used to match a driver's destination against a flight point name.
local function placeKey(raw)
	local head = shortName(raw)
	if not head then return nil end
	local p = type(W.FindPlace) == "function" and call(W.FindPlace, head) or nil
	if type(p) ~= "table" and raw ~= head and type(W.FindPlace) == "function" then
		p = call(W.FindPlace, raw)
	end
	local name = (type(p) == "table" and S(p.name)) or head
	if type(W.NormPlace) == "function" then
		local nk = S((call(W.NormPlace, name)))
		if nk and nk ~= "" then return nk end
	end
	return string.lower(name)
end

local function driverName(d)
	local svc = S(d.service)
	if svc and svc ~= "" then return svc end
	local nm = S(d.name)
	if nm and nm ~= "" then return nm end
	local sh = S(d.short)
	if sh and sh ~= "" then return sh end
	return "?"
end

local function tooltipLine(d, price, fallbackPlace)
	local place = S(d.dest) or fallbackPlace or "?"
	local wait = type(UI.SummonWait) == "function" and N((call(UI.SummonWait, d))) or 30
	wait = math.max(1, math.floor(wait + 0.5))
	-- (decisions H, the author's words) the price beside the wait: the time first with no "about", then "costing" and
	-- the gold price. The flying sentence after it is a time alone and keeps "about".
	local line = driverName(d) .. " · summon to " .. place .. " · " .. wait .. " sec · costing " .. T.Code("gold") .. money(price) .. "|r"
	local secs = type(W.FlightTime) == "function" and N((call(W.FlightTime, nil, place))) or nil
	if secs and secs > 0 then
		local mins = math.max(1, math.floor(secs / 60 + 0.5))
		line = line .. ". Flying: about " .. mins .. " min."
	end
	return line
end

-- Opens Wuber on the driver's Confirm view, leaving the flight map open.
local function openDriver(key)
	if not key then return end
	if UI.Toggle and not (UI.state and UI.state.win and UI.state.win:IsShown()) then UI.Toggle(true) end
	UI.Show("confirm", key)
end

local function getHolder()
	if not holder then
		holder = CreateFrame("Frame", "WuberFlightPins", UIParent)
		holder:EnableMouse(false)
		holder:Hide()
	end
	return holder
end

local function buildMarker(parent)
	local m = CreateFrame("Frame", nil, parent)
	m:SetSize(CFG.markerSize, CFG.markerSize)
	m:EnableMouse(false)
	local PinsMod = W.Mod("UI.Map.Pins")
	if type(PinsMod) == "table" and type(PinsMod.Aura) == "function" then
		local aura = call(PinsMod.Aura, m, CFG.markerInner)
		if type(aura) == "table" then
			aura:Hide()
			m.aura = aura
		end
	end
	if not m.aura then
		local ring = m:CreateTexture(nil, "ARTWORK")
		ring:SetAllPoints(m)
		ring:SetTexture(MEDIA .. "ring")
		local r, g, b = 0.65, 0.42, 1
		if type(T.RGB) == "function" then
			local tr, tg, tb = call(T.RGB, "accent")
			if N(tr) and N(tg) and N(tb) then r, g, b = N(tr), N(tg), N(tb) end
		end
		ring:SetVertexColor(r, g, b, 0.95)
		m.ring = ring
	end
	m:Hide()
	return m
end

local function buildTag(parent)
	local tag = CreateFrame("Button", nil, parent)
	tag:SetSize(CFG.tagMinW, CFG.tagH)
	tag:EnableMouse(true)
	tag:RegisterForClicks("LeftButtonUp")
	tag.bg = T.Card(tag, CFG.tagMinW, CFG.tagH, { colour = { 0.09, 0.08, 0.17, 0.94 }, radius = 8, border = "accent" })
	tag.bg:SetAllPoints(tag)
	if type(tag.bg.EnableMouse) == "function" then tag.bg:EnableMouse(false) end
	tag.text = T.Text(tag.bg, "caption", "white", "CENTER", "medium")
	tag.text:SetPoint("CENTER", tag.bg, "CENTER", 0, 0)
	safeScript(tag, "OnClick", function() openDriver(tag.driverKey) end)
	tag:Hide()
	return tag
end

-- Tries right, left, above, then below the flight point; rejects any side overlapping a flight button or Wuber's window.
local function placeTag(cx, cy, btnRect, tw, th, obstacles, placedTags, sw, sh)
	local gap, mh = CFG.tagGap, CFG.markerHalf
	local leftEdge = math.min(btnRect.l, cx - mh)
	local rightEdge = math.max(btnRect.r, cx + mh)
	local botEdge = math.min(btnRect.b, cy - mh)
	local topEdge = math.max(btnRect.t, cy + mh)
	local cands = {
		{ l = rightEdge + gap, r = rightEdge + gap + tw, b = cy - th / 2, t = cy + th / 2 },
		{ l = leftEdge - gap - tw, r = leftEdge - gap, b = cy - th / 2, t = cy + th / 2 },
		{ l = cx - tw / 2, r = cx + tw / 2, b = topEdge + gap, t = topEdge + gap + th },
		{ l = cx - tw / 2, r = cx + tw / 2, b = botEdge - gap - th, t = botEdge - gap },
	}
	-- (r3 D) more sides when the four are taken by other pins' rings or tags: the corners, then a row further out
	local function add(l, b) cands[#cands + 1] = { l = l, r = l + tw, b = b, t = b + th } end
	add(rightEdge + gap, topEdge + gap)
	add(rightEdge + gap, botEdge - gap - th)
	add(leftEdge - gap - tw, topEdge + gap)
	add(leftEdge - gap - tw, botEdge - gap - th)
	add(rightEdge + gap, cy + th / 2 + gap)
	add(rightEdge + gap, cy - th * 1.5 - gap)
	add(leftEdge - gap - tw, cy + th / 2 + gap)
	add(leftEdge - gap - tw, cy - th * 1.5 - gap)
	add(cx - tw / 2, topEdge + gap * 2 + th)
	add(cx - tw / 2, botEdge - gap * 2 - th * 2)
	-- (r51 P) still crowded: the same eight spots one, two and three tag-sizes further out, so a tag need not lie over another's price
	for k = 1, 3 do
		local dx, dy = (tw + gap) * k, (th + gap) * k
		add(rightEdge + gap + dx, cy - th / 2)
		add(leftEdge - gap - tw - dx, cy - th / 2)
		add(cx - tw / 2, topEdge + gap + dy)
		add(cx - tw / 2, botEdge - gap - th - dy)
		add(rightEdge + gap + dx, topEdge + gap + dy)
		add(rightEdge + gap + dx, botEdge - gap - th - dy)
		add(leftEdge - gap - tw - dx, topEdge + gap + dy)
		add(leftEdge - gap - tw - dx, botEdge - gap - th - dy)
	end
	local bestOnScreen, bestClearTags, bestAny
	for i = 1, #cands do
		local c = cands[i]
		if not hitsAny(c, obstacles, CFG.hitPad) then
			local scr = onScreen(c, sw, sh)
			local clearTags = not hitsAny(c, placedTags, CFG.hitPad)
			if scr and clearTags then return c end
			if scr and not bestOnScreen then bestOnScreen = c end
			if clearTags and not bestClearTags then bestClearTags = c end
			if not bestAny then bestAny = c end
		end
	end
	if bestOnScreen then return bestOnScreen end
	-- (gauntlet #41) nothing fits on the screen: the nearest spot near the pin, on the screen, clear of the buttons, rings, windows and
	-- other tags (a tag far from its pin would mislead); none: the tag is left off (never drawn off the screen over a window)
	if sw and sh and sw >= tw and sh >= th then
		local reach = ((tw + gap) * 4) ^ 2
		local step, bestG, bestD = math.max(4, math.floor(th / 2)), nil, nil
		for y = 0, sh - th, step do
			for x = 0, sw - tw, step do
				local d = (x + tw / 2 - cx) ^ 2 + (y + th / 2 - cy) ^ 2
				if d <= reach and (not bestD or d < bestD) then
					local s = { l = x, r = x + tw, b = y, t = y + th }
					if not hitsAny(s, obstacles, CFG.hitPad) and not hitsAny(s, placedTags, CFG.hitPad) then bestG, bestD = s, d end
				end
			end
		end
		if bestG then return bestG end
		return nil
	end
	return bestClearTags or bestAny
end

function Mod.Hide()
	watchToken = nil
	active = {}
	for i = 1, #pool do
		if pool[i].marker.aura then pool[i].marker.aura:Hide() end
		pool[i].marker:Hide()
		pool[i].tag:Hide()
	end
	if holder then holder:Hide() end
end

-- Builds or updates the flight map pins; returns the number of price tags shown.
function Mod.Refresh()
	if W.db and W.db.flightOffers == false then
		Mod.Hide()
		return 0
	end
	local map = mapFrame()
	if not map then
		Mod.Hide()
		return 0
	end
	local mr = rectOf(map)
	if not mr or mr.r <= mr.l or mr.t <= mr.b then
		Mod.Hide()
		return 0
	end
	local count = type(NumTaxiNodes) == "function" and N((call(NumTaxiNodes))) or 0
	count = math.min(count, 200)
	if count <= 0 then
		Mod.Hide()
		return 0
	end

	-- Cheapest open driver per place (never my own beacon).
	local me = myKey()
	local bestByPlace = {}
	for _, d in ipairs(UI.Drivers() or {}) do
		if type(d) == "table" and d.state == "open" and d.key ~= me then
			local pk = placeKey(d.dest)
			local price = N(d.price)
			if pk and price then
				local cur = bestByPlace[pk]
				if not cur or price < cur.price then
					bestByPlace[pk] = { d = d, price = price }
				end
			end
		end
	end

	-- Map area for TaxiNodePosition fallback (TaxiRouteMap, or FlightMapFrame's ScrollContainer, when shown, else the map).
	local mapArea = mr
	local routeMap = _G["TaxiRouteMap"]
	if map ~= _G["TaxiFrame"] then routeMap = map.ScrollContainer end
	-- (run 1) Daylight UI puts the map art (InsetBg) inside a bigger window under a header: use it when no route map shows
	-- (r52) a nil routeMap must not hide InsetBg: ipairs stops at the first nil in Lua 5.1, so the list is walked by index
	local areas = { routeMap, map.InsetBg }
	for ai = 1, 2 do
		local area = areas[ai]
		if type(area) == "table" and type(area.IsShown) == "function" and W.Plain(call(area.IsShown, area)) == true then
			local rr = rectOf(area)
			if rr and rr.r > rr.l and rr.t > rr.b then mapArea = rr break end
		end
	end

	-- Read every flight point's button rect (as an obstacle) and collect points with open drivers.
	local obstacles = {}
	local matches = {}
	local seenPlace = {}
	for i = 1, count do
		local nodeName = type(TaxiNodeName) == "function" and S((call(TaxiNodeName, i))) or nil
		local cx, cy, btnRect
		local btn = _G["TaxiButton" .. i]
		if type(btn) == "table" and type(btn.IsShown) == "function" and W.Plain(call(btn.IsShown, btn)) == true then
			local br = rectOf(btn)
			if br and br.r > br.l and br.t > br.b then
				cx, cy, btnRect = (br.l + br.r) / 2, (br.b + br.t) / 2, br
			end
		end
		if not btnRect and type(TaxiNodePosition) == "function" then
			local nx, ny = call(TaxiNodePosition, i)
			nx, ny = N(nx), N(ny)
			if nx and ny and not (nx == 0 and ny == 0) and nx >= 0 and nx <= 1 and ny >= 0 and ny <= 1 then
				cx = mapArea.l + nx * (mapArea.r - mapArea.l)
				cy = mapArea.t - ny * (mapArea.t - mapArea.b)
				btnRect = { l = cx - CFG.btnHalf, r = cx + CFG.btnHalf, t = cy + CFG.btnHalf, b = cy - CFG.btnHalf }
			end
		end
		if btnRect then
			obstacles[#obstacles + 1] = btnRect
			if nodeName then
				local pk = placeKey(nodeName)
				local entry = pk and bestByPlace[pk]
				if entry and not seenPlace[pk] then
					seenPlace[pk] = true
					matches[#matches + 1] = {
						node = nodeName,
						short = shortName(nodeName),
						cx = cx,
						cy = cy,
						btnRect = btnRect,
						d = entry.d,
						price = entry.price,
					}
				end
			end
		end
	end

	if #matches == 0 then
		Mod.Hide()
		return 0
	end

	local winRects = windowRects()
	lastWinKey = winRectKey(winRects)
	for i = 1, #winRects do obstacles[#obstacles + 1] = winRects[i] end
	hookWin()

	local h = getHolder()
	-- anchored to the map itself (it follows a move or a resize), one strata above it
	h:ClearAllPoints()
	h:SetAllPoints(map)
	h:SetFrameStrata(aboveStrata(S((call(map.GetFrameStrata, map))) or "MEDIUM"))
	h:SetFrameLevel((N((call(map.GetFrameLevel, map))) or 1) + CFG.levelOffset)
	h:EnableMouse(false)

	local screenW = N((call(UIParent.GetWidth, UIParent))) or 0
	local screenH = N((call(UIParent.GetHeight, UIParent))) or 0
	active = {}
	local placedTags = {}
	local tagsShown = 0
	-- (r3 D) every shown pin ring is an obstacle for every tag: a tag never lies over another flight point's ring
	-- (r3 D2) a ring that would meet a neighbouring pin's ring is drawn smaller to fit (never moved off its point), or not at all
	for idx = 1, #matches do
		local m = matches[idx]
		local s = CFG.markerSize
		for j = 1, #matches do
			if j ~= idx then
				local n = matches[j]
				s = math.min(s, math.max(math.abs(n.cx - m.cx), math.abs(n.cy - m.cy)))
			end
		end
		m.ringSize = s
		m.ringInner = s - CFG.ringChrome
	end
	for idx = 1, #matches do
		local m = matches[idx]
		local rh = math.min(CFG.markerHalf, m.ringSize / 2)
		local ring = { l = m.cx - rh, r = m.cx + rh, b = m.cy - rh, t = m.cy + rh }
		if m.ringInner >= CFG.ringMinInner and not hitsAny(ring, winRects, 0) then obstacles[#obstacles + 1] = ring end
	end

	for idx = 1, #matches do
		local m = matches[idx]
		local slot = pool[idx]
		if not slot then
			slot = { marker = buildMarker(h), tag = buildTag(h) }
			pool[idx] = slot
		end
		local marker, tag = slot.marker, slot.tag
		marker:ClearAllPoints()
		marker:SetPoint("CENTER", h, "TOPLEFT", m.cx - mr.l, m.cy - mr.t)
		marker:EnableMouse(false)
		-- (r49 D) the ring is a box too: where Wuber's window lies over the flight point it is not drawn on the window
		local mh = CFG.markerHalf
		local noRing = m.ringInner < CFG.ringMinInner
		if noRing or hitsAny({ l = m.cx - mh, r = m.cx + mh, b = m.cy - mh, t = m.cy + mh }, winRects, 0) then
			if marker.aura then marker.aura:Hide() end
			marker:Hide()
		else
			marker:Show()
			if marker.aura then
				marker.aura:SetSize(math.min(CFG.markerInner, m.ringInner))
				marker.aura:Start()
			end
		end

		local priceText = money(m.price)
		tag.text:SetText(priceText)
		local sw = N((call(tag.text.GetStringWidth, tag.text))) or 0
		local tw = math.max(CFG.tagMinW, #priceText * 6 + CFG.tagPadX * 2, math.ceil(sw) + CFG.tagPadX * 2)
		local th = CFG.tagH
		local rect = placeTag(m.cx, m.cy, m.btnRect, tw, th, obstacles, placedTags, screenW, screenH)
		local shownTag
		if rect then
			tag:SetSize(tw, th)
			tag.bg:SetSize(tw, th)
			tag:ClearAllPoints()
			tag:SetPoint("TOPLEFT", h, "TOPLEFT", rect.l - mr.l, rect.t - mr.t)
			tag.driverKey = m.d.key
			local tip = tooltipLine(m.d, m.price, m.short)
			if tag._tipLine ~= tip then
				tag._tipLine = tip
				T.Tip(tag, tip)
			end
			tag:Show()
			placedTags[#placedTags + 1] = rect
			tagsShown = tagsShown + 1
			shownTag = tag
		else
			tag.driverKey = nil
			tag:Hide()
		end

		active[#active + 1] = {
			node = m.node,
			driver = m.d.key,
			price = m.price,
			tag = shownTag,
			marker = marker,
		}
	end

	for j = #matches + 1, #pool do
		if pool[j].marker.aura then pool[j].marker.aura:Hide() end
		pool[j].marker:Hide()
		pool[j].tag:Hide()
	end

	h:Show()
	local tok = {}
	watchToken = tok
	local function watch()
		if watchToken ~= tok then return end
		if not mapFrame() then Mod.Hide() return end
		hookWin()
		if winRectKey(windowRects()) ~= lastWinKey then
			W.Safe("flightpins", Mod.Refresh)
			return
		end
		W.After(CFG.check, watch)
	end
	W.After(CFG.check, watch)
	return tagsShown
end

function Mod.Pins()
	local out = {}
	for i = 1, #active do
		local p = active[i]
		out[i] = { node = p.node, driver = p.driver, price = p.price, tag = p.tag, marker = p.marker }
	end
	return out
end

-- True when at least one flight point has a shown button or a map position Wuber can place a tag by.
local function anyNodePlaced()
	local count = type(NumTaxiNodes) == "function" and N((call(NumTaxiNodes))) or 0
	for i = 1, math.min(count, 200) do
		local btn = _G["TaxiButton" .. i]
		if type(btn) == "table" and type(btn.IsShown) == "function" and W.Plain(call(btn.IsShown, btn)) == true then return true end
		if type(TaxiNodePosition) == "function" then
			local nx, ny = call(TaxiNodePosition, i)
			nx, ny = N(nx), N(ny)
			if nx and ny and not (nx == 0 and ny == 0) then return true end
		end
	end
	return false
end

function Mod.Why()
	if W.db and W.db.flightOffers == false then
		return "Flight map prices: off in Settings (Riding, Flight offers)."
	end
	local map = mapFrame()
	if map then
		if holder and holder:IsShown() and #active > 0 then return nil end
		if not rectOf(map) or not anyNodePlaced() then return "Flight map prices: this flight map is not one Wuber knows." end
		return "Flight map prices: no open driver summons to a place on this flight map."
	end
	return nil
end

-- The map opened (TAXIMAP_OPENED, or the map frame's OnShow: the real client never fired the event):
-- refresh now and a few times after, while a skin re-lays the map out. Both signals share one token.
local function onOpen()
	local tok = {}
	openToken = tok
	W.Safe("flightpins", Mod.Refresh)
	for _, t in ipairs(REFRESH_AFTER) do
		W.After(t, function()
			if openToken ~= tok then return end
			if mapFrame() then W.Safe("flightpins", Mod.Refresh) end
		end)
	end
end

-- The map changed size (Daylight's layout): place the tags again a moment later, once its buttons moved.
local function onResize()
	if resizePending or not mapFrame() then return end
	resizePending = true
	W.After(0.05, function()
		resizePending = nil
		if mapFrame() then W.Safe("flightpins", Mod.Refresh) end
	end)
end

local function onHidden()
	if mapFrame() then return end
	openToken = nil
	Mod.Hide()
end

local function onWinChange()
	if mapFrame() then W.Safe("flightpins", Mod.Refresh) end
end

local function onWinResize()
	if winResizePending or not mapFrame() then return end
	winResizePending = true
	W.After(0.05, function()
		winResizePending = nil
		if mapFrame() then W.Safe("flightpins", Mod.Refresh) end
	end)
end

hookWin = function()
	local ui = KitMod.ui
	if type(ui) ~= "table" then return end
	local win = ui.win
	if type(win) == "table" and not winHooked[win] and type(win.HookScript) == "function" then
		winHooked[win] = true
		call(win.HookScript, win, "OnShow", onWinChange)
		call(win.HookScript, win, "OnHide", onWinChange)
		call(win.HookScript, win, "OnSizeChanged", onWinResize)
	end
	-- (r50 E) any drag of the window re-checks at drag stop: the header, the phone, its status bar and its pill
	local ph = type(ui.phone) == "table" and ui.phone or {}
	local list = { ui.top, ui.phone, ph.status, ph.island }
	for i = 1, 4 do -- fixed count: a missing frame must not skip the later ones
		local f = list[i]
		if type(f) == "table" and not winHooked[f] and type(f.HookScript) == "function" then
			winHooked[f] = true
			call(f.HookScript, f, "OnDragStop", onWinChange)
		end
	end
	-- (r49 D) the small named frames: a pin steps aside the moment one shows, hides or changes size, not a second later
	for _, name in ipairs(WUBER_FRAMES) do
		local f = rawget(_G, name)
		if type(f) == "table" and not winHooked[f] and type(f.HookScript) == "function" then
			winHooked[f] = true
			call(f.HookScript, f, "OnShow", onWinChange)
			call(f.HookScript, f, "OnHide", onWinChange)
			call(f.HookScript, f, "OnSizeChanged", onWinResize)
		end
	end
end

-- Hooks each flight map frame once, as soon as it exists (TaxiFrame at login, FlightMapFrame with its addon).
-- Neither is a secure frame; HookScript keeps the game's own scripts.
local function hookMaps()
	hookWin()
	for _, name in ipairs(MAP_NAMES) do
		local f = _G[name]
		if type(f) == "table" and not hooked[f] and type(f.HookScript) == "function" then
			hooked[f] = true
			call(f.HookScript, f, "OnShow", function() onOpen() end)
			call(f.HookScript, f, "OnHide", function() onHidden() end)
			call(f.HookScript, f, "OnSizeChanged", function() onResize() end)
		end
	end
end
hookMaps()

W.Listen("FOLD", onWinChange)
W.Listen("PAGE", onWinChange)
W.Listen("NEWS_MOVED", onWinChange) -- the What's new card stands somewhere new: the tags step aside from it there

W.On("ADDON_LOADED", function() hookMaps() end)
W.On("PLAYER_LOGIN", function() hookMaps() end)
W.On("PLAYER_ENTERING_WORLD", function() hookMaps() end)

W.On("TAXIMAP_OPENED", function()
	onOpen()
	hookMaps() -- after the first open's refresh, so a map frame made now is not refreshed twice at once
end)

W.On("TAXIMAP_CLOSED", function()
	openToken = nil
	Mod.Hide()
end)
