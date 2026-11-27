-- The hunt's shrinking and repro files (part of tests/hunt/lib.lua, loaded by it).
--   Hunt.shrink(case, opts) -> smallest failing case, its result, runs  (nil when the failure does not repeat)
--   Hunt.caseId(case)       -> a stable readable id (promise + non-default dials [+ after / steps] [+ hash])
--   Hunt.writeRepro(case, res, dir, extra) -> path, id   one file, runnable alone: lua5.1 <path>
--   Hunt.repro(spec)        what a repro file calls: 1 while the bug exists, 0 when fixed, 2 when it cannot tell
--   Hunt.writeKnown(reproDir, knownPath)  KNOWN.md: one line per repro file
return function(Hunt)
	local copy, ser, oneLine = Hunt.copy, Hunt.ser, Hunt.oneLine

	local function copySteps(list)
		if not list then return nil end
		local out = {}
		for i, s in ipairs(list) do out[i] = { id = s.id, args = s.args } end
		return out
	end

	local function caseCopy(c)
		return { promise = c.promise, sit = copy(c.sit), seed = c.seed, steps = copySteps(c.steps), after = c.after, match = c.match }
	end
	Hunt.caseCopy = caseCopy

	-- the dials that differ from their defaults: { name = value }
	function Hunt.nonDefault(sit)
		local out = {}
		for _, d in ipairs(Hunt.dialOrder) do
			local v = sit[d.name]
			if v ~= nil and v ~= d.default then out[d.name] = v end
		end
		return out
	end

	-- Shrinks a failing case: first it must fail again (else nil: not repeatable, never a repro); then without
	-- the scenario before it (an always-promise), then each non-default dial back to its default one at a time
	-- (kept when it still fails with the SAME promise; groups of dials first, then one at a time, repeated until
	-- nothing more goes), then walk steps (chunks first, then single steps). opts: maxRuns, deadline (os.clock),
	-- wallDeadline (os.time), verbose. Stopped early (runs or deadline), it hands back the smallest failing case so far.
	-- case.match (a plain line, numbers blanked: Hunt.blank): only a failure with that line counts, so a shrink
	-- never wanders off to another finding of the same promise.
	function Hunt.shrink(case, opts)
		opts = opts or {}
		local maxRuns = opts.maxRuns or 60
		local runs, last = 0, nil
		local function late()
			return (opts.deadline ~= nil and os.clock() > opts.deadline) or (opts.wallDeadline ~= nil and os.time() >= opts.wallDeadline)
		end
		local cur = caseCopy(case)
		local p = Hunt.promises[cur.promise]
		local function valid(c)
			if not (p and Hunt.applies(p, c.sit)) then return false end
			if c.after then
				local q = Hunt.promises[c.after]
				if not (q and Hunt.applies(q, c.sit)) then return false end
			end
			return true
		end
		local memo = {}
		local function try(c)
			local mk = ser({ c.promise, Hunt.sitString(c.sit), c.after or "", c.steps or {} })
			if memo[mk] ~= nil and mk ~= memo.first then return memo[mk] end
			if runs >= maxRuns then return false end
			if runs > 0 and late() then return false end
			runs = runs + 1
			memo.first = memo.first or mk
			local r = Hunt.runCase(c)
			if opts.verbose then print(("    shrink %d: %s %s%s -> %s"):format(runs, c.promise, Hunt.sitString(c.sit),
				c.steps and (" (" .. #c.steps .. " steps)") or "", r.status)) end
			local hit = r.status == "fail" and (not c.match or Hunt.blank(r.seen) == c.match)
			memo[mk] = hit
			if hit then
				last = r
				return true
			end
			return false
		end
		if not try(cur) then return nil, nil, runs end
		local function cut(c)
			if c.steps and last.failStep and last.failStep < #c.steps then
				local s = {}
				for i = 1, last.failStep do s[i] = c.steps[i] end
				c.steps = s
			end
		end
		cut(cur)
		if cur.after then
			local c2 = caseCopy(cur)
			c2.after = nil
			if valid(c2) and try(c2) then cur = c2 cut(cur) end
		end
		-- walk steps: chunks first (halves, quarters ...), then single steps
		local function stepPass()
			if not (cur.steps and #cur.steps > 0) then return end
			local size = math.floor(#cur.steps / 2)
			if size < 1 then size = 1 end
			while size >= 1 and runs < maxRuns and not late() do
				local i, removed = 1, false
				while i <= #cur.steps and runs < maxRuns and not late() do
					local c2 = caseCopy(cur)
					local s = {}
					for k, st in ipairs(cur.steps) do if k < i or k >= i + size then s[#s + 1] = st end end
					c2.steps = s
					if try(c2) then cur, removed = c2, true cut(cur) else i = i + size end
				end
				if not removed then size = math.floor(size / 2) end
			end
		end
		-- a long session's steps go first when there are many (every later run replays fewer of them)
		local stepsFirst = cur.steps and #cur.steps > 8
		if stepsFirst then stepPass() end
		-- dials back to their defaults: all at once, then halves, quarters ... then one at a time, until nothing
		-- more can go (a group can reset dials that only go together, e.g. a saved character and its role)
		local function nonDefaultNames()
			local list = {}
			for _, d in ipairs(Hunt.dialOrder) do if cur.sit[d.name] ~= d.default then list[#list + 1] = d.name end end
			return list
		end
		local size = #nonDefaultNames()
		while size >= 1 and runs < maxRuns and not late() do
			local list, i, removed = nonDefaultNames(), 1, false
			if size > #list then size = #list end
			while i <= #list and runs < maxRuns and not late() do
				local c2 = caseCopy(cur)
				for k = i, math.min(i + size - 1, #list) do c2.sit[list[k]] = Hunt.dials[list[k]].default end
				if valid(c2) and try(c2) then
					cur, removed = c2, true
					cut(cur)
					list = nonDefaultNames()
				else
					i = i + size
				end
			end
			if not removed then
				if size == 1 then break end
				size = math.floor(size / 2)
			end
		end
		-- (again after the dials: a step only a dial needed can go now; tries made before are remembered, not re-run)
		stepPass()
		return cur, last, runs
	end

	local function short(s, n)
		local t = tostring(s):gsub("[^%w_%.%-]", "_"):sub(1, n or 14)
		return (t:gsub("[%._%-]+$", ""))
	end

	function Hunt.caseId(case)
		local parts = { case.promise }
		local nd = Hunt.nonDefault(case.sit)
		for _, k in ipairs(Hunt.sortedKeys(nd)) do parts[#parts + 1] = short(k, 10) .. "-" .. short(nd[k], 12) end
		if case.after then parts[#parts + 1] = "after-" .. short(case.after, 24) end
		if case.steps then parts[#parts + 1] = #case.steps .. "steps" end
		local id = table.concat(parts, "--")
		if #id > 90 or case.steps then
			local h = { case.promise, Hunt.sitString(case.sit), case.after or "", case.steps or {} }
			if case.steps and case.match then h[5] = case.match end
			id = id:sub(1, 80) .. "-" .. Hunt.hex(ser(h))
		end
		return id
	end

	local function knownLine(id, case, seen)
		return ("%s | %s | %s%s%s | %s"):format(id, case.promise, Hunt.sitString(case.sit),
			case.after and (" (after " .. case.after .. ")") or "", case.steps and (" (" .. #case.steps .. " steps, seed " .. case.seed .. ")") or "",
			oneLine(seen, 240))
	end

	-- writes the repro file (the same failure gives the same file); extra: { found = "...", addon = dir, id = id }
	-- (extra.id: the sweep's join gives one when two findings would share Hunt.caseId)
	function Hunt.writeRepro(case, res, dir, extra)
		extra = extra or {}
		Hunt.mkdir(dir)
		local id = extra.id or Hunt.caseId(case)
		local path = dir .. "/" .. id .. ".lua"
		local p = Hunt.promises[case.promise]
		local spec = {
			id = id, promise = case.promise, text = p and p.text, situation = Hunt.nonDefault(case.sit), seed = case.seed,
			steps = case.steps, after = case.after, seen = res and res.seen or "?", addon = extra.addon, found = extra.found,
			match = case.steps and case.match or nil,
		}
		local rel = path:gsub("^" .. Hunt.ROOT:gsub("%p", "%%%0") .. "/", "")
		local lines = {
			"-- A failure the bug hunt found (generated by tools/hunt/sweep.lua; NOT part of the normal suite).",
			"-- KNOWN: " .. knownLine(id, case, spec.seen),
			"-- Promise: " .. tostring(spec.text),
			"-- Run alone from the repo root: lua5.1 " .. rel .. "  [--verbose] [--addon <Wuber folder>]",
			"-- Exit 1 and the plain line while the bug exists, 0 when it is fixed, 2 when it cannot tell (the hunt itself changed).",
			"local here = ((arg and arg[0]) or \"\"):gsub(\"\\\\\", \"/\"):match(\"^(.*)/[^/]*$\") or \".\"",
			"local lib = here .. \"/../lib.lua\"",
			"local f = io.open(lib, \"rb\")",
			"if f then f:close() else lib = \"tests/hunt/lib.lua\" end",
			"local Hunt = dofile(lib)",
			"os.exit(Hunt.repro(" .. ser(spec) .. "))",
			"",
		}
		local text = table.concat(lines, "\n")
		local old = Hunt.readFile(path)
		if old ~= text then Hunt.writeFile(path, text) end
		return path, id, old == nil
	end

	local function flagArgs()
		local o = {}
		local argv = arg or {}
		local i = 1
		while argv[i] do
			local a = argv[i]
			if a == "--addon" then o.addon = argv[i + 1] i = i + 1
			elseif a == "--verbose" then o.verbose = true end
			i = i + 1
		end
		return o
	end

	function Hunt.repro(spec)
		local o = flagArgs()
		local ok, err = pcall(Hunt.init, { addon = o.addon or spec.addon })
		if not ok then print("CANNOT TELL: the hunt did not load: " .. tostring(err)) return 2 end
		if not Hunt.promises[spec.promise] then print("CANNOT TELL: there is no promise " .. tostring(spec.promise) .. " now") return 2 end
		local okf, full = pcall(Hunt.full, spec.situation or {})
		if not okf then print("CANNOT TELL: the situation no longer exists: " .. tostring(full)) return 2 end
		if o.verbose then print("Wuber: " .. Hunt.addonInfo()) end
		local r = Hunt.runCase({ promise = spec.promise, sit = full, seed = spec.seed, steps = spec.steps, after = spec.after, match = spec.match },
			{ verbose = o.verbose })
		local where = Hunt.sitString(full) .. (spec.after and (", after " .. spec.after) or "")
			.. (spec.steps and (", " .. #spec.steps .. " steps") or "") .. ", seed " .. tostring(spec.seed)
		if o.verbose then
			for _, e in ipairs(r.log or {}) do print("  " .. Hunt.logLine(e)) end
			if r.detail then print("  detail: " .. tostring(r.detail)) end
			if r.texts then print("  on screen: " .. oneLine(table.concat(r.texts, " | "), 1200)) end
		end
		if r.status == "fail" then
			print("FAIL " .. spec.promise .. ": " .. tostring(r.seen))
			print("  (" .. where .. ")")
			return 1
		elseif r.status == "pass" then
			print("PASS " .. spec.promise .. " (fixed): it used to be: " .. tostring(spec.seen))
			return 0
		end
		print("CANNOT TELL (" .. r.status .. ") " .. spec.promise .. ": " .. oneLine(r.detail, 600))
		return 2
	end

	-- the HUNT ids that the shared bug list cites for each repro file: { ["<repro id>"] = "HUNT-26" or "HUNT-01, HUNT-02" }.
	-- Read from the list at call time (env WUBER_BUGS_NEXT overrides the path); {} when the list is not there.
	function Hunt.huntIds(path)
		path = path or (os.getenv and os.getenv("WUBER_BUGS_NEXT")) or "BUGS-NEXT.md"
		local t = Hunt.readFile(path)
		local ids = {}
		if not t then return ids, false end
		for line in t:gmatch("[^\n]+") do
			local h = line:match("^(HUNT%-%d+) ")
			if h then
				for name in line:gmatch("repro[\\/]([^%s%]\\/|]+)%.lua") do
					local seen = ids[name]
					if not seen then ids[name] = h
					elseif not (", " .. seen .. ","):find(", " .. h .. ",", 1, true) then ids[name] = seen .. ", " .. h end
				end
			end
		end
		return ids, true
	end

	-- the spec table inside a repro file (its last line: os.exit(Hunt.repro({ ... })))
	local function readSpec(text)
		local body = text:match("os%.exit%(Hunt%.repro%((.-)%)%)%s*$")
		if not body then return nil end
		local chunk = loadstring("return " .. body)
		if not chunk then return nil end
		local ok, spec = pcall(chunk)
		return ok and type(spec) == "table" and spec or nil
	end

	-- A looser line for the universal.* promises, whose plain line differs between situations without being another bug
	-- (another driver name, "1060 h ago" against "16 min ago", another screen in front of the line). nil for other promises.
	-- universal.layout*: the kind of problem and the file:line of the first region only (a price-and-place text such as
	-- "50s to Ratchet" / "50s to Stormwind" is the same bug). Other universal.*: the leading "On the <screen> screen" part
	-- is dropped, units of time and numbers are blanked, quoted player or driver names become <name>.
	function Hunt.looseLine(pid, seen)
		pid = tostring(pid)
		if pid:sub(1, 10) ~= "universal." then return nil end
		local s = oneLine(seen, 600)
		if pid:sub(1, 16) == "universal.layout" then
			local kind = s:match("^A layout problem %((.-)%)") or (s:find("is cut off", 1, true) and "cut off") or "?"
			local region = s:match("([%w_]+%.lua:%d+)") or s:match("^A layout problem %(.-%): (%S+)") or "?"
			return "layout\1" .. kind .. "\1" .. (region:gsub("%.$", ""))
		end
		s = s:gsub("^On the .-screen ", "")
		s = s:gsub("%d+%s*h ago", "# ago"):gsub("%d+%s*min ago", "# ago"):gsub("%d+%s*s ago", "# ago")
		s = s:gsub('"%u%l+%s?%u?%l*"', "<name>")
		return (s:gsub("%d+", "#"))
	end

	-- the findings already known: { [Hunt.findingKey(promise, seen)] = { id = repro id, hunt = "HUNT-nn" or nil, file = path } }
	-- from the repro files in a folder (each holds its promise and the line the player saw). The same table also holds, under
	-- keys that start with "\2" (one per promise: any repro of the promise, only used to LINK a finding of another line to
	-- it, never to call it known) and "\3" (the loose line of a universal.* promise); Hunt.knownFind reads all three.
	-- skip(path) true: that file is left out (a repro file this run wrote itself).
	function Hunt.knownMap(dir, bugsPath, skip)
		local ids = Hunt.huntIds(bugsPath)
		local map = {}
		for _, path in ipairs(Hunt.listLua(dir)) do
			local spec = not (skip and skip(path)) and readSpec(Hunt.readFile(path) or "")
			if spec and spec.promise and spec.seen then
				local key = Hunt.findingKey(spec.promise, spec.seen)
				local id = spec.id or path:match("([^/\\]*)%.lua$")
				local ent = { id = id, hunt = ids[id], file = path }
				if not map[key] then map[key] = ent end
				local loose = Hunt.looseLine(spec.promise, spec.seen)
				if loose then
					if not map["\3" .. loose] then map["\3" .. loose] = ent end
				elseif not map["\2" .. spec.promise] then
					map["\2" .. spec.promise] = ent
				end
			end
		end
		return map
	end

	-- one row per promise whose failure another job already lists (tests/hunt/known-elsewhere.tsv: promise id, the other
	-- job's id, one-line why, and optionally a fourth column: the plain line the row covers; # lines and blank lines are
	-- skipped) -> { [promise] = { id = "AUD-17", why = "...", line = "..." or nil } }
	function Hunt.knownElsewhere(path)
		local map = {}
		local t = Hunt.readFile(path or (Hunt.ROOT .. "/tests/hunt/known-elsewhere.tsv"))
		if not t then return map end
		for line in t:gmatch("[^\r\n]+") do
			if line:sub(1, 1) ~= "#" then
				local pid, other, why, seen = line:match("^([^\t]+)\t([^\t]+)\t?([^\t]*)\t?(.*)$")
				if pid and not map[pid] then map[pid] = { id = other, why = why, line = seen ~= "" and seen or nil } end
			end
		end
		return map
	end

	-- is this finding known? -> entry, how  ("same line" | "loose line" | "elsewhere"); or nil, nil, and the repro entry of
	-- the same promise when only the promise matches (another line is NEW, the entry is there to link it)
	-- order: the same promise and line; for universal.* the loose line; then known-elsewhere.tsv (a row with a line covers
	-- only that line; a row without one covers the whole promise and the entry says so: whole = true).
	function Hunt.knownFind(map, promise, seen, elsewhere)
		local e = map[Hunt.findingKey(promise, seen)]
		if e then return e, "same line" end
		local loose = Hunt.looseLine(promise, seen)
		if loose then
			e = map["\3" .. loose]
			if e then return e, "loose line" end
		end
		local x = elsewhere and elsewhere[promise]
		if x and (not x.line or Hunt.blank(x.line) == Hunt.blank(seen)) then
			return { id = x.id, hunt = x.id, file = "known-elsewhere.tsv", elsewhere = x.why, whole = not x.line or nil }, "elsewhere"
		end
		return nil, nil, map["\2" .. tostring(promise)]
	end

	-- re-runs a repro file with the code as it is now and, when it still fails and the line the player sees was reworded,
	-- rewrites only its "seen" (the spec and the -- KNOWN: line). -> "same" | "rewritten" | "pass" | "other" (and the new line)
	function Hunt.refreshSeen(path)
		local text = Hunt.readFile(path) or ""
		local spec = readSpec(text)
		if not spec or not Hunt.promises[spec.promise] then return "other" end
		local okf, full = pcall(Hunt.full, spec.situation or {})
		if not okf then return "other" end
		local r = Hunt.runCase({ promise = spec.promise, sit = full, seed = spec.seed, steps = spec.steps, after = spec.after, match = spec.match }, {})
		if r.status == "pass" then return "pass" end
		if r.status ~= "fail" then return "other" end
		if r.seen == spec.seen then return "same", r.seen end
		local oldSeen = spec.seen
		spec.seen = r.seen
		local head = text:match("^(.-)os%.exit%(Hunt%.repro%(")
		if not head then return "other" end
		local old1 = oneLine(oldSeen, 240)
		local new1 = oneLine(r.seen, 240)
		local kl = head:match("\n%-%- KNOWN: ([^\n]*)")
		local i = kl and kl:find(old1, 1, true)
		if i then
			local p1, p2 = head:find("\n%-%- KNOWN: " .. kl:gsub("%p", "%%%0"))
			if p1 then head = head:sub(1, p1 - 1) .. "\n-- KNOWN: " .. kl:sub(1, i - 1) .. new1 .. kl:sub(i + #old1) .. head:sub(p2 + 1) end
		end
		Hunt.writeFile(path, head .. "os.exit(Hunt.repro(" .. ser(spec) .. "))\n")
		return "rewritten", r.seen
	end

	-- KNOWN.md from the repro files in a folder (their "-- KNOWN:" line), each with the shared list's id (HUNT-nn)
	function Hunt.writeKnown(reproDir, knownPath, counts, bugsPath)
		local ids, haveList = Hunt.huntIds(bugsPath)
		local rows = {}
		for _, path in ipairs(Hunt.listLua(reproDir)) do
			local t = Hunt.readFile(path) or ""
			local line = t:match("\n%-%- KNOWN: ([^\n]*)")
			if line then rows[#rows + 1] = line end
		end
		local out = {
			"# Failures the bug hunt found",
			"",
			"These are NOT part of the normal suite (tests/run.lua never runs them). Each line is one repro file in",
			"repro/ next to this file: 'lua5.1 <that folder>/<id>.lua' from the repo root exits 1 while the bug exists",
			"and 0 once it is fixed. Written by tools/hunt/sweep.lua (--known-md); a fixed bug's file stays until someone removes it.",
			"The 'list' column is the id on the shared bug list (BUGS-NEXT.md, read when this file was made).",
			"A sweep counts a finding with the same promise and line as one of these as KNOWN: it is not shrunk again.",
			"",
			"id | promise | situation | what the player sees | list" .. (counts and " | found" or ""),
			"---|---|---|---|---" .. (counts and "|---" or ""),
		}
		for _, r in ipairs(rows) do
			local id = r:match("^(%S+)")
			out[#out + 1] = r .. " | " .. (ids[id] or (haveList and "not on the list yet" or "list not found")) .. (counts and (" | " .. tostring(counts[id] or 0)) or "")
		end
		if #rows == 0 then out[#out + 1] = "(none)" end
		Hunt.writeFile(knownPath, table.concat(out, "\n") .. "\n")
		return #rows
	end
end
