-- Merged table-driven tests (test audit): each group below was several near-identical tests of tests/winners/drive_chat_test.lua, the same body with different
-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- from tests/winners/drive_chat_test.lua: line 8; line 295; line 312
test("breakit Drive.Chat: a summoner without Wuber is marked in the summoner list (3 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Chat: a summoner without Wuber is marked in the summoner list", "the summoner is marked as having no Wuber" },
		{ "breakit Drive.Chat: a crew member without Wuber is marked in the summoner list", "the crew summoner is marked as having no Wuber" },
		{ "breakit Drive.Chat: a summoner missing Wuber is marked in the summoner list", "the summoner is marked as having no Wuber" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANA)
		T.settle(w)
		d.W.Drive.SummonerHasApp = function() return nil end
		d.W.Drive.CrewEntry = function() return { app = false, role = "lock" } end
		d.W.Drive.RaidWarlocks = function() return nil end
		d.W.Drive.ShortOf = function(k) return k end
		d.W.Drive.SetSummoners = function() end
		d.W.Drive.Summoners = function() return { "Bob" } end
		d:slash("/wuber drive summoners Bob")
		local line = d.chatLines[#d.chatLines] or ""
		ok(line:find("no Wuber", 1, true), C[1])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_chat_test.lua: line 25; line 329
test("breakit Drive.Chat: a raid summoner without Wuber is marked in the summoner list (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Chat: a raid summoner without Wuber is marked in the summoner list" },
		{ "breakit Drive.Chat: a raid warlock without Wuber is marked in the summoner list" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANA)
		T.settle(w)
		d.W.Drive.SummonerHasApp = function() return nil end
		d.W.Drive.CrewEntry = function() return nil end
		d.W.Drive.RaidWarlocks = function() return { { key = "Bob", app = false } } end
		d.W.Drive.ShortOf = function(k) return k end
		d.W.Drive.SetSummoners = function() end
		d.W.Drive.Summoners = function() return { "Bob" } end
		d:slash("/wuber drive summoners Bob")
		local line = d.chatLines[#d.chatLines] or ""
		ok(line:find("no Wuber", 1, true), "the raid summoner is marked as having no Wuber")
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_chat_test.lua: line 427; line 439; line 451
test("breakit Drive.Chat: the summoner list shows the known player's name (3 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Chat: the summoner list shows the known player's name" },
		{ "breakit Drive.Chat: a known summoner is named in the list" },
		{ "breakit Drive.Chat: the summoner list keeps a known player's name" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANA)
		T.settle(w)
		d.W.Drive.WhoIs = function(key) return "Zed Quill" end
		d:slash("/wuber drive summoners " .. d.player.name)
		local line = d.chatLines[#d.chatLines]
		ok(type(line) == "string" and line:find("Zed Quill", 1, true) ~= nil, "the summoner list shows the known player's full name")
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_chat_test.lua: line 769; line 783
test("breakit Drive.Chat: a payment notice stays unwritten in quiet mode (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Chat: a payment notice stays unwritten in quiet mode", 'quiet mode leaves the payment reminder unwritten' },
		{ "breakit Drive.Chat: a payment reminder is not sent by itself in quiet mode", 'quiet mode does not mark the payment as told' },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local d = T.driver(w, T.ANA)
	    T.settle(w)
	    d.W.Drive.opts = function() return { whisperMode = 'off' } end
	    local c = { name = 'Zed' }
	    d.W.db.drive.customers = { zed = c }
	    d.W.Drive.Pending = function() return { { kind = 'pay', c = c } } end
	    d.W.Drive.PumpChat()
	    eq(d.W.db.drive.customers.zed.reminded, nil, C[1])
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_chat_test.lua: line 797; line 1149
test("breakit Drive.Chat: the driver is warned when whispers keep missing (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Chat: the driver is warned when whispers keep missing", 'the driver is told about the fallback' },
		{ "breakit Drive.Chat: the driver sees a warning after whispers keep missing", 'the driver sees the fallback warning' },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local d = T.driver(w, T.ANA)
	    T.settle(w)
	    d.W.Drive.opts = function() return { whisperMode = nil } end
	    d.W.Drive.chat.failed = false
	    d.W.Drive.chat.confirms = 0
	    d.W.Drive.chat.misses = 0
	    d.W.Drive.WatchEcho({ { key = 'one' } })
	    d.W.Drive.WatchEcho({ { key = 'two' } })
	    d.W.Drive.WatchEcho({ { key = 'three' } })
	    w:advance(6.2)
	    local seen = false
	    for _, e in ipairs(d.W.eventLog or {}) do
	        if e.name == 'DRIVE_ALERT' then seen = true end
	    end
	    ok(seen or #d:findText('No whisper sent by the button', true, true) > 0, C[1])
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)
