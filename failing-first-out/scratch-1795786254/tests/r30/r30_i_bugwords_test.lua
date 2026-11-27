local T = ...
local test, ok = T.test, T.ok

test("r30 i: the bug report never shows the old summoning addon's word in its events or errors", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	local Wr = r.W
	Wr.Fire("RITUAL", "x", {})
	Wr.Fire("DRIVE_RITUAL", "x", "t", {})
	Wr.Error("DRIVE_RITUAL", "boom")
	local text = Wr.UI.Bug.Report("it broke")
	ok(not text:lower():find("ritual", 1, true), "no banned word in the report: " .. text)
	ok(text:find("SUMMON PORTAL", 1, true), "the plain event name is shown")
	ok(text:find("DRIVE_SUMMON_PORTAL", 1, true), "the longer name too")
	Wr.lastError = nil
	T.clean(w)
end)
