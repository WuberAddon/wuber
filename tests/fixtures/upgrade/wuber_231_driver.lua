-- Saved variables of Wuber 2.3.1 (before the 2.3.2 public-invite switch, with Simple mode already
-- chosen), a driver with options of his own. Built by hand and scrubbed: neutral names only.
-- Loaded by tests/upgrade/upgrade_saved_vars.lua.
WuberDB = {
	["ruleset"] = "EU-PvE",
	["advanced"] = true,
	["progressReady"] = true,
	["scale"] = 1.4,
	["scaleV"] = 2,
	["flightsV"] = 3,
	["fx"] = "off",
	["timeValue"] = 40000,
	["favs"] = { ["riderone"] = true },
	["rides"] = {
		{ ["at"] = 1763000000, ["driver"] = "Driverone", ["driverKey"] = "driverone", ["dest"] = "Stormwind", ["price"] = 9000 },
	},
	["totals"] = { ["rides"] = 1, ["spent"] = 9000, ["saved"] = 0, ["savedValue"] = 0, ["places"] = { ["stormwind"] = true }, ["placeCount"] = 1, ["drivers"] = { ["driverone"] = { ["name"] = "Driverone", ["n"] = 1 } }, ["firstAt"] = 1763000000, ["lastAt"] = 1763000000 },
	["flights"] = {
		["H|orgrimmar|ratchet"] = { ["c"] = 4200, ["at"] = 1762000000, ["t"] = 250, ["tat"] = 1762000000, ["tsrc"] = "own" },
	},
	["chars"] = {
		["wuber testcharacter"] = { ["drive"] = false, ["price"] = 12000, ["service"] = "Driverone Lifts", ["dest"] = "Stormwind", ["destWords"] = "sw, stormy", ["caster"] = "Drivertwo", ["wizard"] = true },
	},
	["drive"] = {
		["v"] = 1,
		["opts"] = { ["autoPublic"] = true, ["watchPublic"] = false, ["autoInvite"] = false, ["adEvery"] = 45, ["lowShards"] = 8, ["inviteCap"] = 5, ["adChannels"] = "trade", ["helpSeen"] = "ab" },
		["blocklist"] = { ["pestone"] = { ["name"] = "Pestone" } },
		["stats"] = { ["rides"] = 40, ["copper"] = 360000, ["tips"] = 9000 },
		["bell"] = { ["name"] = "Driverone", ["team"] = {}, ["lead"] = "", ["service"] = "Driverone Lifts", ["count"] = 3 },
		["button"] = { ["scale"] = 1.3, ["sizeSet"] = true, ["locked"] = true, ["shown"] = true, ["keepClosed"] = false },
	},
}
