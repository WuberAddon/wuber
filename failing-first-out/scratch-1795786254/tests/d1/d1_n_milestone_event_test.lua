-- Design round 1, group N: the MILESTONE event still reaches the milestone card (the sentence-case sweep
-- had turned the event's name into "Milestone", so no card ever showed).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("d1 n: a MILESTONE event opens the milestone card", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	w:advance(15)
	local seen
	local was = c.W.UI.Celebrate
	c.W.UI.Celebrate = function(main, ids) seen = main; return was(main, ids) end
	c.W.Fire("MILESTONE", "first", { "first" })
	w:advance(1)
	eq(seen, "first", "UI.Celebrate was called by the event")
end)
