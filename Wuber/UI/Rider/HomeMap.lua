-- Module: UI.Rider.HomeMap
-- Purpose: Home's map panel: map art, player spot, driver pins on the strip, UI.RouteOnMap, updateMap (also
--   used by Confirm and Found); Dock/Undock move a panel into an unfolded side pane and back (2.3.0).
-- API: UI.RouteOnMap
-- Internals: buildMapPanel, updateMap, Dock, Undock, ownPin, clearOf
-- (2.3.2) Your own pin ("You", a tap opens the Drive tab) on Home's map while you are open as a driver; a
-- panel's m.avoid = { l, r, t, b } (Confirm's back button) keeps the portal pin and driver pins clear of it;
-- (round 37) m.avoid may be a list of such boxes, an entry a function giving its box now (Confirm's route header).
-- (round 37, REV-r37-2) m.visBottom (Confirm's strip; nil = the strip's own visible part, as before): a number or a
-- function giving (bottom, above) now: bottom, the y where the sheet begins (pin tips and the route's ends stay above
-- it); above (optional), the top of what sits just over it (the route header): the rider is centred no lower than 13
-- above that, the map sliding up with the sheet. Read each time the map is laid out; a docked map ignores it.
-- Uses: UI.Kit
-- Later: (none)
-- Events: listens (none); fires (none)
-- Standalone: no
-- Test: tests/ui/rider/homemap_test.lua
-- From: UI.lua 1080-1406 (Wuber 2.2.1)
--
-- Docking (SPEC7 2.8, the `ride` and `confirm` right panes): Mod.Dock(m, holder, opts) re-parents a
-- panel made by buildMapPanel into a side-pane holder (default 360 x 500 at y 44, under the
-- Here/World control, the rider centred in all of it); Mod.Undock(m) puts it back exactly as it
-- was (shown or hidden as it was when docked). Both keep every frame inside the panel at the same
-- level above it (a re-parent re-levels the panel: the dot, zone pill and pins must stay above its art). Both are idempotent and create no frames; the caller redraws (updateMap) after either.
-- m.mapW (nil = WIN_W) is the panel's width everywhere the map is laid out.
local _, W = ...
local Mod = W.Module("UI.Rider.HomeMap", { "UI.Kit" })
local KitMod = W.Mod("UI.Kit")
local MAP_H = KitMod.MAP_H
local N = KitMod.N
local RIDE_RANK = KitMod.RIDE_RANK
local S = KitMod.S
local SHEET_TOP = KitMod.SHEET_TOP
local WIN_W = KitMod.WIN_W
local call = KitMod.call
local clamp = KitMod.clamp
local money = KitMod.money
local onNetwork = KitMod.onNetwork
local ordinal = KitMod.ordinal
local prominence = KitMod.prominence
local rideActive = KitMod.rideActive
local rideView = KitMod.rideView
local safeScript = KitMod.safeScript
local setShown = KitMod.setShown
local ui = KitMod.ui
local T = W.Theme
local A = T.Animate
local Try = T.Try
local UI = W.UI

---------------------------------------------------------------------------
-- Screen: Home (map panel and the bottom sheet of drivers)
---------------------------------------------------------------------------

-- buildMapPanel(parent, height, visible): the map behind Home's sheet (default) or a strip
-- (Found). visible: how much of it shows (the rider is centred in that part).
-- Crop the hero picture to the panel's own shape (again after a Dock or Undock resize).
local function cropHero(m)
	local v0, v1 = 0.04, 0.70
	local w, h = N(m:GetWidth()) or WIN_W, N(m:GetHeight()) or 0
	if h <= 0 then h = m.mapH end
	local aspect = w / h
	local cut = (1 - (512 * (v1 - v0) * aspect) / 1024) / 2
	m.hero:SetTexCoord(cut, 1 - cut, v0, v1)
end

local function buildMapPanel(home, height, visible)
	local m = CreateFrame("Frame", nil, home)
	m:SetPoint("TOPLEFT", home, "TOPLEFT", 0, 0)
	m.mapH = height or MAP_H
	m.visH = visible or SHEET_TOP
	m:SetSize(WIN_W, m.mapH + (height and 0 or 40))
	Try(m, "SetClipsChildren", true)
	m.noEdgeFade = "map" -- a picture cut to its window, not a list (S6's check skips it)
	-- the hero image when there is no map art: the author's scene, darkened
	m.hero = T.Tex(m, "header", "BACKGROUND", -2)
	m.hero:SetAllPoints(m)
	-- the top two thirds of the scene (the portal), never the gold lettering below it
	m.hero:SetVertexColor(0.72, 0.7, 0.8)
	cropHero(m)
	m.canvas = CreateFrame("Frame", nil, m)
	m.canvas:SetSize(WIN_W, m.mapH)
	m.canvas:SetPoint("TOPLEFT", m, "TOPLEFT", 0, 0)
	m.tiles = {}
	m.shade = CreateFrame("Frame", nil, m)
	m.shade:SetAllPoints(m)
	m.shade:SetFrameLevel(m.canvas:GetFrameLevel() + 2)
	local top = T.Tex(m.shade, "fade", "ARTWORK")
	top:SetPoint("TOPLEFT", m, "TOPLEFT")
	top:SetPoint("TOPRIGHT", m, "TOPRIGHT")
	top:SetHeight(56)
	top:SetTexCoord(0, 1, 1, 0)
	top:SetVertexColor(T.RGB("black", 0.8))
	local bottom = T.Tex(m.shade, "fade", "ARTWORK")
	bottom:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT")
	bottom:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT")
	bottom:SetHeight(height and 64 or 110)
	bottom:SetVertexColor(T.RGB("black", 1))
	m.shadeBottom = bottom
	m.dots = CreateFrame("Frame", nil, m)
	m.dots:SetAllPoints(m)
	m.dots:SetFrameLevel(m.canvas:GetFrameLevel() + 4)
	-- where you are: a light pill with a violet dot (the author's pick, 01 v2)
	m.zone = T.Tag(m.dots, "", { fill = { 0.95, 0.93, 1, 0.96 }, text = "ink", dot = "accent", h = 26, size = "sub", pad = 12 })
	m.zone:SetPoint("TOPLEFT", m, "TOPLEFT", 16, -12)
	m.net = T.Chip(m.dots, "Network offline", "amber")
	m.net:SetPoint("TOPRIGHT", m, "TOPRIGHT", -16, -46) -- (HUNT-136) under the round header buttons (they reach 32 into the map)
	m.net:Hide()
	-- the rider
	m.me = CreateFrame("Frame", nil, m.dots)
	m.me:SetSize(14, 14)
	-- (design 1) the "you are here" dot is flat: no blur round it
	m.me.dot = T.Circle(m.me, 14, "white", "OVERLAY")
	m.me.dot:SetPoint("CENTER", m.me, "CENTER")
	m.me.pulse = A.Pulse(m.me, { size = 64, colour = "glow", alpha = 0.3, period = 3, rings = 1, texture = "ring" }) -- flat rings
	m.me:Hide()
	m.pins = {}
	-- during a ride, a look at Home shows the way back to it
	m.ride = T.Pill(m.dots, "", "dark", 230, 30)
	m.ride:SetPoint("TOP", m, "TOP", 0, -44)
	m.ride.icon = T.Icon(m.ride, "summon", 14, "white", "OVERLAY")
	m.ride.icon:SetPoint("LEFT", m.ride, "LEFT", 14, 0)
	safeScript(m.ride, "OnClick", function()
		ui.peek = nil
		UI.Refresh(true)
	end)
	T.Tip(m.ride, "Your ride", "Back to your ride's screen.")
	m.ride:Hide()
	return m
end

local function mapArt(mapID)
	if not (type(C_Map) == "table" and mapID) then return nil end
	local layers = call(C_Map.GetMapArtLayers, mapID)
	local info = type(layers) == "table" and layers[1]
	if type(info) ~= "table" then return nil end
	local lw, lh = N(info.layerWidth), N(info.layerHeight)
	local tw, th = N(info.tileWidth), N(info.tileHeight)
	if not (lw and lh and tw and th) or lw <= 0 or lh <= 0 or tw <= 0 or th <= 0 then return nil end
	local files = call(C_Map.GetMapArtLayerTextures, mapID, 1)
	if type(files) ~= "table" then return nil end
	local cols, rows = math.ceil(lw / tw), math.ceil(lh / th)
	if cols * rows > 64 or cols * rows < 1 then return nil end
	local list = {}
	for i = 1, cols * rows do
		local f = W.Plain(files[i])
		if f == nil then return nil end
		list[i] = f
	end
	return { lw = lw, lh = lh, tw = tw, th = th, cols = cols, rows = rows, files = list }
end

local function playerSpot()
	if type(C_Map) ~= "table" then return nil end
	local mapID = N(call(C_Map.GetBestMapForUnit, "player"))
	if not mapID then return nil end
	local x, y
	local pos = call(C_Map.GetPlayerMapPosition, mapID, "player")
	if pos then
		local ok, px, py = pcall(pos.GetXY, pos)
		if ok then x, y = N(px), N(py) end
	end
	local name
	local info = call(C_Map.GetMapInfo, mapID)
	if type(info) == "table" then name = S(info.name) end
	return mapID, x, y, name
end

local function mapPin(m, i)
	local p = m.pins[i]
	if p then return p end
	p = CreateFrame("Button", nil, m.dots)
	p:SetSize(22, 22)
	p.halo = T.Tex(p, "glow", "BACKGROUND")
	p.halo:SetSize(48, 48)
	p.halo:SetPoint("CENTER", p, "CENTER")
	Try(p.halo, "SetBlendMode", "ADD")
	p.ring = T.Circle(p, 20, "white", "ARTWORK", 0)
	p.ring:SetPoint("CENTER", p, "CENTER")
	p.dot = T.Circle(p, 14, "accent", "ARTWORK", 1)
	p.dot:SetPoint("CENTER", p, "CENTER")
	p.glyph = T.Icon(p, "summon", 10, "white", "OVERLAY")
	p.glyph:SetPoint("CENTER", p, "CENTER")
	p.pulse = A.Pulse(p, { size = 60, colour = "magenta", alpha = 0.4, period = 3, rings = 1, start = false })
	p:RegisterForClicks("LeftButtonUp")
	safeScript(p, "OnClick", function(self)
		if self.key then UI.Show("confirm", self.key) end
	end)
	safeScript(p, "OnEnter", function(self)
		local d = self.key and UI.Driver(self.key)
		if not d then return end
		-- (design 4) Wuber's own tip card (T.TipShow); the words are as they were
		local lines = {}
		if d.creator then lines[#lines + 1] = { "Wuber founder", "gold" } end
		local look = T.PioneerLook(d.key) -- the shipped list only
		if look then lines[#lines + 1] = { T.PIONEER[look].tip, T.PIONEER[look].colour } end
		lines[#lines + 1] = d.name .. " · to " .. d.dest
		lines[#lines + 1] = { money(d.price), "gold" }
		lines[#lines + 1] = { d.state == "open" and "Click to request" or "Click to see this driver", "glow" }
		T.TipShow(self, d.service, lines, "ANCHOR_RIGHT")
	end)
	safeScript(p, "OnLeave", function(self) T.TipHide(self) end)
	T.Press(p)
	m.pins[i] = p
	return p
end

-- (2.3.2, B4) your own pin while you are open as a driver: a violet ring with "You", never a bookable pin (a
-- tap opens the Drive tab). Home's panel only (not Confirm's or Found's strips); hidden when you're not driving.
local function ownPin(m, mapID, cw, ch)
	local b = (not m.strip) and mapID and type(W.DriverBeacon) == "function" and call(W.DriverBeacon) or nil
	local p = m.ownPin
	if type(b) ~= "table" or b.only or N(b.mapID) ~= mapID or not (N(b.x) and N(b.y)) then
		if p then p:Hide() end
		return
	end
	if not p then
		p = CreateFrame("Button", nil, m.dots)
		p:SetSize(26, 26)
		p.halo = T.Tex(p, "glow", "BACKGROUND")
		p.halo:SetSize(60, 60)
		p.halo:SetPoint("CENTER", p, "CENTER")
		p.halo:SetVertexColor(T.RGB("accent", 0.8))
		Try(p.halo, "SetBlendMode", "ADD")
		p.ring = T.Circle(p, 24, "accent", "ARTWORK", 0)
		p.ring:SetPoint("CENTER", p, "CENTER")
		p.dot = T.Circle(p, 18, "accent", "ARTWORK", 1)
		p.dot:SetPoint("CENTER", p, "CENTER")
		p.glyph = T.Icon(p, "summon", 12, "white", "OVERLAY")
		p.glyph:SetPoint("CENTER", p, "CENTER")
		p.tag = T.Tag(p, "You", { h = 18, size = "caption", pad = 7, fill = "card", text = "white" })
		p.tag:SetPoint("TOP", p, "BOTTOM", 0, -2)
		p:RegisterForClicks("LeftButtonUp")
		T.Press(p)
		safeScript(p, "OnClick", function()
			if type(UI.SelectTab) == "function" then UI.SelectTab("Drive") end
		end)
		T.Tip(p, "You, as a driver", "This is where riders see you. You can't book yourself. Click to open the Drive tab.")
		m.ownPin = p
	end
	p:ClearAllPoints()
	p:SetPoint("CENTER", m.canvas, "TOPLEFT", N(b.x) * cw, -N(b.y) * ch)
	p:SetFrameLevel((N(m.dots:GetFrameLevel()) or 0) + 6)
	p:Show()
end

-- (2.3.2, S3) a map pin never sits over the back button: m.avoid = { l, r, t, b } (the button's box in the
-- panel; Confirm's strip). (round 37, REV-r37-1) m.avoid may also be a list of boxes, an entry a function that
-- returns its box now (or nil: nothing there), as Confirm's route header, which moves with the sheet.
local function avoidBoxes(a)
	if a.l then return { a } end
	local out = {}
	for _, e in ipairs(a) do
		if type(e) == "function" then e = call(e) end
		if type(e) == "table" and N(e.l) and N(e.r) and N(e.t) and N(e.b) then out[#out + 1] = e end
	end
	return out
end

-- Returns how far to move a pin centred at sx, sy (panel pixels, y down) right (dx) and down (dy, less than 0:
-- up) to clear every box: past a box it meets by the shorter of two moves, right past it (when the pin then still fits
-- in the panel) or up over it (when the pin's top then stays on the panel), right on a tie or when neither fits, so a pin
-- south-west of the rider's dot is not thrown across it. soft (a box,
-- optional: the you dot) is kept clear only by a pin that had to move (or was moved already: moved): giving way never
-- puts it there.
local function clearOf(m, sx, sy, halfW, above, below, soft, moved)
	local a = m.avoid
	if type(a) ~= "table" or m.docked then return 0, 0 end
	local boxes = avoidBoxes(a)
	if moved and soft then boxes[#boxes + 1], soft = soft, nil end
	local hard = #boxes
	if soft then boxes[hard + 1] = soft end
	local x, y, right = sx, sy, m.mapW or WIN_W
	for _ = 1, #boxes + 1 do
		local moved = false
		for i, b in ipairs(boxes) do
			if (i <= hard or x ~= sx or y ~= sy) and x + halfW > b.l and x - halfW < b.r and y + below > b.t and y - above < b.b then
				moved = true
				-- (2.4 fix round 3) a taller route header (the origin on two lines) leaves less room above it: the gap
				-- over it shrinks from 6 px to what is left, so the pin still goes up when it fits the strip at all
				local gap = math.max(0, math.min(6, b.t - below - above))
				local rightOk, upOk = b.r + 6 + 2 * halfW <= right, b.t - below - above >= 0
				local dx, dy = b.r + 6 + halfW - x, y - (b.t - gap - below)
				if upOk and (not rightOk or dy < dx) then
					y = b.t - gap - below
				else
					x = b.r + 6 + halfW
				end
			end
		end
		if not moved then break end
	end
	return x - sx, y - sy
end

-- (HUNT-116) how far down the map a pin's tip may go. Confirm's strip is built 182 high-visible but its
-- sheet (rounded top) starts 168 down, so there the visible part is 14 less; a docked map shows all.
-- (REV-r37-2) the owner's m.visBottom says where its sheet really begins (higher when the dial lifts it), and the
-- top of the route header over it (above, or nil)
local STRIP_SHEET_OVERLAP = 14
local function visBottom(m)
	local v = m.visH or m.mapH
	if m.strip and not m.docked then
		v = v - STRIP_SHEET_OVERLAP
		local slot = m.visBottom
		local b, above
		if type(slot) == "function" then
			local ok, x, y = pcall(slot)
			if ok then b, above = N(x), N(y) end
		else
			b = N(slot)
		end
		if b then return b, above end
	end
	return v
end
-- the you dot's centre: mid-way down the visible part (as before), or higher when the owner's header sits over it
local ME_CLEAR = 13 -- the dot's half (7) and a 6 px gap
local function riderMid(m)
	local mid = m.visH / 2
	local _, above = visBottom(m)
	if above then mid = math.min(mid, above - ME_CLEAR) end
	-- (design 4, X2) an owner whose dark bar reaches down into the strip sets m.meMin: the dot's centre is never higher up
	if N(m.meMin) then mid = math.max(mid, m.meMin) end
	return mid
end
-- (REV-r37-2) the destination pin (46 x 54, its tip at x, y) whole on a folded strip: off neither side nor the top
local PIN_W, PIN_H, PIN_EDGE = 46, 54, 4
local function pinOnStrip(m, x, y)
	if not m.strip or m.docked then return x, y end
	local w = m.mapW or WIN_W
	return clamp(x, PIN_W / 2 + PIN_EDGE, w - PIN_W / 2 - PIN_EDGE), math.max(y, PIN_H + PIN_EDGE)
end

-- Where a place is on a map (0..1), through world positions when it is on another map.
local function placeOnMap(name, mapID)
	local p = type(W.ExactPlace) == "function" and call(W.ExactPlace, name) or nil
	if type(p) ~= "table" and type(W.FindPlace) == "function" then p = call(W.FindPlace, name) end
	if type(p) ~= "table" then return nil end
	if N(p.mapID) == mapID then return N(p.x), N(p.y) end
	if type(W.PlaceWorld) ~= "function" or type(C_Map) ~= "table" or type(CreateVector2D) ~= "function" then return nil end
	local cont, wx, wy = call(W.PlaceWorld, p)
	if not (N(cont) and N(wx) and N(wy)) then return nil end
	-- returns (uiMapID, position) on this client; (position) on some others
	local ok, a, b = pcall(C_Map.GetMapPosFromWorldPos, cont, CreateVector2D(wx, wy), mapID)
	local pos = type(b) == "table" and b or a
	if not (ok and type(pos) == "table" and type(pos.GetXY) == "function") then return nil end
	local okXY, x, y = pcall(pos.GetXY, pos)
	if not okXY then return nil end
	return N(x), N(y)
end

-- The flowing dotted line (W.Map.RouteOnPanel) from the rider to the ride's destination on
-- a map panel, while a ride is under way. ox: the art's left offset; up: how far it is slid
-- up; cw, ch: its size.
function UI.RouteOnMap(m, mapID, px, py, ox, up, cw, ch)
	local route = W.Map and W.Map.RouteOnPanel
	if type(route) ~= "function" then return end
	local rv = rideView()
	local active = rv and rideActive(rv) and rv.rank < RIDE_RANK.arrived
	-- no ride: the Confirm strip shows the way to the driver's place
	local dest = active and rv.dest or S(m.routeDest)
	local from, to
	if dest and mapID and px and py then
		local dx, dy = placeOnMap(dest, mapID)
		if dx and dy then
			local w, h = m.mapW or WIN_W, N(m:GetHeight()) or m.mapH
			local vb = visBottom(m)
			local function frac(x, y)
				return { clamp((ox + x * cw) / w, 0.03, 0.97), clamp((y * ch - up) / h, 0.05, math.min(0.95, (vb - 6) / h)) }
			end
			from, to = frac(px, py), frac(dx, dy)
		end
	end
	-- Confirm (02 v3): the portal pin's place, clear of m.avoid; the route ends at the pin
	local pin = m.destPin
	local pinX, pinY
	if from and pin then
		local w = m.mapW or WIN_W
		local ph = N(m:GetHeight()) or m.mapH
		pinX, pinY = to[1] * w, to[2] * ph
		local me = px and py and { l = ox + px * cw - 9, r = ox + px * cw + 9, t = py * ch - up - 9, b = py * ch - up + 9 }
		-- (REV-r37-2) whole on the strip; a pin moved there gives way to the you dot too
		local sx, sy = pinOnStrip(m, pinX, pinY)
		local moved = sx ~= pinX or sy ~= pinY
		pinX, pinY = sx, sy
		local dx, dy = clearOf(m, pinX, pinY - 27, 23, 27, 27, me, moved)
		if moved or dx ~= 0 or dy ~= 0 then
			pinX, pinY = pinX + dx, pinY + dy
			to = { pinX / w, pinY / ph }
		end
	end
	if from then
		m.route = call(route, m, from, to, { level = 3 })
	elseif m.route or m.routed then
		call(route, m, nil, nil)
	end
	m.routed = from ~= nil
	-- Confirm (02 v3): a glowing portal pin where the route ends
	if pin then
		if from then
			pin:ClearAllPoints()
			pin:SetPoint("BOTTOM", m, "TOPLEFT", pinX, -pinY)
			if not pin:IsShown() then A.FadeIn(pin, 0.3) end
		else
			pin:Hide()
		end
	end
end

local function updateMap(m, list)
	local mapID, px, py, zone = playerSpot()
	if m.ride then
		local rv = rideView()
		local on = not m.strip and rv ~= nil and rideActive(rv)
		if on then
			local pos = rv.position
			if pos and pos >= 1 and rv.rank < RIDE_RANK.summoning and rv.rank >= RIDE_RANK.accepted then
				m.ride:SetLabel((pos == 1 and "You're next" or ("You're " .. ordinal(pos) .. " in line")) .. " · " .. rv.short)
			else
				m.ride:SetLabel("Your ride · " .. rv.short .. " to " .. rv.dest)
			end
		end
		setShown(m.ride, on)
	end
	if not m.strip then
		m.zone:SetTag(zone or "Azeroth")
		-- (round 20, B7) the location pill pokes out from behind the raincheck sheet: hidden while it shows
		local rc = ui.rcOffer
		setShown(m.zone, not (rc and rc:IsShown()))
		setShown(m.net, not onNetwork())
	end
	local art = mapID and (m.artFor == mapID and m.art or mapArt(mapID))
	m.artFor, m.art = mapID, art
	local pins = 0
	if art then
		m.hero:Hide()
		local mw = m.mapW or WIN_W
		local k = mw / (0.42 * art.lw)
		local cw, ch = art.lw * k, art.lh * k
		local tw, th = art.tw * k, art.th * k
		for i = 1, art.cols * art.rows do
			local t = m.tiles[i]
			if not t then
				t = m.canvas:CreateTexture(nil, "ARTWORK")
				Try(t, "SetDesaturated", true)
				t:SetVertexColor(0.36, 0.33, 0.52) -- a night-violet map
				m.tiles[i] = t
			end
			local col, row = (i - 1) % art.cols, math.floor((i - 1) / art.cols)
			if t.file ~= art.files[i] then
				t:SetTexture(art.files[i])
				t.file = art.files[i]
			end
			t:SetSize(tw, th)
			T.PlaceOnce(t, "TOPLEFT", m.canvas, "TOPLEFT", col * tw, -row * th)
			t:Show()
		end
		for i = art.cols * art.rows + 1, #m.tiles do m.tiles[i]:Hide() end
		m.canvas:SetSize(cw, ch)
		-- the rider in the middle of the visible part (the sheet covers the bottom)
		local fx, fy = px or 0.5, py or 0.5
		local ox = clamp(mw / 2 - fx * cw, math.min(0, mw - cw), 0)
		-- the canvas slides up (a positive offset) until the rider sits mid-way down the view (REV-r37-2: higher, and
		-- the map further up, when Confirm's lifted sheet and its route header cover the middle)
		local mid = riderMid(m)
		local up = clamp(fy * ch - mid, 0, math.max(0, math.max(0, ch - m.mapH) + m.visH / 2 - mid))
		m.canvas:ClearAllPoints()
		m.canvas:SetPoint("TOPLEFT", m, "TOPLEFT", ox, up)
		m.canvas:Show()
		if px and py then
			m.me:ClearAllPoints()
			m.me:SetPoint("CENTER", m.canvas, "TOPLEFT", px * cw, -py * ch)
			if not m.me:IsShown() then
				m.me:Show()
				if not m.noPulse then m.me.pulse:Start() end -- (run 1, item 10) the ride page's portal looks stand it still
			end
		else
			m.me:Hide()
		end
		for _, d in ipairs(list) do
			if d.mapID == mapID and d.x and d.y and pins < 24 then
				pins = pins + 1
				local p = mapPin(m, pins)
				p.key = d.key
				p:ClearAllPoints()
				local pdx, pdy = clearOf(m, ox + d.x * cw, d.y * ch - up, 15, 15, 15)
				p:SetPoint("CENTER", m.canvas, "TOPLEFT", d.x * cw + pdx, -d.y * ch - pdy)
				local colour = d.state == "open" and "accent" or (d.state == "busy" and "amber" or "off")
				p.dot:SetVertexColor(T.RGB(colour))
				local glow = prominence(d, list)
				local size = d.creator and 30 or 22
				p:SetSize(size, size)
				p.ring:SetSize(size - 2, size - 2)
				p.dot:SetSize(size - 8, size - 8)
				p.ring:SetVertexColor(T.RGB(d.creator and "gold" or "white"))
				p.halo:SetSize(size * 2.4, size * 2.4)
				p.halo:SetVertexColor(T.RGB(d.creator and "gold" or "magenta", d.creator and 0.9 or glow * 0.8))
				if d.creator then
					if not p.crown then p.crown = T.Crown(p, 18, d.key) end
					p.crown:ClearAllPoints()
					p.crown:SetPoint("BOTTOM", p, "TOP", 0, -4)
					p.crown:Show()
				elseif p.crown then
					p.crown:Hide()
				end
				p:SetFrameLevel((N(m.dots:GetFrameLevel()) or 0) + (d.creator and 5 or 1))
				if d.state == "open" then
					if not p.pulse.running then p.pulse:Start() end
				elseif p.pulse.running then
					p.pulse:Stop()
				end
				p:Show()
			end
		end
		ownPin(m, mapID, cw, ch)
		UI.RouteOnMap(m, mapID, px, py, ox, up, cw, ch)
	else
		if m.ownPin then m.ownPin:Hide() end
		m.hero:Show()
		m.canvas:Hide()
		m.me:Hide()
		UI.RouteOnMap(m, nil)
	end
	for i = pins + 1, #m.pins do
		local p = m.pins[i]
		if p:IsShown() then
			p.pulse:Stop()
			p:Hide()
		end
	end
end

---------------------------------------------------------------------------
-- Docking into an unfolded side pane and back
---------------------------------------------------------------------------

-- (p242 r3 F) top 44, not 32: the window's round buttons (fold, cog, x) run from 12 to 44 down the pane, so a map that
-- began at 32 had them half over its top edge; now it begins under them (bottom stays at 544).
local DOCK = { w = 360, h = 500, top = 44, overlayTop = 56, shade = 64 }

-- m: a panel from buildMapPanel; holder: the side pane's holder. opts: w, h (the map's size),
-- vis (the part the rider is centred in; default h), top (y of the panel in holder),
-- overlayTop (y of the zone tag and network chip). Returns m.
-- Every frame inside m, with its level above m's (a move to another parent re-levels m; the
-- overlays - zone pill, rider dot, pins - must stay above its map art, as they were).
local function subLevels(m)
	local out, base = {}, N(m:GetFrameLevel()) or 0
	local function walk(f, depth)
		if depth > 4 then return end
		for _, c in ipairs({ f:GetChildren() }) do
			out[#out + 1] = { c, (N(c:GetFrameLevel()) or base) - base }
			walk(c, depth + 1)
		end
	end
	walk(m, 1)
	return out
end

local function restoreLevels(m, list)
	local base = N(m:GetFrameLevel()) or 0
	for _, e in ipairs(list) do e[1]:SetFrameLevel(math.max(0, math.min(10000, base + e[2]))) end
end

local function Dock(m, holder, opts)
	if not (m and holder) then return nil end
	opts = opts or {}
	if not m.undocked then
		local pts = {}
		for i = 1, (N(m:GetNumPoints()) or 0) do pts[i] = { m:GetPoint(i) } end
		m.undocked = { parent = m:GetParent(), points = pts, w = m:GetWidth(), h = m:GetHeight(), mapW = m.mapW,
			mapH = m.mapH, visH = m.visH, canvasW = m.canvas:GetWidth(), canvasH = m.canvas:GetHeight(),
			shade = m.shadeBottom and m.shadeBottom:GetHeight() or nil, shown = m:IsShown() }
	end
	local w, h = N(opts.w) or DOCK.w, N(opts.h) or DOCK.h
	local lv = m.docked ~= holder and subLevels(m) or nil
	m:SetParent(holder)
	if lv then restoreLevels(m, lv) end
	m:ClearAllPoints()
	m:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(N(opts.top) or DOCK.top))
	m:SetSize(w, h)
	m.mapW, m.mapH, m.visH = w, h, N(opts.vis) or h
	m.canvas:SetSize(w, h)
	cropHero(m)
	if m.shadeBottom then m.shadeBottom:SetHeight(DOCK.shade) end
	local oy = N(opts.overlayTop) or DOCK.overlayTop
	if m.zone and not m.strip then
		m.zone:ClearAllPoints()
		m.zone:SetPoint("TOPLEFT", m, "TOPLEFT", 16, -(oy - (N(opts.top) or DOCK.top)))
	end
	if m.net and not m.strip then
		m.net:ClearAllPoints()
		m.net:SetPoint("TOPRIGHT", m, "TOPRIGHT", -16, -(oy - (N(opts.top) or DOCK.top)))
	end
	m.docked = holder
	return m
end

-- Back where it was (the folded layout, pixel for pixel).
local function Undock(m)
	local u = m and m.undocked
	if not u then return m end
	local lv = subLevels(m)
	m:SetParent(u.parent)
	restoreLevels(m, lv)
	m:ClearAllPoints()
	for _, p in ipairs(u.points) do m:SetPoint(unpack(p)) end
	m:SetSize(u.w, u.h)
	m.mapW, m.mapH, m.visH = u.mapW, u.mapH, u.visH
	m.canvas:SetSize(u.canvasW, u.canvasH)
	cropHero(m)
	if m.shadeBottom and u.shade then m.shadeBottom:SetHeight(u.shade) end
	if m.zone and not m.strip then
		m.zone:ClearAllPoints()
		m.zone:SetPoint("TOPLEFT", m, "TOPLEFT", 16, -12)
	end
	if m.net and not m.strip then
		m.net:ClearAllPoints()
		m.net:SetPoint("TOPRIGHT", m, "TOPRIGHT", -16, -46) -- (HUNT-136) under the round header buttons (they reach 32 into the map)
	end
	setShown(m, u.shown ~= false)
	m.undocked, m.docked = nil, nil
	return m
end

-- internals other modules use (bound at load by later modules, or called late)
Mod.buildMapPanel = buildMapPanel
Mod.updateMap = updateMap
Mod.Dock, Mod.Undock = Dock, Undock
