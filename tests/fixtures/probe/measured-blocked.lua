-- measured-blocked.lua: made by tools/rec/probe-import.lua --blocked-out from the passive blocked log (WuberProbe run.blocked, the Lab's L13.blocked).
-- One row per function the client refused: kind BLOCKED or FORBIDDEN, in combat or not, from a click handler (click = true), not from one (false) or not known (nil), the build.
-- tests/surface-guard.lua turns a row into evidence = "measured:<build>" for that curated name. Do not edit by hand.
return { format = 1, rows = {
	{ fn = "ReloadUI", kind = "BLOCKED", combat = false, click = false, build = "71037" },
} }
