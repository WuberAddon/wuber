-- Module: UI.Rider.SeaRoute
-- Purpose: routes across the sea on the world map. Splits a route's legs into your side, the crossing (boat or
--   zeppelin) and the other side, and draws the arrow "continues by zeppelin" / "continues by boat" at the cut edge.
-- API: SeaRoute.Split(legs, cont) -> { mine, cross, other, word }; SeaRoute.Arrow(split, edge) -> spec or nil;
--   SeaRoute.Draw(parent, spec, colour, reuse) -> { home, line, head1, head2, label }; SeaRoute.Hide(o)
-- Internals: none
-- Uses: (none)
-- Later: (none)
-- Events: none
-- Standalone: yes
-- Test: tests/r25_e_searoute.lua
-- From: new in Wuber 2.3.3 (round 25, M2)
--
-- A leg is { cont = continent of its start, to = continent of its end, kind = "flight" | "boat" | "zeppelin",
--   pts = { x1, y1, x2, y2, ... } in pane pixels }. The crossing is the first boat or zeppelin leg whose two ends
-- are on different continents. edge is the inner cut edge of your continent: a number (its x) or { x = n }.
local _, W = ...
local Mod = W.Module("UI.Rider.SeaRoute", {})

Mod.GAP = 14 -- least arrow length, px
Mod.HEAD = 6 -- arrow head arm, px

-- Legs before the crossing go to mine (those on cont), the crossing is cross, the rest are other.
function Mod.Split(legs, cont)
	local out = { mine = {}, other = {}, cross = nil, word = nil }
	if type(legs) ~= "table" then return out end
	local crossed = false
	for _, leg in ipairs(legs) do
		if type(leg) == "table" then
			local sea = (leg.kind == "boat" or leg.kind == "zeppelin") and leg.cont ~= nil and leg.to ~= nil and leg.cont ~= leg.to
			if not crossed and sea and (cont == nil or leg.cont == cont) then
				crossed = true
				out.cross = leg
				out.word = leg.kind == "zeppelin" and "zeppelin" or "boat"
			elseif crossed then
				out.other[#out.other + 1] = leg
			else
				out.mine[#out.mine + 1] = leg
			end
		end
	end
	return out
end

local function lastPoint(leg)
	local p = leg and leg.pts
	if type(p) == "table" and #p >= 2 then return p[#p - 1], p[#p] end
end

local function firstPoint(leg)
	local p = leg and leg.pts
	if type(p) == "table" and #p >= 2 then return p[1], p[2] end
end

-- The arrow: from the last point on your side to the cut edge, pointing at the other continent.
function Mod.Arrow(split, edge)
	if type(split) ~= "table" or not split.cross then return nil end
	local ex = type(edge) == "table" and edge.x or edge
	if type(ex) ~= "number" then return nil end
	local x, y
	local m = split.mine
	if m and #m > 0 then x, y = lastPoint(m[#m]) end
	if not x then x, y = firstPoint(split.cross) end
	if not x then return nil end
	local dir = ex >= x and 1 or -1
	local x2 = ex
	if math.abs(x2 - x) < Mod.GAP then x2 = x + dir * Mod.GAP end
	return { x1 = x, y1 = y, x2 = x2, y2 = y, dir = dir, kind = split.word,
		label = "continues by " .. split.word,
		head = { x2 - dir * Mod.HEAD, y - Mod.HEAD / 2, x2, y, x2 - dir * Mod.HEAD, y + Mod.HEAD / 2 } }
end

local function line(parent, x1, y1, x2, y2, c, thick, old, home)
	if not parent.CreateLine then return nil end
	local l = old or (home or parent):CreateLine(nil, "OVERLAY")
	l:Show()
	l:SetStartPoint("TOPLEFT", parent, x1, -y1)
	l:SetEndPoint("TOPLEFT", parent, x2, -y2)
	if l.SetThickness then l:SetThickness(thick) end
	l:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
	return l
end

-- spec.below = true puts the words under the line (UI.Rider.WorldMap does that when they would meet a continent's name).
-- Draw it on parent (no Scale animation: plain lines and a FontString).
-- reuse: an earlier result for the same parent; its pieces are hidden then made again (no new objects).
function Mod.Hide(o)
	if type(o) ~= "table" then return end
	for _, k in ipairs({ "line", "head1", "head2", "label", "home" }) do
		if o[k] and o[k].Hide then o[k]:Hide() end
	end
end

function Mod.Draw(parent, spec, colour, reuse)
	if not (parent and type(spec) == "table") then return nil end
	local c = colour or (W.Theme and W.Theme.C and W.Theme.C.accent) or { 0.66, 0.45, 0.96, 1 } -- the accent violet
	local h = spec.head
	Mod.Hide(reuse)
	-- a plain frame just above the parent's first children (the continent clips, the route and place layers), so the arrow
	-- and its label are never under a map; the pin layer (parent + 3) and its pins stay above it
	local home = reuse and reuse.home
	if not home and CreateFrame then
		home = CreateFrame("Frame", nil, parent)
		home:SetAllPoints(parent)
		if home.SetFrameLevel and parent.GetFrameLevel then home:SetFrameLevel(parent:GetFrameLevel() + 2) end
	end
	local o = { home = home, line = line(parent, spec.x1, spec.y1, spec.x2, spec.y2, c, 2, reuse and reuse.line, home),
		head1 = line(parent, h[1], h[2], h[3], h[4], c, 2, reuse and reuse.head1, home),
		head2 = line(parent, h[5], h[6], h[3], h[4], c, 2, reuse and reuse.head2, home) }
	if home then home:Show() end
	local fs = reuse and reuse.label
	if not fs then
		-- (design round 1) Wuber's own font at the old label's size (10), not the game's serif; inside the phone: no shadow
		local T, host = W.Theme, home or parent
		if type(T) == "table" and type(T.SetFont) == "function" then
			fs = host:CreateFontString(nil, "OVERLAY")
			if not pcall(T.SetFont, fs, "caption", "medium") then fs = nil end
		end
		fs = fs or host:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	end
	fs:Show()
	fs:ClearAllPoints()
	-- spec.below (the caller found the words meeting another label above the line): under the arrow instead
	if spec.labelY then
		fs:SetPoint(spec.dir > 0 and "TOPRIGHT" or "TOPLEFT", parent, "TOPLEFT", spec.x2, -spec.labelY)
	elseif spec.below then
		fs:SetPoint(spec.dir > 0 and "TOPRIGHT" or "TOPLEFT", parent, "TOPLEFT", spec.x2, -spec.y2 - 5)
	else
		fs:SetPoint(spec.dir > 0 and "BOTTOMRIGHT" or "BOTTOMLEFT", parent, "TOPLEFT", spec.x2, -spec.y2 + 3)
	end
	fs:SetText(spec.label)
	fs:SetTextColor(c[1], c[2], c[3], 1)
	o.label = fs
	return o
end
