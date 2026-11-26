-- RETIRED 24 Nov 2026 (job 2743). Why: it checked the old addon's own beacon() shape and its /rr team; Wuber reading a provider's beacon is in tests/oldaddon
-- Was in tests/run.lua. Not loaded by the suite; kept for the record. It needed the old addon's own code (Ritual Rides 1.4.1), which is not in this repository.

test("Ritual Rides: beacon() returns named keys only", function()
	rrNeeded()
	local w = newWorld()
	local cs = rrTeam(w)
	settle(w)
	local b = cs[1].W.provider.beacon()
	ok(type(b) == "table", "a beacon table")
	eq(#b, 0, "no array part")
	for k in pairs(b) do
		ok(({ dest = 1, mapID = 1, x = 1, y = 1, price = 1, service = 1, state = 1, team = 1, seats = 1, queue = 1, badge = 1 })[k], "unexpected key " .. tostring(k))
	end
	if b.queue ~= nil then ok(type(b.queue) == "number" and b.queue >= 0 and b.queue <= 40, "queue 0..40: " .. tostring(b.queue)) end
	if b.badge ~= nil then eq(b.badge, "", "RR's badge stays empty (the crown comes from W.CREATOR)") end
	for _, k in ipairs({ "dest", "price", "state", "team", "seats" }) do ok(b[k] ~= nil, "beacon." .. k) end
	eq(cs[2].W.provider.beacon(), nil, "a follower's window returns nil")
	eq(cs[3].W.provider.beacon(), nil, "a follower's window returns nil")
	clean(w)
end)
