-- fga e: chat and addon-message shapes (docs: ChatInfoDocumentation, ChatConstantsDocumentation).
-- Copy to tests/r49/zz_fgp_07_test.lua. Loaded by tests/run.lua with its helper table T.
--
-- Source-proven parts (Blizzard's API documentation for this client build, Gethe/wow-ui-source @734f065):
--   C_ChatInfo.SendAddonMessage "Returns: result SendAddonMessageResult, Nilable = false"; chatType "defaults to SLASH_CMD_PARTY":
--     https://github.com/Gethe/wow-ui-source/blob/734f065/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua#L516-L533
--   Enum SendAddonMessageResult, 13 values 0-12 (AddOnMessageLockdown = 11, TargetOffline = 12):
--     https://github.com/Gethe/wow-ui-source/blob/734f065/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatConstantsDocumentation.lua#L146-L168
--   C_ChatInfo.RegisterAddonMessagePrefix "Returns: result RegisterAddonMessagePrefixResult" (0 Success, 1 DuplicatePrefix, 2 InvalidPrefix, 3 MaxPrefixes):
--     ChatInfoDocumentation.lua#L468-L483 and ChatConstantsDocumentation.lua#L132-L145
--   CHAT_MSG_WHISPER / CHAT_MSG_WHISPER_INFORM payload, 18 values: ChatInfoDocumentation.lua#L2591-L2618 (WHISPER), #L2619-L2646 (INFORM)
-- Engine-side parts (is the realm restricted, which event a refusal fires, the throttle budget, sizes, offline answer, sender spelling)
-- cannot be settled from source: the last test reads tests/fixtures/rec/real-send-matrix.lua (made from the Lab's "Send matrix", probe.lua).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local H = T.H
local A, B = T.TESTCHAR, T.ANITA
local PREFIX = "FGP07"

local function pack(...) return { n = select("#", ...), ... } end

-- two plain windows (no Wuber, so no other addon messages), in one party, both listening for PREFIX
local function twoWindows(w)
	local a = w:addClient(A, { spot = "Orgrimmar", class = "MAGE", addons = {}, allowMissing = true })
	local b = w:addClient(B, { spot = "Orgrimmar", class = "WARLOCK", addons = {}, allowMissing = true })
	w:group({ A, B })
	a.env.C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
	b.env.C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
	return a, b
end

-- every time the window gets this event: { n = number of values, [1..n] = the values }
local function capture(c, event)
	local got = {}
	local f = c.env.CreateFrame("Frame")
	f:RegisterEvent(event)
	f:SetScript("OnEvent", function(_, _, ...) got[#got + 1] = pack(...) end)
	return got
end

---------------------------------------------------------------------------------------------------------------
-- Source-proven
---------------------------------------------------------------------------------------------------------------

-- ChatInfoDocumentation.lua#L529-L532: the result is not nilable. The enum has a code for each of these cases (InvalidPrefix,
-- InvalidMessage, InvalidChatType, TargetRequired, InvalidChannel), which an API that raised would not need. The exact number of
-- each case follows the enum's names; only the engine can confirm them (the last test does, from the recording).
local CASES = {
	{ "an empty prefix", "", "x", "PARTY" },
	{ "a 256-byte text", PREFIX, string.rep("x", 256), "PARTY" },
	{ "an unknown chat type", PREFIX, "x", "FGP07BOGUS" },
	{ "a whisper with no target", PREFIX, "x", "WHISPER" },
	{ "a channel message with no channel number", PREFIX, "x", "CHANNEL" },
}
test("fga e SendAddonMessage answers invalid input with a result number and raises no Lua error", function()
	local w = T.newWorld()
	local a = twoWindows(w)
	local send = a.env.C_ChatInfo.SendAddonMessage
	for _, case in ipairs(CASES) do
		local okc, res = pcall(send, case[2], case[3], case[4], case[5])
		ok(okc, case[1] .. ": raised a Lua error: " .. tostring(res))
		eq(type(res), "number", case[1] .. ": the answer")
		ok(res ~= 0, case[1] .. ": answered 0 (Success) for something the game cannot send")
	end
	-- (the 256-byte text is still the addon's mistake and the fake may keep noting it: this test is about the answer)
	w.violations = {}
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
end)

-- ChatInfoDocumentation.lua#L525: chatType, Nilable = true, "ChatType, defaults to SLASH_CMD_PARTY."
test("fga e SendAddonMessage with no chat type goes to the party", function()
	local w = T.newWorld()
	local a, b = twoWindows(w)
	local heard = capture(b, "CHAT_MSG_ADDON")
	local okc, res = pcall(a.env.C_ChatInfo.SendAddonMessage, PREFIX, "hello")
	ok(okc, "raised a Lua error: " .. tostring(res))
	eq(res, 0, "the result (Success)")
	w:advance(0.5)
	eq(#heard, 1, "the other window heard one message")
	eq(heard[1][1], PREFIX, "its prefix")
	eq(heard[1][3], "PARTY", "its channel")
	T.clean(w)
end)

-- ChatConstantsDocumentation.lua#L146-L168 (NumValues = 13, MinValue 0, MaxValue 12) and #L132-L145 (4 values)
local SEND_RESULT = { Success = 0, InvalidPrefix = 1, InvalidMessage = 2, AddonMessageThrottle = 3, InvalidChatType = 4, NotInGroup = 5,
	TargetRequired = 6, InvalidChannel = 7, ChannelThrottle = 8, GeneralError = 9, NotInGuild = 10, AddOnMessageLockdown = 11, TargetOffline = 12 }
local REGISTER_RESULT = { Success = 0, DuplicatePrefix = 1, InvalidPrefix = 2, MaxPrefixes = 3 }

local function enumProblems(have, want)
	local bad, count = {}, 0
	if type(have) ~= "table" then return { "the table is missing" }, 0 end
	for k in pairs(have) do count = count + 1 end
	for k, v in pairs(want) do
		if have[k] ~= v then bad[#bad + 1] = k .. " is " .. tostring(have[k]) .. ", wanted " .. v end
	end
	table.sort(bad)
	return bad, count
end

test("fga e Enum.SendAddonMessageResult has the 13 documented names 0 to 12, and RegisterAddonMessagePrefixResult the 4", function()
	local w = T.newWorld()
	local a = twoWindows(w)
	local E = a.env.Enum
	local bad, count = enumProblems(E.SendAddonMessageResult, SEND_RESULT)
	ok(#bad == 0, "Enum.SendAddonMessageResult: " .. table.concat(bad, "; "))
	eq(count, 13, "Enum.SendAddonMessageResult has this many entries")
	bad, count = enumProblems(E.RegisterAddonMessagePrefixResult, REGISTER_RESULT)
	ok(#bad == 0, "Enum.RegisterAddonMessagePrefixResult: " .. table.concat(bad, "; "))
	eq(count, 4, "Enum.RegisterAddonMessagePrefixResult has this many entries")
	T.clean(w)
end)

-- ChatInfoDocumentation.lua#L479-L482 ("Returns: result RegisterAddonMessagePrefixResult"; the call "cannot be an empty string", L472).
-- Wuber ignores the answer (Wuber/Net/Inbox.lua:214-216), so nothing changes for it; the number follows the enum's names.
test("fga e RegisterAddonMessagePrefix answers with a number: 0, then 1 for the same prefix again, 2 for an empty one", function()
	local w = T.newWorld()
	local a = twoWindows(w)
	local reg = a.env.C_ChatInfo.RegisterAddonMessagePrefix
	local okc, r = pcall(reg, "FGP07X")
	ok(okc, "a new prefix raised a Lua error: " .. tostring(r))
	eq(r, 0, "a new prefix (Success)")
	okc, r = pcall(reg, "FGP07X")
	ok(okc, "the same prefix again raised a Lua error: " .. tostring(r))
	eq(r, 1, "the same prefix again (DuplicatePrefix)")
	okc, r = pcall(reg, "")
	ok(okc, "an empty prefix raised a Lua error: " .. tostring(r))
	eq(r, 2, "an empty prefix (InvalidPrefix)")
	T.clean(w)
end)

-- CHAT_MSG_WHISPER and CHAT_MSG_WHISPER_INFORM: 18 values (text, playerName, languageName, channelName, playerName2, specialFlags,
-- zoneChannelID, channelIndex, channelBaseName, languageID, lineID, guid, bnSenderID, isMobile, isSubtitle, hideSenderInLetterbox,
-- suppressRaidIcons, discordInfo). The fake gives 12 (tests/harness.lua:3410, 3412, 3424). Wuber reads only the first few.
test("fga e CHAT_MSG_WHISPER and CHAT_MSG_WHISPER_INFORM carry the 18 documented values", function()
	local w = T.newWorld()
	local a, b = twoWindows(w)
	local atB, informA = capture(b, "CHAT_MSG_WHISPER"), capture(a, "CHAT_MSG_WHISPER_INFORM")
	ok(w:whisper(a, B, "hello there", "user"), "control: the whisper went")
	w:advance(0.5)
	eq(#atB, 1, "the receiver got one CHAT_MSG_WHISPER")
	eq(#informA, 1, "the sender got one CHAT_MSG_WHISPER_INFORM")
	eq(atB[1].n, 18, "values in CHAT_MSG_WHISPER")
	eq(informA[1].n, 18, "values in CHAT_MSG_WHISPER_INFORM")
	eq(type(atB[1][13]), "number", "bnSenderID")
	for i = 14, 17 do eq(type(atB[1][i]), "boolean", "value " .. i .. " (isMobile, isSubtitle, hideSenderInLetterbox, suppressRaidIcons)") end
	T.clean(w)
end)

-- the documented order: the documented order: text, playerName, languageName, channelName, playerName2,
-- specialFlags, zoneChannelID, channelIndex, channelBaseName, languageID, lineID, guid.
-- guard: the first 12 values were right on the base and stay in place
test("fga e the first 12 values of CHAT_MSG_WHISPER keep their places", function()
	local w = T.newWorld()
	local a, b = twoWindows(w)
	local atB = capture(b, "CHAT_MSG_WHISPER")
	w:whisper(a, B, "hello there", "user")
	w:advance(0.5)
	local g = atB[1]
	ok(g and g.n >= 12, "control: the event came with at least 12 values")
	eq(g[1], "hello there", "text")
	eq(g[2], A, "playerName")
	eq(g[3], "", "languageName")
	eq(g[4], "", "channelName")
	eq(g[5], A, "playerName2")
	eq(g[6], "", "specialFlags")
	eq(g[7], 0, "zoneChannelID")
	eq(g[8], 0, "channelIndex")
	eq(g[9], "", "channelBaseName")
	eq(g[10], 0, "languageID")
	eq(type(g[11]), "number", "lineID")
	eq(type(g[12]), "string", "guid")
	T.clean(w)
end)


-- the other chat events: channel, notice, guild, system (and the guild and channel lines other windows send)
test("fga e CHAT_MSG_CHANNEL_NOTICE, _USER, GUILD and SYSTEM carry 18 values, and a plain chat line keeps its first values", function()
	local w = T.newWorld()
	local a = twoWindows(w)
	for _, ev in ipairs({ "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER", "CHAT_MSG_GUILD", "CHAT_MSG_SYSTEM", "CHAT_MSG_CHANNEL" }) do
		local got = capture(a, ev)
		a:fire(ev, "text one", "who")
		eq(#got, 1, ev .. " came")
		eq(got[1].n, 18, "values in " .. ev)
		eq(got[1][1], "text one", ev .. " first value kept")
		eq(got[1][2], "who", ev .. " second value kept")
		eq(type(got[1][13]), "number", ev .. " bnSenderID")
		eq(type(got[1][14]), "boolean", ev .. " isMobile")
	end
	T.clean(w)
end)

-- guard: an already-complete 18-value call is passed on untouched (no padding on top)
test("fga e a chat event fired with 18 values keeps exactly 18", function()
	local w = T.newWorld()
	local a = twoWindows(w)
	local got = capture(a, "CHAT_MSG_WHISPER")
	a:fire("CHAT_MSG_WHISPER", "t", "p", "", "", "p", "", 0, 0, "", 0, 7, "g", 5, true, false, false, false, "d")
	eq(got[1].n, 18, "values")
	eq(got[1][13], 5, "bnSenderID kept")
	eq(got[1][14], true, "isMobile kept")
	T.clean(w)
end)

-- a good addon message still returns 0 and reaches the party; a text over 255 bytes is answered 2 and is still a violation (not a guard: the base raised)
test("fga e a good party message still goes; an over-long text is refused with 2 and noted", function()
	local w = T.newWorld()
	local a, b = twoWindows(w)
	local heard = capture(b, "CHAT_MSG_ADDON")
	eq(a.env.C_ChatInfo.SendAddonMessage(PREFIX, "hello", "PARTY"), 0, "result")
	w:advance(1)
	eq(#heard, 1, "heard")
	eq(a.env.C_ChatInfo.SendAddonMessage(PREFIX, string.rep("x", 256), "PARTY"), 2, "over-long")
	eq(#w.violations, 1, "noted as a violation")
	w:advance(5)
	eq(#heard, 1, "the long one was not delivered")
	w.violations = {}
	T.clean(w)
end)
