-- Merged table-driven tests (test audit): each group below was several near-identical tests of tests/winners/drive_ready_test.lua, the same body with different
-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- from tests/winners/drive_ready_test.lua: line 425; line 800
test("breakit Drive.Ready: a partially heard crew is reported as partially heard (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Ready: a partially heard crew is reported as partially heard", 'the partially heard crew is reported' },
		{ "breakit Drive.Ready: the crew hearing line appears when someone is not heard", 'the partially heard crew warning is shown' },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	  local w = T.newWorld()
	  local saved = { Wuber = { chars = { [T.ANA:lower()] = { crew = { { name = T.BEA, role = 'lock', app = true }, { name = T.CAL, role = 'helper', app = true } }, captain = '', wizard = true } } } }
	  local ana = T.rider(w, T.ANA, { spot = 'Undercity', class = 'WARLOCK', saved = saved })
	  T.rider(w, T.BEA, { spot = 'Undercity', class = 'WARLOCK' })
	  w:addBot(T.CAL, { spot = 'Undercity' })
	  w:group({ T.ANA, T.BEA, T.CAL })
	  T.settle(w)
	  ana.W.UI.ShowDrive('settings')
	  w:advance(0.2)
	  ok(#ana:findText('Heard Wuber from 1 of 2', true, true) > 0, C[1])
	  T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_ready_test.lua: line 528; line 545
test("breakit Drive.Ready: a lone Warlock is not told about a main caster (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Ready: a lone Warlock is not told about a main caster", "no caster hand-off line for a solitary Warlock" },
		{ "breakit Drive.Ready: a Warlock driving alone is not given a caster hand-off instruction", "a solitary Warlock gets no caster hand-off row" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	  local w = T.newWorld()
	  local d = T.driver(w, T.TESTCHAR)
	  T.settle(w)
	  d:slash("/wuber drive status")
	  local n = 0
	  for _, line in ipairs(d.chatLines or {}) do
	    if line:find("Main caster:", 1, true) or line:find("summons instead.", 1, true)
	      or line:find("Nobody can summon now", 1, true) or line:find("Whoever clicks casts.", 1, true) then
	      n = n + 1
	    end
	  end
	  eq(n, 0, C[1])
	  T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)
