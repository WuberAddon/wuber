-- HUNT-78: a bounty pinned before a /reload still gets its "Your bounty ended" toast when Net.Bounty
-- says a driver serves the place, even if Home was never opened after the reload.
local T = ...
local test, eq, ok, list = T.test, T.eq, T.ok, T.list

test("r33 k6: HUNT-78: after a reload without opening Home, a served bounty gives the toast", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	eq(r.W.Bounty.Pin("Gadgetzan", 7500), true, "pinned")
	w:advance(2)
	local r2 = w:reload(r)
	w:advance(3)
	ok(r2.W.Bounty.Mine(), "the bounty survived the reload")
	-- what Net.Bounty does when it ends the bounty: clear it, then say "served"
	r2.W.db.bounty = nil
	r2.W.Fire("BOUNTY", "mine", nil, "served", "Anita Lift")
	w:advance(0.5)
	local seen = list(r2:visibleTexts(), " | ")
	ok(seen:find("Your bounty ended", 1, true), "the toast: " .. seen)
	ok(seen:find("Gadgetzan", 1, true), "names the place: " .. seen)
	T.clean(w)
end)
