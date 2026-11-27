-- Merged table-driven tests (test audit): each group below was several near-identical tests of tests/winners/net_beacons_test.lua, the same body with different
-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- from tests/winners/net_beacons_test.lua: line 110; line 158
test("breakit Net.Beacons: an unchanged private beacon is not whispered (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Net.Beacons: an unchanged private beacon is not whispered again every few seconds", "the same beacon is not whispered again within a minute" },
		{ "breakit Net.Beacons: an unchanged private beacon is not whispered on every tick", "the same beacon is not whispered again on every tick" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local r = T.rider(w, T.TESTCHAR)
		local d = T.rider(w, T.ANITA, { spot = "Ratchet" })
		T.settle(w)
		local testchar = r.player.name
		d.W.SetEngine({ name = "Side Driver", beacon = function()
			return { only = { g = testchar }, dest = "Ratchet", price = 500, service = "Summon", state = "open", seats = 3 }
		end })
		w:advance(3)
		local function toTestchar()
			local n = 0
			for _, m in ipairs(w:messages("D", d.player.name, "WHISPER")) do
				if m.target == testchar then n = n + 1 end
			end
			return n
		end
		local before = toTestchar()
		ok(before >= 1, "the rider is whispered the driver's beacon")
		w:advance(12)
		eq(toTestchar() - before, 0, C[1])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)
