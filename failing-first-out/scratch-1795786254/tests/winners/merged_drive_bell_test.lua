-- Merged table-driven tests (test audit): each group below was several near-identical tests of tests/winners/drive_bell_test.lua, the same body with different
-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- from tests/winners/drive_bell_test.lua: line 8; line 306
test("breakit Drive.Bell: the hello still names a crew member the captain also names (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Bell: the hello still names a crew member the captain also names" },
		{ "breakit Drive.Bell: every crew member fits in the hello the alert character hears" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
		local function has(t, v)
			if type(t) ~= "table" then return false end
			for _, x in ipairs(t) do if x == v then return true end end
			return false
		end
		local crew = {}
		for _, n in ipairs({ T.BEA, T.CAL, T.TESTCHAR, T.BOB, T.ANITA }) do crew[#crew + 1] = { name = n, role = "lock", app = true } end
		local saved = { Wuber = { chars = { [key(T.ANA)] = { wizard = true, captain = T.BEA, crew = crew } } } }
		local ana = T.rider(w, T.ANA, { spot = "Undercity", class = "WARLOCK", saved = saved })
		local wub = T.rider(w, "Wuber Rocks", { spot = "Orgrimmar", class = "MAGE" })
		T.settle(w)
		ana:slash("/wuber drive bell Wuber Rocks")
		w:advance(3)
		local team = wub.W.db and wub.W.db.drive and wub.W.db.drive.bell and wub.W.db.drive.bell.team
		ok(has(team, "wuber testcharacter"), "the alert character knows Wuber from the hello")
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_bell_test.lua: line 133; line 146
test("breakit Drive.Bell: a crew hello listing seven names is ignored, so no flash line appears and nothing is learned (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Bell: a crew hello listing seven names is ignored, so no flash line appears and nothing is learned", "BH~1~Ana Smith~a one,b two,c three,d four,e five,f six,ana smith~Ana~2.3.1", "no flash line for a hello whose seventh name is the sender" },
		{ "breakit Drive.Bell: a crew hello that does not name its own sender is ignored, so no flash line appears", "BH~1~Ana Smith~bea jones,cal brown~Ana~2.3.1", "no flash line for a hello that does not name Ana" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local wub = T.rider(w, T.TESTCHAR)
		local ana = T.rider(w, T.ANA)
		T.settle(w)
		ana.env.C_ChatInfo.SendAddonMessage("WUBERT", C[1], "WHISPER", wub.player.name)
		w:advance(1)
		ok(not wub:said("flashes for"), C[2])
		eq(#wub.W.db.drive.bell.team, 0, "nothing learned from it")
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_bell_test.lua: line 252; line 264; line 408; line 474
test("breakit Drive.Bell: a new player can choose an alert character (4 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Bell: a new player can choose an alert character" },
		{ "breakit Drive.Bell: choosing an alert character works on a fresh save" },
		{ "breakit Drive.Bell: the chosen alert character is remembered" },
		{ "breakit Drive.Bell: the alert character setting is stored" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local r = T.rider(w, T.TESTCHAR)
	    T.settle(w)
	    r.env.WuberDB.drive = nil
	    r.W.Drive.BellSet(T.ANITA)
	    local b = r.env.WuberDB.drive and r.env.WuberDB.drive.bell
	    ok(b ~= nil and b.name == T.ANITA, "alert character saved")
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)
