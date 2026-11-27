-- SYNTHETIC stand-in for a WuberProbe SavedVariables file (no real game run made it): one passive blocked-log row, the shape
-- WuberProbe (run.blocked) and the Lab (L13.blocked) write. Job 2894 turns it into measured-blocked.lua with
--   lua5.1 tools/rec/probe-import.lua --file tests/fixtures/probe/SYNTHETIC-blocked-run.lua --out <scratch folder> --source sim --blocked-out tests/fixtures/probe/measured-blocked.lua
-- Replace it by a real run (tools/rec/probe-import.lua --wtf <WTF folder> --blocked-out ...) as soon as the game has logged one.
WuberProbeDB = { runs = { {
	id = "synthetic-blocked-1", build = "71037", v = "sim", why = "synthetic blocked row",
	p = {},
	blocked = { { event = "ADDON_ACTION_BLOCKED", addon = "WuberLabBar", func = "ReloadUI", combat = false, click = false } },
	blockedN = 1,
} } }
