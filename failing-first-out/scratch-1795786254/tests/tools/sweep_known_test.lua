-- tests/tools/sweep_known_test.lua: what the bug hunt's FAILURES.md says about KNOWN (tools/hunt/sweep.lua --plan / --join on a
-- tiny fake out folder, as tests/tools/sweep_own_repro_test.lua does). The same promise as a repro file but another line is a
-- NEW finding that names the repro ("same promise as <id> (other line)"); a known-elsewhere row without a line (coachsteps.
-- got_it_is_final in tests/hunt/known-elsewhere.tsv) is known and marked "whole promise, line not checked".
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local LUA = os.getenv("WUBER_LUA") or "lua5.1"
local base = T.dir .. "/out/sweep-known"

local function slurp(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local s = f:read("*a")
	f:close()
	return (s:gsub("\r\n", "\n")) -- a checkout with CRLF endings must read the same
end
local function put(path, text)
	local f = assert(io.open(path, "wb"))
	f:write(text)
	f:close()
end
local function sh(cmd)
	local p = io.popen("cd " .. T.dir .. "/.. && " .. cmd .. " 2>&1")
	local out = p:read("*a")
	p:close()
	return out
end

test("hunt sweep join: another line of a promise with a repro is NEW and linked; a whole-promise elsewhere row is marked", function()
	local out, known, repro = base .. "/out", base .. "/known", base .. "/repro"
	for _, d in ipairs({ out, known, repro }) do
		if package.config:sub(1, 1) == "\\" then os.execute('mkdir "' .. d:gsub("/", "\\") .. '" >nul 2>&1') else os.execute('mkdir -p "' .. d .. '"') end
	end
	for _, f in ipairs({ "groups.lua", "shrunk.1-of-1.lua", "FAILURES.md", "summary.txt" }) do os.remove(out .. "/" .. f) end
	local id = "own.repro--role-friend"
	os.remove(known .. "/" .. id .. ".lua")
	local src = slurp(T.dir .. "/hunt/repro/bell.crewmate_refused--role-friend.lua")
	local seen, promise = src:match('seen = "(.-)",\n'), src:match('promise = "(.-)",\n')
	ok(seen and promise, "the sample repro file has a promise and a line")
	put(known .. "/" .. id .. ".lua", (src:gsub('id = "[^"]*"', 'id = "' .. id .. '"', 1)))
	put(out .. "/raw.1-of-1.lua",
		"F{promise=\"" .. promise .. "\",seen=\"" .. seen .. "\",sit=\"role=friend\",seed=1,count=1}\n" ..
		"F{promise=\"" .. promise .. "\",seen=\"Another line the player sees.\",sit=\"role=friend\",seed=1,count=1}\n" ..
		"F{promise=\"coachsteps.got_it_is_final\",seen=\"Some line.\",sit=\"role=friend\",seed=1,count=1}\n")
	put(out .. "/results.1-of-1.txt", "# hunt test\n# end\n")
	local o1 = sh(('"%s" tools/hunt/sweep.lua --plan 1 --out "%s" --known-dir "%s"'):format(LUA, out, known))
	local plan = dofile(out .. "/groups.lua")
	ok(plan and plan.groups and #plan.groups == 3, "the plan has three groups:\n" .. o1)
	local byLine = {}
	for _, g in ipairs(plan.groups) do byLine[g.seen] = g end
	ok(byLine[seen] and byLine[seen].known, "the same line is known")
	local other = byLine["Another line the player sees."]
	ok(other and not other.known, "another line of the same promise is not known")
	eq(other.sameAs, id, "it names the repro of the same promise")
	local whole = byLine["Some line."]
	ok(whole and whole.known and whole.known.elsewhere, "the whole-promise row makes it known elsewhere")
	ok(whole.known.repro:find("whole promise, line not checked", 1, true), "marked: " .. tostring(whole.known.repro))
	sh(('"%s" tools/hunt/sweep.lua --join 1 --out "%s" --known-dir "%s" --repro-dir "%s"'):format(LUA, out, known, repro))
	local md = slurp(out .. "/FAILURES.md") or ""
	ok(md:find("same promise as " .. id .. " (other line)", 1, true), "FAILURES.md links the new finding:\n" .. md)
	ok(md:find("whole promise, line not checked", 1, true), "FAILURES.md marks the whole-promise row:\n" .. md)
end)
