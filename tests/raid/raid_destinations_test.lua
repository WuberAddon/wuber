local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- Raid destinations (WoW Forever opens Barrow Deeps, Hyjal Summit and Onyxia's Lair on 9 December 2026):
-- a rider standing at, or asking for, a raid place gets a normal request, a name every screen agrees on
-- and a driver match. Zone names are the game's own (flight node "Summit of Eternity, Mount Hyjal").

local function world(side)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = side == "H" and "Orgrimmar" or "Stormwind", faction = side == "H" and "Horde" or "Alliance" })
	T.settle(w)
	return w, r
end

test("raid places: Onyxia's Lair is a place, a request and a driver match", function()
	local w, r = world("H")
	local W = r.W
	local p = W.ExactPlace("Onyxia's Lair")
	ok(p and p.kind == "dungeon", "Onyxia's Lair is a dungeon place")
	local name, valid = W.ValidDest("Onyxia")
	eq(name, "Onyxia's Lair", "ValidDest names it")
	ok(valid, "and it is a known place")
	eq(W.Drive.DestIn("wtb summon to ony pls"), "Onyxia's Lair", "a driver reads the line")
	T.clean(w)
end)

test("raid places: Mount Hyjal is a place in the core table", function()
	local w, r = world("H")
	local W = r.W
	ok(W.ExactPlace("Mount Hyjal"), "Mount Hyjal is a place")
	ok(W.FindPlace("hyjal"), "hyjal finds it")
	local name, valid = W.ValidDest("Mount Hyjal")
	eq(name, "Mount Hyjal", "ValidDest names it")
	ok(valid, "and it is a known place")
	local p = W.FindPlace("Hyjal Summit")
	ok(p and p.name == "Mount Hyjal", "Hyjal Summit finds the Mount Hyjal place")
	eq(W.Drive.DestIn("wtb summon to hyjal summit"), "Mount Hyjal", "a driver reads the line")
	T.clean(w)
end)
