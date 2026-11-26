-- Design round 4, group E3: the fake game's world is the real client's shape (yards, x north, y west; a map's u runs
-- along minus y, its v along minus x; the continent maps' real extents), so the World view draws two tall continents
-- side by side that fill the pane, as the game's own screenshot of 21 Nov shows. Also: the legend's Flight and Boat
-- swatches are the lines as drawn, and the sea arrow's words are measured with the font's own measure.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local S = H.state

local function setup(spot)
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = spot or "Orgrimmar", faction = "Horde" })
	T.settle(w)
	local W = r.W
	local Mod = W.Mod("UI.Rider.WorldMap")
	Mod.Reset()
	for k in pairs(Mod.cache.maps) do Mod.cache.maps[k] = nil end
	Mod.cache.last = nil
	W.UI.Fold.IsUnfolded = function() return true end
	local holder = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	holder:SetSize(360, 544)
	holder:SetPoint("TOPLEFT", r.env.UIParent, "TOPLEFT", 400, -100)
	W.drivers["bob stone"] = { name = T.BOB, key = "bob stone", dest = "Orgrimmar", price = 5000, state = "open", team = 3,
		service = "Rides", heard = r.env.GetTime() }
	W.Bounty.Demand = function() return {} end
	return w, r, W, Mod, holder
end
local function show(Mod, holder)
	Mod.Build(holder)
	Mod.Show("world", { route = { from = "Orgrimmar", to = "Undercity" } })
	return Mod.cache.maps[holder]
end

test("d4 e3: the fake game's continent maps answer as the real client: u along minus world y, v along minus world x, real extents", function()
	local w, r = setup()
	local env = r.env
	local function corner(id, u, v)
		local cont, pos = env.C_Map.GetWorldPosFromMapPos(id, env.CreateVector2D(u, v))
		local x, y = pos:GetXY()
		return cont, x, y
	end
	for _, c in ipairs({ { 1414, 1, 17066.6, 12799.9, 36799.81, 24533.2 }, { 1415, 0, 18171.97, 11176.34, 40741.18, 27149.69 } }) do
		local id, cont, left, top, wide, high = unpack(c)
		local c0, x0, y0 = corner(id, 0, 0)
		local c1, x1, y1 = corner(id, 1, 0)
		local c2, x2, y2 = corner(id, 0, 1)
		eq(c0, cont, "map " .. id .. " is continent " .. cont)
		ok(math.abs(x0 - top) < 0.01 and math.abs(y0 - left) < 0.01, "map " .. id .. ": the top left corner is the north-west one (x " .. tostring(x0) .. ", y " .. tostring(y0) .. ")")
		ok(math.abs(x1 - x0) < 0.01 and math.abs((y0 - y1) - wide) < 0.01, "map " .. id .. ": u runs along minus y only, " .. wide .. " yards (got dx " .. (x1 - x0) .. ", dy " .. (y1 - y0) .. ")")
		ok(math.abs(y2 - y0) < 0.01 and math.abs((x0 - x2) - high) < 0.01, "map " .. id .. ": v runs along minus x only, " .. high .. " yards (got dx " .. (x2 - x0) .. ", dy " .. (y2 - y0) .. ")")
		-- 3:2 in yards, as its art
		local art = env.C_Map.GetMapArtLayers(id)[1]
		ok(math.abs(wide / high - art.layerWidth / art.layerHeight) < 0.01, "map " .. id .. ": the yards have the art's shape")
	end
	T.clean(w)
end)

test("d4 e3: the fake game: every spot stands on its continent's land, map and world positions agree both ways, north is up", function()
	local w, r, W, Mod = setup()
	local env = r.env
	local LAND = Mod.WM.LAND
	for name, s in pairs(H.SPOTS) do
		local cont, wx, wy = H.toWorld(s.mapID, s.x, s.y)
		local l = LAND[cont]
		ok(wx >= l[1] and wx <= l[3] and wy >= l[2] and wy <= l[4], name .. " stands inside its continent's coastline box (x " .. math.floor(wx) .. ", y " .. math.floor(wy) .. ")")
		local u, v = H.fromWorld(cont, wx, wy, s.mapID)
		ok(math.abs(u - s.x) < 1e-6 and math.abs(v - s.y) < 1e-6, name .. ": world -> map gives the spot back")
		eq(H.mapAt(cont, wx, wy), s.mapID, name .. ": the deepest map at its world position is its own")
		local id, pos = env.C_Map.GetMapPosFromWorldPos(cont, env.CreateVector2D(wx, wy), s.mapID)
		ok(id == s.mapID and math.abs(pos.x - s.x) < 1e-6, name .. ": C_Map.GetMapPosFromWorldPos agrees")
	end
	-- north is up: Everlook (Winterspring) is north of Gadgetzan (Tanaris): larger x, and higher on the continent map
	local _, xe = H.toWorld(H.SPOTS.Everlook.mapID, 0.5, 0.5)
	local _, xg = H.toWorld(H.SPOTS.Gadgetzan.mapID, 0.5, 0.5)
	ok(xe > xg + 5000, "Winterspring lies thousands of yards north of Tanaris (world x " .. math.floor(xe) .. " against " .. math.floor(xg) .. ")")
	-- UnitPosition: y first, then x, as the game
	local y, x, _, cont = env.UnitPosition("player")
	local c2, wx, wy = H.toWorld(H.SPOTS.Orgrimmar.mapID, 0.5, 0.5)
	ok(cont == c2 and math.abs(x - wx) < 0.01 and math.abs(y - wy) < 0.01, "UnitPosition gives the same world position, y first")
	-- a zone's rectangle on its continent lies inside 0..1
	local l, rr, t, b = env.C_Map.GetMapRectOnMap(1413, 1414)
	ok(l > 0 and rr < 1 and t > 0 and b < 1 and l < rr and t < b, "the Barrens' rectangle lies inside Kalimdor's map")
	T.clean(w)
end)

test("d4 e3: the World view at the game's shapes: two tall continents side by side that use at least 70% of the pane's height", function()
	for _, spot in ipairs({ "Orgrimmar", "Undercity" }) do
		local w, r, W, Mod, holder = setup(spot)
		local wm = show(Mod, holder)
		local WM = Mod.WM
		eq(Mod.Probe(), "cmap", spot .. ": control: the game's own continent art is in use")
		local kx, ky, kw, kh = Mod.Box(1)
		local ex, ey, ew, eh = Mod.Box(0)
		ok(kx and ex, spot .. ": both continents are drawn")
		if kx and ex then
			ok(kh > kw * 1.4, spot .. ": Kalimdor is tall (" .. math.floor(kw) .. " x " .. math.floor(kh) .. ")")
			ok(eh > ew * 1.4, spot .. ": the Eastern Kingdoms are tall (" .. math.floor(ew) .. " x " .. math.floor(eh) .. ")")
			ok(math.abs(kx + kw - ex) < 0.5, spot .. ": side by side, Kalimdor on the left, touching")
			local top, bottom = math.min(ky, ey), math.max(ky + kh, ey + eh)
			ok((bottom - top) >= 0.7 * WM.AREA.h, spot .. ": together they use at least 70% of the area's height (" .. math.floor(bottom - top) .. " of " .. WM.AREA.h .. ")")
			ok((kw + ew) >= 0.7 * WM.AREA.w, spot .. ": and at least 70% of its width (" .. math.floor(kw + ew) .. " of " .. WM.AREA.w .. ")")
			ok(kx >= WM.AREA.x and ex + ew <= WM.AREA.x + WM.AREA.w + 0.5 and top >= WM.AREA.y and bottom <= WM.AREA.y + WM.AREA.h + 0.5, spot .. ": inside the area")
			-- the same scale on both: pixels per yard from each box's crop (WM.LAND plus the margin)
			local L = WM.LAND
			local sk, se = kh / (L[1][3] - L[1][1] + 2 * WM.CROP.yards), eh / (L[0][3] - L[0][1] + 2 * WM.CROP.yards)
			ok(math.abs(sk - se) / sk < 0.03, spot .. ": one scale on both continents (" .. string.format("%.5f, %.5f", sk, se) .. " px per yard)")
			-- where you stand is drawn on your own continent, and Orgrimmar's flight master north of Gadgetzan's
			local cont, wx, wy = H.toWorld(H.SPOTS[spot].mapID, 0.5, 0.5)
			local px, py = Mod.Project(cont, wx, wy)
			local bx, by, bw, bh = Mod.Box(cont)
			ok(px and px >= bx and px <= bx + bw and py >= by and py <= by + bh, spot .. ": your own place projects inside your continent's box")
			local nodes = W.TAXI.nodes
			local org, gad
			for _, n in pairs(nodes) do
				if n[2] == 1 and type(n[1]) == "string" then
					if n[1]:find("Orgrimmar", 1, true) then org = n elseif n[1]:find("Gadgetzan", 1, true) then gad = n end
				end
			end
			if org and gad then
				local _, oy = Mod.Project(1, org[3], org[4])
				local _, gy = Mod.Project(1, gad[3], gad[4])
				ok(oy and gy and oy < gy - 100, spot .. ": Orgrimmar is drawn well above Gadgetzan (north is up)")
			end
		end
		T.clean(w)
	end
end)

test("d4 e3: the legend's Flight and Boat swatches are the lines as drawn: colour, strength and dash length", function()
	local w, r, W, Mod, holder = setup()
	local wm = show(Mod, holder)
	local WM = Mod.WM
	ok(wm.swatch and wm.swatch.flight and wm.swatch.boat, "the legend has a flight and a crossing swatch")
	local function look(reg)
		local s = S[reg] or {}
		local v = s.vertexAsked or s.vertex or {}
		return string.format("%.2f %.2f %.2f a%.2f", v[1] or -1, v[2] or -1, v[3] or -1, (s.alphaAsked or s.alpha or 1) * (v[4] or 1))
	end
	local seen = {}
	for i = 1, wm.staticLines or 0 do
		local l = wm.lines.list[i]
		local a = (S[l] or {}).alphaAsked
		if a and math.abs(a - WM.BOAT[4]) < 0.001 then seen.boat = seen.boat or l elseif a and math.abs(a - WM.FLIGHT[4]) < 0.001 then seen.flight = seen.flight or l end
	end
	ok(seen.flight and seen.boat, "control: a flight line and a crossing line are drawn")
	if wm.swatch and wm.swatch.flight and wm.swatch.boat and seen.flight and seen.boat then
		eq(look(wm.swatch.flight), look(seen.flight), "the Flight swatch looks like a flight line")
		eq(look(wm.swatch.boat), look(seen.boat), "the crossing swatch looks like a crossing line")
		ok(look(wm.swatch.flight) ~= look(wm.swatch.boat), "the two swatches differ")
		local function period(t) local l, rr = t:GetTexCoord() return (t.wuberLen or t:GetWidth()) / (rr - l) end
		ok(math.abs(period(wm.swatch.flight) - WM.PERIOD) < 0.01, "the Flight swatch has the flight's dash length")
		ok(math.abs(period(wm.swatch.boat) - WM.BOAT_PERIOD) < 0.01, "the crossing swatch has the crossing's dash length")
	end
	local hr = H.rect(wm.view)
	for _, fs in ipairs(wm.legend) do
		local a = H.rect(fs)
		local sw = fs:GetStringWidth()
		ok(a.l + math.min(a.w, sw > 0 and sw or a.w) <= hr.l + hr.w - 4, "the legend word " .. tostring(fs:GetText()) .. " ends inside the pane")
	end
	T.clean(w)
end)

test("d4 e3: the sea arrow's words are measured with the font's own measure (T.MeasureText, caption medium), not only the string's width", function()
	local w, r, W, Mod, holder = setup()
	local Th = W.Theme
	local real = Th.MeasureText
	local asked = {}
	Th.MeasureText = function(text, size, weight, ...)
		if type(text) == "string" and text:find("continues by", 1, true) then asked[#asked + 1] = tostring(size) .. " " .. tostring(weight) end
		return real(text, size, weight, ...)
	end
	local wm = show(Mod, holder)
	Th.MeasureText = real
	ok(wm.seaArrow and wm.seaArrow.label and wm.seaArrow.label:IsShown(), "control: the sea arrow and its words are drawn")
	ok(#asked >= 1, "the words' width was asked of T.MeasureText")
	eq(asked[1], "caption medium", "at the words' own size and weight")
	T.clean(w)
end)
