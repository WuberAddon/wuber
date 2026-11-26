-- The surface guard's standing allow list (tests/surface-guard.lua, runtime kinds) and the static pass's (tools/surface/static-surface.lua, keys "static:KIND:name@file").
-- Each entry: { "<kind>:<name>", "why this is not a bug" }. Runtime kinds: U undocumented, P protected, K secret accessor, S secret argument, C combat, H hardware click.
-- An entry with no reason is an error. Do not allow a real bug: fix the addon. The old unblocked reload call is NOT here: it was fixed.
-- A static entry is checked both ways by tests/surface/static_surface_test.lua: a finding with no entry fails, an entry that matches nothing fails.
return {
	-- GetScript is a ConstSecretAccessor method (docs) but it was never measured to answer a secret; the runtime guard's default list is only IsEventRegistered and GetAttribute.
	{ "static:B4:GetScript@Wuber/UI/Rider/Cards.lua", "c is the card frame Wuber built itself (overCard(f, c)): never a game frame, so GetScript is not secret there" },
	{ "static:B4:GetScript@Wuber/UI/Secure.lua", "pill is Wuber's own secure pill (b.pill): never a game frame, so GetScript is not secret there" },
	{ "static:B4:GetScript@lab/WuberLab/AutoSteps2.lua", "Lab only (never shipped): type(h) is checked first and GetScript on a game frame was never measured secret; revisit when the probe measures it" },
	{ "static:B4:GetScript@lab/WuberLab/AutoSteps7.lua", "Lab only (never shipped): type(h) is checked first and GetScript on a game frame was never measured secret; revisit when the probe measures it" },
}
