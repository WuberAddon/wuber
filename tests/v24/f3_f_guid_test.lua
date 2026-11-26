-- Wuber 2.4 fix round 3, group F: the sender's GUID (chat event argument 12) is kept beside the name on a
-- rider or lead record, so a later whisper or group fact for the same person under another name shape matches
-- it. In-memory only. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function setup()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	T.goOnline(d)
	w:advance(2)
	return w, d, d.W.Drive
end

local function count(DR)
	local n = 0
	for _ in pairs(DR.customers) do n = n + 1 end
	return n
end

-- the game hands over the first name only on a whisper (sender "Bob"); the group then lists "Bob Stone"
local function whisperAs(w, d, shortName, text, guid)
	w:addBot(T.BOB, {})
	w:advance(1)
	d:chatEvent("CHAT_MSG_WHISPER", text, shortName, "", "", shortName, "", 0, 0, "", 0, 4242, guid)
	w:advance(2)
end

test("v24 f3 guid: a whisper from a first name, then the same player in the group as two names, is one row", function()
	local w, d, DR = setup()
	local guid = "Player-1-bob stone"
	whisperAs(w, d, "Bob", "hello there", guid)
	local c = DR.customers["bob"]
	ok(c, "the whisper made a record under the name it came with")
	eq(c and c.guid, guid, "the GUID is kept beside the name")
	w:join(d.player, w:player(T.BOB))
	w:advance(3)
	eq(count(DR), 1, "one row, not two")
	eq(DR.customers["bob"] and DR.customers["bob"].state, "joined", "the lead is the one that joined")
	ok(DR.units["bob"], "the group unit is found under the record's key")
	T.clean(w)
end)

test("v24 f3 guid: a later whisper under another name shape finds the same record by GUID", function()
	local w, d, DR = setup()
	local guid = "Player-1-bob stone"
	whisperAs(w, d, "Bob", "hello there", guid)
	d:chatEvent("CHAT_MSG_WHISPER", "hello?", "Stone Bob", "", "", "Stone Bob", "", 0, 0, "", 0, 4243, guid)
	w:advance(1)
	eq(count(DR), 1, "still one record")
	eq(DR.customers["bob"] and DR.customers["bob"].msg, "hello?", "the second whisper went to it")
	T.clean(w)
end)

test("v24 f3 guid: a record made for somebody else while a line is handled never takes that line's GUID", function()
	local w, d, DR = setup()
	local guid = "Player-1-bob stone"
	whisperAs(w, d, "Bob", "hello there", guid)
	eq(DR.customers["bob"] and DR.customers["bob"].guid, guid, "the sender's own record has it")
	for k, c in pairs(DR.customers) do
		if k ~= "bob" then eq(c.guid, nil, "no other record holds this GUID: " .. k) end
	end
	T.clean(w)
end)

test("v24 f3 guid: a secret or missing GUID changes nothing", function()
	local w, d, DR = setup()
	whisperAs(w, d, "Bob", "hello there", nil)
	local c = DR.customers["bob"]
	ok(c, "a lead without a GUID")
	eq(c and c.guid, nil, "nothing kept")
	T.clean(w)
	local w2, d2, DR2 = setup()
	d2.secrets.guid = true
	w2:addBot(T.BOB, {})
	w2:botWhisper(T.BOB, d2, "hello there")
	w2:advance(2)
	local c2 = DR2.customers["bob stone"] or DR2.customers["bob"]
	ok(c2, "the whisper still makes its record with a secret GUID")
	eq(c2 and c2.guid, nil, "a secret GUID is never kept")
	T.clean(w2)
end)
