-- tools/check.lua: the restructure's static checks (REFACTOR-MAP section 6.2). Pure Lua 5.1, no
-- shell, nothing of the addon runs.
--
--   lua5.1 tools/check.lua                  FAIL lines; exit 1 on any failure
--   lua5.1 tools/check.lua --warn           also every WARN line
--   lua5.1 tools/check.lua --write-globals  (re)write tools/globals-baseline.txt (a reviewed change)
--   tests/run.lua runs it as the test "tools/check.lua passes" (loadfile(...)("--lib") gives the API)
--
-- Reads Wuber/Wuber.toc and every file it lists, compiled with loadstring and read back from
-- their Lua 5.1 bytecode (string.dump: exact locals, upvalues, globals and calls; no lexer).
-- Checks (FAIL unless marked WARN):
--  1 parse     every TOC file exists and compiles
--  2 locals    per function and per main chunk, the most locals alive at once: WARN > 150,
--              FAIL > 170 (Lua 5.1's hard limit is 200); upvalues per function: WARN > 50, FAIL > 60
--  3 globals   every global read must be in tools/globals-baseline.txt (made from the 25 files of
--              2.2.1): a new one is a lost local (named when another file has a top-level local of
--              that name) or a typo; every global write must be in the baseline too
--  4 load time a statement at a file's top level (main chunk, not inside a function) must not call
--              a function another file defines, directly or through a local function of its own
--              it calls there, except W.Module, W.Mod, W.On, W.Listen, W.OnLogin and the allow-list
--              ALLOW_LOAD (the ones that exist: REFACTOR-MAP fact 6's three, and Drive_Places')
--  5 size      a new module file (not in tools/check-legacy.txt): FAIL > 2,000 lines, WARN > 1,500 (the author 20 Nov: raised from 1,200)
--  6 modules   a new module file has exactly one W.Module("<its path with dots>", { deps }); no
--              two share a name; every dep is a module earlier in the TOC; every W.Mod("x") names
--              a module in the TOC (only once modules exist; legacy files are skipped)
--  7 forbidden no file names (outside a comment) what this client forbids to addons, as listed
--              in tools/forbidden.lua; the lab addon's files too (WUBER_LAB_DIR, else
--              lab/WuberLab in this repo; the default skipped quietly when it isn't there, a
--              WUBER_LAB_DIR that isn't there fails; "lab: N files scanned" says how many it read).
--              Strings are code: a "--" inside one starts no comment
--  8 chat      addon code sends no chat line by itself: no file names SendChatMessage outside a comment,
--              except the files of C.CHAT_ALLOW, each on at most that many lines (the one auto-reply
--              whisper, the author's rule of 21 Nov 2026: CLAUDE.md "Secure and hardware-click rules";
--              and the one whisper to the driver's own rider, the author's yes of 21 Nov 2026 22:28)
--  9 map       the world map is opened in one place: no file names ShowUIPanel, ToggleWorldMap, OpenWorldMap,
--              SetMapID or WorldMapFrame:Show outside a comment, except the files of C.MAP_ALLOW (W.Map.Open in
--              UI/Map/Map.lua), each name on at most that many lines. The fake game holds the same rule at run
--              time, and two more about frames and click scripts under the map (tests/lib/maptaint.lua)
-- 10 text sizes the size (2nd) argument of T.Text, T.SetFont and T.MeasureText holds no number literal and only
--              one of the seven names (C.SIZE_NAMES); no file but Theme/Tokens.lua names SetFont, SetFontObject or a
--              GameFont... object, except the files of C.FONT_ALLOW (each on at most that many lines, a reason beside it)
-- 11 tooltip   Wuber's tips are drawn on its own card (the frame WuberTip: T.Tip, T.TipShow in Theme/Widgets.lua): no
--              file names GameTooltip outside a comment, except the files of C.TIP_ALLOW (each that many times at
--              most, a reason beside it)

local C = {}

C.LIMITS = { localsWarn = 150, localsFail = 170, upvaluesWarn = 50, upvaluesFail = 60, sizeWarn = 1500, sizeFail = 2000 }

-- generic load-time calls every module may make
C.LOAD_OK = { ["W.Module"] = true, ["W.Mod"] = true, ["W.On"] = true, ["W.Listen"] = true, ["W.OnLogin"] = true }

-- load-time calls that reach into another file today (REFACTOR-MAP fact 6), kept as they are:
-- old file (its code wherever it lives now) -> the call made at its top level
C.ALLOW_LOAD = {
	{ old = "Net", call = "addFilters" },     -- game chat filters
	{ old = "FX", call = "hookSendStage" },   -- wraps W.SendStage (defined earlier, in Net)
	{ old = "Driver", call = "AddTab" },      -- W.UI.AddTab queues the Drive tab
	-- found by this check in step 0 (the map lists three): Drive_Places' alias table, built at
	-- load, spells each place's name with W.NormPlace (Places loads earlier; guarded)
	{ old = "Drive_Places", call = "W.NormPlace" },
	-- found when Places.lua was cut (step 2): Core.Flights' FLY.SIDE table, built at load, spells
	-- each town with W.NormPlace (Core.Places, its dependency, loads just before it)
	{ old = "Places", call = "W.NormPlace" },
	-- PST-01 part B: /wuber and /ride are registered at load only while the Gamepad UI is off (W.GamepadUI reads the style once)
	{ old = "Commands", call = "W.GamepadUI" },
}

---------------------------------------------------------------------------
-- Lua 5.1 bytecode
---------------------------------------------------------------------------

local OP = { MOVE = 0, LOADK = 1, GETUPVAL = 4, GETGLOBAL = 5, GETTABLE = 6, SETGLOBAL = 7, SETTABLE = 9, SELF = 11,
	CALL = 28, TAILCALL = 29, CLOSURE = 36 }

local function undump(b)
	local pos = 13
	local sizeInt, sizeT, sizeNum = b:byte(8), b:byte(9), b:byte(11)
	local function int(n)
		local v, mul = 0, 1
		for i = 0, n - 1 do v = v + b:byte(pos + i) * mul mul = mul * 256 end
		pos = pos + n
		return v
	end
	local function str()
		local n = int(sizeT)
		local s = n > 0 and b:sub(pos, pos + n - 2) or nil
		pos = pos + n
		return s
	end
	local function fn()
		local f = { source = str() }
		f.line = int(sizeInt)
		f.lastline = int(sizeInt)
		f.nups, f.nparams = b:byte(pos), b:byte(pos + 1)
		pos = pos + 4 -- nups, numparams, is_vararg, maxstacksize
		f.code = {}
		for i = 1, int(sizeInt) do f.code[i] = int(4) end
		f.k = {}
		for i = 1, int(sizeInt) do
			local t = b:byte(pos)
			pos = pos + 1
			if t == 1 then f.k[i] = b:byte(pos) ~= 0 pos = pos + 1
			elseif t == 3 then f.k[i] = 0 pos = pos + sizeNum -- (numbers: not needed)
			elseif t == 4 then f.k[i] = str()
			else f.k[i] = nil end
		end
		f.p = {}
		for i = 1, int(sizeInt) do f.p[i] = fn() end
		f.lines = {}
		for i = 1, int(sizeInt) do f.lines[i] = int(sizeInt) end
		f.locvars = {}
		for i = 1, int(sizeInt) do
			local name = str()
			f.locvars[i] = { name = name, s = int(sizeInt), e = int(sizeInt) }
		end
		f.upnames = {}
		for i = 1, int(sizeInt) do f.upnames[i] = str() end
		return f
	end
	return fn()
end

local function decode(i)
	local op = i % 64
	local a = math.floor(i / 64) % 256
	local c = math.floor(i / 16384) % 512
	local bb = math.floor(i / 8388608) % 512
	local bx = math.floor(i / 16384)
	return op, a, bb, c, bx
end

-- the most locals alive at once in f (its own, not its closures')
local function maxLive(f)
	local ev = {}
	for _, v in ipairs(f.locvars) do
		ev[#ev + 1] = { v.s, 1 }
		ev[#ev + 1] = { v.e, -1 }
	end
	table.sort(ev, function(x, y) if x[1] ~= y[1] then return x[1] < y[1] end return x[2] < y[2] end)
	local live, top = 0, 0
	for _, e in ipairs(ev) do
		live = live + e[2]
		if live > top then top = live end
	end
	return top
end

-- the name of local register r at pc (0-based), as luaF_getlocalname finds it
local function localName(f, r, pc)
	local n = -1
	for _, v in ipairs(f.locvars) do
		if v.s > pc then break end
		if pc < v.e then
			n = n + 1
			if n == r then return v.name end
		end
	end
	return nil
end

-- Walks f's code and calls visit(kind, name, line, pc) for each call ("call") and each
-- table read or global read ("read"), with the best symbolic name of what is read or called
-- ("W.UI.AddTab", "frame:SetScript", "hookSendStage"); nil when unknown.
local function walk(f, visit)
	local sym, kval = {}, {}
	local function K(x) return f.k[x + 1] end
	local function nameOf(r, pc) return localName(f, r, pc) or sym[r] end
	-- a constant operand: RK(x), or a register LOADK filled (past 256 constants)
	local function rk(x) if x >= 256 then return K(x - 256) end return kval[x] end
	local skip = 0
	for pc0, ins in ipairs(f.code) do
		local pc = pc0 - 1
		local op, a, b, c, bx = decode(ins)
		local line = f.lines[pc0] or f.line
		local newSym, newK
		if skip > 0 then -- CLOSURE's upvalue pseudo-instructions (MOVE/GETUPVAL 0 B): not code
			skip = skip - 1
			op = -1
		elseif op == OP.CLOSURE then
			skip = f.p[bx + 1] and f.p[bx + 1].nups or 0
		end
		if op == OP.MOVE then newSym = nameOf(b, pc)
		elseif op == OP.LOADK then newK = K(bx)
		elseif op == OP.GETGLOBAL then
			newSym = K(bx)
			visit("global", newSym, line, pc)
		elseif op == OP.SETGLOBAL then
			visit("setglobal", K(bx), line, pc)
			newSym = sym[a]
		elseif op == OP.GETUPVAL then newSym = f.upnames[b + 1]
		elseif op == OP.GETTABLE then
			local base, key = nameOf(b, pc), rk(c)
			if base and type(key) == "string" then
				newSym = base .. "." .. key
				visit("read", newSym, line, pc)
			end
		elseif op == OP.SELF then
			local base, key = nameOf(b, pc), rk(c)
			if base and type(key) == "string" then
				sym[a + 1] = base
				newSym = base .. ":" .. key
			end
		elseif op == OP.CALL or op == OP.TAILCALL then
			visit("call", nameOf(a, pc), line, pc)
		end
		-- every op that writes R(A) (all but SETGLOBAL, SETTABLE, SETUPVAL, jumps and tests)
		if op ~= -1 and op ~= OP.SETGLOBAL and op ~= OP.SETTABLE and op ~= 8 and not (op >= 22 and op <= 27) and op ~= 30
			and op ~= 34 and op ~= 35 then
			sym[a], kval[a] = newSym, newK
		end
		if op == OP.CALL or op == OP.TAILCALL then
			for r = a + 1, a + 30 do sym[r], kval[r] = nil, nil end
		end
	end
end

local function eachProto(f, fn)
	fn(f)
	for _, p in ipairs(f.p) do eachProto(p, fn) end
end

---------------------------------------------------------------------------
-- Source text: namespace aliases and definitions
---------------------------------------------------------------------------

-- local T = W.Theme / local D = W.Driver or {} / local UI = {} ... W.UI = UI  ->  T = "W.Theme"
local function aliases(src)
	local al = { W = "W", Wuber = "W" }
	local function canon(path)
		local head, rest = path:match("^([%a_][%w_]*)(.*)$")
		if head and al[head] then return al[head] .. rest end
		return nil
	end
	local empty = {}
	for line in (src .. "\n"):gmatch("([^\n]*)\n") do
		local x, rhs = line:match("^local%s+([%a_][%w_]*)%s*=%s*([%a_][%w_%.]*)%s*$")
		if not x then x, rhs = line:match("^local%s+([%a_][%w_]*)%s*=%s*([%a_][%w_%.]*)%s+or%s+{}%s*$") end
		if x and rhs and rhs:find(".", 1, true) and canon(rhs) and not al[x] then al[x] = canon(rhs) end
		local e = line:match("^local%s+([%a_][%w_]*)%s*=%s*{}%s*$")
		if e then empty[e] = true end
		local lhs, v = line:match("^([%a_][%w_%.]*)%s*=%s*([%a_][%w_]*)%s*$")
		if lhs and empty[v] and lhs:find(".", 1, true) and canon(lhs) and not al[v] then al[v] = canon(lhs) end
	end
	return al, canon
end

-- canonical names of the functions a file defines at line start (function X.y / X.y = function)
local function definitions(src, canon)
	local out = {}
	local n = 0
	for line in (src .. "\n"):gmatch("([^\n]*)\n") do
		n = n + 1
		local name = line:match("^function%s+([%a_][%w_%.:]*)%s*%(") or line:match("^([%a_][%w_%.]*)%s*=%s*function[%s%(]")
		if name and name:find("[%.:]") then
			local c = canon((name:gsub(":", ".")))
			if c then out[c] = n end
		end
	end
	return out
end

---------------------------------------------------------------------------
-- The checks
---------------------------------------------------------------------------

-- the end of the long bracket opened at `s` ("[[", "[==[") in src, or #src when unclosed
local function longEnd(src, s, eqs)
	local _, e = src:find("]" .. eqs .. "]", s + #eqs + 2, true)
	return e or #src
end

-- the source with comments blanked (line count kept), for the W.Module / W.Mod patterns; strings
-- are kept as they are, so a "--" inside one is no comment
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
			e = eqs and longEnd(src, s + 2, eqs) or ((src:find("\n", s + 2, true) or n + 1) - 1)
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
			e = longEnd(src, s, src:match("^%[(=*)%[", s))
			out[#out + 1] = src:sub(s, e)
		else
			out[#out + 1] = c
		end
		i = e + 1
	end
	return table.concat(out)
end

local function readAll(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local t = f:read("*a")
	f:close()
	return t
end

local function lines(text)
	local out = {}
	for l in ((text or "") .. "\n"):gmatch("([^\r\n]*)\r?\n") do
		l = l:gsub("^%s+", ""):gsub("%s+$", "")
		if l ~= "" and not l:match("^#") then out[#out + 1] = l end
	end
	return out
end

-- What this client forbids to addons (tools/forbidden.lua): a list of { name, kind, path, why }, or nil.
function C.readForbidden(root)
	local chunk = loadfile((root or ".") .. "/tools/forbidden.lua")
	local ok, list = pcall(chunk or error)
	return (ok and type(list) == "table") and list or nil
end

-- Every forbidden name in `src` outside comments, as a whole word: { { line = n, name = s }, ... }.
function C.scanForbidden(src, list)
	local hits, n = {}, 0
	for line in (code(src or "") .. "\n"):gmatch("([^\n]*)\n") do
		n = n + 1
		for _, f in ipairs(list or {}) do
			if line:find("%f[%w_]" .. f.name .. "%f[^%w_]") then hits[#hits + 1] = { line = n, name = f.name } end
		end
	end
	return hits
end

-- Chat from addon code (check 8). The ONLY files that may name SendChatMessage outside a comment, and on how
-- many lines. Never add a file or raise a number without the author's yes: this list is the hard rule.
C.CHAT_NAMES = { { name = "SendChatMessage" } }
C.CHAT_ALLOW = {
	["Drive/AutoReply.lua"] = 1, -- the one call: the auto-reply whisper to a player who asked in public chat
	-- the author's yes of 21 Nov 2026 22:28 ("More lines sent by themselves": build them in 2.4): one call, the
	-- greeting or the pay reminder as a whisper to the driver's own rider, inside the limits in that file's header
	["Drive/AutoLines.lua"] = 1,
	["Core/Runtime.lua"] = 1,    -- a string in the table of calls the game may refuse (W.Try's names): never a call
}
-- nil when `file` (a TOC path) may hold what `src` holds; else the line of the first name too many, how many
-- lines name it, and how many may.
function C.scanChat(file, src, allow)
	local hits = C.scanForbidden(src, C.CHAT_NAMES)
	local max = (allow or C.CHAT_ALLOW)[(tostring(file):gsub("\\", "/"))] or 0
	if #hits <= max then return nil end
	return hits[max + 1].line, #hits, max
end

-- Opening the world map (check 9). The game's Lua openers, run from addon code, can leave the map tainted (it then
-- refuses to open in a fight, or loses quest pins, until a reload). Wuber opens it in ONE function, W.Map.Open
-- (UI/Map/Map.lua), through the game's safe opener; these names may stand only there, each on at most that many lines.
C.MAP_NAMES = { { name = "ShowUIPanel" }, { name = "ToggleWorldMap" }, { name = "OpenWorldMap" }, { name = "SetMapID" },
	{ name = "WorldMapFrame:Show" } }
C.MAP_ALLOW = {
	-- W.Map.Open: the safe opener (C_Map.OpenWorldMap), and the fallback for a game without it
	["UI/Map/Map.lua"] = { OpenWorldMap = 1, ShowUIPanel = 1, SetMapID = 1 },
}
-- nil when `file` (a TOC path) may hold what `src` holds; else the line of the first name too many and the name.
function C.scanMapOpen(file, src, allow)
	local may = (allow or C.MAP_ALLOW)[(tostring(file):gsub("\\", "/"))] or {}
	local seen = {}
	for _, h in ipairs(C.scanForbidden(src, C.MAP_NAMES)) do
		seen[h.name] = (seen[h.name] or 0) + 1
		if seen[h.name] > (may[h.name] or 0) then return h.line, h.name end
	end
	return nil
end

-- The game's tooltip (check 11, design round 4). Every Wuber tip is drawn on Wuber's own card, the frame WuberTip
-- (T.Tip, T.TipShow, T.TipHide in Theme/Widgets.lua): the game's shared tooltip, its fonts and its frame are not used
-- and not changed. GameTooltip may be named only in these files, each at most that many times. Never add a file to
-- show a tip of Wuber's: call T.TipShow.
C.TIP_NAMES = { { name = "GameTooltip" } }
C.TIP_ALLOW = {
	-- the game's own unit tooltip (the mouse over a player in the world) gets one line from Wuber: the hook on the
	-- game's tooltip and the check that it is that tooltip. The tooltip stays the game's.
	["FX/Nameplates.lua"] = 4,
}
-- nil when `file` (a TOC path) may hold what `src` holds; else the line of the first name too many, how many
-- times it is named, and how many it may be.
function C.scanGameTip(file, src, allow)
	local hits = C.scanForbidden(src, C.TIP_NAMES)
	local max = (allow or C.TIP_ALLOW)[(tostring(file):gsub("\\", "/"))] or 0
	if #hits <= max then return nil end
	return hits[max + 1].line, #hits, max
end

-- Text sizes and fonts (check 10, design round 3). The theme owns the seven sizes and the font files: a call site names a
-- size ("body") and never writes a number, and no font is set except through T.SetFont (Theme/Tokens.lua).
--   a) the size (2nd) argument of T.Text, T.SetFont and T.MeasureText holds no number literal anywhere in it (13 fails,
--      so do `opts.size or 13` and `on and 12 or 13`), and every string in it is one of C.SIZE_NAMES (the older names
--      small and price are for callers outside, never at a call site)
--   b) `SetFont` (not T.SetFont), `SetFontObject` and a `GameFont...` name stand nowhere outside Theme/Tokens.lua, except
--      in the files of C.FONT_ALLOW, each on at most that many lines
C.SIZE_NAMES = { hero = true, display = true, title = true, heading = true, body = true, sub = true, caption = true }
C.SIZE_CALLS = { ["T.Text"] = true, ["T.SetFont"] = true, ["T.MeasureText"] = true }
C.SIZE_EXEMPT = { ["Theme/Tokens.lua"] = true }
-- Only where the call cannot go through T.SetFont. Never add an entry for one that can: change the call instead.
C.FONT_ALLOW = {
	-- the no-theme branch of the alert banner and its counter (the alert must show even when the theme did not
	-- load): the game's own font file on one line, four of the game's font objects as templates
	["Drive/Bell.lua"] = 5,
	-- the no-theme branch of the Drive button's label: two SetFont lines (Arial Narrow, then the addon's own file)
	["Drive/Button.lua"] = 2,
	-- puts back the game's own popup font and size it saved (o.font is the game's, never one of ours)
	["Drive/Core.lua"] = 2,
	-- the Fonts check: probes game font files one by one on a throw-away string (4 SetFont lines)
	["UI/Commands.lua"] = 4,
	-- the world-map tag labels when the theme is missing or refuses: Arial Narrow, then the game's font object
	["UI/Map/Map.lua"] = 2,
	["UI/Map/Pins.lua"] = 2,
	-- a font string made with no theme must still carry a font object (it errors on SetText without one)
	["UI/Rider/SeaRoute.lua"] = 1,
}

-- The arguments of the call whose "(" is at `open` in `src`: { { text, line }, ... } (top-level commas; strings,
-- brackets and braces respected), and the position after the closing ")" (or #src + 1 when it never closes).
local function callArgs(src, open)
	local args, depth, i, n, start = {}, 0, open, #src, open + 1
	local line = select(2, src:sub(1, open):gsub("\n", "")) + 1
	local startLine = line
	while i <= n do
		local c = src:sub(i, i)
		if c == "\n" then line = line + 1
		elseif c == "\"" or c == "'" then
			i = i + 1
			while i <= n do
				local d = src:sub(i, i)
				if d == "\\" then i = i + 1
				elseif d == c or d == "\n" then break end
				i = i + 1
			end
		elseif c == "(" or c == "[" or c == "{" then depth = depth + 1
		elseif c == ")" or c == "]" or c == "}" then
			depth = depth - 1
			if depth == 0 then
				args[#args + 1] = { text = src:sub(start, i - 1), line = startLine }
				return args, i + 1
			end
		elseif c == "," and depth == 1 then
			args[#args + 1] = { text = src:sub(start, i - 1), line = startLine }
			start = i + 1
			startLine = line
		end
		i = i + 1
	end
	return args, n + 1
end

-- The text-size findings of one file (a TOC path): { { line, why }, ... }
function C.scanTextSizes(file, src, exempt)
	local hits = {}
	if (exempt or C.SIZE_EXEMPT)[(tostring(file):gsub("\\", "/"))] then return hits end
	local text = code(src or "")
	local function judge(name, a)
		local line = a.line + select(2, a.text:match("^%s*"):gsub("\n", ""))
		local bare = a.text:gsub("\"[^\"\n]*\"", "\1"):gsub("'[^'\n]*'", "\1")
		if bare:find("%f[%w_.]%d") or bare:find("%.%d") then
			hits[#hits + 1] = { line = line, why = name .. " takes a size name, never a number: " .. (a.text:gsub("%s+", " ")) }
		end
		for str in a.text:gmatch("[\"']([^\"'\n]*)[\"']") do
			if not C.SIZE_NAMES[str] then
				hits[#hits + 1] = { line = line, why = name .. ' takes one of hero, display, title, heading, body, sub, caption, not "' .. str .. '"' }
			end
		end
	end
	local pos = 1
	while true do
		local s, e, name = text:find("%f[%w_.]([%w_]+%.[%w_]+)%s*%(", pos)
		if not s then break end
		pos = e + 1
		if C.SIZE_CALLS[name] and not text:sub(1, s - 1):match("[%w_]$") then
			local args = callArgs(text, e)
			if args[2] then judge(name, args[2]) end
		end
	end
	-- the same call handed to pcall: pcall(T.SetFont, fs, size, weight) (the size is then the 3rd argument)
	pos = 1
	while true do
		local s, e = text:find("%f[%w_.]pcall%s*%(", pos)
		if not s then break end
		pos = e + 1
		local args = callArgs(text, e)
		local f = args[1] and args[1].text:gsub("%s+", "")
		if f and C.SIZE_CALLS[f] and args[3] then judge(f .. " (through pcall)", args[3]) end
	end
	table.sort(hits, function(x, y) return x.line < y.line end)
	return hits
end

-- The font findings of one file: { { line, name }, ... }, one per line and name; nil when it is Theme/Tokens.lua.
-- Over the file's allowance (C.FONT_ALLOW) only; returns the lines past it.
function C.scanFonts(file, src, allow)
	local key = (tostring(file):gsub("\\", "/"))
	if key == "Theme/Tokens.lua" then return {} end
	local may = (allow or C.FONT_ALLOW)[key] or 0
	local found, n = {}, 0
	for lineText in (code(src or "") .. "\n"):gmatch("([^\n]*)\n") do
		n = n + 1
		local name
		for pre, word in lineText:gmatch("([%w_.]*)%f[%w_](SetFont[%w_]*)%f[^%w_]") do
			if word == "SetFontObject" or (word == "SetFont" and not pre:match("^T%.$") and not pre:match("%.T%.$") and not pre:match("^Theme%.$")) then name = word end
		end
		local gf = lineText:match("%f[%w_](GameFont[%w_]*)")
		if gf then name = name or gf end
		if name then found[#found + 1] = { line = n, name = name } end
	end
	local out = {}
	for i = may + 1, #found do out[#out + 1] = found[i] end
	return out
end

local function forbiddenWhat(name) return "names " .. name .. ", which this client forbids to addons (tools/forbidden.lua)" end

-- The lab addon's folder: WUBER_LAB_DIR (then true: set explicitly), else the usual place.
function C.labDir(getenv)
	local d = (getenv or os.getenv)("WUBER_LAB_DIR")
	if d and d ~= "" then return (d:gsub("\\", "/"):gsub("/+$", "")), true end
	return "lab/WuberLab", false
end

-- Scans the Lua files the lab addon's TOC lists. Returns FAIL lines and how many files it read
-- (none when the folder or its TOC isn't there).
function C.checkLab(dir, list, read)
	read = read or readAll
	local toc = read(dir .. "/WuberLab.toc")
	if not toc then return {}, 0, false end
	local fails, n = {}, 0
	for _, l in ipairs(lines(toc)) do
		local file = l:gsub("\\", "/")
		local src = file:match("%.lua$") and read(dir .. "/" .. file) or nil
		if src then
			n = n + 1
			for _, h in ipairs(C.scanForbidden(src, list)) do
				fails[#fails + 1] = "FAIL lab " .. file .. ":" .. h.line .. " " .. forbiddenWhat(h.name)
			end
		end
	end
	return fails, n, true
end

-- The lab check as check.lua runs it: FAIL lines and how many files it read. A folder named by
-- WUBER_LAB_DIR that isn't there fails; the default one missing is skipped quietly.
function C.scanLab(list, getenv, read)
	local dir, explicit = C.labDir(getenv)
	local fails, n, found = C.checkLab(dir, list, read)
	if explicit and not found then
		fails[#fails + 1] = "FAIL lab " .. dir .. ":0 WUBER_LAB_DIR is set, but there is no WuberLab.toc there"
	end
	return fails, n
end

-- Every string literal of a Lua source that is not in a comment: { { line, text }, ... }. Handles both quote
-- kinds (with escapes), [[long]] strings and -- / --[[ ]] comments. (Q5a)
function C.stringLiterals(src)
	local out, i, n, line = {}, 1, #src, 1
	local function lines_in(s) local _, k = s:gsub("\n", "") return k end
	while i <= n do
		local s = src:find("[%-\"'%[\n]", i)
		if not s then break end
		local c = src:sub(s, s)
		if c == "\n" then
			line = line + 1
			i = s + 1
		elseif c == "-" then
			if src:sub(s + 1, s + 1) == "-" then
				local eqs = src:match("^%[(=*)%[", s + 2)
				local e = eqs and longEnd(src, s + 2, eqs) or ((src:find("\n", s + 2, true) or n + 1) - 1)
				line = line + lines_in(src:sub(s, e))
				i = e + 1
			else
				i = s + 1
			end
		elseif c == "\"" or c == "'" then
			local e = s + 1
			while e <= n do
				e = src:find("[\\\n" .. c .. "]", e) or n + 1
				local ch = src:sub(e, e)
				if ch ~= "\\" then break end
				e = e + 2
			end
			out[#out + 1] = { line = line, text = src:sub(s + 1, e - 1) }
			line = line + lines_in(src:sub(s, e))
			i = e + 1
		else
			local eqs = src:match("^%[(=*)%[", s)
			if eqs then
				local e = longEnd(src, s, eqs)
				out[#out + 1] = { line = line, text = src:sub(s + #eqs + 2, e - #eqs - 2) }
				line = line + lines_in(src:sub(s, e))
				i = e + 1
			else
				i = s + 1
			end
		end
	end
	return out
end

-- The player strings that call WUBER ITSELF free (marketing words): { { line, text }, ... }.
-- the author's rule (23 Nov 19:08): never describe Wuber as free; "free" inside the addon (a free ride, a free raid summon,
-- the free OpenMap addon) is fine when it reads naturally. So only phrases about the addon itself fail.
C.FREE_ADDON_PATTERNS = {
	"wuber[%s%p]+is[%s]+%a*%s*free", "wuber[%s%p]+is[%s]+totally%s+free", "free%s+addon", "free%s+to%s+use", "free%s+to%s+download",
	"for%s+free", "100%%%s*free", "completely%s+free", "totally%s+free", "free%s+forever", "free%s+and%s+open", "wuber[%s%p]+%(free",
}
function C.scanFree(src)
	local hits = {}
	for _, s in ipairs(C.stringLiterals(src)) do
		local low = s.text:lower()
		for _, p in ipairs(C.FREE_ADDON_PATTERNS) do
			if low:find(p) then hits[#hits + 1] = s break end
		end
	end
	return hits
end

-- Test files that assign a harness field at file load: a line at indent zero, H.name = ...  (not ==). (C3, L6)
function C.scanHarnessAssign(src)
	local hits, n = {}, 0
	for l in (src .. "\n"):gmatch("([^\n]*)\n") do
		n = n + 1
		if l:match("^H%.[%w_]+%s*=") and not l:match("^H%.[%w_]+%s*==") then hits[#hits + 1] = n end
	end
	return hits
end

-- every .lua file under a folder, full paths (no shell assumed)
local function luaFilesUnder(dir)
	local windows = package.config:sub(1, 1) == "\\"
	local cmd = windows and ('dir /b /s "' .. dir:gsub("/", "\\") .. '\\*.lua" 2>nul')
		or ('find "' .. dir .. '" -name "*.lua" 2>/dev/null')
	local p = io.popen(cmd)
	local out = {}
	if not p then return out end
	for name in p:read("*a"):gmatch("[^\r\n]+") do out[#out + 1] = (name:gsub("\\", "/")) end
	p:close()
	table.sort(out)
	return out
end

function C.tocFiles(root)
	local toc = readAll(root .. "/Wuber/Wuber.toc")
	if not toc then return nil end
	local out = {}
	for _, l in ipairs(lines(toc)) do out[#out + 1] = (l:gsub("\\", "/")) end
	return out
end

-- old file name -> the files holding its code (tests/lib/files.lua's table)
local function oldOwners(root)
	local chunk = loadfile(root .. "/tests/lib/files.lua")
	local F = chunk and chunk()
	local owner = {}
	for old, list in pairs(F and F.NEW or {}) do
		owner[old .. ".lua"] = old
		for _, p in ipairs(list) do owner[p] = old end
	end
	return owner
end

-- opts: root (repo), files (list of TOC paths; default from the TOC), read(path) -> text,
-- legacy (set of paths), globals ({ read = set, write = set } or nil to skip), allow (list)
-- Returns { fails = {...}, warns = {...}, info = { reads, writes, modules } }.
function C.check(opts)
	local root = opts.root or "."
	local L = C.LIMITS
	local fails, warns = {}, {}
	local function fail(file, line, what) fails[#fails + 1] = "FAIL " .. file .. ":" .. (line or 0) .. " " .. what end
	local function warn(file, line, what) warns[#warns + 1] = "WARN " .. file .. ":" .. (line or 0) .. " " .. what end
	local files = opts.files or C.tocFiles(root)
	if not files then
		fail("Wuber/Wuber.toc", 0, "no TOC")
		return { fails = fails, warns = warns, info = {} }
	end
	local read = opts.read or function(p) return readAll(root .. "/Wuber/" .. p) end
	local legacy = opts.legacy or {}
	local owner = opts.owner or oldOwners(root)
	local allow = opts.allow or C.ALLOW_LOAD

	-- 1 parse
	local parsed = {}
	for _, file in ipairs(files) do
		if file:match("%.lua$") then
			local src = read(file)
			if not src then
				fail(file, 0, "the TOC lists it but it does not exist")
			else
				local chunk, err = loadstring(src, "@" .. file)
				if not chunk then
					fail(file, tonumber(tostring(err):match(":(%d+):")) or 0, "does not compile: " .. tostring(err))
				else
					local al, canon = aliases(src)
					parsed[#parsed + 1] = { file = file, src = src, proto = undump(string.dump(chunk)), aliases = al,
						canon = canon }
				end
			end
		end
	end

	-- 7 forbidden in this client (tools/forbidden.lua)
	local forbidden = opts.forbidden
	if forbidden == nil then forbidden = C.readForbidden(root) end
	for _, P in ipairs(parsed) do
		for _, h in ipairs(C.scanForbidden(P.src, forbidden)) do fail(P.file, h.line, forbiddenWhat(h.name)) end
	end

	-- 9 the world map is opened in one place
	for _, P in ipairs(parsed) do
		local line, name = C.scanMapOpen(P.file, P.src, opts.mapAllow)
		if line then
			fail(P.file, line, "names " .. name .. ": the world map is opened only by W.Map.Open (UI/Map/Map.lua), through the"
				.. " game's safe opener C_Map.OpenWorldMap; its Lua openers from addon code taint the map")
		end
	end

	-- 8 chat from addon code: one call site
	for _, P in ipairs(parsed) do
		local line, n, max = C.scanChat(P.file, P.src, opts.chatAllow)
		if line then
			fail(P.file, line, "names SendChatMessage on " .. n .. " line(s) (allowed in this file: " .. max
				.. "): addon code sends no chat, except the one auto-reply whisper in Drive/AutoReply.lua (CLAUDE.md)"
				.. " and the one whisper to the driver's own rider in Drive/AutoLines.lua")
		end
	end

	-- 10 text sizes and fonts: the theme owns them
	for _, P in ipairs(parsed) do
		for _, h in ipairs(C.scanTextSizes(P.file, P.src)) do
			fail(P.file, h.line, "text size: " .. h.why .. " (design round 3: seven sizes, named; Theme/Tokens.lua)")
		end
		for _, h in ipairs(C.scanFonts(P.file, P.src, opts.fontAllow)) do
			fail(P.file, h.line, "font: names " .. h.name .. " outside Theme/Tokens.lua: set fonts with T.SetFont, or list the file in"
				.. " C.FONT_ALLOW with a reason if the call cannot go through it")
		end
	end

	-- 11 the game's tooltip: Wuber's tips are its own card
	for _, P in ipairs(parsed) do
		local line, n, max = C.scanGameTip(P.file, P.src, opts.tipAllow)
		if line then
			fail(P.file, line, "names GameTooltip " .. n .. " time(s) (allowed in this file: " .. max .. "): a Wuber tip is drawn on"
				.. " Wuber's own card (T.Tip, T.TipShow, T.TipHide in Theme/Widgets.lua), never on the game's tooltip")
		end
	end

	-- 12 a player string that calls Wuber itself free (T-20, narrowed 23 Nov 19:08): marketing words only
	do
		for _, P in ipairs(parsed) do
			for _, h in ipairs(C.scanFree(P.src)) do
				fail(P.file, h.line, "a player string calls Wuber itself free: " .. h.text:sub(1, 60) .. " (never describe Wuber as free;"
					.. " 'free' about a ride, a summon or another addon is fine)")
			end
		end
	end

	-- 13 a test file assigning a harness field at file load (L6): a warning, counted
	local harnessCount
	if opts.testFiles ~= false then
		local list, count = {}, 0
		for _, p in ipairs(opts.testFiles or luaFilesUnder(root .. "/tests")) do
			-- the harness, its libraries and the runner are not test files
			local skip = p:find("/lib/", 1, true) or p:find("/harness[^/]*%.lua$") or p:find("/run%.lua$")
			local src = (not skip) and (opts.testRead and opts.testRead(p) or readAll(p))
			local hs = src and C.scanHarnessAssign(src) or {}
			if #hs > 0 then
				count = count + #hs
				list[#list + 1] = (p:match("(tests/.*)$") or p) .. ":" .. hs[1] .. (#hs > 1 and (" (+" .. (#hs - 1) .. ")") or "")
			end
		end
		harnessCount = count
		if count > 0 then
			warn("tests", 0, "H.* HARNESS FIELDS ASSIGNED AT FILE LOAD (not inside a function; newClient cannot see it): "
				.. count .. " line(s) in " .. #list .. " file(s): " .. table.concat(list, ", "))
		end
	end

	-- who defines what; every file's top-level locals
	local definer, topLocals = {}, {}
	for _, P in ipairs(parsed) do
		P.defs = definitions(P.src, P.canon)
		for name in pairs(P.defs) do definer[name] = definer[name] or P.file end
		for _, v in ipairs(P.proto.locvars) do topLocals[v.name] = topLocals[v.name] or P.file end
	end

	local reads, writes = {}, {}
	for _, P in ipairs(parsed) do
		local file, main = P.file, P.proto
		-- 2 locals and upvalues
		eachProto(main, function(f)
			local n = maxLive(f)
			local where = f == main and 0 or f.line
			local what = (f == main and "the top level" or "a function") .. " holds " .. n .. " locals at once"
			if n > L.localsFail then fail(file, where, what .. " (limit " .. L.localsFail .. "; Lua's is 200)")
			elseif n > L.localsWarn then warn(file, where, what) end
			if f.nups > L.upvaluesFail then fail(file, where, "a function has " .. f.nups .. " upvalues (limit " .. L.upvaluesFail .. ")")
			elseif f.nups > L.upvaluesWarn then warn(file, where, "a function has " .. f.nups .. " upvalues") end
		end)
		-- 3 globals
		eachProto(main, function(f)
			walk(f, function(kind, name, line)
				if kind == "global" and name then
					reads[name] = reads[name] or (file .. ":" .. line)
					if opts.globals and not opts.globals.read[name] then
						local lost = topLocals[name]
						if lost then fail(file, line, "reads global `" .. name .. "`: a lost local (a top-level local of " .. lost .. ")")
						else fail(file, line, "reads a new global `" .. name .. "` (not in tools/globals-baseline.txt)") end
					end
				elseif kind == "setglobal" and name then
					writes[name] = writes[name] or (file .. ":" .. line)
					if opts.globals and not opts.globals.write[name] then
						fail(file, line, "writes a new global `" .. name .. "` (not in tools/globals-baseline.txt)")
					end
				end
			end)
		end)
		-- 4 load-time calls into another file
		local closures = {}
		do -- which proto each top-level local function holds: CLOSURE A Bx into the local's
			-- register (`local function x` starts x's life after the upvalue pseudo-instructions)
			for pc0, ins in ipairs(main.code) do
				local op, a, _, _, bx = decode(ins)
				local proto = op == OP.CLOSURE and main.p[bx + 1]
				if proto then
					local name = localName(main, a, pc0 + proto.nups) or localName(main, a, pc0 - 1)
					if name then closures[name] = proto end
				end
			end
		end
		local function foreign(name)
			if not name then return nil end
			local c = P.canon((name:gsub(":", ".")))
			local d = c and definer[c]
			if d and d ~= file and not C.LOAD_OK[c] then return c, d end
			return nil
		end
		local function allowed(call)
			for _, a in ipairs(allow) do
				if a.call == call and (owner[file] == a.old or file == a.old .. ".lua") then return true end
			end
			return false
		end
		walk(main, function(kind, name, line)
			if kind ~= "call" or not name then return end
			local c, d = foreign(name)
			if c then
				if not allowed(name) then fail(file, line, "load-time call of " .. c .. " (defined in " .. d .. ")") end
				return
			end
			local body = closures[name]
			if body and not allowed(name) then
				-- a local function run at load: what it reaches directly (not its own closures)
				local reached = {}
				walk(body, function(k2, n2)
					local c2, d2 = foreign(n2)
					if c2 and (k2 == "call" or k2 == "read") and not reached[c2] then
						reached[c2] = true
						reached[#reached + 1] = c2 .. " (" .. d2 .. ")"
					end
				end)
				if #reached > 0 then
					fail(file, line, "load-time call of " .. name .. "(), which reaches " .. table.concat(reached, ", "))
				end
			end
		end)
	end

	-- 5 size and 6 modules (new module files only)
	local modules, order = {}, {}
	for i, P in ipairs(parsed) do
		P.index = i
		if not legacy[P.file] then
			local n = select(2, P.src:gsub("\n", "\n")) + 1
			if n > L.sizeFail then fail(P.file, 0, n .. " lines (a module's cap is " .. L.sizeFail .. ")")
			elseif n > L.sizeWarn then warn(P.file, 0, n .. " lines (over " .. L.sizeWarn .. ")") end
			local found = {}
			for name, rest in code(P.src):gmatch("W%.Module%(%s*\"([^\"]+)\"%s*([^%)]*)") do
				local deps = {}
				for d in (rest:match("%b{}") or ""):gmatch("\"([^\"]+)\"") do deps[#deps + 1] = d end
				found[#found + 1] = { name = name, deps = deps }
			end
			local want = P.file:gsub("%.lua$", ""):gsub("/", ".")
			if #found ~= 1 then
				fail(P.file, 0, "a module file needs exactly one W.Module(\"" .. want .. "\", {...}); found " .. #found)
			else
				local m = found[1]
				if m.name ~= want then fail(P.file, 0, "W.Module(\"" .. m.name .. "\") should be named \"" .. want .. "\"") end
				if modules[m.name] then fail(P.file, 0, "module " .. m.name .. " is also defined in " .. modules[m.name].file) end
				modules[m.name] = { file = P.file, index = i, deps = m.deps }
				order[#order + 1] = m.name
			end
		end
	end
	for _, name in ipairs(order) do
		local m = modules[name]
		for _, dep in ipairs(m.deps) do
			local d = modules[dep]
			if not d then fail(m.file, 0, name .. " depends on " .. dep .. ", which no TOC file defines")
			elseif d.index >= m.index then fail(m.file, 0, name .. " loads before its dependency " .. dep .. " (TOC order)") end -- (r48) >=: a module that lists itself
		end
	end
	for _, P in ipairs(parsed) do
		local n = 0
		for line in (code(P.src) .. "\n"):gmatch("([^\n]*)\n") do
			n = n + 1
			for target in line:gmatch("W%.Mod%(%s*\"([^\"]+)\"%s*%)") do
				if not modules[target] then fail(P.file, n, "W.Mod(\"" .. target .. "\"): no module of that name in the TOC") end
			end
		end
	end

	table.sort(fails)
	table.sort(warns)
	return { fails = fails, warns = warns, info = { reads = reads, writes = writes, modules = modules, files = #parsed, harnessAssign = harnessCount } }
end

---------------------------------------------------------------------------
-- Baselines and the command line
---------------------------------------------------------------------------

function C.readGlobals(path)
	local text = readAll(path)
	if not text then return nil end
	local g = { read = {}, write = {} }
	for _, l in ipairs(lines(text)) do
		local kind, name = l:match("^(%a+)%s+([%a_][%w_]*)$")
		if kind == "read" or kind == "write" then g[kind][name] = true end
	end
	return g
end

function C.readLegacy(path)
	local set = {}
	for _, l in ipairs(lines(readAll(path))) do set[(l:gsub("\\", "/"))] = true end
	return set
end

-- everything, as the suite and the command line run it
function C.run(root, extra)
	extra = extra or {}
	local globals = C.readGlobals(root .. "/tools/globals-baseline.txt")
	local res = C.check({ root = root, legacy = C.readLegacy(root .. "/tools/check-legacy.txt"),
		globals = not extra.noGlobals and globals or nil })
	if not globals and not extra.noGlobals then
		table.insert(res.fails, 1, "FAIL tools/globals-baseline.txt:0 missing (lua5.1 tools/check.lua --write-globals)")
	end
	local forbidden = C.readForbidden(root)
	if not forbidden then table.insert(res.fails, 1, "FAIL tools/forbidden.lua:0 missing or broken") end
	local labFails, labFiles = C.scanLab(forbidden)
	for _, l in ipairs(labFails) do res.fails[#res.fails + 1] = l end
	res.info.labFiles = labFiles
	return res
end

function C.writeGlobals(root)
	local res = C.check({ root = root, legacy = C.readLegacy(root .. "/tools/check-legacy.txt") })
	local out = { "# Globals Wuber's files read and write (tools/check.lua check 3). Made with",
		"# `lua5.1 tools/check.lua --write-globals`; adding a name is a reviewed change." }
	for _, kind in ipairs({ "read", "write" }) do
		local names = {}
		for n in pairs(res.info[kind .. "s"]) do names[#names + 1] = n end
		table.sort(names)
		for _, n in ipairs(names) do out[#out + 1] = kind .. " " .. n end
	end
	local f = assert(io.open(root .. "/tools/globals-baseline.txt", "wb"))
	f:write(table.concat(out, "\n"), "\n")
	f:close()
	return #out - 2
end

-- what check.lua prints after the FAIL lines (and the warnings with --warn)
function C.report(res, flags)
	local out = {}
	for _, l in ipairs(res.fails) do out[#out + 1] = l end
	if flags["--warn"] then for _, l in ipairs(res.warns) do out[#out + 1] = l end end
	local nmod = 0
	for _ in pairs(res.info.modules or {}) do nmod = nmod + 1 end
	if res.info.harnessAssign then out[#out + 1] = "test files: " .. res.info.harnessAssign .. " H.* assignment(s) at file load (L6)" end
	out[#out + 1] = "lab: " .. (res.info.labFiles or 0) .. " files scanned"
	out[#out + 1] = ("check: %d files, %d modules, %d failures, %d warnings%s"):format(res.info.files or 0, nmod, #res.fails,
		#res.warns, (#res.warns > 0 and not flags["--warn"]) and " (--warn lists them)" or "")
	return out
end

if ... == "--lib" then return C end

local root = ((arg and arg[0] or "tools/check.lua"):gsub("\\", "/"):match("^(.*)/tools/[^/]*$")) or "."
local flags = {}
for _, a in ipairs(arg or {}) do flags[a] = true end
if flags["--write-globals"] then
	print("tools/globals-baseline.txt: " .. C.writeGlobals(root) .. " names")
	os.exit(0)
end
local res = C.run(root)
for _, l in ipairs(C.report(res, flags)) do print(l) end
os.exit(#res.fails == 0 and 0 or 1)
