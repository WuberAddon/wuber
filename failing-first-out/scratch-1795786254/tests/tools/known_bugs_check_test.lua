-- Tests of tools/known-bugs-check.lua (the checker for docs/KNOWN-BUGS.md).
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local check = assert(loadfile(T.dir .. "/../tools/known-bugs-check.lua"))("--lib")
local files = { ["tests/x_test.lua"] = 'test("KB-001 a thing works", function() end)' }
local function read(p) return files[p] end
local function run(text) return check(text, read) end

local GOOD = "KB-001 | AUD-01 | a rider sees a wrong line | r27 | tests/x_test.lua :: KB-001 a thing works"

-- guard: infra (a tool test; the tool is new)
test("known-bugs-check: a well-formed line passes, and 'test not in this repo' is allowed", function()
	local p, n = run(GOOD .. "\nKB-002 | - | something else | r28 | test not in this repo\n")
	eq(#p, 0, table.concat(p, "; "))
	eq(n, 2)
end)

-- guard: infra
test("known-bugs-check: a duplicated KB id fails", function()
	local p = run(GOOD .. "\n" .. GOOD .. "\n")
	eq(#p, 1)
	ok(p[1]:find("duplicated", 1, true))
end)

-- guard: infra
test("known-bugs-check: a test file that does not exist fails", function()
	local p = run("KB-001 | - | s | r1 | tests/missing_test.lua :: whatever")
	eq(#p, 1)
	ok(p[1]:find("does not exist", 1, true))
end)

-- guard: infra
test("known-bugs-check: a test name that is not in the file fails", function()
	local p = run("KB-001 | - | s | r1 | tests/x_test.lua :: not a test here")
	eq(#p, 1)
	ok(p[1]:find("test name not found", 1, true))
end)

-- guard: infra
test("known-bugs-check: a line with too few fields or a bad id fails", function()
	eq(#run("KB-001 | only | three"), 1)
	eq(#run("KB-1 | - | s | r1 | test not in this repo"), 1)
end)

-- guard: infra
test("known-bugs-check: the shipped docs/KNOWN-BUGS.md is clean (ids unique, every test file and name exists)", function()
	local root = T.dir .. "/.."
	local fh = assert(io.open(root .. "/docs/KNOWN-BUGS.md", "rb"))
	local text = fh:read("*a")
	fh:close()
	local p, n = check(text, function(path)
		local f = io.open(root .. "/" .. path, "rb")
		if not f then return nil end
		local s = f:read("*a")
		f:close()
		return s
	end)
	eq(#p, 0, table.concat(p, "; "))
	ok(n > 0, "the ledger has entries")
end)
