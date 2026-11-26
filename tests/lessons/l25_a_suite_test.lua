-- Job 2525, group A: the suite plan and runner (tests/lib/shard.lua, tools/suite-par.sh, tools/fresh-suite.sh, the
-- "compared 0 records" line of tests/run.lua). Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- every command runs under bash (io.popen uses cmd.exe here): written to a script file first
-- Which bash: the one running the suite (WUBER_BASH, set by tools/suite-par.sh as a Windows path; or BASH),
-- never "bash" from PATH, which on Windows can be WSL's bash. Plain "bash" only when neither is set (Linux, macOS).
local WIN = package.config:sub(1, 1) == "\\"
local BASH = os.getenv("WUBER_BASH") or os.getenv("BASH") or "bash"
if BASH == "" then BASH = "bash" end
local seq = 0
local function sh(cmd)
	seq = seq + 1
	local base = (os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"):gsub("\\", "/")
	-- unique per process: two shards running this file at once shared "cmd1.sh" and one deleted the other's script
	local path = base .. "/wuber-l25a-cmd-" .. os.time() .. "-" .. math.floor(os.clock() * 1000000) .. "-" .. tostring({}):gsub("%W", "") .. "-" .. seq .. ".sh"
	local f = assert(io.open(path, "wb"))
	f:write(cmd, "\n")
	f:close()
	local run = '"' .. BASH .. '" "' .. path .. '" 2>&1'
	if WIN then run = '"' .. run .. '"' end -- cmd /c strips the outer quotes of a command that starts with a quote
	local p = io.popen(run)
	local out = p:read("*a")
	p:close()
	os.remove(path)
	return out
end
local ROOT = sh("pwd"):gsub("%s+$", "")

local function tmp(name)
	local d = (os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"):gsub("\\", "/") .. "/wuber-l25a-" .. name
	sh('mkdir -p "' .. d .. '"')
	return d
end

local function put(path, text)
	local f = assert(io.open(path, "wb"))
	f:write(text)
	f:close()
end

-- guard: infra, failed before because tools/suite-par.sh, tools/fresh-suite.sh and tests/lib/shard.lua had no such feature
test("l25 a: C2 a full run plans from the fixture only, a leftover tests/out/times.txt changes nothing", function()
	local d = tmp("plan")
	sh('mkdir -p "' .. d .. '/fixtures" "' .. d .. '/out"')
	put(d .. "/fixtures/test-times.txt", "5.000\talpha\n4.000\tbeta\n1.000\tgamma\n")
	os.remove(d .. "/out/times.txt")
	local H = T.H
	local SH = dofile(T.dir .. "/lib/shard.lua")
	local a = SH.new(d, H, "1/2", nil, nil)
	local planA = a.plan
	a.out:close()
	put(d .. "/out/times.txt", "9.000\tgamma\n1.000\talpha\n1.000\tbeta\n")
	local b = SH.new(d, H, "1/2", nil, nil)
	local planB = b.plan
	b.out:close()
	ok(planA and planB, "both runs have a plan")
	eq(planB.alpha .. planB.beta .. planB.gamma, planA.alpha .. planA.beta .. planA.gamma, "same plan with a planted out/times.txt")
	eq(planB.gamma, planA.gamma, "gamma stays where the fixture put it")
end)

-- guard: C21 lives in tests/run.lua, which failing-first keeps from the target; failed before because run.lua printed "identical" for a compare of nothing
test("l25 a: C21 a compare that compared nothing says so, not identical", function()
	local d = tmp("cmp")
	-- a small baseline of its own (one record of some other test): the real baseline is not in the repository
	put(d .. "/baseline.txt", "=== some other test, in no run of this probe\n  world 1 time 1000 clients 1\n")
	local out = sh('cd "' .. ROOT .. '" && WUBER_BASELINE="' .. d .. '/baseline.txt" WUBER_TRANSCRIPT="' .. d .. '/t.txt" "' .. (os.getenv("WUBER_LUA") or os.getenv("LUA") or "lua5.1")
		.. '" tests/run.lua "l25 a probe nothing" --compare-transcript')
	ok(out:find("compared 0 records (nothing to compare)", 1, true), out:sub(-600))
	ok(not out:find("identical to the baseline", 1, true), "not called identical")
end)

-- guard: a probe the C21 test above runs on its own; it asserts nothing by itself
test("l25 a: C21 probe nothing (a test that is in no baseline, run by the test above)", function()
	ok(true)
end)

-- guard: the baseline is not stored in the repository (CODE-RULES.md, tests/README.md), so a compare without one must say so
-- (it said "DIFFERS", which is not a behaviour change)
test("l25 a: a compare with no baseline file says NO BASELINE and how to make one, not DIFFERS", function()
	local d = tmp("nobase")
	os.remove(d .. "/missing.txt")
	local out = sh('cd "' .. ROOT .. '" && WUBER_BASELINE="' .. d .. '/missing.txt" WUBER_TRANSCRIPT="' .. d .. '/t.txt" "' .. (os.getenv("WUBER_LUA") or os.getenv("LUA") or "lua5.1")
		.. '" tests/run.lua "l25 a probe nothing" --compare-transcript; echo "exit=$?"')
	ok(out:find("transcript: NO BASELINE", 1, true), out:sub(-600))
	ok(out:find("--update-transcript", 1, true), "it says how to make one: " .. out:sub(-600))
	ok(not out:find("DIFFERS", 1, true), "not called a difference: " .. out:sub(-600))
	ok(out:find("exit=0", 1, true), "a missing baseline is not a failure: " .. out:sub(-300))
end)

local PAR = ROOT .. "/tools/suite-par.sh"

-- guard: infra, failed before because tools/suite-par.sh, tools/fresh-suite.sh and tests/lib/shard.lua had no such feature
test("l25 a: C20 a second suite run in the same tree is refused while the first is alive", function()
	local d = tmp("lock")
	sh('mkdir -p "' .. d .. '/tests/out"')
	local pid = sh('sleep 8 > /dev/null 2>&1 &\necho $!'):match("(%d+)")
	put(d .. "/tests/out/.suite-lock", pid .. " " .. os.time() .. "\n")
	local out = sh('"' .. BASH .. '" "' .. PAR .. '" "' .. d .. '" 1 nofilter')
	ok(out:find("REFUSED: another suite run", 1, true), out)
	local f = io.open(d .. "/tests/out/.suite-lock", "rb")
	ok(f, "the lock stays with its owner")
	if f then f:close() end
end)

-- guard: infra, failed before because tools/suite-par.sh, tools/fresh-suite.sh and tests/lib/shard.lua had no such feature
test("l25 a: C20 a stale lock (dead pid) is taken over with a note and removed on exit", function()
	local d = tmp("stale")
	sh('mkdir -p "' .. d .. '/tests/out"')
	put(d .. "/tests/out/.suite-lock", "999999 " .. os.time() .. "\n")
	local out = sh('WUBER_LUA=true "' .. BASH .. '" "' .. PAR .. '" "' .. d .. '" 1 nofilter')
	ok(out:find("taking over a stale lock", 1, true), out)
	local f = io.open(d .. "/tests/out/.suite-lock", "rb")
	ok(not f, "lock removed on exit")
	if f then f:close() end
end)

-- guard: infra, failed before because tools/suite-par.sh, tools/fresh-suite.sh and tests/lib/shard.lua had no such feature
test("l25 a: C20 an unfiltered run that skipped tests is REJECTED, a filtered one is not", function()
	local d = tmp("skip")
	sh('mkdir -p "' .. d .. '"')
	put(d .. "/fakelua.sh", '#!/bin/bash\necho "5 passed, 0 failed, 0 pending, 2 skipped"\nexit 0\n')
	sh('chmod +x "' .. d .. '/fakelua.sh"') -- a written file is not executable on Linux (Windows has no such bit)
	local out = sh('WUBER_LUA="' .. d .. '/fakelua.sh" "' .. BASH .. '" "' .. PAR .. '" "' .. d .. '" 1; echo "exit=$?"')
	ok(out:find("REJECTED: unfiltered run skipped 2 tests", 1, true), out)
	ok(out:find("exit=4", 1, true), "non-zero exit: " .. out:sub(-80))
	local out2 = sh('WUBER_LUA="' .. d .. '/fakelua.sh" "' .. BASH .. '" "' .. PAR .. '" "' .. d .. '" 1 somefilter; echo "exit=$?"')
	ok(not out2:find("REJECTED", 1, true), out2)
	ok(out2:find("exit=0", 1, true), out2:sub(-80))
end)

-- guard: infra, failed before because tools/suite-par.sh, tools/fresh-suite.sh and tests/lib/shard.lua had no such feature
test("l25 a: C1 fresh-suite --dry says what it would do and refuses --update-transcript", function()
	local FS = ROOT .. "/tools/fresh-suite.sh"
	local out = sh('"' .. BASH .. '" "' .. FS .. '" --dry "' .. T.dir .. '/.." HEAD 4 ; echo "exit=$?"')
	ok(out:find("fresh clone: ", 1, true) and out:find("tests/out empty: yes", 1, true), out)
	ok(out:find("would run: bash tools/suite-par.sh", 1, true) and out:find("--compare-transcript", 1, true), out)
	ok(out:find("exit=0", 1, true), out)
	local bad = sh('"' .. BASH .. '" "' .. FS .. '" --dry "' .. T.dir .. '/.." HEAD 4 --update-transcript; echo "exit=$?"')
	ok(bad:find("REFUSED", 1, true) and bad:find("exit=2", 1, true), bad)
end)
