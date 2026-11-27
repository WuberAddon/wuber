-- Wuber 2.4, chat gauntlet format: proves the chat-lines fixture schema, privacy rules and importer round-trip. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function trim(s)
	s = s:gsub("^%s+", "")
	s = s:gsub("%s+$", "")
	return s
end

test("v24 gauntlet format: every line has a text, a channel and one of three labels, and no line is there twice", function()
	local data = assert(loadfile(T.dir .. "/fixtures/gauntlet/chat-lines.lua"))()
	eq(data.format, "wuber-gauntlet-1", "fixture format")
	ok(type(data.lines) == "table" and #data.lines > 0, "fixture has lines")

	local seen = {}
	local hasReal = false
	local hasAuthor = false
	for i, entry in ipairs(data.lines) do
		eq(entry.n, i, "line n equals position " .. i)
		ok(type(entry.text) == "string" and entry.text ~= "", "line " .. i .. " has non-empty text")
		ok(
			type(entry.channel) == "string" and entry.channel ~= "" and entry.channel == string.lower(entry.channel),
			"line " .. i .. " has lower-case channel"
		)
		ok(
			entry.label == "invite" or entry.label == "never-invite" or entry.label == "unclear",
			"line " .. i .. " has valid label"
		)
		ok(type(entry.writer) == "string" and entry.writer ~= "", "line " .. i .. " has non-empty writer")

		ok(entry.real == nil or entry.real == true, "line " .. i .. " real flag is boolean true when set")

		local key = entry.channel .. "\0" .. string.lower(trim(entry.text))
		ok(not seen[key], "no duplicate (text, channel) at line " .. i)
		seen[key] = true

		if entry.real == true then
			hasReal = true
		end
		if entry.writer == "author" then
			hasAuthor = true
		end
	end

	ok(hasReal, "fixture includes at least one real line")
	ok(hasAuthor, "fixture includes author lines")
end)

test("v24 gauntlet format: the fixture holds no names and no notes", function()
	local data = assert(loadfile(T.dir .. "/fixtures/gauntlet/chat-lines.lua"))()
	ok(type(data.lines) == "table" and #data.lines > 0, "fixture has lines")

	local allowed = {
		n = true,
		text = true,
		channel = true,
		label = true,
		writer = true,
		real = true,
	}
	for i, entry in ipairs(data.lines) do
		for k in pairs(entry) do
			ok(allowed[k] == true, "line " .. i .. " contains only allowed field " .. tostring(k))
		end
	end
end)

test("v24 gauntlet format: the importer reads JSON and JSONL, drops doubles and bad labels, and its output loads back", function()
	local lib = assert(loadfile(T.dir .. "/../tools/gauntlet/import.lua"))("library")

	local jsonInput = [[{
	"model": "test-model",
	"lines": [
		{ "text": "can u \"sum\" me caf\u00e9", "channel": "WHISPER", "label": "invite", "reason": "ignore" },
		{ "text": "  CAN U \"SUM\" ME CAF\u00e9  ", "channel": "whisper", "label": "invite" },
		{ "text": "unknown label line", "channel": "trade", "label": "maybe" }
	]
}]]
	local jsonlInput = table.concat({
		[[{"text":"LF summon to Ratchet","channel":"World","sender":"Mage One","label":"unclear","source":"real chat, screenshot","note":"drop note"}]],
		[[{"text":"WTS ports 1g","channel":"Trade","label":"never-invite","writer":"author"}]],
	}, "\n")

	local entries, dropped = lib.build({
		{ name = "batch.json", text = jsonInput },
		{ name = "mixed.jsonl", text = jsonlInput },
	})

	eq(dropped, 2, "dropped one duplicate and one bad label")
	eq(#entries, 3, "three entries kept")

	eq(entries[1].n, 1, "entry 1 n")
	eq(entries[1].text, 'can u "sum" me caf\195\169', "entry 1 decoded quote and u00e9")
	eq(entries[1].channel, "whisper", "entry 1 lower-cased channel")
	eq(entries[1].label, "invite", "entry 1 label")
	eq(entries[1].writer, "test-model", "entry 1 writer from model")
	eq(entries[1].real, nil, "entry 1 not real")
	eq(entries[1].reason, nil, "entry 1 drops reason")

	eq(entries[2].n, 2, "entry 2 n")
	eq(entries[2].text, "LF summon to Ratchet", "entry 2 text")
	eq(entries[2].channel, "world", "entry 2 lower-cased channel")
	eq(entries[2].label, "unclear", "entry 2 label")
	eq(entries[2].writer, "real", "entry 2 real writer")
	eq(entries[2].real, true, "entry 2 real flag")
	eq(entries[2].sender, nil, "entry 2 drops sender")
	eq(entries[2].note, nil, "entry 2 drops note")

	eq(entries[3].n, 3, "entry 3 n")
	eq(entries[3].text, "WTS ports 1g", "entry 3 text")
	eq(entries[3].channel, "trade", "entry 3 lower-cased channel")
	eq(entries[3].label, "never-invite", "entry 3 label")
	eq(entries[3].writer, "author", "entry 3 writer")
	eq(entries[3].real, nil, "entry 3 not real")

	local rendered = lib.render(entries)
	local loaded = assert(loadstring(rendered))()
	eq(loaded.format, "wuber-gauntlet-1", "rendered format")
	eq(#loaded.lines, #entries, "rendered line count")
	for i = 1, #entries do
		eq(loaded.lines[i].n, entries[i].n, "round-trip n " .. i)
		eq(loaded.lines[i].text, entries[i].text, "round-trip text " .. i)
		eq(loaded.lines[i].channel, entries[i].channel, "round-trip channel " .. i)
		eq(loaded.lines[i].label, entries[i].label, "round-trip label " .. i)
		eq(loaded.lines[i].writer, entries[i].writer, "round-trip writer " .. i)
		eq(loaded.lines[i].real, entries[i].real, "round-trip real " .. i)
	end
end)
