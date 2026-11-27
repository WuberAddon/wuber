-- Module: UI.Map.Route
-- Purpose: The route line on the world map and on the app's map panel (M.RouteOnPanel, M.HideRouteOnPanel).
-- API: M.HideRouteOnPanel, M.RouteOnPanel
-- Internals: HideRoute, UpdateRoute
-- Uses: UI.Map.Base, UI.Map.Pins
-- Later: UI.Map.Map
-- Events: listens (none); fires (none)
-- Standalone: no
-- Test: tests/ui/map/route_test.lua
-- From: Map.lua 908-1200 (Wuber 2.2.1)
--
local _, W = ...
local Mod = W.Module("UI.Map.Route", { "UI.Map.Base", "UI.Map.Pins" })
local BaseMod = W.Mod("UI.Map.Base")
local PinsMod = W.Mod("UI.Map.Pins")
local MapMod = W.Mod("UI.Map.Map")
local Accent = BaseMod.Accent
local Canvas = BaseMod.Canvas
local DOT = BaseMod.DOT
local Driver = BaseMod.Driver
local FLOW = BaseMod.FLOW
local GAP = BaseMod.GAP
local MAGENTA = BaseMod.MAGENTA
local MAX_DOTS = BaseMod.MAX_DOTS
local MEDIA = BaseMod.MEDIA
local MapShown = BaseMod.MapShown
local MapXY = BaseMod.MapXY
local NewFrame = BaseMod.NewFrame
local OpenMapPos = BaseMod.OpenMapPos
local ROUTE = BaseMod.ROUTE
local ShownMapID = BaseMod.ShownMapID
local Stitched = BaseMod.Stitched
local VIOLET = BaseMod.VIOLET
local World = BaseMod.World
local call = BaseMod.call
local CanvasMetrics = PinsMod.CanvasMetrics
local M = W.Map

---------------------------------------------------------------------------
-- The route line: flowing violet dots from the rider to the destination
---------------------------------------------------------------------------

-- a line on a host frame: a holder (with the target ring) and a flow frame (the dots) that
-- one looping Translation slides by one gap toward the destination, then snaps back
local function NewRoute(host)
	local r = { dots = {}, host = host }
	local holder = NewFrame("Frame", host)
	holder:SetAllPoints(host)
	local flow = NewFrame("Frame", holder)
	flow:SetAllPoints(holder)
	local ag = flow:CreateAnimationGroup()
	ag:SetLooping("REPEAT")
	local move = ag:CreateAnimation("Translation")
	move:SetOffset(0, 0)
	move:SetDuration(FLOW)
	r.holder, r.flow, r.anim, r.move = holder, flow, ag, move
	-- the destination: a soft glow and a ring
	local glow = holder:CreateTexture(nil, "BACKGROUND")
	glow:SetTexture(MEDIA .. "glow")
	Accent(glow, 0.8)
	local ring = holder:CreateTexture(nil, "ARTWORK")
	ring:SetTexture(MEDIA .. "ring")
	ring:SetVertexColor(MAGENTA[1], MAGENTA[2], MAGENTA[3], 1)
	r.glow, r.ring = glow, ring
	holder:Hide()
	return r
end

local function RouteHide(r)
	if not r then return end
	if r.playing then
		r.anim:Stop()
		r.playing = false
	end
	r.holder:Hide()
	r.shownDots = 0
end

-- the part of the segment a..b inside the rect (Liang-Barsky): t0, t1 in 0..1, or nil
local function Clip(ax, ay, bx, by, x0, y0, x1, y1)
	local dx, dy = bx - ax, by - ay
	local t0, t1 = 0, 1
	local p = { -dx, dx, -dy, dy }
	local q = { ax - x0, x1 - ax, ay - y0, y1 - ay }
	for i = 1, 4 do
		if p[i] == 0 then
			if q[i] < 0 then return nil end
		else
			local t = q[i] / p[i]
			if p[i] < 0 then
				if t > t1 then return nil end
				if t > t0 then t0 = t end
			else
				if t < t0 then return nil end
				if t < t1 then t1 = t end
			end
		end
	end
	return t0, t1
end

local function Mix(a, b, t)
	return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
end

-- draws the line from (ax, ay) to (bx, by) in the host's units (y downwards), clipped to
-- clip = { x0, y0, x1, y1 }. upp = host units per screen pixel. Returns whether it shows.
local function RouteDraw(r, ax, ay, bx, by, upp, clip, opts)
	opts = opts or {}
	local dx, dy = bx - ax, by - ay
	local len = math.sqrt(dx * dx + dy * dy)
	local dotPx, gapPx = opts.dot or DOT, opts.gap or GAP
	if len ~= len or len < gapPx * upp then RouteHide(r) return false end
	local t0, t1 = Clip(ax, ay, bx, by, clip[1], clip[2], clip[3], clip[4])
	if not t0 or t1 - t0 <= 0 then RouteHide(r) return false end
	local ux, uy = dx / len, dy / len
	local gap = math.max(gapPx * upp, (t1 - t0) * len / MAX_DOTS)
	local size = dotPx * upp
	-- dot k sits at k * gap from the rider and flows one gap toward the destination
	local k0 = math.ceil(t0 * len / gap - 1e-6)
	local k1 = math.floor(t1 * len / gap + 1e-6) - 1
	if k1 - k0 + 1 > MAX_DOTS then k1 = k0 + MAX_DOTS - 1 end
	local n = 0
	local alpha = opts.alpha or 1
	for k = k0, k1 do
		n = n + 1
		local dot = r.dots[n]
		if not dot then
			dot = r.flow:CreateTexture(nil, "ARTWORK")
			dot:SetTexture(MEDIA .. "circle")
			r.dots[n] = dot
		end
		local d = k * gap
		local f = d / len
		local cr, cg, cb = Mix(VIOLET, MAGENTA, f)
		-- the first dots fade in where they appear (after the snap back)
		local a = alpha
		if k == 0 then a = alpha * 0.3 elseif k == 1 then a = alpha * 0.7 end
		dot:SetVertexColor(cr, cg, cb, a)
		dot:SetSize(size, size)
		dot:ClearAllPoints()
		dot:SetPoint("CENTER", r.flow, "TOPLEFT", ax + ux * d, -(ay + uy * d))
		dot:Show()
	end
	for i = n + 1, #r.dots do r.dots[i]:Hide() end
	r.shownDots = n
	-- the destination ring (only when it is in view)
	if bx >= clip[1] and bx <= clip[3] and by >= clip[2] and by <= clip[4] then
		r.ring:SetSize(16 * upp, 16 * upp)
		r.ring:ClearAllPoints()
		r.ring:SetPoint("CENTER", r.holder, "TOPLEFT", bx, -by)
		r.glow:SetSize(34 * upp, 34 * upp)
		r.glow:ClearAllPoints()
		r.glow:SetPoint("CENTER", r.holder, "TOPLEFT", bx, -by)
		r.ring:Show()
		r.glow:Show()
	else
		r.ring:Hide()
		r.glow:Hide()
	end
	r.holder:Show()
	-- the flow: restart only when the step really changed (a restart makes the dots jump)
	local ox, oy = ux * gap, -uy * gap
	local last = r.offset
	if not (r.playing and last and math.abs(last[1] - ox) <= gap * 0.01 and math.abs(last[2] - oy) <= gap * 0.01) then
		r.offset = { ox, oy }
		r.anim:Stop()
		r.move:SetOffset(ox, oy)
		local TH = W.Theme
		if not (TH and TH.ReduceMotion and TH.ReduceMotion()) then r.anim:Play() end -- (#305) Reduce motion: the dots stand still
		r.playing = true
	end
	return true
end

local mapRoute       -- the world map's line (made on first use)

-- the rider's ride, if the line should show: rider map, x, y, destination map, x, y
local function RouteEnds()
	local ride = W.ride
	if type(ride) ~= "table" or not ROUTE[ride.state] then return nil end
	local rm, rx, ry
	if type(W.MyPosition) == "function" then
		local ok, m, x, y = pcall(W.MyPosition)
		if ok then rm, rx, ry = W.Num(m), W.Num(x), W.Num(y) end
	end
	if not (rm and rx and ry) then return nil end -- unreadable (an instance): no line
	local place
	local dest = W.Str(ride.dest)
	if dest then
		if type(W.ExactPlace) == "function" then
			local ok, p = pcall(W.ExactPlace, dest)
			if ok and type(p) == "table" then place = p end
		end
		if not place and type(W.FindPlace) == "function" then
			local ok, p = pcall(W.FindPlace, dest)
			if ok and type(p) == "table" then place = p end
		end
	end
	local dm, dx, dy
	-- the driver stands where the summon goes: their spot when it is on the place's map
	local d = Driver(ride.driverKey)
	local drm, drx, dry
	if d then drm, drx, dry = W.Num(d.mapID), W.Num(d.x), W.Num(d.y) end
	if drm and drx and dry and (not place or W.Num(place.mapID) == drm) then
		dm, dx, dy = drm, drx, dry
	elseif place then
		dm, dx, dy = W.Num(place.mapID), W.Num(place.x), W.Num(place.y)
	end
	if not (dm and dx and dy) then return nil end
	-- never across continents
	local c1 = rm == dm and true or World(rm, rx, ry)
	local c2 = rm == dm and true or World(dm, dx, dy)
	if not (c1 and c2) or c1 ~= c2 then return nil end
	return rm, rx, ry, dm, dx, dy
end

-- the part of the canvas that is on screen, in canvas units: x0, y0, x1, y1
local function ViewRect(child, w, h, stitched)
	local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
	local function edges(f)
		local okl, l = call(f, "GetLeft")
		local okr, r = call(f, "GetRight")
		local okt, t = call(f, "GetTop")
		local okb, b = call(f, "GetBottom")
		local oke, e = call(f, "GetEffectiveScale")
		l, r, t, b, e = okl and W.Num(l), okr and W.Num(r), okt and W.Num(t), okb and W.Num(b), oke and W.Num(e)
		if not (l and r and t and b and e and e > 0) then return nil end
		return l * e, r * e, t * e, b * e, e
	end
	local x0, y0, x1, y1
	if type(sc) == "table" then
		local cl, _, ct, _, ce = edges(child)
		local sl, sr, st, sb = edges(sc)
		if cl and sl then
			x0, x1 = (sl - cl) / ce, (sr - cl) / ce
			y0, y1 = (ct - st) / ce, (ct - sb) / ce
		end
	end
	if not (x0 and x1 > x0 and y1 > y0) then
		if stitched then return -w, -h, 2 * w, 2 * h end
		return 0, 0, w, h
	end
	if not stitched then -- Blizzard's canvas is the map: nothing to draw past it
		x0, y0, x1, y1 = math.max(0, x0), math.max(0, y0), math.min(w, x1), math.min(h, y1)
	end
	return x0, y0, x1, y1
end

local function HideRoute()
	RouteHide(mapRoute)
end

local function UpdateRoute()
	if not MapShown() then HideRoute() return end
	local child = Canvas()
	local shown = ShownMapID()
	if not (child and shown) then HideRoute() return end
	local rm, rx, ry, dm, dx, dy = RouteEnds()
	if not rm then HideRoute() return end
	local stitched = Stitched()
	local ax, ay, bx, by
	if stitched then
		ax, ay = OpenMapPos(rm, rx, ry, shown)
		bx, by = OpenMapPos(dm, dx, dy, shown)
	else
		ax, ay = MapXY(rm, rx, ry, shown)
		bx, by = MapXY(dm, dx, dy, shown)
	end
	if not (ax and bx) then HideRoute() return end
	local w, h, s = CanvasMetrics(child)
	if not w then HideRoute() return end
	if not mapRoute or mapRoute.host ~= child then
		RouteHide(mapRoute)
		mapRoute = NewRoute(child)
	end
	-- below the pins
	local level = MapMod.PinLevel(child, stitched) - 3
	if mapRoute.level ~= level then
		mapRoute.level = level
		mapRoute.holder:SetFrameLevel(math.max(0, level))
		mapRoute.flow:SetFrameLevel(math.max(0, level + 1))
	end
	local x0, y0, x1, y1 = ViewRect(child, w, h, stitched)
	RouteDraw(mapRoute, ax * w, ay * h, bx * w, by * h, 1 / s, { x0, y0, x1, y1 })
end

-- the same line on any frame (Home's mini map): fractions of the frame, from its top-left
local panels = setmetatable({}, { __mode = "k" })

local function Frac(p)
	if type(p) ~= "table" then return nil end
	local x, y = W.Num(p.x or p[1]), W.Num(p.y or p[2])
	if x and y then return x, y end
	return nil
end

function M.HideRouteOnPanel(frame)
	if frame ~= nil then RouteHide(panels[frame]) end
end

function M.RouteOnPanel(frame, fromXY, toXY, opts)
	if type(frame) ~= "table" or type(frame.CreateTexture) ~= "function" then return nil end
	local r = panels[frame]
	local ax, ay = Frac(fromXY)
	local bx, by = Frac(toXY)
	local okw, w = call(frame, "GetWidth")
	local okh, h = call(frame, "GetHeight")
	w, h = okw and W.Num(w), okh and W.Num(h)
	if not (ax and bx and w and h and w > 0 and h > 0) then
		RouteHide(r)
		return r and r.handle or nil
	end
	if not r then
		r = NewRoute(frame)
		panels[frame] = r
		r.handle = { Hide = function() RouteHide(r) end, frame = r.holder }
	end
	opts = type(opts) == "table" and opts or {}
	local ok, base = call(frame, "GetFrameLevel")
	base = ok and W.Num(base) or 1
	local level = math.min(9000, base + (W.Num(opts.level) or 1))
	if r.level ~= level then
		r.level = level
		r.holder:SetFrameLevel(level)
		r.flow:SetFrameLevel(level + 1)
	end
	RouteDraw(r, ax * w, ay * h, bx * w, by * h, 1, { 0, 0, w, h },
		{ dot = W.Num(opts.dot), gap = W.Num(opts.gap), alpha = W.Num(opts.alpha) })
	return r.handle
end

-- internals other modules use (bound at load by later modules, or called late)
Mod.HideRoute = HideRoute
Mod.UpdateRoute = UpdateRoute
