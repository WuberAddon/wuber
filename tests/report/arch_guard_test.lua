-- tests/report/arch_guard_test.lua: tools/arch-guard.lua fails a branch whose diff against the base touches ARCHITECTURE.md.
-- Runs on a tiny git repository it makes in tests/out/arch-guard-selftest/repo (a folder every run reuses; nothing is deleted).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local windows = package.config:sub(1, 1) == "\\"
local function sh(cmd)
	-- (Lua 5.1's close() does not give the exit code: the shell says it)
	local p = io.popen(cmd .. " 2>&1 && echo EXIT0 || echo EXIT1")
	local out = p:read("*a")
	p:close()
	local good = out:find("EXIT0", 1, true) ~= nil
	return (out:gsub("EXIT[01]%s*$", "")), good
end
local function native(path) return windows and path:gsub("/", "\\") or path end
local guard = T.dir .. "/../tools/arch-guard.lua"
local repoBase = T.dir .. "/out/arch-guard-selftest"
local repo = repoBase .. "/repo"
local runNo = 0
local function git(args)
	return sh('git -C "' .. native(repo) .. '" -c core.hooksPath=none-here -c user.name="Anita Lift" -c user.email=anita-lift' .. string.char(64) .. 'users.noreply.github.com ' .. args)
end
local function put(name, text)
	local f = assert(io.open(repo .. "/" .. name, "wb"))
	f:write(text)
	f:close()
end
local function runGuard(env)
	local cmd = 'lua5.1 "' .. native(guard) .. '" --root "' .. native(repo) .. '" --base origin/main'
	if windows then cmd = (env and ('set "' .. env .. '" && ') or "") .. cmd else cmd = (env and (env .. " ") or "") .. cmd end
	return sh(cmd)
end

local function fresh()
	-- A new folder per call (never reused, nothing deleted): a leftover branch or file from an earlier run or another shard
	-- cannot change what the guard sees.
	runNo = runNo + 1
	repo = repoBase .. "/r" .. tostring(os.time()) .. "-" .. tostring(math.floor(os.clock() * 1000000)) .. "-" .. runNo
	sh(windows and ('mkdir "' .. native(repoBase) .. '" 2>nul') or ('mkdir -p "' .. repoBase .. '"'))
	sh(windows and ('mkdir "' .. native(repo) .. '"') or ('mkdir -p "' .. repo .. '"'))
	git("init -q")
	local stamp = tostring(os.time()) .. tostring(math.floor(os.clock() * 1000))
	git("checkout -q -B main")
	put("ARCHITECTURE.md", "map " .. stamp .. "\n")
	put("other.txt", "one " .. stamp .. "\n")
	git("add -A")
	git("commit -q -m base")
	git("update-ref refs/remotes/origin/main HEAD")
	git("checkout -q -B feature")
end

test("arch-guard: a branch that leaves ARCHITECTURE.md alone passes; a missing base is skipped, not failed", function()
	fresh()
	put("other.txt", "two\n")
	git("add -A")
	git("commit -q -m work")
	local out, good = runGuard()
	ok(good and out:find("arch-guard: PASS", 1, true), "passes: " .. out)
	local none, good2 = sh('lua5.1 "' .. native(guard) .. '" --root "' .. native(T.dir .. "/out") .. '" --base nosuchref')
	ok(good2 and none:find("SKIPPED", 1, true), "no base: skipped, exit 0: " .. none)
end)

test("arch-guard: a commit that edits ARCHITECTURE.md fails with a clear message naming the file and the way back", function()
	fresh()
	put("ARCHITECTURE.md", "regenerated on a branch\n")
	git("add -A")
	git("commit -q -m regen")
	local out, good = runGuard()
	ok(not good, "exit code is not 0: " .. out)
	ok(out:find("arch-guard: FAIL", 1, true) and out:find("changes ARCHITECTURE.md", 1, true), "says it: " .. out)
	ok(out:find("git checkout origin/main -- ARCHITECTURE.md", 1, true), "names the way back: " .. out)
end)

test("arch-guard: an uncommitted edit of ARCHITECTURE.md fails too; the maintainer's WUBER_ARCH_REGEN=1 lets it pass", function()
	fresh()
	put("ARCHITECTURE.md", "edited, not committed\n")
	local out, good = runGuard()
	ok(not good and out:find("FAIL", 1, true), "working-tree edit fails: " .. out)
	local out2, good2 = runGuard("WUBER_ARCH_REGEN=1")
	ok(good2 and out2:find("WUBER_ARCH_REGEN=1", 1, true), "regeneration passes and says so: " .. out2)
end)

local function fakeMap()
	-- map.lua is found by --root; its --check reads ARCHITECTURE.md relative to the working folder, so the guard's cwd matters:
	-- the fake reads the path next to itself instead.
	sh(windows and ('mkdir "' .. native(repo .. "/tools") .. '"') or ('mkdir -p "' .. repo .. '/tools"'))
	put("tools/map.lua", 'local d = (arg[0]:gsub("\\\\", "/"):match("^(.*)/tools/[^/]*$")) or "."\nlocal f = io.open(d .. "/ARCHITECTURE.md", "rb")\nlocal s = f and f:read("*a")\nif f then f:close() end\nif s ~= "MAP\\n" then os.exit(1) end\n')
end

test("arch-guard: a commit whose only change to ARCHITECTURE.md is what map.lua --check accepts passes", function()
	fresh()
	fakeMap()
	put("ARCHITECTURE.md", "MAP\n")
	git("add -A")
	git("commit -q -m regen")
	local out, good = runGuard()
	ok(good and out:find("arch-guard: PASS", 1, true) and out:find("map.lua --write produces", 1, true), "regeneration passes: " .. out)
end)

test("arch-guard: with map.lua present, a hand-edited ARCHITECTURE.md still fails", function()
	fresh()
	fakeMap()
	put("ARCHITECTURE.md", "hand edited\n")
	git("add -A")
	git("commit -q -m hand")
	local out, good = runGuard()
	ok(not good and out:find("arch-guard: FAIL", 1, true), "stale/hand edit fails: " .. out)
end)

test("arch-guard: quick-check.sh runs it", function()
	local f = assert(io.open(T.dir .. "/../tools/quick-check.sh", "rb"))
	local text = f:read("*a")
	f:close()
	ok(text:find("tools/arch-guard.lua", 1, true), "tools/quick-check.sh names tools/arch-guard.lua")
end)
