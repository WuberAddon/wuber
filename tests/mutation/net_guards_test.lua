-- Tests from the mutation run: the community transport and its discovery (Net/Community.lua).
-- Each test guards lines that no other test noticed when they were broken. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local BOB, ANITA = "Bob Stone", "Anita Lift"
local COMM = "Community:77:1"
local EU5 = "CAMWOW EU5 Realm 5 PvE" -- the founders' ruleset

-- a world with the Wuber community (id 77) and Bob, a member, in it; opts.streams, opts.members
local function world(opts)
	opts = opts or {}
	local w = T.newWorld({ clubs = true })
	w:addClub({ id = 77, name = "Wuber", members = opts.members or { [BOB] = 4 }, streams = opts.streams })
	local c = w:addClient(BOB, { spot = "Ratchet", class = "WARLOCK", realm = EU5, allowMissing = not T.HAVE_UI })
	T.settle(w, 25)
	return w, c
end

local function CXof(c) return c.W.Mod("Net.Community").CX end

local function debugLines(c, part)
	local out = {}
	for _, e in ipairs(c.W.debugLog or {}) do
		if e.kind == "community" and e.text:find(part, 1, true) then out[#out + 1] = e.text end
	end
	return out
end

-- the stream the addon picks when the game lists these streams
local function pick(c, streams)
	c.env.C_Club.GetStreams = function() return streams end
	c.W.CommunityCheck()
	return c.W.community.streamId, c.W.community.name
end

-- guards Wuber/Net/Community.lua:105 (mutation run, mutant 17176: local value -> nil)
-- guards Wuber/Net/Community.lua:106 (mutation run, mutant 7040: local value -> nil)
-- guards Wuber/Net/Community.lua:109 (mutation run, mutant 8921: swap and->or)
test("mutation net: a guild called Wuber, or a club with no id, is not the Wuber community", function()
	local w, c = world()
	ok(c.W.CommunityMember(), "control: the real community is found")
	c.env.C_Club.GetSubscribedClubs = function() return { { clubId = 5, name = "Wuber", clubType = 2 } } end
	ok(not c.W.CommunityMember(), "a guild named Wuber is not the community")
	eq(c.W.CommunityStatus(), "Community: not joined.", "and says so")
	c.env.C_Club.GetSubscribedClubs = function() return { { clubId = "", name = "Wuber", clubType = 1 } } end
	ok(not c.W.CommunityMember(), "a club whose id is empty is not usable")
	T.clean(w)
end)

-- guards Wuber/Net/Community.lua:125 (mutation run, mutant 31941: local value -> nil)
-- guards Wuber/Net/Community.lua:129 (mutation run, mutant 20136: local value -> nil)
-- guards Wuber/Net/Community.lua:130 (mutation run, mutant 15677: cmp ~=->==)
-- guards Wuber/Net/Community.lua:131 (mutation run, mutant 25803: cmp ==->~=)
-- guards Wuber/Net/Community.lua:229 (mutation run, mutant 17471: drop statement)
test("mutation net: the General stream is chosen by its type, ahead of an earlier open stream", function()
	local w, c = world()
	local id, name = pick(c, { { streamId = 2, name = "Wuber", streamType = 3, leadersAndModeratorsOnly = false },
		{ streamId = 1, name = "Chat", streamType = 0 } })
	eq(id, 1, "the General-type stream")
	eq(c.W.community.streamId, 1, "kept in the community record")
	eq(name, COMM, "its channel name")
	T.clean(w)
end)

-- guards Wuber/Net/Community.lua:124 (mutation run, mutant 19249: local value -> nil)
test("mutation net: the General type is read from the game's own stream-type table", function()
	local w, c = world()
	c.env.Enum.ClubStreamType.General = 5
	local id = pick(c, { { streamId = 2, name = "Wuber", streamType = 3 }, { streamId = 3, name = "Chat", streamType = 5 } })
	eq(id, 3, "the stream of the game's General type")
	T.clean(w)
end)

-- guards Wuber/Net/Community.lua:128 (mutation run, mutant 28718: if cond negated)
-- guards Wuber/Net/Community.lua:132 (mutation run, mutant 8160: swap and->or)
-- guards Wuber/Net/Community.lua:136 (mutation run, mutant 21778: return -> nil)
test("mutation net: with no General stream, the first stream members may post in is used", function()
	local w, c = world()
	eq((pick(c, { 42, { streamId = 4, name = "A", streamType = 3 }, { streamId = 5, name = "B", streamType = 3 } })), 4, "the first open one, not the last; a stray entry is ignored")
	eq((pick(c, { { streamId = 2, name = "Mods", streamType = 3, leadersAndModeratorsOnly = true },
		{ streamId = 3, name = "B", streamType = 3 } })), 3, "a moderators-only stream is passed over")
	T.clean(w)
end)

-- guards Wuber/Net/Community.lua:123 (mutation run, mutant 6230: swap or->and)
-- guards Wuber/Net/Community.lua:230 (mutation run, mutant 1918: cmp ~=->==)
test("mutation net: a game that gives no list of streams leaves the community without a channel name", function()
	local w, c = world()
	local id, name = pick(c, nil)
	eq(id, nil, "no stream")
	eq(name, nil, "no channel name")
	eq(c.W.community.state, "member", "still a member")
	T.clean(w)
end)

-- guards Wuber/Net/Community.lua:144 (mutation run, mutant 11151: local value -> nil)
-- guards Wuber/Net/Community.lua:145 (mutation run, mutant 10090: cmp ==->~=)
-- guards Wuber/Net/Community.lua:148 (mutation run, mutant 23806: swap and->or)
test("mutation net: the channel name comes from the first game function that gives a real name", function()
	local w, c = world()
	c.env.Chat_GetCommunitiesChannelName = function() return "" end
	c.env.ChatFrame_GetCommunitiesChannelName = function(club, stream) return "Alt:" .. club .. ":" .. stream end
	c.W.CommunityCheck()
	eq(c.W.community.name, "Alt:77:1", "an empty answer is skipped, the next function is asked")
	T.clean(w)
end)

-- guards Wuber/Net/Community.lua:141 (mutation run, mutant 30892: cmp ==->~=)
-- guards Wuber/Net/Community.lua:142 (mutation run, mutant 19899: swap and->or)
-- guards Wuber/Net/Community.lua:151 (mutation run, mutant 8208: return -> nil)
test("mutation net: the channel name falls back to ChatFrameUtil and then to Community:club:stream", function()
	local w, c = world()
	c.api.Chat_GetCommunitiesChannelName = nil
	c.api.ChatFrame_GetCommunitiesChannelName = nil
	c.env.ChatFrameUtil.GetCommunitiesChannelName = function(club, stream) return "Util:" .. club .. ":" .. stream end
	c.W.CommunityCheck()
	eq(c.W.community.name, "Util:77:1", "ChatFrameUtil's function is used")
	c.env.ChatFrameUtil.GetCommunitiesChannelName = nil
	c.W.CommunityCheck()
	eq(c.W.community.name, "Community:77:1", "the built name when the game has none")
	T.clean(w)
end)

-- guards Wuber/Net/Community.lua:155 (mutation run, mutant 7432: cmp ~=->==)
-- guards Wuber/Net/Community.lua:158 (mutation run, mutant 8105: swap and->or)
-- guards Wuber/Net/Community.lua:231 (mutation run, mutant 24981: local value -> nil)
-- guards Wuber/Net/Community.lua:232 (mutation run, mutant 13797: drop statement)
test("mutation net: the community channel's number is read when it is joined and absent when it is not", function()
	local w, c = world()
	local comm = c.W.community
	comm.index = 99
	c.W.CommunityCheck()
	eq(comm.index, nil, "not joined: no number (the game answers 0)")
	w:joinChannel(c, COMM)
	w:advance(3)
	local n = c.env.GetChannelName(COMM)
	ok(n > 0, "control: the game gave the channel a number")
	comm.index = 99
	c.W.CommunityCheck()
	eq(comm.index, n, "joined: the number is the game's")
	T.clean(w)
end)

-- guards Wuber/Net/Community.lua:157 (mutation run, mutant 10201: drop statement)
test("mutation net: a channel number that is not a number is never used", function()
	local w, c = world()
	c.env.GetChannelName = function() return "7" end
	c.W.community.index = 99
	c.W.CommunityCheck()
	eq(c.W.community.index, nil, "no number")
	T.clean(w)
end)

-- guards Wuber/Net/Community.lua:165 (mutation run, mutant 1406: cmp ~=->==)
-- guards Wuber/Net/Community.lua:166 (mutation run, mutant 27119: local value -> nil)
-- guards Wuber/Net/Community.lua:167 (mutation run, mutant 28492: drop statement)
-- guards Wuber/Net/Community.lua:168 (mutation run, mutant 32203: return -> nil)
-- guards Wuber/Net/Community.lua:307 (mutation run, mutant 12582: local value -> nil)
test("mutation net: when the community channel can carry messages its number is read again and shown in the status", function()
	local w, c = world()
	local CX, comm = CXof(c), c.W.community
	w:joinChannel(c, COMM)
	w:advance(3)
	local n = c.env.GetChannelName(COMM)
	CX.TRANSPORT = true
	comm.index = 99 -- numbers move
	eq(c.W.CommunityIndex(), n, "the number")
	eq(comm.index, n, "and it is kept")
	eq(c.W.CommunityStatus(), "Community: joined, channel " .. n .. ".", "the status names it")
	comm.off = true
	eq(c.W.CommunityIndex(), nil, "switched off: no channel")
	CX.TRANSPORT = false
	T.clean(w)
end)

-- guards Wuber/Net/Community.lua:175 (mutation run, mutant 30688: local value -> nil)
-- guards Wuber/Net/Community.lua:176 (mutation run, mutant 17775: cmp ==->~=)
-- guards Wuber/Net/Community.lua:177 (mutation run, mutant 17364: local value -> nil)
-- guards Wuber/Net/Community.lua:178 (mutation run, mutant 2810: swap and->or)
test("mutation net: a channel message counts as the community's by its number or by its name, never otherwise", function()
	local w, c = world()
	local comm = c.W.community
	comm.name, comm.index = COMM, 7
	ok(c.W.IsCommunityChannel(7, "something else"), "by the number")
	ok(not c.W.IsCommunityChannel(8, "something else"), "another number, another name: no")
	ok(c.W.IsCommunityChannel(0, "COMMUNITY:77:1"), "by the name, any case")
	ok(not c.W.IsCommunityChannel(nil, "General"), "another name: no")
	T.clean(w)
end)

-- guards Wuber/Net/Community.lua:201 (mutation run, mutant 15974: local value -> nil)
-- guards Wuber/Net/Community.lua:205 (mutation run, mutant 31782: drop statement)
-- guards Wuber/Net/Community.lua:207 (mutation run, mutant 12806: drop statement)
-- guards Wuber/Net/Community.lua:224 (mutation run, mutant 14649: cmp ~=->==)
-- guards Wuber/Net/Community.lua:233 (mutation run, mutant 3966: cmp >=-><)
-- guards Wuber/Net/Community.lua:234 (mutation run, mutant 27679: cmp <->>=)
-- guards Wuber/Net/Community.lua:237 (mutation run, mutant 19339: drop statement)
-- guards Wuber/Net/Community.lua:238 (mutation run, mutant 26985: drop statement)
test("mutation net: the channel is asked for only after the start time, at most three times, hiding its notices once", function()
	local w, c = world()
	w.noClubChannels = true -- the game never gives the channel a number
	c.env.ChatFrameUtil.AddMessageEventFilter = nil -- the global ChatFrame_AddMessageEventFilter is the only way in
	local CX, comm = CXof(c), c.W.community
	local function filters(ev) return #(c.chatFilters[ev] or {}) end
	local f1, f2 = filters("CHAT_MSG_CHANNEL_NOTICE"), filters("CHAT_MSG_CHANNEL_NOTICE_USER")
	CX.TRANSPORT = true
	comm.addTries, comm.addAt, comm.added, comm.off = 0, -1000, false, false
	comm.startAt = c.W.Mod("Net.Base").now() + 100
	c.W.CommunityCheck()
	eq(c.clubChannelAdds, nil, "before the start time: not asked")
	comm.startAt = c.W.Mod("Net.Base").now() - 1
	c.W.CommunityCheck()
	eq(c.clubChannelAdds, 1, "after it: asked once")
	eq(comm.addTries, 1, "counted")
	ok(comm.added, "marked as added by us")
	eq(filters("CHAT_MSG_CHANNEL_NOTICE") - f1, 1, "its join notice is filtered")
	eq(filters("CHAT_MSG_CHANNEL_NOTICE_USER") - f2, 1, "and the user notice")
	for _ = 1, 6 do
		w:advance(25)
		c.W.CommunityCheck()
	end
	eq(c.clubChannelAdds, 3, "three tries a session, no more")
	eq(filters("CHAT_MSG_CHANNEL_NOTICE") - f1, 1, "the filter was put in once")
	eq(filters("CHAT_MSG_CHANNEL_NOTICE_USER") - f2, 1, "once for the user notice too")
	CX.TRANSPORT = false
	T.clean(w)
end)

-- guards Wuber/Net/Community.lua:187 (mutation run, mutant 13511: swap or->and)
-- guards Wuber/Net/Community.lua:188 (mutation run, mutant 15320: local value -> nil)
-- guards Wuber/Net/Community.lua:189 (mutation run, mutant 28960: cmp ==->~=)
-- guards Wuber/Net/Community.lua:190 (mutation run, mutant 27695: local value -> nil)
-- guards Wuber/Net/Community.lua:191 (mutation run, mutant 26331: cmp ==->~=)
-- guards Wuber/Net/Community.lua:192 (mutation run, mutant 26725: local value -> nil)
-- guards Wuber/Net/Community.lua:193 (mutation run, mutant 32014: swap and->or)
-- guards Wuber/Net/Community.lua:195 (mutation run, mutant 14286: return -> nil)
test("mutation net: only the join notice of the channel Wuber added itself is hidden", function()
	local w, c = world()
	local CX, comm = CXof(c), c.W.community
	CX.TRANSPORT = true
	comm.addTries, comm.addAt, comm.added, comm.off = 0, -1000, false, false
	comm.startAt = c.W.Mod("Net.Base").now() - 1
	c.W.CommunityCheck()
	w:advance(3)
	local list = c.chatFilters["CHAT_MSG_CHANNEL_NOTICE"]
	local f = list[#list]
	local n = c.env.GetChannelName(COMM)
	ok(n > 0 and comm.added, "control: Wuber added the channel")
	local function hides(idx, base, str) return f(nil, nil, nil, nil, nil, str, nil, nil, nil, idx, base) end
	eq(hides(n), true, "by the channel number")
	eq(hides(99, COMM:upper()), true, "by the channel's base name")
	eq(hides(99, nil, n .. ". " .. COMM), true, "by the numbered channel text")
	eq(hides(99, "General", "3. General"), false, "another channel's notice stays")
	comm.added = false
	eq(hides(n), false, "a channel the player added themselves keeps its notices")
	CX.TRANSPORT = false
	T.clean(w)
end)

-- guards Wuber/Net/Community.lua:227 (mutation run, mutant 29242: swap and->or)
test("mutation net: our role in the community is read from the game's record of us, and absent when there is none", function()
	local w, c = world()
	eq(c.W.community.role, 4, "a member's role")
	c.env.C_Club.GetMemberInfoForSelf = function() return nil end
	c.W.CommunityCheck()
	eq(c.W.community.role, nil, "no record: no role")
	T.clean(w)
end)

-- guards Wuber/Net/Community.lua:274 (mutation run, mutant 1141: swap or->and)
-- guards Wuber/Net/Community.lua:276 (mutation run, mutant 15081: swap or->and)
test("mutation net: a member is not offered an invitation to the community they are already in", function()
	local w, c = world()
	c.env.C_Club.GetInvitationsForSelf = function()
		return { { club = { clubId = 77, name = "Wuber" }, inviter = { name = ANITA } } }
	end
	eq(c.W.CommunityInvite(), nil, "already a member: nothing to accept")
	T.clean(w)
	w, c = world({ members = { [ANITA] = 1 } })
	c.env.C_Club.GetInvitationsForSelf = function() return nil end
	eq(c.W.CommunityInvite(), nil, "the game gave no list: nothing, and no error")
	T.clean(w)
end)

-- guards Wuber/Net/Community.lua:279 (mutation run, mutant 29312: if cond negated)
test("mutation net: the invitation taken is the one to the club named Wuber, from the founder", function()
	local w = T.newWorld({ clubs = true })
	local other = w:addClub({ id = 5, name = "Goldshire Fishing", members = { [ANITA] = 1 } })
	local club = w:addClub({ id = 77, name = "Wuber", members = { [ANITA] = 1 } })
	local c = w:addClient(BOB, { spot = "Ratchet", class = "WARLOCK", realm = EU5, allowMissing = not T.HAVE_UI })
	T.settle(w, 25)
	w:clubInvite(other, ANITA, BOB)
	w:clubInvite(club, ANITA, BOB)
	w:advance(1)
	local id, who = c.W.CommunityInvite()
	eq(id, 77, "the Wuber club's id")
	eq(who, ANITA, "and who invited")
	T.clean(w)
end)

-- guards Wuber/Net/Community.lua:297 (mutation run, mutant 26954: drop statement)
-- guards Wuber/Net/Community.lua:300 (mutation run, mutant 31524: return -> nil)
test("mutation net: accepting the invitation reports whether the game took it and remembers a failure", function()
	local w, c = world()
	local comm, called = c.W.community, {}
	local result
	c.env.C_Club.AcceptInvitation = function(id) called[#called + 1] = id; return result end
	comm.acceptFailed = true
	eq(c.W.CommunityAccept(77), true, "the game took it")
	eq(called[1], 77, "with the club's id")
	eq(comm.acceptFailed, false, "no failure remembered")
	result = false
	eq(c.W.CommunityAccept(77), false, "the game refused")
	eq(comm.acceptFailed, true, "the failure is remembered")
	c.env.C_Club.AcceptInvitation = function() error("boom") end
	eq(c.W.CommunityAccept(77), false, "an error is a refusal")
	T.clean(w)
end)

-- guards Wuber/Net/Community.lua:290 (mutation run, mutant 17889: drop statement)
-- guards Wuber/Net/Community.lua:291 (mutation run, mutant 11660: if cond negated)
-- guards Wuber/Net/Community.lua:292 (mutation run, mutant 7708: drop statement)
-- guards Wuber/Net/Community.lua:293 (mutation run, mutant 18893: return false->true)
test("mutation net: accepting with no club id does nothing and says it failed", function()
	local w, c = world()
	local calls = 0
	c.env.C_Club.AcceptInvitation = function() calls = calls + 1 end
	c.W.community.acceptFailed = false
	eq(c.W.CommunityAccept(nil), false, "refused")
	eq(c.W.community.acceptFailed, true, "remembered")
	eq(calls, 0, "the game was not asked")
	c.env.issecretvalue = function(v) return v == "SECRET" end
	eq(c.W.CommunityAccept("SECRET"), false, "an id the game hides is no id")
	c.env.issecretvalue = nil
	eq(calls, 0, "still not asked")
	c.env.C_Club.AcceptInvitation = nil
	eq(c.W.CommunityAccept(77), false, "a game with no way to accept")
	eq(c.W.community.acceptFailed, true, "remembered")
	T.clean(w)
end)

-- guards Wuber/Net/Community.lua:315 (mutation run, mutant 1776: if cond negated)
-- guards Wuber/Net/Community.lua:317 (mutation run, mutant 26814: drop statement)
-- guards Wuber/Net/Community.lua:321 (mutation run, mutant 4294: drop statement)
test("mutation net: two failed sends switch the community transport off with one note each", function()
	local w, c = world()
	local CX, comm = CXof(c), c.W.community
	CX.fail("7")
	eq(comm.firstResult, "failed (7)", "the first result is kept")
	eq(#debugLines(c, "first send: failed (7)"), 1, "noted once")
	ok(not comm.off, "one failure is not enough")
	CX.fail("9")
	eq(comm.firstResult, "failed (7)", "still the first")
	ok(comm.off, "two switch it off")
	eq(comm.offWhy, "9", "with the last reason")
	eq(#debugLines(c, "switched off for this session after two failed sends (last: 9)"), 1, "noted")
	T.clean(w)
end)
