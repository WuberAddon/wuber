-- tools/click-ratchet.lua: the click-path ratchet (Fable item 5). Lua 5.1.
-- A test that clicks a button by calling its script, or by Client:click, skips the hit test the player's mouse goes through
-- (what is on top at the centre, clipping, strata, hit-rect insets). Bug #36 (the dead back arrow) reached the game that way:
-- the tests called OnClick directly and passed. Only Client:clickOn (and clickText, which uses it) goes through the hit test.
-- This counts, per test file under tests/, the calls that bypass it:
--   GetScript("OnClick")   GetScript("PostClick")   :Click(   :click(   (clickOn, clickText and the like are not counted)
-- The counts are stored in tests/click-ratchet.txt (one "<count><TAB><path>" per line). The check FAILS when a file's count rises,
-- or a test file that is not in the file has a direct click. A line that carries "-- direct-click: <reason>" is not counted.
-- Usage: lua5.1 tools/click-ratchet.lua [--check] [--update] [--list] [--root <dir>] [--store <file>] [--help]
--   --check    (default) compare with the store; exit 1 on a rise or a new file, 0 otherwise (a fall is only reported)
--   --update   rewrite the store from the tests as they are now (lowers it; it refuses to raise it: use "-- direct-click:" instead)
--   --list     print every file with its count
--   --root     the repository (default: the current folder); --store: the store (default <root>/tests/click-ratchet.txt)
-- As a library: local R = dofile("tools/click-ratchet.lua"); R.count(text) -> n, lines; R.compare(now, stored) -> problems.
local R = {}

local PATTERNS = {
	'GetScript%(%s*["\']OnClick["\']%s*%)',
	'GetScript%(%s*["\']PostClick["\']%s*%)',
	':Click%(',
	':click%(',
}
R.PATTERNS = PATTERNS
-- (the code of a line is set below as R.code)

-- the part of a line before a "--" comment that is not inside a string (good enough for test code: quotes are balanced per line)
local function code(line)
	local q, i = nil, 1
	while i <= #line do
		local c = line:sub(i, i)
		if q then
			if c == "\\" then i = i + 1 elseif c == q then q = nil end
		elseif c == '"' or c == "'" then q = c
		elseif c == "-" and line:sub(i, i + 1) == "--" then return line:sub(1, i - 1) end
		i = i + 1
	end
	return line
end

R.code = code

-- n = the direct clicks in the text (not counting a line that says why with "-- direct-click: <reason>"); lines = their line numbers
function R.count(text)
	local n, lines, ln = 0, {}, 0
	for line in (text .. "\n"):gmatch("(.-)\r?\n") do
		ln = ln + 1
		local reason = line:match("%-%-%s*direct%-click:%s*(%S.*)$")
		if not reason then
			local c = code(line)
			for _, p in ipairs(PATTERNS) do
				for _ in c:gmatch(p) do n = n + 1 lines[#lines + 1] = ln end
			end
		end
	end
	return n, lines
end

local function skip(path)
	return path:find("^tests/out/") or path:find("^tests/lib/") or path:find("^tests/fixtures/") or path:find("^tests/preview/")
		or path:find("^tests/harness[^/]*%.lua$") or path:find("^tests/run%.lua$") or path:find("^tests/hunt/")
end

local function readFile(p)
	local f = io.open(p, "rb")
	if not f then return nil end
	local s = f:read("*a") f:close()
	return s
end

-- every tracked or new .lua file under tests/ (git); falls back to dir listing is not needed: the tool runs in a repository
function R.files(root)
	local out, seen = {}, {}
	for _, cmd in ipairs({ "git ls-files -- tests", "git ls-files --others --exclude-standard -- tests" }) do
		local p = io.popen('cd "' .. root .. '" && ' .. cmd .. " 2>&1")
		if p then
			for l in p:lines() do
				l = l:gsub("\r", "")
				if l:match("%.lua$") and not seen[l] and not skip(l) then seen[l] = true out[#out + 1] = l end
			end
			p:close()
		end
	end
	table.sort(out)
	return out
end

-- now: { [path] = count } for the files with at least one direct click
function R.scan(root, files)
	local now = {}
	for _, path in ipairs(files or R.files(root)) do
		local text = readFile(root .. "/" .. path)
		if text then
			local n = R.count(text)
			if n > 0 then now[path] = n end
		end
	end
	return now
end

function R.load(store)
	local t = {}
	local s = readFile(store)
	if not s then return t, false end
	for line in s:gmatch("[^\r\n]+") do
		if not line:match("^#") then
			local n, p = line:match("^(%d+)%s+(.+)$")
			if n then t[p] = tonumber(n) end
		end
	end
	return t, true
end

-- problems: a rise, or a new file; falls: files whose count went down (or to zero)
function R.compare(now, stored)
	local problems, falls = {}, {}
	for path, n in pairs(now) do
		local was = stored[path]
		if was == nil then problems[#problems + 1] = path .. ": " .. n .. " direct click(s) in a file the ratchet has not seen; click with Client:clickOn, or add '-- direct-click: <reason>' to the line"
		elseif n > was then problems[#problems + 1] = path .. ": direct clicks rose " .. was .. " -> " .. n .. "; click with Client:clickOn, or add '-- direct-click: <reason>' to the line" end
	end
	for path, was in pairs(stored) do
		local n = now[path] or 0
		if n < was then falls[#falls + 1] = path .. ": " .. was .. " -> " .. n end
	end
	table.sort(problems) table.sort(falls)
	return problems, falls
end

function R.write(store, now)
	local paths = {}
	for p in pairs(now) do paths[#paths + 1] = p end
	table.sort(paths)
	local out = { "# tests/click-ratchet.txt: direct clicks (GetScript OnClick, :Click, :click) per test file; written by tools/click-ratchet.lua --update.",
		"# The count may only go down. A new button test clicks with Client:clickOn (the hit test); a direct click needs '-- direct-click: <reason>' on its line." }
	for _, p in ipairs(paths) do out[#out + 1] = now[p] .. "\t" .. p end
	local f = assert(io.open(store, "wb"))
	f:write(table.concat(out, "\n"), "\n") f:close()
end

local function main(argv)
	local mode, root, store = "check", ".", nil
	local i = 1
	while i <= #argv do
		local a = argv[i]
		if a == "--help" or a == "-h" then
			io.write([[
tools/click-ratchet.lua: counts the test clicks that skip the hit test (GetScript("OnClick")(...), :Click(, :click( ) per file.
  lua5.1 tools/click-ratchet.lua [--check|--update|--list] [--root <dir>] [--store <file>]
  --check   (default) fail (exit 1) when a file's count rises or a new test file has a direct click
  --update  rewrite tests/click-ratchet.txt (only ever lowers it)
  --list    every file with its count
A line with "-- direct-click: <reason>" is not counted. Click with Client:clickOn instead.
]])
			return 0
		elseif a == "--check" or a == "--update" or a == "--list" then mode = a:sub(3)
		elseif a == "--root" then i = i + 1 root = argv[i]
		elseif a == "--store" then i = i + 1 store = argv[i]
		else io.stderr:write("click-ratchet: unknown argument " .. a .. " (--help)\n") return 2 end
		i = i + 1
	end
	store = store or (root .. "/tests/click-ratchet.txt")
	local now = R.scan(root)
	if mode == "list" then
		local paths, total = {}, 0
		for p, n in pairs(now) do paths[#paths + 1] = p total = total + n end
		table.sort(paths)
		for _, p in ipairs(paths) do print(now[p] .. "\t" .. p) end
		print("total " .. total .. " in " .. #paths .. " files")
		return 0
	end
	local stored, exists = R.load(store)
	local problems, falls = R.compare(now, stored)
	if mode == "update" then
		if exists and #problems > 0 then
			for _, p in ipairs(problems) do print("click-ratchet: " .. p) end
			print("click-ratchet: FAIL: --update only lowers the counts")
			return 1
		end
		R.write(store, now)
		print("click-ratchet: wrote " .. store)
		return 0
	end
	if not exists then print("click-ratchet: FAIL: no store " .. store .. " (lua5.1 tools/click-ratchet.lua --update)") return 1 end
	for _, p in ipairs(problems) do print("click-ratchet: " .. p) end
	for _, p in ipairs(falls) do print("click-ratchet: lower (run --update to keep it): " .. p) end
	if #problems > 0 then print("click-ratchet: FAIL: " .. #problems .. " file(s)") return 1 end
	local total = 0
	for _, n in pairs(now) do total = total + n end
	print("click-ratchet: PASS (" .. total .. " direct clicks, none more than the store)")
	return 0
end

if arg and arg[0] and arg[0]:gsub("\\", "/"):match("click%-ratchet%.lua$") then os.exit(main(arg)) end
return R
