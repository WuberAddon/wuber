-- BRIEF26 item 3: the layout checker's World view rule (tests/layout/engine.lua E.worldRule / E.world).
-- A continent's box must lie wholly inside the view (4 px margin) and both continents must draw at one scale
-- (pixels per world yard within 1%). Run by tests/run.lua; lua tests/run.lua "r26 layout world"
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local root = T.dir .. "/.."
local E = assert(loadfile(root .. "/tests/layout/engine.lua"))(H)
local X = dofile(root .. "/tests/layout/extra_screens.lua")

-- a fake World map: each continent a box and px per yard (x, y); Project maps world yards to the pane
local function fakeWM(boxes, scales)
	return {
		Box = function(c) local b = boxes[c] if b then return b[1], b[2], b[3], b[4] end end,
		Project = function(c, wx, wy) local s = scales[c] if s then return boxes[c][1] + wx * s, boxes[c][2] + wy * s end end,
	}
end
local VIEW = { w = 360, h = 544 }
local function kinds(out) local s = {} for _, h in ipairs(out) do s[#s + 1] = h.detail end return table.concat(s, "|") end

test("r26 layout world: two continents inside the view at one scale pass", function()
	local out = E.worldRule(fakeWM({ [1] = { 10, 60, 160, 400 }, [0] = { 170, 60, 160, 400 } }, { [1] = 0.01, [0] = 0.01005 }), VIEW)
	eq(#out, 0, kinds(out))
end)

test("r26 layout world: a box past the view edge says the continent leaves the view", function()
	local out = E.worldRule(fakeWM({ [1] = { 10, 60, 160, 400 }, [0] = { 170, 60, 200, 400 } }, { [1] = 0.01, [0] = 0.01 }), VIEW)
	eq(#out, 1, kinds(out))
	ok(out[1].detail:find("continent leaves the view", 1, true), out[1].detail)
	-- inside the view but inside the margin counts as leaving too
	out = E.worldRule(fakeWM({ [1] = { 2, 60, 160, 400 }, [0] = { 162, 60, 160, 400 } }, { [1] = 0.01, [0] = 0.01 }), VIEW)
	eq(#out, 1, kinds(out))
end)

test("r26 layout world: unequal pixels per yard says the continent scales differ", function()
	local out = E.worldRule(fakeWM({ [1] = { 10, 60, 160, 400 }, [0] = { 170, 60, 160, 400 } }, { [1] = 0.01, [0] = 0.0117 }), VIEW)
	ok(#out >= 1 and out[1].detail:find("continent scales differ", 1, true), kinds(out))
	-- 0.9% apart is within the 1% allowed
	out = E.worldRule(fakeWM({ [1] = { 10, 60, 160, 400 }, [0] = { 170, 60, 160, 400 } }, { [1] = 0.01, [0] = 0.01009 }), VIEW)
	eq(#out, 0, kinds(out))
end)

test("r26 layout world: the layout scene stubs Kalimdor from the saved calibration and a taller Eastern Kingdoms", function()
	local k, e = X.CAL[1414], X.CAL[1415]
	eq(k.u0, 0.4507)
	eq(k.v0, 0.5123)
	eq(k.du, 4.1085e-5)
	ok(1 / e.du > 1 / e.dv, "the Eastern Kingdoms are taller (along y) than wide")
	ok(math.abs(1 / k.du - 1 / e.du) > 1000, "the two continents differ in world size")
end)

test("r26 layout world: E.world is quiet when the World view is not showing", function()
	eq(#E.world({}), 0)
	eq(#E.world({ W = { Mod = function() return { Box = function() end, cache = { last = { mode = "here", view = {} } } } end } }), 0)
end)
