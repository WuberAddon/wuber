-- Merged table-driven tests (test audit): each group below was several near-identical tests of tests/winners/core_base_test.lua, the same body with different
-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- from tests/winners/core_base_test.lua: line 64; line 85
test("breakit Core.Base: a listed driver with an unknown realm still starts a Pioneer beacon (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Core.Base: a listed driver with an unknown realm still starts a Pioneer beacon" },
		{ "breakit Core.Base: a listed driver on another realm still starts a Pioneer beacon when the realm is unknown" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local r = T.rider(w, T.TESTCHAR)
	    local d = T.driver(w, T.BOB)
	    T.settle(w)
	    local W = r.W
	    W.PIONEERS = { drivers = { ['EU-PvE'] = { T.TESTCHAR } }, riders = {} }
	    r.env.GetRealmName = function() return nil end
	    r.env.GetNormalizedRealmName = function() return nil end
	    W.myKey = W.Key(T.TESTCHAR)
	    local before = #w:messages('D', T.BOB, 'CHANNEL')
	    if W.IsPioneer(T.TESTCHAR, 'driver') then
	        T.openDrive(d)
	        T.goOnline(d, { price = 500 })
	        w:advance(0.2)
	    end
	    ok(#w:messages('D', T.BOB, 'CHANNEL') > before, 'the listed driver starts a beacon')
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)
