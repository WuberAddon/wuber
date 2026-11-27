-- Design round 4, group E: maps in the palette. Routes, rings, arrows and continent names are violet (the accent token),
-- gold stays on price tags; the labels are Inter at caption size and never touch each other; the "you are here" dot has
-- flat rings, no blurred glow; the World view uses the pane's width. Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local S = H.state

local function setup(dest, price, spot)
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
	local t0 = r.env.GetTime()
	W.drivers["bob stone"] = { name = T.BOB, key = "bob stone", dest = dest, price = price, state = "open", team = 3,
		service = "Rides", heard = t0 }
	W.Bounty.Demand = function() return {} end
	Mod.Build(holder)
	Mod.Show("world", { route = { from = "Orgrimmar", to = "Undercity" } })
	return w, r, W, Mod, Mod.cache.maps[holder], holder
end

local function gold(c) return c and c[1] > 0.9 and c[2] > 0.7 and c[2] < 0.85 and c[3] < 0.4 end
local function colourOf(reg)
	local s = S[reg]
	if not s then return nil end
	if s.textColor then return s.textColor end
	return s.color or s.vertex
end

-- every region under root that is drawn: { region, path }
local function regions(root, out, under)
	out = out or {}
	under = under or {}
	if root.IsShown and not root:IsShown() then return out end
	local isTag = under.tag or (root.SetTag ~= nil)
	for _, rg in ipairs({ root:GetRegions() }) do
		if rg:IsShown() then out[#out + 1] = { rg = rg, tag = isTag, owner = root } end
	end
	for _, c in ipairs({ root:GetChildren() }) do regions(c, out, { tag = isTag }) end
	return out
end

local function textRect(fs)
	local r = H.rect(fs)
	local sw = fs.GetStringWidth and fs:GetStringWidth() or r.w
	if sw and sw > 0 and sw < r.w then
		if fs.GetJustifyH and fs:GetJustifyH() == "RIGHT" then r.l = r.l + r.w - sw end
		r.w = sw
	end
	return r
end

test("d4 e: the World view draws no gold except on price tags (routes, rings, arrow, names are violet)", function()
	local w, r, W, Mod, wm, holder = setup("Orgrimmar", 123 * 10000 + 45 * 100 + 67)
	local bad = {}
	for _, e in ipairs(regions(holder)) do
		local c = colourOf(e.rg)
		if gold(c) and not e.tag then
			bad[#bad + 1] = (e.rg:GetObjectType()) .. " " .. tostring(e.rg.GetText and e.rg:GetText() or "") .. " (" .. string.format("%.2f %.2f %.2f", c[1], c[2], c[3]) .. ")"
		end
	end
	eq(table.concat(bad, "; "), "", "gold drawn outside a price tag")
	ok(wm.seaArrow and wm.seaArrow.label and wm.seaArrow.label:IsShown(), "control: the sea arrow is drawn")
	local acc = W.Theme.C.accent
	local function isAccent(c) return c and math.abs(c[1] - acc[1]) < 0.01 and math.abs(c[2] - acc[2]) < 0.01 and math.abs(c[3] - acc[3]) < 0.01 end
	ok(isAccent(colourOf(wm.seaArrow.label)), "the arrow's words are the accent violet")
	ok(isAccent(colourOf(wm.seaArrow.line)), "the arrow is the accent violet")
	ok(isAccent(colourOf(wm.focusRing)), "the ring on the booked place is the accent violet")
	local n = 0
	for _, l in ipairs(wm.gold.list) do
		if l:IsShown() then n = n + 1 if not isAccent(colourOf(l)) then ok(false, "a route line is not the accent") break end end
	end
	ok(n > 0, "control: the chosen route is drawn (" .. n .. ")")
	T.clean(w)
end)

test("d4 e: the map's labels are Inter at caption size and no two of them touch", function()
	for _, spot in ipairs({ "Orgrimmar", "Undercity" }) do
		local w, r, W, Mod, wm, holder = setup("Orgrimmar", 123 * 10000 + 45 * 100 + 67, spot)
		local boxes = {}
		local function add(name, fs)
			if fs and fs:IsShown() and (fs:GetText() or "") ~= "" then boxes[#boxes + 1] = { name = name .. " " .. tostring(fs:GetText()), r = textRect(fs), fs = fs } end
		end
		for cont, b in pairs(wm.boxes) do add("continent", b.label) end
		add("sea", wm.seaArrow and wm.seaArrow.label)
		for _, p in ipairs(wm.pins) do if p.tag and H.visible(p.tag) and p.tag.text then add("price", p.tag.text) end end
		for _, fs in ipairs(wm.legend) do add("legend", fs) end
		ok(#boxes >= 4, "control: labels are on the map (" .. #boxes .. ")")
		local Th = W.Theme
		for _, b in ipairs(boxes) do
			if not b.name:find("^legend") then
				local path, size = b.fs:GetFont()
				ok(tostring(path):find("Inter", 1, true), b.name .. " is not in Inter (" .. tostring(path) .. ")")
				eq(size, Th.DrawnSize and Th.DrawnSize("caption") or 11, b.name .. " is not at caption size")
			end
		end
		for i = 1, #boxes do
			for j = i + 1, #boxes do
				local a, b = boxes[i].r, boxes[j].r
				ok(not (a.l < b.l + b.w and b.l < a.l + a.w and a.b < b.b + b.h and b.b < a.b + a.h), spot .. ": " .. boxes[i].name .. " touches " .. boxes[j].name)
			end
		end
		T.clean(w)
	end
end)

test("d4 e: the World view fills the pane's width", function()
	local w, r, W, Mod = setup("Orgrimmar", 50 * 100)
	local x0, x1 = 1e9, -1e9
	for cont in pairs(Mod.WM.BOX) do
		local x, y, bw, bh = Mod.Box(cont)
		ok(x, "control: the continent " .. cont .. " has a box")
		x0, x1 = math.min(x0, x), math.max(x1, x + bw)
	end
	ok(x1 - x0 >= 0.8 * Mod.WM.PANE_W, "the two continents span " .. math.floor(x1 - x0) .. " of " .. Mod.WM.PANE_W)
	T.clean(w)
end)

local function noGlow(root, what)
	local bad = {}
	for _, e in ipairs(regions(root)) do
		local rg = e.rg
		if rg.GetObjectType and rg:GetObjectType() == "Texture" then
			local ok2, p = pcall(rg.GetTextureFilePath, rg)
			local f = ok2 and type(p) == "string" and (p:match("([^\\/]+)$") or p):gsub("%.%w+$", "") or nil
			if f == "glow" or f == "pulse" then bad[#bad + 1] = f end
		end
	end
	eq(table.concat(bad, ","), "", what .. " draws a blurred picture")
end

test("d4 e: the you-are-here dot is a flat dot with flat rings (no glow or blurred pulse) on the World view and on Home", function()
	local w, r, W, Mod, wm = setup("Orgrimmar", 50 * 100)
	wm.me:Show()
	wm.me.pulse:Start()
	w:advance(1)
	ok(wm.me:IsShown(), "control: the dot shows")
	noGlow(wm.me, "the World view's dot")
	local c = r.env.WuberFrame
	local found
	local function walk(f)
		if found then return end
		if f.pulse and f.dot and f.GetWidth and f:GetWidth() <= 14 then found = f return end
		for _, ch in ipairs({ f:GetChildren() }) do walk(ch) end
	end
	walk(c)
	ok(found, "control: Home's dot is found")
	if found then
		found:Show()
		noGlow(found, "Home's dot")
	end
	T.clean(w)
end)
