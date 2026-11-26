-- RETIRED 24 Nov 2026 (job 2743). Why: it tested the old addon's own team and main-caster rules (/rr team, RR.MainCaster, RR.Key), none of it Wuber code
-- Was in tests/run.lua. Not loaded by the suite; kept for the record. It needed the old addon's own code (Ritual Rides 1.4.1), which is not in this repository.

test("Ritual Rides: ungrouped named team, only the main caster beacons", function()
	rrNeeded()
	local w = newWorld()
	-- named while grouped, then the group breaks up
	local cs = rrTeam(w)
	settle(w)
	for _, n in ipairs({ BEA, CAL }) do w:leave(n) end
	w:advance(70)
	local senders = {}
	for _, e in ipairs(msgs(w, "D")) do if e.at > w.time - 65 then senders[e.from] = true end end
	ok(count(senders) <= 1, "one window beacons: " .. list((function() local t = {} for k in pairs(senders) do t[#t + 1] = k end return t end)()))
	local main = cs[1].RR.MainCaster and cs[1].RR.MainCaster()
	if count(senders) == 1 and main then
		local who = next(senders)
		local key = cs[1].RR.Key(type(main) == "table" and (main.name or main.key) or main)
		ok(key == nil or cs[1].RR.Key(who) == key, "the main caster beacons (" .. who .. " vs " .. tostring(key) .. ")")
	end
	clean(w)
end)
