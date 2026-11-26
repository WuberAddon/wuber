#!/usr/bin/env lua5.1
-- static-surface.lua: the STATIC API surface pass. It reads the Lua files the TOCs list and judges them against tests/surface/apisurface.lua
-- WITHOUT running anything, so code that no test executes is judged too (the runtime guard, tests/surface-guard.lua, only sees what a test runs).
-- There is no luac on the maintainer's PC, so this file holds its own small Lua 5.1 lexer (names, strings, long strings, comments, numbers).
--
--   lua5.1 tools/surface/static-surface.lua [options]          (run from the repo root, or give --root)
--   lua5.1 tools/surface/static-surface.lua --help
--
-- What it reports (kind = first column):
--   P    protected / secure-only / curated "never" name called from addon code (ReloadUI, CastSpellByName, RunMacroText ...). GATES.
--        ReloadUI is P everywhere, even in a click handler (PR #230: the real client blocks it there too); the context is printed
--        (onclick / timer / plain) so the shape is visible. A curated "never" name given as a string to a call (gfn("ReloadUI")) is P too.
--   B4   secret-compare peephole, GATES: a value that comes from an ALWAYS-secret call (SecretReturns=true) or from a ConstSecretAccessor
--        method on a frame that is not the addon's own (IsEventRegistered, HasScript, GetScript, GetAttribute ...) reaches ==, ~=, <, <=, >, >=,
--        not, if/while/and/or truthiness inside the same function BEFORE it passed through issecretvalue / canaccessvalue (or a local helper
--        whose body calls one). A direct "f:IsEventRegistered(e) == true" is B4 too. Calls through callm(o, "Name") / askm / pcall(o.Name, o) count.
--   B4c  the same for a CONDITIONALLY secret function (SecretWhen*, SecretInChatMessagingLockdown, SecretReturnsForAspect: UnitName, GetText,
--        IsShown ...). Information (does not gate): such a value is secret only when the restriction holds. A conditional value that is
--        never compared is not reported.
--   U    a global / C_X.Fn / :Method the docs, the interface Lua and the addon itself never define (nil in the game). Information unless --gate-u.
--        Behind its own test (a bare mention of the same name earlier in the same top-level function: type(X), X and X(), pcall(X ...)) it is G.
--   G    the guarded U (information), H = curated hardware-click call, C = curated combat call (information, with --verbose).
-- Not checked (say so in every report): taint propagation, a secret returned through a helper in ANOTHER function, a secret stored in a table
--   and compared later, method calls on objects whose class is unknown (a name in the docs is judged by the name alone).
--
-- Exit code: 1 when a gating finding is left (P, B4; U with --gate-u), else 0. --help prints this text.

local SS = {}

---------------------------------------------------------------------------------------------------------------------------------
-- the lexer. Tokens in three parallel arrays: ty ("n" name, "k" keyword, "s" string, "d" number, "o" operator), va (text), li (line)
---------------------------------------------------------------------------------------------------------------------------------
local KW = {}
for w in ("and break do else elseif end false for function if in local nil not or repeat return then true until while"):gmatch("%a+") do KW[w] = true end
local find, sub, byte = string.find, string.sub, string.byte

local function lex(src)
	local ty, va, li = {}, {}, {}
	local n, pos, line, len = 0, 1, 1, #src
	if sub(src, 1, 2) == "#!" then pos = (find(src, "\n", 1, true) or len) end
	local function nl(a, b) -- count the newlines of src[a..b]
		local p = a
		while true do
			local s = find(src, "\n", p, true)
			if not s or s > b then return end
			line = line + 1
			p = s + 1
		end
	end
	while pos <= len do
		local s, e = find(src, "^[ \t\r]+", pos)
		if s then pos = e + 1 end
		if pos > len then break end
		local c = sub(src, pos, pos)
		if c == "\n" then line = line + 1 pos = pos + 1
		elseif c == "-" and sub(src, pos + 1, pos + 1) == "-" then
			local eq = src:match("^%[(=*)%[", pos + 2)
			if eq then
				local close = "]" .. eq .. "]"
				local _, ce = find(src, close, pos + 4 + #eq, true)
				ce = ce or len
				nl(pos, ce)
				pos = ce + 1
			else
				pos = find(src, "\n", pos, true) or (len + 1)
			end
		else
			local b = byte(c)
			n = n + 1
			if (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b == 95 then
				local _, ne = find(src, "^[%w_]*", pos + 1)
				local w = sub(src, pos, ne)
				ty[n] = KW[w] and "k" or "n" va[n] = w li[n] = line
				pos = ne + 1
			elseif (b >= 48 and b <= 57) or (c == "." and find(src, "^%d", pos + 1)) then
				local _, ne = find(src, "^0[xX]%x*", pos)
				if not ne then
					_, ne = find(src, "^%d*%.?%d*", pos)
					local _, ee = find(src, "^[eE][+-]?%d+", ne + 1)
					if ee then ne = ee end
				end
				ty[n] = "d" va[n] = sub(src, pos, ne) li[n] = line
				pos = ne + 1
			elseif c == '"' or c == "'" then
				local p, startLine = pos + 1, line
				while true do
					local q = find(src, "[\\\n" .. c .. "]", p)
					if not q then p = len + 1 break end
					local ch = sub(src, q, q)
					if ch == "\\" then
						if sub(src, q + 1, q + 1) == "\n" then line = line + 1 end
						p = q + 2
					elseif ch == "\n" then p = q break -- unterminated: stop at the line end
					else p = q break end
				end
				ty[n] = "s" va[n] = sub(src, pos + 1, p - 1) li[n] = startLine
				pos = p + 1
			elseif c == "[" and find(src, "^%[=*%[", pos) then
				local eq = src:match("^%[(=*)%[", pos)
				local close = "]" .. eq .. "]"
				local _, ce = find(src, close, pos + 2 + #eq, true)
				ce = ce or len
				local startLine = line
				nl(pos, ce)
				ty[n] = "s" va[n] = sub(src, pos + 2 + #eq, ce - #close) li[n] = startLine
				pos = ce + 1
			else
				local op = sub(src, pos, pos + 2)
				if op == "..." then pos = pos + 3
				else
					op = sub(src, pos, pos + 1)
					if op == ".." or op == "==" or op == "~=" or op == "<=" or op == ">=" then pos = pos + 2
					else op = c pos = pos + 1 end
				end
				ty[n] = "o" va[n] = op li[n] = line
			end
		end
	end
	return ty, va, li, n
end
SS.lex = lex

---------------------------------------------------------------------------------------------------------------------------------
-- the lists
---------------------------------------------------------------------------------------------------------------------------------
local function set(s) local t = {} for w in s:gmatch("%S+") do t[w] = true end return t end
-- Lua / C-side globals the client has that neither the docs nor the interface Lua define (the same short list as the runtime guard) + the Lua 5.1 library
local LUAX = set([[strsplit strjoin strtrim strlen strsub strupper strlower strfind strmatch strrep strbyte strchar strrev strconcat strlenutf8
	strcmputf8i format gsub gmatch tinsert tremove wipe tContains tIndexOf foreach foreachi getn sort max min floor ceil abs sqrt random
	mod fmod date time difftime hooksecurefunc securecall secureexecuterange issecurevariable issecretvalue canaccessvalue canaccesssecrets
	canaccesstable scrub geterrorhandler seterrorhandler debugstack debugprofilestop debuglocals debugprofilestart GetTime
	loadstring loadfile dofile setfenv getfenv xpcall pcall CreateFrame forceinsecure issecure GetFramesRegisteredForEvent
	securecallfunction tostringall tonumber tostring ipairs pairs next unpack select type rawget rawset rawequal assert error
	print setmetatable getmetatable collectgarbage gcinfo UnitName CopyTable Mixin CreateFromMixins CreateAndInitFromMixin
	Lerp Clamp Round require module newproxy load string table math os io coroutine bit hasanysecretvalues]])
local STRMETH = set("format find gsub gmatch match sub lower upper len rep byte reverse")
local SANBASE = set("issecretvalue canaccessvalue canaccesssecrets canaccesstable hasanysecretvalues")
local CMP = set("== ~= < <= > >=")
local NOT_TERM = set(". [ : ( .. + - * / % ^ == ~= < <= > >= and or")
-- wrappers that call a method by its name as a string: callm(o, "Name", ...) / askm(o, "Name") (the lab). The Drive "call(name)" helpers dispatch
-- to the addon's own tables, so they are not wrappers of the client API.
local WRAP = set("callm askm")
local BYNAME = set("call callm askm gfn getglobal rawget safecall")
local CLICKS = set("OnClick PostClick PreClick OnMouseUp OnMouseDown")

local function tocFiles(root, toc)
	local f = io.open(root .. "/" .. toc, "rb")
	if not f then return nil, "cannot open " .. toc end
	local dir = toc:match("^(.*)/[^/]*$") or "."
	local out = {}
	for l in f:lines() do
		l = l:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
		if l ~= "" and l:sub(1, 1) ~= "#" and l:lower():find("%.lua$") then out[#out + 1] = dir .. "/" .. l:gsub("\\", "/") end
	end
	f:close()
	return out
end
SS.tocFiles = tocFiles

---------------------------------------------------------------------------------------------------------------------------------
-- phase 1 per file: functions (blocks), declared names, definitions
---------------------------------------------------------------------------------------------------------------------------------
local function structure(ty, va, li, n)
	local fnOf, fns, stack = {}, {}, {}
	local cur = 0
	local info = { locals = {}, localFuncs = {}, fieldDefs = {}, assigned = {}, ownFrames = {}, sanitizers = {} }
	local function ctxFor(i) -- what a function starting at token i is the argument of: onclick / timer / onupdate / onevent / nil
		local p = i - 1
		if va[p] == "=" and ty[p - 1] == "n" then
			if CLICKS[va[p - 1]] then return "onclick" end
			return nil
		end
		if va[p] ~= "," and va[p] ~= "(" then return nil end
		local depth, j, strs = 0, p, {}
		while j > 0 and j > i - 80 do
			local v, t = va[j], ty[j]
			if t == "o" and (v == ")" or v == "]" or v == "}") then depth = depth + 1
			elseif t == "o" and (v == "(" or v == "[" or v == "{") then
				if depth == 0 then
					if v ~= "(" then return nil end
					local callee = ty[j - 1] == "n" and va[j - 1] or ""
					local owner = (va[j - 2] == "." and ty[j - 3] == "n") and va[j - 3] or ""
					for _, s in ipairs(strs) do
						if CLICKS[s] then return "onclick" end
						if s == "OnUpdate" then return "onupdate" end
						if s == "OnEvent" then return "onevent" end
					end
					if owner == "C_Timer" or callee == "After" or callee == "NewTimer" or callee == "NewTicker" or callee:find("[Dd]elay")
						or callee:find("[Aa]fter") or callee:find("Later") or callee:find("[Tt]imer") then return "timer" end
					return nil
				end
				depth = depth - 1
			elseif t == "s" and depth == 0 then strs[#strs + 1] = v end
			j = j - 1
		end
		return nil
	end
	for i = 1, n do
		fnOf[i] = cur
		local t, v = ty[i], va[i]
		if t == "k" then
			if v == "function" then
				-- name: "function A.B:C(" / "local function C(" / "C = function" / "local C = function"
				local name, q = nil, i + 1
				local isLocalDef = va[i - 1] == "local"
				if ty[q] == "n" then
					name = va[q]
					local chain = 1
					while (va[q + 1] == "." or va[q + 1] == ":") and ty[q + 2] == "n" do q = q + 2 name = va[q] chain = chain + 1 info.fieldDefs[name] = true end
					if chain == 1 then
						info.localFuncs[name] = true
						if isLocalDef then info.locals[name] = true else info.assigned[name] = true end
					end
					if chain > 1 then info.fieldDefs[va[i + 1]] = true end
					q = q + 1
				elseif va[i - 1] == "=" and ty[i - 2] == "n" then
					name = va[i - 2]
				end
				-- parameters
				if va[q] == "(" then
					local j = q + 1
					while j <= n and va[j] ~= ")" do
						if ty[j] == "n" then info.locals[va[j]] = true end
						j = j + 1
					end
				end
				local fn = { start = i, parent = cur, name = name, ctx = (ty[q] ~= "n" or va[i + 1] == "(") and ctxFor(i) or nil }
				fns[#fns + 1] = fn
				stack[#stack + 1] = { f = fn }
				cur = #fns
			elseif v == "if" or v == "do" or v == "repeat" then stack[#stack + 1] = {}
			elseif v == "end" or v == "until" then
				local top = stack[#stack]
				stack[#stack] = nil
				if top and top.f then
					top.f.stop = i
					cur = top.f.parent
				end
			elseif v == "local" then
				local j = i + 1
				if va[j] == "function" then j = n + 1 end
				while j <= n and ty[j] == "n" do
					info.locals[va[j]] = true
					if va[j + 1] == "," then j = j + 2 else break end
				end
			elseif v == "for" then
				local j = i + 1
				while j <= n and ty[j] == "n" do
					info.locals[va[j]] = true
					if va[j + 1] == "," then j = j + 2 else break end
				end
			end
		elseif t == "n" then
			local nx = va[i + 1]
			if nx == "=" and ty[i + 1] == "o" then
				info.fieldDefs[v] = true
				if va[i - 1] ~= "." and va[i - 1] ~= ":" and va[i - 1] ~= "local" then info.assigned[v] = true end
				if va[i + 2] == "CreateFrame" and va[i - 1] ~= "." then info.ownFrames[v] = true end
			end
		end
		if (t == "n" or t == "s") and SANBASE[v] and cur > 0 then fns[cur].san = true end -- (the string too: rawget(_G, "issecretvalue"))
	end
	for _, fn in ipairs(fns) do
		if not fn.stop then fn.stop = n end
		if fn.san and fn.name then info.sanitizers[fn.name] = true end
	end
	return fnOf, fns, info
end

local function matchFwd(ty, va, i, n) -- i = index of an opening ( [ {: the index of its match
	local depth = 0
	for j = i, n do
		if ty[j] == "o" then
			local v = va[j]
			if v == "(" or v == "[" or v == "{" then depth = depth + 1
			elseif v == ")" or v == "]" or v == "}" then
				depth = depth - 1
				if depth == 0 then return j end
			end
		end
	end
	return n
end
local function matchBack(ty, va, i) -- i = index of a closing ) ] }: the index of its opener
	local depth = 0
	for j = i, 1, -1 do
		if ty[j] == "o" then
			local v = va[j]
			if v == ")" or v == "]" or v == "}" then depth = depth + 1
			elseif v == "(" or v == "[" or v == "{" then
				depth = depth - 1
				if depth == 0 then return j end
			end
		end
	end
	return 1
end

---------------------------------------------------------------------------------------------------------------------------------
-- phase 2: judge one file
---------------------------------------------------------------------------------------------------------------------------------
-- the ConstSecretAccessor methods that answer a secret on a frame the GAME made (evidence: B4). Another csa method (GetWidth, GetPoint ...) is
-- secret on such frames too, but on the addon's own frames it never is, and the addon cannot be told apart statically: "cond" (information),
-- unless --csa all makes every one of them gate.
local FOREIGN = set("IsEventRegistered HasScript GetScript GetAttribute")
local function classify(d, name, X)
	if not d then return nil end
	if d.sra then return "always" end
	if d.csa and (X.csaAll or FOREIGN[name]) then return "foreign" end
	if d.csa then return "cond" end
	if d.sw or d.scl or d.sas then return "cond" end
	return nil
end

local function judge(F, X, out)
	local ty, va, li, n, fnOf, fns, info = F.ty, F.va, F.li, F.n, F.fnOf, F.fns, F.info
	local S = X.S
	local fname = F.name
	local seen = {}
	local function add(kind, name, i, msg, ctx, gate)
		local line = li[i] or 0
		local key = kind .. name .. ":" .. line
		if seen[key] then return end
		seen[key] = true
		out[#out + 1] = { kind = kind, name = name, file = fname, line = line, msg = msg, ctx = ctx, gate = gate }
	end
	local function ctxOf(i)
		local f = fnOf[i]
		local seenCtx
		while f and f > 0 do
			local c = fns[f].ctx
			if c then seenCtx = seenCtx or c if c == "onclick" or c == "timer" then return c end end
			f = fns[f].parent
		end
		return seenCtx or "plain"
	end
	local function topFnStart(i) -- the start of the outermost function around token i (1 at the top level)
		local f = fnOf[i]
		if not f or f == 0 then return 1 end
		while fns[f].parent and fns[f].parent > 0 do f = fns[f].parent end
		return fns[f].start
	end
	-- bare mentions of a name (not a call) and strings equal to it: the addon testing for the name first
	local bare = {}
	for i = 1, n do
		local t = ty[i]
		if t == "n" then
			local nx = va[i + 1]
			if not (nx == "(" or ty[i + 1] == "s" or nx == "{") then
				local b = bare[va[i]] if not b then b = {} bare[va[i]] = b end
				b[#b + 1] = i
			end
		elseif t == "s" then
			local b = bare[va[i]] if not b then b = {} bare[va[i]] = b end
			b[#b + 1] = i
		end
	end
	local function guarded(name, i)
		local b = bare[name]
		if not b then return false end
		local from = topFnStart(i)
		for k = 1, #b do
			local j = b[k]
			if j >= i then return false end
			if j >= from and j < i - 0 then
				-- (the mention of the name itself in "function X(" or "X =" is not a test)
				if not (va[j - 1] == "function" or (va[j + 1] == "=" and ty[j + 1] == "o")) then return true end
			end
		end
		return false
	end
	local function exprStart(i)
		local j = i
		for _ = 1, 40 do
			local p = j - 1
			if ty[p] == "o" and (va[p] == "." or va[p] == ":") then
				local q = p - 1
				if ty[q] == "n" then j = q
				elseif ty[q] == "o" and (va[q] == ")" or va[q] == "]") then
					local o = matchBack(ty, va, q)
					j = o
					if ty[o - 1] == "n" then j = o - 1 end
				else break end
			else break end
		end
		return j
	end

	-- follow a variable that holds a secret: the first compare / test before a sanitizer
	local function track(var, from, stopAt, cls, callName)
		for j = from, stopAt do
			if ty[j] == "n" and va[j] == var and va[j - 1] ~= "." and va[j - 1] ~= ":" then
				local nx, pv = va[j + 1], va[j - 1]
				if (nx == "=" and ty[j + 1] == "o") or pv == "local" then return end -- reassigned
				if pv == "(" and ty[j - 2] == "n" and (SANBASE[va[j - 2]] or X.sanitizers[va[j - 2]] or info.sanitizers[va[j - 2]]) then return end -- passed the check
				local why
				if pv == "not" then why = "not " .. var
				elseif CMP[pv] and ty[j - 1] == "o" then why = "compared (" .. pv .. ")"
				elseif CMP[nx] and ty[j + 1] == "o" then why = "compared (" .. nx .. ")"
				elseif nx == "and" or nx == "or" then why = "tested with " .. nx
				elseif (nx == "then" or nx == "do") and (pv == "if" or pv == "elseif" or pv == "while" or pv == "until" or pv == "and" or pv == "or") then why = "tested (" .. pv .. " " .. var .. " " .. nx .. ")"
				end
				if why then
					local kind = (cls == "cond") and "B4c" or "B4"
					add(kind, callName, j, "the answer of " .. callName .. "() is " .. why .. " before issecretvalue/canaccessvalue: a secret value cannot be compared or tested ("
						.. (cls == "cond" and "secret only when the restriction holds" or "secret in the game") .. ")", ctxOf(j), cls ~= "cond")
					return
				end
			end
		end
	end

	-- one call of a function the docs know: its names, flags, and what its result is used for
	local function secretUse(callName, cls, nameIdx, wholeStart, wholeEnd, pcallStyle)
		local a, p = va[wholeEnd + 1], va[wholeStart - 1]
		local pt, at = ty[wholeStart - 1], ty[wholeEnd + 1]
		local why
		if pcallStyle then why = nil
		elseif at == "o" and CMP[a] then why = "compared (" .. a .. ")"
		elseif pt == "o" and CMP[p] then why = "compared (" .. p .. ")"
		elseif p == "not" then why = "not ..."
		elseif a == "and" or a == "or" then why = "tested with " .. a
		elseif (a == "then" or a == "do") and (p == "if" or p == "elseif" or p == "while" or p == "until" or p == "and" or p == "or") then why = "tested (" .. p .. " ... " .. a .. ")"
		end
		if why then
			add(cls == "cond" and "B4c" or "B4", callName, nameIdx, callName .. "() answered a value that is " .. why .. " straight away (no issecretvalue first)",
				ctxOf(nameIdx), cls ~= "cond")
			return
		end
		-- assigned to a name? then follow the name to the end of the function
		if pt == "o" and p == "=" and not (at == "o" and NOT_TERM[a]) and not (at == "k" and (a == "and" or a == "or")) then
			local names, q = {}, wholeStart - 2
			while ty[q] == "n" and va[q - 1] ~= "." and va[q - 1] ~= ":" do
				table.insert(names, 1, va[q])
				if va[q - 1] == "," then q = q - 2 else break end
			end
			if #names > 0 then
				local f = fnOf[nameIdx]
				local stopAt = (f and f > 0) and fns[f].stop or n
				if pcallStyle then names = { names[2] } end
				if cls ~= "always" and #names > 1 then names = { names[1] } end
				for _, v in ipairs(names) do track(v, wholeEnd + 1, stopAt, cls, callName) end
			end
		end
	end

	local function judgeCall(kind, name, nameIdx, full, recv, viaPcall)
		local ctx = ctxOf(nameIdx)
		-- 1. protected / never
		local cur = S.curated[full] or S.curated[name]
		local d
		if kind == "g" then d = S.globals[name] elseif kind == "n" then d = S.ns[full:match("^([^.]+)")] and S.ns[full:match("^([^.]+)")][name] end
		local masked = kind == "g" and info.localFuncs[name] and not (cur and cur.mode == "never")
		if kind ~= "m" and not masked then
			if cur and cur.mode == "never" then
				add("P", full, nameIdx, full .. "(): " .. (cur.note or "blocked") .. " (also from a click handler)", ctx, true)
			elseif d and (d.p or d.so) then
				add("P", full, nameIdx, full .. "() is protected / secure-only: blocked from addon code", ctx, true)
			elseif cur and cur.mode == "hw" then add("H", full, nameIdx, full .. "() needs a hardware click (unmeasured list)", ctx, false)
			elseif cur and cur.mode == "combat" then add("C", full, nameIdx, full .. "() is blocked in combat", ctx, false)
			end
		elseif kind == "m" and cur and cur.mode == "never" then
			add("P", name, nameIdx, name .. "(): " .. (cur.note or "blocked"), ctx, true)
		end
		-- 2. undocumented
		local doc
		if kind == "g" then doc = S.globals[name] or S.curated[name] or S.blizz[name] or LUAX[name] or S.called.g[name] or info.locals[name] or X.globalDefs[name]
		elseif kind == "n" then doc = d or S.called.n[full] or S.curated[full]
		else doc = S.methods[name] or S.called.m[name] or LUAX[name] or STRMETH[name] or X.fieldDefs[name] or info.fieldDefs[name] or S.curated[name] end
		if not doc then
			local label = (kind == "m" and ":" or "") .. full
			if viaPcall or guarded(name, nameIdx) then add("G", label, nameIdx, label .. " is not in the API docs (behind its own test / pcall: information)", ctx, false)
			else add("U", label, nameIdx, label .. " is not in the API docs for this client (nil in the game)", ctx, X.gateU) end
		end
		-- 3. secret answers
		local md
		if kind == "m" then md = S.methods[name] else md = d end
		local cls = classify(md, name, X)
		return cls, md
	end

	local i = 1
	while i <= n do
		local t, v = ty[i], va[i]
		if t == "n" then
			local pv, nx, nt = va[i - 1], va[i + 1], ty[i + 1]
			local isCallOpen = (nx == "(" and nt == "o") or nt == "s" or (nx == "{" and nt == "o")
			if pv == "function" or (ty[i - 1] == "k" and pv == "function") then
				-- a definition, not a call
			elseif ty[i - 1] == "o" and pv == ":" and isCallOpen then
				-- method call (or a method definition "function a:b(")
				local j, def = i - 1, false
				for _ = 1, 8 do
					j = j - 1
					if ty[j] == "n" and (va[j - 1] == "." or va[j - 1] == ":") then j = j - 1
					elseif ty[j] == "n" and va[j - 1] == "function" then def = true break
					else break end
				end
				if not def then
					local open = i + 1
					local close = (nx == "(") and matchFwd(ty, va, open, n) or (nx == "{" and matchFwd(ty, va, open, n) or open)
					local recv = ty[i - 2] == "n" and va[i - 2] or nil
					local cls, md = judgeCall("m", v, i, v, recv, false)
					if cls and not (cls == "foreign" and recv and (recv == "self" or info.ownFrames[recv])) then
						secretUse(v, cls, i, exprStart(i), close, false)
					end
				end
			elseif ty[i - 1] == "o" and pv == "." then
				-- C_X.Fn(  or  _G.Name
				if ty[i - 2] == "n" and va[i - 2] == "_G" and not (va[i - 3] == "." or va[i - 3] == ":") then
					local cur = S.curated[v]
					if cur and cur.mode == "never" then add("P", v, i, "_G." .. v .. ": " .. (cur.note or "blocked") .. " (fetched by name)", ctxOf(i), true) end
				elseif isCallOpen and ty[i - 2] == "n" and va[i - 2]:find("^C_") and not (va[i - 3] == "." or va[i - 3] == ":") then
					local ns = va[i - 2]
					local close = (nx == "(" or nx == "{") and matchFwd(ty, va, i + 1, n) or (i + 1)
					local cls = judgeCall("n", v, i, ns .. "." .. v, nil, false)
					if cls then secretUse(ns .. "." .. v, cls, i, i - 2, close, false) end
				end
			elseif isCallOpen and not KW[v] then
				-- a global call, a wrapper call, pcall(f, ...)
				local close = (nx == "(" or nx == "{") and matchFwd(ty, va, i + 1, n) or (i + 1)
				if v == "pcall" and nx == "(" then
					-- pcall(Name, ...) / pcall(C_X.Fn, ...) / pcall(obj.Name, obj, ...)
					local j, segs = i + 2, {}
					while ty[j] == "n" do
						segs[#segs + 1] = va[j]
						if (va[j + 1] == "." or va[j + 1] == ":") and ty[j + 2] == "n" then j = j + 2 else break end
					end
					if #segs > 0 and va[j + 1] == "," then
						if #segs == 1 then
							local cls = judgeCall("g", segs[1], i + 2, segs[1], nil, true)
							if cls then secretUse(segs[1], cls, i + 2, i, close, true) end
						elseif #segs == 2 and segs[1]:find("^C_") then
							local cls = judgeCall("n", segs[2], j, segs[1] .. "." .. segs[2], nil, true)
							if cls then secretUse(segs[1] .. "." .. segs[2], cls, j, i, close, true) end
						else
							local cls = judgeCall("m", segs[#segs], j, segs[#segs], segs[#segs - 1], true)
							if cls and not (cls == "foreign" and (segs[#segs - 1] == "self" or info.ownFrames[segs[#segs - 1]])) then secretUse(segs[#segs], cls, j, i, close, true) end
						end
					end
				elseif not X.skipGlobals then
					local cls = judgeCall("g", v, i, v, nil, false)
					if cls then secretUse(v, cls, i, i, close, false) end
					if WRAP[v] and nx == "(" then
						-- the name is a string: call("Name", ...) / callm(o, "Name", ...)
						local a1 = i + 2
						if ty[a1] == "s" and (va[a1 + 1] == "," or va[a1 + 1] == ")") then
							local nm = va[a1]
							if nm:find("^[%a_][%w_]*$") then
								local c2 = judgeCall("g", nm, a1, nm, nil, false)
								if c2 then secretUse(nm, c2, a1, i, close, false) end
							end
						else
							-- the first top-level comma, then a string argument
							local depth, j = 0, i + 2
							while j < close do
								local vv = va[j]
								if ty[j] == "o" and (vv == "(" or vv == "[" or vv == "{") then depth = depth + 1
								elseif ty[j] == "o" and (vv == ")" or vv == "]" or vv == "}") then depth = depth - 1
								elseif ty[j] == "o" and vv == "," and depth == 0 then break end
								j = j + 1
							end
							if va[j] == "," and ty[j + 1] == "s" and va[j + 2] ~= nil and (va[j + 2] == "," or va[j + 2] == ")") and va[j + 1]:find("^[%a_][%w_]*$") then
								local nm = va[j + 1]
								local recv = (j == i + 3 and ty[i + 2] == "n") and va[i + 2] or nil
								local cls = judgeCall("m", nm, j + 1, nm, recv, false)
								if cls and not (cls == "foreign" and recv and (recv == "self" or info.ownFrames[recv])) then secretUse(nm, cls, j + 1, i, close, false) end
							end
						end
					end
				end
			end
		elseif t == "s" then
			-- a curated "never" name given as a string to a call: gfn("ReloadUI"), rawget(_G, "ReloadUI")
			local cur = S.curated[v]
			if cur and cur.mode == "never" and (va[i - 1] == "(" or va[i - 1] == ",") and (va[i + 1] == ")" or va[i + 1] == ",") and not (va[i - 1] == "(" and ty[i - 2] ~= "n") then
				add("P", v, i, "\"" .. v .. "\": " .. (cur.note or "blocked") .. " (named by a string: fetched at run time)", ctxOf(i), true)
			end
		end
		i = i + 1
	end
end

---------------------------------------------------------------------------------------------------------------------------------
-- the driver
---------------------------------------------------------------------------------------------------------------------------------
local function readAll(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local s = f:read("*a")
	f:close()
	return s
end

-- opts: { S = surface table, files = { {name=, text=} ... } | paths, root, allow = list, gateU }
function SS.scanSources(sources, opts)
	local X = { S = opts.S, gateU = opts.gateU, csaAll = opts.csaAll, fieldDefs = {}, globalDefs = {}, sanitizers = {} }
	local files, ntok = {}, 0
	for _, s in ipairs(sources) do
		local ty, va, li, n = lex(s.text)
		local fnOf, fns, info = structure(ty, va, li, n)
		files[#files + 1] = { name = s.name, ty = ty, va = va, li = li, n = n, fnOf = fnOf, fns = fns, info = info }
		ntok = ntok + n
		for k in pairs(info.fieldDefs) do X.fieldDefs[k] = true end
		for k in pairs(info.assigned) do if not info.locals[k] then X.globalDefs[k] = true end end
		for k in pairs(info.sanitizers) do X.sanitizers[k] = true end
	end
	local out = {}
	for _, F in ipairs(files) do judge(F, X, out) end
	table.sort(out, function(a, b)
		if a.file ~= b.file then return a.file < b.file end
		if a.line ~= b.line then return a.line < b.line end
		return a.kind < b.kind
	end)
	-- the allow list: "static:KIND:name@file" or "static:KIND:name", each with a reason
	local allowed = {}
	for _, e in ipairs(opts.allow or {}) do allowed[e[1]] = e[2] end
	local kept, nAllowed = {}, 0
	for _, f in ipairs(out) do
		local why = allowed["static:" .. f.kind .. ":" .. f.name .. "@" .. f.file] or allowed["static:" .. f.kind .. ":" .. f.name]
		if why then f.allowed = why nAllowed = nAllowed + 1 end
		kept[#kept + 1] = f
	end
	return kept, { files = #files, tokens = ntok, allowed = nAllowed }
end

function SS.loadSurface(path)
	return dofile(path)
end

function SS.run(opts)
	local t0 = os.clock()
	local root = opts.root or "."
	local paths = {}
	for _, toc in ipairs(opts.tocs or { "Wuber/Wuber.toc", "lab/WuberLab/WuberLab.toc" }) do
		local list, err = tocFiles(root, toc)
		if not list then return nil, err end
		for _, p in ipairs(list) do paths[#paths + 1] = p end
	end
	for _, p in ipairs(opts.paths or {}) do paths[#paths + 1] = p end
	local sources = {}
	for _, p in ipairs(paths) do
		local text = readAll(root .. "/" .. p) or readAll(p)
		if text then sources[#sources + 1] = { name = p, text = text } else io.stderr:write("static-surface: cannot read " .. p .. "\n") end
	end
	opts.S = opts.S or SS.loadSurface(root .. "/tests/surface/apisurface.lua")
	if opts.allowFile == nil then opts.allowFile = root .. "/tests/surface/allow.lua" end
	if opts.allowFile and not opts.allow then
		local ok, list = pcall(dofile, opts.allowFile)
		if ok and type(list) == "table" then
			for _, e in ipairs(list) do
				if type(e) ~= "table" or type(e[2]) ~= "string" or #e[2] < 10 then error("allow list: an entry needs { \"key\", \"the reason\" } (" .. tostring(e and e[1]) .. ")") end
			end
			opts.allow = list
		end
	end
	local found, stat = SS.scanSources(sources, opts)
	stat.seconds = os.clock() - t0
	return found, stat
end

function SS.summary(found, stat)
	local c, gate = {}, 0
	for _, f in ipairs(found) do
		if not f.allowed then
			c[f.kind] = (c[f.kind] or 0) + 1
			if f.gate then gate = gate + 1 end
		end
	end
	return c, gate
end

---------------------------------------------------------------------------------------------------------------------------------
-- command line
---------------------------------------------------------------------------------------------------------------------------------
local function main(args)
	local opts, verbose = { tocs = nil, paths = {} }, false
	local i = 1
	local function need() i = i + 1 return args[i] end
	while i <= #args do
		local a = args[i]
		if a == "--help" or a == "-h" then
			local f = io.open((arg and arg[0]) or "tools/surface/static-surface.lua", "rb")
			local text = f and f:read("*a") or ""
			if f then f:close() end
			for l in text:gmatch("[^\n]*") do
				if l:sub(1, 2) == "--" and l ~= "--" then print((l:gsub("^%-%- ?", ""))) elseif l:sub(1, 5) == "local" then break end
			end
			print("Options:\n  --root DIR       repo root (default .)\n  --toc A,B        TOC files, relative to the root (default Wuber/Wuber.toc,lab/WuberLab/WuberLab.toc)\n"
				.. "  --file PATH      judge one more .lua file (repeatable); with --toc none only these\n  --surface FILE   apisurface.lua (default tests/surface/apisurface.lua)\n"
				.. "  --allow FILE     allow list (default tests/surface/allow.lua; entries \"static:KIND:name@file\" with a reason); --allow none\n"
				.. "  --verbose        also print B4c, G, H, C and the allowed findings\n  --csa all        every ConstSecretAccessor method counts as secret on a foreign frame (default: IsEventRegistered HasScript GetScript GetAttribute)\n  --gate-u         U gates too\n  --quiet          summary only")
			return 0
		elseif a == "--root" then opts.root = need()
		elseif a == "--toc" then
			local v = need()
			opts.tocs = {}
			if v ~= "none" then for t in v:gmatch("[^,]+") do opts.tocs[#opts.tocs + 1] = t end end
		elseif a == "--file" then opts.paths[#opts.paths + 1] = need()
		elseif a == "--surface" then opts.S = SS.loadSurface(need())
		elseif a == "--allow" then local v = need() if v == "none" then opts.allowFile = false opts.allow = {} else opts.allowFile = v end
		elseif a == "--verbose" then verbose = true
		elseif a == "--gate-u" then opts.gateU = true
		elseif a == "--csa" then opts.csaAll = (need() == "all")
		elseif a == "--quiet" then opts.quiet = true
		else io.stderr:write("static-surface: unknown option " .. a .. " (try --help)\n") return 2 end
		i = i + 1
	end
	local found, stat = SS.run(opts)
	if not found then io.stderr:write("static-surface: " .. tostring(stat) .. "\n") return 2 end
	local c, gate = SS.summary(found, stat)
	if not opts.quiet then
		for _, f in ipairs(found) do
			local show = (f.gate or f.kind == "U") and not f.allowed or verbose
			if show then print(string.format("%-4s %s:%d  %s  [%s]%s  %s", f.kind, f.file, f.line, f.name, f.ctx or "", f.allowed and " (allowed: " .. f.allowed .. ")" or "", f.msg)) end
		end
	end
	local kinds = {}
	for _, k in ipairs({ "P", "B4", "B4c", "U", "G", "H", "C" }) do kinds[#kinds + 1] = k .. "=" .. (c[k] or 0) end
	print(string.format("static-surface: %d files, %d tokens, %.2f s; %s; allowed %d; gating findings: %d", stat.files, stat.tokens, stat.seconds, table.concat(kinds, " "), stat.allowed, gate))
	print("not checked: taint propagation, a secret returned through a helper in another function, a secret stored in a table and compared later")
	return gate > 0 and 1 or 0
end

if type(arg) == "table" and arg[0] and tostring(arg[0]):gsub("\\", "/"):find("static%-surface%.lua$") then
	os.exit(main(arg))
end
return SS
