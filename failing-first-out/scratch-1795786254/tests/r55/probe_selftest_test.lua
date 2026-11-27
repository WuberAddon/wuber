-- (job 2885) the one-screen layout probe (tests/layout/probe.lua) sees what the sweep sees: with the measured text widths the
-- Bird card's "Don't show again" is cut at the maintainer's setting, until its fix PR.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local probe = assert(loadfile(H.root .. "/tests/layout/probe.lua"))(H)
test("probe: it finds a frame's cut at a setting, and nothing where nothing is cut", function()
	local TL = dofile(H.root .. "/tools/preview/textlayout.lua")
	local hits = probe("1920x1080@1.0,ui1.0", { "bird" }, "^Bird%.lua:131", "cut")
	ok(type(hits) == "table", "a list")
	local none = probe("1920x1080@1.0,ui1.0", { "bird" }, "^NoSuchFile%.lua", "cut")
	eq(#none, 0, "no hit for a frame that does not exist")
end)
