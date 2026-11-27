local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- Round 33, HUNT-107: the "That's a wrap" summary line says "1 place" and "1 summon" when the count is one.

local function summary(rides, places)
	local w = T.newWorld()
	local r = T.rider(w)
	local Mod = r.W.Mod("UI.Rider.Wrapped")
	local slides = Mod.Slides({ rides = rides, places = places, saved = 0, name = "October" })
	local line = slides[#slides].lines[1]
	T.clean(w)
	return line
end

test("r33 j5: the Wrapped summary says 1 place, not 1 places", function()
	eq(summary(3, 1), "3 summons \194\183 1 place", "three summons to one place")
	eq(summary(1, 1), "1 summon \194\183 1 place", "one summon to one place")
	eq(summary(3, 2), "3 summons \194\183 2 places", "plural kept")
	eq(summary(0, 0), "0 summons \194\183 0 places", "zero plural kept")
end)
