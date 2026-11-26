local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- HUNT-28, mended in the Settings round: the merged "Group size" row shows "Auto" on its slider (the second line
-- says what auto means); DR.MaxGroup is still what Wuber really keeps, and the option is left unchanged.

local function slider(d)
	d.W.UI.Toggle(true)
	d.W.UI.OpenSettings("driving")
	return d.W.UI.settings.controls["drive.maxGroup"]
end

test("r32 h2: Largest group on auto shows DR.MaxGroup with a crew of two helpers", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	w:advance(3)
	local DR = d.W.Drive
	d.W.Drive.opts().maxGroup = nil
	local ch = DR.char()
	ch.crew = { { name = "Fay Moss", key = "fay moss" }, { name = "Gus Pike", key = "gus pike" } }
	local sl = slider(d)
	ok(sl and sl.get, "the slider exists")
	eq(DR.MaxGroup(), 10, "Wuber keeps the group to 10")
	eq(sl.label:GetText(), "Auto", "the row reads Auto")
	eq(d.W.Drive.opts().maxGroup, nil, "reading it leaves the option unchanged")
	d.W.Drive.opts().maxGroup = 8
	eq(sl.get(), 8, "a set number is shown as set")
	T.clean(w)
end)
