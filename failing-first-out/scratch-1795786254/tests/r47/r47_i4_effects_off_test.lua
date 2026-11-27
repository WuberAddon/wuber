local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("r47 i4: turning effects Off stops a Play effect (milestone) already running, not only full-screen ones", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local FX = r.W.FX
	local h = FX.Fullscreen("arrival")
	ok(h and h:IsPlaying(), "control: the screen effect should be playing")
	local parent = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	parent:SetSize(100, 100) parent:SetPoint("CENTER")
	local m = FX.Play("milestone", parent, { size = 72 })
	ok(m and m:IsPlaying(), "control: the milestone effect should be playing")
	w:advance(0.3)
	r.W.db.fx = "off"
	FX.Refresh()
	ok(not h:IsPlaying(), "control: the full-screen effect should stop when Effects is Off")
	ok(not m:IsPlaying(), "the milestone effect should stop when Effects is Off")
	eq(FX.Stats().playing, 0, "nothing left playing")
	T.clean(w)
end)
