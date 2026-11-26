-- (job 2893) the probe's labels part, run in the fake game (needs the WuberProbe addon folder with P.LABELS in its Data.lua: WUBER_PROBE_DIR, or ../WuberProbe;
-- the addon is developer-only and is not in this repository, as in tests/rec/probe_test.lua part B, which defines T.probePlayAuto when it finds the folder).
-- Without the folder one test says so and passes: the learner itself is tested in tests/r55/probe_labels_test.lua.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ROOT = T.dir .. "/.."
local L = dofile(T.dir .. "/lib/probe_learn.lua")
local PI = assert(loadfile(ROOT .. "/tools/rec/probe-import.lua"))("--lib")

if not T.probePlayAuto then
		-- guard: a notice that the dev-only addon folder is absent; it asserts nothing
	test("labels run: skipped (the WuberProbe addon folder was not found; set WUBER_PROBE_DIR)", function() end)
	return
end

-- guard: infra (a test of tests/lib/probe_learn.lua, tools and the fake game; proved with failing-first --base-tools)
test("labels run: /probe run auto records Wuber's strings at 2-3 scales with each method under pcall, and the importer replays them", function()
	local w = T.newWorld()
	local c, run = T.probePlayAuto(w)
	local d = run.p.labels
	ok(d, "the labels probe ran: " .. tostring(run.ran and run.ran.labels and run.ran.labels.err))
	ok(not d.err, "no error: " .. tostring(d.err))
	ok(#d.scales >= 2 and #d.scales <= 3, "2-3 scales")
	ok(d.hash:match("^%x%x%x%x%x%x%x%x$"), "a hash of Wuber's words")
	for _, m in ipairs({ "GetStringWidth", "GetUnboundedStringWidth", "IsTruncated", "GetNumLines" }) do eq(type(d.caps[m]), "boolean", m .. " is recorded as there or not") end
	ok(#d.rows > 0, "rows")
	for i = 1, math.min(#d.rows, 50) do
		local r = d.rows[i]
		eq(#r.trunc, #d.scales, "one IsTruncated answer per scale") eq(#r.w, #d.scales, "one width per scale")
		eq(type(r.box), "number") eq(type(r.text), "string")
	end
	local fx = assert(PI.convert(run, "sim"))
	ok(fx.labels and #fx.labels.rows == #d.rows, "the importer keeps every row")
	local seen = {}
	local cut = L.cutFn(fx, seen)
	local r = d.rows[1]
	local verdict = cut(r.font, r.size, r.text, r.box, r.maxLines, r.wrap, d.scales[1])
	eq(verdict, r.trunc[1], "the replay gives the probe's own answer for a measured string")
	eq(cut(r.font, r.size, r.text .. " (changed)", r.box, r.maxLines, r.wrap, 1), nil, "a changed string is unmeasured")
	ok(L.coverageLine(seen):find("1 of 2 current strings unmeasured (words changed since the probe)", 1, true), L.coverageLine(seen))
	T.clean(w)
end)
