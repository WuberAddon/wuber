-- Round r51 M: REV-dec-1, a group leader's settings never reach a Warlock who is not in the crew.
local T = ...
local test = T.test
local H, eq, ok = T.H, T.eq, T.ok
local function world(join)
	local w = T.newWorld()
	local ana = w:addClient(T.ANA, { spot = "Orgrimmar", class = "WARLOCK" })
	local bea = w:addClient(T.BEA, { spot = "Orgrimmar", class = "WARLOCK" })
	w:group({ T.ANA, T.BEA })
	T.settle(w)
	local A, B = ana.W.Drive, bea.W.Drive
	B.SetPrice(70000)
	B.SetDest("Undercity")
	B.SetOpt("maxGroup", 7)
	if join then
		ok(A.OfferCrew(T.BEA), "setup: the crew offer")
		w:advance(3)
		B.AnswerOffer(T.ANA, true)
		w:advance(3)
		ok(B.char().captain ~= "", "setup: Bea is in the crew")
	end
	A.SetPrice(20000)
	A.SetDest("Orgrimmar")
	A.SetOpt("maxGroup", 12)
	A.SendConfig()
	w:advance(5)
	return w, ana, bea
end
-- guard: the promise already holds on this base (the sender must be a crew key: Drive/Team.lua TrustKey); closes REV-dec-1
test("r51 M: a group leader and captain who is not Bea's crew cannot change her price, place or largest group", function()
	local w, ana, bea = world(false)
	eq(bea.W.Drive.char().captain, "", "Bea is in no crew")
	eq(bea.W.Char().price, 70000, "her own price")
	eq(bea.W.Char().dest, "Undercity", "her own typed place")
	eq(bea.W.Drive.opts().maxGroup, 7, "her own largest group")
	T.clean(w)
end)
-- guard: unchanged path (AU24-31, FAB-03 cover the leaving), a crew member still takes the captain's settings
test("r51 M: a member of the crew still takes the captain's price, place and largest group", function()
	local w, ana, bea = world(true)
	eq(bea.W.Char().price, 20000)
	eq(bea.W.Drive.Dest(), "Orgrimmar")
	eq(bea.W.Drive.opts().maxGroup, 12)
	T.clean(w)
end)
