local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("r34 k: a crown over another player's plate sits in the background strata, under the Drive button's text", function()
	local w = T.newWorld({ realm = T.H.FOUNDER_REALM })
	w:addBot(T.ANITA, { spot = "Orgrimmar" })
	local r = T.rider(w)
	r.cvars.nameplateShowFriends = "1"
	T.settle(w)
	r:showPlate(T.ANITA)
	w:advance(2.5)
	local on = r:onPlate(T.ANITA)
	local crown
	for _, f in ipairs(on) do if f.plateKind == "crown" then crown = f end end
	ok(crown, "a crown over the founder's plate")
	eq(crown:GetFrameStrata(), "BACKGROUND", "plate badges stay behind the buttons")
	T.clean(w)
end)
