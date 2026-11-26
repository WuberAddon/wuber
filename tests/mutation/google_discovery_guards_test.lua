-- Guard tests for Wuber/Net/Discovery.lua lines that no other test protected.
-- Each passes on main and fails when its guarded line is mutated.
-- Skipped:
--   Wuber/Net/Discovery.lua:319 (return nil): unreachable/dead; qGap is only called at
--   line 329 when fb.qAt[key] is non-nil, so line 317 (300) or line 318 (100) always returns.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local H = T.H
local TESTCHAR, ANITA, BOB, CAL = T.TESTCHAR, T.ANITA, T.BOB, T.CAL

-- guards Wuber/Net/Discovery.lua:98 (< to >=)
test("mutation discovery: CommunitySeeds caches for 60s and refreshes after 60s", function()
	local w = H.NewWorld({ clubs = true })
	w:addClub({ id = 77, name = "Wuber", members = { [ANITA] = 1, [BOB] = 4, [CAL] = 4, [TESTCHAR] = 4 } })
	local r = w:addClient(TESTCHAR, { spot = "Orgrimmar", class = "MAGE" })
	w:addBot(BOB, { spot = "Ratchet", class = "WARLOCK" })
	w:addBot(CAL, { spot = "Orgrimmar", class = "WARRIOR" })
	w:player(CAL).online = false
	T.settle(w, 25)
	eq(r.W.community.state, "member", "rider is in the community")

	local calls = 0
	local origGetMembers = r.env.C_Club.GetClubMembers
	r.env.C_Club.GetClubMembers = function(clubId)
		calls = calls + 1
		return origGetMembers(clubId)
	end

	-- Clear any cache populated during settle so we control the first call.
	r.W.Mod("Net.Community").CX.seeds = nil
	r.W.Mod("Net.Community").CX.seedsAt = nil

	local s1 = r.W.CommunitySeeds()
	eq(calls, 1, "first call queries C_Club")
	eq(#s1, 1, "Bob is returned while Cal is offline")

	w:player(CAL).online = true
	w:advance(10)
	local s2 = r.W.CommunitySeeds()
	eq(calls, 1, "within 60s, cached seeds are returned without querying C_Club")
	eq(#s2, 1, "still returns cached list")

	w:advance(55)
	local s3 = r.W.CommunitySeeds()
	eq(calls, 2, "after 60s, C_Club is queried again")
	eq(#s3, 2, "refreshed list includes Cal")
	T.clean(w)
end)

-- guards Wuber/Net/Discovery.lua:101 (and to or)
test("mutation discovery: CommunitySeeds returns empty when GetClubMembers returns non-table", function()
	local w = H.NewWorld({ clubs = true })
	w:addClub({ id = 77, name = "Wuber", members = { [ANITA] = 1, [TESTCHAR] = 4 } })
	local r = w:addClient(TESTCHAR, { spot = "Orgrimmar", class = "MAGE" })
	T.settle(w, 25)
	eq(r.W.community.state, "member", "rider is in the community")

	r.W.Mod("Net.Community").CX.seeds = nil
	r.W.Mod("Net.Community").CX.seedsAt = nil
	r.env.C_Club.GetClubMembers = function() return nil end

	local seeds = r.W.CommunitySeeds()
	eq(type(seeds), "table", "returns a table")
	eq(#seeds, 0, "empty when GetClubMembers returns nil")
	T.clean(w)
end)

-- guards Wuber/Net/Discovery.lua:109 (negate the if)
test("mutation discovery: CommunitySeeds keeps valid members and skips nil GetMemberInfo", function()
	local w = H.NewWorld({ clubs = true })
	w:addClub({ id = 77, name = "Wuber", members = { [ANITA] = 1, [BOB] = 4, [CAL] = 4, [TESTCHAR] = 4 } })
	local r = w:addClient(TESTCHAR, { spot = "Orgrimmar", class = "MAGE" })
	w:addBot(BOB, { spot = "Ratchet", class = "WARLOCK" })
	w:addBot(CAL, { spot = "Orgrimmar", class = "WARRIOR" })
	T.settle(w, 25)

	r.W.Mod("Net.Community").CX.seeds = nil
	r.W.Mod("Net.Community").CX.seedsAt = nil
	local origInfo = r.env.C_Club.GetMemberInfo
	r.env.C_Club.GetMemberInfo = function(clubId, mid)
		local info = origInfo(clubId, mid)
		if info and info.name == CAL then return nil end
		return info
	end

	local seeds = r.W.CommunitySeeds()
	eq(#seeds, 1, "valid member returned while nil member info is skipped")
	eq(seeds[1].name, BOB, "Bob is kept")
	T.clean(w)
end)

-- guards Wuber/Net/Discovery.lua:112 (and to or)
test("mutation discovery: CommunitySeeds normalizes seed key and respects hidden players", function()
	local w = H.NewWorld({ clubs = true })
	w:addClub({ id = 77, name = "Wuber", members = { [ANITA] = 1, [BOB] = 4, [CAL] = 4, [TESTCHAR] = 4 } })
	local r = w:addClient(TESTCHAR, { spot = "Orgrimmar", class = "MAGE" })
	w:addBot(BOB, { spot = "Ratchet", class = "WARLOCK" })
	w:addBot(CAL, { spot = "Orgrimmar", class = "WARRIOR" })
	T.settle(w, 25)

	r.W.HideDriver(H.key(CAL))
	r.W.Mod("Net.Community").CX.seeds = nil
	r.W.Mod("Net.Community").CX.seedsAt = nil

	local seeds = r.W.CommunitySeeds()
	eq(#seeds, 1, "hidden Cal is excluded")
	eq(seeds[1].key, H.key(BOB), "seed key is normalized lowercase")
	T.clean(w)
end)

-- guards Wuber/Net/Discovery.lua:159 (and to or)
test("mutation discovery: Contacts prunes the oldest peer past PEERS_MAX, not a newer smaller key", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)

	local NETK = r.W.Mod("Net.Base").NETK
	local stamp = r.env.time()
	local peers = r.W.db.peers
	for k in pairs(peers) do peers[k] = nil end
	peers["zzz oldest"] = { name = "Zzz Oldest", addr = "Zzz Oldest", at = stamp - 500 }
	for i = 1, NETK.PEERS_MAX do
		local ch = string.char(97 + math.floor((i - 1) / 26)) .. string.char(97 + ((i - 1) % 26))
		local k = "aa " .. ch
		peers[k] = { name = "Aa " .. ch, addr = "Aa " .. ch, at = stamp - i }
	end

	local contacts = r.W.Contacts()
	eq(#contacts, NETK.PEERS_MAX, "kept at PEERS_MAX")
	eq(peers["zzz oldest"], nil, "oldest peer is evicted")
	ok(peers["aa aa"] ~= nil, "newest peer with smaller key is kept")
	T.clean(w)
end)

-- guards Wuber/Net/Discovery.lua:219 (negate the if)
test("mutation discovery: KnownDrivers ranks community seeds above plain seen drivers", function()
	local w = H.NewWorld({ clubs = true })
	w:addClub({ id = 77, name = "Wuber", members = { [ANITA] = 1, [BOB] = 4, [TESTCHAR] = 4 } })
	local r = w:addClient(TESTCHAR, { spot = "Orgrimmar", class = "MAGE" })
	w:addBot(BOB, { spot = "Ratchet", class = "WARLOCK" })
	T.settle(w, 25)

	local BaseMod = r.W.Mod("Net.Base")
	local stamp = r.env.time()
	local seen = BaseMod.seenList()
	for i = 1, BaseMod.NETK.KNOWN_MAX + 5 do
		local k = string.format("seen driver%02d", i)
		seen[k] = { name = string.format("Seen Driver%02d", i), at = stamp - i }
	end

	local known = r.W.KnownDrivers()
	local foundBob = false
	for _, e in ipairs(known) do
		if e.key == H.key(BOB) and not e.unconfirmed then
			foundBob = true
			eq(e.club, true, "community seed is marked as club")
		end
	end
	ok(foundBob, "community seed outranks excess seen drivers and stays in KnownDrivers")
	T.clean(w)
end)

-- guards Wuber/Net/Discovery.lua:269 (~= to ==)
test("mutation discovery: KnownDrivers orders unconfirmed entries oldest first regardless of key", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)

	local t = r.env.GetTime()
	local unc = r.W.fallback.unconfirmed
	unc["aaa newer"] = { key = "aaa newer", name = "Aaa Newer", at = t + 20, from = "peer one", tries = 0, age = 0 }
	unc["zzz older"] = { key = "zzz older", name = "Zzz Older", at = t + 10, from = "peer one", tries = 0, age = 0 }

	local known = r.W.KnownDrivers()
	local posOlder, posNewer
	for i, e in ipairs(known) do
		if e.key == "zzz older" then posOlder = i end
		if e.key == "aaa newer" then posNewer = i end
	end
	ok(posOlder and posNewer, "both unconfirmed entries present")
	ok(posOlder < posNewer, "older unconfirmed entry comes before newer one despite larger key")
	T.clean(w)
end)

-- guards Wuber/Net/Discovery.lua:422 (~= to ==)
test("mutation discovery: K gossip sends the latest-heard drivers, not older ones with smaller keys", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	local bob = w:addClient(BOB, { spot = "Orgrimmar", class = "MAGE", allowMissing = true })
	T.settle(w)

	local NETK = r.W.Mod("Net.Base").NETK
	local t = r.env.GetTime()
	local direct = r.W.fallback.direct
	direct["aaa oldest"] = { name = "Aaa Oldest", at = t - 200 }
	for i = 1, NETK.GOSSIP_NAMES do
		local nm = string.format("Zzz Driver%s", string.char(64 + i))
		direct[H.key(nm)] = { name = nm, at = t - (NETK.GOSSIP_NAMES - i) }
	end

	local mark = #w.addonLog
	bob.W.SendTo(TESTCHAR, "Q", "1", "0", "0")
	w:advance(5)

	local kMsg
	for i = mark + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.prefix == "WUBER" and e.from == TESTCHAR and e.chatType == "WHISPER" and tostring(e.text):match("^K~") then
			kMsg = e.text
		end
	end
	ok(kMsg ~= nil, "K reply was sent")
	ok(not kMsg:find("Aaa Oldest", 1, true), "oldest driver with smaller key was excluded past GOSSIP_NAMES")
	ok(kMsg:find("Zzz DriverH", 1, true), "latest-heard driver was included")
	T.clean(w)
end)

-- guards Wuber/Net/Discovery.lua:493 (== to ~=)
test("mutation discovery: PruneDirectory evicts the oldest lastSeen entry past DIRECTORY_MAX", function()
	local w = H.NewWorld({ realm = H.FOUNDER_REALM })
	local hay = w:addClient(ANITA, { spot = "Orgrimmar", class = "MAGE", allowMissing = true })
	T.settle(w)

	local NETK = hay.W.Mod("Net.Base").NETK
	local dir, stamp = hay.W.db.directory, hay.env.time()
	for k in pairs(dir) do dir[k] = nil end
	dir["zzz oldest"] = { name = "Zzz Oldest", lastSeen = stamp - 500 }
	for i = 1, NETK.DIRECTORY_MAX do
		local k = string.format("aa lock%03d", i)
		dir[k] = { name = string.format("Aa Lock%03d", i), lastSeen = stamp - i }
	end

	local left = hay.W.PruneDirectory()
	eq(left, NETK.DIRECTORY_MAX, "trimmed to DIRECTORY_MAX")
	eq(dir["zzz oldest"], nil, "oldest entry is evicted")
	ok(dir["aa lock001"] ~= nil, "newest entry with smaller key is kept")
	T.clean(w)
end)

-- guards Wuber/Net/Discovery.lua:576 (return nil)
test("mutation discovery: IsKeptKnown returns boolean false when seen driver is trimmed past KNOWN_MAX", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)

	local BaseMod = r.W.Mod("Net.Base")
	local stamp = r.env.time()
	local seen = BaseMod.seenList()
	seen["old seen"] = { name = "Old Seen", at = stamp - 1000 }
	for i = 1, BaseMod.NETK.KNOWN_MAX + 5 do
		local k = string.format("new seen%02d", i)
		seen[k] = { name = string.format("New Seen%02d", i), at = stamp - i }
	end

	eq(r.W.IsKeptKnown("old seen"), false, "trimmed seen driver returns false, not nil")
	T.clean(w)
end)

-- guards Wuber/Net/Discovery.lua:652 (or to and)
test("mutation discovery: maybeRejoin does not leave channel while in combat", function()
	local w = T.newWorld({ realm = H.FOUNDER_REALM })
	local d = T.driver(w, ANITA, { copy = "lonely" })
	w:splitChannel(d, "lonely", { healOnRejoin = true })
	local dan = T.driver(w, "Dan Driver")
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	T.goOnline(d)
	T.goOnline(dan)

	for _ = 1, 4 do
		r.W.Ping()
		w:advance(60)
	end
	eq(d.leftChannels, nil, "not yet split-rejoined before 5 min threshold")

	w:enterCombat(d)
	for _ = 1, 2 do
		r.W.Ping()
		w:advance(60)
	end
	eq(d.leftChannels, nil, "never leaves channel while in combat")
	eq(d.W.net.rejoined, false, "rejoined flag stays false in combat")

	w:leaveCombat(d)
	r.W.Ping()
	w:advance(60)
	eq(d.leftChannels, 1, "rejoins once out of combat")
	eq(d.W.net.rejoined, true, "rejoined flag is set after leaving combat")
	T.clean(w)
end)
