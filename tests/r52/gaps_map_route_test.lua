-- Adopted from the fable-2411 draft in r52 (job 2706).
-- Final home: tests/ui/map/route_test.lua; add it to the per-module list in tests/run.lua.
-- Pins: the contract (RouteOnPanel, HideRouteOnPanel, HideRoute, UpdateRoute); bad frame / missing ends / zero size draw nothing and make nothing.
-- Pins: the dot count (GAP spacing, never more than MAX_DOTS), the first dots fading in, dot size and spacing options, fewer dots for a shorter route.
-- Pins: a line too short to show, a line clipped by the frame (dots stop at the edge, the ring only when the destination is in view), a line wholly outside.
-- Pins: one handle per frame, Hide / HideRouteOnPanel hide it, drawing again brings it back.
-- Why it matters to a player: the violet dotted line on the Home map and the world map is how a rider sees where their ride is going; if this broke they would see
-- a line that never goes, dots piled across the whole screen on a long trip, a ring floating outside the map, or a line left behind after the ride.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function near(a, b, what)
	ok(type(a) == "number" and math.abs(a - b) < 1e-6, (what or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end

-- a lone rider and a panel frame of w x h under UIParent (what Home's mini map hands RouteOnPanel)
local function setup(w_, h_)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local f = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	f:SetSize(w_ or 400, h_ or 200)
	f:SetPoint("CENTER")
	return w, r, r.W.Map, f, r.W.Mod("UI.Map.Base")
end

-- the dots live in the flow frame (the holder's one child); the destination glow and ring are the holder's own textures
local function flowOf(handle) return (handle.frame:GetChildren()) end

local function dotsShown(handle)
	local n = 0
	for _, t in ipairs({ flowOf(handle):GetRegions() }) do
		if t:IsShown() then n = n + 1 end
	end
	return n
end

local function ringShown(handle)
	for _, t in ipairs({ handle.frame:GetRegions() }) do
		if tostring(t:GetTextureFilePath()):find("ring", 1, true) then return t:IsShown() == true end
	end
	error("the holder has no ring texture")
end

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.route: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("UI.Map.Route", "tests/ui/map/route_test.lua", {
		["W.Map.RouteOnPanel"] = "function",
		["W.Map.HideRouteOnPanel"] = "function",
		["Mod.HideRoute"] = "function",
		["Mod.UpdateRoute"] = "function",
	})
	ok(Mod, "W.Mod(\"UI.Map.Route\")")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.route: RouteOnPanel draws nothing for a bad frame, missing ends or a frame with no size, and makes no frames", function()
	local w, r, M, f = setup()
	local made = #r.widgets
	eq(M.RouteOnPanel(nil, { 0.1, 0.5 }, { 0.9, 0.5 }), nil, "no frame") -- Route.lua RouteOnPanel: type(frame) ~= "table"
	eq(M.RouteOnPanel("not a frame", { 0.1, 0.5 }, { 0.9, 0.5 }), nil, "a string")
	eq(M.RouteOnPanel({}, { 0.1, 0.5 }, { 0.9, 0.5 }), nil, "a table that cannot make textures")
	eq(M.RouteOnPanel(f, nil, { 0.9, 0.5 }), nil, "no start")
	eq(M.RouteOnPanel(f, { 0.1, 0.5 }, nil), nil, "no end")
	eq(M.RouteOnPanel(f, { 0.1 }, { 0.9, 0.5 }), nil, "a start with no y")
	eq(M.RouteOnPanel(f, { 0.1, "x" }, { 0.9, 0.5 }), nil, "a start that is not a number")
	f:SetSize(0, 200)
	eq(M.RouteOnPanel(f, { 0.1, 0.5 }, { 0.9, 0.5 }), nil, "a frame with no width")
	eq(#r.widgets, made, "nothing was created")
	M.HideRouteOnPanel(nil)
	M.HideRouteOnPanel(f) -- never routed: harmless
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.route: a 320 px line draws one dot per GAP, the first two fading in, in DOT-sized dots", function()
	local w, r, M, f, B = setup(400, 200)
	local h = M.RouteOnPanel(f, { 0.1, 0.5 }, { 0.9, 0.5 })
	ok(h and h.frame, "a handle with the holder frame")
	ok(h.frame:IsShown(), "the line shows")
	local len = 0.8 * 400
	local gap = math.max(B.GAP, len / B.MAX_DOTS)
	local want = math.floor(len / gap + 1e-6) -- Route.lua RouteDraw: dot k at k * gap, k = 0 .. floor(len / gap) - 1
	eq(dotsShown(h), want, "one dot per gap along the line")
	local dots = { flowOf(h):GetRegions() }
	near(select(4, dots[1]:GetVertexColor()), 0.3, "first dot is faint") -- RouteDraw: k == 0 -> alpha * 0.3
	near(select(4, dots[2]:GetVertexColor()), 0.7, "second dot fainter")
	near(select(4, dots[3]:GetVertexColor()), 1, "the rest full")
	near(dots[1]:GetWidth(), B.DOT, "dot size DOT on screen (1 unit per pixel on a panel)")
	ok(ringShown(h), "the destination is in view: its ring shows")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.route: the dot and gap options and alpha change the dots; a shorter line shows fewer and the rest are hidden, not kept", function()
	local w, r, M, f, B = setup(400, 200)
	local h = M.RouteOnPanel(f, { 0.1, 0.5 }, { 0.9, 0.5 }, { dot = 10, gap = 30, alpha = 0.5 })
	eq(dotsShown(h), math.floor(320 / 30 + 1e-6), "gap 30: floor(320 / 30) dots")
	local dots = { flowOf(h):GetRegions() }
	near(dots[1]:GetWidth(), 10, "dot size option")
	near(select(4, dots[3]:GetVertexColor()), 0.5, "alpha option")
	local h2 = M.RouteOnPanel(f, { 0.1, 0.5 }, { 0.9, 0.5 })
	eq(h2, h, "the same frame keeps its handle")
	local full = dotsShown(h2)
	M.RouteOnPanel(f, { 0.1, 0.5 }, { 0.5, 0.5 })
	eq(dotsShown(h), math.floor(160 / math.max(B.GAP, 160 / B.MAX_DOTS) + 1e-6), "half the line, about half the dots")
	ok(dotsShown(h) < full, "fewer than before")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.route: a very long line never gets more than MAX_DOTS dots", function()
	local w, r, M, f, B = setup(4000, 2000)
	local h = M.RouteOnPanel(f, { 0, 0.5 }, { 1, 0.5 })
	eq(dotsShown(h), B.MAX_DOTS, "capped: the gap grows instead (4000 px / 40 = 100 px)") -- RouteDraw: gap = max(GAP, len / MAX_DOTS)
	local h2 = M.RouteOnPanel(f, { 0, 0 }, { 1, 1 })
	ok(dotsShown(h2) <= B.MAX_DOTS, "a diagonal too: " .. dotsShown(h2))
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.route: a line shorter than one gap is not drawn; missing ends hide a line already drawn; drawing again brings it back", function()
	local w, r, M, f = setup()
	local h = M.RouteOnPanel(f, { 0.1, 0.5 }, { 0.9, 0.5 })
	ok(h.frame:IsShown(), "control: drawn")
	local h2 = M.RouteOnPanel(f, { 0.5, 0.5 }, { 0.5, 0.51 }) -- 2 px, less than GAP
	eq(h2, h, "the handle comes back")
	ok(not h.frame:IsShown(), "too short: hidden") -- RouteDraw: len < gapPx * upp
	M.RouteOnPanel(f, { 0.1, 0.5 }, { 0.9, 0.5 })
	ok(h.frame:IsShown(), "back")
	eq(M.RouteOnPanel(f, nil, { 0.9, 0.5 }), h, "a lost start: the old handle")
	ok(not h.frame:IsShown(), "and the line is hidden")
	M.RouteOnPanel(f, { 0.1, 0.5 }, { 0.9, 0.5 })
	M.HideRouteOnPanel(f)
	ok(not h.frame:IsShown(), "HideRouteOnPanel")
	M.RouteOnPanel(f, { 0.1, 0.5 }, { 0.9, 0.5 })
	ok(h.frame:IsShown(), "drawn again")
	h.Hide()
	ok(not h.frame:IsShown(), "the handle's own Hide")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.route: a line is clipped to its frame: dots stop at the edge, the ring only shows when the destination is inside, a line wholly outside is not drawn", function()
	local w, r, M, f = setup(400, 200)
	local h = M.RouteOnPanel(f, { 0.1, 0.5 }, { 1.5, 0.5 }) -- ends 200 px past the right edge
	ok(h.frame:IsShown(), "the part inside shows")
	eq(dotsShown(h), math.floor(360 / 16 + 1e-6), "dots only over the 360 px inside the frame") -- Clip, then RouteDraw: floor(t1 * len / gap)
	ok(not ringShown(h), "destination outside: no ring")
	M.RouteOnPanel(f, { 0.1, 0.5 }, { 0.9, 0.5 })
	ok(ringShown(h), "destination inside: ring")
	M.RouteOnPanel(f, { 1.2, 0.5 }, { 1.8, 0.5 })
	ok(not h.frame:IsShown(), "a line wholly outside is hidden")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.map.route: each frame has its own line", function()
	local w, r, M, f = setup()
	local g = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	g:SetSize(300, 300)
	local h1 = M.RouteOnPanel(f, { 0.1, 0.5 }, { 0.9, 0.5 })
	local h2 = M.RouteOnPanel(g, { 0.1, 0.5 }, { 0.9, 0.5 })
	ok(h1 ~= h2, "two handles")
	M.HideRouteOnPanel(f)
	ok(not h1.frame:IsShown(), "the first is hidden")
	ok(h2.frame:IsShown(), "the second still shows")
	T.clean(w)
end)

-- NEEDS FAKE-GAME: a way to read the world map's own line (UpdateRoute's private mapRoute). The tests below would pin the
-- ROUTE-states rule (the line shows only for requesting / accepted / invited / ingroup / summoning / portal, never across
-- continents, never when the rider's position is unreadable) but nothing public says whether the line is drawn:
-- test("ui.map.route: the world map's line shows while the ride is on the way, not when it is done or crosses continents", function()
--	local w, r = ...                            -- a rider in Orgrimmar, the map open on Kalimdor (wm:SetMapID(1414) wm:Show())
--	r.W.ride = { id = "x", driver = "Bob Stone", driverKey = "bob stone", dest = "Thunder Bluff", state = "summoning" }
--	r.W.Fire("RIDE")                            -- Map listens RIDE and calls UpdateRoute; then count visible dots under WorldMapFrame.ScrollContainer.Child
--	-- state = "done" -> no dots; dest = "Stormwind" (Eastern Kingdoms) -> no dots (RouteEnds: c1 ~= c2)
-- end)
