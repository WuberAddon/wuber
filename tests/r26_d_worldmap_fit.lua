-- Round 26, group D (item 3): the world view's fit and scale. Each continent is cropped to its whole land
-- (WM.LAND, the coastline, plus a fixed margin) and both share one scale (pixels per yard), centred in WM.AREA.
-- The fake world of tests/harness.lua gives both continents the same square, which hid both faults, so here
-- map 1414 gets the author's saved Kalimdor calibration and 1415 a real Eastern Kingdoms one (taller than wide).
-- Loaded by tests/run.lua with its helper table.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- world = inverse of u = a*wx + b*wy + c, v = d*wx + e*wy + f
local function affine(a, b, c, d, e, f) return { a = a, b = b, c = c, d = d, e = e, f = f } end
local TESTCHAR_K = affine(2.99242415228617e-11, -4.108457110000532e-05, 0.4506986794205422,
	-4.108459183397439e-05, 1.780563177248259e-10, 0.5123252224477992)
-- the Eastern Kingdoms map: 40741 x 27150 yards, its top-left at x 11176, y 18172 (u along -y, v along -x)
local EK = affine(0, -1 / 40741.18, 18171.97 / 40741.18, -1 / 27149.69, 0, 11176.34 / 27149.69)
-- a Kalimdor map with the art's own aspect (1002 x 668 at one scale both ways)
local K_ISO = affine(0, -1 / 36799.81, 17066.6 / 36799.81, -1 / 24533.2, 0, 12133.3 / 24533.2)

local function toUV(m, wx, wy) return m.a * wx + m.b * wy + m.c, m.d * wx + m.e * wy + m.f end
local function toWorld(m, u, v)
	local det = m.a * m.e - m.b * m.d
	local du, dv = u - m.c, v - m.f
	return (m.e * du - m.b * dv) / det, (m.a * dv - m.d * du) / det
end

-- where you stand: Orgrimmar (Kalimdor), Stormwind (the Eastern Kingdoms), or nowhere (an instance)
local SPOTS = { K = { 1, 1677, -4315 }, E = { 0, -8913, 554 }, none = false }

local function setup(how, kal, spot)
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Orgrimmar" })
	T.settle(w)
	local W = r.W
	local Mod = W.Mod("UI.Rider.WorldMap")
	local maps = { [1414] = { 1, kal }, [1415] = { 0, EK } }
	local CM = r.env.C_Map
	local orig = CM.GetWorldPosFromMapPos
	CM.GetWorldPosFromMapPos = function(id, pos)
		local m = maps[id]
		if not m then return orig(id, pos) end
		if how == "cal" or how == "fallback" then return nil end
		local wx, wy = toWorld(m[2], pos.x, pos.y)
		return m[1], r.env.CreateVector2D(wx, wy)
	end
	if how == "cal" then
		W.db.mapCal = {}
		for cont, m in pairs({ [1] = kal, [0] = EK }) do
			local pts = {}
			for id, n in pairs(W.TAXI.nodes) do if n[2] == cont then pts[id] = { toUV(m, n[3], n[4]) } end end
			W.db.mapCal[cont] = { a = m.a, b = m.b, c = m.c, d = m.d, e = m.e, f = m.f, n = 20, at = 1, pts = pts }
		end
	elseif how == "legacy" then
		CM.GetMapArtLayers = nil
	elseif how == "fallback" then
		CM.GetMapArtLayers = nil
		Mod.WM.LEGACY = { [1] = "Interface\\AddOns\\Wuber\\Media\\nope", [0] = "Interface\\AddOns\\Wuber\\Media\\nope" }
	end
	local here = SPOTS[spot]
	local worldPos = W.WorldPos
	W.MyPosition = function() return "here" end
	W.WorldPos = function(a, ...)
		if a == "here" then if here then return here[1], here[2], here[3] end return nil end
		return worldPos(a, ...)
	end
	Mod.Reset()
	for k in pairs(Mod.cache.maps) do Mod.cache.maps[k] = nil end
	Mod.cache.last = nil
	W.UI.Fold.IsUnfolded = function() return true end
	local holder = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	holder:SetSize(360, 544)
	holder:SetPoint("TOPLEFT", r.env.UIParent, "TOPLEFT", 400, -100)
	Mod.Build(holder)
	Mod.Show("world")
	return w, r, W, Mod
end

local function clean(w)
	for path in pairs(w.missingFiles) do
		if path:match("Media\\\\dash$") or path:match("nope") then w.missingFiles[path] = nil end
	end
	T.clean(w)
end

-- pane pixels per 1000 yards along world x and along world y, at a continent's middle
local function perYards(Mod, cont, wx, wy)
	local x0, y0 = Mod.Project(cont, wx, wy)
	local x1, y1 = Mod.Project(cont, wx + 1000, wy)
	local x2, y2 = Mod.Project(cont, wx, wy + 1000)
	local dx = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
	local dy = math.sqrt((x2 - x0) ^ 2 + (y2 - y0) ^ 2)
	return dx, dy, math.sqrt(dx * dy)
end

local function within(a, b, rel) return math.abs(a - b) <= rel * math.max(math.abs(a), math.abs(b)) end

local MARGIN = 6
local HOWS = { "corners", "cal", "legacy", "fallback" }

local function check(how, kal, spot, iso)
	local w, r, W, Mod = setup(how, kal, spot)
	local WM, A = Mod.WM, Mod.WM.AREA
	local tag = how .. "/" .. spot .. (iso and "/iso" or "")
	eq(Mod.cache.focus, SPOTS[spot] and SPOTS[spot][1] or nil, tag .. ": the focus")
	local want = { corners = { "cmap", "corners" }, cal = { "cmap", "cal" }, legacy = { "legacy", "corners" }, fallback = { "fallback", "bounds" } }
	eq(Mod.Probe(), want[how][1], tag .. ": the art")
	eq(Mod.cache.views[1].how, want[how][2], tag .. ": the coordinates")
	local B = {}
	for _, cont in ipairs({ 1, 0 }) do
		local bx, by, bw, bh = Mod.Box(cont)
		ok(bx, tag .. ": box " .. cont)
		B[cont] = { bx, by, bw, bh }
		ok(bx >= A.x + MARGIN - 1e-6 and by >= A.y + MARGIN - 1e-6 and bx + bw <= A.x + A.w - MARGIN + 1e-6
			and by + bh <= A.y + A.h - MARGIN + 1e-6,
			("%s: %s inside the area with %d px to spare: %.1f %.1f %.1f %.1f"):format(tag, WM.BOX[cont].name, MARGIN, bx, by, bw, bh))
		-- every flight master and every corner of the land inside its box
		local L = Mod.cache.views[cont]
		local bad = {}
		local function inside(name, wx, wy)
			local x, y = Mod.Project(cont, wx, wy)
			if not (x and x >= bx - 1e-6 and x <= bx + bw + 1e-6 and y >= by - 1e-6 and y <= by + bh + 1e-6) then bad[#bad + 1] = name end
		end
		for _, n in pairs(W.TAXI.nodes) do if n[2] == cont then inside(n[1], n[3], n[4]) end end
		local land = WM.LAND[cont]
		ok(land, tag .. ": the land of " .. WM.BOX[cont].name)
		for _, c in ipairs({ { land[1], land[2] }, { land[1], land[4] }, { land[3], land[2] }, { land[3], land[4] } }) do
			-- (a corner past the art's own edge is kept to the art)
			local u, v = L.uv(c[1], c[2])
			if not L.art or (u >= 0 and u <= 1 and v >= 0 and v <= 1) then inside(("land corner %d,%d"):format(c[1], c[2]), c[1], c[2]) end
		end
		eq(#bad, 0, tag .. ": " .. WM.BOX[cont].name .. " cuts " .. table.concat(bad, ", "))
	end
	ok(B[1][1] + B[1][3] + WM.GAP <= B[0][1] + 1e-6, tag .. ": Kalimdor left of the Eastern Kingdoms, the cut between")
	ok(B[1][3] + WM.GAP + B[0][3] >= A.w - 2 * MARGIN - 1 or math.max(B[1][4], B[0][4]) >= A.h - 2 * MARGIN - 1, tag .. ": fills one way")
	-- one scale: the same pixels per yard on both continents
	local kx, ky, kg = perYards(Mod, 1, 1677, -4315)
	local ex, ey, eg = perYards(Mod, 0, -8913, 554)
	ok(within(kg, eg, 0.01), ("%s: pixels per 1000 yards %.3f (Kalimdor) and %.3f (the Eastern Kingdoms)"):format(tag, kg, eg))
	if iso then
		ok(within(kx, ex, 0.01) and within(ky, ey, 0.01), ("%s: both ways: %.3f %.3f / %.3f %.3f"):format(tag, kx, ky, ex, ey))
	end
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	clean(w)
end

test("r26 d: world view: each continent whole, inside the area, at one scale (the author's Kalimdor calibration)", function()
	for _, how in ipairs(HOWS) do
		for _, spot in ipairs({ "K", "E", "none" }) do check(how, TESTCHAR_K, spot, how == "fallback") end
	end
end)

test("r26 d: world view: art at one scale both ways gives the same pixels per yard east-west and north-south", function()
	for _, how in ipairs(HOWS) do
		for _, spot in ipairs({ "K", "E", "none" }) do check(how, K_ISO, spot, true) end
	end
end)

test("r26 d: world view: Kalimdor's east coast past Everlook is inside its box", function()
	local w, r, W, Mod = setup("corners", TESTCHAR_K, "K")
	local bx, by, bw, bh = Mod.Box(1)
	local L = Mod.cache.views[1]
	-- Everlook's flight master and the Azshara coast east of it
	local u = L.uv(6800, -4610)
	ok(u > 0.6 and u < 0.7, "Everlook's u " .. u)
	ok(L.u1 >= u + 0.1, ("the crop runs on past Everlook: %.3f > %.3f"):format(L.u1, u))
	ok(bx + bw <= Mod.WM.AREA.x + Mod.WM.AREA.w - MARGIN + 1e-6, "Kalimdor's right edge inside the pane")
	-- and the focus no longer enlarges your continent: the pair is the same with you nowhere
	local w2, r2, W2, Mod2 = setup("corners", TESTCHAR_K, "none")
	local _, _, bw2, bh2 = Mod2.Box(1)
	ok(math.abs(bw - bw2) < 1e-6 and math.abs(bh - bh2) < 1e-6, "the same box with and without the focus")
	clean(w2)
	clean(w)
end)
