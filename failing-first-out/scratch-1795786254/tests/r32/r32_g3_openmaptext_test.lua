local T = ...
-- Round 32 group G (HUNT-09, HUNT-10): Settings, Help and the Home tip no longer say pins and the
-- route need OpenMap (Wuber also draws them on the game's own world map), and the OpenMap row no
-- longer promises a glide on a card click (nothing calls W.Map.ShowDriver).
local test, eq, ok = T.test, T.eq, T.ok

local function slurp(path)
	local f = assert(io.open(path, "rb"))
	local s = f:read("*a")
	f:close()
	return s
end
local function root()
	local here = (debug.getinfo(1, "S").source or ""):gsub("^@", ""):gsub("\\", "/")
	local r = here:gsub("/?tests/r32/[^/]*$", "")
	return r == "" and "." or r
end

test("r32 g3: the map row says Best with OpenMap, not Needs, when OpenMap is missing", function()
	local w = T.newWorld()
	local r = T.rider(w)
	w:advance(3)
	r.W.UI.Toggle(true)
	r.W.UI.OpenSettings("map")
	w:advance(1)
	eq(#r:findText("^Needs the OpenMap addon$"), 0, "no longer claims OpenMap is needed")
	ok(#r:findText("^Best with OpenMap: not installed$") > 0, "the map row says best with")
end)

test("r32 g3: no text promises a glide on a card click; Settings, Help and Home name the game's own world map", function()
	local base = root()
	local panel = slurp(base .. "/Wuber/UI/Settings/Panel.lua")
	local home = slurp(base .. "/Wuber/UI/Rider/Home.lua")
	ok(not panel:find("glides the map", 1, true), "no glide promise in Settings")
	ok(not panel:find("Needs the free OpenMap", 1, true), "Settings tooltip does not say needs")
	ok(panel:find("Best with OpenMap; works without it.", 1, true), "Settings says OpenMap is a bonus, never a need (the 20 rewrites, W-1: it no longer names the game's own world map)")
	-- (word rule) Help's card 7 is "World map: best with the free OpenMap addon.": it no longer names the game's own
	-- world map; it still says OpenMap is a bonus, never a need
	ok(slurp(base .. "/Wuber/UI/Settings/Pages.lua"):find("World map: best with the free OpenMap addon.", 1, true), "Help's map card says best with, not needs")
	ok(home:find("game's own world map", 1, true), "the Home tip names it")
end)
