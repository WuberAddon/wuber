-- The evidence ledger (job 2882): tests/fixtures/client/rules.lua, tests/lib/evidence.lua, H.rule in tests/harness.lua, tools/evidence-report.lua.
-- Why it exists: the fake game's rules for B1 (back arrows, file ids), B7 (hit order under a clipping ancestor), B3, B10 ... were GUESSES that looked like
-- facts, and a green test run said nothing about it. The ledger says, per rule, how well it is known and which tests lean on it. Nothing is "measured"
-- until a WuberProbe fixture with source = "game" feeds it; the synthetic stand-in and the simulator's fixtures never count.
local T = ...
local H, test, eq, ok = T.H, T.testOutside or T.test, T.eq, T.ok

local ROOT = T.dir .. "/.."
local WIN = package.config:sub(1, 1) == "\\"
local E = dofile(T.dir .. "/lib/evidence.lua")
local L = dofile(T.dir .. "/lib/probe_learn.lua")
local RULES = ROOT .. "/tests/fixtures/client/rules.lua"
local STANDIN = T.dir .. "/fixtures/probe/SYNTHETIC-standin.lua"
local OUT = T.dir .. "/out"

local function mkdirp(dir)
	if WIN then os.execute('if not exist "' .. dir:gsub("/", "\\") .. '" mkdir "' .. dir:gsub("/", "\\") .. '" >nul 2>&1')
	else os.execute('mkdir -p "' .. dir .. '"') end
end
-- run one command line and return its output (the whole line is quoted for cmd.exe, which strips the outer pair)
local function run(cmd) local p = assert(io.popen(WIN and ('"' .. cmd .. '"') or cmd, "r")) local s = p:read("*a") p:close() return s end
local function luaExe() local a = rawget(_G, "arg") return (a and a[-1]) or "lua5.1" end
local function envSet(k, v) return WIN and ('set "' .. k .. '=' .. v .. '"&& ') or (k .. '="' .. v .. '" ') end
local function writeFile(path, text) local f = assert(io.open(path, "wb")) f:write(text) f:close() end

-- the rules table, loaded fresh; a copy a test may change
local function rulesCopy(change)
	local rules = assert(E.load(RULES))
	local out = {}
	for i, r in ipairs(rules) do local c = {} for k, v in pairs(r) do c[k] = v end out[i] = c end
	if change then change(out) end
	return out
end
local function byId(rows, id) for _, row in ipairs(rows) do if row.rule.id == id then return row end end end
-- run fn with an empty list of noted fixtures, then put back what the run had (a real game fixture may be loaded at start)
local function withLearned(fn)
	local saved = E.learned
	E.learned = {}
	local ok2, err = pcall(fn)
	E.learned = saved
	if not ok2 then error(err, 0) end
end

-- guard: infra (the ledger's own table: every rule says how well it is known; tests/fixtures/client/rules.lua)
test("ledger: the rules table is well formed, every rule has evidence, and every rule has a hook in the harness (and the reverse)", function()
	local rules = assert(E.load(RULES))
	eq(#E.check(rules), 0, "problems in rules.lua: " .. table.concat(E.check(rules), "; "))
	ok(#rules >= 25, "about 25 rules: " .. #rules)
	local sites = assert(E.hookSites(T.dir .. "/harness.lua"))
	for _, r in ipairs(rules) do ok(sites[r.id], "rule " .. r.id .. " has no H.rule(\"" .. r.id .. "\") call in tests/harness.lua") end
	local known = {}
	for _, r in ipairs(rules) do known[r.id] = true end
	for id in pairs(sites) do ok(known[id], "tests/harness.lua calls H.rule(\"" .. id .. "\") but rules.lua has no such rule (a typo?)") end
end)

-- guard: infra (the false-confidence guard: a stand-in made by hand or by the simulator is never evidence)
test("ledger: with only the synthetic stand-in loaded nothing is measured", function()
	withLearned(function()
		local fx = assert(L.load(STANDIN)) -- L.load notes it in the ledger
		eq(#E.learned, 1, "the stand-in was noted")
		ok(fx.source ~= "game", "the stand-in's source is " .. tostring(fx.source))
		ok(next(fx.fileIds or {}) ~= nil, "control: the stand-in does carry file ids (it feeds tex.file-id, and still does not measure it)")
		local rows = E.rows(assert(E.load(RULES)), E.learned)
		local n = E.countBy(rows)
		eq(n.measured, 0, "measured rules with only the stand-in")
		eq(n["measured, old"], 0, "measured-old rules with only the stand-in")
		eq(byId(rows, "tex.file-id").evidence, "one-real-case", "tex.file-id keeps its own level")
		-- the same table of file ids under every other source word that is not "game"
		for _, source in ipairs({ "sim", "synthetic", "test", false }) do
			E.learned = {}
			local copy = { source = source or nil, build = "71139", fileIds = fx.fileIds, widths = fx.widths, keys = fx.keys, hit = fx.hit, secretApi = { UnitGUID = true } }
			E.note(copy, "copy-" .. tostring(source))
			eq(E.countBy(E.rows(assert(E.load(RULES)), E.learned)).measured, 0, "source " .. tostring(source) .. " measured something")
		end
	end)
end)

-- guard: infra (a fixture marked source = "game" is what flips a rule to measured, with that fixture's build)
test("ledger: a fixture marked game flips the rules it feeds to measured, with its build", function()
	withLearned(function()
		local fx = { format = 1, kind = "probe", source = "game", build = "71139", fileIds = { ["interface\\addons\\wuber\\media\\x.tga"] = 4242 } }
		L.note(fx, "test-game-fixture")
		local rows = E.rows(assert(E.load(RULES)), E.learned)
		local row = byId(rows, "tex.file-id")
		eq(row.evidence, "measured", "tex.file-id after a game fixture with file ids")
		eq(row.build, "71139", "the build the measurement carries")
		eq(row.from, "test-game-fixture", "which fixture measured it")
		eq(E.countBy(rows).measured, 1, "only the rule the fixture feeds is measured (it has file ids and nothing else)")
		eq(byId(rows, "font.small-width").evidence, "one-real-case", "a rule the fixture does not feed keeps its level")
		-- a game fixture with no build cannot say which client it is true for
		E.learned = {}
		L.note({ source = "game", fileIds = fx.fileIds }, "no-build")
		eq(byId(E.rows(assert(E.load(RULES)), E.learned), "tex.file-id").evidence, "one-real-case", "a game fixture with no build measures nothing")
		-- on another build than the installed client's, the measurement is old
		E.learned = {}
		L.note(fx, "test-game-fixture")
		eq(byId(E.rows(assert(E.load(RULES)), E.learned, "71200"), "tex.file-id").evidence, "measured, old", "measured on 71139, the client is 71200")
		eq(byId(E.rows(assert(E.load(RULES)), E.learned, "71139"), "tex.file-id").evidence, "measured", "same build stays measured")
	end)
end)

-- guard: infra (a rule with no evidence field fails the check, and the report tool says so)
test("ledger: a rule with no evidence field fails the check, a hand-written measured too", function()
	local rules = rulesCopy(function(r) r[2].evidence = nil end)
	local bad = E.check(rules)
	eq(#bad, 1, "one problem: " .. table.concat(bad, "; "))
	ok(bad[1]:find("no evidence field", 1, true) and bad[1]:find(rules[2].id, 1, true), "names the rule and the cause: " .. tostring(bad[1]))
	local claimed = E.check(rulesCopy(function(r) r[3].evidence = "measured" end))
	eq(#claimed, 1, "measured cannot be written by hand")
	local nobuild = E.check(rulesCopy(function(r) r[1].build = nil end))
	eq(#nobuild, 1, "a one-real-case rule must say its build: " .. table.concat(nobuild, "; "))
	-- the tool itself prints it and exits 1 (a second lua process: only this one test)
	mkdirp(OUT .. "/ledger")
	local lines = { "return {" }
	lines[#lines + 1] = '{ id = "x.no-evidence", what = "w", source = "s", bug = "-" },'
	lines[#lines + 1] = "}"
	writeFile(OUT .. "/ledger/rules-no-evidence.lua", table.concat(lines, "\n"))
	local out = run('"' .. luaExe() .. '" "' .. ROOT .. '/tools/evidence-report.lua" --rules "' .. OUT .. '/ledger/rules-no-evidence.lua"')
	ok(out:find("PROBLEM rule x.no-evidence: no evidence field", 1, true), "the report prints the problem: " .. out:sub(1, 300))
end)

-- guard: infra (staleness, patch detection layer 2: the newest game fixture's build against the build in the newest WuberProbe.lua)
test("ledger: a fixture on build 71037 against a probe SavedVariables on 71139 prints STALE", function()
	local saved = [[WuberProbeDB = { on = true, runs = {
		{ id = "20261125-100000", epoch = 1000, build = "71037" },
		{ id = "20261126-100000", epoch = 2000, build = "71139" },
	} }]]
	local installed, id = E.probeBuild(saved)
	eq(installed, "71139", "the newest run's build")
	eq(id, "20261126-100000", "the newest run")
	withLearned(function()
		L.note({ source = "game", build = "71037", fileIds = { a = 1 } }, "old-game")
		L.note({ source = "sim", build = "71999", fileIds = { a = 1 } }, "newer-sim") -- a simulator fixture never sets the build
		eq(E.newestGameBuild(), "71037", "the newest GAME fixture's build")
		local line = E.staleness(E.newestGameBuild(), installed)
		ok(line:match("^STALE"), line)
		ok(line:find("71037", 1, true) and line:find("71139", 1, true), "names both builds: " .. line)
		ok(E.staleness("71139", "71139"):match("^OK"), "same build is OK")
	end)
	ok(E.staleness(nil, "71139"):find("NO GAME FIXTURE", 1, true), "no game fixture is said, not called OK")
	local none, why = E.probeBuild("WuberProbeDB = { runs = {} }")
	eq(none, nil, "no run, no build") ok(why, "and says why")
	-- the tool end to end: a folder with one game fixture on 71037, the installed build given as 71139; then a WTF folder with no probe file
	mkdirp(OUT .. "/ledger/fx")
	writeFile(OUT .. "/ledger/fx/game-probe-test.lua", 'return { format = 1, kind = "probe", source = "game", build = "71037", fileIds = { ["interface\\\\addons\\\\wuber\\\\x.tga"] = 1 } }')
	local exe, tool = '"' .. luaExe() .. '" "' .. ROOT .. '/tools/evidence-report.lua"', nil
	local out = run(exe .. ' --check-build --build 71139 --fixtures "' .. OUT .. '/ledger/fx"')
	ok(out:find("STALE: client facts are for build 71037, installed client is 71139", 1, true), "tool output: " .. out:sub(-400))
	local out2 = run(exe .. ' --check-build --fixtures "' .. OUT .. '/ledger/fx" --wtf "' .. OUT .. '/ledger/no-such-wtf"')
	ok(out2:find("no WuberProbe.lua found", 1, true) and out2:find("UNKNOWN", 1, true), "an absent probe file is said: " .. out2:sub(-300))
end)

-- guard: the warning we lacked before run 1: the tests of the B1 / B7 fixes lean on rules that were guesses (it reads what the ledger would have printed)
test("ledger: past bug B1 and B7: the arrow tests lean on guessed rules and the report says so", function()
	if os.getenv("WUBER_LEDGER_SUB") then return end -- (the sub-run below must not start another)
	mkdirp(OUT)
	local hitsFile = OUT .. "/ledger-hits-arrows.txt"
	writeFile(hitsFile, "") -- (a fresh file: the harness appends)
	local out = run(envSet("WUBER_RULE_LOG", hitsFile) .. envSet("WUBER_LEDGER_SUB", "1") .. '"' .. luaExe() .. '" "' .. ROOT .. '/tests/run.lua" "back arrow"')
	local passed, failed = out:match("(%d+) passed, (%d+) failed")
	ok(passed and tonumber(passed) >= 10 and tonumber(failed) == 0, "the sub-run of the arrow tests: " .. out:sub(-300))
	local hits = assert(E.readHits(hitsFile))
	local rules = assert(E.load(RULES))
	-- the table as it stood before 25 Nov: file ids and the hit order under a clipping ancestor were guesses (the fake gave paths, ranked by level)
	local before = rulesCopy(function(r) for _, rule in ipairs(r) do rule.evidence = rule.was or rule.evidence end end)
	local rowsBefore = E.rows(before, {})
	local rowsNow = E.rows(rules, E.learned)
	local function arrowTests(id) local n = 0 for t in pairs(hits[id] or {}) do if t:find("back arrow", 1, true) then n = n + 1 end end return n end
	for _, id in ipairs({ "tex.file-id", "hit.clip-ancestor-level" }) do
		eq(byId(rowsBefore, id).evidence, "guess", id .. " before 25 Nov")
		ok(arrowTests(id) >= 1, id .. ": " .. arrowTests(id) .. " arrow tests lean on it")
		ok(byId(rowsNow, id).evidence ~= "measured" or E.newestGameBuild(), id .. " is not measured without a game fixture")
	end
	ok(arrowTests("hit.clip-ancestor-level") >= 10, "most arrow tests go through the hit order: " .. arrowTests("hit.clip-ancestor-level"))
	local guessed = E.testsOn(rowsBefore, hits, { guess = true })
	local nArrow = 0
	for _, t in ipairs(guessed) do if t:find("back arrow", 1, true) then nArrow = nArrow + 1 end end
	ok(nArrow >= 10, "at the pre-fix table the report prints \"" .. #guessed .. " tests lean on guessed rules\", " .. nArrow .. " of them arrow tests")
	-- and the tool prints it from the same file
	local rep = run('"' .. luaExe() .. '" "' .. ROOT .. '/tools/evidence-report.lua" --hits "' .. hitsFile .. '" --tests 0')
	ok(rep:find("tests lean on guessed rules", 1, true), "the report line: " .. rep:sub(-300))
end)
