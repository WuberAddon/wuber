local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("r47 o2: the founder's own crown stays hidden in full first person (zoom 0)", function()
	local w = T.newWorld()
	local r = T.rider(w, "Anita Lift", { spot = "Orgrimmar" })
	T.settle(w)
	local P = r.W.Plates
	r.cameraZoom = 0.5
	P.EnsureSelf() w:advance(1)
	local h = P.SelfCrown()
	ok(h ~= nil, "the founder's own crown should exist")
	eq(h:GetAlpha(), 0, "control: near first person (zoom 0.5) the crown is hidden")
	r.cameraZoom = 0
	w:advance(1)
	ok(h:GetAlpha() == 0, "camera zoomed all the way in (GetCameraZoom() = 0, first person): the crown should stay hidden, but it pops back to alpha " .. tostring(h:GetAlpha()))
	T.clean(w)
end)