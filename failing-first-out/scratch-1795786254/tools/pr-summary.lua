-- tools/pr-summary.lua: a short markdown block for a PR body (Fable item 7, small form). Lua 5.1.
-- For the Lua files changed between two git refs it lists, from the ADDED lines only:
--   * new API names (names the file did not use at <base>), each with its apisurface flags when tests/surface/apisurface.lua exists
--     (hr = hardware click, sr = secret return, so = secure only, csa = secret accessor, combat, sa = secret arguments);
--     the section says so when the file is absent (it lands with PR #253)
--   * new uses of names in tools/forbidden.lua (Wuber/ and lab/ files; a name in a comment does not count)
--   * new direct test clicks (GetScript("OnClick")(...), :Click(, :click( : see tools/click-ratchet.lua), a line with
--     "-- direct-click: <reason>" is not one
-- Usage: lua5.1 tools/pr-summary.lua <base> <head> [--diff <file>] [--root <dir>] [--surface <file>] [--strict] [--gate] [--help]
--          [--tree <dir>] [--guard-log <file>] [--hits <file>] [--ledger-run] [--no-static] [--no-staleness]
--   <base> <head>   git refs; the word ROOT as <base> means the empty tree (a root commit's whole content)
--   --diff <file>   read a recorded "git diff -U0" instead of running git (no base file is read then: every name added is "new")
--   --root <dir>    the repository (default: the current folder)
--   --surface <f>   the apisurface file (default <root>/tests/surface/apisurface.lua)
--   --strict        exit 1 when a forbidden name or a new direct click shows (default: always 0, it informs)
--   --gate          exit 1 when the gate fails (P, measured-blocked, peephole; see FULL FORM)
--   --tree <dir>    with --diff: the files of the head tree live under <dir> (the static pass and the test names read them there)
--   --guard-log <f> a WUBER_SURFACE_LOG file (kind TAB name TAB where per line); repeatable
--   --hits <f>      a WUBER_RULE_LOG hits file (rule TAB test TAB count); repeatable
--   --ledger-run    run the changed tests once (tests/run.lua --names=...) with WUBER_RULE_LOG and read the hits (live mode only)
--   --no-static / --no-staleness   leave that part out
-- FULL FORM (job 2895, Fable item 7): the block also carries, all on CHANGED lines only:
--   * the static pass (tools/surface/static-surface.lua): P and B4 (peephole) gate; B4c, U, G, H, C are information
--   * the guard log (WUBER_SURFACE=1 quick-check writes WUBER_SURFACE_LOG; give it with --guard-log, repeatable): kind P gates, K counts as a peephole, others inform
--   * the evidence ledger (tests/fixtures/client/rules.lua): the rules the changed tests lean on (--hits <file> from WUBER_RULE_LOG, or --ledger-run to run
--     just those tests once) and the rules whose "names" a changed addon line uses (GetTexture -> tex.file-id), each with its evidence level
--   * the client-facts staleness line (tools/evidence-report.lua --check-build)
--   GATE: only P, a measured-blocked name (tools/forbidden.lua: the real client blocked it) and a peephole hit (B4, guard K) fail it.
--   Everything else is information. --gate exits 1 on a failed gate. The block always says: not checked: taint propagation.
-- Not checked, said in every block: taint propagation, a secret passed on through a helper, anything not on an added Lua line.
-- As a library: local P = dofile("tools/pr-summary.lua"); P.summarize(diffText, opts) -> markdown, findings.
local here = (debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/"):match("^(.*)/[^/]*$")) or "tools"
local R = dofile(here .. "/click-ratchet.lua")
local P = {}
local EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"

-- the added lines of a "git diff -U0" text: { { path = , lines = { { n = , text = } } } }
function P.parse(diff)
	local files, cur, ln = {}, nil, nil
	for line in (diff .. "\n"):gmatch("(.-)\r?\n") do
		local p = line:match("^%+%+%+ b/(.+)$")
		if p then cur = { path = p, lines = {} } files[#files + 1] = cur ln = nil
		elseif line:match("^%+%+%+ /dev/null") then cur = nil
		else
			local s = line:match("^@@ %-%d+,?%d* %+(%d+)")
			if s then ln = tonumber(s)
			elseif cur and ln and line:sub(1, 1) == "+" then
				cur.lines[#cur.lines + 1] = { n = ln, text = line:sub(2) } ln = ln + 1
			end
		end
	end
	return files
end

local function words(code)
	-- the call names on a code line: { { name =, kind = "global"|"ns"|"method" } }
	local out = {}
	for ns, fn in code:gmatch("(C_[%w_]+)%.([%w_]+)") do out[#out + 1] = { name = ns .. "." .. fn, kind = "ns", ns = ns, fn = fn } end
	for s, name in code:gmatch("():([%a_][%w_]*)%s*%(") do out[#out + 1] = { name = name, kind = "method" } end
	for s, name in code:gmatch("()([%a_][%w_]*)%s*%(") do
		local before = s > 1 and code:sub(s - 1, s - 1) or ""
		if before ~= "." and before ~= ":" and name:match("^%u") then out[#out + 1] = { name = name, kind = "global" } end
	end
	return out
end

local function gitShow(root, ref, path)
	if ref == "ROOT" or ref == EMPTY_TREE then return nil end
	local p = io.popen('cd "' .. root .. '" && git show "' .. ref .. ":" .. path .. '" 2>&1')
	if not p then return nil end
	local s = p:read("*a") p:close()
	if s:match("^fatal:") or s:match("^error:") then return nil end
	return s
end

local function flagsOf(surface, w)
	local e
	if w.kind == "global" then e = surface.globals and surface.globals[w.name]
	elseif w.kind == "ns" then e = surface.ns and surface.ns[w.ns] and surface.ns[w.ns][w.fn]
	else e = surface.methods and surface.methods[w.name] end
	if e == nil then return nil end
	local f = {}
	for k, v in pairs(e) do if v == true then f[#f + 1] = k end end
	table.sort(f)
	return #f > 0 and table.concat(f, ",") or "none"
end

-- the forbidden entries as matchers: { name =, kind =, why =, find = function(code) -> bool }
local function matchers(list)
	local out = {}
	for _, e in ipairs(list or {}) do
		local leaf = e.name:match("([%w_]+)$")
		local m
		if e.kind == "event" then m = function(c) return c:find('["\']' .. e.name .. '["\']') ~= nil end
		elseif e.kind == "method" then m = function(c) return c:find(":" .. e.name .. "%f[^%w_]") ~= nil end
		else
			local esc = e.name:gsub("%.", "%%.")
			m = function(c)
				if c:find("%f[%w_]" .. esc .. "%f[^%w_]") then return true end
				if e.name:find(".", 1, true) then return c:find("[%.:]" .. leaf .. "%f[^%w_]") ~= nil end
				return c:find("%f[%w_]" .. leaf .. "%f[^%w_]") ~= nil
			end
		end
		out[#out + 1] = { name = e.name, kind = e.kind, why = e.why, find = m }
	end
	return out
end


---------------------------------------------------------------------------------------------------------------------------------
-- the full form: changed-line passes (job 2895)
---------------------------------------------------------------------------------------------------------------------------------
local function readAll(p)
	local fh = io.open(p, "rb")
	if not fh then return nil end
	local s = fh:read("*a") fh:close()
	return s
end

-- { [path] = { [line] = true } } for the added lines of a parsed diff
function P.changedIndex(files)
	local idx = {}
	for _, f in ipairs(files) do
		local s = idx[f.path] or {}
		for _, l in ipairs(f.lines) do s[l.n] = true end
		idx[f.path] = s
	end
	return idx
end

-- a: the path a tool printed (static pass: exact; guard log: may be longer, an in-game path ending in the repository path); b: the changed path
local function samePath(a, b)
	a, b = a:gsub("\\", "/"), b:gsub("\\", "/")
	return a == b or a:sub(-#b - 1) == "/" .. b
end

local function fileText(opts, path)
	if opts.sources then return opts.sources(path) end
	return readAll(opts.root .. "/" .. path)
end

-- the static pass (tools/surface/static-surface.lua) judged on the files it can read; only findings on changed lines are kept.
-- Returns { gate = {..}, info = {..}, allowed = n, why = "" } (why is set when the pass could not run)
function P.static(opts, changed)
	local out = { gate = {}, info = {}, allowed = 0 }
	if opts.noStatic then out.why = "left out (--no-static)" return out end
	local chunk = loadfile(here .. "/surface/static-surface.lua")
	if not chunk then out.why = "tools/surface/static-surface.lua not found" return out end
	local SS = chunk()
	if type(SS) ~= "table" or not SS.scanSources then out.why = "tools/surface/static-surface.lua is not loadable as a library" return out end
	if not opts.surface then out.why = "tests/surface/apisurface.lua not available" return out end
	local found
	if opts.sources then
		-- fixture mode: only the changed addon files are read (cross-file definitions are not known: U is noisy here, so U is not listed)
		local list = {}
		for path in pairs(changed) do
			if path:find("^Wuber/") or path:find("^lab/") then
				local t = opts.sources(path)
				if t then list[#list + 1] = { name = path, text = t } end
			end
		end
		table.sort(list, function(a, b) return a.name < b.name end)
		found = SS.scanSources(list, { S = opts.surface, allow = opts.staticAllow or {} })
		out.partial = true
	else
		local ok, res = pcall(SS.run, { root = opts.root, S = opts.surface })
		if not ok or not res then out.why = "the pass failed: " .. tostring(res):sub(1, 120) return out end
		found = res
	end
	for _, f in ipairs(found) do
		local ch
		for path, lines in pairs(changed) do if lines[f.line] and samePath(f.file, path) then ch = path break end end
		if ch and not (out.partial and f.kind == "U") then
			if f.allowed then out.allowed = out.allowed + 1
			elseif f.gate then out.gate[#out.gate + 1] = f
			elseif f.kind == "B4c" or f.kind == "U" or f.kind == "G" or f.kind == "H" or f.kind == "C" then out.info[#out.info + 1] = f end
		end
	end
	return out
end

-- the guard log (kind TAB name TAB where) filtered to the changed lines: { { kind, name, path, n } }
function P.guard(texts, changed)
	local out = {}
	local seen = {}
	for _, text in ipairs(texts or {}) do
		for line in (text .. "\n"):gmatch("(.-)\r?\n") do
			local kind, name, at = line:match("^([^\t]+)\t([^\t]*)\t(.*)$")
			if kind then
				local p, n = at:match("([^%s%c\"':]+%.lua):(%d+)")
				if p then
					n = tonumber(n)
					for path, lines in pairs(changed) do
						if lines[n] and samePath(p, path) then
							local key = kind .. name .. path .. n
							if not seen[key] then seen[key] = true out[#out + 1] = { kind = kind, name = name, path = path, n = n } end
							break
						end
					end
				end
			end
		end
	end
	return out
end

-- the test names whose block holds a changed line of a changed test file: { name = true }, plus the list in order
function P.changedTests(files, opts)
	local names, list = {}, {}
	for _, f in ipairs(files) do
		if f.path:find("^tests/") and not f.path:find("^tests/out/") then
			local text = fileText(opts, f.path)
			if text then
				local starts, ln = {}, 0
				for line in (text .. "\n"):gmatch("(.-)\r?\n") do
					ln = ln + 1
					local nm = line:match("^%s*test%(%s*\"([^\"]+)\"") or line:match("^%s*test%(%s*'([^']+)'")
					if nm then starts[#starts + 1] = { n = ln, name = nm } end
				end
				for _, l in ipairs(f.lines) do
					local best
					for _, s in ipairs(starts) do if s.n <= l.n then best = s else break end end
					if best and not names[best.name] then names[best.name] = true list[#list + 1] = best.name end
				end
			end
		end
	end
	return names, list
end

-- the ledger part. Inputs: opts.rules (the rules table), opts.hits (E.readHits result or nil), opts.levels (id -> evidence level)
-- Returns { rows = { { id, level, bug, what, why } }, ran = bool, note = "" }
function P.ledger(files, changed, opts)
	local out = { rows = {}, ran = opts.hits ~= nil, note = "" }
	local rules = opts.rules
	if not rules then out.note = "tests/fixtures/client/rules.lua not available" return out end
	local byId = {}
	for _, r in ipairs(rules) do byId[r.id] = r end
	local added = {}
	local function add(id, why)
		local r = byId[id]
		if not r then return end
		local key = id
		local row = added[key]
		if not row then
			row = { id = id, level = (opts.levels and opts.levels[id]) or r.evidence, bug = r.bug, what = r.what, differs = r.differs, why = {} }
			added[key] = row
			out.rows[#out.rows + 1] = row
		end
		if #row.why < 4 then row.why[#row.why + 1] = why end
	end
	-- (a) a changed addon line that names something a rule is about (rule field "names")
	for _, f in ipairs(files) do
		if f.path:find("^Wuber/") or f.path:find("^lab/") then
			for _, l in ipairs(f.lines) do
				local c = R.code(l.text)
				for _, r in ipairs(rules) do
					for _, nm in ipairs(r.names or {}) do
						if c:find("[:%.]" .. nm .. "%f[^%w_]") or c:find("^%s*" .. nm .. "%f[^%w_]") then add(r.id, f.path .. ":" .. l.n .. " uses " .. nm) end
					end
				end
			end
		end
	end
	-- (b) the rules the changed tests lean on
	if opts.hits then
		local names = P.changedTests(files, opts)
		local ids = {}
		for id in pairs(opts.hits) do ids[#ids + 1] = id end
		table.sort(ids)
		for _, id in ipairs(ids) do
			local n, shown = 0, {}
			for t in pairs(opts.hits[id]) do
				if names[t] then n = n + 1 if #shown < 2 then shown[#shown + 1] = '"' .. t:sub(1, 60) .. '"' end end
			end
			if n > 0 then table.sort(shown) add(id, n .. " changed test" .. (n > 1 and "s" or "") .. " lean on it (" .. table.concat(shown, ", ") .. (n > #shown and ", ..." or "") .. ")") end
		end
	else
		out.note = "the changed tests were not run for the ledger (--hits <file> or --ledger-run): only rules named by changed addon lines are listed"
	end
	local order = {}
	for i, l in ipairs({ "guess", "borrowed", "docs", "one-real-case", "measured, old", "measured" }) do order[l] = i end
	table.sort(out.rows, function(a, b)
		if (order[a.level] or 0) ~= (order[b.level] or 0) then return (order[a.level] or 0) < (order[b.level] or 0) end
		return a.id < b.id
	end)
	return out
end

-- the plain-lua helpers that shell out (live mode only)
local WIN = package.config:sub(1, 1) == "\\"
local function popen(cmd)
	local p = io.popen(cmd, "r")
	if not p then return "" end
	local s = p:read("*a") p:close()
	return s
end
local function luaExe() return (arg and arg[-1]) or "lua5.1" end

-- evidence-report.lua --check-build (+ --hits): returns levels (id -> level) and the staleness line
function P.evidenceReport(root, hitsFiles, wantStale)
	local cmd = '"' .. luaExe() .. '" "' .. root .. '/tools/evidence-report.lua" --tests 0' .. (wantStale and " --check-build" or "")
	for _, h in ipairs(hitsFiles or {}) do cmd = cmd .. ' --hits "' .. h .. '"' end
	local out = popen('cd "' .. root .. '" && ' .. cmd .. " 2>&1")
	local levels, level, stale = {}, nil, nil
	for line in out:gmatch("[^\r\n]+") do
		local lv = line:match("^== (.-) %(%d+%) ==$")
		if lv then level = lv
		elseif level then
			local id = line:match("^  ([%w%._%-]+)%s")
			if id then levels[id] = level end
		end
		if line:match("^STALE") or line:match("^OK:") or line:match("^UNKNOWN") or line:match("^NO GAME FIXTURE") then stale = line end
	end
	return levels, stale
end

function P.gateOf(res)
	local g = { p = 0, peephole = 0, blocked = #res.forbidden }
	for _, f in ipairs(res.static and res.static.gate or {}) do
		if f.kind == "P" then g.p = g.p + 1 else g.peephole = g.peephole + 1 end
	end
	for _, x in ipairs(res.guard or {}) do
		if x.kind == "P" then g.p = g.p + 1 elseif x.kind == "K" then g.peephole = g.peephole + 1 end
	end
	g.fail = g.p + g.peephole + g.blocked > 0
	return g
end

-- opts: root, base (for the base file text), surface (the loaded table or nil), forbidden (the list), noBase
function P.analyse(diff, opts)
	local res = { files = 0, addon = 0, tests = 0, forbidden = {}, clicks = {}, names = {}, unknown = 0 }
	local fm = matchers(opts.forbidden)
	local seen = {}
	local parsed = P.parse(diff)
	res.parsed = parsed
	res.changed = P.changedIndex(parsed)
	for _, f in ipairs(parsed) do
		res.files = res.files + 1
		local isTest = f.path:find("^tests/") ~= nil
		local isAddon = f.path:find("^Wuber/") or f.path:find("^lab/")
		if isTest then res.tests = res.tests + 1 elseif isAddon then res.addon = res.addon + 1 end
		local baseText = (isAddon and not opts.noBase) and gitShow(opts.root, opts.base, f.path) or nil
		local defined = {}
		if isAddon then
			for _, l in ipairs(f.lines) do for n in l.text:gmatch("function%s+([%w_%.:]+)") do defined[n:match("([%w_]+)$")] = true end end
		end
		for _, l in ipairs(f.lines) do
			if isTest then
				if R.count(l.text) > 0 and not f.path:find("^tests/out/") then
					res.clicks[#res.clicks + 1] = { path = f.path, n = l.n, text = l.text:gsub("^%s+", "") }
				end
			elseif isAddon then
				local c = R.code(l.text)
				for _, m in ipairs(fm) do
					if m.find(c) then res.forbidden[#res.forbidden + 1] = { path = f.path, n = l.n, name = m.name, kind = m.kind, why = m.why or "" } end
				end
				for _, w in ipairs(words(c)) do
					local key = f.path .. "\0" .. w.name
					if not seen[key] and not defined[w.name] and not (baseText and baseText:find(w.name, 1, true)) then
						seen[key] = true
						local fl = opts.surface and flagsOf(opts.surface, w)
						if opts.surface and fl == nil then res.unknown = res.unknown + 1
						else res.names[#res.names + 1] = { path = f.path, n = l.n, name = w.name, flags = fl } end
					end
				end
			end
		end
	end
	return res
end

local function md(res, opts)
	local o = {}
	o[#o + 1] = "### Surface summary (tools/pr-summary.lua " .. (opts.label or "") .. ")"
	o[#o + 1] = "Lua files changed: " .. res.files .. " (" .. res.addon .. " addon, " .. res.tests .. " test)."
	local g = res.gate
	o[#o + 1] = "**Gate: " .. (g.fail and "FAIL" or "pass") .. "** (P " .. g.p .. ", measured-blocked names " .. g.blocked .. ", peephole " .. g.peephole
		.. "). Only those three gate; everything else below is information."
	o[#o + 1] = ""
	-- the static pass
	local st = res.static
	if st.why then
		o[#o + 1] = "**Static pass on changed lines:** not run: " .. st.why
	else
		local gating = {}
		o[#o + 1] = "**Static pass on changed lines (tools/surface/static-surface.lua):** " .. (#st.gate == 0 and "no P or B4" or (#st.gate .. " gating"))
			.. (#st.info > 0 and (", " .. #st.info .. " information") or "") .. (st.allowed > 0 and (", " .. st.allowed .. " allowed by tests/surface/allow.lua") or "")
			.. (st.partial and " (changed files only: names defined in other files are not known)" or "")
		for _, x in ipairs(st.gate) do o[#o + 1] = "- " .. x.kind .. " " .. x.file .. ":" .. x.line .. " " .. x.name .. " [" .. (x.ctx or "") .. "]: " .. tostring(x.msg):sub(1, 140) end
		for i, x in ipairs(st.info) do
			if i > 10 then o[#o + 1] = "- ... +" .. (#st.info - 10) .. " more information lines" break end
			o[#o + 1] = "- (info) " .. x.kind .. " " .. x.file .. ":" .. x.line .. " " .. x.name
		end
	end
	o[#o + 1] = ""
	-- the guard log
	if not res.guardRan then
		o[#o + 1] = "**Guard log on changed lines:** no log given (run tools/quick-check.sh with WUBER_SURFACE=1 and pass WUBER_SURFACE_LOG to --guard-log)"
	else
		o[#o + 1] = "**Guard log on changed lines (WUBER_SURFACE=1):** " .. (#res.guard == 0 and "no hit" or (#res.guard .. " hit" .. (#res.guard > 1 and "s" or "")))
		for _, x in ipairs(res.guard) do
			o[#o + 1] = "- " .. x.kind .. " " .. x.path .. ":" .. x.n .. " " .. x.name .. ((x.kind == "P" or x.kind == "K") and " (gates)" or " (information)")
		end
	end
	o[#o + 1] = ""
	o[#o + 1] = "**Measured-blocked names (tools/forbidden.lua), new uses (gate):** " .. (#res.forbidden == 0 and "none" or "")
	for _, x in ipairs(res.forbidden) do
		o[#o + 1] = "- " .. x.path .. ":" .. x.n .. " " .. x.name .. " (" .. x.kind .. "): " .. x.why:sub(1, 110)
	end
	o[#o + 1] = ""
	o[#o + 1] = "**New direct test clicks (skip the hit test; use Client:clickOn or say why with -- direct-click:):** " .. (#res.clicks == 0 and "none" or "")
	for _, x in ipairs(res.clicks) do o[#o + 1] = "- " .. x.path .. ":" .. x.n .. ": " .. x.text:sub(1, 100) end
	o[#o + 1] = ""
	if opts.surface then
		local flagged = {}
		for _, x in ipairs(res.names) do if x.flags and x.flags ~= "none" then flagged[#flagged + 1] = x end end
		o[#o + 1] = "**New API names with flags (apisurface build " .. tostring(opts.surface.meta and opts.surface.meta.build or "?") .. "):** "
			.. (#flagged == 0 and "none flagged" or "") .. " (" .. #res.names .. " documented new names, " .. res.unknown .. " not in the API docs: Wuber's own helpers or a lead for the guard)"
		for _, x in ipairs(flagged) do o[#o + 1] = "- " .. x.path .. ":" .. x.n .. " " .. x.name .. " [" .. x.flags .. "]" end
	else
		o[#o + 1] = "**New API names:** apisurface not available (tests/surface/apisurface.lua lands with PR #253): names only, no flags."
		local list = {}
		for _, x in ipairs(res.names) do list[#list + 1] = x.name .. " (" .. x.path:match("([^/]+)$") .. ":" .. x.n .. ")" end
		if #list > 0 then o[#o + 1] = table.concat(list, ", ", 1, math.min(#list, 40)) .. (#list > 40 and (" ... +" .. (#list - 40)) or "") else o[#o + 1] = "none" end
	end
	o[#o + 1] = ""
	-- the evidence ledger
	local lg = res.ledger
	o[#o + 1] = "**Evidence ledger rules the changed lines lean on:** " .. (#lg.rows == 0 and "none" or (#lg.rows .. " (weakest first)"))
	for _, r in ipairs(lg.rows) do
		o[#o + 1] = "- " .. r.id .. " [" .. r.level .. "]" .. (r.bug and r.bug ~= "-" and (" " .. r.bug) or "") .. ": " .. r.what:sub(1, 90) .. " <- " .. table.concat(r.why, "; ")
		if r.differs then o[#o + 1] = "  DIFFERS: " .. r.differs:sub(1, 120) end
	end
	if lg.note ~= "" then o[#o + 1] = "(" .. lg.note .. ")" end
	o[#o + 1] = ""
	o[#o + 1] = "**Client facts:** " .. (opts.staleness or "not checked (no staleness line given)")
	o[#o + 1] = ""
	o[#o + 1] = "Not checked: taint propagation, a secret value passed on through a helper, code that is not on an added Lua line."
	return table.concat(o, "\n")
end

function P.summarize(diff, opts)
	opts = opts or {}
	opts.root = opts.root or "."
	local res = P.analyse(diff, opts)
	res.static = P.static(opts, res.changed)
	res.guardRan = opts.guardLogs ~= nil and #opts.guardLogs > 0
	res.guard = P.guard(opts.guardLogs, res.changed)
	res.ledger = P.ledger(res.parsed, res.changed, opts)
	res.gate = P.gateOf(res)
	return md(res, opts), res
end

local function main(argv)
	local base, head, diffFile, root, surfaceFile, strict, gate, treeDir, ledgerRun, noStatic, noStale
	local guardFiles, hitFiles = {}, {}
	local pos = {}
	local i = 1
	while i <= #argv do
		local a = argv[i]
		if a == "--help" or a == "-h" then
			io.write([[
tools/pr-summary.lua <base> <head>: a markdown block for a PR body, from the Lua lines added between two git refs:
  new API names (with their apisurface flags when tests/surface/apisurface.lua exists), new uses of the names in
  tools/forbidden.lua (Wuber/ and lab/), new direct test clicks (see tools/click-ratchet.lua), the static pass findings on changed lines,
  the guard log on changed lines, the evidence ledger rules the changed lines lean on and the client-facts staleness line.
  lua5.1 tools/pr-summary.lua <base> <head> [--diff <file>] [--tree <dir>] [--root <dir>] [--surface <file>] [--strict] [--gate]
       [--guard-log <file>] [--hits <file>] [--ledger-run] [--no-static] [--no-staleness]
  <base>=ROOT means the empty tree. --diff reads a recorded "git diff -U0" (--tree: where the head files are). --strict exits 1 on a forbidden name
  or a direct click. --gate exits 1 when P, a measured-blocked name or a peephole hit is on a changed line. Not checked: taint propagation.
]])
			return 0
		elseif a == "--diff" then i = i + 1 diffFile = argv[i]
		elseif a == "--root" then i = i + 1 root = argv[i]
		elseif a == "--surface" then i = i + 1 surfaceFile = argv[i]
		elseif a == "--strict" then strict = true
		elseif a == "--gate" then gate = true
		elseif a == "--tree" then i = i + 1 treeDir = argv[i]
		elseif a == "--guard-log" then i = i + 1 guardFiles[#guardFiles + 1] = argv[i]
		elseif a == "--hits" then i = i + 1 hitFiles[#hitFiles + 1] = argv[i]
		elseif a == "--ledger-run" then ledgerRun = true
		elseif a == "--no-static" then noStatic = true
		elseif a == "--no-staleness" then noStale = true
		else pos[#pos + 1] = a end
		i = i + 1
	end
	root = root or "."
	local diff
	if diffFile then
		local f = assert(io.open(diffFile, "rb")) diff = f:read("*a") f:close()
		base, head = pos[1] or "?", pos[2] or "?"
	else
		base, head = pos[1], pos[2]
		if not base or not head then io.stderr:write("pr-summary: needs <base> <head> (--help)\n") return 2 end
		local b = base == "ROOT" and EMPTY_TREE or base
		local p = io.popen('cd "' .. root .. '" && git diff -U0 --no-color --no-ext-diff "' .. b .. '" "' .. head .. '" -- "*.lua" 2>&1')
		diff = p:read("*a") p:close()
		if diff:match("^fatal:") or diff:match("^error:") then io.stderr:write("pr-summary: " .. diff) return 2 end
	end
	local surface
	local sp = surfaceFile or (root .. "/tests/surface/apisurface.lua")
	local fh = io.open(sp, "rb")
	if fh then fh:close() local ok, s = pcall(dofile, sp) if ok and type(s) == "table" then surface = s end end
	local forbidden
	local ff = loadfile(root .. "/tools/forbidden.lua")
	if ff then local ok, l = pcall(ff) if ok and type(l) == "table" then forbidden = l end end
	local opts = { root = root, base = base, surface = surface, forbidden = forbidden, noBase = diffFile ~= nil, label = base .. " " .. head, noStatic = noStatic }
	if treeDir then opts.sources = function(p) return readAll(treeDir .. "/" .. p) end
	elseif diffFile then opts.sources = function(p) return nil end end
	local ruleFile = root .. "/tests/fixtures/client/rules.lua"
	local okr, rules = pcall(function() local c = loadfile(ruleFile) return c and c() end)
	if okr and type(rules) == "table" then opts.rules = rules end
	-- guard logs
	if #guardFiles > 0 then
		opts.guardLogs = {}
		for _, gf in ipairs(guardFiles) do opts.guardLogs[#opts.guardLogs + 1] = readAll(gf) or "" end
	end
	-- ledger hits: given files, or one run of the changed tests (live mode only)
	local parsed = P.parse(diff)
	if ledgerRun and not diffFile and opts.rules then
		local names, list = P.changedTests(parsed, opts)
		if #list > 0 then
			local tmpn, tmph = os.tmpname(), os.tmpname()
			if WIN then
				local t = os.getenv("TEMP") or "."
				if tmpn:sub(1, 1) == "\\" then tmpn = t .. tmpn end
				if tmph:sub(1, 1) == "\\" then tmph = t .. tmph end
			end
			local nf = assert(io.open(tmpn, "wb")) nf:write(table.concat(list, "\n"), "\n") nf:close()
			local cmd = (WIN and 'set "WUBER_RULE_LOG=' .. tmph .. '"&& ' or ('WUBER_RULE_LOG="' .. tmph .. '" ')) .. '"' .. luaExe() .. '" tests/run.lua --names="' .. tmpn .. '" 2>&1'
			popen('cd "' .. root .. '" && ' .. cmd)
			hitFiles[#hitFiles + 1] = tmph
		end
	end
	if #hitFiles > 0 then
		opts.hits = {}
		for _, hf in ipairs(hitFiles) do
			local fh = io.open(hf, "rb")
			if fh then
				for line in fh:lines() do
					local id, t, n = line:match("^([^\t]+)\t(.*)\t(%d+)\r?$")
					if id then opts.hits[id] = opts.hits[id] or {} opts.hits[id][t] = (opts.hits[id][t] or 0) + tonumber(n) end
				end
				fh:close()
			end
		end
	end
	if not diffFile and not noStale then
		local levels, stale = P.evidenceReport(root, hitFiles, true)
		opts.levels = levels
		opts.staleness = stale
	end
	local text, res = P.summarize(diff, opts)
	print(text)
	if strict and (#res.forbidden > 0 or #res.clicks > 0) then return 1 end
	if gate and res.gate.fail then return 1 end
	return 0
end

if arg and arg[0] and arg[0]:gsub("\\", "/"):match("pr%-summary%.lua$") then os.exit(main(arg)) end
return P
