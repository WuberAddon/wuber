-- Tests of the one shared no-glow helper (issue 6): T.NoGlow lives in Theme.Widgets and the UI files use it
-- instead of each keeping its own copy. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local FILES = {
	"Wuber/UI/Driver/Build.lua", "Wuber/UI/Driver/Sheets.lua", "Wuber/UI/Rider/Done.lua",
	"Wuber/UI/Rider/Home.lua", "Wuber/UI/Rider/Ride.lua", "Wuber/UI/Rider/Trips.lua",
}

test("noglow: no UI file keeps its own copy of the noGlow helper (issue 6)", function()
	for _, path in ipairs(FILES) do
		local f = assert(io.open(path, "r"), path)
		local src = f:read("*a")
		f:close()
		ok(not src:find("local function noGlow", 1, true), path .. " still defines its own noGlow")
	end
end)

test("noglow: T.NoGlow gives an object that takes any call and does nothing (issue 6)", function()
	local W, w = T.contract("Theme.Widgets", "tests/theme/widgets_test.lua", { ["T.NoGlow"] = "function" })
	local Th = W.Theme
	local g = Th.NoGlow()
	eq(type(g), "table")
	eq(g:Show(), nil)
	eq(g:SetVertexColor(1, 0, 0, 1), nil)
	eq(g:SetPoint("CENTER", 0, 0), nil)
	ok(Th.NoGlow() ~= g, "each call gives a fresh object")
end)
