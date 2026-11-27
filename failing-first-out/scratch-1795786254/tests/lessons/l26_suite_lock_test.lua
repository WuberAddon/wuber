-- Job 2755: the machine-wide suite lock, the result cache and the default shard count of tools/suite-par.sh
-- (helpers in tools/suite-guard.sh). Every case runs a fake Lua, so no real suite starts.
local T = ...
local eq, ok = T.eq, T.ok

local seq = 0
local function base() return (os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"):gsub("\\", "/") end
local function sh(cmd)
	seq = seq + 1
	local path = base() .. "/wuber-l26-cmd-" .. os.time() .. "-" .. math.floor(os.clock() * 1000000) .. "-" .. tostring({}):gsub("%W", "") .. "-" .. seq .. ".sh"
	local f = assert(io.open(path, "wb"))
	f:write(cmd, "\n")
	f:close()
	local p = io.popen('bash "' .. path .. '" 2>&1')
	local out = p:read("*a")
	p:close()
	os.remove(path)
	return out
end
local ROOT = sh("pwd"):gsub("%s+$", "")
local PAR = ROOT .. "/tools/suite-par.sh"

-- A lock holder is a 'sleep'. It must still be alive whenever the run under test looks at the lock, however slow a busy PC is
-- (holders of 20 and 25 s ran out before the run looked: the run saw no holder and never waited). So it lives 5 minutes and is
-- stopped by its pid when its test ends (a failed test too).
local started = {}
local function holder()
	local pid = sh('sleep 300 > /dev/null 2>&1 &\necho $!'):match("(%d+)")
	started[#started + 1] = pid
	return pid
end
local rawTest = T.test
local function test(name, fn)
	rawTest(name, function()
		local good, err = pcall(fn)
		for _, pid in ipairs(started) do sh("kill " .. pid .. " 2>/dev/null") end
		started = {}
		if not good then error(err, 0) end
	end)
end

local function put(path, text)
	local f = assert(io.open(path, "wb"))
	f:write(text)
	f:close()
	-- fake Lua and other helper scripts are run directly: they need the exec bit on Linux (exit 126 without it)
	if path:match("%.sh$") then sh('chmod +x "' .. path .. '"') end
end

-- a throwaway git tree with a Wuber/ file and a fake Lua that "passes"
local function tree(name)
	local d = base() .. "/wuber-l26-" .. name .. "-" .. os.time() .. "-" .. math.floor(os.clock() * 1000000) .. "-" .. tostring({}):gsub("%W", "") .. "-" .. seq
	sh('mkdir -p "' .. d .. '/Wuber" "' .. d .. '/tests" "' .. d .. '/tools" && cd "' .. d .. '" && git init -q . && echo one > Wuber/a.lua && git add -A')
	put(d .. "/fakelua.sh", '#!/bin/bash\necho "5 passed, 0 failed, 0 pending, 0 skipped"\nexit 0\n')
	return d
end
local function run(d, env, args)
	return sh('unset WUBER_SHARDS WUBER_SUITE_PARENT WUBER_CORES WUBER_SUITE_LOCK WUBER_SUITE_CACHE WUBER_SUITE_WAIT_MAX WUBER_SUITE_SLOTS; cd "' .. d .. '" && export ' .. (env == "" and "WUBER_X=1" or env) .. ' && WUBER_LUA="' .. d .. '/fakelua.sh" WUBER_SUITE_POLL=1 bash "' .. PAR .. '" "' .. d .. '" ' .. args .. '; echo "exit=$?"')
end

-- guard: failed before because suite-par.sh had no result cache
test("l26: a pass is cached, the same code again says so and exits 0, --force and changed code run again", function()
	local d = tree("cache")
	local a = run(d, "", "1")
	ok(a:find("1 shards", 1, true) and a:find("exit=0", 1, true), a)
	local b = run(d, "", "1")
	ok(b:find("same code already passed (", 1, true) and not b:find("shard 1/1", 1, true) and b:find("exit=0", 1, true), b)
	local c = run(d, "", "1 --force")
	ok(c:find("shard 1/1", 1, true), c)
	put(d .. "/Wuber/a.lua", "two\n")
	local e = run(d, "", "1")
	ok(e:find("shard 1/1", 1, true) and not e:find("already passed", 1, true), e)
end)

-- guard: failed before because suite-par.sh had no result cache
test("l26: a failing run is never cached", function()
	local d = tree("fail")
	put(d .. "/fakelua.sh", '#!/bin/bash\necho "4 passed, 1 failed, 0 pending, 0 skipped"\nexit 1\n')
	local a = run(d, "", "1")
	ok(a:find("exit=1", 1, true), a)
	local b = run(d, "", "1")
	ok(b:find("shard 1/1", 1, true) and not b:find("already passed", 1, true), b)
end)

-- guard: failed before because the cache folder could not be chosen
test("l26: WUBER_SUITE_CACHE chooses the cache folder", function()
	local d = tree("cachedir")
	local cdir = d .. "/mycache"
	run(d, 'WUBER_SUITE_CACHE="' .. cdir .. '"', "1")
	local n = sh('ls "' .. cdir .. '" | wc -l'):match("%d+")
	eq(n, "1", "one pass file in " .. cdir)
	local b = run(d, 'WUBER_SUITE_CACHE="' .. cdir .. '"', "1")
	ok(b:find("already passed", 1, true), b)
end)

-- guard: failed before because there was no default from the core count
test("l26: no shard count given uses the core count, at most 16, half while another suite is queued", function()
	local d = tree("cores")
	local a = run(d, "WUBER_CORES=6", "")
	ok(a:find("shard 6/6", 1, true) and not a:find("shard 7/", 1, true), a)
	local d2 = tree("cores2")
	local b = run(d2, "WUBER_CORES=64", "")
	ok(b:find("shard 16/16", 1, true) and not b:find("shard 17/", 1, true), b)
	-- a fake nproc on the PATH
	local d3 = tree("cores3")
	sh('mkdir -p "' .. d3 .. '/bin"')
	put(d3 .. "/bin/nproc", "#!/bin/bash\necho 3\n")
	sh('chmod +x "' .. d3 .. '/bin/nproc"')
	local c = run(d3, 'PATH="$(cd "' .. d3 .. '/bin" && pwd):$PATH"', "")
	ok(c:find("shard 3/3", 1, true) and not c:find("shard 4/", 1, true), c)
	-- another live suite in the lock folder: half of 8
	local d4 = tree("cores4")
	local lk = d4 .. "/locks"
	sh('mkdir -p "' .. lk .. '"')
	local pid = holder()
	put(lk .. "/wait." .. pid, pid .. " " .. os.time() .. "\n")
	local e = run(d4, 'WUBER_CORES=8 WUBER_SUITE_LOCK="' .. lk .. '"', "")
	ok(e:find("shard 4/4", 1, true) and not e:find("shard 5/", 1, true), e)
	-- an explicit count wins
	local f2 = run(d4, 'WUBER_CORES=8 WUBER_SUITE_LOCK="' .. lk .. '"', "2 --force")
	ok(f2:find("shard 2/2", 1, true), f2)
end)

-- guard: failed before because there was no machine-wide lock
-- The holder must still be alive when the run first looks at the lock, however slow the start is (a busy PC took more than the
-- 3 seconds the holder used to live: the run found no holder and never said it waited). So the holder lives until the run has
-- said it waits (60 s cap), then it is stopped by its pid. WUBER_L26_SLOW=<seconds> adds a slow start (stress knob).
test("l26: a live lock holder makes the run wait, the lock goes on exit, the run then goes ahead", function()
	local d = tree("wait")
	local lk = d .. "/locks"
	sh('mkdir -p "' .. lk .. '"')
	local cmd = 'unset WUBER_SHARDS WUBER_SUITE_PARENT WUBER_CORES WUBER_SUITE_LOCK WUBER_SUITE_CACHE WUBER_SUITE_WAIT_MAX WUBER_SUITE_SLOTS; cd "' .. d .. '" && export WUBER_SUITE_LOCK="' .. lk .. '" WUBER_SUITE_SLOTS=1 && WUBER_LUA="' .. d .. '/fakelua.sh" WUBER_SUITE_POLL=1 bash "' .. PAR .. '" "' .. d .. '" 1; echo "exit=$?"'
	local script = table.concat({
		'sleep 90 > /dev/null 2>&1 &',
		'hp=$!',
		'echo "$hp $(date +%s)" > "' .. lk .. '/held"',
		'echo HOLDER=$hp',
		'sleep ' .. (os.getenv("WUBER_L26_SLOW") or "0"),
		'( ' .. cmd .. ' ) > "' .. d .. '/run.out" 2>&1 &',
		'rp=$!',
		'for i in $(seq 1 300); do grep -q "waiting for suite lock" "' .. d .. '/run.out" && break; sleep 0.2; done',
		'kill $hp 2>/dev/null',
		'wait $rp',
		'cat "' .. d .. '/run.out"',
	}, "\n")
	local out = sh(script)
	local pid = out:match("HOLDER=(%d+)")
	ok(pid, out)
	ok(out:find("waiting for suite lock held by " .. pid, 1, true), out)
	ok(out:find("shard 1/1", 1, true) and out:find("exit=0", 1, true), out)
	local gone = sh('[ -e "' .. lk .. '/held" ] && echo HELD || echo FREE')
	ok(gone:find("FREE", 1, true), "the lock is released: " .. gone)
	local w = sh('ls "' .. lk .. '" | grep -c "^wait\\|^held\\.[0-9]"')
	ok(w:find("^0"), "no wait or held file left: " .. w)
end)

-- guard: failed before because there was no machine-wide lock
test("l26: a stale lock (dead pid, or older than 60 minutes) is taken over with a note", function()
	local d = tree("stale")
	local lk = d .. "/locks"
	sh('mkdir -p "' .. lk .. '"')
	put(lk .. "/held", "999999 " .. os.time() .. "\n")
	local a = run(d, 'WUBER_SUITE_LOCK="' .. lk .. '"', "1")
	ok(a:find("taking over a stale suite lock", 1, true) and a:find("shard 1/1", 1, true), a)
	local pid = holder()
	put(lk .. "/held", pid .. " " .. (os.time() - 3700) .. "\n")
	local b = run(d, 'WUBER_SUITE_LOCK="' .. lk .. '"', "1 --force")
	ok(b:find("taking over a stale suite lock", 1, true) and b:find("shard 1/1", 1, true), b)
end)

-- guard: failed before because the wait had no cap
test("l26: after the wait cap the run goes ahead anyway", function()
	local d = tree("cap")
	local lk = d .. "/locks"
	sh('mkdir -p "' .. lk .. '"')
	local pid = holder()
	put(lk .. "/held", pid .. " " .. os.time() .. "\n")
	local out = run(d, 'WUBER_SUITE_LOCK="' .. lk .. '" WUBER_SUITE_WAIT_MAX=2 WUBER_SUITE_SLOTS=1', "1")
	ok(out:find("running anyway", 1, true) and out:find("shard 1/1", 1, true), out)
	local still = sh('cat "' .. lk .. '/held"')
	ok(still:find(pid, 1, true), "the other holder's lock is left alone: " .. still)
end)

-- guard: failed before because a suite started by a test inside a running suite waited for its parent's lock (a 40 minute hang)
test("l26: a suite started inside a running suite (WUBER_SUITE_PARENT) neither waits nor caches", function()
	local d = tree("nested")
	local lk = d .. "/locks"
	sh('mkdir -p "' .. lk .. '"')
	local pid = holder()
	put(lk .. "/held", pid .. " " .. os.time() .. "\n")
	local out = run(d, 'WUBER_SUITE_LOCK="' .. lk .. '" WUBER_SUITE_PARENT=' .. pid, "1")
	ok(not out:find("waiting for suite lock", 1, true) and out:find("shard 1/1", 1, true) and out:find("exit=0", 1, true), out)
	local again = run(d, 'WUBER_SUITE_LOCK="' .. lk .. '" WUBER_SUITE_PARENT=' .. pid, "1")
	ok(not again:find("already passed", 1, true), "nothing was cached: " .. again)
end)

-- guard: no lock folder = today's behaviour
test("l26: without WUBER_SUITE_LOCK nothing waits and no lock folder is made", function()
	local d = tree("nolock")
	local out = run(d, "", "1")
	ok(not out:find("waiting for suite lock", 1, true) and out:find("shard 1/1", 1, true), out)
end)

-- slot lock (job 2810): up to WUBER_SUITE_SLOTS (default 3) suites at once, one held.<pid> file each
local function holders(lk, n, age)
	local pids = {}
	for i = 1, n do
		local pid = holder()
		put(lk .. "/held." .. pid, pid .. " " .. (os.time() - (age or 0)) .. "\n")
		pids[#pids + 1] = pid
	end
	return pids
end

test("l26: with 2 of the default 3 slots taken a suite runs at once, takes held.<pid> and frees it on exit", function()
	local d = tree("slots2")
	local lk = d .. "/locks"
	sh('mkdir -p "' .. lk .. '"')
	holders(lk, 2)
	local out = run(d, 'WUBER_SUITE_LOCK="' .. lk .. '"', "1")
	ok(not out:find("waiting for suite lock", 1, true) and out:find("shard 1/1", 1, true) and out:find("exit=0", 1, true), out)
	eq(sh('ls "' .. lk .. '" | grep -c "^held\\.[0-9]"'):match("%d+"), "2", "only the two other holders are left")
end)

test("l26: with all 3 slots taken a suite waits; WUBER_SUITE_SLOTS=4 lets it in", function()
	local d = tree("slots3")
	local lk = d .. "/locks"
	sh('mkdir -p "' .. lk .. '"')
	holders(lk, 3)
	local out = run(d, 'WUBER_SUITE_LOCK="' .. lk .. '" WUBER_SUITE_WAIT_MAX=2', "1")
	ok(out:find("waiting for suite lock held by", 1, true) and out:find("running anyway", 1, true), out)
	local d2 = tree("slots4")
	local out2 = run(d2, 'WUBER_SUITE_LOCK="' .. lk .. '" WUBER_SUITE_SLOTS=4 WUBER_SUITE_WAIT_MAX=2', "1")
	ok(not out2:find("waiting for suite lock", 1, true) and out2:find("shard 1/1", 1, true), out2)
end)

test("l26: the old single held file counts as one taken slot", function()
	local d = tree("legacy")
	local lk = d .. "/locks"
	sh('mkdir -p "' .. lk .. '"')
	holders(lk, 2)
	local pid = holder()
	put(lk .. "/held", pid .. " " .. os.time() .. "\n")
	local out = run(d, 'WUBER_SUITE_LOCK="' .. lk .. '" WUBER_SUITE_WAIT_MAX=2', "1")
	ok(out:find("waiting for suite lock held by", 1, true) and out:find("running anyway", 1, true), out)
	ok(sh('cat "' .. lk .. '/held"'):find(pid, 1, true), "the old holder's file is left alone")
end)

test("l26: a dead pid's slot is taken over, a live one is not", function()
	local d = tree("slotstale")
	local lk = d .. "/locks"
	sh('mkdir -p "' .. lk .. '"')
	holders(lk, 2)
	put(lk .. "/held.999999", "999999 " .. os.time() .. "\n")
	local out = run(d, 'WUBER_SUITE_LOCK="' .. lk .. '" WUBER_SUITE_WAIT_MAX=20', "1")
	ok(out:find("taking over a stale suite lock (pid 999999", 1, true) and out:find("shard 1/1", 1, true) and not out:find("waiting for suite lock", 1, true), out)
	eq(sh('ls "' .. lk .. '" | grep -c "^held\\.[0-9]"'):match("%d+"), "2", "the two live holders keep their files")
	eq(sh('ls "' .. lk .. '" | grep -c "^held\\.stale"'):match("%d+"), "0", "the moved-aside file is not named held.*")
	eq(sh('ls "' .. lk .. '" | grep -c "^stale\\.[0-9]"'):match("%d+"), "1", "the moved-aside file is kept as stale.*")
end)

-- job 2925: no flock in Git Bash; a lock that cannot be taken must fail loudly, never wait or run silently
test("l26: an unusable lock folder FAILS LOUDLY (exit 2) and suite.sh needs no flock", function()
	local d = tree("badlock")
	put(d .. "/notafolder", "x\n")
	local out = run(d, 'WUBER_SUITE_LOCK="' .. d .. '/notafolder"', "1")
	ok(out:find("ERROR: cannot use WUBER_SUITE_LOCK", 1, true) and out:find("exit=2", 1, true) and not out:find("shard 1/1", 1, true), out)
	local s = sh('cd "' .. d .. '" && mkdir -p tests && printf "x" > tests/run.lua && WUBER_SUITE_LOCK="' .. d .. '/slk" WUBER_LUA="' .. d .. '/fakelua.sh" bash "' .. ROOT .. '/tools/suite.sh" "' .. d .. '"; echo "exit=$?"')
	ok(s:find("5 passed", 1, true) and s:find("exit=0", 1, true) and not s:find("flock", 1, true), s)
end)

test("l26: a suite started inside a running suite does not wait even with every slot taken", function()
	local d = tree("slotsnested")
	local lk = d .. "/locks"
	sh('mkdir -p "' .. lk .. '"')
	local p = holders(lk, 3)
	local out = run(d, 'WUBER_SUITE_LOCK="' .. lk .. '" WUBER_SUITE_PARENT=' .. p[1], "1")
	ok(not out:find("waiting for suite lock", 1, true) and out:find("shard 1/1", 1, true), out)
end)
