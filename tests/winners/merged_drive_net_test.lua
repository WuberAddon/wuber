-- Merged table-driven tests (test audit): each group below was several near-identical tests of tests/winners/drive_net_test.lua, the same body with different
-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- from tests/winners/drive_net_test.lua: line 8; line 126
test("breakit Drive.Net: the group leader's window announces the open ride to riders (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Net: the group leader's window announces the open ride to riders" },
		{ "breakit Drive.Net: the group leader's window announces the open ride to riders when no leader answer comes" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
		local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
		local b = w:addBot(T.BOB, { spot = "Ratchet" })
		T.settle(w)
		w:group({ T.ANITA, T.BOB })
		d.W.Drive.IsLeader = function() return nil end
		d.W.Drive.IsCaptain = function() return false end
		T.goOnline(d, { price = 100000 })
		w:advance(3)
		ok(#T.msgs(w, "D", T.ANITA) > 0, "the group leader's window sends the open beacon to riders")
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_net_test.lua: line 217; line 518
test("breakit Drive.Net: a driver grouped with a crew member (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Net: a driver grouped with a crew member tells riders the crew brings 2" },
		{ "breakit Drive.Net: a driver grouped with a crew member keeps the crew count on the beacon" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local a = T.driver(w, T.ANA, { spot = "Ratchet", saved = { Wuber = { chars = { ["ana smith"] = { crew = { { name = "Bea Jones", role = "lock", app = true } }, captain = "", wizard = true } } } } })
		w:addBot(T.BEA, { spot = "Ratchet", class = "WARLOCK" })
		T.settle(w)
		T.goOnline(a, { price = 100000 })
		w:group({ T.ANA, T.BEA })
		w:advance(6)
		local ds = T.msgs(w, "D", T.ANA)
		eq(T.fields(ds[#ds])[10], "2", "riders see the crew bringing 2 in the beacon")
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_net_test.lua: line 316; line 579; line 722
test("breakit Drive.Net: rider is told crew mate Bob's name in the driver's ride stage messages (3 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Net: rider is told crew mate Bob's name in the driver's ride stage messages", "the rider is told the crew mate Bob's name in the driver's stage messages" },
		{ "breakit Drive.Net: rider's ride stage messages list the crew mate Bob by name", "the rider's stage messages list the crew mate Bob by name" },
		{ "breakit Drive.Net: rider's ride stage messages name crew mate Bob, not the driver alone", "the rider's stage messages name the crew mate Bob" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
		local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
		T.settle(w)
		d.W.PriceOk = function() return true end
		d.W.Drive.Crew = function()
			return { { name = d.player.name, key = d.W.myKey, role = "lock", app = true, me = true, here = true, shards = 2 },
				{ name = T.BOB, key = "bob crew", role = "helper", app = false, here = true } }
		end
		T.goOnline(d, { price = 100000 })
		w:advance(2)
		w:inject(T.ANITA, "D~1~Ratchet~1413~500~500~5000~~open~1~0~~2.3.1", "CHANNEL")
		w:advance(0.2)
		r.W.RequestRide("anita lift")
		w:advance(6)
		local seen = false
		for _, e in ipairs(T.msgs(w, "S", T.ANITA)) do
			for _, f in ipairs(T.fields(e)) do
				if string.find(f, "Bob", 1, true) then seen = true end
			end
		end
		ok(seen, C[1])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_net_test.lua: line 388; line 409
test("breakit Drive.Net: a blocked rider is declined (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Net: a blocked rider is declined and never gets a driver's acceptance", "driver does not accept a blocked rider", "driver sends a decline to a blocked rider" },
		{ "breakit Drive.Net: a blocked rider is declined when the block list says so", "blocked rider gets no acceptance", "blocked rider gets a decline" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	    local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	    T.settle(w)
	    d.W.PriceOk = function() return true end
	    d.W.Drive.BlockEntry = function() return true end
	    T.goOnline(d, { price = 100000 })
	    w:advance(2)
	    w:inject(T.ANITA, "D~1~Ratchet~1413~500~500~5000~~open~1~0~~2.3.1", "CHANNEL")
	    w:advance(0.2)
	    local beforeA = #T.msgs(w, "A", T.ANITA)
	    local beforeN = #T.msgs(w, "N", T.ANITA)
	    r.W.RequestRide("anita lift")
	    w:advance(2)
	    eq(#T.msgs(w, "A", T.ANITA), beforeA, C[1])
	    ok(#T.msgs(w, "N", T.ANITA) > beforeN, C[2])
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_net_test.lua: line 504; line 680; line 793
test("breakit Drive.Net: a driver from another addon is named in the alert (3 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Net: a driver from another addon is named in the alert", "Other Rides", "Other Rides drives for you now", "Other Rides drives for you now", "the alert names the other addon" },
		{ "breakit Drive.Net: the player is told when another addon takes over driving", "Other Rides", "Other Rides drives for you now", "Other Rides drives for you now", "the player sees that Wuber's own driving is off" },
		{ "breakit Drive.Net: a rival named Ritual Rides is shown as Another addon", "Ritual Rides", "Another addon drives for you now", "Another addon drives for you now", "the alert says Another addon, not the rival's name" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
		T.settle(w)
		T.goOnline(d)
		w:advance(3)
		d.env.WuberAPI.SetDriver({ name = C[1], beacon = function() return nil end, onRequest = function() end })
		w:advance(2)
		local shown = d:said(C[2]) or #d:findText(C[3], false, true) > 0
		ok(shown, C[4])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)
