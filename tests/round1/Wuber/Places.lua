-- Places: the summon spots riders ask for. Each has the map it sits on (uiMapID) and where
-- on that map (x, y from 0 to 1), so a pin can be placed, plus the names riders type.
--
--   W.PLACES               the list (see the fields below)
--   W.NormPlace(text)      "Light's Hope" -> "lights hope"
--   W.FindPlace(text)      a place from what a rider typed ("uc", "org", "booty"), or nil
--   W.SearchPlaces(text)   every place that starts with / contains what was typed
--   W.PlaceAt(mapID, x, y) the place at a map position, or nil
--   W.DestHere()           where the player stands: its name, and the place if it is one
--
-- Coordinates are approximate: they only place a pin. Names must be right.

local _, W = ...

local str, num = W.Str, W.Num

-- One entry per place:
--   name   how the place is written
--   mapID  the uiMapID of the map it sits on
--   x, y   where on that map (0..1)
--   kind   "city" (the whole map is the city), "town", "dungeon" or "zone"
--   zone   the zone it is in (towns and dungeons)
--   names  other names riders type (lower case, no apostrophes)
local function P(kind, name, mapID, x, y, zone, names)
	return { name = name, mapID = mapID, x = x, y = y, kind = kind, zone = zone, names = names or {} }
end

W.PLACES = {
	-- capital cities: their own map, pinned in the middle
	P("city", "Undercity", 1458, 0.5, 0.5, "Tirisfal Glades", { "uc", "u c", "under city", "the undercity", "ucity", "undercit", "undercty", "undrcity" }),
	P("city", "Orgrimmar", 1454, 0.5, 0.5, "Durotar", { "org", "og", "orgri", "orgrim", "orgrimar", "orgimmar", "orgrimmer" }),
	P("city", "Thunder Bluff", 1456, 0.5, 0.5, "Mulgore", { "tb", "thunderbluff", "thunder bluf" }),
	P("city", "Stormwind", 1453, 0.5, 0.5, "Elwynn Forest", { "sw", "storm wind", "stormwind city" }),
	P("city", "Ironforge", 1455, 0.5, 0.5, "Dun Morogh", { "if", "iron forge" }),
	P("city", "Darnassus", 1457, 0.5, 0.5, "Teldrassil", { "darn" }),

	-- towns and hubs, Kalimdor
	P("town", "Ratchet", 1413, 0.627, 0.370, "The Barrens", { "rachet", "ratchett", "rachett", "ratchit", "ratch", "ratchet docks" }),
	P("town", "Crossroads", 1413, 0.517, 0.300, "The Barrens", { "the crossroads", "xroads", "xr", "cross roads" }),
	P("town", "Gadgetzan", 1446, 0.515, 0.285, "Tanaris", { "gadgetzen", "gadgetsan", "gadget", "gz" }),
	P("town", "Everlook", 1452, 0.615, 0.385, "Winterspring", { "ever look" }),
	P("town", "Cenarion Hold", 1451, 0.505, 0.345, "Silithus", { "cenarion", "ch" }),
	P("town", "Camp Mojache", 1444, 0.745, 0.430, "Feralas", { "mojache" }),
	P("town", "Feathermoon Stronghold", 1444, 0.310, 0.430, "Feralas", { "feathermoon" }),
	P("town", "Brackenwall Village", 1445, 0.360, 0.310, "Dustwallow Marsh", { "brackenwall", "bracken wall" }),
	P("town", "Theramore", 1445, 0.665, 0.490, "Dustwallow Marsh", { "theramore isle" }),
	P("town", "Splintertree Post", 1440, 0.735, 0.610, "Ashenvale", { "splintertree", "splinter tree" }),
	P("town", "Sun Rock Retreat", 1442, 0.475, 0.615, "Stonetalon Mountains", { "sun rock", "sunrock" }),
	P("town", "Shadowprey Village", 1443, 0.255, 0.715, "Desolace", { "shadowprey" }),
	P("town", "Freewind Post", 1441, 0.455, 0.505, "Thousand Needles", { "freewind" }),
	P("town", "Marshal's Refuge", 1449, 0.435, 0.080, "Un'Goro Crater", { "marshals", "marshal refuge" }),
	P("town", "Nighthaven", 1450, 0.520, 0.400, "Moonglade", { "moonglade" }),
	P("town", "Valormok", 1447, 0.220, 0.510, "Azshara", {}),

	-- towns and hubs, Eastern Kingdoms
	P("town", "Booty Bay", 1434, 0.270, 0.770, "Stranglethorn Vale", { "bootybay", "booty", "bb" }),
	P("town", "Grom'gol", 1434, 0.325, 0.290, "Stranglethorn Vale", { "grom gol", "grom", "gromgol base camp" }),
	P("town", "Tarren Mill", 1424, 0.620, 0.200, "Hillsbrad Foothills", { "tarrenmill", "tm" }),
	P("town", "Southshore", 1424, 0.505, 0.570, "Hillsbrad Foothills", { "south shore" }),
	P("town", "Light's Hope Chapel", 1423, 0.810, 0.590, "Eastern Plaguelands", { "lights hope", "light hope", "lhc" }),
	P("town", "Kargath", 1418, 0.040, 0.470, "Badlands", {}),
	P("town", "Stonard", 1435, 0.460, 0.550, "Swamp of Sorrows", {}),
	P("town", "Hammerfall", 1417, 0.735, 0.330, "Arathi Highlands", {}),
	P("town", "Revantusk Village", 1425, 0.780, 0.810, "The Hinterlands", { "revantusk" }),
	P("town", "Thorium Point", 1427, 0.380, 0.270, "Searing Gorge", { "thorium" }),

	-- dungeons and raids (their entrances)
	P("dungeon", "Blackrock Mountain", 1428, 0.300, 0.300, "Burning Steppes", { "blackrock", "black rock", "brm", "brd", "lbrs", "ubrs", "mc", "molten core", "bwl", "blackrock depths", "blackrock spire" }),
	P("dungeon", "Zul'Farrak", 1446, 0.390, 0.200, "Tanaris", { "zf", "zul farrak", "zulfarrak entrance" }),
	P("dungeon", "Dire Maul", 1444, 0.590, 0.450, "Feralas", { "dm", "diremaul", "dmn", "dme", "dmw", "dm north", "dm east", "dm west" }),
	P("dungeon", "Maraudon", 1443, 0.290, 0.620, "Desolace", { "mara" }),
	P("dungeon", "Scarlet Monastery", 1420, 0.825, 0.330, "Tirisfal Glades", { "sm", "scarlet", "sm cath", "sm arm", "sm lib", "sm gy" }),
	P("dungeon", "Razorfen Kraul", 1413, 0.420, 0.900, "The Barrens", { "rfk" }),
	P("dungeon", "Razorfen Downs", 1413, 0.490, 0.940, "The Barrens", { "rfd" }),
	P("dungeon", "Wailing Caverns", 1413, 0.460, 0.360, "The Barrens", { "wc" }),
	P("dungeon", "Stratholme", 1423, 0.310, 0.150, "Eastern Plaguelands", { "strat", "strath" }),
	P("dungeon", "Scholomance", 1422, 0.690, 0.730, "Western Plaguelands", { "scholo" }),
	P("dungeon", "Uldaman", 1418, 0.440, 0.120, "Badlands", { "ulda", "uld" }),
	P("dungeon", "Sunken Temple", 1435, 0.700, 0.540, "Swamp of Sorrows", { "st", "temple of atalhakkar" }),
	P("dungeon", "Shadowfang Keep", 1421, 0.450, 0.680, "Silverpine Forest", { "sfk", "shadowfang" }),
	P("dungeon", "Gnomeregan", 1426, 0.240, 0.390, "Dun Morogh", { "gnomer" }),
	P("dungeon", "Blackfathom Deeps", 1440, 0.140, 0.140, "Ashenvale", { "bfd", "blackfathom" }),
	P("dungeon", "Zul'Gurub", 1434, 0.530, 0.170, "Stranglethorn Vale", { "zg", "zul gurub" }),
	P("dungeon", "Onyxia's Lair", 1445, 0.520, 0.760, "Dustwallow Marsh", { "ony", "onyxia" }),
	P("dungeon", "Ahn'Qiraj", 1451, 0.290, 0.920, "Silithus", { "aq", "aq20", "aq40", "ahn qiraj" }),

	-- whole zones: found by name, never returned by W.PlaceAt
	P("zone", "The Barrens", 1413, 0.5, 0.5, nil, { "barrens" }),
	P("zone", "Tanaris", 1446, 0.5, 0.5, nil, {}),
	P("zone", "Winterspring", 1452, 0.5, 0.5, nil, { "ws" }),
	P("zone", "Silithus", 1451, 0.5, 0.5, nil, {}),
	P("zone", "Feralas", 1444, 0.5, 0.5, nil, {}),
	P("zone", "Desolace", 1443, 0.5, 0.5, nil, {}),
	P("zone", "Dustwallow Marsh", 1445, 0.5, 0.5, nil, { "dustwallow", "dwm" }),
	P("zone", "Thousand Needles", 1441, 0.5, 0.5, nil, { "needles", "1k needles" }),
	P("zone", "Stonetalon Mountains", 1442, 0.5, 0.5, nil, { "stonetalon" }),
	P("zone", "Ashenvale", 1440, 0.5, 0.5, nil, {}),
	P("zone", "Un'Goro Crater", 1449, 0.5, 0.5, nil, { "ungoro", "un goro" }),
	P("zone", "Felwood", 1448, 0.5, 0.5, nil, {}),
	P("zone", "Azshara", 1447, 0.5, 0.5, nil, {}),
	P("zone", "Stranglethorn Vale", 1434, 0.5, 0.5, nil, { "stranglethorn", "stv" }),
	P("zone", "Hillsbrad Foothills", 1424, 0.5, 0.5, nil, { "hillsbrad" }),
	P("zone", "Eastern Plaguelands", 1423, 0.5, 0.5, nil, { "epl", "eastern plague" }),
	P("zone", "Western Plaguelands", 1422, 0.5, 0.5, nil, { "wpl", "western plague" }),
	P("zone", "Burning Steppes", 1428, 0.5, 0.5, nil, { "steppes" }),
	P("zone", "Searing Gorge", 1427, 0.5, 0.5, nil, {}),
	P("zone", "Badlands", 1418, 0.5, 0.5, nil, {}),
	P("zone", "Swamp of Sorrows", 1435, 0.5, 0.5, nil, { "sos" }),
	P("zone", "Blasted Lands", 1419, 0.5, 0.5, nil, {}),
	P("zone", "Arathi Highlands", 1417, 0.5, 0.5, nil, { "arathi" }),
	P("zone", "The Hinterlands", 1425, 0.5, 0.5, nil, { "hinterlands" }),
	P("zone", "Tirisfal Glades", 1420, 0.5, 0.5, nil, { "tirisfal" }),
	P("zone", "Silverpine Forest", 1421, 0.5, 0.5, nil, { "silverpine" }),
}

---------------------------------------------------------------------------
-- Names
---------------------------------------------------------------------------

-- A destination or service name made safe to show and to put in a whisper macro: only
-- letters, digits, spaces, ' and -, at most 32 bytes. "" when nothing is left.
function W.CleanDest(text)
	local s = W.Clean(W.Plain(text) or "", 96)
	s = s:gsub("[^%w '%-]", ""):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
	return (W.Clean(s, 32):gsub(" $", ""))
end

-- Lower case, apostrophes dropped, anything else that is not a letter or digit a single
-- space, no space at either end. "Light's Hope  Chapel!" -> "lights hope chapel".
function W.NormPlace(text)
	local s = str(text)
	if not s then return "" end
	s = s:lower():gsub("['`]", ""):gsub("\226\128\153", "") -- ' ` and the curly ’
	s = s:gsub("[^%a%d]+", " "):gsub("^ +", ""):gsub(" +$", "")
	return s
end

-- Every name (normalised) -> its place. The first place to claim a name keeps it.
local byName = {}
for _, p in ipairs(W.PLACES) do
	local own = W.NormPlace(p.name)
	if own ~= "" and not byName[own] then byName[own] = p end
	for i, n in ipairs(p.names) do
		n = W.NormPlace(n)
		p.names[i] = n
		if n ~= "" and not byName[n] then byName[n] = p end
	end
end

-- The place a name belongs to exactly (any of its names, "the" in front or not), or nil.
local function exact(text)
	local n = W.NormPlace(text)
	if n == "" then return nil end
	return byName[n] or byName[(n:gsub("^the ", ""))] or byName["the " .. n]
end
W.ExactPlace = exact

-- The place a rider means: an exact name first ("uc", "Booty Bay"), then the first place
-- with a name that starts with what was typed (three letters or more: "gadg"). nil if none.
function W.FindPlace(text)
	local hit = exact(text)
	if hit then return hit end
	local n = W.NormPlace(text)
	if #n < 3 then return nil end
	for _, p in ipairs(W.PLACES) do
		if W.NormPlace(p.name):sub(1, #n) == n then return p end
	end
	for _, p in ipairs(W.PLACES) do
		for _, alias in ipairs(p.names) do
			if alias:sub(1, #n) == n then return p end
		end
	end
	return nil
end

-- Places for a search box: the exact match first, then names that start with the text,
-- then names that contain it. At most `max` (default 8). Empty text: an empty list.
function W.SearchPlaces(text, max)
	max = num(max) or 8
	local out, seen = {}, {}
	local n = W.NormPlace(text)
	if n == "" then return out end
	local function add(p)
		if p and not seen[p] and #out < max then
			seen[p] = true
			out[#out + 1] = p
		end
	end
	add(exact(text))
	for pass = 1, 2 do
		for _, p in ipairs(W.PLACES) do
			local names = { W.NormPlace(p.name) }
			for _, a in ipairs(p.names) do names[#names + 1] = a end
			for _, a in ipairs(names) do
				local at = a:find(n, 1, true)
				if (pass == 1 and at == 1) or (pass == 2 and at) then
					add(p)
					break
				end
			end
		end
	end
	return out
end

---------------------------------------------------------------------------
-- Positions
---------------------------------------------------------------------------

local NEAR = 0.08

-- The place at (x, y) on map `mapID`: on a city's own map, the city wherever you stand;
-- otherwise the nearest town or dungeon on that map within 0.08, or nil. Zones are never
-- returned (a whole zone is not a summon spot).
function W.PlaceAt(mapID, x, y)
	mapID, x, y = num(mapID), num(x), num(y)
	if not (mapID and x and y) then return nil end
	local best, bestD
	for _, p in ipairs(W.PLACES) do
		if p.mapID == mapID and p.kind ~= "zone" then
			if p.kind == "city" then return p end
			local dx, dy = p.x - x, p.y - y
			local d = math.sqrt(dx * dx + dy * dy)
			if d <= NEAR and (not bestD or d < bestD) then best, bestD = p, d end
		end
	end
	return best
end

local function call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if not ok then return nil end
	return a, b, c
end

-- The player's map and position on it: mapID, x, y (any may be nil, e.g. in an instance).
function W.MyPosition()
	local CM = C_Map
	if type(CM) ~= "table" then return nil end
	local mapID = num(call(CM.GetBestMapForUnit, "player"))
	if not mapID then return nil end
	local pos = call(CM.GetPlayerMapPosition, mapID, "player")
	if pos == nil or W.Plain(pos) == nil then return mapID end
	local ok, x, y = pcall(function() return pos:GetXY() end)
	if not ok then return mapID end
	return mapID, num(x), num(y)
end

-- Where the player stands, as a destination: the subzone if it is a place ("Ratchet"),
-- else the place at the player's map position, else the zone (its place name if it is
-- one), else the map's name. Returns name (always a string), place (or nil).
function W.DestHere()
	local sub = str(call(GetSubZoneText))
	local p = sub and exact(sub)
	if p and p.kind ~= "zone" then return p.name, p end
	local mapID, x, y = W.MyPosition()
	p = W.PlaceAt(mapID, x, y)
	if p then return p.name, p end
	local zone = str(call(GetRealZoneText)) or str(call(GetZoneText))
	if zone then
		p = exact(zone)
		if p then return p.name, p end
		local clean = W.CleanDest(zone)
		if clean ~= "" then return clean, nil end
	end
	if mapID and type(C_Map) == "table" then
		local info = call(C_Map.GetMapInfo, mapID)
		local name = type(W.Plain(info)) == "table" and str(info.name)
		name = name and W.CleanDest(name)
		if name and name ~= "" then return name, nil end
	end
	return "Unknown", nil
end

-- Whether two destination names mean the same place ("UC" and "Undercity").
function W.SamePlace(a, b)
	local na, nb = W.NormPlace(a), W.NormPlace(b)
	if na == "" or nb == "" then return false end
	if na == nb then return true end
	local pa, pb = exact(a), exact(b)
	return pa ~= nil and pa == pb
end
