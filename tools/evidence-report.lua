-- tools/evidence-report.lua: the evidence ledger report (job 2882). Lua 5.1.
--   lua5.1 tools/evidence-report.lua --help
-- Rules: tests/fixtures/client/rules.lua. Library: tests/lib/evidence.lua. Hits come from tests/run.lua with WUBER_RULE_LOG=<file> (the harness's H.rule calls).
local dir = (arg and arg[0] or "tools/evidence-report.lua"):gsub("\\", "/"):match("^(.*)/[^/]*$") or "."
local root = dir .. "/.."
local WIN = package.config:sub(1, 1) == "\\"

local HELP = [[
usage: lua5.1 tools/evidence-report.lua [options]
Prints the evidence ledger: every fake-game rule by how well it is known (measured, one-real-case, docs, borrowed, guess), the tests that lean on each
rule, and "N tests lean on guessed rules". "measured" needs a probe fixture with source = "game"; a "sim" or "synthetic" fixture never counts.
  --run <filter>      run tests/run.lua with that name filter first (one lua process) and read the hits it records (default: no run)
  --hits <file>       read a hits file written by tests/run.lua with WUBER_RULE_LOG=<file> (repeatable; several shards add up)
  --rules <file>      the rules table (default tests/fixtures/client/rules.lua)
  --fixtures <dir>    probe fixtures to learn from (default tests/fixtures/probe; every .lua in it is loaded, only source = "game" counts)
  --tests <n>         show at most n tests per rule (default 6; 0 = none, all = every one)
  --check-build       compare the newest game fixture's build with the client build in the newest WuberProbe.lua under --wtf; prints STALE or OK
  --wtf <dir>         WTF folder for --check-build (default C:\Program Files (x86)\World of Warcraft\_forever_\WTF; only read)
  --build <n>         use this as the installed client build (instead of reading --wtf); rules measured on another build print "measured, old"
  --lua <exe>         the lua 5.1 to run tests with (default: the one running this tool)
  --help              this text
Exit code: 0; 1 when the rules table is malformed (a rule with no evidence field, a duplicate id ...); 2 on a bad argument.
]]

local o = { rules = root .. "/tests/fixtures/client/rules.lua", fixtures = root .. "/tests/fixtures/probe", tests = 6, hits = {},
	wtf = "C:\\Program Files (x86)\\World of Warcraft\\_forever_\\WTF", lua = (arg and arg[-1]) or "lua5.1" }
do
	local i = 1
	while arg and arg[i] do
		local a = arg[i]
		if a == "--help" or a == "-h" then io.write(HELP) os.exit(0)
		elseif a == "--check-build" then o.check = true
		elseif a == "--run" or a == "--rules" or a == "--fixtures" or a == "--tests" or a == "--wtf" or a == "--build" or a == "--lua" or a == "--hits" then
			local v = arg[i + 1]
			if not v then io.stderr:write("evidence-report: " .. a .. " needs a value\n") os.exit(2) end
			if a == "--hits" then o.hits[#o.hits + 1] = v else o[a:sub(3)] = v end
			i = i + 1
		else io.stderr:write("evidence-report: unknown argument " .. a .. " (see --help)\n") os.exit(2) end
		i = i + 1
	end
	if o.tests == "all" then o.tests = math.huge else o.tests = tonumber(o.tests) or 6 end
end

local E = dofile(root .. "/tests/lib/evidence.lua")
local L = dofile(root .. "/tests/lib/probe_learn.lua")

local function popen(cmd)
	local p = io.popen(cmd, "r")
	if not p then return "" end
	local s = p:read("*a") p:close()
	return s
end

local rules, err = E.load(o.rules)
if not rules then io.stderr:write("evidence-report: " .. tostring(err) .. "\n") os.exit(1) end
local problems = E.check(rules)

-- the fixtures the fake game learns from
local fixtureNotes = {}
do
	local list = WIN and popen('dir /b "' .. o.fixtures:gsub("/", "\\") .. '\\*.lua" 2>nul') or popen('ls "' .. o.fixtures .. '"/*.lua 2>/dev/null')
	for name in list:gmatch("[^\r\n]+") do
		name = name:match("([^/\\]+)$")
		if name:match("%.lua$") then
			local fx = L.load(o.fixtures .. "/" .. name)
			if type(fx) == "table" then fixtureNotes[#fixtureNotes + 1] = ("%s: source=%s build=%s%s"):format(name, tostring(fx.source), tostring(fx.build),
				(fx.source == "game" and fx.build) and " (counts)" or " (does not count as measured)") end
		end
	end
end

-- the installed client's build
local installed, installedWhy, installedFile
if o.build then installed = o.build end
if o.check and not installed then
	local cmd
	if WIN then
		cmd = 'powershell -NoProfile -Command "Get-ChildItem -Recurse -Filter WuberProbe.lua -LiteralPath \'' .. o.wtf:gsub("'", "''") .. '\' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName"'
	else
		cmd = 'find "' .. o.wtf .. '" -name WuberProbe.lua -printf "%T@ %p\\n" 2>/dev/null | sort -rn | head -1 | cut -d" " -f2-'
	end
	installedFile = popen(cmd):gsub("[\r\n]+$", "")
	if installedFile == "" then installedFile = nil installedWhy = "no WuberProbe.lua found under " .. o.wtf
	else
		local f = io.open(installedFile, "rb")
		if not f then installedWhy = "cannot read " .. installedFile else
			local text = f:read("*a") f:close()
			local b, id = E.probeBuild(text)
			if b then installed = b installedWhy = ("%s (run %s)"):format(installedFile, tostring(id)) else installedWhy = installedFile .. ": " .. tostring(id) end
		end
	end
end

-- hits
local hits
local hitFiles = {}
for _, h in ipairs(o.hits) do hitFiles[#hitFiles + 1] = h end
if o.run then
	local tmp = os.tmpname()
	if WIN and tmp:sub(1, 1) == "\\" then tmp = (os.getenv("TEMP") or ".") .. tmp end
	local cmd = (WIN and 'set "WUBER_RULE_LOG=' .. tmp .. '"&& ' or ('WUBER_RULE_LOG="' .. tmp .. '" ')) .. '"' .. o.lua .. '" "' .. root .. '/tests/run.lua" "' .. o.run .. '" 2>&1'
	local out = popen(cmd)
	local tail = {}
	for line in out:gmatch("[^\r\n]+") do tail[#tail + 1] = line end
	io.write(("ran tests/run.lua \"%s\": %s\n"):format(o.run, tail[#tail - 1] or tail[#tail] or "(no output)"))
	hitFiles[#hitFiles + 1] = tmp
end
for _, path in ipairs(hitFiles) do
	local h, e = E.readHits(path, hits)
	if h then hits = h else io.stderr:write("evidence-report: " .. tostring(e) .. "\n") end
end

local rows = E.rows(rules, E.learned, installed)
local counts = E.countBy(rows)
local function pad(s, n) s = tostring(s) return s .. string.rep(" ", math.max(0, n - #s)) end

print(("EVIDENCE LEDGER: %d rules (%s)"):format(#rules, o.rules:gsub("^.*/tests/", "tests/")))
print(("by evidence: measured %d, measured-old %d, one-real-case %d, docs %d, borrowed %d, guess %d"):format(counts.measured, counts["measured, old"],
	counts["one-real-case"], counts.docs, counts.borrowed, counts.guess))
if #fixtureNotes == 0 then print("fixtures: none in " .. o.fixtures) else for _, n in ipairs(fixtureNotes) do print("fixture " .. n) end end
if counts.measured + counts["measured, old"] == 0 then print("nothing is measured: no fixture with source = \"game\" feeds any rule yet") end
for _, p in ipairs(problems) do print("PROBLEM " .. p) end

local lean = hits and E.leaning(hits)
for _, level in ipairs(E.LEVELS) do
	local group = {}
	for _, row in ipairs(rows) do if row.evidence == level then group[#group + 1] = row end end
	if #group > 0 then
		print(("\n== %s (%d) =="):format(level, #group))
		for _, row in ipairs(group) do
			local r = row.rule
			local n = lean and (lean[r.id] and #lean[r.id] or 0)
			print(("  %s %s  %s%s%s"):format(pad(r.id, 32), pad(n and (n .. " tests") or "-", 10), r.bug ~= "-" and (r.bug .. "  ") or "", row.build and ("build " .. row.build .. "  ") or "", row.from and ("from " .. row.from) or ""))
			print("      " .. r.what)
			if r.differs then print("      DIFFERS: " .. r.differs) end
			if lean and lean[r.id] and o.tests > 0 then
				local shown = {}
				for k = 1, math.min(#lean[r.id], o.tests) do shown[#shown + 1] = lean[r.id][k] end
				print("      tests: " .. table.concat(shown, " | ") .. (#lean[r.id] > #shown and (" | ... +" .. (#lean[r.id] - #shown)) or ""))
			end
		end
	end
end

if hits then
	local guess = E.testsOn(rows, hits, { guess = true })
	local weak = E.testsOn(rows, hits, { guess = true, borrowed = true, docs = true, ["one-real-case"] = true, ["measured, old"] = true })
	local any = {}
	for _, tests in pairs(hits) do for t in pairs(tests) do any[t] = true end end
	local nAny = 0 for _ in pairs(any) do nAny = nAny + 1 end
	print(("\n%d tests lean on guessed rules."):format(#guess))
	print(("%d tests lean on rules that are not measured (of %d tests that touch any ledger rule)."):format(#weak, nAny))
else
	print("\n(no hit data: pass --run \"<test name filter>\" or --hits <file>, to see which tests lean on which rule)")
end

if o.check then
	print("")
	local newest = E.newestGameBuild(E.learned)
	if installedWhy then print("probe SavedVariables: " .. installedWhy) end
	print(E.staleness(newest, installed))
end
os.exit(#problems == 0 and 0 or 1)
