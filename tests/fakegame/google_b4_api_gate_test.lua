-- tests/fakegame/google_b4_api_gate_test.lua: gate ensuring every client API name Wuber calls
-- (scanned from Wuber/Wuber.toc against tests/surface/apisurface.lua) has a row in exactly one
-- tests/fixtures/client/api/*.lua file, and no ledger row is stale (no longer called by Wuber).
local T = ...
local H = T.H
local test, ok = T.test, T.ok

local KW = {}
for w in ("and break do else elseif end false for function if in local nil not or repeat return then true until while"):gmatch("%a+") do
	KW[w] = true
end

local STDLIB = {}
for w in ([[strsplit strjoin strtrim strlen strsub strupper strlower strfind strmatch strrep strbyte strchar strrev strconcat strlenutf8
	strcmputf8i format gsub gmatch tinsert tremove wipe tContains tIndexOf foreach foreachi getn sort max min floor ceil abs sqrt random
	mod fmod difftime loadstring loadfile dofile setfenv getfenv xpcall pcall tostringall tonumber tostring ipairs pairs next unpack
	select type rawget rawset rawequal assert error print setmetatable getmetatable collectgarbage gcinfo require module newproxy
	load string table math os io coroutine bit byte find match sub lower upper len rep reverse]]):gmatch("%S+") do
	STDLIB[w] = true
end

local WUBER_NS = { W = true, UI = true, DR = true, D = true, T = true, FX = true, A = true, Mod = true }

local function lex(src)
	local ty, va, n = {}, {}, 0
	local pos, len = 1, #src
	local find, sub, byte = string.find, string.sub, string.byte
	if sub(src, 1, 2) == "#!" then pos = find(src, "\n", 1, true) or len end
	while pos <= len do
		local s, e = find(src, "^[ \t\r\n]+", pos)
		if s then pos = e + 1 end
		if pos > len then break end
		local c = sub(src, pos, pos)
		if c == "-" and sub(src, pos + 1, pos + 1) == "-" then
			local eq = src:match("^%[(=*)%[", pos + 2)
			if eq then
				local close = "]" .. eq .. "]"
				local _, ce = find(src, close, pos + 4 + #eq, true)
				pos = (ce or len) + 1
			else
				pos = find(src, "\n", pos, true) or (len + 1)
			end
		else
			local b = byte(c)
			n = n + 1
			if (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b == 95 then
				local _, ne = find(src, "^[%w_]*", pos + 1)
				local w = sub(src, pos, ne)
				ty[n] = KW[w] and "k" or "n"
				va[n] = w
				pos = ne + 1
			elseif (b >= 48 and b <= 57) or (c == "." and find(src, "^%d", pos + 1)) then
				local _, ne = find(src, "^0[xX]%x*", pos)
				if not ne then
					_, ne = find(src, "^%d*%.?%d*", pos)
					local _, ee = find(src, "^[eE][+-]?%d+", ne + 1)
					if ee then ne = ee end
				end
				ty[n] = "d"
				va[n] = sub(src, pos, ne)
				pos = ne + 1
			elseif c == '"' or c == "'" then
				local p = pos + 1
				while true do
					local q = find(src, "[\\\n" .. c .. "]", p)
					if not q then p = len + 1 break end
					local ch = sub(src, q, q)
					if ch == "\\" then p = q + 2
					elseif ch == "\n" then p = q break
					else p = q break end
				end
				ty[n] = "s"
				va[n] = sub(src, pos + 1, p - 1)
				pos = p + 1
			elseif c == "[" and find(src, "^%[=*%[", pos) then
				local eq = src:match("^%[(=*)%[", pos)
				local close = "]" .. eq .. "]"
				local _, ce = find(src, close, pos + 2 + #eq, true)
				ce = ce or len
				ty[n] = "s"
				va[n] = sub(src, pos + 2 + #eq, ce - #close)
				pos = ce + 1
			else
				local op = sub(src, pos, pos + 2)
				if op == "..." then pos = pos + 3
				else
					op = sub(src, pos, pos + 1)
					if op == ".." or op == "==" or op == "~=" or op == "<=" or op == ">=" then pos = pos + 2
					else op = c pos = pos + 1 end
				end
				ty[n] = "o"
				va[n] = op
			end
		end
	end
	return ty, va, n
end

local function tocFiles(root, toc)
	local f = assert(io.open(root .. "/" .. toc, "rb"))
	local dir = toc:match("^(.*)/[^/]*$") or "."
	local out = {}
	for l in f:lines() do
		l = l:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
		if l ~= "" and l:sub(1, 1) ~= "#" and l:lower():find("%.lua$") then
			out[#out + 1] = dir .. "/" .. l:gsub("\\", "/")
		end
	end
	f:close()
	return out
end

local function scanCalledApis(root, S)
	local files = tocFiles(root, "Wuber/Wuber.toc")
	local wuberMethodDefs, wuberGlobalDefs, parsed = {}, {}, {}

	for _, rel in ipairs(files) do
		local f = assert(io.open(root .. "/" .. rel, "rb"))
		local src = f:read("*a")
		f:close()
		local ty, va, n = lex(src)
		parsed[#parsed + 1] = { rel = rel, ty = ty, va = va, n = n }
		for i = 1, n do
			if ty[i] == "k" and va[i] == "function" and ty[i + 1] == "n" then
				local q = i + 1
				local last, chain = va[q], 1
				while (va[q + 1] == "." or va[q + 1] == ":") and ty[q + 2] == "n" do
					q = q + 2
					last = va[q]
					chain = chain + 1
				end
				if chain > 1 then wuberMethodDefs[last] = true
				elseif va[i - 1] ~= "local" then wuberGlobalDefs[last] = true end
			end
		end
	end

	local function isClientMethod(v)
		if STDLIB[v] or v:find("^On[A-Z]") then return false end
		if S.methods[v] then
			if wuberMethodDefs[v] and (v == "IsPaused" or v == "GetView" or v == "RegisterCallback") then
				return false
			end
			return true
		end
		return S.called.m[v] and not wuberMethodDefs[v]
	end

	local function isClientNs(ns, fn)
		local full = ns .. "." .. fn
		return (S.ns[ns] and S.ns[ns][fn]) or S.called.n[full] or S.curated[full]
	end

	local function isClientGlobal(v)
		if STDLIB[v] or wuberGlobalDefs[v] then return false end
		return S.globals[v] or S.curated[v] or S.blizz[v] or S.called.g[v]
	end

	local found = {}
	for _, F in ipairs(parsed) do
		local ty, va, n = F.ty, F.va, F.n
		local locals, nsInFile, nsAlias = {}, {}, {}
		for i = 1, n do
			local t, v = ty[i], va[i]
			if t == "k" and v == "local" then
				if ty[i + 1] == "k" and va[i + 1] == "function" and ty[i + 2] == "n" then
					locals[va[i + 2]] = true
				elseif ty[i + 1] == "n" then
					local j = i + 1
					while ty[j] == "n" do
						locals[va[j]] = true
						if va[j + 1] == "," then j = j + 2 else break end
					end
				end
			elseif t == "k" and v == "function" then
				local j = i + 1
				while ty[j] == "n" or va[j] == "." or va[j] == ":" do j = j + 1 end
				if va[j] == "(" then
					j = j + 1
					while j <= n and va[j] ~= ")" do
						if ty[j] == "n" then locals[va[j]] = true end
						j = j + 1
					end
				end
			elseif t == "k" and v == "for" then
				local j = i + 1
				while j <= n and va[j] ~= "=" and va[j] ~= "in" do
					if ty[j] == "n" then locals[va[j]] = true end
					j = j + 1
				end
			elseif t == "n" and v:find("^C_") then
				nsInFile[v] = true
				if va[i - 1] == "=" and ty[i - 2] == "n" and not (va[i + 1] == "." or va[i + 1] == ":") then
					nsAlias[va[i - 2]] = v
				end
			elseif t == "s" and v:find("^C_[A-Za-z0-9_]+$") and S.ns[v] then
				nsInFile[v] = true
			end
		end
		if F.rel == "Wuber/Net/Community.lua" then nsAlias["CX"] = "C_Club" end

		for i = 1, n do
			local t, v = ty[i], va[i]
			if t == "n" then
				local pv, nx, nt = va[i - 1], va[i + 1], ty[i + 1]
				local isCallOpen = (nx == "(" and nt == "o") or nt == "s" or (nx == "{" and nt == "o")
				if pv == "function" then
					-- definition
				elseif pv == ":" and ty[i - 1] == "o" then
					if isCallOpen and isClientMethod(v) then found[":" .. v] = true end
				elseif pv == "." and ty[i - 1] == "o" then
					local owner = ty[i - 2] == "n" and va[i - 2] or nil
					if owner and owner:find("^C_") then
						if isClientNs(owner, v) then found[owner .. "." .. v] = true end
					elseif owner and nsAlias[owner] then
						local ns = nsAlias[owner]
						if isClientNs(ns, v) then found[ns .. "." .. v] = true end
					elseif not (owner and (WUBER_NS[owner] or owner:find("Mod$"))) then
						for ns in pairs(nsInFile) do
							if isClientNs(ns, v) then found[ns .. "." .. v] = true end
						end
						local j = i - 1
						while j > 2 and va[j] == "." and ty[j - 1] == "n" do j = j - 2 end
						if va[j] == "(" and va[j - 1] == "pcall" and owner ~= "api" and isClientMethod(v) then
							found[":" .. v] = true
						elseif v == "AddMessage" then
							found[":" .. v] = true
						end
					end
				elseif not (pv == "." or pv == ":") then
					if not locals[v] and isClientGlobal(v) and not (nx == "=" and nt == "o") then
						found[v] = true
					end
				end
			elseif t == "s" then
				if va[i - 1] == "," and ty[i - 2] == "n" and va[i - 2] == "_G" and va[i - 3] == "(" and va[i - 4] == "rawget" then
					if isClientGlobal(v) then found[v] = true end
				elseif va[i - 1] == "(" and ty[i - 2] == "n" and (va[i - 2] == "call" or va[i - 2] == "api") and va[i - 3] == "." and va[i - 4] == "CX" then
					if isClientNs("C_Club", v) then found["C_Club." .. v] = true end
				elseif va[i - 1] == "," and (va[i + 1] == "," or va[i + 1] == ")") then
					local j = i - 2
					while j > 1 and j > i - 10 do
						if va[j] == "(" and ty[j - 1] == "n" and (va[j - 1] == "call" or va[j - 1] == "ask" or va[j - 1] == "Try" or va[j - 1] == "callm" or va[j - 1] == "askm") then
							if isClientMethod(v) then found[":" .. v] = true end
							break
						end
						j = j - 1
					end
				elseif (va[i - 1] == "{" or va[i - 1] == ",") and (va[i + 1] == "," or va[i + 1] == "}") then
					if (S.globals[v] or (S.called.g[v] and v:find("^[A-Z]") and #v >= 6 and not v:find("^On[A-Z]") and not S.methods[v]))
						and not STDLIB[v] and not wuberGlobalDefs[v] and not v:find("^[A-Z0-9_]+$") then
						found[v] = true
					else
						for ns in pairs(nsInFile) do
							if isClientNs(ns, v) then found[ns .. "." .. v] = true end
						end
					end
				end
			end
		end
	end
	return found
end

test("b4 api gate: every called client API has a unique ledger row and no row is stale", function()
	local root = T.dir .. "/.."
	local S = assert(dofile(T.dir .. "/surface/apisurface.lua"))
	local called = scanCalledApis(root, S)

	local apiDir = T.dir .. "/fixtures/client/api"
	local inLedgers, dupes = {}, {}
	for _, path in ipairs(H.listFiles(apiDir, "lua")) do
		local file = path:match("([^/\\]+)$")
		local rows = assert(loadfile(path))()
		ok(type(rows) == "table", file .. " returns a table")
		for _, row in ipairs(rows) do
			if type(row) == "table" and type(row.name) == "string" and row.name ~= "" then
				if inLedgers[row.name] then
					dupes[#dupes + 1] = row.name .. " (" .. inLedgers[row.name] .. " & " .. file .. ")"
				else
					inLedgers[row.name] = file
				end
			end
		end
	end

	-- chat.lua records AddMessage without a leading colon; normalize if present
	if called[":AddMessage"] and inLedgers["AddMessage"] and not inLedgers[":AddMessage"] then
		called[":AddMessage"] = nil
		called["AddMessage"] = true
	end

	local missing, stale = {}, {}
	for name in pairs(called) do
		if not inLedgers[name] then missing[#missing + 1] = name end
	end
	for name, file in pairs(inLedgers) do
		if not called[name] then stale[#stale + 1] = name .. " (" .. file .. ")" end
	end

	table.sort(dupes)
	table.sort(missing)
	table.sort(stale)

	ok(#missing == 0, #missing .. " called API(s) with no row in tests/fixtures/client/api/*.lua:\n  " .. table.concat(missing, "\n  "))
	ok(#dupes == 0, #dupes .. " API(s) present in two family files:\n  " .. table.concat(dupes, "\n  "))
	ok(#stale == 0, #stale .. " ledger row(s) no longer called by Wuber:\n  " .. table.concat(stale, "\n  "))
end)
