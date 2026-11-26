-- Surface guard: what the guard (tests/surface-guard.lua, on only with WUBER_SURFACE=1) refuses. Each test passes when the guard catches
-- the old pattern. Without the guard the tests are skipped: the same calls go through silently, which is the gap the real game showed.
-- Fixture addon: tests/fixtures/surface/WuberFxOld (old code shapes, not Wuber code).
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local DIR = H.root .. "/tests/fixtures/surface/WuberFxOld"
H.ADDONS.WuberFxOld = DIR

local function mk(opts)
	local w = T.newWorld()
	opts = opts or {}
	local c = w:addClient("Test Pilot", { spot = "Orgrimmar", class = "WARLOCK", addons = { "WuberFxOld" }, allowMissing = true,
		prepare = function(env) env.WuberNoSuchApi = function() return 1 end env.CastSpellByName = function() end env.C_Map.NoSuchThing = function() return 1 end end })
	T.settle(w)
	return w, c
end
-- the guard's lines among the violations, and then forget them (these tests do not end in clean)
local function took(w)
	local out = {}
	for i = #w.violations, 1, -1 do
		local v = w.violations[i]
		if v:find("(surface guard)", 1, true) then table.insert(out, 1, v) end
		w.violations[i] = nil
	end
	return out
end
local function has(list, text) for _, v in ipairs(list) do if v:find(text, 1, true) then return true end end return false end
local GUARD = H.surface ~= nil
local function need(name, fn) test(name .. (GUARD and "" or " (guard off: skipped)"), function() if GUARD then fn() end end) end

need("surface B4: IsEventRegistered on a Blizzard frame is refused when compared straight away (AutoKeys.lua:108 shape)", function()
	local w, c = mk()
	c.env.WuberFxOld.B4old(c.env.UIParent)
	local got = took(w)
	ok(has(got, "IsEventRegistered"), "the old B4 line is reported: " .. table.concat(got, " | "))
	ok(has(got, "Old.lua:"), "with the file and line")
end)
need("surface B4: the fixed form (issecretvalue first) is quiet", function()
	local w, c = mk()
	c.env.WuberFxOld.B4fixed(c.env.UIParent)
	eq(#took(w), 0, "no hit for the fixed lab code")
end)
need("surface B5: ReloadUI from a C_Timer callback (WuberLabBar Bar.lua:247 shape) is refused", function()
	local w, c = mk()
	c.env.WuberFxOld.B5timer()
	w:advance(1)
	local got = took(w)
	ok(has(got, "ReloadUI() is protected"), "reported: " .. table.concat(got, " | "))
end)
need("surface B5: ReloadUI fetched by rawget(_G) and pcalled (GameFacts2.lua shape) is refused", function()
	local w, c = mk()
	c.env.WuberFxOld.B5gamefacts()
	ok(has(took(w), "ReloadUI() is protected"), "reported")
end)
need("surface B5: ReloadUI in a click handler is refused too (a hardware click does not unblock it)", function()
	local w, c = mk()
	local b = c.env.WuberFxOld.B5button()
	c:click(b) -- direct-click: judges the click-handler call shape, not the hit test
	ok(has(took(w), "ReloadUI() is protected"), "reported")
end)
-- Job 2894: P / H / C hits on curated entries whose evidence is only "brief" are LEADS (kind L), never violations; the measured and docs ones fail
-- (tests/surface/guard_evidence_test.lua). These three tests keep the old shapes seen, now as leads.
local function nLeads(name) local n = 0 for _, h in ipairs(H.surface.hits) do if h.kind == "L" and h.name == name then n = n + 1 end end return n end
need("surface: the hardware-click rule (H) is ON by default: InviteUnit outside a click is a lead, inside a click it is quiet", function()
	ok(H.surface.hw, "H on")
	local w, c = mk()
	local before = nLeads("InviteUnit")
	c.env.WuberFxOld.Invite()
	eq(#took(w), 0, "a brief entry is not a violation")
	eq(nLeads("InviteUnit"), before + 1, "outside a click: a lead")
	local w2, c2 = mk()
	local b2 = c2.env.WuberFxOld.InviteButton()
	local mid = nLeads("InviteUnit")
	c2:click(b2) -- direct-click: judges the click-handler call shape, not the hit test
	eq(nLeads("InviteUnit"), mid, "inside a click: quiet")
end)
need("surface: SetCVar is a lead in combat only", function()
	local w, c = mk()
	local before = nLeads("SetCVar")
	c.env.WuberFxOld.CVar()
	eq(nLeads("SetCVar"), before, "out of combat: quiet")
	c.player.combat = true
	c.env.WuberFxOld.CVar()
	eq(nLeads("SetCVar"), before + 1, "in combat: a lead")
	eq(#took(w), 0, "never a violation while it is brief")
end)
need("surface: CastSpellByName (curated never, brief) is a lead from addon code", function()
	local w, c = mk()
	local before = nLeads("CastSpellByName")
	pcall(c.env.WuberFxOld.Macro)
	eq(nLeads("CastSpellByName"), before + 1, "a lead")
	eq(#took(w), 0, "not a violation")
end)
need("surface: an API the docs do not list (and Blizzard code never calls) is refused, a guarded one is not", function()
	local w, c = mk()
	c.env.WuberFxOld.Undoc()
	ok(has(took(w), "WuberNoSuchApi is not in the API docs"), "undocumented global reported")
	local w2, c2 = mk()
	c2.env.WuberFxOld.UndocGuarded()
	eq(#took(w2), 0, "behind type() == function: quiet")
	pcall(c2.env.WuberFxOld.UndocNs)
	ok(has(took(w2), "C_Map.NoSuchThing"), "undocumented C_ function reported")
end)
need("surface: a secret value given to a SecretArguments=NotAllowed function is reported", function()
	local w, c = mk()
	pcall(c.env.WuberFxOld.SecretArg, H.SECRET)
	ok(has(took(w), "given a secret value"), "reported")
end)
need("surface: a tail call (return F()) from a callback is still judged, line unknown", function()
	local w, c = mk()
	local b = c.env.CreateFrame("Button", nil, c.env.UIParent)
	b:SetScript("OnClick", c.env.WuberFxOld.UndocTail)
	c:click(b) -- direct-click: judges the click-handler call shape, not the hit test
	ok(has(took(w), "WuberNoSuchApi is not in the API docs"), "reported")
end)
need("surface: the allow list needs a reason per line", function()
	for key, reason in pairs(H.surface.allow) do ok(type(reason) == "string" and #reason >= 10, "allow entry " .. key .. " has a reason") end
	local f = io.open(H.root .. "/tests/surface/allow.lua", "r")
	ok(f ~= nil, "tests/surface/allow.lua exists")
	if f then f:close() end
	for key in pairs(H.surface.allow) do ok(not key:find("ReloadUI", 1, true), "ReloadUI is never allowed: it was fixed, the guard must find nothing") end
end)
need("surface: the generated surface names its client build", function()
	local S = H.surface.S
	ok(type(S.meta.build) == "string" and S.meta.build:find("^%d+%.%d+%.%d+%.%d+$"), "build " .. tostring(S.meta.build))
	ok(S.curated.ReloadUI and S.curated.ReloadUI.mode == "never", "ReloadUI is curated as never")
	ok(S.ns.C_Timer and S.ns.C_Timer.After, "C_Timer.After is documented")
end)
need("surface: test code and the harness are never judged", function()
	local w, c = mk()
	c.env.ReloadUI() c.env.InviteUnit("x") pcall(c.env.WuberNoSuchApi)
	eq(#took(w), 0, "calls from the test itself are not addon code")
end)
