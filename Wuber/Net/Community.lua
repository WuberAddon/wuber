-- Module: Net.Community
-- Purpose: The Wuber WoW Community as a second transport (CX table, comm state, W.community):
--   discovery of the club stream and its channel.
-- API: W.community, CX.api, CX.call, W.CommunityAvailable, W.CommunityMember, W.CommunityIndex,
--   W.IsCommunityChannel, CX.note, W.CommunityCheck, W.CommunityInvite, W.CommunityAccept,
--   W.CommunityStatus, CX.fail
-- Internals: CX, comm
-- Uses: Net.Base
-- Later: (none)
-- Events: listens (none); fires COMMUNITY
-- Standalone: no
-- Test: tests/net/community_test.lua
-- From: Net.lua 512-818 (Wuber 2.2.1)
--
---------------------------------------------------------------------------
-- The Wuber community (WoW Communities): a second channel that may cross internal realms
---------------------------------------------------------------------------
-- the author's community "Wuber" is Battle.net-backed, so its chat may reach players on other
-- internal realms, where WuberNet does not. Unproven in Forever 1.60.1 (C_Club, a channel
-- number for a community stream, addon messages on it), so every call is guarded and the
-- whole transport switches itself off quietly when the game refuses it:
--   * found: C_Club exists, we are in a club named "Wuber" (any case), its General stream
--     (or the first stream members may post in) has a chat channel for this client; Wuber
--     adds the channel itself (C_Club.AddClubStreamChatChannel) only after WuberNet's join,
--     never puts it in a chat window and never posts text in it.
--   * sent there (through the same queue and rate as everything else): our D when it
--     changed (online, state, price, dest...), every other periodic D (80 s since the last
--     copy, so about every 2 min, inside the riders' 150 s TTL), every D while WuberNet
--     looks isolated (not joined, or only our own echoes for 3 min), X once if we beaconed
--     there, a quick D answering a Q heard there; a rider's Q copy at most once a minute.
--   * heard there: exactly like WuberNet (D/X/Q only, same trust and cleaning).
--   * two failed sends in a row (InvalidChannel 7, ChannelThrottle 8, GeneralError 9,
--     false, or an error) switch it off for the session: one W.Debug note, nothing in chat.

-- the community's helpers and figures (one table: Net.lua's main chunk is near Lua's 200 locals)
local _, W = ...
local Mod = W.Module("Net.Community", { "Net.Base" })
local BaseMod = W.Mod("Net.Base")
local now = BaseMod.now
local plain, str, num = W.Plain, W.Str, W.Num

local CX = {
	EVERY = 80,     -- a periodic D goes to the community this long after the last copy
	Q_GAP = 60,     -- a rider's Q copy at most this often
	START = 15,     -- after login (WuberNet joins first, so it keeps its number)
	ADD_GAP = 20,   -- AddClubStreamChatChannel at most this often, 3 times a session
	TARGET = "\1community", -- the queue's target for a community copy
	-- (SPEC5 community, review #7: Forever's community streams take addon messages and deliver
	-- none, and the stream's channel costs one of the game's 10 chat channels: no channel is
	-- added and nothing is sent there. The community's online members are whisper seeds
	-- instead, W.CommunitySeeds.)
	TRANSPORT = false,
	SEEDS_MAX = 10, -- online members asked as seeds, Warlocks first
}

local comm = {
	state = nil,      -- "none" (no C_Club), "out" (not in the Wuber club), "member"
	clubId = nil, streamId = nil, name = nil, index = nil, role = nil,
	added = false,    -- we asked the game for the channel (its join notice is then ours to hide)
	addTries = 0, addAt = -1000,
	fails = 0, off = false, offWhy = nil, firstResult = nil,
	sent = 0, heard = 0, dropped = 0,
	othersAt = nil, echoAt = nil,
	online = false, lastD = -1000, force = false,
	lastQ = -1000, lastQHeard = -1000, lastQReply = -1000, replyPending = false,
	startAt = nil, sig = nil, acceptFailed = false,
}
W.community = comm -- read by the tests, /wuber status and the test addon

do -- the community: discovery (its local helpers stay in here)

function CX.api(name)
	local C = C_Club
	if type(C) ~= "table" then return nil end
	local fn = C[name]
	return type(fn) == "function" and fn or nil
end

-- C_Club.<name>(...) under pcall: ok, first, second (ok false when missing or it raised).
function CX.call(name, ...)
	local fn = CX.api(name)
	if not fn then return false end
	local res = { pcall(fn, ...) }
	if not res[1] then return false end
	return true, res[2], res[3]
end

local function lowerTrim(s)
	s = str(s)
	if not s then return nil end
	return (s:lower():gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Whether this game has communities at all.
function W.CommunityAvailable()
	return CX.api("GetSubscribedClubs") ~= nil
end

-- The "Wuber" club we are in: clubId, info; nil when not a member.
local function findClub()
	local okc, list = CX.call("GetSubscribedClubs")
	if not okc or type(list) ~= "table" then return nil end
	for _, info in ipairs(list) do
		-- a guild is a club too (the author's guild is also called Wuber): communities only
		local guildType = (type(Enum) == "table" and type(Enum.ClubType) == "table" and Enum.ClubType.Guild) or 2
		local isGuild = plain(info and info.clubType) == guildType
		if type(info) == "table" and not isGuild and lowerTrim(info.name) == "wuber" then
			local id = plain(info.clubId)
			if id ~= nil and id ~= "" then return id, info end
		end
	end
	return nil
end

-- Whether we are in the Wuber community.
function W.CommunityMember()
	return findClub() ~= nil
end

-- The club's General stream, else the first stream members may post in.
local function findStream(clubId)
	local okc, list = CX.call("GetStreams", clubId)
	if not okc or type(list) ~= "table" then return nil end
	local E = type(Enum) == "table" and type(Enum.ClubStreamType) == "table" and Enum.ClubStreamType or nil
	local general = (E and num(E.General)) or 0
	local first
	for _, s in ipairs(list) do
		if type(s) == "table" then
			local id = plain(s.streamId)
			if id ~= nil and id ~= "" then
				if num(s.streamType) == general or lowerTrim(s.name) == "general" then return id end
				if not first and plain(s.leadersAndModeratorsOnly) ~= true then first = id end
			end
		end
	end
	return first
end

-- The chat channel name the game gives a community stream ("Community:<club>:<stream>").
local function streamChannelName(clubId, streamId)
	local CU = type(ChatFrameUtil) == "table" and ChatFrameUtil or nil
	local fns = { Chat_GetCommunitiesChannelName, ChatFrame_GetCommunitiesChannelName, CU and CU.GetCommunitiesChannelName }
	for i = 1, 3 do
		local fn = fns[i]
		if type(fn) == "function" then
			local okn, n = pcall(fn, clubId, streamId)
			n = okn and str(n) or nil
			if n and n ~= "" then return n end
		end
	end
	return "Community:" .. tostring(clubId) .. ":" .. tostring(streamId)
end

local function indexOf(name)
	if not name or type(GetChannelName) ~= "function" then return nil end
	local okc, id = pcall(GetChannelName, name)
	id = okc and num(id) or nil
	if id and id > 0 then return id end
	return nil
end

-- The community channel's number when it can carry our messages now, else nil.
function W.CommunityIndex()
	if not CX.TRANSPORT then return nil end
	if comm.off or comm.state ~= "member" or not comm.name then return nil end
	local idx = indexOf(comm.name) -- read again: numbers move
	comm.index = idx
	return idx
end

-- Whether a channel message (its number and name, as CHAT_MSG_ADDON gives them) came over
-- the community channel.
function W.IsCommunityChannel(index, name)
	if not comm.name then return false end
	local idx = num(index)
	if idx and idx > 0 and comm.index and idx == comm.index then return true end
	local n = lowerTrim(name)
	return n ~= nil and n == comm.name:lower()
end

function CX.note(text) W.Debug("community", text) end

-- Hides the join notice of the community channel when Wuber added it (a channel the player
-- added to chat themselves keeps its notices; its chat is never touched).
local function commNoticeFilter(_, _, _, _, _, chanString, _, _, _, chanIndex, chanBase)
	local okf, ours = pcall(function()
		if not comm.added or not comm.name then return false end
		local idx = num(chanIndex)
		if idx and idx > 0 and idx == indexOf(comm.name) then return true end
		local n = comm.name:lower()
		if lowerTrim(chanBase) == n then return true end
		local s = lowerTrim(chanString)
		return s ~= nil and s:gsub("^%d+%.%s*", "") == n
	end)
	return (okf and ours) and true or false
end

local commFilterAdded = false
local function addCommFilter()
	if commFilterAdded then return end
	local add = (type(ChatFrame_AddMessageEventFilter) == "function" and ChatFrame_AddMessageEventFilter)
		or (type(ChatFrameUtil) == "table" and type(ChatFrameUtil.AddMessageEventFilter) == "function"
			and function(event, fn) return ChatFrameUtil.AddMessageEventFilter(event, fn) end) or nil
	if not add then return end
	commFilterAdded = true
	for _, event in ipairs({ "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER" }) do
		pcall(add, event, commNoticeFilter)
	end
end


-- Looks at the community: membership, stream, channel (adds it when missing, once WuberNet
-- had its turn). Fires "COMMUNITY" with the state when anything changed.
function W.CommunityCheck()
	local was = comm.state
	if not W.CommunityAvailable() then
		comm.state, comm.clubId, comm.name, comm.index = "none", nil, nil, nil
	else
		local clubId = findClub()
		if not clubId then
			comm.state, comm.clubId, comm.streamId, comm.name, comm.index, comm.role = "out", nil, nil, nil, nil, nil
		else
			comm.state = "member"
			if clubId ~= comm.clubId then comm.addTries = 0 end
			comm.clubId = clubId
			local okm, me = CX.call("GetMemberInfoForSelf", clubId)
			comm.role = (okm and type(me) == "table") and num(me.role) or nil
			local streamId = findStream(clubId)
			comm.streamId = streamId
			comm.name = streamId ~= nil and streamChannelName(clubId, streamId) or nil
			local idx = indexOf(comm.name)
			comm.index = idx
			local started = comm.startAt and now() >= comm.startAt
			if CX.TRANSPORT and not idx and comm.name and started and not comm.off and comm.addTries < 3
				and now() - comm.addAt >= CX.ADD_GAP and CX.api("AddClubStreamChatChannel") then
				comm.addTries, comm.addAt, comm.added = comm.addTries + 1, now(), true
				addCommFilter()
				CX.call("AddClubStreamChatChannel", clubId, streamId)
				W.After(2, function() W.CommunityCheck() end)
			end
		end
	end
	local usable = W.CommunityIndex()
	local sig = tostring(comm.state) .. "/" .. tostring(usable) .. "/" .. tostring(comm.off) .. "/" .. tostring(comm.role)
	if sig ~= comm.sig then
		local wasUsable = comm.sig and comm.sig:match("^member/(%d+)/") ~= nil
		comm.sig = sig
		if comm.state == "none" then
			CX.note("not available (no C_Club)")
		elseif comm.state == "out" then
			CX.note("not a member of the Wuber community")
		elseif not CX.TRANSPORT then
			CX.note("found: club " .. tostring(comm.clubId) .. " (no channel: its online members are whisper seeds)")
		elseif usable then
			CX.note("found: club " .. tostring(comm.clubId) .. ", stream " .. tostring(comm.streamId) .. ", channel " .. usable
				.. " (" .. tostring(comm.name) .. "), role " .. tostring(comm.role))
		else
			CX.note("member, no channel yet (stream " .. tostring(comm.streamId) .. ", tries " .. comm.addTries
				.. (comm.off and ", switched off" or "") .. ")")
		end
		if usable and not wasUsable and CX.found then CX.found() end
		W.Fire("COMMUNITY", comm.state)
	elseif was ~= comm.state then
		W.Fire("COMMUNITY", comm.state)
	end
	return comm.state
end

-- A pending invitation to the Wuber community from the founder's team (or from anyone when
-- the game doesn't say who): clubId, inviter name; nil when none or already a member.
function W.CommunityInvite()
	-- (SPEC5 founder, review #1: the founders' names mean them only on their own ruleset)
	if not W.OnFounderRuleset() then return nil end
	if not W.CommunityAvailable() or findClub() then return nil end
	local okc, list = CX.call("GetInvitationsForSelf")
	if not okc or type(list) ~= "table" then return nil end
	for _, inv in ipairs(list) do
		local club = type(inv) == "table" and type(inv.club) == "table" and inv.club or nil
		if club and lowerTrim(club.name) == "wuber" then
			local id = plain(club.clubId)
			local who = type(inv.inviter) == "table" and str(inv.inviter.name) or nil
			if id ~= nil and (not who or W.IsCreator(W.Key(who))) then return id, who end
		end
	end
	return nil
end

-- Accepts the invitation (call it from a click only). Returns whether the game took it.
function W.CommunityAccept(clubId)
	clubId = plain(clubId)
	if clubId == nil or not CX.api("AcceptInvitation") then
		comm.acceptFailed = true
		return false
	end
	local okc, res = CX.call("AcceptInvitation", clubId)
	local fine = okc and res ~= false
	comm.acceptFailed = not fine
	CX.note("AcceptInvitation " .. (fine and "sent" or "failed"))
	W.After(1.5, function() W.CommunityCheck() end)
	return fine
end

-- For /wuber status: "Community: joined, channel 7." and the like.
function W.CommunityStatus()
	if not W.CommunityAvailable() then return "Community: not available in this game." end
	if not findClub() then return "Community: not joined." end
	local idx = W.CommunityIndex()
	if idx then return "Community: joined, channel " .. idx .. "." end
	return "Community: joined."
end

-- A send on the community channel failed (why: the result or "error").
function CX.fail(why)
	comm.fails = comm.fails + 1
	if comm.firstResult == nil then
		comm.firstResult = "failed (" .. tostring(why) .. ")"
		CX.note("first send: " .. comm.firstResult)
	end
	if comm.fails >= 2 and not comm.off then
		comm.off, comm.offWhy = true, tostring(why)
		CX.note("switched off for this session after two failed sends (last: " .. tostring(why) .. ")")
		W.CommunityCheck()
	end
end

end

-- for the Net modules that load after this one (REFACTOR-MAP section 2)
Mod.CX, Mod.comm = CX, comm
