-- Merged table-driven tests (test audit): each group below was several near-identical tests of tests/winners/drive_log_test.lua, the same body with different
-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- from tests/winners/drive_log_test.lua: line 181; line 414; line 427
test("breakit Drive.Log: a paid ride is counted only once (3 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Log: a paid ride is counted only once", 'lifetime rides after two paid notices' },
		{ "breakit Drive.Log: a ride reported paid twice still counts as one ride", 'lifetime rides after two paid notices' },
		{ "breakit Drive.Log: repeated paid notices do not inflate the ride count", 'lifetime rides after repeated paid notices' },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local r = T.rider(w, T.TESTCHAR)
	    T.settle(w)
	    r.W.db.drive.stats = { rides = 0, copper = 0, tips = 0 }
	    local row = { state = 'paid', name = r.player.name }
	    r.W.Fire('DRIVE_STATE', row)
	    r.W.Fire('DRIVE_STATE', row)
	    eq(r.W.db.drive.stats.rides, 1, C[1])
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_log_test.lua: line 234; line 246; line 258; line 270
test("breakit Drive.Log: earnings report names the destination the driver set (4 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Log: earnings report names the destination the driver set", "Ratchet", "Orgrimmar", "the earnings report should name the destination the driver set" },
		{ "breakit Drive.Log: earnings report falls back to the place you are standing", "", "Ratchet", "the earnings report should name the place you are standing when no destination is set" },
		{ "breakit Drive.Log: earnings report names the place you are standing", "", "Ratchet", "the earnings report should name the place you are standing" },
		{ "breakit Drive.Log: earnings report still names the place you are standing", "", "Ratchet", "the earnings report should name the place you are standing" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local r = T.rider(w, T.TESTCHAR)
	    T.settle(w)
	    r.W.Drive.Dest = function() return C[1] end
	    r.W.DestHere = function() return { name = C[2] } end
	    r.W.Drive.LogReport()
	    ok(r:said("Ratchet"), C[3])
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_log_test.lua: line 731; line 759; line 787
test("breakit Drive.Log: the shift card names the earlier of two equally good hours as the best (3 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Log: the shift card names the earlier of two equally good hours as the best", "02", ",500,Dan Miller,Ratchet,t,500", ",500,Eve Long,Ratchet,t,500", "the tied best hour shown is the earlier one, 01:00" },
		{ "breakit Drive.Log: a loser hour never replaces the best hour on the shift card", "00", ",5000,Dan Miller,Ratchet,t,5000", ",1000,Eve Long,Ratchet,t,1000", "the best hour stays 01:00, the one that earned the most" },
		{ "breakit Drive.Log: the earlier hour wins a tie for best hour on the shift card", "02", ",700,Dan Miller,Ratchet,t,700", ",700,Eve Long,Ratchet,t,700", "the tied best hour shown is the earlier one, 01:00" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA)
		T.settle(w)
		local W = d.W
		T.openDrive(d)
		local realDate = d.env.date
		local base = 1700000000
		d.env.date = function(fmt, at)
			if fmt == "%H" then
				at = tonumber(at) or base
				if at >= base + 7200 then return C[1] end
				if at >= base + 3600 then return "01" end
				return "00"
			end
			return realDate(fmt, at)
		end
		local l = W.Drive.Log()
		l.shift = { start = base, stop = base + 7200 }
		l.rides = { tostring(base + 3600) .. C[2], tostring(base + 7200) .. C[3] }
		W.Driver.lastShift = W.Drive.ShiftSummary()
		ok(W.Driver.ShowSheet("shift"), "the shift card opens")
		w:advance(1)
		eq(#d:findText("01:00"), 1, C[4])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_log_test.lua: line 1275; line 1325
test("breakit Drive.Log: the saved log keeps only a limited number of hours (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Log: the saved log keeps only a limited number of hours", 'old hourly entries are pruned: ' },
		{ "breakit Drive.Log: the saved log drops hours beyond the limit", 'hours beyond the limit are dropped: ' },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local r = T.rider(w, T.TESTCHAR)
	    T.settle(w)
	    r.env.time = function() return 1700000000 end
	    local db = r.W.db
	    db.drive = db.drive or {}
	    db.drive.log = db.drive.log or {}
	    local l = db.drive.log
	    l.open = {}
	    for i = 0, 99999 do l.open[string.format('9999%06d', i)] = 1 end
	    r.W.Drive.LogPrune()
	    local n = 0
	    for k in pairs(l.open) do n = n + 1 end
	    ok(n < 100000, C[1] .. tostring(n))
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_log_test.lua: line 1344; line 1360
test("breakit Drive.Log: logging in cleans unusable saved log entries (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Log: logging in cleans unusable saved log entries", "old", "old", "an unusable open-time entry is gone after login" },
		{ "breakit Drive.Log: old hours are removed when a driver logs in", "2000010112", "2000010112", "an hour older than the kept days is gone after login" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local r = T.rider(w, T.TESTCHAR)
	    T.settle(w)
	    local db = r.env.WuberDB
	    db.drive = db.drive or {}
	    db.drive.log = db.drive.log or {}
	    local lg = db.drive.log
	    lg.open = lg.open or {}
	    lg.open[C[1]] = 5
	    r:fire("PLAYER_LOGIN")
	    eq(lg.open[C[2]], nil, C[3])
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_log_test.lua: line 1390; line 1404; line 1418
test("breakit Drive.Log: a buyer seen in chat creates and saves the earnings log (3 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Log: a buyer seen in chat creates and saves the earnings log" },
		{ "breakit Drive.Log: a buyer seen in chat keeps the earnings log in saved variables" },
		{ "breakit Drive.Log: the saved earnings log is marked as version 1" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local r = T.rider(w, T.TESTCHAR)
	    T.settle(w)
	    r.env.WuberDB.drive = r.env.WuberDB.drive or {}
	    r.env.WuberDB.drive.log = nil
	    r.W.Drive.LogAsk("match", "Wuber", "m", "Ratchet", "lf summon")
	    local l = r.env.WuberDB.drive and r.env.WuberDB.drive.log
	    ok(l ~= nil, "the earnings log is saved")
	    eq(l and l.v, 1, "the earnings log is versioned")
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_log_test.lua: line 1432; line 1445
test("breakit Drive.Log: the log report shows the driver's chosen destination (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Log: the log report shows the driver's chosen destination", "Ratchet", "for Ratchet", "the report names Ratchet" },
		{ "breakit Drive.Log: the log report uses the driver's destination not a fallback", "Thunder Bluff", "for Thunder Bluff", "the report names Thunder Bluff" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local r = T.rider(w, T.TESTCHAR)
	    T.settle(w)
	    r.W.Drive.Dest = function() return C[1] end
	    r.W.DestHere = nil
	    r:slash("/wuber drive log")
	    w:advance(0.1)
	    ok(r:said(C[2]), C[3])
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_log_test.lua: line 1458; line 1484
test("breakit Drive.Log: the log report names the place the game knows (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Log: the log report names the place the game knows" },
		{ "breakit Drive.Log: the log report shows a returned place string" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local r = T.rider(w, T.TESTCHAR)
	    T.settle(w)
	    r.W.Drive.Dest = nil
	    r.W.DestHere = function() return "Ratchet" end
	    r:slash("/wuber drive log")
	    w:advance(0.1)
	    ok(r:said("for Ratchet"), "the report names Ratchet")
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_log_test.lua: line 1553; line 1569
test("breakit Drive.Log: driver stats are saved when drive data is rebuilt (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Log: driver stats are saved when drive data is rebuilt", 'the drive data was rebuilt by InitDB' },
		{ "breakit Drive.Log: driver stats are saved after drive data initializes", 'the drive data was initialized' },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local r = T.rider(w, T.TESTCHAR)
		T.settle(w)
		r.W.db.drive = nil
		r.W.Drive.InitDB = function()
			r.W.db.drive = { v = 1, initCalled = true }
		end
		r.W.Drive.Stats()
		local d = r.env.WuberDB.drive
		ok(type(d) == 'table' and d.initCalled == true, C[1])
		ok(type(d) == 'table' and type(d.stats) == 'table' and d.stats.rides == 0, 'the stats were saved')
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)
