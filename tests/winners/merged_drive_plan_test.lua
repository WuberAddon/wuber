-- Merged table-driven tests (test audit): each group below was several near-identical tests of tests/winners/drive_plan_test.lua, the same body with different
-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- from tests/winners/drive_plan_test.lua: line 236; line 258
test("breakit Drive.Plan: a shardless warlock sends no summon whisper (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Plan: a shardless warlock sends no summon whisper" },
		{ "breakit Drive.Plan: a warlock who needs shards sends no summon whisper" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	    T.settle(w)
	    local DR = d.W.Drive
	    DR.Mode = function() return "raid" end
	    DR.IsOpen = function() return true end
	    DR.IsPaused = function() return false end
	    DR.SimHooks = true
	    DR.Shards = function() return 0 end
	    DR.opts = function() return { needShards = true } end
	    local row = { key = "dan miller", name = "Dan Miller", state = "waiting", order = 1 }
	    DR.RaidAssign = function() return { { key = d.W.myKey, row = row, index = 1 } }, { row } end
	    T.openDrive(d)
	    w:advance(0.1)
	    local p = DR.Plan()
	    d:clickText(p.title)
	    eq(#w:whispersTo("Dan Miller"), 0, "the button does not whisper or cast without shards")
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)
