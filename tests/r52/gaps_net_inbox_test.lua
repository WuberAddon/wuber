-- Final home: tests/net/inbox_test.lua; add it to the per-module list in tests/run.lua.
-- Pins:
--   the contract (registered, deps = Uses, W.NetTick)
--   CHAT_MSG_ADDON ignores another addon's prefix, a missing sender and our own echo (the echo is only noted)
--   a whisper-only kind heard over the channel, or any kind over PARTY, is ignored
--   B (booked with another driver) by whisper: noted, and an "offline" mark on that player is cleared
--   X (a driver signs off) drops the driver and a hidden copy of her, and fires DRIVERS once; X from a stranger fires nothing
-- Why it matters to a player: the inbox is the only door for every ride message. If it let the wrong things in, a
-- stranger or another addon could fake a ride step, a driver who signed off would stay on the rider's list, and a
-- rider who booked elsewhere would still be chased by a driver's answers.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local TESTCHAR, ANITA, BOB = T.TESTCHAR, T.ANITA, "Bob Helper"
local AKEY, BKEY = "anita lift", "bob helper"

test("net.inbox: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("Net.Inbox", "tests/net/inbox_test.lua", {
		["W.NetTick"] = "function",
	})
	ok(Mod, "W.Mod(\"Net.Inbox\")")
	T.clean(w)
end)

-- a rider (Wuber) on the network; the messages below are handed to his game as CHAT_MSG_ADDON
local function setup()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" }) -- (a whisper from him may be answered: he must exist)
	T.settle(w)
	return w, r
end

local function hear(r, text, chan, sender)
	r:fire("CHAT_MSG_ADDON", "WUBER", text, chan, sender)
end

-- guard: coverage, fable-2411 draft adopted in r52
test("net.inbox: another addon's prefix, a missing sender and an empty sender are ignored", function()
	local w, r = setup()
	local heard = r.W.net.heard
	r:fire("CHAT_MSG_ADDON", "OTHERADDON", r.W.Encode("B"), "WHISPER", BOB) -- Inbox.lua:42
	r:fire("CHAT_MSG_ADDON", "WUBER", r.W.Encode("B"), "WHISPER", nil) -- Inbox.lua:47
	r:fire("CHAT_MSG_ADDON", "WUBER", r.W.Encode("B"), "WHISPER", "")
	eq(r.W.net.heard, heard, "nothing counted as heard")
	eq(r.W.fallback.booked[BKEY], nil, "nothing noted")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("net.inbox: our own echo on the channel is only noted, never handled", function()
	local w, r = setup()
	local heard = r.W.net.heard
	r.W.fallback.echoAt = nil
	hear(r, r.W.Encode("X"), "CHANNEL", TESTCHAR)
	ok(r.W.fallback.echoAt ~= nil, "the echo is noted (the whisper fallback's rejoin check reads it)") -- Inbox.lua:51-58
	eq(r.W.net.heard, heard, "not counted as heard")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("net.inbox: a whisper-only kind over the channel, or anything over PARTY, is ignored", function()
	local w, r = setup()
	local heard = r.W.net.heard
	hear(r, r.W.Encode("B"), "CHANNEL", BOB) -- B is whisper-only: Inbox.lua:64
	hear(r, r.W.Encode("B"), "PARTY", BOB)
	hear(r, r.W.Encode("X"), "PARTY", ANITA) -- a channel kind may come by channel or whisper only: Inbox.lua:63
	eq(r.W.net.heard, heard, "nothing counted")
	eq(r.W.fallback.booked[BKEY], nil, "the B was not handled")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("net.inbox: B by whisper: the rider booked elsewhere is noted, and an offline mark on him is cleared", function()
	local w, r = setup()
	local fb = r.W.fallback
	local heard = r.W.net.heard
	fb.offlineUntil[BKEY] = 1e9
	fb.riders[BKEY] = { at = 1 }
	hear(r, r.W.Encode("B"), "WHISPER", BOB)
	eq(r.W.net.heard, heard + 1, "counted") -- Inbox.lua:76
	ok(fb.booked[BKEY] ~= nil, "booked elsewhere: no more answers or pushes") -- Inbox.lua:113
	eq(fb.riders[BKEY], nil, "dropped from the fallback's riders")
	eq(fb.offlineUntil[BKEY], nil, "a whisper from him proves he is online") -- Inbox.lua:124
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("net.inbox: X drops the driver and her hidden copy and fires DRIVERS; X from a stranger fires nothing", function()
	local w, r = setup()
	local W = r.W
	local fired = 0
	W.Listen("DRIVERS", function() fired = fired + 1 end)
	W.drivers[AKEY] = { key = AKEY, name = ANITA, addr = ANITA, state = "open", dest = "Ratchet" }
	W.hiddenDrivers = W.hiddenDrivers or {}
	W.hiddenDrivers[AKEY] = true
	hear(r, W.Encode("X"), "CHANNEL", ANITA)
	eq(W.drivers[AKEY], nil, "the driver is gone") -- Inbox.lua:80-83
	eq(W.hiddenDrivers[AKEY], nil, "Show all hidden drivers can't bring her back (AUD-42)") -- Inbox.lua:85
	ok(fired >= 1, "DRIVERS fired")
	local before = fired
	hear(r, W.Encode("X"), "CHANNEL", BOB)
	eq(fired, before, "a stranger's X: no DRIVERS")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("net.inbox: X by whisper (the whisper fallback) drops the driver too", function()
	local w, r = setup()
	local W = r.W
	W.drivers[AKEY] = { key = AKEY, name = ANITA, addr = ANITA, state = "open", dest = "Ratchet" }
	hear(r, W.Encode("X"), "WHISPER", ANITA) -- X is in WHISPER_TOO: Inbox.lua:63
	eq(W.drivers[AKEY], nil, "gone")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("net.inbox: a heard channel message marks its sender as heard on the channel", function()
	local w, r = setup()
	local fb = r.W.fallback
	fb.chanHeard[BKEY] = nil
	hear(r, r.W.Encode("X"), "CHANNEL", BOB)
	ok(fb.chanHeard[BKEY] ~= nil, "noted for the whisper fallback") -- Inbox.lua:68
	ok(fb.chanOthersAt ~= nil, "others are heard on WuberNet") -- Inbox.lua:73
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("net.inbox: W.NetTick runs every part without an error, even called by hand between seconds", function()
	local w, r = setup()
	for _ = 1, 6 do r.W.NetTick() end -- the 5th tick expires drivers too (Inbox.lua:205)
	eq(r.W.lastError, nil, "no error caught by W.Safe")
	T.clean(w)
end)
