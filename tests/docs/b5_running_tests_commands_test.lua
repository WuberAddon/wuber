-- Gate for docs/RUNNING-TESTS.md: every tool/test path (except runtime tests/out/)
-- and every command-line flag named in docs/RUNNING-TESTS.md must exist, and
-- each tool's --help must know the flag(s) documented for it (never runs the full suite).
local T = ...
local test, ok = T.test, T.ok

local function readAll(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local s = f:read("*a")
	f:close()
	return s
end

local function runHelp(cmd)
	local p = io.popen(cmd .. " 2>&1")
	if not p then return nil end
	local out = p:read("*a")
	p:close()
	return out
end

test("docs/RUNNING-TESTS.md: paths exist and tool --help knows documented flags", function()
	local root = T.dir .. "/.."
	local doc = readAll(root .. "/docs/RUNNING-TESTS.md")
	ok(doc, "docs/RUNNING-TESTS.md exists")
	if not doc then return end

	-- 1. Extract every tools/... and tests/... path (and scrub-check.py / scrub-patterns.public.txt)
	local paths = {}
	for p in doc:gmatch("tools/[%w_./-]+") do
		if p:match("%.[%w]+$") then paths[p] = true end
	end
	for p in doc:gmatch("tests/[%w_./-]+") do
		if p:match("%.[%w]+$") and not p:match("^tests/out/") then
			paths[p] = true
		end
	end
	for p in doc:gmatch("scrub%-[%w_.-]+") do
		if p:match("%.[%w]+$") then paths[p] = true end
	end

	local pathCount = 0
	for rel in pairs(paths) do
		pathCount = pathCount + 1
		ok(readAll(root .. "/" .. rel) ~= nil, "path exists on disk: " .. rel)
	end
	ok(pathCount >= 7, "extracted at least 7 tool/test paths (got " .. pathCount .. ")")

	-- 2. Extract every --flag in docs/RUNNING-TESTS.md and verify the owning tool's --help knows it
	local toolForFlag = {}
	local currentTool = nil
	for line in (doc .. "\n"):gmatch("(.-)\r?\n") do
		local t = line:match("tools/[%w_.-]+%.[%w]+") or line:match("scrub%-check%.py")
		if t then currentTool = t end
		for flag in line:gmatch("(%-%-[%w-]+)") do
			if flag ~= "--help" then
				toolForFlag[#toolForFlag + 1] = { tool = currentTool, flag = flag }
			end
		end
	end

	local helpCache = {}
	local luaExe = os.getenv("WUBER_LUA") or "lua5.1"
	local pyExe = os.getenv("PYTHON") or "python"
	local function getHelp(tool)
		if helpCache[tool] ~= nil then return helpCache[tool] end
		local runner = tool:match("%.py$") and pyExe or luaExe
		local target = (root == "tests/..") and tool or (root .. "/" .. tool)
		local out = runHelp(string.format('%s %s --help', runner, target))
		helpCache[tool] = out or false
		return helpCache[tool]
	end

	ok(#toolForFlag >= 2, "extracted at least 2 documented flags (got " .. #toolForFlag .. ")")
	for _, entry in ipairs(toolForFlag) do
		ok(entry.tool ~= nil, "flag " .. entry.flag .. " has an associated tool")
		if entry.tool then
			local help = getHelp(entry.tool)
			ok(help and help:find(entry.flag, 1, true), entry.tool .. " --help documents " .. entry.flag)
		end
	end
end)
