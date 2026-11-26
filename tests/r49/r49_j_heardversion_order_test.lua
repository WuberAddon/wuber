-- r49 group J (item 8): W.HeardVersion must not depend on the order the game walks a table.
-- Promise: when the list of remembered players is full, the one pushed out is the one heard FIRST (arrival
-- order), also when two reports came in the same clock tick. So the newer-version notice is the same
-- whether pairs() walks the reports one way or the other. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function setup()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { version = "2.3.0" })
	T.settle(w)
	return w, r, r.W.Mod("Net.Update")
end

-- pairs() shim (set in the rider's own game environment): a table whose keys are all strings is walked in sorted order (dir = 1 up, -1 down), so a
-- tie that falls to the walk order is decided the same way on every run.
local realPairs = pairs
local function envOf(r) return r.env or r.client and r.client.env end
local function walkSorted(dir)
	return function(t)
		local keys = {}
		for k in realPairs(t) do
			if type(k) ~= "string" then return realPairs(t) end
			keys[#keys + 1] = k
		end
		table.sort(keys, function(a, b)
			if dir > 0 then return a < b end
			return a > b
		end)
		local i = 0
		return function()
			i = i + 1
			local k = keys[i]
			if k ~= nil then return k, t[k] end
		end, t, nil
	end
end

-- room for two players; a says 2.3.9 then b says 2.3.1 (same tick: they agree on 2.3.1); the notice is cleared;
-- then c says 2.3.5 and pushes one of them out. a (first heard) goes: b and c remain, they agree on 2.3.1.
-- If b went instead, a and c would agree on 2.3.5.
local function pushOut(dir, gap)
	local w, r, Mod = setup()
	local W = r.W
	Mod.U.MAX = 2
	Mod.U.NEED = 2
	local env = envOf(r)
	ok(env, "the rider has its own environment")
	local was = rawget(env, "pairs")
	env.pairs = walkSorted(dir)
	local good, err = pcall(function()
		W.HeardVersion("alpha one", "2.3.9")
		if gap then w:advance(gap) end
		W.HeardVersion("bravo two", "2.3.1")
		eq(W.NewerVersion(), "2.3.1", "a and b agree on 2.3.1")
		W.db.newer = nil
		if gap then w:advance(gap) end
		W.HeardVersion("charlie three", "2.3.5")
	end)
	env.pairs = was
	if not good then error(err, 0) end
	local got = W.NewerVersion()
	T.clean(w)
	return got
end

test("r49 J: the player pushed out is the first one heard, walking the table up or down (same tick)", function()
	eq(pushOut(1, nil), "2.3.1", "walk up: a is pushed out")
	eq(pushOut(-1, nil), "2.3.1", "walk down: a is pushed out")
end)

-- guard: reports a second apart already pushed out the oldest by time, whatever the walk order
test("r49 J: reports a second apart: the oldest is pushed out in either walk order", function()
	eq(pushOut(1, 1), "2.3.1", "walk up")
	eq(pushOut(-1, 1), "2.3.1", "walk down")
end)

-- guard: the cap of 50 and the count are unchanged
test("r49 J: the cap still holds with many reports in one tick", function()
	local w, r, Mod = setup()
	for i = 1, 60 do r.W.HeardVersion("player" .. i, "2.3.1") end
	eq(Mod.count(), 50, "the cap holds")
	T.clean(w)
end)
