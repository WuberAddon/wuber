-- Fable item 7, full form (job 2895): tools/pr-summary.lua over the HISTORICAL bug commits, from recorded diffs. Each bug's line must show in the block.
--   B4  lab/WuberLab/AutoKeys.lua:108  callm(c, "IsEventRegistered", ...) == true     (6811c42; recorded: b4_autokeys_6811c42.diff, the file at that commit under tree/)
--   B5  Wuber/UI/Driver/Sheets.lua:665 ReloadUI() from the retire pill               (9716c70 = Wuber 2.4.2; the existing sheets_reloadui_2_4_2.diff, the file under tree/)
--   B5  ReloadUI from a C_Timer callback (WuberLabBar Bar.lua:247 is not in this repository's history: its shape is the reconstruction tests/fixtures/surface/WuberFxOld/Old.lua)
--   B1  Wuber/UI/Window.lua:271 g:GetTexture() compared with a path                    (9716c70; recorded: b1_window_gettexture_2_4_2.diff)
-- Every test below fails on tools/pr-summary.lua of PR #281 (no gate, static, guard or ledger section there): the failing-first proof is in the job 2895 report.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local P = dofile("tools/pr-summary.lua")
local forbidden = dofile("tools/forbidden.lua")
local surface = dofile("tests/surface/apisurface.lua")
local rules = dofile("tests/fixtures/client/rules.lua")
local FX = "tests/fixtures/old/pr_summary/"
local function slurp(p) local f = io.open(p, "rb") if not f then return nil end local s = f:read("*a") f:close() return (s:gsub("\r\n", "\n")) end
local function tree(p) return slurp(FX .. "tree/" .. p) end
local function run(diff, extra)
	local o = { forbidden = forbidden, noBase = true, surface = surface, rules = rules, sources = tree, label = "fixture", staleness = "OK: client facts are for build 71139, installed client is 71139" }
	for k, v in pairs(extra or {}) do o[k] = v end
	return P.summarize(diff, o)
end

-- guard: infra
test("pr summary full: B4 AutoKeys.lua:108 (IsEventRegistered compared before issecretvalue) is a peephole line and fails the gate", function()
	local md, res = run(slurp(FX .. "b4_autokeys_6811c42.diff"))
	ok(md:find("B4 lab/WuberLab/AutoKeys.lua:108 IsEventRegistered", 1, true), "the B4 line shows: " .. md:sub(1, 900))
	eq(res.gate.peephole, 1, "one peephole hit")
	ok(res.gate.fail, "the gate fails")
	ok(md:find("**Gate: FAIL**", 1, true), "and the block says so")
end)

-- guard: infra
test("pr summary full: B5 Sheets.lua ReloadUI from the retire pill is P, a measured-blocked name, and fails the gate", function()
	local md, res = run(slurp("tests/fixtures/old/sheets_reloadui_2_4_2.diff"))
	local p
	for _, f in ipairs(res.static.gate) do if f.kind == "P" and f.name == "ReloadUI" then p = f end end
	ok(p, "the static pass has P ReloadUI: " .. md:sub(1, 900))
	eq(p.line, 665, "at line 665, the call")
	ok(md:find("P Wuber/UI/Driver/Sheets.lua:665 ReloadUI", 1, true), "the block shows it")
	ok(md:find("Sheets.lua:664 ReloadUI", 1, true), "and the measured-blocked name line (tools/forbidden.lua)")
	ok(res.gate.p >= 1 and res.gate.blocked >= 1 and res.gate.fail, "P and measured-blocked both count")
end)

-- guard: infra
test("pr summary full: B5 ReloadUI from a C_Timer callback is P with the context timer", function()
	local text = assert(slurp("tests/fixtures/surface/WuberFxOld/Old.lua"))
	local lines, n = {}, 0
	for l in (text .. "\n"):gmatch("(.-)\n") do n = n + 1 lines[#lines + 1] = "+" .. l end
	if lines[#lines] == "+" then lines[#lines] = nil n = n - 1 end
	local diff = "--- /dev/null\n+++ b/Wuber/WuberFxOld/Old.lua\n@@ -0,0 +1," .. n .. " @@\n" .. table.concat(lines, "\n") .. "\n"
	local md, res = run(diff, { sources = function(p) return p == "Wuber/WuberFxOld/Old.lua" and text or nil end })
	local timer
	for _, f in ipairs(res.static.gate) do if f.kind == "P" and f.name == "ReloadUI" and tostring(f.ctx):find("timer", 1, true) then timer = f end end
	ok(timer, "P ReloadUI [timer] is on a changed line: " .. md:sub(1, 1200))
	ok(md:find("P Wuber/WuberFxOld/Old.lua:" .. timer.line .. " ReloadUI [timer]", 1, true), "the block shows it")
end)

-- guard: infra
test("pr summary full: B1 GetTexture compared with a path shows as an evidence ledger rule (tex.file-id, one-real-case) at Window.lua:271", function()
	local md, res = run(slurp(FX .. "b1_window_gettexture_2_4_2.diff"))
	local row
	for _, r in ipairs(res.ledger.rows) do if r.id == "tex.file-id" then row = r end end
	ok(row, "the rule tex.file-id is listed: " .. md:sub(1, 1200))
	eq(row.level, "one-real-case", "with its evidence level")
	ok(md:find("tex.file-id [one-real-case] B1", 1, true), "the block shows id, level and bug")
	ok(md:find("Wuber/UI/Window.lua:271 uses GetTexture", 1, true), "and the changed line that leans on it")
	ok(not res.gate.fail, "it is information: the gate does not fail on a ledger rule")
end)

-- guard: infra
test("pr summary full: a diff with nothing on the gate lists the information kinds, passes, and always says what it does not check", function()
	local diff = table.concat({ "+++ b/Wuber/Z.lua", "@@ -0,0 +1,3 @@", "+local function f(x)", "+	return x + 1", "+end", "" }, "\n")
	local md, res = run(diff, { staleness = "STALE: client facts are for build 71139, installed client is 71200" })
	ok(not res.gate.fail, "gate passes")
	ok(md:find("**Gate: pass**", 1, true), "and says so")
	ok(md:find("Not checked: taint propagation", 1, true), "taint propagation is named as not checked")
	ok(md:find("**Client facts:** STALE: client facts are for build 71139, installed client is 71200", 1, true), "the staleness line is printed as given")
	local md2 = P.summarize(diff, { forbidden = forbidden, noBase = true, surface = surface, rules = rules })
	ok(md2:find("not checked (no staleness line given)", 1, true), "no staleness line: says so, never a silent OK")
end)

-- guard: infra
test("pr summary full: the guard log keeps only hits on changed lines; P and K gate, the rest inform", function()
	local diff = table.concat({ "+++ b/Wuber/UI/G.lua", "@@ -0,0 +10,3 @@", "+local a = 1", "+local b = 2", "+local c = 3", "" }, "\n")
	local log = table.concat({
		"P\tReloadUI\tWuber/UI/G.lua:11",
		"U\tFooBar\tWuber/UI/G.lua:12",
		"K\tUIParent:IsEventRegistered\tWuber/UI/G.lua:99", -- not a changed line
		"P\tCastSpellByName\tWuber/UI/Other.lua:11", -- not a changed file
		"C\tJumpOrAscendStart\tInterface/AddOns/Wuber/UI/G.lua:10", -- the in-game path ends with the changed path
		"" }, "\n")
	local md, res = run(diff, { guardLogs = { log } })
	eq(#res.guard, 3, "three hits on changed lines")
	eq(res.gate.p, 1, "one P")
	eq(res.gate.peephole, 0, "the K hit is on an unchanged line")
	ok(md:find("P Wuber/UI/G.lua:11 ReloadUI (gates)", 1, true), "P gates: " .. md:sub(1, 700))
	ok(md:find("U Wuber/UI/G.lua:12 FooBar (information)", 1, true), "U informs")
	local md2, res2 = run(diff, { guardLogs = { "K\tUIParent:IsEventRegistered\tWuber/UI/G.lua:12\n" } })
	eq(res2.gate.peephole, 1, "a K hit on a changed line is a peephole hit")
	-- a changed fixture copy of a file (tests/.../Wuber/UI/G.lua) is not the addon file of the same name
	local diffFx = table.concat({ "+++ b/tests/fixtures/old/tree/Wuber/UI/G.lua", "@@ -0,0 +10,1 @@", "+local a = 1", "" }, "\n")
	eq(#(select(2, run(diffFx, { guardLogs = { "P\tReloadUI\tWuber/UI/G.lua:10\n" } }))).guard, 0, "a log hit in Wuber/UI/G.lua is not a hit in a copy of it under tests/")
	local md3 = run(diff)
	ok(md3:find("**Guard log on changed lines:** no log given", 1, true), "no log: says so")
end)

-- guard: infra
test("pr summary full: the ledger lists the rules a changed test leans on, weakest evidence first, and ignores tests that did not change", function()
	local diff = table.concat({ "+++ b/tests/fakegame/led_test.lua", "@@ -0,0 +6,2 @@", "+	local x = 1", "+	eq(x, 1)", "" }, "\n")
	local text = table.concat({ "local T = ...", "local test = T.test", "", "test(\"first test\", function()", "	local a = 1", "	local x = 1", "	eq(x, 1)", "end)", "test(\"second test\", function() end)", "" }, "\n")
	local hits = { ["tex.file-id"] = { ["first test"] = 3 }, ["keys.propagate-default-off"] = { ["second test"] = 1, ["first test"] = 1 } }
	local levels = { ["tex.file-id"] = "one-real-case", ["keys.propagate-default-off"] = "guess" }
	local md, res = run(diff, { hits = hits, levels = levels, sources = function(p) return p == "tests/fakegame/led_test.lua" and text or nil end })
	eq(#res.ledger.rows, 2, "both rules the changed test leans on")
	eq(res.ledger.rows[1].id, "keys.propagate-default-off", "guess before one-real-case")
	ok(md:find("keys.propagate-default-off [guess] B3", 1, true), "level and bug show: " .. md:sub(1, 900))
	ok(md:find("1 changed test lean on it", 1, true) or md:find("1 changed test lean", 1, true), "counted once, not the unchanged second test")
	local hits2 = { ["tex.file-id"] = { ["second test"] = 3 } }
	local _, res2 = run(diff, { hits = hits2, sources = function(p) return p == "tests/fakegame/led_test.lua" and text or nil end })
	eq(#res2.ledger.rows, 0, "a rule only an unchanged test leans on is not listed")
end)
