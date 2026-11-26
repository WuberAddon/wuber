-- Merged table-driven tests (test audit): each group below was several near-identical tests of tests/winners/drive_raincheck_test.lua, the same body with different
-- literals. One body, one table of cases; every case keeps its own assertions and a failing case is named in the message.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- from tests/winners/drive_raincheck_test.lua: line 884; line 919
test("breakit Drive.Raincheck: a driver's own waiting raincheck card is shown when a rider (2 cases)", function()
	local failed = {}
	local cases = {
		{ "breakit Drive.Raincheck: a driver's own waiting raincheck card is shown when a rider accepts", "ok" },
		{ "breakit Drive.Raincheck: a driver's own waiting raincheck card is shown when a rider declines", "no" },
	}
	for _, case in ipairs(cases) do
		local C = { select(2, unpack(case)) }
		local good, err = pcall(function()
		local w = T.newWorld()
		local d = T.driver(w, T.ANA, { spot = "Undercity" })
		T.settle(w)
		local t = d.env.time()
		local card = { ["ZZZZ9999"] = { driverKey = "anita lift", driver = "Anita Lift", service = "Anita",
			cover = 5000, expires = t + 86400, state = "offered", rideId = "ZZZZZZ", at = t } }
		local ch = d.W.Char()
		if ch then ch.rainchecks = card end
		if d.W.db then d.W.db.rainchecks = card end
		d.W.Drive.RaincheckFact(T.ANA, true, "i", "ABCD1234", "wuber testcharacter", 5000, t + 86400, "ABCDEF")
		local v = d.W.db and d.W.db.drive and d.W.db.drive.iou and d.W.db.drive.iou["ABCD1234"]
		ok(v ~= nil, "the offered raincheck is in the driver's book")
		eq(v.state, "offered", "waiting for the rider's answer")
		d.W.Drive.RaincheckHeard(C[1], v.rider, T.TESTCHAR, "ABCD1234")
		ok(#d:findText("offers a raincheck", true) > 0, "the waiting raincheck card is shown")
		T.clean(w)
		end)
		if not good then failed[#failed + 1] = case[1] .. ": " .. tostring(err) end
	end
	if #failed > 0 then error(#failed .. " of " .. #cases .. " cases failed:\n" .. table.concat(failed, "\n"), 0) end
end)
