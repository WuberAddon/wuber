-- Merged table-driven tests (test audit): each group below was several near-identical tests of tests/winners/drive_kitchen_test.lua, the same body with different
-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- from tests/winners/drive_kitchen_test.lua: line 60; line 138
test("breakit Drive.Kitchen: casting update names crew member (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Kitchen: casting update names crew member Cal who is not in the group", "c", "casting update sent", "casting update names Cal" },
		{ "breakit Drive.Kitchen: casting update names crew member Cal, not a blank caster", "h", "update sent", "update names Cal, not blank" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
		local w = T.H.NewWorld({})
		local crew = { { name = T.BEA, role = "lock", app = true }, { name = T.CAL, role = "lock", app = true } }
		local saved = { chars = { [key(T.ANA)] = { crew = crew, captain = "", wizard = true } } }
		local ana = w:addClient(T.ANA, { spot = "Undercity", class = "WARLOCK", saved = { Wuber = saved } })
		w:addBot(T.BEA, { spot = "Undercity", class = "WARLOCK" })
		local r = w:addClient(T.TESTCHAR, { spot = "Orgrimmar", class = "MAGE", money = 100000, version = "2.3.0" })
		w:group({ T.ANA, T.BEA })
		w:advance(15)
		ana.W.Drive.SetOpen(true)
		w:advance(8)
		ok(r.W.RequestRide(key(T.ANA)), "rider requested")
		w:advance(11)
		local c = ana.W.Drive.customers[key(T.TESTCHAR)]
		ok(c and c.wuberRide, "driver took ride")
		ana.W.Drive.KitchenSend(c, C[1], { caster = key(T.CAL) })
		w:advance(1) -- the game answers the whisper check (PF-062) in 0.2 s before the line goes out
		local msgs = T.msgs(w, "G")
		ok(#msgs >= 1, C[2])
		ok(msgs[#msgs].text:find("Cal", 1, true) ~= nil, C[3])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)
