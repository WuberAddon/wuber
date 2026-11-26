-- Merged table-driven tests (test audit): each group below was several near-identical tests of tests/winners/drive_raid_test.lua, the same body with different
-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- from tests/winners/drive_raid_test.lua: line 436; line 456
test("breakit Drive.Raid: a rider sees their real place in the summon queue (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Raid: a rider sees their real place in the summon queue", "Other", "Other", "queued", "2nd in line", "the rider is second in line", "You're next", "the rider is not next" },
		{ "breakit Drive.Raid: a summoning row does not push a queued rider back", "Active", "Active", "summoning", "You're next", "the rider is next: a summoning row is not queued", "2nd in line", "the rider is not second" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local r = T.rider(w, T.TESTCHAR)
	    T.settle(w)
	    local DR = r.W.Drive
	    local myKey = r.W.Key(r.player.name)
	    DR.apps = { [r.W.Key("Runner")] = { name = "Runner", mode = "R" } }
	    DR.units = { [r.W.Key("Runner")] = true }
	    DR.raidRows = {
	        [myKey] = { name = r.player.name, state = "queued", order = 5 },
	        [r.W.Key(C[1])] = { name = C[2], state = C[3], order = 1 },
	    }
	    r:slash("/wuber")
	    w:advance(1)
	    ok(#r:findText(C[4]) > 0, C[5])
	    ok(#r:findText(C[6]) == 0, C[7])
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_raid_test.lua: line 566; line 710
test("breakit Drive.Raid: losing lead shows the raid summons paused notice (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Raid: losing lead shows the raid summons paused notice" },
		{ "breakit Drive.Raid: a runner who lost lead is told raid summons paused" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local d = T.driver(w, T.TESTCHAR)
	    T.settle(w)
	    w:addBot(T.ANITA, { spot = "Ratchet" })
	    w:group({ T.ANITA, T.TESTCHAR })
	    w:advance(1)
	    local DR = d.W.Drive
	    local ch = d.W.Char()
	    ch.mode = "raid"
	    ch.raidRun = true
	    ch.paused = false
	    DR.raidLostTold = nil
	    local out = {}
	    local real = DR.Alert
	    DR.Alert = function(text, kind, ...)
	        out[#out + 1] = tostring(text)
	        return real(text, kind, ...)
	    end
	    w:advance(2)
	    local hit = false
	    for _, t in ipairs(out) do
	        if t:find("Raid summons paused", 1, true) then hit = true end
	    end
	    ok(hit, "the runner sees the paused notice: " .. table.concat(out, " | "))
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)
