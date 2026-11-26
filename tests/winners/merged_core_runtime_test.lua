-- Merged table-driven tests (test audit): each group below was several near-identical tests of tests/winners/core_runtime_test.lua, the same body with different
-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- from tests/winners/core_runtime_test.lua: line 8; line 240
test("breakit Core.Runtime: a fare above the highest allowed amount is refused (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Core.Runtime: a fare above the highest allowed amount is refused", "the over-large fare is refused so the price stays put" },
		{ "breakit Core.Runtime: a fare of exactly one hundred thousand gold is refused", "a fare of 1,000,000,000 copper is refused and the price stays put" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w)
		T.settle(w)
		d:slash("/wuber price 1g")
		w:advance(1)
		eq(d.W.Char().price, 10000, "a normal price is set first")
		d:slash("/wuber price 100000g")
		w:advance(1)
		eq(d.W.Char().price, 10000, C[1])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/core_runtime_test.lua: line 52; line 87
test("breakit Core.Runtime: a refused long message is counted as long as the cut leaves it (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Core.Runtime: a refused long message is counted as long as the cut leaves it", "chat does not count one letter too many" },
		{ "breakit Core.Runtime: a refused long message never counts a half letter", "the whole letter at the cut is dropped, not half kept" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA)
		T.settle(w)
		local text = string.rep("a", 254) .. string.char(195, 169) .. " tail"
		d:slash("/wuber drive msg greet " .. text)
		ok(d:said("it is 254 letters long"), "chat counts the message at the length the cut leaves")
		eq(d:said("it is 255 letters long"), false, C[1])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)
