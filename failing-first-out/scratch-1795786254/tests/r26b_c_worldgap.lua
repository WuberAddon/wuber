-- Round 26b, group C: no gap between the two continent pictures in the World view (WM.GAP = 0, the boxes touch),
-- and the layout checker's new "gap between the continents" rule. Loaded by tests/run.lua with its helper table.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local E = assert(loadfile(T.dir .. "/layout/engine.lua"))(H)

local function mod()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar", screenW = 1365, screenH = 768 })
	return r.W.Mod("UI.Rider.WorldMap")
end

local function crops(kw, kh, ew, eh)
	local function L(cont, w, h) return { cont = cont, yw = w, aspect = w / h, u0 = 0, u1 = 1, v0 = 0, v1 = 1, aw = 1, ah = 1 } end
	return { [1] = L(1, kw, kh), [0] = L(0, ew, eh) }
end

test("r26b c: world view: the two continent boxes touch (no gap) at several pane sizes, inside, at one scale", function()
	local Mod = mod()
	local WM = Mod.WM
	eq(WM.GAP, 0, "no gap constant")
	local keep = {}
	for k, v in pairs(WM.AREA) do keep[k] = v end
	for _, a in ipairs({ { 6, 44, 348, 470 }, { 6, 44, 300, 400 }, { 4, 30, 520, 360 }, { 6, 44, 250, 470 }, { 6, 44, 700, 500 } }) do
		WM.AREA.x, WM.AREA.y, WM.AREA.w, WM.AREA.h = a[1], a[2], a[3], a[4]
		local out = crops(36800, 24500, 27100, 40700)
		Mod.arrange(out, 1)
		local k, e = out[1], out[0]
		local gap = e.x - (k.x + k.w)
		ok(math.abs(gap) <= 1, ("gap %.2f at area %dx%d"):format(gap, a[3], a[4]))
		for _, L in pairs(out) do
			ok(L.x >= a[1] + WM.CROP.fit - 1e-6 and L.x + L.w <= a[1] + a[3] - WM.CROP.fit + 1e-6, "inside across")
			ok(L.y >= a[2] + WM.CROP.fit - 1e-6 and L.y + L.h <= a[2] + a[4] - WM.CROP.fit + 1e-6, "inside down")
		end
		ok(math.abs(k.w / k.bw - e.w / e.bw) < 1e-9, "one scale")
		-- centred as a pair
		local left, right = k.x - a[1], a[1] + a[3] - (e.x + e.w)
		ok(math.abs(left - right) < 1e-6, "pair centred")
	end
	for k, v in pairs(keep) do WM.AREA[k] = v end
end)

test("r26b c: layout rule: a gap or an overlap between the continents is reported, touching passes", function()
	local function fake(kx, ex)
		return { Box = function(c) if c == 1 then return kx, 60, 160, 400 end return ex, 60, 160, 400 end,
			Project = function(c, wx, wy) return (c == 1 and kx or ex) + wx * 0.01, 60 + wy * 0.01 end }
	end
	local V = { w = 360, h = 544 }
	local function gaps(o) local n = 0 for _, h in ipairs(o) do if (h.key == "world gap") then n = n + 1 end end return n end
	eq(gaps(E.worldRule(fake(10, 170), V)), 0, "touching")
	eq(gaps(E.worldRule(fake(10, 170.8), V)), 0, "within 1 px")
	eq(gaps(E.worldRule(fake(10, 178), V)), 1, "8 px gap")
	eq(gaps(E.worldRule(fake(10, 160), V)), 1, "overlap")
end)
