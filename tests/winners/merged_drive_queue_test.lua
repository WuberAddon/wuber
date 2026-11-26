-- Merged table-driven tests (test audit): each group below was several near-identical tests of tests/winners/drive_queue_test.lua, the same body with different
-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- from tests/winners/drive_queue_test.lua: line 264; line 291; line 318; line 345
test("breakit Drive.Queue: the crew is told an expired rider left the list (4 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Queue: the crew is told an expired rider left the list", "expired", "the crew is told to drop the expired rider" },
		{ "breakit Drive.Queue: the crew is told a declining rider left the list", "declined", "the crew is told to drop the rider who declined" },
		{ "breakit Drive.Queue: the crew is told a missing rider left the list", "missing", "the crew is told to drop the missing rider" },
		{ "breakit Drive.Queue: the crew is told a rider who left the group left the list", "left", "the crew is told to drop the rider who left" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local a = T.driver(w, T.ANITA, { spot = "Undercity" })
		w:addBot(T.BOB, { spot = "Ratchet", acceptsInvites = true })
		T.settle(w)
		ok(a.W.Drive.SetOpen(true), "driver opens")
		w:advance(1)
		w:botWhisper(T.BOB, a, "summon pls")
		w:advance(4)
		local DR = a.W.Drive
		local c = DR.customers[a.W.Key(T.BOB)]
		ok(c ~= nil, "rider is on the list")
		local function drops()
			local n = 0
			for _, e in ipairs(w.addonLog) do
				if type(e.text) == "string" and e.text:sub(1, 7) == "DROP~1~" and e.text:find(T.BOB, 1, true) then n = n + 1 end
			end
			return n
		end
		DR.SetState(c, "queued")
		local before = drops()
		DR.Remove(c, C[1])
		eq(drops(), before + 1, C[2])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_queue_test.lua: line 484; line 503
test("breakit Drive.Queue: a /say request on the street only becomes a lead, never an invite (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Queue: a /say request on the street only becomes a lead, never an invite", "CHAT_MSG_SAY", "a /say request on the street was not turned into an invited rider" },
		{ "breakit Drive.Queue: a /yell request on the street only becomes a lead, never an invite", "CHAT_MSG_YELL", "a /yell request on the street was not turned into an invited rider" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	    local dan = w:addBot("Dan Miller", { spot = "Orgrimmar", acceptsInvites = true })
	    T.settle(w)
	    T.goOnline(a, { price = 5000 })
	    local o = a.W.Drive.opts()
	    o.watchPublic = true
	    o.autoPublic = true
	    o.autoInvite = true
	    a:fire(C[1], "LF summon to Undercity", "Dan Miller")
	    w:advance(0.5)
	    a.W.Drive.PumpInvites()
	    w:advance(2)
	    eq(dan.group, nil, C[2])
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_queue_test.lua: line 771; line 791
test("breakit Drive.Queue: a rider waiting for the summon who pays by trade is still waiting for the summon (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Queue: a rider waiting for the summon who pays by trade is still waiting for the summon", 'waiting', 'waiting' },
		{ "breakit Drive.Queue: a rider who just joined and pays by trade is still waiting for the summon", 'joined', 'joined' },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local a = T.driver(w, T.ANITA, { spot = 'Undercity' })
	    w:addBot('Dan Miller', { spot = 'Orgrimmar', acceptsInvites = true })
	    T.settle(w)
	    T.goOnline(a, { price = 5000 })
	    w:botWhisper('Dan Miller', a, 'summon')
	    w:advance(4)
	    local c = a.W.Drive.Find('Dan Miller')
	    c.price = 5000
	    c.wuberVer = '2.3.0'
	    a.W.Drive.SetState(c, C[1])
	    local before = a.W.Drive.session.rides
	    a.W.Drive.Do('PAID', 'Dan Miller', 5000)
	    eq(c.state, C[2], 'the rider still waits for the summon after paying by trade')
	    eq(a.W.Drive.session.rides, before, 'paying by trade before arrival does not count a finished ride')
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_queue_test.lua: line 1082; line 1101
test("breakit Drive.Queue: a lead who gives a clear request is invited (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Queue: a lead who gives a clear request is invited", 'lead', 'the former lead is now invited' },
		{ "breakit Drive.Queue: a finished rider who asks again is invited", 'done', 'the finished rider is invited for the new request' },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	  local function saved(me, captain, crew)
	    return { Wuber = { chars = { [string.lower(me)] = { crew = crew, captain = captain, wizard = true } } } }
	  end
	  local w = T.newWorld()
	  local a = T.driver(w, T.ANA, { spot = 'Orgrimmar', saved = saved(T.ANA, '', { { name = T.BEA, role = 'lock', app = true } }) })
	  local b = T.driver(w, T.BEA, { spot = 'Orgrimmar', saved = saved(T.BEA, T.ANA, { { name = T.ANA, role = 'lock', app = true } }) })
	  w:group({ T.ANA, T.BEA })
	  T.settle(w)
	  ok(a.W.Drive.SetOpen(true), 'leader opens')
	  w:advance(3)
	  local c = b.W.Drive.Create('Dan Miller', C[1], 'relay')
	  b.W.Drive.Apply('ASK', string.lower(T.ANA), 'Dan Miller', 'invited', 'Orgrimmar', 5000)
	  w:advance(1)
	  eq(b.W.Drive.Find('Dan Miller').state, 'invited', C[2])
	  T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_queue_test.lua: line 1160; line 1176; line 1192
test("breakit Drive.Queue: a driver casting Teleport holds riders instead of inviting them (3 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Queue: a driver casting Teleport holds riders instead of inviting them", "Teleport: Undercity", "the rider waits while the driver teleports" },
		{ "breakit Drive.Queue: a driver casting Hearthstone holds riders instead of inviting them", "Hearthstone", "the rider waits while the driver casts Hearthstone" },
		{ "breakit Drive.Queue: a driver casting Astral Recall holds riders instead of inviting them", "Astral Recall", "the rider waits while the driver casts Astral Recall" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	  local w = T.newWorld()
	  local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	  w:addBot(T.BOB, { spot = "Ratchet", acceptsInvites = true })
	  T.settle(w)
	  ok(a.W.Drive.SetOpen(true), "driver opens")
	  w:advance(1)
	  a.env.UnitCastingInfo = function() return C[1] end
	  w:botWhisper(T.BOB, a, "summon pls")
	  w:advance(5)
	  local row = a.W.Drive.customers[a.W.Key(T.BOB)]
	  eq(row and row.state, "queued", C[2])
	  T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)
