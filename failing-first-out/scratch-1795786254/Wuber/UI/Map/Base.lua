-- Module: UI.Map.Base
-- Purpose: World-map constants, colours, guarded helpers, OpenMap and Blizzard map positions, the driver
--   list for pins.
-- API: W.Map, M.focus
-- Internals: AMBER, Accent, BRIGHT, BadgeInfo, BlizzardPos, CHOSEN_LEVEL, CREATOR_LEVEL, CREATOR_SCALE,
--   Canvas, Chosen, ClickOver, DOT, Driver, Drivers, FILL, FLOW, GAP, GLIDE_ZOOM, GOLD, IsFav, LEVEL_ABOVE, MAGENTA,
--   MAX_DOTS, MEDIA, MUTED, MapShown, MapXY, NewFrame, OM, OMHas, OpenMapPos, PAUSED, PIN, PinsOn, PriceRanks,
--   Prominence, ROUTE, STATE_LEVEL, ScaleTo, Seed, ShownMapID, Stitched, TEXT, TICK, Text, VIOLET, World,
--   WorldUV, XY, call, hex, pins, plainIcon
-- Uses: (none: Core via W)
-- Later: (none)
-- Events: listens (none); fires (none)
-- Standalone: yes
-- Test: tests/ui/map/base_test.lua
-- From: Map.lua 1-381 (its pin and tick state locals, lines 68-71, moved to UI.Map.Map) (Wuber 2.2.1)
--
-- Wuber: drivers on the world map, both on Blizzard's map and on OpenMap's stitched map.
-- Each driver is a round pin (black circle, white summon glyph, grey while busy or paused).
-- The cheaper an open driver, the stronger its violet glow (W.Prominence); the creator's pin
-- is bigger, crowned, gold-ringed and sparkles. Badges, favourite hearts; hidden drivers are
-- not drawn. Hover: who, where to, how much. Click: the Wuber window opens on Confirm for
-- that driver; nothing else is closed. While a ride is under way (requesting..portal) an
-- animated dotted violet line runs from the rider to the destination.
--
-- W.Map.Refresh()            redraw the pins and the route (cheap; nothing while the map is closed)
-- W.Map.ShowDriver(key)      open the world map on that driver (OpenMap: glide there)
-- W.Map.Open([mapID])        the one way Wuber opens the world map: the game's safe opener, never in combat
-- W.Map.SetShown(on)         pins on or off (W.db.mapPins)
-- W.Map.RouteOnPanel(frame, fromXY, toXY [, opts])
--                            the same flowing dotted line on any frame (Home's mini map):
--                            fromXY/toXY = { x, y } (or { x = , y = }) as fractions 0..1 of
--                            the frame from its top-left corner; nil hides it. opts: dot, gap
--                            (pixels), level (above the frame), alpha. Returns a handle with
--                            :Hide(); also W.Map.HideRouteOnPanel(frame).
-- W.Map.PlaceUnderCursor([wide])  the W.PLACES entry under the cursor on the world map, or nil
--                            (wide: a click's wider search: the zone's nearest or main place)
-- W.Map.BookPlace(place|name)     opens Wuber on a place (UI's "book" screen, else Home + search)
-- Book from the map: hovering a known place shows "Ride here · 2 drivers · from 50s" by the
-- cursor and a "Ride here" button in the map's corner; Ctrl-click books it.

local _, W = ...
local Mod = W.Module("UI.Map.Base", {})

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
-- the route line shows while the rider is still on the way
local ROUTE = { requesting = true, accepted = true, invited = true, ingroup = true, summoning = true, portal = true }

local DOT = 6            -- route dot size on screen (pixels)
local GAP = 16           -- route dot spacing on screen (pixels), more when the line is long
local MAX_DOTS = 40      -- route dots per line, at most
local FLOW = 0.7         -- seconds for the dots to flow one gap
local CREATOR_SCALE = 1.3

-- the accent: violet to magenta, as the Wuber icon
local function hex(h)
	return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 }
end
-- (design round 4) the colours are Wuber's tokens (T.C): the route and rings violet, gold for prices only; the hex is the
-- fallback if the theme is not there
local function tok(name, fallback)
	local C = W.Theme and W.Theme.C
	local c = C and C[name]
	if type(c) == "table" then return { c[1], c[2], c[3] } end
	return hex(fallback)
end
local VIOLET = tok("accent", "A974F5")
local MAGENTA = tok("magenta", "A974F5")
local BRIGHT = tok("accent", "A974F5")
local GOLD = tok("gold", "F9C53E")
local AMBER = tok("amber", "F9A23E")
local PAUSED = tok("off", "8B83AC")
local FILL = tok("panel", "181630")    -- the pin: black-violet
local TEXT = tok("white", "F2EEFF")
local MUTED = tok("muted", "ABA5C9")

-- open drivers draw above busy ones, busy above paused, the creator above them, the chosen on top
local STATE_LEVEL = { open = 12, busy = 6, paused = 0 } -- each pin uses six levels
local CREATOR_LEVEL, CHOSEN_LEVEL = 18, 24

local pins = {}          -- the pool: every pin frame ever made, reused for ever
local plainIcon = setmetatable({}, { __mode = "k" }) -- textures standing in for FX frames
local contCache = {}     -- uiMapID -> continentID or false

M.focus = nil            -- the driver ShowDriver last showed (highlighted until a ride says otherwise)

---------------------------------------------------------------------------
-- Small guarded helpers
---------------------------------------------------------------------------

-- a frame made with NO parent, then parented: with the game's Gamepad UI on, a frame created WITH a parent inside an
-- open game window (the world map) makes the game rebuild that window's navigation inside our code and taints it
local function NewFrame(kind, parent, template)
	local f = CreateFrame(kind, nil, nil, template)
	if parent ~= nil then f:SetParent(parent) end
	return f
end

-- With the game's Gamepad UI on (W.GamepadUI), Wuber's map frames carry no click or mouse script (the controller's
-- navigation reads them as buttons and blames the addon). A click is taken from the game-wide GLOBAL_MOUSE_DOWN / UP
-- events instead: left button, the pointer over the frame, pressed and released on the same frame; of the frames the
-- pointer is over, the topmost (strata, then level, then the later one) takes it. up(frame, button) is what OnClick did.
local STRATA_RANK = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local clickable, clickList, pressedOn = {}, {}, nil

-- is the frame the one the game says the pointer is on (or an ancestor of it)? True when the game cannot say
local function PointerOn(f)
	local foci
	if type(GetMouseFoci) == "function" then
		local ok, list = pcall(GetMouseFoci)
		if ok and type(list) == "table" then foci = list end
	elseif type(GetMouseFocus) == "function" then
		local ok, one = pcall(GetMouseFocus)
		if ok and one ~= nil then foci = { one } end
	end
	if not foci or foci[1] == nil then return true end
	for _, focus in ipairs(foci) do
		local at, n = focus, 0
		while at ~= nil and n < 60 do
			if at == f then return true end
			at = type(at.GetParent) == "function" and at:GetParent() or nil
			n = n + 1
		end
	end
	return false
end

local function TopClickable()
	local best, bestKey
	for i = 1, #clickList do
		local f = clickList[i]
		if f:IsVisible() and f:IsMouseOver() and PointerOn(f) then
			local key = (STRATA_RANK[f:GetFrameStrata()] or 3) * 1e8 + (f:GetFrameLevel() or 0) * 1e4 + i
			if not bestKey or key > bestKey then best, bestKey = f, key end
		end
	end
	return best
end

local function ClickOver(frame, up, down)
	if clickable[frame] then clickable[frame] = { up = up, down = down } return end
	clickable[frame] = { up = up, down = down }
	clickList[#clickList + 1] = frame
	if #clickList > 1 then return end
	W.On("GLOBAL_MOUSE_DOWN", function(button)
		pressedOn = nil
		if W.Plain(button) ~= "LeftButton" then return end
		local f = TopClickable()
		pressedOn = f
		local h = f and clickable[f].down
		if h then W.Safe("map click", h, f, "LeftButton") end
	end)
	W.On("GLOBAL_MOUSE_UP", function(button)
		local was = pressedOn
		pressedOn = nil
		if W.Plain(button) ~= "LeftButton" or not was then return end
		local f = TopClickable()
		local h = f == was and clickable[f].up
		if h then W.Safe("map click", h, f, "LeftButton") end
	end)
end

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

-- continentID, world x, world y of a map position: W.WorldPos (Places.lua) when it is there,
-- else straight from C_Map
local function World(mapID, x, y)
	if type(W.WorldPos) == "function" then
		local ok, cont, wx, wy = pcall(W.WorldPos, mapID, x, y)
		if ok then
			cont = W.Num(cont)
			if type(W.Plain(wx)) == "table" then wx, wy = XY(wx) else wx, wy = W.Num(wx), W.Num(wy) end
			if cont and wx and wy then return cont, wx, wy end
		end
	end
	if not (C_Map and type(C_Map.GetWorldPosFromMapPos) == "function" and type(CreateVector2D) == "function") then
		return nil
	end
	local ok, vec = pcall(CreateVector2D, x, y)
	if not ok or vec == nil then return nil end
	local ok2, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, vec)
	if not ok2 then return nil end
	cont = W.Num(cont)
	if not cont then return nil end
	local wx, wy = XY(pos)
	if not wx then return nil end
	return cont, wx, wy
end

local function ContinentOf(mapID)
	local c = contCache[mapID]
	if c == nil then
		c = World(mapID, 0.5, 0.5) or false
		contCache[mapID] = c
	end
	return c or nil
end

-- where a map position falls on the shown map (may lie outside 0..1); nil across continents
local function MapXY(mapID, x, y, shown)
	if mapID == shown then return x, y end
	if not (C_Map and type(C_Map.GetMapPosFromWorldPos) == "function" and type(CreateVector2D) == "function") then
		return nil
	end
	local cont, wx, wy = World(mapID, x, y)
	if not cont then return nil end
	local shownCont = ContinentOf(shown)
	if shownCont and shownCont ~= cont then return nil end -- another continent
	local okv, vec = pcall(CreateVector2D, wx, wy)
	if not okv or vec == nil then return nil end
	local ok, a, b = pcall(C_Map.GetMapPosFromWorldPos, cont, vec, shown)
	if not ok then return nil end
	-- the game returns uiMapID, position; take the vector wherever it is
	local px, py = XY(b)
	if not px then px, py = XY(a) end
	return px, py
end

local function BlizzardPos(mapID, x, y, shown)
	local px, py = MapXY(mapID, x, y, shown)
	if not px or px < 0 or px > 1 or py < 0 or py > 1 then return nil end
	return px, py
end

---------------------------------------------------------------------------
-- The drivers
---------------------------------------------------------------------------

local function Hidden(key)
	local h = W.db and W.db.hidden
	return key ~= nil and type(h) == "table" and h[key] and true or false
end

local function Drivers()
	local list
	if type(W.DriversSorted) == "function" then
		local ok, l = pcall(W.DriversSorted)
		if ok and type(l) == "table" then list = l end
	end
	if not list then
		list = {}
		if type(W.drivers) == "table" then
			for k, d in pairs(W.drivers) do
				if type(d) == "table" then list[#list + 1] = d end
			end
			table.sort(list, function(a, b) return tostring(a.key) < tostring(b.key) end)
		end
	end
	-- hidden drivers are never drawn (Net filters them too; this is the belt to its braces)
	local out = {}
	for i = 1, #list do
		local d = list[i]
		if type(d) == "table" and not Hidden(d.key) then out[#out + 1] = d end
	end
	return out
end

local function IsCreator(d)
	if type(W.IsCreator) ~= "function" then return false end
	local ok, yes = pcall(W.IsCreator, d.key or d.name)
	if ok and yes == true then return true end
	if d.name and d.name ~= d.key then
		ok, yes = pcall(W.IsCreator, d.name)
		return ok and yes == true
	end
	return false
end

local function IsFav(key)
	if key == nil then return false end
	if type(W.IsFav) == "function" then
		local ok, yes = pcall(W.IsFav, key)
		if ok then return yes and true or false end
	end
	local f = W.db and W.db.favs
	return type(f) == "table" and f[key] and true or false
end

-- price ranks among open drivers (for the glow when W.Prominence isn't there)
local function PriceRanks(list)
	local prices, seen = {}, {}
	for i = 1, #list do
		local d = list[i]
		local p = W.Num(d.price)
		if d.state == "open" and p and not seen[p] then
			seen[p] = true
			prices[#prices + 1] = p
		end
	end
	table.sort(prices)
	local rank = {}
	for i, p in ipairs(prices) do rank[p] = i end
	return rank, #prices
end

-- glow 0..1 and whether this is the creator: W.Prominence (Net), else the same rule here:
-- the cheaper the open driver, the stronger (others at most 0.7), the creator always 1.0
local function Prominence(d, rank, n)
	if type(W.Prominence) == "function" then
		local ok, glow, creator = pcall(W.Prominence, d)
		glow = ok and W.Num(glow)
		if glow then return math.max(0, math.min(1, glow)), creator == true end
	end
	local creator = IsCreator(d)
	if creator then return d.state == "open" and 1 or 0.5, true end
	if d.state ~= "open" then return 0, false end
	local r = rank[W.Num(d.price) or -1]
	if not r or n <= 1 then return 0.7, false end
	return 0.15 + 0.55 * (1 - (r - 1) / (n - 1)), false
end

-- a small number from a name, so three crowns don't spin in step
local function Seed(text)
	text = tostring(text or "")
	local h = 0
	for i = 1, #text do h = (h * 31 + text:byte(i)) % 9973 end
	return h
end

-- a badge id -> { id, name, tex } from W.BADGES (a list or a map; unknown ids: nil)
local function BadgeInfo(id)
	id = W.Str(id)
	if not id or id == "" or type(W.BADGES) ~= "table" then return nil end
	local e = W.BADGES[id]
	if e == nil then
		for _, x in ipairs(W.BADGES) do
			if type(x) == "table" and x.id == id then e = x break end
		end
	end
	if e == nil then return nil end
	if type(e) ~= "table" then e = { name = W.Str(e) } end
	local tex = e.tex or e.texture or e.icon
	-- W.BADGES names a bare file ("badge_skull"): make it a full Media path, or the pin draws blank (white)
	if type(tex) == "string" and tex ~= "" and not tex:find("[\\/]") then tex = "Interface\\AddOns\\Wuber\\Media\\" .. tex end
	return { id = id, name = W.Str(e.name) or id, tex = tex }
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

-- internals other modules use (bound at load by later modules, or called late)
Mod.AMBER = AMBER
Mod.Accent = Accent
Mod.BRIGHT = BRIGHT
Mod.BadgeInfo = BadgeInfo
Mod.BlizzardPos = BlizzardPos
Mod.CHOSEN_LEVEL = CHOSEN_LEVEL
Mod.CREATOR_LEVEL = CREATOR_LEVEL
Mod.CREATOR_SCALE = CREATOR_SCALE
Mod.Canvas = Canvas
Mod.Chosen = Chosen
Mod.ClickOver = ClickOver
Mod.DOT = DOT
Mod.Driver = Driver
Mod.Drivers = Drivers
Mod.FILL = FILL
Mod.FLOW = FLOW
Mod.GAP = GAP
Mod.GLIDE_ZOOM = GLIDE_ZOOM
Mod.GOLD = GOLD
Mod.IsFav = IsFav
Mod.LEVEL_ABOVE = LEVEL_ABOVE
Mod.MAGENTA = MAGENTA
Mod.MAX_DOTS = MAX_DOTS
Mod.MEDIA = MEDIA
Mod.MUTED = MUTED
Mod.MapShown = MapShown
Mod.MapXY = MapXY
Mod.NewFrame = NewFrame
Mod.OM = OM
Mod.OMHas = OMHas
Mod.OpenMapPos = OpenMapPos
Mod.PAUSED = PAUSED
Mod.PIN = PIN
Mod.PinsOn = PinsOn
Mod.PriceRanks = PriceRanks
Mod.Prominence = Prominence
Mod.ROUTE = ROUTE
Mod.STATE_LEVEL = STATE_LEVEL
Mod.ScaleTo = ScaleTo
Mod.Seed = Seed
Mod.ShownMapID = ShownMapID
Mod.Stitched = Stitched
Mod.TEXT = TEXT
Mod.TICK = TICK
Mod.Text = Text
Mod.VIOLET = VIOLET
Mod.World = World
Mod.WorldUV = WorldUV
Mod.XY = XY
Mod.call = call
Mod.hex = hex
Mod.pins = pins
Mod.plainIcon = plainIcon
