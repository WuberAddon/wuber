-- Merged table-driven tests (test audit): each group below was several near-identical tests of tests/winners/drive_commands_test.lua, the same body with different
-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- from tests/winners/drive_commands_test.lua: line 90; line 1833; line 2100
test("breakit Drive.Commands: /wuber drive show brings the big button back after hide (3 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Commands: /wuber drive show brings the big button back after hide", "the saved big button is shown again after show" },
		{ "breakit Drive.Commands: typing /wuber drive show saves the big button as shown again", "the saved big button is shown after show" },
		{ "breakit Drive.Commands: /wuber drive show turns the hidden big button back on", "the saved big button is shown after show" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA)
		T.settle(w)
		d:slash("/wuber drive hide")
		eq(d.env.WuberDB.drive.button.shown, false, "the saved big button is hidden after hide")
		d:slash("/wuber drive show")
		eq(d.env.WuberDB.drive.button.shown, true, C[1])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_commands_test.lua: line 605; line 1709
test("breakit Drive.Commands: stations command lists each station with its summoner and helper counts (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Commands: stations command lists each station with its summoner and helper counts", "chat lists a station with its summoner count: ", "chat lists the helper count: " },
		{ "breakit Drive.Commands: stations command shows the summoner and helper counts for a station", "chat shows the summoner count: ", "chat shows the helper count: " },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA)
		T.settle(w)
		d:slash("/wuber drive stations")
		local text = table.concat(d.chatLines or {}, "\n")
		ok(text:find("summoner(s), ", 1, true) ~= nil, C[1] .. text)
		ok(text:find("helper(s)", 1, true) ~= nil, C[2] .. text)
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_commands_test.lua: line 717; line 730; line 743
test("breakit Drive.Commands: help lists the price, destination and service commands (3 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Commands: help lists the price, destination and service commands", "price 1g", "price command shown", "service <name>", "service command shown", "on / off", "on and off shown" },
		{ "breakit Drive.Commands: help lists the rider and block commands", "unblock <name>", "unblock command shown", "msg <kind> <text>", "msg command shown", "keywords", "keywords command shown" },
		{ "breakit Drive.Commands: help lists the advert and mode commands", "adevery 15", "adevery command shown", "mode auto", "mode command shown", "bell <name>", "bell command shown" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA)
		T.settle(w)
		d:slash("/wuber drive help")
		local s = (table.concat(d.chatLines or {}, "\n"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
		ok(s:find(C[1], 1, true), C[2])
		ok(s:find(C[3], 1, true), C[4])
		ok(s:find(C[5], 1, true), C[6])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_commands_test.lua: line 1465; line 1477
test("breakit Drive.Commands: bell with no alert character prints a reply in chat (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Commands: bell with no alert character prints a reply in chat", "/wuber drive bell", "the bell command prints an answer in chat", "No alert character", "the answer says there is no alert character" },
		{ "breakit Drive.Commands: turning the alert character off tells the player it is off", "/wuber drive bell off", "the off command prints an answer in chat", "No alert character.", "chat confirms there is no alert character now" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA)
		T.settle(w)
		local before = #d.chatLines
		d:slash(C[1])
		ok(#d.chatLines > before, C[2])
		ok(d:said(C[3]), C[4])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_commands_test.lua: line 1630; line 1641
test("breakit Drive.Commands: typing raid prints the raid summons explanation (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Commands: typing raid prints the raid summons explanation", "/wuber drive raid", "Raid summons: raiders who say 123 in raid chat are summoned at no charge", "chat explains raid summons after typing raid" },
		{ "breakit Drive.Commands: typing sell confirms selling summons in chat", "/wuber drive sell", "Selling summons.", "chat confirms selling summons after typing sell" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA)
		T.settle(w)
		d.W.Drive.SetMode = function(m) return true end
		d:slash(C[1])
		ok(d:said(C[2]), C[3])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_commands_test.lua: line 1721; line 1969
test("breakit Drive.Commands: typing team opens the crew wizard on screen (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Commands: typing team opens the crew wizard on screen", "/wuber drive team", "the crew wizard shows text on screen" },
		{ "breakit Drive.Commands: a bare /wuber drive opens the Drive screen", "/wuber drive", "the Drive screen shows its texts after /wuber drive alone" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA)
		T.settle(w)
		local before = #d:visibleTexts()
		d:slash(C[1])
		ok(#d:visibleTexts() > before, C[2])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_commands_test.lua: line 1821; line 1857
test("breakit Drive.Commands: typing the check command prints the status lines (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Commands: typing the check command prints the status lines", "/wuber drive check", "Crew messages: ", "chat prints the crew messages line: ", "Whispers go by ", "chat prints how whispers go" },
		{ "breakit Drive.Commands: hiding the big button tells the driver how to bring it back", "/wuber drive hide", "The big button is hidden.", "chat says the big button is hidden: ", "/wuber drive show", "chat names the command that brings it back" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA)
		T.settle(w)
		d:slash(C[1])
		local text = table.concat(d.chatLines or {}, "\n")
		ok(text:find(C[2], 1, true) ~= nil, C[3] .. text)
		ok(text:find(C[4], 1, true) ~= nil, C[5])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)
