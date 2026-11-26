-- tools/taint.lua: read the game's taint.log and list what the game blocked, and which names are
-- not yet on tools/forbidden.lua. Read-only: it never writes anywhere (least of all the game folder).
--
--   lua5.1 tools/taint.lua <taint.log> [AddOns folder]
--   e.g. lua5.1 tools/taint.lua \
--          "/c/Program Files (x86)/World of Warcraft/_forever_/Logs/taint.log"
--
-- taint.log (turn it on in game with /console taintLog 1; the game writes it in
-- World of Warcraft\_forever_\Logs\taint.log and starts it again at the next game start, so copy it
-- first) gives each blocked action as "An action was blocked because of taint from <Addon> - <function>"
-- plus the Lua stack. This client leaves <function> empty (the popup says UNKNOWN()), so the tool
-- reads the addon's line at the top of the stack (from the AddOns folder: by default the one next to
-- the Logs folder, i.e. the installed copy) and lists the event and API names on it as candidates.
-- "Execution tainted by" lines are only notes (no popup) and are just counted.
--
-- Prints one block per place (addon file:line) and, at the end, the candidates not on the list with
-- a ready line for tools/forbidden.lua. Check each by hand before adding it: a candidate is only a
-- name on the line that was blocked. Exit code 0 (2 on a usage error).
--   tests: tests/tools/taint_test.lua (loadfile(...)("--lib") gives the API)

local T = {}
T.FRAMES = 3 -- stack lines inside the addon read per blocked action

local function readLines(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local s = f:read("*a")
	f:close()
	local out = {}
	for line in (s:gsub("\r\n", "\n") .. "\n"):gmatch("([^\n]*)\n") do out[#out + 1] = line end
	return out
end
T.readLines = readLines

-- the blocked actions in a taint.log's lines: { { at, addon, fn, file, line, head }, ... };
-- notes = how many "Execution tainted" lines
function T.parse(lines)
	local out, notes, cur = {}, 0, nil
	for _, raw in ipairs(lines) do
		local at, rest = raw:match("^(%d+/%d+ [%d:%.]+)  (.*)$")
		if at then
			if rest:match("^%s") then
				-- a stack line of the entry above: the first one inside that addon is where it happened;
				-- the next few (a wrapper such as pcall(frame.RegisterEvent, frame, event) hides the name)
				local path = rest:match("^%s*(Interface[/\\]AddOns[/\\]%S+)")
				if cur and path and #cur.frames < T.FRAMES then
					path = path:gsub("\\", "/")
					local addon, file, n = path:match("^Interface/AddOns/([^/]+)/(.-):(%d+)")
					if addon == cur.addon then
						cur.frames[#cur.frames + 1] = { file = file, line = tonumber(n) }
						if not cur.file then cur.file, cur.line = file, tonumber(n) end
					end
				end
			else
				cur = nil
				local addon = rest:match("blocked.-taint from ([%w_%-]+)") or rest:match("AddOn '([^']+)' tried to call")
				if addon then
					local fn = rest:match(" %- ([%w_%.:]+)%(%)%s*$") or rest:match("protected function '([%w_%.:]+)%(%)'")
					if fn == "UNKNOWN" then fn = nil end
					cur = { at = at, addon = addon, fn = fn, head = rest, frames = {} }
					out[#out + 1] = cur
				elseif rest:find("Execution tainted by", 1, true) or rest:find("Global variable", 1, true) then
					notes = notes + 1
				end
			end
		end
	end
	return out, notes
end

-- the names on one line of Lua that could be what was blocked: quoted EVENT_NAMES, and calls whose
-- last part starts with a capital (C_Club.SendCharacterInvitation, f:RegisterAllEvents, CastSpellByName),
-- leaving out the addon's own tables (W.On, L.On, DR.Open: a prefix of capitals only, or ending in Mod)
local OWN = { self = true }
-- the carriers: the event name they are given is the candidate, not they
local CARRIER = { RegisterEvent = true, RegisterUnitEvent = true, UnregisterEvent = true, CreateFrame = true,
	SetScript = true, HookScript = true }
function T.candidates(src)
	local out, seen = {}, {}
	local function add(name, kind)
		if not seen[name] then seen[name] = true out[#out + 1] = { name = name, kind = kind } end
	end
	if not src then return out end
	local code = src:gsub("%-%-.*$", "")
	for ev in code:gmatch("[\"']([A-Z][A-Z0-9_]+_[A-Z0-9_]+)[\"']") do add(ev, "event") end
	for full in code:gmatch("([%a_][%w_%.:]*)%s*%(") do
		local prefix, sep, last = full:match("^(.-)([%.:]?)([%a_][%w_]*)$")
		if last:match("^%u") and not CARRIER[last] and not (prefix ~= "" and (prefix:match("^%u+$") or prefix:match("Mod$") or OWN[prefix])) then
			if sep == ":" then add(last, "method")
			elseif prefix ~= "" then add(prefix .. "." .. last, "api")
			else add(last, "api") end
		end
	end
	return out
end

-- name -> true for every name on the list (an api's dotted path too)
function T.listed(list)
	local on = {}
	for _, f in ipairs(list or {}) do
		on[f.name] = true
		if f.path then on[table.concat(f.path, ".")] = true end
	end
	return on
end

-- the report: lines to print
function T.report(entries, notes, list, readSource)
	local on, out, places, order = T.listed(list), {}, {}, {}
	for _, e in ipairs(entries) do
		local key = e.addon .. "/" .. (e.file and (e.file .. ":" .. e.line) or ((e.fn or "?") .. "()"))
		local p = places[key]
		if not p then
			p = { key = key, e = e, n = 0 }
			places[key] = p
			order[#order + 1] = p
		end
		p.n = p.n + 1
	end
	out[#out + 1] = ("taint.log: %d blocked action%s at %d place%s; %d taint note%s (no popup)"):format(#entries,
		#entries == 1 and "" or "s", #order, #order == 1 and "" or "s", notes, notes == 1 and "" or "s")
	local missing, missSeen, blind = {}, {}, 0
	for _, p in ipairs(order) do
		local e = p.e
		out[#out + 1] = ""
		out[#out + 1] = ("%s x%d (first %s): %s"):format(p.key, p.n, e.at, e.fn and (e.fn .. "()") or "function not named (UNKNOWN())")
		local cands = {}
		if e.fn then
			local last = e.fn:match("([%w_]+)$")
			cands[1] = { name = e.fn:gsub(":", "."), kind = e.fn:find(":", 1, true) and "method" or "api", short = last }
		end
		for _, fr in ipairs(e.frames or {}) do
			local src = readSource and readSource(e.addon, fr.file, fr.line)
			out[#out + 1] = ("  at %s:%d%s"):format(fr.file, fr.line, src and (": " .. (src:gsub("^%s+", ""))) or "")
			for _, c in ipairs(T.candidates(src)) do cands[#cands + 1] = c end
		end
		if #cands == 0 then blind = blind + 1 end
		for _, c in ipairs(cands) do
			local short = c.short or c.name:match("([%w_]+)$")
			local listed = on[c.name] or on[short]
			out[#out + 1] = ("  %s %s (%s)"):format(listed and "listed " or "NEW    ", c.name, c.kind)
			if not listed and not missSeen[c.name] then
				missSeen[c.name] = true
				missing[#missing + 1] = { c = c, short = short, where = p.key }
			end
		end
	end
	out[#out + 1] = ""
	if blind > 0 then
		out[#out + 1] = ("%d place%s with no name to read (the code changed since, or the name is a variable): read the stack"
			.. " in taint.log, or give the AddOns folder of the build that wrote it."):format(blind, blind == 1 and "" or "s")
	end
	if #missing == 0 then
		out[#out + 1] = #entries == 0 and "Nothing was blocked." or "No new name found: every candidate is on tools/forbidden.lua."
	else
		out[#out + 1] = "Not on tools/forbidden.lua yet (check each by hand; add only what the game really blocks):"
		for _, m in ipairs(missing) do
			local c = m.c
			local path = ""
			if c.kind == "api" then
				local parts = {}
				for part in c.name:gmatch("[^%.]+") do parts[#parts + 1] = ("%q"):format(part) end
				path = " path = { " .. table.concat(parts, ", ") .. " },"
			end
			out[#out + 1] = ("\t{ name = %q, kind = %q,%s why = \"taint.log: blocked at %s\" },"):format(m.short, c.kind, path, m.where)
		end
	end
	return out
end

if ... == "--lib" then return T end

local logPath, addonsDir = arg and arg[1], arg and arg[2]
if not logPath or logPath == "-h" or logPath == "--help" then
	print("usage: lua5.1 tools/taint.lua <taint.log> [AddOns folder]")
	os.exit(2)
end
local lines = readLines(logPath)
if not lines then
	print("tools/taint.lua: cannot read " .. logPath)
	os.exit(2)
end
local root = ((arg[0] or "tools/taint.lua"):gsub("\\", "/"):match("^(.*)/tools/[^/]*$")) or "."
local chunk = loadfile(root .. "/tools/forbidden.lua")
local list = chunk and chunk() or {}
if not addonsDir then
	local logs = logPath:gsub("\\", "/"):match("^(.*)/[^/]*$")
	addonsDir = logs and (logs .. "/../Interface/AddOns") or nil
end
local cache = {}
local function readSource(addon, file, n)
	if not addonsDir then return nil end
	local p = addonsDir .. "/" .. addon .. "/" .. file
	if cache[p] == nil then cache[p] = readLines(p) or false end
	return cache[p] and cache[p][n] or nil
end
local entries, notes = T.parse(lines)
for _, l in ipairs(T.report(entries, notes, list, readSource)) do print(l) end
os.exit(0)
