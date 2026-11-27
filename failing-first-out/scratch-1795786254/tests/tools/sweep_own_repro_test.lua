-- tests/tools/sweep_own_repro_test.lua: the bug hunt's join (tools/hunt/sweep.lua --join) after sweep.ps1's --plan and
-- --shrink-part. A new finding's repro file is written into the known folder by the shrink part; the join marks the
-- groups known AGAIN (a rejoin) and must not let a finding become known through the repro file its own run just wrote.
-- Fake out folder: one raw failure, the plan made by the real --plan, a shrink result that names a repro file in a
-- temporary known folder. The finding must count as NEW (status repro), not known.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local LUA = os.getenv("WUBER_LUA") or "lua5.1"
local base = T.dir .. "/out/sweep-own-repro"

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
local function ser(v)
	if type(v) == "table" then
		local parts = {}
		for k, x in pairs(v) do parts[#parts + 1] = "[" .. ser(k) .. "]=" .. ser(x) end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return type(v) == "string" and string.format("%q", v) or tostring(v)
end
local function sh(cmd)
	local p = io.popen("cd " .. T.dir .. "/.. && " .. cmd .. " 2>&1")
	local out = p:read("*a")
	local a, b, code = p:close()
	return out, code
end

test("hunt sweep join: a new finding does not become known through the repro file its own run wrote", function()
	local out, known, repro = base .. "/out", base .. "/known", base .. "/repro"
	for _, d in ipairs({ out, known, repro }) do
		if package.config:sub(1, 1) == "\\" then os.execute('mkdir "' .. d:gsub("/", "\\") .. '" >nul 2>&1') else os.execute('mkdir -p "' .. d .. '"') end
	end
	for _, f in ipairs({ "groups.lua", "shrunk.1-of-1.lua", "own.repro--role-friend.lua" }) do os.remove(out .. "/" .. f) os.remove(known .. "/" .. f) end
	-- the promise and the line the player saw come from a repro file of the repo, so both are real
	local src = slurp(T.dir .. "/hunt/repro/bell.crewmate_refused--role-friend.lua")
	local seen = src:match('seen = "(.-)",\n')
	local promise = src:match('promise = "(.-)",\n')
	ok(seen and promise, "the sample repro file has a promise and a line")
	put(out .. "/raw.1-of-1.lua", "F{promise=\"" .. promise .. "\",seen=\"" .. seen .. "\",sit=\"role=friend\",seed=1,count=1}\n")
	put(out .. "/results.1-of-1.txt", "# hunt test\n# end\n")
	local o1 = sh(('"%s" tools/hunt/sweep.lua --plan 1 --out "%s" --known-dir "%s"'):format(LUA, out, known))
	local plan = dofile(out .. "/groups.lua")
	ok(plan and plan.groups and #plan.groups == 1 and not plan.groups[1].known, "the plan has one new group:\n" .. o1)
	-- the shrink part wrote this run's repro file into the known folder and reports it
	local id = "own.repro--role-friend"
	local path = known .. "/" .. id .. ".lua"
	put(path, (src:gsub('id = "[^"]*"', 'id = "' .. id .. '"', 1)))
	local rel = path:gsub("^.*/tests/out/", "tests/out/")
	local res = { token = plan.token, g = 1, findings = { { members = { 1 }, id = id, repro = rel, seen = seen, sit = "role=friend", seed = 1, runs = 3, secs = 0 } } }
	put(out .. "/shrunk.1-of-1.lua", "# shrink part 1/1: 1 groups\nG" .. ser(res) .. "\n# wall 1\n")
	local o2, code = sh(('"%s" tools/hunt/sweep.lua --join 1 --out "%s" --known-dir "%s" --repro-dir "%s"'):format(LUA, out, known, repro))
	local summary = slurp(out .. "/summary.txt") or o2
	ok(summary:find("known 0, new 1", 1, true), "the finding counts as new:\n" .. summary)
	local tsvNew = slurp(out .. "/failures-new.tsv") or ""
	ok(tsvNew:find("\trepro\t", 1, true), "status repro in failures-new.tsv:\n" .. tsvNew)
end)

test("hunt sweep join: a repro file from an EARLIER run still makes its finding known", function()
	local b2 = T.dir .. "/out/sweep-own-repro-earlier"
	local out, known, repro = b2 .. "/out", b2 .. "/known", b2 .. "/repro"
	for _, d in ipairs({ out, known, repro }) do
		if package.config:sub(1, 1) == "\\" then os.execute('mkdir "' .. d:gsub("/", "\\") .. '" >nul 2>&1') else os.execute('mkdir -p "' .. d .. '"') end
	end
	local newId, oldId = "own.repro--role-friend", "earlier.repro--phone-confirm"
	for _, f in ipairs({ "groups.lua", "shrunk.1-of-1.lua", newId .. ".lua", oldId .. ".lua" }) do os.remove(out .. "/" .. f) os.remove(known .. "/" .. f) end
	local src = slurp(T.dir .. "/hunt/repro/bell.crewmate_refused--role-friend.lua")
	local srcOld = slurp(T.dir .. "/hunt/repro/booking.confirm_not_yanked--phone-confirm.lua")
	local seen, promise = src:match('seen = "(.-)",\n'), src:match('promise = "(.-)",\n')
	local seenOld, promiseOld = srcOld:match('seen = "(.-)",\n'), srcOld:match('promise = "(.-)",\n')
	ok(seen and promise and seenOld and promiseOld and promise ~= promiseOld, "two sample repro files with different promises")
	put(out .. "/raw.1-of-1.lua",
		"F{promise=\"" .. promise .. "\",seen=\"" .. seen .. "\",sit=\"role=friend\",seed=1,count=1}\n" ..
		"F{promise=\"" .. promiseOld .. "\",seen=\"" .. seenOld .. "\",sit=\"phone=confirm\",seed=1,count=1}\n")
	put(out .. "/results.1-of-1.txt", "# hunt test\n# end\n")
	local o1 = sh(('"%s" tools/hunt/sweep.lua --plan 1 --out "%s" --known-dir "%s"'):format(LUA, out, known))
	local plan = dofile(out .. "/groups.lua")
	ok(plan and plan.groups and #plan.groups == 2 and not plan.groups[1].known and not plan.groups[2].known, "the plan has two new groups:\n" .. o1)
	local gNew
	for i, g in ipairs(plan.groups) do if g.promise == promise then gNew = i end end
	ok(gNew, "the bell finding is in the plan")
	-- an EARLIER run's repro file, in the known folder by the join (the matching may be newer than the plan, as in a rejoin)
	-- but named in no shrunk.*.lua result of this run: it must still make its finding known
	put(known .. "/" .. oldId .. ".lua", (srcOld:gsub('id = "[^"]*"', 'id = "' .. oldId .. '"', 1)))
	-- only the new finding was shrunk by this run
	local path = known .. "/" .. newId .. ".lua"
	put(path, (src:gsub('id = "[^"]*"', 'id = "' .. newId .. '"', 1)))
	local rel = path:gsub("^.*/tests/out/", "tests/out/")
	local res = { token = plan.token, g = gNew, findings = { { members = { 1 }, id = newId, repro = rel, seen = seen, sit = "role=friend", seed = 1, runs = 3, secs = 0 } } }
	put(out .. "/shrunk.1-of-1.lua", "# shrink part 1/1: 1 groups\nG" .. ser(res) .. "\n# wall 1\n")
	local o2 = sh(('"%s" tools/hunt/sweep.lua --join 1 --out "%s" --known-dir "%s" --repro-dir "%s"'):format(LUA, out, known, repro))
	local summary = slurp(out .. "/summary.txt") or o2
	ok(summary:find("known 1, new 1", 1, true), "one known (the earlier run's), one new (this run's):\n" .. summary)
	local tsvNew = slurp(out .. "/failures-new.tsv") or ""
	ok(tsvNew:find("\trepro\t", 1, true), "the new finding has status repro:\n" .. tsvNew)
	ok(not tsvNew:find(seenOld, 1, true), "the earlier finding is not in failures-new.tsv:\n" .. tsvNew)
end)
