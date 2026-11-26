-- Saved variables of an older Wuber (2.2 era: before Simple mode, before the scale and Enhanced Flight Map
-- migrations), a rider with settings of his own. Built by hand from that version's shapes and scrubbed:
-- neutral names only. Loaded by tests/upgrade/upgrade_saved_vars.lua.
WuberDB = {
	["ruleset"] = "EU-PvE",
	["minimapAngle"] = 90,
	["minimapHidden"] = true,
	["sound"] = false,
	["mapPins"] = false,
	["scale"] = 1,
	["lastDest"] = "Undercity",
	["fx"] = "light",
	["plates"] = false,
	["timeValue"] = 250000,
	["coach"] = true,
	["tipsOn"] = false,
	["autoAccept"] = false,
	["autoLeave"] = false,
	["advertOnline"] = false,
	["openMapHint"] = true,
	["reduceMotion"] = true,
	["favs"] = { ["driverone"] = true },
	["watch"] = { ["thunder bluff"] = true },
	["hidden"] = { ["driverthree"] = true },
	["milestones"] = { ["first_ride"] = 1762000000 },
	["tipsSeen"] = { ["welcome"] = true },
	["rides"] = {
		{ ["at"] = 1762000000, ["driver"] = "Driverone", ["driverKey"] = "driverone", ["dest"] = "Undercity", ["price"] = 5000, ["stars"] = 5, ["saved"] = 300, ["savedValue"] = 8000, ["fromZone"] = "Orgrimmar" },
		{ ["at"] = 1762100000, ["driver"] = "Drivertwo", ["driverKey"] = "drivertwo", ["dest"] = "Thunder Bluff", ["price"] = 3000, ["stars"] = 4, ["saved"] = 200, ["savedValue"] = 5000, ["fromZone"] = "Orgrimmar" },
		{ ["at"] = 1762200000, ["driver"] = "Driverone", ["driverKey"] = "driverone", ["dest"] = "Undercity", ["price"] = 5000, ["unpaid"] = true },
	},
	["flights"] = {
		["H|orgrimmar|ratchet"] = { ["c"] = 4200, ["at"] = 1762000000, ["t"] = 260, ["tat"] = 1762000000, ["tsrc"] = "efm" },
		["H|undercity|tarren mill"] = { ["c"] = 1500, ["at"] = 1762000000 },
	},
	["chars"] = {
		["wuber testcharacter"] = { ["price"] = 7500, ["service"] = "Riderone Rides", ["dest"] = "Undercity", ["paused"] = true },
	},
	["drive"] = {
		["v"] = 1,
		["opts"] = { ["autoPublic"] = true, ["adEvery"] = 30, ["lowShards"] = 6, ["whisperMode"] = "macro", ["maxGroup"] = 12 },
		["stats"] = { ["rides"] = 12, ["copper"] = 60000, ["tips"] = 2000 },
	},
}
