-- Conformance test for tests/fixtures/client/api/chat.lua (Batch 4 Part 5, Lane e1).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local LEDGER_PATH = T.dir .. "/fixtures/client/api/chat.lua"
local VALID_EVIDENCE = {
	["one-real-case"] = true,
	["docs"] = true,
	["borrowed"] = true,
	["guess"] = true,
}

test("b4 api chat: ledger schema, honest evidence, and fake-game conformance", function()
	local rows = assert(dofile(LEDGER_PATH))
	ok(type(rows) == "table" and #rows >= 1, "ledger has rows")

	local seen = {}
	for i, row in ipairs(rows) do
		local tag = "row " .. i .. " (" .. tostring(row.name) .. ")"
		ok(type(row.name) == "string" and row.name ~= "", tag .. " has name")
		ok(not seen[row.name], tag .. " is not duplicated")
		seen[row.name] = true

		ok(type(row.calls) == "number" and row.calls >= 1, tag .. " has calls >= 1")
		ok(type(row.first) == "string" and row.first:find("^Wuber/.+:%d+$") ~= nil, tag .. " has valid first path:line")
		ok(type(row.fake) == "string" and row.fake ~= "", tag .. " has fake description")
		ok(VALID_EVIDENCE[row.evidence], tag .. " has valid evidence word (never measured): " .. tostring(row.evidence))
		ok(type(row.source) == "string" and row.source ~= "", tag .. " has source")

		if row.evidence == "one-real-case" then
			ok(type(row.build) == "string" and row.build ~= "", tag .. " one-real-case has build")
		else
			ok(row.build == nil, tag .. " non-one-real-case has build = nil")
			ok((type(row.game) == "string" and row.game ~= "") or (type(row.offline) == "string" and row.offline ~= ""),
				tag .. " guess/docs/borrowed has game or offline")
		end
	end

	-- Default logged-in fake game
	local w = T.newWorld()
	local c = w:addClient("Anita Lift", { spot = "Orgrimmar", class = "WARLOCK" })
	w:advance(5)

	-- Club-enabled logged-in fake game for C_Club.*
	local wc = T.newWorld({ clubs = true })
	wc:addClub({
		id = 1001,
		name = "Wuber",
		streams = { { streamId = 1, name = "General", streamType = 0 } },
		members = { ["anita lift"] = 4 },
	})
	local cc = wc:addClient("Anita Lift", { spot = "Orgrimmar", class = "WARLOCK" })
	wc:advance(5)

	local byName = {}
	for _, row in ipairs(rows) do byName[row.name] = row end

	-- 1. AddMessage
	ok(byName["AddMessage"], "AddMessage present")
	local cf = c.env.DEFAULT_CHAT_FRAME
	eq(type(cf and cf.AddMessage), "function", "DEFAULT_CHAT_FRAME:AddMessage exists")
	eq(cf:AddMessage("b4-chat-test"), nil, "AddMessage returns nil")

	-- 2. C_ChatInfo.*
	eq(type(c.env.C_ChatInfo), "table", "C_ChatInfo table exists")
	eq(type(c.env.C_ChatInfo.InChatMessagingLockdown), "function", "InChatMessagingLockdown exists")
	eq(c.env.C_ChatInfo.InChatMessagingLockdown(), false, "InChatMessagingLockdown returns false by default")

	eq(type(c.env.C_ChatInfo.RegisterAddonMessagePrefix), "function", "RegisterAddonMessagePrefix exists")
	eq(type(c.env.C_ChatInfo.RegisterAddonMessagePrefix("B4TEST")), "number", "RegisterAddonMessagePrefix returns number")

	eq(type(c.env.C_ChatInfo.RequestCanLocalWhisperTarget), "function", "RequestCanLocalWhisperTarget exists")
	eq(c.env.C_ChatInfo.RequestCanLocalWhisperTarget("Player-1-anita lift"), nil, "RequestCanLocalWhisperTarget returns nil")
	w:advance(0.3)

	eq(type(c.env.C_ChatInfo.SendAddonMessage), "function", "SendAddonMessage exists")
	local sendRes = c.env.C_ChatInfo.SendAddonMessage("B4TEST", "hello", "WHISPER", "Anita Lift")
	eq(type(sendRes), "number", "SendAddonMessage returns number")

	eq(type(c.env.C_ChatInfo.SendChatMessage), "function", "C_ChatInfo.SendChatMessage exists")
	-- Calling SendChatMessage from addon code triggers ADDON_ACTION_BLOCKED, so verify its type without violating clean(w)
	ok(c.env.C_ChatInfo.SendChatMessage == c.env.SendChatMessage, "C_ChatInfo.SendChatMessage aliases SendChatMessage")

	-- 3. C_Club.* (methods are nil in default world; populated in clubs = true world)
	eq(type(c.env.C_Club), "table", "C_Club is table in default world")
	eq(c.env.C_Club.GetSubscribedClubs, nil, "C_Club.GetSubscribedClubs is nil in default world")
	eq(type(cc.env.C_Club), "table", "C_Club is table in clubs = true world")
	eq(type(cc.env.C_Club.AcceptInvitation), "function", "C_Club.AcceptInvitation exists")
	eq(type(cc.env.C_Club.AddClubStreamChatChannel), "function", "C_Club.AddClubStreamChatChannel exists")
	eq(cc.env.C_Club.AddClubStreamChatChannel(1001, 1), nil, "C_Club.AddClubStreamChatChannel returns nil")
	eq(type(cc.env.C_Club.GetSubscribedClubs()), "table", "C_Club.GetSubscribedClubs returns table")
	eq(type(cc.env.C_Club.GetStreams(1001)), "table", "C_Club.GetStreams returns table")
	eq(type(cc.env.C_Club.GetClubMembers(1001)), "table", "C_Club.GetClubMembers returns table")
	eq(type(cc.env.C_Club.GetMemberInfo(1001, 1)), "table", "C_Club.GetMemberInfo returns table")
	eq(type(cc.env.C_Club.GetMemberInfoForSelf(1001)), "table", "C_Club.GetMemberInfoForSelf returns table")
	eq(type(cc.env.C_Club.GetInvitationsForSelf()), "table", "C_Club.GetInvitationsForSelf returns table")

	-- 4. Globals
	eq(c.env.FCF_GetCurrentChatFrame, nil, "FCF_GetCurrentChatFrame is nil (not modelled)")

	eq(type(c.env.GetChannelList), "function", "GetChannelList exists")
	local chIdx, chName, chDisabled = c.env.GetChannelList()
	eq(type(chIdx), "number", "GetChannelList first return is number")
	eq(type(chName), "string", "GetChannelList second return is string")
	eq(type(chDisabled), "boolean", "GetChannelList third return is boolean")

	eq(type(c.env.GetChannelName), "function", "GetChannelName exists")
	local gIdx, gName, gInst, gDisabled = c.env.GetChannelName(1)
	eq(type(gIdx), "number", "GetChannelName index is number")
	eq(type(gName), "string", "GetChannelName name is string")
	eq(type(gInst), "number", "GetChannelName instance is number")
	eq(type(gDisabled), "boolean", "GetChannelName disabled is boolean")

	eq(type(c.env.IsDisplayChannelOwner), "function", "IsDisplayChannelOwner exists")
	eq(c.env.IsDisplayChannelOwner(), false, "IsDisplayChannelOwner returns false by default")

	eq(type(c.env.JoinChannelByName), "function", "JoinChannelByName exists")
	eq(c.env.JoinChannelByName("B4TestChan"), 0, "JoinChannelByName returns 0")

	eq(type(c.env.LeaveChannelByName), "function", "LeaveChannelByName exists")
	eq(c.env.LeaveChannelByName("B4TestChan"), nil, "LeaveChannelByName returns nil")

	eq(type(c.env.SetChannelPassword), "function", "SetChannelPassword exists")
	eq(c.env.SetChannelPassword("General", ""), nil, "SetChannelPassword returns nil")

	T.clean(w)
	T.clean(wc)
end)
