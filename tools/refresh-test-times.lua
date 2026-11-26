-- tools/refresh-test-times.lua: rewrite the plan fixture from a finished full run (Lua 5.1).
--
--   lua5.1 tools/refresh-test-times.lua [--help] [--force] [<run times file> [<fixture>]]      (from the repo root)
--
-- Defaults: the run times file is tests/out/times.txt (a full run writes it when its shards are joined);
-- the fixture is tests/fixtures/test-times.txt, which tools/quick-select.lua and the shard plan read.
-- Both files hold one line per test: seconds, a TAB, the test name.
-- The fixture gets exactly the tests of that run, in the run's order, each with its seconds to 3 places.
-- Tests that are not in the run are dropped (they no longer exist, or the run was filtered: use a FULL run).
-- A name seen twice keeps its first place and its last time. Lines that are not "seconds TAB name" are skipped.
-- Guard: a filtered run has far fewer tests than a full one, so when the new count is below 90% of the existing
-- fixture's line count the tool refuses (exit 2, message, fixture untouched) unless --force is given.
-- Prints: "N tests, M s total". Exit 0; exit 2 for a missing or empty input or a refusal (the fixture is then left alone).
local args, force = {}, false
for _, a in ipairs({ ... }) do
	if a == "--force" then force = true else args[#args + 1] = a end
end
if args[1] == "--help" or args[1] == "-h" then
	io.write("refresh-test-times: lua5.1 tools/refresh-test-times.lua [--force] [<run times file> [<fixture>]]\n",
		"Rewrites the fixture (default tests/fixtures/test-times.txt) from a full run's times\n",
		"(default tests/out/times.txt): the run's tests only, in run order. Refuses a run under 90% of the\n",
		"fixture's line count unless --force. Prints \"N tests, M s total\".\n")
	return
end
local inPath = args[1] or "tests/out/times.txt"
local outPath = args[2] or "tests/fixtures/test-times.txt"

local f = io.open(inPath, "rb")
if not f then io.stderr:write("no times file: " .. inPath .. "\n") os.exit(2) end
local text = f:read("*a")
f:close()

local order, secs = {}, {}
for line in text:gmatch("[^\r\n]+") do
	local t, name = line:match("^([%d%.]+)\t(.+)$")
	if t and tonumber(t) then
		if secs[name] == nil then order[#order + 1] = name end
		secs[name] = tonumber(t)
	end
end
if #order == 0 then io.stderr:write("no test times in " .. inPath .. "\n") os.exit(2) end

local old = io.open(outPath, "rb")
if old and not force then
	local n = 0
	for _ in old:read("*a"):gmatch("[^\r\n]+") do n = n + 1 end
	old:close()
	if #order < n * 0.9 then
		io.stderr:write(("refusing: %d tests in %s is under 90%% of the %d lines in %s (a filtered run?). Use --force to write it anyway.\n"):format(#order, inPath, n, outPath))
		os.exit(2)
	end
elseif old then old:close() end

local lines, total = {}, 0
for i, name in ipairs(order) do
	lines[i] = ("%.3f\t%s"):format(secs[name], name)
	total = total + secs[name]
end
local o = assert(io.open(outPath, "wb"))
o:write(table.concat(lines, "\n"), "\n")
o:close()
print(("%d tests, %.1f s total"):format(#order, total))
