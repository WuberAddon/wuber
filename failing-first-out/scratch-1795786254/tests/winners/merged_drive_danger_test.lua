-- Merged table-driven tests (test audit): each group below was several near-identical tests of tests/winners/drive_danger_test.lua, the same body with different
-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- from tests/winners/drive_danger_test.lua: line 107; line 127
test("breakit Drive.Danger: the beacon keeps my own recent enemy sighting over a crewmate's older one (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Danger: the beacon keeps my own recent enemy sighting over a crewmate's older one", "the beacon keeps my five-second-old sighting: " },
		{ "breakit Drive.Danger: the beacon does not swap my fresh enemy sighting for a crewmate's older equal one", "the beacon keeps my fresh sighting: " },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
		T.settle(w)
		T.goOnline(d, { price = 5000 })
		w:advance(6)
		local DR = d.W.Drive
		DR.IsCrewKey = function(key) return key == "mate" end
		-- I saw an enemy player 5 s ago; a crewmate saw one 30 s ago
		DR.danger.seenAt = d.env.GetTime() - 5
		DR.DangerHeard("mate", "1:30:")
		w:advance(2)
		local all = T.msgs(w, "D", T.ANITA)
		local f = T.fields(all[#all])
		local n = f[20] and f[20]:match("^1:(%d+)$")
		ok(n and tonumber(n) < 20, C[1] .. tostring(f[20]))
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)
