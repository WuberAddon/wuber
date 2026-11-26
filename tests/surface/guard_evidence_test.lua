-- Job 2894: the surface guard learns its blocked and hardware lists from real data.
--   1. tools/rec/probe-import.lua turns the passive blocked log into tests/fixtures/probe/measured-blocked.lua (rows: fn, kind, combat, click, build)
--   2. every curated entry has evidence = "measured:<build>" | "docs" | "brief"; only measured and docs hits fail a test, "brief" ones are leads (kind L)
--   3. the H rule (hardware click) is ON by default
--   4. PROOF: the row "ReloadUI, blocked, not from a click" makes the old WuberLabBar timer shape (B5) fail as measured
--   5. a call through a thin wrapper (callm, T.Call, pcall) is judged at the next Wuber frame up
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local DIR = H.root .. "/tests/fixtures/surface/WuberFxOld"
H.ADDONS.WuberFxOld = DIR
local GUARD = H.surface ~= nil
local function need(name, fn) test(name .. (GUARD and "" or " (guard off: skipped)"), function() if GUARD then fn() end end) end

-- 1. the importer (runs with or without the guard) ---------------------------------------------------------------------
local PI = assert(loadfile(H.root .. "/tools/rec/probe-import.lua"))("--lib")
test("probe-import blocked rows: a BLOCKED log row becomes fn, kind, combat, click, build", function()
	local rows = PI.blockedRows({ build = "71037", blocked = { { event = "ADDON_ACTION_BLOCKED", addon = "A", func = "ReloadUI", combat = false, click = false } } })
	eq(#rows, 1, "one row")
	eq(rows[1].fn, "ReloadUI") eq(rows[1].kind, "BLOCKED") eq(rows[1].combat, false) eq(rows[1].click, false) eq(rows[1].build, "71037")
end)
test("probe-import blocked rows: FORBIDDEN, the Lab's L13 list, unknown click = nil, junk dropped", function()
	local rows = PI.blockedRows({ build = "1", blocked = { { event = "ADDON_ACTION_FORBIDDEN", func = "C_Club.X", combat = true }, "junk", { event = "ADDON_ACTION_BLOCKED" } },
		l13 = { { event = "ADDON_ACTION_BLOCKED", func = "InviteUnit", click = true } } })
	eq(#rows, 2, "junk and a row with no function are dropped")
	eq(rows[1].kind, "FORBIDDEN") eq(rows[1].combat, true) eq(rows[1].click, nil, "click not known")
	eq(rows[2].fn, "InviteUnit") eq(rows[2].click, true)
end)
test("probe-import blocked rows: a Lab call note counts only when a blocked event followed it", function()
	local rows = PI.blockedRows({ build = "1", calls = { { fn = "Logout", click = true, blocked = true, kind = "BLOCKED" }, { fn = "Quit", click = true, blocked = false } } })
	eq(#rows, 1) eq(rows[1].fn, "Logout")
end)
test("probe-import blocked rows: merging keeps old rows, drops duplicates, is stable", function()
	local a = { fn = "ReloadUI", kind = "BLOCKED", combat = false, click = false, build = "1" }
	local b = { fn = "Logout", kind = "BLOCKED", combat = false, click = false, build = "1" }
	local m = PI.mergeBlocked({ a }, { a, b })
	eq(#m, 2)
	local text = PI.serializeBlocked(m)
	local fn = assert(loadstring(text)) setfenv(fn, {})
	eq(#fn().rows, 2, "the file reads back")
end)
test("the shipped fixture holds the row ReloadUI, BLOCKED, not from a click", function()
	local rows = PI.readBlocked(H.root .. "/tests/fixtures/probe/measured-blocked.lua")
	local found
	for _, r in ipairs(rows) do if r.fn == "ReloadUI" and r.kind == "BLOCKED" and r.click == false then found = r end end
	ok(found, "row present")
end)

-- 2. evidence on every curated entry -----------------------------------------------------------------------------------
test("every curated entry of apisurface.lua carries evidence docs or brief", function()
	local S = dofile(H.root .. "/tests/surface/apisurface.lua")
	local n = 0
	for name, c in pairs(S.curated) do
		n = n + 1
		ok(c.ev == "docs" or c.ev == "brief", name .. " has ev = " .. tostring(c.ev))
	end
	ok(n >= 27, "the curated list is there: " .. n)
end)

-- the lead / violation split and H on by default ------------------------------------------------------------------------
local function mk()
	local w = T.newWorld()
	local c = w:addClient("Test Pilot", { spot = "Orgrimmar", class = "WARLOCK", addons = { "WuberFxOld" }, allowMissing = true,
		prepare = function(env) env.CastSpellByName = function() end end })
	T.settle(w)
	return w, c
end
local function took(w)
	local out = {}
	for i = #w.violations, 1, -1 do
		local v = w.violations[i]
		if v:find("(surface guard)", 1, true) then table.insert(out, 1, v) end
		w.violations[i] = nil
	end
	return out
end
local function leads(kind, name)
	local n = 0
	for _, h in ipairs(H.surface.hits) do if h.kind == kind and h.name == name then n = n + 1 end end
	return n
end

need("surface evidence: the H rule is on by default", function() ok(H.surface.hw == true, "hardware-click rule on") end)
need("surface evidence: a brief entry (InviteUnit, no click) is a LEAD, not a violation", function()
	local w, c = mk()
	c.env.WuberFxOld.Invite()
	eq(#took(w), 0, "no violation from a brief entry")
	ok(leads("L", "InviteUnit") >= 1, "logged as a lead (kind L)")
end)
need("surface evidence: a brief entry stays quiet in the world's clean(w)", function()
	local w, c = mk()
	c.env.WuberFxOld.Macro() -- CastSpellByName: curated "never", brief
	local good = pcall(T.clean, w)
	ok(good, "clean(w) passes: a brief entry never fails a test")
end)
need("surface evidence: ReloadUI from a timer (B5) fails AS MEASURED (fixture row: ReloadUI, blocked, not from a click)", function()
	local w, c = mk()
	c.env.WuberFxOld.B5timer()
	w:advance(1)
	local got = took(w)
	local text = table.concat(got, " | ")
	ok(text:find("ReloadUI() is protected", 1, true), "reported: " .. text)
	ok(text:find("evidence: measured:71037", 1, true), "as measured: " .. text)
	eq(H.surface.evidence("ReloadUI", { ev = "brief" }), "measured:71037", "the measured row beats the table's brief")
end)
need("surface evidence: the measured row only lifts the function it names (CastSpellByName stays brief)", function()
	eq(H.surface.evidence("CastSpellByName", { ev = "brief" }), "brief")
end)

-- 5. thin wrappers -------------------------------------------------------------------------------------------------------
need("surface wrapper: ReloadUI through callm is reported at the call site one frame up, not at the wrapper line", function()
	local w, c = mk()
	c.env.WuberFxOld.B5wrapped()
	local got = took(w)
	local line
	local n = 0
	for l in io.lines(DIR .. "/Old.lua") do n = n + 1 if l:find("WRAPPED-CALL-SITE", 1, true) then line = n end end
	ok(line, "marker found")
	local text = table.concat(got, " | ")
	ok(text:find("Old.lua:" .. line .. " (surface guard)", 1, true), "judged at the call site Old.lua:" .. tostring(line) .. ": " .. text)
end)
test("surface wrapper: the wrapper list stays under 10 names", function()
	if not GUARD then return end
	local n = 0
	for _ in pairs(H.surface.WRAPPERS) do n = n + 1 end
	ok(n < 10 and n >= 3, "wrapper names: " .. n)
end)
