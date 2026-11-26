local T = ...
local test, eq, ok = T.test, T.eq, T.ok
-- r54 B follow-up (an outside review CA-1, 24 Nov): a founder with NO badge saved at all (nil, the state of a fresh character) is
-- summed up on Settings as "Founder (automatic)", like the empty pick; a non-founder with none saved stays "none".
local function summary(c, w)
	c.W.db.coach = true
	c.W.UI.Toggle(true)
	w:advance(3)
	c.W.UI.OpenSettings()
	w:advance(1)
	c.W.UI.RefreshNow()
	w:advance(0.5)
	return #c:findText("Founder (automatic)", nil, true) > 0, #c:findText("Badge: none", nil, true) > 0
end

test("r54 b2: a founder with no badge saved at all is summed up as Founder (automatic), not none", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	T.settle(w)
	d.W.Char().badge = nil
	local crown, none = summary(d, w)
	ok(crown, "the Driving summary names the crown")
	ok(not none, "and does not say none")
	T.clean(w)
end)

-- guard: a non-founder with no badge saved has no crown: the summary says none (unchanged path)
test("r54 b2 guard: a non-founder with no badge saved is summed up as none", function()
	local w = T.newWorld()
	local d = T.driver(w, "Mia Runner")
	T.settle(w)
	d.W.Char().badge = nil
	local crown, none = summary(d, w)
	ok(not crown, "no crown named")
	ok(none, "the summary says none")
	T.clean(w)
end)
