-- Wuber: drivers on the world map, both on Blizzard's map and on OpenMap's stitched map.
-- Each driver is a round pin (black circle, white summon glyph, a soft pulse while open,
-- grey while busy or paused). Hover: who, where to, how much. Click: the Wuber window opens
-- on Confirm for that driver; nothing else is closed.
--
-- W.Map.Refresh()            redraw the pins (cheap; does nothing while the map is closed)
-- W.Map.ShowDriver(key)      open the world map on that driver (OpenMap: glide there)
-- W.Map.SetShown(on)         pins on or off (W.db.mapPins)

local _, W = ...

local M = {}
W.Map = M

local MEDIA = "Interface\\AddOns\\" .. tostring(W.ADDON or "Wuber") .. "\\Media\\"
local PIN = 24           -- the pin's size on screen, whatever the zoom
local TICK = 0.1         -- 10 Hz while the map is open
local GLIDE_ZOOM = 4     -- OpenMap: at least this close when showing a driver
local LEVEL_ABOVE = 500  -- pins sit this far above the canvas (Blizzard's own pins stay below)

-- the rider's ride is under way in these states: its driver is the chosen one
local LIVE = { requesting = true, accepted = true, invited = true, ingroup = true, summoning = true,
	portal = true, arrived = true, paying = true }

-- the accent: violet to magenta, as the Wuber icon
local function hex(h)
	return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 }
end
-- the author's logo colours
local VIOLET = hex("883FDA")
local MAGENTA = hex("E467FC")
local BRIGHT = hex("CD7DF5")
local GOLD = hex("F9C53E")
local AMBER = hex("F9A23E")
local PAUSED = hex("6B6585")
local FILL = hex("161628")    -- the pin: black-violet
local TEXT = hex("F2EEFF")
local MUTED = hex("9A93B8")

-- open drivers draw above busy ones, busy above paused
local STATE_LEVEL = { open = 8, busy = 4, paused = 0 } -- each pin uses four levels

local pins = {}          -- the pool: every pin frame ever made, reused for ever
local used = 0           -- pins[1..used] show a driver now
local ticker             -- the 10 Hz frame (a child of WorldMapFrame: runs only while it shows)
local hooked, omDone = false, false
local lastMap, lastStitched, lastW, lastH, lastS
local contCache = {}     -- uiMapID -> continentID or false

M.focus = nil            -- the driver ShowDriver last showed (highlighted until a ride says otherwise)

---------------------------------------------------------------------------
-- Small guarded helpers
---------------------------------------------------------------------------

local function call(obj, method, ...)
	if obj == nil then return false end
	local f = obj[method]
	if type(f) ~= "function" then return false end
	return pcall(f, obj, ...)
end

-- the x, y of a vector the game handed over (nil if secret or not a vector)
local function XY(vec)
	vec = W.Plain(vec)
	if type(vec) ~= "table" then return nil end
	local f = vec.GetXY
	if type(f) ~= "function" then return nil end
	local ok, x, y = pcall(f, vec)
	if not ok then return nil end
	x, y = W.Num(x), W.Num(y)
	if x and y then return x, y end
	return nil
end

local function Canvas()
	local map = WorldMapFrame
	local sc = map and map.ScrollContainer
	local child = sc and sc.Child
	if type(child) == "table" and type(child.GetWidth) == "function" then return child end
	return nil
end

local function MapShown()
	local ok, shown = call(WorldMapFrame, "IsShown")
	return ok and W.Plain(shown) and true or false
end

local function ShownMapID()
	local ok, id = call(WorldMapFrame, "GetMapID")
	return ok and W.Num(id) or nil
end

local function PinsOn()
	return not (W.db and W.db.mapPins == false)
end

---------------------------------------------------------------------------
-- OpenMap (optional): API major 1; ArtTopLevel from version 2
---------------------------------------------------------------------------

local function OM()
	local api = OpenMapAPI
	if type(api) == "table" and api.major == 1 then return api end
	return nil
end

local function OMHas(name, version)
	local api = OM()
	if not (api and type(api[name]) == "function") then return nil end
	if version and not (type(api.version) == "number" and api.version >= version) then return nil end
	return api
end

local function Stitched()
	local api = OMHas("IsStitched")
	if not api then return false end
	local ok, on = pcall(api.IsStitched)
	return ok and W.Plain(on) == true
end

local function WorldUV(mapID, x, y)
	local api = OMHas("WorldFromMap")
	if not api then return nil end
	local ok, u, v = pcall(api.WorldFromMap, mapID, x, y)
	if not ok then return nil end
	u, v = W.Num(u), W.Num(v)
	if u and v then return u, v end
	return nil
end

-- a driver's place on the stitched canvas (may lie outside 0..1: the view shows past the host map)
local function OpenMapPos(mapID, x, y, shown)
	local api = OMHas("MapFromWorld")
	if not api then return nil end
	local u, v = WorldUV(mapID, x, y)
	if not u then return nil end
	local ok, cx, cy = pcall(api.MapFromWorld, shown, u, v)
	if not ok then return nil end
	cx, cy = W.Num(cx), W.Num(cy)
	if cx and cy then return cx, cy end
	return nil
end

---------------------------------------------------------------------------
-- Blizzard's map: the driver's own map, or a map that holds it (through world coordinates)
---------------------------------------------------------------------------

local function WorldPos(mapID, x, y)
	if not (C_Map and type(C_Map.GetWorldPosFromMapPos) == "function" and type(CreateVector2D) == "function") then
		return nil
	end
	local ok, vec = pcall(CreateVector2D, x, y)
	if not ok or vec == nil then return nil end
	local ok2, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, vec)
	if not ok2 then return nil end
	cont, pos = W.Num(cont), W.Plain(pos)
	if not cont or pos == nil then return nil end
	return cont, pos
end

local function ContinentOf(mapID)
	local c = contCache[mapID]
	if c == nil then
		c = WorldPos(mapID, 0.5, 0.5) or false
		contCache[mapID] = c
	end
	return c or nil
end

local function BlizzardPos(mapID, x, y, shown)
	if mapID == shown then return x, y end
	if not (C_Map and type(C_Map.GetMapPosFromWorldPos) == "function") then return nil end
	local cont, pos = WorldPos(mapID, x, y)
	if not cont then return nil end
	local shownCont = ContinentOf(shown)
	if shownCont and shownCont ~= cont then return nil end -- another continent
	local ok, a, b = pcall(C_Map.GetMapPosFromWorldPos, cont, pos, shown)
	if not ok then return nil end
	-- the game returns uiMapID, position; take the vector wherever it is
	local px, py = XY(b)
	if not px then px, py = XY(a) end
	if not px or px < 0 or px > 1 or py < 0 or py > 1 then return nil end
	return px, py
end

---------------------------------------------------------------------------
-- The drivers
---------------------------------------------------------------------------

local function Drivers()
	if type(W.DriversSorted) == "function" then
		local ok, list = pcall(W.DriversSorted)
		if ok and type(list) == "table" then return list end
	end
	local list = {}
	if type(W.drivers) == "table" then
		for k, d in pairs(W.drivers) do
			if type(d) == "table" then list[#list + 1] = d end
		end
		table.sort(list, function(a, b) return tostring(a.key) < tostring(b.key) end)
	end
	return list
end

local function Driver(key)
	if key == nil or type(W.drivers) ~= "table" then return nil end
	local d = W.drivers[key]
	if type(d) == "table" then return d end
	return nil
end

local function Chosen()
	local ride = W.ride
	if type(ride) == "table" and LIVE[ride.state] and ride.driverKey then return ride.driverKey end
	if M.focus and Driver(M.focus) then return M.focus end
	return nil
end

local function Text(v, fallback)
	return W.Str(v) or fallback
end

-- violet to magenta across a texture (falls back to plain violet)
local function Accent(t, alpha)
	local done = false
	if type(CreateColor) == "function" then
		done = pcall(t.SetGradient, t, "HORIZONTAL", CreateColor(VIOLET[1], VIOLET[2], VIOLET[3], alpha),
			CreateColor(MAGENTA[1], MAGENTA[2], MAGENTA[3], alpha))
	end
	if not done and t.SetGradientAlpha then
		done = pcall(t.SetGradientAlpha, t, "HORIZONTAL", VIOLET[1], VIOLET[2], VIOLET[3], alpha,
			MAGENTA[1], MAGENTA[2], MAGENTA[3], alpha)
	end
	if not done then t:SetVertexColor(VIOLET[1], VIOLET[2], VIOLET[3], alpha) end
end

local function ScaleTo(a, from, to)
	local f = a.SetScaleFrom or a.SetFromScale
	local t = a.SetScaleTo or a.SetToScale
	if f then f(a, from, from) end
	if t then t(a, to, to) end
end

---------------------------------------------------------------------------
-- Pins
---------------------------------------------------------------------------

local function Tooltip(pin)
	local tip = GameTooltip
	local d = Driver(pin.key)
	if not (tip and d) then return end
	local name = Text(d.name, "?")
	local service = Text(d.service, name)
	tip:SetOwner(pin, "ANCHOR_RIGHT")
	tip:AddLine(service, TEXT[1], TEXT[2], TEXT[3])
	if service ~= name then tip:AddLine(name, MUTED[1], MUTED[2], MUTED[3]) end
	tip:AddLine("To " .. Text(d.dest, "?"), TEXT[1], TEXT[2], TEXT[3])
	tip:AddLine(W.Money(W.Num(d.price) or 0), GOLD[1], GOLD[2], GOLD[3])
	if d.state == "busy" then
		tip:AddLine("Busy right now", AMBER[1], AMBER[2], AMBER[3])
	elseif d.state == "paused" then
		tip:AddLine("Paused", PAUSED[1], PAUSED[2], PAUSED[3])
	end
	local team = W.Num(d.team) or 1
	if team >= 3 then
		tip:AddLine("No helpers needed", MUTED[1], MUTED[2], MUTED[3])
	else
		local n = 3 - math.max(1, math.floor(team))
		tip:AddLine("Bring " .. n .. (n == 1 and " helper" or " helpers"), MUTED[1], MUTED[2], MUTED[3])
	end
	if W.Num(d.seats) == 0 then tip:AddLine("Group full", MUTED[1], MUTED[2], MUTED[3]) end
	if W.myKey and pin.key == W.myKey then
		tip:AddLine("This is you", MUTED[1], MUTED[2], MUTED[3])
	elseif d.state == "paused" then
		tip:AddLine("Can't take requests now", MUTED[1], MUTED[2], MUTED[3])
	else
		tip:AddLine("Click to request", BRIGHT[1], BRIGHT[2], BRIGHT[3])
	end
	tip:Show()
end

-- size and place one pin: constant size on screen (1 / canvas scale), centred on its spot
local function Place(pin, child, w, h, s)
	local scale = (1 / s) * (pin.chosen and 1.25 or 1) * (pin.hover and 1.15 or 1)
	pin:SetScale(scale)
	pin:ClearAllPoints()
	-- offsets are in the pin's own (scaled) units
	pin:SetPoint("CENTER", child, "TOPLEFT", pin.nx * w / scale, -pin.ny * h / scale)
end

local function CanvasMetrics(child)
	local okw, w = call(child, "GetWidth")
	local okh, h = call(child, "GetHeight")
	local oks, s = call(child, "GetScale")
	w, h, s = okw and W.Num(w), okh and W.Num(h), oks and W.Num(s)
	if not (w and h and w > 0 and h > 0) then return nil end
	if not (s and s > 0) then s = 1 end
	return w, h, s
end

local function PlaceOne(pin)
	local child = Canvas()
	if not child then return end
	local w, h, s = CanvasMetrics(child)
	if w then Place(pin, child, w, h, s) end
end

local function SetLevels(pin, level)
	if pin.level == level then return end
	pin.level = level
	pin:SetFrameLevel(level)
	pin.pulse:SetFrameLevel(level + 1)
	pin.body:SetFrameLevel(level + 2)
	pin.tag:SetFrameLevel(level + 3)
end

local function StartPulse(pin)
	if pin.pulsing then return end
	pin.pulsing = true
	pin.pulse:Show()
	pin.pulseAnim:Play()
end

local function StopPulse(pin)
	if not pin.pulsing then return end
	pin.pulsing = false
	pin.pulseAnim:Stop()
	pin.pulse:Hide()
end

local function NewPin(parent)
	local pin = CreateFrame("Button", nil, parent)
	pin:SetSize(PIN, PIN)
	pin:EnableMouse(true)
	pin:RegisterForClicks("LeftButtonUp")

	-- the soft ring that grows and fades while the driver is open
	local pulse = CreateFrame("Frame", nil, pin)
	pulse:SetSize(PIN, PIN)
	pulse:SetPoint("CENTER", pin, "CENTER", 0, 0)
	local soft = pulse:CreateTexture(nil, "BACKGROUND")
	soft:SetSize(PIN * 1.4, PIN * 1.4)
	soft:SetPoint("CENTER", pulse, "CENTER", 0, 0)
	soft:SetTexture(MEDIA .. "glow")
	Accent(soft, 0.55)
	local ring = pulse:CreateTexture(nil, "ARTWORK")
	ring:SetAllPoints(pulse)
	ring:SetTexture(MEDIA .. "ring")
	Accent(ring, 1)
	local ag = pulse:CreateAnimationGroup()
	ag:SetLooping("REPEAT")
	local grow = ag:CreateAnimation("Scale")
	ScaleTo(grow, 0.8, 2.1)
	grow:SetDuration(1.8)
	grow:SetSmoothing("OUT")
	local fade = ag:CreateAnimation("Alpha")
	fade:SetFromAlpha(0.7)
	fade:SetToAlpha(0)
	fade:SetDuration(1.8)
	fade:SetSmoothing("OUT")
	pulse:Hide()
	pin.pulse, pin.pulseAnim = pulse, ag

	-- the pin itself
	local body = CreateFrame("Frame", nil, pin)
	body:SetAllPoints(pin)
	local shadow = body:CreateTexture(nil, "BACKGROUND")
	shadow:SetSize(PIN * 1.7, PIN * 1.7)
	shadow:SetPoint("CENTER", body, "CENTER", 0, -2)
	shadow:SetTexture(MEDIA .. "shadow")
	shadow:SetVertexColor(0, 0, 0, 0.6)
	local halo = body:CreateTexture(nil, "BORDER")
	halo:SetSize(PIN + 12, PIN + 12)
	halo:SetPoint("CENTER", body, "CENTER", 0, 0)
	halo:SetTexture(MEDIA .. "ring")
	halo:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1) -- the chosen driver: a gold ring
	halo:Hide()
	local edge = body:CreateTexture(nil, "ARTWORK")
	edge:SetAllPoints(body)
	edge:SetTexture(MEDIA .. "circle")
	edge:SetVertexColor(1, 1, 1, 1)
	local fill = body:CreateTexture(nil, "OVERLAY", nil, 1)
	fill:SetSize(PIN - 4, PIN - 4)
	fill:SetPoint("CENTER", body, "CENTER", 0, 0)
	fill:SetTexture(MEDIA .. "circle")
	fill:SetVertexColor(FILL[1], FILL[2], FILL[3], 1)
	-- the face: the author's portal art, or the white summon glyph if that file isn't there
	local glyph = body:CreateTexture(nil, "OVERLAY", nil, 2)
	glyph:SetPoint("CENTER", body, "CENTER", 0, 0)
	local okp, loaded = pcall(glyph.SetTexture, glyph, MEDIA .. "portal")
	pin.portal = okp and loaded ~= false
	if pin.portal then
		glyph:SetSize(PIN - 6, PIN - 6)
	else
		glyph:SetTexture(MEDIA .. "summon")
		glyph:SetSize(PIN * 0.6, PIN * 0.6)
	end
	pin.body, pin.halo, pin.fill, pin.glyph, pin.edge = body, halo, fill, glyph, edge

	-- the price tag under the chosen driver's pin
	local tag = CreateFrame("Frame", nil, pin)
	tag:SetSize(44, 16)
	tag:SetPoint("TOP", pin, "BOTTOM", 0, -3)
	local tl = tag:CreateTexture(nil, "BACKGROUND")
	tl:SetSize(8, 16)
	tl:SetPoint("LEFT", tag, "LEFT", 0, 0)
	tl:SetTexture(MEDIA .. "circle")
	tl:SetTexCoord(0, 0.5, 0, 1)
	tl:SetVertexColor(FILL[1], FILL[2], FILL[3], 1)
	local tr = tag:CreateTexture(nil, "BACKGROUND")
	tr:SetSize(8, 16)
	tr:SetPoint("RIGHT", tag, "RIGHT", 0, 0)
	tr:SetTexture(MEDIA .. "circle")
	tr:SetTexCoord(0.5, 1, 0, 1)
	tr:SetVertexColor(FILL[1], FILL[2], FILL[3], 1)
	local tm = tag:CreateTexture(nil, "BACKGROUND")
	tm:SetPoint("TOPLEFT", tag, "TOPLEFT", 8, 0)
	tm:SetPoint("BOTTOMRIGHT", tag, "BOTTOMRIGHT", -8, 0)
	tm:SetColorTexture(FILL[1], FILL[2], FILL[3], 1)
	local text = tag:CreateFontString(nil, "OVERLAY")
	local T = W.Theme
	if not (type(T) == "table" and type(T.SetFont) == "function" and pcall(T.SetFont, text, 11, "bold")) then
		local okf, set = pcall(text.SetFont, text, "Fonts\\ARIALN.TTF", 11, "")
		if (not okf or set == false) and GameFontNormal then pcall(text.SetFontObject, text, GameFontNormal) end
	end
	text:SetPoint("CENTER", tag, "CENTER", 0, 0)
	text:SetTextColor(GOLD[1], GOLD[2], GOLD[3], 1)
	tag:Hide()
	pin.tag, pin.tagText = tag, text

	pin:SetScript("OnEnter", function(self)
		W.Safe("map pin", function()
			self.hover = true
			PlaceOne(self)
			Tooltip(self)
		end)
	end)
	pin:SetScript("OnLeave", function(self)
		W.Safe("map pin", function()
			self.hover = false
			PlaceOne(self)
			if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
		end)
	end)
	pin:SetScript("OnClick", function(self)
		W.Safe("map pin", function()
			local key = self.key
			local d = Driver(key)
			if not key or not d or d.state == "paused" or (W.myKey and key == W.myKey) then return end
			if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
			W.Sound("click")
			if W.UI and type(W.UI.Show) == "function" then W.UI.Show("confirm", key) end
		end)
	end)
	pin:Hide()
	return pin
end

local function Desaturate(t, on)
	if t.SetDesaturated then pcall(t.SetDesaturated, t, on) end
end

local function Paint(pin, d, chosen)
	local state = d.state
	pin.chosen = chosen
	-- the rim says the state: open bright violet (and the pulse), busy amber, paused grey-violet
	local rim = state == "open" and BRIGHT or (state == "busy" and AMBER or PAUSED)
	pin.edge:SetVertexColor(rim[1], rim[2], rim[3], 1)
	if state == "open" then
		pin.glyph:SetVertexColor(1, 1, 1, 1)
		if pin.portal then Desaturate(pin.glyph, false) end
		pin.body:SetAlpha(1)
		StartPulse(pin)
	else
		pin.glyph:SetVertexColor(0.85, 0.85, 0.85, state == "paused" and 0.7 or 0.9)
		if pin.portal then Desaturate(pin.glyph, state == "paused") end
		pin.body:SetAlpha(state == "paused" and 0.65 or 1)
		StopPulse(pin)
	end
	if chosen then
		pin.halo:Show()
		local price = W.Money(W.Num(d.price) or 0)
		pin.tagText:SetText(price)
		pin.tag:SetWidth(math.max(36, #price * 6 + 18))
		pin.tag:Show()
	else
		pin.halo:Hide()
		pin.tag:Hide()
	end
end

local function Release(pin)
	pin:Hide()
	pin.key, pin.hover, pin.chosen = nil, false, false
	StopPulse(pin)
end

local function HideAll()
	for i = 1, used do Release(pins[i]) end
	used = 0
	if GameTooltip and GameTooltip.GetOwner then
		local ok, owner = pcall(GameTooltip.GetOwner, GameTooltip)
		for i = 1, #pins do
			if ok and owner == pins[i] then GameTooltip:Hide() break end
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

local Setup

function M.Refresh()
	if Setup then Setup() end
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
	local chosenKey = Chosen()
	local list = Drivers()
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
				SetLevels(pin, level + (chosen and 12 or (STATE_LEVEL[d.state] or 0)))
				Paint(pin, d, chosen)
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
		end
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
	ticker = CreateFrame("Frame", nil, map)
	ticker:SetScript("OnUpdate", Tick)
	map:HookScript("OnShow", function() W.Safe("map show", M.Refresh) end)
	map:HookScript("OnHide", function() W.Safe("map hide", HideAll) end)
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
	M.focus = key
	Setup()
	local wasShown = MapShown()
	if not wasShown then
		local ok = false
		if type(ShowUIPanel) == "function" then ok = pcall(ShowUIPanel, map) end
		if not ok or not MapShown() then call(map, "Show") end
	end
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
			call(map, "SetMapID", mapID)
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

W.Listen("DRIVERS", function() if MapShown() then M.Refresh() end end)
W.Listen("RIDE", function() if MapShown() then M.Refresh() end end)
W.Listen("SETTINGS", function() if MapShown() or used > 0 then M.Refresh() end end)

W.On("ADDON_LOADED", function(name)
	name = W.Plain(name)
	if name == "Blizzard_WorldMap" or name == "OpenMap" then Setup() end
end)

W.OnLogin(function() Setup() end)
