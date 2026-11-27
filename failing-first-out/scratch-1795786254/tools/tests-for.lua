-- tools/tests-for.lua: which tests cover the changed files, and (with --run) run only those.
--
--   lua5.1 tools/tests-for.lua [--run] [--quiet] [--strict] [--coverage [--map=<file>]] <file>...     (from the repo root)
--
-- --coverage (round 25, L14): also lists, for a Wuber/ file, every test that tests/out/coverage-map.txt says
-- executed it ("by coverage"; build the map with  lua5.1 tools/coverage-map.lua "<filter>") and the test parts
-- that run a fixture pinning the file (tests/fixtures/*.lua entries with file = "UI/X.lua": "by fixture"), next
-- to today's name-based list ("by name"). No map: one line says how to build it, the rest is today's output.
--
-- Prints the test parts that cover each file and one line to paste:  tests/run.lua --files=a,b
-- (run.lua's --files flag loads only those test parts; the tests written in run.lua itself are
-- the part called "run"). --run runs them (WUBER_LUA, WUBER_LAB_DIR, WUBER_RR141 as tools/suite-par.sh
-- uses) and exits non-zero on any failure. Exit 2: could not run; exit 3: the change needs the full suite.
--
-- A Wuber/ module file is covered by: the part named on its header "Test:" line; the part named
-- <module>_test; every part that names the module in quotes ("UI.Fold": W.Mod, the contract) or its
-- path (UI/Fold.lua); and "run" when run.lua itself does. Wuber.toc, .xml, Media: round2 + core/registry_test.
-- A changed test part runs itself; run.lua, tests/lib, harness, fakes, fixtures: the full suite (exit 3).
-- Tests are not always run in the part their module names: a wide module (Core.Base) matches
-- many parts, it is just slower. "Not covered" means nothing names it: run "tests/run.lua <word>" by hand.
-- Lua 5.1; no dependency but io.popen for --run.

local args, run, quiet, files, strict = arg or {}, false, false, {}, false
local coverage, mapPath = false, nil
for _, a in ipairs(args) do
	if a == "--run" then run = true elseif a == "--quiet" then quiet = true elseif a == "--strict" then strict = true
	elseif a == "--coverage" then coverage = true
	elseif a:match("^%-%-map=") then mapPath = a:sub(7)
	else files[#files + 1] = a end
end
local root = ((args[0] or "tools/tests-for.lua"):gsub("\\", "/"):match("^(.*)/tools/[^/]*$")) or "."
local function slurp(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local s = f:read("*a")
	f:close()
	return s
end
local function say(...) if not quiet then print(...) end end

-- the parts run.lua loads: every quoted word in it that is a file tests/<word>.lua
local runText = slurp(root .. "/tests/run.lua")
if not runText then io.stderr:write("tests-for: no tests/run.lua under " .. root .. "\n") os.exit(2) end
local parts, order = {}, {}
local function addPart(p)
	p = p:gsub("^/", ""):gsub("%.lua$", "")
	if p ~= "run" and not p:find("^lib/") and not parts[p] then
		local text = slurp(root .. "/tests/" .. p .. ".lua")
		if text then parts[p] = text order[#order + 1] = p end
	end
end
for w in runText:gmatch('"([%w_/%.]+)"') do addPart(w) end
table.sort(order)
parts.run = runText

local function norm(f)
	f = f:gsub("\\", "/")
	local rel = f:match("[Ww]uber/(.*)$")
	if f:match("^tests/") or f:match("/tests/") then return f:match("tests/.*$") end
	if f:match("^tools/") or f:match("/tools/") then return f:match("tools/.*$") end
	return rel and ("Wuber/" .. rel) or f
end

local chosen, chosenSet, why, full, uncovered = {}, {}, {}, false, {}
local function pick(p, f, how)
	-- --strict (verify-day's retake gate): only a part that names the module by its Test: line, its name or W.Mod("..."),
	-- never "run" (run.lua's own tests) and never a bare file-name mention
	if strict and (p == "run" or how == "names the file") then return end
	if not chosenSet[p] then chosenSet[p] = true chosen[#chosen + 1] = p end
	if coverage and how ~= "by coverage" and how ~= "by fixture" then how = "by name: " .. how end
	local key = p .. "|" .. f .. ((how == "by coverage" or how == "by fixture") and ("|" .. how) or "")
	if chosenSet[key] then return end
	chosenSet[key] = true
	why[#why + 1] = ("  %-34s <- %s (%s)"):format(p, f, how)
end

-- --coverage: the map (test name <TAB> files it executed, from tools/coverage-map.lua) and the fixtures' pinned files
local covIndex, covNote = nil, nil
local fixPins = {}
local function partsOfTest(name) -- every part with test("<name>" (or pending/testOutside), a quote escaped as in the source
	local found, esc = {}, name:gsub('"', '\\"')
	for _, p in ipairs(order) do
		for _, n in ipairs({ name, esc }) do
			if parts[p]:find('("' .. n .. '"', 1, true) then found[#found + 1] = p break end
		end
	end
	return found
end
if coverage then
	local mp = mapPath or (root .. "/tests/out/coverage-map.txt")
	local text = slurp(mp)
	if text then
		covIndex = {}
		for line in text:gmatch("[^\r\n]+") do
			local name, fl = line:match("^(.-)\t(.*)$")
			if name then for fn in fl:gmatch("[^,]+") do
				covIndex[fn] = covIndex[fn] or {}
				table.insert(covIndex[fn], name)
			end end
		end
	else
		print("--coverage: no coverage map (" .. mp .. "); build it with:  lua5.1 tools/coverage-map.lua \"<filter>\"  (about 1 s a test; a full build is long). Name-based list only:")
	end
	local p = io.popen(package.config:sub(1, 1) == "\\" and ('dir /b "' .. (root .. "/tests/fixtures"):gsub("/", "\\") .. '" 2>nul') or ('ls "' .. root .. '/tests/fixtures" 2>/dev/null'))
	for fx in (p and p:read("*a") or ""):gmatch("[^\r\n]+") do
		if fx:match("%.lua$") then
			local t = slurp(root .. "/tests/fixtures/" .. fx) or ""
			for pinned in t:gmatch('file%s*=%s*"([%w_/]+%.lua)"') do
				fixPins[pinned] = fixPins[pinned] or {}
				fixPins[pinned][fx] = true
			end
		end
	end
	if p then p:close() end
end

for _, raw in ipairs(files) do
	local f = norm(raw)
	local n0 = #chosen + #why
	if f:match("^tests/") then
		local p = f:gsub("^tests/", ""):gsub("%.lua$", "")
		if p == "run" or p:match("^lib/") or p:match("^harness") or p:match("^fixtures/") or p:match("^transcripts/") then
			full = true say("  " .. f .. ": the test machinery changed: full suite")
		elseif parts[p] then pick(p, f, "the test itself")
		else say("  " .. f .. ": not a part run.lua loads (a helper? run the suite)") full = true end
	elseif f:match("^Wuber/.*%.lua$") then
		local path = f:gsub("^Wuber/", ""):gsub("%.lua$", "")
		local text = slurp(root .. "/" .. f) or ""
		local mod = text:match("%-%- Module:%s*([%w_%.]+)") or path:gsub("/", ".")
		local direct = text:match("%-%- Test:%s*tests/([%w_/%.]+)")
		if direct then
			direct = direct:gsub("%.lua$", "")
			if parts[direct] then pick(direct, f, "Test: line") else say("  " .. f .. ": its Test: line names " .. direct .. ", which run.lua does not load") end
		end
		local last = mod:match("([^%.]+)$"):lower()
		local pathTail = path:match("([^/]+/[^/]+)$") or path
		for _, p in ipairs(order) do
			local t = parts[p]
			if p:match("([^/]+)$") == last .. "_test" then pick(p, f, "named for it")
			elseif t:find('"' .. mod .. '"', 1, true) then pick(p, f, "names " .. mod)
			elseif t:find(pathTail .. ".lua", 1, true) then pick(p, f, "names the file") end
		end
		for _, pat in ipairs({ '"' .. mod .. '"', pathTail .. ".lua" }) do
			if runText:find(pat, 1, true) then pick("run", f, "run.lua names it") break end
		end
	elseif f:match("%.toc$") or f:match("%.xml$") or f:match("^Wuber/Media/") then
		pick("round2", f, "TOC / xml / media") pick("core/registry_test", f, "TOC / xml / media")
		if f:match("%.toc$") then pick("run", f, "the TOC tests live in run.lua") end
	else
		say("  " .. f .. ": nothing to run for this file")
	end
	if coverage and f:match("^Wuber/.*%.lua$") then
		local seenTest = {}
		for _, name in ipairs(covIndex and covIndex[f:gsub("^Wuber/", "")] or {}) do
			if not seenTest[name] then
				seenTest[name] = true
				why[#why + 1] = ("  test %q <- %s (by coverage)"):format(name, f)
				for _, p in ipairs(partsOfTest(name)) do pick(p, f, "by coverage") end
			end
		end
		for fx in pairs(fixPins[f:gsub("^Wuber/", "")] or {}) do
			for _, p in ipairs(order) do
				if parts[p]:find("fixtures/" .. fx, 1, true) then pick(p, f, "by fixture") end
			end
		end
	end
	if #chosen + #why == n0 and (f:match("^Wuber/") or f:match("^tests/")) and not full then uncovered[#uncovered + 1] = f end
end

if not quiet then for _, w in ipairs(why) do print(w) end end
for _, f in ipairs(uncovered) do say("  not covered: " .. f .. " (nothing names it; try tests/run.lua <word>)") end
if full then
	print("full suite needed (tools/suite-par.sh <repo> 16 --compare-transcript)")
	if run then os.exit(3) end
	return
end
if #chosen == 0 then print("tests: none") return end
table.sort(chosen)
local flag = "--files=" .. table.concat(chosen, ",")
print("tests: " .. flag)
if not run then return end

local function exists(p) local f = io.open(p, "rb") if f then f:close() return true end end
local lua = os.getenv("WUBER_LUA")
for _, c in ipairs({ root .. "/bin/lua5.1.exe" }) do
	if not lua and exists(c) then lua = c end
end
lua = lua or "lua5.1"
local lab = os.getenv("WUBER_LAB_DIR") or (root .. "/lab/WuberLab")
local rr = os.getenv("WUBER_RR141") or ""
-- the run's output goes into this checkout (round 27: nine groups sharing one file in TEMP locked each other out)
local out = root .. "/tests/out/tests-for.out"
do
	local f = io.open(out, "w")
	if f then f:close() else out = (os.getenv("TEMP") or "/tmp") .. "/wuber-tests-for.out" end
end
local isWin = package.config:sub(1, 1) == "\\"
local cmd
if isWin then
	cmd = ('set "WUBER_LAB_DIR=%s" && set "WUBER_RR141=%s" && cd /d "%s" && "%s" tests/run.lua %s > "%s" 2>&1'):format(lab, rr, root:gsub("/", "\\"), lua:gsub("/", "\\"), flag, out:gsub("/", "\\"))
else
	cmd = ('WUBER_LAB_DIR="%s" WUBER_RR141="%s" "%s" "%s/tests/run.lua" %s > "%s" 2>&1'):format(lab, rr, lua, root, flag, out)
end
local t0 = os.time()
local code = os.execute(cmd)
local text = slurp(out) or ""
local fails = 0
for line in text:gmatch("[^\r\n]+") do
	if line:match("^FAIL") then fails = fails + 1 print(line) end
end
if fails > 0 then
	for block in text:gmatch("FAIL[^\n]*\n(.-)\nPASS") do print(block:sub(1, 600)) break end
end
local summary = text:match("(%d+ passed, %d+ failed[^\r\n]*)")
print(("tests-for: %s in %d s"):format(summary or "no summary line (did run.lua crash?)", os.time() - t0))
if not summary then print(text:sub(-1500)) os.exit(2) end
local ok = (code == 0 or code == true) and fails == 0 and summary:match("^%d+ passed, 0 failed")
os.exit(ok and 0 or 1)
