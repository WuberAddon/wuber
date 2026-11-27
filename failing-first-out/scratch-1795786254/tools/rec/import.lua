-- tools/rec/import.lua: saved recorder data (WuberRecDB, the developer-only WuberRec addon) -> test fixtures.
--
--   lua5.1 tools/rec/import.lua [--wtf <WTF folder>] [--file <a WuberRec.lua SavedVariables file>]
--                               [--out tests/fixtures/rec] [--source game|sim] [--deny <names file>] [--list]
--   local IMP = loadfile("tools/rec/import.lua")("--lib")
--
-- --wtf (default the game's _forever_/WTF folder): every Account/*/SavedVariables/WuberRec.lua.
-- --file: one such file instead. --list: say what is there, write nothing.
-- For each saved session it writes <out>/<source>-<id>-<character>.lua: "return { ... }", the table
-- tools/rec/session.lua makes (SES.convert) plus fx.facts (below), written in a fixed order (sorted
-- keys, one event or snapshot row per line, numbers that read back equal), so the same data always
-- gives the same bytes.
--
-- SAFETY. The input is only read: io.open(path, "rb"), never written, renamed or deleted. Its text
-- must be plain data (names, =, braces, brackets, commas, strings, numbers, true/false/nil): anything
-- else (a keyword, a bracket call, an operator) is refused before it runs. Then it runs with an
-- EMPTY environment and an instruction limit, and must leave WuberRecDB as a table.
-- PRIVACY. Before a fixture is written, every string in it is checked against the names in the
-- --deny file (one per line, "#" starts a comment): a hit refuses that fixture. The number of
-- P-numbers (other players, as the recorder renamed them) is always printed.
--
-- fx.facts: a flat list for the conformance tests, each { id = "<kind>:<key>", q = kind, key = key,
-- v = a plain value }, sorted by id. One row of FACTS below adds a kind.

local IMP = {}
local args = { ... }

local here = (debug.getinfo(1, "S").source or ""):gsub("^@", ""):gsub("\\", "/"):match("^(.*)/[^/]*$") or "."
local SES = dofile(here .. "/session.lua")
IMP.SES = SES
IMP.DEFAULT_WTF = "C:/Program Files (x86)/World of Warcraft/_forever_/WTF"
IMP.MAX_STEPS = 50000000 -- instructions the saved data may take to build itself

local WINDOWS = package.config:sub(1, 1) == "\\"

---------------------------------------------------------------------------
-- Reading (only ever "rb")
---------------------------------------------------------------------------

function IMP.read(path)
	local f = io.open(path, "rb")
	if not f then return nil, "cannot open " .. path end
	local text = f:read("*a")
	f:close()
	return text
end

-- The names in a folder (files and folders), sorted; no shell of either kind assumed
-- (as tests/harness.lua's H.listFiles: "dir /b" on Windows, "ls -1" elsewhere).
function IMP.listDir(dir)
	if dir:find('"', 1, true) then return {} end
	local cmd = WINDOWS and ('dir /b "' .. dir:gsub("/", "\\") .. '" 2>nul') or ('ls -1 "' .. dir .. '" 2>/dev/null')
	local p = io.popen(cmd)
	local out = {}
	if not p then return out end
	for name in p:read("*a"):gmatch("[^\r\n]+") do out[#out + 1] = name end
	p:close()
	table.sort(out)
	return out
end

-- every account's WuberRec.lua under a WTF folder
function IMP.findFiles(wtf)
	wtf = wtf:gsub("\\", "/"):gsub("/+$", "")
	local out = {}
	for _, acct in ipairs(IMP.listDir(wtf .. "/Account")) do
		local path = wtf .. "/Account/" .. acct .. "/SavedVariables/WuberRec.lua"
		local f = io.open(path, "rb")
		if f then
			f:close()
			out[#out + 1] = { path = path, account = acct }
		end
	end
	return out
end

-- Is this text plain data? A small Lua lexer: true, or nil and why.
local KEYWORDS = {}
for w in ("and break do else elseif end for function if in local not or repeat return then until while"):gmatch("%a+") do KEYWORDS[w] = true end

function IMP.plainData(text)
	local i, n = 1, #text
	local prev -- the kind of the token before: "name", "]", "str", ...
	while i <= n do
		local c = text:sub(i, i)
		if c:match("%s") then
			i = i + 1
		elseif text:sub(i, i + 1) == "--" then
			local eq = text:match("^%-%-%[(=*)%[", i)
			if eq then
				local close = text:find("]" .. eq .. "]", i, true)
				if not close then return nil, "an open comment" end
				i = close + #eq + 2
			else
				local nl = text:find("\n", i, true)
				i = nl and nl + 1 or n + 1
			end
		elseif c == '"' or c == "'" then
			if prev == "name" or prev == "]" then return nil, "a call (a string after a name) at byte " .. i end
			local j = i + 1
			while true do
				local d = text:sub(j, j)
				if d == "" or d == "\n" then return nil, "an open string at byte " .. i end
				if d == "\\" then j = j + 2
				elseif d == c then break
				else j = j + 1 end
			end
			i, prev = j + 1, "str"
		elseif c == "[" and text:match("^%[=*%[", i) then
			if prev == "name" or prev == "]" then return nil, "a call (a string after a name) at byte " .. i end
			local eq = text:match("^%[(=*)%[", i)
			local close = text:find("]" .. eq .. "]", i, true)
			if not close then return nil, "an open long string" end
			i, prev = close + #eq + 2, "str"
		elseif c:match("[%a_]") then
			local word = text:match("^[%w_]+", i)
			if KEYWORDS[word] then return nil, "the keyword '" .. word .. "' at byte " .. i end
			i, prev = i + #word, (word == "true" or word == "false" or word == "nil") and "value" or "name"
		elseif c:match("%d") or (c == "." and text:sub(i + 1, i + 1):match("%d")) then
			local num = text:match("^0[xX]%x+", i) or text:match("^%d*%.?%d*[eE][%+%-]?%d+", i) or text:match("^%d*%.?%d*", i)
			i, prev = i + #num, "value"
		elseif c == "{" then
			if prev == "name" or prev == "]" then return nil, "a call (a table after a name) at byte " .. i end
			i, prev = i + 1, "{"
		elseif c == "}" or c == "[" or c == "]" or c == "=" or c == "," or c == ";" or c == "-" then
			if c == "=" and text:sub(i + 1, i + 1) == "=" then return nil, "an operator at byte " .. i end
			if c == "-" and not text:match("^%-%s*[%d%.]", i) then return nil, "an operator at byte " .. i end
			i, prev = i + 1, c
		else
			return nil, "'" .. c .. "' at byte " .. i .. " (not plain data)"
		end
	end
	return true
end

-- The saved text -> WuberRecDB (a table), or nil and why. Nothing in the text can reach the tool.
function IMP.loadSaved(text, name)
	name = name or "WuberRecDB"
	if type(text) ~= "string" then return nil, "no text" end
	local okData, why = IMP.plainData(text)
	if not okData then return nil, "refused: not plain data (" .. why .. ")" end
	local chunk, err = loadstring(text, "=saved data")
	if not chunk then return nil, "refused: " .. tostring(err) end
	local env = {}
	setfenv(chunk, env)
	debug.sethook(function() error("refused: the saved data takes too long to build", 2) end, "", IMP.MAX_STEPS)
	local ok, rerr = pcall(chunk)
	debug.sethook()
	if not ok then return nil, "refused: " .. tostring(rerr) end
	local v = rawget(env, name)
	if type(v) ~= "table" then return nil, "refused: " .. name .. " is not a table" end
	return v
end

---------------------------------------------------------------------------
-- Writing: a fixed order, numbers that read back equal
---------------------------------------------------------------------------

local function quote(s)
	return '"' .. s:gsub('[%c"\\]', function(c)
		if c == "\n" then return "\\n" end
		if c == "\t" then return "\\t" end
		if c == '"' or c == "\\" then return "\\" .. c end
		return ("\\%03d"):format(c:byte())
	end) .. '"'
end
IMP.quote = quote

local function number(v)
	if v ~= v then return quote("<nan>") end
	if v == math.huge or v == -math.huge then return quote("<inf>") end
	if v == math.floor(v) and math.abs(v) < 2 ^ 53 then return ("%.0f"):format(v) end
	for p = 14, 17 do
		local s = ("%." .. p .. "g"):format(v)
		if tonumber(s) == v then return s end
	end
	return ("%.17g"):format(v)
end
IMP.number = number

local function scalar(v)
	local t = type(v)
	if t == "string" then return quote(v) end
	if t == "number" then return number(v) end
	if t == "boolean" then return tostring(v) end
	return quote("<" .. t .. ">")
end

-- the keys of a table in a fixed order: 1..n as a list, then other numbers, then strings
local function keysOf(v)
	local list, nums, strs = 0, {}, {}
	while v[list + 1] ~= nil do list = list + 1 end
	for k in pairs(v) do
		local tk = type(k)
		if tk == "number" then
			if not (k >= 1 and k <= list and k == math.floor(k)) then nums[#nums + 1] = k end
		elseif tk == "string" then
			strs[#strs + 1] = k
		end
	end
	table.sort(nums)
	table.sort(strs)
	return list, nums, strs
end

local function keyText(k)
	if type(k) == "string" then
		if k:match("^[%a_][%w_]*$") and not KEYWORDS[k] and k ~= "true" and k ~= "false" and k ~= "nil" then return k end
		return "[" .. quote(k) .. "]"
	end
	return "[" .. number(k) .. "]"
end

local function inline(v)
	if type(v) ~= "table" then return scalar(v) end
	local list, nums, strs = keysOf(v)
	local parts = {}
	for i = 1, list do parts[#parts + 1] = inline(v[i]) end
	for _, k in ipairs(nums) do parts[#parts + 1] = keyText(k) .. " = " .. inline(v[k]) end
	for _, k in ipairs(strs) do parts[#parts + 1] = keyText(k) .. " = " .. inline(v[k]) end
	if #parts == 0 then return "{}" end
	return "{ " .. table.concat(parts, ", ") .. " }"
end
IMP.inline = inline

local function flat(v)
	for _, x in pairs(v) do if type(x) == "table" then return false end end
	return true
end

-- rows(path) says which tables are written on one line whatever their size
local function block(v, indent, out, rowsAt, depth)
	if type(v) ~= "table" then
		out[#out + 1] = scalar(v)
		return
	end
	if rowsAt(depth) or flat(v) and #inline(v) <= 100 then
		out[#out + 1] = inline(v)
		return
	end
	local list, nums, strs = keysOf(v)
	local inner = indent .. "\t"
	out[#out + 1] = "{\n"
	local function item(prefix, x, d)
		out[#out + 1] = inner .. prefix
		block(x, inner, out, rowsAt, d)
		out[#out + 1] = ",\n"
	end
	for i = 1, list do item("", v[i], depth .. "#") end
	for _, k in ipairs(nums) do item(keyText(k) .. " = ", v[k], depth .. "#") end
	for _, k in ipairs(strs) do item(keyText(k) .. " = ", v[k], depth .. "." .. k) end
	out[#out + 1] = indent .. "}"
end

-- "return { ... }" for a fixture: each fx.events[i], fx.snaps[i] and fx.facts[i] on one line
local ROWS = { [".events#"] = true, [".snaps#"] = true, [".facts#"] = true }
function IMP.serialize(v)
	local out = { "return " }
	block(v, "", out, function(path) return ROWS[path] == true end, "")
	out[#out + 1] = "\n"
	return table.concat(out)
end

-- WoW's own SavedVariables format ("WuberRecDB = { ... }"), as the game writes it (for tests)
local function wowValue(v, indent, out)
	if type(v) ~= "table" then
		out[#out + 1] = scalar(v)
		return
	end
	local list, nums, strs = keysOf(v)
	out[#out + 1] = "{\n"
	for i = 1, list do
		out[#out + 1] = indent .. "\t"
		wowValue(v[i], indent .. "\t", out)
		out[#out + 1] = ", -- [" .. i .. "]\n"
	end
	for _, group in ipairs({ nums, strs }) do
		for _, k in ipairs(group) do
			out[#out + 1] = indent .. "\t[" .. (type(k) == "string" and quote(k) or number(k)) .. "] = "
			wowValue(v[k], indent .. "\t", out)
			out[#out + 1] = ",\n"
		end
	end
	out[#out + 1] = indent .. "}"
end
function IMP.savedText(name, value)
	local out = { "\n", name, " = " }
	wowValue(value, "", out)
	out[#out + 1] = "\n"
	return table.concat(out)
end

---------------------------------------------------------------------------
-- Facts: one row per kind of fact
---------------------------------------------------------------------------

local function firstSnap(fx, id, test)
	for _, s in ipairs(fx.snaps) do
		if s.id == id and type(s.d) == "table" and not s.err and (not test or test(s.d)) then return s end
	end
	return nil
end

local function sortedKeys(t)
	local out = {}
	for k in pairs(t or {}) do out[#out + 1] = k end
	table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
	return out
end

local function rect(o)
	if type(o) ~= "table" then return nil end
	return { l = o.l, b = o.b, w = o.w, h = o.h }
end

local function r3(x)
	if type(x) ~= "number" then return x end
	return math.floor(x * 1000 + 0.5) / 1000
end

local BOOT = { ADDON_LOADED = true, PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true }

IMP.FACTS = {
	{ "boot", function(fx, add)
		if fx.why ~= "boot" then return end
		local order = {}
		for _, e in ipairs(fx.events) do
			if not BOOT[e.e] then break end
			order[#order + 1] = { e = e.e, a = e.a, n = e.n, db = e.db, wdb = e.wdb, li = e.li }
			if e.e == "PLAYER_ENTERING_WORLD" then break end
		end
		if #order > 0 then add("boot", "order", order) end
	end },
	-- what was there when the recorder's own file ran (session.boot: its saved data, Wuber's, Wuber itself)
	{ "boot:file", function(fx, add)
		if fx.why == "boot" and type(fx.boot) == "table" then add("boot", "file", fx.boot) end
	end },
	-- the chat channels at a boot session's PLAYER_LOGIN ("channels" snapshots): a fresh login
	-- (PLAYER_ENTERING_WORLD(true, ...)) has { n, first = seconds from PLAYER_LOGIN to the first
	-- non-empty list }; a /reload (..., true) has { n }
	{ "channels", function(fx, add)
		if fx.why ~= "boot" then return end
		local kind, login
		for _, e in ipairs(fx.events) do
			if not BOOT[e.e] then break end
			if e.e == "PLAYER_LOGIN" then login = e.t end
			if e.e == "PLAYER_ENTERING_WORLD" then
				kind = (e.a[2] == true and "reload") or (e.a[1] == true and "login") or nil
				break
			end
		end
		if not kind then return end
		local at, full
		for _, s in ipairs(fx.snaps) do
			if s.id == "channels" and type(s.d) == "table" and type(s.d.n) == "number" then
				if not at and s.why == "PLAYER_LOGIN" then at = s end
				if not full and s.d.n > 0 then full = s end
			end
		end
		if not at then return end
		if kind == "login" then
			add("channels", "login", { n = at.d.n, first = full and r3(full.t - (login or at.t)) or nil })
		else
			add("channels", "reload", { n = at.d.n })
		end
	end },
	-- whether the session has Wuber's settings ("settings" snapshot: WuberDB's scalars)
	{ "settings", function(fx, add)
		add("settings", "known", firstSnap(fx, "settings", function(d) return type(d.db) == "table" end) ~= nil)
	end },
	{ "event", function(fx, add)
		local seen = {}
		for _, e in ipairs(fx.events) do
			if type(e.e) == "string" and type(e.n) == "number" then
				seen[e.e] = seen[e.e] or {}
				seen[e.e][e.n] = true
			end
		end
		for _, name in ipairs(sortedKeys(seen)) do
			local ns = sortedKeys(seen[name])
			table.sort(ns)
			add("event", "argc:" .. name, ns)
		end
		if type(fx.unknownEvents) == "table" then
			local u = SES.copy(fx.unknownEvents)
			table.sort(u)
			add("event", "unknown", u)
		end
	end },
	{ "client", function(fx, add)
		local s = firstSnap(fx, "client", function(d) return type(d.api) == "table" end)
		if not s then return end
		local d = s.d
		for path, letter in pairs(d.api) do add("api", path, letter) end
		for _, path in ipairs(d.missing or {}) do add("api", path, "missing") end
		for k, v in pairs(d.gs or {}) do add("gs", k, v) end
		if d.build then add("build", nil, d.build) end
		if d.unitName then add("unitname", "shape", d.unitName) end
	end },
	{ "screen", function(fx, add)
		local s = firstSnap(fx, "screen", function(d) return d.sw ~= nil or type(d.ui) == "table" end)
		if not s then return end
		-- UIParent's own size now that the recorder reads it (a frame that only holds protected frames:
		-- ui.holds); a recording without it (UIParent read as protected): GetScreenWidth / GetScreenHeight
		local d, ui = s.d, type(s.d.ui) == "table" and s.d.ui or {}
		local own = type(ui.w) == "number" and type(ui.h) == "number"
		add("screen", "ui", { w = own and ui.w or d.sw, h = own and ui.h or d.sh, from = own and "UIParent" or "screen",
			uiScale = d.uiScale, useUiScale = d.useUiScale, pw = d.pw, ph = d.ph,
			prot = ui.prot == true, holds = ui.holds == true, s = ui.s, es = ui.es })
		for name, o in pairs(s.d.frames or {}) do
			if type(o) == "table" then
				add("frame", name, { rect = rect(o), strata = o.strata, lvl = o.lvl, shown = o.shown, prot = o.prot == true })
			end
		end
	end },
	{ "taxi", function(fx, add)
		local s = firstSnap(fx, "taxi", function(d) return type(d.nodes) == "table" and (d.n or 0) > 0 end)
		if not s then return end
		local d = s.d
		for _, name in ipairs({ "TaxiFrame", "FlightMapFrame" }) do
			local o = d.frames and d.frames[name]
			if type(o) == "table" and o.shown then
				add("taxi", "frame", { name = name, rect = rect(o), strata = o.strata, lvl = o.lvl, prot = o.prot == true })
				break
			end
		end
		local types, inside, zero = {}, 0, false
		for _, node in ipairs(d.nodes) do
			if type(node[2]) == "string" then types[node[2]] = true end
			local x, y = node[4], node[5]
			if type(x) == "number" and type(y) == "number" and x >= 0 and x <= 1 and y >= 0 and y <= 1 then inside = inside + 1 end
			if node[2] == "REACHABLE" and node[3] == 0 then zero = true end
		end
		add("taxi", "nodes", { n = #d.nodes, types = sortedKeys(types), inside = inside, zeroCost = zero })
		if d.has then add("taxi", "has", d.has) end
	end },
	{ "map", function(fx, add)
		local s = firstSnap(fx, "atlas", function(d) return type(d.maps) == "table" end)
		if s then
			for _, m in ipairs(s.d.maps) do
				local id = tostring(m.id)
				local a = m.art
				if type(a) == "table" then add("map", "art:" .. id, { w = a.w, h = a.h, tw = a.tw, th = a.th, tiles = a.tiles }) end
				if m.c00 or m.c11 then add("map", "world:" .. id, { c00 = m.c00, c11 = m.c11 }) end
				local kids = {}
				for _, k in ipairs(m.kids or {}) do kids[#kids + 1] = { id = k.id, rect = k.rect } end
				table.sort(kids, function(a2, b2) return (a2.id or 0) < (b2.id or 0) end)
				add("map", "kids:" .. id, kids)
			end
		end
		local m = firstSnap(fx, "map", function(d) return type(d.chain) == "table" end)
		if m then
			local chain = {}
			for _, info in ipairs(m.d.chain) do chain[#chain + 1] = { id = info.id, type = info.type } end
			add("map", "chain", chain)
		end
	end },
	{ "name", function(fx, add)
		for where, counts in pairs(fx.shapes or {}) do add("name", "shape:" .. where, counts) end
	end },
	{ "trade", function(fx, add)
		local counts, cur = {}, nil
		for _, e in ipairs(fx.events) do
			if e.e == "TRADE_SHOW" then
				counts[#counts + 1] = 0
				cur = #counts
			elseif e.e == "TRADE_CLOSED" and cur then
				counts[cur] = counts[cur] + 1
			end
		end
		if #counts > 0 then add("trade", "closed:count", counts) end
	end },
	{ "summon", function(fx, add)
		local out = {}
		local ev = fx.events
		for i, e in ipairs(ev) do
			if e.e == "CONFIRM_SUMMON" then
				local seq, last = {}, e.t
				for j = i + 1, math.min(#ev, i + 60) do
					local x = ev[j]
					seq[#seq + 1] = { x.e, r3(x.t - last) }
					last = x.t
					if x.e == "ZONE_CHANGED_NEW_AREA" or x.e == "PLAYER_ENTERING_WORLD" then break end
				end
				out[#out + 1] = seq
			end
		end
		if #out > 0 then add("summon", "arrival", out) end
	end },
	{ "leave", function(fx, add)
		local left, near = 0, 0
		for _, e in ipairs(fx.events) do
			if e.e == "GROUP_LEFT" then
				left = left + 1
				for _, x in ipairs(fx.events) do
					if x.e == "CANCEL_SUMMON" and math.abs(x.t - e.t) <= 0.2 then
						near = near + 1
						break
					end
				end
			end
		end
		if left > 0 then add("leave", "cancel_summon", { left = left, cancelNear = near }) end
	end },
	{ "reload", function(fx, add)
		if fx.why ~= "boot" then return end
		for _, e in ipairs(fx.events) do
			if e.e == "PLAYER_ENTERING_WORLD" then
				local zone = false
				for _, x in ipairs(fx.events) do
					if x.e == "ZONE_CHANGED_NEW_AREA" and x.t >= e.t and x.t - e.t <= 10 then zone = true break end
				end
				add("reload", "pew", { a = e.a, n = e.n, zone = zone })
				return
			end
		end
	end },
}

function IMP.facts(fx)
	local out = {}
	local function add(kind, key, v)
		local id = key ~= nil and (kind .. ":" .. tostring(key)) or kind
		out[#out + 1] = { id = id, q = kind, key = key, v = SES.copy(v) }
	end
	for _, row in ipairs(IMP.FACTS) do row[2](fx, add) end
	table.sort(out, function(a, b) return a.id < b.id end)
	return out
end

---------------------------------------------------------------------------
-- A session -> a fixture
---------------------------------------------------------------------------

function IMP.convert(session, source)
	local fx = SES.convert(session, source)
	if source == "sim" then
		-- the fake game's clock is fixed, but its epoch is the machine's local time: kept as a span only
		if type(fx.epoch) == "number" and type(fx.untilEpoch) == "number" then fx.span = fx.untilEpoch - fx.epoch end
		fx.epoch, fx.untilEpoch = nil, nil
	end
	fx.facts = IMP.facts(fx)
	return fx
end

function IMP.fileName(fx, source)
	local char = (type(fx.char) == "string" and fx.char ~= "") and fx.char or "unknown"
	char = char:lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
	local id = tostring(fx.id or "noid"):gsub("[^%w%-]+", "-")
	return (source or fx.source or "game") .. "-" .. id .. "-" .. char .. ".lua"
end

-- every string in a value
local function strings(v, out)
	out = out or {}
	if type(v) == "string" then
		out[#out + 1] = v
	elseif type(v) == "table" then
		for k, x in pairs(v) do
			strings(k, out)
			strings(x, out)
		end
	end
	return out
end

-- the distinct P-numbers in a value
function IMP.pnumbers(v)
	local seen, n = {}, 0
	for _, s in ipairs(strings(v)) do
		for p in (" " .. s .. " "):gmatch("%f[%w](P%d+)%f[%W]") do
			if not seen[p] then
				seen[p] = true
				n = n + 1
			end
		end
	end
	return n, seen
end

function IMP.readDeny(path)
	local text, err = IMP.read(path)
	if not text then return nil, err end
	local out = {}
	for line in text:gmatch("[^\r\n]+") do
		line = line:gsub("#.*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
		if line ~= "" then out[#out + 1] = line end
	end
	return out
end

-- nil when no string holds a denied name, else the first name found
function IMP.privacy(v, deny)
	if not deny or #deny == 0 then return nil end
	local low = {}
	for i, name in ipairs(deny) do
		local k = name:lower():gsub("[%s%-]+", " ")
		low[i] = { k, (k:gsub(" ", "-")), (k:gsub(" ", "")) }
	end
	for _, s in ipairs(strings(v)) do
		local ls = s:lower()
		for i, forms in ipairs(low) do
			for _, f in ipairs(forms) do
				if f ~= "" and ls:find(f, 1, true) then return deny[i] end
			end
		end
	end
	return nil
end

-- One saved file -> its fixtures. opts: out, source, deny (list), list (only say), write (default true).
-- Returns { { path, fx, text, pn } ... } or nil, why.
function IMP.importFile(path, opts)
	opts = opts or {}
	local text, err = IMP.read(path)
	if not text then return nil, err end
	local db, why = IMP.loadSaved(text, "WuberRecDB")
	if not db then return nil, path .. ": " .. why end
	local sessions = type(db.sessions) == "table" and db.sessions or {}
	local done = {}
	local source = opts.source or "game"
	for i, s in ipairs(sessions) do
		if type(s) == "table" then
			local fx = IMP.convert(s, source)
			local name = IMP.fileName(fx, source)
			local pn = IMP.pnumbers(fx)
			local item = { name = name, fx = fx, pn = pn, index = i }
			local hit = IMP.privacy(fx, opts.deny)
			if hit then
				item.refused = "a denied name is in it"
			elseif not opts.list then
				item.text = IMP.serialize(fx)
				if opts.out then
					item.path = opts.out .. "/" .. name
					if opts.write ~= false then
						local f = assert(io.open(item.path, "wb"))
						f:write(item.text)
						f:close()
					end
				end
			end
			done[#done + 1] = item
		end
	end
	return done
end

---------------------------------------------------------------------------
-- The command line
---------------------------------------------------------------------------

local function main(argv, say)
	local print = say or print
	local o = { out = "tests/fixtures/rec", source = "game" }
	local i = 1
	while i <= #argv do
		local a = argv[i]
		if a == "--list" then o.list = true
		elseif a == "--wtf" or a == "--file" or a == "--out" or a == "--source" or a == "--deny" then
			o[a:sub(3)] = argv[i + 1]
			i = i + 1
		else
			print("unknown argument: " .. tostring(a))
			return 2
		end
		i = i + 1
	end
	if o.source ~= "game" and o.source ~= "sim" then
		print("--source is game or sim")
		return 2
	end
	local deny
	if o.deny then
		local err
		deny, err = IMP.readDeny(o.deny)
		if not deny then
			print(tostring(err))
			return 2
		end
	end
	local files = {}
	if o.file then
		files[1] = { path = o.file }
	else
		files = IMP.findFiles(o.wtf or IMP.DEFAULT_WTF)
	end
	if #files == 0 then
		print("no WuberRec.lua found")
		return 0
	end
	local code = 0
	for _, f in ipairs(files) do
		local done, err = IMP.importFile(f.path, { out = (o.out:gsub("\\", "/"):gsub("/+$", "")), source = o.source, deny = deny, list = o.list })
		if not done then
			print(err)
			code = 1
		else
			print(f.path .. ": " .. #done .. " session(s)")
			for _, it in ipairs(done) do
				local fx = it.fx
				local what = ("  %s: %s, %d events, %d snapshots, %d P-numbers"):format(it.name, tostring(fx.why), #fx.events, #fx.snaps, it.pn)
				if it.refused then
					what = what .. " - REFUSED: " .. it.refused
					code = 1
				elseif it.path then
					what = what .. " - wrote " .. it.path
				end
				print(what)
			end
		end
	end
	return code
end
IMP.main = main

if args[1] == "--lib" then return IMP end
os.exit(main(args))
