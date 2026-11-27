local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- The real client gives Escape to a focused edit box first; only without focus does it close special windows.
local function escape(box)
	local fn = box:GetScript("OnEscapePressed")
	if fn then fn(box) end
end

test("r33 j4 HUNT-40: one Escape in the bug report's boxes closes the window", function()
	local w = H.NewWorld({})
	local a = w:addClient("Ana Smith", { spot = "Orgrimmar", class = "WARLOCK" })
	w:advance(5)
	local Bug = a.W.UI.Bug
	a:slash("/wuber bug")
	w:advance(0.5)
	ok(Bug.Shown(), "control: /wuber bug opens the window")
	escape(Bug.frame.copy.edit)
	w:advance(0.3)
	ok(not Bug.Shown(), "Escape in the report box (focused on open) should close the window at once")
	a:slash("/wuber bug")
	w:advance(0.5)
	ok(Bug.Shown(), "control: opens again")
	escape(Bug.frame.note.edit)
	w:advance(0.3)
	ok(not Bug.Shown(), "Escape in the What happened box closes the window too")
	T.clean(w)
end)
