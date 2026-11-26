-- The real flight maps of a Horde character on WoW Forever 1.60.1 (the flight recorder, lane B2; facts
-- taxi.numnodes, taxi.reachable, taxi.positions, taxi.nodeids in lab-real-facts.lua). Verbatim sources:
--   * how many nodes: the test addon's probe lines "flight map: N of M nodes reachable" (20 opens):
--       Wuber Rocks at Thunder Bluff 21 Nov 00:05:56 "0 of 22", 00:08:28 to 00:10:51 "1 of 22" (11 opens),
--       Anita Lift at Orgrimmar 21 Nov 00:02:36 "3 of 22", Wuber Rocks at Undercity 19 Nov 21:27:31 "0 of 14"
--   * positions: WuberDB.mapCal[1].pts (Kalimdor, 21 nodes, written 21 Nov 00:12) and mapCal[0].pts
--       (Eastern Kingdoms, 13 nodes), TaxiNodePosition rounded to 5 places, keyed by node id
--   * node ids: WuberDB.flightNodes.H (27 ids, from C_TaxiMap on the real client) and the mapCal keys
--   * names: as the game spells them, from the client's own TaxiNodes table (ref/flightdata/TaxiNodes.csv,
--       Name_lang; the recording keeps only Wuber's lower-case place keys, e.g. 69 -> "nighthaven")
--   * costs: WuberDB.flights (copper, own: read with TaxiNodeCost at a flight master on that account):
--       H|thunder bluff|orgrimmar 50, H|orgrimmar|crossroads 99, H|orgrimmar|ratchet 0,
--       H|orgrimmar|camp taurajo 0, H|camp taurajo|crossroads 110, H|camp taurajo|ratchet 0,
--       H|camp taurajo|orgrimmar 0
-- Not recorded, so chosen here (each says so): the order of the nodes (here by id), the type word of a
-- node that is not REACHABLE or CURRENT (the addon counted REACHABLE only: here "NONE"), the 22nd
-- Kalimdor node (63 Nighthaven: in flightNodes.H but with no position, so 0, 0), the 14th Eastern
-- Kingdoms node (unknown: left out, so the fake's Eastern Kingdoms map has 13).
return {
	Kalimdor = {
		mapID = 1414, recordedNodes = 22,
		nodes = {
			{ id = 22, name = "Thunder Bluff, Mulgore", x = 0.44948, y = 0.56151 },
			{ id = 23, name = "Orgrimmar, Durotar", x = 0.62801, y = 0.4434 },
			{ id = 25, name = "Crossroads, The Barrens", x = 0.55736, y = 0.53048 },
			{ id = 29, name = "Sun Rock Retreat, Stonetalon Mountains", x = 0.40796, y = 0.47261 },
			{ id = 30, name = "Freewind Post, Thousand Needles", x = 0.54989, y = 0.7345 },
			{ id = 38, name = "Shadowprey Village, Desolace", x = 0.3166, y = 0.58495 },
			{ id = 40, name = "Gadgetzan, Tanaris", x = 0.60601, y = 0.80193 },
			{ id = 42, name = "Camp Mojache, Feralas", x = 0.44251, y = 0.69391 },
			{ id = 44, name = "Valormok, Azshara", x = 0.63108, y = 0.36189 },
			{ id = 48, name = "Bloodvenom Post, Felwood", x = 0.46455, y = 0.30409 },
			{ id = 53, name = "Everlook, Winterspring", x = 0.64014, y = 0.23241 },
			{ id = 55, name = "Brackenwall Village, Dustwallow Marsh", x = 0.56747, y = 0.64163 },
			{ id = 58, name = "Zoram'gar Outpost, Ashenvale", x = 0.40974, y = 0.37368 },
			{ id = 61, name = "Splintertree Post, Ashenvale", x = 0.55442, y = 0.41773 },
			{ id = 63, name = "Nighthaven, Moonglade" },
			{ id = 69, name = "Moonglade", x = 0.53794, y = 0.20541 },
			{ id = 72, name = "Cenarion Hold, Silithus", x = 0.41632, y = 0.79217 },
			{ id = 77, name = "Camp Taurajo, The Barrens", x = 0.52805, y = 0.61013 },
			{ id = 79, name = "Marshal's Refuge, Un'Goro Crater", x = 0.49765, y = 0.76351 },
			{ id = 80, name = "Ratchet, The Barrens", x = 0.60571, y = 0.54908 },
			{ id = 559, name = "Summit of Eternity, Mount Hyjal", x = 0.58655, y = 0.29527 },
			{ id = 3242, name = "Tainted Foothills, Mount Hyjal", x = 0.56723, y = 0.33182 },
		},
	},
	["Eastern Kingdoms"] = {
		mapID = 1415, recordedNodes = 14,
		nodes = {
			{ id = 10, name = "The Sepulcher, Silverpine Forest", x = 0.38448, y = 0.2449 },
			{ id = 11, name = "Undercity, Tirisfal", x = 0.44268, y = 0.19491 },
			{ id = 13, name = "Tarren Mill, Hillsbrad", x = 0.49442, y = 0.26687 },
			{ id = 17, name = "Hammerfall, Arathi", x = 0.6154, y = 0.30891 },
			{ id = 18, name = "Booty Bay, Stranglethorn", x = 0.43159, y = 0.92954 },
			{ id = 20, name = "Grom'gol, Stranglethorn", x = 0.44826, y = 0.83641 },
			{ id = 21, name = "Kargath, Badlands", x = 0.55499, y = 0.57122 },
			{ id = 56, name = "Stonard, Swamp of Sorrows", x = 0.60542, y = 0.74662 },
			{ id = 68, name = "Light's Hope Chapel, Eastern Plaguelands", x = 0.69752, y = 0.16009 },
			{ id = 70, name = "Flame Crest, Burning Steppes", x = 0.55533, y = 0.61114 },
			{ id = 75, name = "Thorium Point, Searing Gorge", x = 0.50544, y = 0.5676 },
			{ id = 76, name = "Revantusk Village, The Hinterlands", x = 0.67154, y = 0.29602 },
			{ id = 3203, name = "Rog'mar, Riverglades", x = 0.6744, y = 0.6304 },
		},
	},
	-- [from town][to town] = copper (TaxiNodeCost as recorded; 0 is a real answer)
	costs = {
		["Thunder Bluff"] = { Orgrimmar = 50 },
		Orgrimmar = { Crossroads = 99, Ratchet = 0, ["Camp Taurajo"] = 0 },
		["Camp Taurajo"] = { Crossroads = 110, Ratchet = 0, Orgrimmar = 0 },
	},
	-- what the probe lines saw (who, where, reachable, nodes)
	seen = {
		{ who = "Wuber Rocks", at = "21 Nov 00:05:56", here = "Thunder Bluff", reach = 0, nodes = 22 },
		{ who = "Wuber Rocks", at = "21 Nov 00:08:28", here = "Thunder Bluff", reach = 1, nodes = 22, known = { "Orgrimmar" } },
		-- (which 3: inferred from the three own costs read at Orgrimmar, above)
		{ who = "Anita Lift", at = "21 Nov 00:02:36", here = "Orgrimmar", reach = 3, nodes = 22, known = { "Crossroads", "Ratchet", "Camp Taurajo" } },
		{ who = "Wuber Rocks", at = "19 Nov 21:27:31", here = "Undercity", reach = 0, nodes = 14 },
	},
	-- the frame (fact taxi.frame and SHOT-FACTS.md): TaxiFrame showed (Anita Lift 20 Nov "bird: the flight map
	-- is TaxiFrame"); measured on two screenshots of 21 Nov at about 603 x 638 UI units, top left 16, -118 of
	-- the screen (an estimate, about 2 percent, from 893 x 945 pixels at 1.97 pixels a unit)
	frame = { name = "TaxiFrame", w = 603, h = 638, x = 16, y = -118 },
}
