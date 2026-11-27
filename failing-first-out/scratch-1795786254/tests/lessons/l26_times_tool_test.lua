-- tools/refresh-test-times.lua: turns a finished full run's times file into the committed plan fixture.
-- The tool runs through the Lua interpreter directly (no bash needed).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local TMP = (os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"):gsub("\\", "/")
local LUA = os.getenv("WUBER_LUA") or os.getenv("LUA") or "lua5.1"
local TOOL = T.dir .. "/../tools/refresh-test-times.lua"

local function run(...)
	local cmd = '"' .. LUA .. '" "' .. TOOL .. '"'
	for _, a in ipairs({ ... }) do cmd = cmd .. ' "' .. a .. '"' end
	cmd = cmd .. " 2>&1"
	if package.config:sub(1, 1) == "\\" then cmd = '"' .. cmd .. '"' end -- cmd.exe drops the outer quotes
	local p = io.popen(cmd)
	local out = p:read("*a")
	p:close()
	return out
end

local function put(path, text)
	local f = assert(io.open(path, "wb"))
	f:write(text)
	f:close()
end

local function get(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local s = f:read("*a")
	f:close()
	return s
end

-- guard: infra, failed before because tools/refresh-test-times.lua did not exist
test("refresh-test-times: writes the run's times in run order, drops junk and repeats, and prints the total", function()
	local i, o = TMP .. "/wuber-l26-in.txt", TMP .. "/wuber-l26-out.txt"
	put(i, "0.500\talpha test\n2.25\tbeta: test\n\nnot a line\n1.000\talpha test\n0.250\tgamma\r\n")
	os.remove(o)
	local out = run(i, o)
	eq(get(o), "1.000\talpha test\n2.250\tbeta: test\n0.250\tgamma\n", "run order, three tests, one line each")
	ok(out:find("3 tests, 3.5 s total", 1, true), "prints the count and the total, got: " .. out)
	ok(run("--help"):find("refresh%-test%-times"), "--help names the tool")
	os.remove(i) os.remove(o)
end)

-- guard: infra, failed before because the tool wrote a short (filtered) run over a larger fixture
test("refresh-test-times: refuses a run under 90 percent of the fixture, leaves the fixture alone, --force overrides", function()
	local i, o = TMP .. "/wuber-l26g-in.txt", TMP .. "/wuber-l26g-fix.txt"
	local fixture = {}
	for n = 1, 10 do fixture[n] = "1.000\told test " .. n end
	local before = table.concat(fixture, "\n") .. "\n"
	put(o, before)
	put(i, "0.100\told test 1\n0.100\told test 2\n0.100\told test 3\n")
	local out = run(i, o)
	eq(get(o), before, "the fixture is untouched")
	ok(out:find("refus", 1, true) and out:find("--force", 1, true), "says it refuses and names --force, got: " .. out)
	local forced = run("--force", i, o)
	eq(get(o), "0.100\told test 1\n0.100\told test 2\n0.100\told test 3\n", "--force writes it")
	ok(forced:find("3 tests, 0.3 s total", 1, true), "prints the total, got: " .. forced)
	put(o, before)
	local nine = {}
	for n = 1, 9 do nine[n] = "2.000\told test " .. n end
	put(i, table.concat(nine, "\n") .. "\n")
	ok(run(i, o):find("9 tests, 18.0 s total", 1, true), "exactly 90 percent is accepted")
	os.remove(i) os.remove(o)
end)
