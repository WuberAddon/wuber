-- SYNTHETIC stand-in for the taint and combat-lockdown part of a WuberProbe run (job 2908): invented answers, NOT real client data (source = "sim",
-- so the evidence ledger never counts it as measured, and tools/rec/taint-compare.lua says NOT MEASURED). It is what tests/lib/probe_learn.lua
-- L.protectRule would learn from a real run in which a plain frame under or anchored to a secure frame is protected too, and CreateFrame under a protected
-- parent is refused in a fight. Replace by a real run: tools/rec/probe-import.lua --wtf <WTF folder> (the fixture then carries protect, taintSweep,
-- protectCombat and dummy from WuberProbe's sweep, protprop, combat and dummy probes). The harness never loads this file by itself.
return {
	format = 1, kind = "probe", source = "sim", id = "synthetic-protect", build = "71037",
	protect = {
		S = { prot = true, explicit = true },
		kid = { prot = true, explicit = false },
		tied = { prot = true, explicit = false },
		ctl = { prot = false, explicit = false },
		box = { prot = true, explicit = false },
	},
	protectCombat = {
		{ tag = "start", lock = true, frames = { S = { prot = true, explicit = true, shown = true }, kid = { prot = true, explicit = false, shown = true }, ctl = { prot = false, explicit = false, shown = true } } },
	},
	dummy = {
		control = { { at = "out of combat", op = "S:Show", ok = true, took = true }, { at = "out of combat", op = "S:CreateFrame", ok = true, took = true } },
		fight = {
			{ at = "0.3 s", op = "S:Show", ok = true, took = false },
			{ at = "0.3 s", op = "S:Hide", ok = true, took = false },
			{ at = "0.3 s", op = "S:SetPoint", ok = true, took = false },
			{ at = "0.3 s", op = "S:SetParent", ok = true, took = false },
			{ at = "0.3 s", op = "S:SetAttribute", ok = true, took = false },
			{ at = "0.3 s", op = "S:CreateFrame", ok = false, took = nil, err = "ADDON_ACTION_BLOCKED" },
			{ at = "0.3 s", op = "kid:Hide", ok = true, took = false },
			{ at = "0.3 s", op = "ctl:Hide", ok = true, took = true },
		},
		ended = "10 s", blockedRows = 7,
	},
	taintSweep = { has = true, n = 6, rows = {
		UIParent = true, WorldFrame = true, TradeFrame = "Wuber", GameTooltip = "SomeOtherAddon", C_Map = true, ["WorldMapFrame.Show"] = "<nil>",
	} },
}
