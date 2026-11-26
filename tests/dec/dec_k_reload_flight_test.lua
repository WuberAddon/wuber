-- Decisions round, group K: a flight in the air survives a /reload (saved with the server's clock), and the bug
-- report says where a blocked action came from. Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local UC_TM = { { name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 },
	{ name = "Tarren Mill, Hillsbrad", type = "REACHABLE", cost = 330, x = 0.47, y = 0.44 } }

local function stored(r, a, b)
	local e = r.W.db.flights and r.W.db.flights["H|" .. a .. "|" .. b]
	return e and e.t
end

local function inAir(secsBeforeReload)
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Undercity" })
	T.settle(w)
	w:openTaxiMap(r, UC_TM)
	w:takeTaxi(r, 2)
	w:advance(1 + secsBeforeReload)
	return w, r
end

test("dec k: a /reload in the air picks the flight up again and the landing is recorded with the true time", function()
	local w, r = inAir(30)
	eq(r.player.onTaxi, true, "in the air")
	local c = w:reload(r)
	w:advance(2)
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	ok(c.W.FlightLeft(), "the flight is timed again after the reload")
	w:advance(40)
	w:landTaxi(c, "Tarren Mill")
	w:advance(1)
	local t = stored(c, "undercity", "tarren mill")
	ok(t and t >= 70 and t <= 76, "about 72 s stored, got " .. tostring(t))
end)

test("dec k: a /reload after landing (not on a taxi) drops the saved start and records nothing", function()
	local w, r = inAir(30)
	r.player.onTaxi = false
	local c = w:reload(r)
	w:advance(2)
	eq(c.W.FlightLeft(), nil, "no flight timed")
	eq(c.W.Char().flightStart, nil, "the saved start is gone")
	w:landTaxi(c, "Tarren Mill")
	w:advance(1)
	eq(stored(c, "undercity", "tarren mill"), nil, "no flight time recorded")
end)

test("dec k: a saved start older than its expected time plus the margin is not picked up", function()
	local w, r = inAir(30)
	local e = r.W.Char().flightStart
	ok(e and e.exp, "the start is saved with its expected seconds")
	w:advance(e.exp + r.W.Mod("Core.FlightTimes").FT.LAND_MARGIN + 5)
	local c = w:reload(r)
	w:advance(2)
	eq(c.W.FlightLeft(), nil, "too old: dropped")
	eq(c.W.Char().flightStart, nil)
end)

-- Idea 12: a blocked action: where it came from, in the report; the game's error handler at most once in 30 s
local STACK = "[string \"=[C]\"]: in function 'x'\n" ..
	"Interface\\AddOns\\Wuber\\Core\\Runtime.lua:480: in function <Interface\\AddOns\\Wuber\\Core\\Runtime.lua:470>\n" ..
	"Interface\\AddOns\\Wuber\\Drive\\Invite.lua:212: in function 'go'\n" ..
	"Interface\\AddOns\\Other\\Thing.lua:9: in main chunk"

test("dec k: a blocked action is kept with the first Wuber file:line (the last five), listed in the bug report", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Undercity" })
	T.settle(w)
	r.env.debugstack = function() return STACK end
	r.env.geterrorhandler = function() return function() end end
	for i = 1, 7 do
		r:fire("ADDON_ACTION_BLOCKED", "Wuber", "Func" .. i .. "()")
		w:advance(1)
	end
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	local list = r.W.blockedAt
	eq(#list, 5, "the last five")
	eq(list[5].func, "Func7()")
	eq(list[5].where, "Drive/Invite.lua:212", "the first frame in Wuber's own code, not the dispatch in Runtime.lua")
	local text = r.W.UI.Bug.Report("x")
	ok(text:find("Blocked actions (last 5", 1, true), "the report has the heading")
	ok(text:find("Func7() from Drive/Invite.lua:212", 1, true), "and the line")
	ok(not text:find("Func1()", 1, true), "the oldest is gone")
	ok(not text:find("Thing.lua", 1, true), "no other addon's frame")
end)

test("dec k: the game's error handler gets a blocked action at most once in 30 s", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Undercity" })
	T.settle(w)
	local got = {}
	r.env.debugstack = function() return STACK end
	r.env.geterrorhandler = function() return function(m) got[#got + 1] = m end end
	r:fire("ADDON_ACTION_BLOCKED", "Wuber", "A()")
	w:advance(10)
	r:fire("ADDON_ACTION_FORBIDDEN", "Wuber", "B()")
	w:advance(10)
	r:fire("ADDON_ACTION_BLOCKED", "Wuber", "C()")
	eq(#got, 1, "once in the first 30 s")
	ok(got[1]:find("A()", 1, true) and got[1]:find("Drive/Invite.lua:212", 1, true), got[1])
	w:advance(15)
	r:fire("ADDON_ACTION_BLOCKED", "Wuber", "D()")
	eq(#got, 2, "again after 30 s")
	r:fire("ADDON_ACTION_BLOCKED", "SomeoneElse", "E()")
	eq(#got, 2, "another addon's block is not Wuber's")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
end)
