-- r51 group O (HUNT F005): the newer-version note after a fight. Loaded by tests/run.lua with helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local ANITA, TESTCHAR = T.ANITA, T.TESTCHAR

local function setup()
	local w = T.newWorld({ realm = T.H.FOUNDER_REALM })
	local r = T.rider(w, TESTCHAR, { version = "2.3.0" })
	T.settle(w)
	local toasts = {}
	local UI = r.W.UI
	local real = UI.Toast
	UI.Toast = function(text, kind, fn)
		toasts[#toasts + 1] = { text = text, kind = kind, fn = fn }
		return real(text, kind, fn)
	end
	return w, r, toasts
end

local function beacon(w, from, ver)
	w:inject(from, "D~1~Ratchet~1413~500~500~5000~~open~1~0~~" .. ver, "CHANNEL")
	w:advance(0.5)
end

-- the promise: told during a fight, the note comes once the fight ends (never in combat), once per version
for _, step in ipairs({ 1, 5 }) do
	-- guard: Net.Update is right (F005 is the hunt promise's check: the founder's word counts only on the founders' ruleset)
	test("r51 o: the note told of in a fight comes after it (steps of " .. step .. " s)", function()
		local w, r, toasts = setup()
		w:enterCombat(r)
		beacon(w, ANITA, "2.3.1")
		for _ = 1, math.floor(40 / step) do
			w:advance(step)
			eq(#toasts, 0, "no note in the fight")
		end
		w:leaveCombat(r)
		for _ = 1, math.floor(60 / step) do w:advance(step) end
		eq(#toasts, 1, "the note came once after the fight")
		for _ = 1, math.floor(60 / step) do w:advance(step) end
		eq(#toasts, 1, "still once")
		T.clean(w)
	end)
end

-- guard: out of combat the note shows at once (no fight involved)
test("r51 o: out of combat the note shows without a fight", function()
	local w, r, toasts = setup()
	beacon(w, ANITA, "2.3.1")
	w:advance(30)
	eq(#toasts, 1, "the note came")
	T.clean(w)
end)

-- guard: on a realm that names no ruleset the founder's word is only one player's word (Core.Base IsCreator):
-- the hunt's F005 was this (its check heard the founder alone); two players tell it, and after a fight too
-- guard: Net.Update is right, the hunt promise's check was wrong
test("r51 o: off the founders' ruleset one player is not enough, two are, and the note waits for the fight", function()
	local w = T.newWorld({ realm = "Nowhere" })
	local r = T.rider(w, TESTCHAR, { version = "2.3.0" })
	T.settle(w)
	local toasts = {}
	local UI = r.W.UI
	local real = UI.Toast
	UI.Toast = function(text, kind, fn) toasts[#toasts + 1] = text return real(text, kind, fn) end
	w:enterCombat(r)
	beacon(w, ANITA, "2.3.1")
	w:advance(60)
	eq(r.W.NewerVersion(), nil, "one player alone: not trusted off the founders' ruleset")
	beacon(w, T.BEA, "2.3.1")
	w:advance(40)
	eq(#toasts, 0, "no note in the fight")
	w:leaveCombat(r)
	w:advance(30)
	eq(#toasts, 1, "the note came after the fight")
	T.clean(w)
end)
