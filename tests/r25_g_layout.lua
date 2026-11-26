-- BRIEF25 L1: the layout sweep covers the login tip card (UI.Tips) and the new World map with a sea route.
-- tests/layout/extra_screens.lua adds the shots when their modules exist; FILE_SCREENS maps the files to them.
-- Run by tests/run.lua; lua tests/run.lua "layout extra"
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local root = T.dir .. "/.."

local function read(p) local f = io.open(p, "rb") local s = f and f:read("*a") or "" if f then f:close() end return s end
local X = dofile(root .. "/tests/layout/extra_screens.lua")

local function fakeW(mods)
	return { Mod = function(name) return mods[name] end }
end

test("layout extra: nothing is added when the modules are missing", function()
	local L = { PHOTO_SCREENS = {} }
	eq(#X.install(L, fakeW({})), 0)
	eq(#L.PHOTO_SCREENS, 0)
end)

test("layout extra: the tip card and the sea route shots are added when their modules exist", function()
	local L = { PHOTO_SCREENS = {} }
	local added = X.install(L, fakeW({ ["UI.Tips"] = { ShowNow = function() end }, ["UI.Rider.WorldMap"] = { Show = function() return true end },
		["UI.Rider.SeaRoute"] = {} }))
	eq(table.concat(added, ","), "tipcard,worldmap_sea")
	ok(L.PHOTO_SCREENS[1].unfold, "the tip card is taken folded and unfolded")
	eq(L.PHOTO_SCREENS[2].only, "unfolded")
end)

test("layout extra: longest picks the longest tip text", function()
	local s, id = X.longest({ { id = "a", text = "short" }, { id = "b", text = "a much longer tip text" }, "mid text" })
	eq(s, "a much longer tip text")
	eq(id, "b")
end)

test("layout extra: the sweep loads the extra screens and FILE_SCREENS maps the new files", function()
	ok(read(root .. "/tests/layout/run.lua"):find("extra_screens.lua", 1, true), "run.lua installs them")
	local src = read(root .. "/tools/layout-check.lua")
	ok(src:find('{ "UI/Tips", { "tipcard" } }', 1, true), "UI/Tips maps to tipcard")
	ok(src:find('{ "UI/Rider/SeaRoute", { "worldmap" } }', 1, true), "SeaRoute maps to worldmap")
end)
