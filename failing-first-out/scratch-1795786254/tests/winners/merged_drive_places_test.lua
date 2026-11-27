-- Merged table-driven tests (test audit): each group below was several near-identical tests of tests/winners/drive_places_test.lua, the same body with different
-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- from tests/winners/drive_places_test.lua: line 8; line 37; line 66; line 95; line 124; line 153; line 182; line 211; line 240; line 269; line 298; line 327; line 356; line 385; line 414; line 443; line 472; line 501; line 530; line 559; line 588; line 617; line 646; line 675; line 704; line 733; line 762; line 912; line 970; line 1057
test("breakit Drive.Places: driver ignores a summon request to the word 'if' (30 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Places: driver ignores a summon request to the word 'if'", "[%s%-]+", " ", "lock", "", "Ironforge", "WARLOCK", "driver opens", "Thunder Bluff", "wtb summon to if", "no invite for a mere word" },
		{ "breakit Drive.Places: a chat line about mortals does not invite a buyer", "[%s%-]+", " ", "lock", "", "Undercity", "WARLOCK", "driver opens", "Thunder Bluff", "wtb mortals to uc", "no invite for a line about mortals" },
		{ "breakit Drive.Places: buyer leaving the driver's town is not invited", '[%s%-]+', ' ', 'lock', '', 'Ratchet', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'wtb summon frm ratchet', 'no invite for a buyer leaving Ratchet' },
		{ "breakit Drive.Places: buyer leaving with the typo 'fron' is not invited", '[%s%-]+', ' ', 'lock', '', 'Ratchet', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'wtb summon fron ratchet', 'no invite for a buyer leaving Ratchet' },
		{ "breakit Drive.Places: buyer leaving the driver's town is not invited instead", '[%s%-]+', ' ', 'lock', '', 'Ratchet', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'wtb summon leaving ratchet', 'no invite for a buyer leaving Ratchet' },
		{ "breakit Drive.Places: a buyer asking for another town is not invited to the driver's town", '[%s%-]+', ' ', 'lock', '', 'Ratchet', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'wtb summon to zapville ratchet', 'no invite for a buyer wanting another town' },
		{ "breakit Drive.Places: available seller not invited", "[%s%-]+", " ", "lock", "", "Undercity", "WARLOCK", "driver opens", "Thunder Bluff", "wtb summon to uc, available now", "seller using available not invited" },
		{ "breakit Drive.Places: sell seller not invited", "[%s%-]+", " ", "lock", "", "Undercity", "WARLOCK", "driver opens", "Thunder Bluff", "sell summon to uc, need buyers", "seller using sell not invited" },
		{ "breakit Drive.Places: public chat with the word sells is ignored", "[%s%-]+", " ", "lock", "", "Undercity", "WARLOCK", "driver opens", "Thunder Bluff", "sells summon to uc, need summon", "seller line ignored, no invite to seller" },
		{ "breakit Drive.Places: public chat with the word offering is ignored", "[%s%-]+", " ", "lock", "", "Undercity", "WARLOCK", "driver opens", "Thunder Bluff", "offering summon to uc, need summon", "seller line ignored, no invite to seller" },
		{ "breakit Drive.Places: public chat with the word offer is ignored", "[%s%-]+", " ", "lock", "", "Undercity", "WARLOCK", "driver opens", "Thunder Bluff", "offer summon to uc, need summon", "seller line ignored, no invite to seller" },
		{ "breakit Drive.Places: public chat with the word wts is ignored", "[%s%-]+", " ", "lock", "", "Undercity", "WARLOCK", "driver opens", "Thunder Bluff", "wts summon to uc, need summon", "seller line ignored, no invite to seller" },
		{ "breakit Drive.Places: public chat with the word avail is ignored", "[%s%-]+", " ", "lock", "", "Undercity", "WARLOCK", "driver opens", "Thunder Bluff", "avail summon to uc, need summon", "seller line ignored, no invite to seller" },
		{ "breakit Drive.Places: LFM seller is not invited as a buyer", '[%s%-]+', ' ', 'lock', '', 'Undercity', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'lfm wtb summon to uc', 'LFM seller not invited' },
		{ "breakit Drive.Places: recruiting seller is not invited as a buyer", '[%s%-]+', ' ', 'lock', '', 'Undercity', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'recruiting wtb summon to uc', 'recruiting seller not invited' },
		{ "breakit Drive.Places: guild seller is not invited as a buyer", '[%s%-]+', ' ', 'lock', '', 'Undercity', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'guild wtb summon to uc', 'guild seller not invited' },
		{ "breakit Drive.Places: whisp seller is not invited as a buyer", '[%s%-]+', ' ', 'lock', '', 'Undercity', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'whisp wtb summon to uc', 'whisp seller not invited' },
		{ "breakit Drive.Places: wisp seller is not invited as a buyer", '[%s%-]+', ' ', 'lock', '', 'Undercity', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'wisp wtb summon to uc', 'wisp seller not invited' },
		{ "breakit Drive.Places: public advert with cheap is not invited as a buyer", '[%s%-]+', ' ', 'lock', '', 'Undercity', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'wtb summon to uc cheap', 'no invite for a cheap advert' },
		{ "breakit Drive.Places: public advert with cheapest is not invited as a buyer", '[%s%-]+', ' ', 'lock', '', 'Undercity', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'wtb summon to uc cheapest', 'no invite for a cheapest advert' },
		{ "breakit Drive.Places: public advert with open is not invited as a buyer", '[%s%-]+', ' ', 'lock', '', 'Undercity', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'wtb summon to uc open', 'no invite for an open advert' },
		{ "breakit Drive.Places: public advert with ready is not invited as a buyer", '[%s%-]+', ' ', 'lock', '', 'Undercity', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'wtb summon to uc ready', 'no invite for a ready advert' },
		{ "breakit Drive.Places: summon service advert is not invited as a buyer", '[%s%-]+', ' ', 'lock', '', 'Undercity', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'summon service to uc', 'no invite for a summon service advert' },
		{ "breakit Drive.Places: advert selling portal services is not invited", '[%s%-]+', ' ', 'lock', '', 'Undercity', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'portal services to uc', 'advert not invited' },
		{ "breakit Drive.Places: advert selling portal svc is not invited", '[%s%-]+', ' ', 'lock', '', 'Undercity', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'portal svc to uc', 'advert not invited' },
		{ "breakit Drive.Places: advert selling portal business is not invited", '[%s%-]+', ' ', 'lock', '', 'Undercity', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'portal business to uc', 'advert not invited' },
		{ "breakit Drive.Places: advert selling portal dm is not invited", '[%s%-]+', ' ', 'lock', '', 'Undercity', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'portal dm to uc', 'advert not invited' },
		{ "breakit Drive.Places: a two-letter typo of Durotar is ignored", '[%s%-]+', ' ', 'lock', '', 'Durotar', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'wtb summon to dyrotor', 'two-letter typo of Durotar ignored' },
		{ "breakit Drive.Places: a word two edits from summon is not a summon request", '[%s%-]+', ' ', 'lock', '', 'Undercity', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'wtb summoonn to uc', 'a word two edits from summon is not a summon request' },
		{ "breakit Drive.Places: buyer asking for an unknown three-letter place is not invited", '[%s%-]+', ' ', 'lock', '', 'Undercity', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'wtb summon to xqz uc pickup', 'buyer asking for another place is not invited' },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local function key(n) return (n:lower():gsub(C[1], C[2])) end
		local names = { T.ANA, T.BEA, T.CAL }
		local cs = {}
		for i, n in ipairs(names) do
			local crew = {}
			for j, m in ipairs(names) do
				if m ~= n then crew[#crew + 1] = { name = m, role = C[3], app = true } end
			end
			local ch = { crew = crew, captain = (i == 1) and C[4] or T.ANA, wizard = true }
			cs[i] = w:addClient(n, { spot = C[5], class = C[6], saved = { Wuber = { chars = { [key(n)] = ch } } } })
		end
		w:group(names)
		w:advance(5)
		local DR = cs[1].W.Drive
		ok(DR.SetOpen(true), C[7])
		w:advance(5)
		DR.opts().watchPublic, DR.opts().autoPublic = true, true
		w:addBot(T.BOB, { spot = C[8] })
		DR.PublicLine(C[9], T.BOB, true)
		w:advance(3)
		local inv = 0
		for i, x in ipairs(w.invites) do if key(x.to) == key(T.BOB) then inv = inv + 1 end end
		eq(inv, 0, C[10])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_places_test.lua: line 883; line 941; line 999; line 1028; line 1297
test("breakit Drive.Places: one-letter typo of Orgrim still gets an invite (5 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Places: one-letter typo of Orgrim still gets an invite", '[%s%-]+', ' ', 'lock', '', 'Orgrimmar', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'wtb summon to xrgrim', 'one-letter typo of Orgrim still invited' },
		{ "breakit Drive.Places: two-letter typo of Orgrimar still gets an invite", '[%s%-]+', ' ', 'lock', '', 'Orgrimmar', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'wtb summon to xrgzimar', 'two-letter typo of Orgrimar still invited' },
		{ "breakit Drive.Places: a buyer spelling summoner with two slips is still invited", '[%s%-]+', ' ', 'lock', '', 'Undercity', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'wtb sammonar to uc', 'a word two edits from summoner is a summon request' },
		{ "breakit Drive.Places: an eight-letter buyer word two slips from summoner is still a request", '[%s%-]+', ' ', 'lock', '', 'Undercity', 'WARLOCK', 'driver opens', 'Thunder Bluff', 'wtb sammonor to uc', 'an eight-letter word two edits from summoner is a summon request' },
		{ "breakit Drive.Places: colored chat line still invites buyer to Undercity", "[%s%-]+", " ", "lock", "", "Undercity", "WARLOCK", "driver opens", "Thunder Bluff", "wtb summon to |cff00ff00uc|r", "colored buyer line invited" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local function key(n) return (n:lower():gsub(C[1], C[2])) end
		local names = { T.ANA, T.BEA, T.CAL }
		local cs = {}
		for i, n in ipairs(names) do
			local crew = {}
			for j, m in ipairs(names) do
				if m ~= n then crew[#crew + 1] = { name = m, role = C[3], app = true } end
			end
			local ch = { crew = crew, captain = (i == 1) and C[4] or T.ANA, wizard = true }
			cs[i] = w:addClient(n, { spot = C[5], class = C[6], saved = { Wuber = { chars = { [key(n)] = ch } } } })
		end
		w:group(names)
		w:advance(5)
		local DR = cs[1].W.Drive
		ok(DR.SetOpen(true), C[7])
		w:advance(5)
		DR.opts().watchPublic, DR.opts().autoPublic = true, true
		w:addBot(T.BOB, { spot = C[8] })
		DR.PublicLine(C[9], T.BOB, true)
		w:advance(3)
		local inv = 0
		for i, x in ipairs(w.invites) do if key(x.to) == key(T.BOB) then inv = inv + 1 end end
		eq(inv, 1, C[10])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_places_test.lua: line 1120; line 1154; line 1188
test("breakit Drive.Places: driver invites a buyer whose (3 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Places: driver invites a buyer whose one-word typo names the destination", 'm abcdef', 'm abcdef', 'wtb summon to mabcde', 'buyer invited from a one-word typo' },
		{ "breakit Drive.Places: driver invites a buyer whose four-letter typo names the destination", 'l abcd', 'l abcd', 'wtb summon to labc', 'buyer invited from a four-letter typo' },
		{ "breakit Drive.Places: driver invites a buyer whose typo is two letters from the destination", 'n abcdefg', 'n abcdefg', 'wtb summon to nabcde', 'buyer invited from a two-letter typo' },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local function key(n) return (n:lower():gsub('[%s%-]+', ' ')) end
		local names = { T.ANA, T.BEA, T.CAL }
		local cs = {}
		for i, n in ipairs(names) do
			local crew = {}
			for j, m in ipairs(names) do
				if m ~= n then crew[#crew + 1] = { name = m, role = 'lock', app = true } end
			end
			local ch = { crew = crew, captain = (i == 1) and '' or T.ANA, wizard = true }
			cs[i] = w:addClient(n, { spot = 'Undercity', class = 'WARLOCK', saved = { Wuber = { chars = { [key(n)] = ch } } } })
		end
		w:group(names)
		w:advance(5)
		local DR = cs[1].W.Drive
		ok(DR.SetOpen(true), 'driver opens')
		w:advance(5)
		DR.opts().watchPublic, DR.opts().autoPublic = true, true
		local found = false
		for _, e in ipairs(DR.PLACES) do
			if type(e[1]) == 'string' and e[1]:lower() == 'undercity' then e[#e + 1] = C[1]; found = true end
		end
		if not found then DR.PLACES[#DR.PLACES + 1] = { 'Undercity', C[2] } end
		w:addBot(T.BOB, { spot = 'Thunder Bluff' })
		DR.PublicLine(C[3], T.BOB, true)
		w:advance(3)
		local inv = 0
		for i, x in ipairs(w.invites) do if key(x.to) == key(T.BOB) then inv = inv + 1 end end
		eq(inv, 1, C[4])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_places_test.lua: line 1356; line 1374
test("breakit Drive.Places: a driver is told a rider asked for (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Places: a driver is told a rider asked for Auberdine", "summon to auberdine", "Auberdine", "the console names Auberdine as the place the rider asked for" },
		{ "breakit Drive.Places: a driver is told a rider asked for Feathermoon Stronghold", "summon to feathermoon", "Feathermoon Stronghold", "the console names Feathermoon Stronghold as the place the rider asked for" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.TESTCHAR, { spot = "Orgrimmar" })
		T.settle(w)
		local DR = d.W.Drive
		T.goOnline(d, { price = 5000 })
		w:advance(2)
		DR.Request(T.BOB, "manual", C[1])
		w:advance(1)
		local said = false
		for _, f in ipairs(d.fired) do
			if f.name == "DRIVE_ALERT" and tostring(f.args[1]):find(C[2], 1, true) then said = true end
		end
		ok(said, C[3])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_places_test.lua: line 1510; line 1530
test("breakit Drive.Places: buyer naming the driver's custom 'to' word is invited (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Places: buyer naming the driver's custom 'to' word is invited", "to foo", "wtb summon to foo", "the buyer whose words are covered by the driver's custom name is invited" },
		{ "breakit Drive.Places: buyer using the driver's custom 'to' name is still invited", "to zed", "wtb summon to zed", "the buyer naming the driver's custom place is invited" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
		local ana = w:addClient(T.ANA, { spot = "Undercity", class = "WARLOCK",
			saved = { Wuber = { chars = { [key(T.ANA)] = { wizard = true, captain = "", runner = true, destWords = C[1] } } } } })
		w:advance(10)
		local DR = ana.W.Drive
		ok(DR.SetOpen(true), "driver opens")
		w:advance(5)
		DR.opts().watchPublic, DR.opts().autoPublic = true, true
		w:addBot(T.BOB, { spot = "Thunder Bluff" })
		DR.PublicLine(C[2], T.BOB, true)
		w:advance(3)
		local inv = 0
		for _, x in ipairs(w.invites) do if key(x.to) == key(T.BOB) then inv = inv + 1 end end
		eq(inv, 1, C[3])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_places_test.lua: line 1550; line 1832; line 1860
test("breakit Drive.Places: a rider asking for a place Wuber cannot find is not invited (3 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Places: a rider asking for a place Wuber cannot find is not invited", "lf summon to zzq pls", "rider for a place Wuber cannot find is not invited" },
		{ "breakit Drive.Places: a rider asking for an unknown place is not invited when they mention our city", "summon uc to zqzz", "rider for an unknown place is not invited" },
		{ "breakit Drive.Places: a rider asking for a place no station serves is not invited", "any summon to qzx pls?", "rider for a place no station serves is not invited" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
		local names = { T.ANA, T.BEA, T.CAL }
		local cs = {}
		for i, n in ipairs(names) do
			local crew = {}
			for j, m in ipairs(names) do
				if m ~= n then crew[#crew + 1] = { name = m, role = "lock", app = true } end
			end
			local ch = { crew = crew, captain = (i == 1) and "" or T.ANA, wizard = true }
			cs[i] = w:addClient(n, { spot = "Undercity", class = "WARLOCK", saved = { Wuber = { chars = { [key(n)] = ch } } } })
		end
		w:group(names)
		w:advance(5)
		local DR = cs[1].W.Drive
		ok(DR.SetOpen(true), "driver opens")
		w:advance(5)
		w:addBot(T.BOB, { spot = "Thunder Bluff" })
		w:botWhisper(T.BOB, cs[1], C[1])
		w:advance(3)
		local inv = 0
		for i, x in ipairs(w.invites) do if key(x.to) == key(T.BOB) then inv = inv + 1 end end
		eq(inv, 0, C[2])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_places_test.lua: line 1593; line 1607
test("breakit Drive.Places: an empty current place counts as no destination (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Places: an empty current place counts as no destination", "", "an empty place is not shown as a destination" },
		{ "breakit Drive.Places: an unknown current place counts as no destination", "Unknown", "an unknown place is not shown as a destination" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local r = T.rider(w, T.TESTCHAR)
	    T.settle(w)
	    local DR = r.W.Drive
	    r.W.DestHere = function() return C[1] end
	    local p = DR.PlaceOf("player")
	    DR.Alert("place=" .. tostring(p), "info")
	    w:advance(1)
	    ok(#r:findText("place=nil") > 0, C[2])
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/drive_places_test.lua: line 1781; line 1903
test("breakit Drive.Places: a rider naming Undercity and coming from Thunder Bluff is invited to Undercity (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Places: a rider naming Undercity and coming from Thunder Bluff is invited to Undercity", "undercity from thunder bluff" },
		{ "breakit Drive.Places: a rider naming Thunder Bluff to Undercity is invited to Undercity", "thunder bluff to undercity" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local function key(n) return (n:lower():gsub("[%s%-]+", " ")) end
		local names = { T.ANA, T.BEA, T.CAL }
		local cs = {}
		for i, n in ipairs(names) do
			local crew = {}
			for j, m in ipairs(names) do
				if m ~= n then crew[#crew + 1] = { name = m, role = "lock", app = true } end
			end
			local ch = { crew = crew, captain = (i == 1) and "" or T.ANA, wizard = true }
			cs[i] = w:addClient(n, { spot = "Undercity", class = "WARLOCK", saved = { Wuber = { chars = { [key(n)] = ch } } } })
		end
		w:group(names)
		w:advance(5)
		local DR = cs[1].W.Drive
		ok(DR.SetOpen(true), "driver opens")
		w:advance(5)
		DR.customers = DR.customers or {}
		DR.customers[key(T.BOB)] = { name = T.BOB, state = "lead", elsewhere = true }
		w:addBot(T.BOB, { spot = "Thunder Bluff" })
		w:botWhisper(T.BOB, cs[1], C[1])
		w:advance(3)
		local n = 0
		for _, x in ipairs(w.invites) do if key(x.to) == key(T.BOB) then n = n + 1 end end
		eq(n, 1, "buyer invited to Undercity")
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)
