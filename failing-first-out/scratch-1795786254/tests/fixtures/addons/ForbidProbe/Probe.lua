-- Test fixture (tests/tools/forbidden_test.lua): an addon that touches what this client forbids
-- (tools/forbidden.lua), each time under its own pcall, as a careful addon would: the error is
-- swallowed, so only the harness can tell. Nothing runs until ForbidProbeGo() is called.
-- extra: { { kind = "event" | "api" | "method", name = s, path = { ... } }, ... } (a longer list)
ForbidProbeLog = {}
function ForbidProbeGo(extra)
	local f = CreateFrame("Frame")
	local function try(what, fn, ...)
		local okc, err = pcall(fn, ...)
		ForbidProbeLog[#ForbidProbeLog + 1] = { what = what, ok = okc, err = tostring(err) }
	end
	try("RegisterEvent", f.RegisterEvent, f, "COMBAT_LOG_EVENT_UNFILTERED")
	try("UnregisterEvent", f.UnregisterEvent, f, "COMBAT_LOG_EVENT_UNFILTERED")
	try("CombatLogGetCurrentEventInfo", CombatLogGetCurrentEventInfo)
	if C_Club then try("SendCharacterInvitation", C_Club.SendCharacterInvitation, 1, "Bob Stone") end
	try("RegisterAllEvents", f.RegisterAllEvents, f)
	for _, e in ipairs(extra or {}) do
		if e.kind == "event" then
			try(e.name, f.RegisterEvent, f, e.name)
		elseif e.kind == "api" then
			local v = _G
			for _, k in ipairs(e.path) do v = type(v) == "table" and v[k] or nil end
			try(e.name, v)
		elseif e.kind == "method" then
			try(e.name, f[e.name], f)
		end
	end
end
