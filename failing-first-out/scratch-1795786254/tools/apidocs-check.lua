-- tools/apidocs-check.lua: the fake game against Blizzard's own machine-readable API documentation (job 2630, item 05). DRAFT, not run.
--
--   lua5.1 tools/apidocs-check.lua <docs folder> [--root <repo>] [--known tools/apidocs-known.txt] [--samples tools/apidocs-samples.lua]
--                                  [--constants tools/apidocs-constants.txt] [--no-fake] [--all]
--   local M = loadfile("tools/apidocs-check.lua")("--lib")      (the pure functions, for tests/r49/zz_fgp_05_test.lua)
--
-- <docs folder>: Interface/AddOns/Blizzard_APIDocumentationGenerated of a Blizzard UI source checkout (or the checkout's root);
-- without the argument the environment variable WUBER_UISRC names the checkout. The Blizzard files stay OUTSIDE the repo.
-- SAFETY: each documentation file is a Lua table literal wrapped in "local X = { ... }; APIDocumentation:AddDocumentationTable(X);".
-- It is run with loadstring + setfenv in an environment that holds ONLY an APIDocumentation table with a collector (no os, io,
-- _G, require, print) plus two harmless stand-ins, Enum and Constants, and an instruction limit; the tables it hands over are
-- plain data, read, never called. Many files use Enum.X.Y / Constants.X.Y as a value (SecretReturnsForAspect, Value = ...,
-- sometimes added or subtracted): the stand-in is a table whose any index is another such table (a "marker", tostring = its
-- path, e.g. "Enum.Foo.Bar"); arithmetic on markers gives a marker. A marker means "unknown value": the checks never compare it.
--
-- Checks (a finding is "<check>:<name>", the same key as in the allow file tools/apidocs-known.txt: key<TAB>reason):
--   exists     the addon calls a C_ function, or a global the fake defines, that the docs do not have
--   returns    a documented function the fake defines gives a different number of return values for the sample call
--   events     an event the fake fires with another number of arguments than the documented Payload; an event the docs lack;
--              an event the addon registers that the fake does not know (H.KNOWN_EVENTS) or never fires
--   enums      Enum.X in the fake differs from the documented table (missing or extra keys, other numbers)
--   protected  a documented IsProtectedFunction widget method the fake defines but never guards in combat (blocked())
--   mrn        a MayReturnNothing function the fake answers with a value for its empty sample
--   constants  a global constant (tools/apidocs-constants.txt: NAME<TAB>value<TAB>source) the fake sets differently
--   An event the fake pads (tests/harness.lua H.CHAT18_EVENTS, padChat) counts at the padded length (M.scanPadded); a fire that
--   leaves out only trailing slots the docs mark Nilable is not a finding (M.minPayload).
-- A sample in tools/apidocs-samples.lua may carry setup = function(world, client) that runs before the call (UnitCastingInfo and
-- UnitChannelInfo start a cast first, so their 11-value shape is the one compared).
-- Output: the findings that are not in the allow file, allow-file lines that no longer match ("stale"), a last line
--   GAUNTLET apidocs result=<pass|fail|error> findings=N known=K stale=S     and exit code 0 / 1 / 2 (could not run).

local M = {}
local WINDOWS = package.config:sub(1, 1) == "\\"

local function readFile(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local t = f:read("*a")
	f:close()
	return t
end
local function listDir(dir)
	local cmd = WINDOWS and ('dir /b "' .. dir:gsub("/", "\\") .. '" 2>nul') or ('ls -1 "' .. dir .. '" 2>/dev/null')
	local p, out = io.popen(cmd), {}
	if not p then return out end
	for name in p:read("*a"):gmatch("[^\r\n]+") do out[#out + 1] = name end
	p:close()
	table.sort(out)
	return out
end
local function sortedKeys(t)
	local out = {}
	for k in pairs(t) do out[#out + 1] = k end
	table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
	return out
end

---------------------------------------------------------------------------
-- 1. The documentation as data
---------------------------------------------------------------------------

-- a marker: a plain table with no real value; any index gives a child marker, tostring gives the path, arithmetic gives a marker
local MARKS = setmetatable({}, { __mode = "k" })
function M.marker(path)
	local m = {}
	MARKS[m] = path
	local function arith(sym) return function(a, b) return M.marker("(" .. tostring(a) .. sym .. tostring(b) .. ")") end end
	setmetatable(m, {
		__index = function(t, k) local c = M.marker(path .. "." .. tostring(k)) rawset(t, k, c) return c end,
		__tostring = function() return path end,
		__add = arith("+"), __sub = arith("-"), __mul = arith("*"), __div = arith("/"), __mod = arith("%"), __pow = arith("^"),
		__unm = function(a) return M.marker("-" .. tostring(a)) end,
		__concat = function(a, b) return M.marker(tostring(a) .. tostring(b)) end,
		__lt = function() return false end, __le = function() return false end,
	})
	return m
end
function M.isMarker(v) return type(v) == "table" and MARKS[v] ~= nil end

-- the fake's Enum is a proxy whose own table is empty (tests/harness.lua wraps it with an __index function over a local "inner"):
-- pairs() on it finds nothing. Give back the table behind it, or the table itself.
function M.plainTable(t)
	if type(t) ~= "table" or next(t) ~= nil then return t end
	local mt = getmetatable(t)
	local f = type(mt) == "table" and mt.__index
	if type(f) == "function" and debug and debug.getupvalue then
		local i = 1
		while true do
			local name, v = debug.getupvalue(f, i)
			if not name then break end
			if name == "inner" and type(v) == "table" then return v end
			i = i + 1
		end
	end
	return t
end

-- one file's text -> the list of tables it hands to AddDocumentationTable, or nil and why
function M.loadText(text, label)
	local found = {}
	local env = { APIDocumentation = { AddDocumentationTable = function(_, t) found[#found + 1] = t end },
		Enum = M.marker("Enum"), Constants = M.marker("Constants") }
	local chunk, err = loadstring(text, "=" .. tostring(label))
	if not chunk then return nil, err end
	setfenv(chunk, env)
	debug.sethook(function() error("the documentation took too long to build itself", 2) end, "", 20000000)
	local ok, e = pcall(chunk)
	debug.sethook()
	if not ok then return nil, tostring(e) end
	return found
end

-- the tables -> { funcs[fullName], methods[name] (widget methods, all classes merged), events[LiteralName], enums[Name] }
function M.index(tables)
	local m = { funcs = {}, methods = {}, events = {}, enums = {} }
	for _, t in ipairs(tables) do
		for _, f in ipairs(t.Functions or {}) do
			local entry = { name = f.Name, nret = #(f.Returns or {}), mrn = f.MayReturnNothing == true, protected = f.IsProtectedFunction == true,
				first = f.Returns and f.Returns[1] or nil }
			if t.Type == "ScriptObject" then
				local old = m.methods[f.Name]
				if old then old.mrn, old.protected = old.mrn or entry.mrn, old.protected or entry.protected else m.methods[f.Name] = entry end
			else
				m.funcs[(t.Namespace and (t.Namespace .. ".") or "") .. f.Name] = entry
			end
		end
		for _, e in ipairs(t.Events or {}) do
			if e.LiteralName then m.events[e.LiteralName] = { name = e.Name, n = #(e.Payload or {}), payload = e.Payload or {} } end
		end
		for _, e in ipairs(t.Tables or {}) do
			if e.Type == "Enumeration" then
				local fields = {}
				for _, fd in ipairs(e.Fields or {}) do fields[fd.Name] = fd.EnumValue end
				m.enums[e.Name] = { fields = fields, n = type(e.NumValues) == "number" and e.NumValues or #(e.Fields or {}) } -- (a marker NumValues is unknown)
			end
		end
	end
	return m
end

-- the Lua type a documented value has, or nil when the docs say something we do not judge (tables, structs, mixed)
local SCALAR = { number = "number", luaIndex = "number", uiUnit = "number", cstring = "string", string = "string", WOWGUID = "string", bool = "boolean" }
function M.docType(model, t)
	if type(t) ~= "string" then return nil end
	if SCALAR[t] then return SCALAR[t] end
	if model.enums[t] then return "number" end
	return nil
end

function M.loadDir(dir)
	local sub = dir .. "/Interface/AddOns/Blizzard_APIDocumentationGenerated"
	if #listDir(sub) > 0 then dir = sub end
	local tables, errors, files = {}, {}, 0
	for _, name in ipairs(listDir(dir)) do
		if name:match("Documentation%.lua$") then
			files = files + 1
			local text = readFile(dir .. "/" .. name)
			local found, err = M.loadText(text or "", name)
			if found then for _, t in ipairs(found) do tables[#tables + 1] = t end else errors[#errors + 1] = name .. ": " .. tostring(err) end
		end
	end
	return M.index(tables), errors, files
end

---------------------------------------------------------------------------
-- 2. Reading the addon and the fake as text
---------------------------------------------------------------------------

function M.stripComments(text) return (text:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")) end

-- C_ names used (any use: also C_Map.GetMapInfo passed to pcall) and bare names called
function M.scanCalls(text, into)
	into = into or { c = {}, bare = {} }
	text = " " .. M.stripComments(text)
	for ns, name in text:gmatch("(C_[%w_]+)%.([%w_]+)") do into.c[ns .. "." .. name] = true end
	for name in text:gmatch("[^%w_.:]([%a_][%w_]*)%s*%(") do into.bare[name] = true end
	return into
end

function M.scanRegistered(text, into)
	into = into or {}
	for ev in M.stripComments(text):gmatch('Register%w*Event%(%s*"([A-Z][A-Z0-9_]+)"') do
		if ev:sub(-1) ~= "_" then into[ev] = true end -- "CHAT_MSG_" .. kind is a prefix, not an event
	end
	return into
end

-- the arguments after the event name in a fire call: text is the whole file, i the index just after the event's closing quote;
-- returns the list of argument texts and dynamic (true when "..." or unpack/select is inside: the count is then not known)
function M.splitArgs(text, i)
	local depth, dyn, len, args = 0, false, #text, {}
	local start = nil
	while i <= len do
		local c = text:sub(i, i)
		if c == '"' or c == "'" then
			local j = i + 1
			while j <= len do
				local d = text:sub(j, j)
				if d == "\\" then j = j + 1 elseif d == c then break end
				j = j + 1
			end
			i = j
		elseif c == "(" or c == "{" or c == "[" then depth = depth + 1
		elseif c == ")" or c == "}" or c == "]" then
			if depth == 0 then
				if start then args[#args + 1] = text:sub(start, i - 1):match("^%s*(.-)%s*$") end
				return args, dyn
			end
			depth = depth - 1
		elseif c == "," and depth == 0 then
			if start then args[#args + 1] = text:sub(start, i - 1):match("^%s*(.-)%s*$") end
			start = i + 1
		elseif c == "." and text:sub(i, i + 2) == "..." then dyn = true
		elseif c == "u" and text:sub(i, i + 6) == "unpack(" then dyn = true
		elseif c == "s" and text:sub(i, i + 6) == "select(" then dyn = true end
		i = i + 1
	end
	return args, true
end

-- every fire("EVENT", ...) / :fire("EVENT", ...) / fireAll("EVENT", ...) / chatEvent("EVENT", ...): { EVENT = { counts = { [n] = true }, lits = { [n] = { arg texts } }, dynamic = bool } }
function M.scanFires(text, into)
	into = into or {}
	text = M.stripComments(text)
	for _, pat in ipairs({ 'fire%w*%(%s*"([A-Z][A-Z0-9_]+)"', 'chatEvent%(%s*"([A-Z][A-Z0-9_]+)"' }) do -- (chatEvent: tests/harness.lua's chat lines)
		local pos = 1
		while true do
			local _, e, ev = text:find(pat, pos)
			if not e then break end
			if ev:sub(-1) ~= "_" then -- a name ending in "_" is the start of a built name ("CHAT_MSG_" .. kind): not an event, skipped
				local args, dyn = M.splitArgs(text, e + 1)
				local rec = into[ev] or { counts = {}, lits = {} }
				into[ev] = rec
				if dyn then rec.dynamic = true else rec.counts[#args] = true rec.lits[#args] = rec.lits[#args] or args end
			end
			pos = e + 1
		end
	end
	return into
end

-- the chat events the fake pads to the documented length (tests/harness.lua: padChat, Client:fire and chatEvent): { EVENT = n }.
-- Read from the harness text: the names in H.CHAT18_EVENTS = { NAME = true, ... } and the length in padChat's
-- "for i = a.n + 1, <n> do". When either is not found (the fake changed) nothing is padded, so the literal call counts show up.
function M.scanPadded(harnessText)
	local out = {}
	local names = harnessText:match("H%.CHAT18_EVENTS%s*=%s*(%b{})")
	local n = tonumber(harnessText:match("CHAT18_EVENTS%[event%].-for%s+i%s*=%s*a%.n%s*%+%s*1%s*,%s*(%d+)"))
	if names and n then
		for ev in names:gmatch("([A-Z][A-Z0-9_]+)%s*=%s*true") do out[ev] = n end
	end
	return out
end

function M.scanKnownEvents(harnessText)
	local block = harnessText:match("H%.KNOWN_EVENTS = {}(.-)H%.KNOWN_EVENTS%[e%] = true") or ""
	local out = {}
	for ev in block:gmatch('"([A-Z][A-Z0-9_]+)"') do out[ev] = true end
	return out
end

-- helpers that guard by their last argument (setShown(self, on, "Show")): the quoted method names passed to them
function M.scanGuarded(harnessText)
	local guarded, helpers = {}, {}
	for name in harnessText:gmatch("local function (%w+)%([^)]*%)%s*\n%s*if blocked%(self, method%)") do helpers[#helpers + 1] = name end
	for m in harnessText:gmatch('blocked%(%w+,%s*"(%w+)"%)') do guarded[m] = true end
	for _, h in ipairs(helpers) do
		for args in harnessText:gmatch(h .. "(%b())") do
			local last = args:match('"(%w+)"%)$')
			if last then guarded[last] = true end
		end
	end
	return guarded
end
function M.scanDefined(harnessText)
	local defined = {}
	for m in harnessText:gmatch("function%s+[%w_]+:(%w+)%(") do defined[m] = true end
	return defined
end

---------------------------------------------------------------------------
-- 3. The checks. Each appends { key = "<check>:<name>", text = "..." } to out
---------------------------------------------------------------------------

local function add(out, key, text) out[#out + 1] = { key = key, text = text } end

-- the identifiers Blizzard's own Lua uses: a global used there exists in this client even when the docs do not list it
function M.blizzardNames(uisrc)
	local names = {}
	local function walk(dir)
		for _, name in ipairs(listDir(dir)) do
			if name:match("%.lua$") then
				for id in (readFile(dir .. "/" .. name) or ""):gmatch("[%a_][%w_]*") do names[id] = true end
			elseif not name:find(".", 1, true) and name ~= "Blizzard_APIDocumentationGenerated" then walk(dir .. "/" .. name) end
		end
	end
	walk(uisrc .. "/Interface/AddOns")
	return names
end

-- used (optional): M.blizzardNames(...); a global Blizzard's own code uses is not a finding
function M.checkExists(model, calls, fakeGlobals, out, used)
	for _, name in ipairs(sortedKeys(calls.c)) do
		if not model.funcs[name] then add(out, "exists:" .. name, "the addon uses it; the docs have no such function") end
	end
	for _, name in ipairs(sortedKeys(calls.bare)) do
		if fakeGlobals[name] and rawget(_G, name) == nil and not model.funcs[name] and not (used and used[name]) then
			add(out, "exists:" .. name, "a global the addon calls and the fake defines; the docs do not have it")
		end
	end
end

-- call(name, args) -> the number of values and the type of the first, or nil when the fake does not define it
function M.checkReturns(model, samples, call, out)
	for _, name in ipairs(sortedKeys(samples)) do
		local s, f = samples[name], model.funcs[name]
		if f and s.args then
			local n, ft = call(name, s.args, s)
			if n and n ~= f.nret and not (f.mrn and n == 0) then
				add(out, "returns:" .. name, ("docs %d value(s)%s, the fake gives %d"):format(f.nret, f.mrn and " or none" or "", n))
			elseif n and n >= 1 and f.first and f.first.Type and ft and ft ~= "nil" then -- ft nil = the caller did not say the type: nothing to judge
				local want = M.docType(model, f.first.Type)
				if want and want ~= ft then add(out, "returns:" .. name, ("the first value is a %s, docs say %s (a %s)"):format(ft, f.first.Type, want)) end
			end
		end
		if f and f.mrn and s.empty then
			local n = call(name, s.empty, s)
			if n and n >= 1 then add(out, "mrn:" .. name, ("docs: may return nothing; the fake answers %d value(s) for the empty sample"):format(n)) end
		end
	end
end

-- the fewest values a fire may carry: the position of the last slot the docs do not mark Nilable. Lua cannot tell a trailing nil
-- from a missing value, so leaving out only trailing Nilable slots (UNIT_SPELLCAST_*: castBarID) is not a difference.
function M.minPayload(payload)
	local min = 0
	for i, slot in ipairs(payload or {}) do if slot.Nilable ~= true then min = i end end
	return min
end

-- padded (optional): M.scanPadded(harness text): an event the fake pads to a length counts at that length when it fires fewer
function M.checkEvents(model, fires, registered, known, out, padded)
	padded = padded or {}
	for _, ev in ipairs(sortedKeys(fires)) do
		local rec, d = fires[ev], model.events[ev]
		if not d then
			add(out, "events:" .. ev, "the fake fires an event the docs do not have")
		elseif not rec.dynamic then
			local min = M.minPayload(d.payload)
			for _, n0 in ipairs(sortedKeys(rec.counts)) do
				local n = n0
				if padded[ev] and n < padded[ev] then n = padded[ev] end
				if n ~= d.n and not (n < d.n and n >= min) then
					add(out, "events:" .. ev, ("the fake fires %d argument(s), the documented payload has %d"):format(n, d.n))
				end
			end
			for slot, text in ipairs(rec.lits and rec.lits[d.n] or {}) do -- a literal in a slot of another type than the docs' (PARTY_INVITE_REQUEST)
				local lit = (text == "true" or text == "false") and "boolean" or (text:match('^".*"$') or text:match("^'.*'$")) and "string"
					or text:match("^%-?%d+%.?%d*$") and "number" or nil
				local want = d.payload[slot] and M.docType(model, d.payload[slot].Type)
				if lit and want and lit ~= want then
					add(out, "events:" .. ev .. "#" .. slot, ("slot %d (%s): the fake fires %s, a %s; the docs say %s, a %s"):format(slot, d.payload[slot].Name, text, lit, d.payload[slot].Type, want))
				end
			end
		end
	end
	for _, ev in ipairs(sortedKeys(registered)) do
		if not model.events[ev] then add(out, "events:" .. ev, "the addon registers it; the docs do not have it")
		elseif not known[ev] then add(out, "events:" .. ev, "the addon registers it; the fake does not know it (H.KNOWN_EVENTS)")
		elseif not fires[ev] then add(out, "events:" .. ev, "the addon registers it; no fire call for it in the harness or tests/lib") end
	end
end

function M.checkEnums(model, fakeEnum, out)
	for _, name in ipairs(sortedKeys(fakeEnum)) do
		local fe, d = fakeEnum[name], model.enums[name]
		if type(fe) == "table" then
			if not d then add(out, "enums:" .. name, "the fake defines it; the docs have no such Enum")
			else
				local n, missing = 0, {}
				for k, v in pairs(fe) do
					n = n + 1
					if d.fields[k] == nil then add(out, "enums:" .. name .. "." .. tostring(k), "the fake has a key the docs do not")
					elseif not M.isMarker(d.fields[k]) and d.fields[k] ~= v then add(out, "enums:" .. name .. "." .. tostring(k), ("docs %s, the fake %s"):format(tostring(d.fields[k]), tostring(v))) end
				end
				for _, k in ipairs(sortedKeys(d.fields)) do if fe[k] == nil then missing[#missing + 1] = k end end
				if #missing > 0 then
					add(out, "enums:" .. name, ("docs %d values, the fake %d (missing %s%s)"):format(d.n, n, table.concat(missing, ", ", 1, math.min(#missing, 5)), #missing > 5 and ", ..." or ""))
				end
			end
		end
	end
end

function M.checkProtected(model, guarded, defined, out)
	for _, name in ipairs(sortedKeys(model.methods)) do
		if model.methods[name].protected and defined[name] and not guarded[name] then
			add(out, "protected:" .. name, "docs: IsProtectedFunction; the fake defines it and never refuses it in combat")
		end
	end
end

function M.checkConstants(lines, env, out)
	for line in lines:gmatch("[^\r\n]+") do
		local name, value, src = line:match("^([^#\t][^\t]*)\t([^\t]*)\t?(.*)$")
		if name and tostring(env[name]) ~= value then
			add(out, "constants:" .. name, ("real %s (%s), the fake %s"):format(value, src, tostring(env[name])))
		end
	end
end

-- the allow file: key<TAB>reason -> set; the verdict: what is new, what is stale
function M.parseKnown(text)
	local known = {}
	for line in (text or ""):gmatch("[^\r\n]+") do
		local key, why = line:match("^([^#\t][^\t]*)\t(.*)$")
		if key then known[key] = why end
	end
	return known
end
function M.verdict(findings, known)
	local fresh, seen, stale, nKnown = {}, {}, {}, 0
	for _, f in ipairs(findings) do
		seen[f.key] = true
		if known[f.key] then nKnown = nKnown + 1 else fresh[#fresh + 1] = f end
	end
	for _, k in ipairs(sortedKeys(known)) do if not seen[k] then stale[#stale + 1] = k end end
	return { fresh = fresh, known = nKnown, stale = stale }
end

---------------------------------------------------------------------------
-- 4. The command line
---------------------------------------------------------------------------

local function bootFake(root)
	arg = { [0] = root .. "/tests/run.lua" }
	package.path = root .. "/tests/?.lua;" .. package.path
	local H = require("harness")
	local w = H.NewWorld()
	local c = w:addClient("Apidocs", { spot = "Orgrimmar", class = "WARLOCK", addons = {}, allowMissing = true })
	return H, c.env, w, c
end
local function lookup(env, dotted)
	local v = env
	for part in dotted:gmatch("[^.]+") do
		if type(v) ~= "table" then return nil end
		v = v[part]
	end
	return v
end

function M.main(args)
	local opt = { root = ".", known = "tools/apidocs-known.txt", samples = "tools/apidocs-samples.lua", constants = "tools/apidocs-constants.txt" }
	local i = 1
	while args[i] do
		local a = args[i]
		if a == "--no-fake" or a == "--all" then opt[a:sub(3)] = true
		elseif a:match("^%-%-") then opt[a:sub(3)], i = args[i + 1], i + 1
		else opt.docs = a end
		i = i + 1
	end
	opt.docs = opt.docs or os.getenv("WUBER_UISRC")
	local function die(msg) print("apidocs-check: " .. msg) print("GAUNTLET apidocs result=error findings=0 known=0 stale=0") os.exit(2) end
	if not opt.docs then die("give the documentation folder or set WUBER_UISRC") end
	local model, errors, files = M.loadDir(opt.docs)
	if files == 0 then die("no *Documentation.lua in " .. opt.docs) end
	for _, e in ipairs(errors) do print("  not loaded: " .. e) end
	local out, root = {}, opt.root
	local function rel(p) if p:match("^/") or p:match("^%a:") then return p end return root .. "/" .. p end
	-- the addon
	local calls, registered = { c = {}, bare = {} }, {}
	local function walk(dir, fn)
		for _, name in ipairs(listDir(dir)) do
			if name:match("%.lua$") then fn(readFile(dir .. "/" .. name) or "")
			elseif not name:find(".", 1, true) then walk(dir .. "/" .. name, fn) end
		end
	end
	walk(root .. "/Wuber", function(t) M.scanCalls(t, calls) M.scanRegistered(t, registered) end)
	-- the fake, as text
	local fires = {}
	local harness = readFile(root .. "/tests/harness.lua") or ""
	M.scanFires(harness, fires)
	for _, name in ipairs(listDir(root .. "/tests/lib")) do if name:match("%.lua$") then M.scanFires(readFile(root .. "/tests/lib/" .. name) or "", fires) end end
	M.checkEvents(model, fires, registered, M.scanKnownEvents(harness), out, M.scanPadded(harness))
	M.checkProtected(model, M.scanGuarded(harness), M.scanDefined(harness), out)
	if not opt["no-fake"] then
		local okB, H, env, world, client = pcall(bootFake, root)
		if not okB then die("could not start the fake game: " .. tostring(H)) end
		-- env is an EMPTY proxy (its names sit behind __index), so pairs(env) finds nothing: ask by name instead
		local globals = setmetatable({}, { __index = function(_, k) return type(env[k]) == "function" end })
		local ui = opt.docs:gsub("\\", "/"):match("^(.-)/Interface/AddOns") or (#listDir(opt.docs .. "/Interface") > 0 and opt.docs) or nil
		M.checkExists(model, calls, globals, out, ui and M.blizzardNames(ui) or nil)
		local fakeEnum = M.plainTable(env.Enum) or {}
		if next(fakeEnum) == nil and type(env.Enum) == "table" then -- the table behind the proxy was not reachable: ask for each documented name
			fakeEnum = {}
			for name in pairs(model.enums) do local v = env.Enum[name] if v ~= nil then fakeEnum[name] = v end end
		end
		M.checkEnums(model, fakeEnum, out)
		local chunk = loadfile(rel(opt.samples))
		local samples = chunk and chunk() or {}
		M.checkReturns(model, samples, function(name, args, sample)
			local fn = lookup(env, name)
			if type(fn) ~= "function" then return nil end
			-- a sample may set the game up first: setup(world, client), e.g. a cast under way for UnitCastingInfo
			if type(sample) == "table" and type(sample.setup) == "function" and args == sample.args then
				local okS, errS = pcall(sample.setup, world, client)
				if not okS then print("  sample setup for " .. name .. " failed: " .. tostring(errS)) end
			end
			local function count(good, ...) if not good then return nil end return select("#", ...), type((...)) end
			local a = type(args) == "function" and args(env) or args
			return count(pcall(fn, unpack(a, 1, a.n or #a)))
		end, out)
		local ctext = readFile(rel(opt.constants))
		if ctext then M.checkConstants(ctext, env, out) end
	else
		M.checkExists(model, calls, {}, out)
	end
	local v = M.verdict(out, M.parseKnown(readFile(rel(opt.known))))
	for _, f in ipairs(v.fresh) do print(("%-60s %s"):format(f.key, f.text)) end
	for _, k in ipairs(v.stale) do print("stale (in " .. opt.known .. ", no longer found): " .. k) end
	local result = #v.fresh == 0 and "pass" or "fail"
	print(("GAUNTLET apidocs result=%s findings=%d known=%d stale=%d"):format(result, #v.fresh, v.known, #v.stale))
	os.exit(result == "pass" and 0 or 1)
end

local args = { ... }
if args[1] == "--lib" then return M end
M.main(args)
