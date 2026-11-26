-- r49 C: every test the tournament sides added that passes on the addon base carries a "-- guard: <reason>" line
-- directly above its test( line (tools/failing-first.py judges those lines). Promise: tools/failing-first.py against
-- the tournament base f8bc501 reports passed_on_base=0. The proof run is that tool itself; this test only keeps the
-- 16 comment lines from being lost in a later edit.
local T = ...
local test, ok = T.test, T.ok

local LIST = {
	{ "r48/r48_e1_01_x_closes_settings_test.lua", "e1 merged 01: the X with Settings opened by the cog (not from Options) still hides Wuber" },
	{ "r48/r48_e1_01_x_closes_settings_test.lua", "e1 merged 01: the back arrow over Options still closes Settings back to the page, Wuber and the Options stay" },
	{ "v24/e3b11c_layout_allow_test.lua", "e3b-11c: hunt allow-list covers splash (F033) and finding radar corner (F037-F042, F049) without masking regressions" },
	{ "r48/r48_e3b12_determinism_test.lua", "e3b-12: Hunt.init does not leak H.textMetrics and Hunt.runPromise applies/restores it on every run" },
	{ "r48/e3b_h_earnings_title_test.lua", "e3b-h: guard: the Earnings page keeps its scroll top under the title when it sets the scroll area again" },
	{ "r48/e3b_h_earnings_title_test.lua", "e3b-h: guard: the other driver screens keep the small title in the header bar" },
	{ "r48/e3b_k4_close_test.lua", "e3b-k4: danger.closed_no_warning answers 'Close anyway?' and passes on the 2.4 code" },
	{ "v24/e3b_11b_promises_test.lua", "e3b_11b: F015-F018 FAB-02 Close anyway? repros pass on 2.4" },
	{ "v24/e3b_11b_promises_test.lua", "e3b_11b: F025 queue.row_menu repro passes on 2.4 and checks row tap invites + Options menu" },
	{ "v24/e3b_11b_promises_test.lua", "e3b_11b: F026 tips.first_open (drive_direct) repro passes on 2.4 and fails if HR-1 breaks" },
	{ "v24/e3b_11b_promises_test.lua", "e3b_11b: N1 nowayout.driver_can_remove_rider passes with kickAfter off and fails if Plan text breaks" },
	{ "tools/transcript_test.lua", "transcript: H.textMetrics isolation (step 1: set without restoring)" },
	{ "tools/transcript_test.lua", "transcript: H.textMetrics isolation (step 2: next test sees nil)" },
	{ "ui/rider/trips_test.lua", "ui.rider.trips: E3b-02 cue stays visible while content lies below without overlapping Wrapped card" },
}

local function lines(path)
	local f = assert(io.open(path, "rb"), "cannot open " .. path)
	local s = f:read("*a")
	f:close()
	local out = {}
	for l in (s .. "\n"):gmatch("([^\n]*)\n") do out[#out + 1] = (l:gsub("\r$", "")) end
	return out
end

-- guard: reads the test files, not addon code, so the addon base cannot fail it (the tool run against f8bc501 is the proof)
test("r49-c: each test that passed on its base carries a guard reason on the line above", function()
	local bad = {}
	for _, item in ipairs(LIST) do
		local ls, at = lines(T.dir .. "/" .. item[1]), nil
		for i, l in ipairs(ls) do
			if l:find("test" .. "(\"" .. item[2]:gsub("\\", "\\\\"), 1, true) then at = i break end
		end
		if not at then
			bad[#bad + 1] = "not found: " .. item[2]
		elseif not (ls[at - 1] or ""):match("^%s*%-%-%s*guard:%s*%S") then
			bad[#bad + 1] = "no guard line: " .. item[2]
		end
	end
	ok(#bad == 0, table.concat(bad, "; "))
end)
