-- Module: UI.Rider.WorldMap
-- Purpose: the whole-world map in an unfolded side pane: Kalimdor and the Eastern Kingdoms side by
--   side, each cropped to its land and pushed together (game art probed at run time, else the stylised
--   fallback), dashed flight routes, boats, driver pins, bounty coins and the rider's dot; the continent
--   you are on gets the focus; the pane's Here/World control.
-- API: WorldMap.Build, WorldMap.Show, WorldMap.Refresh, WorldMap.Probe, WorldMap.Project, WorldMap.Wanted,
--   WorldMap.Box, WorldMap.CutEdge
-- Internals: drawOwn (2.3.2: your own "You" pin while you are open as a driver; a tap opens the Drive tab); spread
--   (round 31: driver pins of places so close they would overlap are pushed apart, inside their continent's box)
-- (2.3.2, S7) A price tag near a continent box's right edge sits left of its pin; the focus ring is centred on a
-- bounty coin at that place.
-- (BRIEF25 M1, round 26) crop (each continent's whole land: its coastline box WM.LAND, the flight masters and
-- the extra pins, plus WM.CROP.yards, inside the art) and arrange (the two crops side by side, WM.GAP apart,
-- at one scale: the same pixels per yard on both, as large as fits WM.AREA less WM.CROP.fit, centred). The
-- continent you are on, CACHE.focus, is not made larger: its art is tinted brighter and its name violet. Price tags try right, then left of their pin and are hidden (the tooltip keeps
-- the price) when both would overlap a tag, a pin or a continent's name.
-- Uses: UI.Kit
-- Later: UI.Fold, UI.Rider.SeaRoute (the "continues by boat / zeppelin" arrow on the violet route)
-- Events: listens (from the first Build: Listen DRIVERS, Listen BOUNTY, Listen FLIGHTS); fires (none)
-- Standalone: no
-- Test: tests/ui/rider/worldmap_test.lua
-- From: new in Wuber 2.3.0
--
-- Callers (C's `ride` and `confirm` pages) reach it through the handle:
--   local WorldMod = W.Mod("UI.Rider.WorldMap")
--   WorldMod.Build(holder, opts) -> the world view frame inside holder (360 x 544; the Here/World
--       control at the top of holder). opts.here: the frame "Here" shows (the docked HomeMap panel,
--       UI.Rider.HomeMap's Mod.Dock); opts.mode: "here" or "world" (default: Wanted()); opts.onMode(mode).
--       Cheap: the map itself is drawn on the first Show("world") while unfolded. Hooks holder's
--       OnShow (HookScript): a pane that shows again redraws what it missed while hidden.
--   WorldMod.Show(mode, opts): mode "here" | "world" (nil: keep); opts.holder (which built map;
--       default the last one), opts.route = { from = place name or nil (here), to = place name }
--       (the flight the rider would take, solid violet), opts.focus = place name (a ring there).
--   WorldMod.Wanted() -> "world" | "here": the view a pane opens on (round 12, item 9): the player's last
--       pick on the Here/World control (W.db.mapView, per account), else "world". Build (without
--       opts.mode) opens on it every time a page unfolds; a click on the control saves it.
--   WorldMod.Refresh() redraws the pins of a shown world view (DRIVERS / BOUNTY, 0.5 s debounced).
--   WorldMod.Probe() -> "cmap" | "legacy" | "fallback" (the art in use this session).
--   WorldMod.Project(cont, wx, wy) -> x, y in the pane (nil: off the map / not projected).
--   WorldMod.Box(cont) -> x, y, w, h: continent cont's cropped box in the pane (top-left origin, y down;
--       nil when it is not drawn). Kalimdor (1) is on the left, the Eastern Kingdoms (0) on the right.
--   WorldMod.CutEdge(cont) -> x, top, bottom, dir: the box's inner edge (the cut sea between the two),
--       its y range, and dir +1 when the other continent lies to the right (Kalimdor), -1 to the left.
--       For a "continues by boat / zeppelin" arrow drawn at the cut. Pane coordinates as Project.
-- Never drawn while folded (UI.Fold.IsUnfolded() false) or hidden; nothing redraws while hidden.
-- Art: C_Map continent art (uiMapIDs found under Azeroth 947), else the legacy
-- WorldMap tiles, else Media/mapbg. Coordinates (3.3): C_Map's map corners, else the calibration
-- learned at flight masters (Core.FlightTimes, W.db.mapCal), else W.TAXI_BOUNDS (fallback art
-- only). Routes (3.4): W.TAXI_PATHS for this side's legs, Line objects with Media/dash (the dash
-- phase carried along each polyline), else pooled dash sprites; at most WM.BUDGET textures.

local _, W = ...
local Mod = W.Module("UI.Rider.WorldMap", { "UI.Kit" })
local KitMod = W.Mod("UI.Kit")
local N, S, call, clamp, money = KitMod.N, KitMod.S, KitMod.call, KitMod.clamp, KitMod.money
local safeScript = KitMod.safeScript
local T = W.Theme
local A = T.Animate
local Try = T.Try
local UI = W.UI

local ACC = T.C.accent
local WM = {
	PANE_W = 360, PANE_H = 544,
	SEG_W = 184, SEG_H = 28, SEG_Y = 14, SEG_X = 16,
	BOX = { [1] = { name = "Kalimdor", left = true }, [0] = { name = "Eastern Kingdoms" } },
	BOX_Y = 44, BOX_H = 470, LEGEND_Y = 516,
	-- the area both crops share and the cut between them (none now: the crops touch); (round 26) the crop's margin past the
	-- land (yards) and the boxes' margin inside the area (pane units)
	AREA = { x = 6, y = 44, w = 348, h = 470 }, GAP = 0,
	CROP = { yards = 250, fit = 6 },
	-- (round 26) each continent's whole land, world yards { minX, minY, maxX, maxY } (x north, y west): Kalimdor
	-- from Tanaris' south coast to Teldrassil, Feralas' isles to Azshara; the Eastern Kingdoms from the
	-- Stranglethorn cape to Quel'Thalas, the west coast to the east of the Plaguelands. Drawn whatever the art.
	LAND = { [1] = { -9800, -7700, 11100, 4200 }, [0] = { -15000, -8000, 10400, 3200 } },
	TINT = { 0.46, 0.42, 0.62 }, TINT_FOCUS = { 0.6, 0.56, 0.8 }, TINT_DIM = { 0.36, 0.33, 0.5 },
	ART_ALPHA = 0.85, MARGIN = 0.06,
	PIN = 22, COIN = 18, TAG_H = 20, TAG_SIZE = "caption", LABEL = 13, LABEL_SIZE = "caption", ME = 10, -- LABEL is the box label's height maths, LABEL_SIZE its text size
	-- (design round 4) routes, rings and arrows are the accent violet (T.C.accent); gold is for price tags only
	FLIGHT = { ACC[1], ACC[2], ACC[3], 0.45 }, BOAT = { ACC[1], ACC[2], ACC[3], 0.85 }, ROUTE = { ACC[1], ACC[2], ACC[3], 1 },
	SILVER = { 0.8, 0.82, 0.88, 1 },
	THICK = 1.5, GOLD_THICK = 2.5, PERIOD = 16, BOAT_PERIOD = 8, SPACING = 8, BUDGET = 700, EPS = 1,
	CONT_MAPS = { [1] = 1414, [0] = 1415 }, AZEROTH = 947, CONTINENT_TYPE = 2,
	LEGACY = { [1] = "Interface\\WorldMap\\Kalimdor\\Kalimdor", [0] = "Interface\\WorldMap\\Azeroth\\Azeroth" },
	DEBOUNCE = 0.5, TAGS = 3, PINS = 40, NODE_HIT = 10,
	-- (round 13, I21) the game's continent art has its name written across the middle ("KALIMDOR",
	-- "EASTERN KINGDOMS"), wider than our boxes: a soft dark band over those letters (box y, half
	-- height, alpha), the boxes' own labels name them. Not on our own fallback art.
	BAND = { y = 246, half = 30, alpha = 0.6, v = 0.52, halfV = 0.045 },
}
Mod.WM = WM

-- session caches: the art probe, each continent's projection, the static routes per side
local CACHE = { maps = {}, last = nil, wired = false, pending = false }

---------------------------------------------------------------------------
-- Probes: the continents, their art and how world positions land on them
---------------------------------------------------------------------------

local function fold() return UI and UI.Fold end
local function unfolded()
	local F = fold()
	return type(F) == "table" and type(F.IsUnfolded) == "function" and call(F.IsUnfolded) == true
end

local function side()
	local s = W.Faction and W.Faction() or nil
	if s == "H" or s == "A" then return s end
	return nil
end

local function vec(x, y)
	if type(CreateVector2D) ~= "function" then return nil end
	local ok, v = pcall(CreateVector2D, x, y)
	return ok and v or nil
end

local function vxy(v)
	v = W.Plain(v)
	if type(v) ~= "table" and type(v) ~= "userdata" then return nil end
	local ok, a, b = pcall(function() if v.GetXY then return v:GetXY() end return v.x, v.y end)
	if not ok then return nil end
	return N(a), N(b)
end

-- The world position of a point of a continent map: cont, wx, wy.
local function worldOf(mapID, u, v)
	if type(C_Map) ~= "table" or type(C_Map.GetWorldPosFromMapPos) ~= "function" then return nil end
	local p = vec(u, v)
	if not p then return nil end
	local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, p)
	if not ok then return nil end
	local wx, wy = vxy(pos)
	if not (N(cont) and wx) then return nil end
	return N(cont), wx, wy
end

-- Continent uiMapIDs by continent id: the children of Azeroth (947) of type continent, so
-- Forever's own geography comes with it; else Classic's 1414 / 1415.
local function continents()
	if CACHE.conts then return CACHE.conts end
	local out = {}
	local kids = type(C_Map) == "table" and call(C_Map.GetMapChildrenInfo, WM.AZEROTH) or nil
	kids = W.Plain(kids)
	if type(kids) == "table" then
		for i, info in ipairs(kids) do
			if i > 40 then break end
			info = W.Plain(info)
			local id = type(info) == "table" and N(info.mapID)
			if id and N(info.mapType) == WM.CONTINENT_TYPE then
				local cont = worldOf(id, 0.5, 0.5)
				if cont and WM.BOX[cont] and not out[cont] then out[cont] = id end
			end
		end
	end
	for cont, id in pairs(WM.CONT_MAPS) do
		if not out[cont] then out[cont] = id end
	end
	CACHE.conts = out
	return out
end

-- C_Map's art for a map: { lw, lh, tw, th, cols, rows, files } or nil (as HomeMap's mapArt).
local function cmapArt(mapID)
	if type(C_Map) ~= "table" then return nil end
	local layers = W.Plain(call(C_Map.GetMapArtLayers, mapID))
	local info = type(layers) == "table" and W.Plain(layers[1])
	if type(info) ~= "table" then return nil end
	local lw, lh, tw, th = N(info.layerWidth), N(info.layerHeight), N(info.tileWidth), N(info.tileHeight)
	if not (lw and lh and tw and th) or lw <= 0 or lh <= 0 or tw <= 0 or th <= 0 then return nil end
	local files = W.Plain(call(C_Map.GetMapArtLayerTextures, mapID, 1))
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

-- The legacy tiles (4 x 3 of 256 covering 1002 x 668), when every one of them loads.
local function legacyArt(cont, probeParent)
	local base = WM.LEGACY[cont]
	if not base or not probeParent then return nil end
	local t = probeParent:CreateTexture(nil, "BACKGROUND")
	t:Hide()
	local list = {}
	for i = 1, 12 do
		local path = base .. i
		local ok, set = pcall(t.SetTexture, t, path)
		local got = ok and set ~= false and Try(t, "GetTexture")
		if got == nil or got == false then return nil end
		list[i] = path
	end
	pcall(t.SetTexture, t, nil)
	return { lw = 1002, lh = 668, tw = 256, th = 256, cols = 4, rows = 3, files = list }
end

-- Which art this session uses: "cmap", "legacy" or "fallback"; the art per continent.
local function probe(parent)
	if CACHE.kind then return CACHE.kind, CACHE.art end
	local art, conts = {}, continents()
	local kind = "cmap"
	for cont in pairs(WM.BOX) do
		art[cont] = conts[cont] and cmapArt(conts[cont])
		if not art[cont] then kind = nil end
	end
	if not kind then
		kind, art = "legacy", {}
		for cont in pairs(WM.BOX) do
			art[cont] = legacyArt(cont, parent)
			if not art[cont] then kind = nil end
		end
	end
	if not kind then kind, art = "fallback", {} end
	CACHE.kind, CACHE.art = kind, art
	return kind, art
end
function Mod.Probe(parent) return (probe(parent or (CACHE.last and CACHE.last.view))) end

-- world -> continent-map u, v for continent `cont`: the map's corners first, else the
-- flight-master calibration; nil when neither is known. kind says which.
local function affineOf(cont)
	CACHE.corners = CACHE.corners or {}
	local hit = CACHE.corners[cont]
	if hit == nil then
		hit = false
		local id = continents()[cont]
		local c0, x0, y0 = worldOf(id, 0, 0)
		local c1, x1, y1 = worldOf(id, 1, 0)
		local c2, x2, y2 = worldOf(id, 0, 1)
		if c0 and c0 == cont and c1 == cont and c2 == cont then
			-- world = P0 + u (P1 - P0) + v (P2 - P0): invert the 2 x 2
			local ax, ay, bx, by = x1 - x0, y1 - y0, x2 - x0, y2 - y0
			local det = ax * by - bx * ay
			if math.abs(det) > 1e-9 then
				hit = { a = by / det, b = -bx / det, d = -ay / det, e = ax / det, x0 = x0, y0 = y0 }
			end
		end
		CACHE.corners[cont] = hit
	end
	if hit then
		return function(wx, wy)
			local dx, dy = wx - hit.x0, wy - hit.y0
			return hit.a * dx + hit.b * dy, hit.d * dx + hit.e * dy
		end, "corners"
	end
	local FT = W.Mod("Core.FlightTimes")
	local cal = type(FT) == "table" and type(FT.MapCal) == "function" and FT.MapCal(cont) or nil
	if cal then
		return function(wx, wy) return cal.a * wx + cal.b * wy + cal.c, cal.d * wx + cal.e * wy + cal.f end, "cal"
	end
	return nil
end

-- The fallback: the continent's node box, u along -Y and v along -X (as the game's maps).
local function boundsOf(cont)
	local b = type(W.TAXI_BOUNDS) == "table" and W.TAXI_BOUNDS[cont] or nil
	if type(b) ~= "table" or not (N(b[1]) and N(b[2]) and N(b[3]) and N(b[4])) or b[3] <= b[1] or b[4] <= b[2] then return nil end
	return function(wx, wy) return (b[4] - wy) / (b[4] - b[2]), (b[3] - wx) / (b[3] - b[1]) end, b
end

-- (round 26) yards of world per unit of u, per unit of v, and per unit of uv area (the uv functions are affine)
local function yardsOf(uv)
	local u0, v0 = uv(0, 0)
	local ux, vx = uv(1000, 0)
	local uy, vy = uv(0, 1000)
	if not (u0 and v0 and ux and vx and uy and vy) then return nil end
	local a, b, d, e = (ux - u0) / 1000, (uy - u0) / 1000, (vx - v0) / 1000, (vy - v0) / 1000
	local det = math.abs(a * e - b * d)
	if det < 1e-15 then return nil end
	return math.sqrt(e * e + d * d) / det, math.sqrt(a * a + b * b) / det, 1 / det
end

-- (BRIEF25 M1, round 26) Each continent's crop: uv function, art (or nil) and the uv window of its whole land
-- (WM.LAND's corners, the nodes and the extra pins, plus WM.CROP.yards, kept inside the art). The window's
-- aspect is the land's own; yw, yh: the box's size at one pixel per yard (arrange() scales both alike).
local function layout(cont, kind, art)
	local uv, how = nil, nil
	if kind ~= "fallback" then uv, how = affineOf(cont) end
	local aw, ah
	if uv and art then
		aw, ah = art.lw, art.lh
	else
		local b
		uv, b = boundsOf(cont)
		if not uv then return nil end
		how, art = "bounds", nil
		aw, ah = b[4] - b[2], b[3] - b[1]
	end
	local u0, v0, u1, v1
	for _, n in pairs(type(W.TAXI) == "table" and W.TAXI.nodes or {}) do
		if n[2] == cont then
			local u, v = uv(n[3], n[4])
			if u and v then
				u0, u1 = math.min(u0 or u, u), math.max(u1 or u, u)
				v0, v1 = math.min(v0 or v, v), math.max(v1 or v, v)
			end
		end
	end
	if not u0 or u1 - u0 <= 0 or v1 - v0 <= 0 then return nil end
	-- where you stand, and the driver, own and bounty pins, count as land too
	for _, e in ipairs(type(Mod.extraPoints) == "function" and Mod.extraPoints() or {}) do
		if e.cont == cont then
			local u, v = uv(e.wx, e.wy)
			if u and v then
				u0, u1 = math.min(u0, u), math.max(u1, u)
				v0, v1 = math.min(v0, v), math.max(v1, v)
			end
		end
	end
	-- (round 26) the whole land: the coastline's corners (the flight masters alone cut the coasts)
	local pu0, pu1, pv0, pv1 = u0, u1, v0, v1
	local land = WM.LAND[cont]
	if type(land) == "table" then
		for _, c in ipairs({ { land[1], land[2] }, { land[1], land[4] }, { land[3], land[2] }, { land[3], land[4] } }) do
			local u, v = uv(c[1], c[2])
			if u and v then
				u0, u1 = math.min(u0, u), math.max(u1, u)
				v0, v1 = math.min(v0, v), math.max(v1, v)
			end
		end
	end
	local yu, yv, area = yardsOf(uv)
	local mu, mv
	if yu then
		mu, mv = WM.CROP.yards / yu, WM.CROP.yards / yv
	else
		mu, mv = (u1 - u0) * WM.MARGIN, (v1 - v0) * WM.MARGIN
	end
	if art then
		-- never past the art's own edge (a node outside it keeps its place inside the window)
		u0, u1 = math.max(math.min(0, pu0), u0 - mu), math.min(math.max(1, pu1), u1 + mu)
		v0, v1 = math.max(math.min(0, pv0), v0 - mv), math.min(math.max(1, pv1), v1 + mv)
	else
		u0, u1, v0, v1 = u0 - mu, u1 + mu, v0 - mv, v1 + mv
	end
	local aspect = ((u1 - u0) * aw) / ((v1 - v0) * ah)
	-- the box at one pixel per yard (the geometric mean of the two ways, so art drawn at its own aspect
	-- keeps it); without a usable uv, one pixel per art pixel
	local yw = area and math.sqrt(aspect * (u1 - u0) * (v1 - v0) * area) or nil
	return { cont = cont, uv = uv, how = how, art = art, u0 = u0, u1 = u1, v0 = v0, v1 = v1, aw = aw, ah = ah,
		aspect = aspect, yw = yw, yh = yw and yw / aspect or nil }
end

-- (BRIEF25 M1, round 26) The boxes: Kalimdor left, the Eastern Kingdoms right, WM.GAP apart (the sea cut out),
-- at one scale s (pixels per yard, the same on both): s = min((AREA.w - GAP - 2 fit) / (Kw + Ew),
-- (AREA.h - 2 fit) / max(Kh, Eh)) from each crop's size in yards, the pair centred in WM.AREA. Each box keeps
-- its crop's aspect, so art and projection share one scale. The focus only tints (drawn elsewhere).
local function arrange(out, focus)
	local A, gap, m = WM.AREA, WM.GAP, WM.CROP.fit
	local Lk, Le = out[1], out[0]
	local yards = true
	for _, L in pairs(out) do if not L.yw then yards = false end end
	for _, L in pairs(out) do
		L.bw = yards and L.yw or (L.u1 - L.u0) * L.aw
		L.bh = L.bw / L.aspect
	end
	local function size(L, s) L.w, L.h = L.bw * s, L.bh * s end
	if Lk and Le then
		local s = math.min((A.w - gap - 2 * m) / (Lk.bw + Le.bw), (A.h - 2 * m) / math.max(Lk.bh, Le.bh))
		size(Lk, s)
		size(Le, s)
		local x = A.x + (A.w - (Lk.w + gap + Le.w)) / 2
		Lk.x, Le.x = x, x + Lk.w + gap
	else
		local L = Lk or Le
		if not L then return end
		size(L, math.min((A.w - 2 * m) / L.bw, (A.h - 2 * m) / L.bh))
		L.x = A.x + (A.w - L.w) / 2
	end
	for _, L in pairs(out) do
		L.y = A.y + (A.h - L.h) / 2
		L.focus = focus ~= nil and L.cont == focus or false
	end
end
Mod.arrange = arrange

-- world -> pane x, y (top-left origin, y down) through a continent's view.
local function toPane(L, wx, wy)
	if not L then return nil end
	local u, v = L.uv(wx, wy)
	if not (u and v) then return nil end
	return L.x + (u - L.u0) / (L.u1 - L.u0) * L.w, L.y + (v - L.v0) / (L.v1 - L.v0) * L.h
end

-- the continent the player is on (nil: neither, an instance or unknown): it gets the focus
local function hereCont()
	local cont = type(W.WorldPos) == "function" and type(W.MyPosition) == "function" and N((call(W.WorldPos, call(W.MyPosition)))) or nil
	return cont and WM.BOX[cont] and cont or nil
end

local function views()
	if CACHE.views then return CACHE.views end
	local kind, art = probe(CACHE.last and CACHE.last.view)
	local out = {}
	for cont in pairs(WM.BOX) do
		out[cont] = layout(cont, kind, art[cont])
		-- game art that can't be aligned: the fallback art for that box
	end
	arrange(out, CACHE.focus)
	CACHE.views = out
	return out
end

function Mod.Project(cont, wx, wy)
	cont, wx, wy = N(cont), N(wx), N(wy)
	if not (cont and wx and wy) then return nil end
	return toPane(views()[cont], wx, wy)
end

function Mod.Box(cont)
	local L = views()[N(cont) or -1]
	if not L then return nil end
	return L.x, L.y, L.w, L.h
end

function Mod.CutEdge(cont)
	local L = views()[N(cont) or -1]
	if not L then return nil end
	local left = WM.BOX[L.cont].left == true
	return left and (L.x + L.w) or L.x, L.y, L.y + L.h, left and 1 or -1
end

---------------------------------------------------------------------------
-- Drawing: art, routes (pooled), nodes
---------------------------------------------------------------------------

local function newPool(parent, kind)
	return { parent = parent, kind = kind, list = {}, used = 0 }
end

local function take(pool)
	pool.used = pool.used + 1
	local t = pool.list[pool.used]
	if not t then
		if pool.kind == "line" then
			t = pool.parent:CreateLine(nil, "ARTWORK")
		else
			t = pool.parent:CreateTexture(nil, "ARTWORK")
		end
		pool.list[pool.used] = t
	end
	t:Show()
	return t
end

local function release(pool, from)
	for i = (from or 0) + 1, #pool.list do pool.list[i]:Hide() end
	pool.used = from or 0
end

-- Douglas-Peucker in pane pixels: { x1, y1, x2, y2, ... } -> the same, fewer points.
local function simplify(pts, eps)
	local n = #pts / 2
	if n <= 2 then return pts end
	local keep = { [1] = true, [n] = true }
	local stack = { { 1, n } }
	while #stack > 0 do
		local seg = table.remove(stack)
		local i, j = seg[1], seg[2]
		local ax, ay, bx, by = pts[2 * i - 1], pts[2 * i], pts[2 * j - 1], pts[2 * j]
		local dx, dy = bx - ax, by - ay
		local l2 = dx * dx + dy * dy
		local best, bestD = nil, eps
		for k = i + 1, j - 1 do
			local px, py = pts[2 * k - 1], pts[2 * k]
			local t = l2 > 0 and clamp(((px - ax) * dx + (py - ay) * dy) / l2, 0, 1) or 0
			local qx, qy = ax + t * dx - px, ay + t * dy - py
			local d = math.sqrt(qx * qx + qy * qy)
			if d > bestD then best, bestD = k, d end
		end
		if best then
			keep[best] = true
			stack[#stack + 1] = { i, best }
			stack[#stack + 1] = { best, j }
		end
	end
	local out = {}
	for k = 1, n do
		if keep[k] then
			out[#out + 1] = pts[2 * k - 1]
			out[#out + 1] = pts[2 * k]
		end
	end
	return out
end
Mod.simplify = simplify

local function usable(n, s) return type(n) == "table" and type(n[5]) == "string" and n[5]:find(s, 1, true) ~= nil end

-- The polylines this side flies, in pane pixels: { { pts, kind = "flight"|"boat" }, ... }.
local function routes(s, eps)
	local V, T0 = views(), W.TAXI
	local out = {}
	if type(T0) ~= "table" then return out end
	for key, p in pairs(type(W.TAXI_PATHS) == "table" and W.TAXI_PATHS or {}) do
		local a, b = key:match("^(%d+):(%d+)$")
		local na, nb = T0.nodes[tonumber(a or "")], T0.nodes[tonumber(b or "")]
		if usable(na, s) and usable(nb, s) and V[na[2]] then
			local pts = {}
			for i = 1, #p - 1, 2 do
				local x, y = toPane(V[na[2]], p[i], p[i + 1])
				if x then
					pts[#pts + 1] = x
					pts[#pts + 1] = y
				end
			end
			if #pts >= 4 then out[#out + 1] = { pts = simplify(pts, eps), kind = "flight", key = key } end
		end
	end
	table.sort(out, function(x, y) return x.key < y.key end)
	local B = type(T0.boats) == "table" and T0.boats or {}
	for i = 1, #B - 2, 3 do
		local na, nb = T0.nodes[B[i]], T0.nodes[B[i + 1]]
		if B[i + 2] == s and usable(na, s) and usable(nb, s) and V[na[2]] and V[nb[2]] then
			local x1, y1 = toPane(V[na[2]], na[3], na[4])
			local x2, y2 = toPane(V[nb[2]], nb[3], nb[4])
			if x1 and x2 then out[#out + 1] = { pts = { x1, y1, x2, y2 }, kind = "boat", key = B[i] .. "~" .. B[i + 1] } end
		end
	end
	return out
end

local function segments(list)
	local n = 0
	for _, r in ipairs(list) do n = n + #r.pts / 2 - 1 end
	return n
end

-- One polyline, dashed. Lines: a Line a segment, texcoords carrying the dash phase; else dash
-- sprites every `spacing` px (rotated when the client can), else 2 px dots. Returns the phase.
local function drawPolyline(wm, pts, colour, thick, period, spacing, solid)
	local phase = 0
	local useLines = wm.hasLines
	for i = 1, #pts - 3, 2 do
		local x1, y1, x2, y2 = pts[i], pts[i + 1], pts[i + 2], pts[i + 3]
		local dx, dy = x2 - x1, y2 - y1
		local len = math.sqrt(dx * dx + dy * dy)
		if len > 0 then
			if useLines then
				local l = take(wm.lines)
				l:SetStartPoint("TOPLEFT", wm.view, x1, -y1)
				l:SetEndPoint("TOPLEFT", wm.view, x2, -y2)
				Try(l, "SetThickness", thick)
				if solid then
					l:SetVertexColor(1, 1, 1, 1)
					l:SetAlpha(1)
					l:SetColorTexture(colour[1], colour[2], colour[3], colour[4])
				else
					l:SetTexture(T.MEDIA .. "dash", "REPEAT", "CLAMP")
					l:SetTexCoord(phase, phase + len / period, 0, 1)
					-- a reused line keeps alpha 1 in its colour; the route's alpha is the region's
					l:SetVertexColor(colour[1], colour[2], colour[3], 1)
					l:SetAlpha(colour[4] or 1)
				end
				l.wuberPhase = phase
				phase = (phase + len / period) % 1
			else
				local step = solid and math.max(2, spacing / 3) or spacing
				local at = (phase * step) % step
				while at <= len and wm.dots.used < WM.BUDGET - #wm.tiles - 1 do
					local d = take(wm.dots)
					local px, py = x1 + dx * at / len, y1 + dy * at / len
					d:ClearAllPoints()
					d:SetPoint("CENTER", wm.view, "TOPLEFT", px, -py)
					if wm.canRotate and not solid then
						d:SetTexture(T.MEDIA .. "dash")
						d:SetTexCoord(0, 0.5, 0, 1)
						d:SetSize(6, math.max(1, thick + 0.5))
						d:SetRotation(math.atan2(-dy, dx))
					else
						d:SetTexture(T.MEDIA .. "circle")
						d:SetTexCoord(0, 1, 0, 1)
						d:SetSize(solid and thick + 1 or 2, solid and thick + 1 or 2)
					end
					d:SetVertexColor(colour[1], colour[2], colour[3], colour[4])
					at = at + step
				end
				phase = ((at - len) / step) % 1
			end
		end
	end
	return phase
end

local function placeArt(wm)
	local kind = probe(wm.view)
	local V = views()
	for cont, box in pairs(wm.boxes) do
		if not V[cont] then
			box.clip:Hide()
			box.label:Hide()
		else
			box.clip:Show()
		end
	end
	for cont, L in pairs(V) do
		local box = wm.boxes[cont]
		-- the cropped box, where arrange() put it; the focus continent brighter, its name violet
		box.clip:ClearAllPoints()
		box.clip:SetPoint("TOPLEFT", wm.view, "TOPLEFT", L.x, -L.y)
		box.clip:SetSize(L.w, L.h)
		local tint = L.focus and WM.TINT_FOCUS or (CACHE.focus ~= nil and WM.TINT_DIM or WM.TINT)
		box.bg:SetVertexColor(tint[1] + 0.09, tint[2] + 0.08, tint[3] + 0.13)
		box.bg:Show()
		box.label:SetTextColor(T.RGB(L.focus and "accent" or "muted"))
		local weight = L.focus and "bold" or "medium"
		T.SetFont(box.label, WM.LABEL_SIZE, weight)
		box.label:SetText(WM.BOX[cont].name)
		-- (design round 4) just under the box (the route's arrow and its words are at the box's top, the routes inside it), left
		-- edge in line with it; no room under it: above it; none there either (the box fills the area): inside its top edge
		local lw = math.min(math.ceil((N(T.MeasureText(WM.BOX[cont].name, WM.LABEL_SIZE, weight)) or 80) * 1.08) + 2, math.max(20, L.w - 12)) -- (#259) 8% over the font table: the game draws the small name wider
		local lh = T.DrawnSize(WM.LABEL_SIZE) + 2
		local ly = L.y + L.h + 2
		if ly + lh > WM.LEGEND_Y - 2 then
			ly = L.y - lh - 2
			if ly < WM.BOX_Y - 6 then ly = L.y + 4 end
		end
		box.label:SetWidth(lw)
		box.label:ClearAllPoints()
		box.label:SetPoint("TOPLEFT", wm.view, "TOPLEFT", L.x + 6, -ly)
		box.label:Show()
		wm.labelRects = wm.labelRects or {}
		wm.labelRects[cont] = { L.x + 6, ly, lw, lh }
		local art = L.art
		local k = art and L.w / ((L.u1 - L.u0) * art.lw) or nil
		for i = 1, art and art.cols * art.rows or 0 do
			local t = box.tiles[i]
			if not t then
				t = box.clip:CreateTexture(nil, "BORDER")
				Try(t, "SetDesaturated", true)
				t:SetAlpha(WM.ART_ALPHA)
				box.tiles[i] = t
				wm.tiles[#wm.tiles + 1] = t
			end
			local col, row = (i - 1) % art.cols, math.floor((i - 1) / art.cols)
			t:SetTexture(art.files[i])
			t:SetVertexColor(tint[1], tint[2], tint[3])
			t:SetSize(art.tw * k, art.th * k)
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", box.clip, "TOPLEFT", (col * art.tw - L.u0 * art.lw) * k, -(row * art.th - L.v0 * art.lh) * k)
			t:Show()
		end
		for i = (art and art.cols * art.rows or 0) + 1, #box.tiles do box.tiles[i]:Hide() end
		-- the band over the art's own lettering: at its place on the art (v), scaled with the art
		local by = art and (WM.BAND.v - L.v0) / (L.v1 - L.v0) * L.h or WM.BAND.y
		local half = art and math.max(10, WM.BAND.halfV * art.lh * k) or WM.BAND.half
		for i, t in ipairs(box.band or {}) do
			t:ClearAllPoints()
			t:SetPoint(i == 1 and "BOTTOMLEFT" or "TOPLEFT", box.clip, "TOPLEFT", 0, -by)
			t:SetPoint(i == 1 and "BOTTOMRIGHT" or "TOPRIGHT", box.clip, "TOPRIGHT", 0, -by)
			t:SetHeight(half)
			if art then t:Show() else t:Hide() end
		end
	end
	wm.kind = kind
end

-- The static layer: art, routes, boats and node dots, built once per session and side.
local function drawStatic(wm)
	local s = side() or "H"
	-- a new focus (or calibration) re-arranges the boxes: a new views table, so redraw
	if wm.staticFor == s and wm.staticViews == views() then return end
	wm.staticFor, wm.staticViews = s, views()
	placeArt(wm)
	release(wm.lines)
	release(wm.dots)
	-- fewer points until the budget holds
	local eps, list = WM.EPS, nil
	for _ = 1, 8 do
		list = routes(s, eps)
		if not wm.hasLines or segments(list) + #wm.tiles <= WM.BUDGET - 40 then break end
		eps = eps * 2
	end
	local spacing = WM.SPACING
	if not wm.hasLines then
		local total = 0
		for _, r in ipairs(list) do
			for i = 1, #r.pts - 3, 2 do
				total = total + math.sqrt((r.pts[i + 2] - r.pts[i]) ^ 2 + (r.pts[i + 3] - r.pts[i + 1]) ^ 2)
			end
		end
		spacing = math.max(spacing, total / math.max(1, WM.BUDGET - #wm.tiles - 40))
	end
	for _, r in ipairs(list) do
		if r.kind == "boat" then
			drawPolyline(wm, r.pts, WM.BOAT, WM.THICK, WM.BOAT_PERIOD, spacing * 1.5)
		else
			drawPolyline(wm, r.pts, WM.FLIGHT, WM.THICK, WM.PERIOD, spacing)
		end
	end
	wm.staticLines, wm.staticDots = wm.lines.used, wm.dots.used
	wm.routeCount = #list
	-- node dots (hover: the town's name)
	local V, i = views(), 0
	local ids = {}
	for id, n in pairs(type(W.TAXI) == "table" and W.TAXI.nodes or {}) do
		if usable(n, s) and V[n[2]] then ids[#ids + 1] = id end
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local n = W.TAXI.nodes[id]
		local x, y = toPane(V[n[2]], n[3], n[4])
		if x then
			i = i + 1
			local b = wm.nodes[i]
			if not b then
				b = CreateFrame("Button", nil, wm.nodeLayer)
				b:SetSize(WM.NODE_HIT, WM.NODE_HIT)
				b.dot = T.Circle(b, 4, "muted", "ARTWORK")
				b.dot:SetPoint("CENTER", b, "CENTER")
				wm.nodes[i] = b
			end
			b:ClearAllPoints()
			b:SetPoint("CENTER", wm.view, "TOPLEFT", x, -y)
			T.Tip(b, n[1], "A flight master.")
			b:Show()
		end
	end
	for k = i + 1, #wm.nodes do wm.nodes[k]:Hide() end
end

---------------------------------------------------------------------------
-- Pins: drivers, bounties, the rider, the chosen route
---------------------------------------------------------------------------

-- (design round 4) the sea arrow's words' width: the font's own measure (a string's width as the game reports it can be
-- the smaller, drawn one under a UI scale), never less than the string says
local function wordsWidth(fs, text)
	local a = N(T.MeasureText(text, "caption", "medium")) or 0
	local b = N(fs and fs.GetStringWidth and fs:GetStringWidth()) or 0
	local w = math.max(a, b)
	return w > 0 and math.ceil(w) or (#text * 6)
end

-- (r33, HUNT-55) the wishes riders pinned are shown only while Settings > Driving "Show what riders want" is on
local function watching()
	local d = W.db and W.db.drive
	return not (type(d) == "table" and type(d.opts) == "table" and d.opts.watchBounty == false)
end

local function placeWorld(name)
	local p = type(W.ExactPlace) == "function" and call(W.ExactPlace, name) or nil
	if type(p) ~= "table" and type(W.FindPlace) == "function" then p = call(W.FindPlace, name) end
	if type(p) ~= "table" then return nil end
	local cont, wx, wy = call(W.PlaceWorld, p)
	if not (N(cont) and N(wx) and N(wy)) then return nil end
	return N(cont), N(wx), N(wy), p
end

local function waitLine(d)
	local q = N(d.queue)
	if q == 0 then return "No queue" end
	if q then return q .. " in the queue" end
	return nil
end

local function pinFor(wm, i)
	local p = wm.pins[i]
	if p then return p end
	p = CreateFrame("Button", nil, wm.pinLayer)
	p:SetSize(WM.PIN, WM.PIN)
	p:SetFrameLevel((N(wm.pinLayer:GetFrameLevel()) or 0) + 4) -- (round 13, I21) above the bounty coins
	p.icon = T.Icon(p, "pin", WM.PIN, "accent", "ARTWORK")
	p.icon:SetPoint("BOTTOM", p, "CENTER", 0, -2)
	p.count = T.Text(p, "caption", "white", "CENTER", "bold", "OVERLAY")
	p.count:SetPoint("CENTER", p.icon, "CENTER", 0, 2)
	p:RegisterForClicks("LeftButtonUp")
	safeScript(p, "OnClick", function(self)
		if self.key and UI.Show then UI.Show("confirm", self.key) end
	end)
	T.Press(p)
	wm.pins[i] = p
	return p
end

local function coinFor(wm, i)
	local c = wm.coins[i]
	if c then return c end
	c = CreateFrame("Frame", nil, wm.pinLayer)
	c:SetSize(WM.COIN, WM.COIN)
	-- (round 13, I21) under the driver pins: a coin never hides a pin
	c:SetFrameLevel((N(wm.pinLayer:GetFrameLevel()) or 0) + 1)
	c.icon = T.Icon(c, "coin", WM.COIN, "white", "ARTWORK")
	c.icon:SetPoint("CENTER", c, "CENTER")
	c.icon:SetVertexColor(WM.SILVER[1], WM.SILVER[2], WM.SILVER[3], WM.SILVER[4])
	c.count = T.Text(c, "caption", "ink", "CENTER", "bold", "OVERLAY")
	c.count:SetPoint("CENTER", c, "CENTER", 0, 0)
	c:EnableMouse(true) -- (AUD-150) a tooltip needs the mouse; the coin is not clickable
	wm.coins[i] = c
	return c
end

-- the spots the map shows besides the flight masters: you, the driver pins, your own pin, the
-- bounty coins. layout() folds them into the crop; drawDrivers keeps price tags off them.
function Mod.extraPoints()
	local out = {}
	local cont, wx, wy = W.WorldPos(W.MyPosition())
	if N(cont) and N(wx) and N(wy) and hereCont() == N(cont) then out[#out + 1] = { kind = "me", cont = N(cont), wx = wx, wy = wy } end
	local list = type(UI.Drivers) == "function" and call(UI.Drivers) or {}
	for _, d in ipairs(type(list) == "table" and list or {}) do
		if type(d) == "table" and S(d.dest) then
			local c, x, y = placeWorld(d.dest)
			if c then out[#out + 1] = { kind = "driver", cont = c, wx = x, wy = y } end
		end
	end
	local b = type(W.DriverBeacon) == "function" and call(W.DriverBeacon) or nil
	if type(b) == "table" and not b.only then
		local c, x, y
		if S(b.dest) then c, x, y = placeWorld(b.dest) end
		if not c and N(b.mapID) and N(b.x) and N(b.y) then c, x, y = W.WorldPos(b.mapID, b.x, b.y) end
		if c then out[#out + 1] = { kind = "own", cont = c, wx = x, wy = y } end
	end
	local B = W.Bounty
	local want = {}
	if type(B) == "table" and type(B.Demand) == "function" and watching() then
		local ok, l = pcall(B.Demand)
		if ok and type(l) == "table" then for _, e in ipairs(l) do if type(e) == "table" and S(e.place) then want[#want + 1] = S(e.place) end end end
	end
	if type(B) == "table" and type(B.Mine) == "function" then
		local ok, m = pcall(B.Mine)
		if ok and type(m) == "table" and S(m.place) then want[#want + 1] = S(m.place) end
	end
	for _, place in ipairs(want) do
		local c, x, y = placeWorld(place)
		if c then out[#out + 1] = { kind = "coin", cont = c, wx = x, wy = y } end
	end
	return out
end

-- (round 31) pins of places so close that they would overlap (Ratchet and the Crossroads) are pushed apart,
-- each half the overlap on the axis that needs less, until none overlaps; a pin that moved stays inside its
-- continent's box. Groups in their sorted order: the same drivers give the same picture.
-- The group of the place in focus (fixedKey: the ring and the gold route's end are on that place) never
-- moves: the other pin of a pair moves the whole overlap instead.
local function spread(groups, order, fixedKey)
	local gs, D = {}, WM.PIN
	for k, gk in ipairs(order) do
		if k > WM.PINS then break end
		gs[#gs + 1] = groups[gk]
		gs[#gs].fixed = fixedKey ~= nil and gk == fixedKey
	end
	for _ = 1, 16 do
		local moved = false
		for i = 1, #gs - 1 do
			for j = i + 1, #gs do
				local a, b = gs[i], gs[j]
				local dx, dy = b.x - a.x, b.y - a.y
				local ox, oy = D - math.abs(dx), D - math.abs(dy)
				if ox > 0 and oy > 0 then
					local share = (a.fixed or b.fixed) and 1 or 0.5
					local ma, mb = a.fixed, b.fixed -- the one that stays put
					if ox <= oy then
						local s = (dx < 0 and -1 or 1) * (ox * share + 0.5)
						if not ma then a.x = a.x - s end
						if not mb then b.x = b.x + s end
					else
						local s = (dy < 0 and -1 or 1) * (oy * share + 0.5)
						if not ma then a.y = a.y - s end
						if not mb then b.y = b.y + s end
					end
					if not ma then a.moved = true end
					if not mb then b.moved = true end
					moved = true
				end
			end
		end
		for _, g in ipairs(gs) do
			local bx, by, bw, bh = Mod.Box(g.cont)
			if g.moved and bx then
				g.x = clamp(g.x, bx + D / 2, bx + bw - D / 2)
				g.y = clamp(g.y, by + D, by + bh - D / 2)
			end
		end
		if not moved then break end
	end
end

local function rectClear(keep, x, y, w, h, own)
	for _, r in ipairs(keep) do
		if r ~= own and x < r[1] + r[3] and r[1] < x + w and y < r[2] + r[4] and r[2] < y + h then return false end
	end
	return true
end

local function baseKeep(wm, skipOwn)
	local half, keep = WM.PIN / 2, {}
	for cont in pairs(WM.BOX) do
		local lr = wm.labelRects and wm.labelRects[cont]
		if lr and Mod.Box(cont) then keep[#keep + 1] = { lr[1] - 2, lr[2] - 2, lr[3] + 4, lr[4] + 4 } end
	end
	for _, e in ipairs(Mod.extraPoints()) do
		local x, y = Mod.Project(e.cont, e.wx, e.wy)
		if x then
			if e.kind == "me" then
				keep[#keep + 1] = { x - WM.ME / 2 - 1, y - WM.ME / 2 - 1, WM.ME + 2, WM.ME + 2 }
			elseif e.kind == "coin" then
				keep[#keep + 1] = { x, y - 18, WM.COIN, WM.COIN }
			elseif e.kind == "driver" and skipOwn then
				keep[#keep + 1] = { x - half + 2, y - WM.PIN + 2, WM.PIN - 4, WM.PIN }
			elseif e.kind == "own" then
				keep[#keep + 1] = { x - 12 - half + 2, y - WM.PIN + 2, WM.PIN - 4, WM.PIN }
				if not skipOwn then
					keep[#keep + 1] = wm.ownTagRect or { x - 12 - 18, y + half, 36, WM.TAG_H }
				end
			end
		end
	end
	-- the sea arrow's head and its "continues by" label (drawGold has drawn them already)
	local sp, seaLabel = wm.seaSpec, wm.seaArrow and wm.seaArrow.label
	if sp and seaLabel and seaLabel.IsShown and seaLabel:IsShown() then
		local hd = sp.head
		keep[#keep + 1] = { math.min(hd[1], hd[3]), hd[2], math.abs(hd[3] - hd[1]), hd[6] - hd[2] }
		local lw = wordsWidth(seaLabel, sp.label)
		local lh = math.max(N(seaLabel.GetStringHeight and seaLabel:GetStringHeight()) or 0, T.DrawnSize("caption") + 2)
		local slx = sp.dir > 0 and sp.x2 - lw or sp.x2
		local sly = sp.labelY or (sp.below and (sp.y2 + 5) or (sp.y2 - 3 - lh))
		keep[#keep + 1] = { slx - 2, sly - 2, lw + 4, lh + 4 }
	end
	return keep
end

local function drawDrivers(wm)
	local list = type(UI.Drivers) == "function" and call(UI.Drivers) or {}
	local groups, order = {}, {}
	for _, d in ipairs(type(list) == "table" and list or {}) do
		-- (round 13, I21) every driver the list shows has a pin: a busy or paused one muted
		if type(d) == "table" and S(d.dest) then
			local cont, wx, wy, p = placeWorld(d.dest)
			if not cont and d.mapID and d.x and d.y then cont, wx, wy = W.WorldPos(d.mapID, d.x, d.y) end
			local x, y = Mod.Project(cont, wx, wy)
			if x then
				local gk = p and W.NormPlace(p.name) or (math.floor(x) .. ":" .. math.floor(y))
				local g = groups[gk]
				if not g then
					g = { x = x, y = y, cont = cont, list = {} }
					groups[gk] = g
					order[#order + 1] = gk
				end
				g.list[#g.list + 1] = d
			end
		end
	end
	table.sort(order)
	-- the top three by prominence get a price tag
	local ranked = {}
	for _, gk in ipairs(order) do
		local g = groups[gk]
		local best, glow = g.list[1], -1
		for _, d in ipairs(g.list) do
			local v = type(UI.Prominence) == "function" and N(call(UI.Prominence, d, list)) or 0
			if d.state == "open" then v = (v or 0) + 1000 end -- an open driver speaks for the place
			if v and v > glow then best, glow = d, v end
		end
		g.best, g.glow = best, glow
		ranked[#ranked + 1] = g
	end
	table.sort(ranked, function(a, b)
		if a.glow ~= b.glow then return a.glow > b.glow end
		return (a.best.price or 0) < (b.best.price or 0)
	end)
	for rank, g in ipairs(ranked) do g.rank = rank end
	local fr = wm.route
	local focus = S(wm.focus) or (type(fr) == "table" and S(fr.to)) or nil
	local fpl = focus and select(4, placeWorld(focus))
	spread(groups, order, fpl and W.NormPlace(fpl.name) or nil)
	-- what a price tag must not cover: the continents' names and every pin
	local half, keep, pinBox = WM.PIN / 2, baseKeep(wm, false), {}
	for k, gk in ipairs(order) do
		if k > WM.PINS then break end
		local g = groups[gk]
		-- the icon hangs from the pin's centre: about y - 20 to y + 2
		pinBox[gk] = { g.x - half + 2, g.y - WM.PIN + 2, WM.PIN - 4, WM.PIN }
		keep[#keep + 1] = pinBox[gk]
	end
	local n = 0
	for _, gk in ipairs(order) do
		local g = groups[gk]
		if n >= WM.PINS then break end
		n = n + 1
		local p, d = pinFor(wm, n), g.best
		p.key = d.key
		p:ClearAllPoints()
		p:SetPoint("CENTER", wm.view, "TOPLEFT", g.x, -g.y)
		local open = d.state == "open"
		p.icon:SetVertexColor(T.RGB(d.creator and "gold" or (open and "accent" or "muted"), open and 1 or 0.8))
		p.count:SetText(#g.list > 1 and tostring(#g.list) or "")
		local lines = {}
		for _, o in ipairs(g.list) do
			local wl = waitLine(o)
			lines[#lines + 1] = o.short .. " · " .. money(o.price) .. (o.state == "paused" and " · paused" or o.state ~= "open" and " · busy" or (wl and (" · " .. wl) or ""))
		end
		T.Tip(p, "To " .. d.dest, table.concat(lines, "\n") .. (open and ("\nClick to book " .. d.short .. ".") or "\nClick to see this driver."))
		if d.creator then
			if not p.crown then p.crown = T.Crown(p, 14, d.key) end
			if p.crown then
				p.crown:ClearAllPoints()
				p.crown:SetPoint("BOTTOM", p.icon, "TOP", 0, -2)
				p.crown:Show()
			end
		elseif p.crown then
			p.crown:Hide()
		end
		local placed = false
		if g.rank <= WM.TAGS then
			if not p.tag then
				p.tag = T.Tag(p, "", { h = WM.TAG_H, size = WM.TAG_SIZE, pad = 7, fill = "card", text = "gold" })
				p.tag:SetPoint("LEFT", p, "RIGHT", 1, 0)
			end
			p.tag:SetTag(money(d.price))
			-- (2.3.2, S7) the price stays inside its continent: near a box's right edge it goes left of the pin
			-- right of the pin, else left; neither clear of the names, pins and tags: no tag
			local bx, _, bw = Mod.Box(g.cont)
			local tw = N(p.tag:GetWidth()) or (#money(d.price) * 7 + 14)
			local th, ty = WM.TAG_H, g.y - WM.TAG_H / 2
			local rx, lx = g.x + half + 1, g.x - half - 1 - tw
			local inR = not bx or rx + tw <= bx + bw - 2
			local inL = not bx or lx >= bx + 2
			p.tag:ClearAllPoints()
			if inR and rectClear(keep, rx, ty, tw, th, pinBox[gk]) then
				p.tag:SetPoint("LEFT", p, "RIGHT", 1, 0)
				placed = { rx, ty, tw, th }
			elseif inL and rectClear(keep, lx, ty, tw, th, pinBox[gk]) then
				p.tag:SetPoint("RIGHT", p, "LEFT", -1, 0)
				placed = { lx, ty, tw, th }
			end
		end
		if placed then
			keep[#keep + 1] = placed
			p.tag:Show()
		elseif p.tag then
			p.tag:Hide()
		end
		p:Show()
	end
	for i = n + 1, #wm.pins do wm.pins[i]:Hide() end
	wm.pinCount = n
end

-- (2.3.2, B4) your own pin while you are open as a driver: violet, "You", beside the place's driver pin; a tap
-- opens the Drive tab (you can't book yourself).
local function drawOwn(wm)
	local b = type(W.DriverBeacon) == "function" and call(W.DriverBeacon) or nil
	local p = wm.ownPin
	local cont, x, y
	if type(b) == "table" and not b.only then
		local wx, wy = nil, nil
		if S(b.dest) then cont, wx, wy = placeWorld(b.dest) end
		if not cont and N(b.mapID) and N(b.x) and N(b.y) then cont, wx, wy = W.WorldPos(b.mapID, b.x, b.y) end
		x, y = Mod.Project(cont, wx, wy)
	end
	if not x then
		if p then p:Hide() end
		wm.ownTagRect = nil
		return
	end
	if not p then
		p = CreateFrame("Button", nil, wm.pinLayer)
		p:SetSize(WM.PIN, WM.PIN)
		p:SetFrameLevel((N(wm.pinLayer:GetFrameLevel()) or 0) + 5)
		p.icon = T.Icon(p, "pin", WM.PIN, "accent", "ARTWORK")
		p.icon:SetPoint("BOTTOM", p, "CENTER", 0, -2)
		p.tag = T.Tag(p, "You", { h = WM.TAG_H, size = WM.TAG_SIZE, pad = 7, fill = "card", text = "white" })
		p.tag:SetPoint("TOP", p, "BOTTOM", 0, 0)
		p:RegisterForClicks("LeftButtonUp")
		safeScript(p, "OnClick", function()
			if UI.SelectTab then UI.SelectTab("Drive") end
		end)
		T.Press(p)
		wm.ownPin = p
	end
	T.Tip(p, "You, as a driver", "Riders see you in " .. (S(b.destShown) or S(b.dest) or "your place") .. " for " .. money(N(b.price) or 0)
		.. ". You can't book yourself. Click to open the Drive tab.")
	local ox = x - 12
	p:ClearAllPoints()
	p:SetPoint("CENTER", wm.view, "TOPLEFT", ox, -y)
	local half, tw, th = WM.PIN / 2, N(p.tag:GetWidth()) or 36, WM.TAG_H
	local keep = baseKeep(wm, true)
	local bx, by, bw, bh = Mod.Box(cont)
	local cands = {
		{ "TOP", p, "BOTTOM", 0, 0, { ox - tw / 2, y + half, tw, th } },
		{ "BOTTOM", p.icon, "TOP", 0, 1, { ox - tw / 2, y - WM.PIN - 3 - th, tw, th } },
		{ "RIGHT", p, "LEFT", -1, 0, { ox - half - 1 - tw, y - th / 2, tw, th } },
		{ "LEFT", p, "RIGHT", 1, 0, { ox + half + 1, y - th / 2, tw, th } },
	}
	local function inBox(r) return bx and r[1] >= bx + 2 and r[1] + r[3] <= bx + bw - 2 and r[2] >= by + 2 and r[2] + r[4] <= by + bh - 2 end
	local function inPane(r) return r[1] >= 0 and r[1] + r[3] <= WM.PANE_W and r[2] >= 0 and r[2] + r[4] <= WM.LEGEND_Y end
	local picked
	for _, fn in ipairs({ inBox, inPane }) do
		for _, c in ipairs(cands) do
			if not picked and fn(c[6]) and rectClear(keep, c[6][1], c[6][2], c[6][3], c[6][4]) then picked = c end
		end
	end
	if not picked then
		for _, c in ipairs(cands) do
			if not picked and rectClear(keep, c[6][1], c[6][2], c[6][3], c[6][4]) then picked = c end
		end
	end
	picked = picked or cands[1]
	p.tag:ClearAllPoints()
	p.tag:SetPoint(picked[1], picked[2], picked[3], picked[4], picked[5])
	wm.ownTagRect = picked[6]
	p:Show()
end

local function drawBounties(wm)
	local B = W.Bounty
	local want = {}
	if type(B) == "table" and type(B.Demand) == "function" and watching() then
		local ok, list = pcall(B.Demand)
		if ok and type(list) == "table" then
			for _, e in ipairs(list) do
				if type(e) == "table" and S(e.place) then want[#want + 1] = { place = S(e.place), n = N(e.riders) or 1 } end
			end
		end
	end
	if type(B) == "table" and type(B.Mine) == "function" then
		local ok, mine = pcall(B.Mine)
		if ok and type(mine) == "table" and S(mine.place) then
			local key, merged = W.NormPlace(S(mine.place)), false
			for _, e in ipairs(want) do
				if W.NormPlace(e.place) == key then e.n, e.mine, e.others, merged = e.n + 1, true, e.n, true break end
			end
			if not merged then want[#want + 1] = { place = S(mine.place), n = 1, mine = true } end
		end
	end
	local n = 0
	wm.coinAt = {}
	for _, e in ipairs(want) do
		local cont, wx, wy, pl = placeWorld(e.place)
		local x, y = Mod.Project(cont, wx, wy)
		if x and n < WM.PINS then
			n = n + 1
			local c = coinFor(wm, n)
			c:ClearAllPoints()
			c:SetPoint("CENTER", wm.view, "TOPLEFT", x + 9, -(y - 9))
			wm.coinAt[W.NormPlace(pl and pl.name or e.place)] = { x + 9, y - 9 }
			c.count:SetText(tostring(math.min(99, e.n)))
			T.Tip(c, "Wanted: " .. e.place, ((e.mine and "Your bounty. " or "") .. ((not e.mine or e.others) and (((e.others or e.n) == 1 and "1 rider wants to go here. ") or ((e.others or e.n) .. " riders want to go here. ")) or ""))
				.. "A bounty is a wish, not a payment.")
			c:Show()
		end
	end
	for i = n + 1, #wm.coins do wm.coins[i]:Hide() end
	wm.coinCount = n
end

local function drawRider(wm)
	local cont, wx, wy = W.WorldPos(W.MyPosition())
	local x, y = Mod.Project(cont, wx, wy)
	if x then
		-- backstop: the dot never floats outside its continent's box
		local bx, by, bw, bh = Mod.Box(cont)
		if bx then x, y = clamp(x, bx, bx + bw), clamp(y, by, by + bh) end
		wm.me:ClearAllPoints()
		wm.me:SetPoint("CENTER", wm.view, "TOPLEFT", x, -y)
		if not wm.me:IsShown() then
			wm.me:Show()
			if wm.me.pulse then wm.me.pulse:Start() end
		end
	elseif wm.me:IsShown() then
		if wm.me.pulse then wm.me.pulse:Stop() end
		wm.me:Hide()
	end
end

-- The chosen route (Confirm): the flight the rider would take, leg by leg along the splines.
-- the zeppelin towers (W.TAXI node ids): a crossing between two of them is a zeppelin, any other a boat
local ZEPPELIN = { [11] = true, [20] = true, [23] = true }

local function drawGold(wm)
	release(wm.gold)
	-- no stale "continues by" arrow when the route has gone; it is drawn again below when needed
	local SeaHide = W.Mod("UI.Rider.SeaRoute")
	wm.seaSpec = nil
	if wm.seaArrow and SeaHide then SeaHide.Hide(wm.seaArrow) end
	wm.focusRing:Hide()
	local r = wm.route
	if type(r) == "table" and S(r.to) and type(W.FlightRoute) == "function" then
		local ids = call(W.FlightRoute, S(r.from), S(r.to))
		local V, T0 = views(), W.TAXI
		local saveLines, saveDots = wm.lines, wm.dots
		wm.lines, wm.dots = wm.gold, wm.gold
		local seaLegs = {}
		for i = 1, type(ids) == "table" and #ids - 1 or 0 do
			local a, b = ids[i], ids[i + 1]
			local lo, hi = math.min(a, b), math.max(a, b)
			local p = type(W.TAXI_PATHS) == "table" and W.TAXI_PATHS[lo .. ":" .. hi]
			local na, nb = T0.nodes[a], T0.nodes[b]
			local pts, crossing = {}, false
			if p and na and V[T0.nodes[lo][2]] then
				local L = V[T0.nodes[lo][2]]
				for k = 1, #p - 1, 2 do
					local x, y = toPane(L, p[k], p[k + 1])
					if x then
						pts[#pts + 1] = x
						pts[#pts + 1] = y
					end
				end
				if a > b then
					local rev = {}
					for k = #pts - 1, 1, -2 do
						rev[#rev + 1] = pts[k]
						rev[#rev + 1] = pts[k + 1]
					end
					pts = rev
				end
			elseif na and nb and V[na[2]] and V[nb[2]] then
				local x1, y1 = toPane(V[na[2]], na[3], na[4])
				local x2, y2 = toPane(V[nb[2]], nb[3], nb[4])
				if x1 and x2 then pts, crossing = { x1, y1, x2, y2 }, true end
			end
			-- the flight legs solid; a boat or zeppelin crossing dashed (as the boats are), in the same violet
			if #pts >= 4 then
				drawPolyline(wm, simplify(pts, WM.EPS), WM.ROUTE, WM.GOLD_THICK, crossing and WM.BOAT_PERIOD or WM.PERIOD, 4, not crossing)
				if na and nb then
					seaLegs[#seaLegs + 1] = { cont = na[2], to = nb[2], pts = pts,
						kind = crossing and ((ZEPPELIN[a] and ZEPPELIN[b]) and "zeppelin" or "boat") or "flight" }
				end
			end
		end
		wm.lines, wm.dots = saveLines, saveDots
		-- your side's legs are drawn above; the arrow at the cut edge says how the route goes on
		local SeaMod = W.Mod("UI.Rider.SeaRoute")
		local split = SeaMod.Split(seaLegs, seaLegs[1] and seaLegs[1].cont)
		local x = split.cross and Mod.CutEdge(split.cross.cont)
		local spec = x and SeaMod.Arrow(split, x)
		wm.seaArrow = spec and SeaMod.Draw(wm.view, spec, WM.ROUTE, wm.seaArrow) or (SeaMod.Hide(wm.seaArrow) or wm.seaArrow)
		-- (design round 4) the words never sit on a continent's name: when they would, they go under the arrow
		if spec and wm.seaArrow and wm.seaArrow.label then
			local seaText = wm.seaArrow.label
			local lw = wordsWidth(seaText, spec.label)
			local lh = T.DrawnSize("caption") + 2
			local lx, ly = spec.dir > 0 and spec.x2 - lw or spec.x2, spec.y2 - 3 - lh
			local function hitsLabels(y0)
				for _, lr in pairs(wm.labelRects or {}) do
					if lx < lr[1] + lr[3] + 2 and lr[1] < lx + lw + 2 and y0 < lr[2] + lr[4] + 2 and lr[2] < y0 + lh + 2 then return true end
				end
				return false
			end
			if hitsLabels(ly) then
				spec.below = true
			else
				local mc, mx, my = W.WorldPos(W.MyPosition())
				mx, my = Mod.Project(mc, mx, my)
				if mx then
					local bx, by, bw, bh = Mod.Box(mc)
					if bx then mx, my = clamp(mx, bx, bx + bw), clamp(my, by, by + bh) end
					local mr = WM.ME / 2 + 1
					if lx < mx + mr and mx - mr < lx + lw and ly < my + mr and my - mr < ly + lh then
						if not hitsLabels(spec.y2 + 5) then
							spec.below = true
						else
							spec.labelY = my - mr - lh - 1
						end
					end
				end
			end
			if spec.below or spec.labelY then wm.seaArrow = SeaMod.Draw(wm.view, spec, WM.ROUTE, wm.seaArrow) end
		end
		wm.seaSpec = spec
	end
end

-- the ring on the booked place (after the pins and coins it may centre on)
local function drawFocus(wm)
	local r = wm.route
	local focus = S(wm.focus) or (type(r) == "table" and S(r.to)) or nil
	if focus then
		local cont, wx, wy, pl = placeWorld(focus)
		local x, y = Mod.Project(cont, wx, wy)
		-- (2.3.2, S7) a bounty coin there: the ring is centred on the coin, not beside it
		local coin = x and wm.coinAt and wm.coinAt[W.NormPlace(pl and pl.name or focus)]
		if coin then x, y = coin[1], coin[2] end
		if x then
			wm.focusRing:ClearAllPoints()
			wm.focusRing:SetPoint("CENTER", wm.view, "TOPLEFT", x, -y)
			wm.focusRing:Show()
		end
	end
end

local function redraw(wm)
	if not (wm and wm.mode == "world" and wm.view:IsVisible() and unfolded()) then return false end
	-- where you are: the continent you're on gets the focus (a new arrangement when it changes)
	local here = hereCont()
	if here ~= CACHE.focus then CACHE.focus, CACHE.views = here, nil end
	-- you moved outside the crop: lay out again (once per spot, so an art edge can't loop)
	local V = CACHE.views
	if V and here and V[here] then
		local c, wx, wy = W.WorldPos(W.MyPosition())
		local L = V[here]
		local u, v = L.uv(N(wx) or 0, N(wy) or 0)
		if u and v and (u < L.u0 or u > L.u1 or v < L.v0 or v > L.v1) then
			local key = here .. ":" .. string.format("%.4f:%.4f", u, v)
			if CACHE.foldKey ~= key then CACHE.foldKey, CACHE.views = key, nil end
		end
	end
	drawStatic(wm)
	-- the chosen route and its sea arrow first: drawOwn and drawDrivers keep tags off the arrow's label
	drawGold(wm)
	drawOwn(wm)
	drawDrivers(wm)
	drawBounties(wm)
	drawRider(wm)
	drawFocus(wm)
	wm.redraws = (wm.redraws or 0) + 1
	return true
end

function Mod.Refresh()
	local any = false
	for _, wm in pairs(CACHE.maps) do any = redraw(wm) or any end
	return any
end

local function soon()
	if CACHE.pending then return end
	CACHE.pending = true
	W.After(WM.DEBOUNCE, function()
		CACHE.pending = false
		Mod.Refresh()
	end)
end

---------------------------------------------------------------------------
-- Build and Show
---------------------------------------------------------------------------

local function buildView(wm)
	local v = wm.view
	Try(v, "SetClipsChildren", true)
	v.noEdgeFade = "map" -- the map, not a list (S6's check skips it)
	wm.hasLines = type(v.CreateLine) == "function"
	local probeTex = v:CreateTexture(nil, "BACKGROUND")
	wm.canRotate = type(probeTex.SetRotation) == "function"
	probeTex:Hide()
	wm.boxes, wm.tiles = {}, {}
	for cont, b in pairs(WM.BOX) do
		local box = { tiles = {} }
		box.clip = CreateFrame("Frame", nil, v)
		box.clip:SetPoint("TOPLEFT", v, "TOPLEFT", WM.AREA.x, -WM.BOX_Y) -- (placeArt: the cropped box)
		box.clip:SetSize(WM.AREA.w / 2, WM.BOX_H)
		Try(box.clip, "SetClipsChildren", true)
		box.clip.noEdgeFade = "map"
		box.bg = T.Tex(box.clip, "mapbg", "BACKGROUND")
		box.bg:SetAllPoints(box.clip)
		box.bg:SetVertexColor(0.55, 0.5, 0.75)
		box.fade = {}
		for i, side_ in ipairs({ "TOP", "BOTTOM" }) do
			local f = T.Tex(box.clip, "fade", "ARTWORK", 2)
			f:SetPoint(side_ .. "LEFT", box.clip, side_ .. "LEFT")
			f:SetPoint(side_ .. "RIGHT", box.clip, side_ .. "RIGHT")
			f:SetHeight(36)
			if i == 1 then f:SetTexCoord(0, 1, 1, 0) end
			f:SetVertexColor(T.RGB("black", 0.7))
			box.fade[i] = f
		end
		-- inside the box's top edge (over its dark fade): above the box it sat under the Here/World control
		-- (round 13, I21) the band over the art's own name (shown with game art only: placeArt)
		box.band = {}
		for i = 1, 2 do
			local t = T.Tex(box.clip, "fade", "BORDER", 3)
			t:SetPoint(i == 1 and "BOTTOMLEFT" or "TOPLEFT", box.clip, "TOPLEFT", 0, -WM.BAND.y)
			t:SetPoint(i == 1 and "BOTTOMRIGHT" or "TOPRIGHT", box.clip, "TOPRIGHT", 0, -WM.BAND.y)
			t:SetHeight(WM.BAND.half)
			if i == 2 then t:SetTexCoord(0, 1, 1, 0) end
			t:SetVertexColor(0.05, 0.04, 0.1, WM.BAND.alpha)
			t:Hide()
			box.band[i] = t
		end
		-- (design round 4) the name stands on the pane just above its box (never under the routes); placeArt puts it
		box.label = T.Text(v, WM.LABEL_SIZE, "muted", "LEFT", "medium", "OVERLAY")
		box.label:SetText(b.name)
		wm.boxes[cont] = box
	end
	wm.routeLayer = CreateFrame("Frame", nil, v)
	wm.routeLayer:SetAllPoints(v)
	wm.lines = newPool(wm.routeLayer, wm.hasLines and "line" or "tex")
	wm.dots = newPool(wm.routeLayer, "tex")
	wm.gold = newPool(wm.routeLayer, wm.hasLines and "line" or "tex")
	wm.nodeLayer = CreateFrame("Frame", nil, v)
	wm.nodeLayer:SetAllPoints(v)
	wm.nodes = {}
	wm.pinLayer = CreateFrame("Frame", nil, v)
	wm.pinLayer:SetAllPoints(v)
	wm.pinLayer:SetFrameLevel((N(wm.nodeLayer:GetFrameLevel()) or 0) + 2)
	wm.pins, wm.coins = {}, {}
	wm.focusRing = T.Tex(wm.pinLayer, "ring", "OVERLAY")
	wm.focusRing:SetSize(26, 26)
	wm.focusRing:SetVertexColor(WM.ROUTE[1], WM.ROUTE[2], WM.ROUTE[3], 0.9)
	wm.focusRing:Hide()
	wm.me = CreateFrame("Frame", nil, wm.pinLayer)
	wm.me:SetSize(WM.ME, WM.ME)
	wm.me.dot = T.Circle(wm.me, WM.ME, "white", "OVERLAY")
	wm.me.dot:SetPoint("CENTER", wm.me, "CENTER")
	wm.me.pulse = A.Pulse(wm.me, { size = 40, colour = "glow", alpha = 0.3, period = 3, rings = 1, texture = "ring" }) -- flat rings, not the blurred pulse
	wm.me:Hide()
	-- legend: -- flight  .. boat (or zeppelin)  * driver  $ bounty
	-- (round 13, I21) the Horde's dashed crossings are mostly zeppelins: the legend says so
	local x = 12
	wm.legend = {}
	local crossWord = side() == "H" and "Boat or zeppelin" or "Boat"
	-- (design round 4) the two line swatches are the lines as drawn: the same violet, strength and dashes (a flight's
	-- long and faint, a crossing's short and strong)
	wm.swatch = {}
	for _, it in ipairs({ { "dash", WM.FLIGHT, "Flight", 20, 2, WM.PERIOD, "flight" }, { "dash", WM.BOAT, crossWord, 20, 2, WM.BOAT_PERIOD, "boat" },
		{ "pin", ACC, "Driver", 10, 10 }, { "coin", WM.SILVER, "Bounty", 10, 10 } }) do
		local t
		if it[6] and wm.hasLines then
			-- a Line, as the routes are (the dash pattern repeats along it)
			t = v:CreateLine(nil, "ARTWORK")
			t:SetStartPoint("TOPLEFT", v, x, -(WM.LEGEND_Y + 8))
			t:SetEndPoint("TOPLEFT", v, x + it[4], -(WM.LEGEND_Y + 8))
			Try(t, "SetThickness", WM.THICK)
		else
			t = T.Tex(v, it[1], "ARTWORK")
			t:SetSize(it[4], it[5])
			t:SetPoint("LEFT", v, "TOPLEFT", x, -(WM.LEGEND_Y + 8))
		end
		t:SetVertexColor(it[2][1], it[2][2], it[2][3], 1)
		if it[6] then
			t:SetTexture(T.MEDIA .. "dash", "REPEAT", "CLAMP")
			t:SetTexCoord(0, it[4] / it[6], 0, 1)
			t:SetAlpha(it[2][4] or 1)
			t.wuberLen = it[4]
			wm.swatch[it[7]] = t
		end
		local fs = T.Text(v, "sub", "muted", "LEFT", "regular")
		fs:SetPoint("LEFT", v, "TOPLEFT", x + it[4] + 4, -(WM.LEGEND_Y + 8))
		fs:SetText(it[3])
		wm.legend[#wm.legend + 1] = fs
		local tw = N(T.MeasureText(it[3], "sub", "regular")) or (#it[3] * 7)
		x = x + it[4] + 4 + math.ceil(tw) + 14
	end
	wm.built = true
end

local function applyMode(wm)
	local world = wm.mode == "world"
	if world and not wm.built and unfolded() then buildView(wm) end
	world = world and wm.built == true
	KitMod.setShown(wm.view, world)
	-- (Here only while it is docked in this pane: an undocked panel is its page's own again)
	if wm.here and wm.here:GetParent() == wm.holder then KitMod.setShown(wm.here, not world) end
	if wm.seg and wm.seg.value ~= wm.mode then wm.seg:SetValue(wm.mode) end
	if world then
		if redraw(wm) and A.FadeIn then A.FadeIn(wm.view, 0.18) end
	end
end

local function wire()
	if CACHE.wired then return end
	CACHE.wired = true
	W.Listen("DRIVERS", soon)
	W.Listen("BOUNTY", soon)
	-- a flight master was visited: its calibration may place the map better now
	W.Listen("FLIGHTS", function()
		local V = CACHE.views
		if V and V[0] and V[1] and V[0].how == "corners" and V[1].how == "corners" then return end -- (exact already)
		CACHE.views = nil
		for _, wm in pairs(CACHE.maps) do wm.staticFor = nil end
		soon()
	end)
end

-- (round 9, S15) Here/World in the app's dark segmented look (gold is for primary actions): a dark
-- track, the chosen half violet with white words, the other muted (white on hover).
-- T.Segmented lights the chosen half with its own opaque pill, shown or hidden (never an
-- alpha change); this only sets the look.
local function calmSeg(seg)
	seg.bg:SetColor("panel")
	seg.onStyle, seg.onText = "violet", "white"
	seg:SetValue(seg.value)
	return seg
end
Mod.calmSeg = calmSeg

-- (round 12, item 9) World first; the player's last pick after that (W.db.mapView, per account)
function Mod.Wanted()
	local v = W.db and W.db.mapView
	return v == "here" and "here" or "world"
end

-- holder: a side pane's holder (one per page). Returns the world view frame.
function Mod.Build(holder, opts)
	if not holder then return nil end
	opts = opts or {}
	local wm = CACHE.maps[holder]
	if not wm then
		wm = { holder = holder, mode = Mod.Wanted() }
		wm.view = CreateFrame("Frame", nil, holder)
		wm.view:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
		wm.view:SetSize(WM.PANE_W, WM.PANE_H)
		wm.view:Hide()
		wm.seg = T.Segmented(holder, {
			{ value = "here", label = "Here", tip = "The zone you're in, with drivers near you." },
			{ value = "world", label = "World", tip = "Both continents: flight routes, drivers and bounties." },
		}, wm.mode, function(v)
			wm.mode = v
			if W.db then W.db.mapView = v end -- (the player's pick: remembered)
			applyMode(wm)
			if type(wm.onMode) == "function" then W.Safe("map mode", wm.onMode, v) end
		end, WM.SEG_W, WM.SEG_H)
		-- (design 2, C) at the pane's top left, on the line of the window's buttons (they are over this pane's
		-- top right while the window is wide) and ending before them
		wm.seg:SetPoint("TOPLEFT", holder, "TOPLEFT", WM.SEG_X, -WM.SEG_Y)
		wm.seg:SetFrameLevel((N(wm.view:GetFrameLevel()) or 0) + 20)
		calmSeg(wm.seg)
		CACHE.maps[holder] = wm
		-- the pane shows (a page unfolds, or the Fold switches to this page): draw what it missed
		-- while hidden (a hook: the holder's own scripts stay the caller's)
		if type(holder.HookScript) == "function" then
			pcall(holder.HookScript, holder, "OnShow", function()
				if wm.mode == "world" then W.Safe("world map", applyMode, wm) end
			end)
		end
		wire()
	end
	if opts.here then wm.here = opts.here end
	if opts.onMode then wm.onMode = opts.onMode end
	if opts.mode then wm.mode = opts.mode == "world" and "world" or "here" else wm.mode = Mod.Wanted() end
	CACHE.last = wm
	applyMode(wm)
	return wm.view
end

-- mode: "here" | "world" | nil (keep); opts.holder, opts.route, opts.focus.
function Mod.Show(mode, opts)
	opts = opts or {}
	local wm = (opts.holder and CACHE.maps[opts.holder]) or CACHE.last
	if not wm then return nil end
	CACHE.last = wm
	if mode == "here" or mode == "world" then wm.mode = mode end
	if opts.route ~= nil then wm.route = opts.route or nil end
	if opts.focus ~= nil then wm.focus = opts.focus or nil end
	applyMode(wm)
	return wm.view
end

-- (tests) the session's caches start over: the probe, the projections, the built maps
function Mod.Reset()
	CACHE.kind, CACHE.art, CACHE.views, CACHE.corners, CACHE.conts, CACHE.focus = nil, nil, nil, nil, nil, nil
	for _, wm in pairs(CACHE.maps) do wm.staticFor = nil end
end
Mod.cache = CACHE
