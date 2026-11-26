-- r52 group D: a shift's Fair split is written to the cut log before a new shift starts, however long the gap.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function world()
	local W, w = T.contract("Drive.Cut", "tests/drive/cut_test.lua", {})
	W.VERSION = "2.3.0"
	W.Drive.Selling = function() return true end
	return W, w
end

test("r52 D #10: a shift left open over a 2-minute gap is logged before the new one starts (in memory)", function()
	local W, w = world()
	local DR = W.Drive
	local l = W.db.drive.log
	l.shift = { start = 100, seen = 100 }
	DR.ShiftCheck = DR.ShiftCheck
	DR.CutTick()
	W.Fire("DRIVE_PAID", "Eve", 30000)
	eq(DR.cut.gold, 30000, "tally counted")
	l.shift.seen = 100 -- (no sign of life for a long time)
	l.shift.start = 5000 l.shift.seen = 5000 -- Drive.Log's gap branch: new start, no stop
	DR.CutTick()
	local log = DR.CutLog()
	eq(#log, 1, "the old shift's split was logged")
	eq(log[1].gold, 30000)
	eq(DR.cut.gold, 0, "the new shift starts from zero")
	T.clean(w)
end)

test("r52 D #10: after a reload the saved tally of the overwritten shift is logged", function()
	local W, w = world()
	local DR = W.Drive
	local l = W.db.drive.log
	l.shift = { start = 5000, seen = 5000, cut = { since = 100, gold = 70000, casts = { ana = 2 }, clicks = { bea = 3 }, names = { ana = "Ana", bea = "Bea" } } }
	DR.CutTick()
	local log = DR.CutLog()
	eq(#log, 1, "one cut line")
	eq(log[1].gold, 70000)
	eq(log[1].casts.Ana, 2)
	eq(log[1].clicks.Bea, 3)
	DR.CutTick()
	eq(#DR.CutLog(), 1, "logged once")
	T.clean(w)
end)

-- guard: the same shift again (start unchanged) is never logged
test("r52 D #10: guard: a running shift is not logged by a repeat tick", function()
	local W, w = world()
	local DR = W.Drive
	local l = W.db.drive.log
	l.shift = { start = 100, seen = 100 }
	DR.CutTick()
	W.Fire("DRIVE_PAID", "Eve", 30000)
	DR.CutTick() DR.CutTick()
	eq(#DR.CutLog(), 0)
	T.clean(w)
end)
