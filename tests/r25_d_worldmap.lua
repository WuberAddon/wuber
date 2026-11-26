-- BRIEF25 M1 (group D): a clearer world map. Each continent's art is cropped to its land, the two crops sit
-- WM.GAP apart, Project stays exact (the same land spot relative to the crop, the art under it), the continent
-- you're on gets the focus, bigger pins, and price tags that never overlap a pin, a tag or a continent's name.
-- Loaded by tests/run.lua with its helper table.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function setup(opts)
	opts = opts or {}
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = opts.spot or "Orgrimmar", faction = opts.faction })
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
	return w, r, W, Mod, holder
end

local function clean(w)
	for path in pairs(w.missingFiles) do
		if path:match("Media\\dash$") or path:match("nope") then w.missingFiles[path] = nil end
	end
	T.clean(w)
end

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

-- every node of both continents lands inside its crop, at the same art spot the projection says
local function checkExact(W, Mod, wm, what)
	local V = Mod.cache.views
	local bad, n = {}, 0
	for _, m in pairs(W.TAXI.nodes) do
		local L = V[m[2]]
		if L then
			local x, y = Mod.Project(m[2], m[3], m[4])
			local bx, by, bw, bh = Mod.Box(m[2])
			local u, v = L.uv(m[3], m[4])
			n = n + 1
			if not (x and x >= bx - 1e-6 and x <= bx + bw + 1e-6 and y >= by - 1e-6 and y <= by + bh + 1e-6) then
				bad[#bad + 1] = m[1] .. " outside"
			end
			-- relative to the crop: the same u, v as before the crop
			local ru = L.u0 + (x - bx) / bw * (L.u1 - L.u0)
			local rv = L.v0 + (y - by) / bh * (L.v1 - L.v0)
			if not (near(ru, u) and near(rv, v)) then bad[#bad + 1] = m[1] .. " moved on the land" end
			-- the art under it: tile 1's corner plus u * layer width at the tiles' scale
			local box, art = wm.boxes[m[2]], L.art
			if art then
				local t = box.tiles[1]
				local k = bw / ((L.u1 - L.u0) * art.lw)
				local sx = wm.view:GetLeft() + x
				local sy = wm.view:GetTop() - y
				if not (near((sx - t:GetLeft()) / k, u * art.lw, 1e-3) and near((t:GetTop() - sy) / k, v * art.lh, 1e-3)) then
					bad[#bad + 1] = m[1] .. " off its art"
				end
				if not near(bh / ((L.v1 - L.v0) * art.lh), k, 1e-6) then bad[#bad + 1] = "box " .. m[2] .. " stretched" end
			end
		end
	end
	ok(n > 50, what .. ": nodes checked " .. n)
	eq(#bad, 0, what .. ": " .. table.concat(bad, ", ", 1, math.min(#bad, 8)))
end

test("r25 d: M1 - each art source: the crop holds its land, Project lands on the same spot, the art under it", function()
	local w, r, W, Mod, holder = setup()
	Mod.Build(holder)
	Mod.Show("world")
	local wm = Mod.cache.maps[holder]
	eq(Mod.Probe(), "cmap")
	checkExact(W, Mod, wm, "C_Map art")
	-- legacy tiles
	local CM = r.env.C_Map
	local layers = CM.GetMapArtLayers
	CM.GetMapArtLayers = nil
	Mod.Reset()
	Mod.Refresh()
	eq(Mod.Probe(), "legacy")
	checkExact(W, Mod, wm, "legacy tiles")
	-- the fallback
	local legacy = Mod.WM.LEGACY
	Mod.WM.LEGACY = { [1] = "Interface\\AddOns\\Wuber\\Media\\nope", [0] = "Interface\\AddOns\\Wuber\\Media\\nope" }
	Mod.Reset()
	Mod.Refresh()
	eq(Mod.Probe(), "fallback")
	checkExact(W, Mod, wm, "fallback")
	Mod.WM.LEGACY = legacy
	CM.GetMapArtLayers = layers
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	clean(w)
end)

test("r25 d: M1 - the sea is cut out: crops are the land's own shape, pushed WM.GAP apart, filling the pane", function()
	local w, r, W, Mod, holder = setup()
	Mod.Build(holder)
	Mod.Show("world")
	local WM, V = Mod.WM, Mod.cache.views
	local kx, ky, kw, kh = Mod.Box(1)
	local ex, ey, ew, eh = Mod.Box(0)
	ok(kx and ex, "both boxes")
	ok(near(ex - (kx + kw), WM.GAP, 1e-6), "the cut between them: " .. (ex - (kx + kw)))
	ok(kx >= WM.AREA.x - 1e-6 and ex + ew <= WM.AREA.x + WM.AREA.w + 1e-6, "inside the area, side to side")
	for _, b in ipairs({ { ky, kh }, { ey, eh } }) do
		ok(b[1] >= WM.AREA.y - 1e-6 and b[1] + b[2] <= WM.AREA.y + WM.AREA.h + 1e-6, "inside the area, top to bottom")
	end
	-- (round 26) less WM.CROP.fit on each side
	local fit = 2 * WM.CROP.fit
	ok(kw + WM.GAP + ew >= WM.AREA.w - fit - 1 or math.max(kh, eh) >= WM.AREA.h - fit - 1, "the land fills the pane one way")
	-- (round 26) the window holds the nodes and the whole land (WM.LAND) plus WM.CROP.yards, kept to the art:
	-- no sea grown on to fit a fixed box
	for cont, L in pairs(V) do
		local u0, u1, v0, v1
		for _, m in pairs(W.TAXI.nodes) do
			if m[2] == cont then
				local u, v = L.uv(m[3], m[4])
				u0, u1 = math.min(u0 or u, u), math.max(u1 or u, u)
				v0, v1 = math.min(v0 or v, v), math.max(v1 or v, v)
			end
		end
		local land = WM.LAND[cont]
		for _, c in ipairs({ { land[1], land[2] }, { land[1], land[4] }, { land[3], land[2] }, { land[3], land[4] } }) do
			local u, v = L.uv(c[1], c[2])
			u0, u1 = math.min(u0, u), math.max(u1, u)
			v0, v1 = math.min(v0, v), math.max(v1, v)
		end
		local yu = WM.CROP.yards / 1000 -- (the fake world: u, v are world / 10000)
		ok(L.u0 >= u0 - yu - 1e-9 and L.u1 <= u1 + yu + 1e-9 and L.v0 >= v0 - yu - 1e-9 and L.v1 <= v1 + yu + 1e-9,
			WM.BOX[cont].name .. ": the crop is the land plus " .. WM.CROP.yards .. " yards")
		ok(L.u0 >= math.min(0, u0) and L.u1 <= math.max(1, u1) and L.v0 >= math.min(0, v0) and L.v1 <= math.max(1, v1), WM.BOX[cont].name .. ": inside the art")
		local bx, by, bw, bh = Mod.Box(cont)
		ok(near(bw / bh, L.aspect, 1e-9), WM.BOX[cont].name .. ": the box has the land's aspect")
		-- the clip frame is where the box says
		local clip = Mod.cache.maps[holder].boxes[cont].clip
		local view = Mod.cache.maps[holder].view
		ok(near(clip:GetLeft() - view:GetLeft(), bx, 1e-6) and near(view:GetTop() - clip:GetTop(), by, 1e-6)
			and near(clip:GetWidth(), bw, 1e-6), WM.BOX[cont].name .. ": its clip frame")
	end
	clean(w)
end)

test("r25 d: M1 - CutEdge: each box's inner edge at the cut, its y range, pointing at the other continent", function()
	local w, r, W, Mod, holder = setup()
	Mod.Build(holder)
	Mod.Show("world")
	local kx, ky, kw, kh = Mod.Box(1)
	local ex, ey, ew, eh = Mod.Box(0)
	local x1, t1, b1, d1 = Mod.CutEdge(1)
	local x0, t0, b0, d0 = Mod.CutEdge(0)
	eq(x1, kx + kw, "Kalimdor's right edge")
	eq(d1, 1, "the Eastern Kingdoms lie to the right")
	eq(t1, ky) eq(b1, ky + kh)
	eq(x0, ex, "the Eastern Kingdoms' left edge")
	eq(d0, -1, "Kalimdor lies to the left")
	eq(t0, ey) eq(b0, ey + eh)
	eq(Mod.CutEdge(5), nil, "no such continent")
	eq(Mod.Box(nil), nil)
	-- Project is still callable the same way
	local n = W.TAXI.nodes[23]
	local x, y = Mod.Project(1, n[3], n[4])
	ok(x and y and x < x1 and x > kx, "Orgrimmar is in Kalimdor, left of the cut")
	clean(w)
end)

local function lum(t)
	local r_, g, b = t:GetVertexColor()
	return (r_ or 0) + (g or 0) + (b or 0)
end

test("r25 d: M1 - where you are: your continent is brighter, named in violet, at the same scale as the other", function()
	for _, case in ipairs({ { "Orgrimmar", "Horde", 1, 0 }, { "Stormwind", "Alliance", 0, 1 } }) do
		local w, r, W, Mod, holder = setup({ spot = case[1], faction = case[2] })
		Mod.Build(holder)
		Mod.Show("world")
		local wm, V, WM = Mod.cache.maps[holder], Mod.cache.views, Mod.WM
		local me, other = case[3], case[4]
		eq(Mod.cache.focus, me, case[1] .. ": the focus continent")
		ok(V[me].focus and not V[other].focus, "flagged")
		ok(lum(wm.boxes[me].tiles[1]) > lum(wm.boxes[other].tiles[1]), "your continent's art is brighter")
		local gr, gg, gb = W.Theme.RGB("accent")
		local lr, lg, lb = wm.boxes[me].label:GetTextColor()
		ok(near(lr, gr) and near(lg, gg) and near(lb, gb), "its name in violet (design round 4: gold is for prices)")
		local mr = wm.boxes[other].label:GetTextColor()
		ok(not near(mr, gr), "the other's name muted")
		-- (round 26: no larger share for yours) one scale: the same pixels per yard on both continents
		ok(near(V[me].w / V[me].bw, V[other].w / V[other].bw, 1e-9), "one scale for both")
		checkExact(W, Mod, wm, case[1])
		-- the rider's dot is on your continent's box
		ok(wm.me:IsShown(), "your dot")
		local bx, by, bw, bh = Mod.Box(me)
		local cx = (wm.me:GetLeft() + wm.me:GetRight()) / 2 - wm.view:GetLeft()
		local cy = wm.view:GetTop() - (wm.me:GetTop() + wm.me:GetBottom()) / 2
		local px, py = Mod.Project(W.WorldPos(W.MyPosition()))
		ok(px and near(cx, px, 1e-6) and near(cy, py, 1e-6), "the dot where Project puts you")
		if case[1] == "Orgrimmar" then
			ok(cx >= bx and cx <= bx + bw and cy >= by and cy <= by + bh, ("the dot inside your continent: %.1f, %.1f in %.1f %.1f %.1f %.1f"):format(cx, cy, bx, by, bw, bh))
		end
		clean(w)
	end
end)

test("r25 d: M1 - bigger pins; price tags never overlap a pin, another tag or a continent's name, and stay inside", function()
	local w, r, W, Mod, holder = setup()
	local t0 = r.env.GetTime()
	local places = { "Orgrimmar", "Razor Hill", "Crossroads", "Ratchet", "Gadgetzan", "Undercity", "Tarren Mill" }
	for i, p in ipairs(places) do
		local key = "drv " .. i
		W.drivers[key] = { name = "Drv" .. i, key = key, short = "Drv" .. i, dest = p, price = 5000 + i * 1000, state = "open",
			team = 3, service = "Rides", heard = t0, mapID = 1454, x = 0.5, y = 0.5 }
	end
	W.Bounty.Demand = function() return {} end
	Mod.Build(holder)
	Mod.Show("world")
	local wm = Mod.cache.maps[holder]
	ok(wm.pinCount >= 5, "pins: " .. tostring(wm.pinCount))
	local function R(f) return { f:GetLeft(), f:GetBottom(), f:GetRight(), f:GetTop() } end
	local function over(a, b) return a[1] < b[3] - 0.01 and b[1] < a[3] - 0.01 and a[2] < b[4] - 0.01 and b[2] < a[4] - 0.01 end
	local tags, pins = {}, {}
	for i = 1, wm.pinCount do
		local p = wm.pins[i]
		ok(p:GetWidth() >= 22 and p.icon:GetWidth() >= 22, "a bigger pin")
		pins[#pins + 1] = { r = R(p.icon), p = p }
		if p.tag and p.tag:IsShown() then tags[#tags + 1] = { r = R(p.tag), p = p } end
	end
	ok(#tags >= 1, "some price tags: " .. #tags)
	for i, a in ipairs(tags) do
		ok(a.p.tag:GetHeight() >= 20, "a bigger tag")
		for j, b in ipairs(tags) do
			if i < j then ok(not over(a.r, b.r), "tags " .. i .. " and " .. j .. " apart") end
		end
		for _, q in ipairs(pins) do
			if q.p ~= a.p then
				local pr = { q.r[1] + 2, q.r[2], q.r[3] - 2, q.r[4] }
				ok(not over(a.r, pr), "tag " .. i .. " clear of " .. tostring(q.p.key) .. "'s pin")
			end
		end
		for cont, box in pairs(wm.boxes) do
			local l = box.label
			local lr = { l:GetLeft(), l:GetBottom(), l:GetLeft() + math.min(box.clip:GetWidth() - 8, 120), l:GetTop() }
			ok(not over(a.r, lr), "tag " .. i .. " clear of " .. Mod.WM.BOX[cont].name)
		end
		local inside = false
		for _, box in pairs(wm.boxes) do
			local c = R(box.clip)
			if a.r[1] >= c[1] - 0.5 and a.r[3] <= c[3] + 0.5 then inside = true end
		end
		ok(inside, "tag " .. i .. " inside a continent")
	end
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	clean(w)
end)
