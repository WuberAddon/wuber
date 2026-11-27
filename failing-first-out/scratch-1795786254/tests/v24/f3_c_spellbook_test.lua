-- Wuber 2.4 fix round 3, group C: LRN-08, a spellbook that cannot be read just after login must not say
-- "cannot summon" (DR.CanCast, the Ready list) before it has been asked again. Fake switch: addClient opts.spellbookLate.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function lock(late, knows)
	local w = T.newWorld()
	local c = w:addClient(T.ANITA, { spot = "Ratchet", class = "WARLOCK", spellbookLate = late, knowsRitual = knows })
	return w, c
end

test("v24 f3c: control: a readable spellbook that lacks the ritual says so at once", function()
	local w, c = lock(nil, false)
	w:advance(1)
	local good, why = c.W.Drive.CanCast(c.W.myKey)
	eq(good, false, "cannot")
	eq(why, "does not know the summoning spell", "why")
	T.clean(w)
end)

test("v24 f3c: an unreadable spellbook just after login does not say 'does not know the summoning spell'", function()
	local w, c = lock(4, true)
	w:advance(1)
	local good, why = c.W.Drive.CanCast(c.W.myKey)
	ok(good ~= false or why ~= "does not know the summoning spell", "no wrong 'does not know' at 1 s (got " .. tostring(why) .. ")")
	w:advance(5)
	eq(select(2, c.W.Drive.Ritual()), true, "known once the book is readable")
	eq(c.W.Drive.CanCast(c.W.myKey), true, "can cast")
	T.clean(w)
end)

test("v24 f3c: a Warlock who really lacks it is told after the 10 s window", function()
	local w, c = lock(4, false)
	w:advance(1)
	ok(select(2, c.W.Drive.CanCast(c.W.myKey)) ~= "does not know the summoning spell", "not yet at 1 s")
	w:advance(12)
	local good, why = c.W.Drive.CanCast(c.W.myKey)
	eq(good, false, "cannot")
	eq(why, "does not know the summoning spell", "told once the window has passed")
	T.clean(w)
end)
