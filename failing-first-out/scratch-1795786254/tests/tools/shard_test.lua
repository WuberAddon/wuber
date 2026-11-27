-- tests/tools/shard_test.lua: the split suite (tests/lib/shard.lua, tools/suite-par.sh).
-- A small run of four tests over two shards, in a folder of its own (tests/out/shard-selftest):
-- each test goes to one shard, the join puts the transcript back in test order byte for byte,
-- counts and failures add up, the report tables merge as one run's would, and a shard that did
-- not finish is a problem, not a pass.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local SH = dofile(T.dir .. "/lib/shard.lua")
local root = T.dir .. "/out/shard-selftest"

local function fakeH()
	return { used = { method = {}, api = {} }, unknown = {}, missingGlobals = {}, uncertain = {}, release = function() end }
end
local function slurp(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local s = f:read("*a")
	f:close()
	return s
end
local function put(path, text)
	local f = assert(io.open(path, "wb"))
	f:write(text)
	f:close()
end

test("suite-par: the longest test first, each to the least loaded shard; the same plan every time", function()
	local list = { { 1, "a" }, { 9, "b" }, { 2, "c" }, { 8, "d" }, { 2, "e" } }
	local plan = SH.balance(list, 2)
	eq(plan.b, 1, "the longest to shard 1")
	eq(plan.d, 2, "the next to the emptier shard")
	eq(plan.c, 2) eq(plan.e, 1) eq(plan.a, 2)
	local again = SH.balance(list, 2)
	for _, e in ipairs(list) do eq(again[e[2]], plan[e[2]], "same plan for " .. e[2]) end
end)

test("suite-par: two shards' files join into the serial order, counts, failures and report tables", function()
	local names = { "one", "two", "three", "four" }
	local records = {}
	for i, n in ipairs(names) do records[i] = "=== " .. n .. (i == 3 and " (FAILED)" or "") .. "\n  world 1 time " .. i .. "\n" end
	-- the two shards (round robin: a filter is given)
	for k = 1, 2 do
		local H = fakeH()
		local sh = SH.new(root, H, k .. "/2", nil, "x")
		local skipped, part = {}, {}
		local tr = { skip = function(name) skipped[#skipped + 1] = name end }
		for i, n in ipairs(names) do
			if not sh.skip(n, tr) then
				H.used.method.Show = "Wuber/UI/" .. n .. ".lua:1" -- first use: the earliest test's
				H.unknown["Frame:Foo"] = "Wuber/" .. n .. ".lua:2" -- last write: the latest test's
				part[#part + 1] = records[i]
				sh.done(n, i ~= 3, i == 3 and "boom\nline two" or nil, true)
			end
		end
		eq(#skipped, 2, "shard " .. k .. " skipped the other's two")
		sh.finish(0, 0)
		put(SH.partName(root, "transcript", k, 2, "txt"), table.concat(part))
	end
	-- the join
	local H = fakeH()
	local j = SH.new(root, H, nil, "2")
	for _, n in ipairs(names) do ok(j.skip(n), "the join runs no test") end
	local said = {}
	local res = j:join(root, H, root .. "/out/joined.txt", function(s) said[#said + 1] = s end)
	eq(#res.problems, 0, table.concat(res.problems, "; "))
	eq(res.passed, 3) eq(res.failed, 1)
	eq(res.failures[1], "three")
	ok(said[1] and said[1]:find("FAIL  three  (shard 1)", 1, true) and said[1]:find("boom\n      line two", 1, true), tostring(said[1]))
	eq(slurp(root .. "/out/joined.txt"), table.concat(records), "the transcript in test order, byte for byte")
	eq(H.used.method.Show, "Wuber/UI/one.lua:1", "first use: from test 1")
	eq(H.unknown["Frame:Foo"], "Wuber/four.lua:2", "last write: from test 4")
	ok(slurp(root .. "/out/times.txt"):find("\tfour\n", 1, true), "the times for the next run")
	-- a shard that did not finish: no end line
	local path = SH.partName(root, "results", 2, 2, "txt")
	local text = slurp(path)
	put(path, (text:gsub("E\t[^\n]*\n$", "")))
	local j2 = SH.new(root, fakeH(), nil, "2")
	for _, n in ipairs(names) do j2.skip(n) end
	local res2 = j2:join(root, fakeH(), nil, function() end)
	ok(#res2.problems >= 1 and res2.problems[1]:find("did not finish", 1, true), table.concat(res2.problems, "; "))
	os.remove(path)
	local j3 = SH.new(root, fakeH(), nil, "2")
	for _, n in ipairs(names) do j3.skip(n) end
	local res3 = j3:join(root, fakeH(), nil, function() end)
	local all = table.concat(res3.problems, "; ")
	ok(all:find("no results file", 1, true) and all:find("not run by any shard: two", 1, true), all)
end)

test("suite-par: a full run's times drop tests that no longer exist; a filtered run keeps the others'", function()
	local names = { "one", "two", "three", "four" }
	for k = 1, 2 do
		local H = fakeH()
		local sh = SH.new(root, H, k .. "/2", nil, "x")
		local part = {}
		for i, n in ipairs(names) do
			if not sh.skip(n, { skip = function() end }) then
				part[#part + 1] = "=== " .. n .. "\n"
				sh.done(n, true, nil, true)
			end
		end
		sh.finish(0, 0)
		put(SH.partName(root, "transcript", k, 2, "txt"), table.concat(part))
	end
	local function joinWith(filter)
		put(root .. "/out/times.txt", "146.000\tgone\n1.000\tone\n")
		local j = SH.new(root, fakeH(), nil, "2", filter)
		for _, n in ipairs(names) do j.skip(n) end
		local res = j:join(root, fakeH(), nil, function() end)
		eq(#res.problems, 0, table.concat(res.problems, "; "))
		return slurp(root .. "/out/times.txt")
	end
	local full = joinWith(nil)
	ok(full:find("\tfour\n", 1, true) and full:find("\tone\n", 1, true), "this run's times")
	ok(not full:find("\tgone\n", 1, true), "a full run drops a test that no longer exists: " .. full)
	ok(joinWith("x"):find("\tgone\n", 1, true), "a filtered run keeps the times of tests it did not run")
end)
