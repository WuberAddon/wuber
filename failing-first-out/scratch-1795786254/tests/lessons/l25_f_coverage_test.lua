-- Tests of tools/tests-for.lua --coverage (round 25, group F, L14): a test the name-based list misses comes from the
-- coverage map ("by coverage"), a part that runs a fixture pinning the changed file is listed ("by fixture"), and a
-- missing map says how to build it. Loaded by tests/run.lua (tools part list) with its helper table.
local T = ...
local test, ok = T.test, T.ok
local root = T.dir .. "/.."

local function lua() return (arg and arg[-1]) or "lua5.1" end
local function tf(args)
	local p = io.popen(("cd %s && \"%s\" tools/tests-for.lua %s 2>&1"):format(root, lua():gsub("\\", "/"), args))
	local out = p and p:read("*a") or ""
	if p then p:close() end
	return out
end

local NAME = "layout bird: FILE_SCREENS maps UI/Bird to the bird shot" -- a real test, in r24_c_layout, which names no Widgets file
local MAP = T.dir .. "/out/l25f-map.txt"

-- guard: infra, failed before because tools/tests-for.lua had no --coverage and tools/coverage-map.lua did not exist
test("l25 F tests-for --coverage: a test the map says ran Widgets.lua is listed by coverage; the name list lacks it", function()
	local f = assert(io.open(MAP, "wb"))
	f:write(NAME, "\tUI/Widgets.lua,Core/Base.lua\n", "some other test\tCore/Base.lua\n")
	f:close()
	local base = tf("Wuber/UI/Widgets.lua")
	local cov = tf("--coverage --map=" .. MAP .. " Wuber/UI/Widgets.lua")
	os.remove(MAP)
	ok(not base:find(NAME, 1, true), "the name-based list does not have it: " .. base)
	ok(cov:find(NAME, 1, true), "--coverage lists it: " .. cov)
	ok(cov:find("(by coverage)", 1, true), "and says where it came from: " .. cov)
	ok(cov:find("by name", 1, true), "the name-based part is still there, labelled: " .. cov)
	ok(cov:find("r24_c_layout", 1, true) and cov:find("tests: --files=", 1, true), "its part is on the run line: " .. cov)
	ok(not cov:find("some other test", 1, true), "a test that did not run the file is not listed")
end)

-- guard: infra, failed before because tools/tests-for.lua had no --coverage and tools/coverage-map.lua did not exist
test("l25 F tests-for --coverage: no map prints how to build it and today's list", function()
	local cov = tf("--coverage --map=" .. T.dir .. "/out/l25f-no-such-map.txt Wuber/UI/Widgets.lua")
	ok(cov:find("tools/coverage-map.lua", 1, true), "tells how to build the map: " .. cov)
	ok(cov:find("tests: --files=", 1, true), "today's list is still printed: " .. cov)
end)

-- guard: infra, failed before because tools/tests-for.lua had no --coverage and tools/coverage-map.lua did not exist
test("l25 F tests-for --coverage: a file pinned by tests/fixtures/old_pills.lua lists the harness draw part by fixture", function()
	local cov = tf("--coverage --map=" .. T.dir .. "/out/l25f-no-such-map.txt Wuber/UI/Window.lua")
	ok(cov:find("harness_draw", 1, true), "the harness draw part: " .. cov)
	ok(cov:find("(by fixture)", 1, true), "labelled by fixture: " .. cov)
end)
