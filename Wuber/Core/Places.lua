-- Module: Core.Places
-- Purpose: the place table (W.PLACES), place names and search, positions, anti-spam for driver text, world
--   positions and travel time saved.
-- API: W.PLACES, W.CleanDest, W.NormPlace, W.ExactPlace, W.FindPlace, W.SearchPlaces, W.PlaceAt,
--   W.MyPosition, W.DestHere, W.SamePlace, W.ZoneHere, W.SPAM_WORDS, W.SpamReason, W.SentenceSpam,
--   W.CleanService,
--   W.ValidDest, W.WorldPos, W.PlaceWorld, W.CROSSINGS, W.SUMMON_SECS, W.TravelSaved, W.TimeValue
-- Internals: call, exact
-- Uses: Core.Words (W.Words, the blocked-word lists)
-- Later: (none)
-- Events: listens (none); fires (none)
-- Standalone: no
-- Test: tests/core/places_test.lua
-- From: Places.lua 1-547 (Wuber 2.2.1)
--
-- Places: the summon spots riders ask for. Each has the map it sits on (uiMapID) and where
-- on that map (x, y from 0 to 1), so a pin can be placed, plus the names riders type.
--
--   W.PLACES               the list (see the fields below)
--   W.NormPlace(text)      "Light's Hope" -> "lights hope"
--   W.FindPlace(text)      a place from what a rider typed ("uc", "org", "booty"), or nil
--   W.SearchPlaces(text)   every place that starts with / contains what was typed
--   W.PlaceAt(mapID, x, y) the place at a map position, or nil
--   W.DestHere()           where the player stands: its name, and the place if it is one
--   W.ValidDest(dest, mapID, x, y)  a driver's dest as riders may see it (anti-spam)
--   W.SPAM_WORDS, W.CleanService(text, fallbackName)  a driver's service name (anti-spam)
--   W.WorldPos(mapID, x, y) continent and world position of a map point (guarded)
--   W.TravelSaved(dest)    flying time a summon saves from here; W.TimeValue(seconds)
--   W.SUMMON_SECS          seconds a summon takes when the driver is ready (30): the one number the Fly or
--                          summon card and the bird card take off the flight
--   W.FlightCost(from, to), W.FlightTime(from, to), W.FlightInfo(dest)  real flight prices and
--                          flight times (Core.Flights: own, shared, else "est", the spline guess)
--
-- Coordinates are approximate: they only place a pin. Names must be right.

local _, W = ...
local Mod = W.Module("Core.Places", { "Core.Words" })

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
	P("town", "Auberdine", 1439, 0.370, 0.440, "Darkshore", {}),

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
	P("town", "Menethil Harbor", 1437, 0.100, 0.600, "Wetlands", { "menethil", "menethil harbour" }),

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
	-- Mount Hyjal (the game's own name; flight points "Summit of Eternity" and "Tainted Foothills" are in it). Its
	-- uiMapID in this client is not known from any source here, so none is guessed: no pin, found by name.
	P("zone", "Mount Hyjal", nil, 0.5, 0.5, nil, { "hyjal", "mt hyjal", "hyjal summit" }),
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

-- The zone the player is in ("The Barrens"), for the trip history. Never nil.
function W.ZoneHere()
	local zone = str(call(GetRealZoneText)) or str(call(GetZoneText))
	zone = zone and W.CleanDest(zone)
	if zone and zone ~= "" then return zone end
	return (W.DestHere())
end

---------------------------------------------------------------------------
-- Anti-spam: what a driver's free text may show riders
---------------------------------------------------------------------------

-- The word lists live in Core/Words.lua (W.Words.BLOCKED = W.SPAM_WORDS, ANYWHERE, ALLOWED_PLACES): edit them
-- there. They are read on every check.
local function spamSet()
	local set = {}
	for _, w in ipairs(W.Words.BLOCKED) do
		if type(w) == "string" and w ~= "" then set[w:lower()] = true end
	end
	return set
end

local function isSpamWord(set, word)
	if word == "" then return false end
	if set[word] then return true end
	return #word > 3 and word:sub(-1) == "s" and set[word:sub(1, -2)] == true
end

-- Why a service name is refused ("word", "digits", "letters", "link"), or nil if it is fine.
-- Whole words only, so "Orgrimmar Express", "Goldshire Cabs" and "Wuber Network" pass;
-- "g o l d" and "go ld" are caught by joining the short pieces.
local function spamReason(text, sentence)
	-- Core/Words.lua not loaded (a /reload after an update that added it): refuse, never a weaker check or an error
	local WD = W.Words
	if type(WD) ~= "table" or type(WD.BLOCKED) ~= "table" or type(WD.ANYWHERE) ~= "table" or type(WD.ALLOWED_PLACES) ~= "table" then return "word" end
	local low = tostring(W.Plain(text) or ""):lower()
	for _, w in ipairs(W.Words.ANYWHERE) do
		if low:find(w, 1, true) then return "link" end
	end
	if sentence then
		-- a place nickname (Org) in a driver's own sentence is no spam, unless written as an address (".org")
		for _, w in ipairs(W.Words.ALLOWED_PLACES) do
			if type(w) == "string" and w ~= "" then
				low = low:gsub("(.?)%f[%w]" .. w:lower():gsub("%p", "%%%0") .. "%f[%W]", function(pre)
					if pre == "." then return nil end
					return pre .. " "
				end)
			end
		end
	end
	low = low:gsub("[^%w '%-]", " ")
	if low:find("%d%d%d%d") then return "digits" end
	local set = spamSet()
	local singles, run, runCount = 0, "", 0
	local function endRun()
		if runCount >= 2 then
			if isSpamWord(set, run) then return true end
			for w in pairs(set) do
				if #w >= 4 and run:find(w, 1, true) then return true end
			end
		end
		run, runCount = "", 0
		return false
	end
	for token in low:gmatch("[^%s'%-]+") do
		if isSpamWord(set, token) then return "word" end
		if #token == 1 then singles = singles + 1 end
		if #token <= 2 then
			run, runCount = run .. token, runCount + 1
		elseif endRun() then
			return "word"
		end
	end
	if endRun() then return "word" end
	if singles >= 2 then return "letters" end
	local joined = low:gsub("[%s'%-]", "")
	if isSpamWord(set, joined) then return "word" end
	return nil
end

-- Why a whole sentence is refused ("word", "digits", "link"), or nil: W.SpamReason without its
-- "letters" rule, which is made for service names ("g o l d"): a sentence like "3 h 20 min
-- saved" or "a summon to Booty Bay" has short words on purpose. The names a sentence carries
-- (driver, service, place) still go through the word list; "Goldshire" and "Marigold" pass.
function W.SpamReason(text)
	return spamReason(text, false)
end

function W.SentenceSpam(text)
	local why = spamReason(text, true)
	if why == "letters" then return nil end
	return why
end

-- A driver's service name as riders may see it: letters, digits, spaces, ' and -, at most
-- 24 characters; a spammy one (W.SpamReason) or an empty one becomes `fallbackName` (the
-- driver's full name). Returns the name, and the reason when it was refused.
function W.CleanService(text, fallbackName)
	local raw = W.Clean(W.Plain(text) or "", 96)
	local why = W.SpamReason(raw)
	local s = raw:gsub("[^%w '%-]", ""):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
	s = W.Clean(s, 24):gsub(" $", "")
	if why or s == "" then
		local fb = W.CleanDest(fallbackName or "")
		if fb == "" then fb = "Driver" end
		return fb, why
	end
	return s, nil
end

-- A driver's destination as riders may see it: a known place (any of its names, compared
-- through W.NormPlace) shows as that place's name; the name of the driver's own map
-- (C_Map.GetMapInfo(mapID).name) shows as itself; anything else shows as the place at the
-- driver's position (W.PlaceAt), or "Unknown". Never free text.
-- Returns the name to show, and whether the text passed (so it may be whispered as is).
function W.ValidDest(dest, mapID, x, y)
	local d = W.CleanDest(dest)
	if d ~= "" then
		local p = exact(d)
		if p then return p.name, true end
	end
	mapID = num(mapID)
	if mapID and mapID > 0 then
		if d ~= "" and type(C_Map) == "table" then
			local info = W.Plain(call(C_Map.GetMapInfo, mapID))
			local name = type(info) == "table" and str(info.name) or nil
			if name then
				local n, nd = W.NormPlace(name), W.NormPlace(d)
				if n ~= "" and (n == nd or n == "the " .. nd or nd == "the " .. n) then
					local clean = W.CleanDest(name)
					if clean ~= "" then return clean, true end
				end
			end
		end
		local p = W.PlaceAt(mapID, x, y)
		if p then return p.name, false end
	end
	return "Unknown", false
end

---------------------------------------------------------------------------
-- World positions and the travel time a summon saves
---------------------------------------------------------------------------

local function vecXY(v)
	v = W.Plain(v)
	if v == nil then return nil end
	if type(v) == "table" or type(v) == "userdata" then
		local ok, a, b = pcall(function() if v.GetXY then return v:GetXY() end return v.x, v.y end)
		if ok then
			a, b = num(a), num(b)
			if a and b then return a, b end
		end
	end
	return nil
end

-- A map point (x, y 0..1 on uiMapID) in world terms: continentID, wx, wy (yards), and the
-- game's position vector (for C_Map.GetMapPosFromWorldPos). nil when the game can't say
-- (instances, unknown maps, secret values). Every call guarded.
function W.WorldPos(mapID, x, y)
	mapID, x, y = num(mapID), num(x), num(y)
	if not (mapID and x and y) or type(C_Map) ~= "table" or type(C_Map.GetWorldPosFromMapPos) ~= "function" then
		return nil
	end
	local vec
	if type(CreateVector2D) == "function" then
		local ok, v = pcall(CreateVector2D, x, y)
		if ok then vec = v end
	end
	if vec == nil then return nil end
	local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, vec)
	if not ok then return nil end
	cont, pos = num(cont), W.Plain(pos)
	if not cont or pos == nil then return nil end
	local wx, wy = vecXY(pos)
	if not wx then return nil end
	return cont, wx, wy, pos
end

-- A place's world position (worked out once, when first asked): continentID, wx, wy.
function W.PlaceWorld(p)
	if type(p) ~= "table" then return nil end
	local c = p.world
	if not c then
		local cont, wx, wy = W.WorldPos(p.mapID, p.x, p.y)
		if not cont then return nil end
		c = { cont, wx, wy }
		p.world = c
	end
	return c[1], c[2], c[3]
end

-- The flying model (SPEC2, "Travel time saved"):
--   flight time = straight distance (yards) x 1.35 / W.FLY.SPEED yards a second (30; Core.Flights, read at call time)
--   same continent:  60 s to reach a flight master + the flight
--   other continent: 60 s + flight to the port + 4 min boat or zeppelin + flight from the
--                    far port; the quickest crossing open to the rider's faction:
--                    Horde    Orgrimmar - Undercity, Orgrimmar - Grom'gol (zeppelins), Ratchet - Booty Bay (boat)
--                    Alliance Theramore - Menethil Harbor, Auberdine - Menethil Harbor, Ratchet - Booty Bay (boats)
--                    a crossing the game can't place: a flat 10 min in all
--   nil under about 400 yards or 2 minutes, and when a position can't be read; at most 40 min.
local CROSSINGS = {
	{ "Orgrimmar", "Undercity", "by zeppelin", H = true },
	{ "Orgrimmar", "Grom'gol", "by zeppelin", H = true },
	{ "Ratchet", "Booty Bay", "by boat", H = true },
	{ "Theramore", "Menethil Harbor", "by boat", A = true },
	{ "Auberdine", "Menethil Harbor", "by boat", A = true },
	{ "Ratchet", "Booty Bay", "by boat", A = true },
}
W.CROSSINGS = CROSSINGS
-- How long a summon takes once the driver is ready: the ritual cast (about 5 s), the summoning channel
-- (about 10 s) and the rider's accept click, with the group invite, plus a few seconds' reaction.
-- (Recorded rides with a ready driver: cast to arrival 18 s at the quickest, request to arrival 37 s with
-- one person working every window.) A busy driver's wait is its own.
W.SUMMON_SECS = 30
local ROUTE_FACTOR, TO_FLIGHT_MASTER, CROSSING = 1.35, 60, 240

local function flight(ax, ay, bx, by)
	local dx, dy = ax - bx, ay - by
	-- Core.Flights loads after this file, so the speed is read when called
	local speed = type(W.FLY) == "table" and tonumber(W.FLY.SPEED) or 30
	if speed <= 0 then speed = 30 end
	return math.sqrt(dx * dx + dy * dy) * ROUTE_FACTOR / speed
end

-- Seconds of flying a summon to `dest` (a place name) saves from where the player stands,
-- and how they would have gone: "same continent", "by boat" or "by zeppelin", or "est" (the
-- route time worked out from the game's flight splines, Core.FlightTimes); third: true when the flight
-- itself was measured (W.FlightTime "own" or "shared"). nil when it can't be known or isn't
-- worth saying. Every number but a measured one is a guess: callers say "about".
-- The spline estimate is used once the player's own flights calibrated it (3 flights,
-- W.db.flyCal); until then the straight-line model below, as in 2.2.
local function calibrated()
	local c = type(W.db) == "table" and W.db.flyCal or nil
	return type(c) == "table" and (num(c.n) or 0) >= 3 and num(c.ratio) ~= nil
end

function W.TravelSaved(dest)
	local place = exact(dest) or W.FindPlace(dest)
	if not place or W.InInstance() then return nil end
	-- a flight measured from here (by this account, or shared by another Wuber user) beats the
	-- speed model; the third value says so
	local measured, src = nil, nil
	if W.FlightTime then measured, src = W.FlightTime(nil, dest) end
	if measured and (src ~= "est" or calibrated()) then
		local s = TO_FLIGHT_MASTER + measured
		if s < 120 then return nil end
		if src == "est" then return math.floor(math.min(s, 2400) + 0.5), "est" end
		return math.floor(math.min(s, 2400) + 0.5), "same continent", true
	end
	local mapID, x, y = W.MyPosition()
	local rc, rx, ry = W.WorldPos(mapID, x, y)
	if not rc then return nil end
	local dc, dx, dy = W.PlaceWorld(place)
	if not dc then return nil end
	local seconds, how
	if rc == dc then
		local ddx, ddy = rx - dx, ry - dy
		if math.sqrt(ddx * ddx + ddy * ddy) < 400 then return nil end
		seconds, how = TO_FLIGHT_MASTER + flight(rx, ry, dx, dy), "same continent"
	else
		local faction = W.Faction and W.Faction() or ""
		for _, c in ipairs(CROSSINGS) do
			if faction == "" or c[faction] then
				local pa, pb = exact(c[1]), exact(c[2])
				local ac, ax, ay = W.PlaceWorld(pa)
				local bc, bx, by = W.PlaceWorld(pb)
				if ac and bc and ac ~= bc then
					if bc == rc and ac == dc then -- the other way round
						ac, ax, ay, bc, bx, by = bc, bx, by, ac, ax, ay
					end
					if ac == rc and bc == dc then
						local t = TO_FLIGHT_MASTER + flight(rx, ry, ax, ay) + CROSSING + flight(bx, by, dx, dy)
						if not seconds or t < seconds then seconds, how = t, c[3] end
					end
				end
			end
		end
		if not seconds then seconds, how = 600, "by boat" end
	end
	if seconds < 120 then return nil end
	return math.floor(math.min(seconds, 2400) + 0.5), how
end

-- Seconds of the player's time in copper, at "My time is worth" (W.db.timeValue, copper an
-- hour; 10g/h by default). Rounded to whole silver from 1g up.
function W.TimeValue(seconds)
	seconds = num(seconds)
	if not seconds or seconds <= 0 then return 0 end
	local rate = num(W.db and W.db.timeValue) or 100000
	local v = seconds * rate / 3600
	if v >= 10000 then return math.floor(v / 100 + 0.5) * 100 end
	return math.floor(v + 0.5)
end

-- exports (REFACTOR-MAP section 2)
Mod.call, Mod.exact = call, exact
