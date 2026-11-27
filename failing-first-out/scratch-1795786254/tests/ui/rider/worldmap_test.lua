-- Tests of UI.Rider.WorldMap and HomeMap's docking. Loaded by
-- tests/run.lua with its helper table T. The Fold (UI.Fold, agent A) is stubbed here: tests set
-- UI.Fold.IsUnfolded and make a 360 x 544 side-pane holder of their own.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANITA = T.ANITA

-- Media/dash.tga is agent G's (round 8); until it lands, its absence is the only missing file
-- these tests forgive.
local DASH = T.dir .. "/../Wuber/Media/dash.tga"
local function dashMissingOk(w)
	local f = io.open(DASH, "rb")
	if f then f:close() return end
	for path in pairs(w.missingFiles) do
		if path:match("Media\\dash$") then w.missingFiles[path] = nil end
	end
end

local function clean(w)
	dashMissingOk(w)
	T.clean(w)
end

-- a rider, the world map module (caches reset), a holder and the Fold unfolded
local function setup(opts)
	opts = opts or {}
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = opts.spot or "Orgrimmar", faction = opts.faction, prepare = opts.prepare })
	T.settle(w)
	local W = r.W
	local UI = W.UI
	local Mod = W.Mod("UI.Rider.WorldMap")
	Mod.Reset()
	for k in pairs(Mod.cache.maps) do Mod.cache.maps[k] = nil end
	Mod.cache.last = nil
	UI.Fold.IsUnfolded = function() return opts.folded ~= true end
	local holder = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	holder:SetSize(360, 544)
	holder:SetPoint("TOPLEFT", r.env.UIParent, "TOPLEFT", 400, -100)
	return w, r, W, Mod, holder
end

local function mapOf(Mod, holder) return Mod.cache.maps[holder] end

test("ui.rider.worldmap: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("UI.Rider.WorldMap", "tests/ui/rider/worldmap_test.lua", {
		["Mod.Build"] = "function",
		["Mod.Show"] = "function",
		["Mod.Refresh"] = "function",
		["Mod.Probe"] = "function",
		["Mod.Project"] = "function",
	})
	ok(Mod, "W.Mod(\"UI.Rider.WorldMap\")")
	T.clean(w)
end)

test("ui.rider.worldmap: Build is cheap (the Here/World control only); never built while folded; World by default (round 12)", function()
	local w, r, W, Mod, holder = setup({ folded = true })
	local here = r.env.CreateFrame("Frame", nil, holder)
	local made = #r.widgets
	local view = Mod.Build(holder, { here = here })
	ok(view, "the world view frame")
	local wm = mapOf(Mod, holder)
	eq(wm.mode, "world", "World by default (round 12, item 9)")
	ok(here:IsShown(), "Here shows while nothing is drawn (folded)")
	ok(not view:IsShown(), "World hidden")
	-- 26: each part has its own lit pill (3 textures), shown or hidden
	ok(#r.widgets - made < 26, "only the control: " .. (#r.widgets - made))
	Mod.Show("world")
	eq(wm.built, nil, "folded: never built")
	ok(not view:IsShown(), "and not shown")
	eq(Mod.Build(holder), view, "the same map for the same holder")
	-- unfolded: World builds and draws
	W.UI.Fold.IsUnfolded = function() return true end
	Mod.Show("world")
	ok(wm.built, "built when unfolded")
	ok(view:IsShown() and not here:IsShown(), "World shown, Here hidden")
	eq(wm.seg.value, "world", "the control follows")
	Mod.Show("here")
	ok(here:IsShown() and not view:IsShown(), "back to Here")
	-- the control itself
	wm.seg.buttons[2]:Click()
	eq(wm.mode, "world", "tapping World")
	-- (round 9, S15) the dark segmented look: the chosen half violet, never the gold of primary actions
	eq(wm.seg.buttons[2].style, "violet", "World chosen: violet")
	eq(wm.seg.buttons[1].style, "ghost", "Here not chosen: plain")
	wm.seg.buttons[1]:Click()
	eq(wm.seg.buttons[1].style, "violet", "Here chosen: violet")
	for _, b in ipairs(wm.seg.buttons) do ok(b.style ~= "primary", "no gold") end
	clean(w)
end)

test("ui.rider.worldmap: art probe: C_Map art -> tiles; no C_Map art -> legacy tiles; neither -> the fallback, no error", function()
	local w, r, W, Mod, holder = setup()
	Mod.Build(holder)
	Mod.Show("world")
	eq(Mod.Probe(), "cmap", "the fake C_Map has continent art")
	local wm = mapOf(Mod, holder)
	ok(#wm.tiles >= 24, "12 tiles a continent: " .. #wm.tiles)
	local t = wm.boxes[1].tiles[1]
	eq(t:GetTexture(), 1414 * 100 + 1, "Kalimdor's first tile by file id")
	-- no C_Map art: the legacy WorldMap tiles
	local CM = r.env.C_Map
	local layers = CM.GetMapArtLayers
	CM.GetMapArtLayers = nil
	Mod.Reset()
	eq(Mod.Probe(), "legacy")
	Mod.Refresh()
	eq(wm.boxes[0].tiles[1]:GetTexture(), "Interface\\WorldMap\\Azeroth\\Azeroth1", "the Eastern Kingdoms' legacy tile")
	-- legacy tiles that don't load: the fallback (mapbg, routes on the node box)
	Mod.WM.LEGACY = { [1] = "Interface\\AddOns\\Wuber\\Media\\nope", [0] = "Interface\\AddOns\\Wuber\\Media\\nope" }
	Mod.Reset()
	eq(Mod.Probe(), "fallback")
	Mod.Refresh()
	eq(Mod.cache.views[1].how, "bounds", "the node box")
	ok(not wm.boxes[1].tiles[1]:IsShown(), "no tiles")
	ok(wm.boxes[1].bg:IsShown(), "the night backdrop")
	ok(wm.routeCount and wm.routeCount > 20, "routes still drawn: " .. tostring(wm.routeCount))
	for path in pairs(w.missingFiles) do if path:match("nope") then w.missingFiles[path] = nil end end
	CM.GetMapArtLayers = layers
	Mod.WM.LEGACY = { [1] = "Interface\\WorldMap\\Kalimdor\\Kalimdor", [0] = "Interface\\WorldMap\\Azeroth\\Azeroth" }
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	clean(w)
end)

test("ui.rider.worldmap: coordinates: the map's corners first, the flight-master calibration second", function()
	local w, r, W, Mod, holder = setup()
	Mod.Build(holder)
	Mod.Show("world")
	local V = Mod.cache.views
	eq(V[1].how, "corners")
	-- (design round 4, E3) the fake world is the real client's: u along minus world y, v along minus world x, from the
	-- continent map's north-west corner over its real extent (H.WORLD), so a node lands where its world position says
	local n = W.TAXI.nodes[23] -- Orgrimmar, Kalimdor
	local u, v = V[1].uv(n[3], n[4])
	local g = H.WORLD[1].map
	ok(math.abs(u - (g[1] - n[4]) / g[3]) < 1e-9 and math.abs(v - (g[2] - n[3]) / g[4]) < 1e-9, ("corner transform: %.4f, %.4f"):format(u, v))
	local px, py = Mod.Project(1, n[3], n[4])
	-- the box is the cropped land's, where arrange() put it (tests/r25_d_worldmap.lua)
	local bx, by, bw, bh = Mod.Box(1)
	ok(math.abs(px - (bx + (u - V[1].u0) / (V[1].u1 - V[1].u0) * bw)) < 1e-6, "pane x")
	ok(math.abs(py - (by + (v - V[1].v0) / (V[1].v1 - V[1].v0) * bh)) < 1e-6, "pane y")
	-- the crop holds every node of the continent, with the box's aspect
	for _, m in pairs(W.TAXI.nodes) do
		if m[2] == 1 then
			local x, y = Mod.Project(1, m[3], m[4])
			ok(x >= bx and x <= bx + bw and y >= by and y <= by + bh, m[1] .. " inside Kalimdor's box")
		end
	end
	local L = V[1]
	local aspect = ((L.u1 - L.u0) * L.aw) / ((L.v1 - L.v0) * L.ah)
	ok(math.abs(aspect - bw / bh) < 1e-6, "aspect " .. aspect)
	-- no corners: the calibration learned at flight masters (W.db.mapCal)
	r.env.C_Map.GetWorldPosFromMapPos = function() return nil end
	-- (round 9, C11 review: a fit is trusted only with north-south spread among its points, as a real one has)
	W.db.mapCal = { [0] = { a = -1e-5, b = -6e-5, c = 0.5, d = -4e-5, e = 1e-5, f = 0.4, n = 4, at = 1,
		pts = { [11] = { 0.1, 0.1 }, [13] = { 0.2, 0.2 }, [17] = { 0.3, 0.3 }, [21] = { 0.4, 0.4 } } } }
	Mod.Reset()
	Mod.Refresh()
	eq(Mod.cache.views[0].how, "cal", "the Eastern Kingdoms from the calibration")
	local uc = W.TAXI.nodes[11]
	local cu = Mod.cache.views[0].uv(uc[3], uc[4])
	ok(math.abs(cu - (-1e-5 * uc[3] - 6e-5 * uc[4] + 0.5)) < 1e-9, "u from the affine")
	eq(Mod.cache.views[1].how, "bounds", "Kalimdor: neither, so the fallback box")
	clean(w)
end)

local function legsFor(W, s)
	local n = 0
	for key in pairs(W.TAXI_PATHS) do
		local a, b = key:match("^(%d+):(%d+)$")
		local na, nb = W.TAXI.nodes[tonumber(a)], W.TAXI.nodes[tonumber(b)]
		if na[5]:find(s, 1, true) and nb[5]:find(s, 1, true) then n = n + 1 end
	end
	local B = W.TAXI.boats
	for i = 1, #B - 2, 3 do if B[i + 2] == s then n = n + 1 end end
	return n
end

test("ui.rider.worldmap: a Horde player sees no Alliance-only legs (and the reverse); dashes carry their phase; the budget holds", function()
	for _, faction in ipairs({ "Horde", "Alliance" }) do
		local w, r, W, Mod, holder = setup({ faction = faction, spot = faction == "Horde" and "Orgrimmar" or "Stormwind" })
		local s = faction == "Horde" and "H" or "A"
		Mod.Build(holder)
		Mod.Show("world")
		local wm = mapOf(Mod, holder)
		eq(wm.routeCount, legsFor(W, s), faction .. ": this side's legs and crossings")
		ok(wm.hasLines, "Line objects")
		ok(#wm.lines.list + #wm.dots.list + #wm.tiles <= 700, "budget: " .. (#wm.lines.list + #wm.tiles))
		-- dash phase: each segment starts where the last one ended (or a new polyline at 0)
		local cont, fresh = 0, 0
		local prev
		for i = 1, wm.lines.used do
			local l = wm.lines.list[i]
			local u0, u1 = l:GetTexCoord()
			if prev and u0 ~= 0 then
				local want = prev % 1
				ok(math.abs(u0 - want) < 1e-6, ("segment %d starts at %.5f, the last ended at %.5f"):format(i, u0, want))
				cont = cont + 1
			else
				fresh = fresh + 1
			end
			prev = u1
		end
		ok(cont > fresh, ("most segments continue a polyline (%d continue, %d start)"):format(cont, fresh))
		-- node dots: this side's only
		local shown = 0
		for _, b in ipairs(wm.nodes) do if b:IsShown() then shown = shown + 1 end end
		local want = 0
		for _, n in pairs(W.TAXI.nodes) do if n[5]:find(s, 1, true) then want = want + 1 end end
		eq(shown, want, "node dots")
		clean(w)
	end
end)

test("ui.rider.worldmap: without Line objects: dash sprites within the 700-texture budget (spacing grows)", function()
	local w, r, W, Mod, holder = setup()
	local view = Mod.Build(holder, { mode = "here" }) -- (round 12: World is the default; draw it only after the line switch)
	rawset(view, "CreateLine", false)
	Mod.Show("world")
	local wm = mapOf(Mod, holder)
	eq(wm.hasLines, false)
	ok(wm.dots.used > 200, "sprites drawn: " .. wm.dots.used)
	ok(#wm.dots.list + #wm.lines.list + #wm.tiles <= 700, "budget: " .. (#wm.dots.list + #wm.tiles))
	eq(#wm.lines.list, 0, "no lines")
	clean(w)
end)

test("ui.rider.worldmap: all 286 legs (both sides' 143 shapes and every crossing) stay within the 700-texture budget, lines or sprites", function()
	for _, lines in ipairs({ true, false }) do
		local w, r, W, Mod, holder = setup()
		for _, n in pairs(W.TAXI.nodes) do n[5] = "HA" end
		local view = Mod.Build(holder)
		if not lines then rawset(view, "CreateLine", false) end
		Mod.Show("world")
		local wm = mapOf(Mod, holder)
		local shapes = 0
		for _ in pairs(W.TAXI_PATHS) do shapes = shapes + 1 end
		eq(#W.TAXI.legs / 3, 286, "286 legs in the table")
		ok(wm.routeCount >= shapes, ("every shape drawn: %d of %d"):format(wm.routeCount or 0, shapes))
		local used = #wm.lines.list + (wm.lines ~= wm.dots and #wm.dots.list or 0) + #wm.tiles
		ok(used <= 700, (lines and "lines" or "sprites") .. " budget: " .. used)
		clean(w)
	end
end)

test("ui.rider.worldmap: driver pins (merged per place, top three tagged), a pin click opens Confirm; bounty coins; gold route", function()
	local w, r, W, Mod, holder = setup()
	w:addBot(ANITA, { spot = "Gadgetzan" })
	w:addBot("Bea Bright", { spot = "Gadgetzan" })
	w:addBot(T.BOB, { spot = "Ratchet", class = "WARLOCK" })
	w:advance(1)
	w:inject(ANITA, "D~1~Gadgetzan~1446~515~285~5000~Rides~open~1~1~H~2.2.3", "CHANNEL")
	w:inject("Bea Bright", "D~1~Gadgetzan~1446~515~285~6000~Bea's~open~1~1~H~2.2.3", "CHANNEL")
	w:advance(1)
	w:inject(T.BOB, "D~1~Ratchet~1413~627~370~5500~Rides~open~1~1~H~2.2.3", "CHANNEL")
	w:advance(2)
	W.Bounty.Demand = function() return { { place = "Everlook", riders = 3, low = 5000, high = 10000, newest = 30 } } end
	Mod.Build(holder)
	Mod.Show("world", { route = { from = "Orgrimmar", to = "Tarren Mill" } })
	local wm = mapOf(Mod, holder)
	eq(wm.pinCount, 2, "two places: Gadgetzan (2 drivers) and Ratchet")
	local gad
	for i = 1, wm.pinCount do if wm.pins[i].count:GetText() == "2" then gad = wm.pins[i] end end
	ok(gad, "Gadgetzan's pin counts 2")
	ok(gad.tag and gad.tag:IsShown(), "a price tag (top three)")
	eq(wm.coinCount, 1, "one bounty coin")
	eq(wm.coins[1].count:GetText(), "3")
	ok(wm.gold.used > 0, "the gold route drawn")
	local solid, dashed = 0, 0
	for i = 1, wm.gold.used do
		local tex = wm.gold.list[i]:GetTextureFilePath()
		if type(tex) == "string" and tex:match("dash$") then dashed = dashed + 1 else solid = solid + 1 end
	end
	ok(solid > 0, "the flight legs solid gold")
	eq(dashed, 1, "the zeppelin Orgrimmar - Undercity dashed gold")
	-- (design round 4) the continents' names stand on the pane just under their boxes (not under the routes), clear of the Here/World control
	for cont, box in pairs(wm.boxes) do
		eq(box.label:GetParent(), wm.view, "on the pane, outside the clipped box")
		ok(box.label:GetTop() <= box.clip:GetBottom() + 4 and box.label:GetTop() < wm.seg:GetBottom(), Mod.WM.BOX[cont].name .. " under its box, under the control")
	end
	ok(wm.focusRing:IsShown(), "a ring at the destination")
	-- click: Confirm for that driver (not secure)
	local got
	local old = W.UI.Show
	W.UI.Show = function(screen, key) got = { screen, key } end
	gad:Click()
	W.UI.Show = old
	ok(got and got[1] == "confirm" and (got[2] == W.Key(ANITA) or got[2] == W.Key("Bea Bright")), "Confirm for the pin's driver")
	clean(w)
end)

test("ui.rider.worldmap: refresh on DRIVERS (debounced 0.5 s) only while shown; nothing redraws while hidden", function()
	local w, r, W, Mod, holder = setup()
	Mod.Build(holder)
	Mod.Show("world")
	local wm = mapOf(Mod, holder)
	local n = wm.redraws
	W.Fire("DRIVERS")
	W.Fire("DRIVERS")
	w:advance(1)
	eq(wm.redraws, n + 1, "one redraw for two DRIVERS")
	holder:Hide()
	W.Fire("DRIVERS")
	W.Fire("BOUNTY")
	w:advance(1)
	eq(wm.redraws, n + 1, "hidden: none")
	holder:Show()
	eq(wm.redraws, n + 2, "shown again: one redraw (what it missed while hidden)")
	Mod.Show("here")
	W.Fire("DRIVERS")
	w:advance(1)
	eq(wm.redraws, n + 2, "Here: none")
	clean(w)
end)

test("ui.rider.homemap: Dock moves a map panel into a side pane (360 x 512 at y 32) and Undock puts it back exactly", function()
	local w, r, W, Mod, holder = setup()
	local HM = W.Mod("UI.Rider.HomeMap")
	local home = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	home:SetSize(360, 600)
	home:SetPoint("TOPLEFT", r.env.UIParent, "TOPLEFT", 10, -10)
	local m = HM.buildMapPanel(home)
	local function rect(f) return table.concat({ f:GetLeft(), f:GetTop(), f:GetWidth(), f:GetHeight() }, ",") end
	local before, mapH, visH = rect(m), m.mapH, m.visH
	HM.updateMap(m, {})
	local made = #r.widgets
	HM.Dock(m, holder)
	eq(m:GetParent(), holder)
	-- (p242 r3 F) 360 x 500 at y 44 now (the name above says 512 and 32, as the baseline keys it): under the header buttons
	eq(m:GetWidth(), 360) eq(m:GetHeight(), 500)
	eq(m.mapH, 500) eq(m.visH, 500)
	eq(math.floor(holder:GetTop() - m:GetTop() + 0.5), 44, "under the Here/World control and the header buttons")
	HM.updateMap(m, {})
	HM.Dock(m, holder)
	HM.updateMap(m, {})
	eq(#r.widgets, made, "docking creates no frames")
	HM.Undock(m)
	eq(m:GetParent(), home)
	eq(rect(m), before, "back where it was")
	eq(m.mapH, mapH) eq(m.visH, visH)
	eq(m.mapW, nil)
	HM.Undock(m)
	eq(rect(m), before, "idempotent")
	-- the world map's Here is the docked panel
	HM.Dock(m, holder)
	Mod.Build(holder, { here = m })
	Mod.Show("world")
	ok(not m:IsShown(), "World hides Here")
	Mod.Show("here")
	ok(m:IsShown(), "Here shows the docked panel")
	clean(w)
end)

-- Inside A's real Fold: the ride and confirm pages registered the way C's pages do it:
-- build(holder) makes the map, layout(true) docks Home's map panel and shows the world view,
-- layout(false) undocks it.
local function registerPages(r)
	local W = r.W
	local UI, HM, WorldMod = W.UI, W.Mod("UI.Rider.HomeMap"), W.Mod("UI.Rider.WorldMap")
	local seen = { holders = {} }
	local function homeMap() return UI.state.screens.home and UI.state.screens.home.map end
	UI.Fold.Register("ride", {
		build = function(holder)
			seen.holders.ride = holder
			WorldMod.Build(holder, { here = homeMap() })
		end,
		layout = function(on, holder)
			local m = homeMap()
			if on then
				HM.Dock(m, holder)
				WorldMod.Build(holder, { here = m })
				WorldMod.Show("world", { holder = holder })
			else
				HM.Undock(m)
			end
			HM.updateMap(m, UI.Drivers())
		end,
	})
	UI.Fold.Register("confirm", {
		build = function(holder)
			seen.holders.confirm = holder
			WorldMod.Build(holder)
		end,
		layout = function(on, holder)
			if on then
				local d = W.drivers[UI.state.confirmKey or ""]
				local dest = d and d.dest or nil
				WorldMod.Show("world", { holder = holder, route = dest and { to = dest } or false, focus = dest or false })
			end
		end,
	})
	return seen, homeMap
end

test("ui.rider.worldmap: inside the real Fold: ride and confirm unfold with the map drawn and routes shown; folding undocks cleanly", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Orgrimmar" })
	r.wide = true -- (opts in: the harness keeps other tests folded)
	T.settle(w)
	local W = r.W
	local UI, Mod = W.UI, W.Mod("UI.Rider.WorldMap")
	Mod.Reset()
	for k in pairs(Mod.cache.maps) do Mod.cache.maps[k] = nil end
	Mod.cache.last = nil
	W.db.coach = true
	local seen, homeMap = registerPages(r)
	W.drivers["anita lift"] = { name = ANITA, key = "anita lift", dest = "Undercity", price = 5000, state = "open",
		team = 3, service = "Anita's Portals", heard = r.env.GetTime(), mapID = 1454, x = 0.5, y = 0.5 }
	UI.Toggle(true)
	w:advance(3)
	eq(UI.Fold.Page(), "ride", "the ride page")
	ok(UI.Fold.IsUnfolded(), "unfolded")
	eq(r.env.WuberFrame:GetWidth(), 720, "720 wide")
	local holder = seen.holders.ride
	ok(holder, "ride's side pane built")
	local m = homeMap()
	local home = UI.state.screens.home.frame
	eq(m:GetParent(), holder, "Home's map docked in the side pane")
	local wm = Mod.cache.maps[holder]
	ok(wm and wm.built, "the world map built")
	ok(wm.view:IsVisible(), "and visible in the side pane")
	ok(not m:IsShown(), "World hides Here")
	ok(wm.routeCount and wm.routeCount > 20, "routes drawn: " .. tostring(wm.routeCount))
	ok(wm.lines.used > 0, "dashed lines in use")
	eq(wm.pinCount, 1, "Anita's pin (Orgrimmar)")
	local pl = UI.Fold.Pane():GetLeft() - r.env.WuberFrame:GetLeft()
	eq(math.floor(pl + 0.5), 360, "the pane is the right half")
	eq(math.floor(wm.view:GetLeft() - UI.Fold.Pane():GetLeft() + 0.5), 0, "the map fills the pane from its left")
	-- Here: the docked panel
	wm.seg.buttons[1]:Click()
	ok(m:IsVisible() and not wm.view:IsShown(), "Here shows the docked map")
	eq(m:GetWidth(), 360)
	wm.seg.buttons[2]:Click()
	-- confirm: the gold route to the driver's town
	UI.Show("confirm", "anita lift")
	w:advance(1)
	eq(UI.Fold.Page(), "confirm", "confirm page")
	ok(UI.Fold.IsUnfolded(), "confirm unfolded")
	eq(m:GetParent(), home, "leaving ride undocked Home's map")
	local cw = Mod.cache.maps[seen.holders.confirm]
	ok(cw and cw.built and cw.view:IsVisible(), "confirm's world map shows")
	ok(cw.gold.used > 0, "the gold route Orgrimmar > Undercity")
	ok(cw.focusRing:IsShown(), "a ring at Undercity")
	-- back to ride, then fold with the button: undocked, nothing drawn while folded
	UI.Show("home")
	w:advance(1)
	eq(m:GetParent(), holder, "docked again")
	r:click(UI.state.phone.fold)
	w:advance(1)
	ok(not UI.Fold.IsUnfolded(), "folded")
	eq(r.env.WuberFrame:GetWidth(), 360, "360 wide")
	eq(m:GetParent(), home, "undocked")
	eq(m:GetWidth(), 360, "the panel's own width")
	eq(m.mapW, nil, "no docked width left")
	ok(m:IsShown(), "Home's map shows again")
	ok(not wm.view:IsVisible(), "the world map is not visible folded")
	local n = wm.redraws
	W.Fire("DRIVERS")
	W.Fire("BOUNTY")
	w:advance(1)
	eq(wm.redraws, n, "folded: no redraws")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	clean(w)
end)

test("ui.rider.worldmap: pins for the drivers the rider list shows (busy and paused muted since round 13, hidden none); the rider's own bounty coin", function()
	local w, r, W, Mod, holder = setup()
	local t0 = r.env.GetTime()
	local function drv(key, name, dest, state)
		W.drivers[key] = { name = name, key = key, dest = dest, price = 5000, state = state, team = 3,
			service = "Rides", heard = t0, mapID = 1454, x = 0.5, y = 0.5 }
	end
	drv("anita lift", ANITA, "Gadgetzan", "open")
	drv("bea bright", "Bea Bright", "Ratchet", "busy")
	drv("cal cole", "Cal Cole", "Everlook", "paused")
	drv("dee dark", "Dee Dark", "Undercity", "open")
	local hidden = W.IsHidden
	W.IsHidden = function(key) if key == "dee dark" then return true end return hidden(key) end
	W.Bounty.Demand = function() return {} end
	W.Bounty.Mine = function() return { place = "Everlook", copper = 6000, at = 1, sends = 1, left = 1200 } end
	Mod.Build(holder)
	Mod.Show("world")
	local wm = mapOf(Mod, holder)
	-- (round 13, I21) every driver the list shows has a pin: Anita (open), Bea (busy) and Cal (paused)
	eq(wm.pinCount, 3, "Anita, Bea and Cal (not hidden Dee)")
	local keys = {}
	for i = 1, wm.pinCount do keys[#keys + 1] = wm.pins[i].key end
	table.sort(keys)
	eq(table.concat(keys, ","), "anita lift,bea bright,cal cole", "the pins")
	eq(wm.coinCount, 1, "the rider's bounty")
	eq(wm.coins[1].count:GetText(), "1")
	ok(wm.coins[1]:IsShown(), "shown")
	-- the bounty ends: the coin goes on the next BOUNTY
	W.Bounty.Mine = function() return nil end
	W.Fire("BOUNTY", "mine", nil)
	w:advance(1)
	eq(wm.coinCount, 0, "no coin")
	ok(not wm.coins[1]:IsShown(), "hidden")
	-- a new driver opens: a pin on the next DRIVERS
	W.IsHidden = hidden
	W.Fire("DRIVERS")
	w:advance(1)
	eq(wm.pinCount, 4, "Dee shown once not hidden")
	clean(w)
end)

-- (2.3.2, S7 / B4) Ratchet's price stays inside Kalimdor; the focus ring is centred on a bounty coin; your own pin
test("ui.rider.worldmap: 2.3.2 - a price tag stays inside its continent; the ring centres on the coin; your own 'You' pin", function()
	local w, r, W, Mod, holder = setup()
	local t0 = r.env.GetTime()
	W.drivers["bob stone"] = { name = T.BOB, key = "bob stone", dest = "Ratchet", price = 6000, state = "open", team = 3, service = "Rides", heard = t0 }
	W.Bounty.Demand = function() return { { place = "Gadgetzan", riders = 1, low = 5000, high = 5000, newest = 30 } } end
	-- your You tag is kept clear too, so it stands away from Ratchet's price tag
	W.DriverBeacon = function() return { dest = "Undercity", destShown = "Undercity", price = 5000, state = "open", service = "A", team = 1, seats = 0, queue = 0 } end
	Mod.Build(holder)
	Mod.Show("world", { focus = "Gadgetzan" })
	local wm = mapOf(Mod, holder)
	local pin
	for i = 1, wm.pinCount do if wm.pins[i].key == "bob stone" then pin = wm.pins[i] end end
	ok(pin and pin.tag and pin.tag:IsShown(), "Ratchet's price tag")
	local bx, _, bw = Mod.Box(1) -- (the cropped box)
	local right = wm.view:GetLeft() + bx + bw
	ok(pin.tag:GetRight() <= right + 0.5, "the tag ends inside Kalimdor: " .. tostring(pin.tag:GetRight()) .. " vs " .. right)
	ok(pin.tag:GetLeft() >= wm.view:GetLeft() + bx - 0.5, "and starts inside it")
	eq(wm.coinCount, 1, "the bounty coin")
	local c, ring = wm.coins[1], wm.focusRing
	ok(ring:IsShown(), "the ring")
	ok(math.abs((ring:GetLeft() + ring:GetRight()) / 2 - (c:GetLeft() + c:GetRight()) / 2) < 0.6
		and math.abs((ring:GetTop() + ring:GetBottom()) / 2 - (c:GetTop() + c:GetBottom()) / 2) < 0.6, "the ring is centred on the coin")
	-- your own pin
	local own = wm.ownPin
	ok(own and own:IsShown(), "your own pin")
	ok(own.tag and own.tag.label:GetText() == "You", "tagged You")
	local went
	W.UI.SelectTab = function(n) went = n return true end
	own:Click()
	eq(went, "Drive", "a tap opens the Drive tab")
	W.DriverBeacon = function() return nil end
	Mod.Refresh()
	ok(not own:IsShown(), "gone when you stop driving")
	clean(w)
end)

-- C's real registrations (UI.Rider.Home / UI.Rider.Confirm): the docked map is not empty - the
-- rider's dot, the zone pill and the pins stay above the map art (a re-parent re-levels the map)
test("ui.rider.homemap: docked by the real ride and confirm pages, the map's dot, zone pill and pins sit above its art; undocked too", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Orgrimmar" })
	r.wide = true
	T.settle(w)
	local W = r.W
	local UI = W.UI
	W.db.coach = true
	W.db.mapView = "here" -- (round 12: World is the default; this test is about the docked Here panel)
	W.drivers["sly fox"] = { name = "Sly Fox", key = "sly fox", dest = "Crossroads", price = 5000, state = "open",
		team = 1, service = "Sly's", heard = r.env.GetTime(), mapID = 1454, x = 0.5, y = 0.5 }
	UI.Toggle(true)
	w:advance(3)
	ok(UI.Fold.IsUnfolded(), "ride unfolded")
	local regs = W.Mod("UI.Fold").state.regs
	local function check(m, holder, what)
		eq(m:GetParent(), holder, what .. ": docked")
		local art = m.canvas:GetFrameLevel()
		ok(m.dots:GetFrameLevel() > art, what .. ": overlays above the art (" .. m.dots:GetFrameLevel() .. " > " .. art .. ")")
		ok(m.me:GetFrameLevel() > art, what .. ": the rider's dot above the art")
		ok(m.me:IsVisible(), what .. ": the rider's dot shows")
		ok(m.zone:GetFrameLevel() > art, what .. ": the zone pill above the art")
	end
	local home = UI.state.screens.home
	check(home.map, regs.ride.holder, "ride")
	ok(#home.map.pins > 0 and home.map.pins[1]:IsShown() and home.map.pins[1]:GetFrameLevel() > home.map.canvas:GetFrameLevel(), "Sly's pin shows above the art")
	UI.Show("confirm", "sly fox")
	w:advance(1)
	local conf = UI.state.screens.confirm
	check(conf.map, regs.confirm.holder, "confirm")
	-- folded again: the panels are back on their pages, still in order
	UI.Show("home")
	w:advance(1)
	r:click(UI.state.phone.fold)
	w:advance(1)
	ok(not UI.Fold.IsUnfolded(), "folded")
	ok(home.map:GetParent() ~= regs.ride.holder, "undocked")
	ok(home.map.me:GetFrameLevel() > home.map.canvas:GetFrameLevel(), "undocked: the dot above the art")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	clean(w)
end)
