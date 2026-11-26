-- Merged table-driven tests (test audit): each group below was several near-identical tests of tests/winners/core_places_test.lua, the same body with different
-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- from tests/winners/core_places_test.lua: line 49; line 64
test("breakit Core.Places: a partial place typed in Where to? still names the place in the empty state (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Core.Places: a partial place typed in Where to? still names the place in the empty state", "gadgetz" },
		{ "breakit Core.Places: a three-letter start of a place typed in Where to? still names the place", "gad" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local r = T.rider(w, T.TESTCHAR)
	    T.settle(w)
	    r.W.UI.Toggle(true)
	    w:advance(3)
	    r.W.UI.Show("home")
	    w:advance(1.5)
	    r.W.UI.SetSearch(C[1])
	    w:advance(1)
	    ok(#r:findText("Nobody summons to Gadgetzan right now", true, true) > 0, "the searched place is named")
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/core_places_test.lua: line 102; line 120; line 138; line 389
test("breakit Core.Places: typing r offers Ratchet first (4 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Core.Places: typing r offers Ratchet first", "r", "Ratchet", "the place that starts with r is offered first" },
		{ "breakit Core.Places: typing ra offers Ratchet before places that only contain ra", "ra", "Ratchet", "the place whose name starts with ra comes first" },
		{ "breakit Core.Places: typing a offers Auberdine first", "a", "Auberdine", "the place whose name starts with a is offered first" },
		{ "breakit Core.Places: typing 'the org' offers Orgrimmar", "the org", "Orgrimmar", "the place with 'the' in front is offered" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local d = T.driver(w, T.TESTCHAR)
	    T.settle(w)
	    T.openDrive(d)
	    d:clickOn(d.W.Driver.ui.console.fare)
	    w:advance(1)
	    local s = d.W.UI.drive.screens.sheet
	    d:clickOn(s.where.buttons[2])
	    w:advance(0.2)
	    d:type(s.search.edit, C[1])
	    w:advance(0.2)
	    ok(s.hits[1]:IsShown(), "the driver sees a place offered")
	    eq(s.hits[1].place, C[2], C[3])
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/core_places_test.lua: line 156; line 175
test("breakit Core.Places: a town at the driver's spot is offered, not a later duplicate (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Core.Places: a town at the driver's spot is offered, not a later duplicate", "the first town at the spot is offered; beacon was: ", "the duplicate town is not offered" },
		{ "breakit Core.Places: two towns at one spot keep the first one offered", "the earlier town at the spot is offered; beacon was: ", "the later tie is not offered" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANITA)
		T.settle(w)
		local MAP = 987654
		table.insert(d.W.PLACES, { name = "Alpha", mapID = MAP, x = 0, y = 0, kind = "town" })
		table.insert(d.W.PLACES, { name = "Beta", mapID = MAP, x = 0, y = 0, kind = "town" })
		d.W.MyPosition = function() return MAP, 0, 0 end
		d.env.GetSubZoneText = function() return "BreakNowhere" end
		T.goOnline(d, { price = 100 })
		w:advance(1)
		local txt = ""
		for _, e in ipairs(w:messages("D", d.player.name)) do txt = txt .. e.text end
		ok(string.find(txt, "Alpha", 1, true) ~= nil, C[1] .. txt)
		eq(string.find(txt, "Beta", 1, true), nil, C[2])
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/core_places_test.lua: line 250; line 272; line 463; line 485
test("breakit Core.Places: a driver's online beacon keeps the map name (4 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Core.Places: a driver's online beacon keeps the map name", 'the beacon keeps the map name' },
		{ "breakit Core.Places: a driver's online beacon shows a real zone", 'the beacon shows a real zone' },
		{ "breakit Core.Places: a driver's online beacon names the current zone", 'the beacon names the current zone' },
		{ "breakit Core.Places: a driver's online beacon is not Unknown", 'the beacon is not Unknown' },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local d = T.driver(w, T.ANITA)
	    T.settle(w)
	    local info = d.env.C_Map.GetMapInfo(1413)
	    local want = d.W.CleanDest(info.name)
	    d.env.GetSubZoneText = function() return nil end
	    d.env.GetRealZoneText = function() return nil end
	    d.env.GetZoneText = function() return nil end
	    d.W.PlaceAt = function() return nil end
	    T.goOnline(d, { price = 5000 })
	    w:advance(6)
	    local beacon
	    for _, e in ipairs(w:messages('D', T.ANITA)) do
	        beacon = T.fields(e)
	    end
	    ok(beacon ~= nil, 'the driver sends a beacon')
	    eq(beacon and beacon[3], want, C[1])
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/core_places_test.lua: line 330; line 352; line 507; line 529
test("breakit Core.Places: the confirm card shows the map-name destination (4 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Core.Places: the confirm card shows the map-name destination" },
		{ "breakit Core.Places: the rider reads the map name on the driver's offer" },
		{ "breakit Core.Places: a rider sees a driver headed to the map's own name" },
		{ "breakit Core.Places: a driver offering a map-name destination is shown to the rider" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local r = T.rider(w, T.TESTCHAR)
	    T.settle(w)
	    local cm = r.env.C_Map
	    local oldMapInfo = cm.GetMapInfo
	    cm.GetMapInfo = function(id)
	        if tonumber(id) == 1413 then return { name = "Zqx Zone" } end
	        return oldMapInfo(id)
	    end
	    w:inject(T.ANITA, "D~1~Zqx Zone~1413~0~0~5000~~open~1~0~~2.3.1", "CHANNEL")
	    w:advance(1)
	    local key = r.W.drivers and next(r.W.drivers)
	    ok(key, "Anita is listed as a driver")
	    T.openConfirm(r, key)
	    w:advance(1)
	    ok(#r:findText("Zqx Zone") > 0, "the rider sees Zqx Zone as the destination")
	    eq(r.W.drivers[key].dest, "Zqx Zone", "the map name is accepted as the destination")
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)

-- from tests/winners/core_places_test.lua: line 407; line 446
test("breakit Core.Places: a driver in Orgrimmar advertises (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Core.Places: a driver in Orgrimmar advertises the proper place name", "the beacon uses the place's proper name" },
		{ "breakit Core.Places: a driver in Orgrimmar advertises Orgrimmar, not an unknown map name", "the beacon names Orgrimmar" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
	    local w = T.newWorld()
	    local d = T.driver(w, T.ANITA)
	    T.settle(w)
	    d.env.GetSubZoneText = function() return nil end
	    d.env.GetRealZoneText = function() return "orgrimmar" end
	    d.env.C_Map.GetBestMapForUnit = function() return nil end
	    T.goOnline(d, { price = 5000 })
	    w:advance(1)
	    local ms = T.msgs(w, "D", T.ANITA)
	    ok(ms[1], "the driver sent a beacon")
	    local f = T.fields(ms[1])
	    eq(f[3], "Orgrimmar", C[1])
	    T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)
