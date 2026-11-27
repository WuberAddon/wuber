-- the layout check covers the "Skip the bird" card (Wuber/UI/Bird.lua): FILE_SCREENS maps the file to the
-- lab's gated "bird" shot, the sweep opens the fake flight map so that shot is taken at every size, and a text half
-- over a pill ("straddle") is a problem (the card's "Don't show again" over "Open Wuber" before B1's fix).
-- Run by tests/run.lua (T = its helper table); lua tests/run.lua "layout bird"
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local root = T.dir .. "/.."

local function read(p) local f = io.open(p, "rb") local s = f and f:read("*a") or "" if f then f:close() end return s end

local function lua() return (arg and arg[-1]) or "lua5.1" end

test("layout bird: FILE_SCREENS maps UI/Bird to the bird shot", function()
	local src = read(root .. "/tools/layout-check.lua")
	ok(src:find('{ "UI/Bird", { "bird" } }', 1, true), "the mapping is in FILE_SCREENS")
	ok(read(root .. "/tests/layout/run.lua"):find("openTaxiMap", 1, true), "the sweep opens the fake flight map")
end)

test("layout bird: the 9-size sweep takes the bird card (and a text half over a pill is a kind)", function()
	local cmd = ('"%s" tools/layout-check.lua --files Wuber/UI/Bird.lua 2>&1'):format(lua():gsub("\\", "/"))
	local p = io.popen("cd " .. root .. " && " .. cmd)
	local out = p and p:read("*a") or ""
	if p then p:close() end
	ok(out:find("9 runs", 1, true), "nine runs (3 windows x 3 sizes): " .. out)
	ok(out:find("9 shots", 1, true), "one bird shot per run: " .. out)
	ok(out:find(" 0 broken", 1, true), "nothing broken: " .. out)
	ok(out:find("screens bird", 1, true) or out:find("bird", 1, true), "the bird screen was selected")
	-- before B1's fix the card is flagged; after it, clean: either way no other kind of failure
	if out:find("result 1", 1, true) then ok(out:find("straddle: half over [^\n]*Open Wuber"), "the flag is the label over the pill: " .. out) end
end)
