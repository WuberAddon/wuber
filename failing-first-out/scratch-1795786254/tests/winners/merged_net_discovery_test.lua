-- Merged table-driven tests (test audit): each group below was several near-identical tests of tests/winners/net_discovery_test.lua, the same body with different
-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- from tests/winners/net_discovery_test.lua: line 8; line 24; line 40
test("breakit Net.Discovery: a saved favourite is not whispered to as a brand-new gossiped name (3 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Net.Discovery: a saved favourite is not whispered to as a brand-new gossiped name", "no Q whisper to a driver already saved as a favourite" },
		{ "breakit Net.Discovery: a driver already on the rider's list is not queried as a new name", "a listed driver gets no confirmation Q" },
		{ "breakit Net.Discovery: a known driver is not treated as a freshly heard name", "a known driver is not whispered as freshly heard" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local r = T.rider(w, T.TESTCHAR)
	    T.settle(w)
	    r.W.db.favs = { ["bob stone"] = true }
	    w:inject("Evil Guy", "K~1~Bob Stone", "WHISPER", r)
	    w:advance(10)
	    local n = 0
	    for _, e in ipairs(w:messages("Q", T.TESTCHAR, "WHISPER")) do
	        if e.target and string.lower(e.target) == "bob stone" then n = n + 1 end
	    end
	    eq(n, 0, C[1])
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)
