-- tools/coverage-map.lua: which Wuber/ files each test executed (file granularity), for tools/tests-for.lua --coverage.
--
--   lua5.1 tools/coverage-map.lua ["<filter>"] [--out=<file>] [--append] [--shard K/N | --join N]   (from the repo root)
--
-- Sharded (the same split as run.lua --shard; shard K writes tests/out/coverage-map.K.txt, --join N merges them):
--   for k in $(seq 1 16); do lua5.1 tools/coverage-map.lua --shard $k/16 > tests/out/cm-$k.log 2>&1 & done; wait; lua5.1 tools/coverage-map.lua --join 16
--
-- (job 2690: the file name is matched at any depth, Wuber/UI/Rider/Trips.lua too; the first version stopped at one folder level, so no
-- UI/Rider, UI/Driver, UI/Map or UI/Settings file was ever in a map built with it.)
-- (the boot of a world is left out and marked "@boot", see the hook below)
-- Runs tests/run.lua in this process with the filter (default: every test; the same substring match as
-- "tests/run.lua <filter>") and a debug.sethook on the "call" event only: each call looks up the source of
-- the called function once (cached per function) and notes the file when it is under Wuber/. No line hook, so a
-- comment-only change is not tracked by line; this is a file map: "this test ran code of that file".
-- Writes tests/out/coverage-map.txt (or --out): one line per test, "<test name> TAB <file>,<file>,..." with files
-- relative to Wuber/ (e.g. UI/Widgets.lua). --append keeps the lines of tests this run does not cover, so a map can
-- be built a filter at a time. Cost: about 3.7 s a test with the hook on, about 0.7 s without (measured on "tips", 40 tests:
-- 147 s against 29 s; the hook looks a function up in a weak cache and asks for its source only once). The suite is
-- about 4,070 tests, so a full build is about 4 hours on one core, about 15 to 20 minutes on 16 shards; never run it
-- while other work shares the CPU). Needs WUBER_LAB_DIR like the suite. Lua 5.1.

local filter, out, append, shard, join = nil, nil, false, nil, nil
do
	local argv, i = arg or {}, 1
	while argv[i] do
		local a = argv[i]
		if a:match("^%-%-out=") then out = a:sub(7) elseif a == "--append" then append = true
		elseif a == "--shard" then shard, i = argv[i + 1], i + 1
		elseif a == "--join" then join, i = argv[i + 1], i + 1
		elseif not filter then filter = a end
		i = i + 1
	end
end
local root = ((arg and arg[0] or "tools/coverage-map.lua"):gsub("\\", "/"):match("^(.*)/tools/[^/]*$")) or "."
local K = shard and shard:match("^(%d+)/%d+$")
out = out or (root .. "/tests/out/coverage-map" .. (K and ("." .. K) or "") .. ".txt")

if join then -- --join N: merge coverage-map.1.txt .. coverage-map.N.txt into coverage-map.txt, run nothing
	local lines = {}
	for k = 1, tonumber(join) or 0 do
		local f = io.open(root .. "/tests/out/coverage-map." .. k .. ".txt", "rb")
		if not f then io.stderr:write("coverage-map: shard " .. k .. " left no file\n") os.exit(1) end
		for line in f:read("*a"):gmatch("[^\r\n]+") do lines[#lines + 1] = line end
		f:close()
	end
	table.sort(lines)
	local f = assert(io.open(out, "wb"))
	f:write(table.concat(lines, "\n"), "\n")
	f:close()
	io.stderr:write(("coverage-map: joined %d shards, %d tests in %s\n"):format(tonumber(join), #lines, out))
	os.exit(0)
end

package.path = root .. "/tests/?.lua;" .. package.path
local H = require("harness") -- run.lua's own require gets this same table

local map, order, cur = {}, {}, nil
H.onTestStart = function(name)
	cur = {}
	if not map[name] then order[#order + 1] = name end
	map[name] = cur
end

-- (job 2690) a world's boot (World:addClient: the addon's files load and PLAYER_LOGIN runs every module's start-up) is not recorded as the
-- test's own use of a file: the first map recorded all 111 files for each of the 2,141 tests that make a client, so every change selected
-- half the suite. A test that makes a client gets the marker "@boot" instead; tools/quick-select.lua runs the tests that hold only "@boot"
-- (they assert what the boot left) for any changed Wuber file, and the others only for the files they ran after the boot.
local realNewWorld, wrappedClient = H.NewWorld, false
H.NewWorld = function(...)
	local w = realNewWorld(...)
	local mt = not wrappedClient and getmetatable(w)
	local idx = mt and mt.__index
	if type(idx) == "table" and type(idx.addClient) == "function" then
		local realAdd = idx.addClient
		idx.addClient = function(...)
			local saved = cur
			if saved then saved["@boot"] = true end
			cur = nil
			local r = { realAdd(...) }
			cur = saved
			return unpack(r)
		end
		wrappedClient = true
	end
	return w
end

local cache = setmetatable({}, { __mode = "k" })
local getinfo = debug.getinfo
local function callHook()
	if not cur then return end
	local i = getinfo(2, "f") -- the cheap query first; the source only for a function not seen before
	if not i then return end
	local fn = i.func
	local rel = cache[fn]
	if rel == nil then
		rel = tostring(getinfo(2, "S").source):gsub("\\", "/"):match("/Wuber/([%w_/]+%.lua)$") or false
		cache[fn] = rel
	end
	if rel then cur[rel] = true end
end
local realSethook = debug.sethook
realSethook(callHook, "c")
-- (job 2690) tests/hunt/lib.lua and tools/rec/import.lua clear the hook with debug.sethook() when they are done (they set their own
-- loop guard): from then on a process recorded nothing, and every later test held only "@boot". A bare debug.sethook() now puts this
-- hook back, and every test start does too.
debug.sethook = function(...)
	if select("#", ...) == 0 then return realSethook(callHook, "c") end
	return realSethook(...)
end
local startedBefore = H.onTestStart
H.onTestStart = function(name)
	realSethook(callHook, "c")
	return startedBefore(name)
end

local function write()
	realSethook()
	local old = {}
	if append then
		local f = io.open(out, "rb")
		if f then
			for line in f:read("*a"):gmatch("[^\r\n]+") do
				local n, fl = line:match("^(.-)\t(.*)$")
				if n and not map[n] then old[#old + 1] = line end
			end
			f:close()
		end
	end
	local lines = old
	for _, name in ipairs(order) do
		local fl = {}
		for fn in pairs(map[name]) do fl[#fl + 1] = fn end
		table.sort(fl)
		lines[#lines + 1] = name .. "\t" .. table.concat(fl, ",")
	end
	table.sort(lines)
	local f = assert(io.open(out, "wb"))
	f:write(table.concat(lines, "\n"), "\n")
	f:close()
	io.stderr:write(("coverage-map: %d tests this run, %d lines in %s\n"):format(#order, #lines, out))
end
local realExit = os.exit
os.exit = function(code) write() realExit(code) end

arg = { [-1] = arg and arg[-1], [0] = root .. "/tests/run.lua" } -- (tests that start tools use arg[-1], the interpreter)
if filter then arg[#arg + 1] = filter end
if shard then arg[#arg + 1] = "--shard" arg[#arg + 1] = shard end -- the same split as run.lua --shard
dofile(root .. "/tests/run.lua")
write()
