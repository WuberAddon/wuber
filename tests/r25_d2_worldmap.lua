-- BRIEF25 D2 (group D follow-up): the crop holds where you stand (even outside every flight master), the rider
-- dot stays inside its continent's box, a price tag never covers a pin icon, the You pin or the rider dot.
-- Loaded by tests/run.lua with its helper table.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function setup(spot, faction)
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = spot or "Orgrimmar", faction = faction })
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

local function inBox(Mod, cont, x, y)
	local bx, by, bw, bh = Mod.Box(cont)
	return bx and x >= bx - 1e-6 and x <= bx + bw + 1e-6 and y >= by - 1e-6 and y <= by + bh + 1e-6
end

test("r25 d2: the dot is inside its box at Stormwind, and the crop is wider than 5%", function()
	local w, r, W, Mod, holder = setup("Stormwind", "Alliance")
	Mod.Build(holder)
	Mod.Show("world")
	local wm = Mod.cache.maps[holder]
	ok(Mod.WM.CROP.yards >= 200, "crop margin past the land (round 26: yards, was 8% of the node box)")
	local cont = W.WorldPos(W.MyPosition())
	local x, y = Mod.Project(W.WorldPos(W.MyPosition()))
	ok(x and inBox(Mod, cont, x, y), "the rider's spot is inside its box")
	ok(wm.me:IsShown(), "the dot shows")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	clean(w)
end)

test("r25 d2: a spot outside every flight master is folded into the crop (re-laid out) and inside its box", function()
	local w, r, W, Mod, holder = setup("Stormwind", "Alliance")
	Mod.Build(holder)
	Mod.Show("world")
	local wm = Mod.cache.maps[holder]
	local cont, wx, wy = W.WorldPos(W.MyPosition())
	local L = Mod.cache.views[cont]
	-- the nodes' own window (before any extra), from the nodes
	local nu0, nu1, nv0, nv1
	for _, m in pairs(W.TAXI.nodes) do
		if m[2] == cont then
			local u, v = L.uv(m[3], m[4])
			nu0, nu1 = math.min(nu0 or u, u), math.max(nu1 or u, u)
			nv0, nv1 = math.min(nv0 or v, v), math.max(nv1 or v, v)
		end
	end
	local found
	for _, k in ipairs({ 200, 600, 2000, 6000 }) do
		for _, d in ipairs({ { k, 0 }, { -k, 0 }, { 0, k }, { 0, -k } }) do
			local u, v = L.uv(wx + d[1], wy + d[2])
			if u and v and not found and (u < nu0 or u > nu1 or v < nv0 or v > nv1) and u > 0.01 and u < 0.99 and v > 0.01 and v < 0.99 then
				found = { wx + d[1], wy + d[2], u, v }
			end
		end
	end
	ok(found, "found a spot outside the flight masters")
	local oldPos = W.WorldPos
	W.WorldPos = function(...)
		if select("#", ...) == 0 or ... == nil then return cont, found[1], found[2] end
		return oldPos(...)
	end
	W.MyPosition = function() return nil end
	Mod.Refresh()
	local V = Mod.cache.views[cont]
	ok(found[3] >= V.u0 - 1e-9 and found[3] <= V.u1 + 1e-9 and found[4] >= V.v0 - 1e-9 and found[4] <= V.v1 + 1e-9, "the crop holds the spot")
	local x, y = Mod.Project(cont, found[1], found[2])
	ok(x and inBox(Mod, cont, x, y), "the spot is inside its box")
	local cx = (wm.me:GetLeft() + wm.me:GetRight()) / 2 - wm.view:GetLeft()
	local cy = wm.view:GetTop() - (wm.me:GetTop() + wm.me:GetBottom()) / 2
	ok(wm.me:IsShown() and inBox(Mod, cont, cx, cy), "the dot is inside its box")
	W.WorldPos = oldPos
	clean(w)
end)

test("r25 d2: a price tag never overlaps a neighbouring pin icon, the You pin or the rider dot", function()
	local w, r, W, Mod, holder = setup("Orgrimmar", "Horde")	local t0 = r.env.GetTime()
	local places = { "Orgrimmar", "Razor Hill", "Crossroads", "Ratchet", "Gadgetzan", "Undercity", "Tarren Mill" }
	for i, p in ipairs(places) do
		local key = "drv " .. i
		-- (round 26) the cheapest (tagged) far from the You pin: at one scale the harness's flat fake Kalimdor has no
		-- room for a tag next to Orgrimmar's pins
		W.drivers[key] = { name = "Drv" .. i, key = key, short = "Drv" .. i, dest = p, price = 13000 - i * 1000, state = "open",
			team = 3, service = "Rides", heard = t0, mapID = 1454, x = 0.5, y = 0.5 }
	end
	W.Bounty.Demand = function() return { { place = "Ratchet", riders = 2 } } end
	W.DriverBeacon = function() return { dest = "Orgrimmar", price = 4000, destShown = "Orgrimmar" } end
	Mod.Build(holder)
	Mod.Show("world")
	local wm = Mod.cache.maps[holder]
	local function R(f) return { f:GetLeft(), f:GetBottom(), f:GetRight(), f:GetTop() } end
	local function over(a, b) return a[1] < b[3] - 0.01 and b[1] < a[3] - 0.01 and a[2] < b[4] - 0.01 and b[2] < a[4] - 0.01 end
	local tags, others = {}, {}
	for _, p in ipairs(wm.pins) do
		if p:IsShown() then
			others[#others + 1] = { R(p.icon), "pin " .. tostring(p.key), p }
			if p.tag and p.tag:IsShown() then tags[#tags + 1] = p end
		end
	end
	if wm.ownPin and wm.ownPin:IsShown() then
		others[#others + 1] = { R(wm.ownPin.icon), "You pin" }
		others[#others + 1] = { R(wm.ownPin.tag), "You tag" }
	end
	if wm.me:IsShown() then others[#others + 1] = { R(wm.me.dot), "rider dot" } end
	for i = 1, wm.coinCount or 0 do
		if wm.coins[i]:IsShown() then others[#others + 1] = { R(wm.coins[i]), "coin " .. i } end
	end
	ok(#tags >= 1, "some tags: " .. #tags)
	ok(wm.ownPin and wm.ownPin:IsShown(), "the You pin shows")
	for _, p in ipairs(tags) do
		local tr = R(p.tag)
		for _, o in ipairs(others) do
			if o[3] ~= p then
				ok(not over(tr, o[1]), tostring(p.key) .. "'s tag clear of " .. o[2])
			end
		end
	end
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	clean(w)
end)

test("e1-14: the You tag avoids the continent label when the You pin sits near it", function()
	local w, r, W, Mod, holder = setup("Orgrimmar", "Horde")
	W.DriverBeacon = function() return { dest = "Booty Bay", price = 4000, destShown = "Booty Bay" } end
	Mod.Build(holder)
	Mod.Show("world")
	local wm = Mod.cache.maps[holder]
	local function R(f) return { f:GetLeft(), f:GetBottom(), f:GetRight(), f:GetTop() } end
	local function over(a, b) return a[1] < b[3] - 0.01 and b[1] < a[3] - 0.01 and a[2] < b[4] - 0.01 and b[2] < a[4] - 0.01 end
	ok(wm.ownPin and wm.ownPin:IsShown(), "the You pin shows")
	local tr = R(wm.ownPin.tag)
	for cont, box in pairs(wm.boxes) do
		if box.label and box.label:IsShown() then
			ok(not over(tr, R(box.label)), "You tag clear of continent label " .. tostring(cont))
		end
	end
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	clean(w)
end)
