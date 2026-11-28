-- Guard tests for Wuber/Net/Base.lua and Wuber/Net/Favourites.lua.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local TESTCHAR, ANITA, BOB = T.TESTCHAR, T.ANITA, "Bob Helper"

-- guards Wuber/Net/Base.lua:214 (return -> nil: myKey falls back to UnitName("player") when W.myKey is "?")
test("mutation b5 base: RequestRide still refuses self-request when W.myKey is placeholder", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	r.W.myKey = "?"
	local meKey = r.W.Key(TESTCHAR)
	r.W.drivers[meKey] = { name = TESTCHAR, key = meKey, addr = TESTCHAR, dest = "Orgrimmar", price = 5000, state = "open" }
	local res, err = r.W.RequestRide(meKey)
	eq(res, nil, "refuses self-request")
	eq(err, "self", "reason is self via UnitName fallback")
	T.clean(w)
end)

-- guards Wuber/Net/Base.lua:296 (cmp <=-> >: Encode truncates to MAX_BYTES only after shrinking field limit to 0)
-- Skipped Wuber/Net/Base.lua:297 (drop statement: limit = math.max(0, limit - 8) causes an infinite loop in W.Encode)
test("mutation b5 base: Encode shrinks field limits before truncating at MAX_BYTES", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local f5 = string.rep("e", 60)
	local encoded = r.W.Encode("D", string.rep("a", 60), string.rep("b", 60), string.rep("c", 60), string.rep("d", 60), f5)
	ok(#encoded <= 250, "encoded message stays within MAX_BYTES")
	local _, _, f = r.W.Decode(encoded)
	ok(f and #f == 5 and #f[5] > 0, "fifth field is preserved by shrinking field limit instead of early truncation")
	local huge = r.W.Encode("D", string.rep("x", 300), string.rep("y", 300), string.rep("z", 300))
	ok(#huge <= 250, "even when limit hits 0, output is capped at MAX_BYTES")
	T.clean(w)
end)

-- guards Wuber/Net/Base.lua:360 (return -> nil: W.Faction returns "" for unknown/neutral faction)
test("mutation b5 base: Faction returns empty string when player faction is unknown", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	r.env.UnitFactionGroup = function() return "Neutral" end
	eq(r.W.Faction(), "", "unknown faction returns empty string, not nil")
	T.clean(w)
end)

-- guards Wuber/Net/Base.lua:390 (drop statement: pcall(ChatFrameUtil.RemoveChannel, f, W.CHANNEL))
test("mutation b5 base: HideChannel uses ChatFrameUtil.RemoveChannel when legacy global is absent", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local removed = 0
	r.env.ChatFrame_RemoveChannel = false
	r.env.ChatFrameUtil = {
		RemoveChannel = function(_, ch)
			if ch == r.W.CHANNEL then removed = removed + 1 end
		end,
	}
	r.env._G.ChatFrame1 = r.env._G.ChatFrame1 or {}
	r.W.HideChannel()
	ok(removed >= 1, "ChatFrameUtil.RemoveChannel was called for W.CHANNEL")
	T.clean(w)
end)

-- guards Wuber/Net/Base.lua:487 (swap and->or: pruneSeen tie-breaker compares key only when at == oldAt)
-- guards Wuber/Net/Base.lua:489 (drop statement: list[oldKey] = nil)
-- Skipped Wuber/Net/Base.lua:490 (drop statement: n = n - 1 causes an infinite loop in pruneSeen)
test("mutation b5 base: seenDrivers prunes oldest entry and caps at 60", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	local d = T.driver(w, "Zzz Driver", { spot = "Orgrimmar" })
	T.settle(w)
	local t0 = r.env.time()
	r.W.db.seenDrivers = {}
	r.W.db.seenDrivers["zzz_oldest"] = { name = "Zzz Oldest", addr = "Zzz Oldest", at = t0 - 100 }
	for i = 1, 59 do
		local k = string.format("aaa_%02d", i)
		r.W.db.seenDrivers[k] = { name = k, addr = k, at = t0 - 10 }
	end
	T.goOnline(d, { price = 5000 })
	w:advance(3)
	local count = 0
	for _ in pairs(r.W.db.seenDrivers) do count = count + 1 end
	eq(count, 60, "seenDrivers is capped at SEEN_MAX (60)")
	eq(r.W.db.seenDrivers["zzz_oldest"], nil, "oldest seenDriver is evicted")
	ok(r.W.db.seenDrivers["aaa_01"] ~= nil, "newer alphabetically-earlier seenDriver is kept")
	T.clean(w)
end)

-- guards Wuber/Net/Base.lua:559 (drop statement: clearLater = true)
test("mutation b5 base: repeated PASSWORD_CHANGED notices within 30s queue only one retry clear", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local clears = 0
	r.env.IsDisplayChannelOwner = function() return true end
	r.env.SetChannelPassword = function() clears = clears + 1 end
	r:fire("CHAT_MSG_CHANNEL_NOTICE_USER", "PASSWORD_CHANGED", "", "", r.W.CHANNEL, "OtherPlayer")
	eq(clears, 1, "first notice clears password immediately")
	r:fire("CHAT_MSG_CHANNEL_NOTICE_USER", "PASSWORD_CHANGED", "", "", r.W.CHANNEL, "OtherPlayer")
	r:fire("CHAT_MSG_CHANNEL_NOTICE_USER", "PASSWORD_CHANGED", "", "", r.W.CHANNEL, "OtherPlayer")
	w:advance(70)
	eq(clears, 2, "only one delayed retry clear runs after 30s")
	T.clean(w)
end)

-- guards Wuber/Net/Base.lua:568 (swap and->or: if W.net.warned and not W.net.lockedSaid then)
-- guards Wuber/Net/Base.lua:569 (drop statement: W.net.lockedSaid = true)
-- guards Wuber/Net/Base.lua:570 (drop statement: W.Print(LOCKED_LINE))
-- guards Wuber/Net/Base.lua:612 (drop statement: W.net.lockedSaid = true)
test("mutation b5 base: password-locked channel prints notice once after warned", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local prints = 0
	local origPrint = r.W.Print
	r.W.Print = function(msg)
		if tostring(msg):find("password", 1, true) then prints = prints + 1 end
		return origPrint(msg)
	end
	r.W.net.warned = false
	r.W.net.lockedSaid = nil
	r:fire("CHAT_MSG_CHANNEL_NOTICE", "WRONG_PASSWORD", "", "", r.W.CHANNEL)
	eq(prints, 0, "does not print locked line before warned is true")
	r.W.net.warned = true
	r:fire("CHAT_MSG_CHANNEL_NOTICE", "WRONG_PASSWORD", "", "", r.W.CHANNEL)
	eq(prints, 1, "prints locked line once warned is true")
	r:fire("CHAT_MSG_CHANNEL_NOTICE", "WRONG_PASSWORD", "", "", r.W.CHANNEL)
	eq(prints, 1, "does not print locked line a second time")

	-- Also guard CheckChannel setting lockedSaid (line 612)
	r.W.net.warned = nil
	r.W.net.lockedSaid = nil
	r.W.net.locked = true
	r.W.net.joinFails = 1
	r.env.GetChannelName = function() return 0 end
	r.env.JoinTemporaryChannel = nil
	r.env.JoinChannelByName = nil
	w:advance(70)
	r.W.CheckChannel(true)
	w:advance(4)
	eq(prints, 2, "CheckChannel prints locked line when 2nd join fails")
	r:fire("CHAT_MSG_CHANNEL_NOTICE", "WRONG_PASSWORD", "", "", r.W.CHANNEL)
	eq(prints, 2, "WRONG_PASSWORD afterwards does not repeat locked line")
	T.clean(w)
end)

-- guards Wuber/Net/Favourites.lua:46 (cmp ~=->==: byPrice sorts different prices cheapest first)
-- guards Wuber/Net/Favourites.lua:47 (return -> nil: byPrice breaks price ties alphabetically by key)
test("mutation b5 favs: FAV_ONLINE picks cheapest favourite driver and breaks ties by key", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	local dZed = T.driver(w, "Zed Driver", { spot = "Orgrimmar" })
	local dAna = T.driver(w, "Ana Driver", { spot = "Orgrimmar" })
	local dBob = T.driver(w, "Bob Driver", { spot = "Orgrimmar" })
	local dCal = T.driver(w, "Cal Driver", { spot = "Orgrimmar" })
	local dDan = T.driver(w, "Dan Driver", { spot = "Orgrimmar" })
	T.settle(w)
	local firstKey, favList
	r.W.Listen("FAV_ONLINE", function(d, _, list)
		firstKey = d and d.key
		favList = list
	end)
	r.W.ToggleFav("Zed Driver")
	r.W.ToggleFav("Ana Driver")
	T.goOnline(dZed, { price = 2000 })
	T.goOnline(dAna, { price = 9000 })
	w:advance(6)
	eq(firstKey, "zed driver", "cheapest favourite driver is chosen first")

	-- Same price tie-break: "bob driver" < "cal driver" < "dan driver"
	firstKey, favList = nil, nil
	r.W.db.toastAt = {}
	r.W.ToggleFav("Bob Driver")
	r.W.ToggleFav("Cal Driver")
	r.W.ToggleFav("Dan Driver")
	local inCombat = true
	r.env.InCombatLockdown = function() return inCombat end
	T.goOnline(dDan, { price = 5000 })
	T.goOnline(dCal, { price = 5000 })
	T.goOnline(dBob, { price = 5000 })
	w:advance(15)
	inCombat = false
	r:fire("PLAYER_REGEN_ENABLED")
	w:advance(1)
	eq(firstKey, "bob driver", "equal-price favourite tie is broken alphabetically by key")
	eq(favList and favList[2] and favList[2].key, "cal driver", "second equal-price favourite is cal driver")
	eq(favList and favList[3] and favList[3].key, "dan driver", "third equal-price favourite is dan driver")
	T.clean(w)
end)

-- Skipped Wuber/Net/Favourites.lua:59 (drop statement: duplicate AfterCombat flushToasts is a no-op because the first flush clears pendingFav/pendingWatch)
-- guards Wuber/Net/Favourites.lua:61 (drop statement: toastCombat = false)
test("mutation b5 favs: combat defers favourite toast once and resets after combat ends", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	local d1 = T.driver(w, ANITA, { spot = "Orgrimmar" })
	local d2 = T.driver(w, BOB, { spot = "Orgrimmar" })
	local d3 = T.driver(w, "Cal Driver", { spot = "Orgrimmar" })
	T.settle(w)
	local toasts = 0
	r.W.Listen("FAV_ONLINE", function() toasts = toasts + 1 end)
	r.W.ToggleFav(ANITA)
	r.W.ToggleFav(BOB)
	local inCombat = true
	r.env.InCombatLockdown = function() return inCombat end
	T.goOnline(d1, { price = 5000 })
	w:advance(4.5)
	-- Second driver triggers another flushToasts while still in combat.
	T.goOnline(d2, { price = 5000 })
	w:advance(4.5)
	eq(toasts, 0, "no favourite toast fires during combat")
	inCombat = false
	r:fire("PLAYER_REGEN_ENABLED")
	w:advance(1)
	eq(toasts, 1, "deferred favourite toast fires once when combat ends")

	-- Second combat later must still defer and fire again (toastCombat was reset to false).
	r.W.db.toastAt = {}
	r.W.drivers = {}
	r.W.ToggleFav("Cal Driver")
	inCombat = true
	T.goOnline(d3, { price = 5000 })
	w:advance(5)
	eq(toasts, 1, "second combat defers toast again")
	inCombat = false
	r:fire("PLAYER_REGEN_ENABLED")
	w:advance(1)
	eq(toasts, 2, "second combat toast fires after regen enabled")
	T.clean(w)
end)

-- guards Wuber/Net/Favourites.lua:195 (drop statement: W.Fire("SETTINGS", "hidden"))
-- guards Wuber/Net/Favourites.lua:196 (drop statement: W.Fire("DRIVERS"))
-- guards Wuber/Net/Favourites.lua:204 (drop statement: n = n + 1)
-- guards Wuber/Net/Favourites.lua:207 (return -> nil: return n)
test("mutation b5 favs: HideDriver fires SETTINGS and DRIVERS and ShowAllDrivers returns hidden count", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local settingsHidden, driversFired = 0, 0
	r.W.Listen("SETTINGS", function(what) if what == "hidden" then settingsHidden = settingsHidden + 1 end end)
	r.W.Listen("DRIVERS", function() driversFired = driversFired + 1 end)
	r.W.HideDriver(ANITA, true)
	eq(settingsHidden, 1, "HideDriver fires SETTINGS hidden")
	eq(driversFired, 1, "HideDriver fires DRIVERS")
	r.W.HideDriver(BOB, true)
	eq(r.W.ShowAllDrivers(), 2, "ShowAllDrivers returns count of unhidden drivers")
	T.clean(w)
end)
