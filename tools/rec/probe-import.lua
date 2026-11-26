-- tools/rec/probe-import.lua: saved probe data (WuberProbeDB, the developer-only WuberProbe addon) -> fixture tables.
--
--   lua5.1 tools/rec/probe-import.lua [--wtf <WTF folder>] [--file <a WuberProbe.lua SavedVariables file>]
--                                     [--out tests/fixtures/probe] [--source game|sim] [--deny <names file>] [--list]
--   local PI = loadfile("tools/rec/probe-import.lua")("--lib")      -- PI.convert(run, source) -> fixture table
--
-- Same safety as tools/rec/import.lua (it reuses its reader): the input is only read ("rb"), must be plain data, runs in an
-- empty environment with an instruction limit, and a fixture holding a denied name is refused. One fixture per run:
-- <out>/<source>-probe-<id>.lua = "return { ... }". Fixture fields (all plain data):
--   fileIds   [lower-case path with backslashes] = the number GetTexture() gave (only numbers; paths the client answered
--             with a string are in fileIdStrings)
--   fileIdsAre  "number" | "string" | "mixed"   (what GetTexture answers for an addon's own file)
--   atlases   [name] = { file, fileID, width, height, l, r, t, b } or { none = true }
--   widths    [lower-case font file name][size] = { adv = { [byte] = advance }, strings = { [text] = width }, imm, settled, lineH }
--   hit       [scenario id] = { [cell number] = winner role }, hitMixed (cells with more than one winner), hitCoverage
--   keys      the keysAuto answers, keysGuided = the rows of the typed test
--   secrets   secretAccessors = { "<accessor>" = { frames that gave a secret } }, secretApi = { api name = true when secret }
--   blocked   the ADDON_ACTION_BLOCKED / FORBIDDEN rows (event, addon, function, combat)
-- Job 2894: --blocked-out <file> also turns the passive blocked log (run.blocked of WuberProbe, the Lab's L13.blocked list) and the Lab's
--   L13.calls notes into the guard's evidence file (default tests/fixtures/probe/measured-blocked.lua): one row per
--   { fn, kind = "BLOCKED"|"FORBIDDEN", combat, click = true|false|nil (from a click handler or not; nil = not known), build }.
--   The rows are merged with the rows already in the file (nothing is dropped). tests/surface-guard.lua reads it.
--   env       build, project, realm, locale, screen, has (which globals exist), login (UnitName shapes at each loading event)
--   events    [name] = { valid, reg, fired = count in the watch run or nil }
--   timing    frame time and 0.25 s ticker statistics
--   facts     a flat list { id, v } for tests: "build", "realm.name", "project.id", "tex.idsAre", "event.TAXIMAP_OPENED.fired" ...
local IMP = assert(loadfile((debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/"):match("^(.*)/[^/]*$") or ".") .. "/import.lua"))("--lib")
local PI = { IMP = IMP }
local SECRET, NIL = "<secret>", "<nil>"

local function lowerPath(p) return (tostring(p):gsub("/", "\\"):lower()) end
local function baseName(p) return (tostring(p):gsub("\\", "/"):match("([^/]+)$") or tostring(p)):lower() end
local function isNum(v) return type(v) == "number" end

-- a stored marker is a value that is not data: "<nil>" etc.
local function plainv(v) if v == NIL then return nil end return v end

function PI.convert(run, source)
	if type(run) ~= "table" then return nil, "not a run" end
	if type(run.p) ~= "table" then return nil, "no probe data (run.p)" end
	local p = run.p
	local fx = { format = 1, kind = "probe", source = source or "game", id = run.id, build = run.build, v = run.v, why = run.why, ran = run.ran }
	-- file ids
	local tex = p.tex
	if type(tex) == "table" and type(tex.files) == "table" then
		fx.fileIds, fx.fileIdStrings = {}, {}
		local nn, ns = 0, 0
		for path, r in pairs(tex.files) do
			if type(r) == "table" then
				local id = r.fid
				if not isNum(id) then id = r.id end
				if isNum(id) then fx.fileIds[lowerPath(path)] = id nn = nn + 1
				elseif type(r.id) == "string" and r.id ~= SECRET then fx.fileIdStrings[lowerPath(path)] = r.id ns = ns + 1 end
			end
		end
		fx.fileIdsAre = (nn > 0 and ns == 0) and "number" or (ns > 0 and nn == 0) and "string" or "mixed"
		fx.texOther = tex.other
		fx.fromNumber, fx.colorTexture, fx.atlasSet, fx.fontBack = tex.fromNumber, tex.color, tex.atlasSet, tex.fontBack
	end
	if type(p.atlas) == "table" then fx.atlases = p.atlas.atlases end
	-- widths
	local f = p.fontw
	if type(f) == "table" and type(f.fonts) == "table" then
		fx.widths = {}
		for path, sizes in pairs(f.fonts) do
			local key = baseName(path)
			fx.widths[key] = fx.widths[key] or {}
			for size, row in pairs(sizes) do
				if type(row) == "table" then
					local adv = {}
					for code, w in pairs(row.chars or {}) do if isNum(w) then adv[code] = w end end
					fx.widths[key][tonumber(size) or size] = { adv = adv, strings = row.strings, imm = row.imm, settled = row.settled, lineH = row.lineH, ll = row.ll }
				end
			end
		end
	end
	-- hit order: the winner of each cell (the one seen most)
	local hit = p.hit
	if type(hit) == "table" and type(hit.cells) == "table" then
		fx.hit, fx.hitMixed = {}, {}
		for id, cells in pairs(hit.cells) do
			fx.hit[id] = {}
			for cell, who in pairs(cells) do
				local best, bn, kinds = nil, 0, 0
				for name, n in pairs(who) do
					if name ~= "n" and isNum(n) then kinds = kinds + 1 if n > bn then best, bn = name, n end end
				end
				if best then fx.hit[id][cell] = best end
				if kinds > 1 then fx.hitMixed[#fx.hitMixed + 1] = id .. "#" .. cell end
			end
		end
		table.sort(fx.hitMixed)
		fx.hitCoverage = hit.coverage
		fx.hitScenarios = hit.scenarios
	end
	-- keys
	if type(p.keysAuto) == "table" then fx.keys = p.keysAuto end
	if type(p.keys) == "table" then fx.keysGuided = p.keys.rows end
	-- secrets: per accessor, the Blizzard frames that gave a secret
	local sec = p.secrets
	if type(sec) == "table" then
		fx.secretAccessors, fx.secretApi = {}, {}
		for fname, row in pairs(sec.frames or {}) do
			for acc, r in pairs(row) do
				if type(r) == "table" and r.s then
					fx.secretAccessors[acc] = fx.secretAccessors[acc] or {}
					table.insert(fx.secretAccessors[acc], fname)
				end
			end
		end
		for _, l in pairs(fx.secretAccessors) do table.sort(l) end
		for name, r in pairs(sec.api or {}) do if type(r) == "table" and r.s then fx.secretApi[name] = true end end
	end
	fx.blocked = run.blocked
	fx.blockedN = run.blockedN
	if type(p.taint) == "table" then fx.taint = p.taint end
	-- env, events, timing
	if type(p.env) == "table" then
		fx.env = p.env
		fx.login = p.login
	end
	if type(p.events) == "table" and type(p.events.list) == "table" then
		fx.events = {}
		for e, r in pairs(p.events.list) do fx.events[e] = { valid = r.valid, reg = r.reg, err = r.err } end
		local w = p.watch
		if type(w) == "table" and type(w.fired) == "table" then
			for e, r in pairs(fx.events) do if w.asked and w.asked[e] then r.fired = w.fired[e] or 0 end end
			fx.watchSeconds = w.seconds
		end
	end
	if type(p.timing) == "table" then fx.timing = p.timing end
	-- facts: a flat list for the conformance tests
	local facts = {}
	local function fact(id, v) facts[#facts + 1] = { id = id, v = v } end
	if fx.env then
		local e = fx.env
		if type(e.build) == "table" then fact("build", e.build[2]) end
		if type(e.realm) == "table" then fact("realm.name", e.realm.name) end
		if type(e.project) == "table" then fact("project.id", e.project.id) end
	end
	if fx.fileIdsAre then fact("tex.idsAre", fx.fileIdsAre) end
	for e, r in pairs(fx.events or {}) do if r.fired ~= nil then fact("event." .. e .. ".fired", r.fired) end end
	table.sort(facts, function(a, b) return a.id < b.id end)
	fx.facts = facts
	return fx
end

function PI.fileName(fx, source) return (source or fx.source or "game") .. "-probe-" .. tostring(fx.id or "noid"):gsub("[^%w%-]+", "-") .. ".lua" end

function PI.findFiles(wtf)
	wtf = wtf:gsub("\\", "/"):gsub("/+$", "")
	local out = {}
	for _, acct in ipairs(IMP.listDir(wtf .. "/Account")) do
		local path = wtf .. "/Account/" .. acct .. "/SavedVariables/WuberProbe.lua"
		local f = io.open(path, "rb")
		if f then f:close() out[#out + 1] = { path = path, account = acct } end
	end
	return out
end

-- the blocked rows of one run (see the header). rows: run.blocked and run.l13 (the Lab's L13.blocked list), each item
-- { event|kind, func|fn, combat, click }; the build is the run's.
function PI.blockedRows(run, build)
	local rows = {}
	if type(run) ~= "table" then return rows end
	build = tostring(build or run.build or "?")
	local function add(item)
		if type(item) ~= "table" then return end
		local fn = item.fn or item.func
		if type(fn) ~= "string" or fn == "" or fn == NIL or fn == SECRET then return end
		fn = fn:gsub("^%a+:%s*", "") -- "function: ReloadUI"? keep the bare name only
		local kind = item.kind
		if not kind then kind = tostring(item.event or ""):find("FORBIDDEN", 1, true) and "FORBIDDEN" or "BLOCKED" end
		if kind ~= "BLOCKED" and kind ~= "FORBIDDEN" then return end
		local click = item.click
		if click ~= true and click ~= false then click = nil end
		rows[#rows + 1] = { fn = fn, kind = kind, combat = item.combat == true, click = click, build = build }
	end
	for _, list in ipairs({ run.blocked, run.l13 }) do
		if type(list) == "table" then for _, it in ipairs(list) do add(it) end end
	end
	-- the Lab's own call notes that were followed by a blocked event in the same frame
	if type(run.calls) == "table" then
		for _, c in ipairs(run.calls) do
			if type(c) == "table" and c.blocked then add({ fn = c.fn, kind = c.kind, combat = c.combat, click = c.click }) end
		end
	end
	return rows
end

local function rowKey(r) return table.concat({ r.fn, r.kind, tostring(r.combat), tostring(r.click), r.build }, "|") end

-- merge new rows into old ones (the same fn, kind, combat, click, build is one row); sorted so the file is stable
function PI.mergeBlocked(old, new)
	local seen, out = {}, {}
	for _, list in ipairs({ old or {}, new or {} }) do
		for _, r in ipairs(list) do
			local k = rowKey(r)
			if not seen[k] then seen[k] = true out[#out + 1] = r end
		end
	end
	table.sort(out, function(a, b) return rowKey(a) < rowKey(b) end)
	return out
end

function PI.serializeBlocked(rows, note)
	local o = { "-- measured-blocked.lua: made by tools/rec/probe-import.lua --blocked-out from the passive blocked log (WuberProbe run.blocked, the Lab's L13.blocked).",
		"-- One row per function the client refused: kind BLOCKED or FORBIDDEN, in combat or not, from a click handler (click = true), not from one (false) or not known (nil), the build.",
		"-- tests/surface-guard.lua turns a row into evidence = \"measured:<build>\" for that curated name. Do not edit by hand." }
	if note then o[#o + 1] = "-- " .. note end
	o[#o + 1] = "return { format = 1, rows = {"
	for _, r in ipairs(rows) do
		o[#o + 1] = ("\t{ fn = %q, kind = %q, combat = %s, click = %s, build = %q },"):format(r.fn, r.kind, tostring(r.combat), tostring(r.click), r.build)
	end
	o[#o + 1] = "} }"
	return table.concat(o, "\n") .. "\n"
end

-- read an existing measured-blocked file (plain data in an empty environment)
function PI.readBlocked(path)
	local f = io.open(path, "rb")
	if not f then return {} end
	local text = f:read("*a") f:close()
	local fn = loadstring(text, "=measured-blocked")
	if not fn then return {} end
	setfenv(fn, {})
	local ok, t = pcall(fn)
	return ok and type(t) == "table" and type(t.rows) == "table" and t.rows or {}
end

-- one saved file -> fixtures { { name, fx, text, path, refused } }
function PI.importFile(path, opts)
	opts = opts or {}
	local text, err = IMP.read(path)
	if not text then return nil, err end
	local db, why = IMP.loadSaved(text, "WuberProbeDB")
	if not db then return nil, path .. ": " .. why end
	local done = {}
	for i, run in ipairs(type(db.runs) == "table" and db.runs or {}) do
		local fx, e = PI.convert(run, opts.source or "game")
		local item = { index = i }
		if opts.blockedRows then for _, r in ipairs(PI.blockedRows(run, run.build)) do opts.blockedRows[#opts.blockedRows + 1] = r end end
		if not fx then item.refused = e else
			item.fx, item.name = fx, PI.fileName(fx, opts.source)
			local hit = IMP.privacy(fx, opts.deny)
			if hit then item.refused = "a denied name is in it"
			elseif not opts.list then
				item.text = IMP.serialize(fx)
				if opts.out then
					item.path = opts.out .. "/" .. item.name
					local f = assert(io.open(item.path, "wb")) f:write(item.text) f:close()
				end
			end
		end
		done[#done + 1] = item
	end
	return done
end

local function main(argv, say)
	local out = say or print
	local o = { out = "tests/fixtures/probe", source = "game" }
	local i = 1
	while i <= #argv do
		local a = argv[i]
		if a == "--list" then o.list = true
		elseif a == "--wtf" or a == "--file" or a == "--out" or a == "--source" or a == "--deny" or a == "--blocked-out" then o[a:sub(3)] = argv[i + 1] i = i + 1
		else out("unknown argument: " .. tostring(a)) return 2 end
		i = i + 1
	end
	local deny
	if o.deny then local e deny, e = IMP.readDeny(o.deny) if not deny then out(tostring(e)) return 2 end end
	local files = o.file and { { path = o.file } } or PI.findFiles(o.wtf or IMP.DEFAULT_WTF)
	if #files == 0 then out("no WuberProbe.lua found") return 0 end
	local code = 0
	local blockedRows = o["blocked-out"] and {} or nil
	for _, f in ipairs(files) do
		local done, err = PI.importFile(f.path, { blockedRows = blockedRows, out = (o.out:gsub("\\", "/"):gsub("/+$", "")), source = o.source, deny = deny, list = o.list })
		if not done then out(err) code = 1 else
			out(f.path .. ": " .. #done .. " run(s)")
			for _, it in ipairs(done) do
				local fx = it.fx or {}
				local n = function(t) local c = 0 for _ in pairs(t or {}) do c = c + 1 end return c end
				out(("  %s: %d file ids (%s), %d fonts, %d hit scenarios, %d blocked, %d facts%s"):format(it.name or "?", n(fx.fileIds), tostring(fx.fileIdsAre), n(fx.widths), n(fx.hit), fx.blockedN or 0, n(fx.facts),
					it.refused and (" - REFUSED: " .. it.refused) or (it.path and (" - wrote " .. it.path) or "")))
				if it.refused then code = 1 end
			end
		end
	end
	if blockedRows and not o.list then
		local merged = PI.mergeBlocked(PI.readBlocked(o["blocked-out"]), blockedRows)
		local f = assert(io.open(o["blocked-out"], "wb")) f:write(PI.serializeBlocked(merged)) f:close()
		out(("blocked rows: %d new, %d in %s"):format(#blockedRows, #merged, o["blocked-out"]))
	end
	return code
end
PI.main = main

if (...) == "--lib" then return PI end
os.exit(main({ ... }))
