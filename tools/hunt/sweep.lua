-- The bug hunt's sweep (tests/hunt/README.md). Run from the repo root:
--   lua5.1 tools/hunt/sweep.lua --list
--   lua5.1 tools/hunt/sweep.lua --one "session=reload,phone=drive_direct" --promise tips.first_open [--verbose] [--shrink]
--   lua5.1 tools/hunt/sweep.lua --mode pairs|random|walk [--seed N] [--n N] [--steps N | --steps A-B] [--promise id-prefix]
--          [--shard K/N] [--addon <folder with another Wuber>] [--out dir] [--no-shrink] [--verbose] [--skip id,id]
--          [--budget-seconds S | --total-seconds T] [--deadline-seconds W] [--max-shrinks N] [--shrink-seconds S]
--          [--repro-dir dir]
--   lua5.1 tools/hunt/sweep.lua --one "sit" --mode walk [--n 3] [--steps 300]   (long sessions from one fixed start)
--   lua5.1 tools/hunt/sweep.lua --join N --out dir      (joins N shards' files: FAILURES.md, failures.tsv, cannot.tsv,
--          broken.tsv, summary.txt, KNOWN.md; shrinks here unless --plan and --shrink-part did it)
--   lua5.1 tools/hunt/sweep.lua --plan N --out dir      (the join's first half: groups the shards' raw failures, groups.lua)
--   lua5.1 tools/hunt/sweep.lua --shrink-part K/M --out dir [--deadline-seconds W]  (shrinks every M-th group of groups.lua)
-- pairs: each promise's pairwise set (then, with a budget, random situations); the promises share the time fairly
-- (the one that has used the least time runs next; its pairwise situations first, then random ones).
-- random: --n random situations per promise. walk: --n long sessions of --steps player actions each (--steps A-B:
-- each walk's length drawn from the range by its seed); a failure does not stop a walk: each distinct finding
-- (promise + plain line with numbers blanked) is kept and muted for the rest of that walk. A start that cannot build
-- is skipped (the next one is tried, counted).
-- --budget-seconds S: at most S seconds (CPU) of checks per promise in this process; --total-seconds T: at most T s
-- (CPU) of checks in this process; --deadline-seconds W: this process starts nothing after W s of wall time (a check
-- still running is stopped 20 s later). What a budget or the deadline drops is counted and printed.
-- --skip id,id: these promises are never checked in this run (an id ending in "." skips all that start with it).
-- --resume dir: (pairs/random) skip each (promise, situation) that the sweep in dir (its results.*.txt) ran and passed,
-- when that promise's file, the dials, the hunt's core and the Wuber are the same as then (they are written as resumed
-- pass lines, not run). --no-cache: never read or write the pairwise set cache (tests/out/hunt/cache).
-- --make-sets: only make (and cache) the pairwise sets of this shard's promises; prints the time. Without --out, --one
-- writes to tests/out/hunt/one-<time>-<id>/ (parallel runs never overwrite each other).
-- Shards do not shrink: they write every raw failure (raw.K-of-N.lua); the join groups them by promise + plain line
-- (numbers blanked) and shrinks each group ONCE (--shrink-seconds in all, default 900; sweep.ps1 runs the shrinking on
-- all its processes with --plan / --shrink-part). --no-shrink: re-run once (repeatable?) and write the repro unshrunk.
local here = ((arg and arg[0]) or "tools/hunt/sweep.lua"):gsub("\\", "/"):match("^(.*)/[^/]*$") or "."
local Hunt = dofile(here .. "/../../tests/hunt/lib.lua")
local T0 = os.time() -- the wall clock: deadlines only, never a choice

local o = { mode = "pairs", seed = 1, steps = 30, skip = {} }
do
	local argv, i = arg or {}, 1
	local function val() i = i + 1 return argv[i] end
	while argv[i] do
		local a = argv[i]
		local k, v = a:match("^%-%-([%w%-]+)=(.*)$")
		if k then a = "--" .. k end
		local function get() if v ~= nil then return v end return val() end
		if a == "--list" then o.list = true
		elseif a == "--one" then o.one = get()
		elseif a == "--mode" then o.mode = get()
		elseif a == "--seed" then o.seed = tonumber(get()) or 1
		elseif a == "--n" then o.n = tonumber(get())
		elseif a == "--steps" then
			local s = tostring(get())
			local lo, hi = s:match("^(%d+)%-(%d+)$")
			if lo then o.stepsMin, o.stepsMax = tonumber(lo), tonumber(hi) else o.steps = tonumber(s) or 30 end
		elseif a == "--steps-min" then o.stepsMin = tonumber(get())
		elseif a == "--steps-max" then o.stepsMax = tonumber(get())
		elseif a == "--promise" then o.promise = get()
		elseif a == "--skip" then for id in tostring(get()):gmatch("[^,%s]+") do o.skip[#o.skip + 1] = id end
		elseif a == "--shard" then o.shard = get()
		elseif a == "--join" then o.join = tonumber(get())
		elseif a == "--plan" then o.plan = tonumber(get())
		elseif a == "--shrink-part" then o.shrinkPart = get()
		elseif a == "--addon" then o.addon = get()
		elseif a == "--out" then o.out = get()
		elseif a == "--no-shrink" then o.noShrink = true
		elseif a == "--shrink" then o.shrink = true
		elseif a == "--verbose" then o.verbose = true
		elseif a == "--budget-seconds" then o.budget = tonumber(get())
		elseif a == "--total-seconds" then o.total = tonumber(get())
		elseif a == "--deadline-seconds" then o.deadline = tonumber(get())
		elseif a == "--max-shrinks" then o.maxShrinks = tonumber(get())
		elseif a == "--shrink-seconds" then o.shrinkSeconds = tonumber(get())
		elseif a == "--repro-dir" then o.reproDir = get()
		elseif a == "--known-dir" then o.knownDir = get()
		elseif a == "--known-md" then o.knownMd = true
		elseif a == "--refresh-known" then o.refreshKnown = true
		elseif a == "--resume" then o.resume = get()
		elseif a == "--no-cache" then o.noCache = true
		elseif a == "--make-sets" then o.makeSets = true
		elseif a == "--help" or a == "-h" then o.help = true
		else io.stderr:write("unknown option " .. tostring(argv[i]) .. " (--help)\n") os.exit(2) end
		i = i + 1
	end
end
if o.help then
	for line in (Hunt.readFile(here .. "/sweep.lua") or ""):gmatch("[^\n]*") do
		if not line:match("^%-%-") then break end
		print(line)
	end
	os.exit(0)
end
if o.stepsMin or o.stepsMax then
	o.stepsMin = o.stepsMin or o.stepsMax
	o.stepsMax = o.stepsMax or o.stepsMin
	if o.stepsMax < o.stepsMin then o.stepsMin, o.stepsMax = o.stepsMax, o.stepsMin end
	o.steps = o.stepsMin
end

local ok, err = pcall(Hunt.init, { addon = o.addon })
if not ok then io.stderr:write(tostring(err) .. "\n") os.exit(2) end
for _, id in ipairs(o.skip) do Hunt.skipIds[#Hunt.skipIds + 1] = id end
local Sit = Hunt.Sit
if o.noCache then Sit.useCache = false end
local oneLine = Hunt.oneLine
local DEADLINE = o.deadline and (T0 + o.deadline) or nil
if DEADLINE then Hunt.hardStop = DEADLINE + 20 end
local function timeLeft() return DEADLINE and (DEADLINE - os.time()) or math.huge end

local function out(...) print(...) io.stdout:flush() end

local function loadReport()
	for _, e in ipairs(Hunt.loadErrors) do out("LOAD ERROR " .. e.file .. ": " .. oneLine(e.err:match("^[^\n]*"), 300)) end
	for _, n in ipairs(Hunt.notes or {}) do out("note: " .. n) end
end

local function selected()
	local list = {}
	for _, p in ipairs(Hunt.promiseOrder) do
		if (not o.promise or p.id:sub(1, #o.promise) == o.promise) and not Hunt.isSkipped(p.id) then list[#list + 1] = p end
	end
	return list
end

---------------------------------------------------------------------------
-- --list
---------------------------------------------------------------------------
if o.list then
	out("Wuber: " .. Hunt.addonInfo())
	loadReport()
	out(("%d dials, %d promises, %d actions"):format(#Hunt.dialOrder, #Hunt.promiseOrder, #Hunt.actionOrder))
	local byPhase = {}
	for _, d in ipairs(Hunt.dialOrder) do byPhase[#byPhase + 1] = d end
	table.sort(byPhase, function(a, b) if a.phase ~= b.phase then return a.phase < b.phase end return a.name < b.name end)
	for _, d in ipairs(byPhase) do
		out(("dial %s (phase %d, default %s, %s): %s"):format(d.name, d.phase, d.default, d.file, oneLine(d.about or "", 140)))
		for _, v in ipairs(d.values) do
			local ex = {}
			for od, l in pairs(v.excludes or {}) do ex[#ex + 1] = od .. "=" .. table.concat(type(l) == "table" and l or { l }, "/") end
			table.sort(ex)
			out(("    %s%s%s"):format(v.id, v.about and (": " .. oneLine(v.about, 120)) or "", #ex > 0 and ("  [excludes " .. table.concat(ex, ", ") .. "]") or ""))
		end
	end
	for _, p in ipairs(Hunt.promiseOrder) do
		local needs = {}
		for k, v in pairs(p.needs or {}) do needs[#needs + 1] = k .. "=" .. (type(v) == "table" and table.concat(v, "/") or tostring(v)) end
		table.sort(needs)
		out(("promise %s [%s] %s%s%s"):format(p.id, p.kind, oneLine(p.text, 160), #needs > 0 and ("  (needs " .. table.concat(needs, ", ") .. ")") or "",
			Hunt.isSkipped(p.id) and "  (--skip)" or ""))
	end
	for _, a in ipairs(Hunt.actionOrder) do out(("action %s (weight %s, %s)"):format(a.id, a.weight, a.file)) end
	os.exit(0)
end

---------------------------------------------------------------------------
-- where things go
---------------------------------------------------------------------------
local K, N = 1, 1
if o.shard then
	K, N = o.shard:match("^(%d+)/(%d+)$")
	K, N = tonumber(K), tonumber(N)
	if not (K and N and K >= 1 and K <= N) then io.stderr:write("--shard K/N\n") os.exit(2) end
end
local RUN = ("%s-s%d%s"):format(o.mode, o.seed, o.addon and "-addon" or "")
local OUT
do
	local dir = o.out
	if not dir and o.one then
		-- (a --one run of its own folder: two agents' runs never write the same files)
		local tn = tostring(os.tmpname() or ""):gsub("\\", "/"):match("([^/]*)$"):gsub("[^%w]", "")
		dir = Hunt.ROOT .. "/tests/out/hunt/one-" .. os.time() .. "-" .. tn
	end
	OUT = Hunt.norm(dir or (Hunt.ROOT .. "/tests/out/hunt/" .. RUN))
end
-- a run against another Wuber (--addon) keeps its repro files with its results, not with the repo's KNOWN list
-- (--repro-dir: somewhere else, e.g. while trying a new promise; KNOWN.md then goes next to that folder)
local REPRO = o.reproDir and Hunt.norm(o.reproDir) or (o.addon and (OUT .. "/repro")) or (Hunt.ROOT .. "/tests/hunt/repro")
local KNOWN = (o.reproDir and (REPRO .. "/../KNOWN.md")) or (o.addon and (OUT .. "/KNOWN.md")) or (Hunt.ROOT .. "/tests/hunt/KNOWN.md")
local function rel(p) return (p:gsub("^" .. Hunt.ROOT:gsub("%p", "%%%0") .. "/", "")) end
-- the folder whose repro files say which findings are KNOWN (default: the repo's, whatever --repro-dir says)
local KNOWN_DIR = o.knownDir and Hunt.norm(o.knownDir) or (Hunt.ROOT .. "/tests/hunt/repro")
if o.knownMd then
	-- KNOWN.md again from the repro files now in the folder (with the shared list's HUNT ids)
	local nk = Hunt.writeKnown(REPRO, KNOWN)
	print(rel(KNOWN) .. ": " .. nk .. " repro files")
	os.exit(0)
end
if o.refreshKnown then
	-- re-runs each repro file of the known folder (only the promises starting with --promise, if given) and rewrites its
	-- "seen" when the wording changed and it still fails; prints one line each
	local bad = 0
	for _, path in ipairs(Hunt.listLua(KNOWN_DIR)) do
		local t = Hunt.readFile(path) or ""
		local pid = t:match('promise = "([^"]*)"') or ""
		if not o.promise or pid:sub(1, #o.promise) == o.promise then
			local what, seen = Hunt.refreshSeen(path)
			if what ~= "same" then bad = bad + 1 end
			print(("%-10s %s%s"):format(what, rel(path), what == "rewritten" and ("\n      " .. tostring(seen)) or ""))
		end
	end
	os.exit(0)
end
local SHRINK_SECONDS = o.shrinkSeconds or ((o.total or (o.budget and o.budget * 10)) and math.floor(0.25 * (o.total or o.budget * 10))) or 900
local MAX_SHRINKS = o.maxShrinks or 6

local SHRINK_END -- (--shrink-part: the end of this process's shrinking; in a shard the deadline is for the checks only)

local function tsvField(s) return (tostring(s == nil and "" or s):gsub("[\t\r\n]+", " ")) end

---------------------------------------------------------------------------
-- reading the shards' files
---------------------------------------------------------------------------

-- the raw failures of shard k of n: raw.k-of-n.lua (one record per line; a cut last line is skipped), else the
-- older failures.k-of-n.lua
local function readRaw(k, n)
	local list = {}
	local text = Hunt.readFile(OUT .. "/raw." .. k .. "-of-" .. n .. ".lua")
	if text then
		for line in text:gmatch("[^\n]+") do
			if line:sub(1, 2) == "F{" then
				local chunk = loadstring("return " .. line:sub(2))
				local okc, rec = false, nil
				if chunk then okc, rec = pcall(chunk) end
				if okc and type(rec) == "table" and rec.promise then list[#list + 1] = rec end
			end
		end
		return list, true
	end
	local chunk = loadfile(OUT .. "/failures." .. k .. "-of-" .. n .. ".lua")
	local okc, old = false, nil
	if chunk then okc, old = pcall(chunk) end
	for _, f in ipairs(okc and type(old) == "table" and old or {}) do
		list[#list + 1] = { promise = f.promise, seen = f.seen, sit = f.sit, seed = f.seed, after = f.after, steps = f.steps,
			found = f.found, count = f.count, kind = f.steps and "walk" or nil }
	end
	return list, false
end

local function fileSize(path)
	local f = io.open(path, "rb")
	if not f then return -1 end
	local s = f:seek("end")
	f:close()
	return s or -1
end

-- the plan's token: the sizes of the shards' files (a plan made from other files is not used)
local function token(n)
	local parts = {}
	for k = 1, n do
		parts[#parts + 1] = fileSize(OUT .. "/results." .. k .. "-of-" .. n .. ".txt")
		parts[#parts + 1] = fileSize(OUT .. "/raw." .. k .. "-of-" .. n .. ".lua")
	end
	return Hunt.hex(table.concat(parts, ","))
end

-- the counts in the results files
local function readStats(n)
	local st = { counts = { pass = 0, fail = 0, na = 0, ["cannot-build"] = 0, ["broken-check"] = 0 },
		after = { n = 0, pass = 0, fail = 0, na = 0, ["broken-check"] = 0, ["cannot-build"] = 0 },
		secs = 0, checks = 0, sits = {}, promises = {}, notes = {}, broken = {}, cannot = {}, missing = {}, partial = {},
		walks = { n = 0, steps = 0, secs = 0, findings = 0, muted = 0, skipped = 0, stopped = 0, ended = 0 }, dropped = 0, resumed = 0 }
	for k = 1, n do
		local text = Hunt.readFile(OUT .. "/results." .. k .. "-of-" .. n .. ".txt")
		if not text then st.missing[#st.missing + 1] = k else
			local ended = false
			for line in text:gmatch("[^\n]+") do
				if line:match("^# hunt ") then st.header = st.header or line:sub(3)
				elseif line:match("^# after ") then
					for key, v in line:gmatch("([%w%-]+)=(%d+)") do st.after[key] = (st.after[key] or 0) + tonumber(v) end
				elseif line:match("^# end") then ended = true
				elseif line:match("^# walk ") then
					local w = st.walks
					w.n = w.n + 1
					w.steps = w.steps + (tonumber(line:match(" steps=(%d+)")) or 0)
					w.secs = w.secs + (tonumber(line:match(" secs=([%d%.]+)")) or 0)
					w.findings = w.findings + (tonumber(line:match(" findings=(%d+)")) or 0)
					w.muted = w.muted + (tonumber(line:match(" muted=(%d+)")) or 0)
					w.skipped = w.skipped + (tonumber(line:match(" skipped=(%d+)")) or 0)
					if line:match(" stopped=1") then w.stopped = w.stopped + 1 end
					if line:match(" ended=1") then w.ended = w.ended + 1 end
				elseif line:match("^# dropped ") then
					st.dropped = st.dropped + (tonumber(line:match(": (%d+) ")) or 0)
				elseif line:match("^# ") then
					if not line:match("^# %-%-one ") and not line:match("^# stopped") and not line:match("^# psig ") then st.notes[#st.notes + 1] = "shard " .. k .. ": " .. line:sub(3) end
				else
					local s, pid, sit, seed, secs, note = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t?(.*)$")
					if s then
						local side = note and (note:match("^after ") or note:match("^walk step ") or note == "resumed")
						if note == "resumed" then st.resumed = st.resumed + 1 end
						if not side then
							st.checks = st.checks + 1
							st.counts[s] = (st.counts[s] or 0) + 1
							st.secs = st.secs + (tonumber(secs) or 0)
							st.sits[sit] = true
							if pid ~= "walk" then st.promises[pid] = true end
						end
						local detail = note and note:match("detail: (.*)$") or note
						if s == "broken-check" then
							local b = st.broken[pid]
							if not b then b = { n = 0, detail = detail, sit = sit, seed = seed } st.broken[pid] = b end
							b.n = b.n + 1
						elseif s == "cannot-build" then
							local why = Hunt.blank(oneLine(detail or "?", 200))
							local c = st.cannot[why]
							if not c then c = { n = 0, sit = sit, pid = pid, seed = seed } st.cannot[why] = c end
							c.n = c.n + 1
						end
					end
				end
			end
			if not ended then st.partial[#st.partial + 1] = k end
		end
	end
	return st
end

---------------------------------------------------------------------------
-- grouping and shrinking (the join decides: every raw failure from every shard first, then each group ONCE)
---------------------------------------------------------------------------

local MEMBERS_KEPT, WALK_STEPS_KEPT = 300, 3
local markKnown

-- sets g.known on every group that matches the known folder's repro files or tests/hunt/known-elsewhere.tsv
-- (Hunt.knownFind: same line; universal.* loose line; a known-elsewhere row by its line). The same promise with another line
-- is NEW: g.sameAs names the repro of that promise so FAILURES.md can link it
local function sitSize(s) local n = 0 for _ in tostring(s):gmatch(",") do n = n + 1 end return n end
-- ignore: { [rel path] = true } of repro files that do not count (the ones this run's own shrinking wrote)
function markKnown(groups, ignore)
	local knownMap = Hunt.knownMap(KNOWN_DIR, nil, ignore and function(p) return ignore[rel(p)] end)
	local elsewhere = Hunt.knownElsewhere(Hunt.ROOT .. "/tests/hunt/known-elsewhere.tsv")
	for _, g in ipairs(groups) do
		local kn, how, link = Hunt.knownFind(knownMap, g.promise, g.seen, elsewhere)
		g.sameAs = not kn and link and link.id or nil
		if not kn and g.known and g.known.how ~= "same line" then g.known = nil end -- a plan made with older matching
		if kn and not (g.known and how ~= "elsewhere" and g.known.how == "same line") then
			local k = { id = kn.id, hunt = kn.hunt, repro = kn.elsewhere and ("known elsewhere" .. (kn.whole and " (whole promise, line not checked)" or "") .. ": " .. kn.elsewhere) or rel(kn.file), how = how }
			if kn.elsewhere then k.elsewhere = true end
			if how == "loose line" then
				local best
				for _, m in ipairs(g.members or {}) do if not best or sitSize(m.sit) < sitSize(best) then best = m.sit end end
				k.another = best or "?"
			end
			g.known = k
		end
	end
end

local function makeGroups(n)
	local byKey, groups, raws = {}, {}, 0
	for k = 1, n do
		local list = readRaw(k, n)
		for _, r in ipairs(list) do
			raws = raws + (r.count or 1)
			local key = Hunt.findingKey(r.promise, r.seen)
			local g = byKey[key]
			if not g then
				g = { key = key, promise = r.promise, seen = r.seen, blank = Hunt.blank(r.seen), detail = r.detail, members = {}, count = 0,
					sitSet = {}, nsits = 0, afters = {}, walkSteps = 0, over = 0 }
				byKey[key] = g
				groups[#groups + 1] = g
			end
			g.count = g.count + (r.count or 1)
			if not g.sitSet[r.sit] then g.sitSet[r.sit] = true g.nsits = g.nsits + 1 end
			if r.after then g.afters[r.after] = (g.afters[r.after] or 0) + 1 end
			if #g.members < MEMBERS_KEPT then
				local m = { sit = r.sit, seed = r.seed, after = r.after, kind = r.kind, found = r.found, step = r.step, count = r.count or 1,
					nsteps = r.steps and #r.steps or nil }
				if r.steps and g.walkSteps < WALK_STEPS_KEPT then m.steps = r.steps g.walkSteps = g.walkSteps + 1 end
				g.members[#g.members + 1] = m
			else
				g.over = g.over + (r.count or 1)
			end
		end
	end
	-- the order of shrinking: a feature promise's own failures first (an always-promise's are many and alike), then
	-- the most found
	local function always(g) local p = Hunt.promises[g.promise] return (p and p.kind == "always") and 1 or 0 end
	table.sort(groups, function(a, b)
		local xa, xb = always(a), always(b)
		if xa ~= xb then return xa < xb end
		if a.count ~= b.count then return a.count > b.count end
		return a.key < b.key
	end)
	-- a finding whose promise and plain line match a repro file of the known folder is KNOWN: counted, never shrunk again
	markKnown(groups)
	local perPromise, lines = {}, {}
	for _, g in ipairs(groups) do if not g.known then lines[g.promise] = (lines[g.promise] or 0) + 1 end end
	for i, g in ipairs(groups) do
		g.index, g.sitSet = i, nil
		g.multi = (lines[g.promise] or 0) > 1 or nil
		if not g.known then perPromise[g.promise] = (perPromise[g.promise] or 0) + 1 end
		if not g.known and perPromise[g.promise] > MAX_SHRINKS then
			g.why = "more than " .. MAX_SHRINKS .. " different failures of this promise (--max-shrinks)"
		end
	end
	return groups, raws
end

local fullCache = {}
local function fullOf(sitStr)
	if fullCache[sitStr] == nil then
		local okp, full = pcall(function() return Hunt.full(Hunt.parseSit(sitStr)) end)
		fullCache[sitStr] = okp and full or false
	end
	return fullCache[sitStr] or nil
end

local function holds(full, nd)
	if not full then return false end
	for k, v in pairs(nd) do if full[k] ~= v then return false end end
	return true
end

-- shrinks one group (at most 3 different shrunk situations for it) within cap seconds (wall) -> findings:
-- { members = { index ... }, sit, after, nsteps, seed, seen, detail, id, repro, runs, secs, flaky, why }
local function shrinkGroup(g, cap, skipWhy)
	local all = {}
	for i = 1, #g.members do all[i] = i end
	if g.known then return { { members = all, known = g.known } } end
	if skipWhy or g.why then return { { members = all, why = g.why or skipWhy } } end
	local findings = {}
	local unassigned = all
	local groupEnd = os.time() + math.max(20, math.floor(cap))
	if SHRINK_END and SHRINK_END < groupEnd then groupEnd = SHRINK_END end
	local function replayable(m) return m.kind ~= "walk" or m.steps ~= nil end
	local function order(list)
		local c = {}
		for _, i in ipairs(list) do if replayable(g.members[i]) and fullOf(g.members[i].sit) then c[#c + 1] = i end end
		local function weight(i)
			local m = g.members[i]
			local nd = 0
			for _ in pairs(Hunt.nonDefault(fullOf(m.sit))) do nd = nd + 1 end
			if m.steps then return 2000000 + #m.steps * 100 + nd end
			if m.after then return 1000000 + nd end
			return nd
		end
		table.sort(c, function(a, b) local wa, wb = weight(a), weight(b) if wa ~= wb then return wa < wb end return a < b end)
		return c
	end
	local timeWhy
	while #unassigned > 0 and #findings < 3 do
		if os.time() >= groupEnd then timeWhy = "the shrinking time was used up" break end
		local cands = order(unassigned)
		if #cands == 0 then break end
		local small, sres, runs, tried
		local t0 = os.clock()
		for t = 1, math.min(2, #cands) do
			local m = g.members[cands[t]]
			local case = { promise = g.promise, sit = fullOf(m.sit), seed = m.seed, after = m.after, steps = m.steps, match = g.blank }
			small, sres, runs = Hunt.shrink(case, { maxRuns = o.noShrink and 1 or 40, wallDeadline = groupEnd, verbose = o.verbose })
			tried = cands[t]
			if small then break end
			if Hunt.timeUp or os.time() >= groupEnd then break end
		end
		if not small then
			local late = Hunt.timeUp or os.time() >= groupEnd
			findings[#findings + 1] = { members = unassigned, flaky = not late or nil,
				why = late and "the shrinking time was used up before it failed again" or nil, secs = os.clock() - t0 }
			if not late then out("  NOT REPEATABLE: " .. g.promise .. ": " .. oneLine(g.seen, 160)) end
			unassigned = {}
			break
		end
		local id = Hunt.caseId(small) .. (g.multi and ("-" .. Hunt.hex(g.blank)) or "")
		local m = g.members[tried]
		local path = Hunt.writeRepro(small, sres, REPRO, { found = m.found, addon = o.addon and Hunt.addonDir or nil, id = id })
		local f = { sit = Hunt.sitString(small.sit), after = small.after, nsteps = small.steps and #small.steps or nil, seed = small.seed,
			seen = sres.seen, detail = sres.detail, id = id, repro = rel(path), runs = runs, secs = os.clock() - t0, members = {} }
		local nd = Hunt.nonDefault(small.sit)
		local rest = {}
		for _, i in ipairs(unassigned) do
			if i == tried or holds(fullOf(g.members[i].sit), nd) then f.members[#f.members + 1] = i else rest[#rest + 1] = i end
		end
		findings[#findings + 1] = f
		unassigned = rest
		out(("  shrunk %s in %d runs (%.0f s) to %s%s%s -> %s"):format(g.promise, runs or 0, f.secs, f.sit, f.after and (" after " .. f.after) or "",
			f.nsteps and (", " .. f.nsteps .. " steps") or "", f.repro))
	end
	if #unassigned > 0 then
		if #findings > 0 then
			local f = findings[1]
			for _, i in ipairs(unassigned) do f.members[#f.members + 1] = i end
			f.others = (f.others or 0) + #unassigned
			f.othersWhy = timeWhy or "three situations of this line were shrunk already"
		else
			findings[#findings + 1] = { members = unassigned, why = timeWhy or "none of its failures can be replayed (a long session's steps were not kept)" }
		end
	end
	return findings
end

local function shrinkAll(groups, budget, skipWhy)
	local results, t0 = {}, os.time()
	local stop = os.time() + budget
	local todo = 0
	for _, g in ipairs(groups) do if not g.why and not g.known then todo = todo + 1 end end
	for _, g in ipairs(groups) do
		local left = stop - os.time()
		local cap = left / math.max(1, todo)
		if not g.why and not g.known then todo = todo - 1 end
		if left <= 0 and not skipWhy and not g.known then results[g.index] = shrinkGroup(g, 0, "the shrinking time (--shrink-seconds) was used up")
		else results[g.index] = shrinkGroup(g, cap, skipWhy) end
	end
	return results, os.time() - t0
end

---------------------------------------------------------------------------
-- the join: FAILURES.md, failures.tsv, cannot.tsv, broken.tsv, summary.txt, KNOWN.md
---------------------------------------------------------------------------

local function compose(n, st, groups, raws, results, shrinkWall)
	local fl, nr, nns, shrinkCpu, nknown = {}, 0, 0, 0, 0
	for _, g in ipairs(groups) do
		local list = results[g.index] or { { members = (function() local a = {} for i = 1, #g.members do a[i] = i end return a end)(),
			why = "its shrinking process stopped before it (the time ran out, or it died)" } }
		for j, f in ipairs(list) do
			f.group = g
			if g.known and not f.known then f.known = g.known end
			if f.known then nknown = nknown + 1 end
			f.count = 0
			local sitsSeen, nsits = {}, 0
			for _, i in ipairs(f.members) do
				local m = g.members[i]
				f.count = f.count + (m and m.count or 1)
				if m and not sitsSeen[m.sit] then sitsSeen[m.sit] = true nsits = nsits + 1 end
			end
			if j == 1 then f.count = f.count + (g.over or 0) end
			f.nsits = (#list == 1) and g.nsits or nsits
			if f.flaky then nr = nr + 1 end
			if not f.repro and not f.flaky and not f.known then nns = nns + 1 end
			shrinkCpu = shrinkCpu + (f.secs or 0)
			fl[#fl + 1] = f
		end
	end
	for i, f in ipairs(fl) do f.fid = ("F%03d"):format(i) end
	local np, ns = 0, 0
	for _ in pairs(st.promises) do np = np + 1 end
	for _ in pairs(st.sits) do ns = ns + 1 end
	local c, a, w = st.counts, st.after, st.walks
	local md = { "# Bug hunt failures: " .. RUN, "", st.header and ("Run: " .. st.header) or "", "",
		("Checks: %d (%d promises x %d situations), pass %d, fail %d, na %d, cannot-build %d, broken-check %d, %.0f s of checks."):format(
			st.checks, np, ns, c.pass, c.fail, c.na, c["cannot-build"], c["broken-check"], st.secs),
		("Always-promises after each check: %d, pass %d, fail %d, na %d, broken-check %d."):format(a.n or 0, a.pass or 0, a.fail or 0, a.na or 0, a["broken-check"] or 0) }
	if w.n > 0 then
		md[#md + 1] = ("Long sessions: %d walks, %d steps in %.0f s (%.1f steps a second); %d starts could not build and were skipped; %d findings kept, %d repeats muted%s%s."):format(
			w.n, w.steps, w.secs, w.secs > 0 and w.steps / w.secs or 0, w.skipped, w.findings, w.muted,
			w.stopped > 0 and (", " .. w.stopped .. " stopped by the time") or "", w.ended > 0 and (", " .. w.ended .. " ended early (the world stopped working or no action was possible)") or "")
	end
	md[#md + 1] = ("Distinct failures: %d (known %d, new %d; from %d raw failures in %d groups); not repeatable %d; not shrunk %d; shrinking %.0f s (CPU)%s."):format(
		#fl, nknown, #fl - nknown, raws, #groups, nr, nns, shrinkCpu, shrinkWall and (", " .. shrinkWall .. " s wall") or "")
	if st.resumed > 0 then md[#md + 1] = ("%d passed checks of an earlier sweep were not run again (--resume); they are not in the counts above."):format(st.resumed) end
	if st.dropped > 0 then md[#md + 1] = ("The budget or the deadline dropped %d checks (the shards' results files list them per promise)."):format(st.dropped) end
	md[#md + 1] = ""
	if #st.missing > 0 then md[#md + 1] = "MISSING shard files: " .. table.concat(st.missing, ", ") .. " (that part did not run or did not finish)" md[#md + 1] = "" end
	if #st.partial > 0 then md[#md + 1] = "PARTIAL shard files (no end line: the shard died or was stopped; what it wrote is counted): " .. table.concat(st.partial, ", ") md[#md + 1] = "" end
	if #fl == 0 then md[#md + 1] = "No failures." md[#md + 1] = "" end
	local tsv = { table.concat({ "id", "promise", "promise_text", "seen", "detail", "situation", "count", "situations", "repro", "after", "status", "examples" }, "\t") }
	local mdNew, mdKnown, tsvNew = {}, {}, { tsv[1] }
	for _, f in ipairs(fl) do
		local g = f.group
		local ent = {}
		local p = Hunt.promises[g.promise]
		local seen = f.seen or g.seen
		local detail = oneLine(f.detail or g.detail or "", 300)
		local sit = f.sit and (f.sit .. (f.after and (", after " .. f.after) or "") .. (f.nsteps and (", " .. f.nsteps .. " steps") or "") .. ", seed " .. tostring(f.seed))
		local ex = {}
		for _, i in ipairs(f.members) do
			local m = g.members[i]
			if m and #ex < 3 then
				ex[#ex + 1] = m.sit .. (m.after and (" after " .. m.after) or "") .. (m.nsteps and (" (walk, step " .. tostring(m.step or m.nsteps) .. ")") or "") .. " seed " .. tostring(m.seed)
			end
		end
		local afterNames = Hunt.sortedKeys(g.afters)
		local afterStr = ""
		if #afterNames > 0 then
			afterStr = "after " .. afterNames[1] .. (#afterNames > 1 and (" and " .. (#afterNames - 1) .. " more scenarios") or "")
		end
		local status = f.known and "known" or f.repro and "repro" or (f.flaky and "not-repeatable" or "not-shrunk")
		ent[#ent + 1] = "## " .. f.fid .. " " .. g.promise
		ent[#ent + 1] = ""
		ent[#ent + 1] = "Promise: " .. tostring(p and p.text or "?")
		ent[#ent + 1] = ""
		ent[#ent + 1] = "- The player sees: " .. tostring(seen)
		if g.sameAs then ent[#ent + 1] = "- same promise as " .. g.sameAs .. " (other line)" end
		if detail ~= "" then ent[#ent + 1] = "- Detail: " .. detail end
		ent[#ent + 1] = "- Situation" .. (f.repro and " (shrunk)" or "") .. ": " .. tostring(sit or (ex[1] or "?"))
		ent[#ent + 1] = ("- Count: %d raw failures in %d different situations; examples: %s"):format(f.count, f.nsits, table.concat(ex, "; "))
		if #afterNames > 0 then
			ent[#ent + 1] = "- Found by an always-promise " .. afterStr .. (f.repro and (f.after and " (the repro needs the scenario first)" or " (the repro does not need the scenario)") or "")
		end
		local walksN = 0
		for _, i in ipairs(f.members) do if g.members[i] and g.members[i].kind == "walk" then walksN = walksN + 1 end end
		if walksN > 0 then ent[#ent + 1] = "- Found in " .. walksN .. " long session" .. (walksN > 1 and "s" or "") end
		if f.repro then ent[#ent + 1] = "- Repro: lua5.1 " .. f.repro .. (f.runs and (" (shrunk in " .. f.runs .. " runs, " .. ("%.0f"):format(f.secs or 0) .. " s)") or "")
		elseif f.flaky then ent[#ent + 1] = "- NOT REPEATABLE: it did not fail again when re-run, so no repro was written (look at it by hand)"
		else ent[#ent + 1] = "- Not shrunk, no repro: " .. tostring(f.why or "?") end
		if f.others then ent[#ent + 1] = ("- %d of these were not shrunk on their own (%s); they may be another cause."):format(f.others, f.othersWhy or "?") end
		ent[#ent + 1] = ""
		if f.known then
			ent = { "## " .. f.fid .. " " .. g.promise .. " (" .. (f.known.hunt or "not on the list yet") .. ")", "",
				"- The player sees: " .. tostring(seen),
				("- Count: %d raw failures in %d different situations; examples: %s"):format(f.count, f.nsits, table.concat(ex, "; ")),
				(f.known.elsewhere and ("- " .. (f.known.repro:find("^known elsewhere") and "" or "Known elsewhere: ") .. tostring(f.known.repro) .. " (" .. tostring(f.known.id) .. "); no repro file")
					or ("- Known repro: lua5.1 " .. tostring(f.known.repro) .. " (" .. tostring(f.known.id) .. "); not shrunk again"))
					.. (f.known.another and (" (another situation: " .. f.known.another .. ")") or ""), "" }
		end
		local dest = f.known and mdKnown or mdNew
		for _, l in ipairs(ent) do dest[#dest + 1] = l end
		local row = table.concat({ f.fid, g.promise, tsvField(p and p.text), tsvField(seen), tsvField(detail), tsvField(sit or ex[1]), f.count, f.nsits,
			tsvField(f.known and (f.known.repro .. (f.known.another and (" (another situation: " .. f.known.another .. ")") or "")) or f.repro or ""), tsvField(afterStr), status, tsvField(table.concat(ex, "; ")) }, "\t")
		tsv[#tsv + 1] = row
		if not f.known then tsvNew[#tsvNew + 1] = row end
	end
	if #mdNew > 0 then md[#md + 1] = "# New (not on the list yet)" md[#md + 1] = "" for _, l in ipairs(mdNew) do md[#md + 1] = l end end
	if #mdKnown > 0 then
		md[#md + 1] = "# Known (already on the list)"
		md[#md + 1] = ""
		md[#md + 1] = "Same promise and plain line as a repro file in the known folder (for universal.* the looser line; or listed in tests/hunt/known-elsewhere.tsv, marked 'whole promise, line not checked' when the row gives no line): counted, not shrunk again, no new repro file."
		md[#md + 1] = ""
		for _, l in ipairs(mdKnown) do md[#md + 1] = l end
	end
	local bk = Hunt.sortedKeys(st.broken)
	local btsv = { "promise\tcount\tdetail\tsituation\tseed" }
	if #bk > 0 then
		md[#md + 1] = "## Broken checks (the check itself raised: NOT bugs; fix the promise or the action)"
		md[#md + 1] = ""
		for _, pid in ipairs(bk) do
			local b = st.broken[pid]
			md[#md + 1] = ("- %s: %d, first in %s: %s"):format(pid, b.n, b.sit, oneLine(b.detail or "?", 300))
			btsv[#btsv + 1] = table.concat({ pid, b.n, tsvField(oneLine(b.detail or "?", 300)), tsvField(b.sit), tsvField(b.seed) }, "\t")
		end
		md[#md + 1] = ""
	end
	local ck = Hunt.sortedKeys(st.cannot)
	local ctsv = { "reason\tcount\tsituation\tpromise" }
	if #ck > 0 then
		md[#md + 1] = "## Cannot build (a dial or check could not reach its state: NOT bugs)"
		md[#md + 1] = ""
		table.sort(ck, function(x, y) if st.cannot[x].n ~= st.cannot[y].n then return st.cannot[x].n > st.cannot[y].n end return x < y end)
		for _, why in ipairs(ck) do
			local cc = st.cannot[why]
			md[#md + 1] = ("- %d x %s (first: %s, %s)"):format(cc.n, why, cc.pid, cc.sit)
			ctsv[#ctsv + 1] = table.concat({ tsvField(why), cc.n, tsvField(cc.sit), tsvField(cc.pid) }, "\t")
		end
		md[#md + 1] = ""
	end
	if #st.notes > 0 then
		md[#md + 1] = "## Notes"
		md[#md + 1] = ""
		for _, nt in ipairs(st.notes) do md[#md + 1] = "- " .. nt end
	end
	Hunt.mkdir(OUT)
	Hunt.writeFile(OUT .. "/FAILURES.md", table.concat(md, "\n") .. "\n")
	Hunt.writeFile(OUT .. "/failures.tsv", table.concat(tsv, "\n") .. "\n")
	Hunt.writeFile(OUT .. "/failures-new.tsv", table.concat(tsvNew, "\n") .. "\n")
	Hunt.writeFile(OUT .. "/broken.tsv", table.concat(btsv, "\n") .. "\n")
	Hunt.writeFile(OUT .. "/cannot.tsv", table.concat(ctsv, "\n") .. "\n")
	local summary = ("hunt %s: %d checks (%d promises x %d situations), pass %d, fail %d, na %d, cannot-build %d, broken-check %d, %.0f s; distinct failures %d (known %d, new %d); after-checks %d (fail %d); not-repeatable %d; not-shrunk %d; raw failures %d; shrinking %.0f s CPU%s"):format(
		RUN, st.checks, np, ns, c.pass, c.fail, c.na, c["cannot-build"], c["broken-check"], st.secs, #fl, nknown, #fl - nknown, a.n or 0, a.fail or 0, nr, nns, raws, shrinkCpu,
		shrinkWall and (" (" .. shrinkWall .. " s wall)") or "")
	if w.n > 0 then
		summary = summary .. ("; walks %d, steps %d, %.1f steps/s, starts skipped %d, findings %d, muted %d"):format(w.n, w.steps, w.secs > 0 and w.steps / w.secs or 0, w.skipped, w.findings, w.muted)
	end
	Hunt.writeFile(OUT .. "/summary.txt", summary .. "\n")
	out(summary)
	local reproCounts = {}
	for _, f in ipairs(fl) do
		local rid = f.id or (f.known and f.known.id)
		if rid and not (f.known and f.known.elsewhere) then reproCounts[rid] = (reproCounts[rid] or 0) + f.count end
	end
	if o.one and o.mode ~= "walk" and not o.shrink then
		out("FAILURES.md: " .. rel(OUT .. "/FAILURES.md"))
	else
		local nk = Hunt.writeKnown(REPRO, KNOWN, reproCounts)
		out("FAILURES.md: " .. rel(OUT .. "/FAILURES.md") .. " (and failures.tsv, cannot.tsv, broken.tsv); " .. rel(KNOWN) .. ": " .. nk .. " repro files")
	end
	if #st.missing > 0 then out("MISSING shard files: " .. table.concat(st.missing, ", ")) end
	if #st.partial > 0 then out("PARTIAL shard files: " .. table.concat(st.partial, ", ")) end
	return #fl
end

local function loadPlan(n)
	local chunk = loadfile(OUT .. "/groups.lua")
	if not chunk then return nil end
	local okc, plan = pcall(chunk)
	if not (okc and type(plan) == "table" and plan.n == n and plan.token == token(n)) then return nil end
	return plan
end

local function join(n)
	local st = readStats(n)
	local plan = o.join and loadPlan(n)
	if plan then
		-- sweep.ps1: --plan grouped, --shrink-part K/M shrank; read their results
		local results, wall = {}, nil
		for _, path in ipairs(Hunt.listLua(OUT)) do
			if path:match("/shrunk%.%d+%-of%-%d+%.lua$") then
				local text = Hunt.readFile(path) or ""
				for line in text:gmatch("[^\n]+") do
					if line:sub(1, 2) == "G{" then
						local chunk = loadstring("return " .. line:sub(2))
						local okc, rec = false, nil
						if chunk then okc, rec = pcall(chunk) end
						if okc and type(rec) == "table" and rec.token == plan.token and rec.g then results[rec.g] = rec.findings end
					elseif line:match("^# wall ") then
						local s = tonumber(line:match("(%d+)"))
						if s and (not wall or s > wall) then wall = s end
					end
				end
			end
		end
		-- the matching may be newer than the plan (a rejoin), but never through a repro file this run's own shrinking wrote
		-- (it is in the known folder by now: every new finding would match its own file and count as known)
		local own = {}
		for _, list in pairs(results) do for _, f in ipairs(list) do if f.repro then own[rel(Hunt.norm(f.repro))] = true end end end
		markKnown(plan.groups, own)
		return compose(n, st, plan.groups, plan.raws or 0, results, wall)
	end
	local groups, raws = makeGroups(n)
	local skipWhy = (o.one and o.mode ~= "walk" and not o.shrink) and "--one without --shrink does not shrink" or nil
	if #groups > 0 and not skipWhy then out(("shrinking %d groups of failures (%d raw), at most %d s"):format(#groups, raws, SHRINK_SECONDS)) end
	local results, wall = shrinkAll(groups, SHRINK_SECONDS, skipWhy)
	return compose(n, st, groups, raws, results, (#groups > 0 and not skipWhy) and wall or nil)
end

if o.join then
	local nfail = join(o.join)
	os.exit(nfail > 0 and 1 or 0)
end

if o.plan then
	local groups, raws = makeGroups(o.plan)
	Hunt.mkdir(OUT)
	Hunt.writeFile(OUT .. "/groups.lua", "return " .. Hunt.ser({ n = o.plan, token = token(o.plan), raws = raws, groups = groups }) .. "\n")
	local walkG = 0
	for _, g in ipairs(groups) do if g.walkSteps > 0 then walkG = walkG + 1 end end
	out(("groups: %d (from %d raw failures; %d with long-session steps)"):format(#groups, raws, walkG))
	os.exit(0)
end

if o.shrinkPart then
	local k, m = o.shrinkPart:match("^(%d+)/(%d+)$")
	k, m = tonumber(k), tonumber(m)
	if not (k and m and k >= 1 and k <= m) then io.stderr:write("--shrink-part K/M\n") os.exit(2) end
	local chunk = loadfile(OUT .. "/groups.lua")
	local okc, plan = false, nil
	if chunk then okc, plan = pcall(chunk) end
	if not (okc and type(plan) == "table") then io.stderr:write("--shrink-part: no groups.lua in " .. OUT .. " (run --plan first)\n") os.exit(2) end
	local mine = {}
	for _, g in ipairs(plan.groups) do if (g.index - 1) % m == k - 1 then mine[#mine + 1] = g end end
	local f = assert(io.open(OUT .. "/shrunk." .. k .. "-of-" .. m .. ".lua", "wb"))
	f:write(("# shrink part %d/%d: %d groups\n"):format(k, m, #mine))
	f:flush()
	local budget = DEADLINE and (DEADLINE - os.time()) or SHRINK_SECONDS
	local stop = os.time() + budget
	SHRINK_END = stop
	out(("shrink part %d/%d: %d groups, %d s"):format(k, m, #mine, budget))
	local todo = 0
	for _, g in ipairs(mine) do if not g.why and not g.known then todo = todo + 1 end end
	for _, g in ipairs(mine) do
		local left = stop - os.time()
		local res
		if left <= 0 then res = shrinkGroup(g, 0, "the shrinking time was used up")
		else res = shrinkGroup(g, left / math.max(1, todo)) end
		if not g.why and not g.known then todo = todo - 1 end
		f:write("G" .. Hunt.serLine({ token = plan.token, g = g.index, findings = res }) .. "\n")
		f:flush()
	end
	f:write("# wall " .. (os.time() - T0) .. "\n")
	f:close()
	os.exit(0)
end

out("Wuber: " .. Hunt.addonInfo())
loadReport()

if o.makeSets then
	-- only the pairwise sets of this shard's promises (into the cache unless --no-cache); the time is the point
	local t0, made, sits = os.clock(), 0, 0
	for idx, p in ipairs(selected()) do
		if (idx - 1) % N == K - 1 then
			local okg, list, why = pcall(Sit.forPromise, p, "pairs", o.seed)
			if okg and list then sits = sits + #list made = made + 1
			elseif not okg then out("broken: the set of " .. p.id .. " raised: " .. tostring(type(list) == "table" and (list.detail or list.hunt) or list)) end
		end
	end
	out(("sets: %d promises, %d situations in %.1f s; %d read from the cache, %d made, %d written"):format(made, sits, os.clock() - t0,
		Sit.stats.hits, Sit.stats.made, Sit.stats.written))
	os.exit(0)
end

---------------------------------------------------------------------------
-- results and raw failures (shards never shrink: the join does)
---------------------------------------------------------------------------
Hunt.mkdir(OUT)
local RESULTS = OUT .. "/results." .. K .. "-of-" .. N .. ".txt"
local rf = assert(io.open(RESULTS, "wb"))
local rawf = assert(io.open(OUT .. "/raw." .. K .. "-of-" .. N .. ".lua", "wb"))
rf:write(("# hunt mode=%s seed=%d n=%s steps=%d promise=%s shard=%d/%d budget=%s addon=%s%s%s%s\n"):format(o.mode, o.seed, tostring(o.n),
	o.steps, tostring(o.promise or "all"), K, N, tostring(o.budget or o.total or "none"), Hunt.addonInfo(),
	o.stepsMax and (" steps-range=" .. o.stepsMin .. "-" .. o.stepsMax) or "", #o.skip > 0 and (" skip=" .. table.concat(o.skip, ",")) or "",
	o.deadline and (" deadline=" .. o.deadline) or ""))
rf:flush()
local function line(st, pid, sit, seed, secs, note)
	rf:write(("%s\t%s\t%s\t%s\t%.2f%s\n"):format(st, pid, sit, tostring(seed), secs or 0, note and ("\t" .. oneLine(note, 600)) or ""))
	rf:flush()
end
local failures, byKey = {}, {}
local function rawFail(rec)
	rawf:write("F" .. Hunt.serLine(rec) .. "\n")
	rawf:flush()
	local key = Hunt.findingKey(rec.promise, rec.seen)
	local e = byKey[key]
	if e then e.count = e.count + 1 return end
	e = { promise = rec.promise, seen = rec.seen, sit = rec.sit, seed = rec.seed, after = rec.after, steps = rec.steps and #rec.steps or nil,
		found = rec.found, count = 1 }
	byKey[key] = e
	failures[#failures + 1] = e
end
local after = { n = 0, pass = 0, fail = 0, na = 0, ["broken-check"] = 0, ["cannot-build"] = 0 }
local done, doneSecs = 0, 0

local function record(res)
	done, doneSecs = done + 1, doneSecs + (res.secs or 0)
	local note
	if res.status == "fail" then note = "seen: " .. tostring(res.seen)
	elseif res.status ~= "pass" then note = "detail: " .. tostring(res.detail) end
	line(res.status, res.promise, res.sit, res.seed, res.secs, note)
	out(("%-12s %s  %s  (%.1f s)%s%s"):format(res.status, res.promise, res.sit, res.secs or 0,
		(o.one and res.status == "na" and res.detail) and ("  (" .. oneLine(res.detail, 300) .. ")") or "",
		res.status == "fail" and ("\n      " .. tostring(res.seen)) or (res.status ~= "pass" and res.status ~= "na" and o.verbose and ("\n      " .. oneLine(res.detail, 400)) or "")))
end

local function recordAfter(res, case, found)
	for _, a in ipairs(res.always or {}) do
		after.n = after.n + 1
		after[a.status] = (after[a.status] or 0) + 1
		if a.status == "fail" or a.status == "broken-check" or a.status == "cannot-build" then
			line(a.status, a.promise, res.sit, res.seed, 0, "after " .. res.promise .. (a.status == "fail" and ("; seen: " .. tostring(a.seen)) or ("; detail: " .. tostring(a.detail))))
			if a.status == "fail" then
				out(("%-12s %s  %s  (after %s)\n      %s"):format("fail", a.promise, res.sit, res.promise, tostring(a.seen)))
				rawFail({ promise = a.promise, seen = a.seen, detail = a.detail, sit = Hunt.sitString(case.sit), seed = case.seed, after = case.promise,
					found = found .. " after " .. case.promise, kind = "after" })
			end
		end
	end
end

local function finish(totalItems, dropped)
	rf:write(("# after n=%d pass=%d fail=%d na=%d broken-check=%d cannot-build=%d\n"):format(after.n, after.pass, after.fail, after.na,
		after["broken-check"], after["cannot-build"]))
	for _, d in ipairs(dropped or {}) do rf:write("# dropped " .. d .. "\n") end
	for _, e in ipairs(Hunt.loadErrors) do rf:write("# load error " .. e.file .. ": " .. oneLine(e.err:match("^[^\n]*"), 200) .. "\n") end
	rf:write(("# end checks=%d secs=%.0f wall=%d\n"):format(done, doneSecs, os.time() - T0))
	rf:close()
	rawf:close()
	-- the older per-process list (deduplicated, with counts), for anything that still reads it
	local ser = { "return {" }
	for _, f in ipairs(failures) do ser[#ser + 1] = "\t" .. Hunt.ser(f, "\t") .. "," end
	ser[#ser + 1] = "}"
	Hunt.writeFile(OUT .. "/failures." .. K .. "-of-" .. N .. ".lua", table.concat(ser, "\n") .. "\n")
	local avg = done > 0 and doneSecs / done or 0
	out(("shard %d/%d: %d checks in %.0f s (%.2f s per build + check, the always-promises included); %d s wall"):format(K, N, done, doneSecs, avg, os.time() - T0))
	if totalItems then
		out(("this shard made %d situations (%.1f min of checks at this rate)"):format(totalItems, totalItems * avg / 60))
	end
	for i, d in ipairs(dropped or {}) do
		if i <= 12 then out("dropped by the budget: " .. d) elseif i == 13 then out("dropped by the budget: ... " .. (#dropped - 12) .. " more promises (results file)") end
	end
	if N == 1 then
		-- (the deadline was for the checks: the shrinking here has its own time, --shrink-seconds)
		Hunt.hardStop, Hunt.timeUp = nil, nil
		join(1)
	end
end

---------------------------------------------------------------------------
-- walks (long sessions): every distinct finding kept, the walk goes on to its last step
---------------------------------------------------------------------------
local function walks(fixed)
	if #Hunt.actionOrder == 0 then
		out("walk mode: no actions are registered (tests/hunt/actions.lua is missing or did not load): nothing to walk")
		finish()
		os.exit(0)
	end
	local n = o.n or (fixed and 3 or 20)
	local starts = not fixed and Sit.walkStarts(o.seed, n) or nil
	local MAX_TRIES = 30
	local droppedN, allSteps, allSecs = 0, 0, 0
	for j = 1, n do
		if (j - 1) % N == K - 1 then
			if DEADLINE and os.time() >= DEADLINE then droppedN = droppedN + 1 else
				local wseed = Hunt.caseSeed(o.seed, "walk", tostring(j))
				local nsteps = o.steps
				if o.stepsMax then nsteps = o.stepsMin + Hunt.rng(wseed):fork("length"):int(o.stepsMax - o.stepsMin + 1) - 1 end
				local res, sit, skipped = nil, nil, 0
				for t = 0, MAX_TRIES - 1 do
					sit = fixed or starts[j + t * n] or Sit.random(Hunt.domains(nil), nil, Hunt.hash("walk-extra", j * 1000 + t), 1)[1] or Hunt.full({})
					res = Hunt.walk(sit, wseed, nsteps, { keepGoing = true, verbose = o.verbose, deadline = DEADLINE })
					if res.status ~= "cannot-build" and res.status ~= "na" then break end
					if Hunt.timeUp then break end
					line(res.status, "walk", Hunt.sitString(sit), wseed, res.secs, "detail: " .. tostring(res.detail) .. " (a walk start, skipped)")
					skipped = skipped + 1
					if fixed then break end
				end
				local sitStr = Hunt.sitString(sit)
				if res.status == "cannot-build" or res.status == "na" then
					out(("walk %d: no start could build (%d tried)%s"):format(j, skipped, fixed and (": " .. oneLine(res.detail, 300)) or ""))
					rf:write(("# walk %d steps=0 want=%d secs=0 findings=0 muted=0 skipped=%d\n"):format(j, nsteps, skipped))
				else
					done, doneSecs = done + 1, doneSecs + (res.secs or 0)
					local nf = #res.findings
					line(res.status, "walk", sitStr, wseed, res.secs, ("walked %d of %d steps, %d findings, %d repeats muted%s%s"):format(
						res.stepsDone, nsteps, nf, res.muted, res.stopped and ("; stopped: " .. res.stopped) or "", res.ended and ("; ended: " .. res.ended) or ""))
					rf:write(("# walk %d steps=%d want=%d secs=%.1f findings=%d muted=%d skipped=%d stopped=%d ended=%d\n"):format(j, res.stepsDone, nsteps,
						res.secs or 0, nf, res.muted, skipped, res.stopped and 1 or 0, res.ended and 1 or 0))
					allSteps, allSecs = allSteps + res.stepsDone, allSecs + (res.secs or 0)
					out(("walk %d: %d of %d steps in %.0f s (%.1f steps a second), %d findings, %d repeats muted%s; start %s%s%s"):format(j, res.stepsDone, nsteps,
						res.secs or 0, (res.secs or 0) > 0 and res.stepsDone / res.secs or 0, nf, res.muted,
						skipped > 0 and (" (" .. skipped .. " starts skipped)") or "", sitStr, res.stopped and ("; stopped: " .. res.stopped) or "",
						res.ended and ("; ended: " .. res.ended) or ""))
					for _, f in ipairs(res.findings) do
						if f.status == "fail" then
							line("fail", f.promise, sitStr, wseed, 0, "walk step " .. f.step .. "; seen: " .. tostring(f.seen))
							out(("    step %d: fail %s: %s"):format(f.step, f.promise, oneLine(f.seen, 200)))
							local steps = {}
							for i = 1, f.step do steps[i] = res.steps[i] end
							rawFail({ promise = f.promise, seen = f.seen, detail = f.detail, sit = sitStr, seed = wseed, steps = steps, step = f.step,
								kind = "walk", found = RUN .. " walk " .. j .. " step " .. f.step })
						else
							line("broken-check", f.promise, sitStr, wseed, 0, "walk step " .. f.step .. "; detail: " .. tostring(f.detail))
							out(("    step %d: broken %s: %s"):format(f.step, f.promise, oneLine(f.detail, 200)))
						end
					end
				end
			end
		end
	end
	if allSecs > 0 then out(("walks: %d steps in %.0f s, %.1f steps a second"):format(allSteps, allSecs, allSteps / allSecs)) end
	finish(nil, droppedN > 0 and { "walk: " .. droppedN .. " walks (the deadline)" } or nil)
	os.exit(#failures > 0 and 1 or 0)
end

---------------------------------------------------------------------------
-- --one: one situation, each selected promise (all when none is given); with --mode walk, long sessions from it
---------------------------------------------------------------------------
if o.one then
	local sit = Hunt.parseSit(o.one)
	local okf, ferr = pcall(Hunt.full, sit)
	if not okf then io.stderr:write(tostring(ferr) .. "\n") os.exit(2) end
	do
		-- a state no player could be in (a dial's valid() or excludes): na, never a pass or a bug
		local okc, why = Hunt.compatible(ferr)
		if not okc then
			out("na (" .. tostring(why) .. ")  " .. Hunt.sitString(ferr))
			os.exit(0)
		end
	end
	if o.mode == "walk" then
		rf:write("# --one " .. o.one .. "\n")
		walks(ferr)
	end
	local list = selected()
	if #list == 0 then io.stderr:write("no promise starts with " .. tostring(o.promise) .. "\n") os.exit(2) end
	local anyFail = false
	for _, p in ipairs(list) do
		local full = Hunt.project(p, sit)
		local seed = o.seed
		local res = Hunt.runPromise(p, sit, seed, { verbose = o.verbose })
		record(res)
		if o.verbose then
			for _, e in ipairs(res.log or {}) do out("    " .. Hunt.logLine(e)) end
			if res.detail then out("    detail: " .. oneLine(res.detail, 1500)) end
			if res.texts then out("    on screen: " .. oneLine(table.concat(res.texts, " | "), 1500)) end
		end
		local fsit = full or Hunt.full(sit)
		recordAfter(res, { promise = p.id, sit = fsit, seed = seed }, "--one")
		if res.status == "fail" then
			anyFail = true
			rawFail({ promise = p.id, seen = res.seen, detail = res.detail, sit = Hunt.sitString(fsit), seed = seed, found = "--one", kind = "one" })
		end
		if o.verbose then
			for _, a in ipairs(res.always or {}) do
				if a.status ~= "pass" and a.status ~= "na" then out(("    after: %s %s %s"):format(a.status, a.promise, oneLine(a.seen or a.detail, 300))) end
			end
		end
	end
	rf:write("# --one " .. o.one .. "\n")
	finish()
	os.exit(anyFail and 1 or 0)
end

if o.mode == "walk" then walks(nil) end

---------------------------------------------------------------------------
-- pairs / random: the promises share the time (the one that has used least runs next), pairwise first
---------------------------------------------------------------------------
if o.mode ~= "pairs" and o.mode ~= "random" then io.stderr:write("--mode pairs|random|walk\n") os.exit(2) end
local list = selected()
if #list == 0 then io.stderr:write("no promise starts with " .. tostring(o.promise) .. "\n") os.exit(2) end
local budget = o.budget
local limited = o.budget or o.total or o.deadline
-- each promise belongs to one shard (promise i of the list to shard (i - 1) % N + 1): a shard makes only its own
-- promises' sets, when it first runs them (a pairwise set takes a second or two), and random ones only when a
-- promise's pairwise set is used up (with a budget or a deadline)
local work, dropped, genSecs = {}, {}, 0
for idx, p in ipairs(list) do
	if (idx - 1) % N == K - 1 then work[#work + 1] = { p = p, next = 1, spent = 0, idx = idx } end
end
local function moreRandom(wk)
	if wk.randomDone or o.mode ~= "pairs" or not limited then return false end
	wk.randomDone = true
	local t0 = os.clock()
	local skip = {}
	for _, it in ipairs(wk.items) do skip[Sit.key(it.sit)] = true end
	local n0 = #wk.items
	for _, s in ipairs(Sit.forPromise(wk.p, "random", o.seed, o.n or 200, skip) or {}) do wk.items[#wk.items + 1] = { sit = s, kind = "random" } end
	genSecs = genSecs + (os.clock() - t0)
	return #wk.items > n0
end
-- the promise's next situation: its pairwise set is made as it is asked for (Sit.forPromiseStream), then random ones
local function nextItem(wk)
	local p = wk.p
	if not wk.items then
		wk.items = {}
		local t0 = os.clock()
		local okg, gen, why = pcall(Sit.forPromiseStream, p, o.mode, o.seed, o.n or 50)
		genSecs = genSecs + (os.clock() - t0)
		if not okg then
			line("broken-check", p.id, "-", "-", 0, "detail: making its set raised: " .. tostring(type(gen) == "table" and (gen.detail or gen.hunt) or gen))
		elseif not gen then
			line("na", p.id, "-", "-", 0, "detail: " .. tostring(why))
		else
			wk.gen = gen
		end
	end
	if wk.next <= #wk.items then return wk.items[wk.next] end
	if wk.gen then
		local t0 = os.clock()
		local okg, s = pcall(wk.gen)
		genSecs = genSecs + (os.clock() - t0)
		if okg and s then
			wk.items[#wk.items + 1] = { sit = s, kind = o.mode }
			return wk.items[wk.next]
		end
		wk.gen = nil
		wk.setDone = true
		if not okg then
			line("broken-check", p.id, "-", "-", 0, "detail: making its set raised: " .. tostring(type(s) == "table" and (s.detail or s.hunt) or s))
		elseif #wk.items == 0 then
			line("na", p.id, "-", "-", 0, "detail: no situation of its " .. (o.mode == "pairs" and "pairwise" or "random") .. " set can exist (its needs, when() and the dials' excludes rule them all out)")
		end
	end
	if moreRandom(wk) then return wk.items[wk.next] end
	return nil
end
-- --resume: the (promise, situation) pairs an earlier sweep passed, valid only while the promise's signature is unchanged
local resumeSet, resumeSig, resumedN, resumeDirs = {}, {}, 0, 0
if o.resume then
	local rdir = Hunt.norm(o.resume)
	for _, path in ipairs(Hunt.H.listFiles(rdir, "txt")) do
		local name = Hunt.norm(path):match("[^/]*$")
		if name:match("^results%.%d+%-of%-%d+%.txt$") then
			resumeDirs = resumeDirs + 1
			for ln in (Hunt.readFile(path) or ""):gmatch("[^\n]+") do
				local pid, sg = ln:match("^# psig (%S+) (%S+)")
				if pid then resumeSig[pid] = sg
				else
					local stt, pid2, sit2, _, _, note = ln:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t?(.*)$")
					if stt == "pass" and not (note or ""):match("^after ") and not (note or ""):match("^walk step ") then resumeSet[pid2 .. "\t" .. sit2] = true end
				end
			end
		end
	end
	if resumeDirs == 0 then io.stderr:write("--resume: no results.K-of-N.txt in " .. rdir .. "\n") os.exit(2) end
end
local addonSig = Hunt.hex(Hunt.addonInfo())
local psigs = {}
local function psigOf(p)
	if psigs[p.id] == nil then
		local sg = Sit.promiseSig(p)
		psigs[p.id] = sg and (sg .. "-" .. addonSig) or false
	end
	return psigs[p.id]
end
local function resumeSkip(p, sitStr)
	if not o.resume then return false end
	local sg = psigOf(p)
	return sg and resumeSig[p.id] == sg and resumeSet[p.id .. "\t" .. sitStr] or false
end
out(("%d promises, %d in this shard (%d/%d)%s%s%s"):format(#list, #work, K, N,
	budget and (", budget " .. ("%.0f"):format(budget) .. " s per promise") or "", o.total and (", " .. o.total .. " s of checks in all") or "",
	o.deadline and (", deadline " .. o.deadline .. " s") or ""))
local spentAll, stopWhy = 0, nil
while true do
	if DEADLINE and os.time() >= DEADLINE then stopWhy = "the deadline" break end
	if o.total and spentAll >= o.total then stopWhy = "--total-seconds" break end
	local best
	for _, wk in ipairs(work) do
		if not wk.out and not (budget and wk.spent >= budget) then
			if not best or wk.spent < best.spent then best = wk end
		end
	end
	if not best then break end
	local it = nextItem(best)
	if not it then
		best.out = true
	else
		best.next = best.next + 1
		local p = best.p
		local sitStr = Hunt.sitString(it.sit)
		local seed = Hunt.caseSeed(o.seed, p.id, sitStr)
		psigOf(p)
		if resumeSkip(p, sitStr) then
			resumedN = resumedN + 1
			line("pass", p.id, sitStr, seed, 0, "resumed")
		else
			local res = Hunt.runCase({ promise = p.id, sit = it.sit, seed = seed }, { always = true })
			if Hunt.timeUp then
				best.next = best.next - 1
				rf:write("# stopped " .. p.id .. " " .. sitStr .. ": the run's time was up\n")
				stopWhy = "the deadline"
				break
			end
			best.spent = best.spent + (res.secs or 0)
			spentAll = spentAll + (res.secs or 0)
			record(res)
			if res.status == "fail" then
				rawFail({ promise = p.id, seen = res.seen, detail = res.detail, sit = sitStr, seed = seed, found = RUN .. " (" .. it.kind .. ")", kind = it.kind })
			end
			recordAfter(res, { promise = p.id, sit = it.sit, seed = seed }, RUN .. " (" .. it.kind .. ")")
		end
	end
end
local totalItems, ranP, unfinished = 0, 0, 0
for _, wk in ipairs(work) do
	local dp, dr = 0, 0
	local items = wk.items
	if items then
		totalItems = totalItems + #items
		if wk.next > 1 then ranP = ranP + 1 end
		for i = wk.next, #items do if items[i].kind == "random" then dr = dr + 1 else dp = dp + 1 end end
		if wk.gen then
			unfinished = unfinished + 1
			dropped[#dropped + 1] = ("%s: the rest of its pairwise set (not made; %d of it run)"):format(wk.p.id, wk.next - 1)
		end
	else
		dropped[#dropped + 1] = ("%s: never started (no time was left)"):format(wk.p.id)
	end
	if dp > 0 then dropped[#dropped + 1] = ("%s: %d pairwise situations"):format(wk.p.id, dp) end
	if dr > 0 then dropped[#dropped + 1] = ("%s: %d random situations"):format(wk.p.id, dr) end
end
out(("this shard: %d of %d promises run (%d with their pairwise set unfinished), sets made in %.0f s"):format(ranP, #work, unfinished, genSecs))
out(("set cache: %d pairwise sets read from tests/out/hunt/cache, %d made (%d written)%s"):format(Sit.stats.hits, Sit.stats.made, Sit.stats.written,
	Sit.useCache and "" or " (--no-cache)"))
if o.resume then out(("resume: %d passed checks of %s not run again"):format(resumedN, o.resume)) end
for pid, sg in pairs(psigs) do if sg then rf:write("# psig " .. pid .. " " .. sg .. "\n") end end
if stopWhy then out("stopped by " .. stopWhy) end
finish(totalItems, dropped)
os.exit(#failures > 0 and 1 or 0)
