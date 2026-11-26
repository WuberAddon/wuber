local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function ws(w, from)
	local out = {}
	for _, e in ipairs(T.msgs(w, "W", from, "CHANNEL")) do
		if e.target == nil or type(e.target) == "number" then out[#out + 1] = e end
	end
	return out
end

test("r33 k2 AUD-43: replacing a sent bounty then cancelling the new one inside a minute leaves the first on drivers' lists", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	eq(r.W.Bounty.Pin("gadget", 6000), true, "pinned A")
	w:advance(3)
	local list = ws(w, T.TESTCHAR)
	eq(#list, 1, "control: A was sent once")
	local f = T.fields(list[1])
	eq(f[4], "6000", "control: A sent with its fare")
	eq(r.W.Bounty.Pin("booty bay", 7000), true, "pinned B in its place (within the minute)")
	w:advance(3)
	eq(r.W.Bounty.Cancel(), true, "cancelled B")
	w:advance(180)
	local cancelA = false
	for _, e in ipairs(ws(w, T.TESTCHAR)) do
		local ff = T.fields(e)
		if ff[3] == "Gadgetzan" and ff[4] == "0" then cancelA = true end
	end
	ok(cancelA, "the rider cancelled everything, but no copper-0 W for Gadgetzan went out: drivers keep showing the old pledge for up to 30 min")
	T.clean(w)
end)