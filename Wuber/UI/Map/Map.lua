-- Module: UI.Map.Map
-- Purpose: Pin pool layout (Release, HideAll, PinLevel, Layout), book-from-the-map hover and clicks
--   (M.PlaceUnderCursor, M.BookPlace), M.Refresh, the tick, OpenMap setup, M.Open (the one map opener), M.ShowDriver and wiring.
-- API: M.PlaceUnderCursor, M.DriversTo, M.TagText, M.BookPlace, M.UpdateHover, M.Refresh, M.SetShown,
--   M.ShowDriver, M.Open, M.Veil, M.OnlyPill, M.redraws, M.RedrawSoon
-- Internals: PinLevel
-- Uses: UI.Map.Base, UI.Map.Pins, UI.Map.Route
-- Later: UI.InFlight (Driver)
-- Events: listens Listen DRIVERS, Listen RIDE, Listen SETTINGS, On ADDON_LOADED, login; fires SETTINGS
-- Standalone: no
-- Test: tests/ui/map/map_test.lua
-- From: Map.lua 864-907, 1201-1827 (and lines 68-71: the pin and tick state locals) (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Map.Map", { "UI.Map.Base", "UI.Map.Pins", "UI.Map.Route" })
local BaseMod = W.Mod("UI.Map.Base")
local PinsMod = W.Mod("UI.Map.Pins")
local RouteMod = W.Mod("UI.Map.Route")
local Accent = BaseMod.Accent
local BlizzardPos = BaseMod.BlizzardPos
local CHOSEN_LEVEL = BaseMod.CHOSEN_LEVEL
local CREATOR_LEVEL = BaseMod.CREATOR_LEVEL
local Canvas = BaseMod.Canvas
local BaseChosen = BaseMod.Chosen
local Driver = BaseMod.Driver
local Drivers = BaseMod.Drivers
local FILL = BaseMod.FILL
local GLIDE_ZOOM = BaseMod.GLIDE_ZOOM
local ClickOver = BaseMod.ClickOver
local LEVEL_ABOVE = BaseMod.LEVEL_ABOVE
local MEDIA = BaseMod.MEDIA
local MUTED = BaseMod.MUTED
local MapShown = BaseMod.MapShown
local NewFrame = BaseMod.NewFrame
local OM = BaseMod.OM
local OMHas = BaseMod.OMHas
local OpenMapPos = BaseMod.OpenMapPos
local PinsOn = BaseMod.PinsOn
local PriceRanks = BaseMod.PriceRanks
local Prominence = BaseMod.Prominence
local STATE_LEVEL = BaseMod.STATE_LEVEL
local ShownMapID = BaseMod.ShownMapID
local Stitched = BaseMod.Stitched
local TEXT = BaseMod.TEXT
local TICK = BaseMod.TICK
local VIOLET = BaseMod.VIOLET
local World = BaseMod.World
local WorldUV = BaseMod.WorldUV
local XY = BaseMod.XY
local call = BaseMod.call
local pins = BaseMod.pins
local CanvasMetrics = PinsMod.CanvasMetrics
local NewPin = PinsMod.NewPin
local Paint = PinsMod.Paint
local Place = PinsMod.Place
local SetLevels = PinsMod.SetLevels
local StopCreator = PinsMod.StopCreator
local StopPulse = PinsMod.StopPulse
local HideRoute = RouteMod.HideRoute
local UpdateRoute = RouteMod.UpdateRoute
local M = W.Map

local used = 0           -- pins[1..used] show a driver now
local ticker             -- the 10 Hz frame (a child of WorldMapFrame: runs only while it shows)
local hooked, omDone = false, false
local lastMap, lastStitched, lastW, lastH, lastS
local veil, onlyPill

local function Release(pin)
	pin:Hide()
	pin.key, pin.hover, pin.chosen = nil, false, false
	StopPulse(pin)
	StopCreator(pin)
	pin.creator = false
end

local function HideAll()
	for i = 1, used do Release(pins[i]) end
	used = 0
	if veil then veil:Hide() end
	if onlyPill then onlyPill:Hide() end
	-- a tip of the pill or of a pin goes with it (Wuber's own tip card, T.TipOwner)
	local Th = W.Theme
	local owner = Th and Th.TipOwner and Th.TipOwner()
	if owner then
		if owner == onlyPill then
			Th.TipHide(owner)
		else
			for i = 1, #pins do
				if owner == pins[i] then Th.TipHide(owner) break end
			end
		end
	end
end

local function PinLevel(child, stitched)
	local ok, base = call(child, "GetFrameLevel")
	base = ok and W.Num(base) or 1
	local level = base + LEVEL_ABOVE
	local api = stitched and OMHas("ArtTopLevel", 2)
	if api then
		local okt, top = pcall(api.ArtTopLevel)
		top = okt and W.Num(top)
		if top and top + 10 > level then level = top + 10 end
	end
	return math.floor(math.min(level, 9000))
end

-- puts every pin where it belongs on the canvas; only does work when the canvas changed size
-- or zoom (or when forced)
local function Layout(force)
	local child = Canvas()
	if not child or used == 0 then return end
	local w, h, s = CanvasMetrics(child)
	if not w then return end
	if not force and w == lastW and h == lastH and s == lastS then return end
	lastW, lastH, lastS = w, h, s
	for i = 1, used do Place(pins[i], child, w, h, s) end
end

---------------------------------------------------------------------------
-- Book from the map: any known place, not only driver pins. Hovering a place shows a small
-- "Ride here · 2 drivers · from 50s" tag by the cursor and a "Ride here" button in the map's
-- corner; Ctrl-click (or the button) opens Wuber on that place. Blizzard's own clicks are
-- never touched (OnMouseUp is hooked, and only Ctrl + left click is acted on).
---------------------------------------------------------------------------

local RADIUS = 26        -- screen pixels around a place that count as "on" it
local GRACE = 2          -- seconds the corner button stays after the cursor leaves a place
local placeCache = {}    -- "<shown>:<stitched>" -> { { place, nx, ny }, ... }
local hover = { }        -- place, at (when last over one), tag, button

local function Same(a, b)
	if type(W.SamePlace) == "function" then
		local ok, yes = pcall(W.SamePlace, a, b)
		if ok then return yes == true end
	end
	a, b = W.Str(a), W.Str(b)
	return a ~= nil and b ~= nil and a:lower() == b:lower()
end

-- every place's spot on the shown map (worked out once per map)
local function PlaceSpots(shown, stitched)
	local key = tostring(shown) .. ":" .. tostring(stitched)
	local list = placeCache[key]
	if list then return list end
	list = {}
	if type(W.PLACES) == "table" then
		for _, p in ipairs(W.PLACES) do
			local m, x, y = type(p) == "table" and W.Num(p.mapID), type(p) == "table" and W.Num(p.x), type(p) == "table" and W.Num(p.y)
			if m and x and y and p.kind ~= "zone" then
				local nx, ny
				if stitched then nx, ny = OpenMapPos(m, x, y, shown) else nx, ny = BlizzardPos(m, x, y, shown) end
				if nx then list[#list + 1] = { p, nx, ny } end
			end
		end
	end
	placeCache[key] = list
	return list
end

-- the cursor on the canvas (0..1 of the shown map; may lie past it on OpenMap), and on the
-- stitched world (u, v) when OpenMap says
local function CursorOnCanvas(child, shown, stitched)
	local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
	if type(sc) == "table" then
		local ok, over = call(sc, "IsMouseOver")
		if ok and W.Plain(over) == false then return nil end
	end
	if stitched then
		local api = OMHas("CursorPosition")
		local okc, u, v
		if api then okc, u, v = pcall(api.CursorPosition) end
		u, v = okc and W.Num(u), okc and W.Num(v)
		if u and v and OMHas("MapFromWorld") then
			local okm, cx, cy = pcall(OpenMapAPI.MapFromWorld, shown, u, v)
			cx, cy = okm and W.Num(cx), okm and W.Num(cy)
			if cx and cy then return cx, cy, u, v end
		end
	elseif type(sc) == "table" and type(sc.GetNormalizedCursorPosition) == "function" then
		local ok, x, y = pcall(sc.GetNormalizedCursorPosition, sc)
		x, y = ok and W.Num(x), ok and W.Num(y)
		if x and y then return x, y end
	end
	-- work it out from the cursor and the canvas's rectangle
	if type(GetCursorPosition) ~= "function" then return nil end
	local ok, mx, my = pcall(GetCursorPosition)
	mx, my = ok and W.Num(mx), ok and W.Num(my)
	local oke, es = call(child, "GetEffectiveScale")
	local okl, l = call(child, "GetLeft")
	local okt, t = call(child, "GetTop")
	es, l, t = oke and W.Num(es), okl and W.Num(l), okt and W.Num(t)
	local w, h = CanvasMetrics(child)
	if not (mx and my and es and es > 0 and l and t and w) then return nil end
	return (mx / es - l) / w, (t - my / es) / h
end

local function MapName(mapID)
	if not (C_Map and type(C_Map.GetMapInfo) == "function") then return nil end
	local ok, info = pcall(C_Map.GetMapInfo, mapID)
	info = ok and W.Plain(info)
	return type(info) == "table" and W.Str(info.name) or nil
end

-- the main place of a zone map: its city, else its own zone entry, else its first town
local function MainPlace(mapID)
	if not mapID or type(W.PLACES) ~= "table" then return nil end
	local zone = MapName(mapID)
	local town
	for _, p in ipairs(W.PLACES) do
		if p.kind == "city" and (p.mapID == mapID or (zone and p.zone == zone)) then return p end
	end
	for _, p in ipairs(W.PLACES) do
		if p.kind == "zone" and p.mapID == mapID then return p end
		if not town and p.kind == "town" and p.mapID == mapID then town = p end
	end
	return town
end

-- The known place under the cursor on the world map (W.PLACES entry), or nil. A place counts
-- within ~26 pixels of its spot; on a city's own map, anywhere. wide = true (a click) also
-- takes the nearest place on the zone under the cursor, then the zone's main place.
function M.PlaceUnderCursor(wide)
	if not MapShown() then return nil end
	local child, shown = Canvas(), ShownMapID()
	if not (child and shown) then return nil end
	local stitched = Stitched()
	local cx, cy, u, v = CursorOnCanvas(child, shown, stitched)
	if not cx then return nil end
	local w, h, s = CanvasMetrics(child)
	if not w then return nil end
	local oke, es = call(child, "GetEffectiveScale")
	es = oke and W.Num(es)
	if not (es and es > 0) then es = s end
	local best, bestD
	for _, e in ipairs(PlaceSpots(shown, stitched)) do
		local dx, dy = (e[2] - cx) * w * es, (e[3] - cy) * h * es
		local d = math.sqrt(dx * dx + dy * dy)
		if d <= RADIUS and (not bestD or d < bestD) then best, bestD = e[1], d end
	end
	if best then return best end
	local inside = cx >= 0 and cx <= 1 and cy >= 0 and cy <= 1
	-- a city's own map is the city
	if inside and not stitched and type(W.PLACES) == "table" then
		for _, p in ipairs(W.PLACES) do
			if p.kind == "city" and p.mapID == shown then return p end
		end
	end
	if not wide then return nil end
	-- the zone under the cursor: its nearest place, else its main place
	local zoneMap, zx, zy
	if stitched then
		if u and OMHas("MapAt") then
			local ok, m = pcall(OpenMapAPI.MapAt, u, v)
			zoneMap = ok and W.Num(m)
			if zoneMap and OMHas("MapFromWorld") then
				local okm, x, y = pcall(OpenMapAPI.MapFromWorld, zoneMap, u, v)
				zx, zy = okm and W.Num(x), okm and W.Num(y)
			end
		end
	elseif inside then
		zoneMap, zx, zy = shown, cx, cy
		if C_Map and type(C_Map.GetMapInfoAtPosition) == "function" then
			local ok, info = pcall(C_Map.GetMapInfoAtPosition, shown, cx, cy)
			info = ok and W.Plain(info)
			local id = type(info) == "table" and W.Num(info.mapID)
			if id and id ~= shown then
				local x, y = nil, nil
				local cont, wx, wy = World(shown, cx, cy)
				if cont then
					local okv, vec = pcall(CreateVector2D, wx, wy)
					if okv and vec then
						local okp, a, b = pcall(C_Map.GetMapPosFromWorldPos, cont, vec, id)
						if okp then x, y = XY(b) if not x then x, y = XY(a) end end
					end
				end
				zoneMap, zx, zy = id, x, y
			end
		end
	end
	if not zoneMap then return nil end
	if zx and zy and type(W.PlaceAt) == "function" then
		local ok, p = pcall(W.PlaceAt, zoneMap, zx, zy)
		if ok and type(p) == "table" then return p end
	end
	return MainPlace(zoneMap)
end

-- drivers to a place (open or busy, not paused, not hidden, not me): count, cheapest fare
local function DriversTo(place)
	local n, cheapest, cheapestOpen = 0, nil, nil
	for _, d in ipairs(Drivers()) do
		if d.state ~= "paused" and not (W.myKey and d.key == W.myKey) and Same(d.dest, place.name) then
			n = n + 1
			local price = W.Num(d.price)
			if price then
				if not cheapest or price < cheapest then cheapest = price end
				if d.state == "open" and (not cheapestOpen or price < cheapestOpen) then cheapestOpen = price end
			end
		end
	end
	return n, cheapestOpen or cheapest
end
M.DriversTo = DriversTo

-- the tag's text: "Ride here · 2 drivers · from 50s" (or "Ride here · no drivers yet")
local function TagText(place)
	local n, price = DriversTo(place)
	local text = "|cffcd7df5Ride here|r  ·  " .. tostring(place.name)
	if n == 0 then return text .. "  ·  no drivers yet" end
	text = text .. "  ·  " .. n .. (n == 1 and " driver" or " drivers")
	if price then text = text .. "  ·  from |cfff9c53e" .. W.Money(price) .. "|r" end
	return text
end
M.TagText = TagText

-- opens Wuber on a place: the "book" screen (UI), else Home with the search filled
function M.BookPlace(place)
	if type(place) == "string" then
		local name = place
		place = nil
		if type(W.ExactPlace) == "function" then
			local ok, p = pcall(W.ExactPlace, name)
			if ok and type(p) == "table" then place = p end
		end
		place = place or { name = name }
	end
	if type(place) ~= "table" or not W.Str(place.name) then return false end
	if W.InCombat and W.InCombat() then
		if W.UI and type(W.UI.Toast) == "function" then W.Safe("toast", W.UI.Toast, "Leave combat first", "warn") end
		return false
	end
	if not (W.UI and type(W.UI.Show) == "function") then return false end
	W.Sound("click")
	local ok, res = W.Safe("book", W.UI.Show, "book", place.name)
	if ok and res ~= false then return true end
	-- no "book" screen yet: Home, with the place in the search box
	W.Safe("book home", W.UI.Show, "home")
	if type(W.UI.SetSearch) == "function" then W.Safe("book search", W.UI.SetSearch, place.name) end
	return true
end

local function TagFont(fs, size)
	local T = W.Theme
	if type(T) == "table" and type(T.SetFont) == "function" and pcall(T.SetFont, fs, size, "medium") then return end
	local ok, set = pcall(fs.SetFont, fs, "Fonts\\ARIALN.TTF", 12, "") -- (design round 3) without the theme: the 12 these tags always had
	if (not ok or set == false) and GameFontNormal then pcall(fs.SetFontObject, fs, GameFontNormal) end
end

local function Pill(f, h, colour, alpha)
	local parts = {}
	for i, tc in ipairs({ { 0, 0.25 }, { 0.75, 1 }, { 0.25, 0.75 } }) do
		local t = f:CreateTexture(nil, "BACKGROUND")
		t:SetTexture(MEDIA .. "pill")
		t:SetTexCoord(tc[1], tc[2], 0, 1)
		t:SetVertexColor(colour[1], colour[2], colour[3], alpha)
		parts[i] = t
	end
	parts[1]:SetSize(h / 2, h)
	parts[1]:SetPoint("LEFT", f, "LEFT", 0, 0)
	parts[2]:SetSize(h / 2, h)
	parts[2]:SetPoint("RIGHT", f, "RIGHT", 0, 0)
	parts[3]:SetPoint("TOPLEFT", parts[1], "TOPRIGHT", 0, 0)
	parts[3]:SetPoint("BOTTOMRIGHT", parts[2], "BOTTOMLEFT", 0, 0)
	return parts
end

local function TextWidth(fs, text)
	local ok, w = call(fs, "GetStringWidth")
	w = ok and W.Num(w)
	if w and w > 0 then return w end
	return #(text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) * 6
end

-- the tag by the cursor (one frame, on the canvas, constant size on screen, never takes the mouse)
local function HoverTag(child)
	local tag = hover.tag
	if tag and tag.host == child then return tag end
	tag = NewFrame("Frame", child)
	tag.host = child
	tag:SetSize(160, 22)
	if tag.EnableMouse then tag:EnableMouse(false) end
	Pill(tag, 22, FILL, 0.94)
	local dot = tag:CreateTexture(nil, "ARTWORK")
	dot:SetTexture(MEDIA .. "summon")
	dot:SetSize(12, 12)
	dot:SetPoint("LEFT", tag, "LEFT", 8, 0)
	Accent(dot, 1)
	local text = tag:CreateFontString(nil, "OVERLAY")
	TagFont(text, "sub")
	text:SetPoint("LEFT", dot, "RIGHT", 5, 0)
	text:SetTextColor(TEXT[1], TEXT[2], TEXT[3], 1)
	tag.text = text
	tag:Hide()
	hover.tag = tag
	return tag
end

-- the "Ride here" button in the map's corner (shown while over a place, and a moment after)
local function CornerButton()
	local b = hover.button
	if b then return b end
	local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
	if type(sc) ~= "table" then return nil end
	b = NewFrame("Button", sc)
	b:SetSize(150, 26)
	b:SetPoint("BOTTOMRIGHT", sc, "BOTTOMRIGHT", -12, 12)
	b:RegisterForClicks("LeftButtonUp")
	Pill(b, 26, VIOLET, 1)
	local text = b:CreateFontString(nil, "OVERLAY")
	TagFont(text, "sub")
	text:SetPoint("CENTER", b, "CENTER", 0, 0)
	text:SetTextColor(1, 1, 1, 1)
	b.text = text
	local function onRide(self)
		W.Safe("ride here", function() if self.place then M.BookPlace(self.place) end end)
	end
	if W.GamepadUI() then -- (PST-01 B) no click script with the Gamepad UI on: the global mouse events
		ClickOver(b, onRide)
	else
		b:SetScript("OnClick", function(self)
			onRide(self)
		end)
	end
	b:SetScript("OnEnter", function(self)
		W.Safe("ride here tip", function()
			local Th = W.Theme
			if not (Th and Th.TipShow and self.place) then return end
			-- (design 4) Wuber's own tip card: a frame under UIParent, never under the game's map
			Th.TipShow(self, "Ride here", "Opens Wuber on " .. tostring(self.place.name) .. ": its drivers, cheapest first. Ctrl-click a place on the map does the same.", "ANCHOR_TOP")
		end)
	end)
	b:SetScript("OnLeave", function(self)
		W.Safe("ride here tip", function()
			if W.Theme and W.Theme.TipHide then W.Theme.TipHide(self) end
		end)
	end)
	b:Hide()
	hover.button = b
	return b
end

local function UpdateVeil(child, level)
	local on = W.db and W.db.mapOnly and true or false
	if not on then
		if veil then veil:Hide() end
		return
	end
	if not veil then
		veil = NewFrame("Frame", child)
		veil:SetAllPoints(child)
		if veil.EnableMouse then veil:EnableMouse(false) end
		local tex = veil:CreateTexture(nil, "BACKGROUND")
		tex:SetAllPoints(veil)
		tex:SetColorTexture(0, 0, 0, 0.55)
		veil.tex = tex
	end
	local vlevel = math.max(0, level - 1)
	if veil.level ~= vlevel then
		veil.level = vlevel
		veil:SetFrameLevel(vlevel)
	end
	veil:Show()
end

local function PaintOnlyPill(b, on)
	local colour = on and VIOLET or FILL
	local alpha = on and 1 or 0.94
	for i = 1, #b.parts do
		b.parts[i]:SetVertexColor(colour[1], colour[2], colour[3], alpha)
	end
	if on then
		b.text:SetTextColor(1, 1, 1, 1)
	else
		b.text:SetTextColor(MUTED[1], MUTED[2], MUTED[3], 1)
	end
end

local function PlaceCornerButton(b)
	local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
	if not (b and type(sc) == "table") then return end
	local beside = onlyPill and onlyPill:IsShown() and true or false
	if b.beside == beside then return end
	b.beside = beside
	b:ClearAllPoints()
	if beside then
		if onlyPill.left then
			b:SetPoint("LEFT", onlyPill, "RIGHT", 8, 0)
		else
			b:SetPoint("RIGHT", onlyPill, "LEFT", -8, 0)
		end
	else
		b:SetPoint("BOTTOMRIGHT", sc, "BOTTOMRIGHT", -12, 12)
	end
end

-- the pill's home is the map's bottom-right corner; Wuber's unfolded window can cover it, and a covered pill
-- takes no click: then it sits in the bottom-left corner (the hover button follows it)
local function WindowCoversPillHome(b, sc)
	local wf = type(_G) == "table" and rawget(_G, "WuberFrame") or nil
	if not wf then return false end
	local oks, shown = call(wf, "IsShown")
	if not (oks and W.Plain(shown) == true) then return false end
	local _, wl = call(wf, "GetLeft")
	local _, wr = call(wf, "GetRight")
	local _, wb = call(wf, "GetBottom")
	local _, wt = call(wf, "GetTop")
	local _, sr = call(sc, "GetRight")
	local _, sb = call(sc, "GetBottom")
	local _, bw = call(b, "GetWidth")
	local _, bh = call(b, "GetHeight")
	local _, wes = call(wf, "GetEffectiveScale")
	local _, ses = call(sc, "GetEffectiveScale")
	wl, wr, wb, wt, sr, sb, bw, bh = W.Num(wl), W.Num(wr), W.Num(wb), W.Num(wt), W.Num(sr), W.Num(sb), W.Num(bw), W.Num(bh)
	wes, ses = W.Num(wes) or 1, W.Num(ses) or 1
	if not (wl and wr and wb and wt and sr and sb and bw and bh) then return false end
	-- each frame reports its edges in its own scale: compare in screen units
	wl, wr, wb, wt = wl * wes, wr * wes, wb * wes, wt * wes
	local pr, pb = sr * ses - 12 * ses, sb * ses + 12 * ses
	local pl, pt = pr - bw * ses, pb + bh * ses
	return wl < pr and wr > pl and wb < pt and wt > pb
end

local function PlaceOnlyPill()
	local b = onlyPill
	local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
	if not (b and type(sc) == "table") then return end
	local left = WindowCoversPillHome(b, sc)
	if b.left == left then return end
	b.left = left
	b:ClearAllPoints()
	if left then
		b:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 12, 12)
	else
		b:SetPoint("BOTTOMRIGHT", sc, "BOTTOMRIGHT", -12, 12)
	end
	if hover.button then hover.button.beside = nil end
end

local function EnsureOnlyPill()
	if onlyPill then return onlyPill end
	local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
	if type(sc) ~= "table" then return nil end
	local b = NewFrame("Button", sc)
	b:SetSize(92, 26)
	b:SetPoint("BOTTOMRIGHT", sc, "BOTTOMRIGHT", -12, 12)
	b:RegisterForClicks("LeftButtonUp")
	b.parts = Pill(b, 26, FILL, 0.94)
	local text = b:CreateFontString(nil, "OVERLAY")
	TagFont(text, "sub")
	text:SetPoint("CENTER", b, "CENTER", 0, 0)
	text:SetText("Wuber only")
	b:SetWidth(TextWidth(text, "Wuber only") + 28)
	b.text = text
	local function onOnly()
		W.Safe("wuber only", function()
			if not W.db then return end
			if W.db.mapOnly then
				W.db.mapOnly = nil
			else
				W.db.mapOnly = true
			end
			W.Sound("click")
			M.Refresh()
			W.Fire("SETTINGS", "mapOnly")
		end)
	end
	if W.GamepadUI() then -- (PST-01 B) no click script with the Gamepad UI on: the global mouse events
		ClickOver(b, onOnly)
	else
		b:SetScript("OnClick", function()
			onOnly()
		end)
	end
	b:SetScript("OnEnter", function(self)
		W.Safe("wuber only tip", function()
			local Th = W.Theme
			if not (Th and Th.TipShow) then return end
			Th.TipShow(self, "Wuber only", "Dims the rest of the map so Wuber's pins stand out.", "ANCHOR_TOP")
		end)
	end)
	b:SetScript("OnLeave", function(self)
		W.Safe("wuber only tip", function()
			if W.Theme and W.Theme.TipHide then W.Theme.TipHide(self) end
		end)
	end)
	b:Hide()
	onlyPill = b
	return b
end

local function UpdateOnlyPill()
	local b = EnsureOnlyPill()
	if not b then return end
	local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
	local okl, level = call(sc, "GetFrameLevel")
	level = okl and W.Num(level) or 1
	if b.level ~= level then
		b.level = level
		b:SetFrameLevel(math.min(9990, level + 600))
	end
	PaintOnlyPill(b, W.db and W.db.mapOnly and true or false)
	PlaceOnlyPill()
	b:Show()
	if hover.button and hover.button:IsShown() then PlaceCornerButton(hover.button) end
end

function M.Veil()
	return veil
end

function M.OnlyPill()
	return onlyPill
end

local function HideHover()
	if hover.tag then hover.tag:Hide() end
	if hover.button then hover.button:Hide() end
	hover.place, hover.at = nil, nil
end

-- 10 Hz while the map shows: the tag by the cursor and the corner button
local function UpdateHover()
	local child = Canvas()
	if not (child and MapShown() and PinsOn()) then HideHover() return end
	local place = M.PlaceUnderCursor(false)
	local now = W.Now()
	local b = CornerButton()
	if place then
		hover.place, hover.at = place, now
		local shown, stitched = ShownMapID(), Stitched()
		local cx, cy = CursorOnCanvas(child, shown, stitched)
		local w, h, s = CanvasMetrics(child)
		local tag = HoverTag(child)
		local text = TagText(place)
		tag.text:SetText(text)
		tag:SetWidth(TextWidth(tag.text, text) + 36)
		if cx and w then
			local scale = 1 / s
			tag:SetScale(scale)
			tag:ClearAllPoints()
			tag:SetPoint("BOTTOM", child, "TOPLEFT", cx * w / scale, -cy * h / scale + 18)
			local level = PinLevel(child, stitched) + 32
			if tag.level ~= level then
				tag.level = level
				tag:SetFrameLevel(math.min(9990, level))
			end
			tag:Show()
		else
			tag:Hide()
		end
	elseif hover.tag then
		hover.tag:Hide()
	end
	if not b then return end
	local okm, overButton = call(b, "IsMouseOver")
	overButton = okm and W.Plain(overButton) == true and b:IsShown()
	local keep = hover.place and (place or overButton or (hover.at and now - hover.at <= GRACE))
	if keep then
		local p = place or hover.place
		if b.place ~= p then
			b.place = p
			b.text:SetText("Ride here: " .. tostring(p.name))
			b:SetWidth(TextWidth(b.text, "Ride here: " .. tostring(p.name)) + 28)
		end
		local okl, level = call(WorldMapFrame.ScrollContainer, "GetFrameLevel")
		level = okl and W.Num(level) or 1
		if b.level ~= level then
			b.level = level
			b:SetFrameLevel(math.min(9990, level + 600))
		end
		PlaceCornerButton(b)
		b:Show()
	else
		hover.place = nil
		b:Hide()
		b.place = nil
	end
end
M.UpdateHover = UpdateHover

-- Ctrl + left click on the map (a click, not the end of a drag)
local downX, downY, downPlace
local function MouseDown()
	downPlace = nil
	if type(IsControlKeyDown) == "function" and W.Plain(IsControlKeyDown()) == true then
		-- the place under the cursor now, before the game's own OnMouseUp can zoom the map
		downPlace = M.PlaceUnderCursor(true)
	end
	if type(GetCursorPosition) ~= "function" then return end
	local ok, x, y = pcall(GetCursorPosition)
	downX, downY = ok and W.Num(x), ok and W.Num(y)
end

local function MouseUp(_, button)
	if W.Plain(button) ~= "LeftButton" then return end
	if not (type(IsControlKeyDown) == "function" and W.Plain(IsControlKeyDown()) == true) then return end
	if downX and type(GetCursorPosition) == "function" then
		local ok, x, y = pcall(GetCursorPosition)
		x, y = ok and W.Num(x), ok and W.Num(y)
		if x and y and math.abs(x - downX) + math.abs(y - downY) > 8 then return end -- a drag
	end
	if W.InCombat and W.InCombat() then
		if W.UI and type(W.UI.Toast) == "function" then W.Safe("toast", W.UI.Toast, "Leave combat first", "warn") end
		return
	end
	local place = downPlace or M.PlaceUnderCursor(true)
	downPlace = nil
	if place then M.BookPlace(place) end
end

local function HookClicks()
	local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
	if hover.hooked or type(sc) ~= "table" or type(sc.HookScript) ~= "function" then return end
	hover.hooked = true
	if W.GamepadUI() then -- (PST-01 B) no hook on the game's frame: the global mouse events, while the pointer is over it
		ClickOver(sc, function(_, button) MouseUp(sc, button) end, function() MouseDown() end)
		return
	end
	pcall(sc.HookScript, sc, "OnMouseDown", function(...) W.Safe("map click", MouseDown, ...) end)
	pcall(sc.HookScript, sc, "OnMouseUp", function(...) W.Safe("map click", MouseUp, ...) end)
end

local Setup

local function Chosen()
	local key = BaseChosen and BaseChosen()
	if key then return key end
	local InFlightMod = type(W.Mod) == "function" and W.Mod("UI.InFlight")
	if type(InFlightMod) == "table" and type(InFlightMod.Driver) == "function" then
		local ok, d = pcall(InFlightMod.Driver)
		if ok and d then return d end
	end
	return nil
end

function M.Refresh()
	if Setup then Setup() end
	UpdateRoute()
	if not (MapShown() and PinsOn()) then
		HideAll()
		return
	end
	local child = Canvas()
	local shown = ShownMapID()
	if not (child and shown) then
		HideAll()
		return
	end
	local stitched = Stitched()
	lastMap, lastStitched = shown, stitched
	local level = PinLevel(child, stitched)
	UpdateVeil(child, level)
	UpdateOnlyPill()
	local chosenKey = Chosen()
	local list = Drivers()
	local rank, nRank = PriceRanks(list)
	local n = 0
	for i = 1, #list do
		local d = list[i]
		local key = type(d) == "table" and d.key
		local mapID, x, y
		if key then mapID, x, y = W.Num(d.mapID), W.Num(d.x), W.Num(d.y) end
		if mapID and mapID > 0 and x and y then
			local cx, cy
			if stitched then
				cx, cy = OpenMapPos(mapID, x, y, shown)
			else
				cx, cy = BlizzardPos(mapID, x, y, shown)
			end
			if cx then
				n = n + 1
				local pin = pins[n]
				if not pin then
					pin = NewPin(child)
					pins[n] = pin
				end
				if pin.key ~= key then pin.hover = false end
				pin.key, pin.nx, pin.ny = key, cx, cy
				local chosen = key == chosenKey
				local glow, creator = Prominence(d, rank, nRank)
				SetLevels(pin, level + (chosen and CHOSEN_LEVEL or (creator and d.state ~= "paused" and CREATOR_LEVEL)
					or (STATE_LEVEL[d.state] or 0)))
				Paint(pin, d, chosen, glow, creator)
				pin:Show()
			end
		end
	end
	for i = n + 1, used do Release(pins[i]) end
	used = n
	Layout(true)
end

---------------------------------------------------------------------------
-- Following the map: hooks, the 10 Hz tick, OpenMap callbacks and menu
---------------------------------------------------------------------------

local function Tick(self, elapsed)
	self.wait = (self.wait or 0) + (tonumber(elapsed) or 0)
	if self.wait < TICK then return end
	self.wait = 0
	W.Safe("map tick", function()
		local id, st = ShownMapID(), Stitched()
		if id ~= lastMap or st ~= lastStitched then
			M.Refresh()
		else
			Layout(false)
			UpdateRoute()
		end
		UpdateHover()
		PlaceOnlyPill()
		if hover.button and hover.button:IsShown() then PlaceCornerButton(hover.button) end
	end)
end

local function SetupOpenMap()
	if omDone then return end
	local api = OM()
	if not api then return end
	omDone = true
	if type(api.RegisterMenuToggle) == "function" then
		W.Safe("map menu", api.RegisterMenuToggle, "Wuber", {
			id = "drivers",
			label = "Wuber drivers",
			icon = MEDIA .. "pin",
			get = function() return PinsOn() end,
			set = function(on) M.SetShown(on) end,
		})
	end
	if type(api.RegisterCallback) == "function" then
		pcall(api.RegisterCallback, M, "OpenMap_ViewChanged", function()
			W.Safe("map view", M.Refresh)
		end)
		pcall(api.RegisterCallback, M, "OpenMap_StitchedChanged", function()
			W.Safe("map stitched", M.Refresh)
		end)
	end
end

Setup = function()
	SetupOpenMap()
	if hooked then return end
	local map = WorldMapFrame
	if not (map and type(map.HookScript) == "function" and Canvas()) then return end
	hooked = true
	ticker = NewFrame("Frame", map)
	ticker:SetScript("OnUpdate", Tick)
	map:HookScript("OnShow", function() W.Safe("map show", M.Refresh) end)
	map:HookScript("OnHide", function() W.Safe("map hide", function() HideAll() HideRoute() HideHover() end) end)
	HookClicks()
	if type(hooksecurefunc) == "function" and type(map.OnMapChanged) == "function" then
		pcall(hooksecurefunc, map, "OnMapChanged", function() W.Safe("map change", M.Refresh) end)
	end
end

function M.SetShown(on)
	if not W.db then return end
	W.db.mapPins = on and true or false
	M.Refresh()
	W.Fire("SETTINGS", "mapPins")
end

-- The ONE place Wuber opens the world map, or moves an open one to another map (mapID optional). It asks the game
-- to do it (C_Map.OpenWorldMap), so none of the map's own Lua runs in Wuber's name: opening it with ShowUIPanel,
-- OpenWorldMap, ToggleWorldMap, :Show() or :SetMapID() from addon code can leave the map refusing to open in a
-- fight, or without quest pins, until a reload. Never in combat (the safe opener is refused then too). Only a game
-- with no C_Map.OpenWorldMap falls back to the old way. True when the map shows afterwards.
function M.Open(mapID)
	if W.GamepadUI() then return false end -- (PST-01 B) with the Gamepad UI on the addon never opens the map
	if W.InCombat and W.InCombat() then return false end
	mapID = W.Num(mapID)
	if not (mapID and mapID > 0) then mapID = nil end
	local open = type(C_Map) == "table" and C_Map.OpenWorldMap
	if type(open) == "function" then
		if mapID then pcall(open, mapID) else pcall(open) end
		return MapShown() == true
	end
	local map = WorldMapFrame -- fallback: this game has no safe opener
	if not map then return false end
	if not MapShown() and type(ShowUIPanel) == "function" then pcall(ShowUIPanel, map) end
	if not MapShown() then return false end
	if mapID then call(map, "SetMapID", mapID) end
	return true
end

-- Opens the world map on a driver. With OpenMap's stitched map: glides there.
function M.ShowDriver(key)
	-- opening or moving the world map from addon code in combat can be blocked and taint it
	if W.InCombat and W.InCombat() then
		if W.UI and W.UI.Toast then W.UI.Toast("Leave combat first, then open the map.", "warn") end
		return false
	end
	local d = Driver(key)
	if not d then return false end
	local mapID, x, y = W.Num(d.mapID), W.Num(d.x), W.Num(d.y)
	if not (mapID and mapID > 0) then return false end
	local map = WorldMapFrame
	if not map then return false end
	if W.GamepadUI() and not MapShown() then return false end -- (PST-01 B) it will not open the map
	M.focus = key
	Setup()
	local wasShown = MapShown()
	if not wasShown then M.Open() end
	local function go()
		if not MapShown() then return end
		local api = Stitched() and OMHas("ShowWorld")
		local u, v
		if api and x and y then u, v = WorldUV(mapID, x, y) end
		if u then
			local zoom = GLIDE_ZOOM
			if OMHas("GetView") then
				local ok, _, _, now = pcall(api.GetView)
				now = ok and W.Num(now)
				if now and now > zoom then zoom = now end
			end
			pcall(api.ShowWorld, u, v, zoom)
		else
			M.Open(mapID)
		end
		M.Refresh()
	end
	if not wasShown and OM() then
		W.After(0.05, go) -- OpenMap decides stitched or not as the map opens
	else
		go()
	end
	return true
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------

-- DRIVERS can fire dozens of times a second when many beacons land (review #10): the pins
-- redraw at most every quarter second, once after the burst (a ride change redraws at once).
local REDRAW_GAP = 0.25
local redrawAt, redrawDue = 0, false
M.redraws = 0 -- (tests)
local function redrawSoon()
	if not MapShown() then return end
	if redrawDue then return end
	local t = W.Num(GetTime()) or 0
	local wait = REDRAW_GAP - (t - redrawAt)
	if wait <= 0 then
		redrawAt = t
		M.redraws = M.redraws + 1
		M.Refresh()
		return
	end
	redrawDue = true
	W.After(wait, function()
		redrawDue = false
		redrawAt = W.Num(GetTime()) or 0
		if MapShown() then
			M.redraws = M.redraws + 1
			W.Safe("map redraw", M.Refresh)
		end
	end)
end
M.RedrawSoon = redrawSoon

W.Listen("DRIVERS", redrawSoon)
W.Listen("RIDE", function() if MapShown() then M.Refresh() end end)
W.Listen("SETTINGS", function() if MapShown() or used > 0 then M.Refresh() end end)

W.On("ADDON_LOADED", function(name)
	name = W.Plain(name)
	if name == "Blizzard_WorldMap" or name == "OpenMap" then Setup() end
end)

W.OnLogin(function() Setup() end)

-- internals other modules use (bound at load by later modules, or called late)
Mod.PinLevel = PinLevel
