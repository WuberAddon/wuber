-- The bug hunt's core (tests/hunt/README.md is the contract). Loads the fake game (tests/harness.lua) itself,
-- keeps the dial, promise and action registries, builds a situation into a world (ctx), runs promise checks,
-- walks, shrinks failures and writes the one-file repro tests. Lua 5.1; every choice comes from a seed.
--   local Hunt = dofile("tests/hunt/lib.lua")
--   Hunt.init({ addon = "<folder with another Wuber>" })   -- once; loads the harness, then every dial/promise/action file
--   local res = Hunt.runPromise("tips.first_open", { session = "reload" }, 7)
-- Nothing here changes addon code. Not part of the normal suite.

local Hunt = {}

---------------------------------------------------------------------------
-- Paths
---------------------------------------------------------------------------

local function norm(p)
	p = tostring(p):gsub("\\", "/")
	local abs = p:sub(1, 1) == "/"
	local out = {}
	for seg in p:gmatch("[^/]+") do
		if seg == "." then
			-- nothing
		elseif seg == ".." and #out > 0 and out[#out] ~= ".." and not out[#out]:match("^%a:$") then
			table.remove(out)
		else
			out[#out + 1] = seg
		end
	end
	local s = table.concat(out, "/")
	if abs then s = "/" .. s end
	if s == "" then s = "." end
	return s
end
Hunt.norm = norm

local SRC = (debug.getinfo(1, "S").source or ""):gsub("^@", ""):gsub("\\", "/")
-- SRCDIR: where this file is (its parts, lib/shrink.lua and situations.lua, load from there); DIR: the repo's
-- tests/hunt (dials, actions). WUBER_HUNT_ROOT=<repo> runs a copy of the core against that repo (trying a new core).
Hunt.SRCDIR = norm(SRC:match("^(.*)/[^/]*$") or "tests/hunt")
Hunt.DIR = Hunt.SRCDIR
Hunt.ROOT = norm(Hunt.DIR .. "/../..")
do
	local over = os.getenv and os.getenv("WUBER_HUNT_ROOT")
	if over and over ~= "" then
		Hunt.ROOT = norm(over)
		Hunt.DIR = Hunt.ROOT .. "/tests/hunt"
	end
end

local WINDOWS = package.config:sub(1, 1) == "\\"
function Hunt.mkdir(path)
	path = norm(path)
	if WINDOWS then
		os.execute('if not exist "' .. path:gsub("/", "\\") .. '\\" mkdir "' .. path:gsub("/", "\\") .. '" >nul 2>nul')
	else
		os.execute('mkdir -p "' .. path .. '"')
	end
end

function Hunt.readFile(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local t = f:read("*a")
	f:close()
	return t
end

function Hunt.writeFile(path, text)
	local f = assert(io.open(path, "wb"))
	f:write(text)
	f:close()
end

function Hunt.exists(path)
	local f = io.open(path, "rb")
	if f then f:close() return true end
	return false
end

---------------------------------------------------------------------------
-- The generator (Park-Miller minimal standard, in doubles: 16807 * (2^31 - 1) < 2^53, so exact)
---------------------------------------------------------------------------

local M = 2147483647
local Rng = {}
Rng.__index = Rng

function Hunt.hash(str, h)
	h = h or 5381
	str = tostring(str)
	for i = 1, #str do h = (h * 33 + str:byte(i)) % 2147483629 end
	return h
end

function Hunt.hex(str) return ("%06x"):format(Hunt.hash(str) % 16777216) end

function Hunt.rng(seed)
	local s = math.floor(tonumber(seed) or 1) % (M - 1)
	if s < 0 then s = s + M - 1 end
	local r = setmetatable({ s = s + 1 }, Rng)
	r:next()
	r:next()
	return r
end
function Rng:next()
	self.s = (16807 * self.s) % M
	return self.s / M -- (0, 1)
end
function Rng:int(n)
	n = math.floor(tonumber(n) or 0)
	if n < 1 then error("rng:int(n) needs n >= 1", 2) end
	local v = math.floor(self:next() * n) + 1
	if v > n then v = n end
	return v
end
function Rng:pick(list)
	if type(list) ~= "table" or #list == 0 then return nil end
	return list[self:int(#list)]
end
function Rng:chance(p) return self:next() < (tonumber(p) or 0) end
function Rng:shuffle(list)
	for i = #list, 2, -1 do
		local j = self:int(i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end
-- a generator of its own for a part of the work (the label), the same every time for this state
function Rng:fork(label) return Hunt.rng(Hunt.hash(tostring(label), self.s)) end

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

local function sortedKeys(t)
	local out = {}
	for k in pairs(t or {}) do out[#out + 1] = k end
	table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
	return out
end
Hunt.sortedKeys = sortedKeys

local function copy(t)
	local out = {}
	for k, v in pairs(t or {}) do out[k] = v end
	return out
end
Hunt.copy = copy

-- saved data as the game keeps it on disk: strings, numbers, booleans and tables of them (no functions,
-- no shared tables)
local function plain(v, depth)
	depth = depth or 0
	local tv = type(v)
	if tv == "string" or tv == "number" or tv == "boolean" then return v end
	if tv ~= "table" or depth > 40 then return nil end
	local out = {}
	for k, x in pairs(v) do
		local tk = type(k)
		if tk == "string" or tk == "number" then
			local px = plain(x, depth + 1)
			if px ~= nil then out[k] = px end
		end
	end
	return out
end
Hunt.plain = plain

local function contains(list, v)
	if type(list) ~= "table" then return list == v end
	for _, x in ipairs(list) do if x == v then return true end end
	return false
end
Hunt.contains = contains

-- a Lua literal of plain data (sorted keys: the same text every time)
local function ser(v, ind)
	ind = ind or ""
	local tv = type(v)
	if tv == "string" then
		local s = ("%q"):format(v)
		s = s:gsub("\\\n", "\\n")
		s = s:gsub("\r", "\\r")
		return s
	end
	if tv == "number" then
		if v == math.floor(v) and math.abs(v) < 1e15 then return ("%d"):format(v) end
		return ("%.17g"):format(v)
	end
	if tv == "boolean" or tv == "nil" then return tostring(v) end
	if tv ~= "table" then return "nil --[[" .. tv .. "]]" end
	local n = #v
	local parts = {}
	for i = 1, n do parts[#parts + 1] = ser(v[i], ind .. "\t") end
	for _, k in ipairs(sortedKeys(v)) do
		if not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) then
			local key = (type(k) == "string" and k:match("^[%a_][%w_]*$")) and k or ("[" .. ser(k) .. "]")
			parts[#parts + 1] = key .. " = " .. ser(v[k], ind .. "\t")
		end
	end
	if #parts == 0 then return "{}" end
	local one = "{ " .. table.concat(parts, ", ") .. " }"
	if #one <= 100 and not one:find("\n") then return one end
	return "{\n" .. ind .. "\t" .. table.concat(parts, ",\n" .. ind .. "\t") .. ",\n" .. ind .. "}"
end
Hunt.ser = ser

local function oneLine(s, max)
	s = tostring(s or ""):gsub("%s+", " ")
	max = max or 300
	if #s > max then s = s:sub(1, max - 3) .. "..." end
	return s
end
Hunt.oneLine = oneLine

-- a plain line with its numbers blanked (a finding's key: "3 riders" and "4 riders" are the same finding)
function Hunt.blank(s) return (oneLine(s, 400):gsub("%d+", "#")) end
function Hunt.findingKey(pid, seen) return tostring(pid) .. "\1" .. Hunt.blank(seen) end

-- a Lua literal of plain data on ONE line (sorted keys): one record per line in the sweep's append-only files
local function serLine(v)
	local tv = type(v)
	if tv == "string" then
		local s = ("%q"):format(v)
		s = s:gsub("\\\n", "\\n")
		s = s:gsub("\r", "\\r")
		return s
	end
	if tv == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return "0" end
		if v == math.floor(v) and math.abs(v) < 1e15 then return ("%d"):format(v) end
		return ("%.17g"):format(v)
	end
	if tv == "boolean" then return tostring(v) end
	if tv ~= "table" then return "nil" end
	local n = #v
	local parts = {}
	for i = 1, n do parts[#parts + 1] = serLine(v[i]) end
	for _, k in ipairs(sortedKeys(v)) do
		if not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) then
			local key = (type(k) == "string" and k:match("^[%a_][%w_]*$")) and k or ("[" .. serLine(k) .. "]")
			parts[#parts + 1] = key .. "=" .. serLine(v[k])
		end
	end
	return "{" .. table.concat(parts, ",") .. "}"
end
Hunt.serLine = serLine

-- promise ids never checked in this run (sweep.lua --skip id,id; an id ending in "." skips every id it starts)
Hunt.skipIds = {}
function Hunt.isSkipped(id)
	id = tostring(id)
	for _, s in ipairs(Hunt.skipIds) do
		if s == id or (s:sub(-1) == "." and id:sub(1, #s) == s) then return true end
	end
	return false
end

---------------------------------------------------------------------------
-- The fake game
---------------------------------------------------------------------------

local H, S

-- Hunt.init{ addon = dir, quiet = bool }: loads tests/harness.lua (with the paths run.lua gives it) and every
-- dial, promise and action file. A second call only changes nothing (one harness per process).
function Hunt.init(opts)
	opts = opts or {}
	if not H then
		arg = arg or {}
		local old0 = arg[0]
		arg[0] = Hunt.ROOT .. "/tests/run.lua" -- the harness finds the repo from it (H.root, round1)
		package.path = Hunt.ROOT .. "/tests/?.lua;" .. package.path
		local ok, h = pcall(require, "harness")
		arg[0] = old0
		if not ok then error("the hunt could not load tests/harness.lua: " .. tostring(h), 0) end
		H, S = h, h.state
		Hunt.H = H
		Hunt.defaultAddon = H.ADDONS.Wuber
	end
	if opts.addon then
		local dir = norm(opts.addon)
		if not Hunt.exists(dir .. "/Wuber.toc") then error("--addon: no Wuber.toc in " .. dir, 0) end
		H.ADDONS.Wuber = dir
	end
	Hunt.addonDir = H.ADDONS.Wuber
	if not Hunt.loaded then
		Hunt.loaded = true
		Hunt.loadAll()
	end
	return Hunt
end

-- what Wuber is loaded from (the --addon proof): the folder, its VERSION line and a fingerprint of its TOC
function Hunt.addonInfo()
	local dir = Hunt.addonDir or "?"
	local base = Hunt.readFile(dir .. "/Core/Base.lua") or ""
	local ver = base:match('W%.VERSION%s*=%s*"([^"]+)"') or "?"
	local toc = Hunt.readFile(dir .. "/Wuber.toc") or ""
	local n = 0
	for line in toc:gmatch("[^\r\n]+") do if line:match("%.lua%s*$") then n = n + 1 end end
	return ("%s (W.VERSION %s, %d files in the TOC, TOC %s)"):format(norm(dir), ver, n, Hunt.hex(toc))
end

---------------------------------------------------------------------------
-- Registries (a file's registrations count only when the whole file loaded)
---------------------------------------------------------------------------

Hunt.dials, Hunt.dialOrder = {}, {}
Hunt.promises, Hunt.promiseOrder = {}, {}
Hunt.actions, Hunt.actionOrder = {}, {}
Hunt.loadErrors, Hunt.files = {}, {}
local stage

local function where() return stage and stage.file or "(no file)" end

local ID = "^[%w_%-%.]+$"

function Hunt.dial(d)
	if type(d) ~= "table" then error("Hunt.dial{...} needs a table", 2) end
	if type(d.name) ~= "string" or not d.name:match("^[%w_]+$") then error("a dial needs a name (letters, digits, _)", 2) end
	if type(d.values) ~= "table" or #d.values == 0 then error("dial " .. d.name .. " has no values", 2) end
	d.byId = {}
	for i, v in ipairs(d.values) do
		if type(v) ~= "table" or type(v.id) ~= "string" or v.id == "" or v.id:find("[%s,=]") then
			error("dial " .. d.name .. ": value " .. i .. " needs an id (a string without spaces, commas or =)", 2)
		end
		if d.byId[v.id] then error("dial " .. d.name .. ": two values are called " .. v.id, 2) end
		for _, hk in ipairs({ "pre", "world", "login", "apply" }) do
			if v[hk] ~= nil and type(v[hk]) ~= "function" then error("dial " .. d.name .. "=" .. v.id .. ": " .. hk .. " must be a function", 2) end
		end
		if v.excludes ~= nil and type(v.excludes) ~= "table" then error("dial " .. d.name .. "=" .. v.id .. ": excludes must be a table", 2) end
		d.byId[v.id] = v
	end
	if d.valid ~= nil and type(d.valid) ~= "function" then error("dial " .. d.name .. ": valid must be a function(sit) -> ok, why", 2) end
	d.default = d.default or d.values[1].id
	if not d.byId[d.default] then error("dial " .. d.name .. ": the default " .. tostring(d.default) .. " is not one of its values", 2) end
	d.phase = tonumber(d.phase) or 90
	d.file = where()
	if stage then stage.dials[#stage.dials + 1] = d else Hunt.commitDial(d) end
	return d
end

function Hunt.promise(p)
	if type(p) ~= "table" then error("Hunt.promise{...} needs a table", 2) end
	if type(p.id) ~= "string" or not p.id:match("^[%w_]+%.[%w_%.%-]+$") then error("a promise needs an id like area.name", 2) end
	if type(p.check) ~= "function" then error("promise " .. p.id .. " has no check function", 2) end
	p.kind = p.kind or "scenario"
	if p.kind ~= "scenario" and p.kind ~= "always" then error("promise " .. p.id .. ": kind is scenario or always", 2) end
	if p.when ~= nil and type(p.when) ~= "function" then error("promise " .. p.id .. ": when must be a function", 2) end
	if p.pre ~= nil and type(p.pre) ~= "function" then error("promise " .. p.id .. ": pre must be a function", 2) end
	if p.needs ~= nil and type(p.needs) ~= "table" then error("promise " .. p.id .. ": needs must be a table", 2) end
	p.text = p.text or p.id
	p.file = where()
	if stage then stage.promises[#stage.promises + 1] = p else Hunt.commitPromise(p) end
	return p
end

function Hunt.action(a)
	if type(a) ~= "table" or type(a.id) ~= "string" or not a.id:match(ID) then error("Hunt.action{...} needs an id", 2) end
	if type(a.run) ~= "function" then error("action " .. a.id .. " has no run function", 2) end
	if a.pick ~= nil and type(a.pick) ~= "function" then error("action " .. a.id .. ": pick must be a function", 2) end
	a.weight = tonumber(a.weight) or 1
	if a.weight <= 0 then error("action " .. a.id .. ": weight must be above 0", 2) end
	a.file = where()
	if stage then stage.actions[#stage.actions + 1] = a else Hunt.commitAction(a) end
	return a
end

local function sortByName(list, key) table.sort(list, function(a, b) return a[key] < b[key] end) end

function Hunt.commitDial(d)
	if Hunt.dials[d.name] then error("dial " .. d.name .. " is already defined by " .. Hunt.dials[d.name].file, 0) end
	Hunt.dials[d.name] = d
	Hunt.dialOrder[#Hunt.dialOrder + 1] = d
	sortByName(Hunt.dialOrder, "name")
end
function Hunt.commitPromise(p)
	if Hunt.promises[p.id] then error("promise " .. p.id .. " is already defined by " .. Hunt.promises[p.id].file, 0) end
	Hunt.promises[p.id] = p
	Hunt.promiseOrder[#Hunt.promiseOrder + 1] = p
	sortByName(Hunt.promiseOrder, "id")
end
function Hunt.commitAction(a)
	if Hunt.actions[a.id] then error("action " .. a.id .. " is already defined by " .. Hunt.actions[a.id].file, 0) end
	Hunt.actions[a.id] = a
	Hunt.actionOrder[#Hunt.actionOrder + 1] = a
	sortByName(Hunt.actionOrder, "id")
end

local function traceback(e)
	if type(e) == "table" then return e end
	return debug.traceback(tostring(e), 2)
end

-- one dial / promise / action file; a missing or broken file is reported (Hunt.loadErrors) and skipped
function Hunt.loadFile(path)
	local rel = path:gsub("^" .. Hunt.ROOT:gsub("%p", "%%%0") .. "/", "")
	local chunk, err = loadfile(path)
	if not chunk then
		Hunt.loadErrors[#Hunt.loadErrors + 1] = { file = rel, err = tostring(err) }
		return false
	end
	stage = { file = rel, dials = {}, promises = {}, actions = {} }
	local ok, e = xpcall(function()
		local f = chunk()
		if type(f) == "function" then f(Hunt)
		elseif f ~= nil and f ~= true and f ~= Hunt then error("the file must return function(Hunt) ... end") end
	end, traceback)
	local st = stage
	stage = nil
	if ok then
		ok, e = pcall(function()
			for _, d in ipairs(st.dials) do if Hunt.dials[d.name] then error("dial " .. d.name .. " is already defined by " .. Hunt.dials[d.name].file, 0) end end
			for _, p in ipairs(st.promises) do if Hunt.promises[p.id] then error("promise " .. p.id .. " is already defined by " .. Hunt.promises[p.id].file, 0) end end
			for _, a in ipairs(st.actions) do if Hunt.actions[a.id] then error("action " .. a.id .. " is already defined by " .. Hunt.actions[a.id].file, 0) end end
		end)
	end
	if not ok then
		Hunt.loadErrors[#Hunt.loadErrors + 1] = { file = rel, err = tostring(e) }
		return false
	end
	for _, d in ipairs(st.dials) do Hunt.commitDial(d) end
	for _, p in ipairs(st.promises) do Hunt.commitPromise(p) end
	for _, a in ipairs(st.actions) do Hunt.commitAction(a) end
	Hunt.files[#Hunt.files + 1] = rel
	return true
end

function Hunt.listLua(dir)
	local out = {}
	for _, p in ipairs(H.listFiles(dir, "lua")) do out[#out + 1] = norm(p) end
	table.sort(out)
	return out
end

-- dials (tests/hunt/dials/*.lua, by name), then promises (tests/promises/*.lua), then tests/hunt/actions.lua
function Hunt.loadAll()
	Hunt.Sit = dofile(Hunt.SRCDIR .. "/situations.lua")(Hunt)
	Hunt.Sit.loadDials()
	for _, p in ipairs(Hunt.listLua(Hunt.ROOT .. "/tests/promises")) do Hunt.loadFile(p) end
	local act = Hunt.DIR .. "/actions.lua"
	if Hunt.exists(act) then Hunt.loadFile(act) end
	for _, d in ipairs(Hunt.dialOrder) do
		for _, v in ipairs(d.values) do
			for od, list in pairs(v.excludes or {}) do
				if not Hunt.dials[od] then
					Hunt.notes = Hunt.notes or {}
					Hunt.notes[#Hunt.notes + 1] = "dial " .. d.name .. "=" .. v.id .. " excludes dial " .. tostring(od) .. ", which is not loaded (ignored)"
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Situations: { [dialName] = valueId }; a missing dial is its default
---------------------------------------------------------------------------

function Hunt.full(sit)
	local out = {}
	for name, v in pairs(sit or {}) do
		local d = Hunt.dials[name]
		if not d then error("no dial called " .. tostring(name) .. " (lua5.1 tools/hunt/sweep.lua --list)", 0) end
		if not d.byId[v] then error("dial " .. name .. " has no value " .. tostring(v), 0) end
		out[name] = v
	end
	for _, d in ipairs(Hunt.dialOrder) do if out[d.name] == nil then out[d.name] = d.default end end
	return out
end

-- "a=b,c=d" (the non-default dials, by name; "default" when none); all = every dial
function Hunt.sitString(sit, all)
	local parts = {}
	for _, d in ipairs(Hunt.dialOrder) do
		local v = sit[d.name] or d.default
		if all or v ~= d.default then parts[#parts + 1] = d.name .. "=" .. v end
	end
	for _, k in ipairs(sortedKeys(sit)) do
		if not Hunt.dials[k] then parts[#parts + 1] = k .. "=" .. tostring(sit[k]) .. "(no such dial)" end
	end
	if #parts == 0 then return "default" end
	return table.concat(parts, ",")
end

function Hunt.parseSit(s)
	local out = {}
	s = tostring(s or "")
	if s == "" or s == "default" then return out end
	for part in s:gmatch("[^,]+") do
		local k, v = part:match("^%s*([^=%s]+)%s*=%s*([^%s]+)%s*$")
		if not k then error("a situation is dial=value,dial=value: " .. part, 0) end
		out[k] = v
	end
	return out
end

-- can these dial values exist together? false and why when one excludes another
function Hunt.compatible(full)
	for _, d in ipairs(Hunt.dialOrder) do
		local v = d.byId[full[d.name] or d.default]
		for od, list in pairs(v and v.excludes or {}) do
			if Hunt.dials[od] then
				local other = full[od] or Hunt.dials[od].default
				if contains(type(list) == "table" and list or { list }, other) then
					return false, "cannot exist: " .. d.name .. "=" .. v.id .. " cannot exist with " .. od .. "=" .. other
				end
			end
		end
	end
	-- a dial's valid(fullSituation) -> ok, why: a state no player could be in (it sees every dial's value)
	local view
	for _, d in ipairs(Hunt.dialOrder) do
		if d.valid then
			if not view then
				view = {}
				for _, d2 in ipairs(Hunt.dialOrder) do view[d2.name] = full[d2.name] or d2.default end
			end
			local okv, ok, why = pcall(d.valid, copy(view))
			if not okv then
				Hunt.notes = Hunt.notes or {}
				local msg = "dial " .. d.name .. ": valid() raised: " .. tostring(ok):match("^[^\n]*")
				if not Hunt.contains(Hunt.notes, msg) then Hunt.notes[#Hunt.notes + 1] = msg end
				return false, "cannot exist: " .. msg
			end
			if not ok then return false, "cannot exist: " .. tostring(why or ("dial " .. d.name .. " says no")) end
		end
	end
	return true
end

-- the values a promise allows for each dial (its needs), or nil and why
function Hunt.domains(p)
	if p and p._dom and p._domN == #Hunt.dialOrder then return p._dom end
	local dom = {}
	for _, d in ipairs(Hunt.dialOrder) do
		local list = {}
		for _, v in ipairs(d.values) do list[#list + 1] = v.id end
		dom[d.name] = list
	end
	for name, want in pairs(p and p.needs or {}) do
		local d = Hunt.dials[name]
		if not d then return nil, "it needs the dial " .. name .. ", which is not loaded" end
		local list = type(want) == "table" and want or { want }
		for _, v in ipairs(list) do
			if not d.byId[v] then return nil, "it needs " .. name .. "=" .. tostring(v) .. ", which that dial does not have" end
		end
		dom[name] = list
	end
	if p then p._dom, p._domN = dom, #Hunt.dialOrder end
	return dom
end

-- a promise's view of a situation: its needs put in, then excludes and when; nil and why (na) when it
-- does not apply; throws when its when() throws (a broken check)
function Hunt.project(p, sit)
	local full = Hunt.full(sit)
	local dom, why = Hunt.domains(p)
	if not dom then return nil, why end
	for name in pairs(p and p.needs or {}) do
		if not contains(dom[name], full[name]) then full[name] = dom[name][1] end
	end
	local ok, why2 = Hunt.compatible(full)
	if not ok then return nil, why2 end
	if p and p.when then
		local okw, res = pcall(p.when, copy(full))
		if not okw then error({ hunt = "broken", detail = "when() of " .. p.id .. " raised: " .. tostring(res) }) end
		if not res then return nil, "its when() says it does not apply here" end
	end
	return full
end

-- does a full situation already satisfy a promise (an always-promise after another check)?
function Hunt.applies(p, full)
	local okp, proj = pcall(Hunt.project, p, full)
	if not okp or not proj then return false end
	for k, v in pairs(proj) do if full[k] ~= v then return false end end
	return true
end

---------------------------------------------------------------------------
-- ctx: one built situation
---------------------------------------------------------------------------

local Ctx = {}
Ctx.__index = Ctx
Hunt.Ctx = Ctx

local SIGNAL = { fail = { hunt = "fail" }, cannot = { hunt = "cannot" }, na = { hunt = "na" } }

Hunt.DEFAULT_NAME = "Wuber TestCharacter"
Hunt.DEFAULT_CLIENT = { spot = "Orgrimmar", class = "MAGE", money = 100000 }

local function newCtx(full, seed)
	local ctx = setmetatable({
		sit = copy(full), seed = seed, rng = Hunt.rng(seed),
		worldOpts = {}, clientOpts = copy(Hunt.DEFAULT_CLIENT), saved = {},
		facts = {}, peers = {}, log = {}, H = H, S = S, Hunt = Hunt, name = Hunt.DEFAULT_NAME,
	}, Ctx)
	return ctx
end

function Ctx:note(line) self.log[#self.log + 1] = { kind = "note", text = oneLine(line) } end

-- one ctx.log entry as a line (entries are tables { kind, text, id, args } or plain strings from a dial)
function Hunt.logLine(e)
	if type(e) ~= "table" then return "note: " .. oneLine(e, 300) end
	local t = e.text or (e.id and (e.id .. " " .. Hunt.ser(e.args))) or ""
	return tostring(e.kind or "note") .. ": " .. oneLine(t, 300)
end
function Ctx:advance(secs) self.w:advance(tonumber(secs) or 0) end
function Ctx:mod(name)
	local W = self.W
	if type(W) ~= "table" or type(W.Mod) ~= "function" then return nil end
	local ok, m = pcall(W.Mod, name)
	if ok and type(m) == "table" then return m end
	return nil
end
function Ctx:visible(region)
	if type(region) ~= "table" or not S[region] then return false end
	local ok, v = pcall(H.visible, region)
	return ok and v and true or false
end
-- every visible text of my window, top to bottom (then left to right)
function Ctx:texts()
	local c = self.me
	if not c then return {} end
	local items = {}
	for i, obj in ipairs(c.widgets or {}) do
		local s = S[obj]
		if s and s.otype == "FontString" and type(s.text) == "string" and s.text ~= "" and self:visible(obj) then
			local okr, r = pcall(H.rect, obj)
			local top, left = 0, 0
			if okr and type(r) == "table" then top, left = (r.b or 0) + (r.h or 0), r.l or 0 end
			items[#items + 1] = { text = s.text, top = top, left = left, i = i }
		end
	end
	table.sort(items, function(a, b)
		if a.top ~= b.top then return a.top > b.top end
		if a.left ~= b.left then return a.left < b.left end
		return a.i < b.i
	end)
	local out = {}
	for _, it in ipairs(items) do out[#out + 1] = it.text end
	return out
end
function Ctx:fail(seen, detail)
	if not self._failed then self._failed = { seen = oneLine(seen, 400), detail = detail and oneLine(detail, 2000) or nil } end
	error(SIGNAL.fail, 0)
end
function Ctx:cannot(why)
	self._cannot = self._cannot or oneLine(why or "cannot build this", 600)
	error(SIGNAL.cannot, 0)
end
function Ctx:na(why)
	self._na = self._na or oneLine(why or "does not apply here", 600)
	error(SIGNAL.na, 0)
end

-- my client logs in (the session dial calls this; a world without the session dial gets a plain login)
function Ctx:login(extra)
	local o = copy(self.clientOpts)
	for k, v in pairs(extra or {}) do o[k] = v end
	o.saved = plain(self.saved) or {}
	local keep = copy(o)
	keep.saved = nil
	self.loginOpts = keep
	self.me = self.w:addClient(self.name, o)
	self.W = self.me.W
	self.logins = (self.logins or 0) + 1
	self._loginAt = self.w.time
	return self.me
end

-- after the build, a /reload or a relog waits as long as the session dial's login waited after its last login
-- (ctx.settleSeconds, measured by Hunt.build; Hunt.SETTLE_SECONDS when unknown), so the session settles the same
-- way (the network joins its channel, timers start). Inside the session dial's own login hook it does not wait.
Hunt.SETTLE_SECONDS = 2
local function settle(ctx)
	ctx._loginAt = ctx.w.time
	if ctx.stage ~= "login" then
		local s = tonumber(ctx.settleSeconds) or Hunt.SETTLE_SECONDS
		if s > 0 then ctx:advance(s) end
	end
end

-- the first PLAYER_ENTERING_WORLD of this window says (false, true): a /reload, as the game does
local function asReload(client)
	local method = client.fire
	client.fire = function(selfc, ev, ...)
		if ev == "PLAYER_ENTERING_WORLD" then
			client.fire = nil -- back to the method for every later loading screen
			return method(selfc, ev, false, true)
		end
		return method(selfc, ev, ...)
	end
end

local function savedOf(c)
	local saved = {}
	for _, addon in ipairs(c.allAddons or c.addons or { "Wuber" }) do
		local sv = addon == "Wuber" and "WuberDB" or (addon .. "DB")
		local v = rawget(c.env, sv)
		if v == nil then v = c.saved[addon] end
		saved[addon] = plain(v)
	end
	return saved
end

-- a /reload: PLAYER_LOGOUT, the saved data kept (as on disk), a new window with PLAYER_ENTERING_WORLD(false, true)
function Ctx:reload()
	local c, w = self.me, self.w
	if not c then error("ctx:reload() before my client logged in", 2) end
	if c.alive then c:fire("PLAYER_LOGOUT") end
	local saved = savedOf(c)
	w:closeClient(c, false)
	c.player.online = true
	w.reloads = (w.reloads or 0) + 1
	local o = copy(self.loginOpts)
	o.saved = saved
	o.spot = nil -- a /reload leaves the player where he stands (the world keeps him); the spawn spot would move him back
	local prep = o.prepare
	o.prepare = function(env, client)
		asReload(client)
		if prep then prep(env, client) end
	end
	self.me = w:addClient(self.name, o)
	self.W = self.me.W
	self.reloads = (self.reloads or 0) + 1
	settle(self)
	return self.me
end

-- a real logout and login (gap seconds offline, 5 by default)
function Ctx:relog(gap)
	local c, w = self.me, self.w
	if not c then error("ctx:relog() before my client logged in", 2) end
	local saved = plain(w:logout(c)) or {}
	w:advance(tonumber(gap) or 5)
	local o = copy(self.loginOpts)
	o.saved = saved
	self.me = w:addClient(self.name, o)
	self.W = self.me.W
	self.logins = (self.logins or 0) + 1
	settle(self)
	return self.me
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------

-- the hooks of a situation, in phase order (then dial name)
local function hooksOf(full)
	local list = {}
	for _, d in ipairs(Hunt.dialOrder) do
		local v = d.byId[full[d.name] or d.default]
		list[#list + 1] = { dial = d, value = v }
	end
	table.sort(list, function(a, b)
		if a.dial.phase ~= b.dial.phase then return a.dial.phase < b.dial.phase end
		return a.dial.name < b.dial.name
	end)
	return list
end

local savedTextMetrics, haveSavedTM

-- builds a full situation (throws the ctx signals or errors; runCase sorts them out). extraPre: a promise's
-- own pre (after every dial's)
function Hunt.build(full, seed, extraPre)
	if not haveSavedTM then savedTextMetrics, haveSavedTM = H.textMetrics, true end
	local okU, U = pcall(dofile, Hunt.DIR .. "/lib/universal_util.lua")
	if okU and type(U) == "table" and U.TL then H.textMetrics = U.TL end
	local ctx = newCtx(full, seed)
	Hunt.current = ctx
	local hooks = hooksOf(full)
	for _, h in ipairs(hooks) do
		if h.value.id ~= h.dial.default then ctx.log[#ctx.log + 1] = { kind = "dial", text = h.dial.name .. "=" .. h.value.id } end
	end
	ctx.stage = "pre"
	for _, h in ipairs(hooks) do if h.value.pre then ctx.hook = h.dial.name h.value.pre(ctx) end end
	if extraPre then ctx.hook = "promise" extraPre(ctx) end
	ctx.stage = "world"
	ctx.w = H.NewWorld(ctx.worldOpts)
	for _, h in ipairs(hooks) do if h.value.world then ctx.hook = h.dial.name h.value.world(ctx) end end
	ctx.stage = "login"
	local logged = false
	for _, h in ipairs(hooks) do
		if h.value.login then
			if logged then error("two dials log my client in (" .. logged .. " and " .. h.dial.name .. ")", 0) end
			ctx.hook = h.dial.name
			h.value.login(ctx)
			logged = h.dial.name
		end
	end
	if not logged then
		ctx:login()
		ctx:advance(2)
	end
	if not ctx.me then error("the session's login hook made no client (ctx:login())", 0) end
	if ctx._loginAt and ctx.w and ctx.w.time and ctx.w.time >= ctx._loginAt then ctx.settleSeconds = ctx.w.time - ctx._loginAt end
	ctx.stage = "apply"
	for _, h in ipairs(hooks) do if h.value.apply then ctx.hook = h.dial.name h.value.apply(ctx) end end
	ctx.stage, ctx.hook = "built", nil
	return ctx
end

---------------------------------------------------------------------------
-- Checks
---------------------------------------------------------------------------

Hunt.CASE_SECONDS = 240 -- one build + check longer than this (CPU) is stopped (an endless loop is not a bug report)

local deadline
local function guard(fn)
	deadline = os.clock() + Hunt.CASE_SECONDS
	debug.sethook(function()
		-- (raised again at every hook call until it gets out: the harness catches errors in timers and scripts)
		if deadline and os.clock() > deadline then error("the hunt stopped it: over " .. Hunt.CASE_SECONDS .. " s", 0) end
		-- the run's own end (sweep.lua --deadline-seconds): a wall clock, not a choice
		if Hunt.hardStop and os.time() >= Hunt.hardStop then
			Hunt.timeUp = true
			error("the hunt stopped it: the run's time is up", 0)
		end
	end, "", 1000000)
	local ok, err = xpcall(fn, traceback)
	debug.sethook()
	deadline = nil
	return ok, err
end

local function signalOf(ctx, err)
	if ctx and ctx._failed then return "fail" end
	if ctx and ctx._na then return "na" end
	if ctx and ctx._cannot then return "cannot" end
	if type(err) == "table" and err.hunt then return err.hunt end
	return nil
end

-- runs one promise's check on a built ctx: status, seen, detail
local function runCheck(ctx, p)
	ctx._failed, ctx._cannot, ctx._na = nil, nil, nil
	ctx.stage, ctx.checking = "check", p.id
	local ok, err = guard(function() p.check(ctx) end)
	local sig = signalOf(ctx, err)
	local f, c, n = ctx._failed, ctx._cannot, ctx._na
	ctx._failed, ctx._cannot, ctx._na, ctx.checking = nil, nil, nil, nil
	if sig == "fail" then return "fail", f and f.seen or "?", f and f.detail end
	if sig == "na" then return "na", nil, n end
	if sig == "cannot" then return "cannot-build", nil, "the check could not reach its state: " .. tostring(c) end
	if not ok then
		if type(err) == "table" then err = err.detail or err.hunt or "?" end
		return "broken-check", nil, tostring(err)
	end
	return "pass"
end

-- the always-promises (except skip) that apply to this situation, on the state as it is now
local function runAlways(ctx, full, skip)
	local out = {}
	for _, q in ipairs(Hunt.promiseOrder) do
		if q.kind == "always" and q.id ~= skip and not Hunt.isSkipped(q.id) and Hunt.applies(q, full) then
			local st, seen, detail = runCheck(ctx, q)
			out[#out + 1] = { promise = q.id, status = st, seen = seen, detail = detail }
		end
	end
	return out
end
Hunt.runAlways = runAlways

-- a long session moves the world's Lua errors away after each look (ctx.huntErrors), so a later, different
-- error is a new finding instead of hiding behind the first (universal.no_lua_error reports errors[1])
local function clearErrors(ctx)
	local e = ctx and ctx.w and ctx.w.errors
	if type(e) ~= "table" then return end
	local n = #e
	if n == 0 then return end
	ctx.huntErrors = ctx.huntErrors or {}
	for i = 1, n do ctx.huntErrors[#ctx.huntErrors + 1] = e[i] end
	for i = n, 1, -1 do e[i] = nil end
end
Hunt.clearErrors = clearErrors

-- after a step raised: does the world still work (my client is there and time can pass)?
local function worldWorks(ctx)
	if not (ctx and ctx.w and ctx.me) then return false, "my client is gone" end
	local ok, err = guard(function() ctx.w:advance(0.1) end)
	if not ok then return false, tostring(type(err) == "table" and (err.hunt or err.detail) or err) end
	return true
end
Hunt.worldWorks = worldWorks

local function release()
	Hunt.current = nil
	if haveSavedTM then H.textMetrics, savedTextMetrics, haveSavedTM = savedTextMetrics, nil, false end
	H.release()
	collectgarbage("collect")
end
Hunt.release = release

-- one replayable case: { promise = id, sit = full, seed = n, steps = { {id, args} } | nil, after = scenario id | nil }
-- opts.always: also run every always-promise on the final state (result.always)
-- -> { status, promise, sit, seed, seen, detail, secs, failStep, always, log }
function Hunt.runCase(case, opts)
	opts = opts or {}
	local t0 = os.clock()
	local p = Hunt.promises[case.promise]
	local res = { promise = case.promise, seed = case.seed, sit = Hunt.sitString(case.sit), steps = case.steps, after = case.after }
	local function done()
		res.secs = os.clock() - t0
		release()
		return res
	end
	if not p then res.status, res.detail = "broken-check", "no promise called " .. tostring(case.promise) return done() end
	local ctx
	local ok, err = guard(function() ctx = Hunt.build(case.sit, case.seed, p.pre) end)
	ctx = ctx or Hunt.current
	if not ok then
		local sig = signalOf(ctx, err)
		if sig == "na" then
			res.status, res.detail = "na", ctx and ctx._na
		else
			local why = (ctx and ctx._cannot) or (type(err) == "table" and (err.detail or err.hunt)) or tostring(err)
			if sig == "fail" then why = "a dial or pre hook called ctx:fail while building: " .. tostring(ctx._failed and ctx._failed.seen) end
			res.status = "cannot-build"
			res.detail = (ctx and ctx.hook and ("[" .. ctx.stage .. " " .. ctx.hook .. "] ") or "") .. tostring(why)
		end
		return done()
	end
	res.log = ctx.log
	if case.after then
		local q = Hunt.promises[case.after]
		if not q then res.status, res.detail = "cannot-build", "the scenario " .. case.after .. " is gone" return done() end
		local st, _, detail = runCheck(ctx, q)
		if st == "broken-check" or st == "cannot-build" then
			res.status, res.detail = "cannot-build", "the scenario " .. case.after .. " before it: " .. tostring(st) .. ": " .. tostring(detail)
			return done()
		end
		ctx.log[#ctx.log + 1] = { kind = "note", text = "ran the scenario " .. case.after .. " (" .. st .. ")" }
	end
	if case.steps and case.match then
		-- a long-session finding replayed (case.match = its plain line, numbers blanked): only that line counts;
		-- the promise's other failures, a na or a step that raised are passed by, as the walk itself did
		local function hit()
			local st, seen, detail = runCheck(ctx, p)
			clearErrors(ctx)
			if st == "fail" and Hunt.blank(seen) == case.match then res.status, res.seen, res.detail = st, seen, detail return true end
			return false
		end
		if hit() then res.failStep = 0 return done() end
		for i, step in ipairs(case.steps) do
			local a = Hunt.actions[step.id]
			if not a then res.status, res.detail = "cannot-build", "no action called " .. tostring(step.id) return done() end
			local okr, line = guard(function() return a.run(ctx, step.args) end)
			if not okr then
				local okw, why = worldWorks(ctx)
				if not okw then
					res.status, res.detail = "cannot-build", "step " .. i .. " (" .. step.id .. ") raised and the world stopped working: " .. tostring(why)
					return done()
				end
				line = "raised: " .. tostring(type(line) == "table" and (line.hunt or "?") or line)
			end
			ctx.log[#ctx.log + 1] = { kind = "step", id = step.id, args = step.args, text = oneLine(line) }
			if hit() then res.failStep = i return done() end
		end
		res.status = "pass"
	elseif case.steps then
		-- a walk replayed: the promise after the build and after every step
		local st, seen, detail = runCheck(ctx, p)
		if st ~= "pass" then res.status, res.seen, res.detail, res.failStep = st, seen, detail, 0 return done() end
		for i, step in ipairs(case.steps) do
			local a = Hunt.actions[step.id]
			if not a then res.status, res.detail = "cannot-build", "no action called " .. tostring(step.id) return done() end
			local okr, line = guard(function() return a.run(ctx, step.args) end)
			if not okr then
				res.status, res.detail = "cannot-build", "step " .. i .. " (" .. step.id .. ") could not be replayed: " .. tostring(type(line) == "table" and (line.hunt or "") or line)
				return done()
			end
			ctx.log[#ctx.log + 1] = { kind = "step", id = step.id, args = step.args, text = oneLine(line) }
			st, seen, detail = runCheck(ctx, p)
			if st ~= "pass" then res.status, res.seen, res.detail, res.failStep = st, seen, detail, i return done() end
		end
		res.status = "pass"
	else
		res.status, res.seen, res.detail = runCheck(ctx, p)
	end
	if opts.always and res.status ~= "broken-check" and res.status ~= "cannot-build" then
		res.always = runAlways(ctx, case.sit, p.id)
	end
	if opts.keep then res.ctx = ctx res.texts = ctx:texts() end
	if opts.verbose then res.texts = ctx:texts() end
	return done()
end

-- runPromise(promise or id, sit, seed) -> result; the situation is projected through the promise first
-- (needs, excludes, when: "na" when it does not apply), then built, checked, and every always-promise run
-- on the final state (result.always)
function Hunt.runPromise(p, sit, seed, opts)
	if type(p) == "string" then p = Hunt.promises[p] end
	if not p then return { status = "broken-check", detail = "no such promise" } end
	seed = seed or 1
	local okp, full, why = pcall(Hunt.project, p, sit or {})
	if not okp then
		return { status = "broken-check", promise = p.id, seed = seed, sit = "?", secs = 0,
			detail = type(full) == "table" and full.detail or tostring(full) }
	end
	if not full then return { status = "na", promise = p.id, seed = seed, sit = Hunt.sitString(Hunt.full(sit or {})), detail = why, secs = 0 } end
	local o = copy(opts or {})
	if o.always == nil then o.always = true end
	return Hunt.runCase({ promise = p.id, sit = full, seed = seed }, o)
end

-- a seed for one (promise, situation): the same in every shard and every run with this base seed
function Hunt.caseSeed(base, pid, sitStr) return Hunt.hash(pid .. "|" .. sitStr, tonumber(base) or 1) % 2147483646 + 1 end

---------------------------------------------------------------------------
-- Walks (long sessions): a situation, then steps; every always-promise after the build and each step
---------------------------------------------------------------------------

local function chooseAction(ctx, rng)
	local pool = {}
	for _, a in ipairs(Hunt.actionOrder) do pool[#pool + 1] = a end
	while #pool > 0 do
		local total = 0
		for _, a in ipairs(pool) do total = total + a.weight end
		local x, idx = rng:next() * total, #pool
		for i, a in ipairs(pool) do
			x = x - a.weight
			if x <= 0 then idx = i break end
		end
		local a = table.remove(pool, idx)
		local args = true
		if a.pick then
			local ok, got = guard(function() return a.pick(ctx, rng) end)
			if not ok then return nil, a, got end
			args = got
		end
		if args ~= nil and args ~= false then return a, nil, nil, args end
	end
	return nil
end

-- -> { status, promise (the always-promise that failed, or "walk"), sit, seed, steps, failStep, seen, detail, secs, ran }
-- opts.keepGoing (a long session): a failure does not end the walk. Each distinct finding (promise + plain line with
-- its numbers blanked; a broken check or a step that raised: once per promise / action) is kept in res.findings
-- ({ promise, status, seen, detail, step, key }), then muted for the rest of the walk (res.muted counts the repeats);
-- the world's Lua errors are moved away after each look (a later, different one is a new finding); a step that
-- raised ends the walk only when the world stopped working (res.ended). res.status: "fail" when a promise failed,
-- "broken-check" when only checks or steps broke, else "pass". opts.deadline (os.time): stop stepping then
-- (res.stopped). opts.verbose prints the steps.
function Hunt.walk(full, seed, nsteps, opts)
	opts = opts or {}
	local keep = opts.keepGoing
	local t0 = os.clock()
	local res = { promise = "walk", sit = Hunt.sitString(full), seed = seed, steps = {}, kind = "walk", findings = {}, muted = 0, want = nsteps }
	local function done()
		res.secs = os.clock() - t0
		res.stepsDone = #res.steps
		if keep and res.status == nil then
			res.status = "pass"
			for _, f in ipairs(res.findings) do
				if f.status == "fail" then res.status = "fail" break end
				res.status = "broken-check"
			end
		end
		release()
		return res
	end
	if #Hunt.actionOrder == 0 then res.status, res.detail = "na", "no actions are registered (tests/hunt/actions.lua)" return done() end
	local ctx
	local ok, err = guard(function() ctx = Hunt.build(full, seed) end)
	ctx = ctx or Hunt.current
	if not ok then
		local sig = signalOf(ctx, err)
		res.status = sig == "na" and "na" or "cannot-build"
		res.detail = (ctx and (ctx._na or ctx._cannot)) or tostring(type(err) == "table" and (err.detail or err.hunt) or err)
		if res.status == "cannot-build" and ctx and ctx.hook then res.detail = "[" .. tostring(ctx.stage) .. " " .. ctx.hook .. "] " .. tostring(res.detail) end
		return done()
	end
	local muted = {}
	local function found(f, i)
		f.step = i
		f.key = f.key or Hunt.findingKey(f.promise, f.seen)
		if muted[f.key] then res.muted = res.muted + 1 return end
		muted[f.key] = true
		res.findings[#res.findings + 1] = f
		if opts.verbose then
			print(("  step %d: %s %s: %s"):format(i, f.status, f.promise, oneLine(f.seen or f.detail, 200)))
		end
	end
	local function look(i)
		for _, r in ipairs(runAlways(ctx, full)) do
			if Hunt.timeUp then break end -- (a check the run's end stopped is not a finding)
			if r.status == "fail" or r.status == "broken-check" then
				if not keep then
					res.status, res.promise, res.seen, res.detail, res.failStep = r.status, r.promise, r.seen, r.detail, i
					return true
				end
				found({ promise = r.promise, status = r.status, seen = r.seen, detail = r.detail,
					key = r.status ~= "fail" and (r.promise .. "\1broken") or nil }, i)
			end
		end
		if keep then clearErrors(ctx) end
		return false
	end
	if look(0) then return done() end
	local rng = Hunt.rng(seed):fork("walk")
	for i = 1, nsteps do
		if opts.deadline and os.time() >= opts.deadline then res.stopped = "the time was up after " .. (i - 1) .. " steps" break end
		local a, bad, berr, args = chooseAction(ctx, rng)
		if bad then
			if Hunt.timeUp then res.stopped = "the time was up after " .. (i - 1) .. " steps" break end
			if not keep then
				res.status, res.promise, res.detail, res.failStep = "broken-check", "action." .. bad.id, "pick raised: " .. tostring(berr), i
				return done()
			end
			found({ promise = "action." .. bad.id, status = "broken-check", detail = "pick raised: " .. tostring(type(berr) == "table" and (berr.hunt or "?") or berr),
				key = "action." .. bad.id .. "\1broken" }, i)
			a = nil -- (the next step picks again; a pick that always raises is muted after the first)
		elseif not a then
			if keep then res.ended = "no action possible after " .. (i - 1) .. " steps" break end
			res.status, res.detail = "pass", "no action possible after " .. (i - 1) .. " steps"
			return done()
		end
		if a then
			local okr, line = guard(function() return a.run(ctx, args) end)
			res.steps[#res.steps + 1] = { id = a.id, args = args }
			if not okr then
				if Hunt.timeUp then res.stopped = "the time was up in step " .. i break end
				local why = tostring(type(line) == "table" and (line.hunt or "?") or line)
				if not keep then
					res.status, res.promise, res.detail, res.failStep = "broken-check", "action." .. a.id, "run raised: " .. why, i
					return done()
				end
				found({ promise = "action." .. a.id, status = "broken-check", detail = "run raised: " .. why, key = "action." .. a.id .. "\1broken" }, i)
				ctx.log[#ctx.log + 1] = { kind = "step", id = a.id, args = args, text = "raised: " .. oneLine(why) }
				local okw, why2 = worldWorks(ctx)
				if not okw then res.ended = "after step " .. i .. " the world stopped working: " .. tostring(why2) break end
			else
				ctx.log[#ctx.log + 1] = { kind = "step", id = a.id, args = args, text = oneLine(line) }
				if opts.verbose then print(("  step %d %s: %s"):format(i, a.id, oneLine(line, 160))) end
			end
			if look(i) then return done() end
			if Hunt.timeUp then res.stopped = "the time was up in step " .. i break end
		end
	end
	if not keep then res.status = "pass" end
	return done()
end

---------------------------------------------------------------------------
-- Shrinking, repro files, KNOWN.md (tests/hunt/lib/shrink.lua)
---------------------------------------------------------------------------

dofile(Hunt.SRCDIR .. "/lib/shrink.lua")(Hunt)

return Hunt
