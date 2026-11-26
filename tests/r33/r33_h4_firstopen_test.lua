local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"

-- a client with room for two panes, the first-open tips not yet done
local function firstOpen()
	local w = T.newWorld()
	local c = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
	c.wide = true
	T.settle(w)
	c.W.db.coach = false
	c.W.UI.Toggle(true)
	return w, c
end

test("r33 h4: HUNT-42: the first-open tips run on one narrow pane, then the window may open out", function()
	local w, c = firstOpen()
	local W = c.W
	w:advance(3)
	ok(W.UI.state.coaching, "the first-open tips are showing")
	eq(W.UI.Fold.IsUnfolded(), false, "tips showing: not opened out to two panes")
	eq(c.env.WuberFrame:GetWidth(), 360, "tips showing: one narrow pane")
	W.UI.EndCoach()
	w:advance(3)
	eq(W.UI.state.coaching, false, "the tips are done")
	eq(W.UI.Fold.IsUnfolded(), true, "after the tips the page opens out again where there is room")
	T.clean(w)
end)
