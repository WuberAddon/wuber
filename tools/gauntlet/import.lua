-- Wuber 2.4, chat gauntlet importer: reads JSON and JSONL chat-line batches, drops empty/invalid/duplicate lines,
-- strips names and notes, and writes the Lua fixture tests/fixtures/gauntlet/chat-lines.lua.
-- Usage: lua5.1 tools/gauntlet/import.lua [--out tests/fixtures/gauntlet/chat-lines.lua] <input file>...

local VALID_LABELS = {
	invite = true,
	["never-invite"] = true,
	unclear = true,
}

local SIMPLE_ESCAPES = {
	[34] = '"',
	[92] = "\\",
	[47] = "/",
	[98] = string.char(8),
	[102] = string.char(12),
	[110] = "\n",
	[114] = "\r",
	[116] = "\t",
}

local function trim(s)
	s = s:gsub("^%s+", "")
	s = s:gsub("%s+$", "")
	return s
end

local function encodeUtf8(cp)
	if cp <= 0x7F then
		return string.char(cp)
	elseif cp <= 0x7FF then
		return string.char(
			192 + math.floor(cp / 64),
			128 + (cp % 64)
		)
	elseif cp <= 0xFFFF then
		return string.char(
			224 + math.floor(cp / 4096),
			128 + (math.floor(cp / 64) % 64),
			128 + (cp % 64)
		)
	else
		return string.char(
			240 + math.floor(cp / 262144),
			128 + (math.floor(cp / 4096) % 64),
			128 + (math.floor(cp / 64) % 64),
			128 + (cp % 64)
		)
	end
end

local function decode(text)
	if type(text) ~= "string" then
		return nil, "expected JSON string"
	end
	if text:sub(1, 3) == "\239\187\191" then
		text = text:sub(4)
	end
	local pos = 1
	local len = #text

	local function skipWs()
		while pos <= len do
			local b = text:byte(pos)
			if b == 32 or b == 9 or b == 10 or b == 13 then
				pos = pos + 1
			else
				break
			end
		end
	end

	local function parseUnicodeEscape()
		if pos + 3 > len then
			return nil, "incomplete \\u escape"
		end
		local hex = text:sub(pos, pos + 3)
		if not hex:match("^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$") then
			return nil, "invalid \\u escape"
		end
		local cp = tonumber(hex, 16)
		pos = pos + 4
		if cp >= 0xD800 and cp <= 0xDBFF then
			if pos + 5 <= len and text:sub(pos, pos + 1) == "\\u" then
				local hex2 = text:sub(pos + 2, pos + 5)
				if hex2:match("^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$") then
					local cp2 = tonumber(hex2, 16)
					if cp2 >= 0xDC00 and cp2 <= 0xDFFF then
						pos = pos + 6
						cp = 0x10000 + (cp - 0xD800) * 1024 + (cp2 - 0xDC00)
						return encodeUtf8(cp)
					end
				end
			end
			return nil, "unpaired high surrogate"
		elseif cp >= 0xDC00 and cp <= 0xDFFF then
			return nil, "unpaired low surrogate"
		end
		return encodeUtf8(cp)
	end

	local function parseString()
		local parts = {}
		local start = pos
		while pos <= len do
			local b = text:byte(pos)
			if b == 34 then
				if pos > start then
					parts[#parts + 1] = text:sub(start, pos - 1)
				end
				pos = pos + 1
				return table.concat(parts)
			elseif b == 92 then
				if pos > start then
					parts[#parts + 1] = text:sub(start, pos - 1)
				end
				pos = pos + 1
				if pos > len then
					return nil, "unterminated escape in string"
				end
				local esc = text:byte(pos)
				pos = pos + 1
				local simple = SIMPLE_ESCAPES[esc]
				if simple then
					parts[#parts + 1] = simple
				elseif esc == 117 then
					local ustr, uerr = parseUnicodeEscape()
					if not ustr then
						return nil, uerr
					end
					parts[#parts + 1] = ustr
				else
					return nil, "invalid escape in string"
				end
				start = pos
			elseif b < 32 then
				return nil, "unescaped control character in string"
			else
				pos = pos + 1
			end
		end
		return nil, "unterminated string"
	end

	local function parseNumber()
		local start = pos
		if text:byte(pos) == 45 then
			pos = pos + 1
		end
		if pos > len then
			return nil, "invalid number"
		end
		local b = text:byte(pos)
		if b == 48 then
			pos = pos + 1
			local nextB = pos <= len and text:byte(pos) or nil
			if nextB and nextB >= 48 and nextB <= 57 then
				return nil, "leading zero in number"
			end
		elseif b >= 49 and b <= 57 then
			pos = pos + 1
			while pos <= len do
				local d = text:byte(pos)
				if d >= 48 and d <= 57 then
					pos = pos + 1
				else
					break
				end
			end
		else
			return nil, "invalid number"
		end
		if pos <= len and text:byte(pos) == 46 then
			pos = pos + 1
			if pos > len or text:byte(pos) < 48 or text:byte(pos) > 57 then
				return nil, "invalid fraction in number"
			end
			while pos <= len do
				local d = text:byte(pos)
				if d >= 48 and d <= 57 then
					pos = pos + 1
				else
					break
				end
			end
		end
		if pos <= len and (text:byte(pos) == 101 or text:byte(pos) == 69) then
			pos = pos + 1
			if pos <= len and (text:byte(pos) == 43 or text:byte(pos) == 45) then
				pos = pos + 1
			end
			if pos > len or text:byte(pos) < 48 or text:byte(pos) > 57 then
				return nil, "invalid exponent in number"
			end
			while pos <= len do
				local d = text:byte(pos)
				if d >= 48 and d <= 57 then
					pos = pos + 1
				else
					break
				end
			end
		end
		local num = tonumber(text:sub(start, pos - 1))
		if not num then
			return nil, "invalid number"
		end
		return num
	end

	local parseValue

	local function parseObject()
		pos = pos + 1
		skipWs()
		local obj = {}
		if pos <= len and text:byte(pos) == 125 then
			pos = pos + 1
			return obj
		end
		while true do
			skipWs()
			if pos > len or text:byte(pos) ~= 34 then
				return nil, "expected string key at position " .. pos
			end
			pos = pos + 1
			local key, kerr = parseString()
			if kerr then
				return nil, kerr
			end
			skipWs()
			if pos > len or text:byte(pos) ~= 58 then
				return nil, "expected ':' at position " .. pos
			end
			pos = pos + 1
			local val, verr = parseValue()
			if verr then
				return nil, verr
			end
			obj[key] = val
			skipWs()
			if pos > len then
				return nil, "unterminated object"
			end
			local sep = text:byte(pos)
			if sep == 125 then
				pos = pos + 1
				return obj
			elseif sep == 44 then
				pos = pos + 1
			else
				return nil, "expected ',' or '}' at position " .. pos
			end
		end
	end

	local function parseArray()
		pos = pos + 1
		skipWs()
		local arr = {}
		if pos <= len and text:byte(pos) == 93 then
			pos = pos + 1
			return arr
		end
		local idx = 0
		while true do
			local val, verr = parseValue()
			if verr then
				return nil, verr
			end
			idx = idx + 1
			arr[idx] = val
			skipWs()
			if pos > len then
				return nil, "unterminated array"
			end
			local sep = text:byte(pos)
			if sep == 93 then
				pos = pos + 1
				return arr
			elseif sep == 44 then
				pos = pos + 1
			else
				return nil, "expected ',' or ']' at position " .. pos
			end
		end
	end

	parseValue = function()
		skipWs()
		if pos > len then
			return nil, "unexpected end of JSON input"
		end
		local b = text:byte(pos)
		if b == 123 then
			return parseObject()
		elseif b == 91 then
			return parseArray()
		elseif b == 34 then
			pos = pos + 1
			return parseString()
		elseif b == 116 then
			if text:sub(pos, pos + 3) == "true" then
				pos = pos + 4
				return true
			end
			return nil, "invalid literal at position " .. pos
		elseif b == 102 then
			if text:sub(pos, pos + 4) == "false" then
				pos = pos + 5
				return false
			end
			return nil, "invalid literal at position " .. pos
		elseif b == 110 then
			if text:sub(pos, pos + 3) == "null" then
				pos = pos + 4
				return nil, nil
			end
			return nil, "invalid literal at position " .. pos
		elseif b == 45 or (b >= 48 and b <= 57) then
			return parseNumber()
		else
			return nil, "unexpected character at position " .. pos
		end
	end

	local val, err = parseValue()
	if err then
		return nil, err
	end
	skipWs()
	if pos <= len then
		return nil, "trailing characters at position " .. pos
	end
	return val, nil
end

local function fileStem(path)
	local base = path:match("([^/\\]+)$") or path
	return base:match("(.+)%.[^%.]+$") or base
end

local function build(inputs)
	if type(inputs) ~= "table" then
		return nil, "inputs must be a list"
	end
	local entries = {}
	local dropped = 0
	local seen = {}

	local function processItem(item, fallbackWriter, isJsonl)
		local rawText = item.text
		local rawChannel = item.channel
		local lbl = item.label
		if type(rawText) ~= "string" or trim(rawText) == "" then
			dropped = dropped + 1
			return
		end
		if type(rawChannel) ~= "string" or trim(rawChannel) == "" then
			dropped = dropped + 1
			return
		end
		if type(lbl) ~= "string" or not VALID_LABELS[lbl] then
			dropped = dropped + 1
			return
		end
		local ch = string.lower(trim(rawChannel))
		local normText = string.lower(trim(rawText))
		local byChannel = seen[ch]
		if not byChannel then
			byChannel = {}
			seen[ch] = byChannel
		end
		if byChannel[normText] then
			dropped = dropped + 1
			return
		end
		byChannel[normText] = true

		local writer = fallbackWriter
		local isReal = false
		if isJsonl then
			if type(item.source) == "string" and item.source:sub(1, 9) == "real chat" then
				writer = "real"
				isReal = true
			elseif type(item.writer) == "string" and item.writer ~= "" then
				writer = item.writer
			end
		end

		local entry = {
			n = #entries + 1,
			text = rawText,
			channel = ch,
			label = lbl,
			writer = writer,
		}
		if isReal then
			entry.real = true
		end
		entries[#entries + 1] = entry
	end

	for _, inp in ipairs(inputs) do
		if type(inp) ~= "table" or type(inp.name) ~= "string" or type(inp.text) ~= "string" then
			return nil, "invalid input entry"
		end
		local lowerName = string.lower(inp.name)
		local defaultWriter = fileStem(inp.name)
		if lowerName:sub(-6) == ".jsonl" then
			local raw = inp.text
			local pos = 1
			local textLen = #raw
			local lineNo = 0
			while pos <= textLen do
				local nl = raw:find("\n", pos, true)
				local line
				if nl then
					line = raw:sub(pos, nl - 1)
					pos = nl + 1
				else
					line = raw:sub(pos)
					pos = textLen + 1
				end
				lineNo = lineNo + 1
				if line:sub(-1) == "\r" then
					line = line:sub(1, -2)
				end
				if lineNo == 1 and line:sub(1, 3) == "\239\187\191" then
					line = line:sub(4)
				end
				if trim(line) ~= "" then
					local item, err = decode(line)
					if err then
						return nil, inp.name .. ":" .. lineNo .. ": " .. err
					end
					if type(item) ~= "table" or #item > 0 then
						return nil, inp.name .. ":" .. lineNo .. ": expected JSON object"
					end
					processItem(item, defaultWriter, true)
				end
			end
		elseif lowerName:sub(-5) == ".json" then
			local doc, err = decode(inp.text)
			if err then
				return nil, inp.name .. ": " .. err
			end
			if type(doc) ~= "table" or type(doc.lines) ~= "table" then
				return nil, inp.name .. ": expected JSON object with lines array"
			end
			local modelWriter = defaultWriter
			if type(doc.model) == "string" and doc.model ~= "" then
				modelWriter = doc.model
			end
			local count = table.maxn(doc.lines)
			for idx = 1, count do
				local item = doc.lines[idx]
				if type(item) ~= "table" then
					return nil, inp.name .. ": line " .. idx .. " is not an object"
				end
				processItem(item, modelWriter, false)
			end
		else
			return nil, inp.name .. ": unsupported input format"
		end
	end

	return entries, dropped
end

local function quoteLua(s)
	local out = { '"' }
	for i = 1, #s do
		local b = s:byte(i)
		if b == 92 then
			out[#out + 1] = "\\\\"
		elseif b == 34 then
			out[#out + 1] = '\\"'
		elseif b == 10 then
			out[#out + 1] = "\\n"
		elseif b == 13 then
			out[#out + 1] = "\\r"
		elseif b < 32 or b == 127 then
			out[#out + 1] = string.format("\\%03d", b)
		else
			out[#out + 1] = string.char(b)
		end
	end
	out[#out + 1] = '"'
	return table.concat(out)
end

local function render(lines)
	local out = {
		"-- GENERATED by tools/gauntlet/import.lua: do not edit by hand. The chat gauntlet: messy chat lines, each marked",
		'-- "invite" (a rider clearly asking the reader for a summon), "never-invite" (a seller, an advert, anything else) or "unclear".',
		"return {",
		'\tformat = "wuber-gauntlet-1",',
		"\tlines = {",
	}
	for _, entry in ipairs(lines) do
		local suffix = entry.real and ", real = true" or ""
		out[#out + 1] = string.format(
			"\t\t{ n = %d, text = %s, channel = %s, label = %s, writer = %s%s },",
			entry.n,
			quoteLua(entry.text),
			quoteLua(entry.channel),
			quoteLua(entry.label),
			quoteLua(entry.writer),
			suffix
		)
	end
	out[#out + 1] = "\t},"
	out[#out + 1] = "}"
	return table.concat(out, "\n") .. "\n"
end

if select("#", ...) == 1 and (...) == "library" then
	return {
		decode = decode,
		build = build,
		render = render,
	}
end

local function fail(msg)
	io.stderr:write("import.lua: " .. msg .. "\n")
	os.exit(1)
end

local args = arg or { ... }
local outPath = "tests/fixtures/gauntlet/chat-lines.lua"
local inputPaths = {}
local idx = 1
while idx <= #args do
	local a = args[idx]
	if a == "--out" then
		idx = idx + 1
		if idx > #args then
			fail("missing path after --out")
		end
		outPath = args[idx]
	else
		inputPaths[#inputPaths + 1] = a
	end
	idx = idx + 1
end

if #inputPaths == 0 then
	fail("usage: lua5.1 tools/gauntlet/import.lua [--out <path>] <input file>...")
end

local inputs = {}
for _, path in ipairs(inputPaths) do
	local f, err = io.open(path, "rb")
	if not f then
		fail("cannot read " .. path .. ": " .. (err or "unknown error"))
	end
	local content = f:read("*a")
	f:close()
	if not content then
		fail("cannot read " .. path)
	end
	inputs[#inputs + 1] = { name = path, text = content }
end

local entries, droppedOrErr = build(inputs)
if not entries then
	fail(droppedOrErr or "failed to build fixture")
end
local dropped = droppedOrErr

local outputText = render(entries)
local outFile, outErr = io.open(outPath, "wb")
if not outFile then
	fail("cannot write " .. outPath .. ": " .. (outErr or "unknown error"))
end
local okWrite, writeErr = outFile:write(outputText)
outFile:close()
if not okWrite then
	fail("cannot write " .. outPath .. ": " .. (writeErr or "unknown error"))
end

local byLabel = {
	invite = 0,
	["never-invite"] = 0,
	unclear = 0,
}
local byWriter = {}
local writerOrder = {}
for _, entry in ipairs(entries) do
	byLabel[entry.label] = (byLabel[entry.label] or 0) + 1
	if not byWriter[entry.writer] then
		byWriter[entry.writer] = 0
		writerOrder[#writerOrder + 1] = entry.writer
	end
	byWriter[entry.writer] = byWriter[entry.writer] + 1
end

print(string.format(
	"%d lines written to %s (%d invite, %d never-invite, %d unclear; %d dropped)",
	#entries, outPath, byLabel.invite, byLabel["never-invite"], byLabel.unclear, dropped
))
for _, w in ipairs(writerOrder) do
	print(string.format("  %s: %d", w, byWriter[w]))
end
