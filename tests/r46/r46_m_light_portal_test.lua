-- Round 46 m: Effects set to Light plays no full-screen effect (HUNT-18); the emblem's art is called a
-- portal in its texts, the look stays named Orb (HUNT-68).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local TESTCHAR = T.TESTCHAR

test("r46.m: Effects on Light plays no full-screen effect; Full still does", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local W = r.W
	W.db.fx = "light"
	eq(W.FX.Fullscreen("paid"), nil, "paid: nothing on Light")
	eq(W.FX.Fullscreen("portal_open", { loop = true }), nil, "portal: nothing on Light")
	eq(W.FX.Fullscreen("coins"), nil, "coins: nothing on Light")
	W.db.fx = "full"
	ok(W.FX.Fullscreen("paid") ~= nil, "paid plays on Full")
end)

test("r46.m: the emblem says portal, the look is still named Orb", function()
	local w = T.newWorld()
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	local E = r.W.Emblem
	eq(E.LOOKS[1].desc, "a small portal just above the name, quicker")
	eq(E.LOOKS[2].desc, "Wuber's portal, bigger and higher up")
	eq(E.LOOKS[3].desc, "a small faint portal, slow")
	eq(E.LOOKS[2].name, "Orb", "the name stays")
	eq(E.Status().model, "custom portal")
end)
