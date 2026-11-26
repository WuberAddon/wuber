-- Runs the three "no way out" promises (tests/promises/nowayout.lua) and the sequence chains (tools/hunt/seq_hunt.lua)
-- once each, about 8 s. A tool, not part of the suite (blind-spot check 4, job 206). From the repo root:
--   lua5.1 tools/hunt/nowayout_check.lua        (exit 1 on a failure; a "pending" chain is listed, never a failure)
local SRC = (debug.getinfo(1, "S").source or ""):gsub("^@", ""):gsub("\\", "/")
local ROOT = (SRC:match("^(.*)/[^/]*$") or ".") .. "/../.."
local SeqHunt = dofile(ROOT .. "/tools/hunt/seq_hunt.lua")
local Hunt = SeqHunt.Hunt
Hunt.init({})

local failed = 0
local cases = {
	{ id = "nowayout.driver_can_remove_rider", sit = { role = "warlock", ride = "arrived" } },
	{ id = "nowayout.rider_not_stuck_after_cancelled_trade", sit = { role = "rider", ride = "arrived" } },
	{ id = "nowayout.rider_never_stuck_waiting", sit = { role = "rider", ride = "summoning" } },
}
for _, tc in ipairs(cases) do
	local res = Hunt.runPromise(tc.id, tc.sit, 1, { always = false })
	local good = res.status == "pass"
	if not good then failed = failed + 1 end
	print(("%s  [promise] %s%s"):format(good and "PASS" or "FAIL", tc.id, good and "" or ("\n      " .. tostring(res.seen or res.detail or res.status))))
end
local res = SeqHunt.runAll({ seed = 1, n = 4, steps = 5 })
for _, list in ipairs({ res.chains, res.random }) do
	for _, r in ipairs(list) do
		local mark = r.status == "pass" and "PASS" or (r.status == "pending" and "PEND" or "FAIL")
		if mark == "FAIL" then failed = failed + 1 end
		print(("%s  [seq] %s%s"):format(mark, r.id, r.status == "pass" and "" or ("\n      " .. tostring(r.failure or r.detail))))
	end
end
print(("nowayout check: %d failed"):format(failed))
os.exit(failed > 0 and 1 or 0)
