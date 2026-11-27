-- Guard tests for Wuber/Net/Community.lua lines unprotected on origin/main.
-- Each test guards one line that no other test noticed when it was broken.
local T = ...
local test, eq = T.test, T.eq
local H = T.H
local TESTCHAR, ANITA = T.TESTCHAR, T.ANITA

-- guards Wuber/Net/Community.lua:89 (drop statement: non-string club or channel name crashes lowerTrim instead of being ignored)
test("mutation b4 community: non-string club or channel name is ignored without error", function()
	local w = H.NewWorld({ clubs = true })
	w:addClub({ id = 77, name = "Wuber", members = { [ANITA] = 1, [TESTCHAR] = 4 } })
	local r = w:addClient(TESTCHAR, { spot = "Orgrimmar", class = "MAGE" })
	T.settle(w, 25)
	eq(r.W.IsCommunityChannel(0, 123), false, "non-string channel name returns false without error")
	r.env.C_Club.GetSubscribedClubs = function()
		return { { clubId = 77, name = 123, clubType = 1 } }
	end
	eq(r.W.CommunityMember(), false, "non-string club name is ignored without error")
	T.clean(w)
end)

-- guards Wuber/Net/Community.lua:102 (swap or->and: non-table GetSubscribedClubs return crashes findClub)
test("mutation b4 community: non-table GetSubscribedClubs result is treated as not a member", function()
	local w = H.NewWorld({ clubs = true })
	local r = w:addClient(TESTCHAR, { spot = "Orgrimmar", class = "MAGE" })
	T.settle(w, 25)
	r.env.C_Club.GetSubscribedClubs = function() return nil end
	eq(r.W.CommunityMember(), false, "nil GetSubscribedClubs result returns false without error")
	eq(r.W.CommunityCheck(), "out", "CommunityCheck reports out when GetSubscribedClubs returns nil")
	T.clean(w)
end)

-- guards Wuber/Net/Community.lua:155 (swap or->and: nil channel name still calls GetChannelName)
test("mutation b4 community: club with no stream does not query GetChannelName with nil", function()
	local w = H.NewWorld({ clubs = true })
	w:addClub({ id = 77, name = "Wuber", streams = {}, members = { [TESTCHAR] = 4 } })
	local r = w:addClient(TESTCHAR, { spot = "Orgrimmar", class = "MAGE" })
	T.settle(w, 25)
	local nilCalls = 0
	local origGetChannelName = r.env.GetChannelName
	r.env.GetChannelName = function(name)
		if name == nil then nilCalls = nilCalls + 1 end
		return origGetChannelName and origGetChannelName(name) or 0
	end
	eq(r.W.CommunityCheck(), "member", "member state is still reported without streams")
	eq(nilCalls, 0, "GetChannelName is not called with nil when club has no stream")
	T.clean(w)
end)

-- guards Wuber/Net/Community.lua:178 (return -> nil: IsCommunityChannel returns nil instead of boolean on name match)
test("mutation b4 community: IsCommunityChannel returns boolean by channel name when index is unknown", function()
	local w = H.NewWorld({ clubs = true })
	w:addClub({ id = 77, name = "Wuber", members = { [TESTCHAR] = 4 } })
	local r = w:addClient(TESTCHAR, { spot = "Orgrimmar", class = "MAGE" })
	T.settle(w, 25)
	eq(r.W.IsCommunityChannel(0, "  community:77:1  "), true, "matches community channel name case-insensitively")
	eq(r.W.IsCommunityChannel(0, "General"), false, "non-matching channel name returns false, not nil")
	T.clean(w)
end)
