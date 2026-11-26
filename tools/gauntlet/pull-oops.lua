-- Wuber 2.4, PC tool: extracts learned wrong-invite chat lines from SavedVariables into JSONL.
-- Usage: lua5.1 tools/gauntlet/pull-oops.lua <saved Wuber.lua file>... [--out tools/gauntlet/oops-lines.jsonl]
-- Library: assert(loadfile("tools/gauntlet/pull-oops.lua"))("library") -> { collect = fn, json = fn }

local mode = ...

local ESC = {
	['"'] = '\\"',
	['\\'] = '\\\\',
	['\b'] = '\\b',
	['\f'] = '\\f',
	['\n'] = '\\n',
	['\r'] = '\\r',
	['\t'] = '\\t',
}

local UNESC = {
	['"'] = '"',
	['\\'] = '\\',
	['/'] = '/',
	b = '\b',
	f = '\f',
	n = '\n',
	r = '\r',
	t = '\t',
}

local function json(s)
	s = tostring(s or "")
	local escaped = s:gsub('[%z\1-\31\\"]', function(c)
		return ESC[c] or string.format("\\u%04x", string.byte(c))
	end)
	return '"' .. escaped .. '"'
end

local function sortedKeys(t)
	local keys = {}
	for k in pairs(t) do
		keys[#keys + 1] = k
	end
	table.sort(keys, function(a, b)
		local ta, tb = type(a), type(b)
		if ta ~= tb then return ta < tb end
		if ta == "number" or ta == "string" then return a < b end
		return tostring(a) < tostring(b)
	end)
	return keys
end

local function collect(db)
	local out, seenTexts, seenTables = {}, {}, {}
	local function addText(text)
		if type(text) ~= "string" or text == "" or text:match("^%s*$") then return end
		if not seenTexts[text] then
			seenTexts[text] = true
			out[#out + 1] = text
		end
	end
	local function walk(t)
		if type(t) ~= "table" or seenTables[t] then return end
		seenTables[t] = true
		for _, k in ipairs(sortedKeys(t)) do
			local v = t[k]
			if type(v) == "table" then
				if k == "oops" and type(v.log) == "table" then
					for _, entry in ipairs(v.log) do
						local text = type(entry) == "table" and entry.text
							or (type(entry) == "string" and entry or nil)
						addText(text)
					end
				end
				walk(v)
			end
		end
	end
	walk(db)
	return out
end

if mode == "library" then
	return { collect = collect, json = json }
end

local function extractText(line)
	local _, pos = line:find('"text"%s*:%s*"')
	if not pos then return nil end
	local buf, i, len = {}, pos + 1, #line
	while i <= len do
		local c = line:sub(i, i)
		if c == '"' then
			return table.concat(buf)
		elseif c == '\\' then
			local nxt = line:sub(i + 1, i + 1)
			if nxt == 'u' then
				local hex = line:sub(i + 2, i + 5)
				local code = tonumber(hex, 16)
				if code and code < 256 then
					buf[#buf + 1] = string.char(code)
					i = i + 6
				else
					buf[#buf + 1] = '\\u'
					i = i + 2
				end
			elseif UNESC[nxt] then
				buf[#buf + 1] = UNESC[nxt]
				i = i + 2
			else
				buf[#buf + 1] = nxt
				i = i + 2
			end
		else
			buf[#buf + 1] = c
			i = i + 1
		end
	end
	return nil
end

local function loadSaved(path)
	local fn, err = loadfile(path)
	if not fn then
		io.stderr:write("pull-oops: cannot load " .. tostring(path) .. ": " .. tostring(err) .. "\n")
		os.exit(1)
	end
	local env = {}
	setfenv(fn, env)
	local ok, runErr = pcall(fn)
	if not ok then
		io.stderr:write("pull-oops: error in " .. tostring(path) .. ": " .. tostring(runErr) .. "\n")
		os.exit(1)
	end
	return env.WuberDB
end

local function main(args)
	local outPath = "tools/gauntlet/oops-lines.jsonl"
	local inputs = {}
	local i = 1
	while i <= #args do
		local a = args[i]
		if a == "--out" then
			i = i + 1
			if not args[i] or args[i] == "" then
				io.stderr:write("pull-oops: --out needs a file path\n")
				os.exit(1)
			end
			outPath = args[i]
		else
			inputs[#inputs + 1] = a
		end
		i = i + 1
	end
	if #inputs == 0 then
		io.stderr:write("Usage: lua5.1 tools/gauntlet/pull-oops.lua <saved Wuber.lua file>... [--out tools/gauntlet/oops-lines.jsonl]\n")
		os.exit(1)
	end

	local existingLines, seenTexts = {}, {}
	local rf = io.open(outPath, "r")
	if rf then
		for ln in rf:lines() do
			if ln:match("%S") then
				existingLines[#existingLines + 1] = ln
				local t = extractText(ln)
				if t then seenTexts[t] = true end
			end
		end
		rf:close()
	end

	local newLines = {}
	for _, path in ipairs(inputs) do
		local db = loadSaved(path)
		if type(db) == "table" then
			for _, text in ipairs(collect(db)) do
				if not seenTexts[text] then
					seenTexts[text] = true
					newLines[#newLines + 1] = '{"text": ' .. json(text)
						.. ', "channel": "whisper", "label": "never-invite", "writer": "oops"}'
				end
			end
		end
	end

	local wf, werr = io.open(outPath, "w")
	if not wf then
		io.stderr:write("pull-oops: cannot write " .. tostring(outPath) .. ": " .. tostring(werr) .. "\n")
		os.exit(1)
	end
	for _, ln in ipairs(existingLines) do wf:write(ln, "\n") end
	for _, ln in ipairs(newLines) do wf:write(ln, "\n") end
	wf:close()

	print(string.format("%d new, %d already there", #newLines, #existingLines))
end

main(type(arg) == "table" and arg or { ... })
