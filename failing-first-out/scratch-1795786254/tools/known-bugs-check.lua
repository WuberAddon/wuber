-- tools/known-bugs-check.lua: checks docs/KNOWN-BUGS.md (the ledger of fixed bugs and the test that holds each).
-- guard: infra
--
--   lua5.1 tools/known-bugs-check.lua [ledger]      (from the repo root; exit 0 = fine, 1 = problems)
--
-- A ledger line starts with "KB-" and has five fields separated by " | ":
--   KB-nnn | source id | what the player saw | fixed in round | tests/x_test.lua :: exact test name
-- Fails on: a malformed line, a duplicated KB id, a test file that does not exist, a test name that is
-- not in that file (as "name"). The last field may be exactly "test not in this repo".
-- Library use: loadfile("tools/known-bugs-check.lua")("--lib") returns check(text, readFile) -> problems.
-- Lua 5.1; reads files only.

local NOTREPO = "test not in this repo"

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- text: the ledger; readFile(path) -> contents or nil. Returns a list of problem strings.
local function check(text, readFile)
	local problems, seen, count = {}, {}, 0
	local n = 0
	for line in (text .. "\n"):gmatch("(.-)\r?\n") do
		n = n + 1
		if line:match("^KB%-") then
			count = count + 1
			local f, rest = {}, line
			for _ = 1, 4 do
				local a, b = rest:find(" | ", 1, true)
				if not a then break end
				f[#f + 1] = trim(rest:sub(1, a - 1))
				rest = rest:sub(b + 1)
			end
			f[#f + 1] = trim(rest)
			local id = f[1]
			if #f ~= 5 or f[2] == "" or f[3] == "" or f[4] == "" or f[5] == "" then
				problems[#problems + 1] = "line " .. n .. ": needs five fields (id | source | symptom | round | test)"
			elseif not id:match("^KB%-%d%d%d+$") then
				problems[#problems + 1] = "line " .. n .. ": bad id '" .. id .. "' (want KB-nnn)"
			else
				if seen[id] then
					problems[#problems + 1] = "line " .. n .. ": " .. id .. " is duplicated (first on line " .. seen[id] .. ")"
				end
				seen[id] = seen[id] or n
				local path, name = f[5]:match("^(.-) :: (.+)$")
				if f[5] ~= NOTREPO then
					if not path then
						problems[#problems + 1] = "line " .. n .. ": " .. id .. " last field must be 'file :: test name' or '" .. NOTREPO .. "'"
					else
						local body = readFile(path)
						if not body then
							problems[#problems + 1] = "line " .. n .. ": " .. id .. " test file does not exist: " .. path
						elseif not body:find('"' .. name .. '"', 1, true) and not body:find("'" .. name .. "'", 1, true) then
							problems[#problems + 1] = "line " .. n .. ": " .. id .. " test name not found in " .. path .. ": " .. name
						end
					end
				end
			end
		end
	end
	return problems, count
end

if (...) == "--lib" then return check end

local function reader(path)
	local fh = io.open(path, "rb")
	if not fh then return nil end
	local s = fh:read("*a")
	fh:close()
	return s
end

local ledger = arg and arg[1] or "docs/KNOWN-BUGS.md"
local text = reader(ledger)
if not text then
	io.stderr:write("known-bugs-check: cannot read " .. ledger .. "\n")
	os.exit(1)
end
local problems, count = check(text, reader)
for _, p in ipairs(problems) do print(p) end
print(("known-bugs-check: %d entries, %d problems"):format(count, #problems))
os.exit(#problems == 0 and 1 - 1 or 1)
