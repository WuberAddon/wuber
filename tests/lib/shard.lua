-- tests/lib/shard.lua: the suite split across processes (tools/suite-par.sh).
--
--   lua5.1 tests/run.lua [filter] [flags] --shard K/N   runs only its share of the tests
--   lua5.1 tests/run.lua [filter] [flags] --join N      runs none: joins the N shards' files
--
-- Every process loads the same test files, so every one sees the same ordered list of tests
-- (index 1, 2, ... among those the filter keeps), and each test goes to exactly one shard:
--   * a full run (no filter) balances by the CPU seconds each test took last time: the longest
--     first, each to the shard with the least so far, from the COMMITTED tests/fixtures/test-times.txt
--     only (or the file WUBER_PLAN_TIMES names); never from tests/out/times.txt, a leftover of some
--     earlier run that would give each tree its own plan. Every join still WRITES tests/out/times.txt,
--     so a person can copy it into the fixtures on purpose; a test not in the file goes round robin
--   * a filtered run, or no times file: round robin, the test with index i to shard (i - 1) % N + 1
-- Every shard reads the same file and makes the same plan. A skipped test still counts for
-- "name #2" in the transcript and drops the worlds made for it, as the serial run does.
-- One test (drive.book's "Get Wuber", about 2 minutes) is the floor of a split run's time.
--
-- A shard writes only its own files (no two processes write the same one):
--   tests/out/transcript.K-of-N.txt  its tests' transcript records (with a transcript flag)
--   tests/out/results.K-of-N.txt     one line per test it ran (index, pass, CPU seconds, name,
--                                    error); the report's tables (widget methods and APIs used,
--                                    unknown methods, missing globals) with the test index of
--                                    each entry; and an end line (a shard that crashed has none)
-- The join reads them, checks every test of the list was run by exactly one shard, writes the
-- transcript in the serial order (byte for byte the file a serial run writes) and hands run.lua
-- the counts, so its own compare / update / report code runs on the joined result.

local SH = {}

local function esc(s)
	return (tostring(s):gsub("[\\\t\n\r]", { ["\\"] = "\\\\", ["\t"] = "\\t", ["\n"] = "\\n", ["\r"] = "\\r" }))
end
local function unesc(s)
	return (s:gsub("\\(.)", { ["\\"] = "\\", t = "\t", n = "\n", r = "\r" }))
end

local function split(line)
	local out = {}
	for part in (line .. "\t"):gmatch("([^\t]*)\t") do out[#out + 1] = part end
	return out
end

local function mkdirFor(path)
	local folder = path:match("^(.*)[/\\][^/\\]*$")
	if not folder then return end
	if package.config:sub(1, 1) == "\\" then os.execute('mkdir "' .. folder:gsub("/", "\\") .. '" 2>nul')
	else os.execute('mkdir -p "' .. folder .. '"') end
end

local function partName(dir, what, k, n, ext)
	return dir .. "/out/" .. what .. "." .. k .. "-of-" .. n .. "." .. ext
end
SH.partName = partName

-- The report's tables: "first" keeps the value of the earliest test (H.used: first use),
-- "last" the latest (a later write replaces the value).
local TABLES = {
	{ "method", "first", function(H) return H.used.method end },
	{ "api", "first", function(H) return H.used.api end },
	{ "unknown", "last", function(H) return H.unknown end },
	{ "missing", "last", function(H) return H.missingGlobals end },
	{ "uncertain", "last", function(H) return H.uncertain end },
}

-- "secs<tab>test id" lines (id: the name, "name #2" for a repeat), in test order
local function readTimes(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local list = {}
	for line in f:lines() do
		local secs, id = line:match("^([%d%.]+)\t(.+)$")
		if secs then list[#list + 1] = { tonumber(secs), unesc(id) } end
	end
	f:close()
	return #list > 0 and list or nil
end

-- the times a full run plans by: the committed fixture (or WUBER_PLAN_TIMES), never tests/out/times.txt
local function timesPath(dir)
	local env = os.getenv("WUBER_PLAN_TIMES")
	if env and env ~= "" then return env end
	return dir .. "/fixtures/test-times.txt"
end

-- the older times a filtered join keeps for tests it did not run: the last run's own file, else the fixture
local function oldTimesPath(dir)
	local mine = dir .. "/out/times.txt"
	local f = io.open(mine, "rb")
	if f then f:close() return mine end
	return timesPath(dir)
end

-- test id -> shard: longest first, each to the least loaded shard (ties: the lower shard)
local function balance(list, n)
	local order = {}
	for i, e in ipairs(list) do order[i] = { e[1], i, e[2] } end
	table.sort(order, function(a, b) if a[1] ~= b[1] then return a[1] > b[1] end return a[2] < b[2] end)
	local load, plan = {}, {}
	for k = 1, n do load[k] = 0 end
	for _, e in ipairs(order) do
		if not plan[e[3]] then
			local best = 1
			for k = 2, n do if load[k] < load[best] then best = k end end
			plan[e[3]] = best
			load[best] = load[best] + e[1]
		end
	end
	return plan
end
SH.balance = balance

-- spec: "K/N" (a shard) ; joinN: "N" (the join); filter: the run's filter. Nil when neither.
function SH.new(dir, H, spec, joinN, filter)
	if not spec and not joinN then return nil end
	local self = setmetatable({ index = 0, counts = {}, unknown = 0, filter = filter }, { __index = SH })
	if joinN then
		self.joining = true
		self.n = tonumber(joinN)
		if not self.n or self.n < 1 or self.n % 1 ~= 0 then error("--join N: N is the number of shards, got " .. tostring(joinN)) end
		self.names = {}
	else
		local k, n = tostring(spec):match("^(%d+)/(%d+)$")
		k, n = tonumber(k), tonumber(n)
		if not k or n < 1 or k < 1 or k > n then error("--shard K/N with 1 <= K <= N, got " .. tostring(spec)) end
		self.k, self.n = k, n
		self.transcript = partName(dir, "transcript", k, n, "txt")
		self.resultsPath = partName(dir, "results", k, n, "txt")
		mkdirFor(self.resultsPath)
		self.out = assert(io.open(self.resultsPath, "wb"))
		self.seen = {}
		for _, t in ipairs(TABLES) do self.seen[t[1]] = {} end
		local list = not filter and readTimes(timesPath(dir))
		self.plan = list and balance(list, n)
	end

	-- the report tables: new entries ("first") or every entry written since the last look
	-- ("last": written out, then cleared, so a later write is seen again)
	local function look(stamp)
		for _, t in ipairs(TABLES) do
			local tab, seen = t[3](H), self.seen[t[1]]
			local keys = {}
			for key in pairs(tab) do
				if t[2] == "last" or not seen[key] then keys[#keys + 1] = key end
			end
			table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
			for _, key in ipairs(keys) do
				self.out:write("R\t", t[1], "\t", stamp, "\t", esc(key), "\t", esc(tab[key]), "\n")
				seen[key] = true
				if t[2] == "last" then tab[key] = nil end
			end
		end
	end

	-- the shard a test goes to
	local function shardOf(id)
		local k = self.plan and self.plan[id]
		if k then return k end
		if not self.plan then return (self.index - 1) % self.n + 1 end
		self.unknown = self.unknown + 1 -- a test the times file does not know (a new one)
		return (self.unknown - 1) % self.n + 1
	end

	-- A test the filter kept: true when this process does not run it.
	function self.skip(name, TR)
		self.index = self.index + 1
		self.counts[name] = (self.counts[name] or 0) + 1
		local id = self.counts[name] > 1 and (name .. " #" .. self.counts[name]) or name
		self.ids = self.ids or {}
		self.ids[self.index] = id
		if self.joining then
			self.names[self.index] = name
			return true
		end
		if shardOf(id) ~= self.k then
			if TR then TR.skip(name) end
			H.release()
			return true
		end
		look(self.index - 0.5)
		self.t0 = os.clock()
		return false
	end

	-- One of this shard's tests ended. recorded: its transcript record was written.
	function self.done(name, ok, err, recorded)
		local secs = os.clock() - (self.t0 or os.clock())
		look(self.index)
		self.out:write("T\t", self.index, "\t", ok and 1 or 0, "\t", recorded and 1 or 0, "\t",
			string.format("%.3f", secs), "\t", esc(name), "\t", ok and "" or esc(err), "\n")
		self.out:flush()
	end

	function self.finish(passed, failed)
		if not self.out then return end
		look(self.index + 0.5)
		self.out:write("E\t", self.index, "\t", passed, "\t", failed, "\n")
		self.out:close()
		self.out = nil
	end

	return self
end

-- the records of a transcript file, as the exact bytes of each (header line to the next)
local function recordsOf(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local text = f:read("*a")
	f:close()
	local recs, pos = {}, 1
	if text == "" then return recs end
	if text:sub(1, 4) ~= "=== " then return nil, "does not start with a record" end
	while pos <= #text do
		local nxt = text:find("\n=== ", pos, true)
		local stop = nxt or #text
		recs[#recs + 1] = text:sub(pos, stop)
		pos = stop + 1
	end
	return recs
end

-- The join: reads the N shards' files. transcript: the path the joined transcript goes to
-- (nil: no transcript). Returns { passed, failed, failures = { names }, problems = { text } };
-- prints (say: print) each failure with its error, in test order. H's report tables are
-- replaced by the merged ones.
function SH.join(self, dir, H, transcript, say)
	say = say or print
	local n, names = self.n, self.names
	local tests, problems = {}, {}
	local merged = {}
	for _, t in ipairs(TABLES) do merged[t[1]] = {} end
	local cpu, records = {}, {}
	for k = 1, n do
		local path = partName(dir, "results", k, n, "txt")
		local f = io.open(path, "rb")
		local ended, order = false, {}
		cpu[k] = 0
		if not f then
			problems[#problems + 1] = "shard " .. k .. "/" .. n .. ": no results file " .. path
		else
			for line in f:lines() do
				local p = split(line)
				if p[1] == "T" then
					local i = tonumber(p[2])
					if tests[i] then problems[#problems + 1] = "test " .. i .. " run by two shards" end
					tests[i] = { ok = p[3] == "1", recorded = p[4] == "1", secs = tonumber(p[5]) or 0,
						name = unesc(p[6] or ""), err = unesc(p[7] or ""), shard = k }
					cpu[k] = cpu[k] + tests[i].secs
					order[#order + 1] = i
				elseif p[1] == "R" then
					local stamp, key, value = tonumber(p[3]), unesc(p[4] or ""), unesc(p[5] or "")
					local rule
					for _, t in ipairs(TABLES) do if t[1] == p[2] then rule = t[2] end end
					local m = merged[p[2]]
					if m then
						local cur = m[key]
						if not cur or (rule == "first" and stamp < cur[1]) or (rule == "last" and stamp >= cur[1]) then
							m[key] = { stamp, value }
						end
					end
				elseif p[1] == "E" then
					ended = true
					if tonumber(p[2]) ~= #names then
						problems[#problems + 1] = "shard " .. k .. "/" .. n .. " saw " .. p[2] .. " tests, the join " .. #names
					end
				end
			end
			f:close()
			if not ended then problems[#problems + 1] = "shard " .. k .. "/" .. n .. " did not finish (crashed or still running): " .. path end
		end
		if transcript then
			local tpath = partName(dir, "transcript", k, n, "txt")
			local recs, why = recordsOf(tpath)
			if not recs then
				problems[#problems + 1] = "shard " .. k .. "/" .. n .. ": transcript " .. tpath .. " " .. (why or "missing")
			else
				local r = 0
				for _, i in ipairs(order) do
					if tests[i].recorded then
						r = r + 1
						records[i] = recs[r]
					end
				end
				if r ~= #recs then
					problems[#problems + 1] = "shard " .. k .. "/" .. n .. ": " .. #recs .. " transcript records for " .. r .. " tests"
				end
			end
		end
	end

	local res = { passed = 0, failed = 0, failures = {}, problems = problems, cpu = cpu }
	for i, name in ipairs(names) do
		local t = tests[i]
		if not t then
			problems[#problems + 1] = "test " .. i .. " not run by any shard: " .. name
		elseif t.name ~= name then
			problems[#problems + 1] = "test " .. i .. " is \"" .. name .. "\" here, \"" .. t.name .. "\" in shard " .. t.shard
		elseif t.ok then
			res.passed = res.passed + 1
		else
			res.failed = res.failed + 1
			res.failures[#res.failures + 1] = name
			say("FAIL  " .. name .. "  (shard " .. t.shard .. ")\n      " .. t.err:gsub("\n", "\n      "))
		end
	end
	for i in pairs(tests) do
		if not names[i] then problems[#problems + 1] = "test " .. i .. " ran in a shard but is not in the list" end
	end

	if transcript then
		mkdirFor(transcript)
		local out = assert(io.open(transcript, "wb"))
		for i = 1, #names do if records[i] then out:write(records[i]) end end
		out:close()
	end

	-- the times the next full run balances by: this run's, then (a filtered run only) the older file's for
	-- tests not run. A full run ran every test there is, so an older entry it did not run is a test that was
	-- removed or renamed: kept, it would still get a shard to itself (the split "Get Wuber", 146 s, left
	-- shard 1 empty in the speed round)
	local old = readTimes(oldTimesPath(dir)) or {}
	local have, lines = {}, {}
	for i = 1, #names do
		local t, id = tests[i], self.ids[i]
		if t and t.name == names[i] then
			have[id] = true
			lines[#lines + 1] = ("%.3f\t%s"):format(t.secs, esc(id))
		end
	end
	if #lines > 0 then
		for _, e in ipairs(self.filter and old or {}) do
			if not have[e[2]] then lines[#lines + 1] = ("%.3f\t%s"):format(e[1], esc(e[2])) end
		end
		mkdirFor(dir .. "/out/times.txt")
		local tf = io.open(dir .. "/out/times.txt", "wb")
		if tf then tf:write(table.concat(lines, "\n"), "\n") tf:close() end
	end

	for _, t in ipairs(TABLES) do
		local tab = t[3](H)
		for key in pairs(tab) do tab[key] = nil end
		for key, sv in pairs(merged[t[1]]) do tab[key] = sv[2] end
	end
	return res
end

return SH
