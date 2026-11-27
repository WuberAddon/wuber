-- tools/rec/gen-data.lua: writes Data.lua, the data file of the developer-only in-game recorder addon
-- WuberRec, from Wuber's own source (the files listed in Wuber/Wuber.toc, read from the repo root).
--
--   lua5.1 tools/rec/gen-data.lua [--check] [--out <path>]
--   default out: lab/WuberRec/Data.lua (the folder must exist)
--   --check  regenerate in memory; exit 1 with one line when the file on disk differs, else 0
--   exit 1 too (nothing written) when Wuber's code names anything tools/forbidden.lua lists
--
-- What it reads (comments never count; strings do):
--   EVENTS      first argument of W.On("X"), RegisterEvent / RegisterUnitEvent with a literal name, and the
--               literal list of a loop that feeds W.On(var) (for _, ev in ipairs({ ... }) do W.On(ev, ...))
--   FIRES       the same for W.Listen / W.Fire (Wuber's own message names)
--   PREFIXES    every RegisterAddonMessagePrefix argument, constants resolved from their definitions
--   GS          ERR_* names, and other all-capitals names read through rawget(_G, "NAME")
--   FRAMES      CreateFrame(type, "WuberX", ...), makeSecure("WuberX") and advertButton("WuberX");
--               true when created from a Secure*Template (every Secure.lua button is)
--   GAME_FRAMES the game's frames read: UIParent, Minimap, names ending Frame / _FRAME, a few fixed ones,
--               the HUD table of UI/Toasts.lua, and <prefix>1 for a _G["Prefix" .. n] read
--   API         every other game global read (check.lua's bytecode reader: tools/check.lua --lib, so the
--               names are exactly the globals it finds) minus Lua 5.1's own and Wuber's, plus rawget(_G, "X")
--               names, C_Xxx.Member / Enum.Xxx paths (also through a local alias of the namespace) and the
--               members of ChatFrameUtil, TooltipDataProcessor and Constants
--   MAPS        the uiMapIDs written in UI/Rider/WorldMap.lua (AZEROTH, CONT_MAPS) and Core/Flights.lua
-- Frames and global strings are listed in their own lists, not again in API.
-- No date and no git hash in the output, so --check is stable.
--   tests: tests/rec/data_test.lua (loadfile(...)("--lib") gives the API: G.generate(root) -> text, data)

local G = {}
G.DEFAULT_OUT = "lab/WuberRec/Data.lua"

local LUA51 = {}
for n in ([[_G _VERSION arg assert collectgarbage coroutine debug dofile error gcinfo getfenv getmetatable io ipairs
	load loadfile loadstring math module newproxy next os package pairs pcall print rawequal rawget rawset require
	select setfenv setmetatable string table tonumber tostring type unpack xpcall]]):gmatch("%S+") do LUA51[n] = true end
local OTHER_ADDONS = { "^Wuber", "^RitualRides", "^GigaLocks", "^OpenMap" }
local FIXED_FRAMES = { UIParent = true, Minimap = true, MinimapCluster = true, GameTooltip = true,
	TradeFrameTradeButton = true }
local NOT_FRAMES = { CreateFrame = true, FCF_GetCurrentChatFrame = true } -- functions that end in Frame
local NAMESPACES = { "ChatFrameUtil", "TooltipDataProcessor", "Constants" }

local function readAll(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local s = f:read("*a")
	f:close()
	return s
end

-- the source with comments blanked (newlines kept); strings stay
local function longEnd(src, s, eqs)
	local _, e = src:find("]" .. eqs .. "]", s, true)
	return e or #src
end
local function code(src)
	local out, i, n = {}, 1, #src
	while i <= n do
		local s = src:find("[%-\"'%[]", i)
		if not s then out[#out + 1] = src:sub(i) break end
		out[#out + 1] = src:sub(i, s - 1)
		local c, e = src:sub(s, s), s
		if c == "-" and src:sub(s + 1, s + 1) == "-" then
			local eqs = src:match("^%[(=*)%[", s + 2)
			e = eqs and longEnd(src, s + 2, eqs) or ((src:find("\n", s + 2, true) or n + 1) - 1)
			out[#out + 1] = (src:sub(s, e):gsub("[^\n]", ""))
		elseif c == "\"" or c == "'" then
			e = s + 1
			while e <= n do
				e = src:find("[\\\n" .. c .. "]", e) or n + 1
				if src:sub(e, e) ~= "\\" then break end
				e = e + 2
			end
			out[#out + 1] = src:sub(s, e)
		elseif c == "[" and src:match("^%[=*%[", s) then
			e = longEnd(src, s, src:match("^%[(=*)%[", s))
			out[#out + 1] = src:sub(s, e)
		else
			out[#out + 1] = c
		end
		i = e + 1
	end
	return table.concat(out)
end
G.code = code

local function strings(text)
	local out = {}
	for s in text:gmatch("\"([^\"\n]*)\"") do out[#out + 1] = s end
	return out
end

-- the literal events/messages a call takes: W.On("X" ... and the list of the loop feeding W.On(var ...)
local function callNames(src, fn, into)
	for name in src:gmatch(fn .. "%(%s*\"([^\"\n]+)\"") do into[name] = true end
	for pos, var in src:gmatch("()" .. fn .. "%(%s*([%a_][%w_]*)%s*,") do
		local best
		for fpos, v, list in src:gmatch("()for%s+[%w_]+%s*,%s*([%w_]+)%s+in%s+ipairs%(%s*(%b{})%s*%)%s*do") do
			if fpos < pos and v == var then best = list end
		end
		for _, s in ipairs(strings(best or "")) do into[s] = true end
	end
end

local function sortedKeys(set)
	local out = {}
	for k in pairs(set) do out[#out + 1] = k end
	table.sort(out)
	return out
end

local function matchesAny(name, pats)
	for _, p in ipairs(pats) do if name:find(p) then return true end end
	return false
end

local function isFrameName(name)
	if NOT_FRAMES[name] then return false end
	return FIXED_FRAMES[name] or name:find("Frame$") or name:find("_FRAME$") or false
end

-- (root, opts) -> text, data. opts.forbidden: list as tools/forbidden.lua (default: read from root).
-- Returns nil, message when Wuber names a forbidden event or function.
function G.generate(root, opts)
	opts = opts or {}
	local C = assert(loadfile(root .. "/tools/check.lua"))("--lib")
	local toc = assert(readAll(root .. "/Wuber/Wuber.toc"), "no Wuber/Wuber.toc")
	local version = toc:match("##%s*Version:%s*([^\r\n]+)") or "?"
	version = version:gsub("%s+$", "")
	local files = assert(C.tocFiles(root))
	local raw, src = {}, {}
	for _, f in ipairs(files) do
		if f:match("%.lua$") then
			local s = assert(readAll(root .. "/Wuber/" .. f), "cannot read " .. f)
			raw[f], src[f] = s, code(s)
		end
	end
	local order = {}
	for _, f in ipairs(files) do if src[f] then order[#order + 1] = f end end
	local all = {}
	for _, f in ipairs(order) do all[#all + 1] = src[f] end
	all = table.concat(all, "\n")

	-- events and Wuber's own messages
	local events, fires = {}, {}
	for _, f in ipairs(order) do
		local s = src[f]
		callNames(s, "W%.On", events)
		callNames(s, "W%.Listen", fires)
		callNames(s, "W%.Fire", fires)
		for name in s:gmatch("Register[%a]*Event[^\n\"]-\"([A-Z][A-Z0-9_]+)\"") do events[name] = true end
	end

	-- prefixes
	local prefixes = {}
	local function resolve(arg, file)
		local lit = arg:match("^\"([^\"]*)\"$")
		if lit then return lit end
		local v = src[file]:match("local%s+" .. arg:gsub("%.", "%%.") .. "%s*=%s*\"([^\"]*)\"")
		if v then return v end
		return all:match("%f[%w_]" .. arg:gsub("%.", "%%.") .. "%s*=%s*\"([^\"]*)\"")
	end
	for _, f in ipairs(order) do
		local s = src[f]
		local args = {}
		for a in s:gmatch("RegisterAddonMessagePrefix%s*,%s*([%w_.\"]+)%s*%)") do args[#args + 1] = a end
		for a in s:gmatch("RegisterAddonMessagePrefix%s*%(%s*([%w_.\"]+)%s*%)") do args[#args + 1] = a end
		for _, a in ipairs(args) do
			local v = resolve(a, f)
			if not v then return nil, "cannot resolve the addon message prefix " .. a .. " in " .. f end
			prefixes[v] = true
		end
	end

	-- global strings, frames, API
	local gs, gameFrames, api = {}, {}, {}
	local reads = C.check({ root = root, legacy = C.readLegacy(root .. "/tools/check-legacy.txt") }).info.reads
	local function addGlobal(name)
		if LUA51[name] or matchesAny(name, OTHER_ADDONS) then return end
		if name:find("^ERR_[A-Z0-9_]+$") then gs[name] = true
		elseif isFrameName(name) then gameFrames[name] = true
		else api[name] = true end
	end
	for name in pairs(reads) do addGlobal(name) end
	for name in all:gmatch("%f[%w_](ERR_[A-Z0-9_]+)") do gs[name] = true end
	for name in all:gmatch("rawget%(%s*_G%s*,%s*\"([%w_]+)\"%s*%)") do
		if not (LUA51[name] or matchesAny(name, OTHER_ADDONS)) then
			if name:find("^[A-Z][A-Z0-9_]+$") and not name:find("^ERR_") and not isFrameName(name) then
				gs[name] = true
				api[name] = nil
			else
				addGlobal(name)
			end
		end
	end
	for name in all:gmatch("%f[%w_]_G%[\"([%w_]+)\"%]") do addGlobal(name) end
	for prefix in all:gmatch("_G%[\"([%a_]+)\"%s*%.%.") do gameFrames[prefix .. "1"] = true end
	local hud = src["UI/Toasts.lua"] and src["UI/Toasts.lua"]:match("HUD%s*=%s*{.-names%s*=%s*(%b{})")
	for _, s in ipairs(strings(hud or "")) do gameFrames[s] = true end
	for _, n in ipairs(sortedKeys(gs)) do api[n] = nil end

	-- namespaces: C_Xxx.Member, Enum.Xxx[.Yyy], and members read through a local alias of one
	local function member(ns, m)
		api[ns] = true
		api[ns .. "." .. m] = true
	end
	for _, f in ipairs(order) do
		local s = src[f]
		for ns, m in s:gmatch("%f[%w_](C_[%w]+)%.(%u[%w_]*)") do member(ns, m) end
		for ns, m in s:gmatch("%f[%w_](C_[%w]+):(%u[%w_]*)") do member(ns, m) end
		for _, ns in ipairs(NAMESPACES) do
			for m in s:gmatch("%f[%w_]" .. ns .. "%.(%u[%w_]*)") do member(ns, m) end
		end
		for a, b in s:gmatch("%f[%w_]Enum%.([%a_][%w_]*)%.?([%a_]?[%w_]*)") do
			api.Enum, api["Enum." .. a] = true, true
			if b ~= "" then api["Enum." .. a .. "." .. b] = true end
		end
		local alias = {}
		for var, ns in s:gmatch("local%s+([%a_][%w_]*)%s*=%s*rawget%(%s*_G%s*,%s*\"(C_[%w]+)\"%s*%)") do alias[var] = ns end
		for var, ns in s:gmatch("local%s+([%a_][%w_]*)%s*=%s*(C_[%w]+)%f[^%w_]") do alias[var] = ns end
		for var, ns in pairs(alias) do
			for m in s:gmatch("%f[%w_]" .. var .. "%.(%u[%w_]*)") do member(ns, m) end
		end
	end

	-- frames Wuber creates
	local frames = {}
	local function addFrame(name, secure)
		if name:find("^Wuber") then frames[name] = frames[name] or (secure and true or false) end
		if secure then frames[name] = true end
	end
	for _, f in ipairs(order) do
		local s = src[f]
		for name, rest in s:gmatch("CreateFrame%(%s*\"[%a]+\"%s*,%s*\"([%w_]+)\"([^\n]*)") do
			addFrame(name, rest:find("\"Secure[%w]*Template\"") ~= nil)
		end
		if f == "UI/Secure.lua" then
			for name in s:gmatch("makeSecure%(%s*\"([%w_]+)\"") do addFrame(name, true) end
			for name in s:gmatch("advertButton%(%s*\"([%w_]+)\"") do addFrame(name, true) end
		end
	end

	-- map ids
	local maps = {}
	local wm = src["UI/Rider/WorldMap.lua"] or ""
	for id in (wm:match("CONT_MAPS%s*=%s*(%b{})") or ""):gmatch("=%s*(%d+)") do maps[tonumber(id)] = true end
	local az = wm:match("AZEROTH%s*=%s*(%d+)")
	if az then maps[tonumber(az)] = true end
	for id in (src["Core/Flights.lua"] or ""):gmatch("%f[%w_]add%(%s*(%d+)%s*%)") do maps[tonumber(id)] = true end

	-- forbidden: fail, never write
	local forbidden = opts.forbidden or C.readForbidden(root) or {}
	for _, fb in ipairs(forbidden) do
		local path = fb.path and table.concat(fb.path, ".") or fb.name
		if (fb.kind == "event" and events[fb.name]) or (fb.kind ~= "event" and (api[path] or api[fb.name])) then
			return nil, "Wuber names " .. fb.name .. ", which this client forbids to addons (tools/forbidden.lua)"
		end
	end

	local data = { from = "Wuber " .. version, events = sortedKeys(events), fires = sortedKeys(fires),
		prefixes = sortedKeys(prefixes), gs = sortedKeys(gs), frames = {}, gameFrames = sortedKeys(gameFrames),
		api = sortedKeys(api), maps = {} }
	for _, n in ipairs(sortedKeys(frames)) do data.frames[#data.frames + 1] = { n, frames[n] } end
	for id in pairs(maps) do data.maps[#data.maps + 1] = id end
	table.sort(data.maps)
	return G.format(data), data
end

-- the Data.lua text: one wrapped block per list, about 110 columns
local function wrap(items, indent)
	local lines, cur = {}, indent
	for i, it in ipairs(items) do
		local piece = it .. (i < #items and "," or "")
		if #cur > #indent and #cur + 1 + #piece > 110 then
			lines[#lines + 1] = cur
			cur = indent .. piece
		else
			cur = (#cur > #indent) and (cur .. " " .. piece) or (cur .. piece)
		end
	end
	if #cur > #indent then lines[#lines + 1] = cur end
	return table.concat(lines, "\n")
end

function G.format(d)
	local out = { "-- GENERATED by tools/rec/gen-data.lua from " .. d.from .. " (## Version in Wuber.toc). Do not edit:",
		"-- run the generator again (tools/rec/gen-data.lua --check says when this file is stale).",
		"local _, R = ...", "R.DATA_FROM = " .. string.format("%q", d.from) }
	local function list(name, items)
		out[#out + 1] = "R." .. name .. " = {"
		out[#out + 1] = wrap(items, "\t")
		out[#out + 1] = "}"
	end
	local function quoted(t)
		local o = {}
		for i, s in ipairs(t) do o[i] = string.format("%q", s) end
		return o
	end
	list("EVENTS", quoted(d.events))
	list("FIRES", quoted(d.fires))
	list("PREFIXES", quoted(d.prefixes))
	list("GS", quoted(d.gs))
	local fr = {}
	for i, f in ipairs(d.frames) do
		fr[i] = "{ " .. string.format("%q", f[1]) .. (f[2] and ", true" or "") .. " }"
	end
	list("FRAMES", fr)
	list("GAME_FRAMES", quoted(d.gameFrames))
	list("API", quoted(d.api))
	local m = {}
	for i, id in ipairs(d.maps) do m[i] = tostring(id) end
	list("MAPS", m)
	return table.concat(out, "\n") .. "\n"
end

if select("#", ...) > 0 and (...) == "--lib" then return G end

-- command line
local script = (arg and arg[0] or "tools/rec/gen-data.lua"):gsub("\\", "/")
local root = script:match("^(.*)/tools/rec/[^/]*$") or "."
local check, out = false, G.DEFAULT_OUT
local i = 1
while arg and arg[i] do
	if arg[i] == "--check" then check = true
	elseif arg[i] == "--out" then i = i + 1 out = arg[i]
	else io.stderr:write("usage: lua5.1 tools/rec/gen-data.lua [--check] [--out <path>]\n") os.exit(2) end
	i = i + 1
end
local text, data = G.generate(root)
if not text then
	io.stderr:write("gen-data: FAIL " .. tostring(data) .. "\n")
	os.exit(1)
end
if check then
	if readAll(out) == text then print("gen-data: " .. out .. " is current") os.exit(0) end
	print("gen-data: " .. out .. " is stale or missing (run tools/rec/gen-data.lua)")
	os.exit(1)
end
local f, err = io.open(out, "wb")
if not f then io.stderr:write("gen-data: cannot write " .. out .. ": " .. tostring(err) .. "\n") os.exit(1) end
f:write(text)
f:close()
print(("gen-data: %s written from %s: %d events, %d fires, %d prefixes, %d global strings, %d frames, %d game frames, %d API names, %d maps")
	:format(out, data.from, #data.events, #data.fires, #data.prefixes, #data.gs, #data.frames, #data.gameFrames, #data.api, #data.maps))
