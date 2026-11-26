-- Static checks of the developer-only recorder addon's source (WuberRec, never shipped): nothing the
-- game forbids, nothing that hooks, sends, writes cvars or changes a frame, one frame, the globals
-- it may write, Data.lua pure data, a policy line for every event, and its TOC. Comments are stripped
-- first. Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok, list = T.H, T.testOutside or T.test, T.eq, T.ok, T.list -- (testOutside: not in the behaviour transcript)

local ADDON = dofile(T.dir .. "/lib/rec_addon.lua") -- where the recorder is, and which version these tests are for
local REC_DIR = ADDON.dir()
if not ADDON.have() then
	test("rec: safety: skipped (" .. ADDON.why() .. ")", function() end)
	return
end

local ROOT = T.dir .. "/.."
local FORBIDDEN = assert(loadfile(ROOT .. "/tools/forbidden.lua"))()
local TAINT = assert(loadfile(ROOT .. "/tools/taint.lua"))("--lib")
local FILES = { "Data.lua", "Rec.lua", "Snaps.lua" }

local function read(name) return assert(T.readFile(REC_DIR .. "/" .. name), name) end

-- the source with comments blanked (strings kept, line count kept)
local function code(src)
	local out, i, n = {}, 1, #src
	while i <= n do
		local s = src:find("[%-\"'%[]", i)
		if not s then
			out[#out + 1] = src:sub(i)
			break
		end
		out[#out + 1] = src:sub(i, s - 1)
		local c = src:sub(s, s)
		local e = s
		if c == "-" and src:sub(s + 1, s + 1) == "-" then
			local eqs = src:match("^%[(=*)%[", s + 2)
			if eqs then
				local _, close = src:find("]" .. eqs .. "]", s + 2, true)
				e = close or n
			else
				e = (src:find("\n", s + 2, true) or n + 1) - 1
			end
			out[#out + 1] = (src:sub(s, e):gsub("[^\n]", ""))
		elseif c == "\"" or c == "'" then
			e = s + 1
			while e <= n do
				e = src:find("[\\\n" .. c .. "]", e) or n + 1
				local ch = src:sub(e, e)
				if ch ~= "\\" then break end
				e = e + 2
			end
			out[#out + 1] = src:sub(s, e)
		elseif c == "[" and src:match("^%[=*%[", s) then
			local eqs = src:match("^%[(=*)%[", s)
			local _, close = src:find("]" .. eqs .. "]", s, true)
			e = close or n
			out[#out + 1] = src:sub(s, e)
		else
			out[#out + 1] = c
		end
		i = e + 1
	end
	return table.concat(out)
end

-- the code without its strings too (for names that must not be called)
local function bare(src) return (code(src):gsub("%b\"\"", '""'):gsub("%b''", "''")) end

local function count(text, pattern)
	local n = 0
	for _ in text:gmatch(pattern) do n = n + 1 end
	return n
end

local function lineOf(text, pattern)
	local n = 0
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		n = n + 1
		if line:find(pattern) then return n, line end
	end
	return nil
end

---------------------------------------------------------------------------

test("rec: safety: no name on tools/forbidden.lua in any WuberRec file (check.lua's scan)", function()
	ok(#FORBIDDEN > 0, "the forbidden list")
	for _, f in ipairs(FILES) do
		local hits = T.CHECK.scanForbidden(read(f), FORBIDDEN)
		local what = {}
		for _, h in ipairs(hits) do what[#what + 1] = f .. ":" .. h.line .. " " .. h.name end
		eq(#hits, 0, list(what))
	end
end)

test("rec: safety: no line names a call or event taint.lua would flag (tools/taint.lua candidates vs the list)", function()
	local on = TAINT.listed(FORBIDDEN)
	local n = 0
	for _, f in ipairs(FILES) do
		local i = 0
		for line in (code(read(f)) .. "\n"):gmatch("([^\n]*)\n") do
			i = i + 1
			for _, c in ipairs(TAINT.candidates(line)) do
				n = n + 1
				local short = c.name:match("([%w_]+)$")
				ok(not on[c.name] and not on[short], f .. ":" .. i .. " " .. c.name .. " is on the forbidden list")
			end
		end
	end
	ok(n > 50, "candidates were found to check: " .. n)
end)

local DENY_NAMES = { "hooksecurefunc", "HookScript", "seterrorhandler", "SetCVar", "RegisterAllEvents", "SendChatMessage",
	"SendAddonMessage", "RunMacroText", "setfenv", "loadstring", "rawset", "debug", "ReloadUI", "TakeTaxiNode", "AcceptGroup",
	"ConfirmSummon", "InviteUnit", "LeaveParty", "InitiateTrade", "AcceptTrade", "SetTradeMoney", "StaticPopup_Show" }
local DENY_METHODS = { "Show", "Hide", "SetPoint", "ClearAllPoints", "SetParent", "SetAttribute", "SetShown", "SetAlpha", "SetSize",
	"SetWidth", "SetHeight", "SetFrameStrata", "SetFrameLevel", "EnableMouse", "Click", "SetScale", "SetAllPoints", "SetText",
	"SetMovable", "StartMoving", "Raise", "Lower", "SetMapID", "SetOwner", "UnregisterAllEvents" }

test("rec: safety: Rec.lua and Snaps.lua never hook, send, set a cvar, run a macro or change a frame", function()
	for _, f in ipairs({ "Rec.lua", "Snaps.lua" }) do
		local src = bare(read(f))
		for _, name in ipairs(DENY_NAMES) do
			local n, line = lineOf(src, "%f[%w_]" .. name .. "%f[^%w_]")
			ok(not n, f .. ":" .. tostring(n) .. " names " .. name .. ": " .. tostring(line))
		end
		ok(not src:find("C_ChatInfo%s*%.%s*Send"), f .. ": C_ChatInfo.Send...")
		for _, m in ipairs(DENY_METHODS) do
			-- frame:Show( and pcall(frame.Show, ...) alike
			local n, line = lineOf(src, "[%.:]%s*" .. m .. "%f[^%w_]")
			ok(not n, f .. ":" .. tostring(n) .. " calls " .. m .. ": " .. tostring(line))
		end
	end
end)

test("rec: safety: one frame (CreateFrame once: a plain Frame, no name, no template), one SetScript (OnEvent, on it)", function()
	local rec, snaps = bare(read("Rec.lua")), bare(read("Snaps.lua"))
	eq(count(rec, "%f[%w_]CreateFrame%f[^%w_]"), 1, "CreateFrame in Rec.lua")
	eq(count(snaps, "%f[%w_]CreateFrame%f[^%w_]"), 0, "CreateFrame in Snaps.lua")
	local codeRec = code(read("Rec.lua"))
	local _, line = lineOf(codeRec, "%f[%w_]CreateFrame%f[^%w_]")
	ok(line:find('pcall%(CreateFrame, "Frame"%)'), "CreateFrame(\"Frame\") and nothing more: " .. line)
	eq(count(rec, "%f[%w_]SetScript%f[^%w_]"), 1, "SetScript in Rec.lua")
	eq(count(snaps, "%f[%w_]SetScript%f[^%w_]"), 0, "SetScript in Snaps.lua")
	local _, sline = lineOf(codeRec, "%f[%w_]SetScript%f[^%w_]")
	ok(sline:find('pcall%(f%.SetScript, f, "OnEvent", onEvent%)'), "only OnEvent, on its own frame: " .. sline)
	-- the frame it made is the only one it registers events on
	for _, l in (codeRec .. "\n"):gmatch("()([^\n]*)\n") do
		if l:find("RegisterEvent") then
			ok(l:find("pcall%(frame%.RegisterEvent, frame,") or l:find("pcall%(f%.RegisterEvent, f,") or l:find("pcall%(frame%.UnregisterEvent, frame,")
				or l:find("frame%.IsEventRegistered"), "events only on its own frame: " .. l)
		end
	end
end)

-- every global a chunk writes (Lua 5.1 bytecode, SETGLOBAL), through check.lua's own reader when it is
-- reachable, else none (the text scan below covers it)
local function findUp(fn, name, seen)
	seen = seen or {}
	if seen[fn] then return nil end
	seen[fn] = true
	for i = 1, 200 do
		local n, v = debug.getupvalue(fn, i)
		if not n then break end
		if n == name and type(v) == "function" then return v end
		if type(v) == "function" then
			local got = findUp(v, name, seen)
			if got then return got end
		end
	end
	return nil
end

local function setGlobals(src, chunkName)
	local undump, walk
	for _, f in pairs(T.CHECK) do
		if type(f) == "function" then
			undump = undump or findUp(f, "undump")
			walk = walk or findUp(f, "walk")
		end
	end
	if not (undump and walk) then return nil end
	local chunk = assert(loadstring(src, "=" .. chunkName))
	local out = {}
	local function each(p)
		walk(p, function(kind, name)
			if kind == "setglobal" then out[name] = true end
		end)
		for _, q in ipairs(p.p) do each(q) end
	end
	each(undump(string.dump(chunk)))
	return out
end

test("rec: safety: no global written but WuberRecDB, SLASH_WUBERREC1/2 and SlashCmdList.WUBERREC", function()
	local allowed = { WuberRecDB = true, SLASH_WUBERREC1 = true, SLASH_WUBERREC2 = true }
	local any = false
	for _, f in ipairs(FILES) do
		local got = setGlobals(read(f), f)
		if got then
			any = true
			for name in pairs(got) do ok(allowed[name], f .. " writes the global " .. name) end
		end
	end
	ok(any, "check.lua's bytecode reader was reachable")
	local rec = setGlobals(read("Rec.lua"), "Rec.lua")
	ok(rec.WuberRecDB and rec.SLASH_WUBERREC1 and rec.SLASH_WUBERREC2, "it writes what it must")
	-- table fields of the game's globals: only SlashCmdList.WUBERREC
	for _, f in ipairs(FILES) do
		local src = bare(read(f))
		for target in src:gmatch("SlashCmdList%s*%.%s*([%w_]+)%s*=[^=]") do eq(target, "WUBERREC", f .. ": SlashCmdList." .. target) end
		ok(not src:find("_G%s*%[[^%]]*%]%s*=[^=]") and not src:find("_G%s*%.%s*[%w_]+%s*=[^=]"), f .. ": writes through _G")
	end
	-- and when the files run (a stub environment: no game at all), these are all it leaves behind
	local env = setmetatable({}, { __index = _G })
	local R = {}
	for _, f in ipairs(FILES) do
		local chunk = assert(loadstring(read(f), "=" .. f))
		setfenv(chunk, env)
		chunk("WuberRec", R)
	end
	local left = {}
	for k in pairs(env) do left[#left + 1] = k end
	table.sort(left)
	eq(table.concat(left, ","), "SLASH_WUBERREC1,SLASH_WUBERREC2", "globals after loading without a game")
end)

test("rec: safety: Data.lua is pure data (local _, R = ... and R.NAME = literal tables of strings, numbers and true)", function()
	local src = code(read("Data.lua"))
	local body = src:gsub("^%s*", "")
	ok(body:sub(1, #"local _, R = ...") == "local _, R = ...", "starts with local _, R = ...")
	body = body:sub(#"local _, R = ..." + 1)
	local heads = 0
	body = body:gsub("%f[%w_]R%.([%u_]+)%s*=", function(name)
		heads = heads + 1
		return "X_" .. name .. " ="
	end)
	ok(heads >= 8, "R.NAME lines: " .. heads)
	local IMP = assert(loadfile(ROOT .. "/tools/rec/import.lua"))("--lib")
	local okData, why = IMP.plainData(body)
	ok(okData, "plain data: " .. tostring(why))
	local names = bare(body):gsub('""', "")
	for word in names:gmatch("[%a_][%w_]*") do
		ok(word:match("^X_[%u_]+$") or word == "true", "a bare name in Data.lua: " .. word)
	end
	local R = {}
	local chunk = assert(loadstring(read("Data.lua"), "=Data.lua"))
	setfenv(chunk, {})
	chunk("WuberRec", R)
	local function plainValue(v, depth)
		local t = type(v)
		if t == "string" or t == "number" or v == true then return true end
		if t ~= "table" or depth > 3 then return false end
		for k, x in pairs(v) do
			if type(k) ~= "number" or not plainValue(x, depth + 1) then return false end
		end
		return true
	end
	for k, v in pairs(R) do ok(plainValue(v, 0), "R." .. k .. " is a literal") end
end)

test("rec: safety: every event in R.EVENTS has a line in R.POLICY, with known letters only", function()
	local env = setmetatable({}, { __index = _G })
	local R = {}
	for _, f in ipairs({ "Data.lua", "Rec.lua" }) do
		local chunk = assert(loadstring(read(f), "=" .. f))
		setfenv(chunk, env)
		chunk("WuberRec", R)
	end
	ok(#R.EVENTS >= 50, "events: " .. #R.EVENTS)
	for _, e in ipairs(R.EVENTS) do
		local p = R.POLICY[e]
		ok(type(p) == "string", e .. " has no line in R.POLICY")
		ok(p and not p:find("[^knxsw%-]"), e .. ": unknown letters in " .. tostring(p))
	end
	for e in pairs(R.FILTER) do ok(R.POLICY[e], "a filter without a policy: " .. e) end
	-- the default for an event with no line keeps no words
	ok(R.POLICY.CHAT_MSG_WHISPER:sub(1, 1) == "x" and R.POLICY.CHAT_MSG_SYSTEM == "s", "chat as length, system lines as game strings")
end)

test("rec: safety: the TOC: Interface 16001, never ship, optional Wuber and WuberLab, WuberRecDB, exactly its three files", function()
	local toc = read("WuberRec.toc")
	local fields, files = {}, {}
	for line in (toc .. "\n"):gmatch("([^\n]*)\n") do
		line = line:gsub("\r", ""):gsub("%s+$", "")
		local k, v = line:match("^##%s*([%w]+)%s*:%s*(.-)%s*$")
		if k then
			fields[k] = v
		elseif line ~= "" and not line:match("^#") then
			files[#files + 1] = line
		end
	end
	eq(fields.Interface, "16001")
	ok(fields.Title and fields.Title:lower():find("never ship", 1, true), "never ship in the Title: " .. tostring(fields.Title))
	local deps = {}
	for d in (fields.OptionalDeps or ""):gmatch("[^,%s]+") do deps[#deps + 1] = d end
	table.sort(deps)
	eq(table.concat(deps, ","), "Wuber,WuberLab", "OptionalDeps")
	eq(fields.SavedVariables, "WuberRecDB")
	eq(fields.SavedVariablesPerCharacter, nil)
	eq(table.concat(files, ","), "Data.lua,Rec.lua,Snaps.lua", "the files, in order")
	for _, f in ipairs(files) do ok(T.readFile(REC_DIR .. "/" .. f), f .. " exists") end
end)
