-- Merged table-driven tests (test audit): each group below was several near-identical tests of tests/winners/net_update_test.lua, the same body with different
-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- from tests/winners/net_update_test.lua: line 21; line 34
test("breakit Net.Update: changing an unrelated setting does not show an update toast (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Net.Update: changing an unrelated setting does not show an update toast", "breakitProbe" },
		{ "breakit Net.Update: an unrelated setting does not bring up a saved update notice", "breakitProbeTwo" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local r = T.rider(w, T.TESTCHAR, { version = "2.3.0" })
		T.settle(w)
		r.W.db.newer = { ver = "2.3.1", at = T.H.EPOCH }
		local before = #r:visibleTexts()
		r.W.Fire("SETTINGS", C[1])
		w:advance(6)
		eq(#r:visibleTexts(), before, "no update toast appears for an unrelated setting")
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)
