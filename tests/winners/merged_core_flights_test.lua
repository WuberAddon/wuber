-- Merged table-driven tests (test audit): each group below was several near-identical tests of tests/winners/core_flights_test.lua, the same body with different
-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- from tests/winners/core_flights_test.lua: line 225; line 238
test("breakit Core.Flights: a first flight time is saved for a new route (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Core.Flights: a first flight time is saved for a new route", "ratchet", "the first measured time is accepted", "H|orgrimmar|ratchet", "the new route appears in the saved flight list" },
		{ "breakit Core.Flights: a newly recorded flight time is kept in the saved flight list", "undercity", "the measured time is accepted", "H|orgrimmar|undercity", "the recorded route stays in the saved flight list" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local r = T.rider(w, T.TESTCHAR)
	    T.settle(w)
	    local t = r.W.FLY.SetOwnTime("H", "orgrimmar", C[1], 95)
	    eq(t, 95, C[2])
	    local e = r.env.WuberDB.flights[C[3]]
	    ok(type(e) == "table", C[4])
	    eq(e.t, 95, "the saved time is 95 seconds")
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)
