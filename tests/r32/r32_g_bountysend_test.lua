local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function ws(w, from)
	local out = {}
	for _, e in ipairs(T.msgs(w, "W", from, "CHANNEL")) do
		if e.target == nil or type(e.target) == "number" then out[#out + 1] = e end
	end
	return out
end

-- AUD-31: a bounty pinned before the channel is joined is not counted as sent.
test("r32 g AUD-31: a bounty pinned before WuberNet is joined is still told to drivers once on", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	w:advance(1)
	eq(r.W.OnNetwork(), false, "precondition: not on WuberNet yet at login + 1 s")
	eq(r.W.Bounty.Pin("gadget", 6000), true, "pinned")
	w:advance(120)
	eq(r.W.OnNetwork(), true, "on the network after 2 min")
	ok(#ws(w, T.TESTCHAR) >= 1, "a W went out once the rider was on the network (sends=" ..
		tostring(r.W.db.bounty and r.W.db.bounty.sends) .. ")")
	T.clean(w)
end)

-- HUNT-104: a second place pinned within a minute reaches a driver (the gap is on real seconds).
test("r32 g HUNT-104: a bounty changed to another place within a minute is counted by the driver", function()
	for _, offset in ipairs({ 0, 0.3, 0.6, 0.9 }) do
		local w = T.newWorld()
		local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
		local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
		T.settle(w)
		w:advance(offset)
		eq(r.W.Bounty.Pin("gadget", 6000), true, "first pinned")
		w:advance(20)
		eq(r.W.Bounty.Pin("ratchet", 6000), true, "second pinned")
		w:advance(100)
		local seen = false
		for _, row in ipairs(d.W.Bounty.Demand()) do
			if row.place == "Ratchet" then seen = true end
		end
		ok(seen, "the driver shows the second place (offset " .. offset .. ")")
		T.clean(w)
	end
end)
